#include "dispatch.h"
#include "lift.h"

/* Power-on, from j_0000 through the halt, and j_234b through the
 * fall into the scheduler at $238D. A slice stops when the budget
 * runs out, or when PC leaves this span: the calls to j_240d and
 * j_23ed, the byte after ei, or an interrupt accept. rst $08 stays
 * inside the slice. Its opcodes are not stolen, so a fill that
 * crosses a frame finishes as Z80 and the boot span resumes at the
 * return. The halt sets resume and leaves PC on $234B. The host
 * accepts the interrupt before that byte is fetched. */

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

static uint8_t and_flags(uint8_t result)
{
	return (uint8_t)(0x10u | parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

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

static void push_word(Board *b, uint16_t *sp, uint16_t value)
{
	*sp = (uint16_t)(*sp - 2u);
	board_mem_write(b, (uint16_t)(*sp + 1u), (uint8_t)(value >> 8));
	board_mem_write(b, *sp, (uint8_t)value);
}

static uint16_t pop_word(Board *b)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t lo = board_mem_read(b, sp);
	uint16_t hi = board_mem_read(b, (uint16_t)(sp + 1u));

	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	return (uint16_t)(lo | (uint16_t)(hi << 8));
}

static void mark(Board *b, uint8_t opcode, uint16_t pc)
{
	b->cpu.data.uint8_array[0] = opcode;
	Z80_PC(b->cpu) = pc;
}

static void store_a(Board *b, uint16_t addr)
{
	uint8_t a = Z80_A(b->cpu);

	Z80_MEMPTR(b->cpu) = (uint16_t)(((uint16_t)a << 8) |
					(uint8_t)(addr + 1u));
	board_mem_write(b, addr, a);
}

static void set_l(Board *b, uint8_t l)
{
	Z80_HL(b->cpu) = (uint16_t)((Z80_HL(b->cpu) & 0xFF00u) | l);
}

static void set_h(Board *b, uint8_t h)
{
	Z80_HL(b->cpu) = (uint16_t)((Z80_HL(b->cpu) & 0x00FFu) |
				    (uint16_t)((uint16_t)h << 8));
}

static void ld_hl_a(Board *b, uint16_t next)
{
	board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
	mark(b, 0x77, next);
}

static void inc_l(Board *b, uint16_t next)
{
	uint8_t l;
	uint8_t flags = inc8((uint8_t)Z80_HL(b->cpu), Z80_F(b->cpu), &l);

	set_l(b, l);
	Z80_F(b->cpu) = flags;
	mark(b, 0x2C, next);
}

static void inc_h(Board *b, uint16_t next)
{
	uint8_t h;
	uint8_t flags = inc8((uint8_t)(Z80_HL(b->cpu) >> 8), Z80_F(b->cpu), &h);

	set_h(b, h);
	Z80_F(b->cpu) = flags;
	mark(b, 0x24, next);
}

static void xor_a(Board *b, uint16_t next)
{
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = or_flags(0);
	mark(b, 0xAF, next);
}

static void jp_abs(Board *b, uint16_t dest)
{
	b->cpu.data.uint8_array[0] = 0xC3;
	Z80_PC(b->cpu) = dest;
	Z80_MEMPTR(b->cpu) = dest;
}

static zusize jr_nz(Board *b, uint16_t dest, uint16_t next)
{
	b->cpu.data.uint8_array[0] = 0x20;
	if ((Z80_F(b->cpu) & 0x40u) == 0) {
		Z80_PC(b->cpu) = dest;
		Z80_MEMPTR(b->cpu) = dest;
		return 12;
	}
	Z80_PC(b->cpu) = next;
	return 7;
}

static zusize djnz_to(Board *b, uint16_t dest, uint16_t next)
{
	uint8_t breg = (uint8_t)(Z80_B(b->cpu) - 1u);

	Z80_B(b->cpu) = breg;
	b->cpu.data.uint8_array[0] = 0x10;
	if (breg != 0) {
		Z80_PC(b->cpu) = dest;
		Z80_MEMPTR(b->cpu) = dest;
		return 13;
	}
	Z80_PC(b->cpu) = next;
	return 8;
}

static void call_to(Board *b, uint16_t dest, uint16_t ret)
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, ret);
	Z80_SP(b->cpu) = sp;
	b->cpu.data.uint8_array[0] = 0xCD;
	Z80_PC(b->cpu) = dest;
	Z80_MEMPTR(b->cpu) = dest;
}

