*
* Game FrameTick — == j_008d logic portion (after HW publish).
*
	mx	%00

FrameTick
LogicTick
	php
	rep	#$30
	lda	>FRAME_COUNT
	inc
	sta	>FRAME_COUNT
	jsr	LevelFsm
	jsr	ActorPublish
	plp
	rts
