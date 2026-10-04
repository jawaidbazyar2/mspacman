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
*   HUD      the BCD scores, lives, level and credits, into the side HUD
*   input    the keyboard into the IN0/IN1 bytes of the host block
*   sound    the voice registers at $5040 into DOC oscillators 0-2
*            (lower_sound.s)
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
G_PAC_DEATH	equ	GAME+$4DA5	; pac_death_anim, 0 while alive
G_FRUIT_POS	equ	GAME+$4DD2
G_LEVEL	equ	GAME+$4E13
G_LIVES	equ	GAME+$4E15
G_SCORE1	equ	GAME+$4E80	; 3 bytes BCD, low first
G_HISCORE	equ	GAME+$4E88
G_CREDITS	equ	GAME+$4E6E	; BCD, $FF free play
G_MODE	equ	GAME+$4E00	; game_mode
G_SUB2	equ	GAME+$4E03	; game_mode_sub2 (press-start step)
G_EFFNUM	equ	GAME+$4E9C	; effect channel 1 request bits
G_EFFCUR	equ	GAME+$4E9E	; effect channel 1 bit now playing
G_HB	equ	GAME+$F000
G_IN0	equ	GAME+$F010
G_IN1	equ	GAME+$F011
G_DSW1	equ	GAME+$F012
G_REPLAY	equ	GAME+$F013
G_VID_FULL	equ	GAME+$F200	; video change log (lower/dp.s VID_*)
G_VID_N	equ	GAME+$F202
G_VID_LOG	equ	GAME+$F204
G_RC_KEY	equ	GAME+$F800	; LowerDrawCell's remap cache, 32-byte slots:
G_RC_BUF	equ	GAME+$F802	; bank << 8 | tile, then its 18 bytes
RC_SLOTS	equ	64

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
	jsr	SoundInit
	jsr	WaitVBL

MainLoop
* One color per activity (BRD_* in equates.s). Erase, draw and sort paint
* their own; everything else is painted here so a color cannot stick
* past the routine that owns it. FrameDone is the check breakpoint and
* stays on the sound color. Check mode mirrors the DOC before that
* breakpoint. In play, CoinSoundGate holds a new credit silent until
* the push-start blit has finished, so the opening is not stretched
* across it.
	sep	#$20
	jsr	LowerKeys
	bcc	:run
	brl	:exit
:run	rep	#$30
	lda	>DEMO_FREEZE
	and	#$00FF
	beq	:live
	brl	:frozen
:live
	jsr	EraseAllSprites		; purple
	lda	#BRD_TILES
	jsr	SetBorder
	jsr	LowerApplyTiles
	jsr	DrawAllSprites		; green
	lda	#BRD_COPY
	jsr	SetBorder
	jsr	CopySpritePos
	lda	#BRD_TICK
	jsr	SetBorder
	jsr	CallFrame
	lda	|CheckMode
	and	#$00FF
	bne	:chk
	lda	#BRD_DIFF
	jsr	SetBorder
	jsr	LowerTiles
	jsr	CoinSoundGate
	bcs	:held
	lda	#BRD_SOUND
	jsr	SetBorder
	jsr	LowerSound
	bra	:fd
:held	lda	#BRD_SOUND
	jsr	SetBorder
:fd	jsr	FrameDone
	bra	:adapt
:chk	lda	#BRD_SOUND
	jsr	SetBorder
	jsr	LowerSound
	jsr	FrameDone
	lda	#BRD_DIFF
	jsr	SetBorder
	jsr	LowerTiles
:adapt
	lda	#BRD_ACTOR
	jsr	SetBorder
	jsr	LowerSprites
	lda	#BRD_HUD
	jsr	SetBorder
	jsr	LowerHud
	lda	#ACT_OY
	jsr	SortActorsByY		; yellow
	lda	>G_REPLAY
	and	#$00FF
	beq	:vbl
	brl	MainLoop
:vbl	jsr	WaitVBL			; black
	brl	MainLoop
