*
* coin.c: coins and credits, from the vertical blank.
*

COIN_LOCKOUT	equ	$5006	; latch: 1 accepts coins
COIN_COUNTER	equ	$5007	; latch: pulses the coin meter

* add_coin ($02DF): enough coins add credits, capped at 99.
add_coin
	inc	coins_inserted
	lda	coins_inserted
	cmp	dip_coins_per_credit
	beq	:go
	rts
:go	stz	coins_inserted
	sed
	clc
	lda	dip_credits_per_coin
	adc	credits
	cld
	bcc	:ok
	lda	#$99
:ok	sta	credits
	lda	effect
	ora	#$02
	sta	effect
	rts

* coin_meter ($02AD): one 16-frame pulse per counted coin; the coin
* counts at the start of the pulse.
coin_meter
	lda	coin_counter
	bne	:go
	rts
:go	lda	coin_counter_timeout
	bne	:n0
	lda	#1
	sta	COIN_COUNTER
	jsr	add_coin
	lda	#0
:n0	cmp	#8
	bne	:n8
	stz	COIN_COUNTER
:n8	inc
	sta	coin_counter_timeout
	cmp	#$10
	bne	:done
	stz	coin_counter_timeout
	dec	coin_counter
:done	rts

* pressed(history at X, switch in A) -> Z set on a press: shift the
* sample into a 4-frame history; a press is the active-low 1100.
pressed
	cmp	#1
	lda	|$0000,x
	rol
	and	#$0F
	sta	|$0000,x
	cmp	#$0C
	rts

* coin_inputs ($0267): free play and 99 credits lock the slots. The
* service switch credits at once; coins wait for coin_meter. T8 IN0.
coin_inputs
	lda	credits
	cmp	#$99
	bcc	:accept
	stz	COIN_LOCKOUT
	rts
:accept	lda	#1
	sta	COIN_LOCKOUT
	jsr	read_in0
	sta	T8
	and	#$80
	ldx	#in_service_hist
	jsr	pressed
	bne	:coin2
	jsr	add_coin
:coin2	lda	T8
	and	#$40
	ldx	#in_coin2_hist
	jsr	pressed
	bne	:coin1
	inc	coin_counter
:coin1	lda	T8
	and	#$20
	ldx	#in_coin1_hist
	jsr	pressed
	bne	:done
	inc	coin_counter
:done	rts
