; z80dasm 1.2.0
; command line: z80dasm -a -l -g 0x0000 -t -b disasm/blocks.def -S disasm/symbols.sym -o disasm/boot_annotated.asm ROMs/MICRAL_P2_CHARGEUR.BIN

	org 00000h

; --- RAM variables (0xBEE8..0xBFFD) ---
stack_top:	equ	0bee8h		; Top of stack; also stores boot drive number
sector_buf:	equ	0bee9h		; 256-byte FDC sector read buffer
boot_cfg:	equ	0beebh		; Boot config byte (sector_buf+2): bit7=bank1, bit6=bank2
buf_rd_ptr:	equ	0bfe9h		; Current read pointer into sector buffer
buf_remain:	equ	0bfebh		; Bytes remaining in current sector (word)
disk_lba:	equ	0bfedh		; Logical sector counter for sequential reads (word)
fdc_sector:	equ	0bfefh		; Physical sector number, 1-based (for FD1797)
fdc_track:	equ	0bff0h		; Current track number
disk_geom:	equ	0bff1h		; Disk geometry: sectors/track, heads (word)
sys_flags:	equ	0bff3h		; System flags / port 0x20 shadow (bank select, video sync)
fdc_side:	equ	0bff4h		; FDC side select: 0x00=side 0, 0x02=side 1
floppy_prm_ptr:	equ	0bff5h		; Pointer to floppy parameters table (word)
cursor_row:	equ	0bff7h		; Display cursor row position (0..24)
cursor_col:	equ	0bff8h		; Display cursor column position (bit7=half-select)
vram_char:	equ	0bff9h		; Character code for VRAM write (SAA5120)
vram_attr:	equ	0bffah		; Character attribute for VRAM write (SAA5120)
scroll_off:	equ	0bffbh		; Scroll offset: first visible row (wraps at 25)
kbd_state:	equ	0bffch		; Keyboard debounce state (0=first press, 1=repeat)
kbd_last:	equ	0bffdh		; Last key code read from KR3600
bank_latch:	equ	0ffffh		; Bank switch latch register

; --- I/O Ports ---
PORT_VIDEO_ROW:	equ	000h		; SAA5120 row address
PORT_VIDEO_CHAR:	equ	001h		; SAA5120 character data (bit 6 = write strobe)
PORT_VIDEO_ATTR:	equ	002h		; SAA5120 attribute data
PORT_SCROLL:	equ	003h		; SAA5120 scroll register
PORT_SCROLL_ALT:	equ	004h		; SAA5120 scroll register (alternate)
PORT_TIMER:	equ	007h		; CTC timer reload
PORT_FDC_CMD:	equ	010h		; FD1797 command (W) / status (R)
PORT_FDC_TRACK:	equ	011h		; FD1797 track register
PORT_FDC_SECTOR:	equ	012h		; FD1797 sector register
PORT_FDC_DATA:	equ	013h		; FD1797 data register
PORT_SYS_CTRL:	equ	020h		; System control (LED/drive/bank)
PORT_KBD_DATA:	equ	030h		; KR3600 keyboard data (7-bit)
PORT_UART_DATA:	equ	050h		; 2661 UART data
PORT_UART_STATUS:	equ	051h		; 2661 UART status
PORT_UART_MODE:	equ	052h		; 2661 UART mode
PORT_UART_CMD:	equ	053h		; 2661 UART command
PORT_LUCY_REG:	equ	060h		; SAA5070 LUCY register select
PORT_LUCY_DATA:	equ	070h		; SAA5070 LUCY register data

; --- FD1797 Commands ---
FDC_CMD_RESTORE:	equ	00fh		; Restore to track 0, verify, 6ms step
FDC_CMD_SEEK:	equ	01fh		; Seek to track, verify, 6ms step
FDC_CMD_STEP_IN:	equ	05fh		; Step in, update track reg, 6ms step
FDC_CMD_READ_SEC:	equ	088h		; Read sector (side bit OR'd separately)
FDC_CMD_READ_ADDR:	equ	0c4h		; Read address mark
FDC_CMD_FORCE_INT:	equ	0d0h		; Force interrupt (terminate command)

; --- FD1797 Status Masks ---
FDC_STAT_ERR_SEEK:	equ	018h		; Bits 3-4: CRC error + seek error
FDC_STAT_ERR_READ:	equ	03ch		; Bits 2-5: read error flags

; --- System Control Register ---
SYS_KBD_ENABLE:	equ	022h		; Keyboard + drive enable
SYS_ACTIVE:	equ	020h		; System active / base drive select
SYS_BANK_SWITCH:	equ	040h		; Bank switch (ROM out, RAM in)
SYS_RAM_TEST:	equ	060h		; RAM bank for POST testing

; --- SAA5070 LUCY Register IDs ---
LUCY_REG_SYNC:	equ	003h		; Sync/configuration register
LUCY_REG_SCAN:	equ	006h		; Scan control / video sync register
LUCY_REG_KBD:	equ	007h		; Keyboard status register
LUCY_SYNC_BIT:	equ	020h		; Bit 5: sync status flag
LUCY_SCAN_ALL:	equ	0ffh		; Enable all keyboard scan rows

; --- SAA5120 Video Constants ---
VID_WRITE_STROBE:	equ	040h		; Bit 6: character write strobe
ATTR_NORMAL:	equ	00eh		; Normal text attribute (white on black)
ATTR_CURSOR_XOR:	equ	0c0h		; XOR mask for cursor inversion
COL_HALF:	equ	080h		; Column half-select (right half)
COL_HALF_COUNT:	equ	028h		; Columns per half (40)
COL_LAST:	equ	0a7h		; Last valid column position
COL_WRAP:	equ	0a8h		; Column wrap sentinel
SCREEN_ROWS:	equ	019h		; 25 display rows
LAST_ROW:	equ	018h		; Row 24 (0-based last row)
SCREEN_COLS:	equ	050h		; 80 display columns

; --- 2661 UART Configuration ---
UART_MODE1_VAL:	equ	04eh		; Mode register 1: 8N1
UART_MODE2_VAL:	equ	03eh		; Mode register 2: 16x clock
UART_CMD_VAL:	equ	0a7h		; Command: TX/RX enable, RTS, DTR, loopback

; --- MOS Hex Record Types ---
REC_TYPE_MIN:	equ	0c1h		; Minimum valid record type
REC_DATA:	equ	0c2h		; Data record: load bytes to memory
REC_EXEC:	equ	0c6h		; Execute: jump to loaded code
REC_ERROR:	equ	0d2h		; Error/abort record
REC_TYPE_MAX:	equ	0dbh		; Above maximum valid type

; --- Miscellaneous ---
TEST_PATTERN:	equ	055h		; POST test pattern increment
KBD_DATA_MASK:	equ	07fh		; 7-bit keyboard data mask
DD_TRACK_THRESH:	equ	016h		; Track >= 22: double-density select

; --- ASCII Control Characters ---
CR:		equ	00dh		; Carriage return
LF:		equ	00ah		; Line feed
ESC:		equ	01bh		; Escape
BEL:		equ	006h		; Bell / error beep

reset:

; BLOCK 'reset_init' (start 0x0000 end 0x0033)
reset_init_start:
	ld sp,stack_top		;0000	31 e8 be	1 . .
	ld a,SYS_KBD_ENABLE		;0003	3e 22		> "
	out (PORT_SYS_CTRL),a		;0005	d3 20		.  
	ld b,030h		;0007	06 30		. 0
l0009h:
	djnz l0009h		;0009	10 fe		. .
	xor a			;000b	af		.
	out (PORT_SYS_CTRL),a		;000c	d3 20		.  
	ld a,LUCY_REG_SYNC		;000e	3e 03		> .
	out (PORT_LUCY_REG),a		;0010	d3 60		. `
	ld a,LUCY_SYNC_BIT		;0012	3e 20		>  
	out (PORT_LUCY_DATA),a		;0014	d3 70		. p
l0016h:
	ld a,LUCY_REG_SYNC		;0016	3e 03		> .
	out (PORT_LUCY_REG),a		;0018	d3 60		. `
	in a,(PORT_LUCY_DATA)		;001a	db 70		. p
	and LUCY_SYNC_BIT		;001c	e6 20		.  
	jr nz,l0016h		;001e	20 f6		  .
	ld a,LUCY_REG_SCAN		;0020	3e 06		> .
	out (PORT_LUCY_REG),a		;0022	d3 60		. `
	ld a,LUCY_SCAN_ALL		;0024	3e ff		> .
	out (PORT_LUCY_DATA),a		;0026	d3 70		. p
	ld a,LUCY_REG_KBD		;0028	3e 07		> .
	out (PORT_LUCY_REG),a		;002a	d3 60		. `
	ld a,LUCY_SCAN_ALL		;002c	3e ff		> .
	out (PORT_LUCY_DATA),a		;002e	d3 70		. p
	jp post_start		;0030	c3 fa 05	. . .

; BLOCK 'pad_rst30' (start 0x0033 end 0x0038)
pad_rst30_start:
	defb 000h		;0033	00		.
	defb 000h		;0034	00		.
	defb 000h		;0035	00		.
	defb 000h		;0036	00		.
pad_rst30_last:
	defb 000h		;0037	00		.
irq_im1:

; BLOCK 'irq_handler' (start 0x0038 end 0x003d)
irq_handler_start:
	inc d			;0038	14		.
	out (PORT_TIMER),a		;0039	d3 07		. .
	ei			;003b	fb		.
irq_handler_last:
	ret			;003c	c9		.

; BLOCK 'pad_vectors' (start 0x003d end 0x0066)
pad_vectors_start:
	defb 000h		;003d	00		.
	defb 000h		;003e	00		.
	defb 000h		;003f	00		.
	defb 000h		;0040	00		.
	defb 000h		;0041	00		.
	defb 000h		;0042	00		.
	defb 000h		;0043	00		.
	defb 000h		;0044	00		.
	defb 000h		;0045	00		.
	defb 000h		;0046	00		.
	defb 000h		;0047	00		.
	defb 000h		;0048	00		.
	defb 000h		;0049	00		.
	defb 000h		;004a	00		.
	defb 000h		;004b	00		.
	defb 000h		;004c	00		.
	defb 000h		;004d	00		.
	defb 000h		;004e	00		.
	defb 000h		;004f	00		.
	defb 000h		;0050	00		.
	defb 000h		;0051	00		.
	defb 000h		;0052	00		.
	defb 000h		;0053	00		.
	defb 000h		;0054	00		.
	defb 000h		;0055	00		.
	defb 000h		;0056	00		.
	defb 000h		;0057	00		.
	defb 000h		;0058	00		.
	defb 000h		;0059	00		.
	defb 000h		;005a	00		.
	defb 000h		;005b	00		.
	defb 000h		;005c	00		.
	defb 000h		;005d	00		.
	defb 000h		;005e	00		.
	defb 000h		;005f	00		.
	defb 000h		;0060	00		.
	defb 000h		;0061	00		.
	defb 000h		;0062	00		.
	defb 000h		;0063	00		.
	defb 000h		;0064	00		.
pad_vectors_last:
	defb 000h		;0065	00		.
nmi_handler:

; BLOCK 'nmi_handler' (start 0x0066 end 0x006e)
nmi_handler_start:
	ex af,af'		;0066	08		.
	in a,(PORT_FDC_DATA)		;0067	db 13		. .
	ld (hl),a		;0069	77		w
	inc hl			;006a	23		#
	ex af,af'		;006b	08		.
	retn			;006c	ed 45		. E
init_display:

; BLOCK 'init_display' (start 0x006e end 0x0093)
init_display_start:
	ld a,SCREEN_ROWS		;006e	3e 19		> .
	ld (cursor_row),a		;0070	32 f7 bf	2 . .
	xor a			;0073	af		.
	ld (sys_flags),a		;0074	32 f3 bf	2 . .
	ld (cursor_col),a		;0077	32 f8 bf	2 . .
	ld a,001h		;007a	3e 01		> .
	ld (vram_attr),a		;007c	32 fa bf	2 . .
	ld a,'.'		;007f	3e 2e		> .
	ld (vram_char),a		;0081	32 f9 bf	2 . .
	call write_vram		;0084	cd a5 05	. . .
	ld a,COL_HALF		;0087	3e 80		> .
	ld (cursor_col),a		;0089	32 f8 bf	2 . .
	call write_vram		;008c	cd a5 05	. . .
	call clear_screen	;008f	cd 5d 05	. ] .
