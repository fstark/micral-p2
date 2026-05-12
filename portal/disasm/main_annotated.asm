; ============================================================
; MICRAL Portal Boot ROM — Main Monitor (Annotated)
; ============================================================
;
; Machine:   Bull/R2E Micral Portal (8085 @ 5 MHz, 1984)
; ROM:       2 KB, self-relocates main code to F800h
; CPU:       Intel 8085 (disassembled in Z80/Zilog syntax)
; Source:    z80dasm from portal.bin (offset 0x17, 1052 bytes)
;
; Execution flow:
;   0xF800  init         → hardware init (SIM, PIC, FDC specify)
;   0xF824  main_loop    → command loop: B (boot), G (go),
;                           & (set base), * (terminal), CR (default boot)
;   0xF879  boot_floppy  → spin up drive, read MOS records, execute
;
; Hardware:
;   D8085AC          — CPU (Intel 8085A @ 5 MHz)
;   KR3600-017       — Keyboard encoder (ports 10h/11h)
;   D765AC (µPD765)  — Floppy disk controller (ports 50h/51h)
;   M5L8257P-5       — DMA controller (ports 40h–48h)
;   D8259C-5         — Programmable Interrupt Controller (ports 60h/61h)
;   8× DL1416T       — 32-character LED display (ports 80h–9Fh)
;   P8253-5          — Programmable Interval Timer
;   IM6402AIPL       — UART (async serial)
;   SCN2652ACIN40    — MPCC (multi-protocol comms)
;
; Memory map (after bootstrap relocates code):
;   0x0000–0x07FF   ROM (bootstrap still mapped, not used after copy)
;   0xF800–0xFC1A   Main monitor code (this file)
;   0xFC1B–0xFC3E   RAM variables (FDC state, geometry, flags)
;   0xFC3F–0xFD3E   Sector buffer (256 bytes, DMA target)
;   0xFD3F–0xFD5C   Stack space (grows downward)
;   0xFD5D–0xFD5E   Display cursor pointer
;   0xFD5F–0xFD7E   Display buffer (32 characters)
;
; ============================================================

	org 0f800h

	; --- RAM Variables (FC1Bh..FD7Eh) ---
fdc_cur_trk_0:      equ	0fc1bh          ; Current track, drive 0
fdc_cur_trk_1:      equ	0fc1ch          ; Current track, drive 1
fdc_cur_trk_2:      equ	0fc1dh          ; Current track, drive 2
fdc_cur_trk_3:      equ	0fc1eh          ; Current track, drive 3
fdc_cmd_buf:        equ	0fc1fh          ; FDC command buffer start (max 9 bytes)
fdc_seek_drv:       equ	0fc20h          ; Seek cmd: drive+head byte
fdc_seek_cyl:       equ	0fc21h          ; Seek cmd: cylinder byte
fdc_cmd_byte:       equ	0fc22h          ; FDC command byte (46h = MFM Read Data)
fdc_cmd_drv:        equ	0fc23h          ; FDC drive + head select byte
fdc_cmd_cyl:        equ	0fc24h          ; FDC cylinder/track number
fdc_cmd_head:       equ	0fc25h          ; FDC head number (0 or 1)
fdc_cmd_sector:     equ	0fc26h          ; FDC sector number (1-based)
fdc_cmd_n:          equ	0fc27h          ; FDC N (bytes/sector code: 01=256)
fdc_cmd_eot:        equ	0fc28h          ; FDC EOT (end of track sector)
fdc_cmd_gpl:        equ	0fc29h          ; FDC GPL (gap 3 length)
fdc_cmd_dtl:        equ	0fc2ah          ; FDC DTL (data length, 0 when N≠0)
fdc_result_buf:     equ	0fc2ah          ; FDC result phase buffer (overlaps DTL)
fdc_result_st0:     equ	0fc2bh          ; FDC ST0 result byte
fdc_result_st1:     equ	0fc2ch          ; FDC ST1 result byte
irq_status:         equ	0fc33h          ; Interrupt completion flag (0=waiting, nonzero=done)
boot_flag:          equ	0fc34h          ; Boot mode flag (0=idle, 1=booting)
disk_lba:           equ	0fc35h          ; Current LBA for sequential reads (word)
disk_geom:          equ	0fc37h          ; Disk geometry (word: low=SPT, high=total_tracks)
buf_rd_ptr:         equ	0fc39h          ; Current read pointer into sector buffer (word)
buf_remain:         equ	0fc3bh          ; Bytes remaining in sector buffer (word)
reloc_base:         equ	0fc3dh          ; Relocation base address for MOS records (word)
sector_buf:         equ	0fc3fh          ; 256-byte sector buffer (DMA target)
stack_top:          equ	0fd5dh          ; Top of stack (SP initial value)
disp_cursor:        equ	0fd5dh          ; Display cursor pointer (word)
disp_buf:           equ	0fd5fh          ; Display buffer (32 bytes)

	; --- I/O Ports ---
PORT_KBD_STATUS:    equ	010h            ; KR3600 keyboard status (bit 0 = data ready)
PORT_KBD_DATA:      equ	011h            ; KR3600 keyboard data (7-bit ASCII)
PORT_DMA_CH0_ADDR:  equ	040h            ; 8257 DMA channel 0 address (low/high)
PORT_DMA_CH0_CNT:   equ	041h            ; 8257 DMA channel 0 terminal count (low/high)
PORT_DMA_MODE:      equ	048h            ; 8257 DMA mode register
PORT_FDC_MSR:       equ	050h            ; µPD765 Main Status Register
PORT_FDC_DATA:      equ	051h            ; µPD765 Data Register
PORT_PIC_ICW1:      equ	060h            ; 8259 PIC ICW1 / OCW2
PORT_PIC_ICW2:      equ	061h            ; 8259 PIC ICW2–4 / OCW1
PORT_DISP_LAST:     equ	09fh            ; DL1416T display, leftmost character
PORT_DISP_FIRST:    equ	080h            ; DL1416T display, rightmost character

	; --- µPD765 FDC Commands ---
