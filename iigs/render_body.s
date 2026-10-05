*
* Tile / sprite render (included from all.s)
*

* Render scratch in low DP (DP=$0000, set once by tcd in all.s). DP is always
* bank $00, so these stay reachable across the DBR=$01 switch in the blits —
* and cost 4 cycles / 2 bytes instead of the 6 / 4 of a long access to $02.
* Always write these with an explicit `<`.
R_X            equ $10
R_Y            equ $12
R_TX           equ $14
R_TY           equ $16
R_TILE         equ $18
R_OFF          equ $1A
R_DEST         equ $1C
R_ROW          equ $1E
R_IDX          equ $20
R_CARRY        equ $22
R_TMP          equ $24
R_ACT          equ $26
R_BASE         equ $28
R_SAVE         equ $2A
R_BODY         equ $2C		; ACT_COLOR nibble for RemapBodyByte
R_BTMP         equ $2E
R_BDEST        equ $30		; BCK strip offset (BckXY)
R_PEN          equ $32		; HUD glyph ink pen (BlitTileAbs / RemapInkByte)
* High DP (DP=$0000): Y-sort keys — actor records are never moved
DP_KEYI        equ $EA		; insertion: actor index being placed
DP_KEYY        equ $EB		; insertion: its Y
DP_YOFF        equ $EC		; word: ACT_Y or ACT_OY field offset
DP_I           equ $EE
DP_J           equ $EF
DP_SORT        equ $F0		; 6 bytes: actor indices, Y-ascending
DP_YKEY        equ $F6		; 6 bytes: Y low for actor 0..5 (by actor #)
* Actors: >ACTORS+field,x with X = index×16

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
	sta	<R_TMP
	asl
	asl
	sta	<R_OFF
	lda	<R_TMP
	asl
	asl
	asl
	asl
	clc
	adc	<R_OFF
	sta	<R_OFF
	lda	<R_TMP
	asl
	asl
	asl
	asl
	asl
	asl
	clc
	adc	<R_OFF
	rts

Mul18
	sta	<R_TMP
	asl
	sta	<R_OFF
	lda	<R_TMP
	asl
	asl
	asl
	asl
	clc
	adc	<R_OFF
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
	lda	<R_Y
	and	#$00FF
	asl
	tax
	lda	>ROW_ADDR,x
	sta	<R_DEST
	lda	<R_X
	lsr
	clc
	adc	<R_DEST
	sta	<R_DEST
	rts

BckXY
* R_BDEST = ROW_BCK[Y] + (X-BCK_ORIGIN_X)/2. Strip is S_BCK-wide @ $01/A000.
	lda	<R_Y
	and	#$00FF
	asl
	tax
	lda	>ROW_BCK,x
	sta	<R_BDEST
	lda	<R_X
	sec
	sbc	#BCK_ORIGIN_X
	lsr
	clc
	adc	<R_BDEST
	sta	<R_BDEST
	rts

GenOddSprites
	php
	rep	#$30
	lda	#0
	sta	<R_IDX
]spr	lda	<R_IDX
	jsr	Mul84
	sta	<R_OFF
	lda	#12
	sta	<R_ROW
]row	jsr	ShiftOneRow
	lda	<R_OFF
	clc
	adc	#7
	sta	<R_OFF
	lda	<R_ROW
	dec
	sta	<R_ROW
	bne	]row
	lda	<R_IDX
	inc
	sta	<R_IDX
	lda	<R_IDX
	cmp	#64
	bcc	]spr
	plp
	rts

