PPUCTRL = $2000 ; NMI enable (V), PPU master/slave (P), sprite height (H), background tile select (B), sprite tile select (S), increment mode (I), nametable select (NN)
PPUMASK	= $2001	 ; color emphasis (BGR), sprite enable (s), background enable (b), sprite left column enable (M), background left column enable (m), greyscale (G)
PPUSTATUS = $2002 ; vblank (V), sprite 0 hit (S), sprite overflow (O); read resets write pair for $2005/$2006
OAMADDR	= $2003 ; OAM read/write address
OAMDATA	= $2004 ; OAM data read/write
PPUSCROLL = $2005 ; fine scroll position (two writes: X scroll, y scroll)
PPUADDR	= $2006 ; PPU read/write address (two writes: most significant byte, least significant byte)
PPUDATA	= $2007 ; PPU data read/write
OAMDMA	= $4014 ; OAM DMA high address

CONTROLLER1 = $4016
CONTROLLER2 = $4017
APU = $4017
IRQ_ENABLE = $4010

BTN_RIGHT   = %00000001
BTN_LEFT    = %00000010
BTN_DOWN    = %00000100
BTN_UP      = %00001000
BTN_START   = %00010000
BTN_SELECT  = %00100000
BTN_B       = %01000000
BTN_A       = %10000000