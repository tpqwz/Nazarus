## Nazarus IDE. One window: menu, toolbar, component palette, form designer,
## Nim source editor, an Explore index, object inspector,
## component tree, and a compile log. Design, Code, and Explore are the three views.

import std/[os, osproc, posix, strutils, unicode]
import ncl
import codegen
import nimsyn
import project
import edsearch
import ededit
import version

type
  TUnit = ref object
    name: string
    form: TForm
    source: string
  TExploreKind = enum ekForm, ekControl, ekProc
  TExploreHit = object
    kind: TExploreKind
    name: string
    line: int
    comp: TComponent

var
  proj: TProject
  units: seq[TUnit]
  current: TUnit
  ideForm: TForm
  toolbar: TToolBar
  palette: TScrollBox
  paletteOn: bool = true
  tree: TTreeView
  inspectorPane: TPanel
  inspector: TScrollBox
  pages: TPageControl
  designSheet: TTabSheet
  codeSheet: TTabSheet
  host: TScrollBox
  editor: TSourceEditor
  procBar: TPanel
  procCombo: TComboBox
  codeProcs: seq[TNimProc]
  procSync: bool
  exploreSheet: TTabSheet
  exploreIndex: TListBox
  exploreFilter: TEdit
  exploreDetail: TMemo
  exploreRows: seq[TExploreHit]
  findBar: TPanel
  findEdit: TEdit
  replaceEdit: TEdit
  lineEdit: TEdit
  messages: TMemo
  statusBar: TStatusBar
  unitCombo: TComboBox
  filePane: TPanel
  fileList: TListBox
  viewButtons: array[3, TButton]
  viewItems: array[3, TMenuItem]
  buildProc: Process
  buildTimer: TTimer
  runAfter = false
  runs: seq[Process]
  syncing = false
  inspMode = "props"
  ready = false

proc doNew()
proc doOpen()
proc doSave()
proc doCompile()
proc doRun()
proc doFind()
proc doFindNext()
proc doFindPrev()
proc doReplace()
proc doReplaceAll()
proc doGoLine()
proc doComment()
proc doShift(outward: bool)
proc doToggleView()
proc doQuit()
proc doAbout()
proc doAddForm()
proc showUnit(u: TUnit)
proc refreshTree()
proc rebuildInspector()
proc refreshEditor()
proc showCode()
proc showDesign()
proc showExploreDetail()

proc setStatus(s: string) =
  if statusBar != nil: statusBar.simpleText = s

proc logMsg(s: string) =
  if messages == nil: return
  var cur = messages.text
  cur.add(s)
  if cur.len > 60000: cur = cur[cur.len - 40000 .. ^1]
  messages.text = cur
  messages.scrollToEnd()

proc procAtLine(line: int): int =
  ## Innermost routine whose span covers this 1-based line.
  result = -1
  var best = -1
  for i in 0 ..< codeProcs.len:
    let p = codeProcs[i]
    if line >= p.line and line <= p.closeLine and p.depth >= best:
      best = p.depth
      result = i

proc refreshCodeStructure() =
  ## Fill the procedure dropdown, the scope rails, and the jump lanes.
  if editor == nil or procCombo == nil or not editor.hasBuffer: return
  let src = editor.text
  let outline = nimOutline(src)
  var rails: seq[TScopeRail]
  var jumps: seq[TJumpMark]
  codeProcs.setLen(0)
  if outline.ok:
    for s in outline.scopes:
      rails.add(TScopeRail(openLine: s.openLine, closeLine: s.closeLine, depth: s.depth))
    for j in outline.jumps:
      jumps.add(TJumpMark(fromLine: j.fromLine, toLine: j.toLine,
        column: j.column, backward: j.backward))
    codeProcs = outline.procs
  else:
    for item in procNames(src):
      codeProcs.add(TNimProc(name: item.name, line: item.line, closeLine: item.line, depth: 0))
  editor.jumpMarks = jumps
  editor.scopeRails = rails
  var names = @["(declarations)"]
  for p in codeProcs:
    names.add(p.name)
  let at = procAtLine(editor.caretLine)
  let idx = if at < 0: 0 else: at + 1
  procSync = true
  if names != procCombo.items: procCombo.items = names
  if procCombo.itemIndex != idx: procCombo.itemIndex = idx
  procSync = false

proc currentSource(): string =
  if current == nil: return ""
  if editor != nil and editor.hasBuffer and pages != nil and pages.activePageIndex == 1:
    current.source = editor.text
  current.source

proc pushEditor() =
  if editor == nil or not editor.hasBuffer or current == nil: return
  syncing = true
  editor.text = current.source
  syncing = false
  refreshCodeStructure()

proc exploreWanted(label, filt: string): bool =
  filt.len == 0 or filt in label.toLowerAscii

proc addExplore(rows: var seq[TExploreHit], labels: var seq[string],
    hit: TExploreHit, label, filt: string) =
  if not exploreWanted(label, filt): return
  rows.add(hit)
  labels.add(label)

proc walkExplore(root: TComponent, rows: var seq[TExploreHit],
    labels: var seq[string], filt: string) =
  for c in root.ownedComponents:
    addExplore(rows, labels, TExploreHit(kind: ekControl, name: c.name, comp: c),
      c.className & "  " & c.name, filt)
    walkExplore(c, rows, labels, filt)

proc refreshExplore() =
  ## Index of this unit: the form, its components, and its procs.
  if exploreIndex == nil: return
  var rows: seq[TExploreHit]
  var labels: seq[string]
  let filt = if exploreFilter == nil: "" else: exploreFilter.text.toLowerAscii
  if current != nil and current.form != nil:
    let form = current.form
    addExplore(rows, labels, TExploreHit(kind: ekForm, name: form.name, comp: form),
      "form  " & form.name, filt)
    walkExplore(form, rows, labels, filt)
  if current != nil:
    let src = generateUnit(current.form, currentSource())
    let outline = nimOutline(src)
    if outline.ok:
      for item in outline.procs:
        addExplore(rows, labels, TExploreHit(kind: ekProc, name: item.name, line: item.line),
          "proc  " & item.name, filt)
    else:
      for item in procNames(src):
        addExplore(rows, labels, TExploreHit(kind: ekProc, name: item.name, line: item.line),
          "proc  " & item.name, filt)
  exploreRows = rows
  syncing = true
  exploreIndex.items = labels
  syncing = false
  showExploreDetail()

proc selectedExplore(): int =
  if exploreIndex == nil: return -1
  let i = exploreIndex.itemIndex
  if i < 0 or i >= exploreRows.len: -1 else: i

proc showExploreDetail() =
  if exploreDetail == nil: return
  let i = selectedExplore()
  if i < 0:
    exploreDetail.text = "Select a form, a component, or a proc."
    return
  let hit = exploreRows[i]
  var lines: seq[string]
  case hit.kind
  of ekForm, ekControl:
    let c = hit.comp
    if c == nil:
      exploreDetail.text = "That component is gone."
      return
    lines.add(c.name)
    lines.add(c.className)
    if c of TControl:
      let t = TControl(c)
      lines.add("Left " & $t.left & "   Top " & $t.top)
      lines.add("Width " & $t.width & "   Height " & $t.height)
    for p in publishedProps(c.className):
      if p.kind == pkEvent:
        let h = c.handler(p.name)
        if h.len > 0: lines.add(p.name & " = " & h)
    lines.add("")
    lines.add("Double-click to show it on the form.")
  of ekProc:
    let unitName = if current == nil: "unit" else: current.name
    lines.add(hit.name)
    lines.add("proc · " & unitName & ".nim:" & $hit.line)
    lines.add("")
    lines.add("Double-click to open this line.")
  exploreDetail.text = lines.join("\n")

