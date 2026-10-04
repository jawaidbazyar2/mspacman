/* The phase 3 harness: the game bank as the 65816 sees it, shadow
 * comparison of lowered functions, the report, and the command line.
 *
 * main.c is compiled with -Dmain=idiom_main -Dboard_init=lower_board_init,
 * so this file's main() runs first and hands the remaining arguments on. */
#include "lift.h"
#include "game.h"
#include "hook.h"
#include "shadow.h"
#define LOWER_FN_TABLE
#include "entries.h"

#include <fnmatch.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int idiom_main(int argc, char **argv);
void board_init(Board *b);

Board *g_lower_board;

/* Everything game logic can change, as the frame record and later frames
 * see it. */
typedef struct LowerState {
	uint8_t mem[0x1000];          /* $4000-$4FFF */
	uint8_t latch[8];
	uint8_t spr2[16];
	uint8_t voice[32];
	uint32_t kick;
	uint8_t int_enabled, restart, started;
	int stop;
	uint32_t rand_state;
	uint16_t nreads;
	uint8_t reads[LIFT_MAX_READS];
	uint16_t read_pos;
	int mismatch;
	char msg[160];
} LowerState;

#define MAX_DEPTH 32

static struct {
	uint8_t on[LF_COUNT > 0 ? LF_COUNT : 1];
	uint8_t guard[LF_COUNT > 0 ? LF_COUNT : 1];
	int only;           /* --asm-only */
	int trace_fail;
	int cycles;
	int depth;
	LowerState snap[MAX_DEPTH];
	LowerState cres[MAX_DEPTH];
	uint8_t dp[16];
	uint8_t dp_n;
	uint8_t run_dp[16];
	uint8_t run_dp_n;
	/* Per function. */
	uint64_t calls[LF_COUNT > 0 ? LF_COUNT : 1];
	uint64_t cyc[LF_COUNT > 0 ? LF_COUNT : 1];
	uint64_t cyc_max[LF_COUNT > 0 ? LF_COUNT : 1];
	uint64_t bad[LF_COUNT > 0 ? LF_COUNT : 1];
	uint8_t traced[LF_COUNT > 0 ? LF_COUNT : 1];
	uint64_t total_bad;
	char run_err[192];
	int run_rc;
} S;

/* ---- The game bank. ---- */

static int game_ram(uint16_t a)
{
	return (a >= 0x4000 && a <= 0x47FF) || (a >= 0x4C00 && a <= 0x4FFF);
}

static int game_rom(uint16_t a)
{
	return a < 0x4000 || (a >= 0x8000 && a < 0xA000);
}

static int game_io(uint16_t a)
{
	return a >= 0x5000 && a <= 0x50FF;
}

static uint8_t host_read(uint16_t a, int *fault)
{
	Board *b = g_lower_board;
	switch (a - LOWER_HOST_BLOCK) {
	case HB_INT_ENABLED: return b->int_enabled;
	case HB_RESTART: return (uint8_t)b->restart;
	case HB_STARTED: return (uint8_t)b->started;
	case HB_STOP: return (uint8_t)b->stop;
	case HB_RAND + 0: return (uint8_t)b->rand_state;
	case HB_RAND + 1: return (uint8_t)(b->rand_state >> 8);
	case HB_RAND + 2: return (uint8_t)(b->rand_state >> 16);
	case HB_RAND + 3: return (uint8_t)(b->rand_state >> 24);
	default:
		if (a - LOWER_HOST_BLOCK >= HB_LATCH && a - LOWER_HOST_BLOCK < HB_LATCH + 8)
			return b->latch[a - LOWER_HOST_BLOCK - HB_LATCH];
		*fault = 1;
		return 0;
	}
}

