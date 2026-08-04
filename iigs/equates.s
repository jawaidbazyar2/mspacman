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
BRD_RAILS      equ $09		; orange — demo rails / FrameTick (alias BRD_TICK)
BRD_TICK       equ $09		; orange — FrameTick (DemoTick or LogicTick)
BRD_SORT       equ $0D		; yellow — SortActorsByY (after tick, before WaitVBL)
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
* Arcade tile codes (py/gen_maze1.py + listing "PACMAN TILE CODES")
TILE_DOT       equ $10
TILE_POWER     equ $14
TILE_EMPTY     equ $40		; also the space glyph ($40-$5B = space + ASCII)
TILE_DIGIT0    equ $00		; score digits $00-$09

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
* HUD game state. Scores are 3 BCD bytes lo/mid/hi like arcade #4E80/#4E88:
* value = hi*10000 + mid*100 + lo. Lives / level mirror #4E15 / #4E13.
SCORE_LO       equ $028908
SCORE_MID      equ $028909
SCORE_HI       equ $02890A
HISCORE_LO     equ $02890B
HISCORE_MID    equ $02890C
HISCORE_HI     equ $02890D
LIVES          equ $02890E
LEVEL          equ $02890F	; 0 = cherry (arcade level_number)
* Low 16 of the score bytes, for >BANK2,x reads (same idiom as ACTORS16)
SCORE16        equ $8908
HISCORE16      equ $890B
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
FLAG_NODRAW    equ $02		; skip DrawSprite (inactive fruit, tunnel null zone)

* Ghost body pens (palette slots from gen_palette color-ROM fill)
COL_BLINKY     equ 5		; red
COL_PINKY      equ 7		; pink
COL_INKY       equ 9		; cyan
COL_CLYDE      equ 11		; orange
COL_POWER      equ 14		; energizer fade (palette poke only)
BODY_PEN       equ 6		; marker in sprite assets
COL_DIGIT      equ 13		; yellow ink for HUD glyphs (tile art is pen 3)

