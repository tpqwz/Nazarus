# Nazarus

Nazarus is a Lazarus-style RAD GUI IDE for Nim. The component library is NCL (the job LCL does in Lazarus). You design a form, the IDE writes Nim, and the Nim compiler builds the program.

The IDE and the code you write in it are Nim. Names you already know are still there: `TForm`, `TButton`, `TForm1`. A form file is `.nfm` (the `.lfm` equivalent) and a project file is `.npr` (the `.lpi` equivalent).

## Build and run

Nim 2 and GTK 3 are required. The shared libraries are loaded by soname (`libgtk-3.so.0`, `libgtksourceview-4.so.0`), so development headers are not required.

```
nim c -r src/nazarus.nim
```

Or open a project directly:

```
nim c -r src/nazarus.nim examples/Greeter/Greeter.npr
```

From the IDE: File, New Project, drop a button, double-click it, write Nim in the handler, press F9.

| Key | Action |
| --- | --- |
| Ctrl+N | New project |
| Ctrl+O | Open project |
| Ctrl+S | Save |
| F12 | Form / unit |
| F9 | Run |
| Ctrl+F9 | Compile |
| Ctrl+F | Find |
| Ctrl+Q | Quit |

Ctrl+Z is the editor's undo.

## A program without the IDE

`examples/hello` is a short NCL program. From that directory:

```
nim c -r hello.nim
```

`examples/Greeter` is the same shape the designer writes: `unit1.nim`, `unit1.nfm`, and a generated program.

## What this version is

GTK 3 only. The palette covers the standard controls (button, label, edit, memo, check box, radio, list, combo, group, panel), a few more (bevel, paint box, splitter, scroll box), common controls (track bar, progress bar, tree, status bar, toolbar, page control), the open and save dialogs, and a timer.

The designer snaps to an 8-pixel grid, streams the form both ways, and rewrites only the marked sections of a unit. Handler bodies and any extra procs you add are kept.

There is no debugger, no package manager, and no widgetset other than GTK 3. The designer overlay takes the mouse, including the wheel; use the scroll bars to reach the rest of a large form. The first compile of a project builds NCL, so it takes longer than the next one.

## Tests

```
nim c -r tests/test_ncl.nim
NAZARUS_QUIT_AFTER_MS=600 nim c -r tests/test_gtk.nim
nim c -r tests/test_build.nim
```

## History

The repo is Jujutsu (`jj`), colocated with Git. The bookmark `restore-point` is the known-good snapshot of this tree. How to return to it, undo a `jj` command, and cut a new restore point is in [RESTORE.md](RESTORE.md).
