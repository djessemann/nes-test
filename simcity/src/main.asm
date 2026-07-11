; ============================================================================
; MICROPOLIS — a city simulator for the NES
; An homage to the original 1989 city simulator, rebuilt from scratch
; in 6502 assembly. Mapper: MMC1 (32KB PRG, 8KB CHR, 8KB battery WRAM).
; ============================================================================

.include "tiles.inc"
FONTMAP                 ; map ASCII -> font tile indices for all strings

; ---------------------------------------------------------------- PPU/APU --
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
JOY1      = $4016
JOY2      = $4017

; buttons (bit numbers in joy state)
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SELECT = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

; ---------------------------------------------------------------- map ------
MAPW      = 64
MAPH      = 48
VIEW_W    = 16
VIEW_H    = 13
STATUS_ROWS = 4          ; tile rows used by status bar

; map0 cell codes
C_DIRT    = $00
C_TREES   = $01
C_WATER   = $02
C_RUBBLE  = $03
C_PARK    = $04
C_FIRE    = $05
C_ROAD    = $06
C_RAIL    = $07
C_WIRE    = $08
C_ROADWIRE = $09
C_RAILROAD = $0A
C_WIRE_W  = $0B         ; power line over water
C_RAIL_W  = $0C         ; rail trestle over water
; zone cells: $10+pos R, $20+pos C, $30+pos I, then buildings
C_ZR      = $10
C_ZC      = $20
C_ZI      = $30
C_POLICE  = $40
C_FIRESTN = $50
C_COAL    = $60
C_NUKE    = $70
C_STADIUM = $80
C_SEAPORT = $90
C_AIRPORT = $A0
C_ZONE_END = $B0

; game states
ST_TITLE  = 0
ST_PLAY   = 1
ST_TRANS  = 2            ; page transition (drawing back nametable)
ST_MENU   = 3            ; build menu overlay
ST_PAUSE  = 4            ; pause/budget screen
ST_NEWMAP = 5            ; generating map

; ---------------------------------------------------------------- header ---
.segment "HEADER"
.byte $4E,$45,$53,$1A   ; "NES" (raw — FONTMAP remaps char literals)
.byte 2                 ; 2x16KB PRG
.byte 1                 ; 1x8KB CHR
.byte $12               ; mapper 1 low nibble, battery-backed WRAM
.byte $00
.byte 1                 ; 8KB PRG RAM
.byte 0,0,0,0,0,0,0

; ---------------------------------------------------------------- zeropage -
.segment "ZEROPAGE"
frame_ctr:   .res 1
nmi_ready:   .res 1
ppuctrl_sh:  .res 1     ; PPUCTRL shadow (incl. nametable select bit)
ppumask_sh:  .res 1
joy:         .res 1
joy_prev:    .res 1
joy_press:   .res 1     ; buttons newly pressed this frame
joy_rep:     .res 1     ; presses + autorepeat (d-pad)
rep_timer:   .res 1
game_state:  .res 1
state_sub:   .res 1
vp_x:        .res 1     ; viewport top-left cell
vp_y:        .res 1
cur_x:       .res 1     ; cursor cell (map coords)
cur_y:       .res 1
draw_nt:     .res 1     ; displayed nametable 0/1
rand_lo:     .res 1
rand_hi:     .res 1
ptr0:        .res 2
ptr1:        .res 2
ptr2:        .res 2
t0:          .res 1
t1:          .res 1
t2:          .res 1
t3:          .res 1
t4:          .res 1
t5:          .res 1
t6:          .res 1
t7:          .res 1
cell_x:      .res 1     ; args for map routines
cell_y:      .res 1
gfx_id:      .res 1
gfx_at:      .res 1
tool_cur:    .res 1
menu_sel:    .res 1
menu_top:    .res 1
trans_row:   .res 1
money:       .res 6     ; six decimal digits, big-endian
month:       .res 1     ; 0-11
year:        .res 2     ; BCD big-endian: $19,$00
dirty:       .res 1     ; status redraw flags
msg_cur:     .res 1     ; current advisor message id
msg_timer:   .res 1
speed:       .res 1     ; 0=pause 1=slow 2=med 3=fast
tax_rate:    .res 1     ; 0-20
oam_ptr:     .res 1
sim_phase:   .res 1
sim_lo:      .res 1     ; sim scan index
sim_hi:      .res 1
vq_len:      .res 1     ; vblank queue byte length
vq_ready:    .res 1
tool_size:   .res 1     ; 1 or 3 cells
cur_moved:   .res 1
menu_page:   .res 1
sim_p0:      .res 2     ; scan pointer into map0
sim_p1:      .res 2     ; scan pointer into map1
sim_cx:      .res 1     ; scan cell coords
sim_cy:      .res 1

