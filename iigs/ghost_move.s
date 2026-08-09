*
* Ghost motion — == j_1b36 / j_1c4b / j_1d22 / j_1df9 (four similar bodies).
*
	mx	%00

GhostsMoveAll
	php
	jsr	GhostMoveRed
	jsr	GhostMovePink
	jsr	GhostMoveBlue
	jsr	GhostMoveOrange
	plp
	rts

GhostSpeedFor
* In: A = fright flag (0=normal); Z from caller's LDA (JSR preserves P).
* Level1 ghosts share red's patterns (#4D56 / #4D5A). Do not AND #$FF here:
* file mx %00 would emit 16-bit imm and BRK under runtime 8-bit A.
	bne	GhostSpeedBlue
* fall through — normal
GhostSpeedStep
* 32-bit ROL on SPD_RED_NORM; C = move (same fix as RotSpeedNorm)
	sep	#$20
	lda	>SPD_RED_NORM
	asl	a
	sta	>SPD_RED_NORM
	lda	>SPD_RED_NORM+1
	rol	a
	sta	>SPD_RED_NORM+1
	lda	>SPD_RED_NORM+2
	rol	a
	sta	>SPD_RED_NORM+2
	lda	>SPD_RED_NORM+3
	rol	a
	sta	>SPD_RED_NORM+3
	bcc	:out
	lda	>SPD_RED_NORM
	ora	#$01
	sta	>SPD_RED_NORM
	sec
:out	rts

GhostSpeedBlue
* == speed_pat_red_blue #4D5A — level1 denser holes (~31% vs ~47%)
	sep	#$20
	lda	>SPD_RED_BLUE
	asl	a
	sta	>SPD_RED_BLUE
	lda	>SPD_RED_BLUE+1
	rol	a
	sta	>SPD_RED_BLUE+1
	lda	>SPD_RED_BLUE+2
	rol	a
	sta	>SPD_RED_BLUE+2
	lda	>SPD_RED_BLUE+3
	rol	a
	sta	>SPD_RED_BLUE+3
	bcc	:out
	lda	>SPD_RED_BLUE
	ora	#$01
	sta	>SPD_RED_BLUE
	sec
:out	rts

GhostStepXY
* In: Y addr in R_TMP (low16 of RED_Y etc), dy at tile_dy addr in R_OFF
* Uses R_ACT as ghost index unused — expects:
*   R_BASE = long? Simpler: pass via fixed labels per caller.
	rts

* ---------------------------------------------------------------
GhostMoveRed
* == j_1b36 — maze when SUBSTATE≠0 and STATE=0; eyes (STATE=1) also move
	php
	sep	#$20
	lda	>RED_SUBSTATE
	beq	:skip
	lda	>RED_STATE
	beq	:alive
	cmp	#1
	bne	:skip			; STATE≥2: door entry via EyesTick
* Eyes: every half-tick (== j_10c0→j_1bd8, no speed gate)
	bra	:do
:alive	lda	>RED_FRIGHT
	jsr	GhostSpeedFor
	bcs	:do
:skip	plp
	rts
:do	sep	#$20			; GhostSpeed* leaves 16-bit A
* == j_1bd8: decide on the motion axis only (not both X&Y).
* Vertical movers spawn at X&7==0; requiring both forever skipped AI.
	lda	>RED_TILE_DY
	beq	:cx
	lda	>RED_Y
	and	#$07
	cmp	#$04
	bne	:step
	bra	:dec
:cx	lda	>RED_X
	and	#$07
	cmp	#$04
	bne	:step
:dec	jsr	RedDecide
:step	sep	#$20
	lda	>RED_TILE_DY
	beq	:xr
	bmi	:ru
* no vertical wrap (unlike tunnel X) — Y $FF→$00 teleports top↔bottom
	lda	>RED_Y
	inc
	beq	:fix
	sta	>RED_Y
	bra	:fix
:ru	lda	>RED_Y
	beq	:fix
	dec
	sta	>RED_Y
	bra	:fix
:xr	lda	>RED_TILE_DY+1
	beq	:fix
	bmi	:rl
	lda	>RED_X
	inc
	sta	>RED_X
	bra	:fix
:rl	lda	>RED_X
	dec
	sta	>RED_X
:fix	lda	>RED_Y
	lsr
	lsr
	lsr
	clc
	adc	#$20
	sta	>RED_TILE_Y
	lda	>RED_X
	lsr
	lsr
	lsr
	clc
	adc	#$1E
	sta	>RED_TILE_X
	plp
	rts

