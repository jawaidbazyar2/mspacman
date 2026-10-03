/* The game modes (power-on, attract, press start, play) and, within
 * play, the level state: start, READY, playing, death, end of board,
 * the intermissions, and game over. */
#include "game.h"

#define IN0          0x5000u
#define IRQ_ENABLE   0x5001u
#define FLIP_SCREEN  0x5003u
#define PILLS_PER_MAZE 0x94B5u /* per-maze table of each maze's pill count */
#define LAST_DIFFICULTY 0x14u

/* The two players' level records are the $2E bytes from difficulty_ptr;
 * the player who is waiting has his copy in level_data_copy. */
#define PLAYER_BLOCK RAM_ADDR(difficulty_ptr_lo)
#define WAITING(ram, field) \
	((ram)->level_data_copy[offsetof(WorkRam, field) - offsetof(WorkRam, difficulty_ptr_lo)])

enum {
	TEXT_GAME_OVER = 0x05,
	TEXT_READY = 0x06,
	TEXT_PLAYER_ONE = 0x03, /* + player_number */
	TEXT_MS_PAC_MAN = 0x83,
};

/* Two players at a cocktail table: flip the screen for player 2.
 * Cocktail tables are out of scope for the port. */
static void flip_for_player(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	board_mem_write(b, FLIP_SCREEN, (uint8_t)(ram->player_number & ram->dip_cocktail));
}

static void wait_level_state(Board *b, uint8_t units)
{
	(void)queue_timed(b, TIMER(1, units), TT_LEVEL_STATE, 0);
}

/* $0AA6  exchange the two players' level records */
static void swap_players(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	unsigned i;

	for (i = 0; i < sizeof ram->level_data_copy; i++) {
		uint16_t mine = (uint16_t)(PLAYER_BLOCK + i);
		uint8_t t = board_mem_read(b, mine);

		board_mem_write(b, mine, ram->level_data_copy[i]);
		ram->level_data_copy[i] = t;
	}
}

/* $0879  state 0: a new game. Both players get the starting record. */
static void new_game(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	fill_bytes(b, RAM_ADDR(player_number), 0, 11);
	reset_pills(b);
	ram->difficulty_ptr_lo = ram->dip_difficulty_ptr_lo;
	ram->difficulty_ptr_hi = ram->dip_difficulty_ptr_hi;
	copy_bytes(b, RAM_ADDR(level_data_copy), PLAYER_BLOCK, sizeof ram->level_data_copy);
	advance_level_state(b);
}

/* $0899  state 1: the opening, "MS PAC-MAN" over the maze. The demo
 * skips it. */
static void opening(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if (ram->game_mode == MODE_ATTRACT) {
		ram->level_state = LEVEL_GET_READY;
		return;
	}
	queue_task(b, TASK_CLEAR_ACTORS, 0);
	queue_task(b, TASK_TEXT, TEXT_MS_PAC_MAN);
	queue_task(b, TASK_PLACE_ACTORS, 0);
	queue_task(b, TASK_HOUSE_TIMER, 0);
	queue_task(b, TASK_DIFFICULTY, 0);
	queue_task(b, TASK_LIVES_ROW, 0);
	wait_level_state(b, 0x14);
	(void)queue_timed(b, TIMER(1, 0x14), TT_CLEAR_READY, 0);
	flip_for_player(b);
	advance_level_state(b);
}

/* $08CD  state 3: play a frame until the board is clear. The rack-test
 * switch (IN0 bit 4 low) clears it at once. */
static void playing(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if ((board_mem_read(b, IN0) & 0x10u) == 0) {
		ram->level_state = LEVEL_FLASH;
		queue_task(b, TASK_ERASE_PILLS, 0);
		return;
	}
	if (ram->dots_eaten == board_mem_read(b, maze_word(b, PILLS_PER_MAZE)))
		ram->level_state = LEVEL_BOARD_CLEAR;
	else
		play_frame(b);
}

/* $090D  state 4: a life was lost. With two players and the other one
 * still in, show his name and GAME OVER first. */
static void life_lost(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	ram->died_this_level = 1;
	pill_bitmap(b);
	ram->level_state++;
	if (ram->lives_real != 0 || ram->num_players == 0 || WAITING(ram, lives_real) == 0) {
		ram->level_state++;
		return;
	}
	queue_task(b, TASK_TEXT, (uint8_t)(TEXT_PLAYER_ONE + ram->player_number));
	queue_task(b, TASK_TEXT, TEXT_GAME_OVER);
	wait_level_state(b, 0x14);
}