static void rst8(Board *b)
{
	uint16_t pc = Z80_PC(b->cpu);
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, (uint16_t)(pc + 1u));
	Z80_SP(b->cpu) = sp;
	b->cpu.data.uint8_array[0] = 0xCF;
	Z80_PC(b->cpu) = 0x0008;
	Z80_MEMPTR(b->cpu) = 0x0008;
}

static void enable_int(Board *b, uint16_t next)
{
	b->cpu.iff1 = 1;
	b->cpu.iff2 = 1;
	if (b->cpu.int_line)
		b->cpu.request = (uint8_t)(b->cpu.request | Z80_REQUEST_INT);
	mark(b, 0xFB, next);
}

static void charge(Board *b, zusize ran)
{
	if (ran >= b->cycles_left)
		b->cycles_left = 0;
	else
		b->cycles_left -= ran;
}

static int accept_int(Board *b)
{
	uint16_t sp;

	if ((b->cpu.request & Z80_REQUEST_INT) == 0)
		return 0;
	if (b->cpu.data.uint8_array[0] == 0xFB)
		return 0;
	b->cpu.request = 0;
	b->cpu.iff1 = 0;
	b->cpu.iff2 = 0;
	if (b->cpu.halt_line)
		b->cpu.halt_line = 0;
	sp = Z80_SP(b->cpu);
	push_word(b, &sp, Z80_PC(b->cpu));
	Z80_SP(b->cpu) = sp;
	Z80_PC(b->cpu) = 0x0038;
	Z80_MEMPTR(b->cpu) = 0x0038;
	b->cpu.data.uint8_array[0] = 0;
	return 1;
}

/* One halted z80_run(1). The halt opcode itself only arms resume.
 * The following step raises the halt line, or accepts the interrupt. */
static zusize halt_wake(Board *b)
{
	if (b->cpu.request & Z80_REQUEST_INT) {
		b->cpu.resume = 0;
		accept_int(b);
		return 13;
	}
	b->cpu.halt_line = 1;
	return 4;
}

static int boot_code(uint16_t pc)
{
	if (c_boot_pc(pc))
		return 1;
	return pc == 0x0008 || pc == 0x0009 || pc == 0x000A || pc == 0x000C;
}

int c_boot_pc(uint16_t pc)
{
	if (pc <= 0x0005)
		return 1;
	if (pc >= 0x230B && pc <= 0x238C)
		return 1;
	return 0;
}

int c_boot_inside(Board *b)
{
	if (b->cpu.resume == Z80_RESUME_HALT)
		return 1;
	return boot_code(Z80_PC(b->cpu));
}

/* j_0000  power-on, and the j_234b continuation
 * Entry:    Reset fetches $0000. A later slice resumes at the opcode
 *           the budget left PC on, including j_230b and j_234b.
 *           j_234b is also fetched when the self-test jumps to it.
 * Exit:     One slice. The halt arms resume and leaves PC on $234B.
 *           The calls leave PC on j_240d or j_23ed. ei at $238C leaves
 *           PC on $238D.
 * Clobbers: whatever the slice executed.
 * Flags live-out: the flags of the last instruction in the slice.
 * Interrupt: held off from the opening di until ei. The halt is the
 *           instruction after ei, so it runs, then the host accepts.
 * Stack: rst $08 and the two calls push a return and leave it.
 */