GhostMovePink
* == j_1c4b — maze when SUBSTATE==1 and STATE=0; eyes (STATE=1) from anywhere
	php
	sep	#$20
	lda	>PINK_STATE
	beq	:maze
	cmp	#1
	bne	:skip			; STATE≥2: EyesTick door entry
	bra	:do			; eyes: ignore SUBSTATE
:maze	lda	>PINK_SUBSTATE
	cmp	#1
	bne	:skip
	lda	>PINK_FRIGHT
	jsr	GhostSpeedFor
	bcs	:do
:skip	plp
	rts
:do	sep	#$20
	lda	>PINK_TILE_DY
	beq	:cx
	lda	>PINK_Y
	and	#$07
	cmp	#$04
	bne	:step
	bra	:dec
:cx	lda	>PINK_X
	and	#$07
	cmp	#$04
	bne	:step
:dec	jsr	PinkDecide
:step	sep	#$20
	lda	>PINK_TILE_DY
	beq	:xp
	bmi	:pu
	lda	>PINK_Y
	inc
	beq	:fix
	sta	>PINK_Y
	bra	:fix
:pu	lda	>PINK_Y
	beq	:fix
	dec
	sta	>PINK_Y
	bra	:fix
:xp	lda	>PINK_TILE_DY+1
	beq	:fix
	bmi	:pl
	lda	>PINK_X
	inc
	sta	>PINK_X
	bra	:fix
:pl	lda	>PINK_X
	dec
	sta	>PINK_X
:fix	lda	>PINK_Y
	lsr
	lsr
	lsr
	clc
	adc	#$20
	sta	>PINK_TILE_Y
	lda	>PINK_X
	lsr
	lsr
	lsr
	clc
	adc	#$1E
	sta	>PINK_TILE_X
	plp
	rts

GhostMoveBlue
* == j_1d22 — maze when SUBSTATE==1 and STATE=0; eyes (STATE=1) from anywhere
	php
	sep	#$20
	lda	>BLUE_STATE
	beq	:maze
	cmp	#1
	bne	:skip
	bra	:do
:maze	lda	>BLUE_SUBSTATE
	cmp	#1
	bne	:skip
	lda	>BLUE_FRIGHT
	jsr	GhostSpeedFor
	bcs	:do
:skip	plp
	rts
:do	sep	#$20
	lda	>BLUE_TILE_DY
	beq	:cx
	lda	>BLUE_Y
	and	#$07
	cmp	#$04
	bne	:step
	bra	:dec
:cx	lda	>BLUE_X
	and	#$07
	cmp	#$04
	bne	:step
:dec	jsr	BlueDecide
:step	sep	#$20
	lda	>BLUE_TILE_DY
	beq	:xb
	bmi	:bu
	lda	>BLUE_Y
	inc
	beq	:fix
	sta	>BLUE_Y
	bra	:fix
:bu	lda	>BLUE_Y
	beq	:fix
	dec
	sta	>BLUE_Y
	bra	:fix
:xb	lda	>BLUE_TILE_DY+1
	beq	:fix
	bmi	:bl
	lda	>BLUE_X
	inc
	sta	>BLUE_X
	bra	:fix
:bl	lda	>BLUE_X
	dec
	sta	>BLUE_X
:fix	lda	>BLUE_Y
	lsr
	lsr
	lsr
	clc
	adc	#$20
	sta	>BLUE_TILE_Y
	lda	>BLUE_X
	lsr
	lsr
	lsr
	clc
	adc	#$1E
	sta	>BLUE_TILE_X
	plp
	rts

GhostMoveOrange
* == j_1df9 — maze when SUBSTATE==1 and STATE=0; eyes (STATE=1) from anywhere
	php
	sep	#$20
	lda	>ORANGE_STATE
	beq	:maze
	cmp	#1
	bne	:skip
	bra	:do
:maze	lda	>ORANGE_SUBSTATE
	cmp	#1
	bne	:skip
	lda	>ORANGE_FRIGHT
	jsr	GhostSpeedFor
	bcs	:do
:skip	plp
	rts
:do	sep	#$20
	lda	>ORANGE_TILE_DY
	beq	:cx
	lda	>ORANGE_Y
	and	#$07
	cmp	#$04
	bne	:step
	bra	:dec
:cx	lda	>ORANGE_X
	and	#$07
	cmp	#$04
	bne	:step
