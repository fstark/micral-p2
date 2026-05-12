---
name: z80-asm
description: "Z80 assembly reference and tooling. Use when: reading/writing Z80 asm, using z80dasm/z80asm, checking file format specs, verifying round-trip assembly, or looking up Z80 hardware conventions."
---

# Z80 Assembly Reference & Tooling

Reference material for working with Z80 assembly: tool invocation, file formats, syntax rules, and hardware conventions.

## Tools

- **z80dasm** — Z80 disassembler (installed at `/usr/local/bin/z80dasm`)
- **z80asm** — Z80 assembler (installed at `/usr/local/bin/z80asm`) — used for round-trip verification

## z80dasm Invocation

```sh
z80dasm -a -l -g <ORIGIN> -t <FILE.BIN> -o <OUTPUT.asm>
```

Flags:
- `-a` — Print memory address in comments
- `-l` — Generate labels for jump targets
- `-g <ORIGIN>` — Set origin address (default 0x0100; use 0x0000 for boot ROMs)
- `-t` — Print hex+ASCII source data in comments
- `-b <file.def>` — Use block definition file
- `-S <file.sym>` — Use symbol file

## z80dasm File Formats

### Symbol File (.sym)

```
; comments start with semicolon
; format: label: equ 0xADDR
reset: equ 0x0000
irq_handler: equ 0x0038
main: equ 0x0100
```

- The colon after the label is **required**
- Use `0x` prefix for hex addresses
- **Tip:** Generate a sample with `z80dasm -g 0 -s sample.sym ROM.BIN` to confirm format

### Block Definition File (.def)

```
; comment lines start with semicolon
; format: name: start 0xADDR last 0xADDR type TYPE
reset_code: start 0x0000 last 0x0037 type code
irq_handler: start 0x0038 last 0x003c type code
padding: start 0x003d last 0x00ff type bytedata
```

- Types: `code`, `bytedata`, `worddata`, `pointers`
- `start` is the first byte, `last` is the last byte (inclusive)
- Use `0x` prefix for hex addresses
- **NOT** simple space-separated columns — uses keyword syntax

## z80asm Syntax Notes

- Constants use colon syntax: `label: equ 0bee8h` (colon required, unlike some assemblers)
- Hex values use `0` prefix + `h` suffix: `0bee8h`, `0ffh` (leading zero needed if starts with A-F)
- `defb` for byte data, `defw` for word data, `defm` for printable strings
- `defs N` for N bytes of padding (zero-filled)
- The `equ` definitions must appear before first use (put them after `org` but before code)
- VS Code: `detectIndentation: false` + `tabSize: 8` for proper column alignment

## Round-Trip Verification

After any modification to an assembly file, verify it still produces an identical binary:

```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
cmp ORIGINAL.BIN /tmp/roundtrip.bin
```

Or with diff for debugging mismatches:
```sh
diff <(xxd ORIGINAL.BIN) <(xxd /tmp/roundtrip.bin)
```

## Z80 Interrupt Vectors

For ROMs starting at 0x0000:

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

## Common Z80 Peripheral Chips

- **Z80-PIO** — 2 ports × (data + control), mode setting via control word sequences
- **Z80-SIO** — Serial I/O, channel A/B with data and control registers
- **Z80-CTC** — Counter/timer, 4 channels, time constant + control word
- **8255 PPI** — 3 ports + control, mode set via control byte bit 7=1
- **FDC (765/1793/1797)** — Command register, status register, data register, track/sector

## Comment Formatting

Use `format_asm.py` to align inline `;` comments to a consistent column:

```sh
python3 .copilot/skills/z80-asm-annotation/format_asm.py input.asm output.asm
```

Edit `COMMENT_COL` (default 40) and `TAB` (default 4) at the top of the script. Always round-trip verify after formatting.

## Tips

- Z80 is little-endian: `ld sp,0bee8h` stores as `31 e8 be`
- `rst` instructions are single-byte calls to fixed addresses (multiples of 8)
- Look for `di`/`ei` pairs around critical sections
- `halt` usually means "wait for interrupt"
- Sequences of `out` to the same port often indicate peripheral initialization
- Compare multiple ROMs from the same system — shared routines reveal the hardware abstraction layer
- When you see `cp` followed by conditional jumps, you're likely in a command dispatcher or state machine
- Use `defm` for sequences of printable ASCII characters (cleaner than individual `defb` values)
