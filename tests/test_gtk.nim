## Live GTK smoke. Quits itself. Run with a display:
##   NAZARUS_QUIT_AFTER_MS=600 nim c -r tests/test_gtk.nim
import ncl

let form = TForm.new()
form.caption = "Nazarus GTK smoke"
form.position = poScreenCenter
form.width = 420
form.height = 300

let button = TButton.new(form)
button.parent = form
button.caption = "OK"
button.left = 16
button.top = 16

let edit = TEdit.new(form)
edit.parent = form
edit.left = 16
edit.top = 56
edit.text = "hello"

let memo = TMemo.new(form)
memo.parent = form
memo.left = 16
memo.top = 96
memo.width = 180
memo.height = 70
memo.text = "one\ntwo"

let check = TCheckBox.new(form)
check.parent = form
check.left = 220
check.top = 16
check.caption = "Check"
check.checked = true

let radio = TRadioGroup.new(form)
radio.parent = form
radio.left = 220
radio.top = 56
radio.width = 170
radio.height = 100
radio.caption = "Pick"
radio.items = @["A", "B"]
radio.itemIndex = 0

let bar = TProgressBar.new(form)
bar.parent = form
bar.left = 16
bar.top = 180
bar.position = 40

form.onCreate = proc(sender: TObject) =
  if edit.text != "hello" or not check.checked or radio.itemIndex != 0:
    echo "GTK smoke saw the wrong widget state"
    quit(2)

form.run()
echo "gtk ok"