* Hold white across the blank. WaitVBL would paint black immediately.
:frozen	lda	#BRD_FREEZE
	jsr	SetBorder
	sep	#$20
]fw1	lda	>RDVBLBAR
	bmi	]fw1
]fw2	lda	>RDVBLBAR
	bpl	]fw2
	rep	#$30
	brl	MainLoop
:exit	jmp	ExitDemo

ExitDemo
	jsr	SoundOff
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
:adapt	lda	#1
	sta	>G_VID_FULL
	lda	#0
	sta	>G_VID_N
	lda	#$FFFF
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
	ldx	#RC_SLOTS*32-32
]rc	sta	>G_RC_KEY,x
	txa
	sec
	sbc	#32
	tax
	lda	#$FFFF
	bcs	]rc
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
LT_N	equ	$56	; VID_N, the log's length in bytes

* Changed cells to TILEMAP and the dirty list, or to a full redraw.
* VID_FULL: diff every cell against the last pass. Otherwise only the
* cells the game logged; a tile or color address both name the cell at
* (addr & $3FF) - $40, the offset :cell takes.
LowerTiles
	php
	jsr	LowerMazeBank
	sep	#$20
	lda	>G_VID_FULL
	bne	:full
	rep	#$30
	lda	>G_VID_N
	and	#$00FF
	beq	:pens
	sta	<LT_N
	ldy	#0
]l	tyx
	lda	>G_VID_LOG,x
	and	#$03FF
	sec
	sbc	#$0040
	bcc	:nx			; bottom chrome rows
	cmp	#$0380			; top chrome rows
	bcs	:nx
	tax
* :cell is for cells that changed. Text is rewritten every frame on
* some screens, and a logged cell may repeat.
	sep	#$20
	lda	>G_TILE,x
	cmp	|SH_TILE,x
	bne	:lchg
	lda	>G_COLOR,x
	cmp	|SH_COLOR,x
	beq	:lsame
:lchg	rep	#$20
	phy
	jsr	:cell
	ply
:lsame	rep	#$20
:nx	iny
	iny
	cpy	<LT_N
	bcc	]l
	lda	#0
	sta	>G_VID_N
:pens	rep	#$30
	jsr	LowerMazePens
	plp
	rts
:full	rep	#$30
	lda	#0
	sta	>G_VID_FULL
	sta	>G_VID_N
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
	jsr	LowerMazePens
	plp
	rts
:chg	phx
	jsr	:cell
	inx
	jsr	:cell
	plx
	bra	:next