FDC_CMD_SPECIFY:    equ	003h            ; Specify: set step rate, head times
FDC_CMD_SENSE_DRV:  equ	004h            ; Sense Drive Status → ST3
FDC_CMD_READ_MFM:   equ	046h            ; Read Data (MFM mode)
FDC_CMD_RECAL:      equ	007h            ; Recalibrate (seek to track 0)
FDC_CMD_SENSE_INT:  equ	008h            ; Sense Interrupt Status
FDC_CMD_SEEK:       equ	00fh            ; Seek to cylinder

	; --- µPD765 MSR Bit Masks ---
FDC_MSR_RQM:        equ	080h            ; Bit 7: Request for Master (ready)
FDC_MSR_DIO:        equ	040h            ; Bit 6: Data direction (1=FDC→CPU)
FDC_MSR_CB:         equ	010h            ; Bit 4: Command Busy

	; --- 8257 DMA Configuration ---
DMA_MODE_VAL:       equ	0e5h            ; Auto-load, TC stop, ext write, ch0+ch2 enable

	; --- MOS Record Types ---
REC_DATA:           equ	0c2h            ; Data record: load bytes to memory
REC_EXEC:           equ	0c6h            ; Execute: jump to loaded code
REC_RELOC:          equ	0d2h            ; Relocation fixup record
REC_TYPE_MIN:       equ	0c1h            ; Minimum valid record type
REC_TYPE_MAX:       equ	0dbh            ; Maximum valid record type (+1)

	; --- Floppy Geometry ---
SECTORS_PER_TRACK:  equ	16              ; 16 sectors per track
TOTAL_TRACKS:       equ	40              ; 40 tracks (single-sided)
BYTES_PER_SECTOR:   equ	256             ; 256 bytes per sector
DEFAULT_START_LBA:  equ	00080h          ; Default boot start: LBA 128 (track 8, sector 1)
DEFAULT_RELOC:      equ	00110h          ; Default relocation base address

	; --- Display ---
DISP_WIDTH:         equ	32              ; 32-character LED display
CURSOR_CHAR:        equ	05fh            ; '_' used as cursor indicator

	; --- Keyboard ---
KBD_DATA_MASK:      equ	07fh            ; 7-bit ASCII mask

	; --- ASCII Control Characters ---
CHAR_CR:            equ	00dh            ; Carriage return
CHAR_LF:            equ	00ah            ; Line feed
CHAR_ESC:           equ	01bh            ; Escape

; ============================================================
; init @ 0xF800 — Hardware initialization
; Sets serial output high (SIM), initializes stack, clears
; keyboard, sets up PIC interrupt vector for µPD765,
; configures the 8259 PIC, and falls into main loop.
; ============================================================
init:
	ld a,0c0h                           ; SIM value: SOD=1, SOE=1 (serial output high)
	defb 030h                           ; SIM — set interrupt mask (8085-only)
	ld sp,stack_top                     ; initialize stack pointer
		; Clear keyboard data register
	xor a                               ; A = 0
	out (PORT_KBD_DATA),a               ; clear keyboard latch
		; Install interrupt vector at F7F8h for PIC IR6
		; (PIC vectors to F7F8h for IR6 based on ICW1/ICW2 config)
	ld hl,0f7f8h                        ; vector location for IR6
	ld (hl),0c3h                        ; write JP opcode
	inc hl                              ; F7F9h
	ld (hl),07ah                        ; low byte of handler (FA7Ah)
	inc hl                              ; F7FAh
	ld (hl),0fah                        ; high byte → JP FA7Ah (irq_fdc_handler)
		; Initialize 8259 PIC
	ld a,0f6h                           ; ICW1: 8085 mode, vectors at F7xxh, level-trig, single
	out (PORT_PIC_ICW1),a               ; program PIC
	ld a,0f7h                           ; ICW2: vector base high byte = F7h
	out (PORT_PIC_ICW2),a               ; set vector page
	ld a,0bfh                           ; OCW1: mask = BFh (only IR6 unmasked)
	out (PORT_PIC_ICW2),a               ; enable FDC interrupt only
		; Clear boot mode flag
	xor a                               ; A = 0
	ld (boot_flag),a                    ; not in boot mode

; ============================================================
; main_loop @ 0xF824 — Main monitor command loop
; Resets stack, clears display, prints " PORTAL.." prompt,
; then reads a command character and dispatches.
;
; Commands:
;   CR  → boot from drive 0, LBA 128 (default)
;   B   → boot: B<drive>:<start_lba>
;   G   → execute: G<address>
;   &   → set relocation base: &<address>
;   *   → transparent terminal mode (keyboard echo)
; ============================================================
main_loop:
	ld sp,stack_top                     ; reset stack
	call clear_line                     ; blank the 32-char display
	ld hl,str_portal                    ; " PORTAL.." prompt string
	call print_str                      ; display prompt
		; Set default relocation base and start LBA
	ld hl,DEFAULT_RELOC                 ; 0110h default relocation base
	ld (reloc_base),hl                  ; store for MOS record loader
	ld de,DEFAULT_START_LBA             ; 0080h = default boot LBA (track 8, sector 1)
		; Command input loop
cmd_input:
	ld b,000h                           ; no special flags
	call get_key_echo                   ; read key → C, echo to display
	ld a,c                              ; A = typed character
		; Check for '&' (set relocation base)
	cp '&'                              ; '&'?
	jp z,cmd_ampersand                  ; → set base address
		; Check for CR (default boot)
	cp CHAR_CR                          ; carriage return?
	ex de,hl                            ; HL = start LBA (swap for boot path)
	jp z,boot_floppy                    ; CR → boot with defaults (drive 0, LBA 80h)
		; Check for '*' (terminal mode)
	cp '*'                              ; '*'?
	jp z,cmd_terminal                   ; → keyboard echo mode
		; Not a single-char command — echo ':' separator
	ld b,a                              ; save command letter in B
	ld c,':'                            ; ':' separator
	call putchar                        ; echo ':'
		; Match remaining commands
	ld a,'G'                            ; 'G'
	cp b                                ; command = G?
	jp z,cmd_go                         ; → execute at address
	ld a,'B'                            ; 'B'
	cp b                                ; command = B?
	jp nz,cmd_error                     ; not B either → error
		; Parse 'B' command: B<drive>:<start_lba>
	call parse_hex                      ; parse drive number → HL
	jp nc,cmd_error                     ; no valid input → error
	ld a,h                              ; drive high byte
	or a                                ; must be zero
	jp nz,cmd_error                     ; drive > 255 → error
	ld a,l                              ; drive low byte
	cp 4                                ; must be < 4
	jp nc,cmd_error                     ; invalid drive
	ld b,l                              ; B = drive number
	call parse_hex                      ; parse start LBA → HL
	jp nc,cmd_error                     ; no valid input → error

