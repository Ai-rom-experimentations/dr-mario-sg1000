; ==========================================================================
; sg1000/game.asm - Dr. Mario rules
;
; The playfield uses the same 8x16, row-major, one-byte-per-cell layout as
; the NES game.  The high nibble is the object type, the low two bits are
; the colour:
;
;   $40/$50  top / bottom half of a vertical pill
;   $60/$70  left / right half of a horizontal pill
;   $80      single half pill (a pill whose partner has been cleared)
;   $B0      just cleared (flashes, then disappears)
;   $D0      virus
;   $FF      empty
;
; Colours are 0 = yellow, 1 = red, 2 = blue, as in the NES game.
; ==========================================================================

; --------------------------------------------------------------------------
; update_playfield_tiles: copy the 128 playfield cells into the name table
; --------------------------------------------------------------------------
update_playfield_tiles:
    ld a,FIELD_Y0
    ld (tmp1),a                 ; screen row
    ld a,16
    ld (tmp2),a                 ; rows left
    ld hl,field
.rowloop:
    push hl
    ld a,(tmp1)
    ld c,a
    ld b,FIELD_X0
    call pname_addr
    call vdp_set_addr
    pop hl
    ld b,8
.cells:
    ld a,(hl)
    call cell_tile
    out (VDP_DATA),a
    inc hl
    dec b
    jr nz,.cells
    ld a,(tmp1)
    inc a
    ld (tmp1),a
    ld a,(tmp2)
    dec a
    ld (tmp2),a
    jr nz,.rowloop
    ret

; --------------------------------------------------------------------------
; cell_tile: A = field byte -> A = tile number to display
; --------------------------------------------------------------------------
cell_tile:
    push bc
    ld b,a
    and MASK_TYPE
    cp O_TOP
    jr z,.top
    cp O_BOTTOM
    jr z,.bottom
    cp O_LEFT
    jr z,.left
    cp O_RIGHT
    jr z,.right
    cp O_SINGLE
    jr z,.single
    cp O_VIRUS
    jr z,.virus
    ld a,T_SPACE
    pop bc
    ret
.top:
    ld a,b
    and MASK_COLOR
    add a,a
    add a,a
    add a,a
    add a,T_PILL+S_TOP
    pop bc
    ret
.bottom:
    ld a,b
    and MASK_COLOR
    add a,a
    add a,a
    add a,a
    add a,T_PILL+S_BOTTOM
    pop bc
    ret
.left:
    ld a,b
    and MASK_COLOR
    add a,a
    add a,a
    add a,a
    add a,T_PILL+S_LEFT
    pop bc
    ret
.right:
    ld a,b
    and MASK_COLOR
    add a,a
    add a,a
    add a,a
    add a,T_PILL+S_RIGHT
    pop bc
    ret
.single:
    ld a,b
    and MASK_COLOR
    add a,a
    add a,a
    add a,a
    add a,T_PILL+S_SINGLE
    pop bc
    ret
.virus:
    ld a,b
    and MASK_COLOR
    add a,a
    add a,a
    add a,a
    add a,T_VIRUS
    pop bc
    ret

; --------------------------------------------------------------------------
; small helpers
; --------------------------------------------------------------------------
; ram_fill: HL = destination, BC = count, A = byte. Clobbers D.
ram_fill:
    ld d,a
.loop:
    ld (hl),d
    inc hl
    dec bc
    ld a,b
    or c
    ld a,d
    jr nz,.loop
    ret

field_clear:
    ld hl,field
    ld bc,128
    ld a,O_EMPTY
    jp ram_fill

; --------------------------------------------------------------------------
; game_update: dispatch on the game state
; --------------------------------------------------------------------------
game_update:
    ld a,(state)
    cp GS_TITLE
    jp z,title_update
    cp GS_PLAY
    jp z,play_update
    jp end_state_update

; --------------------------------------------------------------------------
; render: redraw dirty tiles, then the sprites
; --------------------------------------------------------------------------
render:
    ld a,(field_dirty)
    or a
    jr z,.sprites
    xor a
    ld (field_dirty),a
    call update_playfield_tiles
    call draw_hud
.sprites:
    jp render_sprites

; ==========================================================================
; Title screen
; ==========================================================================
title_init:
    ld a,GS_TITLE
    ld (state),a
    ld a,10
    ld (title_level),a
    ld a,1
    ld (title_speed),a
    xor a
    ld (menu_sel),a
    ld a,(frame_counter)
    or 0x5A                     ; the LFSR must never be seeded with zero
    ld (rnd),a
    ld a,(frame_counter)
    xor 0xA5
    or 0x01
    ld (rnd_hi),a
    jp draw_title_screen

