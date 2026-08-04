*
* level_state machine (maze-only) — == j_06be subset.
*
	mx	%00

LevelFsm
* == j_06be dispatch (play / death / clear only)
	php
	sep	#$20
	lda	>LEVEL_STATE
	cmp	#3
	beq	:play
	cmp	#4
	beq	:death
	cmp	#12
	beq	:clear
	bra	:done
:play	jsr	PlayTick
	bra	:done
:death
	lda	>DEATH_TIMER
	beq	:dorel
	lda	>DEATH_TIMER
	dec
	sta	>DEATH_TIMER
	bra	:done
:dorel
	lda	>LIVES
	beq	:gameover
	lda	>LIVES
	dec
	sta	>LIVES
	sta	>LIVES_REAL
	jsr	DrawLives
	jsr	ResetActorsOnly
	lda	#3
	sta	>LEVEL_STATE
	bra	:done
:gameover
	lda	#0
	sta	>LEVEL_STATE		; freeze
	bra	:done
:clear
	lda	>CLEAR_TIMER
	beq	:reload
	lda	>CLEAR_TIMER
	dec
	sta	>CLEAR_TIMER
	bra	:done
:reload
	jsr	ReloadBoard
	lda	>LEVEL
	inc
	sta	>LEVEL
	sta	>LEVEL_NUMBER
	jsr	DrawLevelFruit
	jsr	ResetActorsOnly
	lda	#0
	sta	>DOTS_EATEN
	lda	#0
	sta	>FRUIT_SPAWNED
	lda	#0
	sta	>FRUIT_ACTIVE
	lda	#3
	sta	>LEVEL_STATE
:done	plp
	rts

ResetActorsOnly
* Re-apply #253D spawn without redrawing maze.
	php
	jsr	InitArcadeActors
	jsr	ActorPublish
* commit new==old so no erase streak
	rep	#$30
	ldx	#$8400
]c	lda	>BANK2+ACT_X,x
	sta	>BANK2+ACT_OX,x
	lda	>BANK2+ACT_Y,x
	sta	>BANK2+ACT_OY,x
	txa
	clc
	adc	#16
	tax
	cpx	#$8460
	bcc	]c
	plp
	rts

ReloadBoard
	php
	rep	#$30
	jsr	CopyMaze
	jsr	DrawMaze
	plp
	rts
