#include "lift.h"

/* Even parity sets P/V, matching the core's parity table for `and a`. */
static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

/* j_2b0b  point HL at the current player's score
 * Entry:    player number at $4E09 (0 = player 1, nonzero = player 2).
 * Exit:     A = that byte. HL = $4E80 for player 1, $4E84 otherwise.
 *           F is the `and a` result: H set, N clear, P/V = parity of A,
 *           Z set when A is 0, S/Y/X copied from A.
 *           Host finishes the RET.
 * Clobbers: A, F, HL
 * Flags live-out: none. Both callers overwrite A before they test flags.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_2b0b(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4E09);
	uint8_t flags = (uint8_t)(0x10u | parity_pv(a) | (a & 0xA8u));
	uint16_t hl = 0x4E80;

	if (a == 0)
		flags = (uint8_t)(flags | 0x40u);
	else
		hl = 0x4E84;
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = hl;
}
