/* Ghost targeting: the chase, scatter, and flee tasks, and the demo's
 * steering for Ms. Pac-Man. Each task picks the next direction for one
 * actor when it reaches the middle of a tile. */
#include "game.h"

#define SCATTER_CORNERS 0x9578u /* per-maze lists of 4 corner tiles */

static const Coord ABOVE_DOOR = { 0x2C, 0x2E };
static const Coord BLUE_CORNER = { 0x40, 0x20 };
static const Coord ORANGE_CORNER = { 0x40, 0x3B };

/* $29EA: squared distance, kept to 16 bits as the game does. */
static uint16_t distance2(Coord a, Coord b)
{
	unsigned dy = a.y > b.y ? (unsigned)(a.y - b.y) : (unsigned)(b.y - a.y);
	unsigned dx = a.x > b.x ? (unsigned)(a.x - b.x) : (unsigned)(b.x - a.x);

	return (uint16_t)(dy * dy + dx * dx);
}

/* $2966: the open direction whose next tile is closest to `target`.
 * Reversing is not allowed. Ties go to the later direction. With every
 * way blocked the current direction stays. The search state stays in
 * RAM ($4D3B-$4D45, $4DC7) as the game leaves it. */
static uint8_t best_dir(Board *b, Coord from, Coord target, uint8_t dir)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t opposite = (uint8_t)(dir ^ 2u);
	uint8_t best = dir;
	uint16_t min = 0xFFFF;
	uint8_t d;

	ram->path_from = from;
	ram->path_target = target;
	ram->path_best_dir = dir;
	ram->path_opposite_dir = opposite;
	put16(b, RAM_ADDR(path_min_dist_lo), min);
	for (d = 0; d < 4; d++) {
		uint16_t dist;

		ram->path_try_dir = d;
		if (d == opposite)
			continue;
		ram->path_try = coord_add(from, dir_step(b, d));
		if (is_wall(tile_at(b, ram->path_try)))
			continue;
		dist = distance2(target, ram->path_try);
		if (dist <= min) {
			min = dist;
			put16(b, RAM_ADDR(path_min_dist_lo), min);
			best = d;
			ram->path_best_dir = d;
		}
	}
	ram->path_try_dir = 4;
	return best;
}

/* $291E: a random open direction other than back the way it came.
 * The search starts at a random direction and turns clockwise. */
static uint8_t random_dir(Board *b, Coord from, uint8_t dir)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t opposite = (uint8_t)(dir ^ 2u);
	uint8_t d = (uint8_t)(rom_random(b) & 0x03u);

	ram->path_from = from;
	ram->path_opposite_dir = opposite;
	ram->path_best_dir = d;
	while (d == opposite || is_wall(tile_at(b, coord_add(from, dir_step(b, d))))) {
		d = (uint8_t)((d + 1u) & 0x03u);
		ram->path_best_dir = d;
	}
	return d;
}

/* $9561: one of this maze's four scatter corners, at random. */
static Coord random_corner(Board *b)
{
	uint16_t list = maze_word(b, SCATTER_CORNERS);

	return word_coord(rom16(b, (uint16_t)(list + (lift_random_byte(b) & 0x06u))));
}

/* Scatter until the first reversal, and only during play. */
static bool scattering(const WorkRam *ram)
{
	return (ram->ghost_orient_index & 0x01u) == 0 && ram->level_state == LEVEL_PLAYING;
}

static void head(Board *b, int ghost, uint8_t dir)
{
	WorkRam *ram = work_ram(b->mem);

	ram->next_step[ghost] = dir_step(b, dir);
	ram->dir[ghost] = dir;
}

static void aim(Board *b, int ghost, Coord target)
{
	WorkRam *ram = work_ram(b->mem);

	head(b, ghost, best_dir(b, ram->mid_tile[ghost], target, ram->dir[ghost]));
}

/* $2730: red chases Ms. Pac-Man. Cruise Elroy never scatters. */
void aim_red(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if (scattering(ram) && ram->cruise_elroy_1 == 0)
		aim(b, ACT_RED, random_corner(b));
	else
		aim(b, ACT_RED, ram->tile[ACT_PAC]);
}

/* $276C: pink aims four tiles ahead of Ms. Pac-Man. The sum is one
 * 16-bit add, so a step of -1 in Y borrows from X. */
void aim_pink(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint16_t ahead;

	if (scattering(ram)) {
		aim(b, ACT_PINK, random_corner(b));
		return;
	}
	ahead = (uint16_t)(4u * coord_word(ram->step[ACT_PAC]) +
			   coord_word(ram->tile[ACT_PAC]));
	aim(b, ACT_PINK, word_coord(ahead));
}

/* $27A9: blue aims at the point two tiles ahead of Ms. Pac-Man,
 * reflected through red. Scatter still draws a corner, then ignores it. */
void aim_blue(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	Coord ahead;
	Coord red = ram->mid_tile[ACT_RED];
	Coord target;

	if (scattering(ram)) {
		(void)random_corner(b);
		aim(b, ACT_BLUE, BLUE_CORNER);
		return;
	}
	ahead = word_coord((uint16_t)(2u * coord_word(ram->step[ACT_PAC]) +
				      coord_word(ram->tile[ACT_PAC])));
	target.y = (uint8_t)(2u * ahead.y - red.y);
	target.x = (uint8_t)(2u * ahead.x - red.x);
	aim(b, ACT_BLUE, target);
}

/* $27F1: orange chases until within 8 tiles, then heads for its corner. */
void aim_orange(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if (scattering(ram) ||
	    distance2(ram->tile[ACT_PAC], ram->mid_tile[ACT_ORANGE]) < 0x40u) {
		(void)random_corner(b);
		aim(b, ACT_ORANGE, ORANGE_CORNER);
		return;
	}
	aim(b, ACT_ORANGE, ram->tile[ACT_PAC]);
}

/* $283B-$28B9: a blue ghost wanders. Eyes head for the house door. */
static void flee(Board *b, int ghost)
{
	WorkRam *ram = work_ram(b->mem);

	if (ram->ghost_state[ghost] == GHOST_ALIVE)
		head(b, ghost, random_dir(b, ram->mid_tile[ghost], ram->dir[ghost]));
	else
		aim(b, ghost, ABOVE_DOOR);
}

void flee_red(Board *b) { flee(b, ACT_RED); }
void flee_pink(Board *b) { flee(b, ACT_PINK); }
void flee_blue(Board *b) { flee(b, ACT_BLUE); }
void flee_orange(Board *b) { flee(b, ACT_ORANGE); }

/* $28E3: the demo steers Ms. Pac-Man away from pink, reflecting pink
 * through her. While red is blue she heads for pink instead. */
void demo_steer(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	Coord pac = ram->tile[ACT_PAC];
	Coord pink = ram->mid_tile[ACT_PINK];
	Coord target = pink;
	uint8_t dir;

	if (ram->frightened[ACT_RED] == 0) {
		target.y = (uint8_t)(2u * pac.y - pink.y);
		target.x = (uint8_t)(2u * pac.x - pink.x);
	}
	dir = best_dir(b, ram->mid_tile[ACT_PAC], target, ram->pac_wanted_dir);
	ram->next_step[ACT_PAC] = dir_step(b, dir);
	ram->pac_wanted_dir = dir;
}
