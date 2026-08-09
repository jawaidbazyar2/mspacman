*
* Game-logic build translation unit.
* make iigs-game → build/iigs/game.bin
*
	xc
	xc
	mx	%00

	org	$0000

	put	mem_static.s
	put	equates.s
	put	frame_body.s
	put	game_tick.s
	put	input_adapt.s
	put	logic_data.s
	put	maze_state.s
	put	ghost_ai.s
	put	mspac_move.s
	put	ghost_move.s
	put	collide.s
	put	fruit.s			; uses AbsLt4 from collide
	put	leave_house.s
	put	play_tick.s
	put	level_fsm.s
	put	actor_publish.s
	put	game_init.s		; InitActors last among logic (calls publish)
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
