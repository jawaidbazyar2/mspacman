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
	jsr	InitActors
	jsr	DrawMaze
	jsr	DrawAllSprites
	lda	#0
	sta	>$027900
	cli				; IRQs ok once frame path is live

MainLoop
* Demo actors are parked (dx=dy=0). Skip erase/redraw so GS2 frame
* captures stay stable (pause often landed between erase and draw).
	jsr	WaitVBL
	lda	>$027900
	inc
	sta	>$027900
	bra	MainLoop

	put	shr_body.s
	put	render_body.s
	put	harness_body.s
* Palette data last so it is not accidentally DP-addressed if |abs is missed
	put	palette_data.s

	end
