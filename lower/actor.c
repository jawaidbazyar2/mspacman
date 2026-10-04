/* Geometry shared by Ms. Pac-Man and the ghosts: direction steps, tiles,
 * the side tunnel, and the speed patterns. */
#include "game.h"

#define DIR_STEPS 0x32FFu /* Coord step per DIR_*, stored twice in a row */

/* rst $18 on the step table. Indexes 4-7 repeat 0-3. */
Coord dir_step(const Board *b, uint8_t dir)
{
	LOWER_HOOK(dir_step, b, dir);
	uint16_t at = (uint16_t)(DIR_STEPS + 2u * dir);
	Coord step = { rom8(b, at), rom8(b, (uint16_t)(at + 1u)) };

	return step;
}

/* $2000: bytewise, each half wraps on its own. */
Coord coord_add(Coord a, Coord b)
{
	LOWER_HOOK(coord_add, a, b);
	Coord sum = { (uint8_t)(a.y + b.y), (uint8_t)(a.x + b.x) };

	return sum;
}

bool coord_eq(Coord a, Coord b)
{
	LOWER_HOOK(coord_eq, a, b);
	return a.y == b.y && a.x == b.x;
}

/* The game sometimes adds positions as one 16-bit word, Y low. */
uint16_t coord_word(Coord c)
{
	LOWER_HOOK(coord_word, c);
	return (uint16_t)(c.y | (uint16_t)(c.x << 8));
}

Coord word_coord(uint16_t w)
{
	LOWER_HOOK(word_coord, w);
	Coord c = { (uint8_t)w, (uint8_t)(w >> 8) };

	return c;
}

/* $2018: the tile under a pixel position. */
Coord pos_to_tile(Coord pos)
{
	LOWER_HOOK(pos_to_tile, pos);
	Coord t = { (uint8_t)((pos.y >> 3) + 0x20u), (uint8_t)((pos.x >> 3) + 0x1Eu) };

	return t;
}

/* $0065: the video RAM cell for a tile. Color RAM is $400 above. */
uint16_t tile_cell(Coord t)
{
	LOWER_HOOK(tile_cell, t);
	uint8_t row = (uint8_t)(t.y - 0x20u);
	uint8_t col = (uint8_t)((uint8_t)(t.x - 0x20u) & 0x1Fu);

	return (uint16_t)(0x4040u + row + (uint16_t)(col << 5));
}

uint8_t tile_at(Board *b, Coord t)
{
	LOWER_HOOK(tile_at, b, t);
	return board_mem_read(b, tile_cell(t));
}

uint8_t color_at(Board *b, Coord t)
{
	LOWER_HOOK(color_at, b, t);
	return board_mem_read(b, (uint16_t)(tile_cell(t) + 0x400u));
}

/* Maze walls are the tiles with both top bits set. */
bool is_wall(uint8_t tile)
{
	LOWER_HOOK(is_wall, tile);
	return (tile & 0xC0u) == 0xC0u;
}

/* $1ED0: wrap an actor's mid tile through the side tunnel. Returns true
 * while it is in the tunnel, where no new direction is chosen. */
bool tunnel_wrap(WorkRam *ram, int actor)
{
	LOWER_HOOK(tunnel_wrap, ram, actor);
	uint8_t *x = &ram->mid_tile[actor].x;

	if (*x == 0x1D) {
		*x = 0x3D;
		return true;
	}
	if (*x == 0x3E) {
		*x = 0x1E;
		return true;
	}
	return *x < 0x21 || *x >= 0x3B;
}

/* Rotate the pattern left one bit. Returns the bit that came out. */
bool speed_tick(SpeedPattern *p)
{
	LOWER_HOOK(speed_tick, p);
	uint16_t hi = (uint16_t)(p->bits[0] | (uint16_t)(p->bits[1] << 8));
	uint16_t lo = (uint16_t)(p->bits[2] | (uint16_t)(p->bits[3] << 8));
	bool out = (hi & 0x8000u) != 0;

	hi = (uint16_t)((hi << 1) | (lo >> 15));
	lo = (uint16_t)((lo << 1) | (uint16_t)out);
	p->bits[0] = (uint8_t)hi;
	p->bits[1] = (uint8_t)(hi >> 8);
	p->bits[2] = (uint8_t)lo;
	p->bits[3] = (uint8_t)(lo >> 8);
	return out;
}
