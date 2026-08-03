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
* Inhibit every shadow except SHR (bit3=0). Includes IOLC (bit6) so
* $01/A000–FFFF is RAM for BCK — must set this BEFORE clearing BCK or
* stores into $01/Cxxx hit I/O and wedge VBL. Soft-switches use $E0/$E1.
	lda	#$F7
	sta	>SHADOW
	rep	#$30
	lda	#$0000
	ldx	#SHR_PIXEL_BYTES-2
]clr	sta	>SHR_PIXELS,x
	dex
	dex
	bpl	]clr
* Zero PF backing strip ($01/A000, stride S_BCK) before DrawMaze.
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

BlinkPowerPills
* Arcade #0C0D / FLASHEN: every POWER_FLASH_PERIOD frames, toggle pen 14
* between pale (PalTable) and black. Pixels stay COL_POWER in SHR+BCK.
	php
	sep	#$20
	lda	>POWER_FLASH_CNT
	inc
	sta	>POWER_FLASH_CNT
	cmp	#POWER_FLASH_PERIOD
	bne	:done
	lda	#0
	sta	>POWER_FLASH_CNT
	rep	#$20
	lda	>SHR_PALETTE+28		; pen 14 word
	beq	:on
	lda	#0
	bra	:store
:on	lda	|PalTable+28		; full-bright pale
:store	sta	>SHR_PALETTE+28
:done	plp
	rts

SetBorder
* A = color 0–15. $E0/C034 (IOLC inhibited — not $00/C034).
	php
	sep	#$20
	and	#$0F
	sta	>BORDCOLOR
	plp
	rts

WaitVBL
* $E1/C019 bit7=1 during blank (TN #40). Required when IOLC inhibited.
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
