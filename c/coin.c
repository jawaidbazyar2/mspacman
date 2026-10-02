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

/* `sub n`. The difference replaces A. */
static uint8_t sub_a(uint8_t a, uint8_t rhs, uint8_t *flags)
{
	uint8_t diff = (uint8_t)(a - rhs);
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ rhs) & (a ^ diff)) & 0x80u) >> 5);
	uint8_t partial = (uint8_t)((a < rhs ? 1u : 0u) |
				    0x02u |
				    ov |
				    ((a ^ rhs ^ diff) & 0x10u));

	*flags = (uint8_t)(partial | (diff & 0xA8u) | (diff == 0 ? 0x40u : 0u));
	return diff;
}

/* `add a, n`. The sum replaces A. */
static uint8_t add_a(uint8_t a, uint8_t rhs, uint8_t *flags)
{
	uint16_t sum = (uint16_t)((uint16_t)a + rhs);
	uint8_t result = (uint8_t)sum;
	uint8_t inv = (uint8_t)~rhs;
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ inv) & (a ^ result)) & 0x80u) >> 5);
	uint8_t partial = (uint8_t)((sum > 255u ? 1u : 0u) |
				    ov |
				    ((a ^ rhs ^ result) & 0x10u));

	*flags = (uint8_t)(partial | (result & 0xA8u) | (result == 0 ? 0x40u : 0u));
	return result;
}

/* `daa`, the core's non-table form. N stays. C stays if it was set. */
static uint8_t daa(uint8_t a, uint8_t *flags)
{
	uint8_t f = *flags;
	uint8_t bcd_carry = a > 0x99u ? 1u : 0u;
	uint8_t corr = ((f & 0x10u) != 0 || (a & 0x0Fu) > 9u) ? 6u : 0u;
	uint8_t result;

	if ((f & 0x01u) != 0 || bcd_carry != 0)
		corr = (uint8_t)(corr | 0x60u);
	if ((f & 0x02u) != 0)
		result = (uint8_t)(a - corr);
	else
		result = (uint8_t)(a + corr);
	*flags = (uint8_t)((f & 0x03u) |
			   (result & 0xA8u) |
			   (result == 0 ? 0x40u : 0u) |
			   ((a ^ result) & 0x10u) |
			   parity_pv(result) |
			   bcd_carry);
	return result;
}

/* j_02df  turn inserted coins into credits
 * Entry:    ($4E6B) = coins per credit. ($4E6C) = coins still short.
 *           ($4E6D) = credits per coin. ($4E6E) = current credits.
 * Exit:     ($4E6C) is incremented. If it does not match ($4E6B):
 *           A is the difference, HL = $4E6C, F is the `sub`, and credits
 *           are unchanged.
 *           If it matches: ($4E6C) = 0, credits are the BCD sum with
 *           ($4E6D), capped at $99. Bit 1 of ($4E9C) is set. HL = $4E9C.
 *           A is the stored credit byte. F is the `daa`.
 *           Host finishes the RET.
 * Clobbers: A, F, HL
 * Flags live-out: none. Callers replace F with `rlc` or `cp`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_02df(Board *b)
{
	uint8_t per = board_mem_read(b, 0x4E6B);
	uint8_t coins = (uint8_t)(board_mem_read(b, 0x4E6C) + 1u);
	uint8_t flags = 0;
	uint8_t a;
	uint8_t sound;

	board_mem_write(b, 0x4E6C, coins);
	a = sub_a(per, coins, &flags);
	Z80_HL(b->cpu) = 0x4E6C;
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	board_mem_write(b, 0x4E6C, 0);
	a = add_a(board_mem_read(b, 0x4E6D), board_mem_read(b, 0x4E6E), &flags);
	a = daa(a, &flags);
	if ((flags & 0x01u) != 0)
		a = 0x99;
	board_mem_write(b, 0x4E6E, a);
	sound = board_mem_read(b, 0x4E9C);
	board_mem_write(b, 0x4E9C, (uint8_t)(sound | 0x02u));
	Z80_HL(b->cpu) = 0x4E9C;
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
}

/* `and a`. H is set. N and C are clear. */
static uint8_t and_a_flags(uint8_t a)
{
	return (uint8_t)(0x10u | parity_pv(a) | (a & 0xA8u) |
			 (a == 0 ? 0x40u : 0u));
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

/* `inc r`. C is unchanged. */
static uint8_t inc_flags(uint8_t value, uint8_t flags)
{
	uint8_t result = (uint8_t)(value + 1u);

	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x7Fu ? 0x04u : 0u) |
			 (flags & 0x01u));
}

