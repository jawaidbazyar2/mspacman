*
* Tile / sprite render (included from all.s)
*

R_X            equ $027A00
R_Y            equ $027A02
R_TX           equ $027A04
R_TY           equ $027A06
R_TILE         equ $027A08
R_OFF          equ $027A0A
R_DEST         equ $027A0C
R_ROW          equ $027A0E
R_IDX          equ $027A10
R_CARRY        equ $027A12
R_TMP          equ $027A14
R_ACT          equ $027A16
R_BASE         equ $027A18
R_SAVE         equ $027A1A
R_BODY         equ $027A1C	; ACT_COLOR nibble for RemapBodyByte
R_BTMP         equ $027A1E
R_SAFEY        equ $027A30	; scanline wait threshold (pixel Y)
R_SORT         equ $027A20	; 4 actor indices, Y-sorted
R_SI           equ $027A28
R_SJ           equ $027A2A

CopyMaze
	php
	rep	#$30
	ldx	#0
]c	lda	>$036600,x
	sta	>$027000,x
	inx
	inx
	cpx	#868
	bcc	]c
	lda	#0
	sta	>$027800
	lda	#0
	sta	>$027902
	plp
	rts

Mul84
	sta	>$027A14
	asl
	asl
	sta	>$027A0A
	lda	>$027A14
	asl
	asl
	asl
	asl
	clc
	adc	>$027A0A
	sta	>$027A0A
	lda	>$027A14
	asl
	asl
	asl
	asl
	asl
	asl
	clc
	adc	>$027A0A
	rts

Mul18
	sta	>$027A14
	asl
	sta	>$027A0A
	lda	>$027A14
	asl
	asl
	asl
	asl
	clc
	adc	>$027A0A
	rts

ScreenXY
	lda	>$027A02
	asl
	asl
	asl
	asl
	asl
	sta	>$027A0A
	lda	>$027A02
	asl
	asl
	asl
	asl
	asl
	asl
	asl
	clc
	adc	>$027A0A
	sta	>$027A0C
	lda	>$027A00
	lsr
	clc
	adc	>$027A0C
	sta	>$027A0C
	rts

GenOddSprites
	php
	rep	#$30
	lda	#0
	sta	>$027A10
]spr	lda	>$027A10
	jsr	Mul84
	sta	>$027A0A
	lda	#12
	sta	>$027A0E
]row	jsr	ShiftOneRow
	lda	>$027A0A
	clc
	adc	#7
	sta	>$027A0A
	lda	>$027A0E
	dec
	sta	>$027A0E
	bne	]row
	lda	>$027A10
	inc
	sta	>$027A10
	lda	>$027A10
	cmp	#64
	bcc	]spr
	plp
	rts

ShiftOneRow
	php
	rep	#$30			; 16-bit A/X to fetch offset
	lda	>$027A0A
	tax
	sep	#$20			; 8-bit A for pixel work; X stays 16-bit
	lda	#0
	sta	>$027A12
	ldy	#7
]p	lda	>$031200,x
	pha
	lda	>$027A12
	asl
	asl
	asl
	asl
	sta	>$027A14
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	ora	>$027A14
	sta	>$033C00,x
	pla
	and	#$0F
	sta	>$027A12
	inx
	dey
	bne	]p
	rep	#$20
	lda	>$027A0A
	tax
	sep	#$20
	lda	#0
	sta	>$027A12
	ldy	#7
]m	lda	>$032700,x
	pha
	lda	>$027A12
	asl
	asl
	asl
	asl
	sta	>$027A14
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	ora	>$027A14
	sta	>$035100,x
	pla
	and	#$0F
	sta	>$027A12
	inx
	dey
	bne	]m
	plp
	rts

DrawTile
	php
	phb
	sep	#$20
	lda	#$01
	pha
	plb
	rep	#$30
	lda	>$027A04
	asl
	clc
	adc	>$027A04
	asl
	clc
	adc	#76
	sta	>$027A00
	lda	>$027A06
	asl
	clc
	adc	>$027A06
	asl
	clc
	adc	#7
	sta	>$027A02
	jsr	ScreenXY
	lda	>$027A08
	and	#$00FF
	jsr	Mul18
	tax
	lda	#6
	sta	>$027A0E
	lda	>$027A0C
	tay
* 8-bit stores — 16-bit sta would write a 4th byte past each 6px tile
]tr	sep	#$20
	lda	>$030000,x
	sta	$2000,y
	lda	>$030001,x
	sta	$2001,y
	lda	>$030002,x
	sta	$2002,y
	rep	#$20
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#160
	tay
	lda	>$027A0E
	dec
	sta	>$027A0E
	bne	]tr
	plb
	plp
	rts

