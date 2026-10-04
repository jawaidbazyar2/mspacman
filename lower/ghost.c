/* The ghosts: speed, stepping through the maze, life in the house, the
 * trip home as eyes, and the timers that release and reverse them. */
#include "game.h"

/* Pixel and tile landmarks around the house. */
static const Coord DOOR_POS = { 0x64, 0x80 };  /* eyes stop here, then drop in */
static const Coord EXIT_TILE = { 0x2C, 0x2E }; /* the tile above the door */
#define HOUSE_FLOOR_Y 0x80u /* eyes stop descending here */
#define BOB_TOP_Y     0x78u /* a waiting ghost bobs between these */
#define BOB_BOTTOM_Y  0x80u
#define CENTER_X      0x80u /* blue and orange slide here before climbing */

/* Where each ghost is parked once its eyes are home. */
static const Coord HOME_TILE[4] = {
	{ 0x2F, 0x2E }, { 0x2F, 0x2E }, { 0x2F, 0x30 }, { 0x2F, 0x2C }
};

/* Colour code of tiles where a ghost keeps going without a new choice. */
#define KEEP_COURSE_COLOR 0x1Au

/* $1EFE-$1F89: turn around. The return value is what the next compare
 * in bob_in_house sees: the attract scene byte, or during Pac-Man's
 * title chase the new direction. Ms. Pac-Man has no such chase, so
 * that branch is dead. */
static uint8_t reverse_ghost(Board *b, int g)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t turned = (uint8_t)(ram->prev_dir[g] ^ 2u);
	Coord step = dir_step(b, turned);

	ram->dir[g] = turned;
	ram->next_step[g] = step;
	if (ram->game_mode_sub1 != PACMAN_CHASE_SCENE)
		return ram->game_mode_sub1;
	ram->step[g] = step;
	ram->prev_dir[g] = turned;
	return turned;
}

/* $1BD8, $1CAF, $1D86, $1E5D: one pixel along the current step. In the
 * middle of a tile the ghost queues its targeting task, reverses if
 * asked to, and commits to the direction that task chose last time. */
static void ghost_step(Board *b, int g)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t along = ram->step[g].y == 0 ? ram->pos[g].x : ram->pos[g].y;

	if ((along & 0x07u) == 4) {
		if (!tunnel_wrap(ram, g)) {
			if (ram->frightened[g] != 0)
				queue_task(b, (uint8_t)(TASK_RED_FLEE + g), 0);
			else if (color_at(b, ram->mid_tile[g]) != KEEP_COURSE_COLOR)
				queue_task(b, (uint8_t)(TASK_RED_TARGET + g), 0);
		}
		if (ram->reverse[g] != 0) {
			ram->reverse[g] = 0;
			(void)reverse_ghost(b, g);
		}
		ram->mid_tile[g] = coord_add(ram->mid_tile[g], ram->next_step[g]);
		ram->step[g] = ram->next_step[g];
		ram->prev_dir[g] = ram->dir[g];
	}
	ram->pos[g] = coord_add(ram->pos[g], ram->step[g]);
	ram->tile[g] = pos_to_tile(ram->pos[g]);
}

/* $1B36, $1C4B, $1D22, $1DF9: step a live ghost that is out of the
 * house when its speed pattern says so. Red is out in any substate but
 * 0, and its speed follows Cruise Elroy. */
static void move_ghost(Board *b, int g)
{
	WorkRam *ram = work_ram(b->mem);
	SpeedPattern *speed = &ram->ghost_speed[3 * g];

	if (g == ACT_RED ? ram->substate[g] == HOUSE_WAIT : ram->substate[g] != HOUSE_OUT)
		return;
	if (ram->ghost_state[g] != GHOST_ALIVE)
		return;
	if (g == ACT_RED)
		update_elroy(b);
	ram->tunnel_slow[g] = (color_at(b, ram->tile[g]) & 0x40u) != 0 ? 1 : 0;
	if (ram->tunnel_slow[g] != 0)
		speed += SPEED_TUNNEL;
	else if (ram->frightened[g] != 0)
		speed += SPEED_BLUE;
	else if (g == ACT_RED && ram->cruise_elroy_2 != 0)
		speed = &ram->elroy2_speed;
	else if (g == ACT_RED && ram->cruise_elroy_1 != 0)
		speed = &ram->elroy1_speed;
	if (speed_tick(speed))
		ghost_step(b, g);
}

void move_ghosts(Board *b)
{
	LOWER_HOOK(move_ghosts, b);
	int g;

	for (g = ACT_RED; g <= ACT_ORANGE; g++)
		move_ghost(b, g);
}

/* Eyes: drop, slide, and the final park. Each moves one pixel and sets
 * both direction bytes. */
static void eyes_step(Board *b, int g, uint8_t dir)
{
	WorkRam *ram = work_ram(b->mem);

	ram->pos[g] = coord_add(ram->pos[g], dir_step(b, dir));
	ram->prev_dir[g] = dir;
	ram->dir[g] = dir;
}

