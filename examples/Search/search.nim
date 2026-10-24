## Full-text search over the sample documents. Each row is a snippet.
## Choosing a row selects that match in the original text.
import std/[os, strutils]
import ncl, engine

var
  index: TIndex
  hits: seq[THit]
  shown = -1

let form = TForm.new()
form.caption = "Search"
form.position = poScreenCenter
form.width = 960
form.height = 640

let status = TStatusBar.new(form)
status.parent = form
status.simpleText = "No documents"

let bar = TPanel.new(form)
bar.parent = form
bar.align = alTop
bar.height = 46
bar.bevel = bvNone

let findLabel = TLabel.new(form)
findLabel.parent = bar
findLabel.caption = "Find"
findLabel.left = 12
findLabel.top = 14

let query = TEdit.new(form)
query.parent = bar
query.left = 52
query.top = 10
query.width = 740
query.height = 26
query.anchors = {akLeft, akTop, akRight}

let openBtn = TButton.new(form)
openBtn.parent = bar
openBtn.caption = "Open..."
openBtn.left = 820
openBtn.top = 8
openBtn.width = 110
openBtn.height = 30
openBtn.anchors = {akTop, akRight}

let results = TListBox.new(form)
results.parent = form
results.align = alLeft
results.width = 400

let split = TSplitter.new(form)
split.parent = form
split.align = alLeft
split.width = 6

let viewer = TMemo.new(form)
viewer.parent = form
viewer.align = alClient
viewer.readOnly = true
viewer.wordWrap = false
viewer.monospace = true
viewer.color = clWindow

proc showHit(h: THit) =
  if h.doc < 0 or h.doc >= index.docs.len: return
  let doc = index.docs[h.doc]
  if shown != h.doc:
    viewer.text = doc.text
    shown = h.doc
  viewer.selectRange(h.at, h.len)
  if h.len == 0:
    status.simpleText = doc.name
  else:
    status.simpleText = doc.name & "   line " & $h.line & "   character " & $h.at

proc runQuery() =
  let q = query.text.strip
  if q.len == 0:
    hits.setLen(0)
    var rows: seq[string]
    for i, doc in index.docs:
      let line = doc.text.splitLines()
      let preview = if line.len > 0: line[0] else: ""
      rows.add(doc.name & "    " & preview)
      hits.add(THit(doc: i, at: 0, len: 0, line: 1, snippet: preview))
    results.items = rows
    status.simpleText = $index.docs.len & " documents. Type a word or a \"phrase\"."
    return
  hits = search(index, q)
  var rows: seq[string]
  for h in hits:
    rows.add(index.docs[h.doc].name & ":" & $h.line & "    " & h.snippet)
  results.items = rows
  if hits.len == 0:
    status.simpleText = "No matches"
  else:
    results.itemIndex = 0
    showHit(hits[0])
    var docs = 0
    var seen: seq[int]
    for h in hits:
      if h.doc notin seen:
        seen.add(h.doc)
        inc docs
    status.simpleText = $hits.len & " matches in " & $docs & " documents. " &
      index.docs[hits[0].doc].name & "   line " & $hits[0].line &
      "   character " & $hits[0].at

proc openHit() =
  let i = results.itemIndex
  if i < 0 or i >= hits.len: return
  showHit(hits[i])

proc addFile(path: string) =
  if path.len == 0 or not fileExists(path): return
  addDocument(index, path, readFile(path))
  form.caption = "Search"
  runQuery()

proc loadCorpus() =
  var dir = getAppDir() / "docs"
  if not dirExists(dir):
    dir = currentSourcePath().parentDir / "docs"
  if not dirExists(dir):
    status.simpleText = "No docs directory beside the program"
    return
  for kind, path in walkDir(dir):
    if kind != pcFile: continue
    let ext = path.splitFile.ext.toLowerAscii
    if ext notin [".txt", ".md"]: continue
    addDocument(index, path, readFile(path))
  runQuery()

proc doOpen() =
  let dlg = TOpenDialog.new(form)
  dlg.title = "Add a text file"
  dlg.filter = "Text|*.txt,*.md|All files|*"
  if dlg.execute():
    addFile(dlg.fileName)

query.onChange = proc(sender: TObject) = runQuery()
results.onClick = proc(sender: TObject) = openHit()
openBtn.onClick = proc(sender: TObject) = doOpen()

loadCorpus()
form.run()
