; ============================================================================
; ui.asm — title screen, status bar, menus, play-state input handling
; ============================================================================

NTOOLS = 15

; tool indices
TL_BULL  = 0
TL_ROAD  = 1
TL_WIRE  = 2
TL_RAIL  = 3
TL_PARK  = 4
TL_RES   = 5
TL_COM   = 6
TL_IND   = 7
TL_POL   = 8
TL_FIRE  = 9
TL_STAD  = 10
TL_COAL  = 11
TL_NUKE  = 12
TL_PORT  = 13
TL_AIRP  = 14

; ---------------------------------------------------------------- title ----
title_enter:
    lda #0
    sta ppumask_sh
    sta ppuctrl_sh
    jsr wait_vblank
    lda #0
    sta PPUMASK
    sta PPUCTRL
    ; black background for title
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #$0F
    sta PPUDATA
    ; clear NT0
    lda #$20
    jsr clear_nt
    ; attr: text areas use P2 (white on black). skyline handled below.
    ; title text
    lda #$20
    sta t0
    lda #$C7
    sta t1
    ldy #<str_title
    lda #>str_title
    jsr set_ptr0
    jsr ppu_text
    lda #$21
    sta t0
    lda #$27
    sta t1
    ldy #<str_subtitle
    lda #>str_subtitle
    jsr set_ptr0
    jsr ppu_text
    lda #$21
    sta t0
    lda #$CB
    sta t1
    ldy #<str_new_city
    lda #>str_new_city
    jsr set_ptr0
    jsr ppu_text
    ; CONTINUE only if valid save
    jsr save_valid
    bcc :+
    lda #$22
    sta t0
    lda #$0B
    sta t1
    ldy #<str_continue
    lda #>str_continue
    jsr set_ptr0
    jsr ppu_text
:   lda #$22
    sta t0
    lda #$4B
    sta t1
    ldy #<str_level
    lda #>str_level
    jsr set_ptr0
    jsr ppu_text
    jsr title_level_text
    ; skyline: blocks along bottom rows 24-29
    jsr title_skyline
    ; attributes: all P2 for text region, skyline pals set in skyline
    lda #$23
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    ldx #0
: lda #%10101010      ; P2 everywhere
    cpx #48
    bcc :+
    lda title_sky_attr-48,x
:   sta PPUDATA
    inx
    cpx #64
    bne :-
    lda #ST_TITLE
    sta game_state
    lda #0
    sta menu_sel
    sta state_sub
    jsr title_cursor
    ; enable
    lda #%10001000
    sta ppuctrl_sh
    lda #%00011110
    sta ppumask_sh
    jsr wait_vblank
    lda ppuctrl_sh
    sta PPUCTRL
    lda #0
    sta PPUSCROLL
    sta PPUSCROLL
    lda ppumask_sh
    sta PPUMASK
    rts

; skyline attr: bottom 2 attr rows: mix palettes for building band
title_sky_attr:
    .byte $AA,$FF,$FF,$55,$55,$AA,$AA,$AA
    .byte $AA,$FF,$FF,$55,$55,$AA,$AA,$AA

title_skyline:
    ; draw blocks: COM3, RES3, COAL, IND3, POLICE at rows 24-29
    ldx #0
@blk:
    stx t5
    lda sky_blk_lo,x
    sta ptr2
    lda sky_blk_hi,x
    sta ptr2+1
    ; block x: 1 + b*3 cells -> tile col 2+b*6
    ldy #0              ; pos
@pos:
    sty t6
    ; tile row = 24 + (pos/3)*2 ; tile col = 2 + b*6 + (pos%3)*2
    tya
    ; pos/3 and pos%3 via table
    ldx t6
    lda pos_row,x
    asl a
    clc
    adc #24
    sta t2              ; tile row
    lda t5
    asl a               ; b*2
    sta t3
    asl a               ; b*4
    clc
    adc t3              ; b*6
    clc
    adc #2
    ldx t6
    clc
    adc pos_col,x
    adc pos_col,x
    sta t3              ; tile col
    ; gfx id
    ldy t6
    lda (ptr2),y
    tax
    ; write 4 tiles: addr = $2000 + row*32 + col
    lda #0
    sta t4
    lda t2
    asl a
    rol t4
    asl a
    rol t4
    asl a
    rol t4
    asl a
    rol t4
    asl a
    rol t4
    clc
    adc t3
    sta t1
    lda t4
    adc #$20
    sta t0
    sta PPUADDR
    lda t1
    sta PPUADDR
    lda cg_tl,x
    sta PPUDATA
    lda cg_tr,x
    sta PPUDATA
    lda t1
    clc
    adc #32
    sta t1
    lda t0
    adc #0
    sta PPUADDR
    lda t1
    sta PPUADDR
    lda cg_bl,x
    sta PPUDATA
    lda cg_br,x
    sta PPUDATA
    ldy t6
    iny
    cpy #9
    beq :+
    jmp @pos
:   ldx t5
    inx
    cpx #5
    beq :+
    jmp @blk
:   rts

pos_row: .byte 0,0,0,1,1,1,2,2,2
pos_col: .byte 0,1,2,0,1,2,0,1,2

sky_blk_lo: .byte <blk_COM3, <blk_RES3, <blk_COAL, <blk_IND3, <blk_POLICE
sky_blk_hi: .byte >blk_COM3, >blk_RES3, >blk_COAL, >blk_IND3, >blk_POLICE

title_level_text:
    lda #$22
    sta t0
    lda #$52
    sta t1
    lda state_sub       ; difficulty 0..2
    asl a
    asl a
    asl a
    tax
    lda #<lvl_names
    clc
    adc identity,x      ; x = level*8
    tay
    lda #>lvl_names
    adc #0
    jsr set_ptr0
    jmp ppu_text

identity:               ; small helper table for add-x
    .byte 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24

lvl_names:
    .byte "EASY  ",$FF,$00
    .byte "MEDIUM",$FF,$00
    .byte "HARD  ",$FF,$00

; title menu cursor: sprite at selection
title_cursor:
    ldx #0
    lda menu_sel
    beq :+
    ldx #8              ; row offset for CONTINUE
:   lda #$5F            ; y: row 23 (NEW CITY line) - 1... computed:
    ; NEW CITY at tile row 14 -> y=112; CONTINUE row 16 -> y=128
    txa
    asl a               ; 0 or 16
    clc
    adc #111
    sta oam
    lda #S_CURSOR
    sta oam+1
    lda #0
    sta oam+2
    lda #72
    sta oam+3
    ; hide rest
    ldx #4
    lda #$FF
: sta oam,x
    inx
    bne :-
    rts

