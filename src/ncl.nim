## Nazarus Component Library. One module, so the widget classes can refer to each other the way LCL units do.
import std/[tables, sets, strutils, os]

const NazarusShare* = currentSourcePath().parentDir().parentDir() / "share"

include "nclmods/gtkbind.nim"
include "nclmods/core.nim"
include "nclmods/widgets.nim"
include "nclmods/streaming.nim"
include "nclmods/design.nim"

registerAll()
application = TApplication()
application.title = "Application"
