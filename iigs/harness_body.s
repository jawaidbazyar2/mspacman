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
	sta	<R_TMP
	asl
	clc
	adc	<R_TMP
	asl				; tile * 6
	clc
	adc	#SPR_BASE_X
	rts

TileToScreenY
	sta	<R_TMP
	asl
	clc
	adc	<R_TMP
	asl
	clc
	adc	#SPR_BASE_Y
	rts

SetActorAtWP
* X = actor base ($8400+); A = waypoint index (0..RAIL_LEN-1)
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
	sta	<R_TX		; cur tile X
	iny
	lda	RailPath,y
	and	#$00FF
	sta	<R_TY		; cur tile Y
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
	cmp	<R_TX
	beq	:yDir
	bcc	:left
	lda	#DIR_RIGHT
	bra	:out
:left	lda	#DIR_LEFT
	bra	:out
:yDir	iny
	lda	RailPath,y
	and	#$00FF
	cmp	<R_TY
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
	sta	<R_TMP
	lda	>FRAME_COUNT
	lsr
	lsr
	lsr
	and	#$0001
	clc
	adc	<R_TMP
	clc
	adc	#$0020
	sep	#$20
	sta	>$020008,x		; ACT_SPR
	plp
	rts

* Arcade #869C–#86EA mouth phase: p=(axis&7)>>1 → mouth 0..2
MsPacMouthTab
	db	0,1,2,1			; E
	db	0,1,0,2			; S
	db	0,1,0,2			; W
	db	0,1,2,1			; N

InitMsPacSprFacing
* X = actor base; ACT_SPR = dir*3 + mouth from axis pos.
	php
	jsr	DirToNextWP
	jsr	SetMsPacSprFromDir
	plp
	rts

SetMsPacSprFromDir
* A = DIR_*; X = actor base.
* ACT_SPR = dir*3 + mouth; axis = X for E/W, Y for N/S.
	php
	rep	#$30
	and	#$0003
	sta	<R_TMP		; dir
	bit	#$0001			; odd dir → Y axis
	bne	:useY
	lda	>$020000,x		; ACT_X
	bra	:gotAxis
:useY	lda	>$020002,x		; ACT_Y
:gotAxis	and	#$0007
	lsr				; p = (axis&7)>>1
	sta	<R_ACT
	lda	<R_TMP
	asl
	asl				; dir*4
	clc
	adc	<R_ACT		; +p
	tay
	lda	MsPacMouthTab,y
	and	#$00FF
	sta	<R_ACT		; mouth
	lda	<R_TMP		; dir*3
	asl
	clc
	adc	<R_TMP
	clc
	adc	<R_ACT
	sep	#$20
	sta	>$020008,x		; ACT_SPR
	plp
	rts

InitActors
* Four ghosts + fixed fruit + Ms. Pac; rails RAIL_START0..3 / PAC_RAIL_START
	php
	rep	#$30
	ldx	#$8400
	lda	#RAIL_START0
	jsr	SetActorAtWP
	jsr	InitGhostSprFacing
	sep	#$20
	lda	#0
	sta	>$020009,x
	lda	#COL_BLINKY
	sta	>$02000B,x
	rep	#$20

	ldx	#$8410
	lda	#RAIL_START1
	jsr	SetActorAtWP
	jsr	InitGhostSprFacing
	sep	#$20
	lda	#0
	sta	>$020009,x
	lda	#COL_PINKY
	sta	>$02000B,x
	rep	#$20

	ldx	#$8420
	lda	#RAIL_START2
	jsr	SetActorAtWP
	jsr	InitGhostSprFacing
	sep	#$20
	lda	#0
	sta	>$020009,x
	lda	#COL_INKY
	sta	>$02000B,x
	rep	#$20

	ldx	#$8430
	lda	#RAIL_START3
	jsr	SetActorAtWP
	jsr	InitGhostSprFacing
	sep	#$20
	lda	#0
	sta	>$020009,x
	lda	#COL_CLYDE
	sta	>$02000B,x
	rep	#$20

* Fruit actor 4 — fixed tile; ACT_SPR = fruit type 0..7
	ldx	#$8440
	lda	#FRUIT_TILE_X
	jsr	TileToScreenX
	sta	>$020000,x		; ACT_X
	sta	>$020004,x		; ACT_OX
	lda	#FRUIT_TILE_Y
	jsr	TileToScreenY
	sta	>$020002,x		; ACT_Y
	sta	>$020006,x		; ACT_OY
	sep	#$20
	lda	#0
	sta	>$020008,x		; ACT_SPR = cherry
	sta	>$020009,x		; ACT_FLAGS
	sta	>$02000A,x		; ACT_WP unused
	sta	>$02000B,x		; ACT_COLOR unused
	rep	#$20