DrawMaze
* Blit pre-stitched per-cell 6x6 from AST_MAZE_CELLS (edge-repaired walls).
* Cells are already upright (CW + row^3); no rotate/flip here.
	php
	phb
	sep	#$20
	lda	#$01
	pha
	plb
	rep	#$30
	lda	#0
	sta	>$027A06
]my	lda	#0
	sta	>$027A04
]mx	lda	>$027A04
	asl
	clc
	adc	>$027A04
	asl
	clc
	adc	#76
	sta	>$027A00
	lda	>$027A06
	asl
	clc
	adc	>$027A06
	asl
	clc
	adc	#7
	sta	>$027A02
	jsr	ScreenXY
	lda	>$027A06
	asl
	asl
	asl
	asl
	asl
	sta	>$027A14
	lda	>$027A06
	asl
	asl
	sta	>$027A0A
	lda	>$027A14
	sec
	sbc	>$027A0A
	clc
	adc	>$027A04
	jsr	Mul18
	tax
	lda	#6
	sta	>$027A0E
	lda	>$027A0C
	tay
* 8-bit stores — 16-bit sta spills 2px past the rightmost column
]mc	sep	#$20
	lda	>$037000,x
	sta	$2000,y
	lda	>$037001,x
	sta	$2001,y
	lda	>$037002,x
	sta	$2002,y
	rep	#$20
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#160
	tay
	lda	>$027A0E
	dec
	sta	>$027A0E
	bne	]mc
	lda	>$027A04
	inc
	sta	>$027A04
	lda	>$027A04
	cmp	#28
	bcs	:ny
	brl	]mx
:ny	lda	>$027A06
	inc
	sta	>$027A06
	lda	>$027A06
	cmp	#31
	bcs	:mdone
	brl	]my
:mdone	plb
	plp
	rts

* Sort actor indices at R_SORT by ACT_Y ascending (beam-race order).
SortActorsByY
* Bubble-sort actor indices at $7A20 (bank $02 / DB) by ACT_Y.
* Merlin32 long addr is X-only — use abs,x with DB=$02.
	php
	sep	#$30
	lda	#0
	sta	>$027A20
	lda	#1
	sta	>$027A21
	lda	#2
	sta	>$027A22
	lda	#3
	sta	>$027A23
	lda	#0
	sta	>R_SI
]si	lda	#0
	sta	>R_SJ
]sj	lda	>R_SJ
	tax
	lda	$7A20,x			; idx[j]
	jsr	:yOf
	sta	>R_BTMP
	lda	>R_SJ
	inc
	tax
	lda	$7A20,x			; idx[j+1]
	jsr	:yOf
	cmp	>R_BTMP
	bcs	:noswap
	lda	>R_SJ
	tax
	lda	$7A20,x
	sta	>R_BTMP
	lda	$7A21,x
	sta	$7A20,x
	lda	>R_BTMP
	sta	$7A21,x
:noswap	lda	>R_SJ
	inc
	sta	>R_SJ
	cmp	#NUM_ACTORS-1
	bcc	]sj
	lda	>R_SI
	inc
	sta	>R_SI
	cmp	#NUM_ACTORS-1
	bcc	]si
	plp
	rts

:yOf	asl				; A=actor idx → ACT_Y low in A
	asl
	asl
	asl
	tax
	lda	$7402,x
	rts

EraseAllSprites
* Y-sorted + WaitBeamSafe so erase finishes before the beam hits each sprite.
	php
	rep	#$30
	jsr	SortActorsByY
	lda	#0
	sta	>R_SI
]e	sep	#$20
	lda	>R_SI
	tax
	lda	$7A20,x
	sta	>R_ACT
	rep	#$20
	and	#$00FF
	asl
	asl
	asl
	asl
	tax
	lda	>$020002,x		; ACT_Y
	sta	>R_SAFEY
	jsr	WaitBeamSafe
	lda	>R_ACT
	and	#$00FF
	jsr	EraseSprite
	lda	>R_SI
	inc
	sta	>R_SI
	cmp	#NUM_ACTORS
	bcc	]e
	plp
	rts

