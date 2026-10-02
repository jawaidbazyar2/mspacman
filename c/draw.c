#include "lift.h"

/* `add hl, rr`. S, Z, and P/V stay. Y and X come from the high byte.
 * H is the carry out of bit 11. C is the carry out of bit 15. N clears.
 */
static uint8_t add_hl_flags(uint16_t hl, uint16_t rhs, uint8_t flags, uint16_t *sum)
{
	uint32_t total = (uint32_t)hl + rhs;
	uint16_t result = (uint16_t)total;
	uint8_t high = (uint8_t)(total >> 8);

	*sum = result;
	return (uint8_t)((flags & 0xC4u) |
			 (high & 0x28u) |
			 (uint8_t)(((hl ^ rhs ^ result) >> 8) & 0x10u) |
			 (total > 0xFFFFu ? 1u : 0u));
}

/* PUSH writes high byte then low byte, and leaves those bytes after POP. */
static void push_word(Board *b, uint16_t *sp, uint16_t value)
{
	*sp = (uint16_t)(*sp - 2u);
	board_mem_write(b, (uint16_t)(*sp + 1u), (uint8_t)(value >> 8));
	board_mem_write(b, *sp, (uint8_t)value);
}

/* j_2b80  paint a 2x2 block with one tile code
 * Entry:    HL = top-left screen cell. A = tile. Flags' S, Z, P/V are live-in.
 * Exit:     (HL), (HL+1), (HL+$20), (HL+$21) = A.
 *           HL and DE are restored by the pushes. A is unchanged.
 *           The four stack bytes below SP still hold the saved HL and DE.
 *           F is `add hl, de` of (HL+1) + $001F. N is clear.
 *           Host finishes the RET.
 * Clobbers: F
 * Flags live-out: none. Both callers replace F with `add a,h`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: two pushes, both popped before the RET. No callee.
 */
void j_2b80(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t at;
	uint8_t tile = Z80_A(b->cpu);

	push_word(b, &sp, hl);
	push_word(b, &sp, Z80_DE(b->cpu));
	board_mem_write(b, hl, tile);
	hl = (uint16_t)(hl + 1u);
	board_mem_write(b, hl, tile);
	Z80_F(b->cpu) = add_hl_flags(hl, 0x001F, Z80_F(b->cpu), &at);
	board_mem_write(b, at, tile);
	board_mem_write(b, (uint16_t)(at + 1u), tile);
}

/* j_2b7e  paint a 2x2 block with the blank tile
 * Entry:    HL = top-left screen cell. Flags' S, Z, P/V are live-in.
 * Exit:     A = $40. Otherwise the same as j_2b80.
 *           Host finishes the RET.
 * Clobbers: A, F
 * Flags live-out: none. Callers replace F or branch without testing it.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the same two pushes as j_2b80. No callee.
 */
void j_2b7e(Board *b)
{
	Z80_A(b->cpu) = 0x40;
	j_2b80(b);
}

/* `inc a`. S, Z, H, P/V, Y, X from the result. N clear. C unchanged. */
static uint8_t inc_a_flags(uint8_t value, uint8_t flags, uint8_t *next)
{
	uint8_t result = (uint8_t)(value + 1u);

	*next = result;
	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x7Fu ? 0x04u : 0u) |
			 (flags & 0x01u));
}

/* j_2b8f  paint the four parts of a fruit or an extra life
 * Entry:    HL = top-left screen cell. A = first tile.
 *           Flags' carry is live-in, and stays through the first two `inc a`.
 * Exit:     (HL) = A, (HL+1) = A+1, (HL+$20) = A+2, (HL+$21) = A+3.
 *           A = A+3. HL and DE are restored. The four stack bytes below SP
 *           still hold the saved HL and the original DE.
 *           F is the third `inc a`. Its carry is the carry from
 *           `add hl, de` of (HL+1) + $001F.
 *           Host finishes the RET.
 * Clobbers: A, F
 * Flags live-out: C. The extra-life caller keeps it in `dec c`.
 *           The fruit caller replaces F with `add a,h`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: two pushes, both popped before the RET. No callee.
 */
