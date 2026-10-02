#include "dispatch.h"
#include "fiber.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

enum {
	YIELD_NONE = 0,
	YIELD_RETURN = 1,
	YIELD_NEST = 2
};

static Fiber host_fiber;
static Fiber alt_fiber;
static uint8_t alt_stack[1 << 20] __attribute__((aligned(16)));
static int alt_ready;
static int yield_kind;
static uint16_t nest_entry;
static uint16_t top_entry;
static Board *job_board;
static void (*job_fn)(Board *);
static void c_dispatch(Board *b, uint16_t entry);

static void alt_loop(void)
{
	for (;;) {
		if (job_fn) {
			void (*fn)(Board *) = job_fn;
			Board *b = job_board;
			job_fn = NULL;
			fn(b);
		}
		fiber_switch(&alt_fiber, &host_fiber);
	}
}

static void fiber_enter(void)
{
	if (!alt_ready) {
		uintptr_t sp = (uintptr_t)alt_stack + sizeof alt_stack;
		sp &= ~(uintptr_t)15u;
		memset(&alt_fiber, 0, sizeof alt_fiber);
		alt_fiber.sp = (uint64_t)sp;
		alt_fiber.lr = (uint64_t)(uintptr_t)alt_loop;
		alt_ready = 1;
	}
	fiber_switch(&host_fiber, &alt_fiber);
}

static void run_top(Board *b)
{
	c_dispatch(b, top_entry);
}

typedef void (*LiftFn)(Board *);

typedef struct {
	uint16_t pc;
	LiftFn fn;
	const char *name;
} LiftEnt;

static LiftEnt k_lifts[LIFT_MAX_LIFTS];
static int k_n;
static uint32_t shadow_misses;

void c_add_lift(uint16_t pc, LiftFn fn, const char *name)
{
	if (k_n >= LIFT_MAX_LIFTS)
		return;
	k_lifts[k_n].pc = pc;
	k_lifts[k_n].fn = fn;
	k_lifts[k_n].name = name;
	k_n++;
}

extern void j_1000(Board *b);

void c_register_leaves(Board *b)
{
	(void)b;
	c_add_lift(0x1000, j_1000, "j_1000");
}

void lift_call_z80(Board *b, uint16_t target)
{
	uint16_t sp;

	if (b->c_depth >= LIFT_CALL_DEPTH) {
		fprintf(stderr, "lift: C to Z80 call nested too deep\n");
		b->mismatch = 1;
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "C to Z80 call nested too deep");
		return;
	}
	sp = (uint16_t)(Z80_SP(b->cpu) - 2u);
	board_mem_write(b, sp, (uint8_t)(LIFT_SENTINEL & 0xFFu));
	board_mem_write(b, (uint16_t)(sp + 1u),
			(uint8_t)((LIFT_SENTINEL >> 8) & 0xFFu));
	Z80_SP(b->cpu) = sp;
	Z80_PC(b->cpu) = target;
	b->c_depth++;
	for (;;) {
		fiber_switch(&alt_fiber, &host_fiber);
		if (yield_kind == YIELD_RETURN) {
			yield_kind = YIELD_NONE;
			break;
		}
		if (yield_kind == YIELD_NEST) {
			uint16_t entry = nest_entry;
			yield_kind = YIELD_NONE;
			c_dispatch(b, entry);
		}
	}
	b->c_depth--;
}

void c_host_prove(Board *b)
{
	if (!b->lift_prove || !b->lift_prove_fn)
		return;
	b->lift_prove = 0;
	job_fn = b->lift_prove_fn;
	job_board = b;
	fiber_enter();
}

void c_host_lift(Board *b, uint16_t entry)
{
	if (b->c_depth > 0) {
		nest_entry = entry;
		yield_kind = YIELD_NEST;
		fiber_switch(&host_fiber, &alt_fiber);
		return;
	}
	top_entry = entry;
	job_fn = run_top;
	job_board = b;
	fiber_enter();
}

void c_host_sentinel(Board *b)
{
	(void)b;
	yield_kind = YIELD_RETURN;
	fiber_switch(&host_fiber, &alt_fiber);
}

static void save_board(Board *b, Z80 *cpu, uint8_t *mem, uint8_t spr2[16],
		       uint8_t latch[8], uint8_t voice[32], uint32_t *kick)
{
	memcpy(cpu, &b->cpu, sizeof *cpu);
	memcpy(mem, b->mem, 65536u);
	memcpy(spr2, b->spr2, 16u);
	memcpy(latch, b->latch, 8u);
	memcpy(voice, b->audio.reg, 32u);
	*kick = b->frames_since_kick;
}

