; ============================================================
; MICRAL P2 Boot ROM — Annotated Disassembly
; ============================================================
;
; Machine:   Bull/R2E Micral P2 (Z80A @ 4 MHz, 1981)
; ROM:       2 KB (0x0000–0x07FF), mapped at reset
; RAM:       Variables at 0xBEE8–0xBFFD (top of 48K)
; Source:    z80dasm from MICRAL_P2_CHARGEUR.BIN
;
; Execution flow:
;   0x0000  reset       → hardware init (LUCY, keyboard)
;   0x05FA  post_start  → self-test (VRAM, RAM, FDC, UART, timer)
;   0x0093  monitor     → command loop: Boot / Memory / Go / Terminal
;   0x00F6  boot_floppy → load MOS hex records from floppy, bank-switch, run
;
; Hardware:
;   SAA5070 (LUCY)  — video sync, keyboard scan (ports 0x60/0x70)
;   SAA5120         — 25×80 teletext display (ports 0x00–0x04)
;   FD1797          — floppy disk controller (ports 0x10–0x13)
;   2661 (EPCI)     — serial UART (ports 0x50–0x53)
;   KR3600          — keyboard encoder (port 0x30)
;   CTC             — timer (port 0x07)
;
; Memory map:
;   0x0000–0x07FF   Boot ROM (this file)
;   0x0800–0xBEE7   User RAM (available after boot)
;   0xBEE8–0xBFFD   Boot loader variables / stack
;   0xFFFF          Bank latch (write: ROM out, RAM in)
;
; ============================================================

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
LUCY_REG_SYNC:      equ	3               ; Sync/configuration register
LUCY_REG_SCAN:      equ	6               ; Scan control / video sync register
LUCY_REG_KBD:       equ	7               ; Keyboard status register
LUCY_SYNC_BIT:      equ	020h            ; Bit 5: sync status flag
LUCY_SCAN_ALL:      equ	0ffh            ; Enable all keyboard scan rows

	; --- SAA5120 Video Constants ---
VID_WRITE_STROBE:   equ	040h            ; Bit 6: character write strobe
ATTR_NORMAL:        equ	00eh            ; Normal text attribute (white on black)
ATTR_CURSOR_XOR:    equ	0c0h            ; XOR mask for cursor inversion
COL_HALF:           equ	080h            ; Column half-select (right half)
COL_HALF_COUNT:     equ	40              ; Columns per half
COL_LAST:           equ	0a7h            ; Last valid column position
COL_WRAP:           equ	0a8h            ; Column wrap sentinel
SCREEN_ROWS:        equ	25              ; 25 display rows
LAST_ROW:           equ	24              ; Row 24 (0-based last row)
SCREEN_COLS:        equ	80              ; 80 display columns

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
DD_TRACK_THRESH:    equ	22              ; Track >= 22: double-density select

	; --- ASCII Control Characters ---
CR:                 equ	00dh            ; Carriage return
LF:                 equ	00ah            ; Line feed
ESC:                equ	01bh            ; Escape
ERR_CHAR:           equ	006h            ; Error indicator character (written to display)

; ============================================================
; reset @ 0x0000 — Power-on entry point
; Initializes stack, pulses keyboard controller enable,
; configures SAA5070 (LUCY) for video sync and keyboard
; scanning, then jumps to POST.
; ============================================================
reset:
	ld sp,stack_top                     ; init stack at top of RAM
		; Pulse keyboard enable on system control port
	ld a,SYS_KBD_ENABLE                 ; keyboard + drive enable bits
	out (PORT_SYS_CTRL),a               ; assert enable pulse
		; Short delay for keyboard controller to latch
	ld b,48                             ; 48-iteration delay
delay_loop:
	djnz delay_loop                     ; spin until B=0
		; Deassert keyboard enable pulse
	xor a                               ; A=0
	out (PORT_SYS_CTRL),a               ; clear all control bits
		; Select LUCY sync register and trigger sync
	ld a,LUCY_REG_SYNC                  ; reg 3 = sync config
	out (PORT_LUCY_REG),a               ; select LUCY register
	ld a,LUCY_SYNC_BIT                  ; bit 5 = trigger sync
	out (PORT_LUCY_DATA),a              ; start video sync
		; Poll until LUCY sync completes (bit 5 clears)
wait_lucy_sync:
	ld a,LUCY_REG_SYNC                  ; re-select sync register
	out (PORT_LUCY_REG),a               ; address it
	in a,(PORT_LUCY_DATA)               ; read sync status
	and LUCY_SYNC_BIT                   ; test bit 5
	jr nz,wait_lucy_sync                ; loop while still syncing
		; Enable all keyboard scan rows (LUCY register 6)
	ld a,LUCY_REG_SCAN                  ; reg 6 = scan control
	out (PORT_LUCY_REG),a               ; select it
	ld a,LUCY_SCAN_ALL                  ; 0xFF = all rows enabled
	out (PORT_LUCY_DATA),a              ; enable scan matrix
		; Enable keyboard data register (LUCY register 7)
	ld a,LUCY_REG_KBD                   ; reg 7 = keyboard data
	out (PORT_LUCY_REG),a               ; select it
	ld a,LUCY_SCAN_ALL                  ; 0xFF = all inputs active
	out (PORT_LUCY_DATA),a              ; enable keyboard readout
		; Hardware init done — jump to Power-On Self Test
	jp post_start                       ; begin POST sequence
		; Unused padding (RST 0x30 vector area, not used)
	defs 5                              ; pad to 0x0038

; ============================================================
; irq_im1 @ 0x0038 — IM1 interrupt handler
; Called by CTC timer tick. Increments D as a tick counter
; (used by POST timing calibration), reloads timer, returns.
; ============================================================
irq_im1:
	inc d                               ; bump tick counter
	out (PORT_TIMER),a                  ; reload timer
	ei                                  ; re-enable interrupts
	ret                                 ; return from interrupt
		; Unused vector space (0x003D–0x0065)
	defs 41                             ; pad to 0x0066

; ============================================================
; nmi_handler @ 0x0066 — Non-maskable interrupt
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
	retn                                ; return from NMI

; ============================================================
; init_display @ 0x006E — Initialize video display state
; Sets cursor to row 25 (off-screen), clears system flags
; and column, writes '.' at both column halves to prime the
; SAA5120, then clears the full screen.
; ============================================================
init_display:
		; Start cursor off-screen (row 25); first CR will scroll it in
	ld a,SCREEN_ROWS                    ; A = 25 (one past last row)
	ld (cursor_row),a                   ; place cursor off-screen
		; Clear system flags and reset column to 0
	xor a                               ; A = 0
	ld (sys_flags),a                    ; clear all flags
	ld (cursor_col),a                   ; column = 0 (left edge)
		; Prime SAA5120: write '.' at left-half column 0
	ld a,1                              ; minimal attribute
	ld (vram_attr),a                    ; set attribute for write
	ld a,'.'                            ; dummy character
	ld (vram_char),a                    ; set character for write
	call write_vram                     ; prime left half of SAA5120
		; Same for right-half column 0 (bit 7 = right half)
	ld a,COL_HALF                       ; 0x80 = right-half base
	ld (cursor_col),a                   ; select right half column 0
	call write_vram                     ; prime right half of SAA5120
		; Fill entire screen with spaces
	call clear_screen                   ; blank all 25×80 cells
	ret                                 ; display initialized

; ============================================================
; monitor_prompt @ 0x0093 — Main monitor command loop
; Resets stack, prints "\r\n M P 2 ... " prompt, reads one
; character and dispatches:
;   CR → default boot (drive 0)    B → boot drive,sector
;   *  → transparent terminal      M → memory submenu
;   G  → execute at address
; Invalid commands show error and re-prompt.
; ============================================================
monitor_prompt:
		; Reset stack (clean return from any prior command)
	ld sp,stack_top                     ; discard any nested call frames
		; Clear system flags
	xor a                               ; A = 0
	ld (sys_flags),a                    ; reset all flags
	ld hl,str_prompt                    ; point to "\r\n M P 2 ... " string
print_str_loop:
	ld c,(hl)                           ; load next char from string
	call putchar                        ; display it
	inc hl                              ; advance string pointer
	ld a,(hl)                           ; peek at next char
	or a                                ; test for null terminator
	jr nz,print_str_loop                ; loop until end of string
		; Read command character
	ld b,0                              ; no flags for get_char_echo
	call get_char_echo                  ; read key, echo to screen → C
		; Bare Enter → default boot from drive 0
	ld a,c                              ; A = typed character
	cp CR                               ; Enter key?
	jp z,cmd_cr_boot                    ; yes → boot from drive 0
		; Not CR — echo ':' separator and match command letter
	ex af,af'                           ; save command char
	ld c,':'                            ; separator
	call putchar                        ; echo ':'
	ex af,af'                           ; restore command char
	cp '*'                              ; transparent terminal?
	jp z,cmd_star                       ; → terminal mode
	cp 'M'                              ; memory submenu?
	jp z,cmd_memory                     ; → memory inspect
	cp 'B'                              ; boot command?
	jr z,cmd_boot_parse                 ; → parse boot args
	cp 'G'                              ; go (execute)?
	jp z,cmd_go                         ; → execute at address
		; No valid command matched — signal error and re-prompt
