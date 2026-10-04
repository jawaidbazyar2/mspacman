*
* conly.s: one frame, the vertical blank and then the main task list.
* Lowered from conly.c.
*

c_only_frame
	lda	HB_STARTED
	beq	:start
	jsr	read_latch0
	beq	:start
	lda	HB_INT_ENABLED
	beq	:start
	jsr	vblank
	lda	HB_RESTART
	beq	:start
	stz	HB_RESTART
	jmp	game_start
:start	lda	HB_STARTED
	bne	:tasks
	jsr	game_start
:tasks	jsr	sched_tasks
	cpx	#0
	bne	:done
	lda	#1
	sta	HB_STOP
:done	rts
