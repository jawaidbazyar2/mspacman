#include "lift.h"

/* Flags from `add a, n`. The sum replaces A. */
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

/* j_2000  add a two-byte offset to a sprite position
 * Entry:    IY points at a Y,X position. IX points at a Y,X offset.
 * Exit:     L = (IY) + (IX), H = (IY+1) + (IX+1), both sums 8-bit.
 *           A = H. F is the second add (the X byte). The Y add's
 *           flags are overwritten.
 *           Host finishes the RET.
 * Clobbers: A, F, HL
 * Flags live-out: none. Callers store HL or replace F (`rrca`, `ld a`)
 *           before a test. The carry into that `rrca` is not this carry.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_2000(Board *b)
{
	uint16_t ix = Z80_IX(b->cpu);
	uint16_t iy = Z80_IY(b->cpu);
	uint8_t flags = 0;
	uint8_t y;
	uint8_t x;

	y = add_a(board_mem_read(b, iy), board_mem_read(b, ix), &flags);
	x = add_a(board_mem_read(b, (uint16_t)(iy + 1u)),
		  board_mem_read(b, (uint16_t)(ix + 1u)),
		  &flags);
	Z80_A(b->cpu) = x;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = (uint16_t)(((uint16_t)x << 8) | y);
}

/* j_2018  convert a sprite position to a tile position
 * Entry:    HL = sprite position. L is X, H is Y.
 * Exit:     L = (X >> 3) + $20. H = (Y >> 3) + $1E. A = H.
 *           F is the Y add. The X add's flags are overwritten.
 *           Host finishes the RET.
 * Clobbers: A, F, HL
 * Flags live-out: none. The caller stores HL, then `and a` replaces F.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_2018(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint8_t flags = 0;
	uint8_t x = (uint8_t)((uint8_t)hl >> 3);
	uint8_t y = (uint8_t)((uint8_t)(hl >> 8) >> 3);

	x = add_a(x, 0x20, &flags);
	y = add_a(y, 0x1E, &flags);
	Z80_A(b->cpu) = y;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = (uint16_t)(((uint16_t)y << 8) | x);
}

/* PUSH writes high byte then low byte, and leaves those bytes after POP. */
static void push_word(Board *b, uint16_t *sp, uint16_t value)
{
	*sp = (uint16_t)(*sp - 2u);
	board_mem_write(b, (uint16_t)(*sp + 1u), (uint8_t)(value >> 8));
	board_mem_write(b, *sp, (uint8_t)value);
}

/* j_0065  convert a tile position to a screen address
 * Entry:    HL = tile position. The routine is the body at $202D.
 *           AF and BC are live-in.
 * Exit:     HL = ((L - $20) + (((H - $20) & $1F) << 5)) + $4040,
 *           with both subtractions 8-bit.
 *           A, F, and BC are restored. The four stack bytes below SP
 *           still hold the saved AF and BC.
 *           Host finishes the RET.
 * Clobbers: HL
 * Flags live-out: all. `pop af` puts the incoming flags back.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: two pushes, both popped before the RET. No callee.
 */
void j_0065(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t x = (uint8_t)((uint8_t)hl - 0x20u);
	uint8_t y = (uint8_t)((uint8_t)(hl >> 8) - 0x20u);
	uint16_t af = (uint16_t)(((uint16_t)Z80_A(b->cpu) << 8) | Z80_F(b->cpu));

	push_word(b, &sp, af);
	push_word(b, &sp, Z80_BC(b->cpu));
	hl = (uint16_t)((uint16_t)x + (uint16_t)((uint16_t)(y & 0x1Fu) << 5));
	Z80_HL(b->cpu) = (uint16_t)(hl + 0x4040u);
}

/* `add hl, de`. S, Z, and P/V stay. N is clear. */
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

/* j_2052  turn a tile position into a color-screen address
 * Entry:    HL = tile position. A, F, and BC are live-in.
 * Exit:     HL = the screen address from j_0065 plus $0400. DE = $0400.
 *           A, F's S/Z/P/V, and BC are what j_0065 restored. F is that
 *           `add hl, de`.
 *           The six stack bytes below SP still hold the call to j_0065
 *           ($2055) and the AF and BC that j_0065 pushed.
 *           Host finishes the RET.
 * Clobbers: F, DE, HL
 * Flags live-out: none. The caller loads A from (HL) and compares it.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: one call, returned before this RET. The callee is already C.
 */
