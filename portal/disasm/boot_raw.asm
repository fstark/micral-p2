; z80dasm 1.2.0
; command line: z80dasm -a -l -t -g 0x0000 -o boot_raw.asm boot.bin

	org 00000h

	di			;0000	f3		.
	ld hl,00017h		;0001	21 17 00	! . .
	ld bc,0041ch		;0004	01 1c 04	. . .
	ld de,0f800h		;0007	11 00 f8	. . .
l000ah:
	ld a,(hl)		;000a	7e		~
	ld (de),a		;000b	12		.
	inc hl			;000c	23		#
	inc de			;000d	13		.
	dec bc			;000e	0b		.
	ld a,b			;000f	78		x
	or c			;0010	b1		.
	jp nz,l000ah		;0011	c2 0a 00	. . .
	jp 0f800h		;0014	c3 00 f8	. . .
