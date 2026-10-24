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

let menu = TMainMenu.new(form)
form.menu = menu
discard menu.add("&File")
let quitItem = menu.menuItems[0].add("Quit")
quitItem.shortCut = "Ctrl+Q"
quitItem.checked = true
let timer = TTimer.new(form)
timer.interval = 250

let nfm = saveNfm(form)
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

echo "ok"
