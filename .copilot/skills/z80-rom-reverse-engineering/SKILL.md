---
name: z80-rom-reverse-engineering
description: "Reverse engineer Z80 ROM code from .BIN files. Use when: disassembling Z80 binaries, analyzing boot ROMs, documenting I/O port usage, mapping memory layout, identifying subroutines, or annotating vintage Z80 firmware."
argument-hint: "Path to .BIN file and optional origin address, e.g. ROMs/BOOT.BIN 0x0000"
---

# Z80 ROM Reverse Engineering

Disassemble and analyze Z80 binary ROM dumps, producing annotated assembly listings with identified subroutines, data regions, I/O port maps, and memory layout documentation.

## Tools

- **z80dasm** — Z80 disassembler (installed at `/usr/local/bin/z80dasm`)
- **z80asm** — Z80 assembler (installed at `/usr/local/bin/z80asm`) — used for round-trip verification

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

Once identified, create a block definition file for z80dasm to produce cleaner output.

**IMPORTANT:** Block definition format uses keyword syntax, NOT simple columns:

```
; comment lines start with semicolon
reset_init: start 0x0000 last 0x0032 type code
pad_data:   start 0x0033 last 0x0037 type bytedata
irq_code:   start 0x0038 last 0x003c type code
```

Format: `name: start 0xADDR last 0xADDR type TYPE`
- Types: `code`, `bytedata`, `worddata`, `pointers`
- `start` is the first byte, `last` is the last byte (inclusive)
- Use `0x` prefix for hex addresses

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

Create a symbol file for z80dasm.

**IMPORTANT:** Symbol file format uses `label: equ 0xADDR`, NOT space-separated columns:

```
; comment lines start with semicolon
reset: equ 0x0000
irq_handler: equ 0x0038
init_serial: equ 0x0100
```

Format: `label: equ 0xADDR`
- The colon after the label is required
- Use `0x` prefix for hex addresses
- To generate a sample, use: `z80dasm -g 0 -s sample.sym ROM.BIN` then inspect sample.sym

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

### Phase 7: RAM Variable Symbolification

After the annotated disassembly is complete, scan for raw memory addresses used as variables and replace them with named EQU definitions.

#### Step 1: Find all direct address references

```sh
grep -oE '0[0-9a-f]{3,4}h' annotated.asm | sort | uniq -c | sort -rn
```

Focus on addresses in the RAM region (not ROM code addresses). These are typically used with `ld (addr),a`, `ld a,(addr)`, `ld hl,addr` followed by `(hl)` operations, and `ld (addr),hl`.

#### Step 2: Infer purpose from usage context

For each RAM address, grep its occurrences and study the surrounding code to determine:
- What values are written to it (constants, computed values, I/O reads)
- What reads from it and how the value is used
- Whether it's a byte, word, or pointer
- Its role in the system (video state, keyboard buffer, FDC parameters, etc.)

#### Step 3: Add EQU definitions

Insert a block of `equ` definitions after the `org` directive but before the first code label. Include a short comment documenting each variable's purpose:

```z80
; --- RAM variables ---
cursor_row:	equ	0bff7h		; Display cursor row position (0..24)
cursor_col:	equ	0bff8h		; Display cursor column position
kbd_state:	equ	0bffch		; Keyboard debounce state flag
```

#### Step 4: Replace raw addresses in code

Use sed to bulk-replace all occurrences of each raw address with its symbolic name:

```sh
sed -i '' \
  -e 's/0bff7h/cursor_row/g' \
  -e 's/0bff8h/cursor_col/g' \
  -e 's/0bffch/kbd_state/g' \
  annotated.asm
```

**Order matters:** Replace longer/more-specific addresses first to avoid partial matches (e.g. replace `0beebh` before `0bee9h`).

#### Step 5: Round-trip verify

Always reassemble and diff after bulk replacements to confirm nothing was corrupted:

```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
diff <(xxd ORIGINAL.BIN) <(xxd /tmp/roundtrip.bin)
```

### Phase 8: Named Constants for Magic Values