draw_title_screen:
    call clear_name_table
    ld de,txt_play
    ld bc,0x0C02
    call draw_text_at
    ld de,txt_drmario
    ld bc,0x0A03
    call draw_text_at

    ; cursor + LEVEL
    ld a,(menu_sel)
    or a
    ld a,T_SPACE
    jr nz,.lvl
    ld a,T_DASH
.lvl:
    ld b,0x0B
    ld c,0x0A
    call put_tile_xy
    ld de,txt_level
    ld bc,0x0D0A
    call draw_text_at
    ld a,(title_level)
    ld b,0x13
    ld c,0x0A
    call print_dec2_at

    ; cursor + SPEED
    ld a,(menu_sel)
    cp 1
    ld a,T_SPACE
    jr nz,.spd
    ld a,T_DASH
.spd:
    ld b,0x0B
    ld c,0x0C
    call put_tile_xy
    ld de,txt_speed
    ld bc,0x0D0C
    call draw_text_at
    ld a,(title_speed)
    add a,a
    add a,a                     ; four bytes per name
    ld e,a
    ld d,0
    ld hl,speed_names
    add hl,de
    call put_string

    ld de,txt_keys
    ld bc,0x0610
    call draw_text_at
    ld de,txt_start
    ld bc,0x0611
    call draw_text_at
    ld de,txt_version
    ld bc,0x0D16
    call draw_text_at

    ; decorative pills above the menu
    ld a,T_PILL+S_TOP
    ld b,0x0D
    ld c,0x06
    call put_tile_xy
    ld a,T_PILL+1*8+S_BOTTOM
    ld b,0x0D
    ld c,0x07
    call put_tile_xy
    ld a,T_PILL+2*8+S_SINGLE
    ld b,0x0D
    ld c,0x08
    call put_tile_xy
    ret

; put_tile_xy: A = tile, B = x, C = y
put_tile_xy:
    push af                       ; preserve the tile value in A
    ld a,b
    ld (draw_x),a
    ld a,c
    ld (draw_y),a
    pop af                        ; restore the tile value
    jp write_tile_advance

; put_string: HL = zero terminated ASCII string at the cursor
put_string:
.loop:
    ld a,(hl)
    or a
    ret z
    inc hl
    push hl
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
    pop hl
    jr .loop

title_update:
    ld a,(key_new)
    and BTN_UP|BTN_DOWN
    jr z,.vert
    ld a,(menu_sel)
    xor 1
    ld (menu_sel),a
    call draw_title_screen
.vert:
    ld a,(key_new)
    and BTN_LEFT
    jr z,.left
    call title_dec
.left:
    ld a,(key_new)
    and BTN_RIGHT
    jr z,.right
    call title_inc
.right:
    ld a,(key_new)
    and BTN_B1|BTN_B2
    ret z
    ld a,SFX_LAND
    call play_sfx
    jp start_game

title_inc:
    ld a,(menu_sel)
    or a
    jr nz,.speed
    ld a,(title_level)
    cp 20
    ret nc
    inc a
    ld (title_level),a
    jp draw_title_screen
.speed:
    ld a,(title_speed)
    cp 2
    ret nc
    inc a
    ld (title_speed),a
    jp draw_title_screen

title_dec:
    ld a,(menu_sel)
    or a
    jr nz,.speed
    ld a,(title_level)
    cp 2
    ret c
    dec a
    ld (title_level),a
    jp draw_title_screen
.speed:
    ld a,(title_speed)
    or a
    ret z
    dec a
    ld (title_speed),a
    jp draw_title_screen

; ==========================================================================
; Starting a game
; ==========================================================================
start_game:
    ld a,(title_level)
    ld (level),a
    ld a,(title_speed)
    ld (speed_setting),a
    xor a
    ld (score),a
    ld (score+1),a
    ld (score+2),a
    ld (pills_dropped),a
    ld (flash_timer),a
    ld (pending_clear),a
    ld (gameover_flag),a
    ld (match_flag),a
    ld (pill_active),a
    call field_clear
    call clear_name_table
    call draw_bottle
    call draw_side_panel
    call spawn_viruses
    call draw_hud
    call pick_next_pill
    ld a,GS_PLAY
    ld (state),a
    ld a,1
    ld (field_dirty),a
    jp spawn_pill

; --------------------------------------------------------------------------
; spawn_viruses: (level + 1) * 4 viruses in rows 2-9, leaving spawn rows clear
; --------------------------------------------------------------------------
spawn_viruses:
    ld a,(level)
    inc a
    add a,a
    add a,a
    ld (viruses_total),a
    ld (viruses_left),a
    ld b,a
