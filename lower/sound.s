*
* sound.c: three effect channels and three song channels. The channel
* being run is at (SND_CH), its four frequency bytes at (SND_FQ), and
* its effect or song table at SND_TB. Routines return the volume in A.
*

VOLUME_TYPES	equ	$2F02	; jump table for the 16 envelope types
NOTE_DURATIONS	equ	$3BB0	; frames per note, by bits 7-5
NOTE_FREQS	equ	$3BB8	; base frequency, by bits 3-0
EFFECTS_CH1	equ	$3B30	; 8 bytes per effect bit
EFFECTS_CH2	equ	$3B40
EFFECTS_CH3	equ	$3B80
SONGS_CH1	equ	$9685	; song pointers per channel
SONGS_CH2	equ	$967D
SONGS_CH3	equ	$968D

* SoundChannel offsets. e: effects, w: songs.
SN_NUM	equ	0
SN_CUR	equ	2
SN_SHAPE	equ	3	; e
SN_SEL	equ	3	; w
SN_BASE	equ	4	; e
SN_OCT	equ	4	; w
SN_STEP	equ	5	; e
SN_LEN	equ	6	; e
SN_PTR	equ	6	; w: word
SN_RSTEP	equ	7	; e
SN_REPS	equ	8	; e
SN_VOL0	equ	9
SN_VSTEP	equ	10	; e
SN_TYPE	equ	11
SN_DUR	equ	12
SN_DIR	equ	13
SN_FREQ	equ	14
SN_VOL	equ	15

SND_CH	equ	$48	; word: the channel
SND_FQ	equ	$4A	; word: its frequency bytes
SND_TB	equ	$4C	; word: its table
SND_BIT	equ	$4E	; top_bit: the bit
SND_IDX	equ	$4F	; top_bit: its index
SND_F	equ	$50	; word: set_freq's frequency
SND_SH	equ	$52	; set_shifted_freq's shift
SND_NOTE	equ	$53	; play_note's note

* silence -> A 0: stop the channel's sound.
silence
	ldy	#SN_CUR
	lda	(SND_CH),y
	beq	:z
	lda	#0
	sta	(SND_CH),y
	ldy	#SN_DIR
	sta	(SND_CH),y
	iny
	sta	(SND_CH),y
	iny
	sta	(SND_CH),y
	ldy	#0
	sta	(SND_FQ),y
	iny
	sta	(SND_FQ),y
	iny
	sta	(SND_FQ),y
	iny
	sta	(SND_FQ),y
:z	lda	#0
	rts

* fade -> A: the volume down one, stopping at 0.
fade
	ldy	#SN_VOL
	lda	(SND_CH),y
	and	#$0F
	beq	:z
	dec
	sta	(SND_CH),y
:z	rts

* envelope -> A: the channel's envelope type. Types 3 and up are dead
* in Ms. Pac-Man; 5-15 point at bare RETs, leaving the low byte of the
* address as the volume.
envelope
	ldy	#SN_TYPE
	lda	(SND_CH),y
	asl
	rep	#$20
	and	#$00FF
	tax
	lda	|VOLUME_TYPES,x
	cmp	#$2F22
	beq	:hold
	cmp	#$2F26
	beq	:f1
	cmp	#$2F2B
	beq	:f2
	cmp	#$2F3C
	beq	:f3
	cmp	#$2F43
	beq	:f4
	sep	#$20
	rts
:hold	sep	#$20
:keep	ldy	#SN_VOL
	lda	(SND_CH),y
	rts
:f1	sep	#$20
	jmp	fade
:f2	sep	#$20
	lda	SOUND_COUNTER
	and	#$01
	bne	:keep
	jmp	fade
:f3	sep	#$20
	lda	SOUND_COUNTER
	and	#$03
	bne	:keep
	jmp	fade
:f4	sep	#$20
	lda	SOUND_COUNTER
	and	#$07
	bne	:keep
	jmp	fade

* swap_nibbles(A) -> A.
swap_nibbles
	asl
	adc	#$80
	rol
	asl
	adc	#$80
	rol
	rts

