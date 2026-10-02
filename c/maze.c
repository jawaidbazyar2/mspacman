#include "lift.h"

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

/* `add hl, rr`. S, Z, and P/V stay. N is clear. Y and X come from the high byte. */
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

/* `rst $10`: HL = HL + A, A = (HL). The index is the incoming A. */
static uint8_t rst10(Board *b, uint16_t *hl, uint8_t index)
{
	uint8_t flags = 0;
	uint8_t low = add_a(index, (uint8_t)*hl, &flags);
	uint8_t high = (uint8_t)((uint8_t)(*hl >> 8) + (flags & 0x01u));

	*hl = (uint16_t)(((uint16_t)high << 8) | low);
	return board_mem_read(b, *hl);
}

/* j_94bd  look up a per-maze word
 * Entry:    HL = base of a four-entry word table, one word per maze.
 *           ($4E13) = level, counting from 0.
 * Exit:     BC = the word for this level's maze. A = maze number times 2.
 *           HL = the address of the high byte of that word.
 *           Levels 0..12 index the order table at $94DF directly.
 *           A higher level subtracts 13, then 8, while the sign flag
 *           stays clear, then adds 13. The `jp p` tests that sign flag.
 *           F is `add hl, bc`. S, Z, and P/V come from `add a, a` of the
 *           maze number.
 *           The stack bytes below SP are the saved table base and, under
 *           that, the `rst $10` return address $94CA.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, HL
 * Flags live-out: none. Callers use BC.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: one push and the rst, both popped. The rst body is inlined.
 */
