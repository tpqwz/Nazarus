## Headless checks for layout, form files, and Nim codegen. No display required.
import std/[os, strutils]
import ncl, codegen, project

headless = true

proc fail(msg: string) =
  stderr.writeLine("FAIL " & msg)
  quit(1)

if parseColor("clRed") != clRed: fail("parse clRed")
if parseColor("#010203") != TColor(0x010203): fail("parse hex")
if colorName(clBtnFace) != "clBtnFace": fail("color name")
if cssHex(clBlue) != "#1E5AC8": fail("css " & cssHex(clBlue))

let sources = ["/tmp/app/unit1.nim", "/tmp/app/src/unit1.nim", "/tmp/app/Jump.nim"]
let nimSite = compilerSite("/tmp/app/src/unit1.nim(12, 8) Error: undeclared identifier: 'x'", sources)
if nimSite.file != "/tmp/app/src/unit1.nim" or nimSite.line != 12 or nimSite.col != 8:
  fail("nim site " & nimSite.file & ":" & $nimSite.line & ":" & $nimSite.col)
let shortSite = compilerSite("unit1.nim(3, 1) Error: bad", @["/tmp/app/unit1.nim"])
if shortSite.file != "/tmp/app/unit1.nim" or shortSite.line != 3 or shortSite.col != 1:
  fail("short site")
let progSite = compilerSite("Jump.nim(4, 2) Error: y", sources)
if progSite.file != "/tmp/app/Jump.nim" or progSite.line != 4 or progSite.col != 2:
  fail("program site")
if compilerSite("Compiling Jump...", sources).file.len != 0: fail("plain line")
if compilerSite("/tmp/nimcache/unit1.nim.c:20:4: error: boom", sources).file.len != 0:
  fail("nim cache")
let cSite = compilerSite("/tmp/app/Jump.nim:9:2: error: boom", sources)
if cSite.file != "/tmp/app/Jump.nim" or cSite.line != 9 or cSite.col != 2: fail("gcc site")
if compilerSite("Error: 12: not a file", sources).file.len != 0: fail("bare number")

let form = TForm.new()
form.name = "Form1"
form.caption = "Hello"
form.width = 220
form.height = 120
let panel = TPanel.new(form)
panel.parent = form
panel.bevel = bvNone
panel.align = alTop
panel.height = 40
let button = TButton.new(form)
button.parent = form
button.align = alClient
button.caption = "Go"
button.setProp("OnClick", "Button1Click")

if panel.top != 0 or panel.height != 40 or panel.width != 220:
  fail("panel layout " & $panel.left & "," & $panel.top & " " & $panel.width & "x" & $panel.height)
if button.top != 40 or button.height != 80 or button.width != 220:
  fail("button layout " & $button.left & "," & $button.top & " " & $button.width & "x" & $button.height)
panel.visible = false
if button.top != 0 or button.height != 120:
  fail("hidden panel " & $button.top & "x" & $button.height)
panel.visible = true
if button.top != 40 or button.height != 80:
  fail("restored panel")

let plain = TForm.new()
plain.width = 800
plain.height = 300
let plainSide = TPanel.new(plain)
plainSide.parent = plain
plainSide.bevel = bvNone
plainSide.align = alLeft
plainSide.width = 100
let plainPage = TPanel.new(plain)
plainPage.parent = plain
plainPage.bevel = bvNone
plainPage.align = alClient
plain.width = 300
if plainPage.left != 100 or plainSide.width != 100:
  fail("plain stacked " & $plainPage.left & " " & $plainSide.width)