void j_0000(Board *b)
{
	int guard = 0;

	while (b->cycles_left > 0 && guard++ < 2000000) {
		uint16_t pc = Z80_PC(b->cpu);
		zusize ran = 0;
		uint8_t a;
		uint8_t flags;

		if (b->cpu.resume == Z80_RESUME_HALT) {
			charge(b, halt_wake(b));
			continue;
		}
		if (!boot_code(pc))
			return;
		if (accept_int(b)) {
			charge(b, 13);
			continue;
		}
		switch (pc) {
		case 0x0000:
			b->cpu.iff1 = 0;
			b->cpu.iff2 = 0;
			b->cpu.request = (uint8_t)(b->cpu.request &
						    (uint8_t)~Z80_REQUEST_INT);
			mark(b, 0xF3, 0x0001);
			ran = 4;
			break;
		case 0x0001:
			Z80_A(b->cpu) = 0;
			mark(b, 0x3E, 0x0003);
			ran = 7;
			break;
		case 0x0003:
			b->cpu.i = Z80_A(b->cpu);
			b->cpu.data.uint8_array[0] = 0xED;
			b->cpu.data.uint8_array[1] = 0x47;
			Z80_PC(b->cpu) = 0x0005;
			ran = 9;
			break;
		case 0x0005:
			jp_abs(b, 0x230B);
			ran = 10;
			break;
		case 0x0008:
			ld_hl_a(b, 0x0009);
			ran = 7;
			break;
		case 0x0009:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			mark(b, 0x23, 0x000A);
			ran = 6;
			break;
		case 0x000A:
			ran = djnz_to(b, 0x0008, 0x000C);
			break;
		case 0x000C: {
			uint16_t ret = pop_word(b);

			Z80_PC(b->cpu) = ret;
			Z80_MEMPTR(b->cpu) = ret;
			b->cpu.data.uint8_array[0] = 0xC9;
			ran = 10;
			break;
		}
		case 0x230B:
			Z80_HL(b->cpu) = 0x5000;
			mark(b, 0x21, 0x230E);
			ran = 10;
			break;
		case 0x230E:
			Z80_B(b->cpu) = 0x08;
			mark(b, 0x06, 0x2310);
			ran = 7;
			break;
		case 0x2310:
			xor_a(b, 0x2311);
			ran = 4;
			break;
		case 0x2311:
			ld_hl_a(b, 0x2312);
			ran = 7;
			break;
		case 0x2312:
			inc_l(b, 0x2313);
			ran = 4;
			break;
		case 0x2313:
			ran = djnz_to(b, 0x2311, 0x2315);
			break;
		case 0x2315:
			Z80_HL(b->cpu) = 0x4000;
			mark(b, 0x21, 0x2318);
			ran = 10;
			break;
		case 0x2318:
			Z80_B(b->cpu) = 0x04;
			mark(b, 0x06, 0x231A);
			ran = 7;
			break;
		case 0x231A:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x231D);
			ran = 13;
			break;
		case 0x231D:
			store_a(b, 0x5007);
			mark(b, 0x32, 0x2320);
			ran = 13;
			break;
		case 0x2320:
			Z80_A(b->cpu) = 0x40;
			mark(b, 0x3E, 0x2322);
			ran = 7;
			break;
		case 0x2322:
			ld_hl_a(b, 0x2323);
			ran = 7;
			break;
		case 0x2323:
			inc_l(b, 0x2324);
			ran = 4;
			break;
		case 0x2324:
			ran = jr_nz(b, 0x2322, 0x2326);
			break;
		case 0x2326:
			inc_h(b, 0x2327);
			ran = 4;
			break;
		case 0x2327:
			ran = djnz_to(b, 0x231A, 0x2329);
			break;
		case 0x2329:
			Z80_B(b->cpu) = 0x04;
			mark(b, 0x06, 0x232B);
			ran = 7;
			break;
		case 0x232B:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x232E);
			ran = 13;
			break;
		case 0x232E:
			xor_a(b, 0x232F);
			ran = 4;
			break;
		case 0x232F:
			store_a(b, 0x5007);
			mark(b, 0x32, 0x2332);
			ran = 13;
			break;
		case 0x2332:
			Z80_A(b->cpu) = 0x0F;
			mark(b, 0x3E, 0x2334);
			ran = 7;
			break;
		case 0x2334:
			ld_hl_a(b, 0x2335);
			ran = 7;
			break;
		case 0x2335:
			inc_l(b, 0x2336);
			ran = 4;
			break;
		case 0x2336:
			ran = jr_nz(b, 0x2334, 0x2338);
			break;
		case 0x2338:
			inc_h(b, 0x2339);
			ran = 4;
			break;
		case 0x2339:
			ran = djnz_to(b, 0x232B, 0x233B);
			break;
		case 0x233B:
			b->cpu.im = 1;
			b->cpu.data.uint8_array[0] = 0xED;
			b->cpu.data.uint8_array[1] = 0x56;
			Z80_PC(b->cpu) = 0x233D;
			ran = 8;
			break;
		case 0x233D:
		case 0x233E:
		case 0x233F:
		case 0x2340:
			mark(b, 0x00, (uint16_t)(pc + 1u));
			ran = 4;
			break;
		case 0x2341:
			xor_a(b, 0x2342);
			ran = 4;
			break;
		case 0x2342:
			store_a(b, 0x5007);
			mark(b, 0x32, 0x2345);
			ran = 13;
			break;
		case 0x2345:
			flags = inc8(Z80_A(b->cpu), Z80_F(b->cpu), &a);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x3C, 0x2346);
			ran = 4;
			break;
		case 0x2346:
			store_a(b, 0x5000);
			mark(b, 0x32, 0x2349);
			ran = 13;
			break;
		case 0x2349:
			enable_int(b, 0x234A);
			ran = 4;
			break;
		case 0x234A:
			b->cpu.resume = Z80_RESUME_HALT;
			mark(b, 0x76, 0x234B);
			ran = 4;
			break;
		case 0x234B:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x234E);
			ran = 13;
			break;
		case 0x234E:
			Z80_SP(b->cpu) = 0x4FC0;
			mark(b, 0x31, 0x2351);
			ran = 10;
			break;
		case 0x2351:
			xor_a(b, 0x2352);
			ran = 4;
			break;
		case 0x2352:
			Z80_HL(b->cpu) = 0x5000;
			mark(b, 0x21, 0x2355);
			ran = 10;
			break;
		case 0x2355:
			Z80_BC(b->cpu) = 0x0808;
			mark(b, 0x01, 0x2358);
			ran = 10;
			break;
		case 0x2358:
		case 0x235E:
		case 0x235F:
		case 0x2360:
		case 0x2361:
		case 0x2367:
		case 0x2386:
			rst8(b);
			ran = 11;
			break;
		case 0x2359:
			Z80_HL(b->cpu) = 0x4C00;
			mark(b, 0x21, 0x235C);
			ran = 10;
			break;
		case 0x235C:
			Z80_B(b->cpu) = 0xBE;
			mark(b, 0x06, 0x235E);
			ran = 7;
			break;
		case 0x2362:
			Z80_HL(b->cpu) = 0x5040;
			mark(b, 0x21, 0x2365);
			ran = 10;
			break;
		case 0x2365:
			Z80_B(b->cpu) = 0x40;
			mark(b, 0x06, 0x2367);
			ran = 7;
			break;
		case 0x2368:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x236B);
			ran = 13;
			break;
		case 0x236B:
			call_to(b, 0x240D, 0x236E);
			ran = 17;
			break;
		case 0x236E:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x2371);
			ran = 13;
			break;
		case 0x2371:
			Z80_B(b->cpu) = 0;
			mark(b, 0x06, 0x2373);
			ran = 7;
			break;
		case 0x2373:
			call_to(b, 0x23ED, 0x2376);
			ran = 17;
			break;
		case 0x2376:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x2379);
			ran = 13;
			break;
		case 0x2379:
			Z80_HL(b->cpu) = 0x4CC0;
			mark(b, 0x21, 0x237C);
			ran = 10;
			break;
		case 0x237C:
			board_mem_write(b, 0x4C80, (uint8_t)Z80_HL(b->cpu));
			board_mem_write(b, 0x4C81, (uint8_t)(Z80_HL(b->cpu) >> 8));
			Z80_MEMPTR(b->cpu) = 0x4C81;
			mark(b, 0x22, 0x237F);
			ran = 16;
			break;
		case 0x237F:
			board_mem_write(b, 0x4C82, (uint8_t)Z80_HL(b->cpu));
			board_mem_write(b, 0x4C83, (uint8_t)(Z80_HL(b->cpu) >> 8));
			Z80_MEMPTR(b->cpu) = 0x4C83;
			mark(b, 0x22, 0x2382);
			ran = 16;
			break;
		case 0x2382:
			Z80_A(b->cpu) = 0xFF;
			mark(b, 0x3E, 0x2384);
			ran = 7;
			break;
		case 0x2384:
			Z80_B(b->cpu) = 0x40;
			mark(b, 0x06, 0x2386);
			ran = 7;
			break;
		case 0x2387:
			Z80_A(b->cpu) = 0x01;
			mark(b, 0x3E, 0x2389);
			ran = 7;
			break;
		case 0x2389:
			store_a(b, 0x5000);
			mark(b, 0x32, 0x238C);
			ran = 13;
			break;
		case 0x238C:
			enable_int(b, 0x238D);
			ran = 4;
			break;
		default:
			fprintf(stderr, "boot: unhandled %04X\n", pc);
			return;
		}
		if (ran == 0)
			return;
		charge(b, ran);
	}
}

