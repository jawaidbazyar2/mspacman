*
* cutscene.c: cutscenes and the attract-mode walks. Six actors each
* follow a small script; actor 5 uses the fruit slot.
*

SCRIPTS	equ	$81F0	; 12-byte sets of six script pointers

CS_A	equ	$54	; word: the actor
CS_A2	equ	$56	; word: 2 * the actor
CS_S	equ	$58	; word: its script pointer
CS_ADV	equ	$5A	; the script advance
CS_SET	equ	$5B	; run_cutscene's script set
CS_POS	equ	$5C	; word: the actor's Coord
CS_ANIM	equ	$5E	; word: cmd_move's animation table
CS_FR	equ	$60	; cmd_move's frame
CS_ACT	equ	$61	; run_act's act

* hide_pac_at_edge: at tile column $3D Ms. Pac-Man goes black.
hide_pac_at_edge
	lda	tile+9
	cmp	#$3D
	bne	:r
	stz	sprite+11
:r	rts

* cutscene2_sprites ($162D): Pac-Man only; never past the first test.
cutscene2_sprites
	lda	cutscene2_state
	bne	:go
	rts
:go	jsr	hide_pac_at_edge
	lda	cutscene2_state
	cmp	#$0A
	bcs	:c
	rts
:c	cmp	#$0C
	lda	#$32
	bcc	:s
	lda	#$33
:s	sta	sprite+2
	lda	#$1D
	sta	sprite+3
	rts

* cutscene1_positions ($039D): the big Pac-Man's four quarters around
* Ms. Pac-Man's position. T1 x.
cutscene1_positions
	lda	cutscene1_state
	cmp	#5
	bcs	:go
	rts
:go	lda	pos+9
	clc
	adc	#8
	sta	T1
	lda	pos+8
	sta	pos+6
	sta	fruit_pos_y
	sec
	sbc	#$10
	sta	pos+2
	sta	pos+4
	lda	T1
	sta	pos+3
	sta	pos+7
	sec
	sbc	#$10
	sta	pos+5
	sta	fruit_pos_x
	rts

* cutscene3_sprites ($1652).
cutscene3_sprites
	lda	cutscene3_state
	bne	:go
	rts
:go	jsr	hide_pac_at_edge
	lda	ghost_anim_phase
	clc
	adc	#8
	sta	sprite+2
	lda	cutscene3_state
	cmp	#3
	bcs	:c
	rts
:c	lda	pos+1
	and	#$08
	lsr
	lsr
	lsr
	clc
	adc	#$0A
	sta	SPR_FRUIT_CODE
	inc
	inc
	sta	sprite+2
	lda	#$1E
	sta	SPR_FRUIT_COLOR
	rts

* cutscene1_sprites ($15E6): the frame follows his x; her sprite hides.
cutscene1_sprites
	lda	cutscene1_state
	cmp	#5
	bcs	:go
	rts
:go	lda	pos+9
	and	#$0F
	cmp	#$0C
	bcs	:t18
	cmp	#8
	bcs	:t14
	cmp	#4
	bcs	:t10
:t14	lda	#$14
	bra	:t
:t18	lda	#$18
	bra	:t
:t10	lda	#$10
:t	sta	sprite+4
	inc
	sta	sprite+6
	inc
	sta	sprite+8
	inc
	sta	SPR_FRUIT_CODE
	lda	#$3F
	sta	sprite+10
	lda	#$16
	sta	sprite+5
	sta	sprite+7
	sta	sprite+9
	sta	SPR_FRUIT_COLOR
	rts

* actor_pos -> X: the actor's Coord; actor 5 is the fruit.
actor_pos
	lda	CS_A
	cmp	#5
	bne	:p
	ldx	#fruit_pos
	rts
:p	rep	#$20
	lda	CS_A2
	clc
	adc	#pos
	tax
	sep	#$20
	rts

* carry_pixels(accumulator at X, speed in A) -> A ($3556): whole pixels
* to move; the remainder keeps the sign of the sum. T0 sum, T1 whole.
carry_pixels
	clc
	adc	|$0000,x
	sta	T0
	bmi	:neg
	lsr
	lsr
	lsr
	lsr
	sta	T1
	lda	T0
	and	#$0F
	sta	|$0000,x
	lda	T1
	rts
:neg	lsr
	lsr
	lsr
	lsr
	ora	#$F0
	inc
	sta	T1
	lda	T0
	ora	#$F0
	sta	|$0000,x
	lda	T1
	rts

* cmd_move -> A ($34E0): move by (dx, dy)/16 and show the next frame;
* 4 when the count runs out, else 0. T2-T3 scratch.
cmd_move
	jsr	actor_pos
	stx	CS_POS
	ldx	CS_A2
	rep	#$20
	lda	cutscene_anim,x
	sta	CS_ANIM
	sep	#$20
	ldx	CS_A
	lda	cutscene_frame,x
	inc
	sta	CS_FR
	rep	#$20
	lda	CS_A2
	clc
	adc	#cutscene_frac_x
	tax
	sep	#$20
	ldy	CS_S
	lda	|$0001,y
	jsr	carry_pixels
	ldy	CS_POS
	clc
	adc	|$0001,y
	sta	|$0001,y
	rep	#$20
	lda	CS_A2
	clc
	adc	#cutscene_frac_y
	tax
	sep	#$20
	ldy	CS_S
	lda	|$0002,y
	jsr	carry_pixels
	ldy	CS_POS
	clc
	adc	|$0000,y
	sta	|$0000,y
