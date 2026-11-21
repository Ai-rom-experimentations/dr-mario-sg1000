; ==========================================================================
; Dr. Mario - SG-1000 prototype
;
; A from-scratch SG-1000 port of the NES game, written as a Z80 program for a
; 32KB cartridge (.sg).  The playfield, object encoding, gravity table and
; rotation model follow the NES disassembly in this repository.
;
; Hardware: Z80 @ 3.58MHz, TMS9918A VDP (Graphics I mode), SN76489 PSG,
;           SG-1000 control pads on ports 0xDC/0xDD, 1KB RAM at 0xC000.
;
; Build with:  sjasmplus --raw=build/drmario.sg src/main.asm
; ==========================================================================

    include 'src/hardware.asm'
    include 'src/ram.asm'

    org 0x0000
    di
    jp start

; ==========================================================================
; Boot
; ==========================================================================
start:
    ld sp,0xDFF0
    call clear_ram
    call vdp_init
    call load_graphics
    call audio_init
    call title_init
    ld a,(VDP_CTRL)             ; clear any stale VDP status

main_loop:
    call wait_frame
    call read_controller
    call game_update
    call render
    call audio_update
    jr main_loop

; --------------------------------------------------------------------------
; clear_ram: zero the game variables
; --------------------------------------------------------------------------
clear_ram:
    ld hl,0xC000
    ld bc,0x0100
.clr:
    ld (hl),0
    inc hl
    dec bc
    ld a,b
    or c
    jr nz,.clr
    ret

; --------------------------------------------------------------------------
; wait_frame: spin until the VDP signals vertical blank
; --------------------------------------------------------------------------
wait_frame:
    ld hl,frame_counter
    inc (hl)                    ; (the low byte is enough for pacing)
    in a,(VDP_CTRL)             ; clear a pending interrupt flag
.wait:
    in a,(VDP_CTRL)
    bit 7,a
    jr z,.wait
    ret

; ==========================================================================
; VDP helpers
; ==========================================================================
; vdp_set_addr: HL = VRAM address
vdp_set_addr:
    ld a,l
    out (VDP_CTRL),a
    ld a,h
    or 0x40
    out (VDP_CTRL),a
    ret

; vram_fill: HL = VRAM address, BC = count, A = byte
vram_fill:
    ld e,a
    call vdp_set_addr
    ld a,e
.loop:
    out (VDP_DATA),a
    dec bc
    ld a,b
    or c
    ld a,e
    jr nz,.loop
    ret

; vram_copy: HL = VRAM address, DE = source, BC = count
vram_copy:
    call vdp_set_addr
.loop:
    ld a,(de)
    out (VDP_DATA),a
    inc de
    dec bc
    ld a,b
    or c
    jr nz,.loop
    ret

; --------------------------------------------------------------------------
; vdp_init: registers, clear the VRAM areas we use
; --------------------------------------------------------------------------
vdp_init:
    ld a,VDP_R0_VAL
    out (VDP_CTRL),a
    ld a,0x80
    out (VDP_CTRL),a
    ld a,VDP_R1_VAL
    out (VDP_CTRL),a
    ld a,0x81
    out (VDP_CTRL),a
    ld a,VDP_R2_VAL
    out (VDP_CTRL),a
    ld a,0x82
    out (VDP_CTRL),a
    ld a,VDP_R3_VAL
    out (VDP_CTRL),a
    ld a,0x83
    out (VDP_CTRL),a
    ld a,VDP_R4_VAL
    out (VDP_CTRL),a
    ld a,0x84
    out (VDP_CTRL),a
    ld a,VDP_R5_VAL
    out (VDP_CTRL),a
    ld a,0x85
    out (VDP_CTRL),a
    ld a,VDP_R6_VAL
    out (VDP_CTRL),a
    ld a,0x86
    out (VDP_CTRL),a
    ld a,VDP_R7_VAL
    out (VDP_CTRL),a
    ld a,0x87
    out (VDP_CTRL),a

    ; blank out the parts of VRAM we use
    ld hl,VRAM_NAMETABLE            ; 0x1800-0x1AFF
    ld bc,32*24
    xor a
    call vram_fill
    ld hl,VRAM_SPRITE_ATTR          ; 0x1B00-0x1B7F
    ld bc,0x0080
    xor a
    call vram_fill
    ld hl,VRAM_COLOUR               ; 0x2000-0x201F
    ld bc,0x0020
    xor a
    call vram_fill
    ld hl,VRAM_SPRITE_PAT           ; 0x3800-0x38FF
    ld bc,0x0100
    xor a
    call vram_fill
    ; sprite attribute table: y = 0xD0 hides the sprite and ends the list
    ld hl,VRAM_SPRITE_ATTR
    ld bc,0x0080
    ld a,0xD0
    call vram_fill
    ret

; --------------------------------------------------------------------------
; load_graphics: tiles, colour table and sprite patterns into VRAM
; --------------------------------------------------------------------------
load_graphics:
    ld hl,VRAM_PATTERN
    ld de,tiles_data
    ld bc,TILES_TO_LOAD*8
    call vram_copy

    ld hl,0x2000
    ld de,tiles_colour
    ld bc,10
    call vram_copy

    ld hl,0x3800
    ld de,sprite_patterns
    ld bc,SPRITE_PATTERN_COUNT*8
    call vram_copy
    ret

