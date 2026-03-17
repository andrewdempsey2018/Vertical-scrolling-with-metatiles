.proc clear_oam
  php                   ; save registers
  pha
  txa
  pha
  tya
  pha

  ldx #$00
  lda #$F8
@clear_oam:
  sta $0200, x          ; set sprite y-positions off the screen
  inx
  inx
  inx
  inx
  bne @clear_oam

  pla                   ; restore registers
  tay
  pla
  tax
  pla
  plp

  rts
.endproc