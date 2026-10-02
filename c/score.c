#include "lift.h"

/* Even parity sets P/V, matching the core's parity table for `and a`. */
static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

/* j_2b0b  point HL at the current player's score
 * Entry:    player number at $4E09 (0 = player 1, nonzero = player 2).
 * Exit:     A = that byte. HL = $4E80 for player 1, $4E84 otherwise.
 *           F is the `and a` result: H set, N clear, P/V = parity of A,
 *           Z set when A is 0, S/Y/X copied from A.
 *           Host finishes the RET.
 * Clobbers: A, F, HL
 * Flags live-out: none. Both callers overwrite A before they test flags.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_2b0b(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4E09);
	uint8_t flags = (uint8_t)(0x10u | parity_pv(a) | (a & 0xA8u));
	uint16_t hl = 0x4E80;

	if (a == 0)
		flags = (uint8_t)(flags | 0x40u);
	else
		hl = 0x4E84;
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = hl;
}

/* `and n` replaces A and F. H is set. N and C are clear. */
static uint8_t and_flags(uint8_t result)
{
	return (uint8_t)(0x10u | parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

/* `add a, n`. N is clear. Y and X come from the sum. */
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

/* j_2ace  draw one score digit and step left
 * Entry:    A = a score byte or its swapped nibbles. HL = screen cell.
 *           C is the leading-blank count ($04 or $06 at the first digit).
 * Exit:     The low nibble is drawn at (HL), then HL = HL - 1.
 *           A non-zero digit clears C and is drawn as itself.
 *           A zero with C = 0 is drawn as tile 0, and C stays 0.
 *           A zero with C != 0 is drawn as blank $40, and C = C - 1.
 *           F is `and $0F`, `and a`, or that `dec c`. The `dec c` sees
 *           carry clear.
 *           Host finishes the RET.
 * Clobbers: A, C, F, HL
 * Flags live-out: none. The caller draws the next digit with `ld a,(de)`
 *           and counts digits with `djnz`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_2ace(Board *b)
{
	uint8_t a = (uint8_t)(Z80_A(b->cpu) & 0x0Fu);
	uint8_t c = Z80_C(b->cpu);
	uint8_t flags;
	uint16_t hl = Z80_HL(b->cpu);

	if (a != 0) {
		flags = and_flags(a);
		c = 0;
	} else {
		a = c;
		flags = and_flags(a);
		if (a != 0) {
			uint8_t next = (uint8_t)(c - 1u);

			flags = (uint8_t)((next & 0xA8u) |
					  (next == 0 ? 0x40u : 0u) |
					  ((c ^ next) & 0x10u) |
					  (c == 0x80u ? 0x04u : 0u) |
					  0x02u);
			a = 0x40;
			c = next;
		}
	}
	board_mem_write(b, hl, a);
	Z80_A(b->cpu) = a;
	Z80_C(b->cpu) = c;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = (uint16_t)(hl - 1u);
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

/* j_2abe  draw three score bytes as six digits
 * Entry:    DE = address of the most significant score byte.
 *           HL = rightmost screen cell. B = digit-pair count (3 from
 *           the score task). C = leading-blank count for j_2ace.
 * Exit:     Six digits are drawn, right to left. B = 0. DE = DE - B.
 *           HL and C are whatever the last j_2ace left. F is that
 *           call's flags. A is the last digit tile.
 *           The stack bytes below SP hold the last ones-digit call
 *           ($2ACA). j_2ace pushes nothing, so each call overwrites
 *           the previous return address.
 *           Host finishes the RET.
 * Clobbers: A, B, C, F, DE, HL
 * Flags live-out: none. Callers return or overwrite F.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: two calls per digit pair, all returned. Callee is already C.
 */
void j_2abe(Board *b)
{
	uint8_t count = Z80_B(b->cpu);

	do {
		uint8_t score = board_mem_read(b, Z80_DE(b->cpu));

		Z80_A(b->cpu) = (uint8_t)((score >> 4) | (uint8_t)(score << 4));
		call_lifted(b, 0x2AC6, j_2ace);
		Z80_A(b->cpu) = board_mem_read(b, Z80_DE(b->cpu));
		call_lifted(b, 0x2ACA, j_2ace);
		Z80_DE(b->cpu) = (uint16_t)(Z80_DE(b->cpu) - 1u);
		count = (uint8_t)(count - 1u);
	} while (count != 0);
	Z80_B(b->cpu) = 0;
}

/* j_2aaf  draw the current player's score
 * Entry:    DE = address of that score's most significant byte.
 *           Player number is at $4E09.
 * Exit:     BC starts as $0304. HL is $43FC for player 1 and $43E9
 *           for player 2, then j_2abe walks it. A and F match j_2abe.
 *           The fall into j_2abe is a C call, not a Z80 CALL, so no
 *           extra return address is written for it.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, HL, and whatever j_2abe clobbers
 * Flags live-out: none.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the calls inside j_2abe. No other callee.
 */
void j_2aaf(Board *b)
{
	uint8_t player = board_mem_read(b, 0x4E09);

	Z80_BC(b->cpu) = 0x0304;
	Z80_HL(b->cpu) = player == 0 ? 0x43FCu : 0x43E9u;
	Z80_A(b->cpu) = player;
	Z80_F(b->cpu) = and_flags(player);
	j_2abe(b);
}

extern void j_2b8f(Board *b);
extern void j_2b7e(Board *b);

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

/* `dec r`. N is set. C stays. P/V is set only when the old value is $80. */
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

/* `inc (hl)`. N is clear. C stays. P/V is set only when the old value is $7F. */
static uint8_t inc_mem(Board *b, uint16_t addr, uint8_t flags)
{
	uint8_t value = board_mem_read(b, addr);
	uint8_t result = (uint8_t)(value + 1u);

	board_mem_write(b, addr, result);
	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x7Fu ? 0x04u : 0u) |
			 (flags & 0x01u));
}

