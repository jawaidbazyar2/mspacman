*
* Single translation unit for Merlin32 (equates + shr + render + harness)
*

	xc
	xc
	mx	%00

	org	$0000

	put	equates.s

*============================================================
* Entry
*============================================================
Start
	sei
	clc
	xce
	rep	#$30
	lda	#$01FF
	tcs
	lda	#$0000
	tcd
	phk
	plb

	jsr	InitSHR
	jsr	CopyMaze
* Odd sprite/mask forms are injected from host (sprites14x12.odd*.bin)
	lda	#0
	sta	>DEMO_FREEZE
	jsr	InitActors
	jsr	DrawMaze
	jsr	DrawAllSprites		; new (== old at start)
	jsr	CopySpritePos
	lda	#0
	sta	>FRAME_COUNT
	cli				; IRQs ok once frame path is live
	jsr	WaitVBL			; sync before first erase/draw

MainLoop
* erase(old) → draw(new) → old←new → move(new) → WaitVBL
	sep	#$20
	lda	>KBD
	bpl	:nokey
	sta	>KBDSTRB			; clear strobe
	jmp	ExitDemo
:nokey	rep	#$30
	lda	>DEMO_FREEZE
	and	#$00FF
	bne	:frozen
	jsr	EraseAllSprites		; ACT_OX/OY
	jsr	DrawAllSprites		; ACT_X/Y
	jsr	CopySpritePos		; old ← new
	jsr	AdvanceRails		; write new XY only
	lda	>FRAME_COUNT
	inc
	sta	>FRAME_COUNT
	jsr	WaitVBL
	bra	MainLoop
:frozen	jsr	WaitVBL
	bra	MainLoop

ExitDemo
* Any key ends the rail demo: drop SHR, halt (host freeze still used for PNG).
	sep	#$30
	lda	#$41
	sta	>NEWVIDEO
	lda	>KBDSTRB
	sec
	xce
]hang	bra	]hang

	put	shr_body.s
	put	render_body.s
	put	harness_body.s
	put	rails_data.s
* Palette data last so it is not accidentally DP-addressed if |abs is missed
	put	palette_data.s

	end