title_frame:
    lda joy_press
    and #BTN_UP
    beq :+
    lda #0
    sta menu_sel
    jsr title_cursor
:   lda joy_press
    and #BTN_DOWN
    beq :+
    jsr save_valid
    bcc :+
    lda #1
    sta menu_sel
    jsr title_cursor
:   lda joy_press
    and #(BTN_LEFT|BTN_RIGHT)
    beq @no_lvl
    lda joy_press
    and #BTN_RIGHT
    beq @lvl_dn
    lda state_sub
    cmp #2
    bcs @no_lvl
    inc state_sub
    jmp @lvl_upd
@lvl_dn:
    lda state_sub
    beq @no_lvl
    dec state_sub
@lvl_upd:
    ; update level text via queue
    lda #$22
    sta t0
    lda #$52
    sta t1
    lda state_sub
    asl a
    asl a
    asl a
    tax
    lda #<lvl_names
    clc
    adc identity,x
    tay
    lda #>lvl_names
    adc #0
    jsr set_ptr0
    jsr queue_text_once
@no_lvl:
    lda joy_press
    and #(BTN_A|BTN_START)
    beq @done
    ; start game: seed rng
    lda frame_ctr
    ora #1
    sta rand_lo
    eor #$B7
    sta rand_hi
    lda menu_sel
    bne @cont
    jsr city_new
    rts
@cont:
    jsr city_load
    rts
@done:
    rts

; queue text once (active NT only, title uses NT0)
queue_text_once:
    ldy #0
: lda (ptr0),y
    cmp #$FF
    beq :+
    iny
    bne :-
:   sty t2
    tya
    clc
    adc #3
    jsr vq_room
    bcc @no
    lda t2
    jsr vq_hdr
    ldy #0
: lda (ptr0),y
    sta vq,x
    inx
    iny
    cpy t2
    bne :-
    jsr vq_end
@no:
    rts

set_ptr0:
    sty ptr0
    sta ptr0+1
    rts

wait_vblank:
    bit PPUSTATUS
: bit PPUSTATUS
    bpl :-
    rts

clear_nt:               ; A = NT hi byte ($20/$24); clears 1KB
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #0
    ldx #4
    ldy #0
: sta PPUDATA
    iny
    bne :-
    dex
    bne :-
    rts

; ---------------------------------------------------------------- city -----
city_new:
    jsr rendering_off
    jsr map_generate
    ; init state by difficulty
    ldx #0
    lda state_sub
    beq :+
    ldx #6
    cmp #1
    beq :+
    ldx #12
:   ldy #0
: lda start_money,x
    sta money,y
    inx
    iny
    cpy #6
    bne :-
    lda #0
    sta month
    lda #$19
    sta year
    lda #$00
    sta year+1
    lda #7
    sta tax_rate
    lda #2
    sta speed
    lda #1
    sta disaster_on
    lda #TL_ROAD
    sta tool_cur
    lda #24
    sta vp_x
    lda #18
    sta vp_y
    lda #31
    sta cur_x
    lda #24
    sta cur_y
    lda #0
    sta sim_phase
    sta sim_lo
    sta sim_hi
    sta sim_cycles
    sta pw_head
    sta pw_tail
    sta pend_head
    sta pend_tail
    jsr scan_init
    sta msg_cur
    sta res_pop
    sta res_pop+1
    sta com_pop
    sta com_pop+1
    sta ind_pop
    sta ind_pop+1
    sta demand_r
    sta demand_c
    sta demand_i
    jsr city_save
    jmp game_screen_enter

start_money:
    .byte 0,2,0,0,0,0   ; easy   20000
    .byte 0,1,0,0,0,0   ; medium 10000
    .byte 0,0,5,0,0,0   ; hard    5000

city_save:
    lda #'M'
    sta save_magic
    lda #'P'
    sta save_magic+1
    lda #'L'
    sta save_magic+2
    lda #'S'
    sta save_magic+3
    ldx #5
: lda money,x
    sta sv_money,x
    dex
    bpl :-
    lda month
    sta sv_month
    lda year
    sta sv_year
    lda year+1
    sta sv_year+1
    lda tax_rate
    sta sv_tax
    lda vp_x
    sta sv_vpx
    lda vp_y
    sta sv_vpy
    lda cur_x
    sta sv_curx
    lda cur_y
    sta sv_cury
    lda disaster_on
    sta sv_disaster
    rts

city_load:
    ldx #5
: lda sv_money,x
    sta money,x
    dex
    bpl :-
    lda sv_month
    sta month
    lda sv_year
    sta year
    lda sv_year+1
    sta year+1
    lda sv_tax
    sta tax_rate
    lda sv_vpx
    sta vp_x
    lda sv_vpy
    sta vp_y
    lda sv_curx
    sta cur_x
    lda sv_cury
    sta cur_y
    lda sv_disaster
    sta disaster_on
    lda #2
    sta speed
    lda #TL_ROAD
    sta tool_cur
    jsr rendering_off
    jmp game_screen_enter

save_valid:
    lda save_magic
    cmp #'M'
    bne @no
    lda save_magic+1
    cmp #'P'
    bne @no
    lda save_magic+2
    cmp #'L'
    bne @no
    lda save_magic+3
    cmp #'S'
    bne @no
    sec
    rts
@no:
    clc
    rts

rendering_off:
    lda #0
    sta PPUCTRL         ; NMI off first: makes $2002 polling race-free
    sta ppuctrl_sh
    jsr wait_vblank
    lda #0
    sta PPUMASK
    sta ppumask_sh
    rts

; enter the in-game screen: draws everything with rendering off
game_screen_enter:
    ; game palette bg color
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #$1A
    sta PPUDATA
    ; clear both NTs + shadows
    lda #$20
    jsr clear_nt
    lda #$24
    jsr clear_nt
    ldx #0
    lda #0
: sta attr_sh,x
    sta attr_sh1,x
    inx
    cpx #64
    bne :-
    ; clamp viewport
    jsr clamp_vp
    ; draw status bar to both NTs
    jsr status_full_draw
    ; draw viewport to NT0
    lda #0
    sta draw_nt
    sta draw_target
    jsr draw_full_viewport
    lda #0
    sta vq_len
    sta vq_ready
    lda #ST_PLAY
    sta game_state
    lda #$FF
    sta msg_cur
    lda #0
    sta msg_timer
    sta bolt_n
    lda dirty
    ora #(DIRTY_MONEY|DIRTY_DATE|DIRTY_TOOL|DIRTY_RCI|DIRTY_POP)
    sta dirty
    ; sprites on
    lda #%10001000
    sta ppuctrl_sh
    jsr wait_vblank
    lda ppuctrl_sh
    sta PPUCTRL
    lda #0
    sta PPUSCROLL
    sta PPUSCROLL
    lda #%00011110
    sta ppumask_sh
    sta PPUMASK
    rts

