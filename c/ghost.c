#include "lift.h"

static void write_hl(Board *b, uint16_t addr)
{
	uint16_t hl = Z80_HL(b->cpu);

	board_mem_write(b, addr, (uint8_t)hl);
	board_mem_write(b, (uint16_t)(addr + 1u), (uint8_t)(hl >> 8));
}

/* j_267e  store HL into the four ghost positions
 * Entry:    HL = the position word (callers pass 0 to clear them).
 * Exit:     ($4D00), ($4D02), ($4D04), ($4D06) = HL, low byte first.
 *           Registers and flags are unchanged.
 *           Host finishes the RET.
 * Clobbers: none
 * Flags live-out: none. Both callers overwrite flags before a test.
 *           j_2675 falls into this entry; the host pops that call's return.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_267e(Board *b)
{
	write_hl(b, 0x4D00);
	write_hl(b, 0x4D02);
	write_hl(b, 0x4D04);
	write_hl(b, 0x4D06);
}

/* j_2a12  square A into HL
 * Entry:    A = the value to square.
 * Exit:     HL = A * A. E = A, D = 0, C = 0. A and B are unchanged.
 *           F is the last `dec c`: Z and N set, H and P/V clear,
 *           C is the carry from that iteration's last `add hl`.
 *           Host finishes the RET.
 * Clobbers: HL, DE, C, F
 * Flags live-out: none. One caller pushes HL; the other adds BC,
 *           which replaces F.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_2a12(Board *b)
{
	uint8_t a = Z80_A(b->cpu);
	uint16_t hl = (uint16_t)((uint16_t)a << 8);
	uint16_t de = a;
	uint8_t c = 8;
	uint8_t carry = 0;

	while (c != 0) {
		uint32_t doubled = (uint32_t)hl + hl;

		hl = (uint16_t)doubled;
		carry = doubled > 0xFFFFu ? 1u : 0u;
		if (carry != 0) {
			uint32_t sum = (uint32_t)hl + de;

			hl = (uint16_t)sum;
			carry = sum > 0xFFFFu ? 1u : 0u;
		}
		c = (uint8_t)(c - 1u);
	}
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = de;
	Z80_C(b->cpu) = 0;
	Z80_F(b->cpu) = (uint8_t)(0x42u | carry);
}

/* `cp n`. A is not modified. Y and X come from the operand. */
static uint8_t cp_flags(uint8_t a, uint8_t n)
{
	uint8_t diff = (uint8_t)(a - n);
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ n) & (a ^ diff)) & 0x80u) >> 5);

	return (uint8_t)((diff & 0x80u) |
			 (diff == 0 ? 0x40u : 0u) |
			 ((a ^ n ^ diff) & 0x10u) |
			 ov |
			 (a < n ? 1u : 0u) |
			 (n & 0x28u) |
			 0x02u);
}

/* Even parity sets P/V, matching `xor`. */
static uint8_t parity_pv(uint8_t value)
{
	uint8_t x = value;

	x = (uint8_t)(x ^ (uint8_t)(x >> 4));
	x = (uint8_t)(x ^ (uint8_t)(x >> 2));
	x = (uint8_t)(x ^ (uint8_t)(x >> 1));
	return (uint8_t)(((x ^ 1u) & 1u) << 2);
}

/* j_0e23  advance the ghost animation every eighth call
 * Entry:    ($4DC4) = frame divider. ($4DC0) = animation phase.
 * Exit:     HL = $4DC4. ($4DC4) has been incremented.
 *           If it is not 8: A = 8, F is `cp (hl)`, and the phase is unchanged.
 *           If it is 8: ($4DC4) = 0, A = ($4DC0) xor 1, that byte is stored,
 *           and F is the `xor`.
 *           Host finishes the RET.
 * Clobbers: A, F, HL
 * Flags live-out: none. Callers go straight into another call.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0e23(Board *b)
{
	uint8_t next = (uint8_t)(board_mem_read(b, 0x4DC4) + 1u);
	uint8_t phase;

	board_mem_write(b, 0x4DC4, next);
	Z80_HL(b->cpu) = 0x4DC4;
	Z80_A(b->cpu) = 0x08;
	if (next != 0x08) {
		Z80_F(b->cpu) = cp_flags(0x08, next);
		return;
	}
	board_mem_write(b, 0x4DC4, 0);
	phase = (uint8_t)(board_mem_read(b, 0x4DC0) ^ 0x01u);
	board_mem_write(b, 0x4DC0, phase);
	Z80_A(b->cpu) = phase;
	Z80_F(b->cpu) = (uint8_t)(parity_pv(phase) | (phase & 0xA8u) |
				  (phase == 0 ? 0x40u : 0u));
}

static void write_word(Board *b, uint16_t addr, uint16_t value)
{
	board_mem_write(b, addr, (uint8_t)value);
	board_mem_write(b, (uint16_t)(addr + 1u), (uint8_t)(value >> 8));
}

/* j_2675  clear the fruit, Ms. Pac-Man, and the four ghosts
 * Entry:    Flags are live-in.
 * Exit:     HL = 0. ($4DD2), ($4D08), and the four ghost positions are 0.
 *           Flags are unchanged.
 *           Host finishes the RET.
 * Clobbers: HL
 * Flags live-out: all. The caller has just done `dec (hl)` and this
 *           routine must leave that result alone.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. Falls into j_267e. No callee.
 */
void j_2675(Board *b)
{
	Z80_HL(b->cpu) = 0;
	write_word(b, 0x4DD2, 0);
	write_word(b, 0x4D08, 0);
	j_267e(b);
}

/* `and a`. H is set. N and C are clear. */
static uint8_t and_a_flags(uint8_t a)
{
	return (uint8_t)(0x10u | parity_pv(a) | (a & 0xA8u) |
			 (a == 0 ? 0x40u : 0u));
}

/* j_2069  release the pink ghost from the house
 * Entry:    ($4DA1) = pink substate. ($4E12) = died-this-level.
 *           ($4D9F) = pills eaten since death. ($4E0F) = pink pill counter.
 *           ($4DB8) = pink leave-home limit.
 * Exit:     If pink is already out: A = the substate, F is `and a`.
 *           If the death flag is set and the pill count is not 7:
 *           A = that count, F is `cp 7`.
 *           If the death flag is clear and the counter is below the limit:
 *           A = the counter, HL = $4DB8, F is `cp (hl)` with carry set.
 *           Otherwise ($4DA1) = 2, A = 2, and F is the compare that released her.
 *           Host finishes the RET.
 * Clobbers: A, F, and HL on the counter path
 * Flags live-out: none. The next call loads A and then `and a`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_2069(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA1);
	uint8_t flags = and_a_flags(a);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	a = board_mem_read(b, 0x4E12);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0) {
		a = board_mem_read(b, 0x4D9F);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = cp_flags(a, 0x07);
		if (a != 0x07)
			return;
	} else {
		uint8_t count = board_mem_read(b, 0x4E0F);
		uint8_t limit = board_mem_read(b, 0x4DB8);

		Z80_HL(b->cpu) = 0x4DB8;
		Z80_A(b->cpu) = count;
		Z80_F(b->cpu) = cp_flags(count, limit);
		if (count < limit)
			return;
	}
	Z80_A(b->cpu) = 0x02;
	board_mem_write(b, 0x4DA1, 0x02);
}

/* j_208c  release the blue ghost from the house
 * Entry:    ($4DA2) = blue substate. ($4E12) = died-this-level.
 *           ($4D9F) = pills eaten since death. ($4E10) = blue pill counter.
 *           ($4DB9) = blue leave-home limit.
 * Exit:     Same shape as j_2069, with the pill test at $11 and the
 *           released substate stored as 3.
 *           Host finishes the RET.
 * Clobbers: A, F, and HL on the counter path
 * Flags live-out: none. The next call loads A and then `and a`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_208c(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA2);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	if (a != 0)
		return;
	a = board_mem_read(b, 0x4E12);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	if (a != 0) {
		a = board_mem_read(b, 0x4D9F);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = cp_flags(a, 0x11);
		if (a != 0x11)
			return;
	} else {
		uint8_t count = board_mem_read(b, 0x4E10);
		uint8_t limit = board_mem_read(b, 0x4DB9);

		Z80_HL(b->cpu) = 0x4DB9;
		Z80_A(b->cpu) = count;
		Z80_F(b->cpu) = cp_flags(count, limit);
		if (count < limit)
			return;
	}
	Z80_A(b->cpu) = 0x03;
	board_mem_write(b, 0x4DA2, 0x03);
}

/* j_20af  release the orange ghost, or clear the post-death counters
 * Entry:    ($4DA3) = orange substate. ($4E12) = died-this-level.
 *           ($4D9F) = pills eaten since death. ($4E11) = orange pill counter.
 *           ($4DBA) = orange leave-home limit.
 * Exit:     If orange is already out: A = the substate, F is `and a`.
 *           If the death flag is set and the pill count is not $20:
 *           A = that count, F is `cp $20`.
 *           If the pill count is $20: A = 0, F is `xor a`, and both
 *           ($4E12) and ($4D9F) are cleared. Orange stays home.
 *           If the death flag is clear and the counter is below the limit:
 *           A = the counter, HL = $4DBA, F is `cp (hl)` with carry set.
 *           Otherwise ($4DA3) = 3, A = 3, and F is that compare.
 *           Host finishes the RET.
 * Clobbers: A, F, and HL on the counter path
 * Flags live-out: none. The next call loads A and then `and a`.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_20af(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA3);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	if (a != 0)
		return;
	a = board_mem_read(b, 0x4E12);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = and_a_flags(a);
	if (a != 0) {
		a = board_mem_read(b, 0x4D9F);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = cp_flags(a, 0x20);
		if (a != 0x20)
			return;
		Z80_A(b->cpu) = 0;
		Z80_F(b->cpu) = 0x44;
		board_mem_write(b, 0x4E12, 0);
		board_mem_write(b, 0x4D9F, 0);
		return;
	}
	{
		uint8_t count = board_mem_read(b, 0x4E11);
		uint8_t limit = board_mem_read(b, 0x4DBA);

		Z80_HL(b->cpu) = 0x4DBA;
		Z80_A(b->cpu) = count;
		Z80_F(b->cpu) = cp_flags(count, limit);
		if (count < limit)
			return;
	}
	Z80_A(b->cpu) = 0x03;
	board_mem_write(b, 0x4DA3, 0x03);
}

/* `dec r`. C is unchanged. */
static uint8_t dec_flags(uint8_t value, uint8_t flags, uint8_t *next)
{
	uint8_t result = (uint8_t)(value - 1u);

	*next = result;
	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x80u ? 0x04u : 0u) |
			 0x02u |
			 (flags & 0x01u));
}

/* `inc r`. C is unchanged. */
static uint8_t inc_flags(uint8_t value, uint8_t flags, uint8_t *next)
{
	uint8_t result = (uint8_t)(value + 1u);

	*next = result;
	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x7Fu ? 0x04u : 0u) |
			 (flags & 0x01u));
}

/* Mark one ghost eaten and clear the kill-state byte. */
static void eaten(Board *b, uint16_t state, uint8_t a, uint8_t flags)
{
	uint8_t dead;

	board_mem_write(b, 0x4DAB, 0);
	flags = inc_flags(a, flags, &dead);
	board_mem_write(b, state, dead);
	Z80_A(b->cpu) = dead;
	Z80_F(b->cpu) = flags;
}