/* `bit 0,(hl)`. Y and X come from MEMPTR's high byte. C stays. H is set. */
static uint8_t bit0_hl_flags(Board *b, uint16_t hl, uint8_t flags)
{
	uint8_t t = (uint8_t)(board_mem_read(b, hl) & 0x01u);
	uint8_t memptr_h = (uint8_t)(Z80_MEMPTR(b->cpu) >> 8);

	return (uint8_t)((t != 0 ? 0u : 0x44u) | (memptr_h & 0x28u) | 0x10u |
			 (flags & 0x01u));
}

/* Draw the life icons at $401A, then blank the rest of the five slots. */
static void draw_lives(Board *b)
{
	uint8_t breg = Z80_B(b->cpu);
	uint8_t c = 5;
	uint8_t flags;
	uint16_t hl = 0x401A;

	Z80_HL(b->cpu) = hl;
	Z80_C(b->cpu) = c;
	Z80_A(b->cpu) = breg;
	flags = and_flags(breg);
	Z80_F(b->cpu) = flags;
	if (breg != 0) {
		flags = cp_flags(breg, 0x06);
		Z80_F(b->cpu) = flags;
		if ((flags & 0x01u) != 0) {
			while (breg != 0) {
				Z80_A(b->cpu) = 0x20;
				call_lifted(b, 0x2B5C, j_2b8f);
				hl = (uint16_t)(Z80_HL(b->cpu) - 2u);
				Z80_HL(b->cpu) = hl;
				flags = dec_flags(c, Z80_F(b->cpu), &c);
				Z80_C(b->cpu) = c;
				Z80_F(b->cpu) = flags;
				breg = (uint8_t)(breg - 1u);
			}
			Z80_B(b->cpu) = 0;
		}
	}
	for (;;) {
		flags = dec_flags(c, Z80_F(b->cpu), &c);
		Z80_C(b->cpu) = c;
		Z80_F(b->cpu) = flags;
		if ((flags & 0x80u) != 0)
			return;
		call_lifted(b, 0x2B66, j_2b7e);
		hl = (uint16_t)(Z80_HL(b->cpu) - 2u);
		Z80_HL(b->cpu) = hl;
	}
}

/* j_2b33  award one extra life, once
 * Entry:    DE points at the third byte of the player's score. The next
 *           byte's bit 0 is the "already awarded" flag. Carry is set.
 *           B is whatever the caller left.
 * Exit:     If that bit is already set: HL = DE+1, DE is unchanged,
 *           A is unchanged, and F is `bit 0,(hl)`.
 *           Otherwise the bit is set, sound $4E9C bit 0 is set, both
 *           life counters ($4E14 and $4E15) increment, and the bottom
 *           row shows up to five life tiles. A, F, B, C, and HL are
 *           whatever the last `dec c` or blank tile left. DE is unchanged.
 *           Host finishes the RET.
 * Clobbers: A, F, B, C, HL
 * Flags live-out: none. The caller draws the score next.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: each icon is a call to j_2b8f ($2B5C) and each blank is a call
 *        to j_2b7e ($2B66). Both callees leave HL and DE under that
 *        return. The last call is the one still visible.
 */
void j_2b33(Board *b)
{
	uint16_t de = Z80_DE(b->cpu);
	uint16_t hl = (uint16_t)(de + 1u);
	uint8_t flags = bit0_hl_flags(b, hl, Z80_F(b->cpu));
	uint8_t mem;

	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;

	mem = (uint8_t)(board_mem_read(b, hl) | 0x01u);
	board_mem_write(b, hl, mem);
	hl = 0x4E9C;
	mem = (uint8_t)(board_mem_read(b, hl) | 0x01u);
	board_mem_write(b, hl, mem);
	Z80_HL(b->cpu) = 0x4E14;
	flags = inc_mem(b, 0x4E14, flags);
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = 0x4E15;
	flags = inc_mem(b, 0x4E15, flags);
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = board_mem_read(b, 0x4E15);
	draw_lives(b);
}

/* `add a` or `adc a`. N is clear. The carry-in is used only for `adc`. */
static uint8_t add_carry(uint8_t a, uint8_t rhs, uint8_t *flags, int with_carry)
{
	uint8_t cin = (with_carry && (*flags & 0x01u) != 0) ? 1u : 0u;
	uint16_t sum = (uint16_t)((uint16_t)a + rhs + cin);
	uint8_t result = (uint8_t)sum;
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ (uint8_t)~rhs) & (a ^ result)) &
				0x80u) >> 5);

	*flags = (uint8_t)((sum > 255u ? 1u : 0u) |
			   ov |
			   ((a ^ rhs ^ result) & 0x10u) |
			   (result & 0xA8u) |
			   (result == 0 ? 0x40u : 0u));
	return result;
}

