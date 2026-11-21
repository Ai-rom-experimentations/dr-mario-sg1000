; ==========================================================================
; sg1000/ram.asm - all game state lives in RAM (0xC000-0xC3FF)
;
; The Z80 has no zero page, so these are just the first bytes of RAM and are
; accessed with plain (nn) addressing.
; ==========================================================================

; --- timing --------------------------------------------------------------
frame_counter   equ 0xC000  ; incremented every frame by wait_frame
rnd             equ 0xC002  ; 16 bit LFSR state (low byte)
rnd_hi          equ 0xC007  ; 16 bit LFSR state (high byte)
field_dirty     equ 0xC003  ; redraw the playfield next frame?

; --- input ---------------------------------------------------------------
key_held        equ 0xC004  ; buttons down this frame
key_prev        equ 0xC005
key_new         equ 0xC006  ; buttons that went down this frame

; --- playfield -----------------------------------------------------------
; 128 bytes, row 0 = top row of the bottle, index = row*8 + column
field           equ 0xC020  ; .. 0xC09F

; --- falling pill --------------------------------------------------------
pill_x          equ 0xC0A0
pill_y          equ 0xC0A1
pill_rot        equ 0xC0A2  ; 0 and 2 horizontal, 1 and 3 vertical
pill_c1         equ 0xC0A3
pill_c2         equ 0xC0A4
pill_active     equ 0xC0A5
pill_hor_vel    equ 0xC0A6
pill_speed_cnt  equ 0xC0A7

; --- next pill -----------------------------------------------------------
next_c1         equ 0xC0A8
next_c2         equ 0xC0A9

; --- game state ----------------------------------------------------------
state           equ 0xC0AA
state_timer     equ 0xC0AB
level           equ 0xC0AC
speed_setting   equ 0xC0AD
viruses_left    equ 0xC0AE
viruses_total   equ 0xC0AF
pills_dropped   equ 0xC0B0
score           equ 0xC0B2  ; 3 bytes packed BCD, most significant first
match_flag      equ 0xC0B5
pending_clear   equ 0xC0B6
flash_timer     equ 0xC0B7
gameover_flag   equ 0xC0B8
menu_sel        equ 0xC0B9
title_level     equ 0xC0BA
title_speed     equ 0xC0BB

; --- audio ---------------------------------------------------------------
sfx             equ 0xC0C0
sfx_timer       equ 0xC0C1
sfx_ptr         equ 0xC0C2  ; 2 bytes

; --- scratch -------------------------------------------------------------
tmp0            equ 0xC0D0
tmp1            equ 0xC0D1
tmp2            equ 0xC0D2
tmp3            equ 0xC0D3
draw_x          equ 0xC0D4
draw_y          equ 0xC0D5

; --- sprite attribute buffer --------------------------------------------
sprite_buf      equ 0xC0E0  ; 32 sprites * 4 bytes

; --- game states ---------------------------------------------------------
GS_TITLE        equ 0
GS_PLAY         equ 1
GS_CLEAR        equ 2
GS_OVER         equ 3
