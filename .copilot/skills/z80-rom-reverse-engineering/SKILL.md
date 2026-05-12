---
name: z80-rom-reverse-engineering
description: "Reverse engineer Z80 ROM code from .BIN files. Use when: disassembling Z80 binaries, analyzing boot ROMs, identifying code/data regions, mapping memory layout, identifying subroutines, or producing initial ROM analysis documentation."
argument-hint: "Path to .BIN file and optional origin address, e.g. ROMs/BOOT.BIN 0x0000"
---

# Z80 ROM Reverse Engineering

Disassemble and analyze Z80 binary ROM dumps, producing an initial analysis with identified subroutines, data regions, I/O port maps, and memory layout documentation.

**After this skill completes**, use the `z80-asm-annotation` skill to symbolify variables, name constants/labels, and add comments.

## Procedure

### Phase 1: Initial Disassembly

Disassemble the target ROM with full annotations:

```sh
z80dasm -a -l -g <ORIGIN> -t <FILE.BIN> -o <OUTPUT.asm>
```

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

Create a block definition file and re-disassemble:
```sh
z80dasm -a -l -g <ORIGIN> -t -b blocks.def <FILE.BIN> -o <OUTPUT.asm>
```

See the `z80-asm` skill for block definition file format details.

### Phase 3: Identify Interrupt Vectors

For ROMs starting at 0x0000, check the standard Z80 interrupt/restart vectors (see `z80-asm` skill for the full table). Document which vectors contain actual handlers vs padding.

### Phase 4: I/O Port Analysis

Extract all `in` and `out` instructions:

```sh
grep -E '^\s+(in|out)\s' <OUTPUT.asm> | sort -u
```

Build an I/O port map documenting:
- Port address
- Direction (read/write/both)
- Likely peripheral (see `z80-asm` skill for common Z80 peripheral chips)
- Values written and their meaning (control words, data)

### Phase 5: Subroutine Identification

Identify and name subroutines by analyzing:

1. **Call targets** — All addresses referenced by `call` instructions
2. **Entry patterns** — `push` sequences at function prologues
3. **Exit patterns** — `ret`, `ret z`, `ret nz`, etc.
4. **Functionality** — What the routine does (I/O init, string print, memory copy, etc.)

Create a symbol file (see `z80-asm` skill for format) and re-disassemble:
```sh
z80dasm -a -l -g <ORIGIN> -t -b blocks.def -S symbols.sym <FILE.BIN> -o <OUTPUT.asm>
```

### Phase 5.5: Identify Orphan Functions

After all `call` targets are named, identify functions that are **never called** from within the ROM:

```sh
# List all defined labels
grep -oE '^[a-z_]+:' annotated.asm | tr -d ':' > /tmp/labels.txt
# List all call/jp targets
grep -oE '(call|jp)\s+[a-z_]+' annotated.asm | awk '{print $2}' | sort -u > /tmp/targets.txt
# Find labels with no references
comm -23 <(sort /tmp/labels.txt) /tmp/targets.txt
```

For each orphan, determine if it's:
- **Dead code** — Utility function left over from development (linker didn't strip it)
- **External entry point** — Called by the loaded OS after boot (e.g. the monitor's `G` command could jump to ROM utilities)
- **Interrupt/vector handler** — Referenced by hardware, not by code

Document accordingly in the symbol file comments and analysis doc.

### Phase 5.6: Strip z80dasm Hex Dump Comments

The `-a -t` flags produce comments like `;0000\t31 e8 be\t1 . .` on every line. These were useful during analysis but must be removed before annotation begins (they collide with real inline comments).

```sh
# Remove hex dump comments, preserving any user comments appended after
sed -E 's/;[0-9a-f]{4}\t[0-9a-f ]{2,12}\t.{1,4}(;.*)?$/\1/' annotated.asm > clean.asm
mv clean.asm annotated.asm
```

Round-trip verify after stripping.

### Phase 6: Documentation Output

Produce a markdown analysis document containing:

1. **Summary** — ROM purpose, size, origin address, hardware target
2. **Memory Map** — Code regions, data regions, tables, strings
3. **I/O Port Map** — All ports with peripheral identification
4. **Interrupt Vectors** — Which are implemented
5. **Subroutine Table** — Address, name, purpose, calling convention
6. **Orphan Functions** — Unreferenced routines with likely explanation
7. **Boot Sequence** — Step-by-step walkthrough of initialization code

## Iterative Refinement

Reverse engineering is iterative. After each pass:
1. Update the block definition file with newly identified data regions
2. Update the symbol file with newly named subroutines
3. Re-disassemble to get cleaner output
4. Cross-reference subroutines to understand calling relationships

## Next Steps

Once the initial analysis is complete (Phases 1–6), use the `z80-asm-annotation` skill to:
- Symbolify RAM variables (replace raw addresses with named EQUs)
- Name magic values (hardware commands, masks, configuration bytes)
- Rename auto-generated branch labels to meaningful names
- Add function headers and inline comments