static void load_board(Board *b, const Z80 *cpu, const uint8_t *mem,
		       const uint8_t spr2[16], const uint8_t latch[8],
		       const uint8_t voice[32], uint32_t kick)
{
	memcpy(&b->cpu, cpu, sizeof *cpu);
	memcpy(b->mem, mem, 65536u);
	memcpy(b->spr2, spr2, 16u);
	memcpy(b->latch, latch, 8u);
	memcpy(b->audio.reg, voice, 32u);
	b->frames_since_kick = kick;
}

static void apply_ret(Board *b)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t lo = board_mem_read(b, sp);
	uint16_t hi = board_mem_read(b, (uint16_t)(sp + 1u));
	uint16_t ret = (uint16_t)(lo | (uint16_t)(hi << 8));

	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	Z80_PC(b->cpu) = ret;
	Z80_MEMPTR(b->cpu) = ret;
}

static int run_until_ret(Board *b, uint16_t ret, uint16_t sp0)
{
	uint16_t sp_back = (uint16_t)(sp0 + 2u);
	int guard = 0;

	while (b->cycles_left > 0 && guard++ < 2000000) {
		zusize ran;
		if (Z80_PC(b->cpu) == ret && Z80_SP(b->cpu) == sp_back)
			return 1;
		ran = z80_run(&b->cpu, 1);
		if (ran == 0)
			return 0;
		if (ran >= b->cycles_left)
			b->cycles_left = 0;
		else
			b->cycles_left -= ran;
	}
	return Z80_PC(b->cpu) == ret && Z80_SP(b->cpu) == sp_back;
}

static int diff_u16(const char *name, uint16_t expect, uint16_t got,
		    char *msg, size_t cap)
{
	if (expect == got)
		return 0;
	snprintf(msg, cap, "%s expected %04X got %04X", name, expect, got);
	return 1;
}

static int diff_u8(const char *name, uint8_t expect, uint8_t got,
		   char *msg, size_t cap)
{
	if (expect == got)
		return 0;
	snprintf(msg, cap, "%s expected %02X got %02X", name, expect, got);
	return 1;
}

/* R counts M1 cycles. The C body is not an M1 counter; the committed Z80
 * result keeps the real R for the frame record. */
static int diff_cpu(const Z80 *z, const Z80 *c, char *msg, size_t cap)
{
	if (diff_u8("F", Z80_F(*z), Z80_F(*c), msg, cap))
		return 1;
	if (diff_u16("PC", Z80_PC(*z), Z80_PC(*c), msg, cap))
		return 1;
	if (diff_u16("SP", Z80_SP(*z), Z80_SP(*c), msg, cap))
		return 1;
	if (diff_u16("AF", Z80_AF(*z), Z80_AF(*c), msg, cap))
		return 1;
	if (diff_u16("BC", Z80_BC(*z), Z80_BC(*c), msg, cap))
		return 1;
	if (diff_u16("DE", Z80_DE(*z), Z80_DE(*c), msg, cap))
		return 1;
	if (diff_u16("HL", Z80_HL(*z), Z80_HL(*c), msg, cap))
		return 1;
	if (diff_u16("AF'", Z80_AF_(*z), Z80_AF_(*c), msg, cap))
		return 1;
	if (diff_u16("BC'", Z80_BC_(*z), Z80_BC_(*c), msg, cap))
		return 1;
	if (diff_u16("DE'", Z80_DE_(*z), Z80_DE_(*c), msg, cap))
		return 1;
	if (diff_u16("HL'", Z80_HL_(*z), Z80_HL_(*c), msg, cap))
		return 1;
	if (diff_u16("IX", Z80_IX(*z), Z80_IX(*c), msg, cap))
		return 1;
	if (diff_u16("IY", Z80_IY(*z), Z80_IY(*c), msg, cap))
		return 1;
	if (diff_u16("WZ", Z80_MEMPTR(*z), Z80_MEMPTR(*c), msg, cap))
		return 1;
	if (diff_u8("I", z->i, c->i, msg, cap))
		return 1;
	if (diff_u8("IFF1", z->iff1, c->iff1, msg, cap))
		return 1;
	if (diff_u8("IFF2", z->iff2, c->iff2, msg, cap))
		return 1;
	if (diff_u8("IM", z->im, c->im, msg, cap))
		return 1;
	if (diff_u8("Q", z->q, c->q, msg, cap))
		return 1;
	if (diff_u8("INT", z->int_line, c->int_line, msg, cap))
		return 1;
	if (diff_u8("HALT", z->halt_line, c->halt_line, msg, cap))
		return 1;
	return 0;
}

