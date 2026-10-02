#include "lift.h"

/* j_1000  clear the fruit
 * Entry:    fruit byte at $4DD4. A is ignored.
 * Exit:     A = 0, F = Z|PV (the xor a result), ($4DD4) = 0.
 *           Host finishes the RET: PC is the return address, SP is back,
 *           WZ holds that return address.
 * Clobbers: A, F
 * Flags live-out: none. Both callers jump unconditionally after the call.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_1000(Board *b)
{
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	board_mem_write(b, 0x4DD4, 0);
}

extern void j_94bd(Board *b);

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

/* `adc a, n`. The carry-in is added. Overflow ignores that carry. */
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

/* Even parity sets P/V. */
static uint8_t parity_pv(uint8_t value)
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
	return (uint8_t)(0x10u | parity_pv(a) | (a & 0xA8u) |
			 (a == 0 ? 0x40u : 0u));
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

/* `rlca`. S, Z, and P/V stay. Y, X, and C come from the rotated byte. */
static uint8_t rlca(uint8_t value, uint8_t *flags)
{
	uint8_t result = (uint8_t)((uint8_t)(value << 1) | (uint8_t)(value >> 7));

	*flags = (uint8_t)((*flags & 0xC4u) | (result & 0x29u));
	return result;
}

static uint16_t read_word(Board *b, uint16_t addr)
{
	return (uint16_t)(board_mem_read(b, addr) |
			  (uint16_t)((uint16_t)board_mem_read(b, (uint16_t)(addr + 1u)) << 8));
}

static void write_word(Board *b, uint16_t addr, uint16_t value)
{
	board_mem_write(b, addr, (uint8_t)value);
	board_mem_write(b, (uint16_t)(addr + 1u), (uint8_t)(value >> 8));
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

/* `rst $10`: HL = HL + A, A = (HL). F is the `adc a, h`. */
static uint8_t rst10(Board *b, uint16_t *hl, uint8_t index, uint8_t *flags)
{
	uint8_t low = add_a(index, (uint8_t)*hl, flags);
	uint8_t high = adc8(0, (uint8_t)(*hl >> 8), *flags, flags);

	*hl = (uint16_t)(((uint16_t)high << 8) | low);
	return board_mem_read(b, *hl);
}

/* j_87cd through j_87e4. HL is the path-table base.
 * Caller leaves SP where `call j_94bd` executes.
 * The path slot is the next generator byte, masked to two bits. */
static void choose_path(Board *b, uint16_t table)
{
	uint8_t flags = 0;
	uint8_t pick;
	uint8_t a;
	uint8_t low;
	uint8_t hi;
	uint16_t hl;
	uint16_t sp;

	Z80_HL(b->cpu) = table;
	call_lifted(b, 0x87D0, j_94bd);

	hl = Z80_BC(b->cpu);
	a = lift_random_byte(b);
	pick = (uint8_t)(a & 0x03u);
	flags = and_a_flags(pick);
	a = add_a(pick, pick, &flags);
	a = add_a(a, a, &flags);
	a = add_a(a, pick, &flags);

	sp = Z80_SP(b->cpu);
	push_word(b, &sp, 0x87DB);
	low = rst10(b, &hl, a, &flags);
	hl = (uint16_t)(hl + 1u);
	hi = board_mem_read(b, hl);
	Z80_DE(b->cpu) = (uint16_t)(((uint16_t)hi << 8) | low);
	write_word(b, 0x4C42, Z80_DE(b->cpu));
	hl = (uint16_t)(hl + 1u);
	a = board_mem_read(b, hl);
	board_mem_write(b, 0x4C40, a);
	board_mem_write(b, 0x4C41, 0x1F);
	Z80_A(b->cpu) = 0x1F;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = pick;
	Z80_HL(b->cpu) = hl;
}

/* j_8747. Release a fruit when the dot count hits $40 or $B0.
 * From level 7 the fruit index is the next generator byte, mod 7. */
static void release_fruit(Board *b)
{
	uint8_t dots = board_mem_read(b, 0x4E0E);
	uint8_t flags = cp_flags(dots, 0x40);
	uint8_t a;
	uint16_t flag;
	uint16_t hl;
	uint16_t sp;

	Z80_A(b->cpu) = dots;
	if ((flags & 0x40u) != 0) {
		flag = 0x4E0C;
	} else {
		flags = cp_flags(dots, 0xB0);
		if ((flags & 0x40u) == 0) {
			Z80_F(b->cpu) = flags;
			return;
		}
		flag = 0x4E0D;
	}

	a = board_mem_read(b, flag);
	flags = and_a_flags(a);
	Z80_HL(b->cpu) = flag;
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;

	board_mem_write(b, flag, 1);
	a = board_mem_read(b, 0x4E13);
	flags = cp_flags(a, 0x07);
	if ((flags & 0x01u) == 0) {
		uint8_t rnd = (uint8_t)(lift_random_byte(b) & 0x1Fu);

		do
			rnd = sub_a(rnd, 7, &flags);
		while ((flags & 0x01u) == 0);
		a = add_a(rnd, 7, &flags);
	}

	hl = 0x879D;
	Z80_B(b->cpu) = a;
	a = add_a(a, a, &flags);
	a = add_a(a, Z80_B(b->cpu), &flags);
	a = rst10(b, &hl, a, &flags);
	board_mem_write(b, 0x4C0C, a);
	hl = (uint16_t)(hl + 1u);
	a = board_mem_read(b, hl);
	board_mem_write(b, 0x4C0D, a);
	hl = (uint16_t)(hl + 1u);
	a = board_mem_read(b, hl);
	board_mem_write(b, 0x4DD4, a);

	sp = Z80_SP(b->cpu);
	push_word(b, &sp, 0x878A);
	Z80_SP(b->cpu) = sp;
	choose_path(b, 0x87F8);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);

	hl = (uint16_t)(Z80_HL(b->cpu) + 1u);
	a = board_mem_read(b, hl);
	hl = (uint16_t)(hl + 1u);
	Z80_DE(b->cpu) = (uint16_t)(((uint16_t)board_mem_read(b, hl) << 8) | a);
	write_word(b, 0x4DD2, Z80_DE(b->cpu));
	Z80_HL(b->cpu) = hl;
}