* set_freq: SND_F as the voice's four nibble bytes, each also keeping
* the other nibble.
set_freq
	lda	SND_F
	ldy	#0
	sta	(SND_FQ),y
	jsr	swap_nibbles
	iny
	sta	(SND_FQ),y
	lda	SND_F+1
	iny
	sta	(SND_FQ),y
	jsr	swap_nibbles
	iny
	sta	(SND_FQ),y
	jmp	envelope

* set_shifted_freq(base in A, shift in SND_SH).
set_shifted_freq
	sta	SND_F
	stz	SND_F+1
:l	lda	SND_SH
	beq	:go
	dec	SND_SH
	rep	#$20
	asl	SND_F
	sep	#$20
	bra	:l
:go	jmp	set_freq

* song_freq: a note's frequency; note bit 4 raises it an octave.
song_freq
	ldy	#SN_DIR
	lda	(SND_CH),y
	and	#$10
	beq	:n
	lda	#1
:n	ldy	#SN_OCT
	clc
	adc	(SND_CH),y
	sta	SND_SH
	ldy	#SN_FREQ
	lda	(SND_CH),y
	jmp	set_shifted_freq

* play_note(note in A): bits 7-5 the duration; bits 4-0 the pitch, or
* 0 to hold the previous one.
play_note
	sta	SND_NOTE
	and	#$1F
	beq	:keep
	lda	SND_NOTE
	ldy	#SN_DIR
	sta	(SND_CH),y
:keep	ldy	#SN_TYPE
	lda	(SND_CH),y
	and	#$08
	beq	:v0
	lda	#0
	bra	:sv
:v0	ldy	#SN_VOL0
	lda	(SND_CH),y
:sv	ldy	#SN_VOL
	sta	(SND_CH),y
	lda	SND_NOTE
	lsr
	lsr
	lsr
	lsr
	lsr
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	|NOTE_DURATIONS,x
	ldy	#SN_DUR
	sta	(SND_CH),y
	lda	SND_NOTE
	and	#$1F
	beq	:sf
	lda	SND_NOTE
	and	#$0F
	rep	#$20
	and	#$00FF
	tax
	sep	#$20
	lda	|NOTE_FREQS,x
	ldy	#SN_FREQ
	sta	(SND_CH),y
:sf	jmp	song_freq

* song_byte -> A: the next song byte.
song_byte
	ldy	#SN_PTR
	rep	#$20
	lda	(SND_CH),y
	tax
	inc
	sta	(SND_CH),y
	sep	#$20
	lda	|$0000,x
	rts

* run_song(p in X): song bytes until a note plays. $F0 jump, $F1
* select, $F2 octave, $F3 volume, $F4 type, $FF end (the bytes after
* it still run); $F5-$FE do nothing.
run_song
	ldy	#SN_PTR
	rep	#$20
	txa
	sta	(SND_CH),y
	sep	#$20
:loop	jsr	song_byte
	cmp	#$F0
	bcs	:cmd
	jmp	play_note
:cmd	bne	:f1
	ldy	#SN_PTR
	rep	#$20
	lda	(SND_CH),y
	tax
	lda	|$0000,x
	sta	(SND_CH),y
	sep	#$20
	bra	:loop
:f1	cmp	#$F1
	bne	:f2
	jsr	song_byte
	ldy	#SN_SEL
	sta	(SND_CH),y
	bra	:loop
:f2	cmp	#$F2
	bne	:f3
	jsr	song_byte
	ldy	#SN_OCT
	sta	(SND_CH),y
	bra	:loop
:f3	cmp	#$F3
	bne	:f4
	jsr	song_byte
	ldy	#SN_VOL0
	sta	(SND_CH),y
	bra	:loop
:f4	cmp	#$F4
	bne	:ff
	jsr	song_byte
	ldy	#SN_TYPE
	sta	(SND_CH),y
	bra	:loop
:ff	cmp	#$FF
	bne	:loop
	ldy	#SN_CUR
	lda	(SND_CH),y
	eor	#$FF
	ldy	#SN_NUM
	and	(SND_CH),y
	sta	(SND_CH),y
	jsr	silence
	bra	:loop

