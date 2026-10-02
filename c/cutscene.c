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

/* j_162d  second-cutscene sprite tweak
 * Entry:    ($4E07) = cutscene state. IX = a sprite record.
 *           ($4D3A) = Ms. Pac-Man's tile X, used only when the state is nonzero.
 * Exit:     If the state is 0: A = 0, F is `and a`, nothing else changes.
 *           Otherwise D = the state. If tile X is $3D, (IX+$0B) = 0.
 *           If the state is below $0A, F is `cp $0A` and the call returns.
 *           At $0A or $0B, (IX+2) = $32 and (IX+3) = $1D, and F is `cp $0C`.
 *           At $0C or above, (IX+2) = $33 as well.
 *           Host finishes the RET.
 * Clobbers: A, F, and D once the state is nonzero
 * Flags live-out: none. The next call replaces A and F.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_162d(Board *b)
{
	uint8_t state = board_mem_read(b, 0x4E07);
	uint8_t flags = 0;
	uint8_t tile;
	uint16_t ix;

	Z80_A(b->cpu) = state;
	Z80_F(b->cpu) = and_a_flags(state);
	if (state == 0)
		return;
	Z80_D(b->cpu) = state;
	tile = sub_a(board_mem_read(b, 0x4D3A), 0x3D, &flags);
	ix = Z80_IX(b->cpu);
	if (tile == 0)
		board_mem_write(b, (uint16_t)(ix + 0x0Bu), 0);
	Z80_A(b->cpu) = state;
	Z80_F(b->cpu) = cp_flags(state, 0x0A);
	if (state < 0x0Au)
		return;
	board_mem_write(b, (uint16_t)(ix + 2u), 0x32);
	board_mem_write(b, (uint16_t)(ix + 3u), 0x1D);
	Z80_F(b->cpu) = cp_flags(state, 0x0C);
	if (state < 0x0Cu)
		return;
	board_mem_write(b, (uint16_t)(ix + 2u), 0x33);
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

/* j_039d  big-pac positions during the first cutscene
 * Entry:    ($4E06) = cutscene counter.
 * Exit:     If the counter is below 5: A = counter - 5, F is that `sub`,
 *           and nothing is drawn.
 *           Otherwise HL = ($4D08), B = 8, C = $10. The low byte is stored
 *           at $4D06 and $4DD2. That byte minus $10 is stored at $4D02 and
 *           $4D04. The high byte plus 8 is stored at $4D03 and $4D07.
 *           That sum minus $10 is stored at $4D05 and $4DD3. A and F are
 *           that last `sub`.
 *           Host finishes the RET.
 * Clobbers: A, F, and on the draw path B, C, HL
 * Flags live-out: none. The caller goes on to the next cutscene check.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_039d(Board *b)
{
	uint8_t flags = 0;
	uint8_t a = sub_a(board_mem_read(b, 0x4E06), 0x05, &flags);
	uint16_t hl;
	uint8_t low;
	uint8_t high;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) != 0)
		return;
	hl = board_mem_read(b, 0x4D08);
	hl = (uint16_t)(hl | (uint16_t)((uint16_t)board_mem_read(b, 0x4D09) << 8));
	Z80_HL(b->cpu) = hl;
	Z80_B(b->cpu) = 0x08;
	Z80_C(b->cpu) = 0x10;
	low = (uint8_t)hl;
	board_mem_write(b, 0x4D06, low);
	board_mem_write(b, 0x4DD2, low);
	low = sub_a(low, 0x10, &flags);
	board_mem_write(b, 0x4D02, low);
	board_mem_write(b, 0x4D04, low);
	high = add_a((uint8_t)(hl >> 8), 0x08, &flags);
	board_mem_write(b, 0x4D03, high);
	board_mem_write(b, 0x4D07, high);
	high = sub_a(high, 0x10, &flags);
	board_mem_write(b, 0x4D05, high);
	board_mem_write(b, 0x4DD3, high);
	Z80_A(b->cpu) = high;
	Z80_F(b->cpu) = flags;
}

/* `rrca`. S, Z, and P/V stay. Y and X come from the rotated byte. */
static uint8_t rrca(uint8_t a, uint8_t *flags)
{
	a = (uint8_t)((a >> 1) | (uint8_t)((a & 1u) << 7));
	*flags = (uint8_t)((*flags & 0xC4u) | (a & 0x28u) | (a >> 7));
	return a;
}