void j_2052(Board *b)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t color;

	push_word(b, &sp, 0x2055);
	Z80_SP(b->cpu) = sp;
	j_0065(b);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	Z80_DE(b->cpu) = 0x0400;
	Z80_F(b->cpu) = add_hl_flags(Z80_HL(b->cpu), 0x0400, Z80_F(b->cpu), &color);
	Z80_HL(b->cpu) = color;
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

/* `and a`. H is set. N and C are clear. */
static uint8_t and_a_flags(uint8_t a)
{
	return (uint8_t)(0x10u | parity_pv(a) | (a & 0xA8u) |
			 (a == 0 ? 0x40u : 0u));
}

/* `scf` with Q disabled. S, Z, and P/V stay. Y and X come from A. */
static uint8_t scf_flags(uint8_t flags, uint8_t a)
{
	return (uint8_t)((flags & 0xC4u) | (a & 0x28u) | 0x01u);
}

/* j_1ed0  wrap a tile X through the side tunnel
 * Entry:    A = actor index. Positions are the X bytes at $4D09 + A*2.
 * Exit:     C = A*2, HL = that X address.
 *           If X is $1D: store $3D, B stays 0, A stays $1D, F is `scf`.
 *           If X is $3E: store $1E, B stays 0, A stays $3E, F is `scf`.
 *           If X < $21: B = $21, A = X - $21, F is `scf` after that `sub`.
 *           If X >= $3B: B = $3B, A = X - $3B, F is `scf` after that `sub`.
 *           Otherwise B = $3B, A = X - $3B, F is `and a` (carry clear).
 *           Host finishes the RET.
 * Clobbers: A, F, B, C, HL
 * Flags live-out: carry tells the caller the position was wrapped.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_1ed0(Board *b)
{
	uint8_t flags = 0;
	uint8_t doubled = add_a(Z80_A(b->cpu), Z80_A(b->cpu), &flags);
	uint16_t hl = (uint16_t)(0x4D09u + doubled);
	uint8_t x = board_mem_read(b, hl);
	uint8_t a = x;

	Z80_B(b->cpu) = 0;
	Z80_C(b->cpu) = doubled;
	Z80_HL(b->cpu) = hl;
	flags = cp_flags(x, 0x1D);
	if ((flags & 0x40u) != 0) {
		board_mem_write(b, hl, 0x3D);
		flags = scf_flags(flags, a);
	} else {
		flags = cp_flags(x, 0x3E);
		if ((flags & 0x40u) != 0) {
			board_mem_write(b, hl, 0x1E);
			flags = scf_flags(flags, a);
		} else {
			Z80_B(b->cpu) = 0x21;
			a = sub_a(x, 0x21, &flags);
			if ((flags & 0x01u) == 0) {
				a = board_mem_read(b, hl);
				Z80_B(b->cpu) = 0x3B;
				a = sub_a(a, 0x3B, &flags);
				if ((flags & 0x01u) != 0)
					flags = and_a_flags(a);
				else
					flags = scf_flags(flags, a);
			} else
				flags = scf_flags(flags, a);
		}
	}
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
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

/* j_200f  read the tile at a sprite-relative position
 * Entry:    IX and IY are the two positions j_2000 adds.
 * Exit:     HL = the screen address of that sum. A = the byte there.
 *           F is `and a` of that byte.
 *           The stack bytes below SP hold the call to j_0065 ($2015)
 *           and the AF and BC that j_0065 pushed. The earlier call to
 *           j_2000 is overwritten by that return address.
 *           Host finishes the RET.
 * Clobbers: A, F, HL
 * Flags live-out: Z tells the caller whether the tile is empty.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: two calls, both returned. Both callees are already C.
 */
void j_200f(Board *b)
{
	uint8_t a;

	call_lifted(b, 0x2012, j_2000);
	call_lifted(b, 0x2015, j_0065);
	a = board_mem_read(b, Z80_HL(b->cpu));
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
}

/* `bit 6, a`. A is unchanged. Y and X come from A. H is set. C stays. */
static uint8_t bit6_flags(uint8_t a, uint8_t flags)
{
	uint8_t tested = (a & 0x40u) != 0 ? 0u : 0x44u;

	return (uint8_t)(tested | (a & 0x28u) | 0x10u | (flags & 0x01u));
}

