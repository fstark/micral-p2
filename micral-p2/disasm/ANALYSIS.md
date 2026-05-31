# MICRAL P2 Boot ROM — Reverse Engineering Analysis

**ROM File:** `MICRAL_P2_CHARGEUR.BIN` ("CHARGEUR" = loader in French)  
**Size:** 2048 bytes (2 KB)  
**Origin:** 0x0000  
**CPU:** Zilog Z80  
**Purpose:** Power-On Self Test + Monitor + Floppy Boot Loader

---

## Summary

This is the bootstrap ROM for the Bull/R2E Micral P2 microcomputer. On power-up it:

1. Initializes hardware (keyboard controller, video)
2. Jumps to POST (Power-On Self Test) which tests VRAM, RAM, FDC, serial, and timer
3. Displays "AUTO-TEST : OK" or error codes
4. Enters a simple monitor with commands for booting from floppy, memory inspection, and I/O port access

The ROM communicates with user through a built-in video terminal driver (SAA5120/SAA5150 character-mapped display) and a KR3600 keyboard encoder mediated by the SAA5070 LUCY multi-function controller.

---

## Memory Map

| Address Range | Size | Content |
|---------------|------|---------|
| 0x0000–0x0032 | 51B  | Reset: SP init, hardware setup, jump to POST |
| 0x0033–0x0037 | 5B   | Padding (unused) |
| 0x0038–0x003C | 5B   | IM1 Interrupt handler (timer tick counter) |
| 0x003D–0x0065 | 41B  | Padding |
| 0x0066–0x006C | 7B   | NMI handler (reads FDC data byte) |
| 0x006E–0x0092 | 37B  | Display initialization |
| 0x0093–0x00F5 | 99B  | Monitor command prompt & parser |
| 0x00F6–0x01BC | 199B | Floppy boot loader (MOS hex record parser) |
| 0x01BD–0x02F0 | 308B | Floppy disk I/O (seek, read, restore) |
| 0x02F1–0x0317 | 39B  | Hex number input parser |
| 0x0318–0x034E | 55B  | Commands: * (transparent), CR (default boot), G (go) |
| 0x034F–0x042B | 221B | M command: memory dump, modify, I/O port read/write |
| 0x042C–0x0476 | 75B  | Hex output utilities |
| 0x0477–0x04C8 | 82B  | Keyboard driver |
| 0x04C9–0x05F9 | 305B | Character I/O + video display driver |
| 0x05FA–0x0789 | 400B | POST (Power-On Self Test) |
| 0x078A–0x0797 | 14B  | String: `"\r\n MP2 ..."` |
| 0x0798–0x07A7 | 16B  | String: `"\r\n AUTO-TEST : "` |
| 0x07A8–0x07FF | 88B  | Floppy parameters + padding |

### RAM Usage (inferred)

| Address | Purpose |
|---------|---------|
| 0xBEE8  | Stack pointer (grows down) |
| 0xBEE9  | Sector buffer (256 bytes) |
| 0xBEEB  | Record bytes remaining counter |
| 0xBFED  | Current sector/track for FDC |
| 0xBFEF  | FDC track number |
| 0xBFF0  | FDC sector number |
| 0xBFF1  | Sectors per track (word) |
| 0xBFF3  | System control flags / LED register shadow |
| 0xBFF4  | FDC side select |
| 0xBFF5  | Floppy parameter table pointer |
| 0xBFF7  | Video: current row |
| 0xBFF8  | Video: current column |
| 0xBFF9  | Video: current character |
| 0xBFFA  | Video: current attribute |
| 0xBFFB  | Video: scroll line counter |
| 0xBFFC  | Keyboard: key state flag |
| 0xBFFD  | Keyboard: last character read |
| 0xFFFF  | Bank switch latch register |

---

## I/O Port Map

| Port | Direction | Peripheral | Function |
|------|-----------|------------|----------|
| 0x00 | OUT | SAA5120/SAA5150 video | Row address |
| 0x01 | OUT | SAA5120/SAA5150 video | Character data (bit 6 = write strobe) |
| 0x02 | IN/OUT | SAA5120/SAA5150 video | Attribute data (read-back for test) |
| 0x03 | OUT | SAA5120/SAA5150 video | Scroll register (line offset) |
| 0x04 | OUT | SAA5120/SAA5150 video | Scroll register (alternate) |
| 0x07 | OUT | Timer/CTC | Timer reload (in IRQ handler) |
| 0x10 | IN/OUT | FD1797 FDC | Command (W) / Status (R) |
| 0x11 | IN/OUT | FD1797 FDC | Track register |
| 0x12 | IN/OUT | FD1797 FDC | Sector register |
| 0x13 | IN/OUT | FD1797 FDC | Data register |
| 0x20 | OUT | System control | LED/drive select/bank flags |
| 0x30 | IN | KR3600 keyboard encoder | Parallel data output (7-bit ASCII) |
| 0x50 | IN/OUT | 2661 UART | Data register |
| 0x51 | IN | 2661 UART | Status register |
| 0x52 | OUT | 2661 UART | Mode register |
| 0x53 | OUT | 2661 UART | Command register |
| 0x60 | OUT | SAA5070 (LUCY) | Register select |
| 0x70 | IN/OUT | SAA5070 (LUCY) | Register data (R/W) |