let stackForm = TForm.new()
stackForm.name = "Box"
stackForm.width = 800
stackForm.height = 420
stackForm.responsive = true
stackForm.breakWidth = 700
let bar = TPanel.new(stackForm)
bar.name = "Bar"
bar.bevel = bvNone
bar.align = alTop
bar.height = 36
bar.parent = stackForm
let side = TPanel.new(stackForm)
side.name = "Side"
side.bevel = bvNone
side.align = alLeft
side.width = 180
side.parent = stackForm
let mark = TButton.new(stackForm)
mark.name = "Mark"
mark.align = alClient
mark.parent = side
let split = TSplitter.new(stackForm)
split.name = "Split"
split.width = 6
split.parent = stackForm
let page = TPanel.new(stackForm)
page.name = "Page"
page.bevel = bvNone
page.align = alClient
page.parent = stackForm
let foot = TPanel.new(stackForm)
foot.name = "Foot"
foot.bevel = bvNone
foot.align = alBottom
foot.height = 24
foot.parent = stackForm
if bar.top != 0 or bar.height != 36 or bar.width != 800: fail("bar wide")
if foot.height != 24 or foot.top != 396: fail("foot wide")
if side.left != 0 or side.width != 180 or side.height != 360: fail("side wide " & $side.width & "x" & $side.height)
if mark.width != 180: fail("mark wide " & $mark.width)
if split.left != 180 or split.width != 6: fail("split wide")
if page.left != 186 or page.width != 614 or page.top != 36: fail("page wide " & $page.left & "," & $page.top & " " & $page.width)
let rightPane = TPanel.new(stackForm)
rightPane.name = "Right"
rightPane.bevel = bvNone
rightPane.align = alRight
rightPane.width = 50
rightPane.parent = stackForm
if rightPane.width != 50 or rightPane.left != 750: fail("right wide " & $rightPane.left)
stackForm.width = 500
if side.width != 180 or side.height != 180 or side.top != 36: fail("side stack " & $side.top & " " & $side.width & "x" & $side.height)
if mark.width != 500 or mark.height != 180: fail("mark stack " & $mark.width & "x" & $mark.height)
if split.top != 216 or split.height != 6: fail("split stack " & $split.top)
if page.left != 0 or page.top != 222 or page.width != 500: fail("page stack " & $page.left & "," & $page.top & " " & $page.width)
if rightPane.top != 222 + page.height or rightPane.height != 50 or rightPane.width != 50:
  fail("right stack " & $rightPane.top & " h" & $rightPane.height)
if bar.top != 0 or bar.height != 36 or foot.top != 396: fail("chrome stack")
let stacked = saveNfm(stackForm)
if "Responsive = True" notin stacked or "BreakWidth = 700" notin stacked: fail("responsive streamed")
if "Width = 180" notin stacked: fail("column not kept")
side.width = 140
if side.height != 140 or side.width != 140: fail("band resize " & $side.width & "x" & $side.height)
side.visible = false
split.visible = false
rightPane.visible = false
if page.top != 36 or page.left != 0: fail("hidden stack " & $page.left & "," & $page.top)
side.visible = true
split.visible = true
rightPane.visible = true
stackForm.width = 800
if side.width != 140 or page.left != 146 or rightPane.left != 750 or rightPane.width != 50:
  fail("restored columns " & $side.width & " page " & $page.left & " right " & $rightPane.left)
if mark.width != 140: fail("mark restored " & $mark.width)
let againBox = TForm.new()
loadNfm(againBox, stacked)
if not againBox.responsive or againBox.breakWidth != 700: fail("responsive reload")
againBox.width = 800
let side2 = TPanel(againBox.findComponent("Side"))
let page2 = TPanel(againBox.findComponent("Page"))
if side2 == nil or page2 == nil or side2.width != 180 or page2.left != 186:
  fail("reloaded columns")

let hostR = TScrollBox.new()
let doc = TForm.new()
doc.width = 800
doc.height = 300
doc.responsive = true
doc.breakWidth = 900
let docSide = TPanel.new(doc)
docSide.bevel = bvNone
docSide.align = alLeft
docSide.width = 160
docSide.parent = doc
let docPage = TPanel.new(doc)
docPage.bevel = bvNone
docPage.align = alClient
docPage.parent = doc
enableDesign(doc, hostR)
doc.width = 320
if docPage.left != 160 or docSide.width != 160:
  fail("design stacked " & $docPage.left & " " & $docSide.width)

let menu = TMainMenu.new(form)
form.menu = menu
discard menu.add("&File")
let quitItem = menu.menuItems[0].add("Quit")
quitItem.shortCut = "Ctrl+Q"
quitItem.checked = true
let timer = TTimer.new(form)
timer.interval = 250

let nfm = saveNfm(form)
if "Responsive" in nfm or "BreakWidth" in nfm: fail("responsive default streamed")
let loaded = TForm.new()
loadNfm(loaded, nfm)
if loaded.name != "Form1" or loaded.caption != "Hello": fail("form props")
let button2 = loaded.findComponent("Button1")
if button2 == nil or TButton(button2).caption != "Go" or TButton(button2).align != alClient:
  fail("button reload")
