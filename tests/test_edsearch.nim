## Literal find and replace. No display required.
import edsearch

proc fail(msg: string) =
  stderr.writeLine("FAIL " & msg)
  quit(1)

proc expect(hit: TFindHit, index, line, column: int, wrapped: bool, what: string) =
  if hit.index != index or hit.line != line or hit.column != column or
      hit.wrapped != wrapped:
    fail(what & " got " & $hit.index & " line " & $hit.line & " col " &
      $hit.column & " wrap " & $hit.wrapped)

let fwd = findLiteral("ab cd ab", "ab", 2, false)
expect(fwd, 6, 1, 7, false, "forward")

let wrap = findLiteral("ab cd ab", "ab", 8, false)
expect(wrap, 0, 1, 1, true, "wrap forward")

let back = findLiteral("ab cd ab", "ab", 6, true)
expect(back, 0, 1, 1, false, "backward")

let wrapBack = findLiteral("ab cd ab", "ab", 0, true)
expect(wrapBack, 6, 1, 7, true, "wrap backward")

let miss = findLiteral("abc", "z", 0, false)
if miss.index != -1: fail("missing match")

let empty = findLiteral("abc", "", 0, false)
if empty.index != -1: fail("empty needle")

let second = findLiteral("bc bc", "bc", 2, false)
expect(second, 3, 1, 4, false, "skip the match under the caret")

let line2 = findLiteral("a\nload", "load", 0, false)
expect(line2, 2, 2, 1, false, "next line")

let cafe = findLiteral("café load", "load", 0, false)
if cafe.index != 6 or cafe.charIndex != 5 or cafe.column != 6 or cafe.line != 1:
  fail("utf-8 place " & $cafe.index & " char " & $cafe.charIndex &
    " col " & $cafe.column)
if byteAt("café load", cafe.charIndex) != cafe.index:
  fail("byteAt does not land on the match")

let overlap = replaceAllLiteral("aaa", "aa", "b")
if overlap.count != 1 or overlap.text != "ba":
  fail("overlap " & $overlap.count & " " & overlap.text)

let pairs = replaceAllLiteral("aaaa", "aa", "b")
if pairs.count != 2 or pairs.text != "bb":
  fail("pairs " & pairs.text)

let gone = replaceAllLiteral("a-b-a", "a", "")
if gone.count != 2 or gone.text != "-b-":
  fail("delete " & gone.text)

let keep = replaceAllLiteral("left side", "side", "hand")
if keep.count != 1 or keep.text != "left hand":
  fail("tail " & keep.text)

let none = replaceAllLiteral("abc", "z", "q")
if none.count != 0 or none.text != "abc":
  fail("replace miss")

let grown = replaceAllLiteral("a", "a", "aa")
if grown.count != 1 or grown.text != "aa":
  fail("replacement was searched again")

echo "ok"
