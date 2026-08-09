*
* Ghost pathfinding — == j_2966 (min distance² among 4 dirs).
*
	mx	%00

* PATH_CUR_Y/X, PATH_DST_Y/X set; A = current dir.
* Returns A = best dir (never opposite unless no choice — opposite skipped).
Pathfind2966
	php
	sep	#$20
	sta	>PATH_BEST_DIR
	eor	#$02
	sta	>PATH_OPP_DIR
	lda	#$FF
	sta	>PATH_MIN_LO
	sta	>PATH_MIN_LO+1
	lda	#0
	sta	>PATH_TRY_DIR
:try	sep	#$30			; DirDelta index + IsWall args must be 8-bit
	lda	>PATH_TRY_DIR
	cmp	>PATH_OPP_DIR
	beq	:next
	asl
	tax
	lda	>PATH_CUR_Y
	clc
	adc	DirDelta,x
	sta	>PATH_TMP_Y
	lda	>PATH_CUR_X
	clc
	adc	DirDelta+1,x
	sta	>PATH_TMP_X
	lda	>PATH_TMP_X		; LDX has no 24-bit form (GS/OS EXT)
	tax
	lda	>PATH_TMP_Y
	jsr	IsWallArcade
	bcs	:next
	jsr	Dist2TmpToDst		; → R_X
	rep	#$30
	lda	>PATH_MIN_LO		; word
	cmp	<R_X
	bcc	:next16			; min < dist → keep min
	lda	<R_X
	sta	>PATH_MIN_LO
	sep	#$20
	lda	>PATH_TRY_DIR
	sta	>PATH_BEST_DIR
	bra	:next
:next16	sep	#$20
:next	sep	#$20
	lda	>PATH_TRY_DIR
	inc
	sta	>PATH_TRY_DIR
	lda	>PATH_TRY_DIR
	cmp	#4
	bcc	:try
	sep	#$20
	lda	>PATH_BEST_DIR
	plp
	rts

Dist2TmpToDst
	php
	sep	#$30
	lda	>PATH_DST_Y
	sec
	sbc	>PATH_TMP_Y
	bcs	:yok
	eor	#$FF
	inc
:yok	tax
	jsr	SquareX
	rep	#$30
	lda	<R_X
	sta	<R_Y			; dy²
	sep	#$30
	lda	>PATH_DST_X
	sec
	sbc	>PATH_TMP_X
	bcs	:xok
	eor	#$FF
	inc
:xok	tax
	jsr	SquareX			; dx² in R_X
	rep	#$30
	lda	<R_X
	clc
	adc	<R_Y
	sta	<R_X
	plp
	rts

SquareX
* X = value → R_X = X*X (16-bit). Clobbers A / R_TMP / R_OFF.
* Multiplier bits must start at bit15: ASL on $00V never feeds C (always 0),
* so Dist2 was always 0 and Pathfind picked the first open dir (not toward dest).
	php
	rep	#$30
	txa
	and	#$00FF
	sta	<R_TMP			; multiplicand
	asl	a
	asl	a
	asl	a
	asl	a
	asl	a
	asl	a
	asl	a
	asl	a			; V → high byte ($V00)
	sta	<R_OFF			; multiplier (MSB first)
	lda	#0
	ldx	#8
]s	asl	a			; product <<= 1
	asl	<R_OFF			; C ← next multiplier bit
	bcc	:n
	clc
	adc	<R_TMP
:n	dex
	bne	]s
	sta	<R_X
	plp
	rts
