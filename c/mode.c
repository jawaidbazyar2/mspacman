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

/* `inc r`. C is unchanged. */
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

static void write_word(Board *b, uint16_t addr, uint16_t value)
{
	board_mem_write(b, addr, (uint8_t)value);
	board_mem_write(b, (uint16_t)(addr + 1u), (uint8_t)(value >> 8));
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

/* `rst $20`. A is the index. `table` is the address after the rst.
 * HL becomes the selected target. DE is the address of its high byte.
 * F is the `adc` inside `rst $10`. A $000C target is the bare RET:
 * the plant at SP-2 is $0023 and the host pops the original return.
 */
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

/* `inc (hl)` at a known address. C is unchanged. */
static void inc_addr(Board *b, uint16_t addr)
{
	uint8_t cur = board_mem_read(b, addr);
	uint8_t next;
	uint8_t flags = inc_a_flags(cur, Z80_F(b->cpu), &next);

	board_mem_write(b, addr, next);
	Z80_HL(b->cpu) = addr;
	Z80_F(b->cpu) = flags;
}

/* `ldir` of `bc` bytes. Flags are unchanged. BC ends at 0. */
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

extern void j_0042(Board *b);
extern void j_0894(Board *b);
extern void j_24c9(Board *b);
extern void j_2487(Board *b);
extern void j_2ba1(Board *b);
extern void j_267e(Board *b);
extern void j_94bd(Board *b);
extern void j_08eb(Board *b);
extern void j_05e5(Board *b);
extern void j_3ed0(Board *b);
extern void j_045f(Board *b);
extern void j_3e8b(Board *b);
extern void j_3e96(Board *b);
extern void j_3e9c(Board *b);
extern void j_3ea2(Board *b);
extern void j_3eab(Board *b);
extern void j_3eb1(Board *b);
extern void j_3eb7(Board *b);
extern void j_3ebd(Board *b);
extern void j_3ec3(Board *b);
extern void j_3483(Board *b);
extern void j_3488(Board *b);
extern void j_348d(Board *b);
extern void j_3492(Board *b);
extern void j_3497(Board *b);
extern void j_349c(Board *b);

/* `rst $28` into the task list. The continuation stays below SP. */
static void queue_task(Board *b, uint8_t task, uint8_t param, uint16_t ret)
{
	Z80_B(b->cpu) = task;
	Z80_C(b->cpu) = param;
	call_lifted(b, ret, j_0042);
}

/* Three data bytes that `rst $30` returns into when the list is full. */
static void exec_timed_data(Board *b, uint16_t data)
{
	uint8_t i;

	for (i = 0; i < 3u; i++) {
		uint8_t op = board_mem_read(b, data);

		data = (uint16_t)(data + 1u);
		if (op == 0x54)
			Z80_D(b->cpu) = (uint8_t)(Z80_HL(b->cpu) >> 8);
		else if (op == 0x42)
			Z80_B(b->cpu) = Z80_D(b->cpu);
		else if (op == 0x43)
			Z80_B(b->cpu) = Z80_E(b->cpu);
		else if (op == 0x45)
			Z80_B(b->cpu) = (uint8_t)Z80_HL(b->cpu);
	}
}

/* `rst $30`. Copies 3 bytes into the first free timed-task slot.
 * Found: A is the last copied byte, B = 0, DE is the slot plus 3,
 * HL is the address after the data, F is the third `inc e`.
 * Full: the three data bytes execute, then the caller continues.
 * The data address is left at SP-2. C and IX are unchanged.
 */
static void queue_timed(Board *b, uint16_t data)
{
	uint16_t de = 0x4C90;
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t left = 0x10;
	uint8_t a = 0;
	uint8_t e;
	uint8_t i;
	uint8_t flags = Z80_F(b->cpu);
	int found = 0;

	push_word(b, &sp, data);
	Z80_SP(b->cpu) = sp;
	for (;;) {
		a = board_mem_read(b, de);
		flags = and_a_flags(a);
		if (a == 0) {
			found = 1;
			break;
		}
		e = (uint8_t)de;
		flags = inc_a_flags(e, flags, &e);
		flags = inc_a_flags(e, flags, &e);
		flags = inc_a_flags(e, flags, &e);
		de = (uint16_t)((de & 0xFF00u) | e);
		left--;
		if (left == 0)
			break;
	}
	sp = (uint16_t)(sp + 2u);
	Z80_SP(b->cpu) = sp;
	Z80_A(b->cpu) = a;
	Z80_DE(b->cpu) = de;
	Z80_F(b->cpu) = flags;
	if (!found) {
		Z80_B(b->cpu) = 0;
		exec_timed_data(b, data);
		return;
	}
	e = (uint8_t)de;
	for (i = 0; i < 3u; i++) {
		a = board_mem_read(b, data);
		board_mem_write(b, de, a);
		data = (uint16_t)(data + 1u);
		flags = inc_a_flags(e, flags, &e);
		de = (uint16_t)((de & 0xFF00u) | e);
	}
	Z80_A(b->cpu) = a;
	Z80_B(b->cpu) = 0;
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = data;
	Z80_F(b->cpu) = flags;
}

/* Cocktail and player 2: store the AND into the flip latch. */
static void cocktail_flip(Board *b)
{
	uint8_t cock = board_mem_read(b, 0x4E72);
	uint8_t a = board_mem_read(b, 0x4E09);

	Z80_B(b->cpu) = cock;
	a = (uint8_t)(a & cock);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	board_mem_write(b, 0x5003, a);
}

/* j_0aa6  swap the two players' level records
 * Entry:    nothing.
 * Exit:     $2E bytes at $4E0A and $4E38 are exchanged.
 *           B = 0. IX = $4E38. IY = $4E66. D and E are the last
 *           pair exchanged. A, F, C, and HL are unchanged.
 *           Host finishes the RET.
 * Clobbers: B, DE, IX, IY
 * Flags live-out: the caller's flags. No flag instruction runs.
 * Interrupt: returns inside the frame budget.
 * Stack: normal RET. No callee.
 */
void j_0aa6(Board *b)
{
	uint16_t ix = 0x4E0A;
	uint16_t iy = 0x4E38;
	uint8_t n;
	uint8_t d = 0;
	uint8_t e = 0;

	for (n = 0x2E; n != 0; n--) {
		d = board_mem_read(b, ix);
		e = board_mem_read(b, iy);
		board_mem_write(b, iy, d);
		board_mem_write(b, ix, e);
		ix = (uint16_t)(ix + 1u);
		iy = (uint16_t)(iy + 1u);
	}
	Z80_B(b->cpu) = 0;
	Z80_D(b->cpu) = d;
	Z80_E(b->cpu) = e;
	Z80_IX(b->cpu) = ix;
	Z80_IY(b->cpu) = iy;
}

/* j_09ea  one maze-color flash and a short wait
 * Entry:    C = 2 or 0, the color parameter.
 * Exit:     Task 1 is queued with that parameter. A timer of $42
 *           advances the level state. Ghost positions are cleared.
 *           ($4E04) increases by one. HL = $4E04. F is that `inc`.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: Z when the level state wraps.
 * Interrupt: returns inside the frame budget.
 * Stack: the call of j_0042, the `rst $30`, and the call of j_267e.
 */
void j_09ea(Board *b)
{
	Z80_B(b->cpu) = 1;
	call_lifted(b, 0x09EF, j_0042);
	queue_timed(b, 0x09F0);
	Z80_HL(b->cpu) = 0;
	call_lifted(b, 0x09F9, j_267e);
	inc_addr(b, 0x4E04);
}

/* j_09e8  flash with color parameter 2 */
void j_09e8(Board *b)
{
	Z80_C(b->cpu) = 2;
	j_09ea(b);
}

/* j_09fe  flash with color parameter 0 */
void j_09fe(Board *b)
{
	Z80_C(b->cpu) = 0;
	j_09ea(b);
}

void j_0a02(Board *b)
{
	j_09e8(b);
}

void j_0a04(Board *b)
{
	j_09fe(b);
}

void j_0a06(Board *b)
{
	j_09e8(b);
}

void j_0a08(Board *b)
{
	j_09fe(b);
}

void j_0a0a(Board *b)
{
	j_09e8(b);
}

void j_0a0c(Board *b)
{
	j_09fe(b);
}

/* j_0879  clear the player record and copy the difficulty block
 * Entry:    the level-state 0 vector.
 * Exit:     $4E09 through $4E13 are cleared, then the dip difficulty
 *           pointer is stored at $4E0A and $2E bytes are copied to $4E38.
 *           ($4E04) increases by one, from j_0894.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: j_0894's `inc`.
 * Interrupt: returns inside the frame budget.
 * Stack: `rst $08` and the call of j_24c9. Both return.
 */
void j_0879(Board *b)
{
	uint16_t hl;

	Z80_HL(b->cpu) = 0x4E09;
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
	Z80_B(b->cpu) = 0x0B;
	rst08(b, 0x0880);
	call_lifted(b, 0x0883, j_24c9);
	hl = word_at(b, 0x4E73);
	Z80_HL(b->cpu) = hl;
	write_word(b, 0x4E0A, hl);
	ldir_n(b, 0x4E0A, 0x4E38, 0x002E);
	j_0894(b);
}

/* j_0899  opening tasks, or skip them when this is the demo
 * Entry:    level state 1. F is the `rst $20` that selected it.
 * Exit:     Demo (game mode 1): ($4E04) = 9. A = 9. F is `dec` of
 *           the game mode. HL stays $0899.
 *           A real game queues the six opening tasks and two timers,
 *           writes the flip latch, then j_0894 advances the level state.
 *           Host finishes the RET.
 * Clobbers: A, F, and on the real-game path B, C, DE, HL
 * Flags live-out: the demo `dec`, or j_0894's `inc`.
 * Interrupt: returns inside the frame budget.
 * Stack: six `rst $28`s and two `rst $30`s on the real-game path.
 */
void j_0899(Board *b)
{
	uint8_t mode = board_mem_read(b, 0x4E00);
	uint8_t next;
	uint8_t flags = dec_r(mode, Z80_F(b->cpu), &next);

	Z80_A(b->cpu) = next;
	Z80_F(b->cpu) = flags;
	if (next == 0) {
		Z80_A(b->cpu) = 9;
		board_mem_write(b, 0x4E04, 9);
		return;
	}
	queue_task(b, 0x11, 0x00, 0x08A8);
	queue_task(b, 0x1C, 0x83, 0x08AB);
	queue_task(b, 0x04, 0x00, 0x08AE);
	queue_task(b, 0x05, 0x00, 0x08B1);
	queue_task(b, 0x10, 0x00, 0x08B4);
	queue_task(b, 0x1A, 0x00, 0x08B7);
	queue_timed(b, 0x08B8);
	queue_timed(b, 0x08BC);
	cocktail_flip(b);
	j_0894(b);
}

/* j_08e5  the board is clear
 * Entry:    A and F are the pellet `cp` from j_94a1.
 * Exit:     ($4E04) = $0C. HL = $4E04. A and F stay the `cp`.
 *           Host finishes the RET.
 * Clobbers: HL
 * Flags live-out: the pellet compare. Z is set.
 * Interrupt: returns inside the frame budget.
 * Stack: normal RET. The saved BC from j_94a1 is already popped.
 */
void j_08e5(Board *b)
{
	Z80_HL(b->cpu) = 0x4E04;
	board_mem_write(b, 0x4E04, 0x0C);
}

/* j_94a1  choose play or end-of-level from the pellet table
 * Entry:    BC is the caller's BC.
 * Exit:     If pellets remain, the exit is j_08eb.
 *           If the board is clear, the exit is j_08e5.
 *           Host finishes the RET.
 * Clobbers: A, F, BC during the lookup, DE, HL
 * Flags live-out: j_08eb's flags, or the pellet `cp` on a clear board.
 * Interrupt: returns inside the frame budget.
 * Stack: BC is pushed and popped. j_94bd and, on a live board, j_08eb.
 */
void j_94a1(Board *b)
{
	uint16_t saved = Z80_BC(b->cpu);
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t need;
	uint8_t dots;
	uint8_t flags;

	push_word(b, &sp, saved);
	Z80_SP(b->cpu) = sp;
	Z80_HL(b->cpu) = 0x94B5;
	call_lifted(b, 0x94A8, j_94bd);
	need = board_mem_read(b, Z80_BC(b->cpu));
	dots = board_mem_read(b, 0x4E0E);
	flags = cp_flags(dots, need);
	Z80_A(b->cpu) = dots;
	Z80_F(b->cpu) = flags;
	(void)pop_word(b);
	Z80_BC(b->cpu) = saved;
	if ((flags & 0x40u) == 0)
		j_08eb(b);
	else
		j_08e5(b);
}

/* j_08de  load the pellet count and test the board */
void j_08de(Board *b)
{
	Z80_A(b->cpu) = board_mem_read(b, 0x4E0E);
	j_94a1(b);
}

/* j_08cd  one frame of play, or the rack-test skip
 * Entry:    level state 3.
 * Exit:     Bit 4 of IN0 clear: ($4E04) = $0E and task $13 is queued.
 *           Bit 4 set: j_08de, which plays or ends the board.
 *           The IN0 read happens once.
 *           Host finishes the RET.
 * Clobbers: A, F, and whatever the play path clobbers
 * Flags live-out: the play path's flags, or j_0042 on rack test.
 * Interrupt: returns inside the frame budget.
 * Stack: the rack path's `rst $28`, or j_94a1's calls.
 */
void j_08cd(Board *b)
{
	uint8_t a = board_mem_read(b, 0x5000);

	Z80_A(b->cpu) = a;
	if ((a & 0x10u) != 0) {
		j_08de(b);
		return;
	}
	Z80_HL(b->cpu) = 0x4E04;
	board_mem_write(b, 0x4E04, 0x0E);
	queue_task(b, 0x13, 0x00, 0x08DD);
}

/* j_090d  a life was just lost
 * Entry:    level state 4.
 * Exit:     ($4E12) = 1. Pellets are saved. ($4E04) increases once.
 *           If lives remain, or this is one player, or $4E42 is 0,
 *           ($4E04) increases a second time.
 *           Otherwise the player banner, GAME OVER, and a timer are queued.
 *           Host finishes the RET.
 * Clobbers: A, F, HL, and on the banner path B, C, DE
 * Flags live-out: the second `inc`, or the timer's last `inc e`.
 * Interrupt: returns inside the frame budget.
 * Stack: the call of j_2487, and on the banner path j_0042, `rst $28`, `rst $30`.
 */
void j_090d(Board *b)
{
	uint8_t a;
	uint8_t flags = 0;

	Z80_A(b->cpu) = 1;
	board_mem_write(b, 0x4E12, 1);
	call_lifted(b, 0x0915, j_2487);
	inc_addr(b, 0x4E04);
	a = board_mem_read(b, 0x4E14);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0) {
		inc_addr(b, 0x4E04);
		return;
	}
	a = board_mem_read(b, 0x4E70);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		inc_addr(b, 0x4E04);
		return;
	}
	a = board_mem_read(b, 0x4E42);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0) {
		inc_addr(b, 0x4E04);
		return;
	}
	a = board_mem_read(b, 0x4E09);
	a = add_a(a, 0x03, &flags);
	Z80_A(b->cpu) = a;
	Z80_C(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = 0x1C;
	call_lifted(b, 0x0936, j_0042);
	queue_task(b, 0x1C, 0x05, 0x0939);
	queue_timed(b, 0x093A);
}

