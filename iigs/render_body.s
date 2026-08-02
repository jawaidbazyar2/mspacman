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
* High DP (DP=$0000): Y-sort keys — actor records are never moved
DP_KEYI        equ $EA		; insertion: actor index being placed
DP_KEYY        equ $EB		; insertion: its Y
DP_YOFF        equ $EC		; word: ACT_Y or ACT_OY field offset
DP_I           equ $EE
DP_J           equ $EF
DP_SORT        equ $F0		; 6 bytes: actor indices, Y-ascending
DP_YKEY        equ $F6		; 6 bytes: Y low for actor 0..5 (by actor #)
* Bank $02 long base: >BANK2+field,x with X = ACTORS16
BANK2          equ $020000
ACTORS16       equ $8400

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

CopyBgToShr
* Word-copy $04/2000 → $01/2000 (32000 bytes). Level-start only.
	php
	rep	#$30
	ldx	#0
]c	lda	>BG_PIXELS,x
	sta	>SHR_PIXELS,x
	inx
	inx
	cpx	#SHR_PIXEL_BYTES
	bcc	]c
	plp
	rts

DrawTile
* Write tile to SHR ($01) and BG mirror ($04).
	php
	phb
	sep	#$20
	lda	#BANK_SHR
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
* Long,Y is not a 65816 mode — dual-write BG via long,X (X = dest).
]tr	lda	>AST_TILES,x
	sta	$2000,y
	sta	>R_BTMP
	lda	>AST_TILES+1,x
	sta	$2001,y
	sta	>R_TMP
	phx
	tyx
	lda	>R_BTMP
	sta	>BG_PIXELS,x
	lda	>R_TMP
	sta	>BG_PIXELS+1,x
	plx
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
* Blit pre-stitched per-cell 6x6 into BG mirror ($04), then copy to SHR ($01).
* Cells are already upright (CW + row^3); no rotate/flip here.
	php
	phb
	sep	#$20
	lda	#BANK_BG
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
	jsr	CopyBgToShr
	plp
	rts

SortActorsByY
* A = ACT_Y or ACT_OY field offset.
* Insertion-sort actor *indices* into DP_SORT (high DP) by that Y.
* Actor records stay put; DP_YKEY[i] = Y of actor i (lookup only).
	php
	rep	#$30
	and	#$00FF
	sta	<DP_YOFF
	sep	#$20
	lda	#BRD_SORT
	jsr	SetBorder
* One long Y read per actor → DP_YKEY; seed DP_SORT[i]=i
	sep	#$30
	ldx	#0
]bld	txa
	sta	<DP_I
	sta	<DP_SORT,x
	rep	#$30
	lda	<DP_I			; 16-bit clean (avoid B junk after rep)
	and	#$00FF
	asl
	asl
	asl
	asl
	clc
	adc	#ACTORS16
	clc
	adc	<DP_YOFF
	tax
	lda	>BANK2,x			; Y word
	sep	#$30
	ldx	<DP_I
	sta	<DP_YKEY,x			; low byte only
	inx
	cpx	#NUM_ACTORS
	bcc	]bld
* Insertion sort DP_SORT[1..n) by DP_YKEY[DP_SORT[]]
	lda	#1
]outer	sta	<DP_I
	tax
	lda	<DP_SORT,x
	sta	<DP_KEYI			; key index
	tay
	lda	<DP_YKEY,y
	sta	<DP_KEYY			; key Y
	lda	<DP_I
	sta	<DP_J			; j = i
]inner	lda	<DP_J
	beq	:place			; j == 0
	dec
	tax				; X = j-1
	lda	<DP_SORT,x
	tay
	lda	<DP_YKEY,y			; Y of SORT[j-1]
	cmp	<DP_KEYY
	bcc	:place			; SORT[j-1].Y < key → done
	beq	:place			; equal → stable
	ldx	<DP_J
	dex				; X = j-1
	lda	<DP_SORT,x
	inx				; X = j
	sta	<DP_SORT,x			; SORT[j] = SORT[j-1]
	dex
	stx	<DP_J			; j--
	bra	]inner
:place	lda	<DP_J
	tax
	lda	<DP_KEYI
	sta	<DP_SORT,x
	lda	<DP_I
	inc
	cmp	#NUM_ACTORS
	bcc	]outer
	plp
	rts

EraseAllSprites
* Erase at ACT_OX/OY (old), top→bottom by ACT_OY. (init / tools)
	php
	rep	#$30
	lda	#ACT_OY
	jsr	SortActorsByY
	sep	#$30
	ldx	#0
]e	lda	<DP_SORT,x
	phx
	rep	#$30
	and	#$00FF
	jsr	EraseSprite
	sep	#$30
	plx
	inx
	cpx	#NUM_ACTORS
	bcc	]e
	plp
	rts

DrawAllSprites
* Draw at ACT_X/Y (new), top→bottom by ACT_Y. (level start)
	php
	rep	#$30
	lda	#ACT_Y
	jsr	SortActorsByY
	sep	#$30
	ldx	#0
]d	lda	<DP_SORT,x
	phx
	rep	#$30
	and	#$00FF
	jsr	DrawSprite
	sep	#$30
	plx
	inx
	cpx	#NUM_ACTORS
	bcc	]d
	plp
	rts