if loaded.menu == nil or loaded.menu.menuItems.len != 1: fail("menu reload")
let quit2 = loaded.findComponent(quitItem.name)
if quit2 == nil or not (quit2 of TMenuItem) or TMenuItem(quit2).shortCut != "Ctrl+Q":
  fail("shortcut reload")
if not TMenuItem(quit2).checked: fail("checked menu")
let timer2 = loaded.findComponent(timer.name)
if timer2 == nil or TTimer(timer2).interval != 250: fail("timer reload")
let nested = TPanel(loaded.findComponent(panel.name))
if nested == nil or nested.bevel != bvNone: fail("panel reload")
let child = nested.findComponent("Button1")
# The button is owned by the form, not the panel.
if loaded.findComponent("Button1") == nil: fail("owned button")
if child != nil: fail("button should not be owned by the panel")

let src = generateUnit(form, "")
if "Button1*: TButton" notin src: fail("field")
if "proc Button1Click*" notin src: fail("event proc")
if "proc loadTForm1*" notin src: fail("loader")
if "newForm(TForm1)" notin src: fail("constructor")
let edited = src.replace("  discard\n", "  self.Button1.caption = \"Hi\"\n")
let src2 = generateUnit(form, edited)
if "self.Button1.caption = \"Hi\"" notin src2: fail("kept body")
if generateUnit(form, src2) != src2: fail("generate changed a unit it had just written")
let decl = "# NAZARUS:DECL BEGIN\ntype\n  Box = object\n    n: int\n\nproc helper(self: TForm1) =\n  echo self.name\n# NAZARUS:DECL END\n\n"
let withDecl = src2.replace("# NAZARUS:EVENTS BEGIN\n", decl & "# NAZARUS:EVENTS BEGIN\n")
let srcD = generateUnit(form, withDecl)
let helperAt = srcD.find("proc helper(self: TForm1)")
let clickAt = srcD.find("proc Button1Click*")
if helperAt < 0 or clickAt < 0 or helperAt > clickAt: fail("decl order")
if srcD.count("proc helper(self: TForm1)") != 1: fail("decl duplicated")
if "n: int" notin srcD: fail("decl type")
if generateUnit(form, srcD) != srcD: fail("decl not stable")
let src3 = generateUnit(form, src2 & "\nproc helper(self: TForm1) =\n  echo self.name\n")
if "proc helper(self: TForm1)" notin src3: fail("kept helper")
button.setProp("OnClick", "")
let src4 = generateUnit(form, src3)
if "proc Button1Click*" notin src4: fail("orphan event kept")
if "self.Button1.onClick" in src4: fail("cleared event still bound")

let dir = getTempDir() / "nazarus-test-proj"
createDir(dir)
let proj = TProject(name: "Demo", dir: dir, mainUnit: "unit1", units: @["unit1"])
saveProject(proj)
let again = loadProject(proj.projectFile)
if again.name != "Demo" or again.mainUnit != "unit1" or again.units != @["unit1"]:
  fail("project file")
writeProgram(proj, @[TProgramForm(unitName: "unit1", typeName: "TForm1")])
let program = readFile(proj.programFile)
if "import unit1" notin program or "loadTForm1(getAppDir() / \"unit1.nfm\")" notin program:
  fail("program")
if "application.mainForm = unit1Form" notin program: fail("main form")

let host = TScrollBox.new()
let dform = TForm.new()
dform.left = 0
dform.top = 0
dform.width = 400
dform.height = 300
let ba = TButton.new(dform)
ba.parent = dform
ba.setBounds(10, 10, 40, 20)
let bb = TButton.new(dform)
bb.parent = dform
bb.setBounds(80, 10, 40, 20)
let box = TPanel.new(dform)
box.parent = dform
box.bevel = bvNone
box.setBounds(10, 80, 100, 60)
let inner = TButton.new(dform)
inner.parent = box
inner.setBounds(10, 10, 30, 20)
enableDesign(dform, host)
designSelectRect(0, 0, 200, 40)
if designSelectionCount() != 2: fail("marquee both " & $designSelectionCount())
if ba notin designSelection() or bb notin designSelection(): fail("marquee members")
designSelectRect(10, 10, 30, 15)
if designSelectionCount() != 1 or designSelected() != ba: fail("marquee one")
designSelectRect(12, 82, 26, 16)
if designSelectionCount() != 1 or designSelected() != inner: fail("marquee child")
designSelectRect(70, 100, 20, 20)
if designSelectionCount() != 1 or designSelected() != box: fail("marquee panel")
designSelectRect(300, 200, 20, 20)
if designSelected() != dform: fail("marquee empty")

