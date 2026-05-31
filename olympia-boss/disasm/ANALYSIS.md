# Olympia Boss System ROM — Reverse Engineering Analysis

**ROM File:** `olympia_boss_system_251-462.bin`  
**Size:** 2048 bytes (2 KB)  
**Origin:** 0000h  
**CPU:** Zilog Z80A  
**Purpose:** Boot monitor, display driver, floppy/serial loader  
**Machine:** Olympia Boss (OEM of R2E Micral 80/60, ~1983)

---

## Summary

The Olympia Boss system ROM is the boot monitor for a Z80A-based word processor. On power-up it:

1. Initialises all hardware (8255 PPI, display controller, Intel 8257 DMA, AMD 9519 UIC, 2651 USART)
2. Displays a `BOSS ..` prompt on the 80×27 CRT display
3. Accepts interactive commands (boot, load, go, terminal echo)
4. Loads block-framed binary records from either the local µPD765 floppy or a USART-linked remote disk controller into RAM
5. Banks out the ROM and jumps to the loaded program

Two disk paths are supported:
- **Local FDC (`L`)**: µPD765 accessed directly via ports 71–73 (active-low signals). DMA via Intel 8257 into buffer at BED3h.
- **USART-linked controller (`B`)**: a remote disk controller accessed over a serial link (2651 USART, ports 10–11). Commands are sent as length-prefixed byte blocks; responses arrive via interrupt.

Auto-detection (`CR`) reads config bits from port 60h to choose between the two paths.

---

## ROM Layout

| Range | Size | Content |
|-------|------|---------|
| 0000h–0696h | 1687B | Code: reset, monitor, display driver, FDC driver |
| 0697h–06FFh | 105B | Data tables: strings, drive params, UIC init, FDC templates |
| 0700h–07EFh | 240B | Unused (zero-filled) |
| 07F0h–07FFh | 16B | IM 2 interrupt vector table (I = 07h) |

---

## Code Map

| Address | Symbol | Description |
|---------|--------|-------------|
| 0000h | `reset` | JP to `cold_start` |
| 0004h | `warm_entry` | JP to `warm_start` (DI already done) |
| 000Ah | `cold_start` | Full hardware init (PPI, display, 8257 DMA, UIC) |
| 007Ah | `cmd_loop` | Print `BOSS ..` prompt, dispatch command |
| ~00C0h | `cmd_load` | Parse B/L command arguments (drive, start sector) |
| ~0120h | `start_load` | Common load entry; selects FDC or USART path |
| 0190h | `serial_rx` | Block-framed binary record parser (data/exec/abort) |
| ~0220h | `get_srx_byte` | Feed bytes from sector buffer; refill from disk |
| ~0250h | `do_sector_rw` | Dispatch to FDC or USART-linked sector read |
| ~0290h | `divide_hl_e` | 16-bit unsigned division (track/sector arithmetic) |
| ~02B0h | `seek_track` | Seek FDC to track (with recalibrate on first access) |
| 032Ch | `usart_rx_isr` | USART RX interrupt handler (receive block reply) |
| ~0380h | `usart_read_stat` | Poll 2651 USART for received bytes |
| ~03A0h | `usart_tx_wait` | Wait for 2651 USART TX buffer empty |
| ~03B0h | `usart_send_blk` | Send C bytes from (HL) to USART |
| ~03C0h | `usart_send_wait` | Send block + wait for interrupt-driven completion |
| 03D8h | `isr_stub` | Stub ISR: EI + RET |
| 03DAh | `isr_usart_err` | USART error ISR: acknowledge AMD 9519 + RET |
| ~03F0h | `parse_hex` | Read hex digits, build 16-bit value |
| 0447h | `fdc_read_sector` | Read one sector via µPD765 FDC + Intel 8257 DMA |
| ~0530h | `fdc_wait_stat` | Poll FDC status register (active-low) |
| ~0540h | `fdc_send_cmd` | Send 8-byte command block to FDC |
| ~0550h | `fdc_send_data` | Send B bytes to FDC data port (with active-low inversion) |
| ~0560h | `cmd_terminal` | `*` command: keyboard echo to screen until ESC |
| ~0570h | `cmd_boot` | `CR` command: auto-detect USART vs FDC boot |
| ~05A0h | `cmd_go` | `G` command: bank-out ROM, jump to address |
| 053Fh | `kbd_isr` | Keyboard ISR: read PPI Port A, set KEY_FLAG |
| ~05B0h | `kbd_getchar` | Blocking keyboard poll |
| ~05C0h | `putchar` | Write character to display (handles CR, LF) |
| ~05E0h | `carriage_ret` | Move cursor to column 0 |
| ~05F0h | `advance_cur` | Move cursor right, wrap to next line at col 79 |
| ~0610h | `scroll_line` | Advance one line, scroll display if at bottom |
| 0670h | `crt_vsync_isr` | Vsync ISR: reprogram 8257 DMA + re-enable display |
| ~0680h | `program_dma_display` | Program 8257 Ch.2/Ch.3 for display DMA scrolling |
| ~06A0h | `update_cursor` | Send cursor col/line to display chip (port 81/80) |
| ~06B0h | `init_display_mem` | Fill display buffer with blank lines |
| ~06C0h | `init_one_line` | Write 80 spaces + 38 NULs + FF 00 for one line |
| ~06D0h | `fill_mem` | Fill A bytes at (HL) with byte E |
| ~06E0h | `memcopy` | Copy C bytes from (HL) to (DE) |
| ~06F0h | `get_trk_cmp` | Return pointer to track compare slot for current side |

