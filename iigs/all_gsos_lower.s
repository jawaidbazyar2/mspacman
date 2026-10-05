*
* GS/OS lowered game: relocatable code segment (segment 1). The game
* bank, the BCK strip, the art and the renderer's work RAM are data
* segments (see link_gsos_lower.s).
*
	rel
	xc
	xc
	mx	%00

	ext	BCK_PIXELS,GAME
	ext	AST_TILES,AST_SPR_EVEN,AST_MSK_EVEN
	ext	AST_SPR_ODD,AST_MSK_ODD,AST_MAZE,AST_MAZE_CELLS

	put	mem_gsos.s
	put	equates.s
	put	entry_ids.s
	put	gsos_entry.s
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
