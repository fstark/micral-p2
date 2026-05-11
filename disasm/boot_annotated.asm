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

; ============================================================
; reset — Power-on entry point
; Initializes stack, pulses keyboard controller enable,
; configures SAA5070 (LUCY) for video sync and keyboard
; scanning, then jumps to POST.
; ============================================================
reset:

; BLOCK 'reset_init' (start 0x0000 end 0x0033)
reset_init_start:
	ld sp,stack_top		;0000	31 e8 be	1 . .
; Pulse keyboard enable on system control port
	ld a,SYS_KBD_ENABLE		;0003	3e 22		> "
	out (PORT_SYS_CTRL),a		;0005	d3 20		.  
; Short delay for keyboard controller to latch
	ld b,030h		;0007	06 30		. 0
delay_loop:
	djnz delay_loop		;0009	10 fe		. .
; Deassert keyboard enable pulse
	xor a			;000b	af		.
	out (PORT_SYS_CTRL),a		;000c	d3 20		.  
; Select LUCY sync register and trigger sync
	ld a,LUCY_REG_SYNC		;000e	3e 03		> .
	out (PORT_LUCY_REG),a		;0010	d3 60		. `
	ld a,LUCY_SYNC_BIT		;0012	3e 20		>  
	out (PORT_LUCY_DATA),a		;0014	d3 70		. p
; Poll until LUCY sync completes (bit 5 clears)
wait_lucy_sync:
	ld a,LUCY_REG_SYNC		;0016	3e 03		> .
	out (PORT_LUCY_REG),a		;0018	d3 60		. `
	in a,(PORT_LUCY_DATA)		;001a	db 70		. p
	and LUCY_SYNC_BIT		;001c	e6 20		.  
	jr nz,wait_lucy_sync		;001e	20 f6		  .
; Enable all keyboard scan rows (LUCY register 6)
	ld a,LUCY_REG_SCAN		;0020	3e 06		> .
	out (PORT_LUCY_REG),a		;0022	d3 60		. `
	ld a,LUCY_SCAN_ALL		;0024	3e ff		> .
	out (PORT_LUCY_DATA),a		;0026	d3 70		. p
; Enable keyboard data register (LUCY register 7)
	ld a,LUCY_REG_KBD		;0028	3e 07		> .
	out (PORT_LUCY_REG),a		;002a	d3 60		. `
	ld a,LUCY_SCAN_ALL		;002c	3e ff		> .
	out (PORT_LUCY_DATA),a		;002e	d3 70		. p
; Hardware init done — jump to Power-On Self Test
	jp post_start		;0030	c3 fa 05	. . .

; BLOCK 'pad_rst30' (start 0x0033 end 0x0038)
pad_rst30_start:
	defb 000h		;0033	00		.
	defb 000h		;0034	00		.
	defb 000h		;0035	00		.
	defb 000h		;0036	00		.
pad_rst30_last:
	defb 000h		;0037	00		.
; ============================================================
; irq_im1 — IM1 interrupt handler (address 0x0038)
; Called by CTC timer tick. Increments D as a tick counter
; (used by POST timing calibration), reloads timer, returns.
; ============================================================
irq_im1:

; BLOCK 'irq_handler' (start 0x0038 end 0x003d)
irq_handler_start:
	inc d			;0038	14		. ; bump tick counter
	out (PORT_TIMER),a		;0039	d3 07		. . ; reload timer
	ei			;003b	fb		. ; re-enable interrupts
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
; ============================================================
; nmi_handler — Non-maskable interrupt (address 0x0066)
; Triggered by FDC DRQ (data request). Saves AF via shadow
; register, reads one byte from FDC data port into the
; buffer at (HL), advances HL, restores AF and returns.
; Called once per byte during sector reads.
; ============================================================
nmi_handler:

; BLOCK 'nmi_handler' (start 0x0066 end 0x006e)
nmi_handler_start:
	ex af,af'		;0066	08		. ; save caller's flags
	in a,(PORT_FDC_DATA)		;0067	db 13		. . ; read byte from FDC
	ld (hl),a		;0069	77		w ; store into buffer
	inc hl			;006a	23		# ; advance buffer pointer
	ex af,af'		;006b	08		. ; restore caller's flags
	retn			;006c	ed 45		. E
; ============================================================
; init_display — Initialize video display state
; Sets cursor to row 25 (off-screen), clears system flags
; and column, writes '.' at both column halves to prime the
; SAA5120, then clears the full screen.
; ============================================================
init_display:

; BLOCK 'init_display' (start 0x006e end 0x0093)
init_display_start:
; Start cursor off-screen (row 25); first CR will scroll it in
	ld a,SCREEN_ROWS		;006e	3e 19		> .
	ld (cursor_row),a		;0070	32 f7 bf	2 . .
; Clear system flags and reset column to 0
	xor a			;0073	af		.
	ld (sys_flags),a		;0074	32 f3 bf	2 . .
	ld (cursor_col),a		;0077	32 f8 bf	2 . .
; Prime SAA5120: write '.' at left-half column 0
	ld a,001h		;007a	3e 01		> .
	ld (vram_attr),a		;007c	32 fa bf	2 . .
	ld a,'.'		;007f	3e 2e		> .
	ld (vram_char),a		;0081	32 f9 bf	2 . .
	call write_vram		;0084	cd a5 05	. . .
; Same for right-half column 0 (bit 7 = right half)
	ld a,COL_HALF		;0087	3e 80		> .
	ld (cursor_col),a		;0089	32 f8 bf	2 . .
	call write_vram		;008c	cd a5 05	. . .
; Fill entire screen with spaces
	call clear_screen	;008f	cd 5d 05	. ] .
init_display_last:
	ret			;0092	c9		.
; ============================================================
; monitor_prompt — Main monitor command loop
; Resets stack, prints "\r\n M P 2 ... " prompt, reads one
; character and dispatches:
;   CR → default boot (drive 0)    B → boot drive,sector
;   *  → transparent terminal      M → memory submenu
;   G  → execute at address
; Invalid commands beep and re-prompt.
; ============================================================
monitor_prompt:

; BLOCK 'monitor' (start 0x0093 end 0x00f6)
monitor_start:
; Reset stack (clean return from any prior command)
	ld sp,stack_top		;0093	31 e8 be	1 . .
; Clear system flags
	xor a			;0096	af		.
	ld (sys_flags),a		;0097	32 f3 bf	2 . .
	ld hl,str_prompt	;009a	21 8a 07	! . .
print_str_loop:
	ld c,(hl)		;009d	4e		N
	call putchar		;009e	cd cd 04	. . .
	inc hl			;00a1	23		#
	ld a,(hl)		;00a2	7e		~
	or a			;00a3	b7		.
	jr nz,print_str_loop		;00a4	20 f7		  .
; Read command character
	ld b,000h		;00a6	06 00		. .
	call get_char_echo	;00a8	cd c9 04	. . .
; Bare Enter → default boot from drive 0
	ld a,c			;00ab	79		y
	cp CR			;00ac	fe 0d		. .
	jp z,cmd_cr_boot	;00ae	ca 26 03	. & .
; Not CR — echo ':' separator and match command letter
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
; No valid command matched — beep and re-prompt
cmd_error:
	ld c,BEL		;00cb	0e 06		. .
	call putchar		;00cd	cd cd 04	. . .
	jr monitor_prompt	;00d0	18 c1		. .
; Parse 'B' command: B<drive>,<sector>
cmd_boot_parse:
	ex af,af'		;00d2	08		.
; Read drive number as hex
	call parse_hex		;00d3	cd f1 02	. . .
	dec b			;00d6	05		.
	jp m,cmd_boot_default		;00d7	fa 30 03	. 0 . ; no digits → default
; Expect comma separator
	ld a,c			;00da	79		y
	cp ','			;00db	fe 2c		. ,
	jr nz,cmd_error		;00dd	20 ec		  .
; Validate drive number is 0 or 1
	ld a,d			;00df	7a		z
	or a			;00e0	b7		.
	jr nz,cmd_error		;00e1	20 e8		  . ; high byte must be 0
	or e			;00e3	b3		.
	cp 002h			;00e4	fe 02		. .
	jr nc,cmd_error		;00e6	30 e3		0 . ; drive >= 2 invalid
; Save drive number, parse starting sector
	push af			;00e8	f5		.
	call parse_hex		;00e9	cd f1 02	. . .
	dec b			;00ec	05		.
	ld a,c			;00ed	79		y
	pop bc			;00ee	c1		.
	jp m,cmd_error		;00ef	fa cb 00	. . .
	cp CR			;00f2	fe 0d		. .
	jr nz,cmd_error		;00f4	20 d5		  .
; ============================================================
; boot_floppy — Floppy disk boot loader
; Entry: B=drive (0/1), DE=starting sector, A'=drive letter
; Disables interrupts, saves drive number, selects the drive
; in system control register, waits for FDC ready, restores
; head to track 0, reads boot sector 1, then enters the MOS
; hex record loading loop. Data records (0xC2) load bytes
; into RAM, exec records (0xC6) bank-switch and jump.
; ============================================================
boot_floppy:

; BLOCK 'boot_loader' (start 0x00f6 end 0x01bd)
boot_loader_start:
	di			;00f6	f3		. ; no interrupts during boot
	ld (disk_lba),de		;00f7	ed 53 ed bf	. S . . ; save starting sector
	ex af,af'		;00fb	08		.
	ld (stack_top),a		;00fc	32 e8 be	2 . . ; save boot drive number
