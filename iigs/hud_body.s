*
* Side HUD (gutters) + demo score / dot eating
*
* Text is arcade 6×6 glyph tiles: score digits $00–$09, ASCII $40–$5B (space
* $40). Tile art is single-ink (pen 3), so glyphs are recolored to R_PEN at
* blit time. HUD pixels go to SHR only — sprites never reach the gutters, so
* the BCK strip carries no HUD copy.
*
	mx	%00			; force 16-bit asm (compiled blit sep must not leak)

* Tile-code strings, $FF-terminated. Arcade writes "1UP" backwards (#50/#55/#31
* at descending VRAM addresses); upright we draw left→right.
HudStr1UP
	db	$31,$55,$50,$FF		; "1UP"
HudStrHighScore
	db	$48,$49,$47,$48,$40	; "HIGH "
	db	$53,$43,$4F,$52,$45	; "SCORE"
	db	$FF

InitHUD
* Demo state: no score, 10000 to beat, three lives, level 1 (cherry).
	php
	sep	#$30
	lda	#0
	sta	>SCORE_LO
	sta	>SCORE_MID
	sta	>SCORE_HI
	sta	>HISCORE_LO
	sta	>HISCORE_MID
	sta	>LEVEL
	lda	#$01
	sta	>HISCORE_HI		; BCD 01/00/00 = 10000
	lda	#START_LIVES
	sta	>LIVES
	plp
	rts

DrawSideHUD
* Level start: everything in both gutters.
	php
	rep	#$30
	jsr	DrawHudChrome
	jsr	DrawScore
	jsr	DrawHiscore
	jsr	DrawLives
	jsr	DrawLevelFruit
	plp
	rts

DrawHudChrome
* Static labels; redrawn only at level start.
	php
	rep	#$30
	lda	#COL_DIGIT
	sta	<R_PEN
	lda	#HUD_1UP_X
	sta	<R_X
	lda	#HUD_1UP_Y
	sta	<R_Y
	ldx	#HudStr1UP
	jsr	DrawHudString
	lda	#HUD_HS_LABEL_X
	sta	<R_X
	lda	#HUD_HS_LABEL_Y
	sta	<R_Y
	ldx	#HudStrHighScore
	jsr	DrawHudString
	plp
	rts

DrawHudString
* X = code-bank offset of a $FF-terminated tile-code string; R_X/R_Y = origin.
* Reads via DB=PHK so static ($02) and GS/OS (relocated code) both work.
* Advances R_X one glyph per character.
	php
	rep	#$30
	stx	<R_SAVE
	phb
	phk
	plb
]ch	ldx	<R_SAVE
	lda	|$0000,x
	and	#$00FF
	cmp	#$00FF
	beq	:done
	sta	<R_TILE
	jsr	BlitTileAbs
	lda	<R_X
	clc
	adc	#HUD_GLYPH_W
	sta	<R_X
	lda	<R_SAVE
	inc
	sta	<R_SAVE
	bra	]ch
:done	plb
	plp
	rts

DrawScore
	php
	rep	#$30
	lda	#COL_DIGIT
	sta	<R_PEN
	lda	#HUD_SCORE_X
	sta	<R_X
	lda	#HUD_SCORE_Y
	sta	<R_Y
	ldx	#0			; SCORE_LO + 0..2
	jsr	DrawScoreBCD
	plp
	rts

DrawHiscore
	php
	rep	#$30
	lda	#COL_DIGIT
	sta	<R_PEN
	lda	#HUD_HISCORE_X
	sta	<R_X
	lda	#HUD_HISCORE_Y
	sta	<R_Y
	ldx	#3			; SCORE_LO + 3..5 == HISCORE_LO..HI
	jsr	DrawScoreBCD
	plp
	rts

DrawScoreBCD
* X = byte offset from SCORE_LO (0=P1, 3=hiscore); R_X/R_Y = origin.
* Six digits high→low, blanking up to HUD_BLANK_LEAD leading zeros so a fresh
* score reads "00" like the arcade (j_2abe / j_2ace).
	php
	rep	#$30
	stx	<R_BASE
	lda	#HUD_BLANK_LEAD
	sta	<R_IDX			; leading blanks still allowed
	lda	#2
	sta	<R_ACT			; byte cursor: hi, mid, lo
]byte	lda	<R_BASE
	clc
	adc	<R_ACT
	tax
	lda	>SCORE_LO,x
	and	#$00FF
	sta	<R_SAVE			; BCD digit pair
	lsr
	lsr
	lsr
	lsr
	jsr	:digit
	lda	<R_SAVE
	and	#$000F
	jsr	:digit
	lda	<R_ACT
	dec
	sta	<R_ACT
	bpl	]byte
	plp
	rts
