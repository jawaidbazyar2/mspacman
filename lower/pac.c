/* Ms. Pac-Man: the joystick, cornering, eating, and her death. */
#include "game.h"

#define PILL        0x10u
#define ENERGIZER   0x14u
#define PILL_DELAY  1u /* frames she pauses after a pill */
#define ENERGIZER_DELAY 6u
#define NOT_EATING  0xFFu

/* Fruit score: the timed task that removes the points sprite. */
#define FRUIT_POINTS_TIMER TIMER(1, 0x14)

static bool centered(const WorkRam *ram)
{
	const Coord *pos = &ram->pos[ACT_PAC];
	uint8_t across = (ram->dir[ACT_PAC] & 0x01u) != 0 ? pos->y : pos->x;

	return (across & 0x07u) == 4;
}

/* Is there a wall one step from her tile? */
static bool wall_ahead(Board *b, Coord step)
{
	LOWER_HOOK(wall_ahead, b, step);
	return is_wall(tile_at(b, coord_add(work_ram(b->mem)->tile[ACT_PAC], step)));
}

/* $1985-$19B1: the fruit counts when she is within 3 pixels of it.
 * Its sprite becomes the points, and the score is returned. */
static bool eat_fruit(Board *b, uint8_t *points)
{
	WorkRam *ram = work_ram(b->mem);
	Coord pac = ram->pos[ACT_PAC];
	Coord fruit = ram->fruit_pos;

	if (fruit.y == 0 || ram->fruit_points == 0)
		return false;
	if ((uint8_t)(pac.x - fruit.x + 3u) >= 6u ||
	    (uint8_t)(pac.y - fruit.y + 3u) >= 6u)
		return false;
	*points = ram->fruit_points;
	ram->sprite[SPR_FRUIT].color = 0x01;
	ram->sprite[SPR_FRUIT].code = (uint8_t)(*points + 2u);
	return true;
}

/* $19D2: eat the pill under her. A pill costs one frame, an energizer
 * six. The munch sound alternates between two halves. */
static void eat_pill(Board *b)
{
	LOWER_HOOK(eat_pill, b);
	WorkRam *ram = work_ram(b->mem);
	uint16_t cell = tile_cell(ram->tile[ACT_PAC]);
	uint8_t tile = board_mem_read(b, cell);
	bool energizer = tile == ENERGIZER;

	ram->pac_move_delay = NOT_EATING;
	if (tile != PILL && !energizer)
		return;
	ram->dots_eaten++;
	board_mem_write(b, cell, TILE_BLANK);
	queue_task(b, TASK_ADD_SCORE, energizer ? SCORE_ENERGIZER : SCORE_PILL);
	ram->pac_move_delay = energizer ? ENERGIZER_DELAY : PILL_DELAY;
	count_house_pill(b);
	start_fright(b);
	if ((ram->dots_eaten & 0x01u) != 0)
		ram->effect[2].num = (uint8_t)((ram->effect[2].num & ~0x01u) | 0x02u);
	else
		ram->effect[2].num = (uint8_t)((ram->effect[2].num | 0x01u) & ~0x02u);
}

/* $1985: she has moved. Nothing is eaten on the frame she enters the
 * tunnel. Eating the fruit stops here if the timer list is full
 * (unverified; it never is in the corpus). */
static void arrive(Board *b, Coord pos)
{
	LOWER_HOOK(arrive, b, pos);
	WorkRam *ram = work_ram(b->mem);
	uint8_t entering = ram->pac_entering_tunnel;
	uint8_t points;

	ram->pos[ACT_PAC] = pos;
	ram->tile[ACT_PAC] = pos_to_tile(pos);
	ram->pac_entering_tunnel = 0;
	if (entering != 0)
		return;
	if (eat_fruit(b, &points)) {
		queue_task(b, TASK_ADD_SCORE, points);
		clear_fruit(b);
		if (!queue_timed(b, FRUIT_POINTS_TIMER, TT_CLEAR_FRUIT_POS, 0))
			return;
		ram->effect[2].num |= 0x04u;
	}
	eat_pill(b);
}