---

## Interrupt Vectors

| Address | Vector | Implementation |
|---------|--------|----------------|
| 0x0000 | RESET | ✅ Full hardware init → POST |
| 0x0008 | RST 08h | ❌ Unused (NOPs) |
| 0x0010 | RST 10h | ❌ Unused |
| 0x0018 | RST 18h | ❌ Unused |
| 0x0020 | RST 20h | ❌ Unused |
| 0x0028 | RST 28h | ❌ Unused |
| 0x0030 | RST 30h | ❌ Unused |
| 0x0038 | RST 38h / IM1 | ✅ Timer tick: `inc d; out (07h),a; ei; ret` |
| 0x0066 | NMI | ✅ FDC DRQ handler: reads data byte from port 0x13 into (HL)++ |

---

## Boot Sequence (Power-On)

1. **Reset (0x0000):** Set SP to 0xBEE8
2. **Keyboard init:** Write 0x22 to port 0x20 (enable keyboard), short delay, then clear
3. **SAA5070 init:** Program LUCY chip via ports 0x60/0x70 — configure registers, write 0xFF to registers 6 and 7 (keyboard scan enable)
4. **Jump to POST (0x05FA)**
5. **POST — Video RAM test:** Write/verify pattern to character-mapped display (25 rows × 80 cols)
6. **POST — Main RAM test:** Write/verify 32KB at 0x8000, relocates test code to high RAM to test lower region
7. **POST — FDC test:** Verify FDC registers (track, sector, data) hold written values
8. **POST — Serial test:** Initialize 2661 UART (mode 0x4E/0x3E, command 0xA7), loopback test with incrementing pattern
9. **POST — Timer test:** Enable IM1, run counter for calibration period, verify expected tick count (0x23–0x25)
10. **POST complete (0x074F):** Initialize display, print `"\r\n AUTO-TEST : "`, then "OK" or error bit codes

### POST Error Table

On completion, POST displays `AUTO-TEST : OK` if all tests pass. On failure, it prints each failed test's bit number as an ASCII digit on a separate line. Error bits accumulate in A' (shadow register) and are displayed LSB-first.

| Bit | Displayed | Subsystem | Test Method | Pass Criteria |
|-----|-----------|-----------|-------------|---------------|
| 0 | `0` | Video RAM (SAA5120) | Write incrementing pattern (+0x55) to all 25×80 cells via two-phase column protocol, then read back attributes | All 4000 attribute bytes match expected pattern |
| 1 | `1` | Main RAM (32 KB) | Write/verify pattern across 0x8000–0xFFFF; then relocate test code to high RAM to test 0x0000–0x7FFF with bank select (port 0x20 = 0x60) | All 32768 bytes match in both banks |
| 2 | `2` | FDC (FD1797) | Force-interrupt, then write rotating pattern (+0x55) to track, sector, and data registers; read back after 80-cycle settle delay; repeat until pattern wraps to 0 | All register read-backs match written values across full cycle |
| 3 | `3` | Serial (2661 UART) | Configure for 8N1 loopback (mode 0x4E/0x3E, cmd 0xA7); send each pattern byte, wait 256-cycle delay, read back | All echoed bytes match sent values; TX-ready within 255 polls |
| 4 | `4` | Timer (CTC / IM1) | Enable IM1 interrupts; ISR at 0x0038 increments D on each tick; main loop counts down 65536 iterations; check D | Tick count D in range 35–36 (0x23–0x24) |

**Example display on failure:** If VRAM and FDC fail, the screen shows:
```
 AUTO-TEST : 
0
2
```

---

## Monitor Commands

After POST, the monitor prints `"\r\n MP2 ..."` and accepts single-letter commands:

| Command | Syntax | Function |
|---------|--------|----------|
| **CR** | (just press Enter) | Boot from drive 0, track 0, sector 1 (default) |
| **B** | `B<drive>,<sector>` | Boot from specified drive (0/1) and starting sector |
| **G** | `G<addr>` | Execute code at address (with bank switch) |
| **\*** | `*` | Transparent terminal mode (echo keyboard to screen, ESC exits) |
| **M** | `M` | Enter memory submenu |