.loop:
    push bc
    call spawn_one_virus
    pop bc
    dec b
    jr nz,.loop
    ret

; spawn_one_virus: drop a virus into a random free cell of rows 2-9.
; Keep rows 0-1 open so the pill can spawn and rotate into the bottle.
spawn_one_virus:
    ld c,250                    ; placement attempts
.try:
    ld b,8
    call rnd_mod                ; row 0..7
    add a,2                     ; actual row 2..9
    ld (tmp1),a
    ld b,8
    call rnd_mod                ; column 0..7
    ld (tmp2),a
    ld a,(tmp1)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl                   ; row * 8
    ld a,(tmp2)
    ld e,a
    ld d,0
    add hl,de
    ld de,field
    add hl,de
    ld a,(hl)
    cp O_EMPTY
    jr z,.free
    dec c
    jr nz,.try
    ; random search failed: fall back to a linear scan for a free cell.
    ; Start at row 2 so fallback viruses never block the pill spawn area.
    ld hl,field+16
    ld b,64                     ; rows 2..9
.scan:
    ld a,(hl)
    cp O_EMPTY
    jr z,.found
    inc hl
    djnz .scan
    ret                         ; field full (should not happen)
.found:
    ; hl -> cell. row = (hl-field)/8, col = (hl-field)%8
    push hl
    ld de,field
    ; compute offset in bc via hl-de
    ld a,l
    sub e
    ld c,a
    ld a,h
    sbc a,d
    ld b,a                      ; bc = offset
    ; row = offset / 8
    ld a,c
    rrca
    rrca
    rrca
    and 0x1F
    ld (tmp1),a
    ld a,c
    and 7
    ld (tmp2),a
    pop hl
    jr .free
.free:
    ; pick a colour; re-roll if it would already complete a line of three
    ld d,6
.colour:
    push de
    push hl
    ld b,3
    call rnd_mod
    ld (tmp0),a
    pop hl
    pop de
    ; two cells to the left?
    ld a,(tmp2)
    cp 2
    jr c,.above
    push de
    push hl
    dec hl
    ld a,(hl)
    and MASK_COLOR
    ld c,a
    dec hl
    ld a,(hl)
    and MASK_COLOR
    cp c
    pop hl
    pop de
    jr nz,.above
    ld a,(tmp0)
    cp c
    jr z,.reroll
.above:
    ; two rows above?
    ld a,(tmp1)
    cp 2
    jr c,.place
    push de
    push hl
    ld bc,-16
    add hl,bc
    ld a,(hl)
    and MASK_COLOR
    ld c,a
    ld bc,8
    add hl,bc
    ld a,(hl)
    and MASK_COLOR
    cp c
    pop hl
    pop de
    jr nz,.place
    ld a,(tmp0)
    cp c
    jr z,.reroll
.place:
    ld a,(tmp0)
    or O_VIRUS
    ld (hl),a
    ret
.reroll:
    dec d
    jr nz,.colour
    ld a,(tmp0)
    or O_VIRUS
    ld (hl),a
    ret

; --------------------------------------------------------------------------
; draw_bottle: name table frame around the playfield
; --------------------------------------------------------------------------
draw_bottle:
    ld a,T_BOTTLE+0
    ld b,BOTTLE_X0
    ld c,BOTTLE_Y0
    call put_tile_xy
    ld d,8
.topl:
    ld a,T_BOTTLE+1
    inc b
    push de
    call put_tile_xy
    pop de
    dec d
    jr nz,.topl
    ld a,T_BOTTLE+2
    inc b
    call put_tile_xy

    ld a,T_BOTTLE+5
    ld b,BOTTLE_X0
    ld c,BOTTLE_Y0+17
    call put_tile_xy
    ld d,8
.botl:
    ld a,T_BOTTLE+6
    inc b
    push de
    call put_tile_xy
    pop de
    dec d
    jr nz,.botl
    ld a,T_BOTTLE+7
    inc b
    call put_tile_xy

    ld d,16
    ld e,BOTTLE_Y0+1
.sides:
    ld a,T_BOTTLE+3
    ld b,BOTTLE_X0
    ld c,e
    push de
    call put_tile_xy
    ld a,T_BOTTLE+4
    ld b,BOTTLE_X0+9
    ld c,e
    call put_tile_xy
    pop de
    inc e
    dec d
    jr nz,.sides
    ret