static int diff_machine(Board *b, const Z80 *cpu, const uint8_t *mem,
			const uint8_t spr2[16], const uint8_t latch[8],
			const uint8_t voice[32], uint32_t kick,
			char *msg, size_t cap)
{
	uint32_t i;

	if (diff_cpu(cpu, &b->cpu, msg, cap))
		return 1;
	if (memcmp(mem, b->mem, 65536u) != 0) {
		for (i = 0; i < 65536u; i++) {
			if (mem[i] != b->mem[i]) {
				snprintf(msg, cap, "mem+%04X expected %02X got %02X",
					 i, mem[i], b->mem[i]);
				return 1;
			}
		}
	}
	for (i = 0; i < 16u; i++) {
		if (spr2[i] != b->spr2[i]) {
			snprintf(msg, cap, "sprpos+%04X expected %02X got %02X",
				 (unsigned)(0x5060u + i), spr2[i], b->spr2[i]);
			return 1;
		}
	}
	for (i = 0; i < 8u; i++) {
		if (latch[i] != b->latch[i]) {
			snprintf(msg, cap, "latch+%04X expected %02X got %02X",
				 (unsigned)(0x5000u + i), latch[i], b->latch[i]);
			return 1;
		}
	}
	for (i = 0; i < 32u; i++) {
		if (voice[i] != b->audio.reg[i]) {
			snprintf(msg, cap, "voice+%04X expected %02X got %02X",
				 (unsigned)(0x5040u + i), voice[i], b->audio.reg[i]);
			return 1;
		}
	}
	if (kick != b->frames_since_kick) {
		snprintf(msg, cap, "watchdog expected %u got %u", kick,
			 b->frames_since_kick);
		return 1;
	}
	return 0;
}

static void c_dispatch(Board *b, uint16_t entry)
{
	LiftEnt *ent = NULL;
	const char *name = "?";
	uint8_t *mem_entry;
	uint8_t *mem_result;
	Z80 cpu_entry;
	Z80 cpu_result;
	uint8_t spr_entry[16], spr_result[16];
	uint8_t latch_entry[8], latch_result[8];
	uint8_t voice_entry[32], voice_result[32];
	uint32_t kick_entry, kick_result;
	uint16_t sp0, ret;
	uint16_t pos0, pos1, n0, n1;
	uint8_t reads0[LIFT_MAX_READS], reads1[LIFT_MAX_READS];
	int mismatch;
	char msg_saved[160];
	int prev_suspend;
	int returned;
	int i;

	for (i = 0; i < k_n; i++) {
		if (k_lifts[i].pc == entry) {
			ent = &k_lifts[i];
			name = ent->name;
			break;
		}
	}

	sp0 = Z80_SP(b->cpu);
	ret = (uint16_t)board_mem_read(b, sp0);
	ret = (uint16_t)(ret | (uint16_t)((uint16_t)board_mem_read(b, (uint16_t)(sp0 + 1u)) << 8));

	mem_entry = malloc(65536u);
	mem_result = malloc(65536u);
	if (!mem_entry || !mem_result) {
		fprintf(stderr, "lift: shadow out of memory\n");
		free(mem_entry);
		free(mem_result);
		b->mismatch = 1;
		return;
	}

	pos0 = b->corpus.read_pos;
	n0 = b->cur.nreads;
	memcpy(reads0, b->cur.reads, sizeof reads0);
	mismatch = b->mismatch;
	memcpy(msg_saved, b->corpus.mismatch_msg, sizeof msg_saved);
	save_board(b, &cpu_entry, mem_entry, spr_entry, latch_entry, voice_entry,
		   &kick_entry);

	prev_suspend = b->lift_suspend;
	b->lift_suspend = 1;
	returned = run_until_ret(b, ret, sp0);
	b->lift_suspend = prev_suspend;

	if (!returned) {
		fprintf(stderr,
			"shadow %s frame %u did not return before the frame budget\n",
			name, b->frame_index);
		shadow_misses++;
		free(mem_entry);
		free(mem_result);
		return;
	}

	pos1 = b->corpus.read_pos;
	n1 = b->cur.nreads;
	memcpy(reads1, b->cur.reads, sizeof reads1);
	mismatch = b->mismatch;
	memcpy(msg_saved, b->corpus.mismatch_msg, sizeof msg_saved);
	save_board(b, &cpu_result, mem_result, spr_result, latch_result,
		   voice_result, &kick_result);

	load_board(b, &cpu_entry, mem_entry, spr_entry, latch_entry, voice_entry,
		   kick_entry);
	b->corpus.read_pos = pos0;
	b->cur.nreads = n0;
	memcpy(b->cur.reads, reads0, sizeof reads0);

	if (ent && ent->fn) {
		char detail[120];
		ent->fn(b);
		apply_ret(b);
		if (diff_machine(b, &cpu_result, mem_result, spr_result,
				 latch_result, voice_result, kick_result,
				 detail, sizeof detail)) {
			fprintf(stderr, "shadow %s frame %u %s\n", name,
				b->frame_index, detail);
			shadow_misses++;
		}
	}

	load_board(b, &cpu_result, mem_result, spr_result, latch_result,
		   voice_result, kick_result);
	b->corpus.read_pos = pos1;
	b->cur.nreads = n1;
	memcpy(b->cur.reads, reads1, sizeof reads1);
	b->mismatch = mismatch;
	memcpy(b->corpus.mismatch_msg, msg_saved, sizeof msg_saved);
	free(mem_entry);
	free(mem_result);
}