; ============================================================
; boot_floppy @ 0xF879 — Floppy disk boot sequence
; Entry: B = drive number (0–3), HL = starting LBA
; Spins up drive, sends Specify + Sense Drive Status to the
; µPD765, determines geometry, recalibrates, then enters the
; MOS hex record loading loop to load and execute code.
; ============================================================
boot_floppy:
	ld a,1                              ; set boot mode
	ld (boot_flag),a                    ; flag for IRQ handler behavior
	ld a,030h                           ; keyboard acknowledge / clear
	out (PORT_KBD_DATA),a               ; reset keyboard strobe
		; Motor spin-up delay (with interrupts enabled for FDC)
	ld de,084c6h                        ; delay counter (~34K iterations)
	ei                                  ; enable interrupts
spinup_delay:
	ex (sp),hl                          ; waste cycles
	ex (sp),hl                          ; (2 memory accesses per iteration)
	dec de                              ; decrement counter
	ld a,e                              ; test DE == 0
	or d                                ;
	jp nz,spinup_delay                  ; loop until delay complete
	di                                  ; disable interrupts
		; Save boot parameters
	xor a                               ; A = 0
	ld (boot_flag),a                    ; clear boot flag (normal IRQ handling)
	ld (disk_lba),hl                    ; save starting LBA
	ld a,b                              ; drive number
	ld (fdc_cmd_drv),a                  ; store in FDC command buffer
		; Send µPD765 Specify command (set step rate / head load times)
	ld hl,floppy_params                 ; parameters: SRT=53h, HLT=30h
	ld de,fdc_cmd_buf                   ; command buffer
	ld a,FDC_CMD_SPECIFY                ; 03h = Specify
	ld (de),a                           ; command byte
	inc de                              ; → parameter area
	ld c,2                              ; 2 parameter bytes to copy
	call memcpy                         ; copy params to buffer
		; Send 3-byte Specify command to FDC
	ld c,3                              ; 3 bytes: cmd + 2 params
	ld hl,fdc_cmd_buf                   ; point to command
	call fdc_send_bytes                 ; send to µPD765
		; Invalidate cached track positions (FFh = unknown)
	ld hl,0ffffh                        ; FFFFh marker
	ld (fdc_cur_trk_0),hl               ; drives 0,1 unknown
	ld (fdc_cur_trk_2),hl               ; drives 2,3 unknown
		; Send Sense Drive Status to detect double-sided drive
	ld hl,fdc_cmd_byte                  ; command buffer at FC22h
	ld (hl),FDC_CMD_SENSE_DRV           ; 04h = Sense Drive Status
	ld c,2                              ; 2 bytes: command + drive
	call fdc_send_bytes                 ; send and wait for result
	call fdc_read_result                ; read ST3 result
		; Check ST3 bit 3 (Two Side flag) — NOTE: result is discarded
		; because the unconditional LD A,040h / OR 006h below always
		; builds 046h. The Portal floppy is single-sided, so this
		; has no practical effect.
	ld a,(hl)                           ; ST3 result byte
	and 008h                            ; test Two Side bit (bit 3)
	rlca                                ; shift toward bit 7
	rlca                                ;   (4 rotations total)
	rlca                                ;
	rlca                                ; bit 3 now in bit 7
		; Build Read Data command byte (always 046h for single-sided)
	ld a,040h                           ; MFM bit (bit 6)
	or 006h                             ; Read Data command (06h) → 46h
	ld (fdc_cmd_byte),a                 ; store command byte
		; Determine disk geometry
	ld hl,floppy_geom_rom               ; geometry data table
	rlca                                ; test bit 7 of command (always 0 → carry=0)
	ld a,(hl)                           ; A = sectors per track × heads (28h = 40)
	jp nc,single_sided                  ; carry=0 → single-sided path (always taken)
	rlca                                ; (dead code: would double for two-sided)
single_sided:
	inc hl                              ; skip to second geometry entry
	inc hl                              ; → FB01h (EOT value = 10h = 16)
	ld l,(hl)                           ; L = 16 (sectors per track)
	ld h,a                              ; H = 40 (total tracks)
	ld (disk_geom),hl                   ; geometry: SPT=16, tracks=40
		; Set up sector buffer and relocation base
	ld hl,(reloc_base)                  ; load relocation base (0110h default)
	ex de,hl                            ; DE = reloc base (used in record loader)
	ld hl,0                             ; zero
	ld (buf_remain),hl                  ; buffer empty → force first sector read

