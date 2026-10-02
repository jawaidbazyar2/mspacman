#include "lift.h"

/* Flags from `cp n`. A is not modified. Y and X come from the operand. */
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

/* j_3641  point HL at an act-table base
 * Entry:    B selects the table.
 * Exit:     A = B. HL = $4DC6 when B is 6, otherwise $4CFE.
 *           F is the `cp 6` result. Y and X are clear because the
 *           operand is 6.
 *           Host finishes the RET.
 * Clobbers: A, F, HL
 * Flags live-out: none. Each caller reaches `add a,a` inside rst $18
 *           before it tests flags.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_3641(Board *b)
{
	uint8_t a = Z80_B(b->cpu);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = cp_flags(a, 0x06);
	Z80_HL(b->cpu) = a == 0x06 ? 0x4DC6 : 0x4CFE;
}

/* Even parity sets P/V, matching `and`. */
static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

static uint8_t and_flags(uint8_t result)
{
	return (uint8_t)(0x10u | parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

/* Four `sra`. Bit 7 stays. Intermediate flags are overwritten later. */
static uint8_t sra4(uint8_t value)
{
	uint8_t i;

	for (i = 0; i < 4u; i++)
		value = (uint8_t)((value & 0x80u) | (uint8_t)(value >> 1));
	return value;
}

/* j_3556  split an act offset into a signed high nibble and a low nibble
 * Entry:    A = the offset byte.
 * Exit:     C = A arithmetic-shifted right by 4.
 *           If A is negative: A = A | $F0, C = C + 1, F is that `inc c`
 *           with carry clear.
 *           If A is positive: A = A & $0F, F is that `and`.
 *           Host finishes the RET.
 * Clobbers: A, C, F
 * Flags live-out: none. The caller stores A, then calls j_3641.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_3556(Board *b)
{
	uint8_t a = Z80_A(b->cpu);
	uint8_t c = sra4(a);

	if ((a & 0x80u) == 0) {
		a = (uint8_t)(a & 0x0Fu);
		Z80_F(b->cpu) = and_flags(a);
	} else {
		uint8_t next = (uint8_t)(c + 1u);

		a = (uint8_t)(a | 0xF0u);
		Z80_F(b->cpu) = (uint8_t)((next & 0xA8u) |
					  (next == 0 ? 0x40u : 0u) |
					  ((c ^ next) & 0x10u) |
					  (c == 0x7Fu ? 0x04u : 0u));
		c = next;
	}
	Z80_A(b->cpu) = a;
	Z80_C(b->cpu) = c;
}

extern void j_1291(Board *b);
extern void j_1066(Board *b);
extern void j_1094(Board *b);
extern void j_109e(Board *b);
extern void j_10a8(Board *b);
extern void j_10b4(Board *b);
extern void j_1235(Board *b);
extern void j_171d(Board *b);
extern void j_1789(Board *b);
extern void j_1806(Board *b);
extern void j_1b36(Board *b);
extern void j_1c4b(Board *b);
extern void j_1d22(Board *b);
extern void j_1df9(Board *b);
extern void j_1376(Board *b);
extern void j_2069(Board *b);
extern void j_208c(Board *b);
extern void j_20af(Board *b);
extern void j_13dd(Board *b);
extern void j_0c42(Board *b);
extern void j_0e23(Board *b);
extern void j_0e36(Board *b);
extern void j_0ac3(Board *b);
extern void j_0bd6(Board *b);
extern void j_0c0d(Board *b);
extern void j_0e6c(Board *b);
extern void j_0ead(Board *b);

static void push_word(Board *b, uint16_t *sp, uint16_t value)
{
	*sp = (uint16_t)(*sp - 2u);
	board_mem_write(b, (uint16_t)(*sp + 1u), (uint8_t)(value >> 8));
	board_mem_write(b, *sp, (uint8_t)value);
}

static void call_lifted(Board *b, uint16_t ret, void (*fn)(Board *))
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, ret);
	Z80_SP(b->cpu) = sp;
	fn(b);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
}

/* j_1017  one pass of the playfield while a life is in progress
 * Entry:    Death, ghost, and level bytes described below.
 * Exit:     If Ms. Pac-Man is dying: A = ($4DA5), F is `and a`.
 *           If a ghost is waiting to be shown as eaten: that animation
 *           runs and this returns with its result.
 *           If a collision is pending: A = ($4DA4), F is `and a`.
 *           If the level state is not 3: A = ($4E04), F is `cp 3`.
 *           Otherwise the fright timer and the three house releases
 *           have run. A and F are whatever the orange release left.
 *           Host finishes the RET.
 * Clobbers: A, F, and every register the calls use
 * Flags live-out: none. The caller draws the sprites next.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the calls are sequential. The deepest one still on the stack
 *         is the last call that pushed farther than the others.
 */
void j_1017(Board *b)
{
	uint8_t a;
	uint8_t flags;

	call_lifted(b, 0x101A, j_1291);
	a = board_mem_read(b, 0x4DA5);
	flags = and_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	call_lifted(b, 0x1022, j_1066);
	call_lifted(b, 0x1025, j_1094);
	call_lifted(b, 0x1028, j_109e);
	call_lifted(b, 0x102B, j_10a8);
	call_lifted(b, 0x102E, j_10b4);
	a = board_mem_read(b, 0x4DA4);
	flags = and_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0) {
		call_lifted(b, 0x1038, j_1235);
		return;
	}
	call_lifted(b, 0x103C, j_171d);
	call_lifted(b, 0x103F, j_1789);
	a = board_mem_read(b, 0x4DA4);
	flags = and_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	call_lifted(b, 0x1047, j_1806);
	call_lifted(b, 0x104A, j_1b36);
	call_lifted(b, 0x104D, j_1c4b);
	call_lifted(b, 0x1050, j_1d22);
	call_lifted(b, 0x1053, j_1df9);
	a = board_mem_read(b, 0x4E04);
	flags = cp_flags(a, 0x03);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;
	call_lifted(b, 0x105C, j_1376);
	call_lifted(b, 0x105F, j_2069);
	call_lifted(b, 0x1062, j_208c);
	call_lifted(b, 0x1065, j_20af);
}

/* j_08eb  one frame of play after the level is known to be unfinished
 * Entry:    the level-state dispatcher has compared the dot count.
 * Exit:     the two playfield passes, the ghost releases, and the fruit
 *           step have returned. Registers are whatever the fruit routine
 *           left. The word under SP is $090C.
 *           Host finishes the RET.
 * Clobbers: A, F, and every register the calls use
 * Flags live-out: none. The dispatcher returns to the task loop.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: eleven calls, each returned. The fruit routine reads the
 *        generator once per draw.
 */
void j_08eb(Board *b)
{
	call_lifted(b, 0x08EE, j_1017);
	call_lifted(b, 0x08F1, j_1017);
	call_lifted(b, 0x08F4, j_13dd);
	call_lifted(b, 0x08F7, j_0c42);
	call_lifted(b, 0x08FA, j_0e23);
	call_lifted(b, 0x08FD, j_0e36);
	call_lifted(b, 0x0900, j_0ac3);
	call_lifted(b, 0x0903, j_0bd6);
	call_lifted(b, 0x0906, j_0c0d);
	call_lifted(b, 0x0909, j_0e6c);
	call_lifted(b, 0x090C, j_0ead);
}

/* `inc (hl)`. C is unchanged. */
static uint8_t inc_mem_flags(uint8_t value, uint8_t flags, uint8_t *next)
{
	uint8_t result = (uint8_t)(value + 1u);

	*next = result;
	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x7Fu ? 0x04u : 0u) |
			 (flags & 0x01u));
}