init_display_last:
	ret			;0092	c9		.
monitor_prompt:

; BLOCK 'monitor' (start 0x0093 end 0x00f6)
monitor_start:
	ld sp,stack_top		;0093	31 e8 be	1 . .
	xor a			;0096	af		.
	ld (sys_flags),a		;0097	32 f3 bf	2 . .
	ld hl,str_prompt	;009a	21 8a 07	! . .
l009dh:
	ld c,(hl)		;009d	4e		N
	call putchar		;009e	cd cd 04	. . .
	inc hl			;00a1	23		#
	ld a,(hl)		;00a2	7e		~
	or a			;00a3	b7		.
	jr nz,l009dh		;00a4	20 f7		  .
	ld b,000h		;00a6	06 00		. .
	call get_char_echo	;00a8	cd c9 04	. . .
	ld a,c			;00ab	79		y
	cp CR			;00ac	fe 0d		. .
	jp z,cmd_cr_boot	;00ae	ca 26 03	. & .
	ex af,af'		;00b1	08		.
	ld c,':'		;00b2	0e 3a		. :
	call putchar		;00b4	cd cd 04	. . .
	ex af,af'		;00b7	08		.
	cp '*'			;00b8	fe 2a		. *
	jp z,cmd_star		;00ba	ca 18 03	. . .
	cp 'M'			;00bd	fe 4d		. M
	jp z,cmd_memory		;00bf	ca 4f 03	. O .
	cp 'B'			;00c2	fe 42		. B
	jr z,cmd_boot_parse	;00c4	28 0c		( .
	cp 'G'			;00c6	fe 47		. G
	jp z,cmd_go		;00c8	ca 3e 03	. > .
cmd_error:
	ld c,BEL		;00cb	0e 06		. .
	call putchar		;00cd	cd cd 04	. . .
	jr monitor_prompt	;00d0	18 c1		. .
cmd_boot_parse:
	ex af,af'		;00d2	08		.
	call parse_hex		;00d3	cd f1 02	. . .
	dec b			;00d6	05		.
	jp m,l0330h		;00d7	fa 30 03	. 0 .
	ld a,c			;00da	79		y
	cp ','			;00db	fe 2c		. ,
	jr nz,cmd_error		;00dd	20 ec		  .
	ld a,d			;00df	7a		z
	or a			;00e0	b7		.
	jr nz,cmd_error		;00e1	20 e8		  .
	or e			;00e3	b3		.
	cp 002h			;00e4	fe 02		. .
	jr nc,cmd_error		;00e6	30 e3		0 .
	push af			;00e8	f5		.
	call parse_hex		;00e9	cd f1 02	. . .
	dec b			;00ec	05		.
	ld a,c			;00ed	79		y
	pop bc			;00ee	c1		.
	jp m,cmd_error		;00ef	fa cb 00	. . .
	cp CR			;00f2	fe 0d		. .
	jr nz,cmd_error		;00f4	20 d5		  .
boot_floppy:

; BLOCK 'boot_loader' (start 0x00f6 end 0x01bd)
boot_loader_start:
	di			;00f6	f3		.
	ld (disk_lba),de		;00f7	ed 53 ed bf	. S . .
	ex af,af'		;00fb	08		.
	ld (stack_top),a		;00fc	32 e8 be	2 . .
setup_fdc_flags:
	ld hl,sys_flags		;00ff	21 f3 bf	! . .
	dec b			;0102	05		.
	jr z,l0109h		;0103	28 04		( .
	set 2,(hl)		;0105	cb d6		. .
	jr l010bh		;0107	18 02		. .
l0109h:
	set 3,(hl)		;0109	cb de		. .
l010bh:
	set 4,(hl)		;010b	cb e6		. .
	ld a,(hl)		;010d	7e		~
	out (PORT_SYS_CTRL),a		;010e	d3 20		.  
	ld hl,floppy_params	;0110	21 a8 07	! . .
	ld (floppy_prm_ptr),hl		;0113	22 f5 bf	" . .
wait_drive_ready:
	in a,(PORT_FDC_CMD)		;0116	db 10		. .
	bit 7,a			;0118	cb 7f		. .
	jr nz,wait_drive_ready	;011a	20 fa		  .
	ld de,0c000h		;011c	11 00 c0	. . .
l011fh:
	ex (sp),hl		;011f	e3		.
	ex (sp),hl		;0120	e3		.
	dec de			;0121	1b		.
	ld a,e			;0122	7b		{
	or d			;0123	b2		.
	jr nz,l011fh		;0124	20 f9		  .
read_boot_sector:
	call fdc_restore	;0126	cd 51 02	. Q .
	ld hl,(floppy_prm_ptr)		;0129	2a f5 bf	* . .
	ld a,(hl)		;012c	7e		~
	rlca			;012d	07		.
	inc hl			;012e	23		#
	ld l,(hl)		;012f	6e		n
	ld h,a			;0130	67		g
	ld (disk_geom),hl		;0131	22 f1 bf	" . .
	ld a,000h		;0134	3e 00		> .
	ld (fdc_side),a		;0136	32 f4 bf	2 . .
	inc a			;0139	3c		<
	ld (fdc_sector),a		;013a	32 ef bf	2 . .
	call fdc_read_sector	;013d	cd d2 02	. . .
	dec a			;0140	3d		=
	jr nz,read_boot_sector	;0141	20 e3		  .
	ld a,(boot_cfg)		;0143	3a eb be	: . .
	ld hl,0fffdh		;0146	21 fd ff	! . .
	ld (hl),000h		;0149	36 00		6 .
	bit 7,a			;014b	cb 7f		. .
	jr z,l0151h		;014d	28 02		( .
	set 1,(hl)		;014f	cb ce		. .
l0151h:
	bit 6,a			;0151	cb 77		. w
	jr z,l0157h		;0153	28 02		( .
	set 2,(hl)		;0155	cb d6		. .
l0157h:
	ld hl,reset		;0157	21 00 00	! . .
	ld (buf_remain),hl		;015a	22 eb bf	" . .
parse_record:
	call get_next_byte	;015d	cd bd 01	. . .
	and a			;0160	a7		.
	jp z,cmd_error		;0161	ca cb 00	. . .
	ld c,a			;0164	4f		O
	call get_next_byte	;0165	cd bd 01	. . .
	ld b,a			;0168	47		G
	ld a,c			;0169	79		y
	cp 003h			;016a	fe 03		. .
	jr c,dispatch_record	;016c	38 0b		8 .
	call get_next_byte	;016e	cd bd 01	. . .
	ld h,a			;0171	67		g
	call get_next_byte	;0172	cd bd 01	. . .
	ld l,a			;0175	6f		o
	call get_next_byte	;0176	cd bd 01	. . .
dispatch_record:
	ld a,b			;0179	78		x
	cp REC_DATA			;017a	fe c2		. .
	jr z,load_data_record	;017c	28 18		( .
	cp REC_ERROR			;017e	fe d2		. .
	jp z,cmd_error		;0180	ca cb 00	. . .
	cp REC_EXEC			;0183	fe c6		. .
	jr z,exec_loaded_code	;0185	28 16		( .
	cp REC_TYPE_MIN		;0187	fe c1		. .
	jp c,cmd_error		;0189	da cb 00	. . .
	cp REC_TYPE_MAX		;018c	fe db		. .
	jp nc,cmd_error		;018e	d2 cb 00	. . .
l0191h:
	call get_next_byte	;0191	cd bd 01	. . .
	jr l0191h		;0194	18 fb		. .
load_data_record:
	call get_next_byte	;0196	cd bd 01	. . .
	ld (hl),a		;0199	77		w
	inc hl			;019a	23		#
	jr load_data_record	;019b	18 f9		. .
exec_loaded_code:
	di			;019d	f3		.
	push hl			;019e	e5		.
	push de			;019f	d5		.
	ld hl,trampoline	;01a0	21 b0 01	! . .
	ld de,sector_buf		;01a3	11 e9 be	. . .
	ld bc,0000dh		;01a6	01 0d 00	. . .
	ldir			;01a9	ed b0		. .
	pop de			;01ab	d1		.
	pop hl			;01ac	e1		.
	jp sector_buf		;01ad	c3 e9 be	. . .
trampoline:
	ld a,(sys_flags)		;01b0	3a f3 bf	: . .
	or SYS_BANK_SWITCH		;01b3	f6 40		. @
	ld (bank_latch),a		;01b5	32 ff ff	2 . .
	ld a,SYS_BANK_SWITCH		;01b8	3e 40		> @
	out (PORT_SYS_CTRL),a		;01ba	d3 20		.  
boot_loader_last:
	jp (hl)			;01bc	e9		.
get_next_byte:

; BLOCK 'fdc_io' (start 0x01bd end 0x02f1)
fdc_io_start:
	inc c			;01bd	0c		.
	dec c			;01be	0d		.
	jr nz,l01c5h		;01bf	20 04		  .
	pop af			;01c1	f1		.
	inc c			;01c2	0c		.
	jr parse_record		;01c3	18 98		. .
l01c5h:
	push hl			;01c5	e5		.
	ld hl,(buf_remain)		;01c6	2a eb bf	* . .
	ld a,h			;01c9	7c		|
	or l			;01ca	b5		.
	jr nz,l01ebh		;01cb	20 1e		  .
	push hl			;01cd	e5		.
	push de			;01ce	d5		.
	push bc			;01cf	c5		.
	ld hl,(disk_geom)		;01d0	2a f1 bf	* . .
	ex de,hl		;01d3	eb		.
	ld hl,(disk_lba)		;01d4	2a ed bf	* . .
	call read_next_sector	;01d7	cd fa 01	. . .
	ld (disk_lba),hl		;01da	22 ed bf	" . .
	pop bc			;01dd	c1		.
	pop de			;01de	d1		.
	pop hl			;01df	e1		.
	ld hl,setup_fdc_flags	;01e0	21 ff 00	! . .
	ld (buf_remain),hl		;01e3	22 eb bf	" . .
	ld hl,sector_buf		;01e6	21 e9 be	! . .
	jr l01f2h		;01e9	18 07		. .
l01ebh:
	dec hl			;01eb	2b		+
	ld (buf_remain),hl		;01ec	22 eb bf	" . .
	ld hl,(buf_rd_ptr)		;01ef	2a e9 bf	* . .
l01f2h:
	ld a,(hl)		;01f2	7e		~
	inc hl			;01f3	23		#
	ld (buf_rd_ptr),hl		;01f4	22 e9 bf	" . .
	pop hl			;01f7	e1		.
	dec c			;01f8	0d		.
	ret			;01f9	c9		.
read_next_sector:
	push hl			;01fa	e5		.
	push de			;01fb	d5		.
	call div_hl_e		;01fc	cd 40 02	. @ .
	ld a,b			;01ff	78		x
	inc a			;0200	3c		<
	ld (fdc_sector),a		;0201	32 ef bf	2 . .
	ld a,l			;0204	7d		}
	pop de			;0205	d1		.
	cp d			;0206	ba		.
	jp nc,cmd_error		;0207	d2 cb 00	. . .
	ld b,000h		;020a	06 00		. .
	ld a,l			;020c	7d		}
	or a			;020d	b7		.
	rra			;020e	1f		.
	jr nc,l0213h		;020f	30 02		0 .
	ld b,002h		;0211	06 02		. .
l0213h:
	ld (fdc_track),a		;0213	32 f0 bf	2 . .
	ld a,b			;0216	78		x
	ld (fdc_side),a		;0217	32 f4 bf	2 . .
l021ah:
	call fdc_seek_read	;021a	cd 74 02	. t .
	jr nz,l023bh		;021d	20 1c		  .
	ld hl,sys_flags		;021f	21 f3 bf	! . .
	ld a,(fdc_track)		;0222	3a f0 bf	: . .
	cp DD_TRACK_THRESH		;0225	fe 16		. .
	jr c,l022dh		;0227	38 04		8 .
	set 7,(hl)		;0229	cb fe		. .
	jr l022fh		;022b	18 02		. .
l022dh:
	res 7,(hl)		;022d	cb be		. .
l022fh:
	ld a,(hl)		;022f	7e		~
	out (PORT_SYS_CTRL),a		;0230	d3 20		.  
	call fdc_read_sector	;0232	cd d2 02	. . .
	dec a			;0235	3d		=
	jr nz,l023bh		;0236	20 03		  .
	pop hl			;0238	e1		.
	inc hl			;0239	23		#
	ret			;023a	c9		.
l023bh:
	call fdc_restore	;023b	cd 51 02	. Q .
	jr l021ah		;023e	18 da		. .
div_hl_e:
	xor a			;0240	af		.
	ld d,010h		;0241	16 10		. .
l0243h:
	add hl,hl		;0243	29		)
	rla			;0244	17		.
	jr c,l024ah		;0245	38 03		8 .
	cp e			;0247	bb		.
	jr c,l024ch		;0248	38 02		8 .
l024ah:
	inc l			;024a	2c		,
	sub e			;024b	93		.
l024ch:
	dec d			;024c	15		.
	jr nz,l0243h		;024d	20 f4		  .
	ld b,a			;024f	47		G
	ret			;0250	c9		.
fdc_restore:
	ld a,FDC_CMD_FORCE_INT		;0251	3e d0		> .
	call fdc_send_cmd	;0253	cd ca 02	. . .
	ld a,FDC_CMD_RESTORE		;0256	3e 0f		> .
	call fdc_send_cmd	;0258	cd ca 02	. . .
l025bh:
	in a,(PORT_FDC_CMD)		;025b	db 10		. .
	bit 0,a			;025d	cb 47		. G
	jr nz,l025bh		;025f	20 fa		  .
	bit 2,a			;0261	cb 57		. W
	jr nz,l0267h		;0263	20 02		  .
	ld a,0ffh		;0265	3e ff		> .
l0267h:
	push af			;0267	f5		.
	push hl			;0268	e5		.
	ld hl,003e8h		;0269	21 e8 03	! . .
l026ch:
	dec hl			;026c	2b		+
	ld a,h			;026d	7c		|
	or l			;026e	b5		.
	jr nz,l026ch		;026f	20 fb		  .
	pop hl			;0271	e1		.
	pop af			;0272	f1		.
	ret			;0273	c9		.
fdc_seek_read:
	ld a,FDC_CMD_FORCE_INT		;0274	3e d0		> .
	call fdc_send_cmd	;0276	cd ca 02	. . .
l0279h:
	in a,(PORT_FDC_CMD)		;0279	db 10		. .
	bit 0,a			;027b	cb 47		. G
	jr nz,l0279h		;027d	20 fa		  .
	push bc			;027f	c5		.
	ld b,002h		;0280	06 02		. .
l0282h:
	ld a,FDC_CMD_READ_ADDR		;0282	3e c4		> .
	call fdc_send_cmd	;0284	cd ca 02	. . .
l0287h:
	in a,(PORT_FDC_CMD)		;0287	db 10		. .
	bit 0,a			;0289	cb 47		. G
	jr z,fdc_check_status	;028b	28 1b		( .
	jr l0287h		;028d	18 f8		. .
fdc_step_in:
	ld a,FDC_CMD_FORCE_INT		;028f	3e d0		> .
	call fdc_send_cmd	;0291	cd ca 02	. . .
	ld a,FDC_CMD_STEP_IN		;0294	3e 5f		> _
	call fdc_send_cmd	;0296	cd ca 02	. . .
l0299h:
	in a,(PORT_FDC_CMD)		;0299	db 10		. .
	bit 0,a			;029b	cb 47		. G
	jr nz,l0299h		;029d	20 fa		  .
	dec b			;029f	05		.
	jr nz,l0282h		;02a0	20 e0		  .
	call fdc_restore	;02a2	cd 51 02	. Q .
	pop bc			;02a5	c1		.
	jr fdc_seek_read	;02a6	18 cc		. .
fdc_check_status:
	bit 4,a			;02a8	cb 67		. g
	jr nz,fdc_step_in	;02aa	20 e3		  .
	bit 3,a			;02ac	cb 5f		. _
	jr nz,fdc_step_in	;02ae	20 df		  .
	pop bc			;02b0	c1		.
	in a,(PORT_FDC_SECTOR)		;02b1	db 12		. .
	out (PORT_FDC_TRACK),a		;02b3	d3 11		. .
	ld a,(fdc_track)		;02b5	3a f0 bf	: . .
	out (PORT_FDC_DATA),a		;02b8	d3 13		. .
	ld a,FDC_CMD_SEEK		;02ba	3e 1f		> .
	call fdc_send_cmd	;02bc	cd ca 02	. . .
l02bfh:
	in a,(PORT_FDC_CMD)		;02bf	db 10		. .
	bit 0,a			;02c1	cb 47		. G
	jr nz,l02bfh		;02c3	20 fa		  .
	and FDC_STAT_ERR_SEEK		;02c5	e6 18		. .
	jr nz,fdc_seek_read	;02c7	20 ab		  .
	ret			;02c9	c9		.
fdc_send_cmd:
	out (PORT_FDC_CMD),a		;02ca	d3 10		. .
	ld a,040h		;02cc	3e 40		> @
l02ceh:
	dec a			;02ce	3d		=
	ret z			;02cf	c8		.
	jr l02ceh		;02d0	18 fc		. .
fdc_read_sector:
	ld a,(fdc_sector)		;02d2	3a ef bf	: . .
	out (PORT_FDC_SECTOR),a		;02d5	d3 12		. .
	ld hl,sector_buf		;02d7	21 e9 be	! . .
	ld b,FDC_CMD_READ_SEC		;02da	06 88		. .
	ld a,(fdc_side)		;02dc	3a f4 bf	: . .
	or b			;02df	b0		.
	call fdc_send_cmd	;02e0	cd ca 02	. . .
l02e3h:
	in a,(PORT_FDC_CMD)		;02e3	db 10		. .
	bit 0,a			;02e5	cb 47		. G
	jr nz,l02e3h		;02e7	20 fa		  .
	and FDC_STAT_ERR_READ		;02e9	e6 3c		. <
	ld a,000h		;02eb	3e 00		> .
	ret nz			;02ed	c0		.
	ld a,001h		;02ee	3e 01		> .
fdc_io_last:
	ret			;02f0	c9		.
parse_hex:

; BLOCK 'hex_parser' (start 0x02f1 end 0x0318)
hex_parser_start:
	ld de,reset		;02f1	11 00 00	. . .
	ld b,e			;02f4	43		C
l02f5h:
	call get_char_echo	;02f5	cd c9 04	. . .
	ld a,c			;02f8	79		y
	sub '0'			;02f9	d6 30		. 0
	cp LF			;02fb	fe 0a		. .
	jr c,l0304h		;02fd	38 05		8 .
	cp 011h			;02ff	fe 11		. .
	ret c			;0301	d8		.
	sub 007h		;0302	d6 07		. .
l0304h:
	cp 010h			;0304	fe 10		. .
	ccf			;0306	3f		?
	ret c			;0307	d8		.
	inc b			;0308	04		.
	ld l,a			;0309	6f		o
	ld h,000h		;030a	26 00		& .
	ld a,010h		;030c	3e 10		> .
l030eh:
	add hl,de		;030e	19		.
	jp c,cmd_error		;030f	da cb 00	. . .
	dec a			;0312	3d		=
	jr nz,l030eh		;0313	20 f9		  .
	ex de,hl		;0315	eb		.
	jr l02f5h		;0316	18 dd		. .
cmd_star:

; BLOCK 'cmd_star_cr_go' (start 0x0318 end 0x034f)
cmd_star_cr_go_start:
	call get_kbd_char	;0318	cd 77 04	. w .
	cp ESC			;031b	fe 1b		. .
	jp z,monitor_prompt	;031d	ca 93 00	. . .
	ld c,a			;0320	4f		O
	call putchar		;0321	cd cd 04	. . .
	jr cmd_star		;0324	18 f2		. .
cmd_cr_boot:
	ld hl,00080h		;0326	21 80 00	! . .
	ld a,'B'		;0329	3e 42		> B
	ex de,hl		;032b	eb		.
	ex af,af'		;032c	08		.
	jp boot_floppy		;032d	c3 f6 00	. . .
l0330h:
	ld a,c			;0330	79		y
	cp CR			;0331	fe 0d		. .
	jp nz,cmd_error		;0333	c2 cb 00	. . .
	ld b,000h		;0336	06 00		. .
	ld de,reset+1		;0338	11 01 00	. . .
	jp boot_floppy		;033b	c3 f6 00	. . .
cmd_go:
	call parse_hex		;033e	cd f1 02	. . .
	dec b			;0341	05		.
	jp m,cmd_error		;0342	fa cb 00	. . .
	ld a,c			;0345	79		y
	cp CR			;0346	fe 0d		. .
	jp nz,cmd_error		;0348	c2 cb 00	. . .
	ex de,hl		;034b	eb		.
	jp exec_loaded_code	;034c	c3 9d 01	. . .
cmd_memory:

; BLOCK 'cmd_memory' (start 0x034f end 0x042c)
cmd_memory_start:
	call print_crlf		;034f	cd 4d 04	. M .
	ld c,004h		;0352	0e 04		. .
	call putchar		;0354	cd cd 04	. . .
	call get_char_echo	;0357	cd c9 04	. . .
	push bc			;035a	c5		.
	ld c,':'		;035b	0e 3a		. :
	call putchar		;035d	cd cd 04	. . .
	pop bc			;0360	c1		.
	ld a,c			;0361	79		y
	cp 'R'			;0362	fe 52		. R
	jp z,monitor_prompt	;0364	ca 93 00	. . .
	cp 'G'			;0367	fe 47		. G
	jr z,cmd_go		;0369	28 d3		( .
	cp 'D'			;036b	fe 44		. D
	jr z,cmd_mem_dispatch	;036d	28 13		( .
	cp 'M'			;036f	fe 4d		. M
	jr z,cmd_mem_dispatch	;0371	28 0f		( .
	cp 'I'			;0373	fe 49		. I
	jr z,cmd_mem_dispatch	;0375	28 0b		( .
	cp 'O'			;0377	fe 4f		. O
	jr z,cmd_mem_dispatch	;0379	28 07		( .
l037bh:
	ld c,BEL		;037b	0e 06		. .
	call putchar		;037d	cd cd 04	. . .
	jr cmd_memory		;0380	18 cd		. .
cmd_mem_dispatch:
	ex af,af'		;0382	08		.
	call parse_hex		;0383	cd f1 02	. . .
	dec b			;0386	05		.
	jp m,cmd_memory		;0387	fa 4f 03	. O .
	ex af,af'		;038a	08		.
	cp 'M'			;038b	fe 4d		. M
	jr z,cmd_mem_modify	;038d	28 71		( q
	cp 'I'			;038f	fe 49		. I
	jr z,cmd_mem_inport	;0391	28 4d		( M
	ex af,af'		;0393	08		.
	ld a,c			;0394	79		y
	cp ','			;0395	fe 2c		. ,
	jr nz,l037bh		;0397	20 e2		  .
	push de			;0399	d5		.
	call parse_hex		;039a	cd f1 02	. . .
	pop hl			;039d	e1		.
	dec b			;039e	05		.
	jp m,l037bh		;039f	fa 7b 03	. { .
	ld a,c			;03a2	79		y
	cp CR			;03a3	fe 0d		. .
	jr nz,l037bh		;03a5	20 d4		  .
	ex af,af'		;03a7	08		.
	cp 'O'			;03a8	fe 4f		. O
	jr z,cmd_mem_outport	;03aa	28 48		( H
	call compare_hl_de	;03ac	cd 47 04	. G .
	jr nc,l037bh		;03af	30 ca		0 .
	ex de,hl		;03b1	eb		.
	push hl			;03b2	e5		.
cmd_mem_dump:
	call print_crlf		;03b3	cd 4d 04	. M .
l03b6h:
	call print_address	;03b6	cd 65 04	. e .
	ld a,004h		;03b9	3e 04		> .
	ex af,af'		;03bb	08		.
l03bch:
	ld b,004h		;03bc	06 04		. .
l03beh:
	ld a,(de)		;03be	1a		.
	call print_hex_byte	;03bf	cd 51 04	. Q .
	inc de			;03c2	13		.
	pop hl			;03c3	e1		.
	call compare_hl_de	;03c4	cd 47 04	. G .
	jp z,cmd_memory		;03c7	ca 4f 03	. O .
	push hl			;03ca	e5		.
	ld a,e			;03cb	7b		{
	or a			;03cc	b7		.
	jr z,cmd_mem_dump	;03cd	28 e4		( .
	ld c,' '		;03cf	0e 20		.  
	call putchar		;03d1	cd cd 04	. . .
	djnz l03beh		;03d4	10 e8		. .
	call putchar		;03d6	cd cd 04	. . .
	ex af,af'		;03d9	08		.
	dec a			;03da	3d		=
	jr z,l03b6h		;03db	28 d9		( .
	ex af,af'		;03dd	08		.
	jr l03bch		;03de	18 dc		. .
cmd_mem_inport:
	ld a,c			;03e0	79		y
	cp CR			;03e1	fe 0d		. .
	jp nz,l037bh		;03e3	c2 7b 03	. { .
	call print_address	;03e6	cd 65 04	. e .
	ld b,d			;03e9	42		B
	ld c,e			;03ea	4b		K
	in d,(c)		;03eb	ed 50		. P
	ld a,d			;03ed	7a		z
	call print_hex_byte	;03ee	cd 51 04	. Q .
	jp cmd_memory		;03f1	c3 4f 03	. O .
cmd_mem_outport:
	ld a,d			;03f4	7a		z
	or a			;03f5	b7		.
	jp nz,l037bh		;03f6	c2 7b 03	. { .
	ld b,h			;03f9	44		D
	ld c,l			;03fa	4d		M
	out (c),e		;03fb	ed 59		. Y
	jp cmd_memory		;03fd	c3 4f 03	. O .
cmd_mem_modify:
	ld a,c			;0400	79		y
	cp CR			;0401	fe 0d		. .
	jp nz,l037bh		;0403	c2 7b 03	. { .
l0406h:
	call print_address	;0406	cd 65 04	. e .
	ex de,hl		;0409	eb		.
	push hl			;040a	e5		.
	ld a,(hl)		;040b	7e		~
	call print_hex_byte	;040c	cd 51 04	. Q .
	ld c,' '		;040f	0e 20		.  
	call putchar		;0411	cd cd 04	. . .
	call parse_hex		;0414	cd f1 02	. . .
	pop hl			;0417	e1		.
	ld a,c			;0418	79		y
	cp '.'			;0419	fe 2e		. .
	jp z,cmd_memory		;041b	ca 4f 03	. O .
	cp CR			;041e	fe 0d		. .
	jp nz,l037bh		;0420	c2 7b 03	. { .
	dec b			;0423	05		.
	jp m,l0428h		;0424	fa 28 04	. ( .
	ld (hl),e		;0427	73		s
l0428h:
	inc hl			;0428	23		#
	ex de,hl		;0429	eb		.
	jr l0406h		;042a	18 da		. .
nibble_to_ascii:

; BLOCK 'hex_output' (start 0x042c end 0x0477)
hex_output_start:
	and 00fh		;042c	e6 0f		. .
	add a,090h		;042e	c6 90		. .
	daa			;0430	27		'
	adc a,040h		;0431	ce 40		. @
	daa			;0433	27		'
	ret			;0434	c9		.
	ld a,l			;0435	7d		}
	cpl			;0436	2f		/
	ld l,a			;0437	6f		o
	ld a,h			;0438	7c		|
	cpl			;0439	2f		/
	ld h,a			;043a	67		g
	inc hl			;043b	23		#
	add hl,de		;043c	19		.
	ret			;043d	c9		.
	push bc			;043e	c5		.
	ld b,a			;043f	47		G
	ld a,l			;0440	7d		}
	sub b			;0441	90		.
	ld l,a			;0442	6f		o
	pop bc			;0443	c1		.
	ret nc			;0444	d0		.
	dec h			;0445	25		%
	ret			;0446	c9		.
compare_hl_de:
	ld a,h			;0447	7c		|
	cp d			;0448	ba		.
	ret nz			;0449	c0		.
	ld a,l			;044a	7d		}
	cp e			;044b	bb		.
	ret			;044c	c9		.
print_crlf:
	ld c,CR			;044d	0e 0d		. .
	jr putchar		;044f	18 7c		. |
print_hex_byte:
	push af			;0451	f5		.
	call nibble_to_ascii	;0452	cd 2c 04	. , .
	ld h,a			;0455	67		g
	pop af			;0456	f1		.
	rra			;0457	1f		.
	rra			;0458	1f		.
	rra			;0459	1f		.
	rra			;045a	1f		.
	call nibble_to_ascii	;045b	cd 2c 04	. , .
	ld c,a			;045e	4f		O
	call putchar		;045f	cd cd 04	. . .
	ld c,h			;0462	4c		L
	jr putchar		;0463	18 68		. h
print_address:
	call print_crlf		;0465	cd 4d 04	. M .
	ld a,d			;0468	7a		z
	call print_hex_byte	;0469	cd 51 04	. Q .
	ld a,e			;046c	7b		{
	call print_hex_byte	;046d	cd 51 04	. Q .
	ld c,' '		;0470	0e 20		.  
	call putchar		;0472	cd cd 04	. . .
	jr putchar		;0475	18 56		. V
get_kbd_char:

; BLOCK 'kbd_driver' (start 0x0477 end 0x04c9)
kbd_driver_start:
	ld a,LUCY_REG_KBD		;0477	3e 07		> .
	out (PORT_LUCY_REG),a		;0479	d3 60		. `
	in a,(PORT_LUCY_DATA)		;047b	db 70		. p
	bit 1,a			;047d	cb 4f		. O
	jr z,l0493h		;047f	28 12		( .
	push af			;0481	f5		.
	xor a			;0482	af		.
	ld (kbd_state),a		;0483	32 fc bf	2 . .
	pop af			;0486	f1		.
	bit 0,a			;0487	cb 47		. G
	jr z,get_kbd_char	;0489	28 ec		( .
l048bh:
	in a,(PORT_KBD_DATA)		;048b	db 30		. 0
	and KBD_DATA_MASK		;048d	e6 7f		. .
	ld (kbd_last),a		;048f	32 fd bf	2 . .
	ret			;0492	c9		.
l0493h:
	ld a,(kbd_state)		;0493	3a fc bf	: . .
	or a			;0496	b7		.
	jr z,l04adh		;0497	28 14		( .
	in a,(PORT_LUCY_DATA)		;0499	db 70		. p
	bit 0,a			;049b	cb 47		. G
	jr nz,l048bh		;049d	20 ec		  .
	push bc			;049f	c5		.
	ld bc,00a00h		;04a0	01 00 0a	. . .
l04a3h:
	dec bc			;04a3	0b		.
	ld a,b			;04a4	78		x
	or c			;04a5	b1		.
	jr nz,l04a3h		;04a6	20 fb		  .
	pop bc			;04a8	c1		.
l04a9h:
	ld a,(kbd_last)		;04a9	3a fd bf	: . .
	ret			;04ac	c9		.
l04adh:
	ld a,001h		;04ad	3e 01		> .
	ld (kbd_state),a		;04af	32 fc bf	2 . .
l04b2h:
	in a,(PORT_LUCY_DATA)		;04b2	db 70		. p
	bit 0,a			;04b4	cb 47		. G
	jr z,l04b2h		;04b6	28 fa		( .
	in a,(PORT_KBD_DATA)		;04b8	db 30		. 0
	ld (kbd_last),a		;04ba	32 fd bf	2 . .
	in a,(PORT_LUCY_DATA)		;04bd	db 70		. p
	bit 1,a			;04bf	cb 4f		. O
	jr z,l04a9h		;04c1	28 e6		( .
	xor a			;04c3	af		.
	ld (kbd_state),a		;04c4	32 fc bf	2 . .
	jr l04a9h		;04c7	18 e0		. .
get_char_echo:

; BLOCK 'char_io_video' (start 0x04c9 end 0x05fa)
char_io_video_start:
	call get_kbd_char	;04c9	cd 77 04	. w .
	ld c,a			;04cc	4f		O
putchar:
	push bc			;04cd	c5		.
	push de			;04ce	d5		.
	push hl			;04cf	e5		.
	ld a,c			;04d0	79		y
	cp CR			;04d1	fe 0d		. .
	jr z,handle_cr		;04d3	28 19		( .
	cp LF			;04d5	fe 0a		. .
	jr z,handle_lf		;04d7	28 25		( %
	ld (vram_char),a		;04d9	32 f9 bf	2 . .
	ld a,ATTR_NORMAL		;04dc	3e 0e		> .
	ld (vram_attr),a		;04de	32 fa bf	2 . .
	call write_vram		;04e1	cd a5 05	. . .
	call advance_cursor	;04e4	cd 06 05	. . .
l04e7h:
	call cursor_off		;04e7	cd dc 05	. . .
	pop hl			;04ea	e1		.
	pop de			;04eb	d1		.
	pop bc			;04ec	c1		.
	ret			;04ed	c9		.
handle_cr:
	call cursor_on		;04ee	cd ec 05	. . .
	call advance_row	;04f1	cd 1f 05	. . .
	call reset_column	;04f4	cd f9 04	. . .
	jr l04e7h		;04f7	18 ee		. .
reset_column:
	xor a			;04f9	af		.
	ld (cursor_col),a		;04fa	32 f8 bf	2 . .
	ret			;04fd	c9		.
handle_lf:
	call cursor_on		;04fe	cd ec 05	. . .
	call advance_row	;0501	cd 1f 05	. . .
	jr l04e7h		;0504	18 e1		. .
advance_cursor:
	ld a,(cursor_col)		;0506	3a f8 bf	: . .
	cp COL_LAST			;0509	fe a7		. .
	jr z,l0518h		;050b	28 0b		( .
	bit 7,a			;050d	cb 7f		. .
	jr z,l0512h		;050f	28 01		( .
	inc a			;0511	3c		<
l0512h:
	xor COL_HALF		;0512	ee 80		. .
	ld (cursor_col),a		;0514	32 f8 bf	2 . .
	ret			;0517	c9		.
l0518h:
	call reset_column	;0518	cd f9 04	. . .
	call advance_row	;051b	cd 1f 05	. . .
	ret			;051e	c9		.
advance_row:
	ld a,(cursor_row)		;051f	3a f7 bf	: . .
	cp LAST_ROW			;0522	fe 18		. .
	jr z,scroll_screen	;0524	28 08		( .
	ld a,(cursor_row)		;0526	3a f7 bf	: . .
	inc a			;0529	3c		<
	ld (cursor_row),a		;052a	32 f7 bf	2 . .
	ret			;052d	c9		.
scroll_screen:
	ld a,(cursor_col)		;052e	3a f8 bf	: . .
	push af			;0531	f5		.
	ld a,(scroll_off)		;0532	3a fb bf	: . .
	inc a			;0535	3c		<
	ld (scroll_off),a		;0536	32 fb bf	2 . .
	cp SCREEN_ROWS		;0539	fe 19		. .
	jr z,l0555h		;053b	28 18		( .
	out (PORT_SCROLL_ALT),a		;053d	d3 04		. .
l053fh:
	xor a			;053f	af		.
	ld (cursor_col),a		;0540	32 f8 bf	2 . .
	ld a,' '		;0543	3e 20		>  
	ld (vram_char),a		;0545	32 f9 bf	2 . .
	ld a,ATTR_NORMAL		;0548	3e 0e		> .
	ld (vram_attr),a		;054a	32 fa bf	2 . .
	call fill_row_spaces	;054d	cd 87 05	. . .
	pop af			;0550	f1		.
	ld (cursor_col),a		;0551	32 f8 bf	2 . .
	ret			;0554	c9		.
l0555h:
	xor a			;0555	af		.
	ld (scroll_off),a		;0556	32 fb bf	2 . .
	out (PORT_SCROLL),a		;0559	d3 03		. .
	jr l053fh		;055b	18 e2		. .
clear_screen:
	xor a			;055d	af		.
l055eh:
	ld (cursor_row),a		;055e	32 f7 bf	2 . .
	xor a			;0561	af		.
	ld (cursor_col),a		;0562	32 f8 bf	2 . .
	ld a,' '		;0565	3e 20		>  
	ld (vram_char),a		;0567	32 f9 bf	2 . .
	ld a,ATTR_NORMAL		;056a	3e 0e		> .
	ld (vram_attr),a		;056c	32 fa bf	2 . .
	call fill_row_spaces	;056f	cd 87 05	. . .
	ld a,(cursor_row)		;0572	3a f7 bf	: . .
	inc a			;0575	3c		<
	cp SCREEN_ROWS		;0576	fe 19		. .
	jr nz,l055eh		;0578	20 e4		  .
	xor a			;057a	af		.
	ld (cursor_col),a		;057b	32 f8 bf	2 . .
	out (PORT_SCROLL),a		;057e	d3 03		. .
	ld (scroll_off),a		;0580	32 fb bf	2 . .
	call cursor_off		;0583	cd dc 05	. . .
	ret			;0586	c9		.
fill_row_spaces:
	call write_vram		;0587	cd a5 05	. . .
	ld a,(cursor_col)		;058a	3a f8 bf	: . .
	inc a			;058d	3c		<
	ld (cursor_col),a		;058e	32 f8 bf	2 . .
	bit 7,a			;0591	cb 7f		. .
	jr nz,l05a0h		;0593	20 0b		  .
	cp COL_HALF_COUNT		;0595	fe 28		. (
	jr nz,fill_row_spaces	;0597	20 ee		  .
	ld a,COL_HALF		;0599	3e 80		> .
	ld (cursor_col),a		;059b	32 f8 bf	2 . .
	jr fill_row_spaces	;059e	18 e7		. .
l05a0h:
	cp COL_WRAP			;05a0	fe a8		. .
	jr nz,fill_row_spaces	;05a2	20 e3		  .
	ret			;05a4	c9		.
write_vram:
	ld hl,cursor_row		;05a5	21 f7 bf	! . .
	ld a,(hl)		;05a8	7e		~
	out (PORT_VIDEO_ROW),a		;05a9	d3 00		. .
	inc hl			;05ab	23		#
	ld d,(hl)		;05ac	56		V
	ld a,(hl)		;05ad	7e		~
	or VID_WRITE_STROBE		;05ae	f6 40		. @
	ld b,a			;05b0	47		G
	inc hl			;05b1	23		#
	ld c,(hl)		;05b2	4e		N
	inc hl			;05b3	23		#
	ld e,(hl)		;05b4	5e		^
	ld hl,sys_flags		;05b5	21 f3 bf	! . .
	set 5,(hl)		;05b8	cb ee		. .
	ld a,LUCY_REG_SCAN		;05ba	3e 06		> .
	out (PORT_LUCY_REG),a		;05bc	d3 60		. `
l05beh:
	in a,(PORT_LUCY_DATA)		;05be	db 70		. p
	bit 0,a			;05c0	cb 47		. G
	jr z,l05beh		;05c2	28 fa		( .
	ld a,(hl)		;05c4	7e		~
	res 5,(hl)		;05c5	cb ae		. .
	ld h,(hl)		;05c7	66		f
	push hl			;05c8	e5		.
	pop hl			;05c9	e1		.
	out (PORT_SYS_CTRL),a		;05ca	d3 20		.  
	ld a,b			;05cc	78		x
	out (PORT_VIDEO_CHAR),a		;05cd	d3 01		. .
	ld a,c			;05cf	79		y
	out (PORT_VIDEO_ATTR),a		;05d0	d3 02		. .
	ld a,d			;05d2	7a		z
	out (PORT_VIDEO_CHAR),a		;05d3	d3 01		. .
	ld a,e			;05d5	7b		{
	out (PORT_VIDEO_ATTR),a		;05d6	d3 02		. .
	ld a,h			;05d8	7c		|
	out (PORT_SYS_CTRL),a		;05d9	d3 20		.  
	ret			;05db	c9		.
cursor_off:
	ld a,' '		;05dc	3e 20		>  
	ld (vram_char),a		;05de	32 f9 bf	2 . .
	ld a,ATTR_NORMAL		;05e1	3e 0e		> .
	xor ATTR_CURSOR_XOR		;05e3	ee c0		. .
	ld (vram_attr),a		;05e5	32 fa bf	2 . .
	call write_vram		;05e8	cd a5 05	. . .
	ret			;05eb	c9		.
cursor_on:
	ld a,' '		;05ec	3e 20		>  
	ld (vram_char),a		;05ee	32 f9 bf	2 . .
	ld a,ATTR_NORMAL		;05f1	3e 0e		> .
	ld (vram_attr),a		;05f3	32 fa bf	2 . .
	call write_vram		;05f6	cd a5 05	. . .
char_io_video_last:
	ret			;05f9	c9		.
post_start:

; BLOCK 'post_code' (start 0x05fa end 0x078a)
post_code_start:
	ex af,af'		;05fa	08		.
	xor a			;05fb	af		.
	ex af,af'		;05fc	08		.
	ld a,SYS_ACTIVE		;05fd	3e 20		>  
	out (PORT_SYS_CTRL),a		;05ff	d3 20		.  
	xor a			;0601	af		.
	ld c,000h		;0602	0e 00		. .
post_vram_write:
	ld d,000h		;0604	16 00		. .
	out (PORT_VIDEO_ROW),a		;0606	d3 00		. .
	ld h,a			;0608	67		g
	ld a,d			;0609	7a		z
l060ah:
	rrca			;060a	0f		.
	ld b,a			;060b	47		G
	or VID_WRITE_STROBE		;060c	f6 40		. @
	out (PORT_VIDEO_CHAR),a		;060e	d3 01		. .
	ld a,c			;0610	79		y
	out (PORT_VIDEO_ATTR),a		;0611	d3 02		. .
	add a,TEST_PATTERN		;0613	c6 55		. U
	ld c,a			;0615	4f		O
	ld a,b			;0616	78		x
	out (PORT_VIDEO_CHAR),a		;0617	d3 01		. .
	ld a,c			;0619	79		y
	out (PORT_VIDEO_ATTR),a		;061a	d3 02		. .
	add a,TEST_PATTERN		;061c	c6 55		. U
	ld c,a			;061e	4f		O
	inc d			;061f	14		.
	ld a,d			;0620	7a		z
	cp SCREEN_COLS		;0621	fe 50		. P
	jr nz,l060ah		;0623	20 e5		  .
	ld a,h			;0625	7c		|
	inc a			;0626	3c		<
	cp SCREEN_ROWS		;0627	fe 19		. .
	jr nz,post_vram_write	;0629	20 d9		  .
	xor a			;062b	af		.
	ld c,000h		;062c	0e 00		. .
post_vram_verify:
	ld d,000h		;062e	16 00		. .
	out (PORT_VIDEO_ROW),a		;0630	d3 00		. .
	ld h,a			;0632	67		g
	ld a,d			;0633	7a		z
l0634h:
	rrca			;0634	0f		.
	ld b,a			;0635	47		G
	or VID_WRITE_STROBE		;0636	f6 40		. @
	out (PORT_VIDEO_CHAR),a		;0638	d3 01		. .
	in a,(PORT_VIDEO_ATTR)		;063a	db 02		. .
	cp c			;063c	b9		.
	jr nz,l0661h		;063d	20 22		  "
	add a,TEST_PATTERN		;063f	c6 55		. U
	ld c,a			;0641	4f		O
	xor a			;0642	af		.
	out (PORT_VIDEO_ATTR),a		;0643	d3 02		. .
	ld a,b			;0645	78		x
	out (PORT_VIDEO_CHAR),a		;0646	d3 01		. .
	in a,(PORT_VIDEO_ATTR)		;0648	db 02		. .
	cp c			;064a	b9		.
	jr nz,l0661h		;064b	20 14		  .
	add a,TEST_PATTERN		;064d	c6 55		. U
	ld c,a			;064f	4f		O
	xor a			;0650	af		.
	out (PORT_VIDEO_ATTR),a		;0651	d3 02		. .
	inc d			;0653	14		.
	ld a,d			;0654	7a		z
	cp SCREEN_COLS		;0655	fe 50		. P
	jr nz,l0634h		;0657	20 db		  .
	ld a,h			;0659	7c		|
	inc a			;065a	3c		<
	cp SCREEN_ROWS		;065b	fe 19		. .
	jr nz,post_vram_verify	;065d	20 cf		  .
	jr post_ram_test	;065f	18 04		. .
l0661h:
	ex af,af'		;0661	08		.
	set 0,a			;0662	cb c7		. .
	ex af,af'		;0664	08		.
post_ram_test:
	ld hl,08000h		;0665	21 00 80	! . .
	ld de,08000h		;0668	11 00 80	. . .
	jr l0671h		;066b	18 04		. .
l066dh:
	ld a,SYS_RAM_TEST		;066d	3e 60		> `
	out (PORT_SYS_CTRL),a		;066f	d3 20		.  
l0671h:
	ld c,080h		;0671	0e 80		. .
	ld a,000h		;0673	3e 00		> .
l0675h:
	ld b,000h		;0675	06 00		. .
l0677h:
	ld (hl),a		;0677	77		w
	inc hl			;0678	23		#
	add a,TEST_PATTERN		;0679	c6 55		. U
	djnz l0677h		;067b	10 fa		. .
	dec c			;067d	0d		.
	jr nz,l0675h		;067e	20 f5		  .
	ld hl,reset		;0680	21 00 00	! . .
	add hl,de		;0683	19		.
	ld c,080h		;0684	0e 80		. .
	ld a,000h		;0686	3e 00		> .
l0688h:
	ld b,000h		;0688	06 00		. .
l068ah:
	cp (hl)			;068a	be		.
	jr nz,l069ah		;068b	20 0d		  .
	inc hl			;068d	23		#
	add a,TEST_PATTERN		;068e	c6 55		. U
	djnz l068ah		;0690	10 f8		. .
	dec c			;0692	0d		.
	jr nz,l0688h		;0693	20 f3		  .
	ld hl,reset		;0695	21 00 00	! . .
	jr l06a9h		;0698	18 0f		. .
l069ah:
	ld a,h			;069a	7c		|
	or l			;069b	b5		.
	jr z,l06a2h		;069c	28 04		( .
	ex af,af'		;069e	08		.
	set 1,a			;069f	cb cf		. .
	ex af,af'		;06a1	08		.
l06a2h:
	ld a,SYS_ACTIVE		;06a2	3e 20		>  
	out (PORT_SYS_CTRL),a		;06a4	d3 20		.  
	jp post_fdc_test	;06a6	c3 c0 06	. . .
l06a9h:
	ld hl,l066dh		;06a9	21 6d 06	! m .
	ld de,0866dh		;06ac	11 6d 86	. m .
	ld bc,irq_handler_last	;06af	01 3c 00	. < .
	ldir			;06b2	ed b0		. .
	ld hl,reset		;06b4	21 00 00	! . .
	ld de,reset		;06b7	11 00 00	. . .
	ld (08698h),hl		;06ba	22 98 86	" . .
	jp 0866dh		;06bd	c3 6d 86	. m .
post_fdc_test:
	ld a,FDC_CMD_FORCE_INT		;06c0	3e d0		> .
	out (PORT_FDC_CMD),a		;06c2	d3 10		. .
	xor a			;06c4	af		.
l06c5h:
	ld c,a			;06c5	4f		O
	out (PORT_FDC_TRACK),a		;06c6	d3 11		. .
	add a,TEST_PATTERN		;06c8	c6 55		. U
	out (PORT_FDC_SECTOR),a		;06ca	d3 12		. .
	add a,TEST_PATTERN		;06cc	c6 55		. U
	out (PORT_FDC_DATA),a		;06ce	d3 13		. .
	ld b,050h		;06d0	06 50		. P
l06d2h:
	djnz l06d2h		;06d2	10 fe		. .
	in a,(PORT_FDC_TRACK)		;06d4	db 11		. .
	cp c			;06d6	b9		.
	jr nz,l06f4h		;06d7	20 1b		  .
	add a,TEST_PATTERN		;06d9	c6 55		. U
	ld c,a			;06db	4f		O
	in a,(PORT_FDC_SECTOR)		;06dc	db 12		. .
	cp c			;06de	b9		.
	jr nz,l06f4h		;06df	20 13		  .
	add a,TEST_PATTERN		;06e1	c6 55		. U
	ld c,a			;06e3	4f		O
	in a,(PORT_FDC_DATA)		;06e4	db 13		. .
	cp c			;06e6	b9		.
	jr nz,l06f4h		;06e7	20 0b		  .
	add a,TEST_PATTERN		;06e9	c6 55		. U
	or a			;06eb	b7		.
	jr z,post_serial_setup	;06ec	28 0e		( .
	ld b,050h		;06ee	06 50		. P
l06f0h:
	djnz l06f0h		;06f0	10 fe		. .
	jr l06c5h		;06f2	18 d1		. .
l06f4h:
	ex af,af'		;06f4	08		.
	set 2,a			;06f5	cb d7		. .
	ex af,af'		;06f7	08		.
	ld a,FDC_CMD_FORCE_INT		;06f8	3e d0		> .
	out (PORT_FDC_CMD),a		;06fa	d3 10		. .
post_serial_setup:
	ld a,SYS_ACTIVE		;06fc	3e 20		>  
	out (PORT_SYS_CTRL),a		;06fe	d3 20		.  
	ld a,UART_MODE1_VAL		;0700	3e 4e		> N
	out (PORT_UART_MODE),a		;0702	d3 52		. R
	ld a,UART_MODE2_VAL		;0704	3e 3e		> >
	out (PORT_UART_MODE),a		;0706	d3 52		. R
	ld a,UART_CMD_VAL		;0708	3e a7		> .
	out (PORT_UART_CMD),a		;070a	d3 53		. S
	ld c,000h		;070c	0e 00		. .
post_serial_test:
	ld d,0ffh		;070e	16 ff		. .
l0710h:
	dec d			;0710	15		.
	jr z,l0730h		;0711	28 1d		( .
	in a,(PORT_UART_STATUS)		;0713	db 51		. Q
	and 001h		;0715	e6 01		. .
	jr z,l0710h		;0717	28 f7		( .
	ld a,c			;0719	79		y
	out (PORT_UART_DATA),a		;071a	d3 50		. P
	xor a			;071c	af		.
l071dh:
	dec ix			;071d	dd 2b		. +
	dec a			;071f	3d		=
	jr nz,l071dh		;0720	20 fb		  .
	in a,(PORT_UART_DATA)		;0722	db 50		. P
	cp c			;0724	b9		.
	jr nz,l0730h		;0725	20 09		  .
	add a,TEST_PATTERN		;0727	c6 55		. U
	ld c,a			;0729	4f		O
	or a			;072a	b7		.
	jr nz,post_serial_test	;072b	20 e1		  .
	jp post_timer_test	;072d	c3 34 07	. 4 .
l0730h:
	ex af,af'		;0730	08		.
	set 3,a			;0731	cb df		. .
	ex af,af'		;0733	08		.
post_timer_test:
	ld hl,reset		;0734	21 00 00	! . .
	ld d,000h		;0737	16 00		. .
	im 1			;0739	ed 56		. V
	ei			;073b	fb		.
l073ch:
	dec hl			;073c	2b		+
	ld a,h			;073d	7c		|
	or l			;073e	b5		.
	jr nz,l073ch		;073f	20 fb		  .
	di			;0741	f3		.
	ld a,d			;0742	7a		z
	cp 023h			;0743	fe 23		. #
	jr c,l074bh		;0745	38 04		8 .
	cp 025h			;0747	fe 25		. %
	jr c,post_complete	;0749	38 04		8 .
l074bh:
	ex af,af'		;074b	08		.
	set 4,a			;074c	cb e7		. .
	ex af,af'		;074e	08		.
post_complete:
	di			;074f	f3		.
	call init_display	;0750	cd 6e 00	. n .
	ld hl,str_autotest	;0753	21 98 07	! . .
l0756h:
	ld c,(hl)		;0756	4e		N
	call putchar		;0757	cd cd 04	. . .
	inc hl			;075a	23		#
	ld a,(hl)		;075b	7e		~
	or a			;075c	b7		.
	jr nz,l0756h		;075d	20 f7		  .
	ex af,af'		;075f	08		.
	or a			;0760	b7		.
	jr nz,post_show_errors	;0761	20 0d		  .
	ld c,'O'		;0763	0e 4f		. O
	call putchar		;0765	cd cd 04	. . .
	ld c,'K'		;0768	0e 4b		. K
	call putchar		;076a	cd cd 04	. . .
	jp monitor_prompt	;076d	c3 93 00	. . .
post_show_errors:
	ld b,008h		;0770	06 08		. .
	ld e,a			;0772	5f		_
	ld d,'0'		;0773	16 30		. 0
l0775h:
	srl e			;0775	cb 3b		. ;
	jr c,l077fh		;0777	38 06		8 .
l0779h:
	inc d			;0779	14		.
	djnz l0775h		;077a	10 f9		. .
	jp monitor_prompt	;077c	c3 93 00	. . .
l077fh:
	ld c,CR			;077f	0e 0d		. .
	call putchar		;0781	cd cd 04	. . .
	ld c,d			;0784	4a		J
	call putchar		;0785	cd cd 04	. . .
	jr l0779h		;0788	18 ef		. .
str_prompt:

; BLOCK 'str_prompt' (start 0x078a end 0x0798)
str_prompt_start:
	defb 00dh		;078a	0d		.
	defb 00ah		;078b	0a		.
	defb 020h		;078c	20		 
	defb 04dh		;078d	4d		M
	defb 020h		;078e	20		 
	defb 050h		;078f	50		P
	defb 020h		;0790	20		 
	defb 032h		;0791	32		2
	defb 020h		;0792	20		 
	defb 02eh		;0793	2e		.
	defb 02eh		;0794	2e		.
	defb 02eh		;0795	2e		.
	defb 020h		;0796	20		 
str_prompt_last:
	defb 000h		;0797	00		.
str_autotest:

; BLOCK 'str_autotest' (start 0x0798 end 0x07a8)
str_autotest_start:
	defb 00dh		;0798	0d		.
	defb 00ah		;0799	0a		.
	defb 020h		;079a	20		 
	defb 041h		;079b	41		A
	defb 055h		;079c	55		U
	defb 054h		;079d	54		T
	defb 04fh		;079e	4f		O
	defb 02dh		;079f	2d		-
	defb 054h		;07a0	54		T
	defb 045h		;07a1	45		E
	defb 053h		;07a2	53		S
	defb 054h		;07a3	54		T
	defb 020h		;07a4	20		 
	defb 03ah		;07a5	3a		:
	defb 020h		;07a6	20		 
str_autotest_last:
	defb 000h		;07a7	00		.
floppy_params:

; BLOCK 'floppy_data' (start 0x07a8 end 0x0800)
floppy_data_start:
	defb 020h		;07a8	20		 
	defb 010h		;07a9	10		.
	defb 000h		;07aa	00		.
	defb 000h		;07ab	00		.
	defb 000h		;07ac	00		.
	defb 000h		;07ad	00		.
	defb 000h		;07ae	00		.
	defb 000h		;07af	00		.
	defb 000h		;07b0	00		.
	defb 000h		;07b1	00		.
	defb 000h		;07b2	00		.
	defb 000h		;07b3	00		.
	defb 000h		;07b4	00		.
	defb 000h		;07b5	00		.
	defb 000h		;07b6	00		.
	defb 000h		;07b7	00		.
	defb 000h		;07b8	00		.
	defb 000h		;07b9	00		.
	defb 000h		;07ba	00		.
	defb 000h		;07bb	00		.
	defb 000h		;07bc	00		.
	defb 000h		;07bd	00		.
	defb 000h		;07be	00		.
	defb 000h		;07bf	00		.
	defb 000h		;07c0	00		.
	defb 000h		;07c1	00		.
	defb 000h		;07c2	00		.
	defb 000h		;07c3	00		.
	defb 000h		;07c4	00		.
	defb 000h		;07c5	00		.
	defb 000h		;07c6	00		.
	defb 000h		;07c7	00		.
	defb 000h		;07c8	00		.
	defb 000h		;07c9	00		.
	defb 000h		;07ca	00		.
	defb 000h		;07cb	00		.
	defb 000h		;07cc	00		.
	defb 000h		;07cd	00		.
	defb 000h		;07ce	00		.
	defb 000h		;07cf	00		.
	defb 000h		;07d0	00		.
	defb 000h		;07d1	00		.
	defb 000h		;07d2	00		.
	defb 000h		;07d3	00		.
	defb 000h		;07d4	00		.
	defb 000h		;07d5	00		.
	defb 000h		;07d6	00		.
	defb 000h		;07d7	00		.
	defb 000h		;07d8	00		.
	defb 000h		;07d9	00		.
	defb 000h		;07da	00		.
	defb 000h		;07db	00		.
	defb 000h		;07dc	00		.
	defb 000h		;07dd	00		.
	defb 000h		;07de	00		.
	defb 000h		;07df	00		.
	defb 000h		;07e0	00		.
	defb 000h		;07e1	00		.
	defb 000h		;07e2	00		.
	defb 000h		;07e3	00		.
	defb 000h		;07e4	00		.
	defb 000h		;07e5	00		.
	defb 000h		;07e6	00		.
	defb 000h		;07e7	00		.
	defb 000h		;07e8	00		.
	defb 000h		;07e9	00		.
	defb 000h		;07ea	00		.
	defb 000h		;07eb	00		.
	defb 000h		;07ec	00		.
	defb 000h		;07ed	00		.
	defb 000h		;07ee	00		.
	defb 000h		;07ef	00		.
	defb 000h		;07f0	00		.
	defb 000h		;07f1	00		.
	defb 000h		;07f2	00		.
	defb 000h		;07f3	00		.
	defb 000h		;07f4	00		.
	defb 000h		;07f5	00		.
	defb 000h		;07f6	00		.
	defb 000h		;07f7	00		.
	defb 000h		;07f8	00		.
	defb 000h		;07f9	00		.
	defb 000h		;07fa	00		.
	defb 000h		;07fb	00		.
	defb 000h		;07fc	00		.
	defb 000h		;07fd	00		.
	defb 000h		;07fe	00		.
floppy_data_last:
	defb 000h		;07ff	00		.