/* `daa` after an add. N stays clear. Old carry stays set. */
static uint8_t daa(uint8_t a, uint8_t *flags)
{
	uint8_t f = *flags;
	uint8_t cf = a > 0x99u ? 1u : 0u;
	uint8_t corr = ((f & 0x10u) != 0 || (a & 0x0Fu) > 9u) ? 6u : 0u;
	uint8_t result;

	if ((f & 0x01u) != 0 || cf != 0)
		corr = (uint8_t)(corr | 0x60u);
	result = (uint8_t)(a + corr);
	*flags = (uint8_t)((f & 0x03u) |
			   (result & 0xA8u) |
			   (result == 0 ? 0x40u : 0u) |
			   ((a ^ result) & 0x10u) |
			   parity_pv(result) |
			   cf);
	return result;
}

/* `rst $18`: HL = the word at base + 2*index. DE points at its high byte.
 * The rst return and the inner `rst $10` return ($001B) stay below SP.
 */
static uint16_t rst18(Board *b, uint16_t base, uint16_t ret, uint8_t index)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t at = (uint16_t)(base + (uint16_t)((uint16_t)index << 1));
	uint8_t lo;
	uint8_t hi;

	push_word(b, &sp, ret);
	push_word(b, &sp, 0x001B);
	lo = board_mem_read(b, at);
	at = (uint16_t)(at + 1u);
	hi = board_mem_read(b, at);
	Z80_DE(b->cpu) = at;
	return (uint16_t)(((uint16_t)hi << 8) | lo);
}

/* Add one BCD byte plus carry, and store it. */
static uint8_t add_bcd(Board *b, uint16_t addr, uint8_t term, uint8_t *flags,
		       int with_carry)
{
	uint8_t a = add_carry(term, board_mem_read(b, addr), flags, with_carry);

	a = daa(a, flags);
	board_mem_write(b, addr, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = *flags;
	return a;
}

/* j_2a5a  add a table score and check the high score
 * Entry:    B = item code (0 = dot ... 13 = the last fruit). ($4E00) = mode.
 *           ($4E71) = bonus-life dip. The current score is three BCD bytes.
 * Exit:     In the demo (mode 1): A = 1, F is `cp #01`, nothing else changes.
 *           Otherwise the word at $2B17 + 2*B is added to the player's score.
 *           A crossing of the bonus threshold awards one life through j_2b33.
 *           The score is drawn. If it does not beat the high score, A and F
 *           are the digit compare that stopped the check, B counts the digits
 *           still uncompared, and DE/HL point at that pair.
 *           If it wins, the three score bytes are copied to $4E88 and the
 *           high score is drawn at $43F2 by falling into j_2abe. That fall
 *           is not a Z80 CALL.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: none. Callers return or start another task.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: `rst $18` leaves $001B under the following calls. j_2b0b ($2A68
 *        and, on a new high score, $2A9E), the conditional j_2b33 ($2A86),
 *        and j_2aaf ($2A89) each overwrite the return at SP-2.
 */
void j_2a5a(Board *b)
{
	uint8_t mode = board_mem_read(b, 0x4E00);
	uint8_t flags = cp_flags(mode, 0x01);
	uint16_t points;
	uint16_t hl;
	uint16_t de;
	uint16_t hs;
	uint8_t mid;
	uint8_t top;
	uint8_t a;
	uint8_t breg;

	Z80_A(b->cpu) = mode;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return;

	points = rst18(b, 0x2B17, 0x2A64, Z80_B(b->cpu));
	Z80_HL(b->cpu) = Z80_DE(b->cpu);
	Z80_DE(b->cpu) = points;
	call_lifted(b, 0x2A68, j_2b0b);
	hl = Z80_HL(b->cpu);
	de = Z80_DE(b->cpu);
	flags = 0;
	add_bcd(b, hl, (uint8_t)de, &flags, 0);
	hl = (uint16_t)(hl + 1u);
	mid = add_bcd(b, hl, (uint8_t)(de >> 8), &flags, 1);
	hl = (uint16_t)(hl + 1u);
	top = add_bcd(b, hl, 0, &flags, 1);
	Z80_DE(b->cpu) = hl;
	hl = (uint16_t)(((uint16_t)top << 8) | mid);
	hl = (uint16_t)(hl << 1);
	hl = (uint16_t)(hl << 1);
	hl = (uint16_t)(hl << 1);
	hl = (uint16_t)(hl << 1);
	Z80_HL(b->cpu) = hl;
	a = (uint8_t)(board_mem_read(b, 0x4E71) - 1u);
	flags = cp_flags(a, (uint8_t)(hl >> 8));
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) != 0)
		call_lifted(b, 0x2A86, j_2b33);
	call_lifted(b, 0x2A89, j_2aaf);
	de = (uint16_t)(Z80_DE(b->cpu) + 3u);
	hs = 0x4E8A;
	breg = 3;
	Z80_B(b->cpu) = breg;
	for (;;) {
		a = board_mem_read(b, de);
		flags = cp_flags(a, board_mem_read(b, hs));
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		Z80_DE(b->cpu) = de;
		Z80_HL(b->cpu) = hs;
		if ((flags & 0x01u) != 0)
			return;
		if ((flags & 0x40u) == 0)
			break;
		de = (uint16_t)(de - 1u);
		hs = (uint16_t)(hs - 1u);
		breg = (uint8_t)(breg - 1u);
		Z80_B(b->cpu) = breg;
		Z80_DE(b->cpu) = de;
		Z80_HL(b->cpu) = hs;
		if (breg == 0)
			return;
	}
	call_lifted(b, 0x2A9E, j_2b0b);
	hl = Z80_HL(b->cpu);
	de = 0x4E88;
	for (breg = 0; breg < 3u; breg++) {
		board_mem_write(b, de, board_mem_read(b, hl));
		hl = (uint16_t)(hl + 1u);
		de = (uint16_t)(de + 1u);
	}
	Z80_HL(b->cpu) = 0x43F2;
	Z80_DE(b->cpu) = 0x4E8A;
	Z80_BC(b->cpu) = 0x0304;
	j_2abe(b);
}