### Memory Submenu (M command)

| Sub-cmd | Syntax | Function |
|---------|--------|----------|
| **D** | `D<start>,<end>` | Hex dump memory range |
| **M** | `M<addr>` | Modify memory (enter hex, '.' to exit) |
| **I** | `I<port>` | Read and display I/O port |
| **O** | `O<port>,<value>` | Write value to I/O port |
| **G** | `G<addr>` | Go (execute) |
| **R** | `R` | Return to main prompt |

---

## Floppy Boot Process

The boot loader reads sectors from a WD1793-compatible FDC and parses a **MOS Technology hex record format** (similar to Intel HEX but with different record types):

### Record Format

Each record from disk has:
- **Length byte** (C): number of data bytes
- **Type byte** (B): record type identifier
- For types ≥ 3: **Address** (H:L, 2 bytes) + extra byte

### Record Types

| Type (hex) | Meaning |
|------------|---------|
| 0xC2 | Data record — load bytes into memory at current address |
| 0xC6 | Execution record — transfer control to loaded code |
| 0xD2 | Error/skip — abort loading |
| 0xC1–0xDA | Other valid range (consumed but action varies) |

### Bank Switching (exec_loaded_code at 0x019D)

When a C6 record is encountered, the ROM:
1. Copies a 13-byte trampoline to RAM (0xBEE9)
2. The trampoline sets bit 6 in the control flags, writes to 0xFFFF (bank switch), outputs 0x40 to port 0x20
3. Jumps to the loaded program via `jp (hl)`

This maps out the ROM and maps in full RAM, then executes the loaded operating system.

---

## Video Display (SAA5120 + SAA5150)

- **SAA5150** video timing/display processor + **SAA5120** character generator
- **25 rows × 80 columns** character-mapped display
- Character + attribute stored via ports 0x00 (row), 0x01 (char), 0x02 (attr)
- Port 0x01 bit 6 distinguishes write strobe (set) from normal output
- Port 0x03/0x04: hardware scroll register
- Cursor implemented by toggling attribute bit (XOR 0xC0)
- Software scroll: rewrites entire screen row by row
- SAA5070 register 6 polled (port 0x70 bit 0) for display blanking sync before VRAM write

---

## Keyboard (KR3600 + SAA5070)

- **KR3600** keyboard matrix encoder provides parallel ASCII output at port 0x30
- **SAA5070 (LUCY)** mediates keyboard status via register 7 (port 0x60=select, 0x70=data)
- SAA5070 reg 7, bit 0: key pressed flag
- SAA5070 reg 7, bit 1: key released flag  
- Port 0x30: KR3600 data output (7-bit, masked with 0x7F)
- Includes auto-repeat logic with debounce delay (0x0A00 loop iterations)
- KR3600 has a separate mapping ROM for scan-code to ASCII conversion

---

## FDC (Floppy Disk Controller)

- **FD1797** (WD179x family, active-high data bus variant) at ports 0x10–0x13
- Commands used:
  - 0xD0: Force interrupt (abort/reset)
  - 0x0F: Restore (seek track 0)
  - 0xC4: Read sector (with side flag)
  - 0x5F: Step-in
  - 0x1F: Seek to track
  - 0x88: Read sector (multi)
- Status bits checked: bit 0 (busy), bit 2 (lost data), bit 3 (CRC error), bit 4 (record not found)
- NMI used for DRQ (data request) — byte-by-byte transfer to memory
- Sector buffer at 0xBEE9 (256 bytes)
- Supports 2 drives (drive select via bit 2/3 of port 0x20 shadow at 0xBFF3)
- Side select via bit 4 of port 0x20 and FDC command bits

---

## Files Produced

| File | Description |
|------|-------------|
| `disasm/boot_raw.asm` | Raw disassembly (auto-labels only) |
| `disasm/boot_annotated.asm` | Annotated disassembly with meaningful labels |
| `disasm/symbols.sym` | Symbol file for z80dasm |
| `disasm/blocks.def` | Block definition file (code vs data regions) |

---

## System Architecture (inferred from ROM analysis)

