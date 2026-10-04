*
* mode.c: the game modes and, within play, the level state.
*

IRQ_ENABLE	equ	$5001
FLIP_SCREEN	equ	$5003
PILLS_PER_MAZE	equ	$94B5	; per-maze table of each maze's pill count
LAST_DIFFICULTY	equ	$14
PLAYER_BLOCK_LEN	equ	46	; difficulty_ptr_lo.., and level_data_copy
WAITING_LIVES	equ	level_data_copy+10	; the waiting player's lives_real

* flip_for_player: cocktail player 2 flips the screen.
flip_for_player
	lda	player_number
	and	dip_cocktail
	sta	FLIP_SCREEN
	rts

* wait_level_state(units in A): a timed level-state advance.
wait_level_state
	ora	#$40
	ldx	#0		; TT_LEVEL_STATE
	ldy	#0
	jmp	queue_timed

* swap_players ($0AA6): exchange the two players' level records.
swap_players
	ldx	#0
:l	lda	difficulty_ptr_lo,x
	sta	T0
	lda	level_data_copy,x
	sta	difficulty_ptr_lo,x
	lda	T0
	sta	level_data_copy,x
	inx
	cpx	#PLAYER_BLOCK_LEN
	bcc	:l
	rts

* new_game ($0879), state 0: both players get the starting record.
new_game
	lda	#0
	ldx	#player_number
	ldy	#11
	jsr	fillb
	jsr	reset_pills
	ldx	dip_difficulty_ptr_lo
	stx	difficulty_ptr_lo
	ldx	#difficulty_ptr_lo
	ldy	#level_data_copy
	lda	#PLAYER_BLOCK_LEN
	jsr	copyb
	jmp	advance_level_state

* opening ($0899), state 1: "MS PAC-MAN" over the maze; the demo skips.
opening
	lda	game_mode
	cmp	#1
	bne	:go
	lda	#9
	sta	level_state
	rts
:go	QT	TASK_CLEAR_ACTORS;0
	QT	TASK_TEXT;$83
	QT	TASK_PLACE_ACTORS;0
	QT	TASK_HOUSE_TIMER;0
	QT	TASK_DIFFICULTY;0
	QT	TASK_LIVES_ROW;0
	lda	#$14
	jsr	wait_level_state
	lda	#$54		; TIMER(1, $14)
	ldx	#6		; TT_CLEAR_READY
	ldy	#0
	jsr	queue_timed
	jsr	flip_for_player
	jmp	advance_level_state

* playing ($08CD), state 3: a frame until the board is clear. The
* rack-test switch (IN0 bit 4 low) clears it at once.
playing
	jsr	read_in0
	and	#$10
	bne	:norm
	lda	#14
	sta	level_state
	QT	TASK_ERASE_PILLS;0
	rts
:norm	ldx	#PILLS_PER_MAZE
	jsr	maze_word
	lda	|$0000,x
	cmp	dots_eaten
	bne	:play
	lda	#12
	sta	level_state
	rts
:play	jmp	play_frame

* life_lost ($090D), state 4: with two players and the other still in,
* his name and GAME OVER first. T8 text.
life_lost
	lda	#1
	sta	died_this_level
	jsr	pill_bitmap_task
	inc	level_state
	lda	lives_real
	bne	:skip
	lda	num_players
	beq	:skip
	lda	WAITING_LIVES
	beq	:skip
	lda	player_number
	clc
	adc	#3
	sta	T8
	stz	T9
	lda	#TASK_TEXT
	ldx	T8
	jsr	queue_task
	QT	TASK_TEXT;5
	lda	#$14
	jmp	wait_level_state
:skip	inc	level_state
	rts

* next_turn ($0940), state 6: the other player, the next life, or
* game over.
next_turn
	lda	num_players
	beq	:one
	lda	WAITING_LIVES
	beq	:one
	jsr	swap_players
	lda	player_number
	eor	#1
	sta	player_number
	lda	#9
	sta	level_state
	rts
:one	lda	lives_real
	beq	:over
	lda	#9
	sta	level_state
	rts
:over	jsr	show_credits
	QT	TASK_TEXT;5
	lda	#$14
	jsr	wait_level_state
	inc	level_state
	rts

* game_over ($0972), state 8: back to attract.
game_over
	stz	game_mode_sub1
	stz	level_state
	stz	num_players
	stz	player_number
	stz	FLIP_SCREEN
	lda	#1
	sta	game_mode
	rts

* get_ready ($0988), states 9 and 35: the board and READY; the demo
* shows GAME OVER and the credits too.
get_ready
	QT	TASK_CLEAR_SCREEN;1
	QT	TASK_MAZE_COLORS;1
	QT	TASK_DRAW_MAZE;0
	QT	TASK_CLEAR_ACTORS;0
	QT	TASK_ERASE_PILLS;0
	QT	TASK_DRAW_PILLS;0
	QT	TASK_PLACE_ACTORS;0
	QT	TASK_HOUSE_TIMER;0
	QT	TASK_DIFFICULTY;0
	QT	TASK_LIVES_ROW;0
	QT	TASK_TEXT;6
	lda	game_mode
	cmp	#3
	beq	:w
	QT	TASK_TEXT;5
	QT	TASK_CREDITS;0
