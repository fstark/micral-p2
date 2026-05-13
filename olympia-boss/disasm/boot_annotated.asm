; ==========================================================================
; Olympia Boss System ROM — Annotated Disassembly
; ==========================================================================
;
; ROM:       olympia_boss_system_251-462.bin (2048 bytes)
; Machine:   Olympia Boss (Z80A word processor, ~1983)
; Origin:    0000h
;
; This is the boot/monitor ROM for the Olympia Boss word processor.
; It provides:
;   - Hardware initialisation (CRT, SIO, PPI, FDC, DMA, interrupts)
;   - A command prompt ("BOSS ..") accepting:
;       CR    — Boot from floppy disk (auto-detect drive type)
;       B addr,size — Load binary from serial and execute
;       L     — Load from floppy disk
;       G addr — Go (jump to address)
;       *     — Terminal pass-through mode (until ESC)
;   - Display driver (80x27 scrolling text, cursor management)
;   - Serial file transfer protocol (block-framed records)
;   - Floppy disk sector read (active-low FDC interface)
;
; Memory Map:
;   0000-07FF : System ROM (this 2K ROM)
;   0800-0FFF : Character generator ROM (2K, separate chip)
;   BE00-BFFF : Work RAM (stack at BED2, variables BFD3-BFFF)
;   F2C6-FxFF : Display character buffer (27 lines x 82 bytes)
;   FFE6-FFFF : Display state variables
;
; I/O Port Map:
;   00-01 : DMA controller (address, word count)
;   04-07 : CRT controller (start/end/scroll address registers)
;   08    : CRT controller command
;   10    : SIO Channel B status
;   11    : SIO Channel B data (serial port)
;   30    : SIO Channel A data
;   31    : SIO Channel A control
;   40    : 8255 PPI Port A (keyboard data, active-low)
;   43    : 8255 PPI control register
;   60    : System control (write: ROM bank/drive; read: config)
;   71    : FDC control/mode select
;   72    : FDC status (active-low)
;   73    : FDC data (active-low)
;   80    : Display data port (cursor position, init params)
;   81    : Display command register
;
; Interrupts: IM 2, I=07h, vector table at 07F0h
;   07F0: CRT vsync      → 0670h (reprogram CRTC each frame)
;   07F2: stub           → 03D8h (EI; RET)
;   07F4: SIO RX         → 032Ch (serial receive handler)
;   07F6: stub           → 03D8h (EI; RET)
;   07F8: keyboard       → 053Fh (PPI port A read)
;   07FA: stub           → 03D8h (EI; RET)
;   07FC: stub           → 03D8h (EI; RET)
;   07FE: SIO error      → 03DAh (acknowledge + RETI)
;
; Execution Flow:
;   0000h  reset        → cold_start (full hardware init)
;   0004h  warm_entry   → warm_start (SIO/display reinit only)
;   007Ah  cmd_loop     — prompt and command dispatch
;   0190h  serial_rx    — serial binary receive protocol
;   0447h  fdc_read_sector — floppy disk sector read
;
; ==========================================================================

; --- ASCII control characters ---
CHAR_NUL:        equ 000h
CHAR_LF:         equ 00ah       ; Line feed
CHAR_CR:         equ 00dh       ; Carriage return
CHAR_ESC:        equ 01bh       ; Escape

; --- Display command bytes ---
DISP_RESET:      equ 000h       ; Reset display controller
DISP_ON:         equ 020h       ; Display on
DISP_CURSOR:     equ 081h       ; Set cursor position register
DISP_ENABLE:     equ 0a0h       ; Enable display output
DISP_MODE:       equ 042h       ; Set display mode
DISP_START:      equ 0c0h       ; Start display output

; --- CRT controller commands ---
CRTC_INIT:       equ 041h       ; CRTC initialise
CRTC_START:      equ 0c5h       ; CRTC start DMA / run
CRTC_WRAP:       equ 080h       ; Address wrap flag in CRTC registers

; --- Serial protocol record types ---
REC_DATA:        equ 0c2h       ; Data record (store bytes)
REC_ABORT:       equ 0d2h       ; Abort/error record
REC_EXEC:        equ 0c6h       ; Execute record (jump to address)
REC_SKIP_LO:     equ 0c1h       ; Lower bound of skip range
REC_SKIP_HI:     equ 0dbh       ; Upper bound of skip range

; --- FDC commands ---
FDC_RECAL:       equ 007h       ; Recalibrate command
FDC_SEEK:        equ 00fh       ; Seek command
FDC_STAT_RDY:    equ 002h       ; Status: ready bit
FDC_STAT_DRQ:    equ 040h       ; Status: data request
FDC_STAT_BUSY:   equ 082h       ; Status: busy + DRQ combined

; --- System control port values ---
SYS_BANKOUT:     equ 001h       ; Bank out ROM, map RAM at 0000h
SYS_DRV_SEL:     equ 002h       ; Drive select / enable
SYS_DENSITY:     equ 080h       ; Bit 7: density flag
SYS_TYPE_MASK:   equ 003h       ; Drive type mask (after rotation)
SYS_BIT5:        equ 020h       ; Config bit 5
SYS_TYPE_BITS:   equ 0c0h       ; Drive type bits 7:6

; --- PPI mode/BSR values ---
PPI_MODE_SET:    equ 0bch       ; Port A=input(mode1), B=input
PPI_BSR_PC2:     equ 005h       ; BSR: set PC2 (strobe)
PPI_BSR_PC4:     equ 009h       ; BSR: set PC4 (int enable)

; --- Display geometry ---
SCR_COLS:        equ 80         ; Columns per line
SCR_LINES:       equ 27         ; Visible screen lines
SCR_STRIDE:      equ 120        ; Bytes per display line (80+38+2)
SCR_MAX_COL:     equ 79         ; Maximum column index (0-based)
SCR_PAD:         equ 38         ; Padding bytes per line

