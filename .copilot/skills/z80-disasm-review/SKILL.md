---
name: z80-disasm-review
description: "Review an annotated Z80/8085 disassembly for quality and completeness. Use when: checking if a disassembly meets annotation standards, auditing before shipping, planning remaining annotation work, or after completing a batch of changes."
---

# Z80 Disassembly Quality Review

Evaluate an annotated disassembly against the quality checklist below, report what's missing or non-conforming, then plan and execute the fixes.

## Procedure

1. **Read the target file** in full (or large sections).
2. **Run each checklist item** — record pass/fail with specific line numbers or examples.
3. **Produce a summary table** showing status per item.
4. **Plan fixes** — group by category, estimate scope (lines affected).
5. **Execute fixes** in batches, round-trip verifying after each batch.

---

## Quality Checklist

### A. File-Level Header

| # | Criterion | What to look for |
|---|-----------|-----------------|
| A1 | Machine identification | Machine name, CPU, clock speed |
| A2 | ROM metadata | Size, address range, source binary filename |
| A3 | RAM variable region | Address range documented |
| A4 | Execution flow summary | Entry point + major phases with hex addresses |
| A5 | Hardware inventory | All peripherals listed with chip names and port ranges |
| A6 | Memory map | ROM, RAM, variables, stack, special registers |

### B. Symbol Definitions (EQUs)

| # | Criterion | What to look for |
|---|-----------|-----------------|
| B1 | All RAM variables named | No raw RAM addresses (outside ROM range) in code body |
| B2 | All I/O ports named | No raw hex in `in`/`out` instructions |
| B3 | Hardware commands named | FDC commands, UART config, PIC ICWs, etc. as EQUs |
| B4 | Status masks named | Bit masks used with `and`/`or`/`bit` after I/O reads |
| B5 | Protocol/format constants | Record types, magic numbers, thresholds |
| B6 | Display constants | Screen geometry, attributes, special characters |
| B7 | ASCII control chars named | CR, LF, ESC etc. as EQUs (printable chars use literals) |
| B8 | EQUs grouped by category | Separate sections with `; --- Category ---` headers |
| B9 | Each EQU has inline comment | Brief description of purpose |

### C. Labels

| # | Criterion | What to look for |
|---|-----------|-----------------|
| C1 | No auto-generated labels | Zero `l[0-9a-f]+h:` patterns remaining |
| C2 | All subroutines named | Descriptive `snake_case` names for all `call`/`jp` targets |
| C3 | Branch targets named | Local jumps have meaningful names (not just addresses) |
| C4 | Naming conventions followed | `wait_*` for polls, `*_loop` for iterations, `*_done`/`*_next` for exits, `*_fail` for errors |
| C5 | Orphan functions identified | Unreferenced routines marked as ORPHAN with explanation |

### D. Function Headers

| # | Criterion | What to look for |
|---|-----------|-----------------|
| D1 | Every function has a header | `; ====...` block before each subroutine |
| D2 | Address in header | `routine_name @ 0xNNNN` format |
| D3 | Purpose description | What the function does (1-3 lines) |
| D4 | Entry conditions | Input registers/memory documented |
| D5 | Return values | Output registers/flags documented |
| D6 | Short routines have 1-line header | < 10 instructions get `; name @ 0xNNNN — description` |

### E. Inline Comments

| # | Criterion | What to look for |
|---|-----------|-----------------|
| E1 | Every instruction commented | No bare instruction lines without `;` comment |
| E2 | Comments explain intent | *Why*, not just restating the opcode |
| E3 | Hardware interactions noted | What port reads/writes trigger in hardware |
| E4 | Loop invariants documented | Register contents at entry, exit conditions |
| E5 | Logical grouping with blank lines | Related instructions blocked together, blank line between blocks |
| E6 | Group intro comments | `; --- description ---` or `\t\t; Description` before multi-instruction blocks |

### F. Data Representation

| # | Criterion | What to look for |
|---|-----------|-----------------|
| F1 | Hex for bit patterns/addresses | Masks, port numbers, hardware commands stay hex |
| F2 | Decimal for counts/sizes | Loop counts, screen dimensions, byte sizes in decimal |
| F3 | Character literals for ASCII | `'M'`, `':'`, `' '` instead of hex for printable chars |
| F4 | Strings use `defm` | Printable text data uses `defm` not raw `defb` sequences |
| F5 | Data tables properly typed | `defb`/`defw`/`defm` with comments explaining structure |

### G. Structural Hygiene

| # | Criterion | What to look for |
|---|-----------|-----------------|
| G1 | No z80dasm hex dump comments | No `;ADDR\tHEX\tASCII` artifacts remaining |
| G2 | Consistent tab/alignment | Instructions at column 1 (after label), operands aligned, comments at consistent column |
| G3 | Round-trip clean | `z80asm` + `cmp` against original binary passes |
| G4 | Code/data separation correct | No instructions in data regions, no `defb` in code regions |
| G5 | Padding documented | `defs N` with comment explaining why (vector alignment, etc.) |

---

## Execution

After running the checklist:

### Reporting

```
## Review Summary: <filename>

| Category | Pass | Fail | Notes |
|----------|------|------|-------|
| A. Header | 6/6 | 0 | ✓ Complete |
| B. Symbols | 7/9 | 2 | B3: FDC commands still raw; B5: missing record types |
| ...        |      |     | |

### Items to fix:
1. [B3] Add FDC command EQUs — ~8 constants, ~15 code lines affected
2. [B5] Add record type EQUs — ~4 constants, ~6 code lines affected
3. ...
```

### Fixing

1. Group fixes by category (all symbol work together, all comments together).
2. Do the safest/most mechanical fixes first (EQU additions, label renames).
3. Round-trip verify after each batch:
   ```sh
   z80asm -o /tmp/roundtrip.bin <file>.asm
   cmp <ORIGINAL.BIN> /tmp/roundtrip.bin
   ```
4. Add comments/headers last (no binary impact, but verify formatting).

### 8085 Considerations

For 8085 ROMs disassembled with Z80 tooling:
- `SIM` (0x30) and `RIM` (0x20) must remain as `defb` with comment explaining the true instruction
- Intel mnemonic equivalents noted in comments where helpful (e.g. `; LHLD = ld hl,(addr)`)
- Verify these `defb` workarounds haven't been accidentally "fixed" back to Z80 instructions
