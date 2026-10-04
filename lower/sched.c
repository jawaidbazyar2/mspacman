/* The main task list: the game queues tasks and the loop at $238D runs
 * them between interrupts. Also the start-up code at $234B. */
#include "dispatch.h"

#include <stdio.h>
#include <string.h>

/* The main tasks, the jump table at $23A8. Each gets the parameter byte
 * queued with it. */
typedef void (*TaskFn)(Board *b, uint8_t param);

/* Tasks that ignore the parameter. */
#define NO_PARAM(fn) \
	static void fn##_task(Board *b, uint8_t param) { (void)param; fn(b); }

NO_PARAM(draw_maze) NO_PARAM(draw_pills) NO_PARAM(clear_colors)
NO_PARAM(demo_mode) NO_PARAM(clear_actors) NO_PARAM(reset_pills)
NO_PARAM(erase_pills) NO_PARAM(pill_bitmap)
NO_PARAM(aim_red) NO_PARAM(aim_pink) NO_PARAM(aim_blue) NO_PARAM(aim_orange)
NO_PARAM(flee_red) NO_PARAM(flee_pink) NO_PARAM(flee_blue) NO_PARAM(flee_orange)
NO_PARAM(read_dip_switches) NO_PARAM(demo_steer)
NO_PARAM(draw_scores) NO_PARAM(draw_lives_row) NO_PARAM(draw_fruit_row)
NO_PARAM(show_credits) NO_PARAM(clear_actor_positions) NO_PARAM(draw_bonus_digits)

static const TaskFn k_task[32] = {
	[TASK_CLEAR_SCREEN] = clear_screen,
	[TASK_MAZE_COLORS] = maze_colors,
	[TASK_DRAW_MAZE] = draw_maze_task,
	[TASK_DRAW_PILLS] = draw_pills_task,
	[TASK_PLACE_ACTORS] = place_actors,
	[TASK_HOUSE_TIMER] = house_timer,
	[TASK_CLEAR_COLORS] = clear_colors_task,
	[TASK_DEMO_MODE] = demo_mode_task,
	[TASK_RED_TARGET] = aim_red_task,
	[TASK_PINK_TARGET] = aim_pink_task,
	[TASK_BLUE_TARGET] = aim_blue_task,
	[TASK_ORANGE_TARGET] = aim_orange_task,
	[TASK_RED_FLEE] = flee_red_task,
	[TASK_PINK_FLEE] = flee_pink_task,
	[TASK_BLUE_FLEE] = flee_blue_task,
	[TASK_ORANGE_FLEE] = flee_orange_task,
	[TASK_DIFFICULTY] = load_difficulty,
	[TASK_CLEAR_ACTORS] = clear_actors_task,
	[TASK_RESET_PILLS] = reset_pills_task,
	[TASK_ERASE_PILLS] = erase_pills_task,
	[TASK_DIP_SWITCHES] = read_dip_switches_task,
	[TASK_PILL_BITMAP] = pill_bitmap_task,
	[TASK_NEXT_LEVEL_STATE] = task_next_level_state,
	[TASK_DEMO_STEER] = demo_steer_task,
	[TASK_DRAW_SCORES] = draw_scores_task,
	[TASK_ADD_SCORE] = add_score,
	[TASK_LIVES_ROW] = draw_lives_row_task,
	[TASK_FRUIT_ROW] = draw_fruit_row_task,
	[TASK_TEXT] = text_task,
	[TASK_CREDITS] = show_credits_task,
	[TASK_CLEAR_SPRITES] = clear_actor_positions_task,
	[TASK_BONUS_DIGITS] = draw_bonus_digits_task,
};

/* Task $15 is in the table, but the game calls pill_bitmap directly and
 * never queues it, so pill_bitmap_task is unverified. */

/* Stop the replay with a message. A green run never gets here. */
static void fail(Board *b, const char *why)
{
	if (b->mismatch)
		return;
	b->mismatch = 1;
	snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
		 "frame %u %s", b->frame_index, why);
	fprintf(stderr, "lift: %s\n", b->corpus.mismatch_msg);
}

static void fill(Board *b, uint16_t addr, uint16_t count, uint8_t value)
{
	uint16_t i;

	for (i = 0; i < count; i++)
		board_mem_write(b, (uint16_t)(addr + i), value);
}

#define WATCHDOG 0x50C0u

/* $234B. Kick the watchdog, then clear the latches, the work RAM the
 * boot clears, the voice registers, the screen, and the task list.
 * Interrupts go on last. Unverified: every corpus session starts from a
 * snapshot taken after this, and none presses the service switch. */
void game_start(Board *b)
{
	LOWER_HOOK(game_start, b);
	WorkRam *ram = work_ram(b->mem);

	board_mem_write(b, WATCHDOG, 0);
	fill(b, 0x5000, 8, 0);
	memset(ram, 0, 0xBE);
	fill(b, 0x5040, 0x40, 0);
	board_mem_write(b, WATCHDOG, 0);
	clear_colors(b);
	board_mem_write(b, WATCHDOG, 0);
	clear_screen(b, 0);
	board_mem_write(b, WATCHDOG, 0);
	ram->task_list_tail_ptr = (uint8_t)MAIN_TASK_LIST;
	ram->task_list_tail_ptr_hi = (uint8_t)(MAIN_TASK_LIST >> 8);
	ram->task_list_head_ptr = (uint8_t)MAIN_TASK_LIST;
	ram->task_list_head_ptr_hi = (uint8_t)(MAIN_TASK_LIST >> 8);
	memset(ram->main_task_list, 0xFF, sizeof ram->main_task_list);
	board_mem_write(b, 0x5000, 1);
	b->int_enabled = 1;
	b->started = 1;
}

/* Consume one task byte and its parameter. The second inc of L wraps
 * to $C0, which is the only wrap the dispatcher does. */
static int take_task(Board *b, uint8_t *task, uint8_t *param)
{
	WorkRam *ram = work_ram(b->mem);
	uint16_t hl = (uint16_t)(ram->task_list_head_ptr |
				 (uint16_t)((uint16_t)ram->task_list_head_ptr_hi << 8));
	uint8_t *slot = work_byte(ram, hl);
	uint8_t t = *slot;
	uint8_t l;

	if ((t & 0x80u) != 0)
		return 0;
	*slot = 0xFF;
	l = (uint8_t)((uint8_t)hl + 1u);
	hl = (uint16_t)((hl & 0xFF00u) | l);
	slot = work_byte(ram, hl);
	*param = *slot;
	*slot = 0xFF;
	l = (uint8_t)(l + 1u);
	if (l == 0)
		l = 0xC0;
	hl = (uint16_t)((hl & 0xFF00u) | l);
	ram->task_list_head_ptr = (uint8_t)hl;
	ram->task_list_head_ptr_hi = (uint8_t)(hl >> 8);
	*task = t;
	return 1;
}

/* Run queued tasks until the list is empty. Returns 0, or -1 when the
 * list holds a byte that is not a task or never empties; those are
 * replay failures, not game paths. */
int sched_tasks(Board *b)
{
	LOWER_HOOK(sched_tasks, b);
	int guard = 0;

	while (!b->mismatch && guard++ < 100000) {
		uint8_t task;
		uint8_t param;
		char why[64];

		if (!take_task(b, &task, &param))
			return 0;
		if (task >= 32) {
			snprintf(why, sizeof why, "task %02X is not in the table", task);
			fail(b, why);
			return -1;
		}
		k_task[task](b, param);
	}
	if (!b->mismatch)
		fail(b, "task list did not empty");
	return -1;
}
