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
MSG_STADIUM  = 13
MSG_SEAPORT  = 14
MSG_AIRPORT  = 15
MSG_CRIME    = 16

msg_lo:
    .byte <m_paused,<m_nofunds,<m_cant,<m_needpow,<m_needres
    .byte <m_needjobs,<m_blackout,<m_fire,<m_tornado,<m_growing
    .byte <m_taxes,<m_saved,<m_meltdown
    .byte <m_stadium,<m_seaport,<m_airport,<m_crime
msg_hi:
    .byte >m_paused,>m_nofunds,>m_cant,>m_needpow,>m_needres
    .byte >m_needjobs,>m_blackout,>m_fire,>m_tornado,>m_growing
    .byte >m_taxes,>m_saved,>m_meltdown
    .byte >m_stadium,>m_seaport,>m_airport,>m_crime

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
m_stadium:  .byte "RESIDENTS WANT A STADIUM    ",$FF
m_seaport:  .byte "INDUSTRY WANTS A SEAPORT    ",$FF
m_airport:  .byte "COMMERCE WANTS AN AIRPORT   ",$FF
m_crime:    .byte "CRIME IS RISING             ",$FF

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
    cmp #C_WATER
    beq @mk_wire_w
    jmp err_cant
:   cpx #TL_RAIL
    bne :+
    lda t5
    cmp #C_ROAD
    beq @mk_railroad
    cmp #C_WATER
    beq @mk_rail_w
:   jmp err_cant
@mk_roadwire:
    lda #C_ROADWIRE
    bne @place
@mk_railroad:
    lda #C_RAILROAD
    bne @place
@mk_wire_w:
    lda #C_WIRE_W
    bne @place
@mk_rail_w:
    lda #C_RAIL_W
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
    ; simple tile: water crossings revert to water, land to dirt
    jsr tool_pay
    bcs :+
    jmp err_funds
:   lda t5
    cmp #C_WIRE_W
    beq @to_water
    cmp #C_RAIL_W
    beq @to_water
    lda #C_DIRT
    bne @clr
@to_water:
    lda #C_WATER
@clr:
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
; The simulation runs as repeated passes over the whole map (phase 0), each
; followed by a power flood-fill (phase 1). Power uses two bits in map1:
; bit6 = being computed this pass, bit7 = displayed/effective (previous pass).
; Every scan step migrates bit6 -> bit7 and clears bit6 for the next fill.

SIM_STEPS_SLOW = 24
SIM_STEPS_MED  = 48
SIM_STEPS_FAST = 96

sim_slice:
    jsr msg_tick
    lda #0
    sta grew_flag
    ldx speed
    beq @done           ; paused
    lda speed_steps,x
    sta t7
@loop:
    lda grew_flag
    bne @done           ; a zone redraw happened: stop early this frame
    lda sim_phase
    bne @power
    jsr scan_step
    jmp @next
@power:
    jsr power_step
@next:
    dec t7
    bne @loop
@done:
    rts

speed_steps: .byte 0, SIM_STEPS_SLOW, SIM_STEPS_MED, SIM_STEPS_FAST

scan_init:
    lda #<map0
    sta sim_p0
    lda #>map0
    sta sim_p0+1
    lda #<map1
    sta sim_p1
    lda #>map1
    sta sim_p1+1
    lda #0
    sta sim_cx
    sta sim_cy
    ; clear accumulators
    sta scan_r
    sta scan_r+1
    sta scan_c
    sta scan_c+1
    sta scan_i
    sta scan_i+1
    sta scan_rz
    sta scan_cz
    sta scan_iz
    sta scan_pow
    sta scan_unp
    sta scan_plant
    sta scan_road
    sta scan_road+1
    sta scan_rail
    sta scan_rail+1
    sta scan_fire
    sta scan_firestn
    sta scan_police
    sta scan_flags
    sta scan_boltn
    sta scan_nuke_f
    rts

; ---- one map cell
scan_step:
    ldy #0
    ; power bit migration: bit7' = bit6, bit6' = 0
    lda (sim_p1),y
    and #$40
    asl a               ; -> bit7
    sta t0
    lda (sim_p1),y
    and #$3F
    ora t0
    sta (sim_p1),y
    sta t6              ; current aux (bit7 = effective power)
    lda (sim_p0),y
    beq scan_next       ; dirt
    cmp #C_FIRE
    bne :+
    jmp scan_fire_cell
