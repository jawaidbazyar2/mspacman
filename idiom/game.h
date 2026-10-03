/* Game logic shared across files: prototypes and ROM/RAM helpers. */
#ifndef IDIOM_GAME_H
#define IDIOM_GAME_H

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "lift.h"

/* A byte or little-endian word of program ROM. */
static inline uint8_t rom8(const Board *b, uint16_t addr)
{
	return b->rom[addr];
}

static inline uint16_t rom16(const Board *b, uint16_t addr)
{
	return (uint16_t)(b->rom[addr] |
			  (uint16_t)((uint16_t)b->rom[(uint16_t)(addr + 1u)] << 8));
}

/* The bus address of a WorkRam field. */
#define RAM_ADDR(field) ((uint16_t)(WORK_RAM_BASE + offsetof(WorkRam, field)))

/* Copy `n` bytes from the bus at `src` to the bus at `dst`. */
static inline void copy_bytes(Board *b, uint16_t dst, uint16_t src, unsigned n)
{
	while (n-- != 0)
		board_mem_write(b, dst++, board_mem_read(b, src++));
}

/* Store `value` in `n` bytes on the bus from `dst`. */
static inline void fill_bytes(Board *b, uint16_t dst, uint8_t value, unsigned n)
{
	while (n-- != 0)
		board_mem_write(b, dst++, value);
}

/* A little-endian word at a bus address. */
static inline uint16_t get16(Board *b, uint16_t addr)
{
	return (uint16_t)(board_mem_read(b, addr) |
			  (uint16_t)((uint16_t)board_mem_read(b, (uint16_t)(addr + 1u)) << 8));
}

static inline void put16(Board *b, uint16_t addr, uint16_t value)
{
	board_mem_write(b, addr, (uint8_t)value);
	board_mem_write(b, (uint16_t)(addr + 1u), (uint8_t)(value >> 8));
}

/* Two-digit BCD add with carry: `adc` then `daa`. Inputs that are not
 * BCD give the Z80's result. */
static inline uint8_t bcd_add(uint8_t a, uint8_t b, bool carry_in, bool *carry_out)
{
	unsigned cin = carry_in ? 1u : 0u;
	unsigned sum = (unsigned)a + b + cin;
	bool half = ((a & 0x0Fu) + (b & 0x0Fu) + cin) > 0x0Fu;
	uint8_t r = (uint8_t)sum;
	uint8_t fix = 0;
	bool carry = sum > 0xFFu || r > 0x99u;

	if (half || (r & 0x0Fu) > 9u)
		fix = 0x06;
	if (carry)
		fix = (uint8_t)(fix | 0x60u);
	*carry_out = carry;
	return (uint8_t)(r + fix);
}

/* Actors in pos[], tile[], dir[], and the other per-actor arrays.
 * Ghost-only arrays stop at ACT_ORANGE. */
enum {
	ACT_RED = 0,
	ACT_PINK = 1,
	ACT_BLUE = 2,
	ACT_ORANGE = 3,
	ACT_PAC = 4
};

#define TILE_BLANK 0x40u

/* game_mode */
enum {
	MODE_POWER_ON = 0,
	MODE_ATTRACT = 1,     /* includes the demo game */
	MODE_PRESS_START = 2,
	MODE_PLAY = 3
};

/* level_state, the table at $06C2. The numbers missing here are waits
 * that a timed task ends by advancing the state. */
enum {
	LEVEL_NEW_GAME = 0,
	LEVEL_OPENING = 1,
	LEVEL_PLAYING = 3,
	LEVEL_LIFE_LOST = 4,
	LEVEL_NEXT_TURN = 6,
	LEVEL_GAME_OVER = 8,
	LEVEL_GET_READY = 9,
	LEVEL_GO = 11,
	LEVEL_BOARD_CLEAR = 12,
	LEVEL_FLASH = 14,     /* 14-28: white on the even steps of 4 */
	LEVEL_FLASH_BACK = 16,
	LEVEL_CLEAR_BOARD = 30,
	LEVEL_INTERMISSION = 32,
	LEVEL_NEXT_BOARD = 34,
	LEVEL_NEXT_READY = 35,
	LEVEL_NEXT_GO = 37
};

/* substate[]: where a live ghost is relative to the house. */
enum {
	HOUSE_WAIT = 0,  /* inside, bobbing (red: inside, climbing) */
	HOUSE_OUT = 1,   /* in the maze */
	HOUSE_CLIMB = 2, /* rising through the door */
	HOUSE_SLIDE = 3  /* blue and orange moving to the middle first */
};

