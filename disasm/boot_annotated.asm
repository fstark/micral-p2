; z80dasm 1.2.0
; command line: z80dasm -a -l -g 0x0000 -t -b disasm/blocks.def -S disasm/symbols.sym -o disasm/boot_annotated.asm ROMs/MICRAL_P2_CHARGEUR.BIN

	org 00000h

	; --- RAM variables (0xBEE8..0xBFFD) ---
stack_top:          equ	0bee8h          ; Top of stack; also stores boot drive number
sector_buf:         equ	0bee9h          ; 256-byte FDC sector read buffer
boot_cfg:           equ	0beebh          ; Boot config byte (sector_buf+2): bit7=bank1, bit6=bank2
buf_rd_ptr:         equ	0bfe9h          ; Current read pointer into sector buffer
buf_remain:         equ	0bfebh          ; Bytes remaining in current sector (word)
disk_lba:           equ	0bfedh          ; Logical sector counter for sequential reads (word)
fdc_sector:         equ	0bfefh          ; Physical sector number, 1-based (for FD1797)
fdc_track:          equ	0bff0h          ; Current track number
disk_geom:          equ	0bff1h          ; Disk geometry: sectors/track, heads (word)
sys_flags:          equ	0bff3h          ; System flags / port 0x20 shadow (bank select, video sync)
fdc_side:           equ	0bff4h          ; FDC side select: 0x00=side 0, 0x02=side 1
floppy_prm_ptr:     equ	0bff5h          ; Pointer to floppy parameters table (word)
cursor_row:         equ	0bff7h          ; Display cursor row position (0..24)
cursor_col:         equ	0bff8h          ; Display cursor column position (bit7=half-select)
vram_char:          equ	0bff9h          ; Character code for VRAM write (SAA5120)
vram_attr:          equ	0bffah          ; Character attribute for VRAM write (SAA5120)
scroll_off:         equ	0bffbh          ; Scroll offset: first visible row (wraps at 25)
kbd_state:          equ	0bffch          ; Keyboard debounce state (0=first press, 1=repeat)
kbd_last:           equ	0bffdh          ; Last key code read from KR3600
bank_latch:         equ	0ffffh          ; Bank switch latch register

	; --- I/O Ports ---
PORT_VIDEO_ROW:     equ	000h            ; SAA5120 row address
PORT_VIDEO_CHAR:    equ	001h            ; SAA5120 character data (bit 6 = write strobe)
PORT_VIDEO_ATTR:    equ	002h            ; SAA5120 attribute data
PORT_SCROLL:        equ	003h            ; SAA5120 scroll register
PORT_SCROLL_ALT:    equ	004h            ; SAA5120 scroll register (alternate)
PORT_TIMER:         equ	007h            ; CTC timer reload
PORT_FDC_CMD:       equ	010h            ; FD1797 command (W) / status (R)
PORT_FDC_TRACK:     equ	011h            ; FD1797 track register
PORT_FDC_SECTOR:    equ	012h            ; FD1797 sector register
PORT_FDC_DATA:      equ	013h            ; FD1797 data register
PORT_SYS_CTRL:      equ	020h            ; System control (LED/drive/bank)
PORT_KBD_DATA:      equ	030h            ; KR3600 keyboard data (7-bit)
PORT_UART_DATA:     equ	050h            ; 2661 UART data
PORT_UART_STATUS:   equ	051h            ; 2661 UART status
PORT_UART_MODE:     equ	052h            ; 2661 UART mode
PORT_UART_CMD:      equ	053h            ; 2661 UART command
PORT_LUCY_REG:      equ	060h            ; SAA5070 LUCY register select
PORT_LUCY_DATA:     equ	070h            ; SAA5070 LUCY register data

	; --- FD1797 Commands ---
