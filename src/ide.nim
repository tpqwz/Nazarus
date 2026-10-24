## Nazarus IDE. One window: menu, toolbar, component palette, form designer,
## Nim source editor, object inspector, component tree, and a compile log.

import std/[os, osproc, posix, strutils]
import ncl
import codegen
import project

type
  TUnit = ref object
    name: string
    form: TForm
    source: string
    findFrom: int

var
  proj: TProject
  units: seq[TUnit]
  current: TUnit
  ideForm: TForm
  toolbar: TToolBar
  palette: TScrollBox
  tree: TTreeView
  inspector: TScrollBox
  pages: TPageControl
  designSheet: TTabSheet
  codeSheet: TTabSheet
  host: TScrollBox
  editor: TSourceEditor
  findBar: TPanel
  findEdit: TEdit
  messages: TMemo
  statusBar: TStatusBar
  unitCombo: TComboBox
  buildProc: Process
  buildTimer: TTimer
  runAfter = false
  syncing = false
  inspMode = "props"
  ready = false

proc doNew()
proc doOpen()
proc doSave()
proc doCompile()
proc doRun()
proc doFind()
proc doToggleView()
proc doQuit()
proc doAbout()
proc doAddForm()
proc showUnit(u: TUnit)
proc refreshTree()
proc rebuildInspector()
proc refreshEditor()

proc setStatus(s: string) =
  if statusBar != nil: statusBar.simpleText = s

proc logMsg(s: string) =
  if messages == nil: return
  var cur = messages.text
  cur.add(s)
  if cur.len > 60000: cur = cur[cur.len - 40000 .. ^1]
  messages.text = cur

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

proc refreshEditor() =
  if current == nil: return
  current.source = generateUnit(current.form, currentSource())
  pushEditor()

proc showCode() =
  if pages == nil: return
  pages.activePageIndex = 1
  refreshEditor()
  if editor != nil: editor.focus()

proc showDesign() =
  if pages == nil: return
  if current != nil and editor != nil and editor.hasBuffer:
    current.source = editor.text
  pages.activePageIndex = 0
  refreshDesign()

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
  if proj != nil: ideForm.caption = "Nazarus - " & proj.name & " - " & u.name
  if pages.activePageIndex == 1: refreshEditor()
  else: refreshDesign()

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
  clearInspector()
  if tree != nil: tree.clear()

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
  if buildTimer != nil: buildTimer.enabled = false
  if code == 0:
    logMsg("Compiled.\n")
    setStatus("Compiled")
    if runAfter and outFile.len > 0 and fileExists(outFile):
      discard startProcess(outFile, proj.dir, [], nil, {poParentStreams})
      setStatus("Running " & proj.name)
  else:
    logMsg("Compile failed (" & $code & ").\n")
    setStatus("Compile failed")
  runAfter = false

proc drainBuild() =
  if buildProc == nil: return
  var buf: array[4096, char]
  while true:
    let n = posix.read(buildProc.outputHandle, addr buf[0], buf.len)
    if n <= 0: break
    var chunk = newString(n)
    copyMem(addr chunk[0], addr buf[0], n)
    logMsg(chunk)

proc pollBuild(sender: TObject) =
  if buildProc == nil: return
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

proc doCompile() = startBuild(false)
proc doRun() = startBuild(true)

proc doFind() =
  if findBar == nil: return
  showCode()
  findBar.visible = true
  if findEdit != nil: findEdit.focus()

proc findNext() =
  if current == nil or editor == nil or findEdit == nil: return
  let needle = findEdit.text
  if needle.len == 0: return
  let src = editor.text
  var idx = src.find(needle, current.findFrom)
  if idx < 0 and current.findFrom > 0:
    idx = src.find(needle)
  if idx < 0:
    setStatus("Not found")
    current.findFrom = 0
    return
  current.findFrom = idx + max(1, needle.len)
  var line = 1
  for i in 0 ..< idx:
    if src[i] == '\n': inc line
  editor.gotoLine(line)
  setStatus("Found at line " & $line)

proc doToggleView() =
  if pages == nil: return
  if pages.activePageIndex == 0: showCode() else: showDesign()

proc doQuit() = application.terminate()

proc doAbout() =
  showMessage("Nazarus\nA Lazarus-style RAD GUI IDE for Nim.\nDesign the form, write Nim, press F9.")