DrawAllSprites
	php
	rep	#$30
	jsr	SortActorsByY
	lda	#0
	sta	>R_SI
]d	sep	#$20
	lda	>R_SI
	tax
	lda	$7A20,x
	sta	>R_ACT
	rep	#$20
	and	#$00FF
	asl
	asl
	asl
	asl
	tax
	lda	>$020002,x
	sta	>R_SAFEY
	jsr	WaitBeamSafe
	lda	>R_ACT
	and	#$00FF
	jsr	DrawSprite
	lda	>R_SI
	inc
	sta	>R_SI
	cmp	#NUM_ACTORS
	bcc	]d
	plp
	rts

EraseSprite
* A = actor index — must save before PHB bank switch clobbers it
	php
	rep	#$30
	sta	>$027A16
	phb
	sep	#$20
	lda	#$01
	pha
	plb
	rep	#$30
	lda	>$027A16
	asl
	asl
	asl
	asl
	clc
	adc	#$7400
	sta	>$027A18
	tax
	lda	>$020009,x
	and	#$0001
	bne	:er
	plb
	plp
	rts
:er	lda	>$020000,x
	sta	>$027A00
	lda	>$020002,x
	sta	>$027A02
	jsr	ScreenXY
	lda	>$027A16
	jsr	Mul84
	clc
	adc	#$7500
	sta	>$027A1A
	lda	#12
	sta	>$027A0E
	lda	>$027A1A
	tax
	lda	>$027A0C
	tay
* 8-bit — 16-bit sta $2006,y would clobber the next screen byte
]er	sep	#$20
	lda	>$020000,x
	sta	$2000,y
	lda	>$020001,x
	sta	$2001,y
	lda	>$020002,x
	sta	$2002,y
	lda	>$020003,x
	sta	$2003,y
	lda	>$020004,x
	sta	$2004,y
	lda	>$020005,x
	sta	$2005,y
	lda	>$020006,x
	sta	$2006,y
	rep	#$20
	txa
	clc
	adc	#7
	tax
	tya
	clc
	adc	#160
	tay
	lda	>$027A0E
	dec
	sta	>$027A0E
	bne	]er
	lda	>$027A18
	tax
	sep	#$20
	lda	>$020009,x
	and	#$FE
	sta	>$020009,x
	plb
	plp
	rts

DrawSprite
* A = actor index — must save before PHB bank switch clobbers it
	php
	rep	#$30
	sta	>$027A16
	phb
	sep	#$20
	lda	#$01
	pha
	plb
	rep	#$30
	lda	>$027A16
	asl
	asl
	asl
	asl
	clc
	adc	#$7400
	sta	>$027A18
	tax
	lda	>$020000,x
	sta	>$027A00
	lda	>$020002,x
	sta	>$027A02
	lda	>$020008,x
	and	#$00FF
	sta	>$027A10
	lda	>$02000B,x		; ACT_COLOR
	and	#$000F
	sta	>R_BODY
	jsr	ScreenXY
	lda	>$027A16
	jsr	Mul84
	clc
	adc	#$7500
	sta	>$027A1A
	lda	#12
	sta	>$027A0E
	lda	>$027A1A
	tax
	lda	>$027A0C
	tay
* 8-bit save-under — 16-bit stores overlapped rows (byte 7 = next row)
]su	sep	#$20
	lda	$2000,y
	sta	>$020000,x
	lda	$2001,y
	sta	>$020001,x
	lda	$2002,y
	sta	>$020002,x
	lda	$2003,y
	sta	>$020003,x
	lda	$2004,y
	sta	>$020004,x
	lda	$2005,y
	sta	>$020005,x
	lda	$2006,y
	sta	>$020006,x
	rep	#$20
	txa
	clc
	adc	#7
	tax
	tya
	clc
	adc	#160
	tay
	lda	>$027A0E
	dec
	sta	>$027A0E
	bne	]su
	lda	>$027A10
	jsr	Mul84
	sta	>$027A0A
	lda	>$027A00
	bit	#$0001
	bne	:oddDraw
	jsr	MaskedBlitEven
	bra	:mark
:oddDraw
	jsr	MaskedBlitOdd
:mark	lda	>$027A18
	tax
	sep	#$20
	lda	>$020009,x
	ora	#$01
	sta	>$020009,x
	plb
	plp
	rts

* A = packed sprite byte; replace BODY_PEN ($6) nibbles with R_BODY.
RemapBodyByte
	php
	sep	#$20
	sta	>R_BTMP
	and	#$F0
	cmp	#$60			; BODY_PEN in high nibble
	bne	:hiOk
	lda	>R_BODY
	asl
	asl
	asl
	asl
	bra	:hi
:hiOk	lda	>R_BTMP
	and	#$F0
