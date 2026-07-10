; ============================================================================
; MICROPOLIS — a city simulator for the NES
; An homage to the original 1989 city simulator, rebuilt from scratch
; in 6502 assembly. Mapper: MMC1 (32KB PRG, 8KB CHR, 8KB battery WRAM).
; ============================================================================

.include "tiles.inc"

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

; ---------------------------------------------------------------- header ---
.segment "HEADER"
.byte 'N','E','S',$1A
.byte 2                 ; 2x16KB PRG
.byte 1                 ; 1x8KB CHR
.byte $12               ; mapper 1 low nibble, battery-backed WRAM
.byte $00               ; mapper 1 high nibble
.byte 1                 ; 8KB PRG RAM
.byte 0,0,0,0,0,0,0

; ---------------------------------------------------------------- zeropage -
.segment "ZEROPAGE"
frame_ctr:   .res 1     ; increments every NMI
nmi_ready:   .res 1     ; set by NMI, cleared by main loop
ptr0:        .res 2
ptr1:        .res 2

.segment "OAM_SEG"
oam: .res 256

.segment "BSS"

.segment "WRAM"

; ---------------------------------------------------------------- code -----
.segment "CODE"

reset:
    sei
    cld
    ldx #$40
    stx JOY2            ; disable APU frame IRQ
    ldx #$FF
    txs
    inx                 ; X = 0
    stx PPUCTRL         ; NMI off
    stx PPUMASK         ; rendering off
    stx $4010           ; DMC IRQ off

    ; MMC1 init: reset shift register, then configure
    lda #$80
    sta $8000           ; reset MMC1 shift register
    lda #%00000010      ; vertical mirroring, 32KB PRG, 8KB CHR
    jsr mmc1_ctrl
    lda #0
    jsr mmc1_chr0       ; CHR bank 0 (8KB mode)
    lda #0
    jsr mmc1_prg        ; PRG bank 0, WRAM enabled

    bit PPUSTATUS
: bit PPUSTATUS         ; wait first vblank
    bpl :-

    ; clear internal RAM ($0000-$07FF)
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
    ; hide all sprites
    lda #$FF
: sta $0200,x
    inx
    bne :-

: bit PPUSTATUS         ; wait second vblank
    bpl :-

    ; ---- load palettes
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

    ; ---- clear nametable $2000 + $2400
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #0
    ldy #16             ; 16*256 = 4KB (both nametables + attrs)
    ldx #0
: sta PPUDATA
    inx
    bne :-
    dey
    bne :-

    ; ---- write boot message
    lda #$21
    sta PPUADDR
    lda #$8B
    sta PPUADDR
    ldx #0
: lda boot_msg,x
    beq :+
    sta PPUDATA
    inx
    bne :-
:
    ; ---- scroll = 0, enable NMI + rendering
    bit PPUSTATUS
    lda #0
    sta PPUSCROLL
    sta PPUSCROLL
    lda #%10001000      ; NMI on, sprites use pattern table 1
    sta PPUCTRL
    lda #%00011110      ; show bg + sprites
    sta PPUMASK

main_loop:
    lda nmi_ready
    beq main_loop
    lda #0
    sta nmi_ready
    jmp main_loop

; ---- MMC1 register writes (A = value, 5 serial writes LSB first)
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

nmi:
    pha
    txa
    pha
    tya
    pha
    inc frame_ctr
    lda #1
    sta nmi_ready
    ; OAM DMA
    lda #0
    sta OAMADDR
    lda #>oam
    sta OAMDMA
    lda #0
    sta PPUSCROLL
    sta PPUSCROLL
    pla
    tay
    pla
    tax
    pla
irq:
    rti

; ---------------------------------------------------------------- data -----
.segment "RODATA"

FONTMAP                 ; map ASCII to font tiles for .byte strings

palettes:
    ; background
    .byte $0F,$2A,$1A,$30   ; greens + white
    .byte $0F,$21,$11,$30   ; blues
    .byte $0F,$10,$00,$30   ; grays
    .byte $0F,$27,$17,$30   ; browns/orange
    ; sprites
    .byte $0F,$30,$16,$27
    .byte $0F,$30,$21,$11
    .byte $0F,$30,$2A,$1A
    .byte $0F,$30,$10,$00

boot_msg:
    .byte "MICROPOLIS BOOT OK", 0

; ---------------------------------------------------------------- vectors --
.segment "VECTORS"
.word nmi
.word reset
.word irq

; ---------------------------------------------------------------- chr ------
.segment "CHARS"
.incbin "../chr.bin"