static void c_prove(Board *b)
{
	uint8_t *mem;
	Z80 cpu;
	uint8_t spr2[16], latch[8], voice[32];
	uint32_t kick;
	zusize cycles;
	int stop, irq, mismatch;
	int ok;
	uint16_t target = 0x000C;

	mem = malloc(65536u);
	if (!mem) {
		fprintf(stderr, "lift: C-to-Z80 yield out of memory\n");
		b->mismatch = 1;
		return;
	}
	save_board(b, &cpu, mem, spr2, latch, voice, &kick);
	cycles = b->cycles_left;
	stop = b->stop;
	irq = b->irq_seen;
	mismatch = b->mismatch;

	if (b->rom[target] != 0xC9) {
		fprintf(stderr, "lift: C-to-Z80 yield failed, no RET at %04X\n",
			target);
		ok = 0;
	} else {
		Z80_SP(b->cpu) = 0x4F00;
		Z80_AF(b->cpu) = 0x1234;
		Z80_HL(b->cpu) = 0xABCD;
		lift_call_z80(b, target);
		ok = Z80_SP(b->cpu) == 0x4F00 &&
		     Z80_PC(b->cpu) == LIFT_SENTINEL &&
		     Z80_AF(b->cpu) == 0x1234 &&
		     Z80_HL(b->cpu) == 0xABCD;
		if (ok)
			fprintf(stderr, "lift: C-to-Z80 yield ok\n");
		else
			fprintf(stderr,
				"lift: C-to-Z80 yield failed SP=%04X PC=%04X AF=%04X HL=%04X\n",
				Z80_SP(b->cpu), Z80_PC(b->cpu), Z80_AF(b->cpu),
				Z80_HL(b->cpu));
	}

	load_board(b, &cpu, mem, spr2, latch, voice, kick);
	b->cycles_left = cycles;
	b->stop = stop;
	b->irq_seen = irq;
	b->lift_nop = 0;
	b->lift_hit = 0;
	b->lift_sentinel = 0;
	free(mem);
	if (!ok) {
		b->mismatch = 1;
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "C-to-Z80 yield failed");
	} else {
		b->mismatch = mismatch;
	}
}

void c_boot(Board *b, int census)
{
	int i;

	if (census) {
		census_attach(b);
		return;
	}
	b->lift_dispatch = c_dispatch;
	b->lift_prove = 1;
	b->lift_prove_fn = c_prove;
	c_register_leaves(b);
	for (i = 0; i < k_n; i++)
		board_lift_add(b, k_lifts[i].pc);
}

int c_done(Board *b)
{
	if (b->lift_watch && !b->lift_dispatch)
		return census_report(b);
	if (k_n == 0)
		return 0;
	if (shadow_misses == 0) {
		fprintf(stderr, "shadow log empty\n");
		return 0;
	}
	fprintf(stderr, "shadow misses: %u\n", shadow_misses);
	return 1;
}
