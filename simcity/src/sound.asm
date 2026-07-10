; ============================================================================
; sound.asm — APU music driver (pulse1 melody + triangle bass) and SFX
; (pulse2 / noise). Ticked from NMI after the PPU-critical section.
; ============================================================================

; note indices (1-based into note period tables; 0 = rest)
N_C3 = 1
N_D3 = 2
N_E3 = 3
N_F3 = 4
N_G3 = 5
N_A3 = 6
N_B3 = 7
N_C4 = 8
N_D4 = 9
N_E4 = 10
N_F4 = 11
N_G4 = 12
N_A4 = 13
N_B4 = 14
N_C5 = 15
N_D5 = 16
N_E5 = 17
N_F5 = 18
N_G5 = 19
N_A5 = 20

note_lo:
    .byte 0
    .byte <854,<761,<678,<640,<570,<507,<452
    .byte <426,<380,<338,<319,<284,<253,<225
    .byte <213,<189,<168,<159,<141,<126
note_hi:
    .byte 0
    .byte >854,>761,>678,>640,>570,>507,>452
    .byte >426,>380,>338,>319,>284,>253,>225
    .byte >213,>189,>168,>159,>141,>126

.segment "ZEROPAGE"
mel_ptr:     .res 2
bas_ptr:     .res 2
.segment "BSS"
mus_on:      .res 1
mel_wait:    .res 1
bas_wait:    .res 1
sfx_id:      .res 1     ; $FF = none
sfx_pos:     .res 1
.segment "CODE"

apu_init:
    lda #%00001111      ; enable pulse1/2, triangle, noise
    sta $4015
    lda #$40
    sta $4017
    lda #$08
    sta $4001           ; no sweep
    sta $4005
    lda #$FF
    sta sfx_id
    lda #1
    sta mus_on
    jsr music_restart
    rts

music_restart:
    lda #<song_melody
    sta mel_ptr
    lda #>song_melody
    sta mel_ptr+1
    lda #<song_bass
    sta bas_ptr
    lda #>song_bass
    sta bas_ptr+1
    lda #1
    sta mel_wait
    sta bas_wait
    rts

audio_tick:
    jsr music_tick
    jmp sfx_tick

music_tick:
    lda mus_on
    bne :+
    rts
:   ; ---- melody (pulse 1)
    dec mel_wait
    bne @bass
@mel_next:
    ldy #0
    lda (mel_ptr),y
    cmp #$FF
    bne :+
    jsr music_restart
    jmp @mel_next
:   tax                 ; note
    iny
    lda (mel_ptr),y
    sta mel_wait
    ; advance ptr += 2
    lda mel_ptr
    clc
    adc #2
    sta mel_ptr
    bcc :+
    inc mel_ptr+1
:   cpx #0
    bne :+
    lda #%10110000      ; rest: volume 0
    sta $4000
    jmp @bass
:   lda #%10110011      ; duty 50%, const vol 3
    sta $4000
    lda note_lo,x
    sta $4002
    lda note_hi,x
    ora #%11111000      ; long length counter
    sta $4003
@bass:
    ; ---- bass (triangle)
    dec bas_wait
    bne @done
@bas_next:
    ldy #0
    lda (bas_ptr),y
    cmp #$FF
    bne :+
    ; loop bass independently
    lda #<song_bass
    sta bas_ptr
    lda #>song_bass
    sta bas_ptr+1
    jmp @bas_next
:   tax
    iny
    lda (bas_ptr),y
    sta bas_wait
    lda bas_ptr
    clc
    adc #2
    sta bas_ptr
    bcc :+
    inc bas_ptr+1
:   cpx #0
    bne :+
    lda #%10000000      ; silence triangle
    sta $4008
    jmp @done
:   lda #%11000001      ; linear counter on
    sta $4008
    lda note_lo,x
    sta $400A
    lda note_hi,x
    ora #%11111000
    sta $400B
@done:
    rts

; ---------------------------------------------------------------- sfx ------
SFX_PLACE = 0
SFX_ERROR = 1
SFX_ALARM = 2
SFX_CLICK = 3
SFX_DOZER = 4           ; noise-channel sfx start here

sfx_start:              ; A = sfx id
    sta sfx_id
    lda #0
    sta sfx_pos
    rts

sfx_tick:
    lda sfx_id
    cmp #$FF
    bne :+
    rts
:   cmp #SFX_DOZER
    bcs @noise
    ; pulse2 sfx: 3 bytes per frame (ctrl, lo, hi), ctrl=$FF end
    tax
    lda sfx_tab_lo,x
    sta ptr2
    lda sfx_tab_hi,x
    sta ptr2+1
    lda sfx_pos
    asl a
    clc
    adc sfx_pos         ; *3
    tay
    lda (ptr2),y
    cmp #$FF
    beq @end_pulse
    sta $4004
    iny
    lda (ptr2),y
    sta $4006
    iny
    lda (ptr2),y
    ora #%11111000
    sta $4007
    inc sfx_pos
    rts