/* j_205a  set a ghost's tunnel slowdown flag from the color map
 * Entry:    IX and IY are the positions j_2052 turns into a color address.
 *           BC is the slowdown flag this ghost writes.
 * Exit:     (BC) = 1 when bit 6 of the color byte is set, else 0.
 *           A is that stored value. When the bit is clear, F is `xor a`
 *           ($44). When the bit is set, F is `bit 6, a` of the color byte:
 *           S and Z clear, H set, C copied from the `cp #1b` of that byte,
 *           Y and X copied from the color byte.
 *           The stack bytes below SP are the call to j_2052 ($205D) and
 *           whatever that call left underneath.
 *           The jump to j_366f is part of this routine. The nop and the
 *           Pac-Man store at $2063 are not executed.
 *           Host finishes the RET.
 * Clobbers: A, F, HL, and whatever j_2052 clobbers
 * Flags live-out: none. Callers return after the store.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: one call, returned. Callee is already C.
 */
void j_205a(Board *b)
{
	uint8_t a;
	uint8_t flags;

	call_lifted(b, 0x205D, j_2052);
	a = board_mem_read(b, Z80_HL(b->cpu));
	flags = bit6_flags(a, cp_flags(a, 0x1B));
	if ((flags & 0x40u) != 0) {
		a = 0;
		flags = 0x44;
	} else
		a = 1;
	board_mem_write(b, Z80_BC(b->cpu), a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
}

extern void j_0042(Board *b);
extern void j_1000(Board *b);
extern void j_1b08(Board *b);
extern void j_1a6a(Board *b);

static uint16_t read_word(Board *b, uint16_t addr)
{
	uint8_t lo = board_mem_read(b, addr);
	uint8_t hi = board_mem_read(b, (uint16_t)(addr + 1u));

	return (uint16_t)(lo | (uint16_t)((uint16_t)hi << 8));
}

static void write_word(Board *b, uint16_t addr, uint16_t value)
{
	board_mem_write(b, addr, (uint8_t)value);
	board_mem_write(b, (uint16_t)(addr + 1u), (uint8_t)(value >> 8));
}

static uint8_t inc8(uint8_t value, uint8_t flags, uint8_t *next)
{
	uint8_t result = (uint8_t)(value + 1u);

	*next = result;
	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x7Fu ? 0x04u : 0u) |
			 (flags & 0x01u));
}

static uint8_t dec8(uint8_t value, uint8_t flags, uint8_t *next)
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

static uint8_t rrca(uint8_t a, uint8_t flags, uint8_t *out)
{
	uint8_t next = (uint8_t)((a >> 1) | (uint8_t)((a & 1u) << 7));

	*out = (uint8_t)((flags & 0xC4u) | (next & 0x28u) | (next >> 7));
	return next;
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

static uint8_t bit_flags(uint8_t value, uint8_t bit, uint8_t flags)
{
	uint8_t t = (uint8_t)(value & (uint8_t)(1u << bit));
	uint8_t tested = t != 0 ? (uint8_t)(t & 0x80u) : 0x44u;

	return (uint8_t)(tested | (value & 0x28u) | 0x10u | (flags & 0x01u));
}

/* `adc hl, hl`. S, Z, H, P/V, and C come from the sum. */
static uint8_t adc_hl_hl(uint16_t hl, uint8_t carry, uint16_t *sum)
{
	uint32_t total = (uint32_t)hl + hl + (carry & 1u);
	uint16_t result = (uint16_t)total;
	uint16_t flipped = (uint16_t)~hl;
	uint16_t mix = (uint16_t)((hl ^ flipped) & (hl ^ result));
	uint8_t high = (uint8_t)(result >> 8);

	*sum = result;
	return (uint8_t)((high & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 (high & 0x10u) |
			 (uint8_t)((mix >> 13) & 0x04u) |
			 (uint8_t)((total >> 16) & 1u));
}

/* Double the counter, then the pattern. 0 means `ret nc`. */
static int arm_speed(Board *b, uint16_t counter, uint16_t pattern)
{
	uint16_t hl = read_word(b, counter);
	uint16_t sum;
	uint8_t flags = add_hl_flags(hl, hl, Z80_F(b->cpu), &sum);
	uint8_t low;

	write_word(b, counter, sum);
	hl = read_word(b, pattern);
	flags = adc_hl_hl(hl, flags, &sum);
	write_word(b, pattern, sum);
	Z80_HL(b->cpu) = sum;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) == 0)
		return 0;
	Z80_HL(b->cpu) = counter;
	low = board_mem_read(b, counter);
	board_mem_write(b, counter, (uint8_t)(low + 1u));
	return 1;
}