:   cmp #C_ROAD
    beq sc_road
    cmp #C_ROADWIRE
    beq sc_road
    cmp #C_RAILROAD
    beq sc_railroad
    cmp #C_RAIL
    beq sc_rail
    cmp #C_RAIL_W
    beq sc_rail
    cmp #$10
    bcs sc_zone_cell
    ; trees/water/rubble/park/wire: nothing
scan_next_j:
    jmp scan_next
sc_road:
    inc scan_road
    bne scan_next_j
    inc scan_road+1
    jmp scan_next
sc_railroad:
    inc scan_road
    bne :+
    inc scan_road+1
:   ; fall through: also a rail
sc_rail:
    inc scan_rail
    bne scan_next_j
    inc scan_rail+1
    jmp scan_next
sc_zone_cell:
    sta t5              ; code
    and #$0F
    cmp #4
    bne scan_next_j     ; only centers processed
    jmp scan_center

scan_next:
    ; advance pointers and coords
    inc sim_p0
    bne :+
    inc sim_p0+1
:   inc sim_p1
    bne :+
    inc sim_p1+1
:   inc sim_cx
    lda sim_cx
    cmp #MAPW
    bne @out
    lda #0
    sta sim_cx
    inc sim_cy
    lda sim_cy
    cmp #MAPH
    bne @out
    jsr pass_end
@out:
    rts

; ---- burning cell
scan_fire_cell:
    inc scan_fire
    ; age in aux bits 0-2
    lda t6
    and #$07
    clc
    adc #1
    sta t0
    ; burnout threshold: 4, or 3 with any fire station
    lda #4
    ldx firestn_n
    beq :+
    lda #3
:   cmp t0
    bcs @keep_burning
    ; burn out -> rubble
    lda #C_RUBBLE
    sta (sim_p0),y
    lda #0
    sta (sim_p1),y
    jsr scan_set_cellxy
    jsr queue_cell
    jmp scan_next
@keep_burning:
    lda t6
    and #$F8
    ora t0
    sta (sim_p1),y
    ; spread chance
    jsr rand_step
    ldx firestn_n
    beq :+
    cmp #96
    bcc @try_spread
    jmp scan_next
:   cmp #144
    bcc @try_spread
    jmp scan_next
@try_spread:
    jsr scan_set_cellxy
    jsr rand_step
    and #3
    tax
    lda cell_x
    clc
    adc walk4_dx,x
    cmp #MAPW
    bcs @no
    sta cell_x
    lda cell_y
    clc
    adc walk4_dy,x
    cmp #MAPH
    bcs @no
    sta cell_y
    jsr fire_ignite
@no:
    jmp scan_next

walk4_dx: .byte 0, 1, 0, <-1
walk4_dy: .byte <-1, 0, 1, 0

scan_set_cellxy:
    lda sim_cx
    sta cell_x
    lda sim_cy
    sta cell_y
    rts

; ignite cell at (cell_x, cell_y) if flammable
fire_ignite:
    jsr get_cell
    cmp #C_TREES
    beq @burn
    cmp #C_PARK
    beq @burn
    cmp #$10
    bcc @no
    ; zone cell: destroy the whole zone to rubble first
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
    jsr rubble_3x3
    jsr redraw_3x3
@burn:
    lda #C_FIRE
    jsr set_cell
    lda #0
    sta (ptr1),y
    jsr queue_cell
    lda scan_fire
    bne @no             ; only message on fresh outbreak
    jsr sfx_alarm
    lda #MSG_FIRE
    jsr show_msg
@no:
    rts

; 3x3 around center -> rubble
rubble_3x3:
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
    lda #C_RUBBLE
    jsr set_cell
    lda #0
    sta (ptr1),y
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

; ---- zone / building center (code in t5, aux in t6)
scan_center:
    lda t5
    lsr a
    lsr a
    lsr a
    lsr a
    sec
    sbc #1              ; type 0..9
    sta t4
    cmp #3
    bcc @rci
    cmp #5
    bcc @service        ; police(3) / firestn(4)
    cmp #7
    bcc @plant          ; coal(5) / nuke(6)
    ; stadium(7) / seaport(8) / airport(9)
    lda t6
    bmi :+
    jsr bolt_collect
    jmp scan_next