/* The body of j_2bcd: paint `rows` runs of `len` cells, stride $20.
 * The return address pushed here is the instruction after the inline
 * data, not the address the CALL itself pushed.
 */
static void fill_rows(Board *b, uint16_t at, uint8_t color, uint8_t len,
		      uint8_t rows, uint16_t ret)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t hl = at;
	uint16_t bc = (uint16_t)(((uint16_t)len << 8) | color);
	uint8_t left = rows;

	push_word(b, &sp, ret);
	do {
		uint16_t rowsp = sp;
		uint16_t cursor = hl;
		uint8_t n = len;

		push_word(b, &rowsp, hl);
		push_word(b, &rowsp, bc);
		do {
			board_mem_write(b, cursor, color);
			cursor = (uint16_t)(cursor + 1u);
			n = (uint8_t)(n - 1u);
		} while (n != 0);
		hl = (uint16_t)(hl + 0x20u);
		left = (uint8_t)(left - 1u);
	} while (left != 0);
	Z80_A(b->cpu) = 0;
	Z80_BC(b->cpu) = bc;
	Z80_DE(b->cpu) = 0x0020;
	Z80_HL(b->cpu) = hl;
}

/* j_2b6a  color the bottom rows and draw the extra lives
 * Entry:    ($4E00) = game mode. ($4E15) = lives to display.
 * Exit:     In the demo (mode 1): A = 1, F is `cp #01`, nothing else.
 *           Otherwise $4412 and $4432 each get ten $09 bytes. DE = $0020.
 *           B is the life count, then the same icon row as j_2b4a is drawn.
 *           A, F, C, and HL are whatever that row left.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: none. The caller returns or starts the next task.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: j_2bcd pops the call and pushes $2B78, the real continuation.
 *        The life icons then overwrite that image with their own calls.
 */
void j_2b6a(Board *b)
{
	uint8_t mode = board_mem_read(b, 0x4E00);
	uint8_t flags = cp_flags(mode, 0x01);

	Z80_A(b->cpu) = mode;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return;

	fill_rows(b, 0x4412, 0x09, 0x0A, 0x02, 0x2B78);
	Z80_HL(b->cpu) = 0x4E15;
	Z80_B(b->cpu) = board_mem_read(b, 0x4E15);
	draw_lives(b);
}

/* j_26b2  draw the bonus-life digits
 * Entry:    task $1F. ($4E71) is the bonus threshold, $10, $15, $20, or $FF.
 * Exit:     IX = $4136. The low digit is at $4136.
 *           A non-zero high nibble is also at $4156, and A and F are
 *           `add a, #$30` of that nibble. A zero high nibble returns
 *           with A = 0 and F from `and #$0F`.
 *           Host finishes the RET.
 * Clobbers: A, F, IX
 * Flags live-out: Z when there is no tens digit.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: normal RET. No callee.
 */
void j_26b2(Board *b)
{
	uint8_t bonus = board_mem_read(b, 0x4E71);
	uint8_t low = (uint8_t)(bonus & 0x0Fu);
	uint8_t high = (uint8_t)(bonus >> 4);
	uint8_t flags = 0;

	Z80_IX(b->cpu) = 0x4136;
	low = add_a(low, 0x30, &flags);
	board_mem_write(b, 0x4136, low);
	if (high == 0) {
		Z80_A(b->cpu) = 0;
		Z80_F(b->cpu) = and_flags(0);
		return;
	}
	high = add_a(high, 0x30, &flags);
	board_mem_write(b, 0x4156, high);
	Z80_A(b->cpu) = high;
	Z80_F(b->cpu) = flags;
}

static uint8_t rol8(uint8_t value)
{
	return (uint8_t)((uint8_t)(value << 1) | (uint8_t)(value >> 7));
}

static uint8_t ror8(uint8_t value)
{
	return (uint8_t)((value >> 1) | (uint8_t)((value & 1u) << 7));
}

