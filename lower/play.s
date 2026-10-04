*
* play.c: one frame of play.
*

* play_pass ($1017): move everyone once. A dying Ms. Pac-Man or a ghost
* being eaten freezes the rest.
play_pass
	jsr	pac_death
	lda	pac_death_anim
	beq	:a
	rts
:a	jsr	mark_eaten_ghost
	jsr	return_all_eyes
	lda	ghosts_killed_pending
	beq	:b
	jmp	show_eaten_ghost
:b	jsr	tile_collision
	jsr	pixel_collision
	lda	ghosts_killed_pending
	beq	:c
	rts
:c	jsr	move_pac
	jsr	move_ghosts
	lda	level_state
	cmp	#LEVEL_PLAYING
	beq	:d
	rts
:d	jsr	fright_countdown
	jmp	release_by_pills

* play_frame ($08EB): the actors move twice, then the timers, the
* power-pill blink, the siren, and the fruit.
play_frame
	jsr	play_pass
	jsr	play_pass
	jsr	release_idle_ghost
	jsr	move_in_house
	jsr	ghost_anim_tick
	jsr	reversal_timer
	jsr	flash_ghosts
	jsr	color_eyes
	jsr	flash_power_pills
	jsr	siren_update
	jmp	move_fruit
