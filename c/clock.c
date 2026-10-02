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

/* j_01dc  advance the sound counters and the frame timers
 * Entry:    ($4C84) and ($4C85) are the sound counters.
 *           ($4C86) onward are the limit counters. The table is at $0219.
 *           ($4C8B) and ($4C8C) are the two running timers.
 * Exit:     ($4C84) increments. ($4C85) decrements.
 *           Each limit counter increments. While its low nibble matches the
 *           table, C increments, the high nibble steps by $10, and a second
 *           table match clears the counter and advances both pointers.
 *           B counts those pairs down from 4. C starts at 1.
 *           ($4C8A) = C. ($4C8B) = 5 * old + 1. ($4C8C) = 13 * old + 1.
 *           HL = $4C8C. A is the new $4C8C byte. F is that final `inc a`,
 *           whose carry is the carry from the last `add`.
 *           DE and BC are whatever the table walk left behind.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: none. The caller tests the next task with a fresh `and a`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_01dc(Board *b)
{
	uint16_t hl = 0x4C84;
	uint16_t de = 0x0219;
	uint16_t swap;
	uint8_t breg = 4;
	uint8_t creg = 1;
	uint8_t a;
	uint8_t cur;
	uint8_t flags = 0;
	uint8_t orig;

	cur = (uint8_t)(board_mem_read(b, hl) + 1u);
	board_mem_write(b, hl, cur);
	hl = 0x4C85;
	cur = (uint8_t)(board_mem_read(b, hl) - 1u);
	board_mem_write(b, hl, cur);
	hl = 0x4C86;
	for (;;) {
		cur = (uint8_t)(board_mem_read(b, hl) + 1u);
		board_mem_write(b, hl, cur);
		a = (uint8_t)(cur & 0x0Fu);
		swap = hl;
		hl = de;
		de = swap;
		if (a != board_mem_read(b, hl))
			break;
		creg = (uint8_t)(creg + 1u);
		a = board_mem_read(b, de);
		a = (uint8_t)((uint8_t)(a + 0x10u) & 0xF0u);
		board_mem_write(b, de, a);
		hl = (uint16_t)(hl + 1u);
		if (a != board_mem_read(b, hl))
			break;
		creg = (uint8_t)(creg + 1u);
		swap = hl;
		hl = de;
		de = swap;
		board_mem_write(b, hl, 0);
		hl = (uint16_t)(hl + 1u);
		de = (uint16_t)(de + 1u);
		breg = (uint8_t)(breg - 1u);
		if (breg == 0)
			break;
	}
	board_mem_write(b, 0x4C8A, creg);
	orig = board_mem_read(b, 0x4C8B);
	a = add_a(orig, orig, &flags);
	a = add_a(a, a, &flags);
	a = add_a(a, orig, &flags);
	board_mem_write(b, 0x4C8B, (uint8_t)(a + 1u));
	orig = board_mem_read(b, 0x4C8C);
	a = add_a(orig, orig, &flags);
	a = add_a(a, orig, &flags);
	a = add_a(a, a, &flags);
	a = add_a(a, a, &flags);
	a = add_a(a, orig, &flags);
	flags = inc_a_flags(a, flags, &a);
	board_mem_write(b, 0x4C8C, a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = 0x4C8C;
	Z80_DE(b->cpu) = de;
	Z80_B(b->cpu) = breg;
	Z80_C(b->cpu) = creg;
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

/* `or r`. HF, NF, and CF clear. */
static uint8_t or_flags(uint8_t value)
{
	return (uint8_t)(parity_pv(value) | (value & 0xA8u) |
			 (value == 0 ? 0x40u : 0u));
}

static void charge_delay(Board *b, zusize ran)
{
	if (ran >= b->cycles_left)
		b->cycles_left = 0;
	else
		b->cycles_left -= ran;
}

static void delay_ret(Board *b)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t lo = board_mem_read(b, sp);
	uint16_t hi = board_mem_read(b, (uint16_t)(sp + 1u));
	uint16_t ret = (uint16_t)(lo | (uint16_t)(hi << 8));

	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	Z80_PC(b->cpu) = ret;
	Z80_MEMPTR(b->cpu) = ret;
}

/* j_32ed  pause used by the crosshatch and the Namco egg
 * Entry:    A is the caller's. Also resumed at $32F0, $32F3, $32F4,
 *           $32F5, $32F6, or $32F8 when the previous frame stopped
 *           inside the countdown. Interrupts are off on the crosshatch.
 * Exit:     The $32ED entry stores A at the watchdog ($50C0) and loads
 *           HL with $2800. Each following trip is `dec hl` / `ld a,h` /
 *           `or l` / `jr nz`, 26 cycles. The prologue is 23 cycles and
 *           the finishing trip plus RET is 31. The whole call is
 *           266268 cycles, which spans about five frames of 50688.
 *           This returns when the frame budget runs out, leaving PC on
 *           the next instruction of the countdown. The slice that
 *           reaches RET performs it.
 *           WZ after the watchdog store is (A << 8) | $C1. A taken JR
 *           sets WZ to $32F3. RET sets WZ to the return address.
 * Clobbers: A, F, HL. The finishing slice also pops the return.
 * Flags live-out: Z set and A = HL = 0 when the countdown finishes.
 *           The crosshatch only counts B. The egg reloads A from IN0.
 * Interrupt: returns inside the frame budget. The call itself covers
 *           several frames, resumed from the opcode where it stopped.
 * Stack: one RET, on the finishing slice. No callee.
 */
void j_32ed(Board *b)
{
	int guard = 0;

	while (b->cycles_left > 0 && guard++ < 2000000) {
		uint16_t pc = Z80_PC(b->cpu);
		zusize ran = 0;
		int done = 0;

		switch (pc) {
		case 0x32ED: {
			uint8_t a = Z80_A(b->cpu);

			Z80_MEMPTR(b->cpu) = (uint16_t)(((unsigned)a << 8) | 0xC1u);
			board_mem_write(b, 0x50C0, a);
			Z80_PC(b->cpu) = 0x32F0;
			ran = 13;
			break;
		}
		case 0x32F0:
			Z80_HL(b->cpu) = 0x2800;
			Z80_PC(b->cpu) = 0x32F3;
			ran = 10;
			break;
		case 0x32F3:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) - 1u);
			Z80_PC(b->cpu) = 0x32F4;
			ran = 6;
			break;
		case 0x32F4:
			Z80_A(b->cpu) = (uint8_t)(Z80_HL(b->cpu) >> 8);
			Z80_PC(b->cpu) = 0x32F5;
			ran = 4;
			break;
		case 0x32F5: {
			uint8_t a = (uint8_t)(Z80_A(b->cpu) | (uint8_t)Z80_HL(b->cpu));

			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = or_flags(a);
			Z80_PC(b->cpu) = 0x32F6;
			ran = 4;
			break;
		}
		case 0x32F6:
			if ((Z80_F(b->cpu) & 0x40u) == 0) {
				Z80_PC(b->cpu) = 0x32F3;
				Z80_MEMPTR(b->cpu) = 0x32F3;
				ran = 12;
			} else {
				Z80_PC(b->cpu) = 0x32F8;
				ran = 7;
			}
			break;
		case 0x32F8:
			delay_ret(b);
			ran = 10;
			done = 1;
			break;
		default:
			return;
		}
		charge_delay(b, ran);
		if (done)
			return;
	}
}