/* j_058e  advance the attract subroutine
 * Entry:    timed task 2, or a call from the marquee.
 * Exit:     ($4E02) increases by one. HL = $4E02.
 *           F is that `inc (hl)`. A, BC, and DE are unchanged.
 *           Host finishes the RET.
 * Clobbers: F, HL
 * Flags live-out: Z when the subroutine number wraps to 0.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: normal RET. No callee.
 */
void j_058e(Board *b)
{
	uint8_t cur = board_mem_read(b, 0x4E02);
	uint8_t next;
	uint8_t flags = inc_mem_flags(cur, Z80_F(b->cpu), &next);

	board_mem_write(b, 0x4E02, next);
	Z80_HL(b->cpu) = 0x4E02;
	Z80_F(b->cpu) = flags;
}

/* `add ix, de`. S, Z, and P/V stay. N is clear. */
static uint8_t add_ix_flags(uint16_t ix, uint16_t rhs, uint8_t flags, uint16_t *sum)
{
	uint32_t total = (uint32_t)ix + rhs;
	uint16_t result = (uint16_t)total;
	uint8_t high = (uint8_t)(total >> 8);

	*sum = result;
	return (uint8_t)((flags & 0xC4u) |
			 (high & 0x28u) |
			 (uint8_t)(((ix ^ rhs ^ result) >> 8) & 0x10u) |
			 (total > 0xFFFFu ? 1u : 0u));
}

