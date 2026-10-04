*
* sched.s: the main task list ($238D) and the start-up code ($234B).
* Lowered from sched.c.
*

SC_HL	equ	$68	; word: the slot being taken
SC_T	equ	$6A	; the task byte
SC_P	equ	$6B	; its parameter
SC_G	equ	$6C	; word: the guard count

* $234B. Kick the watchdog, then clear the latches, the work RAM the
* boot clears, the voice registers, the screen, and the task list.
* Interrupts go on last.
game_start
	stz	WATCHDOG
	lda	#0
	ldx	#$5000
	ldy	#8
	jsr	iofill
	lda	#0
	ldx	#sprite
	ldy	#$BE
	jsr	fillb
	lda	#0
	ldx	#$5040
	ldy	#$40
	jsr	iofill
	stz	WATCHDOG
	jsr	clear_colors
	stz	WATCHDOG
	lda	#0
	jsr	clear_screen
	stz	WATCHDOG
	ldx	#MAIN_TASK_LIST
	stx	task_list_tail_ptr
	stx	task_list_head_ptr
	lda	#$FF
	ldx	#main_task_list
	ldy	#main_task_list_LEN
	jsr	fillb
	lda	#1
	sta	|$5000
	sta	HB_INT_ENABLED
	sta	HB_STARTED
	rts

* Run queued tasks until the list is empty. X = 0, or $FFFF after a
* replay failure: a byte that is not a task, or a list that never empties.
sched_tasks
	ldx	#0
	stx	SC_G
:next	ldx	task_list_head_ptr
	lda	|$0000,x
	bpl	:take
	ldx	#0
	rts
:take	sta	SC_T
	stx	SC_HL
	lda	#$FF
	sta	|$0000,x
	inc	SC_HL
	ldx	SC_HL
	lda	|$0000,x
	sta	SC_P
	lda	#$FF
	sta	|$0000,x
	inc	SC_HL
	bne	:hl
	lda	#$C0
	sta	SC_HL
:hl	ldx	SC_HL
	stx	task_list_head_ptr
	lda	SC_T
	cmp	#32
	bcs	:bad
	asl
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	SC_P
	jsr	(:tab,x)
	ldx	SC_G
	inx
	stx	SC_G
	bne	:next
	lda	#FAIL_NOT_EMPTY
	ldx	#0
	db	$42,$02
	ldx	#$FFFF
	rts
:bad	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	#FAIL_BAD_TASK
	db	$42,$02
	ldx	#$FFFF
	rts

* $23A8. A = the parameter; tasks that take none ignore it.
:tab	da	clear_screen
	da	maze_colors
	da	draw_maze
	da	draw_pills
	da	place_actors
	da	house_timer
	da	clear_colors
	da	demo_mode
	da	aim_red
	da	aim_pink
	da	aim_blue
	da	aim_orange
	da	flee_red
	da	flee_pink
	da	flee_blue
	da	flee_orange
	da	load_difficulty
	da	clear_actors
	da	reset_pills
	da	erase_pills
	da	read_dip_switches
	da	pill_bitmap_task
	da	task_next_level_state
	da	demo_steer
	da	draw_scores
	da	add_score
	da	draw_lives_row
	da	draw_fruit_row
	da	text_task
	da	show_credits
	da	clear_actor_positions
	da	draw_bonus_digits
