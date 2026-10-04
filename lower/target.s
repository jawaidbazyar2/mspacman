*
* target.c: ghost chase, scatter, and flee targets, and the demo's
* steering for Ms. Pac-Man.
*

SCATTER_CORNERS	equ	$9578	; per-maze lists of 4 corner tiles
ABOVE_DOOR	equ	$2E2C	; Coords: y low, x high
BLUE_CORNER	equ	$2040
ORANGE_CORNER	equ	$3B40

* sq8(A) -> T4: A squared, 16 bits. Changes T2-T7.
sq8
	rep	#$20
	and	#$00FF
	sta	T2
	sta	T6
	stz	T4
:loop	lsr	T2
	bcc	:skip
	lda	T4
	clc
	adc	T6
	sta	T4
:skip	asl	T6
	lda	T2
	bne	:loop
	sep	#$20
	rts

* distance2(a in X, b in Y) -> X ($29EA): squared distance, 16 bits.
* Changes T2-T13.
distance2
	stx	T8
	sty	T10
	lda	T8
	sec
	sbc	T10
	bcs	:y
	eor	#$FF
	inc
:y	jsr	sq8
	ldx	T4
	stx	T12
	lda	T9
	sec
	sbc	T11
	bcs	:x
	eor	#$FF
	inc
:x	jsr	sq8
	rep	#$20
	lda	T4
	clc
	adc	T12
	tax
	sep	#$20
	rts

* best_dir(from in X, target in Y, dir in A) -> A ($2966): the open
* direction whose next tile is closest to the target, never reversing.
* Ties go to the later direction. The search state lives in RAM as the
* game leaves it.
best_dir
	stx	path_from
	sty	path_target
	sta	path_best_dir
	eor	#2
	sta	path_opposite_dir
	ldx	#$FFFF
	stx	path_min_dist_lo
	stz	path_try_dir
:loop	lda	path_try_dir
	cmp	path_opposite_dir
	beq	:next
	jsr	dir_step
	txy
	ldx	path_from
	jsr	coord_add
	stx	path_try
	jsr	tile_at
	jsr	is_wall
	bne	:next
	ldx	path_target
	ldy	path_try
	jsr	distance2
	cpx	path_min_dist_lo
	beq	:take
	bcs	:next
:take	stx	path_min_dist_lo
	lda	path_try_dir
	sta	path_best_dir
:next	inc	path_try_dir
	lda	path_try_dir
	cmp	#4
	bcc	:loop
	lda	path_best_dir
	rts

* random_dir(from in X, dir in A) -> A ($291E): a random open
* direction other than back, turning clockwise from a random start.
random_dir
	stx	path_from
	eor	#2
	sta	path_opposite_dir
	jsr	rom_random
	and	#$03
	sta	path_best_dir
:loop	lda	path_best_dir
	cmp	path_opposite_dir
	beq	:turn
	jsr	dir_step
	txy
	ldx	path_from
	jsr	coord_add
	jsr	tile_at
	jsr	is_wall
	beq	:done
:turn	lda	path_best_dir
	inc
	and	#$03
	sta	path_best_dir
	bra	:loop
:done	lda	path_best_dir
	rts

* random_corner -> X ($9561): one of this maze's scatter corners.
random_corner
	ldx	#SCATTER_CORNERS
	jsr	maze_word
	stx	T8
	jsr	lift_random_byte
	and	#$06
	rep	#$20
	and	#$00FF
	clc
	adc	T8
	tax
	lda	|$0000,x
	tax
	sep	#$20
	rts

* scattering -> A, Z clear when scattering: before the first reversal,
* and only during play.
scattering
	lda	ghost_orient_index
	and	#$01
	bne	:no
	lda	level_state
	cmp	#LEVEL_PLAYING
	bne	:no
	lda	#1
	rts
:no	lda	#0
	rts

* head(ghost in Y, dir in A). Changes Y.
head
	sta	dir,y
	jsr	dir_step
	rep	#$20
	tya
	asl
	tay
	txa
	sta	next_step,y
	sep	#$20
	rts

* aim(ghost in Y, target in X): head for the target from the ghost's
* mid tile.
aim
	phy
	stx	T14
	lda	dir,y
	pha
	rep	#$20
	tya
	asl
	tax
	lda	mid_tile,x
	tax
	sep	#$20
	ldy	T14
	pla
	jsr	best_dir
	ply
	jmp	head

* aim_red ($2730): red chases; Cruise Elroy never scatters.
aim_red
	jsr	scattering
	beq	:chase
	lda	cruise_elroy_1
	bne	:chase
	jsr	random_corner
	ldy	#0
	jmp	aim
:chase	ldx	tile+8
	ldy	#0
	jmp	aim

* aim_pink ($276C): four tiles ahead, as one 16-bit add, so a step of
* -1 in y borrows from x.
aim_pink
	jsr	scattering
	beq	:chase
	jsr	random_corner
	ldy	#1
	jmp	aim
:chase	rep	#$20
	lda	step+8
	asl
	asl
	clc
	adc	tile+8
	tax
	sep	#$20
	ldy	#1
	jmp	aim

* aim_blue ($27A9): two tiles ahead, reflected through red. Scatter
* still draws a corner, then ignores it.
aim_blue
	jsr	scattering
	beq	:chase
	jsr	random_corner
	ldx	#BLUE_CORNER
	ldy	#2
	jmp	aim
:chase	rep	#$20
	lda	step+8
	asl
	clc
	adc	tile+8
	sta	T14
	sep	#$20
	lda	T14
	asl
	sec
	sbc	mid_tile
	sta	T14
	lda	T15
	asl
	sec
	sbc	mid_tile+1
	sta	T15
	ldx	T14
	ldy	#2
	jmp	aim

* aim_orange ($27F1): chase until within 8 tiles, then the corner.
aim_orange
	jsr	scattering
	bne	:corner
	ldx	tile+8
	ldy	mid_tile+6
	jsr	distance2
	cpx	#$0040
	bcs	:chase
:corner	jsr	random_corner
	ldx	#ORANGE_CORNER
	ldy	#3
	jmp	aim
:chase	ldx	tile+8
	ldy	#3
	jmp	aim

* flee(ghost in Y) ($283B-$28B9): blue ghosts wander; eyes head home.
flee
	lda	ghost_state,y
	bne	:eyes
	phy
	lda	dir,y
	pha
	rep	#$20
	tya
	asl
	tax
	lda	mid_tile,x
	tax
	sep	#$20
	pla
	jsr	random_dir
	ply
	jmp	head
:eyes	ldx	#ABOVE_DOOR
	jmp	aim

flee_red
	ldy	#0
	jmp	flee
flee_pink
	ldy	#1
	jmp	flee
flee_blue
	ldy	#2
	jmp	flee
flee_orange
	ldy	#3
	jmp	flee

* demo_steer ($28E3): away from pink, reflected through Ms. Pac-Man;
* toward pink while red is blue. T14 target.
demo_steer
	ldx	mid_tile+2
	stx	T14
	lda	frightened
	bne	:go
	lda	tile+8
	asl
	sec
	sbc	T14
	sta	T14
	lda	tile+9
	asl
	sec
	sbc	T15
	sta	T15
:go	ldx	mid_tile+8
	ldy	T14
	lda	pac_wanted_dir
	jsr	best_dir
	sta	pac_wanted_dir
	jsr	dir_step
	stx	next_step+8
	rts
