/* Attract mode: the marquee with its chasing bulbs, the cast
 * introduction, then the demo game. */
#include "game.h"

#define BULB_CELLS 0x3F81u /* six bulb-cell words, 16 bytes apart */

/* Script sets for the cast walks ($3483..$3497) */
enum {
	WALK_BLINKY = 0x24,
	WALK_PINKY = 0x30,
	WALK_INKY = 0x3C,
	WALK_SUE = 0x48,
	WALK_MS_PAC = 0x54,
};

/* $3ED0  move the lit bulbs one step around the marquee. On odd steps
 * six bulbs are lit; on even steps those dim and the next six light. */
static void marquee_bulbs(Board *b)
{
	static const uint8_t lit[6] = { 0x87, 0x87, 0x8A, 0x81, 0x81, 0x84 };
	static const uint8_t next[6] = { 0x88, 0x88, 0x8B, 0x82, 0x82, 0x83 };
	WorkRam *ram = work_ram(b->mem);
	uint8_t step = (uint8_t)((ram->marquee_step + 1u) & 0x0Fu);
	uint16_t cells;
	unsigned i;

	ram->marquee_step = step;
	if ((step & 1u) != 0) {
		cells = (uint16_t)(BULB_CELLS + (step & 0xFEu));
		for (i = 0; i < 6; i++)
			board_mem_write(b, rom16(b, (uint16_t)(cells + 16u * i)), lit[i]);
		return;
	}
	cells = (uint16_t)(BULB_CELLS + step - 2u);
	for (i = 0; i < 6; i++) {
		uint16_t dim = rom16(b, (uint16_t)(cells + 16u * i));

		board_mem_write(b, dim, (uint8_t)(board_mem_read(b, dim) - 1u));
		board_mem_write(b, rom16(b, (uint16_t)(cells + 16u * i + 2u)), next[i]);
	}
}

/* $9642  queue the copyright lines and draw the Midway logo: a 4x4
 * block of tiles $B0..$BF, color 1. */
void draw_midway_logo(Board *b)
{
	uint16_t cell = 0x429A;
	uint8_t tile = 0xBF;
	unsigned row, col;

	queue_task(b, TASK_TEXT, 0x13);
	queue_task(b, TASK_TEXT, 0x35);
	for (row = 0; row < 4; row++) {
		for (col = 0; col < 4; col++) {
			board_mem_write(b, cell, tile);
			board_mem_write(b, (uint16_t)(cell + 0x400u), 1);
			if (col != 3) {
				cell++;
				tile = (uint8_t)(tile - 4u);
			}
		}
		cell = (uint16_t)(cell + 0x1Du);
		tile = (uint8_t)(tile + 0x0Bu);
	}
}

static void show_card(Board *b, uint8_t text)
{
	queue_task(b, TASK_TEXT, text);
	advance_attract_state(b);
}

/* $045F  clear the screen and show "MS PAC-MAN" for ten units */
static void open_marquee(Board *b)
{
	queue_task(b, TASK_CLEAR_SCREEN, 1);
	queue_task(b, TASK_MAZE_COLORS, 0);
	queue_task(b, TASK_PLACE_ACTORS, 0);
	queue_task(b, TASK_CLEAR_SPRITES, 0);
	queue_task(b, TASK_TEXT, 0x0C);
	if (queue_timed(b, TIMER(1, 0x0A), TT_ATTRACT_STATE, 0))
		advance_attract_state(b);
}

/* $3E5C  one step of the attract sequence, selected by game_mode_sub1.
 * The walks (steps 6, 8, 10, 12, 15) advance on their own when the
 * actor reaches its mark; step 3 waits for the timed task. */
void attract_step(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if (ram->game_mode_sub1 != 0x10)
		marquee_bulbs(b);
	switch (ram->game_mode_sub1) {
	case 0:
		open_marquee(b);
		break;
	case 1:
		draw_midway_logo(b);
		advance_attract_state(b);
		break;
	case 2:
		queue_task(b, TASK_TEXT, 0x0C);
		ram->marquee_step = 0x60;
		advance_attract_state(b);
		break;
	case 4:
		show_card(b, 0x0E); /* "WITH" */
		break;
	case 5:
		show_card(b, 0x0D);
		break;
	case 6:
		run_cutscene(b, WALK_BLINKY);
		break;
	case 7:
		queue_task(b, TASK_TEXT, 0x30);
		show_card(b, 0x0F);
		break;
	case 8:
		run_cutscene(b, WALK_PINKY);
		break;
	case 9:
		show_card(b, 0x2F);
		break;
	case 10:
		run_cutscene(b, WALK_INKY);
		break;
	case 11:
		show_card(b, 0x31);
		break;
	case 12:
		run_cutscene(b, WALK_SUE);
		break;
	case 13:
		show_card(b, 0x10);
		break;
	case 14:
		show_card(b, 0x33);
		break;
	case 15:
		run_cutscene(b, WALK_MS_PAC);
		break;
	case 16:
		/* $3EC9: the demo game */
		ram->lives_real = 0;
		level_step(b);
		break;
	default:
		break;
	}
}