static void set_e(Board *b, uint8_t e)
{
	Z80_DE(b->cpu) = (uint16_t)((Z80_DE(b->cpu) & 0xFF00u) | e);
}

static void set_d(Board *b, uint8_t d)
{
	Z80_DE(b->cpu) = (uint16_t)((Z80_DE(b->cpu) & 0x00FFu) |
				    (uint16_t)((uint16_t)d << 8));
}

static zusize jp_m(Board *b, uint16_t dest, uint16_t next)
{
	b->cpu.data.uint8_array[0] = 0xFA;
	Z80_MEMPTR(b->cpu) = dest;
	Z80_PC(b->cpu) = (Z80_F(b->cpu) & 0x80u) ? dest : next;
	return 10;
}

static void rst_n(Board *b, uint8_t opcode, uint16_t dest)
{
	uint16_t pc = Z80_PC(b->cpu);
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, (uint16_t)(pc + 1u));
	Z80_SP(b->cpu) = sp;
	b->cpu.data.uint8_array[0] = opcode;
	Z80_PC(b->cpu) = dest;
	Z80_MEMPTR(b->cpu) = dest;
}

int c_sched_pc(uint16_t pc)
{
	return pc >= 0x238D && pc <= 0x23A7;
}

/* The rst $20 / rst $10 bytes are stepped here and are not stolen.
 * A slice that ends inside them resumes as Z80, then the task fetch
 * is the lifted entry. */
