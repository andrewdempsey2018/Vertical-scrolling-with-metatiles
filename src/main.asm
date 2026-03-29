.include "constants.inc" 
.include "header.inc"
.include "reset.asm"
.include "controllers.asm"
.include "LoadRow.asm"
.include "ClearOAM.asm"
.include "data.asm"

.segment "ZEROPAGE"
sleeping: .res 1
buttons_held: .res 1
buttons_pressed: .res 1

nametable_number: .res 1
row_address: .res 2
level_data: .res 2
scroll_y: .res 1
zp_screen_pointer: .res 2
screen_counter: .res 1
prep_next_row: .res 1

row_number: .res 1

; ----------------------------------- ;
; scratch area
zp_scratch_0: .res 1
zp_scratch_1: .res 2
; ----------------------------------- ;

.segment "BSS"
RowData: .res 64
AttribData: .res 8

.segment "CODE"

.proc irq_handler
  rti
.endproc

.proc nmi_handler
                        ; save registers
  php
  pha
  txa
  pha
  tya
  pha

  lda #$00
  sta OAMADDR
  lda #$02
  sta OAMDMA
  lda #$00

  inc scroll_y
  lda scroll_y
  cmp #240
  bne :+
  lda #0
  sta scroll_y
  lda nametable_number
  eor #$02
  sta nametable_number
:

NewRowCheck:
  lda scroll_y
  and #%00001111        ; multiple of 16
  bne NewRowCheckDone
  jsr LoadRow
  lda #$01
  sta prep_next_row

NewRowCheckDone:

  lda #$00
  sta PPUSCROLL         ; x scroll
  lda scroll_y
  sta PPUSCROLL         ; y scroll
                        
                        ; This is the PPU clean up section, so rendering the next frame starts properly.
  lda #%10010000        ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  eor nametable_number
  sta PPUCTRL
  lda #%00011110        ; enable sprites, enable background, no clipping on left side
  sta PPUMASK

  ;;
  lda #$00
  sta sleeping

                        ; restore registers and return
  pla
  tay
  pla
  tax
  pla
  plp

  rti
.endproc

.proc main
  ldx PPUSTATUS
  ldx #$3f
  stx PPUADDR
  ldx #$00
  stx PPUADDR

  lda #0
  sta PPUMASK

load_palettes:
  lda palettes,X
  sta PPUDATA
  inx
  cpx #$20              ; there are 32 colours to load
  bne load_palettes

; ----------------------------------- ;
; init nametables
  
  lda #$02
  ldx #$00
FillRowData:
  sta RowData, x
  inx
  cpx #$40
  bne FillRowData


InitializeNametables:
  lda #$02
  sta nametable_number
  lda #$00
  sta scroll_y
InitializeNametablesLoop:
  jsr LoadRow           ; draw bg column
  lda scroll_y          ; go to next column
  clc
  adc #$10
  sta scroll_y
  
  lda scroll_y          ; calculate rown number based on scroll position
  lsr a
  lsr a
  lsr a                 ; repeat for first nametable 
  cmp #$1E
  bne InitializeNametablesLoop
  
  lda #$00
  sta nametable_number
  sta scroll_y
  jsr LoadRow           ; draw first column of second nametable


InitializeNametablesDone:


; ----------------------------------- ;

  ldx #$00
  lda ScreensLow, x
  sta zp_screen_pointer
  lda ScreensHigh, x
  sta zp_screen_pointer+1
  
  ;;;;;;;;;;;;;;;;;;;;;;;;;

  cli

  lda #%10010000        ; turn on NMIs, sprites use first pattern table
  sta PPUCTRL
  lda #%00011110        ; turn on screen
  sta PPUMASK
  ;;

vblankwait:             ; wait for another vblank before continuing
  bit PPUSTATUS
  bpl vblankwait

mainloop:

  lda prep_next_row
  bne :+
  jmp Finished
:

  inc row_number
  lda row_number
  cmp #15
  bne :+
  ;;;
  inc screen_counter
  ldx screen_counter

  lda ScreensLow, x
  sta zp_screen_pointer
  lda ScreensHigh, x
  sta zp_screen_pointer+1

  lda AttribsLow, x
  sta zp_scratch_1
  lda AttribsHigh, x
  sta zp_scratch_1+1

  ;;;
  lda #0
  sta row_number
:
  asl a
  asl a
  asl a
  asl a                 ; multiply by 16
  tay                   ; y now contains the address of the first element of the row we're interested in
  
  sta zp_scratch_0

  ldx #$FF
FillTopRowData:
  inx
  lda (zp_screen_pointer), y
  asl a
  tay
  lda MetatileTop, y
  sta RowData, x
  inx
  iny
  lda MetatileTop, y
  sta RowData, x
  inc zp_scratch_0
  ldy zp_scratch_0
  cpx #$1F              ; 32 top tiles
  bne FillTopRowData

  ;;;
  lda row_number
  asl a
  asl a
  asl a
  asl a                 ; multiply by 16
  tay                   ; y now contains the address of the first element
  sta zp_scratch_0
  ;;;

FillBottomRowData:
  inx
  lda (zp_screen_pointer), y
  asl a
  tay
  lda MetatileBottom, y
  sta RowData, x
  inx
  iny
  lda MetatileBottom, y
  sta RowData, x
  inc zp_scratch_0
  ldy zp_scratch_0
  cpx #$3F              ; 32 top tiles
  bne FillBottomRowData

                        ; load attributes if the row number is even (atributes only need to be loaded every second row as attributes cover a 32x32 area)
  lda row_number
  and #%00000001        ; isolate lowest bit
  bne DontLoadAttrib    ; if result != 0 → odd
  lda row_number
  lsr a                 ; divide by 2 (if row number=0 then a=0, if row number=2 then a=1, if row number=4 then a=2 etc... 
                        ; this ensures the correct index is available for the attributes tables which is set out in 8 rows)

  asl a
  asl a
  asl a

  tay
  ldx #$00
FillAttribs:
  lda (zp_scratch_1), y
  sta AttribData, x
  iny
  inx
  cpx #$08
  bne FillAttribs
  
DontLoadAttrib:

  ;;
  lda #$00
  sta prep_next_row

Finished:

  jsr read_controller

done:
  ;loop
  inc sleeping
sleep:
  lda sleeping
  bne sleep

  jmp mainloop
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "graphics.chr"

.segment "RODATA"

palettes:
  .byte $0f,$00,$10,$30 ; background
  .byte $0f,$01,$21,$31
  .byte $0f,$06,$16,$26
  .byte $0f,$09,$19,$29

  .byte $0f,$00,$10,$30 ; sprite
  .byte $0f,$01,$21,$31
  .byte $0f,$06,$16,$26
  .byte $0f,$09,$19,$29