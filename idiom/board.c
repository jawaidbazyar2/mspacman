/* Host side: the arcade board's memory map, ROM loading, and reset. */
#include "lift.h"
#include "dispatch.h"

#include <string.h>
#include <stdlib.h>

/* mspacmab / woodpek address map (MAME).
 * IRQ mask is a write to $5000 bit 0 (the live `ld (IN0),a`).
 * Sound enable is a write to $5001. ram.inc names those two the other way.
 * Unmapped device reads return $BF (pacman_read_nop). Empty ROM is $FF.
 * Video/color/work RAM are mirrored by ignoring A15 and A13, so the
 * text writer at $C000 lands in video RAM.
 */

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

uint8_t lift_random_byte(Board *b)
{
	b->rand_state = b->rand_state * LIFT_RAND_MUL + LIFT_RAND_ADD;
	return (uint8_t)(b->rand_state >> 24);
}

void board_init(Board *b)
{
	memset(b, 0, sizeof *b);
	b->corpus.dsw1 = LIFT_DSW1_DEFAULT;
	b->rand_seed = LIFT_RAND_SEED;
	b->rand_state = LIFT_RAND_SEED;
}

void board_load_rom(Board *b, const char *path)
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
	b->stop = 0;
	b->started = 0;
	b->restart = 0;
	b->rand_state = b->rand_seed;
	b->int_enabled = 0;
}

uint8_t board_mem_read(Board *b, uint16_t addr)
{
	return mem_read(b, addr);
}

void board_mem_write(Board *b, uint16_t addr, uint8_t data)
{
	mem_write(b, addr, data);
}

void board_frame(Board *b)
{
	b->stop = 0;
	b->cur.nreads = 0;
	b->cur.stop = LIFT_STOP_BUDGET;
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

	c_only_frame(b);
	b->cur.stop = b->stop ? LIFT_STOP_IDLE : LIFT_STOP_BUDGET;
	corpus_note_frame(b);

	if (b->frames_since_kick < 0xFFFFFFFFu)
		b->frames_since_kick++;
	int kick_reset = b->frames_since_kick >= LIFT_WATCHDOG_FRAMES;
	b->frame_index++;
	if (kick_reset)
		board_reset(b);
}