; --- I/O Port equates ---
PORT_DMA_ADDR:   equ 000h
PORT_DMA_COUNT:  equ 001h
PORT_CRTC_START: equ 004h
PORT_CRTC_END:   equ 005h
PORT_CRTC_SCRL:  equ 006h
PORT_CRTC_SEND:  equ 007h
PORT_CRTC_CMD:   equ 008h
PORT_SIO_B_CTRL: equ 010h
PORT_SIO_B_DATA: equ 011h
PORT_SIO_A_DATA: equ 030h
PORT_SIO_A_CTRL: equ 031h
PORT_PPI_A:      equ 040h
PORT_PPI_CTRL:   equ 043h
PORT_SYS_CTRL:   equ 060h
PORT_FDC_CTRL:   equ 071h
PORT_FDC_STAT:   equ 072h
PORT_FDC_DATA:   equ 073h
PORT_DISP_DATA:  equ 080h
PORT_DISP_CMD:   equ 081h

; --- Miscellaneous constants ---
RELAY_LEN:       equ 5          ; Length of relay code copied to RAM
BUF_SIZE:        equ 255        ; DMA buffer usable bytes
FDC_CMD_LEN:     equ 8          ; FDC command block length
MAX_DRIVES:      equ 4          ; Maximum drive/unit number
SEC_128:         equ 128        ; 128-byte sector size
SEC_PER_TRK_MAX: equ 32         ; Max sectors per track
MAX_SECTOR:      equ 31         ; Maximum sector number (0-based)
MAX_HEAD:        equ 3          ; Maximum head number

; --- RAM variable equates ---
STACK_TOP:       equ 0bed2h     ; Stack pointer init / boot cmd storage
DMA_BUF:         equ 0bed3h     ; DMA transfer buffer (256 bytes)
BUF_PTR:         equ 0bfd3h     ; Buffer read pointer
BLOCK_CNT:       equ 0bfd5h     ; Block bytes remaining
LOAD_ADDR:       equ 0bfd7h     ; Current load address
FDC_CMD:         equ 0bfd9h     ; FDC command block (8 bytes)
SEC_PER_TRK:     equ 0bfdch     ; Sectors per track
FDC_PARAMS:      equ 0bfdfh     ; FDC working parameters
TRK_CMP_0:      equ 0bfe1h     ; Track compare (side 0)
TRK_CMP_1:      equ 0bfe3h     ; Track compare (side 1)
SIO_CMD:         equ 0bfe5h     ; SIO command buffer
SIO_SEEK:        equ 0bfe6h     ; SIO seek command area
SIO_SEEKD:       equ 0bfe7h     ; SIO seek data byte
DRV_CONFIG:      equ 0bfe8h     ; Drive config (density/sides/sector)
DRV_PARAMS:      equ 0bfe9h     ; Drive parameter copy
CUR_TRACK:       equ 0bfeah     ; Current track number
SIDE_FLAG:       equ 0bfebh     ; Current side flag
STEP_RATE:       equ 0bfech     ; Step rate / interleave
FDC_SEEKBUF:     equ 0bfedh     ; FDC seek parameter buffer
SIO_RXBUF:       equ 0bff0h     ; SIO receive buffer
SIO_DONE:        equ 0bffbh     ; SIO completion flag
SEC_SIZE:        equ 0bffch     ; Sector size (16-bit)
PARAM_PTR:       equ 0bff9h     ; Pointer to drive param table
DRV_TYPE:        equ 0bff8h     ; Drive type/density flags
KEY_FLAG:        equ 0bffeh     ; Keyboard ready flag (0=none, 1=ready)
KEY_DATA:        equ 0bfffh     ; Keyboard data byte

; --- Display memory equates ---
SCREEN_BASE:     equ 0f2c6h     ; Start of character display buffer
SCR_LIMIT:       equ 0ffe6h     ; End of display buffer
SCR_START:       equ 0ffe8h     ; Scroll window start address
SCR_END:         equ 0ffeah     ; Scroll window end address
CUR_ADDR:        equ 0ffech     ; Cursor memory address
CUR_COL:         equ 0ffeeh     ; Cursor column (0-79)
CUR_LINE:        equ 0ffefh     ; Cursor line (0-27)


        org 00000h

; ==========================================================================
; RESET VECTOR (0000h) — Cold start entry point
; ==========================================================================
reset:
        jp cold_start

; Warm restart entry (after DI)
        di
warm_entry:
        jp warm_start

; ==========================================================================
; COLD START — Full hardware initialisation
; ==========================================================================
cold_start:
        ld sp,STACK_TOP                     ; Init stack

        ; --- 8255 PPI initialisation ---
        ld a,PPI_MODE_SET                   ; Mode set word:
        out (PORT_PPI_CTRL),a               ;   Port A=input(mode1), B=input, Cupper=in
        ld a,PPI_BSR_PC2                    ; BSR: set bit PC2 (strobe)
        out (PORT_PPI_CTRL),a
        ld a,PPI_BSR_PC4                    ; BSR: set bit PC4 (int enable)
        out (PORT_PPI_CTRL),a

        ; --- Clear keyboard flag ---
        xor a
        ld (KEY_FLAG),a

        ; --- Initialise display memory and CRT controller ---
        call init_display_mem
        call program_crtc

        ; --- Initialise cursor state ---
        xor a
        ld (CUR_COL),a                      ; Column = 0
        ld a,SCR_LINES
        ld (CUR_LINE),a                     ; Line = 27 (bottom)

        ; --- Display controller setup ---
        xor a
        out (PORT_DISP_CMD),a               ; Reset display chip
        ld hl,crt_init_data                 ; 5-byte timing table
        ld b,5
.crt_loop:
        ld a,(hl)
        out (PORT_DISP_DATA),a              ; Write param to display
        inc hl
        djnz .crt_loop
        ld a,DISP_ENABLE
        out (PORT_DISP_CMD),a               ; Enable display
        ld a,DISP_MODE
        out (PORT_DISP_CMD),a               ; Set display mode
        ld a,DISP_START
        out (PORT_DISP_CMD),a               ; Activate output

