#!/bin/sh
# Extract the relocated main code from the Portal ROM for disassembly.
#
# The ROM layout:
#   0x0000-0x0016: Bootstrapper (runs at addr 0000h, copies main code to RAM)
#   0x0017-0x0432: Main code (runs at addr F800h after relocation)
#   0x0433-0x07FF: Data tables / padding
#
# We split into two binaries:
#   boot.bin  — the 23-byte bootstrapper (org 0000h)
#   main.bin  — the relocated code (org F800h)

ROMDIR="$(dirname "$0")/../ROMs"
OUTDIR="$(dirname "$0")"

dd if="$ROMDIR/portal.bin" bs=1 count=23 of="$OUTDIR/boot.bin" 2>/dev/null
dd if="$ROMDIR/portal.bin" bs=1 skip=23 of="$OUTDIR/main.bin" 2>/dev/null

echo "Extracted: boot.bin (23 bytes, org 0000h)"
echo "Extracted: main.bin ($(wc -c < "$OUTDIR/main.bin" | tr -d ' ') bytes, org F800h)"
