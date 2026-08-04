*
* Fruit release — == j_0ead / j_86ee (simplified: appear at tile, timed).
*
	mx	%00

FruitTick
* == j_0ead / j_86ee
	php
	sep	#$20
	lda	>FRUIT_ACTIVE
	bne	:aging
	lda	>DOTS_EATEN
	cmp	#FruitDots1
	bcc	:try2
	lda	>FRUIT_SPAWNED
	bit	#$01
	bne	:try2
	ora	#$01
	sta	>FRUIT_SPAWNED
	bra	:spawn
:try2	lda	>DOTS_EATEN
	cmp	#FruitDots2
	bcc	:done
	lda	>FRUIT_SPAWNED
	bit	#$02
	bne	:done
	ora	#$02
	sta	>FRUIT_SPAWNED
:spawn
	lda	#$94
	sta	>FRUIT_PIXEL_Y
	lda	#$80
	sta	>FRUIT_PIXEL_X
	lda	#1
	sta	>FRUIT_ACTIVE
	lda	#255
	sta	>FRUIT_TIMER
	bra	:done
:aging	lda	>FRUIT_TIMER
	dec
	sta	>FRUIT_TIMER
	lda	>FRUIT_TIMER
	bne	:eatchk
	lda	#0
	sta	>FRUIT_ACTIVE
	bra	:done
:eatchk
* collide with pac
	lda	>FRUIT_PIXEL_Y
	sec
	sbc	>PAC_Y
	jsr	AbsLt4
	bcs	:done
	lda	>FRUIT_PIXEL_X
	sec
	sbc	>PAC_X
	jsr	AbsLt4
	bcs	:done
	lda	#0
	sta	>FRUIT_ACTIVE
	jsr	ScoreAdd100
:done	plp
	rts

ScoreAdd100
	php
	rep	#$30
	ldx	#10
]f	phx
	jsr	ScoreAdd10
	plx
	dex
	bne	]f
	jsr	DrawScore
	jsr	CheckHighScore
	plp
	rts
