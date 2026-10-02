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
