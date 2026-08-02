*
* Tile / sprite render (included from all.s)
*

R_X            equ $028A00
R_Y            equ $028A02
R_TX           equ $028A04
R_TY           equ $028A06
R_TILE         equ $028A08
R_OFF          equ $028A0A
R_DEST         equ $028A0C
R_ROW          equ $028A0E
R_IDX          equ $028A10
R_CARRY        equ $028A12
R_TMP          equ $028A14
R_ACT          equ $028A16
R_BASE         equ $028A18
R_SAVE         equ $028A1A
R_BODY         equ $028A1C	; ACT_COLOR nibble for RemapBodyByte
R_BTMP         equ $028A1E
R_SORT         equ $028A20	; NUM_ACTORS actor indices, Y-sorted
R_SI           equ $028A28
R_SJ           equ $028A2A
R_YOFF         equ $028A2C	; ACT_Y or ACT_OY offset for SortActorsByY
* Bank $02 long base: >BANK2+field,x with X = ACTORS16 / SAVEUNDER16
BANK2          equ $020000
ACTORS16       equ $8400
SAVEUNDER16    equ $8500

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
* 3 bytes/row: word @0 then overlapped word @1 (covers 0–2, no 4th byte)
]tr	lda	>AST_TILES,x
	sta	$2000,y
	lda	>AST_TILES+1,x
	sta	$2001,y
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
* 3 bytes/row: word @0 + overlapped word @1 (no spill past cell)
]mc	lda	>AST_MAZE_CELLS,x
	sta	$2000,y
	lda	>AST_MAZE_CELLS+1,x
	sta	$2001,y
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

ActorYLow
* A = actor index. R_YOFF = ACT_Y or ACT_OY. Returns A = Y low; leaves M=8.
	rep	#$30
	and	#$00FF
	asl
	asl
	asl
	asl
	clc
	adc	#ACTORS16
	clc
	adc	>R_YOFF
	tax
	lda	>BANK2,x
	sep	#$30
	rts

SortActorsByY
* A = actor-field offset (ACT_Y or ACT_OY). Bubble-sort indices into R_SORT
* ascending by Y so top-of-screen sprites update first (beam race).
	php
	rep	#$30
	and	#$00FF
	sta	>R_YOFF
	sep	#$30
* Seed R_SORT[i] = i for all actors (must cover NUM_ACTORS, not hard-coded 4)
	ldx	#0
]seed	txa
	sta	>R_SORT,x
	inx
	cpx	#NUM_ACTORS
	bcc	]seed
	lda	#0
	sta	>R_SI
]si	lda	#0
	sta	>R_SJ
]sj	lda	>R_SJ
	tax
	lda	>R_SORT,x			; idx[j]
	jsr	ActorYLow
	sta	>R_BTMP
	lda	>R_SJ
	inc
	tax
	lda	>R_SORT,x			; idx[j+1]
	jsr	ActorYLow
	cmp	>R_BTMP
	bcs	:noswap
	lda	>R_SJ
	tax
	lda	>R_SORT,x
	sta	>R_CARRY
	lda	>R_SORT+1,x
	sta	>R_SORT,x
	lda	>R_CARRY
	sta	>R_SORT+1,x
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

EraseAllSprites
* Erase at ACT_OX/OY (old), top→bottom by ACT_OY.
	php
	rep	#$30
	lda	#ACT_OY
	jsr	SortActorsByY
	lda	#0
	sta	>R_SI
]e	sep	#$30
	lda	>R_SI
	tax
	lda	>R_SORT,x
	rep	#$30
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
* Draw at ACT_X/Y (new), top→bottom by ACT_Y.
	php
	rep	#$30
	lda	#ACT_Y
	jsr	SortActorsByY
	lda	#0
	sta	>R_SI
]d	sep	#$30
	lda	>R_SI
	tax
	lda	>R_SORT,x
	rep	#$30
	and	#$00FF
	jsr	DrawSprite
	lda	>R_SI
	inc
	sta	>R_SI
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
	lda	>R_SAVE
	tax
	lda	>R_DEST
	tay