---

## Memory Map

| Address Range | Size | Content |
|---------------|------|---------|
| 0000h–07FFh | 2KB | System ROM (banks out via port 60h bit 0) |
| BED2h | 2B | Stack pointer initial value |
| BED3h–BFD2h | 256B | `DMA_BUF` — DMA transfer buffer (Intel 8257 target) |
| BFD3h–BFFFh | 45B | RAM variables (see table below) |
| F2C6h–FFE5h | 3360B | Display character buffer (28 lines × 120 bytes) |
| FFE6h–FFEFh | 10B | Display state variables (scroll pointers, cursor) |

### RAM Variables (BFD3h–BFFFh)

| Address | Symbol | Description |
|---------|--------|-------------|
| BFD3h | `BUF_PTR` | Current read pointer into DMA buffer |
| BFD5h | `BLOCK_CNT` | Bytes remaining in current buffer |
| BFD7h | `LOAD_ADDR` | Current disk load address (sector index) |
| BFD9h | `FDC_CMD` | FDC command block (8 bytes) |
| BFDCh | `SEC_PER_TRK` | Sectors per track |
| BFDFh | `FDC_PARAMS` | FDC working parameters |
| BFE1h | `TRK_CMP_0` | Last-seeked track, side 0 (FFFFh = uninitialised) |
| BFE3h | `TRK_CMP_1` | Last-seeked track, side 1 |
| BFE5h | `USART_CMD` | USART command buffer (to remote disk controller) |
| BFE6h | `USART_SEEK` | USART seek command area |
| BFE7h | `USART_SEEKD` | USART seek data byte (target track) |
| BFE8h | `DRV_CONFIG` | Drive config byte (density, sides, sector size) |
| BFE9h | `DRV_PARAMS` | Drive parameter copy (drive select + side flag) |
| BFEAh | `CUR_TRACK` | Physical track currently under head |
| BFEBh | `SIDE_FLAG` | Current side (0 or 1) |
| BFECh | `STEP_RATE` | Step rate / sector interleave |
| BFEDh | `FDC_SEEKBUF` | FDC seek parameters (4 bytes) |
| BFF0h | `USART_RXBUF` | USART receive buffer (11 bytes) |
| BFFBh | `USART_DONE` | USART completion flag (0=pending, 1=done) |
| BFF8h | `DRV_TYPE` | Drive type/density flags |
| BFF9h | `PARAM_PTR` | Pointer to active drive parameter table |
| BFFCh | `SEC_SIZE` | Computed sector size (16-bit) |
| BFFEh | `KEY_FLAG` | Keyboard ready flag (0=none, 1=ready) |
| BFFFh | `KEY_DATA` | Keyboard data byte |

