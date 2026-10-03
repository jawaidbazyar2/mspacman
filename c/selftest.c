#include "lift.h"

/* The boot self-test, $3000 through the button check at $3295.
 * A slice stops when the frame budget runs out, or when PC leaves
 * the span: a call, the jump to $234B, or an interrupt accept.
 * The host then runs that other routine. $3298 is the Namco egg. */

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

static uint8_t or_flags(uint8_t result)
{
	return (uint8_t)(parity_pv(result) | (result & 0xA8u) |
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

static uint8_t dec8(uint8_t value, uint8_t flags, uint8_t *next)
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

static void load_a(Board *b, uint16_t addr)
{
	Z80_A(b->cpu) = board_mem_read(b, addr);
	Z80_MEMPTR(b->cpu) = (uint16_t)(addr + 1u);
}

static void jp_to(Board *b, int taken, uint16_t dest, uint16_t next,
		  uint8_t opcode)
{
	b->cpu.data.uint8_array[0] = opcode;
	Z80_MEMPTR(b->cpu) = dest;
	Z80_PC(b->cpu) = taken ? dest : next;
}

static zusize jr_to(Board *b, int taken, uint16_t dest, uint16_t next,
		    uint8_t opcode)
{
	b->cpu.data.uint8_array[0] = opcode;
	if (taken) {
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

static void exx(Board *b)
{
	uint16_t t;

	t = Z80_BC(b->cpu);
	Z80_BC(b->cpu) = Z80_BC_(b->cpu);
	Z80_BC_(b->cpu) = t;
	t = Z80_DE(b->cpu);
	Z80_DE(b->cpu) = Z80_DE_(b->cpu);
	Z80_DE_(b->cpu) = t;
	t = Z80_HL(b->cpu);
	Z80_HL(b->cpu) = Z80_HL_(b->cpu);
	Z80_HL_(b->cpu) = t;
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

static void inc_l(Board *b)
{
	uint8_t l;
	uint8_t flags = inc8((uint8_t)Z80_HL(b->cpu), Z80_F(b->cpu), &l);

	set_l(b, l);
	Z80_F(b->cpu) = flags;
}

static void dec_l(Board *b)
{
	uint8_t l;
	uint8_t flags = dec8((uint8_t)Z80_HL(b->cpu), Z80_F(b->cpu), &l);

	set_l(b, l);
	Z80_F(b->cpu) = flags;
}

static void inc_h(Board *b)
{
	uint8_t h;
	uint8_t flags = inc8((uint8_t)(Z80_HL(b->cpu) >> 8), Z80_F(b->cpu), &h);

	set_h(b, h);
	Z80_F(b->cpu) = flags;
}

static void dec_h(Board *b)
{
	uint8_t h;
	uint8_t flags = dec8((uint8_t)(Z80_HL(b->cpu) >> 8), Z80_F(b->cpu), &h);

	set_h(b, h);
	Z80_F(b->cpu) = flags;
}

static void rrca(Board *b)
{
	uint8_t a = Z80_A(b->cpu);
	uint8_t c = (uint8_t)(a & 1u);
	uint8_t flags = Z80_F(b->cpu);

	a = (uint8_t)((a >> 1) | (uint8_t)(c << 7));
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = (uint8_t)((flags & 0xC4u) | (a & 0x28u) | c);
}

static void rlca(Board *b)
{
	uint8_t a = Z80_A(b->cpu);
	uint8_t c = (uint8_t)((a >> 7) & 1u);
	uint8_t flags = Z80_F(b->cpu);

	a = (uint8_t)((uint8_t)(a << 1) | c);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = (uint8_t)((flags & 0xC4u) | (a & 0x29u));
}

static void cpl(Board *b)
{
	uint8_t a = (uint8_t)~Z80_A(b->cpu);
	uint8_t flags = Z80_F(b->cpu);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = (uint8_t)((flags & 0xC5u) | (a & 0x28u) | 0x12u);
}

static void charge(Board *b, zusize ran)
{
	if (ran >= b->cycles_left)
		b->cycles_left = 0;
	else
		b->cycles_left -= ran;
}

/* IM 1 accept. Not on the instruction after EI. Leaves PC at $0038. */
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
	sp = Z80_SP(b->cpu);
	push_word(b, &sp, Z80_PC(b->cpu));
	Z80_SP(b->cpu) = sp;
	Z80_PC(b->cpu) = 0x0038;
	Z80_MEMPTR(b->cpu) = 0x0038;
	b->cpu.data.uint8_array[0] = 0;
	return 1;
}

static int zset(Board *b)
{
	return (Z80_F(b->cpu) & 0x40u) != 0;
}

static int cset(Board *b)
{
	return (Z80_F(b->cpu) & 0x01u) != 0;
}

/* j_3000  power-on self-test
 * Entry:    Also resumed at whichever opcode the previous frame's
 *           budget left PC on. I is clear on the first entry. The
 *           return pushed by the interrupt is still on the stack
 *           until $3042 replaces SP.
 * Exit:     One slice. PC stays in $3000..$3297 when the budget
 *           runs out. A call leaves PC on j_2c5e or j_32ed. The
 *           button check leaves PC on $234B. An interrupt accept
 *           leaves PC on $0038. The egg at $3298 is outside this span.
 * Clobbers: whatever the slice executed.
 * Flags live-out: the flags of the last instruction in the slice.
 * Interrupt: the checksum keeps interrupts off. After $3196, the
 *           next instruction runs, then IM 1 accepts.
 * Stack: the RAM test pops the table at $3154. Calls push their
 *        return and stop. The interrupt accept pushes PC.
 */
void j_3000(Board *b)
{
	int guard = 0;

	while (b->cycles_left > 0 && guard++ < 2000000) {
		uint16_t pc = Z80_PC(b->cpu);
		zusize ran = 0;
		uint8_t a;
		uint8_t flags;

		if (pc < 0x3000 || pc > 0x3297)
			return;
		if (accept_int(b)) {
			charge(b, 13);
			continue;
		}
		switch (pc) {
		case 0x3000:
			Z80_HL(b->cpu) = 0;
			mark(b, 0x21, 0x3003);
			ran = 10;
			break;
		case 0x3003:
			Z80_BC(b->cpu) = 0x1000;
			mark(b, 0x01, 0x3006);
			ran = 10;
			break;
		case 0x3006:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x3009);
			ran = 13;
			break;
		case 0x3009:
			Z80_A(b->cpu) = Z80_C(b->cpu);
			mark(b, 0x79, 0x300A);
			ran = 4;
			break;
		case 0x300A:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu),
				  board_mem_read(b, Z80_HL(b->cpu)), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x86, 0x300B);
			ran = 7;
			break;
		case 0x300B:
			Z80_C(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x4F, 0x300C);
			ran = 4;
			break;
		case 0x300C:
			Z80_A(b->cpu) = (uint8_t)Z80_HL(b->cpu);
			mark(b, 0x7D, 0x300D);
			ran = 4;
			break;
		case 0x300D:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), 0x02, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xC6, 0x300F);
			ran = 7;
			break;
		case 0x300F:
			set_l(b, Z80_A(b->cpu));
			mark(b, 0x6F, 0x3010);
			ran = 4;
			break;
		case 0x3010:
			Z80_F(b->cpu) = cp_flags(Z80_A(b->cpu), 0x02);
			mark(b, 0xFE, 0x3012);
			ran = 7;
			break;
		case 0x3012:
			jp_to(b, !cset(b), 0x3009, 0x3015, 0xD2);
			ran = 10;
			break;
		case 0x3015:
			inc_h(b);
			mark(b, 0x24, 0x3016);
			ran = 4;
			break;
		case 0x3016:
			ran = djnz_to(b, 0x3006, 0x3018);
			break;
		case 0x3018:
			Z80_A(b->cpu) = Z80_C(b->cpu);
			mark(b, 0x79, 0x3019);
			ran = 4;
			break;
		case 0x3019:
			a = Z80_A(b->cpu);
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xA7, 0x301A);
			ran = 4;
			break;
		case 0x301A:
			mark(b, 0x00, 0x301B);
			ran = 4;
			break;
		case 0x301B:
			mark(b, 0x00, 0x301C);
			ran = 4;
			break;
		case 0x301C:
			store_a(b, 0x5007);
			mark(b, 0x32, 0x301F);
			ran = 13;
			break;
		case 0x301F:
			Z80_A(b->cpu) = (uint8_t)(Z80_HL(b->cpu) >> 8);
			mark(b, 0x7C, 0x3020);
			ran = 4;
			break;
		case 0x3020:
			Z80_F(b->cpu) = cp_flags(Z80_A(b->cpu), 0x30);
			mark(b, 0xFE, 0x3022);
			ran = 7;
			break;
		case 0x3022:
			jp_to(b, !zset(b), 0x3003, 0x3025, 0xC2);
			ran = 10;
			break;
		case 0x3025:
			set_h(b, 0);
			mark(b, 0x26, 0x3027);
			ran = 7;
			break;
		case 0x3027:
			inc_l(b);
			mark(b, 0x2C, 0x3028);
			ran = 4;
			break;
		case 0x3028:
			Z80_A(b->cpu) = (uint8_t)Z80_HL(b->cpu);
			mark(b, 0x7D, 0x3029);
			ran = 4;
			break;
		case 0x3029:
			Z80_F(b->cpu) = cp_flags(Z80_A(b->cpu), 0x02);
			mark(b, 0xFE, 0x302B);
			ran = 7;
			break;
		case 0x302B:
			jp_to(b, cset(b), 0x3003, 0x302E, 0xDA);
			ran = 10;
			break;
		case 0x302E:
			jp_to(b, 1, 0x3042, 0x3031, 0xC3);
			ran = 10;
			break;
		case 0x3031:
			dec_h(b);
			mark(b, 0x25, 0x3032);
			ran = 4;
			break;
		case 0x3032:
			Z80_A(b->cpu) = (uint8_t)(Z80_HL(b->cpu) >> 8);
			mark(b, 0x7C, 0x3033);
			ran = 4;
			break;
		case 0x3033:
			a = (uint8_t)(Z80_A(b->cpu) & 0xF0u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x3035);
			ran = 7;
			break;
		case 0x3035:
			store_a(b, 0x5007);
			mark(b, 0x32, 0x3038);
			ran = 13;
			break;
		case 0x3038:
		case 0x3039:
		case 0x303A:
		case 0x303B:
			rrca(b);
			mark(b, 0x0F, (uint16_t)(pc + 1u));
			ran = 4;
			break;
		case 0x303C:
			Z80_E(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x5F, 0x303D);
			ran = 4;
			break;
		case 0x303D:
			Z80_B(b->cpu) = 0;
			mark(b, 0x06, 0x303F);
			ran = 7;
			break;
		case 0x303F:
			jp_to(b, 1, 0x30BD, 0x3042, 0xC3);
			ran = 10;
			break;
		case 0x3042:
			Z80_SP(b->cpu) = 0x3154;
			mark(b, 0x31, 0x3045);
			ran = 10;
			break;
		case 0x3045:
			Z80_B(b->cpu) = 0xFF;
			mark(b, 0x06, 0x3047);
			ran = 7;
			break;
		case 0x3047:
			Z80_HL(b->cpu) = pop_word(b);
			mark(b, 0xE1, 0x3048);
			ran = 10;
			break;
		case 0x3048:
			Z80_DE(b->cpu) = pop_word(b);
			mark(b, 0xD1, 0x3049);
			ran = 10;
			break;
		case 0x3049:
			Z80_C(b->cpu) = Z80_B(b->cpu);
			mark(b, 0x48, 0x304A);
			ran = 4;
			break;
		case 0x304A:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x304D);
			ran = 13;
			break;
		case 0x304D:
			Z80_A(b->cpu) = Z80_C(b->cpu);
			mark(b, 0x79, 0x304E);
			ran = 4;
			break;
		case 0x304E:
			a = (uint8_t)(Z80_A(b->cpu) & Z80_E(b->cpu));
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xA3, 0x304F);
			ran = 4;
			break;
		case 0x304F:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			mark(b, 0x77, 0x3050);
			ran = 7;
			break;
		case 0x3050:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), 0x33, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xC6, 0x3052);
			ran = 7;
			break;
		case 0x3052:
			Z80_C(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x4F, 0x3053);
			ran = 4;
			break;
		case 0x3053:
			inc_l(b);
			mark(b, 0x2C, 0x3054);
			ran = 4;
			break;
		case 0x3054:
			Z80_A(b->cpu) = (uint8_t)Z80_HL(b->cpu);
			mark(b, 0x7D, 0x3055);
			ran = 4;
			break;
		case 0x3055:
			a = (uint8_t)(Z80_A(b->cpu) & 0x0Fu);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x3057);
			ran = 7;
			break;
		case 0x3057:
			jp_to(b, !zset(b), 0x304D, 0x305A, 0xC2);
			ran = 10;
			break;
		case 0x305A:
			Z80_A(b->cpu) = Z80_C(b->cpu);
			mark(b, 0x79, 0x305B);
			ran = 4;
			break;
		case 0x305B:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), Z80_A(b->cpu), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x87, 0x305C);
			ran = 4;
			break;
		case 0x305C:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), Z80_A(b->cpu), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x87, 0x305D);
			ran = 4;
			break;
		case 0x305D:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), Z80_C(b->cpu), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x81, 0x305E);
			ran = 4;
			break;
		case 0x305E:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), 0x31, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xC6, 0x3060);
			ran = 7;
			break;
		case 0x3060:
			Z80_C(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x4F, 0x3061);
			ran = 4;
			break;
		case 0x3061:
			Z80_A(b->cpu) = (uint8_t)Z80_HL(b->cpu);
			mark(b, 0x7D, 0x3062);
			ran = 4;
			break;
		case 0x3062:
			a = Z80_A(b->cpu);
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xA7, 0x3063);
			ran = 4;
			break;
		case 0x3063:
			jp_to(b, !zset(b), 0x304D, 0x3066, 0xC2);
			ran = 10;
			break;
		case 0x3066:
			inc_h(b);
			mark(b, 0x24, 0x3067);
			ran = 4;
			break;
		case 0x3067: {
			uint8_t d;
			flags = dec8(Z80_D(b->cpu), Z80_F(b->cpu), &d);
			Z80_D(b->cpu) = d;
			Z80_F(b->cpu) = flags;
			mark(b, 0x15, 0x3068);
			ran = 4;
			break;
		}
		case 0x3068:
			jp_to(b, !zset(b), 0x304A, 0x306B, 0xC2);
			ran = 10;
			break;
		case 0x306B:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x306C);
			ran = 6;
			break;
		case 0x306C:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x306D);
			ran = 6;
			break;
		case 0x306D:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x306E);
			ran = 6;
			break;
		case 0x306E:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x306F);
			ran = 6;
			break;
		case 0x306F:
			Z80_HL(b->cpu) = pop_word(b);
			mark(b, 0xE1, 0x3070);
			ran = 10;
			break;
		case 0x3070:
			Z80_DE(b->cpu) = pop_word(b);
			mark(b, 0xD1, 0x3071);
			ran = 10;
			break;
		case 0x3071:
			Z80_C(b->cpu) = Z80_B(b->cpu);
			mark(b, 0x48, 0x3072);
			ran = 4;
			break;
		case 0x3072:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x3075);
			ran = 13;
			break;
		case 0x3075:
			Z80_A(b->cpu) = Z80_C(b->cpu);
			mark(b, 0x79, 0x3076);
			ran = 4;
			break;
		case 0x3076:
			a = (uint8_t)(Z80_A(b->cpu) & Z80_E(b->cpu));
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xA3, 0x3077);
			ran = 4;
			break;
		case 0x3077:
			Z80_C(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x4F, 0x3078);
			ran = 4;
			break;
		case 0x3078:
			Z80_A(b->cpu) = board_mem_read(b, Z80_HL(b->cpu));
			mark(b, 0x7E, 0x3079);
			ran = 7;
			break;
		case 0x3079:
			a = (uint8_t)(Z80_A(b->cpu) & Z80_E(b->cpu));
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xA3, 0x307A);
			ran = 4;
			break;
		case 0x307A:
			Z80_F(b->cpu) = cp_flags(Z80_A(b->cpu), Z80_C(b->cpu));
			mark(b, 0xB9, 0x307B);
			ran = 4;
			break;
		case 0x307B:
			jp_to(b, !zset(b), 0x30B5, 0x307E, 0xC2);
			ran = 10;
			break;
		case 0x307E:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), 0x33, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xC6, 0x3080);
			ran = 7;
			break;
		case 0x3080:
			Z80_C(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x4F, 0x3081);
			ran = 4;
			break;
		case 0x3081:
			inc_l(b);
			mark(b, 0x2C, 0x3082);
			ran = 4;
			break;
		case 0x3082:
			Z80_A(b->cpu) = (uint8_t)Z80_HL(b->cpu);
			mark(b, 0x7D, 0x3083);
			ran = 4;
			break;
		case 0x3083:
			a = (uint8_t)(Z80_A(b->cpu) & 0x0Fu);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x3085);
			ran = 7;
			break;
		case 0x3085:
			jp_to(b, !zset(b), 0x3075, 0x3088, 0xC2);
			ran = 10;
			break;
		case 0x3088:
			Z80_A(b->cpu) = Z80_C(b->cpu);
			mark(b, 0x79, 0x3089);
			ran = 4;
			break;
		case 0x3089:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), Z80_A(b->cpu), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x87, 0x308A);
			ran = 4;
			break;
		case 0x308A:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), Z80_A(b->cpu), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x87, 0x308B);
			ran = 4;
			break;
		case 0x308B:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), Z80_C(b->cpu), &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x81, 0x308C);
			ran = 4;
			break;
		case 0x308C:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), 0x31, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xC6, 0x308E);
			ran = 7;
			break;
		case 0x308E:
			Z80_C(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x4F, 0x308F);
			ran = 4;
			break;
		case 0x308F:
			Z80_A(b->cpu) = (uint8_t)Z80_HL(b->cpu);
			mark(b, 0x7D, 0x3090);
			ran = 4;
			break;
		case 0x3090:
			a = Z80_A(b->cpu);
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xA7, 0x3091);
			ran = 4;
			break;
		case 0x3091:
			jp_to(b, !zset(b), 0x3075, 0x3094, 0xC2);
			ran = 10;
			break;
		case 0x3094:
			inc_h(b);
			mark(b, 0x24, 0x3095);
			ran = 4;
			break;
		case 0x3095: {
			uint8_t d;
			flags = dec8(Z80_D(b->cpu), Z80_F(b->cpu), &d);
			Z80_D(b->cpu) = d;
			Z80_F(b->cpu) = flags;
			mark(b, 0x15, 0x3096);
			ran = 4;
			break;
		}
		case 0x3096:
			jp_to(b, !zset(b), 0x3072, 0x3099, 0xC2);
			ran = 10;
			break;
		case 0x3099:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x309A);
			ran = 6;
			break;
		case 0x309A:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x309B);
			ran = 6;
			break;
		case 0x309B:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x309C);
			ran = 6;
			break;
		case 0x309C:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x309D);
			ran = 6;
			break;
		case 0x309D:
			Z80_A(b->cpu) = Z80_B(b->cpu);
			mark(b, 0x78, 0x309E);
			ran = 4;
			break;
		case 0x309E:
			flags = Z80_F(b->cpu);
			a = sub_a(Z80_A(b->cpu), 0x10, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xD6, 0x30A0);
			ran = 7;
			break;
		case 0x30A0:
			Z80_B(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x47, 0x30A1);
			ran = 4;
			break;
		case 0x30A1:
			ran = djnz_to(b, 0x3047, 0x30A3);
			break;
		case 0x30A3:
			Z80_AF(b->cpu) = pop_word(b);
			mark(b, 0xF1, 0x30A4);
			ran = 10;
			break;
		case 0x30A4:
			Z80_DE(b->cpu) = pop_word(b);
			mark(b, 0xD1, 0x30A5);
			ran = 10;
			break;
		case 0x30A5:
			Z80_F(b->cpu) = cp_flags(Z80_A(b->cpu), 0x44);
			mark(b, 0xFE, 0x30A7);
			ran = 7;
			break;
		case 0x30A7:
			jp_to(b, !zset(b), 0x3045, 0x30AA, 0xC2);
			ran = 10;
			break;
		case 0x30AA:
			Z80_A(b->cpu) = Z80_E(b->cpu);
			mark(b, 0x7B, 0x30AB);
			ran = 4;
			break;
		case 0x30AB:
			a = (uint8_t)(Z80_A(b->cpu) ^ 0xF0u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = or_flags(a);
			mark(b, 0xEE, 0x30AD);
			ran = 7;
			break;
		case 0x30AD:
			jp_to(b, !zset(b), 0x3045, 0x30B0, 0xC2);
			ran = 10;
			break;
		case 0x30B0:
			Z80_B(b->cpu) = 0x01;
			mark(b, 0x06, 0x30B2);
			ran = 7;
			break;
		case 0x30B2:
			jp_to(b, 1, 0x30BD, 0x30B5, 0xC3);
			ran = 10;
			break;
		case 0x30B5:
			Z80_A(b->cpu) = Z80_E(b->cpu);
			mark(b, 0x7B, 0x30B6);
			ran = 4;
			break;
		case 0x30B6:
			a = (uint8_t)(Z80_A(b->cpu) & 0x01u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x30B8);
			ran = 7;
			break;
		case 0x30B8:
			a = (uint8_t)(Z80_A(b->cpu) ^ 0x01u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = or_flags(a);
			mark(b, 0xEE, 0x30BA);
			ran = 7;
			break;
		case 0x30BA:
			Z80_E(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x5F, 0x30BB);
			ran = 4;
			break;
		case 0x30BB:
			Z80_B(b->cpu) = 0;
			mark(b, 0x06, 0x30BD);
			ran = 7;
			break;
		case 0x30BD:
			Z80_SP(b->cpu) = 0x4FC0;
			mark(b, 0x31, 0x30C0);
			ran = 10;
			break;
		case 0x30C0:
			exx(b);
			mark(b, 0xD9, 0x30C1);
			ran = 4;
			break;
		case 0x30C1:
			Z80_HL(b->cpu) = 0x4C00;
			mark(b, 0x21, 0x30C4);
			ran = 10;
			break;
		case 0x30C4:
			Z80_B(b->cpu) = 0x04;
			mark(b, 0x06, 0x30C6);
			ran = 7;
			break;
		case 0x30C6:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x30C9);
			ran = 13;
			break;
		case 0x30C9:
			board_mem_write(b, Z80_HL(b->cpu), 0);
			mark(b, 0x36, 0x30CB);
			ran = 10;
			break;
		case 0x30CB:
			inc_l(b);
			mark(b, 0x2C, 0x30CC);
			ran = 4;
			break;
		case 0x30CC:
			ran = jr_to(b, !zset(b), 0x30C9, 0x30CE, 0x20);
			break;
		case 0x30CE:
			inc_h(b);
			mark(b, 0x24, 0x30CF);
			ran = 4;
			break;
		case 0x30CF:
			ran = djnz_to(b, 0x30C6, 0x30D1);
			break;
		case 0x30D1:
			Z80_HL(b->cpu) = 0x4000;
			mark(b, 0x21, 0x30D4);
			ran = 10;
			break;
		case 0x30D4:
			Z80_B(b->cpu) = 0x04;
			mark(b, 0x06, 0x30D6);
			ran = 7;
			break;
		case 0x30D6:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x30D9);
			ran = 13;
			break;
		case 0x30D9:
			Z80_A(b->cpu) = 0x40;
			mark(b, 0x3E, 0x30DB);
			ran = 7;
			break;
		case 0x30DB:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			mark(b, 0x77, 0x30DC);
			ran = 7;
			break;
		case 0x30DC:
			inc_l(b);
			mark(b, 0x2C, 0x30DD);
			ran = 4;
			break;
		case 0x30DD:
			ran = jr_to(b, !zset(b), 0x30DB, 0x30DF, 0x20);
			break;
		case 0x30DF:
			inc_h(b);
			mark(b, 0x24, 0x30E0);
			ran = 4;
			break;
		case 0x30E0:
			ran = djnz_to(b, 0x30D6, 0x30E2);
			break;
		case 0x30E2:
			Z80_B(b->cpu) = 0x04;
			mark(b, 0x06, 0x30E4);
			ran = 7;
			break;
		case 0x30E4:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x30E7);
			ran = 13;
			break;
		case 0x30E7:
			Z80_A(b->cpu) = 0x0F;
			mark(b, 0x3E, 0x30E9);
			ran = 7;
			break;
		case 0x30E9:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			mark(b, 0x77, 0x30EA);
			ran = 7;
			break;
		case 0x30EA:
			inc_l(b);
			mark(b, 0x2C, 0x30EB);
			ran = 4;
			break;
		case 0x30EB:
			ran = jr_to(b, !zset(b), 0x30E9, 0x30ED, 0x20);
			break;
		case 0x30ED:
			inc_h(b);
			mark(b, 0x24, 0x30EE);
			ran = 4;
			break;
		case 0x30EE:
			ran = djnz_to(b, 0x30E4, 0x30F0);
			break;
		case 0x30F0:
			exx(b);
			mark(b, 0xD9, 0x30F1);
			ran = 4;
			break;
		case 0x30F1:
			ran = djnz_to(b, 0x30FB, 0x30F3);
			break;
		case 0x30F3:
			Z80_B(b->cpu) = 0x23;
			mark(b, 0x06, 0x30F5);
			ran = 7;
			break;
		case 0x30F5:
			call_to(b, 0x2C5E, 0x30F8);
			ran = 17;
			break;
		case 0x30F8:
			jp_to(b, 1, 0x3174, 0x30FB, 0xC3);
			ran = 10;
			break;
		case 0x3174:
			Z80_HL(b->cpu) = 0x5006;
			mark(b, 0x21, 0x3177);
			ran = 10;
			break;
		case 0x3177:
			Z80_A(b->cpu) = 0x01;
			mark(b, 0x3E, 0x3179);
			ran = 7;
			break;
		case 0x3179:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			mark(b, 0x77, 0x317A);
			ran = 7;
			break;
		case 0x317A:
			dec_l(b);
			mark(b, 0x2D, 0x317B);
			ran = 4;
			break;
		case 0x317B:
			ran = jr_to(b, !zset(b), 0x3179, 0x317D, 0x20);
			break;
		case 0x317D:
			Z80_A(b->cpu) = 0;
			Z80_F(b->cpu) = or_flags(0);
			mark(b, 0xAF, 0x317E);
			ran = 4;
			break;
		case 0x317E:
			store_a(b, 0x5003);
			mark(b, 0x32, 0x3181);
			ran = 13;
			break;
		case 0x3181:
			flags = Z80_F(b->cpu);
			a = sub_a(Z80_A(b->cpu), 0x04, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xD6, 0x3183);
			ran = 7;
			break;
		case 0x3183:
			b->cpu.i = Z80_A(b->cpu);
			b->cpu.data.uint8_array[0] = 0xED;
			b->cpu.data.uint8_array[1] = 0x47;
			Z80_PC(b->cpu) = 0x3185;
			ran = 9;
			break;
		case 0x3185:
			Z80_SP(b->cpu) = 0x4FC0;
			mark(b, 0x31, 0x3188);
			ran = 10;
			break;
		case 0x3188:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x318B);
			ran = 13;
			break;
		case 0x318B:
			Z80_A(b->cpu) = 0;
			Z80_F(b->cpu) = or_flags(0);
			mark(b, 0xAF, 0x318C);
			ran = 4;
			break;
		case 0x318C:
			store_a(b, 0x4E00);
			mark(b, 0x32, 0x318F);
			ran = 13;
			break;
		case 0x318F:
			flags = inc8(Z80_A(b->cpu), Z80_F(b->cpu), &a);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x3C, 0x3190);
			ran = 4;
			break;
		case 0x3190:
			store_a(b, 0x4E01);
			mark(b, 0x32, 0x3193);
			ran = 13;
			break;
		case 0x3193:
			store_a(b, 0x5000);
			mark(b, 0x32, 0x3196);
			ran = 13;
			break;
		case 0x3196:
			b->cpu.iff1 = 1;
			b->cpu.iff2 = 1;
			if (b->cpu.int_line)
				b->cpu.request = (uint8_t)(b->cpu.request |
							    Z80_REQUEST_INT);
			mark(b, 0xFB, 0x3197);
			ran = 4;
			break;
		case 0x3197:
			load_a(b, 0x5000);
			mark(b, 0x3A, 0x319A);
			ran = 13;
			break;
		case 0x319A:
			cpl(b);
			mark(b, 0x2F, 0x319B);
			ran = 4;
			break;
		case 0x319B:
			Z80_B(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x47, 0x319C);
			ran = 4;
			break;
		case 0x319C:
			a = (uint8_t)(Z80_A(b->cpu) & 0xE0u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x319E);
			ran = 7;
			break;
		case 0x319E:
			ran = jr_to(b, zset(b), 0x31A5, 0x31A0, 0x28);
			break;
		case 0x31A0:
			Z80_A(b->cpu) = 0x02;
			mark(b, 0x3E, 0x31A2);
			ran = 7;
			break;
		case 0x31A2:
			store_a(b, 0x4E9C);
			mark(b, 0x32, 0x31A5);
			ran = 13;
			break;
		case 0x31A5:
			load_a(b, 0x5040);
			mark(b, 0x3A, 0x31A8);
			ran = 13;
			break;
		case 0x31A8:
			cpl(b);
			mark(b, 0x2F, 0x31A9);
			ran = 4;
			break;
		case 0x31A9:
			Z80_C(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x4F, 0x31AA);
			ran = 4;
			break;
		case 0x31AA:
			a = (uint8_t)(Z80_A(b->cpu) & 0x60u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x31AC);
			ran = 7;
			break;
		case 0x31AC:
			ran = jr_to(b, zset(b), 0x31B3, 0x31AE, 0x28);
			break;
		case 0x31AE:
			Z80_A(b->cpu) = 0x01;
			mark(b, 0x3E, 0x31B0);
			ran = 7;
			break;
		case 0x31B0:
			store_a(b, 0x4E9C);
			mark(b, 0x32, 0x31B3);
			ran = 13;
			break;
		case 0x31B3:
			Z80_A(b->cpu) = Z80_B(b->cpu);
			mark(b, 0x78, 0x31B4);
			ran = 4;
			break;
		case 0x31B4:
			a = (uint8_t)(Z80_A(b->cpu) | Z80_C(b->cpu));
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = or_flags(a);
			mark(b, 0xB1, 0x31B5);
			ran = 4;
			break;
		case 0x31B5:
			a = (uint8_t)(Z80_A(b->cpu) & 0x01u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x31B7);
			ran = 7;
			break;
		case 0x31B7:
			ran = jr_to(b, zset(b), 0x31BE, 0x31B9, 0x28);
			break;
		case 0x31B9:
			Z80_A(b->cpu) = 0x08;
			mark(b, 0x3E, 0x31BB);
			ran = 7;
			break;
		case 0x31BB:
			store_a(b, 0x4EBC);
			mark(b, 0x32, 0x31BE);
			ran = 13;
			break;
		case 0x31BE:
			Z80_A(b->cpu) = Z80_B(b->cpu);
			mark(b, 0x78, 0x31BF);
			ran = 4;
			break;
		case 0x31BF:
			a = (uint8_t)(Z80_A(b->cpu) | Z80_C(b->cpu));
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = or_flags(a);
			mark(b, 0xB1, 0x31C0);
			ran = 4;
			break;
		case 0x31C0:
			a = (uint8_t)(Z80_A(b->cpu) & 0x02u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x31C2);
			ran = 7;
			break;
		case 0x31C2:
			ran = jr_to(b, zset(b), 0x31C9, 0x31C4, 0x28);
			break;
		case 0x31C4:
			Z80_A(b->cpu) = 0x04;
			mark(b, 0x3E, 0x31C6);
			ran = 7;
			break;
		case 0x31C6:
			store_a(b, 0x4EBC);
			mark(b, 0x32, 0x31C9);
			ran = 13;
			break;
		case 0x31C9:
			Z80_A(b->cpu) = Z80_B(b->cpu);
			mark(b, 0x78, 0x31CA);
			ran = 4;
			break;
		case 0x31CA:
			a = (uint8_t)(Z80_A(b->cpu) | Z80_C(b->cpu));
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = or_flags(a);
			mark(b, 0xB1, 0x31CB);
			ran = 4;
			break;
		case 0x31CB:
			a = (uint8_t)(Z80_A(b->cpu) & 0x04u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x31CD);
			ran = 7;
			break;
		case 0x31CD:
			ran = jr_to(b, zset(b), 0x31D4, 0x31CF, 0x28);
			break;
		case 0x31CF:
			Z80_A(b->cpu) = 0x10;
			mark(b, 0x3E, 0x31D1);
			ran = 7;
			break;
		case 0x31D1:
			store_a(b, 0x4EBC);
			mark(b, 0x32, 0x31D4);
			ran = 13;
			break;
		case 0x31D4:
			Z80_A(b->cpu) = Z80_B(b->cpu);
			mark(b, 0x78, 0x31D5);
			ran = 4;
			break;
		case 0x31D5:
			a = (uint8_t)(Z80_A(b->cpu) | Z80_C(b->cpu));
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = or_flags(a);
			mark(b, 0xB1, 0x31D6);
			ran = 4;
			break;
		case 0x31D6:
			a = (uint8_t)(Z80_A(b->cpu) & 0x08u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x31D8);
			ran = 7;
			break;
		case 0x31D8:
			ran = jr_to(b, zset(b), 0x31DF, 0x31DA, 0x28);
			break;
		case 0x31DA:
			Z80_A(b->cpu) = 0x20;
			mark(b, 0x3E, 0x31DC);
			ran = 7;
			break;
		case 0x31DC:
			store_a(b, 0x4EBC);
			mark(b, 0x32, 0x31DF);
			ran = 13;
			break;
		case 0x31DF:
			load_a(b, 0x5080);
			mark(b, 0x3A, 0x31E2);
			ran = 13;
			break;
		case 0x31E2:
			a = (uint8_t)(Z80_A(b->cpu) & 0x03u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x31E4);
			ran = 7;
			break;
		case 0x31E4:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), 0x25, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xC6, 0x31E6);
			ran = 7;
			break;
		case 0x31E6:
			Z80_B(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x47, 0x31E7);
			ran = 4;
			break;
		case 0x31E7:
			call_to(b, 0x2C5E, 0x31EA);
			ran = 17;
			break;
		case 0x31EA:
			load_a(b, 0x5080);
			mark(b, 0x3A, 0x31ED);
			ran = 13;
			break;
		case 0x31ED:
		case 0x31EE:
		case 0x31EF:
		case 0x31F0:
			rrca(b);
			mark(b, 0x0F, (uint16_t)(pc + 1u));
			ran = 4;
			break;
		case 0x31F1:
			a = (uint8_t)(Z80_A(b->cpu) & 0x03u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x31F3);
			ran = 7;
			break;
		case 0x31F3:
			Z80_F(b->cpu) = cp_flags(Z80_A(b->cpu), 0x03);
			mark(b, 0xFE, 0x31F5);
			ran = 7;
			break;
		case 0x31F5:
			ran = jr_to(b, !zset(b), 0x31FF, 0x31F7, 0x20);
			break;
		case 0x31F7:
			Z80_B(b->cpu) = 0x2A;
			mark(b, 0x06, 0x31F9);
			ran = 7;
			break;
		case 0x31F9:
			call_to(b, 0x2C5E, 0x31FC);
			ran = 17;
			break;
		case 0x31FC:
			jp_to(b, 1, 0x321C, 0x31FF, 0xC3);
			ran = 10;
			break;
		case 0x31FF:
			rlca(b);
			mark(b, 0x07, 0x3200);
			ran = 4;
			break;
		case 0x3200:
			Z80_E(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x5F, 0x3201);
			ran = 4;
			break;
		case 0x3201: {
			uint16_t sp = Z80_SP(b->cpu);

			push_word(b, &sp, Z80_DE(b->cpu));
			Z80_SP(b->cpu) = sp;
			mark(b, 0xD5, 0x3202);
			ran = 11;
			break;
		}
		case 0x3202:
			Z80_B(b->cpu) = 0x2B;
			mark(b, 0x06, 0x3204);
			ran = 7;
			break;
		case 0x3204:
			call_to(b, 0x2C5E, 0x3207);
			ran = 17;
			break;
		case 0x3207:
			Z80_B(b->cpu) = 0x2E;
			mark(b, 0x06, 0x3209);
			ran = 7;
			break;
		case 0x3209:
			call_to(b, 0x2C5E, 0x320C);
			ran = 17;
			break;
		case 0x320C:
			Z80_DE(b->cpu) = pop_word(b);
			mark(b, 0xD1, 0x320D);
			ran = 10;
			break;
		case 0x320D:
			Z80_D(b->cpu) = 0;
			mark(b, 0x16, 0x320F);
			ran = 7;
			break;
		case 0x320F:
			Z80_HL(b->cpu) = 0x32F9;
			mark(b, 0x21, 0x3212);
			ran = 10;
			break;
		case 0x3212: {
			uint16_t hl = Z80_HL(b->cpu);
			uint16_t sum;

			Z80_MEMPTR(b->cpu) = (uint16_t)(hl + 1u);
			flags = add_hl_flags(hl, Z80_DE(b->cpu), Z80_F(b->cpu),
					     &sum);
			Z80_HL(b->cpu) = sum;
			Z80_F(b->cpu) = flags;
			mark(b, 0x19, 0x3213);
			ran = 11;
			break;
		}
		case 0x3213:
			Z80_A(b->cpu) = board_mem_read(b, Z80_HL(b->cpu));
			mark(b, 0x7E, 0x3214);
			ran = 7;
			break;
		case 0x3214:
			store_a(b, 0x422A);
			mark(b, 0x32, 0x3217);
			ran = 13;
			break;
		case 0x3217:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			mark(b, 0x23, 0x3218);
			ran = 6;
			break;
		case 0x3218:
			Z80_A(b->cpu) = board_mem_read(b, Z80_HL(b->cpu));
			mark(b, 0x7E, 0x3219);
			ran = 7;
			break;
		case 0x3219:
			store_a(b, 0x424A);
			mark(b, 0x32, 0x321C);
			ran = 13;
			break;
		case 0x321C:
			load_a(b, 0x5080);
			mark(b, 0x3A, 0x321F);
			ran = 13;
			break;
		case 0x321F:
		case 0x3220:
			rrca(b);
			mark(b, 0x0F, (uint16_t)(pc + 1u));
			ran = 4;
			break;
		case 0x3221:
			a = (uint8_t)(Z80_A(b->cpu) & 0x03u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x3223);
			ran = 7;
			break;
		case 0x3223:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), 0x31, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xC6, 0x3225);
			ran = 7;
			break;
		case 0x3225:
			Z80_F(b->cpu) = cp_flags(Z80_A(b->cpu), 0x34);
			mark(b, 0xFE, 0x3227);
			ran = 7;
			break;
		case 0x3227:
			ran = jr_to(b, !zset(b), 0x322A, 0x3229, 0x20);
			break;
		case 0x3229:
			flags = inc8(Z80_A(b->cpu), Z80_F(b->cpu), &a);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0x3C, 0x322A);
			ran = 4;
			break;
		case 0x322A:
			store_a(b, 0x41AC);
			mark(b, 0x32, 0x322D);
			ran = 13;
			break;
		case 0x322D:
			Z80_B(b->cpu) = 0x29;
			mark(b, 0x06, 0x322F);
			ran = 7;
			break;
		case 0x322F:
			call_to(b, 0x2C5E, 0x3232);
			ran = 17;
			break;
		case 0x3232:
			load_a(b, 0x5040);
			mark(b, 0x3A, 0x3235);
			ran = 13;
			break;
		case 0x3235:
			rlca(b);
			mark(b, 0x07, 0x3236);
			ran = 4;
			break;
		case 0x3236:
			a = (uint8_t)(Z80_A(b->cpu) & 0x01u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x3238);
			ran = 7;
			break;
		case 0x3238:
			flags = Z80_F(b->cpu);
			a = add_a(Z80_A(b->cpu), 0x2C, &flags);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			mark(b, 0xC6, 0x323A);
			ran = 7;
			break;
		case 0x323A:
			Z80_B(b->cpu) = Z80_A(b->cpu);
			mark(b, 0x47, 0x323B);
			ran = 4;
			break;
		case 0x323B:
			call_to(b, 0x2C5E, 0x323E);
			ran = 17;
			break;
		case 0x323E:
			load_a(b, 0x5040);
			mark(b, 0x3A, 0x3241);
			ran = 13;
			break;
		case 0x3241:
			a = (uint8_t)(Z80_A(b->cpu) & 0x10u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x3243);
			ran = 7;
			break;
		case 0x3243:
			jp_to(b, zset(b), 0x3188, 0x3246, 0xCA);
			ran = 10;
			break;
		case 0x3246:
			Z80_A(b->cpu) = 0;
			Z80_F(b->cpu) = or_flags(0);
			mark(b, 0xAF, 0x3247);
			ran = 4;
			break;
		case 0x3247:
			store_a(b, 0x5000);
			mark(b, 0x32, 0x324A);
			ran = 13;
			break;
		case 0x324A:
			b->cpu.iff1 = 0;
			b->cpu.iff2 = 0;
			b->cpu.request = (uint8_t)(b->cpu.request &
						    (uint8_t)~Z80_REQUEST_INT);
			mark(b, 0xF3, 0x324B);
			ran = 4;
			break;
		case 0x324B:
			Z80_HL(b->cpu) = 0x5007;
			mark(b, 0x21, 0x324E);
			ran = 10;
			break;
		case 0x324E:
			Z80_A(b->cpu) = 0;
			Z80_F(b->cpu) = or_flags(0);
			mark(b, 0xAF, 0x324F);
			ran = 4;
			break;
		case 0x324F:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			mark(b, 0x77, 0x3250);
			ran = 7;
			break;
		case 0x3250:
			dec_l(b);
			mark(b, 0x2D, 0x3251);
			ran = 4;
			break;
		case 0x3251:
			ran = jr_to(b, !zset(b), 0x324F, 0x3253, 0x20);
			break;
		case 0x3253:
			Z80_SP(b->cpu) = 0x3AE2;
			mark(b, 0x31, 0x3256);
			ran = 10;
			break;
		case 0x3256:
			Z80_B(b->cpu) = 0x03;
			mark(b, 0x06, 0x3258);
			ran = 7;
			break;
		case 0x3258:
			exx(b);
			mark(b, 0xD9, 0x3259);
			ran = 4;
			break;
		case 0x3259:
			Z80_HL(b->cpu) = pop_word(b);
			mark(b, 0xE1, 0x325A);
			ran = 10;
			break;
		case 0x325A:
			Z80_DE(b->cpu) = pop_word(b);
			mark(b, 0xD1, 0x325B);
			ran = 10;
			break;
		case 0x325B:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x325E);
			ran = 13;
			break;
		case 0x325E:
			Z80_BC(b->cpu) = pop_word(b);
			mark(b, 0xC1, 0x325F);
			ran = 10;
			break;
		case 0x325F:
			Z80_A(b->cpu) = 0x3C;
			mark(b, 0x3E, 0x3261);
			ran = 7;
			break;
		case 0x3261:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			mark(b, 0x77, 0x3262);
			ran = 7;
			break;
		case 0x3262:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			mark(b, 0x23, 0x3263);
			ran = 6;
			break;
		case 0x3263:
			board_mem_write(b, Z80_HL(b->cpu), Z80_D(b->cpu));
			mark(b, 0x72, 0x3264);
			ran = 7;
			break;
		case 0x3264:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			mark(b, 0x23, 0x3265);
			ran = 6;
			break;
		case 0x3265:
			ran = djnz_to(b, 0x325F, 0x3267);
			break;
		case 0x3267:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x3268);
			ran = 6;
			break;
		case 0x3268:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x3269);
			ran = 6;
			break;
		case 0x3269:
			Z80_BC(b->cpu) = pop_word(b);
			mark(b, 0xC1, 0x326A);
			ran = 10;
			break;
		case 0x326A:
			board_mem_write(b, Z80_HL(b->cpu), Z80_C(b->cpu));
			mark(b, 0x71, 0x326B);
			ran = 7;
			break;
		case 0x326B:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			mark(b, 0x23, 0x326C);
			ran = 6;
			break;
		case 0x326C:
			Z80_A(b->cpu) = 0x3F;
			mark(b, 0x3E, 0x326E);
			ran = 7;
			break;
		case 0x326E:
			board_mem_write(b, Z80_HL(b->cpu), Z80_A(b->cpu));
			mark(b, 0x77, 0x326F);
			ran = 7;
			break;
		case 0x326F:
			Z80_HL(b->cpu) = (uint16_t)(Z80_HL(b->cpu) + 1u);
			mark(b, 0x23, 0x3270);
			ran = 6;
			break;
		case 0x3270:
			ran = djnz_to(b, 0x326A, 0x3272);
			break;
		case 0x3272:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x3273);
			ran = 6;
			break;
		case 0x3273:
			Z80_SP(b->cpu) = (uint16_t)(Z80_SP(b->cpu) - 1u);
			mark(b, 0x3B, 0x3274);
			ran = 6;
			break;
		case 0x3274: {
			uint8_t e;
			flags = dec8(Z80_E(b->cpu), Z80_F(b->cpu), &e);
			Z80_E(b->cpu) = e;
			Z80_F(b->cpu) = flags;
			mark(b, 0x1D, 0x3275);
			ran = 4;
			break;
		}
		case 0x3275:
			jp_to(b, !zset(b), 0x325B, 0x3278, 0xC2);
			ran = 10;
			break;
		case 0x3278:
			Z80_AF(b->cpu) = pop_word(b);
			mark(b, 0xF1, 0x3279);
			ran = 10;
			break;
		case 0x3279:
			exx(b);
			mark(b, 0xD9, 0x327A);
			ran = 4;
			break;
		case 0x327A:
			ran = djnz_to(b, 0x3258, 0x327C);
			break;
		case 0x327C:
			Z80_SP(b->cpu) = 0x4FC0;
			mark(b, 0x31, 0x327F);
			ran = 10;
			break;
		case 0x327F:
			Z80_B(b->cpu) = 0x08;
			mark(b, 0x06, 0x3281);
			ran = 7;
			break;
		case 0x3281:
			call_to(b, 0x32ED, 0x3284);
			ran = 17;
			break;
		case 0x3284:
			ran = djnz_to(b, 0x3281, 0x3286);
			break;
		case 0x3286:
			store_a(b, 0x50C0);
			mark(b, 0x32, 0x3289);
			ran = 13;
			break;
		case 0x3289:
			load_a(b, 0x5040);
			mark(b, 0x3A, 0x328C);
			ran = 13;
			break;
		case 0x328C:
			a = (uint8_t)(Z80_A(b->cpu) & 0x10u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x328E);
			ran = 7;
			break;
		case 0x328E:
			ran = jr_to(b, zset(b), 0x3286, 0x3290, 0x28);
			break;
		case 0x3290:
			load_a(b, 0x5040);
			mark(b, 0x3A, 0x3293);
			ran = 13;
			break;
		case 0x3293:
			a = (uint8_t)(Z80_A(b->cpu) & 0x60u);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = and_flags(a);
			mark(b, 0xE6, 0x3295);
			ran = 7;
			break;
		case 0x3295:
			jp_to(b, !zset(b), 0x234B, 0x3298, 0xC2);
			ran = 10;
			break;
		default:
			fprintf(stderr, "selftest: unhandled %04X\n", pc);
			return;
		}
		if (ran == 0)
			return;
		charge(b, ran);
	}
}