/* j_1066  mark the ghost that is being eaten
 * Entry:    ($4DAB) = kill state. 0 means nobody. 1 red, 2 pink, 3 blue,
 *           and any other value is orange after three decrements.
 * Exit:     If the state is 0: A = 0, F is `and a`.
 *           Otherwise the chosen ghost's state byte becomes 1, except
 *           orange, whose state becomes the value after three `dec`s.
 *           ($4DAB) becomes 0. F is the `inc` that made the 1, or the
 *           final `dec` on the orange path.
 *           Host finishes the RET.
 * Clobbers: A, F
 * Flags live-out: none. The caller moves on to the next ghost check.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_1066(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DAB);
	uint8_t flags = and_a_flags(a);
	uint8_t next;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0)
		return;
	flags = dec_flags(a, flags, &next);
	if (next == 0) {
		eaten(b, 0x4DAC, next, flags);
		return;
	}
	flags = dec_flags(next, flags, &next);
	if (next == 0) {
		eaten(b, 0x4DAD, next, flags);
		return;
	}
	flags = dec_flags(next, flags, &next);
	if (next == 0) {
		eaten(b, 0x4DAE, next, flags);
		return;
	}
	board_mem_write(b, 0x4DAF, next);
	flags = dec_flags(next, flags, &next);
	board_mem_write(b, 0x4DAB, next);
	Z80_A(b->cpu) = next;
	Z80_F(b->cpu) = flags;
}

/* j_1b08  count pills toward the next ghost leaving home
 * Entry:    ($4E12) = died-this-level. Ghost substates at $4DA1..$4DA3.
 * Exit:     If the death flag is set: ($4D9F) increments, HL = $4D9F,
 *           A stays the flag, F is `inc (hl)`.
 *           If orange is out: A = that substate, F is `and a`.
 *           If only orange is home: ($4E11) increments, HL = $4E11.
 *           If pink is out and the others are home: ($4E10) increments.
 *           If all three are home: ($4E0F) increments.
 *           On an increment, A is the substate just tested and F is `inc (hl)`.
 *           Host finishes the RET.
 * Clobbers: A, F, and HL when a counter increments
 * Flags live-out: none. Callers continue into the next per-frame check.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_1b08(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4E12);
	uint8_t flags = and_a_flags(a);
	uint8_t next;
	uint16_t addr;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		addr = 0x4D9F;
	else {
		a = board_mem_read(b, 0x4DA3);
		flags = and_a_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if (a != 0)
			return;
		a = board_mem_read(b, 0x4DA2);
		flags = and_a_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if (a != 0)
			addr = 0x4E11;
		else {
			a = board_mem_read(b, 0x4DA1);
			flags = and_a_flags(a);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			addr = a != 0 ? 0x4E10 : 0x4E0F;
		}
	}
	next = 0;
	flags = inc_flags(board_mem_read(b, addr), flags, &next);
	board_mem_write(b, addr, next);
	Z80_HL(b->cpu) = addr;
	Z80_F(b->cpu) = flags;
}

/* `sbc hl, de` with carry already clear. */
static uint8_t sbc_hl(uint16_t *hl, uint16_t de)
{
	uint16_t old = *hl;
	uint32_t total = (uint32_t)old - de;
	uint16_t result = (uint16_t)total;
	uint16_t mix = (uint16_t)((old ^ de) & (old ^ result));
	uint8_t high = (uint8_t)(total >> 8);

	*hl = result;
	return (uint8_t)((high & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 (uint8_t)(((old ^ de ^ result) >> 8) & 0x10u) |
			 ((mix & 0x8000u) != 0 ? 0x04u : 0u) |
			 ((total >> 16) & 1u) |
			 0x02u);
}

/* j_0e36  reverse the ghosts when the orientation timer matches
 * Entry:    ($4DA6) = power-pill effect. ($4DC1) = orientation index.
 *           ($4DC2) = orientation counter. The limit table is at $4D86.
 * Exit:     If a power pill is on: A = that byte, F is `and a`.
 *           If the index is 7: A stays 7, F is `cp 7`.
 *           Otherwise the counter increments, E was the doubled index,
 *           IX = $4D86 + that index, DE = the table word, HL = counter - DE,
 *           A stays the doubled index, F is `sbc hl, de`.
 *           When that subtract is zero: A = 1, F is `inc` of `xor a`,
 *           ($4DC1) = 1, HL = $0101, and $4DB1..$4DB4 are each 1.
 *           Host finishes the RET.
 * Clobbers: A, F, and DE, HL, IX once the timer runs
 * Flags live-out: none. The caller moves on to the sound update.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0e36(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA6);
	uint8_t flags = and_a_flags(a);
	uint16_t hl;
	uint16_t ix;
	uint16_t de;
	uint8_t next;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	a = board_mem_read(b, 0x4DC1);
	flags = cp_flags(a, 0x07);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 7)
		return;
	a = (uint8_t)(a + a);
	hl = board_mem_read(b, 0x4DC2);
	hl = (uint16_t)(hl | (uint16_t)((uint16_t)board_mem_read(b, 0x4DC3) << 8));
	hl = (uint16_t)(hl + 1u);
	board_mem_write(b, 0x4DC2, (uint8_t)hl);
	board_mem_write(b, 0x4DC3, (uint8_t)(hl >> 8));
	ix = (uint16_t)(0x4D86u + a);
	de = board_mem_read(b, ix);
	de = (uint16_t)(de |
			(uint16_t)((uint16_t)board_mem_read(b, (uint16_t)(ix + 1u)) << 8));
	flags = sbc_hl(&hl, de);
	Z80_A(b->cpu) = a;
	Z80_DE(b->cpu) = de;
	Z80_IX(b->cpu) = ix;
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;
	flags = inc_flags(0, 0x44, &next);
	board_mem_write(b, 0x4DC1, next);
	board_mem_write(b, 0x4DB1, 0x01);
	board_mem_write(b, 0x4DB2, 0x01);
	board_mem_write(b, 0x4DB3, 0x01);
	board_mem_write(b, 0x4DB4, 0x01);
	Z80_A(b->cpu) = next;
	Z80_F(b->cpu) = flags;
	Z80_HL(b->cpu) = 0x0101;
}

/* j_0bd6  paint ghost colors while they are eyes
 * Entry:    ($4E02) = subroutine number. Ghost states are $4DAC..$4DAF.
 *           Sprite color bytes sit at $4C03, $4C05, $4C07, and $4C09.
 * Exit:     B = 0 when the subroutine is $22, otherwise $19. IX = $4C00.
 *           Each ghost whose state is nonzero gets B stored in its color byte.
 *           A is the orange state. F is `and a` of that state.
 *           Host finishes the RET.
 * Clobbers: A, F, B, IX
 * Flags live-out: none. The caller continues the per-frame ghost work.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0bd6(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4E02);
	uint8_t color = 0x19;
	static const uint16_t state_addr[4] = { 0x4DAC, 0x4DAD, 0x4DAE, 0x4DAF };
	static const uint16_t color_addr[4] = { 0x4C03, 0x4C05, 0x4C07, 0x4C09 };
	int i;

	if (a == 0x22)
		color = 0;
	Z80_B(b->cpu) = color;
	Z80_IX(b->cpu) = 0x4C00;
	for (i = 0; i < 4; i++) {
		a = board_mem_read(b, state_addr[i]);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = and_a_flags(a);
		if (a != 0)
			board_mem_write(b, color_addr[i], color);
	}
}

/* j_1a6a  start the power-pill fright timer after an energizer
 * Entry:    ($4D9D) = the dot just eaten. 6 means an energizer.
 *           ($4DBD) = the fright duration for this board.
 * Exit:     If the dot is not 6: A stays that byte, F is `cp 6`.
 *           Otherwise the duration is copied to $4DCB. A = 0, F is `xor a`.
 *           $4DA6..$4DAA and $4DB1..$4DB5 are 1. $4DC8 and $4DD0 are 0.
 *           IX = $4C00. Sprite bytes $4C02,$4C04,$4C06,$4C08 are $1C.
 *           $4C03,$4C05,$4C07,$4C09 are $11.
 *           HL = $4EAC, with bit 5 set and bit 7 clear. `set` and `res`
 *           leave the `xor a` flags alone.
 *           Host finishes the RET.
 * Clobbers: A, F, and HL, IX when an energizer was eaten
 * Flags live-out: none. The caller continues the pill check.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee. $1A70 is this body, not a separate call.
 */
void j_1a6a(Board *b)
{
	static const uint16_t arm[10] = {
		0x4DA6, 0x4DA7, 0x4DA8, 0x4DA9, 0x4DAA,
		0x4DB1, 0x4DB2, 0x4DB3, 0x4DB4, 0x4DB5
	};
	static const uint16_t edible[4] = { 0x4C02, 0x4C04, 0x4C06, 0x4C08 };
	static const uint16_t blue[4] = { 0x4C03, 0x4C05, 0x4C07, 0x4C09 };
	uint8_t a = board_mem_read(b, 0x4D9D);
	uint16_t time;
	uint8_t ch;
	int i;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = cp_flags(a, 0x06);
	if (a != 0x06)
		return;
	time = board_mem_read(b, 0x4DBD);
	time = (uint16_t)(time |
			  (uint16_t)((uint16_t)board_mem_read(b, 0x4DBE) << 8));
	board_mem_write(b, 0x4DCB, (uint8_t)time);
	board_mem_write(b, 0x4DCC, (uint8_t)(time >> 8));
	for (i = 0; i < 10; i++)
		board_mem_write(b, arm[i], 0x01);
	board_mem_write(b, 0x4DC8, 0);
	board_mem_write(b, 0x4DD0, 0);
	for (i = 0; i < 4; i++) {
		board_mem_write(b, edible[i], 0x1C);
		board_mem_write(b, blue[i], 0x11);
	}
	ch = board_mem_read(b, 0x4EAC);
	ch = (uint8_t)((ch | 0x20u) & 0x7Fu);
	board_mem_write(b, 0x4EAC, ch);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	Z80_HL(b->cpu) = 0x4EAC;
	Z80_IX(b->cpu) = 0x4C00;
}

/* `or`. H, N, and C are clear. */
static uint8_t or_flags(uint8_t result)
{
	return (uint8_t)(parity_pv(result) | (result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u));
}

/* j_1376  count down the power-pill fright timer
 * Entry:    ($4DA6) = power-pill effect. ($4DA7..$4DAA) = ghost fright flags.
 *           ($4DCB) = fright timer.
 * Exit:     If the pill is off: A = 0, F is `and a`.
 *           If any ghost is still frightened and the timer is not zero:
 *           the timer decrements, IX = $4DA7, HL = the new timer,
 *           A = H | L, F is that `or`.
 *           Otherwise the pill ends. ($4C0B) = 9. A frightened flag is
 *           cleared when that ghost's state byte is 0. $4DCB, $4DCC,
 *           $4DA6, $4DC8, and $4DD0 are 0. HL = $4EAC with bits 5 and 7
 *           clear. A = 0, F is `xor a`. IX stays $4DA7.
 *           Host finishes the RET.
 * Clobbers: A, F, and HL, IX once the pill is on
 * Flags live-out: none. The caller continues the ghost update.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_1376(Board *b)
{
	static const uint16_t state_addr[4] = { 0x4DAC, 0x4DAD, 0x4DAE, 0x4DAF };
	static const uint16_t fright_addr[4] = { 0x4DA7, 0x4DA8, 0x4DA9, 0x4DAA };
	uint8_t a = board_mem_read(b, 0x4DA6);
	uint8_t flags = and_a_flags(a);
	uint16_t hl;
	uint8_t ch;
	int i;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0)
		return;
	a = board_mem_read(b, 0x4DA7);
	a = (uint8_t)(a | board_mem_read(b, 0x4DA8));
	a = (uint8_t)(a | board_mem_read(b, 0x4DA9));
	a = (uint8_t)(a | board_mem_read(b, 0x4DAA));
	Z80_IX(b->cpu) = 0x4DA7;
	if (a != 0) {
		hl = board_mem_read(b, 0x4DCB);
		hl = (uint16_t)(hl |
				(uint16_t)((uint16_t)board_mem_read(b, 0x4DCC) << 8));
		hl = (uint16_t)(hl - 1u);
		board_mem_write(b, 0x4DCB, (uint8_t)hl);
		board_mem_write(b, 0x4DCC, (uint8_t)(hl >> 8));
		a = (uint8_t)((uint8_t)(hl >> 8) | (uint8_t)hl);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = or_flags(a);
		Z80_HL(b->cpu) = hl;
		if (a != 0)
			return;
	}
	board_mem_write(b, 0x4C0B, 0x09);
	for (i = 0; i < 4; i++) {
		a = board_mem_read(b, state_addr[i]);
		if (a == 0)
			board_mem_write(b, fright_addr[i], 0);
	}
	board_mem_write(b, 0x4DCB, 0);
	board_mem_write(b, 0x4DCC, 0);
	board_mem_write(b, 0x4DA6, 0);
	board_mem_write(b, 0x4DC8, 0);
	board_mem_write(b, 0x4DD0, 0);
	ch = board_mem_read(b, 0x4EAC);
	ch = (uint8_t)(ch & (uint8_t)~0xA0u);
	board_mem_write(b, 0x4EAC, ch);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	Z80_HL(b->cpu) = 0x4EAC;
}

static uint16_t word_at(Board *b, uint16_t addr)
{
	uint16_t lo = board_mem_read(b, addr);

	return (uint16_t)(lo |
			  (uint16_t)((uint16_t)board_mem_read(b, (uint16_t)(addr + 1u)) << 8));
}

/* One ghost in the fright-color walk. Both "already normal" branches store
 * the same color. A frightened ghost whose timer is still at least $0100
 * leaves its color alone. */
static uint8_t flash_one(Board *b, uint16_t fright, uint16_t color_at,
			 uint8_t normal, uint16_t *hl, int *have_hl,
			 uint8_t *flags)
{
	uint8_t a = board_mem_read(b, fright);
	uint8_t color;

	*flags = and_a_flags(a);
	if (a == 0) {
		color = board_mem_read(b, color_at);
		*flags = cp_flags(normal, color);
		board_mem_write(b, color_at, normal);
		return normal;
	}
	*hl = word_at(b, 0x4DCB);
	*flags = sbc_hl(hl, 0x0100);
	*have_hl = 1;
	if ((*flags & 0x01u) == 0)
		return a;
	color = board_mem_read(b, color_at);
	*flags = cp_flags(0x11, color);
	board_mem_write(b, color_at, (*flags & 0x40u) != 0 ? 0x12 : 0x11);
	return 0x11;
}

/* j_0ac3  flash edible ghosts and tick the color counter
 * Entry:    ($4DA4) = ghosts killed but not yet collided. ($4DC8) = flash count.
 *           ($4DA6) = power pill. ($4DCB) = fright timer. DE's subtract is $0100.
 * Exit:     If a kill is pending: A = that byte, F is `and a`.
 *           Otherwise IX = $4C00, IY = $4DC8, DE = $0100.
 *           When the counter is not 0 it decrements and A stays 0.
 *           When it is 0 it is reloaded with $0E, the four ghost colors are
 *           walked, then the counter decrements. A frightened ghost below
 *           the $0100 mark alternates $11 and $12. A ghost that is not
 *           frightened is painted 1, 3, 5, or 7. A is whatever orange left.
 *           If the pill is on and the timer is below $0100, bit 7 of $4EAC
 *           is set, then cleared again when pac's color is already 9, and
 *           ($4C0B) = 9.
 *           F is the final `dec (iy)`. Its carry is the carry of the compare
 *           or subtract just before that decrement.
 *           Host finishes the RET.
 * Clobbers: A, F, and DE, IX, IY, and sometimes HL, once no kill is pending
 * Flags live-out: none. The caller moves on to the next per-frame check.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_0ac3(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA4);
	uint8_t flags = and_a_flags(a);
	uint8_t counter;
	uint8_t ch;
	uint16_t hl = 0;
	int have_hl = 0;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	Z80_IX(b->cpu) = 0x4C00;
	Z80_IY(b->cpu) = 0x4DC8;
	Z80_DE(b->cpu) = 0x0100;
	counter = board_mem_read(b, 0x4DC8);
	flags = cp_flags(0, counter);
	a = 0;
	if (counter == 0) {
		board_mem_write(b, 0x4DC8, 0x0E);
		a = board_mem_read(b, 0x4DA6);
		flags = and_a_flags(a);
		if (a != 0) {
			hl = word_at(b, 0x4DCB);
			flags = sbc_hl(&hl, 0x0100);
			have_hl = 1;
			if ((flags & 0x01u) != 0) {
				ch = (uint8_t)(board_mem_read(b, 0x4EAC) | 0x80u);
				board_mem_write(b, 0x4EAC, ch);
				hl = 0x4EAC;
				flags = cp_flags(0x09, board_mem_read(b, 0x4C0B));
				if ((flags & 0x40u) != 0) {
					ch = (uint8_t)(ch & 0x7Fu);
					board_mem_write(b, 0x4EAC, ch);
				}
				board_mem_write(b, 0x4C0B, 0x09);
				a = 0x09;
			}
		}
		a = flash_one(b, 0x4DA7, 0x4C03, 0x01, &hl, &have_hl, &flags);
		a = flash_one(b, 0x4DA8, 0x4C05, 0x03, &hl, &have_hl, &flags);
		a = flash_one(b, 0x4DA9, 0x4C07, 0x05, &hl, &have_hl, &flags);
		a = flash_one(b, 0x4DAA, 0x4C09, 0x07, &hl, &have_hl, &flags);
	}
	counter = board_mem_read(b, 0x4DC8);
	flags = dec_flags(counter, flags, &counter);
	board_mem_write(b, 0x4DC8, counter);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (have_hl)
		Z80_HL(b->cpu) = hl;
}

/* PUSH writes high byte then low byte, and leaves those bytes after POP. */
static void push_word(Board *b, uint16_t *sp, uint16_t value)
{
	*sp = (uint16_t)(*sp - 2u);
	board_mem_write(b, (uint16_t)(*sp + 1u), (uint8_t)(value >> 8));
	board_mem_write(b, *sp, (uint8_t)value);
}

/* Leave the CALL's return address in memory, then run a lifted callee. */
static void call_lifted(Board *b, uint16_t ret, void (*fn)(Board *))
{
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, ret);
	Z80_SP(b->cpu) = sp;
	fn(b);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
}

