*
* ghost.c: ghost speed, stepping, the house, eyes going home, and the
* timers that release and reverse them. The per-ghost routines take
* the ghost from GH_G (set_ghost).
*

GH_G	equ	$30	; word: the ghost (ACT_*)
GH_G2	equ	$32	; word: 2 * the ghost, for Coord arrays

HOUSE_WAIT	equ	0
HOUSE_OUT	equ	1
HOUSE_CLIMB	equ	2
HOUSE_SLIDE	equ	3
DOOR_POS	equ	$8064	; eyes stop here, then drop in
EXIT_TILE	equ	$2E2C	; the tile above the door
KEEP_COURSE_COLOR	equ	$1A
TASK_RED_TARGET	equ	$08
TASK_RED_FLEE	equ	$0C
PACMAN_CHASE	equ	$22	; game_mode_sub1 of Pac-Man's title chase

* set_ghost(A): GH_G = A, GH_G2 = 2A.
set_ghost
	sta	GH_G
	stz	GH_G+1
	asl
	sta	GH_G2
	stz	GH_G2+1
	rts

* reverse_ghost -> A ($1EFE-$1F89): turn around. A is what
* bob_in_house compares next: the attract scene byte, or in Pac-Man's
* title chase (dead here) the new direction. T8 turned, T10 step.
reverse_ghost
	ldx	GH_G
	lda	prev_dir,x
	eor	#2
	sta	T8
	sta	dir,x
	jsr	dir_step
	stx	T10
	ldy	GH_G2
	rep	#$20
	txa
	sta	next_step,y
	sep	#$20
	lda	game_mode_sub1
	cmp	#PACMAN_CHASE
	beq	:chase
	rts
:chase	rep	#$20
	lda	T10
	sta	step,y
	sep	#$20
	ldx	GH_G
	lda	T8
	sta	prev_dir,x
	rts

* ghost_step ($1BD8...): one pixel along the step. In the middle of a
* tile: queue the targeting task, reverse if asked, and commit to the
* direction the task chose last time.
ghost_step
	ldx	GH_G2
	lda	step,x
	bne	:y
	lda	pos+1,x
	bra	:a
:y	lda	pos,x
:a	and	#$07
	cmp	#4
	beq	:mid
	jmp	:move
:mid	lda	GH_G
	jsr	tunnel_wrap
	bne	:rev
	ldx	GH_G
	lda	frightened,x
	beq	:tgt
	lda	GH_G
	clc
	adc	#TASK_RED_FLEE
	ldx	#0
	jsr	queue_task
	bra	:rev
:tgt	ldx	GH_G2
	rep	#$20
	lda	mid_tile,x
	tax
	sep	#$20
	jsr	color_at
	cmp	#KEEP_COURSE_COLOR
	beq	:rev
	lda	GH_G
	clc
	adc	#TASK_RED_TARGET
	ldx	#0
	jsr	queue_task
:rev	ldx	GH_G
	lda	reverse,x
	beq	:commit
	stz	reverse,x
	jsr	reverse_ghost
:commit	ldy	GH_G2
	rep	#$20
	lda	mid_tile,y
	tax
	lda	next_step,y
	tay
	sep	#$20
	jsr	coord_add
	ldy	GH_G2
	rep	#$20
	txa
	sta	mid_tile,y
	lda	next_step,y
	sta	step,y
	sep	#$20
	ldx	GH_G
	lda	dir,x
	sta	prev_dir,x
:move	ldy	GH_G2
	rep	#$20
	lda	pos,y
	tax
	lda	step,y
	tay
	sep	#$20
	jsr	coord_add
	ldy	GH_G2
	rep	#$20
	txa
	sta	pos,y
	sep	#$20
	jsr	pos_to_tile
	ldy	GH_G2
	rep	#$20
	txa
	sta	tile,y
	sep	#$20
	rts

* move_ghost(A) ($1B36...): a live ghost out of the house steps when
* its speed pattern says so. Red is out in any substate but 0, and
* follows Cruise Elroy. T8 the speed pattern.
move_ghost
	jsr	set_ghost
	ldx	GH_G
	lda	substate,x
	cpx	#0
	bne	:other
	cmp	#HOUSE_WAIT
	bne	:alive
:out	rts
:other	cmp	#HOUSE_OUT
	bne	:out
:alive	lda	ghost_state,x
	bne	:out
	cpx	#0
	bne	:nel
	jsr	update_elroy
:nel	ldx	GH_G2
	rep	#$20
	lda	tile,x
	tax
	sep	#$20
	jsr	color_at
	and	#$40
	beq	:ns
	lda	#1
:ns	ldx	GH_G
	sta	tunnel_slow,x
	lda	GH_G
	jsr	mul3
	asl
	asl
	rep	#$20
	and	#$00FF
	clc
	adc	#ghost_speed
	sta	T8
	sep	#$20
	ldx	GH_G
	lda	tunnel_slow,x
	beq	:nt
	ldy	#8		; SPEED_TUNNEL
	bra	:addy
:nt	lda	frightened,x
	beq	:nb
	ldy	#4		; SPEED_BLUE
