*
* lower_sound.s: the arcade's three WSG voices on DOC oscillators 0-2
* (make iigs-lower). Put after lower_host.s, which defines GAME.
*
* SoundInit gives each of the eight PROM waves a 4 KB DOC table at
* $8000 + wave * $1000, one cycle with each sample repeated 128 times
* (iigs/wave_data.s, py/gen_wave_data.py). A free-running oscillator
* wraps one entry short of its table, which at 128 entries per sample
* is inaudible. It enables 4 oscillators (the scan rate the frequency
* tables are built for, about 149 kHz) and starts 0-2 free-running at
* volume 0; 3 stays halted. After each game frame LowerSound reads the
* voice registers at $5040 in the game bank and writes the wave page,
* frequency and volume that changed:
*
*   wave   $5045+5v & 7, * $10 + $80 -> DOC $80+v
*   freq   nibbles $5050+5v+k        -> DOC $00+v / $20+v (sum of FreqNib,
*          saturating at $FFFF; voices 1 and 2 have no k = 0 nibble)
*   vol    $5055+5v * 16, 0 when $5001 bit 0 is clear -> DOC $40+v
*
* The oscillators never stop; a silent voice is volume 0.
*
	mx	%00

G_VOICE	equ	GAME+$5040
G_SOUND_ON	equ	GAME+$5001
DOC_WAVE_PAGE	equ	$80	; DOC RAM page of wave 0
DOC_TABLE_PAGES	equ	$10	; 4 KB per wave
DOC_SIZE_RES	equ	$23	; $C0+o: table size 4 (4 KB) << 3, resolution 3
WAVE_STRETCH	equ	128	; table bytes per sample
DOC_OSCS_E1	equ	$06	; $E1: (4 - 1) * 2, the SR of wave_data.s
VOL_SCALE_SH	equ	4	; DOC volume = WSG volume << 4
GLU_REGS	equ	$00	; SOUNDCTL: DOC registers, no auto-increment
GLU_RAM_INC	equ	$60	; SOUNDCTL: DOC RAM, auto-increment

SD_V	equ	$58	; voice = oscillator number
SD_X	equ	$5A	; voice * 5: its offset in the voice registers
SD_K	equ	$5C	; frequency nibble index
SD_T	equ	$5E
SD_ACC	equ	$60	; 32 bits: D in 24.8

* Load the waves, halt every oscillator, enable 4, start 0-2.
SoundInit
	php
	sep	#$20
	rep	#$10
	jsr	GluWait
	lda	>SYS_VOL
	and	#$0F
	ora	#GLU_RAM_INC
	sta	>SOUNDCTL
	lda	#0
	sta	>SOUNDADRL
	lda	#DOC_WAVE_PAGE
	sta	>SOUNDADRH
	ldy	#0			; WaveSamples index, 8 waves x 32
]smp	lda	|WaveSamples,y
	ldx	#WAVE_STRETCH
]rep	jsr	GluWait
	sta	>SOUNDDATA
	dex
	bne	]rep
	iny
	cpy	#8*32
	bne	]smp

	sei
	jsr	GluRegs
	ldy	#$A0+31
]halt	lda	#$01
	jsr	DocPoke
	dey
	cpy	#$A0
	bcs	]halt
	ldy	#$E1
	lda	#DOC_OSCS_E1
	jsr	DocPoke
	ldx	#2
]osc	txy
	lda	#0
	jsr	DocPoke			; $00+o: frequency low
	tya
	ora	#$20
	tay
	lda	#0
	jsr	DocPoke			; $20+o: frequency high
	tya
	eor	#$20!$40
	tay
	lda	#0
	jsr	DocPoke			; $40+o: volume
	tya
	eor	#$40!$C0
	tay
	lda	#DOC_SIZE_RES
	jsr	DocPoke			; $C0+o: 4 KB table, resolution 3
	tya
	eor	#$C0!$80
	tay
	lda	#DOC_WAVE_PAGE
	jsr	DocPoke			; $80+o: wave 0
	tya
	eor	#$80!$A0
	tay
	lda	#0
	jsr	DocPoke			; $A0+o: free-run, no IRQ, running
	dex
	bpl	]osc

	rep	#$30
	lda	#$FFFF			; never written, except freq saturating
	sta	|SndFreq
	sta	|SndFreq+2
	sta	|SndFreq+4
	sta	|SndVol
	sta	|SndVol+1
	sta	|SndWave
	sta	|SndWave+1
	sta	|SndOn
	ldx	#30
]sh	sta	|SndRegs,x
	dex
	dex
	bpl	]sh
	plp
	rts

* Mirror the voice registers into the DOC, writing what changed. With
* $5001 and $5044-$505F as last frame left them, the DOC is untouched.
LowerSound
	php
	rep	#$30
	sep	#$20
	lda	>G_SOUND_ON
	cmp	|SndOn
	bne	:chg
	rep	#$20
	ldx	#26
]same	lda	>G_VOICE+4,x
	cmp	|SndRegs+4,x
	bne	:chg
	dex
	dex
	bpl	]same
	plp
	rts
