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
	jsr	ApplyKillGhost		; == j_1066 (pending→STATE after freeze)
	jsr	EyesTick		; == j_1094…j_10b4 eyes travel / enter
* == #102E: while eat-pose pending, freeze motion (no pac/ghost/fright dec)
	lda	>GHOSTS_KILLED_PENDING
	beq	:move
	jsr	EatGhostAnimTick	; == j_1235 + $4A timer
	plp
	rts
:move	jsr	CollideAll
	lda	>GHOSTS_KILLED_PENDING
	bne	:out			; == #103F ate this half-tick → no move
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

* == j_1235 + RST#30 $4A stand-in. Points/hide via ActorPublish flags.
EatGhostAnimTick
	php
	sep	#$20
	lda	>EAT_FREEZE_TIMER
	beq	:teardown
	dec
	sta	>EAT_FREEZE_TIMER
	bne	:done
:teardown
* == j_1277: eyes restore, kill_ghost_state ← pending, clear pending/anim
	lda	>GHOSTS_KILLED_PENDING
	sta	>KILL_GHOST_STATE
	lda	#0
	sta	>GHOSTS_KILLED_PENDING
	sta	>KILLED_GHOST_ANIM
	sta	>EAT_FREEZE_TIMER
	jsr	EyesSoundStub		; == #128E CH2 bit6
:done	plp
	rts

EyesSoundStub
* == #128E set 6,(CH2_E_NUM) — WSG not ported
	rts

* == j_1066: promote KILL_GHOST_STATE → that ghost STATE=1 (eyes)
ApplyKillGhost
	php
	sep	#$20
	lda	>KILL_GHOST_STATE
	beq	:out
	cmp	#1
	bne	:p
	lda	#0
	sta	>KILL_GHOST_STATE
	lda	#1
	sta	>RED_STATE
	bra	:out
:p	cmp	#2
	bne	:b
	lda	#0
	sta	>KILL_GHOST_STATE
	lda	#1
	sta	>PINK_STATE
	bra	:out
:b	cmp	#3
	bne	:o
	lda	#0
	sta	>KILL_GHOST_STATE
	lda	#1
	sta	>BLUE_STATE
	bra	:out
:o	lda	#0
	sta	>KILL_GHOST_STATE
	lda	#1
	sta	>ORANGE_STATE
:out	plp
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
:end	jsr	ClearFrightState		; == j_1398
:done16	plp
	rts
:done	plp
	rts

