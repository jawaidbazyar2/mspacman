/* Screen drawing: 2x2 blocks, the fruit row, and the message table. */
#include "game.h"

#define COLOR_RAM    0x0400u /* color cell = video cell + $400 */
#define FRUIT_TABLE  0x3B08u /* tile, color per fruit */
#define FRUIT_ROW    0x4004u /* bottom row, rightmost fruit slot */
#define MESSAGES     0x36A5u /* pointer per message */
#define MARK_TILES   0x9616u /* the Ms. Pac-Man mark in the bonus line */
#define DSW1         0x5080u
#define MSG_END      0x2Fu   /* '/' ends a message's text */
/* A 2x2 block of one tile. Rows are $20 cells apart. */
void draw_block(Board *b, uint16_t cell, uint8_t tile)
{
	board_mem_write(b, cell, tile);
	board_mem_write(b, (uint16_t)(cell + 1u), tile);
	board_mem_write(b, (uint16_t)(cell + 0x20u), tile);
	board_mem_write(b, (uint16_t)(cell + 0x21u), tile);
}

/* A 2x2 picture made of four consecutive tiles. */
void draw_icon(Board *b, uint16_t cell, uint8_t tile)
{
	board_mem_write(b, cell, tile);
	board_mem_write(b, (uint16_t)(cell + 1u), (uint8_t)(tile + 1u));
	board_mem_write(b, (uint16_t)(cell + 0x20u), (uint8_t)(tile + 2u));
	board_mem_write(b, (uint16_t)(cell + 0x21u), (uint8_t)(tile + 3u));
}

/* $2BEA  task $1B: one fruit per level up to seven, then blanks.
 * The attract mode leaves the row alone. */
void draw_fruit_row(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	unsigned fruits;
	unsigned i;
	uint16_t cell = FRUIT_ROW;

	if (ram->game_mode == MODE_ATTRACT)
		return;
	fruits = ram->level_number + 1u;
	if (fruits > 7)
		fruits = 7;
	for (i = 0; i < 7; i++, cell = (uint16_t)(cell + 2u)) {
		if (i < fruits) {
			uint16_t entry = (uint16_t)(FRUIT_TABLE + 2u * i);

			draw_icon(b, cell, rom8(b, entry));
			draw_block(b, (uint16_t)(cell + COLOR_RAM), rom8(b, (uint16_t)(entry + 1u)));
		} else {
			draw_block(b, cell, TILE_BLANK);
			draw_block(b, (uint16_t)(cell + COLOR_RAM), 0);
		}
	}
}

/* $2C5E  draw message `n` from the table. Bit 7 of `n` erases it.
 *
 * A message is a screen offset, the text up to '/', then the colors.
 * A first color byte with bit 7 set colors every cell; otherwise there is
 * one color per cell. Text runs left to right: down the column-major
 * video RAM ($-20 per cell), or one cell back on the top and bottom rows.
 */
void draw_message(Board *b, uint8_t n)
{
	uint16_t rec = rom16(b, (uint16_t)(MESSAGES + (uint8_t)(n << 1)));
	uint16_t offset = rom16(b, rec);
	uint16_t color = (uint16_t)(0x4400u + offset);
	uint16_t video = (uint16_t)(color - COLOR_RAM);
	uint16_t step = (offset & 0x8000u) ? 0xFFFFu : 0xFFE0u;
	uint16_t p = (uint16_t)(rec + 2u);
	uint8_t count = 0;
	uint8_t first;
	unsigned left;

	for (; board_mem_read(b, p) != MSG_END; p++, count++) {
		board_mem_write(b, video, (n & 0x80u) ? TILE_BLANK : board_mem_read(b, p));
		video = (uint16_t)(video + step);
	}
	p++;
	if (n & 0x80u) {
		/* The erase path skips a second '/'-terminated string with
		 * CPIR. The color count becomes the high byte of the CPIR
		 * counter, which started at (count + 1) << 8. */
		uint16_t bc = (uint16_t)((uint8_t)(count + 1u) << 8);

		do
			bc--;
		while (board_mem_read(b, p++) != MSG_END && bc != 0);
		count = (uint8_t)(bc >> 8);
	}

	first = board_mem_read(b, p);
	left = count == 0 ? 256u : count;
	for (; left != 0; left--) {
		if (first & 0x80u)
			board_mem_write(b, color, first);
		else
			board_mem_write(b, color, board_mem_read(b, p++));
		color = (uint16_t)(color + step);
	}
}

/* Records of color, tile, and cell address, ending with $FF. */
static void draw_tile_list(Board *b, uint16_t p)
{
	uint8_t color;

	while ((color = board_mem_read(b, p)) != 0xFF) {
		uint8_t tile = board_mem_read(b, (uint16_t)(p + 1u));
		uint16_t cell = get16(b, (uint16_t)(p + 2u));

		board_mem_write(b, cell, tile);
		board_mem_write(b, (uint16_t)(cell | COLOR_RAM), color);
		p = (uint16_t)(p + 4u);
	}
}

/* $95E3  task $1C: draw a message, with three extras.
 * $0A also draws the mark in the bonus line. $0B draws the Midway logo
 * first and becomes $20 when the dip switch turns the bonus life off
 * (unverified; every session has a bonus life). $06 clears the
 * intermission flag. */
void text_task(Board *b, uint8_t n)
{
	if (n == 0x0A)
		draw_tile_list(b, MARK_TILES);
	else if (n == 0x0B) {
		draw_midway_logo(b);
		if ((board_mem_read(b, DSW1) & 0x30u) == 0x30u)
			n = 0x20;
	} else if (n == 0x06)
		work_ram(b->mem)->intermission_flag = 0;
	draw_message(b, n);
}