/* `inc a`. C is unchanged. */
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

/* j_1652  third-cutscene sprite tweak
 * Entry:    ($4E08) = cutscene state. IX = a sprite record.
 *           ($4D3A) = tile X. ($4DC0) = animation phase. ($4D01) = red X.
 * Exit:     If the state is 0: A = 0, F is `and a`.
 *           Otherwise D = the state. If tile X is $3D, (IX+$0B) = 0.
 *           If the state is below 1: A = state, F is `cp 1`.
 *           Otherwise E = 8 and (IX+2) = phase + 8.
 *           If the state is below 3: A = state, F is `cp 3`.
 *           Otherwise E = $0A. (IX+$0C) = ((red X & 8) rotated right 3) + $0A.
 *           (IX+2) = that sum plus 2. (IX+$0D) = $1E. A is that sum plus 2.
 *           F is the second `inc a`.
 *           Host finishes the RET.
 * Clobbers: A, F, D, and E once the state is at least 1
 * Flags live-out: none. The next cutscene step replaces A and F.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee. The `jp` at $168C is the next routine.
 */
void j_1652(Board *b)
{
	uint16_t ix = Z80_IX(b->cpu);
	uint8_t state = board_mem_read(b, 0x4E08);
	uint8_t flags = and_a_flags(state);
	uint8_t a;
	uint8_t diff;

	Z80_A(b->cpu) = state;
	Z80_F(b->cpu) = flags;
	if (state == 0)
		return;
	Z80_D(b->cpu) = state;
	diff = sub_a(board_mem_read(b, 0x4D3A), 0x3D, &flags);
	if (diff == 0)
		board_mem_write(b, (uint16_t)(ix + 0x0Bu), 0);
	flags = cp_flags(state, 0x01);
	Z80_A(b->cpu) = state;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) != 0)
		return;
	a = add_a(board_mem_read(b, 0x4DC0), 0x08, &flags);
	Z80_E(b->cpu) = 0x08;
	board_mem_write(b, (uint16_t)(ix + 2u), a);
	flags = cp_flags(state, 0x03);
	Z80_A(b->cpu) = state;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) != 0)
		return;
	a = (uint8_t)(board_mem_read(b, 0x4D01) & 0x08u);
	flags = and_a_flags(a);
	a = rrca(a, &flags);
	a = rrca(a, &flags);
	a = rrca(a, &flags);
	Z80_E(b->cpu) = 0x0A;
	a = add_a(a, 0x0A, &flags);
	board_mem_write(b, (uint16_t)(ix + 0x0Cu), a);
	flags = inc_a_flags(a, flags, &a);
	flags = inc_a_flags(a, flags, &a);
	board_mem_write(b, (uint16_t)(ix + 2u), a);
	board_mem_write(b, (uint16_t)(ix + 0x0Du), 0x1E);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
}

