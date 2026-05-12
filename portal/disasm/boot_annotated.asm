; ============================================================
; MICRAL Portal Boot ROM — Bootstrapper (Annotated)
; ============================================================
;
; Machine:   Bull/R2E Micral Portal (8085 @ 5 MHz, 1984)
; ROM:       2 KB (0x0000–0x07FF in physical EPROM)
; Source:    z80dasm from portal.bin (first 23 bytes)
;
; This 23-byte bootstrap runs at address 0000h on reset.
; It copies the main monitor code (1052 bytes starting at
; offset 0x17 in the ROM) to RAM at F800h, then jumps there.
; The remaining 974 bytes of the 2 KB ROM are trailing zeros
; and are intentionally not copied.
;
; The ROM chip is mapped at 0000h at power-on, but the main
; code is assembled for F800h — hence the relocation copy.
;
; ============================================================

	org 00000h

; ============================================================
; reset @ 0x0000 — Copy main code to RAM and jump to it
; ============================================================
reset:
	di			; disable interrupts during copy
	ld hl,00017h		; source: ROM offset 0x17 (main code start)
	ld bc,0041ch		; byte count: 1052 bytes (main code size)
	ld de,0f800h		; destination: RAM at F800h
copy_loop:
	ld a,(hl)		; read byte from ROM
	ld (de),a		; write to RAM
	inc hl			; advance source
	inc de			; advance destination
	dec bc			; decrement count
	ld a,b			; test BC == 0
	or c			;   (OR high and low bytes)
	jp nz,copy_loop		; loop until all bytes copied
	jp 0f800h		; jump to main code in RAM
