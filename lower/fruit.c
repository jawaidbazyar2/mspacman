/* The bouncing fruit: when it appears, the path it takes, and its exit. */
#include "game.h"

#define FRUIT_TYPES   0x879Du /* code, color, points per fruit */
#define ENTRY_PATHS   0x87F8u /* per-maze lists of entry paths */
#define EXIT_PATHS    0x8800u /* per-maze lists of exit paths */
#define HOUSE_PATH    0x8808u /* loop around the ghost house */
#define BOUNCE_STEPS  0x8841u /* position delta per bounce step */

/* Clear the fruit ($1000): no fruit is worth points. */
void clear_fruit(Board *b)
{
	LOWER_HOOK(clear_fruit, b);
	work_ram(b->mem)->fruit_points = 0;
}

/* Clear the fruit position ($3678, reached from timed task 5 at $100B). */
void clear_fruit_pos(Board *b)
{
	LOWER_HOOK(clear_fruit_pos, b);
	WorkRam *ram = work_ram(b->mem);

	ram->fruit_pos.y = 0;
	ram->fruit_pos.x = 0;
}

static uint16_t path_ptr(const WorkRam *ram)
{
	return (uint16_t)(ram->fruit_path_ptr | (uint16_t)(ram->fruit_path_ptr_hi << 8));
}

static void set_path(WorkRam *ram, uint16_t path, uint8_t length)
{
	ram->fruit_path_ptr = (uint8_t)path;
	ram->fruit_path_ptr_hi = (uint8_t)(path >> 8);
	ram->fruit_path_index = length;
	ram->fruit_bounce_index = 0x1F;
}

/* $87CD  start one of this maze's four paths at random. Each 5-byte
 * entry is the path pointer, its length, and the fruit's start position.
 * Returns the entry. */
static uint16_t choose_path(Board *b, uint16_t table)
{
	LOWER_HOOK(choose_path, b, table);
	uint16_t list = maze_word(b, table);
	uint8_t pick = (uint8_t)(lift_random_byte(b) & 0x03u);
	uint16_t entry = (uint16_t)(list + (uint8_t)(pick * 5u));

	set_path(work_ram(b->mem), rom16(b, entry), rom8(b, (uint16_t)(entry + 2u)));
	return entry;
}

/* $8747  a fruit comes out after 64 and after 176 pills. From level 7
 * the fruit is random. Unverified: a fruit gone again before the next
 * pill (the released flag stops a second one). */
static void release_fruit(Board *b)
{
	LOWER_HOOK(release_fruit, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t *released;
	uint8_t fruit;
	uint16_t type;
	uint16_t entry;

	if (ram->dots_eaten == 0x40)
		released = &ram->fruit1_released;
	else if (ram->dots_eaten == 0xB0)
		released = &ram->fruit2_released;
	else
		return;
	if (*released != 0)
		return;
	*released = 1;

	fruit = ram->level_number;
	if (fruit >= 7)
		fruit = (uint8_t)((lift_random_byte(b) & 0x1Fu) % 7u);
	type = (uint16_t)(FRUIT_TYPES + (uint8_t)(fruit * 3u));
	ram->sprite[SPR_FRUIT].code = rom8(b, type);
	ram->sprite[SPR_FRUIT].color = rom8(b, (uint16_t)(type + 1u));
	ram->fruit_points = rom8(b, (uint16_t)(type + 2u));

	entry = choose_path(b, ENTRY_PATHS);
	ram->fruit_pos.y = rom8(b, (uint16_t)(entry + 3u));
	ram->fruit_pos.x = rom8(b, (uint16_t)(entry + 4u));
}

/* The path packs four 2-bit directions per byte, low bits first. The
 * direction picks a 16-step bounce from BOUNCE_STEPS. */
static void next_bounce(Board *b, uint8_t index)
{
	LOWER_HOOK(next_bounce, b, index);
	WorkRam *ram = work_ram(b->mem);
	uint8_t packed = rom8(b, (uint16_t)(path_ptr(ram) + (index >> 2)));
	uint8_t dir = (uint8_t)((packed >> (2u * (index & 3u))) & 0x03u);

	ram->effect[2].num = (uint8_t)(ram->effect[2].num | 0x20u);
	ram->fruit_bounce_index = (uint8_t)(dir << 4);
}

/* $87B5  the path is done. Off screen, the fruit goes away. Otherwise
 * it circles the ghost house, then takes one of the exit paths. */
static void end_of_path(Board *b)
{
	LOWER_HOOK(end_of_path, b);
	WorkRam *ram = work_ram(b->mem);

	if ((uint8_t)(ram->fruit_pos.x + 0x20u) < 0x40u) {
		ram->sprite[SPR_FRUIT].color = 0;
		clear_fruit(b);
		return;
	}
	if (path_ptr(ram) != HOUSE_PATH) {
		set_path(ram, HOUSE_PATH, 0x1D);
		return;
	}
	(void)choose_path(b, EXIT_PATHS);
}

/* $86EE  one frame of the fruit, reached from $0EAD. It stands still
 * while a ghost-eaten pause is pending. Unverified: a fruit with points
 * but no position. */
void move_fruit(Board *b)
{
	LOWER_HOOK(move_fruit, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t step;
	uint16_t pos;
	uint8_t index;

	if (ram->ghosts_killed_pending != 0)
		return;
	if (ram->fruit_points == 0 || ram->fruit_pos.y == 0) {
		release_fruit(b);
		return;
	}

	step = ram->fruit_bounce_index;
	pos = (uint16_t)(rom16(b, (uint16_t)(BOUNCE_STEPS + (uint8_t)(step * 2u))) +
			 (ram->fruit_pos.y | (uint16_t)(ram->fruit_pos.x << 8)));
	ram->fruit_pos.y = (uint8_t)pos;
	ram->fruit_pos.x = (uint8_t)(pos >> 8);
	ram->fruit_bounce_index = (uint8_t)(step + 1u);
	if (((step + 1u) & 0x0Fu) != 0)
		return;

	index = --ram->fruit_path_index;
	if ((index & 0x80u) != 0)
		end_of_path(b);
	else
		next_bounce(b, index);
}
