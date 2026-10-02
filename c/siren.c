#include "lift.h"

/* Even parity sets P/V. */
static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

/* `and`. H is set. N and C are clear. Flags come from the result. */
static uint8_t and_flags(uint8_t result)
{
	return (uint8_t)(0x10u | parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

/* j_0e6c  pick the chase siren from the number of dots eaten
 * Entry:    ($4DA5) = death animation. ($4E0E) = dots eaten.
 *           ($4EAC) = sound channel 2.
 * Exit:     If the death animation is running: ($4EAC) = 0, A = 0,
 *           F is `xor a`.
 *           Otherwise HL = $4EAC and B = $E0. The channel keeps its top
 *           three bits and gains one siren bit: bit 4 at $E4 dots,
 *           bit 3 at $D4, bit 2 at $B4, bit 1 at $74, otherwise bit 0.
 *           A is the stored byte. F is the `and` from before `set`,
 *           so the new bit is not in the flags.
 *           Host finishes the RET.
 * Clobbers: A, F, and B, HL when the chase siren is written
 * Flags live-out: none. The caller continues the per-frame update.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee. The `jp` at $0EAD is the next routine.
 */
void j_0e6c(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA5);
	uint8_t dots;
	uint8_t bit;
	uint8_t masked;

	if (a != 0) {
		board_mem_write(b, 0x4EAC, 0);
		Z80_A(b->cpu) = 0;
		Z80_F(b->cpu) = 0x44;
		return;
	}
	dots = board_mem_read(b, 0x4E0E);
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
	masked = (uint8_t)(0xE0u & board_mem_read(b, 0x4EAC));
	a = (uint8_t)(masked | bit);
	board_mem_write(b, 0x4EAC, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_flags(masked);
	Z80_B(b->cpu) = 0xE0;
	Z80_HL(b->cpu) = 0x4EAC;
}