:   lda t4
    sec
    sbc #7
    tax
    lda scan_flags
    ora flag_bit,x
    sta scan_flags
    jmp scan_next
@service:
    lda t6
    bmi :+
    jsr bolt_collect
    jmp scan_next
:   lda t4
    cmp #3
    bne :+
    inc scan_police
    jmp scan_next
:   inc scan_firestn
    jmp scan_next
@plant:
    inc scan_plant
    lda t4
    cmp #6              ; nuke?
    bne :+
    lda #1
    sta scan_nuke_f
    lda sim_cx
    sta scan_nuke_x
    lda sim_cy
    sta scan_nuke_y
:   ; seed the power flood fill with this cell's index
    lda sim_cy
    and #3
    tax
    lda row_lo_tab,x
    ora sim_cx
    sta t0              ; idx lo
    lda sim_cy
    lsr a
    lsr a
    sta t1              ; idx hi
    jsr pw_push
    jmp scan_next
@rci:
    ; accumulate population + zone count
    lda t6
    and #$03
    sta t3              ; level
    ldx t4
    beq @r
    dex
    beq @c
    inc scan_iz
    lda scan_i
    clc
    adc t3
    sta scan_i
    bcc @powchk
    inc scan_i+1
    jmp @powchk
@r: inc scan_rz
    lda scan_r
    clc
    adc t3
    sta scan_r
    bcc @powchk
    inc scan_r+1
    jmp @powchk
@c: inc scan_cz
    lda scan_c
    clc
    adc t3
    sta scan_c
    bcc @powchk
    inc scan_c+1
@powchk:
    lda t6
    bmi @powered
    ; unpowered
    inc scan_unp
    jsr bolt_collect
    lda t3
    beq @zdone
    jsr rand_step
    cmp #24
    bcs @zdone
    jsr zone_decline
@zdone:
    jmp scan_next
@powered:
    inc scan_pow
    ; road access check -> t2 (0/1)
    jsr scan_set_cellxy
    jsr road_access
    lda t2
    bne @has_road
    ; no road: very slow decline
    lda t3
    beq @zdone
    jsr rand_step
    cmp #6
    bcs @zdone
    jsr zone_decline
    jmp scan_next
@has_road:
    ; demand-driven growth/decline
    ldx t4
    lda demand_r,x      ; demand_r/c/i are consecutive
    sta t0
    bmi @neg
    ; positive demand: growth roll
    lda t3
    cmp #3
    bcs @zdone          ; maxed
    ; level 2->3 requires the type's big amenity
    cmp #2
    bne @roll
    ldx t4
    lda has_flags
    and grow_gate,x     ; R needs stadium, C airport, I seaport
    beq @zdone
@roll:
    jsr rand_step
    and #$7F
    cmp t0
    bcs @zdone
    jsr zone_grow
    jmp scan_next
@neg:
    ; negative demand: decline roll (slower)
    lda t3
    beq @zdone
    lda #0
    sec
    sbc t0              ; -demand
    lsr a
    sta t1
    jsr rand_step
    and #$7F
    cmp t1
    bcs @zdone
    jsr zone_decline
    jmp scan_next

flag_bit: .byte 1,2,4
grow_gate: .byte 1,4,2

; collect a bolt indicator position (cell = sim scan position)
bolt_collect:
    ldx scan_boltn
    cpx #8
    bcs :+
    lda sim_cx
    sta bolt_tx,x
    lda sim_cy
    sta bolt_ty,x
    inc scan_boltn
:   rts

zone_grow:
    ldy #0
    lda (sim_p1),y
    and #$FC
    sta t0
    lda t3
    clc
    adc #1
    ora t0
    sta (sim_p1),y
    jmp zone_redraw
zone_decline:
    ldy #0
    lda (sim_p1),y
    and #$FC
    sta t0
    lda t3
    sec
    sbc #1
    ora t0
    sta (sim_p1),y
zone_redraw:
    jsr scan_set_cellxy
    jsr redraw_3x3
    lda #1
    sta grew_flag
    lda dirty
    ora #DIRTY_POP
    sta dirty
    ldy #0
    rts

; road access: any road within the 12 cells ringing the 3x3 zone
; (cell_x/cell_y = center). Result in t2.
road_access:
    lda #0
    sta t2
    ldx #0
