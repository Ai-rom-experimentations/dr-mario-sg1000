; ==========================================================================
; sg1000/data.asm - tables and text
; ==========================================================================

; --------------------------------------------------------------------------
; ASCII -> tile number.  Index 0 is ASCII 0x20 (space); anything that is not
; mapped prints as a space.
; --------------------------------------------------------------------------
char_map:
    db T_SPACE  ; ' '
    db T_BANG   ; '!'
    db T_SPACE  ; '"'
    db T_SPACE  ; '#'
    db T_SPACE  ; '$'
    db T_SPACE  ; '%'
    db T_SPACE  ; '&'
    db T_SPACE  ; 'apostrophe'
    db T_SPACE  ; '('
    db T_SPACE  ; ')'
    db T_SPACE  ; '*'
    db T_SPACE  ; '+'
    db T_SPACE  ; ','
    db T_DASH   ; '-'
    db T_SPACE  ; '.'
    db T_SPACE  ; '/'
    db T_DIGIT0+0 ; '0'
    db T_DIGIT0+1 ; '1'
    db T_DIGIT0+2 ; '2'
    db T_DIGIT0+3 ; '3'
    db T_DIGIT0+4 ; '4'
    db T_DIGIT0+5 ; '5'
    db T_DIGIT0+6 ; '6'
    db T_DIGIT0+7 ; '7'
    db T_DIGIT0+8 ; '8'
    db T_DIGIT0+9 ; '9'
    db T_COLON  ; ':'
    db T_SPACE  ; ';'
    db T_SPACE  ; '<'
    db T_SPACE  ; '='
    db T_SPACE  ; '>'
    db T_SPACE  ; '?'
    db T_SPACE      ; '@'
    db T_A+0        ; 'A'
    db T_A+1        ; 'B'
    db T_A+2        ; 'C'
    db T_A+3        ; 'D'
    db T_A+4        ; 'E'
    db T_A+5        ; 'F'
    db T_A+6        ; 'G'
    db T_A+7        ; 'H'
    db T_A+8        ; 'I'
    db T_A+9        ; 'J'
    db T_A+10       ; 'K'
    db T_A+11       ; 'L'
    db T_A+12       ; 'M'
    db T_A+13       ; 'N'
    db T_A+14       ; 'O'
    db T_A+15       ; 'P'
    db T_A+16       ; 'Q'
    db T_A+17       ; 'R'
    db T_A+18       ; 'S'
    db T_A+19       ; 'T'
    db T_A+20       ; 'U'
    db T_A+21       ; 'V'
    db T_A+22       ; 'W'
    db T_A+23       ; 'X'
    db T_A+24       ; 'Y'
    db T_A+25       ; 'Z'
    db T_SPACE      ; '['
    db T_SPACE      ; '\'
    db T_SPACE      ; ']'
    db T_SPACE      ; '^'
    db T_SPACE      ; '_'

; --------------------------------------------------------------------------
; Text
; --------------------------------------------------------------------------
txt_play:       db 'DR. MARIO',0
txt_drmario:    db 'SG-1000 PROTOTYPE',0
txt_level:      db 'LEVEL',0
txt_speed:      db 'SPEED ',0
txt_virus:      db 'VIRUS',0
txt_score:      db 'SCORE',0
txt_next:       db 'NEXT',0
txt_keys:       db '1=B1   2=B2',0
txt_keys2:      db 'ARROWS MOVE',0
txt_start:      db 'PRESS 1 OR 2',0
txt_version:    db 'V0.1',0
txt_clear:      db 'LEVEL CLEAR',0
txt_gameover:   db 'GAME OVER',0
txt_b2cont:     db 'PRESS B1',0
txt_combo:      db 'COMBO',0

speed_names:
    db 'LOW',0
    db 'MED',0
    db 'HI',0

; --------------------------------------------------------------------------
; Frames between automatic drops, indexed by (level - 1) + speed * 4.
; Lower is faster; the NES table in dermario_data_game.asm runs from $45 at
; the slowest to $00 at the fastest.
; --------------------------------------------------------------------------
gravity_table:
    db 30,28,26,24                  ; level 1-4,   speed low
    db 23,22,21,20                  ; level 5-8
    db 19,18,17,16                  ; level 9-12
    db 18,16,15,14                  ; level 1-4,   speed med
    db 13,12,11,10                  ; level 5-8
    db  9, 9, 8, 8                  ; level 9-12
    db  7, 7, 6, 6                  ; level 1-4,   speed hi
    db  5, 5, 5, 4                  ; level 5-8

; --------------------------------------------------------------------------
; Sprite colours for the three pill colours (TMS9918A palette)
; --------------------------------------------------------------------------
pill_colours:
    db C_LYELLOW
    db C_LRED
    db C_LBLUE
