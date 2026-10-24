## Two-way form unit writer. The designer owns fields, bindings, and the load
## proc. Event bodies are kept. A DECL block above the events is kept in place,
## so handlers can call the procs in it. Every other top-level proc is copied
## through.

import std/[strutils, tables, sets]

import ncl

const
  MarkFields0 = "# NAZARUS:FIELDS BEGIN"
  MarkFields1 = "# NAZARUS:FIELDS END"
  MarkEvents0 = "# NAZARUS:EVENTS BEGIN"
  MarkEvents1 = "# NAZARUS:EVENTS END"
  MarkBind0 = "# NAZARUS:BIND BEGIN"
  MarkBind1 = "# NAZARUS:BIND END"
  MarkDecl0 = "# NAZARUS:DECL BEGIN"
  MarkDecl1 = "# NAZARUS:DECL END"
  MarkUser0 = "# NAZARUS:USER BEGIN"
  MarkUser1 = "# NAZARUS:USER END"

proc isIdent(s: string): bool =
  if s.len == 0 or s[0] notin {'A' .. 'Z', 'a' .. 'z', '_'}: return false
  for ch in s:
    if ch notin {'A' .. 'Z', 'a' .. 'z', '0' .. '9', '_'}: return false
  result = true

proc formTypeName*(formName: string): string =
  if formName.len > 0 and formName[0] == 'T': formName else: "T" & formName

proc handlerName*(compName, event: string): string =
  var suffix = event
  if suffix.startsWith("On") and suffix.len > 2 and suffix[2] in {'A' .. 'Z'}:
    suffix = suffix[2 .. ^1]
  compName & suffix

proc procNames*(src: string): seq[tuple[name: string, line: int]] =
  ## Every top-level `proc` in a unit, with its 1-based line.
  var n = 1
  for line in src.splitLines:
    let s = line.strip
    if s.startsWith("proc "):
      var rest = s[5 .. ^1].strip
      if rest.len > 0 and rest[0] == '*':
        rest = rest[1 .. ^1].strip
      var i = 0
      while i < rest.len and rest[i] in {'A' .. 'Z', 'a' .. 'z', '_', '0' .. '9'}:
        inc i
      if i > 0:
        result.add((name: rest[0 ..< i], line: n))
    inc n

proc eventField(event: string): string =
  if event.len == 0: ""
  else: event[0].toLowerAscii & event[1 .. ^1]

proc identOfProc(line: string): string =
  var s = line.strip
  if s.startsWith("proc "): s = s[5 .. ^1].strip
  var i = 0
  while i < s.len and s[i] in {'A' .. 'Z', 'a' .. 'z', '_', '0' .. '9'}: inc i
  if i == 0: "" else: s[0 ..< i]

proc atBoundary(line: string): bool =
  line.startsWith("proc ") or line.startsWith("# NAZARUS:") or
    line.startsWith("type ") or line.startsWith("import ") or line.startsWith("from ")

proc captureBetween(src, a, b: string): string =
  let i = src.find(a)
  if i < 0: return ""
  let j = src.find(b, i + a.len)
  if j < 0: return ""
  src[i + a.len ..< j]

proc regionBody(src, a, b: string): string =
  ## Text between two markers. The begin marker's own line break is not part of it,
  ## so writing the marker back does not grow a blank line on every save.
  result = captureBetween(src, a, b)
  if result.startsWith("\r\n"): result = result[2 .. ^1]
  elif result.startsWith("\n"): result = result[1 .. ^1]

proc blankRegion(src, a, b: string): string =
  ## Drop a marked block so the procs inside it are not also copied as orphans.
  let i = src.find(a)
  if i < 0: return src
  let j = src.find(b, i + a.len)
  if j < 0: return src
  src[0 ..< i] & src[j + b.len .. ^1]

type
  TKeptProc = object
    full: string
    body: string

proc captureProcs(src: string): OrderedTable[string, TKeptProc] =
  result = initOrderedTable[string, TKeptProc]()
  let lines = src.splitLines()
  var i = 0
  while i < lines.len:
    if not lines[i].startsWith("proc "):
      inc i
      continue
    let name = identOfProc(lines[i])
    var full = ""
    var body = ""
    var depth = 0
    var sawEq = false
    while i < lines.len:
      let line = lines[i]
      if sawEq and atBoundary(line): break
      full.add(line & "\n")
      if not sawEq:
        var eqAt = -1
        var k = 0
        var d = depth
        while k < line.len:
          if line[k] == '(': inc d
          elif line[k] == ')':
            if d > 0: dec d
          elif line[k] == '=' and d == 0:
            eqAt = k
            break
          inc k
        depth = d
        if eqAt >= 0:
          sawEq = true
          let tail = line[eqAt + 1 .. ^1].strip
          if tail.len > 0: body.add(tail & "\n")
      else:
        body.add(line & "\n")
      inc i
    if name.len > 0:
      result[name] = TKeptProc(full: full, body: body)

