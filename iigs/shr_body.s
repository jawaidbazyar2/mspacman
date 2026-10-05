*
* SHR init + VBL (included from all.s)
*
* Shadowing ON → own SHR via bank $01:
*   pixels  $2000–$9CFF
*   SCB     $9D00–$9DFF  (one byte/scanline; low nibble = palette #)
*   palettes $9E00–$9FFF (16 palettes × 32 bytes; we use palette 0)
*

InitSHR
	php
	sep	#$30
	lda	#$C1
	sta	>NEWVIDEO
	sta	>TXTCLR
	lda	#BRD_VBL
	sta	>BORDCOLOR
* Normal SHR shadow on bank $01 (bit3=0). Bit6 clear — IOLC intact;
* BCK lives at BCK_PIXELS (static $04/2000 or GS/OS segment), not $01/A000.
* Soft-switches via $E0/$E1.
	lda	#$B7
	sta	>SHADOW
	rep	#$30
	lda	#$0000
	ldx	#SHR_PIXEL_BYTES-2
]clr	sta	>SHR_PIXELS,x
	dex
	dex
	bpl	]clr
* Zero PF backing strip (long BCK_PIXELS, stride S_BCK) before DrawMaze.
* Use CPX end (not BPL) — count is >$8000 so BPL would abort early.
	ldx	#0
]bck	sta	>BCK_PIXELS,x
	inx
	inx
	cpx	#BCK_CLEAR_BYTES
	bcc	]bck
* SCB: 320 mode, fill off, palette 0 for every scanline ($00)
	sep	#$30
	lda	#$00
	ldx	#0
]scb	sta	>SHR_SCB,x
	inx
	bne	]scb			; 256 bytes $9D00–$9DFF
	jsr	LoadPalette
	plp
	rts

LoadPalette
* Palette 0 at $01/9E00 (32 bytes). With shadowing on, do not poke $E1.
* |PalTable forces absolute (not DP): table may sit below $0100 in bank $02.
	php
	rep	#$30
	ldx	#0
]lp	lda	|PalTable,x
	sta	>SHR_PALETTE,x
	inx
	inx
	cpx	#32
	bcc	]lp
	plp
	rts

* PalTable lives in palette_data.s (put from all.s) — maze PROM #1D → pens 0–3

* A = arcade bank: maze wall pens ← its outline and fill (MazeBankRGB).
* DBR = the program bank.
SetMazePens
	php
	rep	#$30
	and	#$001F
	asl
	asl
	tax
	lda	|MazeBankRGB,x
	sta	>SHR_PALETTE+{MAZE_OUTLINE_PEN*2}
	lda	|MazeBankRGB+2,x
	sta	>SHR_PALETTE+{MAZE_FILL_PEN*2}
	plp
	rts

BlinkPowerPills
* Arcade #0C0D / j_9524: every POWER_FLASH_PERIOD frames the pills go off
* or back on. POWER_FLASH_CNT bit 7 is the off phase; ApplyDirty draws
* TILE_POWER cells blank while it is set, and every pill cell is queued.
	php
	sep	#$20
	lda	>POWER_FLASH_CNT
	inc
	sta	>POWER_FLASH_CNT
	and	#$7F
	cmp	#POWER_FLASH_PERIOD
	bne	:done
	lda	>POWER_FLASH_CNT
	and	#$80
	eor	#$80
	sta	>POWER_FLASH_CNT
	rep	#$30
	ldx	#0
	stx	<R_TY
]y	stz	<R_TX
]x	lda	>TILEMAP,x
	and	#$00FF
	cmp	#TILE_POWER
	bne	:nx
	phx
	lda	>DIRTY_COUNT
	asl
	tax
	sep	#$20
	lda	<R_TX
	sta	>DIRTY_LIST,x
	lda	<R_TY
	sta	>DIRTY_LIST+1,x
	rep	#$20
	lda	>DIRTY_COUNT
	inc
	sta	>DIRTY_COUNT
	plx
:nx	inx
	inc	<R_TX
	lda	<R_TX
	cmp	#PF_COLS
	bcc	]x
	inc	<R_TY
	lda	<R_TY
	cmp	#PF_ROWS
	bcc	]y
:done	plp
	rts

SetBorder
* A = color 0–15. Prefer $E0/C034 (Mega II path).
	do	GSOS_PROD
	rts
	else
	php
	sep	#$20
	and	#$0F
	sta	>BORDCOLOR
	plp
	rts
	fin

WaitVBL
* $E1/C019 bit7=1 during blank (TN #40).
	php
	sep	#$20
	lda	#BRD_VBL
	jsr	SetBorder
]w1	lda	>RDVBLBAR
	bmi	]w1			; while in VBL (bit7 set)
]w2	lda	>RDVBLBAR
	bpl	]w2			; while in active display (bit7 clear)
	plp
	rts
