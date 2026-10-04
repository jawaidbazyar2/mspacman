/* One frame of play: the actors move twice, then the timers, the
 * power-pill blink, the siren, and the fruit. */
#include "game.h"

/* $1017  move everyone once. A dying Ms. Pac-Man or a ghost being
 * eaten freezes the rest. */
static void play_pass(Board *b)
{
	LOWER_HOOK(play_pass, b);
	WorkRam *ram = work_ram(b->mem);

	pac_death(b);
	if (ram->pac_death_anim != 0)
		return;
	mark_eaten_ghost(b);
	return_all_eyes(b);
	if (ram->ghosts_killed_pending != 0) {
		show_eaten_ghost(b);
		return;
	}
	tile_collision(b);
	pixel_collision(b);
	if (ram->ghosts_killed_pending != 0)
		return;
	move_pac(b);
	move_ghosts(b);
	/* Unverified: no move in the corpus changes the level state. */
	if (ram->level_state != LEVEL_PLAYING)
		return;
	fright_countdown(b);
	release_by_pills(b);
}

/* $08EB */
void play_frame(Board *b)
{
	LOWER_HOOK(play_frame, b);
	play_pass(b);
	play_pass(b);
	release_idle_ghost(b);
	move_in_house(b);
	ghost_anim_tick(b);
	reversal_timer(b);
	flash_ghosts(b);
	color_eyes(b);
	flash_power_pills(b);
	siren_update(b);
	move_fruit(b);
}
