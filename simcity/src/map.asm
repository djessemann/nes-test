; ============================================================================
; map.asm — city map storage, graphics derivation, viewport rendering
; ============================================================================

; ---------------------------------------------------------------- access ---
; cell_ptr: (cell_x, cell_y) -> ptr0 = &map0[cy*64+cx], ptr1 = &map1[...]
; clobbers A. Y left at 0.
cell_ptr:
    lda cell_y
    and #3
    tay
    lda row_lo_tab,y
    ora cell_x
    sta ptr0
    sta ptr1
    lda cell_y
    lsr a
    lsr a
    clc
    adc #>map0
    sta ptr0+1
    adc #>(map1-map0)   ; map1 is +$0C00
    sta ptr1+1
    ldy #0
    rts

row_lo_tab: .byte $00,$40,$80,$C0

; get_cell: A = map0[cell_x,cell_y]
get_cell:
    jsr cell_ptr
    lda (ptr0),y
    rts

; set_cell: A -> map0[cell_x,cell_y]
set_cell:
    pha
    jsr cell_ptr
    pla
    sta (ptr0),y
    rts

; neighbor fetch: returns map0 code of neighbor or $FF if off-map
; t3 = direction 0=N 1=E 2=S 3=W ; preserves cell_x/cell_y
get_neighbor:
    lda t3
    beq @n
    cmp #1
    beq @e
    cmp #2
    beq @s
@w: lda cell_x
    beq @off
    dec cell_x
    jsr get_cell
    inc cell_x
    rts
@n: lda cell_y
    beq @off
    dec cell_y
    jsr get_cell
    inc cell_y
    rts
@e: lda cell_x
    cmp #MAPW-1
    bcs @off
    inc cell_x
    jsr get_cell
    dec cell_x
    rts
@s: lda cell_y
    cmp #MAPH-1
    bcs @off
    inc cell_y
    jsr get_cell
    dec cell_y
    rts
@off:
    lda #$FF
    rts

; ---------------------------------------------------------------- classify -
; is_roadish: A=code, returns carry set if road-bearing
is_roadish:
    cmp #C_ROAD
    beq @yes
    cmp #C_ROADWIRE
    beq @yes
    cmp #C_RAILROAD
    beq @yes
    clc
    rts
@yes:
    sec
    rts

is_railish:
    cmp #C_RAIL
    beq @yes
    cmp #C_RAILROAD
    beq @yes
    cmp #C_RAIL_W
    beq @yes
    clc
    rts
@yes:
    sec
    rts

is_wireish:
    cmp #C_WIRE
    beq @yes
    cmp #C_ROADWIRE
    beq @yes
    cmp #C_WIRE_W
    beq @yes
    clc
    rts
@yes:
    sec
    rts

; net_mask: build 4-bit N/E/S/W mask. ptr2 = classifier routine address.
; result in t4.
net_mask:
    lda #0
    sta t4
    lda #0
    sta t3
@loop:
    jsr get_neighbor
    jsr call_ptr2
    bcc @no
    ldx t3
    lda t4
    ora mask_bit,x
    sta t4
@no:
    inc t3
    lda t3
    cmp #4
    bne @loop
    rts

call_ptr2:
    jmp (ptr2)

mask_bit: .byte 1,2,4,8   ; N,E,S,W

; ---------------------------------------------------------------- gfx ------
; cell_gfx: derive gfx_id/gfx_at for cell (cell_x, cell_y).
; input A = cell code (from get_cell).
cell_gfx:
    cmp #$10
    bcc :+
    jmp @zone
:   tax
    lda small_gfx,x
    cmp #$FF
    beq :+
    jmp @have           ; simple static mapping
:
    ; dynamic: roads/rails/wires/crossings/fire
    txa
    cmp #C_FIRE
    beq @fire
    cmp #C_ROAD
    beq @road
    cmp #C_RAIL
    beq @rail
    cmp #C_WIRE
    beq @wire
    cmp #C_ROADWIRE
    beq @roadwire
    cmp #C_WIRE_W
    bne :+
    jmp @wire_w
