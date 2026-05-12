#!/bin/sh
# Verify that boot_raw.asm + main_raw.asm reassemble to the original ROM.
# Requires: z80asm

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
ROM="$DIR/../ROMs/portal.bin"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

z80asm "$DIR/boot_raw.asm" -o "$TMPDIR/boot.bin"
z80asm "$DIR/main_raw.asm" -o "$TMPDIR/main.bin"
cat "$TMPDIR/boot.bin" "$TMPDIR/main.bin" > "$TMPDIR/portal.bin"

if cmp -s "$ROM" "$TMPDIR/portal.bin"; then
    echo "OK: reassembled binary matches portal.bin"
else
    echo "FAIL: reassembled binary differs from portal.bin"
    xxd "$ROM" > "$TMPDIR/orig.hex"
    xxd "$TMPDIR/portal.bin" > "$TMPDIR/new.hex"
    diff "$TMPDIR/orig.hex" "$TMPDIR/new.hex" | head -20
    exit 1
fi