/* `add hl, rr`. S, Z, and P/V stay. N is clear. Y and X come from the high byte. */
static uint8_t add_hl_flags(uint16_t hl, uint16_t rhs, uint8_t flags, uint16_t *sum)
{
	uint32_t total = (uint32_t)hl + rhs;
	uint16_t result = (uint16_t)total;
	uint8_t high = (uint8_t)(total >> 8);

	*sum = result;
	return (uint8_t)((flags & 0xC4u) |
			 (high & 0x28u) |
			 (uint8_t)(((hl ^ rhs ^ result) >> 8) & 0x10u) |
			 (total > 0xFFFFu ? 1u : 0u));
}

/* Absolute difference. B ends as the smaller of the two inputs. */
static uint8_t abs_diff(uint8_t a, uint8_t *breg)
{
	if (a >= *breg)
		return (uint8_t)(a - *breg);

	{
		uint8_t other = *breg;

		*breg = a;
		return (uint8_t)(other - a);
	}
}

/* j_29ea  squared distance between Pac and one ghost
 * Entry:    IX points at Pac's Y,X. IY points at the ghost's Y,X.
 * Exit:     HL = (Y difference)^2 + (X difference)^2.
 *           A = the X difference. DE = that difference (D = 0).
 *           BC = the Y square, which the `pop bc` restored.
 *           F is `add hl, bc`. j_2a12 leaves Z set, and `add hl`
 *           keeps that Z, so Z is set here even when the sum is
 *           not zero. S and P/V stay clear. C is the 16-bit carry.
 *           The stack bytes below SP are the Y square, and under
 *           that the second call's return address ($2A0F). The
 *           first call's return address is overwritten by `push hl`.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: none. The caller uses HL.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: two calls and one push, all balanced. Callee is already C.
 */
void j_29ea(Board *b)
{
	uint16_t ix = Z80_IX(b->cpu);
	uint16_t iy = Z80_IY(b->cpu);
	uint8_t breg;
	uint8_t a;
	uint16_t sp;
	uint16_t ysq;
	uint16_t sum;

	a = board_mem_read(b, ix);
	breg = board_mem_read(b, iy);
	a = abs_diff(a, &breg);
	Z80_A(b->cpu) = a;
	Z80_B(b->cpu) = breg;
	call_lifted(b, 0x29FC, j_2a12);

	sp = Z80_SP(b->cpu);
	ysq = Z80_HL(b->cpu);
	push_word(b, &sp, ysq);
	Z80_SP(b->cpu) = sp;

	a = board_mem_read(b, (uint16_t)(ix + 1u));
	breg = board_mem_read(b, (uint16_t)(iy + 1u));
	a = abs_diff(a, &breg);
	Z80_A(b->cpu) = a;
	Z80_B(b->cpu) = breg;
	call_lifted(b, 0x2A0F, j_2a12);

	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	Z80_BC(b->cpu) = ysq;
	Z80_F(b->cpu) = add_hl_flags(Z80_HL(b->cpu), ysq, Z80_F(b->cpu), &sum);
	Z80_HL(b->cpu) = sum;
}

extern void j_2a23(Board *b);
extern void j_200f(Board *b);

/* `sub n`. The difference replaces A. */
static uint8_t sub_a(uint8_t a, uint8_t rhs, uint8_t *flags)
{
	uint8_t diff = (uint8_t)(a - rhs);
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ rhs) & (a ^ diff)) & 0x80u) >> 5);

	*flags = (uint8_t)((diff & 0xA8u) |
			   (diff == 0 ? 0x40u : 0u) |
			   ((a ^ rhs ^ diff) & 0x10u) |
			   ov |
			   (a < rhs ? 1u : 0u) |
			   0x02u);
	return diff;
}

/* j_291e  pick a random open direction for a ghost
 * Entry:    HL = the ghost's current tile. A = its current direction.
 * Exit:     ($4D3E) = that tile. ($4D3D) = the reversed direction.
 *           ($4D3B) = the chosen direction, 0..3. A = that direction.
 *           HL = the tile delta for it, from the table at $32FF.
 *           IX points at that table entry. IY = $4D3E.
 *           DE = twice the first random direction, before any retry.
 *           F is `sub #C0` of the open tile. The result is not zero,
 *           so the top two bits of the tile were not both set.
 *           The stack bytes below SP are the call to j_200f ($2947)
 *           and the calls that j_200f left under it. The earlier call
 *           to j_2a23 is overwritten.
 *           Host finishes the RET.
 * Clobbers: A, F, DE, HL, IX, IY
 * Flags live-out: none. The caller uses A and HL.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the random call and one tile check per try, all returned.
 *           Both callees are already C.
 */
void j_291e(Board *b)
{
	uint16_t hl = Z80_HL(b->cpu);
	uint8_t dir;
	uint16_t ix;
	uint8_t a;
	uint8_t flags;

	write_hl(b, 0x4D3E);
	board_mem_write(b, 0x4D3D, (uint8_t)(Z80_A(b->cpu) ^ 0x02u));
	call_lifted(b, 0x2929, j_2a23);
	dir = (uint8_t)(Z80_A(b->cpu) & 0x03u);
	board_mem_write(b, 0x4D3B, dir);
	Z80_DE(b->cpu) = (uint16_t)((uint16_t)dir << 1);
	ix = (uint16_t)(0x32FFu + (uint16_t)((uint16_t)dir << 1));
	Z80_IX(b->cpu) = ix;
	Z80_IY(b->cpu) = 0x4D3E;

	for (;;) {
		a = board_mem_read(b, 0x4D3D);
		flags = cp_flags(a, board_mem_read(b, 0x4D3B));
		if ((flags & 0x40u) == 0) {
			Z80_IX(b->cpu) = ix;
			call_lifted(b, 0x2947, j_200f);
			a = sub_a((uint8_t)(Z80_A(b->cpu) & 0xC0u), 0xC0, &flags);
			if (a != 0) {
				hl = board_mem_read(b, ix);
				hl = (uint16_t)(hl |
						(uint16_t)((uint16_t)board_mem_read(
								   b, (uint16_t)(ix + 1u))
							   << 8));
				Z80_HL(b->cpu) = hl;
				Z80_A(b->cpu) = board_mem_read(b, 0x4D3B);
				Z80_F(b->cpu) = flags;
				return;
			}
		}
		ix = (uint16_t)(ix + 2u);
		dir = (uint8_t)((board_mem_read(b, 0x4D3B) + 1u) & 0x03u);
		board_mem_write(b, 0x4D3B, dir);
	}
}

extern void j_2000(Board *b);
extern void j_0065(Board *b);

/* `srl a`. H and N are clear. C is the old bit 0. */
static uint8_t srl_a(uint8_t value, uint8_t *result)
{
	uint8_t shifted = (uint8_t)(value >> 1);

	*result = shifted;
	return (uint8_t)((shifted & 0xA8u) |
			 (shifted == 0 ? 0x40u : 0u) |
			 parity_pv(shifted) |
			 (value & 0x01u));
}

/* j_2966  choose the direction that gets closest to a target tile
 * Entry:    HL = current tile. DE = target tile. A = current direction.
 * Exit:     ($4D3E) = current tile. ($4D40) = target.
 *           ($4D3D) = the reversed direction. ($4DC7) = 4.
 *           ($4D44) = the smallest distance squared found, or $FFFF
 *           when every direction was blocked. ($4D3B) and A = the best
 *           direction, which stays the entry direction if none was open.
 *           HL = that direction's tile delta from the table at $32FF.
 *           IX points at the delta. IY = $4D3E. DE = twice the direction.
 *           F is `srl a` of that doubled direction.
 *           The stack bytes below SP are whatever the last of the four
 *           tries left: a blocked try leaves the j_0065 call, an open
 *           try leaves the saved IX and IY plus the j_29ea call under
 *           them, and the reversed direction leaves the previous try.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The caller uses A and HL.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: up to three calls per direction, all returned. Callees are C.
 */
void j_2966(Board *b)
{
	uint16_t ix = 0x32FF;
	uint16_t dest = Z80_DE(b->cpu);
	uint8_t best = Z80_A(b->cpu);
	uint8_t opposite = (uint8_t)(best ^ 0x02u);
	uint8_t counter = 0;
	uint8_t doubled;
	uint8_t a;
	uint8_t flags;

	write_hl(b, 0x4D3E);
	board_mem_write(b, 0x4D40, (uint8_t)dest);
	board_mem_write(b, 0x4D41, (uint8_t)(dest >> 8));
	board_mem_write(b, 0x4D3B, best);
	board_mem_write(b, 0x4D3D, opposite);
	board_mem_write(b, 0x4D44, 0xFF);
	board_mem_write(b, 0x4D45, 0xFF);
	Z80_IX(b->cpu) = ix;
	Z80_IY(b->cpu) = 0x4D3E;
	board_mem_write(b, 0x4DC7, 0);

	for (;;) {
		if (counter != opposite) {
			uint8_t blocked;

			Z80_IX(b->cpu) = ix;
			Z80_IY(b->cpu) = 0x4D3E;
			call_lifted(b, 0x2992, j_2000);
			write_hl(b, 0x4D42);
			call_lifted(b, 0x2998, j_0065);
			blocked = sub_a((uint8_t)(board_mem_read(b, Z80_HL(b->cpu)) & 0xC0u),
					0xC0, &flags);
			if (blocked != 0) {
				uint16_t sp = Z80_SP(b->cpu);
				uint16_t dist;
				uint16_t min;

				push_word(b, &sp, ix);
				push_word(b, &sp, 0x4D3E);
				Z80_SP(b->cpu) = sp;
				Z80_IX(b->cpu) = 0x4D40;
				Z80_IY(b->cpu) = 0x4D42;
				call_lifted(b, 0x29AE, j_29ea);
				Z80_SP(b->cpu) = (uint16_t)(sp + 4u);
				Z80_IX(b->cpu) = ix;
				Z80_IY(b->cpu) = 0x4D3E;
				dist = Z80_HL(b->cpu);
				min = word_at(b, 0x4D44);
				if (min >= dist) {
					board_mem_write(b, 0x4D44, (uint8_t)dist);
					board_mem_write(b, 0x4D45, (uint8_t)(dist >> 8));
					best = counter;
					board_mem_write(b, 0x4D3B, best);
				}
			}
		}
		ix = (uint16_t)(ix + 2u);
		counter = (uint8_t)(counter + 1u);
		board_mem_write(b, 0x4DC7, counter);
		if (counter == 4)
			break;
	}

	doubled = (uint8_t)(best << 1);
	Z80_DE(b->cpu) = doubled;
	ix = (uint16_t)(0x32FFu + doubled);
	Z80_IX(b->cpu) = ix;
	Z80_HL(b->cpu) = word_at(b, ix);
	Z80_F(b->cpu) = srl_a(doubled, &a);
	Z80_A(b->cpu) = a;
}

/* j_2086  send the pink ghost out of the house
 * Entry:    flags are live-in.
 * Exit:     A = 2. ($4DA1) = 2. Flags are unchanged.
 *           Host finishes the RET.
 * Clobbers: A
 * Flags live-out: all. The caller pops AF and returns on Z.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_2086(Board *b)
{
	Z80_A(b->cpu) = 0x02;
	board_mem_write(b, 0x4DA1, 0x02);
}

/* j_20a9  send the blue ghost out of the house
 * Entry:    flags are live-in.
 * Exit:     A = 3. ($4DA2) = 3. Flags are unchanged.
 *           Host finishes the RET.
 * Clobbers: A
 * Flags live-out: all. The caller pops AF and returns on Z.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_20a9(Board *b)
{
	Z80_A(b->cpu) = 0x03;
	board_mem_write(b, 0x4DA2, 0x03);
}

/* j_20d1  send the orange ghost out of the house
 * Entry:    flags are live-in.
 * Exit:     A = 3. ($4DA3) = 3. Flags are unchanged.
 *           Host finishes the RET.
 * Clobbers: A
 * Flags live-out: all. The caller returns without restoring AF.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: normal RET. No callee.
 */
void j_20d1(Board *b)
{
	Z80_A(b->cpu) = 0x03;
	board_mem_write(b, 0x4DA3, 0x03);
}

/* Save AF, optionally release one ghost, then pop AF back. */
static int release_if_home(Board *b, uint16_t state, uint16_t ret,
			   void (*fn)(Board *))
{
	uint8_t a = board_mem_read(b, state);
	uint8_t flags = and_a_flags(a);
	uint16_t sp = Z80_SP(b->cpu);

	push_word(b, &sp, (uint16_t)(((uint16_t)a << 8) | flags));
	Z80_SP(b->cpu) = sp;
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		call_lifted(b, ret, fn);
	Z80_SP(b->cpu) = (uint16_t)(sp + 2u);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	return (flags & 0x40u) != 0;
}