:dec	jsr	OrangeDecide
:step	sep	#$20
	lda	>ORANGE_TILE_DY
	beq	:xo
	bmi	:ou
	lda	>ORANGE_Y
	inc
	beq	:fix
	sta	>ORANGE_Y
	bra	:fix
:ou	lda	>ORANGE_Y
	beq	:fix
	dec
	sta	>ORANGE_Y
	bra	:fix
:xo	lda	>ORANGE_TILE_DY+1
	beq	:fix
	bmi	:ol
	lda	>ORANGE_X
	inc
	sta	>ORANGE_X
	bra	:fix
:ol	lda	>ORANGE_X
	dec
	sta	>ORANGE_X
:fix	lda	>ORANGE_Y
	lsr
	lsr
	lsr
	clc
	adc	#$20
	sta	>ORANGE_TILE_Y
	lda	>ORANGE_X
	lsr
	lsr
	lsr
	clc
	adc	#$1E
	sta	>ORANGE_TILE_X
	plp
	rts

* Tile-center AI decisions (keep GhostMove* branches short for Merlin)
* Target: scatter corner if frightened OR ghost_orient_index bit0=0;
* else chase (pink: 4 ahead). Bit0 matches j_2730 / j_278e.
* After ~7s Ms. Pac j_0e36 forces index=1 so chase stays on (see GhostOrientTick).

* Reverse (== j_1efe): PREV_DIR⊕2 → DIR/TILE_DY, skip AI this center.
* Arcade runs reverse after AI insert and overwrites tile_dy2.

RedDecide
	php
	sep	#$20
	lda	>RED_REVERSE
	beq	:ai
	lda	#0
	sta	>RED_REVERSE
	lda	>RED_PREV_DIR
	eor	#$02
	sta	>RED_DIR
	sta	>RED_PREV_DIR
	sep	#$30
	asl
	tax
	lda	DirDelta,x
	sta	>RED_TILE_DY
	lda	DirDelta+1,x
	sta	>RED_TILE_DY+1
	plp
	rts
:ai	lda	>RED_TILE_Y
	sta	>PATH_CUR_Y
	lda	>RED_TILE_X
	sta	>PATH_CUR_X
	lda	>RED_STATE
	cmp	#1
	bne	:norm
	lda	EyesHomeTile		; == #2842 dest above door
	sta	>PATH_DST_Y
	lda	EyesHomeTile+1
	sta	>PATH_DST_X
	bra	:aim
:norm	lda	>RED_FRIGHT
	bne	:scat
	lda	>GHOST_ORIENT_IDX
	and	#$01
	bne	:chase
:scat	lda	ScatterRed
	sta	>PATH_DST_Y
	lda	ScatterRed+1
	sta	>PATH_DST_X
	bra	:aim
:chase	lda	>PAC_TILE_Y
	sta	>PATH_DST_Y
	lda	>PAC_TILE_X
	sta	>PATH_DST_X
:aim	lda	>RED_DIR
	jsr	Pathfind2966
	sep	#$30
	sta	>RED_DIR
	sta	>RED_PREV_DIR
	asl
	tax
	lda	DirDelta,x
	sta	>RED_TILE_DY
	lda	DirDelta+1,x
	sta	>RED_TILE_DY+1
	plp
	rts

PinkDecide
	php
	sep	#$20
	lda	>PINK_REVERSE
	beq	:ai
	lda	#0
	sta	>PINK_REVERSE
	lda	>PINK_PREV_DIR
	eor	#$02
	sta	>PINK_DIR
	sta	>PINK_PREV_DIR
	sep	#$30
	asl
	tax
	lda	DirDelta,x
	sta	>PINK_TILE_DY
	lda	DirDelta+1,x
	sta	>PINK_TILE_DY+1
	plp
	rts
:ai	lda	>PINK_TILE_Y
	sta	>PATH_CUR_Y
	lda	>PINK_TILE_X
	sta	>PATH_CUR_X
	lda	>PINK_STATE
	cmp	#1
	bne	:norm
	lda	EyesHomeTile
	sta	>PATH_DST_Y
	lda	EyesHomeTile+1
	sta	>PATH_DST_X
	bra	:aim
:norm	lda	>PINK_FRIGHT
	bne	:scat
	lda	>GHOST_ORIENT_IDX
	and	#$01
	bne	:chase
:scat	lda	ScatterPink
	sta	>PATH_DST_Y
	lda	ScatterPink+1
	sta	>PATH_DST_X
	bra	:aim