:   cmp #C_RAIL_W
    bne :+
    jmp @rail_w
:   ; railroad crossing
    lda #<is_railish
    sta ptr2
    lda #>is_railish
    sta ptr2+1
    jsr net_mask
    lda t4
    and #(1|4)          ; rail N/S -> rail vertical -> road horizontal
    beq :+
    lda #CG_RAILROAD_H
    jmp @have
:   lda #CG_RAILROAD_V
    jmp @have
@fire:
    lda frame_ctr
    and #%00010000
    beq :+
    lda #CG_FIRE_A
    jmp @have
:   lda #CG_FIRE_B
    jmp @have
@road:
    lda #<is_roadish
    sta ptr2
    lda #>is_roadish
    sta ptr2+1
    jsr net_mask
    lda #CG_ROAD
    clc
    adc t4
    jmp @have
@rail:
    lda #<is_railish
    sta ptr2
    lda #>is_railish
    sta ptr2+1
    jsr net_mask
    lda #CG_RAIL
    clc
    adc t4
    jmp @have
@wire:
    lda #<is_wireish
    sta ptr2
    lda #>is_wireish
    sta ptr2+1
    jsr net_mask
    lda #CG_WIRE
    clc
    adc t4
    jmp @have
@roadwire:
    lda #<is_roadish
    sta ptr2
    lda #>is_roadish
    sta ptr2+1
    jsr net_mask
    lda t4
    and #(1|4)          ; road N/S -> road vertical
    beq :+
    lda #CG_ROADWIRE_V
    jmp @have
:   lda #CG_ROADWIRE_H
    jmp @have
@wire_w:
    lda #<is_wireish
    sta ptr2
    lda #>is_wireish
    sta ptr2+1
    jsr net_mask
    lda t4
    and #(1|4)          ; wire N/S -> vertical crossing
    beq :+
    lda #CG_WIREW_V
    jmp @have
:   lda #CG_WIREW_H
    jmp @have
@rail_w:
    lda #<is_railish
    sta ptr2
    lda #>is_railish
    sta ptr2+1
    jsr net_mask
    lda t4
    and #(1|4)
    beq :+
    lda #CG_RAILW_V
    jmp @have
:   lda #CG_RAILW_H
@have:
    sta gfx_id
    tax
    lda cg_at,x
    sta gfx_at
    rts

@zone:
    ; A = $10..$AF : high nibble = type+1, low = pos 0..8
    sta t5
    and #$0F
    sta t6              ; pos
    lda t5
    lsr a
    lsr a
    lsr a
    lsr a
    sec
    sbc #1              ; type 0..9
    cmp #3
    bcs @building
    ; RCI zone: level = aux of center cell
    sta t5              ; type 0..2
    jsr zone_center_aux ; A = level 0..3 (uses t6=pos)
    ; gfx = zgfx[type][level*9 + pos]
    asl a
    asl a
    asl a
    adc t6              ; carry clear (level*8 max 24 + pos)
    sta t3
    lda t5              ; wait: level*9 = level*8 + level
    ; redo: A(level) preserved? recompute cleanly below
    jsr zone_level_a    ; A = level again (cheap)
    clc
    adc t3              ; level*8 + pos + level = level*9 + pos
    tax
    lda t5
    beq @zr
    cmp #1
    beq @zc
    lda zgfx_i,x
    jmp @have
@zc:
    lda zgfx_c,x
    jmp @have
@zr:
    lda zgfx_r,x
    jmp @have
@building:
    ; type 3..9 -> blk tables
    sec
    sbc #3
    tax
    lda blk_tab_lo,x
    sta ptr2
    lda blk_tab_hi,x
    sta ptr2+1
    ldy t6
    lda (ptr2),y
    ldy #0
    jmp @have