cmd_error:
	ld c,ERR_CHAR                       ; error indicator char
	call putchar                        ; display error
	jr monitor_prompt                   ; re-prompt
		; Parse 'B' command: B<drive>,<sector>
cmd_boot_parse:
	ex af,af'                           ; save command context
		; Read drive number as hex
	call parse_hex                      ; DE = drive number, B = digit count
	dec b                               ; any digits entered?
	jp m,cmd_boot_default               ; no digits → default
		; Expect comma separator
	ld a,c                              ; A = terminator char from parse_hex
	cp ','                              ; must be comma
	jr nz,cmd_error                     ; not comma → syntax error
		; Validate drive number is 0 or 1
	ld a,d                              ; high byte of drive number
	or a                                ; must be zero
	jr nz,cmd_error                     ; high byte must be 0
	or e                                ; A = low byte (drive 0 or 1)
	cp 2                                ; drive >= 2?
	jr nc,cmd_error                     ; drive >= 2 invalid
		; Save drive number, parse starting sector
	push af                             ; save drive number on stack
	call parse_hex                      ; DE = starting sector
	dec b                               ; any digits entered?
	ld a,c                              ; A = terminator char
	pop bc                              ; B = drive number from stack
	jp m,cmd_error                      ; no digits → error
	cp CR                               ; must end with Enter
	jr nz,cmd_error                     ; not CR → syntax error

; ============================================================
; boot_floppy @ 0x00F6 — Floppy disk boot loader
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
	ex af,af'                           ; retrieve boot drive letter
	ld (stack_top),a                    ; save boot drive number
		; Select drive: bit 2 = drive 0, bit 3 = drive 1, bit 4 = motor on
setup_fdc_flags:
	ld hl,sys_flags                     ; point to system flags byte
	dec b                               ; B=0 → drive 0, B=1 → drive 1
	jr z,setup_drive1                   ; B was 1 → drive 1
	set 2,(hl)                          ; drive 0 select
	jr setup_drive_common               ; skip drive 1 setup
setup_drive1:
	set 3,(hl)                          ; drive 1 select
setup_drive_common:
	set 4,(hl)                          ; motor enable
	ld a,(hl)                           ; load combined flags
	out (PORT_SYS_CTRL),a               ; apply drive selection
		; Load floppy parameters table pointer
	ld hl,floppy_params                 ; ROM address of param table
	ld (floppy_prm_ptr),hl              ; save pointer for later use
		; Wait for FDC to become idle (bit 7 = not ready)
wait_drive_ready:
	in a,(PORT_FDC_CMD)                 ; read FDC status
	bit 7,a                             ; drive ready?
	jr nz,wait_drive_ready              ; not yet → keep polling
		; Long delay for drive motor spin-up / head settle
	ld de,49152                         ; 49152 iterations
settle_delay:
	ex (sp),hl                          ; waste cycles (2 mem accesses)
	ex (sp),hl                          ; restore HL
	dec de                              ; decrement delay counter
	ld a,e                              ; test if DE = 0
	or d                                ; combine both bytes
	jr nz,settle_delay                  ; loop until delay complete
		; Restore head to track 0, then read boot sector
read_boot_sector:
	call fdc_restore                    ; seek head to track 0
		; Load disk geometry from floppy parameters: sectors/track, heads
	ld hl,(floppy_prm_ptr)              ; HL = param table pointer
	ld a,(hl)                           ; first byte = sectors/track * 2
	rlca                                ; rotate to get heads in high bits
	inc hl                              ; advance to second param byte
	ld l,(hl)                           ; L = second byte of geometry
	ld h,a                              ; H = rotated first byte
	ld (disk_geom),hl                   ; store geometry (spt, heads)
		; Start reading from side 0, sector 1
	ld a,0                              ; side 0
	ld (fdc_side),a                     ; select side 0
	inc a                               ; A = 1
	ld (fdc_sector),a                   ; sector 1 (boot sector)
		; Read the boot sector; retry from restore if error
	call fdc_read_sector                ; read sector into buffer
	dec a                               ; A=1 → 0 on success
	jr nz,read_boot_sector              ; retry on error
		; Check boot config byte from sector data (offset +2)
		; Bits 7,6 control which RAM banks to enable at 0xFFFD
	ld a,(boot_cfg)                     ; load config byte from sector
	ld hl,0fffdh                        ; bank control address
	ld (hl),0                           ; start with no banks enabled
	bit 7,a                             ; test bank 1 flag
	jr z,check_bank2                    ; not set → skip
	set 1,(hl)                          ; enable bank 1
check_bank2:
	bit 6,a                             ; test bank 2 flag
	jr z,begin_record_load              ; not set → skip
	set 2,(hl)                          ; enable bank 2
		; Initialize record loading: zero bytes remaining in buffer
begin_record_load:
	ld hl,reset                         ; HL = 0 (zero)
	ld (buf_remain),hl                  ; buffer empty → force first read
	; --- MOS hex record parsing loop ---
		; Each record: length (C), type (B), optional address (HL), data bytes
parse_record:
	call get_next_byte                  ; read record length
	and a                               ; test for zero
	jp z,cmd_error                      ; zero length = bad record
	ld c,a                              ; C = byte count for this record
	call get_next_byte                  ; read record type
	ld b,a                              ; B = record type
		; If length >= 3, record has address (H:L) + extra byte
	ld a,c                              ; A = record length
	cp 3                                ; at least 3 bytes?
	jr c,dispatch_record                ; short record, skip addr
	call get_next_byte                  ; read address high byte
	ld h,a                              ; H = address high
	call get_next_byte                  ; read address low byte
	ld l,a                              ; L = address low
	call get_next_byte                  ; read extra byte (discarded)
		; Dispatch on record type
