*
* Active maze play body — == j_08eb / j_1017.
*
	mx	%00

PlayTick
* == j_08eb
	php
	jsr	ActorTick		; == j_1017 × 2
	jsr	ActorTick
	jsr	GhostHouse		; == j_13dd
	jsr	LeaveHouse		; == j_0c42
	jsr	GhostAnimStub		; == j_0e23
	jsr	GhostOrientTick		; == j_0e36 reverse / scatter↔chase waves
	jsr	FrightTick		; == j_0ac3 fright timer
	jsr	BlinkPowerPills		; == j_0c0d / j_9524
	jsr	SirenStub		; == j_0e6c
	jsr	FruitTick		; == j_0ead / j_86ee
	jsr	CheckBoardClear		; == j_08de / j_94a1
	plp
	rts

* Top-left 4 SHR pixels @ $01/2000: $FFFF (pen $F) = chase, $0000 = scatter.
* GHOST_ORIENT_IDX bit0 (Ms. Pac: 0 until first reverse, then stays 1).
* Called once per frame from LogicTick.
ChaseModeInd
	php
	rep	#$30
	lda	>GHOST_ORIENT_IDX
	and	#$0001
	beq	:scat
	lda	#$FFFF
	bra	:wr
:scat	lda	#$0000
:wr	sta	>SHR_PIXELS		; $01/2000 — four 320-mode nibbles
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
	jsr	FrightTimerDec		; == j_1376 (×2 via ActorTick)
	jsr	ReleaseDotChecks	; == j_2069 / j_208c / j_20af
:out	plp
	rts

GhostAnimStub
	rts
SirenStub
	rts

* Countdown fright word; clear when 0 or no fright flags. == j_1376
FrightTimerDec
	php
	sep	#$20
	lda	>POWER_PILL_ACT
	beq	:done
	lda	>RED_FRIGHT
	ora	>PINK_FRIGHT
	ora	>BLUE_FRIGHT
	ora	>ORANGE_FRIGHT
	beq	:end
	rep	#$30
	lda	>FRIGHT_TIMER
	beq	:end16
	dec
	sta	>FRIGHT_TIMER
	bne	:done16
:end16	sep	#$20
:end	lda	#0
	sta	>POWER_PILL_ACT
	sta	>RED_FRIGHT
	sta	>PINK_FRIGHT
	sta	>BLUE_FRIGHT
	sta	>ORANGE_FRIGHT
	sta	>FRIGHT_FLASH_CNT
	sta	>FRIGHT_FLASH_PHASE
	rep	#$30
	lda	#0
	sta	>FRIGHT_TIMER
	jsr	FrightPaletteUpdate	; restore per-ghost body pens
:done16	plp
	rts
:done	plp
	rts

* Periodic ghost reverses + scatter→chase. == j_0e36 (Ms. Pac patch)
* Pac-Man SRL A then INC walks the wave table (scatter/chase/scatter…).
* Ms. Pac replaces SRL with XOR A / NOP so index becomes 1 forever after the
* first reverse — chase sticks on, ghosts do not re-park in scatter corners
* ("PATCH TO MAKE RED MONSTER GO AFTER OTTO TO AVOID PARKING" @0E5C).
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
	lda	#1			; == xor a / inc a @0E5C — force chase
	sta	>GHOST_ORIENT_IDX
	sta	>RED_REVERSE
	sta	>PINK_REVERSE
	sta	>BLUE_REVERSE
	sta	>ORANGE_REVERSE
:done	plp
	rts

FrightTick
* Flash period + per-ghost colors. == j_0ac3 / j_0afe
* Each ghost's body pen follows its own *_FRIGHT flag (arcade spr color).
	php
	sep	#$20
	lda	>POWER_PILL_ACT
	beq	:done
	lda	>FRIGHT_FLASH_CNT
	beq	:fire
	dec
	sta	>FRIGHT_FLASH_CNT
	bra	:apply
:fire	lda	#$0E
	sta	>FRIGHT_FLASH_CNT
	rep	#$30
	lda	>FRIGHT_TIMER
	cmp	#$0100
	bcc	:blink
	sep	#$20
	lda	#0
	sta	>FRIGHT_FLASH_PHASE
	bra	:apply
:blink	sep	#$20
	lda	>FRIGHT_FLASH_PHASE
	eor	#1
	sta	>FRIGHT_FLASH_PHASE
:apply	jsr	FrightPaletteUpdate
:done	plp
	rts

