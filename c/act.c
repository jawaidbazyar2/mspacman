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
