.segment "ZEROPAGE"

.segment "CODE"
.export reset_handler
.proc reset_handler
  sei
  cld
  ldx #$40
  stx APU
  ldx #$FF
  txs
  inx
  stx PPUCTRL
  stx PPUMASK
  stx IRQ_ENABLE
  bit PPUSTATUS
vblankwait:
  bit PPUSTATUS
  bpl vblankwait

	ldx #$00
	lda #$FF
clear_oam:
	sta PPUCTRL, x        ; set sprite y-positions off the screen
	inx
	inx
	inx
	inx
	bne clear_oam

  lda #$00
  sta nametable_number
  sta row_address
  sta level_data
  sta prep_next_row

  lda #$FF
  sta scroll_y

  lda #$00
  sta row_number
  

  lda #$00
  sta zp_scratch_0
  sta zp_scratch_1
  sta zp_screen_pointer
  sta zp_screen_pointer+1
  sta screen_counter

vblankwait2:
  bit PPUSTATUS
  bpl vblankwait2
  jmp main
.endproc