/* $0940  state 6: the other player's turn, the next life, or game over */
static void next_turn(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if (ram->num_players != 0 && WAITING(ram, lives_real) != 0) {
		swap_players(b);
		ram->player_number ^= 1u;
		ram->level_state = LEVEL_GET_READY;
		return;
	}
	if (ram->lives_real != 0) {
		ram->level_state = LEVEL_GET_READY;
		return;
	}
	show_credits(b);
	queue_task(b, TASK_TEXT, TEXT_GAME_OVER);
	wait_level_state(b, 0x14);
	ram->level_state++;
}

/* $0972  state 8: back to attract */
static void game_over(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	ram->game_mode_sub1 = 0;
	ram->level_state = LEVEL_NEW_GAME;
	ram->num_players = 0;
	ram->player_number = 0;
	board_mem_write(b, FLIP_SCREEN, 0);
	ram->game_mode = MODE_ATTRACT;
}

/* $0988  state 9: draw the board and show READY. The demo shows
 * GAME OVER and the credits too. */
static void get_ready(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	queue_task(b, TASK_CLEAR_SCREEN, 1);
	queue_task(b, TASK_MAZE_COLORS, 1);
	queue_task(b, TASK_DRAW_MAZE, 0);
	queue_task(b, TASK_CLEAR_ACTORS, 0);
	queue_task(b, TASK_ERASE_PILLS, 0);
	queue_task(b, TASK_DRAW_PILLS, 0);
	queue_task(b, TASK_PLACE_ACTORS, 0);
	queue_task(b, TASK_HOUSE_TIMER, 0);
	queue_task(b, TASK_DIFFICULTY, 0);
	queue_task(b, TASK_LIVES_ROW, 0);
	queue_task(b, TASK_TEXT, TEXT_READY);
	if (ram->game_mode != MODE_PLAY) {
		queue_task(b, TASK_TEXT, TEXT_GAME_OVER);
		queue_task(b, TASK_CREDITS, 0);
	}
	wait_level_state(b, 0x14);
	if (ram->game_mode != MODE_ATTRACT)
		(void)queue_timed(b, TIMER(1, 0x14), TT_CLEAR_READY, 0);
	flip_for_player(b);
	advance_level_state(b);
}

/* $09D8  state 12: the board is clear; pause */
static void board_clear(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	wait_level_state(b, 0x14);
	ram->level_state++;
	ram->effect[1].num = 0;
	ram->effect[2].num = 0;
}

/* $09EA  states 14-28: flash the walls white (2) and back (0) */
static void flash_maze(Board *b, uint8_t color)
{
	WorkRam *ram = work_ram(b->mem);
	unsigned g;

	queue_task(b, TASK_MAZE_COLORS, color);
	wait_level_state(b, 2);
	for (g = ACT_RED; g <= ACT_ORANGE; g++) {
		ram->pos[g].y = 0;
		ram->pos[g].x = 0;
	}
	ram->level_state++;
}

/* $0A0E  state 30: clear the board for the next one */
static void clear_board(Board *b)
{
	queue_task(b, TASK_CLEAR_SCREEN, 1);
	queue_task(b, TASK_CLEAR_COLORS, 0);
	queue_task(b, TASK_CLEAR_ACTORS, 0);
	queue_task(b, TASK_ERASE_PILLS, 0);
	queue_task(b, TASK_PLACE_ACTORS, 1);
	queue_task(b, TASK_HOUSE_TIMER, 1);
	queue_task(b, TASK_DIFFICULTY, 0x13);
	wait_level_state(b, 3);
	work_ram(b->mem)->level_state++;
}

/* $0A2C  state 32: the intermission after boards 2, 5, 9, 13, and 17.
 * Other boards skip state 33. */
static void intermission(Board *b)
{
	static const uint8_t act_after[0x15] = {
		0, 1, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 3, 0, 0, 0, 0
	};
	WorkRam *ram = work_ram(b->mem);
	uint8_t level = ram->level_number < 0x14 ? ram->level_number : 0x14;

	ram->effect[1].num = 0;
	ram->effect[2].num = 0;
	if (act_after[level] != 0) {
		run_act(b, act_after[level]);
		return;
	}
	/* $0A6F */
	ram->level_state = (uint8_t)(ram->level_state + 2u);
	ram->wave[0].num = 0;
	ram->wave[1].num = 0;
}

