*
* Keyboard → soft IN0 (active-low) — == IN0 @ #5000 / design §4.
* A=up Z=down ←=left →=right; Esc=pause toggle; Q=quit.
*
	mx	%00

HandleKey
* Called when KBD bit7 set. Carry set → ExitDemo.
	php
	sep	#$20
	lda	>KBD
	and	#$7F
	sta	>KBDSTRB
	cmp	#KEY_ESC
	beq	:pause
	cmp	#'Q'
	beq	:quit
	cmp	#'q'
	beq	:quit
* Direction latch (IIgs keyboard is strobe, not matrix)
	cmp	#KEY_A
	beq	:up
	cmp	#'A'
	beq	:up
	cmp	#'a'
	beq	:up
	cmp	#KEY_Z
	beq	:dn
	cmp	#'Z'
	beq	:dn
	cmp	#'z'
	beq	:dn
	cmp	#KEY_LEFT
	beq	:lf
	cmp	#KEY_RIGHT
	beq	:rt
	plp
	clc
	rts
:pause
* Toggle DEMO_FREEZE — MainLoop skips erase/draw/FrameTick while set.
	lda	>DEMO_FREEZE
	beq	:pOn
	lda	#0
	bra	:pSt
:pOn	lda	#1
:pSt	sta	>DEMO_FREEZE
	plp
	clc
	rts
:up	lda	#%11111110		; clear bit0 → active-low up
	sta	>STICK_IN0
	plp
	clc
	rts
:dn	lda	#%11110111		; clear bit3
	sta	>STICK_IN0
	plp
	clc
	rts
:lf	lda	#%11111101		; clear bit1
	sta	>STICK_IN0
	plp
	clc
	rts
:rt	lda	#%11111011		; clear bit2
	sta	>STICK_IN0
	plp
	clc
	rts
:quit	plp
	sec
	rts
