/* Per-board difficulty: speeds, ghost-house limits, Blinky's "cruise
 * elroy" thresholds, and the frightened time. */
#include "game.h"

#define DIFFICULTY_ROWS 0x0796u /* 6 bytes per row */
#define SPEED_PATTERNS  0x330Fu /* 42 bytes per entry */
#define EXIT_LIMITS     0x0843u /* 3 bytes per entry */
#define ELROY_PILLS     0x084Fu /* 2 bytes per entry */
#define BLUE_TIMES      0x0861u /* word per entry */
#define LEAVE_HOME      0x0873u /* word per entry */

/* $070E  task $10. The parameter is the row; 0 takes it from the
 * difficulty pointer. */
void load_difficulty(Board *b, uint8_t index)
{
	LOWER_HOOK(load_difficulty, b, index);
	WorkRam *ram = work_ram(b->mem);
	uint16_t row;
	uint16_t speeds;
	uint16_t speed_dst = RAM_ADDR(pac_speed);
	unsigned g;

	if (index == 0)
		index = board_mem_read(b, (uint16_t)(ram->difficulty_ptr_lo |
						     (uint16_t)(ram->difficulty_ptr_hi << 8)));
	row = (uint16_t)(DIFFICULTY_ROWS + (uint8_t)(index * 6u));

	/* $0814: Ms. Pac-Man's and the shared patterns, the same 12-byte
	 * ghost patterns for each ghost, then the reversal schedule. */
	speeds = (uint16_t)(SPEED_PATTERNS + (uint8_t)(rom8(b, row) * 42u));
	copy_bytes(b, speed_dst, speeds, 0x1C);
	for (g = 1; g < 4; g++)
		copy_bytes(b, (uint16_t)(speed_dst + 0x1Cu + 12u * (g - 1u)),
			   (uint16_t)(speeds + 0x10u), 12);
	copy_bytes(b, RAM_ADDR(ghost_orient_table), (uint16_t)(speeds + 0x1Cu), 14);

	ram->diff_unused_4db0 = rom8(b, (uint16_t)(row + 1u));
	copy_bytes(b, RAM_ADDR(pink_exit_limit),
		   (uint16_t)(EXIT_LIMITS + (uint8_t)(rom8(b, (uint16_t)(row + 2u)) * 3u)), 3);
	copy_bytes(b, RAM_ADDR(elroy1_pill_threshold),
		   (uint16_t)(ELROY_PILLS + (uint8_t)(rom8(b, (uint16_t)(row + 3u)) * 2u)), 2);
	copy_bytes(b, RAM_ADDR(frightened_time_lo),
		   (uint16_t)(BLUE_TIMES + (uint8_t)(rom8(b, (uint16_t)(row + 4u)) * 2u)), 2);
	copy_bytes(b, RAM_ADDR(ghost_leave_home_units_lo),
		   (uint16_t)(LEAVE_HOME + (uint8_t)(rom8(b, (uint16_t)(row + 5u)) * 2u)), 2);
	draw_fruit_row(b);
}

/* $20D7  once the orange ghost is out, Blinky speeds up in two steps as
 * the pills run down. */
void update_elroy(Board *b)
{
	LOWER_HOOK(update_elroy, b);
	WorkRam *ram = work_ram(b->mem);
	uint8_t remain;

	if (ram->substate[ACT_ORANGE] == 0)
		return;
	remain = (uint8_t)(0xF4u - ram->dots_eaten);
	if (ram->cruise_elroy_1 == 0) {
		if (ram->elroy1_pill_threshold < remain)
			return;
		ram->cruise_elroy_1 = 1;
	}
	if (ram->cruise_elroy_2 != 0 || ram->elroy2_pill_threshold < remain)
		return;
	ram->cruise_elroy_2 = 1;
}
