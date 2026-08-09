*
* Ghost house leave / release — == j_0c42 / j_13dd / j_1b08 / j_2069…
* Substate: 0=home bounce, 1=outside, 2=up through door, 3=to door (blue/orange).
*
	mx	%00

* ---------------------------------------------------------------
* LeaveHouse — == j_0c42
* ---------------------------------------------------------------
LeaveHouse
	php
	sep	#$20
* == #0C42: only eat-pose pending blocks (not eyes STATE — that was a v1 stand-in
* and left house/exit ghosts frozen until eyes finished returning).
	lda	>GHOSTS_KILLED_PENDING
	bne	:out
* RLCA half-rate (== #4D94): bit7→C and wraps into bit0
	lda	>GHOST_HOME_MOVE
	asl	a
	bcc	:nowrap
	ora	#$01
	sta	>GHOST_HOME_MOVE
	bra	:go
:nowrap	sta	>GHOST_HOME_MOVE
	bra	:out
:go	jsr	HouseSanity		; unstick house-SUBSTATE while in maze
	jsr	LeaveRed
	jsr	LeavePink
	jsr	LeaveBlue
	jsr	LeaveOrange
:out	plp
	rts

* If SUBSTATE says "in house" but pixels are outside the house bbox,
* promote to SUBSTATE=1 so GhostMove (maze) owns them — otherwise Leave*
* walks them through walls at half-rate (no collision).
* BBox: Y=$64..$80, X=$70..$90 (door shaft + blue/orange pens).
HouseSanity
	php
	sep	#$30
	lda	>RED_STATE
	bne	:p
	lda	>RED_SUBSTATE
	bne	:p			; red: only 0 is house-side
	lda	>RED_X
	tax
	lda	>RED_Y
	jsr	IsInHouse
	bcs	:p
	lda	#1
	sta	>RED_SUBSTATE
:p	lda	>PINK_STATE
	bne	:b
	lda	>PINK_SUBSTATE
	cmp	#1
	beq	:b
	lda	>PINK_X
	tax
	lda	>PINK_Y
	jsr	IsInHouse
	bcs	:b
	lda	#1
	sta	>PINK_SUBSTATE
:b	lda	>BLUE_STATE
	bne	:o
	lda	>BLUE_SUBSTATE
	cmp	#1
	beq	:o
	lda	>BLUE_X
	tax
	lda	>BLUE_Y
	jsr	IsInHouse
	bcs	:o
	lda	#1
	sta	>BLUE_SUBSTATE
:o	lda	>ORANGE_STATE
	bne	:done
	lda	>ORANGE_SUBSTATE
	cmp	#1
	beq	:done
	lda	>ORANGE_X
	tax
	lda	>ORANGE_Y
	jsr	IsInHouse
	bcs	:done
	lda	#1
	sta	>ORANGE_SUBSTATE
:done	plp
	rts

* A=Y, X=X. SEC=inside house bbox, CLC=outside.
IsInHouse
	cmp	#$64
	bcc	:no
	cmp	#$81
	bcs	:no
	txa
	cmp	#$70
	bcc	:no
	cmp	#$91
	bcs	:no
	sec
	rts
:no	clc
	rts

LeaveRed
	php
	sep	#$20
	lda	>RED_STATE
	bne	:done			; eyes: maze/entry via GhostMove / EyesTick
	lda	>RED_SUBSTATE
	bne	:done			; only when home (eyes re-entry)
	lda	>RED_Y
	beq	:done
	dec
	sta	>RED_Y
	lda	#DIR_UP
	sta	>RED_DIR
	sta	>RED_PREV_DIR
	lda	>RED_Y
	cmp	#$64
	bne	:tile
	lda	#$2C
	sta	>RED_TILE_Y
	lda	#$2E
	sta	>RED_TILE_X
	lda	#0
	sta	>RED_TILE_DY
	lda	#$01
	sta	>RED_TILE_DY+1
	lda	#DIR_LEFT
	sta	>RED_DIR
	sta	>RED_PREV_DIR
	lda	#1
	sta	>RED_SUBSTATE
	bra	:done
:tile	jsr	RetileRed
:done	plp
	rts

LeavePink
	php
	sep	#$20
	lda	>PINK_STATE
	bne	:done			; eyes: not house leave
	lda	>PINK_SUBSTATE
	cmp	#1
	bne	:act
:done	plp
	rts
:act	cmp	#0
	bne	:up			; 2 = crossing door
* bounce in house
	lda	>PINK_Y
	cmp	#$78
	beq	:rev
	cmp	#$80
	bne	:step
:rev	sep	#$30
	lda	>PINK_DIR
	eor	#$02
	sta	>PINK_DIR
	asl
	tax
	lda	DirDelta,x
	sta	>PINK_TILE_DY
	lda	DirDelta+1,x
	sta	>PINK_TILE_DY+1
:step	sep	#$20
	lda	>PINK_DIR
	sta	>PINK_PREV_DIR
	jsr	StepPinkDelta
	plp
	rts
:up	lda	>PINK_Y
	bne	:upu
	plp
	rts
:upu	dec
	sta	>PINK_Y
	lda	#DIR_UP
	sta	>PINK_DIR
	sta	>PINK_PREV_DIR
	lda	>PINK_Y
	cmp	#$64
	beq	:snap
	jsr	RetilePink
	plp
	rts
:snap	lda	#$2C
	sta	>PINK_TILE_Y
	lda	#$2E
	sta	>PINK_TILE_X
	lda	#0
	sta	>PINK_TILE_DY
	lda	#$01
	sta	>PINK_TILE_DY+1
	lda	#DIR_LEFT
	sta	>PINK_DIR
	sta	>PINK_PREV_DIR
	lda	#1
	sta	>PINK_SUBSTATE
	plp
	rts

LeaveBlue
	php
	sep	#$20
	lda	>BLUE_STATE
	bne	:done			; eyes: not house leave
	lda	>BLUE_SUBSTATE
	cmp	#1
	bne	:act
:done	plp
	rts
:act	cmp	#0
	bne	:chk3
* bounce
	lda	>BLUE_Y
	cmp	#$78
	beq	:rev
	cmp	#$80
	bne	:step
:rev	sep	#$30
	lda	>BLUE_DIR
	eor	#$02
	sta	>BLUE_DIR
	asl
	tax
	lda	DirDelta,x
	sta	>BLUE_TILE_DY
	lda	DirDelta+1,x
	sta	>BLUE_TILE_DY+1
:step	sep	#$20
	lda	>BLUE_DIR
	sta	>BLUE_PREV_DIR
	jsr	StepBlueDelta
	plp
	rts
:chk3	cmp	#3
	bne	:up
* slide arcade-right (X decreases) from $90 → door center $80
	lda	>BLUE_X
	beq	:tile
	dec
	sta	>BLUE_X
	lda	#DIR_RIGHT
	sta	>BLUE_DIR
	sta	>BLUE_PREV_DIR
	lda	>BLUE_X
	cmp	#$80
	bne	:tile
	lda	#2
	sta	>BLUE_SUBSTATE
:tile	jsr	RetileBlue
	plp
	rts
:up	lda	>BLUE_Y
	bne	:upu
	plp
	rts
:upu	dec
	sta	>BLUE_Y
	lda	#DIR_UP
	sta	>BLUE_DIR
	sta	>BLUE_PREV_DIR
	lda	>BLUE_Y
	cmp	#$64
	beq	:snap
	jsr	RetileBlue
	plp
	rts
:snap	lda	#$2C
	sta	>BLUE_TILE_Y
	lda	#$2E
	sta	>BLUE_TILE_X
	lda	#0
	sta	>BLUE_TILE_DY
	lda	#$01
	sta	>BLUE_TILE_DY+1
	lda	#DIR_LEFT
	sta	>BLUE_DIR
	sta	>BLUE_PREV_DIR
	lda	#1
	sta	>BLUE_SUBSTATE
	plp
	rts

LeaveOrange
	php
	sep	#$20
	lda	>ORANGE_STATE
	bne	:done			; eyes: not house leave
	lda	>ORANGE_SUBSTATE
	cmp	#1
	bne	:act
:done	plp
	rts
:act	cmp	#0
	bne	:chk3
	lda	>ORANGE_Y
	cmp	#$78
	beq	:rev
	cmp	#$80
	bne	:step
:rev	sep	#$30
	lda	>ORANGE_DIR
	eor	#$02
	sta	>ORANGE_DIR
	asl
	tax
	lda	DirDelta,x
	sta	>ORANGE_TILE_DY
	lda	DirDelta+1,x
	sta	>ORANGE_TILE_DY+1
:step	sep	#$20
	lda	>ORANGE_DIR
	sta	>ORANGE_PREV_DIR
	jsr	StepOrangeDelta
	plp
	rts
:chk3	cmp	#3
	bne	:up
* slide arcade-left (X increases) from $70 → door center $80
	lda	>ORANGE_X
	inc
	sta	>ORANGE_X
	lda	#DIR_LEFT
	sta	>ORANGE_DIR
	sta	>ORANGE_PREV_DIR
	lda	>ORANGE_X
	cmp	#$80
	bne	:tile
	lda	#2
	sta	>ORANGE_SUBSTATE
:tile	jsr	RetileOrange
	plp
	rts
:up	lda	>ORANGE_Y
	bne	:upu
	plp
	rts
:upu	dec
	sta	>ORANGE_Y
	lda	#DIR_UP
	sta	>ORANGE_DIR
	sta	>ORANGE_PREV_DIR
	lda	>ORANGE_Y
	cmp	#$64
	beq	:snap
	jsr	RetileOrange
	plp
	rts
:snap	lda	#$2C
	sta	>ORANGE_TILE_Y
	lda	#$2E
	sta	>ORANGE_TILE_X
	lda	#0
	sta	>ORANGE_TILE_DY
	lda	#$01
	sta	>ORANGE_TILE_DY+1
	lda	#DIR_LEFT
	sta	>ORANGE_DIR
	sta	>ORANGE_PREV_DIR
	lda	#1
	sta	>ORANGE_SUBSTATE
	plp
	rts

* Step ±1px from TILE_DY word (dY,dX)
StepPinkDelta
	php
	sep	#$20
	lda	>PINK_TILE_DY
	beq	:x
	bmi	:u
	lda	>PINK_Y
	inc
	sta	>PINK_Y
	bra	:t
:u	lda	>PINK_Y
	beq	:t
	dec
	sta	>PINK_Y
	bra	:t
:x	lda	>PINK_TILE_DY+1
	beq	:t
	bmi	:l
	lda	>PINK_X
	inc
	sta	>PINK_X
	bra	:t
:l	lda	>PINK_X
	dec
	sta	>PINK_X
:t	jsr	RetilePink
	plp
	rts

StepBlueDelta
	php
	sep	#$20
	lda	>BLUE_TILE_DY
	beq	:x
	bmi	:u
	lda	>BLUE_Y
	inc
	sta	>BLUE_Y
	bra	:t
:u	lda	>BLUE_Y
	beq	:t
	dec
	sta	>BLUE_Y
	bra	:t
:x	lda	>BLUE_TILE_DY+1
	beq	:t
	bmi	:l
	lda	>BLUE_X
	inc
	sta	>BLUE_X
	bra	:t
:l	lda	>BLUE_X
	dec
	sta	>BLUE_X
:t	jsr	RetileBlue
	plp
	rts

StepOrangeDelta
	php
	sep	#$20
	lda	>ORANGE_TILE_DY
	beq	:x
	bmi	:u
	lda	>ORANGE_Y
	inc
	sta	>ORANGE_Y
	bra	:t
:u	lda	>ORANGE_Y
	beq	:t
	dec
	sta	>ORANGE_Y
	bra	:t
:x	lda	>ORANGE_TILE_DY+1
	beq	:t
	bmi	:l
	lda	>ORANGE_X
	inc
	sta	>ORANGE_X
	bra	:t
:l	lda	>ORANGE_X
	dec
	sta	>ORANGE_X
:t	jsr	RetileOrange
	plp
	rts

RetileRed
	php
	sep	#$20
	lda	>RED_Y
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

RetilePink
	php
	sep	#$20
	lda	>PINK_Y
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

RetileBlue
	php
	sep	#$20
	lda	>BLUE_Y
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

RetileOrange
	php
	sep	#$20
	lda	>ORANGE_Y
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

* ---------------------------------------------------------------
* GhostHouse — == j_13dd (idle timeout release)
* ---------------------------------------------------------------
GhostHouse
	php
	sep	#$20
	lda	>DOTS_EATEN
	cmp	>PILLS_SINCE_PAC_MOVE
	beq	:idle
	rep	#$30
	lda	#0
	sta	>LEAVE_HOME_IDLE
	plp
	rts
:idle	rep	#$30
	lda	>LEAVE_HOME_IDLE
	inc
	sta	>LEAVE_HOME_IDLE
	cmp	>LEAVE_HOME_UNITS
	bne	:out
	lda	#0
	sta	>LEAVE_HOME_IDLE
	sep	#$20
	lda	>PINK_SUBSTATE
	bne	:b
	jsr	ReleasePink
	bra	:out
:b	lda	>BLUE_SUBSTATE
	bne	:o
	jsr	ReleaseBlue
	bra	:out
:o	lda	>ORANGE_SUBSTATE
	bne	:out
	jsr	ReleaseOrange
:out	plp
	rts

* ---------------------------------------------------------------
* Release helpers — == j_2086 / j_20a9 / j_20d1
* ---------------------------------------------------------------
ReleasePink
	php
	sep	#$20
	lda	#2
	sta	>PINK_SUBSTATE
	plp
	rts

ReleaseBlue
	php
	sep	#$20
	lda	#3
	sta	>BLUE_SUBSTATE
	plp
	rts

ReleaseOrange
	php
	sep	#$20
	lda	#3
	sta	>ORANGE_SUBSTATE
	plp
	rts

* ---------------------------------------------------------------
* HouseDotInc — == j_1b08 (on pellet eat)
* ---------------------------------------------------------------
HouseDotInc
	php
	sep	#$20
	lda	>DIED_THIS_LEVEL
	beq	:norm
	lda	>PILLS_AFTER_DEATH
	inc
	sta	>PILLS_AFTER_DEATH
	plp
	rts
:norm	lda	>ORANGE_SUBSTATE
	bne	:done			; orange already out → no personal counters
	lda	>BLUE_SUBSTATE
	beq	:chkp
	lda	>ORANGE_EXIT_CNT
	inc
	sta	>ORANGE_EXIT_CNT
	plp
	rts
:chkp	lda	>PINK_SUBSTATE
	beq	:pink
	lda	>BLUE_EXIT_CNT
	inc
	sta	>BLUE_EXIT_CNT
	plp
	rts
:pink	lda	>PINK_EXIT_CNT
	inc
	sta	>PINK_EXIT_CNT
:done	plp
	rts

* ---------------------------------------------------------------
* ReleaseDotChecks — == j_2069 / j_208c / j_20af
* ---------------------------------------------------------------
ReleaseDotChecks
	php
	jsr	ReleaseCheckPink
	jsr	ReleaseCheckBlue
	jsr	ReleaseCheckOrange
	plp
	rts

ReleaseCheckPink
	php
	sep	#$20
	lda	>PINK_SUBSTATE
	bne	:done
	lda	>DIED_THIS_LEVEL
	beq	:lim
	lda	>PILLS_AFTER_DEATH
	cmp	#7
	bne	:done
	jsr	ReleasePink
	bra	:done
:lim	lda	>PINK_EXIT_CNT
	cmp	>PINK_EXIT_LIMIT
	bcc	:done
	jsr	ReleasePink
:done	plp
	rts

ReleaseCheckBlue
	php
	sep	#$20
	lda	>BLUE_SUBSTATE
	bne	:done
	lda	>DIED_THIS_LEVEL
	beq	:lim
	lda	>PILLS_AFTER_DEATH
	cmp	#$11
	bne	:done
	jsr	ReleaseBlue
	bra	:done
:lim	lda	>BLUE_EXIT_CNT
	cmp	>BLUE_EXIT_LIMIT
	bcc	:done
	jsr	ReleaseBlue
:done	plp
	rts

ReleaseCheckOrange
	php
	sep	#$20
	lda	>ORANGE_SUBSTATE
	bne	:done
	lda	>DIED_THIS_LEVEL
	beq	:lim
	lda	>PILLS_AFTER_DEATH
	cmp	#$20
	bne	:done
* arcade quirk: clear death flags, do not release
	lda	#0
	sta	>DIED_THIS_LEVEL
	sta	>PILLS_AFTER_DEATH
	bra	:done
:lim	lda	>ORANGE_EXIT_CNT
	cmp	>ORANGE_EXIT_LIMIT
	bcc	:done
	jsr	ReleaseOrange
:done	plp
	rts