/* j_0940  game over, or hand the board to the other player
 * Entry:    level state 6.
 * Exit:     One player, or $4E42 = 0: if lives remain, ($4E04) = 9
 *           and F is `and` of the life count. If none remain, GAME OVER
 *           is queued and ($4E04) increases.
 *           Two players with $4E42 nonzero: the level records swap,
 *           the player number flips, and ($4E04) = 9. F is `xor 1`.
 *           Host finishes the RET.
 * Clobbers: A, F, and on the swap or game-over path B, DE, HL, IX, IY
 * Flags live-out: the life `and`, the player `xor`, or the final `inc`.
 * Interrupt: returns inside the frame budget.
 * Stack: j_0aa6, or j_2ba1 plus `rst $28` and `rst $30`.
 */
void j_0940(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4E70);
	uint8_t flags = and_a_flags(a);
	uint8_t flipped;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0) {
		a = board_mem_read(b, 0x4E42);
		flags = and_a_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if (a != 0) {
			call_lifted(b, 0x0964, j_0aa6);
			a = board_mem_read(b, 0x4E09);
			flipped = (uint8_t)(a ^ 1u);
			board_mem_write(b, 0x4E09, flipped);
			Z80_F(b->cpu) = xor_flags(flipped);
			Z80_A(b->cpu) = 9;
			board_mem_write(b, 0x4E04, 9);
			return;
		}
	}
	a = board_mem_read(b, 0x4E14);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0) {
		Z80_A(b->cpu) = 9;
		board_mem_write(b, 0x4E04, 9);
		return;
	}
	call_lifted(b, 0x0955, j_2ba1);
	queue_task(b, 0x1C, 0x05, 0x0958);
	queue_timed(b, 0x0959);
	inc_addr(b, 0x4E04);
}

