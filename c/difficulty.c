#include "lift.h"

/* j_083a  copy three difficulty bytes to the ghost leave-home limits
 * Entry:    HL = source (a row of the table at $0843). A and F are live-in.
 * Exit:     ($4DB8..$4DBA) = the three source bytes. HL = source+3,
 *           DE = $4DBB, BC = 0. F keeps S, Z, C; H, P/V, N are clear;
 *           Y and X come from (A + last byte copied).
 *           Host finishes the RET.
 * Clobbers: BC, DE, HL, F
 * Flags live-out: none. The caller replaces F with `add a,a`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_083a(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint16_t de = 0x4DB8;
	uint16_t bc = 0x0003;
	uint8_t a = Z80_A(b->cpu);
	uint8_t f = Z80_F(b->cpu);
	uint8_t byte = 0;
	uint8_t sum;

	Z80_DE(b->cpu) = de;
	Z80_BC(b->cpu) = bc;
	while (bc != 0) {
		byte = board_mem_read(b, hl);
		hl = (uint16_t)(hl + 1u);
		board_mem_write(b, de, byte);
		de = (uint16_t)(de + 1u);
		bc = (uint16_t)(bc - 1u);
	}
	sum = (uint8_t)(byte + a);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = de;
	Z80_BC(b->cpu) = bc;
	Z80_F(b->cpu) = (uint8_t)((f & 0xC1u) |
				  (uint8_t)((sum & 0x02u) << 4) |
				  (sum & 0x08u));
}
