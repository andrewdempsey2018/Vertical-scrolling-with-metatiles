.proc LoadRow
  php                   ; save registers
  pha
  txa
  pha
  tya
  pha

  lda scroll_y          ; calculate rown number based on scroll position
  lsr a
  lsr a
  lsr a
  tay

  lda RowLow, y         ; figure out what nametable to draw to
  sta row_address
  
  lda nametable_number
  eor #$02              ; drawing to nametable that is currently offscreen
  cmp #$00
  bne Nametable2
  lda RowHighNT0, y
  sta row_address+1
  jmp DrawTiles
Nametable2:
  lda RowHighNT2, y
  sta row_address+1

DrawTiles:           ; prep ppu for drawing tiles
  lda PPUSTATUS
  lda row_address + 1
  sta PPUADDR
  lda row_address
  sta PPUADDR

  ldx #$00              ; draw top half of 16x16 tiles
DrawTilesLoop:
  lda RowData, x
  sta PPUDATA
  inx
  txa
  cmp #$40
  bne DrawTilesLoop

;  ldx #$20              ; draw bottom half of 16x16 tiles
;DrawBottomTilesLoop:
;  lda #7
;  sta PPUDATA
;  dex
;  bne DrawBottomTilesLoop

  pla                   ; restore registers
  tay
  pla
  tax
  pla
  plp

  rts
.endproc