DIRTY_MONEY = %00000001
DIRTY_DATE  = %00000010
DIRTY_RCI   = %00000100
DIRTY_TOOL  = %00001000
DIRTY_MSG   = %00010000
DIRTY_POP   = %00100000

.segment "OAM_SEG"
oam: .res 256

.segment "BSS"
vq:          .res 176   ; vblank write queue
attr_sh:     .res 64    ; attribute shadow, NT0
attr_sh1:    .res 64    ; attribute shadow, NT1
res_pop:     .res 2     ; zone population counts (levels summed)
com_pop:     .res 2
ind_pop:     .res 2
res_zones:   .res 1     ; zone center counts
com_zones:   .res 1
ind_zones:   .res 1
demand_r:    .res 1     ; signed demand -128..127
demand_c:    .res 1
demand_i:    .res 1
powered_n:   .res 1     ; powered zone centers
unpowered_n: .res 1
plant_n:     .res 1     ; power plant count
pw_head:     .res 1
pw_tail:     .res 1
bolt_n:      .res 1
bolt_x:      .res 8
bolt_y:      .res 8
scan_r:      .res 2     ; per-pass accumulators
scan_c:      .res 2
scan_i:      .res 2
scan_rz:     .res 1
scan_cz:     .res 1
scan_iz:     .res 1
scan_pow:    .res 1
scan_unp:    .res 1
scan_plant:  .res 1
scan_road:   .res 2
scan_rail:   .res 2
scan_fire:   .res 1     ; burning cells seen this pass
scan_firestn: .res 1
scan_police: .res 1
scan_flags:  .res 1     ; bit0 stadium, bit1 seaport, bit2 airport (powered)
scan_boltn:  .res 1
sim_cycles:  .res 1     ; completed scan passes (month ticks)
roads_n:     .res 2     ; latched stats
rails_n:     .res 2
police_n:    .res 1
firestn_n:   .res 1
has_flags:   .res 1
grew_flag:   .res 1     ; a zone changed level this frame (throttle)
pw_drop:     .res 1     ; BFS queue overflowed
cost_tmp:    .res 6     ; scratch digits for money ops
mul_a:       .res 2
mul_r:       .res 2
bolt_tx:     .res 8     ; bolt list being built this pass
bolt_ty:     .res 8
pend_x:      .res 16    ; cell redraws deferred when the queue was full
pend_y:      .res 16
pend_head:   .res 1
pend_tail:   .res 1
num_buf:     .res 8     ; text number scratch
tmp_row:     .res 1
tmp_col:     .res 1
disaster_on: .res 1
fire_n:      .res 1     ; active fires (from last pass)
new_city:    .res 1
torn_active: .res 1
torn_x:      .res 1
torn_y:      .res 1
torn_timer:  .res 1     ; lifetime in 16-frame steps
scan_nuke_x: .res 1
scan_nuke_y: .res 1
scan_nuke_f: .res 1
nuke_x:      .res 1
nuke_y:      .res 1
nuke_present: .res 1

; ---------------------------------------------------------------- WRAM -----
.segment "WRAM"
map0:        .res 3072  ; cell codes
map1:        .res 3072  ; bit7 power, bit6 power scratch, bits0-3 zone level
save_magic:  .res 4
sv_money:    .res 6
sv_month:    .res 1
sv_year:     .res 2
sv_tax:      .res 1
sv_vpx:      .res 1
sv_vpy:      .res 1
sv_curx:     .res 1
sv_cury:     .res 1
sv_speed:    .res 1
sv_disaster: .res 1
pw_queue:    .res 512   ; power BFS queue (256 entries x 2)

; ---------------------------------------------------------------- code -----
.segment "CODE"

reset:
    sei
    cld
    ldx #$40
    stx JOY2
    ldx #$FF
    txs
    inx
    stx PPUCTRL
    stx PPUMASK
    stx $4010

    lda #$80
    sta $8000           ; reset MMC1 shift register
    lda #%00000010      ; vertical mirroring, 32KB PRG, 8KB CHR
    jsr mmc1_ctrl
    lda #0
    jsr mmc1_chr0
    lda #0
    jsr mmc1_prg        ; WRAM enabled

    bit PPUSTATUS
: bit PPUSTATUS
    bpl :-

    lda #0
    tax
: sta $0000,x
    sta $0100,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne :-
    lda #$FF
: sta $0200,x
    inx
    bne :-

: bit PPUSTATUS
    bpl :-

    ; ---- palettes
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #0
: lda palettes,x
    sta PPUDATA
    inx
    cpx #32
    bne :-

    jsr rng_init
    jsr apu_init
    jsr title_enter

