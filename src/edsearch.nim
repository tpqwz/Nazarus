## Literal search of an editor buffer. Case matters, the way Nim identifiers do.
## Indexes are bytes. `charIndex` is the UTF-8 character offset GtkSourceView uses.

import std/[strutils, unicode]

type
  TFindHit* = object
    index*: int
    charIndex*: int
    charLen*: int
    line*: int
    column*: int
    wrapped*: bool

proc runeStep(s: string, i: int): int =
  if i < 0 or i >= s.len: return 1
  let n = runeLenAt(s, i)
  if n <= 0: 1 else: n

proc measure(s: string, byteIndex: int): tuple[chars, line, column: int] =
  ## Characters before `byteIndex`, and the 1-based line and column there.
  var chars = 0
  var line = 1
  var column = 1
  var i = 0
  var stop = byteIndex
  if stop < 0: stop = 0
  if stop > s.len: stop = s.len
  while i < stop:
    if s[i] == '\n':
      inc line
      column = 1
      inc i
      inc chars
    else:
      let n = runeStep(s, i)
      if i + n > stop: break
      i += n
      inc chars
      inc column
  (chars, line, column)

proc charCount(s: string): int =
  var i = 0
  while i < s.len:
    i += runeStep(s, i)
    inc result

proc charsBefore*(s: string, byteIndex: int): int =
  ## UTF-8 characters before `byteIndex`.
  measure(s, byteIndex).chars

proc byteAt*(s: string, charIndex: int): int =
  ## Byte offset of the character at `charIndex`. The end of `s` when past the last.
  if charIndex <= 0: return 0
  var i = 0
  var n = 0
  while n < charIndex and i < s.len:
    if s[i] == '\n': inc i
    else: i += runeStep(s, i)
    inc n
  i

proc findLiteral*(src, needle: string, origin: int, backward: bool): TFindHit =
  ## The next literal match. Forward starts at `origin`. Backward starts before it.
  ## The search wraps once. An empty needle, or no match, leaves `index` at -1.
  result.index = -1
  if needle.len == 0: return
  var origin = origin
  if origin < 0: origin = 0
  if origin > src.len: origin = src.len
  var matches: seq[int]
  var i = 0
  while true:
    let j = src.find(needle, i)
    if j < 0: break
    matches.add(j)
    i = j + 1
  if matches.len == 0: return
  var pick = -1
  var wrapped = false
  if not backward:
    for j in matches:
      if j >= origin:
        pick = j
        break
    if pick < 0:
      pick = matches[0]
      wrapped = true
  else:
    for k in countdown(matches.high, 0):
      if matches[k] < origin:
        pick = matches[k]
        break
    if pick < 0:
      pick = matches[^1]
      wrapped = true
  let spot = measure(src, pick)
  result.index = pick
  result.charIndex = spot.chars
  result.charLen = charCount(needle)
  result.line = spot.line
  result.column = spot.column
  result.wrapped = wrapped

proc replaceAllLiteral*(src, needle, repl: string): tuple[text: string, count: int] =
  ## One left-to-right pass. A needle inside `repl` is not searched again.
  if needle.len == 0: return (src, 0)
  var i = 0
  result.text = ""
  while true:
    let j = src.find(needle, i)
    if j < 0:
      if i < src.len: result.text.add(src[i .. ^1])
      break
    if j > i: result.text.add(src[i ..< j])
    result.text.add(repl)
    inc result.count
    i = j + needle.len
  if result.count == 0: result.text = src
