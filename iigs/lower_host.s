*
* lower_host.s: the IIgs host for the phase 3 game (make iigs-lower).
*
* lower.bin (the 65816 lowered from lower/*.c) is loaded at $05/0000 and
* runs one arcade frame per call of its c_only_frame entry. It sees the
* arcade map in the game bank, $06: ROM at $0000-$3FFF and $8000-$9FFF,
* video, color and work RAM at $4000-$4FFF, the I/O page at $5000 as
* plain RAM, and the host block at $F000. This file keeps the soft-sprite
* renderer's loop and feeds it from the game bank:
*
*   tiles    video and color RAM, diffed each frame into TILEMAP and the
*            dirty list (color 0 blanks a cell)
*   sprites  sprite codes and colors at $4C02 plus the actor and fruit
*            positions, into ACTORS
*   HUD      the BCD scores, lives and level, into the side HUD
*   input    the keyboard into the IN0/IN1 bytes of the host block
*
* Sound is not adapted: the voice registers stay in the game bank.
*
* lower-iigs-check sets CheckMode before the first frame, preloads the
* game bank from a session and points the replay stream at its reads.
* The breakpoint at FrameDone ends each frame.
*
* Under GS/OS (make iigs-lower-gsos) the game bank is the bank-aligned
* OMF segment GAME (seg_game_lower.s), with lower.bin assembled at $A000
* inside it, and lower.bin's direct page is a Memory Manager page in
* bank $00. The loader relocates every GAME reference.
*
	mx	%00

	do	BUILD_GSOS
LOWER_CODE	equ	GAME+$A000
	else
GAME	equ	$060000
LOWER_CODE	equ	$050000
LOWER_DP	equ	$1E00	; lower.bin's direct page, bank $00
HOST_STACK	equ	$1DFF
	fin

G_TILE	equ	GAME+$4040	; 28 columns x 32 rows, column-major
G_COLOR	equ	GAME+$4440
G_SPRITE	equ	GAME+$4C00	; code, color by slot (flips in bits 7-6)
G_POS	equ	GAME+$4D00	; actor positions, y then x
G_PAC_DIR	equ	GAME+$4D30
G_FRUIT_POS	equ	GAME+$4DD2
G_LEVEL	equ	GAME+$4E13
G_LIVES	equ	GAME+$4E15
G_SCORE1	equ	GAME+$4E80	; 3 bytes BCD, low first
G_HISCORE	equ	GAME+$4E88
G_HB	equ	GAME+$F000
G_IN0	equ	GAME+$F010
G_IN1	equ	GAME+$F011
G_DSW1	equ	GAME+$F012
G_REPLAY	equ	GAME+$F013

DSW1_DEFAULT	equ	$C9	; LIFT_DSW1_DEFAULT
FRUIT_ROW_MAX	equ	7	; draw_fruit_row: one fruit per level up to seven
FRUIT_ROW_WIDE	equ	4	; icons per HUD row
FRUIT_ROW_X	equ	HUD_FRUIT_X+SPR_CELL_W+SPR_CELL_W+SPR_CELL_W
DIRTY_MAX	equ	120	; DIRTY_LIST holds 127; past this, redraw all
TILEMAP_CELLS	equ	868	; 28 x 31

* The adapters' shadows (SH_TILE, SH_COLOR, SH_HUD, FULL_REDRAW) are at
* the end of this file, in the program bank.

	do	BUILD_GSOS
CheckMode	db	0
FrameDone	rts
	else
* all_lower.s puts entry_ids.s (LE_*) ahead of this file, which must
* start the image: the trampoline jumps to $02/0000.
	jmp	Start
CheckMode	db	0	; $0003: lower-iigs-check preloaded the game bank
FrameDone	rts		; $0004: the end of a frame (check breakpoint)

Start
	sei
	clc
	xce
	rep	#$30
	lda	#HOST_STACK
	tcs
	lda	#$0000
	tcd
	phk
	plb
	lda	#LOWER_DP
	sta	|LowerDP
	fin

* GS/OS: gsos_entry.s's Start calls here and quits when this returns.
GameEnter
	do	BUILD_GSOS
	jsr	AllocLowerDP
	bcc	:dp
	rts
:dp
	fin
	jsr	InitSHR
	jsr	InitRowAddr
	jsr	InitHUD
	jsr	DrawHudChrome
	jsr	LowerInit
	jsr	WaitVBL

MainLoop
	sep	#$20
	jsr	LowerKeys
	bcs	:exit
	rep	#$30
	lda	>DEMO_FREEZE
	and	#$00FF
	bne	:frozen
	jsr	EraseAllSprites
	jsr	LowerApplyTiles
	jsr	DrawAllSprites
	jsr	CopySpritePos
	jsr	CallFrame
	jsr	FrameDone
	jsr	LowerTiles
	jsr	LowerSprites
	jsr	LowerHud
	lda	#ACT_OY
	jsr	SortActorsByY
	lda	>G_REPLAY
	and	#$00FF
	bne	MainLoop
	jsr	WaitVBL
	bra	MainLoop
:frozen	jsr	WaitVBL
	bra	MainLoop
:exit	jmp	ExitDemo

ExitDemo
	sep	#$30
	lda	#0
	jsr	SetBorder
	lda	#$41
	sta	>NEWVIDEO
	lda	>KBDSTRB
	do	BUILD_GSOS
	rep	#$30
	jmp	QuitGSOS
	else
	sec
	xce
]hang	bra	]hang
	fin

	do	BUILD_GSOS
* A locked page in bank $00 for lower.bin's direct page: NewHandle
* ($0902), attributes locked, fixed, page-aligned, bank given. Carry set
* when the Memory Manager has none.
AllocLowerDP
	rep	#$30
	pha				; result: the handle
	pha
	pea	$0000			; size $00000100
	pea	$0100
	lda	|myID
	pha
	pea	$C005
	pea	$0000			; location: bank $00
	pea	$0000
	ldx	#$0902
	jsl	$E10000
	bcs	:fail
	pla
	sta	<R_TMP
	pla
	sta	<R_TMP+2
	lda	[R_TMP]
	sta	|LowerDP
	clc
	rts
:fail	pla
	pla
	sec
	rts
	fin

* One arcade frame: lower.bin's c_only_frame with its calling convention,
* MX %10, D = LowerDP, DBR = the game bank.
CallFrame
	php
	phb
	phd
	rep	#$30
	lda	|LowerDP
	tcd
	sep	#$20
	lda	#^GAME
	pha
	plb
	sep	#$20
	rep	#$10
	jsl	LOWER_CODE+LE_c_only_frame
	rep	#$30
	pld
	plb
	plp
	rts

* Power-on state, unless lower-iigs-check preloaded a session: the game
* bank's RAM and I/O page clear, the host block's seed and switches set.
* Every tile cell is redrawn on the first pass.
LowerInit
	php
	rep	#$30
	lda	|CheckMode
	and	#$00FF
	bne	:adapt
	lda	#0
	ldx	#$0FFE
]clr	sta	>GAME+$4000,x
	dex
	dex
	bpl	]clr
	ldx	#$00FE
]io	sta	>GAME+$5000,x
	sta	>G_HB,x
	dex
	dex
	bpl	]io
	lda	#1
	sta	>G_HB+4			; HB_RAND = 1, little-endian
	sep	#$20
	lda	#$FF
	sta	>G_IN0
	sta	>G_IN1
	lda	#DSW1_DEFAULT
	sta	>G_DSW1
	rep	#$20
:adapt	lda	#$FFFF
	ldx	#$03FE
]sh	sta	|SH_TILE,x
	sta	|SH_COLOR,x
	dex
	dex
	bpl	]sh
	ldx	#$000E
]hud	sta	|SH_HUD,x
	dex
	dex
	bpl	]hud
	ldx	#TILEMAP_CELLS-2
	lda	#$4040
]tm	sta	>TILEMAP,x
	dex
	dex
	bpl	]tm
	lda	#1
	sta	|FULL_REDRAW
	lda	#0
	sta	>DIRTY_COUNT
	sta	>DEMO_FREEZE
	sta	>FRAME_COUNT
* No actor drawn yet: erase skips them until DrawSprite marks them.
	ldx	#NUM_ACTORS*ACT_SIZE-ACT_SIZE
]act	lda	#0
	sta	>ACTORS+ACT_X,x
	sta	>ACTORS+ACT_Y,x
	sta	>ACTORS+ACT_OX,x
	sta	>ACTORS+ACT_OY,x
	sep	#$20
	lda	#FLAG_NODRAW
	sta	>ACTORS+ACT_FLAGS,x
	rep	#$20
	txa
	sec
	sbc	#ACT_SIZE
	tax
	bpl	]act
	jsr	LowerTiles
	jsr	LowerSprites
	lda	#ACT_OY
	jsr	SortActorsByY
	plp
	rts

*------------------------------------------------------------------
* Keyboard -> IN0 / IN1 (active low). Arrows or A/Z steer, 5 or C is
* coin 1, 1 and 2 are the start buttons, Control-S is the rack test
* (clears the board), Esc pauses, Q quits (carry set). Directions use
* any-key-down so a held key holds the stick.
*------------------------------------------------------------------
	mx	%10
LowerKeys
	php
	sep	#$20
	lda	#$FF
	sta	>G_IN0
	sta	>G_IN1
	lda	>KBD
	bpl	:akd
	and	#$7F
	cmp	#KEY_ESC
	beq	:pause
	cmp	#'Q'
	beq	:quit
	cmp	#'q'
	beq	:quit
:akd	lda	>KBDSTRB
	bpl	:done
	and	#$7F
	cmp	#$60
	bcc	:upper
	sbc	#$20			; lower case to upper
:upper	ldx	#0
]k	cmp	|:keys,x
	beq	:hit
	inx
	inx
	inx
	cpx	#:keys_end-:keys
	bcc	]k
:done	plp
	clc
	rts
:hit	lda	|:keys+2,x
	beq	:in1
	eor	#$FF
	and	>G_IN0
	sta	>G_IN0
	bra	:done
:in1	lda	|:keys+1,x
	eor	#$FF
	and	>G_IN1
	sta	>G_IN1
	bra	:done
:pause	lda	>KBDSTRB
	lda	>DEMO_FREEZE
	eor	#1
	sta	>DEMO_FREEZE
	bra	:done
:quit	lda	>KBDSTRB
	plp
	sec
	rts
* key, IN1 bit, IN0 bit (one of the two is zero)
:keys	db	$0B,0,$01		; up arrow
	db	KEY_A,0,$01
	db	KEY_LEFT,0,$02
	db	KEY_RIGHT,0,$04
	db	$0A,0,$08		; down arrow
	db	KEY_Z,0,$08
	db	'5',0,$20		; coin 1
	db	'C',0,$20
	db	'1',$20,0		; start 1
	db	'2',$40,0		; start 2
	db	$13,0,$10		; Control-S: rack test
:keys_end
	mx	%00

*------------------------------------------------------------------
* Tiles. Video RAM $4040 + col*32 + row is the renderer's cell
* (27 - col, row - 1); row 0 is above the maze. A cell whose color is 0
* draws as a blank. The low 5 bits of a cell's color pick its arcade
* bank, kept in CellBank; LowerDrawCell resolves the tile's pens through
* it (docs/ColorMap.md).
*------------------------------------------------------------------
LT_BANK	equ	$3C	; cell's bank (LowerDrawCell, LowerRemapTile)
LT_BK16	equ	$3E	; bank * 16: its row of TileBankPens
LT_I	equ	$40	; byte index into LT_BUF
LT_BUF	equ	$42	; 18 resolved tile bytes, +2 for word stores

* Diff the game bank's tiles and colors against the last pass. Changed
* cells go to TILEMAP and the dirty list, or to a full redraw.
LowerTiles
	php
	jsr	LowerMazeBank
	rep	#$30
	ldx	#$037E
]w	lda	>G_TILE,x
	cmp	|SH_TILE,x
	bne	:chg
	lda	>G_COLOR,x
	cmp	|SH_COLOR,x
	bne	:chg
:next	dex
	dex
	bpl	]w
	plp
	rts
:chg	phx
	jsr	:cell
	inx
	jsr	:cell
	plx
	bra	:next

* One cell, X = its offset from $4040. Keeps X.
:cell	sep	#$20
	lda	>G_TILE,x
	sta	|SH_TILE,x
	sta	<R_TILE
	lda	>G_COLOR,x
	sta	|SH_COLOR,x
	and	#$1F
	sta	<LT_BANK
	bne	:lit
	lda	#TILE_EMPTY
	sta	<R_TILE
:lit	rep	#$20
	txa
	and	#$001F
	beq	:skip			; row 0: off the playfield
	dec
	sta	<R_TY
	txa
	lsr
	lsr
	lsr
	lsr
	lsr
	sta	<R_TMP
	lda	#27
	sec
	sbc	<R_TMP
	sta	<R_TX
	phx
	lda	<R_TY
	asl
	asl
	sta	<R_OFF			; ty*4
	asl
	asl
	asl				; ty*32
	sec
	sbc	<R_OFF			; ty*28
	clc
	adc	<R_TX
	tax
	sep	#$20
	lda	<R_TILE
	sta	>TILEMAP,x
	lda	<LT_BANK
	sta	|CellBank,x
	rep	#$20
	plx
	lda	|FULL_REDRAW
	bne	:skip
	lda	>DIRTY_COUNT
	cmp	#DIRTY_MAX
	bcc	:q
	lda	#1
	sta	|FULL_REDRAW
	rts
:q	phx
	asl
	tax
	sep	#$20
	lda	<R_TX
	sta	>DIRTY_LIST,x
	lda	<R_TY
	sta	>DIRTY_LIST+1,x
	rep	#$20
	lda	>DIRTY_COUNT
	inc
	sta	>DIRTY_COUNT
	plx
:skip	rep	#$20
	rts

* Between erase and draw: the dirty cells, or every cell.
LowerApplyTiles
	php
	rep	#$30
	lda	|FULL_REDRAW
	bne	:all
	jsr	LowerApplyDirty
	plp
	rts
:all	lda	#0
	sta	|FULL_REDRAW
	sta	>DIRTY_COUNT
	sta	<R_IDX
	sta	<R_TY
]y	lda	#0
	sta	<R_TX
]x	ldx	<R_IDX
	lda	>TILEMAP,x
	and	#$00FF
	sta	<R_TILE
	lda	<R_TX
	pha
	lda	<R_TY
	pha
	jsr	LowerDrawCell
	pla
	sta	<R_TY
	pla
	sta	<R_TX
	inc	<R_IDX
	inc
	sta	<R_TX
	cmp	#PF_COLS
	bcc	]x
	lda	<R_TY
	inc
	sta	<R_TY
	cmp	#PF_ROWS
	bcc	]y
	plp
	rts

* ApplyDirty, with each cell drawn through its bank.
LowerApplyDirty
	php
	rep	#$30
	lda	>DIRTY_COUNT
	beq	:done
	sta	<R_IDX
	ldx	#0
]d	lda	>DIRTY_LIST,x
	and	#$00FF
	sta	<R_TX
	lda	>DIRTY_LIST+1,x
	and	#$00FF
	sta	<R_TY
	phx
	asl
	asl
	sta	<R_OFF			; ty*4
	asl
	asl
	asl				; ty*32
	sec
	sbc	<R_OFF			; ty*28
	clc
	adc	<R_TX
	tax
	lda	>TILEMAP,x
	and	#$00FF
	sta	<R_TILE
	jsr	LowerDrawCell
	plx
	inx
	inx
	dec	<R_IDX
	bne	]d
	lda	#0
	sta	>DIRTY_COUNT
:done	plp
	rts

* The bank the game paints this level's maze in: j_9590's level ->
* $95AE lookup, folds included. Cells in it draw raw, as before banks
* were resolved, so every level's maze keeps palette pens 0-3.
LowerMazeBank
	php
	sep	#$20
	lda	>G_LEVEL
	sec
	sbc	#$15
	bmi	:low			; @9595 JP P: level < #15
]fold	sec
	sbc	#$10
	bpl	]fold
	clc
	adc	#$15
	bra	:look
:low	lda	>G_LEVEL
:look	rep	#$30
	and	#$00FF
	tax
	sep	#$20
	lda	>GAME+$95AE,x
	and	#$1F
	sta	|MazeBank
	plp
	rts
	mx	%00

* Draw TILEMAP cell X (R_TX, R_TY, R_TILE set) in its bank's colors.
* Raw: the maze bank, banks whose map is the identity, and blanks.
LowerDrawCell
	lda	|CellBank,x
	and	#$001F
	cmp	|MazeBank
	beq	:raw
	tay
	lda	|TileBankRaw,y
	and	#$00FF
	bne	:raw
	lda	<R_TILE
	cmp	#TILE_EMPTY
	beq	:raw
	sty	<LT_BANK
	jsr	LowerRemapTile
	jmp	LowerDrawTileBuf
:raw	jmp	DrawTile

* R_TILE's 18 bytes into LT_BUF, each nibble through LT_BANK's row of
* TileBankPens. DBR = the program bank.
LowerRemapTile
	lda	<LT_BANK
	asl
	asl
	asl
	asl
	sta	<LT_BK16
	stz	<LT_I
	lda	<R_TILE
	jsr	Mul18
	tax
]b	lda	>AST_TILES,x
	and	#$00FF
	beq	:put			; both pixels pen 0
	sta	<R_BTMP
	lsr
	lsr
	lsr
	lsr
	ora	<LT_BK16
	tay
	lda	|TileBankPens,y
	and	#$000F
	asl
	asl
	asl
	asl
	sta	<R_TMP
	lda	<R_BTMP
	and	#$000F
	ora	<LT_BK16
	tay
	lda	|TileBankPens,y
	and	#$000F
	ora	<R_TMP
:put	phx
	ldx	<LT_I
	sta	<LT_BUF,x
	inx
	stx	<LT_I
	plx
	inx
	lda	<LT_I
	cmp	#18
	bcc	]b
	rts

* DrawTile with LT_BUF as the art: SHR ($01) and BCK strip.
LowerDrawTileBuf
	php
	phb
	sep	#$20
	lda	#BANK_SHR
	pha
	plb
	rep	#$30
	lda	<R_TX
	asl
	clc
	adc	<R_TX
	asl
	clc
	adc	#PF_ORIGIN_X
	sta	<R_X
	lda	<R_TY
	asl
	clc
	adc	<R_TY
	asl
	clc
	adc	#PF_ORIGIN_Y
	sta	<R_Y
	jsr	ScreenXY
	jsr	BckXY
	lda	#6
	sta	<R_ROW
	ldy	<R_DEST
	ldx	#0
* 3 bytes/row: word @0 then overlapped word @1, as DrawTile.
]tr	lda	<LT_BUF,x
	sta	$2000,y
	sta	<R_BTMP
	lda	<LT_BUF+1,x
	sta	$2001,y
	sta	<R_TMP
	phx
	ldx	<R_BDEST
	lda	<R_BTMP
	sta	>BCK_PIXELS,x
	lda	<R_TMP
	sta	>BCK_PIXELS+1,x
	plx
	inx
	inx
	inx
	tya
	clc
	adc	#S_SHR
	tay
	lda	<R_BDEST
	clc
	adc	#S_BCK
	sta	<R_BDEST
	dec	<R_ROW
	bne	]tr
	plb
	plp
	rts

*------------------------------------------------------------------
* Sprites. Slots 1-4 are the ghosts, 5 Ms. Pac-Man, 6 the fruit; the
* renderer's actors are ghosts 0-3, the fruit 4 and Ms. Pac-Man 5.
* Positions come from the actor table the sprite registers are made
* from, through the renderer's own arcade-to-screen map.
*------------------------------------------------------------------
LS_SLOT	equ	$34	; renderer DP is free from $34 to $E9
LS_CODE	equ	$36
LS_COLOR	equ	$38
LS_BASE	equ	$3A

LowerSprites
	php
	rep	#$30
	lda	#0
	sta	<LS_SLOT
]g	lda	<LS_SLOT		; ghosts
	asl
	tax
	lda	>G_POS,x
	jsr	:place
	jsr	:ghost
	inc	<LS_SLOT
	lda	<LS_SLOT
	cmp	#4
	bcc	]g
	lda	>G_POS+8		; Ms. Pac-Man
	ldy	#5*ACT_SIZE
	ldx	#5
	jsr	:placeYX
	jsr	:pac
	lda	>G_FRUIT_POS		; fruit
	ldy	#FRUIT_ACTOR*ACT_SIZE
	ldx	#6
	jsr	:placeYX
	jsr	:fruit
	plp
	rts

* Ghost LS_SLOT: A = its position word.
:place	ldy	<LS_SLOT
	tyx
	inx				; sprite slot
	pha
	tya
	asl
	asl
	asl
	asl
	tay
	pla
* A = position (y low, x high), Y = actor base, X = sprite slot.
:placeYX	sty	<LS_BASE
	pha
	txa
	asl
	tax
	lda	>G_SPRITE,x
	sep	#$20
	sta	<LS_CODE
	xba
	sta	<LS_COLOR
	rep	#$20
	pla
	sep	#$30
	xba
	tax				; x
	xba				; y
	jsr	ArcadeToScreen
	rep	#$30
	ldx	<LS_BASE
	lda	<R_X
	sta	>ACTORS+ACT_X,x
	lda	<R_Y
	sta	>ACTORS+ACT_Y,x
	jsr	ActorTunnelVis
	sep	#$20
	lda	>ACTORS+ACT_FLAGS,x
	and	#$FF-FLAG_POINTS
	sta	>ACTORS+ACT_FLAGS,x
	lda	<LS_COLOR
	bne	:vis
	jsr	:hide
:vis	rep	#$20
	rts

* X = actor base. Not drawn this frame.
:hide	sep	#$20
	lda	>ACTORS+ACT_FLAGS,x
	ora	#FLAG_NODRAW
	sta	>ACTORS+ACT_FLAGS,x
	rep	#$20
	rts

* Ghost: walking frames $20-$27 in the ghost's pen, eyes, points, or
* blue ($1C-$1D), which recolors the ghost's own pen.
:ghost	ldx	<LS_BASE
	sep	#$20
	lda	<LS_CODE
	and	#$3F
	cmp	#$28
	bcs	:pts
	cmp	#$1C
	bcc	:gone
	cmp	#$1E
	bcc	:blue
	cmp	#$20
	bcc	:gone
	sta	>ACTORS+ACT_SPR,x
	lda	<LS_COLOR
	cmp	#$19
	beq	:eyes
	lda	<LS_SLOT
	asl
	adc	#COL_BLINKY
	sta	>ACTORS+ACT_COLOR,x
	rep	#$20
	lda	#0
	bra	:pen
	mx	%10
:eyes	lda	#COL_EYES
	sta	>ACTORS+ACT_COLOR,x
	rep	#$20
	lda	#0
	bra	:pen
	mx	%10
:blue	and	#1
	sta	>ACTORS+ACT_SPR,x
	lda	<LS_SLOT
	asl
	adc	#COL_BLINKY
	sta	>ACTORS+ACT_COLOR,x
	lda	<LS_COLOR
	cmp	#$12
	rep	#$20
	lda	#$022D			; blue
	bcc	:pen
	lda	#$0FFF			; flashing white
	bra	:pen
	mx	%10
:pts	cmp	#$2C
	bcs	:gone
	sta	>ACTORS+ACT_SPR,x
	lda	>ACTORS+ACT_FLAGS,x
	ora	#FLAG_POINTS
	sta	>ACTORS+ACT_FLAGS,x
	rep	#$20
	rts
:gone	rep	#$20
	jmp	:hide
* A = the body pen's color, 0 for the ghost's own.
:pen	pha
	lda	<LS_SLOT
	asl
	asl
	adc	#COL_BLINKY*2
	tax
	pla
	bne	:poke
	lda	|PalTable,x
:poke	sta	>SHR_PALETTE,x
	rts

* Ms. Pac-Man: the pose for her direction, closed or one of the open
* mouths. Codes outside the walk set (death, cutscenes) show closed.
:pac	ldx	<LS_BASE
	lda	>G_PAC_DIR
	and	#$0003
	asl
	asl
	sta	<R_TMP
	lda	<LS_CODE
	and	#$003F
	cmp	#$34
	bcc	:open
	cmp	#$38
	bcs	:open
	lda	<LS_CODE
	and	#$00C0
	bne	:open			; $F4-$F7 up: $35/$37 are open
	lda	<LS_CODE
	and	#$003F
	cmp	#$34
	bne	:clsd
	lda	<R_TMP
	cmp	#1*4
	bne	:open			; $34 is closed only facing down
:clsd	ldy	#0
	bra	:sel
:open	lda	<LS_CODE
	and	#$0002
	beq	:o1
	ldy	#2
	bra	:sel
:o1	ldy	#1
:sel	tya
	clc
	adc	<R_TMP
	tay
	sep	#$20
	lda	|:poses,y
	sta	>ACTORS+ACT_SPR,x
	rep	#$20
	rts
* dir*4 + (closed, open with bit 1 clear, open with bit 1 set) -> dir*3+mouth
:poses	db	1,2,0,0
	db	3,4,5,0
	db	6,7,8,0
	db	10,11,9,0

* Fruit: codes $00-$07.
:fruit	ldx	<LS_BASE
	sep	#$20
	lda	<LS_CODE
	and	#$3F
	cmp	#8
	bcs	:fgone
	sta	>ACTORS+ACT_SPR,x
	rep	#$20
	rts
:fgone	rep	#$20
	jmp	:hide

*------------------------------------------------------------------
* Side HUD: player 1's score, the high score, lives and level, redrawn
* when they change.
*------------------------------------------------------------------
LowerHud
	php
	sep	#$30
	ldx	#2
]s	lda	>G_SCORE1,x
	cmp	|SH_HUD,x
	bne	:score
	dex
	bpl	]s
	bra	:hi
:score	ldx	#2
]sc	lda	>G_SCORE1,x
	sta	|SH_HUD,x
	sta	>SCORE_LO,x
	dex
	bpl	]sc
	rep	#$30
	jsr	DrawScore
	sep	#$30
:hi	ldx	#2
]h	lda	>G_HISCORE,x
	cmp	|SH_HUD+3,x
	bne	:hisc
	dex
	bpl	]h
	bra	:lives
:hisc	ldx	#2
]hc	lda	>G_HISCORE,x
	sta	|SH_HUD+3,x
	sta	>HISCORE_LO,x
	dex
	bpl	]hc
	rep	#$30
	jsr	DrawHiscore
	sep	#$30
* The gutter holds four icons.
:lives	lda	>G_LIVES
	cmp	#5
	bcc	:lv
	lda	#4
:lv	cmp	|SH_HUD+6
	beq	:level
	sta	|SH_HUD+6
	sta	>LIVES
	rep	#$30
	lda	#HUD_LIVES_X
	ldx	#HUD_LIVES_Y
	ldy	#4*HUD_LIVES_DX
	jsr	ClearHud
	jsr	DrawLives
	sep	#$30
:level	lda	>G_LEVEL
	cmp	|SH_HUD+7
	beq	:done
	sta	|SH_HUD+7
	sta	>LEVEL
	rep	#$30
	lda	#HUD_FRUIT_X
	ldx	#HUD_FRUIT_Y
	ldy	#FRUIT_ROW_WIDE*SPR_CELL_W
	jsr	ClearHud
	lda	#HUD_FRUIT_X
	ldx	#HUD_FRUIT_Y+SPR_CELL_H
	ldy	#FRUIT_ROW_WIDE*SPR_CELL_W
	jsr	ClearHud
	jsr	DrawFruitRow
:done	plp
	rts

* The arcade's fruit row ($2BEA): one fruit per level up to seven, cherry
* first. The row starts at the right like the arcade's and wraps after
* four icons. 16-bit A/X/Y; R_TMP is the slot (= fruit type), R_ACT the
* count.
DrawFruitRow
	lda	>G_LEVEL
	and	#$00FF
	cmp	#FRUIT_ROW_MAX
	bcc	:few
	lda	#FRUIT_ROW_MAX-1
:few	inc
	sta	<R_ACT
	stz	<R_TMP
	lda	#FRUIT_ROW_X
	sta	<R_X
	lda	#HUD_FRUIT_Y
	sta	<R_Y
]f	jsr	ScreenXY
	phb
	sep	#$20
	lda	#BANK_SHR
	pha
	plb
	rep	#$30
	lda	<R_TMP
	asl
	asl				; (type*2 + even parity) * 2
	tax
	ldy	<R_DEST
	jsr	FruitBlitGo
	plb
	lda	<R_X
	sec
	sbc	#SPR_CELL_W
	sta	<R_X
	inc	<R_TMP
	lda	<R_TMP
	cmp	#FRUIT_ROW_WIDE
	bne	:next
	lda	#FRUIT_ROW_X
	sta	<R_X
	lda	<R_Y
	clc
	adc	#SPR_CELL_H
	sta	<R_Y
:next	lda	<R_TMP
	cmp	<R_ACT
	bcc	]f
	rts

* Clear one sprite-cell-high band of the SHR: A = x, X = y, Y = width
* in pixels (all even).
ClearHud
	php
	rep	#$30
	sty	<R_TMP
	lsr	<R_TMP			; bytes per row
	sta	<R_X
	stx	<R_Y
	jsr	ScreenXY
	lda	#SPR_CELL_H
	sta	<R_ROW
	phb
	sep	#$20
	lda	#BANK_SHR
	pha
	plb
	rep	#$20
]r	ldy	<R_DEST
	ldx	<R_TMP
	sep	#$20
	lda	#0
]b	sta	$2000,y
	iny
	dex
	bne	]b
	rep	#$20
	lda	<R_DEST
	clc
	adc	#S_SHR
	sta	<R_DEST
	dec	<R_ROW
	bne	]r
	plb
	plp
	rts

* Adapter state, read with absolute addressing in the program bank.
LowerDP	dw	0	; lower.bin's direct page, bank $00
FULL_REDRAW	dw	0	; redraw every cell next pass
SH_HUD	ds	16	; score1 x3, hiscore x3, lives, level
SH_TILE	ds	$400	; last tile codes seen, 896 used
SH_COLOR	ds	$400	; last colors seen
MazeBank	dw	0	; LowerMazeBank: this level's maze bank
CellBank	ds	TILEMAP_CELLS	; per TILEMAP cell: color & $1F
