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
* Bank $02 long base: >BANK2+field,x with X = ACTORS16 / SAVEUNDER16
BANK2          equ $020000
ACTORS16       equ $7400
SAVEUNDER16    equ $7500

CopyMaze
	php
	rep	#$30
	ldx	#0
]c	lda	>AST_MAZE,x
	sta	>TILEMAP,x
	inx
	inx
	cpx	#868
	bcc	]c
	lda	#0
	sta	>DIRTY_COUNT
	lda	#0
	sta	>EAT_INDEX
	plp
	rts

Mul84
	sta	>R_TMP
	asl
	asl
	sta	>R_OFF
	lda	>R_TMP
	asl
	asl
	asl
	asl
	clc
	adc	>R_OFF
	sta	>R_OFF
	lda	>R_TMP
	asl
	asl
	asl
	asl
	asl
	asl
	clc
	adc	>R_OFF
	rts

Mul18
	sta	>R_TMP
	asl
	sta	>R_OFF
	lda	>R_TMP
	asl
	asl
	asl
	asl
	clc
	adc	>R_OFF
	rts

ScreenXY
	lda	>R_Y
	asl
	asl
	asl
	asl
	asl
	sta	>R_OFF
	lda	>R_Y
	asl
	asl
	asl
	asl
	asl
	asl
	asl
	clc
	adc	>R_OFF
	sta	>R_DEST
	lda	>R_X
	lsr
	clc
	adc	>R_DEST
	sta	>R_DEST
	rts

GenOddSprites
	php
	rep	#$30
	lda	#0
	sta	>R_IDX
]spr	lda	>R_IDX
	jsr	Mul84
	sta	>R_OFF
	lda	#12
	sta	>R_ROW
]row	jsr	ShiftOneRow
	lda	>R_OFF
	clc
	adc	#7
	sta	>R_OFF
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]row
	lda	>R_IDX
	inc
	sta	>R_IDX
	lda	>R_IDX
	cmp	#64
	bcc	]spr
	plp
	rts

ShiftOneRow
	php
	rep	#$30			; 16-bit A/X to fetch offset
	lda	>R_OFF
	tax
	sep	#$20			; 8-bit A for pixel work; X stays 16-bit
	lda	#0
	sta	>R_CARRY
	ldy	#7
]p	lda	>AST_SPR_EVEN,x
	pha
	lda	>R_CARRY
	asl
	asl
	asl
	asl
	sta	>R_TMP
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	ora	>R_TMP
	sta	>AST_SPR_ODD,x
	pla
	and	#$0F
	sta	>R_CARRY
	inx
	dey
	bne	]p
	rep	#$20
	lda	>R_OFF
	tax
	sep	#$20
	lda	#0
	sta	>R_CARRY
	ldy	#7
]m	lda	>AST_MSK_EVEN,x
	pha
	lda	>R_CARRY
	asl
	asl
	asl
	asl
	sta	>R_TMP
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	ora	>R_TMP
	sta	>AST_MSK_ODD,x
	pla
	and	#$0F
	sta	>R_CARRY
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
	lda	>R_TX
	asl
	clc
	adc	>R_TX
	asl
	clc
	adc	#PF_ORIGIN_X
	sta	>R_X
	lda	>R_TY
	asl
	clc
	adc	>R_TY
	asl
	clc
	adc	#PF_ORIGIN_Y
	sta	>R_Y
	jsr	ScreenXY
	lda	>R_TILE
	and	#$00FF
	jsr	Mul18
	tax
	lda	#6
	sta	>R_ROW
	lda	>R_DEST
	tay
* 8-bit stores — 16-bit sta would write a 4th byte past each 6px tile
]tr	sep	#$20
	lda	>AST_TILES,x
	sta	$2000,y
	lda	>AST_TILES+1,x
	sta	$2001,y
	lda	>AST_TILES+2,x
	sta	$2002,y
	rep	#$20
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#SHR_ROW_BYTES
	tay
	lda	>R_ROW
	dec
	sta	>R_ROW
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
	sta	>R_TY
]my	lda	#0
	sta	>R_TX
]mx	lda	>R_TX
	asl
	clc
	adc	>R_TX
	asl
	clc
	adc	#PF_ORIGIN_X
	sta	>R_X
	lda	>R_TY
	asl
	clc
	adc	>R_TY
	asl
	clc
	adc	#PF_ORIGIN_Y
	sta	>R_Y
	jsr	ScreenXY
	lda	>R_TY
	asl
	asl
	asl
	asl
	asl
	sta	>R_TMP
	lda	>R_TY
	asl
	asl
	sta	>R_OFF
	lda	>R_TMP
	sec
	sbc	>R_OFF
	clc
	adc	>R_TX
	jsr	Mul18
	tax
	lda	#6
	sta	>R_ROW
	lda	>R_DEST
	tay