static void host_write(uint16_t a, uint8_t v, int *fault)
{
	Board *b = g_lower_board;
	switch (a - LOWER_HOST_BLOCK) {
	case HB_INT_ENABLED: b->int_enabled = v; return;
	case HB_RESTART: b->restart = v; return;
	case HB_STARTED: b->started = v; return;
	case HB_STOP: b->stop = v; return;
	case HB_RAND + 0: b->rand_state = (b->rand_state & 0xFFFFFF00u) | v; return;
	case HB_RAND + 1: b->rand_state = (b->rand_state & 0xFFFF00FFu) | ((uint32_t)v << 8); return;
	case HB_RAND + 2: b->rand_state = (b->rand_state & 0xFF00FFFFu) | ((uint32_t)v << 16); return;
	case HB_RAND + 3: b->rand_state = (b->rand_state & 0x00FFFFFFu) | ((uint32_t)v << 24); return;
	default:
		*fault = 1;
	}
}

static int in_host(uint16_t a)
{
	return a >= LOWER_HOST_BLOCK && a < LOWER_HOST_BLOCK + HB_SIZE;
}

static uint8_t bus_read(uint16_t a, int *fault)
{
	if (game_rom(a) || game_ram(a) || game_io(a))
		return board_mem_read(g_lower_board, a);
	if (in_host(a))
		return host_read(a, fault);
	*fault = 1;
	return 0;
}

static void bus_write(uint16_t a, uint8_t v, int *fault)
{
	if (game_ram(a) || game_io(a)) {
		board_mem_write(g_lower_board, a, v);
		return;
	}
	if (in_host(a)) {
		host_write(a, v, fault);
		return;
	}
	*fault = 1;
}

/* ---- State snapshots. ---- */

static void capture(LowerState *s)
{
	Board *b = g_lower_board;
	memcpy(s->mem, b->mem + 0x4000, sizeof s->mem);
	memcpy(s->latch, b->latch, 8);
	memcpy(s->spr2, b->spr2, 16);
	memcpy(s->voice, b->audio.reg, 32);
	s->kick = b->frames_since_kick;
	s->int_enabled = b->int_enabled;
	s->restart = (uint8_t)b->restart;
	s->started = (uint8_t)b->started;
	s->stop = b->stop;
	s->rand_state = b->rand_state;
	s->nreads = b->cur.nreads;
	memcpy(s->reads, b->cur.reads, b->cur.nreads);
	s->read_pos = b->corpus.read_pos;
	s->mismatch = b->mismatch;
	memcpy(s->msg, b->corpus.mismatch_msg, sizeof s->msg);
}

static void apply(const LowerState *s)
{
	Board *b = g_lower_board;
	memcpy(b->mem + 0x4000, s->mem, sizeof s->mem);
	memcpy(b->latch, s->latch, 8);
	memcpy(b->spr2, s->spr2, 16);
	memcpy(b->audio.reg, s->voice, 32);
	b->frames_since_kick = s->kick;
	b->int_enabled = s->int_enabled;
	b->restart = s->restart;
	b->started = s->started;
	b->stop = s->stop;
	b->rand_state = s->rand_state;
	b->cur.nreads = s->nreads;
	memcpy(b->cur.reads, s->reads, s->nreads);
	b->corpus.read_pos = s->read_pos;
	b->mismatch = s->mismatch;
	memcpy(b->corpus.mismatch_msg, s->msg, sizeof s->msg);
}

static void addr_name(uint16_t a, char *out, size_t cap)
{
	const char *n = work_ram_name(a);
	if (n)
		snprintf(out, cap, "$%04X %s", a, n);
	else if (a < 0x4400)
		snprintf(out, cap, "$%04X tile", a);
	else if (a < 0x4800)
		snprintf(out, cap, "$%04X color", a);
	else if (a >= 0x4FF0)
		snprintf(out, cap, "$%04X sprite", a);
	else
		snprintf(out, cap, "$%04X", a);
}

