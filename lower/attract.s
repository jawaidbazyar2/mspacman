*
* attract.c: the attract-mode marquee, cards, and demo.
*

MIDWAY_CELL	equ	$429A
BULB_CELLS	equ	$3F81	; six bulb-cell words, 16 bytes apart
WALK_BLINKY	equ	$24	; cast-walk script sets
WALK_PINKY	equ	$30
WALK_INKY	equ	$3C
WALK_SUE	equ	$48
WALK_MS_PAC	equ	$54

* LIT offset;tile: light the bulb whose cell is the word at T8+offset.
LIT	MAC
	ldx	T8
	rep	#$20
	lda	|]1,x
	tax
	sep	#$20
	lda	#]2
	sta	|$0000,x
	jsr	vid_log
	<<<

* DIM offset;tile: dim the bulb at T8+offset, light the one after it.
DIM	MAC
	ldx	T8
	rep	#$20
	lda	|]1,x
	tay
	lda	|]1+2,x
	tax
	sep	#$20
	lda	|$0000,y
	dec
	sta	|$0000,y
	lda	#]2
	sta	|$0000,x
	jsr	vid_log
	tyx
	jsr	vid_log
	<<<

* marquee_bulbs ($3ED0): the lit bulbs step around the marquee. On odd
* steps six bulbs light; on even steps they dim and the next six
* light. T8 the cell list.
marquee_bulbs
	lda	marquee_step
	inc
	and	#$0F
	sta	marquee_step
	lsr
	bcc	:even
	lda	marquee_step
	and	#$FE
	rep	#$20
	and	#$00FF
	clc
	adc	#BULB_CELLS
	sta	T8
	sep	#$20
	LIT	$00;$87
	LIT	$10;$87
	LIT	$20;$8A
	LIT	$30;$81
	LIT	$40;$81
	LIT	$50;$84
	rts
:even	lda	marquee_step
	rep	#$20
	and	#$00FF
	clc
	adc	#BULB_CELLS-2
	sta	T8
	sep	#$20
	DIM	$00;$88
	DIM	$10;$88
	DIM	$20;$8B
	DIM	$30;$82
	DIM	$40;$82
	DIM	$50;$83
	rts

* show_card(text in A): a card, then the next attract step. T8 text.
show_card
	sta	T8
	stz	T9
	lda	#TASK_TEXT
	ldx	T8
	jsr	queue_task
	jmp	advance_attract_state

* open_marquee ($045F): clear the screen and show "MS PAC-MAN" for ten
* units.
open_marquee
	QT	TASK_CLEAR_SCREEN;1
	QT	TASK_MAZE_COLORS;0
	QT	TASK_PLACE_ACTORS;0
	QT	TASK_CLEAR_SPRITES;0
	QT	TASK_TEXT;$0C
	lda	#$4A		; TIMER(1, $0A)
	ldx	#2		; TT_ATTRACT_STATE
	ldy	#0
	jsr	queue_timed
	cmp	#0
	beq	:r
	jmp	advance_attract_state
:r	rts

* attract_step ($3E5C): one step of the attract sequence. The walks
* advance on their own; step 3 waits for the timed task.
attract_step
	lda	game_mode_sub1
	cmp	#$10
	beq	:sw
	jsr	marquee_bulbs
:sw	lda	game_mode_sub1
	cmp	#17
	bcs	:r
	asl
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	jmp	(:tab,x)
:r	rts
:s1	jsr	draw_midway_logo
	jmp	advance_attract_state
:s2	QT	TASK_TEXT;$0C
	lda	#$60
	sta	marquee_step
	jmp	advance_attract_state
:s4	lda	#$0E		; "WITH"
	jmp	show_card
:s5	lda	#$0D
	jmp	show_card
:s6	lda	#WALK_BLINKY
	jmp	run_cutscene
:s7	QT	TASK_TEXT;$30
	lda	#$0F
	jmp	show_card
:s8	lda	#WALK_PINKY
	jmp	run_cutscene
:s9	lda	#$2F
	jmp	show_card
:s10	lda	#WALK_INKY
	jmp	run_cutscene
:s11	lda	#$31
	jmp	show_card
:s12	lda	#WALK_SUE
	jmp	run_cutscene
:s13	lda	#$10
	jmp	show_card
:s14	lda	#$33
	jmp	show_card
:s15	lda	#WALK_MS_PAC
	jmp	run_cutscene
:s16	stz	lives_real	; $3EC9: the demo game
	jmp	level_step
:tab	da	open_marquee,:s1,:s2,:r,:s4,:s5,:s6,:s7
	da	:s8,:s9,:s10,:s11,:s12,:s13,:s14,:s15
	da	:s16

* draw_midway_logo ($9642): queue the copyright lines and draw the
* Midway logo, a 4x4 block of tiles $B0-$BF in color 1. Each row steps
* the tile down by 4 per cell. T6 tile, T7 col, T8 row.
draw_midway_logo
	lda	#TASK_TEXT
	ldx	#$13
	jsr	queue_task
	lda	#TASK_TEXT
	ldx	#$35
	jsr	queue_task
	ldx	#MIDWAY_CELL
	lda	#$BF
	sta	T6
	lda	#4
	sta	T8
:row	lda	#4
	sta	T7
:col	lda	T6
	sta	|$0000,x
	lda	#1
	sta	|COLOR_RAM,x
	jsr	vid_log
	dec	T7
	beq	:rowend
	inx
	lda	T6
	sec
	sbc	#4
	sta	T6
	bra	:col
:rowend	rep	#$20
	txa
	clc
	adc	#$001D
	tax
	sep	#$20
	lda	T6
	clc
	adc	#$0B
	sta	T6
	dec	T8
	bne	:row
	rts
