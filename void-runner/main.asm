; ============================================================
; VOID RUNNER - NES ROM
; Vertical shoot-em-up with parallax stars, 4 enemy types,
; boss battles, power-ups, and 4-channel chiptune music.
; Mapper 0 (NROM), 32KB PRG, 8KB CHR
; ============================================================

.segment "HEADER"
    .byte $4E,$45,$53,$1A   ; "NES" + EOF marker
    .byte 2                  ; 2 x 16KB PRG-ROM banks
    .byte 1                  ; 1 x 8KB CHR-ROM bank
    .byte %00000001          ; Flags6: Mapper 0, vertical mirroring
    .byte %00000000          ; Flags7: Mapper 0
    .byte 0,0,0,0,0,0,0,0   ; Padding

; ============================================================
; ZERO PAGE VARIABLES
; ============================================================
.segment "ZEROPAGE"

player_x:      .res 1
player_y:      .res 1
player_lives:  .res 1
player_hp:     .res 1
player_power:  .res 1
player_bombs:  .res 1
player_fire_t: .res 1
player_animf:  .res 1
player_inv:    .res 1    ; invincibility timer

score_l:       .res 1
score_m:       .res 1
score_h:       .res 1
hi_l:          .res 1
hi_m:          .res 1
hi_h:          .res 1

wave:          .res 1
wave_timer:    .res 1
boss_hp:       .res 1
boss_x:        .res 1
boss_y:        .res 1
boss_phase:    .res 1
boss_timer:    .res 1
boss_active:   .res 1

frame_cnt:     .res 1
nmi_flag:      .res 1
game_state:    .res 1
pause_edge:    .res 1

scroll_y:      .res 1      ; Background scroll Y
scroll_spd:    .res 1      ; Scroll speed counter
star_x1:       .res 1      ; Layer 1 offset
star_x2:       .res 1      ; Layer 2 offset
star_x3:       .res 1      ; Layer 3 offset

spawn_timer:   .res 1
spawn_pat:     .res 1

temp0:         .res 1
temp1:         .res 1
temp2:         .res 1
oam_pos:       .res 1

; Enemy table (8 enemies x 8 fields = 64 bytes)
en_x:          .res 8
en_y:          .res 8
en_type:       .res 8
en_hp:         .res 8
en_timer:      .res 8
en_vx:         .res 8      ; signed velocity
en_vy:         .res 8
en_anim:       .res 8

; Player bullet table (12 bullets x 3 fields)
pb_x:          .res 12
pb_y:          .res 12
pb_act:        .res 12     ; active flag + type (0=off, 1=straight, 2=left, 3=right)

; Enemy bullet table (16 bullets x 4 fields)
eb_x:          .res 16
eb_y:          .res 16
eb_act:        .res 16
eb_vx:         .res 16     ; signed

; Music engine
mus_pos_p1:    .res 1
mus_pos_p2:    .res 1
mus_pos_tri:   .res 1
mus_pos_noi:   .res 1
mus_tim_p1:    .res 1
mus_tim_p2:    .res 1
mus_tim_tri:   .res 1
mus_tim_noi:   .res 1
mus_track:     .res 1

; SFX state
sfx_timer:     .res 1
sfx_type:      .res 1

; PPU update queue
ppu_upd:       .res 1      ; flag: BG needs update
score_dirty:   .res 1

; Screen flash effect
flash_timer:   .res 1

; Controller
joy1:          .res 1
joy1_prev:     .res 1
joy1_edge:     .res 1      ; newly pressed this frame

; ============================================================
; OAM BUFFER AT $0200
; ============================================================
.segment "OAM_SEG"
oam_buf:    .res 256

; ============================================================
; RAM VARIABLES
; ============================================================
.segment "BSS"
score_digits:  .res 7      ; BCD digits for display
lives_buf:     .res 4      ; lives display buffer

; ============================================================
; CONSTANTS
; ============================================================
STATE_TITLE    = 0
STATE_PLAY     = 1
STATE_PAUSE    = 2
STATE_GAMEOVER = 3
STATE_BOSS     = 4
STATE_WIN      = 5

PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTAT   = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
APUP1VOL  = $4000
APUP1SWP  = $4001
APUP1LO   = $4002
APUP1HI   = $4003
APUP2VOL  = $4004
APUP2SWP  = $4005
APUP2LO   = $4006
APUP2HI   = $4007
APUTVOL   = $4008
APUTLO    = $400A
APUTHI    = $400B
APUNVOL   = $400C
APUNPER   = $400E
APUNLEN   = $400F
APUSTAT   = $4015
APUFRAME  = $4017
JOY1      = $4016
JOY2      = $4017

; ============================================================
; BUTTON MASKS (standard NES controller read order)
; Read order: A, B, Sel, Start, Up, Down, Left, Right
; ============================================================
BTN_A      = %10000000
BTN_B      = %01000000
BTN_SEL    = %00100000
BTN_START  = %00010000
BTN_UP     = %00001000
BTN_DOWN   = %00000100
BTN_LEFT   = %00000010
BTN_RIGHT  = %00000001

; Sprite tile indices (in pattern table 1)
SPR_SHIP0  = $00    ; Player ship frame 0, top-left
SPR_SHIP2  = $04    ; Player ship frame 1, top-left
SPR_EN0    = $08    ; Enemy type 0
SPR_EN1    = $0A    ; Enemy type 1
SPR_EN2    = $0C    ; Enemy type 2
SPR_EN3    = $0E    ; Enemy type 3
SPR_PBL    = $10    ; Player bullet
SPR_EBL    = $11    ; Enemy bullet
SPR_EXP0   = $12    ; Explosion frame 0
SPR_EXP1   = $13
SPR_EXP2   = $14
SPR_BOSS0  = $15    ; Boss tile 0
SPR_BOSS1  = $16
SPR_BOSS2  = $17
SPR_BOSS3  = $18
SPR_PWR0   = $19    ; Weapon power-up
SPR_PWR1   = $1A    ; Bomb power-up
SPR_HUD0   = $1B    ; Sprite-0 trigger (HUD line)

; ============================================================
; CODE START
; ============================================================
.segment "CODE"

; ============================================================
; RESET HANDLER
; ============================================================
.proc RESET
    SEI
    CLD
    LDX #$40
    STX APUFRAME        ; Disable APU frame IRQ
    LDX #$FF
    TXS                 ; Init stack
    INX                 ; X = 0
    STX PPUCTRL         ; Disable NMI
    STX PPUMASK         ; Disable rendering
    STX APUP1VOL        ; Silence APU
    STX APUP2VOL
    STX APUTVOL
    STX APUNVOL

    ; First vblank wait
    BIT PPUSTAT
@wait1:
    BIT PPUSTAT
    BPL @wait1

    ; Clear all RAM $0000-$07FF
    TXA
@clr:
    STA $000,X
    STA $100,X
    STA $200,X
    STA $300,X
    STA $400,X
    STA $500,X
    STA $600,X
    STA $700,X
    INX
    BNE @clr

    ; Move all sprites off-screen
    LDA #$FF
    LDX #0
@oam:
    STA oam_buf,X
    INX
    BNE @oam

    ; Second vblank wait
    BIT PPUSTAT
@wait2:
    BIT PPUSTAT
    BPL @wait2

    ; Set APU to enable channels
    LDA #$0F
    STA APUSTAT

    ; Load palettes
    JSR load_palettes

    ; Load nametable 0 (title screen)
    JSR load_title_nt

    ; Init game data
    JSR init_game

    ; Enable PPU rendering
    LDA #%10001000      ; NMI on, BG pattbl=1 ($1000), Spr pattbl=0 ($0000)
    STA PPUCTRL
    LDA #%00011110      ; Show BG+sprites, no clipping
    STA PPUMASK

    ; Start main loop
    CLI
@loop:
    LDA nmi_flag
    BEQ @loop
    LDA #0
    STA nmi_flag

    LDA game_state
    CMP #STATE_TITLE
    BEQ @do_title
    CMP #STATE_PLAY
    BEQ @do_play
    CMP #STATE_PAUSE
    BEQ @do_pause
    CMP #STATE_GAMEOVER
    BEQ @do_gameover
    CMP #STATE_BOSS
    BEQ @do_boss
    JMP @loop

@do_title:
    JSR title_logic
    JMP @loop
@do_play:
    JSR play_logic
    JMP @loop
@do_pause:
    JSR pause_logic
    JMP @loop
@do_gameover:
    JSR gameover_logic
    JMP @loop
@do_boss:
    JSR boss_logic
    JMP @loop
.endproc

; ============================================================
; NMI HANDLER - runs every vblank (~60Hz)
; ============================================================
.proc NMI
    PHA
    TXA
    PHA
    TYA
    PHA

    ; OAM DMA - copy $0200 to PPU OAM
    LDA #0
    STA OAMADDR
    LDA #$02
    STA OAMDMA

    ; Score HUD update (during vblank, safe to write VRAM)
    LDA score_dirty
    BEQ @no_score_upd
    JSR update_score_hud
    LDA #0
    STA score_dirty
@no_score_upd:

    ; Apply scroll (MUST follow any PPUADDR writes)
    BIT PPUSTAT         ; Reset address latch
    LDA #0
    STA PPUSCROLL       ; X scroll = 0
    LDA scroll_y
    STA PPUSCROLL       ; Y scroll = scroll_y
    LDA #%10001000      ; NMI enable, sprites from $1000, BG from $0000
    STA PPUCTRL

    ; Run music engine
    JSR music_tick

    ; Run SFX
    JSR sfx_tick

    ; Flash effect: brighten palette
    LDA flash_timer
    BEQ @no_flash
    DEC flash_timer
    LDA flash_timer
    AND #$01
    BEQ @no_flash
    ; Write bright palette during flash
    JSR flash_palettes
@no_flash:

    ; Signal main loop
    INC frame_cnt
    LDA #1
    STA nmi_flag

    PLA
    TAY
    PLA
    TAX
    PLA
    RTI
.endproc

; ============================================================
; LOAD PALETTES
; ============================================================
.proc load_palettes
    LDA PPUSTAT
    LDA #$3F
    STA PPUADDR
    LDA #$00
    STA PPUADDR
    LDX #0
@loop:
    LDA palette_data,X
    STA PPUDATA
    INX
    CPX #32
    BNE @loop
    RTS
.endproc

; ============================================================
; FLASH PALETTES (screen flash for bomb)
; ============================================================
.proc flash_palettes
    LDA PPUSTAT
    LDA #$3F
    STA PPUADDR
    LDA #$00
    STA PPUADDR
    LDX #0
@loop:
    LDA #$30            ; White-ish
    STA PPUDATA
    INX
    CPX #32
    BNE @loop
    RTS
.endproc

; ============================================================
; INIT GAME
; ============================================================
.proc init_game
    ; Player init
    LDA #128
    STA player_x
    LDA #200
    STA player_y
    LDA #3
    STA player_lives
    LDA #5
    STA player_hp
    LDA #0
    STA player_power
    LDA #3
    STA player_bombs
    LDA #0
    STA player_fire_t
    STA player_animf
    STA player_inv

    ; Score
    LDA #0
    STA score_l
    STA score_m
    STA score_h

    ; Wave
    LDA #1
    STA wave
    LDA #200
    STA wave_timer

    ; Enemies
    LDX #7