main_loop:
    lda nmi_ready
    beq main_loop
    lda #0
    sta nmi_ready

    jsr read_joy
    jsr rand_step

    lda game_state
    cmp #ST_TITLE
    bne :+
    jsr title_frame
    jmp main_done
:   cmp #ST_PLAY
    bne :+
    jsr play_frame
    jmp main_done
:   cmp #ST_TRANS
    bne :+
    jsr trans_frame
    jmp main_done
:   cmp #ST_MENU
    bne :+
    jsr menu_frame
    jmp main_done
:   cmp #ST_PAUSE
    bne :+
    jsr pause_frame
:
main_done:
    ; release the vblank queue to the NMI handler (all writes complete)
    lda vq_len
    beq :+
    lda #1
    sta vq_ready
:   jmp main_loop

; ---------------------------------------------------------------- NMI ------
nmi:
    pha
    txa
    pha
    tya
    pha
    inc frame_ctr

    lda #0
    sta OAMADDR
    lda #>oam
    sta OAMDMA

    ; drain vblank queue: entries [addr_hi, addr_lo, len, data...]
    lda vq_ready
    beq vq_done
    ldx #0
vq_entry:
    cpx vq_len
    bcs vq_flush
    lda vq,x
    sta PPUADDR
    inx
    lda vq,x
    sta PPUADDR
    inx
    lda vq,x            ; count
    inx
    tay
: lda vq,x
    sta PPUDATA
    inx
    dey
    bne :-
    jmp vq_entry
vq_flush:
    lda #0
    sta vq_len
    sta vq_ready
vq_done:

    lda ppuctrl_sh
    sta PPUCTRL
    bit PPUSTATUS
    lda #0
    sta PPUSCROLL
    sta PPUSCROLL
    lda ppumask_sh
    sta PPUMASK

    jsr audio_tick

    lda #1
    sta nmi_ready
    pla
    tay
    pla
    tax
    pla
irq:
    rti

; ---------------------------------------------------------------- MMC1 -----
mmc1_ctrl:
    sta $8000
    lsr a
    sta $8000
    lsr a
    sta $8000
    lsr a
    sta $8000
    lsr a
    sta $8000
    rts
mmc1_chr0:
    sta $A000
    lsr a
    sta $A000
    lsr a
    sta $A000
    lsr a
    sta $A000
    lsr a
    sta $A000
    rts
mmc1_prg:
    sta $E000
    lsr a
    sta $E000
    lsr a
    sta $E000
    lsr a
    sta $E000
    lsr a
    sta $E000
    rts

; ---------------------------------------------------------------- input ----
read_joy:
    lda joy
    sta joy_prev
    lda #1
    sta JOY1
    lda #0
    sta JOY1
    ldx #8
: lda JOY1
    lsr a
    rol joy
    dex
    bne :-
    ; newly pressed
    lda joy_prev
    eor #$FF
    and joy
    sta joy_press
    ; autorepeat on d-pad
    sta joy_rep
    lda joy
    and #(BTN_UP|BTN_DOWN|BTN_LEFT|BTN_RIGHT)
    beq rep_reset
    lda joy_press
    and #(BTN_UP|BTN_DOWN|BTN_LEFT|BTN_RIGHT)
    bne rep_reset2      ; fresh press: restart timer
    dec rep_timer
    bne rep_done
    lda #4              ; repeat rate
    sta rep_timer
    lda joy
    and #(BTN_UP|BTN_DOWN|BTN_LEFT|BTN_RIGHT)
    ora joy_rep
    sta joy_rep
    rts
rep_reset2:
    lda #14             ; initial repeat delay
    sta rep_timer
    rts
rep_reset:
    lda #14
    sta rep_timer
rep_done:
    rts

; ---------------------------------------------------------------- RNG ------
rng_init:
    lda #$5A
    sta rand_lo
    lda #$21
    sta rand_hi
    rts

rand_step:              ; 16-bit galois LFSR, returns A = random byte
    lda rand_hi
    lsr a
    lda rand_lo
    ror a
    eor rand_hi
    sta rand_hi
    ror a
    eor rand_lo
    sta rand_lo
    eor rand_hi
    sta rand_hi
    lda rand_lo
    rts

; A = random in 0..(X-1), X <= 128 (simple modulo by masking + retry-free fold)
rand_mod:
    stx t7
    jsr rand_step
: sec
    sbc t7
    bcs :-
    adc t7
    rts

; ---------------------------------------------------------------- money ----
; money is 6 decimal digits, big-endian, one digit per byte (money..money+5).
; Costs are 6-digit tables in ROM. ptr0 -> cost digits.

