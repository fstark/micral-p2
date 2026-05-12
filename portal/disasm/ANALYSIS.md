# Micral Portal Boot ROM — Reverse Engineering Analysis

**ROM File:** `portal.bin`  
**Size:** 2048 bytes (2 KB EPROM)  
**CPU:** Intel 8085A @ 5 MHz  
**Purpose:** Self-relocating monitor + floppy boot loader

---

## Summary

The Micral Portal boot ROM is a compact monitor/loader for a diskette-based microcomputer with a 32-character LED display. On power-up it:

1. Copies itself from ROM at 0000h to RAM at F800h (self-relocation)
2. Initializes hardware (PIC, keyboard, FDC)
3. Displays " PORTAL.." prompt on the 32-char LED display
4. Accepts commands: Boot, Go, set base address, terminal mode
5. Loads MOS-format hex records from floppy into RAM and executes them

The loading format supports data records, relocatable addresses, and fixup records — making it capable of loading position-independent code to arbitrary RAM locations.

---

## ROM Layout

The 2048-byte ROM is split into two logical sections:

| Offset | Size | Address | Content |
|--------|------|---------|---------|
| 0x0000–0x0016 | 23B | 0000h | Bootstrap: copy + jump |
| 0x0017–0x0432 | 1052B | F800h | Main monitor code + data |
| 0x0433–0x07FF | 973B | — | Unused (zero padding) |

The bootstrap runs at address 0000h (where the ROM is mapped at reset) and copies the main code to RAM at F800h, then jumps there. After this, the ROM at 0000h is no longer used.

---

## Memory Map (after relocation)

| Address Range | Size | Content |
|---------------|------|---------|
| 0xF7F8–0xF7FA | 3B | Interrupt vector (JP irq_fdc_handler) |
| 0xF800–0xF823 | 36B | Hardware init (SIM, PIC, FDC) |
| 0xF824–0xF878 | 85B | Main loop: prompt, command dispatch |
| 0xF879–0xF8EE | 118B | Boot sequence: spin-up, FDC init, geometry |
| 0xF8EF–0xF95D | 111B | MOS record parser (data, reloc, exec) |
| 0xF95E–0xF99E | 65B | Stream reader (sector buffer management) |
| 0xF99F–0xFA0D | 111B | LBA→CHS conversion + DMA + sector read |
| 0xFA0E–0xFA1D | 16B | Read error handler |
| 0xFA1E–0xFA26 | 9B | memcpy utility |
| 0xFA27–0xFA33 | 13B | Get current track pointer |
| 0xFA34–0xFA68 | 53B | Seek to track |
| 0xFA69–0xFA79 | 17B | Recalibrate (seek track 0) |
| 0xFA7A–0xFAAC | 51B | FDC interrupt handler |
| 0xFAAD–0xFAEC | 64B | FDC read result + send bytes |
| 0xFAED–0xFAFC | 16B | Send command + wait for IRQ |
| 0xFAFD–0xFB03 | 7B | Floppy parameters / geometry table |
| 0xFB04–0xFB3D | 58B | Hex number parser |
| 0xFB3E–0xFB65 | 40B | Terminal mode (*) |
| 0xFB66–0xFB80 | 27B | Commands: G, &, error handler |
| 0xFB81–0xFB8B | 11B | Keyboard read (KR3600) |
| 0xFB8C–0xFB96 | 11B | Prompt string: " PORTAL.." |
| 0xFB97–0xFC0B | 117B | Character I/O: putchar, CR, display refresh |
| 0xFC0C–0xFC1A | 15B | Print string utility |
| 0xFC1B–0xFC3E | 36B | RAM variables (FDC state) |
| 0xFC3F–0xFD3E | 256B | Sector buffer (DMA target) |
| 0xFD3F–0xFD5C | 30B | Stack space (grows down from FD5Dh) |
| 0xFD5D–0xFD5E | 2B | Display cursor pointer |
| 0xFD5F–0xFD7E | 32B | Display character buffer |

---

## I/O Port Map

