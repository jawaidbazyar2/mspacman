#include "lift.h"

/* Even parity sets P/V, matching `and a`. */
static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

static uint8_t and_a_flags(uint8_t a)
{
	return (uint8_t)(0x10u | parity_pv(a) | (a & 0xA8u) |
			 (a == 0 ? 0x40u : 0u));
}

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

static uint8_t xor_flags(uint8_t result)
{
	return (uint8_t)(parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

static uint8_t srl(uint8_t value, uint8_t *flags)
{
	uint8_t result = (uint8_t)(value >> 1);

	*flags = (uint8_t)((result & 0xA8u) |
			   (result == 0 ? 0x40u : 0u) |
			   parity_pv(result) |
			   (value & 1u));
	return result;
}

static uint8_t rlca(uint8_t a, uint8_t *flags)
{
	a = (uint8_t)((uint8_t)(a << 1) | (uint8_t)(a >> 7));
	*flags = (uint8_t)((*flags & 0xC4u) | (a & 0x28u) | (a & 1u));
	return a;
}

static uint8_t rrca(uint8_t a, uint8_t *flags)
{
	a = (uint8_t)((a >> 1) | (uint8_t)((a & 1u) << 7));
	*flags = (uint8_t)((*flags & 0xC4u) | (a & 0x28u) | (a >> 7));
	return a;
}

static uint8_t add_hl_flags(uint16_t hl, uint16_t rhs, uint8_t flags,
			    uint16_t *sum)
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

static uint16_t word_at(Board *b, uint16_t addr)
{
	return (uint16_t)(board_mem_read(b, addr) |
			  (uint16_t)((uint16_t)board_mem_read(b, (uint16_t)(addr + 1u)) << 8));
}

static void push_word(Board *b, uint16_t *sp, uint16_t value)
{
	*sp = (uint16_t)(*sp - 2u);
	board_mem_write(b, (uint16_t)(*sp + 1u), (uint8_t)(value >> 8));
	board_mem_write(b, *sp, (uint8_t)value);
}

static uint16_t pop_word(Board *b)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t value = word_at(b, sp);

	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	return value;
}

static void push(Board *b, uint16_t value)
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, value);
	Z80_SP(b->cpu) = sp;
}

static void call_lifted(Board *b, uint16_t ret, void (*fn)(Board *))
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, ret);
	Z80_SP(b->cpu) = sp;
	fn(b);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
}

static void rst10(Board *b, uint16_t ret)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint8_t index = Z80_A(b->cpu);
	uint8_t flags = 0;
	uint8_t low;
	uint8_t high;
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, ret);
	Z80_SP(b->cpu) = sp;
	low = add_a(index, (uint8_t)hl, &flags);
	high = adc8(0, (uint8_t)(hl >> 8), flags, &flags);
	hl = (uint16_t)(((uint16_t)high << 8) | low);
	Z80_A(b->cpu) = board_mem_read(b, hl);
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = hl;
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
}

