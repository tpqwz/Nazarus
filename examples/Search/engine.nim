## A small full-text index. Words are stored lowercase with the character
## offset of each occurrence. A query is a set of words, or a quoted phrase
## whose words have to follow one another. Snippets are slices of the
## original text with the match marked.

import std/[algorithm, os, strutils, tables, unicode]

type
  TToken = object
    at: int
    len: int
    word: string
  TDocument* = object
    path*: string
    name*: string
    text*: string
    starts: seq[int]
    tokens: seq[TToken]
  TPosting = object
    doc: int
    token: int
  THit* = object
    doc*: int
    at*: int
    len*: int
    line*: int
    snippet*: string
  TClause = object
    words: seq[string]
  TIndex* = object
    docs*: seq[TDocument]
    terms: Table[string, seq[TPosting]]

proc charStarts(text: string): seq[int] =
  var i = 0
  while i < text.len:
    result.add(i)
    let c = uint8(text[i])
    var n = 1
    if c >= 0xF0'u8: n = 4
    elif c >= 0xE0'u8: n = 3
    elif c >= 0xC0'u8: n = 2
    if i + n > text.len: n = text.len - i
    inc i, n
  result.add(text.len)

proc charCount(doc: TDocument): int = max(0, doc.starts.len - 1)

proc sliceChars(doc: TDocument, a, b: int): string =
  let n = charCount(doc)
  let lo = max(0, min(a, n))
  let hi = max(lo, min(b, n))
  if lo == hi: return ""
  doc.text[doc.starts[lo] ..< doc.starts[hi]]

proc wordChar(doc: TDocument, ci: int): bool =
  if ci < 0 or ci >= charCount(doc): return false
  let b = doc.text[doc.starts[ci]]
  b in {'A' .. 'Z', 'a' .. 'z', '0' .. '9'} or uint8(b) >= 128'u8

proc breakChar(doc: TDocument, ci: int): bool =
  if ci < 0 or ci >= charCount(doc): return true
  doc.text[doc.starts[ci]] in {' ', '\n', '\t', '\r'}

proc tokenize(text: string): seq[TToken] =
  var doc: TDocument
  doc.text = text
  doc.starts = charStarts(text)
  let n = charCount(doc)
  var i = 0
  while i < n:
    if not wordChar(doc, i):
      inc i
      continue
    let at = i
    inc i
    while i < n and wordChar(doc, i): inc i
    result.add(TToken(at: at, len: i - at, word: toLower(sliceChars(doc, at, i))))

proc indexDoc(index: var TIndex, di: int) =
  for ti, tok in index.docs[di].tokens:
    index.terms.mgetOrPut(tok.word, @[]).add(TPosting(doc: di, token: ti))

proc addDocument*(index: var TIndex, path, text: string) =
  var doc: TDocument
  doc.path = path
  doc.name = path.extractFilename
  doc.text = text
  doc.starts = charStarts(text)
  doc.tokens = tokenize(text)
  var replaced = false
  for i, old in index.docs:
    if old.path == path:
      index.docs[i] = doc
      replaced = true
      break
  if not replaced: index.docs.add(doc)
  index.terms.clear()
  for i in 0 ..< index.docs.len:
    indexDoc(index, i)

proc parseQuery(query: string): seq[TClause] =
  var doc: TDocument
  doc.text = query
  doc.starts = charStarts(query)
  let n = charCount(doc)
  var i = 0
  while i < n:
    let ch = doc.text[doc.starts[i]]
    if ch in {' ', '\n', '\t', '\r'}:
      inc i
      continue
    if ch == '"':
      inc i
      var words: seq[string]
      while i < n and doc.text[doc.starts[i]] != '"':
        if not wordChar(doc, i):
          inc i
          continue
        let at = i
        inc i
        while i < n and wordChar(doc, i): inc i
        words.add(toLower(sliceChars(doc, at, i)))
      if i < n: inc i
      if words.len > 0: result.add(TClause(words: words))
      continue
    if not wordChar(doc, i):
      inc i
      continue
    let at = i
    inc i
    while i < n and wordChar(doc, i): inc i
    result.add(TClause(words: @[toLower(sliceChars(doc, at, i))]))

proc phraseAt(doc: TDocument, tokenIndex: int, words: seq[string]): bool =
  if tokenIndex < 0 or tokenIndex + words.len > doc.tokens.len: return false
  for k, w in words:
    if doc.tokens[tokenIndex + k].word != w: return false
  true

proc docMatches(doc: TDocument, clause: TClause): bool =
  if clause.words.len == 0: return false
  if clause.words.len == 1:
    for tok in doc.tokens:
      if tok.word == clause.words[0]: return true
    return false
  for i in 0 .. doc.tokens.len - clause.words.len:
    if phraseAt(doc, i, clause.words): return true

proc collapse(s: string): string =
  var spaced = false
  for c in s:
    if c in {' ', '\n', '\t', '\r'}:
      if result.len > 0 and not spaced:
        result.add ' '
        spaced = true
    else:
      spaced = false
      result.add c

proc lineOf(doc: TDocument, at: int): int =
  result = 1
  let n = min(at, charCount(doc))
  if n <= 0: return
  let endb = doc.starts[n]
  for i in 0 ..< endb:
    if doc.text[i] == '\n': inc result

proc makeSnippet(doc: TDocument, at, length: int): string =
  let n = charCount(doc)
  if length <= 0:
    let hi = min(n, 72)
    let body = collapse(sliceChars(doc, 0, hi))
    if hi < n: return body & " ..."
    return body
  var a = max(0, at - 42)
  var b = min(n, at + length + 58)
  if a > 0:
    var j = a
    while j < at and not breakChar(doc, j): inc j
    if j < at: a = j + 1
  if b < n:
    var j = b
    while j > at + length and not breakChar(doc, j): dec j
    if j > at + length: b = j
  let pre = if a > 0: "... " else: ""
  let post = if b < n: " ..." else: ""
  pre & collapse(sliceChars(doc, a, at)) & "[[" &
    collapse(sliceChars(doc, at, at + length)) & "]]" &
    collapse(sliceChars(doc, at + length, b)) & post

proc search*(index: TIndex, query: string, limit = 300): seq[THit] =
  let clauses = parseQuery(query)
  if clauses.len == 0 or index.docs.len == 0: return
  let lead = clauses[0]
  # Hits come from the inverted list of the first word. The other clauses
  # only decide whether that document qualifies.
  let leadWord = lead.words[0]
  if leadWord notin index.terms: return
  for post in index.terms[leadWord]:
    let doc = index.docs[post.doc]
    if lead.words.len > 1 and not phraseAt(doc, post.token, lead.words):
      continue
    var ok = true
    for clause in clauses:
      if not docMatches(doc, clause):
        ok = false
        break
    if not ok: continue
    let first = doc.tokens[post.token]
    var length = first.len
    if lead.words.len > 1:
      let last = doc.tokens[post.token + lead.words.len - 1]
      length = last.at + last.len - first.at
    result.add(THit(doc: post.doc, at: first.at, len: length,
      line: lineOf(doc, first.at), snippet: makeSnippet(doc, first.at, length)))
  result.sort proc(a, b: THit): int =
    result = cmp(index.docs[a.doc].name, index.docs[b.doc].name)
    if result == 0: result = cmp(a.at, b.at)
  if result.len > limit: result.setLen(limit)
