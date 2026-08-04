*
* Shared Start + MainLoop (demo and game builds).
* Mode-specific work is FrameTick (DemoTick or LogicTick).
* InitActors is provided by the build (rails_body vs game_init).
*
	mx	%00

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
	jsr	InitRowAddr
	jsr	CopyMaze
	lda	#0
	sta	>DEMO_FREEZE
	jsr	InitActors
	jsr	DrawMaze
	jsr	InitHUD
	jsr	DrawSideHUD
	rep	#$30
	lda	#ACT_OY
	jsr	SortActorsByY
	jsr	DrawAllSprites
	jsr	CopySpritePos
	lda	#0
	sta	>FRAME_COUNT
	sep	#$20
	sta	>POWER_FLASH_CNT
	rep	#$30
* Keep SEI — no IRQ handlers installed
	jsr	WaitVBL

MainLoop
* erase(old) → dirty → draw(new) → old←new → FrameTick → sort → WaitVBL
	sep	#$20
	lda	>KBD
	bpl	:nokey
	cmp	#$FF
	beq	:nokey
	jsr	HandleKey		; build-specific: quit and/or stick
	bcs	:exit
:nokey	rep	#$30
	lda	>DEMO_FREEZE
	and	#$00FF
	bne	:frozen
	rep	#$30
	jsr	EraseAllSprites
	jsr	ApplyDirty
	jsr	DrawAllSprites
	sep	#$20
	lda	#BRD_COPY
	jsr	SetBorder
	rep	#$30
	jsr	CopySpritePos
	sep	#$20
	lda	#BRD_TICK
	jsr	SetBorder
	rep	#$30
	jsr	FrameTick
	lda	#ACT_OY
	jsr	SortActorsByY
	jsr	WaitVBL
	bra	MainLoop
:frozen	sep	#$20
	lda	#BRD_FREEZE
	jsr	SetBorder
	rep	#$30
	jsr	WaitVBL
	bra	MainLoop
:exit	jmp	ExitDemo

ExitDemo
	sep	#$30
	lda	#0
	jsr	SetBorder
	lda	#$41
	sta	>NEWVIDEO
	lda	>KBDSTRB
	sec
	xce
]hang	bra	]hang