clamp_vp:
    lda vp_x
    cmp #MAPW-VIEW_W+1
    bcc :+
    lda #MAPW-VIEW_W
    sta vp_x
:   lda vp_y
    cmp #MAPH-VIEW_H+1
    bcc :+
    lda #MAPH-VIEW_H
    sta vp_y
:   rts

; ---------------------------------------------------------------- status ---
; status bar: rows 0-2 text, row 3 solid separator. Drawn to both NTs.
status_full_draw:
    ; separator row 3 + solid backdrop rows 0-2 (SOLID tiles as bg for text?
    ; text tiles have their own dark bg; fill all 4 rows with SOLID)
    ldx #0              ; both NTs
@nt:
    lda nt_hi_tab,x
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldy #128
    lda #T_SOLID
: sta PPUDATA
    dey
    bne :-
    ; static POP label at row 0 col 21
    lda nt_hi_tab,x
    sta PPUADDR
    lda #$15
    sta PPUADDR
    lda #'P'
    sta PPUDATA
    lda #'O'
    sta PPUDATA
    lda #'P'
    sta PPUDATA
    ; RCI letters at row 1, cols 26/28/30
    lda nt_hi_tab,x
    sta PPUADDR
    lda #$3A
    sta PPUADDR
    lda #'R'
    sta PPUDATA
    lda #' '
    sta PPUDATA
    lda #'C'
    sta PPUDATA
    lda #' '
    sta PPUDATA
    lda #'I'
    sta PPUDATA
    ; attr row 0: all P2
    lda nt_hi_tab,x
    clc
    adc #$03
    sta PPUADDR
    lda #$C0
    sta PPUADDR
    lda #%10101010
    ldy #8
: sta PPUDATA
    dey
    bne :-
    inx
    cpx #2
    bne @nt
    rts

nt_hi_tab: .byte $20,$24

; per-frame status updates: handle one dirty flag per frame via queue.
; Only runs when the queue is empty so a full update always fits.
status_update:
    lda vq_len
    bne @sdone
    lda dirty
    beq @sdone
    lsr a
    bcc :+
    jsr stat_money
    lda dirty
    and #<~DIRTY_MONEY
    sta dirty
    rts
:   lsr a
    bcc :+
    jsr stat_date
    lda dirty
    and #<~DIRTY_DATE
    sta dirty
    rts
:   lsr a
    bcc :+
    jsr stat_rci
    lda dirty
    and #<~DIRTY_RCI
    sta dirty
    rts
:   lsr a
    bcc :+
    jsr stat_tool
    lda dirty
    and #<~DIRTY_TOOL
    sta dirty
    rts
:   lsr a
    bcc :+
    jsr stat_msg
    lda dirty
    and #<~DIRTY_MSG
    sta dirty
    rts
:   lsr a
    bcc @sdone
    jsr stat_pop
    lda dirty
    and #<~DIRTY_POP
    sta dirty
@sdone:
    rts

; money: row 0 col 1: "$123456 " -> build in num_buf as tiles
stat_money:
    ldx #0
    lda #'$'
    sta num_buf
    ; skip leading zeros (but keep last digit)
    ldy #0
: lda money,y
    bne @nz
    iny
    cpy #5
    bne :-
@nz:
    ldx #1
: lda money,y
    clc
    adc #1              ; tile index: digit d -> tile d+1 ('0' tile = 1)
    sta num_buf,x
    inx
    iny
    cpy #6
    bne :-
    ; pad with spaces to 8
: cpx #8
    beq :+
    lda #' '
    sta num_buf,x
    inx
    bne :-
:   lda #$20
    sta t0
    lda #$01
    sta t1
    jmp queue_numbuf8

; queue num_buf (8 tiles) to both NTs at t0/t1
queue_numbuf8:
    lda #8
    sta t4
; queue num_buf (t4 tiles) to both NTs at t0/t1
queue_numbuf:
    lda t4
    asl a
    clc
    adc #6
    jsr vq_room
    bcs :+
    rts
:   lda t4
    jsr vq_hdr
    ldy #0
: lda num_buf,y
    sta vq,x
    inx
    iny
    cpy t4
    bne :-
    jsr vq_end
    lda t0
    eor #$04
    sta t0
    lda t4
    jsr vq_hdr
    ldy #0
: lda num_buf,y
    sta vq,x
    inx
    iny
    cpy t4
    bne :-
    jsr vq_end
    lda t0
    eor #$04
    sta t0
    rts

stat_date:
    ; "JAN 1900" at row 0 col 12
    lda month
    asl a
    clc
    adc month           ; month*3
    tax
    lda month_names,x
    sta num_buf
    lda month_names+1,x
    sta num_buf+1
    lda month_names+2,x
    sta num_buf+2
    lda #' '
    sta num_buf+3
    ; year digits from BCD
    lda year
    lsr a
    lsr a
    lsr a
    lsr a
    clc
    adc #1
    sta num_buf+4
    lda year
    and #$0F
    clc
    adc #1
    sta num_buf+5
    lda year+1
    lsr a
    lsr a
    lsr a
    lsr a
    clc
    adc #1
    sta num_buf+6
    lda year+1
    and #$0F
    clc
    adc #1
    sta num_buf+7
    lda #$20
    sta t0
    lda #$0C
    sta t1
    jmp queue_numbuf8

month_names:
    .byte "JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC"

; RCI bars at row 0, cols 27/29/31 (tile ids BAR1..BAR8 by demand)
stat_rci:
    lda #14
    jsr vq_room
    bcs :+
    rts
:   lda demand_r
    jsr demand_bar
    sta num_buf
    lda demand_c
    jsr demand_bar
    sta num_buf+1
    lda demand_i
    jsr demand_bar
    sta num_buf+2
    ; letters R C I under bars on row 1
    ldx #0
@nt:
    lda nt_hi_tab,x
    sta t0
    lda #$1A
    sta t1
    txa
    pha
    lda #5
    jsr vq_hdr
    lda num_buf
    sta vq,x
    inx
    lda #T_SOLID
    sta vq,x
    inx
    lda num_buf+1
    sta vq,x
    inx
    lda #T_SOLID
    sta vq,x
    inx
    lda num_buf+2
    sta vq,x
    inx
    jsr vq_end
    pla
    tax
    inx
    cpx #2
    bne @nt
    rts

; demand (-128..127) -> bar tile. 0 -> BAR1-ish baseline.
demand_bar:
    clc
    adc #128            ; 0..255
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a               ; 0..7
    clc
    adc #T_BAR1
    rts

