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

WaitVBL
* Poll Mega II VBL ($C019 bit7). If the bit never toggles, time out
* so a stuck sense cannot hang the harness forever.
	php
	sep	#$20
	ldy	#$40
:outer	ldx	#$00
:w1	lda	>RDVBLBAR
	bpl	:gotlow
	dex
	bne	:w1
	dey
	bne	:outer
	bra	:done
:gotlow	ldy	#$40
:outer2	ldx	#$00
:w2	lda	>RDVBLBAR
	bmi	:done
	dex
	bne	:w2
	dey
	bne	:outer2
:done	plp
	rts