### Display Variables (FFE6h–FFEFh)

| Address | Symbol | Description |
|---------|--------|-------------|
| FFE6h | `SCR_LIMIT` | End of visible display area |
| FFE8h | `SCR_START` | Scroll window start (advances on each scroll) |
| FFEAh | `SCR_END` | Absolute end of display buffer |
| FFECh | `CUR_ADDR` | Cursor memory address in display buffer |
| FFEEh | `CUR_COL` | Cursor column (0–79) |
| FFEFh | `CUR_LINE` | Cursor line (0–27) |

---

## I/O Port Map

| Port | Dir | Chip | Function |
|------|-----|------|----------|
| 00h | OUT | Intel 8257 DMA | Ch.0 address — floppy sector read (write low, then high) |
| 01h | OUT | Intel 8257 DMA | Ch.0 word count — floppy sector read (write low, then high) |
| 04h | OUT | Intel 8257 DMA | Ch.2 address — µPD3301 display DMA (write low, then high) |
| 05h | OUT | Intel 8257 DMA | Ch.2 word count (bit 7 of high byte = read-from-memory) |
| 06h | OUT | Intel 8257 DMA | Ch.3 address — auto-reload source for scroll origin |
| 07h | OUT | Intel 8257 DMA | Ch.3 word count (auto-loaded into Ch.2 on terminal count) |
| 08h | OUT | Intel 8257 DMA | Mode register (41h=Ch.0 only, C5h=Ch.0+Ch.2+auto-load) |
| 10h | IN/OUT | 2651 USART | Control/status register |
| 11h | IN/OUT | 2651 USART | Data register |
| 30h | OUT | AMD 9519 UIC | Data / interrupt vector (low byte) |
| 31h | OUT | AMD 9519 UIC | Register select |
| 40h | IN | 8255 PPI | Port A — keyboard data (active-low) |
| 43h | OUT | 8255 PPI | Control register (mode set / BSR) |
| 60h | IN/OUT | System control | Read: drive config bits 7:6; Write: ROM bank, drive enable |
| 71h | OUT | µPD765 FDC | Control / mode select |
| 72h | IN | µPD765 FDC | Status register (active-low — complement before use) |
| 73h | IN/OUT | µPD765 FDC | Data register (active-low — complement before use) |
| 80h | OUT | NEC µPD3301 | Parameter data port (cursor col/line after DISP_CURSOR command) |
| 81h | OUT | NEC µPD3301 | Command register (reset, on, cursor, enable, mode, start) |

### System Control Port 60h

| Direction | Bits | Meaning |
|-----------|------|---------|
| Write | bit 0 | `1` = bank out ROM, map RAM at 0000h |
| Write | bit 1 | Drive select / enable USART-linked controller |
| Read | bits 7:6 | Drive type (00=local FDC, non-zero=USART path) |
| Read | bit 5 | Sector size modifier flag |

---

## Interrupt System

**Mode:** IM 2, interrupt register I = 07h → vector table at 07F0h

### UIC Initialisation (AMD 9519)

The AMD 9519 Universal Interrupt Controller is programmed at boot by writing 10 register/value pairs via ports 31h (register select) and 30h (data). The first 8 pairs load interrupt vector low bytes for vectors e0h–e7h, matching the IM2 table entries at 07F0h–07FEh.

### Vector Table (07F0h–07FFh)