ShiftOneRow
	php
	rep	#$30			; 16-bit A/X to fetch offset
	lda	<R_OFF
	tax
	sep	#$20			; 8-bit A for pixel work; X stays 16-bit
	lda	#0
	sta	<R_CARRY
	ldy	#7
]p	lda	>AST_SPR_EVEN,x
	pha
	lda	<R_CARRY
	asl
	asl
	asl
	asl
	sta	<R_TMP
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	ora	<R_TMP
	sta	>AST_SPR_ODD,x
	pla
	and	#$0F
	sta	<R_CARRY
	inx
	dey
	bne	]p
	rep	#$20
	lda	<R_OFF
	tax
	sep	#$20
	lda	#0
	sta	<R_CARRY
	ldy	#7
]m	lda	>AST_MSK_EVEN,x
	pha
	lda	<R_CARRY
	asl
	asl
	asl
	asl
	sta	<R_TMP
	pla
	pha
	lsr
	lsr
	lsr
	lsr
	ora	<R_TMP
	sta	>AST_MSK_ODD,x
	pla
	and	#$0F
	sta	<R_CARRY
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
	lda	<R_TX
	asl
	clc
	adc	<R_TX
	asl
	clc
	adc	#PF_ORIGIN_X
	sta	<R_X
	lda	<R_TY
	asl
	clc
	adc	<R_TY
	asl
	clc
	adc	#PF_ORIGIN_Y
	sta	<R_Y
	jsr	ScreenXY
	jsr	BckXY
	lda	<R_TILE
	and	#$00FF
	jsr	Mul18
	tax
	lda	#6
	sta	<R_ROW
	lda	<R_DEST
	tay
* 3 bytes/row: word @0 then overlapped word @1. X=tile src, Y=SHR, R_BDEST=BCK.
]tr	lda	>AST_TILES,x
	sta	$2000,y
	sta	<R_BTMP
	lda	>AST_TILES+1,x
	sta	$2001,y
	sta	<R_TMP
	phx
	lda	<R_BDEST
	tax
	lda	<R_BTMP
	sta	>BCK_PIXELS,x
	lda	<R_TMP
	sta	>BCK_PIXELS+1,x
	plx
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#S_SHR
	tay
	lda	<R_BDEST
	clc
	adc	#S_BCK
	sta	<R_BDEST
	lda	<R_ROW
	dec
	sta	<R_ROW
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
	sta	<R_TY
]my	lda	#0
	sta	<R_TX
]mx	lda	<R_TX
	asl
	clc
	adc	<R_TX
	asl
	clc
	adc	#PF_ORIGIN_X
	sta	<R_X
	lda	<R_TY
	asl
	clc
	adc	<R_TY
	asl
	clc
	adc	#PF_ORIGIN_Y
	sta	<R_Y
	jsr	ScreenXY
	jsr	BckXY
	lda	<R_TY
	asl
	asl
	asl
	asl
	asl
	sta	<R_TMP
	lda	<R_TY
	asl
	asl
	sta	<R_OFF
	lda	<R_TMP
	sec
	sbc	<R_OFF
	clc
	adc	<R_TX
	jsr	Mul18
	tax
	lda	#6
	sta	<R_ROW
	lda	<R_DEST
	tay
]mc	lda	>AST_MAZE_CELLS,x
	sta	$2000,y
	sta	<R_BTMP
	lda	>AST_MAZE_CELLS+1,x
	sta	$2001,y
	sta	<R_TMP
	phx
	lda	<R_BDEST
	tax
	lda	<R_BTMP
	sta	>BCK_PIXELS,x
	lda	<R_TMP
	sta	>BCK_PIXELS+1,x
	plx
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#S_SHR
	tay
	lda	<R_BDEST
	clc
	adc	#S_BCK
	sta	<R_BDEST
	lda	<R_ROW
	dec
	sta	<R_ROW
	bne	]mc
	lda	<R_TX
	inc
	sta	<R_TX
	lda	<R_TX
	cmp	#28
	bcs	:ny
	brl	]mx