@clr_en:
    LDA #0
    STA en_hp,X
    DEX
    BPL @clr_en

    ; Bullets
    LDX #11
@clr_pb:
    LDA #0
    STA pb_act,X
    DEX
    BPL @clr_pb

    LDX #15
@clr_eb:
    LDA #0
    STA eb_act,X
    DEX
    BPL @clr_eb

    ; Misc
    LDA #0
    STA boss_active
    STA spawn_timer
    STA spawn_pat
    STA scroll_y
    STA star_x1
    STA star_x2
    STA star_x3
    STA flash_timer
    STA pause_edge
    STA frame_cnt

    ; Music
    LDA #0
    STA mus_track
    JSR music_start

    LDA #STATE_TITLE
    STA game_state
    RTS
.endproc

; ============================================================
; LOAD TITLE NAMETABLE
; ============================================================
.proc load_title_nt
    ; Disable rendering so VRAM writes are safe at any time
    LDA #0
    STA PPUMASK
    ; Clear nametable 0
    LDA PPUSTAT
    LDA #$20
    STA PPUADDR
    LDA #$00
    STA PPUADDR
    LDA #0
    LDX #0
    LDY #4
@clr:
    STA PPUDATA
    INX
    BNE @clr
    DEY
    BNE @clr

    ; Set attribute table (all palette 0 for BG)
    LDA #$20
    STA PPUADDR
    LDA #$C0
    STA PPUADDR
    LDA #0
    LDX #64
@attr:
    STA PPUDATA
    DEX
    BNE @attr

    ; Write title text at row 8 col 9: "VOID RUNNER"
    ; Row 8, col 9: $2000 + 8*32 + 9 = $2000+$109 = $2109
    LDA PPUSTAT
    LDA #$21
    STA PPUADDR
    LDA #$09
    STA PPUADDR
    LDX #0
@title:
    LDA title_str,X
    BEQ @done_title
    STA PPUDATA
    INX
    BNE @title
@done_title:

    ; "PRESS START" at row 14 col 10
    ; offset = 14*32 + 10 = 448+10 = 458 = $01CA
    ; $2000 + $01CA = $21CA. High=$21, Low=$CA
    LDA PPUSTAT
    LDA #$21
    STA PPUADDR
    LDA #$CA
    STA PPUADDR
    LDX #0
@press:
    LDA press_str,X
    BEQ @done_press
    STA PPUDATA
    INX
    BNE @press
@done_press:

    ; "A=FIRE  B=BOMB" at row 16
    ; 16*32 = 512 = $200. $2200 + col 9 = $2209
    LDA PPUSTAT
    LDA #$22
    STA PPUADDR
    LDA #$09
    STA PPUADDR
    LDX #0
@ctrl:
    LDA ctrl_str,X
    BEQ @done_ctrl
    STA PPUDATA
    INX
    BNE @ctrl
@done_ctrl:

    ; "BY CLAUDE" at row 26 col 11
    ; 26*32=832=$340. +11=$34B. $2000+$34B=$234B
    LDA PPUSTAT
    LDA #$23
    STA PPUADDR
    LDA #$4B
    STA PPUADDR
    LDX #0
@by:
    LDA by_str,X
    BEQ @done_by
    STA PPUDATA
    INX
    BNE @by
@done_by:

    ; Place some star tiles for title background
    JSR scatter_stars_title

    ; Restore PPU state and re-enable rendering
    BIT PPUSTAT
    LDA #0
    STA PPUSCROLL
    STA PPUSCROLL
    LDA #%10001000
    STA PPUCTRL
    LDA #%00011110
    STA PPUMASK

    RTS
.endproc

; ============================================================
; SCATTER STARS ON TITLE SCREEN
; ============================================================
.proc scatter_stars_title
    LDX #0
@loop:
    LDA star_seed_lo,X
    STA temp0
    LDA star_seed_hi,X
    STA temp1
    ; Calc nametable address = $2000 + hi*256 + lo
    LDA PPUSTAT
    LDA temp1
    ORA #$20
    STA PPUADDR
    LDA temp0
    STA PPUADDR
    LDA star_tile_t,X   ; which star tile
    STA PPUDATA
    INX
    CPX #40
    BNE @loop
    RTS
.endproc

; ============================================================
; LOAD GAME NAMETABLE (background for play)
; ============================================================
.proc load_game_nt
    LDA #0
    STA PPUMASK         ; Disable rendering for safe VRAM access
    ; Clear nametable 0
    LDA PPUSTAT
    LDA #$20
    STA PPUADDR
    LDA #$00
    STA PPUADDR
    LDA #$00
    LDX #0
    LDY #4
@clr:
    STA PPUDATA
    INX
    BNE @clr
    DEY
    BNE @clr

    ; Draw HUD separator line at row 2
    ; Row 2: tiles $40-$5F all set to tile $06 (solid line)
    LDA PPUSTAT
    LDA #$20
    STA PPUADDR
    LDA #$40
    STA PPUADDR
    LDA #$06            ; HUD line tile
    LDX #32
@hud:
    STA PPUDATA
    DEX
    BNE @hud

    ; Score label at row 0, col 1
    LDA PPUSTAT
    LDA #$20
    STA PPUADDR
    LDA #$01
    STA PPUADDR
    LDA #$2C            ; 'S'
    STA PPUDATA
    LDA #$1C            ; 'C'
    STA PPUDATA
    LDA #$28            ; 'O'
    STA PPUDATA
    LDA #$2B            ; 'R'
    STA PPUDATA
    LDA #$1E            ; 'E'
    STA PPUDATA
    LDA #$35            ; ':'
    STA PPUDATA

    ; WAVE label at row 0, col 15
    LDA PPUSTAT
    LDA #$20
    STA PPUADDR
    LDA #$0F
    STA PPUADDR
    LDA #$30            ; 'W'
    STA PPUDATA
    LDA #$1A            ; 'A'
    STA PPUDATA
    LDA #$2F            ; 'V'
    STA PPUDATA
    LDA #$1E            ; 'E'
    STA PPUDATA

    ; LIVES label at row 0, col 21
    LDA PPUSTAT
    LDA #$20
    STA PPUADDR
    LDA #$15
    STA PPUADDR
    LDA #$25            ; 'L'
    STA PPUDATA
    LDA #$22            ; 'I'
    STA PPUDATA
    LDA #$2F            ; 'V'
    STA PPUDATA
    LDA #$1E            ; 'E'
    STA PPUDATA
    LDA #$2C            ; 'S'
    STA PPUDATA

    ; Place background stars in play area
    JSR scatter_stars_play

    ; Attribute table: row 0-1 = palette 2 (HUD color)
    LDA PPUSTAT
    LDA #$23
    STA PPUADDR
    LDA #$C0
    STA PPUADDR
    ; First 2 attribute rows = palette 2 for HUD
    ; Attribute byte covers 4x4 tile area. Row 0-1 = first attr row.
    ; 8 bytes for first row of attributes
    LDA #%10101010      ; Palette 2 everywhere in first attr row
    LDX #8
@attr_hud:
    STA PPUDATA
    DEX
    BNE @attr_hud

    ; Restore PPU state and re-enable rendering
    BIT PPUSTAT
    LDA #0
    STA PPUSCROLL
    STA PPUSCROLL
    LDA #%10001000
    STA PPUCTRL
    LDA #%00011110
    STA PPUMASK

    RTS
.endproc

; ============================================================
; SCATTER STARS IN PLAY AREA
; ============================================================
.proc scatter_stars_play
    LDX #0
@loop:
    LDA star_seed_lo,X
    STA temp0
    LDA star_seed_hi,X
    AND #$03
    CLC
    ADC #$20            ; Keep in nametable 0 play area
    STA temp1
    ; Skip HUD rows (first 2 rows = offset < $40)
    LDA temp0
    CMP #$40
    BCS @ok
    LDA #$40
    STA temp0
@ok:
    LDA PPUSTAT
    LDA temp1
    STA PPUADDR
    LDA temp0
    STA PPUADDR
    LDA star_tile_t,X
    STA PPUDATA
    INX
    CPX #40
    BNE @loop
    RTS
.endproc

; ============================================================
; TITLE LOGIC
; ============================================================
.proc title_logic
    JSR read_joy

    ; Check START
    LDA joy1_edge
    AND #BTN_START
    BEQ @no_start

    ; Start game
    LDA #0
    STA nmi_flag        ; Reset just in case
    JSR start_new_game
    RTS

@no_start:
    ; Animate title - scroll stars
    LDA frame_cnt
    AND #$07
    BNE @no_scroll
    INC scroll_y
@no_scroll:

    ; Draw animated ship on title (spin/bob)
    JSR render_title_sprites

    RTS
.endproc

; ============================================================
; START NEW GAME
; ============================================================
.proc start_new_game
    ; Reset player
    LDA #128
    STA player_x
    LDA #200
    STA player_y
    LDA #3
    STA player_lives
    LDA #5
    STA player_hp
    LDA #0
    STA player_power
    LDA #3
    STA player_bombs
    LDA #0
    STA player_fire_t
    STA player_inv

    ; Reset score (preserve hi-score)
    LDA #0
    STA score_l
    STA score_m
    STA score_h

    ; Wave 1
    LDA #1
    STA wave
    LDA #180
    STA wave_timer

    ; Clear all enemies/bullets
    LDX #7
@en:
    LDA #0
    STA en_hp,X
    DEX
    BPL @en
    LDX #11
@pb:
    LDA #0
    STA pb_act,X
    DEX
    BPL @pb
    LDX #15
@eb:
    LDA #0
    STA eb_act,X
    DEX
    BPL @eb

    LDA #0
    STA boss_active
    STA spawn_timer
    STA spawn_pat
    STA flash_timer
    LDA #0
    STA scroll_y

    ; Load game background
    JSR load_game_nt

    ; Request score HUD update (NMI will write during next vblank)
    LDA #1
    STA score_dirty

    ; Start gameplay music (track 1)
    LDA #1
    STA mus_track
    JSR music_start

    LDA #STATE_PLAY
    STA game_state
    RTS
.endproc

; ============================================================
; PLAY LOGIC (main game frame)
; ============================================================
.proc play_logic
    JSR read_joy

    ; Pause check
    LDA joy1_edge
    AND #BTN_START
    BEQ @no_pause
    LDA #STATE_PAUSE
    STA game_state
    RTS
@no_pause:

    JSR update_player
    JSR update_enemies
    JSR update_pbullets
    JSR update_ebullets
    JSR check_collisions
    JSR spawn_enemies
    JSR check_wave

    ; Scroll background
    LDA frame_cnt
    AND #$03
    BNE @no_scroll
    INC scroll_y
@no_scroll:

    ; Parallax star layers
    LDA frame_cnt
    AND #$07
    BNE @no_stars
    INC star_x1
    LDA frame_cnt
    AND #$0F
    BNE @no_s2
    INC star_x2
@no_s2:
    LDA frame_cnt
    AND #$1F
    BNE @no_stars
    INC star_x3
@no_stars:

    ; Invincibility decay
    LDA player_inv
    BEQ @no_inv
    DEC player_inv
@no_inv:

    ; Flash timer
    LDA flash_timer
    BEQ @no_flash
    DEC flash_timer
@no_flash:

    ; Render everything
    JSR render_play

    RTS
