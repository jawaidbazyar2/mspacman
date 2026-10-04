*
* maze.c: walls, pills, maze colors, the pill bitmap, start positions.
*

MAZE_TOP	equ	$4040	; first maze cell; rows above are the HUD
MAZE_END	equ	$43C0	; one past the last maze cell
PILL	equ	$10
PILL_BITS	equ	30	; bitmap bytes, 8 pills each

MAZE_LAYOUTS	equ	$9474	; per-maze word tables
PILL_DELTAS	equ	$9499
POWER_PILL_CELLS	equ	$951C
TUNNEL_CELLS	equ	$95DF
MAZE_ORDER	equ	$94DF	; level -> maze number
MAZE_COLOR_ORDER	equ	$95AE	; level -> wall color

LEVEL_PLAYING	equ	3
DIR_RIGHT	equ	0
DIR_DOWN	equ	1
DIR_LEFT	equ	2
DIR_UP	equ	3

* level_slot(level in A, first in X, period in Y) -> A. Levels below
* `first` index directly; later ones repeat the last `period` entries.
* The test is the sign of the 8-bit difference.
level_slot
	sta	T0
	txa
	sta	T1
	tya
	sta	T2
	lda	T0
	sec
	sbc	T1
	bpl	:loop
	lda	T0
	rts
:loop	sec
	sbc	T2
	bpl	:loop
	clc
	adc	T1
	rts

* maze_word(table in X) -> X ($94BD): this level's word in a per-maze
* table. Changes T0-T5.
maze_word
	stx	T4
	lda	level_number
	ldx	#13
	ldy	#8
	jsr	level_slot
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	|MAZE_ORDER,x
	asl
	rep	#$20
	and	#$00FF
	clc
	adc	T4
	tax
	lda	|$0000,x
	tax
	sep	#$20
	rts

* power_pill_cell(k in A) -> X: the k-th power pill's cell. Changes T0-T7.
power_pill_cell
	asl
	sta	T6
	stz	T7
	ldx	#POWER_PILL_CELLS
	jsr	maze_word
	rep	#$20
	txa
	clc
	adc	T6
	tax
	lda	|$0000,x
	tax
	sep	#$20
	rts

* flash_power_pills ($0C0D): every ten frames. Outside play, the two
* attract-screen pills blink instead. T10 color.
flash_power_pills
	inc	power_pill_flash_counter
	lda	power_pill_flash_counter
	cmp	#10
	beq	:go
	rts
:go	stz	power_pill_flash_counter
	lda	level_state
	cmp	#LEVEL_PLAYING
	beq	:play
	lda	$4732
	cmp	#PILL
	beq	:off
	lda	#PILL
	bra	:set
:off	lda	#0
:set	sta	$4732
	sta	$4678
	ldx	#$4732
	jsr	vid_log
	ldx	#$4678
	jmp	vid_log
:play	lda	$447E
	sta	T10
	lda	#0
	jsr	power_pill_cell
	lda	|COLOR_RAM,x
	cmp	T10
	bne	:all
	stz	T10
:all	ldy	#0
:pp	phy
	tya
	jsr	power_pill_cell
	ply
	lda	T10
	sta	|COLOR_RAM,x
	jsr	vid_log
	iny
	cpy	#4
	bcc	:pp
	rts

* pill_bitmap_task ($2487), task $15: record which pills are on screen.
* T8 delta pointer, T10 cell, T13 bits, T14 bit count.
pill_bitmap_task
	ldx	#PILL_DELTAS
	jsr	maze_word
	stx	T8
	ldx	#$4000
	stx	T10
	ldy	#0
:byte	stz	T13
	lda	#8
	sta	T14
:bit	jsr	next_pill_cell
	lda	|$0000,x
	cmp	#PILL
	clc
	bne	:sh
	sec
:sh	rol	T13
	dec	T14
	bne	:bit
	lda	T13
	sta	pill_bitmap,y
	iny
	cpy	#PILL_BITS
	bcc	:byte
	ldy	#0
:pp	phy
	tya
	jsr	power_pill_cell
	ply
	lda	|$0000,x
	sta	power_pill_data,y
	iny
	cpy	#4
	bcc	:pp
	rts