* Side HUD — the 76px gutters either side of the 168px playfield (§1 design).
* Glyphs are 6×6 tiles blitted at absolute screen XY (SHR only: sprites never
* reach the gutters, so the BCK strip needs no HUD copy). X must stay even.
HUD_GLYPH_W    equ 6		; glyph advance = tile width
HUD_SCORE_DIGITS equ 6		; 3 BCD bytes × 2 digits
HUD_BLANK_LEAD equ 4		; leading zeros blanked (arcade j_2ace C=#04)
HUD_1UP_X      equ 8
HUD_1UP_Y      equ 4
HUD_SCORE_X    equ 8
HUD_SCORE_Y    equ 12
HUD_LIVES_X    equ 8
HUD_LIVES_Y    equ 40
HUD_LIVES_DX   equ 14		; one sprite cell per life icon
HUD_HS_LABEL_X equ 248
HUD_HS_LABEL_Y equ 4
HUD_HISCORE_X  equ 248
HUD_HISCORE_Y  equ 12
HUD_FRUIT_X    equ 252
HUD_FRUIT_Y    equ 28
MSPAC_LIFE_SPR equ 7		; dir W, mouth nearly shut ($2D+H) — HUD life icon
MAX_FRUIT_TYPE equ 7		; arcade j_8793 clamps level fruit at banana
START_LIVES    equ 3
SCORE_PERIOD   equ 300		; demo: +10 points every 300 frames

*============================================================
* Game-build arcade RAM mirror (#4D00–#4E3F) in free actor pad.
* Offsets match locked src/ram.inc — comment anchors for listing.
*============================================================
RAM4D          equ $028460	; == #4D00
RAM4E          equ $028560	; == #4E00 (256 bytes after #4D00)
* #4Dxx actor physics (Y then X — arcade order)
RED_Y          equ $028460	; == #4D00
RED_X          equ $028461
PINK_Y         equ $028462
PINK_X         equ $028463
BLUE_Y         equ $028464
BLUE_X         equ $028465
ORANGE_Y       equ $028466
ORANGE_X       equ $028467
PAC_Y          equ $028468	; == #4D08
PAC_X          equ $028469	; == #4D09
RED_TILE_Y     equ $02846A	; == #4D0A
RED_TILE_X     equ $02846B
PINK_TILE_Y    equ $02846C
PINK_TILE_X    equ $02846D
BLUE_TILE_Y    equ $02846E
BLUE_TILE_X    equ $02846F
ORANGE_TILE_Y  equ $028470
ORANGE_TILE_X  equ $028471
PAC_TILE_Y     equ $028499	; == #4D39
PAC_TILE_X     equ $02849A	; == #4D3A
PAC_TILE_DY    equ $02847C	; == #4D1C (word Y,X deltas)
PAC_TILE_DX    equ $02847D
PAC_WANT_DY    equ $028486	; == #4D26
PAC_WANT_DX    equ $028487
PAC_DIR        equ $028490	; == #4D30
PAC_WANT_DIR   equ $02849C	; == #4D3C
RED_DIR        equ $02848C	; == #4D2C
PINK_DIR       equ $02848D
BLUE_DIR       equ $02848E
ORANGE_DIR     equ $02848F
RED_PREV_DIR   equ $028488	; == #4D28
PINK_PREV_DIR  equ $028489
BLUE_PREV_DIR  equ $02848A
ORANGE_PREV_DIR equ $02848B
RED_TILE_DY    equ $028474	; == #4D14
PINK_TILE_DY   equ $028476
BLUE_TILE_DY   equ $028478
ORANGE_TILE_DY equ $02847A
SPD_PAC_NORM   equ $0284A6	; == #4D46 (4 bytes rotating)
SPD_PAC_ENERG  equ $0284AA	; == #4D4A
SPD_RED_NORM   equ $0284B6	; == #4D56
PAC_MOVE_DELAY equ $0284FD	; == #4D9D
POWER_PILL_ACT equ $028506	; == #4DA6
RED_FRIGHT     equ $028507	; == #4DA7
PINK_FRIGHT    equ $028508
BLUE_FRIGHT    equ $028509
ORANGE_FRIGHT  equ $02850A
RED_STATE      equ $02850B	; == #4DAB (0=alive,1=eyes,…)
PINK_STATE     equ $02850C
BLUE_STATE     equ $02850D
ORANGE_STATE   equ $02850E
RED_SUBSTATE   equ $028500	; == #4DA0 (0=home,1=chase,…)
PINK_SUBSTATE  equ $028501
BLUE_SUBSTATE  equ $028502
ORANGE_SUBSTATE equ $028503
DOTS_EATEN     equ $02856E	; == #4E0E
GAME_MODE      equ $028560	; == #4E00
LEVEL_STATE    equ $028564	; == #4E04
LEVEL_NUMBER   equ $028573	; == #4E13
LIVES_REAL     equ $028575	; == #4E15
FRIGHT_TIMER   equ $02852B	; == #4DCB (byte; we use word at FRIGHT_TIME)
FRIGHT_TIME    equ $02851D	; == #4DBD word initial fright duration
RED_REVERSE    equ $028511	; == #4DB1
PINK_REVERSE   equ $028512	; == #4DB2
BLUE_REVERSE   equ $028513	; == #4DB3
ORANGE_REVERSE equ $028514	; == #4DB4
* Level1Speed copy places reverse thresholds at #4D86 (== SPD_PAC_NORM+$40)
GHOST_ORIENT_TBL equ $0284E6	; == #4D86
GHOST_ORIENT_IDX equ $028521	; == #4DC1
GHOST_ORIENT_CNT equ $028522	; == #4DC2 word
PATH_BEST_DIR  equ $02849B	; == #4D3B
PATH_OPP_DIR   equ $02849D	; == #4D3D
PATH_CUR_Y     equ $02849E	; == #4D3E
PATH_CUR_X     equ $02849F
PATH_DST_Y     equ $0284A0	; == #4D40
PATH_DST_X     equ $0284A1
PATH_TMP_Y     equ $0284A2
PATH_TMP_X     equ $0284A3
PATH_MIN_LO    equ $0284A4	; == #4D44
PATH_TRY_DIR   equ $028527	; == #4DC7
STICK_IN0      equ $028590	; soft IN0 (active-low), game build
FRUIT_ACTIVE   equ $028591
FRUIT_PIXEL_Y  equ $028592	; == fruit_pos style
FRUIT_PIXEL_X  equ $028593
DEATH_TIMER    equ $028594
CLEAR_TIMER    equ $028595
FRUIT_TIMER    equ $028596
FRUIT_SPAWNED  equ $028597	; bit0=first, bit1=second
PELLET_TARGET  equ 224		; maze1 clear count (== #8B2C)
DIR_RIGHT      equ 0
DIR_DOWN       equ 1
DIR_LEFT       equ 2
DIR_UP         equ 3
* KBD codes after AND #$7F (HandleKey strips the strobe bit)
KEY_ESC        equ $1B		; Escape ($9B with bit7)
KEY_Q          equ $51		; 'Q'
KEY_A          equ $41		; 'A'
KEY_Z          equ $5A		; 'Z'
KEY_LEFT       equ $08		; ← ($88 with bit7)
KEY_RIGHT      equ $15		; → ($95 with bit7)