.endproc

; ============================================================
; UPDATE PLAYER
; ============================================================
.proc update_player
    ; --- Movement ---
    LDA joy1
    AND #BTN_UP
    BEQ @no_up
    LDA player_y
    SEC
    SBC #2
    CMP #24             ; Top limit (below HUD)
    BCC @no_up
    STA player_y
@no_up:

    LDA joy1
    AND #BTN_DOWN
    BEQ @no_down
    LDA player_y
    CLC
    ADC #2
    CMP #224            ; Bottom limit
    BCS @no_down
    STA player_y
@no_down:

    LDA joy1
    AND #BTN_LEFT
    BEQ @no_left
    LDA player_x
    SEC
    SBC #2
    CMP #8
    BCC @no_left
    STA player_x
@no_left:

    LDA joy1
    AND #BTN_RIGHT
    BEQ @no_right
    LDA player_x
    CLC
    ADC #2
    CMP #248
    BCS @no_right
    STA player_x
@no_right:

    ; --- Fire ---
    LDA player_fire_t
    BEQ @can_fire
    DEC player_fire_t
    JMP @no_fire
@can_fire:
    LDA joy1
    AND #BTN_A
    BEQ @no_fire
    JSR fire_player
    LDA #8              ; Cooldown
    LDA player_power
    BEQ @set_cooldown
    LDA #5              ; Faster with power
@set_cooldown:
    STA player_fire_t
@no_fire:

    ; --- Bomb ---
    LDA joy1_edge
    AND #BTN_B
    BEQ @no_bomb
    LDA player_bombs
    BEQ @no_bomb
    DEC player_bombs
    JSR use_bomb
@no_bomb:

    ; --- Animation ---
    LDA frame_cnt
    AND #$0F
    BNE @no_anim
    LDA player_animf
    EOR #1
    STA player_animf
@no_anim:

    RTS
.endproc

; ============================================================
; FIRE PLAYER BULLETS
; ============================================================
.proc fire_player
    ; Always fire center bullet
    LDX #0
@find0:
    LDA pb_act,X
    BEQ @found0
    INX
    CPX #12
    BNE @find0
    RTS
@found0:
    LDA player_x
    STA pb_x,X
    LDA player_y
    SEC
    SBC #10
    STA pb_y,X
    LDA #1              ; Straight up
    STA pb_act,X

    ; Power level 1+: spread shot
    LDA player_power
    BEQ @sfx
    INX
    CPX #12
    BCS @sfx
    LDA pb_act,X
    BNE @try_right
    LDA player_x
    SEC
    SBC #6
    STA pb_x,X
    LDA player_y
    SEC
    SBC #6
    STA pb_y,X
    LDA #2              ; Left diagonal
    STA pb_act,X
@try_right:
    INX
    CPX #12
    BCS @sfx
    LDA pb_act,X
    BNE @sfx
    LDA player_x
    CLC
    ADC #6
    STA pb_x,X
    LDA player_y
    SEC
    SBC #6
    STA pb_y,X
    LDA #3              ; Right diagonal
    STA pb_act,X

    ; Power level 2+: extra side shots
    LDA player_power
    CMP #2
    BCC @sfx
    ; TODO: homing bullet (simplified: add 2 more)

@sfx:
    ; Trigger shoot SFX
    LDA #1
    STA sfx_type
    LDA #4
    STA sfx_timer
    RTS
.endproc

; ============================================================
; UPDATE PLAYER BULLETS
; ============================================================
.proc update_pbullets
    LDX #0
@loop:
    LDA pb_act,X
    BEQ @next
    AND #$03
    CMP #1
    BEQ @straight
    CMP #2
    BEQ @left
    ; Right diagonal
    LDA pb_y,X
    SEC
    SBC #3
    STA pb_y,X
    LDA pb_x,X
    CLC
    ADC #2
    STA pb_x,X
    JMP @oob
@left:
    LDA pb_y,X
    SEC
    SBC #3
    STA pb_y,X
    LDA pb_x,X
    SEC
    SBC #2
    STA pb_x,X
    JMP @oob
@straight:
    LDA pb_y,X
    SEC
    SBC #5              ; Speed 5 pixels/frame
    STA pb_y,X
@oob:
    ; Off top of screen?
    LDA pb_y,X
    CMP #16
    BCS @next
    LDA #0
    STA pb_act,X
@next:
    INX
    CPX #12
    BNE @loop
    RTS
.endproc

; ============================================================
; UPDATE ENEMY BULLETS
; ============================================================
.proc update_ebullets
    LDX #0
@loop:
    LDA eb_act,X
    BEQ @next
    ; Move down
    LDA eb_y,X
    CLC
    ADC #3
    STA eb_y,X
    ; Move X (signed: $FF=$-1, $01=+1, $00=0)
    LDA eb_vx,X
    BEQ @skip_x
    CLC
    ADC eb_x,X
    STA eb_x,X
@skip_x:
    ; Off bottom?
    LDA eb_y,X
    CMP #240
    BCC @next
    LDA #0
    STA eb_act,X
@next:
    INX
    CPX #16
    BNE @loop
    RTS
.endproc

; ============================================================
; UPDATE ENEMIES
; ============================================================
.proc update_enemies
    LDX #0
@loop:
    LDA en_hp,X
    BNE @has_en
    JMP @next
@has_en:
    INC en_timer,X

    LDA en_type,X
    BEQ @type0
    CMP #1
    BEQ @type1
    CMP #2
    BEQ @type2
    ; Type 3: figure-8 (uses sine)
    LDA en_timer,X
    AND #$1F
    TAY
    LDA sine_tbl,Y
    ASL A               ; Carry = movement direction
    BCC @t3_left
    INC en_x,X
    JMP @t3_y
@t3_left:
    DEC en_x,X
@t3_y:
    LDA en_timer,X
    LSR A
    AND #$1F
    TAY
    LDA sine_tbl,Y
    ASL A
    BCC @t3_up
    INC en_y,X
    JMP @t3_fire
@t3_up:
    DEC en_y,X
@t3_fire:
    LDA en_timer,X
    AND #$3F
    BNE @done_move
    JSR enemy_fire_aimed
    JMP @done_move

@type0:
    ; Straight down, fires periodically
    INC en_y,X
    LDA en_timer,X
    AND #$3F
    BNE @done_move
    JSR enemy_fire_straight
    JMP @done_move

@type1:
    ; Sine wave horizontal
    LDA en_timer,X
    LSR A
    AND #$1F
    TAY
    LDA sine_tbl,Y
    ASL A
    BCC @t1_left
    INC en_x,X
    JMP @t1_vert
@t1_left:
    DEC en_x,X
@t1_vert:
    LDA en_y,X
    CLC
    ADC #1
    STA en_y,X
    LDA en_timer,X
    AND #$7F
    BNE @done_move
    JSR enemy_fire_aimed
    JMP @done_move

@type2:
    ; Hold then dive at player
    LDA en_timer,X
    CMP #80
    BCS @t2_dive
    ; Hover: bob up/down
    AND #$07
    CMP #4
    BCC @t2_bob_dn
    DEC en_y,X
    JMP @done_move
@t2_bob_dn:
    INC en_y,X
    JMP @done_move
@t2_dive:
    ; Dive toward player X
    LDA en_x,X
    CMP player_x
    BEQ @t2_down
    BCS @t2_left
    CLC
    ADC #2
    STA en_x,X
    JMP @t2_down
@t2_left:
    SEC
    SBC #2
    STA en_x,X
@t2_down:
    LDA en_y,X
    CLC
    ADC #3
    STA en_y,X
    ; Fire during dive
    LDA en_timer,X
    AND #$0F
    BNE @done_move
    JSR enemy_fire_aimed

@done_move:
    ; Clamp X 0-255 (wraps naturally)
    ; Off bottom?
    LDA en_y,X
    CMP #240
    BCC @next
    LDA #0
    STA en_hp,X

@next:
    INX
    CPX #8
    BEQ @ue_done
    JMP @loop
@ue_done:
    RTS
.endproc

; ============================================================
; ENEMY FIRE STRAIGHT DOWN
; ============================================================
; X = enemy index on entry, preserved
.proc enemy_fire_straight
    STX temp0
    LDX #0
@find:
    LDA eb_act,X
    BEQ @found
    INX
    CPX #16
    BNE @find
    LDX temp0
    RTS
@found:
    STX temp1
    LDX temp0
    LDA en_x,X
    LDY temp1
    STA eb_x,Y
    LDA en_y,X
    CLC
    ADC #8
    STA eb_y,Y
    LDA #0
    STA eb_vx,Y
    LDA #1
    STA eb_act,Y
    LDX temp0
    RTS
.endproc

; ============================================================
; ENEMY FIRE AIMED AT PLAYER
; ============================================================
.proc enemy_fire_aimed
    STX temp0
    LDX #0
@find:
    LDA eb_act,X
    BEQ @found
    INX
    CPX #16
    BNE @find
    LDX temp0
    RTS
@found:
    STX temp1
    LDX temp0
    LDA en_x,X
    LDY temp1
    STA eb_x,Y
    LDA en_y,X
    CLC
    ADC #8
    STA eb_y,Y
    ; X direction toward player
    LDA en_x,X
    CMP player_x
    BEQ @vx_zero
    BCS @vx_left
    LDA #1
    STA eb_vx,Y
    JMP @done_vx
@vx_left:
    LDA #$FF            ; -1
    STA eb_vx,Y
    JMP @done_vx
@vx_zero:
    LDA #0
    STA eb_vx,Y
@done_vx:
    LDA #1
    STA eb_act,Y
    LDX temp0
    RTS
.endproc

; ============================================================
; SPAWN ENEMIES
; ============================================================
.proc spawn_enemies
    LDA spawn_timer
    BEQ @do_spawn
    DEC spawn_timer
    RTS
@do_spawn:
    ; Timer based on wave (harder = faster)
    LDA #50
    SEC
    SBC wave
    STA temp0
    LDA temp0
    CMP #10
    BCS @ok_timer
    LDA #10
@ok_timer:
    STA spawn_timer

    ; Find free slot
    LDX #0
@find:
    LDA en_hp,X
    BEQ @found
    INX
    CPX #8
    BNE @find
    RTS
@found:
    ; Type = spawn_pat mod 4
    LDA spawn_pat
    AND #$03
    STA en_type,X
    INC spawn_pat

    ; Random-ish X based on frame_cnt + spawn_pat
    LDA frame_cnt
    EOR spawn_pat
    AND #$D0            ; Keep in center-ish range
    CLC
    ADC #24
    STA en_x,X

    LDA #8              ; Start just off top
    STA en_y,X
    LDA #0
    STA en_timer,X
    STA en_anim,X

    ; HP based on type and wave
    LDA en_type,X
    CLC
    ADC #2
    CLC
    ADC wave
    CMP #8
    BCC @ok_hp
    LDA #8
@ok_hp:
    STA en_hp,X

    RTS
.endproc

; ============================================================
; CHECK WAVE COMPLETION
; ============================================================
.proc check_wave
    DEC wave_timer
    BNE @not_done

    ; Count remaining enemies
    LDX #0
    LDA #0
    STA temp0
@count:
    LDA en_hp,X
    BEQ @skip
    INC temp0
