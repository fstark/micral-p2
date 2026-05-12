; demo.asm — "Hello, World!" for Micral P2
; Loaded at 0x8000 by MOS hex boot, ROM banked out.
; Self-contained: uses video hardware directly.

	org	08000h

; --- I/O Ports ---
PORT_VIDEO_ROW:	equ	000h		; SAA5120 row address
PORT_VIDEO_COL:	equ	001h		; SAA5120 column / write strobe
PORT_VIDEO_DAT:	equ	002h		; SAA5120 data (char or attr)
PORT_SCROLL:	equ	003h		; Scroll register
PORT_SCROLL_ALT:	equ	004h		; Scroll register (alternate)
PORT_SYS_CTRL:	equ	020h		; System control (bank/video)
PORT_LUCY_REG:	equ	060h		; LUCY register select
PORT_LUCY_DATA:	equ	070h		; LUCY data read

; --- Constants ---
VID_STROBE:	equ	040h		; Bit 6: write strobe
SYS_BASE:	equ	040h		; Bank switch active (ROM out)
SYS_VIDEO:	equ	060h		; Bank switch + video write enable
ATTR_NORMAL:	equ	00eh		; White on black
LUCY_REG_SCAN:	equ	006h		; Scan/sync register

; =============================================================
; Entry point
; =============================================================
entry:
	; Reset scroll registers
	xor	a
	out	(PORT_SCROLL),a
	out	(PORT_SCROLL_ALT),a

	; --- Clear screen: 25 rows x 80 cols ---
	ld	d,0			; D = row
cls_row:
	ld	e,0			; E = col
cls_col:
	ld	a,e
	cp	40
	jr	c,cls_left
	sub	40
	or	080h
cls_left:
	ld	c,a			; C = encoded port col
	ld	b,' '			; B = space character
	call	write_char
	inc	e
	ld	a,e
	cp	80
	jr	nz,cls_col
	inc	d
	ld	a,d
	cp	25
	jr	nz,cls_row

	; --- Print message at row 12, col 33 ---
	ld	hl,message
	ld	d,12
	ld	e,33
print_loop:
	ld	a,(hl)
	or	a
	jr	z,halt_loop
	ld	b,a			; B = character
	push	hl
	push	de
	ld	a,e
	cp	40
	jr	c,pr_left
	sub	40
	or	080h
pr_left:
	ld	c,a			; C = encoded port col
	call	write_char
	pop	de
	pop	hl
	inc	hl
	inc	e
	jr	print_loop

halt_loop:
	halt
	jr	halt_loop

; =============================================================
; write_char — Write one character to VRAM
;   D = row, C = encoded column, B = character
;   Uses ATTR_NORMAL for attribute.
; =============================================================
write_char:
	; Set row
	ld	a,d
	out	(PORT_VIDEO_ROW),a
	; Wait for blanking (LUCY reg 6, bit 0)
	ld	a,LUCY_REG_SCAN
	out	(PORT_LUCY_REG),a
wc_wait:
	in	a,(PORT_LUCY_DATA)
	bit	0,a
	jr	z,wc_wait
	; Enable video write mode
	ld	a,SYS_VIDEO
	out	(PORT_SYS_CTRL),a
	; Column with strobe + character
	ld	a,c
	or	VID_STROBE
	out	(PORT_VIDEO_COL),a
	ld	a,b
	out	(PORT_VIDEO_DAT),a
	; Column without strobe + attribute
	ld	a,c
	out	(PORT_VIDEO_COL),a
	ld	a,ATTR_NORMAL
	out	(PORT_VIDEO_DAT),a
	; Restore system control
	ld	a,SYS_BASE
	out	(PORT_SYS_CTRL),a
	ret

; =============================================================
message:
	defb	"Hello, World!",0
