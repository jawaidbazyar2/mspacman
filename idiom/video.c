/* Host side: draw the tile and sprite hardware into a frame buffer. */
#include "lift.h"

#include <stdio.h>
#include <string.h>

/* Tile/sprite bit layouts match py/gen_shr_gfx.py (MAME pacman char/sprite).
 * Placement matches pacman_scan_rows and draw_sprites in MAME pacman_v.cpp.
 * The cabinet picture is that 288x224 frame rotated 90 degrees counter-clockwise.
 */

static const int TILE_X[8] = {64, 65, 66, 67, 0, 1, 2, 3};
static const int TILE_Y[8] = {0, 8, 16, 24, 32, 40, 48, 56};
static const int SPR_X[16] = {
	64, 65, 66, 67, 128, 129, 130, 131, 192, 193, 194, 195, 0, 1, 2, 3
};
static const int SPR_Y[16] = {
	0, 8, 16, 24, 32, 40, 48, 56, 256, 264, 272, 280, 288, 296, 304, 312
};

static int bit_at(const uint8_t *rom, size_t n, int bit)
{
	int byte = bit >> 3;
	if (byte < 0 || (size_t)byte >= n)
		return 0;
	return (rom[byte] >> (bit & 7)) & 1;
}

static int load_file(const char *path, uint8_t *dst, size_t n)
{
	FILE *f = fopen(path, "rb");
	if (!f)
		return 0;
	size_t got = fread(dst, 1, n, f);
	fclose(f);
	return got == n;
}

static void decode_tile(uint8_t dst[8][8], const uint8_t *rom, int index)
{
	int base = index * 16 * 8;
	for (int y = 0; y < 8; y++) {
		for (int x = 0; x < 8; x++) {
			/* After the frame rotation, tile columns are screen rows.
			 * Each group of four is stored bottom-up: 3,2,1,0 then 7,6,5,4. */
			int sx = x ^ 3;
			int b0 = base + TILE_Y[y] + TILE_X[sx];
			int b1 = b0 + 4;
			dst[y][x] = (uint8_t)(bit_at(rom, 0x1000, b0) |
					       (bit_at(rom, 0x1000, b1) << 1));
		}
	}
}

static void decode_sprite(uint8_t dst[16][16], const uint8_t *rom, int index)
{
	int base = index * 64 * 8;
	for (int y = 0; y < 16; y++) {
		for (int x = 0; x < 16; x++) {
			int sx = x ^ 3;
			int b0 = base + SPR_Y[y] + SPR_X[sx];
			int b1 = b0 + 4;
			dst[y][x] = (uint8_t)(bit_at(rom, 0x1000, b0) |
					       (bit_at(rom, 0x1000, b1) << 1));
		}
	}
}

static void prom_rgb(uint8_t byte, uint8_t rgb[3])
{
	int r = ((byte >> 0) & 1) * 0x21 + ((byte >> 1) & 1) * 0x47 + ((byte >> 2) & 1) * 0x97;
	int g = ((byte >> 3) & 1) * 0x21 + ((byte >> 4) & 1) * 0x47 + ((byte >> 5) & 1) * 0x97;
	int b = ((byte >> 6) & 1) * 0x51 + ((byte >> 7) & 1) * 0xAE;
	rgb[0] = (uint8_t)r;
	rgb[1] = (uint8_t)g;
	rgb[2] = (uint8_t)b;
}

void video_load(Board *b, const char *tile_path, const char *sprite_path,
		const char *color_path, const char *pal_path)
{
	uint8_t tiles[0x1000];
	uint8_t sprites[0x1000];
	uint8_t color[32];
	uint8_t pal[256];
	memset(&b->gfx, 0, sizeof b->gfx);
	for (int i = 0; i < 32; i++) {
		b->gfx.rgb[i][0] = (uint8_t)(i * 8);
		b->gfx.rgb[i][1] = (uint8_t)(255 - i * 8);
		b->gfx.rgb[i][2] = 0x40;
	}
	for (int i = 0; i < 256; i++)
		b->gfx.lookup[i] = (uint8_t)(i & 3);

	if (load_file(tile_path, tiles, sizeof tiles) &&
	    load_file(sprite_path, sprites, sizeof sprites)) {
		b->gfx.have_gfx = 1;
		for (int i = 0; i < 256; i++)
			decode_tile(b->gfx.tile[i], tiles, i);
		for (int i = 0; i < 64; i++)
			decode_sprite(b->gfx.sprite[i], sprites, i);
	}
	if (load_file(color_path, color, sizeof color) &&
	    load_file(pal_path, pal, sizeof pal)) {
		b->gfx.have_prom = 1;
		for (int i = 0; i < 32; i++)
			prom_rgb(color[i], b->gfx.rgb[i]);
		memcpy(b->gfx.lookup, pal, 256);
	}
}

static int scan_rows(int col, int row)
{
	row += 2;
	col -= 2;
	if (col & 0x20)
		return row + ((col & 0x1f) << 5);
	return col + (row << 5);
}