/* `dec r`. C is unchanged. */
static uint8_t dec_flags(uint8_t value, uint8_t flags)
{
	uint8_t result = (uint8_t)(value - 1u);

	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x80u ? 0x04u : 0u) |
			 0x02u |
			 (flags & 0x01u));
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

/* j_02ad  debounce the coin counter into credits
 * Entry:    ($4E69) = coins waiting. ($4E6A) = how long the counter
 *           output has been held.
 * Exit:     If no coins are waiting: A = 0, F is `and a`, nothing else
 *           changes.
 *           Otherwise E = the timeout on entry, B = the coin count.
 *           A timeout of 0 stores 1 at the coin-counter latch $5007 and
 *           calls j_02df. A timeout of 8 clears that latch with `xor a`.
 *           ($4E6A) becomes the timeout plus 1. A is that byte minus $10.
 *           F is the `sub` when the result is not zero.
 *           When the result is zero, ($4E6A) = 0, B and ($4E69) lose one
 *           coin, A = B, and F is that `dec b`.
 *           The call's return address ($02C4) is left below SP only on
 *           the timeout-zero path.
 *           Host finishes the RET.
 * Clobbers: A, F, and B, E, HL once a coin is waiting
 * Flags live-out: Z on the empty-counter return. Other callers fall
 *           through into the next task.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: one conditional call, returned. Callee is already C.
 */