/* First difference between the C result `c` and the 65816 result `m`. */
static int diff(const LowerState *c, const LowerState *m, char *out, size_t cap)
{
	for (unsigned i = 0; i < sizeof c->mem; i++) {
		if (c->mem[i] != m->mem[i]) {
			char name[96];
			addr_name((uint16_t)(0x4000 + i), name, sizeof name);
			snprintf(out, cap, "%s C=%02X 65816=%02X", name, c->mem[i], m->mem[i]);
			return 1;
		}
	}
#define CMP_ARR(f, label)                                                        \
	for (unsigned i = 0; i < sizeof c->f; i++)                               \
		if (c->f[i] != m->f[i]) {                                        \
			snprintf(out, cap, label "[%u] C=%02X 65816=%02X", i, c->f[i], \
				 m->f[i]);                                       \
			return 1;                                                \
		}
	CMP_ARR(latch, "latch")
	CMP_ARR(spr2, "sprite pos $5060")
	CMP_ARR(voice, "voice $5040")
#undef CMP_ARR
#define CMP_ONE(f, label)                                                         \
	if (c->f != m->f) {                                                       \
		snprintf(out, cap, label " C=%lX 65816=%lX", (unsigned long)c->f,   \
			 (unsigned long)m->f);                                    \
		return 1;                                                         \
	}
	CMP_ONE(kick, "watchdog")
	CMP_ONE(int_enabled, "int_enabled")
	CMP_ONE(restart, "restart")
	CMP_ONE(started, "started")
	CMP_ONE(stop, "stop")
	CMP_ONE(rand_state, "rand_state")
	CMP_ONE(nreads, "input reads")
	CMP_ONE(read_pos, "input read_pos")
	CMP_ONE(mismatch, "mismatch")
#undef CMP_ONE
	if (memcmp(c->reads, m->reads, c->nreads) != 0) {
		snprintf(out, cap, "input values differ");
		return 1;
	}
	return 0;
}

/* ---- Hooks. ---- */

int lower_enter(unsigned id)
{
	if (S.guard[id]) {
		S.guard[id] = 0;
		return 0;
	}
	if (!S.on[id])
		return 0;
	return S.only ? 2 : 1;
}

void lower_c_begin(unsigned id)
{
	if (S.depth >= MAX_DEPTH) {
		fprintf(stderr, "lower: shadow nesting deeper than %d at %s\n",
			MAX_DEPTH, k_lower_fns[id].name);
		exit(2);
	}
	capture(&S.snap[S.depth]);
	S.guard[id] = 1;
	S.depth++;
}

void lower_c_end(unsigned id)
{
	(void)id;
	int d = S.depth - 1;
	capture(&S.cres[d]);
	apply(&S.snap[d]);
}

void lower_dp(uint8_t off, uint8_t value)
{
	if (off < sizeof S.dp) {
		S.dp[off] = value;
		if (off + 1u > S.dp_n)
			S.dp_n = (uint8_t)(off + 1u);
	}
}

uint16_t lower_mem_addr(const void *p)
{
	const uint8_t *q = p;
	const uint8_t *m = g_lower_board->mem;
	if (q < m || q >= m + sizeof g_lower_board->mem) {
		fprintf(stderr, "lower: pointer argument is not in Board.mem\n");
		exit(2);
	}
	return (uint16_t)(q - m);
}

static uint32_t result_of(unsigned id, const L65Regs *r)
{
	switch (k_lower_fns[id].result) {
	case 'b': return r->a & 0xFFu;
	case 'w':
	case 'c': return r->x;
	default: return 0;
	}
}

