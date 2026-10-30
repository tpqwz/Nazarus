## Structure of a Nim unit: procs and block spans. No display required.
import std/strutils
import nimsyn

proc fail(msg: string) =
  stderr.writeLine("FAIL " & msg)
  quit(1)

let src = """
proc outer() =
  if true:
    echo "proc nope"
  # proc commented
  proc inner() =
    discard

proc exported*() =
  for i in 0 .. 1:
    discard

proc oneLine() = discard
"""

let outline = nimOutline(src)
if not outline.ok: fail("parser did not load")

var got: seq[string]
for p in outline.procs:
  got.add(p.name & ":" & $p.line & "-" & $p.closeLine & "@" & $p.depth)
let want = @["outer:1-6@0", "inner:5-6@1", "exported:8-10@0", "oneLine:12-12@0"]
if got != want:
  fail("procs " & got.join(", "))

proc scope(kind: string, openL, closeL, depth: int): bool =
  for s in outline.scopes:
    if s.openLine == openL and s.closeLine == closeL and s.depth == depth:
      return true
  false

if not scope("if", 2, 4, 1): fail("if span")
if not scope("for", 9, 10, 1): fail("for span")

for p in outline.procs:
  if p.name == "nope" or p.name == "commented" or p.name == "fake":
    fail("noise proc " & p.name)

let noisy = nimOutline("""
proc real() =
  echo """ & "\"\"\"" & """
proc fake() =
  discard
""" & "\"\"\"" & """
""")
if not noisy.ok: fail("string parse")
if noisy.procs.len != 1 or noisy.procs[0].name != "real":
  var names: seq[string]
  for p in noisy.procs: names.add(p.name)
  fail("string hid a proc " & names.join(", "))

if identAt("refreshList(self)", 1) != "refreshList": fail("ident start")
if identAt("refreshList(self)", 12) != "refreshList": fail("ident after")
if identAt("refreshList(self)", 13) != "self": fail("ident second")
if identAt("  x", 4) != "x": fail("ident pad")
if identAt("12abc", 1) != "": fail("ident digit")
if identAt("ab12", 3) != "ab12": fail("ident trail digit")
if identAt("", 1) != "": fail("ident empty")
let accented = "é name"
if identAt(accented, 4) != "name": fail("ident after accent")

let outer = TNimProc(name: "helper", line: 1, closeLine: 4, depth: 0)
let inner = TNimProc(name: "helper", line: 10, closeLine: 12, depth: 1)
let earlier = TNimProc(name: "same", line: 2, closeLine: 2, depth: 0)
let later = TNimProc(name: "same", line: 8, closeLine: 8, depth: 0)
let procs = @[outer, inner, earlier, later, TNimProc(name: "only", line: 20, closeLine: 22, depth: 0)]
let helper = declarationTarget("helper", procs, "Atlas", @["helper", "FilterEdit"])
if helper.kind != dkProc or helper.line != 1: fail("outer helper")
let same = declarationTarget("same", procs, "", @[])
if same.kind != dkProc or same.line != 2: fail("earlier same")
let only = declarationTarget("only", procs, "Atlas", @["FilterEdit"])
if only.kind != dkProc or only.line != 20: fail("only proc")
let formHit = declarationTarget("Atlas", procs, "Atlas", @["FilterEdit"])
if formHit.kind != dkForm or formHit.name != "Atlas": fail("form")
let ctrl = declarationTarget("FilterEdit", procs, "Atlas", @["FilterEdit"])
if ctrl.kind != dkControl: fail("control")
if declarationTarget("missing", procs, "Atlas", @["FilterEdit"]).kind != dkNone:
  fail("missing")
if declarationTarget("", procs, "Atlas", @[]).kind != dkNone: fail("blank")

proc jumpKey(j: TNimJump): string =
  let dir = if j.backward: "up" else: "down"
  $j.fromLine & "->" & $j.toLine & " " & dir & " c" & $j.column

proc expectJumps(label, src: string, want: seq[string]) =
  let o = nimOutline(src)
  if not o.ok: fail(label & " parser")
  var got: seq[string]
  for j in o.jumps: got.add(jumpKey(j))
  if got != want:
    fail(label & "\n got " & got.join(" | ") & "\n want " & want.join(" | "))

expectJumps("flow", """
proc outer() =
  proc inner() =
    return 1
  block outer:
    for i in 0 .. 1:
      if cond:
        break
      while going:
        continue
        break outer
    return
  block:
    break
  return
proc one() = return
proc loopBreak() =
  for i in 0 .. 1:
    block:
      break
      continue
    discard
proc lanes() =
  while going:
    if leave: return
    if ready: continue
    if also: return
    discard
  echo 1
  discard
proc share() =
  if a: return
  if b: return
  discard
proc anon() =
  let f = proc (): int =
    return 2
    0
  return 3
proc miss() =
  for i in 0 .. 1:
    break nowhere
proc quiet() =
  echo "return"
  # return
  while cond: continue
  discard
""", @[
  "7->11 down c2",
  "9->8 up c0",
  "10->12 down c0",
  "11->14 down c1",
  "13->14 down c0",
  "19->21 down c0",
  "20->17 up c1",
  "24->29 down c1",
  "25->23 up c0",
  "26->29 down c0",
  "31->33 down c0",
  "32->33 down c0",
  "36->37 down c0",
])

let capped = nimOutline("""
proc cap() =
  block a:
    block b:
      block c:
        block d:
          block e:
            block f:
              block g:
                break a
                break b
                break c
                break d
                break e
                break f
                break g
              discard
            discard
          discard
        discard
      discard
    discard
  discard
""")
if not capped.ok: fail("cap parser")
if capped.jumps.len != 6: 
  var got: seq[string]
  for j in capped.jumps: got.add(jumpKey(j))
  fail("cap count " & $capped.jumps.len & " " & got.join(" | "))
var widest = 0
var sawShort = false
for j in capped.jumps:
  if j.column < 0 or j.column > 5: fail("cap column " & $j.column)
  let span = abs(j.fromLine - j.toLine)
  if span > widest: widest = span
  if span == 1: sawShort = true
if not sawShort: fail("cap dropped the short jump")
if widest != 11: fail("cap span " & $widest)

echo "ok"
