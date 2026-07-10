; ============================================================================
; sim.asm — tool placement, simulation, messages
; ============================================================================

; message ids
MSG_PAUSED   = 0
MSG_NOFUNDS  = 1
MSG_CANT     = 2
MSG_NEEDPOW  = 3
MSG_NEEDRES  = 4
MSG_NEEDJOBS = 5
MSG_BLACKOUT = 6
MSG_FIRE     = 7
MSG_TORNADO  = 8
MSG_GROWING  = 9
MSG_TAXES    = 10
MSG_SAVED    = 11
MSG_MELTDOWN = 12

msg_lo:
    .byte <m_paused,<m_nofunds,<m_cant,<m_needpow,<m_needres
    .byte <m_needjobs,<m_blackout,<m_fire,<m_tornado,<m_growing
    .byte <m_taxes,<m_saved,<m_meltdown
msg_hi:
    .byte >m_paused,>m_nofunds,>m_cant,>m_needpow,>m_needres
    .byte >m_needjobs,>m_blackout,>m_fire,>m_tornado,>m_growing
    .byte >m_taxes,>m_saved,>m_meltdown

m_paused:   .byte "- PAUSED -                  ",$FF
m_nofunds:  .byte "NOT ENOUGH FUNDS            ",$FF
m_cant:     .byte "CAN'T BUILD THERE           ",$FF
m_needpow:  .byte "CITY NEEDS MORE POWER       ",$FF
m_needres:  .byte "MORE HOUSING NEEDED         ",$FF
m_needjobs: .byte "CITIZENS DEMAND JOBS        ",$FF
m_blackout: .byte "BLACKOUTS REPORTED          ",$FF
m_fire:     .byte "FIRE REPORTED!              ",$FF
m_tornado:  .byte "TORNADO WARNING!            ",$FF
m_growing:  .byte "THE CITY IS GROWING         ",$FF
m_taxes:    .byte "TAXES COLLECTED             ",$FF
m_saved:    .byte "CITY SAVED                  ",$FF
m_meltdown: .byte "NUCLEAR MELTDOWN!           ",$FF

show_msg:               ; A = msg id
    sta msg_cur
    lda #240
    sta msg_timer
    lda dirty
    ora #DIRTY_MSG
    sta dirty
    rts

msg_tick:
    lda msg_timer
    beq :+
    dec msg_timer
    bne :+
    lda #$FF
    sta msg_cur
    lda dirty
    ora #DIRTY_MSG
    sta dirty
:   rts

; ---------------------------------------------------------------- tools ----
tool_apply:
    ldx tool_cur
    lda tool_sizes,x
    cmp #3
    bne :+
    jmp tool_apply_big
:
    ; ---- 1x1 tools
    lda cur_x
    sta cell_x
    lda cur_y
    sta cell_y
    jsr get_cell
    sta t5              ; target code
    ldx tool_cur
    beq bulldoze
    ; combos and placement for road/wire/rail/park
    lda t5
    cmp #C_DIRT
    beq @clear_ok
    cmp #C_TREES
    beq @clear_ok
    ; combos
    ldx tool_cur
    cpx #TL_ROAD
    bne :+
    lda t5
    cmp #C_WIRE
    beq @mk_roadwire
    cmp #C_RAIL
    beq @mk_railroad
    jmp err_cant
:   cpx #TL_WIRE
    bne :+
    lda t5
    cmp #C_ROAD
    beq @mk_roadwire
    jmp err_cant
:   cpx #TL_RAIL
    bne :+
    lda t5
    cmp #C_ROAD
    beq @mk_railroad
:   jmp err_cant
@mk_roadwire:
    lda #C_ROADWIRE
    bne @place
@mk_railroad:
    lda #C_RAILROAD
    bne @place
@clear_ok:
    ldx tool_cur
    lda tool_codes,x
@place:
    pha
    jsr tool_pay
    bcs :+
    pla
    jmp err_funds
:   pla
    jsr set_cell
    lda #0
    sta (ptr1),y        ; clear aux
    jsr sfx_place
    jmp queue_cell_neighbors

; ---- bulldozer
bulldoze:
    lda t5
    cmp #C_DIRT
    bne :+
    rts                 ; nothing to do
:   cmp #C_WATER
    beq bd_cant
    cmp #C_FIRE
    beq bd_cant
    cmp #$10
    bcs bd_zone
    ; simple tile
    jsr tool_pay
    bcs :+
    jmp err_funds
:   lda #C_DIRT
    jsr set_cell
    lda #0
    sta (ptr1),y
    jsr sfx_dozer
    jmp queue_cell_neighbors