:ny	lda	<R_TY
	inc
	sta	<R_TY
	lda	<R_TY
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
	adc	<DP_YOFF
	tax
	lda	>ACTORS,x		; Y word at ACTORS+idx*16+DP_YOFF
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
	tax				; dp,X — 65816 has no LDA dp,Y
	lda	<DP_YKEY,x
	sta	<DP_KEYY			; key Y
	lda	<DP_I
	sta	<DP_J			; j = i
]inner	lda	<DP_J
	beq	:place			; j == 0
	dec
	tax				; X = j-1
	lda	<DP_SORT,x
	tax				; dp,X — 65816 has no LDA dp,Y
	lda	<DP_YKEY,x			; Y of SORT[j-1]
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
* Erase at ACT_OX/OY (old), top→bottom from DP_SORT.
* Caller fills DP_SORT once after rails (SortActorsByY ACT_OY) before WaitVBL.
	php
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
* Draw at ACT_X/Y (new), same DP_SORT as erase (no re-sort: ≤1px/frame).
	php
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
* Stork head ($30, act-3 blit 0) shares its Y with the body. Equal Y
* keeps the lower actor index behind, so the wing would cover the beak.
* Draw the head once more, on top.
	ldx	#0
]hd	phx
	rep	#$30
	txa
	and	#$00FF
	sta	<R_ACT
	asl
	asl
	asl
	asl
	tax
	lda	>ACTORS+ACT_FLAGS,x
	and	#$00FF
	bit	#FLAG_ACT3
	beq	:nohd
	lda	>ACTORS+ACT_SPR,x
	and	#$00FF
	bne	:nohd
	lda	<R_ACT
	jsr	DrawSprite
:nohd	sep	#$30
	plx
	inx
	cpx	#NUM_ACTORS
	bcc	]hd
	plp
	rts

CopySpritePos
* After draw: old ← new so next erase hits the on-screen pose.
	php
	rep	#$30
	lda	#0
	sta	<R_ACT
]c	lda	<R_ACT
	asl
	asl
	asl
	asl
	tax
	lda	>ACTORS+ACT_X,x
	sta	>ACTORS+ACT_OX,x
	lda	>ACTORS+ACT_Y,x
	sta	>ACTORS+ACT_OY,x
	lda	<R_ACT
	inc
	sta	<R_ACT
	cmp	#NUM_ACTORS
	bcc	]c
	plp
	rts

EraseSprite
* A = actor index. Restore at last DrawSprite pose (ACT_DEST / ACT_BDEST).
* Restore 14×12: abs,X load BCK (S_BCK) → abs,Y store SHR (S_SHR), DBR=$01.
* Merlin parses a+b*c left-to-right — use decimal row offsets, not S_BCK*n.
	php
	rep	#$30
	sta	<R_ACT
	sep	#$20
	lda	#BRD_ERASE
	jsr	SetBorder
	phb
	lda	#BANK_SHR
	pha
	plb
	rep	#$30
	lda	<R_ACT
	asl
	asl
	asl
	asl
	sta	<R_BASE
	tax
	lda	>ACTORS+ACT_FLAGS,x
	and	#$0001
	bne	:er
	plb
	plp
	rts
* X still holds the actor base, so read both cached offsets straight into Y/X.
:er	lda	>ACTORS+ACT_DEST,x
* Refuse a stale DEST from a pre-clip frame (12 rows → $01/C0xx).
	cmp	#SPR_Y_LIMIT*S_SHR	; 189*160
	bcc	:erOk
	sep	#$20
	lda	>ACTORS+ACT_FLAGS,x
	and	#$FE
	sta	>ACTORS+ACT_FLAGS,x
	plb
	plp
	rts
:erOk	tay				; Y = SHR offset
	lda	>ACTORS+ACT_BDEST,x
	tax				; X = BCK offset