proc openExplore() =
  if syncing: return
  let i = selectedExplore()
  if i < 0: return
  let hit = exploreRows[i]
  case hit.kind
  of ekForm, ekControl:
    if hit.comp != nil: selectComponent(hit.comp)
    showDesign()
  of ekProc:
    showCode()
    if editor != nil: editor.gotoLine(hit.line)

proc refreshEditor() =
  if current == nil: return
  current.source = generateUnit(current.form, currentSource())
  pushEditor()
  refreshExplore()

proc markActiveView() =
  ## The toolbar buttons stay in one place. The lit one is the view showing.
  ## Checking a menu item would run its command again, so this update is quiet.
  if pages == nil or syncing: return
  let page = max(0, pages.activePageIndex)
  syncing = true
  for i in 0 .. 2:
    if viewButtons[i] != nil:
      viewButtons[i].color = if i == page: TColor(0xD3E3F6) else: TColor(0xF2F2F2)
    if viewItems[i] != nil and viewItems[i].checked != (i == page):
      viewItems[i].checked = i == page
  syncing = false

proc useCodeChrome(code: bool) =
  ## The component tree, the inspector, and the palette belong to Design.
  ## Code and Explore leave them hidden. Design brings them back.
  ## The View check remembers whether Design should show the palette.
  if tree != nil: tree.visible = not code
  if inspectorPane != nil: inspectorPane.visible = not code
  if palette != nil: palette.visible = paletteOn and not code
  markActiveView()

proc showCode() =
  if pages == nil: return
  pages.activePageIndex = 1
  useCodeChrome(true)
  refreshEditor()
  if editor != nil: editor.focus()

proc showDesign() =
  if pages == nil: return
  if current != nil and editor != nil and editor.hasBuffer and
      pages.activePageIndex == 1:
    current.source = editor.text
  pages.activePageIndex = 0
  useCodeChrome(false)
  refreshDesign()
  focusDesign()

proc showExplore() =
  if pages == nil: return
  if current != nil and editor != nil and editor.hasBuffer and
      pages.activePageIndex == 1:
    current.source = editor.text
  pages.activePageIndex = 2
  useCodeChrome(true)
  refreshExplore()

proc lineOf(src, needle: string): int =
  result = 1
  var n = 1
  for line in src.splitLines:
    if needle in line: return n
    inc n

proc ensureHandler(c: TComponent) =
  if c == nil: return
  let ev = defaultEvent(c.className)
  if ev.len == 0 or not c.hasProp(ev): return
  var existing = getProp(c, ev).strip
  if existing.len == 0:
    existing = handlerName(c.name, ev)
    setProp(c, ev, existing)
  refreshEditor()
  showCode()
  if editor != nil: editor.gotoLine(lineOf(current.source, "proc " & existing))

proc clearInspector() =
  if inspector == nil: return
  var kids: seq[TControl]
  for c in inspector.childControls: kids.add(c)
  for c in kids: freeComponent(c)

proc addLabel(text: string, x, y, w: int): TLabel =
  result = TLabel.new(ideForm)
  result.autoSize = false
  result.caption = text
  result.left = x
  result.top = y
  result.width = w
  result.height = 20
  result.parent = inspector

proc noteChange(prop: string) =
  refreshDesign()
  if prop == "Name" or prop == "Caption": refreshTree()
  let sel = designSelected()
  if sel != nil: setStatus(sel.name & ": " & sel.className)

proc bindEdit(ed: TEdit, comp: TComponent, prop: string) =
  ed.onChange = proc(sender: TObject) =
    if syncing: return
    try:
      comp.setProp(prop, ed.text)
      noteChange(prop)
    except CatchableError as e:
      setStatus(e.msg)

proc bindMemo(ed: TMemo, comp: TComponent, prop: string) =
  ed.onChange = proc(sender: TObject) =
    if syncing: return
    try:
      comp.setProp(prop, ed.text)
      noteChange(prop)
    except CatchableError as e:
      setStatus(e.msg)

proc bindCheck(cb: TCheckBox, comp: TComponent, prop: string) =
  cb.onClick = proc(sender: TObject) =
    if syncing: return
    try:
      comp.setProp(prop, if cb.checked: "True" else: "False")
      noteChange(prop)
    except CatchableError as e:
      setStatus(e.msg)

proc bindCombo(box: TComboBox, comp: TComponent, prop: string) =
  box.onChange = proc(sender: TObject) =
    if syncing: return
    let v = if box.itemIndex >= 0 and box.itemIndex < box.items.len: box.items[box.itemIndex] else: box.text
    try:
      comp.setProp(prop, v)
      noteChange(prop)
    except CatchableError as e:
      setStatus(e.msg)

const colorNames = [
  "clNone", "clBlack", "clWhite", "clRed", "clGreen", "clBlue", "clYellow",
  "clGray", "clSilver", "clNavy", "clTeal", "clMaroon", "clPurple", "clOlive",
  "clLime", "clAqua", "clFuchsia", "clBtnFace", "clBtnText", "clWindow",
  "clWindowText", "clHighlight", "clHighlightText", "clForm"]

proc rebuildInspector() =
  if inspector == nil: return
  syncing = true
  clearInspector()
  let comp = designSelected()
  if comp == nil:
    syncing = false
    return
  var y = 6
  for p in publishedProps(comp.className):
    let isEvent = p.kind == pkEvent
    if inspMode == "events" and not isEvent: continue
    if inspMode == "props" and isEvent: continue
    var value = ""
    try: value = getProp(comp, p.name)
    except CatchableError: value = ""
    if p.kind == pkBool:
      let cb = TCheckBox.new(ideForm)
      cb.caption = p.name
      cb.left = 8
      cb.top = y
      cb.width = 220
      cb.height = 22
      cb.checked = value.toLowerAscii in ["true", "1", "yes"]
      cb.parent = inspector
      bindCheck(cb, comp, p.name)
      y += 26
      continue
    discard addLabel(p.name, 6, y + 2, 100)
    case p.kind
    of pkEnum:
      let box = TComboBox.new(ideForm)
      box.style = csDropDownList
      box.items = p.enums
      box.left = 110
      box.top = y
      box.width = 130
      box.height = 26
      var idx = 0
      for i, n in p.enums:
        if cmpIgnoreCase(n, value) == 0: idx = i
      box.parent = inspector
      box.itemIndex = idx
      bindCombo(box, comp, p.name)
      y += 30
    of pkColor:
      let box = TComboBox.new(ideForm)
      box.style = csDropDown
      var names: seq[string] = @colorNames
      if value.len > 0 and value notin names: names.add(value)
      box.items = names
      box.text = value
      box.left = 110
      box.top = y
      box.width = 130
      box.height = 26
      box.parent = inspector
      bindCombo(box, comp, p.name)
      y += 30
    of pkStrings:
      let ed = TMemo.new(ideForm)
      ed.left = 110
      ed.top = y
      ed.width = 130
      ed.height = 52
      ed.text = value
      ed.parent = inspector
      bindMemo(ed, comp, p.name)
      y += 56
    of pkEvent:
      let ed = TEdit.new(ideForm)
      ed.left = 110
      ed.top = y
      ed.width = 130
      ed.height = 24
      ed.text = value
      ed.parent = inspector
      bindEdit(ed, comp, p.name)
      y += 28
    else:
      let ed = TEdit.new(ideForm)
      ed.left = 110
      ed.top = y
      ed.width = 130
      ed.height = 24
      ed.text = value
      ed.parent = inspector
      bindEdit(ed, comp, p.name)
      y += 28
  syncing = false

