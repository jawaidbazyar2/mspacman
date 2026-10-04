*
* draw.c: 2x2 blocks, the fruit row, and the message table.
*

FRUIT_TABLE	equ	$3B08	; tile, color per fruit
FRUIT_ROW	equ	$4004	; bottom row, rightmost fruit slot
MESSAGES	equ	$36A5	; pointer per message
MARK_TILES	equ	$9616	; the Ms. Pac-Man mark in the bonus line
MSG_END	equ	$2F	; '/' ends a message's text

DRAW_N	equ	$24	; text_task's message number

* draw_block(cell in X, tile in A): a 2x2 block of one tile.
draw_block
	sta	|$0000,x
	sta	|$0001,x
	sta	|$0020,x
	sta	|$0021,x
	jmp	vid_log4

* draw_icon(cell in X, tile in A): four consecutive tiles.
draw_icon
	sta	|$0000,x
	inc
	sta	|$0001,x
	inc
	sta	|$0020,x
	inc
	sta	|$0021,x
	jmp	vid_log4

* draw_fruit_row ($2BEA), task $1B: one fruit per level up to seven,
* then blanks. The attract mode leaves the row alone.
* T0 fruits, T1 i, T2 cell.
draw_fruit_row
	lda	game_mode
	cmp	#1
	bne	:go
	rts
:go	lda	level_number
	cmp	#6
	bcc	:few
	lda	#7
	bra	:n
:few	inc
:n	sta	T0
	stz	T1
	ldx	#FRUIT_ROW
	stx	T2
:slot	lda	T1
	cmp	T0
	bcs	:blank
	asl
	rep	#$20
	and	#$00FF
	tay
	sep	#$20
	ldx	T2
	lda	|FRUIT_TABLE,y
	jsr	draw_icon
	rep	#$20
	lda	T2
	clc
	adc	#COLOR_RAM
	tax
	sep	#$20
	lda	|FRUIT_TABLE+1,y
	jsr	draw_block
	bra	:next
:blank	ldx	T2
	lda	#TILE_BLANK
	jsr	draw_block
	rep	#$20
	lda	T2
	clc
	adc	#COLOR_RAM
	tax
	sep	#$20
	lda	#0
	jsr	draw_block
:next	ldx	T2
	inx
	inx
	stx	T2
	inc	T1
	lda	T1
	cmp	#7
	bcc	:slot
	rts

* draw_message(n in A) ($2C5E): bit 7 of n erases. A message is a screen
* offset, the text up to '/', then the colors: a first color with bit 7
* set colors every cell, otherwise one color per cell. Text runs down the
* column-major video RAM ($-20 per cell), or one cell back on the top
* and bottom rows (offset bit 15).
* T0 n, T2 rec, T4 video, T6 color, T8 step, T10 count, T11 first,
* T12 the CPIR counter, T14 cells left; Y walks the record.
draw_message
	sta	T0
	asl
	rep	#$20
	and	#$00FF
	tax
	lda	|MESSAGES,x
	sta	T2
	tax
	lda	|$0000,x
	tay
	clc
	adc	#$4400
	and	#$5FFF		; the C writes the $C000 mirror; use $4000
	sta	T6
	sec
	sbc	#COLOR_RAM
	sta	T4
	tya
	bmi	:back
	lda	#$FFE0
	bra	:step
:back	lda	#$FFFF
:step	sta	T8
	lda	T2
	inc
	inc
	tay
	sep	#$20
	stz	T10
:text	lda	|$0000,y
	cmp	#MSG_END
	beq	:tdone
	bit	T0
	bpl	:keep
	lda	#TILE_BLANK
:keep	ldx	T4
	sta	|$0000,x
	jsr	vid_log
	rep	#$20
	lda	T4
	clc
	adc	T8
	sta	T4
	sep	#$20
	iny
	inc	T10
	bra	:text
:tdone	iny
	bit	T0
	bpl	:colors
* Erase: skip a second '/'-terminated string the way CPIR did. The
* color count becomes the high byte of its counter, (count + 1) << 8.
	lda	T10
	inc
	sta	T13
	stz	T12
:skip	rep	#$20
	dec	T12
	sep	#$20
	lda	|$0000,y
	iny
	cmp	#MSG_END
	beq	:sdone
	ldx	T12
	bne	:skip
:sdone	lda	T13
	sta	T10
:colors	lda	|$0000,y
	sta	T11
	rep	#$20
	lda	T10
	and	#$00FF
	bne	:left
	lda	#$0100
:left	sta	T14
	sep	#$20
:cell	lda	T11
	bmi	:all
	lda	|$0000,y
	iny
:all	ldx	T6
	sta	|$0000,x
	jsr	vid_log
	rep	#$20
	lda	T6
	clc
	adc	T8
	sta	T6
	dec	T14
	sep	#$20
	bne	:cell
	rts

* draw_tile_list(p in X): records of color, tile, cell address, ending
* with $FF. The color goes to cell | $400.
draw_tile_list
	txy
:rec	lda	|$0000,y
	cmp	#$FF
	beq	:done
	sta	T0
	rep	#$20
	lda	|$0002,y
	tax
	sep	#$20
	lda	|$0001,y
	sta	|$0000,x
	jsr	vid_log
	rep	#$20
	txa
	ora	#COLOR_RAM
	tax
	sep	#$20
	lda	T0
	sta	|$0000,x
	jsr	vid_log
	iny
	iny
	iny
	iny
	bra	:rec
:done	rts

* text_task(n in A) ($95E3), task $1C: a message, with three extras.
* $0A also draws the mark in the bonus line. $0B draws the Midway logo
* first and becomes $20 when the dip switch turns the bonus life off.
* $06 clears the intermission flag.
text_task
	sta	DRAW_N
	cmp	#$0A
	bne	:not0a
	ldx	#MARK_TILES
	jsr	draw_tile_list
	bra	:msg
:not0a	cmp	#$0B
	bne	:not0b
	jsr	draw_midway_logo
	jsr	read_dsw1
	and	#$30
	cmp	#$30
	bne	:msg
	lda	#$20
	sta	DRAW_N
	bra	:msg
:not0b	cmp	#$06
	bne	:msg
	stz	intermission_flag
:msg	lda	DRAW_N
	jmp	draw_message