; --------------------------------------------------------------------------
; side panel labels
; --------------------------------------------------------------------------
draw_side_panel:
    ld de,txt_level
    ld bc,0x1301
    call draw_text_at
    ld de,txt_virus
    ld bc,0x1302
    call draw_text_at
    ld de,txt_score
    ld bc,0x1304
    call draw_text_at
    ld de,txt_next
    ld bc,0x1306
    call draw_text_at
    ret

; --------------------------------------------------------------------------
; draw_hud: level, viruses left, score, next pill
; --------------------------------------------------------------------------
draw_hud:
    ld a,(level)
    ld b,0x1B
    ld c,0x01
    call print_dec2_at
    ld a,(viruses_left)
    ld b,0x1B
    ld c,0x02
    call print_dec2_at
    ld a,(score+2)
    ld b,0x19
    ld c,0x04
    call print_bcd_xy
    ld a,(score+1)
    ld b,0x1B
    ld c,0x04
    call print_bcd_xy
    ld a,(score)
    ld b,0x1D
    ld c,0x04
    call print_bcd_xy
    ; next pill preview: left half then right half
    ld a,(next_c1)
    add a,a
    add a,a
    add a,a
    add a,T_PILL+S_LEFT
    ld b,0x1B
    ld c,0x07
    call put_tile_xy
    ld a,(next_c2)
    add a,a
    add a,a
    add a,a
    add a,T_PILL+S_RIGHT
    ld b,0x1C
    ld c,0x07
    call put_tile_xy
    ret

; print_bcd_xy: A = packed BCD, B = x, C = y
print_bcd_xy:
    ld a,b
    ld (draw_x),a
    ld a,c
    ld (draw_y),a
    jp print_bcd_byte

; ==========================================================================
; End of level / game over
; ==========================================================================
end_state_update:
    ld a,(state)
    cp GS_CLEAR
    jr nz,.over
    ld de,txt_clear
    ld bc,0x0B0A
    call draw_text_at
    ld de,txt_b2cont
    ld bc,0x0C0C
    call draw_text_at
    ld hl,state_timer
    dec (hl)
    ret nz
    jp title_init
.over:
    ld de,txt_gameover
    ld bc,0x0B0A
    call draw_text_at
    ld de,txt_b2cont
    ld bc,0x0C0C
    call draw_text_at
    ld hl,state_timer
    ld a,(hl)
    or a
    jr z,.waitkey
    dec (hl)
    ret
.waitkey:
    ld a,(key_new)
    and BTN_B1|BTN_B2
    ret z
    jp title_init

; ==========================================================================
; The falling pill
; ==========================================================================
; spawn_pill: take the previewed colours and drop a new pill in at the top
spawn_pill:
    ld a,(next_c1)
    ld (pill_c1),a
    ld a,(next_c2)
    ld (pill_c2),a
    call pick_next_pill
    xor a
    ld (pill_y),a
    ld (pill_rot),a
    ld (pill_hor_vel),a
    ld (pill_speed_cnt),a
    ld a,3
    ld (pill_x),a
    ld a,1
    ld (pill_active),a
    call pill_can_move
    jr z,.ok
    ; no room for a new pill: the bottle is full
    xor a
    ld (pill_active),a
    ld a,1
    ld (gameover_flag),a
    ld a,GS_OVER
    ld (state),a
    ld a,80
    ld (state_timer),a
    ld a,SFX_OVER
    jp play_sfx
.ok:
    ld a,1
    ld (field_dirty),a
    ret

; pick_next_pill: roll the colours of the previewed pill
pick_next_pill:
    ld b,3
    call rnd_mod
    ld (next_c1),a
    ld b,3
    call rnd_mod
    ld (next_c2),a
    ret

; --------------------------------------------------------------------------
; pill_cells: B = field index of the first half, C = of the second half
; --------------------------------------------------------------------------
pill_cells:
    ld a,(pill_y)
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl                   ; row * 8
    ld a,(pill_x)
    ld e,a
    ld d,0
    add hl,de
    ld a,l
    ld b,a
    ld a,(pill_rot)
    and 1
    jr nz,.vertical
    ld a,(pill_x)
    cp 7
    jr nc,.off
    ld a,b
    inc a
    ld c,a
    ret
.off:
    ld c,0xFF                   ; outside the bottle: never a legal move
    ret
.vertical:
    ld a,b
    add a,8
    ld c,a
    ret