/* j_13dd  release a ghost that has waited in the house
 * Entry:    ($4E0E) = dots eaten. ($4D9E) = dots at the last Pac move.
 *           ($4D97) = idle time. ($4D95) = how long a ghost waits.
 * Exit:     If Pac has eaten since the last check, the idle time is
 *           cleared, A is the dot count, HL = 0, and F is the `cp`.
 *           Otherwise the idle time increments. When it does not match
 *           the wait, HL is the difference, DE is the wait, A is the
 *           dot count, and F is `sbc hl, de`.
 *           When it matches, the idle time is cleared again. The first
 *           ghost still at home (pink, then blue, then orange) is sent
 *           out. Pink and blue restore A and F from the `and a` of their
 *           state and return. Orange leaves A = 3 when it was home, with
 *           F still that `and a`.
 *           The stack bytes below SP are the saved AF, and under that
 *           the release call when pink or blue was home. Orange's call
 *           overwrites the saved AF.
 *           Host finishes the RET.
 * Clobbers: A, F, HL, and DE once the idle time is checked
 * Flags live-out: Z when a ghost is released or the dot counts match
 *           and the wait has elapsed.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: up to one call, returned. Callees are already C.
 */
void j_13dd(Board *b)
{
	uint8_t dots = board_mem_read(b, 0x4E0E);
	uint8_t since = board_mem_read(b, 0x4D9E);
	uint8_t flags = cp_flags(dots, since);
	uint16_t hl;
	uint16_t de;
	uint8_t orange;

	Z80_A(b->cpu) = dots;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0) {
		Z80_HL(b->cpu) = 0;
		write_hl(b, 0x4D97);
		return;
	}

	hl = (uint16_t)(word_at(b, 0x4D97) + 1u);
	Z80_HL(b->cpu) = hl;
	write_hl(b, 0x4D97);
	de = word_at(b, 0x4D95);
	flags = sbc_hl(&hl, de);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = de;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;

	Z80_HL(b->cpu) = 0;
	write_hl(b, 0x4D97);
	if (release_if_home(b, 0x4DA1, 0x140B, j_2086))
		return;
	if (release_if_home(b, 0x4DA2, 0x1415, j_20a9))
		return;

	orange = board_mem_read(b, 0x4DA3);
	flags = and_a_flags(orange);
	Z80_A(b->cpu) = orange;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		call_lifted(b, 0x141E, j_20d1);
}

/* `rst $18`: HL = the word at $32FF + 2*index. DE points at its high byte.
 * The rst return and the inner `rst $10` return ($001B) stay below SP.
 */
static uint16_t rst18(Board *b, uint16_t ret, uint8_t index)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint16_t at = (uint16_t)(0x32FFu + (uint16_t)((uint16_t)index << 1));
	uint8_t lo = board_mem_read(b, at);
	uint8_t hi;

	push_word(b, &sp, ret);
	push_word(b, &sp, 0x001B);
	at = (uint16_t)(at + 1u);
	hi = board_mem_read(b, at);
	Z80_DE(b->cpu) = at;
	return (uint16_t)(((uint16_t)hi << 8) | lo);
}

/* Reverse one ghost: flip its direction and load that tile delta. */
static void reverse_ghost(Board *b, uint16_t prev, uint16_t dir, uint16_t dy2,
			  uint16_t dy, uint16_t rst_ret)
{
	uint8_t turned = (uint8_t)(board_mem_read(b, prev) ^ 0x02u);
	uint16_t hl = rst18(b, rst_ret, turned);
	uint8_t sub = board_mem_read(b, 0x4E02);
	uint8_t flags = cp_flags(sub, 0x22);

	board_mem_write(b, dir, turned);
	Z80_B(b->cpu) = turned;
	Z80_HL(b->cpu) = hl;
	write_hl(b, dy2);
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0) {
		Z80_A(b->cpu) = sub;
		return;
	}
	write_hl(b, dy);
	board_mem_write(b, prev, turned);
	Z80_A(b->cpu) = turned;
}

/* j_1f2e  reverse the pink ghost
 * Entry:    ($4D29) = pink's previous direction.
 * Exit:     ($4D2D) = that direction with bit 1 flipped. B = the new
 *           direction. HL = its tile delta from $32FF. DE points at the
 *           high byte of that table word. ($4D20) = the delta.
 *           A = ($4E02) and F is `cp #22`, unless that byte is $22.
 *           Then ($4D16) = the delta, ($4D29) = the new direction, and
 *           A = the new direction. F stays the `cp`.
 *           The stack bytes below SP are the `rst $18` return $1F3B and
 *           the `rst $10` return $001B.
 *           Host finishes the RET.
 * Clobbers: A, F, B, DE, HL
 * Flags live-out: Z when ($4E02) is $22.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the two rst returns, both popped. No callee.
 */
void j_1f2e(Board *b)
{
	reverse_ghost(b, 0x4D29, 0x4D2D, 0x4D20, 0x4D16, 0x1F3B);
}

/* j_1f55  reverse the blue ghost
 * Entry:    ($4D2A) = blue's previous direction.
 * Exit:     Same shape as j_1f2e. The direction is stored at $4D2E,
 *           the delta at $4D22, and the demo copy at $4D18 and $4D2A.
 *           The outer rst return is $1F62.
 *           Host finishes the RET.
 * Clobbers: A, F, B, DE, HL
 * Flags live-out: Z when ($4E02) is $22.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the two rst returns, both popped. No callee.
 */
void j_1f55(Board *b)
{
	reverse_ghost(b, 0x4D2A, 0x4D2E, 0x4D22, 0x4D18, 0x1F62);
}

/* j_1f7c  reverse the orange ghost
 * Entry:    ($4D2B) = orange's previous direction.
 * Exit:     Same shape as j_1f2e. The direction is stored at $4D2F,
 *           the delta at $4D24, and the demo copy at $4D1A and $4D2B.
 *           The outer rst return is $1F89.
 *           Host finishes the RET.
 * Clobbers: A, F, B, DE, HL
 * Flags live-out: Z when ($4E02) is $22.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the two rst returns, both popped. No callee.
 */
void j_1f7c(Board *b)
{
	reverse_ghost(b, 0x4D2B, 0x4D2F, 0x4D24, 0x4D1A, 0x1F89);
}

extern void j_2000(Board *b);

/* `rlca`. S, Z, and P/V stay. Y, X, and C come from the rotated byte. */
static uint8_t rlca_flags(uint8_t value, uint8_t flags, uint8_t *rotated)
{
	uint8_t result = (uint8_t)((uint8_t)(value << 1) | (uint8_t)(value >> 7));

	*rotated = result;
	return (uint8_t)((flags & 0xC4u) | (result & 0x29u));
}

/* Add the offset at IX to the sprite at IY, and store the new position. */
static void step_sprite(Board *b, uint16_t ix, uint16_t iy, uint16_t ret,
			uint16_t pos)
{
	Z80_IX(b->cpu) = ix;
	Z80_IY(b->cpu) = iy;
	call_lifted(b, ret, j_2000);
	write_hl(b, pos);
}

/* `cp n`, then call when that compare sets Z. A comes back from the callee. */
static uint8_t cp_then_call(Board *b, uint8_t a, uint8_t n, uint16_t ret,
			    void (*fn)(Board *))
{
	uint8_t flags = cp_flags(a, n);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		call_lifted(b, ret, fn);
	return Z80_A(b->cpu);
}

/* Store one direction into both the current and previous slots. */
static void aim(Board *b, uint16_t prev, uint16_t dir, uint8_t way)
{
	Z80_A(b->cpu) = way;
	board_mem_write(b, prev, way);
	board_mem_write(b, dir, way);
}

/* Ghost is through the door: tile $2E2C, heading left, substate 1. */
static void exit_up(Board *b, uint16_t tile, uint16_t dy, uint16_t dy2,
		    uint16_t prev, uint16_t dir, uint16_t sub)
{
	Z80_HL(b->cpu) = 0x2E2C;
	write_hl(b, tile);
	Z80_HL(b->cpu) = 0x0100;
	write_hl(b, dy);
	write_hl(b, dy2);
	aim(b, prev, dir, 0x02);
	board_mem_write(b, sub, 0x01);
	Z80_A(b->cpu) = 0x01;
}

/* Step straight up. On Y == $64, record the ghost as outside. */
static void climb_out(Board *b, uint16_t y, uint16_t prev, uint16_t dir,
		      uint16_t tile, uint16_t dy, uint16_t dy2, uint16_t sub,
		      uint16_t ret)
{
	uint8_t pos;
	uint8_t flags;

	step_sprite(b, 0x3305, y, ret, y);
	aim(b, prev, dir, 0x03);
	pos = board_mem_read(b, y);
	flags = cp_flags(pos, 0x64);
	Z80_A(b->cpu) = pos;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		exit_up(b, tile, dy, dy2, prev, dir, sub);
}

/* Bob between Y $78 and Y $80, then step along the current delta. */
static void bob_in_house(Board *b, uint16_t y, uint16_t dir, uint16_t prev,
			 uint16_t dy2, uint16_t ret_top, uint16_t ret_bot,
			 uint16_t ret_step, void (*rev)(Board *))
{
	uint8_t a = board_mem_read(b, y);

	a = cp_then_call(b, a, 0x78, ret_top, rev);
	cp_then_call(b, a, 0x80, ret_bot, rev);
	a = board_mem_read(b, dir);
	board_mem_write(b, prev, a);
	Z80_A(b->cpu) = a;
	step_sprite(b, dy2, y, ret_step, y);
}

/* j_0c42  move ghosts that are still inside the house
 * Entry:    ($4DA4) = ghosts killed with no collision yet.
 *           ($4D94) = house-move timer. ($4DA0..$4DA3) = substates.
 * Exit:     If a kill is pending: A = that count, F is `and a`, nothing else.
 *           If the timer's bit 7 was clear: the timer is rotated left,
 *           A is that byte, and F is `rlca`.
 *           Otherwise each ghost still inside takes one step. A ghost
 *           whose substate is 0 bounces between Y $78 and Y $80. Substate
 *           2 climbs toward Y $64 and, on arrival, is placed at tile
 *           $2E2C heading left with substate 1. Blue's substate 3 walks
 *           right, and orange's walks left, until X is $80, then the
 *           substate becomes 2. A ghost already out (substate 1) is left
 *           alone. The routine returns from the orange ghost's path, so
 *           A, F, HL, IX, and IY are whatever that path last wrote.
 *           A reverse is a conditional call. Its A is what the next `cp`
 *           sees, which is the subroutine byte ($4E02) during a normal
 *           game, not the Y position the compare started with.
 *           Host finishes the RET.
 * Clobbers: A, F, HL, IX, IY. B and DE change when a reverse runs.
 * Flags live-out: none. The caller tests nothing from this return.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: each taken call leaves its return address. A reverse also
 *        leaves its two rst returns under that word. A later call at
 *        the same SP overwrites only the two return bytes.
 */
void j_0c42(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA4);
	uint8_t flags = and_a_flags(a);
	uint8_t rotated = 0;
	uint8_t pos;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;

	a = board_mem_read(b, 0x4D94);
	flags = rlca_flags(a, flags, &rotated);
	board_mem_write(b, 0x4D94, rotated);
	Z80_A(b->cpu) = rotated;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) == 0)
		return;

	a = board_mem_read(b, 0x4DA0);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		climb_out(b, 0x4D00, 0x4D28, 0x4D2C, 0x4D0A, 0x4D14, 0x4D1E,
			  0x4DA0, 0x0C61);

	a = board_mem_read(b, 0x4DA1);
	flags = cp_flags(a, 0x01);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0) {
		flags = cp_flags(a, 0x00);
		Z80_F(b->cpu) = flags;
		if ((flags & 0x40u) != 0)
			bob_in_house(b, 0x4D02, 0x4D2D, 0x4D29, 0x4D20,
				     0x0CA5, 0x0CAA, 0x0CBB, j_1f2e);
		else
			climb_out(b, 0x4D02, 0x4D29, 0x4D2D, 0x4D0C, 0x4D16,
				  0x4D20, 0x4DA1, 0x0CCC);
	}

	a = board_mem_read(b, 0x4DA2);
	flags = cp_flags(a, 0x01);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0) {
		flags = cp_flags(a, 0x00);
		Z80_F(b->cpu) = flags;
		if ((flags & 0x40u) != 0) {
			bob_in_house(b, 0x4D04, 0x4D2E, 0x4D2A, 0x4D22,
				     0x0D10, 0x0D15, 0x0D26, j_1f55);
		} else {
			a = board_mem_read(b, 0x4DA2);
			flags = cp_flags(a, 0x03);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			if ((flags & 0x40u) != 0) {
				step_sprite(b, 0x32FF, 0x4D04, 0x0D3F, 0x4D04);
				Z80_A(b->cpu) = 0;
				Z80_F(b->cpu) = 0x44;
				board_mem_write(b, 0x4D2A, 0);
				board_mem_write(b, 0x4D2E, 0);
				pos = board_mem_read(b, 0x4D05);
				flags = cp_flags(pos, 0x80);
				Z80_A(b->cpu) = pos;
				Z80_F(b->cpu) = flags;
				if ((flags & 0x40u) != 0) {
					board_mem_write(b, 0x4DA2, 0x02);
					Z80_A(b->cpu) = 0x02;
				}
			} else {
				climb_out(b, 0x4D04, 0x4D2A, 0x4D2E, 0x4D0E,
					  0x4D18, 0x4D22, 0x4DA2, 0x0D64);
			}
		}
	}

	a = board_mem_read(b, 0x4DA3);
	flags = cp_flags(a, 0x01);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return;

	flags = cp_flags(a, 0x00);
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0) {
		bob_in_house(b, 0x4D06, 0x4D2F, 0x4D2B, 0x4D24,
			     0x0DA6, 0x0DAB, 0x0DBC, j_1f7c);
		return;
	}

	a = board_mem_read(b, 0x4DA3);
	flags = cp_flags(a, 0x03);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0) {
		step_sprite(b, 0x3303, 0x4D06, 0x0DD3, 0x4D06);
		aim(b, 0x4D2B, 0x4D2F, 0x02);
		pos = board_mem_read(b, 0x4D07);
		flags = cp_flags(pos, 0x80);
		Z80_A(b->cpu) = pos;
		Z80_F(b->cpu) = flags;
		if ((flags & 0x40u) == 0)
			return;
		board_mem_write(b, 0x4DA3, 0x02);
		Z80_A(b->cpu) = 0x02;
		return;
	}

	climb_out(b, 0x4D06, 0x4D2B, 0x4D2F, 0x4D10, 0x4D1A, 0x4D24, 0x4DA3,
		  0x0DF5);
}

