## Nim structure for the code view. Tree-sitter (alaviss/tree-sitter-nim,
## ABI 14, runtime 0.25.6) names the procs, the block spans, and the
## break / continue / return landings. GtkSourceView keeps the coloring.
## The shared library is third_party/libnimsyn.so, built by
## third_party/build-nimsyn.sh.

import std/[os, strutils]

proc nimSynLib(): string =
  ## Prefer libnimsyn.so next to the executable. A source-tree build
  ## falls back to third_party/libnimsyn.so.
  let beside = getAppFilename().parentDir / "libnimsyn.so"
  if fileExists(beside):
    return beside
  currentSourcePath().parentDir().parentDir() / "third_party" / "libnimsyn.so"

type
  TSPoint {.bycopy.} = object
    row: uint32
    column: uint32
  TSNode {.bycopy.} = object
    context: array[4, uint32]
    id: pointer
    tree: pointer
  TNimProc* = object
    name*: string
    line*: int
    closeLine*: int
    depth*: int
  TNimScope* = object
    openLine*: int
    closeLine*: int
    depth*: int
  TNimJump* = object
    ## `column` 0 is the lane nearest the code. `backward` is a continue.
    fromLine*, toLine*, column*: int
    backward*: bool
  TNimOutline* = object
    ok*: bool
    procs*: seq[TNimProc]
    scopes*: seq[TNimScope]
    jumps*: seq[TNimJump]

proc ts_parser_new(): pointer {.importc, dynlib: nimSynLib().}
proc ts_parser_set_language(p, lang: pointer): bool {.importc, dynlib: nimSynLib().}
proc ts_parser_parse_string(p, old: pointer, s: cstring, n: uint32): pointer {.importc, dynlib: nimSynLib().}
proc ts_tree_delete(t: pointer) {.importc, dynlib: nimSynLib().}
proc ts_tree_root_node(t: pointer): TSNode {.importc, dynlib: nimSynLib().}
proc tree_sitter_nim(): pointer {.importc, dynlib: nimSynLib().}
proc ts_node_type(n: TSNode): cstring {.importc, dynlib: nimSynLib().}
proc ts_node_is_null(n: TSNode): bool {.importc, dynlib: nimSynLib().}
proc ts_node_is_named(n: TSNode): bool {.importc, dynlib: nimSynLib().}
proc ts_node_is_error(n: TSNode): bool {.importc, dynlib: nimSynLib().}
proc ts_node_start_byte(n: TSNode): uint32 {.importc, dynlib: nimSynLib().}
proc ts_node_end_byte(n: TSNode): uint32 {.importc, dynlib: nimSynLib().}
proc ts_node_start_point(n: TSNode): TSPoint {.importc, dynlib: nimSynLib().}
proc ts_node_end_point(n: TSNode): TSPoint {.importc, dynlib: nimSynLib().}
proc ts_node_named_child(n: TSNode, i: uint32): TSNode {.importc, dynlib: nimSynLib().}
proc ts_node_named_child_count(n: TSNode): uint32 {.importc, dynlib: nimSynLib().}
proc ts_node_child_by_field_name(n: TSNode, name: cstring, nameLen: uint32): TSNode {.importc, dynlib: nimSynLib().}

var
  parser: pointer
  tried = false
  ready = false

proc ensureParser(): bool =
  if tried: return ready
  tried = true
  try:
    let lang = tree_sitter_nim()
    parser = ts_parser_new()
    if parser != nil and lang != nil and ts_parser_set_language(parser, lang):
      ready = true
  except CatchableError as e:
    stderr.writeLine("Nazarus: Nim syntax tree unavailable (" & e.msg & ")")
  ready

proc scopeKind(typ: string): int =
  ## 2 is a named routine. 1 is another block. 0 is not a scope.
  case typ
  of "proc_declaration", "func_declaration", "method_declaration",
     "iterator_declaration", "converter_declaration",
     "template_declaration", "macro_declaration":
    2
  of "proc_expression", "func_expression", "iterator_expression", "do_block",
     "block", "if", "elif_branch", "else_branch", "when", "case", "of_branch",
     "for", "while", "try", "except_branch", "finally_branch":
    1
  else:
    0

proc nodeText(src: string, n: TSNode): string =
  let a = int(ts_node_start_byte(n))
  let b = int(ts_node_end_byte(n))
  if a < 0 or b > src.len or a > b: return ""
  src[a ..< b]