* 8-bit stores — 16-bit sta spills 2px past the rightmost column
]mc	sep	#$20
	lda	>AST_MAZE_CELLS,x
	sta	$2000,y
	lda	>AST_MAZE_CELLS+1,x
	sta	$2001,y
	lda	>AST_MAZE_CELLS+2,x
	sta	$2002,y
	rep	#$20
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#SHR_ROW_BYTES
	tay
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]mc
	lda	>R_TX
	inc
	sta	>R_TX
	lda	>R_TX
	cmp	#28
	bcs	:ny
	brl	]mx
:ny	lda	>R_TY
	inc
	sta	>R_TY
	lda	>R_TY
	cmp	#31
	bcs	:mdone
	brl	]my
:mdone	plb
	plp
	rts

EraseAllSprites
* Erase at ACT_OX/OY (old / last drawn).
	php
	rep	#$30
	lda	#NUM_ACTORS-1
	sta	>R_ACT
]e	lda	>R_ACT
	jsr	EraseSprite
	lda	>R_ACT
	dec
	sta	>R_ACT
	bpl	]e
	plp
	rts

DrawAllSprites
* Draw at ACT_X/Y (new).
	php
	rep	#$30
	lda	#0
	sta	>R_ACT
]d	lda	>R_ACT
	jsr	DrawSprite
	lda	>R_ACT
	inc
	sta	>R_ACT
	cmp	#NUM_ACTORS
	bcc	]d
	plp
	rts

CopySpritePos
* After draw: old ← new so next erase hits the on-screen pose.
	php
	rep	#$30
	lda	#0
	sta	>R_ACT
]c	lda	>R_ACT
	asl
	asl
	asl
	asl
	clc
	adc	#ACTORS16
	tax
	lda	>BANK2+ACT_X,x
	sta	>BANK2+ACT_OX,x
	lda	>BANK2+ACT_Y,x
	sta	>BANK2+ACT_OY,x
	lda	>R_ACT
	inc
	sta	>R_ACT
	cmp	#NUM_ACTORS
	bcc	]c
	plp
	rts

EraseSprite
* A = actor index — must save before PHB bank switch clobbers it
* Position from ACT_OX/OY (old).
	php
	rep	#$30
	sta	>R_ACT
	phb
	sep	#$20
	lda	#$01
	pha
	plb
	rep	#$30
	lda	>R_ACT
	asl
	asl
	asl
	asl
	clc
	adc	#ACTORS16
	sta	>R_BASE
	tax
	lda	>BANK2+ACT_FLAGS,x
	and	#$0001
	bne	:er
	plb
	plp
	rts
:er	lda	>BANK2+ACT_OX,x
	sta	>R_X
	lda	>BANK2+ACT_OY,x
	sta	>R_Y
	jsr	ScreenXY
	lda	>R_ACT
	jsr	Mul84
	clc
	adc	#SAVEUNDER16
	sta	>R_SAVE
	lda	#12
	sta	>R_ROW
	lda	>R_SAVE
	tax
	lda	>R_DEST
	tay
* 8-bit — 16-bit sta $2006,y would clobber the next screen byte
]er	sep	#$20
	lda	>BANK2,x
	sta	$2000,y
	lda	>BANK2+1,x
	sta	$2001,y
	lda	>BANK2+2,x
	sta	$2002,y
	lda	>BANK2+3,x
	sta	$2003,y
	lda	>BANK2+4,x
	sta	$2004,y
	lda	>BANK2+5,x
	sta	$2005,y
	lda	>BANK2+6,x
	sta	$2006,y
	rep	#$20
	txa
	clc
	adc	#7
	tax
	tya
	clc
	adc	#SHR_ROW_BYTES
	tay
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]er
	lda	>R_BASE
	tax
	sep	#$20
	lda	>BANK2+ACT_FLAGS,x
	and	#$FE
	sta	>BANK2+ACT_FLAGS,x
	plb
	plp
	rts

DrawSprite
* A = actor index — must save before PHB bank switch clobbers it
	php
	rep	#$30
	sta	>R_ACT
	phb
	sep	#$20
	lda	#$01
	pha
	plb
	rep	#$30
	lda	>R_ACT
	asl
	asl
	asl
	asl
	clc
	adc	#ACTORS16
	sta	>R_BASE
	tax
	lda	>BANK2+ACT_X,x
	sta	>R_X
	lda	>BANK2+ACT_Y,x
	sta	>R_Y
	lda	>BANK2+ACT_SPR,x
	and	#$00FF
	sta	>R_IDX
	lda	>BANK2+ACT_COLOR,x
	and	#$000F
	sta	>R_BODY
	jsr	ScreenXY
	lda	>R_ACT
	jsr	Mul84
	clc
	adc	#SAVEUNDER16
	sta	>R_SAVE
	lda	#12
	sta	>R_ROW
	lda	>R_SAVE
	tax
	lda	>R_DEST
	tay
