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
