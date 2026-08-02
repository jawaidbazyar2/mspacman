*
* Ms. Pac-Man IIgs — shared equates (render harness v1)
*
* Assets in bank $03 come from make gfx / make maze:
*   tiles6.bin / sprites14x12*.bin — upright (CW then row XOR 3)
*   maze1_cells.bin — stitched per-cell copies of those tiles
* Do not re-orient in 65816; blit as packed (8-bit stores per row).
*

* Soft-switches as 24-bit bank $00 (DB may be $02 while running)
NEWVIDEO       equ $00C029
SHADOW         equ $00C035
RDVBLBAR       equ $00C019
TXTCLR         equ $00C050

BANK_CODE      equ $02
BANK_SHR       equ $01
BANK_ASSETS    equ $03

SHR_PIXELS     equ $012000
SHR_SCB        equ $019D00
SHR_PALETTE    equ $019E00
SHR_ROW_BYTES  equ 160
SHR_PIXEL_BYTES equ 32000

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
* (opaque ~cols 2–11); -4 lines that band up with the 6px path.
SPR_OFF_X      equ -4
SPR_OFF_Y      equ -3
NUM_SPRITES    equ 64
NUM_ACTORS     equ 3

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

TILEMAP        equ $027000
ACTORS         equ $027400
SAVEUNDER      equ $027500
DIRTY_COUNT    equ $027800
DIRTY_LIST     equ $027802
FRAME_COUNT    equ $027900
EAT_INDEX      equ $027902

ACT_SIZE       equ 16
ACT_X          equ 0
ACT_Y          equ 2
ACT_DX         equ 4
ACT_DY         equ 6
ACT_SPR        equ 8
ACT_FLAGS      equ 9
FLAG_DRAWN     equ $01