/* j_15e6  big-pac sprite tiles during the first cutscene
 * Entry:    ($4E06) = cutscene state. IX = a sprite record.
 *           ($4D09) = pac X, used only when the state is at least 5.
 * Exit:     If the state is below 5: A = state - 5, F is that `sub`.
 *           Otherwise A = pac X & $0F. D ends as $16.
 *           (IX+4), (IX+6), (IX+8), and (IX+$0C) are a run of four
 *           tiles starting at $18, $14, or $10, chosen from the nibble.
 *           (IX+$0A) = $3F. (IX+5), (IX+7), (IX+9), and (IX+$0D) are $16.
 *           F is the third `inc d`. Its carry is set only when the nibble
 *           was below 4.
 *           Host finishes the RET.
 * Clobbers: A, F, and D when the tiles are written
 * Flags live-out: none. The next cutscene check replaces A and F.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_15e6(Board *b)
{
	uint8_t state = board_mem_read(b, 0x4E06);
	uint8_t flags = 0;
	uint8_t a = sub_a(state, 0x05, &flags);
	uint16_t ix;
	uint8_t nibble;
	uint8_t tile;
	uint8_t carry;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) != 0)
		return;
	nibble = (uint8_t)(board_mem_read(b, 0x4D09) & 0x0Fu);
	if (nibble >= 0x0Cu) {
		tile = 0x18;
		carry = 0;
	} else if (nibble >= 0x08u) {
		tile = 0x14;
		carry = 0;
	} else if (nibble >= 0x04u) {
		tile = 0x10;
		carry = 0;
	} else {
		tile = 0x14;
		carry = 1;
	}
	ix = Z80_IX(b->cpu);
	board_mem_write(b, (uint16_t)(ix + 4u), tile);
	flags = inc_a_flags(tile, carry, &tile);
	board_mem_write(b, (uint16_t)(ix + 6u), tile);
	flags = inc_a_flags(tile, flags, &tile);
	board_mem_write(b, (uint16_t)(ix + 8u), tile);
	flags = inc_a_flags(tile, flags, &tile);
	board_mem_write(b, (uint16_t)(ix + 0x0Cu), tile);
	board_mem_write(b, (uint16_t)(ix + 0x0Au), 0x3F);
	board_mem_write(b, (uint16_t)(ix + 5u), 0x16);
	board_mem_write(b, (uint16_t)(ix + 7u), 0x16);
	board_mem_write(b, (uint16_t)(ix + 9u), 0x16);
	board_mem_write(b, (uint16_t)(ix + 0x0Du), 0x16);
	Z80_A(b->cpu) = nibble;
	Z80_D(b->cpu) = 0x16;
	Z80_F(b->cpu) = flags;
}

/* j_212b  advance the first cutscene
 * Entry:    timed task 7.
 * Exit:     ($4E06) increases by one. HL = $4E06.
 *           F is that `inc (hl)`. A, BC, and DE are unchanged.
 *           Host finishes the RET.
 * Clobbers: F, HL
 * Flags live-out: Z when the state wraps to 0.
 * Interrupt: not reached on testplay2.
 * Stack: normal RET. No callee.
 */
void j_212b(Board *b)
{
	uint8_t cur = board_mem_read(b, 0x4E06);
	uint8_t next;
	uint8_t flags = inc_a_flags(cur, Z80_F(b->cpu), &next);

	board_mem_write(b, 0x4E06, next);
	Z80_HL(b->cpu) = 0x4E06;
	Z80_F(b->cpu) = flags;
}

/* j_21f0  advance the second cutscene
 * Entry:    timed task 8.
 * Exit:     ($4E07) increases by one. HL = $4E07.
 *           F is that `inc (hl)`. A, BC, and DE are unchanged.
 *           Host finishes the RET.
 * Clobbers: F, HL
 * Flags live-out: Z when the state wraps to 0.
 * Interrupt: not reached on testplay2.
 * Stack: normal RET. No callee.
 */
void j_21f0(Board *b)
{
	uint8_t cur = board_mem_read(b, 0x4E07);
	uint8_t next;
	uint8_t flags = inc_a_flags(cur, Z80_F(b->cpu), &next);

	board_mem_write(b, 0x4E07, next);
	Z80_HL(b->cpu) = 0x4E07;
	Z80_F(b->cpu) = flags;
}

/* j_22b9  advance the third cutscene
 * Entry:    timed task 9.
 * Exit:     ($4E08) increases by one. HL = $4E08.
 *           F is that `inc (hl)`. A, BC, and DE are unchanged.
 *           Host finishes the RET.
 * Clobbers: F, HL
 * Flags live-out: Z when the state wraps to 0.
 * Interrupt: not reached on testplay2.
 * Stack: normal RET. No callee.
 */
void j_22b9(Board *b)
{
	uint8_t cur = board_mem_read(b, 0x4E08);
	uint8_t next;
	uint8_t flags = inc_a_flags(cur, Z80_F(b->cpu), &next);

	board_mem_write(b, 0x4E08, next);
	Z80_HL(b->cpu) = 0x4E08;
	Z80_F(b->cpu) = flags;
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

/* `add hl, ss`. S, Z, and P/V stay. N is cleared. */
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

static void push(Board *b, uint16_t value)
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, value);
	Z80_SP(b->cpu) = sp;
}