extern void j_2a5a(Board *b);

static uint16_t read_word(Board *b, uint16_t addr)
{
	uint8_t lo = board_mem_read(b, addr);
	uint8_t hi = board_mem_read(b, (uint16_t)(addr + 1u));

	return (uint16_t)(lo | (uint16_t)((uint16_t)hi << 8));
}

/* Shared tail of the ghost-collision checks. B is the ghost number, or 0. */
static void note_ghost_hit(Board *b, uint8_t breg)
{
	uint8_t flags = and_a_flags(breg);
	uint16_t hl;
	uint8_t count;
	uint8_t snd;

	board_mem_write(b, 0x4DA4, breg);
	board_mem_write(b, 0x4DA5, breg);
	Z80_A(b->cpu) = breg;
	Z80_F(b->cpu) = flags;
	Z80_B(b->cpu) = breg;
	if ((flags & 0x40u) != 0)
		return;

	Z80_DE(b->cpu) = breg;
	hl = (uint16_t)(0x4DA6u + breg);
	Z80_HL(b->cpu) = hl;
	breg = board_mem_read(b, hl);
	flags = and_a_flags(breg);
	Z80_A(b->cpu) = breg;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return;

	board_mem_write(b, 0x4DA5, 0);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	count = (uint8_t)(board_mem_read(b, 0x4DD0) + 1u);
	board_mem_write(b, 0x4DD0, count);
	Z80_HL(b->cpu) = 0x4DD0;
	Z80_B(b->cpu) = (uint8_t)(count + 1u);
	call_lifted(b, 0x1783, j_2a5a);
	snd = (uint8_t)(board_mem_read(b, 0x4EBC) | 0x08u);
	board_mem_write(b, 0x4EBC, snd);
	Z80_HL(b->cpu) = 0x4EBC;
}

/* j_171d  tile collision between Pac and a ghost
 * Entry:    ($4D39) = Pac's tile. Ghost tiles are at $4D31, $4D33,
 *           $4D35, and $4D37. Ghost states are at $4DAC through $4DAF.
 * Exit:     B = 4, 3, 2, or 1 for orange, blue, pink, or red, or 0 when
 *           nobody shares Pac's tile. ($4DA4) and ($4DA5) = B.
 *           If B is 0, A = 0 and F is `and a`.
 *           If that ghost's byte at $4DA6+B is 0, A is that byte and F
 *           is `and a`. DE = B.
 *           If the ghost is edible, ($4DA5) is cleared, the kill count
 *           at $4DD0 increments, B = that count plus 1, and j_2a5a scores
 *           it. Then bit 3 of $4EBC is set and HL = $4EBC. A and F are
 *           whatever j_2a5a left.
 *           Host finishes the RET.
 * Clobbers: A, F, B, DE, HL. The score call also clobbers C.
 * Flags live-out: none. The caller moves on to the next task.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the score call ($1783) when a blue ghost is eaten. No other call.
 */
void j_171d(Board *b)
{
	static const uint16_t state[4] = { 0x4DAF, 0x4DAE, 0x4DAD, 0x4DAC };
	static const uint16_t tile[4] = { 0x4D37, 0x4D35, 0x4D33, 0x4D31 };
	uint16_t pac = read_word(b, 0x4D39);
	uint8_t breg = 4;
	int i;

	Z80_DE(b->cpu) = pac;
	Z80_B(b->cpu) = breg;
	for (i = 0; i < 4; i++) {
		uint8_t a = board_mem_read(b, state[i]);
		uint8_t flags = and_a_flags(a);

		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if ((flags & 0x40u) != 0) {
			uint16_t hl = (uint16_t)(read_word(b, tile[i]) - pac);

			Z80_HL(b->cpu) = hl;
			if (hl == 0)
				break;
		}
		breg = (uint8_t)(breg - 1u);
		Z80_B(b->cpu) = breg;
	}
	note_ghost_hit(b, breg);
}

/* 8-bit `sub` then `cp limit`. Carry means the difference is below the limit. */
static int closer_than(uint8_t ghost, uint8_t pac, uint8_t limit)
{
	return (uint8_t)(ghost - pac) < limit;
}

/* j_1789  sprite collision with an edible ghost
 * Entry:    ($4DA4) = a kill already waiting. ($4DA6) = power pill.
 *           IX is not required. Pac's pixels are at $4D08.
 * Exit:     If a kill is already waiting: A = that byte, F is `and a`.
 *           If the power pill is off: A = 0, F is `and a`.
 *           Otherwise C = 4 and IX = $4D08. A ghost whose Y and X are
 *           each less than 4 pixels above Pac's, by an 8-bit subtract,
 *           is handed to the same tail as j_171d. B is 4, 3, 2, 1, or 0
 *           for orange, blue, pink, red, or nobody.
 *           Host finishes the RET.
 * Clobbers: A, F, and, once the scan starts, BC, IX, HL, DE
 * Flags live-out: none. The caller moves on to the next task.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the score call inside the shared tail, when a ghost is eaten.
 */
void j_1789(Board *b)
{
	static const uint16_t state[4] = { 0x4DAF, 0x4DAE, 0x4DAD, 0x4DAC };
	static const uint16_t yx[4] = { 0x4D06, 0x4D04, 0x4D02, 0x4D00 };
	uint8_t a = board_mem_read(b, 0x4DA4);
	uint8_t flags = and_a_flags(a);
	uint8_t breg;
	uint8_t limit;
	uint8_t pac_y;
	uint8_t pac_x;
	int i;

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;

	a = board_mem_read(b, 0x4DA6);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return;

	limit = 4;
	breg = 4;
	Z80_C(b->cpu) = limit;
	Z80_B(b->cpu) = breg;
	Z80_IX(b->cpu) = 0x4D08;
	pac_y = board_mem_read(b, 0x4D08);
	pac_x = board_mem_read(b, 0x4D09);
	for (i = 0; i < 4; i++) {
		uint16_t pos = yx[i];

		a = board_mem_read(b, state[i]);
		flags = and_a_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if ((flags & 0x40u) != 0 &&
		    closer_than(board_mem_read(b, pos), pac_y, limit) &&
		    closer_than(board_mem_read(b, (uint16_t)(pos + 1u)), pac_x,
				limit))
			break;
		breg = (uint8_t)(breg - 1u);
		Z80_B(b->cpu) = breg;
	}
	note_ghost_hit(b, breg);
}

/* `inc (hl)`. N is clear. C stays. */
static uint8_t inc_byte(Board *b, uint16_t addr, uint8_t flags)
{
	uint8_t value = board_mem_read(b, addr);
	uint8_t result = (uint8_t)(value + 1u);

	board_mem_write(b, addr, result);
	return (uint8_t)((result & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 ((value ^ result) & 0x10u) |
			 (value == 0x7Fu ? 0x04u : 0u) |
			 (flags & 0x01u));
}

/* Step one pixel. Returns Z when the tested axis byte equals `goal`. */
static int axis_at(Board *b, uint16_t ix, uint16_t iy, uint16_t ret,
		   uint16_t pos, uint16_t prev, uint16_t dir, uint8_t way,
		   uint16_t axis, uint8_t goal)
{
	uint8_t a;
	uint8_t flags;

	Z80_IX(b->cpu) = ix;
	Z80_IY(b->cpu) = iy;
	call_lifted(b, ret, j_2000);
	write_hl(b, pos);
	Z80_A(b->cpu) = way;
	board_mem_write(b, prev, way);
	board_mem_write(b, dir, way);
	a = board_mem_read(b, axis);
	flags = cp_flags(a, goal);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	return (flags & 0x40u) != 0;
}

/* j_1101: if every ghost is alive, clear the eyes sound. A starts at 0. */
static void eyes_quiet(Board *b)
{
	uint8_t a = Z80_A(b->cpu);
	uint8_t flags = Z80_F(b->cpu);
	uint16_t addr;
	uint8_t snd;

	Z80_IX(b->cpu) = 0x4DAC;
	for (addr = 0x4DAC; addr <= 0x4DAF; addr++) {
		a = (uint8_t)(a | board_mem_read(b, addr));
		flags = or_flags(a);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = flags;
		if ((flags & 0x40u) == 0)
			return;
	}
	snd = (uint8_t)(board_mem_read(b, 0x4EAC) & 0xBFu);
	board_mem_write(b, 0x4EAC, snd);
	Z80_HL(b->cpu) = 0x4EAC;
}

/* Park a ghost in the house and silence the eyes if the others are home. */
static void park_eyes(Board *b, uint16_t tile, uint16_t tile2, uint16_t sub,
		      uint16_t state, uint16_t fright, uint16_t home)
{
	Z80_HL(b->cpu) = home;
	write_hl(b, tile);
	write_hl(b, tile2);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	board_mem_write(b, sub, 0);
	board_mem_write(b, state, 0);
	board_mem_write(b, fright, 0);
	eyes_quiet(b);
}

/* Red eyes, state 2: walk down into the house. */
void j_10d2(Board *b)
{
	if (!axis_at(b, 0x3301, 0x4D00, 0x10DD, 0x4D00, 0x4D28, 0x4D2C, 0x01,
		     0x4D00, 0x80))
		return;
	park_eyes(b, 0x4D0A, 0x4D31, 0x4DA0, 0x4DAC, 0x4DA7, 0x2E2F);
}

/* Pink eyes, state 2: walk down into the house. */
void j_112a(Board *b)
{
	if (!axis_at(b, 0x3301, 0x4D02, 0x1135, 0x4D02, 0x4D29, 0x4D2D, 0x01,
		     0x4D02, 0x80))
		return;
	park_eyes(b, 0x4D0C, 0x4D33, 0x4DA1, 0x4DAD, 0x4DA8, 0x2E2F);
}

/* Blue eyes, state 2: walk down to the door. */
void j_116e(Board *b)
{
	if (!axis_at(b, 0x3301, 0x4D04, 0x1179, 0x4D04, 0x4D2A, 0x4D2E, 0x01,
		     0x4D04, 0x80))
		return;
	Z80_HL(b->cpu) = 0x4DAE;
	Z80_F(b->cpu) = inc_byte(b, 0x4DAE, Z80_F(b->cpu));
}

/* Blue eyes, state 3: walk left to the home slot. */
void j_118f(Board *b)
{
	if (!axis_at(b, 0x3303, 0x4D04, 0x119A, 0x4D04, 0x4D2A, 0x4D2E, 0x02,
		     0x4D05, 0x90))
		return;
	Z80_A(b->cpu) = 0x01;
	board_mem_write(b, 0x4D2A, 0x01);
	board_mem_write(b, 0x4D2E, 0x01);
	park_eyes(b, 0x4D0E, 0x4D35, 0x4DA2, 0x4DAE, 0x4DA9, 0x302F);
}

/* Orange eyes, state 2: walk down to the door. */
void j_11db(Board *b)
{
	if (!axis_at(b, 0x3301, 0x4D06, 0x11E6, 0x4D06, 0x4D2B, 0x4D2F, 0x01,
		     0x4D06, 0x80))
		return;
	Z80_HL(b->cpu) = 0x4DAF;
	Z80_F(b->cpu) = inc_byte(b, 0x4DAF, Z80_F(b->cpu));
}

/* Orange eyes, state 3: walk right to the home slot. */
void j_11fc(Board *b)
{
	if (!axis_at(b, 0x32FF, 0x4D06, 0x1207, 0x4D06, 0x4D2B, 0x4D2F, 0x00,
		     0x4D07, 0x70))
		return;
	Z80_A(b->cpu) = 0x01;
	board_mem_write(b, 0x4D2B, 0x01);
	board_mem_write(b, 0x4D2F, 0x01);
	park_eyes(b, 0x4D10, 0x4D37, 0x4DA3, 0x4DAF, 0x4DAA, 0x2C2F);
}

/* Clear a reverse flag, then run the reverse, when the flag is set. */
static void reverse_if(Board *b, uint16_t flag, void (*body)(Board *))
{
	uint8_t a = board_mem_read(b, flag);
	uint8_t flags = and_a_flags(a);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) != 0)
		return;
	board_mem_write(b, flag, 0);
	Z80_A(b->cpu) = 0;
	Z80_F(b->cpu) = 0x44;
	body(b);
}

static void reverse_red(Board *b)
{
	reverse_ghost(b, 0x4D28, 0x4D2C, 0x4D1E, 0x4D14, 0x1F14);
}

/* j_1efe  reverse red when its reverse flag is set
 * Entry:    ($4DB1) = red's reverse flag.
 * Exit:     If the flag is 0: A = 0, F is `and a`.
 *           Otherwise the flag is cleared and red is reversed, with the
 *           same exit as the pink/blue/orange reverses.
 *           Host finishes the RET.
 * Clobbers: A, F. B, DE, and HL change only when the flag is set.
 * Flags live-out: Z when the flag was already clear.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the two rst returns when a reverse runs. No callee.
 */
void j_1efe(Board *b)
{
	reverse_if(b, 0x4DB1, reverse_red);
}

/* j_1f25  reverse pink when its reverse flag is set
 * Entry:    ($4DB2) = pink's reverse flag.
 * Exit:     Same shape as j_1efe. The reverse itself is j_1f2e.
 *           Falling into j_1f2e is not a Z80 CALL.
 *           Host finishes the RET.
 * Clobbers: A, F. B, DE, and HL change only when the flag is set.
 * Flags live-out: Z when the flag was already clear.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the two rst returns inside j_1f2e when a reverse runs.
 */
void j_1f25(Board *b)
{
	reverse_if(b, 0x4DB2, j_1f2e);
}

/* j_1f4c  reverse blue when its reverse flag is set
 * Entry:    ($4DB3) = blue's reverse flag.
 * Exit:     Same shape as j_1efe. The reverse itself is j_1f55.
 *           Host finishes the RET.
 * Clobbers: A, F. B, DE, and HL change only when the flag is set.
 * Flags live-out: Z when the flag was already clear.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the two rst returns inside j_1f55 when a reverse runs.
 */
void j_1f4c(Board *b)
{
	reverse_if(b, 0x4DB3, j_1f55);
}

