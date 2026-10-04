*
* clock.c: the frame clock and the 16 timed tasks it counts down.
*

CLOCK_LIMITS	equ	$0219	; carry nibble, then wrap value, per counter

* clock_tick ($01DC): the four clock counters tick with carries;
* clock_limit_changes is 1 plus the carries and wraps this frame.
* X counter, Y 2 * counter, T0 changes, T1-T2 scratch.
clock_tick
	inc	SOUND_COUNTER
	dec	timer_unused_4c85
	lda	#1
	sta	T0
	ldx	#0
	ldy	#0
:loop	inc	clock_hundredths,x
	lda	clock_hundredths,x
	and	#$0F
	cmp	|CLOCK_LIMITS,y
	bne	:end
	inc	T0
	lda	clock_hundredths,x
	clc
	adc	#$10
	and	#$F0
	sta	clock_hundredths,x
	cmp	|CLOCK_LIMITS+1,y
	bne	:end
	inc	T0
	stz	clock_hundredths,x
	inx
	iny
	iny
	cpx	#4
	bcc	:loop
:end	lda	T0
	sta	clock_limit_changes
	lda	rng_unused_4c8b	; x*5+1
	sta	T1
	asl
	asl
	clc
	adc	T1
	inc
	sta	rng_unused_4c8b
	lda	rng_unused_4c8c	; x*13+1
	sta	T1
	asl
	asl
	sta	T2
	asl
	clc
	adc	T2
	clc
	adc	T1
	inc
	sta	rng_unused_4c8c
	rts

* Timed tasks 0-3 and 7-9.
advance_level_state
	inc	level_state
	rts
advance_play_state
	inc	game_mode_sub2
	rts
advance_attract_state
	inc	game_mode_sub1
	rts
advance_eaten_ghost_anim
	inc	killed_ghost_anim
	rts
advance_cutscene1
	inc	cutscene1_state
	rts
advance_cutscene2
	inc	cutscene2_state
	rts
advance_cutscene3
	inc	cutscene3_state
	rts

* Timed task 6 ($0263): erase READY!.
clear_ready
	lda	#TASK_TEXT
	ldx	#$86
	jmp	queue_task

timed_tasks
	da	advance_level_state
	da	advance_play_state
	da	advance_attract_state
	da	advance_eaten_ghost_anim
	da	clear_fruit
	da	clear_fruit_pos
	da	clear_ready
	da	advance_cutscene1
	da	advance_cutscene2
	da	advance_cutscene3

* timers_run ($0221): count down the 16 slots (timer, task, parameter).
* A slot whose unit (timer bits 7-6) is below clock_limit_changes counts
* down; one that reaches 0 is freed and its task runs. Y slot offset.
timers_run
	ldy	#0
:loop	lda	timed_task_list,y
	beq	:next
	sta	T9
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr
	cmp	clock_limit_changes
	bcs	:next
	lda	T9
	dec
	sta	timed_task_list,y
	and	#$3F
	bne	:next
	lda	#0
	sta	timed_task_list,y
	lda	timed_task_list+1,y
	cmp	#10
	bcs	:next
	asl
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	phy
	jsr	(timed_tasks,x)
	ply
:next	iny
	iny
	iny
	cpy	#48
	bcc	:loop
	rts

* queue_timed(timer in A, task in X, param in Y) -> A: put a task in
* the first free slot; 0 when all 16 are taken.
queue_timed
	sta	T0
	txa
	sta	T1
	tya
	sta	T2
	ldx	#0
:loop	lda	timed_task_list,x
	beq	:put
	inx
	inx
	inx
	cpx	#48
	bcc	:loop
	lda	#0
	rts
:put	lda	T0
	sta	timed_task_list,x
	lda	T1
	sta	timed_task_list+1,x
	lda	T2
	sta	timed_task_list+2,x
	lda	#1
	rts
