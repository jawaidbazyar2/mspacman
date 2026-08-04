*
* Pac ↔ ghost collisions — == j_171d / j_1789.
*
	mx	%00

CollideAll
	php
	sep	#$20
	lda	>LEVEL_STATE
	cmp	#3
	beq	:ok
	plp
	rts
:ok	lda	>POWER_PILL_ACT
	bne	:fr
	jsr	CollideHostile
	plp
	rts
:fr	jsr	CollideFright
	plp
	rts

CollideHostile
* == j_171d
	php
	sep	#$20
	jsr	NearRed
	bcc	:p
	lda	>RED_FRIGHT
	ora	>RED_STATE
	beq	:die
:p	jsr	NearPink
	bcc	:b
	lda	>PINK_FRIGHT
	ora	>PINK_STATE
	beq	:die
:b	jsr	NearBlue
	bcc	:o
	lda	>BLUE_FRIGHT
	ora	>BLUE_STATE
	beq	:die
:o	jsr	NearOrange
	bcc	:out
	lda	>ORANGE_FRIGHT
	ora	>ORANGE_STATE
	bne	:out
:die	lda	#4
	sta	>LEVEL_STATE
	lda	#90
	sta	>DEATH_TIMER
	lda	#1
	sta	>DIED_THIS_LEVEL
	lda	#0
	sta	>PILLS_AFTER_DEATH
:out	plp
	rts

CollideFright
* == j_1789
	php
	sep	#$20
	jsr	NearRed
	bcc	:fp
	lda	>RED_FRIGHT
	beq	:fp
	lda	#0
	sta	>RED_FRIGHT
	lda	#1
	sta	>RED_STATE
	jsr	ScoreGhost
:fp	jsr	NearPink
	bcc	:fb
	lda	>PINK_FRIGHT
	beq	:fb
	lda	#0
	sta	>PINK_FRIGHT
	lda	#1
	sta	>PINK_STATE
	jsr	ScoreGhost
:fb	jsr	NearBlue
	bcc	:fo
	lda	>BLUE_FRIGHT
	beq	:fo
	lda	#0
	sta	>BLUE_FRIGHT
	lda	#1
	sta	>BLUE_STATE
	jsr	ScoreGhost
:fo	jsr	NearOrange
	bcc	:out
	lda	>ORANGE_FRIGHT
	beq	:out
	lda	#0
	sta	>ORANGE_FRIGHT
	lda	#1
	sta	>ORANGE_STATE
	jsr	ScoreGhost
:out	jsr	FrightPaletteUpdate	; eaten ghost reverts; others stay blue
	plp
	rts

NearRed
	php
	sep	#$20
	lda	>RED_Y
	sec
	sbc	>PAC_Y
	jsr	AbsLt4
	bcs	:no
	lda	>RED_X
	sec
	sbc	>PAC_X
	jsr	AbsLt4
	bcs	:no
	plp
	sec
	rts
:no	plp
	clc
	rts

NearPink
	php
	sep	#$20
	lda	>PINK_Y
	sec
	sbc	>PAC_Y
	jsr	AbsLt4
	bcs	:no
	lda	>PINK_X
	sec
	sbc	>PAC_X
	jsr	AbsLt4
	bcs	:no
	plp
	sec
	rts
:no	plp
	clc
	rts

NearBlue
	php
	sep	#$20
	lda	>BLUE_Y
	sec
	sbc	>PAC_Y
	jsr	AbsLt4
	bcs	:no
	lda	>BLUE_X
	sec
	sbc	>PAC_X
	jsr	AbsLt4
	bcs	:no
	plp
	sec
	rts
:no	plp
	clc
	rts

NearOrange
	php
	sep	#$20
	lda	>ORANGE_Y
	sec
	sbc	>PAC_Y
	jsr	AbsLt4
	bcs	:no
	lda	>ORANGE_X
	sec
	sbc	>PAC_X
	jsr	AbsLt4
	bcs	:no
	plp
	sec
	rts
:no	plp
	clc
	rts

* After sec/sbc: carry set if |A| >= 4 (miss).
AbsLt4
	bcc	:neg
	cmp	#4
	rts
:neg	eor	#$FF
	inc
	cmp	#4
	rts

ScoreGhost
	php
	rep	#$30
	ldx	#20
]g	phx
	jsr	ScoreAdd10
	plx
	dex
	bne	]g
	jsr	DrawScore
	jsr	CheckHighScore
	plp
	rts