/* j_1f73  reverse orange when its reverse flag is set
 * Entry:    ($4DB4) = orange's reverse flag.
 * Exit:     Same shape as j_1efe. The reverse itself is j_1f7c.
 *           Host finishes the RET.
 * Clobbers: A, F. B, DE, and HL change only when the flag is set.
 * Flags live-out: Z when the flag was already clear.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: the two rst returns inside j_1f7c when a reverse runs.
 */
void j_1f73(Board *b)
{
	reverse_if(b, 0x4DB4, j_1f7c);
}

extern void j_1ed0(Board *b);
extern void j_2052(Board *b);
extern void j_2018(Board *b);
extern void j_0042(Board *b);

/* `rst $28`: B and C are the two data bytes. The RET lands after them. */
static void rst28(Board *b, uint8_t task, uint8_t param, uint16_t ret)
{
	Z80_B(b->cpu) = task;
	Z80_C(b->cpu) = param;
	call_lifted(b, ret, j_0042);
}

/* One ghost step. The four routines differ only in addresses and task ids. */
static void step_ghost(Board *b, uint8_t who, uint16_t dy, uint16_t dy2,
		       uint16_t y, uint16_t tile, uint16_t tile2,
		       uint16_t fright, uint16_t dir, uint16_t prev,
		       uint16_t ret_ed0, uint16_t ret_color, uint16_t ret_rev,
		       uint16_t ret_tile, uint16_t ret_pix, uint16_t ret_tilepos,
		       uint8_t task_blue, uint16_t ret_blue, uint8_t task_ai,
		       uint16_t ret_ai, void (*rev)(Board *))
{
	uint8_t delta = board_mem_read(b, dy);
	uint16_t axis = delta == 0 ? (uint16_t)(y + 1u) : y;
	uint8_t pos = board_mem_read(b, axis);
	uint16_t hl;

	if ((pos & 0x07u) == 0x04u) {
		uint8_t a;
		uint8_t flags;

		Z80_A(b->cpu) = who;
		call_lifted(b, ret_ed0, j_1ed0);
		if ((Z80_F(b->cpu) & 0x01u) == 0) {
			a = board_mem_read(b, fright);
			flags = and_a_flags(a);
			Z80_A(b->cpu) = a;
			Z80_F(b->cpu) = flags;
			if ((flags & 0x40u) == 0) {
				rst28(b, task_blue, 0, ret_blue);
			} else {
				Z80_HL(b->cpu) = read_word(b, tile);
				call_lifted(b, ret_color, j_2052);
				a = board_mem_read(b, Z80_HL(b->cpu));
				flags = cp_flags(a, 0x1A);
				Z80_A(b->cpu) = a;
				Z80_F(b->cpu) = flags;
				if ((flags & 0x40u) == 0)
					rst28(b, task_ai, 0, ret_ai);
			}
		}
		call_lifted(b, ret_rev, rev);
		Z80_IX(b->cpu) = dy2;
		Z80_IY(b->cpu) = tile;
		call_lifted(b, ret_tile, j_2000);
		write_hl(b, tile);
		hl = read_word(b, dy2);
		Z80_HL(b->cpu) = hl;
		write_hl(b, dy);
		a = board_mem_read(b, dir);
		board_mem_write(b, prev, a);
		Z80_A(b->cpu) = a;
	}
	Z80_IX(b->cpu) = dy;
	Z80_IY(b->cpu) = y;
	call_lifted(b, ret_pix, j_2000);
	write_hl(b, y);
	call_lifted(b, ret_tilepos, j_2018);
	write_hl(b, tile2);
}

/* j_1bd8  advance the red ghost one step
 * Entry:    Red's sprite, tile, and direction bytes.
 * Exit:     The sprite moves by the current tile delta. When the sprite
 *           is centered in a tile, the tunnel check, the frightened or
 *           chase task, and a reverse may run first, and the tile
 *           position advances. ($4D31) becomes the tile under the sprite.
 *           A, F, and HL are whatever j_2018 left. IX points at the
 *           sprite delta. IY points at the sprite.
 *           Host finishes the RET.
 * Clobbers: A, F, HL, IX, IY, and the registers those calls clobber
 * Flags live-out: none. The eyes check compares the new position next.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: each taken call leaves its return. The deepest is j_2052.
 */
void j_1bd8(Board *b)
{
	step_ghost(b, 1, 0x4D14, 0x4D1E, 0x4D00, 0x4D0A, 0x4D31, 0x4DA7,
		   0x4D2C, 0x4D28, 0x1BFC, 0x1C11, 0x1C1C, 0x1C27, 0x1C41,
		   0x1C47, 0x0C, 0x1C08, 0x08, 0x1C19, j_1efe);
}

/* j_1caf  advance the pink ghost one step */
void j_1caf(Board *b)
{
	step_ghost(b, 2, 0x4D16, 0x4D20, 0x4D02, 0x4D0C, 0x4D33, 0x4DA8,
		   0x4D2D, 0x4D29, 0x1CD3, 0x1CE8, 0x1CF3, 0x1CFE, 0x1D18,
		   0x1D1E, 0x0D, 0x1CDF, 0x09, 0x1CF0, j_1f25);
}

/* j_1d86  advance the blue ghost one step */
void j_1d86(Board *b)
{
	step_ghost(b, 3, 0x4D18, 0x4D22, 0x4D04, 0x4D0E, 0x4D35, 0x4DA9,
		   0x4D2E, 0x4D2A, 0x1DAA, 0x1DBF, 0x1DCA, 0x1DD5, 0x1DEF,
		   0x1DF5, 0x0E, 0x1DB6, 0x0A, 0x1DC7, j_1f4c);
}

/* j_1e5d  advance the orange ghost one step */
void j_1e5d(Board *b)
{
	step_ghost(b, 4, 0x4D1A, 0x4D24, 0x4D06, 0x4D10, 0x4D37, 0x4DAA,
		   0x4D2F, 0x4D2B, 0x1E81, 0x1E96, 0x1EA1, 0x1EAC, 0x1EC6,
		   0x1ECC, 0x0F, 0x1E8D, 0x0B, 0x1E9E, j_1f73);
}

extern void j_205a(Board *b);
extern void j_20d7(Board *b);

/* `adc hl, hl`. S, Z, H, P/V, and C all come from the sum. N is clear. */
static uint8_t adc_hl_hl(uint16_t hl, uint8_t carry, uint16_t *sum)
{
	uint32_t total = (uint32_t)hl + hl + (carry & 1u);
	uint16_t result = (uint16_t)total;
	uint16_t flipped = (uint16_t)~hl;
	uint16_t mix = (uint16_t)((hl ^ flipped) & (hl ^ result));
	uint8_t high = (uint8_t)(result >> 8);

	*sum = result;
	return (uint8_t)((high & 0xA8u) |
			 (result == 0 ? 0x40u : 0u) |
			 (high & 0x10u) |
			 (uint8_t)((mix >> 13) & 0x04u) |
			 (uint8_t)((total >> 16) & 1u));
}

/* Double the counter word, then the pattern, carrying between them.
 * Returns 1 when the pattern overflows and the ghost should step. */
static int shift_speed(Board *b, uint16_t counter, uint16_t pattern)
{
	uint16_t hl = read_word(b, counter);
	uint16_t sum;
	uint8_t flags = add_hl_flags(hl, hl, Z80_F(b->cpu), &sum);
	uint8_t low;

	write_word(b, counter, sum);
	hl = read_word(b, pattern);
	flags = adc_hl_hl(hl, flags, &sum);
	write_word(b, pattern, sum);
	Z80_HL(b->cpu) = sum;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x01u) == 0)
		return 0;
	Z80_HL(b->cpu) = counter;
	low = board_mem_read(b, counter);
	board_mem_write(b, counter, (uint8_t)(low + 1u));
	return 1;
}

static void use_speed(Board *b, uint16_t counter, uint16_t pattern,
		      void (*step)(Board *))
{
	if (shift_speed(b, counter, pattern))
		step(b);
}

/* AND the flag. A set flag consumes this call: either `ret nc` or a step. */
static int use_if_set(Board *b, uint16_t flag, uint16_t counter,
		      uint16_t pattern, void (*step)(Board *))
{
	uint8_t a = board_mem_read(b, flag);
	uint8_t flags = and_a_flags(a);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0)
		return 0;
	use_speed(b, counter, pattern, step);
	return 1;
}

static void pace_out(Board *b, uint16_t tile2, uint16_t slow, uint16_t ret,
		     uint16_t fright, uint16_t tun_c, uint16_t tun_p,
		     uint16_t blue_c, uint16_t blue_p, uint16_t nor_c,
		     uint16_t nor_p, void (*step)(Board *))
{
	Z80_HL(b->cpu) = read_word(b, tile2);
	Z80_BC(b->cpu) = slow;
	call_lifted(b, ret, j_205a);
	if (use_if_set(b, slow, tun_c, tun_p, step))
		return;
	if (use_if_set(b, fright, blue_c, blue_p, step))
		return;
	use_speed(b, nor_c, nor_p, step);
}

/* j_1b36  move the red ghost if it is out and alive
 * Entry:    Red substate ($4DA0) and state ($4DAC).
 * Exit:     Substate 0 or a nonzero state returns with `and a`.
 *           Otherwise the elroy check runs, then one speed pattern
 *           doubles. Carry clear returns with `adc hl, hl`. Carry
 *           set increments the pattern counter and steps the ghost.
 *           Tunnel, frightened, elroy 2, and elroy 1 are tested in
 *           that order. The first set flag wins.
 *           Host finishes the RET.
 * Clobbers: A, F, HL, and the calls' registers
 * Flags live-out: none. The caller goes on to the next ghost.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: j_20d7, then j_205a. A step adds that routine's calls.
 */
void j_1b36(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA0);
	uint8_t flags = and_a_flags(a);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a == 0)
		return;
	a = board_mem_read(b, 0x4DAC);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	call_lifted(b, 0x1B43, j_20d7);
	Z80_HL(b->cpu) = read_word(b, 0x4D31);
	Z80_BC(b->cpu) = 0x4D99;
	call_lifted(b, 0x1B4C, j_205a);
	if (use_if_set(b, 0x4D99, 0x4D60, 0x4D5E, j_1bd8))
		return;
	if (use_if_set(b, 0x4DA7, 0x4D5C, 0x4D5A, j_1bd8))
		return;
	if (use_if_set(b, 0x4DB7, 0x4D50, 0x4D4E, j_1bd8))
		return;
	if (use_if_set(b, 0x4DB6, 0x4D54, 0x4D52, j_1bd8))
		return;
	use_speed(b, 0x4D58, 0x4D56, j_1bd8);
}

/* j_1c4b  move the pink ghost when its substate is exactly 1 */
void j_1c4b(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA1);
	uint8_t flags = cp_flags(a, 0x01);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;
	a = board_mem_read(b, 0x4DAD);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	pace_out(b, 0x4D33, 0x4D9A, 0x1C5F, 0x4DA8, 0x4D6C, 0x4D6A, 0x4D68,
		 0x4D66, 0x4D64, 0x4D62, j_1caf);
}

/* j_1d22  move the blue ghost when its substate is exactly 1 */
void j_1d22(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA2);
	uint8_t flags = cp_flags(a, 0x01);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;
	a = board_mem_read(b, 0x4DAE);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	pace_out(b, 0x4D35, 0x4D9B, 0x1D36, 0x4DA9, 0x4D78, 0x4D76, 0x4D74,
		 0x4D72, 0x4D70, 0x4D6E, j_1d86);
}

/* j_1df9  move the orange ghost when its substate is exactly 1 */
void j_1df9(Board *b)
{
	uint8_t a = board_mem_read(b, 0x4DA3);
	uint8_t flags = cp_flags(a, 0x01);

	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;
	a = board_mem_read(b, 0x4DAF);
	flags = and_a_flags(a);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	if (a != 0)
		return;
	pace_out(b, 0x4D37, 0x4D9C, 0x1E0D, 0x4DAA, 0x4D84, 0x4D82, 0x4D80,
		 0x4D7E, 0x4D7C, 0x4D7A, j_1e5d);
}

/* `add a, n`. N is clear. Y and X come from the sum. */
static uint8_t add8(uint8_t a, uint8_t rhs, uint8_t *flags)
{
	uint16_t sum = (uint16_t)((uint16_t)a + rhs);
	uint8_t result = (uint8_t)sum;
	uint8_t inv = (uint8_t)~rhs;
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ inv) & (a ^ result)) & 0x80u) >> 5);

	*flags = (uint8_t)((sum > 255u ? 1u : 0u) |
			   ov |
			   ((a ^ rhs ^ result) & 0x10u) |
			   (result & 0xA8u) |
			   (result == 0 ? 0x40u : 0u));
	return result;
}

/* `adc a, n`. The carry-in is added. Overflow ignores that carry. */
static uint8_t adc8(uint8_t a, uint8_t rhs, uint8_t carry, uint8_t *flags)
{
	uint16_t sum = (uint16_t)((uint16_t)a + rhs + (carry & 1u));
	uint8_t result = (uint8_t)sum;
	uint8_t inv = (uint8_t)~rhs;
	uint8_t ov = (uint8_t)(((uint8_t)((a ^ inv) & (a ^ result)) & 0x80u) >> 5);

	*flags = (uint8_t)((sum > 255u ? 1u : 0u) |
			   ov |
			   ((a ^ rhs ^ result) & 0x10u) |
			   (result & 0xA8u) |
			   (result == 0 ? 0x40u : 0u));
	return result;
}

/* `rst $20`. A selects a word at `table`. SP ends where it started.
 * The popped rst $10 return ($0023) is the word just below SP. */
static uint16_t rst20(Board *b, uint16_t table)
{
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t flags = 0;
	uint8_t l = (uint8_t)table;
	uint8_t h = (uint8_t)(table >> 8);
	uint8_t a = add8(Z80_A(b->cpu), Z80_A(b->cpu), &flags);
	uint8_t byte;
	uint16_t hl;
	uint16_t de;

	push_word(b, &sp, table);
	sp = (uint16_t)(sp + 2u);
	push_word(b, &sp, 0x0023);
	a = add8(a, l, &flags);
	l = a;
	a = adc8(0, h, flags, &flags);
	h = a;
	hl = (uint16_t)(((uint16_t)h << 8) | l);
	byte = board_mem_read(b, hl);
	sp = (uint16_t)(sp + 2u);
	Z80_E(b->cpu) = byte;
	hl = (uint16_t)(hl + 1u);
	Z80_D(b->cpu) = board_mem_read(b, hl);
	de = Z80_DE(b->cpu);
	Z80_A(b->cpu) = byte;
	Z80_F(b->cpu) = flags;
	Z80_DE(b->cpu) = hl;
	Z80_HL(b->cpu) = de;
	Z80_SP(b->cpu) = sp;
	return de;
}