; --------------------------------------------------------------------------
; pill_can_move: Z set when both halves sit in empty cells
; --------------------------------------------------------------------------
pill_can_move:
    call pill_cells
    push bc
    ld hl,field
    ld e,c
    ld d,0
    add hl,de
    ld a,(hl)
    pop hl                      ; B is now in L
    cp O_EMPTY
    ret nz
    ld e,l
    ld d,0
    ld hl,field
    add hl,de
    ld a,(hl)
    cp O_EMPTY
    ret

; ==========================================================================
; play_update: one frame of the bottle
; ==========================================================================
play_update:
    ; flashing cleared pieces, then they vanish
    ld a,(flash_timer)
    or a
    jr z,.settled
    dec a
    ld (flash_timer),a
    jr nz,.settled
    call apply_clears
.settled:
    ld a,(viruses_left)
    or a
    jr nz,.not_cleared
    ; no viruses left: level complete
    ld a,GS_CLEAR
    ld (state),a
    ld a,150
    ld (state_timer),a
    ld a,SFX_CLEAR
    jp play_sfx
.not_cleared:
    ld a,(pill_active)
    or a
    jr nz,.falling
    ; the board is settling: hand out a new pill once it is quiet
    ld a,(pending_clear)
    or a
    ret nz
    ld a,(flash_timer)
    or a
    ret nz
    jp spawn_pill
.falling:
    call pill_input
    call pill_gravity
    ret

; --------------------------------------------------------------------------
; pill_input: horizontal movement (with acceleration) and rotation
; --------------------------------------------------------------------------
pill_input:
    ld a,(key_held)
    and BTN_LEFT|BTN_RIGHT
    jr z,.no_hold
    ld a,(pill_hor_vel)
    inc a
    cp 5
    jr c,.store
    xor a
.store:
    ld (pill_hor_vel),a
.no_hold:
    ld a,(key_new)
    and BTN_LEFT
    jr z,.nl
    call pill_try_left
.nl:
    ld a,(key_new)
    and BTN_RIGHT
    jr z,.nr
    call pill_try_right
.nr:
    ld a,(key_new)
    and BTN_LEFT|BTN_RIGHT
    jr nz,.rotate               ; a fresh press was handled above
    ld a,(pill_hor_vel)
    or a
    jr nz,.rotate
    ld a,(key_held)
    and BTN_LEFT
    jr z,.nl2
    call pill_try_left
.nl2:
    ld a,(key_held)
    and BTN_RIGHT
    jr z,.rotate
    call pill_try_right
.rotate:
    ld a,(key_new)
    and BTN_B1
    jr z,.b2
    ld a,(pill_rot)
    dec a
    and 3
    ld (pill_rot),a
    call pill_can_move
    jr z,.rotated
    call pill_kick_left
    jr .rotated
.b2:
    ld a,(key_new)
    and BTN_B2
    ret z
    ld a,(pill_rot)
    inc a
    and 3
    ld (pill_rot),a
    call pill_can_move
    jr z,.rotated
    call pill_kick_left
.rotated:
    ld a,SFX_ROTATE
    call play_sfx
    ld a,1
    ld (field_dirty),a
    ret

pill_try_left:
    ld a,(pill_x)
    or a
    ret z
    dec a
    ld (pill_x),a
    call pill_can_move
    jr z,.ok
    ld a,(pill_x)
    inc a
    ld (pill_x),a
    ret
.ok:
    ld a,1
    ld (field_dirty),a
    ld a,SFX_MOVE
    jp play_sfx

pill_try_right:
    ld a,(pill_x)
    cp 7
    ret z
    inc a
    ld (pill_x),a
    call pill_can_move
    jr z,.ok
    ld a,(pill_x)
    dec a
    ld (pill_x),a
    ret
.ok:
    ld a,1
    ld (field_dirty),a
    ld a,SFX_MOVE
    jp play_sfx

; pill_kick_left: the "wall kick", back off a column when a flip is blocked
pill_kick_left:
    ld a,(pill_x)
    or a
    ret z
    dec a
    ld (pill_x),a
    call pill_can_move
    ret z
    ld a,(pill_x)
    inc a
    ld (pill_x),a
    ret

; --------------------------------------------------------------------------
; pill_gravity
; --------------------------------------------------------------------------
pill_gravity:
    ld a,(key_held)
    and BTN_DOWN
    jr nz,.drop                 ; soft drop
    ld a,(pill_speed_cnt)
    inc a
    ld (pill_speed_cnt),a
    ld b,a
    call gravity_delay          ; A = frames per row
    cp b
    ret nc
    jr .drop
.drop:
    xor a
    ld (pill_speed_cnt),a
    ld a,(pill_y)
    inc a
    ld (pill_y),a
    call pill_can_move
    jr z,.moved
    ld a,(pill_y)
    dec a
    ld (pill_y),a
    jp lock_pill