; ==========================================================================
; Name table / text helpers
; ==========================================================================
; nt_addr: HL = address of (draw_x, draw_y) in the name table.
; Preserves AF, BC, DE (row*32+column never exceeds 0x2FF, so the name table
; base can simply be added to H).
nt_addr:
    ld a,(draw_y)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl                   ; * 32
    ld a,(draw_x)
    add a,l
    ld l,a
    ld a,h
    adc a,0
    add a,VRAM_NAMETABLE>>8
    ld h,a
    ret

; write_tile_advance: A = tile, written at (draw_x,draw_y), then draw_x++
write_tile_advance:
    push af
    call nt_addr
    call vdp_set_addr
    pop af
    out (VDP_DATA),a
    ld a,(draw_x)
    inc a
    ld (draw_x),a
    ret

; pname_addr: B = x, C = y -> HL = name table address. Preserves AF/BC/DE.
pname_addr:
    ld h,0
    ld l,c
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl                   ; y * 32
    ld a,b
    add a,l
    ld l,a
    ld a,h
    adc a,0
    add a,VRAM_NAMETABLE>>8
    ld h,a
    ret

; draw_text: DE = ASCIIZ string at (draw_x,draw_y)
draw_text:
.loop:
    ld a,(de)
    or a
    ret z
    inc de
    sub 0x20                    ; printable ASCII starts at space
    cp 0x40
    jr c,.inrange
    xor a
.inrange:
    ld hl,char_map
    ld c,a
    ld b,0
    add hl,bc
    ld a,(hl)
    call write_tile_advance
    jr .loop

; draw_text_at: DE = string, B = x, C = y
draw_text_at:
    ld a,b
    ld (draw_x),a
    ld a,c
    ld (draw_y),a
    jr draw_text

; print_dec2_at: A = value 0-99, B = x, C = y
print_dec2_at:
    ld (tmp0),a
    ld a,b
    ld (draw_x),a
    ld a,c
    ld (draw_y),a
    ld a,(tmp0)
    jp print_dec2

; print_dec2: A = value 0-99, printed as two digits at the cursor
print_dec2:
    ld b,0
.tens:
    cp 10
    jr c,.done
    sub 10
    inc b
    jr .tens
.done:
    push af
    ld a,b
    call write_tile_advance
    pop af
    call write_tile_advance
    ret

; print_bcd_byte: A = packed BCD byte, printed as two digits
print_bcd_byte:
    push af
    rrca
    rrca
    rrca
    rrca
    and 0x0F
    add a,T_DIGIT0
    call write_tile_advance
    pop af
    and 0x0F
    add a,T_DIGIT0
    call write_tile_advance
    ret

; clear_name_table: fill the name table with blank tiles
clear_name_table:
    ld hl,VRAM_NAMETABLE
    ld bc,32*24
    ld a,T_SPACE
    jp vram_fill

; ==========================================================================
; Controllers
; ==========================================================================
read_controller:
    ld a,(key_held)
    ld (key_prev),a
    in a,(JOY1)
    cpl                         ; active low -> 1 = pressed
    and 0x7F                    ; dpad, B1, B2, START
    ld b,a
    ld a,(key_prev)
    cpl
    and b                       ; buttons that are newly down
    ld (key_new),a
    ld a,b
    ld (key_held),a
    ret

; ==========================================================================
; Pseudo random numbers (8 bit LFSR, max length, never returns 0)
; ==========================================================================
random:
    ; 16-bit Galois LFSR, primitive polynomial x^16+x^15+x^13+x^4+1.
    ; State in rnd_hi:rnd. Returns the high byte (well mixed).
    ld a,(rnd)
    add a,a
    ld (rnd),a
    ld a,(rnd_hi)
    rl a
    ld (rnd_hi),a
    jr nc,.done
    ld a,(rnd)
    xor 0x11                    ; mask 0xA011 low byte
    ld (rnd),a
    ld a,(rnd_hi)
    xor 0xA0                    ; mask 0xA011 high byte
    ld (rnd_hi),a
.done:
    ld a,(rnd_hi)
    ret

; rnd_mod: B = modulus (>0), returns A = 0..B-1. Clobbers B.
rnd_mod:
    call random
.loop:
    cp b
    jr c,.done
    sub b
    jr .loop
.done:
    ret

    include 'src/audio.asm'
    include 'src/game.asm'
    include 'src/data.asm'
    include 'src/tiles.asm'

; ==========================================================================
; .sg cartridge header (the SG-1000 does not need one, but it keeps ROM
; tools and emulators happy) at the end of the 32KB image.
; ==========================================================================
    ds 0x7FF0-$, 0x00           ; pad the ROM out to the header
    org 0x7FF0
    db 'TMR SEGA'               ; 0x7FF0-0x7FF7
    db 0x00,0x00                ; 0x7FF8 reserved
    dw 0x0000                   ; 0x7FFA checksum (unused)
    db 0x00,0x00,0x00           ; 0x7FFC product code
    db 0x4C                    ; 0x7FFF region (SG-1000) + 32KB ROM

    assert $ == 0x8000, "ROM must be exactly 32KB"