; zone_center_aux: for zone cell (cell_x,cell_y) with pos in t6,
; returns A = level (aux & 3 of the center cell). Preserves cell_x/y.
.segment "BSS"
zone_level_save: .res 1
.segment "CODE"
zone_center_aux:
    lda cell_x
    pha
    lda cell_y
    pha
    ldx t6
    lda cell_x
    clc
    adc center_dx,x
    sta cell_x
    lda cell_y
    clc
    adc center_dy,x
    sta cell_y
    jsr cell_ptr
    lda (ptr1),y
    and #$03
    sta zone_level_save
    pla
    sta cell_y
    pla
    sta cell_x
    lda zone_level_save
    rts
zone_level_a:
    lda zone_level_save
    rts

; offsets from pos to center (pos 0=NW ... 8=SE)
center_dx: .byte 1, 0, <-1, 1, 0, <-1, 1, 0, <-1
center_dy: .byte 1, 1,  1,  0, 0,  0, <-1, <-1, <-1

; small cell gfx map ($FF = dynamic)
small_gfx:
    .byte CG_DIRT, CG_TREES, CG_WATER, CG_RUBBLE, CG_PARK
    .byte $FF, $FF, $FF, $FF, $FF, $FF   ; fire, road, rail, wire, rw, rr
    .byte $FF, $FF                       ; water wire, water rail
    .byte 0,0,0

blk_tab_lo:
    .byte <blk_POLICE, <blk_FIRESTN, <blk_COAL, <blk_NUKE
    .byte <blk_STADIUM, <blk_SEAPORT, <blk_AIRPORT
blk_tab_hi:
    .byte >blk_POLICE, >blk_FIRESTN, >blk_COAL, >blk_NUKE
    .byte >blk_STADIUM, >blk_SEAPORT, >blk_AIRPORT

; ---------------------------------------------------------------- drawing --
; row_buf: 32 top tiles + 32 bottom tiles + 8 attr bytes built per cell row
.segment "BSS"
row_buf:     .res 72
.segment "CODE"

; build_row: fill row_buf for viewport cell row in t0 (0..12) targeting
; attr shadow X: 0 = attr_sh (NT0), 1 = attr_sh1.
; row cells from (vp_x, vp_y + t0).
build_row:
    lda t0
    sta tmp_row
    ldx #0
    stx tmp_col
@col:
    lda vp_x
    clc
    adc tmp_col
    sta cell_x
    lda vp_y
    clc
    adc tmp_row
    sta cell_y
    jsr get_cell
    jsr cell_gfx
    ; tiles
    ldx gfx_id
    ldy tmp_col
    tya
    asl a
    tay
    lda cg_tl,x
    sta row_buf,y
    lda cg_bl,x
    sta row_buf+32,y
    iny
    lda cg_tr,x
    sta row_buf,y
    lda cg_br,x
    sta row_buf+32,y
    ; attr: 2 bits into row_buf+64 + (col>>1)
    lda tmp_col
    lsr a
    tay
    lda gfx_at
    ldx tmp_row
    ; quadrant: qy = row&1, qx = col&1 -> shift = (qy*2+qx)*2
    txa
    and #1
    asl a
    sta t2
    lda tmp_col
    and #1
    ora t2
    asl a
    tax                 ; shift amount
    lda gfx_at
@shl:
    dex
    bmi @shifted
    asl a
    jmp @shl
@shifted:
    ora row_buf+64,y
    sta row_buf+64,y
    inc tmp_col
    lda tmp_col
    cmp #VIEW_W
    bne @col
    rts

; clear attr accumulation for a row build
clear_row_attr:
    lda #0
    ldy #7
: sta row_buf+64,y
    dey
    bpl :-
    rts

; merge row attrs into shadow + return: for row r, attr bytes live at
; shadow index ay*8..ay*8+7 where ay=(4+2r)>>2. If r even, row supplies
; top quadrant bits (mask $0F); if odd, bottom bits (mask $F0).
; X = target shadow (0=NT0's, 1=NT1's)
merge_row_attr:
    lda tmp_row
    asl a
    clc
    adc #4
    lsr a
    lsr a
    asl a
    asl a
    asl a
    sta t2              ; ay*8
    lda tmp_row
    and #1
    beq @even
    lda #$0F            ; odd row: keep existing top bits
    bne @go
@even:
    lda #$F0            ; even row: keep existing bottom bits
@go:
    sta t3
    ldy #0
