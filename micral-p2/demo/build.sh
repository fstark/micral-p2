#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Assembling demo.asm..."
z80asm demo.asm -o demo.bin

echo "Building floppy image..."
python3 mkimage.py

echo ""
echo "Boot with: B0,1 at MP2 monitor prompt"