static uint16_t rst20(Board *b, uint16_t table)
{
	uint8_t a = Z80_A(b->cpu);
	uint8_t flags = 0;
	uint8_t e;
	uint8_t d;
	uint16_t hl;

	a = add_a(a, a, &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = table;
	rst10(b, 0x0023);
	e = Z80_A(b->cpu);
	hl = (uint16_t)(Z80_HL(b->cpu) + 1u);
	d = board_mem_read(b, hl);
	Z80_DE(b->cpu) = hl;
	hl = (uint16_t)(((uint16_t)d << 8) | e);
	Z80_HL(b->cpu) = hl;
	return hl;
}

/* `rst $18`. HL = word at (HL + 2*B). Plant $001B under the rst return. */
static void rst18(Board *b, uint16_t ret)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t flags = 0;
	uint8_t a = Z80_B(b->cpu);
	uint16_t hl;
	uint8_t e;
	uint8_t d;

	push_word(b, &sp, ret);
	Z80_SP(b->cpu) = sp;
	a = add_a(a, a, &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	rst10(b, 0x001B);
	e = Z80_A(b->cpu);
	hl = (uint16_t)(Z80_HL(b->cpu) + 1u);
	d = board_mem_read(b, hl);
	Z80_DE(b->cpu) = hl;
	Z80_HL(b->cpu) = (uint16_t)(((uint16_t)d << 8) | e);
	sp = Z80_SP(b->cpu);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
}

static uint16_t ix_at(Board *b, uint8_t off)
{
	return (uint16_t)(Z80_IX(b->cpu) + off);
}

static uint16_t iy_at(Board *b, uint8_t off)
{
	return (uint16_t)(Z80_IY(b->cpu) + off);
}

static uint8_t ixr(Board *b, uint8_t off)
{
	return board_mem_read(b, ix_at(b, off));
}

static void ixw(Board *b, uint8_t off, uint8_t value)
{
	board_mem_write(b, ix_at(b, off), value);
}

static void iyw(Board *b, uint8_t off, uint8_t value)
{
	board_mem_write(b, iy_at(b, off), value);
}

static uint16_t ix_ptr(Board *b)
{
	return (uint16_t)(ixr(b, 6) | (uint16_t)((uint16_t)ixr(b, 7) << 8));
}

static void ix_set_ptr(Board *b, uint16_t hl)
{
	ixw(b, 6, (uint8_t)hl);
	ixw(b, 7, (uint8_t)(hl >> 8));
	Z80_HL(b->cpu) = hl;
}

static uint8_t dec_ix(Board *b, uint8_t off)
{
	uint8_t cur = ixr(b, off);
	uint8_t next;
	uint8_t flags = dec_r(cur, Z80_F(b->cpu), &next);

	ixw(b, off, next);
	Z80_F(b->cpu) = flags;
	return next;
}

/* j_2df4  silence the voice when its current bit is set */
void j_2df4(Board *b)
{
	uint8_t cur = ixr(b, 2);
	uint8_t flags = and_a_flags(cur);

	Z80_A(b->cpu) = cur;
	Z80_F(b->cpu) = flags;
	if (cur == 0)
		return;
	ixw(b, 2, 0);
	ixw(b, 0x0D, 0);
	ixw(b, 0x0E, 0);
	ixw(b, 0x0F, 0);
	iyw(b, 0, 0);
	iyw(b, 1, 0);
	iyw(b, 2, 0);
	iyw(b, 3, 0);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
}

/* Volume adjust at $2F01. A on exit is the volume the caller stores. */
static void adjust_volume(Board *b)
{
	uint16_t target;
	uint8_t a;
	uint8_t flags;
	uint8_t counter;

	Z80_A(b->cpu) = ixr(b, 0x0B);
	target = rst20(b, 0x2F02);
	if (target == 0x2F22) {
		Z80_A(b->cpu) = ixr(b, 0x0F);
		return;
	}
	if (target == 0x2F26) {
		a = ixr(b, 0x0F);
		a = (uint8_t)(a & 0x0Fu);
		flags = and_a_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if (a == 0)
			return;
		flags = dec_r(a, flags, &a);
		ixw(b, 0x0F, a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		return;
	}
	if (target == 0x2F2B || target == 0x2F3C || target == 0x2F43) {
		uint8_t mask = 1;

		if (target == 0x2F3C)
			mask = 3;
		else if (target == 0x2F43)
			mask = 7;
		counter = board_mem_read(b, 0x4C84);
		counter = (uint8_t)(counter & mask);
		flags = and_a_flags(counter);
		a = ixr(b, 0x0F);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if (counter != 0)
			return;
		a = (uint8_t)(a & 0x0Fu);
		flags = and_a_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if (a == 0)
			return;
		flags = dec_r(a, flags, &a);
		ixw(b, 0x0F, a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		return;
	}
	/* Types 5 through 15 are bare RETs. A and F stay the rst $20 result. */
}

/* Split HL into the four frequency bytes and run the volume adjust. */
static void commit_freq(Board *b, uint16_t hl)
{
	uint8_t low = (uint8_t)hl;
	uint8_t high = (uint8_t)(hl >> 8);
	uint8_t a;
	uint8_t flags = Z80_F(b->cpu);
	uint8_t i;

	Z80_HL(b->cpu) = hl;
	iyw(b, 0, low);
	a = low;
	for (i = 0; i < 4u; i++)
		a = rrca(a, &flags);
	iyw(b, 1, a);
	iyw(b, 2, high);
	a = high;
	for (i = 0; i < 4u; i++)
		a = rrca(a, &flags);
	iyw(b, 3, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	adjust_volume(b);
}

static void shift_freq(Board *b, uint16_t hl, uint8_t count)
{
	uint8_t n;

	Z80_B(b->cpu) = count;
	Z80_HL(b->cpu) = hl;
	for (n = count; n != 0; n--) {
		uint8_t flags = add_hl_flags(hl, hl, Z80_F(b->cpu), &hl);

		Z80_HL(b->cpu) = hl;
		Z80_F(b->cpu) = flags;
	}
	Z80_B(b->cpu) = 0;
	commit_freq(b, hl);
}

/* j_2dd7  scale the wave's base frequency and return the volume in A. */
static void wave_freq(Board *b)
{
	uint16_t hl = ixr(b, 0x0E);
	uint8_t a = (uint8_t)(ixr(b, 0x0D) & 0x10u);
	uint8_t flags = and_a_flags(a);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = hl;
	if (a != 0)
		a = 1;
	a = add_a(a, ixr(b, 4), &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		commit_freq(b, hl);
		return;
	}
	shift_freq(b, hl, a);
}

/* One ordinary wave byte, then the frequency update. */
static void play_note(Board *b, uint8_t note)
{
	uint8_t low = (uint8_t)(note & 0x1Fu);
	uint8_t flags = and_a_flags(low);
	uint8_t c;
	uint8_t a;
	uint8_t index;

	Z80_B(b->cpu) = note;
	Z80_A(b->cpu) = low;
	Z80_F(b->cpu) = flags;
	if (low != 0)
		ixw(b, 0x0D, note);
	c = ixr(b, 9);
	a = (uint8_t)(ixr(b, 0x0B) & 0x08u);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_C(b->cpu) = c;
	if (a != 0)
		c = 0;
	ixw(b, 0x0F, c);
	Z80_C(b->cpu) = c;
	index = (uint8_t)((note >> 5) & 7u);
	Z80_HL(b->cpu) = 0x3BB0;
	Z80_A(b->cpu) = index;
	rst10(b, 0x2DC6);
	ixw(b, 0x0C, Z80_A(b->cpu));
	low = (uint8_t)(note & 0x1Fu);
	flags = and_a_flags(low);
	Z80_A(b->cpu) = low;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = note;
	if (low != 0) {
		low = (uint8_t)(low & 0x0Fu);
		Z80_HL(b->cpu) = 0x3BB8;
		Z80_A(b->cpu) = low;
		rst10(b, 0x2DD4);
		ixw(b, 0x0E, Z80_A(b->cpu));
	}
	wave_freq(b);
}

/* F0 replaces the program pointer with the word it points at. */
static void cmd_f0(Board *b)
{
	uint16_t hl = ix_ptr(b);
	uint8_t low = board_mem_read(b, hl);

	ixw(b, 6, low);
	hl = (uint16_t)(hl + 1u);
	ixw(b, 7, board_mem_read(b, hl));
	Z80_HL(b->cpu) = hl;
	Z80_A(b->cpu) = ixr(b, 7);
}

/* F1 through F4 read one parameter and store it at `off`. */
static void cmd_param(Board *b, uint8_t off)
{
	uint16_t hl = ix_ptr(b);
	uint8_t a = board_mem_read(b, hl);

	hl = (uint16_t)(hl + 1u);
	ix_set_ptr(b, hl);
	ixw(b, off, a);
	Z80_A(b->cpu) = a;
}

/* Walk song bytes until a note returns through the volume adjust.
 * Special bytes push $2D6C and RET back into this loop. FF's jump
 * to j_2df4 also RETs to $2D6C, so the next byte still runs.
 */
static void process_commands(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);

	for (;;) {
		uint8_t a = board_mem_read(b, hl);
		uint8_t flags;
		uint16_t target;

		hl = (uint16_t)(hl + 1u);
		ix_set_ptr(b, hl);
		flags = cp_flags(a, 0xF0);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if (a < 0xF0) {
			play_note(b, a);
			return;
		}
		push(b, 0x2D6C);
		a = (uint8_t)(a & 0x0Fu);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = and_a_flags(a);
		target = rst20(b, 0x2D85);
		if (target == 0x2F55)
			cmd_f0(b);
		else if (target == 0x2F65)
			cmd_param(b, 3);
		else if (target == 0x2F77)
			cmd_param(b, 4);
		else if (target == 0x2F89)
			cmd_param(b, 9);
		else if (target == 0x2F9B)
			cmd_param(b, 0x0B);
		else if (target == 0x2FAD) {
			a = (uint8_t)((uint8_t)~ixr(b, 2) & ixr(b, 0));
			ixw(b, 0, a);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_a_flags(a);
			j_2df4(b);
		}
		(void)pop_word(b);
		hl = ix_ptr(b);
		Z80_HL(b->cpu) = hl;
	}
}

/* j_364e  pick the song for this bit and read its pointer
 * Entry:    B is the bit-scan counter. HL is the channel's song table.
 *           E is the bit. IX is the wave block.
 * Exit:     The song pointer is in HL. BC is the saved scan pair.
 *           A byte has been processed. A is the volume adjust result.
 *           Host finishes the RET of that adjust, which is this call's RET
 *           when j_364e was reached by the jump at $2D62.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: the volume adjust.
 * Interrupt: returns inside the frame budget.
 * Stack: BC is pushed and popped. `rst $18` leaves $366B and $001B below it.
 */
void j_364e(Board *b)
{
	uint8_t breg = (uint8_t)(Z80_B(b->cpu) - 1u);
	uint8_t flags;
	uint16_t saved;
	uint8_t level;

	Z80_B(b->cpu) = breg;
	saved = Z80_BC(b->cpu);
	push(b, saved);
	flags = cp_flags(breg, 1);
	Z80_A(b->cpu) = breg;
	Z80_F(b->cpu) = flags;
	if (breg != 1) {
		Z80_B(b->cpu) = 0;
	} else {
		level = board_mem_read(b, 0x4E13);
		Z80_B(b->cpu) = 1;
		Z80_A(b->cpu) = level;
		Z80_F(b->cpu) = cp_flags(level, 1);
		if (level != 1) {
			Z80_B(b->cpu) = 2;
			Z80_F(b->cpu) = cp_flags(level, 4);
			Z80_A(b->cpu) = level;
			if (level != 4)
				Z80_B(b->cpu) = 3;
		}
	}
	rst18(b, 0x366B);
	Z80_BC(b->cpu) = pop_word(b);
	process_commands(b);
}

/* j_2d44  one wave channel
 * Entry:    IX = W_NUM. IY = the frequency bytes. HL = the song table.
 * Exit:     A is the volume. A silent channel returns from j_2df4.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, HL, and DE when a new song pointer is read
 * Flags live-out: the volume adjust, or j_2df4.
 * Interrupt: returns inside the frame budget.
 * Stack: a new bit jumps through j_364e. A note's volume RET is this RET.
 */
void j_2d44(Board *b)
{
	uint8_t num = ixr(b, 0);
	uint8_t flags = and_a_flags(num);
	uint8_t ebit;
	uint8_t breg;
	uint8_t a;
	uint8_t cur;

	Z80_A(b->cpu) = num;
	Z80_F(b->cpu) = flags;
	if (num == 0) {
		j_2df4(b);
		return;
	}
	Z80_C(b->cpu) = num;
	Z80_B(b->cpu) = 8;
	ebit = 0x80;
	breg = 8;
	for (;;) {
		a = (uint8_t)(ebit & num);
		flags = and_a_flags(a);
		Z80_A(b->cpu) = a;
		Z80_E(b->cpu) = ebit;
		Z80_F(b->cpu) = flags;
		if (a != 0)
			break;
		ebit = srl(ebit, &flags);
		Z80_E(b->cpu) = ebit;
		Z80_F(b->cpu) = flags;
		breg--;
		Z80_B(b->cpu) = breg;
		if (breg == 0)
			return;
	}
	cur = ixr(b, 2);
	a = (uint8_t)(cur & ebit);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		ixw(b, 2, ebit);
		j_364e(b);
		return;
	}
	if (dec_ix(b, 0x0C) != 0) {
		wave_freq(b);
		return;
	}
	Z80_HL(b->cpu) = ix_ptr(b);
	process_commands(b);
}

/* Scale an effect frequency. Count 0 skips the shift. */
static void effect_freq(Board *b)
{
	uint8_t base;
	uint8_t flags;
	uint8_t a;
	uint16_t hl;
	uint8_t i;

	base = add_a(ixr(b, 0x0E), ixr(b, 5), &flags);
	ixw(b, 0x0E, base);
	Z80_A(b->cpu) = base;
	Z80_F(b->cpu) = flags;
	hl = base;
	Z80_HL(b->cpu) = hl;
	Z80_H(b->cpu) = 0;
	Z80_L(b->cpu) = base;
	a = (uint8_t)(ixr(b, 3) & 0x70u);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		commit_freq(b, hl);
		return;
	}
	for (i = 0; i < 4u; i++)
		a = rrca(a, &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	shift_freq(b, hl, a);
}

/* Copy the eight parameter bytes for a newly selected effect bit. */
static void load_effect(Board *b, uint8_t ebit)
{
	uint8_t breg = (uint8_t)(Z80_B(b->cpu) - 1u);
	uint8_t a;
	uint8_t flags = Z80_F(b->cpu);
	uint16_t hl = Z80_HL(b->cpu);
	uint16_t de;
	uint16_t bc;
	uint8_t i;
	uint8_t vol;

	Z80_B(b->cpu) = breg;
	a = breg;
	for (i = 0; i < 3u; i++)
		a = rlca(a, &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_C(b->cpu) = a;
	Z80_B(b->cpu) = 0;
	push(b, hl);
	flags = add_hl_flags(hl, a, flags, &hl);
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
	push(b, Z80_IX(b->cpu));
	de = pop_word(b);
	de = (uint16_t)(de + 3u);
	Z80_DE(b->cpu) = de;
	bc = 8;
	while (bc != 0) {
		board_mem_write(b, de, board_mem_read(b, hl));
		de = (uint16_t)(de + 1u);
		hl = (uint16_t)(hl + 1u);
		bc = (uint16_t)(bc - 1u);
	}
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = hl;
	Z80_BC(b->cpu) = 0;
	Z80_HL(b->cpu) = pop_word(b);
	a = (uint8_t)(ixr(b, 6) & 0x7Fu);
	ixw(b, 0x0C, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	a = ixr(b, 4);
	ixw(b, 0x0E, a);
	Z80_A(b->cpu) = a;
	vol = ixr(b, 9);
	Z80_B(b->cpu) = vol;
	a = vol;
	for (i = 0; i < 4u; i++)
		a = rrca(a, &flags);
	a = (uint8_t)(a & 0x0Fu);
	flags = and_a_flags(a);
	ixw(b, 0x0B, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	a = (uint8_t)(a & 0x08u);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		ixw(b, 0x0F, vol);
		ixw(b, 0x0D, 0);
	}
	(void)ebit;
}

/* 1 means the effect bit was cleared and j_2dee must start over. */
static int effect_step(Board *b, uint8_t ebit)
{
	uint8_t cur = ixr(b, 2);
	uint8_t a = (uint8_t)(cur & ebit);
	uint8_t flags = and_a_flags(a);
	uint8_t next;
	uint8_t dir;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		ixw(b, 2, ebit);
		load_effect(b, ebit);
	}
	next = dec_ix(b, 0x0C);
	if (next != 0) {
		effect_freq(b);
		return 0;
	}
	a = ixr(b, 8);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0) {
		next = dec_ix(b, 8);
		if (next == 0) {
			a = (uint8_t)~ebit;
			flags = xor_flags(0);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = (uint8_t)((flags & 0xC5u) | (a & 0x28u) | 0x12u);
			a = (uint8_t)(a & ixr(b, 0));
			flags = and_a_flags(a);
			ixw(b, 0, a);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			return 1;
		}
	}
	a = (uint8_t)(ixr(b, 6) & 0x7Fu);
	flags = and_a_flags(a);
	ixw(b, 0x0C, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((ixr(b, 6) & 0x80u) != 0) {
		a = ixr(b, 5);
		a = sub_a(0, a, &flags);
		ixw(b, 5, a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		dir = ixr(b, 0x0D);
		flags = (uint8_t)(((dir & 0x01u) != 0 ? 0u : 0x44u) |
				  (dir & 0x28u) | 0x10u | (flags & 0x01u));
		Z80_F(b->cpu) = flags;
		ixw(b, 0x0D, (uint8_t)(dir | 0x01u));
		if ((dir & 0x01u) == 0) {
			effect_freq(b);
			return 0;
		}
		ixw(b, 0x0D, (uint8_t)(dir & (uint8_t)~0x01u));
	}
	a = add_a(ixr(b, 4), ixr(b, 7), &flags);
	ixw(b, 4, a);
	ixw(b, 0x0E, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	a = add_a(ixr(b, 9), ixr(b, 0x0A), &flags);
	ixw(b, 9, a);
	Z80_A(b->cpu) = a;
	Z80_B(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	a = (uint8_t)(ixr(b, 0x0B) & 0x08u);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0)
		ixw(b, 0x0F, Z80_B(b->cpu));
	effect_freq(b);
	return 0;
}

/* j_2dee  one effect channel
 * Entry:    IX = E_NUM. IY = the frequency bytes. HL = the effect table.
 * Exit:     A is the volume, or 0 when the channel is idle.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: the volume adjust, or j_2df4, or the failed bit scan.
 * Interrupt: returns inside the frame budget.
 * Stack: a new effect pushes the table and IX. The volume RET is this RET.
 */
void j_2dee(Board *b)
{
	for (;;) {
		uint8_t num = ixr(b, 0);
		uint8_t flags = and_a_flags(num);
		uint8_t ebit;
		uint8_t breg;
		uint8_t a;

		Z80_A(b->cpu) = num;
		Z80_F(b->cpu) = flags;
		if (num == 0) {
			j_2df4(b);
			return;
		}
		Z80_C(b->cpu) = num;
		ebit = 0x80;
		breg = 8;
		Z80_B(b->cpu) = 8;
		for (;;) {
			a = (uint8_t)(ebit & num);
			flags = and_a_flags(a);
			Z80_A(b->cpu) = a;
			Z80_E(b->cpu) = ebit;
			Z80_F(b->cpu) = flags;
			if (a != 0)
				break;
			ebit = srl(ebit, &flags);
			Z80_E(b->cpu) = ebit;
			Z80_F(b->cpu) = flags;
			breg--;
			Z80_B(b->cpu) = breg;
			if (breg == 0)
				return;
		}
		if (effect_step(b, ebit) == 0)
			return;
	}
}

/* j_2d0c  effects for all three voices
 * Entry:    the three effect blocks and frequency bytes.
 * Exit:     Each channel volume is stored. ($4E90) = 0.
 *           A = 0. F is `xor a`.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: Z and P/V set.
 * Interrupt: returns inside the frame budget.
 * Stack: three calls of j_2dee. The last return $2D3C is under SP.
 */
void j_2d0c(Board *b)
{
	Z80_HL(b->cpu) = 0x3B30;
	Z80_IX(b->cpu) = 0x4E9C;
	Z80_IY(b->cpu) = 0x4E8C;
	call_lifted(b, 0x2D1A, j_2dee);
	board_mem_write(b, 0x4E91, Z80_A(b->cpu));

	Z80_HL(b->cpu) = 0x3B40;
	Z80_IX(b->cpu) = 0x4EAC;
	Z80_IY(b->cpu) = 0x4E92;
	call_lifted(b, 0x2D2B, j_2dee);
	board_mem_write(b, 0x4E96, Z80_A(b->cpu));

	Z80_HL(b->cpu) = 0x3B80;
	Z80_IX(b->cpu) = 0x4EBC;
	Z80_IY(b->cpu) = 0x4E97;
	call_lifted(b, 0x2D3C, j_2dee);
	board_mem_write(b, 0x4E9B, Z80_A(b->cpu));

	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
	board_mem_write(b, 0x4E90, 0);
}

/* Store the wave volume when the channel is still playing.
 * The last channel returns. The others fall through.
 */
static void song_channel(Board *b, uint16_t table, uint16_t ix, uint16_t iy,
			 uint16_t vol_addr, uint16_t ret, int last)
{
	uint8_t volume;
	uint8_t num;
	uint8_t flags;

	Z80_HL(b->cpu) = table;
	Z80_IX(b->cpu) = ix;
	Z80_IY(b->cpu) = iy;
	call_lifted(b, ret, j_2d44);
	volume = Z80_A(b->cpu);
	Z80_B(b->cpu) = volume;
	num = board_mem_read(b, ix);
	flags = and_a_flags(num);
	Z80_A(b->cpu) = num;
	Z80_F(b->cpu) = flags;
	if (num == 0)
		return;
	Z80_A(b->cpu) = volume;
	board_mem_write(b, vol_addr, volume);
	(void)last;
}

/* j_2cc4  the three song channels
 * Entry:    HL = song table 1, set by j_9797.
 * Exit:     Channel 3 idle: A = 0, F is `and`, B is that channel's volume.
 *           Otherwise ($4E9B) holds channel 3's volume. A is that volume.
 *           F is `and` of channel 3's wave number.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: `and` of channel 3's wave number.
 * Interrupt: returns inside the frame budget.
 * Stack: three calls of j_2d44.
 */
void j_2cc4(Board *b)
{
	song_channel(b, Z80_HL(b->cpu), 0x4ECC, 0x4E8C, 0x4E91, 0x2CCF, 0);
	song_channel(b, 0x967D, 0x4EDC, 0x4E92, 0x4E96, 0x2CE8, 0);
	song_channel(b, 0x968D, 0x4EEC, 0x4E97, 0x4E9B, 0x2D01, 1);
}

static void ldir_n(Board *b, uint16_t hl, uint16_t de, uint16_t bc)
{
	while (bc != 0) {
		board_mem_write(b, de, board_mem_read(b, hl));
		hl = (uint16_t)(hl + 1u);
		de = (uint16_t)(de + 1u);
		bc = (uint16_t)(bc - 1u);
	}
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = de;
	Z80_BC(b->cpu) = 0;
}

/* j_9797  intermission sprites, then the songs
 * Entry:    ($4F00) is the intermission flag. HL is whatever the jump left.
 * Exit:     While an intermission runs, 12 bytes move from $4F50 to $4C02.
 *           Cocktail player 2 with sprite $3F stores $FF at $4C0A.
 *           Then j_2cc4. HL enters that routine as $9685.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: j_2cc4's flags.
 * Interrupt: returns inside the frame budget.
 * Stack: the jump is a tail into j_2cc4.
 */
void j_9797(Board *b)
{
	uint8_t flag = board_mem_read(b, 0x4F00);
	uint8_t flags = cp_flags(flag, 0);
	uint8_t a;

	Z80_A(b->cpu) = flag;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0) {
		Z80_DE(b->cpu) = 0x4C02;
		Z80_HL(b->cpu) = 0x4F50;
		Z80_BC(b->cpu) = 0x000C;
		ldir_n(b, 0x4F50, 0x4C02, 0x000C);
	}
	a = board_mem_read(b, 0x4E09);
	Z80_HL(b->cpu) = 0x4E72;
	Z80_A(b->cpu) = a;
	a = (uint8_t)(a & board_mem_read(b, 0x4E72));
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0) {
		a = board_mem_read(b, 0x4C0A);
		flags = cp_flags(a, 0x3F);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if ((flags & 0x40u) != 0) {
			Z80_A(b->cpu) = 0xFF;
			board_mem_write(b, 0x4C0A, 0xFF);
		}
	}
	Z80_HL(b->cpu) = 0x9685;
	j_2cc4(b);
}

/* j_2cc1  the vblank's song call. The bytes are `jp j_9797`. */
void j_2cc1(Board *b)
{
	j_9797(b);
}