designSelectRect(10, 10, 30, 15)
designSelectRect(80, 10, 30, 15, true)
if designSelectionCount() != 2: fail("add marquee " & $designSelectionCount())
if ba notin designSelection() or bb notin designSelection(): fail("add marquee members")
designSelectRect(300, 200, 20, 20, true)
if designSelectionCount() != 2: fail("add marquee empty")

selectComponent(ba)
designToggle(bb)
if designSelectionCount() != 2 or designSelected() != bb: fail("toggle add")
if ba notin designSelection(): fail("toggle kept")
let widthTargets = designApplyTargets("Width")
if widthTargets.len != 2 or widthTargets[0] != bb: fail("width targets")
if designApplyTargets("Name").len != 1: fail("name stays primary")
for c in widthTargets: c.setProp("Width", "80")
if ba.width != 80 or bb.width != 80: fail("width both")
setDesignGrid(8, false)
ba.setBounds(0, 8, 16, 16)
bb.setBounds(48, 8, 16, 16)
selectComponent(ba)
designToggle(bb)
designDragResize(3, 64, 0)
if ba.left != 0 or ba.top != 8 or ba.width != 32 or ba.height != 16:
  fail("group anchor " & $ba.left & "," & $ba.top & " " & $ba.width & "x" & $ba.height)
if bb.left != 96 or bb.top != 8 or bb.width != 32 or bb.height != 16:
  fail("group far " & $bb.left & "," & $bb.top & " " & $bb.width & "x" & $bb.height)
setDesignGrid(8, true)
ba.setBounds(10, 10, 40, 20)
bb.setBounds(80, 10, 40, 20)
selectComponent(ba)
designToggle(bb)
designToggle(bb)
if designSelectionCount() != 1 or designSelected() != ba: fail("toggle remove")
designToggle(ba)
if designSelected() != dform: fail("toggle last")

ba.setBounds(10, 10, 40, 20)
bb.setBounds(80, 30, 50, 25)
designSelectRect(0, 0, 200, 80)
if designSelected() != bb: fail("align primary")
if designAlign(daLeft) < 2: fail("align left ran")
if ba.left != 80 or ba.top != 10: fail("align left " & $ba.left & "," & $ba.top)
ba.setBounds(10, 10, 40, 20)
bb.setBounds(80, 30, 50, 25)
designSelectRect(0, 0, 200, 80)
discard designAlign(daTop)
if ba.top != 30: fail("align top " & $ba.top)
ba.setBounds(10, 10, 40, 20)
bb.setBounds(80, 30, 50, 25)
designSelectRect(0, 0, 200, 80)
discard designAlign(daRight)
if ba.left != 90: fail("align right " & $ba.left)
selectComponent(ba)
if designAlign(daTop) != 0: fail("align needs two")

ba.setBounds(10, 10, 40, 20)
inner.setBounds(10, 10, 30, 20)
selectComponent(ba)
designToggle(inner)
if designSelected() != inner: fail("toggle primary")
discard designAlign(daTop)
if ba.top != 90: fail("align across parent " & $ba.top)
if inner.top != 10: fail("align ref moved")

