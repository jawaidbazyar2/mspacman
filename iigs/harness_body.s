*
* Actor init + rail tour
* Rails write ACT_X / ACT_Y and ACT_SPR (facing); renderer reads them (no SHR here).
*
	mx	%00			; force 16-bit asm (ghost_work_blit sep must not leak)

DIR_RIGHT      equ 0
DIR_DOWN       equ 1
DIR_LEFT       equ 2
DIR_UP         equ 3

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

DirToNextWP
* X = actor base with ACT_WP set. Returns A = DIR_* toward next waypoint.
	php
	rep	#$30
	lda	>$02000A,x		; ACT_WP
	and	#$00FF
	asl
	tay
	lda	RailPath,y
	and	#$00FF
	sta	>$027A04		; R_TX = cur tile X
	iny
	lda	RailPath,y
	and	#$00FF
	sta	>$027A06		; R_TY = cur tile Y
	lda	>$02000A,x
	and	#$00FF
	inc
	cmp	#RAIL_LEN
	bcc	:nx
	lda	#0
:nx	asl
	tay
	lda	RailPath,y
	and	#$00FF
	cmp	>$027A04
	beq	:yDir
	bcc	:left
	lda	#DIR_RIGHT
	bra	:out
:left	lda	#DIR_LEFT
	bra	:out
:yDir	iny
	lda	RailPath,y
	and	#$00FF
	cmp	>$027A06
	bcc	:up
	lda	#DIR_DOWN
	bra	:out
:up	lda	#DIR_UP
:out	plp
	rts

InitGhostSprFacing
* X = actor base; set ACT_SPR from dir to next WP (anim phase 0). No rebake.
	php
	jsr	DirToNextWP
	rep	#$30
	and	#$0003
	asl				; dir * 2
	clc
	adc	#$0020
	sep	#$20
	sta	>$020008,x		; ACT_SPR
	plp
	rts

SetGhostSprFromDir
* A = DIR_*; X = actor base.
* ACT_SPR = dir*2 + ((FRAME_COUNT>>3)&1) + $20 (compiled blit; no rebake).
	php
	rep	#$30
	and	#$0003
	asl				; dir * 2
	sta	>$027A14		; R_TMP
	lda	>FRAME_COUNT
	lsr
	lsr
	lsr
	and	#$0001
	clc
	adc	>$027A14
	clc
	adc	#$0020
	sep	#$20
	sta	>$020008,x		; ACT_SPR
	plp
	rts

InitActors
* Four ghosts; waypoint phases from rails_data.s (RAIL_START0..3)
	php
	rep	#$30
	ldx	#$7400
	lda	#RAIL_START0
	jsr	SetActorAtWP
	jsr	InitGhostSprFacing
	sep	#$20
	lda	#0
	sta	>$020009,x
	lda	#COL_BLINKY
	sta	>$02000B,x
	rep	#$20

	ldx	#$7410
	lda	#RAIL_START1
	jsr	SetActorAtWP
	jsr	InitGhostSprFacing
	sep	#$20
	lda	#0
	sta	>$020009,x
	lda	#COL_PINKY
	sta	>$02000B,x
	rep	#$20

	ldx	#$7420
	lda	#RAIL_START2
	jsr	SetActorAtWP
	jsr	InitGhostSprFacing
	sep	#$20
	lda	#0
	sta	>$020009,x
	lda	#COL_INKY
	sta	>$02000B,x
	rep	#$20

	ldx	#$7430
	lda	#RAIL_START3
	jsr	SetActorAtWP
	jsr	InitGhostSprFacing
	sep	#$20
	lda	#0
	sta	>$020009,x
	lda	#COL_CLYDE
	sta	>$02000B,x
	rep	#$20
	plp
	rts

AdvanceRails
* Writes ACT_X/ACT_Y (new) and ACT_SPR on move; does not touch ACT_OX/OY.
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
	lda	#DIR_LEFT
	jsr	SetGhostSprFromDir
	bra	:arNext
:goRight	inc
	sta	>$020000,x
	lda	#DIR_RIGHT
	jsr	SetGhostSprFromDir
	bra	:arNext
:yAxis	lda	>$020002,x
	cmp	>$027A02
	beq	:hit
	bcc	:goDown
	dec
	sta	>$020002,x
	lda	#DIR_UP
	jsr	SetGhostSprFromDir
	bra	:arNext
:goDown	inc
	sta	>$020002,x
	lda	#DIR_DOWN
	jsr	SetGhostSprFromDir
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
