#include "lift.h"
#include "dispatch.h"

#include <Z/constants/boolean.h>

#include <string.h>
#include <stdlib.h>

/* mspacmab / woodpek address map (MAME).
 * IRQ mask is a write to $5000 bit 0 (the live `ld (IN0),a`).
 * Sound enable is a write to $5001. ram.inc names those two the other way.
 * Unmapped device reads return $BF (pacman_read_nop). Empty ROM is $FF.
 * Video/color/work RAM are mirrored by ignoring A15 and A13, so the
 * text writer at $C000 lands in video RAM.
 */

static int is_lifted(Board *b, uint16_t pc)
{
	for (int i = 0; i < b->lift_count; i++) {
		if (b->lift_pc[i] == pc)
			return 1;
	}
	return 0;
}

static int task_idle(Board *b)
{
	uint16_t lo = b->mem[0x4C82];
	uint16_t hi = b->mem[0x4C83];
	uint16_t p = (uint16_t)(lo | (uint16_t)(hi << 8));
	uint8_t v;
	if (p >= 0x4C00 && p <= 0x4FEF)
		v = b->mem[p];
	else
		v = 0;
	return (v & 0x80) != 0;
}

static uint8_t rom_read(Board *b, uint16_t addr)
{
	if (addr < 0x4000)
		return b->rom[addr];
	if (addr >= 0x8000 && addr < 0xA000)
		return b->rom[addr];
	if (addr >= 0xA000 && addr < 0xC000)
		return 0xFF;
	return 0xBF;
}

static void log_port(Board *b, uint8_t value)
{
	if (b->cur.nreads < LIFT_MAX_READS)
		b->cur.reads[b->cur.nreads++] = value;
}

static uint8_t take_logged(Board *b)
{
	uint8_t v;
	if (b->corpus.read_pos >= b->corpus.replay_nreads) {
		b->mismatch = 1;
		if (b->corpus.mismatch_msg[0] == 0) {
			snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
				 "frame %u input overrun (logged %u)",
				 b->frame_index, b->corpus.replay_nreads);
		}
		v = 0xFF;
	} else {
		v = b->corpus.replay_reads[b->corpus.read_pos++];
	}
	log_port(b, v);
	return v;
}

static uint8_t in0_value(Board *b)
{
	if (b->corpus.replaying)
		return take_logged(b);
	uint8_t v = (uint8_t)(0xFF & ~b->input.clear_in0);
	log_port(b, v);
	return v;
}

static uint8_t in1_value(Board *b)
{
	if (b->corpus.replaying)
		return take_logged(b);
	uint8_t v = (uint8_t)(0xFF & ~b->input.clear_in1);
	log_port(b, v);
	return v;
}

static uint8_t mem_read(Board *b, uint16_t addr)
{
	if (addr < 0x4000 || (addr >= 0x8000 && addr < 0xC000))
		return rom_read(b, addr);

	uint16_t a = (uint16_t)(addr & (uint16_t)~0xA000u);
	if (a >= 0x4000 && a <= 0x43FF)
		return b->mem[a];
	if (a >= 0x4400 && a <= 0x47FF)
		return b->mem[a];
	if (a >= 0x4800 && a <= 0x4BFF)
		return 0xBF;
	if (a >= 0x4C00 && a <= 0x4FFF)
		return b->mem[a];

	if (a >= 0x5000 && a <= 0x503F)
		return in0_value(b);
	if (a >= 0x5040 && a <= 0x507F)
		return in1_value(b);
	if (a >= 0x5080 && a <= 0x50BF)
		return b->corpus.dsw1;
	if (a >= 0x50C0 && a <= 0x50FF)
		return 0xFF;
	return 0xBF;
}

static void latch_write(Board *b, unsigned n, uint8_t data)
{
	b->latch[n] = (uint8_t)(data & 1);
	if (n == 0 && b->latch[0] == 0)
		z80_int(&b->cpu, Z_FALSE);
}

static void mem_write(Board *b, uint16_t addr, uint8_t data)
{
	if (addr < 0x4000 || (addr >= 0x8000 && addr < 0xC000))
		return;

	uint16_t a = (uint16_t)(addr & (uint16_t)~0xA000u);
	if (a >= 0x4000 && a <= 0x43FF) {
		b->mem[a] = data;
		return;
	}
	if (a >= 0x4400 && a <= 0x47FF) {
		b->mem[a] = data;
		return;
	}
	if (a >= 0x4800 && a <= 0x4BFF)
		return;
	if (a >= 0x4C00 && a <= 0x4FFF) {
		b->mem[a] = data;
		return;
	}

	if (a >= 0x5000 && a <= 0x503F) {
		latch_write(b, a & 7, data);
		return;
	}
	if (a >= 0x5040 && a <= 0x505F) {
		b->audio.reg[a - 0x5040] = (uint8_t)(data & 0x0F);
		return;
	}
	if (a >= 0x5060 && a <= 0x506F) {
		b->spr2[a - 0x5060] = data;
		return;
	}
	if (a >= 0x5070 && a <= 0x50BF)
		return;
	if (a >= 0x50C0 && a <= 0x50FF)
		b->frames_since_kick = 0;
}