dispatch_record:
	ld a,b                              ; A = record type
	cp REC_DATA                         ; data record (0xC2)?
	jr z,load_data_record               ; 0xC2 = load data
	cp REC_ERROR                        ; error record (0xD2)?
	jp z,cmd_error                      ; 0xD2 = error/abort
	cp REC_EXEC                         ; exec record (0xC6)?
	jr z,exec_loaded_code               ; 0xC6 = run loaded code
		; Unknown record type — must be in valid range or abort
	cp REC_TYPE_MIN                     ; below 0xC1?
	jp c,cmd_error                      ; below valid range
	cp REC_TYPE_MAX                     ; above 0xDB?
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
	di                                  ; disable interrupts for bank switch
	push hl                             ; save entry point
	push de                             ; save DE
		; Copy trampoline code to RAM (can't run from ROM after bank switch)
	ld hl,trampoline                    ; source: trampoline code in ROM
	ld de,sector_buf                    ; dest: sector buffer in RAM
	ld bc,13                            ; 13 bytes to copy
	ldir                                ; block copy ROM → RAM
	pop de                              ; restore DE
	pop hl                              ; restore entry point to HL
	jp sector_buf                       ; jump to trampoline in RAM
	; --- Trampoline stub (copied to RAM and executed there) ---
		; Switches ROM out by writing to bank latch, then jumps to HL
trampoline:
	ld a,(sys_flags)                    ; load current system flags
	or SYS_BANK_SWITCH                  ; set bank switch bit
	ld (bank_latch),a                   ; latch: ROM out, RAM in
	ld a,SYS_BANK_SWITCH                ; bank switch value for port
	out (PORT_SYS_CTRL),a               ; system control mirrors it
	jp (hl)                             ; jump to loaded program

; ============================================================
; get_next_byte @ 0x01BD — Read next byte from sequential disk stream
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
	ld hl,(buf_remain)                  ; load remaining byte count
	ld a,h                              ; test high byte
	or l                                ; combine with low byte
	jr nz,buf_has_data                  ; still have bytes
		; Buffer exhausted — read next sector from disk
	push hl                             ; save HL (= 0)
	push de                             ; save caller's DE
	push bc                             ; save caller's BC
	ld hl,(disk_geom)                   ; load geometry (spt, heads)
	ex de,hl                            ; DE = geometry
	ld hl,(disk_lba)                    ; HL = current LBA
	call read_next_sector               ; read sector, returns HL = LBA+1
	ld (disk_lba),hl                    ; save updated LBA
	pop bc                              ; restore caller's BC
	pop de                              ; restore caller's DE
	pop hl                              ; restore HL
		; Reset buffer: 255 bytes remaining, pointer = sector_buf
	ld hl,setup_fdc_flags               ; HL = 0x00FF = 255 (address trick)
	ld (buf_remain),hl                  ; 255 bytes available
	ld hl,sector_buf                    ; point to start of buffer
	jr read_from_buf                    ; go read first byte
		; Buffer still has data — decrement count, load from read pointer
buf_has_data:
	dec hl                              ; one fewer byte remaining
	ld (buf_remain),hl                  ; update remaining count
	ld hl,(buf_rd_ptr)                  ; current read position
		; Fetch byte from buffer and advance read pointer
read_from_buf:
	ld a,(hl)                           ; read byte from buffer
	inc hl                              ; advance pointer
	ld (buf_rd_ptr),hl                  ; save updated pointer
	pop hl                              ; restore caller's HL
	dec c                               ; decrement record byte counter
	ret                                 ; return byte in A

; ============================================================
; read_next_sector @ 0x01FA — Convert LBA to CHS and read one sector
; Entry: HL = logical block address, DE = disk geometry
;        E = sectors per track, D = number of tracks
; Computes track/sector/side from LBA, seeks to the correct
; track, selects density (SD below track 22, DD above), and
; reads the sector. Retries with restore on any error.
; Returns: HL = LBA + 1 (next sector to read)
; ============================================================
read_next_sector:
	push hl                             ; save LBA for return value
	push de                             ; save geometry
		; Divide LBA by sectors-per-track: L = track, B = sector offset
	call div_hl_e                       ; HL / E → L=quotient, B=remainder
	ld a,b                              ; remainder = sector offset
	inc a                               ; sectors are 1-based
	ld (fdc_sector),a                   ; store physical sector number
		; Check track against max tracks (D)
	ld a,l                              ; L = track (including side bit)
	pop de                              ; restore DE (D = max tracks)
	cp d                                ; track >= max?
	jp nc,cmd_error                     ; past end of disk
		; Determine side from track parity: even = side 0, odd = side 1
	ld b,0                              ; B = side 0 (default)
	ld a,l                              ; A = logical track number
	or a                                ; clear carry, test A
	rra                                 ; divide by 2; LSB → carry
	jr nc,set_track                     ; carry clear = even → side 0
	ld b,2                              ; carry set = odd → side 1 (B=2)
set_track:
	ld (fdc_track),a                    ; physical track = LBA_track / 2
	ld a,b                              ; A = side select value
	ld (fdc_side),a                     ; store for FDC command
		; Seek to track and read sector; retry with restore on error
try_seek_read:
	call fdc_seek_read                  ; seek to target track
	jr nz,retry_seek_read               ; seek failed, retry
		; Set density based on track number (track >= 22 → double density)
	ld hl,sys_flags                     ; point to system flags
	ld a,(fdc_track)                    ; load current track number
	cp DD_TRACK_THRESH                  ; track >= 22?
	jr c,set_single_density             ; track < 22 → single density
	set 7,(hl)                          ; set DD flag (bit 7)
	jr apply_density                    ; apply to hardware
set_single_density:
	res 7,(hl)                          ; clear DD flag (bit 7)
apply_density:
	ld a,(hl)                           ; load updated flags
	out (PORT_SYS_CTRL),a               ; output updated flags
	call fdc_read_sector                ; read sector into buffer
	dec a                               ; A=1 success → 0, A=0 error → -1
	jr nz,retry_seek_read               ; read error → retry
	pop hl                              ; restore original LBA
	inc hl                              ; return LBA + 1
	ret                                 ; done
retry_seek_read:
	call fdc_restore                    ; restore to track 0
	jr try_seek_read                    ; try seek again

; ============================================================
; div_hl_e @ 0x0240 — Unsigned 16-bit by 8-bit division
; Entry: HL = dividend, E = divisor
; Returns: L = quotient, B = remainder
; Uses shift-and-subtract algorithm (16 iterations).
; ============================================================
div_hl_e:
	xor a                               ; clear accumulator (partial remainder)
	ld d,16                             ; 16-bit dividend = 16 iterations
div_loop:
	add hl,hl                           ; shift dividend left, MSB into A
	rla                                 ; rotate carry into A (partial remainder)
	jr c,div_subtract                   ; overflow → must subtract
	cp e                                ; partial remainder >= divisor?
	jr c,div_next_bit                   ; no → skip subtract
div_subtract:
	inc l                               ; set quotient bit
	sub e                               ; subtract divisor from remainder
div_next_bit:
	dec d                               ; count iterations
	jr nz,div_loop                      ; repeat for all 16 bits
	ld b,a                              ; B = final remainder
	ret                                 ; L = quotient, B = remainder

; ============================================================
; fdc_restore @ 0x0251 — Restore FDC head to track 0
; Aborts any pending command, issues restore, waits for
; completion, then delays for head settle time (~1ms).
; Returns: A = 0xFF if track-0 found, status bits if error
; ============================================================
fdc_restore:
	ld a,FDC_CMD_FORCE_INT              ; abort any pending command
	call fdc_send_cmd                   ; send force-interrupt
	ld a,FDC_CMD_RESTORE                ; restore to track 0
	call fdc_send_cmd                   ; issue restore command
		; Poll until FDC finishes (bit 0 = busy)
wait_restore_done:
	in a,(PORT_FDC_CMD)                 ; read FDC status
	bit 0,a                             ; still busy?
	jr nz,wait_restore_done             ; yes → keep polling
		; Check for head-load error (bit 2)
	bit 2,a                             ; head-load failed?
	jr nz,restore_settle                ; error: skip OK marker
	ld a,0ffh                           ; success marker
		; Head settle delay (~1000 iterations)
restore_settle:
	push af                             ; save result
	push hl                             ; save HL
	ld hl,1000                          ; 1000 iterations
settle_delay_loop:
	dec hl                              ; count down
	ld a,h                              ; test high byte
	or l                                ; combine with low byte
	jr nz,settle_delay_loop             ; loop until zero
	pop hl                              ; restore HL
	pop af                              ; restore result
	ret                                 ; return (A=0xFF=ok or status)

; ============================================================
; fdc_seek_read @ 0x0274 — Seek FDC head to target track
; Uses read-address-mark to discover current head position,
; then issues a seek command to the target track. If read-
; address fails (CRC or record-not-found), steps in and
; retries (up to 2 attempts). On complete failure, restores
; to track 0 and starts seek over.
; Returns: Z = success, NZ = error
; ============================================================
fdc_seek_read:
	ld a,FDC_CMD_FORCE_INT              ; abort any pending cmd
	call fdc_send_cmd                   ; send force-interrupt
		; Wait for FDC to go idle
wait_fdc_idle:
	in a,(PORT_FDC_CMD)                 ; read FDC status
	bit 0,a                             ; still busy?
	jr nz,wait_fdc_idle                 ; yes → keep waiting
	push bc                             ; save caller's BC
	ld b,2                              ; 2 attempts before full restore
		; Issue read-address to discover current physical track
read_addr_mark:
	ld a,FDC_CMD_READ_ADDR              ; read address mark command
	call fdc_send_cmd                   ; issue it
wait_addr_done:
	in a,(PORT_FDC_CMD)                 ; read FDC status
	bit 0,a                             ; still busy?
	jr z,fdc_check_status               ; command complete
	jr wait_addr_done                   ; still busy → poll
		; Read-address failed — step in one track and retry
fdc_step_in:
	ld a,FDC_CMD_FORCE_INT              ; abort failed command
	call fdc_send_cmd                   ; send force-interrupt
	ld a,FDC_CMD_STEP_IN                ; step head inward one track
	call fdc_send_cmd                   ; issue step-in
wait_step_done:
	in a,(PORT_FDC_CMD)                 ; read FDC status
	bit 0,a                             ; still busy?
	jr nz,wait_step_done                ; yes → keep waiting
	dec b                               ; decrement attempt counter
	jr nz,read_addr_mark                ; try read-address again
		; Both attempts failed — full restore and start over
	call fdc_restore                    ; restore to track 0
	pop bc                              ; restore caller's BC
	jr fdc_seek_read                    ; retry from scratch
		; Check read-address result: bits 4,3 = record-not-found, CRC error
fdc_check_status:
	bit 4,a                             ; record not found?
	jr nz,fdc_step_in                   ; try stepping in
	bit 3,a                             ; CRC error?
	jr nz,fdc_step_in                   ; try stepping in
		; Read-address OK — now seek to target track
	pop bc                              ; restore caller's BC
	in a,(PORT_FDC_SECTOR)              ; read-address returns track in sector reg
	out (PORT_FDC_TRACK),a              ; set FDC track to current position
	ld a,(fdc_track)                    ; target track
	out (PORT_FDC_DATA),a               ; target goes in data reg for seek
	ld a,FDC_CMD_SEEK                   ; seek command
	call fdc_send_cmd                   ; issue seek
		; Wait for seek to complete
wait_seek_done:
	in a,(PORT_FDC_CMD)                 ; read FDC status
	bit 0,a                             ; still busy?
	jr nz,wait_seek_done                ; yes → keep waiting
		; Check for seek errors (CRC + seek error bits)
	and FDC_STAT_ERR_SEEK               ; isolate error bits
	jr nz,fdc_seek_read                 ; seek error → retry
	ret                                 ; Z set = success

; ============================================================
; fdc_send_cmd @ 0x02CA — Send command byte to FDC with post-delay
; Entry: A = command byte
; Writes to FDC command port, then burns ~64 cycles for the
; FDC to latch the command before returning.
; ============================================================
fdc_send_cmd:
	out (PORT_FDC_CMD),a                ; issue command
	ld a,64                             ; 64 iterations
cmd_delay_loop:
	dec a                               ; decrement counter
	ret z                               ; done when counter hits 0
	jr cmd_delay_loop                   ; keep looping

; ============================================================
; fdc_read_sector @ 0x02D2 — Read one sector into sector_buf via NMI
; Sets FDC sector register and side flag, issues read-sector
; command. Data transfer happens byte-by-byte via NMI handler.
; Waits for completion and checks for read errors.
; Returns: A = 1 if success, A = 0 if error
; ============================================================
fdc_read_sector:
	ld a,(fdc_sector)                   ; load sector number
	out (PORT_FDC_SECTOR),a             ; set sector number
	ld hl,sector_buf                    ; NMI writes data here via (HL)
	ld b,FDC_CMD_READ_SEC               ; read-sector base command
	ld a,(fdc_side)                     ; load side select (0 or 2)
	or b                                ; OR side flag into command
	call fdc_send_cmd                   ; start the read
		; Wait for read to complete (NMI transfers data in background)
wait_read_done:
	in a,(PORT_FDC_CMD)                 ; read FDC status
	bit 0,a                             ; still busy?
	jr nz,wait_read_done                ; yes → NMI still transferring
		; Check for read errors (lost data, CRC, record not found)
	and FDC_STAT_ERR_READ               ; isolate error bits
	ld a,0                              ; pre-load error return value
	ret nz                              ; error: return 0
	ld a,1                              ; success: return 1
	ret                                 ; done

; ============================================================
; parse_hex @ 0x02F1 — Parse hex number from keyboard input
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
	ld a,c                              ; A = typed character
	sub '0'                             ; convert ASCII to value
	cp LF                               ; value < 10?
	jr c,hex_digit_valid                ; yes, 0-9 is valid
	cp 17                               ; gap between '9' and 'A'?
	ret c                               ; not a hex digit, return
	sub 7                               ; adjust A-F range
hex_digit_valid:
	cp 16                               ; value >= 16?
	ccf                                 ; complement carry for ret c test
	ret c                               ; not a hex digit
	inc b                               ; count this digit
		; Shift existing value left 4 bits and add new digit
	ld l,a                              ; L = new nibble value
	ld h,0                              ; HL = nibble (0x00-0x0F)
	ld a,16                             ; multiply DE by 16 via repeated add
hex_shift_loop:
	add hl,de                           ; HL += DE (16 times = DE * 16 + nibble)
	jp c,cmd_error                      ; overflow
	dec a                               ; decrement multiply counter
	jr nz,hex_shift_loop                ; loop 16 times total
	ex de,hl                            ; DE = updated value
	jr hex_next_char                    ; read next digit

; ============================================================
; cmd_star @ 0x0318 — Transparent terminal mode ('*' command)
; Echoes keystrokes directly to screen in a tight loop.
; Press ESC to exit back to the monitor prompt.
; ============================================================
cmd_star:
	call get_kbd_char                   ; read one key
	cp ESC                              ; ESC exits to monitor
	jp z,monitor_prompt                 ; ESC → back to prompt
	ld c,a                              ; C = character for putchar
	call putchar                        ; echo to screen
	jr cmd_star                         ; loop forever
		; cmd_cr_boot — Default boot on bare Enter key
		; Boots from drive 0 ('B'), starting at sector 0x0080
cmd_cr_boot:
	ld hl,128                           ; default start sector (128)
	ld a,'B'                            ; boot drive letter
	ex de,hl                            ; DE = start sector
	ex af,af'                           ; save drive letter in A'
	jp boot_floppy                      ; begin boot sequence
		; cmd_boot_default — 'B' with no args: drive 0, sector 1
cmd_boot_default:
	ld a,c                              ; A = terminator from parse_hex
	cp CR                               ; must be Enter
	jp nz,cmd_error                     ; not CR → error
	ld b,0                              ; drive 0
	ld de,reset+1                       ; sector 1 (DE = 0x0001)
	jp boot_floppy                      ; begin boot sequence

; ============================================================
; cmd_go @ 0x033E — Execute code at address ('G' command)
; Parses hex address, does bank-switch, jumps to it.
; ============================================================
cmd_go:
	call parse_hex                      ; parse hex address → DE
	dec b                               ; any digits entered?
	jp m,cmd_error                      ; no digits → error
	ld a,c                              ; A = terminator
	cp CR                               ; must be Enter
	jp nz,cmd_error                     ; not CR → error
	ex de,hl                            ; HL = target address
	jp exec_loaded_code                 ; bank-switch and jump

; ============================================================
; cmd_memory @ 0x034F — Memory inspection submenu ('M' command)
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
	call print_crlf                     ; new line for sub-prompt
	ld c,004h                           ; sub-prompt char (diamond)
	call putchar                        ; display sub-prompt
	call get_char_echo                  ; read sub-command key → C
	push bc                             ; save sub-command
	ld c,':'                            ; separator
	call putchar                        ; echo ':'
	pop bc                              ; restore sub-command
		; Dispatch sub-command letter
	ld a,c                              ; A = sub-command character
	cp 'R'                              ; return to main prompt
	jp z,monitor_prompt                 ; R → main prompt
	cp 'G'                              ; go (execute)?
	jr z,cmd_go                         ; G → execute at address
	cp 'D'                              ; dump?
	jr z,cmd_mem_dispatch               ; D → parse args
	cp 'M'                              ; modify?
	jr z,cmd_mem_dispatch               ; M → parse args
	cp 'I'                              ; in port?
	jr z,cmd_mem_dispatch               ; I → parse args
	cp 'O'                              ; out port?
	jr z,cmd_mem_dispatch               ; O → parse args
cmd_mem_error:
	ld c,ERR_CHAR                       ; error indicator
	call putchar                        ; display error
	jr cmd_memory                       ; re-prompt
		; Parse first hex argument, then dispatch by saved command letter
cmd_mem_dispatch:
	ex af,af'                           ; save command letter in A'
	call parse_hex                      ; DE = first hex arg
	dec b                               ; any digits entered?
	jp m,cmd_memory                     ; no digits entered → re-prompt
	ex af,af'                           ; restore command letter
	cp 'M'                              ; modify command?
	jr z,cmd_mem_modify                 ; M → modify memory
	cp 'I'                              ; input port command?
	jr z,cmd_mem_inport                 ; I → read port
		; D and O commands need a second argument after comma
	ex af,af'                           ; save command letter again
	ld a,c                              ; A = terminator from parse_hex
	cp ','                              ; must be comma separator
	jr nz,cmd_mem_error                 ; not comma → error
	push de                             ; save first arg (start addr or port)
	call parse_hex                      ; DE = second arg (end addr or value)
	pop hl                              ; HL = first arg
	dec b                               ; any digits for second arg?
	jp m,cmd_mem_error                  ; no digits → error
	ld a,c                              ; A = terminator
	cp CR                               ; must be Enter
	jr nz,cmd_mem_error                 ; not CR → error
	ex af,af'                           ; restore command letter
	cp 'O'                              ; output port?
	jr z,cmd_mem_outport                ; O → write port
		; Validate end > start, then set up dump loop
	call compare_hl_de                  ; start < end?
	jr nc,cmd_mem_error                 ; start >= end → error
	ex de,hl                            ; DE = start (current), HL = end
	push hl                             ; save end address on stack
	; --- Hex dump: print 16 bytes per line in 4 groups of 4 ---
cmd_mem_dump:
	call print_crlf                     ; new line
dump_print_addr:
	call print_address                  ; print current address
	ld a,4                              ; 4 groups per line
	ex af,af'                           ; save group counter in A'
dump_group:
	ld b,4                              ; 4 bytes per group
dump_byte:
	ld a,(de)                           ; read memory byte
	call print_hex_byte                 ; print as hex
	inc de                              ; advance to next address
	pop hl                              ; retrieve end address
	call compare_hl_de                  ; reached end?
	jp z,cmd_memory                     ; done → return to menu
	push hl                             ; save end address back
	ld a,e                              ; check low byte of address
	or a                                ; page boundary (E=0)?
	jr z,cmd_mem_dump                   ; page boundary → new line
	ld c,' '                            ; space separator
	call putchar                        ; print space
	djnz dump_byte                      ; next byte in group
	call putchar                        ; extra space between groups
	ex af,af'                           ; retrieve group counter
	dec a                               ; decrement group counter
	jr z,dump_print_addr                ; 4 groups done → new line
	ex af,af'                           ; save counter back
	jr dump_group                       ; next group
		; cmd_mem_inport — Read and display I/O port value
cmd_mem_inport:
	ld a,c                              ; A = terminator from parse_hex
	cp CR                               ; must be Enter
	jp nz,cmd_mem_error                 ; not CR → error
	call print_address                  ; print port number
	ld b,d                              ; BC = port address (16-bit)
	ld c,e                              ; (from DE parsed value)
	in d,(c)                            ; read I/O port → D
	ld a,d                              ; A = port value
	call print_hex_byte                 ; display as hex
	jp cmd_memory                       ; return to menu
		; cmd_mem_outport — Write value to I/O port
cmd_mem_outport:
	ld a,d                              ; high byte of port address
	or a                                ; must be zero (8-bit port)
	jp nz,cmd_mem_error                 ; non-zero → error
	ld b,h                              ; BC = port (from HL = first arg)
	ld c,l                              ; C = port number
	out (c),e                           ; write value E to port
	jp cmd_memory                       ; return to menu
		; cmd_mem_modify — Modify memory byte-by-byte
		; Shows current value, reads new hex value, writes it.
		; Enter '.' to stop, CR to advance without changing.
cmd_mem_modify:
	ld a,c                              ; A = terminator from parse_hex
	cp CR                               ; must be Enter
	jp nz,cmd_mem_error                 ; not CR → error
mem_modify_loop:
	call print_address                  ; show address
	ex de,hl                            ; HL = current address
	push hl                             ; save it
	ld a,(hl)                           ; read current byte
	call print_hex_byte                 ; display current value
	ld c,' '                            ; space separator
	call putchar                        ; print space
	call parse_hex                      ; read new value → DE
	pop hl                              ; restore address
	ld a,c                              ; A = terminator
	cp '.'                              ; dot = quit modify
	jp z,cmd_memory                     ; '.' → return to menu
	cp CR                               ; Enter = accept/skip
	jp nz,cmd_mem_error                 ; other → error
	dec b                               ; any digits entered?
	jp m,mem_modify_next                ; no digits → skip (don't write)
	ld (hl),e                           ; write new value to memory
mem_modify_next:
	inc hl                              ; advance to next address
	ex de,hl                            ; DE = address for print_address
	jr mem_modify_loop                  ; continue modifying

; ============================================================
; nibble_to_ascii @ 0x042C — Convert low nibble of A to ASCII hex char
; Uses the classic DAA trick: A + 0x90 + DAA + 0x40 + DAA
; converts 0x0-0xF → '0'-'9', 'A'-'F'.
; Returns: A = ASCII hex character
; ============================================================
nibble_to_ascii:
	and 00fh                            ; isolate low nibble (0-F)
	add a,090h                          ; offset for DAA trick
	daa                                 ; decimal adjust
	adc a,040h                          ; second offset + carry
	daa                                 ; produces '0'-'9' or 'A'-'F'
	ret                                 ; A = ASCII hex character
; ============================================================
; negate_add_hl_de @ 0x0435 — ORPHAN (unreferenced dead code)
; Computes HL = DE - HL (two's complement negate HL, add DE).
; Likely a utility left over from development; never called
; by any code path in this ROM.
; ============================================================
negate_add_hl_de:
	ld a,l                              ; load L
	cpl                                 ; complement L (one's complement)
	ld l,a                              ; store back
	ld a,h                              ; load H
	cpl                                 ; complement H
	ld h,a                              ; store back
	inc hl                              ; HL = ~HL + 1 = -HL (two's complement)
	add hl,de                           ; HL = DE - original_HL
	ret                                 ; return result in HL
; ============================================================
; sub_l_a @ 0x043E — ORPHAN (unreferenced dead code)
; Computes L = L - A (with borrow into H).
; Another unused utility; no call or jump targets this
; address anywhere in the ROM.
; ============================================================
sub_l_a:
	push bc                             ; save BC
	ld b,a                              ; B = subtrahend
	ld a,l                              ; A = L
	sub b                               ; A = L - B
	ld l,a                              ; L = result
	pop bc                              ; restore BC
	ret nc                              ; no borrow → done
	dec h                               ; propagate borrow into H
	ret                                 ; done

; ============================================================
; compare_hl_de @ 0x0447 — Compare HL with DE
; Returns: Z flag set if HL == DE, NZ if different.
; ============================================================
compare_hl_de:
	ld a,h                              ; compare high bytes
	cp d                                ; H == D?
	ret nz                              ; different → return NZ
	ld a,l                              ; compare low bytes
	cp e                                ; L == E?
	ret                                 ; Z if equal, NZ if not

; ============================================================
; print_crlf @ 0x044D — Output carriage return + line feed
; ============================================================
print_crlf:
	ld c,CR                             ; carriage return char
	jr putchar                          ; output CR (putchar adds LF)

; ============================================================
; print_hex_byte @ 0x0451 — Print byte in A as two hex digits
; Converts low nibble first (saves to H), then shifts high
; nibble down and prints high digit first, then low digit.
; ============================================================
print_hex_byte:
	push af                             ; save original byte
	call nibble_to_ascii                ; convert low nibble
	ld h,a                              ; save low digit in H
	pop af                              ; restore original byte
		; Shift high nibble into low position
	rra                                 ; shift right 4 times
	rra                                 ; to move bits 7-4
	rra                                 ; into bits 3-0
	rra                                 ; A = high nibble
	call nibble_to_ascii                ; convert high nibble
	ld c,a                              ; C = high digit for putchar
	call putchar                        ; print high digit first
	ld c,h                              ; C = low digit
	jr putchar                          ; then low digit

; ============================================================
; print_address @ 0x0465 — Print CRLF, then DE as 4 hex digits + space
; ============================================================
print_address:
	call print_crlf                     ; start on new line
	ld a,d                              ; high byte of address
	call print_hex_byte                 ; print high byte
	ld a,e                              ; low byte of address
	call print_hex_byte                 ; print low byte
	ld c,' '                            ; trailing space
	call putchar                        ; print space
	jr putchar                          ; extra space (double-spaced)

; ============================================================
; get_kbd_char @ 0x0477 — Read one key from keyboard with auto-repeat
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
	ld a,LUCY_REG_KBD                   ; select LUCY keyboard register
	out (PORT_LUCY_REG),a               ; address register 7
	in a,(PORT_LUCY_DATA)               ; read keyboard status
		; Bit 1 = key released event
	bit 1,a                             ; key released event?
	jr z,kbd_check_repeat               ; no release → check repeat
		; Key was released — reset debounce state
	push af                             ; save status flags
	xor a                               ; A = 0
	ld (kbd_state),a                    ; state = no key held
	pop af                              ; restore status flags
		; Check if a new key is also pressed right now (bit 0)
	bit 0,a                             ; key currently pressed?
	jr z,get_kbd_char                   ; no key → keep polling
		; Key pressed — read the scancode from KR3600
read_kbd_data:
	in a,(PORT_KBD_DATA)                ; read scancode from KR3600
	and KBD_DATA_MASK                   ; mask to 7-bit ASCII
	ld (kbd_last),a                     ; save for auto-repeat
	ret                                 ; return key in A
		; No release event — check if we're in repeat mode
kbd_check_repeat:
	ld a,(kbd_state)                    ; load debounce state
	or a                                ; state == 0 (no key)?
	jr z,kbd_first_press                ; first time seeing this key
		; In repeat mode — check if key is still pressed
	in a,(PORT_LUCY_DATA)               ; read LUCY status
	bit 0,a                             ; key still pressed?
	jr nz,read_kbd_data                 ; still pressed → read fresh data
		; Key released during repeat — delay, then return last key
	push bc                             ; save BC
	ld bc,2560                          ; ~2560 iteration delay
kbd_repeat_delay:
	dec bc                              ; decrement counter
	ld a,b                              ; test high byte
	or c                                ; combine with low byte
	jr nz,kbd_repeat_delay              ; loop until zero
	pop bc                              ; restore BC
kbd_return_cached:
	ld a,(kbd_last)                     ; load last key code
	ret                                 ; return cached key
		; First key press — mark state and wait for key data ready
kbd_first_press:
	ld a,1                              ; state = key held
	ld (kbd_state),a                    ; mark as first press
kbd_wait_key:
	in a,(PORT_LUCY_DATA)               ; poll LUCY status
	bit 0,a                             ; data ready?
	jr z,kbd_wait_key                   ; wait for data ready
	in a,(PORT_KBD_DATA)                ; read KR3600 scancode
	ld (kbd_last),a                     ; save key code
		; Check if key was already released before we read it
	in a,(PORT_LUCY_DATA)               ; read LUCY status again
	bit 1,a                             ; key released?
	jr z,kbd_return_cached              ; still held → return it
		; Key released between press and read — reset state
	xor a                               ; A = 0
	ld (kbd_state),a                    ; back to idle
	jr kbd_return_cached                ; return the key anyway

; ============================================================
; get_char_echo @ 0x04C9 — Read key and echo to display
; Calls get_kbd_char, then falls through to putchar.
; ============================================================
get_char_echo:
	call get_kbd_char                   ; read one key → A
	ld c,a                              ; C = key for putchar (fall through)

; ============================================================
; putchar @ 0x04CD — Output character to video display
; Entry: C = character to display
; Handles CR (new line + reset column), LF (advance row),
; and printable characters (write to VRAM + advance cursor).
; Saves/restores all registers. Updates cursor on exit.
; ============================================================
putchar:
	push bc                             ; save registers
	push de                             ; |
	push hl                             ; |
	ld a,c                              ; A = character to display
	cp CR                               ; carriage return?
	jr z,handle_cr                      ; → handle CR
	cp LF                               ; line feed?
	jr z,handle_lf                      ; → handle LF
		; Printable character — write to VRAM and move cursor right
	ld (vram_char),a                    ; set character for VRAM write
	ld a,ATTR_NORMAL                    ; normal text attribute
	ld (vram_attr),a                    ; set attribute
	call write_vram                     ; write to video RAM
	call advance_cursor                 ; move cursor right
		; Restore registers and show cursor at new position
putchar_done:
	call cursor_on                      ; display cursor block
	pop hl                              ; restore registers
	pop de                              ; |
	pop bc                              ; |
	ret                                 ; done
		; CR: erase cursor, advance row, reset column to 0
handle_cr:
	call cursor_off                     ; erase old cursor
	call advance_row                    ; move down one row
	call reset_column                   ; column = 0
	jr putchar_done                     ; update cursor
reset_column:
	xor a                               ; A = 0
	ld (cursor_col),a                   ; reset column to 0
	ret                                 ; done
		; LF: erase cursor, advance row (column unchanged)
handle_lf:
	call cursor_off                     ; erase old cursor
	call advance_row                    ; move down one row
	jr putchar_done                     ; update cursor

; ============================================================
; advance_cursor @ 0x0506 — Move cursor right by one character position
; The SAA5120 uses split-column addressing: columns 0-39 in
; the left half (bit 7 clear), 40-79 in the right half (bit 7
; set). Advances within a half, toggles between halves at
; the boundary, and wraps to next row at column 80.
; ============================================================
advance_cursor:
	ld a,(cursor_col)                   ; load current column
	cp COL_LAST                         ; at last column (0xA7)?
	jr z,col_overflow                   ; yes → wrap to next line
	bit 7,a                             ; in right half?
	jr z,toggle_half                    ; no → toggle to right
	inc a                               ; right half: also increment
toggle_half:
	xor COL_HALF                        ; flip half-select bit
	ld (cursor_col),a                   ; save updated column
	ret                                 ; done
		; Past last column — wrap to column 0 of next row
col_overflow:
	call reset_column                   ; column = 0
	call advance_row                    ; move to next row
	ret                                 ; done
		; advance_row — Move cursor down one row, scrolling if at bottom
advance_row:
	ld a,(cursor_row)                   ; load current row
	cp LAST_ROW                         ; at row 24 (last row)?
	jr z,scroll_screen                  ; yes → scroll
	ld a,(cursor_row)                   ; reload row
	inc a                               ; simply move down one row
	ld (cursor_row),a                   ; save new row
	ret                                 ; done

; ============================================================
; scroll_screen @ 0x052E — Scroll display up one line
; Increments the SAA5120 hardware scroll register (offset of
; first visible row), wraps at row 25, then clears the newly
; exposed bottom row with spaces. This is zero-copy hardware
; scrolling — no data is moved in VRAM.
; ============================================================
scroll_screen:
	ld a,(cursor_col)                   ; save current column
	push af                             ; on stack
		; Increment scroll offset and program hardware
	ld a,(scroll_off)                   ; current scroll offset
	inc a                               ; advance by one row
	ld (scroll_off),a                   ; save new offset
	cp SCREEN_ROWS                      ; past row 25?
	jr z,scroll_wrap                    ; yes → wrap to 0
	out (PORT_SCROLL_ALT),a             ; set scroll register
		; Clear the newly exposed bottom row
clear_new_row:
	xor a                               ; A = 0
	ld (cursor_col),a                   ; start at column 0
	ld a,' '                            ; space character
	ld (vram_char),a                    ; set char for fill
	ld a,ATTR_NORMAL                    ; normal attribute
	ld (vram_attr),a                    ; set attr for fill
	call fill_row_spaces                ; fill row with spaces
	pop af                              ; restore cursor column
	ld (cursor_col),a                   ; put cursor back
	ret                                 ; done
		; Scroll offset wrapped past 25 — reset to 0
scroll_wrap:
	xor a                               ; A = 0
	ld (scroll_off),a                   ; reset scroll offset
	out (PORT_SCROLL),a                 ; program hardware scroll = 0
	jr clear_new_row                    ; clear the exposed row

; ============================================================
; clear_screen @ 0x055D — Clear entire 25×80 display
; Fills all rows with spaces + normal attribute, resets
; scroll offset and column, updates cursor.
; ============================================================
clear_screen:
	xor a                               ; start at row 0
clear_row_loop:
	ld (cursor_row),a                   ; set current row
	xor a                               ; A = 0
	ld (cursor_col),a                   ; start at column 0
	ld a,' '                            ; space character
	ld (vram_char),a                    ; set char for fill
	ld a,ATTR_NORMAL                    ; normal attribute
	ld (vram_attr),a                    ; set attr for fill
	call fill_row_spaces                ; fill entire row
	ld a,(cursor_row)                   ; load current row
	inc a                               ; next row
	cp SCREEN_ROWS                      ; done all 25?
	jr nz,clear_row_loop                ; no → loop
	xor a                               ; A = 0
	ld (cursor_col),a                   ; reset column
	out (PORT_SCROLL),a                 ; reset hardware scroll
	ld (scroll_off),a                   ; reset scroll offset
	call cursor_on                      ; show cursor
	ret                                 ; done

; ============================================================
; fill_row_spaces @ 0x0587 — Fill current row from current column onward
; Handles SAA5120 split-column addressing: writes left half
; (cols 0-39), then switches to right half (0x80-0xA7).
; Returns when column wraps past 0xA7.
; ============================================================
fill_row_spaces:
	call write_vram                     ; write space at current col
	ld a,(cursor_col)                   ; load current column
	inc a                               ; advance to next column
	ld (cursor_col),a                   ; save it
	bit 7,a                             ; in right half?
	jr nz,fill_check_done               ; yes → check wrap
	cp COL_HALF_COUNT                   ; reached col 40?
	jr nz,fill_row_spaces               ; no → keep going
		; Switch to right half (bit 7 set, counter at 0x80)
	ld a,COL_HALF                       ; 0x80 = right-half base
	ld (cursor_col),a                   ; switch to right half
	jr fill_row_spaces                  ; continue filling
fill_check_done:
	cp COL_WRAP                         ; past last right-half col?
	jr nz,fill_row_spaces               ; no → keep going
	ret                                 ; row complete

; ============================================================
; write_vram @ 0x05A5 — Write character + attribute to video RAM
; Reads cursor position, character, and attribute from RAM
; variables, then programs the SAA5120 via I/O ports. Waits
; for LUCY video sync (blanking interval) before writing to
; avoid display glitches. The SAA5120 has a peculiar write
; protocol: two character writes (with/without strobe bit)
; paired with two attribute writes.
; ============================================================
write_vram:
		; Load cursor_row, cursor_col, vram_char, vram_attr into regs
	ld hl,cursor_row                    ; point to cursor data block
	ld a,(hl)                           ; A = row number
	out (PORT_VIDEO_ROW),a              ; set row address
	inc hl                              ; advance to cursor_col
	ld d,(hl)                           ; D = column (without strobe)
	ld a,(hl)                           ; A = column value
	or VID_WRITE_STROBE                 ; set bit 6 for write
	ld b,a                              ; B = column with write strobe
	inc hl                              ; advance to vram_char
	ld c,(hl)                           ; C = character code
	inc hl                              ; advance to vram_attr
	ld e,(hl)                           ; E = attribute
		; Wait for video blanking interval (bit 0 of LUCY scan reg)
	ld hl,sys_flags                     ; point to system flags
	set 5,(hl)                          ; mark sync-pending in flags
	ld a,LUCY_REG_SCAN                  ; LUCY scan control register
	out (PORT_LUCY_REG),a               ; select it
wait_video_sync:
	in a,(PORT_LUCY_DATA)               ; read LUCY scan status
	bit 0,a                             ; blanking active?
	jr z,wait_video_sync                ; wait for blanking
		; Critical timing section — write char+attr during blanking
	ld a,(hl)                           ; read sys_flags
	res 5,(hl)                          ; clear sync-pending flag
	ld h,(hl)                           ; H = sys_flags (for later restore)
	push hl                             ; | push+pop provides
	pop hl                              ; | small timing delay
	out (PORT_SYS_CTRL),a               ; activate video write mode
		; Write: strobe column + char, then plain column + attr
	ld a,b                              ; column with strobe
	out (PORT_VIDEO_CHAR),a             ; 1st char write (strobe)
	ld a,c                              ; character code
	out (PORT_VIDEO_ATTR),a             ; 1st attr write
	ld a,d                              ; column without strobe
	out (PORT_VIDEO_CHAR),a             ; 2nd char write
	ld a,e                              ; attribute value
	out (PORT_VIDEO_ATTR),a             ; 2nd attr write
		; Restore system control to previous state
	ld a,h                              ; original sys_flags
	out (PORT_SYS_CTRL),a               ; restore control port
	ret                                 ; done

; ============================================================
; cursor_on @ 0x05DC — Show cursor block (inverted attribute)
; Writes space with XOR'd attribute to create visible cursor.
; ============================================================
cursor_on:
	ld a,' '                            ; space character (block cursor)
	ld (vram_char),a                    ; set character
	ld a,ATTR_NORMAL                    ; base attribute
	xor ATTR_CURSOR_XOR                 ; invert attribute bits
	ld (vram_attr),a                    ; set inverted attribute
	call write_vram                     ; write cursor block
	ret                                 ; done

; ============================================================
; cursor_off @ 0x05EC — Remove cursor block (restore normal attribute)
; Writes space with normal attribute to erase cursor.
; ============================================================
cursor_off:
	ld a,' '                            ; space character
	ld (vram_char),a                    ; set character
	ld a,ATTR_NORMAL                    ; normal attribute (no inversion)
	ld (vram_attr),a                    ; set attribute
	call write_vram                     ; overwrite cursor with blank
	ret                                 ; done

; ============================================================
; post_start @ 0x05FA — Power-On Self Test (POST)
; Tests all major hardware subsystems in sequence:
;   1. Video RAM: write/verify pattern to all 25×80 cells
;   2. Main RAM: write/verify 32KB pattern (both banks)
;   3. FDC: verify track/sector/data registers hold values
;   4. Serial: UART loopback test (TX→RX, full byte range)
;   5. Timer: IM1 tick count in calibrated loop (expect 35-36)
; Error bits accumulate in A' (bit 0=VRAM, 1=RAM, 2=FDC,
; 3=serial, 4=timer). Displays "AUTO-TEST : OK" or error nums.
; ============================================================
post_start:
		; A' = error accumulator, start at 0
	ex af,af'                           ; switch to shadow A
	xor a                               ; clear error bits
	ex af,af'                           ; switch back
		; Enable system (LED on)
	ld a,SYS_ACTIVE                     ; system active flag
	out (PORT_SYS_CTRL),a               ; LED on, drives ready
	; --- TEST 1: Video RAM ---
		; Write incrementing pattern (+0x55) to every cell, then verify.
		; The SAA5120 uses a two-phase write protocol per cell: the
		; column address is written twice — once with bit 6 (strobe)
		; set, once without — each paired with an attribute byte.
		; This write pass stores two running pattern values per cell
		; (one per phase), advancing C by +0x55 each time.
	xor a                               ; start at row 0
	ld c,0                              ; C = running test pattern
post_vram_write:
	ld d,0                              ; D = column counter (0..79)
	out (PORT_VIDEO_ROW),a              ; set row address
	ld h,a                              ; save row in H
	ld a,d                              ; A = column counter
post_vram_col_write:
		; Column rotation: RRCA produces the SAA5120 column address
		; from a linear 0-79 counter (maps 0-39 to left half, 40-79
		; to right half via the carry/high-bit rotation).
	rrca                                ; rotate column into SAA5120 format
	ld b,a                              ; B = column without strobe
	or VID_WRITE_STROBE                 ; set bit 6 = write strobe
	out (PORT_VIDEO_CHAR),a             ; phase 1: column WITH strobe
	ld a,c                              ; current pattern value
	out (PORT_VIDEO_ATTR),a             ; phase 1: write pattern byte
	add a,TEST_PATTERN                  ; advance pattern (+0x55)
	ld c,a                              ; update running pattern
	ld a,b                              ; column WITHOUT strobe
	out (PORT_VIDEO_CHAR),a             ; phase 2: column without strobe
	ld a,c                              ; current pattern value
	out (PORT_VIDEO_ATTR),a             ; phase 2: write next pattern byte
	add a,TEST_PATTERN                  ; advance pattern again
	ld c,a                              ; update running pattern
	inc d                               ; next column
	ld a,d                              ; A = column counter
	cp SCREEN_COLS                      ; done all 80 columns?
	jr nz,post_vram_col_write           ; no → next column
	ld a,h                              ; restore row
	inc a                               ; next row
	cp SCREEN_ROWS                      ; done all 25 rows?
	jr nz,post_vram_write               ; no → next row
		; VRAM verify pass: replay the same pattern and read back.
		; Reads attribute via IN after selecting the column; compares
		; against the expected pattern. Clears the attr port (OUT 0)
		; between reads to reset the SAA5120 latch for the next phase.
	xor a                               ; start at row 0
	ld c,0                              ; reset test pattern to match write pass
post_vram_verify:
	ld d,0                              ; D = column counter
	out (PORT_VIDEO_ROW),a              ; set row address
	ld h,a                              ; save row
	ld a,d                              ; A = column counter
post_vram_col_verify:
	rrca                                ; rotate column into SAA5120 format
	ld b,a                              ; B = column without strobe
	or VID_WRITE_STROBE                 ; set strobe bit
	out (PORT_VIDEO_CHAR),a             ; select column (phase 1)
	in a,(PORT_VIDEO_ATTR)              ; read back stored attribute
	cp c                                ; compare against expected pattern
	jr nz,post_vram_fail                ; mismatch → VRAM error
	add a,TEST_PATTERN                  ; advance expected pattern
	ld c,a                              ; update expected pattern
	xor a                               ; A = 0
	out (PORT_VIDEO_ATTR),a             ; clear attr latch for phase 2
	ld a,b                              ; column without strobe
	out (PORT_VIDEO_CHAR),a             ; select column (phase 2)
	in a,(PORT_VIDEO_ATTR)              ; read back second attribute
	cp c                                ; compare against expected
	jr nz,post_vram_fail                ; mismatch → VRAM error
	add a,TEST_PATTERN                  ; advance expected pattern
	ld c,a                              ; update expected pattern
	xor a                               ; A = 0
	out (PORT_VIDEO_ATTR),a             ; clear attr latch
	inc d                               ; next column
	ld a,d                              ; A = column counter
	cp SCREEN_COLS                      ; done all 80?
	jr nz,post_vram_col_verify          ; no → next column
	ld a,h                              ; restore row
	inc a                               ; next row
	cp SCREEN_ROWS                      ; done all 25?
	jr nz,post_vram_verify              ; no → next row
	jr post_ram_test                    ; VRAM OK → test RAM
		; VRAM test failed — set error bit 0
post_vram_fail:
	ex af,af'                           ; switch to error accumulator
	set 0,a                             ; bit 0 = VRAM error
	ex af,af'                           ; switch back
	; --- TEST 2: Main RAM (32KB at 0x8000) ---
		; Write incrementing pattern byte-by-byte, then verify
post_ram_test:
	ld hl,08000h                        ; start address (32KB mark)
	ld de,08000h                        ; block size (32KB)
	jr ram_test_write                   ; begin write pass
		; Second pass: test bank 2 (re-entered from relocated code)
ram_test_bank2:
	ld a,SYS_RAM_TEST                   ; select test bank (0x60)
	out (PORT_SYS_CTRL),a               ; switch to RAM test bank
ram_test_write:
	ld c,128                            ; 128 pages = 32KB
	ld a,0                              ; starting pattern value
ram_write_page:
	ld b,0                              ; 256 bytes per page
ram_write_byte:
	ld (hl),a                           ; write pattern byte
	inc hl                              ; advance address
	add a,TEST_PATTERN                  ; rotate pattern (+0x55)
	djnz ram_write_byte                 ; loop 256 bytes
	dec c                               ; next page
	jr nz,ram_write_page                ; loop 128 pages
		; Verify pass: compare pattern against written data
	ld hl,reset                         ; HL = 0
	add hl,de                           ; HL = start of test region
	ld c,128                            ; 128 pages
	ld a,0                              ; same starting pattern
ram_verify_page:
	ld b,0                              ; 256 bytes per page
ram_verify_byte:
	cp (hl)                             ; compare with written pattern
	jr nz,ram_verify_fail               ; mismatch → RAM error
	inc hl                              ; advance address
	add a,TEST_PATTERN                  ; rotate expected pattern
	djnz ram_verify_byte                ; loop 256 bytes
	dec c                               ; next page
	jr nz,ram_verify_page               ; loop 128 pages
		; RAM verify OK — copy test code to high RAM for bank 2 test
	ld hl,reset                         ; HL = 0 (marker for bank 2 done)
	jr copy_ramtest_high                ; set up relocated test
		; RAM verify failed
ram_verify_fail:
	ld a,h                              ; check if we're in bank 2 test
	or l                                ; HL=0 means bank 2 pass
	jr z,ram_test_exit                  ; HL=0 means bank2 test done
	ex af,af'                           ; switch to error accumulator
	set 1,a                             ; bit 1 = RAM error
	ex af,af'                           ; switch back
ram_test_exit:
	ld a,SYS_ACTIVE                     ; normal system mode
	out (PORT_SYS_CTRL),a               ; restore normal banking
	jp post_fdc_test                    ; continue to FDC test
		; Copy ram_test_bank2 routine to 0x8000+ so it can test low RAM
copy_ramtest_high:
	ld hl,ram_test_bank2                ; source: test routine in ROM
	ld de,0866dh                        ; dest: relocated address in RAM
	ld bc,60                            ; size = 60 bytes
	ldir                                ; block copy ROM → RAM
		; Patch relocated copy's data pointers
	ld hl,reset                         ; HL = 0 (start address for bank 2)
	ld de,reset                         ; DE = 0 (block size for bank 2)
	ld (08698h),hl                      ; patch start address in copy
	jp 0866dh                           ; jump to relocated test
	; --- TEST 3: FDC register test ---
		; Write incrementing pattern to track/sector/data regs, read back
post_fdc_test:
	ld a,FDC_CMD_FORCE_INT              ; abort any command
	out (PORT_FDC_CMD),a                ; send force-interrupt
	xor a                               ; start pattern at 0
fdc_test_write:
	ld c,a                              ; save current pattern
	out (PORT_FDC_TRACK),a              ; write to track register
	add a,TEST_PATTERN                  ; advance pattern (+0x55)
	out (PORT_FDC_SECTOR),a             ; write to sector register
	add a,TEST_PATTERN                  ; advance again
	out (PORT_FDC_DATA),a               ; write to data register
	ld b,80                             ; settle delay (80 iterations)
fdc_test_settle:
	djnz fdc_test_settle                ; wait for registers to settle
		; Read back and compare each register
	in a,(PORT_FDC_TRACK)               ; read track register
	cp c                                ; matches written value?
	jr nz,fdc_test_fail                 ; mismatch → FDC error
	add a,TEST_PATTERN                  ; compute expected sector value
	ld c,a                              ; save expected
	in a,(PORT_FDC_SECTOR)              ; read sector register
	cp c                                ; matches expected?
	jr nz,fdc_test_fail                 ; mismatch → FDC error
	add a,TEST_PATTERN                  ; compute expected data value
	ld c,a                              ; save expected
	in a,(PORT_FDC_DATA)                ; read data register
	cp c                                ; matches expected?
	jr nz,fdc_test_fail                 ; mismatch → FDC error
	add a,TEST_PATTERN                  ; advance to next pattern set
	or a                                ; wrapped to 0? (full cycle done)
	jr z,post_serial_setup              ; yes → FDC test passed
	ld b,80                             ; inter-pass settle delay
fdc_test_delay:
	djnz fdc_test_delay                 ; wait
	jr fdc_test_write                   ; next pattern set
		; FDC test failed — set error bit 2
fdc_test_fail:
	ex af,af'                           ; switch to error accumulator
	set 2,a                             ; bit 2 = FDC error
	ex af,af'                           ; switch back
	ld a,FDC_CMD_FORCE_INT              ; clean up
	out (PORT_FDC_CMD),a                ; abort any pending FDC command
	; --- TEST 4: Serial port (UART loopback) ---
		; Configure 2661 UART for 8N1 with loopback, send incrementing
		; pattern, verify each byte echoes back correctly.
post_serial_setup:
	ld a,SYS_ACTIVE                     ; normal system mode
	out (PORT_SYS_CTRL),a               ; restore system control
	ld a,UART_MODE1_VAL                 ; 8N1 config
	out (PORT_UART_MODE),a              ; set mode register 1
	ld a,UART_MODE2_VAL                 ; 16x clock divisor
	out (PORT_UART_MODE),a              ; set mode register 2
	ld a,UART_CMD_VAL                   ; TX/RX enable + loopback
	out (PORT_UART_CMD),a               ; configure UART command
	ld c,0                              ; start pattern at 0
		; Send test byte and wait for loopback echo
post_serial_test:
	ld d,255                            ; timeout counter
wait_uart_txready:
	dec d                               ; decrement timeout counter
	jr z,serial_test_fail               ; timeout → UART stuck
	in a,(PORT_UART_STATUS)             ; read UART status
	and 001h                            ; TX ready bit?
	jr z,wait_uart_txready              ; not ready → keep waiting
	ld a,c                              ; A = test pattern byte
	out (PORT_UART_DATA),a              ; transmit byte (loopback)
		; Delay for loopback propagation
	xor a                               ; A = 0 (256-iteration delay)
uart_rx_delay:
	dec ix                              ; waste time (IX unused)
	dec a                               ; decrement delay counter
	jr nz,uart_rx_delay                 ; loop 256 times
		; Read back and compare
	in a,(PORT_UART_DATA)               ; read loopback echo
	cp c                                ; matches sent byte?
	jr nz,serial_test_fail              ; mismatch → serial error
		; Advance pattern, loop until full byte range tested
	add a,TEST_PATTERN                  ; rotate pattern (+0x55)
	ld c,a                              ; save updated pattern
	or a                                ; wrapped to 0? (all values tested)
	jr nz,post_serial_test              ; no → test next value
	jp post_timer_test                  ; serial OK → timer test
		; Serial test failed — set error bit 3
serial_test_fail:
	ex af,af'                           ; switch to error accumulator
	set 3,a                             ; bit 3 = serial error
	ex af,af'                           ; switch back
	; --- TEST 5: Timer/interrupt test ---
		; Enable IM1, count ticks during a calibrated loop.
		; D is incremented by the IRQ handler each tick.
		; Expect 35-36 ticks; outside range = timer failure.
post_timer_test:
	ld hl,reset                         ; HL = 0 (will count down 65536)
	ld d,0                              ; D = tick counter (IRQ increments)
	im 1                                ; use IM1 handler at 0x0038
	ei                                  ; enable interrupts, start counting
timer_count_loop:
	dec hl                              ; count down from 0 (= 65536)
	ld a,h                              ; test high byte
	or l                                ; combine with low byte
	jr nz,timer_count_loop              ; loop until zero
	di                                  ; stop counting
		; Check tick count is in expected range [0x23, 0x24]
	ld a,d                              ; D = number of ticks
	cp 35                               ; < 35 = too slow
	jr c,timer_test_fail                ; too few ticks → timer slow
	cp 37                               ; >= 37 = too fast
	jr c,post_complete                  ; in range [35,36] = OK
		; Timer test failed — set error bit 4
timer_test_fail:
	ex af,af'                           ; switch to error accumulator
	set 4,a                             ; bit 4 = timer error
	ex af,af'                           ; switch back
	; --- POST complete — display results ---
post_complete:
	di                                  ; disable interrupts
	call init_display                   ; initialize video
		; Print "\r\n AUTO-TEST : "
	ld hl,str_autotest                  ; result string pointer
print_autotest_loop:
	ld c,(hl)                           ; load next char
	call putchar                        ; display it
	inc hl                              ; advance pointer
	ld a,(hl)                           ; peek at next char
	or a                                ; null terminator?
	jr nz,print_autotest_loop           ; no → keep printing
		; Check accumulated error bits in A'
	ex af,af'                           ; switch to error accumulator
	or a                                ; any errors?
	jr nz,post_show_errors              ; errors found
		; All tests passed — print "OK"
	ld c,'O'                            ; 'O'
	call putchar                        ; print 'O'
	ld c,'K'                            ; 'K'
	call putchar                        ; print 'K'
	jp monitor_prompt                   ; enter command loop
		; Errors detected — print each set bit's number (0-7)
post_show_errors:
	ld b,8                              ; check 8 bits
	ld e,a                              ; E = error bitmap
	ld d,'0'                            ; D = ASCII digit counter
post_error_loop:
	srl e                               ; ; shift out lowest bit
	jr c,post_print_error               ; bit was set → print it
post_next_error:
	inc d                               ; next digit
	djnz post_error_loop                ; check all 8 bits
	jp monitor_prompt                   ; done → enter monitor
		; Print error number on its own line
post_print_error:
	ld c,CR                             ; carriage return
	call putchar                        ; new line
	ld c,d                              ; C = ASCII digit
	call putchar                        ; print error number
	jr post_next_error                  ; continue checking bits
str_prompt:
	defb CR,LF                          ; prompt string: "\r\n M P 2 ... "
	defm " M P 2 ... "
	defb 000h                           ; null terminator
str_autotest:
	defb CR,LF                          ; POST result: "\r\n AUTO-TEST : "
	defm " AUTO-TEST : "
	defb 000h                           ; null terminator
floppy_params:
		; Floppy parameters table (geometry) + ROM padding to 0x0800
	defb 32, 16                         ; sectors/track, heads
	defs 86                             ; pad to fill 2KB ROM
