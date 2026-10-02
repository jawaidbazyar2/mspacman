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

/* One `ldir`. S, Z, and C stay as they were when the block started. */
static void ldir_block(Board *b, uint16_t *hl, uint16_t *de, uint16_t count,
			uint8_t *flags)
{
	uint8_t a = Z80_A(b->cpu);
	uint8_t kept = (uint8_t)(*flags & 0xC1u);
	uint8_t byte = 0;
	uint8_t sum;

	while (count != 0) {
		byte = board_mem_read(b, *hl);
		*hl = (uint16_t)(*hl + 1u);
		board_mem_write(b, *de, byte);
		*de = (uint16_t)(*de + 1u);
		count = (uint16_t)(count - 1u);
	}
	sum = (uint8_t)(byte + a);
	*flags = (uint8_t)(kept |
			   (uint8_t)((sum & 0x02u) << 4) |
			   (sum & 0x08u));
}

/* `sbc hl, bc` with carry already clear. */
static void sbc_hl_bc(uint16_t *hl, uint16_t bc, uint8_t *flags)
{
	uint32_t total = (uint32_t)*hl - bc;
	uint16_t result = (uint16_t)total;
	uint16_t mix = (uint16_t)((*hl ^ bc) & (*hl ^ result));
	uint8_t high = (uint8_t)(total >> 8);

	*flags = (uint8_t)((high & 0xA8u) |
			   (result == 0 ? 0x40u : 0u) |
			   (uint8_t)(((*hl ^ bc ^ result) >> 8) & 0x10u) |
			   ((mix & 0x8000u) != 0 ? 0x04u : 0u) |
			   ((total >> 16) & 1u) |
			   0x02u);
	*hl = result;
}

/* j_0814  copy the speed-pattern rows into work RAM
 * Entry:    HL = source row. A is live-in (it tints the final `ldir` flags).
 * Exit:     0x1C bytes, then three rewound 0x0C copies, then 0x0E more,
 *           land at $4D46 onward. HL = source + $2A. DE = $4D94. BC = 0.
 *           F is the last `ldir`. Its S, Z, and C come from the last
 *           `sbc hl, bc`. Y and X come from (A + the last byte).
 *           Host finishes the RET.
 * Clobbers: BC, DE, HL, F
 * Flags live-out: none. The caller loads A from the table next.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0814(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint16_t de = 0x4D46;
	uint8_t flags = Z80_F(b->cpu);

	ldir_block(b, &hl, &de, 0x001C, &flags);
	sbc_hl_bc(&hl, 0x000C, &flags);
	ldir_block(b, &hl, &de, 0x000C, &flags);
	sbc_hl_bc(&hl, 0x000C, &flags);
	ldir_block(b, &hl, &de, 0x000C, &flags);
	sbc_hl_bc(&hl, 0x000C, &flags);
	ldir_block(b, &hl, &de, 0x000C, &flags);
	ldir_block(b, &hl, &de, 0x000E, &flags);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = de;
	Z80_BC(b->cpu) = 0;
	Z80_F(b->cpu) = flags;
}

/* Even parity sets P/V. */
static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

/* `and a`. H is set. N and C are clear. */
static uint8_t and_a_flags(uint8_t a)
{
	return (uint8_t)(0x10u | parity_pv(a) | (a & 0xA8u) |
			 (a == 0 ? 0x40u : 0u));
}

/* `sub n`. The difference replaces A. */
static uint8_t sub_a(uint8_t a, uint8_t rhs, uint8_t *flags)
{
	uint8_t diff = (uint8_t)(a - rhs);
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ rhs) & (a ^ diff)) & 0x80u) >> 5);
	uint8_t partial = (uint8_t)((a < rhs ? 1u : 0u) |
				    0x02u |
				    ov |
				    ((a ^ rhs ^ diff) & 0x10u));

	*flags = (uint8_t)(partial | (diff & 0xA8u) | (diff == 0 ? 0x40u : 0u));
	return diff;
}

/* $F4 minus dots eaten, then the threshold minus that remainder.
 * Carry means the flag stays off. A successful subtract leaves its flags. */
static int elroy_due(Board *b, uint16_t threshold, uint8_t *a, uint8_t *flags)
{
	uint8_t remain = sub_a(0xF4, board_mem_read(b, 0x4E0E), flags);

	Z80_B(b->cpu) = remain;
	*a = sub_a(board_mem_read(b, threshold), remain, flags);
	return (*flags & 0x01u) == 0;
}