ba.setBounds(10, 10, 40, 20)
bb.setBounds(80, 30, 50, 25)
selectComponent(ba)
designToggle(bb)
if designAlign(daSameW) < 2: fail("same width ran")
if ba.width != 50 or ba.height != 20 or ba.left != 10: fail("same width " & $ba.width)
if bb.width != 50: fail("same width ref")
ba.setBounds(10, 10, 40, 20)
bb.setBounds(80, 30, 50, 25)
selectComponent(ba)
designToggle(bb)
discard designAlign(daSameH)
if ba.height != 25 or ba.width != 40: fail("same height " & $ba.height)
ba.setBounds(10, 10, 40, 20)
bb.setBounds(80, 30, 50, 25)
selectComponent(ba)
designToggle(bb)
discard designAlign(daSameSize)
if ba.width != 50 or ba.height != 25: fail("same size")
let stuck = TButton.new(dform)
stuck.parent = dform
stuck.align = alLeft
stuck.width = 30
stuck.height = 40
ba.setBounds(10, 10, 40, 20)
bb.setBounds(80, 30, 50, 25)
selectComponent(bb)
designToggle(ba)
designToggle(stuck)
discard designAlign(daSameW)
if stuck.width != 30: fail("aligned control resized")
if ba.width != 40 or bb.width != 40: fail("size ref " & $ba.width & " " & $bb.width)
let bc = TButton.new(dform)
bc.parent = dform
ba.setBounds(10, 10, 20, 16)
bb.setBounds(40, 10, 20, 16)
bc.setBounds(100, 10, 20, 16)
selectComponent(ba)
designToggle(bb)
if designAlign(daSpaceH) != 0: fail("space needs three")
designToggle(bc)
if designAlign(daSpaceH) < 3: fail("space h ran")
if ba.left != 10 or bb.left != 55 or bc.left != 100: fail("space h " & $ba.left & "," & $bb.left & "," & $bc.left)
ba.setBounds(0, 0, 10, 10)
bb.setBounds(20, 0, 10, 10)
bc.setBounds(31, 0, 10, 10)
selectComponent(ba)
designToggle(bb)
designToggle(bc)
discard designAlign(daSpaceH)
if ba.left != 0 or bb.left != 16 or bc.left != 31: fail("space remainder " & $bb.left)
ba.setBounds(10, 10, 20, 10)
bb.setBounds(10, 40, 20, 10)
bc.setBounds(10, 80, 20, 10)
selectComponent(ba)
designToggle(bb)
designToggle(bc)
discard designAlign(daSpaceV)
if ba.top != 10 or bb.top != 45 or bc.top != 80: fail("space v " & $ba.top & "," & $bb.top & "," & $bc.top)

ba.setBounds(10, 10, 40, 20)
selectComponent(ba)
if not designKey(dkeyRight, false) or ba.left != 11: fail("nudge")
if not designKey(dkeyRight, true) or ba.left != 19: fail("nudge grid")
if not designKey(dkeyDelete, false): fail("delete key")
if ba.parent != nil: fail("deleted")
if designSelected() != dform: fail("delete selects form")
if bb.parent == nil or inner.parent == nil: fail("delete spared")

selectComponent(dform)
dform.setBounds(0, 0, 400, 300)
designDragResize(4, 40, 24)
if dform.width != 440 or dform.height != 328:
  fail("form resize " & $dform.width & "x" & $dform.height)
dform.setBounds(0, 0, 200, 160)
designDragResize(4, -400, -400)
if dform.width != 80 or dform.height != 60:
  fail("form min " & $dform.width & "x" & $dform.height)
dform.align = alTop
dform.setBounds(12, 16, 220, 140)
if dform.left != 12 or dform.top != 16 or dform.width != 220 or dform.height != 140:
  fail("form keeps designed size")
dform.align = alNone
dform.setBounds(0, 0, 400, 300)
let grow = TButton.new(dform)
grow.parent = dform
grow.setBounds(10, 10, 40, 20)
grow.anchors = {akLeft, akRight, akTop}
if grow.getProp("Anchors") != "akLeft,akTop,akRight":
  fail("anchor text " & grow.getProp("Anchors"))
selectComponent(dform)
designDragResize(3, 32, 0)
if dform.width != 432: fail("form right edge " & $dform.width)
if grow.width != 72: fail("anchored child " & $grow.width)

let c1 = TButton.new(dform)
c1.parent = dform
c1.caption = "One"
c1.setBounds(40, 40, 75, 25)
c1.setProp("OnClick", "GoClick")
let c2 = TButton.new(dform)
c2.parent = dform
c2.caption = "Two"
c2.setBounds(40, 80, 75, 25)
selectComponent(c1)
designToggle(c2)
if designCopy() != 2: fail("copy two")
if c1.left != 40: fail("copy moved")
selectComponent(dform)
if designCopy() != 0: fail("copy form keeps clip")
if not designKey(dkeyPaste, false): fail("paste key")
if designSelectionCount() != 2: fail("paste selects " & $designSelectionCount())
var sawOne = false
var sawTwo = false
for s in designSelection():
  if not (s of TControl): continue
  let c = TControl(s)
  if c.caption == "One":
    sawOne = true
    if c.parent != dform: fail("paste parent")
    if c.left != 48 or c.top != 48: fail("paste offset " & $c.left & "," & $c.top)
    if c.getProp("OnClick") != "GoClick": fail("paste event")
    if c.name == c1.name: fail("paste kept name")
  elif c.caption == "Two":
    sawTwo = true
    if c.left != 48 or c.top != 88: fail("paste two offset")
