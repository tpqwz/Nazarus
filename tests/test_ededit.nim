## Comment and uncomment lines. No display required.
import ededit

proc fail(msg: string) =
  stderr.writeLine("FAIL " & msg)
  quit(1)

proc round(src: string, a, b: int, want: string, removed: bool, what: string) =
  let got = toggleComment(src, a, b)
  if got.removed != removed or got.text != want:
    fail(what & " [" & got.text & "] removed " & $got.removed)
  let back = toggleComment(got.text, got.newStart, got.newFinish)
  if back.text != src:
    fail(what & " did not restore [" & back.text & "]")

let src = "  if true:\n    echo 1\n"
round(src, 2, 2, "  # if true:\n    echo 1\n", false, "caret line")

round("proc greet() =\n  echo 1\n", 0, 20, "# proc greet() =\n  # echo 1\n", false, "block")

round("  # if true:\n", 0, 5, "  if true:\n", true, "uncomment")

let doc = toggleComment("## note\n", 0, 1)
if not doc.removed or doc.text != "# note\n":
  fail("doc comment [" & doc.text & "]")
let doc2 = toggleComment(doc.text, 0, 1)
if not doc2.removed or doc2.text != "note\n":
  fail("doc again [" & doc2.text & "]")

let tight = toggleComment("  #if true:\n", 0, 3)
if not tight.removed or tight.text != "  if true:\n":
  fail("hash without space [" & tight.text & "]")

# The selection ends at the start of the next line, so only the first line changes.
let edge = toggleComment("aaa\nbbb\n", 0, 4)
if edge.text != "# aaa\nbbb\n":
  fail("boundary [" & edge.text & "]")

let mid = toggleComment("aaa\nbbb\nccc\n", 0, 5)
if mid.text != "# aaa\n# bbb\nccc\n":
  fail("two lines [" & mid.text & "]")

let cafe = toggleComment("café = 1\n", 0, 0)
if cafe.text != "# café = 1\n":
  fail("utf-8 [" & cafe.text & "]")
let back = toggleComment(cafe.text, 0, 0)
if back.text != "café = 1\n":
  fail("utf-8 restore [" & back.text & "]")

let mixed = toggleComment("  # kept\n  echo 1\n", 0, 20)
if mixed.removed or mixed.text != "  # # kept\n  # echo 1\n":
  fail("mixed [" & mixed.text & "]")

proc roundShift(src: string, a, b: int, want: string, what: string) =
  let got = shiftLines(src, a, b, 2, true)
  if got.text != want:
    fail(what & " [" & got.text & "]")
  let back = shiftLines(got.text, got.newStart, got.newFinish, 2, false)
  if back.text != src:
    fail(what & " did not restore [" & back.text & "]")

roundShift("import ncl\n", 4, 4, "  import ncl\n", "caret indent")
roundShift("proc greet() =\n  echo 1\n", 0, 20, "  proc greet() =\n    echo 1\n", "block indent")
roundShift("café = 1\n", 0, 0, "  café = 1\n", "utf-8 indent")

let edgeIn = shiftLines("aaa\nbbb\n", 0, 4, 2, true)
if edgeIn.text != "  aaa\nbbb\n":
  fail("indent boundary [" & edgeIn.text & "]")

let shallow = shiftLines(" if true:\n", 0, 3, 2, false)
if shallow.text != "if true:\n":
  fail("one space [" & shallow.text & "]")

let tabbed = shiftLines("\tif true:\n", 0, 2, 2, false)
if tabbed.text != "if true:\n":
  fail("tab [" & tabbed.text & "]")

let kept = shiftLines("   echo 1\n", 0, 4, 2, false)
if kept.text != " echo 1\n":
  fail("three spaces [" & kept.text & "]")

let bare = shiftLines("import ncl\n", 0, 4, 2, false)
if bare.text != "import ncl\n":
  fail("nothing to remove [" & bare.text & "]")

proc roundMove(src: string, a, b: int, down: bool, want: string, what: string) =
  let got = moveLines(src, a, b, down)
  if got.text != want:
    fail(what & " [" & got.text & "]")
  let back = moveLines(got.text, got.newStart, got.newFinish, not down)
  if back.text != src:
    fail(what & " did not restore [" & back.text & "]")