/* $1950: one pixel along her step. While moving on one axis she is
 * pulled toward the middle of the other, which is how she cuts corners. */
static void pac_step(Board *b)
{
	LOWER_HOOK(pac_step, b);
	WorkRam *ram = work_ram(b->mem);
	Coord pos = coord_add(ram->pos[ACT_PAC], ram->step[ACT_PAC]);
	uint8_t *across = (ram->dir[ACT_PAC] & 0x01u) != 0 ? &pos.x : &pos.y;

	if ((*across & 0x07u) < 4)
		(*across)++;
	else if ((*across & 0x07u) > 4)
		(*across)--;
	arrive(b, pos);
}

/* Take the wanted step. A held direction also turns her to face it. */
static void adopt(Board *b, bool turn)
{
	LOWER_HOOK(adopt, b, turn);
	WorkRam *ram = work_ram(b->mem);

	ram->step[ACT_PAC] = ram->next_step[ACT_PAC];
	if (turn)
		ram->dir[ACT_PAC] = ram->pac_wanted_dir;
	pac_step(b);
}

/* $18E4: try the wanted step. If it is walled off, a held direction
 * keeps her going the old way; with the stick released she stops at
 * the middle of the tile. */
static void try_turn(Board *b, bool held)
{
	LOWER_HOOK(try_turn, b, held);
	WorkRam *ram = work_ram(b->mem);

	if (!wall_ahead(b, ram->next_step[ACT_PAC])) {
		adopt(b, held);
		return;
	}
	if (held) {
		if (wall_ahead(b, ram->step[ACT_PAC]) && centered(ram))
			return;
		pac_step(b);
		return;
	}
	if (centered(ram))
		return;
	adopt(b, true);
}

/* The stick picks the wanted direction. */
static void want(Board *b, uint8_t dir)
{
	LOWER_HOOK(want, b, dir);
	WorkRam *ram = work_ram(b->mem);

	ram->pac_wanted_dir = dir;
	ram->next_step[ACT_PAC] = dir_step(b, dir);
	try_turn(b, true);
}

/* In the tunnel only left and right count, and they turn her at once. */
static void face(Board *b, uint8_t dir)
{
	LOWER_HOOK(face, b, dir);
	WorkRam *ram = work_ram(b->mem);

	ram->dir[ACT_PAC] = dir;
	ram->step[ACT_PAC] = dir_step(b, dir);
	pac_step(b);
}

/* $1A1C: in the attract demo the steering task drives her, tile by
 * tile, the way the ghosts move. */
