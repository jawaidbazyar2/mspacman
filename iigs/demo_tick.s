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

* Demo: any key strobe ends the rail demo (carry set → ExitDemo).
* Called every frame — only quit on $C000 bit7 (new press), not AKD alone.
HandleKey
	php
	sep	#$20
	lda	>KBD
	bpl	:no
	sta	>KBDSTRB
	plp
	sec
	rts
:no	plp
	clc
	rts