.moved:
    ld a,1
    ld (field_dirty),a
    ret

; gravity_delay: A = frames between automatic drops
gravity_delay:
    ld a,(level)
    dec a
    ld b,a
    ld a,(speed_setting)
    add a,a
    add a,a
    add a,b                     ; level - 1 + speed * 4
    cp 32
    jr c,.ok
    ld a,31
.ok:
    ld e,a
    ld d,0
    ld hl,gravity_table
    add hl,de
    ld a,(hl)
    ret

; --------------------------------------------------------------------------
; lock_pill: cement both halves into the field, then look for matches
; --------------------------------------------------------------------------
lock_pill:
    call pill_cells
    push bc
    ld a,(pill_rot)
    and 1
    jr nz,.vertical
    ld a,(pill_c1)
    or O_LEFT
    jr .have1
.vertical:
    ld a,(pill_c1)
    or O_TOP
.have1:
    ld hl,field
    ld e,b
    ld d,0
    add hl,de
    ld (hl),a
    pop bc
    ld a,(pill_rot)
    and 1
    jr nz,.vertical2
    ld a,(pill_c2)
    or O_RIGHT
    jr .have2
.vertical2:
    ld a,(pill_c2)
    or O_BOTTOM
.have2:
    ld hl,field
    ld e,c
    ld d,0
    add hl,de
    ld (hl),a
    xor a
    ld (pill_active),a
    ld (pill_hor_vel),a
    ld (pill_speed_cnt),a
    ld a,1
    ld (field_dirty),a
    ld hl,pills_dropped
    inc (hl)
    ld a,SFX_LAND
    call play_sfx
    jp find_matches

; ==========================================================================
; Matches
; ==========================================================================
; match_colour: A = field byte -> A = colour + 1 when the cell can take part
; in a match, 0 otherwise.
match_colour:
    push bc
    ld b,a
    and MASK_TYPE
    cp O_VIRUS
    jr z,.yes
    cp O_TOP
    jr z,.yes
    cp O_BOTTOM
    jr z,.yes
    cp O_LEFT
    jr z,.yes
    cp O_RIGHT
    jr z,.yes
    cp O_SINGLE
    jr z,.yes
    xor a
    pop bc
    ret
.yes:
    ld a,b
    and MASK_COLOR
    inc a
    pop bc
    or a
    ret

; --------------------------------------------------------------------------
; find_matches: mark every run of three or more, horizontal then vertical
; --------------------------------------------------------------------------
find_matches:
    xor a
    ld (match_flag),a
    ; --- horizontal windows: 16 rows x 6 start columns
    ld hl,field
    ld c,16
.hrow:
    push hl
    ld b,6
.hwin:
    push hl
    push bc
    ld a,(hl)
    call match_colour
    jr z,.hskip
    ld e,a
    inc hl
    ld a,(hl)
    call match_colour
    cp e
    jr nz,.hskip
    inc hl
    ld a,(hl)
    call match_colour
    cp e
    jr nz,.hskip
    ; HL points at the third cell of the run
    ld d,3
.hmark:
    push de
    push hl
    call mark_cell
    pop hl
    pop de
    dec hl
    dec d
    jr nz,.hmark
.hskip:
    pop bc
    pop hl
    inc hl
    dec b
    jr nz,.hwin
    pop hl
    ld de,8
    add hl,de
    dec c
    jr nz,.hrow

    ; --- vertical windows: 8 columns x 14 start rows
    ld hl,field
    ld b,8
.vcol:
    push hl
    ld c,14
.vwin:
    push hl
    ld a,(hl)
    call match_colour
    jr z,.vskip
    ld (tmp0),a
    push hl
    ld de,8
    add hl,de
    ld a,(hl)
    call match_colour
    ld e,a
    pop hl
    ld a,(tmp0)
    cp e
    jr nz,.vskip
    push hl
    ld de,16
    add hl,de
    ld a,(hl)
    call match_colour
    ld e,a
    pop hl
    ld a,(tmp0)
    cp e
    jr nz,.vskip
    ; HL points at the top cell of a run of three going down
    ld d,3
.vmark:
    push de
    push hl
    call mark_cell
    pop hl
    pop de
    ld bc,8
    add hl,bc
    dec d
    jr nz,.vmark
.vskip:
    pop hl
    ld de,8
    add hl,de
    dec c
    jr nz,.vwin
    pop hl
    inc hl
    dec b
    jr nz,.vcol

    ld a,(match_flag)
    or a
    ret z
    ld a,1
    ld (pending_clear),a
    ld a,10
    ld (flash_timer),a
    ret

