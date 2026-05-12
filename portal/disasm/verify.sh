#!/bin/sh
# Verify that disassemblies reassemble to the original ROM.
# Requires: z80asm

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
ROM="$DIR/../ROMs/portal.bin"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# --- Verify raw disassembly ---
z80asm "$DIR/boot_raw.asm" -o "$TMPDIR/boot.bin"
z80asm "$DIR/main_raw.asm" -o "$TMPDIR/main.bin"
cat "$TMPDIR/boot.bin" "$TMPDIR/main.bin" > "$TMPDIR/portal.bin"

if cmp -s "$ROM" "$TMPDIR/portal.bin"; then
    echo "OK: raw disassembly matches portal.bin"
else
    echo "FAIL: raw disassembly differs from portal.bin"
    xxd "$ROM" > "$TMPDIR/orig.hex"
    xxd "$TMPDIR/portal.bin" > "$TMPDIR/new.hex"
    diff "$TMPDIR/orig.hex" "$TMPDIR/new.hex" | head -20
    exit 1
fi

# --- Verify annotated disassembly ---
z80asm "$DIR/boot_annotated.asm" -o "$TMPDIR/boot_ann.bin"
z80asm "$DIR/main_annotated.asm" -o "$TMPDIR/main_ann.bin"
cat "$TMPDIR/boot_ann.bin" "$TMPDIR/main_ann.bin" > "$TMPDIR/portal_ann.bin"

if cmp -s "$ROM" "$TMPDIR/portal_ann.bin"; then
    echo "OK: annotated disassembly matches portal.bin"
else
    echo "FAIL: annotated disassembly differs from portal.bin"
    xxd "$ROM" > "$TMPDIR/orig.hex"
    xxd "$TMPDIR/portal_ann.bin" > "$TMPDIR/new.hex"
    diff "$TMPDIR/orig.hex" "$TMPDIR/new.hex" | head -20
    exit 1
fi
