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
;   - Hardware initialisation (CRT, 2651 USART, 8255 PPI, µPD765 FDC, DMA, AMD 9519 UIC)
;   - A command prompt ("BOSS ..") accepting:
;       CR    — Boot from floppy (auto-detect local FDC vs USART-linked controller)
;       B drive,start — Boot from USART-linked drive (unit 0-3, start sector)
;       L     — Load from local FDC
;       G addr — Go (jump to address)
;       *     — Keyboard echo mode (type to screen until ESC)
;   - Display driver (80x27 scrolling text, cursor management)
;   - Block record loader (reads sectors, parses framed records into RAM)
;   - Floppy disk access via local FDC (active-low) or USART-linked controller
;
; Memory Map (only ranges referenced by code):
;   0000-07FF : System ROM (banks out via port 60h bit 0)
;   BED2-BFFF : Work RAM (stack at BED2, DMA buf BED3, variables BFD3-BFFF)
;   F2C6-FFE5 : Display buffer (28 lines × 120 bytes = 3360 bytes)
;               Each line: 80 chars + 38 pad + 2 end markers
;   FFE6-FFEF : Display state variables (scroll ptrs, cursor pos)
;
; I/O Port Map:
;   00-01 : Intel 8257 DMA controller (address, word count; flip-flop low/high)
;   04-07 : CRT controller (start/end/scroll address registers)
;   08    : CRT controller command
;   10    : 2651 USART control/status (disk controller serial link)
;   11    : 2651 USART data (disk controller serial link)
;   30-31 : AMD 9519 UIC (Universal Interrupt Controller)
;           Port 31=register select, port 30=data/vector
;   40    : 8255 PPI Port A (keyboard data, active-low)
;   43    : 8255 PPI control register
;   60    : System control (write: ROM bank/drive; read: config)
;   71    : FDC control/mode select
;   72    : FDC status (active-low)
;   73    : FDC data (active-low)
;   80    : NEC µPD3301 data port (parameter bytes after command)
;   81    : NEC µPD3301 command register
;
; Interrupts: IM 2, I=07h, vector table at 07F0h
;   07F0: CRT vsync      → 0670h (reprogram CRTC each frame)
;   07F2: stub           → 03D8h (EI; RET)
;   07F4: USART RX       → 032Ch (serial receive handler)
;   07F6: stub           → 03D8h (EI; RET)
;   07F8: keyboard       → 053Fh (PPI port A read)
;   07FA: stub           → 03D8h (EI; RET)
;   07FC: stub           → 03D8h (EI; RET)
;   07FE: USART error    → 03DAh (acknowledge + RET)
;
; Execution Flow:
;   0000h  reset        → cold_start (full hardware init)
;   0004h  warm_entry   → warm_start (USART/display reinit only)
;   007Ah  cmd_loop     — prompt and command dispatch
;   0190h  serial_rx    — serial binary receive protocol
;   0447h  fdc_read_sector — floppy disk sector read
;
; ==========================================================================

; --- ASCII control characters ---
CHAR_NUL:           equ	000h
CHAR_LF:            equ	00ah            ; Line feed
CHAR_CR:            equ	00dh            ; Carriage return
CHAR_ESC:           equ	01bh            ; Escape

; --- NEC µPD3301 command bytes ---
DISP_RESET:         equ	000h            ; µPD3301 reset
DISP_ON:            equ	020h            ; µPD3301 display on
DISP_CURSOR:        equ	081h            ; µPD3301 set cursor position
DISP_ENABLE:        equ	0a0h            ; µPD3301 enable display output
DISP_MODE:          equ	042h            ; µPD3301 set display mode
DISP_START:         equ	0c0h            ; µPD3301 start display output

; --- CRT controller commands ---
CRTC_INIT:          equ	041h            ; CRTC initialise
CRTC_START:         equ	0c5h            ; CRTC start DMA / run
CRTC_WRAP:          equ	080h            ; Address wrap flag in CRTC registers

; --- Serial protocol record types ---
REC_DATA:           equ	0c2h            ; Data record (store bytes)
REC_ABORT:          equ	0d2h            ; Abort/error record
REC_EXEC:           equ	0c6h            ; Execute record (jump to address)
REC_SKIP_LO:        equ	0c1h            ; Lower bound of skip range
REC_SKIP_HI:        equ	0dbh            ; Upper bound of skip range

; --- FDC commands ---
FDC_RECAL:          equ	007h            ; Recalibrate command
FDC_SEEK:           equ	00fh            ; Seek command
FDC_STAT_RDY:       equ	002h            ; Status: ready bit
FDC_STAT_DRQ:       equ	040h            ; Status: data request
FDC_STAT_BUSY:      equ	082h            ; Status: busy + DRQ combined

; --- System control port values ---
SYS_BANKOUT:        equ	001h            ; Bank out ROM, map RAM at 0000h
SYS_DRV_SEL:        equ	002h            ; Drive select / enable
SYS_DENSITY:        equ	080h            ; Bit 7: density flag
SYS_TYPE_MASK:      equ	003h            ; Drive type mask (after rotation)
SYS_BIT5:           equ	020h            ; Config bit 5
SYS_TYPE_BITS:      equ	0c0h            ; Drive type bits 7:6

; --- PPI mode/BSR values ---
PPI_MODE_SET:       equ	0bch            ; Port A=input(mode1), B=input
PPI_BSR_PC2:        equ	005h            ; BSR: set PC2 (strobe)
PPI_BSR_PC4:        equ	009h            ; BSR: set PC4 (int enable)

; --- Display geometry ---
SCR_COLS:           equ	80              ; Columns per line
SCR_LINES:          equ	27              ; Visible screen lines
SCR_STRIDE:         equ	120             ; Bytes per display line (80+38+2)
SCR_MAX_COL:        equ	79              ; Maximum column index (0-based)
SCR_PAD:            equ	38              ; Padding bytes per line

; --- I/O Port equates ---
PORT_DMA_ADDR:      equ	000h            ; Intel 8257 DMA — address register (write low then high)
PORT_DMA_COUNT:     equ	001h            ; Intel 8257 DMA — word count register (write low then high)
PORT_CRTC_START:    equ	004h
PORT_CRTC_END:      equ	005h
PORT_CRTC_SCRL:     equ	006h
PORT_CRTC_SEND:     equ	007h
PORT_CRTC_CMD:      equ	008h
PORT_USART_CTRL:    equ	010h            ; 2651 USART control/status
PORT_USART_DATA:    equ	011h            ; 2651 USART data
PORT_UIC_DATA:      equ	030h            ; AMD 9519 UIC data/vector
PORT_UIC_REG:       equ	031h            ; AMD 9519 UIC register select
PORT_PPI_A:         equ	040h
PORT_PPI_CTRL:      equ	043h
PORT_SYS_CTRL:      equ	060h
PORT_FDC_CTRL:      equ	071h
PORT_FDC_STAT:      equ	072h
PORT_FDC_DATA:      equ	073h
PORT_UPD3301_DATA:  equ	080h            ; NEC µPD3301 — parameter data port
PORT_UPD3301_CMD:   equ	081h            ; NEC µPD3301 — command register

; --- Miscellaneous constants ---
RELAY_LEN:          equ	5               ; Length of relay code copied to RAM
BUF_SIZE:           equ	255             ; DMA buffer usable bytes
FDC_CMD_LEN:        equ	8               ; FDC command block length
MAX_DRIVES:         equ	4               ; Maximum drive/unit number
SEC_128:            equ	128             ; 128-byte sector size
SEC_PER_TRK_MAX:    equ	32              ; Max sectors per track
MAX_SECTOR:         equ	31              ; Maximum sector number (0-based)
MAX_HEAD:           equ	3               ; Maximum head number

