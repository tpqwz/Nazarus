## Atlas catalog: seed data, the form file, and a unit the designer can rewrite.
import std/[os, strutils]
import ncl, codegen, atlas

headless = true

proc fail(msg: string) =
  stderr.writeLine("FAIL " & msg)
  quit(1)

let root = currentSourcePath().parentDir().parentDir()
let dir = root / "examples" / "Atlas"
let rows = seedPlaces()
if rows.len != 15: fail("seed " & $rows.len)
let text = catalogText(rows)
let back = parseCatalog(text)
if back.len != 15: fail("roundtrip " & $back.len)
if back[0].name != "Valletta" or not back[0].visited or back[0].interest != 82:
  fail("valletta")
if back[2].kind != "Coast" or back[2].region != "Mediterranean": fail("rovinj")
var ghardaia = false
var ait = false
for p in back:
  if p.name == "Ghardaïa":
    ghardaia = true
    if "M'zab" notin p.notes: fail("ghardaia notes")
  if p.name == "Aït Benhaddou" and p.kind == "Ruin": ait = true
if not ghardaia or not ait: fail("unicode places")
if not matchesPlace(rows[0], "", "harbour", "All", false): fail("query notes")
if not matchesPlace(rows[0], "Mediterranean", "", "Harbor", true): fail("harbor visited")
if matchesPlace(rows[0], "Pacific", "", "All", false): fail("wrong region")
if matchesPlace(rows[1], "", "", "All", true): fail("matera is not visited")
if not matchesPlace(rows[1], "", "ravine", "Stone", false): fail("matera notes")

let catalog = dir / "atlas.catalog"
if not fileExists(catalog): fail("missing catalog file")
let filed = parseCatalog(readFile(catalog))
if filed.len != 15 or filed[0].name != "Valletta" or filed[^1].name != "Nagasaki":
  fail("catalog file")
if catalogText(filed) != text: fail("catalog file drifted from the seed")

let form = loadTAtlas(dir / "atlas.nfm")
if form.name != "Atlas" or form.caption != "Atlas": fail("form")
if form.width != 1020 or form.height != 680: fail("size")
if form.findComponent("RegionTree") == nil: fail("tree")
if form.findComponent("PlaceList") == nil: fail("list")
if form.findComponent("InterestBar") == nil: fail("track")
if form.findComponent("InterestProgress") == nil: fail("progress")
if form.findComponent("NotesMemo") == nil: fail("notes")
if form.findComponent("JournalMemo") == nil: fail("journal")
if form.findComponent("Clock") == nil or TTimer(form.findComponent("Clock")).interval != 1000:
  fail("timer")
if form.menu == nil or form.menu.menuItems.len != 2: fail("menu")
let pages = form.findComponent("Pages")
if pages == nil or not (pages of TPageControl) or TPageControl(pages).activePageIndex != 0:
  fail("pages")
let kind = TComboBox(form.findComponent("KindFilter"))
if kind == nil or kind.items.len != 7 or kind.itemIndex != 0 or kind.text != "All":
  fail("kind filter")
let src = readFile(dir / "atlas.nim")
if generateUnit(form, src) != src: fail("generateUnit rewrote atlas.nim")
if "proc seedPlaces*" notin src or "proc AtlasCreate*" notin src: fail("procs")
if src.find("proc seedPlaces*") > src.find("proc AtlasCreate*"): fail("decl after events")

echo "ok"
