*
* rng.c: the game's random numbers, and board.c lift_random_byte, the
* host generator the ROM's three `ld a,r` reads were replaced with.
*

* rom_random ($2A23): rng_rom_ptr = (ptr * 5 + 1) & $1FFF, then the ROM
* byte there. Reads/writes rng_rom_ptr_lo/hi. -> A.
rom_random
	rep	#$20
	lda	rng_rom_ptr_lo
	sta	T0
	asl
	asl
	clc
	adc	T0
	inc
	and	#$1FFF
	sta	rng_rom_ptr_lo
	tax
	sep	#$20
	lda	|$0000,x
	rts

* lift_random_byte: state = state * 1664525 + 1013904223 on the host
* block's 32-bit state, and its high byte. -> A.
* 1664525 = $0019660D, 1013904223 = $3C6EF35F.
lift_random_byte
	rep	#$20
	lda	HB_RAND+2	; high(state) * $660D, low 16 bits
	sta	T0
	lda	#$660D
	sta	T2
	jsr	mul16
	lda	T4
	sta	T12
	lda	HB_RAND		; low(state) * $0019, low 16 bits
	sta	T0
	lda	#$0019
	sta	T2
	jsr	mul16
	lda	T4
	clc
	adc	T12
	sta	T12
	lda	HB_RAND		; low(state) * $660D, all 32 bits
	sta	T0
	lda	#$660D
	sta	T2
	jsr	mul16
	lda	T4
	clc
	adc	#$F35F
	sta	HB_RAND
	lda	T6
	adc	#$3C6E
	clc
	adc	T12
	sta	HB_RAND+2
	sep	#$20
	lda	HB_RAND+3
	rts

* T0 (16) * T2 (16) -> T4..T7 (32). Called and returns with M=0.
* Changes T0 and Y.
mul16
	mx	%00
	stz	T4
	stz	T6
	ldy	#16
:bit	asl	T4
	rol	T6
	asl	T0
	bcc	:next
	clc
	lda	T4
	adc	T2
	sta	T4
	bcc	:next
	inc	T6
:next	dey
	bne	:bit
	rts
	mx	%10
