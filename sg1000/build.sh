#!/bin/sh
set -eu
cd "$(dirname "$0")"
SJASMPLUS=${SJASMPLUS:-sjasmplus}
mkdir -p build
"$SJASMPLUS" --raw=build/drmario.sg src/main.asm
size=$(wc -c < build/drmario.sg | tr -d ' ')
[ "$size" = 32768 ] || { echo "Expected 32768-byte ROM, got $size" >&2; exit 1; }
printf 'Built build/drmario.sg (%s bytes)\n' "$size"