; ==========================================================================
; WARM START — Reinit serial + display (preserves PPI/CRT timing)
; ==========================================================================
warm_start:
        ld sp,STACK_TOP
        call update_cursor

        ld a,DISP_ON
        out (PORT_DISP_CMD),a               ; Display ON

        ; --- SIO Channel A initialisation (10 register pairs) ---
        xor a
        out (PORT_SIO_A_CTRL),a             ; Reset register pointer
        ld hl,sio_init_tbl
        ld b,10
.sio_loop:
        ld a,(hl)
        out (PORT_SIO_A_CTRL),a             ; Register addr/cmd
        inc hl
        ld a,(hl)
        out (PORT_SIO_A_DATA),a             ; Register value
        inc hl
        djnz .sio_loop

        ; --- SIO post-init commands ---
        ld a,040h                           ; Reset RX CRC
        out (PORT_SIO_A_CTRL),a
        ld a,0a1h                           ; Enable INT on next RX
        out (PORT_SIO_A_CTRL),a

        ; --- Set up IM 2 interrupts ---
        ld a,007h                           ; Vector page = 07xxh
        ld i,a
        im 2

        ; --- Final SIO config ---
        ld a,02fh                           ; Reset TX INT pending
        out (PORT_SIO_A_CTRL),a
        ld a,02ch                           ; Reset TX INT pending
        out (PORT_SIO_A_CTRL),a
        ld a,020h                           ; Enable INT on next RX
        out (PORT_SIO_A_CTRL),a
        ei

; ==========================================================================
; COMMAND LOOP — Print prompt, parse commands
; ==========================================================================
cmd_loop:
        ld sp,STACK_TOP
        ld hl,str_prompt
.print_loop:
        ld c,(hl)
        call putchar
        inc hl
        ld a,(hl)
        or a
        jp nz,.print_loop

        ; --- Read command ---
        ld b,000h
        call getchar_echo
        ld a,c
        cp CHAR_CR                          ; CR → floppy boot
        jp z,cmd_boot
        ex af,af'
        ld c,':'                            ; Print ':'
        call putchar
        ex af,af'
        cp '*'                              ; '*' → terminal mode
        jp z,cmd_terminal
        cp 'B'                              ; 'B' → serial boot
        jp z,cmd_load
        cp 'L'                              ; 'L' → floppy load
        jp z,cmd_load
        cp 'G'                              ; 'G' → go to address
        jp z,cmd_go

cmd_error:
        ld c,'#'                            ; Print '#' = error
        call putchar
        jp cmd_loop

; ==========================================================================
; COMMAND: B/L — Load binary (serial or floppy)
; Syntax: B addr,size<CR> or L<CR>
; ==========================================================================
cmd_load:
        ex af,af'                           ; Recover command char
        call parse_hex                      ; Parse address → DE
        dec b
        jp m,cmd_noaddr                     ; No digits: special case
        ld a,c
        cp ','                              ; Expect ','
        jp nz,cmd_error
        ld a,d                              ; Address high byte
        or a
        jp nz,cmd_error                     ; Must be 00xx
        or e
        cp MAX_DRIVES                       ; Max drive/unit = 3
        jp nc,cmd_error
        push af
        call parse_hex                      ; Parse size
        dec b
        ld a,c
        pop bc
        jp m,cmd_error
        cp CHAR_CR                          ; Must end with CR
        jp nz,cmd_error