static uint16_t pop_word(Board *b)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t value = word_at(b, sp);

	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	return value;
}

static void call_lifted(Board *b, uint16_t ret, void (*fn)(Board *))
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, ret);
	Z80_SP(b->cpu) = sp;
	fn(b);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
}

/* `rst $10`. HL = HL + A, A = (HL). F is the `adc a, h`.
 * The return address is left at SP-2. */
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

/* `rst $18`. HL = word at (HL + 2*B). DE = address of that word's
 * high byte. The rst $10 inside plants $001B at SP-4. */
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
	Z80_SP(b->cpu) = sp;
	for (i = 0; i < n; i++) {
		board_mem_write(b, hl, a);
		hl = (uint16_t)(hl + 1u);
	}
	Z80_HL(b->cpu) = hl;
	Z80_B(b->cpu) = 0;
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
}

/* j_2195  queue the level-state timer and advance it
 * Entry:    the animation END path when game_mode_sub1 is 0.
 * Exit:     Bytes $45, $00, $00 are copied into the first free
 *           timed-task slot. ($4E04) increases by one. HL = $4E04.
 *           A is the last copied byte ($00) when a slot was free.
 *           B = 0. DE is that slot plus 3. F is the `inc (hl)`,
 *           with carry clear. C and IX are unchanged.
 *           Host finishes the RET.
 * Clobbers: A, F, B, DE, HL
 * Flags live-out: Z when the level state wraps to 0.
 * Interrupt: returns inside the frame budget.
 * Stack: `rst $30` leaves $2196 under SP.
 */
void j_2195(Board *b)
{
	uint16_t data = 0x2196;
	uint16_t de = 0x4C90;
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t left = 0x10;
	uint8_t a = 0;
	uint8_t e;
	uint8_t i;
	int found = 0;
	uint8_t cur;
	uint8_t next;
	uint8_t flags;

	push_word(b, &sp, data);
	for (;;) {
		a = board_mem_read(b, de);
		if (a == 0) {
			found = 1;
			break;
		}
		e = (uint8_t)(de + 1u);
		e = (uint8_t)(e + 1u);
		e = (uint8_t)(e + 1u);
		de = (uint16_t)((de & 0xFF00u) | e);
		left--;
		if (left == 0)
			break;
	}
	sp = (uint16_t)(sp + 2u);
	Z80_SP(b->cpu) = sp;
	Z80_A(b->cpu) = a;
	Z80_DE(b->cpu) = de;
	if (!found) {
		Z80_B(b->cpu) = (uint8_t)Z80_HL(b->cpu);
	} else {
		e = (uint8_t)de;
		for (i = 0; i < 3u; i++) {
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
	}
	cur = board_mem_read(b, 0x4E04);
	flags = inc_a_flags(cur, 0, &next);
	board_mem_write(b, 0x4E04, next);
	Z80_HL(b->cpu) = 0x4E04;
	Z80_F(b->cpu) = flags;
}

/* j_3611  load one animation program
 * Entry:    C = table offset into the pointer list at $81F0.
 *           ($4E02) = game_mode_sub1.
 * Exit:     12 bytes are copied to $4F02. ($4F00) = 1.
 *           ($4DA4) = 1. ($4DA5) = 0. $14 zeros are stored from $4F1F.
 *           When sub1 is 0, ($4ECC) and ($4EDC) are 2.
 *           A = 0. B = 0. C = 0. DE = $4F0E. HL = $4F33.
 *           F is the `add hl,bc` of the table address.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: none. The caller fetches a command byte.
 * Interrupt: returns inside the frame budget.
 * Stack: `rst $08` leaves $3640 under SP.
 */
void j_3611(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4E02);
	uint8_t flags = and_a_flags(a);
	uint16_t hl = 0x81F0;
	uint16_t de;
	unsigned i;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		board_mem_write(b, 0x4ECC, 2);
		board_mem_write(b, 0x4EDC, 2);
		Z80_A(b->cpu) = 2;
	}
	Z80_B(b->cpu) = 0;
	flags = add_hl_flags(hl, Z80_C(b->cpu), flags, &hl);
	de = 0x4F02;
	for (i = 0; i < 12u; i++) {
		board_mem_write(b, de, board_mem_read(b, hl));
		de = (uint16_t)(de + 1u);
		hl = (uint16_t)(hl + 1u);
	}
	Z80_BC(b->cpu) = 0;
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
	board_mem_write(b, 0x4F00, 1);
	board_mem_write(b, 0x4DA4, 1);
	Z80_HL(b->cpu) = 0x4F1F;
	Z80_A(b->cpu) = 0;
	board_mem_write(b, 0x4DA5, 0);
	Z80_B(b->cpu) = 0x14;
	rst08(b, 0x3640);
}