; mark_cell: HL = cell, turn it into a flashing "cleared" piece.
; Preserves BC, DE and HL.
mark_cell:
    ld a,(hl)
    and MASK_TYPE
    cp O_CLEARED
    ret z                       ; already marked by the other pass
    ld a,(hl)
    push af
    and MASK_TYPE
    cp O_VIRUS
    jr nz,.notvirus
    push hl
    call destroy_virus
    pop hl
.notvirus:
    pop af
    and MASK_COLOR
    or O_CLEARED
    ld (hl),a
    ld a,1
    ld (match_flag),a
    ret

; destroy_virus: a virus was part of a match
destroy_virus:
    ld hl,viruses_left
    ld a,(hl)
    or a
    jr z,.no
    dec (hl)
.no:
    ; 100 points, packed BCD
    ld hl,score
    ld a,(hl)
    add a,0x00
    daa
    ld (hl),a
    ld a,(score+1)
    adc a,0x01
    daa
    ld (score+1),a
    ld a,(score+2)
    adc a,0x00
    daa
    ld (score+2),a
    ld a,SFX_VIRUS
    jp play_sfx

; --------------------------------------------------------------------------
; apply_clears: remove the flashing pieces, drop what is left, re-check
; --------------------------------------------------------------------------
apply_clears:
    ld hl,field
    ld b,128
.loop:
    ld a,(hl)
    and MASK_TYPE
    cp O_CLEARED
    jr nz,.next
    ld (hl),O_EMPTY
.next:
    inc hl
    dec b
    jr nz,.loop
    xor a
    ld (pending_clear),a
    call break_halves
    call gravity
    call break_halves
    ld a,1
    ld (field_dirty),a
    jp find_matches

; --------------------------------------------------------------------------
; break_halves: a pill half whose partner is gone becomes a single
; (the NES "updateField" routine)
; --------------------------------------------------------------------------
break_halves:
    ld hl,field
    ld b,0
.loop:
    ld a,(hl)
    and MASK_TYPE
    cp O_TOP
    jr z,.top
    cp O_BOTTOM
    jr z,.bottom
    cp O_LEFT
    jr z,.left
    cp O_RIGHT
    jr z,.right
    jr .next
.top:
    ld a,b
    cp 120
    jr nc,.to_single
    push hl
    push bc
    ld de,8
    add hl,de
    ld a,(hl)
    pop bc
    pop hl
    and MASK_TYPE
    cp O_BOTTOM
    jr z,.next
    jr .to_single
.bottom:
    ld a,b
    cp 8
    jr c,.to_single
    push hl
    push bc
    ld de,-8
    add hl,de
    ld a,(hl)
    pop bc
    pop hl
    and MASK_TYPE
    cp O_TOP
    jr z,.next
    jr .to_single
.left:
    ld a,b
    and 7
    cp 7
    jr z,.to_single
    push hl
    push bc
    inc hl
    ld a,(hl)
    pop bc
    pop hl
    and MASK_TYPE
    cp O_RIGHT
    jr z,.next
    jr .to_single
.right:
    ld a,b
    and 7
    jr z,.to_single
    push hl
    push bc
    dec hl
    ld a,(hl)
    pop bc
    pop hl
    and MASK_TYPE
    cp O_LEFT
    jr z,.next
    jr .to_single
.to_single:
    ld a,(hl)
    and MASK_COLOR
    or O_SINGLE
    ld (hl),a
.next:
    inc hl
    inc b
    ld a,b
    cp 128
    jr c,.loop
    ret

; --------------------------------------------------------------------------
; gravity: let loose pieces fall; horizontal pairs fall together
; --------------------------------------------------------------------------
gravity:
    ld b,16                     ; at most sixteen settling passes
.pass:
    push bc
    call gravity_pass
    pop bc
    ld a,(tmp3)
    or a
    ret z
    dec b
    jr nz,.pass
    ret

gravity_pass:
    xor a
    ld (tmp3),a                 ; "something moved" flag
    ld hl,field+119             ; work backwards from the bottom
    ld b,120
.loop:
    ld a,(hl)
    and MASK_TYPE
    cp O_EMPTY
    jr z,.next
    cp O_LEFT
    jr z,.pair
    jr .single