* Unrolled 12×7: save-under → SHR. Words @0,2,4 + @5 per row (no 8th byte).
* X = SAVEUNDER16+…, Y = SHR offset; no per-row adc/tax/tay.
	lda	>BANK2,x
	sta	$2000,y
	lda	>BANK2+2,x
	sta	$2002,y
	lda	>BANK2+4,x
	sta	$2004,y
	lda	>BANK2+5,x
	sta	$2005,y
	lda	>BANK2+7,x
	sta	$2000+160,y
	lda	>BANK2+9,x
	sta	$2002+160,y
	lda	>BANK2+11,x
	sta	$2004+160,y
	lda	>BANK2+12,x
	sta	$2005+160,y
	lda	>BANK2+14,x
	sta	$2000+320,y
	lda	>BANK2+16,x
	sta	$2002+320,y
	lda	>BANK2+18,x
	sta	$2004+320,y
	lda	>BANK2+19,x
	sta	$2005+320,y
	lda	>BANK2+21,x
	sta	$2000+480,y
	lda	>BANK2+23,x
	sta	$2002+480,y
	lda	>BANK2+25,x
	sta	$2004+480,y
	lda	>BANK2+26,x
	sta	$2005+480,y
	lda	>BANK2+28,x
	sta	$2000+640,y
	lda	>BANK2+30,x
	sta	$2002+640,y
	lda	>BANK2+32,x
	sta	$2004+640,y
	lda	>BANK2+33,x
	sta	$2005+640,y
	lda	>BANK2+35,x
	sta	$2000+800,y
	lda	>BANK2+37,x
	sta	$2002+800,y
	lda	>BANK2+39,x
	sta	$2004+800,y
	lda	>BANK2+40,x
	sta	$2005+800,y
	lda	>BANK2+42,x
	sta	$2000+960,y
	lda	>BANK2+44,x
	sta	$2002+960,y
	lda	>BANK2+46,x
	sta	$2004+960,y
	lda	>BANK2+47,x
	sta	$2005+960,y
	lda	>BANK2+49,x
	sta	$2000+1120,y
	lda	>BANK2+51,x
	sta	$2002+1120,y
	lda	>BANK2+53,x
	sta	$2004+1120,y
	lda	>BANK2+54,x
	sta	$2005+1120,y
	lda	>BANK2+56,x
	sta	$2000+1280,y
	lda	>BANK2+58,x
	sta	$2002+1280,y
	lda	>BANK2+60,x
	sta	$2004+1280,y
	lda	>BANK2+61,x
	sta	$2005+1280,y
	lda	>BANK2+63,x
	sta	$2000+1440,y
	lda	>BANK2+65,x
	sta	$2002+1440,y
	lda	>BANK2+67,x
	sta	$2004+1440,y
	lda	>BANK2+68,x
	sta	$2005+1440,y
	lda	>BANK2+70,x
	sta	$2000+1600,y
	lda	>BANK2+72,x
	sta	$2002+1600,y
	lda	>BANK2+74,x
	sta	$2004+1600,y
	lda	>BANK2+75,x
	sta	$2005+1600,y
	lda	>BANK2+77,x
	sta	$2000+1760,y
	lda	>BANK2+79,x
	sta	$2002+1760,y
	lda	>BANK2+81,x
	sta	$2004+1760,y
	lda	>BANK2+82,x
	sta	$2005+1760,y
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
* Save-under then compiled ghost / fruit / Ms. Pac blit; no SPR_WORK / remap.
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
	jsr	ScreenXY
	lda	>R_ACT
	jsr	Mul84
	clc
	adc	#SAVEUNDER16
	sta	>R_SAVE
	lda	>R_SAVE
	tax
	lda	>R_DEST
	tay
