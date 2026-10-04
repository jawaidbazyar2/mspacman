*
* score.c: scores, the high score, extra lives, credits, DIP switches.
* Scores are three BCD bytes, least significant first, then the
* player's "bonus life awarded" flag.
*

POINTS_TABLE	equ	$2B17	; BCD word per scoring item
BONUS_TABLE	equ	$2728	; bonus-life threshold by DSW bits 5-4
DIFFICULTY_TAB	equ	$272C	; difficulty table pointer by DSW bit 6
CELL_P1_SCORE	equ	$43FC	; rightmost digit of each score
CELL_P2_SCORE	equ	$43E9
CELL_HI_SCORE	equ	$43F2
CELL_LIVES	equ	$401A	; bottom row, first life icon
CELL_CREDIT1	equ	$4033
CELL_CREDIT10	equ	$4034
CELL_BONUS1	equ	$4136
CELL_BONUS10	equ	$4156
TILE_LIFE	equ	$20
TILE_DIGIT0	equ	$30

SC_BL	equ	$28	; draw_score: leading blanks left
SC_CELL	equ	$2A	; draw_score: word, next cell
SC_PTR	equ	$2C	; draw_score: word, the score
ADD_PTR	equ	$2E	; add_score: word, the player's score

* X = the current player's score.
player_score
	ldx	#score_p1_lo
	lda	player_number
	beq	:p1
	ldx	#score_p2_lo
:p1	rts

* draw_score(cell in X, score at Y, blanks in A) ($2ABE): six digits,
* most significant first, leftmost cell on screen first (the top rows
* run right to left in video RAM). The first `blanks` leading zeros
* are blank.
draw_score
	sta	SC_BL
	stx	SC_CELL
	sty	SC_PTR
	ldy	#2
:byte	lda	(SC_PTR),y
	lsr
	lsr
	lsr
	lsr
	jsr	:digit
	lda	(SC_PTR),y
	and	#$0F
	jsr	:digit
	dey
	bpl	:byte
	rts
:digit	cmp	#0
	bne	:nz
	lda	SC_BL
	beq	:zero
	dec	SC_BL
	lda	#TILE_BLANK
	bra	:put
:zero	lda	#0
	bra	:put
:nz	stz	SC_BL
:put	ldx	SC_CELL
	sta	|$0000,x
	dex
	stx	SC_CELL
	rts

* draw_player_score ($2AAF).
draw_player_score
	jsr	player_score
	txy
	ldx	#CELL_P1_SCORE
	lda	player_number
	beq	:p1
	ldx	#CELL_P2_SCORE
:p1	lda	#4
	jmp	draw_score

* draw_lives(lives in A): life icons along the bottom, then blanks up to
* five slots. Six or more lives show none. T0 lives, T1 slot.
draw_lives
	sta	T0
	stz	T1
	ldx	#CELL_LIVES
	lda	T0
	beq	:blanks
	cmp	#6
	bcs	:blanks
:icon	lda	#TILE_LIFE
	jsr	draw_icon
	dex
	dex
	inc	T1
	lda	T1
	cmp	T0
	bcc	:icon
:blanks	lda	T1
	cmp	#5
	bcs	:done
	lda	#TILE_BLANK
	jsr	draw_block
	dex
	dex
	inc	T1
	bra	:blanks
:done	rts

* award_life(score at X) ($2B33): the bonus life, once per player.
award_life
	lda	|$0003,x
	and	#1
	bne	:done
	lda	|$0003,x
	ora	#1
	sta	|$0003,x
	lda	effect
	ora	#$01
	sta	effect
	inc	lives_real
	inc	lives_displayed
	lda	lives_displayed
	jmp	draw_lives
:done	rts

* add_score(item in A) ($2A5A), task $19: score an item, award the bonus
* life, update the high score. The attract mode scores nothing.
add_score
	tay
	lda	game_mode
	cmp	#1
	bne	:go
	rts
:go	tya
	asl
	rep	#$20
	and	#$00FF
	tax
	lda	|POINTS_TABLE,x
	sta	T0
	sep	#$20
	jsr	player_score
	stx	ADD_PTR
	sed
	clc
	lda	|$0000,x
	adc	T0
	sta	|$0000,x
	lda	|$0001,x
	adc	T1
	sta	|$0001,x
	lda	|$0002,x
	adc	#0
	sta	|$0002,x
	cld