bd_cant:
    jmp err_cant
bd_zone:
    ; find center from pos, clear 3x3
    jsr tool_pay
    bcs :+
    jmp err_funds
:   lda t5
    and #$0F
    tax
    lda cell_x
    clc
    adc center_dx,x
    sta cell_x
    lda cell_y
    clc
    adc center_dy,x
    sta cell_y
    jsr zone_clear_3x3
    jsr sfx_dozer
    jmp redraw_3x3

; clear 3x3 around center (cell_x/cell_y) to rubble-free dirt
zone_clear_3x3:
    lda cell_x
    pha
    lda cell_y
    pha
    dec cell_x
    dec cell_y
    ldx #0
@loop:
    txa
    pha
    lda #C_DIRT
    jsr set_cell
    lda #0
    sta (ptr1),y
    pla
    tax
    ; advance
    inx
    cpx #9
    beq @done
    txa
    ; col = x%3: if x%3==0 -> newline
    ldy #0
: cmp #3
    bcc :+
    sbc #3
    iny
    bne :-
:   cmp #0
    bne @right
    ; new row: back 2, down 1
    dec cell_x
    dec cell_x
    inc cell_y
    jmp @loop
@right:
    inc cell_x
    jmp @loop
@done:
    pla
    sta cell_y
    pla
    sta cell_x
    rts

; redraw 3x3 around center (cell_x/cell_y)
redraw_3x3:
    lda cell_x
    pha
    lda cell_y
    pha
    dec cell_x
    dec cell_y
    ldx #0
@loop:
    txa
    pha
    jsr queue_cell
    pla
    tax
    inx
    cpx #9
    beq @done
    txa
    ldy #0
: cmp #3
    bcc :+
    sbc #3
    iny
    bne :-
:   cmp #0
    bne @right
    dec cell_x
    dec cell_x
    inc cell_y
    jmp @loop
@right:
    inc cell_x
    jmp @loop
@done:
    pla
    sta cell_y
    pla
    sta cell_x
    rts

; ---- 3x3 placement
tool_apply_big:
    ; bounds: center must be 1..W-2
    lda cur_x
    beq @cant
    cmp #MAPW-1
    bcs @cant
    lda cur_y
    beq @cant
    cmp #MAPH-1
    bcs @cant
    ; check 3x3 clear (dirt/trees/rubble)
    lda cur_x
    sta cell_x
    lda cur_y
    sta cell_y
    dec cell_x
    dec cell_y
    ldx #0
@chk:
    txa
    pha
    jsr get_cell
    cmp #C_DIRT
    beq @ok
    cmp #C_TREES
    beq @ok
    cmp #C_RUBBLE
    beq @ok
    pla
    jmp @cant
@ok:
    pla
    tax
    inx
    cpx #9
    beq @clear
    txa
    ldy #0
: cmp #3
    bcc :+
    sbc #3
    iny
    bne :-
:   cmp #0
    bne @right
    dec cell_x
    dec cell_x
    inc cell_y
    jmp @chk
@right:
    inc cell_x
    jmp @chk
@cant:
    jmp err_cant
@clear:
    jsr tool_pay
    bcs @place
    jmp err_funds
@place:
    ; write 9 cells: base code + pos
    lda cur_x
    sta cell_x
    lda cur_y
    sta cell_y
    dec cell_x
    dec cell_y
    ldx #0
@wr:
    txa
    pha
    ldy tool_cur
    lda tool_codes,y
    sta t6
    pla
    pha
    clc
    adc t6              ; code = base + pos
    jsr set_cell
    lda #0
    sta (ptr1),y
    pla
    tax
    inx
    cpx #9
    beq @drawn
    txa
    ldy #0
: cmp #3
    bcc :+
    sbc #3
    iny
    bne :-
:   cmp #0
    bne @right2
    dec cell_x
    dec cell_x
    inc cell_y
    jmp @wr
@right2:
    inc cell_x
    jmp @wr
@drawn:
    jsr sfx_place
    lda cur_x
    sta cell_x
    lda cur_y
    sta cell_y
    jmp redraw_3x3

; pay for current tool: carry set if paid
tool_pay:
    jsr tool_cost_ptr
    jmp money_sub

err_cant:
    lda #MSG_CANT
    jsr show_msg
    jmp sfx_error
err_funds:
    lda #MSG_NOFUNDS
    jsr show_msg
    jmp sfx_error

; ---------------------------------------------------------------- sim ------
sim_slice:
    jsr msg_tick
    rts

; sfx stubs (filled in later)
sfx_place:
    rts
sfx_dozer:
    rts
sfx_error:
    rts