* Unrolled 12×7 save-under capture (SHR → bank $02). Same layout as EraseSprite.
	lda	$2000,y
	sta	>BANK2,x
	lda	$2002,y
	sta	>BANK2+2,x
	lda	$2004,y
	sta	>BANK2+4,x
	lda	$2005,y
	sta	>BANK2+5,x
	lda	$2000+160,y
	sta	>BANK2+7,x
	lda	$2002+160,y
	sta	>BANK2+9,x
	lda	$2004+160,y
	sta	>BANK2+11,x
	lda	$2005+160,y
	sta	>BANK2+12,x
	lda	$2000+320,y
	sta	>BANK2+14,x
	lda	$2002+320,y
	sta	>BANK2+16,x
	lda	$2004+320,y
	sta	>BANK2+18,x
	lda	$2005+320,y
	sta	>BANK2+19,x
	lda	$2000+480,y
	sta	>BANK2+21,x
	lda	$2002+480,y
	sta	>BANK2+23,x
	lda	$2004+480,y
	sta	>BANK2+25,x
	lda	$2005+480,y
	sta	>BANK2+26,x
	lda	$2000+640,y
	sta	>BANK2+28,x
	lda	$2002+640,y
	sta	>BANK2+30,x
	lda	$2004+640,y
	sta	>BANK2+32,x
	lda	$2005+640,y
	sta	>BANK2+33,x
	lda	$2000+800,y
	sta	>BANK2+35,x
	lda	$2002+800,y
	sta	>BANK2+37,x
	lda	$2004+800,y
	sta	>BANK2+39,x
	lda	$2005+800,y
	sta	>BANK2+40,x
	lda	$2000+960,y
	sta	>BANK2+42,x
	lda	$2002+960,y
	sta	>BANK2+44,x
	lda	$2004+960,y
	sta	>BANK2+46,x
	lda	$2005+960,y
	sta	>BANK2+47,x
	lda	$2000+1120,y
	sta	>BANK2+49,x
	lda	$2002+1120,y
	sta	>BANK2+51,x
	lda	$2004+1120,y
	sta	>BANK2+53,x
	lda	$2005+1120,y
	sta	>BANK2+54,x
	lda	$2000+1280,y
	sta	>BANK2+56,x
	lda	$2002+1280,y
	sta	>BANK2+58,x
	lda	$2004+1280,y
	sta	>BANK2+60,x
	lda	$2005+1280,y
	sta	>BANK2+61,x
	lda	$2000+1440,y
	sta	>BANK2+63,x
	lda	$2002+1440,y
	sta	>BANK2+65,x
	lda	$2004+1440,y
	sta	>BANK2+67,x
	lda	$2005+1440,y
	sta	>BANK2+68,x
	lda	$2000+1600,y
	sta	>BANK2+70,x
	lda	$2002+1600,y
	sta	>BANK2+72,x
	lda	$2004+1600,y
	sta	>BANK2+74,x
	lda	$2005+1600,y
	sta	>BANK2+75,x
	lda	$2000+1760,y
	sta	>BANK2+77,x
	lda	$2002+1760,y
	sta	>BANK2+79,x
	lda	$2004+1760,y
	sta	>BANK2+81,x
	lda	$2005+1760,y
	sta	>BANK2+82,x
	lda	>R_ACT
	cmp	#FRUIT_ACTOR
	beq	:fruitBlit
	cmp	#PAC_ACTOR
	beq	:pacBlit
* Ghost: index = color_slot*16 + (ACT_SPR&7)*2 + (X&1)
	lda	>R_BASE
	tax
	lda	>BANK2+ACT_COLOR,x
	and	#$00FF
	sec
	sbc	#5
	lsr				; 5/7/9/11 → 0..3
	and	#$0003
	asl
	asl
	asl
	asl				; *16
	sta	>R_TMP
	lda	>BANK2+ACT_SPR,x
	and	#$0007
	asl				; frame*2
	sta	>R_OFF
	lda	>R_X
	and	#$0001
	ora	>R_OFF
	ora	>R_TMP
	asl				; word index
	tax
	lda	>R_DEST
	tay
	jsr	GhostBlitGo
	bra	:blitDone
:fruitBlit
* Fruit: index = (ACT_SPR&7)*2 + (X&1)
	lda	>R_BASE
	tax
	lda	>BANK2+ACT_SPR,x
	and	#$0007
	asl				; type*2
	sta	>R_OFF
	lda	>R_X
	and	#$0001
	ora	>R_OFF
	asl				; word index
	tax
	lda	>R_DEST
	tay
	jsr	FruitBlitGo
	bra	:blitDone
:pacBlit
* Ms. Pac: index = (ACT_SPR & $0F)*2 + (X&1); ACT_SPR = dir*3+mouth
	lda	>R_BASE
	tax
	lda	>BANK2+ACT_SPR,x
	and	#$000F
	asl				; slot*2
	sta	>R_OFF
	lda	>R_X
	and	#$0001
	ora	>R_OFF
	asl				; word index
	tax
	lda	>R_DEST
	tay
	jsr	MsPacBlitGo
:blitDone
	lda	>R_BASE
	tax
	sep	#$20
	lda	>BANK2+ACT_FLAGS,x
	ora	#$01
	sta	>BANK2+ACT_FLAGS,x
	plb
	plp
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
