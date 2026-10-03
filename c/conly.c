#include "dispatch.h"

#include <stdio.h>

/* The C-only frame. No Z80 instruction runs. At the vertical blank the
 * routines the interrupt ran are called, then the task list is drained
 * until it is empty. That point is the end of the frame and the present.
 * The emulated stack and register file stay, because the lifted
 * routines still keep their state there. */

static int sched_idle_pc(uint16_t pc)
{
	return pc >= 0x238D && pc <= 0x2392;
}

static uint16_t task_head(Board *b)
{
	return (uint16_t)(b->mem[0x4C82] | (uint16_t)(b->mem[0x4C83] << 8));
}

static int tasks_empty(Board *b)
{
	uint16_t p = task_head(b);

	if (p < 0x4C00 || p > 0x4FEF)
		return 1;
	return (b->mem[p] & 0x80u) != 0;
}

/* The registers the Z80 left in the idle spin, after `ld hl,($4C82)`. */
static void park(Board *b)
{
	Z80_HL(b->cpu) = task_head(b);
	Z80_MEMPTR(b->cpu) = 0x4C83;
	Z80_PC(b->cpu) = 0x2390;
	b->stop = 1;
}

static void fail(Board *b, uint16_t pc)
{
	if (b->mismatch)
		return;
	b->mismatch = 1;
	snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
		 "frame %u no C routine at %04X", b->frame_index, pc);
	fprintf(stderr, "lift: %s\n", b->corpus.mismatch_msg);
}

/* Self-test is not run. Power-on and the service switch start here, with
 * the vector and interrupt mode the self-test leaves. */
void c_only_power_on(Board *b)
{
	b->cpu.i = 0xFC;
	b->cpu.im = 1;
	b->cpu.request = 0;
	Z80_PC(b->cpu) = 0x234B;
}

static void run_to_idle(Board *b)
{
	int guard = 0;

	while (!b->mismatch && guard++ < 100000) {
		uint16_t pc = Z80_PC(b->cpu);

		if (pc == 0) {
			c_only_power_on(b);
			continue;
		}
		if (sched_idle_pc(pc) && tasks_empty(b)) {
			if (b->slice_armed) {
				b->mismatch = 1;
				snprintf(b->corpus.mismatch_msg,
					 sizeof b->corpus.mismatch_msg,
					 "frame %u setup finished before the arcade "
					 "frame ended at PC %04X HL %04X",
					 b->frame_index, b->slice_want[0],
					 b->slice_want[4]);
				return;
			}
			park(b);
			return;
		}
		if (c_run_pc(b) != 0) {
			fail(b, pc);
			return;
		}
		if (b->slice_hit) {
			b->corpus.paused++;
			return;
		}
	}
	fail(b, Z80_PC(b->cpu));
}

/* Checking an arcade trace, a frame whose record ended mid-setup holds the
 * setup routine at that point. The next frame resumes it after the
 * interrupt routines, as the Z80 did. Live play never holds. */
void c_only_frame(Board *b)
{
	b->cycles_left = (zusize)0x7FFFFFFF;
	b->slice_hit = 0;
	b->slice_armed = corpus_want_paused(b, b->slice_want);
	if (b->latch[0] && b->cpu.iff1) {
		uint16_t sp = (uint16_t)(Z80_SP(b->cpu) - 2u);
		uint16_t pc = Z80_PC(b->cpu);

		b->cpu.iff1 = 0;
		b->cpu.iff2 = 0;
		b->cpu.halt_line = 0;
		board_mem_write(b, (uint16_t)(sp + 1u), (uint8_t)(pc >> 8));
		board_mem_write(b, sp, (uint8_t)pc);
		Z80_SP(b->cpu) = sp;
		Z80_PC(b->cpu) = 0x0038;
		Z80_MEMPTR(b->cpu) = 0x0038;
		if (c_run_pc(b) != 0) {
			fail(b, 0x0038);
			return;
		}
	}
	run_to_idle(b);
	b->slice_armed = 0;
}