proc addBranch(parent: TTreeNode, c: TComponent) =
  let node = tree.addNode(parent, c.name & ": " & c.className, c)
  for ch in streamChildren(c):
    addBranch(node, ch)

proc refreshTree() =
  if tree == nil or current == nil: return
  syncing = true
  tree.clear()
  addBranch(nil, current.form)
  tree.expandAll()
  syncing = false

proc fillFiles() =
  ## The Code view lists unit sources. The row follows the unit that is open.
  if fileList == nil: return
  var names: seq[string] = @[]
  var idx = -1
  for i, u in units:
    names.add(u.name & ".nim")
    if u == current: idx = i
  if names != fileList.items: fileList.items = names
  if fileList.itemIndex != idx: fileList.itemIndex = idx

proc fillUnits() =
  if unitCombo == nil or proj == nil: return
  syncing = true
  unitCombo.items = proj.units
  var idx = 0
  if current != nil:
    for i, n in proj.units:
      if n == current.name: idx = i
  unitCombo.itemIndex = idx
  syncing = false
  fillFiles()

proc showUnit(u: TUnit) =
  if u == nil: return
  if current != nil and current != u:
    current.source = currentSource()
    if current.form != nil and current.form.parent != nil:
      current.form.parent = nil
  current = u
  pushEditor()
  enableDesign(u.form, host)
  refreshTree()
  fillUnits()
  if proj != nil: ideForm.caption = "Nazarus " & NazarusVersion & " - " & proj.name & " - " & u.name
  if pages.activePageIndex == 1: refreshEditor()
  else:
    refreshDesign()
    focusDesign()

proc programForms(): seq[TProgramForm] =
  for u in units:
    result.add(TProgramForm(unitName: u.name, typeName: formTypeName(u.form.name)))

proc saveUnit(u: TUnit) =
  if u == nil or proj == nil: return
  if u == current: u.source = currentSource()
  u.source = generateUnit(u.form, u.source)
  writeFile(proj.unitNim(u.name), u.source)
  writeFile(proj.unitNfm(u.name), saveNfm(u.form))
  if u == current: pushEditor()

proc saveAll() =
  if proj == nil: return
  for u in units: saveUnit(u)
  saveProject(proj)
  writeProgram(proj, programForms())
  setStatus("Saved " & proj.name)

proc closeUnits() =
  closeDesign()
  for u in units:
    if u.form != nil: freeComponent(u.form)
  units = @[]
  current = nil
  if editor != nil and editor.hasBuffer:
    syncing = true
    editor.text = ""
    syncing = false
    refreshCodeStructure()
  clearInspector()
  if tree != nil: tree.clear()
  fillFiles()

proc adopt(name: string, form: TForm, source: string): TUnit =
  result = TUnit(name: name, form: form, source: source)
  units.add(result)

proc openProjectFile(path: string) =
  if not fileExists(path):
    setStatus("No such project: " & path)
    return
  closeUnits()
  proj = loadProject(path)
  for name in proj.units:
    let nimPath = proj.unitNim(name)
    let nfmPath = proj.unitNfm(name)
    let form = TForm.new()
    if fileExists(nfmPath): loadNfm(form, readFile(nfmPath))
    else:
      form.name = "Form" & $(units.len + 1)
      form.caption = form.name
    var src = ""
    if fileExists(nimPath): src = readFile(nimPath)
    else: src = generateUnit(form, "")
    discard adopt(name, form, src)
  if units.len == 0:
    setStatus("Project has no units")
    return
  var shown = units[0]
  for u in units:
    if u.name == proj.mainUnit: shown = u
  showUnit(shown)
  setStatus(proj.name)

proc createUnit(name, formName: string): TUnit =
  let form = TForm.new()
  form.name = formName
  form.caption = formName
  let src = generateUnit(form, "")
  writeFile(proj.unitNim(name), src)
  writeFile(proj.unitNfm(name), saveNfm(form))
  proj.units.add(name)
  result = adopt(name, form, src)

proc newProjectAt(path: string) =
  var file = path
  if not file.toLowerAscii.endsWith(".npr"): file.add(".npr")
  let name = projectNameFromPath(file)
  closeUnits()
  proj = TProject(name: name, dir: file.parentDir, mainUnit: "unit1", units: @[])
  createDir(proj.dir)
  let u = createUnit("unit1", "Form1")
  proj.mainUnit = "unit1"
  saveProject(proj)
  writeProgram(proj, programForms())
  showUnit(u)
  setStatus("New project " & proj.name)

proc doNew() =
  let dlg = TSaveDialog.new(ideForm)
  dlg.title = "New project"
  dlg.filter = "Nazarus project|*.npr|All files|*"
  dlg.fileName = getCurrentDir() / "Project1.npr"
  if dlg.execute(): newProjectAt(dlg.fileName)

proc doOpen() =
  let dlg = TOpenDialog.new(ideForm)
  dlg.title = "Open project"
  dlg.filter = "Nazarus project|*.npr|All files|*"
  if dlg.execute(): openProjectFile(dlg.fileName)

proc doAddForm() =
  if proj == nil:
    setStatus("Open or create a project first")
    return
  let name = freshUnitName(proj)
  let n = name.replace("unit", "")
  let u = createUnit(name, "Form" & n)
  saveProject(proj)
  writeProgram(proj, programForms())
  showUnit(u)

proc doSave() =
  if proj == nil: doNew()
  else: saveAll()

proc drainBuild()

proc finishBuild() =
  if buildProc == nil: return
  drainBuild()
  let code = buildProc.peekExitCode()
  let outFile = if proj != nil: proj.outputFile else: ""
  close(buildProc)
  buildProc = nil
  if code == 0:
    logMsg("Compiled.\n")
    setStatus("Compiled")
    if runAfter and outFile.len > 0 and fileExists(outFile):
      runs.add(startProcess(outFile, proj.dir, [], nil, {poParentStreams}))
      setStatus("Running " & proj.name)
  else:
    logMsg("Compile failed (" & $code & ").\n")
    setStatus("Compile failed")
  runAfter = false
  if buildTimer != nil:
    buildTimer.enabled = runs.len > 0

proc drainBuild() =
  if buildProc == nil: return
  var buf: array[4096, char]
  while true:
    let n = posix.read(buildProc.outputHandle, addr buf[0], buf.len)
    if n <= 0: break
    var chunk = newString(n)
    copyMem(addr chunk[0], addr buf[0], n)
    logMsg(chunk)

proc reapRuns() =
  var kept: seq[Process]
  for p in runs:
    if p.running: kept.add(p)
    else:
      discard p.peekExitCode()
      close(p)
  let finished = kept.len < runs.len
  runs = kept
  if finished and buildProc == nil: setStatus("Program finished")

proc pollBuild(sender: TObject) =
  reapRuns()
  if buildProc == nil:
    if runs.len == 0 and buildTimer != nil: buildTimer.enabled = false
    return
  drainBuild()
  if not buildProc.running: finishBuild()

