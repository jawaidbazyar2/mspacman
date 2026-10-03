#include "lift.h"

extern void j_01dc(Board *b);
extern void j_0221(Board *b);
extern void j_0267(Board *b);
extern void j_02ad(Board *b);
extern void j_02fd(Board *b);
extern void j_039d(Board *b);
extern void j_03c8(Board *b);
extern void j_141f(Board *b);
extern void j_1490(Board *b);
extern void j_2cc1(Board *b);
extern void j_2d0c(Board *b);

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

static void push(Board *b, uint16_t value)
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, value);
	Z80_SP(b->cpu) = sp;
}

static uint16_t pop(Board *b)
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

static void ldir(Board *b, uint16_t hl, uint16_t de, uint16_t bc)
{
	while (bc != 0) {
		board_mem_write(b, de, board_mem_read(b, hl));
		hl = (uint16_t)(hl + 1u);
		de = (uint16_t)(de + 1u);
		bc = (uint16_t)(bc - 1u);
	}
}

/* Two `rlca`. The sprite code's top two bits become the bottom two. */
static void rot_sprite(Board *b, uint16_t addr)
{
	uint8_t a = board_mem_read(b, addr);

	a = (uint8_t)((uint8_t)(a << 1) | (uint8_t)(a >> 7));
	a = (uint8_t)((uint8_t)(a << 1) | (uint8_t)(a >> 7));
	board_mem_write(b, addr, a);
}

/* A playing wave supplies the voice select. An idle wave uses the effect. */
static void wave_select(Board *b, uint16_t num, uint16_t sel, uint16_t effect,
			 uint16_t hw)
{
	uint8_t a;

	if (board_mem_read(b, num) != 0)
		a = board_mem_read(b, sel);
	else {
		(void)board_mem_read(b, sel);
		a = board_mem_read(b, effect);
	}
	board_mem_write(b, hw, a);
}

/* Swap the eaten ghost into the first hardware slot. */
static void swap_eaten(Board *b)
{
	uint8_t doubled = (uint8_t)(board_mem_read(b, 0x4DA4) << 1);
	uint16_t ix = (uint16_t)(0x4C20u + doubled);
	uint16_t hl = word_at(b, 0x4C24);
	uint16_t de = word_at(b, 0x4C34);
	uint8_t a;

	a = board_mem_read(b, ix);
	board_mem_write(b, 0x4C24, a);
	a = board_mem_read(b, (uint16_t)(ix + 1u));
	board_mem_write(b, 0x4C25, a);
	a = board_mem_read(b, (uint16_t)(ix + 0x10u));
	board_mem_write(b, 0x4C34, a);
	a = board_mem_read(b, (uint16_t)(ix + 0x11u));
	board_mem_write(b, 0x4C35, a);
	board_mem_write(b, ix, (uint8_t)hl);
	board_mem_write(b, (uint16_t)(ix + 1u), (uint8_t)(hl >> 8));
	board_mem_write(b, (uint16_t)(ix + 0x10u), (uint8_t)de);
	board_mem_write(b, (uint16_t)(ix + 0x11u), (uint8_t)(de >> 8));
}

/* Swap Ms. Pac into the first sprite while a power pill is active. */
static void swap_pill(Board *b)
{
	uint16_t bc = word_at(b, 0x4C22);
	uint16_t de = word_at(b, 0x4C32);
	uint16_t hl = word_at(b, 0x4C2A);

	write_word(b, 0x4C22, hl);
	hl = word_at(b, 0x4C3A);
	write_word(b, 0x4C32, hl);
	write_word(b, 0x4C2A, bc);
	write_word(b, 0x4C3A, de);
}

/* j_008d  one vertical blank
 * Entry:    Reached by the jump at $1FA2 after `ld a,i` finds I nonzero.
 *           SP holds the interrupted return. A clear I does not arrive
 *           here; that fork enters the self-test at $3000.
 * Exit:     Sound bytes are copied to the voice hardware and the sprite
 *           buffer is copied to sprite RAM. Timers, the game mode, and
 *           the sound engine have run. Demo mode clears two effect
 *           channels first. A is 1 at the interrupt latch, then AF is
 *           restored. Interrupts are enabled. SP is back at the return.
 *           Host finishes the RET. The service switch sets PC to
 *           $0000 and does not return.
 * Clobbers: nothing that survives the pops. IFF1 and IFF2 are set.
 * Flags live-out: the interrupted flags, restored by `pop af`.
 * Interrupt: returns inside the frame budget.
 * Stack: six words are pushed and popped. Each call leaves its return.
 */