@skip:
    INX
    CPX #8
    BNE @count

    LDA temp0
    BNE @not_done_reset ; Still enemies alive, give more time

    ; Wave complete!
    INC wave
    LDA wave
    ; Every 5 waves: boss
    AND #$04
    BNE @start_boss     ; bit 2 set = waves 4,5,6,7,12-15,...

    ; Normal next wave
    LDA #180
    STA wave_timer
    ; Clear all bullets
    LDX #11
@pb:
    LDA #0
    STA pb_act,X
    DEX
    BPL @pb
    LDX #15
@eb:
    LDA #0
    STA eb_act,X
    DEX
    BPL @eb
    RTS

@not_done_reset:
    LDA #30
    STA wave_timer
@not_done:
    RTS

@start_boss:
    JSR init_boss
    LDA #STATE_BOSS
    STA game_state
    RTS
.endproc

; ============================================================
; CHECK COLLISIONS
; ============================================================
.proc check_collisions
    ; Player bullets vs enemies
    LDX #0
@pb_loop:
    LDA pb_act,X
    BEQ @pb_next
    STX temp0

    LDY #0
@en_loop:
    LDA en_hp,Y
    BNE @en_alive
    JMP @en_next
@en_alive:
    STY temp1

    ; Distance check X
    LDA pb_x,X
    SEC
    SBC en_x,Y
    BCC @pb_neg_x
    CMP #12
    BCC @test_y
    JMP @en_next
@pb_neg_x:
    EOR #$FF
    CMP #12
    BCC @test_y
    JMP @en_next
@test_y:
    LDA pb_y,X
    SEC
    SBC en_y,Y
    BCC @pb_neg_y
    CMP #10
    BCC @pb_hit
    JMP @en_next
@pb_neg_y:
    EOR #$FF
    CMP #10
    BCC @pb_hit
    JMP @en_next

@pb_hit:
    ; Deactivate bullet
    LDA #0
    LDX temp0
    STA pb_act,X
    ; Damage enemy
    LDY temp1
    LDA en_hp,Y
    SEC
    SBC #1
    STA en_hp,Y
    BNE @not_killed

    ; Enemy killed
    JSR add_score_10
    LDA #1
    STA score_dirty
    ; SFX: explosion
    LDA #2
    STA sfx_type
    LDA #8
    STA sfx_timer
    JMP @pb_next

@not_killed:
    ; SFX: hit
    LDA #3
    STA sfx_type
    LDA #3
    STA sfx_timer

@pb_next:
    LDX temp0
    INX
    CPX #12
    BNE @pb_loop

    ; Enemy bullets vs player
    LDA player_inv
    BNE @skip_ep        ; Invincible, skip

    LDX #0
@eb_loop:
    LDA eb_act,X
    BEQ @eb_next

    ; Distance check X
    LDA eb_x,X
    SEC
    SBC player_x
    BCC @eb_neg_x
    CMP #12
    BCS @eb_next
    JMP @eb_test_y
@eb_neg_x:
    EOR #$FF
    CMP #12
    BCS @eb_next
@eb_test_y:
    LDA eb_y,X
    SEC
    SBC player_y
    BCC @eb_neg_y
    CMP #12
    BCS @eb_next
    JMP @eb_hit
@eb_neg_y:
    EOR #$FF
    CMP #12
    BCS @eb_next

@eb_hit:
    LDA #0
    STA eb_act,X
    ; Damage player
    DEC player_hp
    LDA #60
    STA player_inv
    ; SFX: player hit
    LDA #4
    STA sfx_type
    LDA #8
    STA sfx_timer

    LDA player_hp
    BNE @eb_next

    ; Player died
    DEC player_lives
    LDA #5
    STA player_hp
    LDA #120
    STA player_inv
    LDA #128
    STA player_x
    LDA #200
    STA player_y

    ; Check game over
    LDA player_lives
    BNE @eb_next
    LDA #STATE_GAMEOVER
    STA game_state
    ; Update hiscore
    JSR check_hiscore
    ; Start game over music (stop music)
    LDA #0
    STA APUSTAT
    LDA #$0F
    STA APUSTAT

@eb_next:
    INX
    CPX #16
    BNE @eb_loop

@skip_ep:
    RTS

@en_next:
    LDX temp0
    INY
    CPY #8
    BEQ @en_all_done
    JMP @en_loop
@en_all_done:
    JMP @pb_next
.endproc

; ============================================================
; ADD SCORE +10 (BCD-style)
; ============================================================
.proc add_score_10
    LDA score_l
    CLC
    ADC #10
    STA score_l
    LDA #0
    ADC score_m
    STA score_m
    LDA #0
    ADC score_h
    STA score_h
    RTS
.endproc

; ============================================================
; ADD SCORE +100
; ============================================================
.proc add_score_100
    LDA score_l
    CLC
    ADC #100
    STA score_l
    BCC @done
    INC score_m
    LDA score_m
    BNE @done
    INC score_h
@done:
    RTS
.endproc

; ============================================================
; CHECK HI-SCORE
; ============================================================
.proc check_hiscore
    LDA score_h
    CMP hi_h
    BCC @no
    BNE @yes
    LDA score_m
    CMP hi_m
    BCC @no
    BNE @yes
    LDA score_l
    CMP hi_l
    BCC @no
@yes:
    LDA score_l
    STA hi_l
    LDA score_m
    STA hi_m
    LDA score_h
    STA hi_h
@no:
    RTS
.endproc

; ============================================================
; USE BOMB
; ============================================================
.proc use_bomb
    ; Kill all enemies
    LDX #7
@en:
    LDA en_hp,X
    BEQ @skip_en
    LDA #0
    STA en_hp,X
    JSR add_score_10
    LDA #1
    STA score_dirty
@skip_en:
    DEX
    BPL @en

    ; Clear all enemy bullets
    LDX #15
@eb:
    LDA #0
    STA eb_act,X
    DEX
    BPL @eb

    ; Flash screen
    LDA #20
    STA flash_timer

    ; SFX: bomb
    LDA #5
    STA sfx_type
    LDA #20
    STA sfx_timer

    RTS
.endproc

; ============================================================
; INIT BOSS
; ============================================================
.proc init_boss
    LDA #124
    STA boss_x
    LDA #24
    STA boss_y
    LDA #30
    STA boss_hp
    LDA #0
    STA boss_phase
    STA boss_timer
    LDA #1
    STA boss_active

    ; Boss music (track 2)
    LDA #2
    STA mus_track
    JSR music_start

    ; Clear all enemies
    LDX #7
@en:
    LDA #0
    STA en_hp,X
    DEX
    BPL @en

    RTS
.endproc

; ============================================================
; BOSS LOGIC
; ============================================================
.proc boss_logic
    JSR read_joy

    LDA joy1_edge
    AND #BTN_START
    BEQ @no_pause
    LDA #STATE_PAUSE
    STA game_state
    RTS
@no_pause:

    JSR update_player
    JSR update_pbullets
    JSR update_ebullets

    ; Update boss movement
    LDA boss_active
    BNE @boss_alive
    JMP @no_boss
@boss_alive:

    INC boss_timer

    LDA boss_phase
    BEQ @phase0
    CMP #1
    BEQ @phase1
    ; Phase 2: enrage
    JMP @phase2

@phase0:
    ; Side to side, fire spread every 30 frames
    LDA boss_timer
    AND #$7F
    CMP #64
    BCS @p0_right
    LDA boss_x
    SEC
    SBC #1
    CMP #16
    BCC @p0_right
    STA boss_x
    JMP @p0_fire
@p0_right:
    LDA boss_x
    CLC
    ADC #1
    CMP #232
    BCS @p0_fire
    STA boss_x
@p0_fire:
    LDA boss_timer
    AND #$1F
    BNE @no_boss_fire
    JSR boss_fire_spread
    JMP @no_boss_fire

@phase1:
    ; Circular movement + circle shots
    LDA boss_timer
    AND #$3F
    TAY
    LDA sine_tbl,Y
    ASL A
    BCC @p1_left
    INC boss_x
    JMP @p1_y
@p1_left:
    DEC boss_x
@p1_y:
    LDA boss_timer
    LSR A
    AND #$3F
    TAY
    LDA sine_tbl,Y
    ASL A
    BCC @p1_up
    INC boss_y
    JMP @p1_fire
@p1_up:
    DEC boss_y
@p1_fire:
    LDA boss_timer
    AND #$0F
    BNE @no_boss_fire
    JSR boss_fire_circle
    JMP @no_boss_fire

@phase2:
    ; Fast side-to-side + rapid fire
    LDA boss_timer
    AND #$3F
    CMP #32
    BCS @p2_right
    LDA boss_x
    SEC
    SBC #2
    CMP #16
    BCC @p2_right
    STA boss_x
    JMP @p2_fire
@p2_right:
    LDA boss_x
    CLC
    ADC #2
    CMP #232
    BCS @p2_fire
    STA boss_x
@p2_fire:
    LDA boss_timer
    AND #$07
    BNE @no_boss_fire
    JSR boss_fire_spread
    JSR boss_fire_circle
@no_boss_fire:

    ; Transition phases
    LDA boss_phase
    BNE @check_p2
    LDA boss_hp
    CMP #20
    BCS @no_boss
    INC boss_phase
    JMP @no_boss
@check_p2:
    CMP #1
    BNE @no_boss
    LDA boss_hp
    CMP #10
    BCS @no_boss
    INC boss_phase      ; Phase 2: enrage

@no_boss:
    ; Check player bullets vs boss
    JSR check_boss_collision

    LDA boss_active
    BEQ @boss_died

    ; Check boss Y bounds
    LDA boss_y
    CMP #8
    BCS @no_boss2
    LDA #8
    STA boss_y
@no_boss2:
    CMP #80
    BCC @no_boss3
    LDA #80
    STA boss_y
@no_boss3:

    JSR check_collisions    ; Still check eb vs player
    JSR render_boss_screen
    RTS

@boss_died:
    ; Boss dead!
    JSR add_score_100
    JSR add_score_100
    JSR add_score_100
    LDA #1
    STA score_dirty
    LDA #30
    STA flash_timer
    ; SFX: boss death
    LDA #6
    STA sfx_type
    LDA #30
    STA sfx_timer
    ; Back to play, next wave
    LDA #1
    STA mus_track
    JSR music_start
    LDA #0
    STA boss_active
    LDA #180
    STA wave_timer
    LDA #STATE_PLAY
    STA game_state
    RTS
.endproc

; ============================================================
; BOSS FIRE SPREAD (5-way)
; ============================================================
.proc boss_fire_spread
    ; Find up to 5 bullet slots
    LDX #0
    LDY #0          ; Y = direction index
@loop:
    LDA eb_act,X
    BNE @try_next
    LDA boss_x
    STA eb_x,X
    LDA boss_y
    CLC
    ADC #16
    STA eb_y,X
    LDA spread_vx,Y
    STA eb_vx,X
    LDA #1
    STA eb_act,X
    INY
    CPY #5
    BEQ @done
@try_next:
    INX
    CPX #16
    BNE @loop
@done:
    RTS
.endproc

; ============================================================
; BOSS FIRE CIRCLE (8-way)
; ============================================================
.proc boss_fire_circle
    LDX #0
    LDY #0          ; direction
