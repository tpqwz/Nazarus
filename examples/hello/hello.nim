## A hand-written Nazarus program. The IDE writes the same kind of code for you.
import ncl

let form = TForm.new()
form.caption = "Hello"
form.position = poScreenCenter
form.width = 360
form.height = 150

let label = TLabel.new(form)
label.parent = form
label.caption = "Nazarus"
label.left = 24
label.top = 24

let button = TButton.new(form)
button.parent = form
button.caption = "Close"
button.left = 24
button.top = 64
button.onClick = proc(sender: TObject) = application.terminate()

form.run()