extern void j_3556(Board *b);
extern void j_3641(Board *b);
extern void j_0042(Board *b);
extern void j_058e(Board *b);

/* F1 and F3 share this. DE is the word to store. The table base is
 * under SP. Leaves DE = 3 and F from `rst $18`. */
static void store_pair(Board *b)
{
	uint16_t pos;
	uint16_t hl;

	Z80_HL(b->cpu) = pop_word(b);
	pos = Z80_DE(b->cpu);
	push(b, pos);
	rst18(b, 0x358D);
	pos = pop_word(b);
	hl = Z80_DE(b->cpu);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = pos;
	board_mem_write(b, hl, (uint8_t)(pos >> 8));
	hl = (uint16_t)(hl - 1u);
	Z80_HL(b->cpu) = hl;
	board_mem_write(b, hl, (uint8_t)pos);
	Z80_DE(b->cpu) = 3;
}

static void cmd_f0(Board *b, uint16_t script)
{
	uint8_t a;
	uint8_t c;
	uint8_t flags;
	uint16_t de;
	int spins;

	push(b, script);
	Z80_HL(b->cpu) = script;
	Z80_A(b->cpu) = 1;
	rst10(b, 0x34E2);
	c = Z80_A(b->cpu);
	Z80_C(b->cpu) = c;
	Z80_HL(b->cpu) = 0x4F2E;
	rst18(b, 0x34E7);
	flags = 0;
	a = add_a(c, (uint8_t)(Z80_HL(b->cpu) >> 8), &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	call_lifted(b, 0x34EC, j_3556);
	board_mem_write(b, Z80_DE(b->cpu), Z80_A(b->cpu));
	call_lifted(b, 0x34F0, j_3641);
	rst18(b, 0x34F1);
	flags = 0;
	a = add_a((uint8_t)(Z80_HL(b->cpu) >> 8), Z80_C(b->cpu), &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	board_mem_write(b, Z80_DE(b->cpu), a);
	script = pop_word(b);
	push(b, script);
	Z80_HL(b->cpu) = script;
	Z80_A(b->cpu) = 2;
	rst10(b, 0x34F9);
	c = Z80_A(b->cpu);
	Z80_C(b->cpu) = c;
	Z80_HL(b->cpu) = 0x4F2E;
	rst18(b, 0x34FE);
	flags = 0;
	a = add_a(c, (uint8_t)Z80_HL(b->cpu), &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	call_lifted(b, 0x3503, j_3556);
	de = (uint16_t)(Z80_DE(b->cpu) - 1u);
	Z80_DE(b->cpu) = de;
	board_mem_write(b, de, Z80_A(b->cpu));
	call_lifted(b, 0x3508, j_3641);
	rst18(b, 0x3509);
	flags = 0;
	a = add_a((uint8_t)Z80_HL(b->cpu), Z80_C(b->cpu), &flags);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	de = (uint16_t)(Z80_DE(b->cpu) - 1u);
	Z80_DE(b->cpu) = de;
	board_mem_write(b, de, a);
	Z80_HL(b->cpu) = 0x4F0F;
	Z80_A(b->cpu) = Z80_B(b->cpu);
	rst10(b, 0x3512);
	push(b, Z80_HL(b->cpu));
	a = Z80_A(b->cpu);
	flags = inc_a_flags(a, Z80_F(b->cpu), &a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	c = a;
	Z80_C(b->cpu) = c;
	for (spins = 0; spins < 4; spins++) {
		Z80_HL(b->cpu) = 0x4F3E;
		rst18(b, 0x3519);
		a = (uint8_t)((c >> 1) | (c & 0x80u));
		Z80_A(b->cpu) = a;
		rst10(b, 0x351D);
		a = Z80_A(b->cpu);
		Z80_F(b->cpu) = cp_flags(a, 0xFF);
		if (a != 0xFF)
			break;
		c = 0;
		Z80_C(b->cpu) = 0;
	}
	de = pop_word(b);
	board_mem_write(b, de, c);
	Z80_HL(b->cpu) = de;
	de = (uint16_t)((Z80_DE(b->cpu) & 0xFF00u) | a);
	Z80_DE(b->cpu) = de;
	script = pop_word(b);
	Z80_HL(b->cpu) = script;
	Z80_A(b->cpu) = 3;
	rst10(b, 0x352D);
	de = (uint16_t)(((uint16_t)Z80_A(b->cpu) << 8) |
			(uint8_t)Z80_DE(b->cpu));
	Z80_DE(b->cpu) = de;
	push(b, de);
	Z80_HL(b->cpu) = 0x4F4E;
	rst18(b, 0x3533);
	de = pop_word(b);
	Z80_HL(b->cpu) = Z80_DE(b->cpu);
	Z80_DE(b->cpu) = de;
	board_mem_write(b, Z80_HL(b->cpu), (uint8_t)(de >> 8));
	Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) - 1u);
	a = board_mem_read(b, 0x4E09);
	Z80_A(b->cpu) = a;
	Z80_C(b->cpu) = a;
	a = (uint8_t)(board_mem_read(b, 0x4E72) & a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	if (a != 0) {
		a = (uint8_t)(0xC0u ^ (uint8_t)Z80_DE(b->cpu));
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = xor_flags(a);
		Z80_DE(b->cpu) = (uint16_t)((Z80_DE(b->cpu) & 0xFF00u) | a);
	}
	board_mem_write(b, Z80_HL(b->cpu), (uint8_t)Z80_DE(b->cpu));
	Z80_HL(b->cpu) = 0x4F17;
	Z80_A(b->cpu) = Z80_B(b->cpu);
	rst10(b, 0x354B);
	a = Z80_A(b->cpu);
	flags = dec_r(a, Z80_F(b->cpu), &a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	board_mem_write(b, Z80_HL(b->cpu), a);
	if (a != 0) {
		Z80_DE(b->cpu) = 0;
		return;
	}
	Z80_DE(b->cpu) = 4;
}

static void cmd_f1(Board *b, uint16_t script)
{
	uint16_t hl;
	uint8_t d;
	uint8_t e;

	Z80_DE(b->cpu) = script;
	call_lifted(b, 0x356F, j_3641);
	hl = Z80_DE(b->cpu);
	Z80_DE(b->cpu) = Z80_HL(b->cpu);
	Z80_HL(b->cpu) = hl;
	push(b, Z80_DE(b->cpu));
	hl = (uint16_t)(script + 1u);
	d = board_mem_read(b, hl);
	hl = (uint16_t)(hl + 1u);
	e = board_mem_read(b, hl);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = (uint16_t)(((uint16_t)d << 8) | e);
	store_pair(b);
}

static void cmd_f2(Board *b, uint16_t script)
{
	uint16_t hl = (uint16_t)(script + 1u);
	uint8_t c = board_mem_read(b, hl);

	Z80_HL(b->cpu) = hl;
	Z80_C(b->cpu) = c;
	Z80_HL(b->cpu) = 0x4F17;
	Z80_A(b->cpu) = Z80_B(b->cpu);
	rst10(b, 0x359E);
	board_mem_write(b, Z80_HL(b->cpu), c);
	Z80_DE(b->cpu) = 2;
}

static void cmd_f3(Board *b, uint16_t script)
{
	uint16_t hl;
	uint8_t d;
	uint8_t e;

	Z80_HL(b->cpu) = 0x4F0F;
	Z80_A(b->cpu) = Z80_B(b->cpu);
	rst10(b, 0x357D);
	board_mem_write(b, Z80_HL(b->cpu), 0);
	hl = (uint16_t)(script + 1u);
	e = board_mem_read(b, hl);
	hl = (uint16_t)(hl + 1u);
	d = board_mem_read(b, hl);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = 0x4F3E;
	push(b, 0x4F3E);
	Z80_DE(b->cpu) = (uint16_t)(((uint16_t)d << 8) | e);
	store_pair(b);
}

static void cmd_f5(Board *b, uint16_t script)
{
	uint16_t hl = (uint16_t)(script + 1u);
	uint8_t a = board_mem_read(b, hl);

	Z80_HL(b->cpu) = hl;
	Z80_A(b->cpu) = a;
	board_mem_write(b, 0x4EBC, a);
	Z80_DE(b->cpu) = 2;
}

static void cmd_f6(Board *b)
{
	uint8_t a;
	uint8_t flags;

	Z80_HL(b->cpu) = 0x4F17;
	Z80_A(b->cpu) = Z80_B(b->cpu);
	rst10(b, 0x35A9);
	a = Z80_A(b->cpu);
	flags = dec_r(a, Z80_F(b->cpu), &a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	board_mem_write(b, Z80_HL(b->cpu), a);
	Z80_DE(b->cpu) = a == 0 ? 1u : 0u;
}

static void cmd_f7(Board *b)
{
	uint8_t saved = Z80_B(b->cpu);

	Z80_A(b->cpu) = saved;
	Z80_B(b->cpu) = 0x1C;
	Z80_C(b->cpu) = 0x30;
	call_lifted(b, 0x35F7, j_0042);
	Z80_B(b->cpu) = Z80_A(b->cpu);
	Z80_DE(b->cpu) = 1;
}

static void cmd_f8(Board *b)
{
	Z80_A(b->cpu) = 0x40;
	board_mem_write(b, 0x42AC, 0x40);
	Z80_DE(b->cpu) = 1;
}

/* 1 when this END leaves the interpreter. 0 when the pointer stays. */
static int cmd_ff(Board *b)
{
	uint16_t hl = 0x4F20;
	uint8_t a;
	uint8_t flags = 0;
	int i;

	Z80_HL(b->cpu) = 0x4F1F;
	Z80_A(b->cpu) = Z80_B(b->cpu);
	rst10(b, 0x35D0);
	board_mem_write(b, Z80_HL(b->cpu), 1);
	a = board_mem_read(b, hl);
	for (i = 0; i < 5; i++) {
		hl = (uint16_t)(hl + 1u);
		a = (uint8_t)(a & board_mem_read(b, hl));
		flags = and_a_flags(a);
	}
	hl = (uint16_t)(hl + 1u);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = 0;
	if (a == 0)
		return 0;
	a = board_mem_read(b, 0x4E02);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		j_2195(b);
		return 1;
	}
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	board_mem_write(b, 0x4F00, 0);
	j_058e(b);
	return 1;
}

/* Add DE to the program pointer at IX, then step to the next actor. */
static int finish_actor(Board *b, uint16_t adv)
{
	uint16_t ix = Z80_IX(b->cpu);
	uint16_t hl = word_at(b, ix);
	uint8_t flags = add_hl_flags(hl, adv, Z80_F(b->cpu), &hl);
	uint8_t breg = (uint8_t)(Z80_B(b->cpu) - 1u);

	board_mem_write(b, ix, (uint8_t)hl);
	board_mem_write(b, (uint16_t)(ix + 1u), (uint8_t)(hl >> 8));
	Z80_IX(b->cpu) = (uint16_t)(ix - 2u);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = adv;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = breg;
	return breg != 0;
}

/* j_349c  one step of an intermission or attract animation
 * Entry:    C = offset of a 6-pointer program at $81F0, unless
 *           ($4F00) is already 1 and the program is loaded.
 * Exit:     Each of the six actors runs one command. The program
 *           pointers live at $4F02. A finished program clears
 *           ($4F00) and advances ($4E02), or queues the level-state
 *           timer when ($4E02) is 0.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX
 * Flags live-out: `add hl,de` on a command step, or the tail's flags
 *           when a program ends.
 * Interrupt: returns inside the frame budget.
 * Stack: the command that ran last leaves its rst and call returns.
 */
void j_349c(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4F00);
	uint8_t flags = and_a_flags(a);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0)
		call_lifted(b, 0x34A3, j_3611);
	Z80_B(b->cpu) = 6;
	Z80_IX(b->cpu) = 0x4F0C;
	for (;;) {
		uint16_t hl = word_at(b, Z80_IX(b->cpu));
		uint8_t op;

		Z80_HL(b->cpu) = hl;
		op = board_mem_read(b, hl);
		Z80_A(b->cpu) = op;
		if (op == 0xFF) {
			if (cmd_ff(b))
				return;
			if (!finish_actor(b, 0))
				return;
			continue;
		}
		Z80_F(b->cpu) = cp_flags(op, op);
		switch (op) {
		case 0xF0:
			cmd_f0(b, hl);
			break;
		case 0xF1:
			cmd_f1(b, hl);
			break;
		case 0xF2:
			cmd_f2(b, hl);
			break;
		case 0xF3:
			cmd_f3(b, hl);
			break;
		case 0xF5:
			cmd_f5(b, hl);
			break;
		case 0xF6:
			cmd_f6(b);
			break;
		case 0xF7:
			cmd_f7(b);
			break;
		case 0xF8:
			cmd_f8(b);
			break;
		default:
			/* A non-command byte is HALT, and the next
			 * instruction is the F0 handler. */
			cmd_f0(b, hl);
			break;
		}
		if (!finish_actor(b, Z80_DE(b->cpu)))
			return;
	}
}

/* j_3483  attract: walk Blinky
 * Entry:    marquee subroutine 6.
 * Exit:     C = $24, then one step of j_349c.
 *           Host finishes the RET.
 * Clobbers: C, then whatever j_349c clobbers
 * Flags live-out: j_349c's.
 * Interrupt: returns inside the frame budget.
 * Stack: tail JP. One RET.
 */
void j_3483(Board *b)
{
	Z80_C(b->cpu) = 0x24;
	j_349c(b);
}

/* j_3488  attract: walk Pinky
 * Entry:    marquee subroutine 8.
 * Exit:     C = $30, then one step of j_349c.
 *           Host finishes the RET.
 * Clobbers: C, then whatever j_349c clobbers
 * Flags live-out: j_349c's.
 * Interrupt: returns inside the frame budget.
 * Stack: tail JP. One RET.
 */
void j_3488(Board *b)
{
	Z80_C(b->cpu) = 0x30;
	j_349c(b);
}

/* j_348d  attract: walk Inky
 * Entry:    marquee subroutine 10.
 * Exit:     C = $3C, then one step of j_349c.
 *           Host finishes the RET.
 * Clobbers: C, then whatever j_349c clobbers
 * Flags live-out: j_349c's.
 * Interrupt: returns inside the frame budget.
 * Stack: tail JP. One RET.
 */
void j_348d(Board *b)
{
	Z80_C(b->cpu) = 0x3C;
	j_349c(b);
}

/* j_3492  attract: walk Sue
 * Entry:    marquee subroutine 12.
 * Exit:     C = $48, then one step of j_349c.
 *           Host finishes the RET.
 * Clobbers: C, then whatever j_349c clobbers
 * Flags live-out: j_349c's.
 * Interrupt: returns inside the frame budget.
 * Stack: tail JP. One RET.
 */
void j_3492(Board *b)
{
	Z80_C(b->cpu) = 0x48;
	j_349c(b);
}

/* j_3497  attract: walk Ms. Pac-Man
 * Entry:    marquee subroutine 15.
 * Exit:     C = $54, then one step of j_349c.
 *           Host finishes the RET.
 * Clobbers: C, then whatever j_349c clobbers
 * Flags live-out: j_349c's.
 * Interrupt: returns inside the frame budget.
 * Stack: tail JP. One RET.
 */
void j_3497(Board *b)
{
	Z80_C(b->cpu) = 0x54;
	j_349c(b);
}