/* ghost_state[]: alive, or eyes on the way home. */
enum {
	GHOST_ALIVE = 0,
	EYES_TO_DOOR = 1,
	EYES_DOWN = 2,
	EYES_SIDE = 3    /* blue and orange only */
};

/* ghost_speed[3 * ghost + SPEED_*] */
enum {
	SPEED_NORMAL = 0,
	SPEED_BLUE = 1,
	SPEED_TUNNEL = 2
};

/* add_score items, the table at $2B17. Ghosts are SCORE_GHOST + 0..3,
 * fruit items follow. */
enum {
	SCORE_PILL = 0,
	SCORE_ENERGIZER = 1,
	SCORE_GHOST = 2
};

/* game_mode_sub1 of Pac-Man's title chase. Ms. Pac-Man never sets it,
 * but the checks for it remain. */
#define PACMAN_CHASE_SCENE 0x22u

/* dir[] values. */
enum {
	DIR_RIGHT = 0,
	DIR_DOWN = 1,
	DIR_LEFT = 2,
	DIR_UP = 3
};

/* Sprite slots in sprite[] and sprite_pos[]. Slots 0 and 7 are unused. */
enum {
	SPR_RED = 1,
	SPR_PINK = 2,
	SPR_BLUE = 3,
	SPR_ORANGE = 4,
	SPR_PAC = 5,
	SPR_FRUIT = 6
};

/* Main task numbers, the table at $23A8. The parameter byte follows. */
enum {
	TASK_CLEAR_SCREEN = 0x00,   /* 0 whole screen, 1 the maze only */
	TASK_MAZE_COLORS = 0x01,    /* 0 attract, 1 this maze, 2 flash white */
	TASK_DRAW_MAZE = 0x02,
	TASK_DRAW_PILLS = 0x03,
	TASK_PLACE_ACTORS = 0x04,   /* 0 a new board, 1 the attract demo */
	TASK_HOUSE_TIMER = 0x05,
	TASK_CLEAR_COLORS = 0x06,
	TASK_DEMO_MODE = 0x07,
	TASK_RED_TARGET = 0x08,     /* chase or scatter targets, by ghost */
	TASK_PINK_TARGET = 0x09,
	TASK_BLUE_TARGET = 0x0A,
	TASK_ORANGE_TARGET = 0x0B,
	TASK_RED_FLEE = 0x0C,       /* targets while blue, by ghost */
	TASK_PINK_FLEE = 0x0D,
	TASK_BLUE_FLEE = 0x0E,
	TASK_ORANGE_FLEE = 0x0F,
	TASK_DIFFICULTY = 0x10,
	TASK_CLEAR_ACTORS = 0x11,
	TASK_RESET_PILLS = 0x12,
	TASK_ERASE_PILLS = 0x13,
	TASK_DIP_SWITCHES = 0x14,
	TASK_PILL_BITMAP = 0x15,
	TASK_NEXT_LEVEL_STATE = 0x16,
	TASK_DEMO_STEER = 0x17,
	TASK_DRAW_SCORES = 0x18,
	TASK_ADD_SCORE = 0x19,      /* parameter SCORE_* */
	TASK_LIVES_ROW = 0x1A,
	TASK_FRUIT_ROW = 0x1B,
	TASK_TEXT = 0x1C,           /* parameter: message, bit 7 erases */
	TASK_CREDITS = 0x1D,
	TASK_CLEAR_SPRITES = 0x1E,
	TASK_BONUS_DIGITS = 0x1F
};

/* task.c: the main task list */
void queue_task(Board *b, uint8_t task, uint8_t param);
void task_next_level_state(Board *b, uint8_t param);

/* clock.c: frame counters and timed tasks */
void clock_tick(Board *b);
void timers_run(Board *b);
bool queue_timed(Board *b, uint8_t timer, uint8_t task, uint8_t param);
void advance_level_state(Board *b);
void advance_play_state(Board *b);
void advance_attract_state(Board *b);
void advance_eaten_ghost_anim(Board *b);
void advance_cutscene1(Board *b);
void advance_cutscene2(Board *b);
void advance_cutscene3(Board *b);

/* Timer byte for queue_timed: bits 7-6 the unit, bits 5-0 the count.
 * Unit 0 counts frames. Units 1-3 count the clock_hundredths,
 * clock_seconds, and clock_minutes wraps. */
#define TIMER(unit, count) ((uint8_t)(((unsigned)(unit) << 6) | (unsigned)(count)))

