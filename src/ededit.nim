## Line edits for the code editor. A Nim comment is `#` after the indent.
## Indent is a run of spaces at the start of each whole line.

import std/strutils
import std/unicode

type
  TCommentEdit* = object
    text*: string
    oldStart*: int
    oldFinish*: int
    newStart*: int
    newFinish*: int
    removed*: bool

proc indentOf(line: string): int =
  while result < line.len and line[result] in {' ', '\t'}:
    inc result

proc commentLine(line: string): string =
  let i = indentOf(line)
  if i == line.len: return line & "# "
  line[0 ..< i] & "# " & line[i .. ^1]

proc uncommentLine(line: string): string =
  let i = indentOf(line)
  if i >= line.len or line[i] != '#': return line
  var rest = i + 1
  if rest < line.len and line[rest] == ' ': inc rest
  line[0 ..< i] & line[rest .. ^1]

proc commented(lines: seq[string]): bool =
  ## True when every line that has text is already a comment, and at least one is.
  var any = false
  for line in lines:
    let i = indentOf(line)
    if i == line.len: continue
    if line[i] != '#': return false
    any = true
  any

proc spanLines(src: string, a, b: int): tuple[start, finish: int] =
  ## Bytes of the whole lines touched by [a, b). A caret uses its own line.
  ## A selection that ends on the first byte of a line does not include that line.
  var a = a
  var b = b
  if a < 0: a = 0
  if b < 0: b = 0
  if a > src.len: a = src.len
  if b > src.len: b = src.len
  if b < a:
    let t = a
    a = b
    b = t
  var start = a
  while start > 0 and src[start - 1] != '\n':
    dec start
  var last = b
  if a != b and last > a and src[last - 1] == '\n':
    dec last
  if last < start: last = start
  var finish = last
  while finish < src.len and src[finish] != '\n':
    inc finish
  (start, finish)

proc toggleComment*(src: string, a, b: int): TCommentEdit =
  ## Comment the lines in the range, or remove one `#` when they are all comments.
  let span = spanLines(src, a, b)
  let chunk = src[span.start ..< span.finish]
  let lines = chunk.split('\n')
  let remove = commented(lines)
  var outLines = newSeq[string](lines.len)
  for i, line in lines:
    if remove: outLines[i] = uncommentLine(line)
    else: outLines[i] = commentLine(line)
  let replaced = outLines.join("\n")
  result.text = src[0 ..< span.start] & replaced & src[span.finish .. ^1]
  result.oldStart = span.start
  result.oldFinish = span.finish
  result.newStart = span.start
  result.newFinish = span.start + replaced.len
  result.removed = remove

proc unindentLine(line: string, width: int): string =
  ## One level: a leading tab, or up to `width` spaces. Other text stays.
  if line.len == 0: return line
  if line[0] == '\t': return line[1 .. ^1]
  var n = 0
  while n < width and n < line.len and line[n] == ' ':
    inc n
  line[n .. ^1]

proc shiftLines*(src: string, a, b: int, width: int, outward: bool): TCommentEdit =
  ## Indent or unindent the whole lines touched by [a, b). `width` is in spaces.
  let span = spanLines(src, a, b)
  let lines = src[span.start ..< span.finish].split('\n')
  var outLines = newSeq[string](lines.len)
  let step = if width < 1: 1 else: width
  for i, line in lines:
    if outward: outLines[i] = " ".repeat(step) & line
    else: outLines[i] = unindentLine(line, step)
  let replaced = outLines.join("\n")
  result.text = src[0 ..< span.start] & replaced & src[span.finish .. ^1]
  result.oldStart = span.start
  result.oldFinish = span.finish
  result.newStart = span.start
  result.newFinish = span.start + replaced.len
  result.removed = not outward

proc tailFrom(src: string, i: int): string =
  if i <= 0: src
  elif i >= src.len: ""
  else: src[i .. ^1]

proc lineBefore(src: string, start: int): tuple[start, finish: int, ok: bool] =
  ## The line above `start`, which is the first byte of a line.
  if start <= 0 or src[start - 1] != '\n': return
  var s = start - 1
  while s > 0 and src[s - 1] != '\n':
    dec s
  (s, start - 1, true)

