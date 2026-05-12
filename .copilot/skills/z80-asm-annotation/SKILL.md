---
name: z80-asm-annotation
description: "Annotate Z80 disassembly with meaningful symbols, constants, labels, and comments. Use when: symbolifying RAM variables, naming magic values, renaming auto-labels, adding function headers, or commenting Z80 assembly."
---

# Z80 Assembly Annotation

Transform a raw Z80 disassembly into a fully documented, human-readable assembly listing.

**Prerequisites:** The assembly file should already have named subroutines and correct code/data separation (instructions for code, `defb`/`defw` for data). If not, use the `z80-rom-reverse-engineering` skill first.

## Phase 1: Strip z80dasm Hex Dump Comments

Before adding any annotation, remove the z80dasm-generated hex dump comments. These have the format `;ADDR\tHEX_BYTES\tASCII` and will collide with real inline comments.

```sh
# Remove hex dump comments, preserving any user comments appended after them
sed -E 's/;[0-9a-f]{4}\t[0-9a-f ]{2,12}\t.{1,4}(;.*)?$/\1/' annotated.asm > clean.asm
```

**Do this BEFORE any other annotation phase.** The hex dump comments served their purpose during initial analysis but become noise once you start adding real comments.

```sh
mv clean.asm annotated.asm
```

Round-trip verify:
```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
cmp ORIGINAL.BIN /tmp/roundtrip.bin
```

## Phase 2: RAM Variable Symbolification

Scan for raw memory addresses used as variables and replace them with named EQU definitions.

### Step 1: Find all direct address references

```sh
grep -oE '0[0-9a-f]{3,4}h' annotated.asm | sort | uniq -c | sort -rn
```

Focus on addresses in the RAM region (not ROM code addresses). These are typically used with `ld (addr),a`, `ld a,(addr)`, `ld hl,addr` followed by `(hl)` operations, and `ld (addr),hl`.

### Step 2: Infer purpose from usage context

For each RAM address, grep its occurrences and study the surrounding code to determine:
- What values are written to it (constants, computed values, I/O reads)
- What reads from it and how the value is used
- Whether it's a byte, word, or pointer
- Its role in the system (video state, keyboard buffer, FDC parameters, etc.)

### Step 3: Add EQU definitions

Insert a block of `equ` definitions after the `org` directive but before the first code label. Include a short comment documenting each variable's purpose:

```z80
; --- RAM variables ---
cursor_row:	equ	0bff7h		; Display cursor row position (0..24)
cursor_col:	equ	0bff8h		; Display cursor column position
kbd_state:	equ	0bffch		; Keyboard debounce state flag
```

### Step 4: Replace raw addresses in code

Use sed to bulk-replace all occurrences of each raw address with its symbolic name:

```sh
sed -i '' \
  -e 's/0bff7h/cursor_row/g' \
  -e 's/0bff8h/cursor_col/g' \
  -e 's/0bffch/kbd_state/g' \
  annotated.asm
```

**Order matters:** Replace longer/more-specific addresses first to avoid partial matches (e.g. replace `0beebh` before `0bee9h`).

### Step 5: Round-trip verify

```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
cmp ORIGINAL.BIN /tmp/roundtrip.bin
```

## Phase 3: Named Constants for Magic Values

Replace raw hex literals used as hardware commands, bit masks, configuration values, and ASCII characters with named EQU constants.

### Step 1: Inventory magic values

```sh
grep -nE '\b0[0-9a-f]{2,3}h\b' annotated.asm | grep -vE '(equ|defb|defw|defm)' | sort
```

### Step 2: Categorize by peripheral / subsystem

Group into logical categories:

- **I/O Ports** — Port addresses in `in`/`out` instructions (e.g. `PORT_FDC_CMD equ 010h`)
- **Hardware commands** — Command bytes written to peripherals (e.g. `FDC_CMD_RESTORE equ 00fh`)
- **Status masks** — Bit masks used with `and`/`or`/`bit` after reading status (e.g. `FDC_STAT_BUSY equ 01h`)
- **Configuration values** — Init bytes for UARTs, timers, video (e.g. `UART_MODE1 equ 04eh`)
- **Protocol constants** — Record types, magic numbers in data formats (e.g. `REC_DATA equ 0c2h`)
- **Display constants** — Screen geometry, attribute values (e.g. `SCREEN_ROWS equ 019h`)
- **ASCII characters** — Use character literals for printable chars (`'M'`, `':'`, `' '`) and named EQUs for control characters (`CR equ 00dh`, `ESC equ 01bh`)

### Step 3: Add EQU definitions grouped by category

Insert after the RAM variable EQUs, before the first code label:

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

### Step 4: Replace in instruction operands

Replace each raw value with its constant name. Target `ld`, `cp`, `and`, `or`, `xor`, `add`, `sub`, `in`, `out` operands — but NOT `defb`/`defw` data.

For ASCII printable characters, use z80asm character literals:
```z80
	cp 'M'		; instead of cp 04dh
	ld c,':'	; instead of ld c,03ah
```

**Do NOT replace:**
- `defb`/`defw` in string data or lookup tables
- Values that happen to match but have different meaning in context (e.g. `ld bc,0000dh` where 13 is a byte count, not a CR character)
- Addresses used as code targets or memory addresses

### Step 5: Round-trip verify

```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
cmp ORIGINAL.BIN /tmp/roundtrip.bin
```

