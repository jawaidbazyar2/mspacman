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
	jsr	PrepGhostWork		; bake ACT_COLOR into work spr+mask
	jsr	DrawMaze
	jsr	DrawAllSprites		; new (== old at start)
	jsr	CopySpritePos
	lda	#0
	sta	>FRAME_COUNT
* Keep SEI — no IRQ handlers installed; cli → random BRK/monitor
	jsr	WaitVBL			; sync before first erase/draw

MainLoop
* erase(old) → draw(new) → old←new → move(new) → WaitVBL
* Border color = phase profiler (see BRD_* in equates.s).
	sep	#$20
	lda	>KBD
	bpl	:nokey
	sta	>KBDSTRB			; clear strobe
	jmp	ExitDemo
:nokey	rep	#$30
	lda	>DEMO_FREEZE
	and	#$00FF
	bne	:frozen
	sep	#$20
	lda	#BRD_ERASE
	jsr	SetBorder
	rep	#$30
	jsr	EraseAllSprites		; ACT_OX/OY
	sep	#$20
	lda	#BRD_DRAW
	jsr	SetBorder
	rep	#$30
	jsr	DrawAllSprites		; ACT_X/Y
	sep	#$20
	lda	#BRD_COPY
	jsr	SetBorder
	rep	#$30
	jsr	CopySpritePos		; old ← new
	sep	#$20
	lda	#BRD_RAILS
	jsr	SetBorder
	rep	#$30
	jsr	AdvanceRails		; write new XY only
	lda	>FRAME_COUNT
	inc
	sta	>FRAME_COUNT
	jsr	WaitVBL			; border black while waiting
	bra	MainLoop
:frozen	sep	#$20
	lda	#BRD_FREEZE
	jsr	SetBorder		; white between frozen waits
	rep	#$30
	jsr	WaitVBL			; black again while in WaitVBL
	bra	MainLoop

ExitDemo
* Any key ends the rail demo: drop SHR, halt (host freeze still used for PNG).
	sep	#$30
	lda	#0
	jsr	SetBorder
	lda	#$41
	sta	>NEWVIDEO
	lda	>KBDSTRB
	sec
	xce
]hang	bra	]hang

	put	shr_body.s
	put	render_body.s
	put	ghost_work_blit.s
	mx	%00			; blit file ends mid-sep; restore before harness
	put	harness_body.s
	put	rails_data.s
* Palette data last so it is not accidentally DP-addressed if |abs is missed
	put	palette_data.s

	end