After subroutines and RAM variables are symbolified, replace raw hex literals used as hardware commands, bit masks, configuration values, and ASCII characters with named EQU constants.

#### Step 1: Inventory magic values

Grep for immediate operands that aren't already symbolic:

```sh
# Find raw hex in ld, cp, and, or, xor, add, sub, out, in instructions
grep -nE '\b0[0-9a-f]{2,3}h\b' annotated.asm | grep -vE '(equ|defb|defw)' | sort
```

Ignore values that are already named (EQU references) and data bytes (`defb`/`defw`).

#### Step 2: Categorize by peripheral / subsystem

Group the magic values into logical categories:

- **I/O Ports** — Port addresses used in `in`/`out` instructions (e.g. `PORT_FDC_CMD equ 010h`)
- **Hardware commands** — Command bytes written to peripherals (e.g. `FDC_CMD_RESTORE equ 00fh`)
- **Status masks** — Bit masks used with `and`/`or`/`bit` after reading status (e.g. `FDC_STAT_BUSY equ 01h`)
- **Configuration values** — Init bytes for UARTs, timers, video (e.g. `UART_MODE1 equ 04eh`)
- **Protocol constants** — Record types, magic numbers in data formats (e.g. `REC_DATA equ 0c2h`)
- **Display constants** — Screen geometry, attribute values, cursor control (e.g. `SCREEN_ROWS equ 019h`)
- **ASCII characters** — Use character literals for printable chars (`'M'`, `':'`, `' '`) and named EQUs for control characters (`CR equ 00dh`, `ESC equ 01bh`)

#### Step 3: Add EQU definitions grouped by category

Insert after the RAM variable EQUs, before the first code label. Group with section headers:

```z80
; --- I/O Ports ---
PORT_FDC_CMD:	equ	010h		; FD1797 command (W) / status (R)
PORT_FDC_TRACK:	equ	011h		; FD1797 track register

; --- FD1797 Commands ---
FDC_CMD_RESTORE:	equ	00fh		; Restore to track 0
FDC_CMD_FORCE_INT:	equ	0d0h		; Force interrupt

; --- ASCII Control Characters ---
CR:		equ	00dh		; Carriage return
LF:		equ	00ah		; Line feed
ESC:		equ	01bh		; Escape
```

#### Step 4: Replace in instruction operands

Replace each raw value with its constant name. Target `ld`, `cp`, `and`, `or`, `xor`, `add`, `sub`, `in`, `out` operands — but NOT `defb`/`defw` data.

For ASCII printable characters, use z80asm character literals directly:
```z80
	cp 'M'		; instead of cp 04dh
	ld c,':'	; instead of ld c,03ah
	ld a,' '	; instead of ld a,020h
```

For control characters and hardware values, use the named EQU:
```z80
	cp CR		; instead of cp 00dh
	ld a,FDC_CMD_RESTORE	; instead of ld a,00fh
```

**Do NOT replace:**
- `defb`/`defw` in string data or lookup tables
- Values that happen to match but have different meaning in context (e.g. `ld bc,0000dh` where 13 is a byte count, not a CR character)
- Addresses used as code targets or memory addresses

#### Step 5: Round-trip verify

```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
cmp ORIGINAL.BIN /tmp/roundtrip.bin
```

### Phase 9: Meaningful Label Names for Branch Targets

After subroutines, RAM variables, and constants are symbolified, the remaining auto-generated labels (e.g. `l0009h`, `l06a9h`) are local branch targets — loop bodies, error exits, conditional branches, and fallthrough points. Renaming them eliminates the need to mentally trace every jump.

#### Step 1: Inventory auto-labels

```sh
grep -c '^l[0-9a-f]\+h:' annotated.asm
```

Expect dozens (40–80 in a typical boot ROM). Each is a `jr`/`jp`/`djnz` target.

#### Step 2: Categorize by surrounding context

Read the code around each label and assign it to one of these naming patterns:

