*
* Harness self-test routines (lower/host/selftest.c). Not game logic.
*

* A = A + X.
st_add
	sta	T0
	txa
	clc
	adc	T0
	rts

* A = A + X in decimal mode.
st_bcd
	sta	T0
	txa
	sed
	clc
	adc	T0
	cld
	rts

* The word Y at game-bank address X.
st_store16
	rep	#$20
	tya
	sta	|$0000,x
	sep	#$20
	rts

* X = the word at game-bank address X.
st_load16
	rep	#$20
	lda	|$0000,x
	tax
	sep	#$20
	rts