* Step T10 by the next delta byte at T8 -> X.
next_pill_cell
	ldx	T8
	lda	|$0000,x
	inx
	stx	T8
	rep	#$20
	and	#$00FF
	clc
	adc	T10
	sta	T10
	tax
	sep	#$20
	rts

* reset_pills ($24C9), task $12: every pill present.
reset_pills
	lda	#$FF
	ldx	#pill_bitmap
	ldy	#PILL_BITS
	jsr	fillb
	lda	#$14
	ldx	#power_pill_data
	ldy	#4
	jmp	fillb

* draw_pills ($2448), task $03: the pills the bitmap says are present.
draw_pills
	VIDFULL
	ldx	#PILL_DELTAS
	jsr	maze_word
	stx	T8
	ldx	#$4000
	stx	T10
	ldy	#0
:byte	lda	pill_bitmap,y
	sta	T13
	lda	#8
	sta	T14
:bit	jsr	next_pill_cell
	asl	T13
	bcc	:no
	lda	#PILL
	sta	|$0000,x
:no	dec	T14
	bne	:bit
	iny
	cpy	#PILL_BITS
	bcc	:byte
	ldy	#0
:pp	phy
	tya
	jsr	power_pill_cell
	ply
	lda	power_pill_data,y
	sta	|$0000,x
	iny
	cpy	#4
	bcc	:pp
	rts

* erase_pills ($2A35), task $13: blank every pill and power pill.
erase_pills
	VIDFULL
	ldx	#MAZE_TOP
:loop	lda	|$0000,x
	cmp	#$10
	beq	:blank
	cmp	#$12
	beq	:blank
	cmp	#$14
	bne	:next
:blank	lda	#TILE_BLANK
	sta	|$0000,x
:next	inx
	cpx	#MAZE_END
	bne	:loop
	rts

* clear_colors ($240D), task $06.
clear_colors
	VIDFULL
	lda	#0
	ldx	#$4400
	ldy	#$0400
	jmp	fillb

* clear_screen(which in A) ($23ED), task $00: 1 blanks only the maze.
clear_screen
	VIDFULL
	cmp	#1
	bne	:all
	lda	#TILE_BLANK
	ldx	#MAZE_TOP
	ldy	#MAZE_END-MAZE_TOP
	jmp	fillb
:all	lda	#TILE_BLANK
	ldx	#$4000
	ldy	#$0400
	jmp	fillb

* draw_maze ($2419), task $02: the layout is (skip, tile) runs for the
* left half; each tile is mirrored onto the right half with bit 0
* flipped. Y walks the layout. T8 cell, T10 tile.
draw_maze
	VIDFULL
	ldx	#MAZE_LAYOUTS
	jsr	maze_word
	txy
	ldx	#$4000
	stx	T8
:loop	lda	|$0000,y
	beq	:done
	bmi	:tile
	rep	#$20
	and	#$00FF
	dec
	clc
	adc	T8
	sta	T8
	sep	#$20
	iny
	lda	|$0000,y
:tile	sta	T10
	rep	#$20
	inc	T8
	ldx	T8
	sep	#$20
	sta	|$0000,x
	rep	#$20
	lda	T8
	and	#$001F
	asl
	clc
	adc	#$83E0
	sec
	sbc	T8
	tax
	sep	#$20
	lda	T10
	eor	#1
	sta	|$0000,x
	iny
	bra	:loop
:done	rts

* wall_color(which in A) -> A: $1F for the end-of-board flash, 1 in
* some attract screens, otherwise this level's color.
wall_color
	cmp	#2
	bne	:n2
	lda	#$1F
	rts
:n2	lda	game_mode_sub1
	beq	:lvl
	cmp	#$10
	beq	:lvl
	lda	#1
	rts
:lvl	lda	level_number
	ldx	#21
	ldy	#16
	jsr	level_slot
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	|MAZE_COLOR_ORDER,x
	rts