RefreshAllSprites
* Per actor top→bottom using DP_SORT (filled before WaitVBL).
* Erase(old) then draw(new); closes upper holes before the beam.
	php
	sep	#$30
	ldx	#0
]r	lda	<DP_SORT,x
	phx
	rep	#$30
	and	#$00FF
	sta	>R_ACT
	jsr	EraseSprite
	lda	>R_ACT
	jsr	DrawSprite
	sep	#$30
	plx
	inx
	cpx	#NUM_ACTORS
	bcc	]r
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
* A = actor index. Position from ACT_OX/OY (old).
* Restore 14×12: long load from BG ($04) + abs,y store with DBR=$01.
* X = Y = dest (no absolute-long,Y mode).
	php
	rep	#$30
	sta	>R_ACT
	sep	#$20
	lda	#BRD_ERASE
	jsr	SetBorder
	phb
	lda	#BANK_SHR
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
	lda	>R_DEST
	tax
	tay
* Unrolled 12×7: BG → SHR. Words @0,2,4 + @5 per row (no 8th byte).
* |SHR_PIXELS forces abs (low 16 of $012000 → $2000) with DBR=$01.
	lda	>BG_PIXELS,x
	sta	|SHR_PIXELS,y
	lda	>BG_PIXELS+2,x
	sta	|SHR_PIXELS+2,y
	lda	>BG_PIXELS+4,x
	sta	|SHR_PIXELS+4,y
	lda	>BG_PIXELS+5,x
	sta	|SHR_PIXELS+5,y
	lda	>BG_PIXELS+160,x
	sta	|SHR_PIXELS+160,y
	lda	>BG_PIXELS+162,x
	sta	|SHR_PIXELS+162,y
	lda	>BG_PIXELS+164,x
	sta	|SHR_PIXELS+164,y
	lda	>BG_PIXELS+165,x
	sta	|SHR_PIXELS+165,y
	lda	>BG_PIXELS+320,x
	sta	|SHR_PIXELS+320,y
	lda	>BG_PIXELS+322,x
	sta	|SHR_PIXELS+322,y
	lda	>BG_PIXELS+324,x
	sta	|SHR_PIXELS+324,y
	lda	>BG_PIXELS+325,x
	sta	|SHR_PIXELS+325,y
	lda	>BG_PIXELS+480,x
	sta	|SHR_PIXELS+480,y
	lda	>BG_PIXELS+482,x
	sta	|SHR_PIXELS+482,y
	lda	>BG_PIXELS+484,x
	sta	|SHR_PIXELS+484,y
	lda	>BG_PIXELS+485,x
	sta	|SHR_PIXELS+485,y
	lda	>BG_PIXELS+640,x
	sta	|SHR_PIXELS+640,y
	lda	>BG_PIXELS+642,x
	sta	|SHR_PIXELS+642,y
	lda	>BG_PIXELS+644,x
	sta	|SHR_PIXELS+644,y
	lda	>BG_PIXELS+645,x
	sta	|SHR_PIXELS+645,y
	lda	>BG_PIXELS+800,x
	sta	|SHR_PIXELS+800,y
	lda	>BG_PIXELS+802,x
	sta	|SHR_PIXELS+802,y
	lda	>BG_PIXELS+804,x
	sta	|SHR_PIXELS+804,y
	lda	>BG_PIXELS+805,x
	sta	|SHR_PIXELS+805,y
	lda	>BG_PIXELS+960,x
	sta	|SHR_PIXELS+960,y
	lda	>BG_PIXELS+962,x
	sta	|SHR_PIXELS+962,y
	lda	>BG_PIXELS+964,x
	sta	|SHR_PIXELS+964,y
	lda	>BG_PIXELS+965,x
	sta	|SHR_PIXELS+965,y
	lda	>BG_PIXELS+1120,x
	sta	|SHR_PIXELS+1120,y
	lda	>BG_PIXELS+1122,x
	sta	|SHR_PIXELS+1122,y
	lda	>BG_PIXELS+1124,x
	sta	|SHR_PIXELS+1124,y
	lda	>BG_PIXELS+1125,x
	sta	|SHR_PIXELS+1125,y
	lda	>BG_PIXELS+1280,x
	sta	|SHR_PIXELS+1280,y
	lda	>BG_PIXELS+1282,x
	sta	|SHR_PIXELS+1282,y
	lda	>BG_PIXELS+1284,x
	sta	|SHR_PIXELS+1284,y
	lda	>BG_PIXELS+1285,x
	sta	|SHR_PIXELS+1285,y
	lda	>BG_PIXELS+1440,x
	sta	|SHR_PIXELS+1440,y
	lda	>BG_PIXELS+1442,x
	sta	|SHR_PIXELS+1442,y
	lda	>BG_PIXELS+1444,x
	sta	|SHR_PIXELS+1444,y
	lda	>BG_PIXELS+1445,x
	sta	|SHR_PIXELS+1445,y
	lda	>BG_PIXELS+1600,x
	sta	|SHR_PIXELS+1600,y
	lda	>BG_PIXELS+1602,x
	sta	|SHR_PIXELS+1602,y
	lda	>BG_PIXELS+1604,x
	sta	|SHR_PIXELS+1604,y
	lda	>BG_PIXELS+1605,x
	sta	|SHR_PIXELS+1605,y
	lda	>BG_PIXELS+1760,x
	sta	|SHR_PIXELS+1760,y
	lda	>BG_PIXELS+1762,x
	sta	|SHR_PIXELS+1762,y
	lda	>BG_PIXELS+1764,x
	sta	|SHR_PIXELS+1764,y
	lda	>BG_PIXELS+1765,x
	sta	|SHR_PIXELS+1765,y
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
* Compiled ghost / fruit / Ms. Pac blit only (no save-under; erase uses $04).
	php
	rep	#$30
	sta	>R_ACT
	sep	#$20
	lda	#BRD_DRAW
	jsr	SetBorder
	phb
	lda	#BANK_SHR
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
