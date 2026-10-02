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

static uint16_t pop_word(Board *b, uint16_t *sp)
{
	uint16_t lo = board_mem_read(b, *sp);
	uint16_t hi = board_mem_read(b, (uint16_t)(*sp + 1u));

	*sp = (uint16_t)(*sp + 2u);
	return (uint16_t)(lo | (uint16_t)(hi << 8));
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

/* `add a, n`. N is clear. Y and X come from the sum. */
static uint8_t add8(uint8_t a, uint8_t rhs, uint8_t *flags)
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

/* `adc a, n`. The carry-in is added. */
static uint8_t adc8(uint8_t a, uint8_t rhs, uint8_t carry, uint8_t *flags)
{
	uint16_t sum = (uint16_t)((uint16_t)a + rhs + (carry & 1u));
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

/* `dec r`. C is unchanged. */
static uint8_t dec_flags(uint8_t value, uint8_t flags, uint8_t *next)
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

/* `sbc hl, de` with carry already clear. */
static uint8_t sbc_hl(uint16_t *hl, uint16_t de)
{
	uint16_t old = *hl;
	uint32_t total = (uint32_t)old - de;
	uint16_t result = (uint16_t)total;
	uint16_t mix = (uint16_t)((old ^ de) & (old ^ result));
	uint8_t high = (uint8_t)(total >> 8);

	*hl = result;
	return (uint8_t)((high & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 (uint8_t)(((old ^ de ^ result) >> 8) & 0x10u) |
			 ((mix & 0x8000u) != 0 ? 0x04u : 0u) |
			 ((total >> 16) & 1u) |
			 0x02u);
}

/* `ld (nn), a`. WZ is (A << 8) | the low byte of nn+1. */
static void store_a_nn(Board *b, uint16_t addr, uint8_t a)
{
	board_mem_write(b, addr, a);
	Z80_MEMPTR(b->cpu) = (uint16_t)(((unsigned)a << 8) |
					(unsigned)((uint8_t)(addr + 1u)));
}

/* `rst $08`. B == 0 fills 256 bytes. Flags are unchanged.
 * The rst return is left at SP-2. */
static void rst08(Board *b, uint16_t ret)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t hl = Z80_HL(b->cpu);
	uint8_t a = Z80_A(b->cpu);
	unsigned n = Z80_B(b->cpu);
	unsigned i;

	if (n == 0)
		n = 256u;
	push_word(b, &sp, ret);
	for (i = 0; i < n; i++) {
		board_mem_write(b, hl, a);
		hl = (uint16_t)(hl + 1u);
	}
	sp = (uint16_t)(sp + 2u);
	Z80_HL(b->cpu) = hl;
	Z80_B(b->cpu) = 0;
	Z80_SP(b->cpu) = sp;
}

/* `rst $20`. A selects a word at `table`. The jump target is returned.
 * The popped rst $10 return ($0023) is the word just below SP. */
static uint16_t rst20(Board *b, uint16_t table)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t flags = 0;
	uint8_t l = (uint8_t)table;
	uint8_t h = (uint8_t)(table >> 8);
	uint8_t a = add8(Z80_A(b->cpu), Z80_A(b->cpu), &flags);
	uint8_t byte;
	uint16_t hl;
	uint16_t de;

	push_word(b, &sp, table);
	sp = (uint16_t)(sp + 2u);
	push_word(b, &sp, 0x0023);
	a = add8(a, l, &flags);
	l = a;
	a = adc8(0, h, flags, &flags);
	h = a;
	hl = (uint16_t)(((uint16_t)h << 8) | l);
	byte = board_mem_read(b, hl);
	sp = (uint16_t)(sp + 2u);
	Z80_E(b->cpu) = byte;
	hl = (uint16_t)(hl + 1u);
	Z80_D(b->cpu) = board_mem_read(b, hl);
	de = Z80_DE(b->cpu);
	Z80_A(b->cpu) = byte;
	Z80_F(b->cpu) = flags;
	Z80_DE(b->cpu) = hl;
	Z80_HL(b->cpu) = de;
	Z80_SP(b->cpu) = sp;
	return de;
}

/* Fill `rows` passes. The first pass uses B as loaded; later passes see
 * the 0 that rst $08 left, which fills 256 bytes. */
static void fill_passes(Board *b, uint16_t hl, uint8_t bcount, uint8_t rows,
			uint16_t rst_ret)
{
	uint8_t flags = Z80_F(b->cpu);
	uint8_t c = rows;

	Z80_HL(b->cpu) = hl;
	Z80_B(b->cpu) = bcount;
	Z80_C(b->cpu) = c;
	do {
		rst08(b, rst_ret);
		flags = dec_flags(c, flags, &c);
		Z80_C(b->cpu) = c;
		Z80_F(b->cpu) = flags;
	} while (c != 0);
}

/* j_24c9  fill the pellet bitmap with "present"
 * Entry:    nothing. Called as task $12 and from level setup.
 * Exit:     $4E16..$4E33 are $FF. $4E34..$4E37 are $14.
 *           A = $14. B = 0. HL = $4E38. F is unchanged.
 *           The word under SP is the second rst return $24D6.
 *           Host finishes the RET.
 * Clobbers: A, B, HL
 * Flags live-out: the caller's.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: two rsts, both returned. No callee.
 */
void j_24c9(Board *b)
{
	Z80_HL(b->cpu) = 0x4E16;
	Z80_A(b->cpu) = 0xFF;
	Z80_B(b->cpu) = 0x1E;
	rst08(b, 0x24D1);
	Z80_A(b->cpu) = 0x14;
	Z80_B(b->cpu) = 0x04;
	rst08(b, 0x24D6);
}

static void charge_fill(Board *b, zusize ran)
{
	if (ran >= b->cycles_left)
		b->cycles_left = 0;
	else
		b->cycles_left -= ran;
}

static void fill_ret(Board *b)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t lo = board_mem_read(b, sp);
	uint16_t hi = board_mem_read(b, (uint16_t)(sp + 1u));
	uint16_t ret = (uint16_t)(lo | (uint16_t)(hi << 8));

	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	Z80_PC(b->cpu) = ret;
	Z80_MEMPTR(b->cpu) = ret;
}