proc extraImports(src: string): seq[string] =
  for line in src.splitLines:
    if line.startsWith("type ") or line.startsWith("# NAZARUS:FIELDS") or
        line.startsWith(MarkEvents0):
      break
    let t = line.strip
    if (t.startsWith("import ") or t.startsWith("from ")) and t != "import ncl":
      if t notin result: result.add(t)

proc sigParams(formType, sig: string): string =
  case sig
  of "paint": "self: " & formType & "; sender: TObject; canvas: TCanvas"
  of "close": "self: " & formType & "; sender: TObject; action: var TCloseAction"
  else: "self: " & formType & "; sender: TObject"

proc closureHead(sig: string): string =
  case sig
  of "paint": "proc(sender: TObject; canvas: TCanvas) = "
  of "close": "proc(sender: TObject; action: var TCloseAction) = "
  else: "proc(sender: TObject) = "

proc callTail(handler, sig: string): string =
  case sig
  of "paint": "self." & handler & "(sender, canvas)"
  of "close": "self." & handler & "(sender, action)"
  else: "self." & handler & "(sender)"

type
  TBound = object
    target: string
    field: string
    handler: string
    sig: string

proc boundEvents(form: TForm): seq[TBound] =
  var comps: seq[TComponent] = @[TComponent(form)]
  for c in form.ownedComponents: comps.add(c)
  for c in comps:
    for p in publishedProps(c.className):
      if p.kind != pkEvent: continue
      var handler = ""
      try: handler = getProp(c, p.name).strip
      except CatchableError: handler = ""
      if handler.len == 0 or not isIdent(handler): continue
      let sig = if p.sig.len > 0: p.sig else: "notify"
      let target = if c == form: "self" else: "self." & c.name
      result.add(TBound(target: target, field: eventField(p.name),
        handler: handler, sig: sig))

proc bodyOrDiscard(kept: OrderedTable[string, TKeptProc], name: string): string =
  if kept.hasKey(name) and kept[name].body.strip.len > 0: kept[name].body
  else: "  discard\n"

proc generateUnit*(form: TForm, previous: string): string =
  ## Rewrite the managed sections of a form unit. `previous` may be empty.
  let formType = formTypeName(form.name)
  let kept = captureProcs(blankRegion(previous, MarkDecl0, MarkDecl1))
  let decl = regionBody(previous, MarkDecl0, MarkDecl1)
  let user = regionBody(previous, MarkUser0, MarkUser1)

  var fields = ""
  for c in form.ownedComponents:
    if isIdent(c.name):
      fields.add("    " & c.name & "*: " & c.className & "\n")

  let events = boundEvents(form)
  var eventSet = initHashSet[string]()
  var eventBlock = ""
  for e in events:
    if e.handler in eventSet: continue
    eventSet.incl(e.handler)
    eventBlock.add("proc " & e.handler & "*(" & sigParams(formType, e.sig) & ") =\n")
    let body = bodyOrDiscard(kept, e.handler)
    eventBlock.add(body)
    if not eventBlock.endsWith("\n"): eventBlock.add("\n")

  var orphans = ""
  for name, procText in kept:
    if name in eventSet or name == "bindForm" or name.startsWith("load"): continue
    orphans.add(procText.full)
    if not orphans.endsWith("\n"): orphans.add("\n")
    orphans.add("\n")

  var wiring = ""
  for c in form.ownedComponents:
    if not isIdent(c.name): continue
    wiring.add("  self." & c.name & " = " & c.className &
      "(self.findComponent(\"" & c.name & "\"))\n")
  for e in events:
    let assign = e.target & "." & e.field & " = " & closureHead(e.sig) &
      callTail(e.handler, e.sig) & "\n"
    if e.target == "self": wiring.add("  " & assign)
    else: wiring.add("  if " & e.target & " != nil: " & assign)

  result = "# Generated by Nazarus. Event bodies and the USER section are kept.\n"
  result.add("import ncl\n")
  for imp in extraImports(previous):
    result.add(imp & "\n")
  result.add("\ntype\n  " & formType & "* = ref object of TForm\n")
  result.add("    " & MarkFields0 & "\n")
  result.add(fields)
  result.add("    " & MarkFields1 & "\n\n")
  if decl.len > 0:
    result.add(MarkDecl0 & "\n")
    result.add(decl)
    if not decl.endsWith("\n"): result.add("\n")
    result.add(MarkDecl1 & "\n\n")
  result.add(MarkEvents0 & "\n")
  result.add(eventBlock)
  result.add(MarkEvents1 & "\n\n")
  if orphans.len > 0: result.add(orphans)
  result.add("proc bindForm*(self: " & formType & ") =\n")
  result.add("  " & MarkBind0 & "\n")
  result.add(wiring)
  result.add("  " & MarkBind1 & "\n\n")
  result.add("proc load" & formType & "*(nfmPath: string): " & formType & " =\n")
  result.add("  result = newForm(" & formType & ")\n")
  result.add("  loadNfm(result, readFile(nfmPath))\n")
  result.add("  bindForm(result)\n\n")
  result.add(MarkUser0 & "\n")
  if user.len > 0: result.add(user)
  if user.len > 0 and not user.endsWith("\n"): result.add("\n")
  result.add(MarkUser1 & "\n")
