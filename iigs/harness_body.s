*
* Actor init / bounce (included from all.s)
*

InitActors
	php
	rep	#$30
	ldx	#$7400
	lda	#76+80
	sta	>$020000,x
	lda	#7+40
	sta	>$020002,x
	lda	#1
	sta	>$020004,x
	lda	#1
	sta	>$020006,x
	sep	#$20
	lda	#0
	sta	>$020008,x
	lda	#0
	sta	>$020009,x
	rep	#$20

	ldx	#$7410
	lda	#76+40
	sta	>$020000,x
	lda	#7+100
	sta	>$020002,x
	lda	#2
	sta	>$020004,x
	lda	#$FFFF
	sta	>$020006,x
	sep	#$20
	lda	#$20
	sta	>$020008,x
	lda	#0
	sta	>$020009,x
	rep	#$20

	ldx	#$7420
	lda	#76+120
	sta	>$020000,x
	lda	#7+60
	sta	>$020002,x
	lda	#$FFFF
	sta	>$020004,x
	lda	#1
	sta	>$020006,x
	sep	#$20
	lda	#4
	sta	>$020008,x
	lda	#0
	sta	>$020009,x
	rep	#$20
	plp
	rts

UpdateActors
	php
	rep	#$30
	lda	#0
	sta	>$027A16
UpdateLoop
	lda	>$027A16
	asl
	asl
	asl
	asl
	clc
	adc	#$7400
	tax
	lda	>$020000,x
	clc
	adc	>$020004,x
	sta	>$020000,x
	lda	>$020002,x
	clc
	adc	>$020006,x
	sta	>$020002,x

	lda	>$020000,x
	cmp	#76
	bcs	:xhi
	lda	#76
	sta	>$020000,x
	lda	>$020004,x
	eor	#$FFFF
	inc
	sta	>$020004,x
	bra	:y
:xhi	cmp	#76+168-14
	bcc	:y
	lda	#76+168-14
	sta	>$020000,x
	lda	>$020004,x
	eor	#$FFFF
	inc
	sta	>$020004,x

:y	lda	>$020002,x
	cmp	#7
	bcs	:yhi
	lda	#7
	sta	>$020002,x
	lda	>$020006,x
	eor	#$FFFF
	inc
	sta	>$020006,x
	bra	:next
:yhi	cmp	#7+186-12
	bcc	:next
	lda	#7+186-12
	sta	>$020002,x
	lda	>$020006,x
	eor	#$FFFF
	inc
	sta	>$020006,x

:next	lda	>$027A16
	inc
	sta	>$027A16
	lda	>$027A16
	cmp	#3
	bcs	:udone
	jmp	UpdateLoop
:udone	plp
	rts