/* j_0972  the demo is over
 * Entry:    level state 8.
 * Exit:     A = 1. ($4E00) = 1. $4E02, $4E04, $4E70, $4E09, and the
 *           flip latch are 0. F is `xor a` ($44).
 *           Host finishes the RET.
 * Clobbers: A, F
 * Flags live-out: Z and P/V set. H, N, and C clear.
 * Interrupt: returns inside the frame budget.
 * Stack: normal RET. No callee.
 */
void j_0972(Board *b)
{
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
	board_mem_write(b, 0x4E02, 0);
	board_mem_write(b, 0x4E04, 0);
	board_mem_write(b, 0x4E70, 0);
	board_mem_write(b, 0x4E09, 0);
	board_mem_write(b, 0x5003, 0);
	Z80_A(b->cpu) = 1;
	board_mem_write(b, 0x4E00, 1);
}

/* j_0988  draw the board and show READY or GAME OVER
 * Entry:    level state 9, or the jump from j_0aa0.
 * Exit:     The board tasks are queued. A playing game also queues
 *           the READY-clear timer. The flip latch is written.
 *           j_0894 advances the level state.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: j_0894's `inc`.
 * Interrupt: returns inside the frame budget.
 * Stack: the task and timer rsts, all returned.
 */
void j_0988(Board *b)
{
	uint8_t mode;
	uint8_t next;
	uint8_t flags;

	queue_task(b, 0x00, 0x01, 0x098B);
	queue_task(b, 0x01, 0x01, 0x098E);
	queue_task(b, 0x02, 0x00, 0x0991);
	queue_task(b, 0x11, 0x00, 0x0994);
	queue_task(b, 0x13, 0x00, 0x0997);
	queue_task(b, 0x03, 0x00, 0x099A);
	queue_task(b, 0x04, 0x00, 0x099D);
	queue_task(b, 0x05, 0x00, 0x09A0);
	queue_task(b, 0x10, 0x00, 0x09A3);
	queue_task(b, 0x1A, 0x00, 0x09A6);
	queue_task(b, 0x1C, 0x06, 0x09A9);
	mode = board_mem_read(b, 0x4E00);
	flags = cp_flags(mode, 0x03);
	Z80_A(b->cpu) = mode;
	Z80_F(b->cpu) = flags;
	if (mode != 0x03) {
		queue_task(b, 0x1C, 0x05, 0x09B3);
		queue_task(b, 0x1D, 0x00, 0x09B6);
	}
	queue_timed(b, 0x09B7);
	mode = board_mem_read(b, 0x4E00);
	flags = dec_r(mode, Z80_F(b->cpu), &next);
	Z80_A(b->cpu) = next;
	Z80_F(b->cpu) = flags;
	if (next != 0)
		queue_timed(b, 0x09C1);
	cocktail_flip(b);
	j_0894(b);
}

