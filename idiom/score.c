/* Scores, the high score, extra lives, credits, and the DIP switches.
 * Scores are three BCD bytes, least significant first, followed by the
 * player's "bonus life awarded" flag. */
#include "game.h"

#include <string.h>

#define POINTS_TABLE   0x2B17u /* BCD word per scoring item */
#define BONUS_TABLE    0x2728u /* bonus-life threshold by DSW bits 5-4 */
#define DIFFICULTY_TAB 0x272Cu /* difficulty table pointer by DSW bit 6 */
#define DSW1           0x5080u
#define IN1            0x5040u
#define CELL_P1_SCORE  0x43FCu /* rightmost digit of each score */
#define CELL_P2_SCORE  0x43E9u
#define CELL_HI_SCORE  0x43F2u
#define CELL_LIVES     0x401Au /* bottom row, first life icon */
#define CELL_CREDIT1   0x4033u /* ones digit of the credit count */
#define CELL_CREDIT10  0x4034u
#define CELL_BONUS1    0x4136u /* bonus-life thousands digits */
#define CELL_BONUS10   0x4156u
#define TILE_LIFE      0x20u
#define TILE_DIGIT0    0x30u   /* '0' in the text font */
#define SOUND_EXTRA    0x01u   /* effect channel 1 bit */
#define MSG_HIGH_SCORE 0x00u
#define MSG_CREDIT     0x01u
#define MSG_FREE_PLAY  0x02u

static uint8_t *player_score(WorkRam *ram)
{
	return ram->player_number == 0 ? &ram->score_p1_lo : &ram->score_p2_lo;
}

/* One digit. The first `*blanks` leading zeros are drawn blank. */
static void draw_digit(Board *b, uint16_t cell, uint8_t digit, uint8_t *blanks)
{
	if (digit != 0)
		*blanks = 0;
	else if (*blanks != 0) {
		(*blanks)--;
		digit = TILE_BLANK;
	}
	board_mem_write(b, cell, digit);
}

/* $2ABE  six digits, most significant first. `cell` is the leftmost on
 * screen; the top rows run right to left in video RAM. */
static void draw_score(Board *b, uint16_t cell, const uint8_t *score, uint8_t blanks)
{
	int i;

	for (i = 2; i >= 0; i--) {
		draw_digit(b, cell--, (uint8_t)(score[i] >> 4), &blanks);
		draw_digit(b, cell--, (uint8_t)(score[i] & 0x0Fu), &blanks);
	}
}

/* $2AAF */
static void draw_player_score(Board *b, WorkRam *ram)
{
	uint16_t cell = ram->player_number == 0 ? CELL_P1_SCORE : CELL_P2_SCORE;

	draw_score(b, cell, player_score(ram), 4);
}

/* Life icons along the bottom, then blanks up to five slots. Six or more
 * lives show none. */
static void draw_lives(Board *b, uint8_t lives)
{
	uint16_t cell = CELL_LIVES;
	unsigned slot = 0;

	if (lives != 0 && lives < 6)
		for (; slot < lives; slot++, cell = (uint16_t)(cell - 2u))
			draw_icon(b, cell, TILE_LIFE);
	for (; slot < 5; slot++, cell = (uint16_t)(cell - 2u))
		draw_block(b, cell, TILE_BLANK);
}

/* $2B33  the bonus life, once per player */
static void award_life(Board *b, WorkRam *ram, uint8_t *score)
{
	if (score[3] & 1u)
		return;
	score[3] |= 1u;
	ram->effect[0].num |= SOUND_EXTRA;
	ram->lives_real++;
	ram->lives_displayed++;
	draw_lives(b, ram->lives_displayed);
}

/* $2A5A  task $19: score an item (SCORE_*), award the bonus life, and
 * update the high score. The attract mode scores nothing. */
void add_score(Board *b, uint8_t item)
{
	WorkRam *ram = work_ram(b->mem);
	uint16_t points;
	uint8_t *score;
	uint8_t thousands;
	bool carry;
	int i;

	if (ram->game_mode == MODE_ATTRACT)
		return;
	points = rom16(b, (uint16_t)(POINTS_TABLE + (uint8_t)(item << 1)));
	score = player_score(ram);
	score[0] = bcd_add(score[0], (uint8_t)points, false, &carry);
	score[1] = bcd_add(score[1], (uint8_t)(points >> 8), carry, &carry);
	score[2] = bcd_add(score[2], 0, carry, &carry);

	/* The threshold is in thousands: $10 is 10,000. */
	thousands = (uint8_t)((uint8_t)(score[2] << 4) | (score[1] >> 4));
	if ((uint8_t)(ram->dip_bonus_life - 1u) < thousands)
		award_life(b, ram, score);
	draw_player_score(b, ram);

	for (i = 2; i >= 0; i--) {
		uint8_t high = (&ram->high_score_lo)[i];

		if (score[i] < high)
			return;
		if (score[i] > high)
			break;
	}
	if (i < 0)
		return; /* a tie */
	memcpy(&ram->high_score_lo, score, 3);
	draw_score(b, CELL_HI_SCORE, &ram->high_score_lo, 4);
}

