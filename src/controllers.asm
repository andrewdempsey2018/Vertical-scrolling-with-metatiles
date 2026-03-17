.segment "ZEROPAGE"

.segment "CODE"
.export read_controller
.proc read_controller
  php  ; save registers
  pha
  txa
  pha
  tya
  pha

  lda buttons_held
  tay
  lda #$01
  sta CONTROLLER1
  sta buttons_held
  lsr
  sta CONTROLLER1
get_buttons:
  lda CONTROLLER1
  lsr
  rol buttons_held
  bcc get_buttons
  tya
  eor buttons_held
  and buttons_held
  sta buttons_pressed

  pla ; restore registers
  tay
  pla
  tax
  pla
  plp

  rts
.endproc