/* j_09d2  start the maze part of the demo
 * Entry:    F is the `rst $20` that selected this state.
 * Exit:     A = 3. ($4E04) = 3. F and HL stay as the `rst $20` left them.
 *           Host finishes the RET.
 * Clobbers: A
 * Flags live-out: the `rst $20` `adc`.
 * Interrupt: returns inside the frame budget.
 * Stack: normal RET. No callee.
 */
void j_09d2(Board *b)
{
	Z80_A(b->cpu) = 3;
	board_mem_write(b, 0x4E04, 3);
}

/* j_09d8  pause at the end of a board and silence two channels
 * Entry:    level state $0C.
 * Exit:     A timer of $54 is queued. ($4E04) increases.
 *           ($4EAC) and ($4EBC) are 0. A = 0. F is `xor a`.
 *           HL = $4E04.
 *           Host finishes the RET.
 * Clobbers: A, F, B, DE, HL
 * Flags live-out: Z and P/V set.
 * Interrupt: returns inside the frame budget.
 * Stack: `rst $30` leaves $09D9 under SP.
 */
void j_09d8(Board *b)
{
	queue_timed(b, 0x09D9);
	inc_addr(b, 0x4E04);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
	board_mem_write(b, 0x4EAC, 0);
	board_mem_write(b, 0x4EBC, 0);
}