@loop:
    lda cell_x
    clc
    adc ring_dx,x
    cmp #MAPW
    bcs @skip
    sta t0
    lda cell_y
    clc
    adc ring_dy,x
    cmp #MAPH
    bcs @skip
    sta t1
    ; read map0[t1*64+t0]
    lda t1
    and #3
    tay
    lda row_lo_tab,y
    ora t0
    sta ptr2
    lda t1
    lsr a
    lsr a
    clc
    adc #>map0
    sta ptr2+1
    ldy #0
    lda (ptr2),y
    jsr is_roadish
    bcc @skip
    lda #1
    sta t2
    rts
@skip:
    inx
    cpx #12
    bne @loop
    rts

ring_dx: .byte <-2,<-2,<-2, 2,2,2, <-1,0,1, <-1,0,1
ring_dy: .byte <-1,0,1, <-1,0,1, <-2,<-2,<-2, 2,2,2

; ---------------------------------------------------------------- power ----
; queue: pw_queue = 256 lo bytes, pw_queue+256 = 256 hi bytes
pw_push:                ; t0 = idx lo, t1 = idx hi
    ldx pw_tail
    inx
    cpx pw_head
    bne :+
    lda #1
    sta pw_drop
    rts
:   ldx pw_tail
    lda t0
    sta pw_queue,x
    lda t1
    sta pw_queue+256,x
    inc pw_tail
    rts

power_step:
    lda pw_head
    cmp pw_tail
    bne @pop
    ; drained: back to scanning
    lda #0
    sta sim_phase
    rts
@pop:
    ldx pw_head
    lda pw_queue,x
    sta t0              ; idx lo
    lda pw_queue+256,x
    sta t1              ; idx hi
    inc pw_head
    ; aux ptr = map1 + idx
    lda t0
    sta ptr1
    lda t1
    clc
    adc #>map1
    sta ptr1+1
    ldy #0
    lda (ptr1),y
    and #$40
    bne @done           ; already energized this pass
    lda (ptr1),y
    ora #$40
    sta (ptr1),y
    ; coords: cx = lo & 63, cy = (hi<<2) | (lo>>6)
    lda t0
    and #$3F
    sta t2              ; cx
    lda t0
    rol a
    rol a
    rol a
    and #$03
    sta t3
    lda t1
    asl a
    asl a
    ora t3
    sta t3              ; cy
    ; neighbors
    ldx #0
@ndir:
    stx t4
    lda t2
    clc
    adc walk4_dx,x
    cmp #MAPW
    bcs @next
    sta cell_x
    lda t3
    clc
    adc walk4_dy,x
    cmp #MAPH
    bcs @next
    sta cell_y
    jsr cell_ptr
    lda (ptr0),y
    jsr is_conductive
    bcc @next
    lda (ptr1),y
    and #$40
    bne @next
    ; push neighbor
    lda ptr0
    sta t0
    lda ptr0+1
    sec
    sbc #>map0
    sta t1
    jsr pw_push
@next:
    ldx t4
    inx
    cpx #4
    bne @ndir
@done:
    rts

is_conductive:
    cmp #$10
    bcs @yes
    cmp #C_WIRE
    beq @yes
    cmp #C_ROADWIRE
    beq @yes
    cmp #C_RAILROAD
    beq @yes
    cmp #C_WIRE_W
    beq @yes
    clc
    rts
@yes:
    sec
    rts

; ---------------------------------------------------------------- pass end -
pass_end:
    ; latch accumulators
    lda scan_r
    sta res_pop
    lda scan_r+1
    sta res_pop+1
    lda scan_c
    sta com_pop
    lda scan_c+1
    sta com_pop+1
    lda scan_i
    sta ind_pop
    lda scan_i+1
    sta ind_pop+1
    lda scan_rz
    sta res_zones
    lda scan_cz
    sta com_zones
    lda scan_iz
    sta ind_zones
    lda scan_road
    sta roads_n
    lda scan_road+1
    sta roads_n+1
    lda scan_rail
    sta rails_n
    lda scan_rail+1
    sta rails_n+1
    lda scan_police
    sta police_n
    lda scan_firestn
    sta firestn_n
    lda scan_flags
    sta has_flags
    lda scan_plant
    sta plant_n
    lda scan_pow
    sta powered_n
    lda scan_unp
    sta unpowered_n
    lda scan_fire
    sta fire_n
    lda scan_nuke_f
    sta nuke_present
    lda scan_nuke_x
    sta nuke_x
    lda scan_nuke_y
    sta nuke_y
    ; bolts
    lda scan_boltn
    sta bolt_n
    ldx #7