static uint32_t run_once(unsigned id, L65Regs *regs)
{
	for (unsigned i = 0; i < S.run_dp_n; i++)
		l65_poke_dp((uint8_t)i, S.run_dp[i]);
	uint64_t c0 = l65_cycles();
	S.run_rc = l65_call(id, regs, S.run_err, sizeof S.run_err);
	uint64_t used = l65_cycles() - c0;
	S.calls[id]++;
	S.cyc[id] += used;
	if (used > S.cyc_max[id])
		S.cyc_max[id] = used;
	uint8_t why;
	uint16_t detail;
	if (S.run_rc == 0 && l65_failed(&why, &detail) && !g_lower_board->mismatch) {
		Board *b = g_lower_board;
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "frame %u %s", b->frame_index, lower_fail_text(why, detail));
		fprintf(stderr, "lift: %s\n", b->corpus.mismatch_msg);
		b->mismatch = 1;
	}
	return result_of(id, regs);
}

uint32_t lower_run(unsigned id, L65Regs *regs)
{
	memcpy(S.run_dp, S.dp, sizeof S.dp);
	S.run_dp_n = S.dp_n;
	S.dp_n = 0;
	uint32_t r = run_once(id, regs);
	if (S.run_rc != 0 && S.only) {
		fprintf(stderr, "lower: %s frame %u: %s\n", k_lower_fns[id].name,
			g_lower_board->frame_index, S.run_err);
		exit(2);
	}
	return r;
}

static void dump_trace(unsigned id, const L65Regs *args)
{
	char path[256];
	snprintf(path, sizeof path, "build/lower/trace-%s.txt", k_lower_fns[id].name);
	FILE *f = fopen(path, "w");
	if (!f)
		return;
	int d = S.depth - 1;
	LowerState keep;
	capture(&keep);
	apply(&S.snap[d]);
	L65Regs r = *args;
	l65_trace(f);
	run_once(id, &r);
	l65_trace(NULL);
	S.calls[id]--;
	fclose(f);
	apply(&keep);
	fprintf(stderr, "lower:   trace in %s\n", path);
}

void lower_finish(unsigned id, uint32_t c_result, uint32_t result65,
		  const L65Regs *args)
{
	int d = S.depth - 1;
	char what[224];
	int bad = 0;
	LowerState now;
	if (S.run_rc != 0) {
		snprintf(what, sizeof what, "%s", S.run_err);
		bad = 1;
	} else {
		capture(&now);
		if (diff(&S.cres[d], &now, what, sizeof what))
			bad = 1;
		else if (c_result != result65) {
			snprintf(what, sizeof what, "result C=%X 65816=%X",
				 (unsigned)c_result, (unsigned)result65);
			bad = 1;
		}
	}
	if (bad) {
		S.bad[id]++;
		S.total_bad++;
		if (S.bad[id] == 1) {
			char dpbuf[64] = "";
			for (unsigned i = 0; i < S.run_dp_n && i < 8; i++)
				snprintf(dpbuf + strlen(dpbuf), sizeof dpbuf - strlen(dpbuf),
					 " dp%u=%02X", i, S.run_dp[i]);
			fprintf(stderr,
				"lower: MISMATCH %s (%s) frame %u: %s  [A=%02X X=%04X Y=%04X%s]\n",
				k_lower_fns[id].name, k_lower_fns[id].file,
				g_lower_board->frame_index, what, args->a & 0xFF, args->x,
				args->y, dpbuf);
			if (S.trace_fail && !S.traced[id]) {
				S.traced[id] = 1;
				dump_trace(id, args);
			}
		}
	}
	apply(&S.cres[d]);
	S.depth--;
}

/* ---- Command line and report. ---- */

static void enable(const char *list)
{
	char *dup = strdup(list);
	for (char *tok = strtok(dup, ","); tok; tok = strtok(NULL, ",")) {
		int hit = 0;
		for (unsigned i = 0; i < LF_COUNT; i++) {
			const LowerFn *f = &k_lower_fns[i];
			char full[96];
			if (strcmp(f->file, "selftest") == 0)
				continue;
			snprintf(full, sizeof full, "%s.%s", f->file, f->name);
			if (strcmp(tok, "all") == 0 || fnmatch(tok, f->name, 0) == 0 ||
			    fnmatch(tok, full, 0) == 0) {
				S.on[i] = 1;
				hit = 1;
			}
		}
		if (!hit && strcmp(tok, "none") != 0 && strcmp(tok, "all") != 0)
			fprintf(stderr, "lower: --asm %s matches no lowered function\n", tok);
	}
	free(dup);
}