/* j_0a0e  clear the finished board and wait
 * Entry:    level state $14.
 * Exit:     Seven tasks and a timer of $43 are queued.
 *           ($4E04) increases. HL = $4E04. F is that `inc`.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: the final `inc`. Carry is clear.
 * Interrupt: returns inside the frame budget.
 * Stack: seven `rst $28`s and one `rst $30`.
 */
void j_0a0e(Board *b)
{
	queue_task(b, 0x00, 0x01, 0x0A11);
	queue_task(b, 0x06, 0x00, 0x0A14);
	queue_task(b, 0x11, 0x00, 0x0A17);
	queue_task(b, 0x13, 0x00, 0x0A1A);
	queue_task(b, 0x04, 0x01, 0x0A1D);
	queue_task(b, 0x05, 0x01, 0x0A20);
	queue_task(b, 0x10, 0x13, 0x0A23);
	queue_timed(b, 0x0A24);
	inc_addr(b, 0x4E04);
}

/* j_0a6f  skip the cutscene
 * Entry:    the intermission table's ordinary slots.
 * Exit:     ($4E04) increases by two. ($4ECC) and ($4EDC) are 0.
 *           A = 0. F is `xor a`. HL = $4E04.
 *           Host finishes the RET.
 * Clobbers: A, F, HL
 * Flags live-out: Z and P/V set.
 * Interrupt: returns inside the frame budget.
 * Stack: normal RET. No callee.
 */
void j_0a6f(Board *b)
{
	inc_addr(b, 0x4E04);
	inc_addr(b, 0x4E04);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
	board_mem_write(b, 0x4ECC, 0);
	board_mem_write(b, 0x4EDC, 0);
}

/* j_3435  start cutscene 1, or keep it running
 * Entry:    ($4F00) is 1 when the act is already going.
 * Exit:     If it is already going, the exit is j_349c with C unchanged.
 *           Otherwise task $1C/$32 is queued, "1" is drawn at $42AC,
 *           C = 0, and the exit is j_349c.
 *           Host finishes the RET.
 * Clobbers: A, F, and on the start path B, C, HL
 * Flags live-out: j_349c's flags.
 * Interrupt: returns inside the frame budget.
 * Stack: the start path's `rst $28`, then j_349c's own calls.
 */
void j_3435(Board *b)
{
	uint8_t flag = board_mem_read(b, 0x4F00);
	uint8_t flags = cp_flags(flag, 1);

	Z80_A(b->cpu) = flag;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0) {
		j_349c(b);
		return;
	}
	queue_task(b, 0x1C, 0x32, 0x3440);
	Z80_A(b->cpu) = 1;
	board_mem_write(b, 0x42AC, 1);
	Z80_A(b->cpu) = 0x16;
	board_mem_write(b, 0x46AC, 0x16);
	Z80_C(b->cpu) = 0;
	j_349c(b);
}