/* j_240d  clear color RAM
 * Entry:    task $06, at $240D. B is the task parameter and is not read.
 * Exit:     A slice of the clear. $4400 onward are 0 for the bytes this
 *           slice stored. The whole clear is `xor a`, BC = $0004,
 *           HL = $4400, then four rst $08 passes of 256. That is about
 *           26781 cycles, and a call late in the frame does not reach
 *           RET. This stops when the frame budget runs out, leaving PC
 *           on the next opcode, including inside rst $08. The slice that
 *           reaches the outer RET performs it. A finished call leaves
 *           $4400..$47FF = 0, A = 0, BC = 0, HL = $4800, and F from the
 *           last `dec c`.
 * Clobbers: A, F, BC, HL
 * Flags live-out: Z, once the clear finishes.
 * Interrupt: returns inside the frame budget. A short budget resumes
 *           next frame in Z80 from the opcode where this stopped.
 * Stack: the rst return is pushed and popped inside the slice that
 *        contains it. The outer RET is only on the finishing slice.
 */
void j_240d(Board *b)
{
	int guard = 0;

	while (b->cycles_left > 0 && guard++ < 2000000) {
		uint16_t pc = Z80_PC(b->cpu);
		zusize ran = 0;
		int done = 0;

		switch (pc) {
		case 0x240D:
			Z80_A(b->cpu) = 0;
			Z80_F(b->cpu) = 0x44;
			Z80_PC(b->cpu) = 0x240E;
			ran = 4;
			break;
		case 0x240E:
			Z80_BC(b->cpu) = 0x0004;
			Z80_PC(b->cpu) = 0x2411;
			ran = 10;
			break;
		case 0x2411:
			Z80_HL(b->cpu) = 0x4400;
			Z80_PC(b->cpu) = 0x2414;
			ran = 10;
			break;
		case 0x2414: {
			uint16_t sp = Z80_SP(b->cpu);

			push_word(b, &sp, 0x2415);
			Z80_SP(b->cpu) = sp;
			Z80_PC(b->cpu) = 0x0008;
			Z80_MEMPTR(b->cpu) = 0x0008;
			ran = 11;
			break;
		}
		case 0x0008:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			Z80_PC(b->cpu) = 0x0009;
			ran = 7;
			break;
		case 0x0009:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			Z80_PC(b->cpu) = 0x000A;
			ran = 6;
			break;
		case 0x000A: {
			uint8_t breg = (uint8_t)(Z80_B(b->cpu) - 1u);

			Z80_B(b->cpu) = breg;
			if (breg != 0) {
				Z80_PC(b->cpu) = 0x0008;
				Z80_MEMPTR(b->cpu) = 0x0008;
				ran = 13;
			} else {
				Z80_PC(b->cpu) = 0x000C;
				ran = 8;
			}
			break;
		}
		case 0x000C:
			fill_ret(b);
			ran = 10;
			break;
		case 0x2415: {
			uint8_t flags = Z80_F(b->cpu);
			uint8_t c = Z80_C(b->cpu);

			flags = dec_flags(c, flags, &c);
			Z80_C(b->cpu) = c;
			Z80_F(b->cpu) = flags;
			Z80_PC(b->cpu) = 0x2416;
			ran = 4;
			break;
		}
		case 0x2416:
			if ((Z80_F(b->cpu) & 0x40u) == 0) {
				Z80_PC(b->cpu) = 0x2414;
				Z80_MEMPTR(b->cpu) = 0x2414;
				ran = 12;
			} else {
				Z80_PC(b->cpu) = 0x2418;
				ran = 7;
			}
			break;
		case 0x2418:
			fill_ret(b);
			ran = 10;
			done = 1;
			break;
		default:
			return;
		}
		charge_fill(b, ran);
		if (done)
			return;
	}
}

