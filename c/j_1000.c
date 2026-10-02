#include "lift.h"

/* j_1000  clear the fruit
 * Entry:    fruit byte at $4DD4. A is ignored.
 * Exit:     A = 0, F = Z|PV (the xor a result), ($4DD4) = 0.
 *           Host finishes the RET: PC is the return address, SP is back,
 *           WZ holds that return address.
 * Clobbers: A, F
 * Flags live-out: none. Both callers jump unconditionally after the call.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_1000(Board *b)
{
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	board_mem_write(b, 0x4DD4, 0);
}
