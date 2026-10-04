*
* sprite.c: sprite positions and codes for the next vertical blank.
* sprite_pos entries are x, then y.
*

PAC_DIR_TABLE	equ	$1514	; jump per direction to the mouth frames
SP_CK	equ	$64	; choose_codes: cocktail player 2

* place_upright: actors then the fruit in slots 1-6; y is flipped, x
* offset 6 for slots 1-2 and 7 for the rest.
place_upright
	ldx	#0
:l	lda	pos,x
	eor	#$FF
	clc
	adc	#9
	sta	sprite_pos+3,x
	lda	pos+1,x
	clc
	adc	#6
	cpx	#4
	bcc	:s
	inc
:s	sta	sprite_pos+2,x
	inx
	inx
	cpx	#10
	bcc	:l
	lda	fruit_pos_y
	eor	#$FF
	clc
	adc	#9
	sta	sprite_pos+13
	lda	fruit_pos_x
	clc
	adc	#7
	sta	sprite_pos+12
	rts

* place_cocktail: player 2 on a cocktail table sees the screen upside
* down. Out of scope for the port; kept for the ROM's behavior.
place_cocktail
	ldx	#0
:l	lda	pos,x
	clc
	adc	#8
	sta	sprite_pos+3,x
	lda	pos+1,x
	eor	#$FF
	clc
	adc	#7
	cpx	#4
	bcc	:s
	inc
:s	sta	sprite_pos+2,x
	inx
	inx
	cpx	#10
	bcc	:l
	lda	fruit_pos_y
	clc
	adc	#8
	sta	sprite_pos+13
	lda	fruit_pos_x
	eor	#$FF
	clc
	adc	#8
	sta	sprite_pos+12
	rts

* pac_phase(coord in A) -> A: (coord & 7) >> 1.
pac_phase
	and	#$07
	lsr
	rts

* pac_code(code in A, closed in T0): an odd frame is open; an even one
* shows `closed`.
pac_code
	bit	#$01
	bne	:s
	lda	T0
:s	sta	sprite+10
	rts

* face_pac ($869C...): the mouth follows her position along the
* direction of travel.
face_pac
	lda	dir+4
	asl
	rep	#$20
	and	#$00FF
	tax
	lda	|PAC_DIR_TABLE,x
	cmp	#$168C
	beq	:c0
	cmp	#$16B1
	beq	:c1
	cmp	#$16D6
	beq	:c2
	cmp	#$16F7
	beq	:c3
	sep	#$20
	rts
:c0	sep	#$20
	lda	#$37
	sta	T0
	lda	pos+9
	jsr	pac_phase
	eor	#$FF
	clc
	adc	#$30
	jmp	pac_code
:c1	sep	#$20
	lda	#$34
	sta	T0
	lda	pos+8
	jsr	pac_phase
	clc
	adc	#$30
	jmp	pac_code
:c2	sep	#$20
	lda	#$35
	sta	T0
	lda	pos+9
	jsr	pac_phase
	clc
	adc	#$AC
	jmp	pac_code
:c3	sep	#$20
	lda	#$36
	sta	T0
	lda	pos+8
	jsr	pac_phase
	eor	#$FF
	clc
	adc	#$F4
	jmp	pac_code

* flip_pac: cocktail player 2 turns her sprite over. T0 code.
flip_pac
	lda	sprite+10
	bit	#$C0
	bne	:e
	ora	#$C0
	sta	sprite+10
	rts
:e	sta	T0
	lda	dir+4
	cmp	#DIR_LEFT
	bne	:up
	lda	T0
	and	#$80
	bne	:flip
:up	lda	dir+4
	cmp	#DIR_UP
	bne	:r
	lda	T0
	and	#$40
	beq	:r
:flip	lda	T0
	eor	#$C0
	sta	sprite+10
:r	rts

* ghost_frames: every ghost gets the blue frame; one that is not blue
* and alive then gets the frame for its direction.
ghost_frames
	lda	ghost_anim_phase
	clc
	adc	#$1C
	sta	sprite+2
	sta	sprite+4
	sta	sprite+6
	sta	sprite+8
	ldx	#0
	ldy	#0
:l	lda	ghost_state,x
	bne	:set
	lda	frightened,x
	bne	:next
:set	lda	dir,x
	asl
	clc
	adc	ghost_anim_phase
	clc
	adc	#$20
	sta	sprite+2,y
:next	inx
	iny
	iny
	cpx	#4
	bcc	:l
	rts

* choose_codes(cocktail in A) ($14FE).
choose_codes
	sta	SP_CK
	lda	pac_death_anim
	ora	ghosts_killed_pending
	bne	:g
	jsr	face_pac
	lda	SP_CK
	beq	:g
	jsr	flip_pac
:g	lda	pac_death_anim
	bne	:gf
	lda	ghosts_killed_pending
	bne	:cs
:gf	jsr	ghost_frames
:cs	jsr	cutscene1_sprites
	jsr	cutscene2_sprites
	jsr	cutscene3_sprites
	lda	SP_CK
	beq	:r
	ldx	#2
:l	cpx	#10
	beq	:n
	lda	sprite,x
	ora	#$C0
	sta	sprite,x
:n	inx
	inx
	cpx	#14
	bcc	:l
:r	rts

* sprites_upright ($1490).
sprites_upright
	lda	player_number
	and	dip_cocktail
	beq	:go
	rts
:go	jsr	place_upright
	lda	#0
	jmp	choose_codes

* sprites_cocktail ($141F): cocktail player 2.
sprites_cocktail
	lda	player_number
	and	dip_cocktail
	bne	:go
	rts
:go	jsr	place_cocktail
	lda	#1
	jmp	choose_codes
