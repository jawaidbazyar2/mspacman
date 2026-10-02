#ifndef C_FIBER_H
#define C_FIBER_H

#include <stdint.h>

/* Callee-saved arm64 registers. The host and a lifted C routine each keep
 * their own stack: a longjmp back onto the stack the host is using would
 * overwrite the suspended caller. Switching stacks is the host transfer.
 * It is not a Z80 instruction and it does not charge cycles. */
typedef struct {
	uint64_t sp;
	uint64_t x19, x20, x21, x22, x23, x24, x25, x26, x27, x28;
	uint64_t fp, lr;
} Fiber;

void fiber_switch(Fiber *save, Fiber *restore);

#endif