stat_tool:
    ; tool name (10 chars) + price (6) at row 1 col 1
    lda tool_cur
    asl a
    tax
    lda tool_names_lo,x
    ldy tool_cur
    lda tool_names_lo,y
    sta ptr0
    lda tool_names_hi,y
    sta ptr0+1
    ; copy 10 chars into num_buf... too small; write two chunks
    ; chunk 1: name 10 tiles
    lda #26
    jsr vq_room
    bcs :+
    rts
:   ldx #0
@nt:
    lda nt_hi_tab,x
    sta t0
    lda #$21
    sta t1
    txa
    pha
    lda #10
    jsr vq_hdr
    ldy #0
: lda (ptr0),y
    sta vq,x
    inx
    iny
    cpy #10
    bne :-
    jsr vq_end
    pla
    tax
    inx
    cpx #2
    bne @nt
    ; price: "$NNNNN " 7 tiles at col 12 row 1
    jsr tool_cost_ptr
    ldx #0
    lda #'$'
    sta num_buf
    ldy #0
: lda (ptr0),y
    bne @nz
    iny
    cpy #5
    bne :-
@nz:
    ldx #1
: lda (ptr0),y
    clc
    adc #1
    sta num_buf,x
    inx
    iny
    cpy #6
    bne :-
: cpx #8
    beq :+
    lda #' '
    sta num_buf,x
    inx
    bne :-
:   lda #$20
    sta t0
    lda #$2C
    sta t1
    jmp queue_numbuf8

; ptr0 = cost digits for tool_cur
tool_cost_ptr:
    lda tool_cur
    asl a
    clc
    adc tool_cur        ; *3
    asl a               ; *6
    tay
    lda #<tool_costs
    clc
    adc identity,y
    ; careful: identity table only 25 long; do 16-bit add properly
    sta ptr0
    lda #>tool_costs
    adc #0
    sta ptr0+1
    ; redo with plain math to be safe
    lda tool_cur
    asl a
    clc
    adc tool_cur
    asl a
    clc
    adc #<tool_costs
    sta ptr0
    lda #>tool_costs
    adc #0
    sta ptr0+1
    rts

stat_msg:
    ; message line: row 2, 28 chars from msg table (or blank)
    lda #66
    jsr vq_room
    bcs :+
    rts
:   lda msg_cur
    cmp #$FF
    bne @have
    ; clear line
    ldx #0
@ntc:
    lda nt_hi_tab,x
    sta t0
    lda #$41
    sta t1
    txa
    pha
    lda #28
    jsr vq_hdr
    ldy #28
    lda #T_SOLID
: sta vq,x
    inx
    dey
    bne :-
    jsr vq_end
    pla
    tax
    inx
    cpx #2
    bne @ntc
    rts
@have:
    tay
    lda msg_lo,y
    sta ptr0
    lda msg_hi,y
    sta ptr0+1
    lda #$20
    sta t0
    lda #$41
    sta t1
    jsr draw_text
    rts

stat_pop:
    ; population: 5 digits at row 1 col 20 (label is static on row 0)
    jsr calc_pop        ; 16-bit in t2/t3 (lo/hi)
    ; 16-bit to 5 digits: repeated subtract powers of 10
    ldx #0
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
    clc
    adc #1              ; digit tile
    sta num_buf,x
    inx
    cpx #4
    bne @dig
    lda t2
    clc
    adc #1
    sta num_buf+4
    ; suppress leading zeros (keep last)
    ldx #0
: lda num_buf,x
    cmp #1              ; '0' tile
    bne :+
    lda #' '
    sta num_buf,x
    inx
    cpx #4
    bne :-
:   lda #$20
    sta t0
    lda #$34
    sta t1
    lda #5
    sta t4
    jmp queue_numbuf

pow10_lo: .byte <10000, <1000, <100, <10
pow10_hi: .byte >10000, >1000, >100, >10

; total pop = (res_pop + com_pop + ind_pop) * 8-ish; use sum*4 for feel
calc_pop:
    lda res_pop
    clc
    adc com_pop
    sta t2
    lda res_pop+1
    adc com_pop+1
    sta t3
    lda t2
    clc
    adc ind_pop
    sta t2
    lda t3
    adc ind_pop+1
    sta t3
    ; x32 (each zone level represents ~32 citizens)
    ldx #5
: asl t2
    rol t3
    dex
    bne :-
    rts

; ---------------------------------------------------------------- play -----
play_frame:
    jsr pend_drain
    jsr cursor_move
    jsr play_buttons
    jsr sim_slice
    jsr tornado_tick
    jsr status_update
    jsr build_oam
    rts

cursor_move:
    lda #0
    sta cur_moved
    lda joy_rep
    and #BTN_UP
    beq :+
    lda cur_y
    beq :+
    dec cur_y
    inc cur_moved
:   lda joy_rep
    and #BTN_DOWN
    beq :+
    lda cur_y
    cmp #MAPH-1
    bcs :+
    inc cur_y
    inc cur_moved
:   lda joy_rep
    and #BTN_LEFT
    beq :+
    lda cur_x
    beq :+
    dec cur_x
    inc cur_moved
:   lda joy_rep
    and #BTN_RIGHT
    beq :+
    lda cur_x
    cmp #MAPW-1
    bcs :+
    inc cur_x
    inc cur_moved
:   lda cur_moved
    beq @done
    ; page if cursor left viewport
    lda cur_x
    sec
    sbc vp_x
    bcc @page_l
    cmp #VIEW_W
    bcs @page_r
    lda cur_y
    sec
    sbc vp_y
    bcc @page_u
    cmp #VIEW_H
    bcs @page_d
@done:
    rts
@page_l:
    lda vp_x
    sec
    sbc #8
    bcs :+
    lda #0
:   sta vp_x
    jmp start_trans
@page_r:
    lda vp_x
    clc
    adc #8
    cmp #MAPW-VIEW_W+1
    bcc :+
    lda #MAPW-VIEW_W
:   sta vp_x
    jmp start_trans
@page_u:
    lda vp_y
    sec
    sbc #6
    bcs :+
    lda #0
:   sta vp_y
    jmp start_trans
@page_d:
    lda vp_y
    clc
    adc #6
    cmp #MAPH-VIEW_H+1
    bcc :+
    lda #MAPH-VIEW_H
:   sta vp_y
    jmp start_trans

start_trans:
    lda draw_nt
    eor #1
    sta draw_target
    lda #0
    sta trans_row
    lda #ST_TRANS
    sta game_state
    rts

trans_frame:
    ; draw up to 2 rows per frame into back NT
    jsr queue_row_step
    lda game_state
    cmp #ST_TRANS
    bne :+
    jsr build_oam
:   rts

