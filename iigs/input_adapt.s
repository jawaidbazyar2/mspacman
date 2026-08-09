*
* Keyboard → soft IN0 (active-low) — == IN0 @ #5000 / design §4.
* A=up Z=down ←=left →=right; Esc=pause toggle; Q=quit.
*
* Directions use IIe/IIgs any-key-down (AKD = bit7 of $C010 on read):
* level-sensitive like the arcade 4-way stick. Esc/Q stay strobe-edged
* so a held key does not re-fire every frame.
*
	mx	%00

HandleKey
* Call every frame. Carry set → ExitDemo (Q).
	php
	sep	#$20
* Strobe edge ($C000 bit7): pause / quit only
	lda	>KBD
	bpl	:akd
	and	#$7F
	cmp	#KEY_ESC
	beq	:pause
	cmp	#'Q'
	beq	:quit
	cmp	#'q'
	beq	:quit
* Direction (or other) key — fall through; AKD supplies held state
:akd
	lda	>KBDSTRB		; read clears strobe; bit7=AKD, 0–6=key
	bpl	:none			; nothing held → stick centered
	and	#$7F
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
:none	lda	#$FF			; active-low: all released
	sta	>STICK_IN0
	plp
	clc
	rts
:pause
* Toggle DEMO_FREEZE — MainLoop skips erase/draw/FrameTick while set.
	lda	>KBDSTRB		; clear strobe (also samples AKD; unused)
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
:quit	lda	>KBDSTRB
	plp
	sec
	rts