/* j_344f  start cutscene 2, or keep it running */
void j_344f(Board *b)
{
	uint8_t flag = board_mem_read(b, 0x4F00);
	uint8_t flags = cp_flags(flag, 1);

	Z80_A(b->cpu) = flag;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0) {
		j_349c(b);
		return;
	}
	queue_task(b, 0x1C, 0x17, 0x345A);
	Z80_A(b->cpu) = 2;
	board_mem_write(b, 0x42AC, 2);
	Z80_A(b->cpu) = 0x16;
	board_mem_write(b, 0x46AC, 0x16);
	Z80_C(b->cpu) = 0x0C;
	j_349c(b);
}

/* j_3469  start cutscene 3, or keep it running */
void j_3469(Board *b)
{
	uint8_t flag = board_mem_read(b, 0x4F00);
	uint8_t flags = cp_flags(flag, 1);

	Z80_A(b->cpu) = flag;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0) {
		j_349c(b);
		return;
	}
	queue_task(b, 0x1C, 0x15, 0x3474);
	Z80_A(b->cpu) = 3;
	board_mem_write(b, 0x42AC, 3);
	Z80_A(b->cpu) = 0x16;
	board_mem_write(b, 0x46AC, 0x16);
	Z80_C(b->cpu) = 0x18;
	j_349c(b);
}

/* j_2108  the intermission table's jump to cutscene 1 */
void j_2108(Board *b)
{
	j_3435(b);
}

/* j_219e  load the second-cutscene state, then start the act.
 * j_344f replaces A. */
void j_219e(Board *b)
{
	Z80_A(b->cpu) = board_mem_read(b, 0x4E07);
	j_344f(b);
}

/* j_2297  load the third-cutscene state, then start the act.
 * j_3469 replaces A. */
void j_2297(Board *b)
{
	Z80_A(b->cpu) = board_mem_read(b, 0x4E08);
	j_3469(b);
}

/* j_0a2c  silence the effects and run the cutscene for this level
 * Entry:    level state $16.
 * Exit:     ($4EAC) and ($4EBC) are 0. The level is capped at $14.
 *           The table at $0A45 selects j_0a6f or a cutscene prologue.
 *           Host finishes the RET.
 * Clobbers: A, F, and whatever the selected act clobbers
 * Flags live-out: the selected act's flags.
 * Interrupt: returns inside the frame budget.
 * Stack: the inner `rst $20` plant, then the act's own calls.
 */
void j_0a2c(Board *b)
{
	uint8_t level;
	uint8_t flags;
	uint16_t target;

	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
	board_mem_write(b, 0x4EAC, 0);
	board_mem_write(b, 0x4EBC, 0);
	level = board_mem_read(b, 0x4E13);
	flags = cp_flags(level, 0x14);
	Z80_A(b->cpu) = level;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) == 0) {
		level = 0x14;
		Z80_A(b->cpu) = level;
	}
	target = rst20(b, 0x0A45);
	if (target == 0x2108)
		j_2108(b);
	else if (target == 0x219E)
		j_219e(b);
	else if (target == 0x2297)
		j_2297(b);
	else if (target == 0x0A6F)
		j_0a6f(b);
}

/* j_0a7c  advance to the next board
 * Entry:    level state $18.
 * Exit:     Wave channels $4ECC and $4EDC are 0. Seven bytes at $4E0C
 *           are cleared. Pellets are reset. ($4E04) and ($4E13) increase.
 *           If the difficulty byte is $14, F is that `cp` and HL stays
 *           on it. Otherwise HL advances and is stored back. F stays
 *           the `cp`.
 *           Host finishes the RET.
 * Clobbers: A, F, B, HL, and whatever j_24c9 clobbers
 * Flags live-out: `cp $14`.
 * Interrupt: returns inside the frame budget.
 * Stack: `rst $08` and the call of j_24c9.
 */
void j_0a7c(Board *b)
{
	uint16_t ptr;
	uint8_t diff;
	uint8_t flags;

	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
	board_mem_write(b, 0x4ECC, 0);
	board_mem_write(b, 0x4EDC, 0);
	Z80_HL(b->cpu) = 0x4E0C;
	Z80_B(b->cpu) = 7;
	rst08(b, 0x0A89);
	call_lifted(b, 0x0A8C, j_24c9);
	inc_addr(b, 0x4E04);
	inc_addr(b, 0x4E13);
	ptr = word_at(b, 0x4E0A);
	diff = board_mem_read(b, ptr);
	flags = cp_flags(diff, 0x14);
	Z80_HL(b->cpu) = ptr;
	Z80_A(b->cpu) = diff;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return;
	ptr = (uint16_t)(ptr + 1u);
	Z80_HL(b->cpu) = ptr;
	write_word(b, 0x4E0A, ptr);
}

