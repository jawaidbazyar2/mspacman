/* The game's random numbers. */
#include "game.h"

/* Next byte of the ROM random stream ($2A23). The pointer at
 * rng_rom_ptr steps to pointer * 5 + 1, kept inside $0000-$1FFF, and the
 * ROM byte there is the result. */
uint8_t rom_random(Board *b)
{
	LOWER_HOOK(rom_random, b);
	WorkRam *ram = work_ram(b->mem);
	uint16_t ptr = (uint16_t)(ram->rng_rom_ptr_lo |
				  (uint16_t)((uint16_t)ram->rng_rom_ptr_hi << 8));

	ptr = (uint16_t)((uint16_t)(ptr * 5u + 1u) & 0x1FFFu);
	ram->rng_rom_ptr_lo = (uint8_t)ptr;
	ram->rng_rom_ptr_hi = (uint8_t)(ptr >> 8);
	return board_mem_read(b, ptr);
}