static int rst30(Board *b, uint16_t data)
{
	uint16_t de = 0x4C90;
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t left = 0x10;
	uint8_t i;
	uint8_t a = 0;
	uint8_t flags;
	uint8_t e;

	Z80_DE(b->cpu) = de;
	Z80_B(b->cpu) = left;
	for (;;) {
		a = board_mem_read(b, de);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = and_a_flags(a);
		if (a == 0)
			break;
		for (i = 0; i < 3; i++)
			de = (uint16_t)((de & 0xFF00u) | (uint8_t)(de + 1u));
		left--;
		Z80_B(b->cpu) = left;
		Z80_DE(b->cpu) = de;
		if (left == 0)
			return 0;
	}
	push_word(b, &sp, data);
	sp = (uint16_t)(sp + 2u);
	flags = Z80_F(b->cpu);
	e = (uint8_t)de;
	for (i = 0; i < 3; i++) {
		a = board_mem_read(b, data);
		board_mem_write(b, de, a);
		data = (uint16_t)(data + 1u);
		flags = inc8(e, flags, &e);
		de = (uint16_t)((de & 0xFF00u) | e);
	}
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = 0;
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = data;
	Z80_SP(b->cpu) = sp;
	return 1;
}

static int leave_play(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4E00);
	uint8_t flags = cp_flags(a, 0x01);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return 1;
	a = board_mem_read(b, 0x4E04);
	flags = cp_flags(a, 0x10);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	return (flags & 0x01u) == 0;
}

static uint8_t stick(Board *b)
{
	uint8_t c = Z80_C(b->cpu);
	uint8_t flags = and_a_flags(c);
	uint8_t a;

	Z80_A(b->cpu) = c;
	Z80_F(b->cpu) = flags;
	a = board_mem_read(b, c == 0 ? 0x5000 : 0x5040);
	Z80_A(b->cpu) = a;
	return a;
}

static int pressed(Board *b, uint8_t a, uint8_t bit)
{
	uint8_t flags = bit_flags(a, bit, Z80_F(b->cpu));

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	return (flags & 0x40u) != 0;
}

static int wall(Board *b)
{
	uint8_t a = (uint8_t)(Z80_A(b->cpu) & 0xC0u);
	uint8_t flags = and_a_flags(a);
	uint8_t diff;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	diff = sub_a(a, 0xC0, &flags);
	Z80_A(b->cpu) = diff;
	Z80_F(b->cpu) = flags;
	return (flags & 0x40u) != 0;
}

static void dec_b(Board *b)
{
	uint8_t next = 0;

	Z80_F(b->cpu) = dec8(Z80_B(b->cpu), Z80_F(b->cpu), &next);
	Z80_B(b->cpu) = next;
}

static int at_center(Board *b, uint16_t axis)
{
	uint8_t a = (uint8_t)(board_mem_read(b, axis) & 0x07u);
	uint8_t flags = cp_flags(a, 0x04);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	return (flags & 0x40u) != 0;
}

static int facing_vertical(Board *b)
{
	uint8_t flags = 0;
	uint8_t a = rrca(board_mem_read(b, 0x4D30), Z80_F(b->cpu), &flags);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	return (flags & 0x01u) != 0;
}

static void after_move(Board *b, uint16_t hl);
static void step_sprite(Board *b);

static void adopt(Board *b)
{
	uint16_t hl = read_word(b, 0x4D26);
	uint8_t dir;

	Z80_HL(b->cpu) = hl;
	write_word(b, 0x4D1C, hl);
	dec_b(b);
	if (Z80_B(b->cpu) != 0) {
		dir = board_mem_read(b, 0x4D3C);
		Z80_A(b->cpu) = dir;
		board_mem_write(b, 0x4D30, dir);
	}
	step_sprite(b);
}

static void old_way(Board *b)
{
	Z80_IX(b->cpu) = 0x4D1C;
	call_lifted(b, 0x191D, j_200f);
	if (!wall(b)) {
		step_sprite(b);
		return;
	}
	if (facing_vertical(b)) {
		if (at_center(b, 0x4D08))
			return;
	} else if (at_center(b, 0x4D09))
		return;
	step_sprite(b);
}

