*
* actor.c: direction steps, tiles, the side tunnel, speed patterns.
* A Coord travels as a word, y low and x high.
*

DIR_STEPS	equ	$32FF	; Coord step per DIR_*, stored twice in a row

* dir_step(dir in A) -> X: the ROM step for dir (rst $18).
dir_step
	rep	#$20
	and	#$00FF
	asl
	tax
	lda	|DIR_STEPS,x
	tax
	sep	#$20
	rts

* coord_add(X, Y) -> X: bytewise ($2000), each half wraps.
coord_add
	stx	T0
	sty	T2
	lda	T0
	clc
	adc	T2
	sta	T0
	lda	T1
	clc
	adc	T3
	sta	T1
	ldx	T0
	rts

* coord_eq(X, Y) -> A 0/1.
coord_eq
	sty	T0
	cpx	T0
	beq	:yes
	lda	#0
	rts
:yes	lda	#1
	rts

* coord_word(X) -> X and word_coord(X) -> X: the same bits.
coord_word
word_coord
	rts

* pos_to_tile(X) -> X ($2018): y>>3 + $20, x>>3 + $1E.
pos_to_tile
	stx	T0
	lda	T0
	lsr
	lsr
	lsr
	clc
	adc	#$20
	sta	T0
	lda	T1
	lsr
	lsr
	lsr
	clc
	adc	#$1E
	sta	T1
	ldx	T0
	rts

* tile_cell(X) -> X ($0065): $4040 + (y-$20) + ((x-$20)&$1F)<<5.
tile_cell
	stx	T0
	lda	T1
	sec
	sbc	#$20
	and	#$1F
	rep	#$20
	and	#$00FF
	asl
	asl
	asl
	asl
	asl
	sta	T2
	sep	#$20
	lda	T0
	sec
	sbc	#$20
	rep	#$20
	and	#$00FF
	clc
	adc	T2
	adc	#$4040
	tax
	sep	#$20
	rts

* tile_at(X) -> A: the tile code at a tile position.
tile_at
	jsr	tile_cell
	lda	|$0000,x
	rts

* color_at(X) -> A: its color byte, $400 above. Tiles off the bottom of
* the screen land in the unmapped $4800 page, which reads $BF.
color_at
	jsr	tile_cell
	cpx	#$4800-$400
	bcs	:open
	lda	|$0400,x
	rts
:open	lda	#$BF
	rts

* is_wall(A) -> A: both top bits set.
is_wall
	and	#$C0
	cmp	#$C0
	beq	:yes
	lda	#0
	rts
:yes	lda	#1
	rts

* tunnel_wrap(actor in A) -> A ($1ED0): wrap mid_tile[actor].x through
* the side tunnel; 1 while in the tunnel.
tunnel_wrap
	rep	#$20
	and	#$00FF
	asl
	tax
	sep	#$20
	lda	mid_tile_x,x
	cmp	#$1D
	bne	:not1d
	lda	#$3D
	sta	mid_tile_x,x
	lda	#1
	rts
:not1d	cmp	#$3E
	bne	:not3e
	lda	#$1E
	sta	mid_tile_x,x
	lda	#1
	rts
:not3e	cmp	#$21
	bcc	:in
	cmp	#$3B
	bcs	:in
	lda	#0
	rts
:in	lda	#1
	rts

* speed_tick(pattern at X) -> A: rotate the 32-bit pattern (bytes 0-1
* the high word) left one bit; A is the bit that came out.
speed_tick
	rep	#$20
	lda	|$0000,x
	asl
	lda	|$0002,x
	rol
	sta	|$0002,x
	lda	|$0000,x
	rol
	sta	|$0000,x
	sep	#$20
	lda	#0
	rol
	rts
