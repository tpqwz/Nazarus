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

let menu = TMainMenu.new(form)
form.menu = menu
discard menu.add("&File")
let quitItem = menu.menuItems[0].add("Quit")
quitItem.shortCut = "Ctrl+Q"
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

echo "ok"
