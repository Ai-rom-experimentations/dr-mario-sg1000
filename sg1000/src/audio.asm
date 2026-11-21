; ==========================================================================
; sg1000/audio.asm - SN76489 sound effects
;
; One PSG channel is enough for a prototype: each effect is a short list of
; (duration, period) steps.  The PSG is write-only, so the "now playing"
; state lives in RAM.
; ==========================================================================

audio_init:
    xor a
    ld (sfx),a
    ld (sfx_timer),a
    jp psg_silence_all

; psg_tone: HL = 10 bit period, C = channel (0-3)
psg_tone:
    ld a,c
    rlca
    rlca
    rlca
    and 0xE0                    ; channel << 5
    or 0x80                     ; latch + frequency register
    ld b,a
    ld a,l
    and 0x0F
    or b
    out (PSG_PORT),a            ; low four bits of the period
    ld a,l
    rrca
    rrca
    rrca
    rrca
    and 0x0F
    ld b,a
    ld a,h
    add a,a
    add a,a
    add a,a
    add a,a
    or b
    and 0x3F
    out (PSG_PORT),a            ; high six bits of the period
    ret

; psg_volume: A = channel (0-3), B = attenuation (0 = loud, 15 = off)
psg_volume:
    rlca
    rlca
    rlca
    and 0xE0
    or 0x90
    or b
    out (PSG_PORT),a
    ret

psg_silence_all:
    ld a,0x9F
    out (PSG_PORT),a
    ld a,0xBF
    out (PSG_PORT),a
    ld a,0xDF
    out (PSG_PORT),a
    ld a,0xFF
    out (PSG_PORT),a
    ret

; --------------------------------------------------------------------------
; play_sfx: A = SFX_*  (0 restarts nothing)
; --------------------------------------------------------------------------
play_sfx:
    ld (sfx),a
    dec a                       ; SFX_NONE is 0
    jr nz,.go
    jp psg_silence_all
.go:
    add a,a                     ; two byte table entries
    ld e,a
    ld d,0
    ld hl,sfx_table
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld (sfx_ptr),de
    jp sfx_step

; --------------------------------------------------------------------------
; audio_update: advance the current effect by one frame
; --------------------------------------------------------------------------
audio_update:
    ld a,(sfx)
    or a
    ret z
    ld a,(sfx_timer)
    dec a
    ld (sfx_timer),a
    ret nz
    jr sfx_step

; sfx_step: play the step at (sfx_ptr)
sfx_step:
    ld de,(sfx_ptr)
    ld a,(de)                   ; duration (0 = end of effect)
    or a
    jr z,.finished
    ld (sfx_timer),a
    inc de
    ld a,(de)                   ; period, low byte
    inc de
    ld l,a
    ld a,(de)                   ; period, high byte
    inc de
    ld h,a
    ld (sfx_ptr),de
    ld a,l
    or h
    jr z,.rest
    push hl
    ld c,0
    call psg_tone
    pop hl
    ld a,0
    ld b,4                      ; fairly loud
    jp psg_volume
.rest:
    ld a,0
    ld b,15
    jp psg_volume
.finished:
    xor a
    ld (sfx),a
    ld (sfx_timer),a
    jp psg_silence_all

; --------------------------------------------------------------------------
; effect tables: duration, period low, period high, ... 0 ends the effect
; --------------------------------------------------------------------------
sfx_table:
    dw sfx_none
    dw sfx_move
    dw sfx_rotate
    dw sfx_land
    dw sfx_clear
    dw sfx_virus
    dw sfx_over

sfx_none:
    db 0

sfx_move:
    db 1,0x7E,0x00
    db 0

sfx_rotate:
    db 2,0x9E,0x00
    db 2,0x6E,0x00
    db 0

sfx_land:
    db 2,0x3E,0x00
    db 3,0x2E,0x00
    db 3,0x1E,0x00
    db 0

sfx_clear:
    db 2,0x5E,0x00
    db 2,0x4E,0x00
    db 2,0x3E,0x00
    db 2,0x2E,0x00
    db 2,0x1E,0x00
    db 0

sfx_virus:
    db 3,0xDE,0x00
    db 3,0xAE,0x00
    db 3,0x8E,0x00
    db 3,0x6E,0x00
    db 0

sfx_over:
    db 8,0x9E,0x00
    db 8,0x8E,0x00
    db 8,0x7E,0x00
    db 8,0x6E,0x00
    db 8,0x5E,0x00
    db 12,0x4E,0x00
    db 0