static void report(void)
{
	unsigned n_on = 0;
	for (unsigned i = 0; i < LF_COUNT; i++)
		n_on += S.on[i];
	if (S.cycles) {
		fprintf(stderr, "lower: %-24s %-10s %10s %12s %8s %8s\n", "function",
			"file", "calls", "cycles", "mean", "max");
		for (unsigned i = 0; i < LF_COUNT; i++) {
			if (!S.calls[i])
				continue;
			fprintf(stderr, "lower: %-24s %-10s %10llu %12llu %8llu %8llu\n",
				k_lower_fns[i].name, k_lower_fns[i].file,
				(unsigned long long)S.calls[i],
				(unsigned long long)S.cyc[i],
				(unsigned long long)(S.cyc[i] / S.calls[i]),
				(unsigned long long)S.cyc_max[i]);
		}
	}
	if (S.total_bad) {
		for (unsigned i = 0; i < LF_COUNT; i++)
			if (S.bad[i])
				fprintf(stderr, "lower: %s: %llu of %llu calls differ\n",
					k_lower_fns[i].name, (unsigned long long)S.bad[i],
					(unsigned long long)S.calls[i]);
	}
	printf("lower: %u functions on, %llu mismatched calls\n", n_on,
	       (unsigned long long)S.total_bad);
}

void lower_board_init(Board *b)
{
	board_init(b);
	g_lower_board = b;
}

int main(int argc, char **argv)
{
	const char *bin = "build/lower/lower.bin";
	const char *asm_list = NULL;
	const char *frame_log = NULL;
	const char *session = NULL;
	int selftest = 0;
	char **rest = calloc((size_t)argc + 1, sizeof *rest);
	int nrest = 0;
	rest[nrest++] = argv[0];
	for (int i = 1; i < argc; i++) {
		if (strncmp(argv[i], "--asm=", 6) == 0)
			asm_list = argv[i] + 6;
		else if (strcmp(argv[i], "--asm") == 0 && i + 1 < argc)
			asm_list = argv[++i];
		else if (strcmp(argv[i], "--asm-only") == 0)
			S.only = 1;
		else if (strcmp(argv[i], "--trace-fail") == 0)
			S.trace_fail = 1;
		else if (strcmp(argv[i], "--cycles") == 0)
			S.cycles = 1;
		else if (strcmp(argv[i], "--selftest") == 0)
			selftest = 1;
		else if (strcmp(argv[i], "--bin") == 0 && i + 1 < argc)
			bin = argv[++i];
		else if (strcmp(argv[i], "--frame-log") == 0 && i + 1 < argc)
			frame_log = argv[++i];
		else {
			if (strcmp(argv[i], "--replay") == 0 && i + 1 < argc)
				session = argv[i + 1];
			rest[nrest++] = argv[i];
		}
	}
#ifdef LOWER_ONLY
	S.only = 1;
#endif
	if (l65_init(bin) != 0)
		return 2;
	l65_set_bus(bus_read, bus_write);
	if (selftest)
		return lower_selftest();
	if (asm_list)
		enable(asm_list);
	int rc = idiom_main(nrest, rest);
#ifdef LOWER_ONLY
	lower_only_report(frame_log, session);
#else
	(void)frame_log;
	(void)session;
	report();
#endif
	free(rest);
	if (S.total_bad)
		return 1;
	return rc;
}

unsigned lower_find(const char *name)
{
	for (unsigned i = 0; i < LF_COUNT; i++)
		if (strcmp(k_lower_fns[i].name, name) == 0)
			return i;
	return (unsigned)-1;
}

void lower_set_board(Board *b)
{
	g_lower_board = b;
}
