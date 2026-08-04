*
* Demo FrameTick — rail tour + demo HUD economy (not arcade logic).
*
	mx	%00

* FrameTick ≡ DemoTick for the demo build
FrameTick
DemoTick
	php
	rep	#$30
	jsr	AdvanceRails
	lda	>FRAME_COUNT
	inc
	sta	>FRAME_COUNT
	jsr	EatDotsAtPac
	jsr	DemoScoreTick
	jsr	AdvanceFruit
	jsr	BlinkPowerPills
	plp
	rts

* Demo: any meaningful key ends the rail demo (carry set → ExitDemo).
HandleKey
	php
	sep	#$20
	sta	>KBDSTRB
	plp
	sec				; always quit
	rts
