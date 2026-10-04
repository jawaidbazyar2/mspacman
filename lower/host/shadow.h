/* Harness internals shared by shadow.c and selftest.c. */
#ifndef LOWER_SHADOW_H
#define LOWER_SHADOW_H

#include "lift.h"

/* The host block: Board fields game logic uses that are not in mem[],
 * at fixed addresses in the game bank above the arcade map. */
#define LOWER_HOST_BLOCK 0xF000u
enum {
	HB_INT_ENABLED = 0x00,
	HB_RESTART = 0x01,
	HB_STARTED = 0x02,
	HB_STOP = 0x03,
	HB_RAND = 0x04,     /* 4 bytes, little-endian */
	HB_LATCH = 0x08,    /* 8 bytes, read-only: latch[0..7] */
	HB_SIZE = 0x10
};

/* The IIgs host's video change log (VID_FULL, VID_N, VID_LOG in dp.s).
 * Plain RAM to the game logic; no frame record or diff covers it. */
#define LOWER_VID_LOG 0xF200u
#define LOWER_VID_LOG_SIZE 0x204u

/* sched.c fail() reasons, in A at WDM $02. X carries the detail. */
enum {
	FAIL_BAD_TASK = 1,   /* X = the task byte */
	FAIL_NOT_EMPTY = 2
};

extern Board *g_lower_board;

const char *lower_fail_text(uint8_t reason, uint16_t detail);
int lower_selftest(void);
unsigned lower_find(const char *name);
/* only.c: the per-frame cycle report, appended to log_path if set. */
void lower_only_report(const char *log_path, const char *session);

#endif
