## Nazarus Component Library. One module, so the widget classes can refer to each other the way LCL units do.
import std/[tables, sets, strutils, os]

proc nazarusShare*(): string =
  ## Prefer share/ next to the executable, so a release archive works on
  ## a machine that does not have this source tree. A build started from
  ## the repo falls back to the share/ beside these sources.
  let beside = getAppFilename().parentDir / "share"
  if fileExists(beside / "nim.lang"):
    return beside
  currentSourcePath().parentDir().parentDir() / "share"

include "nclmods/gtkbind.nim"
include "nclmods/core.nim"
include "nclmods/widgets.nim"
include "nclmods/streaming.nim"
include "nclmods/design.nim"

registerAll()
application = TApplication()
application.title = "Application"
