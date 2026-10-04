*
* start.c: game mode 2, waiting for a start button, then the intro.
*

* bcd_dec(A) -> A: BCD minus one (add $99, daa).
bcd_dec
	sed
	clc
	adc	#$99
	cld
	rts

* draw_prompt: step 0, the attract screen's text.
draw_prompt
	jsr	show_credits
	QT	TASK_CLEAR_SCREEN;$01
	QT	TASK_MAZE_COLORS;$00
	QT	TASK_TEXT;$07
	QT	TASK_TEXT;$0B
	QT	TASK_CLEAR_SPRITES;$00
	inc	game_mode_sub2
	lda	#1
	sta	start_button_wait
	lda	dip_bonus_life
	cmp	#$FF
	bne	:bonus
	rts
:bonus	QT	TASK_TEXT;$0A
	QT	TASK_BONUS_DIGITS;$00
	rts

* begin_game: charge the credits (unless free play), start the tune.
* T8 credits.
begin_game
	lda	dip_coins_per_credit
	beq	:free
	lda	credits
	sta	T8
	lda	num_players
	beq	:one
	lda	T8
	jsr	bcd_dec
	sta	T8
:one	lda	T8
	jsr	bcd_dec
	sta	credits
	jsr	show_credits
:free	inc	game_mode_sub2
	stz	start_button_wait
	lda	#1
	sta	wave
	sta	wave+wave_SIZE
	rts

* wait_start: step 1. One credit allows player 1 only. T8 IN1.
wait_start
	jsr	show_credits
	lda	credits
	cmp	#1
	bne	:two
	lda	#$08
	bra	:m
:two	lda	#$09
:m	jsr	draw_message
	jsr	read_in1
	sta	T8
	lda	credits
	cmp	#1
	beq	:p1
	lda	T8
	and	#$40
	bne	:p1
	lda	#1
	sta	num_players
	jmp	begin_game
:p1	lda	T8
	and	#$20
	bne	:r
	stz	num_players
	jmp	begin_game
:r	rts

* set_up_game: step 2, the playfield and lives; wait for the tune.
set_up_game
	QT	TASK_CLEAR_SCREEN;$01
	QT	TASK_MAZE_COLORS;$01
	QT	TASK_DRAW_MAZE;$00
	QT	TASK_RESET_PILLS;$00
	QT	TASK_DRAW_PILLS;$00
	QT	TASK_TEXT;$03
	QT	TASK_TEXT;$06
	QT	TASK_DRAW_SCORES;$00
	QT	TASK_FRUIT_ROW;$00
	stz	level_number
	lda	dip_lives
	sta	lives_real
	sta	lives_displayed
	QT	TASK_LIVES_ROW;$00
	lda	#$57		; TIMER(1, $17)
	ldx	#1		; TT_PLAY_STATE
	ldy	#0
	jsr	queue_timed
	cmp	#0
	beq	:r
	inc	game_mode_sub2
:r	rts

* start_play: step 4, one life fewer shown, and play.
start_play
	dec	lives_displayed
	jsr	draw_lives_row
	stz	game_mode_sub2
	stz	game_mode_sub1
	stz	level_state
	inc	game_mode
	rts

* press_start ($05E5).
press_start
	lda	game_mode_sub2
	bne	:n0
	jmp	draw_prompt
:n0	cmp	#1
	bne	:n1
	jmp	wait_start
:n1	cmp	#2
	bne	:n2
	jmp	set_up_game
:n2	cmp	#4
	bne	:r
	jmp	start_play
:r	rts