proc wireDesign() =
  onDesignSelect = proc(c: TComponent) =
    if syncing: return
    rebuildInspector()
    if c != nil: setStatus(c.name & ": " & c.className)
  onDesignChange = proc() =
    if designTool().len > 0: setStatus("Place " & designTool())
    else: setStatus("Select")
    refreshTree()
  onDesignActivate = proc(c: TComponent) =
    ensureHandler(c)

proc armPalette(cls: string) =
  `designTool=`(cls)
  if cls.len == 0: setStatus("Select")
  else: setStatus("Place " & cls)

proc buildChrome() =
  ideForm = TForm.new()
  ideForm.caption = "Nazarus"
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

  let mView = menu.add("&View")
  let miToggle = mView.add("&Toggle Form/Unit")
  miToggle.shortCut = "F12"
  miToggle.onClick = proc(sender: TObject) = doToggleView()
  let miFind = mView.add("&Find...")
  miFind.shortCut = "Ctrl+F"
  miFind.onClick = proc(sender: TObject) = doFind()

  let mRun = menu.add("&Run")
  let miRun = mRun.add("&Run")
  miRun.shortCut = "F9"
  miRun.onClick = proc(sender: TObject) = doRun()
  let miBuild = mRun.add("&Compile")
  miBuild.shortCut = "Ctrl+F9"
  miBuild.onClick = proc(sender: TObject) = doCompile()

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

  toolbar = TToolBar.new(ideForm)
  toolbar.parent = ideForm
  toolbar.align = alTop
  proc toolButton(caption: string, act: proc()) =
    let b = TButton.new(ideForm)
    b.caption = caption
    b.width = 78
    b.height = 26
    b.parent = toolbar
    b.onClick = proc(sender: TObject) = act()
  toolButton("New", doNew)
  toolButton("Open", doOpen)
  toolButton("Save", doSave)
  toolButton("Compile", doCompile)
  toolButton("Run", doRun)
  unitCombo = TComboBox.new(ideForm)
  unitCombo.style = csDropDownList
  unitCombo.width = 140
  unitCombo.height = 26
  unitCombo.parent = toolbar
  unitCombo.onChange = proc(sender: TObject) =
    if syncing or proj == nil: return
    let i = unitCombo.itemIndex
    if i >= 0 and i < units.len: showUnit(units[i])

  palette = TScrollBox.new(ideForm)
  palette.parent = ideForm
  palette.align = alTop
  palette.height = 62
  palette.layout = lkWrap
  palette.color = clBtnFace
  let arrow = TButton.new(ideForm)
  arrow.caption = "Arrow"
  arrow.width = 64
  arrow.height = 24
  arrow.hint = "Select"
  arrow.parent = palette
  arrow.onClick = proc(sender: TObject) = armPalette("")
  for item in paletteItems():
    let cls = item.cls
    let cap = item.caption
    let cat = item.category
    let b = TButton.new(ideForm)
    b.caption = cap
    b.width = max(72, cap.len * 8 + 16)
    b.height = 24
    b.hint = cat
    b.parent = palette
    b.onClick = proc(sender: TObject) = armPalette(cls)

  tree = TTreeView.new(ideForm)
  tree.parent = ideForm
  tree.align = alLeft
  tree.width = 190
  tree.onSelect = proc(sender: TObject, node: TTreeNode) =
    if syncing or node == nil or node.obj == nil: return
    if node.obj of TComponent:
      selectComponent(TComponent(node.obj))

  let right = TPanel.new(ideForm)
  right.parent = ideForm
  right.align = alRight
  right.width = 260
  right.bevel = bvNone
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

  findBar = TPanel.new(ideForm)
  findBar.parent = codeSheet
  findBar.align = alTop
  findBar.height = 32
  findBar.visible = false
  findBar.bevel = bvNone
  findEdit = TEdit.new(ideForm)
  findEdit.parent = findBar
  findEdit.left = 8
  findEdit.top = 4
  findEdit.width = 220
  let findBtn = TButton.new(ideForm)
  findBtn.parent = findBar
  findBtn.caption = "Find"
  findBtn.left = 236
  findBtn.top = 3
  findBtn.width = 64
  findBtn.height = 26
  findBtn.onClick = proc(sender: TObject) = findNext()
  findEdit.onChange = proc(sender: TObject) =
    if current != nil: current.findFrom = 0

  editor = TSourceEditor.new(ideForm)
  editor.parent = codeSheet
  editor.align = alClient

  pages.onChange = proc(sender: TObject) =
    if not ready or current == nil: return
    if pages.activePageIndex == 1: refreshEditor()
    else:
      current.source = currentSource()
      refreshDesign()

  ideForm.onShow = proc(sender: TObject) =
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
