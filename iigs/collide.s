*
* Pac ↔ ghost collisions — == j_171d / j_1763 / j_1789.
* Arcade always runs hostile check then resolves blue via that ghost's
* fright flag (not a global POWER_PILL_ACT gate). Recovered non-blue ghosts
* kill during an energizer; blue ones are eaten.
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
:ok
* First near alive ghost decides: fright → eat, else → die. == j_1763
	jsr	NearRed
	bcc	:p
	lda	>RED_STATE
	bne	:p
	lda	>RED_FRIGHT
	bne	:eatR
	brl	:die
:eatR	lda	#0
	sta	>RED_FRIGHT
	lda	#1
	sta	>RED_STATE
	bra	:ate
:p	jsr	NearPink
	bcc	:b
	lda	>PINK_STATE
	bne	:b
	lda	>PINK_FRIGHT
	bne	:eatP
	brl	:die
:eatP	lda	#0
	sta	>PINK_FRIGHT
	lda	#1
	sta	>PINK_STATE
	bra	:ate
:b	jsr	NearBlue
	bcc	:o
	lda	>BLUE_STATE
	bne	:o
	lda	>BLUE_FRIGHT
	bne	:eatB
	brl	:die
:eatB	lda	#0
	sta	>BLUE_FRIGHT
	lda	#1
	sta	>BLUE_STATE
	bra	:ate
:o	jsr	NearOrange
	bcc	:out
	lda	>ORANGE_STATE
	bne	:out
	lda	>ORANGE_FRIGHT
	bne	:eatO
	brl	:die
:eatO	lda	#0
	sta	>ORANGE_FRIGHT
	lda	#1
	sta	>ORANGE_STATE
:ate	jsr	ScoreGhost
	jsr	FrightPaletteUpdate
:out	plp
	rts

* == j_090D side effects when colliding with a hostile (non-blue) ghost
:die	lda	#4
	sta	>LEVEL_STATE
	lda	#90
	sta	>DEATH_TIMER
	lda	#1
	sta	>DIED_THIS_LEVEL
	lda	#0
	sta	>PILLS_AFTER_DEATH
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