* Unrolled 12×7. Row r offsets: BCK r*88+{0,2,4,5} / SHR r*160+…
* Decimal only — Merlin a+b*c is left-to-right (breaks S_BCK*n).
	lda	>BCK_PIXELS+0,x
	sta	|SHR_PIXELS+0,y
	lda	>BCK_PIXELS+2,x
	sta	|SHR_PIXELS+2,y
	lda	>BCK_PIXELS+4,x
	sta	|SHR_PIXELS+4,y
	lda	>BCK_PIXELS+5,x
	sta	|SHR_PIXELS+5,y
	lda	>BCK_PIXELS+88,x
	sta	|SHR_PIXELS+160,y
	lda	>BCK_PIXELS+90,x
	sta	|SHR_PIXELS+162,y
	lda	>BCK_PIXELS+92,x
	sta	|SHR_PIXELS+164,y
	lda	>BCK_PIXELS+93,x
	sta	|SHR_PIXELS+165,y
	lda	>BCK_PIXELS+176,x
	sta	|SHR_PIXELS+320,y
	lda	>BCK_PIXELS+178,x
	sta	|SHR_PIXELS+322,y
	lda	>BCK_PIXELS+180,x
	sta	|SHR_PIXELS+324,y
	lda	>BCK_PIXELS+181,x
	sta	|SHR_PIXELS+325,y
	lda	>BCK_PIXELS+264,x
	sta	|SHR_PIXELS+480,y
	lda	>BCK_PIXELS+266,x
	sta	|SHR_PIXELS+482,y
	lda	>BCK_PIXELS+268,x
	sta	|SHR_PIXELS+484,y
	lda	>BCK_PIXELS+269,x
	sta	|SHR_PIXELS+485,y
	lda	>BCK_PIXELS+352,x
	sta	|SHR_PIXELS+640,y
	lda	>BCK_PIXELS+354,x
	sta	|SHR_PIXELS+642,y
	lda	>BCK_PIXELS+356,x
	sta	|SHR_PIXELS+644,y
	lda	>BCK_PIXELS+357,x
	sta	|SHR_PIXELS+645,y
	lda	>BCK_PIXELS+440,x
	sta	|SHR_PIXELS+800,y
	lda	>BCK_PIXELS+442,x
	sta	|SHR_PIXELS+802,y
	lda	>BCK_PIXELS+444,x
	sta	|SHR_PIXELS+804,y
	lda	>BCK_PIXELS+445,x
	sta	|SHR_PIXELS+805,y
	lda	>BCK_PIXELS+528,x
	sta	|SHR_PIXELS+960,y
	lda	>BCK_PIXELS+530,x
	sta	|SHR_PIXELS+962,y
	lda	>BCK_PIXELS+532,x
	sta	|SHR_PIXELS+964,y
	lda	>BCK_PIXELS+533,x
	sta	|SHR_PIXELS+965,y
	lda	>BCK_PIXELS+616,x
	sta	|SHR_PIXELS+1120,y
	lda	>BCK_PIXELS+618,x
	sta	|SHR_PIXELS+1122,y
	lda	>BCK_PIXELS+620,x
	sta	|SHR_PIXELS+1124,y
	lda	>BCK_PIXELS+621,x
	sta	|SHR_PIXELS+1125,y
	lda	>BCK_PIXELS+704,x
	sta	|SHR_PIXELS+1280,y
	lda	>BCK_PIXELS+706,x
	sta	|SHR_PIXELS+1282,y
	lda	>BCK_PIXELS+708,x
	sta	|SHR_PIXELS+1284,y
	lda	>BCK_PIXELS+709,x
	sta	|SHR_PIXELS+1285,y
	lda	>BCK_PIXELS+792,x
	sta	|SHR_PIXELS+1440,y
	lda	>BCK_PIXELS+794,x
	sta	|SHR_PIXELS+1442,y
	lda	>BCK_PIXELS+796,x
	sta	|SHR_PIXELS+1444,y
	lda	>BCK_PIXELS+797,x
	sta	|SHR_PIXELS+1445,y
	lda	>BCK_PIXELS+880,x
	sta	|SHR_PIXELS+1600,y
	lda	>BCK_PIXELS+882,x
	sta	|SHR_PIXELS+1602,y
	lda	>BCK_PIXELS+884,x
	sta	|SHR_PIXELS+1604,y
	lda	>BCK_PIXELS+885,x
	sta	|SHR_PIXELS+1605,y
	lda	>BCK_PIXELS+968,x
	sta	|SHR_PIXELS+1760,y
	lda	>BCK_PIXELS+970,x
	sta	|SHR_PIXELS+1762,y
	lda	>BCK_PIXELS+972,x
	sta	|SHR_PIXELS+1764,y
	lda	>BCK_PIXELS+973,x
	sta	|SHR_PIXELS+1765,y
	lda	<R_BASE
	tax
	sep	#$20
	lda	>ACTORS+ACT_FLAGS,x
	and	#$FE
	sta	>ACTORS+ACT_FLAGS,x
	plb
	plp
	rts

