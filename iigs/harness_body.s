*
* Actor init + rail tour
* Rails write ACT_X / ACT_Y only; renderer reads them (no SHR here).
*
	mx	%00			; force 16-bit asm (ghost_work_blit sep must not leak)

* A = tile coord → screen pixel in A (X variant)
TileToScreenX
	sta	>$027A14
	asl
	clc
	adc	>$027A14
	asl				; tile * 6
	clc
	adc	#SPR_BASE_X
	rts

TileToScreenY
	sta	>$027A14
	asl
	clc
	adc	>$027A14
	asl
	clc
	adc	#SPR_BASE_Y
	rts

SetActorAtWP
* X = actor base ($7400+); A = waypoint index (0..RAIL_LEN-1)
* Sets ACT_WP, ACT_X/Y (new), and ACT_OX/OY = new (old)
	php
	sep	#$20
	sta	>$02000A,x		; ACT_WP
	rep	#$20
	and	#$00FF
	asl
	tay
	lda	RailPath,y
	and	#$00FF
	jsr	TileToScreenX
	sta	>$020000,x		; ACT_X
	sta	>$020004,x		; ACT_OX = new
	iny
	lda	RailPath,y
	and	#$00FF
	jsr	TileToScreenY
	sta	>$020002,x		; ACT_Y
	sta	>$020006,x		; ACT_OY = new
	plp
	rts

InitActors
* Four ghosts; waypoint phases from rails_data.s (RAIL_START0..3)
	php
	rep	#$30
	ldx	#$7400
	lda	#RAIL_START0
	jsr	SetActorAtWP
	sep	#$20
	lda	#$20
	sta	>$020008,x
	lda	#0
	sta	>$020009,x
	lda	#COL_BLINKY
	sta	>$02000B,x
	rep	#$20

	ldx	#$7410
	lda	#RAIL_START1
	jsr	SetActorAtWP
	sep	#$20
	lda	#$22
	sta	>$020008,x
	lda	#0
	sta	>$020009,x
	lda	#COL_PINKY
	sta	>$02000B,x
	rep	#$20

	ldx	#$7420
	lda	#RAIL_START2
	jsr	SetActorAtWP
	sep	#$20
	lda	#$24
	sta	>$020008,x
	lda	#0
	sta	>$020009,x
	lda	#COL_INKY
	sta	>$02000B,x
	rep	#$20

	ldx	#$7430
	lda	#RAIL_START3
	jsr	SetActorAtWP
	sep	#$20
	lda	#$26
	sta	>$020008,x
	lda	#0
	sta	>$020009,x
	lda	#COL_CLYDE
	sta	>$02000B,x
	rep	#$20
	plp
	rts

AdvanceRails
* Writes ACT_X/ACT_Y (new) only; does not touch ACT_OX/OY.
	php
	rep	#$30
	lda	#0
	sta	>$027A16
]ar	lda	>$027A16
	asl
	asl
	asl
	asl
	clc
	adc	#$7400
	tax
	phx
	lda	>$02000A,x		; ACT_WP (byte in low)
	and	#$00FF
	asl
	tay
	lda	RailPath,y
	and	#$00FF
	jsr	TileToScreenX
	sta	>$027A00
	iny
	lda	RailPath,y
	and	#$00FF
	jsr	TileToScreenY
	sta	>$027A02
	plx
	lda	>$020000,x
	cmp	>$027A00
	beq	:yAxis
	bcc	:goRight
	dec
	sta	>$020000,x
	bra	:arNext
:goRight	inc
	sta	>$020000,x
	bra	:arNext
:yAxis	lda	>$020002,x
	cmp	>$027A02
	beq	:hit
	bcc	:goDown
	dec
	sta	>$020002,x
	bra	:arNext
:goDown	inc
	sta	>$020002,x
	bra	:arNext
:hit	sep	#$20
	lda	>$02000A,x
	inc
	cmp	#RAIL_LEN
	bcc	:storeWp
	lda	#0
:storeWp	sta	>$02000A,x
	rep	#$20
:arNext	lda	>$027A16
	inc
	sta	>$027A16
	cmp	#NUM_ACTORS
	bcs	:arDone
	jmp	]ar
:arDone	plp
	rts