* == j_1398 — end energizer: clear pill/fright/timer/flash.
* Also used after death respawn (arcade task #11 zeros #4D00–#4DFF before
* task #04 re-seeds actors; without this, ghosts stay blue).
ClearFrightState
	php
	sep	#$20
	lda	#0
	sta	>POWER_PILL_ACT
	sta	>RED_FRIGHT
	sta	>PINK_FRIGHT
	sta	>BLUE_FRIGHT
	sta	>ORANGE_FRIGHT
	sta	>FRIGHT_FLASH_CNT
	sta	>FRIGHT_FLASH_PHASE
	sta	>RED_REVERSE
	sta	>PINK_REVERSE
	sta	>BLUE_REVERSE
	sta	>ORANGE_REVERSE
	sta	>GHOSTS_KILLED_PENDING
	sta	>GHOSTS_KILLED_COUNT	; == #13D2
	sta	>KILLED_GHOST_ANIM
	sta	>EAT_FREEZE_TIMER
	sta	>KILL_GHOST_STATE
	rep	#$30
	lda	#0
	sta	>FRIGHT_TIMER
	plp
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
* Flash period and phase. == j_0ac3 / j_0afe
* ActorPublish picks each ghost's blit from its *_FRIGHT flag and the phase.
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
:apply
:done	plp
	rts

EyesTick
* == j_1094…j_10b4: STATE=1 maze travel (GhostMove*); door at ($64,$80);
* STATE=2 enter down to Y=$80; blue/orange STATE=3 slide to pen then home.
	php
	sep	#$20
	jsr	EyesTickRed
	jsr	EyesTickPink
	jsr	EyesTickBlue
	jsr	EyesTickOrange
	plp
	rts

* Door arrive: tile match to EyesHomeTile ($2C,$2E), then snap pixels.
* Exact ($64,$80) is easy to miss — pathfind centers on X=$84 (tile mid).

EyesTickRed
	sep	#$20
	lda	>RED_STATE
	cmp	#1
	beq	:atDoor
	cmp	#2
	beq	:enter
	rts
:atDoor	lda	>RED_TILE_Y
	cmp	EyesHomeTile
	bne	:rts
	lda	>RED_TILE_X
	cmp	EyesHomeTile+1
	bne	:rts
	lda	#$64			; snap to arcade door pixel
	sta	>RED_Y
	lda	#$80
	sta	>RED_X
	lda	#2
	sta	>RED_STATE
	rts
:enter	lda	>RED_Y
	inc
	sta	>RED_Y
	lda	#DIR_DOWN
	sta	>RED_DIR
	sta	>RED_PREV_DIR
	lda	#1
	sta	>RED_TILE_DY
	lda	#0
	sta	>RED_TILE_DY+1
	lda	>RED_Y
	cmp	#$80
	bne	:rts
	lda	#$80
	sta	>RED_X
	lda	#$2F
	sta	>RED_TILE_Y
	lda	#$2E
	sta	>RED_TILE_X
	lda	#$FF
	sta	>RED_TILE_DY
	lda	#0
	sta	>RED_TILE_DY+1
	lda	#DIR_UP
	sta	>RED_DIR
	lda	#0
	sta	>RED_STATE
	sta	>RED_SUBSTATE
	sta	>RED_FRIGHT
:rts	rts

EyesTickPink
	sep	#$20
	lda	>PINK_STATE
	cmp	#1
	beq	:atDoor
	cmp	#2
	beq	:enter
	rts
:atDoor	lda	>PINK_TILE_Y
	cmp	EyesHomeTile
	bne	:rts
	lda	>PINK_TILE_X
	cmp	EyesHomeTile+1
	bne	:rts
	lda	#$64
	sta	>PINK_Y
	lda	#$80
	sta	>PINK_X
	lda	#2
	sta	>PINK_STATE
	rts
:enter	lda	>PINK_Y
	inc
	sta	>PINK_Y
	lda	#DIR_DOWN
	sta	>PINK_DIR
	sta	>PINK_PREV_DIR
	lda	#1
	sta	>PINK_TILE_DY
	lda	#0
	sta	>PINK_TILE_DY+1
	lda	>PINK_Y
	cmp	#$80
	bne	:rts
	lda	#$80
	sta	>PINK_Y
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
	sta	>PINK_FRIGHT
:rts	rts

EyesTickBlue
	sep	#$20
	lda	>BLUE_STATE
	cmp	#1
	beq	:atDoor
	cmp	#2
	beq	:enter
	cmp	#3
	beq	:slide
	rts
:atDoor	lda	>BLUE_TILE_Y
	cmp	EyesHomeTile
	bne	:done
	lda	>BLUE_TILE_X
	cmp	EyesHomeTile+1
	bne	:done
	lda	#$64
	sta	>BLUE_Y
	lda	#$80
	sta	>BLUE_X
	lda	#2
	sta	>BLUE_STATE
:done	rts
:enter	lda	>BLUE_Y
	inc
	sta	>BLUE_Y
	lda	#DIR_DOWN
	sta	>BLUE_DIR
	sta	>BLUE_PREV_DIR
	lda	#1
	sta	>BLUE_TILE_DY
	lda	#0
	sta	>BLUE_TILE_DY+1
	lda	>BLUE_Y
	cmp	#$80
	bne	:done
	lda	#3
	sta	>BLUE_STATE
	rts
:slide	lda	>BLUE_X			; arcade left → +X to $90
	inc
	sta	>BLUE_X
	lda	#DIR_LEFT
	sta	>BLUE_DIR
	sta	>BLUE_PREV_DIR
	lda	#0
	sta	>BLUE_TILE_DY
	lda	#1
	sta	>BLUE_TILE_DY+1
	lda	>BLUE_X
	cmp	#$90
	bne	:done
	lda	#$80			; pen: center Y, left X
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
	sta	>BLUE_FRIGHT
	rts

EyesTickOrange
	sep	#$20
	lda	>ORANGE_STATE
	cmp	#1
	beq	:atDoor
	cmp	#2
	beq	:enter
	cmp	#3
	beq	:slide
	rts
:atDoor	lda	>ORANGE_TILE_Y
	cmp	EyesHomeTile
	bne	:done
	lda	>ORANGE_TILE_X
	cmp	EyesHomeTile+1
	bne	:done
	lda	#$64
	sta	>ORANGE_Y
	lda	#$80
	sta	>ORANGE_X
	lda	#2
	sta	>ORANGE_STATE
:done	rts
:enter	lda	>ORANGE_Y
	inc
	sta	>ORANGE_Y
	lda	#DIR_DOWN
	sta	>ORANGE_DIR
	sta	>ORANGE_PREV_DIR
	lda	#1
	sta	>ORANGE_TILE_DY
	lda	#0
	sta	>ORANGE_TILE_DY+1
	lda	>ORANGE_Y
	cmp	#$80
	bne	:done
	lda	#3
	sta	>ORANGE_STATE
	rts
:slide	lda	>ORANGE_X		; arcade right → -X to $70
	dec
	sta	>ORANGE_X
	lda	#DIR_RIGHT
	sta	>ORANGE_DIR
	sta	>ORANGE_PREV_DIR
	lda	#0
	sta	>ORANGE_TILE_DY
	lda	#$FF
	sta	>ORANGE_TILE_DY+1
	lda	>ORANGE_X
	cmp	#$70
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
	sta	>ORANGE_FRIGHT
	rts
