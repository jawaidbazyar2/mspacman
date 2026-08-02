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
	lda	>SHADOW
	and	#$F7			; bit3=0 → SHR shadowing on
	sta	>SHADOW
	sta	>TXTCLR
	rep	#$30
	lda	#$0000
	ldx	#SHR_PIXEL_BYTES-2
]clr	sta	>SHR_PIXELS,x
	dex
	dex
	bpl	]clr
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

SetBorder
* A = color 0–15. Writes $00/C034 low nibble only (high ← 0; fine for demo).
	php
	sep	#$20
	and	#$0F
	sta	>BORDCOLOR
	plp
	rts

WaitVBL
* IIgs $C019: bit7=1 during blank (TN #40). Border black for slack time.
* Wait until OUT of VBL, then until INTO VBL (next blank leading edge).
* Do NOT time out past :w1 — that used to skip :w2 and drop frame sync.
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