@loop:
    tya
    clc
    adc t2
    tax
    lda draw_target
    bne @nt1
    lda attr_sh,x
    and t3
    ora row_buf+64,y
    sta attr_sh,x
    sta row_buf+64,y
    jmp @next
@nt1:
    lda attr_sh1,x
    and t3
    ora row_buf+64,y
    sta attr_sh1,x
    sta row_buf+64,y
@next:
    iny
    cpy #8
    bne @loop
    rts

.segment "BSS"
draw_target: .res 1     ; 0 = NT0, 1 = NT1 (for full/row draws)
.segment "CODE"

; draw_row_now: immediate PPU write of row t0 to draw_target NT
; (rendering must be OFF). Also writes the 8 attr bytes.
draw_row_now:
    jsr clear_row_attr
    jsr build_row
    ldx draw_target
    jsr merge_row_attr
    ; PPU addr = base + (4+2r)*32
    lda tmp_row
    asl a
    clc
    adc #4              ; tile row
    ; addr = base + row*32 : row*32 = row<<5
    sta t2
    lda #0
    sta t3
    ; shift left 5: use 16-bit
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
    sta t2              ; lo
    lda t3
    clc
    adc nt_base_hi
    sta PPUADDR
    lda t2
    sta PPUADDR
    ldy #0
: lda row_buf,y
    sta PPUDATA
    iny
    cpy #32
    bne :-
    ; second tile row = addr + 32
    lda t2
    clc
    adc #32
    sta t4
    lda t3
    adc #0
    clc
    adc nt_base_hi
    sta PPUADDR
    lda t4
    sta PPUADDR
    ldy #0
: lda row_buf+32,y
    sta PPUDATA
    iny
    cpy #32
    bne :-
    ; attrs: addr = base + $3C0 + ay*8
    lda tmp_row
    asl a
    clc
    adc #4
    lsr a
    lsr a
    asl a
    asl a
    asl a
    clc
    adc #$C0
    sta t2
    lda nt_base_hi
    clc
    adc #$03
    sta PPUADDR
    lda t2
    sta PPUADDR
    ldy #0
: lda row_buf+64,y
    sta PPUDATA
    iny
    cpy #8
    bne :-
    rts

nt_base_hi_calc:
    lda draw_target
    beq :+
    lda #$24
    sta nt_base_hi
    rts
:   lda #$20
    sta nt_base_hi
    rts

.segment "BSS"
nt_base_hi: .res 1
.segment "CODE"

; draw_full_viewport: rendering OFF. draws all 13 rows to draw_target.
draw_full_viewport:
    jsr nt_base_hi_calc
    lda #0
    sta t0
: jsr draw_row_now
    inc t0
    lda t0
    cmp #VIEW_H
    bne :-
    rts

; queue_row: queue cell row t0 (of viewport) for back-NT during transition.
; 72 bytes of data + 9 header = 81 queue bytes.
queue_row:
    jsr nt_base_hi_calc
    jsr clear_row_attr
    jsr build_row
    ldx draw_target
    jsr merge_row_attr
    ; entry 1: top tile row (32 bytes)
    lda tmp_row
    asl a
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
    sta t1              ; lo
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
    ; entry 2: bottom tile row
    lda t1
    clc
    adc #32
    sta t1
    lda t0
    adc #0
    sta t0
    lda #32
    jsr vq_hdr
    ldy #32
: lda row_buf,y
    sta vq,x
    inx
    iny
    cpy #64
    bne :-
    jsr vq_end
    ; entry 3: attr row
    lda tmp_row
    asl a
    clc
    adc #4
    lsr a
    lsr a
    asl a
    asl a
    asl a
    clc
    adc #$C0
    sta t1
    lda nt_base_hi
    clc
    adc #$03
    sta t0
    lda #8
    jsr vq_hdr
    ldy #64
: lda row_buf,y
    sta vq,x
    inx
    iny
    cpy #72
    bne :-
    jsr vq_end
    rts