if not sawOne or not sawTwo: fail("paste captions")
let firstName = designSelected().name
if designPaste() != 2: fail("paste again")
for s in designSelection():
  if s of TControl and TControl(s).caption == "One":
    if TControl(s).left != 56: fail("second offset " & $TControl(s).left)
    if s.name == firstName: fail("second name")

let hostP = TPanel.new(dform)
hostP.parent = dform
hostP.bevel = bvNone
hostP.setBounds(10, 160, 140, 80)
let kid = TButton.new(dform)
kid.parent = hostP
kid.caption = "Inside"
kid.setBounds(8, 8, 60, 22)
selectComponent(hostP)
designToggle(kid)
if designCopy() != 1: fail("copy panel skips child")
selectComponent(dform)
if designPaste() != 1: fail("paste panel")
let copyP = designSelected()
if copyP == nil or not (copyP of TPanel): fail("pasted panel")
if TControl(copyP).left != 18 or TControl(copyP).parent != dform: fail("panel spot")
var found: TControl
for c in TPanel(copyP).childControls:
  found = c
if found == nil or found.caption != "Inside" or found.left != 8: fail("panel child")
if found.name == kid.name: fail("child name")

selectComponent(hostP)
if designPaste() != 1: fail("paste into panel")
if designSelected() == nil or TControl(designSelected()).parent != hostP:
  fail("paste target")

let clipTimer = TTimer.new(dform)
clipTimer.interval = 400
selectComponent(clipTimer)
if designCopy() != 1: fail("copy timer")
if designSelected() != clipTimer: fail("copy keeps timer")
selectComponent(c1)
if designPaste() != 1: fail("paste timer")
let nt = designSelected()
if nt == nil or nt.className != "TTimer": fail("pasted timer")
if TTimer(nt).interval != 400: fail("timer interval")

let cutLeft = c2.left
let cutName = c2.name
selectComponent(c2)
if designCut() != 1: fail("cut")
if c2.parent != nil: fail("cut removed")
if designSelected() != dform: fail("cut selects form")
if designPaste() != 1: fail("paste cut")
let back = designSelected()
if back == nil or back.name != cutName: fail("cut name " & (if back == nil: "nil" else: back.name))
if TControl(back).left != cutLeft + 8 or TControl(back).caption != "Two":
  fail("cut paste")

let oa = TButton.new(dform)
oa.parent = dform
oa.caption = "OA"
let ob = TButton.new(dform)
ob.parent = dform
ob.caption = "OB"
let oc = TButton.new(dform)
oc.parent = dform
oc.caption = "OC"

proc threeOrder(): seq[TControl] =
  for c in dform.childControls:
    if c == oa or c == ob or c == oc: result.add(c)

selectComponent(oa)
if designOrder(true) != 1: fail("front count")
var got = threeOrder()
if got.len != 3 or got[0] != ob or got[1] != oc or got[2] != oa: fail("front order")
selectComponent(oa)
if designOrder(false) != 1: fail("back count")
got = threeOrder()
if got[0] != oa or got[1] != ob or got[2] != oc: fail("back order")
selectComponent(ob)
designToggle(oc)
if designOrder(false) != 2: fail("back pair count")
got = threeOrder()
if got[0] != ob or got[1] != oc or got[2] != oa: fail("back pair")
selectComponent(dform)
if designOrder(true) != 0: fail("form stays")
let deepBox = TPanel.new(dform)
deepBox.parent = dform
let deep = TButton.new(dform)
deep.parent = deepBox
deep.caption = "Deep"
selectComponent(deep)
if designOrder(true) != 1 or deep.parent != deepBox: fail("inner order")
selectComponent(clipTimer)
if designOrder(true) != 0: fail("timer order")

echo "ok"