/* Dead eyes: step, and once they sit on $8064 advance the state. */
static void eyes_arrive(Board *b, void (*step)(Board *), uint16_t ret,
			uint16_t y, uint16_t state)
{
	uint16_t hl = 0;
	uint8_t flags;

	call_lifted(b, ret, step);
	hl = read_word(b, y);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = 0x8064;
	Z80_F(b->cpu) = and_a_flags(Z80_A(b->cpu));
	flags = sbc_hl(&hl, 0x8064);
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;
	Z80_HL(b->cpu) = state;
	Z80_F(b->cpu) = inc_byte(b, state, flags);
}

/* j_1094  red ghost: alive returns, dead walks, door enters the house
 * Entry:    A is overwritten with ($4DAC).
 * Exit:     State 0 is the bare RET at $000C. A is $0C and F is the
 *           `adc` inside `rst $20`. DE points at the table's high byte.
 *           State 1 steps the ghost and compares the sprite with $8064.
 *           State 2 is j_10d2.
 *           Host finishes the RET.
 * Clobbers: A, F, HL, DE
 * Flags live-out: none. The caller checks the next ghost.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: `rst $20` leaves $0023 under SP. A step or a door walk
 *         overwrites that word with its own call.
 */
void j_1094(Board *b)
{
	uint16_t target;

	Z80_A(b->cpu) = board_mem_read(b, 0x4DAC);
	target = rst20(b, 0x1098);
	if (target == 0x10C0)
		eyes_arrive(b, j_1bd8, 0x10C3, 0x4D00, 0x4DAC);
	else if (target == 0x10D2)
		j_10d2(b);
}

/* j_109e  pink ghost state */
void j_109e(Board *b)
{
	uint16_t target;

	Z80_A(b->cpu) = board_mem_read(b, 0x4DAD);
	target = rst20(b, 0x10A2);
	if (target == 0x1118)
		eyes_arrive(b, j_1caf, 0x111B, 0x4D02, 0x4DAD);
	else if (target == 0x112A)
		j_112a(b);
}

/* j_10a8  blue ghost state */
void j_10a8(Board *b)
{
	uint16_t target;

	Z80_A(b->cpu) = board_mem_read(b, 0x4DAE);
	target = rst20(b, 0x10AC);
	if (target == 0x115C)
		eyes_arrive(b, j_1d86, 0x115F, 0x4D04, 0x4DAE);
	else if (target == 0x116E)
		j_116e(b);
	else if (target == 0x118F)
		j_118f(b);
}

/* j_10b4  orange ghost state */
void j_10b4(Board *b)
{
	uint16_t target;

	Z80_A(b->cpu) = board_mem_read(b, 0x4DAF);
	target = rst20(b, 0x10B8);
	if (target == 0x11C9)
		eyes_arrive(b, j_1e5d, 0x11CC, 0x4D06, 0x4DAF);
	else if (target == 0x11DB)
		j_11db(b);
	else if (target == 0x11FC)
		j_11fc(b);
}

/* `rst $30`: copy the 3 bytes at `data` into the first free timed-task
 * slot. Returns 0 when all 16 slots are busy. */
static int rst30(Board *b, uint16_t data)
{
	uint16_t de = 0x4C90;
	uint16_t sp = Z80_SP(b->cpu);
	uint8_t left = 0x10;
	uint8_t i;
	uint8_t a = 0;

	Z80_DE(b->cpu) = de;
	Z80_B(b->cpu) = left;
	for (;;) {
		a = board_mem_read(b, de);
		Z80_A(b->cpu) = a;
		Z80_F(b->cpu) = and_a_flags(a);
		if (a == 0)
			break;
		for (i = 0; i < 3; i++)
			de = (uint16_t)((de & 0xFF00u) | (uint8_t)(de + 1u));
		left--;
		Z80_B(b->cpu) = left;
		Z80_DE(b->cpu) = de;
		if (left == 0)
			return 0;
	}
	push_word(b, &sp, data);
	sp = (uint16_t)(sp + 2u);
	{
		uint8_t flags = Z80_F(b->cpu);
		uint8_t e = (uint8_t)de;

		for (i = 0; i < 3; i++) {
			a = board_mem_read(b, data);
			board_mem_write(b, de, a);
			data = (uint16_t)(data + 1u);
			flags = inc_flags(e, flags, &e);
			de = (uint16_t)((de & 0xFF00u) | e);
		}
		Z80_F(b->cpu) = flags;
	}
	Z80_A(b->cpu) = a;
	Z80_B(b->cpu) = 0;
	Z80_DE(b->cpu) = de;
	Z80_HL(b->cpu) = data;
	Z80_SP(b->cpu) = sp;
	return 1;
}

/* j_1235  show the points sprite for an eaten ghost, or turn it to eyes
 * Entry:    ($4DD1) selects the case. 0 and 2 both enter the body.
 * Exit:     Case 1 is the bare RET at $000C.
 *           Anim 0 stores the points sprite, paints it color $18,
 *           hides Pac, and arms a timed task of $4A,$03,$00. A stays
 *           0. F is the `inc` of the animation byte. B is 0. DE is
 *           just past the task slot.
 *           Any other animation stores the eyes sprite, restores Pac's
 *           color, copies the pending kill into ($4DAB), and sets bit
 *           6 of the eyes sound. A is 0. F is `xor a`.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: none. The caller returns after this call.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: `rst $20` leaves $0023. The points path replaces it with the
 *         rst $30 data address ($126F).
 */
void j_1235(Board *b)
{
	uint16_t target;
	uint8_t pending;
	uint8_t anim;
	uint16_t hl;

	Z80_A(b->cpu) = board_mem_read(b, 0x4DD1);
	target = rst20(b, 0x1239);
	if (target != 0x123F)
		return;
	pending = board_mem_read(b, 0x4DA4);
	Z80_A(b->cpu) = (uint8_t)(pending << 1);
	Z80_D(b->cpu) = 0;
	Z80_E(b->cpu) = Z80_A(b->cpu);
	hl = (uint16_t)(0x4C00u + Z80_E(b->cpu));
	Z80_HL(b->cpu) = hl;
	anim = board_mem_read(b, 0x4DD1);
	Z80_A(b->cpu) = anim;
	Z80_F(b->cpu) = and_a_flags(anim);
	if (anim != 0) {
		uint8_t snd;

		board_mem_write(b, hl, 0x20);
		Z80_A(b->cpu) = 0x09;
		board_mem_write(b, 0x4C0B, 0x09);
		pending = board_mem_read(b, 0x4DA4);
		Z80_A(b->cpu) = pending;
		board_mem_write(b, 0x4DAB, pending);
		Z80_A(b->cpu) = 0;
		Z80_F(b->cpu) = 0x44;
		board_mem_write(b, 0x4DA4, 0);
		board_mem_write(b, 0x4DD1, 0);
		snd = (uint8_t)(board_mem_read(b, 0x4EAC) | 0x40u);
		board_mem_write(b, 0x4EAC, snd);
		Z80_HL(b->cpu) = 0x4EAC;
		return;
	}
	{
		uint8_t count = board_mem_read(b, 0x4DD0);
		uint8_t cocktail = board_mem_read(b, 0x4E72);
		uint8_t player = board_mem_read(b, 0x4E09);
		uint8_t sprite = (uint8_t)(count + 0x27u);

		Z80_C(b->cpu) = cocktail;
		if ((player & cocktail) != 0)
			sprite = (uint8_t)(sprite | 0xC0u);
		Z80_B(b->cpu) = sprite;
		board_mem_write(b, hl, sprite);
		hl = (uint16_t)(hl + 1u);
		Z80_HL(b->cpu) = hl;
		board_mem_write(b, hl, 0x18);
		Z80_A(b->cpu) = 0;
		board_mem_write(b, 0x4C0B, 0);
		if (!rst30(b, 0x126F))
			return;
		Z80_HL(b->cpu) = 0x4DD1;
		Z80_F(b->cpu) = inc_byte(b, 0x4DD1, 0);
	}
}

/* Hold the death pose until the counter reaches `limit`, then advance. */
static void death_frame(Board *b, uint8_t sprite, uint16_t limit)
{
	uint8_t cocktail = board_mem_read(b, 0x4E72);
	uint8_t player = board_mem_read(b, 0x4E09);
	uint8_t mixed = (uint8_t)(player & cocktail);
	uint8_t shown = sprite;
	uint16_t hl = read_word(b, 0x4DC5);
	uint8_t flags;

	Z80_C(b->cpu) = sprite;
	Z80_B(b->cpu) = cocktail;
	Z80_A(b->cpu) = mixed;
	Z80_F(b->cpu) = and_a_flags(mixed);
	if (mixed != 0) {
		shown = (uint8_t)(0xC0u | sprite);
		Z80_A(b->cpu) = shown;
		Z80_F(b->cpu) = or_flags(shown);
		Z80_C(b->cpu) = shown;
	}
	Z80_A(b->cpu) = shown;
	Z80_DE(b->cpu) = limit;
	board_mem_write(b, 0x4C0A, shown);
	hl = (uint16_t)(hl + 1u);
	write_word(b, 0x4DC5, hl);
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = and_a_flags(shown);
	flags = sbc_hl(&hl, limit);
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;
	Z80_HL(b->cpu) = 0x4DA5;
	Z80_F(b->cpu) = inc_byte(b, 0x4DA5, flags);
}

/* States 1..4: wait until the death counter reaches $78. */
static void death_wait(Board *b)
{
	uint16_t hl = read_word(b, 0x4DC5);
	uint8_t flags;

	hl = (uint16_t)(hl + 1u);
	write_word(b, 0x4DC5, hl);
	Z80_HL(b->cpu) = hl;
	Z80_DE(b->cpu) = 0x0078;
	Z80_F(b->cpu) = and_a_flags(Z80_A(b->cpu));
	flags = sbc_hl(&hl, 0x0078);
	Z80_HL(b->cpu) = hl;
	Z80_F(b->cpu) = flags;
	if ((flags & 0x40u) == 0)
		return;
	Z80_A(b->cpu) = 0x05;
	board_mem_write(b, 0x4DA5, 0x05);
}

/* j_1291  play Ms. Pac-Man's death, one animation state per call
 * Entry:    ($4DA5) selects the case. 0 means she is alive.
 * Exit:     Alive is the bare RET at $000C.
 *           States 1..4 count ($4DC5) up to $78, then store state 5.
 *           Later states show one dying sprite and advance ($4DA5)
 *           when the counter reaches that frame's limit. Player 2 in
 *           cocktail mode ORs $C0 into the sprite.
 *           The last state decrements both life counters, clears the
 *           actors, and increments ($4E04).
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL
 * Flags live-out: none. The caller returns while the animation runs.
 * Interrupt: returns inside the frame budget on every testplay1 call.
 * Stack: `rst $20` leaves $0023. The clear and the last state replace
 *         it with their calls ($12D1, $1371).
 */
void j_1291(Board *b)
{
	uint16_t target;
	uint8_t snd;

	Z80_A(b->cpu) = board_mem_read(b, 0x4DA5);
	target = rst20(b, 0x1295);
	if (target == 0x12B7) {
		death_wait(b);
	} else if (target == 0x12CB) {
		Z80_HL(b->cpu) = 0;
		call_lifted(b, 0x12D1, j_267e);
		death_frame(b, 0x34, 0x00B4);
	} else if (target == 0x12F9) {
		snd = (uint8_t)(board_mem_read(b, 0x4EBC) | 0x10u);
		board_mem_write(b, 0x4EBC, snd);
		death_frame(b, 0x35, 0x00C3);
	} else if (target == 0x1306) {
		death_frame(b, 0x36, 0x00D2);
	} else if (target == 0x130E) {
		death_frame(b, 0x37, 0x00E1);
	} else if (target == 0x1316) {
		death_frame(b, 0x38, 0x00F0);
	} else if (target == 0x131E) {
		death_frame(b, 0x39, 0x00FF);
	} else if (target == 0x1326) {
		death_frame(b, 0x3A, 0x010E);
	} else if (target == 0x132E) {
		death_frame(b, 0x3B, 0x011D);
	} else if (target == 0x1336) {
		death_frame(b, 0x3C, 0x012C);
	} else if (target == 0x133E) {
		death_frame(b, 0x3D, 0x013B);
	} else if (target == 0x1346) {
		board_mem_write(b, 0x4EBC, 0);
		death_frame(b, 0x3E, 0x0159);
	} else if (target == 0x1353) {
		uint16_t hl = read_word(b, 0x4DC5);
		uint8_t flags;
		uint8_t next = 0;

		Z80_A(b->cpu) = 0x3F;
		board_mem_write(b, 0x4C0A, 0x3F);
		hl = (uint16_t)(hl + 1u);
		write_word(b, 0x4DC5, hl);
		Z80_HL(b->cpu) = hl;
		Z80_DE(b->cpu) = 0x01B8;
		Z80_F(b->cpu) = and_a_flags(0x3F);
		flags = sbc_hl(&hl, 0x01B8);
		Z80_HL(b->cpu) = hl;
		Z80_F(b->cpu) = flags;
		if ((flags & 0x40u) == 0)
			return;
		flags = dec_flags(board_mem_read(b, 0x4E14), flags, &next);
		board_mem_write(b, 0x4E14, next);
		flags = dec_flags(board_mem_read(b, 0x4E15), flags, &next);
		board_mem_write(b, 0x4E15, next);
		Z80_HL(b->cpu) = 0x4E15;
		Z80_F(b->cpu) = flags;
		call_lifted(b, 0x1371, j_2675);
		Z80_HL(b->cpu) = 0x4E04;
		Z80_F(b->cpu) = inc_byte(b, 0x4E04, Z80_F(b->cpu));
	}
}

extern void j_94bd(Board *b);