/* z80_break still runs the fetched instruction. A lifted entry is replaced
 * with NOP so the host can undo it and stand at the call boundary. */
static uint8_t steal_nop(Board *b, uint16_t addr)
{
	b->lift_nop = 1;
	b->lift_entry = addr;
	b->lift_q_saved = b->cpu.q;
	z80_break(&b->cpu);
	return 0x00;
}

static int rand_pc(uint16_t pc)
{
	return pc == 0x8768 || pc == 0x87D2 || pc == 0x956C;
}

uint8_t lift_random_byte(Board *b)
{
	b->rand_state = b->rand_state * LIFT_RAND_MUL + LIFT_RAND_ADD;
	return (uint8_t)(b->rand_state >> 24);
}

void board_apply_draw(Board *b)
{
	if (!b->rand_draw)
		return;
	b->rand_draw = 0;
	Z80_A(b->cpu) = lift_random_byte(b);
}

static zuint8 cb_fetch_opcode(void *ctx, zuint16 addr)
{
	Board *b = ctx;
	if (rand_pc(addr)) {
		b->rand_draw = 1;
		z80_break(&b->cpu);
	}
	if (b->lift_watch)
		b->lift_watch(b, addr);
	if (!b->lift_suspend && b->c_depth > 0 && addr == LIFT_SENTINEL) {
		b->lift_sentinel = 1;
		return steal_nop(b, addr);
	}
	if (!b->lift_suspend && b->lift_dispatch && is_lifted(b, addr)) {
		b->lift_hit = 1;
		return steal_nop(b, addr);
	}
	if (is_lifted(b, addr)) {
		b->lift_hit = 1;
		z80_break(&b->cpu);
	}
	if (addr == 0x0038)
		b->irq_seen = 1;
	if (!b->lift_suspend && b->irq_seen && addr == 0x238D && task_idle(b)) {
		b->stop = 1;
		z80_break(&b->cpu);
	}
	return mem_read(b, addr);
}

static zuint8 cb_read(void *ctx, zuint16 addr)
{
	return mem_read((Board *)ctx, addr);
}

static void cb_write(void *ctx, zuint16 addr, zuint8 data)
{
	mem_write((Board *)ctx, addr, data);
}

static zuint8 cb_in(void *ctx, zuint16 addr)
{
	(void)ctx;
	(void)addr;
	return 0xFF;
}

static void cb_out(void *ctx, zuint16 addr, zuint8 data)
{
	(void)ctx;
	(void)addr;
	(void)data;
}

void board_init(Board *b)
{
	memset(b, 0, sizeof *b);
	b->corpus.dsw1 = LIFT_DSW1_DEFAULT;
	b->cpu.context = b;
	b->cpu.fetch_opcode = cb_fetch_opcode;
	b->cpu.fetch = cb_read;
	b->cpu.read = cb_read;
	b->cpu.write = cb_write;
	b->cpu.in = cb_in;
	b->cpu.out = cb_out;
	b->cpu.options = Z80_MODEL_ZILOG_NMOS;
	b->rand_seed = LIFT_RAND_SEED;
	b->rand_state = LIFT_RAND_SEED;
	z80_power(&b->cpu, Z_TRUE);
}

void board_load_cpu(Board *b, const char *path)
{
	FILE *f = fopen(path, "rb");
	if (!f) {
		fprintf(stderr, "lift: cannot open CPU image %s\n", path);
		exit(1);
	}
	memset(b->rom, 0xFF, sizeof b->rom);
	size_t n = fread(b->rom, 1, sizeof b->rom, f);
	fclose(f);
	if (n < 0xA000) {
		fprintf(stderr, "lift: %s is %zu bytes, need at least 40960\n", path, n);
		exit(1);
	}
	board_reset(b);
}