* One cell, X = its offset from $4040. Keeps X. The level-end flash
* (task #01, #24D7) repaints the playfield between the maze bank and #1F
* with the tiles unchanged: that only sets MazeFlash, for LowerMazePens.
:cell	sep	#$20
	lda	>G_TILE,x
	cmp	|SH_TILE,x
	bne	:draw
	lda	|SH_COLOR,x
	jsr	:mz
	bcc	:draw
	lda	>G_COLOR,x
	jsr	:mz
	bcc	:draw
	lda	>G_COLOR,x
	cmp	|SH_COLOR,x
	beq	:kept
	sta	|SH_COLOR,x
	and	#$1F
	cmp	#FLASH_BANK		; C = flashed
	lda	#0
	rol
	sta	|MazeFlash
:kept	rep	#$20
	rts
	mx	%10
:draw	lda	>G_TILE,x
	sta	|SH_TILE,x
	sta	<R_TILE
	lda	>G_COLOR,x
	sta	|SH_COLOR,x
	and	#$1F
	beq	:blank
	cmp	#FLASH_BANK
	bne	:bank
	ldy	|MazeFlash
	beq	:bank
	lda	|MazeBank		; flashed maze cell: the maze sheet
:bank	sta	<LT_BANK
	bra	:lit
:blank	sta	<LT_BANK
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

* C = A's bank (low 5 bits) is the maze's or the flash's. 8-bit A.
	mx	%10
:mz	and	#$1F
	cmp	#FLASH_BANK
	beq	:mzy
	cmp	|MazeBank
	beq	:mzy
	clc
	rts
:mzy	sec
	rts
	mx	%00

* Maze wall pens to the flash or the maze bank, when MazeFlash changed.
LowerMazePens
	lda	|MazeFlash
	and	#$00FF
	cmp	|MazeFlashShown
	beq	:done
	sta	|MazeFlashShown
	tax
	lda	|MazeBank
	cpx	#0
	beq	:set
	lda	#FLASH_BANK
:set	jsr	SetMazePens
:done	rts

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
	jsr	ReleaseCoinSound
	plp
	rts

* The credit chime (effect channel 1, bit 1) is requested a couple of
* frames before draw_prompt's screen clear, and the hardware registers
* the DOC mirrors lag the engine by one frame. Left alone, the opening
* slice is what the DOC is playing while LowerApplyTiles repaints every
* cell, so that slice is held for the whole blit.
*
* In play, hold the DOC silent from the request until that blit
* finishes, then clear the channel's current bit so the engine reloads
* the effect. The release frame's mirror is the pre-reload registers;
* skip it. The next frame's mirror is the first slice, with the
* push-start screen already up. A credit once that screen is up
* (press-start step already running) plays immediately. Check mode
* never calls this.
*
* Carry set: leave the DOC alone. Carry clear: call LowerSound.
* M and X are preserved.
	mx	%00
CREDIT_BIT	equ	$02
MODE_PRESS_START	equ	2
CoinSoundGate
	php
	sep	#$20
	lda	>G_EFFNUM
	and	#CREDIT_BIT
	bne	:on
	stz	|CreditOn
	lda	|SoundHold
	beq	:out
	stz	|SoundHold
	bra	:out
:on	lda	|CreditOn
	bne	:busy
	lda	#1
	sta	|CreditOn
	lda	>G_MODE
	cmp	#MODE_PRESS_START
	bne	:arm
	lda	>G_SUB2
	beq	:arm
	bra	:play
:arm	lda	#1
	sta	|SoundHold
	stz	|HoldTimer
	jsr	SoundMute
	bra	:skip
:busy	lda	|SoundHold
	beq	:play
	cmp	#3
	beq	:once
	cmp	#1
	bne	:skip
	lda	|FULL_REDRAW
	beq	:tick
	lda	#2
	sta	|SoundHold
	bra	:skip
:tick	inc	|HoldTimer
	lda	|HoldTimer
	cmp	#8
	bcc	:skip
	lda	#3
	sta	|SoundHold
	lda	#0
	sta	>G_EFFCUR
	bra	:skip
:once	stz	|SoundHold
	bra	:skip
:play	stz	|SoundHold
:out	plp
	clc
	rts
:skip	plp
	sec
	rts

* Called at the end of a full redraw. State 2 means this blit is the
* one the credit chime was waiting on: restart the effect and skip the
* stale mirror later this frame.
ReleaseCoinSound
	php
	sep	#$20
	lda	|SoundHold
	cmp	#2
	bne	:no
	lda	#3
	sta	|SoundHold
	stz	|HoldTimer
	lda	#0
	sta	>G_EFFCUR
:no	plp
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
* $95AE lookup, folds included. When it changes, MazeSheet is rebuilt:
* every tile resolved through it as a maze (walls on the maze pens), so
* maze cells draw without a remap; and the maze pens get its colors.
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
	lda	>GAME+$95AE,x
	and	#$001F
	cmp	|MazeBank
	beq	:same
	sta	|MazeBank
	jsr	SetMazePens
	stz	|MazeFlash
	stz	|MazeFlashShown
	lda	|MazeBank
	clc
	adc	#32			; its maze row of TileBankPens
	sta	<LT_BANK
	stz	<R_TILE
	ldy	#0
]t	phy
	jsr	LowerRemapTile
	ply
	ldx	#0
]c	lda	<LT_BUF,x
	sta	|MazeSheet,y
	iny
	iny
	inx
	inx
	cpx	#18
	bcc	]c
	inc	<R_TILE
	lda	<R_TILE
	cmp	#256
	bcc	]t
