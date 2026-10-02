#include "dispatch.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define CENSUS_MAX 1024
#define CENSUS_OPEN 64

typedef struct {
	uint16_t entry;
	uint16_t ret;
	uint16_t sp;
	int slot;
} OpenCall;

typedef struct {
	uint16_t pc;
	uint32_t calls;
	uint32_t rets;
	uint32_t escapes;
	uint32_t irqs;
	uint32_t min_left;
	int size;
	char name[32];
} CenStat;

static CenStat stats[CENSUS_MAX];
static int nstats;
static int *slot_of;
static OpenCall open_calls[CENSUS_OPEN];
static int open_n;
static int census_ready;

static int is_call_op(uint8_t op)
{
	return op == 0xCD || op == 0xC4 || op == 0xCC || op == 0xD4 ||
	       op == 0xDC || op == 0xE4 || op == 0xEC || op == 0xF4 || op == 0xFC;
}

static uint16_t read16(Board *b, uint16_t addr)
{
	uint16_t lo = board_mem_read(b, addr);
	uint16_t hi = board_mem_read(b, (uint16_t)(addr + 1u));
	return (uint16_t)(lo | (uint16_t)(hi << 8));
}

static void census_fetch(Board *b, uint16_t pc)
{
	int slot;
	uint16_t sp;
	uint16_t ret;
	uint16_t at;
	uint8_t op;
	uint16_t tgt;

	if (!census_ready)
		return;
	if (pc == 0x0038 && open_n > 0) {
		int i;
		for (i = 0; i < open_n; i++)
			stats[open_calls[i].slot].irqs++;
	}
	while (open_n > 0) {
		OpenCall *o = &open_calls[open_n - 1];
		if (pc == o->ret && Z80_SP(b->cpu) == (uint16_t)(o->sp + 2u)) {
			stats[o->slot].rets++;
			open_n--;
			continue;
		}
		break;
	}
	slot = slot_of[pc];
	if (slot < 0)
		return;
	sp = Z80_SP(b->cpu);
	ret = read16(b, sp);
	if (ret < 3)
		return;
	at = (uint16_t)(ret - 3u);
	op = board_mem_read(b, at);
	tgt = read16(b, (uint16_t)(at + 1u));
	if (!is_call_op(op) || tgt != pc)
		return;
	if (open_n > 0 && open_calls[open_n - 1].entry == pc &&
	    open_calls[open_n - 1].sp == sp)
		return;
	if (open_n >= CENSUS_OPEN)
		return;
	open_calls[open_n].entry = pc;
	open_calls[open_n].ret = ret;
	open_calls[open_n].sp = sp;
	open_calls[open_n].slot = slot;
	open_n++;
	stats[slot].calls++;
	if ((uint32_t)b->cycles_left < stats[slot].min_left)
		stats[slot].min_left = (uint32_t)b->cycles_left;
}

static void census_frame_end(Board *b)
{
	int i;
	(void)b;
	for (i = 0; i < open_n; i++)
		stats[open_calls[i].slot].escapes++;
	open_n = 0;
}

void census_attach(Board *b)
{
	FILE *f;
	int i;

	slot_of = malloc(65536u * sizeof *slot_of);
	if (!slot_of) {
		fprintf(stderr, "census: out of memory\n");
		return;
	}
	for (i = 0; i < 65536; i++)
		slot_of[i] = -1;
	f = fopen("build/c/leaves.txt", "r");
	if (!f) {
		fprintf(stderr, "census: cannot open build/c/leaves.txt\n");
		return;
	}
	for (;;) {
		unsigned addr = 0;
		int size = 0;
		char name[32];
		int n = fscanf(f, "%x %d %31s", &addr, &size, name);
		if (n != 3)
			break;
		if (nstats >= CENSUS_MAX || addr > 0xFFFFu)
			continue;
		stats[nstats].pc = (uint16_t)addr;
		stats[nstats].size = size;
		stats[nstats].min_left = 0xFFFFFFFFu;
		snprintf(stats[nstats].name, sizeof stats[nstats].name, "%s", name);
		slot_of[addr] = nstats;
		nstats++;
	}
	fclose(f);
	census_ready = 1;
	b->lift_watch = census_fetch;
	b->lift_frame_end = census_frame_end;
	fprintf(stderr, "census: %d candidate leaves\n", nstats);
}

int census_report(Board *b)
{
	int idx[CENSUS_MAX];
	int n = 0;
	int i;
	int winner = -1;
	(void)b;

	if (!census_ready) {
		fprintf(stderr, "census: no leaf list\n");
		return 1;
	}
	for (i = 0; i < nstats; i++) {
		CenStat *s = &stats[i];
		if (s->calls == 0)
			continue;
		idx[n++] = i;
	}
	for (i = 1; i < n; i++) {
		int v = idx[i];
		int j = i;
		while (j > 0) {
			CenStat *a = &stats[idx[j - 1]];
			CenStat *bstat = &stats[v];
			int worse = a->size > bstat->size ||
				    (a->size == bstat->size && a->pc > bstat->pc);
			if (!worse)
				break;
			idx[j] = idx[j - 1];
			j--;
		}
		idx[j] = v;
	}
	for (i = 0; i < n; i++) {
		CenStat *s = &stats[idx[i]];
		int ok = s->escapes == 0 && s->irqs == 0 && s->rets == s->calls;
		printf("%s %04X size %d calls %u rets %u escapes %u irq %u min_left %u %s\n",
		       ok ? "leaf" : "skip", s->pc, s->size, s->calls, s->rets,
		       s->escapes, s->irqs, s->min_left, s->name);
		if (ok && winner < 0)
			winner = idx[i];
	}
	if (winner < 0) {
		printf("winner none\n");
		return 1;
	}
	printf("winner %04X size %d %s\n", stats[winner].pc, stats[winner].size,
	       stats[winner].name);
	return 0;
}