/* $2B6A  task $1A: color the bottom rows and draw the lives */
void draw_lives_row(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	unsigned i;

	if (ram->game_mode == MODE_ATTRACT)
		return;
	for (i = 0; i < 10; i++) {
		board_mem_write(b, (uint16_t)(0x4412u + i), 0x09);
		board_mem_write(b, (uint16_t)(0x4432u + i), 0x09);
	}
	draw_lives(b, ram->lives_displayed);
}

/* $26B2  task $1F: the bonus-life threshold's two digits */
void draw_bonus_digits(Board *b)
{
	uint8_t bonus = work_ram(b->mem)->dip_bonus_life;

	board_mem_write(b, CELL_BONUS1, (uint8_t)((bonus & 0x0Fu) + TILE_DIGIT0));
	if (bonus >> 4)
		board_mem_write(b, CELL_BONUS10, (uint8_t)((bonus >> 4) + TILE_DIGIT0));
}

/* $26D0  task $14: read the DIP switches.
 *   bits 1-0  coinage: 0 free play, 1 1/1, 2 1/2, 3 2/1
 *   bits 3-2  lives - 1, with 3 meaning 5 lives
 *   bits 5-4  bonus life
 *   bit 6     clear: hard
 *   bit 7     clear: alternate ghost names
 * IN1 bit 7 clear is a cocktail table. Cocktail tables and coinage other
 * than free play or 1 coin, 1 credit are out of scope for the port. */
void read_dip_switches(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t dip = board_mem_read(b, DSW1);
	uint8_t coinage = (uint8_t)(dip & 0x03u);
	uint8_t lives = (uint8_t)(((dip >> 2) & 0x03u) + 1u);
	uint16_t difficulty;

	if (coinage == 0)
		ram->credits = 0xFF;
	ram->dip_coins_per_credit = (uint8_t)((coinage >> 1) + (coinage & 1u));
	ram->dip_credits_per_coin = (uint8_t)((ram->dip_coins_per_credit & 0x02u) ^ coinage);
	ram->dip_lives = lives == 4 ? 5 : lives;
	ram->dip_bonus_life = rom8(b, (uint16_t)(BONUS_TABLE + ((dip >> 4) & 0x03u)));
	ram->ghost_names_mode = (dip & 0x80u) ? 0 : 1;
	difficulty = rom16(b, (uint16_t)(DIFFICULTY_TAB + ((dip & 0x40u) ? 0u : 2u)));
	ram->dip_difficulty_ptr_lo = (uint8_t)difficulty;
	ram->dip_difficulty_ptr_hi = (uint8_t)(difficulty >> 8);
	ram->dip_cocktail = (board_mem_read(b, IN1) & 0x80u) ? 0 : 1;
}

/* $2AE0  task $18: HIGH SCORE and both scores, cleared to zero. Player 2's
 * field is blank in a one-player game. */
void draw_scores(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	draw_message(b, MSG_HIGH_SCORE);
	memset(&ram->score_p1_lo, 0, 8);
	draw_score(b, CELL_P1_SCORE, &ram->score_p1_lo, 4);
	draw_score(b, CELL_P2_SCORE, &ram->score_p2_lo, ram->num_players == 0 ? 6 : 4);
}

/* $2BA1  task $1D: CREDIT and the count, or FREE PLAY. The tens digit
 * is only ever drawn, never erased. */
void show_credits(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if (ram->credits == 0xFF) {
		draw_message(b, MSG_FREE_PLAY);
		return;
	}
	draw_message(b, MSG_CREDIT);
	if (ram->credits & 0xF0u)
		board_mem_write(b, CELL_CREDIT10, (uint8_t)((ram->credits >> 4) + TILE_DIGIT0));
	board_mem_write(b, CELL_CREDIT1, (uint8_t)((ram->credits & 0x0Fu) + TILE_DIGIT0));
}