void j_94bd(Board *b)
{
	uint16_t base = Z80_HL(b->cpu);
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t order = 0x94DF;
	uint16_t hl;
	uint8_t level = board_mem_read(b, 0x4E13);
	uint8_t flags = cp_flags(level, 0x0D);
	uint8_t a = level;
	uint8_t map;
	uint8_t doubled;
	uint8_t lo;
	uint8_t hi;

	push_word(b, &sp, base);
	push_word(b, &sp, 0x94CA);
	if ((flags & 0x80u) == 0) {
		a = sub_a(a, 0x0D, &flags);
		do
			a = sub_a(a, 0x08, &flags);
		while ((flags & 0x80u) == 0);
		a = add_a(a, 0x0D, &flags);
	}
	map = rst10(b, &order, a);
	doubled = add_a(map, map, &flags);
	flags = add_hl_flags(base, doubled, flags, &hl);
	lo = board_mem_read(b, hl);
	hl = (uint16_t)(hl + 1u);
	hi = board_mem_read(b, hl);
	Z80_A(b->cpu) = doubled;
	Z80_F(b->cpu) = flags;
	Z80_BC(b->cpu) = (uint16_t)(((uint16_t)hi << 8) | lo);
	Z80_HL(b->cpu) = hl;
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

/* j_946a  point BC at this level's maze table
 * Entry:    nothing. The maze-number table is the four words at $9474.
 * Exit:     BC = the maze table address for this level. A and F match
 *           j_94bd. HL = $4000, the start of video RAM.
 *           The stack bytes below SP are the call to j_94bd ($9470) and
 *           the table base and rst return that j_94bd left under it.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, HL
 * Flags live-out: none. The caller uses BC.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: one call, returned. Callee is already C.
 */
void j_946a(Board *b)
{
	Z80_HL(b->cpu) = 0x9474;
	call_lifted(b, 0x9470, j_94bd);
	Z80_HL(b->cpu) = 0x4000;
}

/* Color address for a screen word whose high byte is still in the table. */
static uint16_t color_of(uint8_t hi, uint8_t lo)
{
	return (uint16_t)(((uint16_t)(hi | 0x04u) << 8) | lo);
}

/* j_0c0d  flash the power pellets
 * Entry:    ($4DCF) = frames since the last flash.
 * Exit:     The counter increments. Until it reaches 10, A = $0A, HL = $4DCF,
 *           and F is `cp` of that 10 with the new count.
 *           At 10 the counter is cleared. In the demo, $4732 and $4678
 *           toggle between $10 and 0, HL = $4732, and F is the `cp`.
 *           In a game, the four pellets for this maze toggle between the
 *           graphic at $447E and 0. A = $10. HL points at the high byte of
 *           the fourth pellet address. F is `cp` of $10 with that byte.
 *           BC and DE are what they were on entry. The stack bytes below
 *           SP are the saved BC and DE, then the call to j_94bd.
 *           The jump to j_9524 is part of this routine. The Pac-Man stores
 *           at $0C24 are not executed.
 *           Host finishes the RET.
 * Clobbers: A, F, HL, and BC during the lookup
 * Flags live-out: Z when the counter matches, the demo cell matches, or
 *           the fourth address high byte is $10.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: one call on the in-game path, returned. Callee is already C.
 */
void j_0c0d(Board *b)
{
	uint8_t counter = (uint8_t)(board_mem_read(b, 0x4DCF) + 1u);
	uint8_t flags = cp_flags(0x0A, counter);
	uint8_t a;
	uint16_t ptr;
	uint16_t sp;
	uint16_t saved_bc;
	uint16_t saved_de;
	uint8_t hi;
	uint8_t lo;
	int i;

	board_mem_write(b, 0x4DCF, counter);
	Z80_HL(b->cpu) = 0x4DCF;
	Z80_A(b->cpu) = 0x0A;
	Z80_F(b->cpu) = flags;
	if (counter != 0x0Au)
		return;

	board_mem_write(b, 0x4DCF, 0);
	a = board_mem_read(b, 0x4E04);
	flags = cp_flags(a, 0x03);
	if ((flags & 0x40u) == 0) {
		a = 0x10;
		flags = cp_flags(a, board_mem_read(b, 0x4732));
		if ((flags & 0x40u) != 0)
			a = 0;
		board_mem_write(b, 0x4732, a);
		board_mem_write(b, 0x4678, a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		Z80_HL(b->cpu) = 0x4732;
		return;
	}

	sp = Z80_SP(b->cpu);
	saved_bc = Z80_BC(b->cpu);
	saved_de = Z80_DE(b->cpu);
	push_word(b, &sp, saved_bc);
	push_word(b, &sp, saved_de);
	Z80_SP(b->cpu) = sp;
	Z80_HL(b->cpu) = 0x951C;
	call_lifted(b, 0x952C, j_94bd);
	Z80_SP(b->cpu) = (uint16_t)(sp + 4u);

	ptr = Z80_BC(b->cpu);
	lo = board_mem_read(b, ptr);
	ptr = (uint16_t)(ptr + 1u);
	hi = board_mem_read(b, ptr);
	a = board_mem_read(b, 0x447E);
	if (board_mem_read(b, color_of(hi, lo)) == a)
		a = 0;
	board_mem_write(b, color_of(hi, lo), a);
	for (i = 0; i < 3; i++) {
		uint16_t color;

		ptr = (uint16_t)(ptr + 1u);
		lo = board_mem_read(b, ptr);
		ptr = (uint16_t)(ptr + 1u);
		hi = board_mem_read(b, ptr);
		color = color_of(hi, lo);
		board_mem_write(b, color, a);
	}
	Z80_A(b->cpu) = 0x10;
	Z80_F(b->cpu) = cp_flags(0x10, hi);
	Z80_HL(b->cpu) = ptr;
	Z80_BC(b->cpu) = saved_bc;
	Z80_DE(b->cpu) = saved_de;
}

/* j_2487  build the pellet bitmap for this maze
 * Entry:    nothing. The pellet deltas for the maze are chosen from $9499.
 * Exit:     Thirty bytes at $4E16 record which dots are still on screen,
 *           eight dots per byte, first dot in the high bit. A dot is
 *           present when the screen byte is $10.
 *           $4E34..$4E37 save the four power-pellet screen bytes.
 *           IX = $4E34. IY is 240 bytes past the delta list.
 *           HL is 8 bytes past the power-pellet address list. DE = $4E38.
 *           BC is the fourth power pellet's screen address. A = 0.
 *           F is `and` of that 0 ($54).
 *           The jump to j_9481 pushes $2492 and returns there, so the
 *           bytes at $248D are skipped. The jump to j_9504 is part of
 *           this routine.
 *           The stack bytes below SP are the second lookup's return
 *           ($950A), the table base $951C, and two copies of the
 *           `rst $10` return $94CA. The first lookup's return is overwritten.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: Z.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: two calls, both returned. Callee is already C.
 */
void j_2487(Board *b)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t iy;
	uint16_t ix = 0x4E16;
	uint16_t hl;
	uint16_t de;
	uint16_t list;
	uint16_t bc = 0;
	uint8_t rows = 0x1E;
	uint8_t a;

	push_word(b, &sp, 0x2492);
	Z80_SP(b->cpu) = sp;
	Z80_HL(b->cpu) = 0x9499;
	call_lifted(b, 0x948B, j_94bd);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	iy = Z80_BC(b->cpu);
	hl = 0x4000;
	do {
		uint8_t bits = 0;
		uint8_t n = 8;

		do {
			uint8_t delta = board_mem_read(b, iy);
			uint8_t dot;

			hl = (uint16_t)(hl + delta);
			dot = board_mem_read(b, hl);
			bits = (uint8_t)((uint8_t)(bits << 1) | (dot == 0x10u ? 1u : 0u));
			iy = (uint16_t)(iy + 1u);
			n = (uint8_t)(n - 1u);
		} while (n != 0);
		board_mem_write(b, ix, bits);
		ix = (uint16_t)(ix + 1u);
		rows = (uint8_t)(rows - 1u);
	} while (rows != 0);

	Z80_HL(b->cpu) = 0x951C;
	call_lifted(b, 0x950A, j_94bd);
	list = Z80_BC(b->cpu);
	de = 0x4E34;
	do {
		uint8_t lo = board_mem_read(b, list);
		uint8_t hi;

		list = (uint16_t)(list + 1u);
		hi = board_mem_read(b, list);
		list = (uint16_t)(list + 1u);
		bc = (uint16_t)(((uint16_t)hi << 8) | lo);
		board_mem_write(b, de, board_mem_read(b, bc));
		de = (uint16_t)(de + 1u);
		a = (uint8_t)(de & 0x03u);
	} while (a != 0);

	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x54;
	Z80_BC(b->cpu) = bc;
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = list;
	Z80_IX(b->cpu) = ix;
	Z80_IY(b->cpu) = iy;
}