; --- RAM variable equates ---
STACK_TOP:          equ	0bed2h          ; Stack pointer init / boot cmd storage
DMA_BUF:            equ	0bed3h          ; DMA transfer buffer (256 bytes)
BUF_PTR:            equ	0bfd3h          ; Buffer read pointer
BLOCK_CNT:          equ	0bfd5h          ; Block bytes remaining
LOAD_ADDR:          equ	0bfd7h          ; Current load address
FDC_CMD:            equ	0bfd9h          ; FDC command block (8 bytes)
SEC_PER_TRK:        equ	0bfdch          ; Sectors per track
FDC_PARAMS:         equ	0bfdfh          ; FDC working parameters
TRK_CMP_0:          equ	0bfe1h          ; Track compare (side 0)
TRK_CMP_1:          equ	0bfe3h          ; Track compare (side 1)
USART_CMD:          equ	0bfe5h          ; USART command buffer (to remote disk controller)
USART_SEEK:         equ	0bfe6h          ; USART seek command area
USART_SEEKD:        equ	0bfe7h          ; USART seek data byte
DRV_CONFIG:         equ	0bfe8h          ; Drive config (density/sides/sector)
DRV_PARAMS:         equ	0bfe9h          ; Drive parameter copy
CUR_TRACK:          equ	0bfeah          ; Current track number
SIDE_FLAG:          equ	0bfebh          ; Current side flag
STEP_RATE:          equ	0bfech          ; Step rate / interleave
FDC_SEEKBUF:        equ	0bfedh          ; FDC seek parameter buffer
USART_RXBUF:        equ	0bff0h          ; 2651 USART receive buffer
USART_DONE:         equ	0bffbh          ; USART completion flag
SEC_SIZE:           equ	0bffch          ; Sector size (16-bit)
PARAM_PTR:          equ	0bff9h          ; Pointer to drive param table
DRV_TYPE:           equ	0bff8h          ; Drive type/density flags
KEY_FLAG:           equ	0bffeh          ; Keyboard ready flag (0=none, 1=ready)
KEY_DATA:           equ	0bfffh          ; Keyboard data byte

; --- Display memory equates ---
SCREEN_BASE:        equ	0f2c6h          ; Start of character display buffer
SCR_LIMIT:          equ	0ffe6h          ; End of display buffer
SCR_START:          equ	0ffe8h          ; Scroll window start address
SCR_END:            equ	0ffeah          ; Scroll window end address
CUR_ADDR:           equ	0ffech          ; Cursor memory address
CUR_COL:            equ	0ffeeh          ; Cursor column (0-79)
CUR_LINE:           equ	0ffefh          ; Cursor line (0-27)


        org 00000h

; ==========================================================================
; RESET VECTOR (0000h) — Cold start entry point
; ==========================================================================
reset:
        jp cold_start                   ; Skip to full init

; Warm restart entry (after DI)
        di                              ; Already disabled by caller
warm_entry:
        jp warm_start                   ; Reinit serial only

; ==========================================================================
; COLD START — Full hardware initialisation
; ==========================================================================
cold_start:
        ld sp,STACK_TOP                 ; Init stack

        ; --- 8255 PPI initialisation ---
        ld a,PPI_MODE_SET               ; Mode set word:
        out (PORT_PPI_CTRL),a           ;   Port A=input(mode1), B=input, Cupper=in
        ld a,PPI_BSR_PC2                ; BSR: set bit PC2 (strobe)
        out (PORT_PPI_CTRL),a           ; Keyboard strobe active
        ld a,PPI_BSR_PC4                ; BSR: set bit PC4 (int enable)
        out (PORT_PPI_CTRL),a           ; Enable keyboard interrupt

        ; --- Clear keyboard flag ---
        xor a                           ; A = 0
        ld (KEY_FLAG),a                 ; No key pending

        ; --- Initialise display memory and CRT controller ---
        call init_display_mem           ; Fill screen with spaces
        call program_crtc               ; Set up scroll registers

        ; --- Initialise cursor state ---
        xor a                           ; A = 0
        ld (CUR_COL),a                  ; Column = 0
        ld a,SCR_LINES                  ; 27
        ld (CUR_LINE),a                 ; Line = 27 (bottom)

        ; --- Display controller setup ---
        xor a                           ; A = 0
        out (PORT_UPD3301_CMD),a           ; Reset display chip
        ld hl,crt_init_data             ; 5-byte timing table
        ld b,5                          ; 5 parameters
.crt_loop:
        ld a,(hl)                       ; Next timing byte
        out (PORT_UPD3301_DATA),a          ; Write param to display
        inc hl                          ; Advance table pointer
        djnz .crt_loop                  ; Loop all 5
        ld a,DISP_ENABLE                ; Enable display output
        out (PORT_UPD3301_CMD),a           ; Enable display
        ld a,DISP_MODE                  ; Mode register
        out (PORT_UPD3301_CMD),a           ; Set display mode
        ld a,DISP_START                 ; Activate
        out (PORT_UPD3301_CMD),a           ; Activate output

; ==========================================================================
; WARM START — Reinit serial + display (preserves PPI/CRT timing)
; ==========================================================================
warm_start:
        ld sp,STACK_TOP                 ; Reset stack
        call update_cursor              ; Sync cursor to hardware

        ld a,DISP_ON                    ; Switch on
        out (PORT_UPD3301_CMD),a           ; Display ON

        ; --- AMD 9519 UIC initialisation (8 interrupt vectors + 2 control) ---
        xor a                           ; A = 0
        out (PORT_UIC_REG),a            ; Reset UIC register pointer
        ld hl,uic_init_tbl              ; Table of reg/val pairs
        ld b,10                         ; 10 pairs to write
.uic_loop:
        ld a,(hl)                       ; Register address
        out (PORT_UIC_REG),a            ; Select UIC register
        inc hl                          ; Point to value
        ld a,(hl)                       ; Register value
        out (PORT_UIC_DATA),a           ; Write interrupt vector low byte
        inc hl                          ; Next pair
        djnz .uic_loop                  ; Loop all 10

        ; --- UIC post-init commands ---
        ld a,040h                       ; UIC control: reset
        out (PORT_UIC_REG),a            ; Send to AMD 9519
        ld a,0a1h                       ; UIC control: enable interrupts
        out (PORT_UIC_REG),a            ; Send to AMD 9519

        ; --- Set up IM 2 interrupts ---
        ld a,007h                       ; Vector page = 07xxh
        ld i,a                          ; Set interrupt vector base
        im 2                            ; Vectored interrupt mode

        ; --- Final UIC config ---
        ld a,02fh                       ; UIC control word
        out (PORT_UIC_REG),a            ; Send to AMD 9519
        ld a,02ch                       ; UIC control word
        out (PORT_UIC_REG),a            ; Send to AMD 9519
        ld a,020h                       ; UIC control word
        out (PORT_UIC_REG),a            ; Send to AMD 9519
        ei                              ; Enable interrupts

; ==========================================================================
; COMMAND LOOP — Print prompt, parse commands
; ==========================================================================
cmd_loop:
        ld sp,STACK_TOP                 ; Reset stack on re-entry
        ld hl,str_prompt                ; "\r\n BOSS .. "
.print_loop:
        ld c,(hl)                       ; Next char from string
        call putchar                    ; Print it
        inc hl                          ; Advance pointer
        ld a,(hl)                       ; Peek next
        or a                            ; NUL terminator?
        jp nz,.print_loop               ; No — keep printing

        ; --- Read command ---
        ld b,0                          ; Clear digit count
        call getchar_echo               ; Wait for keypress
        ld a,c                          ; Command char
        cp CHAR_CR                      ; CR → floppy boot
        jp z,cmd_boot                   ; Auto-boot
        ex af,af'                       ; Save command
        ld c,':'                        ; Print ':'
        call putchar                    ; Echo separator
        ex af,af'                       ; Restore command
        cp '*'                          ; '*' → echo mode
        jp z,cmd_terminal               ; Enter keyboard echo
        cp 'B'                          ; 'B' → USART-linked drive boot
        jp z,cmd_load                   ; USART-linked drive load
        cp 'L'                          ; 'L' → floppy load
        jp z,cmd_load                   ; Floppy load
        cp 'G'                          ; 'G' → go to address
        jp z,cmd_go                     ; Jump to address

cmd_error:
        ld c,'#'                        ; '#' = error indicator
        call putchar                    ; Print error
        jp cmd_loop                     ; Back to prompt