```
                          ┌──────────────────────────────┐
                          │         Z80 CPU (4 MHz)      │
                          │                              │
                          │  A0-A15  D0-D7  NMI  INT    │
                          └──┬────────┬───────┬────┬────┘
                             │        │       │    │
        ─────────────────────┼────────┼───────┼────┼──────────────
                  System Bus │  Data  │       │    │
                             │        │       │    │
    ┌────────────────────────┴────────┴───────┴────┴──────────────┐
    │                   Address Decoder (active-low CS)           │
    │  A4-A6 select chip   A0-A3 select register                 │
    │  Active I/O ranges: 00-07, 10-13, 20, 30, 50-53, 60, 70   │
    └──┬──────┬───────┬───────┬────────┬────────┬───────┬────────┘
       │      │       │       │        │        │       │
       │      │       │       │        │        │       │
  ┌────┴───┐  │  ┌────┴────┐  │   ┌────┴────┐   │  ┌───┴─────┐
  │SAA5120 │  │  │ FD1797  │  │   │  2661   │   │  │ SAA5070 │
  │SAA5150 │  │  │  FDC    │  │   │  UART   │   │  │ (LUCY)  │
  │ Video  │  │  │         │  │   │         │   │  │         │
  │        │  │  │ P 10-13 │  │   │ P 50-53 │   │  │ P 60,70 │
  └───┬────┘  │  └────┬────┘  │   └─────────┘   │  └──┬──┬───┘
      │       │       │       │                  │     │  │
  P 00-04     │    NMI ───────┘             P 30 │     │  │
  25×80 char  │    (DRQ)              ┌──────────┘     │  │
  display     │                       │                │  │
              │                  ┌────┴────┐     ┌─────┴──┘
         ┌────┴────┐             │ KR3600  │     │ CTC Timer
         │ System  │             │Keyboard │     │ P 07
         │ Control │             │ Encoder │     │    │
         │ P 20    │             │(+map ROM│     │  INT ──→ RST 38h
         │         │             │ CLAVIER)│     │  (IM1)
         └────┬────┘             └─────────┘     └─────────
              │
     ┌────────┼────────┐
     │        │        │
  Drive    Motor    Bank
  Select   Enable   Switch
  bit2/3   bit4     bit6
```

### Memory Map

```
  Bank Switch OFF (reset default)       Bank Switch ON (bit 6 set)
  ┌────────────────────┐                ┌────────────────────┐
  │ 0x0000             │                │ 0x0000             │
  │   Boot ROM (2 KB)  │                │   RAM (banked)     │
  │ 0x07FF             │                │                    │
  ├────────────────────┤                │                    │
  │ 0x0800             │                │                    │
  │   (unmapped/echo?) │                │                    │
  │                    │                │                    │
  ├────────────────────┤                ├────────────────────┤
  │ 0x8000             │                │ 0x8000             │
  │   RAM (32 KB)      │                │   RAM (32 KB)      │
  │                    │                │                    │
  │                    │                │                    │
  ├────────────────────┤                ├────────────────────┤
  │ 0xBEE8  Stack/Vars │                │                    │
  │ 0xBEE9  Sector Buf │                │                    │
  │ 0xBFF3  Sys Flags  │                │                    │
  │ 0xBFF7  Video Vars │                │                    │
  │ 0xBFFD  Kbd Vars   │                │                    │
  ├────────────────────┤                ├────────────────────┤
  │ 0xFFFD  Bank2 Ctrl │                │ 0xFFFD  Bank2 Ctrl │
  │ 0xFFFF  Bank Latch │                │ 0xFFFF  Bank Latch │
  └────────────────────┘                └────────────────────┘
```

### Interrupt Wiring

```
  FD1797 DRQ ──────→ Z80 NMI (0x0066)     Byte-by-byte FDC data transfer
  CTC Timer ───────→ Z80 INT / IM1 (0x0038)  Tick counter for POST calibration
```

### Port 0x20 (System Control) Bit Map

```
  Bit 7:  Double-density select (SD/DD floppy)
  Bit 6:  Bank switch (0=ROM visible, 1=RAM replaces ROM)
  Bit 5:  Video sync pending (software flag)
  Bit 4:  Floppy motor enable
  Bit 3:  Drive 1 select
  Bit 2:  Drive 0 select
  Bit 1:  Keyboard enable (active during init pulse)
  Bit 0:  (active / LED)
```

### Address Decoding (inferred from I/O port usage)

```
  A6  A5  A4 │ Chip Selected        │ Port Range
  ────────────┼──────────────────────┼───────────
   0   0   0 │ SAA5120/5150 (video) │ 0x00–0x07
   0   0   1 │ FD1797 (FDC)         │ 0x10–0x13
   0   1   0 │ System control latch │ 0x20
   0   1   1 │ KR3600 (keyboard)    │ 0x30
   1   0   1 │ 2661 (UART)          │ 0x50–0x53
   1   1   0 │ SAA5070 reg select   │ 0x60
   1   1   1 │ SAA5070 reg data     │ 0x70
```
