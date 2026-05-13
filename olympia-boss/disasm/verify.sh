#!/bin/sh
# Verify the Olympia Boss system ROM annotated disassembly.
# Reassembles and compares against original ROM binary.
set -e
cd "$(dirname "$0")"

echo "Assembling boot_annotated.asm..."
z80asm boot_annotated.asm -o boot_annotated.bin

echo "Comparing with original ROM..."
if cmp boot_annotated.bin ../ROMs/olympia_boss_system_251-462.bin; then
    echo "OK — exact match."
    rm -f boot_annotated.bin
else
    echo "FAIL — mismatch!"
    rm -f boot_annotated.bin
    exit 1
fi