void j_2b8f(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t at;
	uint8_t a = Z80_A(b->cpu);
	uint8_t flags = Z80_F(b->cpu);

	push_word(b, &sp, hl);
	push_word(b, &sp, Z80_DE(b->cpu));
	board_mem_write(b, hl, a);
	flags = inc_a_flags(a, flags, &a);
	hl = (uint16_t)(hl + 1u);
	board_mem_write(b, hl, a);
	flags = inc_a_flags(a, flags, &a);
	flags = add_hl_flags(hl, 0x001F, flags, &at);
	board_mem_write(b, at, a);
	flags = inc_a_flags(a, flags, &a);
	board_mem_write(b, (uint16_t)(at + 1u), a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
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

/* j_9627  draw a tile/color list until a $FF marker
 * Entry:    HL points at records of color, tile, address low, address high.
 * Exit:     Each record is drawn at its address, and the color byte is
 *           drawn at that address with bit 2 of the high byte set.
 *           HL points at the $FF. A = $FF. F is `cp $FF`.
 *           B is the last color. DE is the last color address.
 *           Host finishes the RET.
 * Clobbers: A, F, B, DE, HL
 * Flags live-out: none. The caller pops HL and BC without testing F.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_9627(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint8_t a = board_mem_read(b, hl);

	while (a != 0xFFu) {
		uint8_t color = a;
		uint16_t de;

		hl = (uint16_t)(hl + 1u);
		a = board_mem_read(b, hl);
		hl = (uint16_t)(hl + 1u);
		de = board_mem_read(b, hl);
		hl = (uint16_t)(hl + 1u);
		de = (uint16_t)(de | (uint16_t)((uint16_t)board_mem_read(b, hl) << 8));
		board_mem_write(b, de, a);
		de = (uint16_t)(de | 0x0400u);
		board_mem_write(b, de, color);
		hl = (uint16_t)(hl + 1u);
		Z80_B(b->cpu) = color;
		Z80_DE(b->cpu) = de;
		a = board_mem_read(b, hl);
	}
	Z80_A(b->cpu) = a;
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = cp_flags(a, 0xFF);
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

/* `add a, n`. The sum replaces A. */
static uint8_t add_a(uint8_t a, uint8_t rhs, uint8_t *flags)
{
	uint16_t sum = (uint16_t)((uint16_t)a + rhs);
	uint8_t result = (uint8_t)sum;
	uint8_t inv = (uint8_t)~rhs;
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ inv) & (a ^ result)) & 0x80u) >> 5);

	*flags = (uint8_t)((sum > 255u ? 1u : 0u) |
			   ov |
			   ((a ^ rhs ^ result) & 0x10u) |
			   (result & 0xA8u) |
			   (result == 0 ? 0x40u : 0u));
	return result;
}

/* `dec c`. C is unchanged in the flags, and is kept from the previous add. */
static uint8_t dec_c_flags(uint8_t value, uint8_t flags, uint8_t *next)
{
	uint8_t result = (uint8_t)(value - 1u);

	*next = result;
	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x80u ? 0x04u : 0u) |
			 0x02u |
			 (flags & 0x01u));
}

/* Add a byte to H and leave that sum in A. */
static uint16_t add_h(uint16_t hl, uint8_t rhs, uint8_t *flags, uint8_t *a)
{
	*a = add_a(rhs, (uint8_t)(hl >> 8), flags);
	return (uint16_t)((hl & 0x00FFu) | (uint16_t)((uint16_t)*a << 8));
}

/* j_2bea  draw the fruit row for this level
 * Entry:    ($4E00) = game mode. ($4E13) = level, counting from 0.
 * Exit:     In attract mode (game mode 1): A = 1, F is `cp #01`, and
 *           nothing is drawn.
 *           Otherwise the row at $4004 gets one fruit per level, capped
 *           at 7, and the rest of the seven slots are cleared. The fruit
 *           bytes come from the table at $3B08. B = 0. C = the `dec`
 *           that went negative. DE has walked two bytes per fruit.
 *           HL has walked two cells per slot. A is the video high byte
 *           after the last `add a, $FC`. F is that negative `dec c`,
 *           whose carry is the carry from the last `add a, $FC`.
 *           The jump to j_8793 is part of this routine. The Pac-Man
 *           path at $2C2E is not reached.
 *           The stack bytes below SP are the last paint call and the
 *           HL and DE that paint pushed.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: Z in attract mode. S when the row is finished.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: two calls per fruit and two per blank, all returned.
 *           Callees are already C.
 */
void j_2bea(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4E00);
	uint8_t flags = cp_flags(a, 0x01);
	uint8_t fruits;
	uint8_t c;
	uint16_t de;
	uint16_t hl;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return;

	a = (uint8_t)(board_mem_read(b, 0x4E13) + 1u);
	flags = cp_flags(a, 0x08);
	if ((flags & 0x01u) == 0)
		a = 7;
	fruits = a;
	c = 7;
	de = 0x3B08;
	hl = 0x4004;
	do {
		Z80_HL(b->cpu) = hl;
		Z80_DE(b->cpu) = de;
		Z80_A(b->cpu) = board_mem_read(b, de);
		Z80_F(b->cpu) = flags;
		call_lifted(b, 0x2C06, j_2b8f);
		hl = add_h(hl, 0x04, &flags, &a);
		de = (uint16_t)(de + 1u);
		Z80_HL(b->cpu) = hl;
		Z80_DE(b->cpu) = de;
		Z80_A(b->cpu) = board_mem_read(b, de);
		Z80_F(b->cpu) = flags;
		call_lifted(b, 0x2C0F, j_2b80);
		hl = add_h(hl, 0xFC, &flags, &a);
		de = (uint16_t)(de + 1u);
		hl = (uint16_t)(hl + 2u);
		flags = dec_c_flags(c, flags, &c);
		fruits = (uint8_t)(fruits - 1u);
	} while (fruits != 0);

	for (;;) {
		flags = dec_c_flags(c, flags, &c);
		if ((flags & 0x80u) != 0)
			break;
		Z80_HL(b->cpu) = hl;
		Z80_DE(b->cpu) = de;
		Z80_F(b->cpu) = flags;
		call_lifted(b, 0x2C1E, j_2b7e);
		hl = add_h(hl, 0x04, &flags, &a);
		a = 0;
		flags = 0x44;
		Z80_HL(b->cpu) = hl;
		Z80_DE(b->cpu) = de;
		Z80_A(b->cpu) = 0;
		Z80_F(b->cpu) = flags;
		call_lifted(b, 0x2C26, j_2b80);
		hl = add_h(hl, 0xFC, &flags, &a);
		hl = (uint16_t)(hl + 2u);
	}

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_BC(b->cpu) = c;
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = hl;
}