int c_sched_inside(Board *b)
{
	uint16_t pc = Z80_PC(b->cpu);

	if (c_sched_pc(pc))
		return 1;
	if (pc >= 0x0020 && pc <= 0x0027)
		return 1;
	return pc == 0x0010 || pc == 0x0011 || pc == 0x0012 || pc == 0x0014 ||
	       pc == 0x0015 || pc == 0x0016 || pc == 0x0017;
}

/* j_238d  dispatch one waiting task
 * Entry:    Fetched at $238D only when the head byte is nonnegative,
 *           or resumed on a later opcode of this dispatch. The idle
 *           fetch of $238D is the frame boundary and is not stolen.
 * Exit:     One slice. PC is the rst $20 target. $238D is on the
 *           stack for the task's RET. The host fetches the target.
 * Clobbers: A, F, B, DE, HL.
 * Flags live-out: the `adc a,h` inside rst $10.
 * Interrupt: returns inside the frame budget. The idle spin is not
 *           this function.
 * Stack: pushes $238D, then the rst $20 and rst $10 returns, which
 *        this slice pops. $238D stays.
 */
void j_238d(Board *b)
{
	int guard = 0;

	while (b->cycles_left > 0 && guard++ < 2000000) {
		uint16_t pc = Z80_PC(b->cpu);
		zusize ran = 0;
		uint8_t a;
		uint8_t flags;
		uint16_t hl;

		if (!c_sched_inside(b))
			return;
		switch (pc) {
		case 0x238D:
			hl = board_mem_read(b, 0x4C82);
			hl = (uint16_t)(hl | (uint16_t)((uint16_t)board_mem_read(b, 0x4C83) << 8));
			Z80_HL(b->cpu) = hl;
			Z80_MEMPTR(b->cpu) = 0x4C83;
			mark(b, 0x2A, 0x2390);
			ran = 16;
			break;
		case 0x2390:
			Z80_A(b->cpu) = board_mem_read(b, Z80_HL(b->cpu));
			mark(b, 0x7E, 0x2391);
			ran = 7;
			break;
		case 0x2391:
			a = Z80_A(b->cpu);
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xA7, 0x2392);
			ran = 4;
			break;
		case 0x2392:
			ran = jp_m(b, 0x238D, 0x2395);
			break;
		case 0x2395:
			board_mem_write(b, Z80_HL(b->cpu), 0xFF);
			mark(b, 0x36, 0x2397);
			ran = 10;
			break;
		case 0x2397:
			inc_l(b, 0x2398);
			ran = 4;
			break;
		case 0x2398:
			Z80_B(b->cpu) = board_mem_read(b, Z80_HL(b->cpu));
			mark(b, 0x46, 0x2399);
			ran = 7;
			break;
		case 0x2399:
			board_mem_write(b, Z80_HL(b->cpu), 0xFF);
			mark(b, 0x36, 0x239B);
			ran = 10;
			break;
		case 0x239B:
			inc_l(b, 0x239C);
			ran = 4;
			break;
		case 0x239C:
			ran = jr_nz(b, 0x23A0, 0x239E);
			break;
		case 0x239E:
			set_l(b, 0xC0);
			mark(b, 0x2E, 0x23A0);
			ran = 7;
			break;
		case 0x23A0:
			board_mem_write(b, 0x4C82, (uint8_t)Z80_HL(b->cpu));
			board_mem_write(b, 0x4C83, (uint8_t)(Z80_HL(b->cpu) >> 8));
			Z80_MEMPTR(b->cpu) = 0x4C83;
			mark(b, 0x22, 0x23A3);
			ran = 16;
			break;
		case 0x23A3:
			Z80_HL(b->cpu) = 0x238D;
			mark(b, 0x21, 0x23A6);
			ran = 10;
			break;
		case 0x23A6: {
			uint16_t sp = Z80_SP(b->cpu);

			push_word(b, &sp, Z80_HL(b->cpu));
			Z80_SP(b->cpu) = sp;
			mark(b, 0xE5, 0x23A7);
			ran = 11;
			break;
		}
		case 0x23A7:
			rst_n(b, 0xE7, 0x0020);
			ran = 11;
			break;
		case 0x0020:
			Z80_HL(b->cpu) = pop_word(b);
			mark(b, 0xE1, 0x0021);
			ran = 10;
			break;
		case 0x0021:
			flags = 0;
			a = add_a(Z80_A(b->cpu), Z80_A(b->cpu), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x87, 0x0022);
			ran = 4;
			break;
		case 0x0022:
			rst_n(b, 0xD7, 0x0010);
			ran = 11;
			break;
		case 0x0010:
			flags = 0;
			a = add_a(Z80_A(b->cpu), (uint8_t)Z80_HL(b->cpu), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x85, 0x0011);
			ran = 4;
			break;
		case 0x0011:
			set_l(b, Z80_A(b->cpu));
			mark(b, 0x6F, 0x0012);
			ran = 4;
			break;
		case 0x0012:
			Z80_A(b->cpu) = 0;
			mark(b, 0x3E, 0x0014);
			ran = 7;
			break;
		case 0x0014:
			a = adc8(Z80_A(b->cpu), (uint8_t)(Z80_HL(b->cpu) >> 8),
				 Z80_F(b->cpu), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x8C, 0x0015);
			ran = 4;
			break;
		case 0x0015:
			set_h(b, Z80_A(b->cpu));
			mark(b, 0x67, 0x0016);
			ran = 4;
			break;
		case 0x0016:
			Z80_A(b->cpu) = board_mem_read(b, Z80_HL(b->cpu));
			mark(b, 0x7E, 0x0017);
			ran = 7;
			break;
		case 0x0017:
			hl = pop_word(b);
			Z80_PC(b->cpu) = hl;
			Z80_MEMPTR(b->cpu) = hl;
			b->cpu.data.uint8_array[0] = 0xC9;
			ran = 10;
			break;
		case 0x0023:
			set_e(b, Z80_A(b->cpu));
			mark(b, 0x5F, 0x0024);
			ran = 4;
			break;
		case 0x0024:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			mark(b, 0x23, 0x0025);
			ran = 6;
			break;
		case 0x0025:
			set_d(b, board_mem_read(b, Z80_HL(b->cpu)));
			mark(b, 0x56, 0x0026);
			ran = 7;
			break;
		case 0x0026: {
			uint16_t de = Z80_DE(b->cpu);

			Z80_DE(b->cpu) = Z80_HL(b->cpu);
			Z80_HL(b->cpu) = de;
			mark(b, 0xEB, 0x0027);
			ran = 4;
			break;
		}
		case 0x0027:
			mark(b, 0xE9, Z80_HL(b->cpu));
			ran = 4;
			break;
		default:
			fprintf(stderr, "sched: unhandled %04X\n", pc);
			return;
		}
		if (ran == 0)
			return;
		charge(b, ran);
	}
}
