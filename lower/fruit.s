*
* fruit.c: when the fruit appears, the path it bounces along, its exit.
*

FRUIT_TYPES	equ	$879D	; code, color, points per fruit
ENTRY_PATHS	equ	$87F8	; per-maze lists of entry paths
EXIT_PATHS	equ	$8800
HOUSE_PATH	equ	$8808	; loop around the ghost house
BOUNCE_STEPS	equ	$8841	; position delta per bounce step
SPR_FRUIT_CODE	equ	sprite+12
SPR_FRUIT_COLOR	equ	sprite+13

* clear_fruit ($1000), timed task 4.
clear_fruit
	stz	fruit_points
	rts

* clear_fruit_pos ($3678), timed task 5.
clear_fruit_pos
	stz	fruit_pos_y
	stz	fruit_pos_x
	rts

* set_path(path in X, length in A).
set_path
	stx	fruit_path_ptr
	sta	fruit_path_index
	lda	#$1F
	sta	fruit_bounce_index
	rts

* choose_path(table in X) -> X ($87CD): one of this maze's four paths
* at random. An entry is the path, its length, and the start position.
* T8 list, then the entry; T10 pick; T12 path.
choose_path
	jsr	maze_word
	stx	T8
	jsr	lift_random_byte
	and	#$03
	sta	T10
	asl
	asl
	clc
	adc	T10
	rep	#$20
	and	#$00FF
	clc
	adc	T8
	sta	T8
	tax
	lda	|$0000,x
	sta	T12
	sep	#$20
	lda	|$0002,x
	ldx	T12
	jsr	set_path
	ldx	T8
	rts

* release_fruit ($8747): a fruit after 64 and after 176 pills. From
* level 7 the fruit is random.
release_fruit
	lda	dots_eaten
	ldx	#fruit1_released
	cmp	#$40
	beq	:rel
	ldx	#fruit2_released
	cmp	#$B0
	beq	:rel
	rts
:rel	lda	|$0000,x
	beq	:go
	rts
:go	lda	#1
	sta	|$0000,x
	lda	level_number
	cmp	#7
	bcc	:have
	jsr	lift_random_byte
	and	#$1F
:mod	cmp	#7
	bcc	:have
	sbc	#7
	bra	:mod
:have	jsr	mul3
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	|FRUIT_TYPES,x
	sta	SPR_FRUIT_CODE
	lda	|FRUIT_TYPES+1,x
	sta	SPR_FRUIT_COLOR
	lda	|FRUIT_TYPES+2,x
	sta	fruit_points
	ldx	#ENTRY_PATHS
	jsr	choose_path
	lda	|$0003,x
	sta	fruit_pos_y
	lda	|$0004,x
	sta	fruit_pos_x
	rts

* next_bounce(index in A): the path packs four 2-bit directions per
* byte, low bits first; the direction picks a 16-step bounce.
* T8 index, T9 packed.
next_bounce
	sta	T8
	lsr
	lsr
	rep	#$20
	and	#$00FF
	clc
	adc	fruit_path_ptr
	tax
	sep	#$20
	lda	|$0000,x
	sta	T9
	lda	T8
	and	#$03
	beq	:got
:sh	lsr	T9
	lsr	T9
	dec
	bne	:sh
:got	lda	T9
	and	#$03
	asl
	asl
	asl
	asl
	sta	fruit_bounce_index
	lda	effect+effect_SIZE+effect_SIZE
	ora	#$20
	sta	effect+effect_SIZE+effect_SIZE
	rts

* end_of_path ($87B5): off screen the fruit goes; otherwise it circles
* the ghost house, then takes an exit path.
end_of_path
	lda	fruit_pos_x
	clc
	adc	#$20
	cmp	#$40
	bcs	:on
	stz	SPR_FRUIT_COLOR
	stz	fruit_points
	rts
:on	ldx	fruit_path_ptr
	cpx	#HOUSE_PATH
	beq	:exit
	ldx	#HOUSE_PATH
	lda	#$1D
	jmp	set_path
:exit	ldx	#EXIT_PATHS
	jsr	choose_path
	rts

* move_fruit ($86EE): one frame of the fruit; it waits out a pending
* ghost-eaten pause. T8 bounce step.
move_fruit
	lda	ghosts_killed_pending
	beq	:go
	rts
:go	lda	fruit_points
	beq	:rel
	lda	fruit_pos_y
	bne	:move
:rel	jmp	release_fruit
:move	lda	fruit_bounce_index
	sta	T8
	asl
	rep	#$20
	and	#$00FF
	tax
	lda	|BOUNCE_STEPS,x
	clc
	adc	fruit_pos
	sta	fruit_pos
	sep	#$20
	lda	T8
	inc
	sta	fruit_bounce_index
	and	#$0F
	beq	:step
	rts
:step	dec	fruit_path_index
	lda	fruit_path_index
	bmi	:end
	jmp	next_bounce
:end	jmp	end_of_path
