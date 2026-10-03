/* Cutscenes and the attract-mode walks. Six actors each follow a small
 * script: Blinky, Pinky, Inky, Sue, Ms. Pac-Man, and the fruit slot.
 * The ROM numbers them 6..1 and runs 6 first; `a` here is that minus 1. */
#include "game.h"

#define SCRIPTS 0x81F0u /* 12-byte sets of six script pointers */

enum {
	CMD_MOVE = 0xF0,      /* dx, dy, color: move and animate, see CMD_COUNT */
	CMD_PLACE = 0xF1,     /* x, y */
	CMD_COUNT = 0xF2,     /* n: frames for the next MOVE or WAIT */
	CMD_ANIM = 0xF3,      /* lo, hi: animation table */
	CMD_SOUND = 0xF5,     /* effect 3 bits */
	CMD_WAIT = 0xF6,
	CMD_ERASE_WITH = 0xF7,
	CMD_ERASE_ACT = 0xF8,
	CMD_END = 0xFF,
};

/* The sprite hooks below belong to Pac-Man's three intermissions. Their
 * states ($4E06-$4E08) are Pac-Man only: Ms. Pac-Man's acts use the
 * scripts further down, so these never get past their first test. */

/* At tile column $3D Ms. Pac-Man's sprite goes black. */
static void hide_pac_at_edge(WorkRam *ram)
{
	if (ram->tile[ACT_PAC].x == 0x3D)
		ram->sprite[SPR_PAC].color = 0;
}

/* $162D  second-cutscene sprite codes */
void cutscene2_sprites(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t state = ram->cutscene2_state;

	if (state == 0)
		return;
	hide_pac_at_edge(ram);
	if (state < 0x0A)
		return;
	ram->sprite[SPR_RED].code = state < 0x0C ? 0x32 : 0x33;
	ram->sprite[SPR_RED].color = 0x1D;
}

/* $039D  first cutscene, from state 5: the big Pac-Man is four sprites
 * (pink, blue, orange, fruit) in a square around Ms. Pac-Man's position. */
void cutscene1_positions(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t y = ram->pos[ACT_PAC].y;
	uint8_t x = (uint8_t)(ram->pos[ACT_PAC].x + 8u);

	if (ram->cutscene1_state < 5)
		return;
	ram->pos[ACT_ORANGE].y = y;
	ram->fruit_pos.y = y;
	ram->pos[ACT_PINK].y = (uint8_t)(y - 0x10u);
	ram->pos[ACT_BLUE].y = (uint8_t)(y - 0x10u);
	ram->pos[ACT_PINK].x = x;
	ram->pos[ACT_ORANGE].x = x;
	ram->pos[ACT_BLUE].x = (uint8_t)(x - 0x10u);
	ram->fruit_pos.x = (uint8_t)(x - 0x10u);
}

/* $1652  third-cutscene sprite codes */
void cutscene3_sprites(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t state = ram->cutscene3_state;
	uint8_t code;

	if (state == 0)
		return;
	hide_pac_at_edge(ram);
	ram->sprite[SPR_RED].code = (uint8_t)(ram->ghost_anim_phase + 8u);
	if (state < 3)
		return;
	code = (uint8_t)(((ram->pos[ACT_RED].x & 0x08u) >> 3) + 0x0Au);
	ram->sprite[SPR_FRUIT].code = code;
	ram->sprite[SPR_RED].code = (uint8_t)(code + 2u);
	ram->sprite[SPR_FRUIT].color = 0x1E;
}

/* $15E6  first cutscene, from state 5: the big Pac-Man's four quarters.
 * The frame follows his X position. Ms. Pac-Man's own sprite is hidden. */
void cutscene1_sprites(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t phase;
	uint8_t tile;

	if (ram->cutscene1_state < 5)
		return;
	phase = (uint8_t)(ram->pos[ACT_PAC].x & 0x0Fu);
	tile = phase >= 0x0C ? 0x18 : phase >= 0x08 ? 0x14 : phase >= 0x04 ? 0x10 : 0x14;
	ram->sprite[SPR_PINK].code = tile;
	ram->sprite[SPR_BLUE].code = (uint8_t)(tile + 1u);
	ram->sprite[SPR_ORANGE].code = (uint8_t)(tile + 2u);
	ram->sprite[SPR_FRUIT].code = (uint8_t)(tile + 3u);
	ram->sprite[SPR_PAC].code = 0x3F;
	ram->sprite[SPR_PINK].color = 0x16;
	ram->sprite[SPR_BLUE].color = 0x16;
	ram->sprite[SPR_ORANGE].color = 0x16;
	ram->sprite[SPR_FRUIT].color = 0x16;
}

static uint16_t word_of(const uint8_t *pair)
{
	return (uint16_t)(pair[0] | (uint16_t)(pair[1] << 8));
}

/* Actors 0-4 are the ghost and Ms. Pac-Man slots; 5 uses the fruit. */
static Coord *actor_pos(WorkRam *ram, unsigned a)
{
	return a == 5 ? &ram->fruit_pos : &ram->pos[a];
}

/* $3556  add a 1/16-pixel speed into an accumulator. Returns the whole
 * pixels to move; the remainder keeps the sign of the sum and stays in
 * -16..15. */
static uint8_t carry_pixels(uint8_t *frac, uint8_t speed)
{
	uint8_t sum = (uint8_t)(*frac + speed);
	uint8_t whole = (uint8_t)((sum >> 4) | ((sum & 0x80u) ? 0xF0u : 0u));

	if ((sum & 0x80u) != 0) {
		*frac = (uint8_t)(sum | 0xF0u);
		whole++;
	} else {
		*frac = (uint8_t)(sum & 0x0Fu);
	}
	return whole;
}