roundMove("aaa\nbbb\nccc\n", 4, 4, true, "aaa\nccc\nbbb\n", "move down")
roundMove("aaa\nbbb\nccc\n", 8, 8, false, "aaa\nccc\nbbb\n", "move up")
roundMove("aaa\nbb\ncc\ndd\n", 4, 8, true, "aaa\ndd\nbb\ncc\n", "block down")
roundMove("café\nnext\n", 0, 0, true, "next\ncafé\n", "utf-8 move")
roundMove("aaa\nbbb", 0, 1, true, "bbb\naaa", "no final newline")

let edgeMv = moveLines("aaa\nbbb\n", 0, 4, true)
if edgeMv.text != "bbb\naaa\n":
  fail("move boundary [" & edgeMv.text & "]")

let top = moveLines("aaa\nbbb\n", 0, 1, false)
if top.text != "aaa\nbbb\n":
  fail("at top [" & top.text & "]")

let bottom = moveLines("aaa\nbbb\n", 4, 5, true)
if bottom.text != "aaa\nbbb\n":
  fail("at bottom [" & bottom.text & "]")

let swapped = moveLines("aaa\nbbb\nccc\n", 4, 4, true)
let whole = swapped.text[swapped.oldStart ..< replacedFinish("aaa\nbbb\nccc\n", swapped)]
if whole != "ccc\nbbb":
  fail("replace keeps the neighbor [" & whole & "]")
if swapped.text[swapped.newStart ..< swapped.newFinish] != "bbb":
  fail("selection is only the moved line")

proc roundDup(src: string, a, b: int, want, selected: string, what: string) =
  let got = duplicateLines(src, a, b)
  if got.text != want:
    fail(what & " [" & got.text & "]")
  if got.text[got.newStart ..< got.newFinish] != selected:
    fail(what & " selected [" & got.text[got.newStart ..< got.newFinish] & "]")
  let slice = got.text[got.oldStart ..< replacedFinish(src, got)]
  if slice != selected & "\n" & selected:
    fail(what & " slice dropped the copy [" & slice & "]")

roundDup("import ncl\nimport std\n", 0, 0, "import ncl\nimport ncl\nimport std\n", "import ncl", "one line")
roundDup("aaa\nbb\ncc\ndd\n", 4, 8, "aaa\nbb\ncc\nbb\ncc\ndd\n", "bb\ncc", "two lines")
roundDup("café\nnext\n", 0, 0, "café\ncafé\nnext\n", "café", "utf-8")
roundDup("aaa\nbbb", 4, 4, "aaa\nbbb\nbbb", "bbb", "no final newline")

let edgeDup = duplicateLines("aaa\nbbb\n", 0, 4)
if edgeDup.text != "aaa\naaa\nbbb\n":
  fail("dup boundary [" & edgeDup.text & "]")

let again = duplicateLines(edgeDup.text, edgeDup.newStart, edgeDup.newFinish)
if again.text != "aaa\naaa\naaa\nbbb\n":
  fail("dup the copy [" & again.text & "]")

proc checkDelete(src: string, a, b: int, want: string, what: string) =
  let got = deleteLines(src, a, b)
  if got.text != want:
    fail(what & " [" & got.text & "]")
  let slice = got.text[got.oldStart ..< replacedFinish(src, got)]
  if slice.len != 0:
    fail(what & " slice was not empty [" & slice & "]")
  if got.newStart != got.newFinish:
    fail(what & " caret is a selection")

checkDelete("aaa\nbbb\nccc\n", 4, 4, "aaa\nccc\n", "middle")
checkDelete("aaa\nbbb\nccc\n", 0, 1, "bbb\nccc\n", "first")
checkDelete("aaa\nbbb\nccc\n", 8, 9, "aaa\nbbb\n", "last")
checkDelete("aaa\nbbb", 4, 4, "aaa", "no final newline")
checkDelete("aaa\nbb\ncc\ndd\n", 4, 8, "aaa\ndd\n", "two lines")
checkDelete("café\nnext\n", 0, 0, "next\n", "utf-8")
checkDelete("only\n", 0, 1, "", "only line")

let edgeDel = deleteLines("aaa\nbbb\n", 0, 4)
if edgeDel.text != "bbb\n":
  fail("delete boundary [" & edgeDel.text & "]")

proc checkJoin(src: string, a, b: int, want: string, what: string) =
  let got = joinLines(src, a, b)
  if got.text != want:
    fail(what & " [" & got.text & "]")
  # The caret stays at the start of the joined line, so the selection is empty.
  # The editor still has to insert the whole joined span, or the lines vanish.
  if got.newStart != got.oldStart or got.newFinish != got.oldStart:
    fail(what & " caret left the start")
  if got.text != src:
    let tail = if got.oldFinish <= 0: src
               elif got.oldFinish >= src.len: ""
               else: src[got.oldFinish .. ^1]
    if want.len < tail.len or want[want.len - tail.len .. ^1] != tail:
      fail(what & " tail changed")
    let body = want[got.oldStart ..< want.len - tail.len]
    let slice = got.text[got.oldStart ..< replacedFinish(src, got)]
    if slice != body:
      fail(what & " slice [" & slice & "]")