void board_reset(Board *b)
{
	memset(b->mem, 0, sizeof b->mem);
	memcpy(b->mem + 0x4000, b->corpus.reset_ram, 0x1000);
	memset(b->spr2, 0, sizeof b->spr2);
	memset(b->latch, 0, sizeof b->latch);
	memset(b->audio.reg, 0, sizeof b->audio.reg);
	memset(b->audio.counter, 0, sizeof b->audio.counter);
	b->frames_since_kick = 0;
	b->irq_seen = 0;
	b->stop = 0;
	b->rand_state = b->rand_seed;
	b->rand_draw = 0;
	/* instant_reset leaves AF/SP/WZ/Q. Two runs must start from the same
	 * power-on image or the frame records diverge. */
	if (b->cpu.halt_line)
		z80_instant_reset(&b->cpu);
	z80_power(&b->cpu, Z_TRUE);
	z80_int(&b->cpu, Z_FALSE);
}

void board_lift_add(Board *b, uint16_t pc)
{
	if (b->lift_count < LIFT_MAX_LIFTS)
		b->lift_pc[b->lift_count++] = pc;
}

uint8_t board_mem_read(Board *b, uint16_t addr)
{
	return mem_read(b, addr);
}

void board_mem_write(Board *b, uint16_t addr, uint8_t data)
{
	mem_write(b, addr, data);
}

static void undo_nop(Board *b)
{
	uint8_t r;

	Z80_PC(b->cpu) = b->lift_entry;
	b->cpu.q = b->lift_q_saved;
	r = z80_r(&b->cpu);
	r = (uint8_t)((r & 0x80u) | ((r - 1u) & 0x7Fu));
	b->cpu.r = r;
	b->cpu.r7 = r;
}

static void charge(Board *b, zusize ran)
{
	if (ran >= b->cycles_left)
		b->cycles_left = 0;
	else
		b->cycles_left -= ran;
}

static void run_lifted(Board *b)
{
	volatile int guard = 0;

	c_host_prove(b);

	while (b->cycles_left > 0 && !b->stop && guard++ < 2000000) {
		zusize ran;

		b->lift_nop = 0;
		b->lift_hit = 0;
		b->lift_sentinel = 0;
		ran = z80_run(&b->cpu, b->cycles_left);
		board_apply_draw(b);
		if (b->lift_nop) {
			undo_nop(b);
			if (ran >= 4)
				ran -= 4;
			else
				ran = 0;
		}
		if (ran == 0 && !b->lift_hit && !b->lift_sentinel)
			break;
		charge(b, ran);
		if (b->lift_sentinel) {
			b->lift_sentinel = 0;
			c_host_sentinel(b);
			continue;
		}
		if (b->lift_hit && b->lift_dispatch) {
			uint16_t entry = b->lift_entry;
			b->lift_hit = 0;
			c_host_lift(b, entry);
		}
	}
}

void board_frame(Board *b)
{
	b->irq_seen = 0;
	b->stop = 0;
	b->lift_hit = 0;
	b->cur.nreads = 0;
	b->cur.stop = LIFT_STOP_BUDGET;
	b->cycles_left = LIFT_CYCLES_PER_FRAME;
	b->corpus.mismatch_msg[0] = 0;
	if (b->corpus.replaying) {
		if (b->frame_index >= b->corpus.play_count) {
			b->mismatch = 1;
			snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
				 "frame %u past end of trace", b->frame_index);
			return;
		}
		if (corpus_begin_frame(b) != 0) {
			b->mismatch = 1;
			return;
		}
	}

	if (b->latch[0])
		z80_int(&b->cpu, Z_TRUE);

	if (b->c_depth != 0) {
		fprintf(stderr, "lift: call depth %d leaked into frame %u\n",
			b->c_depth, b->frame_index);
		b->c_depth = 0;
	}

	if (b->lift_dispatch) {
		run_lifted(b);
	} else {
		int guard = 0;
		while (b->cycles_left > 0 && !b->stop && guard++ < 2000000) {
			zusize ran = z80_run(&b->cpu, b->cycles_left);
			board_apply_draw(b);
			if (ran == 0)
				break;
			if (ran >= b->cycles_left)
				b->cycles_left = 0;
			else
				b->cycles_left -= ran;
		}
	}
	if (b->lift_frame_end)
		b->lift_frame_end(b);
	b->cur.stop = b->stop ? LIFT_STOP_IDLE : LIFT_STOP_BUDGET;
	corpus_note_frame(b);

	if (b->frames_since_kick < 0xFFFFFFFFu)
		b->frames_since_kick++;
	int kick_reset = b->frames_since_kick >= LIFT_WATCHDOG_FRAMES;
	b->frame_index++;
	if (kick_reset)
		board_reset(b);
}
