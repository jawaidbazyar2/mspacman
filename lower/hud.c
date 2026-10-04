/* The start lamps and the blinking 1UP / 2UP labels. */
#include "game.h"

#define LAMP_P1    0x5004u /* latch: player-1 start lamp */
#define LAMP_P2    0x5005u /* latch: player-2 start lamp */
#define CELL_1UP   0x43D8u /* top row, "1UP" */
#define CELL_2UP   0x43C5u /* top row, "2UP" */

/* The top rows run right to left in video RAM, so "1UP" is stored "PU1". */
static void put_text(Board *b, uint16_t cell, const char *text)
{
	while (*text != 0)
		board_mem_write(b, cell++, (uint8_t)*text++);
}

static void draw_1up(Board *b)
{
	LOWER_HOOK(draw_1up, b);
	put_text(b, CELL_1UP, "PU1");
}

static void draw_2up(Board *b)
{
	LOWER_HOOK(draw_2up, b);
	put_text(b, CELL_2UP, "PU2");
}

static void clear_label(Board *b, uint16_t cell)
{
	LOWER_HOOK(clear_label, b, cell);
	put_text(b, cell, "\x40\x40\x40");
}

/* Every 16 frames, set the start lamps. One credit lights only player 1. */
static void update_lamps(Board *b, uint8_t counter)
{
	LOWER_HOOK(update_lamps, b, counter);
	WorkRam *ram = work_ram(b->mem);
	uint8_t lamp = (uint8_t)((uint8_t)~ram->start_button_wait | (counter >> 4));
	uint8_t p2 = lamp;

	if (ram->credits == 0) {
		lamp = 0;
		p2 = 0;
	} else if (ram->credits == 1)
		p2 = 0;
	board_mem_write(b, LAMP_P2, p2);
	board_mem_write(b, LAMP_P1, lamp);
}

/* $02FD  run from the vertical blank outside the power-on mode. */
void hud_blink(Board *b)
{
	LOWER_HOOK(hud_blink, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t counter = ++ram->coin_blink_counter;
	bool lit = (counter & 0x10u) == 0;

	if ((counter & 0x0Fu) == 0)
		update_lamps(b, counter);

	if (ram->game_mode != MODE_PLAY && ram->game_mode_sub2 < 2) {
		draw_1up(b);
		draw_2up(b);
		return;
	}
	/* The current player's label blinks. */
	if (ram->player_number == 0) {
		if (lit)
			draw_1up(b);
		else
			clear_label(b, CELL_1UP);
	} else if (lit)
		draw_2up(b);
	else
		clear_label(b, CELL_2UP);
	if (ram->num_players == 0)
		clear_label(b, CELL_2UP);
}