proc routineName(src: string, n: TSNode): string =
  let name = ts_node_child_by_field_name(n, "name", 4)
  if ts_node_is_null(name): return ""
  if $ts_node_type(name) == "identifier":
    return nodeText(src, name)
  let kids = int(ts_node_named_child_count(name))
  for i in 0 ..< kids:
    let ch = ts_node_named_child(name, uint32(i))
    if $ts_node_type(ch) == "identifier":
      return nodeText(src, ch)
  nodeText(src, name).strip(chars = {'*', '`', ' ', '\n'})

proc blockLabel(src: string, n: TSNode): string =
  ## A `block outer:` stores its name in the label field.
  let lab = ts_node_child_by_field_name(n, "label", 5)
  if ts_node_is_null(lab): return ""
  if $ts_node_type(lab) == "identifier": return nodeText(src, lab)
  let kids = int(ts_node_named_child_count(lab))
  for i in 0 ..< kids:
    let ch = ts_node_named_child(lab, uint32(i))
    if $ts_node_type(ch) == "identifier":
      return nodeText(src, ch)
  nodeText(src, lab).strip(chars = {'`', '*', ' ', '\n'})

proc jumpLabel(src: string, n: TSNode): string =
  ## `break outer` keeps the name as a bare identifier, not a field.
  let kids = int(ts_node_named_child_count(n))
  for i in 0 ..< kids:
    let ch = ts_node_named_child(n, uint32(i))
    if $ts_node_type(ch) == "identifier":
      return nodeText(src, ch)
  ""

type
  TFrameKind = enum fkBlock, fkLoop, fkRoutine
  TFrame = object
    kind: TFrameKind
    name: string
    openLine, closeLine: int

proc jumpsClash(a, b: TNimJump): bool =
  ## Same landing shares a lane. Any other shared line needs its own lane.
  let a0 = min(a.fromLine, a.toLine)
  let a1 = max(a.fromLine, a.toLine)
  let b0 = min(b.fromLine, b.toLine)
  let b1 = max(b.fromLine, b.toLine)
  if a1 < b0 or b1 < a0: return false
  if a.toLine == b.toLine and a.backward == b.backward: return false
  true

proc placeJumps(jumps: var seq[TNimJump]) =
  ## Column 0 is nearest the code, so the shortest span takes it.
  ## A jump that would need a seventh lane is left out.
  for j in jumps.mitems: j.column = -1
  var pending = jumps.len
  while pending > 0:
    var best = -1
    for i, j in jumps:
      if j.column != -1: continue
      if best < 0: best = i
      else:
        let si = abs(j.fromLine - j.toLine)
        let sb = abs(jumps[best].fromLine - jumps[best].toLine)
        if si < sb or (si == sb and j.fromLine < jumps[best].fromLine):
          best = i
    if best < 0: break
    var col = 0
    var placed = false
    while col < 6:
      var clash = false
      for other in jumps:
        if other.column != col: continue
        if jumpsClash(jumps[best], other):
          clash = true
          break
      if not clash:
        jumps[best].column = col
        placed = true
        break
      inc col
    if not placed: jumps[best].column = -2
    dec pending
  var kept: seq[TNimJump]
  for j in jumps:
    if j.column >= 0: kept.add(j)
  jumps = kept

proc considerJump(src: string, n: TSNode, typ: string, frames: seq[TFrame],
    outp: var TNimOutline) =
  ## continue lands on the innermost loop head. break lands on the line
  ## after the innermost loop or block, or after the named block.
  ## return lands on the last line of the innermost routine.
  ## Nim rejects a label on continue, so a label there is ignored.
  let fromL = int(ts_node_start_point(n).row) + 1
  var toL = 0
  var back = false
  if typ == "return_statement":
    for i in countdown(frames.len - 1, 0):
      if frames[i].kind == fkRoutine:
        toL = frames[i].closeLine
        break
  elif typ == "continue_statement":
    for i in countdown(frames.len - 1, 0):
      if frames[i].kind == fkLoop:
        toL = frames[i].openLine
        back = true
        break
  elif typ == "break_statement":
    let label = jumpLabel(src, n)
    for i in countdown(frames.len - 1, 0):
      let fr = frames[i]
      if fr.kind != fkBlock and fr.kind != fkLoop: continue
      if label.len == 0 or fr.name == label:
        toL = fr.closeLine + 1
        break
  if toL < 1 or toL == fromL: return
  outp.jumps.add(TNimJump(fromLine: fromL, toLine: toL, column: -1, backward: back))

