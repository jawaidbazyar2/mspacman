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

/* `srl r`. The bit that shifts out becomes C. */
static uint8_t srl(uint8_t value, uint8_t *flags)
{
	uint8_t result = (uint8_t)(value >> 1);

	*flags = (uint8_t)((result & 0xA8u) |
			   (result == 0 ? 0x40u : 0u) |
			   parity_pv(result) |
			   (value & 1u));
	return result;
}

/* `cpl`. S, Z, P/V, and C stay. H and N are set. Y and X come from A. */
static uint8_t cpl_a(uint8_t a, uint8_t flags, uint8_t *out)
{
	a = (uint8_t)~a;
	*out = (uint8_t)((flags & 0xC5u) | (a & 0x28u) | 0x12u);
	return a;
}

/* `bit n, r`. H is set. N is clear. C stays. Y and X come from the register. */
static uint8_t bit_flags(uint8_t value, uint8_t bit, uint8_t flags)
{
	uint8_t t = (uint8_t)(value & (uint8_t)(1u << bit));
	uint8_t tested = t != 0 ? (uint8_t)(t & 0x80u) : 0x44u;

	return (uint8_t)(tested | (value & 0x28u) | 0x10u | (flags & 0x01u));
}

/* `or r`. H, N, and C are clear. */
static uint8_t or_flags(uint8_t result)
{
	return (uint8_t)(parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

/* `xor r`. H, N, and C are clear. */
static uint8_t xor_flags(uint8_t result)
{
	return (uint8_t)(parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
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

/* `rst $10`. HL = HL + A, A = (HL). F is the `adc a, h`. */
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

/* `rst $20`. See c/mode.c. The plant at SP-2 is $0023. */
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

/* 1 when cocktail mode and player 2 are both on. F is the `and`. */
static int p2_cocktail(Board *b)
{
	uint8_t cock = board_mem_read(b, 0x4E72);
	uint8_t a = board_mem_read(b, 0x4E09);

	Z80_B(b->cpu) = cock;
	a = (uint8_t)(a & cock);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	return a != 0;
}

/* Store one actor. Y is written, then X. Optional complement before the add. */
static void store_xy(Board *b, uint16_t y_src, int y_cpl, uint8_t y_add,
		     uint16_t x_src, int x_cpl, uint8_t x_add,
		     uint16_t y_dest, uint16_t x_dest)
{
	uint8_t flags = Z80_F(b->cpu);
	uint8_t a = board_mem_read(b, y_src);

	if (y_cpl)
		a = cpl_a(a, flags, &flags);
	a = add_a(a, y_add, &flags);
	board_mem_write(b, y_dest, a);
	a = board_mem_read(b, x_src);
	if (x_cpl)
		a = cpl_a(a, flags, &flags);
	a = add_a(a, x_add, &flags);
	board_mem_write(b, x_dest, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
}

/* Upright positions. E = 9, C = 7, D = 6. IX = $4C00. */
static void orient_upright(Board *b)
{
	Z80_IX(b->cpu) = 0x4C00;
	Z80_E(b->cpu) = 9;
	Z80_C(b->cpu) = 7;
	Z80_D(b->cpu) = 6;
	store_xy(b, 0x4D00, 1, 9, 0x4D01, 0, 6, 0x4C13, 0x4C12);
	store_xy(b, 0x4D02, 1, 9, 0x4D03, 0, 6, 0x4C15, 0x4C14);
	store_xy(b, 0x4D04, 1, 9, 0x4D05, 0, 7, 0x4C17, 0x4C16);
	store_xy(b, 0x4D06, 1, 9, 0x4D07, 0, 7, 0x4C19, 0x4C18);
	store_xy(b, 0x4D08, 1, 9, 0x4D09, 0, 7, 0x4C1B, 0x4C1A);
	store_xy(b, 0x4DD2, 1, 9, 0x4DD3, 0, 7, 0x4C1D, 0x4C1C);
}

/* Cocktail player 2. E = 8, C = 8, D = 7. IX = $4C00. */
static void orient_cocktail(Board *b)
{
	Z80_IX(b->cpu) = 0x4C00;
	Z80_E(b->cpu) = 8;
	Z80_C(b->cpu) = 8;
	Z80_D(b->cpu) = 7;
	store_xy(b, 0x4D00, 0, 8, 0x4D01, 1, 7, 0x4C13, 0x4C12);
	store_xy(b, 0x4D02, 0, 8, 0x4D03, 1, 7, 0x4C15, 0x4C14);
	store_xy(b, 0x4D04, 0, 8, 0x4D05, 1, 8, 0x4C17, 0x4C16);
	store_xy(b, 0x4D06, 0, 8, 0x4D07, 1, 8, 0x4C19, 0x4C18);
	store_xy(b, 0x4D08, 0, 8, 0x4D09, 1, 8, 0x4C1B, 0x4C1A);
	store_xy(b, 0x4DD2, 0, 8, 0x4DD3, 1, 8, 0x4C1D, 0x4C1C);
}

/* Ms. Pac-Man's mouth. Bit 0 of the sum clear selects the closed tile.
 * F stays the `bit 0` of the sum even when A is replaced.
 */
static void pac_frame(Board *b, uint16_t pos, int invert, uint8_t base,
		      uint8_t closed)
{
	uint8_t flags;
	uint8_t a = board_mem_read(b, pos);

	a = (uint8_t)(a & 7u);
	flags = and_a_flags(a);
	a = srl(a, &flags);
	if (invert)
		a = cpl_a(a, flags, &flags);
	Z80_E(b->cpu) = base;
	a = add_a(a, base, &flags);
	flags = bit_flags(a, 0, flags);
	if ((a & 1u) == 0)
		a = closed;
	board_mem_write(b, 0x4C0A, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
}

/* j_869c  Ms. Pac-Man facing right */
void j_869c(Board *b)
{
	pac_frame(b, 0x4D09, 1, 0x30, 0x37);
}

/* j_86b1  Ms. Pac-Man facing down */
void j_86b1(Board *b)
{
	pac_frame(b, 0x4D08, 0, 0x30, 0x34);
}

/* j_86c5  Ms. Pac-Man facing left */
void j_86c5(Board *b)
{
	pac_frame(b, 0x4D09, 0, 0xAC, 0x35);
}

/* j_86d9  Ms. Pac-Man facing up */
void j_86d9(Board *b)
{
	pac_frame(b, 0x4D08, 1, 0xF4, 0x36);
}

/* j_168c  the direction table's jump to the right-facing tiles */
void j_168c(Board *b)
{
	j_869c(b);
}

/* j_16b1  the direction table's jump to the down-facing tiles */
void j_16b1(Board *b)
{
	j_86b1(b);
}

/* j_16d6  load Ms. Pac-Man's X, then the left-facing tiles.
 * The load is repeated by j_86c5. */
void j_16d6(Board *b)
{
	Z80_A(b->cpu) = board_mem_read(b, 0x4D09);
	j_86c5(b);
}

/* j_16f7  load Ms. Pac-Man's Y, then the up-facing tiles.
 * The load is repeated by j_86d9. */
void j_16f7(Board *b)
{
	Z80_A(b->cpu) = board_mem_read(b, 0x4D08);
	j_86d9(b);
}

/* Keep the edible tile only when the ghost is alive and frightened. */
static void one_ghost(Board *b, uint16_t ix, uint8_t slot, uint16_t state,
		      uint16_t frightened, uint16_t dir, uint8_t phase)
{
	uint8_t s = board_mem_read(b, state);
	uint8_t flags = and_a_flags(s);
	uint8_t a;

	Z80_A(b->cpu) = s;
	Z80_F(b->cpu) = flags;
	if (s == 0) {
		a = board_mem_read(b, frightened);
		flags = and_a_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if (a != 0)
			return;
	}
	a = board_mem_read(b, dir);
	flags = 0;
	a = add_a(a, a, &flags);
	a = add_a(a, phase, &flags);
	a = add_a(a, 0x20, &flags);
	board_mem_write(b, (uint16_t)(ix + slot), a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
}

/* Edible tiles first, then each ghost that is not both alive and blue. */
static void ghost_anim(Board *b)
{
	uint16_t ix = Z80_IX(b->cpu);
	uint8_t phase = board_mem_read(b, 0x4DC0);
	uint8_t flags = 0;
	uint8_t edible;

	Z80_HL(b->cpu) = 0x4DC0;
	Z80_D(b->cpu) = phase;
	edible = add_a(0x1C, phase, &flags);
	board_mem_write(b, (uint16_t)(ix + 2u), edible);
	board_mem_write(b, (uint16_t)(ix + 4u), edible);
	board_mem_write(b, (uint16_t)(ix + 6u), edible);
	board_mem_write(b, (uint16_t)(ix + 8u), edible);
	Z80_C(b->cpu) = 0x20;
	Z80_A(b->cpu) = edible;
	Z80_F(b->cpu) = flags;
	one_ghost(b, ix, 2, 0x4DAC, 0x4DA7, 0x4D2C, phase);
	one_ghost(b, ix, 4, 0x4DAD, 0x4DA8, 0x4D2D, phase);
	one_ghost(b, ix, 6, 0x4DAE, 0x4DA9, 0x4D2E, phase);
	one_ghost(b, ix, 8, 0x4DAF, 0x4DAA, 0x4D2F, phase);
}

/* Cocktail flip of the Ms. Pac-Man tile, before the ghost tiles. */
static void flip_pac(Board *b)
{
	uint8_t c = 0xC0;
	uint8_t d = board_mem_read(b, 0x4C0A);
	uint8_t a = (uint8_t)(d & c);
	uint8_t flags = and_a_flags(a);
	uint8_t dir;

	Z80_C(b->cpu) = c;
	Z80_D(b->cpu) = d;
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		a = (uint8_t)(d | c);
		flags = or_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		board_mem_write(b, 0x4C0A, a);
		return;
	}
	dir = board_mem_read(b, 0x4D30);
	flags = cp_flags(dir, 2);
	Z80_A(b->cpu) = dir;
	Z80_F(b->cpu) = flags;
	if (dir == 2) {
		flags = bit_flags(d, 7, flags);
		Z80_F(b->cpu) = flags;
		if ((d & 0x80u) == 0)
			return;
		a = (uint8_t)(d ^ c);
		flags = xor_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		board_mem_write(b, 0x4C0A, a);
		return;
	}
	flags = cp_flags(dir, 3);
	Z80_F(b->cpu) = flags;
	if (dir != 3)
		return;
	flags = bit_flags(d, 6, flags);
	Z80_F(b->cpu) = flags;
	if ((d & 0x40u) == 0)
		return;
	a = (uint8_t)(d ^ c);
	flags = xor_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	board_mem_write(b, 0x4C0A, a);
}

static void face_pac(Board *b)
{
	uint16_t target;

	push(b, 0x151C);
	Z80_A(b->cpu) = board_mem_read(b, 0x4D30);
	target = rst20(b, 0x1514);
	if (target == 0x168C)
		j_168c(b);
	else if (target == 0x16B1)
		j_16b1(b);
	else if (target == 0x16D6)
		j_16d6(b);
	else if (target == 0x16F7)
		j_16f7(b);
	(void)pop_word(b);
	if (Z80_B(b->cpu) != 0)
		flip_pac(b);
}

extern void j_15e6(Board *b);
extern void j_162d(Board *b);
extern void j_1652(Board *b);

static void or_c0(Board *b, uint16_t addr)
{
	uint8_t a = (uint8_t)(board_mem_read(b, addr) | 0xC0u);

	board_mem_write(b, addr, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = or_flags(a);
}

/* j_14fe  choose Ms. Pac-Man's tile and the four ghost tiles
 * Entry:    IX = $4C00. B is 0 upright and 1 for cocktail player 2.
 *           ($4DA5) is the death animation. ($4DA4) is a ghost being eaten.
 * Exit:     Sprite codes are stored. The three cutscene tweaks run.
 *           Upright: A = 0 and F is `and a` ($54).
 *           Cocktail: the five codes are OR'd with $C0. A and F are the
 *           last `or`. C = $C0.
 *           Host finishes the RET.
 * Clobbers: A, F, C, D, HL
 * Flags live-out: `and a` of B, or the last cocktail `or`.
 * Interrupt: returns inside the frame budget.
 * Stack: the facing path pushes $151C and the direction routine pops it.
 *         Then the three cutscene calls.
 */
void j_14fe(Board *b)
{
	uint8_t death = board_mem_read(b, 0x4DA5);
	uint8_t killed;
	uint8_t breg;

	Z80_A(b->cpu) = death;
	Z80_F(b->cpu) = and_a_flags(death);
	if (death == 0) {
		killed = board_mem_read(b, 0x4DA4);
		Z80_A(b->cpu) = killed;
		Z80_F(b->cpu) = and_a_flags(killed);
		if (killed == 0)
			face_pac(b);
	}
	if (death != 0 || board_mem_read(b, 0x4DA4) == 0)
		ghost_anim(b);
	call_lifted(b, 0x15B7, j_15e6);
	call_lifted(b, 0x15BA, j_162d);
	call_lifted(b, 0x15BD, j_1652);
	breg = Z80_B(b->cpu);
	Z80_A(b->cpu) = breg;
	Z80_F(b->cpu) = and_a_flags(breg);
	if (breg == 0)
		return;
	Z80_C(b->cpu) = 0xC0;
	or_c0(b, 0x4C02);
	or_c0(b, 0x4C04);
	or_c0(b, 0x4C06);
	or_c0(b, 0x4C08);
	or_c0(b, 0x4C0C);
}

/* j_141f  cocktail player 2 sprite positions, then the tiles
 * Entry:    ($4E72) cocktail, ($4E09) player.
 * Exit:     If either is 0: A = 0, B = the cocktail byte, F is `and`.
 *           Otherwise positions are flipped and j_14fe runs.
 *           Host finishes the RET.
 * Clobbers: A, F, B, and on the flip path C, D, E, IX, HL
 * Flags live-out: the opening `and`, or j_14fe.
 * Interrupt: returns inside the frame budget.
 * Stack: normal RET when upright. The flip path is a tail into j_14fe.
 */
void j_141f(Board *b)
{
	if (!p2_cocktail(b))
		return;
	Z80_B(b->cpu) = Z80_A(b->cpu);
	orient_cocktail(b);
	j_14fe(b);
}

/* j_1490  upright sprite positions, then the tiles
 * Entry:    ($4E72) cocktail, ($4E09) player.
 * Exit:     Cocktail player 2 returns immediately. A is the `and`,
 *           B is the cocktail byte, F is the `and`.
 *           Otherwise B = 0, positions are copied, and j_14fe runs.
 *           Host finishes the RET.
 * Clobbers: A, F, B, and on the draw path C, D, E, IX, HL
 * Flags live-out: the opening `and` when it returns, otherwise j_14fe.
 * Interrupt: returns inside the frame budget.
 * Stack: normal RET. The draw path falls into j_14fe.
 */
void j_1490(Board *b)
{
	if (p2_cocktail(b))
		return;
	Z80_B(b->cpu) = 0;
	orient_upright(b);
	j_14fe(b);
}
