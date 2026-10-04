*
* pac.c: the joystick, cornering, eating, and her death. Ms. Pac-Man is
* actor 4: pos+8, tile+8, step+8, next_step+8, mid_tile+8, dir+4.
*

ENERGIZER	equ	$14
NOT_EATING	equ	$FF
TASK_ADD_SCORE	equ	$19
TASK_DEMO_STEER	equ	$17

PAC_PTS	equ	$38	; eat_fruit: the points
PAC_CELL	equ	$3A	; word: eat_pill's cell
PAC_POS	equ	$3C	; word: pac_step's new position
PAC_ENT	equ	$3E	; arrive: entering the tunnel
PAC_HELD	equ	$3F	; try_turn: stick held
PAC_TUN	equ	$40	; steer: in the tunnel
PAC_P2	equ	$41	; steer: player 2 at a cocktail table
PAC_IN	equ	$42	; steer: the control port
PAC_ST	equ	$43	; pac_death: the state

* centered -> A: the cross-axis pixel is 4.
centered
	lda	dir+4
	and	#$01
	beq	:x
	lda	pos+8
	bra	:c
:x	lda	pos+9
:c	and	#$07
	cmp	#4
	beq	:yes
	lda	#0
	rts
:yes	lda	#1
	rts

* wall_ahead(step in X) -> A: a wall one step from her tile.
wall_ahead
	ldy	tile+8
	jsr	coord_add
	jsr	tile_at
	jmp	is_wall

* eat_fruit -> A, points in PAC_PTS ($1985-$19B1): within 3 pixels the
* fruit sprite becomes the points.
eat_fruit
	lda	fruit_pos_y
	beq	:no
	lda	fruit_points
	beq	:no
	lda	pos+9
	sec
	sbc	fruit_pos_x
	clc
	adc	#3
	cmp	#6
	bcs	:no
	lda	pos+8
	sec
	sbc	fruit_pos_y
	clc
	adc	#3
	cmp	#6
	bcs	:no
	lda	fruit_points
	sta	PAC_PTS
	inc
	inc
	sta	SPR_FRUIT_CODE
	lda	#1
	sta	SPR_FRUIT_COLOR
	rts
:no	lda	#0
	rts

* eat_pill ($19D2): a pill costs one frame, an energizer six. The munch
* sound alternates halves. T8 tile.
eat_pill
	ldx	tile+8
	jsr	tile_cell
	stx	PAC_CELL
	lda	|$0000,x
	sta	T8
	lda	#NOT_EATING
	sta	pac_move_delay
	lda	T8
	cmp	#PILL
	beq	:eat
	cmp	#ENERGIZER
	beq	:eat
	rts
:eat	inc	dots_eaten
	ldx	PAC_CELL
	lda	#TILE_BLANK
	sta	|$0000,x
	lda	T8
	cmp	#ENERGIZER
	beq	:en
	lda	#TASK_ADD_SCORE
	ldx	#0
	jsr	queue_task
	lda	#1
	bra	:d
:en	lda	#TASK_ADD_SCORE
	ldx	#1
	jsr	queue_task
	lda	#6
:d	sta	pac_move_delay
	jsr	count_house_pill
	jsr	start_fright
	lda	dots_eaten
	and	#$01
	beq	:even
	lda	EFFECT3
	and	#$FE
	ora	#$02
	sta	EFFECT3
	rts
:even	lda	EFFECT3
	ora	#$01
	and	#$FD
	sta	EFFECT3
	rts

* arrive(pos in X) ($1985): she has moved. Nothing is eaten on the frame
* she enters the tunnel.
arrive
	lda	pac_entering_tunnel
	sta	PAC_ENT
	stx	pos+8
	jsr	pos_to_tile
	stx	tile+8
	stz	pac_entering_tunnel
	lda	PAC_ENT
	beq	:go
	rts