void j_02ad(Board *b)
{
	uint8_t count = board_mem_read(b, 0x4E69);
	uint8_t e;
	uint8_t a;
	uint8_t flags;
	uint16_t de;

	if (count == 0) {
		Z80_A(b->cpu) = 0;
		Z80_F(b->cpu) = and_a_flags(0);
		return;
	}

	de = Z80_DE(b->cpu);
	e = board_mem_read(b, 0x4E6A);
	Z80_B(b->cpu) = count;
	if (e == 0) {
		board_mem_write(b, 0x5007, 1);
		Z80_A(b->cpu) = 1;
		call_lifted(b, 0x02C4, j_02df);
	}

	a = e;
	flags = cp_flags(a, 0x08);
	if ((flags & 0x40u) != 0) {
		a = 0;
		flags = 0x44;
		board_mem_write(b, 0x5007, 0);
	}

	flags = inc_flags(e, flags);
	e = (uint8_t)(e + 1u);
	a = e;
	board_mem_write(b, 0x4E6A, a);
	Z80_DE(b->cpu) = (uint16_t)((de & 0xFF00u) | e);
	a = sub_a(a, 0x10, &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;

	board_mem_write(b, 0x4E6A, 0);
	count = (uint8_t)(count - 1u);
	flags = dec_flags((uint8_t)(count + 1u), flags);
	Z80_B(b->cpu) = count;
	Z80_A(b->cpu) = count;
	Z80_F(b->cpu) = flags;
	board_mem_write(b, 0x4E69, count);
}

/* `rla`. S, Z, and P/V stay. H and N clear. C is the old bit 7. */
static uint8_t rla(uint8_t a, uint8_t *flags)
{
	uint8_t cf = (uint8_t)(a >> 7);
	uint8_t result = (uint8_t)((uint8_t)(a << 1) | (*flags & 0x01u));

	*flags = (uint8_t)((*flags & 0xC4u) | (result & 0x28u) | cf);
	return result;
}

/* `rra`. S, Z, and P/V stay. H and N clear. C is the old bit 0. */
static uint8_t rra(uint8_t a, uint8_t *flags)
{
	uint8_t cf = (uint8_t)(a & 1u);
	uint8_t result = (uint8_t)((a >> 1) | (uint8_t)((*flags & 0x01u) << 7));

	*flags = (uint8_t)((*flags & 0xC4u) | (result & 0x28u) | cf);
	return result;
}

/* `rlc r`. Flags come from the rotated byte. C is its new bit 0. */
static uint8_t rlc(uint8_t value, uint8_t *flags)
{
	uint8_t rotated = (uint8_t)((uint8_t)(value << 1) | (value >> 7));

	*flags = (uint8_t)((rotated & 0xA8u) |
			   (rotated == 0 ? 0x40u : 0u) |
			   parity_pv(rotated) |
			   (rotated & 0x01u));
	return rotated;
}

/* Shift one input bit into a 4-bit history and compare it with $0C. */
static uint8_t shift_hist(Board *b, uint16_t addr, uint8_t *flags)
{
	uint8_t a = rla(board_mem_read(b, addr), flags);

	a = (uint8_t)(a & 0x0Fu);
	*flags = and_a_flags(a);
	board_mem_write(b, addr, a);
	return sub_a(a, 0x0C, flags);
}

/* j_0267  sample the coin and service switches
 * Entry:    ($4E6E) = credits. ($4E66), ($4E67), and ($4E68) are the
 *           service, coin-2, and coin-1 histories.
 * Exit:     The coin-lockout latch $5006 gets credits rotated left
 *           through the `cp #99` carry. `rra` restores A to the credit
 *           byte. If that carry is clear (credits >= $99), F is the
 *           `rra` and the routine returns. S, Z, and P/V are still the
 *           `cp`.
 *           Otherwise B is IN0 rotated left three times. Each rotate's
 *           carry is shifted into one history. A history that becomes
 *           $0C after the mask is a new press: service calls j_02df,
 *           and either coin increments ($4E69).
 *           A and F are the last `sub #0c` when that coin was not
 *           pressed, or the `inc (hl)` when it was. HL changes only
 *           when j_02df or a coin increment writes it.
 *           The service call leaves $0286 below SP.
 *           Host finishes the RET.
 * Clobbers: A, F, and B, HL when a switch is accepted
 * Flags live-out: C on the credit return. Z on a coin return that
 *           did not see a press.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: one conditional call, returned. Callee is already C.
 */
void j_0267(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4E6E);
	uint8_t flags = cp_flags(a, 0x99);
	uint8_t breg;
	uint8_t coin;

	a = rla(a, &flags);
	board_mem_write(b, 0x5006, a);
	a = rra(a, &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) == 0)
		return;

	breg = board_mem_read(b, 0x5000);
	breg = rlc(breg, &flags);
	a = shift_hist(b, 0x4E66, &flags);
	if (a == 0) {
		Z80_A(b->cpu) = 0;
		Z80_F(b->cpu) = flags;
		call_lifted(b, 0x0286, j_02df);
	}

	breg = rlc(breg, &flags);
	a = shift_hist(b, 0x4E67, &flags);
	if (a == 0) {
		coin = board_mem_read(b, 0x4E69);
		flags = inc_flags(coin, flags);
		board_mem_write(b, 0x4E69, (uint8_t)(coin + 1u));
		Z80_HL(b->cpu) = 0x4E69;
		a = 0;
	}

	breg = rlc(breg, &flags);
	a = shift_hist(b, 0x4E68, &flags);
	Z80_B(b->cpu) = breg;
	if (a != 0) {
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		return;
	}

	coin = board_mem_read(b, 0x4E69);
	flags = inc_flags(coin, flags);
	board_mem_write(b, 0x4E69, (uint8_t)(coin + 1u));
	Z80_HL(b->cpu) = 0x4E69;
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = flags;
}