:chg	sei
	sep	#$20
	jsr	GluWait
	jsr	GluRegs
	rep	#$30
	stz	<SD_V
	stz	<SD_X
* The voice's nibbles are within the three words at $5050+5v.
]voice	ldx	<SD_X
	lda	>G_VOICE+$10,x
	cmp	|SndRegs+$10,x
	bne	:sum
	lda	>G_VOICE+$12,x
	cmp	|SndRegs+$12,x
	bne	:sum
	lda	>G_VOICE+$14,x
	cmp	|SndRegs+$14,x
	bne	:sum
	brl	:vol
:sum	lda	#$0080			; round D to nearest
	sta	<SD_ACC
	stz	<SD_ACC+2
	lda	<SD_V
	beq	:k
	lda	#1			; voices 1 and 2 start at nibble 1
:k	sta	<SD_K
]nib	lda	<SD_X
	clc
	adc	<SD_K
	tax
	lda	>G_VOICE+$10,x
	and	#$000F
	sta	<SD_T
	lda	<SD_K
	asl
	asl
	asl
	asl
	ora	<SD_T			; k * 16 + nibble
	asl
	asl
	tay
	lda	|FreqNib0,y
	clc
	adc	<SD_ACC
	sta	<SD_ACC
	lda	|FreqNib0+2,y
	adc	<SD_ACC+2
	sta	<SD_ACC+2
	inc	<SD_K
	lda	<SD_K
	cmp	#5
	bcc	]nib

	lda	<SD_V
	asl
	tax
	lda	<SD_ACC+2
	and	#$FF00
	beq	:fits
	lda	#$FFFF			; past 16 bits: saturate
	bra	:freq
:fits	lda	<SD_ACC+1
:freq	cmp	|SndFreq,x
	beq	:vol
	sta	|SndFreq,x
	sep	#$20
	ldy	<SD_V
	jsr	DocPoke			; $00+v: frequency low
	xba
	pha
	tya
	ora	#$20
	tay
	pla
	jsr	DocPoke			; $20+v: frequency high
	rep	#$20

:vol	ldx	<SD_X
	lda	#0
	sep	#$20
	lda	>G_SOUND_ON
	and	#$01
	beq	:setvol
	lda	>G_VOICE+$15,x
	and	#$0F
	asl
	asl
	asl
	asl
:setvol	ldx	<SD_V
	cmp	|SndVol,x
	beq	:wave
	sta	|SndVol,x
	pha
	txa
	ora	#$40
	tay
	pla
	jsr	DocPoke			; $40+v: volume

:wave	ldx	<SD_X
	lda	>G_VOICE+$05,x
	and	#$07
	asl
	asl
	asl
	asl				; * DOC_TABLE_PAGES
	clc
	adc	#DOC_WAVE_PAGE
	ldx	<SD_V
	cmp	|SndWave,x
	beq	:next
	sta	|SndWave,x
	pha
	txa
	ora	#$80
	tay
	pla
	jsr	DocPoke			; $80+v: wave page

:next	rep	#$30
	lda	<SD_X
	clc
	adc	#5
	sta	<SD_X
	inc	<SD_V
	lda	<SD_V
	cmp	#3
	bcs	:done
	jmp	]voice
:done	ldx	#26
]copy	lda	>G_VOICE+4,x
	sta	|SndRegs+4,x
	dex
	dex
	bpl	]copy
	sep	#$20
	lda	>G_SOUND_ON
	sta	|SndOn
	plp
	rts

* Quiet and halt oscillators 0-2 (on quit).
SoundOff
	php
	sei
	sep	#$20
	rep	#$10
	jsr	GluWait
	jsr	GluRegs
	ldx	#2
]o	txa
	ora	#$40
	tay
	lda	#0
	jsr	DocPoke			; $40+o: volume 0
	tya
	eor	#$40!$A0
	tay
	lda	#$01
	jsr	DocPoke			; $A0+o: halt
	dex
	bpl	]o
	plp
	rts

* M=8. SOUNDCTL to DOC registers at the system volume.
GluRegs
	lda	>SYS_VOL
	and	#$0F
	ora	#GLU_REGS
	sta	>SOUNDCTL
	rts

* M=8. Spin while the GLU is busy; A is kept.
GluWait
	pha
]b	lda	>SOUNDCTL
	bmi	]b
	pla
	rts

* M=8. DOC register Y (low byte) = A; A and Y are kept. SOUNDCTL is in
* register mode.
DocPoke
	pha
	jsr	GluWait
	tya
	sta	>SOUNDADRL
	pla
	sta	>SOUNDDATA
	rts

* Last values written per oscillator; $FF/$FFFF until SoundInit's
* first frame writes them all.
SndFreq	ds	6
SndVol	ds	3
SndWave	ds	3
* $5040-$505F and $5001 as of the last DOC update. The nibbles are 4
* bits, so the $FF fill never matches.
SndRegs	ds	32
SndOn	ds	2