* Per-ghost body pens 5/7/9/11 — == j_0afe…j_0bce
* Frightened → blue ($022F) or flash white ($0DDF); else PalTable normal.
FrightPaletteUpdate
	php
	sep	#$20
	lda	>RED_FRIGHT
	beq	:rNorm
	jsr	FrightEdibleRGB		; m=0, A=RGB word
	sta	>SHR_PALETTE+10
	bra	:p
:rNorm	rep	#$30
	lda	|PalTable+10
	sta	>SHR_PALETTE+10
:p	sep	#$20
	lda	>PINK_FRIGHT
	beq	:pNorm
	jsr	FrightEdibleRGB
	sta	>SHR_PALETTE+14
	bra	:b
:pNorm	rep	#$30
	lda	|PalTable+14
	sta	>SHR_PALETTE+14
:b	sep	#$20
	lda	>BLUE_FRIGHT
	beq	:bNorm
	jsr	FrightEdibleRGB
	sta	>SHR_PALETTE+18
	bra	:o
:bNorm	rep	#$30
	lda	|PalTable+18
	sta	>SHR_PALETTE+18
:o	sep	#$20
	lda	>ORANGE_FRIGHT
	beq	:oNorm
	jsr	FrightEdibleRGB
	sta	>SHR_PALETTE+22
	bra	:out
:oNorm	rep	#$30
	lda	|PalTable+22
	sta	>SHR_PALETTE+22
:out	plp
	rts

* A = fright body RGB word; leaves m=0.
FrightEdibleRGB
	rep	#$30
	lda	>FRIGHT_TIMER
	cmp	#$0100
	bcc	:flash
	lda	#$022F
	rts
:flash	lda	>FRIGHT_FLASH_PHASE
	and	#$00FF
	beq	:blue
	lda	#$0DDF
	rts
:blue	lda	#$022F
	rts

EyesHomeStub
* Eyes (state=1): snap to house interior + SUBSTATE=0 so LeaveHouse re-exits.
* == eyes arrive-home simplified (arcade post-entry Y=$80)
	php
	sep	#$20
	lda	>RED_STATE
	cmp	#1
	bne	:p
	lda	#$80
	sta	>RED_Y
	lda	#$80
	sta	>RED_X
	lda	#$2F
	sta	>RED_TILE_Y
	lda	#$2E
	sta	>RED_TILE_X
	lda	#$FF
	sta	>RED_TILE_DY		; up for leave
	lda	#0
	sta	>RED_TILE_DY+1
	lda	#DIR_UP
	sta	>RED_DIR
	lda	#0
	sta	>RED_STATE
	sta	>RED_SUBSTATE
:p	lda	>PINK_STATE
	cmp	#1
	bne	:b
	lda	#$80
	sta	>PINK_Y
	lda	#$80
	sta	>PINK_X
	lda	#$2F
	sta	>PINK_TILE_Y
	lda	#$2E
	sta	>PINK_TILE_X
	lda	#$FF
	sta	>PINK_TILE_DY
	lda	#0
	sta	>PINK_TILE_DY+1
	lda	#DIR_UP
	sta	>PINK_DIR
	lda	#0
	sta	>PINK_STATE
	sta	>PINK_SUBSTATE
:b	lda	>BLUE_STATE
	cmp	#1
	bne	:o
	lda	#$80
	sta	>BLUE_Y
	lda	#$90
	sta	>BLUE_X
	lda	#$2F
	sta	>BLUE_TILE_Y
	lda	#$30
	sta	>BLUE_TILE_X
	lda	#$FF
	sta	>BLUE_TILE_DY
	lda	#0
	sta	>BLUE_TILE_DY+1
	lda	#DIR_UP
	sta	>BLUE_DIR
	lda	#0
	sta	>BLUE_STATE
	sta	>BLUE_SUBSTATE
:o	lda	>ORANGE_STATE
	cmp	#1
	bne	:done
	lda	#$80
	sta	>ORANGE_Y
	lda	#$70
	sta	>ORANGE_X
	lda	#$2F
	sta	>ORANGE_TILE_Y
	lda	#$2C
	sta	>ORANGE_TILE_X
	lda	#$FF
	sta	>ORANGE_TILE_DY
	lda	#0
	sta	>ORANGE_TILE_DY+1
	lda	#DIR_UP
	sta	>ORANGE_DIR
	lda	#0
	sta	>ORANGE_STATE
	sta	>ORANGE_SUBSTATE
:done	plp
	rts