proc startBuild(andRun: bool) =
  if proj == nil:
    setStatus("Nothing to compile")
    return
  if buildProc != nil:
    setStatus("Compile already running")
    return
  saveAll()
  runAfter = andRun
  messages.text = ""
  logMsg("Compiling " & proj.name & "...\n")
  let nimExe = findExe("nim")
  if nimExe.len == 0:
    logMsg("nim compiler was not found on PATH.\n")
    setStatus("nim not found")
    return
  buildProc = startProcess(nimExe, proj.dir,
    ["c", "--hints:off", "-o:" & proj.outputFile, proj.programFile],
    nil, {poStdErrToStdOut})
  let flags = fcntl(buildProc.outputHandle, F_GETFL)
  if flags >= 0: discard fcntl(buildProc.outputHandle, F_SETFL, flags or O_NONBLOCK)
  if buildTimer == nil:
    buildTimer = TTimer.new(ideForm)
    buildTimer.interval = 120
    buildTimer.onTimer = pollBuild
  buildTimer.enabled = true
  setStatus("Compiling...")

proc projectSources(): seq[string] =
  if proj == nil: return
  for name in proj.units: result.add(proj.unitNim(name))
  result.add(proj.programFile)

proc lineCharRange(text: string, lineNo: int): tuple[start, length: int] =
  if lineNo < 1: return (-1, 0)
  var start = 0
  var n = 1
  for line in text.splitLines:
    if n == lineNo: return (start, line.runeLen)
    start += line.runeLen + 1
    inc n
  (-1, 0)

proc unitForSource(path: string): TUnit =
  if proj == nil or path.len == 0: return nil
  for u in units:
    if proj.unitNim(u.name) == path: return u

proc jumpMessage() =
  ## A click in Messages opens the unit a compiler line names.
  if messages == nil or proj == nil: return
  let lines = messages.text.splitLines
  let at = messages.caretLine()
  if at < 1 or at > lines.len: return
  let site = compilerSite(lines[at - 1], projectSources())
  if site.file.len == 0: return
  let span = lineCharRange(messages.text, at)
  if span.start >= 0: messages.selectRange(span.start, span.length)
  let u = unitForSource(site.file)
  if u == nil:
    setStatus(site.file.extractFilename & " line " & $site.line & " is not an open unit")
    return
  showUnit(u)
  showCode()
  if editor != nil: editor.gotoLine(site.line, site.col)
  setStatus(u.name & ".nim line " & $site.line)

proc doCompile() = startBuild(false)
proc doRun() = startBuild(true)

proc controlNames(root: TComponent): seq[string] =
  for c in root.ownedComponents:
    result.add(c.name)
    result.add(controlNames(c))

proc doDeclare() =
  ## F3. A proc name jumps to that routine. A component name selects it on the form.
  if editor == nil or not editor.hasBuffer:
    setStatus("Open a unit to look up a name")
    return
  refreshCodeStructure()
  let lines = editor.text.splitLines
  let lineNo = editor.caretLine
  if lineNo < 1 or lineNo > lines.len:
    setStatus("No name under the caret")
    return
  let word = identAt(lines[lineNo - 1], editor.caretColumn)
  if word.len == 0:
    setStatus("No name under the caret")
    return
  var formName = ""
  var controls: seq[string]
  if current != nil and current.form != nil:
    formName = current.form.name
    controls = controlNames(current.form)
  let hit = declarationTarget(word, codeProcs, formName, controls)
  case hit.kind
  of dkNone:
    setStatus("No declaration for " & word)
  of dkProc:
    let unitName = if current == nil: "unit" else: current.name
    # Showing Code rebuilds the buffer and moves the caret, so a jump from
    # Design looks the name up again. From Code the line is already right.
    if pages == nil or pages.activePageIndex != 1:
      showCode()
      let again = declarationTarget(word, codeProcs, "", @[])
      if again.kind != dkProc or editor == nil:
        setStatus("No declaration for " & word)
      else:
        editor.gotoLine(again.line)
        setStatus(again.name & " · " & unitName & ".nim:" & $again.line)
    elif hit.line == lineNo:
      setStatus("Already at " & hit.name)
    elif editor != nil:
      editor.gotoLine(hit.line)
      setStatus(hit.name & " · " & unitName & ".nim:" & $hit.line)
  of dkForm, dkControl:
    if current == nil or current.form == nil:
      setStatus("No declaration for " & word)
      return
    let found = if hit.kind == dkForm: TComponent(current.form)
                else: current.form.findComponent(hit.name)
    if found == nil:
      setStatus("No declaration for " & word)
      return
    showDesign()
    selectComponent(found)
    setStatus(hit.name)

proc ensureCode() =
  ## showCode reloads the unit and parks the caret on line 1.
  ## A search that is already in Code must keep the caret.
  if pages == nil: return
  if pages.activePageIndex != 1: showCode()

proc seedFind() =
  ## A single-line selection becomes the needle. A span of lines does not.
  if findEdit == nil or editor == nil: return
  if pages == nil or pages.activePageIndex != 1: return
  if not editor.hasBuffer: return
  let span = editor.selectionChars()
  if not span.any: return
  let src = editor.text
  let slice = src[byteAt(src, span.a) ..< byteAt(src, span.b)]
  if slice.len == 0 or '\n' in slice: return
  findEdit.text = slice

proc showSearch(slot: string) =
  seedFind()
  ensureCode()
  if findBar != nil: findBar.visible = true
  if slot == "replace" and replaceEdit != nil: replaceEdit.focus()
  elif slot == "line" and lineEdit != nil: lineEdit.focus()
  elif findEdit != nil: findEdit.focus()

proc searchOrigin(backward: bool): int =
  ## When the selection is the needle, the next search starts past that match.
  let src = editor.text
  let needle = if findEdit == nil: "" else: findEdit.text
  let span = editor.selectionChars()
  if span.any and needle.len > 0:
    let slice = src[byteAt(src, span.a) ..< byteAt(src, span.b)]
    if slice == needle:
      if backward: return byteAt(src, span.a)
      else: return byteAt(src, span.b)
  byteAt(src, editor.insertChars())

proc noteHit(hit: TFindHit, backward, replaced: bool) =
  if hit.index < 0:
    if replaced: setStatus("Replaced. No further matches")
    else: setStatus("Not found")
    return
  var s = if replaced: "Replaced. Next is line " & $hit.line
          else: "Found at line " & $hit.line
  if hit.wrapped:
    if backward: s.add(", from the end")
    else: s.add(", from the start")
  setStatus(s)

proc search(backward: bool) =
  if editor == nil or findEdit == nil: return
  ensureCode()
  if findBar != nil: findBar.visible = true
  let needle = findEdit.text
  if needle.len == 0:
    setStatus("Find what?")
    findEdit.focus()
    return
  if not editor.hasBuffer: return
  let hit = findLiteral(editor.text, needle, searchOrigin(backward), backward)
  if hit.index >= 0:
    editor.selectCharRange(hit.charIndex, hit.charIndex + hit.charLen)
  noteHit(hit, backward, false)

proc doFind() = showSearch("find")
proc doFindNext() = search(false)
proc doFindPrev() = search(true)
proc doReplace() = showSearch("replace")