/* j_9561 body. A on entry is the ghost direction the caller will want back.
 * DE becomes the quadrant word at this maze's table plus the draw masked
 * with $06. pop af puts the entry A and F back, so the draw's flags die. */
static void pick_quadrant(Board *b)
{
	uint8_t a = Z80_A(b->cpu);
	uint8_t flags = Z80_F(b->cpu);
	uint16_t bc = Z80_BC(b->cpu);
	uint16_t hl = Z80_HL(b->cpu);
	uint16_t entry = Z80_SP(b->cpu);
	uint16_t sp = entry;
	uint16_t ptr;
	uint8_t draw;
	uint8_t lo;

	push_word(b, &sp, (uint16_t)(((uint16_t)a << 8) | flags));
	push_word(b, &sp, bc);
	push_word(b, &sp, hl);
	Z80_SP(b->cpu) = sp;
	Z80_HL(b->cpu) = 0x9578;
	call_lifted(b, 0x956A, j_94bd);

	ptr = Z80_BC(b->cpu);
	draw = (uint8_t)(lift_random_byte(b) & 0x06u);
	sp = Z80_SP(b->cpu);
	push_word(b, &sp, 0x9571);
	ptr = (uint16_t)(ptr + draw);
	lo = board_mem_read(b, ptr);
	ptr = (uint16_t)(ptr + 1u);
	Z80_DE(b->cpu) = (uint16_t)(((uint16_t)board_mem_read(b, ptr) << 8) | lo);
	Z80_A(b->cpu) = a;
	Z80_F(b->cpu) = flags;
	Z80_BC(b->cpu) = bc;
	Z80_HL(b->cpu) = hl;
	Z80_SP(b->cpu) = entry;
}

/* j_9561  pick a maze quadrant for a ghost target
 * Entry:    A holds the ghost's current direction. HL is its tile.
 * Exit:     DE is one of the four quadrant words for this maze.
 *           The index is the next generator byte masked with $06.
 *           A, F, BC, and HL are the entry values. pop af restored them.
 *           The stack bytes below SP are the saved AF, BC, and HL, then
 *           the rst $10 return $9571, the table base $9578, and the
 *           inner rst return $94CA.
 *           Host finishes the RET.
 * Clobbers: DE
 * Flags live-out: the flags the caller pushed. Callers overwrite DE
 *           for blue and orange, and pass it to j_2966 for red and pink.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: the call to j_94bd and the rst, both returned. j_94bd is C.
 */
void j_9561(Board *b)
{
	pick_quadrant(b);
}

/* j_9559  blue ghost's random-move entry
 * Entry:    ($4D2E) = blue direction. F is unchanged by the load.
 * Exit:     same as j_9561, with A equal to that direction byte.
 *           Host finishes the RET.
 * Clobbers: A, DE
 * Flags live-out: the flags on entry.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: falls into j_9561. One call, returned.
 */
void j_9559(Board *b)
{
	Z80_A(b->cpu) = board_mem_read(b, 0x4D2E);
	pick_quadrant(b);
}

/* j_955e  orange ghost's random-move entry
 * Entry:    ($4D2F) = orange direction. F is unchanged by the load.
 * Exit:     same as j_9561, with A equal to that direction byte.
 *           Host finishes the RET.
 * Clobbers: A, DE
 * Flags live-out: the flags on entry.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: falls into j_9561. One call, returned.
 */
void j_955e(Board *b)
{
	Z80_A(b->cpu) = board_mem_read(b, 0x4D2F);
	pick_quadrant(b);
}

/* Bit 0 of the orientation index clear, and the level state is play. */
static int orient_random(Board *b)
{
	uint8_t orient = board_mem_read(b, 0x4DC1);

	if ((orient & 0x01u) != 0)
		return 0;
	return board_mem_read(b, 0x4E04) == 0x03;
}

/* j_2966 has chosen. Store its HL delta and its A direction. */
static void store_heading(Board *b, uint16_t dy2, uint16_t dir)
{
	write_hl(b, dy2);
	board_mem_write(b, dir, Z80_A(b->cpu));
}

static void aim_tile(Board *b, uint16_t tile, uint16_t dir, uint16_t target,
		     uint16_t ret, uint16_t dy2)
{
	Z80_HL(b->cpu) = read_word(b, tile);
	Z80_DE(b->cpu) = target;
	Z80_A(b->cpu) = board_mem_read(b, dir);
	call_lifted(b, ret, j_2966);
	store_heading(b, dy2, dir);
}

/* j_2730  red ghost chase or scatter
 * Entry:    rst $20 task 8. The return on the stack is the task loop.
 *           ($4DC1) bit 0 clear means scatter. ($4DB6) = Cruise Elroy.
 *           ($4E04) = level state. ($4D0A) = red tile. ($4D2C) = direction.
 * Exit:     ($4D1E) = the tile step. ($4D2C) = the new direction.
 *           A and HL are that direction and step. The other registers
 *           are whatever j_2966 left. Scatter aims at a random quadrant.
 *           Chase aims at Ms. Pac-Man's tile. Elroy and a set orientation
 *           bit take the chase path.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The task loop discards them.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: the quadrant call, then j_2966, both returned.
 */
void j_2730(Board *b)
{
	if (orient_random(b) && board_mem_read(b, 0x4DB6) == 0) {
		Z80_HL(b->cpu) = read_word(b, 0x4D0A);
		Z80_A(b->cpu) = board_mem_read(b, 0x4D2C);
		call_lifted(b, 0x274E, j_9561);
		call_lifted(b, 0x2751, j_2966);
		store_heading(b, 0x4D1E, 0x4D2C);
		return;
	}
	aim_tile(b, 0x4D0A, 0x4D2C, read_word(b, 0x4D39), 0x2765, 0x4D1E);
}

/* j_276c  pink ghost chase or scatter
 * Entry:    rst $20 task 9. ($4D0C) = pink tile. ($4D2D) = direction.
 * Exit:     ($4D20) = the tile step. ($4D2D) = the new direction.
 *           Scatter aims at a random quadrant. Chase aims four tiles
 *           ahead of Ms. Pac-Man, along ($4D1C).
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The task loop discards them.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: the quadrant call, then j_2966, both returned.
 */
void j_276c(Board *b)
{
	if (orient_random(b)) {
		Z80_HL(b->cpu) = read_word(b, 0x4D0C);
		Z80_A(b->cpu) = board_mem_read(b, 0x4D2D);
		call_lifted(b, 0x2784, j_9561);
		call_lifted(b, 0x2787, j_2966);
		store_heading(b, 0x4D20, 0x4D2D);
		return;
	}
	{
		uint16_t ahead = read_word(b, 0x4D1C);

		ahead = (uint16_t)(ahead + ahead);
		ahead = (uint16_t)(ahead + ahead);
		ahead = (uint16_t)(ahead + read_word(b, 0x4D39));
		aim_tile(b, 0x4D0C, 0x4D2D, ahead, 0x27A2, 0x4D20);
	}
}

/* Two tiles ahead of Ms. Pac-Man, reflected through the red ghost. */
static uint16_t inky_target(Board *b)
{
	uint16_t red = read_word(b, 0x4D0A);
	uint16_t ahead = read_word(b, 0x4D1C);
	uint8_t y;
	uint8_t x;

	ahead = (uint16_t)(ahead + ahead);
	ahead = (uint16_t)(ahead + read_word(b, 0x4D39));
	y = (uint8_t)ahead;
	y = (uint8_t)(y + y);
	y = (uint8_t)(y - (uint8_t)red);
	x = (uint8_t)(ahead >> 8);
	x = (uint8_t)(x + x);
	x = (uint8_t)(x - (uint8_t)(red >> 8));
	return (uint16_t)(((uint16_t)x << 8) | y);
}

/* j_27a9  blue ghost chase or scatter
 * Entry:    rst $20 task 10. ($4D0E) = blue tile. ($4D2E) = direction.
 * Exit:     ($4D22) = the tile step. ($4D2E) = the new direction.
 *           Scatter still draws a quadrant, then aims at tile $2040.
 *           Chase aims at the reflected target.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The task loop discards them.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: the quadrant call, then j_2966, both returned.
 */
void j_27a9(Board *b)
{
	if (orient_random(b)) {
		Z80_HL(b->cpu) = read_word(b, 0x4D0E);
		call_lifted(b, 0x27BE, j_9559);
		Z80_DE(b->cpu) = 0x2040;
		call_lifted(b, 0x27C4, j_2966);
		store_heading(b, 0x4D22, 0x4D2E);
		return;
	}
	aim_tile(b, 0x4D0E, 0x4D2E, inky_target(b), 0x27EA, 0x4D22);
}

/* Corner aim used when orange is scattering or too close to Ms. Pac-Man. */
static void orange_corner(Board *b)
{
	Z80_HL(b->cpu) = read_word(b, 0x4D10);
	call_lifted(b, 0x2806, j_955e);
	Z80_DE(b->cpu) = 0x3B40;
	call_lifted(b, 0x280C, j_2966);
	store_heading(b, 0x4D24, 0x4D2F);
}

/* j_27f1  orange ghost chase or scatter
 * Entry:    rst $20 task 11. ($4D10) = orange tile. ($4D2F) = direction.
 * Exit:     ($4D24) = the tile step. ($4D2F) = the new direction.
 *           Scatter, and a chase that is within 8 tiles, aim at $3B40
 *           after drawing a quadrant. Otherwise the aim is Ms. Pac-Man.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The task loop discards them.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: the distance call or the quadrant call, then j_2966.
 */
void j_27f1(Board *b)
{
	uint16_t dist;
	uint8_t flags;

	if (orient_random(b)) {
		orange_corner(b);
		return;
	}
	Z80_IX(b->cpu) = 0x4D39;
	Z80_IY(b->cpu) = 0x4D10;
	call_lifted(b, 0x281E, j_29ea);
	dist = Z80_HL(b->cpu);
	flags = sbc_hl(&dist, 0x0040);
	if ((flags & 0x01u) != 0) {
		orange_corner(b);
		return;
	}
	aim_tile(b, 0x4D10, 0x4D2F, read_word(b, 0x4D39), 0x2834, 0x4D24);
}

/* Twice Ms. Pac-Man's tile, reflected through the pink ghost. */
static uint16_t flee_pink(Board *b)
{
	uint16_t pac = read_word(b, 0x4D39);
	uint16_t pink = read_word(b, 0x4D0C);
	uint8_t y = (uint8_t)pac;
	uint8_t x = (uint8_t)(pac >> 8);

	y = (uint8_t)(y + y);
	y = (uint8_t)(y - (uint8_t)pink);
	x = (uint8_t)(x + x);
	x = (uint8_t)(x - (uint8_t)(pink >> 8));
	return (uint16_t)(((uint16_t)x << 8) | y);
}

/* j_28e3  demo steering for Ms. Pac-Man
 * Entry:    rst $20 task $17. The return on the stack is the task loop.
 *           ($4DA7) = red fright flag. Zero means run away from pink.
 *           ($4D12) = demo tile. ($4D3C) = wanted direction.
 *           ($4D0C) = pink tile. ($4D39) = Ms. Pac-Man's tile.
 * Exit:     ($4D26) = the tile step. ($4D3C) = the new direction.
 *           A and HL are that direction and step. The other registers
 *           are whatever j_2966 left. A frightened red ghost chases pink.
 *           Otherwise the aim is the reflected tile.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The task loop discards them.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: one call to j_2966, returned.
 */
void j_28e3(Board *b)
{
	uint16_t target;

	if (board_mem_read(b, 0x4DA7) == 0)
		target = flee_pink(b);
	else
		target = read_word(b, 0x4D0C);
	aim_tile(b, 0x4D12, 0x4D3C, target,
		 board_mem_read(b, 0x4DA7) == 0 ? 0x2917 : 0x28F7, 0x4D26);
}

/* Eyes go to the tile above the house. A live frightened ghost wanders. */
static void fright(Board *b, uint16_t state, uint16_t tile, uint16_t dir,
		   uint16_t dy2, uint16_t home_ret, uint16_t wander_ret)
{
	uint8_t a = board_mem_read(b, state);

	if (a == 0) {
		Z80_HL(b->cpu) = read_word(b, tile);
		Z80_A(b->cpu) = board_mem_read(b, dir);
		call_lifted(b, wander_ret, j_291e);
		store_heading(b, dy2, dir);
		return;
	}
	aim_tile(b, tile, dir, 0x2E2C, home_ret, dy2);
}

/* j_283b  red ghost while a power pill is active
 * Entry:    rst $20 task 12. ($4DAC) = red state, 0 while it is alive.
 * Exit:     ($4D1E) = the tile step. ($4D2C) = the new direction.
 *           Eyes aim at tile $2E2C. A live ghost picks an open direction.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The task loop discards them.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: one call, returned.
 */
void j_283b(Board *b)
{
	fright(b, 0x4DAC, 0x4D0A, 0x4D2C, 0x4D1E, 0x284E, 0x285E);
}

/* j_2865  pink ghost while a power pill is active
 * Entry:    rst $20 task 13. ($4DAD) = pink state.
 * Exit:     ($4D20) = the tile step. ($4D2D) = the new direction.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The task loop discards them.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: one call, returned.
 */
void j_2865(Board *b)
{
	fright(b, 0x4DAD, 0x4D0C, 0x4D2D, 0x4D20, 0x2878, 0x2888);
}

/* j_288f  blue ghost while a power pill is active
 * Entry:    rst $20 task 14. ($4DAE) = blue state.
 * Exit:     ($4D22) = the tile step. ($4D2E) = the new direction.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The task loop discards them.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: one call, returned.
 */
void j_288f(Board *b)
{
	fright(b, 0x4DAE, 0x4D0E, 0x4D2E, 0x4D22, 0x28A2, 0x28B2);
}

/* j_28b9  orange ghost while a power pill is active
 * Entry:    rst $20 task 15. ($4DAF) = orange state.
 * Exit:     ($4D24) = the tile step. ($4D2F) = the new direction.
 *           Host finishes the RET.
 * Clobbers: A, F, BC, DE, HL, IX, IY
 * Flags live-out: none. The task loop discards them.
 * Interrupt: returns inside the frame budget on every testplay2 call.
 * Stack: one call, returned.
 */
void j_28b9(Board *b)
{
	fright(b, 0x4DAF, 0x4D10, 0x4D2F, 0x4D24, 0x28CC, 0x28DC);
}