static void consider(Board *b)
{
	Z80_IX(b->cpu) = 0x4D26;
	Z80_IY(b->cpu) = 0x4D39;
	call_lifted(b, 0x18EF, j_200f);
	if (!wall(b)) {
		adopt(b);
		return;
	}
	dec_b(b);
	if (Z80_B(b->cpu) != 0) {
		old_way(b);
		return;
	}
	if (facing_vertical(b)) {
		if (at_center(b, 0x4D08))
			return;
	} else if (at_center(b, 0x4D09))
		return;
	adopt(b);
}

static void want(Board *b, uint16_t rom, uint8_t dir)
{
	uint16_t hl = read_word(b, rom);

	Z80_HL(b->cpu) = hl;
	Z80_A(b->cpu) = dir;
	if (dir == 0)
		Z80_F(b->cpu) = 0x44;
	board_mem_write(b, 0x4D3C, dir);
	write_word(b, 0x4D26, hl);
	Z80_B(b->cpu) = 0;
	consider(b);
}

static void face(Board *b, uint16_t rom, uint8_t dir)
{
	uint16_t hl = read_word(b, rom);

	Z80_HL(b->cpu) = hl;
	Z80_A(b->cpu) = dir;
	if (dir == 0)
		Z80_F(b->cpu) = 0x44;
	board_mem_write(b, 0x4D30, dir);
	write_word(b, 0x4D1C, hl);
	step_sprite(b);
}

static int fruit_hit(Board *b)
{
	uint8_t pos = board_mem_read(b, 0x4DD2);
	uint8_t flags = and_a_flags(pos);
	uint8_t points;
	uint8_t saved_f;
	uint16_t hl;
	uint16_t de;
	uint16_t sp;
	uint8_t a;

	Z80_A(b->cpu) = pos;
	Z80_F(b->cpu) = flags;
	if (pos == 0)
		return 0;
	points = board_mem_read(b, 0x4DD4);
	flags = and_a_flags(points);
	Z80_A(b->cpu) = points;
	Z80_F(b->cpu) = flags;
	if (points == 0)
		return 0;
	hl = read_word(b, 0x4D08);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = 0x8094;
	sp = Z80_SP(b->cpu);
	push_word(b, &sp, (uint16_t)(((uint16_t)points << 8) | flags));
	saved_f = flags;
	de = read_word(b, 0x4DD2);
	Z80_DE(b->cpu) = de;
	a = sub_a((uint8_t)(hl >> 8), (uint8_t)(de >> 8), &flags);
	a = add_a(a, 0x03, &flags);
	flags = cp_flags(a, 0x06);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) == 0) {
		Z80_A(b->cpu) = points;
		Z80_F(b->cpu) = saved_f;
		return 0;
	}
	a = sub_a((uint8_t)hl, (uint8_t)de, &flags);
	a = add_a(a, 0x03, &flags);
	flags = cp_flags(a, 0x06);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) == 0) {
		Z80_A(b->cpu) = points;
		Z80_F(b->cpu) = saved_f;
		return 0;
	}
	board_mem_write(b, 0x4C0D, 0x01);
	Z80_A(b->cpu) = points;
	Z80_F(b->cpu) = saved_f;
	a = add_a(points, 0x02, &flags);
	board_mem_write(b, 0x4C0C, a);
	a = sub_a(a, 0x02, &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	return 1;
}