proc replaceOne() =
  if editor == nil or findEdit == nil or replaceEdit == nil: return
  ensureCode()
  if findBar != nil: findBar.visible = true
  let needle = findEdit.text
  if needle.len == 0:
    setStatus("Find what?")
    findEdit.focus()
    return
  if not editor.hasBuffer: return
  let src = editor.text
  let span = editor.selectionChars()
  var replaced = false
  if span.any:
    let slice = src[byteAt(src, span.a) ..< byteAt(src, span.b)]
    if slice == needle:
      editor.replaceCharRange(span.a, span.b, replaceEdit.text)
      replaced = true
  let hit = findLiteral(editor.text, needle, searchOrigin(false), false)
  if hit.index >= 0:
    editor.selectCharRange(hit.charIndex, hit.charIndex + hit.charLen)
  if replaced: refreshCodeStructure()
  noteHit(hit, false, replaced)

proc doReplaceAll() =
  if editor == nil or findEdit == nil or replaceEdit == nil: return
  ensureCode()
  if findBar != nil: findBar.visible = true
  let needle = findEdit.text
  if needle.len == 0:
    setStatus("Find what?")
    findEdit.focus()
    return
  if not editor.hasBuffer: return
  let got = replaceAllLiteral(editor.text, needle, replaceEdit.text)
  if got.count == 0:
    setStatus("Not found")
    return
  editor.replaceWholeText(got.text)
  refreshCodeStructure()
  setStatus("Replaced " & $got.count)

proc doGoLine() =
  ensureCode()
  if findBar != nil: findBar.visible = true
  if lineEdit == nil or editor == nil or not editor.hasBuffer: return
  let raw = lineEdit.text.strip()
  if raw.len == 0:
    lineEdit.focus()
    return
  var n = 0
  try: n = parseInt(raw) except: n = -1
  if n < 1:
    setStatus("Not a line number")
    lineEdit.focus()
    return
  var count = editor.lineCount()
  if count < 1: count = 1
  if n > count:
    editor.gotoLine(count)
    setStatus("Only " & $count & " lines")
  else:
    editor.gotoLine(n)
    setStatus("Line " & $n)

proc doToggleView() =
  if pages == nil: return
  if pages.activePageIndex == 0: showCode() else: showDesign()

proc doQuit() = application.terminate()

proc doAbout() =
  showMessage("Nazarus " & NazarusVersion & "\nA Lazarus-style RAD GUI IDE for Nim.\nAlpha software.\nDesign the form, write Nim, press F9.")

proc doDebugNote(sender: TObject) =
  ## The Debug menu names the commands a debugger would own. None of them run yet.
  var name = "That command"
  if sender of TMenuItem:
    name = TMenuItem(sender).caption.replace("&", "")
  setStatus(name & " needs a debugger, and this version does not have one")

proc wireDesign() =
  onDesignSelect = proc(c: TComponent) =
    if syncing: return
    rebuildInspector()
    if designSelectionCount() > 1:
      setStatus($designSelectionCount() & " selected")
    elif c != nil:
      setStatus(c.name & ": " & c.className)
  onDesignChange = proc() =
    if designTool().len > 0: setStatus("Place " & designTool())
    elif designSelectionCount() > 1:
      setStatus($designSelectionCount() & " selected")
    else: setStatus("Select")
    refreshTree()
  onDesignActivate = proc(c: TComponent) =
    ensureHandler(c)
  onDesignNote = proc(s: string) = setStatus(s)

proc editingCode(): bool =
  pages != nil and pages.activePageIndex == 1

proc doCut() =
  if editingCode():
    if editor != nil: editor.editCut()
    return
  discard designCut()

proc doCopy() =
  if editingCode():
    if editor != nil: editor.editCopy()
    return
  discard designCopy()

proc doPaste() =
  if editingCode():
    if editor != nil: editor.editPaste()
    return
  discard designPaste()

proc applyLineEdit(src: string, got: TCommentEdit) =
  ## One undo step. Replace the whole span, then select the lines that moved.
  ## A move's selection is only the block, which is shorter than the span.
  let slice = got.text[got.oldStart ..< replacedFinish(src, got)]
  editor.replaceCharRange(charsBefore(src, got.oldStart), charsBefore(src, got.oldFinish),
    slice, scroll = false)
  let shown = editor.text
  let startChar = charsBefore(shown, got.newStart)
  editor.selectCharRange(startChar, charsBefore(shown, got.newFinish), caretAtStart = true)
  editor.revealChar(startChar)
  refreshCodeStructure()

proc doComment() =
  ## `#` after the indent. Every commented line in the range loses one mark.
  if not editingCode() or editor == nil or not editor.hasBuffer:
    setStatus("Switch to Code to comment")
    return
  let src = editor.text
  let span = editor.selectionChars()
  let got = toggleComment(src, byteAt(src, span.a), byteAt(src, span.b))
  applyLineEdit(src, got)
  if got.removed: setStatus("Uncommented")
  else: setStatus("Commented")

proc doShift(outward: bool) =
  ## Two spaces at the start of each line. Unindent removes one level.
  if not editingCode() or editor == nil or not editor.hasBuffer:
    setStatus("Switch to Code to indent")
    return
  let src = editor.text
  let span = editor.selectionChars()
  let got = shiftLines(src, byteAt(src, span.a), byteAt(src, span.b), 2, outward)
  if got.text != src: applyLineEdit(src, got)
  if outward: setStatus("Indented")
  else: setStatus("Unindented")

proc doMove(down: bool) =
  ## Swap the current lines with the line above or the line below.
  if not editingCode() or editor == nil or not editor.hasBuffer:
    setStatus("Switch to Code to move a line")
    return
  let src = editor.text
  let span = editor.selectionChars()
  let got = moveLines(src, byteAt(src, span.a), byteAt(src, span.b), down)
  if got.text != src: applyLineEdit(src, got)
  if got.text == src:
    if down: setStatus("At the bottom")
    else: setStatus("At the top")
  elif down: setStatus("Moved down")
  else: setStatus("Moved up")

proc doDuplicate() =
  ## Copy the current lines and leave the copy selected underneath.
  if not editingCode() or editor == nil or not editor.hasBuffer:
    setStatus("Switch to Code to duplicate a line")
    return
  let src = editor.text
  let span = editor.selectionChars()
  let got = duplicateLines(src, byteAt(src, span.a), byteAt(src, span.b))
  applyLineEdit(src, got)
  setStatus("Duplicated")

proc doDeleteLines() =
  ## Remove the current lines. The line below slides up to the caret.
  if not editingCode() or editor == nil or not editor.hasBuffer:
    setStatus("Switch to Code to delete a line")
    return
  let src = editor.text
  let span = editor.selectionChars()
  let got = deleteLines(src, byteAt(src, span.a), byteAt(src, span.b))
  if got.text != src: applyLineEdit(src, got)
  setStatus("Deleted")

proc doJoin() =
  ## The current line takes in the next one. A selection joins every line in it.
  if not editingCode() or editor == nil or not editor.hasBuffer:
    setStatus("Switch to Code to join lines")
    return
  let src = editor.text
  let span = editor.selectionChars()
  let got = joinLines(src, byteAt(src, span.a), byteAt(src, span.b))
  if got.text != src: applyLineEdit(src, got)
  if got.text == src: setStatus("Nothing to join")
  else: setStatus("Joined")

proc doInsertLine(above: bool) =
  ## A blank line above or below the current lines. It keeps their indent.
  if not editingCode() or editor == nil or not editor.hasBuffer:
    setStatus("Switch to Code to insert a line")
    return
  let src = editor.text
  let span = editor.selectionChars()
  let got = insertLine(src, byteAt(src, span.a), byteAt(src, span.b), above)
  applyLineEdit(src, got)
  if above: setStatus("Inserted above")
  else: setStatus("Inserted below")