; ============================================================
; parse_record @ 0xF8EF — MOS hex record parsing loop
; Reads records from floppy via sector buffer. Each record:
;   byte 0: length (# of following bytes including type)
;   byte 1: record type
;   bytes 2+: optional address (H, L, flags) then data
;
; Record types:
;   C2h = Data: load bytes sequentially to memory
;   C6h = Execute: jump to address in record
;   D2h = Relocation: apply fixups to loaded code
;   C1h–DBh = other (skip/ignore)
; ============================================================
parse_record:
	call get_stream_byte                ; read record length
	and a                               ; zero length?
	jp z,cmd_error                      ; bad record → error
	ld c,a                              ; C = byte count for this record
	call get_stream_byte                ; read record type
	ld b,a                              ; B = record type
		; If length >= 3, record contains address fields
	ld a,c                              ; record length
	cp 3                                ; at least 3 bytes?
	jp c,dispatch_record                ; short record → dispatch without address
		; Read address: high byte, low byte, flags
	call get_stream_byte                ; address high byte
	ld h,a                              ; H = addr high
	call get_stream_byte                ; address low byte
	ld l,a                              ; L = addr low
	call get_stream_byte                ; flags byte
	and 001h                            ; test bit 0: relative addressing?
	jp z,dispatch_record                ; if clear → absolute address
	add hl,de                           ; if set → address += relocation base
		; Dispatch on record type
dispatch_record:
	ld a,b                              ; A = record type
	cp REC_DATA                         ; data record (C2h)?
	jp z,load_data                      ; → load bytes to memory
	cp REC_RELOC                        ; relocation record (D2h)?
	jp z,apply_reloc                    ; → apply fixups
	cp REC_EXEC                         ; execute record (C6h)?
	jp z,exec_code                      ; → jump to loaded code
		; Unknown type — validate range
	cp REC_TYPE_MIN                     ; below C1h?
	jp c,cmd_error                      ; invalid → error
	cp REC_TYPE_MAX                     ; above DAh?
	jp nc,cmd_error                     ; invalid → error
		; Valid but unhandled type — consume remaining bytes
skip_record:
	call get_stream_byte                ; consume byte (C auto-decrements)
	jp skip_record                      ; loops until C=0 triggers return

; ============================================================
; load_data @ 0xF932 — Load data record bytes into RAM
; Writes bytes from the record to sequential memory at (HL).
; Verifies each write and aborts on memory error.
; ============================================================
load_data:
	call get_stream_byte                ; read next data byte
	ld (hl),a                           ; store at load address
	cp (hl)                             ; verify write (read back)
	jp nz,cmd_error                     ; memory error!
	inc hl                              ; advance load address
	jp load_data                        ; loop until C=0

; ============================================================
; apply_reloc @ 0xF93E — Apply relocation fixup record
; Each byte is a bit mask for 4 consecutive words.
; For each pair of bits: 1x=error, 01=add base to word,
; 00=skip word. Advances through memory applying base offset.
; ============================================================
apply_reloc:
	call get_stream_byte                ; read relocation mask byte
	ld b,4                              ; 4 word pairs per mask byte
reloc_word:
	rlca                                ; high bit of pair → carry
	jp c,cmd_error                      ; bit=1 → invalid relocation type
	rlca                                ; low bit of pair → carry
	jp nc,reloc_skip                    ; 00 = no relocation for this word
		; Apply fixup: add DE (reloc base) to word at (HL)
	push af                             ; save remaining mask bits
	ld a,(hl)                           ; load low byte of word
	add a,e                             ; add reloc base low
	ld (hl),a                           ; store back
	inc hl                              ; → high byte
	ld a,(hl)                           ; load high byte of word
	adc a,d                             ; add reloc base high + carry
	ld (hl),a                           ; store back
	dec hl                              ; point back to word start
	pop af                              ; restore mask bits
reloc_skip:
	inc hl                              ; advance past this word (2 bytes)
	dec b                               ; next word pair
	jp nz,reloc_word                    ; process remaining pairs
	jp apply_reloc                      ; next mask byte

; ============================================================
; exec_code @ 0xF95D — Jump to loaded code
; Entry: HL = entry point address from MOS record
; ============================================================
exec_code:
	jp (hl)                             ; transfer control to loaded program

; ============================================================
; get_stream_byte @ 0xF95E — Read next byte from disk stream
; Manages the sector buffer with lazy refill. When buffer
; is exhausted, reads next sector from disk. Tracks record
; byte count in C: when C reaches 0, pops return and goes
; back to parse_record for the next record.
; Returns: A = next byte, C decremented
; ============================================================
get_stream_byte:
	inc c                               ; test C (set Z if was 0)
	dec c                               ; restore C
	jp nz,stream_has_bytes              ; bytes remaining → read from buffer
		; Record complete — return to record loop
	pop af                              ; discard caller's return address
	inc c                               ; C = 1 (so next call reads length)
	jp parse_record                     ; back to record parsing
stream_has_bytes:
	push hl                             ; save caller's HL
	ld hl,(buf_remain)                  ; remaining bytes in buffer
	ld a,h                              ; test if zero
	or l                                ;
	jp nz,buf_has_data                  ; still have data → read from buffer
		; Buffer empty — read next sector from disk
	push hl                             ; save (0)
	push de                             ; save reloc base
	push bc                             ; save record state
	ld hl,(disk_geom)                   ; L=SPT(16), H=tracks(40)
	ex de,hl                            ; DE = geometry
	ld hl,(disk_lba)                    ; HL = current LBA
	call read_sector_lba                ; read sector, HL = LBA+1 on return
	ld (disk_lba),hl                    ; save updated LBA
	pop bc                              ; restore record state
	pop de                              ; restore reloc base
	pop hl                              ; restore
		; Reset buffer: 255 bytes available, pointer = sector_buf
	ld hl,255                           ; 255 bytes available
	ld (buf_remain),hl                  ; set buffer count
	ld hl,sector_buf                    ; start of sector buffer
	jp read_from_buf                    ; go read first byte
		; Buffer has data — decrement count and read
buf_has_data:
	dec hl                              ; one fewer byte remaining
	ld (buf_remain),hl                  ; update count
	ld hl,(buf_rd_ptr)                  ; current read position
		; Read byte from buffer and advance pointer
read_from_buf:
	ld a,(hl)                           ; read byte
	inc hl                              ; advance pointer
	ld (buf_rd_ptr),hl                  ; save updated pointer
	pop hl                              ; restore caller's HL
	dec c                               ; decrement record byte counter
	ret                                 ; return byte in A

; ============================================================
; read_sector_lba @ 0xF99F — Convert LBA to CHS and read
; Entry: HL = logical block address
;        DE = geometry (E=sectors/track, D=total tracks)
; Divides LBA by sectors/track to get track and sector,
; issues Seek + Read Data via µPD765 / DMA.
; Returns: HL = LBA + 1
; ============================================================
read_sector_lba:
	push hl                             ; save LBA for return
	push de                             ; save geometry
		; Divide HL by E (sectors per track)
		; Result: L = quotient (track), A = remainder (sector-1)
	xor a                               ; clear remainder
	ld d,16                             ; 16-bit division (16 iterations)
div_loop:
	add hl,hl                           ; shift dividend left
	rla                                 ; shift remainder left
	jp c,div_sub                        ; overflow → must subtract
	cp e                                ; remainder >= divisor?
	jp c,div_next                       ; no → skip subtraction
div_sub:
	inc l                               ; set quotient bit
	sub e                               ; subtract divisor
div_next:
	dec d                               ; next bit
	jp nz,div_loop                      ; loop 16 times
		; A = sector offset (0-based), L = logical track
	inc a                               ; sector is 1-based
	ld (fdc_cmd_sector),a               ; save sector number
		; Check track within bounds
	ld a,l                              ; logical track number
	pop de                              ; restore DE (D = total tracks)
	cp d                                ; track >= max tracks?
	jp nc,cmd_error                     ; past end of disk
		; Determine head/side from track (single-sided: no division)
	ld a,(fdc_cmd_byte)                 ; Read Data command byte (046h)
	rlca                                ; bit 7 → carry (double-sided flag, always 0)
	ld b,000h                           ; B = head 0 (default)
	ld a,l                              ; logical track
	jp nc,set_cyl                       ; single-sided → track = cylinder (always taken)
		; (Dead code for double-sided: divide track by 2, odd = head 1)
	or a                                ; clear carry
	rra                                 ; track / 2
	jp nc,set_cyl                       ; even → head 0
	ld b,004h                           ; odd → head 1 (bit 2 in FDC head select)
set_cyl:
	ld (fdc_cmd_cyl),a                  ; save physical cylinder
		; Merge head select with drive number
	ld hl,fdc_cmd_drv                   ; drive byte
	ld a,b                              ; head select bits
	or (hl)                             ; combine with drive
	ld (hl),a                           ; update command
	ld a,b                              ; head bits
	rrca                                ; shift bit 2 → bit 1
	rrca                                ; shift bit 1 → bit 0 → head number
	ld (fdc_cmd_head),a                 ; save head number
		; Copy Read Data parameters (N=01, EOT=10, GPL=20, DTL=00)
	ld hl,fdc_read_params               ; source: ROM parameter table
	ld c,4                              ; 4 bytes
	ld de,fdc_cmd_n                     ; destination in command buffer
	call memcpy                         ; copy N, EOT, GPL, DTL
		; Setup DMA channel 0 for 256-byte transfer to sector_buf
dma_setup:
	ld a,03fh                           ; DMA addr low: FC3Fh low byte
	out (PORT_DMA_CH0_ADDR),a           ; send low byte of sector_buf address
	ld a,0fch                           ; DMA addr high: FC3Fh high byte
	out (PORT_DMA_CH0_ADDR),a           ; send high byte of sector_buf address
	ld a,0ffh                           ; Terminal count low: FFh (256-1 = 255)
	out (PORT_DMA_CH0_CNT),a            ; send low byte of transfer count
	ld a,040h                           ; Terminal count high: 01=write to memory, count=0
	out (PORT_DMA_CH0_CNT),a            ; send high byte (write mode + count)
	ld a,DMA_MODE_VAL                   ; E5h: auto-load, TC stop, ch0+ch2 enable
	out (PORT_DMA_MODE),a               ; configure DMA controller
		; Seek to correct track (if not already there)
	call fdc_seek_track                 ; seek to cylinder in fdc_cmd_cyl
		; Send 9-byte Read Data command to µPD765
	ld c,9                              ; 9 command bytes
	ld hl,fdc_cmd_byte                  ; full Read Data command
	call fdc_send_cmd_wait              ; send + wait for interrupt completion
		; Check result: ST1 bit 7 (End of Cylinder) or bit 2 (No Data)
	dec a                               ; A was irq_status: 1=success
	jp nz,read_error                    ; non-zero after DEC → error
		; Success — increment LBA and return
	pop hl                              ; restore original LBA
	inc hl                              ; LBA + 1
	ret                                 ; return with HL = next LBA

; ============================================================
; read_error @ 0xFA0E — Handle FDC read error
; Checks if error is recoverable (not-ready vs permanent).
; If track was never seeked, does recalibrate and retry.
; Otherwise retries the entire read operation.
; ============================================================
read_error:
	ld a,(fdc_result_st1)               ; ST1 result byte
	and 084h                            ; test End of Cylinder (bit 7) + No Data (bit 2)
	jp z,dma_setup                      ; neither set → retry read
	call get_cur_trk_ptr                ; get pointer to current track for this drive
	ld (hl),0ffh                        ; invalidate cached track → force recalibrate
	jp dma_setup                        ; retry (will recalibrate on next seek)

; ============================================================
; memcpy @ 0xFA1E — Copy C bytes from (HL) to (DE)
; ============================================================
memcpy:
	ld a,(hl)                           ; read source byte
	ld (de),a                           ; write to destination
	inc hl                              ; advance source
	inc de                              ; advance destination
	dec c                               ; decrement count
	jp nz,memcpy                        ; loop until done
	ret

; ============================================================
; get_cur_trk_ptr @ 0xFA27 — Get pointer to cached track
; Returns HL pointing to fdc_cur_trk_N for current drive.
; ============================================================
get_cur_trk_ptr:
	ld a,(fdc_cmd_drv)                  ; current drive (0–3)
	and 003h                            ; mask to drive number only
	ld hl,fdc_cur_trk_0                 ; base of track cache array
	add a,l                             ; offset by drive number
	ld l,a                              ; update pointer
	ret nc                              ; no carry (usual case)
	inc h                               ; handle page crossing
	ret

; ============================================================
; fdc_seek_track @ 0xFA34 — Seek to target cylinder
; Compares target (fdc_cmd_cyl) with cached position.
; If different, issues Seek command. If track unknown (FFh),
; does Recalibrate first.
; ============================================================
fdc_seek_track:
	call get_cur_trk_ptr                ; HL → cached track for this drive
	ld a,(hl)                           ; cached track value
	inc a                               ; test for FFh (unknown)
	jp z,seek_after_recal               ; FFh → must recalibrate first
check_track:
	ld a,(fdc_cmd_cyl)                  ; target cylinder
	cp (hl)                             ; same as current?
	ret z                               ; already there → done
		; Need to seek — issue Seek command
	or a                                ; clear carry
	ex de,hl                            ; DE = track cache pointer
	jp z,do_recalibrate                 ; target is track 0 → use Recalibrate
		; Build Seek command: 0Fh, drive+head, cylinder
	ld hl,fdc_seek_cyl                  ; seek command cylinder slot (FC21h)
	ld (hl),a                           ; store target cylinder there
	ld b,00fh                           ; 0Fh = Seek command
	ld c,3                              ; 3 bytes total
fdc_issue_cmd:
	ld hl,fdc_seek_drv                  ; seek command drive slot (FC20h)
	ld a,(fdc_cmd_drv)                  ; drive + head select byte
	ld (hl),a                           ; byte 2: drive+head
	dec hl                              ; → FC1Fh
	ld (hl),b                           ; byte 1: command
	call fdc_send_cmd_wait              ; send + wait for interrupt
		; Update cached track position
	ld a,(fdc_cmd_cyl)                  ; target cylinder
	ld (de),a                           ; update cache
	ret

; ============================================================
; seek_after_recal @ 0xFA5F — Recalibrate then seek
; ============================================================
seek_after_recal:
	ex de,hl                            ; DE = track cache pointer
	call do_recalibrate                 ; recalibrate (seek to track 0)
	ex de,hl                            ; HL = track cache pointer
	ld (hl),000h                        ; current track = 0
	jp check_track                      ; now seek to target if needed

; ============================================================
; do_recalibrate @ 0xFA69 — Issue Recalibrate command
; Sends Recalibrate (07h) + drive byte. Retries if step
; pulse count exceeded (very far from track 0).
; ============================================================
do_recalibrate:
	ld b,007h                           ; 07h = Recalibrate command
	ld c,2                              ; 2 bytes: command + drive
	call fdc_issue_cmd                  ; send recalibrate
		; Check if recalibrate completed (track 0 found)
	ld a,(irq_status)                   ; completion status
	dec a                               ; 1 → 0 = success
	ld a,000h                           ; (don't affect flags)
	ret z                               ; success → return
	jp do_recalibrate                   ; retry (in case 77-step limit hit)

; ============================================================
; irq_fdc_handler @ 0xFA7A — Interrupt handler for µPD765
; Called via PIC IR6 → vector at F7F8h → JP here.
; During boot: just acknowledges PIC and returns.
; During normal operation: reads FDC result, issues Sense
; Interrupt Status if needed, sets completion flag.
; ============================================================
irq_fdc_handler:
	push af                             ; save registers
	push bc                             ;
	push hl                             ;
		; Check if we're in boot mode (motor spin-up)
	ld a,(boot_flag)                    ; boot mode flag
	and a                               ; test
	jp nz,irq_ack                       ; during boot → just acknowledge
		; Normal mode: read FDC result bytes
irq_read_result:
	call fdc_read_result                ; read result phase from µPD765
	ld a,b                              ; B = number of result bytes received
	and a                               ; any results?
	jp z,irq_sense_int                  ; no results → need Sense Interrupt Status
		; Check ST0 for errors
	ld hl,fdc_result_st0                ; first result byte
	ld a,(hl)                           ; ST0
	rlca                                ; bit 7 → carry (interrupt code bit 1)
	jp c,irq_error                      ; IC bit 1 set → abnormal termination
	rlca                                ; bit 6 → carry (interrupt code bit 0)
	jp c,irq_error                      ; IC bit 0 set → error
		; Success — set completion flag = 1
	ld a,1                              ; success
irq_set_flag:
	ld (irq_status),a                   ; set completion flag
irq_ack:
		; Send EOI to 8259 PIC
	ld a,066h                           ; non-specific EOI command
	out (PORT_PIC_ICW1),a               ; acknowledge interrupt
	pop hl                              ; restore registers
	pop bc                              ;
	pop af                              ;
	ret                                 ; return from interrupt

irq_error:
		; Error — set completion flag = 7Fh (error marker)
	ld a,07fh                           ; error status
	jp irq_set_flag                     ; set flag and return

; ============================================================
; irq_sense_int @ 0xFAAA — Issue Sense Interrupt Status
; When FDC has no result ready (e.g. after Seek/Recalibrate
; completion), we must send Sense Interrupt Status (08h)
; to read ST0 and acknowledge the interrupt.
; ============================================================
irq_sense_int:
	ld hl,fdc_cmd_buf                   ; command buffer
	ld (hl),FDC_CMD_SENSE_INT           ; 08h = Sense Interrupt Status
	ld c,1                              ; 1 byte command
	call fdc_wait_send                  ; wait not-busy, send command
	jp irq_read_result                  ; read the result

; ============================================================
; fdc_read_result @ 0xFAB7 — Read µPD765 result phase
; Reads bytes from FDC data register while Command Busy.
; Returns: B = number of result bytes read,
;          results stored at fdc_result_buf+1..
; ============================================================
fdc_read_result:
	ld hl,fdc_result_buf                ; result buffer start
	ld b,0                              ; byte counter
fdc_result_loop:
	in a,(PORT_FDC_MSR)                 ; read Main Status Register
	rlca                                ; bit 7 (RQM) → carry
	jp nc,fdc_result_loop               ; wait for RQM=1
	ld c,a                              ; save shifted MSR
	and 020h                            ; MSR bit 4 (CB) is now bit 5 after RLCA; mask 20h tests it
	ret z                               ; CB=0 → command complete, return
	ld a,c                              ; restore shifted MSR
	rlca                                ; bit 6 (DIO) → carry
	jp nc,fdc_result_loop               ; wait for DIO=1 (FDC→CPU)
	in a,(PORT_FDC_DATA)                ; read result byte
	inc hl                              ; advance buffer pointer
	inc b                               ; count byte
	ld (hl),a                           ; store result
	jp fdc_result_loop                  ; continue reading

; ============================================================
; fdc_wait_send @ 0xFAD3 — Wait not-busy then send bytes
; Waits for CB=0, then sends C bytes from (HL) to FDC.
; ============================================================
fdc_wait_send:
	in a,(PORT_FDC_MSR)                 ; read MSR
	and FDC_MSR_CB                      ; test Command Busy (bit 4)
	jp nz,fdc_wait_send                 ; wait until not busy
		; Fall through to fdc_send_bytes

; ============================================================
; fdc_send_bytes @ 0xFADA — Send C bytes from (HL) to µPD765
; Waits for RQM=1 and DIO=0 (CPU→FDC) before each byte.
; ============================================================
fdc_send_bytes:
	in a,(PORT_FDC_MSR)                 ; read MSR
	rlca                                ; bit 7 (RQM) → carry
	jp nc,fdc_send_bytes                ; wait for RQM=1
	rlca                                ; bit 6 (DIO) → carry
	jp c,fdc_send_bytes                 ; wait for DIO=0 (CPU→FDC direction)
	ld a,(hl)                           ; load command byte
	out (PORT_FDC_DATA),a               ; send to FDC
	inc hl                              ; advance pointer
	dec c                               ; decrement count
	jp nz,fdc_send_bytes                ; loop until all bytes sent
	ret

; ============================================================
; fdc_send_cmd_wait @ 0xFAED — Send command + wait for IRQ
; Sends the FDC command, then waits for the interrupt handler
; to set the completion flag (irq_status).
; Returns: A = completion status (1=OK, 7Fh=error)
; ============================================================
fdc_send_cmd_wait:
	call fdc_wait_send                  ; wait not-busy, send command bytes
	xor a                               ; clear completion flag
	ld (irq_status),a                   ; reset to "waiting"
	ei                                  ; enable interrupts
wait_for_irq:
	ld a,(irq_status)                   ; check completion flag
	or a                                ; set?
	jp z,wait_for_irq                   ; spin until interrupt handler sets it
	ret                                 ; return with A = status

; ============================================================
; Data Tables
; ============================================================

; --- Floppy Parameters (for Specify command) ---
; Byte 1 (SRT|HUT): SRT=5 (11ms step), HUT=3 (96ms unload)
; Byte 2 (HLT|ND):  HLT=24 (48ms load), ND=0 (DMA mode)

floppy_params:
	defb 053h                           ; Specify param 1: SRT=5, HUT=3
	defb 030h                           ; Specify param 2: HLT=24, ND=0 (DMA)
floppy_geom_rom:
	defb 40                             ; total tracks (single-sided)
fdc_read_params:
	defb 1                              ; N: bytes/sector code (1 = 256 bytes)
	defb 16                             ; EOT: last sector number (16)
	defb 32                             ; GPL: gap 3 length (32)
	defb 0                              ; DTL: don't care (N ≠ 0)

; ============================================================
; parse_hex @ 0xFB05 — Parse hex number from keyboard
; Reads up to 9 hex digits, building result in HL.
; Terminates on non-hex character or ESC.
; Returns: HL = parsed value
;          C = terminating character
;          Carry set = valid number parsed
;          Carry clear = ESC or no input
; ============================================================
	defb 032h                           ; (orphan byte — unreachable padding)
parse_hex:
	push bc                             ; save caller's BC
	ld hl,0                             ; initialize result = 0
	ld b,9                              ; max 9 hex digits
hex_digit_loop:
	call get_key_echo                   ; read key → C (echoed to display)
	ld a,c                              ; A = typed character
		; Convert ASCII to hex digit value
	sub '0'                             ; subtract '0'
	jp c,hex_end_char                   ; < '0' → not a digit
	add a,0e9h                          ; test > '9': adds to wrap if > 9
	jp c,hex_end_char                   ; > '9' and < 'A' → end
	add a,6                             ; adjust: gap between '9' and 'A'
	jp p,hex_valid_digit                ; positive = valid A–F range? (actually 0-9)
	add a,7                             ; additional gap for lowercase or invalid
	jp c,hex_end_char                   ; overflow → not valid hex
hex_valid_digit:
	add a,00ah                          ; final value: 0–15
	or a                                ; clear carry (valid digit)
	dec b                               ; decrement max digit counter
	jp z,hex_max_digits                 ; 9 digits reached → return
		; Shift HL left 4 bits and insert new digit
	add hl,hl                           ; HL × 2
	add hl,hl                           ; HL × 4
	add hl,hl                           ; HL × 8
	add hl,hl                           ; HL × 16
	or l                                ; merge digit into low nibble
	ld l,a                              ; L = shifted | new digit
	jp hex_digit_loop                   ; next digit

hex_end_char:
		; Non-hex terminator — check for ESC
	ld a,c                              ; terminating character
	cp CHAR_ESC                         ; ESC?
	pop bc                              ; restore caller's BC
	jp z,hex_max_digits                 ; ESC → return carry=0 (abort)
	scf                                 ; set carry (valid number parsed)
	ret                                 ; return: HL=number, C=terminator, CF=1

hex_max_digits:
	or a                                ; clear carry (no valid termination / abort)
	ret                                 ; return: CF=0

; ============================================================
; cmd_terminal @ 0xFB3E — Transparent terminal mode (*)
; Infinite keyboard echo loop. Displays typed characters on
; the 32-char LED display. Wraps on line full, CR resets to
; start. No exit — only hardware reset returns to monitor.
; ============================================================
cmd_terminal:
	ld b,9                              ; initial column position (after prompt)
terminal_loop:
	call get_key                        ; wait for keypress → A
	ld c,a                              ; C = character
	cp CHAR_CR                          ; CR?
	jp z,terminal_newline               ; → reset to line start
	cp CHAR_LF                          ; LF?
	jp z,terminal_newline               ; → same as CR
	inc b                               ; advance column counter
	ld a,b                              ; current column
	cp DISP_WIDTH                       ; reached 32 (display full)?
	jp nz,terminal_echo                 ; not full → just echo
	call clear_line                     ; display full → clear line
terminal_newline:
	ld b,0                              ; reset column to 0
	call putchar                        ; output the CR/LF (resets cursor)
	jp terminal_loop                    ; continue
terminal_echo:
	call putchar                        ; echo character to display
	jp terminal_loop                    ; continue

; ============================================================
; cmd_go @ 0xFB66 — Execute at address (G command)
; Parses hex address and jumps to it.
; ============================================================
cmd_go:
	call parse_hex                      ; parse hex address → HL
	jp nc,cmd_error                     ; no valid address → error
	jp (hl)                             ; jump to address

; ============================================================
; cmd_ampersand @ 0xFB6D — Set relocation base (& command)
; Parses hex address and stores as relocation base.
; ============================================================
cmd_ampersand:
	call parse_hex                      ; parse hex address → HL
	jp nc,cmd_error                     ; no valid address → error
	ld (reloc_base),hl                  ; store as new relocation base
	jp cmd_input                        ; back to command input

; ============================================================
; cmd_error @ 0xFB79 — Display error and restart
; Shows '#' error indicator, then returns to main loop.
; ============================================================
cmd_error:
	ld c,'#'                            ; '#' error character
	call putchar                        ; display it
	jp main_loop                        ; restart monitor

; ============================================================
; get_key @ 0xFB81 — Wait for keypress from KR3600
; Polls keyboard status port until data available.
; Returns: A = 7-bit ASCII key code
; ============================================================
get_key:
	in a,(PORT_KBD_STATUS)              ; read keyboard status
	rrca                                ; bit 0 (data ready) → carry
	jp nc,get_key                       ; wait until key available
	in a,(PORT_KBD_DATA)                ; read key data
	and KBD_DATA_MASK                   ; mask to 7-bit ASCII
	ret

; ============================================================
; Prompt String
; ============================================================

str_portal:
	defb 9                              ; length: 9 characters
	defm " PORTAL.."                    ; prompt text
	defb 000h                           ; (null terminator — not used by print_str)

; ============================================================
; get_key_echo @ 0xFB97 — Read key and echo to display
; Calls get_key then falls through to putchar.
; Returns: C = key code
; ============================================================
get_key_echo:
	call get_key                        ; wait for key → A
	ld c,a                              ; C = key code
		; Fall through to putchar

; ============================================================
; putchar @ 0xFB9B — Output character to LED display
; Entry: C = character to display
; Handles CR (reset cursor) and LF (clear line).
; Normal characters are placed at cursor position.
; ============================================================
putchar:
	ld a,c                              ; A = character
	cp CHAR_CR                          ; CR?
	jp z,do_cr                          ; → carriage return
	cp CHAR_LF                          ; LF?
	jp z,clear_line                     ; → clear line (acts as CR+LF)
		; Normal character — store at cursor position
	push hl                             ; save HL
	ld hl,(disp_cursor)                 ; get cursor pointer
	ld (hl),c                           ; write character at cursor
	inc hl                              ; advance cursor
	ld (disp_cursor),hl                 ; save new position
	ld a,CURSOR_CHAR                    ; '_' cursor marker
	ld (hl),a                           ; place cursor at next position
	call refresh_display                ; update LED display
	pop hl                              ; restore HL
	ret

; ============================================================
; do_cr @ 0xFBB7 — Handle carriage return
; Clears cursor from current position and resets to column 0.
; ============================================================
do_cr:
	push hl                             ; save HL
	ld hl,(disp_cursor)                 ; current cursor position
	ld a,' '                            ; space (clear cursor mark)
	ld (hl),a                           ; erase cursor character
	ld hl,disp_buf                      ; reset to start of display buffer
	ld (disp_cursor),hl                 ; cursor = column 0
	ld a,CURSOR_CHAR                    ; '_' cursor
	ld (hl),a                           ; place cursor at start
	call refresh_display                ; update LED display
	pop hl                              ; restore HL
	ret

; ============================================================
; refresh_display @ 0xFBCC — Update DL1416T LED displays
; Writes all 32 characters from disp_buf to the display
; via I/O ports 9Fh (leftmost) down to 80h (rightmost).
; Uses self-modifying code to patch the OUT port address.
; ============================================================
refresh_display:
	push hl                             ; save registers
	push bc                             ;
	ld hl,disp_buf                      ; display buffer start
	ld b,PORT_DISP_LAST                 ; starting port = 9Fh (leftmost char)
disp_loop:
	push hl                             ; save buffer pointer
	ld hl,disp_out_instr+1              ; address of port byte in OUT instruction
	ld (hl),b                           ; patch port number (self-modifying!)
	pop hl                              ; restore buffer pointer
	ld a,(hl)                           ; get character from buffer
disp_out_instr:
	out (PORT_DISP_LAST),a              ; output to display (port is self-modified)
	inc hl                              ; next buffer position
	dec b                               ; next port (decrementing)
	ld a,b                              ; current port
	cp 07fh                             ; reached below port 80h?
	jp nz,disp_loop                     ; continue until all 32 done
	pop bc                              ; restore registers
	pop hl                              ;
	ret

; ============================================================
; clear_line @ 0xFBE7 — Clear display and reset cursor
; Fills display buffer with spaces, places cursor at start,
; and refreshes the LED display.
; ============================================================
clear_line:
	push af                             ; save all registers
	push bc                             ;
	push de                             ;
	push hl                             ;
	ld a,' '                            ; space character
	ld hl,disp_buf                      ; display buffer
	ld c,DISP_WIDTH                     ; 32 characters
clear_loop:
	ld (hl),a                           ; fill with space
	inc hl                              ; next position
	dec c                               ; decrement count
	jp nz,clear_loop                    ; loop until all 32 cleared
		; Reset cursor to start
	ld hl,disp_buf                      ; buffer start
	ld a,CURSOR_CHAR                    ; '_' cursor
	ld (hl),a                           ; place cursor
	call refresh_display                ; update LED display
	ld hl,disp_buf                      ; reset cursor pointer
	ld (disp_cursor),hl                 ; cursor = column 0
	pop hl                              ; restore all registers
	pop de                              ;
	pop bc                              ;
	pop af                              ;
	ret

; ============================================================
; print_str @ 0xFC0C — Print length-prefixed string
; Entry: HL points to string (first byte = length, then chars)
; ============================================================
print_str:
	push bc                             ; save BC
	push hl                             ; save string pointer
	ld b,(hl)                           ; B = string length
print_str_loop:
	inc hl                              ; advance to next char
	ld c,(hl)                           ; C = character
	call putchar                        ; output to display
	dec b                               ; decrement count
	jp nz,print_str_loop                ; loop until all chars printed
	pop hl                              ; restore HL
	pop bc                              ; restore BC
	ret

; ============================================================
; RAM Variables and Padding (FC1Bh–FFE8h)
; The remainder of the ROM image is all zeros. This area
; becomes uninitialized RAM after the bootstrap copies the
; code to F800h. Only the first ~36 bytes (FC1Bh–FC3Eh) are
; used as variables; the sector buffer (FC3Fh–FD3Eh), stack
; area, cursor pointer, and display buffer live beyond.
; ============================================================
	defs 974                            ; pad to match 2048-byte ROM image