; --- Common load entry (DE=size/address, AF'=command type) ---
start_load:
        ld (LOAD_ADDR),de
        ex af,af'
        ld (STACK_TOP),a                    ; Store command type
        cp 'L'                              ; 'L' → floppy path
        jp z,floppy_load

        ; --- Serial boot: drive select ---
        ld a,SYS_DRV_SEL
        out (PORT_SYS_CTRL),a

        ; --- Delay (device settle / motor spin-up) ---
        ld de,084c6h
.delay:
        ex (sp),hl                          ; Burn cycles
        ex (sp),hl
        dec de
        ld a,e
        or d
        jp nz,.delay

        ; --- Detect drive type from system config port ---
        ld a,b
        ld (DRV_PARAMS),a
        in a,(PORT_SYS_CTRL)
        ld c,a
        and SYS_DENSITY                     ; Bit 7 = density
        rrca
        ld (DRV_TYPE),a
        ld a,c
        rlca
        rlca
        and SYS_TYPE_MASK                   ; Bits 7:6 → type 0-3
        ld hl,drv_param_a
        jp nz,.got_type
        ld a,040h                           ; Type 0: special flag
        ld (DRV_TYPE),a
        jp .sel_params
.got_type:
        ld hl,drv_param_c
        dec a
        jp z,.sel_params
        ld hl,drv_param_a
        dec a
        jp z,.sel_params
        ld hl,drv_param_b
.sel_params:
        ld (PARAM_PTR),hl

        ; --- Build and send SIO command ---
        ld de,SIO_CMD
        ld a,003h
        ld (de),a
        inc de
        ld c,002h
        call memcopy
        ld c,003h
        ld hl,SIO_CMD
        call sio_send_blk

        ; --- Init track limits ---
        ld hl,0ffffh
        ld (TRK_CMP_0),hl
        ld (TRK_CMP_1),hl

        ; --- Configure drive ---
        ld hl,DRV_CONFIG
        ld (hl),004h
        ld c,002h
        call sio_send_blk
        call sio_read_stat
        ld a,(hl)
        and 008h                            ; Bit 3 = double sided?
        rlca
        rlca
        rlca
        rlca
        ld hl,DRV_TYPE
        or (hl)
        or 006h
        ld (DRV_CONFIG),a

        ; --- Calculate sector size from param table ---
        ld hl,(PARAM_PTR)
        inc hl
        inc hl
        rlca
        ld a,(hl)
        jp nc,.no_dbl
        rlca
.no_dbl:
        ld b,a
        in a,(PORT_SYS_CTRL)
        and SYS_BIT5
        ld a,b
        jp z,.no_shift
        rlca
.no_shift:
        ld b,a
        inc hl
        inc hl
        ld a,(DRV_TYPE)
        or a
        ld a,(hl)
        jp nz,.use_val
        rrca
.use_val:
        ld l,a
        ld h,b
        ld (SEC_SIZE),hl

; ==========================================================================
; SERIAL RECEIVE — Block-framed binary transfer protocol
; ==========================================================================
serial_rx:
        ld hl,0
        ld (BLOCK_CNT),hl
.next_rec:
        call get_srx_byte
        and a
        jp z,cmd_error                      ; Zero type = error
        ld c,a                              ; C = record type
        call get_srx_byte                   ; Byte count
        ld b,a
        ld a,c
        cp 003h                             ; Type ≥ 3: has address
        jp c,.short_rec
        call get_srx_byte                   ; Address high
        ld h,a
        call get_srx_byte                   ; Address low
        ld l,a
        call get_srx_byte                   ; Extra byte
.short_rec:
        ld a,b
        cp REC_DATA                         ; Data record
        jp z,.data_rec
        cp REC_ABORT                        ; Abort
        jp z,cmd_error
        cp REC_EXEC                         ; Execute record
        jp z,.exec_rec
        cp REC_SKIP_LO
        jp c,cmd_error
        cp REC_SKIP_HI
        jp nc,cmd_error
.skip_rec:
        call get_srx_byte                   ; Consume record
        jp .skip_rec

.data_rec:
        call get_srx_byte
        ld (hl),a                           ; Store byte at address
        inc hl
        jp .data_rec

.exec_rec:
        di
        push hl
        push de
        ld hl,relay_code                    ; Copy relay to RAM
        ld de,DMA_BUF
        ld bc,RELAY_LEN
        ldir
        pop de
        pop hl                              ; HL = exec address
        jp DMA_BUF                          ; Run relay

; --- Relay code (5 bytes, executes from RAM) ---
relay_code:
        ld a,SYS_BANKOUT                    ; Bank out ROM
        out (PORT_SYS_CTRL),a
        jp (hl)                             ; Jump to program

; ==========================================================================
; get_srx_byte — Get one byte from serial receive buffer
; Replenishes buffer from SIO when empty. Adjusts C count.
; ==========================================================================
get_srx_byte:
        inc c
        dec c                               ; Test C == 0
        jp nz,.have_byte
        pop af                              ; Pop caller return
        inc c
        jp .next_rec                        ; Restart record loop
.have_byte:
        push hl
        ld hl,(BLOCK_CNT)
        ld a,h
        or l
        jp nz,.from_buf
        ; --- Refill buffer from disk/serial ---
        push hl
        push de
        push bc
        ld hl,(SEC_SIZE)
        ex de,hl
        ld hl,(LOAD_ADDR)
        call do_sector_rw
        ld (LOAD_ADDR),hl
        pop bc
        pop de
        pop hl
        ld hl,BUF_SIZE                      ; 255 bytes available
        ld (BLOCK_CNT),hl
        ld hl,DMA_BUF
        jp .read_one
.from_buf:
        dec hl
        ld (BLOCK_CNT),hl
        ld hl,(BUF_PTR)
.read_one:
        ld a,(hl)
        inc hl
        ld (BUF_PTR),hl
        pop hl
        dec c
        ret

; ==========================================================================
; do_sector_rw — Read one sector (dispatches to serial or floppy)
; Entry: DE=sector size, HL=current sector address
; Exit:  HL=next sector address
; ==========================================================================
do_sector_rw:
        ld a,(STACK_TOP)                    ; Check mode
        cp 'L'                              ; 'L' = floppy
        jp z,fdc_read_sector

        ; --- Serial/SIO path ---
        push hl
        push de
        call divide_hl_e
        ld a,(DRV_TYPE)
        or a
        ld a,b
        jp nz,.not_t0
        add a,a
.not_t0:
        inc a
        ld (STEP_RATE),a
        ld a,l
        pop de
        cp d
        jp nc,cmd_error

        ; --- Side selection ---
        ld a,(DRV_CONFIG)
        rlca
        ld b,000h
        ld a,l
        jp nc,.one_side
        or a
        rra
        jp nc,.one_side
        ld b,004h                           ; Side 1 flag
.one_side:
        ld (CUR_TRACK),a
        ld hl,DRV_PARAMS
        ld a,(hl)
        and 0fbh                            ; Clear side bit
        or b
        ld (hl),a
        ld a,b
        rrca
        rrca
        ld (SIDE_FLAG),a

        ; --- Copy params from table ---
        ld hl,(PARAM_PTR)
        inc hl
        inc hl
        inc hl
        ld c,004h
        ld de,FDC_SEEKBUF
        call memcopy

; --- DMA setup and sector transfer ---
.do_dma:
        ld a,0d3h                           ; DMA addr low (→BED3h)
        di
        out (PORT_DMA_ADDR),a
        ld a,0beh                           ; DMA addr high
        out (PORT_DMA_ADDR),a
        ld a,0ffh                           ; DMA count low
        out (PORT_DMA_COUNT),a
        ld a,040h                           ; DMA count high
        out (PORT_DMA_COUNT),a
        ei
        ld a,CRTC_START
        out (PORT_CRTC_CMD),a               ; Start DMA

        ; --- Send seek + read command ---
        call seek_track
        ld c,009h                           ; 9-byte command
        ld hl,DRV_CONFIG
        call sio_send_wait
        dec a
        jp nz,.chk_err
        pop hl                              ; Done: advance
        inc hl
        ret
.chk_err:
        ld a,(SIO_RXBUF+2)                  ; Error status
        and 084h
        jp z,.do_dma                        ; Retry if recoverable
        call get_trk_cmp
        ld (hl),0ffh                        ; Mark track failed
        jp .do_dma                          ; Retry

; ==========================================================================
; memcopy — Copy C bytes from (HL) to (DE)
; ==========================================================================
memcopy:
        ld a,(hl)
        ld (de),a
        inc hl
        inc de
        dec c
        jp nz,memcopy
        ret

; ==========================================================================
; get_trk_cmp — Get pointer to track compare value for current side
; ==========================================================================
get_trk_cmp:
        ld a,(DRV_PARAMS)
        and 003h
        ld hl,TRK_CMP_0
add_a_to_hl:
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; ==========================================================================
; divide_hl_e — Unsigned division: HL / E → HL quotient, B remainder
; ==========================================================================
divide_hl_e:
        xor a
        ld d,010h                           ; 16 bits
.div_loop:
        add hl,hl
        rla
        jp c,.do_sub
        cp e
        jp c,.no_sub
.do_sub:
        inc l
        sub e
.no_sub:
        dec d
        jp nz,.div_loop
        ld b,a                              ; Remainder
        ret

; ==========================================================================
; seek_track — Seek FDC to correct track (with recalibrate if needed)
; ==========================================================================
seek_track:
        call get_trk_cmp
        ld a,(hl)
        inc a
        jp z,.first_seek                    ; FF = never seeked
.chk_pos:
        ld a,(CUR_TRACK)
        cp (hl)                             ; Already there?
        ret z
        or a
        ex de,hl
        jp z,.recal                         ; Track 0 = recalibrate
        ; --- Seek to non-zero track ---
        ld hl,SIO_SEEKD
        ld (hl),a                           ; Target track
        ld b,FDC_SEEK                       ; Seek command
        ld c,003h
.exec_seek:
        ld hl,SIO_SEEK
        ld a,(DRV_PARAMS)
        ld (hl),a                           ; Drive select
        dec hl
        ld (hl),b                           ; Command byte
        call sio_send_wait
        ld a,(CUR_TRACK)
        ld (de),a                           ; Update position
        ret
.first_seek:
        ex de,hl
        call .recal                         ; Recalibrate
        ex de,hl
        ld (hl),000h                        ; At track 0
        jp .chk_pos                         ; Then seek target
.recal:
        ld b,FDC_RECAL                      ; Recal command
        ld c,002h
        call .exec_seek
        ld a,(SIO_DONE)
        dec a
        ld a,000h
        ret z
        jp .recal                           ; Retry recal

; ==========================================================================
; SIO RX INTERRUPT HANDLER (vector F4 → 032Ch)
; ==========================================================================
sio_rx_isr:
        push af
        ld a,03ah                           ; RETI to SIO
        out (PORT_SIO_A_CTRL),a
        ei
        push bc
        push hl
.rx_loop:
        call sio_read_stat
        ld a,b
        and a
        jp z,.rx_ack                        ; No data: send ACK
        ld hl,SIO_RXBUF+1
        ld a,(hl)
        rlca
        jp c,.rx_err                        ; Bit 7 set: error
        rlca
        jp c,.rx_err                        ; Bit 6 set: error
        ld a,001h                           ; Normal completion
.rx_done:
        ld (SIO_DONE),a
        pop hl
        pop bc
        pop af
        ret
.rx_err:
        ld a,07fh                           ; Error flag
        jp .rx_done
.rx_ack:
        ld hl,SIO_CMD
        ld (hl),008h                        ; ACK command
        ld c,001h
        call sio_tx_wait
        jp .rx_loop

; ==========================================================================
; sio_read_stat — Read status/data bytes from SIO Channel B
; Exit: B = byte count received, data at SIO_RXBUF+
; ==========================================================================
sio_read_stat:
        ld hl,SIO_RXBUF
        ld b,000h
.poll:
        in a,(PORT_SIO_B_CTRL)
        rlca                                ; Bit 7 → carry
        jp nc,.poll                         ; Wait for ready
        ld c,a
        and 020h                            ; Check data avail
        ret z                               ; None: return
        ld a,c
        rlca
        jp nc,.poll
        in a,(PORT_SIO_B_DATA)              ; Read byte
        inc hl
        inc b
        ld (hl),a
        jp .poll

; ==========================================================================
; sio_tx_wait — Wait for TX buffer empty, then send
; ==========================================================================
sio_tx_wait:
        in a,(PORT_SIO_B_CTRL)
        and 010h
        jp nz,sio_tx_wait

; ==========================================================================
; sio_send_blk — Send C bytes from (HL) to SIO Channel B
; ==========================================================================
sio_send_blk:
        in a,(PORT_SIO_B_CTRL)
        rlca
        jp nc,sio_send_blk
        rlca
        jp c,sio_send_blk
        ld a,(hl)
        out (PORT_SIO_B_DATA),a
        inc hl
        dec c
        jp nz,sio_send_blk
        ret

; ==========================================================================
; sio_send_wait — Send block and wait for ISR completion
; ==========================================================================
sio_send_wait:
        call sio_tx_wait
        xor a
        ld (SIO_DONE),a                     ; Clear flag
        di
        ld a,02ah                           ; Reset TX INT
        out (PORT_SIO_A_CTRL),a
        ei
.wait:
        ld a,(SIO_DONE)
        or a
        jp z,.wait
        ret

; ==========================================================================
; parse_hex — Read hex digits, build 16-bit value in DE
; Exit: DE=value, B=digit count, C=terminating char
; ==========================================================================
parse_hex:
        ld de,0
        ld b,e
.next:
        call getchar_echo
        ld a,c
        sub '0'                             ; '0'
        cp 10
        jp c,.digit                         ; 0-9
        cp 17
        ret c                               ; Non-hex: return
        sub 7                               ; 'A'-'F' → 10-15
.digit:
        cp 16
        ccf
        ret c                               ; >15: return
        inc b
        ld l,a
        ld h,000h
        ld a,010h                           ; Multiply DE × 16
.mul16:
        add hl,de
        jp c,cmd_error                      ; Overflow
        dec a
        jp nz,.mul16
        ex de,hl
        jp .next

; ==========================================================================
; INTERRUPT STUBS
; ==========================================================================
isr_stub:
        ei
        ret

isr_sio_err:
        ei
        push af
        ld a,07fh                           ; SIO RETI command
        out (PORT_SIO_A_CTRL),a
        pop af
        ret

; ==========================================================================
; COMMAND: L (floppy-only path) — Floppy disk load
; ==========================================================================
floppy_load:
        dec b
        jp p,cmd_error
        out (PORT_FDC_CTRL),a               ; FDC mode select
        ; --- Init FDC command block ---
        ld hl,FDC_CMD
        ld (hl),001h                        ; Track = 1
        inc hl
        ld (hl),001h                        ; Sector = 1
        inc hl
        xor a
        ld (hl),a                           ; Head = 0
        ld hl,FDC_PARAMS
        ld (hl),a
        inc hl
        ld (hl),a
        ; --- Compute sectors from size ---
        ex de,hl
        ld de,SEC_128                       ; 128-byte sectors
        add hl,de                           ; Round up
        ld e,SEC_PER_TRK_MAX                ; 32 sectors/track
        call divide_hl_e
        ex de,hl
        ld hl,FDC_CMD+4
        ld (hl),b
        inc hl
        ld a,e
        and 003h
        ld (hl),a
        ex de,hl
        ld de,00004h
        call divide_hl_e
        ld a,h
        or a
        jp nz,cmd_error
        or l
        ld (SEC_PER_TRK),a
        ; --- Recalibrate and format/setup ---
        call fdc_recal
        jp nz,cmd_error
        call fdc_prep
        ld hl,fdc_cmd_read
        call fdc_send_cmd
        ld c,FDC_STAT_DRQ+FDC_STAT_RDY      ; Wait for DRQ+RDY
        call fdc_wait_stat
        and FDC_STAT_RDY
        jp nz,.fmt_ok
        ld hl,intrlv_tbl
        ld b,SEC_PER_TRK_MAX
        call fdc_send_data
.fmt_ok:
        call fdc_result
        jp nz,cmd_error
        jp serial_rx                        ; Start reading

; ==========================================================================
; fdc_read_sector — Read one sector from FDC (floppy-mode path)
; Entry: HL on stack (load address)
; ==========================================================================
fdc_read_sector:
        push hl
.retry:
        call fdc_do_read
        jp nz,.retry
        ; --- Advance sector/head/track ---
        ld hl,FDC_CMD+5
        inc (hl)                            ; Next sector
        ld a,01fh
        cp (hl)
        jp nc,.sec_ok
        ld (hl),000h                        ; Wrap sector
        dec hl
        inc (hl)                            ; Next head
        ld a,003h
        cp (hl)
        jp nc,.sec_ok
        ld (hl),000h                        ; Wrap head
        dec hl
        inc (hl)                            ; Next track
.sec_ok:
        pop hl
        inc hl
        ret

; ==========================================================================
; fdc_do_read — Execute single sector read from FDC
; Exit: Z=success, NZ=error (A=error code)
; ==========================================================================
fdc_do_read:
        call fdc_prep
        ld hl,FDC_CMD
        call fdc_send_cmd
.wait_rdy:
        ld c,FDC_STAT_BUSY
        call fdc_wait_stat
        and FDC_STAT_RDY
        jp nz,.wait_rdy
        ; --- Read 256 bytes ---
        ld hl,DMA_BUF
        ld b,000h                           ; 256 iterations
.rd_byte:
        in a,(PORT_FDC_DATA)
        cpl                                 ; Active-low invert
        ld (hl),a
        inc hl
        djnz .rd_byte
        ; --- Check result ---
        call fdc_result
        ret z                               ; Success
        push af
        cp 008h
        jp z,.needs_recal
        cp 003h
        jp nc,.maybe_retry
.ret_err:
        pop af
        ret
.maybe_retry:
        cp 006h
        jp nc,.ret_err
.needs_recal:
        call fdc_recal
        pop af
        ret

; ==========================================================================
; fdc_recal — Send recalibrate command to FDC
; ==========================================================================
fdc_recal:
        call fdc_prep
        ld hl,fdc_cmd_recal
        call fdc_send_cmd
        ld c,FDC_STAT_RDY
        call fdc_wait_stat

; ==========================================================================
; fdc_result — Send "sense" command and read result byte
; Exit: A=status, Z=success
; ==========================================================================
fdc_result:
        call fdc_prep
        ld hl,fdc_cmd_sense
        call fdc_send_cmd
        ld c,FDC_STAT_BUSY
        call fdc_wait_stat
        and FDC_STAT_RDY
        jp nz,cmd_error
        in a,(PORT_FDC_DATA)
        cpl                                 ; Active-low invert
        or a                                ; Z if success
        ret

; ==========================================================================
; fdc_prep — Prepare FDC (wait ready, toggle chip select)
; ==========================================================================
fdc_prep:
        ld c,FDC_STAT_RDY
        call fdc_wait_stat
        cpl
        out (PORT_FDC_STAT),a
        ld c,FDC_STAT_DRQ

; ==========================================================================
; fdc_wait_stat — Wait for FDC status bits in C (active-low)
; ==========================================================================
fdc_wait_stat:
        in a,(PORT_FDC_STAT)
        cpl
        and c
        ret nz
        jp fdc_wait_stat

; ==========================================================================
; fdc_send_cmd — Send 8 bytes from (HL) to FDC data port
; ==========================================================================
fdc_send_cmd:
        ld b,FDC_CMD_LEN

; ==========================================================================
; fdc_send_data — Send B bytes from (HL) to FDC (with inversion)
; ==========================================================================
fdc_send_data:
        ld a,(hl)
        cpl                                 ; Active-low invert
        out (PORT_FDC_DATA),a
        inc hl
        djnz fdc_send_data
        ret

; ==========================================================================
; COMMAND: * — Terminal mode (echo until ESC)
; ==========================================================================
cmd_terminal:
        call kbd_getchar
        cp CHAR_ESC                         ; ESC?
        jp z,cmd_loop
        ld c,a
        call putchar
        jp cmd_terminal

; ==========================================================================
; COMMAND: CR — Auto-detect boot from floppy
; ==========================================================================
cmd_boot:
        ld hl,SEC_128                       ; 128-byte sector
        in a,(PORT_SYS_CTRL)
        and SYS_TYPE_BITS                   ; Drive type bits
        ld a,'B'                            ; 'B' = serial
        jp nz,.set_type                     ; Non-zero = serial
        ld a,'L'                            ; 'L' = floppy
        add hl,hl                           ; Double sector size
.set_type:
        ex de,hl
        ex af,af'
        jp start_load

; ==========================================================================
; cmd_noaddr — Handle B/L with no address (immediate CR)
; ==========================================================================
cmd_noaddr:
        ld a,c
        cp CHAR_CR
        jp nz,cmd_error
        ld b,000h
        ld de,00001h
        jp start_load

; ==========================================================================
; COMMAND: G addr — Jump to address (with ROM bank-out)
; ==========================================================================
cmd_go:
        call parse_hex
        dec b
        jp m,cmd_error
        ld a,c
        cp CHAR_CR
        jp nz,cmd_error
        ex de,hl                            ; HL = target addr
        di
        ld a,0ffh
        ld i,a                              ; Vectors → FFxxh (RAM)
        im 2
        jp .exec_rec                        ; Bank out + jump

; ==========================================================================
; kbd_getchar — Wait for keyboard input (blocking poll)
; Returns char in A (7-bit ASCII)
; ==========================================================================
kbd_getchar:
        ld a,(KEY_FLAG)
        or a
        jp z,kbd_getchar
        xor a
        ld (KEY_FLAG),a                     ; Clear flag
        ld a,(KEY_DATA)
        and 07fh                            ; 7-bit ASCII
        ret

; ==========================================================================
; KEYBOARD ISR (vector F8 → 053Fh)
; ==========================================================================
kbd_isr:
        ei
        push af
        in a,(PORT_PPI_A)                   ; Read keyboard
        cpl                                 ; Invert (active-low)
        ld (KEY_DATA),a
        ld a,001h
        ld (KEY_FLAG),a                     ; Signal ready
        pop af
        ret

; ==========================================================================
; getchar_echo — Get char from keyboard, echo to display
; Returns char in C
; ==========================================================================
getchar_echo:
        call kbd_getchar
        ld c,a

; ==========================================================================
; putchar — Output character C to display
; Handles CR (0Dh) and LF (0Ah) specially
; ==========================================================================
putchar:
        push bc
        push de
        push hl
        ld a,c
        cp CHAR_CR                          ; CR?
        jp z,.do_cr
        cp CHAR_LF                          ; LF?
        jp z,.do_lf
        ; --- Normal character ---
        ld hl,(CUR_ADDR)
        ld (hl),c                           ; Store in display mem
        call advance_cur
.done:
        pop hl
        pop de
        pop bc
        ret
.do_lf:
        call scroll_line
        jp .done
.do_cr:
        call carriage_ret
        ld (CUR_ADDR),hl
        call update_cursor
        jp .done

; ==========================================================================
; carriage_ret — Move cursor to column 0 of current line
; ==========================================================================
carriage_ret:
        ld hl,(CUR_ADDR)
        ld a,(CUR_COL)
        call sub_hl_a
        xor a
        ld (CUR_COL),a
        ret

; ==========================================================================
; advance_cur — Move cursor right, wrap at column 79
; ==========================================================================
advance_cur:
        ld hl,(CUR_COL)
        ld a,SCR_MAX_COL                    ; Col 79
        cp l
        jp z,.wrap
        inc l
        ld (CUR_COL),hl
        ld hl,(CUR_ADDR)
        inc hl
        jp .set_addr
.wrap:
        call carriage_ret
        ld (CUR_ADDR),hl

; ==========================================================================
; scroll_line — Advance to next line, scroll if at bottom
; ==========================================================================
scroll_line:
        ld hl,CUR_LINE
        inc (hl)
        ld a,SCR_LINES+1                    ; Line 28 = overflow
        cp (hl)
        jp z,.scroll
        ld hl,(CUR_ADDR)
        ld de,SCR_STRIDE                    ; Line stride = 120 bytes
        add hl,de
        jp c,.clamp
        ld de,(SCR_END)
        call cmp_hl_de
        jp c,.set_addr
.clamp:
        ld hl,SCREEN_BASE
.set_line:
        ld a,(CUR_COL)
        call add_a_to_hl
.set_addr:
        ld (CUR_ADDR),hl

; ==========================================================================
; update_cursor — Write cursor position to display hardware
; ==========================================================================
update_cursor:
        ld a,DISP_CURSOR
        out (PORT_DISP_CMD),a
        ld hl,(CUR_COL)
        ld a,l
        out (PORT_DISP_DATA),a              ; Column
        ld a,h
        out (PORT_DISP_DATA),a              ; Line
        ret

; --- Handle scrolling ---
.scroll:
        dec (hl)                            ; Keep at line 27
        ld hl,(SCR_START)
        ld (CUR_ADDR),hl
        call init_one_line                  ; Clear new line
        ld de,(SCR_END)
        call cmp_hl_de
        jp c,.scrl_ok
        ld hl,SCREEN_BASE                   ; Wrap to top
.scrl_ok:
        ld (SCR_START),hl
        ld hl,(CUR_ADDR)
        jp .set_line

; ==========================================================================
; init_display_mem — Fill display buffer with blank lines
; ==========================================================================
init_display_mem:
        ld hl,SCREEN_BASE
        ld (SCR_START),hl
        ld b,SCR_LINES                      ; 27 lines
.clr_loop:
        call init_one_line
        djnz .clr_loop
        ld (SCR_LIMIT),hl
        ld (CUR_ADDR),hl
        call init_one_line                  ; Extra scroll buffer line
        ld (SCR_END),hl
        ret

; ==========================================================================
; init_one_line — Init one display line: 80 spaces + 38 NULs + FF 00
; Entry/Exit: HL = line start → HL = next line start
; ==========================================================================
init_one_line:
        push de
        ld a,SCR_COLS                       ; 80 characters
        ld e,' '                            ; Space
        call fill_mem
        ld a,SCR_PAD                        ; 38 padding bytes
        ld e,000h                           ; NUL
        call fill_mem
        ld (hl),0ffh                        ; End marker
        inc hl
        ld (hl),000h
        inc hl
        pop de
        ret

; ==========================================================================
; fill_mem — Fill A bytes at (HL) with byte E
; ==========================================================================
fill_mem:
        ld (hl),e
        inc hl
        dec a
        ret z
        jp fill_mem

; ==========================================================================
; program_crtc — Program CRT controller registers for scrolling display
; ==========================================================================
program_crtc:
        ld a,CRTC_INIT
        out (PORT_CRTC_CMD),a               ; Init CRTC
        ; --- Start address ---
        ld hl,(SCR_START)
        ld a,l
        out (PORT_CRTC_START),a
        ld a,h
        out (PORT_CRTC_START),a
        ; --- End address ---
        ld de,(SCR_END)
        call negate_sub
        dec hl
        ld a,l
        out (PORT_CRTC_END),a
        ld a,h
        or CRTC_WRAP                        ; Wrap flag
        out (PORT_CRTC_END),a
        ; --- Scroll origin ---
        ld hl,SCREEN_BASE
        ld a,l
        out (PORT_CRTC_SCRL),a
        ld a,h
        out (PORT_CRTC_SCRL),a
        ; --- Scroll end ---
        ld de,(SCR_START)
        call negate_sub
        dec hl
        ld a,l
        out (PORT_CRTC_SEND),a
        ld a,h
        or CRTC_WRAP
        out (PORT_CRTC_SEND),a
        ; --- Activate ---
        ld a,CRTC_START
        out (PORT_CRTC_CMD),a
        ret

; ==========================================================================
; CRT VSYNC ISR (vector F0 → 0670h)
; Reprograms CRTC every frame for smooth scrolling
; ==========================================================================
crt_vsync_isr:
        push af
        push de
        push hl
        call program_crtc
        ld a,DISP_ENABLE
        out (PORT_DISP_CMD),a
        pop hl
        pop de
        pop af
        ei
        ret

; ==========================================================================
; negate_sub — HL = DE - HL
; ==========================================================================
negate_sub:
        ld a,l
        cpl
        ld l,a
        ld a,h
        cpl
        ld h,a
        inc hl
        add hl,de
        ret

; ==========================================================================
; sub_hl_a — HL = HL - A
; ==========================================================================
sub_hl_a:
        push bc
        ld b,a
        ld a,l
        sub b
        ld l,a
        pop bc
        ret nc
        dec h
        ret

; ==========================================================================
; cmp_hl_de — Compare HL vs DE (carry if HL < DE)
; ==========================================================================
cmp_hl_de:
        ld a,h
        cp d
        ret nz
        ld a,l
        cp e
        ret

; ==========================================================================
; DATA TABLES
; ==========================================================================

; --- Boot prompt string ---
str_prompt:
        defb CHAR_CR,CHAR_LF,' '
        defm "BOSS"
        defm " .. "
        defb CHAR_NUL

; --- Floppy drive parameter tables (7 bytes each) ---
; Format: [id, id2, type/mode, param1, param2, param3, param4]
drv_param_a:
        defb 053h,030h,028h,001h,010h,020h,000h

drv_param_b:
        defb 053h,030h,04ch,001h,01ah,00eh,000h

drv_param_c:
        defb 053h,030h,04ch,000h,01ah,007h,080h

; --- SIO Channel A initialisation table (20 bytes, 10 pairs) ---
sio_init_tbl:
        defb 0e0h,0f0h,0e1h,0f2h,0e2h,0f4h,0e3h,0f6h
        defb 0e4h,0f8h,0e5h,0fah,0e6h,0fch,0e7h,0feh
        defb 0c0h,07fh,0b0h,0ffh

; --- Sector interleave table (32 entries: 0..31 sequential) ---
intrlv_tbl:
        defb 000h,001h,002h,003h,004h,005h,006h,007h
        defb 008h,009h,00ah,00bh,00ch,00dh,00eh,00fh
        defb 010h,011h,012h,013h,014h,015h,016h,017h
        defb 018h,019h,01ah,01bh,01ch,01dh,01eh,01fh

; --- FDC command templates (overlapping, read from different offsets) ---
fdc_cmd_read:
        defb 009h               ; Read command byte
fdc_cmd_sense:
        defb 005h               ; Sense interrupt status
fdc_cmd_recal:
        defb 004h               ; Recalibrate
        defb 001h,000h,000h,000h,000h,000h,000h

; --- CRT display init parameters (5 bytes + padding) ---
crt_init_data:
        defb 0ceh,05bh,06bh,056h,013h
        defb 000h,000h,000h,000h,000h

; ==========================================================================
; UNUSED (0700h-07EFh) — Zero-filled, available for expansion
; ==========================================================================
        defs 240

; ==========================================================================
; IM 2 INTERRUPT VECTOR TABLE (07F0h)
; ==========================================================================
        defw crt_vsync_isr                  ; 07F0: CRT refresh
        defw isr_stub                       ; 07F2: stub
        defw sio_rx_isr                     ; 07F4: SIO receive
        defw isr_stub                       ; 07F6: stub
        defw kbd_isr                        ; 07F8: keyboard
        defw isr_stub                       ; 07FA: stub
        defw isr_stub                       ; 07FC: stub
        defw isr_sio_err                    ; 07FE: SIO error