.pair:
    ld a,b
    and 7
    cp 7
    jr z,.single
    ld a,(hl)
    ld d,a
    inc hl
    ld a,(hl)
    ld e,a                      ; DE = the two halves
    dec hl
    and MASK_TYPE
    cp O_RIGHT
    jr nz,.single
    call cell_below_empty       ; first half
    jr nz,.next
    push hl
    ld bc,9
    add hl,bc
    call cell_below_empty       ; second half
    pop hl
    jr nz,.next
    ; move the pair down
    ld (hl),O_EMPTY
    inc hl
    ld (hl),O_EMPTY
    dec hl
    push hl
    ld bc,8
    add hl,bc
    ld (hl),d
    inc hl
    ld (hl),e
    pop hl
    ld a,1
    ld (tmp3),a
    jr .next
.single:
    ld a,(hl)
    ld d,a
    call cell_below_empty
    jr nz,.next
    ld (hl),O_EMPTY
    push hl
    ld bc,8
    add hl,bc
    ld (hl),d
    pop hl
    ld a,1
    ld (tmp3),a
.next:
    dec hl
    dec b
    jr nz,.loop
    ret

; cell_below_empty: HL = cell; Z set when the cell below is empty,
; non-zero when it is not.  Preserves HL, BC, DE.
cell_below_empty:
    push hl
    push bc
    push de
    ld bc,8
    add hl,bc
    ld a,(hl)
    pop de
    pop bc
    pop hl
    cp O_EMPTY                         ; Z set when empty
    ret

; ==========================================================================
; Sprites
; ==========================================================================
; render_sprites: build the sprite attribute table in RAM, then blast it
; ==========================================================================
render_sprites:
    ld a,(state)
    cp GS_TITLE
    jp z,hide_sprites
    ld hl,sprite_buf

    ; --- Dr. Mario: three 16x8 bands, bobbing gently
    ld a,(frame_counter)
    and 0x08
    rrca
    rrca
    rrca                        ; 0 or 1
    ld e,a
    ld a,(pill_y)
    add a,a
    add a,a
    add a,a                     ; row * 8
    add a,FIELD_Y0*8
    sub 16
    add a,e
    ld c,a                      ; y
    ld b,144                    ; x
    ld d,C_WHITE
    ld e,0                      ; first pattern
    ld a,6                      ; six 8x8 sprites
.bands:
    push af
    push bc
    push de
    ld a,e
    call put_sprite
    pop de
    push de
    ld a,b
    add a,8
    ld b,a
    ld a,e
    inc a
    call put_sprite
    pop de
    pop bc
    inc e
    inc e
    ld a,c
    add a,8
    ld c,a
    pop af
    dec a
    jr nz,.bands

    ; --- the falling pill
    ld a,(pill_active)
    or a
    jr z,.tail
    ld a,(pill_y)
    add a,a
    add a,a
    add a,a
    add a,FIELD_Y0*8
    ld c,a
    ld a,(pill_x)
    add a,a
    add a,a
    add a,a
    add a,FIELD_X0*8
    ld b,a
    ld a,(pill_c1)
    call colour_of
    ld d,a
    ld a,(pill_rot)
    and 1
    jr nz,.vpill
    ; horizontal: left half then right half
    push bc
    push de
    ld a,8
    call put_sprite
    pop de
    pop bc
    push bc
    push de
    ld a,b
    add a,8
    ld b,a
    ld a,(pill_c2)
    call colour_of
    ld d,a
    ld a,9
    call put_sprite
    pop de
    pop bc
    jr .tail
.vpill:
    push bc
    push de
    ld a,6
    call put_sprite
    pop de
    pop bc
    push bc
    push de
    ld a,c
    add a,8
    ld c,a
    ld a,(pill_c2)
    call colour_of
    ld d,a
    ld a,7
    call put_sprite
    pop de
    pop bc
.tail:
    ld a,0xD0                   ; terminate the sprite list
    ld (hl),a
    inc hl
    ld (hl),0
    inc hl
    ld (hl),0
    inc hl
    ld (hl),0
    ld hl,VRAM_SPRITE_ATTR
    ld de,sprite_buf
    ld bc,32*4
    jp vram_copy

hide_sprites:
    ld hl,VRAM_SPRITE_ATTR
    ld bc,32*4
    ld a,0xD0
    jp vram_fill

; put_sprite: HL = buffer position, B = x, C = y, D = colour, E = pattern
put_sprite:
    ld a,c
    dec a                       ; the TMS9918 renders one line lower
    ld (hl),a
    inc hl
    ld (hl),b
    inc hl
    ld (hl),e
    inc hl
    ld (hl),d
    inc hl
    ret

; colour_of: A = pill colour index -> A = sprite colour
colour_of:
    ld e,a
    ld d,0
    ld hl,pill_colours
    add hl,de
    ld a,(hl)
    ret