:w	lda	#$14
	jsr	wait_level_state
	lda	game_mode
	cmp	#1
	beq	:f
	lda	#$54		; TIMER(1, $14)
	ldx	#6		; TT_CLEAR_READY
	ldy	#0
	jsr	queue_timed
:f	jsr	flip_for_player
	jmp	advance_level_state

* board_clear ($09D8), state 12: pause.
board_clear
	lda	#$14
	jsr	wait_level_state
	inc	level_state
	stz	EFFECT2
	stz	EFFECT3
	rts

* flash_maze(color in A) ($09EA), states 14-28. T8 color.
flash_maze
	sta	T8
	stz	T9
	lda	#TASK_MAZE_COLORS
	ldx	T8
	jsr	queue_task
	lda	#2
	jsr	wait_level_state
	ldx	#0
	stx	pos
	stx	pos+2
	stx	pos+4
	stx	pos+6
	inc	level_state
	rts

* clear_board ($0A0E), state 30.
clear_board
	QT	TASK_CLEAR_SCREEN;1
	QT	TASK_CLEAR_COLORS;0
	QT	TASK_CLEAR_ACTORS;0
	QT	TASK_ERASE_PILLS;0
	QT	TASK_PLACE_ACTORS;1
	QT	TASK_HOUSE_TIMER;1
	QT	TASK_DIFFICULTY;$13
	lda	#3
	jsr	wait_level_state
	inc	level_state
	rts

* intermission ($0A2C), state 32: act 1 after board 2, act 2 after 5,
* act 3 after 9, 13, and 17. Other boards skip state 33.
intermission
	stz	EFFECT2
	stz	EFFECT3
	lda	level_number
	cmp	#1
	beq	:a1
	cmp	#4
	beq	:a2
	cmp	#8
	beq	:a3
	cmp	#12
	beq	:a3
	cmp	#16
	beq	:a3
	lda	level_state
	clc
	adc	#2
	sta	level_state
	stz	wave
	stz	wave+wave_SIZE
	rts
:a1	lda	#1
	jmp	run_act
:a2	lda	#2
	jmp	run_act
:a3	lda	#3
	jmp	run_act

* next_board ($0A7C), state 34: the difficulty pointer stops at the
* last row. T8 pointer.
next_board
	ldx	difficulty_ptr_lo
	stx	T8
	stz	wave
	stz	wave+wave_SIZE
	lda	#0
	ldx	#fruit1_released
	ldy	#7
	jsr	fillb
	jsr	reset_pills
	inc	level_state
	inc	level_number
	ldx	T8
	lda	|$0000,x
	cmp	#LAST_DIFFICULTY
	beq	:r
	inx
	stx	difficulty_ptr_lo
:r	rts

* level_step ($06BE): one step of the level state. States with no
* routine wait for a timed task.
level_step
	lda	level_state
	cmp	#38
	bcs	:r
	asl
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	jmp	(:tab,x)
:r	rts
:go	lda	#LEVEL_PLAYING
	sta	level_state
	rts
:fl	lda	#2
	jmp	flash_maze
:fb	lda	#0
	jmp	flash_maze
:tab	da	new_game,opening,:r,playing,life_lost,:r,next_turn,:r
	da	game_over,get_ready,:r,:go,board_clear,:r,:fl,:r
	da	:fb,:r,:fl,:r,:fb,:r,:fl,:r
	da	:fb,:r,:fl,:r,:fb,:r,clear_board,:r
	da	intermission,:r,next_board,get_ready,:r,:go

* power_on ($03D4): the start-up tasks, once.
power_on
	lda	game_mode_sub0
	beq	:go
	rts
:go	QT	TASK_CLEAR_SCREEN;0
	QT	TASK_CLEAR_COLORS;0
	QT	TASK_MAZE_COLORS;0
	QT	TASK_DIP_SWITCHES;0
	QT	TASK_DRAW_SCORES;0
	QT	TASK_PLACE_ACTORS;0
	QT	TASK_CLEAR_SPRITES;0
	QT	TASK_DEMO_MODE;0
	inc	game_mode_sub0
	lda	#1
	sta	IRQ_ENABLE
	rts

* attract ($03FE): until a credit moves the game to press-start.
attract
	jsr	show_credits
	lda	credits
	bne	:start
	jmp	attract_step
:start	stz	level_state
	stz	game_mode_sub1
	inc	game_mode
	rts

* game_mode_step ($03C8).
game_mode_step
	lda	game_mode
	bne	:n0
	jmp	power_on
:n0	cmp	#1
	bne	:n1
	jmp	attract
:n1	cmp	#2
	bne	:n2
	jmp	press_start
:n2	cmp	#3
	bne	:r
	jmp	level_step
:r	rts
