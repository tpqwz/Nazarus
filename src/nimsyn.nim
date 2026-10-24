## Nim structure for the code view. Tree-sitter (alaviss/tree-sitter-nim,
## ABI 14, runtime 0.25.6) names the procs and the block spans. GtkSourceView
## keeps the coloring. The shared library is third_party/libnimsyn.so, built
## by third_party/build-nimsyn.sh.

import std/[os, strutils]

const NimSynLib = currentSourcePath().parentDir().parentDir() / "third_party" / "libnimsyn.so"

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
  TNimOutline* = object
    ok*: bool
    procs*: seq[TNimProc]
    scopes*: seq[TNimScope]

proc ts_parser_new(): pointer {.importc, dynlib: NimSynLib.}
proc ts_parser_set_language(p, lang: pointer): bool {.importc, dynlib: NimSynLib.}
proc ts_parser_parse_string(p, old: pointer, s: cstring, n: uint32): pointer {.importc, dynlib: NimSynLib.}
proc ts_tree_delete(t: pointer) {.importc, dynlib: NimSynLib.}
proc ts_tree_root_node(t: pointer): TSNode {.importc, dynlib: NimSynLib.}
proc tree_sitter_nim(): pointer {.importc, dynlib: NimSynLib.}
proc ts_node_type(n: TSNode): cstring {.importc, dynlib: NimSynLib.}
proc ts_node_is_null(n: TSNode): bool {.importc, dynlib: NimSynLib.}
proc ts_node_is_named(n: TSNode): bool {.importc, dynlib: NimSynLib.}
proc ts_node_is_error(n: TSNode): bool {.importc, dynlib: NimSynLib.}
proc ts_node_start_byte(n: TSNode): uint32 {.importc, dynlib: NimSynLib.}
proc ts_node_end_byte(n: TSNode): uint32 {.importc, dynlib: NimSynLib.}
proc ts_node_start_point(n: TSNode): TSPoint {.importc, dynlib: NimSynLib.}
proc ts_node_end_point(n: TSNode): TSPoint {.importc, dynlib: NimSynLib.}
proc ts_node_named_child(n: TSNode, i: uint32): TSNode {.importc, dynlib: NimSynLib.}
proc ts_node_named_child_count(n: TSNode): uint32 {.importc, dynlib: NimSynLib.}
proc ts_node_child_by_field_name(n: TSNode, name: cstring, nameLen: uint32): TSNode {.importc, dynlib: NimSynLib.}

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

proc walk(src: string, n: TSNode, depth: int, outp: var TNimOutline) =
  if ts_node_is_null(n): return
  let typ = $ts_node_type(n)
  let err = ts_node_is_error(n) or typ == "ERROR"
  var next = depth
  if ts_node_is_named(n) and not err:
    let kind = scopeKind(typ)
    if kind > 0:
      let openL = int(ts_node_start_point(n).row) + 1
      let closeL = int(ts_node_end_point(n).row) + 1
      outp.scopes.add(TNimScope(openLine: openL, closeLine: closeL, depth: depth))
      if kind == 2:
        let name = routineName(src, n)
        if name.len > 0:
          outp.procs.add(TNimProc(name: name, line: openL, closeLine: closeL, depth: depth))
      next = depth + 1
  let count = int(ts_node_named_child_count(n))
  for i in 0 ..< count:
    walk(src, ts_node_named_child(n, uint32(i)), next, outp)

proc nimOutline*(src: string): TNimOutline =
  ## Procs and block spans in source order. `ok` is false when the parser
  ## library is missing or the language does not load.
  if not ensureParser(): return
  let tree = ts_parser_parse_string(parser, nil, src.cstring, uint32(src.len))
  if tree == nil: return
  walk(src, ts_tree_root_node(tree), 0, result)
  ts_tree_delete(tree)
  result.ok = true