checkJoin("aaa\nbbb\n", 0, 0, "aaa bbb\n", "caret")
checkJoin("  if true:\n    echo 1\n", 0, 0, "  if true: echo 1\n", "indent")
checkJoin("aaa \nbbb\n", 0, 0, "aaa bbb\n", "trailing space")
checkJoin("aaa\n\nbbb\n", 0, 0, "aaa\nbbb\n", "blank below")
checkJoin("a\nb\nc\n", 0, 5, "a b c\n", "selection")
checkJoin("café\nnext\n", 0, 0, "café next\n", "utf-8 join")
checkJoin("aaa\nbbb\n", 0, 4, "aaa bbb\n", "join boundary")

let stayed = joinLines("aaa\nbbb\n", 4, 4)
if stayed.text != "aaa\nbbb\n":
  fail("last line [" & stayed.text & "]")

let once = joinLines("a\nb\nc\n", 0, 0)
let twice = joinLines(once.text, once.newStart, once.newFinish)
if twice.text != "a b c\n":
  fail("join again [" & twice.text & "]")

proc checkInsert(src: string, a, b: int, above: bool, want, added: string,
    caret: int, what: string) =
  let got = insertLine(src, a, b, above)
  if got.text != want:
    fail(what & " [" & got.text & "]")
  if got.newStart != caret or got.newFinish != caret:
    fail(what & " caret " & $got.newStart)
  let slice = got.text[got.oldStart ..< replacedFinish(src, got)]
  if slice != added:
    fail(what & " slice [" & slice & "]")

checkInsert("aaa\nbbb\n", 0, 0, false, "aaa\n\nbbb\n", "\n", 4, "below")
checkInsert("aaa\nbbb\n", 4, 4, true, "aaa\n\nbbb\n", "\n", 4, "above")
checkInsert("  if true:\n    echo 1\n", 0, 0, false, "  if true:\n  \n    echo 1\n",
  "\n  ", 13, "below indent")
checkInsert("  if true:\n    echo 1\n", 11, 11, true, "  if true:\n    \n    echo 1\n",
  "    \n", 15, "above indent")
checkInsert("aaa\nbbb", 4, 4, false, "aaa\nbbb\n", "\n", 8, "below no final newline")
checkInsert("café\nnext\n", 0, 0, false, "café\n\nnext\n", "\n", 6, "utf-8 insert")
checkInsert("aaa\nbb\ncc\n", 0, 6, false, "aaa\nbb\n\ncc\n", "\n", 7, "below a block")
checkInsert("aaa\nbb\ncc\n", 0, 6, true, "\naaa\nbb\ncc\n", "\n", 0, "above a block")
checkInsert("a\n  b\n", 0, 6, false, "a\n  b\n  \n", "\n  ", 8, "indent of the last line")

proc checkCase(src: string, a, b: int, upper: bool, want: string, what: string) =
  let got = changeCase(src, a, b, upper)
  if got.text != want:
    fail(what & " [" & got.text & "]")
  if got.text == src: return
  if got.newStart != got.oldStart:
    fail(what & " start moved")
  let slice = got.text[got.oldStart ..< replacedFinish(src, got)]
  let body = want[got.newStart ..< got.newFinish]
  if slice != body:
    fail(what & " slice [" & slice & "]")

checkCase("AbC def", 0, 3, true, "ABC def", "selection upper")
checkCase("AbC def", 0, 3, false, "abc def", "selection lower")
checkCase("import ncl\n", 3, 3, true, "IMPORT ncl\n", "word at caret")
checkCase("import ncl\n", 6, 6, true, "IMPORT ncl\n", "caret after word")
checkCase("import ncl\n", 8, 8, false, "import ncl\n", "already lower")
checkCase("import ncl\n", 10, 7, true, "import NCL\n", "reversed selection")
checkCase("café time", 0, 0, true, "CAFÉ time", "utf-8 word")
checkCase("load_path", 4, 4, true, "LOAD_PATH", "underscore")
checkCase("   \n", 1, 1, true, "   \n", "spaces")
checkCase("IMPORT", 0, 6, true, "IMPORT", "already upper")

echo "ok"
