/* Queueing main tasks. sched.c runs them. */
#include "game.h"

/* Append a task and its parameter to the main task list ($0042).
 * The tail pointer at task_list_tail_ptr advances two bytes. Only the
 * second step wraps, from $4D00 back to $4CC0. */
void queue_task(Board *b, uint8_t task, uint8_t param)
{
	WorkRam *ram = work_ram(b->mem);
	uint16_t tail = (uint16_t)(ram->task_list_tail_ptr |
				   (uint16_t)((uint16_t)ram->task_list_tail_ptr_hi << 8));
	uint8_t low = (uint8_t)tail;

	*work_byte(ram, tail) = task;
	low = (uint8_t)(low + 1u);
	*work_byte(ram, (uint16_t)((tail & 0xFF00u) | low)) = param;
	low = (uint8_t)(low + 1u);
	if (low == 0)
		low = (uint8_t)MAIN_TASK_LIST;
	ram->task_list_tail_ptr = low;
	ram->task_list_tail_ptr_hi = (uint8_t)(tail >> 8);
}

/* Task $16 ($23E8): advance the level state. Unverified: the game never
 * queues it. */
void task_next_level_state(Board *b, uint8_t param)
{
	(void)param;
	work_ram(b->mem)->level_state++;
}