/* Timed task numbers, the jump table at $0247. */
enum {
	TT_LEVEL_STATE = 0,
	TT_PLAY_STATE = 1,
	TT_ATTRACT_STATE = 2,
	TT_EATEN_GHOST = 3,
	TT_CLEAR_FRUIT = 4,
	TT_CLEAR_FRUIT_POS = 5,
	TT_CLEAR_READY = 6,
	TT_CUTSCENE1 = 7,
	TT_CUTSCENE2 = 8,
	TT_CUTSCENE3 = 9
};

/* rng.c */
uint8_t rom_random(Board *b);

/* vblank.c */
void vblank(Board *b);

/* coin.c */
void coin_inputs(Board *b);
void coin_meter(Board *b);

/* hud.c */
void hud_blink(Board *b);

/* draw.c */
void draw_block(Board *b, uint16_t cell, uint8_t tile);
void draw_icon(Board *b, uint16_t cell, uint8_t tile);
void draw_fruit_row(Board *b);
void draw_message(Board *b, uint8_t n);
void text_task(Board *b, uint8_t n);

/* score.c */
void add_score(Board *b, uint8_t item);
void draw_lives_row(Board *b);
void draw_bonus_digits(Board *b);
void read_dip_switches(Board *b);
void draw_scores(Board *b);
void show_credits(Board *b);

/* maze.c */
uint16_t maze_word(Board *b, uint16_t table);
void flash_power_pills(Board *b);
void pill_bitmap(Board *b);
void reset_pills(Board *b);
void draw_pills(Board *b);
void erase_pills(Board *b);
void clear_colors(Board *b);
void clear_screen(Board *b, uint8_t which);
void draw_maze(Board *b);
void maze_colors(Board *b, uint8_t which);
void demo_mode(Board *b);
void clear_actors(Board *b);
void house_timer(Board *b, uint8_t param);
void place_actors(Board *b, uint8_t intro);

/* difficulty.c */
void load_difficulty(Board *b, uint8_t index);
void update_elroy(Board *b);

/* start.c */
void press_start(Board *b);

/* sprite.c */
void sprites_upright(Board *b);
void sprites_cocktail(Board *b);

/* cutscene.c */
void cutscene1_positions(Board *b);
void cutscene1_sprites(Board *b);
void run_cutscene(Board *b, uint8_t set);
void run_act(Board *b, unsigned act);

/* mode.c, attract.c, play.c */
void game_mode_step(Board *b);
void level_step(Board *b);
void attract_step(Board *b);
void draw_midway_logo(Board *b);
void play_frame(Board *b);
void cutscene2_sprites(Board *b);
void cutscene3_sprites(Board *b);

/* sound.c */
void sound_effects(Board *b);
void sound_songs(Board *b);

/* siren.c */
void siren_update(Board *b);

/* fruit.c */
void clear_fruit(Board *b);
void clear_fruit_pos(Board *b);
void move_fruit(Board *b);

/* actor.c */
Coord dir_step(const Board *b, uint8_t dir);
Coord coord_add(Coord a, Coord b);
bool coord_eq(Coord a, Coord b);
uint16_t coord_word(Coord c);
Coord word_coord(uint16_t w);
Coord pos_to_tile(Coord pos);
uint16_t tile_cell(Coord t);
uint8_t tile_at(Board *b, Coord t);
uint8_t color_at(Board *b, Coord t);
bool is_wall(uint8_t tile);
bool tunnel_wrap(WorkRam *ram, int actor);
bool speed_tick(SpeedPattern *p);

/* pac.c */
void move_pac(Board *b);
void pac_death(Board *b);
void clear_actor_positions(Board *b);

/* ghost.c */
void move_ghosts(Board *b);
void return_all_eyes(Board *b);
void mark_eaten_ghost(Board *b);
void move_in_house(Board *b);
void release_by_pills(Board *b);
void count_house_pill(Board *b);
void release_idle_ghost(Board *b);
void ghost_anim_tick(Board *b);
void reversal_timer(Board *b);

/* fright.c */
void color_eyes(Board *b);
void start_fright(Board *b);
void fright_countdown(Board *b);
void flash_ghosts(Board *b);
void tile_collision(Board *b);
void pixel_collision(Board *b);
void show_eaten_ghost(Board *b);

/* target.c: main tasks $08-$0F and $17 */
void aim_red(Board *b);
void aim_pink(Board *b);
void aim_blue(Board *b);
void aim_orange(Board *b);
void flee_red(Board *b);
void flee_pink(Board *b);
void flee_blue(Board *b);
void flee_orange(Board *b);
void demo_steer(Board *b);

#endif