:go	jsr	eat_fruit
	beq	:pill
	lda	PAC_PTS
	sta	T8
	stz	T9
	lda	#TASK_ADD_SCORE
	ldx	T8
	jsr	queue_task
	jsr	clear_fruit
	lda	#$54		; TIMER(1, $14)
	ldx	#5		; TT_CLEAR_FRUIT_POS
	ldy	#0
	jsr	queue_timed
	cmp	#0
	bne	:snd
	rts
:snd	lda	EFFECT3
	ora	#$04
	sta	EFFECT3
:pill	jmp	eat_pill

* pac_step ($1950): one pixel along her step, pulled toward the middle
* of the other axis.
pac_step
	ldx	pos+8
	ldy	step+8
	jsr	coord_add
	stx	PAC_POS
	lda	dir+4
	and	#$01
	beq	:y
	ldx	#1
	bra	:a
:y	ldx	#0
:a	lda	PAC_POS,x
	and	#$07
	cmp	#4
	beq	:done
	bcs	:dec
	inc	PAC_POS,x
	bra	:done
:dec	dec	PAC_POS,x
:done	ldx	PAC_POS
	jmp	arrive

* adopt(turn in A): take the wanted step; a held stick turns her.
adopt
	ldx	next_step+8
	stx	step+8
	cmp	#0
	beq	:s
	lda	pac_wanted_dir
	sta	dir+4
:s	jmp	pac_step

* try_turn(held in A) ($18E4): walled off, a held stick keeps her going;
* released, she stops at the middle of the tile.
try_turn
	sta	PAC_HELD
	ldx	next_step+8
	jsr	wall_ahead
	bne	:walled
	lda	PAC_HELD
	jmp	adopt
:walled	lda	PAC_HELD
	beq	:rel
	ldx	step+8
	jsr	wall_ahead
	beq	:step
	jsr	centered
	beq	:step
	rts
:step	jmp	pac_step
:rel	jsr	centered
	beq	:adopt
	rts
:adopt	lda	#1
	jmp	adopt

* want(dir in A): the stick picks the wanted direction.
want
	sta	pac_wanted_dir
	jsr	dir_step
	stx	next_step+8
	lda	#1
	jmp	try_turn

* face(dir in A): in the tunnel left and right turn her at once.
face
	sta	dir+4
	jsr	dir_step
	stx	step+8
	jmp	pac_step

* demo_move ($1A1C): the steering task drives her tile by tile.
demo_move
	lda	step+8
	bne	:y
	lda	pos+9
	bra	:a
:y	lda	pos+8
:a	and	#$07
	cmp	#4
	bne	:move
	lda	#4
	jsr	tunnel_wrap
	bne	:nt
	lda	#TASK_DEMO_STEER
	ldx	#0
	jsr	queue_task
:nt	ldx	mid_tile+8
	ldy	next_step+8
	jsr	coord_add
	stx	mid_tile+8
	ldx	next_step+8
	stx	step+8
	lda	pac_wanted_dir
	sta	dir+4
:move	ldx	pos+8
	ldy	step+8
	jsr	coord_add
	jmp	arrive

* steer(tunnel in A, player2 in X): the demo moves her by itself; in
* play the stick does (active low: 1 up, 2 left, 4 right, 8 down).
steer
	sta	PAC_TUN
	txa
	sta	PAC_P2
	lda	PAC_TUN
	beq	:t
	lda	#1
	sta	pac_entering_tunnel
:t	lda	game_mode
	cmp	#1
	beq	:demo
	lda	level_state
	cmp	#16
	bcc	:stick
:demo	jmp	demo_move
:stick	lda	PAC_P2
	beq	:in0
	jsr	read_in1
	bra	:got
:in0	jsr	read_in0
:got	sta	PAC_IN
	lda	PAC_TUN
	beq	:maze
	lda	PAC_IN
	and	#$02
	bne	:tr
	lda	#DIR_LEFT
	jmp	face
:tr	lda	PAC_IN
	and	#$04
	bne	:ts
	lda	#DIR_RIGHT
	jmp	face
