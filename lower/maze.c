/* The maze: drawing walls and pills, its colors, the pill bitmap, and
 * the start positions of the actors. */
#include "game.h"

#define VIDEO       0x4000u
#define COLOR       0x4400u
#define MAZE_TOP    0x4040u /* first maze cell; rows above are the HUD */
#define MAZE_END    0x43C0u /* one past the last maze cell */

#define PILL        0x10u
#define PILL_BITS   30u     /* bitmap bytes, 8 pills each */

/* Per-maze word tables, one word per maze. */
#define MAZE_LAYOUTS     0x9474u
#define PILL_DELTAS      0x9499u
#define POWER_PILL_CELLS 0x951Cu
#define TUNNEL_CELLS     0x95DFu

#define MAZE_ORDER       0x94DFu /* level -> maze number */
#define MAZE_COLOR_ORDER 0x95AEu /* level -> wall color */

/* Levels below `first` index the table directly. Later levels repeat the
 * last `period` entries. The test is on the sign of the 8-bit difference,
 * so levels of `first` + 128 and up also index directly. */
static uint8_t level_slot(uint8_t level, uint8_t first, uint8_t period)
{
	uint8_t slot = (uint8_t)(level - first);

	if ((slot & 0x80u) != 0)
		return level;
	do
		slot = (uint8_t)(slot - period);
	while ((slot & 0x80u) == 0);
	return (uint8_t)(slot + first);
}

/* $94BD  this level's word in a per-maze table */
uint16_t maze_word(Board *b, uint16_t table)
{
	LOWER_HOOK(maze_word, b, table);
	uint8_t level = work_ram(b->mem)->level_number;
	uint8_t maze = rom8(b, (uint16_t)(MAZE_ORDER + level_slot(level, 13, 8)));

	return get16(b, (uint16_t)(table + (uint8_t)(maze * 2u)));
}

/* Address of the k-th power pill's screen cell for this maze. */
static uint16_t power_pill_cell(Board *b, unsigned k)
{
	LOWER_HOOK(power_pill_cell, b, k);
	return get16(b, (uint16_t)(maze_word(b, POWER_PILL_CELLS) + 2u * k));
}

/* $0C0D  blink the power pills every ten frames. Outside play, the two
 * pills on the attract screen blink instead. In play that path runs only
 * on the frame a life is lost, when the death animation has already
 * moved the level state on. The corpus only ever sees the pill unlit
 * there, so blanking a lit one is unverified. */
