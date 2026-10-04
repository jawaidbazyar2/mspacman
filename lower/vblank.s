*
* vblank.s: the vertical blank interrupt ($008D). Lowered from vblank.c.
*

VOICE_FREQS	equ	$5050
VOICE1_SELECT	equ	$5045
VOICE2_SELECT	equ	$504A
VOICE3_SELECT	equ	$504F
SPRITE_RAM	equ	$4FF0
SPRITE_XY	equ	$5060

* A playing song (X = wave channel) supplies the voice's wave select.
* Otherwise the effect (Y) does.
wave_select
	lda	|SN_NUM,x
	beq	:e
	lda	|SN_SEL,x
	rts
:e	lda	|SN_SHAPE,y
	rts

* Trade sprite_out and sprite_pos_out slots X/2 and Y/2.
swap_slots
	rep	#$20
	lda	sprite_out,x
	pha
	lda	sprite_out,y
	sta	sprite_out,x
	pla
	sta	sprite_out,y
	lda	sprite_pos_out,x
	pha
	lda	sprite_pos_out,y
	sta	sprite_pos_out,x
	pla
	sta	sprite_pos_out,y
	sep	#$20
	rts

* Copy the sprites out, the flips rotated into bits 1-0. The eaten ghost
* trades places with slot 2. While a power pill runs, Ms. Pac trades
* places with slot 1.
send_sprites
	ldx	#sprite+2
	ldy	#sprite_out+2
	lda	#14
	jsr	copyb
	ldx	#sprite_pos
	ldy	#sprite_pos_out
	lda	#14
	jsr	copyb
	ldx	#2
:rot	lda	sprite_out,x
	asl
	adc	#0
	asl
	adc	#0
	sta	sprite_out,x
	inx
	inx
	cpx	#14
	bcc	:rot
	lda	killed_ghost_anim
	cmp	#1
	bne	:pill
	lda	ghosts_killed_pending
	asl
	rep	#$20
	and	#$00FF
	tay
	sep	#$20
	ldx	#4
	jsr	swap_slots
:pill	lda	power_pill_active
	beq	:out
	ldx	#2
	ldy	#10
	jsr	swap_slots
:out	ldx	#sprite_out+2
	ldy	#SPRITE_RAM+2
	lda	#12
	jsr	copyb
	ldx	#sprite_pos_out+2
	ldy	#SPRITE_XY+2
	lda	#12
	jmp	iocopy

vblank
	stz	WATCHDOG
	stz	|$5000
	stz	HB_INT_ENABLED
	ldx	#CH1_FREQ0
	ldy	#VOICE_FREQS
	lda	#16
	jsr	iocopy
	ldx	#wave
	ldy	#effect
	jsr	wave_select
	sta	VOICE1_SELECT
	ldx	#wave+wave_SIZE
	ldy	#effect+effect_SIZE
	jsr	wave_select
	sta	VOICE2_SELECT
	ldx	#wave+wave_SIZE+wave_SIZE
	ldy	#effect+effect_SIZE+effect_SIZE
	jsr	wave_select
	sta	VOICE3_SELECT
	jsr	send_sprites
	jsr	clock_tick
	jsr	timers_run
	jsr	game_mode_step
	lda	game_mode
	beq	:mute
	jsr	cutscene1_positions
	jsr	sprites_upright
	jsr	sprites_cocktail
	jsr	coin_inputs
	jsr	coin_meter
	jsr	hud_blink
* The attract mode is silent.
:mute	lda	game_mode
	cmp	#1
	bne	:snd
	stz	EFFECT2
	stz	EFFECT3
:snd	jsr	sound_effects
	jsr	sound_songs
* The service switch restarts the game.
	lda	game_mode
	beq	:ei
	jsr	read_in1
	and	#$10
	bne	:ei
	lda	#1
	sta	HB_RESTART
	rts
:ei	lda	#1
	sta	|$5000
	sta	HB_INT_ENABLED
	rts