:same	plp
	rts
	mx	%00

* Draw TILEMAP cell X (R_TX, R_TY, R_TILE set) in its bank's colors.
* Maze cells come from MazeSheet; raw: banks whose map is the identity,
* and blanks.
LowerDrawCell
	lda	|CellBank,x
	and	#$001F
	cmp	|MazeBank
	beq	:maze
	tay
	lda	|TileBankRaw,y
	and	#$00FF
	bne	:raw
	lda	<R_TILE
	cmp	#TILE_EMPTY
	beq	:raw
	sty	<LT_BANK
	jmp	LowerCachedTile
:maze	lda	<R_TILE
	jsr	Mul18
	tay
	ldx	#0
]c	lda	|MazeSheet,y
	sta	<LT_BUF,x
	iny
	iny
	inx
	inx
	cpx	#18
	bcc	]c
	jmp	LowerDrawTileBuf
:raw	jmp	DrawTile

* R_TILE in bank LT_BANK (Y) through LowerRemapTile, or from the remap
* cache when the slot holds that tile and bank.
LowerCachedTile
	tya
	asl
	asl
	asl
	eor	<R_TILE
	and	#RC_SLOTS-1
	asl
	asl
	asl
	asl
	asl
	tax
	tya
	xba
	ora	<R_TILE
	cmp	>G_RC_KEY,x
	beq	:hit
	pha
	phx
	jsr	LowerRemapTile
	plx
	pla
	sta	>G_RC_KEY,x
	lda	<LT_BUF
	sta	>G_RC_BUF,x
	lda	<LT_BUF+2
	sta	>G_RC_BUF+2,x
	lda	<LT_BUF+4
	sta	>G_RC_BUF+4,x
	lda	<LT_BUF+6
	sta	>G_RC_BUF+6,x
	lda	<LT_BUF+8
	sta	>G_RC_BUF+8,x
	lda	<LT_BUF+10
	sta	>G_RC_BUF+10,x
	lda	<LT_BUF+12
	sta	>G_RC_BUF+12,x
	lda	<LT_BUF+14
	sta	>G_RC_BUF+14,x
	lda	<LT_BUF+16
	sta	>G_RC_BUF+16,x
	jmp	LowerDrawTileBuf
:hit	lda	>G_RC_BUF,x
	sta	<LT_BUF
	lda	>G_RC_BUF+2,x
	sta	<LT_BUF+2
	lda	>G_RC_BUF+4,x
	sta	<LT_BUF+4
	lda	>G_RC_BUF+6,x
	sta	<LT_BUF+6
	lda	>G_RC_BUF+8,x
	sta	<LT_BUF+8
	lda	>G_RC_BUF+10,x
	sta	<LT_BUF+10
	lda	>G_RC_BUF+12,x
	sta	<LT_BUF+12
	lda	>G_RC_BUF+14,x
	sta	<LT_BUF+14
	lda	>G_RC_BUF+16,x
	sta	<LT_BUF+16
	jmp	LowerDrawTileBuf

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
LS_FR	equ	$3C
PP	equ	12		; Pac-Man poses follow Ms. Pac's 12 in MsPacBlitTable

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
	and	#$FF-FLAG_POINTS-FLAG_CHAR
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

* Ghost: walking frames $20-$27, eyes, points, or frightened ($1C-$1D):
* color $11 blue, $12 the flash's white. Body color follows the sprite
* color byte ($01/$03/$05/$07), and bits 7/6 mirror the frame, so a
* cutscene ghost on another slot keeps its own color and facing.
* Pac-Man and Ms. Pac-Man in the acts use these same slots; their codes
* publish FLAG_CHAR and a pose in MsPacBlitTable.
:ghost	ldx	<LS_BASE
	sep	#$20
	lda	<LS_CODE
	and	#$3F
	cmp	#$28
	bcs	:pts
	cmp	#$1C
	bcs	:chkFright
	jmp	:maybeChar
:chkFright
	cmp	#$1E
	bcs	:notBlue
	jmp	:blue