void flash_power_pills(Board *b)
{
	LOWER_HOOK(flash_power_pills, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t color;
	unsigned k;

	if (++ram->power_pill_flash_counter != 10)
		return;
	ram->power_pill_flash_counter = 0;

	if (ram->level_state != LEVEL_PLAYING) {
		color = board_mem_read(b, 0x4732) == PILL ? 0 : PILL;
		board_mem_write(b, 0x4732, color);
		board_mem_write(b, 0x4678, color);
		return;
	}
	color = board_mem_read(b, 0x447E);
	if (board_mem_read(b, (uint16_t)(power_pill_cell(b, 0) | 0x0400u)) == color)
		color = 0;
	for (k = 0; k < 4; k++)
		board_mem_write(b, (uint16_t)(power_pill_cell(b, k) | 0x0400u), color);
}

/* $2487  task $15: record which pills are still on screen */
void pill_bitmap(Board *b)
{
	LOWER_HOOK(pill_bitmap, b);
	WorkRam *ram = work_ram(b->mem);
	uint16_t delta = maze_word(b, PILL_DELTAS);
	uint16_t cell = VIDEO;
	unsigned i, bit;

	for (i = 0; i < PILL_BITS; i++) {
		uint8_t bits = 0;

		for (bit = 0; bit < 8; bit++) {
			cell = (uint16_t)(cell + rom8(b, delta++));
			bits = (uint8_t)((bits << 1) | (board_mem_read(b, cell) == PILL));
		}
		ram->pill_bitmap[i] = bits;
	}
	for (i = 0; i < 4; i++)
		ram->power_pill_data[i] = board_mem_read(b, power_pill_cell(b, i));
}

/* $24C9  task $12: every pill present */
void reset_pills(Board *b)
{
	LOWER_HOOK(reset_pills, b);
	WorkRam *ram = work_ram(b->mem);

	memset(ram->pill_bitmap, 0xFF, sizeof ram->pill_bitmap);
	memset(ram->power_pill_data, 0x14, sizeof ram->power_pill_data);
}

/* $2448  task $03: draw the pills the bitmap says are present */
void draw_pills(Board *b)
{
	LOWER_HOOK(draw_pills, b);
	WorkRam *ram = work_ram(b->mem);
	uint16_t delta = maze_word(b, PILL_DELTAS);
	uint16_t cell = VIDEO;
	unsigned i, bit;

	for (i = 0; i < PILL_BITS; i++) {
		uint8_t bits = ram->pill_bitmap[i];

		for (bit = 0; bit < 8; bit++) {
			cell = (uint16_t)(cell + rom8(b, delta++));
			if ((bits & 0x80u) != 0)
				board_mem_write(b, cell, PILL);
			bits = (uint8_t)(bits << 1);
		}
	}
	for (i = 0; i < 4; i++)
		board_mem_write(b, power_pill_cell(b, i), ram->power_pill_data[i]);
}

/* $2A35  task $13: blank every pill and power pill. Normally the board
 * is already empty; the rack-test switch leaves pills to blank. Tile
 * $12 never appears in the corpus. */
void erase_pills(Board *b)
{
	LOWER_HOOK(erase_pills, b);
	uint16_t cell;

	for (cell = MAZE_TOP; cell != MAZE_END; cell++) {
		uint8_t tile = board_mem_read(b, cell);

		if (tile == 0x10 || tile == 0x12 || tile == 0x14)
			board_mem_write(b, cell, TILE_BLANK);
	}
}

/* $240D  task $06 */
void clear_colors(Board *b)
{
	LOWER_HOOK(clear_colors, b);
	fill_bytes(b, COLOR, 0, 0x400);
}

/* $23ED  task $00: 0 blanks the whole screen, 1 only the maze */
void clear_screen(Board *b, uint8_t which)
{
	LOWER_HOOK(clear_screen, b, which);
	if (which == 1)
		fill_bytes(b, MAZE_TOP, TILE_BLANK, MAZE_END - MAZE_TOP);
	else
		fill_bytes(b, VIDEO, TILE_BLANK, 0x400);
}

/* $2419  task $02: draw the walls. The layout lists the left half as
 * (skip, tile) runs; each tile is mirrored onto the right half with
 * bit 0 flipped. */
void draw_maze(Board *b)
{
	LOWER_HOOK(draw_maze, b);
	uint16_t src = maze_word(b, MAZE_LAYOUTS);
	uint16_t cell = VIDEO;
	uint8_t tile;

	while ((tile = rom8(b, src)) != 0) {
		if ((tile & 0x80u) == 0) {
			cell = (uint16_t)(cell + tile - 1u);
			tile = rom8(b, ++src);
		}
		cell++;
		board_mem_write(b, cell, tile);
		board_mem_write(b, (uint16_t)(0x83E0u + 2u * (cell & 0x1Fu) - cell),
				(uint8_t)(tile ^ 1u));
		src++;
	}
}

/* Wall color: $1F for the flashing end of a board, 1 in some attract
 * screens, otherwise this level's color. */
static uint8_t wall_color(Board *b, uint8_t which)
{
	LOWER_HOOK(wall_color, b, which);
	WorkRam *ram = work_ram(b->mem);
	uint8_t sub = ram->game_mode_sub1;

	if (which == 2)
		return 0x1F;
	if (sub != 0 && sub != 0x10)
		return 0x01;
	return rom8(b, (uint16_t)(MAZE_COLOR_ORDER +
				  level_slot(ram->level_number, 21, 16)));
}

/* $24D7  task $01: 0 colors the maze, 1 also marks the tunnels as slow
 * and colors the ghost-house door, 2 is the end-of-board flash. */
void maze_colors(Board *b, uint8_t which)
{
	LOWER_HOOK(maze_colors, b, which);
	uint8_t level = work_ram(b->mem)->level_number;

	fill_bytes(b, (uint16_t)(COLOR + 0x40u), wall_color(b, which), 0x380);
	fill_bytes(b, 0x47C0, 0x0F, 0x40);
	if (which != 1)
		return;
	/* Bit 6 of a color byte marks a slow tunnel cell. Unverified past
	 * level 130: the signed compare treats those as early levels. */
	if (((uint8_t)(level - 3u) & 0x80u) != 0) {
		uint16_t list = maze_word(b, TUNNEL_CELLS);
		uint16_t cell = COLOR;
		uint8_t step;

		while ((step = rom8(b, list++)) != 0) {
			cell = (uint16_t)(cell + step);
			board_mem_write(b, cell, (uint8_t)(board_mem_read(b, cell) | 0x40u));
		}
	}
	board_mem_write(b, 0x45ED, 0x18);
	board_mem_write(b, 0x460D, 0x18);
}

/* $2698  task $07 */
void demo_mode(Board *b)
{
	LOWER_HOOK(demo_mode, b);
	WorkRam *ram = work_ram(b->mem);

	ram->game_mode = 1;
	ram->game_mode_sub0 = 0;
}

/* $26A2  task $11: zero $4D00..$4DFF */
void clear_actors(Board *b)
{
	LOWER_HOOK(clear_actors, b);
	fill_bytes(b, RAM_ADDR(pos), 0, 0x100);
}

/* $268B  task $05 */
void house_timer(Board *b, uint8_t param)
{
	LOWER_HOOK(house_timer, b, param);
	WorkRam *ram = work_ram(b->mem);

	ram->ghost_home_move_counter = 0x55;
	if (param != 1)
		ram->substate[ACT_RED] = 1;
}

static void set_coord(Coord *c, uint8_t y, uint8_t x)
{
	c->y = y;
	c->x = x;
}

/* $253D  task $04: 0 puts everyone at the start of play, any other
 * value lines them up for the attract-mode introduction. */
void place_actors(Board *b, uint8_t intro)
{
	LOWER_HOOK(place_actors, b, intro);
	static const uint8_t colors[6] = { 0x01, 0x03, 0x05, 0x07, 0x09, 0x00 };
	static const uint8_t codes[6] = { 0x20, 0x20, 0x20, 0x20, 0x2C, 0x3F };
	static const Coord play_pos[5] = {
		{ 0x64, 0x80 }, { 0x7C, 0x80 }, { 0x7C, 0x90 }, { 0x7C, 0x70 }, { 0xC4, 0x80 }
	};
	static const Coord play_tile[5] = {
		{ 0x2C, 0x2E }, { 0x2F, 0x2E }, { 0x2F, 0x30 }, { 0x2F, 0x2C }, { 0x38, 0x2E }
	};
	static const Coord play_step[5] = {
		{ 0x00, 0x01 }, { 0x01, 0x00 }, { 0xFF, 0x00 }, { 0xFF, 0x00 }, { 0x00, 0x01 }
	};
	static const uint8_t play_dir[4] = { DIR_LEFT, DIR_DOWN, DIR_UP, DIR_UP };
	WorkRam *ram = work_ram(b->mem);
	unsigned i;

	for (i = 0; i < 6; i++) {
		ram->sprite[SPR_RED + i].code = codes[i];
		ram->sprite[SPR_RED + i].color = colors[i];
	}
	ram->pac_wanted_dir = DIR_LEFT;

	if (intro) {
		for (i = 0; i < 4; i++) {
			set_coord(&ram->pos[i], 0x94, 0x00);
			set_coord(&ram->mid_tile[i], 0x32, 0x1E);
			set_coord(&ram->tile[i], 0x32, 0x1E);
		}
		for (i = 0; i < 5; i++) {
			set_coord(&ram->step[i], 0x00, 0x01);
			set_coord(&ram->next_step[i], 0x00, 0x01);
		}
		memset(ram->prev_dir, DIR_LEFT, sizeof ram->prev_dir);
		memset(ram->dir, DIR_LEFT, sizeof ram->dir);
		set_coord(&ram->pos[ACT_PAC], 0x94, 0x08);
		set_coord(&ram->mid_tile[ACT_PAC], 0x32, 0x1F);
		set_coord(&ram->tile[ACT_PAC], 0x32, 0x1F);
		return;
	}
	for (i = 0; i < 5; i++) {
		ram->pos[i] = play_pos[i];
		ram->mid_tile[i] = play_tile[i];
		ram->tile[i] = play_tile[i];
		ram->step[i] = play_step[i];
		ram->next_step[i] = play_step[i];
	}
	for (i = 0; i < 4; i++) {
		ram->prev_dir[i] = play_dir[i];
		ram->dir[i] = play_dir[i];
	}
	ram->dir[ACT_PAC] = DIR_LEFT;
	set_coord(&ram->fruit_pos, 0, 0);
}
