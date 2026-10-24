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

Moving the bookmark off the old commit leaves that commit in history. It is no longer immutable once `restore-point` no longer points at it.

On a fresh clone, immutability is local repo config and is not in the commit. Set it once:

```
jj config set --repo 'revset-aliases."immutable_heads()"' 'builtin_immutable_heads() | restore-point'
```

## What the snapshot does not contain

`.gitignore` keeps `nimcache/`, `hcr_cache/`, and the built `examples/hello/hello` and `examples/Greeter/Greeter` binaries out of the repo. `jj restore` does not delete ignored files. Remove a stale binary yourself if you need a clean build.
