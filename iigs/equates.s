*
* Ms. Pac-Man IIgs — shared equates (render harness v1)
*
* Assets in bank $03 come from make gfx / make maze:
*   tiles6.bin / sprites14x12*.bin — upright (CW then row XOR 3)
*   maze1_cells.bin — stitched per-cell copies of those tiles
* Do not re-orient in 65816; blit as packed (8-bit stores per row).
*

* Soft-switches via Mega II banks after SHADOW inhibits I/O in $00/$01.
* VBL is $E1/C019; other C0xx via $E0. (bit6 IOLC: $00/Cxxx becomes RAM.)
NEWVIDEO       equ $E0C029
SHADOW         equ $E0C035
RDVBLBAR       equ $E1C019
KBD            equ $E0C000
KBDSTRB        equ $E0C010
BORDCOLOR      equ $E0C034	; low nibble = border
TXTCLR         equ $E0C050

* MainLoop phase border colors (classic 16; keep far apart — avoid orange+red→“yellow”)
BRD_ERASE      equ $03		; purple — EraseSprite entry
BRD_DRAW       equ $0C		; green — DrawSprite entry
BRD_COPY       equ $07		; light blue — CopySpritePos
BRD_RAILS      equ $09		; orange — AdvanceRails
BRD_SORT       equ $0D		; yellow — SortActorsByY (before WaitVBL)
BRD_VBL        equ $00		; black — WaitVBL slack (absent ⇒ no headroom / possible miss)
BRD_FREEZE     equ $0F		; white — DEMO_FREEZE spin

BANK_CODE      equ $02
BANK_SHR       equ $01
BANK_ASSETS    equ $03

SHR_PIXELS     equ $012000
SHR_SCB        equ $019D00
SHR_PALETTE    equ $019E00
SHR_PIXEL_BYTES equ 32000
* Strides (bytes/row). SHR is full 320-wide; BCK is PF strip in $01/A000.
S_SHR          equ 160
S_BCK          equ 88		; 176 px = sprite overhang + 28×6 PF + pad
SHR_ROW_BYTES  equ S_SHR	; alias

PF_ORIGIN_X    equ 76
PF_ORIGIN_Y    equ 7
PF_TILE_W      equ 6
PF_TILE_H      equ 6
PF_COLS        equ 28
PF_ROWS        equ 31
PF_PIX_W       equ 168
PF_PIX_H       equ 186

SPR_CELL_W     equ 14
SPR_CELL_H     equ 12
SPR_ART_W      equ 12
SPR_ART_H      equ 12
SPR_BYTES_ROW  equ 7
SPR_BYTES      equ 84
* Center sprite cell on a 6×6 tile. Art is centered in the 14-wide cell
* (opaque ~cols 2–11); -4/-3 lines that band up with the 6px path.
* Merlin cannot fold negative equates into #imm expressions — use bases.
SPR_BASE_X     equ 72		; PF_ORIGIN_X - 4
SPR_BASE_Y     equ 4		; PF_ORIGIN_Y - 3
* Playfield backing store (no sprites): bank $01, abs with DBR=$01.
* Origin = sprite base so 14×12 erase never indexes before the strip.
BCK_PIXELS     equ $01A000
BCK_BASE       equ $A000		; low 16 for abs,X / abs,Y
BCK_ORIGIN_X   equ SPR_BASE_X
BCK_ORIGIN_Y   equ 0		; row index = screen Y (ROW_BCK)
BCK_CLEAR_BYTES equ 200*S_BCK	; rows 0..199 × stride (InitSHR zeros)
NUM_SPRITES    equ 64
NUM_GHOSTS     equ 4		; Blinky / Pinky / Inky / Clyde (rails)
NUM_ACTORS     equ 6		; ghosts + fruit + Ms. Pac
FRUIT_ACTOR    equ 4
PAC_ACTOR      equ 5
FRUIT_PERIOD   equ 360		; frames between fruit-type changes
FRUIT_TILE_X   equ 14		; fixed demo tile (below ghost house)
FRUIT_TILE_Y   equ 17
PAC_RAIL_START equ 24		; Ms. Pac rail waypoint (mid-path visibility)
* Working RAM starts at $8000 so compiled blits may grow through $7xxx.
* Erase restores from BCK strip — no per-actor save-under.
* SHADOW $F7: inhibit text/HGR/aux/TEXT2/IOLC; bit3=0 → SHR shadow on.


NUM_TILES      equ 256
TILE_BYTES_ROW equ 3
TILE_BYTES     equ 18

AST_TILES      equ $030000
AST_SPR_EVEN   equ $031200
AST_MSK_EVEN   equ $032700
AST_SPR_ODD    equ $033C00
AST_MSK_ODD    equ $035100
AST_MAZE       equ $036600
AST_MAZE_CELLS equ $037000	; 868 × 18 stitched 6×6 cells

* Pre-colored ghost work (bank $02): per actor, even then odd (spr+mask each)
SPR_WORK16     equ $6000
SPR_WORK_PAIR  equ 168		; spr+mask one parity
SPR_WORK_ACTOR equ 336		; even pair + odd pair (NUM_ACTORS × this)

TILEMAP        equ $028000
ACTORS         equ $028400
* $028500–$0287FF free (was SAVEUNDER)
DIRTY_COUNT    equ $028800
DIRTY_LIST     equ $028802
FRAME_COUNT    equ $028900
EAT_INDEX      equ $028902
DEMO_FREEZE    equ $028904	; nonzero → MainLoop skips erase/rails/draw
POWER_FLASH_CNT equ $028906	; byte; BlinkPowerPills period counter
POWER_FLASH_PERIOD equ 10	; arcade #4DCF / #0A
ROW_ADDR       equ $028B00	; 256 words: Y → Y*S_SHR (ScreenXY)
ROW_BCK        equ $028D00	; 256 words: Y → Y*S_BCK (BckXY)

ACT_SIZE       equ 16
ACT_X          equ 0		; new X (rails write; DrawSprite reads)
ACT_Y          equ 2		; new Y
ACT_OX         equ 4		; old X (CopySpritePos / Y-sort)
ACT_OY         equ 6		; old Y (Y-sort before WaitVBL)
ACT_SPR        equ 8
ACT_FLAGS      equ 9
ACT_WP         equ 10		; waypoint index into RailPath (byte)
ACT_COLOR      equ 11		; SHR pen for body (replaces marker pen 6)
ACT_DEST       equ 12		; SHR offset cached at DrawSprite
ACT_BDEST      equ 14		; BCK offset cached at DrawSprite (EraseSprite)
FLAG_DRAWN     equ $01

* Ghost body pens (palette slots from gen_palette color-ROM fill)
COL_BLINKY     equ 5		; red
COL_PINKY      equ 7		; pink
COL_INKY       equ 9		; cyan
COL_CLYDE      equ 11		; orange
COL_POWER      equ 14		; energizer fade (palette poke only)
BODY_PEN       equ 6		; marker in sprite assets