static void pen_rgb(Board *b, int color, int pen, uint8_t rgb[3])
{
	int idx = b->gfx.lookup[(color & 63) * 4 + (pen & 3)] & 0x0f;
	rgb[0] = b->gfx.rgb[idx][0];
	rgb[1] = b->gfx.rgb[idx][1];
	rgb[2] = b->gfx.rgb[idx][2];
}

static void put_mame(uint8_t *mame, int x, int y, const uint8_t rgb[3])
{
	if (x < 0 || y < 0 || x >= LIFT_FB_W || y >= LIFT_FB_H)
		return;
	uint8_t *p = mame + ((size_t)y * LIFT_FB_W + (size_t)x) * 3;
	p[0] = rgb[0];
	p[1] = rgb[1];
	p[2] = rgb[2];
}

static void draw_sprite(Board *b, uint8_t *mame, int offs, int yhack)
{
	int sx = 272 - b->spr2[offs + 1];
	int sy = (int)b->spr2[offs] - 31 + yhack;
	int code = (b->mem[0x4FF0 + offs] >> 2) & 63;
	int fx = b->mem[0x4FF0 + offs] & 1;
	int fy = (b->mem[0x4FF0 + offs] >> 1) & 1;
	int color = b->mem[0x4FF1 + offs] & 0x1f;
	/* Color 0 is all black. The game stores it to hide Ms. Pac-Man while the
	 * 200/400/800/1600 sprite is up; drawing it would cut her mouth out of the score. */
	if (color == 0)
		return;
	for (int y = 0; y < 16; y++) {
		for (int x = 0; x < 16; x++) {
			int sx0 = fx ? 15 - x : x;
			int sy0 = fy ? 15 - y : y;
			int pen = b->gfx.sprite[code][sy0][sx0];
			if (pen == 0)
				continue;
			int px = sx + x;
			int py = sy + y;
			if (py < 0 || py >= LIFT_FB_H)
				continue;
			if (px >= 16 && px < 34 * 8) {
				uint8_t rgb[3];
				pen_rgb(b, color, pen, rgb);
				put_mame(mame, px, py, rgb);
			}
			int wrap = px - 256;
			if (wrap >= 16 && wrap < 34 * 8) {
				uint8_t rgb[3];
				pen_rgb(b, color, pen, rgb);
				put_mame(mame, wrap, py, rgb);
			}
		}
	}
}

void video_render(Board *b, uint8_t *rgb, int pitch)
{
	uint8_t mame[LIFT_FB_W * LIFT_FB_H * 3];
	memset(mame, 0, sizeof mame);

	for (int col = 0; col < 36; col++) {
		for (int row = 0; row < 28; row++) {
			int idx = scan_rows(col, row);
			if (idx < 0 || idx >= 0x400)
				continue;
			int code = b->mem[0x4000 + idx];
			int color = b->mem[0x4400 + idx] & 0x1f;
			for (int y = 0; y < 8; y++) {
				for (int x = 0; x < 8; x++) {
					int pen = b->gfx.have_gfx ? b->gfx.tile[code][y][x] : (code ? 1 : 0);
					uint8_t c[3];
					if (!b->gfx.have_gfx && !b->gfx.have_prom) {
						c[0] = (uint8_t)(code * 3);
						c[1] = (uint8_t)(color * 8);
						c[2] = (uint8_t)(pen * 80);
					} else {
						pen_rgb(b, color, pen, c);
					}
					put_mame(mame, col * 8 + x, row * 8 + y, c);
				}
			}
		}
	}

	if (b->gfx.have_gfx) {
		for (int offs = 14; offs > 4; offs -= 2)
			draw_sprite(b, mame, offs, 0);
		for (int offs = 4; offs >= 0; offs -= 2)
			draw_sprite(b, mame, offs, 1);
	}

	if (b->latch[3]) {
		for (int y = 0; y < LIFT_FB_H / 2; y++) {
			for (int x = 0; x < LIFT_FB_W; x++) {
				uint8_t *a = mame + ((size_t)y * LIFT_FB_W + (size_t)x) * 3;
				uint8_t *c = mame + ((size_t)(LIFT_FB_H - 1 - y) * LIFT_FB_W +
						     (size_t)(LIFT_FB_W - 1 - x)) * 3;
				uint8_t t0 = a[0], t1 = a[1], t2 = a[2];
				a[0] = c[0]; a[1] = c[1]; a[2] = c[2];
				c[0] = t0; c[1] = t1; c[2] = t2;
			}
		}
	}

	for (int sy = 0; sy < LIFT_FB_H; sy++) {
		for (int sx = 0; sx < LIFT_FB_W; sx++) {
			int dx = LIFT_FB_H - 1 - sy;
			int dy = sx;
			const uint8_t *s = mame + ((size_t)sy * LIFT_FB_W + (size_t)sx) * 3;
			uint8_t *d = rgb + (size_t)dy * (size_t)pitch + (size_t)dx * 3;
			d[0] = s[0];
			d[1] = s[1];
			d[2] = s[2];
		}
	}
}