## Phase 4: Meaningful Label Names for Branch Targets

The remaining auto-generated labels (e.g. `l0009h`, `l06a9h`) are local branch targets. Renaming them eliminates the need to mentally trace every jump.

### Step 1: Inventory auto-labels

```sh
grep -c '^l[0-9a-f]\+h:' annotated.asm
```

### Step 2: Categorize by surrounding context

| Pattern | Convention | Examples |
|---------|-----------|----------|
| Busy-wait / polling loop | `wait_<what>` | `wait_fdc_idle`, `wait_seek_done` |
| Countdown / iteration loop | `<thing>_loop` | `delay_loop`, `div_loop` |
| Inner loop body | `<outer>_<action>` | `ram_write_byte`, `dump_byte` |
| Conditional branch | `<what_happens>` | `check_bank2`, `set_single_density` |
| Error / failure exit | `<subsystem>_fail` | `post_vram_fail`, `fdc_test_fail` |
| Retry after failure | `retry_<action>` | `retry_seek_read` |
| Skip / fallthrough | `<context>_done` or `_next` | `putchar_done`, `mem_modify_next` |
| Setup sub-step | `setup_<what>` | `setup_drive1`, `setup_drive_common` |

### Step 3: Build a sed replacement script

```sh
sed -i '' \
  -e 's/l0009h/delay_loop/g' \
  -e 's/l0016h/wait_lucy_sync/g' \
  -e 's/l06a9h/copy_ramtest_high/g' \
  ... \
  annotated.asm
```

**Naming guidelines:**
- `snake_case`, consistent with subroutine and variable names
- Prefix with parent subroutine name when only meaningful in that context
- Keep names short (2–4 words)
- Every label should tell you *what happens* at that address

### Step 4: Verify zero auto-labels remain

```sh
grep -c '^l[0-9a-f]\+h:' annotated.asm   # should print 0
grep -E 'l[0-9a-f]{4}h' annotated.asm     # should produce no output
```

### Step 5: Round-trip verify

```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
cmp ORIGINAL.BIN /tmp/roundtrip.bin
```

## Phase 5: Inline Comments and Function Headers

The assembly is now structurally clean but needs narrative comments explaining *why* the code does what it does.

### Step 0: Add a file-level header

Every annotated disassembly must open with a block comment containing:
- Machine name, CPU, and clock speed
- ROM size and address range
- RAM variable region
- High-level execution flow (entry point → major phases, with hex addresses)
- Hardware peripheral inventory (chip names, port ranges)
- ASCII memory map showing ROM, RAM, variables, and special registers

This goes before the `org` directive so readers get full context before hitting any code.

### Step 1: Identify function boundaries

```sh
grep -nE '^[a-z_]+:' annotated.asm | head -60
```

Group by subsystem (video, keyboard, FDC, POST, monitor, etc.).

### Step 2: Add function header comments

Every function header must include the absolute ROM address using `@ 0xNNNN` after the routine name. This makes the disassembly self-contained for cross-referencing with hex dumps, logic analyzer traces, or hardware documentation.

```z80
; ============================================================
; putchar @ 0x04CD — Write one character to the display
; Input:  C = character to print
; Output: cursor position updated
; Clobbers: A, B, HL
; Called by monitor, boot loader, POST display routines
; ============================================================
putchar:
```

For short utility functions (< 10 instructions), a 1–2 line comment suffices but still includes the address:
```z80
; print_crlf @ 0x044D — Output CR+LF to display
print_crlf:
```

### Step 3: Add inline comments explaining logic flow

**Every assembly instruction must have an inline comment.** No instruction line should be left without a `;` comment — even self-documenting ones like `ld sp,stack_top` get a brief comment (e.g. `; init stack at top of RAM`). Consistency matters more than saving keystrokes. The goal is that a reader can understand the entire ROM by reading comments alone, without needing to mentally execute Z80 opcodes.

Focus on:
- **What each block accomplishes** (not what each opcode does)
- **Why** a particular approach is used
- **Hardware interactions** — what a port read/write triggers
- **Loop invariants** — register contents at loop entry, exit conditions
- **State machines** — functions with complex buffering or multi-level state need paragraph-level narrative (e.g. `get_next_byte` with its sector buffering + byte counter + lazy refill)

**Good:**
```z80
; Wait for FDC to finish (bit 0 = busy)
wait_fdc_idle:
	in a,(PORT_FDC_STATUS)
	rrca			; shift busy bit into carry
	jr c,wait_fdc_idle
```

**Bad** (just restating the opcode):
```z80
	ld a,020h		; load 0x20 into A     ← useless
```

### Step 4: Work in batches by subsystem

Process 8–15 functions per batch:

1. Reset vectors, IRQ/NMI handlers, system init
2. Boot loader, record parser
3. Disk I/O (FDC driver routines)
4. Monitor command dispatcher and commands
5. Hex I/O utilities, keyboard driver
6. Character I/O, video driver
7. POST / self-test routines
8. Data tables and strings

After each batch, round-trip verify:
```sh
z80asm -o /tmp/roundtrip.bin annotated.asm
cmp ORIGINAL.BIN /tmp/roundtrip.bin
```

### Step 5: Format and align

After all comments are added, run `format_asm.py` to align columns:
```sh
python3 .copilot/skills/z80-asm-annotation/format_asm.py annotated.asm formatted.asm
mv formatted.asm annotated.asm
```

Round-trip verify one final time.
