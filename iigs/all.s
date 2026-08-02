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
	jsr	DrawAllSprites
	lda	#0
	sta	>FRAME_COUNT
	cli				; IRQs ok once frame path is live

MainLoop
	jsr	WaitVBL
	sep	#$20
	lda	>KBD
	bpl	:nokey
	sta	>KBDSTRB			; clear strobe
	jmp	ExitDemo
:nokey	rep	#$30
	lda	>DEMO_FREEZE
	and	#$00FF
	bne	:frozen
	jsr	EraseAllSprites
	jsr	AdvanceRails		; write ACT_X/ACT_Y only
	jsr	DrawAllSprites		; read ACT_X/ACT_Y
	lda	>FRAME_COUNT
	inc
	sta	>FRAME_COUNT
	bra	MainLoop
:frozen	bra	MainLoop

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