; money_cmp: carry set if money >= cost (ptr0)
money_cmp:
    ldy #0
: lda money,y
    cmp (ptr0),y
    bcc @less
    bne @more
    iny
    cpy #6
    bne :-
@more:
    sec
    rts
@less:
    clc
    rts

; money_sub: pay cost at ptr0. carry set if paid, clear if insufficient.
money_sub:
    jsr money_cmp
    bcs :+
    rts                 ; carry clear = can't afford
:   lda #0
    sta t7              ; borrow
    ldy #5
@loop:
    lda money,y
    sec
    sbc t7              ; A = money - borrow  (exact, small values)
    sec
    sbc (ptr0),y        ; A = money - borrow - cost  (mod 256)
    bpl @ok
    clc
    adc #10
    ldx #1
    bne @st
@ok:
    ldx #0
@st:
    stx t7
    sta money,y
    dey
    bpl @loop
    lda dirty
    ora #DIRTY_MONEY
    sta dirty
    sec
    rts

; money_add: add cost digits at ptr0, clamp at 999999
money_add:
    lda #0
    sta t7              ; carry digit
    ldy #5
@loop:
    lda money,y
    clc
    adc t7
    clc
    adc (ptr0),y
    cmp #10
    bcc @ok
    sec
    sbc #10
    ldx #1
    bne @st
@ok:
    ldx #0
@st:
    stx t7
    sta money,y
    dey
    bpl @loop
    lda t7
    beq @fin
    ldy #5
    lda #9
: sta money,y
    dey
    bpl :-
@fin:
    lda dirty
    ora #DIRTY_MONEY
    sta dirty
    rts

; ---------------------------------------------------------------- queue ----
; append to vblank queue: caller sets up ptr1 = data, X = count,
; ptr2 = PPU addr (t0=hi, t1=lo). Returns carry clear if no room.
; Simple byte-level API used by helpers below.

; vq_room: A = bytes needed incl header; carry set if room.
; The cap keeps total NMI PPU writes within the vblank budget.
vq_room:
    clc
    adc vq_len
    cmp #100
    bcs @no
    sec
    rts
@no:
    clc
    rts

; vq_hdr: start entry. t0=addr hi, t1=addr lo, A=count. X returns write idx.
vq_hdr:
    pha
    ldx vq_len
    lda t0
    sta vq,x
    inx
    lda t1
    sta vq,x
    inx
    pla
    sta vq,x
    inx
    rts
; after filling data at vq,x... call vq_end with X = new length
vq_end:
    stx vq_len
    rts

; ---------------------------------------------------------------- text -----
; draw_text: ptr0 -> $FF-terminated string, t0/t1 = PPU addr hi/lo.
; Writes via queue to BOTH nametables (mirrors to NT+$0400).
draw_text:
    ldy #0
: lda (ptr0),y
    cmp #$FF
    beq :+
    iny
    bne :-
:   tya                 ; length
    beq @done
    sta t2              ; len
    asl a
    clc
    adc #6
    jsr vq_room
    bcc @done
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
    ; second copy at addr ^ $0400
    lda t0
    eor #$04
    sta t0
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
    lda t0
    eor #$04
    sta t0
@done:
    rts

; write text immediately to PPU (rendering off), ptr0 string, t0/t1 addr
ppu_text:
    lda t0
    sta PPUADDR
    lda t1
    sta PPUADDR
    ldy #0
: lda (ptr0),y
    cmp #$FF
    beq :+
    sta PPUDATA
    iny
    bne :-
:   rts

; ---------------------------------------------------------------- includes -
.include "map.asm"
.include "ui.asm"
.include "sim.asm"
.include "sound.asm"

; ---------------------------------------------------------------- data -----
.segment "RODATA"

palettes:
    ; background: universal = grass green
    .byte $1A,$0A,$17,$2A   ; terrain: dk green, brown, lt green
    .byte $1A,$01,$11,$2C   ; water:   dk blue, blue, lt cyan
    .byte $1A,$0F,$10,$30   ; gray:    black, gray, white
    .byte $1A,$07,$16,$27   ; warm:    dk brown, red, yellow
    ; sprites
    .byte $1A,$0F,$16,$30   ; cursor: black shadow, red, white outline
    .byte $1A,$0F,$30,$28   ; bolt: yellow
    .byte $1A,$0F,$00,$2D   ; tornado grays
    .byte $1A,$0F,$16,$30   ; misc

.include "cellgfx.inc"

; ---------------------------------------------------------------- vectors --
.segment "VECTORS"
.word nmi
.word reset
.word irq

; ---------------------------------------------------------------- chr ------
.segment "CHARS"
.incbin "../chr.bin"
