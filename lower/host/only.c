/* The 65816-only build (make lower-only). No game-logic C is linked: the
 * frame entry main.c calls is lower.bin's, and its cycles are kept per
 * frame for the report. */
#include "dispatch.h"
#include "hook.h"
#include "shadow.h"

#include <stdio.h>
#include <stdlib.h>

static uint32_t *g_cyc;
static size_t g_n, g_cap;

void c_only_frame(Board *b)
{
	L65Regs r = { 0, 0, 0 };
	uint64_t c0 = l65_cycles();

	(void)b;
	lower_run(LF_c_only_frame, &r);
	if (g_n == g_cap) {
		g_cap = g_cap ? g_cap * 2 : 4096;
		g_cyc = realloc(g_cyc, g_cap * sizeof *g_cyc);
		if (!g_cyc) {
			fprintf(stderr, "lower: out of memory\n");
			exit(2);
		}
	}
	g_cyc[g_n++] = (uint32_t)(l65_cycles() - c0);
}

static int by_value(const void *a, const void *b)
{
	uint32_t x = *(const uint32_t *)a, y = *(const uint32_t *)b;
	return (x > y) - (x < y);
}

void lower_only_report(const char *log_path, const char *session)
{
	uint64_t sum = 0;
	size_t i;

	if (!g_n)
		return;
	if (log_path) {
		FILE *f = fopen(log_path, "a");
		if (f) {
			for (i = 0; i < g_n; i++)
				fprintf(f, "%s %zu %u\n", session ? session : "-", i + 1, g_cyc[i]);
			fclose(f);
		}
	}
	for (i = 0; i < g_n; i++)
		sum += g_cyc[i];
	qsort(g_cyc, g_n, sizeof *g_cyc, by_value);
	printf("lower: %zu frames, cycles per frame mean %llu, 99th %u, max %u\n",
	       g_n, (unsigned long long)(sum / g_n), g_cyc[(g_n * 99) / 100],
	       g_cyc[g_n - 1]);
}
