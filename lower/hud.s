*
* hud.c: the start lamps and the blinking 1UP / 2UP labels.
*

LAMP_P1	equ	$5004	; latch: player-1 start lamp
LAMP_P2	equ	$5005	; latch: player-2 start lamp
CELL_1UP	equ	$43D8	; top row, "1UP" (stored "PU1": right to left)
CELL_2UP	equ	$43C5

HUD_CNT	equ	$26

draw_1up
	ldx	#CELL_1UP
	lda	#$31
	bra	hud_put
draw_2up
	ldx	#CELL_2UP
	lda	#$32
hud_put	pha
	lda	#$50		; 'P'
	sta	|$0000,x
	lda	#$55		; 'U'
	sta	|$0001,x
	pla
	sta	|$0002,x
	rts

* clear_label(cell in X): three blanks.
clear_label
	lda	#TILE_BLANK
	sta	|$0000,x
	sta	|$0001,x
	sta	|$0002,x
	rts

* update_lamps(counter in A): every 16 frames. One credit lights only
* player 1. T0 lamp, T1 player-2 lamp.
update_lamps
	lsr
	lsr
	lsr
	lsr
	sta	T0
	lda	start_button_wait
	eor	#$FF
	ora	T0
	sta	T0
	sta	T1
	lda	credits
	bne	:some
	stz	T0
	stz	T1
	bra	:out
:some	cmp	#1
	bne	:out
	stz	T1
:out	lda	T1
	sta	LAMP_P2
	lda	T0
	sta	LAMP_P1
	rts

* hud_blink ($02FD): run from the vertical blank outside power-on.
hud_blink
	inc	coin_blink_counter
	lda	coin_blink_counter
	sta	HUD_CNT
	and	#$0F
	bne	:labels
	lda	HUD_CNT
	jsr	update_lamps
:labels	lda	game_mode
	cmp	#3
	beq	:blink
	lda	game_mode_sub2
	cmp	#2
	bcs	:blink
	jsr	draw_1up
	jmp	draw_2up
* The current player's label blinks.
:blink	lda	player_number
	bne	:p2
	lda	HUD_CNT
	and	#$10
	bne	:off1
	jsr	draw_1up
	bra	:two
:off1	ldx	#CELL_1UP
	jsr	clear_label
	bra	:two
:p2	lda	HUD_CNT
	and	#$10
	bne	:off2
	jsr	draw_2up
	bra	:two
:off2	ldx	#CELL_2UP
	jsr	clear_label
:two	lda	num_players
	bne	:done
	ldx	#CELL_2UP
	jmp	clear_label
:done	rts
