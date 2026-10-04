/* Power pills: blue ghosts, their flashing and timer, catching a ghost
 * or being caught, and the score shown for an eaten ghost. */
#include "game.h"

#define EYES_CODE      0x20u /* sprite code for a ghost's eyes */
#define BLUE_CODE      0x1Cu /* sprite code for a blue ghost */
#define BLUE_COLOR     0x11u
#define WHITE_COLOR    0x12u /* the other colour of a flashing ghost */
#define EYES_COLOR     0x19u
#define POINTS_COLOR   0x18u
#define PAC_COLOR      0x09u
#define FLASH_TIME     0x0100u /* blue ghosts flash below this */

/* $0BD6: eyes keep their own colour. Pac-Man's title chase hid them;
 * that branch is dead in Ms. Pac-Man. */
void color_eyes(Board *b)
{
	LOWER_HOOK(color_eyes, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t color = ram->game_mode_sub1 == PACMAN_CHASE_SCENE ? 0 : EYES_COLOR;
	int g;

	for (g = ACT_RED; g <= ACT_ORANGE; g++)
		if (ram->ghost_state[g] != GHOST_ALIVE)
			ram->sprite[SPR_RED + g].color = color;
}

/* $1A6A: an energizer (a 6-frame eat delay) turns every ghost blue and
 * makes them reverse. */
void start_fright(Board *b)
{
	LOWER_HOOK(start_fright, b);
	WorkRam *ram = work_ram(b->mem);
	int g;

	if (ram->pac_move_delay != 6)
		return;
	ram->frightened_timer_lo = ram->frightened_time_lo;
	ram->frightened_timer_hi = ram->frightened_time_hi;
	ram->power_pill_active = 1;
	memset(ram->frightened, 1, sizeof ram->frightened);
	memset(ram->reverse, 1, sizeof ram->reverse);
	ram->frightened_flash_counter = 0;
	ram->ghosts_killed_count = 0;
	for (g = ACT_RED; g <= ACT_ORANGE; g++) {
		ram->sprite[SPR_RED + g].code = BLUE_CODE;
		ram->sprite[SPR_RED + g].color = BLUE_COLOR;
	}
	ram->effect[1].num = (uint8_t)((ram->effect[1].num | 0x20u) & 0x7Fu);
}

/* $1376: the power pill runs out, or ends early once no ghost is blue.
 * Ghosts that are eyes stay frightened until they get home. */
void fright_countdown(Board *b)
{
	LOWER_HOOK(fright_countdown, b);
	WorkRam *ram = work_ram(b->mem);
	int g;

	if (ram->power_pill_active == 0)
		return;
	if ((ram->frightened[0] | ram->frightened[1] | ram->frightened[2] |
	     ram->frightened[3]) != 0) {
		uint16_t left = (uint16_t)(get16(b, RAM_ADDR(frightened_timer_lo)) - 1u);

		put16(b, RAM_ADDR(frightened_timer_lo), left);
		if (left != 0)
			return;
	}
	ram->sprite[SPR_PAC].color = PAC_COLOR;
	for (g = ACT_RED; g <= ACT_ORANGE; g++)
		if (ram->ghost_state[g] == GHOST_ALIVE)
			ram->frightened[g] = 0;
	put16(b, RAM_ADDR(frightened_timer_lo), 0);
	ram->power_pill_active = 0;
	ram->frightened_flash_counter = 0;
	ram->ghosts_killed_count = 0;
	ram->effect[1].num = (uint8_t)(ram->effect[1].num & ~0xA0u);
}

/* $0AC3: every 14 frames repaint the ghosts. Blue ghosts flash white
 * near the end of the pill; the rest get their own colours back. */
void flash_ghosts(Board *b)
{
	LOWER_HOOK(flash_ghosts, b);
	WorkRam *ram = work_ram(b->mem);
	int g;

	if (ram->ghosts_killed_pending != 0)
		return;
	if (ram->frightened_flash_counter == 0) {
		bool ending = get16(b, RAM_ADDR(frightened_timer_lo)) < FLASH_TIME;

		ram->frightened_flash_counter = 0x0E;
		if (ram->power_pill_active != 0 && ending) {
			ram->effect[1].num |= 0x80u;
			if (ram->sprite[SPR_PAC].color == PAC_COLOR)
				ram->effect[1].num &= 0x7Fu;
			ram->sprite[SPR_PAC].color = PAC_COLOR;
		}
		for (g = ACT_RED; g <= ACT_ORANGE; g++) {
			uint8_t *color = &ram->sprite[SPR_RED + g].color;

			if (ram->frightened[g] == 0)
				*color = (uint8_t)(2 * g + 1);
			else if (ending)
				*color = *color == BLUE_COLOR ? WHITE_COLOR : BLUE_COLOR;
		}
	}
	ram->frightened_flash_counter--;
}

/* A ghost (1-4, or 0 for none) met Ms. Pac-Man. A blue one is eaten and
 * scores; any other kills her. */
static void ghost_hit(Board *b, uint8_t who)
{
	LOWER_HOOK(ghost_hit, b, who);
	WorkRam *ram = work_ram(b->mem);

	ram->ghosts_killed_pending = who;
	ram->pac_death_anim = who;
	if (who == 0 || ram->frightened[who - 1] == 0)
		return;
	ram->pac_death_anim = 0;
	ram->ghosts_killed_count++;
	add_score(b, (uint8_t)(ram->ghosts_killed_count + 1u));
	ram->effect[2].num |= 0x08u;
}

/* $171D: a live ghost on Ms. Pac-Man's tile. Orange is checked first. */
void tile_collision(Board *b)
{
	LOWER_HOOK(tile_collision, b);
	WorkRam *ram = work_ram(b->mem);
	int g;

	for (g = ACT_ORANGE; g >= ACT_RED; g--)
		if (ram->ghost_state[g] == GHOST_ALIVE &&
		    coord_eq(ram->tile[g], ram->tile[ACT_PAC]))
			break;
	ghost_hit(b, (uint8_t)(g + 1));
}

/* $1789: during a power pill, a live ghost within 4 pixels. The test is
 * one-sided: the ghost must be 0-3 pixels past her on both axes. */
void pixel_collision(Board *b)
{
	LOWER_HOOK(pixel_collision, b);
	WorkRam *ram = work_ram(b->mem);
	Coord pac = ram->pos[ACT_PAC];
	int g;

	if (ram->ghosts_killed_pending != 0 || ram->power_pill_active == 0)
		return;
	for (g = ACT_ORANGE; g >= ACT_RED; g--)
		if (ram->ghost_state[g] == GHOST_ALIVE &&
		    (uint8_t)(ram->pos[g].y - pac.y) < 4u &&
		    (uint8_t)(ram->pos[g].x - pac.x) < 4u)
			break;
	ghost_hit(b, (uint8_t)(g + 1));
}

/* $1235: an eaten ghost first shows its points with Ms. Pac-Man hidden.
 * A timed task advances the animation, then it becomes eyes. The
 * animation never passes 2, so the `> 2` test is dead. */
void show_eaten_ghost(Board *b)
{
	LOWER_HOOK(show_eaten_ghost, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t who = ram->ghosts_killed_pending;
	SpriteCode *ghost = &ram->sprite[who];
	uint8_t code;

	if (ram->killed_ghost_anim == 1 || ram->killed_ghost_anim > 2)
		return;
	if (ram->killed_ghost_anim != 0) {
		ghost->code = EYES_CODE;
		ram->sprite[SPR_PAC].color = PAC_COLOR;
		ram->kill_ghost_state = who;
		ram->ghosts_killed_pending = 0;
		ram->killed_ghost_anim = 0;
		ram->effect[1].num |= 0x40u;
		return;
	}
	code = (uint8_t)(ram->ghosts_killed_count + 0x27u);
	/* Cocktail table only; out of scope for the port. */
	if ((ram->player_number & ram->dip_cocktail) != 0)
		code |= 0xC0u;
	ghost->code = code;
	ghost->color = POINTS_COLOR;
	ram->sprite[SPR_PAC].color = 0;
	if (queue_timed(b, TIMER(1, 0x0A), TT_EATEN_GHOST, 0))
		ram->killed_ghost_anim++;
}