void j_008d(Board *b)
{
	uint8_t mode;
	uint8_t in1;

	push(b, Z80_AF(b->cpu));
	board_mem_write(b, 0x50C0, Z80_A(b->cpu));
	Z80_A(b->cpu) = 0;
	board_mem_write(b, 0x5000, 0);
	b->cpu.iff1 = 0;
	b->cpu.iff2 = 0;
	push(b, Z80_BC(b->cpu));
	push(b, Z80_DE(b->cpu));
	push(b, Z80_HL(b->cpu));
	push(b, Z80_IX(b->cpu));
	push(b, Z80_IY(b->cpu));

	ldir(b, 0x4E8C, 0x5050, 0x0010);
	wave_select(b, 0x4ECC, 0x4ECF, 0x4E9F, 0x5045);
	wave_select(b, 0x4EDC, 0x4EDF, 0x4EAF, 0x504A);
	wave_select(b, 0x4EEC, 0x4EEF, 0x4EBF, 0x504F);

	ldir(b, 0x4C02, 0x4C22, 0x001C);
	rot_sprite(b, 0x4C22);
	rot_sprite(b, 0x4C24);
	rot_sprite(b, 0x4C26);
	rot_sprite(b, 0x4C28);
	rot_sprite(b, 0x4C2A);
	rot_sprite(b, 0x4C2C);
	if (board_mem_read(b, 0x4DD1) == 1)
		swap_eaten(b);
	if (board_mem_read(b, 0x4DA6) != 0)
		swap_pill(b);
	ldir(b, 0x4C22, 0x4FF2, 0x000C);
	ldir(b, 0x4C32, 0x5062, 0x000C);

	call_lifted(b, 0x018F, j_01dc);
	call_lifted(b, 0x0192, j_0221);
	call_lifted(b, 0x0195, j_03c8);
	mode = board_mem_read(b, 0x4E00);
	if (mode != 0) {
		call_lifted(b, 0x019E, j_039d);
		call_lifted(b, 0x01A1, j_1490);
		call_lifted(b, 0x01A4, j_141f);
		call_lifted(b, 0x01A7, j_0267);
		call_lifted(b, 0x01AA, j_02ad);
		call_lifted(b, 0x01AD, j_02fd);
	}
	mode = board_mem_read(b, 0x4E00);
	if (mode == 1) {
		board_mem_write(b, 0x4EAC, 0);
		board_mem_write(b, 0x4EBC, 0);
	}
	call_lifted(b, 0x01BC, j_2d0c);
	call_lifted(b, 0x01BF, j_2cc1);

	Z80_IY(b->cpu) = pop(b);
	Z80_IX(b->cpu) = pop(b);
	Z80_HL(b->cpu) = pop(b);
	Z80_DE(b->cpu) = pop(b);
	Z80_BC(b->cpu) = pop(b);

	mode = board_mem_read(b, 0x4E00);
	if (mode != 0) {
		in1 = board_mem_read(b, 0x5040);
		if ((in1 & 0x10u) == 0) {
			Z80_PC(b->cpu) = 0;
			Z80_MEMPTR(b->cpu) = 0;
			b->cpu.data.uint8_array[0] = 0xCA;
			return;
		}
	}
	board_mem_write(b, 0x5000, 1);
	b->cpu.iff1 = 1;
	b->cpu.iff2 = 1;
	Z80_AF(b->cpu) = pop(b);
}

static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