: lda bolt_tx,x
    sta bolt_x,x
    lda bolt_ty,x
    sta bolt_y,x
    dex
    bpl :-
    lda #0
    sta pw_drop
    lda dirty
    ora #DIRTY_POP
    sta dirty
    ; month every 2 passes
    inc sim_cycles
    lda sim_cycles
    cmp #2
    bcc :+
    lda #0
    sta sim_cycles
    jsr month_tick
:   jsr scan_init
    lda #1
    sta sim_phase       ; drain power queue before next scan
    rts

; ---------------------------------------------------------------- month ----
month_tick:
    jsr calc_demand
    jsr disaster_roll
    jsr pick_message
    ; advance date
    inc month
    lda month
    cmp #12
    bcc @nd
    lda #0
    sta month
    jsr inc_year
    jsr year_tick
@nd:
    lda dirty
    ora #(DIRTY_DATE|DIRTY_RCI)
    sta dirty
    rts

; clamp helpers: A = 8-bit from 16-bit at ptr-less pairs
clamp8:                 ; t0/t1 (lo/hi) -> A = min(value,255)
    lda t1
    beq :+
    lda #$FF
    rts
:   lda t0
    rts

; --- small signed 16-bit accumulator in t0/t1 for demand math -----------
acc_set:                ; acc = signed A
    sta t0
    ora #0
    bmi :+
    lda #0
    sta t1
    rts
:   lda #$FF
    sta t1
    rts

acc_add:                ; acc += signed A
    tax
    clc
    adc t0
    sta t0
    txa
    bmi :+
    lda t1
    adc #0
    sta t1
    rts
:   lda t1
    adc #$FF
    sta t1
    rts

acc_sub:                ; acc -= signed A
    eor #$FF
    clc
    adc #1
    jmp acc_add

acc_clamp100:           ; A = acc clamped to -100..100 (signed)
    lda t1
    beq @hi0
    cmp #$FF
    beq @hiff
    bmi @min
    lda #100
    rts
@min:
    lda #<-100
    rts
@hi0:
    lda t0
    bmi @max
    cmp #101
    bcc @ok
@max:
    lda #100
@ok:
    rts
@hiff:
    lda t0
    bpl @min
    cmp #<-100
    bcs @ok2
    lda #<-100
@ok2:
    rts

; A = min(16-bit value at (lo=A, hi=X), 120)
clamp120:
    cpx #0
    bne :+
    cmp #120
    bcc :++
:   lda #120
:   rts

calc_demand:
    lda res_pop
    ldx res_pop+1
    jsr clamp120
    sta t2              ; rp
    lda com_pop
    ldx com_pop+1
    jsr clamp120
    sta t3              ; cp
    lda ind_pop
    ldx ind_pop+1
    jsr clamp120
    sta t4              ; ip
    ; taxpen = tax_rate - 7 (signed)
    lda tax_rate
    sec
    sbc #7
    sta t5
    ; ---- demand_r = 24 + cp/2 + ip/2 - rp/2 - taxpen*3 + police_n
    lda #24
    jsr acc_set
    lda t3
    lsr a
    jsr acc_add
    lda t4
    lsr a
    jsr acc_add
    lda t2
    lsr a
    jsr acc_sub
    lda t5
    jsr acc_sub
    lda t5
    jsr acc_sub
    lda t5
    jsr acc_sub
    lda police_n
    cmp #8
    bcc :+
    lda #8
:   jsr acc_add
    jsr acc_clamp100
    sta demand_r
    ; ---- demand_c = 4 + rp/4 - cp - taxpen*2
    lda #4
    jsr acc_set
    lda t2
    lsr a
    lsr a
    jsr acc_add
    lda t3
    jsr acc_sub
    lda t5
    jsr acc_sub
    lda t5
    jsr acc_sub
    jsr acc_clamp100
    sta demand_c
    ; ---- demand_i = 12 + rp/4 - ip - taxpen*2
    lda #12
    jsr acc_set
    lda t2
    lsr a
    lsr a
    jsr acc_add
    lda t4
    jsr acc_sub
    lda t5
    jsr acc_sub
    lda t5
    jsr acc_sub
    jsr acc_clamp100
    sta demand_i
    rts