| Pattern | Convention | Examples |
|---------|-----------|----------|
| Busy-wait / polling loop | `wait_<what>` | `wait_fdc_idle`, `wait_seek_done`, `wait_video_sync` |
| Countdown / iteration loop | `<thing>_loop` | `delay_loop`, `div_loop`, `timer_count_loop` |
| Inner loop body | `<outer>_<action>` | `ram_write_byte`, `dump_byte`, `hex_next_char` |
| Conditional branch (if-true) | `<what_happens>` | `check_bank2`, `set_single_density`, `toggle_half` |
| Error / failure exit | `<subsystem>_fail` or `<subsystem>_error` | `post_vram_fail`, `fdc_test_fail`, `cmd_mem_error` |
| Retry after failure | `retry_<action>` | `retry_seek_read` |
| Skip / fallthrough point | `<context>_done` or `<context>_next` | `putchar_done`, `mem_modify_next`, `post_next_error` |
| Setup/init sub-step | `setup_<what>` or `<what>_common` | `setup_drive1`, `setup_drive_common` |

#### Step 3: Build a sed replacement script

Construct one `sed` invocation with `-e 's/old/new/g'` per label. Use global replacement (`/g`) so both the definition and all references are renamed atomically:

```sh
sed -i '' \
  -e 's/l0009h/delay_loop/g' \
  -e 's/l0016h/wait_lucy_sync/g' \
  -e 's/l06a9h/copy_ramtest_high/g' \
  ... \
  annotated.asm
```

**Naming guidelines:**
- Use `snake_case`, consistent with subroutine and variable names
- Prefix with the parent subroutine or subsystem name when the label is only meaningful in that context (e.g. `ram_write_byte` inside `post_ram_test`)
- Keep names short (2–4 words) — these are local targets, not public API
- Avoid generic names like `label1` or `branch_target` — every label should tell you *what happens* at that address

#### Step 4: Verify zero auto-labels remain

```sh
grep -c '^l[0-9a-f]\+h:' annotated.asm   # should print 0
grep -E 'l[0-9a-f]{4}h' annotated.asm     # should produce no output
```

#### Step 5: Round-trip verify

```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
cmp ORIGINAL.BIN /tmp/roundtrip.bin
```

## Iterative Refinement

Reverse engineering is iterative. After each pass:
1. Update the block definition file with newly identified data regions
2. Update the symbol file with newly named subroutines
3. Re-disassemble to get cleaner output
4. Cross-reference subroutines to understand calling relationships

## z80dasm File Formats

### Symbol File (.sym)

```
; comments start with semicolon
; format: label: equ 0xADDR
reset: equ 0x0000
irq_handler: equ 0x0038
main: equ 0x0100
```

**Tip:** Generate a sample with `z80dasm -g 0 -s sample.sym ROM.BIN` to confirm format.

### Block Definition File (.def)

```
; format: name: start 0xADDR last 0xADDR type TYPE
; Types: code, bytedata, worddata, pointers
reset_code: start 0x0000 last 0x0037 type code
irq_handler: start 0x0038 last 0x003c type code
padding: start 0x003d last 0x00ff type bytedata
```

## z80asm Round-Trip Verification

After annotating, always verify the assembly produces an identical binary:

```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
diff <(xxd ORIGINAL.BIN) <(xxd /tmp/roundtrip.bin)
```

### z80asm Syntax Notes

- Constants use colon syntax: `label: equ 0bee8h` (colon required, unlike some assemblers)
- Hex values use `0` prefix + `h` suffix: `0bee8h`, `0ffh` (leading zero needed if starts with A-F)
- `defb` for byte data, `defw` for word data
- `detectIndentation: false` + `tabSize: 8` in VS Code settings for proper column alignment
- The `equ` definitions must appear before first use (put them after `org` but before code)

## Tips

- Z80 is little-endian: `ld sp,0bee8h` stores as `31 e8 be`
- `rst` instructions are single-byte calls to fixed addresses (multiples of 8)
- Look for `di`/`ei` pairs around critical sections
- `halt` usually means "wait for interrupt"
- Sequences of `out` to the same port often indicate peripheral initialization
- Compare multiple ROMs from the same system — shared routines reveal the hardware abstraction layer
- When you see `cp` followed by conditional jumps, you're likely in a command dispatcher or state machine
