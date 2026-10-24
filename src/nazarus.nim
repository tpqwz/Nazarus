## Nazarus, a Lazarus-style RAD GUI IDE for Nim.
##   nazarus [project.npr]
##   nazarus --smoke

import std/[os, strutils]
import ide

proc main() =
  var smoke = false
  var path = ""
  for i in 1 .. paramCount():
    let a = paramStr(i)
    if a == "--smoke": smoke = true
    elif a == "--help" or a == "-h":
      echo "Nazarus — RAD Nim GUI IDE"
      echo "  nazarus [project.npr]"
      echo "  nazarus --smoke"
      return
    elif not a.startsWith("-"):
      path = a
  runIde(path, smoke)

main()