pick_message:
    ; critical conditions first
    lda plant_n
    bne :+
    lda res_zones
    ora com_zones
    ora ind_zones
    beq :+
    lda #MSG_NEEDPOW
    jmp show_msg
:   lda unpowered_n
    cmp #3
    bcc :+
    jsr rand_step
    cmp #128
    bcs :+
    lda #MSG_BLACKOUT
    jmp show_msg
:   lda fire_n
    beq :+
    lda #MSG_FIRE
    jmp show_msg
:   ; amenity requests
    lda has_flags
    and #1
    bne :+
    lda res_pop+1
    bne @want_stad
    lda res_pop
    cmp #20
    bcc :+
@want_stad:
    jsr rand_step
    cmp #64
    bcs :+
    lda #MSG_STADIUM
    jmp show_msg
:   lda has_flags
    and #2
    bne :+
    lda ind_pop+1
    bne @want_port
    lda ind_pop
    cmp #12
    bcc :+
@want_port:
    jsr rand_step
    cmp #64
    bcs :+
    lda #MSG_SEAPORT
    jmp show_msg
:   lda has_flags
    and #4
    bne :+
    lda com_pop+1
    bne @want_air
    lda com_pop
    cmp #10
    bcc :+
@want_air:
    jsr rand_step
    cmp #64
    bcs :+
    lda #MSG_AIRPORT
    jmp show_msg
:   ; demand pressure
    lda demand_r
    bmi :+
    cmp #48
    bcc :+
    jsr rand_step
    cmp #64
    bcs :+
    lda #MSG_NEEDRES
    jmp show_msg
:   lda demand_c
    bmi @ci
    cmp #48
    bcs @jobs
@ci:
    lda demand_i
    bmi :+
    cmp #48
    bcc :+
@jobs:
    jsr rand_step
    cmp #64
    bcs :+
    lda #MSG_NEEDJOBS
    jmp show_msg
:   ; crime: many zones, few police
    lda police_n
    asl a
    asl a
    asl a
    clc
    adc #12
    sta t0
    lda res_zones
    clc
    adc com_zones
    clc
    adc ind_zones
    cmp t0
    bcc :+
    jsr rand_step
    cmp #48
    bcs :+
    lda #MSG_CRIME
    jmp show_msg
:   rts

inc_year:               ; BCD year in year (hi) / year+1 (lo)
    lda year+1
    clc
    adc #1
    sta year+1
    and #$0F
    cmp #$0A
    bcc @ok
    lda year+1
    clc
    adc #$06
    sta year+1
    cmp #$A0
    bcc @ok
    lda year+1
    sec
    sbc #$A0
    sta year+1
    lda year
    clc
    adc #1
    sta year
    ; (no century adjust needed before year 9999)
@ok:
    rts

; ------------------------------------------------------------- disasters ---
disaster_roll:
    lda disaster_on
    beq @no
    jsr rand_step
    cmp #16             ; ~1 in 16 months
    bcs @no
    jsr rand_step
    cmp #24
    bcc @meltdown
    cmp #112
    bcc @tornado
    ; random fire at a random cell
    jsr rand_step
    and #$3F
    sta cell_x
    jsr rand_step
    ldy #MAPH
    jsr mod_y
    sta cell_y
    jsr fire_ignite
@no:
    rts
@tornado:
    lda torn_active
    bne @no
    lda #1
    sta torn_active
    jsr rand_step
    and #$3F
    sta torn_x
    jsr rand_step
    ldy #MAPH
    jsr mod_y
    sta torn_y
    lda #56             ; ~15 seconds
    sta torn_timer
    jsr sfx_alarm
    lda #MSG_TORNADO
    jmp show_msg
@meltdown:
    lda nuke_present
    beq @tornado        ; no nuke: tornado instead
    lda nuke_x
    sta cell_x
    lda nuke_y
    sta cell_y
    jsr rubble_3x3
    jsr redraw_3x3
    ; fires on the corners
    dec cell_x
    dec cell_y
    lda #C_FIRE
    jsr set_cell
    jsr queue_cell
    inc cell_x
    inc cell_x
    inc cell_y
    inc cell_y
    lda #C_FIRE
    jsr set_cell
    jsr queue_cell
    dec cell_x
    dec cell_y
    jsr sfx_alarm
    lda #MSG_MELTDOWN
    jmp show_msg

