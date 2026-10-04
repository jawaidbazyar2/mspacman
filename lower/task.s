*
* task.c: queueing main tasks. sched.s runs them.
*

* queue_task(task in A, param in X) ($0042): append to the main task
* list. The tail advances two bytes; only the second step wraps, from
* $4D00 back to $4CC0.
queue_task
	sta	T0
	stx	T2
	ldx	task_list_tail_ptr
	stx	T4
	sta	|$0000,x
	lda	T4
	inc
	sta	T4
	ldx	T4
	lda	T2
	sta	|$0000,x
	lda	T4
	inc
	bne	:ok
	lda	#<MAIN_TASK_LIST
:ok	sta	task_list_tail_ptr
	lda	T5
	sta	task_list_tail_ptr_hi
	rts

* task_next_level_state ($23E8), task $16: level_state++.
task_next_level_state
	inc	level_state
	rts