* Each table entry shows for two frames; $FF loops to the start.
	lda	CS_FR
	and	#$80
	sta	T2
	lda	CS_FR
	lsr
	ora	T2
	rep	#$20
	and	#$00FF
	clc
	adc	CS_ANIM
	tax
	sep	#$20
	lda	|$0000,x
	cmp	#$FF
	bne	:ok
	stz	CS_FR
	ldx	CS_ANIM
	lda	|$0000,x
:ok	sta	T3
	ldx	CS_A
	lda	CS_FR
	sta	cutscene_frame,x
	lda	player_number
	and	dip_cocktail
	beq	:nc
	lda	T3
	eor	#$C0
	sta	T3
:nc	ldx	CS_A2
	lda	T3
	sta	cutscene_sprite,x
	ldy	CS_S
	lda	|$0003,y
	sta	cutscene_sprite+1,x
	ldx	CS_A
	dec	cutscene_count,x
	bne	:zero
	lda	#4
	rts
:zero	lda	#0
	rts

* cmd_end -> A ($35BE): this actor is done; 1 when all six are, after
* moving the game on.
cmd_end
	ldx	CS_A
	lda	#1
	sta	cutscene_done,x
	ldx	#0
:l	lda	cutscene_done,x
	beq	:no
	inx
	cpx	#6
	bcc	:l
	lda	game_mode_sub1
	bne	:att
	lda	#$45		; TIMER(1, 5)
	ldx	#0		; TT_LEVEL_STATE
	ldy	#0
	jsr	queue_timed
	inc	level_state
	lda	#1
	rts
:att	stz	intermission_flag
	jsr	advance_attract_state
	lda	#1
	rts
:no	lda	#0
	rts

* load_scripts(set in A) ($3611). T8 set.
load_scripts
	sta	T8
	lda	game_mode_sub1
	bne	:c
	lda	#2
	sta	wave
	sta	wave+wave_SIZE
:c	lda	T8
	rep	#$20
	and	#$00FF
	clc
	adc	#SCRIPTS
	tax
	sep	#$20
	ldy	#cutscene_script
	lda	#12
	jsr	copyb
	lda	#1
	sta	intermission_flag
	sta	ghosts_killed_pending
	stz	pac_death_anim
	lda	#0
	ldx	#cutscene_done-1
	ldy	#$14
	jmp	fillb

* run_cutscene(set in A) ($349C): each actor runs one command, actor 5
* first. $F0 and unknown bytes move; $F1 place; $F2 count; $F3 anim;
* $F5 sound; $F6 wait; $F7 and $F8 erase; $FF end.
run_cutscene
	sta	CS_SET
	lda	intermission_flag
	bne	:go
	lda	CS_SET
	jsr	load_scripts
:go	lda	#6
	sta	CS_A
	stz	CS_A+1
:loop	lda	CS_A
	bne	:next
	rts
:next	dec	CS_A
	lda	CS_A
	asl
	sta	CS_A2
	stz	CS_A2+1
	ldx	CS_A2
	rep	#$20
	lda	cutscene_script,x
	sta	CS_S
	sep	#$20
	stz	CS_ADV
	ldx	CS_S
	lda	|$0000,x
	cmp	#$FF
	bne	:n1
	jsr	cmd_end
	cmp	#0
	bne	:done
	jmp	:store
:done	rts
:n1	cmp	#$F1
	bne	:n2
	jsr	actor_pos
	ldy	CS_S
	lda	|$0001,y
	sta	|$0001,x
	lda	|$0002,y
	sta	|$0000,x
	lda	#3
	sta	CS_ADV
	jmp	:store
:n2	cmp	#$F2
	bne	:n3
	ldy	CS_S
	lda	|$0001,y
	ldx	CS_A
	sta	cutscene_count,x
	lda	#2
	sta	CS_ADV
	jmp	:store
:n3	cmp	#$F3
	bne	:n5
	ldx	CS_A
	stz	cutscene_frame,x
	ldy	CS_S
	ldx	CS_A2
	lda	|$0001,y
	sta	cutscene_anim,x
	lda	|$0002,y
	sta	cutscene_anim+1,x
	lda	#3
	sta	CS_ADV
	jmp	:store
:n5	cmp	#$F5
	bne	:n6
	ldy	CS_S
	lda	|$0001,y
	sta	EFFECT3
	lda	#2
	sta	CS_ADV
	jmp	:store
:n6	cmp	#$F6
	bne	:n7
	ldx	CS_A
	dec	cutscene_count,x
	bne	:store
	lda	#1
	sta	CS_ADV
	bra	:store
:n7	cmp	#$F7
	bne	:n8
	lda	#TASK_TEXT
	ldx	#$30
	jsr	queue_task
	lda	#1
	sta	CS_ADV
	bra	:store
:n8	cmp	#$F8
	bne	:mv
	lda	#TILE_BLANK
	sta	$42AC
	lda	#1
	sta	CS_ADV
	bra	:store
:mv	jsr	cmd_move
	sta	CS_ADV
:store	ldx	CS_A2
	rep	#$20
	lda	CS_ADV
	and	#$00FF
	clc
	adc	CS_S
	sta	cutscene_script,x
	sep	#$20
	jmp	:loop

* run_act(act in A) ($3435...): intermissions 1-3, the title and act
* number, then the scripts.
run_act
	sta	CS_ACT
	lda	intermission_flag
	cmp	#1
	beq	:run
	lda	CS_ACT
	cmp	#2
	beq	:t2
	bcs	:t3
	ldx	#$32
	bra	:t
:t2	ldx	#$17
	bra	:t
:t3	ldx	#$15
:t	lda	#TASK_TEXT
	jsr	queue_task
	lda	CS_ACT
	sta	$42AC
	lda	#$16
	sta	$46AC
:run	lda	CS_ACT
	dec
	sta	T0
	asl
	clc
	adc	T0
	asl
	asl
	jmp	run_cutscene
