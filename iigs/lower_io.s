*
* lower_io.s: the IIgs io.s for lower.bin (make iigs-lower puts it in
* place of lower/io.s). Same labels and contract: the value in A with N
* and Z set from it, X and Y kept.
*
* The game bank is plain RAM, so $5000 holds the last latch write, not
* IN0. The host fills the port bytes in the host block each frame from
* the keyboard; under replay (lower-iigs-check) every IN0/IN1 read takes
* the next byte of the session's logged reads instead.
*

HB_IN0	equ	$F010
HB_IN1	equ	$F011
HB_DSW1	equ	$F012
HB_REPLAY	equ	$F013	; nonzero: read the replay stream
IO_PTR	equ	$70	; dp, 24-bit: the next logged read

read_in0
	lda	HB_REPLAY
	bne	io_take
	lda	HB_IN0
	rts

read_in1
	lda	HB_REPLAY
	bne	io_take
	lda	HB_IN1
	rts

io_take
	lda	[IO_PTR]
	php
	rep	#$20
	inc	IO_PTR
	bne	:same
	inc	IO_PTR+2
:same	sep	#$20
	plp
	rts

read_dsw1
	lda	HB_DSW1
	rts

* latch[0], the interrupt enable: the last write to $5000, bit 0.
read_latch0
	lda	|$5000
	and	#1
	rts