; tornado wander/destroy: called every frame during play
tornado_tick:
    lda torn_active
    bne :+
    rts
:   lda frame_ctr
    and #$0F
    beq :+
    rts                 ; act every 16 frames
:
    dec torn_timer
    bne :+
    lda #0
    sta torn_active
    rts
:   ; wander
    jsr rand_step
    and #3
    tax
    lda torn_x
    clc
    adc walk4_dx,x
    cmp #MAPW
    bcs :+
    sta torn_x
:   jsr rand_step
    and #3
    tax
    lda torn_y
    clc
    adc walk4_dy,x
    cmp #MAPH
    bcs :+
    sta torn_y
:   ; destroy what's underneath
    lda torn_x
    sta cell_x
    lda torn_y
    sta cell_y
    jsr get_cell
    beq @done           ; dirt: nothing
    cmp #C_WATER
    beq @done
    cmp #C_RUBBLE
    beq @done
    cmp #C_FIRE
    beq @done
    cmp #$10
    bcc @simple
    ; zone: level the whole thing
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
    jsr rubble_3x3
    jsr redraw_3x3
    rts
@simple:
    cmp #C_WIRE_W
    beq @to_water
    cmp #C_RAIL_W
    beq @to_water
    lda #C_RUBBLE
    bne @wreck
@to_water:
    lda #C_WATER
@wreck:
    jsr set_cell
    lda #0
    sta (ptr1),y
    jsr queue_cell_neighbors
@done:
    rts

; ---------------------------------------------------------------- taxes ----
year_tick:
    ; revenue = (pop/8) * tax_rate
    jsr calc_pop        ; t2/t3 = displayed population
    ldx #3
: lsr t3
    ror t2
    dex
    bne :-
    lda tax_rate
    jsr mul16_by_a      ; t2/t3 *= A
    jsr bin16_to_cost
    lda #<cost_tmp
    sta ptr0
    lda #>cost_tmp
    sta ptr0+1
    jsr money_add
    ; expenses = roads + rails*2 + stations*100
    lda roads_n
    sta t2
    lda roads_n+1
    sta t3
    lda rails_n
    asl a
    sta t0
    lda rails_n+1
    rol a
    sta t1
    lda t2
    clc
    adc t0
    sta t2
    lda t3
    adc t1
    sta t3
    ; stations cost $100/year each (repeated add; station count is small)
    lda police_n
    clc
    adc firestn_n
    tax
    beq @no_stations
: lda t2
    clc
    adc #100
    sta t2
    bcc :+
    inc t3
:   dex
    bne :--
@no_stations:
    jsr bin16_to_cost
    lda #<cost_tmp
    sta ptr0
    lda #>cost_tmp
    sta ptr0+1
    jsr money_sub
    bcs @paid
    ; couldn't pay: drain to zero
    ldx #5
    lda #0
: sta money,x
    dex
    bpl :-
    lda dirty
    ora #DIRTY_MONEY
    sta dirty
@paid:
    lda #MSG_TAXES
    jsr show_msg
    jsr city_save
    rts

; t2/t3 (16-bit) *= A (shift-add, result clamped 16-bit)
mul16_by_a:
    sta mul_a
    lda t2
    sta mul_r
    lda t3
    sta mul_r+1
    lda #0
    sta t2
    sta t3
    ldx #8
@bit:
    lsr mul_a
    bcc @shift
    lda t2
    clc
    adc mul_r
    sta t2
    lda t3
    adc mul_r+1
    sta t3
@shift:
    asl mul_r
    rol mul_r+1
    dex
    bne @bit
    rts

; t2/t3 -> cost_tmp[6] decimal digits (big-endian)
bin16_to_cost:
    lda #0
    sta cost_tmp
    ldx #0              ; 10000,1000,100,10
@dig:
    lda #0
    sta t4
: lda t2
    sec
    sbc pow10_lo,x
    tay
    lda t3
    sbc pow10_hi,x
    bcc :+
    sta t3
    sty t2
    inc t4
    jmp :-
:   lda t4
    sta cost_tmp+1,x
    inx
    cpx #4
    bne @dig
    lda t2
    sta cost_tmp+5
    rts


