*
* Maze collision / dots / board-clear helpers.
* Wall test mirrors arcade (tile & $C0) == $C0 via TILEMAP.
* == j_200f / j_0065 / j_94a1 (maze1 pellet total)
*
	mx	%00

* Arcade tile Y,X → TILEMAP index in 16-bit A (or $FFFF if OOB).
* Leaves m=0 (16-bit A). Entry: A=tile_y, X=tile_x as 8-bit values.
* our_tx = 27-(tile_x-$20), our_ty = (tile_y-$20)-1
ArcadeTileIndex
	sep	#$30
	sta	<R_TMP
	stx	<R_OFF
	lda	<R_TMP
	sec
	sbc	#$20
	dec				; our_ty
	cmp	#PF_ROWS
	bcs	:oob8
	sta	<R_TY
	lda	<R_OFF
	sec
	sbc	#$20
	sta	<R_ACT
	lda	#27
	sec
	sbc	<R_ACT			; our_tx
	cmp	#PF_COLS
	bcs	:oob8
	sta	<R_TX
	rep	#$30
	lda	<R_TY
	and	#$00FF
	asl
	asl
	asl
	asl
	asl				; *32
	sta	<R_TMP
	lda	<R_TY
	and	#$00FF
	asl
	asl				; *4
	sta	<R_OFF
	lda	<R_TMP
	sec
	sbc	<R_OFF			; *28
	sta	<R_TMP
	lda	<R_TX
	and	#$00FF			; DP word may have junk hi from prior 16-bit ops
	clc
	adc	<R_TMP			; 0..867
	rts
:oob8	rep	#$30
	lda	#$FFFF
	rts

TILEMAP_CELLS  equ 868		; 28*31

* A=tile_y, X=tile_x → carry set if wall (or OOB). Preserves caller MX via php/plp.
IsWallArcade
	php
	sep	#$30
	jsr	ArcadeTileIndex
* Merlin does not track MX across JSR — force 16-bit before word immediates
* (else cmp #$FFFF / #868 assemble as C9 FF / C9 64 and desync the stream).
	rep	#$30
	cmp	#$FFFF
	beq	:wall
	cmp	#TILEMAP_CELLS
	bcs	:wall
	tax
	lda	>TILEMAP,x
	and	#$00C0
	cmp	#$00C0
	beq	:wall
	plp
	clc
	rts
:wall	plp
	sec
	rts

QueueDirty
	php
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
	plp
	rts

EatAtPacTile
* == j_1806 eat path (partial)
	php
	sep	#$30
	lda	>PAC_TILE_X		; LDX has no 24-bit form (GS/OS EXT)
	tax
	lda	>PAC_TILE_Y
	jsr	ArcadeTileIndex
	rep	#$30			; word cmps (Merlin MX across JSR)
	cmp	#$FFFF
	bne	:in
	plp
	rts
:in	cmp	#TILEMAP_CELLS
	bcc	:ok
	plp
	rts
:ok	tax
	lda	>TILEMAP,x
	and	#$00FF
	cmp	#TILE_DOT
	beq	:dot
	cmp	#TILE_POWER
	beq	:pow
	plp
	rts
:pow	jsr	EatPowerAtX		; X = tilemap index
	plp
	rts
:dot	sep	#$20
	lda	#TILE_EMPTY
	sta	>TILEMAP,x
	lda	#$01			; == j_19fd: pac_move_delay = 1 (dot)
	sta	>PAC_MOVE_DELAY
	lda	>DOTS_EATEN
	inc
	sta	>DOTS_EATEN
	jsr	HouseDotInc
	rep	#$30
	jsr	DirtyFromIndex
	jsr	ScoreAdd10
	jsr	DrawScore
	jsr	CheckHighScore
	plp
	rts

* X = tilemap index of energizer. == j_1a70 side effects
EatPowerAtX
	php
	sep	#$20
	lda	#TILE_EMPTY
	sta	>TILEMAP,x
	lda	#$06			; == j_19fc: pac_move_delay = 6 (energizer)
	sta	>PAC_MOVE_DELAY
	lda	#1
	sta	>POWER_PILL_ACT
	sta	>RED_FRIGHT
	sta	>PINK_FRIGHT
	sta	>BLUE_FRIGHT
	sta	>ORANGE_FRIGHT
	sta	>RED_REVERSE
	sta	>PINK_REVERSE
	sta	>BLUE_REVERSE
	sta	>ORANGE_REVERSE
	lda	#0
	sta	>FRIGHT_FLASH_CNT
	sta	>FRIGHT_FLASH_PHASE
	sta	>GHOSTS_KILLED_COUNT	; == #1A9A
	sta	>GHOSTS_KILLED_PENDING
	sta	>KILLED_GHOST_ANIM
	sta	>EAT_FREEZE_TIMER
	sta	>KILL_GHOST_STATE
	rep	#$30
	lda	>FRIGHT_TIME		; #4DBD → #4DCB
	sta	>FRIGHT_TIMER
	phx
	sep	#$20
	lda	>DOTS_EATEN
	inc
	sta	>DOTS_EATEN
	jsr	HouseDotInc
	rep	#$30
	plx
	jsr	DirtyFromIndex
	jsr	ScoreAdd50
	jsr	DrawScore
	jsr	CheckHighScore
	plp
	rts

DirtyFromIndex
* X = tilemap index → R_TX/R_TY + QueueDirty
	php
	rep	#$30
	txa
	sta	<R_TMP
	lda	#0
	sta	<R_TY
	lda	<R_TMP
:div	cmp	#28
	bcc	:rem
	sec
	sbc	#28
	sta	<R_TMP
	lda	<R_TY
	inc
	sta	<R_TY
	lda	<R_TMP
	bra	:div
:rem	sta	<R_TX
	jsr	QueueDirty
	plp
	rts

ScoreAdd50
	php
	jsr	ScoreAdd10
	jsr	ScoreAdd10
	jsr	ScoreAdd10
	jsr	ScoreAdd10
	jsr	ScoreAdd10
	plp
	rts

CheckBoardClear
* == j_08de / j_94a1
	php
	sep	#$20
	lda	>DOTS_EATEN
	cmp	#PELLET_TARGET
	bcc	:no
	lda	#CLEAR_DELAY+{8*CLEAR_STEP}
	sta	>CLEAR_TIMER
	lda	#12
	sta	>LEVEL_STATE
:no	plp
	rts