* A = digit 0..9 → glyph at R_X, then advance R_X.
:digit	cmp	#0
	bne	:ink
	lda	<R_IDX
	beq	:zero
	dec
	sta	<R_IDX
	lda	#TILE_EMPTY		; blank, not a zero
	bra	:put
:zero	lda	#TILE_DIGIT0
	bra	:put
:ink	clc
	adc	#TILE_DIGIT0
	pha
	lda	#0
	sta	<R_IDX			; first inked digit ends blanking
	pla
:put	sta	<R_TILE
	jsr	BlitTileAbs
	lda	<R_X
	clc
	adc	#HUD_GLYPH_W
	sta	<R_X
	rts

DrawLives
* LIVES icons left gutter, one sprite cell apart. Masked blit over black.
	php
	rep	#$30
	lda	>LIVES
	and	#$00FF
	beq	:done
	sta	<R_ACT
	lda	#HUD_LIVES_X
	sta	<R_X
	lda	#HUD_LIVES_Y
	sta	<R_Y
]life	jsr	ScreenXY
	phb
	sep	#$20
	lda	#BANK_SHR
	pha
	plb
	rep	#$30
	ldx	#MSPAC_LIFE_SPR*4	; (slot*2 + even parity) * 2
	lda	<R_DEST
	tay
	jsr	MsPacBlitGo
	plb
	lda	<R_X
	clc
	adc	#HUD_LIVES_DX
	sta	<R_X
	lda	<R_ACT
	dec
	sta	<R_ACT
	bne	]life
:done	plp
	rts

DrawLevelFruit
* Level fruit icon, right gutter. Arcade j_8793 holds at banana past level 7.
	php
	rep	#$30
	lda	>LEVEL
	and	#$00FF
	cmp	#MAX_FRUIT_TYPE+1
	bcc	:ok
	lda	#MAX_FRUIT_TYPE
:ok	asl
	asl				; (type*2 + even parity) * 2
	sta	<R_TMP
	lda	#HUD_FRUIT_X
	sta	<R_X
	lda	#HUD_FRUIT_Y
	sta	<R_Y
	jsr	ScreenXY
	phb
	sep	#$20
	lda	#BANK_SHR
	pha
	plb
	rep	#$30
	ldx	<R_TMP
	lda	<R_DEST
	tay
	jsr	FruitBlitGo
	plb
	plp
	rts

BlitTileAbs
* R_X (even) / R_Y = absolute screen pixel, R_TILE = tile code, R_PEN = ink.
* Opaque 6×6 into SHR only; pen 0 stays black, so redraws need no clear.
	php
	rep	#$30
	jsr	ScreenXY
	lda	<R_TILE
	and	#$00FF
	jsr	Mul18
	tax				; tile source offset
	lda	#6
	sta	<R_ROW
	lda	<R_DEST
	tay
	phb
	sep	#$20
	lda	#BANK_SHR
	pha
	plb
	rep	#$10			; A 8-bit for nibble work, X/Y 16-bit
]row	lda	>AST_TILES,x
	jsr	RemapInkByte
	sta	$2000,y
	inx
	iny
	lda	>AST_TILES,x
	jsr	RemapInkByte
	sta	$2000,y
	inx
	iny
	lda	>AST_TILES,x
	jsr	RemapInkByte
	sta	$2000,y
	inx				; X = next tile row
	rep	#$30
	tya
	clc
	adc	#S_SHR-2		; Y already walked 2 of this row
	tay
	lda	<R_ROW
	dec
	sta	<R_ROW
	beq	:done
	sep	#$20
	bra	]row
:done	plb
	plp
	rts

RemapInkByte
* A (8-bit) = one packed tile byte (two 4bpp pixels). Tile glyphs are drawn in
* a single arcade ink pen, so any nonzero nibble becomes R_PEN.
	pha
	and	#$F0
	beq	:hi0
	lda	<R_PEN
	asl
	asl
	asl
	asl
	bra	:lonib
:hi0	lda	#0
:lonib	sta	<R_BTMP
	pla
	and	#$0F
	beq	:lo0
	lda	<R_PEN
	ora	<R_BTMP
	rts