@loop:
    LDA eb_act,X
    BNE @try_next
    LDA boss_x
    STA eb_x,X
    LDA boss_y
    CLC
    ADC #8
    STA eb_y,X
    LDA circle_vx,Y
    STA eb_vx,X
    LDA #1
    STA eb_act,X
    INY
    CPY #8
    BEQ @done
@try_next:
    INX
    CPX #16
    BNE @loop
@done:
    RTS
.endproc

; ============================================================
; CHECK BOSS COLLISION (player bullets vs boss)
; ============================================================
.proc check_boss_collision
    LDA boss_active
    BEQ @done
    LDX #0
@loop:
    LDA pb_act,X
    BEQ @next
    ; Distance X
    LDA pb_x,X
    SEC
    SBC boss_x
    BCC @neg_x
    CMP #24
    BCS @next
    JMP @test_y
@neg_x:
    EOR #$FF
    CMP #24
    BCS @next
@test_y:
    LDA pb_y,X
    SEC
    SBC boss_y
    BCC @neg_y
    CMP #24
    BCS @next
    JMP @hit
@neg_y:
    EOR #$FF
    CMP #24
    BCS @next
@hit:
    LDA #0
    STA pb_act,X
    DEC boss_hp
    ; SFX: boss hit
    LDA #3
    STA sfx_type
    LDA #3
    STA sfx_timer
    LDA boss_hp
    BNE @next
    LDA #0
    STA boss_active
@next:
    INX
    CPX #12
    BNE @loop
@done:
    RTS
.endproc

; ============================================================
; PAUSE LOGIC
; ============================================================
.proc pause_logic
    JSR read_joy
    LDA joy1_edge
    AND #BTN_START
    BEQ @done
    ; Restore prev state
    LDA boss_active
    BNE @return_boss
    LDA #STATE_PLAY
    STA game_state
    RTS
@return_boss:
    LDA #STATE_BOSS
    STA game_state
@done:
    RTS
.endproc

; ============================================================
; GAMEOVER LOGIC
; ============================================================
.proc gameover_logic
    JSR read_joy
    LDA joy1_edge
    AND #(BTN_START | BTN_A)
    BEQ @done
    ; Return to title
    JSR init_game
    JSR load_title_nt
    LDA #0
    STA mus_track
    JSR music_start
@done:
    RTS
.endproc

; ============================================================
; UPDATE SCORE HUD (write to nametable)
; Must be called when rendering is off OR use PPU update queue
; We call this from NMI-safe context during forced vblank
; For simplicity: call only when PPUSTAT indicates vblank
; ============================================================
.proc update_score_hud
    ; Convert score to decimal digits
    ; score_h, score_m, score_l -> 6 BCD digits
    ; Simple: score is binary 24-bit, max ~16M
    ; Display as 6 hex digits for simplicity (0-9, A-F)
    ; Row 0, col 7: 6 digit score
    LDA PPUSTAT
    LDA #$20
    STA PPUADDR
    LDA #$07
    STA PPUADDR
    ; Write hex representation
    LDA score_h
    JSR write_byte_hex
    LDA score_m
    JSR write_byte_hex
    LDA score_l
    JSR write_byte_hex

    ; Wave number at row 0, col 19
    LDA PPUSTAT
    LDA #$20
    STA PPUADDR
    LDA #$13
    STA PPUADDR
    LDA wave
    JSR write_byte_hex

    ; Lives at row 0, col 26
    LDA PPUSTAT
    LDA #$20
    STA PPUADDR
    LDA #$1A
    STA PPUADDR
    LDA player_lives
    JSR write_byte_hex

    RTS
.endproc

; Write byte A as 2 hex digits to PPU (A preserved)
.proc write_byte_hex
    PHA
    LSR A
    LSR A
    LSR A
    LSR A
    AND #$0F
    CLC
    ADC #$10            ; Tile $10 = '0', $19 = '9', $1A = 'A'...
    CMP #$1A
    BCC @ok1
    CLC
    ADC #6              ; Map A-F to correct tile offset
@ok1:
    STA PPUDATA
    PLA
    AND #$0F
    CLC
    ADC #$10
    CMP #$1A
    BCC @ok2
    CLC
    ADC #6
@ok2:
    STA PPUDATA
    RTS
.endproc

; ============================================================
; RENDER PLAY SCREEN
; ============================================================
.proc render_play
    LDA #0
    STA oam_pos

    ; Sprite 0: HUD trigger line (always at Y=15, X=0, tile=SPR_HUD0)
    LDX oam_pos
    LDA #15
    STA oam_buf,X
    INX
    LDA #SPR_HUD0
    STA oam_buf,X
    INX
    LDA #$02            ; Palette 2
    STA oam_buf,X
    INX
    LDA #0
    STA oam_buf,X
    INX
    STX oam_pos

    JSR render_player_spr
    JSR render_enemies_spr
    JSR render_pbullets_spr
    JSR render_ebullets_spr

    ; Clear remaining OAM
    LDX oam_pos
    LDA #$F0
@clr:
    CPX #$FC
    BCS @done
    STA oam_buf,X
    INX
    INX
    INX
    INX
    JMP @clr
@done:
    RTS
.endproc

; ============================================================
; RENDER BOSS SCREEN
; ============================================================
.proc render_boss_screen
    LDA #0
    STA oam_pos

    ; Sprite 0
    LDX oam_pos
    LDA #15
    STA oam_buf,X
    INX
    LDA #SPR_HUD0
    STA oam_buf,X
    INX
    LDA #$02
    STA oam_buf,X
    INX
    LDA #0
    STA oam_buf,X
    INX
    STX oam_pos

    JSR render_player_spr
    JSR render_boss_spr
    JSR render_pbullets_spr
    JSR render_ebullets_spr

    ; Clear remaining OAM
    LDX oam_pos
    LDA #$F0
@clr:
    CPX #$FC
    BCS @done
    STA oam_buf,X
    INX
    INX
    INX
    INX
    JMP @clr
@done:
    RTS
.endproc

; ============================================================
; RENDER PLAYER SPRITE
; ============================================================
.proc render_player_spr
    ; Blink when invincible
    LDA player_inv
    BEQ @no_blink
    AND #$04
    BNE @skip
@no_blink:
    LDX oam_pos

    ; Player is 2x2 sprite (16x16)
    ; Tile based on animation frame
    LDA player_animf
    ASL A
    ASL A              ; *4 for tile offset (0 or 4)
    STA temp0

    ; Top-left tile
    LDA player_y
    SEC
    SBC #8
    STA oam_buf,X       ; Y
    INX
    LDA temp0           ; Tile = SPR_SHIP0 + animframe*4
    STA oam_buf,X       ; Tile
    INX
    LDA #$00            ; Attr: pal 0, no flip
    STA oam_buf,X
    INX
    LDA player_x
    SEC
    SBC #8
    STA oam_buf,X       ; X
    INX

    ; Top-right tile (h-flipped)
    LDA player_y
    SEC
    SBC #8
    STA oam_buf,X
    INX
    LDA temp0
    CLC
    ADC #1
    STA oam_buf,X
    INX
    LDA #$40            ; H-flip
    STA oam_buf,X
    INX
    LDA player_x
    STA oam_buf,X
    INX

    ; Bottom-left tile
    LDA player_y
    STA oam_buf,X
    INX
    LDA temp0
    CLC
    ADC #2
    STA oam_buf,X
    INX
    LDA #$00
    STA oam_buf,X
    INX
    LDA player_x
    SEC
    SBC #8
    STA oam_buf,X
    INX

    ; Bottom-right tile (h-flipped)
    LDA player_y
    STA oam_buf,X
    INX
    LDA temp0
    CLC
    ADC #3
    STA oam_buf,X
    INX
    LDA #$40
    STA oam_buf,X
    INX
    LDA player_x
    STA oam_buf,X
    INX

    STX oam_pos
@skip:
    RTS
.endproc

; ============================================================
; RENDER ENEMIES SPRITES
; ============================================================
.proc render_enemies_spr
    LDY #0
@loop:
    LDA en_hp,Y
    BEQ @next
    LDX oam_pos

    ; Y pos
    LDA en_y,Y
    STA oam_buf,X
    INX

    ; Tile based on type, animated
    LDA en_type,Y
    ASL A               ; *2 for 2 tiles per type
    CLC
    ADC #SPR_EN0
    ; Add animation frame (bit 3 of anim counter)
    LDA en_anim,Y
    AND #$08
    LSR A
    LSR A
    LSR A               ; = 0 or 1
    STA temp0
    LDA en_type,Y
    ASL A
    CLC
    ADC #SPR_EN0
    CLC
    ADC temp0
    STA oam_buf,X
    INX

    LDA #$01            ; Palette 1 (enemy green)
    STA oam_buf,X
    INX

    LDA en_x,Y
    STA oam_buf,X
    INX

    STX oam_pos
    LDA en_anim,Y
    CLC
    ADC #1
    STA en_anim,Y

@next:
    INY
    CPY #8
    BNE @loop
    RTS
.endproc

; ============================================================
; RENDER PLAYER BULLETS
; ============================================================
.proc render_pbullets_spr
    LDY #0
@loop:
    LDA pb_act,Y
    BEQ @next
    LDX oam_pos

    LDA pb_y,Y
    STA oam_buf,X
    INX
    LDA #SPR_PBL
    STA oam_buf,X
    INX
    LDA #$02            ; Palette 2 (yellow/white)
    STA oam_buf,X
    INX
    LDA pb_x,Y
    STA oam_buf,X
    INX

    STX oam_pos
@next:
    INY
    CPY #12
    BNE @loop
    RTS
.endproc

; ============================================================
; RENDER ENEMY BULLETS
; ============================================================
.proc render_ebullets_spr
    LDY #0
@loop:
    LDA eb_act,Y
    BEQ @next
    LDX oam_pos

    LDA eb_y,Y
    STA oam_buf,X
    INX
    LDA #SPR_EBL
    STA oam_buf,X
    INX
    LDA #$03            ; Palette 3 (red/orange)
    STA oam_buf,X
    INX
    LDA eb_x,Y
    STA oam_buf,X
    INX

    STX oam_pos
@next:
    INY
    CPY #16
    BNE @loop
    RTS
.endproc

; ============================================================
; RENDER BOSS SPRITE (4 tiles, 2x2)
; ============================================================
.proc render_boss_spr
    LDX oam_pos

    ; Flash when damaged (every other 4 frames)
    LDA boss_timer
    AND #$04
    BEQ @no_boss_flash
    LDA flash_timer
    BEQ @no_boss_flash
    JMP @skip_boss
@no_boss_flash:

    ; Top-left
    LDA boss_y
    STA oam_buf,X
    INX
    LDA #SPR_BOSS0
    STA oam_buf,X
    INX
    LDA #$01
    STA oam_buf,X
    INX
    LDA boss_x
    SEC
    SBC #8
    STA oam_buf,X
    INX

    ; Top-right
    LDA boss_y
    STA oam_buf,X
    INX
    LDA #SPR_BOSS1
    STA oam_buf,X
    INX
    LDA #$01
    STA oam_buf,X
    INX
    LDA boss_x
    CLC
    ADC #8
    STA oam_buf,X
    INX

    ; Bottom-left
    LDA boss_y
    CLC
    ADC #8
    STA oam_buf,X
    INX
    LDA #SPR_BOSS2
    STA oam_buf,X
    INX
    LDA #$01
    STA oam_buf,X
    INX
    LDA boss_x
    SEC
    SBC #8
    STA oam_buf,X
    INX

    ; Bottom-right
    LDA boss_y
    CLC
    ADC #8
    STA oam_buf,X
    INX
    LDA #SPR_BOSS3
    STA oam_buf,X
    INX
    LDA #$01
    STA oam_buf,X
    INX
    LDA boss_x
    CLC
    ADC #8
    STA oam_buf,X
    INX

    STX oam_pos