:addy	rep	#$20
	tya
	clc
	adc	T8
	sta	T8
	sep	#$20
	bra	:tick
:nb	cpx	#0
	bne	:tick
	lda	cruise_elroy_2
	beq	:e1
	ldy	#elroy2_speed
	sty	T8
	bra	:tick
:e1	lda	cruise_elroy_1
	beq	:tick
	ldy	#elroy1_speed
	sty	T8
:tick	ldx	T8
	jsr	speed_tick
	cmp	#0
	beq	:ret
	jmp	ghost_step
:ret	rts

move_ghosts
	lda	#0
:l	pha
	jsr	move_ghost
	pla
	inc
	cmp	#4
	bcc	:l
	rts

* eyes_step(dir in A): one pixel; sets both direction bytes.
eyes_step
	ldx	GH_G
	sta	prev_dir,x
	sta	dir,x
	jsr	dir_step
	txy
	ldx	GH_G2
	rep	#$20
	lda	pos,x
	tax
	sep	#$20
	jsr	coord_add
	ldy	GH_G2
	rep	#$20
	txa
	sta	pos,y
	sep	#$20
	rts

* park_eyes ($1101): home; the eyes sound stops once no ghost is eyes.
park_eyes
	lda	GH_G
	cmp	#2
	beq	:blue
	bcs	:orange
	ldx	#$2E2F
	bra	:t
:blue	ldx	#$302F
	bra	:t
:orange	ldx	#$2C2F
:t	ldy	GH_G2
	rep	#$20
	txa
	sta	mid_tile,y
	sta	tile,y
	sep	#$20
	ldx	GH_G
	stz	substate,x
	stz	ghost_state,x
	stz	frightened,x
	lda	ghost_state
	ora	ghost_state+1
	ora	ghost_state+2
	ora	ghost_state+3
	bne	:ret
	lda	EFFECT2
	and	#$BF
	sta	EFFECT2
:ret	rts

* return_eyes(A) ($1094...): eyes fly to the door, drop in, and blue
* and orange slide to their own slots.
return_eyes
	jsr	set_ghost
	ldx	GH_G
	lda	ghost_state,x
	cmp	#1
	beq	:door
	cmp	#2
	beq	:down
	cmp	#3
	beq	:side
	rts
:door	jsr	ghost_step
	ldx	GH_G2
	rep	#$20
	lda	pos,x
	cmp	#DOOR_POS
	sep	#$20
	bne	:r
	ldx	GH_G
	inc	ghost_state,x
:r	rts
:down	lda	#DIR_DOWN
	jsr	eyes_step
	ldx	GH_G2
	lda	pos,x
	cmp	#$80
	bne	:r
	lda	GH_G
	cmp	#2
	bcc	:park
	ldx	GH_G
	inc	ghost_state,x
	rts
:park	jmp	park_eyes
:side	lda	GH_G
	cmp	#2
	bcc	:r
	beq	:bl
	lda	#DIR_RIGHT
	jsr	eyes_step
	lda	#$70
	bra	:chk
:bl	lda	#DIR_LEFT
	jsr	eyes_step
	lda	#$90
:chk	ldx	GH_G2
	cmp	pos+1,x
	bne	:r
	ldx	GH_G
	lda	#DIR_DOWN
	sta	prev_dir,x
	sta	dir,x
	jmp	park_eyes

return_all_eyes
	lda	#0
:l	pha
	jsr	return_eyes
	pla
	inc
	cmp	#4
	bcc	:l
	rts

* mark_eaten_ghost ($1066): the eaten ghost becomes eyes. Values past 4
* run the game's arithmetic.
mark_eaten_ghost
	lda	kill_ghost_state
	bne	:go
	rts
:go	cmp	#4
	bcs	:big
	stz	kill_ghost_state
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	#1
	sta	ghost_state-1,x
	rts
:big	sec
	sbc	#3
	sta	ghost_state+3
	dec
	sta	kill_ghost_state
	rts

* climb_out: up toward the door; at the top the ghost is out, heading
* left.
climb_out
	lda	#DIR_UP
	jsr	eyes_step
	ldx	GH_G2
	lda	pos,x
	cmp	#$64
	beq	:out
	rts
:out	ldy	GH_G2
	rep	#$20
	lda	#EXIT_TILE
	sta	mid_tile,y
	sep	#$20
	lda	#DIR_LEFT
	jsr	dir_step
	ldy	GH_G2
	rep	#$20
	txa
	sta	step,y
	sta	next_step,y
	sep	#$20
	ldx	GH_G
	lda	#DIR_LEFT
	sta	prev_dir,x
	sta	dir,x
	lda	#HOUSE_OUT
	sta	substate,x
	rts

* bob_in_house: turn at $78 and $80. After a turn at the top, the
* bottom compare sees reverse_ghost's A.
bob_in_house
	ldx	GH_G2
	lda	pos,x
	cmp	#$78
	bne	:b
	jsr	reverse_ghost
:b	cmp	#$80
	bne	:c
	jsr	reverse_ghost