/* The nibble of the path byte selects the next bounce index. */
static void step_path(Board *b, uint8_t idx, uint8_t old_b, uint8_t old_lo)
{
	uint8_t flags = 0;
	uint8_t a = (uint8_t)(idx & 0x03u);
	uint8_t c;
	uint8_t n;
	uint16_t hl = read_word(b, 0x4C42);
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t ch = board_mem_read(b, 0x4EBC);

	board_mem_write(b, 0x4EBC, (uint8_t)(ch | 0x20u));
	c = rst10(b, &hl, (uint8_t)(idx >> 2), &flags);
	push_word(b, &sp, 0x872F);
	if (a != 0) {
		do {
			c = (uint8_t)(c >> 1);
			c = (uint8_t)(c >> 1);
			a = (uint8_t)(a - 1u);
		} while (a != 0);
	}
	a = (uint8_t)(c & 0x03u);
	flags = and_a_flags(a);
	for (n = 0; n < 4u; n++)
		a = rlca(a, &flags);
	board_mem_write(b, 0x4C41, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = old_b;
	Z80_C(b->cpu) = c;
	Z80_D(b->cpu) = idx;
	Z80_E(b->cpu) = old_lo;
	Z80_HL(b->cpu) = hl;
}

/* j_87b5. The path index went negative after a bounce. */
static void exit_path(Board *b, uint8_t old_b, uint16_t new_pos, uint16_t old_pos)
{
	uint8_t flags = 0;
	uint8_t a = add_a(board_mem_read(b, 0x4DD3), 0x20, &flags);
	uint16_t hl;

	flags = cp_flags(a, 0x40);
	if ((flags & 0x01u) != 0) {
		board_mem_write(b, 0x4C0D, 0);
		Z80_HL(b->cpu) = new_pos;
		Z80_DE(b->cpu) = old_pos;
		Z80_B(b->cpu) = old_b;
		j_1000(b);
		return;
	}

	hl = read_word(b, 0x4C42);
	flags = sbc_hl(&hl, 0x8808);
	if (hl != 0) {
		write_word(b, 0x4C42, 0x8808);
		board_mem_write(b, 0x4C40, 0x1D);
		board_mem_write(b, 0x4C41, 0x1F);
		Z80_A(b->cpu) = 0x1F;
		Z80_F(b->cpu) = flags;
		Z80_HL(b->cpu) = 0x8808;
		Z80_DE(b->cpu) = 0x8808;
		Z80_B(b->cpu) = old_b;
		return;
	}

	choose_path(b, 0x8800);
}

/* Word at (table + 2 * B), with the double done in 8 bits. */
static uint16_t rst18_delta(Board *b, uint16_t table, uint8_t index)
{
	uint8_t flags = 0;
	uint8_t doubled = add_a(index, index, &flags);
	uint16_t hl = table;
	uint8_t low = rst10(b, &hl, doubled, &flags);
	uint8_t high;

	hl = (uint16_t)(hl + 1u);
	high = board_mem_read(b, hl);
	return (uint16_t)(((uint16_t)high << 8) | low);
}

/* j_0ead  advance or release the fruit
 * Entry:    JP at $0EAD into j_86ee. ($4DA4) = pending eaten ghosts.
 *           ($4DD4) = fruit points, 0 when no fruit is out.
 *           ($4DD2) = fruit position. ($4C41) = bounce index.
 *           ($4C40) = path index. ($4C42) = path pointer.
 *           ($4E0E) = dots eaten. ($4E0C) and ($4E0D) = fruit released.
 *           ($4E13) = level, counting from 0.
 * Exit:     One frame of the fruit routine at $86EE.
 *           While a fruit is on screen and the bounce nibble is not 0:
 *           position += the word at $8841 + 2 * index, the index increments,
 *           A is that index masked with $0F, F is `and`, B is the old index,
 *           HL = $4C41, DE is the old position. The new position is stored.
 *           The stack bytes below SP are the rst $18 return $8709 and,
 *           under it, the rst $10 return $001B.
 *           A finished path step leaves A as four `rlca` of the path
 *           nibble, F from that `and`/`rlca`, and $872F in place of $8709.
 *           Releasing a fruit stores its sprite, color, points, path, and
 *           position. A = $1F and F is the path table's rst $10.
 *           `ld a, r` at $8768 and $87D2 reads the next generator byte.
 *           Host finishes the RET.
 * Clobbers: A, F, and BC, DE, HL once a fruit moves or is released
 * Flags live-out: none. The caller returns immediately.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the rst and the path-table call, both returned. j_94bd is C.
 */
void j_0ead(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA4);
	uint8_t flags = and_a_flags(a);
	uint8_t breg;
	uint8_t idx;
	uint16_t delta;
	uint16_t de;
	uint16_t hl;
	uint16_t sp;

	if (a != 0) {
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		return;
	}

	a = board_mem_read(b, 0x4DD4);
	flags = and_a_flags(a);
	if (a == 0) {
		release_fruit(b);
		return;
	}

	a = board_mem_read(b, 0x4DD2);
	flags = and_a_flags(a);
	if (a == 0) {
		release_fruit(b);
		return;
	}

	breg = board_mem_read(b, 0x4C41);
	sp = Z80_SP(b->cpu);
	push_word(b, &sp, 0x8709);
	push_word(b, &sp, 0x001B);
	delta = rst18_delta(b, 0x8841, breg);
	de = read_word(b, 0x4DD2);
	hl = (uint16_t)(delta + de);
	write_word(b, 0x4DD2, hl);
	a = (uint8_t)(breg + 1u);
	board_mem_write(b, 0x4C41, a);
	a = (uint8_t)(a & 0x0Fu);
	flags = and_a_flags(a);
	if (a != 0) {
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		Z80_B(b->cpu) = breg;
		Z80_HL(b->cpu) = 0x4C41;
		Z80_DE(b->cpu) = de;
		return;
	}

	idx = (uint8_t)(board_mem_read(b, 0x4C40) - 1u);
	board_mem_write(b, 0x4C40, idx);
	if ((idx & 0x80u) != 0)
		exit_path(b, breg, hl, de);
	else
		step_path(b, idx, breg, (uint8_t)de);
}
