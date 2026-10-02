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
	if (k_n >= LIFT_MAX_LIFTS) {
		fprintf(stderr, "lift: routine table full (%s)\n", name);
		return;
	}
	k_lifts[k_n].pc = pc;
	k_lifts[k_n].fn = fn;
	k_lifts[k_n].name = name;
	k_n++;
}

extern void j_1000(Board *b);
extern void j_0ead(Board *b);
extern void j_08eb(Board *b);
extern void j_9561(Board *b);
extern void j_9559(Board *b);
extern void j_955e(Board *b);
extern void j_2730(Board *b);
extern void j_276c(Board *b);
extern void j_27a9(Board *b);
extern void j_27f1(Board *b);
extern void j_283b(Board *b);
extern void j_2865(Board *b);
extern void j_288f(Board *b);
extern void j_28b9(Board *b);
extern void j_32ed(Board *b);
extern void j_24c9(Board *b);
extern void j_240d(Board *b);
extern void j_23ed(Board *b);
extern void j_2698(Board *b);
extern void j_26a2(Board *b);
extern void j_058e(Board *b);
extern void j_2419(Board *b);
extern void j_24d7(Board *b);
extern void j_2448(Board *b);
extern void j_253d(Board *b);
extern void j_268b(Board *b);
extern void j_2a35(Board *b);
extern void j_070e(Board *b);
extern void j_95e3(Board *b);
extern void j_960b(Board *b);
extern void j_95f6(Board *b);
extern void j_963c(Board *b);
extern void j_26b2(Board *b);
extern void j_26d0(Board *b);
extern void j_0506(Board *b);
extern void j_05bf(Board *b);
extern void j_3ed0(Board *b);
extern void j_045f(Board *b);
extern void j_0585(Board *b);
extern void j_3e8b(Board *b);
extern void j_3e96(Board *b);
extern void j_3e9c(Board *b);
extern void j_3ea2(Board *b);
extern void j_3eab(Board *b);
extern void j_3eb1(Board *b);
extern void j_3eb7(Board *b);
extern void j_3ebd(Board *b);
extern void j_3ec3(Board *b);
extern void j_9642(Board *b);
extern void j_2c5e(Board *b);
extern void j_2ae0(Board *b);
extern void j_2ba1(Board *b);
extern void j_05e5(Board *b);
extern void j_083a(Board *b);
extern void j_2b0b(Board *b);
extern void j_0369(Board *b);
extern void j_0376(Board *b);
extern void j_0383(Board *b);
extern void j_0390(Board *b);
extern void j_02fd(Board *b);
extern void j_94bd(Board *b);
extern void j_946a(Board *b);
extern void j_0c0d(Board *b);
extern void j_2487(Board *b);
extern void j_267e(Board *b);
extern void j_3641(Board *b);
extern void j_0042(Board *b);
extern void j_2000(Board *b);
extern void j_2b80(Board *b);
extern void j_2a12(Board *b);
extern void j_29ea(Board *b);
extern void j_291e(Board *b);
extern void j_2966(Board *b);
extern void j_2086(Board *b);
extern void j_20a9(Board *b);
extern void j_20d1(Board *b);
extern void j_13dd(Board *b);
extern void j_1f2e(Board *b);
extern void j_1f55(Board *b);
extern void j_1f7c(Board *b);
extern void j_0c42(Board *b);
extern void j_2b7e(Board *b);
extern void j_2a23(Board *b);
extern void j_2ace(Board *b);
extern void j_2abe(Board *b);
extern void j_2aaf(Board *b);
extern void j_2b8f(Board *b);
extern void j_2b33(Board *b);
extern void j_2a5a(Board *b);
extern void j_171d(Board *b);
extern void j_1789(Board *b);
extern void j_2b6a(Board *b);
extern void j_10d2(Board *b);
extern void j_112a(Board *b);
extern void j_116e(Board *b);
extern void j_118f(Board *b);
extern void j_11db(Board *b);
extern void j_11fc(Board *b);
extern void j_1efe(Board *b);
extern void j_1f25(Board *b);
extern void j_1f4c(Board *b);
extern void j_1f73(Board *b);
extern void j_1bd8(Board *b);
extern void j_1caf(Board *b);
extern void j_1d86(Board *b);
extern void j_1e5d(Board *b);
extern void j_1b36(Board *b);
extern void j_1c4b(Board *b);
extern void j_1d22(Board *b);
extern void j_1df9(Board *b);
extern void j_1094(Board *b);
extern void j_109e(Board *b);
extern void j_10a8(Board *b);
extern void j_10b4(Board *b);
extern void j_1235(Board *b);
extern void j_1291(Board *b);
extern void j_1806(Board *b);
extern void j_1017(Board *b);
extern void j_2bea(Board *b);
extern void j_0e23(Board *b);
extern void j_2018(Board *b);
extern void j_3556(Board *b);
extern void j_9627(Board *b);
extern void j_2675(Board *b);
extern void j_02df(Board *b);
extern void j_02ad(Board *b);
extern void j_0267(Board *b);
extern void j_2069(Board *b);
extern void j_208c(Board *b);
extern void j_162d(Board *b);
extern void j_0814(Board *b);
extern void j_0065(Board *b);
extern void j_20af(Board *b);
extern void j_039d(Board *b);
extern void j_1066(Board *b);
extern void j_1b08(Board *b);
extern void j_1ed0(Board *b);
extern void j_20d7(Board *b);
extern void j_0e36(Board *b);
extern void j_0bd6(Board *b);
extern void j_1652(Board *b);
extern void j_01dc(Board *b);
extern void j_0221(Board *b);
extern void j_0263(Board *b);
extern void j_06a3(Board *b);
extern void j_0894(Board *b);
extern void j_100b(Board *b);
extern void j_1272(Board *b);
extern void j_212b(Board *b);
extern void j_21f0(Board *b);
extern void j_22b9(Board *b);
extern void j_3678(Board *b);
extern void j_0e6c(Board *b);
extern void j_15e6(Board *b);
extern void j_1a6a(Board *b);
extern void j_1376(Board *b);
extern void j_0ac3(Board *b);
extern void j_2052(Board *b);
extern void j_200f(Board *b);
extern void j_205a(Board *b);

