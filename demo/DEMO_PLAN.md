# DEMO_PLAN.md — Micral P2 "Hello, World!" Bootable Floppy

## Overview

Build a bootable floppy image that displays "Hello, World!" on the Micral P2.
The user types `B0,1` at the MP2 monitor prompt to boot.

Three deliverables:
1. `demo.asm` — Z80 assembly program (clears screen, prints message, halts)
2. `mkimage.py` — Python script that encodes the binary as MOS hex records in a floppy image
3. `build.sh` — Assembles + builds the image in one step

---

## Boot Flow (what the ROM does)

1. User types `B0,1` → ROM calls boot_floppy with drive=0, starting LBA=1
2. ROM reads **config sector** (track 0, sector 1, 256 bytes) into buffer at 0xBEE9
3. ROM checks `boot_cfg` byte (buffer offset +2) for RAM bank enables — we set it to 0x00
4. ROM enters MOS hex record parser, streaming bytes from **LBA 1** onward (track 0, sector 2)
5. Parser reads records: our **data record** (0xC2) loads program at 0x8000
6. Parser hits **exec record** (0xC6): copies 13-byte trampoline to RAM, bank-switches ROM out, jumps to 0x8000
7. Our program runs with full RAM, video already initialized by POST

---

## Phase 1: Z80 Program (`demo.asm`)

### Design

- **ORG 0x8000** — main RAM, safe after bank-switch removes ROM
- Self-contained: cannot call ROM routines (ROM is banked out)
- Video hardware (SAA5120/SAA5150/SAA5070) already initialized by POST

### Pseudocode

```
entry:
    reset scroll registers (port 0x03 = 0, port 0x04 = 0)
    clear screen (25 rows × 80 cols, space + attribute 0x0E)
    write "Hello, World!" at row 12, col 33
    loop forever
```

### Video Write Protocol (per character)

The SAA5120 requires this exact port sequence:

1. Poll blanking: select LUCY reg 6 (`out (0x60), 6`), poll `in (0x70)` bit 0 until set
2. Set row: `out (0x00), row`
3. Write column with strobe: `out (0x01), col | 0x40`
4. Write character: `out (0x02), char`
5. Write column without strobe: `out (0x01), col`
6. Write attribute: `out (0x02), attr`

### Column Encoding

- Left half (cols 0–39): port value = col (0x00–0x27)
- Right half (cols 40–79): port value = (col − 40) | 0x80 (0x80–0xA7)
- "Hello, World!" at col 33 stays entirely in the left half

### Constants

```
PORT_VIDEO_ROW  = 0x00    PORT_LUCY_REG  = 0x60
PORT_VIDEO_CHAR = 0x01    PORT_LUCY_DATA = 0x70
PORT_VIDEO_ATTR = 0x02    LUCY_REG_SCAN  = 0x06
PORT_SCROLL     = 0x03    VID_WRITE_STROBE = 0x40
PORT_SCROLL_ALT = 0x04    ATTR_NORMAL    = 0x0E
```

### Expected Size

~60–80 bytes of Z80 code including the message string. Well within a single sector.

---

## Phase 2: MOS Hex Image Builder (`mkimage.py`)

### Record Format (as parsed by ROM at 0x00F6)

```
[LENGTH] [TYPE] [ADDR_H] [ADDR_L] [EXTRA] [DATA...]
```

- **LENGTH** — byte count of everything after this byte (type + addr + extra + data)
- **TYPE** — 0xC2 (data: load into RAM) or 0xC6 (exec: jump to address)
- **ADDR_H:ADDR_L** — 16-bit address, big-endian
- **EXTRA** — ROM reads but ignores (no checksum validation). Use 0x00.
- **DATA** — payload bytes (data records only)

### Records Needed

1. **Data record:** Load program at 0x8000
   - LENGTH = program_size + 4
   - TYPE = 0xC2
   - ADDR = 0x80, 0x00
   - EXTRA = 0x00
   - DATA = [program bytes]

2. **Exec record:** Jump to 0x8000
   - LENGTH = 0x04
   - TYPE = 0xC6
   - ADDR = 0x80, 0x00
   - EXTRA = 0x00

### Floppy Image Layout

| Offset | Size | Content |
|--------|------|---------|
| 0x000 | 256 B | Config sector — all zeros (boot_cfg=0x00 at offset 2) |
| 0x100 | 256 B | MOS hex records (data + exec), zero-padded to sector boundary |

Total image: **512 bytes**.

### Script Logic

```python
1. Read demo.bin
2. Assert len(demo.bin) <= 251  # max single record: 255 - 4 = 251 data bytes
3. Build data record bytes
4. Build exec record bytes
5. config_sector = b'\x00' * 256
6. mos_sector = data_record + exec_record, padded to 256 bytes
7. Write config_sector + mos_sector → demo_floppy.img
```

---

## Phase 3: Build Script (`build.sh`)

```bash
#!/bin/bash
set -e
cd "$(dirname "$0")"
z80asm demo.asm -o demo.bin
python3 mkimage.py
echo "Output: demo_floppy.img (512 bytes)"
echo "Boot with: B0,1 at MP2 monitor prompt"
```

---

## Verification Steps

1. **Assembler:** `z80asm demo.asm -o demo.bin` produces binary < 252 bytes
2. **Image hex check:** `hexdump -C demo_floppy.img | head -40`
   - Offset 0x000: all zeros (config sector)
   - Offset 0x100: length byte, then 0xC2, 0x80, 0x00, 0x00, then Z80 opcodes
   - After program data: 0x04, 0xC6, 0x80, 0x00, 0x00 (exec record)
3. **Mental trace:** Walk ROM's MOS hex parser with our records — confirm load at 0x8000, then exec jump
4. **Hardware test:** Write to floppy, boot with `B0,1`, confirm "Hello, World!" centered on screen

---

## Notes & Decisions

- **Sector size is 256 bytes** (not 128 as originally guessed). Confirmed by ROM's sector_buf at 0xBEE9 (256 bytes) and FD1797 usage.
- **Boot command `B0,1`** keeps the image tiny (512 bytes). Default boot (bare Enter) reads from LBA 0x80 which would require a 33KB image.
- **No checksum needed** — ROM reads the EXTRA byte but discards it.
- **Video sync is mandatory** — must poll SAA5070 reg 6 bit 0 before every VRAM write, otherwise display glitches.
- **z80asm dialect** — using the z80asm installed at /usr/local/bin/z80asm. If it's z88dk's version, syntax may need minor adjustment (e.g., `org` vs `.org`).

---

## Optional Enhancements (not in scope)

- Support default boot (pad image to 33KB so MOS hex lands at LBA 0x80)
- Add blinking cursor or keyboard interaction
- Multiple screen colors via different attribute values