:hi	sta	>$027A12
	lda	>R_BTMP
	and	#$0F
	cmp	#BODY_PEN
	bne	:loOk
	lda	>R_BODY
:loOk	ora	>$027A12
	plp
	rts

MaskedBlitEven
	rep	#$30
	lda	#12
	sta	>$027A0E
	lda	>$027A0A
	tax
	lda	>$027A0C
	tay
]be	jsr	MaskByteE
	inx
	iny
	jsr	MaskByteE
	inx
	iny
	jsr	MaskByteE
	inx
	iny
	jsr	MaskByteE
	inx
	iny
	jsr	MaskByteE
	inx
	iny
	jsr	MaskByteE
	inx
	iny
	jsr	MaskByteE
	inx
	iny
	tya
	clc
	adc	#160-7
	tay
	lda	>$027A0E
	dec
	sta	>$027A0E
	bne	]be
	rts

MaskByteE
	sep	#$20
	lda	>$032700,x
	eor	#$FF
	and	$2000,y
	sta	>$027A14
	lda	>$031200,x
	jsr	RemapBodyByte
	sta	>R_BTMP
	lda	>$032700,x
	and	>R_BTMP
	ora	>$027A14
	sta	$2000,y
	rep	#$20
	rts

MaskedBlitOdd
	rep	#$30
	lda	#12
	sta	>$027A0E
	lda	>$027A0A
	tax
	lda	>$027A0C
	tay
]bo	jsr	MaskByteO
	inx
	iny
	jsr	MaskByteO
	inx
	iny
	jsr	MaskByteO
	inx
	iny
	jsr	MaskByteO
	inx
	iny
	jsr	MaskByteO
	inx
	iny
	jsr	MaskByteO
	inx
	iny
	jsr	MaskByteO
	inx
	iny
	tya
	clc
	adc	#160-7
	tay
	lda	>$027A0E
	dec
	sta	>$027A0E
	bne	]bo
	rts

MaskByteO
	sep	#$20
	lda	>$035100,x
	eor	#$FF
	and	$2000,y
	sta	>$027A14
	lda	>$033C00,x
	jsr	RemapBodyByte
	sta	>R_BTMP
	lda	>$035100,x
	and	>R_BTMP
	ora	>$027A14
	sta	$2000,y
	rep	#$20
	rts

ApplyDirty
	php
	rep	#$30
	lda	>$027800
	beq	:adone
	sta	>$027A0E
	ldx	#0
]ad	lda	>$027802,x
	and	#$00FF
	sta	>$027A04
	lda	>$027803,x
	and	#$00FF
	sta	>$027A06
	phx
	lda	>$027A06
	asl
	asl
	asl
	asl
	asl
	sta	>$027A14
	lda	>$027A06
	asl
	asl
	sta	>$027A0A
	lda	>$027A14
	sec
	sbc	>$027A0A
	clc
	adc	>$027A04
	tax
	lda	>$027000,x
	and	#$00FF
	sta	>$027A08
	jsr	DrawTile
	plx
	inx
	inx
	lda	>$027A0E
	dec
	sta	>$027A0E
	bne	]ad
	lda	#0
	sta	>$027800
:adone	plp
	rts

DirtyEatDemo
	php
	rep	#$30
	lda	>$027900
	and	#$0007
	beq	:doEat
	plp
	rts
:doEat
	lda	>$027902
	sta	>$027A14
]find	lda	>$027A14
	cmp	#868
	bcc	:chk
	plp
	rts
:chk	tax
	lda	>$027000,x
	and	#$00FF
	cmp	#$0010
	beq	:eat
	lda	>$027A14
	inc
	sta	>$027A14
	bra	]find
:eat	sep	#$20
	lda	#$40
	sta	>$027000,x
	rep	#$20
	lda	>$027A14
	sta	>$027902
	lda	>$027902
	inc
	sta	>$027902
	lda	>$027A14
	sta	>$027A0A
	lda	#0
	sta	>$027A06
]div	lda	>$027A0A
	cmp	#28
	bcc	:got
	sec
	sbc	#28
	sta	>$027A0A
	lda	>$027A06
	inc
	sta	>$027A06
	bra	]div
:got	lda	>$027A0A
	sta	>$027A04
	lda	>$027800
	asl
	tax
	sep	#$20
	lda	>$027A04
	sta	>$027802,x
	lda	>$027A06
	sta	>$027803,x
	rep	#$20
	lda	>$027800
	inc
	sta	>$027800
	plp
	rts