* song_start(index in A) -> X: bit 0 the start song; bit 1 the
* intermission tune, by level.
song_start
	cmp	#1
	bne	:z
	lda	level_number
	cmp	#1
	beq	:w1
	cmp	#4
	beq	:w2
	lda	#6
	bra	:w
:w1	lda	#2
	bra	:w
:w2	lda	#4
	bra	:w
:z	lda	#0
:w	rep	#$20
	and	#$00FF
	clc
	adc	SND_TB
	tax
	lda	|$0000,x
	tax
	sep	#$20
	rts

* top_bit(mask in A) -> A, SND_BIT: the highest set bit of a nonzero
* mask; SND_IDX its index.
top_bit
	sta	T0
	lda	#$80
	sta	SND_BIT
	lda	#7
	sta	SND_IDX
:l	lda	T0
	and	SND_BIT
	bne	:d
	lsr	SND_BIT
	dec	SND_IDX
	bra	:l
:d	lda	SND_BIT
	rts

* song_channel -> A: one song channel.
song_channel
	lda	(SND_CH)
	bne	:go
	jmp	silence
:go	jsr	top_bit
	ldy	#SN_CUR
	and	(SND_CH),y
	bne	:same
	lda	SND_BIT
	sta	(SND_CH),y
	lda	SND_IDX
	jsr	song_start
	jmp	run_song
:same	ldy	#SN_DUR
	lda	(SND_CH),y
	dec
	sta	(SND_CH),y
	beq	:next
	jmp	song_freq
:next	ldy	#SN_PTR
	rep	#$20
	lda	(SND_CH),y
	tax
	sep	#$20
	jmp	run_song

* sweep_freq -> A: step the frequency, then shift by the octave.
sweep_freq
	ldy	#SN_FREQ
	lda	(SND_CH),y
	ldy	#SN_STEP
	clc
	adc	(SND_CH),y
	ldy	#SN_FREQ
	sta	(SND_CH),y
	pha
	ldy	#SN_SHAPE
	lda	(SND_CH),y
	and	#$70
	lsr
	lsr
	lsr
	lsr
	sta	SND_SH
	pla
	jmp	set_shifted_freq

* load_effect(index in A): copy the effect's 8 table bytes and set up
* its first sweep.
load_effect
	asl
	asl
	asl
	rep	#$20
	and	#$00FF
	clc
	adc	SND_TB
	tax
	sep	#$20
	ldy	#SN_SHAPE
:c	lda	|$0000,x
	sta	(SND_CH),y
	inx
	iny
	cpy	#SN_SHAPE+8
	bcc	:c
	ldy	#SN_LEN
	lda	(SND_CH),y
	and	#$7F
	ldy	#SN_DUR
	sta	(SND_CH),y
	ldy	#SN_BASE
	lda	(SND_CH),y
	ldy	#SN_FREQ
	sta	(SND_CH),y
	ldy	#SN_VOL0
	lda	(SND_CH),y
	lsr
	lsr
	lsr
	lsr
	ldy	#SN_TYPE
	sta	(SND_CH),y
	and	#$08
	bne	:r
	ldy	#SN_VOL0
	lda	(SND_CH),y
	ldy	#SN_VOL
	sta	(SND_CH),y
	lda	#0
	ldy	#SN_DIR
	sta	(SND_CH),y
:r	rts

* effect_channel -> A: one effect channel. At the end of a sweep the
* last repeat clears the request; a back-and-forth effect reverses its
* step every sweep.
effect_channel
:loop	lda	(SND_CH)
	bne	:go
	jmp	silence
:go	jsr	top_bit
	ldy	#SN_CUR
	and	(SND_CH),y
	bne	:have
	lda	SND_BIT
	sta	(SND_CH),y
	lda	SND_IDX
	jsr	load_effect
:have	ldy	#SN_DUR
	lda	(SND_CH),y
	dec
	sta	(SND_CH),y
	beq	:end
	jmp	sweep_freq