; ==========================================================================
; COMMAND: B/L — Load from disk (USART-linked or local FDC)
; Syntax: B drive,start<CR> or L<CR>
; ==========================================================================
cmd_load:
        ex af,af'                       ; Recover command char
        call parse_hex                  ; Parse address → DE
        dec b                           ; Any digits parsed?
        jp m,cmd_noaddr                 ; No digits: special case
        ld a,c                          ; Terminator char
        cp ','                          ; Expect ','
        jp nz,cmd_error                 ; Bad separator
        ld a,d                          ; Address high byte
        or a                            ; Must be zero
        jp nz,cmd_error                 ; Must be 00xx
        or e                            ; Drive number in E
        cp MAX_DRIVES                   ; Max drive/unit = 3
        jp nc,cmd_error                 ; Too high
        push af                         ; Save drive number
        call parse_hex                  ; Parse size
        dec b                           ; Any digits?
        ld a,c                          ; Terminator
        pop bc                          ; Recover drive in B
        jp m,cmd_error                  ; No size given
        cp CHAR_CR                      ; Must end with CR
        jp nz,cmd_error                 ; Trailing garbage

; --- Common load entry (DE=start sector, AF'=command type) ---
start_load:
        ld (LOAD_ADDR),de               ; Save start sector
        ex af,af'                       ; Get command type
        ld (STACK_TOP),a                ; Store command type
        cp 'L'                          ; 'L' → floppy path
        jp z,floppy_load                ; Use FDC path

        ; --- USART path: enable controller ---
        ld a,SYS_DRV_SEL                ; Select drive
        out (PORT_SYS_CTRL),a           ; Enable USART-linked drive controller

        ; --- Delay (device settle / motor spin-up) ---
        ld de,084c6h                    ; ~34000 iterations
.delay:
        ex (sp),hl                      ; Burn cycles (8T)
        ex (sp),hl                      ; Burn cycles (8T)
        dec de                          ; Count down
        ld a,e                          ; Test DE == 0
        or d                            ; (OR low and high)
        jp nz,.delay                    ; Wait for motor

        ; --- Detect drive type from system config port ---
        ld a,b                          ; Drive number from cmd
        ld (DRV_PARAMS),a               ; Store for later
        in a,(PORT_SYS_CTRL)            ; Read system config
        ld c,a                          ; Save full value
        and SYS_DENSITY                 ; Bit 7 = density
        rrca                            ; Shift to bit 6
        ld (DRV_TYPE),a                 ; Save density flag
        ld a,c                          ; Recover config
        rlca                            ; Shift bits 7:6
        rlca                            ;   into bits 1:0
        and SYS_TYPE_MASK               ; Bits 7:6 → type 0-3
        ld hl,drv_param_a               ; Default: type A
        jp nz,.got_type                 ; Non-zero = valid type
        ld a,040h                       ; Type 0: special flag
        ld (DRV_TYPE),a                 ; Mark as special
        jp .sel_params                  ; Use default params
.got_type:
        ld hl,drv_param_c               ; Try type C first
        dec a                           ; Type 1?
        jp z,.sel_params                ; Yes — use C
        ld hl,drv_param_a               ; Try type A
        dec a                           ; Type 2?
        jp z,.sel_params                ; Yes — use A
        ld hl,drv_param_b               ; Otherwise type B
.sel_params:
        ld (PARAM_PTR),hl               ; Store selected table

        ; --- Build and send USART command ---
        ld de,USART_CMD                   ; Command buffer
        ld a,3                          ; Command byte count
        ld (de),a                       ; Store length
        inc de                          ; Point to payload
        ld c,2                          ; Copy 2 bytes from table
        call memcopy                    ; Param table → USART_CMD
        ld c,3                          ; 3 bytes to send
        ld hl,USART_CMD                   ; Point to buffer
        call usart_send_blk             ; Send to USART-linked controller

        ; --- Init track limits ---
        ld hl,0ffffh                    ; -1 = never seeked
        ld (TRK_CMP_0),hl               ; Side 0 uninit
        ld (TRK_CMP_1),hl               ; Side 1 uninit

        ; --- Configure drive ---
        ld hl,DRV_CONFIG                ; Config byte address
        ld (hl),004h                    ; Init config command
        ld c,2                          ; 2 bytes
        call usart_send_blk               ; Send config request
        call usart_read_stat              ; Read drive response
        ld a,(hl)                       ; Status byte
        and 008h                        ; Bit 3 = double sided?
        rlca                            ; Shift bit 3
        rlca                            ;   up to bit 7
        rlca                            ;   ...
        rlca                            ;   now in bit 7
        ld hl,DRV_TYPE                  ; Drive type flags
        or (hl)                         ; Merge with density
        or 006h                         ; Set standard bits
        ld (DRV_CONFIG),a               ; Final config byte

        ; --- Calculate sector size from param table ---
        ld hl,(PARAM_PTR)               ; Drive params base
        inc hl                          ; Skip id byte 1
        inc hl                          ; Skip id byte 2
        rlca                            ; Config bit → carry
        ld a,(hl)                       ; Base sector count
        jp nc,.no_dbl                   ; No doubling needed
        rlca                            ; Double if config set
.no_dbl:
        ld b,a                          ; Save interim value
        in a,(PORT_SYS_CTRL)            ; Read system config
        and SYS_BIT5                    ; Check bit 5
        ld a,b                          ; Restore value
        jp z,.no_shift                  ; Bit 5 clear: skip
        rlca                            ; Double again for bit 5
.no_shift:
        ld b,a                          ; B = sectors high
        inc hl                          ; Skip to size field
        inc hl                          ; ...
        ld a,(DRV_TYPE)                 ; Check drive type
        or a                            ; Type 0?
        ld a,(hl)                       ; Raw size byte
        jp nz,.use_val                  ; Non-zero type: use as-is
        rrca                            ; Type 0: halve it
.use_val:
        ld l,a                          ; L = size low
        ld h,b                          ; H = size high
        ld (SEC_SIZE),hl                ; Save computed sector size

; ==========================================================================
; SERIAL RECEIVE — Block-framed binary transfer protocol
; ==========================================================================
serial_rx:
        ld hl,0                         ; Zero
        ld (BLOCK_CNT),hl               ; No bytes buffered yet
.next_rec:
        call get_srx_byte               ; Record byte count
        and a                           ; Test for zero
        jp z,cmd_error                  ; Zero length = error
        ld c,a                          ; C = byte counter (auto-restarts at 0)
        call get_srx_byte               ; Record type
        ld b,a                          ; B = record type
        ld a,c                          ; Check remaining count
        cp 3                            ; Count ≥ 3: has address fields
        jp c,.short_rec                 ; Short record: no addr
        call get_srx_byte               ; Address high
        ld h,a                          ; H = addr high
        call get_srx_byte               ; Address low
        ld l,a                          ; L = addr low
        call get_srx_byte               ; Extra byte (ignored)
.short_rec:
        ld a,b                          ; Record type byte
        cp REC_DATA                     ; Data record
        jp z,.data_rec                  ; Go store bytes
        cp REC_ABORT                    ; Abort
        jp z,cmd_error                  ; Fatal
        cp REC_EXEC                     ; Execute record
        jp z,.exec_rec                  ; Go launch program
        cp REC_SKIP_LO                  ; Below skip range?
        jp c,cmd_error                  ; Invalid type
        cp REC_SKIP_HI                  ; Above skip range?
        jp nc,cmd_error                 ; Invalid type
.skip_rec:
        call get_srx_byte               ; Consume record bytes
        jp .skip_rec                    ; Until C exhausted

.data_rec:
        call get_srx_byte               ; Next data byte
        ld (hl),a                       ; Store byte at address
        inc hl                          ; Advance write pointer
        jp .data_rec                    ; Until C exhausted

.exec_rec:
        di                              ; Disable interrupts
        push hl                         ; Save exec address
        push de                         ; Save DE
        ld hl,relay_code                ; Copy relay to RAM
        ld de,DMA_BUF                   ; Destination in RAM
        ld bc,RELAY_LEN                 ; 5 bytes
        ldir                            ; Copy relay code
        pop de                          ; Restore DE
        pop hl                          ; HL = exec address
        jp DMA_BUF                      ; Run relay from RAM

; --- Relay code (5 bytes, executes from RAM) ---
relay_code:
        ld a,SYS_BANKOUT                ; Bank out ROM
        out (PORT_SYS_CTRL),a           ; Map RAM at 0000h
        jp (hl)                         ; Jump to program

; ==========================================================================
; get_srx_byte — Get one byte from serial receive buffer
; Replenishes buffer from USART-linked controller when empty. Adjusts C count.
; ==========================================================================
get_srx_byte:
        inc c                           ; Test C without clobbering
        dec c                           ; Test C == 0
        jp nz,.have_byte                ; Bytes remain in record
        pop af                          ; Pop caller return addr
        inc c                           ; Reset count (non-zero)
        jp .next_rec                    ; Restart record loop
.have_byte:
        push hl                         ; Save caller's HL
        ld hl,(BLOCK_CNT)               ; Bytes left in buffer
        ld a,h                          ; Test if zero
        or l                            ; HL == 0?
        jp nz,.from_buf                 ; Still have data
        ; --- Refill buffer from disk/serial ---
        push hl                         ; Save regs
        push de                         ; ...
        push bc                         ; ...
        ld hl,(SEC_SIZE)                ; Sector size
        ex de,hl                        ; DE = sector size
        ld hl,(LOAD_ADDR)               ; Current disk position
        call do_sector_rw               ; Read next sector
        ld (LOAD_ADDR),hl               ; Update position
        pop bc                          ; Restore regs
        pop de                          ; ...
        pop hl                          ; ...
        ld hl,BUF_SIZE                  ; 255 bytes available
        ld (BLOCK_CNT),hl               ; Reset byte count
        ld hl,DMA_BUF                   ; Point to buffer start
        jp .read_one                    ; Read first byte
.from_buf:
        dec hl                          ; One fewer byte left
        ld (BLOCK_CNT),hl               ; Update count
        ld hl,(BUF_PTR)                 ; Current read position
.read_one:
        ld a,(hl)                       ; Read byte from buffer
        inc hl                          ; Advance pointer
        ld (BUF_PTR),hl                 ; Save new position
        pop hl                          ; Restore caller's HL
        dec c                           ; One fewer byte in record
        ret                             ; Return byte in A

; ==========================================================================
; do_sector_rw — Read one sector (dispatches to serial or floppy)
; Entry: DE=sector size, HL=current sector address
; Exit:  HL=next sector address
; ==========================================================================
do_sector_rw:
        ld a,(STACK_TOP)                ; Check mode
        cp 'L'                          ; 'L' = floppy
        jp z,fdc_read_sector            ; FDC path

        ; --- USART-linked path ---
        push hl                         ; Save sector address
        push de                         ; Save sector size
        call divide_hl_e                ; HL/E → track/sector
        ld a,(DRV_TYPE)                 ; Check drive type
        or a                            ; Type 0?
        ld a,b                          ; Remainder = sector
        jp nz,.not_t0                   ; Non-zero: use as-is
        add a,a                         ; Type 0: double sector#
.not_t0:
        inc a                           ; Sector 1-based
        ld (STEP_RATE),a                ; Store sector number
        ld a,l                          ; Track quotient
        pop de                          ; Recover sector size
        cp d                            ; Track < max?
        jp nc,cmd_error                 ; Track overflow

        ; --- Side selection ---
        ld a,(DRV_CONFIG)               ; Drive config flags
        rlca                            ; Bit 7 → carry (2-sided?)
        ld b,0                          ; Default: side 0
        ld a,l                          ; Track number
        jp nc,.one_side                 ; Single-sided drive
        or a                            ; Clear carry for RRA
        rra                             ; Track/2, odd→carry
        jp nc,.one_side                 ; Even track: side 0
        ld b,004h                       ; Side 1 flag
.one_side:
        ld (CUR_TRACK),a                ; Store physical track
        ld hl,DRV_PARAMS                ; Drive params byte
        ld a,(hl)                       ; Current value
        and 0fbh                        ; Clear side bit
        or b                            ; Set new side
        ld (hl),a                       ; Update params
        ld a,b                          ; Side flag
        rrca                            ; Shift to bit 0
        rrca                            ; (004h → 001h)
        ld (SIDE_FLAG),a                ; Store for seek

        ; --- Copy params from table ---
        ld hl,(PARAM_PTR)               ; Param table base
        inc hl                          ; Skip byte 0
        inc hl                          ; Skip byte 1
        inc hl                          ; Skip byte 2
        ld c,4                          ; 4 seek params
        ld de,FDC_SEEKBUF               ; Destination
        call memcopy                    ; Copy to work area

; --- DMA setup and sector transfer ---
.do_dma:
        ld a,0d3h                       ; DMA addr low (→BED3h)
        di                              ; Disable interrupts for DMA
        out (PORT_DMA_ADDR),a           ; Set DMA address low
        ld a,0beh                       ; DMA addr high
        out (PORT_DMA_ADDR),a           ; Set DMA address high
        ld a,0ffh                       ; DMA count low (255)
        out (PORT_DMA_COUNT),a          ; Set transfer count low
        ld a,040h                       ; DMA count high
        out (PORT_DMA_COUNT),a          ; Set transfer count high
        ei                              ; Re-enable interrupts
        ld a,CRTC_START                 ; Trigger CRT DMA
        out (PORT_CRTC_CMD),a           ; Start DMA

        ; --- Send seek + read command ---
        call seek_track                 ; Move head to position
        ld c,9                          ; 9-byte command block
        ld hl,DRV_CONFIG                ; Config + command data
        call usart_send_wait              ; Send and wait for reply
        dec a                           ; 1 = success
        jp nz,.chk_err                  ; Non-1: check error
        pop hl                          ; Done: recover address
        inc hl                          ; Next sector
        ret                             ; Return to caller
.chk_err:
        ld a,(USART_RXBUF+2)              ; Error status byte
        and 084h                        ; Fatal error bits?
        jp z,.do_dma                    ; Retry if recoverable
        call get_trk_cmp                ; Get track compare ptr
        ld (hl),0ffh                    ; Mark track failed
        jp .do_dma                      ; Retry on next track

; ==========================================================================
; memcopy — Copy C bytes from (HL) to (DE)
; ==========================================================================
memcopy:
        ld a,(hl)                       ; Read source byte
        ld (de),a                       ; Write to dest
        inc hl                          ; Next source
        inc de                          ; Next dest
        dec c                           ; Count down
        jp nz,memcopy                   ; Loop until done
        ret                             ; Return

; ==========================================================================
; get_trk_cmp — Get pointer to track compare value for current side
; ==========================================================================
get_trk_cmp:
        ld a,(DRV_PARAMS)               ; Current drive params
        and 003h                        ; Side select (bit 2 → offset 0 or 2?)
        ld hl,TRK_CMP_0                 ; Base of compare table
add_a_to_hl:
        add a,l                         ; HL += A
        ld l,a                          ; Update low byte
        ret nc                          ; No carry: done
        inc h                           ; Propagate carry
        ret                             ; Return

; ==========================================================================
; divide_hl_e — Unsigned division: HL / E → HL quotient, B remainder
; ==========================================================================
divide_hl_e:
        xor a                           ; Clear accumulator
        ld d,16                         ; 16 bits to process
.div_loop:
        add hl,hl                       ; Shift HL left (into A)
        rla                             ; MSB of HL → A
        jp c,.do_sub                    ; Overflow: must subtract
        cp e                            ; A >= divisor?
        jp c,.no_sub                    ; No: skip subtraction
.do_sub:
        inc l                           ; Set quotient bit
        sub e                           ; A -= divisor
.no_sub:
        dec d                           ; Next bit
        jp nz,.div_loop                 ; Loop all 16 bits
        ld b,a                          ; Remainder in B
        ret                             ; HL=quotient, B=remainder

; ==========================================================================
; seek_track — Seek FDC to correct track (with recalibrate if needed)
; ==========================================================================
seek_track:
        call get_trk_cmp                ; HL → track compare slot
        ld a,(hl)                       ; Last position this side
        inc a                           ; Was it FFh (uninit)?
        jp z,.first_seek                ; FF = never seeked
.chk_pos:
        ld a,(CUR_TRACK)                ; Desired track
        cp (hl)                         ; Already there?
        ret z                           ; Yes: nothing to do
        or a                            ; Track 0?
        ex de,hl                        ; DE = compare slot
        jp z,.recal                     ; Track 0 = recalibrate
        ; --- Seek to non-zero track ---
        ld hl,USART_SEEKD                 ; Seek data buffer
        ld (hl),a                       ; Target track number
        ld b,FDC_SEEK                   ; Seek command code
        ld c,3                          ; 3-byte command
.exec_seek:
        ld hl,USART_SEEK                ; Command buffer
        ld a,(DRV_PARAMS)               ; Drive select byte
        ld (hl),a                       ; Drive select param
        dec hl                          ; Point to command byte
        ld (hl),b                       ; Command byte
        call usart_send_wait              ; Send and wait
        ld a,(CUR_TRACK)                ; New position
        ld (de),a                       ; Update compare slot
        ret                             ; Done
.first_seek:
        ex de,hl                        ; DE = compare slot
        call .recal                     ; Recalibrate first
        ex de,hl                        ; HL = compare slot
        ld (hl),0                       ; Record: at track 0
        jp .chk_pos                     ; Now seek to target
.recal:
        ld b,FDC_RECAL                  ; Recal command code
        ld c,2                          ; 2-byte command
        call .exec_seek                 ; Send recal
        ld a,(USART_DONE)                 ; Completion status
        dec a                           ; 1 = success
        ld a,0                          ; Don't affect flags
        ret z                           ; Success: done
        jp .recal                       ; Retry recal

; ==========================================================================
; USART RX INTERRUPT HANDLER (vector F4 → 032Ch)
; ==========================================================================
usart_rx_isr:
        push af                         ; Save A
        ld a,03ah                       ; RETI acknowledge
        out (PORT_UIC_REG),a            ; Acknowledge interrupt to AMD 9519
        ei                              ; Re-enable interrupts
        push bc                         ; Save BC
        push hl                         ; Save HL
.rx_loop:
        call usart_read_stat              ; Poll for data
        ld a,b                          ; Byte count received
        and a                           ; Any data?
        jp z,.rx_ack                    ; No data: send ACK
        ld hl,USART_RXBUF+1               ; Point to status byte
        ld a,(hl)                       ; Read status
        rlca                            ; Bit 7 → carry
        jp c,.rx_err                    ; Bit 7 set: error
        rlca                            ; Bit 6 → carry
        jp c,.rx_err                    ; Bit 6 set: error
        ld a,1                          ; Normal completion
.rx_done:
        ld (USART_DONE),a                 ; Signal completion
        pop hl                          ; Restore HL
        pop bc                          ; Restore BC
        pop af                          ; Restore A
        ret                             ; Return from ISR
.rx_err:
        ld a,07fh                       ; Error flag
        jp .rx_done                     ; Signal error
.rx_ack:
        ld hl,USART_CMD                   ; Command buffer
        ld (hl),008h                    ; ACK command byte
        ld c,1                          ; 1 byte to send
        call usart_tx_wait                ; Send ACK
        jp .rx_loop                     ; Continue polling

; ==========================================================================
; usart_read_stat — Read status/data bytes from 2651 USART (Channel B, ports 10-11)
; Exit: B = byte count received, data at USART_RXBUF+
; ==========================================================================
usart_read_stat:
        ld hl,USART_RXBUF               ; Buffer start
        ld b,0                          ; Clear byte count
.poll:
        in a,(PORT_USART_CTRL)          ; Read 2651 USART status
        rlca                            ; Bit 7 → carry
        jp nc,.poll                     ; Wait for ready
        ld c,a                          ; Save status
        and 020h                        ; Check data avail bit
        ret z                           ; No data: return
        ld a,c                          ; Recover status
        rlca                            ; Check another bit
        jp nc,.poll                     ; Not valid yet
        in a,(PORT_USART_DATA)          ; Read byte from 2651 USART
        inc hl                          ; Advance buffer pointer
        inc b                           ; Count bytes
        ld (hl),a                       ; Store in buffer
        jp .poll                        ; Check for more

; ==========================================================================
; usart_tx_wait — Wait for 2651 USART TX buffer empty, then send
; ==========================================================================
usart_tx_wait:
        in a,(PORT_USART_CTRL)          ; Read 2651 USART status
        and 010h                        ; TX busy?
        jp nz,usart_tx_wait               ; Wait until not busy

; ==========================================================================
; usart_send_blk — Send C bytes from (HL) to 2651 USART (ports 10-11)
; ==========================================================================
usart_send_blk:
        in a,(PORT_USART_CTRL)          ; 2651 USART status
        rlca                            ; Check ready bit
        jp nc,usart_send_blk              ; Wait for ready
        rlca                            ; Check busy bit
        jp c,usart_send_blk               ; Wait for not busy
        ld a,(hl)                       ; Get byte to send
        out (PORT_USART_DATA),a         ; Transmit byte via 2651 USART
        inc hl                          ; Next source byte
        dec c                           ; Count down
        jp nz,usart_send_blk              ; Loop until all sent
        ret                             ; Done

; ==========================================================================
; usart_send_wait — Send block and wait for ISR completion
; ==========================================================================
usart_send_wait:
        call usart_tx_wait                ; Wait TX ready
        xor a                           ; A = 0
        ld (USART_DONE),a                 ; Clear completion flag
        di                              ; Critical section
        ld a,02ah                       ; Reset TX INT
        out (PORT_UIC_REG),a            ; Enable TX interrupt via UIC
        ei                              ; End critical section
.wait:
        ld a,(USART_DONE)                 ; Poll completion flag
        or a                            ; Set yet?
        jp z,.wait                      ; No: keep waiting
        ret                             ; Done, status in A

; ==========================================================================
; parse_hex — Read hex digits, build 16-bit value in DE
; Exit: DE=value, B=digit count, C=terminating char
; ==========================================================================
parse_hex:
        ld de,0                         ; Result = 0
        ld b,e                          ; Digit count = 0
.next:
        call getchar_echo               ; Get next char
        ld a,c                          ; A = char
        sub '0'                         ; Convert from ASCII
        cp 10                           ; Digit 0-9?
        jp c,.digit                     ; Yes: use directly
        cp 17                           ; Gap between '9' and 'A'
        ret c                           ; Non-hex char: done
        sub 7                           ; 'A'-'F' → 10-15
.digit:
        cp 16                           ; Valid nybble?
        ccf                             ; Invert carry
        ret c                           ; >15: done
        inc b                           ; Count digit
        ld l,a                          ; Digit value in L
        ld h,0                          ; HL = digit (0-15)
        ld a,16                         ; 16 iterations
.mul16:
        add hl,de                       ; HL += DE (old value)
        jp c,cmd_error                  ; Overflow: error
        dec a                           ; Loop counter
        jp nz,.mul16                    ; DE*16 by repeated add
        ex de,hl                        ; DE = new accumulated val
        jp .next                        ; Next digit

; ==========================================================================
; INTERRUPT STUBS
; ==========================================================================
isr_stub:
        ei                              ; Re-enable interrupts
        ret                             ; Return (do nothing)

isr_usart_err:
        ei                              ; Re-enable interrupts
        push af                         ; Save A
        ld a,07fh                       ; AMD 9519 UIC error acknowledge
        out (PORT_UIC_REG),a            ; Clear error condition in UIC
        pop af                          ; Restore A
        ret                             ; Return

; ==========================================================================
; COMMAND: L (floppy-only path) — Floppy disk load
; ==========================================================================
floppy_load:
        dec b                           ; Any digits parsed?
        jp p,cmd_error                  ; Should have none
        out (PORT_FDC_CTRL),a           ; FDC mode select
        ; --- Init FDC command block ---
        ld hl,FDC_CMD                   ; Command buffer
        ld (hl),1                       ; +0: ? (command/mode?)
        inc hl                          ; Next field
        ld (hl),1                       ; +1: ? (initial sector?)
        inc hl                          ; Next field
        xor a                           ; A = 0
        ld (hl),a                       ; +2: 0 (initial head?)
        ld hl,FDC_PARAMS                ; Working params
        ld (hl),a                       ; Clear param 0
        inc hl                          ; Next byte
        ld (hl),a                       ; Clear param 1
        ; --- Compute sectors from size ---
        ex de,hl                        ; HL = load size (from DE)
        ld de,SEC_128                   ; 128-byte sectors
        add hl,de                       ; Round up (size+128)
        ld e,SEC_PER_TRK_MAX            ; 32 sectors/track
        call divide_hl_e                ; HL=tracks, B=sectors
        ex de,hl                        ; DE = track count
        ld hl,FDC_CMD+4                 ; Sector count field
        ld (hl),b                       ; Store remainder
        inc hl                          ; Next field
        ld a,e                          ; Track low bits
        and 003h                        ; Mask 2 bits
        ld (hl),a                       ; Store track extra
        ex de,hl                        ; HL = track count
        ld de,00004h                    ; 4 sides×heads
        call divide_hl_e                ; HL = cylinder count
        ld a,h                          ; High byte
        or a                            ; Should be 0
        jp nz,cmd_error                 ; Too many tracks
        or l                            ; Sectors per track
        ld (SEC_PER_TRK),a              ; Store spt
        ; --- Recalibrate and format/setup ---
        call fdc_recal                  ; Home the head
        jp nz,cmd_error                 ; Recal failed
        call fdc_prep                   ; Prepare FDC
        ld hl,fdc_cmd_read              ; Read command
        call fdc_send_cmd               ; Send to FDC
        ld c,FDC_STAT_DRQ+FDC_STAT_RDY  ; Wait for DRQ+RDY
        call fdc_wait_stat              ; Poll status
        and FDC_STAT_RDY                ; Ready bit set?
        jp nz,.fmt_ok                   ; Already formatted
        ld hl,intrlv_tbl                ; Interleave table
        ld b,SEC_PER_TRK_MAX            ; 32 sector IDs
        call fdc_send_data              ; Write interleave
.fmt_ok:
        call fdc_result                 ; Get status
        jp nz,cmd_error                 ; Failed
        jp serial_rx                    ; Start reading data

; ==========================================================================
; fdc_read_sector — Read one sector from FDC (floppy-mode path)
; Entry: HL on stack (load address)
; ==========================================================================
fdc_read_sector:
        push hl                         ; Save load address
.retry:
        call fdc_do_read                ; Attempt sector read
        jp nz,.retry                    ; Retry on error
        ; --- Advance sector/head/track ---
        ld hl,FDC_CMD+5                 ; Sector number field
        inc (hl)                        ; Next sector
        ld a,31                         ; Max sector
        cp (hl)                         ; Overflow?
        jp nc,.sec_ok                   ; No: keep going
        ld (hl),0                       ; Wrap sector to 0
        dec hl                          ; Head field
        inc (hl)                        ; Next head
        ld a,3                          ; Max head
        cp (hl)                         ; Overflow?
        jp nc,.sec_ok                   ; No: keep going
        ld (hl),0                       ; Wrap head to 0
        dec hl                          ; Track field
        inc (hl)                        ; Next track
.sec_ok:
        pop hl                          ; Restore load address
        inc hl                          ; Advance to next
        ret                             ; Return

; ==========================================================================
; fdc_do_read — Execute single sector read from FDC
; Exit: Z=success, NZ=error (A=error code)
; ==========================================================================
fdc_do_read:
        call fdc_prep                   ; Prepare controller
        ld hl,FDC_CMD                   ; Command block
        call fdc_send_cmd               ; Send read command
.wait_rdy:
        ld c,FDC_STAT_BUSY              ; Wait for not-busy
        call fdc_wait_stat              ; Poll FDC
        and FDC_STAT_RDY                ; Check ready bit
        jp nz,.wait_rdy                 ; Not ready: keep waiting
        ; --- Read 256 bytes ---
        ld hl,DMA_BUF                   ; Destination buffer
        ld b,0                          ; 256 iterations (0 wraps)
.rd_byte:
        in a,(PORT_FDC_DATA)            ; Read raw byte
        cpl                             ; Active-low invert
        ld (hl),a                       ; Store in buffer
        inc hl                          ; Next position
        djnz .rd_byte                   ; Loop 256 times
        ; --- Check result ---
        call fdc_result                 ; Get completion status
        ret z                           ; Success: return Z
        push af                         ; Save error code
        cp 8                            ; Error 8: need recal?
        jp z,.needs_recal               ; Yes
        cp 3                            ; Error >= 3?
        jp nc,.maybe_retry              ; Maybe retryable
.ret_err:
        pop af                          ; Restore error code
        ret                             ; Return NZ (error)
.maybe_retry:
        cp 6                            ; Error >= 6?
        jp nc,.ret_err                  ; Fatal: don't retry
.needs_recal:
        call fdc_recal                  ; Recalibrate head
        pop af                          ; Restore error code
        ret                             ; Return NZ (will retry)

; ==========================================================================
; fdc_recal — Send recalibrate command to FDC
; ==========================================================================
fdc_recal:
        call fdc_prep                   ; Prepare controller
        ld hl,fdc_cmd_recal             ; Recal command
        call fdc_send_cmd               ; Send to FDC
        ld c,FDC_STAT_RDY               ; Wait for completion
        call fdc_wait_stat              ; Poll until ready

; ==========================================================================
; fdc_result — Send "sense" command and read result byte
; Exit: A=status, Z=success
; ==========================================================================
fdc_result:
        call fdc_prep                   ; Prepare controller
        ld hl,fdc_cmd_sense             ; Sense interrupt cmd
        call fdc_send_cmd               ; Send to FDC
        ld c,FDC_STAT_BUSY              ; Wait not-busy + DRQ
        call fdc_wait_stat              ; Poll status
        and FDC_STAT_RDY                ; Data ready?
        jp nz,cmd_error                 ; No: fatal error
        in a,(PORT_FDC_DATA)            ; Read result byte
        cpl                             ; Active-low invert
        or a                            ; Z if success (0)
        ret                             ; Return status

; ==========================================================================
; fdc_prep — Prepare FDC (wait ready, toggle chip select)
; ==========================================================================
fdc_prep:
        ld c,FDC_STAT_RDY               ; Wait for ready
        call fdc_wait_stat              ; Poll until set
        cpl                             ; Invert for active-low
        out (PORT_FDC_STAT),a           ; Toggle chip select
        ld c,FDC_STAT_DRQ               ; Now wait for DRQ

; ==========================================================================
; fdc_wait_stat — Wait for FDC status bits in C (active-low)
; ==========================================================================
fdc_wait_stat:
        in a,(PORT_FDC_STAT)            ; Read FDC status
        cpl                             ; Invert (active-low)
        and c                           ; Test required bits
        ret nz                          ; Set: return
        jp fdc_wait_stat                ; Loop until set

; ==========================================================================
; fdc_send_cmd — Send 8 bytes from (HL) to FDC data port
; ==========================================================================
fdc_send_cmd:
        ld b,FDC_CMD_LEN                ; 8 bytes

; ==========================================================================
; fdc_send_data — Send B bytes from (HL) to FDC (with inversion)
; ==========================================================================
fdc_send_data:
        ld a,(hl)                       ; Get byte
        cpl                             ; Active-low invert
        out (PORT_FDC_DATA),a           ; Write to FDC
        inc hl                          ; Next byte
        djnz fdc_send_data              ; Loop B times
        ret                             ; Done

; ==========================================================================
; COMMAND: * — Keyboard echo mode (type to screen until ESC)
; ==========================================================================
cmd_terminal:
        call kbd_getchar                ; Wait for keypress
        cp CHAR_ESC                     ; ESC pressed?
        jp z,cmd_loop                   ; Yes: exit to prompt
        ld c,a                          ; Char in C for putchar
        call putchar                    ; Echo to display
        jp cmd_terminal                 ; Loop forever

; ==========================================================================
; COMMAND: CR — Auto-detect boot (local FDC vs USART-linked controller)
; ==========================================================================
cmd_boot:
        ld hl,SEC_128                   ; 128-byte sector size
        in a,(PORT_SYS_CTRL)            ; Read system config
        and SYS_TYPE_BITS               ; Drive type bits 7:6
        ld a,'B'                        ; Assume USART-linked controller
        jp nz,.set_type                 ; Non-zero = USART path
        ld a,'L'                        ; Zero = local FDC
        add hl,hl                       ; Floppy: 256-byte sectors
.set_type:
        ex de,hl                        ; DE = sector size
        ex af,af'                       ; Save boot type
        jp start_load                   ; Begin loading

; ==========================================================================
; cmd_noaddr — Handle B/L with no address (immediate CR)
; ==========================================================================
cmd_noaddr:
        ld a,c                          ; Terminator char
        cp CHAR_CR                      ; Must be CR
        jp nz,cmd_error                 ; Otherwise error
        ld b,0                          ; Drive 0 (default)
        ld de,1                         ; Start sector = 1
        jp start_load                   ; Begin loading

; ==========================================================================
; COMMAND: G addr — Jump to address (with ROM bank-out)
; ==========================================================================
cmd_go:
        call parse_hex                  ; Parse target address
        dec b                           ; Any digits?
        jp m,cmd_error                  ; None: error
        ld a,c                          ; Terminator char
        cp CHAR_CR                      ; Must be CR
        jp nz,cmd_error                 ; Otherwise error
        ex de,hl                        ; HL = target addr
        di                              ; Disable interrupts
        ld a,0ffh                       ; Vector page FFh
        ld i,a                          ; Vectors → FFxxh (RAM)
        im 2                            ; Keep IM 2 mode
        jp .exec_rec                    ; Bank out + jump

; ==========================================================================
; kbd_getchar — Wait for keyboard input (blocking poll)
; Returns char in A (7-bit ASCII)
; ==========================================================================
kbd_getchar:
        ld a,(KEY_FLAG)                 ; Check key ready
        or a                            ; Flag set?
        jp z,kbd_getchar                ; No: keep polling
        xor a                           ; A = 0
        ld (KEY_FLAG),a                 ; Clear flag
        ld a,(KEY_DATA)                 ; Get key code
        and 07fh                        ; 7-bit ASCII
        ret                             ; Return char in A

; ==========================================================================
; KEYBOARD ISR (vector F8 → 053Fh)
; ==========================================================================
kbd_isr:
        ei                              ; Re-enable interrupts
        push af                         ; Save A
        in a,(PORT_PPI_A)               ; Read keyboard port
        cpl                             ; Invert (active-low)
        ld (KEY_DATA),a                 ; Store key code
        ld a,1                          ; Flag = ready
        ld (KEY_FLAG),a                 ; Signal ready
        pop af                          ; Restore A
        ret                             ; Return from ISR

; ==========================================================================
; getchar_echo — Get char from keyboard, echo to display
; Returns char in C
; ==========================================================================
getchar_echo:
        call kbd_getchar                ; Wait for keypress
        ld c,a                          ; C = char (for putchar)

; ==========================================================================
; putchar — Output character C to display
; Handles CR (0Dh) and LF (0Ah) specially
; ==========================================================================
putchar:
        push bc                         ; Save registers
        push de                         ; ...
        push hl                         ; ...
        ld a,c                          ; Get character
        cp CHAR_CR                      ; CR?
        jp z,.do_cr                     ; Handle carriage return
        cp CHAR_LF                      ; LF?
        jp z,.do_lf                     ; Handle line feed
        ; --- Normal character ---
        ld hl,(CUR_ADDR)                ; Current screen position
        ld (hl),c                       ; Store char in display
        call advance_cur                ; Move cursor right
.done:
        pop hl                          ; Restore registers
        pop de                          ; ...
        pop bc                          ; ...
        ret                             ; Return
.do_lf:
        call scroll_line                ; Advance line
        jp .done                        ; Done
.do_cr:
        call carriage_ret               ; Move to column 0
        ld (CUR_ADDR),hl                ; Update cursor address
        call update_cursor              ; Sync to hardware
        jp .done                        ; Done

; ==========================================================================
; carriage_ret — Move cursor to column 0 of current line
; ==========================================================================
carriage_ret:
        ld hl,(CUR_ADDR)                ; Current position
        ld a,(CUR_COL)                  ; Current column
        call sub_hl_a                   ; HL -= column offset
        xor a                           ; A = 0
        ld (CUR_COL),a                  ; Column = 0
        ret                             ; HL = line start

; ==========================================================================
; advance_cur — Move cursor right, wrap at column 79
; ==========================================================================
advance_cur:
        ld hl,(CUR_COL)                 ; H=line, L=col
        ld a,SCR_MAX_COL                ; Col 79
        cp l                            ; At right edge?
        jp z,.wrap                      ; Yes: wrap to next line
        inc l                           ; Column += 1
        ld (CUR_COL),hl                 ; Update col/line
        ld hl,(CUR_ADDR)                ; Screen address
        inc hl                          ; Next character cell
        jp .set_addr                    ; Store and update cursor
.wrap:
        call carriage_ret               ; Back to column 0
        ld (CUR_ADDR),hl                ; Update address

; ==========================================================================
; scroll_line — Advance to next line, scroll if at bottom
; ==========================================================================
scroll_line:
        ld hl,CUR_LINE                  ; Line counter address
        inc (hl)                        ; Advance line
        ld a,SCR_LINES+1                ; Line 28 = overflow
        cp (hl)                         ; Past bottom?
        jp z,.scroll                    ; Yes: scroll screen
        ld hl,(CUR_ADDR)                ; Current address
        ld de,SCR_STRIDE                ; 120 bytes per line
        add hl,de                       ; Next line address
        jp c,.clamp                     ; Overflow: wrap
        ld de,(SCR_END)                 ; End of buffer
        call cmp_hl_de                  ; Past end?
        jp c,.set_addr                  ; No: use it
.clamp:
        ld hl,SCREEN_BASE               ; Wrap to buffer start
.set_line:
        ld a,(CUR_COL)                  ; Add column offset
        call add_a_to_hl                ; HL += col
.set_addr:
        ld (CUR_ADDR),hl                ; Store new position

; ==========================================================================
; update_cursor — Write cursor position to display hardware
; ==========================================================================
update_cursor:
        ld a,DISP_CURSOR                ; Cursor register select
        out (PORT_UPD3301_CMD),a           ; Send command
        ld hl,(CUR_COL)                 ; H=line, L=col
        ld a,l                          ; Column byte
        out (PORT_UPD3301_DATA),a          ; Column
        ld a,h                          ; Line byte
        out (PORT_UPD3301_DATA),a          ; Line
        ret                             ; Done

; --- Handle scrolling ---
.scroll:
        dec (hl)                        ; Back to line 27
        ld hl,(SCR_START)               ; First visible line
        ld (CUR_ADDR),hl                ; Cursor at top of freed line
        call init_one_line              ; Clear new bottom line
        ld de,(SCR_END)                 ; End of buffer
        call cmp_hl_de                  ; Past end?
        jp c,.scrl_ok                   ; No: fine
        ld hl,SCREEN_BASE               ; Wrap to top of buffer
.scrl_ok:
        ld (SCR_START),hl               ; Advance scroll window
        ld hl,(CUR_ADDR)                ; Get cursor position
        jp .set_line                    ; Recalculate + update

; ==========================================================================
; init_display_mem — Fill display buffer with blank lines
; ==========================================================================
init_display_mem:
        ld hl,SCREEN_BASE               ; Start of display RAM
        ld (SCR_START),hl               ; Scroll starts here
        ld b,SCR_LINES                  ; 27 visible lines
.clr_loop:
        call init_one_line              ; Fill one line
        djnz .clr_loop                  ; Loop all 27
        ld (SCR_LIMIT),hl               ; End of visible area
        ld (CUR_ADDR),hl                ; Cursor after last line
        call init_one_line              ; Extra scroll buffer line
        ld (SCR_END),hl                 ; Absolute end of buffer
        ret                             ; Done

; ==========================================================================
; init_one_line — Init one display line: 80 spaces + 38 NULs + FF 00
; Entry/Exit: HL = line start → HL = next line start
; ==========================================================================
init_one_line:
        push de                         ; Save DE
        ld a,SCR_COLS                   ; 80 characters
        ld e,' '                        ; Fill with spaces
        call fill_mem                   ; Write 80 spaces
        ld a,SCR_PAD                    ; 38 padding bytes
        ld e,0                          ; Fill with NUL
        call fill_mem                   ; Write padding
        ld (hl),0ffh                    ; End-of-line marker
        inc hl                          ; Next byte
        ld (hl),0                       ; Terminator
        inc hl                          ; HL = next line start
        pop de                          ; Restore DE
        ret                             ; Return

; ==========================================================================
; fill_mem — Fill A bytes at (HL) with byte E
; ==========================================================================
fill_mem:
        ld (hl),e                       ; Write fill byte
        inc hl                          ; Next position
        dec a                           ; Count down
        ret z                           ; Done when zero
        jp fill_mem                     ; Continue filling

; ==========================================================================
; program_crtc — Program CRT controller registers for scrolling display
; ==========================================================================
program_crtc:
        ld a,CRTC_INIT                  ; Init command
        out (PORT_CRTC_CMD),a           ; Reset CRTC
        ; --- Start address ---
        ld hl,(SCR_START)               ; Scroll window start
        ld a,l                          ; Low byte
        out (PORT_CRTC_START),a         ; Write start low
        ld a,h                          ; High byte
        out (PORT_CRTC_START),a         ; Write start high
        ; --- End address ---
        ld de,(SCR_END)                 ; Scroll window end
        call negate_sub                 ; HL = END - START
        dec hl                          ; Adjust (inclusive)
        ld a,l                          ; Low byte
        out (PORT_CRTC_END),a           ; Write end low
        ld a,h                          ; High byte
        or CRTC_WRAP                    ; Set wrap flag
        out (PORT_CRTC_END),a           ; Write end high
        ; --- Scroll origin ---
        ld hl,SCREEN_BASE               ; Buffer base address
        ld a,l                          ; Low byte
        out (PORT_CRTC_SCRL),a          ; Write origin low
        ld a,h                          ; High byte
        out (PORT_CRTC_SCRL),a          ; Write origin high
        ; --- Scroll end ---
        ld de,(SCR_START)               ; Current scroll start
        call negate_sub                 ; HL = START - BASE
        dec hl                          ; Adjust (inclusive)
        ld a,l                          ; Low byte
        out (PORT_CRTC_SEND),a          ; Write scroll end low
        ld a,h                          ; High byte
        or CRTC_WRAP                    ; Set wrap flag
        out (PORT_CRTC_SEND),a          ; Write scroll end high
        ; --- Activate ---
        ld a,CRTC_START                 ; Start DMA/display
        out (PORT_CRTC_CMD),a           ; Activate
        ret                             ; Done

; ==========================================================================
; CRT VSYNC ISR (vector F0 → 0670h)
; Reprograms CRTC every frame for smooth scrolling
; ==========================================================================
crt_vsync_isr:
        push af                         ; Save A/flags
        push de                         ; Save DE
        push hl                         ; Save HL
        call program_crtc               ; Reprogram scroll regs
        ld a,DISP_ENABLE                ; Re-enable display
        out (PORT_UPD3301_CMD),a           ; Write to display ctrl
        pop hl                          ; Restore HL
        pop de                          ; Restore DE
        pop af                          ; Restore A/flags
        ei                              ; Re-enable interrupts
        ret                             ; Return from ISR

; ==========================================================================
; negate_sub — HL = DE - HL
; ==========================================================================
negate_sub:
        ld a,l                          ; Low byte of HL
        cpl                             ; Invert
        ld l,a                          ; L = ~L
        ld a,h                          ; High byte of HL
        cpl                             ; Invert
        ld h,a                          ; H = ~H
        inc hl                          ; Two's complement
        add hl,de                       ; HL = DE - (old HL)
        ret                             ; Return result in HL

; ==========================================================================
; sub_hl_a — HL = HL - A
; ==========================================================================
sub_hl_a:
        push bc                         ; Save BC
        ld b,a                          ; B = subtrahend
        ld a,l                          ; L
        sub b                           ; L - A
        ld l,a                          ; Update L
        pop bc                          ; Restore BC
        ret nc                          ; No borrow: done
        dec h                           ; Propagate borrow
        ret                             ; Return

; ==========================================================================
; cmp_hl_de — Compare HL vs DE (carry if HL < DE)
; ==========================================================================
cmp_hl_de:
        ld a,h                          ; Compare high bytes
        cp d                            ; H vs D
        ret nz                          ; Different: carry set if H<D
        ld a,l                          ; Compare low bytes
        cp e                            ; L vs E
        ret                             ; Carry set if HL < DE

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
; Byte layout:
;   [0]   Controller type ID byte 1  (sent to USART-linked controller as type-select)
;   [1]   Controller type ID byte 2
;   [2]   Max tracks (track count; used as high byte of SEC_SIZE geometry word)
;   [3]   N    — µPD765 sector size code (0=128B, 1=256B, 2=512B)
;   [4]   EOT  — µPD765 end-of-track / sectors per track
;   [5]   GPL  — µPD765 gap length (read)
;   [6]   DTL  — µPD765 data length (ignored when N>0; = actual byte count when N=0)
;
; SEC_SIZE word = (byte[2] << 8) | byte[4] = (max_tracks, sectors_per_track)

drv_param_a:        ; 5.25" 40-track: 16 sectors × 256 B = 160 KB
        defb 053h   ; [0] controller ID byte 1
        defb 030h   ; [1] controller ID byte 2
        defb 028h   ; [2] max tracks = 40
        defb 001h   ; [3] N=1 → 256 bytes/sector
        defb 010h   ; [4] EOT = 16 sectors/track
        defb 020h   ; [5] GPL = 32
        defb 000h   ; [6] DTL (ignored, N>0)

drv_param_b:        ; 8" double-density: 26 sectors × 256 B
        defb 053h   ; [0] controller ID byte 1
        defb 030h   ; [1] controller ID byte 2
        defb 04ch   ; [2] max tracks = 76
        defb 001h   ; [3] N=1 → 256 bytes/sector
        defb 01ah   ; [4] EOT = 26 sectors/track
        defb 00eh   ; [5] GPL = 14 (standard 8" DD read gap)
        defb 000h   ; [6] DTL (ignored, N>0)

drv_param_c:        ; 8" single-density IBM 3740: 26 sectors × 128 B
        defb 053h   ; [0] controller ID byte 1
        defb 030h   ; [1] controller ID byte 2
        defb 04ch   ; [2] max tracks = 76
        defb 000h   ; [3] N=0 → 128 bytes/sector
        defb 01ah   ; [4] EOT = 26 sectors/track
        defb 007h   ; [5] GPL = 7 (standard 8" SD read gap)
        defb 080h   ; [6] DTL = 128 (= sector size when N=0)

; --- AMD 9519 UIC initialisation table (20 bytes: 8 vector pairs + 2 control) ---
; Each pair: (register_select, vector_low_byte) written to PORT_UIC_REG/DATA
; Vectors e0-e7 map to IM2 table entries at 07F0h-07FEh
uic_init_tbl:
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
        defb 009h                       ; Read command byte
fdc_cmd_sense:
        defb 005h                       ; Sense interrupt status
fdc_cmd_recal:
        defb 004h                       ; Recalibrate
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
        defw crt_vsync_isr              ; 07F0: CRT refresh
        defw isr_stub                   ; 07F2: stub
        defw usart_rx_isr               ; 07F4: USART receive
        defw isr_stub                   ; 07F6: stub
        defw kbd_isr                    ; 07F8: keyboard
        defw isr_stub                   ; 07FA: stub
        defw isr_stub                   ; 07FC: stub
        defw isr_usart_err              ; 07FE: USART error
