#include "lift.h"

/* `inc l`: S, Z, H, P/V, Y, X from the result. N clear. C unchanged. */
static uint8_t inc_l(uint8_t value, uint8_t *flags)
{
	uint8_t next = (uint8_t)(value + 1u);

	*flags = (uint8_t)((next & 0xA8u) |
			   (next == 0 ? 0x40u : 0u) |
			   ((value ^ next) & 0x10u) |
			   (value == 0x7Fu ? 0x04u : 0u) |
			   (*flags & 0x01u));
	return next;
}

/* j_0042  append a task byte and a parameter to the task list
 * Entry:    B = task, C = parameter. ($4C80) = tail pointer.
 *           Flags' carry is live-in.
 * Exit:     The two bytes are stored at the tail. L advances twice.
 *           If the second `inc l` wraps L to 0, L is set to $C0.
 *           ($4C80) = the new tail. HL is that pointer.
 *           F is the second `inc l`. Carry is unchanged.
 *           Host finishes the RET.
 * Clobbers: HL, F
 * Flags live-out: none at the direct calls. Each one reaches rst $30,
 *           rst $28, `inc a`, or a ret before it tests flags.
 *           rst $28 falls into this entry after pushing its return.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0042(Board *b)
{
	uint16_t lo = board_mem_read(b, 0x4C80);
	uint16_t hi = board_mem_read(b, 0x4C81);
	uint16_t hl = (uint16_t)(lo | (uint16_t)(hi << 8));
	uint8_t flags = Z80_F(b->cpu);
	uint8_t l;

	board_mem_write(b, hl, Z80_B(b->cpu));
	l = inc_l((uint8_t)hl, &flags);
	hl = (uint16_t)((hl & 0xFF00u) | l);
	board_mem_write(b, hl, Z80_C(b->cpu));
	l = inc_l(l, &flags);
	hl = (uint16_t)((hl & 0xFF00u) | l);
	if (l == 0)
		hl = (uint16_t)((hl & 0xFF00u) | 0xC0u);
	board_mem_write(b, 0x4C80, (uint8_t)hl);
	board_mem_write(b, 0x4C81, (uint8_t)(hl >> 8));
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
}