/* j_0aa0  the level-state jump to the READY setup */
void j_0aa0(Board *b)
{
	j_0988(b);
}

/* j_0aa3  the level-state jump back to the demo maze */
void j_0aa3(Board *b)
{
	j_09d2(b);
}

/* j_06be  one step of the level state
 * Entry:    ($4E04) selects the vector. The caller's return is on the stack.
 * Exit:     The selected state has run. A $000C vector leaves the
 *           `rst $20` registers: HL = $000C, A = $0C, DE points at the
 *           high byte, F is the `adc`, and $0023 is at SP-2.
 *           Host finishes the RET, which is the RET at $000C or the
 *           state's own RET.
 * Clobbers: depends on the state
 * Flags live-out: the state's flags, or the `rst $20` `adc` on a wait.
 * Interrupt: returns inside the frame budget. Waits are one return.
 * Stack: `rst $20` plants $0023. States push their own calls.
 */
void j_06be(Board *b)
{
	uint16_t target;

	Z80_A(b->cpu) = board_mem_read(b, 0x4E04);
	target = rst20(b, 0x06C2);
	switch (target) {
	case 0x000C:
		break;
	case 0x0879:
		j_0879(b);
		break;
	case 0x0899:
		j_0899(b);
		break;
	case 0x08CD:
		j_08cd(b);
		break;
	case 0x090D:
		j_090d(b);
		break;
	case 0x0940:
		j_0940(b);
		break;
	case 0x0972:
		j_0972(b);
		break;
	case 0x0988:
		j_0988(b);
		break;
	case 0x09D2:
		j_09d2(b);
		break;
	case 0x09D8:
		j_09d8(b);
		break;
	case 0x09E8:
		j_09e8(b);
		break;
	case 0x09FE:
		j_09fe(b);
		break;
	case 0x0A02:
		j_0a02(b);
		break;
	case 0x0A04:
		j_0a04(b);
		break;
	case 0x0A06:
		j_0a06(b);
		break;
	case 0x0A08:
		j_0a08(b);
		break;
	case 0x0A0A:
		j_0a0a(b);
		break;
	case 0x0A0C:
		j_0a0c(b);
		break;
	case 0x0A0E:
		j_0a0e(b);
		break;
	case 0x0A2C:
		j_0a2c(b);
		break;
	case 0x0A7C:
		j_0a7c(b);
		break;
	case 0x0AA0:
		j_0aa0(b);
		break;
	case 0x0AA3:
		j_0aa3(b);
		break;
	default:
		break;
	}
}

/* j_03dc  the eight power-on tasks
 * Entry:    game-mode subroutine 0. F is the `rst $20` `adc`.
 * Exit:     ($4E01) increases. The irq latch at $5001 is 1.
 *           A stays the table low byte. B = 7. C = 0. HL = $5001.
 *           F is the `inc` of $4E01. The last continuation $03F4
 *           is at SP-2.
 *           Host finishes the RET.
 * Clobbers: F, B, C, HL
 * Flags live-out: the `inc`. Carry comes from the `rst $20`.
 * Interrupt: returns inside the frame budget.
 * Stack: eight `rst $28`s.
 */
void j_03dc(Board *b)
{
	queue_task(b, 0x00, 0x00, 0x03DF);
	queue_task(b, 0x06, 0x00, 0x03E2);
	queue_task(b, 0x01, 0x00, 0x03E5);
	queue_task(b, 0x14, 0x00, 0x03E8);
	queue_task(b, 0x18, 0x00, 0x03EB);
	queue_task(b, 0x04, 0x00, 0x03EE);
	queue_task(b, 0x1E, 0x00, 0x03F1);
	queue_task(b, 0x07, 0x00, 0x03F4);
	inc_addr(b, 0x4E01);
	Z80_HL(b->cpu) = 0x5001;
	board_mem_write(b, 0x5001, 1);
}

/* j_03d4  power-on subroutine
 * Entry:    ($4E01) is 0 the first time and 1 after that.
 * Exit:     0 runs j_03dc. 1 is the bare RET at $000C.
 *           Host finishes the RET.
 * Clobbers: the selected path
 * Flags live-out: j_03dc, or the `rst $20` `adc`.
 * Interrupt: returns inside the frame budget.
 * Stack: `rst $20`, then j_03dc's tasks.
 */
void j_03d4(Board *b)
{
	uint16_t target;

	Z80_A(b->cpu) = board_mem_read(b, 0x4E01);
	target = rst20(b, 0x03D8);
	if (target == 0x03DC)
		j_03dc(b);
}

