/* Sprite positions and codes for the next vertical blank. */
#include "game.h"

#define PAC_DIR_TABLE 0x1514u /* jump per direction to the mouth frames */

/* The hardware sprite origin differs by slot. */
static const uint8_t k_upright_dx[6] = {6, 6, 7, 7, 7, 7};
static const uint8_t k_cocktail_dx[6] = {7, 7, 8, 8, 8, 8};

static bool p2_cocktail(const WorkRam *ram)
{
	return (ram->player_number & ram->dip_cocktail) != 0;
}

/* Actor positions, then the fruit, in sprite slots 1-6. */
static const Coord *slot_pos(const WorkRam *ram, unsigned i)
{
	return i < 5 ? &ram->pos[i] : &ram->fruit_pos;
}

static void place_upright(WorkRam *ram)
{
	unsigned i;

	for (i = 0; i < 6; i++) {
		const Coord *p = slot_pos(ram, i);
		SpritePos *s = &ram->sprite_pos[i + 1];

		s->y = (uint8_t)((uint8_t)~p->y + 9u);
		s->x = (uint8_t)(p->x + k_upright_dx[i]);
	}
}

/* Player 2 on a cocktail table sees the screen upside down. Cocktail
 * tables are out of scope for the port, so the cocktail paths in this
 * file are kept for the ROM's behavior but never tested. */
static void place_cocktail(WorkRam *ram)
{
	unsigned i;

	for (i = 0; i < 6; i++) {
		const Coord *p = slot_pos(ram, i);
		SpritePos *s = &ram->sprite_pos[i + 1];

		s->y = (uint8_t)(p->y + 8u);
		s->x = (uint8_t)((uint8_t)~p->x + k_cocktail_dx[i]);
	}
}

/* Ms. Pac-Man's mouth follows the low bits of her position along the
 * direction of travel. An odd frame is open; an even one is `closed`. */
static void pac_frame(WorkRam *ram, uint8_t coord, bool invert, uint8_t base,
		      uint8_t closed)
{
	uint8_t phase = (uint8_t)((coord & 7u) >> 1);
	uint8_t code;

	if (invert)
		phase = (uint8_t)~phase;
	code = (uint8_t)(phase + base);
	ram->sprite[SPR_PAC].code = (code & 1u) ? code : closed;
}

/* $869C, $86B1, $86C5, $86D9 by direction. Other values pick nothing;
 * the direction is always 0-3, so the default is dead. */
static void face_pac(Board *b, WorkRam *ram)
{
	const Coord *pac = &ram->pos[ACT_PAC];

	switch (rom16(b, (uint16_t)(PAC_DIR_TABLE + (uint8_t)(ram->dir[ACT_PAC] << 1)))) {
	case 0x168C:
		pac_frame(ram, pac->x, true, 0x30, 0x37);
		break;
	case 0x16B1:
		pac_frame(ram, pac->y, false, 0x30, 0x34);
		break;
	case 0x16D6:
		pac_frame(ram, pac->x, false, 0xAC, 0x35);
		break;
	case 0x16F7:
		pac_frame(ram, pac->y, true, 0xF4, 0x36);
		break;
	default:
		break;
	}
}

/* Cocktail player 2: turn Ms. Pac-Man's sprite over. */
static void flip_pac(WorkRam *ram)
{
	uint8_t code = ram->sprite[SPR_PAC].code;

	if ((code & 0xC0u) == 0)
		ram->sprite[SPR_PAC].code = (uint8_t)(code | 0xC0u);
	else if (ram->dir[ACT_PAC] == DIR_LEFT && (code & 0x80u))
		ram->sprite[SPR_PAC].code = (uint8_t)(code ^ 0xC0u);
	else if (ram->dir[ACT_PAC] == DIR_UP && (code & 0x40u))
		ram->sprite[SPR_PAC].code = (uint8_t)(code ^ 0xC0u);
}

/* Every ghost gets the blue frame. A ghost that is not blue and alive
 * then gets the frame for its direction. */
static void ghost_frames(WorkRam *ram)
{
	uint8_t phase = ram->ghost_anim_phase;
	unsigned g;

	for (g = ACT_RED; g <= ACT_ORANGE; g++)
		ram->sprite[g + 1].code = (uint8_t)(0x1C + phase);
	for (g = ACT_RED; g <= ACT_ORANGE; g++) {
		if (ram->ghost_state[g] == 0 && ram->frightened[g] != 0)
			continue;
		ram->sprite[g + 1].code = (uint8_t)((uint8_t)(ram->dir[g] << 1) + phase + 0x20u);
	}
}

/* $14FE  pick the sprite codes */
static void choose_codes(Board *b, WorkRam *ram, bool cocktail)
{
	if (ram->pac_death_anim == 0 && ram->ghosts_killed_pending == 0) {
		face_pac(b, ram);
		if (cocktail)
			flip_pac(ram);
	}
	if (ram->pac_death_anim != 0 || ram->ghosts_killed_pending == 0)
		ghost_frames(ram);
	cutscene1_sprites(b);
	cutscene2_sprites(b);
	cutscene3_sprites(b);
	if (cocktail) {
		unsigned i;

		for (i = SPR_RED; i <= SPR_FRUIT; i++)
			if (i != SPR_PAC)
				ram->sprite[i].code |= 0xC0u;
	}
}

/* $1490  upright: positions and codes */
void sprites_upright(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if (p2_cocktail(ram))
		return;
	place_upright(ram);
	choose_codes(b, ram, false);
}

/* $141F  cocktail player 2: positions and codes */
void sprites_cocktail(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if (!p2_cocktail(ram))
		return;
	place_cocktail(ram);
	choose_codes(b, ram, true);
}
