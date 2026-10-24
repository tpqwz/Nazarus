## The search index, without a window.
import std/strutils
import engine

proc fail(msg: string) =
  stderr.writeLine("FAIL " & msg)
  quit(1)

var index: TIndex
addDocument(index, "a.txt", "The full text index stores a posting for every word.\n")
addDocument(index, "b.txt", "A full page of text is not the same phrase.\n")
addDocument(index, "c.txt", "The café lamp is lit beside the window.\nSalt the pot, then simmer.\n")

let phrase = search(index, "\"full text\"")
if phrase.len != 1: fail("phrase count " & $phrase.len)
if index.docs[phrase[0].doc].name != "a.txt": fail("phrase doc")
if "[[full text]]" notin phrase[0].snippet: fail("phrase snippet " & phrase[0].snippet)

let both = search(index, "full text")
if both.len != 2: fail("and count " & $both.len)

let lamp = search(index, "lamp")
if lamp.len != 1: fail("lamp count")
# "The café " is nine characters. é is two bytes, so the byte offset is later.
if lamp[0].at != 9: fail("lamp char " & $lamp[0].at)
if "[[lamp]]" notin lamp[0].snippet: fail("lamp snippet " & lamp[0].snippet)

let salt = search(index, "salt simmer")
if salt.len != 1 or index.docs[salt[0].doc].name != "c.txt": fail("and salt")
if salt[0].line != 2: fail("salt line " & $salt[0].line)

if search(index, "missingword").len != 0: fail("missing")
if search(index, "Lamp").len != 1: fail("case")
if search(index, "").len != 0: fail("empty")

echo "ok"