DrawSprite
* A = actor index — must save before PHB bank switch clobbers it
* Compiled blit; cache ACT_DEST/ACT_BDEST for next EraseSprite.
	php
	rep	#$30
	sta	<R_ACT
	sep	#$20
	lda	#BRD_DRAW
	jsr	SetBorder
	phb
	lda	#BANK_SHR
	pha
	plb
	rep	#$30
	lda	<R_ACT
	asl
	asl
	asl
	asl
	sta	<R_BASE
	tax
	lda	>ACTORS+ACT_FLAGS,x
	and	#$00FF
	and	#FLAG_NODRAW
	beq	:doDraw
	plb
	plp
	rts
:doDraw	lda	>ACTORS+ACT_X,x
	sta	<R_X
	lda	>ACTORS+ACT_Y,x
	sta	<R_Y
* Belt: never blit a 12-row cell past SHR (DBR=$01 → $C0xx soft-switches).
	cmp	#SPR_Y_LIMIT
	bcc	:yOk
	plb
	plp
	rts
:yOk	jsr	ScreenXY
	jsr	BckXY
* Act clapper: four sprites $10-$17, on ghost, Ms. Pac and fruit slots.
	ldx	<R_BASE
	lda	>ACTORS+ACT_FLAGS,x
	and	#$00FF
	bit	#FLAG_CLAPPER
	beq	:notClap
	lda	>ACTORS+ACT_SPR,x
	and	#$0007
	asl				; slot*2
	sta	<R_OFF
	lda	<R_X
	and	#$0001
	ora	<R_OFF
	asl				; word index
	tax
	lda	<R_DEST
	tay
	jsr	ActBlitGo
	brl	:blitDone
* Act 3 stork, sack and junior. ACT_SPR is the Act3BlitTable index.
:notClap	lda	>ACTORS+ACT_FLAGS,x
	and	#$00FF
	bit	#FLAG_ACT3
	beq	:notAct3
	lda	>ACTORS+ACT_SPR,x
	and	#$000F
	asl				; slot*2
	sta	<R_OFF
	lda	<R_X
	and	#$0001
	ora	<R_OFF
	asl				; word index
	tax
	lda	<R_DEST
	tay
	jsr	Act3BlitGo
	brl	:blitDone
:notAct3	lda	<R_ACT
	cmp	#FRUIT_ACTOR
	bne	:notFruit
	brl	:fruitBlit
:notFruit
	cmp	#PAC_ACTOR
	bne	:ghostish
	brl	:pacBlit
:ghostish
* Eat-ghost freeze: FLAG_POINTS → sprites $28–$2B (compiled bank $18).
* FLAG_CHAR: Act 1 parks Pac-Man and Ms. Pac-Man on a ghost slot.
	lda	<R_BASE
	tax
	lda	>ACTORS+ACT_FLAGS,x
	and	#$00FF
	bit	#FLAG_POINTS
	bne	:pointsBlit
	bit	#FLAG_CHAR
	beq	:ghostBody
	brl	:pacBlit
:ghostBody
* Ghost: index = ACT_COLOR*16 + (ACT_SPR&7)*2 + (X&1)
	lda	>ACTORS+ACT_COLOR,x
	and	#$0007
	asl
	asl
	asl
	asl				; *16
	sta	<R_TMP
	lda	>ACTORS+ACT_SPR,x
	and	#$0007
	asl				; frame*2
	sta	<R_OFF
	lda	<R_X
	and	#$0001
	ora	<R_OFF
	ora	<R_TMP
	asl				; word index
	tax
	lda	<R_DEST
	tay
	jsr	GhostBlitGo
	brl	:blitDone
:pointsBlit
* Points: index = (ACT_SPR&3)*2 + (X&1)
	lda	>ACTORS+ACT_SPR,x
	and	#$0003
	asl				; slot*2
	sta	<R_OFF
	lda	<R_X
	and	#$0001
	ora	<R_OFF
	asl				; word index
	tax
	lda	<R_DEST
	tay
	jsr	PointsBlitGo
	bra	:blitDone
:fruitBlit
	lda	<R_BASE
	tax
	lda	>ACTORS+ACT_FLAGS,x
	and	#$00FF
	and	#FLAG_POINTS
	bne	:fruitPts