static void swallow(Board *b)
{
	uint8_t tile;
	uint8_t flags;
	uint8_t a;
	uint8_t next = 0;
	uint8_t c;
	uint8_t snd;
	uint16_t hl = read_word(b, 0x4D39);

	Z80_A(b->cpu) = 0xFF;
	board_mem_write(b, 0x4D9D, 0xFF);
	Z80_HL(b->cpu) = hl;
	call_lifted(b, 0x19D8, j_0065);
	tile = board_mem_read(b, Z80_HL(b->cpu));
	Z80_A(b->cpu) = tile;
	flags = cp_flags(tile, 0x10);
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0) {
		flags = cp_flags(tile, 0x14);
		Z80_F(b->cpu) = flags;
		if ((flags & 0x40u) == 0)
			return;
	}
	Z80_IX(b->cpu) = 0x4E0E;
	flags = inc8(board_mem_read(b, 0x4E0E), flags, &next);
	board_mem_write(b, 0x4E0E, next);
	Z80_F(b->cpu) = flags;
	a = (uint8_t)(tile & 0x0Fu);
	flags = and_a_flags(a);
	a = srl(a, &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = 0x40;
	board_mem_write(b, Z80_HL(b->cpu), 0x40);
	Z80_B(b->cpu) = 0x19;
	c = srl(a, &flags);
	Z80_C(b->cpu) = c;
	Z80_F(b->cpu) = flags;
	call_lifted(b, 0x19F6, j_0042);
	flags = inc8(Z80_A(b->cpu), Z80_F(b->cpu), &a);
	Z80_A(b->cpu) = a;
	flags = cp_flags(a, 0x01);
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0) {
		a = add_a(a, a, &flags);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
	}
	board_mem_write(b, 0x4D9D, a);
	call_lifted(b, 0x1A03, j_1b08);
	call_lifted(b, 0x1A06, j_1a6a);
	hl = 0x4EBC;
	a = rrca(board_mem_read(b, 0x4E0E), Z80_F(b->cpu), &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = hl;
	snd = board_mem_read(b, hl);
	if ((flags & 0x01u) != 0)
		snd = (uint8_t)((snd & 0xFEu) | 0x02u);
	else
		snd = (uint8_t)((snd | 0x01u) & 0xFDu);
	board_mem_write(b, hl, snd);
}

static void after_move(Board *b, uint16_t hl)
{
	uint8_t a = 0;
	uint8_t snd;

	write_word(b, 0x4D08, hl);
	Z80_HL(b->cpu) = hl;
	call_lifted(b, 0x198B, j_2018);
	write_word(b, 0x4D39, Z80_HL(b->cpu));
	Z80_IX(b->cpu) = 0x4DBF;
	a = board_mem_read(b, 0x4DBF);
	board_mem_write(b, 0x4DBF, 0);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	if (a != 0)
		return;
	if (fruit_hit(b)) {
		Z80_B(b->cpu) = 0x19;
		Z80_C(b->cpu) = Z80_A(b->cpu);
		call_lifted(b, 0x19B8, j_0042);
		call_lifted(b, 0x19BB, j_1000);
		if (!rst30(b, 0x19C5))
			return;
		snd = (uint8_t)(board_mem_read(b, 0x4EBC) | 0x04u);
		board_mem_write(b, 0x4EBC, snd);
		Z80_HL(b->cpu) = 0x4EBC;
	}
	swallow(b);
}

static uint16_t nudge(uint16_t hl, int high)
{
	uint8_t coord = high ? (uint8_t)(hl >> 8) : (uint8_t)hl;
	uint8_t flags = cp_flags((uint8_t)(coord & 0x07u), 0x04);

	if ((flags & 0x40u) == 0) {
		if ((flags & 0x01u) != 0)
			coord = (uint8_t)(coord + 1u);
		else
			coord = (uint8_t)(coord - 1u);
		if (high)
			hl = (uint16_t)((hl & 0x00FFu) | (uint16_t)((uint16_t)coord << 8));
		else
			hl = (uint16_t)((hl & 0xFF00u) | coord);
	}
	return hl;
}

static void step_sprite(Board *b)
{
	uint16_t hl;

	Z80_IX(b->cpu) = 0x4D1C;
	Z80_IY(b->cpu) = 0x4D08;
	call_lifted(b, 0x195B, j_2000);
	hl = Z80_HL(b->cpu);
	hl = nudge(hl, facing_vertical(b));
	Z80_HL(b->cpu) = hl;
	after_move(b, hl);
}

static void demo(Board *b)
{
	uint8_t dy = board_mem_read(b, 0x4D1C);
	uint16_t hl;
	uint8_t dir;
	int ai;

	Z80_HL(b->cpu) = 0x4D1C;
	Z80_A(b->cpu) = dy;
	Z80_F(b->cpu) = and_a_flags(dy);
	if (dy == 0)
		ai = at_center(b, 0x4D09);
	else
		ai = at_center(b, 0x4D08);
	if (ai) {
		Z80_A(b->cpu) = 0x05;
		call_lifted(b, 0x1A3D, j_1ed0);
		if ((Z80_F(b->cpu) & 0x01u) == 0) {
			Z80_B(b->cpu) = 0x17;
			Z80_C(b->cpu) = 0;
			call_lifted(b, 0x1A42, j_0042);
		}
		Z80_IX(b->cpu) = 0x4D26;
		Z80_IY(b->cpu) = 0x4D12;
		call_lifted(b, 0x1A4D, j_2000);
		write_word(b, 0x4D12, Z80_HL(b->cpu));
		hl = read_word(b, 0x4D26);
		Z80_HL(b->cpu) = hl;
		write_word(b, 0x4D1C, hl);
		dir = board_mem_read(b, 0x4D3C);
		Z80_A(b->cpu) = dir;
		board_mem_write(b, 0x4D30, dir);
	}
	Z80_IX(b->cpu) = 0x4D1C;
	Z80_IY(b->cpu) = 0x4D08;
	call_lifted(b, 0x1A67, j_2000);
	after_move(b, Z80_HL(b->cpu));
}