proc walk(src: string, n: TSNode, depth: int, frames: var seq[TFrame],
    outp: var TNimOutline) =
  if ts_node_is_null(n): return
  let typ = $ts_node_type(n)
  let err = ts_node_is_error(n) or typ == "ERROR"
  var next = depth
  var pushed = false
  if ts_node_is_named(n) and not err:
    let kind = scopeKind(typ)
    if kind > 0:
      let openL = int(ts_node_start_point(n).row) + 1
      let closeL = int(ts_node_end_point(n).row) + 1
      outp.scopes.add(TNimScope(openLine: openL, closeLine: closeL, depth: depth))
      let rname = if kind == 2 or typ in ["proc_expression", "func_expression",
          "iterator_expression"]: routineName(src, n) else: ""
      if kind == 2 and rname.len > 0:
        outp.procs.add(TNimProc(name: rname, line: openL, closeLine: closeL, depth: depth))
      next = depth + 1
      var fr: TFrame
      fr.openLine = openL
      fr.closeLine = closeL
      if kind == 2 or typ in ["proc_expression", "func_expression", "iterator_expression"]:
        fr.kind = fkRoutine
        fr.name = rname
        frames.add(fr)
        pushed = true
      elif typ == "for" or typ == "while":
        fr.kind = fkLoop
        frames.add(fr)
        pushed = true
      elif typ == "block":
        fr.kind = fkBlock
        fr.name = blockLabel(src, n)
        frames.add(fr)
        pushed = true
    elif typ in ["break_statement", "continue_statement", "return_statement"]:
      considerJump(src, n, typ, frames, outp)
  let count = int(ts_node_named_child_count(n))
  for i in 0 ..< count:
    walk(src, ts_node_named_child(n, uint32(i)), next, frames, outp)
  if pushed: discard frames.pop()

type
  TDeclKind* = enum dkNone, dkProc, dkForm, dkControl
  TDeclTarget* = object
    kind*: TDeclKind
    name*: string
    line*: int

proc identAt*(line: string, column: int): string =
  ## `column` is the GTK caret: one plus the number of characters before it.
  ## A caret sitting just after an identifier still names that identifier.
  if column < 1 or line.len == 0: return ""
  var starts: seq[int]
  var i = 0
  while i < line.len:
    starts.add(i)
    let c = uint8(line[i])
    if c < 0x80: inc i
    elif (c and 0xE0) == 0xC0: i += 2
    elif (c and 0xF0) == 0xE0: i += 3
    elif (c and 0xF8) == 0xF0: i += 4
    else: inc i
    if i > line.len: i = line.len
  proc wordAt(charIndex: int): bool =
    if charIndex < 0 or charIndex >= starts.len: return false
    line[starts[charIndex]] in {'A' .. 'Z', 'a' .. 'z', '0' .. '9', '_'}
  var idx = column - 1
  if idx > starts.len: idx = starts.len
  if not wordAt(idx): dec idx
  if not wordAt(idx): return ""
  var a = idx
  while wordAt(a - 1): dec a
  var b = idx + 1
  while wordAt(b): inc b
  if line[starts[a]] in {'0' .. '9'}: return ""
  let fromB = starts[a]
  let toB = if b < starts.len: starts[b] else: line.len
  line[fromB ..< toB]

proc declarationTarget*(word: string, procs: seq[TNimProc], formName: string,
    controlNames: seq[string]): TDeclTarget =
  ## Where F3 should go. A proc wins over a form or a control of the same name.
  ## Two routines with one name resolve to the outer one, then the earlier one.
  if word.len == 0: return
  var best = -1
  for i, p in procs:
    if p.name != word: continue
    if best < 0 or p.depth < procs[best].depth or
        (p.depth == procs[best].depth and p.line < procs[best].line):
      best = i
  if best >= 0:
    return TDeclTarget(kind: dkProc, name: word, line: procs[best].line)
  if formName.len > 0 and word == formName:
    return TDeclTarget(kind: dkForm, name: word)
  for n in controlNames:
    if n == word:
      return TDeclTarget(kind: dkControl, name: word)

proc nimOutline*(src: string): TNimOutline =
  ## Procs and block spans in source order. `ok` is false when the parser
  ## library is missing or the language does not load.
  if not ensureParser(): return
  let tree = ts_parser_parse_string(parser, nil, src.cstring, uint32(src.len))
  if tree == nil: return
  var frames: seq[TFrame]
  walk(src, ts_tree_root_node(tree), 0, frames, result)
  ts_tree_delete(tree)
  placeJumps(result.jumps)
  result.ok = true