/* j_0506  paint the invisible side columns
 * Entry:    nothing. Called from the cutscenes, and fallen into after
 *           the attract energizer is drawn.
 * Exit:     $FC is stored at columns $11 and $13 of 28 rows starting
 *           at $4040. A = $FC. B = 0. DE = $0020. IX = $43C0.
 *           F is the last `add ix, de`. C and HL are unchanged.
 *           Host finishes the RET.
 * Clobbers: A, F, B, DE, IX
 * Flags live-out: none. Callers return.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: normal RET. No callee.
 */
void j_0506(Board *b)
{
	uint16_t ix = 0x4040;
	uint8_t flags = Z80_F(b->cpu);
	int row;

	for (row = 0; row < 28; row++) {
		board_mem_write(b, (uint16_t)(ix + 0x11u), 0xFC);
		board_mem_write(b, (uint16_t)(ix + 0x13u), 0xFC);
		flags = add_ix_flags(ix, 0x0020, flags, &ix);
	}
	Z80_A(b->cpu) = 0xFC;
	Z80_B(b->cpu) = 0;
	Z80_DE(b->cpu) = 0x0020;
	Z80_IX(b->cpu) = ix;
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

/* `and a`. H is set. N and C are clear. */
static uint8_t and_a_flags(uint8_t a)
{
	return (uint8_t)(0x10u | parity_bit(a) | (a & 0xA8u) |
			 (a == 0 ? 0x40u : 0u));
}

/* `dec r`. C is unchanged. */
static uint8_t dec_r(uint8_t value, uint8_t flags, uint8_t *next)
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

/* j_05bf  draw one stationary ghost
 * Entry:    HL = the first screen cell. A = the ghost color.
 * Exit:     Six tiles $B1 $B3 $B5 / $B0 $B2 $B4 are drawn, and the
 *           same six cells are colored with A one page higher.
 *           A is unchanged. BC = $001E. DE = $0400.
 *           HL is the color address of the first tile.
 *           F is the last `dec l`, whose carry is clear.
 *           Host finishes the RET.
 * Clobbers: F, BC, DE, HL
 * Flags live-out: none. Callers return or load C.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: normal RET. No callee.
 */
void j_05bf(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint8_t a = Z80_A(b->cpu);
	uint8_t l;
	uint8_t flags;
	uint8_t tiles[6] = {0xB1, 0xB3, 0xB5, 0xB0, 0xB2, 0xB4};
	int i;

	for (i = 0; i < 3; i++) {
		board_mem_write(b, hl, tiles[i]);
		if (i != 2) {
			l = (uint8_t)(hl + 1u);
			hl = (uint16_t)((hl & 0xFF00u) | l);
		}
	}
	hl = (uint16_t)(hl + 0x001Eu);
	for (i = 3; i < 6; i++) {
		board_mem_write(b, hl, tiles[i]);
		if (i != 5) {
			l = (uint8_t)(hl + 1u);
			hl = (uint16_t)((hl & 0xFF00u) | l);
		}
	}
	hl = (uint16_t)(hl + 0x0400u);
	for (i = 0; i < 3; i++) {
		board_mem_write(b, hl, a);
		if (i != 2) {
			l = (uint8_t)(hl - 1u);
			hl = (uint16_t)((hl & 0xFF00u) | l);
		}
	}
	flags = and_a_flags(a);
	if (hl < 0x001Eu)
		flags = (uint8_t)(flags | 0x01u);
	else
		flags = (uint8_t)(flags & 0xFEu);
	hl = (uint16_t)(hl - 0x001Eu);
	for (i = 0; i < 3; i++) {
		board_mem_write(b, hl, a);
		if (i != 2) {
			l = (uint8_t)hl;
			flags = dec_r(l, flags, &l);
			hl = (uint16_t)((hl & 0xFF00u) | l);
		}
	}
	Z80_BC(b->cpu) = 0x001E;
	Z80_DE(b->cpu) = 0x0400;
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
}

/* Word at IX+disp. The marquee table lives in ROM. */
static uint16_t ix_word(Board *b, uint16_t ix, uint16_t disp)
{
	uint16_t addr = (uint16_t)(ix + disp);

	return (uint16_t)(board_mem_read(b, addr) |
			  (uint16_t)(board_mem_read(b, (uint16_t)(addr + 1u)) << 8));
}

/* `dec (hl)`. N is set. C stays. */
static uint8_t dec_hl(Board *b, uint16_t hl, uint8_t flags)
{
	uint8_t value = board_mem_read(b, hl);
	uint8_t next;

	flags = dec_r(value, flags, &next);
	board_mem_write(b, hl, next);
	return flags;
}

/* j_3ed0  step the flashing bulbs around the marquee
 * Entry:    Counter at $4F01.
 * Exit:     The counter becomes (counter + 1) & $0F and is stored.
 *           An odd count paints six bulbs from the table at $3F81.
 *           An even count turns six bulbs down and lights the next.
 *           The last store on the even path is $83.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, HL, IX
 * Flags live-out: the `add ix,bc` on an odd count, or the last
 *           `dec (hl)` on an even count.
 * Interrupt: returns inside the frame budget.
 * Stack: normal RET. No callee.
 */
void j_3ed0(Board *b)
{
	static const uint8_t odd_ink[6] = {0x87, 0x87, 0x8A, 0x81, 0x81, 0x84};
	static const uint8_t even_ink[6] = {0x88, 0x88, 0x8B, 0x82, 0x82, 0x83};
	uint8_t a = (uint8_t)((board_mem_read(b, 0x4F01) + 1u) & 0x0Fu);
	uint8_t c = (uint8_t)(a & 0xFEu);
	uint8_t breg = 0;
	uint16_t ix;
	uint16_t hl;
	uint8_t flags;
	unsigned i;

	board_mem_write(b, 0x4F01, a);
	if ((a & 0x01u) != 0) {
		flags = add_ix_flags(0x3F81, c, 0, &ix);
		for (i = 0; i < 6; i++) {
			hl = ix_word(b, ix, (uint16_t)(i * 0x10u));
			board_mem_write(b, hl, odd_ink[i]);
		}
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		Z80_B(b->cpu) = 0;
		Z80_C(b->cpu) = c;
		Z80_HL(b->cpu) = hl;
		Z80_IX(b->cpu) = ix;
		return;
	}
	c = (uint8_t)(c - 1u);
	flags = cp_flags(0, c);
	if ((flags & 0x80u) == 0)
		breg = 0xFF;
	flags = dec_r(c, flags, &c);
	flags = add_ix_flags(0x3F81, (uint16_t)(((uint16_t)breg << 8) | c),
			     flags, &ix);
	hl = 0;
	for (i = 0; i < 6; i++) {
		uint16_t base = (uint16_t)(i * 0x10u);

		hl = ix_word(b, ix, base);
		flags = dec_hl(b, hl, flags);
		hl = ix_word(b, ix, (uint16_t)(base + 2u));
		board_mem_write(b, hl, even_ink[i]);
	}
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = breg;
	Z80_C(b->cpu) = c;
	Z80_HL(b->cpu) = hl;
	Z80_IX(b->cpu) = ix;
}

extern void j_0042(Board *b);

/* `rst $28` into the task list. The continuation stays below SP. */
static void queue_task(Board *b, uint8_t task, uint8_t param, uint16_t ret)
{
	Z80_B(b->cpu) = task;
	Z80_C(b->cpu) = param;
	call_lifted(b, ret, j_0042);
}

/* `rst $30`. Copies 3 bytes into the first free timed-task slot. */
static int queue_timed(Board *b, uint16_t data)
{
	uint16_t de = 0x4C90;
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t left = 0x10;
	uint8_t a;
	uint8_t e;
	uint8_t i;

	for (;;) {
		a = board_mem_read(b, de);
		if (a == 0)
			break;
		for (i = 0; i < 3; i++)
			de = (uint16_t)((de & 0xFF00u) | (uint8_t)(de + 1u));
		left--;
		if (left == 0)
			return 0;
	}
	push_word(b, &sp, data);
	sp = (uint16_t)(sp + 2u);
	e = (uint8_t)de;
	for (i = 0; i < 3; i++) {
		a = board_mem_read(b, data);
		board_mem_write(b, de, a);
		data = (uint16_t)(data + 1u);
		e = (uint8_t)(e + 1u);
		de = (uint16_t)((de & 0xFF00u) | e);
	}
	Z80_A(b->cpu) = a;
	Z80_B(b->cpu) = 0;
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = data;
	Z80_SP(b->cpu) = sp;
	return 1;
}

/* One logo cell: tile, color one page up, then back. `advance` steps
 * to the next tile. Carry from the add feeds the subtract. */
static void logo_cell(Board *b, uint16_t *hl, uint8_t tile, int advance)
{
	uint32_t sum = (uint32_t)*hl + 0x0400u;
	int carry = sum > 0xFFFFu ? 1 : 0;
	int32_t back;

	board_mem_write(b, *hl, tile);
	*hl = (uint16_t)sum;
	board_mem_write(b, *hl, 1);
	back = (int32_t)(uint16_t)sum - 0x0400 - carry;
	*hl = (uint16_t)back;
	if (advance)
		*hl = (uint16_t)(*hl + 1u);
}

/* j_9642  queue the copyright lines and draw the Midway logo
 * Entry:    called from the marquee and from the press-start text task.
 * Exit:     Tasks $1C/$13 and $1C/$35 are queued. Four strips of the
 *           logo are drawn from $429A. A is $BB. F is `cp $BB`.
 *           BC = $0400. DE = $001D. HL is the last strip's end.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: the finishing compare.
 * Interrupt: returns inside the frame budget.
 * Stack: two `rst $28`s. The second continuation ($9648) remains.
 */
void j_9642(Board *b)
{
	uint16_t hl = 0x429A;
	uint8_t a = 0xBF;
	uint8_t i;

	queue_task(b, 0x1C, 0x13, 0x9645);
	queue_task(b, 0x1C, 0x35, 0x9648);
	do {
		for (i = 0; i < 4; i++) {
			logo_cell(b, &hl, a, i != 3);
			if (i != 3)
				a = (uint8_t)(a - 4u);
		}
		hl = (uint16_t)(hl + 0x001Du);
		a = (uint8_t)(a + 0x0Bu);
	} while (a != 0xBB);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = cp_flags(a, 0xBB);
	Z80_BC(b->cpu) = 0x0400;
	Z80_DE(b->cpu) = 0x001D;
	Z80_HL(b->cpu) = hl;
}

/* j_0585  queue the marquee text task and advance the subroutine
 * Entry:    C = text parameter. B is ignored and replaced.
 * Exit:     Task $1C with that parameter is queued, then a timed task
 *           $4A,$02,$00. ($4E02) increases by one. A = 0. B = 0.
 *           C is unchanged. HL = $4E02. F is the increment.
 *           Host finishes the RET.
 * Clobbers: A, F, B, DE, HL
 * Flags live-out: the subroutine increment.
 * Interrupt: returns inside the frame budget.
 * Stack: the call of j_0042, then `rst $30`. The timed-task data
 *        address ($058B) remains. j_058e adds nothing.
 */
void j_0585(Board *b)
{
	Z80_B(b->cpu) = 0x1C;
	call_lifted(b, 0x058A, j_0042);
	if (queue_timed(b, 0x058B) == 0)
		return;
	j_058e(b);
}

/* j_045f  open the Ms. Pac-Man marquee
 * Entry:    attract subroutine 0.
 * Exit:     Screen-clear, color, reset, and sprite-clear tasks are
 *           queued. j_0585 draws "MS PAC-MAN" and advances the
 *           subroutine. C = $0C. Other registers match j_0585.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: j_0585.
 * Interrupt: returns inside the frame budget.
 * Stack: four `rst $28`s, then the call of j_0585.
 */
void j_045f(Board *b)
{
	queue_task(b, 0x00, 0x01, 0x0462);
	queue_task(b, 0x01, 0x00, 0x0465);
	queue_task(b, 0x04, 0x00, 0x0468);
	queue_task(b, 0x1E, 0x00, 0x046B);
	Z80_C(b->cpu) = 0x0C;
	call_lifted(b, 0x0470, j_0585);
}

/* Queue one marquee string and advance the attract subroutine. */
static void marquee_line(Board *b, uint8_t param, uint16_t ret)
{
	queue_task(b, 0x1C, param, ret);
	j_058e(b);
}

/* j_3e8b  "MS PAC-MAN" and a bulb delay of $60 */
void j_3e8b(Board *b)
{
	queue_task(b, 0x1C, 0x0C, 0x3E8E);
	Z80_A(b->cpu) = 0x60;
	board_mem_write(b, 0x4F01, 0x60);
	j_058e(b);
}

/* j_3e96  Midway logo, then the next marquee step */
void j_3e96(Board *b)
{
	call_lifted(b, 0x3E99, j_9642);
	j_058e(b);
}

void j_3e9c(Board *b)
{
	marquee_line(b, 0x0D, 0x3E9F);
}

/* j_3ea2  erase "WITH" and show "PINKY" */
void j_3ea2(Board *b)
{
	queue_task(b, 0x1C, 0x30, 0x3EA5);
	queue_task(b, 0x1C, 0x0F, 0x3EA8);
	j_058e(b);
}

void j_3eab(Board *b)
{
	marquee_line(b, 0x2F, 0x3EAE);
}

void j_3eb1(Board *b)
{
	marquee_line(b, 0x31, 0x3EB4);
}

void j_3eb7(Board *b)
{
	marquee_line(b, 0x33, 0x3EBA);
}

void j_3ebd(Board *b)
{
	marquee_line(b, 0x0E, 0x3EC0);
}

void j_3ec3(Board *b)
{
	marquee_line(b, 0x10, 0x3EC6);
}