proc doCase(upper: bool) =
  ## The selection, or the word at the caret, changes case.
  if not editingCode() or editor == nil or not editor.hasBuffer:
    setStatus("Switch to Code to change case")
    return
  let src = editor.text
  let span = editor.selectionChars()
  let got = changeCase(src, byteAt(src, span.a), byteAt(src, span.b), upper)
  if got.text != src: applyLineEdit(src, got)
  if got.text == src: setStatus("Nothing to change")
  elif upper: setStatus("Uppercase")
  else: setStatus("Lowercase")

proc armPalette(cls: string) =
  `designTool=`(cls)
  if cls.len == 0: setStatus("Select")
  else: setStatus("Place " & cls)

proc refitChromeButtons() =
  proc fit(b: TControl) =
    let ns = b.naturalSize()
    if ns.w < 2: return
    b.setBounds(b.left, b.top, ns.w + 6, max(ns.h, 24))
  if toolbar != nil:
    var rowH = 28
    for c in toolbar.childControls:
      if c of TButton:
        fit(c)
        rowH = max(rowH, c.height)
    toolbar.height = max(36, rowH + 10)
  if palette != nil:
    var rowH = 28
    for c in palette.childControls:
      if c of TButton:
        fit(c)
        rowH = max(rowH, c.height)
    # The button row, plus the frame and the horizontal bar under it.
    palette.height = rowH + 26
    palette.setMinContent(0, rowH + 4)

