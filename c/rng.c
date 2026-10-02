#include "lift.h"

/* Even parity sets P/V, matching `and`. */
static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

/* j_2a23  next byte from the ROM random stream
 * Entry:    ($4DC9) = the current ROM pointer, kept in $0000..$1FFF.
 * Exit:     HL = ((old * 5) + 1) with the high byte masked by $1F.
 *           DE = the old pointer. A = the byte at the new HL.
 *           ($4DC9) = the new pointer.
 *           F is `and $1F` on the high byte before A is loaded from ROM.
 *           Host finishes the RET.
 * Clobbers: A, F, DE, HL
 * Flags live-out: none. The caller masks A with `and 3`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_2a23(Board *b)
{
	uint16_t lo = board_mem_read(b, 0x4DC9);
	uint16_t hi = board_mem_read(b, 0x4DCA);
	uint16_t old = (uint16_t)(lo | (uint16_t)(hi << 8));
	uint16_t hl = (uint16_t)(old + old);
	uint8_t masked;

	hl = (uint16_t)(hl + hl);
	hl = (uint16_t)(hl + old);
	hl = (uint16_t)(hl + 1u);
	masked = (uint8_t)((hl >> 8) & 0x1Fu);
	hl = (uint16_t)((hl & 0x00FFu) | (uint16_t)((uint16_t)masked << 8));
	Z80_A(b->cpu) = board_mem_read(b, hl);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = old;
	Z80_F(b->cpu) = (uint8_t)(0x10u | parity_pv(masked) |
				  (masked & 0xA8u) |
				  (masked == 0 ? 0x40u : 0u));
	board_mem_write(b, 0x4DC9, (uint8_t)hl);
	board_mem_write(b, 0x4DCA, (uint8_t)(hl >> 8));
}