:c	ldx	GH_G
	lda	dir,x
	sta	prev_dir,x
	ldy	GH_G2
	rep	#$20
	lda	pos,y
	tax
	lda	next_step,y
	tay
	sep	#$20
	jsr	coord_add
	ldy	GH_G2
	rep	#$20
	txa
	sta	pos,y
	sep	#$20
	rts

* slide_to_center: blue and orange slide to x $80, then climb.
slide_to_center
	lda	GH_G
	cmp	#2
	bne	:or
	lda	#DIR_RIGHT
	bra	:s
:or	lda	#DIR_LEFT
:s	jsr	eyes_step
	ldx	GH_G2
	lda	pos+1,x
	cmp	#$80
	bne	:r
	ldx	GH_G
	lda	#HOUSE_CLIMB
	sta	substate,x
:r	rts

* move_in_house ($0C42): on every other beat of a rotating pattern, and
* not while an eaten ghost is on show.
move_in_house
	lda	ghosts_killed_pending
	beq	:go
	rts
:go	lda	ghost_home_move_counter
	asl
	adc	#0
	sta	ghost_home_move_counter
	and	#$01
	bne	:run
	rts
:run	lda	substate
	bne	:pink
	lda	#0
	jsr	set_ghost
	jsr	climb_out
:pink	lda	#1
:loop	pha
	jsr	set_ghost
	ldx	GH_G
	lda	substate,x
	cmp	#HOUSE_OUT
	beq	:next
	cmp	#HOUSE_WAIT
	bne	:nw
	jsr	bob_in_house
	bra	:next
:nw	cmp	#HOUSE_SLIDE
	bne	:climb
	lda	GH_G
	cmp	#1
	beq	:climb
	jsr	slide_to_center
	bra	:next
:climb	jsr	climb_out
:next	pla
	inc
	cmp	#4
	bcc	:loop
	rts

* release_by_pills ($2069...): pink, blue, orange leave once their pill
* counts reach the limits. After a death one shared count is used; at
* 32 it hands back without releasing orange. X = ghost - 1.
release_by_pills
	ldx	#0
:loop	lda	substate+1,x
	bne	:next
	lda	died_this_level
	beq	:count
	txa
	beq	:a0
	cmp	#1
	beq	:a1
	lda	#$20
	bra	:ad
:a0	lda	#7
	bra	:ad
:a1	lda	#$11
:ad	cmp	pills_after_death
	bne	:next
	cpx	#2
	bne	:rel
	stz	died_this_level
	stz	pills_after_death
	bra	:next
:count	lda	pink_exit_counter,x
	cmp	pink_exit_limit,x
	bcc	:next
:rel	lda	#HOUSE_SLIDE
	cpx	#0
	bne	:s
	lda	#HOUSE_CLIMB
:s	sta	substate+1,x
:next	inx
	cpx	#3
	bcc	:loop
	rts

* count_house_pill ($1B08): a pill counts for the first ghost waiting.
count_house_pill
	lda	died_this_level
	beq	:alive
	inc	pills_after_death
	rts
:alive	lda	substate+3
	bne	:r
	lda	substate+2
	beq	:b
	inc	orange_exit_counter
	rts
:b	lda	substate+1
	beq	:p
	inc	blue_exit_counter
	rts
:p	inc	pink_exit_counter
:r	rts

* release_idle_ghost ($13DD): no pill for long enough lets the next
* waiting ghost out.
release_idle_ghost
	lda	dots_eaten
	cmp	pills_since_pac_move
	beq	:idle
	ldx	#0
	stx	ghost_leave_home_idle_lo
	rts
:idle	rep	#$20
	inc	ghost_leave_home_idle_lo
	lda	ghost_leave_home_idle_lo
	cmp	ghost_leave_home_units_lo
	sep	#$20
	beq	:rel
	rts
:rel	ldx	#0
	stx	ghost_leave_home_idle_lo
	lda	substate+1
	bne	:b
	lda	#HOUSE_CLIMB
	sta	substate+1
	rts
:b	lda	substate+2
	bne	:o
	lda	#HOUSE_SLIDE
	sta	substate+2
	rts
:o	lda	substate+3
	bne	:r
	lda	#HOUSE_SLIDE
	sta	substate+3
:r	rts

* ghost_anim_tick ($0E23): the two-frame animation flips every 8.
ghost_anim_tick
	inc	frame_div8_counter
	lda	frame_div8_counter
	cmp	#8
	bne	:r
	stz	frame_div8_counter
	lda	ghost_anim_phase
	eor	#1
	sta	ghost_anim_phase
:r	rts

* reversal_timer ($0E36): every ghost reverses when the timer reaches
* the table entry. The index is always stored as 1. Paused during a
* power pill.
reversal_timer
	lda	power_pill_active
	bne	:r
	lda	ghost_orient_index
	cmp	#7
	beq	:r
	asl
	rep	#$20
	and	#$00FF
	tax
	inc	ghost_orient_counter_lo
	lda	ghost_orient_counter_lo
	cmp	ghost_orient_table,x
	sep	#$20
	bne	:r
	lda	#1
	sta	ghost_orient_index
	ldx	#$0101
	stx	reverse
	stx	reverse+2
:r	rts