@end_pulse:
    lda #%10110000
    sta $4004
    lda #$FF
    sta sfx_id
    rts
@noise:
    ; noise sfx: 2 bytes per frame (vol, period), vol=$FF end
    tax
    lda sfx_tab_lo,x
    sta ptr2
    lda sfx_tab_hi,x
    sta ptr2+1
    lda sfx_pos
    asl a
    tay
    lda (ptr2),y
    cmp #$FF
    beq @end_noise
    sta $400C
    iny
    lda (ptr2),y
    sta $400E
    lda #%11111000
    sta $400F
    inc sfx_pos
    rts
@end_noise:
    lda #%00110000
    sta $400C
    lda #$FF
    sta sfx_id
    rts

sfx_tab_lo:
    .byte <sfx_place_d, <sfx_error_d, <sfx_alarm_d, <sfx_click_d, <sfx_dozer_d
sfx_tab_hi:
    .byte >sfx_place_d, >sfx_error_d, >sfx_alarm_d, >sfx_click_d, >sfx_dozer_d

sfx_place_d:            ; cheerful rising blip
    .byte %10111010, <380, >380
    .byte %10111010, <319, >319
    .byte %10111000, <284, >284
    .byte %10111000, <253, >253
    .byte %10110100, <213, >213
    .byte %10110010, <213, >213
    .byte $FF

sfx_error_d:            ; low buzz
    .byte %00111000, <854, >854
    .byte %00111000, <854, >854
    .byte %00111000, <854, >854
    .byte %00111000, <907, >907
    .byte %00111000, <907, >907
    .byte %00111000, <907, >907
    .byte %00111000, <854, >854
    .byte %00111000, <854, >854
    .byte %00111000, <907, >907
    .byte %00111000, <907, >907
    .byte $FF

sfx_alarm_d:            ; disaster siren: two tones
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <507, >507
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte %10111010, <380, >380
    .byte $FF

sfx_click_d:            ; tiny tick
    .byte %10110110, <213, >213
    .byte %10110011, <189, >189
    .byte $FF

sfx_dozer_d:            ; crunch (noise: vol, period)
    .byte %00111010, $08
    .byte %00111010, $09
    .byte %00111000, $0A
    .byte %00110110, $0B
    .byte %00110100, $0C
    .byte %00110010, $0C
    .byte %00110001, $0D
    .byte $FF

; sfx entry points used by game code
sfx_place:
    lda #SFX_PLACE
    jmp sfx_start
sfx_dozer:
    lda #SFX_DOZER
    jmp sfx_start
sfx_error:
    lda #SFX_ERROR
    jmp sfx_start
sfx_alarm:
    lda #SFX_ALARM
    jmp sfx_start
sfx_click:
    lda #SFX_CLICK
    jmp sfx_start

; ---------------------------------------------------------------- song -----
; events: note index, duration frames; $FF = loop
B_ = 32                 ; frames per beat

song_melody:
    ; C
    .byte N_E4, 16, N_G4, 8, N_C5, 8
    ; Am
    .byte N_A4, 16, N_E4, 16
    ; F
    .byte N_F4, 8, N_A4, 8, N_C5, 16
    ; G
    .byte N_B4, 16, N_G4, 16
    ; C
    .byte N_C5, 16, N_E5, 8, N_D5, 8
    ; Am
    .byte N_C5, 8, N_A4, 8, N_E4, 16
    ; F
    .byte N_A4, 16, N_F4, 16
    ; G
    .byte N_G4, 24, N_B4, 8
    ; C (variation)
    .byte 0, 8, N_E4, 8, N_G4, 16
    ; Am
    .byte N_A4, 8, N_C5, 8, N_E5, 16
    ; F
    .byte N_F5, 16, N_C5, 16
    ; G
    .byte N_D5, 16, N_B4, 16
    ; C
    .byte N_C5, 32
    ; Am
    .byte N_A4, 16, N_G4, 16
    ; F
    .byte N_F4, 16, N_A4, 16
    ; G
    .byte N_G4, 16, 0, 16
    .byte $FF

song_bass:
    ; C
    .byte N_C3, 8, N_G3, 8, N_C3, 8, N_G3, 8
    ; Am
    .byte N_A3, 8, N_E3, 8, N_A3, 8, N_E3, 8
    ; F
    .byte N_F3, 8, N_C4, 8, N_F3, 8, N_C4, 8
    ; G
    .byte N_G3, 8, N_D4, 8, N_G3, 8, N_D4, 8
    .byte $FF
