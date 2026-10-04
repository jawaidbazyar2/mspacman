*
* Demo build translation unit (rail tour).
* make iigs → build/iigs/harness.bin
*
	xc
	xc
	mx	%00

	org	$0000

	put	mem_static.s
	put	equates.s
	put	frame_body.s
	put	demo_tick.s
	put	shr_body.s
	put	render_body.s
	put	compiled_ghosts.s
	mx	%00
	put	compiled_fruits.s
	mx	%00
	put	compiled_points.s
	mx	%00
	put	compiled_mspac.s
	mx	%00
	put	rails_body.s
	put	hud_body.s
	put	rails_data.s
	put	palette_data.s

	end