* maze_colors(which in A) ($24D7), task $01: 1 also marks the slow
* tunnel cells (color bit 6) before level 3 and colors the house door.
* T8 cell, T12 which.
maze_colors
	VIDFULL
	sta	T12
	jsr	wall_color
	ldx	#$4440
	ldy	#$0380
	jsr	fillb
	lda	#$0F
	ldx	#$47C0
	ldy	#$0040
	jsr	fillb
	lda	T12
	cmp	#1
	beq	:one
	rts
:one	lda	level_number
	sec
	sbc	#3
	bpl	:door
	ldx	#TUNNEL_CELLS
	jsr	maze_word
	txy
	ldx	#$4400
	stx	T8
:t	lda	|$0000,y
	beq	:door
	iny
	rep	#$20
	and	#$00FF
	clc
	adc	T8
	sta	T8
	tax
	sep	#$20
	lda	|$0000,x
	ora	#$40
	sta	|$0000,x
	bra	:t
:door	lda	#$18
	sta	$45ED
	sta	$460D
	rts

* demo_mode ($2698), task $07.
demo_mode
	lda	#1
	sta	game_mode
	stz	game_mode_sub0
	rts

* clear_actors ($26A2), task $11: zero $4D00-$4DFF.
clear_actors
	lda	#0
	ldx	#pos
	ldy	#$0100
	jmp	fillb

* house_timer(param in A) ($268B), task $05.
house_timer
	cmp	#1
	beq	:t
	lda	#1
	sta	substate
:t	lda	#$55
	sta	ghost_home_move_counter
	rts

* place_actors(intro in A) ($253D), task $04: 0 is the start of play,
* anything else lines everyone up for the attract introduction. A Coord
* word is y low, x high.
place_actors
	sta	T12
	rep	#$20
	lda	#$0120		; code $20, color 1
	sta	sprite+2
	lda	#$0320
	sta	sprite+4
	lda	#$0520
	sta	sprite+6
	lda	#$0720
	sta	sprite+8
	lda	#$092C
	sta	sprite+10
	lda	#$003F
	sta	sprite+12
	sep	#$20
	lda	#DIR_LEFT
	sta	pac_wanted_dir
	lda	T12
	beq	:play
	rep	#$20
	ldx	#0
:g	lda	#$0094
	sta	pos,x
	lda	#$1E32
	sta	mid_tile,x
	sta	tile,x
	inx
	inx
	cpx	#8
	bcc	:g
	lda	#$0100
	ldx	#0
:s	sta	step,x
	sta	next_step,x
	inx
	inx
	cpx	#10
	bcc	:s
	lda	#DIR_LEFT*$0101
	sta	prev_dir
	sta	prev_dir+2
	sta	dir
	sta	dir+2
	sep	#$20
	sta	dir+4
	rep	#$20
	lda	#$0894
	sta	pos+8
	lda	#$1F32
	sta	mid_tile+8
	sta	tile+8
	sep	#$20
	rts
:play	rep	#$20
	lda	#$8064
	sta	pos
	lda	#$807C
	sta	pos+2
	lda	#$907C
	sta	pos+4
	lda	#$707C
	sta	pos+6
	lda	#$80C4
	sta	pos+8
	lda	#$2E2C
	sta	mid_tile
	sta	tile
	lda	#$2E2F
	sta	mid_tile+2
	sta	tile+2
	lda	#$302F
	sta	mid_tile+4
	sta	tile+4
	lda	#$2C2F
	sta	mid_tile+6
	sta	tile+6
	lda	#$2E38
	sta	mid_tile+8
	sta	tile+8
	lda	#$0100
	sta	step
	sta	next_step
	sta	step+8
	sta	next_step+8
	lda	#$0001
	sta	step+2
	sta	next_step+2
	lda	#$00FF
	sta	step+4
	sta	next_step+4
	sta	step+6
	sta	next_step+6
	lda	#DIR_DOWN*$100+DIR_LEFT
	sta	prev_dir
	sta	dir
	lda	#DIR_UP*$0101
	sta	prev_dir+2
	sta	dir+2
	stz	fruit_pos
	sep	#$20
	lda	#DIR_LEFT
	sta	dir+4
	rts
