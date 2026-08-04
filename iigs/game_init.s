*
* Game-build InitActors — == task #04 @ #253D spawn + difficulty #070E level1.
*
	mx	%00

InitActors
* Entry from frame_body Start (same label as demo rails InitActors).
	php
	rep	#$30
* Clear #4D00–#4E3F mirror
	lda	#0
	ldx	#0
]z	sta	>RAM4D,x
	inx
	inx
	cpx	#$0140
	bcc	]z
	sep	#$20
	lda	#3
	sta	>GAME_MODE		; playing
	sta	>LEVEL_STATE		; active maze
	lda	#0
	sta	>LEVEL_NUMBER
	lda	#0
	sta	>LEVEL
	lda	#START_LIVES
	sta	>LIVES
	sta	>LIVES_REAL
	lda	#0
	sta	>DOTS_EATEN
	lda	#0
	sta	>FRUIT_ACTIVE
	lda	#0
	sta	>FRUIT_SPAWNED
	lda	#$FF
	sta	>PAC_MOVE_DELAY
	lda	#$FF
	sta	>STICK_IN0		; none pressed (active-low)
* Speed patterns level 1
	rep	#$30
	ldx	#0
]sp	lda	Level1Speed,x
	sta	>SPD_PAC_NORM,x
	inx
	inx
	cpx	#Level1SpeedLen
	bcc	]sp
* Fright duration word == #4DBD from difficulty table (level1 $02D0)
	rep	#$30
	lda	#FrightTimeLevel1
	sta	>FRIGHT_TIME
	sep	#$20
	jsr	InitArcadeActors
	jsr	ActorPublish
* Seed ACT_OX/OY
	rep	#$30
	ldx	#$8400
]c	lda	>BANK2+ACT_X,x
	sta	>BANK2+ACT_OX,x
	lda	>BANK2+ACT_Y,x
	sta	>BANK2+ACT_OY,x
	txa
	clc
	adc	#16
	tax
	cpx	#$8460
	bcc	]c
	plp
	rts

InitArcadeActors
* == #253D parameter 0 positions
	php
	sep	#$20
	lda	#$64
	sta	>RED_Y
	lda	#$80
	sta	>RED_X
	lda	#$7C
	sta	>PINK_Y
	lda	#$80
	sta	>PINK_X
	lda	#$7C
	sta	>BLUE_Y
	lda	#$90
	sta	>BLUE_X
	lda	#$7C
	sta	>ORANGE_Y
	lda	#$70
	sta	>ORANGE_X
	lda	#$C4
	sta	>PAC_Y
	lda	#$80
	sta	>PAC_X
* Tile words from #2594: (Y,X) = #2C2E red, #2F2E pink, #2F30 blue, #2F2C orange, #382E pac
	lda	#$2C
	sta	>RED_TILE_Y
	lda	#$2E
	sta	>RED_TILE_X
	lda	#$2F
	sta	>PINK_TILE_Y
	lda	#$2E
	sta	>PINK_TILE_X
	lda	#$2F
	sta	>BLUE_TILE_Y
	lda	#$30
	sta	>BLUE_TILE_X
	lda	#$2F
	sta	>ORANGE_TILE_Y
	lda	#$2C
	sta	>ORANGE_TILE_X
	lda	#$38
	sta	>PAC_TILE_Y
	lda	#$2E
	sta	>PAC_TILE_X
* Tile deltas are words (dY,dX) little-endian — == #25C1..#25EB
* #0100 → dy=0,dx=1 (left on upright after publish); #0001 → dy=1,dx=0
	lda	#0
	sta	>RED_TILE_DY		; #0100
	lda	#$01
	sta	>RED_TILE_DY+1
	lda	#$01
	sta	>PINK_TILE_DY		; #0001
	lda	#0
	sta	>PINK_TILE_DY+1
	lda	#$FF
	sta	>BLUE_TILE_DY		; #00FF
	lda	#0
	sta	>BLUE_TILE_DY+1
	lda	#$FF
	sta	>ORANGE_TILE_DY		; #00FF
	lda	#0
	sta	>ORANGE_TILE_DY+1
	lda	#0
	sta	>PAC_TILE_DY		; #0100 left
	lda	#$01
	sta	>PAC_TILE_DY+1
	lda	#0
	sta	>PAC_WANT_DY
	lda	#$01
	sta	>PAC_WANT_DX
	lda	#DIR_LEFT		; #02
	sta	>PAC_DIR
	sta	>PAC_WANT_DIR
	lda	#DIR_LEFT		; #0102 → red=2, pink=1
	sta	>RED_DIR
	sta	>RED_PREV_DIR
	lda	#DIR_DOWN
	sta	>PINK_DIR
	sta	>PINK_PREV_DIR
	lda	#DIR_UP			; #0303
	sta	>BLUE_DIR
	sta	>BLUE_PREV_DIR
	sta	>ORANGE_DIR
	sta	>ORANGE_PREV_DIR
	lda	#0
	sta	>RED_STATE
	lda	#0
	sta	>PINK_STATE
	lda	#0
	sta	>BLUE_STATE
	lda	#0
	sta	>ORANGE_STATE
	lda	#0
	sta	>RED_FRIGHT
	lda	#0
	sta	>PINK_FRIGHT
	lda	#0
	sta	>BLUE_FRIGHT
	lda	#0
	sta	>ORANGE_FRIGHT
	lda	#0
	sta	>POWER_PILL_ACT
* Red starts outside; pink/blue/orange bounce in house until released
	lda	#1
	sta	>RED_SUBSTATE
	lda	#0
	sta	>PINK_SUBSTATE
	sta	>BLUE_SUBSTATE
	sta	>ORANGE_SUBSTATE
	lda	#$55
	sta	>GHOST_HOME_MOVE
	rep	#$30
	lda	#LeaveHomeUnitsLevel1
	sta	>LEAVE_HOME_UNITS
	lda	#0
	sta	>LEAVE_HOME_IDLE
	sep	#$20
	lda	#LeaveLimitPink
	sta	>PINK_EXIT_LIMIT
	lda	#LeaveLimitBlue
	sta	>BLUE_EXIT_LIMIT
	lda	#LeaveLimitOrange
	sta	>ORANGE_EXIT_LIMIT
	lda	#0
	sta	>PINK_EXIT_CNT
	sta	>BLUE_EXIT_CNT
	sta	>ORANGE_EXIT_CNT
* Preserve DIED_THIS_LEVEL across death respawn (InitActors RAM clear zeros it)
	lda	#0
	sta	>PILLS_AFTER_DEATH
	lda	>DOTS_EATEN
	sta	>PILLS_SINCE_PAC_MOVE
	plp
	rts
