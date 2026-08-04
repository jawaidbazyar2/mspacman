*
* Active maze play body — == j_08eb / j_1017.
*
	mx	%00

PlayTick
* == j_08eb
	php
	jsr	ActorTick		; == j_1017 × 2
	jsr	ActorTick
	jsr	GhostHouseStub		; == j_13dd
	jsr	LeaveHouseStub		; == j_0c42
	jsr	GhostAnimStub		; == j_0e23
	jsr	GhostOrientTick		; == j_0e36 reverse / scatter↔chase waves
	jsr	FrightTick		; == j_0ac3 fright timer
	jsr	BlinkPowerPills		; == j_0c0d / j_9524
	jsr	SirenStub		; == j_0e6c
	jsr	FruitTick		; == j_0ead / j_86ee
	jsr	CheckBoardClear		; == j_08de / j_94a1
	plp
	rts

ActorTick
* == j_1017
	php
	sep	#$20
	lda	>LEVEL_STATE
	cmp	#3
	bne	:out
	jsr	EyesHomeStub
	jsr	CollideAll
	jsr	MsPacMove
	jsr	GhostsMoveAll
:out	plp
	rts

GhostHouseStub
	rts
LeaveHouseStub
	rts
GhostAnimStub
	rts
SirenStub
	rts

* Periodic ghost reverses + advance scatter/chase index. == j_0e36
* Without this, no-reverse pathfind parks every ghost in a corner loop.
GhostOrientTick
	php
	sep	#$20
	lda	>POWER_PILL_ACT
	bne	:done
	lda	>GHOST_ORIENT_IDX
	cmp	#7
	bcs	:done
	rep	#$30
	lda	>GHOST_ORIENT_IDX
	and	#$00FF
	asl				; word index into threshold table
	tax
	lda	>GHOST_ORIENT_TBL,x	; threshold
	sta	<R_TMP
	lda	>GHOST_ORIENT_CNT
	inc
	sta	>GHOST_ORIENT_CNT
	cmp	<R_TMP
	bne	:done
	sep	#$20
	lda	>GHOST_ORIENT_IDX
	inc
	sta	>GHOST_ORIENT_IDX
	lda	#1
	sta	>RED_REVERSE
	sta	>PINK_REVERSE
	sta	>BLUE_REVERSE
	sta	>ORANGE_REVERSE
:done	plp
	rts

FrightTick
* Decrement fright; clear flags at 0. == j_0ac3 partial
	php
	sep	#$20
	lda	>POWER_PILL_ACT
	beq	:done
	lda	>FRIGHT_TIMER
	beq	:end
	lda	>FRIGHT_TIMER
	dec
	sta	>FRIGHT_TIMER
	bne	:done
:end	lda	#0
	sta	>POWER_PILL_ACT
	lda	#0
	sta	>RED_FRIGHT
	lda	#0
	sta	>PINK_FRIGHT
	lda	#0
	sta	>BLUE_FRIGHT
	lda	#0
	sta	>ORANGE_FRIGHT
:done	plp
	rts

EyesHomeStub
* Eyes (state=1): snap home and revive. == eyes path simplified
	php
	sep	#$20
	lda	>RED_STATE
	cmp	#1
	bne	:p
	lda	#$64
	sta	>RED_Y
	lda	#$80
	sta	>RED_X
	lda	#0
	sta	>RED_STATE
:p	lda	>PINK_STATE
	cmp	#1
	bne	:b
	lda	#$7C
	sta	>PINK_Y
	lda	#$80
	sta	>PINK_X
	lda	#0
	sta	>PINK_STATE
:b	lda	>BLUE_STATE
	cmp	#1
	bne	:o
	lda	#$7C
	sta	>BLUE_Y
	lda	#$90
	sta	>BLUE_X
	lda	#0
	sta	>BLUE_STATE
:o	lda	>ORANGE_STATE
	cmp	#1
	bne	:done
	lda	#$7C
	sta	>ORANGE_Y
	lda	#$70
	sta	>ORANGE_X
	lda	#0
	sta	>ORANGE_STATE
:done	plp
	rts