* The threshold is in thousands: $10 is 10,000.
	lda	|$0002,x
	asl
	asl
	asl
	asl
	sta	T2
	lda	|$0001,x
	lsr
	lsr
	lsr
	lsr
	ora	T2
	sta	T2
	lda	dip_bonus_life
	dec
	cmp	T2
	bcs	:nolife
	jsr	award_life
:nolife	jsr	draw_player_score
	ldy	#2
:cmp	lda	(ADD_PTR),y
	cmp	high_score_lo,y
	bcc	:done
	bne	:high
	dey
	bpl	:cmp
:done	rts
:high	ldy	#2
:copy	lda	(ADD_PTR),y
	sta	high_score_lo,y
	dey
	bpl	:copy
	ldx	#CELL_HI_SCORE
	ldy	#high_score_lo
	lda	#4
	jmp	draw_score

* draw_lives_row ($2B6A), task $1A: color the bottom rows, draw lives.
draw_lives_row
	lda	game_mode
	cmp	#1
	bne	:go
	rts
:go	ldx	#9
	lda	#$09
:col	sta	$4412,x
	sta	$4432,x
	dex
	bpl	:col
	lda	lives_displayed
	jmp	draw_lives

* draw_bonus_digits ($26B2), task $1F: the threshold's two digits.
draw_bonus_digits
	lda	dip_bonus_life
	and	#$0F
	clc
	adc	#TILE_DIGIT0
	sta	CELL_BONUS1
	lda	dip_bonus_life
	lsr
	lsr
	lsr
	lsr
	beq	:done
	clc
	adc	#TILE_DIGIT0
	sta	CELL_BONUS10
:done	rts

* read_dip_switches ($26D0), task $14. T0 dip, T1 coinage.
read_dip_switches
	jsr	read_dsw1
	sta	T0
	and	#$03
	sta	T1
	bne	:paid
	lda	#$FF
	sta	credits
:paid	lda	T1
	lsr
	sta	T2
	lda	T1
	and	#1
	clc
	adc	T2
	sta	dip_coins_per_credit
	and	#$02
	eor	T1
	sta	dip_credits_per_coin
	lda	T0
	lsr
	lsr
	and	#$03
	inc
	cmp	#4
	bne	:lives
	lda	#5
:lives	sta	dip_lives
	lda	T0
	lsr
	lsr
	lsr
	lsr
	and	#$03
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	|BONUS_TABLE,x
	sta	dip_bonus_life
	lda	T0
	and	#$80
	beq	:alt
	lda	#0
	bra	:names
:alt	lda	#1
:names	sta	ghost_names_mode
	ldx	#0
	lda	T0
	and	#$40
	bne	:easy
	ldx	#2
:easy	rep	#$20
	lda	|DIFFICULTY_TAB,x
	sta	dip_difficulty_ptr_lo
	sep	#$20
	jsr	read_in1
	and	#$80
	beq	:cocktail
	lda	#0
	bra	:table
:cocktail	lda	#1
:table	sta	dip_cocktail
	rts

* draw_scores ($2AE0), task $18: HIGH SCORE and both scores, cleared.
* Player 2's field is blank in a one-player game.
draw_scores
	lda	#0
	jsr	draw_message
	ldx	#7
:zero	stz	score_p1_lo,x
	dex
	bpl	:zero
	ldx	#CELL_P1_SCORE
	ldy	#score_p1_lo
	lda	#4
	jsr	draw_score
	lda	num_players
	bne	:two
	lda	#6
	bra	:p2
:two	lda	#4
:p2	ldx	#CELL_P2_SCORE
	ldy	#score_p2_lo
	jmp	draw_score

* show_credits ($2BA1), task $1D: CREDIT and the count, or FREE PLAY.
* The tens digit is only ever drawn, never erased.
show_credits
	lda	credits
	cmp	#$FF
	bne	:credit
	lda	#2
	jmp	draw_message
:credit	lda	#1
	jsr	draw_message
	lda	credits
	and	#$F0
	beq	:ones
	lda	credits
	lsr
	lsr
	lsr
	lsr
	clc
	adc	#TILE_DIGIT0
	sta	CELL_CREDIT10
:ones	lda	credits
	and	#$0F
	clc
	adc	#TILE_DIGIT0
	sta	CELL_CREDIT1
	rts