| Port | Dir | Peripheral | Function |
|------|-----|------------|----------|
| 0x10 | IN | KR3600 | Keyboard status (bit 0 = data ready) |
| 0x11 | IN/OUT | KR3600 | Keyboard data (7-bit ASCII) / acknowledge |
| 0x40 | OUT | 8257 DMA | Channel 0 start address (low, then high byte) |
| 0x41 | OUT | 8257 DMA | Channel 0 terminal count + mode (low, then high) |
| 0x48 | OUT | 8257 DMA | Mode register |
| 0x50 | IN | µPD765 FDC | Main Status Register (MSR) |
| 0x51 | IN/OUT | µPD765 FDC | Data Register (command/result/data) |
| 0x60 | OUT | 8259 PIC | ICW1 / OCW2 (interrupt control) |
| 0x61 | OUT | 8259 PIC | ICW2–4 / OCW1 (vector/mask) |
| 0x80–0x9F | OUT | DL1416T ×8 | LED display characters (32 positions) |

---

## Interrupt System

The 8085's interrupt structure is used through the 8259 PIC:

| Source | PIC Input | Vector Address | Handler |
|--------|-----------|----------------|---------|
| µPD765 FDC | IR6 | F7F8h | irq_fdc_handler (FA7Ah) |

**PIC Configuration:**
- ICW1 = F6h: 8085 mode, 4-byte interval, single PIC, level-triggered
- ICW2 = F7h: Vector base = F7xxh
- OCW1 = BFh: Only IR6 unmasked

The vector at F7F8h is written by software (JP FA7Ah) rather than being in ROM, since the ROM is only at 0000h during bootstrap.

---

## Display System

The display consists of 8 × Litronix/Siemens DL1416T intelligent 4-character LED modules, providing a 32-character single-line display. Characters are mapped to I/O ports 80h–9Fh:

- Port 9Fh = leftmost character (position 0)
- Port 80h = rightmost character (position 31)

