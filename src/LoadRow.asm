.proc LoadRow
  php                   ; save registers
  pha
  txa
  pha
  tya
  pha

  lda scroll_y          ; calculate row number based on scroll position
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

  ;;;;;;;;;;
  lda row_number
  and #%00000001   ; isolate lowest bit
  bne DontLoadAttrib       ; if result != 0 → odd

  ldy row_number
  lda TableAttribData, y         ; figure out what nametable to draw to
  sta row_address


  lda nametable_number
  eor #$02              ; drawing to nametable that is currently offscreen
  cmp #$00
  bne Nametable2X
  lda #$23
  sta row_address+1
  jmp LoadAttribs
Nametable2X:
  lda #$2B
  sta row_address+1

LoadAttribs:

  lda PPUSTATUS
  lda row_address + 1
  sta PPUADDR
  lda row_address
  sta PPUADDR

  ldx #$00              ; draw top half of 16x16 tiles
DrawAttribLoop:
  lda AttribData, x
  sta PPUDATA
  inx
  cpx #$08
  bne DrawAttribLoop

DontLoadAttrib:
  ;;;;;;;;;;

  pla                   ; restore registers
  tay
  pla
  tax
  pla
  plp

  rts
.endproc