*
* siren.c: the background siren, which rises as the board empties.
*

* siren_update ($0E6C): the low five bits of effect channel 2's request
* byte pick the siren by dots eaten; the top three are kept. Silent
* while Ms. Pac-Man is dying.
siren_update
	lda	pac_death_anim
	beq	:alive
	stz	effect+effect_SIZE
	rts
:alive	lda	dots_eaten
	cmp	#$E4
	bcc	:d4
	lda	#$10
	bra	:set
:d4	cmp	#$D4
	bcc	:b4
	lda	#$08
	bra	:set
:b4	cmp	#$B4
	bcc	:74
	lda	#$04
	bra	:set
:74	cmp	#$74
	bcc	:low
	lda	#$02
	bra	:set
:low	lda	#$01
:set	sta	T0
	lda	effect+effect_SIZE
	and	#$E0
	ora	T0
	sta	effect+effect_SIZE
	rts