/* j_20d7  raise the cruise-elroy flags once enough dots are gone
 * Entry:    ($4DA3) = orange substate. ($4E0E) = dots eaten.
 *           ($4DB6) and ($4DB7) are the two elroy flags.
 *           ($4DBB) and ($4DBC) are their thresholds.
 * Exit:     If orange is home: A = 0, F is `and a`.
 *           Otherwise HL = $4E0E.
 *           Each unset flag is tested as threshold - ($F4 - dots).
 *           Carry returns with that `sub` in A and F, and B = $F4 - dots.
 *           A passing test stores 1 and keeps that `sub`'s flags. `ld a,#01`
 *           does not change them. The first flag falls through into the second.
 *           If the second flag is already set: A = that byte, F is `and a`.
 *           Host finishes the RET.
 * Clobbers: A, F, and B and HL once orange is out
 * Flags live-out: none. The caller continues the ghost update.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee. The `jp` at $2108 is the next routine.
 */
void j_20d7(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA3);
	uint8_t flags = and_a_flags(a);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0)
		return;
	Z80_HL(b->cpu) = 0x4E0E;
	a = board_mem_read(b, 0x4DB6);
	flags = and_a_flags(a);
	if (a == 0) {
		if (!elroy_due(b, 0x4DBB, &a, &flags)) {
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			return;
		}
		board_mem_write(b, 0x4DB6, 0x01);
	}
	a = board_mem_read(b, 0x4DB7);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	if (!elroy_due(b, 0x4DBC, &a, &flags)) {
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		return;
	}
	board_mem_write(b, 0x4DB7, 0x01);
	Z80_A(b->cpu) = 0x01;
	Z80_F(b->cpu) = flags;
}

static void push_word(Board *b, uint16_t *sp, uint16_t value)
{
	*sp = (uint16_t)(*sp - 2u);
	board_mem_write(b, (uint16_t)(*sp + 1u), (uint8_t)(value >> 8));
	board_mem_write(b, *sp, (uint8_t)value);
}

static void call_lifted(Board *b, uint16_t ret, void (*fn)(Board *))
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, ret);
	Z80_SP(b->cpu) = sp;
	fn(b);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
}

static void put16(Board *b, uint16_t addr, uint16_t value)
{
	board_mem_write(b, addr, (uint8_t)value);
	board_mem_write(b, (uint16_t)(addr + 1u), (uint8_t)(value >> 8));
}

static uint16_t word_at(Board *b, uint16_t addr)
{
	return (uint16_t)(board_mem_read(b, addr) |
		(uint16_t)((uint16_t)board_mem_read(b, (uint16_t)(addr + 1u)) << 8));
}

extern void j_2bea(Board *b);

/* j_070e  load this board's difficulty row
 * Entry:    task $10, reached through the jump at $000D. B = 0 reads
 *           the index through ($4E0A). Any other B is the index.
 * Exit:     Speed patterns are copied from $330F. The ghost-leave
 *           limits, elroy thresholds, frightened time, and leave-home
 *           units are stored. The fruit row is redrawn by j_2bea.
 *           IX points at the six-byte row in the table at $0796.
 *           IY points at the leave-home word that was stored.
 *           A, F, BC, DE, and HL match j_2bea.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: j_2bea.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: the three calls. Callees are already C.
 */
void j_070e(Board *b)
{
	uint8_t index = Z80_B(b->cpu);
	uint16_t ix;
	uint8_t byte;
	uint8_t scaled;
	uint16_t iy;

	if (index == 0)
		index = board_mem_read(b, word_at(b, 0x4E0A));
	ix = (uint16_t)(0x0796u + (uint8_t)(index * 6u));
	byte = board_mem_read(b, ix);
	scaled = (uint8_t)(byte * 42u);
	Z80_A(b->cpu) = scaled;
	Z80_HL(b->cpu) = (uint16_t)(0x330Fu + scaled);
	Z80_IX(b->cpu) = ix;
	call_lifted(b, 0x073A, j_0814);

	board_mem_write(b, 0x4DB0, board_mem_read(b, (uint16_t)(ix + 1u)));
	byte = board_mem_read(b, (uint16_t)(ix + 2u));
	scaled = (uint8_t)(byte * 3u);
	Z80_HL(b->cpu) = (uint16_t)(0x0843u + scaled);
	call_lifted(b, 0x0750, j_083a);

	byte = board_mem_read(b, (uint16_t)(ix + 3u));
	iy = (uint16_t)(0x084Fu + (uint8_t)(byte * 2u));
	put16(b, 0x4DBB, word_at(b, iy));
	byte = board_mem_read(b, (uint16_t)(ix + 4u));
	iy = (uint16_t)(0x0861u + (uint8_t)(byte * 2u));
	put16(b, 0x4DBD, word_at(b, iy));
	byte = board_mem_read(b, (uint16_t)(ix + 5u));
	scaled = (uint8_t)(byte * 2u);
	iy = (uint16_t)(0x0873u + scaled);
	Z80_HL(b->cpu) = word_at(b, iy);
	put16(b, 0x4D95, Z80_HL(b->cpu));
	Z80_DE(b->cpu) = scaled;
	Z80_A(b->cpu) = scaled;
	Z80_IX(b->cpu) = ix;
	Z80_IY(b->cpu) = iy;
	call_lifted(b, 0x0795, j_2bea);
}