proc buildChrome() =
  ideForm = TForm.new()
  ideForm.caption = "Nazarus " & NazarusVersion
  ideForm.width = 1180
  ideForm.height = 760
  ideForm.position = poScreenCenter

  let menu = TMainMenu.new(ideForm)
  ideForm.menu = menu
  let mFile = menu.add("&File")
  let miNew = mFile.add("&New Project...")
  miNew.shortCut = "Ctrl+N"
  miNew.onClick = proc(sender: TObject) = doNew()
  let miOpen = mFile.add("&Open Project...")
  miOpen.shortCut = "Ctrl+O"
  miOpen.onClick = proc(sender: TObject) = doOpen()
  let miSave = mFile.add("&Save")
  miSave.shortCut = "Ctrl+S"
  miSave.onClick = proc(sender: TObject) = doSave()
  discard mFile.add("-")
  let miAdd = mFile.add("New &Form")
  miAdd.onClick = proc(sender: TObject) = doAddForm()
  discard mFile.add("-")
  let miQuit = mFile.add("&Quit")
  miQuit.shortCut = "Ctrl+Q"
  miQuit.onClick = proc(sender: TObject) = doQuit()

  let mEdit = menu.add("&Edit")
  let miCut = mEdit.add("Cu&t")
  miCut.onClick = proc(sender: TObject) = doCut()
  let miCopy = mEdit.add("&Copy")
  miCopy.onClick = proc(sender: TObject) = doCopy()
  let miPaste = mEdit.add("&Paste")
  miPaste.onClick = proc(sender: TObject) = doPaste()
  let miComment = mEdit.add("Toggle &Comment")
  miComment.shortCut = "Ctrl+/"
  miComment.onClick = proc(sender: TObject) = doComment()
  let miIndent = mEdit.add("&Indent")
  miIndent.shortCut = "Ctrl+Shift+I"
  miIndent.onClick = proc(sender: TObject) = doShift(true)
  let miUnindent = mEdit.add("&Unindent")
  miUnindent.shortCut = "Ctrl+Shift+U"
  miUnindent.onClick = proc(sender: TObject) = doShift(false)
  let miUp = mEdit.add("&Move Up")
  miUp.shortCut = "Alt+Up"
  miUp.onClick = proc(sender: TObject) = doMove(false)
  let miDown = mEdit.add("Move &Down")
  miDown.shortCut = "Alt+Down"
  miDown.onClick = proc(sender: TObject) = doMove(true)
  let miDup = mEdit.add("Duplicate &Line")
  miDup.shortCut = "Ctrl+Shift+D"
  miDup.onClick = proc(sender: TObject) = doDuplicate()
  let miDelLine = mEdit.add("Delete Lin&e")
  miDelLine.shortCut = "Ctrl+Shift+K"
  miDelLine.onClick = proc(sender: TObject) = doDeleteLines()
  let miJoin = mEdit.add("&Join Lines")
  miJoin.shortCut = "Ctrl+J"
  miJoin.onClick = proc(sender: TObject) = doJoin()
  let miBelow = mEdit.add("Insert Line &Below")
  miBelow.shortCut = "Ctrl+Enter"
  miBelow.onClick = proc(sender: TObject) = doInsertLine(false)
  let miAbove = mEdit.add("Insert Line Abo&ve")
  miAbove.shortCut = "Ctrl+Shift+Enter"
  miAbove.onClick = proc(sender: TObject) = doInsertLine(true)
  let miUpper = mEdit.add("Upperca&se")
  miUpper.shortCut = "Ctrl+Shift+X"
  miUpper.onClick = proc(sender: TObject) = doCase(true)
  let miLower = mEdit.add("Lo&wercase")
  miLower.shortCut = "Ctrl+Shift+Y"
  miLower.onClick = proc(sender: TObject) = doCase(false)
  discard mEdit.add("-")
  let mAlign = mEdit.add("&Align")
  proc alignTo(edge: TDesignAlign) =
    if designForm() == nil:
      setStatus("Open a form to align controls")
      return
    showDesign()
    let n = designAlign(edge)
    if edge in {daSpaceH, daSpaceV}:
      if n < 3: setStatus("Select three or more controls to space them")
    elif n < 2:
      setStatus("Select two or more controls to align")
  # The edge is a parameter, so each item keeps its own. A loop variable
  # would be one slot and every item would align the same way.
  proc alignItem(caption: string, edge: TDesignAlign) =
    let it = mAlign.add(caption)
    it.onClick = proc(sender: TObject) = alignTo(edge)
  alignItem("Align &Left", daLeft)
  alignItem("Align &Right", daRight)
  alignItem("Align &Top", daTop)
  alignItem("Align &Bottom", daBottom)
  alignItem("Center &Horizontally", daCenterH)
  alignItem("Center &Vertically", daCenterV)
  alignItem("Same &Width", daSameW)
  alignItem("Same Hei&ght", daSameH)
  alignItem("Same &Size", daSameSize)
  alignItem("Space &Horizontally", daSpaceH)
  alignItem("Space &Vertically", daSpaceV)
  let mOrder = mEdit.add("&Order")
  proc orderTo(front: bool) =
    if designForm() == nil:
      setStatus("Open a form to change order")
      return
    showDesign()
    let n = designOrder(front)
    if n == 0: setStatus("Select a control to change its order")
    elif front: setStatus("Brought to front")
    else: setStatus("Sent to back")
  proc orderItem(caption: string, front: bool) =
    let it = mOrder.add(caption)
    it.onClick = proc(sender: TObject) = orderTo(front)
  orderItem("&Bring to Front", true)
  orderItem("&Send to Back", false)

  let mSearch = menu.add("&Search")
  let miFind = mSearch.add("&Find...")
  miFind.shortCut = "Ctrl+F"
  miFind.onClick = proc(sender: TObject) = doFind()
  let miNext = mSearch.add("Find &Next")
  miNext.shortCut = "Ctrl+F3"
  miNext.onClick = proc(sender: TObject) = doFindNext()
  let miPrev = mSearch.add("Find &Previous")
  miPrev.shortCut = "Ctrl+Shift+F3"
  miPrev.onClick = proc(sender: TObject) = doFindPrev()
  let miReplace = mSearch.add("&Replace...")
  miReplace.shortCut = "Ctrl+R"
  miReplace.onClick = proc(sender: TObject) = doReplace()
  let miAll = mSearch.add("Replace &All")
  miAll.onClick = proc(sender: TObject) = doReplaceAll()
  discard mSearch.add("-")
  let miLine = mSearch.add("Go to &Line...")
  miLine.shortCut = "Ctrl+G"
  miLine.onClick = proc(sender: TObject) = doGoLine()

  let mView = menu.add("&View")
  let miDesign = mView.add("&Design")
  miDesign.onClick = proc(sender: TObject) =
    if not syncing: showDesign()
  let miCode = mView.add("&Code")
  miCode.onClick = proc(sender: TObject) =
    if not syncing: showCode()
  let miExplore = mView.add("&Explore")
  miExplore.shortCut = "F4"
  miExplore.onClick = proc(sender: TObject) =
    if not syncing: showExplore()
  viewItems[0] = miDesign
  viewItems[1] = miCode
  viewItems[2] = miExplore
  miDesign.checked = true
  miCode.checked = true
  miExplore.checked = true
  miCode.checked = false
  miExplore.checked = false
  discard mView.add("-")
  let miToggle = mView.add("&Toggle Design/Code")
  miToggle.shortCut = "F12"
  miToggle.onClick = proc(sender: TObject) = doToggleView()
  discard mView.add("-")
  let miToolbar = mView.add("&Toolbar")
  miToolbar.checked = true
  miToolbar.onClick = proc(sender: TObject) =
    if toolbar != nil: toolbar.visible = TMenuItem(sender).checked
  let miPalette = mView.add("Component &Palette")
  miPalette.checked = true
  miPalette.onClick = proc(sender: TObject) =
    if syncing: return
    paletteOn = TMenuItem(sender).checked
    let designing = pages == nil or pages.activePageIndex == 0
    if palette != nil: palette.visible = paletteOn and designing
  discard mView.add("-")
  let miDecl = mView.add("Go to &Declaration")
  miDecl.shortCut = "F3"
  miDecl.onClick = proc(sender: TObject) = doDeclare()

  let mRun = menu.add("&Run")
  let miRun = mRun.add("&Run")
  miRun.shortCut = "F9"
  miRun.onClick = proc(sender: TObject) = doRun()
  let miBuild = mRun.add("&Compile")
  miBuild.shortCut = "Ctrl+F9"
  miBuild.onClick = proc(sender: TObject) = doCompile()

  let mDebug = menu.add("&Debug")
  proc debugItem(caption: string) =
    let it = mDebug.add(caption)
    it.onClick = doDebugNote
  debugItem("Step &Into")
  debugItem("Step &Over")
  debugItem("Step O&ut")
  debugItem("Run to &Cursor")
  discard mDebug.add("-")
  debugItem("Toggle &Breakpoint")
  discard mDebug.add("-")
  debugItem("&Watches")
  debugItem("&Breakpoints")
  discard mDebug.add("-")
  debugItem("Debugger &Options...")

  let mHelp = menu.add("&Help")
  let miAbout = mHelp.add("&About")
  miAbout.onClick = proc(sender: TObject) = doAbout()

  statusBar = TStatusBar.new(ideForm)
  statusBar.parent = ideForm
  statusBar.align = alBottom
  statusBar.simpleText = "File - New Project, or open a .npr"

  messages = TMemo.new(ideForm)
  messages.parent = ideForm
  messages.align = alBottom
  messages.height = 110
  messages.readOnly = true
  messages.wordWrap = false
  messages.monospace = true
  messages.onClick = proc(sender: TObject) = jumpMessage()

  toolbar = TToolBar.new(ideForm)
  toolbar.parent = ideForm
  toolbar.align = alTop
  proc fitButton(b: TButton) =
    let ns = b.naturalSize()
    # A few pixels of slack keeps the theme from ellipsizing the caption.
    b.setBounds(b.left, b.top, ns.w + 6, ns.h)
  proc toolButton(caption: string, act: proc()) =
    let b = TButton.new(ideForm)
    b.caption = caption
    b.parent = toolbar
    b.onClick = proc(sender: TObject) = act()
    fitButton(b)
  toolButton("New", doNew)
  toolButton("Open", doOpen)
  toolButton("Save", doSave)
  toolButton("Compile", doCompile)
  toolButton("Run", doRun)
  toolbar.height = max(36, toolbar.childControls[^1].height + 10)
  unitCombo = TComboBox.new(ideForm)
  unitCombo.style = csDropDownList
  unitCombo.width = 140
  unitCombo.height = 26
  unitCombo.parent = toolbar
  unitCombo.onChange = proc(sender: TObject) =
    if syncing or proj == nil: return
    let i = unitCombo.itemIndex
    if i >= 0 and i < units.len: showUnit(units[i])
  # These stay on the toolbar. The notebook tabs used to sit in the page
  # that resizes, so Design and Code jumped when the side panels hid.
  proc viewButton(caption: string, act: proc()): TButton =
    result = TButton.new(ideForm)
    result.caption = caption
    result.parent = toolbar
    result.color = TColor(0xF2F2F2)
    result.onClick = proc(sender: TObject) = act()
    fitButton(result)
  viewButtons[0] = viewButton("Design", showDesign)
  viewButtons[1] = viewButton("Code", showCode)
  viewButtons[2] = viewButton("Explore", showExplore)
  viewButtons[0].color = TColor(0xD3E3F6)
  toolbar.height = max(toolbar.height, viewButtons[0].height + 10)

  palette = TScrollBox.new(ideForm)
  # lkRow has to be set before the scroll box is realized. It builds a
  # horizontal box; a layout in that scrolled window clips every caption.
  palette.layout = lkRow
  palette.parent = ideForm
  palette.align = alTop
  palette.color = clBtnFace
  var rowH = 28
  let arrow = TButton.new(ideForm)
  arrow.caption = "Arrow"
  arrow.hint = "Select"
  arrow.parent = palette
  arrow.onClick = proc(sender: TObject) = armPalette("")
  fitButton(arrow)
  rowH = max(rowH, arrow.height)
  # Each button has to close over its own class. The loop variable is one
  # slot, so a closure written in the loop would place whichever component
  # was registered last.
  proc paletteClick(cls: string): proc(sender: TObject) =
    result = proc(sender: TObject) = armPalette(cls)
  for item in paletteItems():
    let cls = item.cls
    let b = TButton.new(ideForm)
    b.caption = item.caption
    b.hint = item.category
    b.parent = palette
    b.onClick = paletteClick(cls)
    fitButton(b)
    rowH = max(rowH, b.height)
  # One row of full captions, plus room for the horizontal bar.
  palette.height = rowH + 26

  tree = TTreeView.new(ideForm)
  tree.parent = ideForm
  tree.align = alLeft
  tree.width = 190
  tree.onSelect = proc(sender: TObject, node: TTreeNode) =
    if syncing or node == nil or node.obj == nil: return
    if node.obj of TComponent:
      selectComponent(TComponent(node.obj))

  inspectorPane = TPanel.new(ideForm)
  inspectorPane.parent = ideForm
  inspectorPane.align = alRight
  inspectorPane.width = 260
  inspectorPane.bevel = bvNone
  let right = inspectorPane
  let propBtn = TButton.new(ideForm)
  propBtn.caption = "Properties"
  propBtn.align = alTop
  propBtn.height = 26
  propBtn.parent = right
  let evBtn = TButton.new(ideForm)
  evBtn.caption = "Events"
  evBtn.align = alTop
  evBtn.height = 26
  evBtn.parent = right
  inspector = TScrollBox.new(ideForm)
  inspector.parent = right
  inspector.align = alClient
  propBtn.onClick = proc(sender: TObject) =
    inspMode = "props"
    rebuildInspector()
  evBtn.onClick = proc(sender: TObject) =
    inspMode = "events"
    rebuildInspector()

  pages = TPageControl.new(ideForm)
  pages.parent = ideForm
  pages.align = alClient
  pages.showTabs = false
  designSheet = TTabSheet.new(ideForm)
  designSheet.caption = "Design"
  designSheet.parent = pages
  codeSheet = TTabSheet.new(ideForm)
  codeSheet.caption = "Code"
  codeSheet.parent = pages

  host = TScrollBox.new(ideForm)
  host.parent = designSheet
  host.align = alClient
  host.color = TColor(0x3A3A3A)

  # Files sit to the left of the editor, the way Droide lists sources beside
  # the scope rails. The procedure strip stays over the editor only.
  filePane = TPanel.new(ideForm)
  filePane.parent = codeSheet
  filePane.align = alLeft
  filePane.width = 200
  filePane.bevel = bvNone
  let fileHead = TLabel.new(ideForm)
  fileHead.parent = filePane
  fileHead.autoSize = false
  fileHead.caption = "Files"
  fileHead.align = alTop
  fileHead.height = 22
  fileList = TListBox.new(ideForm)
  fileList.parent = filePane
  fileList.align = alClient
  fileList.onClick = proc(sender: TObject) =
    if syncing: return
    let i = fileList.itemIndex
    if i >= 0 and i < units.len and units[i] != current:
      showUnit(units[i])

  let codeBody = TPanel.new(ideForm)
  codeBody.parent = codeSheet
  codeBody.align = alClient
  codeBody.bevel = bvNone

  procBar = TPanel.new(ideForm)
  procBar.parent = codeBody
  procBar.align = alTop
  procBar.bevel = bvNone
  # The procedure list is the strip across the editor, the way Visual Basic
  # filled its code window. A fixed 360px box left a long empty remainder.
  procBar.height = 28
  procCombo = TComboBox.new(ideForm)
  procCombo.parent = procBar
  procCombo.style = csDropDownList
  procCombo.align = alClient
  procCombo.onChange = proc(sender: TObject) =
    if procSync or editor == nil: return
    let i = procCombo.itemIndex
    if i <= 0: editor.gotoLine(1)
    elif i - 1 < codeProcs.len: editor.gotoLine(codeProcs[i - 1].line)

  findBar = TPanel.new(ideForm)
  findBar.parent = codeBody
  findBar.align = alTop
  findBar.height = 32
  findBar.visible = false
  findBar.bevel = bvNone
  proc searchEdit(left, width: int, cue: string): TEdit =
    result = TEdit.new(ideForm)
    result.parent = findBar
    result.left = left
    result.top = 4
    result.width = width
    result.cue = cue
  proc searchBtn(left, width: int, caption: string, act: proc()) =
    let b = TButton.new(ideForm)
    b.parent = findBar
    b.caption = caption
    b.left = left
    b.top = 3
    b.width = width
    b.height = 26
    b.onClick = proc(sender: TObject) = act()
  findEdit = searchEdit(8, 188, "Find")
  findEdit.onReturn = proc(sender: TObject) = doFindNext()
  searchBtn(202, 56, "Next", doFindNext)
  searchBtn(262, 56, "Prev", doFindPrev)
  replaceEdit = searchEdit(328, 160, "Replace")
  replaceEdit.onReturn = proc(sender: TObject) = replaceOne()
  searchBtn(494, 72, "Replace", replaceOne)
  searchBtn(572, 104, "Replace All", doReplaceAll)
  lineEdit = searchEdit(708, 64, "Line")
  lineEdit.onReturn = proc(sender: TObject) = doGoLine()
  searchBtn(778, 44, "Go", doGoLine)

  editor = TSourceEditor.new(ideForm)
  editor.parent = codeBody
  editor.align = alClient
  editor.onChange = proc(sender: TObject) = refreshCodeStructure()
  editor.onCaret = proc(line: int) =
    if procSync or procCombo == nil: return
    let at = procAtLine(line)
    let idx = if at < 0: 0 else: at + 1
    if procCombo.itemIndex != idx:
      procSync = true
      procCombo.itemIndex = idx
      procSync = false

  exploreSheet = TTabSheet.new(ideForm)
  exploreSheet.caption = "Explore"
  exploreSheet.parent = pages
  let exploreSide = TPanel.new(ideForm)
  exploreSide.parent = exploreSheet
  exploreSide.align = alLeft
  exploreSide.width = 260
  exploreSide.bevel = bvNone
  exploreFilter = TEdit.new(ideForm)
  exploreFilter.parent = exploreSide
  exploreFilter.align = alTop
  exploreFilter.text = ""
  exploreFilter.onChange = proc(sender: TObject) = refreshExplore()
  exploreIndex = TListBox.new(ideForm)
  exploreIndex.parent = exploreSide
  exploreIndex.align = alClient
  exploreIndex.onClick = proc(sender: TObject) = showExploreDetail()
  exploreIndex.onDblClick = proc(sender: TObject) = openExplore()
  exploreDetail = TMemo.new(ideForm)
  exploreDetail.parent = exploreSheet
  exploreDetail.align = alClient
  exploreDetail.readOnly = true
  exploreDetail.wordWrap = true
  exploreDetail.text = "Select a form, a component, or a proc."

  pages.onChange = proc(sender: TObject) =
    if not ready or current == nil: return
    let page = pages.activePageIndex
    useCodeChrome(page != 0)
    if page == 1: refreshEditor()
    elif page == 2: refreshExplore()
    else:
      current.source = currentSource()
      refreshDesign()

  ideForm.onShow = proc(sender: TObject) =
    # Captions were measured before any widget existed, so every palette
    # button kept the default 75px and the long ones were clipped.
    refitChromeButtons()
    if procCombo != nil and procBar != nil:
      # naturalSize clears the size request. Assigning the height lays the
      # strip out again, or the combo keeps only the width of its caption.
      let h = procCombo.naturalSize().h
      procBar.height = if h > 8: h else: procBar.height
    pushEditor()
    refreshDesign()
  ideForm.onClose = proc(sender: TObject, action: var TCloseAction) =
    action = caHide
    application.terminate()

  wireDesign()
  ready = true

proc runIde*(openPath: string, smoke: bool) =
  buildChrome()
  ideForm.show()
  if openPath.len > 0: openProjectFile(openPath)
  elif smoke:
    let dir = getTempDir() / "nazarus-smoke"
    createDir(dir)
    newProjectAt(dir / "Smoke.npr")
  if smoke:
    let t = TTimer.new(ideForm)
    t.interval = 900
    t.onTimer = proc(sender: TObject) = application.terminate()
  application.mainForm = ideForm
  application.run()
