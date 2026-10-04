*
* Helpers the lowered files share. Not hooked: checked through callers.
*

* copy_bytes: A bytes (1-255) from game-bank X to game-bank Y.
* Advances X and Y past the copy. Changes T15.
copyb
	sta	T15
:l	lda	|$0000,x
	sta	|$0000,y
	inx
	iny
	dec	T15
	bne	:l
	rts

* fill_bytes: Y bytes (16-bit count, may be 0) of value A from game-bank X.
* Advances X past the fill.
fillb
	cpy	#0
	beq	:done
:l	sta	|$0000,x
	inx
	dey
	bne	:l
:done	rts

* The I/O versions store through (T12): an indexed store reads its target
* first, and a read of IN0/IN1 consumes replay input.

* io_fill: Y bytes (1-255) of value A to game-bank X. Changes T12-T13.
iofill
	stx	T12
:l	sta	(T12)
	rep	#$20
	inc	T12
	sep	#$20
	dey
	bne	:l
	rts

* io_copy: A bytes (1-255) from game-bank X to game-bank Y.
* Changes T12-T14.
iocopy
	sty	T12
	sta	T14
:l	lda	|$0000,x
	sta	(T12)
	inx
	rep	#$20
	inc	T12
	sep	#$20
	dec	T14
	bne	:l
	rts

* A = A * 3, 8-bit wrap. Changes T14.
mul3
	sta	T14
	asl
	clc
	adc	T14
	rts