| Offset | Vector | Handler | Description |
|--------|--------|---------|-------------|
| 07F0h | F0h | 0670h `crt_vsync_isr` | CRT vsync: reprogram CRTC scroll registers |
| 07F2h | F2h | 03D8h `isr_stub` | Unused (EI + RET) |
| 07F4h | F4h | 032Ch `usart_rx_isr` | USART RX: receive reply block from disk controller |
| 07F6h | F6h | 03D8h `isr_stub` | Unused |
| 07F8h | F8h | 053Fh `kbd_isr` | Keyboard: read PPI Port A, store in KEY_DATA |
| 07FAh | FAh | 03D8h `isr_stub` | Unused |
| 07FCh | FCh | 03D8h `isr_stub` | Unused |
| 07FEh | FEh | 03DAh `isr_usart_err` | USART error: acknowledge AMD 9519 + RET |

---

## Boot Sequence

### Cold Start (0000h → `cold_start`)

1. Set SP = BED2h
2. **8255 PPI init**: mode word BCh (Port A = mode-1 input), set PC2 (strobe), set PC4 (interrupt enable)
3. Clear `KEY_FLAG`
4. **Display memory init**: fill 27 lines with spaces (80 × space + 38 × NUL + FFh + 00h), set scroll window
5. **8257 DMA display init**: program Ch.2 (display window) and Ch.3 (scroll origin) via ports 04–07; activate with mode C5h via port 08
6. Cursor state: column 0, line 27 (bottom)
7. **Display chip init**: reset (00h), write 5-byte timing table, enable (A0h), set mode (42h), start (C0h)
8. Fall through to warm_start

### Warm Start (0004h → `warm_start`)

1. Reset SP = BED2h
2. Update cursor hardware
3. Display ON (20h)
4. **AMD 9519 UIC init**: write 10 register/value pairs — 8 interrupt vector low bytes (F0h–FEh), then 2 control words
5. Set I = 07h, IM 2 mode
6. Send 3 final UIC control words
7. EI
8. Fall through to cmd_loop

### Command Loop (`cmd_loop`)

Prints `\r\n BOSS .. ` then waits for a keypress:

| Key | Action |
|-----|--------|
| CR | `cmd_boot` — auto-detect drive type from port 60h bits 7:6; use USART path if non-zero, FDC if zero |
| `B` | `cmd_load` — USART-linked drive: parse `drive,start` args, query drive config, load |
| `L` | `cmd_load` — local FDC: load from sector 1 |
| `G` | `cmd_go` — parse hex address, bank out ROM, jump there |
| `*` | `cmd_terminal` — echo keyboard to display until ESC |

---

## Display System

**Chip:** NEC µPD3301 (ports 80–81)

### Buffer Layout

- **Base address:** F2C6h (`SCREEN_BASE`)
- **Line stride:** 120 bytes = 80 chars + 38 NUL padding + 2 end markers (FFh, 00h)
- **Total:** 28 lines × 120 bytes = 3360 bytes (27 visible + 1 scroll buffer line)
- **End markers** per line allow the DMA controller to detect line boundaries

### Scrolling

Scrolling is implemented via the 8257's **auto-load** feature (Ch.3 → Ch.2). Rather than copying memory, the firmware advances `SCR_START` and reprograms two DMA channels each frame:

- **Ch.2** (ports 04–05): points at the current display window start, count = window size. The µPD3301 issues DRQ2 to fetch characters through this channel.
- **Ch.3** (ports 06–07): points at the buffer base (scroll origin), count = bytes before `SCR_START`. When Ch.2 reaches terminal count, the 8257 auto-loads Ch.3’s address/count into Ch.2, implementing circular-buffer wrap.

On each vsync the `crt_vsync_isr` calls `program_dma_display` to reprogram both channels to the current `SCR_START` value. When the cursor reaches line 28, `SCR_START` is advanced by one line (120 bytes, wrapping at the buffer end).

### Cursor

Cursor position is tracked in RAM (`CUR_COL`, `CUR_LINE`, `CUR_ADDR`) and written to the µPD3301 via `update_cursor`: command byte 81h to port 81h (`PORT_UPD3301_CMD`), then column and line bytes to port 80h (`PORT_UPD3301_DATA`).

---

## Disk Subsystem