; queue_cell: redraw single cell (cell_x,cell_y) in the ACTIVE nametable
; if it is inside the viewport. 19 queue bytes.
queue_cell:
    ; visible?
    lda cell_x
    sec
    sbc vp_x
    bcc @out
    cmp #VIEW_W
    bcs @out
    sta tmp_col
    lda cell_y
    sec
    sbc vp_y
    bcc @out
    cmp #VIEW_H
    bcs @out
    sta tmp_row
    ; room? 19 bytes; if not, defer to the pending list
    lda #19
    jsr vq_room
    bcs :+
    jmp pend_push
@out:
    rts
:   jsr get_cell
    jsr cell_gfx
    ; NT base = active
    lda draw_nt
    beq :+
    lda #$24
    bne :++
:   lda #$20
:   sta t5              ; base hi
    ; addr = base + (4+2row)*32 + 2col
    lda tmp_row
    asl a
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
    sta t2
    lda tmp_col
    asl a
    clc
    adc t2
    sta t1
    lda t3
    adc #0
    clc
    adc t5
    sta t0
    ; entry 1: 2 tiles top
    lda #2
    jsr vq_hdr
    ldy gfx_id
    lda cg_tl,y
    sta vq,x
    inx
    lda cg_tr,y
    sta vq,x
    inx
    jsr vq_end
    ; entry 2: 2 tiles bottom (addr+32)
    lda t1
    clc
    adc #32
    sta t1
    lda t0
    adc #0
    sta t0
    lda #2
    jsr vq_hdr
    ldy gfx_id
    lda cg_bl,y
    sta vq,x
    inx
    lda cg_br,y
    sta vq,x
    inx
    jsr vq_end
    ; entry 3: attr byte read-modify from active shadow
    lda tmp_row
    asl a
    clc
    adc #4
    lsr a
    lsr a
    asl a
    asl a
    asl a
    sta t2              ; ay*8
    lda tmp_col
    lsr a
    clc
    adc t2
    tax                 ; shadow index
    ; shift = ((row&1)*2 + (col&1))*2
    lda tmp_row
    and #1
    asl a
    sta t3
    lda tmp_col
    and #1
    ora t3
    asl a
    tay                 ; shift
    lda #%00000011
    sty t3
@mkmask:
    dey
    bmi @mdone
    asl a
    jmp @mkmask
@mdone:
    eor #$FF
    sta t4              ; and-mask
    lda gfx_at
    ldy t3
@shpal:
    dey
    bmi @shdone
    asl a
    jmp @shpal
@shdone:
    sta t6              ; or-bits
    ; pick shadow
    lda draw_nt
    beq @sh0
    lda attr_sh1,x
    and t4
    ora t6
    sta attr_sh1,x
    jmp @wq
@sh0:
    lda attr_sh,x
    and t4
    ora t6
    sta attr_sh,x
@wq:
    pha
    ; attr addr = base + $3C0 + index
    txa
    clc
    adc #$C0
    sta t1
    lda t5
    clc
    adc #$03
    sta t0
    lda #1
    jsr vq_hdr
    pla
    sta vq,x
    inx
    jsr vq_end
    rts

; deferred cell redraws (vblank queue was full)
pend_push:
    ldx pend_tail
    inx
    txa
    and #$0F
    cmp pend_head
    beq @full           ; drop (extremely unlikely; sim will redraw later)
    ldx pend_tail
    lda cell_x
    sta pend_x,x
    lda cell_y
    sta pend_y,x
    inx
    txa
    and #$0F
    sta pend_tail
@full:
    rts

pend_drain:
    lda pend_head
    cmp pend_tail
    beq @done
    lda #19
    jsr vq_room
    bcc @done
    lda cell_x
    pha
    lda cell_y
    pha
    ldx pend_head
    lda pend_x,x
    sta cell_x
    lda pend_y,x
    sta cell_y
    inx
    txa
    and #$0F
    sta pend_head
    jsr queue_cell
    pla
    sta cell_y
    pla
    sta cell_x
    jmp pend_drain
@done:
    rts

; redraw cell and its 4 neighbors (for network connections)
queue_cell_neighbors:
    jsr queue_cell
    lda cell_x
    beq :+
    dec cell_x
    jsr queue_cell
    inc cell_x