* Fruit: index = (ACT_SPR&7)*2 + (X&1)
	lda	>ACTORS+ACT_SPR,x
	and	#$0007
	asl				; type*2
	sta	<R_OFF
	lda	<R_X
	and	#$0001
	ora	<R_OFF
	asl				; word index
	tax
	lda	<R_DEST
	tay
	jsr	FruitBlitGo
	bra	:blitDone
:fruitPts
* Fruit score $08-$0F: index = (4+(ACT_SPR&7))*2 + (X&1)
	lda	>ACTORS+ACT_SPR,x
	and	#$0007
	clc
	adc	#4
	asl				; slot*2
	sta	<R_OFF
	lda	<R_X
	and	#$0001
	ora	<R_OFF
	asl				; word index
	tax
	lda	<R_DEST
	tay
	jsr	PointsBlitGo
	bra	:blitDone
:pacBlit
* Ms. Pac / Pac-Man: index = (ACT_SPR & $1F)*2 + (X&1).
* ACT_SPR = dir*3+mouth; Pac-Man's poses are 12..23.
	lda	<R_BASE
	tax
	lda	>ACTORS+ACT_SPR,x
	and	#$001F
	asl				; slot*2
	sta	<R_OFF
	lda	<R_X
	and	#$0001
	ora	<R_OFF
	asl				; word index
	tax
	lda	<R_DEST
	tay
	jsr	MsPacBlitGo
:blitDone
	lda	<R_BASE
	tax
	lda	<R_DEST
	sta	>ACTORS+ACT_DEST,x
	lda	<R_BDEST
	sta	>ACTORS+ACT_BDEST,x
	sep	#$20
	lda	>ACTORS+ACT_FLAGS,x
	ora	#$01
	sta	>ACTORS+ACT_FLAGS,x
	plb
	plp
	rts

ApplyDirty
* Redraw queued tiles into SHR + BCK. Keep the count in R_IDX: DrawTile owns
* R_ROW (and R_TX/R_TY/R_TMP/R_OFF/R_DEST/R_BDEST/R_BTMP) as scratch.
	php
	rep	#$30
	lda	>DIRTY_COUNT
	beq	:adone
	sta	<R_IDX
	ldx	#0
]ad	lda	>DIRTY_LIST,x
	and	#$00FF
	sta	<R_TX
	lda	>DIRTY_LIST+1,x
	and	#$00FF
	sta	<R_TY
	phx
	lda	<R_TY
	asl
	asl
	asl
	asl
	asl
	sta	<R_TMP
	lda	<R_TY
	asl
	asl
	sta	<R_OFF
	lda	<R_TMP
	sec
	sbc	<R_OFF
	clc
	adc	<R_TX
	tax
	lda	>TILEMAP,x
	and	#$00FF
	cmp	#TILE_POWER
	bne	:put
	lda	>POWER_FLASH_CNT	; bit 7: pills blinked off
	and	#$0080
	beq	:pill
	lda	#TILE_EMPTY
	bra	:put
:pill	lda	#TILE_POWER
:put	sta	<R_TILE
	jsr	DrawTile
	plx
	inx
	inx
	lda	<R_IDX
	dec
	sta	<R_IDX
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
	sta	<R_TMP
]find	lda	<R_TMP
	cmp	#868
	bcc	:chk
	plp
	rts
:chk	tax
	lda	>TILEMAP,x
	and	#$00FF
	cmp	#$0010
	beq	:eat
	lda	<R_TMP
	inc
	sta	<R_TMP
	bra	]find
:eat	sep	#$20
	lda	#$40
	sta	>TILEMAP,x
	rep	#$20
	lda	<R_TMP
	sta	>EAT_INDEX
	lda	>EAT_INDEX
	inc
	sta	>EAT_INDEX
	lda	<R_TMP
	sta	<R_OFF
	lda	#0
	sta	<R_TY
]div	lda	<R_OFF
	cmp	#28
	bcc	:got
	sec
	sbc	#28
	sta	<R_OFF
	lda	<R_TY
	inc
	sta	<R_TY
	bra	]div
:got	lda	<R_OFF
	sta	<R_TX
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
	plp
	rts