queue_row_step:
    lda trans_row
    cmp #VIEW_H
    bcs @flip
    sta t0
    jsr queue_row
    inc trans_row
    rts
@flip:
    lda draw_target
    sta draw_nt
    lda ppuctrl_sh
    and #%11111100
    ora draw_nt
    sta ppuctrl_sh
    lda #ST_PLAY
    sta game_state
    rts

play_buttons:
    lda joy_press
    and #BTN_SELECT
    beq :+
    ldx tool_cur
    inx
    cpx #NTOOLS
    bcc :++
    ldx #0
    jmp :++
:   jmp @not_sel
:   stx tool_cur
    jsr tool_size_upd
    lda dirty
    ora #DIRTY_TOOL
    sta dirty
@not_sel:
    lda joy_press
    and #BTN_A
    beq :+
    jsr tool_apply
:   lda joy_press
    and #BTN_B
    beq :+
    jsr menu_open
:   lda joy_press
    and #BTN_START
    beq :+
    jsr pause_open
:   rts

tool_size_upd:
    ldx tool_cur
    lda tool_sizes,x
    sta tool_size
    rts

; ---------------------------------------------------------------- OAM ------
build_oam:
    ldx #0
    ; cursor box: screen pos = (cur - vp)*16, y + 32 for status bar
    lda cur_x
    sec
    sbc vp_x
    asl a
    asl a
    asl a
    asl a
    sta t0              ; x
    lda cur_y
    sec
    sbc vp_y
    asl a
    asl a
    asl a
    asl a
    clc
    adc #32
    sta t1              ; y
    ; 3x3 tools: box offset -16, size 48; else 16
    lda tool_size
    cmp #3
    bne @small
    lda t0
    sec
    sbc #16
    sta t0
    lda t1
    sec
    sbc #16
    sta t1
    lda #40             ; corner offset = size-8
    sta t2
    bne @corners
@small:
    lda #8
    sta t2
@corners:
    ; TL
    lda t1
    sec
    sbc #1
    sta oam,x
    inx
    lda #S_CURSOR
    sta oam,x
    inx
    lda #0
    sta oam,x
    inx
    lda t0
    sta oam,x
    inx
    ; TR (H flip)
    lda t1
    sec
    sbc #1
    sta oam,x
    inx
    lda #S_CURSOR
    sta oam,x
    inx
    lda #%01000000
    sta oam,x
    inx
    lda t0
    clc
    adc t2
    sta oam,x
    inx
    ; BL (V flip)
    lda t1
    clc
    adc t2
    sec
    sbc #1
    sta oam,x
    inx
    lda #S_CURSOR
    sta oam,x
    inx
    lda #%10000000
    sta oam,x
    inx
    lda t0
    sta oam,x
    inx
    ; BR
    lda t1
    clc
    adc t2
    sec
    sbc #1
    sta oam,x
    inx
    lda #S_CURSOR
    sta oam,x
    inx
    lda #%11000000
    sta oam,x
    inx
    lda t0
    clc
    adc t2
    sta oam,x
    inx
    ; bolts: flash unpowered zone centers (blink on frame bit)
    lda frame_ctr
    and #%00010000
    beq @hide_rest
    ldy #0
@bolt:
    cpy bolt_n
    bcs @hide_rest
    lda bolt_y,y
    sec
    sbc vp_y
    asl a
    asl a
    asl a
    asl a
    clc
    adc #32+3
    sta oam,x
    inx
    lda #S_BOLT
    sta oam,x
    inx
    lda #1
    sta oam,x
    inx
    lda bolt_x,y
    sec
    sbc vp_x
    asl a
    asl a
    asl a
    asl a
    clc
    adc #4
    sta oam,x
    inx
    iny
    bne @bolt
@hide_rest:
    ; tornado (16x16, 2 animation frames)
    lda torn_active
    beq @no_torn
    lda torn_x
    sec
    sbc vp_x
    cmp #VIEW_W
    bcs @no_torn
    asl a
    asl a
    asl a
    asl a
    sta t0
    lda torn_y
    sec
    sbc vp_y
    cmp #VIEW_H
    bcs @no_torn
    asl a
    asl a
    asl a
    asl a
    clc
    adc #32
    sta t1
    ; tile base: alternate A/B every 8 frames
    lda frame_ctr
    and #%00001000
    beq :+
    lda #S_TORN_B0
    bne :++
:   lda #S_TORN_A0
:   sta t2
    ldy #0
@tq: lda t1
    clc
    adc torn_qy,y
    sec
    sbc #1
    sta oam,x
    inx
    tya
    clc
    adc t2
    sta oam,x
    inx
    lda #%00000010      ; palette 2 (grays)
    sta oam,x
    inx
    lda t0
    clc
    adc torn_qx,y
    sta oam,x
    inx
    iny
    cpy #4
    bne @tq
@no_torn:
    lda #$FF
: sta oam,x
    inx
    bne :-
    rts

torn_qx: .byte 0,8,0,8      ; sprite quadrant offsets (TL,TR,BL,BR)
torn_qy: .byte 0,0,8,8

; ---------------------------------------------------------------- strings --
str_title:    .byte "M I C R O P O L I S",$FF
str_subtitle: .byte "- THE CITY SIMULATOR -",$FF
str_new_city: .byte "NEW CITY",$FF
str_continue: .byte "CONTINUE",$FF
str_level:    .byte "LEVEL",$FF

tool_names_lo:
    .byte <tn_bull,<tn_road,<tn_wire,<tn_rail,<tn_park
    .byte <tn_res,<tn_com,<tn_ind,<tn_pol,<tn_fire
    .byte <tn_stad,<tn_coal,<tn_nuke,<tn_port,<tn_airp
tool_names_hi:
    .byte >tn_bull,>tn_road,>tn_wire,>tn_rail,>tn_park
    .byte >tn_res,>tn_com,>tn_ind,>tn_pol,>tn_fire
    .byte >tn_stad,>tn_coal,>tn_nuke,>tn_port,>tn_airp

; names padded to 10 chars
tn_bull: .byte "BULLDOZER "
tn_road: .byte "ROAD      "
tn_wire: .byte "POWER LINE"
tn_rail: .byte "RAIL      "
tn_park: .byte "PARK      "
tn_res:  .byte "RESIDENT. "
tn_com:  .byte "COMMERCIAL"
tn_ind:  .byte "INDUSTRIAL"
tn_pol:  .byte "POLICE DEP"
tn_fire: .byte "FIRE DEPT "
tn_stad: .byte "STADIUM   "
tn_coal: .byte "COAL POWER"
tn_nuke: .byte "NUKE POWER"
tn_port: .byte "SEAPORT   "
tn_airp: .byte "AIRPORT   "

