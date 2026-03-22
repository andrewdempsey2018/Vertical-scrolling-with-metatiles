.include "constants.inc" 
.include "header.inc"
.include "reset.asm"
.include "controllers.asm"
.include "LoadRow.asm"
.include "ClearOAM.asm"

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
zp_scratch_1: .res 1
; ----------------------------------- ;

.segment "BSS"
RowData: .res 64

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

  ;;;;;;;;;;;;;;;;;;;;;;;;;

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
  beq Finished

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
  tay                   ; y now contains the address of the first element of the row we're interested in
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

; ----------------------------------- ;
MetatileTop:
  .byte $00,$00
  .byte $03,$04
  .byte $02,$02
  .byte $06,$06
  .byte $05,$05
  .byte $04,$04
  .byte $07,$07
MetatileBottom:
  .byte $00,$00
  .byte $13,$14
  .byte $02,$02
  .byte $06,$06
  .byte $05,$05
  .byte $04,$04
  .byte $07,$07

Screen1:
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01

Screen2:
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$03,$00,$03,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$03,$00,$03,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$03,$00,$03,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$03,$00,$03,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02

Screen3:
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$03,$00,$03,$00,$03,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$03,$00,$03,$00,$03,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$03,$00,$03,$00,$03,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$03,$00,$03,$00,$03,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01

Screen4:
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02

Screen5:
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$03,$00,$00,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$01
  .byte $01,$00,$03,$00,$00,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$01
  .byte $01,$00,$03,$00,$00,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$01
  .byte $01,$00,$03,$00,$00,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01

Screen6:
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$02
  .byte $02,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$02
  .byte $02,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$02
  .byte $02,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02
  .byte $02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02,$02

ScreensLow:
  .byte <Screen1,<Screen2,<Screen3,<Screen4,<Screen5,<Screen6,<Screen1,<Screen2
  .byte <Screen3,<Screen4,<Screen5,<Screen6,<Screen1,<Screen2,<Screen3,<Screen4
  .byte <Screen5,<Screen6,<Screen1,<Screen2,<Screen3,<Screen4,<Screen5,<Screen6
ScreensHigh:
  .byte >Screen1,>Screen2,>Screen3,>Screen4,>Screen5,>Screen6,>Screen1,>Screen2
  .byte >Screen3,>Screen4,>Screen5,>Screen6,>Screen1,>Screen2,>Screen3,>Screen4
  .byte >Screen5,>Screen6,>Screen1,>Screen2,>Screen3,>Screen4,>Screen5,>Screen6

RowHighNT0:
  .byte $20,$20,$20,$20,$20,$20,$20,$20,$21,$21,$21,$21,$21,$21,$21,$21,$22,$22,$22,$22,$22,$22,$22,$22,$23,$23,$23,$23,$23,$23
RowHighNT2:
  .byte $28,$28,$28,$28,$28,$28,$28,$28,$29,$29,$29,$29,$29,$29,$29,$29,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2A,$2B,$2B,$2B,$2B,$2B,$2B
RowLow:
  .byte $00,$20,$40,$60,$80,$A0,$C0,$E0,$00,$20,$40,$60,$80,$A0,$C0,$E0,$00,$20,$40,$60,$80,$A0,$C0,$E0,$00,$20,$40,$60,$80,$A0

; ----------------------------------- ;