/* j_057c  one level-state step from the demo start
 * Entry:    the return to the mode switch is on the stack.
 * Exit:     j_06be has run. $057F is at SP-2.
 *           Host finishes the RET.
 * Clobbers: whatever j_06be clobbers
 * Flags live-out: j_06be's flags.
 * Interrupt: returns inside the frame budget.
 * Stack: the call of j_06be, returned.
 */
void j_057c(Board *b)
{
	call_lifted(b, 0x057F, j_06be);
}

/* j_3ec9  zero the demo lives and start the level state
 * Entry:    attract subroutine $10.
 * Exit:     A is whatever j_06be left. ($4E14) = 0. F is j_06be's.
 *           The `xor a` runs first.
 *           Host finishes the RET.
 * Clobbers: A, F, and whatever j_06be clobbers
 * Flags live-out: j_06be's flags.
 * Interrupt: returns inside the frame budget.
 * Stack: the jump is a tail into j_057c.
 */
void j_3ec9(Board *b)
{
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
	board_mem_write(b, 0x4E14, 0);
	j_057c(b);
}

/* j_3e5c  one attract card, a walk, or the demo start
 * Entry:    ($4E02) selects the card. $10 is the demo.
 * Exit:     Unless the subroutine is $10, j_3ed0 runs the bulbs.
 *           Subroutine 3 is the bare RET. The others are the card,
 *           the walk, or j_3ec9.
 *           Host finishes the RET.
 * Clobbers: the selected card
 * Flags live-out: the card's flags, or the `rst $20` `adc` on a wait.
 * Interrupt: returns inside the frame budget.
 * Stack: the bulb call when it runs, then the card.
 */
void j_3e5c(Board *b)
{
	uint8_t sub = board_mem_read(b, 0x4E02);
	uint16_t target;

	Z80_A(b->cpu) = sub;
	Z80_F(b->cpu) = cp_flags(sub, 0x10);
	if (sub != 0x10)
		call_lifted(b, 0x3E64, j_3ed0);
	sub = board_mem_read(b, 0x4E02);
	Z80_A(b->cpu) = sub;
	target = rst20(b, 0x3E68);
	switch (target) {
	case 0x000C:
		break;
	case 0x045F:
		j_045f(b);
		break;
	case 0x3E96:
		j_3e96(b);
		break;
	case 0x3E8B:
		j_3e8b(b);
		break;
	case 0x3EBD:
		j_3ebd(b);
		break;
	case 0x3E9C:
		j_3e9c(b);
		break;
	case 0x3483:
		j_3483(b);
		break;
	case 0x3EA2:
		j_3ea2(b);
		break;
	case 0x3488:
		j_3488(b);
		break;
	case 0x3EAB:
		j_3eab(b);
		break;
	case 0x348D:
		j_348d(b);
		break;
	case 0x3EB1:
		j_3eb1(b);
		break;
	case 0x3492:
		j_3492(b);
		break;
	case 0x3EC3:
		j_3ec3(b);
		break;
	case 0x3EB7:
		j_3eb7(b);
		break;
	case 0x3497:
		j_3497(b);
		break;
	case 0x3EC9:
		j_3ec9(b);
		break;
	default:
		break;
	}
}

/* j_03fe  attract, until a credit moves the game to press-start
 * Entry:    game mode 1.
 * Exit:     No credits: j_3e5c.
 *           Credits: ($4E04) and ($4E02) are 0, ($4E00) increases,
 *           A = 0, HL = $4E00, F is that `inc`.
 *           Host finishes the RET.
 * Clobbers: A, F, HL, and the credit draw
 * Flags live-out: j_3e5c, or the `inc`.
 * Interrupt: returns inside the frame budget.
 * Stack: the call of j_2ba1, then either j_3e5c or the RET.
 */
void j_03fe(Board *b)
{
	uint8_t a;

	call_lifted(b, 0x0401, j_2ba1);
	a = board_mem_read(b, 0x4E6E);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	if (a == 0) {
		j_3e5c(b);
		return;
	}
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = xor_flags(0);
	board_mem_write(b, 0x4E04, 0);
	board_mem_write(b, 0x4E02, 0);
	inc_addr(b, 0x4E00);
}

/* j_03c8  one step of the game mode
 * Entry:    ($4E00) is 0 power-on, 1 attract, 2 press-start, 3 play.
 * Exit:     The selected mode has run. Host finishes the RET.
 * Clobbers: the selected mode
 * Flags live-out: the mode's flags.
 * Interrupt: returns inside the frame budget.
 * Stack: `rst $20`, then the mode.
 */
void j_03c8(Board *b)
{
	uint16_t target;

	Z80_A(b->cpu) = board_mem_read(b, 0x4E00);
	target = rst20(b, 0x03CC);
	switch (target) {
	case 0x03D4:
		j_03d4(b);
		break;
	case 0x03FE:
		j_03fe(b);
		break;
	case 0x05E5:
		j_05e5(b);
		break;
	case 0x06BE:
		j_06be(b);
		break;
	default:
		break;
	}
}
