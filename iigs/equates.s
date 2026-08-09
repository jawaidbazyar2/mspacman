*
* Ms. Pac-Man IIgs — shared equates (sizes, pens, field offsets).
* Host addresses (SHR, BCK, work RAM, assets) come from mem_static.s or
* GS/OS segment labels — put that file before this one.
*
* Assets (static bank $03 / GS/OS data segment) from make gfx / make maze:
*   tiles6.bin / sprites14x12*.bin — upright (CW then row XOR 3)
*   maze1_cells.bin — stitched per-cell copies of those tiles
*

* Soft-switches via Mega II banks ($E0/$E1). VBL is $E1/C019.
NEWVIDEO       equ $E0C029
SHADOW         equ $E0C035
RDVBLBAR       equ $E1C019
KBD            equ $E0C000	; bit7=strobe; 0–6=key
KBDSTRB        equ $E0C010	; read: clear strobe; bit7=AKD (IIe/IIgs); 0–6=key
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

SHR_PIXEL_BYTES equ 32000
* Strides (bytes/row). SHR is full 320-wide; BCK is PF strip (S_BCK).
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
* Last legal sprite top Y for a full 12-row blit (rows Y..Y+11 ≤ 199).
* Y ≥ SPR_Y_LIMIT → FLAG_NODRAW. Past this, unrolled sta $2000,y with
* DBR=$01 walks into SCB/palette and then $C0xx soft-switches (disk motor).
SPR_Y_LIMIT    equ 189		; 200 - SPR_CELL_H
* BCK origin = sprite base so 14×12 erase never indexes before the strip.
* BCK_PIXELS itself is defined by mem_static.s / GS/OS BCK segment.
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
* Working RAM starts at $A000 so compiled blits may grow through $9xxx.
* Erase restores from BCK strip — no per-actor save-under.
* SHADOW $B7: inhibit text/HGR/aux/TEXT2; bit3=0 → SHR on; bit6=0 → IOLC intact.


NUM_TILES      equ 256
TILE_BYTES_ROW equ 3
TILE_BYTES     equ 18
* Arcade tile codes (py/gen_maze1.py + listing "PACMAN TILE CODES")
TILE_DOT       equ $10
TILE_POWER     equ $14
TILE_EMPTY     equ $40		; also the space glyph ($40-$5B = space + ASCII)
TILE_DIGIT0    equ $00		; score digits $00-$09

SPR_WORK_PAIR  equ 168		; spr+mask one parity
SPR_WORK_ACTOR equ 336		; even pair + odd pair (NUM_ACTORS × this)

POWER_FLASH_PERIOD equ 10	; arcade #4DCF / #0A

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
FLAG_NODRAW    equ $02		; skip DrawSprite (inactive fruit, tunnel / Y clip)
FLAG_POINTS    equ $04		; eat-ghost freeze: blit $28–$2B points (not body)

* Ghost body pens (palette slots from gen_palette color-ROM fill)
COL_BLINKY     equ 5		; red (fright: palette poke → blue/white)
COL_PINKY      equ 7		; pink
COL_INKY       equ 9		; cyan
COL_CLYDE      equ 11		; orange
COL_EYES       equ 0		; ghost blit slot 4 — body→transparent (eyes only)
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

* Arcade RAM mirror symbols (#4D00–#4E3F) live in mem_static.s / seg_work.s.
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
