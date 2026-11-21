; ==========================================================================
; sg1000/hardware.asm - SG-1000 (TMS9918A + SN76489) definitions
; ==========================================================================

; --- VDP ports -----------------------------------------------------------
VDP_DATA    equ 0xBE        ; VRAM data port
VDP_CTRL    equ 0xBF        ; VRAM address / register port

; --- SN76489 PSG ---------------------------------------------------------
PSG_PORT    equ 0x7F

; --- controller ports ----------------------------------------------------
JOY1        equ 0xDC        ; P1: d-pad, buttons in bits 0-5, START in bit 6
JOY2        equ 0xDD        ; P2: d-pad and buttons in bits 2-5

; --- VRAM map ------------------------------------------------------------
VRAM_PATTERN    equ 0x0000  ; pattern generator, 0x000-0x27F
VRAM_NAMETABLE  equ 0x1800  ; 32 x 24 name table
VRAM_SPRITE_ATTR equ 0x1B00 ; 32 x 4 bytes
VRAM_SPRITE_PAT equ 0x3800  ; sprite patterns, 12 used
VRAM_COLOUR     equ 0x2000  ; colour table, one byte per group of 8 tiles

; --- VDP registers -------------------------------------------------------
; register 0 stays at zero: M3/M4 modes, sprite zoom and the left-hand
; column blanking are all off, which is exactly what we want
VDP_R0_VAL  equ 0x00
VDP_R1_VAL  equ 0xC0        ; 16x16 sprites, display on, frame interrupt on
VDP_R2_VAL  equ 0x06        ; name table  at 0x1800
VDP_R3_VAL  equ 0x80        ; colour table at 0x2000
VDP_R4_VAL  equ 0x00        ; pattern table at 0x0000 (low 1bpp only)
VDP_R5_VAL  equ 0x36        ; sprite attribute table at 0x1B00
VDP_R6_VAL  equ 0x07        ; sprite pattern table at 0x3800
VDP_R7_VAL  equ 0x01        ; backdrop black, text/foreground white

; --- screen geometry -----------------------------------------------------
; The bottle is 8 columns x 16 rows.  It sits on the left of the screen with
; the status panel down the right hand side.
FIELD_X0    equ 8           ; leftmost column of the playfield, in tiles
FIELD_Y0    equ 4           ; top row of the playfield, in tiles
BOTTLE_X0   equ FIELD_X0-1  ; frame is one tile outside the playfield
BOTTLE_Y0   equ FIELD_Y0-1

; --- colours (TMS9918A palette indices) ---------------------------------
C_BLACK     equ 0x01
C_GRAY      equ 0x0E
C_WHITE     equ 0x0F
C_LYELLOW   equ 0x0B
C_LRED      equ 0x09
C_LBLUE     equ 0x05

; --- field objects (same encoding as the NES disassembly) ---------------
O_EMPTY     equ 0xFF
O_TOP       equ 0x40
O_BOTTOM    equ 0x50
O_LEFT      equ 0x60
O_RIGHT     equ 0x70
O_SINGLE    equ 0x80
O_CLEARED   equ 0xB0
O_VIRUS     equ 0xD0
MASK_TYPE   equ 0xF0
MASK_COLOR  equ 0x0F

; --- colours -------------------------------------------------------------
COL_YELLOW  equ 0
COL_RED     equ 1
COL_BLUE    equ 2

; --- joypad bits --------------------------------------------------------
BTN_UP      equ 0x01
BTN_DOWN    equ 0x02
BTN_LEFT    equ 0x04
BTN_RIGHT   equ 0x08
BTN_B1      equ 0x10        ; rotate clockwise
BTN_B2      equ 0x20        ; rotate counter clockwise
BTN_START   equ 0x40

; --- sound effects ------------------------------------------------------
SFX_NONE    equ 0
SFX_MOVE    equ 1
SFX_ROTATE  equ 2
SFX_LAND    equ 3
SFX_CLEAR   equ 4
SFX_VIRUS   equ 5
SFX_OVER    equ 6

; --- tile numbers (see tools/gen_tiles.py) ------------------------------
T_DIGIT0    equ 0x00        ; '0'-'9'
T_A         equ 0x0A        ; 'A'-'Z'
T_SPACE     equ 0x24
T_COLON     equ 0x25
T_DASH      equ 0x26
T_BANG      equ 0x27
T_BOTTLE    equ 0x28        ; frame pieces, +0..+7
T_PILL      equ 0x30        ; + colour*8 + shape
T_VIRUS     equ 0x36        ; + colour*8
S_TOP       equ 0
S_BOTTOM    equ 1
S_LEFT      equ 2
S_RIGHT     equ 3
S_SINGLE    equ 4
S_FLASH     equ 5