:end	ldy	#SN_REPS
	lda	(SND_CH),y
	beq	:again
	dec
	sta	(SND_CH),y
	bne	:again
	lda	SND_BIT
	eor	#$FF
	and	(SND_CH)
	sta	(SND_CH)
	bra	:loop
:again	ldy	#SN_LEN
	lda	(SND_CH),y
	and	#$7F
	ldy	#SN_DUR
	sta	(SND_CH),y
	ldy	#SN_LEN
	lda	(SND_CH),y
	bpl	:fwd
	ldy	#SN_STEP
	lda	(SND_CH),y
	eor	#$FF
	inc
	sta	(SND_CH),y
	ldy	#SN_DIR
	lda	(SND_CH),y
	and	#$01
	bne	:back
	lda	(SND_CH),y
	ora	#$01
	sta	(SND_CH),y
	jmp	sweep_freq
:back	lda	(SND_CH),y
	and	#$FE
	sta	(SND_CH),y
:fwd	ldy	#SN_BASE
	lda	(SND_CH),y
	ldy	#SN_RSTEP
	clc
	adc	(SND_CH),y
	ldy	#SN_BASE
	sta	(SND_CH),y
	ldy	#SN_FREQ
	sta	(SND_CH),y
	ldy	#SN_VOL0
	lda	(SND_CH),y
	ldy	#SN_VSTEP
	clc
	adc	(SND_CH),y
	ldy	#SN_VOL0
	sta	(SND_CH),y
	tax
	ldy	#SN_TYPE
	lda	(SND_CH),y
	and	#$08
	bne	:nv
	txa
	ldy	#SN_VOL
	sta	(SND_CH),y
:nv	jmp	sweep_freq

* sound_effects ($2D0C): the three effect channels.
sound_effects
	ldx	#effect
	stx	SND_CH
	ldx	#CH1_FREQ0
	stx	SND_FQ
	ldx	#EFFECTS_CH1
	stx	SND_TB
	jsr	effect_channel
	sta	CH1_VOL
	ldx	#effect+effect_SIZE
	stx	SND_CH
	ldx	#CH2_FREQ1
	stx	SND_FQ
	ldx	#EFFECTS_CH2
	stx	SND_TB
	jsr	effect_channel
	sta	CH2_VOL
	ldx	#effect+effect_SIZE+effect_SIZE
	stx	SND_CH
	ldx	#CH3_FREQ1
	stx	SND_FQ
	ldx	#EFFECTS_CH3
	stx	SND_TB
	jsr	effect_channel
	sta	CH3_VOL
	stz	CH1_FREQ4
	rts

* sound_songs ($2CC1 -> $9797): intermission sprites, then the three
* song channels. A song's volume replaces the effect's only while the
* song plays. T8 the volume.
sound_songs
	lda	intermission_flag
	beq	:nc
	ldx	#cutscene_sprite
	ldy	#sprite+2
	lda	#12
	jsr	copyb
:nc	lda	player_number
	and	dip_cocktail
	beq	:ch
	lda	sprite+10
	cmp	#$3F
	bne	:ch
	lda	#$FF
	sta	sprite+10
:ch	ldx	#wave
	stx	SND_CH
	ldx	#CH1_FREQ0
	stx	SND_FQ
	ldx	#SONGS_CH1
	stx	SND_TB
	jsr	song_channel
	sta	T8
	lda	(SND_CH)
	beq	:c2
	lda	T8
	sta	CH1_VOL
:c2	ldx	#wave+wave_SIZE
	stx	SND_CH
	ldx	#CH2_FREQ1
	stx	SND_FQ
	ldx	#SONGS_CH2
	stx	SND_TB
	jsr	song_channel
	sta	T8
	lda	(SND_CH)
	beq	:c3
	lda	T8
	sta	CH2_VOL
:c3	ldx	#wave+wave_SIZE+wave_SIZE
	stx	SND_CH
	ldx	#CH3_FREQ1
	stx	SND_FQ
	ldx	#SONGS_CH3
	stx	SND_TB
	jsr	song_channel
	sta	T8
	lda	(SND_CH)
	beq	:done
	lda	T8
	sta	CH3_VOL
:done	rts