/* j_23ed  clear the screen or only the maze
 * Entry:    task $00. B = 0 clears $4000..$43FF. B = 1 clears $4040
 *           for 128 bytes and then three passes of 256, through $43BF.
 * Exit:     A = $40. B = 0. C = 0. DE is the high byte of the rst $20
 *           table word. HL is one past the last byte cleared.
 *           F is the last `dec c`. The word under SP is $23FC for a
 *           full clear and $2409 for the maze.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: Z.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: the rst $20 and four rsts, all returned. No callee.
 */
void j_23ed(Board *b)
{
	uint16_t dest;

	Z80_A(b->cpu) = Z80_B(b->cpu);
	dest = rst20(b, 0x23EF);
	Z80_A(b->cpu) = 0x40;
	if (dest == 0x2400)
		fill_passes(b, 0x4040, 0x80, 4, 0x2409);
	else
		fill_passes(b, 0x4000, 0, 4, 0x23FC);
}

/* j_2698  select demo mode
 * Entry:    task $07.
 * Exit:     ($4E00) = 1. ($4E01) = 0. A = 0. F is `xor a` ($44).
 *           WZ = $0002. Other registers are unchanged.
 *           Host finishes the RET.
 * Clobbers: A, F
 * Flags live-out: Z.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: normal RET. No callee.
 */
void j_2698(Board *b)
{
	Z80_A(b->cpu) = 1;
	store_a_nn(b, 0x4E00, 1);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	store_a_nn(b, 0x4E01, 0);
}

/* j_26a2  clear the actor block
 * Entry:    task $11.
 * Exit:     $4D00..$4DFF are 0. A = 0. DE = $4E00. HL = 0.
 *           F is `sbc hl, de` of that zero, with carry clear.
 *           Host finishes the RET.
 * Clobbers: A, F, DE, HL
 * Flags live-out: Z.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: normal RET. No callee.
 */
void j_26a2(Board *b)
{
	uint16_t de = 0x4D00;
	uint16_t hl;
	uint8_t flags;

	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	do {
		hl = 0x4E00;
		board_mem_write(b, de, 0);
		de = (uint16_t)(de + 1u);
		flags = 0x54;
		flags = sbc_hl(&hl, de);
	} while ((flags & 0x40u) == 0);
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
}