static uint8_t or_flags(uint8_t result)
{
	return (uint8_t)(parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

static void mark(Board *b, uint8_t opcode, uint16_t pc)
{
	b->cpu.data.uint8_array[0] = opcode;
	Z80_PC(b->cpu) = pc;
}

static void charge(Board *b, zusize ran)
{
	if (ran >= b->cycles_left)
		b->cycles_left = 0;
	else
		b->cycles_left -= ran;
}

static int fork_pc(uint16_t pc)
{
	return pc == 0x0038 || pc == 0x1F9B || pc == 0x1F9C || pc == 0x1F9E ||
	       pc == 0x1F9F || pc == 0x1FA1 || pc == 0x1FA2 || pc == 0x1FA5 ||
	       pc == 0x1FA6;
}

/* Clear I: push AF, test I, pop AF, and jump to the self-test.
 * The slice stops with PC at $3000. The host fetches that span. */
void j_0038_clear(Board *b)
{
	int guard = 0;

	while (b->cycles_left > 0 && guard++ < 2000000) {
		uint16_t pc = Z80_PC(b->cpu);
		zusize ran = 0;
		uint8_t a;
		uint8_t flags;

		if (!fork_pc(pc))
			return;
		switch (pc) {
		case 0x0038:
			Z80_MEMPTR(b->cpu) = 0x1F9B;
			mark(b, 0xC3, 0x1F9B);
			ran = 10;
			break;
		case 0x1F9B:
			push(b, Z80_AF(b->cpu));
			mark(b, 0xF5, 0x1F9C);
			ran = 11;
			break;
		case 0x1F9C:
			a = b->cpu.i;
			flags = (uint8_t)((a & 0xA8u) |
					  (a == 0 ? 0x40u : 0u) |
					  (uint8_t)((b->cpu.iff2 & 1u) << 2) |
					  (Z80_F(b->cpu) & 0x01u));
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			b->cpu.data.uint8_array[0] = 0xED;
			b->cpu.data.uint8_array[1] = 0x57;
			Z80_PC(b->cpu) = 0x1F9E;
			ran = 9;
			break;
		case 0x1F9E:
			a = Z80_A(b->cpu);
			Z80_F(b->cpu) = or_flags(a);
			mark(b, 0xB7, 0x1F9F);
			ran = 4;
			break;
		case 0x1F9F:
			b->cpu.data.uint8_array[0] = 0x28;
			if ((Z80_F(b->cpu) & 0x40u) != 0) {
				Z80_PC(b->cpu) = 0x1FA5;
				Z80_MEMPTR(b->cpu) = 0x1FA5;
				ran = 12;
			} else {
				Z80_PC(b->cpu) = 0x1FA1;
				ran = 7;
			}
			break;
		case 0x1FA1:
			Z80_AF(b->cpu) = pop(b);
			mark(b, 0xF1, 0x1FA2);
			ran = 10;
			break;
		case 0x1FA2:
			Z80_MEMPTR(b->cpu) = 0x008D;
			mark(b, 0xC3, 0x008D);
			ran = 10;
			break;
		case 0x1FA5:
			Z80_AF(b->cpu) = pop(b);
			mark(b, 0xF1, 0x1FA6);
			ran = 10;
			break;
		case 0x1FA6:
			Z80_MEMPTR(b->cpu) = 0x3000;
			mark(b, 0xC3, 0x3000);
			ran = 10;
			break;
		default:
			return;
		}
		charge(b, ran);
	}
}

/* Nonzero I. The test of I pops the saved AF, then j_008d runs.
 * Host finishes the RET at the end of j_008d. */
static void fork_run(Board *b)
{
	uint8_t a = b->cpu.i;
	uint8_t flags = (uint8_t)((a & 0xA8u) |
				  (a == 0 ? 0x40u : 0u) |
				  (uint8_t)((b->cpu.iff2 & 1u) << 2) |
				  (Z80_F(b->cpu) & 0x01u));

	push(b, Z80_AF(b->cpu));
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_F(b->cpu) = or_flags(a);
	Z80_AF(b->cpu) = pop(b);
	j_008d(b);
}

/* j_0038  interrupt mode 1 entry
 * Entry:    The hardware interrupt pushed the return. I is clear only
 *           on the first accept, and that path is the clear-I stepper.
 * Exit:     j_008d has run. Host finishes its RET.
 * Clobbers: nothing that survives j_008d.
 * Flags live-out: the interrupted flags.
 * Interrupt: returns inside the frame budget when I is set.
 * Stack: the fork's push is popped. j_008d balances its own pushes.
 */
void j_0038(Board *b)
{
	fork_run(b);
}

/* j_1f9b  the same fork, entered at the push
 * Entry:    AF is the interrupted pair. I is nonzero on this path.
 * Exit:     same as j_0038.
 * Clobbers: nothing that survives j_008d.
 * Flags live-out: the interrupted flags.
 * Interrupt: returns inside the frame budget when I is set.
 * Stack: one push, popped, then j_008d.
 */
void j_1f9b(Board *b)
{
	fork_run(b);
}
