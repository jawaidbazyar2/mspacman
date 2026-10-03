/* The frame clock and the 16 timed tasks it counts down. */
#include "game.h"

/* Limits for the four clock counters, two bytes each: the low nibble
 * that carries into the high nibble, then the high nibble value that
 * wraps the counter to 0. */
#define CLOCK_LIMITS 0x0219u

/* Advance the frame counters ($01DC). The sound counter counts up, the
 * unused byte after it counts down, and the four clock counters tick
 * with carries. clock_limit_changes is 1 plus the number of nibble
 * carries and wraps this frame; the timed tasks use it to decide which
 * units count down. The two unused random bytes step as x*5+1 and
 * x*13+1. */
void clock_tick(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t *counter = &ram->clock_hundredths;
	uint8_t changes = 1;
	unsigned i;

	ram->SOUND_COUNTER++;
	ram->timer_unused_4c85--;
	for (i = 0; i < 4; i++) {
		uint16_t limit = (uint16_t)(CLOCK_LIMITS + 2u * i);
		uint8_t value = ++counter[i];

		if ((value & 0x0Fu) != rom8(b, limit))
			break;
		changes++;
		value = (uint8_t)((value + 0x10u) & 0xF0u);
		counter[i] = value;
		if (value != rom8(b, (uint16_t)(limit + 1u)))
			break;
		changes++;
		counter[i] = 0;
	}
	ram->clock_limit_changes = changes;
	ram->rng_unused_4c8b = (uint8_t)(ram->rng_unused_4c8b * 5u + 1u);
	ram->rng_unused_4c8c = (uint8_t)(ram->rng_unused_4c8c * 13u + 1u);
}

/* Timed task 0 ($0894). Also task $16. */
void advance_level_state(Board *b)
{
	work_ram(b->mem)->level_state++;
}

/* Timed task 1 ($06A3). */
void advance_play_state(Board *b)
{
	work_ram(b->mem)->game_mode_sub2++;
}

/* Timed task 2 ($058E). */
void advance_attract_state(Board *b)
{
	work_ram(b->mem)->game_mode_sub1++;
}

/* Timed task 3 ($1272). */
void advance_eaten_ghost_anim(Board *b)
{
	work_ram(b->mem)->killed_ghost_anim++;
}

/* Timed task 6 ($0263): erase READY! with text $06 (bit 7 erases). */
static void clear_ready(Board *b)
{
	queue_task(b, TASK_TEXT, 0x86);
}

/* Timed tasks 7-9 ($212B, $21F0, $22B9). Pac-Man's intermissions queue
 * them; Ms. Pac-Man never does. */
void advance_cutscene1(Board *b)
{
	work_ram(b->mem)->cutscene1_state++;
}

void advance_cutscene2(Board *b)
{
	work_ram(b->mem)->cutscene2_state++;
}

void advance_cutscene3(Board *b)
{
	work_ram(b->mem)->cutscene3_state++;
}

static void (*const k_timed[10])(Board *) = {
	[TT_LEVEL_STATE] = advance_level_state,
	[TT_PLAY_STATE] = advance_play_state,
	[TT_ATTRACT_STATE] = advance_attract_state,
	[TT_EATEN_GHOST] = advance_eaten_ghost_anim,
	[TT_CLEAR_FRUIT] = clear_fruit,
	[TT_CLEAR_FRUIT_POS] = clear_fruit_pos,
	[TT_CLEAR_READY] = clear_ready,
	[TT_CUTSCENE1] = advance_cutscene1,
	[TT_CUTSCENE2] = advance_cutscene2,
	[TT_CUTSCENE3] = advance_cutscene3,
};

/* Count down the 16 timed-task slots ($0221). A slot is three bytes:
 * timer, task, parameter. A zero timer is a free slot. A slot whose
 * unit is below clock_limit_changes counts down; one that reaches 0 is
 * freed and its task runs. A task may queue into any free slot,
 * including the one it just left. No timed task reads its parameter. */
void timers_run(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t changes = ram->clock_limit_changes;
	unsigned i;

	for (i = 0; i < 16; i++) {
		uint8_t *slot = &ram->timed_task_list[3 * i];
		uint8_t timer = slot[0];

		if (timer == 0 || (timer >> 6) >= changes)
			continue;
		timer--;
		slot[0] = timer;
		if ((timer & 0x3Fu) != 0)
			continue;
		slot[0] = 0;
		if (slot[1] < 10)
			k_timed[slot[1]](b);
	}
}

/* Put a task in the first free timed slot (`rst $30`). Returns false when
 * all 16 are taken; the Z80 then ran the three data bytes as
 * instructions, which only touched registers. Unverified: the list is
 * never full in the corpus. */
bool queue_timed(Board *b, uint8_t timer, uint8_t task, uint8_t param)
{
	WorkRam *ram = work_ram(b->mem);
	unsigned i;

	for (i = 0; i < 16; i++) {
		uint8_t *slot = &ram->timed_task_list[3 * i];

		if (slot[0] == 0) {
			slot[0] = timer;
			slot[1] = task;
			slot[2] = param;
			return true;
		}
	}
	return false;
}
