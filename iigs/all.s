*
* Single translation unit for Merlin32 (equates + shr + render + harness)
*
* Listing: Merlin32 ignores LST. make iigs passes -V → build/iigs/harness_Output.txt
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
	jsr	InitRowAddr		; Y→row-byte LUT for ScreenXY
	jsr	CopyMaze
* Odd sprite/mask forms are injected from host (sprites14x12.odd*.bin)
	lda	#0
	sta	>DEMO_FREEZE
	jsr	InitActors
	jsr	DrawMaze
	jsr	InitHUD
	jsr	DrawSideHUD		; gutters: 1UP / HIGH SCORE / lives / fruit
	rep	#$30
	lda	#ACT_OY
	jsr	SortActorsByY		; DP_SORT for first draw (+ next erase)
	jsr	DrawAllSprites		; new (== old at start)
	jsr	CopySpritePos
	lda	#0
	sta	>FRAME_COUNT
	sep	#$20
	sta	>POWER_FLASH_CNT
	rep	#$30
* Keep SEI — no IRQ handlers installed; cli → random BRK/monitor
	jsr	WaitVBL			; sync before first erase/draw

MainLoop
* erase(old) → dirty → draw(new) → old←new → move → sort → WaitVBL
* Dirty tiles (eaten dots) must land between erase and draw: erase restores the
* BCK strip, so the pellet has to be gone from BCK before the next erase.
* One Y-sort after rails (by ACT_OY) feeds next erase+draw — no re-sort before
* draw (≤1px/frame; teleports are horizontal). Yellow sits before VBL slack.
* Border color = phase profiler (see BRD_* in equates.s).
	sep	#$20
	lda	>KBD
	bpl	:nokey
	cmp	#$FF			; ignore open-bus
	beq	:nokey
	sta	>KBDSTRB
	jmp	ExitDemo
:nokey	rep	#$30
	lda	>DEMO_FREEZE
	and	#$00FF
	bne	:frozen
	rep	#$30
	jsr	EraseAllSprites		; erase/draw set BRD_ERASE / BRD_DRAW
	jsr	ApplyDirty		; eaten dots → SHR + BCK
	jsr	DrawAllSprites
	sep	#$20
	lda	#BRD_COPY
	jsr	SetBorder
	rep	#$30
	jsr	CopySpritePos		; old ← new
	sep	#$20
	lda	#BRD_RAILS
	jsr	SetBorder
	rep	#$30
	jsr	AdvanceRails		; write new XY only (ghosts)
	lda	>FRAME_COUNT
	inc
	sta	>FRAME_COUNT
	jsr	EatDotsAtPac		; tile under Ms. Pac → TILEMAP + dirty list
	jsr	DemoScoreTick		; +10 every SCORE_PERIOD frames
	jsr	AdvanceFruit		; cycle fruit type every FRUIT_PERIOD
	jsr	BlinkPowerPills		; palette pen 14 on/off (arcade #0A)
	lda	#ACT_OY
	jsr	SortActorsByY		; yellow; order for next erase+draw
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
	put	compiled_ghosts.s
	mx	%00			; compiled blits end mid-sep; restore before fruit
	put	compiled_fruits.s
	mx	%00			; fruit blits end mid-sep; restore before mspac
	put	compiled_mspac.s
	mx	%00			; mspac blits end mid-sep; restore before harness
	put	harness_body.s
	put	hud_body.s
	put	rails_data.s
* Palette data last so it is not accidentally DP-addressed if |abs is missed
	put	palette_data.s

	end
