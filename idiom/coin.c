/* Coins and credits. Run from the vertical blank outside the power-on
 * mode. */
#include "game.h"

#define IN0              0x5000u
#define IN0_COIN1        0x20u
#define IN0_COIN2        0x40u
#define IN0_SERVICE      0x80u
#define COIN_LOCKOUT     0x5006u /* latch: 1 accepts coins */
#define COIN_COUNTER     0x5007u /* latch: pulses the coin meter */
#define SOUND_CREDIT     0x02u   /* effect channel 1 bit */

/* $02DF  count one coin. Enough coins add credits, capped at 99.
 * Coinage other than 1 coin, 1 credit is out of scope for the port. The
 * cap needs 2 or more credits per coin: at 1 per coin, coin_inputs locks
 * the slots at 99, so the add never carries. */
static void add_coin(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	bool carry;
	uint8_t credits;

	if (++ram->coins_inserted != ram->dip_coins_per_credit)
		return;
	ram->coins_inserted = 0;
	credits = bcd_add(ram->dip_credits_per_coin, ram->credits, false, &carry);
	ram->credits = carry ? 0x99 : credits;
	ram->effect[0].num |= SOUND_CREDIT;
}

/* $02AD  pulse the coin meter once per counted coin. Each pulse is 8
 * frames on and 8 off; the coin is counted at the start of the pulse. */
void coin_meter(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	uint8_t t;

	if (ram->coin_counter == 0)
		return;
	t = ram->coin_counter_timeout;
	if (t == 0) {
		board_mem_write(b, COIN_COUNTER, 1);
		add_coin(b);
	}
	if (t == 8)
		board_mem_write(b, COIN_COUNTER, 0);
	ram->coin_counter_timeout = ++t;
	if (t == 0x10) {
		ram->coin_counter_timeout = 0;
		ram->coin_counter--;
	}
}

/* Shift one switch sample into a 4-frame history. A press is up, up,
 * down, down: the active-low pattern 1100. */
static bool pressed(uint8_t *hist, bool up)
{
	*hist = (uint8_t)(((uint8_t)(*hist << 1) | (up ? 1u : 0u)) & 0x0Fu);
	return *hist == 0x0C;
}

/* $0267  read the coin and service switches. Coins wait in coin_counter
 * for coin_meter. The service switch credits a coin at once. Free play
 * ($FF credits) locks the slots out. Unverified: the corpus never
 * presses service or uses coin slot 2. */
void coin_inputs(Board *b)
{
	WorkRam *ram = work_ram(b->mem);
	bool accept = ram->credits < 0x99;
	uint8_t in0;

	board_mem_write(b, COIN_LOCKOUT, accept ? 1 : 0);
	if (!accept)
		return;
	in0 = board_mem_read(b, IN0);
	if (pressed(&ram->in_service_hist, in0 & IN0_SERVICE))
		add_coin(b);
	if (pressed(&ram->in_coin2_hist, in0 & IN0_COIN2))
		ram->coin_counter++;
	if (pressed(&ram->in_coin1_hist, in0 & IN0_COIN1))
		ram->coin_counter++;
}