:   lda cell_x
    cmp #MAPW-1
    bcs :+
    inc cell_x
    jsr queue_cell
    dec cell_x
:   lda cell_y
    beq :+
    dec cell_y
    jsr queue_cell
    inc cell_y
:   lda cell_y
    cmp #MAPH-1
    bcs :+
    inc cell_y
    jsr queue_cell
    dec cell_y
:   rts

; ---------------------------------------------------------------- mapgen ---
; generate terrain into map0/map1
map_generate:
    ; clear to dirt
    lda #<map0
    sta ptr0
    lda #>map0
    sta ptr0+1
    ldx #24             ; 24 pages = 6KB (map0+map1)
    lda #0
    tay
@clr:
: sta (ptr0),y
    iny
    bne :-
    inc ptr0+1
    dex
    bne @clr

    ; river: random walk left -> right, 2 cells wide + meander
    jsr rand_step
    and #$1F
    clc
    adc #8              ; y in 8..39
    sta t0              ; river y
    lda #0
    sta t1              ; x
@river:
    lda t1
    sta cell_x
    lda t0
    sta cell_y
    jsr place_water_blob
    ; meander
    jsr rand_step
    and #3
    beq @no_move        ; 25% straight
    cmp #1
    beq @down
    ; up (2/4 -> up/down evenly)
    cmp #2
    beq @up
@down:
    lda t0
    cmp #MAPH-6
    bcs @no_move
    inc t0
    inc t0
    jmp @no_move
@up:
    lda t0
    cmp #6
    bcc @no_move
    dec t0
    dec t0
@no_move:
    inc t1
    inc t1
    lda t1
    cmp #MAPW
    bcc @river

    ; lakes: 4 blobs
    ldx #4
@lakes:
    txa
    pha
    jsr rand_step
    and #$3F
    sta cell_x
    jsr rand_step
    and #$1F
    clc
    adc #8
    sta cell_y
    jsr place_water_blob
    ; second blob adjacent for irregular shape
    inc cell_x
    inc cell_y
    jsr place_water_blob
    pla
    tax
    dex
    bne @lakes

    ; forests: 24 clumps of random walks
    ldx #24
@forest:
    txa
    pha
    jsr rand_step
    and #$3F
    sta cell_x
    jsr rand_step
    ldy #48
    jsr mod_y
    sta cell_y
    ldy #10             ; trees per clump
@tw:
    tya
    pha
    jsr tree_here
    ; drunken step
    jsr rand_step
    and #3
    tax
    lda cell_x
    clc
    adc walk_dx,x
    and #$3F
    sta cell_x
    jsr rand_step
    and #3
    tax
    lda cell_y
    clc
    adc walk_dy,x
    cmp #MAPH
    bcc :+
    lda #MAPH-2
:   sta cell_y
    pla
    tay
    dey
    bne @tw
    pla
    tax
    dex
    bne @forest
    rts

walk_dx: .byte 1, <-1, 0, 1
walk_dy: .byte 0, 1, <-1, 0

mod_y:                  ; A mod Y -> A (Y<=128)
    sty t7
: sec
    sbc t7
    bcs :-
    adc t7
    rts

tree_here:
    jsr get_cell
    bne :+              ; only on dirt
    lda #C_TREES
    sta (ptr0),y
:   rts

; water blob 2x2 at cell_x/cell_y (clamped)
place_water_blob:
    lda cell_x
    pha
    lda cell_y
    pha
    lda cell_x
    cmp #MAPW-1
    bcc :+
    lda #MAPW-2
    sta cell_x
:   lda cell_y
    cmp #MAPH-1
    bcc :+
    lda #MAPH-2
    sta cell_y
:   lda #C_WATER
    jsr set_cell
    inc cell_x
    lda #C_WATER
    jsr set_cell
    inc cell_y
    lda #C_WATER
    jsr set_cell
    dec cell_x
    lda #C_WATER
    jsr set_cell
    pla
    sta cell_y
    pla
    sta cell_x
    rts