* Ms. Pac actor 5 — rails; ACT_SPR = dir*3 + mouth
	ldx	#$8450
	lda	#PAC_RAIL_START
	jsr	SetActorAtWP
	jsr	InitMsPacSprFacing
	sep	#$20
	lda	#0
	sta	>$020009,x		; ACT_FLAGS
	sta	>$02000B,x		; ACT_COLOR unused
	rep	#$20
	plp
	rts

AdvanceFruit
* When FRAME_COUNT is a multiple of FRUIT_PERIOD (and ≠0), next fruit type.
	php
	rep	#$30
	lda	>FRAME_COUNT
	beq	:frDone
	sta	<R_TMP
	lda	#FRUIT_PERIOD
	sta	<R_ACT
* 16-bit remainder: A = FRAME_COUNT % FRUIT_PERIOD (do not AND #$00FF —
* remainder 256 would falsely look like 0).
	lda	<R_TMP
:frDiv	cmp	<R_ACT
	bcc	:frRem
	sec
	sbc	<R_ACT
	bra	:frDiv
:frRem	cmp	#0
	bne	:frDone
	ldx	#$8440			; fruit actor base
	sep	#$20
	lda	>$020008,x		; ACT_SPR
	inc
	and	#$07
	sta	>$020008,x
	rep	#$20
:frDone	plp
	rts

AdvanceRails
* Writes ACT_X/ACT_Y (new) and ACT_SPR on move; does not touch ACT_OX/OY.
* Ghosts (NUM_GHOSTS) then Ms. Pac; fruit stays fixed.
	php
	rep	#$30
	lda	#0
	sta	<R_ACT
]ar	lda	<R_ACT
	asl
	asl
	asl
	asl
	clc
	adc	#$8400
	tax
	lda	#0			; 0 = ghost sprite setter
	jsr	RailStepActor
:arNext	lda	<R_ACT
	inc
	sta	<R_ACT
	cmp	#NUM_GHOSTS
	bcs	:arPac
	jmp	]ar
:arPac	ldx	#$8450			; PAC_ACTOR base
	lda	#1			; 1 = Ms. Pac sprite setter
	jsr	RailStepActor
	plp
	rts

RailStepActor
* X = actor base; A = 0 ghost / nonzero Ms. Pac for ACT_SPR updates.
	php
	rep	#$30
	sta	<R_BTMP		; setter mode (rails phase only)
	phx
	lda	>$02000A,x		; ACT_WP (byte in low)
	and	#$00FF
	asl
	tay
	lda	RailPath,y
	and	#$00FF
	jsr	TileToScreenX
	sta	<R_X
	iny
	lda	RailPath,y
	and	#$00FF
	jsr	TileToScreenY
	sta	<R_Y
	plx
	lda	>$020000,x
	cmp	<R_X
	beq	:yAxis
	bcc	:goRight
	dec
	sta	>$020000,x
	lda	#DIR_LEFT
	jsr	RailSetSpr
	bra	:rsDone
:goRight	inc
	sta	>$020000,x
	lda	#DIR_RIGHT
	jsr	RailSetSpr
	bra	:rsDone
:yAxis	lda	>$020002,x
	cmp	<R_Y
	beq	:hit
	bcc	:goDown
	dec
	sta	>$020002,x
	lda	#DIR_UP
	jsr	RailSetSpr
	bra	:rsDone
:goDown	inc
	sta	>$020002,x
	lda	#DIR_DOWN
	jsr	RailSetSpr
	bra	:rsDone
:hit	sep	#$20
	lda	>$02000A,x
	inc
	cmp	#RAIL_LEN
	bcc	:storeWp
	lda	#0
:storeWp	sta	>$02000A,x
	rep	#$20
:rsDone	plp
	rts

RailSetSpr
* A = DIR_*; X = actor; R_BTMP selects ghost vs Ms. Pac.
	php
	rep	#$30
	pha
	lda	<R_BTMP
	bne	:pac
	pla
	jsr	SetGhostSprFromDir
	plp
	rts
:pac	pla
	jsr	SetMsPacSprFromDir
	plp
	rts