@skip_boss:
    RTS
.endproc

; ============================================================
; RENDER TITLE SPRITES (animated ship)
; ============================================================
.proc render_title_sprites
    LDA #0
    STA oam_pos

    ; Animated ship bobbing up and down
    LDX oam_pos
    LDA frame_cnt
    AND #$1F
    CMP #16
    BCS @bob_down
    LDA #108
    JMP @set_y
@bob_down:
    LDA #112
@set_y:
    STA oam_buf,X
    INX
    LDA #SPR_SHIP0
    STA oam_buf,X
    INX
    LDA #$00
    STA oam_buf,X
    INX
    LDA #116
    STA oam_buf,X
    INX
    STX oam_pos

    ; Clear rest
    LDX oam_pos
    LDA #$F0
@clr:
    CPX #$FC
    BCS @done
    STA oam_buf,X
    INX
    INX
    INX
    INX
    JMP @clr
@done:
    RTS
.endproc

; ============================================================
; READ JOYSTICK 1
; ============================================================
.proc read_joy
    ; Save previous state
    LDA joy1
    STA joy1_prev

    ; Strobe
    LDA #1
    STA JOY1
    LDA #0
    STA JOY1

    ; Read 8 bits (A,B,Sel,Start,Up,Down,Left,Right)
    LDX #8
    LDA #0
    STA joy1
@loop:
    LDA JOY1
    LSR A
    ROL joy1
    DEX
    BNE @loop

    ; Compute edge (newly pressed this frame)
    LDA joy1
    AND joy1_prev
    EOR joy1
    AND joy1            ; = bits set now but not before
    STA joy1_edge

    RTS
.endproc

; ============================================================
; MUSIC ENGINE
; ============================================================
; Tracks: 0=Title, 1=Play, 2=Boss
; Note byte encoding: hi nibble = duration (ticks), lo nibble = note idx
; Note index 15 = rest, 14 = silence/stop

.proc music_start
    LDA mus_track
    ASL A
    ASL A
    TAX
    LDA track_tbl,X
    STA mus_pos_p1
    LDA track_tbl+1,X
    STA mus_pos_p2
    LDA track_tbl+2,X
    STA mus_pos_tri
    LDA track_tbl+3,X
    STA mus_pos_noi
    LDA #0
    STA mus_tim_p1
    STA mus_tim_p2
    STA mus_tim_tri
    STA mus_tim_noi
    RTS
.endproc

.proc music_tick
    ; Tick each channel
    JSR tick_p1
    JSR tick_p2
    JSR tick_tri
    JSR tick_noi
    RTS
.endproc

.proc tick_p1
    LDA mus_tim_p1
    BEQ @play
    DEC mus_tim_p1
    RTS
@play:
    JSR get_p1_note
    CMP #$FF
    BNE @not_end
    LDA #0
    STA mus_pos_p1
    JSR get_p1_note
@not_end:
    INC mus_pos_p1
    ; Decode: hi nibble = duration, lo = note
    PHA
    AND #$F0
    LSR A
    LSR A
    LSR A
    LSR A
    BEQ @min_dur
    STA mus_tim_p1
    JMP @dur_ok
@min_dur:
    LDA #1
    STA mus_tim_p1
@dur_ok:
    PLA
    AND #$0F
    CMP #$0F
    BEQ @rest
    TAX
    LDA note_lo,X
    STA APUP1LO
    LDA note_hi,X
    STA APUP1HI
    LDA #$8F            ; Duty 2 (50%), vol 15
    STA APUP1VOL
    RTS
@rest:
    LDA #$00
    STA APUP1VOL
    RTS
.endproc

.proc get_p1_note
    LDA mus_track
    BEQ @t0
    CMP #1
    BEQ @t1
    ; Track 2: boss
    LDY mus_pos_p1
    LDA mus_boss_p1,Y
    RTS
@t0:
    LDY mus_pos_p1
    LDA mus_title_p1,Y
    RTS
@t1:
    LDY mus_pos_p1
    LDA mus_play_p1,Y
    RTS
.endproc

.proc tick_p2
    LDA mus_tim_p2
    BEQ @play
    DEC mus_tim_p2
    RTS
@play:
    JSR get_p2_note
    CMP #$FF
    BNE @not_end
    LDA #0
    STA mus_pos_p2
    JSR get_p2_note
@not_end:
    INC mus_pos_p2
    PHA
    AND #$F0
    LSR A
    LSR A
    LSR A
    LSR A
    BEQ @min_dur
    STA mus_tim_p2
    JMP @dur_ok
@min_dur:
    LDA #1
    STA mus_tim_p2
@dur_ok:
    PLA
    AND #$0F
    CMP #$0F
    BEQ @rest
    TAX
    LDA note_lo,X
    STA APUP2LO
    LDA note_hi,X
    STA APUP2HI
    LDA #$4F            ; Duty 1 (25%), vol 15
    STA APUP2VOL
    RTS
@rest:
    LDA #$00
    STA APUP2VOL
    RTS
.endproc

.proc get_p2_note
    LDA mus_track
    BEQ @t0
    CMP #1
    BEQ @t1
    LDY mus_pos_p2
    LDA mus_boss_p2,Y
    RTS
@t0:
    LDY mus_pos_p2
    LDA mus_title_p2,Y
    RTS
@t1:
    LDY mus_pos_p2
    LDA mus_play_p2,Y
    RTS
.endproc

.proc tick_tri
    LDA mus_tim_tri
    BEQ @play
    DEC mus_tim_tri
    RTS
@play:
    JSR get_tri_note
    CMP #$FF
    BNE @not_end
    LDA #0
    STA mus_pos_tri
    JSR get_tri_note
@not_end:
    INC mus_pos_tri
    PHA
    AND #$F0
    LSR A
    LSR A
    LSR A
    LSR A
    BEQ @min_dur
    STA mus_tim_tri
    JMP @dur_ok
@min_dur:
    LDA #1
    STA mus_tim_tri
@dur_ok:
    PLA
    AND #$0F
    CMP #$0F
    BEQ @rest
    TAX
    ; Triangle plays one octave lower (doubled period)
    LDA note_lo,X
    STA APUTLO
    LDA note_hi,X
    STA APUTHI
    LDA #$FF            ; Max linear counter
    STA APUTVOL
    RTS
@rest:
    LDA #$00
    STA APUTVOL
    RTS
.endproc

.proc get_tri_note
    LDA mus_track
    BEQ @t0
    CMP #1
    BEQ @t1
    LDY mus_pos_tri
    LDA mus_boss_tri,Y
    RTS
@t0:
    LDY mus_pos_tri
    LDA mus_title_tri,Y
    RTS
@t1:
    LDY mus_pos_tri
    LDA mus_play_tri,Y
    RTS
.endproc

.proc tick_noi
    LDA mus_tim_noi
    BEQ @play
    DEC mus_tim_noi
    RTS
@play:
    JSR get_noi_note
    CMP #$FF
    BNE @not_end
    LDA #0
    STA mus_pos_noi
    JSR get_noi_note
@not_end:
    INC mus_pos_noi
    PHA
    AND #$F0
    LSR A
    LSR A
    LSR A
    LSR A
    BEQ @min_dur
    STA mus_tim_noi
    JMP @dur_ok
@min_dur:
    LDA #1
    STA mus_tim_noi
@dur_ok:
    PLA
    AND #$0F
    CMP #$0F
    BEQ @rest
    AND #$0F
    STA APUNPER         ; Noise period
    LDA #$0F
    STA APUNVOL
    RTS
@rest:
    LDA #$00
    STA APUNVOL
    RTS
.endproc

.proc get_noi_note
    LDA mus_track
    BEQ @t0
    CMP #1
    BEQ @t1
    LDY mus_pos_noi
    LDA mus_boss_noi,Y
    RTS
@t0:
    LDY mus_pos_noi
    LDA mus_title_noi,Y
    RTS
@t1:
    LDY mus_pos_noi
    LDA mus_play_noi,Y
    RTS
.endproc

; ============================================================
; SFX ENGINE
; ============================================================
; sfx_type: 1=shoot, 2=explosion, 3=hit, 4=player_hit, 5=bomb, 6=boss_death
.proc sfx_tick
    LDA sfx_timer
    BNE @active
    RTS
@active:
    DEC sfx_timer
    LDA sfx_timer
    BNE @run
    RTS
@run:

    LDA sfx_type
    CMP #1
    BEQ @shoot
    CMP #2
    BEQ @explode
    CMP #3
    BEQ @hit
    CMP #4
    BEQ @phit
    CMP #5
    BEQ @bomb
    CMP #6
    BEQ @boss_death
    RTS

@shoot:
    ; Quick high blip
    LDA sfx_timer
    ASL A
    ASL A
    ORA #$06
    STA APUP1HI
    LDA #$FF
    STA APUP1LO
    LDA #$9F
    STA APUP1VOL
    RTS

@explode:
    ; Noise burst
    LDA sfx_timer
    AND #$0F
    STA APUNPER
    LDA #$1F
    STA APUNVOL
    RTS

@hit:
    ; Short click
    LDA #$06
    STA APUNPER
    LDA #$0A
    STA APUNVOL
    RTS

@phit:
    ; Low buzz
    LDA #$AF
    STA APUP1LO
    LDA #$00
    STA APUP1HI
    LDA #$8F
    STA APUP1VOL
    RTS

@bomb:
    ; Big noise sweep
    LDA sfx_timer
    STA APUNPER
    LDA #$1F
    STA APUNVOL
    ; Triangle note too
    LDA #$80
    STA APUTLO
    LDA #$01
    STA APUTHI
    LDA #$FF
    STA APUTVOL
    RTS

@boss_death:
    ; Cascading noise + pitch drop
    LDA sfx_timer
    LSR A
    STA APUNPER
    LDA #$1F
    STA APUNVOL
    LDA sfx_timer
    ASL A
    STA APUP1LO
    LDA #$8F
    STA APUP1VOL
    RTS
.endproc

; ============================================================
; READ-ONLY DATA
; ============================================================
.segment "RODATA"

; ============================================================
; PALETTES
; ============================================================
palette_data:
    ; Background palettes
    .byte $0F,$02,$12,$22   ; Pal 0: Black, dark blue, blue, light blue (space)
    .byte $0F,$04,$14,$24   ; Pal 1: Black, dark purple, purple, light purple (nebula)
    .byte $0F,$00,$10,$30   ; Pal 2: Black, dark gray, gray, white (HUD)
    .byte $0F,$06,$16,$27   ; Pal 3: Black, dark red, red, orange (danger)
    ; Sprite palettes
    .byte $0F,$2C,$30,$28   ; SPal 0: Black, cyan, white, yellow (player)
    .byte $0F,$09,$1A,$2A   ; SPal 1: Black, dark green, green, light green (enemies)
    .byte $0F,$17,$27,$30   ; SPal 2: Black, orange, yellow, white (player bullets)
    .byte $0F,$06,$16,$27   ; SPal 3: Black, red, orange, yellow (enemy bullets)

