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
nim c -r src/nazarus.nim examples/Atlas/Atlas.npr
```

From the IDE: File, New Project, drop a button, double-click it, write Nim in the handler, press F9.

| Key | Action |
| --- | --- |
| Ctrl+N | New project |
| Ctrl+O | Open project |
| Ctrl+S | Save |
| F12 | Toggle Design / Code |
| F3 | Go to the declaration under the caret |
| F4 | Explore |
| F9 | Run |
| Ctrl+F9 | Compile |
| Ctrl+F | Find |
| Ctrl+F3 | Find next |
| Ctrl+Shift+F3 | Find previous |
| Ctrl+R | Replace |
| Ctrl+G | Go to line |
| Ctrl+/ | Comment or uncomment the line or the selection |
| Ctrl+Shift+I | Indent the line or the selection |
| Ctrl+Shift+U | Unindent the line or the selection |
| Alt+Up | Move the line or the selection up |
| Alt+Down | Move the line or the selection down |
| Ctrl+Shift+D | Duplicate the line or the selection |
| Ctrl+Shift+K | Delete the line or the selection |
| Ctrl+J | Join the line with the next one, or join the selection |
| Ctrl+Enter | Insert a line below |
| Ctrl+Shift+Enter | Insert a line above |
| Ctrl+Shift+X | Uppercase the selection or the word |
| Ctrl+Shift+Y | Lowercase the selection or the word |
| Ctrl+Q | Quit |
| Ctrl+X, Ctrl+C, Ctrl+V | Cut, copy, and paste controls while the form is showing |

Ctrl+Z is the editor's undo. On the code page, Ctrl+X, Ctrl+C, and Ctrl+V cut, copy, and paste text. Edit, Cut, Copy, and Paste follow the same split. Ctrl+/ puts `#` after the indent of the current line, or of every line in the selection. When those lines are already comments, it takes one `#` away. A `##` note becomes `#`. Ctrl+Shift+I inserts two spaces at the start of those lines. Ctrl+Shift+U removes one level: up to two spaces, or one tab. Alt+Up and Alt+Down swap those lines with the line above or below. The first line stays at the top, and the last line stays at the bottom. Ctrl+Shift+D copies those lines and leaves the copy selected underneath. Ctrl+Shift+K removes those lines and closes the gap. Ctrl+J joins the current line with the next one, or joins every line in the selection, with a single space. The first line keeps its indent. Ctrl+Z puts the break back. Ctrl+Enter inserts a blank line under the current line, or under the selection. Ctrl+Shift+Enter inserts one above. The new line keeps that line's indent, and the caret sits after the indent. Ctrl+Z removes the blank line. Ctrl+Shift+X makes the selection uppercase. Ctrl+Shift+Y makes it lowercase. A caret with no selection changes the word it touches. Ctrl+Z puts the old case back.

The menu bar is part of the window: File, Edit, Search, View, Run, Debug, and Help. Search finds the text and selects it. Find next and find previous wrap. Replace changes the selected match and then finds the next one; Replace All changes every match in one undo step. F3 stays Go to Declaration. View has check items for the toolbar and the component palette. Uncheck one and that strip leaves the window. Debug lists step, breakpoint, watch, and debugger-option commands. They are placeholders. This version has no debugger, so choosing one only says so in the status bar.

Compile and Run write the Nim compiler's output into the Messages pane at the bottom. That text is not saved to a file. The pane keeps the last 40,000 characters and follows the newest line. Click a line that names a project file, such as `unit1.nim(12, 8) Error: ...`, and the editor opens that line. A cache file such as `unit1.nim.c` is not that unit.

## A program without the IDE

`examples/hello` is a short NCL program. From that directory:

```
nim c -r hello.nim
```

`examples/Atlas` is the shape the designer writes: `atlas.nim`, `atlas.nfm`, and a generated program. It is a place catalog. A region tree and a place list sit beside a page that edits the name, the kind, the region, a visited flag, and an interest level. The toolbar filters that list. File, Open and File, Save read and write `atlas.catalog`, one JSON object per line. The panes use Align, so the window can be resized. Atlas sets Responsive, so a window narrower than BreakWidth (640) stacks the region list, the place list, and the page. Widening puts the columns back. The designer keeps showing the wide arrangement. From that directory:

