## Generate a tiny project, compile it with the Nim compiler, and run it.
import std/[os, osproc, strutils]
import ncl, codegen, project

headless = true

proc fail(msg: string) =
  stderr.writeLine("FAIL " & msg)
  quit(1)

let form = TForm.new()
form.name = "Form1"
form.caption = "Greeter"
form.width = 320
form.height = 160
let label = TLabel.new(form)
label.parent = form
label.caption = "Name"
label.left = 16
label.top = 24
let edit = TEdit.new(form)
edit.parent = form
edit.left = 72
edit.top = 20
edit.text = "world"
let button = TButton.new(form)
button.parent = form
button.caption = "Greet"
button.left = 72
button.top = 64
button.setProp("OnClick", "Button1Click")

var src = generateUnit(form, "")
src = src.replace("  discard\n", "  self.Label1.caption = \"Hello, \" & self.Edit1.text\n")
src = generateUnit(form, src)
if "Hello, " notin src: fail("body was not kept")

let dir = getTempDir() / "nazarus-build-test"
createDir(dir)
writeFile(dir / "unit1.nim", src)
writeFile(dir / "unit1.nfm", saveNfm(form))
let proj = TProject(name: "Greeter", dir: dir, mainUnit: "unit1", units: @["unit1"])
writeProgram(proj, @[TProgramForm(unitName: "unit1", typeName: "TForm1")])
saveProject(proj)

let nimExe = findExe("nim")
if nimExe.len == 0: fail("nim not on PATH")
let outFile = dir / "Greeter"
let code = execCmd(nimExe & " c --hints:off -o:" & quoteShell(outFile) & " " & quoteShell(proj.programFile))
if code != 0: fail("project did not compile")

putEnv("NAZARUS_QUIT_AFTER_MS", "500")
let ran = execCmd(quoteShell(outFile))
if ran != 0: fail("project exited " & $ran)
echo "build ok"