; ============================================================
; SINE TABLE (32 entries, 0-255 unsigned)
; ============================================================
sine_tbl:
    .byte 128,153,176,197,214,226,235,240
    .byte 242,240,235,226,214,197,176,153
    .byte 128,103, 80, 59, 42, 30, 21, 16
    .byte  14, 16, 21, 30, 42, 59, 80,103

; ============================================================
; NOTE TABLE (APU period values, NTSC)
; Index: 0=C3 1=D3 2=E3 3=F3 4=G3 5=A3 6=B3
;        7=C4 8=D4 9=E4 A=F4 B=G4 C=A4 D=B4 E=C5 F=rest
; ============================================================
note_lo:
    .byte $AB,$7A,$D3,$09,$F5,$87,$2A,$D5   ; C3-B3
    .byte $6A,$E9,$69,$04,$FA,$43,$15,$00   ; C4-B4 + rest

note_hi:
    .byte $01,$01,$00,$01,$00,$00,$00,$00   ; C3-B3 hi
    .byte $00,$00,$00,$01,$00,$00,$00,$00   ; C4-B4 hi

; ============================================================
; MUSIC TRACK TABLE
; 4 bytes per track: pos_p1, pos_p2, pos_tri, pos_noi
; (offsets into their respective sequence arrays)
; ============================================================
track_tbl:
    .byte 0,0,0,0       ; Track 0: Title
    .byte 0,0,0,0       ; Track 1: Play
    .byte 0,0,0,0       ; Track 2: Boss

; ============================================================
; TITLE MUSIC
; Format: $XY where X=duration(frames/4), Y=note_index
; Duration 0 = 2 frames, 1=4, 2=8, 4=16, 8=32
; Note 0=C3...7=C4...E=C5, F=rest
; ============================================================
mus_title_p1:
    ; Melody: floating, ambient
    .byte $27,$29,$27,$2B,$27,$2E,$27,$2E   ; C D C E C rest C rest
    .byte $47,$4B,$49,$2E,$47,$2E,$2E,$2E   ; C4 E4 D4 rest C4 rest...
    .byte $27,$29,$2B,$2D,$4C,$2E,$2E,$2E   ; C D E G A4 rests
    .byte $FF

mus_title_p2:
    ; Harmony a 3rd below
    .byte $25,$27,$25,$29,$25,$2E,$25,$2E
    .byte $45,$49,$47,$2E,$45,$2E,$2E,$2E
    .byte $25,$27,$29,$2B,$4A,$2E,$2E,$2E
    .byte $FF

mus_title_tri:
    ; Bass
    .byte $40,$40,$40,$42,$40,$40,$44,$2E
    .byte $40,$44,$42,$2E,$40,$2E,$2E,$2E
    .byte $FF

mus_title_noi:
    ; Soft percussion
    .byte $10,$1F,$10,$1F,$10,$1F,$10,$1F
    .byte $20,$1F,$20,$1F,$20,$1F,$20,$1F
    .byte $FF

; ============================================================
; GAMEPLAY MUSIC
; ============================================================
mus_play_p1:
    ; Energetic melody
    .byte $17,$19,$17,$19,$1B,$19,$17,$1E
    .byte $1E,$1C,$1E,$27,$29,$2B,$27,$1E
    .byte $27,$29,$2B,$2E,$2B,$29,$27,$1E
    .byte $19,$1B,$19,$17,$14,$15,$17,$1E
    .byte $FF

mus_play_p2:
    ; Harmony / countermelody
    .byte $15,$17,$15,$17,$19,$17,$15,$1E
    .byte $1E,$1A,$1E,$25,$27,$29,$25,$1E
    .byte $25,$27,$29,$2E,$29,$27,$25,$1E
    .byte $17,$19,$17,$15,$12,$13,$15,$1E
    .byte $FF

mus_play_tri:
    ; Bass line
    .byte $10,$10,$14,$10,$10,$14,$10,$12
    .byte $10,$12,$10,$10,$14,$10,$10,$12
    .byte $FF

mus_play_noi:
    ; Drum pattern: kick-snare-kick-kick-snare
    .byte $10,$1F,$20,$10,$1F,$10,$10,$1F
    .byte $10,$1F,$20,$10,$1F,$10,$20,$1F
    .byte $FF

; ============================================================
; BOSS MUSIC
; ============================================================
mus_boss_p1:
    ; Intense, minor key
    .byte $17,$19,$17,$16,$17,$19,$1B,$1E
    .byte $1C,$1E,$1C,$1B,$19,$18,$17,$1E
    .byte $27,$28,$27,$26,$27,$28,$2A,$1E
    .byte $2B,$2A,$29,$27,$26,$25,$27,$1E
    .byte $FF

mus_boss_p2:
    ; Tension layer
    .byte $15,$17,$15,$14,$15,$17,$19,$1E
    .byte $1A,$1C,$1A,$19,$17,$16,$15,$1E
    .byte $25,$26,$25,$24,$25,$26,$28,$1E
    .byte $29,$28,$27,$25,$24,$23,$25,$1E
    .byte $FF

mus_boss_tri:
    ; Heavy bass
    .byte $10,$12,$10,$12,$10,$12,$14,$10
    .byte $10,$14,$12,$10,$12,$14,$10,$1E
    .byte $FF

mus_boss_noi:
    ; Fast drums
    .byte $10,$1F,$10,$1F,$10,$1F,$20,$1F
    .byte $10,$1F,$10,$10,$1F,$10,$10,$1F
    .byte $FF

; ============================================================
; BOSS FIRE PATTERNS
; ============================================================
spread_vx:
    .byte $FE,$FF,$00,$01,$02    ; -2,-1,0,+1,+2

circle_vx:
    .byte $00,$02,$02,$02,$00,$FE,$FE,$FE    ; 8 directions X

; ============================================================
; TITLE SCREEN STRINGS (tile indices)
; ============================================================
; Tile mapping: $00=blank, $0A='A'...$23='Z', $00+digit
; Let me define: $10='0' $11='1'...$19='9'
;                $1A='A' $1B='B'...$33='Z'
;                $34=' ' (space)
;                $35=':' $36='!' $37='.'

; Tile map: A=$1A B=$1B C=$1C D=$1D E=$1E F=$1F G=$20 H=$21 I=$22 J=$23
;           K=$24 L=$25 M=$26 N=$27 O=$28 P=$29 Q=$2A R=$2B S=$2C T=$2D
;           U=$2E V=$2F W=$30 X=$31 Y=$32 Z=$33 space=$34 :=$35
;           0=$10 1=$11 ... 9=$19

; "VOID RUNNER"
title_str:
    .byte $2F,$28,$22,$1D,$34,$2B,$2E,$27,$27,$1E,$2B   ; V O I D _ R U N N E R
    .byte 0

; "PRESS START"
press_str:
    .byte $29,$2B,$1E,$2C,$2C,$34,$2C,$2D,$1A,$2B,$2D   ; P R E S S _ S T A R T
    .byte 0

; "A:FIRE  B:BOMB"
ctrl_str:
    .byte $1A,$35,$1F,$22,$2B,$1E,$34,$34,$1B,$35,$1B,$28,$26,$1B   ; A:FIRE  B:BOMB
    .byte 0

; "BY CLAUDE"
by_str:
    .byte $1B,$32,$34,$1C,$25,$1A,$2E,$1D,$1E   ; B Y _ C L A U D E
    .byte 0

; ============================================================
; STAR BACKGROUND DATA
; ============================================================
; 40 star positions: lo byte (col offset), hi byte (page in nt)
star_seed_lo:
    .byte $12,$4A,$7E,$B3,$C8,$02,$35,$6F,$9A,$D1
    .byte $08,$3B,$55,$87,$CC,$11,$44,$78,$A2,$DE
    .byte $1F,$52,$8C,$B7,$E3,$0D,$41,$73,$9F,$CB
    .byte $23,$5D,$91,$BD,$E9,$17,$4B,$7F,$A6,$D2

star_seed_hi:
    .byte $21,$22,$23,$21,$22,$23,$21,$22,$23,$21
    .byte $22,$23,$21,$22,$23,$21,$22,$23,$21,$22
    .byte $23,$21,$22,$23,$21,$22,$23,$21,$22,$23
    .byte $21,$22,$23,$21,$22,$23,$21,$22,$23,$21

star_tile_t:
    .byte $01,$02,$01,$01,$02,$01,$03,$01,$02,$01
    .byte $01,$01,$02,$01,$01,$03,$01,$02,$01,$01
    .byte $02,$01,$01,$01,$03,$01,$01,$02,$01,$01
    .byte $01,$02,$01,$01,$01,$03,$02,$01,$01,$02

; ============================================================
; SEGMENT: VECTORS (at $FFFA)
; ============================================================
.segment "VECTORS"
    .addr NMI           ; NMI vector  ($FFFA)
    .addr RESET         ; Reset vector ($FFFC)
    .addr NMI           ; IRQ vector   ($FFFE, reuse NMI for safety)

; ============================================================
; CHR-ROM GRAPHICS DATA
; ============================================================
; NES tile format: 16 bytes per tile
; Bytes 0-7:  bit plane 0 (LSB of color index)
; Bytes 8-15: bit plane 1 (MSB of color index)
; Color: 00=transparent, 01=color1, 10=color2, 11=color3

.segment "CHARS"

; ============================================================
; PATTERN TABLE 0: BACKGROUND TILES ($0000-$0FFF)
; ============================================================

; Tile $00: Blank (transparent/black)
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $01: Tiny star (1 pixel)
    .byte $00,$00,$00,$18,$00,$00,$00,$00
    .byte $00,$00,$00,$18,$00,$00,$00,$00

; Tile $02: Small star (2x2)
    .byte $00,$00,$18,$18,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$18,$18,$00,$00

; Tile $03: Medium star cross
    .byte $00,$18,$3C,$FF,$3C,$18,$00,$00
    .byte $00,$00,$18,$18,$18,$00,$00,$00

; Tile $04: Nebula dot (3x3)
    .byte $00,$38,$7C,$7C,$38,$00,$00,$00
    .byte $00,$10,$38,$38,$10,$00,$00,$00

; Tile $05: Star cluster
    .byte $42,$00,$18,$00,$42,$00,$18,$00
    .byte $00,$42,$00,$18,$00,$42,$00,$18

; Tile $06: HUD separator line (solid)
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $00,$00,$00,$00,$00,$00,$00,$00

; Tile $07: HUD energy bar full
    .byte $FF,$81,$BD,$BD,$BD,$81,$FF,$00
    .byte $00,$7E,$42,$42,$42,$7E,$00,$00

; Tile $08: HUD energy bar half
    .byte $FF,$81,$BD,$80,$80,$81,$FF,$00
    .byte $00,$7E,$42,$42,$42,$7E,$00,$00

; Tile $09: HUD energy bar empty
    .byte $FF,$81,$81,$81,$81,$81,$FF,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00

; Tiles $0A-$0F: more BG decorations
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00

