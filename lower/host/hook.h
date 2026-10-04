/* Entry hooks. The Makefile force-includes this into every C file in lower/.
 *
 * LOWER_HOOK(fn, params...) is the first statement of a lowered function.
 * Switched off, it does nothing. Switched on, it runs the C body and the
 * 65816 from the same state, compares them, and keeps the C result
 * (shadow), or runs the 65816 alone (--asm-only). */
#ifndef LOWER_HOOK_H
#define LOWER_HOOK_H

#include <stdint.h>

#include "l65.h"

typedef struct LowerFn {
	const char *name;
	const char *file;
	char result;
} LowerFn;

/* 0: run the C. 1: shadow. 2: 65816 only. */
int lower_enter(unsigned id);
void lower_c_begin(unsigned id);
void lower_c_end(unsigned id);
uint32_t lower_run(unsigned id, L65Regs *regs);
void lower_finish(unsigned id, uint32_t c_result, uint32_t result65,
		  const L65Regs *args);
/* A direct-page argument byte for the next lower_run. */
void lower_dp(uint8_t off, uint8_t value);
/* The bus address of a pointer into Board.mem. */
uint16_t lower_mem_addr(const void *p);

#define lower_coord_word(c) ((uint16_t)((unsigned)(c).y | ((unsigned)(c).x << 8)))
#define lower_word_coord(w) ((Coord){ (uint8_t)(w), (uint8_t)((unsigned)(w) >> 8) })

#include "entries.h"

#define LOWER_HOOK(fn, ...) LH_##fn(__VA_ARGS__)

#endif