proc lineAfter(src: string, finish: int): tuple[start, finish: int, ok: bool] =
  ## The line below `finish`, which is the newline ending a line, or past the end.
  if finish >= src.len or src[finish] != '\n': return
  let s = finish + 1
  if s >= src.len: return
  var f = s
  while f < src.len and src[f] != '\n':
    inc f
  (s, f, true)

proc replacedFinish*(src: string, got: TCommentEdit): int =
  ## End of the edited span in `got.text`. The selection may be only part of it.
  got.text.len - (src.len - got.oldFinish)

proc keepSpan(src: string, span: tuple[start, finish: int]): TCommentEdit =
  result.text = src
  result.oldStart = span.start
  result.oldFinish = span.finish
  result.newStart = span.start
  result.newFinish = span.finish

proc moveLines*(src: string, a, b: int, down: bool): TCommentEdit =
  ## Swap the touched lines with the line above or below. The ends stay put.
  let span = spanLines(src, a, b)
  if not down:
    let prev = lineBefore(src, span.start)
    if not prev.ok: return keepSpan(src, span)
    let chunk = src[span.start ..< span.finish]
    let neighbor = src[prev.start ..< prev.finish]
    let replaced = chunk & "\n" & neighbor
    result.text = src[0 ..< prev.start] & replaced & tailFrom(src, span.finish)
    result.oldStart = prev.start
    result.oldFinish = span.finish
    result.newStart = prev.start
    result.newFinish = prev.start + chunk.len
    return
  let nxt = lineAfter(src, span.finish)
  if not nxt.ok: return keepSpan(src, span)
  let chunk = src[span.start ..< span.finish]
  let neighbor = src[nxt.start ..< nxt.finish]
  let replaced = neighbor & "\n" & chunk
  result.text = src[0 ..< span.start] & replaced & tailFrom(src, nxt.finish)
  result.oldStart = span.start
  result.oldFinish = nxt.finish
  result.newStart = span.start + neighbor.len + 1
  result.newFinish = result.newStart + chunk.len

proc duplicateLines*(src: string, a, b: int): TCommentEdit =
  ## Copy the touched lines. The copy sits underneath and stays selected.
  let span = spanLines(src, a, b)
  let chunk = src[span.start ..< span.finish]
  let replaced = chunk & "\n" & chunk
  result.text = src[0 ..< span.start] & replaced & tailFrom(src, span.finish)
  result.oldStart = span.start
  result.oldFinish = span.finish
  result.newStart = span.start + chunk.len + 1
  result.newFinish = result.newStart + chunk.len

proc deleteLines*(src: string, a, b: int): TCommentEdit =
  ## Remove the touched lines and the break that followed them.
  ## A last line with no break of its own takes the break above it.
  let span = spanLines(src, a, b)
  var startAt = span.start
  var endAt = span.finish
  if endAt < src.len and src[endAt] == '\n':
    inc endAt
  elif startAt > 0 and src[startAt - 1] == '\n':
    dec startAt
  if startAt == 0: result.text = tailFrom(src, endAt)
  else: result.text = src[0 ..< startAt] & tailFrom(src, endAt)
  result.oldStart = startAt
  result.oldFinish = endAt
  result.newStart = startAt
  result.newFinish = startAt

proc trimEndSpaces(line: string): string =
  var n = line.len
  while n > 0 and line[n - 1] in {' ', '\t'}:
    dec n
  if n == line.len: line
  elif n == 0: ""
  else: line[0 ..< n]

proc joined(lines: seq[string]): string =
  ## One space between lines. The first line keeps its indent. Blank lines drop out.
  for i, line in lines:
    if i == 0:
      result = trimEndSpaces(line)
    else:
      let rest = tailFrom(line, indentOf(line))
      if rest.len == 0: continue
      if result.len > 0 and result[^1] != ' ':
        result.add ' '
      result.add rest

