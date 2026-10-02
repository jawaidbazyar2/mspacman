#include "lift.h"

/* j_0369  draw "1UP"
 * Entry:    IX = first screen cell (the caller loads $43D8).
 *           Flags are live-in.
 * Exit:     (IX) = $50 'P', (IX+1) = $55 'U', (IX+2) = $31 '1'.
 *           Registers and flags are unchanged.
 *           Host finishes the RET.
 * Clobbers: none
 * Flags live-out: all. The blink path tests Z on the next instruction
 *           (`call nz` after `bit 4,a` / `call z`).
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0369(Board *b)
{
	uint16_t ix = Z80_IX(b->cpu);

	board_mem_write(b, ix, 0x50);
	board_mem_write(b, (uint16_t)(ix + 1u), 0x55);
	board_mem_write(b, (uint16_t)(ix + 2u), 0x31);
}

/* j_0376  draw "2UP"
 * Entry:    IY = first screen cell (the caller loads $43C5).
 *           Flags are live-in.
 * Exit:     (IY) = $50 'P', (IY+1) = $55 'U', (IY+2) = $32 '2'.
 *           Registers and flags are unchanged.
 *           Host finishes the RET.
 * Clobbers: none
 * Flags live-out: all. The blink path tests Z on the next instruction
 *           (`call nz` after `bit 4,a` / `call z`).
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0376(Board *b)
{
	uint16_t iy = Z80_IY(b->cpu);

	board_mem_write(b, iy, 0x50);
	board_mem_write(b, (uint16_t)(iy + 1u), 0x55);
	board_mem_write(b, (uint16_t)(iy + 2u), 0x32);
}

/* j_0383  clear "1UP"
 * Entry:    IX = first screen cell. Flags are live-in.
 * Exit:     (IX), (IX+1), and (IX+2) = $40, a blank.
 *           Registers and flags are unchanged.
 *           Host finishes the RET.
 * Clobbers: none
 * Flags live-out: all. The caller tests the blink bit before this call.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0383(Board *b)
{
	uint16_t ix = Z80_IX(b->cpu);

	board_mem_write(b, ix, 0x40);
	board_mem_write(b, (uint16_t)(ix + 1u), 0x40);
	board_mem_write(b, (uint16_t)(ix + 2u), 0x40);
}

/* j_0390  clear "2UP"
 * Entry:    IY = first screen cell. Flags are live-in.
 * Exit:     (IY), (IY+1), and (IY+2) = $40, a blank.
 *           Registers and flags are unchanged.
 *           Host finishes the RET.
 * Clobbers: none
 * Flags live-out: all. The caller tests the player count before this call.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0390(Board *b)
{
	uint16_t iy = Z80_IY(b->cpu);

	board_mem_write(b, iy, 0x40);
	board_mem_write(b, (uint16_t)(iy + 1u), 0x40);
	board_mem_write(b, (uint16_t)(iy + 2u), 0x40);
}

/* Even parity sets P/V. */
static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

/* `and n`. H is set. N and C are clear. Flags depend only on the result. */
static uint8_t and_flags(uint8_t result)
{
	return (uint8_t)(0x10u | parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

/* `cp n`. A is not modified. Y and X come from the operand. */
static uint8_t cp_flags(uint8_t a, uint8_t n)
{
	uint8_t diff = (uint8_t)(a - n);
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ n) & (a ^ diff)) & 0x80u) >> 5);

	return (uint8_t)((diff & 0x80u) |
			 (diff == 0 ? 0x40u : 0u) |
			 ((a ^ n ^ diff) & 0x10u) |
			 ov |
			 (a < n ? 1u : 0u) |
			 (n & 0x28u) |
			 0x02u);
}

/* `sub n`. The difference replaces A. */
static uint8_t sub_a(uint8_t a, uint8_t rhs, uint8_t *flags)
{
	uint8_t diff = (uint8_t)(a - rhs);
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ rhs) & (a ^ diff)) & 0x80u) >> 5);

	*flags = (uint8_t)((diff & 0xA8u) |
			   (diff == 0 ? 0x40u : 0u) |
			   ((a ^ rhs ^ diff) & 0x10u) |
			   ov |
			   (a < rhs ? 1u : 0u) |
			   0x02u);
	return diff;
}

