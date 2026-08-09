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
	bne	:notplay
	jsr	PlayTick
	plp
	rts
:notplay
	cmp	#4
	bne	:notdeath
	lda	>DEATH_TIMER
	beq	:dorel
	dec
	sta	>DEATH_TIMER
	plp
	rts
:dorel
	lda	>LIVES
	beq	:gameover
	dec
	sta	>LIVES
	sta	>LIVES_REAL
	jsr	DrawLives
	jsr	ResetActorsOnly
	lda	#3
	sta	>LEVEL_STATE
	plp
	rts
:gameover
	lda	#0
	sta	>LEVEL_STATE		; freeze
	plp
	rts
:notdeath
	cmp	#12
	bne	:out
	lda	>CLEAR_TIMER
	beq	:reload
	dec
	sta	>CLEAR_TIMER
	plp
	rts
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
	sta	>FRUIT_SPAWNED
	sta	>FRUIT_ACTIVE
	sta	>DIED_THIS_LEVEL
	sta	>PILLS_AFTER_DEATH
	lda	#3
	sta	>LEVEL_STATE
:out	plp
	rts

ResetActorsOnly
* Re-apply #253D spawn without redrawing maze.
	php
	jsr	InitArcadeActors
	jsr	ActorPublish
* commit new==old so no erase streak
	rep	#$30
	ldx	#0
]c	lda	>ACTORS+ACT_X,x
	sta	>ACTORS+ACT_OX,x
	lda	>ACTORS+ACT_Y,x
	sta	>ACTORS+ACT_OY,x
	txa
	clc
	adc	#16
	tax
	cpx	#NUM_ACTORS*16	; X = index×16 (not $8400+)
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
