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

echo "ok"