/* $0A7C  state 34: next board. The difficulty pointer stops at the
 * last row. */
static void next_board(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint16_t ptr = (uint16_t)(ram->difficulty_ptr_lo | (uint16_t)(ram->difficulty_ptr_hi << 8));

	ram->wave[0].num = 0;
	ram->wave[1].num = 0;
	fill_bytes(b, RAM_ADDR(fruit1_released), 0, 7);
	reset_pills(b);
	ram->level_state++;
	ram->level_number++;
	if (board_mem_read(b, ptr) == LAST_DIFFICULTY)
		return;
	ptr++;
	ram->difficulty_ptr_lo = (uint8_t)ptr;
	ram->difficulty_ptr_hi = (uint8_t)(ptr >> 8);
}

/* $06BE  one step of the level state ($06C2 table). The states with no
 * case are waits for a timed task to advance the state. */
void level_step(Board *b)
{
	uint8_t state = work_ram(b->mem)->level_state;

	switch (state) {
	case LEVEL_NEW_GAME: new_game(b); break;
	case LEVEL_OPENING: opening(b); break;
	case LEVEL_PLAYING: playing(b); break;
	case LEVEL_LIFE_LOST: life_lost(b); break;
	case LEVEL_NEXT_TURN: next_turn(b); break;
	case LEVEL_GAME_OVER: game_over(b); break;
	case LEVEL_GET_READY: case LEVEL_NEXT_READY: get_ready(b); break;
	case LEVEL_GO: case LEVEL_NEXT_GO: /* $09D2 */
		work_ram(b->mem)->level_state = LEVEL_PLAYING;
		break;
	case LEVEL_BOARD_CLEAR: board_clear(b); break;
	case LEVEL_FLASH: case LEVEL_FLASH + 4: case LEVEL_FLASH + 8: case LEVEL_FLASH + 12:
		flash_maze(b, 2);
		break;
	case LEVEL_FLASH_BACK: case LEVEL_FLASH_BACK + 4: case LEVEL_FLASH_BACK + 8:
	case LEVEL_FLASH_BACK + 12:
		flash_maze(b, 0);
		break;
	case LEVEL_CLEAR_BOARD: clear_board(b); break;
	case LEVEL_INTERMISSION: intermission(b); break;
	case LEVEL_NEXT_BOARD: next_board(b); break;
	default: break;
	}
}

/* $03D4  power-on: queue the start-up tasks once. Every session starts
 * after this has run, so the second-call return is unverified. */
static void power_on(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	if (ram->game_mode_sub0 != 0)
		return;
	queue_task(b, TASK_CLEAR_SCREEN, 0);
	queue_task(b, TASK_CLEAR_COLORS, 0);
	queue_task(b, TASK_MAZE_COLORS, 0);
	queue_task(b, TASK_DIP_SWITCHES, 0);
	queue_task(b, TASK_DRAW_SCORES, 0);
	queue_task(b, TASK_PLACE_ACTORS, 0);
	queue_task(b, TASK_CLEAR_SPRITES, 0);
	queue_task(b, TASK_DEMO_MODE, 0);
	ram->game_mode_sub0++;
	board_mem_write(b, IRQ_ENABLE, 1);
}

/* $03FE  attract, until a credit moves the game to press-start */
static void attract(Board *b)
{
	WorkRam *ram = work_ram(b->mem);

	show_credits(b);
	if (ram->credits == 0) {
		attract_step(b);
		return;
	}
	ram->level_state = LEVEL_NEW_GAME;
	ram->game_mode_sub1 = 0;
	ram->game_mode++;
}

/* $03C8  one step of the game mode */
void game_mode_step(Board *b)
{
	switch (work_ram(b->mem)->game_mode) {
	case MODE_POWER_ON: power_on(b); break;
	case MODE_ATTRACT: attract(b); break;
	case MODE_PRESS_START: press_start(b); break;
	case MODE_PLAY: level_step(b); break;
	default: break; /* the ROM's table has only four modes */
	}
}