### Local FDC Path (`fdc_read_sector`, 0447h)

- **Chip:** µPD765 on ports 71–73 (all signals active-low — inverted in software)
- **DMA:** Intel 8257 Ch.0, programmed with destination BED3h and count 40FFh; mode register set to C5h (re-enables all channels including display DMA)
- **Track 0 detection:** recalibrate command (07h) sent if `TRK_CMP` = FFFFh
- **Seek:** command 0Fh, 2-byte block (command + track)
- **Side selection:** physical track = logical track / 2; side = logical track bit 0
- **Sector numbering:** 0-based, max 31 (`MAX_SECTOR`)

### USART-Linked Controller Path

- **Serial chip:** Signetics 2651 USART (ports 10–11)
- **Protocol:** length-prefixed command blocks sent via `usart_send_blk`; replies arrive as interrupts (vector F4h → `usart_rx_isr`), stored in `USART_RXBUF`
- **Seek command:** 3 bytes (FDC_SEEK / FDC_RECAL command, drive params byte, track number)
- **Read command:** 9 bytes starting at `DRV_CONFIG`
- **Completion:** `USART_DONE` polled by `usart_send_wait` after enabling TX interrupt via UIC

### Drive Types

Three drive parameter tables are selected from port 60h bits 7:6 (after rotation). Each table is 7 bytes encoding the µPD765 read command parameters and disk geometry:

| Bits 7:6 | Table | Format | Tracks | Sectors/track | Bytes/sector | Capacity |
|----------|-------|--------|--------|---------------|--------------|----------|
| 00 | special | (type 0 — sector count halved) | — | — | — | — |
| 01 | `drv_param_c` | **8″ SD — IBM 3740** | 76 | 26 | 128 | ~247 KB |
| 10 | `drv_param_a` | **5.25″ 40-track** | 40 | 16 | 256 | ~160 KB |
| 11 | `drv_param_b` | **8″ DD** | 76 | 26 | 256 | ~494 KB |

#### Parameter table byte layout

| Byte | Field | Description |
|------|-------|-------------|
| 0–1 | Controller ID | Fixed `53h 30h` — sent as type-select command to the USART-linked controller |
| 2 | Max tracks | Track count; also the high byte of the `SEC_SIZE` geometry word |
| 3 | N | µPD765 sector size code (0 = 128 B, 1 = 256 B) |
| 4 | EOT | µPD765 end-of-track / sectors per track; also the low byte of `SEC_SIZE` |
| 5 | GPL | µPD765 gap length for read operations |
| 6 | DTL | µPD765 data length (= actual byte count when N=0; ignored when N>0) |

The `SEC_SIZE` word assembled at load time is `(byte[2] << 8) | byte[4]`, encoding the full disk geometry as a single value used by the LBA→CHS divider in `do_sector_rw`.

---

## Binary Load Protocol

Both disk paths feed bytes into `serial_rx` (0190h), which parses a simple block-framed format:

| Field | Size | Description |
|-------|------|-------------|
| length | 1B | Total record bytes (0 = error) |
| type | 1B | Record type |
| address | 2B | Load address (if length ≥ 3) |
| extra | 1B | Ignored byte (if length ≥ 3) |
| data | n B | Payload |

### Record Types

| Code | Name | Action |
|------|------|--------|
| C2h | `REC_DATA` | Store payload bytes at address |
| D2h | `REC_ABORT` | Fatal error → cmd_error |
| C6h | `REC_EXEC` | Copy relay to RAM, bank out ROM, jump to address |
| C1h–DBh | skip range | Consume and discard record bytes |

### ROM Bank-Out (Execute Record)

A 5-byte relay snippet (`relay_code`) is copied to `DMA_BUF` (BED3h) before execution:

```
ld  a, 01h          ; SYS_BANKOUT
out (60h), a        ; ROM banks out, RAM maps to 0000h
jp  (hl)            ; Jump to loaded program
```

This ensures the ROM is gone before the program starts at its final address.