The display driver maintains a 32-byte RAM buffer at FD5Fh and refreshes all positions on every character change using self-modifying code (patching the OUT instruction's port byte in a loop).

A cursor character ('_', 5Fh) marks the current input position.

---

## Keyboard

The KR3600-017 keyboard encoder provides 7-bit ASCII parallel output:
- Port 10h bit 0: Data Available (active high)
- Port 11h: 7-bit key code (read when Data Available)
- Writing to port 11h: acknowledge / mode control

---

## Floppy Disk System

### Hardware
- **Controller:** NEC µPD765AC
- **DMA:** Mitsubishi M5L8257P-5 (channel 0 used for FDC data)
- **Drive:** Olivetti FD501 (single-sided, 48 TPI, 300 RPM)

### Disk Geometry
| Parameter | Value |
|-----------|-------|
| Sides | 1 (single-sided) |
| Tracks | 40 |
| Sectors/track | 16 |
| Bytes/sector | 256 (N=1) |
| Total capacity | 160 KB |
| Recording | MFM |
| Step rate | 11 ms (SRT=5) |
| Head load time | 48 ms (HLT=24) |
| Head unload time | 96 ms (HUT=3) |
| Gap 3 length | 32 |

### FDC Command Flow
1. CPU writes command bytes to µPD765 via port 51h (polling MSR for RQM+DIO)
2. DMA transfers sector data (256 bytes) directly to sector buffer at FC3Fh
3. µPD765 raises interrupt → PIC IR6 → vector F7F8h → handler reads result

### Default Boot Parameters
- Drive: 0
- Starting LBA: 128 (0x80) = track 8, sector 1
- Relocation base: 0x0110

---

## Monitor Commands

The monitor displays " PORTAL.." and accepts single-character commands:

| Command | Syntax | Function |
|---------|--------|----------|
| **CR** | (Enter) | Boot from drive 0, starting at LBA 128 |
| **B** | `B<drive>:<start_lba>` | Boot from specified drive (0–3) and LBA |
| **G** | `G<address>` | Jump to hex address |
| **&** | `&<address>` | Set relocation base for MOS records |
| **\*** | `*` | Terminal mode (keyboard echo, no exit) |

Error indicator: `#` is displayed for invalid commands or parse errors.

---

## MOS Hex Record Format

The floppy boot loader reads MOS (Machine Operating System) format records from disk. Each record has:

```
[length] [type] [addr_high] [addr_low] [flags] [data...]
```

| Type | Code | Function |
|------|------|----------|
| Data | C2h | Load bytes to sequential memory addresses |
| Relocation | D2h | Apply address fixups (add base to words) |
| Execute | C6h | Jump to loaded code entry point |
| (Skip) | C1h–DBh | Consume and ignore (future types) |

### Address Modes
- **Absolute** (flags bit 0 = 0): Address from record used directly
- **Relative** (flags bit 0 = 1): Address += relocation base (set by `&` command)

### Relocation Records (D2h)
Each byte contains a mask for 4 consecutive 16-bit words:
- Bit pair `00`: skip word (no relocation)
- Bit pair `01`: add relocation base (DE) to word at current address
- Bit pair `1x`: error (invalid)

### Data Records (C2h)
- Bytes are written to memory sequentially from the address
- Each write is verified (read-back compare); mismatch = error

### Execute Records (C6h)
- Simply does `JP (HL)` to the entry point
- No bank switching needed (code already runs from RAM)

---

## Boot Sequence (detailed)

1. **Bootstrap (0000h):** DI, copy 1052 bytes from ROM[17h] to RAM[F800h], JP F800h
2. **Init (F800h):** SIM (serial out high), set SP, clear keyboard, install IRQ vector at F7F8h
3. **PIC setup:** ICW1/ICW2 for 8085-mode vectors at F7xxh, unmask IR6 only
4. **Main loop (F824h):** Clear display, print " PORTAL..", await command
5. **Boot (F879h):**
   - Set boot flag, motor spin-up delay (~34K iterations with EI)
   - Send Specify command to µPD765 (step rate, head times)
   - Invalidate track cache (all drives = FFh)
   - Sense Drive Status (detect geometry — result unused, single-sided assumed)
   - Build Read Data command (46h, MFM)
   - Determine geometry: 40 tracks × 16 sectors
   - Enter MOS record parsing loop
6. **Record loading:** Sequential sector reads via DMA, parse records, load to RAM
7. **Execute:** JP (HL) to loaded program's entry point

---

## Comparison with Micral P2 Boot ROM

| Feature | Micral P2 | Micral Portal |
|---------|-----------|---------------|
| CPU | Z80A @ 4 MHz | 8085A @ 5 MHz |
| ROM size | 2 KB at 0000h | 2 KB, self-relocates to F800h |
| Display | 25×80 teletext (SAA5120) | 32-char LED (8× DL1416T) |
| FDC | FD1797 (WD-type) | µPD765 (NEC) + 8257 DMA |
| Data transfer | NMI-driven (byte at a time) | DMA (full sector) |
| Keyboard | KR3600 via SAA5070 LUCY | KR3600 direct |
| POST | Yes (VRAM, RAM, FDC, UART, timer) | None |
| Serial port | 2661 UART (loopback tested) | IM6402 + SCN2652 (not used by ROM) |
| Interrupts | IM1 (RST 38h) for timer | 8259 PIC, IR6 for FDC |
| Boot format | MOS hex records | MOS hex records (with relocation) |
| Bank switching | Yes (write to FFFFh latch) | No |
| Commands | B, G, M, * | B, G, &, * |
| Memory inspect | Yes (M command) | No |

---

## Notable Implementation Details

1. **Self-modifying display code:** The refresh_display routine patches the port number byte in its own OUT instruction during the loop — a classic space-saving technique on 8-bit CPUs.

2. **Stream abstraction:** The get_stream_byte function implements a record-aware stream reader. When C (byte counter) reaches zero, it automatically pops the call stack and returns to the record parser — an elegant coroutine-like pattern.

3. **Dead double-sided code:** The ROM checks ST3 bit 3 (Two-Side) from the µPD765, but due to `LD A,040h` overwriting the flag result, the drive is always treated as single-sided. This is correct for the Portal's Olivetti FD501 drive.

4. **No POST:** Unlike the P2, the Portal has no power-on self-test. It goes directly to the monitor prompt.

5. **DMA-based reads:** The P2 uses NMI (one byte per interrupt) for FDC data transfer; the Portal uses the 8257 DMA controller for full 256-byte sector transfers, which is faster and more CPU-efficient.