; Tiles $10-$19: Digits 0-9
; Tile $10: '0'
    .byte $3C,$42,$46,$4A,$52,$62,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; Tile $11: '1'
    .byte $18,$38,$18,$18,$18,$18,$7E,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; Tile $12: '2'
    .byte $3C,$42,$02,$1C,$30,$40,$7E,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; Tile $13: '3'
    .byte $3C,$42,$02,$1C,$02,$42,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; Tile $14: '4'
    .byte $0C,$14,$24,$44,$7E,$04,$04,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; Tile $15: '5'
    .byte $7E,$40,$7C,$02,$02,$42,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; Tile $16: '6'
    .byte $1C,$20,$40,$7C,$42,$42,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; Tile $17: '7'
    .byte $7E,$42,$04,$08,$10,$10,$10,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; Tile $18: '8'
    .byte $3C,$42,$42,$3C,$42,$42,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; Tile $19: '9'
    .byte $3C,$42,$42,$3E,$02,$04,$38,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00

; Tiles $1A-$33: Letters A-Z
; $1A='A'
    .byte $18,$24,$42,$7E,$42,$42,$42,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $1B='B'
    .byte $7C,$42,$42,$7C,$42,$42,$7C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $1C='C'
    .byte $3C,$42,$40,$40,$40,$42,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $1D='D'
    .byte $7C,$42,$42,$42,$42,$42,$7C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $1E='E'
    .byte $7E,$40,$40,$7C,$40,$40,$7E,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $1F='F'
    .byte $7E,$40,$40,$7C,$40,$40,$40,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $20='G'
    .byte $3C,$42,$40,$4E,$42,$42,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $21='H'
    .byte $42,$42,$42,$7E,$42,$42,$42,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $22='I'
    .byte $7E,$18,$18,$18,$18,$18,$7E,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $23='J'
    .byte $1E,$04,$04,$04,$44,$44,$38,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $24='K'
    .byte $42,$44,$48,$70,$48,$44,$42,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $25='L'
    .byte $40,$40,$40,$40,$40,$40,$7E,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $26='M'
    .byte $42,$66,$5A,$5A,$42,$42,$42,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $27='N'
    .byte $42,$62,$52,$4A,$46,$42,$42,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $28='O'
    .byte $3C,$42,$42,$42,$42,$42,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $29='P'
    .byte $7C,$42,$42,$7C,$40,$40,$40,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $2A='Q'
    .byte $3C,$42,$42,$42,$4A,$44,$3A,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $2B='R'
    .byte $7C,$42,$42,$7C,$48,$44,$42,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $2C='S'
    .byte $3C,$42,$40,$3C,$02,$42,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $2D='T'
    .byte $7E,$18,$18,$18,$18,$18,$18,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $2E='U'
    .byte $42,$42,$42,$42,$42,$42,$3C,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $2F='V'
    .byte $42,$42,$42,$42,$24,$24,$18,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $30='W'
    .byte $42,$42,$42,$5A,$5A,$66,$42,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $31='X'
    .byte $42,$42,$24,$18,$24,$42,$42,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $32='Y'
    .byte $42,$42,$24,$18,$18,$18,$18,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $33='Z'
    .byte $7E,$02,$04,$18,$20,$40,$7E,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $34: Space
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $35: ':'
    .byte $00,$18,$18,$00,$18,$18,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $36: '!'
    .byte $18,$18,$18,$18,$00,$18,$18,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $37: '.'
    .byte $00,$00,$00,$00,$00,$18,$18,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; $38-$3F: Fill
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00

; Fill rest of pattern table 0 to $0FFF
; (tiles $40-$FF = 192 more tiles, all blank)
.res 192*16, $00

; ============================================================
; PATTERN TABLE 1: SPRITE TILES ($1000-$1FFF)
; ============================================================

; Tile $00 (SPR_SHIP0): Player ship top-left, frame 0
; Ship nose points up. Left half of top.
;  . . . X X . . .    (X = color 1 = cyan)
;  . . X X X . . .
;  . X X X X . . .
;  X X . X X . . .    (engine gap)
;  X X . X X . . .
;  X X X X X . . .
;  . X X . . . . .    (thruster tip)
;  . . X . . . . .
    .byte $18,$1C,$1E,$1B,$1B,$1F,$06,$02   ; plane 0
    .byte $18,$1C,$1E,$1B,$1B,$1F,$06,$02   ; plane 1 (same = color 3)

; Tile $01 (SPR_SHIP0+1): Player ship top-right, frame 0 (h-flip of $00)
    .byte $18,$38,$78,$D8,$D8,$F8,$60,$40
    .byte $18,$38,$78,$D8,$D8,$F8,$60,$40

; Tile $02 (SPR_SHIP0+2): Player ship bottom-left, frame 0
;  X X X X X . . .    (wing)
;  X . . . . . . .
;  X . . . . . . .    (engine)
;  . X . . . . . .    (thruster glow)
;  . . X . . . . .
;  . . . . . . . .
;  . . . . . . . .
;  . . . . . . . .
    .byte $F8,$80,$80,$40,$20,$00,$00,$00
    .byte $F8,$C0,$C0,$60,$30,$00,$00,$00

; Tile $03 (SPR_SHIP0+3): Player ship bottom-right, frame 0
    .byte $1F,$01,$01,$02,$04,$00,$00,$00
    .byte $1F,$03,$03,$06,$0C,$00,$00,$00

; Tile $04 (SPR_SHIP2): Player ship top-left, frame 1 (thruster firing)
    .byte $18,$1C,$1E,$1B,$1B,$1F,$06,$02
    .byte $00,$00,$00,$18,$18,$1F,$07,$03   ; Different plane 1 = different colors on bottom

; Tile $05: Player ship top-right, frame 1
    .byte $18,$38,$78,$D8,$D8,$F8,$60,$40
    .byte $00,$00,$00,$18,$18,$F8,$E0,$C0

; Tile $06: Player ship bottom-left, frame 1 (thruster bright)
    .byte $F8,$80,$80,$40,$20,$10,$18,$0C   ; Longer thruster plume
    .byte $F8,$C0,$C0,$60,$30,$10,$08,$04

; Tile $07: Player ship bottom-right, frame 1
    .byte $1F,$01,$01,$02,$04,$08,$18,$30
    .byte $1F,$03,$03,$06,$0C,$08,$10,$20

; Tile $08 (SPR_EN0): Enemy type 0 - Dart fighter, frame 0
;   .  .  X  X  X  .  .  .
;   .  X  X  X  X  X  .  .
;   X  X  .  X  .  X  X  .
;   .  .  X  X  X  .  .  .
;   .  .  X  X  X  .  .  .
;   .  X  .  X  .  X  .  .
;   .  .  .  X  .  .  .  .
;   .  .  .  .  .  .  .  .
    .byte $38,$7C,$D6,$38,$38,$54,$10,$00
    .byte $38,$7C,$D6,$38,$38,$54,$10,$00

; Tile $09 (SPR_EN0+1): Enemy type 0 frame 1 (slight variation)
    .byte $38,$7C,$D6,$38,$3C,$56,$10,$00
    .byte $10,$7C,$D6,$38,$3C,$54,$10,$00

; Tile $0A (SPR_EN1): Enemy type 1 - Wing bomber, frame 0
    .byte $18,$3C,$7E,$FF,$7E,$3C,$18,$00
    .byte $00,$18,$3C,$66,$3C,$18,$00,$00

; Tile $0B (SPR_EN1+1): Enemy type 1, frame 1
    .byte $18,$3C,$7E,$FF,$7E,$3C,$18,$00
    .byte $18,$3C,$66,$42,$66,$3C,$18,$00

; Tile $0C (SPR_EN2): Enemy type 2 - Heavy cruiser, frame 0
    .byte $3C,$7E,$E7,$FF,$E7,$7E,$3C,$18
    .byte $18,$42,$A5,$81,$A5,$42,$18,$00

; Tile $0D (SPR_EN2+1): Enemy type 2, frame 1
    .byte $3C,$7E,$E7,$FF,$E7,$7E,$3C,$18
    .byte $00,$42,$BD,$81,$BD,$42,$00,$18

; Tile $0E (SPR_EN3): Enemy type 3 - Spiral drone, frame 0
    .byte $18,$3C,$66,$C3,$C3,$66,$3C,$18
    .byte $00,$18,$24,$42,$42,$24,$18,$00

; Tile $0F (SPR_EN3+1): Enemy type 3, frame 1
    .byte $18,$3C,$66,$C3,$C3,$66,$3C,$18
    .byte $18,$24,$42,$81,$81,$42,$24,$18

; Tile $10 (SPR_PBL): Player bullet - bright elongated shot
    .byte $00,$18,$3C,$7E,$7E,$3C,$18,$00
    .byte $00,$18,$3C,$7E,$7E,$3C,$18,$00

; Tile $11 (SPR_EBL): Enemy bullet - small red orb
    .byte $00,$18,$3C,$3C,$3C,$18,$00,$00
    .byte $00,$00,$18,$3C,$18,$00,$00,$00

; Tile $12 (SPR_EXP0): Explosion frame 0
    .byte $00,$24,$18,$7E,$7E,$18,$24,$00
    .byte $00,$00,$18,$42,$42,$18,$00,$00

; Tile $13 (SPR_EXP1): Explosion frame 1
    .byte $42,$A5,$18,$FF,$FF,$18,$A5,$42
    .byte $00,$42,$24,$7E,$7E,$24,$42,$00

; Tile $14 (SPR_EXP2): Explosion frame 2 (fading)
    .byte $81,$42,$24,$00,$00,$24,$42,$81
    .byte $42,$24,$00,$00,$00,$00,$24,$42

; Tile $15 (SPR_BOSS0): Boss top-left (large alien mothership)
    .byte $07,$1F,$3F,$7F,$FF,$FF,$FF,$FF
    .byte $00,$07,$1F,$3F,$7F,$FF,$FF,$FF

; Tile $16 (SPR_BOSS1): Boss top-right
    .byte $E0,$F8,$FC,$FE,$FF,$FF,$FF,$FF
    .byte $00,$E0,$F8,$FC,$FE,$FF,$FF,$FF

; Tile $17 (SPR_BOSS2): Boss bottom-left
    .byte $FF,$FF,$FF,$7F,$3F,$1F,$07,$00
    .byte $FF,$FF,$FF,$FF,$7F,$3F,$0F,$00

; Tile $18 (SPR_BOSS3): Boss bottom-right
    .byte $FF,$FF,$FF,$FE,$FC,$F8,$E0,$00
    .byte $FF,$FF,$FF,$FF,$FE,$FC,$F0,$00

; Tile $19 (SPR_PWR0): Weapon power-up (star shape)
    .byte $18,$7E,$3C,$FF,$FF,$3C,$7E,$18
    .byte $00,$18,$3C,$66,$66,$3C,$18,$00

; Tile $1A (SPR_PWR1): Bomb power-up
    .byte $3C,$7E,$FF,$FF,$FF,$7E,$3C,$00
    .byte $18,$3C,$66,$FF,$66,$3C,$18,$00

; Tile $1B (SPR_HUD0): Sprite-0 trigger (1 pixel wide, full row)
    .byte $FF,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00

; Tiles $1C-$FF: Fill remaining sprite tiles with blank
.res (256-28)*16, $00