/* j_26d0  read the DIP switches into the game settings
 * Entry:    task $14. DSW1 is $5080. IN1 is $5040.
 * Exit:     ($4E6E) = $FF when bits 0-1 are both off (free play).
 *           ($4E6B) is coins per credit. ($4E6D) is credits per coin.
 *           ($4E6F) is lives: bits 2-3 plus one, and 3 becomes 5.
 *           ($4E71) is the bonus byte from $2728 indexed by bits 4-5.
 *           ($4E75) is the inverse of bit 7. ($4E72) is the inverse of
 *           IN1 bit 7. ($4E73) is $0068 or $007D from the inverse of bit 6.
 *           A is the cocktail bit. F is `and #01` of it.
 *           B is the difficulty index. C is DSW1 bits 0-1.
 *           HL is the difficulty word. DE points at its high byte.
 *           The bytes under SP are the rst $18 return $271A and, under
 *           that, the rst $10 return $001B.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: Z when the cabinet is upright.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: two rsts, both returned. No callee.
 */
void j_26d0(Board *b)
{
	uint8_t dip = board_mem_read(b, 0x5080);
	uint8_t breg = dip;
	uint8_t a = (uint8_t)(dip & 0x03u);
	uint8_t creg = a;
	uint8_t flags = and_flags(a);
	uint8_t carry;
	uint16_t diff;
	int n;

	if (a == 0) {
		Z80_HL(b->cpu) = 0x4E6E;
		board_mem_write(b, 0x4E6E, 0xFF);
	}
	carry = (uint8_t)(a & 1u);
	a = (uint8_t)(a >> 1);
	flags = (uint8_t)((flags & 0xC4u) | (a & 0x28u) | carry);
	a = add_carry(a, 0, &flags, 1);
	board_mem_write(b, 0x4E6B, a);
	a = (uint8_t)(a & 0x02u);
	a = (uint8_t)(a ^ creg);
	board_mem_write(b, 0x4E6D, a);

	a = ror8(ror8(breg));
	a = (uint8_t)(a & 0x03u);
	a = (uint8_t)(a + 1u);
	if (a == 4)
		a = (uint8_t)(a + 1u);
	board_mem_write(b, 0x4E6F, a);

	a = breg;
	for (n = 0; n < 4; n++)
		a = ror8(a);
	a = (uint8_t)(a & 0x03u);
	board_mem_write(b, 0x4E71, board_mem_read(b, (uint16_t)(0x2728u + a)));

	a = (uint8_t)((uint8_t)~rol8(breg) & 0x01u);
	board_mem_write(b, 0x4E75, a);

	a = rol8(rol8(breg));
	breg = (uint8_t)((uint8_t)~a & 0x01u);
	diff = rst18(b, 0x272C, 0x271A, breg);
	board_mem_write(b, 0x4E73, (uint8_t)diff);
	board_mem_write(b, 0x4E74, (uint8_t)(diff >> 8));

	a = rol8(board_mem_read(b, 0x5040));
	a = (uint8_t)((uint8_t)~a & 0x01u);
	board_mem_write(b, 0x4E72, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_flags(a);
	Z80_B(b->cpu) = breg;
	Z80_C(b->cpu) = creg;
	Z80_HL(b->cpu) = diff;
}

/* `add ix,de`. S, Z, and P/V stay. Y and X come from the high byte. */
static uint8_t add16_flags(uint16_t lhs, uint16_t rhs, uint8_t flags,
			   uint16_t *out)
{
	uint32_t sum = (uint32_t)lhs + rhs;

	*out = (uint16_t)sum;
	return (uint8_t)((flags & 0xC4u) |
			 (((uint16_t)sum >> 8) & 0x28u) |
			 ((((lhs ^ rhs ^ sum) >> 8) & 0x10u)) |
			 ((sum >> 16) & 1u));
}

/* Plant a word below SP. The return address at SP stays put. */
static void plant_word(Board *b, uint16_t addr, uint16_t value)
{
	board_mem_write(b, addr, (uint8_t)value);
	board_mem_write(b, (uint16_t)(addr + 1u), (uint8_t)(value >> 8));
}

/* j_2c5e  draw or erase one message from the text table
 * Entry:    B = message number. Bit 7 selects erase (tile $40).
 * Exit:     Characters and colors are written. The step is -1 when
 *           the offset's high bit is set, otherwise -$20.
 *           A is the last color stored. F is the last `add ix,de`
 *           in the color loop; its S, Z, and P/V are the `and a` of
 *           the first color byte.
 *           IX is the color pointer after that loop. DE is the step.
 *           HL points at the single color byte, or just past the last
 *           multi-color byte. B is 0. C is 0 on a draw.
 *           The erase path's CPIR can leave C nonzero; the color
 *           loop does not change C.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX
 * Flags live-out: the last color-step add.
 * Interrupt: returns inside the frame budget. No frame ends inside it.
 * Stack: `rst $18` leaves $001B at SP-4. The saved color IX replaces
 *        the rst return at SP-2. SP itself is unchanged.
 */
void j_2c5e(Board *b)
{
	uint8_t index = Z80_B(b->cpu);
	uint16_t slot = (uint16_t)(0x36A5u + (uint8_t)(index << 1));
	uint16_t rec = (uint16_t)(board_mem_read(b, slot) |
				  (uint16_t)(board_mem_read(b, (uint16_t)(slot + 1u)) << 8));
	uint8_t off_lo = board_mem_read(b, rec);
	uint8_t off_hi = board_mem_read(b, (uint16_t)(rec + 1u));
	uint16_t color_ix = (uint16_t)(0x4400u +
				       (uint16_t)(off_lo | (uint16_t)(off_hi << 8)));
	uint16_t video = (uint16_t)(color_ix + 0xFC00u);
	uint16_t step = (off_hi & 0x80u) != 0 ? 0xFFFFu : 0xFFE0u;
	uint16_t hl = (uint16_t)(rec + 2u);
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t count = 0;
	uint8_t creg = 0;
	uint8_t color0;
	uint8_t flags;
	uint8_t a;
	unsigned left;

	plant_word(b, (uint16_t)(sp - 2u), color_ix);
	plant_word(b, (uint16_t)(sp - 4u), 0x001Bu);

	if ((index & 0x80u) != 0) {
		for (;;) {
			a = board_mem_read(b, hl);
			if (a == 0x2Fu)
				break;
			board_mem_write(b, video, 0x40);
			hl = (uint16_t)(hl + 1u);
			video = (uint16_t)(video + step);
			count = (uint8_t)(count + 1u);
		}
		hl = (uint16_t)(hl + 1u);
		count = (uint8_t)(count + 1u);
		{
			uint16_t bc = (uint16_t)(count << 8);

			a = 0x2F;
			for (;;) {
				uint8_t n = board_mem_read(b, hl);
				uint8_t diff = (uint8_t)(a - n);

				hl = (uint16_t)(hl + 1u);
				bc = (uint16_t)(bc - 1u);
				if (diff == 0 || bc == 0)
					break;
			}
			count = (uint8_t)(bc >> 8);
			creg = (uint8_t)bc;
		}
	} else {
		for (;;) {
			a = board_mem_read(b, hl);
			if (a == 0x2Fu)
				break;
			board_mem_write(b, video, a);
			hl = (uint16_t)(hl + 1u);
			video = (uint16_t)(video + step);
			count = (uint8_t)(count + 1u);
		}
		hl = (uint16_t)(hl + 1u);
	}

	color0 = board_mem_read(b, hl);
	flags = and_flags(color0);
	a = color0;
	left = count == 0 ? 256u : count;
	if ((color0 & 0x80u) != 0) {
		while (left != 0) {
			board_mem_write(b, color_ix, a);
			flags = add16_flags(color_ix, step, flags, &color_ix);
			left--;
		}
	} else {
		while (left != 0) {
			a = board_mem_read(b, hl);
			board_mem_write(b, color_ix, a);
			hl = (uint16_t)(hl + 1u);
			flags = add16_flags(color_ix, step, flags, &color_ix);
			left--;
		}
	}
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = 0;
	Z80_C(b->cpu) = creg;
	Z80_DE(b->cpu) = step;
	Z80_HL(b->cpu) = hl;
	Z80_IX(b->cpu) = color_ix;
}

/* j_2ae0  print HIGH SCORE and both score fields
 * Entry:    Task $18. Scores may hold a previous game.
 * Exit:     Message 0 is drawn. Eight bytes at $4E80 are zero.
 *           Player 1's score is drawn at $43FC with blank count 4.
 *           Player 2's score is drawn at $43E9. A 1-player game
 *           uses blank count 6; a 2-player game uses 4.
 *           Registers match the tail jump into j_2abe.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX
 * Flags live-out: j_2abe's last digit.
 * Interrupt: returns inside the frame budget.
 * Stack: the j_2c5e call, then `rst $08`, then one CALL of j_2abe.
 *        The second j_2abe is a jump, so it shares this frame.
 */
void j_2ae0(Board *b)
{
	uint8_t players;
	uint16_t i;

	Z80_B(b->cpu) = 0;
	call_lifted(b, 0x2AE5, j_2c5e);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	for (i = 0; i < 8; i++)
		board_mem_write(b, (uint16_t)(0x4E80u + i), 0);
	Z80_BC(b->cpu) = 0x0304;
	Z80_DE(b->cpu) = 0x4E82;
	Z80_HL(b->cpu) = 0x43FC;
	call_lifted(b, 0x2AF8, j_2abe);
	Z80_BC(b->cpu) = 0x0304;
	Z80_DE(b->cpu) = 0x4E86;
	Z80_HL(b->cpu) = 0x43E9;
	players = board_mem_read(b, 0x4E70);
	Z80_A(b->cpu) = players;
	Z80_F(b->cpu) = and_flags(players);
	if (players == 0)
		Z80_C(b->cpu) = 6;
	j_2abe(b);
}

/* j_2ba1  draw the credit counter or FREE PLAY
 * Entry:    Credits at $4E6E. $FF means free play.
 * Exit:     Free play tails into message 2. Otherwise message 1 is
 *           drawn, the ones digit is at $4033, and a tens digit is at
 *           $4034 when the credit count is 10 or more.
 *           A and F are the ones-digit `add $30`, or j_2c5e's result
 *           on the free-play tail. The other registers are j_2c5e's.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX
 * Flags live-out: the ones add, or the text routine on free play.
 * Interrupt: returns inside the frame budget.
 * Stack: one CALL of j_2c5e, unless free play jumps there.
 */
void j_2ba1(Board *b)
{
	uint8_t credits = board_mem_read(b, 0x4E6E);
	uint8_t flags;
	uint8_t a;

	if (credits == 0xFF) {
		Z80_B(b->cpu) = 2;
		j_2c5e(b);
		return;
	}
	Z80_B(b->cpu) = 1;
	call_lifted(b, 0x2BB2, j_2c5e);
	credits = board_mem_read(b, 0x4E6E);
	if ((credits & 0xF0u) != 0) {
		a = add_a((uint8_t)(credits >> 4), 0x30, &flags);
		board_mem_write(b, 0x4034, a);
	}
	credits = board_mem_read(b, 0x4E6E);
	a = add_a((uint8_t)(credits & 0x0Fu), 0x30, &flags);
	board_mem_write(b, 0x4033, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
}

extern void j_0042(Board *b);

/* `bit n,r`. H is set. N is clear. C stays. Z and P/V are set together
 * when the bit is clear. S is set only when the tested bit is bit 7. */
static uint8_t bit_reg(uint8_t value, unsigned bit, uint8_t flags)
{
	uint8_t t = (uint8_t)(value & (uint8_t)(1u << bit));

	return (uint8_t)((t != 0 ? (uint8_t)(t & 0x80u) : 0x44u) |
			 (value & 0x28u) |
			 0x10u |
			 (flags & 0x01u));
}

/* `inc r`. N is clear. C stays. P/V is set only when the old value is $7F. */
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

/* `rst $20` at $05E8. A selects a word in the table. SP is unchanged.
 * The inner `rst $10` leaves $0023 just below SP. */
static uint16_t rst20_table(Board *b, uint16_t table)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t flags;
	uint8_t a = add_a(Z80_A(b->cpu), Z80_A(b->cpu), &flags);
	uint8_t l = (uint8_t)table;
	uint8_t h = (uint8_t)(table >> 8);
	uint8_t byte;
	uint16_t hl;
	uint16_t de;

	push_word(b, &sp, table);
	sp = (uint16_t)(sp + 2u);
	push_word(b, &sp, 0x0023);
	a = add_a(a, l, &flags);
	l = a;
	a = add_carry(0, h, &flags, 1);
	h = a;
	hl = (uint16_t)(((uint16_t)h << 8) | l);
	byte = board_mem_read(b, hl);
	sp = (uint16_t)(sp + 2u);
	hl = (uint16_t)(hl + 1u);
	Z80_E(b->cpu) = byte;
	Z80_D(b->cpu) = board_mem_read(b, hl);
	de = Z80_DE(b->cpu);
	Z80_A(b->cpu) = byte;
	Z80_F(b->cpu) = flags;
	Z80_DE(b->cpu) = hl;
	Z80_HL(b->cpu) = de;
	Z80_SP(b->cpu) = sp;
	return de;
}

/* `rst $28`: B and C are the two data bytes. j_0042 returns after them. */
static void rst28_task(Board *b, uint8_t task, uint8_t param, uint16_t ret)
{
	Z80_B(b->cpu) = task;
	Z80_C(b->cpu) = param;
	call_lifted(b, ret, j_0042);
}

/* `rst $30`: copy the 3 bytes at `data` into the first free timed-task
 * slot. Returns 0 when all 16 slots are busy. */
static int rst30_task(Board *b, uint16_t data)
{
	uint16_t de = 0x4C90;
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t left = 0x10;
	uint8_t a;
	uint8_t i;
	uint8_t e;

	for (;;) {
		a = board_mem_read(b, de);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = and_flags(a);
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
	e = (uint8_t)de;
	for (i = 0; i < 3; i++) {
		uint8_t flags = Z80_F(b->cpu);

		a = board_mem_read(b, data);
		board_mem_write(b, de, a);
		data = (uint16_t)(data + 1u);
		flags = inc8(e, flags, &e);
		de = (uint16_t)((de & 0xFF00u) | e);
		Z80_F(b->cpu) = flags;
	}
	Z80_A(b->cpu) = a;
	Z80_B(b->cpu) = 0;
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = data;
	Z80_SP(b->cpu) = sp;
	return 1;
}

/* Subtract one credit in BCD. `add $99` then `daa`. */
static uint8_t bcd_dec(uint8_t a)
{
	uint8_t flags;

	a = add_a(a, 0x99, &flags);
	return daa(a, &flags);
}

/* Shared tail of a start-button press. Charges credits unless the
 * coin setting is free play, redraws the counter, then arms the intro. */
static void press_begin(Board *b)
{
	uint8_t coins = board_mem_read(b, 0x4E6B);
	uint8_t a = 1;

	Z80_A(b->cpu) = coins;
	Z80_F(b->cpu) = and_flags(coins);
	if (coins != 0) {
		uint8_t players = board_mem_read(b, 0x4E70);

		a = board_mem_read(b, 0x4E6E);
		if (players != 0)
			a = bcd_dec(a);
		a = bcd_dec(a);
		board_mem_write(b, 0x4E6E, a);
		Z80_A(b->cpu) = a;
		call_lifted(b, 0x0664, j_2ba1);
	}
	Z80_HL(b->cpu) = 0x4E03;
	(void)inc_mem(b, 0x4E03, Z80_F(b->cpu));
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	board_mem_write(b, 0x4DD6, 0);
	Z80_F(b->cpu) = inc8(0, 0x44, &a);
	Z80_A(b->cpu) = a;
	board_mem_write(b, 0x4ECC, a);
	board_mem_write(b, 0x4EDC, a);
}

/* First press-start frame: credits, the maze tasks, and the prompt. */
static void press_draw(Board *b)
{
	uint8_t bonus;
	uint8_t flags;

	call_lifted(b, 0x05F6, j_2ba1);
	rst28_task(b, 0x00, 0x01, 0x05F9);
	rst28_task(b, 0x01, 0x00, 0x05FC);
	rst28_task(b, 0x1C, 0x07, 0x05FF);
	rst28_task(b, 0x1C, 0x0B, 0x0602);
	rst28_task(b, 0x1E, 0x00, 0x0605);
	Z80_HL(b->cpu) = 0x4E03;
	(void)inc_mem(b, 0x4E03, Z80_F(b->cpu));
	Z80_A(b->cpu) = 1;
	board_mem_write(b, 0x4DD6, 1);
	bonus = board_mem_read(b, 0x4E71);
	flags = cp_flags(bonus, 0xFF);
	Z80_A(b->cpu) = bonus;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return;
	rst28_task(b, 0x1C, 0x0A, 0x0617);
	rst28_task(b, 0x1F, 0x00, 0x061A);
}

/* Wait for a start button. One credit offers player 1 only. */
static void press_wait(Board *b)
{
	uint8_t credits;
	uint8_t flags;
	uint8_t in1;

	call_lifted(b, 0x061E, j_2ba1);
	credits = board_mem_read(b, 0x4E6E);
	Z80_B(b->cpu) = credits == 1 ? 8 : 9;
	call_lifted(b, 0x062C, j_2c5e);
	credits = board_mem_read(b, 0x4E6E);
	flags = cp_flags(credits, 1);
	in1 = board_mem_read(b, 0x5040);
	Z80_A(b->cpu) = in1;
	if (credits != 1) {
		uint8_t bit6 = bit_reg(in1, 6, flags);

		Z80_F(b->cpu) = bit6;
		if ((bit6 & 0x40u) != 0) {
			Z80_A(b->cpu) = 1;
			board_mem_write(b, 0x4E70, 1);
			press_begin(b);
			return;
		}
	}
	flags = bit_reg(in1, 5, flags);
	Z80_A(b->cpu) = in1;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	board_mem_write(b, 0x4E70, 0);
	press_begin(b);
}

/* Start was pressed. Queue the board, zero the level, and arm a timer. */
static void press_go(Board *b)
{
	uint8_t lives;

	rst28_task(b, 0x00, 0x01, 0x0677);
	rst28_task(b, 0x01, 0x01, 0x067A);
	rst28_task(b, 0x02, 0x00, 0x067D);
	rst28_task(b, 0x12, 0x00, 0x0680);
	rst28_task(b, 0x03, 0x00, 0x0683);
	rst28_task(b, 0x1C, 0x03, 0x0686);
	rst28_task(b, 0x1C, 0x06, 0x0689);
	rst28_task(b, 0x18, 0x00, 0x068C);
	rst28_task(b, 0x1B, 0x00, 0x068F);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	board_mem_write(b, 0x4E13, 0);
	lives = board_mem_read(b, 0x4E6F);
	Z80_A(b->cpu) = lives;
	board_mem_write(b, 0x4E14, lives);
	board_mem_write(b, 0x4E15, lives);
	rst28_task(b, 0x1A, 0x00, 0x069F);
	if (rst30_task(b, 0x06A0) == 0)
		return;
	Z80_HL(b->cpu) = 0x4E03;
	Z80_F(b->cpu) = inc_mem(b, 0x4E03, Z80_F(b->cpu));
}

/* Draw the life icons and leave press-start for the play loop. */
static void press_lives(Board *b)
{
	uint8_t shown = board_mem_read(b, 0x4E15);

	board_mem_write(b, 0x4E15, (uint8_t)(shown - 1u));
	Z80_HL(b->cpu) = 0x4E15;
	call_lifted(b, 0x06AF, j_2b6a);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	board_mem_write(b, 0x4E03, 0);
	board_mem_write(b, 0x4E02, 0);
	board_mem_write(b, 0x4E04, 0);
	Z80_HL(b->cpu) = 0x4E00;
	Z80_F(b->cpu) = inc_mem(b, 0x4E00, 0x44);
}

/* j_05e5  press-start dispatcher
 * Entry:    Game mode 2. ($4E03) selects the step.
 * Exit:     Step 0 draws the prompt and queues the board tasks.
 *           Step 1 watches the start buttons and, on a press, charges
 *           a credit and starts the intro tune.
 *           Step 2 queues the playfield and a timer.
 *           Step 3 is the bare return at $000C. Registers are `rst $20`.
 *           Step 4 draws the lives and advances the game mode to 3.
 *           Host finishes the RET.
 * Clobbers: whichever step runs
 * Flags live-out: the step's last flag write.
 * Interrupt: returns inside the frame budget.
 * Stack: `rst $20` leaves $0023. Each step's calls overwrite it.
 */
void j_05e5(Board *b)
{
	uint16_t target;

	Z80_A(b->cpu) = board_mem_read(b, 0x4E03);
	target = rst20_table(b, 0x05E9);
	if (target == 0x05F3)
		press_draw(b);
	else if (target == 0x061B)
		press_wait(b);
	else if (target == 0x0674)
		press_go(b);
	else if (target == 0x06A8)
		press_lives(b);
}
