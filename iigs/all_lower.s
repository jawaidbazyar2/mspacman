*
* Phase 3 IIgs host: the renderer driven by lower.bin's game bank.
* make iigs-lower -> build/iigs/lower_host.bin (and lower_game.bin)
*
	xc
	xc
	mx	%00

	org	$0000

	put	mem_static.s
	put	equates.s
	put	entry_ids.s
	put	lower_host.s
	put	lower_sound.s
	put	shr_body.s
	put	render_body.s
	put	actor_publish.s
	put	compiled_ghosts.s
	mx	%00
	put	compiled_fruits.s
	mx	%00
	put	compiled_points.s
	mx	%00
	put	compiled_mspac.s
	mx	%00
	put	compiled_acts.s
	mx	%00
	put	hud_body.s
	put	palette_data.s
	put	tile_bank_data.s
	put	wave_data.s

	end
