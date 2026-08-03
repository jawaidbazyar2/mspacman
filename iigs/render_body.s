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
R_BDEST        equ $028A20	; BCK strip offset (BckXY)
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

InitRowAddr
* ROW_ADDR[y]=y*S_SHR, ROW_BCK[y]=y*S_BCK (y=0..255).
	php
	rep	#$30
	ldx	#0
	lda	#0
]i	sta	>ROW_ADDR,x
	clc
	adc	#S_SHR
	inx
	inx
	cpx	#512
	bcc	]i
	ldx	#0
	lda	#0
]j	sta	>ROW_BCK,x
	clc
	adc	#S_BCK
	inx
	inx
	cpx	#512
	bcc	]j
	plp
	rts

ScreenXY
* R_DEST = ROW_ADDR[Y] + X/2. Long,X: DBR may be $01 during blit.
	lda	>R_Y
	and	#$00FF
	asl
	tax
	lda	>ROW_ADDR,x
	sta	>R_DEST
	lda	>R_X
	lsr
	clc
	adc	>R_DEST
	sta	>R_DEST
	rts

BckXY
* R_BDEST = ROW_BCK[Y] + (X-BCK_ORIGIN_X)/2. Strip is S_BCK-wide @ $01/A000.
	lda	>R_Y
	and	#$00FF
	asl
	tax
	lda	>ROW_BCK,x
	sta	>R_BDEST
	lda	>R_X
	sec
	sbc	#BCK_ORIGIN_X
	lsr
	clc
	adc	>R_BDEST
	sta	>R_BDEST
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
* Write tile to SHR ($01) and BCK strip ($01/A000), strides S_SHR / S_BCK.
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
	jsr	BckXY
	lda	>R_TILE
	and	#$00FF
	jsr	Mul18
	tax
	lda	#6
	sta	>R_ROW
	lda	>R_DEST
	tay
* 3 bytes/row: word @0 then overlapped word @1. X=tile src, Y=SHR, R_BDEST=BCK.
]tr	lda	>AST_TILES,x
	sta	$2000,y
	sta	>R_BTMP
	lda	>AST_TILES+1,x
	sta	$2001,y
	sta	>R_TMP
	phx
	lda	>R_BDEST
	tax
	lda	>R_BTMP
	sta	BCK_BASE,x
	lda	>R_TMP
	sta	BCK_BASE+1,x
	plx
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#S_SHR
	tay
	lda	>R_BDEST
	clc
	adc	#S_BCK
	sta	>R_BDEST
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]tr
	plb
	plp
	rts

DrawMaze
* Pre-stitched 6×6 cells → SHR + BCK (DBR=$01). No bank-$04 mirror.
	php
	phb
	sep	#$20
	lda	#BANK_SHR
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
	jsr	BckXY
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
]mc	lda	>AST_MAZE_CELLS,x
	sta	$2000,y
	sta	>R_BTMP
	lda	>AST_MAZE_CELLS+1,x
	sta	$2001,y
	sta	>R_TMP
	phx
	lda	>R_BDEST
	tax
	lda	>R_BTMP
	sta	BCK_BASE,x
	lda	>R_TMP
	sta	BCK_BASE+1,x
	plx
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#S_SHR
	tay
	lda	>R_BDEST
	clc
	adc	#S_BCK
	sta	>R_BDEST
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
* Restore 14×12: abs,X load BCK (S_BCK) → abs,Y store SHR (S_SHR), DBR=$01.
* Merlin parses a+b*c left-to-right — use decimal row offsets, not S_BCK*n.
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
	jsr	BckXY
	lda	>R_BDEST
	tax
	lda	>R_DEST
	tay
