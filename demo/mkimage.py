#!/usr/bin/env python3
"""mkimage.py — Build Micral P2 bootable floppy image from demo.bin

Produces a 512-byte raw image:
  Sector 0 (256 B): Config sector (all zeros, boot_cfg=0x00)
  Sector 1 (256 B): MOS hex records (data + exec), zero-padded

Boot with: B0,1 at MP2 monitor prompt.
"""

import sys
from pathlib import Path

LOAD_ADDR = 0x8000
SECTOR_SIZE = 256
MAX_DATA = SECTOR_SIZE - 5 - 5  # room for data record header + exec record

def main():
    bin_path = Path(__file__).parent / "demo.bin"
    out_path = Path(__file__).parent / "demo_floppy.img"

    program = bin_path.read_bytes()
    if len(program) > MAX_DATA:
        print(f"Error: demo.bin is {len(program)} bytes, max {MAX_DATA}", file=sys.stderr)
        sys.exit(1)

    # Data record: [LENGTH] [TYPE=0xC2] [ADDR_H] [ADDR_L] [EXTRA] [DATA...]
    data_record = bytes([
        len(program) + 4,       # length: type + addr(2) + extra + data
        0xC2,                   # type: data record
        (LOAD_ADDR >> 8) & 0xFF,  # address high
        LOAD_ADDR & 0xFF,       # address low
        0x00,                   # extra (unused)
    ]) + program

    # Exec record: [LENGTH=0x04] [TYPE=0xC6] [ADDR_H] [ADDR_L] [EXTRA]
    exec_record = bytes([
        0x04,                   # length
        0xC6,                   # type: exec record
        (LOAD_ADDR >> 8) & 0xFF,
        LOAD_ADDR & 0xFF,
        0x00,                   # extra
    ])

    # Build image
    config_sector = b'\x00' * SECTOR_SIZE
    mos_data = data_record + exec_record
    mos_sector = mos_data.ljust(SECTOR_SIZE, b'\x00')

    image = config_sector + mos_sector
    out_path.write_bytes(image)
    print(f"OK: {out_path.name} ({len(image)} bytes)")
    print(f"    Program: {len(program)} bytes at 0x{LOAD_ADDR:04X}")
    print(f"    Records: data({len(data_record)}B) + exec({len(exec_record)}B)")

if __name__ == "__main__":
    main()