/* Even parity sets P/V. */
static uint8_t parity_bit(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

/* `and`. H is set. N and C are clear. */
static uint8_t and_flags(uint8_t result)
{
	return (uint8_t)(0x10u | parity_bit(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

/* `xor n`. H, N, and C are clear. */
static uint8_t xor_flags(uint8_t result)
{
	return (uint8_t)(parity_bit(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

/* Cycles from $2419 through j_946a's RET, back at $241F.
 * Level 0..12 takes the short lookup. The `jp p` after `cp 13` sends
 * every other level through the subtract loop. */
static zusize maze_prologue_cost(uint8_t level)
{
	uint8_t folded = (uint8_t)(level - 13u);
	zusize body = 168;

	if ((folded & 0x80u) == 0) {
		unsigned n = 0;

		do {
			folded = (uint8_t)(folded - 8u);
			n++;
		} while ((folded & 0x80u) == 0);
		body = (zusize)(194u + 17u * n);
	}
	return (zusize)(74u + body);
}

/* j_2419  draw the maze
 * Entry:    task $02. B is the task parameter and is not read.
 * Exit:     A slice of the draw. The prologue points BC at this level's
 *           maze table (j_946a) in 242 cycles for levels 0..12. Each
 *           later byte is either a skip below $80 or a tile. A tile is
 *           stored, then stored again on the mirrored column with bit 0
 *           flipped. A 0 byte is the end and takes the RET.
 *           The draw is longer than a frame, so this stops when the
 *           budget runs out and leaves PC on the next opcode of the
 *           loop. The slice that reads the 0 performs the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: `xor #01` of the last tile, or `and a` of the
 *           terminating 0.
 * Interrupt: returns inside the frame budget. A short budget resumes
 *           next frame in Z80 from the opcode where this stopped.
 * Stack: one call, returned. Callee is already C. The RET is only on
 *        the finishing slice.
 */
void j_2419(Board *b)
{
	int guard = 0;

	if (Z80_PC(b->cpu) == 0x2419) {
		zusize cost = maze_prologue_cost(board_mem_read(b, 0x4E13));

		if (b->cycles_left > cost - 10u) {
			Z80_HL(b->cpu) = 0x4000;
			call_lifted(b, 0x241F, j_946a);
			Z80_PC(b->cpu) = 0x241F;
			Z80_MEMPTR(b->cpu) = 0x241F;
			charge_fill(b, cost);
		}
	}

	while (b->cycles_left > 0 && guard++ < 2000000) {
		uint16_t pc = Z80_PC(b->cpu);
		zusize ran = 0;
		int done = 0;

		switch (pc) {
		case 0x241F: {
			uint16_t bc = Z80_BC(b->cpu);

			Z80_A(b->cpu) = board_mem_read(b, bc);
			Z80_MEMPTR(b->cpu) = (uint16_t)(bc + 1u);
			Z80_PC(b->cpu) = 0x2420;
			ran = 7;
			break;
		}
		case 0x2420:
			Z80_F(b->cpu) = and_flags(Z80_A(b->cpu));
			Z80_PC(b->cpu) = 0x2421;
			ran = 4;
			break;
		case 0x2421:
			if ((Z80_F(b->cpu) & 0x40u) != 0) {
				fill_ret(b);
				ran = 11;
				done = 1;
			} else {
				Z80_PC(b->cpu) = 0x2422;
				ran = 5;
			}
			break;
		case 0x2422:
			Z80_MEMPTR(b->cpu) = 0x242C;
			Z80_PC(b->cpu) = (Z80_F(b->cpu) & 0x80u) != 0 ? 0x242C : 0x2425;
			ran = 10;
			break;
		case 0x2425:
			Z80_E(b->cpu) = Z80_A(b->cpu);
			Z80_PC(b->cpu) = 0x2426;
			ran = 4;
			break;
		case 0x2426:
			Z80_D(b->cpu) = 0;
			Z80_PC(b->cpu) = 0x2428;
			ran = 7;
			break;
		case 0x2428: {
			uint16_t hl = Z80_HL(b->cpu);
			uint8_t flags = add_hl_flags(hl, Z80_DE(b->cpu), Z80_F(b->cpu), &hl);

			Z80_MEMPTR(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			Z80_HL(b->cpu) = hl;
			Z80_F(b->cpu) = flags;
			Z80_PC(b->cpu) = 0x2429;
			ran = 11;
			break;
		}
		case 0x2429:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) - 1u);
			Z80_PC(b->cpu) = 0x242A;
			ran = 6;
			break;
		case 0x242A:
			Z80_BC(b->cpu) = (uint16_t)(Z80_BC(b->cpu) + 1u);
			Z80_PC(b->cpu) = 0x242B;
			ran = 6;
			break;
		case 0x242B: {
			uint16_t bc = Z80_BC(b->cpu);

			Z80_A(b->cpu) = board_mem_read(b, bc);
			Z80_MEMPTR(b->cpu) = (uint16_t)(bc + 1u);
			Z80_PC(b->cpu) = 0x242C;
			ran = 7;
			break;
		}
		case 0x242C:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			Z80_PC(b->cpu) = 0x242D;
			ran = 6;
			break;
		case 0x242D:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			Z80_PC(b->cpu) = 0x242E;
			ran = 7;
			break;
		case 0x242E: {
			uint16_t sp = Z80_SP(b->cpu);

			push_word(b, &sp, Z80_AF(b->cpu));
			Z80_SP(b->cpu) = sp;
			Z80_PC(b->cpu) = 0x242F;
			ran = 11;
			break;
		}
		case 0x242F: {
			uint16_t sp = Z80_SP(b->cpu);

			push_word(b, &sp, Z80_HL(b->cpu));
			Z80_SP(b->cpu) = sp;
			Z80_PC(b->cpu) = 0x2430;
			ran = 11;
			break;
		}
		case 0x2430:
			Z80_DE(b->cpu) = 0x83E0;
			Z80_PC(b->cpu) = 0x2433;
			ran = 10;
			break;
		case 0x2433:
			Z80_A(b->cpu) = (uint8_t)Z80_HL(b->cpu);
			Z80_PC(b->cpu) = 0x2434;
			ran = 4;
			break;
		case 0x2434: {
			uint8_t a = (uint8_t)(Z80_A(b->cpu) & 0x1Fu);

			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			Z80_PC(b->cpu) = 0x2436;
			ran = 7;
			break;
		}
		case 0x2436: {
			uint8_t flags = 0;
			uint8_t a = Z80_A(b->cpu);

			a = add8(a, a, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			Z80_PC(b->cpu) = 0x2437;
			ran = 4;
			break;
		}
		case 0x2437:
			Z80_H(b->cpu) = 0;
			Z80_PC(b->cpu) = 0x2439;
			ran = 7;
			break;
		case 0x2439:
			Z80_L(b->cpu) = Z80_A(b->cpu);
			Z80_PC(b->cpu) = 0x243A;
			ran = 4;
			break;
		case 0x243A: {
			uint16_t hl = Z80_HL(b->cpu);
			uint8_t flags = add_hl_flags(hl, Z80_DE(b->cpu), Z80_F(b->cpu), &hl);

			Z80_MEMPTR(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			Z80_HL(b->cpu) = hl;
			Z80_F(b->cpu) = flags;
			Z80_PC(b->cpu) = 0x243B;
			ran = 11;
			break;
		}
		case 0x243B: {
			uint16_t sp = Z80_SP(b->cpu);

			Z80_DE(b->cpu) = pop_word(b, &sp);
			Z80_SP(b->cpu) = sp;
			Z80_PC(b->cpu) = 0x243C;
			ran = 10;
			break;
		}
		case 0x243C:
			Z80_F(b->cpu) = and_flags(Z80_A(b->cpu));
			Z80_PC(b->cpu) = 0x243D;
			ran = 4;
			break;
		case 0x243D: {
			uint16_t hl = Z80_HL(b->cpu);
			uint16_t de = Z80_DE(b->cpu);

			Z80_MEMPTR(b->cpu) = (uint16_t)(hl + 1u);
			Z80_F(b->cpu) = sbc_hl(&hl, de);
			Z80_HL(b->cpu) = hl;
			Z80_PC(b->cpu) = 0x243F;
			ran = 15;
			break;
		}
		case 0x243F: {
			uint16_t sp = Z80_SP(b->cpu);

			Z80_AF(b->cpu) = pop_word(b, &sp);
			Z80_SP(b->cpu) = sp;
			Z80_PC(b->cpu) = 0x2440;
			ran = 10;
			break;
		}
		case 0x2440: {
			uint8_t a = (uint8_t)(Z80_A(b->cpu) ^ 0x01u);

			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = xor_flags(a);
			Z80_PC(b->cpu) = 0x2442;
			ran = 7;
			break;
		}
		case 0x2442:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			Z80_PC(b->cpu) = 0x2443;
			ran = 7;
			break;
		case 0x2443: {
			uint16_t de = Z80_DE(b->cpu);

			Z80_DE(b->cpu) = Z80_HL(b->cpu);
			Z80_HL(b->cpu) = de;
			Z80_PC(b->cpu) = 0x2444;
			ran = 4;
			break;
		}
		case 0x2444:
			Z80_BC(b->cpu) = (uint16_t)(Z80_BC(b->cpu) + 1u);
			Z80_PC(b->cpu) = 0x2445;
			ran = 6;
			break;
		case 0x2445:
			Z80_PC(b->cpu) = 0x241F;
			Z80_MEMPTR(b->cpu) = 0x241F;
			ran = 10;
			break;
		default:
			return;
		}
		charge_fill(b, ran);
		if (done)
			return;
	}
}