:notBlue
	cmp	#$20
	bcs	:walk
	jmp	:gone
:walk	sec
	sbc	#$20
	tay
	lda	<LS_CODE
	and	#$C0
	lsr
	lsr
	lsr
	sta	<LS_FR
	tya
	clc
	adc	<LS_FR
	tay
	lda	|:flipTab,y
	clc
	adc	#$20
	sta	>ACTORS+ACT_SPR,x
	lda	<LS_COLOR
	cmp	#$19
	beq	:eyes
	cmp	#$01
	beq	:red
	cmp	#$03
	beq	:pink
	cmp	#$05
	beq	:inky
	cmp	#$07
	beq	:clyde
	lda	<LS_SLOT
	clc
	adc	#COL_BLINKY
	bra	:col
:red	lda	#COL_BLINKY
	bra	:col
:pink	lda	#COL_PINKY
	bra	:col
:inky	lda	#COL_INKY
	bra	:col
:clyde	lda	#COL_CLYDE
	bra	:col
:eyes	lda	#COL_EYES
	bra	:col
:blue	and	#1
	sta	>ACTORS+ACT_SPR,x
	lda	<LS_COLOR
	cmp	#$12
	lda	#COL_FRIGHT
	bcc	:col
	lda	#COL_FLASH
:col	sta	>ACTORS+ACT_COLOR,x
	rep	#$20
	rts
	mx	%10
:pts	cmp	#$2C
	bcs	:maybeChar
	sta	>ACTORS+ACT_SPR,x
	lda	>ACTORS+ACT_FLAGS,x
	ora	#FLAG_POINTS
	sta	>ACTORS+ACT_FLAGS,x
	rep	#$20
	rts
	mx	%10
:maybeChar
	jsr	:charSpr
	bcs	:gotChar
	jmp	:gone
:gotChar
	sta	>ACTORS+ACT_SPR,x
	lda	>ACTORS+ACT_FLAGS,x
	ora	#FLAG_CHAR
	sta	>ACTORS+ACT_FLAGS,x
	rep	#$20
	rts
	mx	%10
* A = index (code & $3F). X preserved. SEC and A = blit pose, or CLC.
* Bit 7 of LS_CODE is an upright H flip, bit 6 an upright V flip.
* Pac mouth order is wide, partial, closed. Ms. Pac poses are 0..11.
:charSpr
	cmp	#$32
	beq	:cClosed
	cmp	#$19
	beq	:c19
	cmp	#$1A
	beq	:c1A
	cmp	#$1B
	beq	:c1B
	cmp	#$2E
	beq	:c2E
	cmp	#$2D
	beq	:c2D
	cmp	#$2F
	beq	:c2F
	cmp	#$37
	beq	:c37
	cmp	#$31
	beq	:c31
	cmp	#$33
	beq	:c33
	cmp	#$34
	beq	:c34
	cmp	#$35
	beq	:c35
	cmp	#$36
	bne	:cNo
	lda	#10			; $36 north, open
	bra	:cYes
:c34	lda	#3			; $34 south, closed
	bra	:cYes
:c35	lda	#6			; $35 west, closed
	bra	:cYes
:cClosed
	lda	#PP+2			; $32 circle
	bra	:cYes
:c19	lda	#PP+1			; $19 east partial; +H west
	ldy	#PP+7
	bra	:cH
:c1B	lda	#PP			; $1B east wide; +H west
	ldy	#PP+6
	bra	:cH
:c1A	lda	#PP+3			; $1A south wide; +V north
	ldy	#PP+9
	bra	:cV
:c2E	lda	#PP+4			; $2E south partial; +V north
	ldy	#PP+10
	bra	:cV
:c2D	lda	#2			; $2D east; +H west
	ldy	#7
	bra	:cH
:c2F	lda	#0			; $2F east; +H west
	ldy	#8
	bra	:cH
:c37	lda	#1			; $37 east closed; +H west closed
	ldy	#6
	bra	:cH
:c31	lda	#4			; $31 south; +HV north
	ldy	#11
	bra	:cHV