; costs: 6 digits each
tool_costs:
    .byte 0,0,0,0,0,1   ; bulldozer 1
    .byte 0,0,0,0,1,0   ; road 10
    .byte 0,0,0,0,0,5   ; wire 5
    .byte 0,0,0,0,2,0   ; rail 20
    .byte 0,0,0,0,1,0   ; park 10
    .byte 0,0,0,1,0,0   ; res 100
    .byte 0,0,0,1,0,0   ; com 100
    .byte 0,0,0,1,0,0   ; ind 100
    .byte 0,0,0,5,0,0   ; police 500
    .byte 0,0,0,5,0,0   ; fire 500
    .byte 0,0,5,0,0,0   ; stadium 5000
    .byte 0,0,3,0,0,0   ; coal 3000
    .byte 0,0,5,0,0,0   ; nuke 5000
    .byte 0,0,3,0,0,0   ; seaport 3000
    .byte 0,1,0,0,0,0   ; airport 10000

tool_sizes:
    .byte 1,1,1,1,1, 3,3,3, 3,3, 3,3,3,3,3

; map codes placed by tools (0 = special-cased)
tool_codes:
    .byte C_DIRT, C_ROAD, C_WIRE, C_RAIL, C_PARK
    .byte C_ZR, C_ZC, C_ZI, C_POLICE, C_FIRESTN
    .byte C_STADIUM, C_COAL, C_NUKE, C_SEAPORT, C_AIRPORT

; ---------------------------------------------------------------- menu -----
; build menu: full-screen list drawn into back NT progressively, then flip.
menu_open:
    lda draw_nt
    eor #1
    sta draw_target
    lda #0
    sta trans_row       ; reused as draw progress
    lda tool_cur
    sta menu_sel
    lda #ST_MENU
    sta game_state
    lda #0
    sta state_sub       ; 0=drawing, 1=interactive, 2=closing
    rts

menu_frame:
    lda state_sub
    beq @drawing
    cmp #1
    beq @interact
    ; closing: redraw viewport rows into back NT then flip
    jsr queue_row_step  ; flips + sets ST_PLAY when done
    lda game_state
    cmp #ST_PLAY
    bne :+
    lda dirty
    ora #DIRTY_TOOL
    sta dirty
:   jmp build_oam_menu_hidden
@drawing:
    jsr menu_draw_step
    jmp build_oam_menu
@interact:
    lda joy_rep
    and #BTN_UP
    beq :+
    lda menu_sel
    beq :+
    dec menu_sel
    jsr sfx_click
:   lda joy_rep
    and #BTN_DOWN
    beq :+
    lda menu_sel
    cmp #NTOOLS-1
    bcs :+
    inc menu_sel
    jsr sfx_click
:   lda joy_press
    and #BTN_A
    beq :+
    lda menu_sel
    sta tool_cur
    jsr tool_size_upd
    jmp menu_close
:   lda joy_press
    and #BTN_B
    beq :+
    jmp menu_close
:   jmp build_oam_menu

menu_close:
    lda draw_nt
    eor #1
    sta draw_target
    lda #0
    sta trans_row
    lda #2
    sta state_sub
    rts

; draw menu screen: rows drawn 2 per frame into back NT
; layout: row 5 title, rows 7..21 tools (15), prices right-aligned
menu_draw_step:
    lda trans_row
    cmp #26
    bcs @done_draw
    ; clear this NT row pair? draw content row by row:
    ; menu occupies tile rows 4..29 in back NT: write full 32-tile rows
    ; row content: SOLID border cols 2/29? keep simple: solid bg + text
    jsr menu_row_build   ; builds row_buf 32 tiles for tile row (4+trans_row)
    ; queue it
    lda #38
    jsr vq_room
    bcs :+
    rts
:   ; addr
    lda trans_row
    clc
    adc #4
    sta t2
    lda #0
    sta t3
    lda t2
    asl a
    rol t3
    asl a
    rol t3
    asl a
    rol t3
    asl a
    rol t3
    asl a
    rol t3
    sta t1
    lda t3
    clc
    adc nt_base_hi
    sta t0
    lda #32
    jsr vq_hdr
    ldy #0
: lda row_buf,y
    sta vq,x
    inx
    iny
    cpy #32
    bne :-
    jsr vq_end
    inc trans_row
    rts
@done_draw:
    ; attrs for menu region: all P2 (attr rows 1-7 = 56 bytes)
    lda #59
    jsr vq_room
    bcs :+
    rts
:   jsr nt_base_hi_calc
    lda nt_base_hi
    clc
    adc #$03
    sta t0
    lda #$C8
    sta t1
    lda #56
    jsr vq_hdr
    lda #%10101010
    ldy #56
: sta vq,x
    inx
    dey
    bne :-
    jsr vq_end
    ; flip to menu screen
    lda draw_target
    sta draw_nt
    lda ppuctrl_sh
    and #%11111100
    ora draw_nt
    sta ppuctrl_sh
    lda #1
    sta state_sub
    rts

; build one 32-tile menu row for tile row (4 + trans_row)
menu_row_build:
    jsr nt_base_hi_calc
    ldy #0
    lda #T_SOLID
: sta row_buf,y
    iny
    cpy #32
    bne :-
    lda trans_row
    cmp #1
    beq @title
    ; tools at rows 3..17 -> trans_row-3 = tool idx
    sec
    sbc #3
    bmi @plain
    cmp #NTOOLS
    bcs @plain
    sta t4              ; tool index
    ; name at col 7
    tay
    lda tool_names_lo,y
    sta ptr0
    lda tool_names_hi,y
    sta ptr0+1
    ldy #0
: lda (ptr0),y
    sta row_buf+7,y
    iny
    cpy #10
    bne :-
    ; price at col 19: $ + digits
    lda t4
    asl a
    clc
    adc t4
    asl a
    clc
    adc #<tool_costs
    sta ptr0
    lda #>tool_costs
    adc #0
    sta ptr0+1
    lda #'$'
    sta row_buf+19
    ldy #0
    ldx #20
: lda (ptr0),y
    clc
    adc #1
    sta row_buf,x
    inx
    iny
    cpy #6
    bne :-
    ; strip leading zero tiles (replace with solid)
    ldx #20
: lda row_buf,x
    cmp #1
    bne @plain
    lda #T_SOLID
    sta row_buf,x
    inx
    cpx #25
    bne :-
@plain:
    rts
@title:
    ldy #0
: lda menu_title,y
    cmp #$FF
    beq @plain
    sta row_buf+11,y
    iny
    bne :-

menu_title: .byte "BUILD MENU",$FF

