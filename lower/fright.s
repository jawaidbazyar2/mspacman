*
* fright.c: blue ghosts, their flashing and timer, collisions, and the
* points shown for an eaten ghost. sprite+2g+2 is ghost g's code,
* sprite+2g+3 its color; Ms. Pac-Man's color is sprite+11.
*

BLUE_CODE	equ	$1C
BLUE_COLOR	equ	$11
WHITE_COLOR	equ	$12
EYES_CODE	equ	$20
EYES_COLOR	equ	$19
POINTS_COLOR	equ	$18
PAC_COLOR	equ	$09
SPR_PAC_COLOR	equ	sprite+11
EFFECT2	equ	effect+effect_SIZE
EFFECT3	equ	effect+effect_SIZE+effect_SIZE

* color_eyes ($0BD6): eyes keep their own color. T0 color.
color_eyes
	lda	game_mode_sub1
	cmp	#$22
	beq	:zero
	lda	#EYES_COLOR
	bra	:c
:zero	lda	#0
:c	sta	T0
	ldx	#0
	ldy	#0
:loop	lda	ghost_state,x
	beq	:next
	lda	T0
	sta	sprite+3,y
:next	inx
	iny
	iny
	cpx	#4
	bcc	:loop
	rts

* start_fright ($1A6A): an energizer turns every ghost blue and makes
* them reverse.
start_fright
	lda	pac_move_delay
	cmp	#6
	beq	:go
	rts
:go	ldx	frightened_time_lo
	stx	frightened_timer_lo
	lda	#1
	sta	power_pill_active
	ldx	#$0101
	stx	frightened
	stx	frightened+2
	stx	reverse
	stx	reverse+2
	sta	reverse+4
	stz	frightened_flash_counter
	stz	ghosts_killed_count
	ldx	#BLUE_COLOR*$100+BLUE_CODE
	stx	sprite+2
	stx	sprite+4
	stx	sprite+6
	stx	sprite+8
	lda	EFFECT2
	ora	#$20
	and	#$7F
	sta	EFFECT2
	rts

* fright_countdown ($1376): the pill runs out, or ends once no ghost is
* blue. Eyes stay frightened until home.
fright_countdown
	lda	power_pill_active
	bne	:go
	rts
:go	lda	frightened
	ora	frightened+1
	ora	frightened+2
	ora	frightened+3
	beq	:end
	rep	#$20
	dec	frightened_timer_lo
	sep	#$20
	beq	:end
	rts
:end	lda	#PAC_COLOR
	sta	SPR_PAC_COLOR
	ldx	#0
:g	lda	ghost_state,x
	bne	:n
	stz	frightened,x
:n	inx
	cpx	#4
	bcc	:g
	stz	frightened_timer_lo
	stz	frightened_timer_hi
	stz	power_pill_active
	stz	frightened_flash_counter
	stz	ghosts_killed_count
	lda	EFFECT2
	and	#$5F
	sta	EFFECT2
	rts

* flash_ghosts ($0AC3): every 14 frames repaint the ghosts; blue ones
* flash white near the end. T0 ending.
flash_ghosts
	lda	ghosts_killed_pending
	beq	:go
	rts
:go	lda	frightened_flash_counter
	bne	:dec
	ldx	frightened_timer_lo
	cpx	#$0100
	lda	#0
	bcs	:e
	inc
:e	sta	T0
	lda	#$0E
	sta	frightened_flash_counter
	lda	power_pill_active
	beq	:ghosts
	lda	T0
	beq	:ghosts
	lda	EFFECT2
	ora	#$80
	sta	EFFECT2
	lda	SPR_PAC_COLOR
	cmp	#PAC_COLOR
	bne	:p
	lda	EFFECT2
	and	#$7F
	sta	EFFECT2
:p	lda	#PAC_COLOR
	sta	SPR_PAC_COLOR
:ghosts	ldx	#0
	ldy	#0
:g	lda	frightened,x
	bne	:blue
	txa
	asl
	inc
	sta	sprite+3,y
	bra	:n
:blue	lda	T0
	beq	:n
	lda	sprite+3,y
	cmp	#BLUE_COLOR
	beq	:w
	lda	#BLUE_COLOR
	bra	:s
:w	lda	#WHITE_COLOR
:s	sta	sprite+3,y
:n	inx
	iny
	iny
	cpx	#4
	bcc	:g
:dec	dec	frightened_flash_counter
	rts

* ghost_hit(who in A): a ghost (1-4, 0 none) met Ms. Pac-Man. A blue
* one is eaten and scores; any other kills her.
ghost_hit
	sta	ghosts_killed_pending
	sta	pac_death_anim
	cmp	#0
	beq	:done
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	frightened-1,x
	beq	:done
	stz	pac_death_anim
	inc	ghosts_killed_count
	lda	ghosts_killed_count
	inc
	jsr	add_score
	lda	EFFECT3
	ora	#$08
	sta	EFFECT3
:done	rts

* tile_collision ($171D): a live ghost on her tile; orange first.
tile_collision
	ldx	#3
:loop	lda	ghost_state,x
	bne	:next
	phx
	rep	#$20
	txa
	asl
	tax
	lda	tile,x
	tax
	sep	#$20
	ldy	tile+8
	jsr	coord_eq
	plx
	cmp	#0
	bne	:hit
:next	dex
	bpl	:loop
:hit	txa
	inc
	jmp	ghost_hit

* pixel_collision ($1789): during a pill, a live ghost 0-3 pixels past
* her on both axes.
pixel_collision
	lda	ghosts_killed_pending
	bne	:ret
	lda	power_pill_active
	bne	:go
:ret	rts
:go	ldx	#3
	ldy	#6
:loop	lda	ghost_state,x
	bne	:next
	lda	pos,y
	sec
	sbc	pos+8
	cmp	#4
	bcs	:next
	lda	pos+1,y
	sec
	sbc	pos+9
	cmp	#4
	bcc	:hit
:next	dey
	dey
	dex
	bpl	:loop
:hit	txa
	inc
	jmp	ghost_hit

* show_eaten_ghost ($1235): the eaten ghost shows its points with her
* hidden; a timed task moves it on, then it becomes eyes. T8 code.
show_eaten_ghost
	lda	killed_ghost_anim
	cmp	#1
	beq	:ret
	cmp	#3
	bcs	:ret
	lda	ghosts_killed_pending
	asl
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	killed_ghost_anim
	beq	:points
	lda	#EYES_CODE
	sta	sprite,x
	lda	#PAC_COLOR
	sta	SPR_PAC_COLOR
	lda	ghosts_killed_pending
	sta	kill_ghost_state
	stz	ghosts_killed_pending
	stz	killed_ghost_anim
	lda	EFFECT2
	ora	#$40
	sta	EFFECT2
:ret	rts
:points	lda	ghosts_killed_count
	clc
	adc	#$27
	sta	T8
	lda	player_number
	and	dip_cocktail
	beq	:up
	lda	T8
	ora	#$C0
	sta	T8
:up	lda	T8
	sta	sprite,x
	lda	#POINTS_COLOR
	sta	sprite+1,x
	stz	SPR_PAC_COLOR
	lda	#$4A		; TIMER(1, $0A)
	ldx	#3		; TT_EATEN_GHOST
	ldy	#0
	jsr	queue_timed
	cmp	#0
	beq	:done
	inc	killed_ghost_anim
:done	rts