:c33	lda	#5			; $33 south; +HV north
	ldy	#9
:cHV	bit	<LS_CODE
	bpl	:cYes
	bvc	:cYes
	tya
	bra	:cYes
:cH	bit	<LS_CODE
	bpl	:cYes
	tya
	bra	:cYes
:cV	bit	<LS_CODE
	bvc	:cYes
	tya
:cYes	sec
	rts
:cNo	clc
	rts
:gone	rep	#$20
	jmp	:hide
* frame 0..7 is E0,E1,S0,S1,W0,W1,N0,N1. Groups: none, V, H, HV.
:flipTab
	db	0,1,2,3,4,5,6,7
	db	0,1,6,7,4,5,2,3
	db	4,5,2,3,0,1,6,7
	db	4,5,6,7,0,1,2,3

* Ms. Pac-Man: the pose for her direction, closed or one of the open
* mouths. While she is dying, codes $34-$3F are the spin. The ROM
* stores that as south, west, north, east, repeated, and $3F holds
* north. An index below $20 is a cutscene prop on her slot (the act
* clapper); hide it.
:pac	ldx	<LS_BASE
	lda	<LS_CODE
	and	#$003F
	cmp	#$0020
	bcs	:body
	jmp	:hide
:body	lda	>G_PAC_DEATH
	and	#$00FF
	beq	:dir
	lda	<LS_CODE
	and	#$003F
	cmp	#$34
	bcc	:dir
	sec
	sbc	#$34
	tay
	sep	#$20
	lda	|:spin,y
	sta	>ACTORS+ACT_SPR,x
	rep	#$20
	rts
:dir	lda	>G_PAC_DIR
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
* $34-$3F: S W N E, S W N E, S W N, and $3F holds north (poses 3,6,10,1).
:spin	db	3,6,10,1,3,6,10,1,3,6,10,10

* Fruit: codes $00-$07. Eat-fruit score is fruit_points+2 → $08-$0F
* (100/200/500/700/1000/2000/5000); FLAG_POINTS selects those blits.
:fruit	ldx	<LS_BASE
	sep	#$20
	lda	<LS_CODE
	and	#$3F
	cmp	#8
	bcc	:fok
	cmp	#$10
	bcs	:fgone
	sta	>ACTORS+ACT_SPR,x
	lda	>ACTORS+ACT_FLAGS,x
	ora	#FLAG_POINTS
	sta	>ACTORS+ACT_FLAGS,x
	rep	#$20
	rts
:fok	sta	>ACTORS+ACT_SPR,x
	rep	#$20
	rts
:fgone	rep	#$20
	jmp	:hide

*------------------------------------------------------------------
* Side HUD: player 1's score, the high score, lives, level and credits,
* redrawn when they change.
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
	beq	:credit
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
	sep	#$30
* show_credits writes the bottom chrome, which LowerTiles drops.
:credit	lda	>G_CREDITS
	cmp	|SH_HUD+8
	beq	:done
	sta	|SH_HUD+8
	sta	>CREDITS
	rep	#$30
	jsr	DrawCredits
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
* Credit chime vs the push-start blit. 0 play. 1 mute until a full
* redraw is requested. 2 mute until that redraw is applied. 3 skip the
* stale voice-register mirror on the release frame.
SoundHold	db	0
CreditOn	db	0	; effect channel 1's credit bit has been seen
HoldTimer	db	0
SH_HUD	ds	16	; score1 x3, hiscore x3, lives, level, credits
SH_TILE	ds	$400	; last tile codes seen, 896 used
SH_COLOR	ds	$400	; last colors seen
MazeBank	dw	$FFFF	; LowerMazeBank: this level's maze bank (none yet)
MazeFlash	dw	0	; LowerTiles: playfield painted #1F (level-end flash)
MazeFlashShown	dw	0	; MazeFlash the maze pens hold
CellBank	ds	TILEMAP_CELLS	; per TILEMAP cell: color & $1F
MazeSheet	ds	256*18	; every tile resolved through MazeBank