* 8-bit save-under — 16-bit stores overlapped rows (byte 7 = next row)
]su	sep	#$20
	lda	$2000,y
	sta	>BANK2,x
	lda	$2001,y
	sta	>BANK2+1,x
	lda	$2002,y
	sta	>BANK2+2,x
	lda	$2003,y
	sta	>BANK2+3,x
	lda	$2004,y
	sta	>BANK2+4,x
	lda	$2005,y
	sta	>BANK2+5,x
	lda	$2006,y
	sta	>BANK2+6,x
	rep	#$20
	txa
	clc
	adc	#7
	tax
	tya
	clc
	adc	#SHR_ROW_BYTES
	tay
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]su
	lda	>R_IDX
	jsr	Mul84
	sta	>R_OFF
	lda	>R_X
	bit	#$0001
	bne	:oddDraw
	jsr	MaskedBlitEven
	bra	:mark
:oddDraw
	jsr	MaskedBlitOdd
:mark	lda	>R_BASE
	tax
	sep	#$20
	lda	>BANK2+ACT_FLAGS,x
	ora	#$01
	sta	>BANK2+ACT_FLAGS,x
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
:hi	sta	>R_CARRY
	lda	>R_BTMP
	and	#$0F
	cmp	#BODY_PEN
	bne	:loOk
	lda	>R_BODY
:loOk	ora	>R_CARRY
	plp
	rts

MaskedBlitEven
	rep	#$30
	lda	#12
	sta	>R_ROW
	lda	>R_OFF
	tax
	lda	>R_DEST
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
	adc	#SHR_ROW_BYTES-7
	tay
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]be
	rts

MaskByteE
	sep	#$20
	lda	>AST_MSK_EVEN,x
	eor	#$FF
	and	$2000,y
	sta	>R_TMP
	lda	>AST_SPR_EVEN,x
	jsr	RemapBodyByte
	sta	>R_BTMP
	lda	>AST_MSK_EVEN,x
	and	>R_BTMP
	ora	>R_TMP
	sta	$2000,y
	rep	#$20
	rts

MaskedBlitOdd
	rep	#$30
	lda	#12
	sta	>R_ROW
	lda	>R_OFF
	tax
	lda	>R_DEST
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
	adc	#SHR_ROW_BYTES-7
	tay
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]bo
	rts

MaskByteO
	sep	#$20
	lda	>AST_MSK_ODD,x
	eor	#$FF
	and	$2000,y
	sta	>R_TMP
	lda	>AST_SPR_ODD,x
	jsr	RemapBodyByte
	sta	>R_BTMP
	lda	>AST_MSK_ODD,x
	and	>R_BTMP
	ora	>R_TMP
	sta	$2000,y
	rep	#$20
	rts

ApplyDirty
	php
	rep	#$30
	lda	>DIRTY_COUNT
	beq	:adone
	sta	>R_ROW
	ldx	#0
]ad	lda	>DIRTY_LIST,x
	and	#$00FF
	sta	>R_TX
	lda	>DIRTY_LIST+1,x
	and	#$00FF
	sta	>R_TY
	phx
	lda	>R_TY
	asl
	asl
	asl
	asl
	asl
	sta	>R_TMP
	lda	>R_TY
	asl
	asl
	sta	>R_OFF
	lda	>R_TMP
	sec
	sbc	>R_OFF
	clc
	adc	>R_TX
	tax
	lda	>TILEMAP,x
	and	#$00FF
	sta	>R_TILE
	jsr	DrawTile
	plx
	inx
	inx
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]ad
	lda	#0
	sta	>DIRTY_COUNT
:adone	plp
	rts

DirtyEatDemo
	php
	rep	#$30
	lda	>FRAME_COUNT
	and	#$0007
	beq	:doEat
	plp
	rts
:doEat
	lda	>EAT_INDEX
	sta	>R_TMP
]find	lda	>R_TMP
	cmp	#868
	bcc	:chk
	plp
	rts
:chk	tax
	lda	>TILEMAP,x
	and	#$00FF
	cmp	#$0010
	beq	:eat
	lda	>R_TMP
	inc
	sta	>R_TMP
	bra	]find
:eat	sep	#$20
	lda	#$40
	sta	>TILEMAP,x
	rep	#$20
	lda	>R_TMP
	sta	>EAT_INDEX
	lda	>EAT_INDEX
	inc
	sta	>EAT_INDEX
	lda	>R_TMP
	sta	>R_OFF
	lda	#0
	sta	>R_TY
]div	lda	>R_OFF
	cmp	#28
	bcc	:got
	sec
	sbc	#28
	sta	>R_OFF
	lda	>R_TY
	inc
	sta	>R_TY
	bra	]div
:got	lda	>R_OFF
	sta	>R_TX
	lda	>DIRTY_COUNT
	asl
	tax
	sep	#$20
	lda	>R_TX
	sta	>DIRTY_LIST,x
	lda	>R_TY
	sta	>DIRTY_LIST+1,x
	rep	#$20
	lda	>DIRTY_COUNT
	inc
	sta	>DIRTY_COUNT
	plp
	rts