; menu cursor sprite at selected row
build_oam_menu:
    lda state_sub
    cmp #1
    bne build_oam_menu_hidden
    ldx #0
    ; y = (4 + 3 + menu_sel + ... ) tile rows: menu item row = 7+sel? rows:
    ; tools start at tile row 4+3=7 -> y = 7*8 + sel*8
    lda menu_sel
    asl a
    asl a
    asl a
    clc
    adc #56-1
    sta oam
    lda #S_CURSOR
    sta oam+1
    lda #0
    sta oam+2
    lda #32
    sta oam+3
    ldx #4
build_oam_menu_hidden_from4:
    lda #$FF
: sta oam,x
    inx
    bne :-
    rts
build_oam_menu_hidden:
    ldx #0
    jmp build_oam_menu_hidden_from4

; ---------------------------------------------------------------- pause ----
; START opens the city report / budget screen (drawn into the back
; nametable, then flipped in — same machinery as the build menu).
pause_open:
    lda draw_nt
    eor #1
    sta draw_target
    lda #0
    sta trans_row
    sta menu_sel        ; 0=tax, 1=speed, 2=disasters
    sta state_sub       ; 0=drawing, 1=interactive, 2=closing
    lda #ST_PAUSE
    sta game_state
    jsr city_save
    rts

pause_frame:
    lda state_sub
    beq @drawing
    cmp #1
    beq @interact
    ; closing
    jsr queue_row_step
    jmp build_oam_menu_hidden
@drawing:
    jsr pause_draw_step
    jmp build_oam_menu_hidden
@interact:
    lda joy_press
    and #(BTN_START|BTN_B)
    beq :+
    ; close
    lda draw_nt
    eor #1
    sta draw_target
    lda #0
    sta trans_row
    lda #2
    sta state_sub
    rts
:   lda joy_press
    and #BTN_UP
    beq :+
    lda menu_sel
    beq :+
    dec menu_sel
:   lda joy_press
    and #BTN_DOWN
    beq :+
    lda menu_sel
    cmp #2
    bcs :+
    inc menu_sel
:   lda joy_press
    and #BTN_LEFT
    beq :+
    jsr pause_adjust_dn
:   lda joy_press
    and #BTN_RIGHT
    beq :+
    jsr pause_adjust_up
:   jmp pause_oam

pause_adjust_up:
    lda menu_sel
    beq @tax
    cmp #1
    beq @spd
    lda #1
    sta disaster_on
    jmp pause_refresh
@tax:
    lda tax_rate
    cmp #20
    bcs @done
    inc tax_rate
    jmp pause_refresh
@spd:
    lda speed
    cmp #3
    bcs @done
    inc speed
    jmp pause_refresh
@done:
    rts

pause_adjust_dn:
    lda menu_sel
    beq @tax
    cmp #1
    beq @spd
    lda #0
    sta disaster_on
    jmp pause_refresh
@tax:
    lda tax_rate
    beq @done
    dec tax_rate
    jmp pause_refresh
@spd:
    lda speed
    beq @done
    dec speed
    jmp pause_refresh
@done:
    rts

; requeue the adjusted row (rows 7/9/11 relative -> menu_sel)
pause_refresh:
    lda menu_sel
    asl a
    clc
    adc #7
    sta trans_row       ; borrow as row index for build
    jsr pause_row_build
    lda #38
    jsr vq_room
    bcs :+
    rts
:   jsr nt_base_hi_calc
    lda trans_row
    clc
    adc #4
    sta t2
    lda #0
    sta t3
    lda t2
    asl a
    rol t3
    asl a
    rol t3
    asl a
    rol t3
    asl a
    rol t3
    asl a
    rol t3
    sta t1
    lda t3
    clc
    adc nt_base_hi
    sta t0
    lda #32
    jsr vq_hdr
    ldy #0
: lda row_buf,y
    sta vq,x
    inx
    iny
    cpy #32
    bne :-
    jmp vq_end

pause_oam:
    ; selection arrow next to the adjustable rows
    ldx #0
    lda menu_sel
    asl a
    asl a
    asl a
    asl a               ; sel*16
    clc
    adc #(4+7)*8-1
    sta oam
    lda #S_CURSOR
    sta oam+1
    lda #0
    sta oam+2
    lda #24
    sta oam+3
    ldx #4
    jmp build_oam_menu_hidden_from4

pause_draw_step:
    lda trans_row
    cmp #26
    bcs @attrs
    jsr pause_row_build
    lda #38
    jsr vq_room
    bcs :+
    rts
:   jsr nt_base_hi_calc
    lda trans_row
    clc
    adc #4
    sta t2
    lda #0
    sta t3
    lda t2
    asl a
    rol t3
    asl a
    rol t3
    asl a
    rol t3
    asl a
    rol t3
    asl a
    rol t3
    sta t1
    lda t3
    clc
    adc nt_base_hi
    sta t0
    lda #32
    jsr vq_hdr
    ldy #0
: lda row_buf,y
    sta vq,x
    inx
    iny
    cpy #32
    bne :-
    jsr vq_end
    inc trans_row
    rts
@attrs:
    lda #59
    jsr vq_room
    bcs :+
    rts
:   jsr nt_base_hi_calc
    lda nt_base_hi
    clc
    adc #$03
    sta t0
    lda #$C8
    sta t1
    lda #56
    jsr vq_hdr
    lda #%10101010
    ldy #56
: sta vq,x
    inx
    dey
    bne :-
    jsr vq_end
    lda draw_target
    sta draw_nt
    lda ppuctrl_sh
    and #%11111100
    ora draw_nt
    sta ppuctrl_sh
    lda #1
    sta state_sub
    rts

; write string at ptr0 into row_buf at offset X ($FF-terminated)
rb_text:
    ldy #0
: lda (ptr0),y
    cmp #$FF
    beq :+
    sta row_buf,x
    inx
    iny
    bne :-
:   rts

; write 16-bit t2/t3 into row_buf at X, 5 digits, leading spaces
rb_num16:
    txa
    pha
    jsr bin16_to_cost
    pla
    tax
    ldy #1
: lda cost_tmp,y
    clc
    adc #1
    sta row_buf,x
    inx
    iny
    cpy #6
    bne :-
    ; leading zero suppression (keep the last digit)
    txa
    sec
    sbc #5
    tax
    ldy #4
: lda row_buf,x
    cmp #1
    bne :+
    lda #' '
    sta row_buf,x
    inx
    dey
    bne :-
:   rts

; build one 32-tile row of the report screen (row index in trans_row)
pause_row_build:
    ldy #0
    lda #' '
: sta row_buf,y
    iny
    cpy #32
    bne :-
    lda trans_row
    cmp #1
    bne :+
    jmp prb_title
:   cmp #3
    bne :+
    jmp prb_funds