/* `bit 4, a`. A is unchanged. Y and X come from A. H is set. C stays. */
static uint8_t bit4_flags(uint8_t a, uint8_t flags)
{
	uint8_t tested = (a & 0x10u) != 0 ? 0u : 0x44u;

	return (uint8_t)(tested | (a & 0x28u) | 0x10u | (flags & 0x01u));
}

/* PUSH writes high byte then low byte, and leaves those bytes after POP. */
static void push_word(Board *b, uint16_t *sp, uint16_t value)
{
	*sp = (uint16_t)(*sp - 2u);
	board_mem_write(b, (uint16_t)(*sp + 1u), (uint8_t)(value >> 8));
	board_mem_write(b, *sp, (uint8_t)value);
}

/* Leave the CALL's return address in memory, then run a lifted callee. */
static void call_lifted(Board *b, uint16_t ret, void (*fn)(Board *))
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, ret);
	Z80_SP(b->cpu) = sp;
	fn(b);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
}

/* j_02fd  blink the start lamps and the 1UP / 2UP labels
 * Entry:    ($4DCE) = the blink counter.
 * Exit:     The counter is one higher. HL = $4DCE.
 *           IX = $43D8 and IY = $43C5, the label cells.
 *           Every 16th count updates the start-lamp latches $5004 and
 *           $5005. With no credits both lamps are 0 and C = 0.
 *           With one credit only the player-1 lamp follows the blink
 *           pattern. With more credits both lamps do. B is the counter's
 *           high nibble on that path and is unchanged otherwise.
 *           Before a game is underway, both labels are drawn and A is
 *           ($4E03), F that `cp #02`.
 *           During play, the current player's label blinks with bit 4 of
 *           the counter, and a one-player game clears "2UP". A is
 *           ($4E70). F is `and a` of that byte.
 *           The stack bytes below SP are the last label call.
 *           Host finishes the RET.
 * Clobbers: A, F, IX, IY, and B, C when the lamps update
 * Flags live-out: Z when no game is underway and ($4E03) < 2, or when
 *           the player count is 0.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: up to two calls, all returned. Callees are already C.
 */
void j_02fd(Board *b)
{
	uint8_t counter = (uint8_t)(board_mem_read(b, 0x4DCE) + 1u);
	uint8_t a = (uint8_t)(counter & 0x0Fu);
	uint8_t flags = and_flags(a);

	board_mem_write(b, 0x4DCE, counter);
	Z80_HL(b->cpu) = 0x4DCE;
	if (a == 0) {
		uint8_t breg = (uint8_t)(counter >> 4);
		uint8_t creg = (uint8_t)((uint8_t)~board_mem_read(b, 0x4DD6) | breg);

		a = sub_a(board_mem_read(b, 0x4E6E), 0x01, &flags);
		if ((flags & 0x01u) != 0) {
			a = 0;
			flags = 0x44;
			creg = 0;
		}
		if ((flags & 0x40u) == 0)
			a = creg;
		board_mem_write(b, 0x5005, a);
		board_mem_write(b, 0x5004, creg);
		Z80_B(b->cpu) = breg;
		Z80_C(b->cpu) = creg;
	}

	Z80_IX(b->cpu) = 0x43D8;
	Z80_IY(b->cpu) = 0x43C5;
	a = board_mem_read(b, 0x4E00);
	flags = cp_flags(a, 0x03);
	if ((flags & 0x40u) == 0) {
		a = board_mem_read(b, 0x4E03);
		flags = cp_flags(a, 0x02);
		if ((flags & 0x01u) != 0) {
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			call_lifted(b, 0x0340, j_0369);
			call_lifted(b, 0x0343, j_0376);
			return;
		}
	}

	flags = and_flags(board_mem_read(b, 0x4E09));
	a = counter;
	flags = bit4_flags(a, flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((and_flags(board_mem_read(b, 0x4E09)) & 0x40u) != 0) {
		if ((flags & 0x40u) != 0)
			call_lifted(b, 0x0353, j_0369);
		else
			call_lifted(b, 0x0356, j_0383);
	} else if ((flags & 0x40u) != 0)
		call_lifted(b, 0x035E, j_0376);
	else
		call_lifted(b, 0x0361, j_0390);

	a = board_mem_read(b, 0x4E70);
	flags = and_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		call_lifted(b, 0x0368, j_0390);
}
