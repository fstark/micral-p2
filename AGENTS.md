This repository contains boot ROM disassemblies for vintage computers.

## Tools

- **z80dasm**: Z80 disassembler. Used for both machines (8080 subset is shared).
  - Supports block definitions (`-b blocks.def`) and label generation (`-l`).
- **z80asm**: Z80 assembler. Used to reassemble and verify round-trip correctness.

## Machines

### Micral P2
- Directory: `micral-p2/`
- CPU: Z80A @ 4 MHz
- Boot ROM: `micral-p2/ROMs/MICRAL_P2_CHARGEUR.BIN`
- Annotated disassembly: `micral-p2/disasm/boot_annotated.asm`
- Demo program: `micral-p2/demo/`

### Micral Portal
- Directory: `portal/`
- CPU: 8085 (Intel mnemonics, but disassembly uses Z80/Zilog syntax for tooling compatibility)
- Boot ROM: `portal/ROMs/portal.bin`
- Raw disassembly: `portal/disasm/boot_raw.asm` + `portal/disasm/main_raw.asm`
- Annotated disassembly: `portal/disasm/boot_annotated.asm` + `portal/disasm/main_annotated.asm`
- Verify script: `portal/disasm/verify.sh` (reassembles and checks against original ROM)

#### Portal ROM layout
The ROM (2048 bytes) self-relocates:
- Bytes 0x00–0x16: bootstrapper (runs at address 0000h, copies main code to RAM)
- Bytes 0x17–0x0432: main code (runs at address F800h after copy)

The disassembly is split into two files for this reason:
- `boot_raw.asm` — org 0000h, 23-byte copy loop
- `main_raw.asm` — org F800h, the actual monitor/loader

Concatenating the two assembled binaries reproduces the original ROM exactly.

#### 8085 vs Z80 tooling note
The 8085 has two opcodes not present on Z80: `SIM` (0x30) and `RIM` (0x20).
On Z80, these bytes are `JR NC` and `JR NZ` (2-byte relative jumps), which causes
z80dasm to desync. The workaround is to mark those bytes as `bytedata` in `blocks.def`:

```
sim_opcode: start 0xF802 last 0xF802 type bytedata
```

In the annotated disassembly, comment them as:
```asm
    defb 030h           ; SIM — set interrupt mask (8085-only)
```

This preserves reassemblability with z80asm while documenting the true instruction.

### Olympia Boss
- Directory: `olympia-boss/`
- CPU: Z80A
- System ROM: `olympia-boss/ROMs/olympia_boss_system_251-462.bin` (2K, boot monitor)
- Graphics ROM: `olympia-boss/ROMs/olympia_boss_graphics_251-461.bin` (2K, character generator)
- Raw disassembly: `olympia-boss/disasm/boot_raw.asm`
- Annotated disassembly: `olympia-boss/disasm/boot_annotated.asm`
- Block definitions: `olympia-boss/disasm/blocks.def`
- Verify script: `olympia-boss/disasm/verify.sh`

#### Olympia Boss ROM layout
The system ROM (2048 bytes) runs in-place at org 0000h:
- 0x0000–0x0696: Code (reset vector, monitor, drivers)
- 0x0697–0x06FF: Data tables (strings, drive params, SIO init, FDC commands)
- 0x0700–0x07EF: Unused (zero-filled)
- 0x07F0–0x07FF: IM 2 interrupt vector table (I register = 07h)

The ROM banks itself out via port 60h before jumping to loaded programs.
The graphics ROM is a pure character generator (font bitmaps), not executable.

