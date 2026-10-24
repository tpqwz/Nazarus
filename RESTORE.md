# Restore points

This repository is a [Jujutsu](https://jj-vcs.dev) workspace (`jj` 0.46), colocated with a Git repo. Use `jj` for history. `git status` and `git log` work in the same directory because the workspace is colocated.

The bookmark `restore-point` names the known-good snapshot: NCL, the designer, the IDE, examples, and tests. The working copy `@` is a new change on top of that commit, so later edits do not rewrite it.

This workspace also treats that bookmark as immutable (`immutable_heads()` includes `restore-point`). `jj` will refuse to rebase, edit, or abandon that commit unless you pass `--ignore-immutable`.

## Look at the snapshot

```
jj log
jj show restore-point
jj diff --from restore-point
```

`jj diff --from restore-point` is everything in the working copy that is not in the snapshot.

## Put files back

Copy the snapshot into the working copy. `@` keeps its change id and description. Tracked files match `restore-point`.

```
jj restore --from restore-point
```

Restore one path:

```
jj restore --from restore-point src/ide.nim
```

`jj restore` with no arguments copies from the parent of `@`. Right after this snapshot, that parent is `restore-point`, so `jj restore` and `jj restore --from restore-point` do the same thing until you add another commit in between.

## Start over from the snapshot

Leave the current working-copy change where it is and open a new empty change on the snapshot:

```
jj new restore-point
```

The previous `@` stays in `jj log`. Drop it when you do not want it:

```
jj abandon <change-id>
```

`jj abandon` refuses to delete `restore-point` itself.

## Undo a jj command

Every `jj` command is an operation. That log is the full undo stack, including bookmark moves.

```
jj op log
jj --at-op=<operation-id> log
jj op restore <operation-id>
```

Look with `--at-op` first. `jj op restore` creates a new operation that puts the repo, local bookmarks, and working copy back to that moment.

`jj op revert <operation-id>` undoes one operation and keeps later ones.

## Cut a new restore point

When the working copy is the next known-good tree:

```
jj describe -m "Restore point: what is good about this tree"
jj bookmark set restore-point -r @
jj new
```

`jj bookmark set` moves the bookmark forward onto `@`. `jj new` puts the working copy on a child, so the next edit does not amend the snapshot.

Moving the bookmark off the old commit leaves that commit in history. It is no longer immutable once `restore-point` no longer points at it. The previous snapshot is change `xtqlvvrx`, commit `dbf1f83a`. `jj new xtqlvvrx` opens a working copy there.

## What this snapshot contains

This is the tree after the Greeter sample. The IDE designs a form, edits the generated Nim, and builds it with F9. There is still no debugger and no package manager, and the only widgetset is GTK 3.

The window has a menu bar: File, Edit, View, Run, Debug, and Help. View can hide the toolbar. Debug names step, breakpoint, watch, and debugger-option commands, and choosing one only writes a note in the status bar. Messages keeps the last part of the compiler output. A click on a compiler line that names a project file opens that line. Ctrl+S, Compile, and Run save the project. Closing the window does not.

Design, Code, and Explore are three views. The toolbar buttons stay put, and the same three entries are in the View menu. F12 moves between Design and Code. F4 opens Explore. Design shows the component tree, the inspector, and the component palette. Code and Explore hide all three. Code is the editor: a file list on the left, a procedure dropdown across the top, and scope rails in the gutter. The dropdown and the rails come from the vendored tree-sitter Nim grammar. Explore is an index of the form, its components, and the procs. The component palette is a Design tool. View, Component Palette remembers whether Design should show it. Code and Explore hide the strip either way.

On the form, the arrow draws a selection rectangle. Shift or Ctrl adds and removes controls. Edit, Align lines the selection up with the inspector's control. Delete and the arrow keys act on the selection, and the form resizes from the same handles as a control. After a drop, the tool returns to the arrow. Edit, Cut, Copy, and Paste keep the selection inside the IDE. Those keys are not window accelerators, so the editor still owns them on the code page. A form being designed inside the design scroll box keeps the Left, Top, Width, and Height you set. Align on that form applies when the program runs.

`generateUnit` rewrites the marked sections of a unit. Event bodies stay. A `# NAZARUS:DECL` block above the events stays, which is where a unit keeps the types, vars, and procs that the handlers call.

`examples/Atlas` replaces Greeter. It is a place catalog: a region tree, a filtered place list, and a page for the name, kind, region, notes, visited flag, and interest. File, Open and File, Save use `atlas.catalog`. The panes use Align. `examples/Search` indexes the text files in `docs`, shows a snippet for each hit, and selects that hit in the document.

NCL in this tree adds the controls those samples and the IDE use on top of the earlier button, label, edit, and timer: memo, list, combo, tree, splitter, page control, toolbar, status bar, track bar, progress bar, group box, panel, menus, and the open and save dialogs. Headless tests cover layout, form streaming, the DECL block, designer selection, align, form resize, the designer clipboard, compiler-line matching, the Atlas catalog, the search index, and the Nim outline.

On a fresh clone, immutability is local repo config and is not in the commit. Set it once:

```
jj config set --repo 'revset-aliases."immutable_heads()"' 'builtin_immutable_heads() | restore-point'
```

## What the snapshot does not contain

`.gitignore` keeps `nimcache/`, `hcr_cache/`, and the built example and test binaries out of the repo, including `examples/hello/hello`, `examples/Atlas/Atlas`, `examples/Search/search`, `tests/test_ncl`, `tests/test_gtk`, `tests/test_build`, `tests/test_search`, `tests/test_atlas`, and `tests/test_nimsyn`. `jj restore` does not delete ignored files. Remove a stale binary yourself if you need a clean build.

`third_party/libnimsyn.so` is also ignored. `third_party/build-nimsyn.sh` builds it from the vendored tree-sitter 0.25.6 runtime and the Nim grammar. The grammar's `parser.c` is in the snapshot. It is about 40MB, so a `jj` command that snapshots new files has to allow that size once. After the file is tracked, later commands snapshot it as usual.
