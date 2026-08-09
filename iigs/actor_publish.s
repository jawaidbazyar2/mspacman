*
* Publish arcade #4D positions → soft-sprite ACT_* (replaces ISR sprite ports).
* == ISR #0176 publish, adapted for upright SHR 6/8 mapping.
*
	mx	%00

* Arcade pixel (Y in A, X in X) → R_X / R_Y screen sprite coords.
* Rails: ACT = tile*6+SPR_BASE (centers sprite on tile). Arcade &7==4 is that
* center — offset by (sub-4)×6/8. Upright X is mirrored: sub_x = 4-(ax&7).
ArcadeToScreen
	php
	sep	#$30
	sta	<R_TMP			; ay
	stx	<R_OFF			; ax
* our_tx = 27 - ((ax>>3) - 2)
	lda	<R_OFF
	lsr
	lsr
	lsr
	sec
	sbc	#2
	sta	<R_ACT
	lda	#27
	sec
	sbc	<R_ACT
	sta	<R_TX
* our_ty = (ay>>3) - 1
	lda	<R_TMP
	lsr
	lsr
	lsr
	dec
	sta	<R_TY
* sub_x = 4-(ax&7), sub_y = (ay&7)-4  (signed bytes)
	lda	<R_OFF
	and	#$07
	sta	<R_ACT
	lda	#4
	sec
	sbc	<R_ACT
	sta	<R_BTMP
	lda	<R_TMP
	and	#$07
	sec
	sbc	#4
	sta	<R_SAVE
	rep	#$30
	lda	<R_TX
	and	#$00FF
	jsr	:tileBase
	clc
	adc	#SPR_BASE_X
	sta	<R_X
	lda	<R_BTMP
	jsr	:subScale
	clc
	adc	<R_X
	sta	<R_X
	lda	<R_TY
	and	#$00FF
	jsr	:tileBase
	clc
	adc	#SPR_BASE_Y
	sta	<R_Y
	lda	<R_SAVE
	jsr	:subScale
	clc
	adc	<R_Y
	sta	<R_Y
	plp
	rts

* A = tile index → A = tile*6 (m=0)
:tileBase
	and	#$00FF
	sta	<R_TMP
	asl
	clc
	adc	<R_TMP
	asl
	rts

* A = signed sub-pixel -4..4 → A = ASR(sub*6, 3) (m=0)
:subScale
	and	#$00FF
	bit	#$0080
	beq	:pl
	ora	#$FF00
:pl	sta	<R_TMP
	asl
	clc
	adc	<R_TMP
	asl				; *6
	ldx	#3
]asr	cmp	#$8000			; C = sign
	ror	a
	dex
	bne	]asr
	rts

* A = dir 0..3 → A = $20 + dir*2 + ((FRAME>>3)&1)
GhostSprFromDir
	php
	rep	#$30
	and	#$0003
	asl
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
	plp
	rts

* X = actor base ($8400…). Uses R_X = screen sprite X after ArcadeToScreen.
* FLAG_NODRAW when outside the 28-wide PF band in screen space.
* Leftmost arcade column can map ACT_X < SPR_BASE_X (72) → BCK underflow
* and tunnel garbage; arcade X>=$F0 alone was not enough on the left.
ActorTunnelVis
	php
	rep	#$30
	lda	<R_X
	cmp	#SPR_BASE_X		; 72 — BCK / sprite origin
	bcc	:hide
	cmp	#SPR_BASE_X+168		; 72+28*6 — past rightmost tile origin
	bcs	:hide
	sep	#$20
	lda	>ACTORS+ACT_FLAGS,x
	and	#$FD			; clear FLAG_NODRAW
	sta	>ACTORS+ACT_FLAGS,x
	plp
	rts
:hide	sep	#$20
	lda	>ACTORS+ACT_FLAGS,x
	ora	#FLAG_NODRAW
	sta	>ACTORS+ACT_FLAGS,x
	plp
	rts

ActorPublish
	php
	rep	#$30
* Blinky — LDX has no 24-bit form; load X via LDA/TAX so GS/OS EXT works.
	sep	#$30
	lda	>RED_X
	tax
	lda	>RED_Y
	jsr	ArcadeToScreen
	rep	#$30
	ldx	#0
	lda	<R_X
	sta	>ACTORS+ACT_X,x
	lda	<R_Y
	sta	>ACTORS+ACT_Y,x
	jsr	ActorTunnelVis
	lda	>RED_DIR
	jsr	GhostSprFromDir
	sep	#$20
	sta	>ACTORS+ACT_SPR,x
	lda	#COL_BLINKY
	sta	>ACTORS+ACT_COLOR,x