static void demo_move(Board *b)
{
	LOWER_HOOK(demo_move, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t along = ram->step[ACT_PAC].y == 0 ? ram->pos[ACT_PAC].x : ram->pos[ACT_PAC].y;

	if ((along & 0x07u) == 4) {
		if (!tunnel_wrap(ram, ACT_PAC))
			queue_task(b, TASK_DEMO_STEER, 0);
		ram->mid_tile[ACT_PAC] = coord_add(ram->mid_tile[ACT_PAC], ram->next_step[ACT_PAC]);
		ram->step[ACT_PAC] = ram->next_step[ACT_PAC];
		ram->dir[ACT_PAC] = ram->pac_wanted_dir;
	}
	arrive(b, coord_add(ram->pos[ACT_PAC], ram->step[ACT_PAC]));
}

/* The control port bits are active low. */
enum { STICK_UP = 0x01, STICK_LEFT = 0x02, STICK_RIGHT = 0x04, STICK_DOWN = 0x08 };

/* The demo moves her by itself; in play the stick does. In the
 * tunnel only left and right count. At a cocktail table player 2 has
 * his own stick on IN1 (out of scope for the port). */
static void steer(Board *b, bool tunnel, bool player2_cocktail)
{
	LOWER_HOOK(steer, b, tunnel, player2_cocktail);
	WorkRam *ram = work_ram(b->mem);
	uint8_t in;

	if (tunnel)
		ram->pac_entering_tunnel = 1;
	if (ram->game_mode == MODE_ATTRACT || ram->level_state >= LEVEL_FLASH_BACK) {
		demo_move(b);
		return;
	}
	in = board_mem_read(b, player2_cocktail ? 0x5040 : 0x5000);
	if (tunnel) {
		if ((in & STICK_LEFT) == 0)
			face(b, DIR_LEFT);
		else if ((in & STICK_RIGHT) == 0)
			face(b, DIR_RIGHT);
		else
			pac_step(b);
	} else if ((in & STICK_LEFT) == 0) {
		want(b, DIR_LEFT);
	} else if ((in & STICK_RIGHT) == 0) {
		want(b, DIR_RIGHT);
	} else if ((in & STICK_UP) == 0) {
		want(b, DIR_UP);
	} else if ((in & STICK_DOWN) == 0) {
		want(b, DIR_DOWN);
	} else {
		ram->next_step[ACT_PAC] = ram->step[ACT_PAC];
		try_turn(b, false);
	}
}

/* $1806: Ms. Pac-Man pauses after eating, otherwise moves when her
 * speed pattern says so. */
void move_pac(Board *b)
{
	LOWER_HOOK(move_pac, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t x;

	if (ram->pac_move_delay != NOT_EATING) {
		ram->pac_move_delay--;
		return;
	}
	if (!speed_tick(&ram->pac_speed[ram->power_pill_active != 0 ? 1 : 0]))
		return;
	ram->pills_since_pac_move = ram->dots_eaten;
	x = ram->tile[ACT_PAC].x;
	steer(b, x < 0x21 || x >= 0x3B, (ram->player_number & ram->dip_cocktail) != 0);
}

/* $2675 (task $1E): clear the fruit and every actor's position, which
 * takes them off screen. */
void clear_actor_positions(Board *b)
{
	LOWER_HOOK(clear_actor_positions, b);
	WorkRam *ram = work_ram(b->mem);

	memset(&ram->fruit_pos, 0, sizeof ram->fruit_pos);
	memset(ram->pos, 0, sizeof ram->pos);
}

/* $1291: the death animation, one state per call. States 1-4 wait,
 * 5-15 show the spin, each until the counter reaches its frame, and
 * 16 takes a life and moves the level on. Nothing sets a state above 16,
 * so that guard is dead. */
void pac_death(Board *b)
{
	LOWER_HOOK(pac_death, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t state = ram->pac_death_anim;
	uint16_t count;
	uint8_t code;
	uint16_t until;

	if (state == 0 || state > 16)
		return;
	count = (uint16_t)(get16(b, RAM_ADDR(death_counter_lo)) + 1u);
	if (state < 5) {
		put16(b, RAM_ADDR(death_counter_lo), count);
		if (count == 0x78)
			ram->pac_death_anim = 5;
		return;
	}
	if (state == 16) {
		ram->sprite[SPR_PAC].code = 0x3F;
		put16(b, RAM_ADDR(death_counter_lo), count);
		if (count != 0x1B8)
			return;
		ram->lives_real--;
		ram->lives_displayed--;
		clear_actor_positions(b);
		ram->level_state++;
		return;
	}
	if (state == 5)
		memset(ram->pos, 0, 4 * sizeof ram->pos[0]);
	else if (state == 6)
		ram->effect[2].num |= 0x10u;
	else if (state == 15)
		ram->effect[2].num = 0;
	code = (uint8_t)(0x34u + (state - 5u));
	until = state == 15 ? 0x159u : (uint16_t)(0xB4u + 15u * (state - 5u));
	/* Cocktail table only; out of scope for the port. */
	if ((ram->player_number & ram->dip_cocktail) != 0)
		code |= 0xC0u;
	ram->sprite[SPR_PAC].code = code;
	put16(b, RAM_ADDR(death_counter_lo), count);
	if (count == until)
		ram->pac_death_anim++;
}