* Unrolled 12×7. Row r offsets: BCK r*88+{0,2,4,5} / SHR r*160+…
* Decimal only — Merlin a+b*c is left-to-right (breaks S_BCK*n).
	lda	BCK_BASE+0,x
	sta	|SHR_PIXELS+0,y
	lda	BCK_BASE+2,x
	sta	|SHR_PIXELS+2,y
	lda	BCK_BASE+4,x
	sta	|SHR_PIXELS+4,y
	lda	BCK_BASE+5,x
	sta	|SHR_PIXELS+5,y
	lda	BCK_BASE+88,x
	sta	|SHR_PIXELS+160,y
	lda	BCK_BASE+90,x
	sta	|SHR_PIXELS+162,y
	lda	BCK_BASE+92,x
	sta	|SHR_PIXELS+164,y
	lda	BCK_BASE+93,x
	sta	|SHR_PIXELS+165,y
	lda	BCK_BASE+176,x
	sta	|SHR_PIXELS+320,y
	lda	BCK_BASE+178,x
	sta	|SHR_PIXELS+322,y
	lda	BCK_BASE+180,x
	sta	|SHR_PIXELS+324,y
	lda	BCK_BASE+181,x
	sta	|SHR_PIXELS+325,y
	lda	BCK_BASE+264,x
	sta	|SHR_PIXELS+480,y
	lda	BCK_BASE+266,x
	sta	|SHR_PIXELS+482,y
	lda	BCK_BASE+268,x
	sta	|SHR_PIXELS+484,y
	lda	BCK_BASE+269,x
	sta	|SHR_PIXELS+485,y
	lda	BCK_BASE+352,x
	sta	|SHR_PIXELS+640,y
	lda	BCK_BASE+354,x
	sta	|SHR_PIXELS+642,y
	lda	BCK_BASE+356,x
	sta	|SHR_PIXELS+644,y
	lda	BCK_BASE+357,x
	sta	|SHR_PIXELS+645,y
	lda	BCK_BASE+440,x
	sta	|SHR_PIXELS+800,y
	lda	BCK_BASE+442,x
	sta	|SHR_PIXELS+802,y
	lda	BCK_BASE+444,x
	sta	|SHR_PIXELS+804,y
	lda	BCK_BASE+445,x
	sta	|SHR_PIXELS+805,y
	lda	BCK_BASE+528,x
	sta	|SHR_PIXELS+960,y
	lda	BCK_BASE+530,x
	sta	|SHR_PIXELS+962,y
	lda	BCK_BASE+532,x
	sta	|SHR_PIXELS+964,y
	lda	BCK_BASE+533,x
	sta	|SHR_PIXELS+965,y
	lda	BCK_BASE+616,x
	sta	|SHR_PIXELS+1120,y
	lda	BCK_BASE+618,x
	sta	|SHR_PIXELS+1122,y
	lda	BCK_BASE+620,x
	sta	|SHR_PIXELS+1124,y
	lda	BCK_BASE+621,x
	sta	|SHR_PIXELS+1125,y
	lda	BCK_BASE+704,x
	sta	|SHR_PIXELS+1280,y
	lda	BCK_BASE+706,x
	sta	|SHR_PIXELS+1282,y
	lda	BCK_BASE+708,x
	sta	|SHR_PIXELS+1284,y
	lda	BCK_BASE+709,x
	sta	|SHR_PIXELS+1285,y
	lda	BCK_BASE+792,x
	sta	|SHR_PIXELS+1440,y
	lda	BCK_BASE+794,x
	sta	|SHR_PIXELS+1442,y
	lda	BCK_BASE+796,x
	sta	|SHR_PIXELS+1444,y
	lda	BCK_BASE+797,x
	sta	|SHR_PIXELS+1445,y
	lda	BCK_BASE+880,x
	sta	|SHR_PIXELS+1600,y
	lda	BCK_BASE+882,x
	sta	|SHR_PIXELS+1602,y
	lda	BCK_BASE+884,x
	sta	|SHR_PIXELS+1604,y
	lda	BCK_BASE+885,x
	sta	|SHR_PIXELS+1605,y
	lda	BCK_BASE+968,x
	sta	|SHR_PIXELS+1760,y
	lda	BCK_BASE+970,x
	sta	|SHR_PIXELS+1762,y
	lda	BCK_BASE+972,x
	sta	|SHR_PIXELS+1764,y
	lda	BCK_BASE+973,x
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
* Compiled ghost / fruit / Ms. Pac blit only (no save-under; erase uses BCK).
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