:ts	jmp	pac_step
:maze	lda	PAC_IN
	and	#$02
	bne	:m1
	lda	#DIR_LEFT
	jmp	want
:m1	lda	PAC_IN
	and	#$04
	bne	:m2
	lda	#DIR_RIGHT
	jmp	want
:m2	lda	PAC_IN
	and	#$01
	bne	:m3
	lda	#DIR_UP
	jmp	want
:m3	lda	PAC_IN
	and	#$08
	bne	:m4
	lda	#DIR_DOWN
	jmp	want
:m4	ldx	step+8
	stx	next_step+8
	lda	#0
	jmp	try_turn

* move_pac ($1806): she pauses after eating, otherwise moves when her
* speed pattern says so.
move_pac
	lda	pac_move_delay
	cmp	#NOT_EATING
	beq	:go
	dec	pac_move_delay
	rts
:go	ldx	#pac_speed
	lda	power_pill_active
	beq	:n
	ldx	#pac_speed+4
:n	jsr	speed_tick
	cmp	#0
	bne	:mv
	rts
:mv	lda	dots_eaten
	sta	pills_since_pac_move
	lda	tile+9
	cmp	#$21
	bcc	:tun
	cmp	#$3B
	bcs	:tun
	lda	#0
	bra	:t
:tun	lda	#1
:t	ldx	#0
	pha
	lda	player_number
	and	dip_cocktail
	beq	:p
	ldx	#1
:p	pla
	jmp	steer

* clear_actor_positions ($2675), task $1E.
clear_actor_positions
	ldx	#0
	stx	fruit_pos
	lda	#0
	ldx	#pos
	ldy	#10
	jmp	fillb

* pac_death ($1291): states 1-4 wait, 5-15 spin, each until the counter
* reaches its frame; 16 takes a life and moves the level on.
* T8 count, T10 state-5, T11 code, T12 until.
pac_death
	lda	pac_death_anim
	bne	:go
	rts
:go	cmp	#17
	bcc	:ok
	rts
:ok	sta	PAC_ST
	rep	#$20
	lda	death_counter_lo
	inc
	sta	T8
	sep	#$20
	lda	PAC_ST
	cmp	#5
	bcs	:spin
	ldx	T8
	stx	death_counter_lo
	cpx	#$0078
	bne	:r
	lda	#5
	sta	pac_death_anim
:r	rts
:spin	cmp	#16
	bne	:mid
	lda	#$3F
	sta	sprite+10
	ldx	T8
	stx	death_counter_lo
	cpx	#$01B8
	bne	:r
	dec	lives_real
	dec	lives_displayed
	jsr	clear_actor_positions
	inc	level_state
	rts
:mid	cmp	#5
	bne	:s6
	ldx	#0
	stx	pos
	stx	pos+2
	stx	pos+4
	stx	pos+6
	bra	:code
:s6	cmp	#6
	bne	:s15
	lda	EFFECT3
	ora	#$10
	sta	EFFECT3
	bra	:code
:s15	cmp	#15
	bne	:code
	stz	EFFECT3
:code	lda	PAC_ST
	sec
	sbc	#5
	sta	T10
	clc
	adc	#$34
	sta	T11
	lda	PAC_ST
	cmp	#15
	bne	:calc
	ldx	#$0159
	stx	T12
	bra	:ck
:calc	lda	T10
	rep	#$20
	and	#$00FF
	sta	T12
	asl
	asl
	asl
	asl
	sec
	sbc	T12
	clc
	adc	#$00B4
	sta	T12
	sep	#$20
:ck	lda	player_number
	and	dip_cocktail
	beq	:nc
	lda	T11
	ora	#$C0
	sta	T11
:nc	lda	T11
	sta	sprite+10
	ldx	T8
	stx	death_counter_lo
	cpx	T12
	bne	:r2
	inc	pac_death_anim
:r2	rts
