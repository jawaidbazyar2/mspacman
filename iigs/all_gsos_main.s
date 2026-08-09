*
* GS/OS game — relocatable code segment (segment 1).
* BCK + assets are separate OMF data segments (see link_gsos_game.s).
*
	rel
	xc
	xc
	mx	%00

	ext	BCK_PIXELS
	ext	AST_TILES,AST_SPR_EVEN,AST_MSK_EVEN
	ext	AST_SPR_ODD,AST_MSK_ODD,AST_MAZE,AST_MAZE_CELLS

	put	mem_gsos.s
	put	equates.s
	put	gsos_entry.s
	put	frame_body.s
	put	game_tick.s
	put	input_adapt.s
	put	logic_data.s
	put	maze_state.s
	put	ghost_ai.s
	put	mspac_move.s
	put	ghost_move.s
	put	collide.s
	put	fruit.s
	put	leave_house.s
	put	play_tick.s
	put	level_fsm.s
	put	actor_publish.s
	put	game_init.s
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
	put	hud_body.s
	put	palette_data.s

	end