/* $34E0  move by (dx, dy)/16 and show the next animation frame. Returns
 * the script advance: 4 when the count runs out, else 0 to repeat. */
static uint16_t cmd_move(Board *b, unsigned a, uint16_t s)
{
	WorkRam *ram = work_ram(b->mem);
	Coord *pos = actor_pos(ram, a);
	uint16_t anim = word_of(&ram->cutscene_anim[2 * a]);
	uint8_t frame = (uint8_t)(ram->cutscene_frame[a] + 1u);
	uint8_t code;

	pos->x = (uint8_t)(pos->x + carry_pixels(&ram->cutscene_frac[a].x,
						 board_mem_read(b, (uint16_t)(s + 1u))));
	pos->y = (uint8_t)(pos->y + carry_pixels(&ram->cutscene_frac[a].y,
						 board_mem_read(b, (uint16_t)(s + 2u))));

	/* Each table entry shows for two frames; $FF loops to the start. */
	code = board_mem_read(b, (uint16_t)(anim + (uint8_t)((frame >> 1) | (frame & 0x80u))));
	if (code == 0xFF) {
		frame = 0;
		code = board_mem_read(b, anim);
	}
	ram->cutscene_frame[a] = frame;
	/* Cocktail table only; out of scope for the port. */
	if ((ram->player_number & ram->dip_cocktail) != 0)
		code ^= 0xC0u;
	ram->cutscene_sprite[a].code = code;
	ram->cutscene_sprite[a].color = board_mem_read(b, (uint16_t)(s + 3u));

	return --ram->cutscene_count[a] == 0 ? 4 : 0;
}

/* $35BE  this actor is finished. Returns true when all six are, after
 * moving the game on: the level state in play, else the attract step. */
static bool cmd_end(Board *b, unsigned a)
{
	WorkRam *ram = work_ram(b->mem);
	unsigned i;

	ram->cutscene_done[a] = 1;
	for (i = 0; i < 6; i++)
		if (ram->cutscene_done[i] == 0)
			return false;
	if (ram->game_mode_sub1 == 0) {
		/* $2195 */
		(void)queue_timed(b, TIMER(1, 5), TT_LEVEL_STATE, 0);
		ram->level_state++;
	} else {
		ram->intermission_flag = 0;
		advance_attract_state(b);
	}
	return true;
}

/* $3611  load the six scripts that start `set` bytes into SCRIPTS */
static void load_scripts(Board *b, uint8_t set)
{
	WorkRam *ram = work_ram(b->mem);

	if (ram->game_mode_sub1 == 0) {
		ram->wave[0].num = 2;
		ram->wave[1].num = 2;
	}
	copy_bytes(b, RAM_ADDR(cutscene_script), (uint16_t)(SCRIPTS + set),
		   sizeof ram->cutscene_script);
	ram->intermission_flag = 1;
	ram->ghosts_killed_pending = 1;
	ram->pac_death_anim = 0;
	fill_bytes(b, (uint16_t)(RAM_ADDR(cutscene_done) - 1u), 0, 0x14);
}

/* $349C  one frame: each actor runs one command. `set` picks the scripts
 * when none are loaded yet. */
void run_cutscene(Board *b, uint8_t set)
{
	WorkRam *ram = work_ram(b->mem);
	unsigned a = 6;

	if (ram->intermission_flag == 0)
		load_scripts(b, set);
	while (a-- != 0) {
		uint8_t *ptr = &ram->cutscene_script[2 * a];
		uint16_t s = word_of(ptr);
		uint16_t advance = 0;

		switch (board_mem_read(b, s)) {
		case CMD_END:
			if (cmd_end(b, a))
				return;
			break;
		case CMD_PLACE:
			actor_pos(ram, a)->x = board_mem_read(b, (uint16_t)(s + 1u));
			actor_pos(ram, a)->y = board_mem_read(b, (uint16_t)(s + 2u));
			advance = 3;
			break;
		case CMD_COUNT:
			ram->cutscene_count[a] = board_mem_read(b, (uint16_t)(s + 1u));
			advance = 2;
			break;
		case CMD_ANIM:
			ram->cutscene_frame[a] = 0;
			ram->cutscene_anim[2 * a] = board_mem_read(b, (uint16_t)(s + 1u));
			ram->cutscene_anim[2 * a + 1] = board_mem_read(b, (uint16_t)(s + 2u));
			advance = 3;
			break;
		case CMD_SOUND:
			ram->effect[2].num = board_mem_read(b, (uint16_t)(s + 1u));
			advance = 2;
			break;
		case CMD_WAIT:
			advance = --ram->cutscene_count[a] == 0 ? 1 : 0;
			break;
		case CMD_ERASE_WITH:
			queue_task(b, TASK_TEXT, 0x30);
			advance = 1;
			break;
		case CMD_ERASE_ACT:
			board_mem_write(b, 0x42AC, TILE_BLANK);
			advance = 1;
			break;
		default:
			/* Any other byte, $F4 included, runs as MOVE. */
			advance = cmd_move(b, a, s);
			break;
		}
		s = (uint16_t)(s + advance);
		ptr[0] = (uint8_t)s;
		ptr[1] = (uint8_t)(s >> 8);
	}
}

/* $3435, $344F, $3469  intermissions 1-3: the act title and number,
 * then the scripts. */
void run_act(Board *b, unsigned act)
{
	static const uint8_t title[3] = { 0x32, 0x17, 0x15 };
	WorkRam *ram = work_ram(b->mem);

	if (ram->intermission_flag != 1) {
		queue_task(b, TASK_TEXT, title[act - 1]);
		board_mem_write(b, 0x42AC, (uint8_t)act);
		board_mem_write(b, 0x46AC, 0x16);
	}
	run_cutscene(b, (uint8_t)(12u * (act - 1)));
}