/* $1101: the eyes siren stops once no ghost is eyes. */
static void park_eyes(Board *b, int g)
{
	WorkRam *ram = work_ram(b->mem);
	int i;

	ram->mid_tile[g] = HOME_TILE[g];
	ram->tile[g] = HOME_TILE[g];
	ram->substate[g] = HOUSE_WAIT;
	ram->ghost_state[g] = GHOST_ALIVE;
	ram->frightened[g] = 0;
	for (i = ACT_RED; i <= ACT_ORANGE; i++)
		if (ram->ghost_state[i] != GHOST_ALIVE)
			return;
	ram->effect[1].num = (uint8_t)(ram->effect[1].num & ~0x40u);
}

/* $1094, $109E, $10A8, $10B4: eaten ghosts fly to the door as eyes at
 * ghost speed, drop into the house, and blue and orange slide to their
 * own slots. Red and pink park in the middle. */
static void return_eyes(Board *b, int g)
{
	WorkRam *ram = work_ram(b->mem);
	bool side = g == ACT_BLUE || g == ACT_ORANGE;

	switch (ram->ghost_state[g]) {
	case EYES_TO_DOOR:
		ghost_step(b, g);
		if (coord_eq(ram->pos[g], DOOR_POS))
			ram->ghost_state[g]++;
		break;
	case EYES_DOWN:
		eyes_step(b, g, DIR_DOWN);
		if (ram->pos[g].y != HOUSE_FLOOR_Y)
			break;
		if (side)
			ram->ghost_state[g]++;
		else
			park_eyes(b, g);
		break;
	case EYES_SIDE:
		if (!side)
			break; /* dead: red and pink park before this state */
		eyes_step(b, g, g == ACT_BLUE ? DIR_LEFT : DIR_RIGHT);
		if (ram->pos[g].x != (g == ACT_BLUE ? 0x90u : 0x70u))
			break;
		ram->prev_dir[g] = DIR_DOWN;
		ram->dir[g] = DIR_DOWN;
		park_eyes(b, g);
		break;
	}
}

void return_all_eyes(Board *b)
{
	LOWER_HOOK(return_all_eyes, b);
	int g;

	for (g = ACT_RED; g <= ACT_ORANGE; g++)
		return_eyes(b, g);
}

/* $1066: the ghost Ms. Pac-Man just ate turns into eyes. Values past 4
 * are not stored by the game; the arithmetic is kept as it runs. */
void mark_eaten_ghost(Board *b)
{
	LOWER_HOOK(mark_eaten_ghost, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t k = ram->kill_ghost_state;

	if (k == 0)
		return;
	if (k <= 3) {
		ram->kill_ghost_state = 0;
		ram->ghost_state[k - 1] = EYES_TO_DOOR;
		return;
	}
	ram->ghost_state[ACT_ORANGE] = (uint8_t)(k - 3u);
	ram->kill_ghost_state = (uint8_t)(k - 4u);
}

/* Climb toward the door. At the top the ghost is out, heading left. */
static void climb_out(Board *b, int g)
{
	WorkRam *ram = work_ram(b->mem);

	eyes_step(b, g, DIR_UP);
	if (ram->pos[g].y != DOOR_POS.y)
		return;
	ram->mid_tile[g] = EXIT_TILE;
	ram->step[g] = dir_step(b, DIR_LEFT);
	ram->next_step[g] = ram->step[g];
	ram->prev_dir[g] = DIR_LEFT;
	ram->dir[g] = DIR_LEFT;
	ram->substate[g] = HOUSE_OUT;
}

/* Bob between two heights, turning at each. After a turn at the top,
 * the bottom compare sees reverse_ghost's return value, not Y. */
static void bob_in_house(Board *b, int g)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t a = ram->pos[g].y;

	if (a == BOB_TOP_Y)
		a = reverse_ghost(b, g);
	if (a == BOB_BOTTOM_Y)
		(void)reverse_ghost(b, g);
	ram->prev_dir[g] = ram->dir[g];
	ram->pos[g] = coord_add(ram->pos[g], ram->next_step[g]);
}

/* Blue and orange slide to the middle, then climb. */
static void slide_to_center(Board *b, int g)
{
	WorkRam *ram = work_ram(b->mem);

	eyes_step(b, g, g == ACT_BLUE ? DIR_RIGHT : DIR_LEFT);
	if (ram->pos[g].x == CENTER_X)
		ram->substate[g] = HOUSE_CLIMB;
}

/* $0C42: ghosts inside the house move on every other beat of a
 * rotating pattern, and not while an eaten ghost is on show. */
