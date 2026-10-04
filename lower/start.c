/* $05E5  game mode 2: waiting for a start button, then the game intro.
 * game_mode_sub2 selects the step. */
#include "game.h"

#define IN1           0x5040u
#define IN1_START1    0x20u /* active low */
#define IN1_START2    0x40u
#define MSG_PUSH_1P   0x08u /* "PUSH START BUTTON", 1 player only */
#define MSG_PUSH_1OR2 0x09u

/* BCD credits minus one: `add $99` and `daa`. */
static uint8_t bcd_dec(uint8_t v)
{
	bool carry;

	return bcd_add(v, 0x99, false, &carry);
}

/* Step 0: queue the attract screen's text and move on. Unverified with
 * the bonus life switched off. */
static void draw_prompt(Board *b, WorkRam *ram)
{
	LOWER_HOOK(draw_prompt, b, ram);
	show_credits(b);
	queue_task(b, TASK_CLEAR_SCREEN, 0x01);
	queue_task(b, TASK_MAZE_COLORS, 0x00);
	queue_task(b, TASK_TEXT, 0x07);
	queue_task(b, TASK_TEXT, 0x0B);
	queue_task(b, TASK_CLEAR_SPRITES, 0x00);
	ram->game_mode_sub2++;
	ram->start_button_wait = 1;
	if (ram->dip_bonus_life == 0xFF)
		return;
	queue_task(b, TASK_TEXT, 0x0A);
	queue_task(b, TASK_BONUS_DIGITS, 0x00);
}

/* Charge the credits (unless free play) and start the intro tune. */
static void begin_game(Board *b, WorkRam *ram)
{
	LOWER_HOOK(begin_game, b, ram);
	if (ram->dip_coins_per_credit != 0) {
		uint8_t credits = ram->credits;

		if (ram->num_players != 0)
			credits = bcd_dec(credits);
		ram->credits = bcd_dec(credits);
		show_credits(b);
	}
	ram->game_mode_sub2++;
	ram->start_button_wait = 0;
	ram->wave[0].num = 1;
	ram->wave[1].num = 1;
}

/* Step 1: wait for a start button. One credit allows player 1 only. */
static void wait_start(Board *b, WorkRam *ram)
{
	LOWER_HOOK(wait_start, b, ram);
	uint8_t in1;

	show_credits(b);
	draw_message(b, ram->credits == 1 ? MSG_PUSH_1P : MSG_PUSH_1OR2);
	in1 = board_mem_read(b, IN1);
	if (ram->credits != 1 && (in1 & IN1_START2) == 0) {
		ram->num_players = 1;
		begin_game(b, ram);
	} else if ((in1 & IN1_START1) == 0) {
		ram->num_players = 0;
		begin_game(b, ram);
	}
}

/* Step 2: queue the playfield, set up lives, and wait for the tune. */
static void set_up_game(Board *b, WorkRam *ram)
{
	LOWER_HOOK(set_up_game, b, ram);
	queue_task(b, TASK_CLEAR_SCREEN, 0x01);
	queue_task(b, TASK_MAZE_COLORS, 0x01);
	queue_task(b, TASK_DRAW_MAZE, 0x00);
	queue_task(b, TASK_RESET_PILLS, 0x00);
	queue_task(b, TASK_DRAW_PILLS, 0x00);
	queue_task(b, TASK_TEXT, 0x03);
	queue_task(b, TASK_TEXT, 0x06);
	queue_task(b, TASK_DRAW_SCORES, 0x00);
	queue_task(b, TASK_FRUIT_ROW, 0x00);
	ram->level_number = 0;
	ram->lives_real = ram->dip_lives;
	ram->lives_displayed = ram->dip_lives;
	queue_task(b, TASK_LIVES_ROW, 0x00);
	/* A full timer list retries next frame (unverified; never full). */
	if (queue_timed(b, TIMER(1, 0x17), TT_PLAY_STATE, 0))
		ram->game_mode_sub2++;
}

/* Step 4: show one life fewer (the one in play) and start the game. */
static void start_play(Board *b, WorkRam *ram)
{
	LOWER_HOOK(start_play, b, ram);
	ram->lives_displayed--;
	draw_lives_row(b);
	ram->game_mode_sub2 = 0;
	ram->game_mode_sub1 = 0;
	ram->level_state = 0;
	ram->game_mode++;
}

void press_start(Board *b)
{
	LOWER_HOOK(press_start, b);
	WorkRam *ram = work_ram(b->mem);

	switch (ram->game_mode_sub2) {
	case 0:
		draw_prompt(b, ram);
		break;
	case 1:
		wait_start(b, ram);
		break;
	case 2:
		set_up_game(b, ram);
		break;
	case 4:
		start_play(b, ram);
		break;
	default:
		/* Step 3 waits for the timer. Unverified past 4. */
		break;
	}
}
