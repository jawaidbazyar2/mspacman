*
* Ms. Pac movement — == j_1806 (speed bits, input, walls, eat).
*
	mx	%00

MsPacMove
* == j_1806
	php
	sep	#$20
	lda	>PAC_MOVE_DELAY
	cmp	#$FF
	beq	:nodelay
	lda	>PAC_MOVE_DELAY
	dec
	sta	>PAC_MOVE_DELAY
	plp
	rts
:nodelay
	lda	>POWER_PILL_ACT
	beq	:normSpd
	jsr	RotSpeedEnerg
	bcc	:done
	bra	:domove
:normSpd	jsr	RotSpeedNorm
	bcc	:done
:domove	sep	#$20			; RotSpeed* leaves 16-bit A
	jsr	ReadWantedDir
	jsr	TryTurnOrAdvance
	jsr	MaybeEat
:done	plp
	rts

* Rotate 32-bit pattern left; C = old bit31 (move this tick). == j_182f
* Must ASL low→high so bit15 feeds bit16; wrap C into bit0. (ASL high first
* shifted in zeros and dropped bit15 — pattern decayed to 0 and froze actors.)
RotSpeedNorm
	jsr	Rol32PacNorm
	rts

RotSpeedEnerg
	jsr	Rol32PacEnerg
	rts

Rol32PacNorm
	sep	#$20
	lda	>SPD_PAC_NORM
	asl	a
	sta	>SPD_PAC_NORM
	lda	>SPD_PAC_NORM+1
	rol	a
	sta	>SPD_PAC_NORM+1
	lda	>SPD_PAC_NORM+2
	rol	a
	sta	>SPD_PAC_NORM+2
	lda	>SPD_PAC_NORM+3
	rol	a
	sta	>SPD_PAC_NORM+3
	bcc	:out
	lda	>SPD_PAC_NORM
	ora	#$01
	sta	>SPD_PAC_NORM
	sec
:out	rts

Rol32PacEnerg
	sep	#$20
	lda	>SPD_PAC_ENERG
	asl	a
	sta	>SPD_PAC_ENERG
	lda	>SPD_PAC_ENERG+1
	rol	a
	sta	>SPD_PAC_ENERG+1
	lda	>SPD_PAC_ENERG+2
	rol	a
	sta	>SPD_PAC_ENERG+2
	lda	>SPD_PAC_ENERG+3
	rol	a
	sta	>SPD_PAC_ENERG+3
	bcc	:out
	lda	>SPD_PAC_ENERG
	ora	#$01
	sta	>SPD_PAC_ENERG
	sec
:out	rts

* Map STICK_IN0 (active-low) → PAC_WANT_DIR + deltas. == j_18c8
ReadWantedDir
	php
	sep	#$20
	lda	>STICK_IN0
	bit	#$02			; left
	bne	:nr
	lda	#DIR_LEFT
	bra	:set
:nr	bit	#$04			; right
	bne	:nu
	lda	#DIR_RIGHT
	bra	:set
:nu	lda	>STICK_IN0
	bit	#$01			; up
	bne	:nd
	lda	#DIR_UP
	bra	:set
:nd	bit	#$08			; down
	bne	:keep
	lda	#DIR_DOWN
:set	sta	>PAC_WANT_DIR
	sep	#$30
	asl
	tax
	lda	DirDelta,x
	sta	>PAC_WANT_DY
	lda	DirDelta+1,x
	sta	>PAC_WANT_DX
:keep	plp
	rts

TryTurnOrAdvance
* At tile center: try wanted dir; else continue. Step 1px along PAC_TILE_DY.
	php
	sep	#$20
	lda	>PAC_X
	and	#$07
	cmp	#$04
	bne	:go
	lda	>PAC_Y
	and	#$07
	cmp	#$04
	bne	:go
* centered — try wanted
	lda	>PAC_TILE_Y
	clc
	adc	>PAC_WANT_DY
	sta	<R_TMP
	lda	>PAC_TILE_X
	clc
	adc	>PAC_WANT_DX
	sta	<R_OFF
	sep	#$30
	lda	<R_TMP
	ldx	<R_OFF
	jsr	IsWallArcade
	bcs	:keepDir
	sep	#$20
	lda	>PAC_WANT_DIR
	sta	>PAC_DIR
	lda	>PAC_WANT_DY
	sta	>PAC_TILE_DY
	lda	>PAC_WANT_DX
	sta	>PAC_TILE_DX
	bra	:go
:keepDir
* if current blocked, stop — unless tunnel edge (== j_1843 / j_1864).
* Mouth neighbor is OOB (= wall); ghosts skip this check and wrap on X.
	sep	#$20
	lda	>PAC_TILE_Y
	clc
	adc	>PAC_TILE_DY
	sta	<R_TMP
	lda	>PAC_TILE_X
	clc
	adc	>PAC_TILE_DX
	sta	<R_OFF
	sep	#$30
	lda	<R_TMP
	ldx	<R_OFF
	jsr	IsWallArcade
	bcc	:go
	sep	#$20
	lda	>PAC_TILE_DY
	bne	:stop			; vertical into wall: stop
	lda	>PAC_TILE_X
	cmp	#$21			; < $21: right-side tunnel
	bcc	:go
	cmp	#$3B			; >= $3B: left-side tunnel
	bcc	:stop
:go	jsr	PacAdvancePixel
	plp
	rts
:stop	plp
	rts

* 1px along PAC_TILE_D*; 8-bit X wrap is the tunnel. Retile.
PacAdvancePixel
	php
	sep	#$20
	lda	>PAC_TILE_DY
	beq	:xax
	bmi	:up
	lda	>PAC_Y
	inc
	sta	>PAC_Y
	bra	:retile
:up	lda	>PAC_Y
	dec
	sta	>PAC_Y
	bra	:retile
:xax	lda	>PAC_TILE_DX
	beq	:done
	bmi	:decx
	lda	>PAC_X
	inc
	sta	>PAC_X
	bra	:retile
:decx	lda	>PAC_X
	dec
	sta	>PAC_X
:retile
* 8-bit X wrap is the tunnel (arcade pace). Publish skips blit when
* outside the 28-wide band (hardware sprite null zone).
	lda	>PAC_Y
	lsr
	lsr
	lsr
	clc
	adc	#$20
	sta	>PAC_TILE_Y
	lda	>PAC_X
	lsr
	lsr
	lsr
	clc
	adc	#$1E
	sta	>PAC_TILE_X
:done	plp
	rts

MaybeEat
* When centered on tile, eat. == eat portion of j_1806
	php
	sep	#$20
	lda	>PAC_X
	and	#$07
	cmp	#$04
	bne	:no
	lda	>PAC_Y
	and	#$07
	cmp	#$04
	bne	:no
	jsr	EatAtPacTile
:no	plp
	rts