void move_in_house(Board *b)
{
	LOWER_HOOK(move_in_house, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t beat = ram->ghost_home_move_counter;
	int g;

	if (ram->ghosts_killed_pending != 0)
		return;
	beat = (uint8_t)((beat << 1) | (beat >> 7));
	ram->ghost_home_move_counter = beat;
	if ((beat & 0x01u) == 0)
		return;
	if (ram->substate[ACT_RED] == HOUSE_WAIT)
		climb_out(b, ACT_RED);
	for (g = ACT_PINK; g <= ACT_ORANGE; g++) {
		uint8_t sub = ram->substate[g];

		if (sub == HOUSE_OUT)
			continue;
		if (sub == HOUSE_WAIT)
			bob_in_house(b, g);
		else if (sub == HOUSE_SLIDE && g != ACT_PINK)
			slide_to_center(b, g);
		else
			climb_out(b, g);
	}
}

/* $2069, $208C, $20AF: pink, blue, then orange leave the house once
 * their pill counters reach the level's limits. After a death one
 * shared count is used; at 32 it hands back to the per-ghost counters
 * without releasing orange. */
void release_by_pills(Board *b)
{
	LOWER_HOOK(release_by_pills, b);
	static const uint8_t after_death[3] = { 7, 0x11, 0x20 };
	static const uint8_t released[3] = { HOUSE_CLIMB, HOUSE_SLIDE, HOUSE_SLIDE };
	WorkRam *ram = work_ram(b->mem);
	const uint8_t count[3] = {
		ram->pink_exit_counter, ram->blue_exit_counter, ram->orange_exit_counter
	};
	const uint8_t limit[3] = {
		ram->pink_exit_limit, ram->blue_exit_limit, ram->orange_exit_limit
	};
	int i;

	for (i = 0; i < 3; i++) {
		int g = ACT_PINK + i;

		if (ram->substate[g] != HOUSE_WAIT)
			continue;
		if (ram->died_this_level != 0) {
			if (ram->pills_after_death != after_death[i])
				continue;
			if (g == ACT_ORANGE) {
				ram->died_this_level = 0;
				ram->pills_after_death = 0;
				continue;
			}
		} else if (count[i] < limit[i]) {
			continue;
		}
		ram->substate[g] = released[i];
	}
}

/* $1B08: a pill counts toward the first ghost still waiting. Unverified
 * for pink, who has a zero limit and leaves before any pill. */
void count_house_pill(Board *b)
{
	LOWER_HOOK(count_house_pill, b);
	WorkRam *ram = work_ram(b->mem);

	if (ram->died_this_level != 0)
		ram->pills_after_death++;
	else if (ram->substate[ACT_ORANGE] != HOUSE_WAIT)
		return;
	else if (ram->substate[ACT_BLUE] != HOUSE_WAIT)
		ram->orange_exit_counter++;
	else if (ram->substate[ACT_PINK] != HOUSE_WAIT)
		ram->blue_exit_counter++;
	else
		ram->pink_exit_counter++;
}

/* $13DD: if Ms. Pac-Man stops eating for long enough, the next ghost
 * still waiting is let out. */
void release_idle_ghost(Board *b)
{
	LOWER_HOOK(release_idle_ghost, b);
	WorkRam *ram = work_ram(b->mem);
	uint16_t idle;

	if (ram->dots_eaten != ram->pills_since_pac_move) {
		put16(b, RAM_ADDR(ghost_leave_home_idle_lo), 0);
		return;
	}
	idle = (uint16_t)(get16(b, RAM_ADDR(ghost_leave_home_idle_lo)) + 1u);
	put16(b, RAM_ADDR(ghost_leave_home_idle_lo), idle);
	if (idle != get16(b, RAM_ADDR(ghost_leave_home_units_lo)))
		return;
	put16(b, RAM_ADDR(ghost_leave_home_idle_lo), 0);
	if (ram->substate[ACT_PINK] == HOUSE_WAIT)
		ram->substate[ACT_PINK] = HOUSE_CLIMB;
	else if (ram->substate[ACT_BLUE] == HOUSE_WAIT)
		ram->substate[ACT_BLUE] = HOUSE_SLIDE;
	else if (ram->substate[ACT_ORANGE] == HOUSE_WAIT)
		ram->substate[ACT_ORANGE] = HOUSE_SLIDE;
}

/* $0E23: the ghosts' two-frame animation flips every 8 frames. */
void ghost_anim_tick(Board *b)
{
	LOWER_HOOK(ghost_anim_tick, b);
	WorkRam *ram = work_ram(b->mem);

	if (++ram->frame_div8_counter != 8)
		return;
	ram->frame_div8_counter = 0;
	ram->ghost_anim_phase ^= 1u;
}

/* $0E36: when the level's timer reaches the next entry, every ghost
 * reverses. Ms. Pac-Man patched the index update to always store 1, so
 * only the first entry is ever used. Paused during a power pill. */
void reversal_timer(Board *b)
{
	LOWER_HOOK(reversal_timer, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t index = ram->ghost_orient_index;
	uint16_t count;

	if (ram->power_pill_active != 0 || index == 7)
		return;
	count = (uint16_t)(get16(b, RAM_ADDR(ghost_orient_counter_lo)) + 1u);
	put16(b, RAM_ADDR(ghost_orient_counter_lo), count);
	if (count != get16(b, (uint16_t)(RAM_ADDR(ghost_orient_table) + 2u * index)))
		return;
	ram->ghost_orient_index = 1;
	memset(ram->reverse, 1, 4);
}