:chase	sep	#$30
	lda	>PAC_DIR
	asl
	tax
	lda	>PAC_TILE_Y
	clc
	adc	DirDelta,x
	clc
	adc	DirDelta,x
	clc
	adc	DirDelta,x
	clc
	adc	DirDelta,x
	sta	>PATH_DST_Y
	lda	>PAC_TILE_X
	clc
	adc	DirDelta+1,x
	clc
	adc	DirDelta+1,x
	clc
	adc	DirDelta+1,x
	clc
	adc	DirDelta+1,x
	sta	>PATH_DST_X
:aim	sep	#$20
	lda	>PINK_DIR
	jsr	Pathfind2966
	sep	#$30
	sta	>PINK_DIR
	sta	>PINK_PREV_DIR
	asl
	tax
	lda	DirDelta,x
	sta	>PINK_TILE_DY
	lda	DirDelta+1,x
	sta	>PINK_TILE_DY+1
	plp
	rts

BlueDecide
	php
	sep	#$20
	lda	>BLUE_REVERSE
	beq	:ai
	lda	#0
	sta	>BLUE_REVERSE
	lda	>BLUE_PREV_DIR
	eor	#$02
	sta	>BLUE_DIR
	sta	>BLUE_PREV_DIR
	sep	#$30
	asl
	tax
	lda	DirDelta,x
	sta	>BLUE_TILE_DY
	lda	DirDelta+1,x
	sta	>BLUE_TILE_DY+1
	plp
	rts
:ai	lda	>BLUE_TILE_Y
	sta	>PATH_CUR_Y
	lda	>BLUE_TILE_X
	sta	>PATH_CUR_X
	lda	>BLUE_STATE
	cmp	#1
	bne	:norm
	lda	EyesHomeTile
	sta	>PATH_DST_Y
	lda	EyesHomeTile+1
	sta	>PATH_DST_X
	bra	:aim
:norm	lda	>BLUE_FRIGHT
	bne	:scat
	lda	>GHOST_ORIENT_IDX
	and	#$01
	bne	:chase
:scat	lda	ScatterBlue
	sta	>PATH_DST_Y
	lda	ScatterBlue+1
	sta	>PATH_DST_X
	bra	:aim
:chase	lda	>PAC_TILE_Y
	sta	>PATH_DST_Y
	lda	>PAC_TILE_X
	sta	>PATH_DST_X
:aim	lda	>BLUE_DIR
	jsr	Pathfind2966
	sep	#$30
	sta	>BLUE_DIR
	sta	>BLUE_PREV_DIR
	asl
	tax
	lda	DirDelta,x
	sta	>BLUE_TILE_DY
	lda	DirDelta+1,x
	sta	>BLUE_TILE_DY+1
	plp
	rts

OrangeDecide
	php
	sep	#$20
	lda	>ORANGE_REVERSE
	beq	:ai
	lda	#0
	sta	>ORANGE_REVERSE
	lda	>ORANGE_PREV_DIR
	eor	#$02
	sta	>ORANGE_DIR
	sta	>ORANGE_PREV_DIR
	sep	#$30
	asl
	tax
	lda	DirDelta,x
	sta	>ORANGE_TILE_DY
	lda	DirDelta+1,x
	sta	>ORANGE_TILE_DY+1
	plp
	rts
:ai	lda	>ORANGE_TILE_Y
	sta	>PATH_CUR_Y
	lda	>ORANGE_TILE_X
	sta	>PATH_CUR_X
	lda	>ORANGE_STATE
	cmp	#1
	bne	:norm
	lda	EyesHomeTile
	sta	>PATH_DST_Y
	lda	EyesHomeTile+1
	sta	>PATH_DST_X
	bra	:aim
:norm	lda	>ORANGE_FRIGHT
	bne	:scat
	lda	>GHOST_ORIENT_IDX
	and	#$01
	bne	:chase
:scat	lda	ScatterOrange
	sta	>PATH_DST_Y
	lda	ScatterOrange+1
	sta	>PATH_DST_X
	bra	:aim
:chase	lda	>PAC_TILE_Y
	sta	>PATH_DST_Y
	lda	>PAC_TILE_X
	sta	>PATH_DST_X
:aim	lda	>ORANGE_DIR
	jsr	Pathfind2966
	sep	#$30
	sta	>ORANGE_DIR
	sta	>ORANGE_PREV_DIR
	asl
	tax
	lda	DirDelta,x
	sta	>ORANGE_TILE_DY
	lda	DirDelta+1,x
	sta	>ORANGE_TILE_DY+1
	plp
	rts