void c_register_leaves(Board *b)
{
	(void)b;
	c_add_lift(0x1000, j_1000, "j_1000");
	c_add_lift(0x083A, j_083a, "j_083a");
	c_add_lift(0x2B0B, j_2b0b, "j_2b0b");
	c_add_lift(0x0369, j_0369, "j_0369");
	c_add_lift(0x0376, j_0376, "j_0376");
	c_add_lift(0x267E, j_267e, "j_267e");
	c_add_lift(0x3641, j_3641, "j_3641");
	c_add_lift(0x0042, j_0042, "j_0042");
	c_add_lift(0x2000, j_2000, "j_2000");
	c_add_lift(0x2B80, j_2b80, "j_2b80");
	c_add_lift(0x2A12, j_2a12, "j_2a12");
	c_add_lift(0x2B7E, j_2b7e, "j_2b7e");
	c_add_lift(0x2A23, j_2a23, "j_2a23");
	c_add_lift(0x2ACE, j_2ace, "j_2ace");
	c_add_lift(0x2B8F, j_2b8f, "j_2b8f");
	c_add_lift(0x0E23, j_0e23, "j_0e23");
	c_add_lift(0x2018, j_2018, "j_2018");
	c_add_lift(0x3556, j_3556, "j_3556");
	c_add_lift(0x9627, j_9627, "j_9627");
	c_add_lift(0x2675, j_2675, "j_2675");
	c_add_lift(0x02DF, j_02df, "j_02df");
	c_add_lift(0x2069, j_2069, "j_2069");
	c_add_lift(0x208C, j_208c, "j_208c");
	c_add_lift(0x162D, j_162d, "j_162d");
	c_add_lift(0x0814, j_0814, "j_0814");
	c_add_lift(0x0065, j_0065, "j_0065");
	c_add_lift(0x20AF, j_20af, "j_20af");
	c_add_lift(0x039D, j_039d, "j_039d");
	c_add_lift(0x1066, j_1066, "j_1066");
	c_add_lift(0x1B08, j_1b08, "j_1b08");
	c_add_lift(0x1ED0, j_1ed0, "j_1ed0");
	c_add_lift(0x20D7, j_20d7, "j_20d7");
	c_add_lift(0x0E36, j_0e36, "j_0e36");
	c_add_lift(0x0BD6, j_0bd6, "j_0bd6");
	c_add_lift(0x1652, j_1652, "j_1652");
	c_add_lift(0x01DC, j_01dc, "j_01dc");
	c_add_lift(0x0E6C, j_0e6c, "j_0e6c");
	c_add_lift(0x15E6, j_15e6, "j_15e6");
	c_add_lift(0x1A6A, j_1a6a, "j_1a6a");
	c_add_lift(0x1376, j_1376, "j_1376");
	c_add_lift(0x0AC3, j_0ac3, "j_0ac3");
	c_add_lift(0x2052, j_2052, "j_2052");
	c_add_lift(0x200F, j_200f, "j_200f");
	c_add_lift(0x2ABE, j_2abe, "j_2abe");
	c_add_lift(0x2AAF, j_2aaf, "j_2aaf");
	c_add_lift(0x205A, j_205a, "j_205a");
	c_add_lift(0x29EA, j_29ea, "j_29ea");
	c_add_lift(0x02AD, j_02ad, "j_02ad");
	c_add_lift(0x0267, j_0267, "j_0267");
	c_add_lift(0x2BEA, j_2bea, "j_2bea");
	c_add_lift(0x291E, j_291e, "j_291e");
	c_add_lift(0x2966, j_2966, "j_2966");
	c_add_lift(0x0383, j_0383, "j_0383");
	c_add_lift(0x0390, j_0390, "j_0390");
	c_add_lift(0x02FD, j_02fd, "j_02fd");
	c_add_lift(0x94BD, j_94bd, "j_94bd");
	c_add_lift(0x946A, j_946a, "j_946a");
	c_add_lift(0x0C0D, j_0c0d, "j_0c0d");
	c_add_lift(0x2487, j_2487, "j_2487");
	c_add_lift(0x2086, j_2086, "j_2086");
	c_add_lift(0x20A9, j_20a9, "j_20a9");
	c_add_lift(0x20D1, j_20d1, "j_20d1");
	c_add_lift(0x13DD, j_13dd, "j_13dd");
	c_add_lift(0x1F2E, j_1f2e, "j_1f2e");
	c_add_lift(0x1F55, j_1f55, "j_1f55");
	c_add_lift(0x1F7C, j_1f7c, "j_1f7c");
	c_add_lift(0x0C42, j_0c42, "j_0c42");
	c_add_lift(0x2B33, j_2b33, "j_2b33");
	c_add_lift(0x2A5A, j_2a5a, "j_2a5a");
	c_add_lift(0x171D, j_171d, "j_171d");
	c_add_lift(0x1789, j_1789, "j_1789");
	c_add_lift(0x2B6A, j_2b6a, "j_2b6a");
	c_add_lift(0x10D2, j_10d2, "j_10d2");
	c_add_lift(0x112A, j_112a, "j_112a");
	c_add_lift(0x116E, j_116e, "j_116e");
	c_add_lift(0x118F, j_118f, "j_118f");
	c_add_lift(0x11DB, j_11db, "j_11db");
	c_add_lift(0x11FC, j_11fc, "j_11fc");
	c_add_lift(0x1EFE, j_1efe, "j_1efe");
	c_add_lift(0x1F25, j_1f25, "j_1f25");
	c_add_lift(0x1F4C, j_1f4c, "j_1f4c");
	c_add_lift(0x1F73, j_1f73, "j_1f73");
	c_add_lift(0x1BD8, j_1bd8, "j_1bd8");
	c_add_lift(0x1CAF, j_1caf, "j_1caf");
	c_add_lift(0x1D86, j_1d86, "j_1d86");
	c_add_lift(0x1E5D, j_1e5d, "j_1e5d");
	c_add_lift(0x1B36, j_1b36, "j_1b36");
	c_add_lift(0x1C4B, j_1c4b, "j_1c4b");
	c_add_lift(0x1D22, j_1d22, "j_1d22");
	c_add_lift(0x1DF9, j_1df9, "j_1df9");
	c_add_lift(0x1094, j_1094, "j_1094");
	c_add_lift(0x109E, j_109e, "j_109e");
	c_add_lift(0x10A8, j_10a8, "j_10a8");
	c_add_lift(0x10B4, j_10b4, "j_10b4");
	c_add_lift(0x1235, j_1235, "j_1235");
	c_add_lift(0x1291, j_1291, "j_1291");
	c_add_lift(0x1806, j_1806, "j_1806");
	c_add_lift(0x1017, j_1017, "j_1017");
	c_add_lift(0x0EAD, j_0ead, "j_0ead");
	c_add_lift(0x08EB, j_08eb, "j_08eb");
	c_add_lift(0x9561, j_9561, "j_9561");
	c_add_lift(0x9559, j_9559, "j_9559");
	c_add_lift(0x955E, j_955e, "j_955e");
	c_add_lift(0x2730, j_2730, "j_2730");
	c_add_lift(0x276C, j_276c, "j_276c");
	c_add_lift(0x27A9, j_27a9, "j_27a9");
	c_add_lift(0x27F1, j_27f1, "j_27f1");
	c_add_lift(0x283B, j_283b, "j_283b");
	c_add_lift(0x2865, j_2865, "j_2865");
	c_add_lift(0x288F, j_288f, "j_288f");
	c_add_lift(0x28B9, j_28b9, "j_28b9");
	c_add_lift(0x32ED, j_32ed, "j_32ed");
	c_add_lift(0x32F0, j_32ed, "j_32ed");
	c_add_lift(0x32F3, j_32ed, "j_32ed");
	c_add_lift(0x32F4, j_32ed, "j_32ed");
	c_add_lift(0x32F5, j_32ed, "j_32ed");
	c_add_lift(0x32F6, j_32ed, "j_32ed");
	c_add_lift(0x32F8, j_32ed, "j_32ed");
	c_add_lift(0x24C9, j_24c9, "j_24c9");
	c_add_lift(0x240D, j_240d, "j_240d");
	c_add_lift(0x23ED, j_23ed, "j_23ed");
	c_add_lift(0x2698, j_2698, "j_2698");
	c_add_lift(0x26A2, j_26a2, "j_26a2");
	c_add_lift(0x058E, j_058e, "j_058e");
	c_add_lift(0x2419, j_2419, "j_2419");
	c_add_lift(0x26B2, j_26b2, "j_26b2");
	c_add_lift(0x26D0, j_26d0, "j_26d0");
	c_add_lift(0x0506, j_0506, "j_0506");
	c_add_lift(0x05BF, j_05bf, "j_05bf");
	c_add_lift(0x2C5E, j_2c5e, "j_2c5e");
	c_add_lift(0x2AE0, j_2ae0, "j_2ae0");
	c_add_lift(0x2BA1, j_2ba1, "j_2ba1");
	c_add_lift(0x05E5, j_05e5, "j_05e5");
	c_add_lift(0x3ED0, j_3ed0, "j_3ed0");
	c_add_lift(0x045F, j_045f, "j_045f");
	c_add_lift(0x0585, j_0585, "j_0585");
	c_add_lift(0x3E8B, j_3e8b, "j_3e8b");
	c_add_lift(0x3E96, j_3e96, "j_3e96");
	c_add_lift(0x3E9C, j_3e9c, "j_3e9c");
	c_add_lift(0x3EA2, j_3ea2, "j_3ea2");
	c_add_lift(0x3EAB, j_3eab, "j_3eab");
	c_add_lift(0x3EB1, j_3eb1, "j_3eb1");
	c_add_lift(0x3EB7, j_3eb7, "j_3eb7");
	c_add_lift(0x3EBD, j_3ebd, "j_3ebd");
	c_add_lift(0x3EC3, j_3ec3, "j_3ec3");
	c_add_lift(0x9642, j_9642, "j_9642");
	c_add_lift(0x24D7, j_24d7, "j_24d7");
	c_add_lift(0x2448, j_2448, "j_2448");
	c_add_lift(0x253D, j_253d, "j_253d");
	c_add_lift(0x268B, j_268b, "j_268b");
	c_add_lift(0x2A35, j_2a35, "j_2a35");
	c_add_lift(0x070E, j_070e, "j_070e");
	c_add_lift(0x95E3, j_95e3, "j_95e3");
	c_add_lift(0x960B, j_960b, "j_960b");
	c_add_lift(0x95F6, j_95f6, "j_95f6");
	c_add_lift(0x963C, j_963c, "j_963c");
	c_add_lift(0x0221, j_0221, "j_0221");
	c_add_lift(0x0263, j_0263, "j_0263");
	c_add_lift(0x06A3, j_06a3, "j_06a3");
	c_add_lift(0x0894, j_0894, "j_0894");
	c_add_lift(0x100B, j_100b, "j_100b");
	c_add_lift(0x1272, j_1272, "j_1272");
	c_add_lift(0x212B, j_212b, "j_212b");
	c_add_lift(0x21F0, j_21f0, "j_21f0");
	c_add_lift(0x22B9, j_22b9, "j_22b9");
	c_add_lift(0x3678, j_3678, "j_3678");
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
		board_apply_draw(b);
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

/* The refresh counter stays out of this compare. Draws go through the
 * generator, and the caller checks that state separately. */
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

/* Opcode addresses of j_32ed. The countdown does not finish in one frame,
 * so the next frame resumes at whichever of these the budget left PC on. */
static int delay_pc(uint16_t pc)
{
	return pc == 0x32ED || pc == 0x32F0 || pc == 0x32F3 || pc == 0x32F4 ||
	       pc == 0x32F5 || pc == 0x32F6 || pc == 0x32F8;
}

/* j_240d plus the rst $08 it runs. A call that starts late in the frame
 * stops inside the fill. The next frame resumes in Z80 at that opcode,
 * which is not itself a lifted entry. */
static int color_pc(uint16_t pc)
{
	return pc == 0x240D || pc == 0x240E || pc == 0x2411 || pc == 0x2414 ||
	       pc == 0x2415 || pc == 0x2416 || pc == 0x2418 || pc == 0x0008 ||
	       pc == 0x0009 || pc == 0x000A || pc == 0x000C;
}

/* Set around a call that may still be running when the frame ends.
 * The slice stops on the return address with the caller's SP restored. */
static uint16_t span_ret;
static uint16_t span_sp_back;

static int delay_inside(Board *b)
{
	return delay_pc(Z80_PC(b->cpu));
}

static int color_inside(Board *b)
{
	return color_pc(Z80_PC(b->cpu));
}

static int span_inside(Board *b)
{
	return !(Z80_PC(b->cpu) == span_ret && Z80_SP(b->cpu) == span_sp_back);
}

static void run_pc_budget(Board *b, int (*inside)(Board *))
{
	int guard = 0;

	while (b->cycles_left > 0 && guard++ < 2000000) {
		zusize ran;

		if (!inside(b))
			return;
		ran = z80_run(&b->cpu, 1);
		board_apply_draw(b);
		if (ran == 0)
			return;
		if (ran >= b->cycles_left)
			b->cycles_left = 0;
		else
			b->cycles_left -= ran;
	}
}

static void shadow_delay(Board *b, LiftEnt *ent, int (*inside)(Board *))
{
	const char *name = ent && ent->name ? ent->name : "j_32ed";
	uint8_t *mem_entry;
	uint8_t *mem_result;
	Z80 cpu_entry;
	Z80 cpu_result;
	uint8_t spr_entry[16], spr_result[16];
	uint8_t latch_entry[8], latch_result[8];
	uint8_t voice_entry[32], voice_result[32];
	uint32_t kick_entry, kick_result;
	uint16_t pos0, pos1, n0, n1;
	uint32_t rand0, rand1;
	uint8_t reads0[LIFT_MAX_READS], reads1[LIFT_MAX_READS];
	zusize cycles0, cycles1;
	int mismatch;
	char msg_saved[160];
	int prev_suspend;

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
	cycles0 = b->cycles_left;
	mismatch = b->mismatch;
	memcpy(msg_saved, b->corpus.mismatch_msg, sizeof msg_saved);
	save_board(b, &cpu_entry, mem_entry, spr_entry, latch_entry, voice_entry,
		   &kick_entry);

	rand0 = b->rand_state;
	prev_suspend = b->lift_suspend;
	b->lift_suspend = 1;
	run_pc_budget(b, inside);
	b->lift_suspend = prev_suspend;
	rand1 = b->rand_state;
	cycles1 = b->cycles_left;

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
	b->rand_state = rand0;
	b->cycles_left = cycles0;

	if (ent && ent->fn) {
		char detail[120];

		ent->fn(b);
		if (b->cycles_left != cycles1) {
			snprintf(detail, sizeof detail,
				 "cycles expected %u got %u",
				 (unsigned)cycles1, (unsigned)b->cycles_left);
			fprintf(stderr, "shadow %s frame %u %s\n", name,
				b->frame_index, detail);
			shadow_misses++;
		} else if (b->rand_state != rand1) {
			snprintf(detail, sizeof detail, "rand expected %08X got %08X",
				 (unsigned)rand1, (unsigned)b->rand_state);
			fprintf(stderr, "shadow %s frame %u %s\n", name,
				b->frame_index, detail);
			shadow_misses++;
		} else if (diff_machine(b, &cpu_result, mem_result, spr_result,
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
	b->rand_state = rand1;
	b->cycles_left = cycles1;
	b->mismatch = mismatch;
	memcpy(b->corpus.mismatch_msg, msg_saved, sizeof msg_saved);
	free(mem_entry);
	free(mem_result);
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
	uint32_t rand0, rand1;
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

	if (delay_pc(entry)) {
		shadow_delay(b, ent, delay_inside);
		return;
	}
	if (entry == 0x240D) {
		shadow_delay(b, ent, color_inside);
		return;
	}
	if (entry == 0x2419 || entry == 0x2448 || entry == 0x24D7 ||
	    entry == 0x2A35) {
		uint16_t sp0 = Z80_SP(b->cpu);

		span_ret = (uint16_t)board_mem_read(b, sp0);
		span_ret = (uint16_t)(span_ret |
			(uint16_t)((uint16_t)board_mem_read(b, (uint16_t)(sp0 + 1u)) << 8));
		span_sp_back = (uint16_t)(sp0 + 2u);
		shadow_delay(b, ent, span_inside);
		return;
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

	rand0 = b->rand_state;
	prev_suspend = b->lift_suspend;
	b->lift_suspend = 1;
	returned = run_until_ret(b, ret, sp0);
	b->lift_suspend = prev_suspend;
	rand1 = b->rand_state;

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
	b->rand_state = rand0;

	if (ent && ent->fn) {
		char detail[120];
		ent->fn(b);
		apply_ret(b);
		if (b->rand_state != rand1) {
			snprintf(detail, sizeof detail, "rand expected %08X got %08X",
				 (unsigned)rand1, (unsigned)b->rand_state);
			fprintf(stderr, "shadow %s frame %u %s\n", name,
				b->frame_index, detail);
			shadow_misses++;
		} else if (diff_machine(b, &cpu_result, mem_result, spr_result,
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
	b->rand_state = rand1;
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
