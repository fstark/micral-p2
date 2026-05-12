; ============================================================
; MICRAL Portal Boot ROM — Bootstrapper (Annotated)
; ============================================================
;
; Machine:   Bull/R2E Micral Portal (8085 @ 5 MHz, 1984)
; ROM:       2 KB (0x0000–0x07FF), first 23 bytes are this
;            bootstrap; remainder is main monitor code + zeros.
;
; Copies 1052 bytes from ROM offset 17h to RAM at F800h,
; then jumps there. The main code is assembled for F800h.
;
; ============================================================

	org 00000h

MAIN_CODE_SRC:  equ	00017h          ; ROM offset of main monitor code
MAIN_CODE_LEN:  equ	1052            ; Bytes to copy (main code size)
MAIN_CODE_DST:  equ	0f800h          ; RAM destination / entry point

; ============================================================
; reset @ 0x0000 — Copy main code to RAM and jump to it
; ============================================================
reset:
	di                                  ; disable interrupts during copy
	ld hl,MAIN_CODE_SRC                 ; source: ROM offset 0x17
	ld bc,MAIN_CODE_LEN                 ; byte count: 1052 bytes
	ld de,MAIN_CODE_DST                 ; destination: RAM at F800h
copy_loop:
	ld a,(hl)                           ; read byte from ROM
	ld (de),a                           ; write to RAM
	inc hl                              ; advance source
	inc de                              ; advance destination
	dec bc                              ; decrement count
	ld a,b                              ; test BC == 0
	or c                                ;   (OR high and low bytes)
	jp nz,copy_loop                     ; loop until all bytes copied
	jp MAIN_CODE_DST                    ; jump to main code in RAM