```
nim c -r Atlas.nim
```

`examples/Search` is a small full-text search window. It indexes the text files in `docs`, lists a short snippet for each hit, and selects that hit in the document when you click the row. A quoted phrase has to occur in order. Separate words match as a set. From that directory:

```
nim c -r search.nim
```

## What this version is

GTK 3 only. The palette covers the standard controls (button, label, edit, memo, check box, radio, list, combo, group, panel), a few more (bevel, paint box, splitter, scroll box), common controls (track bar, progress bar, tree, status bar, toolbar, page control), the open and save dialogs, and a timer.

The designer snaps to an 8-pixel grid, streams the form both ways, and rewrites only the marked sections of a unit. Handler bodies, a declaration block above the events, and any extra procs you add are kept. Code keeps the project file list on the left and a procedure dropdown in a strip across the top of the editor. A click on a file opens that unit. Choosing a name moves the caret there, and the dropdown follows the caret. F3 on a name jumps to that proc, or selects that component on the form. Above the first procedure it reads `(declarations)`. Scope rails in the left margin run from the line that opens a block to the line that closes it, and the rail around the caret is darker. Both come from the tree-sitter grammar for Nim (`third_party/build-nimsyn.sh` builds that library once). The editor colors Nim with GtkSourceView: keywords, types, strings, numbers, comments, and pragmas. Design, Code, and Explore are the three views. Their buttons sit on the toolbar, and the same three are in the View menu. Design shows the component tree, the inspector, and the component palette. Code and Explore hide all three. Code is the editor. Explore lists the form, its components, and the procs in the unit. A click shows that entry. A double-click opens it on the form or at its line. F12 moves between Design and Code. F4 opens Explore. With the arrow, drag across empty space to draw a selection rectangle. It selects every control it touches, one or several. Shift-click or Ctrl-click adds or removes a control, and Shift-drag adds to the selection. Dragging a control still moves it. The same handles resize the form. Edit, Align lines the selected controls up with the one in the inspector. Same Width, Same Height, and Same Size match that control, and Space Horizontally or Space Vertically spreads three or more, leaving the outer ones where they are. Edit, Order brings that selection in front of its siblings, or sends it behind them. Responsive on a form or a panel stacks its side-by-side panes when the client is narrower than BreakWidth, and widening restores the columns. The design surface keeps the wide arrangement. Delete and the arrow keys act on that selection. Hold Shift with an arrow key to step by the grid. Edit, Cut, Copy, and Paste store that selection. Each paste steps one grid to the right and down, gives the new controls their own names, and keeps a panel's children with the panel. Paste again and it steps again. A copied event still names the same handler.

There is no debugger yet (the Debug menu holds its place), no package manager, and no widgetset other than GTK 3. The designer canvas is larger than the window; the wheel and the scroll bars both move it. The first compile of a project builds NCL, so it takes longer than the next one.

## Tests

```
nim c -r tests/test_ncl.nim
nim c -r --path:examples/Atlas tests/test_atlas.nim
nim c -r --path:examples/Search tests/test_search.nim
NAZARUS_QUIT_AFTER_MS=600 nim c -r tests/test_gtk.nim
nim c -r tests/test_build.nim
nim c -r tests/test_edsearch.nim
nim c -r tests/test_ededit.nim
```

## History

The repo is Jujutsu (`jj`), colocated with Git. The bookmark `restore-point` is the known-good snapshot of this tree. How to return to it, undo a `jj` command, and cut a new restore point is in [RESTORE.md](RESTORE.md).

This snapshot replaces the Greeter sample with Atlas, adds Search, and records the Design, Code, and Explore IDE: the file list, the procedure dropdown, the scope rails, designer selection and clipboard, and a component palette that stays on Design. `generateUnit` keeps a declaration block above the events. The notes for that tree are in [RESTORE.md](RESTORE.md).
