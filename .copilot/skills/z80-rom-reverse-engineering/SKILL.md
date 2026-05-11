---
name: z80-rom-reverse-engineering
description: "Reverse engineer Z80 ROM code from .BIN files. Use when: disassembling Z80 binaries, analyzing boot ROMs, documenting I/O port usage, mapping memory layout, identifying subroutines, or annotating vintage Z80 firmware."
argument-hint: "Path to .BIN file and optional origin address, e.g. ROMs/BOOT.BIN 0x0000"
---

# Z80 ROM Reverse Engineering

Disassemble and analyze Z80 binary ROM dumps, producing annotated assembly listings with identified subroutines, data regions, I/O port maps, and memory layout documentation.

## Tools

- **z80dasm** — Z80 disassembler (installed at `/usr/local/bin/z80dasm`)

## Procedure

### Phase 1: Initial Disassembly

Disassemble the target ROM with full annotations:

```sh
z80dasm -a -l -g <ORIGIN> -t <FILE.BIN> -o <OUTPUT.asm>
```

Flags used:
- `-a` — Print memory address in comments
- `-l` — Generate labels for jump targets
- `-g <ORIGIN>` — Set the origin address (default 0x0100; use 0x0000 for boot ROMs)
- `-t` — Print hex+ASCII source data in comments

If origin is not specified, infer from context:
- Boot/reset ROMs → `0x0000`
- CP/M programs → `0x0100`
- Otherwise ask the user

### Phase 2: Identify Code vs Data Regions

Scan the raw disassembly for patterns that indicate data rather than code:

1. **Strings** — Sequences of printable ASCII bytes (0x20–0x7E) followed by a terminator (0x00, 0x0D, '$')
2. **Jump tables** — Consecutive 16-bit addresses (sequences of `defw`)
3. **Lookup tables** — Repeating fixed-size structures
4. **Padding** — Long runs of `nop` (0x00) or `0FFh`
5. **Unreachable code** — Instructions after unconditional `jp`, `ret`, or `rst` with no label

Once identified, create a block definition file for z80dasm to produce cleaner output:

```
# block-def file format: start end type
# types: code, data, bytedata, worddata, pointers
0x0000 0x00FF code
0x0100 0x013F bytedata
```

Then re-disassemble with the block file:
```sh
z80dasm -a -l -g <ORIGIN> -t -b blocks.def <FILE.BIN> -o <OUTPUT.asm>
```

### Phase 3: Identify Interrupt Vectors

For ROMs starting at 0x0000, document the Z80 interrupt/restart vectors:

| Address | Vector |
|---------|--------|
| 0x0000  | RESET  |
| 0x0008  | RST 08h |
| 0x0010  | RST 10h |
| 0x0018  | RST 18h |
| 0x0020  | RST 20h |
| 0x0028  | RST 28h |
| 0x0030  | RST 30h |
| 0x0038  | RST 38h (IM1 interrupt) |
| 0x0066  | NMI |

Check which vectors contain actual handlers vs padding.

### Phase 4: I/O Port Analysis

Extract all `in` and `out` instructions:

```sh
grep -E '^\s+(in|out)\s' <OUTPUT.asm> | sort -u
```

Build an I/O port map documenting:
- Port address
- Direction (read/write/both)
- Likely peripheral (based on common Z80 system chips: PIO, SIO, CTC, DMA, FDC)
- Values written and their meaning (control words, data)

Common Z80 peripheral chips and their programming patterns:
- **Z80-PIO** — 2 ports × (data + control), mode setting via control word sequences
- **Z80-SIO** — Serial I/O, channel A/B with data and control registers
- **Z80-CTC** — Counter/timer, 4 channels, time constant + control word
- **8255 PPI** — 3 ports + control, mode set via control byte bit 7=1
- **FDC (765/1793)** — Command register, status register, data register, track/sector

### Phase 5: Subroutine Identification

Identify and name subroutines by analyzing:

1. **Call targets** — All addresses referenced by `call` instructions
2. **Entry patterns** — `push` sequences at function prologues
3. **Exit patterns** — `ret`, `ret z`, `ret nz`, etc.
4. **Functionality** — What the routine does (I/O init, string print, memory copy, etc.)

Create a symbol file for z80dasm:

```
# symbol file format: address label ; comment
0x0000 reset ; Cold boot entry
0x0038 irq_handler ; IM1 interrupt service routine
0x0100 init_serial ; Initialize SIO port A
```

Then re-disassemble with symbols:
```sh
z80dasm -a -l -g <ORIGIN> -t -b blocks.def -S symbols.sym <FILE.BIN> -o <OUTPUT.asm>
```

### Phase 6: Documentation Output

Produce a markdown analysis document containing:

1. **Summary** — ROM purpose, size, origin address, hardware target
2. **Memory Map** — Code regions, data regions, tables, strings
3. **I/O Port Map** — All ports with peripheral identification
4. **Interrupt Vectors** — Which are implemented
5. **Subroutine Table** — Address, name, purpose, calling convention
6. **Boot Sequence** — Step-by-step walkthrough of initialization code
7. **Annotated Assembly** — Key sections with explanatory comments

## Iterative Refinement

Reverse engineering is iterative. After each pass:
1. Update the block definition file with newly identified data regions
2. Update the symbol file with newly named subroutines
3. Re-disassemble to get cleaner output
4. Cross-reference subroutines to understand calling relationships

## Symbol File Format (z80dasm)

```
; comments start with semicolon
; format: address name
0x0000 reset
0x0038 irq_handler
; address can also use decimal
256 main
```

## Block Definition File Format (z80dasm)

```
; Line format: START END TYPE
; Types: code, data, bytedata, worddata, pointers
; Addresses are hex with 0x prefix or decimal
0x0000 0x0037 code
0x0038 0x003c code
0x003d 0x00ff bytedata
```

## Tips

- Z80 is little-endian: `ld sp,0bee8h` stores as `31 e8 be`
- `rst` instructions are single-byte calls to fixed addresses (multiples of 8)
- Look for `di`/`ei` pairs around critical sections
- `halt` usually means "wait for interrupt"
- Sequences of `out` to the same port often indicate peripheral initialization
- Compare multiple ROMs from the same system — shared routines reveal the hardware abstraction layer
- When you see `cp` followed by conditional jumps, you're likely in a command dispatcher or state machine