* Pinky
	sep	#$30
	lda	>PINK_X
	tax
	lda	>PINK_Y
	jsr	ArcadeToScreen
	rep	#$30
	ldx	#16
	lda	<R_X
	sta	>ACTORS+ACT_X,x
	lda	<R_Y
	sta	>ACTORS+ACT_Y,x
	jsr	ActorTunnelVis
	lda	>PINK_DIR
	jsr	GhostSprFromDir
	sep	#$20
	sta	>ACTORS+ACT_SPR,x
	lda	#COL_PINKY
	sta	>ACTORS+ACT_COLOR,x
* Inky
	sep	#$30
	lda	>BLUE_X
	tax
	lda	>BLUE_Y
	jsr	ArcadeToScreen
	rep	#$30
	ldx	#32
	lda	<R_X
	sta	>ACTORS+ACT_X,x
	lda	<R_Y
	sta	>ACTORS+ACT_Y,x
	jsr	ActorTunnelVis
	lda	>BLUE_DIR
	jsr	GhostSprFromDir
	sep	#$20
	sta	>ACTORS+ACT_SPR,x
	lda	#COL_INKY
	sta	>ACTORS+ACT_COLOR,x
* Clyde
	sep	#$30
	lda	>ORANGE_X
	tax
	lda	>ORANGE_Y
	jsr	ArcadeToScreen
	rep	#$30
	ldx	#48
	lda	<R_X
	sta	>ACTORS+ACT_X,x
	lda	<R_Y
	sta	>ACTORS+ACT_Y,x
	jsr	ActorTunnelVis
	lda	>ORANGE_DIR
	jsr	GhostSprFromDir
	sep	#$20
	sta	>ACTORS+ACT_SPR,x
	lda	#COL_CLYDE
	sta	>ACTORS+ACT_COLOR,x
* Fruit — inactive: FLAG_NODRAW (never blit at 0,0; BckXY X-72 underflows)
	sep	#$20
	lda	>FRUIT_ACTIVE
	bne	:frOn
	rep	#$30
	ldx	#64
	lda	#FLAG_NODRAW
	sep	#$20
	sta	>ACTORS+ACT_FLAGS,x
	bra	:pac
:frOn	sep	#$30
	lda	>FRUIT_PIXEL_X
	tax
	lda	>FRUIT_PIXEL_Y
	jsr	ArcadeToScreen
	rep	#$30
	ldx	#64
	lda	<R_X
	sta	>ACTORS+ACT_X,x
	lda	<R_Y
	sta	>ACTORS+ACT_Y,x
	sep	#$20
	lda	>LEVEL
	cmp	#MAX_FRUIT_TYPE+1
	bcc	:fs
	lda	#MAX_FRUIT_TYPE
:fs	sta	>ACTORS+ACT_SPR,x
	lda	>ACTORS+ACT_FLAGS,x
	and	#$FD			; clear FLAG_NODRAW
	sta	>ACTORS+ACT_FLAGS,x
* Ms. Pac
:pac	sep	#$30
	lda	>PAC_X
	tax
	lda	>PAC_Y
	jsr	ArcadeToScreen
	rep	#$30
	ldx	#80
	lda	<R_X
	sta	>ACTORS+ACT_X,x
	lda	<R_Y
	sta	>ACTORS+ACT_Y,x
	jsr	ActorTunnelVis
	lda	>PAC_DIR
	and	#$0003
	sta	<R_TMP
	bit	#$0001
	bne	:useY
	lda	>PAC_X
	and	#$00FF
	bra	:gotAx
:useY	lda	>PAC_Y
	and	#$00FF
:gotAx	and	#$0007
	lsr
	sta	<R_ACT
	lda	<R_TMP
	asl
	asl
	clc
	adc	<R_ACT
	tay
	lda	GameMouthTab,y
	and	#$00FF
	sta	<R_ACT
	lda	<R_TMP
	asl
	clc
	adc	<R_TMP
	clc
	adc	<R_ACT
	sep	#$20
	sta	>ACTORS+ACT_SPR,x
	plp
	rts

GameMouthTab
	db	0,1,2,1
	db	0,1,0,2
	db	0,1,0,2
	db	0,1,2,1