:lo0	lda	<R_BTMP
	rts

DemoScoreTick
* Demo: +10 points every SCORE_PERIOD frames (FRAME_COUNT already bumped).
	php
	rep	#$30
	lda	>FRAME_COUNT
	beq	:done
	sta	<R_TMP
	lda	#SCORE_PERIOD
	sta	<R_ACT
* 16-bit remainder — do not AND #$00FF (remainder 256 would look like 0)
	lda	<R_TMP
:div	cmp	<R_ACT
	bcc	:rem
	sec
	sbc	<R_ACT
	bra	:div
:rem	cmp	#0
	bne	:done
	jsr	ScoreAdd10
	jsr	DrawScore
	jsr	CheckHighScore
:done	plp
	rts

ScoreAdd10
* +$10 through the 3-byte BCD score — 65816 decimal mode does the arcade's
* add/daa chain (j_2a65). PLP restores D, but clear it explicitly anyway.
	php
	sep	#$20
	sed
	clc
	lda	>SCORE_LO
	adc	#$10
	sta	>SCORE_LO
	lda	>SCORE_MID
	adc	#$00
	sta	>SCORE_MID
	lda	>SCORE_HI
	adc	#$00
	sta	>SCORE_HI
	cld
	plp
	rts

CheckHighScore
* Compare P1 vs high score MSB→LSB (arcade j_2a91); copy + redraw when beaten.
	php
	sep	#$30
	lda	>SCORE_HI
	cmp	>HISCORE_HI
	bcc	:done
	bne	:beat
	lda	>SCORE_MID
	cmp	>HISCORE_MID
	bcc	:done
	bne	:beat
	lda	>SCORE_LO
	cmp	>HISCORE_LO
	bcc	:done
	beq	:done
:beat	lda	>SCORE_LO
	sta	>HISCORE_LO
	lda	>SCORE_MID
	sta	>HISCORE_MID
	lda	>SCORE_HI
	sta	>HISCORE_HI
	rep	#$30
	jsr	DrawHiscore
:done	plp
	rts

EatDotsAtPac
* Tile under Ms. Pac: clear any dot / power pill from TILEMAP and queue the
* cell so ApplyDirty writes empty into SHR *and* BCK — otherwise the next
* EraseSprite would restore the eaten pellet from the backing store.
	php
	rep	#$30
	ldx	#80			; PAC_ACTOR base
	lda	>ACTORS+ACT_X,x
	sec
	sbc	#SPR_BASE_X
	bcc	:done			; left of the playfield
	jsr	Div6
	cmp	#PF_COLS
	bcs	:done
	sta	<R_TX
	ldx	#80
	lda	>ACTORS+ACT_Y,x
	sec
	sbc	#SPR_BASE_Y
	bcc	:done
	jsr	Div6
	cmp	#PF_ROWS
	bcs	:done
	sta	<R_TY
* idx = ty*28 + tx, as ty*32 - ty*4 (same shape as ApplyDirty)
	lda	<R_TY
	asl
	asl
	asl
	asl
	asl
	sta	<R_TMP
	lda	<R_TY
	asl
	asl
	sta	<R_OFF
	lda	<R_TMP
	sec
	sbc	<R_OFF
	clc
	adc	<R_TX
	tax
	lda	>TILEMAP,x
	and	#$00FF
	cmp	#TILE_DOT
	beq	:eat
	cmp	#TILE_POWER
	bne	:done
:eat	sep	#$20
	lda	#TILE_EMPTY
	sta	>TILEMAP,x
	rep	#$30
	lda	>DIRTY_COUNT
	asl
	tax
	sep	#$20
	lda	<R_TX
	sta	>DIRTY_LIST,x
	lda	<R_TY
	sta	>DIRTY_LIST+1,x
	rep	#$30
	lda	>DIRTY_COUNT
	inc
	sta	>DIRTY_COUNT
:done	plp
	rts

Div6
* A = A / 6 for small positives (sprite pixel → tile). 16-bit A in and out.
* No php/plp: callers branch on the returned quotient. Clobbers R_TMP/R_OFF.
	sta	<R_TMP
	lda	#0
	sta	<R_OFF
]d6	lda	<R_TMP
	cmp	#6
	bcc	:out
	sec
	sbc	#6
	sta	<R_TMP
	lda	<R_OFF
	inc
	sta	<R_OFF
	bra	]d6
:out	lda	<R_OFF
	rts