proc joinLines*(src: string, a, b: int): TCommentEdit =
  ## Join the touched lines. A single line also takes in the line below it.
  var span = spanLines(src, a, b)
  if '\n' notin src[span.start ..< span.finish]:
    let nxt = lineAfter(src, span.finish)
    if not nxt.ok: return keepSpan(src, span)
    span.finish = nxt.finish
  let merged = joined(src[span.start ..< span.finish].split('\n'))
  if span.start == 0: result.text = merged & tailFrom(src, span.finish)
  else: result.text = src[0 ..< span.start] & merged & tailFrom(src, span.finish)
  result.oldStart = span.start
  result.oldFinish = span.finish
  result.newStart = span.start
  result.newFinish = span.start

proc indentText(line: string): string =
  let n = indentOf(line)
  if n <= 0: ""
  else: line[0 ..< n]

proc insertLine*(src: string, a, b: int, above: bool): TCommentEdit =
  ## A blank line above the touched lines, or below them.
  ## It copies the indent of the line it sits against. The caret follows that indent.
  let span = spanLines(src, a, b)
  if above:
    var i = span.start
    while i < span.finish and src[i] != '\n':
      inc i
    let indent = indentText(src[span.start ..< i])
    let added = indent & "\n"
    let at = span.start
    result.text = src[0 ..< at] & added & tailFrom(src, at)
    result.oldStart = at
    result.oldFinish = at
    result.newStart = at + indent.len
    result.newFinish = result.newStart
    return
  var lineStart = span.finish
  while lineStart > span.start and src[lineStart - 1] != '\n':
    dec lineStart
  let indent = indentText(src[lineStart ..< span.finish])
  let added = "\n" & indent
  let at = span.finish
  result.text = src[0 ..< at] & added & tailFrom(src, at)
  result.oldStart = at
  result.oldFinish = at
  result.newStart = at + added.len
  result.newFinish = result.newStart

proc wordRune(r: Rune): bool =
  r == Rune('_') or unicode.isAlpha(r) or (uint32(r) <= 127 and chr(uint32(r)) in {'0'..'9'})

proc prevRuneStart(s: string, i: int): int =
  if i <= 0: return 0
  var j = i - 1
  while j > 0 and (uint(s[j]) shr 6) == 0b10'u: dec j
  j

proc wordAt(src: string, at: int): tuple[a, b: int] =
  ## The word touching `at`. A caret just after a word still takes that word.
  result = (at, at)
  if src.len == 0: return
  var i = at
  if i < 0: i = 0
  elif i > src.len: i = src.len
  var origin = -1
  if i < src.len:
    var r: Rune
    fastRuneAt(src, i, r, false)
    if wordRune(r): origin = i
  if origin < 0 and i > 0:
    let p = prevRuneStart(src, i)
    var r: Rune
    fastRuneAt(src, p, r, false)
    if wordRune(r): origin = p
  if origin < 0: return
  var start = origin
  while start > 0:
    let p = prevRuneStart(src, start)
    var r: Rune
    fastRuneAt(src, p, r, false)
    if not wordRune(r): break
    start = p
  var finish = start
  while finish < src.len:
    var r: Rune
    fastRuneAt(src, finish, r, false)
    if not wordRune(r): break
    let n = runeLenAt(src, finish)
    if n <= 0: break
    finish += n
  result = (start, finish)

proc changeCase*(src: string, a, b: int, upper: bool): TCommentEdit =
  ## Upper or lower case. A selection covers that text. A caret covers its word.
  var a = a
  var b = b
  if a > b:
    let t = a
    a = b
    b = t
  if a < 0: a = 0
  if b < 0: b = 0
  if a > src.len: a = src.len
  if b > src.len: b = src.len
  if a == b:
    let w = wordAt(src, a)
    a = w.a
    b = w.b
  if a >= b:
    result.text = src
    result.oldStart = a
    result.oldFinish = a
    result.newStart = a
    result.newFinish = a
    return
  let chunk = src[a ..< b]
  let cased = if upper: unicode.toUpper(chunk) else: unicode.toLower(chunk)
  if a == 0: result.text = cased & tailFrom(src, b)
  else: result.text = src[0 ..< a] & cased & tailFrom(src, b)
  result.oldStart = a
  result.oldFinish = b
  result.newStart = a
  result.newFinish = a + cased.len