; Select drive: bit 2 = drive 0, bit 3 = drive 1, bit 4 = motor on
setup_fdc_flags:
	ld hl,sys_flags		;00ff	21 f3 bf	! . .
	dec b			;0102	05		.
	jr z,setup_drive1		;0103	28 04		( .
	set 2,(hl)		;0105	cb d6		. . ; drive 0 select
	jr setup_drive_common		;0107	18 02		. .
setup_drive1:
	set 3,(hl)		;0109	cb de		. . ; drive 1 select
setup_drive_common:
	set 4,(hl)		;010b	cb e6		. . ; motor enable
	ld a,(hl)		;010d	7e		~
	out (PORT_SYS_CTRL),a		;010e	d3 20		.   ; apply drive selection
; Load floppy parameters table pointer
	ld hl,floppy_params	;0110	21 a8 07	! . .
	ld (floppy_prm_ptr),hl		;0113	22 f5 bf	" . .
; Wait for FDC to become idle (bit 7 = not ready)
wait_drive_ready:
	in a,(PORT_FDC_CMD)		;0116	db 10		. .
	bit 7,a			;0118	cb 7f		. .
	jr nz,wait_drive_ready	;011a	20 fa		  .
; Long delay for drive motor spin-up / head settle
	ld de,0c000h		;011c	11 00 c0	. . .
settle_delay:
	ex (sp),hl		;011f	e3		. ; waste cycles
	ex (sp),hl		;0120	e3		.
	dec de			;0121	1b		.
	ld a,e			;0122	7b		{
	or d			;0123	b2		.
	jr nz,settle_delay		;0124	20 f9		  .
; Restore head to track 0, then read boot sector
read_boot_sector:
	call fdc_restore	;0126	cd 51 02	. Q .
; Load disk geometry from floppy parameters: sectors/track, heads
	ld hl,(floppy_prm_ptr)		;0129	2a f5 bf	* . .
	ld a,(hl)		;012c	7e		~ ; first byte = sectors/track * 2
	rlca			;012d	07		. ; rotate to get heads in high bits
	inc hl			;012e	23		#
	ld l,(hl)		;012f	6e		n ; second byte
	ld h,a			;0130	67		g
	ld (disk_geom),hl		;0131	22 f1 bf	" . .
; Start reading from side 0, sector 1
	ld a,000h		;0134	3e 00		> .
	ld (fdc_side),a		;0136	32 f4 bf	2 . .
	inc a			;0139	3c		< ; A = 1
	ld (fdc_sector),a		;013a	32 ef bf	2 . .
; Read the boot sector; retry from restore if error
	call fdc_read_sector	;013d	cd d2 02	. . .
	dec a			;0140	3d		= ; A=1 → 0 on success
	jr nz,read_boot_sector	;0141	20 e3		  . ; retry on error
; Check boot config byte from sector data (offset +2)
; Bits 7,6 control which RAM banks to enable at 0xFFFD
	ld a,(boot_cfg)		;0143	3a eb be	: . .
	ld hl,0fffdh		;0146	21 fd ff	! . .
	ld (hl),000h		;0149	36 00		6 .
	bit 7,a			;014b	cb 7f		. . ; test bank 1 flag
	jr z,check_bank2		;014d	28 02		( .
	set 1,(hl)		;014f	cb ce		. . ; enable bank 1
check_bank2:
	bit 6,a			;0151	cb 77		. w ; test bank 2 flag
	jr z,begin_record_load		;0153	28 02		( .
	set 2,(hl)		;0155	cb d6		. . ; enable bank 2
; Initialize record loading: zero bytes remaining in buffer
begin_record_load:
	ld hl,reset		;0157	21 00 00	! . . ; HL = 0 (zero)
	ld (buf_remain),hl		;015a	22 eb bf	" . . ; buffer empty → force first read
; --- MOS hex record parsing loop ---
; Each record: length (C), type (B), optional address (HL), data bytes
parse_record:
	call get_next_byte	;015d	cd bd 01	. . . ; read record length
	and a			;0160	a7		.
	jp z,cmd_error		;0161	ca cb 00	. . . ; zero length = bad record
	ld c,a			;0164	4f		O ; C = byte count for this record
	call get_next_byte	;0165	cd bd 01	. . . ; read record type
	ld b,a			;0168	47		G ; B = record type
; If length >= 3, record has address (H:L) + extra byte
	ld a,c			;0169	79		y
	cp 003h			;016a	fe 03		. .
	jr c,dispatch_record	;016c	38 0b		8 . ; short record, skip addr
	call get_next_byte	;016e	cd bd 01	. . . ; read address high byte
	ld h,a			;0171	67		g
	call get_next_byte	;0172	cd bd 01	. . . ; read address low byte
	ld l,a			;0175	6f		o
	call get_next_byte	;0176	cd bd 01	. . . ; read extra byte (discarded)
; Dispatch on record type
dispatch_record:
	ld a,b			;0179	78		x
	cp REC_DATA			;017a	fe c2		. .
	jr z,load_data_record	;017c	28 18		( . ; 0xC2 = load data
	cp REC_ERROR			;017e	fe d2		. .
	jp z,cmd_error		;0180	ca cb 00	. . . ; 0xD2 = error/abort
	cp REC_EXEC			;0183	fe c6		. .
	jr z,exec_loaded_code	;0185	28 16		( . ; 0xC6 = run loaded code
; Unknown record type — must be in valid range or abort
	cp REC_TYPE_MIN		;0187	fe c1		. .
	jp c,cmd_error		;0189	da cb 00	. . . ; below valid range
	cp REC_TYPE_MAX		;018c	fe db		. .
	jp nc,cmd_error		;018e	d2 cb 00	. . . ; above valid range
; Valid but unhandled type — consume remaining bytes and loop
skip_record_bytes:
	call get_next_byte	;0191	cd bd 01	. . . ; consume byte (C auto-decrements)
	jr skip_record_bytes		;0194	18 fb		. . ; loops until C=0 triggers return
; Load data bytes from record into memory at (HL)
load_data_record:
	call get_next_byte	;0196	cd bd 01	. . . ; read next data byte
	ld (hl),a		;0199	77		w ; store at current load address
	inc hl			;019a	23		# ; advance load pointer
	jr load_data_record	;019b	18 f9		. . ; loop until C=0 triggers return
; Execute loaded code via bank-switch trampoline
; Copies 13-byte stub to RAM that switches ROM out / RAM in
; (via bank latch at 0xFFFF and port 0x20), then jumps to
; the loaded program's entry point (HL).
exec_loaded_code:
	di			;019d	f3		.
	push hl			;019e	e5		. ; save entry point
	push de			;019f	d5		.
; Copy trampoline code to RAM (can't run from ROM after bank switch)
	ld hl,trampoline	;01a0	21 b0 01	! . .
	ld de,sector_buf		;01a3	11 e9 be	. . .
	ld bc,0000dh		;01a6	01 0d 00	. . . ; 13 bytes
	ldir			;01a9	ed b0		. .
	pop de			;01ab	d1		.
	pop hl			;01ac	e1		. ; restore entry point to HL
	jp sector_buf		;01ad	c3 e9 be	. . . ; jump to trampoline in RAM
; --- Trampoline stub (copied to RAM and executed there) ---
; Switches ROM out by writing to bank latch, then jumps to HL
trampoline:
	ld a,(sys_flags)		;01b0	3a f3 bf	: . .
	or SYS_BANK_SWITCH		;01b3	f6 40		. @ ; set bank switch bit
	ld (bank_latch),a		;01b5	32 ff ff	2 . . ; latch: ROM out, RAM in
	ld a,SYS_BANK_SWITCH		;01b8	3e 40		> @
	out (PORT_SYS_CTRL),a		;01ba	d3 20		.   ; system control mirrors it
boot_loader_last:
	jp (hl)			;01bc	e9		. ; jump to loaded program
; ============================================================
; get_next_byte — Read next byte from sequential disk stream
; Manages a 256-byte sector buffer with lazy refill: if the
; buffer is empty, reads the next sector from disk. Tracks
; record byte count in C: when C reaches 0, the record is
; done and control pops back to parse_record.
; Returns: A = next byte, C decremented
; ============================================================
get_next_byte:

; BLOCK 'fdc_io' (start 0x01bd end 0x02f1)
fdc_io_start:
; Check if record has any bytes remaining (C = byte counter)
	inc c			;01bd	0c		. ; test C without destroying it
	dec c			;01be	0d		. ; (inc+dec restores C, sets Z if was 0)
	jr nz,get_byte_body		;01bf	20 04		  . ; bytes remaining → read next byte
; C was 0: record complete — discard return address and loop back
	pop af			;01c1	f1		. ; discard caller's return address
	inc c			;01c2	0c		. ; set C=1 so parse_record reads length
	jr parse_record		;01c3	18 98		. . ; back to record parsing loop
get_byte_body:
	push hl			;01c5	e5		. ; save caller's HL
; Check if sector buffer has unread data
	ld hl,(buf_remain)		;01c6	2a eb bf	* . .
	ld a,h			;01c9	7c		|
	or l			;01ca	b5		.
	jr nz,buf_has_data		;01cb	20 1e		  . ; still have bytes
; Buffer exhausted — read next sector from disk
	push hl			;01cd	e5		.
	push de			;01ce	d5		.
	push bc			;01cf	c5		.
	ld hl,(disk_geom)		;01d0	2a f1 bf	* . . ; load geometry (spt, heads)
	ex de,hl		;01d3	eb		. ; DE = geometry
	ld hl,(disk_lba)		;01d4	2a ed bf	* . . ; HL = current LBA
	call read_next_sector	;01d7	cd fa 01	. . . ; read sector, returns HL = LBA+1
	ld (disk_lba),hl		;01da	22 ed bf	" . . ; save updated LBA
	pop bc			;01dd	c1		.
	pop de			;01de	d1		.
	pop hl			;01df	e1		.
; Reset buffer: 255 bytes remaining, pointer = sector_buf
	ld hl,setup_fdc_flags	;01e0	21 ff 00	! . . ; HL = 0x00FF = 255
	ld (buf_remain),hl		;01e3	22 eb bf	" . .
	ld hl,sector_buf		;01e6	21 e9 be	! . .
	jr read_from_buf		;01e9	18 07		. .
; Buffer still has data — decrement count, load from read pointer
buf_has_data:
	dec hl			;01eb	2b		+ ; one fewer byte remaining
	ld (buf_remain),hl		;01ec	22 eb bf	" . .
	ld hl,(buf_rd_ptr)		;01ef	2a e9 bf	* . . ; current read position
; Fetch byte from buffer and advance read pointer
read_from_buf:
	ld a,(hl)		;01f2	7e		~ ; read byte from buffer
	inc hl			;01f3	23		# ; advance pointer
	ld (buf_rd_ptr),hl		;01f4	22 e9 bf	" . . ; save updated pointer
	pop hl			;01f7	e1		. ; restore caller's HL
	dec c			;01f8	0d		. ; decrement record byte counter
	ret			;01f9	c9		.
; ============================================================
; read_next_sector — Convert LBA to CHS and read one sector
; Entry: HL = logical block address, DE = disk geometry
;        E = sectors per track, D = number of tracks
; Computes track/sector/side from LBA, seeks to the correct
; track, selects density (SD below track 22, DD above), and
; reads the sector. Retries with restore on any error.
; Returns: HL = LBA + 1 (next sector to read)
; ============================================================
read_next_sector:
	push hl			;01fa	e5		.
	push de			;01fb	d5		.
; Divide LBA by sectors-per-track: L = track, B = sector offset
	call div_hl_e		;01fc	cd 40 02	. @ .
	ld a,b			;01ff	78		x ; remainder = sector offset
	inc a			;0200	3c		< ; sectors are 1-based
	ld (fdc_sector),a		;0201	32 ef bf	2 . .
; Check track against max tracks (D)
	ld a,l			;0204	7d		} ; L = track (including side bit)
	pop de			;0205	d1		.
	cp d			;0206	ba		. ; track >= max?
	jp nc,cmd_error		;0207	d2 cb 00	. . . ; past end of disk
; Determine side from track parity: even = side 0, odd = side 1
	ld b,000h		;020a	06 00		. .
	ld a,l			;020c	7d		}
	or a			;020d	b7		.
	rra			;020e	1f		. ; shift out low bit into carry
	jr nc,set_track		;020f	30 02		0 . ; even track → side 0
	ld b,002h		;0211	06 02		. . ; odd track → side 1 (B=2)
set_track:
	ld (fdc_track),a		;0213	32 f0 bf	2 . . ; physical track = LBA_track / 2
	ld a,b			;0216	78		x
	ld (fdc_side),a		;0217	32 f4 bf	2 . . ; side select value
; Seek to track and read sector; retry with restore on error
try_seek_read:
	call fdc_seek_read	;021a	cd 74 02	. t .
	jr nz,retry_seek_read		;021d	20 1c		  . ; seek failed, retry
; Set density based on track number (track >= 22 → double density)
	ld hl,sys_flags		;021f	21 f3 bf	! . .
	ld a,(fdc_track)		;0222	3a f0 bf	: . .
	cp DD_TRACK_THRESH		;0225	fe 16		. .
	jr c,set_single_density		;0227	38 04		8 . ; track < 22
	set 7,(hl)		;0229	cb fe		. . ; set DD flag
	jr apply_density		;022b	18 02		. .
set_single_density:
	res 7,(hl)		;022d	cb be		. . ; clear DD flag
apply_density:
	ld a,(hl)		;022f	7e		~
	out (PORT_SYS_CTRL),a		;0230	d3 20		.   ; output updated flags
	call fdc_read_sector	;0232	cd d2 02	. . .
	dec a			;0235	3d		= ; A=1 success, 0 = error
	jr nz,retry_seek_read		;0236	20 03		  . ; read error → retry
	pop hl			;0238	e1		.
	inc hl			;0239	23		# ; return LBA + 1
	ret			;023a	c9		.
retry_seek_read:
	call fdc_restore	;023b	cd 51 02	. Q . ; restore to track 0
	jr try_seek_read		;023e	18 da		. . ; try seek again
; ============================================================
; div_hl_e — Unsigned 16-bit by 8-bit division
; Entry: HL = dividend, E = divisor
; Returns: L = quotient, B = remainder
; Uses shift-and-subtract algorithm (16 iterations).
; ============================================================
div_hl_e:
	xor a			;0240	af		. ; clear accumulator (partial remainder)
	ld d,010h		;0241	16 10		. . ; 16-bit dividend = 16 iterations
div_loop:
	add hl,hl		;0243	29		) ; shift dividend left, MSB into A
	rla			;0244	17		.
	jr c,div_subtract		;0245	38 03		8 . ; overflow → must subtract
	cp e			;0247	bb		. ; partial remainder >= divisor?
	jr c,div_next_bit		;0248	38 02		8 . ; no → skip subtract
div_subtract:
	inc l			;024a	2c		, ; set quotient bit
	sub e			;024b	93		. ; subtract divisor from remainder
div_next_bit:
	dec d			;024c	15		. ; count iterations
	jr nz,div_loop		;024d	20 f4		  .
	ld b,a			;024f	47		G ; B = final remainder
	ret			;0250	c9		.
; ============================================================
; fdc_restore — Restore FDC head to track 0
; Aborts any pending command, issues restore, waits for
; completion, then delays for head settle time (~1ms).
; Returns: A = 0xFF if track-0 found, status bits if error
; ============================================================
fdc_restore:
	ld a,FDC_CMD_FORCE_INT		;0251	3e d0		> . ; abort any pending command
	call fdc_send_cmd	;0253	cd ca 02	. . .
	ld a,FDC_CMD_RESTORE		;0256	3e 0f		> . ; restore to track 0
	call fdc_send_cmd	;0258	cd ca 02	. . .
; Poll until FDC finishes (bit 0 = busy)
wait_restore_done:
	in a,(PORT_FDC_CMD)		;025b	db 10		. .
	bit 0,a			;025d	cb 47		. G
	jr nz,wait_restore_done		;025f	20 fa		  .
; Check for head-load error (bit 2)
	bit 2,a			;0261	cb 57		. W
	jr nz,restore_settle		;0263	20 02		  . ; error: skip OK marker
	ld a,0ffh		;0265	3e ff		> . ; success marker
; Head settle delay (~1000 iterations)
restore_settle:
	push af			;0267	f5		.
	push hl			;0268	e5		.
	ld hl,003e8h		;0269	21 e8 03	! . . ; 1000 iterations
settle_delay_loop:
	dec hl			;026c	2b		+
	ld a,h			;026d	7c		|
	or l			;026e	b5		.
	jr nz,settle_delay_loop		;026f	20 fb		  .
	pop hl			;0271	e1		.
	pop af			;0272	f1		.
	ret			;0273	c9		.
; ============================================================
; fdc_seek_read — Seek FDC head to target track
; Uses read-address-mark to discover current head position,
; then issues a seek command to the target track. If read-
; address fails (CRC or record-not-found), steps in and
; retries (up to 2 attempts). On complete failure, restores
; to track 0 and starts seek over.
; Returns: Z = success, NZ = error
; ============================================================
fdc_seek_read:
	ld a,FDC_CMD_FORCE_INT		;0274	3e d0		> . ; abort any pending cmd
	call fdc_send_cmd	;0276	cd ca 02	. . .
; Wait for FDC to go idle
wait_fdc_idle:
	in a,(PORT_FDC_CMD)		;0279	db 10		. .
	bit 0,a			;027b	cb 47		. G
	jr nz,wait_fdc_idle		;027d	20 fa		  .
	push bc			;027f	c5		.
	ld b,002h		;0280	06 02		. . ; 2 attempts before full restore
; Issue read-address to discover current physical track
read_addr_mark:
	ld a,FDC_CMD_READ_ADDR		;0282	3e c4		> .
	call fdc_send_cmd	;0284	cd ca 02	. . .
wait_addr_done:
	in a,(PORT_FDC_CMD)		;0287	db 10		. .
	bit 0,a			;0289	cb 47		. G
	jr z,fdc_check_status	;028b	28 1b		( . ; command complete
	jr wait_addr_done		;028d	18 f8		. . ; still busy
; Read-address failed — step in one track and retry
fdc_step_in:
	ld a,FDC_CMD_FORCE_INT		;028f	3e d0		> .
	call fdc_send_cmd	;0291	cd ca 02	. . .
	ld a,FDC_CMD_STEP_IN		;0294	3e 5f		> _
	call fdc_send_cmd	;0296	cd ca 02	. . .
wait_step_done:
	in a,(PORT_FDC_CMD)		;0299	db 10		. .
	bit 0,a			;029b	cb 47		. G
	jr nz,wait_step_done		;029d	20 fa		  .
	dec b			;029f	05		. ; decrement attempt counter
	jr nz,read_addr_mark		;02a0	20 e0		  . ; try read-address again
; Both attempts failed — full restore and start over
	call fdc_restore	;02a2	cd 51 02	. Q .
	pop bc			;02a5	c1		.
	jr fdc_seek_read	;02a6	18 cc		. .
; Check read-address result: bits 4,3 = record-not-found, CRC error
fdc_check_status:
	bit 4,a			;02a8	cb 67		. g ; record not found?
	jr nz,fdc_step_in	;02aa	20 e3		  . ; try stepping in
	bit 3,a			;02ac	cb 5f		. _ ; CRC error?
	jr nz,fdc_step_in	;02ae	20 df		  . ; try stepping in
; Read-address OK — now seek to target track
	pop bc			;02b0	c1		.
	in a,(PORT_FDC_SECTOR)		;02b1	db 12		. . ; read-address returns track in sector reg
	out (PORT_FDC_TRACK),a		;02b3	d3 11		. . ; set FDC track to current position
	ld a,(fdc_track)		;02b5	3a f0 bf	: . . ; target track
	out (PORT_FDC_DATA),a		;02b8	d3 13		. . ; target goes in data reg for seek
	ld a,FDC_CMD_SEEK		;02ba	3e 1f		> .
	call fdc_send_cmd	;02bc	cd ca 02	. . .
; Wait for seek to complete
wait_seek_done:
	in a,(PORT_FDC_CMD)		;02bf	db 10		. .
	bit 0,a			;02c1	cb 47		. G
	jr nz,wait_seek_done		;02c3	20 fa		  .
; Check for seek errors (CRC + seek error bits)
	and FDC_STAT_ERR_SEEK		;02c5	e6 18		. .
	jr nz,fdc_seek_read	;02c7	20 ab		  . ; seek error → retry
	ret			;02c9	c9		. ; Z set = success
; ============================================================
; fdc_send_cmd — Send command byte to FDC with post-delay
; Entry: A = command byte
; Writes to FDC command port, then burns ~64 cycles for the
; FDC to latch the command before returning.
; ============================================================
fdc_send_cmd:
	out (PORT_FDC_CMD),a		;02ca	d3 10		. . ; issue command
	ld a,040h		;02cc	3e 40		> @ ; 64 iterations
cmd_delay_loop:
	dec a			;02ce	3d		=
	ret z			;02cf	c8		. ; done when counter hits 0
	jr cmd_delay_loop		;02d0	18 fc		. .
; ============================================================
; fdc_read_sector — Read one sector into sector_buf via NMI
; Sets FDC sector register and side flag, issues read-sector
; command. Data transfer happens byte-by-byte via NMI handler.
; Waits for completion and checks for read errors.
; Returns: A = 1 if success, A = 0 if error
; ============================================================
fdc_read_sector:
	ld a,(fdc_sector)		;02d2	3a ef bf	: . .
	out (PORT_FDC_SECTOR),a		;02d5	d3 12		. . ; set sector number
	ld hl,sector_buf		;02d7	21 e9 be	! . . ; NMI writes data here via (HL)
	ld b,FDC_CMD_READ_SEC		;02da	06 88		. . ; read-sector command
	ld a,(fdc_side)		;02dc	3a f4 bf	: . .
	or b			;02df	b0		. ; OR side flag into command
	call fdc_send_cmd	;02e0	cd ca 02	. . . ; start the read
; Wait for read to complete (NMI transfers data in background)
wait_read_done:
	in a,(PORT_FDC_CMD)		;02e3	db 10		. .
	bit 0,a			;02e5	cb 47		. G
	jr nz,wait_read_done		;02e7	20 fa		  .
; Check for read errors (lost data, CRC, record not found)
	and FDC_STAT_ERR_READ		;02e9	e6 3c		. <
	ld a,000h		;02eb	3e 00		> .
	ret nz			;02ed	c0		. ; error: return 0
	ld a,001h		;02ee	3e 01		> . ; success: return 1
fdc_io_last:
	ret			;02f0	c9		.
; ============================================================
; parse_hex — Parse hex number from keyboard input
; Reads hex digits interactively, building a 16-bit value.
; Accepts 0-9, A-F (uppercase). Stops on any non-hex char
; (the terminator is returned in C for the caller to check).
; Returns: DE = parsed value, B = digit count, C = terminator
; ============================================================
parse_hex:

; BLOCK 'hex_parser' (start 0x02f1 end 0x0318)
hex_parser_start:
	ld de,reset		;02f1	11 00 00	. . . ; DE = 0 (accumulator)
	ld b,e			;02f4	43		C ; B = 0 (digit count)
hex_next_char:
	call get_char_echo	;02f5	cd c9 04	. . . ; read and echo one character
	ld a,c			;02f8	79		y
	sub '0'			;02f9	d6 30		. 0 ; convert ASCII to value
	cp LF			;02fb	fe 0a		. . ; value < 10?
	jr c,hex_digit_valid		;02fd	38 05		8 . ; yes, 0-9 is valid
	cp 011h			;02ff	fe 11		. . ; gap between '9' and 'A'?
	ret c			;0301	d8		. ; not a hex digit, return
	sub 007h		;0302	d6 07		. . ; adjust A-F range
hex_digit_valid:
	cp 010h			;0304	fe 10		. . ; value >= 16?
	ccf			;0306	3f		? ; complement carry for ret c test
	ret c			;0307	d8		. ; not a hex digit
	inc b			;0308	04		. ; count this digit
; Shift existing value left 4 bits and add new digit
	ld l,a			;0309	6f		o ; L = new nibble value
	ld h,000h		;030a	26 00		& .
	ld a,010h		;030c	3e 10		> . ; multiply DE by 16 via repeated add
hex_shift_loop:
	add hl,de		;030e	19		. ; HL += DE (16 times = DE * 16 + nibble)
	jp c,cmd_error		;030f	da cb 00	. . . ; overflow
	dec a			;0312	3d		=
	jr nz,hex_shift_loop		;0313	20 f9		  .
	ex de,hl		;0315	eb		. ; DE = updated value
	jr hex_next_char		;0316	18 dd		. . ; read next digit
; ============================================================
; cmd_star — Transparent terminal mode ('*' command)
; Echoes keystrokes directly to screen in a tight loop.
; Press ESC to exit back to the monitor prompt.
; ============================================================
cmd_star:

; BLOCK 'cmd_star_cr_go' (start 0x0318 end 0x034f)
cmd_star_cr_go_start:
	call get_kbd_char	;0318	cd 77 04	. w .
	cp ESC			;031b	fe 1b		. . ; ESC exits to monitor
	jp z,monitor_prompt	;031d	ca 93 00	. . .
	ld c,a			;0320	4f		O
	call putchar		;0321	cd cd 04	. . .
	jr cmd_star		;0324	18 f2		. .
; cmd_cr_boot — Default boot on bare Enter key
; Boots from drive 0 ('B'), starting at sector 0x0080
cmd_cr_boot:
	ld hl,00080h		;0326	21 80 00	! . . ; default start sector
	ld a,'B'		;0329	3e 42		> B
	ex de,hl		;032b	eb		.
	ex af,af'		;032c	08		.
	jp boot_floppy		;032d	c3 f6 00	. . .
; cmd_boot_default — 'B' with no args: drive 0, sector 1
cmd_boot_default:
	ld a,c			;0330	79		y
	cp CR			;0331	fe 0d		. .
	jp nz,cmd_error		;0333	c2 cb 00	. . .
	ld b,000h		;0336	06 00		. . ; drive 0
	ld de,reset+1		;0338	11 01 00	. . . ; sector 1
	jp boot_floppy		;033b	c3 f6 00	. . .
; ============================================================
; cmd_go — Execute code at address ('G' command)
; Parses hex address, does bank-switch, jumps to it.
; ============================================================
cmd_go:
	call parse_hex		;033e	cd f1 02	. . .
	dec b			;0341	05		.
	jp m,cmd_error		;0342	fa cb 00	. . .
	ld a,c			;0345	79		y
	cp CR			;0346	fe 0d		. .
	jp nz,cmd_error		;0348	c2 cb 00	. . .
	ex de,hl		;034b	eb		.
	jp exec_loaded_code	;034c	c3 9d 01	. . .
; ============================================================
; cmd_memory — Memory inspection submenu ('M' command)
; Sub-commands:
;   D<start>,<end>  — hex dump memory range (16 bytes/line)
;   M<addr>         — modify memory byte-by-byte ('.' to quit)
;   I<port>         — read and display I/O port value
;   O<port>,<value> — write byte to I/O port
;   G<addr>         — execute at address
;   R               — return to main prompt
; ============================================================
cmd_memory:

; BLOCK 'cmd_memory' (start 0x034f end 0x042c)
cmd_memory_start:
; Print sub-prompt and read sub-command character
	call print_crlf		;034f	cd 4d 04	. M .
	ld c,004h		;0352	0e 04		. . ; sub-prompt character
	call putchar		;0354	cd cd 04	. . .
	call get_char_echo	;0357	cd c9 04	. . .
	push bc			;035a	c5		.
	ld c,':'		;035b	0e 3a		. :
	call putchar		;035d	cd cd 04	. . .
	pop bc			;0360	c1		.
; Dispatch sub-command letter
	ld a,c			;0361	79		y
	cp 'R'			;0362	fe 52		. R ; return to main prompt
	jp z,monitor_prompt	;0364	ca 93 00	. . .
	cp 'G'			;0367	fe 47		. G
	jr z,cmd_go		;0369	28 d3		( .
	cp 'D'			;036b	fe 44		. D ; dump
	jr z,cmd_mem_dispatch	;036d	28 13		( .
	cp 'M'			;036f	fe 4d		. M ; modify
	jr z,cmd_mem_dispatch	;0371	28 0f		( .
	cp 'I'			;0373	fe 49		. I ; in port
	jr z,cmd_mem_dispatch	;0375	28 0b		( .
	cp 'O'			;0377	fe 4f		. O ; out port
	jr z,cmd_mem_dispatch	;0379	28 07		( .
cmd_mem_error:
	ld c,BEL		;037b	0e 06		. .
	call putchar		;037d	cd cd 04	. . .
	jr cmd_memory		;0380	18 cd		. .
; Parse first hex argument, then dispatch by saved command letter
cmd_mem_dispatch:
	ex af,af'		;0382	08		. ; save command letter
	call parse_hex		;0383	cd f1 02	. . . ; DE = first arg
	dec b			;0386	05		.
	jp m,cmd_memory		;0387	fa 4f 03	. O . ; no digits entered
	ex af,af'		;038a	08		. ; restore command letter
	cp 'M'			;038b	fe 4d		. M
	jr z,cmd_mem_modify	;038d	28 71		( q
	cp 'I'			;038f	fe 49		. I
	jr z,cmd_mem_inport	;0391	28 4d		( M
; D and O commands need a second argument after comma
	ex af,af'		;0393	08		.
	ld a,c			;0394	79		y ; check terminator was comma
	cp ','			;0395	fe 2c		. ,
	jr nz,cmd_mem_error		;0397	20 e2		  .
	push de			;0399	d5		. ; save first arg (start addr)
	call parse_hex		;039a	cd f1 02	. . . ; DE = second arg (end addr)
	pop hl			;039d	e1		. ; HL = start addr
	dec b			;039e	05		.
	jp m,cmd_mem_error		;039f	fa 7b 03	. { .
	ld a,c			;03a2	79		y
	cp CR			;03a3	fe 0d		. .
	jr nz,cmd_mem_error		;03a5	20 d4		  .
	ex af,af'		;03a7	08		.
	cp 'O'			;03a8	fe 4f		. O
	jr z,cmd_mem_outport	;03aa	28 48		( H
; Validate end > start, then set up dump loop
	call compare_hl_de	;03ac	cd 47 04	. G .
	jr nc,cmd_mem_error		;03af	30 ca		0 . ; start >= end
	ex de,hl		;03b1	eb		. ; DE = current addr, HL(stack) = end
	push hl			;03b2	e5		.
; --- Hex dump: print 16 bytes per line in 4 groups of 4 ---
cmd_mem_dump:
	call print_crlf		;03b3	cd 4d 04	. M .
dump_print_addr:
	call print_address	;03b6	cd 65 04	. e . ; print current address
	ld a,004h		;03b9	3e 04		> . ; 4 groups per line
	ex af,af'		;03bb	08		.
dump_group:
	ld b,004h		;03bc	06 04		. . ; 4 bytes per group
dump_byte:
	ld a,(de)		;03be	1a		. ; read memory byte
	call print_hex_byte	;03bf	cd 51 04	. Q .
	inc de			;03c2	13		. ; next address
	pop hl			;03c3	e1		. ; end address
	call compare_hl_de	;03c4	cd 47 04	. G . ; reached end?
	jp z,cmd_memory		;03c7	ca 4f 03	. O . ; done
	push hl			;03ca	e5		.
	ld a,e			;03cb	7b		{
	or a			;03cc	b7		.
	jr z,cmd_mem_dump	;03cd	28 e4		( . ; page boundary → new line
	ld c,' '		;03cf	0e 20		.  
	call putchar		;03d1	cd cd 04	. . .
	djnz dump_byte		;03d4	10 e8		. . ; next byte in group
	call putchar		;03d6	cd cd 04	. . . ; extra space between groups
	ex af,af'		;03d9	08		.
	dec a			;03da	3d		= ; decrement group counter
	jr z,dump_print_addr		;03db	28 d9		( . ; 4 groups done → new line
	ex af,af'		;03dd	08		.
	jr dump_group		;03de	18 dc		. . ; next group
; cmd_mem_inport — Read and display I/O port value
cmd_mem_inport:
	ld a,c			;03e0	79		y
	cp CR			;03e1	fe 0d		. .
	jp nz,cmd_mem_error		;03e3	c2 7b 03	. { .
	call print_address	;03e6	cd 65 04	. e .
	ld b,d			;03e9	42		B
	ld c,e			;03ea	4b		K
	in d,(c)		;03eb	ed 50		. P
	ld a,d			;03ed	7a		z
	call print_hex_byte	;03ee	cd 51 04	. Q .
	jp cmd_memory		;03f1	c3 4f 03	. O .
; cmd_mem_outport — Write value to I/O port
cmd_mem_outport:
	ld a,d			;03f4	7a		z
	or a			;03f5	b7		.
	jp nz,cmd_mem_error		;03f6	c2 7b 03	. { .
	ld b,h			;03f9	44		D
	ld c,l			;03fa	4d		M
	out (c),e		;03fb	ed 59		. Y
	jp cmd_memory		;03fd	c3 4f 03	. O .
; cmd_mem_modify — Modify memory byte-by-byte
; Shows current value, reads new hex value, writes it.
; Enter '.' to stop, CR to advance without changing.
cmd_mem_modify:
	ld a,c			;0400	79		y
	cp CR			;0401	fe 0d		. .
	jp nz,cmd_mem_error		;0403	c2 7b 03	. { .
mem_modify_loop:
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
	jp nz,cmd_mem_error		;0420	c2 7b 03	. { .
	dec b			;0423	05		.
	jp m,mem_modify_next		;0424	fa 28 04	. ( .
	ld (hl),e		;0427	73		s
mem_modify_next:
	inc hl			;0428	23		#
	ex de,hl		;0429	eb		.
	jr mem_modify_loop		;042a	18 da		. .
; ============================================================
; nibble_to_ascii — Convert low nibble of A to ASCII hex char
; Uses the classic DAA trick: A + 0x90 + DAA + 0x40 + DAA
; converts 0x0-0xF → '0'-'9', 'A'-'F'.
; Returns: A = ASCII hex character
; ============================================================
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
; compare_hl_de — Compare HL with DE (sets Z if equal)
compare_hl_de:
	ld a,h			;0447	7c		|
	cp d			;0448	ba		.
	ret nz			;0449	c0		.
	ld a,l			;044a	7d		}
	cp e			;044b	bb		.
	ret			;044c	c9		.
; print_crlf — Output carriage return + line feed
print_crlf:
	ld c,CR			;044d	0e 0d		. .
	jr putchar		;044f	18 7c		. |
; ============================================================
; print_hex_byte — Print byte in A as two hex digits
; Converts low nibble first (saves to H), then shifts high
; nibble down and prints high digit first, then low digit.
; ============================================================
print_hex_byte:
	push af			;0451	f5		.
	call nibble_to_ascii	;0452	cd 2c 04	. , . ; convert low nibble
	ld h,a			;0455	67		g ; save low digit
	pop af			;0456	f1		.
; Shift high nibble into low position
	rra			;0457	1f		.
	rra			;0458	1f		.
	rra			;0459	1f		.
	rra			;045a	1f		.
	call nibble_to_ascii	;045b	cd 2c 04	. , . ; convert high nibble
	ld c,a			;045e	4f		O
	call putchar		;045f	cd cd 04	. . . ; print high digit first
	ld c,h			;0462	4c		L
	jr putchar		;0463	18 68		. h ; then low digit
; print_address — Print CRLF, then DE as 4 hex digits + space
print_address:
	call print_crlf		;0465	cd 4d 04	. M .
	ld a,d			;0468	7a		z
	call print_hex_byte	;0469	cd 51 04	. Q .
	ld a,e			;046c	7b		{
	call print_hex_byte	;046d	cd 51 04	. Q .
	ld c,' '		;0470	0e 20		.  
	call putchar		;0472	cd cd 04	. . .
	jr putchar		;0475	18 56		. V
; ============================================================
; get_kbd_char — Read one key from keyboard with auto-repeat
; Polls SAA5070 (LUCY) keyboard status register. Handles
; three states:
;   - Key released (bit 1): reset debounce, check if new key
;     is simultaneously pressed (bit 0)
;   - First press: wait for data ready, read KR3600 ASCII
;   - Repeat: if key still held, auto-repeat after delay;
;     if released during delay, return last key
; Returns: A = 7-bit ASCII key code
; ============================================================
get_kbd_char:

; BLOCK 'kbd_driver' (start 0x0477 end 0x04c9)
kbd_driver_start:
; Poll LUCY register 7 for keyboard status
	ld a,LUCY_REG_KBD		;0477	3e 07		> .
	out (PORT_LUCY_REG),a		;0479	d3 60		. `
	in a,(PORT_LUCY_DATA)		;047b	db 70		. p
; Bit 1 = key released event
	bit 1,a			;047d	cb 4f		. O
	jr z,kbd_check_repeat		;047f	28 12		( . ; no release → check repeat
; Key was released — reset debounce state
	push af			;0481	f5		.
	xor a			;0482	af		.
	ld (kbd_state),a		;0483	32 fc bf	2 . . ; state = no key held
	pop af			;0486	f1		.
; Check if a new key is also pressed right now (bit 0)
	bit 0,a			;0487	cb 47		. G
	jr z,get_kbd_char	;0489	28 ec		( . ; no key → keep polling
; Key pressed — read the scancode from KR3600
read_kbd_data:
	in a,(PORT_KBD_DATA)		;048b	db 30		. 0
	and KBD_DATA_MASK		;048d	e6 7f		. . ; mask to 7-bit ASCII
	ld (kbd_last),a		;048f	32 fd bf	2 . . ; save for auto-repeat
	ret			;0492	c9		.
; No release event — check if we're in repeat mode
kbd_check_repeat:
	ld a,(kbd_state)		;0493	3a fc bf	: . .
	or a			;0496	b7		.
	jr z,kbd_first_press		;0497	28 14		( . ; first time seeing this key
; In repeat mode — check if key is still pressed
	in a,(PORT_LUCY_DATA)		;0499	db 70		. p
	bit 0,a			;049b	cb 47		. G
	jr nz,read_kbd_data		;049d	20 ec		  . ; still pressed → read fresh data
; Key released during repeat — delay, then return last key
	push bc			;049f	c5		.
	ld bc,00a00h		;04a0	01 00 0a	. . . ; ~2560 iteration delay
kbd_repeat_delay:
	dec bc			;04a3	0b		.
	ld a,b			;04a4	78		x
	or c			;04a5	b1		.
	jr nz,kbd_repeat_delay		;04a6	20 fb		  .
	pop bc			;04a8	c1		.
kbd_return_last:
	ld a,(kbd_last)		;04a9	3a fd bf	: . .
	ret			;04ac	c9		.
; First key press — mark state and wait for key data ready
kbd_first_press:
	ld a,001h		;04ad	3e 01		> .
	ld (kbd_state),a		;04af	32 fc bf	2 . . ; state = key held
kbd_wait_key:
	in a,(PORT_LUCY_DATA)		;04b2	db 70		. p
	bit 0,a			;04b4	cb 47		. G
	jr z,kbd_wait_key		;04b6	28 fa		( . ; wait for data ready
	in a,(PORT_KBD_DATA)		;04b8	db 30		. 0 ; read KR3600 scancode
	ld (kbd_last),a		;04ba	32 fd bf	2 . .
; Check if key was already released before we read it
	in a,(PORT_LUCY_DATA)		;04bd	db 70		. p
	bit 1,a			;04bf	cb 4f		. O
	jr z,kbd_return_last		;04c1	28 e6		( . ; still held → return it
; Key released between press and read — reset state
	xor a			;04c3	af		.
	ld (kbd_state),a		;04c4	32 fc bf	2 . . ; back to idle
	jr kbd_return_last		;04c7	18 e0		. .
; get_char_echo — Read key and echo to display
; Calls get_kbd_char, then falls through to putchar.
get_char_echo:

; BLOCK 'char_io_video' (start 0x04c9 end 0x05fa)
char_io_video_start:
	call get_kbd_char	;04c9	cd 77 04	. w .
	ld c,a			;04cc	4f		O ; C = key for putchar
; ============================================================
; putchar — Output character to video display
; Entry: C = character to display
; Handles CR (new line + reset column), LF (advance row),
; and printable characters (write to VRAM + advance cursor).
; Saves/restores all registers. Updates cursor on exit.
; ============================================================
putchar:
	push bc			;04cd	c5		.
	push de			;04ce	d5		.
	push hl			;04cf	e5		.
	ld a,c			;04d0	79		y
	cp CR			;04d1	fe 0d		. .
	jr z,handle_cr		;04d3	28 19		( .
	cp LF			;04d5	fe 0a		. .
	jr z,handle_lf		;04d7	28 25		( %
; Printable character — write to VRAM and move cursor right
	ld (vram_char),a		;04d9	32 f9 bf	2 . .
	ld a,ATTR_NORMAL		;04dc	3e 0e		> .
	ld (vram_attr),a		;04de	32 fa bf	2 . .
	call write_vram		;04e1	cd a5 05	. . .
	call advance_cursor	;04e4	cd 06 05	. . .
; Restore registers and show cursor at new position
putchar_done:
	call cursor_off		;04e7	cd dc 05	. . . ; display cursor block
	pop hl			;04ea	e1		.
	pop de			;04eb	d1		.
	pop bc			;04ec	c1		.
	ret			;04ed	c9		.
; CR: erase cursor, advance row, reset column to 0
handle_cr:
	call cursor_on		;04ee	cd ec 05	. . . ; erase old cursor
	call advance_row	;04f1	cd 1f 05	. . .
	call reset_column	;04f4	cd f9 04	. . .
	jr putchar_done		;04f7	18 ee		. .
reset_column:
	xor a			;04f9	af		.
	ld (cursor_col),a		;04fa	32 f8 bf	2 . .
	ret			;04fd	c9		.
; LF: erase cursor, advance row (column unchanged)
handle_lf:
	call cursor_on		;04fe	cd ec 05	. . .
	call advance_row	;0501	cd 1f 05	. . .
	jr putchar_done		;0504	18 e1		. .
; ============================================================
; advance_cursor — Move cursor right by one character position
; The SAA5120 uses split-column addressing: columns 0-39 in
; the left half (bit 7 clear), 40-79 in the right half (bit 7
; set). Advances within a half, toggles between halves at
; the boundary, and wraps to next row at column 80.
; ============================================================
advance_cursor:
	ld a,(cursor_col)		;0506	3a f8 bf	: . .
	cp COL_LAST			;0509	fe a7		. . ; at last column?
	jr z,col_overflow		;050b	28 0b		( . ; yes → wrap to next line
	bit 7,a			;050d	cb 7f		. . ; in right half?
	jr z,toggle_half		;050f	28 01		( . ; no → toggle to right
	inc a			;0511	3c		< ; right half: also increment
toggle_half:
	xor COL_HALF		;0512	ee 80		. . ; flip half-select bit
	ld (cursor_col),a		;0514	32 f8 bf	2 . .
	ret			;0517	c9		.
; Past last column — wrap to column 0 of next row
col_overflow:
	call reset_column	;0518	cd f9 04	. . .
	call advance_row	;051b	cd 1f 05	. . .
	ret			;051e	c9		.
; advance_row — Move cursor down one row, scrolling if at bottom
advance_row:
	ld a,(cursor_row)		;051f	3a f7 bf	: . .
	cp LAST_ROW			;0522	fe 18		. . ; at row 24 (last row)?
	jr z,scroll_screen	;0524	28 08		( . ; yes → scroll
	ld a,(cursor_row)		;0526	3a f7 bf	: . .
	inc a			;0529	3c		< ; simply move down one row
	ld (cursor_row),a		;052a	32 f7 bf	2 . .
	ret			;052d	c9		.
; ============================================================
; scroll_screen — Scroll display up one line
; Increments the SAA5120 hardware scroll register (offset of
; first visible row), wraps at row 25, then clears the newly
; exposed bottom row with spaces. This is zero-copy hardware
; scrolling — no data is moved in VRAM.
; ============================================================
scroll_screen:
	ld a,(cursor_col)		;052e	3a f8 bf	: . .
	push af			;0531	f5		. ; save cursor column
; Increment scroll offset and program hardware
	ld a,(scroll_off)		;0532	3a fb bf	: . .
	inc a			;0535	3c		<
	ld (scroll_off),a		;0536	32 fb bf	2 . .
	cp SCREEN_ROWS		;0539	fe 19		. . ; past row 25?
	jr z,scroll_wrap		;053b	28 18		( . ; yes → wrap to 0
	out (PORT_SCROLL_ALT),a		;053d	d3 04		. . ; set scroll register
; Clear the newly exposed bottom row
clear_new_row:
	xor a			;053f	af		.
	ld (cursor_col),a		;0540	32 f8 bf	2 . .
	ld a,' '		;0543	3e 20		>  
	ld (vram_char),a		;0545	32 f9 bf	2 . .
	ld a,ATTR_NORMAL		;0548	3e 0e		> .
	ld (vram_attr),a		;054a	32 fa bf	2 . .
	call fill_row_spaces	;054d	cd 87 05	. . . ; fill row with spaces
	pop af			;0550	f1		.
	ld (cursor_col),a		;0551	32 f8 bf	2 . . ; restore cursor column
	ret			;0554	c9		.
; Scroll offset wrapped past 25 — reset to 0
scroll_wrap:
	xor a			;0555	af		.
	ld (scroll_off),a		;0556	32 fb bf	2 . .
	out (PORT_SCROLL),a		;0559	d3 03		. .
	jr clear_new_row		;055b	18 e2		. .
; ============================================================
; clear_screen — Clear entire 25×80 display
; Fills all rows with spaces + normal attribute, resets
; scroll offset and column, updates cursor.
; ============================================================
clear_screen:
	xor a			;055d	af		.
clear_row_loop:
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
	jr nz,clear_row_loop		;0578	20 e4		  .
	xor a			;057a	af		.
	ld (cursor_col),a		;057b	32 f8 bf	2 . .
	out (PORT_SCROLL),a		;057e	d3 03		. .
	ld (scroll_off),a		;0580	32 fb bf	2 . .
	call cursor_off		;0583	cd dc 05	. . .
	ret			;0586	c9		.
; ============================================================
; fill_row_spaces — Fill current row from current column onward
; Handles SAA5120 split-column addressing: writes left half
; (cols 0-39), then switches to right half (0x80-0xA7).
; Returns when column wraps past 0xA7.
; ============================================================
fill_row_spaces:
	call write_vram		;0587	cd a5 05	. . . ; write space at current col
	ld a,(cursor_col)		;058a	3a f8 bf	: . .
	inc a			;058d	3c		<
	ld (cursor_col),a		;058e	32 f8 bf	2 . .
	bit 7,a			;0591	cb 7f		. . ; in right half?
	jr nz,fill_check_done		;0593	20 0b		  . ; yes → check wrap
	cp COL_HALF_COUNT		;0595	fe 28		. ( ; reached col 40?
	jr nz,fill_row_spaces	;0597	20 ee		  . ; no → keep going
; Switch to right half (bit 7 set, counter at 0x80)
	ld a,COL_HALF		;0599	3e 80		> .
	ld (cursor_col),a		;059b	32 f8 bf	2 . .
	jr fill_row_spaces	;059e	18 e7		. .
fill_check_done:
	cp COL_WRAP			;05a0	fe a8		. . ; past last right-half col?
	jr nz,fill_row_spaces	;05a2	20 e3		  . ; no → keep going
	ret			;05a4	c9		. ; row complete
; ============================================================
; write_vram — Write character + attribute to video RAM
; Reads cursor position, character, and attribute from RAM
; variables, then programs the SAA5120 via I/O ports. Waits
; for LUCY video sync (blanking interval) before writing to
; avoid display glitches. The SAA5120 has a peculiar write
; protocol: two character writes (with/without strobe bit)
; paired with two attribute writes.
; ============================================================
write_vram:
; Load cursor_row, cursor_col, vram_char, vram_attr into regs
	ld hl,cursor_row		;05a5	21 f7 bf	! . .
	ld a,(hl)		;05a8	7e		~
	out (PORT_VIDEO_ROW),a		;05a9	d3 00		. . ; set row address
	inc hl			;05ab	23		#
	ld d,(hl)		;05ac	56		V ; D = column (without strobe)
	ld a,(hl)		;05ad	7e		~
	or VID_WRITE_STROBE		;05ae	f6 40		. @ ; set bit 6 for write
	ld b,a			;05b0	47		G ; B = column with write strobe
	inc hl			;05b1	23		#
	ld c,(hl)		;05b2	4e		N ; C = character code
	inc hl			;05b3	23		#
	ld e,(hl)		;05b4	5e		^ ; E = attribute
; Wait for video blanking interval (bit 0 of LUCY scan reg)
	ld hl,sys_flags		;05b5	21 f3 bf	! . .
	set 5,(hl)		;05b8	cb ee		. . ; mark sync-pending in flags
	ld a,LUCY_REG_SCAN		;05ba	3e 06		> .
	out (PORT_LUCY_REG),a		;05bc	d3 60		. `
wait_video_sync:
	in a,(PORT_LUCY_DATA)		;05be	db 70		. p
	bit 0,a			;05c0	cb 47		. G
	jr z,wait_video_sync		;05c2	28 fa		( . ; wait for blanking
; Critical timing section — write char+attr during blanking
	ld a,(hl)		;05c4	7e		~ ; read sys_flags
	res 5,(hl)		;05c5	cb ae		. . ; clear sync-pending
	ld h,(hl)		;05c7	66		f ; H = original sys_flags (for restore)
	push hl			;05c8	e5		. ; |
	pop hl			;05c9	e1		. ; | small timing delay
	out (PORT_SYS_CTRL),a		;05ca	d3 20		.   ; activate video write mode
; Write: strobe column + char, then plain column + attr
	ld a,b			;05cc	78		x ; column with strobe
	out (PORT_VIDEO_CHAR),a		;05cd	d3 01		. . ; 1st char write (strobe)
	ld a,c			;05cf	79		y
	out (PORT_VIDEO_ATTR),a		;05d0	d3 02		. . ; 1st attr write
	ld a,d			;05d2	7a		z ; column without strobe
	out (PORT_VIDEO_CHAR),a		;05d3	d3 01		. . ; 2nd char write
	ld a,e			;05d5	7b		{
	out (PORT_VIDEO_ATTR),a		;05d6	d3 02		. . ; 2nd attr write
; Restore system control to previous state
	ld a,h			;05d8	7c		|
	out (PORT_SYS_CTRL),a		;05d9	d3 20		.  
	ret			;05db	c9		.
; cursor_off — Show cursor block (inverted attribute)
; Writes space with XOR'd attribute to create visible cursor.
cursor_off:
	ld a,' '		;05dc	3e 20		>  
	ld (vram_char),a		;05de	32 f9 bf	2 . .
	ld a,ATTR_NORMAL		;05e1	3e 0e		> .
	xor ATTR_CURSOR_XOR		;05e3	ee c0		. . ; invert attribute bits
	ld (vram_attr),a		;05e5	32 fa bf	2 . .
	call write_vram		;05e8	cd a5 05	. . .
	ret			;05eb	c9		.
; cursor_on — Remove cursor block (restore normal attribute)
; Writes space with normal attribute to erase cursor.
cursor_on:
	ld a,' '		;05ec	3e 20		>  
	ld (vram_char),a		;05ee	32 f9 bf	2 . .
	ld a,ATTR_NORMAL		;05f1	3e 0e		> .
	ld (vram_attr),a		;05f3	32 fa bf	2 . .
	call write_vram		;05f6	cd a5 05	. . .
char_io_video_last:
	ret			;05f9	c9		.
; ============================================================
; post_start — Power-On Self Test (POST)
; Tests all major hardware subsystems in sequence:
;   1. Video RAM: write/verify pattern to all 25×80 cells
;   2. Main RAM: write/verify 32KB pattern (both banks)
;   3. FDC: verify track/sector/data registers hold values
;   4. Serial: UART loopback test (TX→RX, full byte range)
;   5. Timer: IM1 tick count in calibrated loop (expect 0x23-0x24)
; Error bits accumulate in A' (bit 0=VRAM, 1=RAM, 2=FDC,
; 3=serial, 4=timer). Displays "AUTO-TEST : OK" or error nums.
; ============================================================
post_start:

; BLOCK 'post_code' (start 0x05fa end 0x078a)
post_code_start:
; A' = error accumulator, start at 0
	ex af,af'		;05fa	08		.
	xor a			;05fb	af		. ; clear error bits
	ex af,af'		;05fc	08		.
; Enable system (LED on)
	ld a,SYS_ACTIVE		;05fd	3e 20		>  
	out (PORT_SYS_CTRL),a		;05ff	d3 20		.  
; --- TEST 1: Video RAM ---
; Write incrementing pattern (+0x55) to every cell, then verify
	xor a			;0601	af		. ; start at row 0
	ld c,000h		;0602	0e 00		. . ; C = running test pattern
post_vram_write:
	ld d,000h		;0604	16 00		. . ; D = column counter
	out (PORT_VIDEO_ROW),a		;0606	d3 00		. . ; set row
	ld h,a			;0608	67		g ; save row in H
	ld a,d			;0609	7a		z
post_vram_col_write:
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
	jr nz,post_vram_col_write		;0623	20 e5		  .
	ld a,h			;0625	7c		|
	inc a			;0626	3c		<
	cp SCREEN_ROWS		;0627	fe 19		. .
	jr nz,post_vram_write	;0629	20 d9		  .
; VRAM verify pass: read back and compare
	xor a			;062b	af		.
	ld c,000h		;062c	0e 00		. . ; reset test pattern
post_vram_verify:
	ld d,000h		;062e	16 00		. .
	out (PORT_VIDEO_ROW),a		;0630	d3 00		. .
	ld h,a			;0632	67		g
	ld a,d			;0633	7a		z
post_vram_col_verify:
	rrca			;0634	0f		.
	ld b,a			;0635	47		G
	or VID_WRITE_STROBE		;0636	f6 40		. @
	out (PORT_VIDEO_CHAR),a		;0638	d3 01		. .
	in a,(PORT_VIDEO_ATTR)		;063a	db 02		. .
	cp c			;063c	b9		.
	jr nz,post_vram_fail		;063d	20 22		  "
	add a,TEST_PATTERN		;063f	c6 55		. U
	ld c,a			;0641	4f		O
	xor a			;0642	af		.
	out (PORT_VIDEO_ATTR),a		;0643	d3 02		. .
	ld a,b			;0645	78		x
	out (PORT_VIDEO_CHAR),a		;0646	d3 01		. .
	in a,(PORT_VIDEO_ATTR)		;0648	db 02		. .
	cp c			;064a	b9		.
	jr nz,post_vram_fail		;064b	20 14		  .
	add a,TEST_PATTERN		;064d	c6 55		. U
	ld c,a			;064f	4f		O
	xor a			;0650	af		.
	out (PORT_VIDEO_ATTR),a		;0651	d3 02		. .
	inc d			;0653	14		.
	ld a,d			;0654	7a		z
	cp SCREEN_COLS		;0655	fe 50		. P
	jr nz,post_vram_col_verify		;0657	20 db		  .
	ld a,h			;0659	7c		|
	inc a			;065a	3c		<
	cp SCREEN_ROWS		;065b	fe 19		. .
	jr nz,post_vram_verify	;065d	20 cf		  .
	jr post_ram_test	;065f	18 04		. .
; VRAM test failed — set error bit 0
post_vram_fail:
	ex af,af'		;0661	08		.
	set 0,a			;0662	cb c7		. . ; bit 0 = VRAM error
	ex af,af'		;0664	08		.
; --- TEST 2: Main RAM (32KB at 0x8000) ---
; Write incrementing pattern byte-by-byte, then verify
post_ram_test:
	ld hl,08000h		;0665	21 00 80	! . . ; start address
	ld de,08000h		;0668	11 00 80	. . . ; block size
	jr ram_test_write		;066b	18 04		. .
; Second pass: test bank 2 (re-entered from relocated code)
ram_test_bank2:
	ld a,SYS_RAM_TEST		;066d	3e 60		> ` ; select test bank
	out (PORT_SYS_CTRL),a		;066f	d3 20		.  
ram_test_write:
	ld c,080h		;0671	0e 80		. . ; 128 pages = 32KB
	ld a,000h		;0673	3e 00		> . ; starting pattern
ram_write_page:
	ld b,000h		;0675	06 00		. .
ram_write_byte:
	ld (hl),a		;0677	77		w
	inc hl			;0678	23		#
	add a,TEST_PATTERN		;0679	c6 55		. U
	djnz ram_write_byte		;067b	10 fa		. .
	dec c			;067d	0d		.
	jr nz,ram_write_page		;067e	20 f5		  .
; Verify pass: compare pattern against written data
	ld hl,reset		;0680	21 00 00	! . . ; HL = 0
	add hl,de		;0683	19		. ; HL = start of test region
	ld c,080h		;0684	0e 80		. . ; 128 pages
	ld a,000h		;0686	3e 00		> . ; same starting pattern
ram_verify_page:
	ld b,000h		;0688	06 00		. .
ram_verify_byte:
	cp (hl)			;068a	be		.
	jr nz,ram_verify_fail		;068b	20 0d		  .
	inc hl			;068d	23		#
	add a,TEST_PATTERN		;068e	c6 55		. U
	djnz ram_verify_byte		;0690	10 f8		. .
	dec c			;0692	0d		.
	jr nz,ram_verify_page		;0693	20 f3		  .
; RAM verify OK — copy test code to high RAM for bank 2 test
	ld hl,reset		;0695	21 00 00	! . .
	jr copy_ramtest_high		;0698	18 0f		. .
; RAM verify failed
ram_verify_fail:
	ld a,h			;069a	7c		|
	or l			;069b	b5		.
	jr z,ram_test_exit		;069c	28 04		( . ; HL=0 means bank2 test done
	ex af,af'		;069e	08		.
	set 1,a			;069f	cb cf		. . ; bit 1 = RAM error
	ex af,af'		;06a1	08		.
ram_test_exit:
	ld a,SYS_ACTIVE		;06a2	3e 20		>  
	out (PORT_SYS_CTRL),a		;06a4	d3 20		.   ; restore normal banking
	jp post_fdc_test	;06a6	c3 c0 06	. . .
; Copy ram_test_bank2 routine to 0x8000+ so it can test low RAM
copy_ramtest_high:
	ld hl,ram_test_bank2		;06a9	21 6d 06	! m .
	ld de,0866dh		;06ac	11 6d 86	. m . ; relocated address
	ld bc,irq_handler_last	;06af	01 3c 00	. < . ; size = 0x3C bytes
	ldir			;06b2	ed b0		. . ; copy test code to high RAM
; Patch relocated copy's data pointers
	ld hl,reset		;06b4	21 00 00	! . .
	ld de,reset		;06b7	11 00 00	. . .
	ld (08698h),hl		;06ba	22 98 86	" . .
	jp 0866dh		;06bd	c3 6d 86	. m . ; jump to relocated test
; --- TEST 3: FDC register test ---
; Write incrementing pattern to track/sector/data regs, read back
post_fdc_test:
	ld a,FDC_CMD_FORCE_INT		;06c0	3e d0		> . ; abort any command
	out (PORT_FDC_CMD),a		;06c2	d3 10		. .
	xor a			;06c4	af		. ; start pattern at 0
fdc_test_write:
	ld c,a			;06c5	4f		O ; save track value
	out (PORT_FDC_TRACK),a		;06c6	d3 11		. .
	add a,TEST_PATTERN		;06c8	c6 55		. U
	out (PORT_FDC_SECTOR),a		;06ca	d3 12		. .
	add a,TEST_PATTERN		;06cc	c6 55		. U
	out (PORT_FDC_DATA),a		;06ce	d3 13		. .
	ld b,050h		;06d0	06 50		. P ; settle delay
fdc_test_settle:
	djnz fdc_test_settle		;06d2	10 fe		. .
; Read back and compare each register
	in a,(PORT_FDC_TRACK)		;06d4	db 11		. .
	cp c			;06d6	b9		. ; matches written value?
	jr nz,fdc_test_fail		;06d7	20 1b		  .
	add a,TEST_PATTERN		;06d9	c6 55		. U
	ld c,a			;06db	4f		O
	in a,(PORT_FDC_SECTOR)		;06dc	db 12		. .
	cp c			;06de	b9		.
	jr nz,fdc_test_fail		;06df	20 13		  .
	add a,TEST_PATTERN		;06e1	c6 55		. U
	ld c,a			;06e3	4f		O
	in a,(PORT_FDC_DATA)		;06e4	db 13		. .
	cp c			;06e6	b9		.
	jr nz,fdc_test_fail		;06e7	20 0b		  .
	add a,TEST_PATTERN		;06e9	c6 55		. U
	or a			;06eb	b7		.
	jr z,post_serial_setup	;06ec	28 0e		( .
	ld b,050h		;06ee	06 50		. P
fdc_test_delay:
	djnz fdc_test_delay		;06f0	10 fe		. .
	jr fdc_test_write		;06f2	18 d1		. .
; FDC test failed — set error bit 2
fdc_test_fail:
	ex af,af'		;06f4	08		.
	set 2,a			;06f5	cb d7		. . ; bit 2 = FDC error
	ex af,af'		;06f7	08		.
	ld a,FDC_CMD_FORCE_INT		;06f8	3e d0		> .
	out (PORT_FDC_CMD),a		;06fa	d3 10		. . ; clean up FDC
; --- TEST 4: Serial port (UART loopback) ---
; Configure 2661 UART for 8N1 with loopback, send incrementing
; pattern, verify each byte echoes back correctly.
post_serial_setup:
	ld a,SYS_ACTIVE		;06fc	3e 20		>  
	out (PORT_SYS_CTRL),a		;06fe	d3 20		.  
	ld a,UART_MODE1_VAL		;0700	3e 4e		> N ; 8N1
	out (PORT_UART_MODE),a		;0702	d3 52		. R
	ld a,UART_MODE2_VAL		;0704	3e 3e		> > ; 16x clock
	out (PORT_UART_MODE),a		;0706	d3 52		. R
	ld a,UART_CMD_VAL		;0708	3e a7		> . ; TX/RX enable + loopback
	out (PORT_UART_CMD),a		;070a	d3 53		. S
	ld c,000h		;070c	0e 00		. . ; start pattern at 0
; Send test byte and wait for loopback echo
post_serial_test:
	ld d,0ffh		;070e	16 ff		. . ; timeout counter
wait_uart_txready:
	dec d			;0710	15		.
	jr z,serial_test_fail		;0711	28 1d		( . ; timeout
	in a,(PORT_UART_STATUS)		;0713	db 51		. Q
	and 001h		;0715	e6 01		. . ; TX ready?
	jr z,wait_uart_txready		;0717	28 f7		( .
	ld a,c			;0719	79		y ; send test byte
	out (PORT_UART_DATA),a		;071a	d3 50		. P
; Delay for loopback propagation
	xor a			;071c	af		.
uart_rx_delay:
	dec ix			;071d	dd 2b		. + ; waste time
	dec a			;071f	3d		=
	jr nz,uart_rx_delay		;0720	20 fb		  .
; Read back and compare
	in a,(PORT_UART_DATA)		;0722	db 50		. P
	cp c			;0724	b9		. ; matches sent byte?
	jr nz,serial_test_fail		;0725	20 09		  .
; Advance pattern, loop until full byte range tested
	add a,TEST_PATTERN		;0727	c6 55		. U
	ld c,a			;0729	4f		O
	or a			;072a	b7		. ; wrapped to 0? (all 256 done)
	jr nz,post_serial_test	;072b	20 e1		  .
	jp post_timer_test	;072d	c3 34 07	. 4 . ; serial OK
; Serial test failed — set error bit 3
serial_test_fail:
	ex af,af'		;0730	08		.
	set 3,a			;0731	cb df		. . ; bit 3 = serial error
	ex af,af'		;0733	08		.
; --- TEST 5: Timer/interrupt test ---
; Enable IM1, count ticks during a calibrated loop.
; D is incremented by the IRQ handler each tick.
; Expect 0x23-0x24 ticks; outside range = timer failure.
post_timer_test:
	ld hl,reset		;0734	21 00 00	! . . ; HL = 0 (loop counter)
	ld d,000h		;0737	16 00		. . ; D = tick counter (incremented by IRQ)
	im 1			;0739	ed 56		. V ; use IM1 handler at 0x0038
	ei			;073b	fb		. ; start counting
timer_count_loop:
	dec hl			;073c	2b		+ ; count down from 0 (= 65536 iterations)
	ld a,h			;073d	7c		|
	or l			;073e	b5		.
	jr nz,timer_count_loop		;073f	20 fb		  .
	di			;0741	f3		. ; stop counting
; Check tick count is in expected range [0x23, 0x24]
	ld a,d			;0742	7a		z ; D = number of ticks
	cp 023h			;0743	fe 23		. # ; < 0x23 = too slow
	jr c,timer_test_fail		;0745	38 04		8 .
	cp 025h			;0747	fe 25		. % ; >= 0x25 = too fast
	jr c,post_complete	;0749	38 04		8 . ; in range = OK
; Timer test failed — set error bit 4
timer_test_fail:
	ex af,af'		;074b	08		.
	set 4,a			;074c	cb e7		. . ; bit 4 = timer error
	ex af,af'		;074e	08		.
; --- POST complete — display results ---
post_complete:
	di			;074f	f3		.
	call init_display	;0750	cd 6e 00	. n . ; initialize video
; Print "\r\n AUTO-TEST : "
	ld hl,str_autotest	;0753	21 98 07	! . .
print_autotest_loop:
	ld c,(hl)		;0756	4e		N
	call putchar		;0757	cd cd 04	. . .
	inc hl			;075a	23		#
	ld a,(hl)		;075b	7e		~
	or a			;075c	b7		.
	jr nz,print_autotest_loop		;075d	20 f7		  .
; Check accumulated error bits in A'
	ex af,af'		;075f	08		.
	or a			;0760	b7		.
	jr nz,post_show_errors	;0761	20 0d		  . ; errors found
; All tests passed — print "OK"
	ld c,'O'		;0763	0e 4f		. O
	call putchar		;0765	cd cd 04	. . .
	ld c,'K'		;0768	0e 4b		. K
	call putchar		;076a	cd cd 04	. . .
	jp monitor_prompt	;076d	c3 93 00	. . .
; Errors detected — print each set bit's number (0-7)
post_show_errors:
	ld b,008h		;0770	06 08		. . ; check 8 bits
	ld e,a			;0772	5f		_ ; E = error bitmap
	ld d,'0'		;0773	16 30		. 0 ; D = ASCII digit counter
post_error_loop:
	srl e			;0775	cb 3b		. ; ; shift out lowest bit
	jr c,post_print_error		;0777	38 06		8 . ; bit was set → print it
post_next_error:
	inc d			;0779	14		. ; next digit
	djnz post_error_loop		;077a	10 f9		. .
	jp monitor_prompt	;077c	c3 93 00	. . . ; done → enter monitor
; Print error number on its own line
post_print_error:
	ld c,CR			;077f	0e 0d		. .
	call putchar		;0781	cd cd 04	. . .
	ld c,d			;0784	4a		J ; print digit
	call putchar		;0785	cd cd 04	. . .
	jr post_next_error		;0788	18 ef		. .
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
