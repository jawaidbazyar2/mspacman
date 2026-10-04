*
* difficulty.c: per-board speeds, ghost-house limits, the cruise elroy
* thresholds, and the frightened time.
*

DIFFICULTY_ROWS	equ	$0796	; 6 bytes per row
SPEED_PATTERNS	equ	$330F	; 42 bytes per entry
EXIT_LIMITS	equ	$0843	; 3 bytes per entry
ELROY_PILLS	equ	$084F	; 2 bytes per entry
BLUE_TIMES	equ	$0861	; word per entry
LEAVE_HOME	equ	$0873	; word per entry

DIFF_ROW	equ	$20	; word: the difficulty row
DIFF_SPD	equ	$22	; word: the speed pattern entry

* load_difficulty(index in A) ($070E), task $10. 0 takes the row from
* the difficulty pointer. Every product wraps at 8 bits, as the C does.
load_difficulty
	cmp	#0
	bne	:have
	ldx	difficulty_ptr_lo
	lda	|$0000,x
:have	jsr	mul3
	asl
	rep	#$20
	and	#$00FF
	clc
	adc	#DIFFICULTY_ROWS
	sta	DIFF_ROW
	sep	#$20
* speeds = SPEED_PATTERNS + (uint8_t)(rom[row] * 42)
	ldx	DIFF_ROW
	lda	|$0000,x
	asl
	sta	T0		; *2
	asl
	asl
	sta	T1		; *8
	asl
	asl			; *32
	clc
	adc	T1
	clc
	adc	T0
	rep	#$20
	and	#$00FF
	clc
	adc	#SPEED_PATTERNS
	sta	DIFF_SPD
	sep	#$20
	ldx	DIFF_SPD
	ldy	#pac_speed
	lda	#$1C
	jsr	copyb
* The same 12-byte ghost patterns for ghosts 1-3.
	rep	#$20
	lda	DIFF_SPD
	clc
	adc	#$10
	sta	T8
	sep	#$20
	ldx	T8
	ldy	#pac_speed+$1C
	lda	#12
	jsr	copyb
	ldx	T8
	ldy	#pac_speed+$1C+12
	lda	#12
	jsr	copyb
	ldx	T8
	ldy	#pac_speed+$1C+24
	lda	#12
	jsr	copyb
	rep	#$20
	lda	DIFF_SPD
	clc
	adc	#$1C
	tax
	sep	#$20
	ldy	#ghost_orient_table
	lda	#14
	jsr	copyb

	ldx	DIFF_ROW
	lda	|$0001,x
	sta	diff_unused_4db0
* pink_exit_limit <- EXIT_LIMITS + (uint8_t)(row[2] * 3), 3 bytes
	lda	|$0002,x
	jsr	mul3
	rep	#$20
	and	#$00FF
	clc
	adc	#EXIT_LIMITS
	tax
	sep	#$20
	ldy	#pink_exit_limit
	lda	#3
	jsr	copyb
* elroy1_pill_threshold <- ELROY_PILLS + (uint8_t)(row[3] * 2), 2 bytes
	ldx	DIFF_ROW
	lda	|$0003,x
	ldy	#elroy1_pill_threshold
	rep	#$20
	ldx	#ELROY_PILLS
	jsr	:copy2
* frightened_time <- BLUE_TIMES + (uint8_t)(row[4] * 2)
	ldx	DIFF_ROW
	lda	|$0004,x
	ldy	#frightened_time_lo
	rep	#$20
	ldx	#BLUE_TIMES
	jsr	:copy2
* ghost_leave_home_units <- LEAVE_HOME + (uint8_t)(row[5] * 2)
	ldx	DIFF_ROW
	lda	|$0005,x
	ldy	#ghost_leave_home_units_lo
	rep	#$20
	ldx	#LEAVE_HOME
	jsr	:copy2
	jmp	draw_fruit_row

* A (16-bit, low byte the entry) -> copy 2 bytes from X + (uint8_t)(A*2)
* to Y. Called with M=0, returns with M=1.
:copy2
	mx	%00
	and	#$00FF
	asl
	and	#$00FF
	stx	T0
	clc
	adc	T0
	tax
	sep	#$20
	lda	#2
	jmp	copyb

* update_elroy ($20D7): once orange is out, Blinky speeds up in two steps
* as the pills run down.
update_elroy
	lda	substate+3
	beq	:ret
	lda	#$F4
	sec
	sbc	dots_eaten
	sta	T0
	lda	cruise_elroy_1
	bne	:e2
	lda	T0
	cmp	elroy1_pill_threshold
	beq	:set1
	bcs	:ret
:set1	lda	#1
	sta	cruise_elroy_1
:e2	lda	cruise_elroy_2
	bne	:ret
	lda	T0
	cmp	elroy2_pill_threshold
	beq	:set2
	bcs	:ret
:set2	lda	#1
	sta	cruise_elroy_2
:ret	rts
