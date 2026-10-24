#!/bin/sh
# Build third_party/libnimsyn.so from the vendored tree-sitter runtime
# (0.25.6) and the Nim grammar. The grammar's parser.c is large; this
# compiles it once and the IDE loads the shared library by path.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
rt="$root/third_party/tree-sitter/lib"
gr="$root/third_party/tree-sitter-nim/src"
out="$root/third_party/libnimsyn.so"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cflags="-std=c11 -fPIC -fvisibility=hidden -D_POSIX_C_SOURCE=200112L -D_DEFAULT_SOURCE -I$rt/src -I$rt/include"
for src in alloc.c get_changed_ranges.c language.c lexer.c node.c parser.c query.c stack.c subtree.c tree.c tree_cursor.c wasm_store.c; do
  gcc -O2 $cflags -c "$rt/src/$src" -o "$work/rt-$(basename "$src" .c).o"
done
gcc -O2 -std=c11 -fPIC -I"$gr" -c "$gr/scanner.c" -o "$work/scanner.o"
gcc -O0 -std=c11 -fPIC -I"$gr" -c "$gr/parser.c" -o "$work/grammar.o"
gcc -shared -o "$out" "$work"/*.o
echo "built $out"
