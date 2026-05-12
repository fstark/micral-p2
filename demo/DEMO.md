Objective:

Create a sample bin file bytes that can be written on a floppy and booted on the MICRAL P2 machine.

The following things will be needed:
* create a z80 assembly code that writes "Hello, World!" on screen and loops forever.
* compile it into a small binary
* encode this binary in the proper MOS hex format that is expected by the MICRAL P2 boot loader, creating the final file

INFO:
  The disasm/ANALYSIS.md for machine analysis
  The disasm/boot_annotated.asm for the boot ROM

Facts (verified from ROM disassembly):

* Sectors are 256 bytes (FD1797 full-sector mode)
* First sector (track 0, sector 1) is a config sector — byte at offset +2 controls RAM bank selection
* MOS hex records are read starting from the LBA specified in the B command (e.g. `B0,1` reads from LBA 1 = sector 2)
* MOS hex stream needs a data record (type 0xC2) to load the binary and an exec record (type 0xC6) to jump to it

Outputs:

* a demo.asm program source
* a build.sh script that outputs:
* a file that can be written to a floppy to boot the MICRAL P2. It doesn't have to be encapsulated into a specific floppy format. A raw 512-byte image (2×256B sectors) is sufficient.

The z80asm assembler is available.
You can also use a python venv in venv
Or the system C compiler
