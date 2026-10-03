/* The background siren, which rises as the board empties. */
#include "game.h"

/* Pick the chase siren from the dots eaten ($0E6C). The siren is one of
 * the low five bits of sound channel 2's effect byte. The top three bits
 * are kept. While Ms. Pac-Man is dying the channel is silenced. */
void siren_update(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t dots = ram->dots_eaten;
	uint8_t bit;

	if (ram->pac_death_anim != 0) {
		ram->effect[1].num = 0;
		return;
	}
	if (dots >= 0xE4u)
		bit = 0x10;
	else if (dots >= 0xD4u)
		bit = 0x08;
	else if (dots >= 0xB4u)
		bit = 0x04;
	else if (dots >= 0x74u)
		bit = 0x02;
	else
		bit = 0x01;
	ram->effect[1].num = (uint8_t)((ram->effect[1].num & 0xE0u) | bit);
}