:   cmp #4
    bne :+
    jmp prb_pop
:   cmp #7
    bne :+
    jmp prb_tax
:   cmp #9
    bne :+
    jmp prb_speed
:   cmp #11
    bne :+
    jmp prb_disaster
:   cmp #14
    bne :+
    jmp prb_res
:   cmp #15
    bne :+
    jmp prb_com
:   cmp #16
    bne :+
    jmp prb_ind
:   cmp #18
    bne :+
    jmp prb_infra
:   cmp #20
    bne :+
    jmp prb_approval
:   cmp #23
    bne :+
    jmp prb_hint
:   rts

prb_title:
    ldx #10
    ldy #<str_report
    lda #>str_report
    jsr set_ptr0
    jmp rb_text
prb_funds:
    ldx #6
    ldy #<str_funds
    lda #>str_funds
    jsr set_ptr0
    jsr rb_text
    ; money digits at col 17
    lda #'$'
    sta row_buf+17
    ldx #0
    ldy #0
: lda money,y
    clc
    adc #1
    sta row_buf+18,x
    inx
    iny
    cpy #6
    bne :-
    ; suppress leading zeros
    ldx #0
: lda row_buf+18,x
    cmp #1
    bne :+
    lda #' '
    sta row_buf+18,x
    inx
    cpx #5
    bne :-
:   rts
prb_pop:
    ldx #6
    ldy #<str_popl
    lda #>str_popl
    jsr set_ptr0
    jsr rb_text
    jsr calc_pop
    ldx #18
    jmp rb_num16
prb_tax:
    ldx #6
    ldy #<str_tax
    lda #>str_tax
    jsr set_ptr0
    jsr rb_text
    lda tax_rate
    sta t2
    lda #0
    sta t3
    ldx #18
    jsr rb_num16
    lda #'%'
    sta row_buf+23
    rts
prb_speed:
    ldx #6
    ldy #<str_speed
    lda #>str_speed
    jsr set_ptr0
    jsr rb_text
    lda speed
    asl a
    asl a
    asl a
    tay
    ldx #18
: lda speed_names,y
    cmp #$FF
    beq :+
    sta row_buf,x
    inx
    iny
    bne :-
:   rts
prb_disaster:
    ldx #6
    ldy #<str_disas
    lda #>str_disas
    jsr set_ptr0
    jsr rb_text
    lda disaster_on
    beq @off
    ldy #<str_on
    lda #>str_on
    bne @w
@off:
    ldy #<str_off
    lda #>str_off
@w: jsr set_ptr0
    ldx #18
    jmp rb_text
prb_res:
    ldx #6
    ldy #<str_res
    lda #>str_res
    jsr set_ptr0
    jsr rb_text
    lda res_pop
    sta t2
    lda res_pop+1
    sta t3
    ldx #12
    jsr rb_num16
    ldx #20
    ldy #<str_zones
    lda #>str_zones
    jsr set_ptr0
    jsr rb_text
    lda res_zones
    sta t2
    lda #0
    sta t3
    ldx #26
    jmp rb_num16
prb_com:
    ldx #6
    ldy #<str_com
    lda #>str_com
    jsr set_ptr0
    jsr rb_text
    lda com_pop
    sta t2
    lda com_pop+1
    sta t3
    ldx #12
    jsr rb_num16
    ldx #20
    ldy #<str_zones
    lda #>str_zones
    jsr set_ptr0
    jsr rb_text
    lda com_zones
    sta t2
    lda #0
    sta t3
    ldx #26
    jmp rb_num16
prb_ind:
    ldx #6
    ldy #<str_ind
    lda #>str_ind
    jsr set_ptr0
    jsr rb_text
    lda ind_pop
    sta t2
    lda ind_pop+1
    sta t3
    ldx #12
    jsr rb_num16
    ldx #20
    ldy #<str_zones
    lda #>str_zones
    jsr set_ptr0
    jsr rb_text
    lda ind_zones
    sta t2
    lda #0
    sta t3
    ldx #26
    jmp rb_num16
prb_infra:
    ldx #6
    ldy #<str_roads
    lda #>str_roads
    jsr set_ptr0
    jsr rb_text
    lda roads_n
    sta t2
    lda roads_n+1
    sta t3
    ldx #12
    jsr rb_num16
    ldx #20
    ldy #<str_plants
    lda #>str_plants
    jsr set_ptr0
    jsr rb_text
    lda plant_n
    sta t2
    lda #0
    sta t3
    ldx #26
    jmp rb_num16
prb_approval:
    ldx #6
    ldy #<str_approval
    lda #>str_approval
    jsr set_ptr0
    jsr rb_text
    jsr calc_approval
    sta t2
    lda #0
    sta t3
    ldx #18
    jsr rb_num16
    lda #'%'
    sta row_buf+23
    rts
prb_hint:
    ldx #6
    ldy #<str_hint
    lda #>str_hint
    jsr set_ptr0
    jmp rb_text

; approval 0-99: powered ratio, services, disasters
calc_approval:
    lda #50
    jsr acc_set
    lda powered_n
    lsr a
    jsr acc_add
    lda unpowered_n
    asl a
    jsr acc_sub
    lda police_n
    asl a
    jsr acc_add
    lda firestn_n
    asl a
    jsr acc_add
    lda fire_n
    asl a
    asl a
    jsr acc_sub
    lda tax_rate
    jsr acc_sub
    lda has_flags       ; amenities please citizens
    and #1
    beq :+
    lda #5
    jsr acc_add
:   jsr acc_clamp100
    ora #0              ; refresh N/Z from the value itself
    bmi @zero
    cmp #100
    bcc @ok
    lda #99
    rts
@zero:
    lda #0
@ok:
    rts

str_report:   .byte "CITY REPORT",$FF
str_funds:    .byte "FUNDS",$FF
str_popl:     .byte "POPULATION",$FF
str_tax:      .byte "TAX RATE",$FF
str_speed:    .byte "SIM SPEED",$FF
str_disas:    .byte "DISASTERS",$FF
str_on:       .byte "ON ",$FF
str_off:      .byte "OFF",$FF
str_res:      .byte "RES",$FF
str_com:      .byte "COM",$FF
str_ind:      .byte "IND",$FF
str_zones:    .byte "ZONES",$FF
str_roads:    .byte "ROADS",$FF
str_plants:   .byte "PLANTS",$FF
str_approval: .byte "APPROVAL",$FF
str_hint:     .byte "START - BACK TO CITY",$FF

speed_names:
    .byte "PAUSED",$FF,$00
    .byte "SLOW  ",$FF,$00
    .byte "NORMAL",$FF,$00
    .byte "FAST  ",$FF,$00