static void steer(Board *b, int tunnel)
{
	uint8_t a;
	uint16_t hl;

	if (tunnel) {
		Z80_A(b->cpu) = 0x01;
		board_mem_write(b, 0x4DBF, 0x01);
	}
	if (leave_play(b)) {
		demo(b);
		return;
	}
	a = stick(b);
	if (tunnel) {
		if (pressed(b, a, 1))
			face(b, 0x3303, 0x02);
		else if (pressed(b, a, 2))
			face(b, 0x32FF, 0x00);
		else
			step_sprite(b);
		return;
	}
	if (pressed(b, a, 1))
		want(b, 0x3303, 0x02);
	else if (pressed(b, a, 2))
		want(b, 0x32FF, 0x00);
	else if (pressed(b, a, 0))
		want(b, 0x3305, 0x03);
	else if (pressed(b, a, 3))
		want(b, 0x3301, 0x01);
	else {
		hl = read_word(b, 0x4D1C);
		Z80_HL(b->cpu) = hl;
		write_word(b, 0x4D26, hl);
		Z80_B(b->cpu) = 0x01;
		consider(b);
	}
}

/* j_1806  move Ms. Pac-Man one step when her speed pattern says to
 * Entry:    ($4D9D) = eat delay. Speed words at $4D46 and $4D4A.
 * Exit:     A delay other than $FF decrements and returns.
 *           Otherwise one speed pattern doubles. Carry clear returns
 *           with `adc hl, hl`. Carry set moves her, eats a dot or
 *           the fruit when she is on one, and may arm the fright timer.
 *           In a demo the same step follows the demo tile instead.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The caller moves the ghosts next.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: each taken call leaves its return. Eating a dot is the deepest.
 */
void j_1806(Board *b)
{
	uint8_t delay = board_mem_read(b, 0x4D9D);
	uint8_t flags = cp_flags(0xFF, delay);
	uint8_t next = 0;
	uint8_t x;
	uint8_t diff;
	uint8_t pill;
	uint8_t mix;

	Z80_HL(b->cpu) = 0x4D9D;
	Z80_A(b->cpu) = 0xFF;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0) {
		Z80_F(b->cpu) = dec8(delay, flags, &next);
		board_mem_write(b, 0x4D9D, next);
		return;
	}
	pill = board_mem_read(b, 0x4DA6);
	flags = and_a_flags(pill);
	Z80_A(b->cpu) = pill;
	Z80_F(b->cpu) = flags;
	if (pill != 0) {
		if (!arm_speed(b, 0x4D4C, 0x4D4A))
			return;
	} else if (!arm_speed(b, 0x4D48, 0x4D46))
		return;
	Z80_A(b->cpu) = board_mem_read(b, 0x4E0E);
	board_mem_write(b, 0x4D9E, Z80_A(b->cpu));
	mix = board_mem_read(b, 0x4E72);
	Z80_C(b->cpu) = mix;
	mix = (uint8_t)(board_mem_read(b, 0x4E09) & mix);
	Z80_A(b->cpu) = mix;
	Z80_C(b->cpu) = mix;
	Z80_F(b->cpu) = and_a_flags(mix);
	Z80_HL(b->cpu) = 0x4D3A;
	x = board_mem_read(b, 0x4D3A);
	Z80_B(b->cpu) = 0x21;
	diff = sub_a(x, 0x21, &flags);
	Z80_A(b->cpu) = diff;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) == 0) {
		x = board_mem_read(b, 0x4D3A);
		Z80_A(b->cpu) = x;
		Z80_B(b->cpu) = 0x3B;
		diff = sub_a(x, 0x3B, &flags);
		Z80_A(b->cpu) = diff;
		Z80_F(b->cpu) = flags;
		if ((flags & 0x01u) != 0) {
			steer(b, 0);
			return;
		}
	}
	steer(b, 1);
}