FDC_CMD_RESTORE:    equ	00fh            ; Restore to track 0, verify, 6ms step
FDC_CMD_SEEK:       equ	01fh            ; Seek to track, verify, 6ms step
FDC_CMD_STEP_IN:    equ	05fh            ; Step in, update track reg, 6ms step
FDC_CMD_READ_SEC:   equ	088h            ; Read sector (side bit OR'd separately)
FDC_CMD_READ_ADDR:  equ	0c4h            ; Read address mark
FDC_CMD_FORCE_INT:  equ	0d0h            ; Force interrupt (terminate command)

	; --- FD1797 Status Masks ---
FDC_STAT_ERR_SEEK:  equ	018h            ; Bits 3-4: CRC error + seek error
FDC_STAT_ERR_READ:  equ	03ch            ; Bits 2-5: read error flags

	; --- System Control Register ---
SYS_KBD_ENABLE:     equ	022h            ; Keyboard + drive enable
SYS_ACTIVE:         equ	020h            ; System active / base drive select
SYS_BANK_SWITCH:    equ	040h            ; Bank switch (ROM out, RAM in)
SYS_RAM_TEST:       equ	060h            ; RAM bank for POST testing

	; --- SAA5070 LUCY Register IDs ---
LUCY_REG_SYNC:      equ	003h            ; Sync/configuration register
LUCY_REG_SCAN:      equ	006h            ; Scan control / video sync register
LUCY_REG_KBD:       equ	007h            ; Keyboard status register
LUCY_SYNC_BIT:      equ	020h            ; Bit 5: sync status flag
LUCY_SCAN_ALL:      equ	0ffh            ; Enable all keyboard scan rows

	; --- SAA5120 Video Constants ---
VID_WRITE_STROBE:   equ	040h            ; Bit 6: character write strobe
ATTR_NORMAL:        equ	00eh            ; Normal text attribute (white on black)
ATTR_CURSOR_XOR:    equ	0c0h            ; XOR mask for cursor inversion
COL_HALF:           equ	080h            ; Column half-select (right half)
COL_HALF_COUNT:     equ	028h            ; Columns per half (40)
COL_LAST:           equ	0a7h            ; Last valid column position
COL_WRAP:           equ	0a8h            ; Column wrap sentinel
SCREEN_ROWS:        equ	019h            ; 25 display rows
LAST_ROW:           equ	018h            ; Row 24 (0-based last row)
SCREEN_COLS:        equ	050h            ; 80 display columns

	; --- 2661 UART Configuration ---
UART_MODE1_VAL:     equ	04eh            ; Mode register 1: 8N1
UART_MODE2_VAL:     equ	03eh            ; Mode register 2: 16x clock
UART_CMD_VAL:       equ	0a7h            ; Command: TX/RX enable, RTS, DTR, loopback

	; --- MOS Hex Record Types ---
REC_TYPE_MIN:       equ	0c1h            ; Minimum valid record type
REC_DATA:           equ	0c2h            ; Data record: load bytes to memory
REC_EXEC:           equ	0c6h            ; Execute: jump to loaded code
REC_ERROR:          equ	0d2h            ; Error/abort record
REC_TYPE_MAX:       equ	0dbh            ; Above maximum valid type

	; --- Miscellaneous ---
TEST_PATTERN:       equ	055h            ; POST test pattern increment
KBD_DATA_MASK:      equ	07fh            ; 7-bit keyboard data mask
DD_TRACK_THRESH:    equ	016h            ; Track >= 22: double-density select

	; --- ASCII Control Characters ---
CR:                 equ	00dh            ; Carriage return
LF:                 equ	00ah            ; Line feed
ESC:                equ	01bh            ; Escape
ERR_CHAR:           equ	006h            ; Error indicator character (written to display)

; ============================================================
; reset — Power-on entry point
; Initializes stack, pulses keyboard controller enable,
; configures SAA5070 (LUCY) for video sync and keyboard
; scanning, then jumps to POST.
; ============================================================
reset:
	ld sp,stack_top
		; Pulse keyboard enable on system control port
	ld a,SYS_KBD_ENABLE
	out (PORT_SYS_CTRL),a
		; Short delay for keyboard controller to latch
	ld b,030h
delay_loop:
	djnz delay_loop
		; Deassert keyboard enable pulse
	xor a
	out (PORT_SYS_CTRL),a
		; Select LUCY sync register and trigger sync
	ld a,LUCY_REG_SYNC
	out (PORT_LUCY_REG),a
	ld a,LUCY_SYNC_BIT
	out (PORT_LUCY_DATA),a
		; Poll until LUCY sync completes (bit 5 clears)
wait_lucy_sync:
	ld a,LUCY_REG_SYNC
	out (PORT_LUCY_REG),a
	in a,(PORT_LUCY_DATA)
	and LUCY_SYNC_BIT
	jr nz,wait_lucy_sync
		; Enable all keyboard scan rows (LUCY register 6)
	ld a,LUCY_REG_SCAN
	out (PORT_LUCY_REG),a
	ld a,LUCY_SCAN_ALL
	out (PORT_LUCY_DATA),a
		; Enable keyboard data register (LUCY register 7)
	ld a,LUCY_REG_KBD
	out (PORT_LUCY_REG),a
	ld a,LUCY_SCAN_ALL
	out (PORT_LUCY_DATA),a
		; Hardware init done — jump to Power-On Self Test
	jp post_start
		; Unused padding (RST 0x30 vector area, not used)
	defs 5

; ============================================================
; irq_im1 — IM1 interrupt handler (address 0x0038)
; Called by CTC timer tick. Increments D as a tick counter
; (used by POST timing calibration), reloads timer, returns.
; ============================================================
irq_im1:
	inc d                               ; bump tick counter
	out (PORT_TIMER),a                  ; reload timer
	ei                                  ; re-enable interrupts
	ret
		; Unused vector space (0x003D–0x0065)
	defs 41

; ============================================================
; nmi_handler — Non-maskable interrupt (address 0x0066)
; Triggered by FDC DRQ (data request). Saves AF via shadow
; register, reads one byte from FDC data port into the
; buffer at (HL), advances HL, restores AF and returns.
; Called once per byte during sector reads.
; ============================================================
nmi_handler:
	ex af,af'                           ; save caller's flags
	in a,(PORT_FDC_DATA)                ; read byte from FDC
	ld (hl),a                           ; store into buffer
	inc hl                              ; advance buffer pointer
	ex af,af'                           ; restore caller's flags
	retn

; ============================================================
; init_display — Initialize video display state
; Sets cursor to row 25 (off-screen), clears system flags
; and column, writes '.' at both column halves to prime the
; SAA5120, then clears the full screen.
; ============================================================
init_display:
		; Start cursor off-screen (row 25); first CR will scroll it in
	ld a,SCREEN_ROWS
	ld (cursor_row),a
		; Clear system flags and reset column to 0
	xor a
	ld (sys_flags),a
	ld (cursor_col),a
		; Prime SAA5120: write '.' at left-half column 0
	ld a,001h
	ld (vram_attr),a
	ld a,'.'
	ld (vram_char),a
	call write_vram
		; Same for right-half column 0 (bit 7 = right half)
	ld a,COL_HALF
	ld (cursor_col),a
	call write_vram
		; Fill entire screen with spaces
	call clear_screen
	ret

; ============================================================
; monitor_prompt — Main monitor command loop
; Resets stack, prints "\r\n M P 2 ... " prompt, reads one
; character and dispatches:
;   CR → default boot (drive 0)    B → boot drive,sector
;   *  → transparent terminal      M → memory submenu
;   G  → execute at address
; Invalid commands show error and re-prompt.
; ============================================================
monitor_prompt:
		; Reset stack (clean return from any prior command)
	ld sp,stack_top
		; Clear system flags
	xor a
	ld (sys_flags),a
	ld hl,str_prompt
print_str_loop:
	ld c,(hl)
	call putchar
	inc hl
	ld a,(hl)
	or a
	jr nz,print_str_loop
		; Read command character
	ld b,000h
	call get_char_echo
		; Bare Enter → default boot from drive 0
	ld a,c
	cp CR
	jp z,cmd_cr_boot
		; Not CR — echo ':' separator and match command letter
	ex af,af'
	ld c,':'
	call putchar
	ex af,af'
	cp '*'
	jp z,cmd_star
	cp 'M'
	jp z,cmd_memory
	cp 'B'
	jr z,cmd_boot_parse
	cp 'G'
	jp z,cmd_go
		; No valid command matched — signal error and re-prompt
cmd_error:
	ld c,ERR_CHAR
	call putchar
	jr monitor_prompt
		; Parse 'B' command: B<drive>,<sector>
cmd_boot_parse:
	ex af,af'
		; Read drive number as hex
	call parse_hex
	dec b
	jp m,cmd_boot_default               ; no digits → default
		; Expect comma separator
	ld a,c
	cp ','
	jr nz,cmd_error
		; Validate drive number is 0 or 1
	ld a,d
	or a
	jr nz,cmd_error                     ; high byte must be 0
	or e
	cp 002h
	jr nc,cmd_error                     ; drive >= 2 invalid
		; Save drive number, parse starting sector
	push af
	call parse_hex
	dec b
	ld a,c
	pop bc
	jp m,cmd_error
	cp CR
	jr nz,cmd_error

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
	di                                  ; no interrupts during boot
	ld (disk_lba),de                    ; save starting sector
	ex af,af'
	ld (stack_top),a                    ; save boot drive number
		; Select drive: bit 2 = drive 0, bit 3 = drive 1, bit 4 = motor on
setup_fdc_flags:
	ld hl,sys_flags
	dec b
	jr z,setup_drive1
	set 2,(hl)                          ; drive 0 select
	jr setup_drive_common
setup_drive1:
	set 3,(hl)                          ; drive 1 select
setup_drive_common:
	set 4,(hl)                          ; motor enable
	ld a,(hl)
	out (PORT_SYS_CTRL),a               ; apply drive selection
		; Load floppy parameters table pointer
	ld hl,floppy_params
	ld (floppy_prm_ptr),hl
		; Wait for FDC to become idle (bit 7 = not ready)
wait_drive_ready:
	in a,(PORT_FDC_CMD)
	bit 7,a
	jr nz,wait_drive_ready
		; Long delay for drive motor spin-up / head settle
	ld de,0c000h
settle_delay:
	ex (sp),hl                          ; waste cycles
	ex (sp),hl
	dec de
	ld a,e
	or d
	jr nz,settle_delay
		; Restore head to track 0, then read boot sector
read_boot_sector:
	call fdc_restore
		; Load disk geometry from floppy parameters: sectors/track, heads
	ld hl,(floppy_prm_ptr)
	ld a,(hl)                           ; first byte = sectors/track * 2
	rlca                                ; rotate to get heads in high bits
	inc hl
	ld l,(hl)                           ; second byte
	ld h,a
	ld (disk_geom),hl
		; Start reading from side 0, sector 1
	ld a,000h
	ld (fdc_side),a
	inc a                               ; A = 1
	ld (fdc_sector),a
		; Read the boot sector; retry from restore if error
	call fdc_read_sector
	dec a                               ; A=1 → 0 on success
	jr nz,read_boot_sector              ; retry on error
		; Check boot config byte from sector data (offset +2)
		; Bits 7,6 control which RAM banks to enable at 0xFFFD
	ld a,(boot_cfg)
	ld hl,0fffdh
	ld (hl),000h
	bit 7,a                             ; test bank 1 flag
	jr z,check_bank2
	set 1,(hl)                          ; enable bank 1
check_bank2:
	bit 6,a                             ; test bank 2 flag
	jr z,begin_record_load
	set 2,(hl)                          ; enable bank 2
		; Initialize record loading: zero bytes remaining in buffer
begin_record_load:
	ld hl,reset                         ; HL = 0 (zero)
	ld (buf_remain),hl                  ; buffer empty → force first read
	; --- MOS hex record parsing loop ---
		; Each record: length (C), type (B), optional address (HL), data bytes
parse_record:
	call get_next_byte                  ; read record length
	and a
	jp z,cmd_error                      ; zero length = bad record
	ld c,a                              ; C = byte count for this record
	call get_next_byte                  ; read record type
	ld b,a                              ; B = record type
		; If length >= 3, record has address (H:L) + extra byte
	ld a,c
	cp 003h
	jr c,dispatch_record                ; short record, skip addr
	call get_next_byte                  ; read address high byte
	ld h,a
	call get_next_byte                  ; read address low byte
	ld l,a
	call get_next_byte                  ; read extra byte (discarded)
		; Dispatch on record type
dispatch_record:
	ld a,b
	cp REC_DATA
	jr z,load_data_record               ; 0xC2 = load data
	cp REC_ERROR
	jp z,cmd_error                      ; 0xD2 = error/abort
	cp REC_EXEC
	jr z,exec_loaded_code               ; 0xC6 = run loaded code
		; Unknown record type — must be in valid range or abort
	cp REC_TYPE_MIN
	jp c,cmd_error                      ; below valid range
	cp REC_TYPE_MAX
	jp nc,cmd_error                     ; above valid range
		; Valid but unhandled type — consume remaining bytes and loop
skip_record_bytes:
	call get_next_byte                  ; consume byte (C auto-decrements)
	jr skip_record_bytes                ; loops until C=0 triggers return
		; Load data bytes from record into memory at (HL)
load_data_record:
	call get_next_byte                  ; read next data byte
	ld (hl),a                           ; store at current load address
	inc hl                              ; advance load pointer
	jr load_data_record                 ; loop until C=0 triggers return
		; Execute loaded code via bank-switch trampoline
		; Copies 13-byte stub to RAM that switches ROM out / RAM in
		; (via bank latch at 0xFFFF and port 0x20), then jumps to
		; the loaded program's entry point (HL).
exec_loaded_code:
	di
	push hl                             ; save entry point
	push de
		; Copy trampoline code to RAM (can't run from ROM after bank switch)
	ld hl,trampoline
	ld de,sector_buf
	ld bc,0000dh                        ; 13 bytes
	ldir
	pop de
	pop hl                              ; restore entry point to HL
	jp sector_buf                       ; jump to trampoline in RAM
	; --- Trampoline stub (copied to RAM and executed there) ---
		; Switches ROM out by writing to bank latch, then jumps to HL
trampoline:
	ld a,(sys_flags)
	or SYS_BANK_SWITCH                  ; set bank switch bit
	ld (bank_latch),a                   ; latch: ROM out, RAM in
	ld a,SYS_BANK_SWITCH
	out (PORT_SYS_CTRL),a               ; system control mirrors it
	jp (hl)                             ; jump to loaded program

; ============================================================
; get_next_byte — Read next byte from sequential disk stream
; Manages a 256-byte sector buffer with lazy refill: if the
; buffer is empty, reads the next sector from disk. Tracks
; record byte count in C: when C reaches 0, the record is
; done and control pops back to parse_record.
; Returns: A = next byte, C decremented
; ============================================================
get_next_byte:
		; Check if record has any bytes remaining (C = byte counter)
	inc c                               ; test C without destroying it
	dec c                               ; (inc+dec restores C, sets Z if was 0)
	jr nz,get_byte_body                 ; bytes remaining → read next byte
		; C was 0: record complete — discard return address and loop back
	pop af                              ; discard caller's return address
	inc c                               ; set C=1 so parse_record reads length
	jr parse_record                     ; back to record parsing loop
get_byte_body:
	push hl                             ; save caller's HL
		; Check if sector buffer has unread data
	ld hl,(buf_remain)
	ld a,h
	or l
	jr nz,buf_has_data                  ; still have bytes
		; Buffer exhausted — read next sector from disk
	push hl
	push de
	push bc
	ld hl,(disk_geom)                   ; load geometry (spt, heads)
	ex de,hl                            ; DE = geometry
	ld hl,(disk_lba)                    ; HL = current LBA
	call read_next_sector               ; read sector, returns HL = LBA+1
	ld (disk_lba),hl                    ; save updated LBA
	pop bc
	pop de
	pop hl
		; Reset buffer: 255 bytes remaining, pointer = sector_buf
	ld hl,setup_fdc_flags               ; HL = 0x00FF = 255
	ld (buf_remain),hl
	ld hl,sector_buf
	jr read_from_buf
		; Buffer still has data — decrement count, load from read pointer
buf_has_data:
	dec hl                              ; one fewer byte remaining
	ld (buf_remain),hl
	ld hl,(buf_rd_ptr)                  ; current read position
		; Fetch byte from buffer and advance read pointer
read_from_buf:
	ld a,(hl)                           ; read byte from buffer
	inc hl                              ; advance pointer
	ld (buf_rd_ptr),hl                  ; save updated pointer
	pop hl                              ; restore caller's HL
	dec c                               ; decrement record byte counter
	ret

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
	push hl
	push de
		; Divide LBA by sectors-per-track: L = track, B = sector offset
	call div_hl_e
	ld a,b                              ; remainder = sector offset
	inc a                               ; sectors are 1-based
	ld (fdc_sector),a
		; Check track against max tracks (D)
	ld a,l                              ; L = track (including side bit)
	pop de
	cp d                                ; track >= max?
	jp nc,cmd_error                     ; past end of disk
		; Determine side from track parity: even = side 0, odd = side 1
	ld b,000h
	ld a,l
	or a
	rra                                 ; shift out low bit into carry
	jr nc,set_track                     ; even track → side 0
	ld b,002h                           ; odd track → side 1 (B=2)
set_track:
	ld (fdc_track),a                    ; physical track = LBA_track / 2
	ld a,b
	ld (fdc_side),a                     ; side select value
		; Seek to track and read sector; retry with restore on error
try_seek_read:
	call fdc_seek_read
	jr nz,retry_seek_read               ; seek failed, retry
		; Set density based on track number (track >= 22 → double density)
	ld hl,sys_flags
	ld a,(fdc_track)
	cp DD_TRACK_THRESH
	jr c,set_single_density             ; track < 22
	set 7,(hl)                          ; set DD flag
	jr apply_density
set_single_density:
	res 7,(hl)                          ; clear DD flag
apply_density:
	ld a,(hl)
	out (PORT_SYS_CTRL),a               ; output updated flags
	call fdc_read_sector
	dec a                               ; A=1 success, 0 = error
	jr nz,retry_seek_read               ; read error → retry
	pop hl
	inc hl                              ; return LBA + 1
	ret
retry_seek_read:
	call fdc_restore                    ; restore to track 0
	jr try_seek_read                    ; try seek again

; ============================================================
; div_hl_e — Unsigned 16-bit by 8-bit division
; Entry: HL = dividend, E = divisor
; Returns: L = quotient, B = remainder
; Uses shift-and-subtract algorithm (16 iterations).
; ============================================================
div_hl_e:
	xor a                               ; clear accumulator (partial remainder)
	ld d,010h                           ; 16-bit dividend = 16 iterations
div_loop:
	add hl,hl                           ; shift dividend left, MSB into A
	rla
	jr c,div_subtract                   ; overflow → must subtract
	cp e                                ; partial remainder >= divisor?
	jr c,div_next_bit                   ; no → skip subtract
div_subtract:
	inc l                               ; set quotient bit
	sub e                               ; subtract divisor from remainder
div_next_bit:
	dec d                               ; count iterations
	jr nz,div_loop
	ld b,a                              ; B = final remainder
	ret

; ============================================================
; fdc_restore — Restore FDC head to track 0
; Aborts any pending command, issues restore, waits for
; completion, then delays for head settle time (~1ms).
; Returns: A = 0xFF if track-0 found, status bits if error
; ============================================================
fdc_restore:
	ld a,FDC_CMD_FORCE_INT              ; abort any pending command
	call fdc_send_cmd
	ld a,FDC_CMD_RESTORE                ; restore to track 0
	call fdc_send_cmd
		; Poll until FDC finishes (bit 0 = busy)
wait_restore_done:
	in a,(PORT_FDC_CMD)
	bit 0,a
	jr nz,wait_restore_done
		; Check for head-load error (bit 2)
	bit 2,a
	jr nz,restore_settle                ; error: skip OK marker
	ld a,0ffh                           ; success marker
		; Head settle delay (~1000 iterations)
restore_settle:
	push af
	push hl
	ld hl,003e8h                        ; 1000 iterations
settle_delay_loop:
	dec hl
	ld a,h
	or l
	jr nz,settle_delay_loop
	pop hl
	pop af
	ret

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
	ld a,FDC_CMD_FORCE_INT              ; abort any pending cmd
	call fdc_send_cmd
		; Wait for FDC to go idle
wait_fdc_idle:
	in a,(PORT_FDC_CMD)
	bit 0,a
	jr nz,wait_fdc_idle
	push bc
	ld b,002h                           ; 2 attempts before full restore
		; Issue read-address to discover current physical track
read_addr_mark:
	ld a,FDC_CMD_READ_ADDR
	call fdc_send_cmd
wait_addr_done:
	in a,(PORT_FDC_CMD)
	bit 0,a
	jr z,fdc_check_status               ; command complete
	jr wait_addr_done                   ; still busy
		; Read-address failed — step in one track and retry
fdc_step_in:
	ld a,FDC_CMD_FORCE_INT
	call fdc_send_cmd
	ld a,FDC_CMD_STEP_IN
	call fdc_send_cmd
wait_step_done:
	in a,(PORT_FDC_CMD)
	bit 0,a
	jr nz,wait_step_done
	dec b                               ; decrement attempt counter
	jr nz,read_addr_mark                ; try read-address again
		; Both attempts failed — full restore and start over
	call fdc_restore
	pop bc
	jr fdc_seek_read
		; Check read-address result: bits 4,3 = record-not-found, CRC error
fdc_check_status:
	bit 4,a                             ; record not found?
	jr nz,fdc_step_in                   ; try stepping in
	bit 3,a                             ; CRC error?
	jr nz,fdc_step_in                   ; try stepping in
		; Read-address OK — now seek to target track
	pop bc
	in a,(PORT_FDC_SECTOR)              ; read-address returns track in sector reg
	out (PORT_FDC_TRACK),a              ; set FDC track to current position
	ld a,(fdc_track)                    ; target track
	out (PORT_FDC_DATA),a               ; target goes in data reg for seek
	ld a,FDC_CMD_SEEK
	call fdc_send_cmd
		; Wait for seek to complete
wait_seek_done:
	in a,(PORT_FDC_CMD)
	bit 0,a
	jr nz,wait_seek_done
		; Check for seek errors (CRC + seek error bits)
	and FDC_STAT_ERR_SEEK
	jr nz,fdc_seek_read                 ; seek error → retry
	ret                                 ; Z set = success

; ============================================================
; fdc_send_cmd — Send command byte to FDC with post-delay
; Entry: A = command byte
; Writes to FDC command port, then burns ~64 cycles for the
; FDC to latch the command before returning.
; ============================================================
fdc_send_cmd:
	out (PORT_FDC_CMD),a                ; issue command
	ld a,040h                           ; 64 iterations
cmd_delay_loop:
	dec a
	ret z                               ; done when counter hits 0
	jr cmd_delay_loop

; ============================================================
; fdc_read_sector — Read one sector into sector_buf via NMI
; Sets FDC sector register and side flag, issues read-sector
; command. Data transfer happens byte-by-byte via NMI handler.
; Waits for completion and checks for read errors.
; Returns: A = 1 if success, A = 0 if error
; ============================================================
fdc_read_sector:
	ld a,(fdc_sector)
	out (PORT_FDC_SECTOR),a             ; set sector number
	ld hl,sector_buf                    ; NMI writes data here via (HL)
	ld b,FDC_CMD_READ_SEC               ; read-sector command
	ld a,(fdc_side)
	or b                                ; OR side flag into command
	call fdc_send_cmd                   ; start the read
		; Wait for read to complete (NMI transfers data in background)
wait_read_done:
	in a,(PORT_FDC_CMD)
	bit 0,a
	jr nz,wait_read_done
		; Check for read errors (lost data, CRC, record not found)
	and FDC_STAT_ERR_READ
	ld a,000h
	ret nz                              ; error: return 0
	ld a,001h                           ; success: return 1
	ret

; ============================================================
; parse_hex — Parse hex number from keyboard input
; Reads hex digits interactively, building a 16-bit value.
; Accepts 0-9, A-F (uppercase). Stops on any non-hex char
; (the terminator is returned in C for the caller to check).
; Returns: DE = parsed value, B = digit count, C = terminator
; ============================================================
parse_hex:
	ld de,reset                         ; DE = 0 (accumulator)
	ld b,e                              ; B = 0 (digit count)
hex_next_char:
	call get_char_echo                  ; read and echo one character
	ld a,c
	sub '0'                             ; convert ASCII to value
	cp LF                               ; value < 10?
	jr c,hex_digit_valid                ; yes, 0-9 is valid
	cp 011h                             ; gap between '9' and 'A'?
	ret c                               ; not a hex digit, return
	sub 007h                            ; adjust A-F range
hex_digit_valid:
	cp 010h                             ; value >= 16?
	ccf                                 ; complement carry for ret c test
	ret c                               ; not a hex digit
	inc b                               ; count this digit
		; Shift existing value left 4 bits and add new digit
	ld l,a                              ; L = new nibble value
	ld h,000h
	ld a,010h                           ; multiply DE by 16 via repeated add
hex_shift_loop:
	add hl,de                           ; HL += DE (16 times = DE * 16 + nibble)
	jp c,cmd_error                      ; overflow
	dec a
	jr nz,hex_shift_loop
	ex de,hl                            ; DE = updated value
	jr hex_next_char                    ; read next digit

; ============================================================
; cmd_star — Transparent terminal mode ('*' command)
; Echoes keystrokes directly to screen in a tight loop.
; Press ESC to exit back to the monitor prompt.
; ============================================================
cmd_star:
	call get_kbd_char
	cp ESC                              ; ESC exits to monitor
	jp z,monitor_prompt
	ld c,a
	call putchar
	jr cmd_star
		; cmd_cr_boot — Default boot on bare Enter key
		; Boots from drive 0 ('B'), starting at sector 0x0080
cmd_cr_boot:
	ld hl,00080h                        ; default start sector
	ld a,'B'
	ex de,hl
	ex af,af'
	jp boot_floppy
		; cmd_boot_default — 'B' with no args: drive 0, sector 1
cmd_boot_default:
	ld a,c
	cp CR
	jp nz,cmd_error
	ld b,000h                           ; drive 0
	ld de,reset+1                       ; sector 1
	jp boot_floppy

; ============================================================
; cmd_go — Execute code at address ('G' command)
; Parses hex address, does bank-switch, jumps to it.
; ============================================================
cmd_go:
	call parse_hex
	dec b
	jp m,cmd_error
	ld a,c
	cp CR
	jp nz,cmd_error
	ex de,hl
	jp exec_loaded_code

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
		; Print sub-prompt and read sub-command character
	call print_crlf
	ld c,004h                           ; sub-prompt character
	call putchar
	call get_char_echo
	push bc
	ld c,':'
	call putchar
	pop bc
		; Dispatch sub-command letter
	ld a,c
	cp 'R'                              ; return to main prompt
	jp z,monitor_prompt
	cp 'G'
	jr z,cmd_go
	cp 'D'                              ; dump
	jr z,cmd_mem_dispatch
	cp 'M'                              ; modify
	jr z,cmd_mem_dispatch
	cp 'I'                              ; in port
	jr z,cmd_mem_dispatch
	cp 'O'                              ; out port
	jr z,cmd_mem_dispatch
cmd_mem_error:
	ld c,ERR_CHAR
	call putchar
	jr cmd_memory
		; Parse first hex argument, then dispatch by saved command letter
cmd_mem_dispatch:
	ex af,af'                           ; save command letter
	call parse_hex                      ; DE = first arg
	dec b
	jp m,cmd_memory                     ; no digits entered
	ex af,af'                           ; restore command letter
	cp 'M'
	jr z,cmd_mem_modify
	cp 'I'
	jr z,cmd_mem_inport
		; D and O commands need a second argument after comma
	ex af,af'
	ld a,c                              ; check terminator was comma
	cp ','
	jr nz,cmd_mem_error
	push de                             ; save first arg (start addr)
	call parse_hex                      ; DE = second arg (end addr)
	pop hl                              ; HL = start addr
	dec b
	jp m,cmd_mem_error
	ld a,c
	cp CR
	jr nz,cmd_mem_error
	ex af,af'
	cp 'O'
	jr z,cmd_mem_outport
		; Validate end > start, then set up dump loop
	call compare_hl_de
	jr nc,cmd_mem_error                 ; start >= end
	ex de,hl                            ; DE = current addr, HL(stack) = end
	push hl
	; --- Hex dump: print 16 bytes per line in 4 groups of 4 ---
cmd_mem_dump:
	call print_crlf
dump_print_addr:
	call print_address                  ; print current address
	ld a,004h                           ; 4 groups per line
	ex af,af'
dump_group:
	ld b,004h                           ; 4 bytes per group
dump_byte:
	ld a,(de)                           ; read memory byte
	call print_hex_byte
	inc de                              ; next address
	pop hl                              ; end address
	call compare_hl_de                  ; reached end?
	jp z,cmd_memory                     ; done
	push hl
	ld a,e
	or a
	jr z,cmd_mem_dump                   ; page boundary → new line
	ld c,' '
	call putchar
	djnz dump_byte                      ; next byte in group
	call putchar                        ; extra space between groups
	ex af,af'
	dec a                               ; decrement group counter
	jr z,dump_print_addr                ; 4 groups done → new line
	ex af,af'
	jr dump_group                       ; next group
		; cmd_mem_inport — Read and display I/O port value
cmd_mem_inport:
	ld a,c
	cp CR
	jp nz,cmd_mem_error
	call print_address
	ld b,d
	ld c,e
	in d,(c)
	ld a,d
	call print_hex_byte
	jp cmd_memory
		; cmd_mem_outport — Write value to I/O port
cmd_mem_outport:
	ld a,d
	or a
	jp nz,cmd_mem_error
	ld b,h
	ld c,l
	out (c),e
	jp cmd_memory
		; cmd_mem_modify — Modify memory byte-by-byte
		; Shows current value, reads new hex value, writes it.
		; Enter '.' to stop, CR to advance without changing.
cmd_mem_modify:
	ld a,c
	cp CR
	jp nz,cmd_mem_error
mem_modify_loop:
	call print_address
	ex de,hl
	push hl
	ld a,(hl)
	call print_hex_byte
	ld c,' '
	call putchar
	call parse_hex
	pop hl
	ld a,c
	cp '.'
	jp z,cmd_memory
	cp CR
	jp nz,cmd_mem_error
	dec b
	jp m,mem_modify_next
	ld (hl),e
mem_modify_next:
	inc hl
	ex de,hl
	jr mem_modify_loop

; ============================================================
; nibble_to_ascii — Convert low nibble of A to ASCII hex char
; Uses the classic DAA trick: A + 0x90 + DAA + 0x40 + DAA
; converts 0x0-0xF → '0'-'9', 'A'-'F'.
; Returns: A = ASCII hex character
; ============================================================
nibble_to_ascii:
	and 00fh
	add a,090h
	daa
	adc a,040h
	daa
	ret
; ============================================================
; negate_add_hl_de — ORPHAN (unreferenced dead code)
; Computes HL = DE - HL (two's complement negate HL, add DE).
; Likely a utility left over from development; never called
; by any code path in this ROM.
; ============================================================
negate_add_hl_de:
	ld a,l
	cpl
	ld l,a
	ld a,h
	cpl
	ld h,a
	inc hl
	add hl,de
	ret
; ============================================================
; sub_l_a — ORPHAN (unreferenced dead code)
; Computes L = L - A (with borrow into H).
; Another unused utility; no call or jump targets this
; address anywhere in the ROM.
; ============================================================
sub_l_a:
	push bc
	ld b,a
	ld a,l
	sub b
	ld l,a
	pop bc
	ret nc
	dec h
	ret

; ============================================================
; compare_hl_de — Compare HL with DE
; Returns: Z flag set if HL == DE, NZ if different.
; ============================================================
compare_hl_de:
	ld a,h
	cp d
	ret nz
	ld a,l
	cp e
	ret

; ============================================================
; print_crlf — Output carriage return + line feed
; ============================================================
print_crlf:
	ld c,CR
	jr putchar

; ============================================================
; print_hex_byte — Print byte in A as two hex digits
; Converts low nibble first (saves to H), then shifts high
; nibble down and prints high digit first, then low digit.
; ============================================================
print_hex_byte:
	push af
	call nibble_to_ascii                ; convert low nibble
	ld h,a                              ; save low digit
	pop af
		; Shift high nibble into low position
	rra
	rra
	rra
	rra
	call nibble_to_ascii                ; convert high nibble
	ld c,a
	call putchar                        ; print high digit first
	ld c,h
	jr putchar                          ; then low digit

; ============================================================
; print_address — Print CRLF, then DE as 4 hex digits + space
; ============================================================
print_address:
	call print_crlf
	ld a,d
	call print_hex_byte
	ld a,e
	call print_hex_byte
	ld c,' '
	call putchar
	jr putchar

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
		; Poll LUCY register 7 for keyboard status
	ld a,LUCY_REG_KBD
	out (PORT_LUCY_REG),a
	in a,(PORT_LUCY_DATA)
		; Bit 1 = key released event
	bit 1,a
	jr z,kbd_check_repeat               ; no release → check repeat
		; Key was released — reset debounce state
	push af
	xor a
	ld (kbd_state),a                    ; state = no key held
	pop af
		; Check if a new key is also pressed right now (bit 0)
	bit 0,a
	jr z,get_kbd_char                   ; no key → keep polling
		; Key pressed — read the scancode from KR3600
read_kbd_data:
	in a,(PORT_KBD_DATA)
	and KBD_DATA_MASK                   ; mask to 7-bit ASCII
	ld (kbd_last),a                     ; save for auto-repeat
	ret
		; No release event — check if we're in repeat mode
kbd_check_repeat:
	ld a,(kbd_state)
	or a
	jr z,kbd_first_press                ; first time seeing this key
		; In repeat mode — check if key is still pressed
	in a,(PORT_LUCY_DATA)
	bit 0,a
	jr nz,read_kbd_data                 ; still pressed → read fresh data
		; Key released during repeat — delay, then return last key
	push bc
	ld bc,00a00h                        ; ~2560 iteration delay
kbd_repeat_delay:
	dec bc
	ld a,b
	or c
	jr nz,kbd_repeat_delay
	pop bc
kbd_return_cached:
	ld a,(kbd_last)
	ret
		; First key press — mark state and wait for key data ready
kbd_first_press:
	ld a,001h
	ld (kbd_state),a                    ; state = key held
kbd_wait_key:
	in a,(PORT_LUCY_DATA)
	bit 0,a
	jr z,kbd_wait_key                   ; wait for data ready
	in a,(PORT_KBD_DATA)                ; read KR3600 scancode
	ld (kbd_last),a
		; Check if key was already released before we read it
	in a,(PORT_LUCY_DATA)
	bit 1,a
	jr z,kbd_return_cached              ; still held → return it
		; Key released between press and read — reset state
	xor a
	ld (kbd_state),a                    ; back to idle
	jr kbd_return_cached

; ============================================================
; get_char_echo — Read key and echo to display
; Calls get_kbd_char, then falls through to putchar.
; ============================================================
get_char_echo:
	call get_kbd_char
	ld c,a                              ; C = key for putchar

; ============================================================
; putchar — Output character to video display
; Entry: C = character to display
; Handles CR (new line + reset column), LF (advance row),
; and printable characters (write to VRAM + advance cursor).
; Saves/restores all registers. Updates cursor on exit.
; ============================================================
putchar:
	push bc
	push de
	push hl
	ld a,c
	cp CR
	jr z,handle_cr
	cp LF
	jr z,handle_lf
		; Printable character — write to VRAM and move cursor right
	ld (vram_char),a
	ld a,ATTR_NORMAL
	ld (vram_attr),a
	call write_vram
	call advance_cursor
		; Restore registers and show cursor at new position
putchar_done:
	call cursor_on                      ; display cursor block
	pop hl
	pop de
	pop bc
	ret
		; CR: erase cursor, advance row, reset column to 0
handle_cr:
	call cursor_off                     ; erase old cursor
	call advance_row
	call reset_column
	jr putchar_done
reset_column:
	xor a
	ld (cursor_col),a
	ret
		; LF: erase cursor, advance row (column unchanged)
handle_lf:
	call cursor_off
	call advance_row
	jr putchar_done

; ============================================================
; advance_cursor — Move cursor right by one character position
; The SAA5120 uses split-column addressing: columns 0-39 in
; the left half (bit 7 clear), 40-79 in the right half (bit 7
; set). Advances within a half, toggles between halves at
; the boundary, and wraps to next row at column 80.
; ============================================================
advance_cursor:
	ld a,(cursor_col)
	cp COL_LAST                         ; at last column?
	jr z,col_overflow                   ; yes → wrap to next line
	bit 7,a                             ; in right half?
	jr z,toggle_half                    ; no → toggle to right
	inc a                               ; right half: also increment
toggle_half:
	xor COL_HALF                        ; flip half-select bit
	ld (cursor_col),a
	ret
		; Past last column — wrap to column 0 of next row
col_overflow:
	call reset_column
	call advance_row
	ret
		; advance_row — Move cursor down one row, scrolling if at bottom
advance_row:
	ld a,(cursor_row)
	cp LAST_ROW                         ; at row 24 (last row)?
	jr z,scroll_screen                  ; yes → scroll
	ld a,(cursor_row)
	inc a                               ; simply move down one row
	ld (cursor_row),a
	ret

; ============================================================
; scroll_screen — Scroll display up one line
; Increments the SAA5120 hardware scroll register (offset of
; first visible row), wraps at row 25, then clears the newly
; exposed bottom row with spaces. This is zero-copy hardware
; scrolling — no data is moved in VRAM.
; ============================================================
scroll_screen:
	ld a,(cursor_col)
	push af                             ; save cursor column
		; Increment scroll offset and program hardware
	ld a,(scroll_off)
	inc a
	ld (scroll_off),a
	cp SCREEN_ROWS                      ; past row 25?
	jr z,scroll_wrap                    ; yes → wrap to 0
	out (PORT_SCROLL_ALT),a             ; set scroll register
		; Clear the newly exposed bottom row
clear_new_row:
	xor a
	ld (cursor_col),a
	ld a,' '
	ld (vram_char),a
	ld a,ATTR_NORMAL
	ld (vram_attr),a
	call fill_row_spaces                ; fill row with spaces
	pop af
	ld (cursor_col),a                   ; restore cursor column
	ret
		; Scroll offset wrapped past 25 — reset to 0
scroll_wrap:
	xor a
	ld (scroll_off),a
	out (PORT_SCROLL),a
	jr clear_new_row

; ============================================================
; clear_screen — Clear entire 25×80 display
; Fills all rows with spaces + normal attribute, resets
; scroll offset and column, updates cursor.
; ============================================================
clear_screen:
	xor a
clear_row_loop:
	ld (cursor_row),a
	xor a
	ld (cursor_col),a
	ld a,' '
	ld (vram_char),a
	ld a,ATTR_NORMAL
	ld (vram_attr),a
	call fill_row_spaces
	ld a,(cursor_row)
	inc a
	cp SCREEN_ROWS
	jr nz,clear_row_loop
	xor a
	ld (cursor_col),a
	out (PORT_SCROLL),a
	ld (scroll_off),a
	call cursor_on
	ret

; ============================================================
; fill_row_spaces — Fill current row from current column onward
; Handles SAA5120 split-column addressing: writes left half
; (cols 0-39), then switches to right half (0x80-0xA7).
; Returns when column wraps past 0xA7.
; ============================================================
fill_row_spaces:
	call write_vram                     ; write space at current col
	ld a,(cursor_col)
	inc a
	ld (cursor_col),a
	bit 7,a                             ; in right half?
	jr nz,fill_check_done               ; yes → check wrap
	cp COL_HALF_COUNT                   ; reached col 40?
	jr nz,fill_row_spaces               ; no → keep going
		; Switch to right half (bit 7 set, counter at 0x80)
	ld a,COL_HALF
	ld (cursor_col),a
	jr fill_row_spaces
fill_check_done:
	cp COL_WRAP                         ; past last right-half col?
	jr nz,fill_row_spaces               ; no → keep going
	ret                                 ; row complete

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
	ld hl,cursor_row
	ld a,(hl)
	out (PORT_VIDEO_ROW),a              ; set row address
	inc hl
	ld d,(hl)                           ; D = column (without strobe)
	ld a,(hl)
	or VID_WRITE_STROBE                 ; set bit 6 for write
	ld b,a                              ; B = column with write strobe
	inc hl
	ld c,(hl)                           ; C = character code
	inc hl
	ld e,(hl)                           ; E = attribute
		; Wait for video blanking interval (bit 0 of LUCY scan reg)
	ld hl,sys_flags
	set 5,(hl)                          ; mark sync-pending in flags
	ld a,LUCY_REG_SCAN
	out (PORT_LUCY_REG),a
wait_video_sync:
	in a,(PORT_LUCY_DATA)
	bit 0,a
	jr z,wait_video_sync                ; wait for blanking
		; Critical timing section — write char+attr during blanking
	ld a,(hl)                           ; read sys_flags
	res 5,(hl)                          ; clear sync-pending
	ld h,(hl)                           ; H = original sys_flags (for restore)
	push hl                             ; |
	pop hl                              ; | small timing delay
	out (PORT_SYS_CTRL),a               ; activate video write mode
		; Write: strobe column + char, then plain column + attr
	ld a,b                              ; column with strobe
	out (PORT_VIDEO_CHAR),a             ; 1st char write (strobe)
	ld a,c
	out (PORT_VIDEO_ATTR),a             ; 1st attr write
	ld a,d                              ; column without strobe
	out (PORT_VIDEO_CHAR),a             ; 2nd char write
	ld a,e
	out (PORT_VIDEO_ATTR),a             ; 2nd attr write
		; Restore system control to previous state
	ld a,h
	out (PORT_SYS_CTRL),a
	ret

; ============================================================
; cursor_on — Show cursor block (inverted attribute)
; Writes space with XOR'd attribute to create visible cursor.
; ============================================================
cursor_on:
	ld a,' '
	ld (vram_char),a
	ld a,ATTR_NORMAL
	xor ATTR_CURSOR_XOR                 ; invert attribute bits
	ld (vram_attr),a
	call write_vram
	ret

; ============================================================
; cursor_off — Remove cursor block (restore normal attribute)
; Writes space with normal attribute to erase cursor.
; ============================================================
cursor_off:
	ld a,' '
	ld (vram_char),a
	ld a,ATTR_NORMAL
	ld (vram_attr),a
	call write_vram
	ret

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
		; A' = error accumulator, start at 0
	ex af,af'
	xor a                               ; clear error bits
	ex af,af'
		; Enable system (LED on)
	ld a,SYS_ACTIVE
	out (PORT_SYS_CTRL),a
	; --- TEST 1: Video RAM ---
		; Write incrementing pattern (+0x55) to every cell, then verify
	xor a                               ; start at row 0
	ld c,000h                           ; C = running test pattern
post_vram_write:
	ld d,000h                           ; D = column counter
	out (PORT_VIDEO_ROW),a              ; set row
	ld h,a                              ; save row in H
	ld a,d
post_vram_col_write:
	rrca
	ld b,a
	or VID_WRITE_STROBE
	out (PORT_VIDEO_CHAR),a
	ld a,c
	out (PORT_VIDEO_ATTR),a
	add a,TEST_PATTERN
	ld c,a
	ld a,b
	out (PORT_VIDEO_CHAR),a
	ld a,c
	out (PORT_VIDEO_ATTR),a
	add a,TEST_PATTERN
	ld c,a
	inc d
	ld a,d
	cp SCREEN_COLS
	jr nz,post_vram_col_write
	ld a,h
	inc a
	cp SCREEN_ROWS
	jr nz,post_vram_write
		; VRAM verify pass: read back and compare
	xor a
	ld c,000h                           ; reset test pattern
post_vram_verify:
	ld d,000h
	out (PORT_VIDEO_ROW),a
	ld h,a
	ld a,d
post_vram_col_verify:
	rrca
	ld b,a
	or VID_WRITE_STROBE
	out (PORT_VIDEO_CHAR),a
	in a,(PORT_VIDEO_ATTR)
	cp c
	jr nz,post_vram_fail
	add a,TEST_PATTERN
	ld c,a
	xor a
	out (PORT_VIDEO_ATTR),a
	ld a,b
	out (PORT_VIDEO_CHAR),a
	in a,(PORT_VIDEO_ATTR)
	cp c
	jr nz,post_vram_fail
	add a,TEST_PATTERN
	ld c,a
	xor a
	out (PORT_VIDEO_ATTR),a
	inc d
	ld a,d
	cp SCREEN_COLS
	jr nz,post_vram_col_verify
	ld a,h
	inc a
	cp SCREEN_ROWS
	jr nz,post_vram_verify
	jr post_ram_test
		; VRAM test failed — set error bit 0
post_vram_fail:
	ex af,af'
	set 0,a                             ; bit 0 = VRAM error
	ex af,af'
	; --- TEST 2: Main RAM (32KB at 0x8000) ---
		; Write incrementing pattern byte-by-byte, then verify
post_ram_test:
	ld hl,08000h                        ; start address
	ld de,08000h                        ; block size
	jr ram_test_write
		; Second pass: test bank 2 (re-entered from relocated code)
ram_test_bank2:
	ld a,SYS_RAM_TEST                   ; select test bank
	out (PORT_SYS_CTRL),a
ram_test_write:
	ld c,080h                           ; 128 pages = 32KB
	ld a,000h                           ; starting pattern
ram_write_page:
	ld b,000h
ram_write_byte:
	ld (hl),a
	inc hl
	add a,TEST_PATTERN
	djnz ram_write_byte
	dec c
	jr nz,ram_write_page
		; Verify pass: compare pattern against written data
	ld hl,reset                         ; HL = 0
	add hl,de                           ; HL = start of test region
	ld c,080h                           ; 128 pages
	ld a,000h                           ; same starting pattern
ram_verify_page:
	ld b,000h
ram_verify_byte:
	cp (hl)
	jr nz,ram_verify_fail
	inc hl
	add a,TEST_PATTERN
	djnz ram_verify_byte
	dec c
	jr nz,ram_verify_page
		; RAM verify OK — copy test code to high RAM for bank 2 test
	ld hl,reset
	jr copy_ramtest_high
		; RAM verify failed
ram_verify_fail:
	ld a,h
	or l
	jr z,ram_test_exit                  ; HL=0 means bank2 test done
	ex af,af'
	set 1,a                             ; bit 1 = RAM error
	ex af,af'
ram_test_exit:
	ld a,SYS_ACTIVE
	out (PORT_SYS_CTRL),a               ; restore normal banking
	jp post_fdc_test
		; Copy ram_test_bank2 routine to 0x8000+ so it can test low RAM
copy_ramtest_high:
	ld hl,ram_test_bank2
	ld de,0866dh                        ; relocated address
	ld bc,0003ch                        ; size = 0x3C bytes
	ldir                                ; copy test code to high RAM
		; Patch relocated copy's data pointers
	ld hl,reset
	ld de,reset
	ld (08698h),hl
	jp 0866dh                           ; jump to relocated test
	; --- TEST 3: FDC register test ---
		; Write incrementing pattern to track/sector/data regs, read back
post_fdc_test:
	ld a,FDC_CMD_FORCE_INT              ; abort any command
	out (PORT_FDC_CMD),a
	xor a                               ; start pattern at 0
fdc_test_write:
	ld c,a                              ; save track value
	out (PORT_FDC_TRACK),a
	add a,TEST_PATTERN
	out (PORT_FDC_SECTOR),a
	add a,TEST_PATTERN
	out (PORT_FDC_DATA),a
	ld b,050h                           ; settle delay
fdc_test_settle:
	djnz fdc_test_settle
		; Read back and compare each register
	in a,(PORT_FDC_TRACK)
	cp c                                ; matches written value?
	jr nz,fdc_test_fail
	add a,TEST_PATTERN
	ld c,a
	in a,(PORT_FDC_SECTOR)
	cp c
	jr nz,fdc_test_fail
	add a,TEST_PATTERN
	ld c,a
	in a,(PORT_FDC_DATA)
	cp c
	jr nz,fdc_test_fail
	add a,TEST_PATTERN
	or a
	jr z,post_serial_setup
	ld b,050h
fdc_test_delay:
	djnz fdc_test_delay
	jr fdc_test_write
		; FDC test failed — set error bit 2
fdc_test_fail:
	ex af,af'
	set 2,a                             ; bit 2 = FDC error
	ex af,af'
	ld a,FDC_CMD_FORCE_INT
	out (PORT_FDC_CMD),a                ; clean up FDC
	; --- TEST 4: Serial port (UART loopback) ---
		; Configure 2661 UART for 8N1 with loopback, send incrementing
		; pattern, verify each byte echoes back correctly.
post_serial_setup:
	ld a,SYS_ACTIVE
	out (PORT_SYS_CTRL),a
	ld a,UART_MODE1_VAL                 ; 8N1
	out (PORT_UART_MODE),a
	ld a,UART_MODE2_VAL                 ; 16x clock
	out (PORT_UART_MODE),a
	ld a,UART_CMD_VAL                   ; TX/RX enable + loopback
	out (PORT_UART_CMD),a
	ld c,000h                           ; start pattern at 0
		; Send test byte and wait for loopback echo
post_serial_test:
	ld d,0ffh                           ; timeout counter
wait_uart_txready:
	dec d
	jr z,serial_test_fail               ; timeout
	in a,(PORT_UART_STATUS)
	and 001h                            ; TX ready?
	jr z,wait_uart_txready
	ld a,c                              ; send test byte
	out (PORT_UART_DATA),a
		; Delay for loopback propagation
	xor a
uart_rx_delay:
	dec ix                              ; waste time
	dec a
	jr nz,uart_rx_delay
		; Read back and compare
	in a,(PORT_UART_DATA)
	cp c                                ; matches sent byte?
	jr nz,serial_test_fail
		; Advance pattern, loop until full byte range tested
	add a,TEST_PATTERN
	ld c,a
	or a                                ; wrapped to 0? (all 256 done)
	jr nz,post_serial_test
	jp post_timer_test                  ; serial OK
		; Serial test failed — set error bit 3
serial_test_fail:
	ex af,af'
	set 3,a                             ; bit 3 = serial error
	ex af,af'
	; --- TEST 5: Timer/interrupt test ---
		; Enable IM1, count ticks during a calibrated loop.
		; D is incremented by the IRQ handler each tick.
		; Expect 0x23-0x24 ticks; outside range = timer failure.
post_timer_test:
	ld hl,reset                         ; HL = 0 (loop counter)
	ld d,000h                           ; D = tick counter (incremented by IRQ)
	im 1                                ; use IM1 handler at 0x0038
	ei                                  ; start counting
timer_count_loop:
	dec hl                              ; count down from 0 (= 65536 iterations)
	ld a,h
	or l
	jr nz,timer_count_loop
	di                                  ; stop counting
		; Check tick count is in expected range [0x23, 0x24]
	ld a,d                              ; D = number of ticks
	cp 023h                             ; < 0x23 = too slow
	jr c,timer_test_fail
	cp 025h                             ; >= 0x25 = too fast
	jr c,post_complete                  ; in range = OK
		; Timer test failed — set error bit 4
timer_test_fail:
	ex af,af'
	set 4,a                             ; bit 4 = timer error
	ex af,af'
	; --- POST complete — display results ---
post_complete:
	di
	call init_display                   ; initialize video
		; Print "\r\n AUTO-TEST : "
	ld hl,str_autotest
print_autotest_loop:
	ld c,(hl)
	call putchar
	inc hl
	ld a,(hl)
	or a
	jr nz,print_autotest_loop
		; Check accumulated error bits in A'
	ex af,af'
	or a
	jr nz,post_show_errors              ; errors found
		; All tests passed — print "OK"
	ld c,'O'
	call putchar
	ld c,'K'
	call putchar
	jp monitor_prompt
		; Errors detected — print each set bit's number (0-7)
post_show_errors:
	ld b,008h                           ; check 8 bits
	ld e,a                              ; E = error bitmap
	ld d,'0'                            ; D = ASCII digit counter
post_error_loop:
	srl e                               ; ; shift out lowest bit
	jr c,post_print_error               ; bit was set → print it
post_next_error:
	inc d                               ; next digit
	djnz post_error_loop
	jp monitor_prompt                   ; done → enter monitor
		; Print error number on its own line
post_print_error:
	ld c,CR
	call putchar
	ld c,d                              ; print digit
	call putchar
	jr post_next_error
str_prompt:
	defb CR,LF
	defm " M P 2 ... "
	defb 000h
str_autotest:
	defb CR,LF
	defm " AUTO-TEST : "
	defb 000h
floppy_params:
		; Floppy parameters table (geometry) + ROM padding to 0x0800
	defb 020h, 010h
	defs 86
