/* $008D  the vertical-blank interrupt
 *
 * Sends last frame's sound and sprite buffers to the hardware, then runs
 * the per-frame work: clocks and timers, the game mode, sprites, coins,
 * lamps, and the sound engine.
 */
#include "game.h"

#include <string.h>

#define IRQ_ENABLE    0x5000u /* latch: interrupts on */
#define VOICE_REGS    0x5040u /* 32 sound registers */
#define VOICE1_SELECT 0x5045u
#define VOICE2_SELECT 0x504Au
#define VOICE3_SELECT 0x504Fu
#define VOICE_FREQS   0x5050u /* frequency and volume nibbles */
#define SPRITE_RAM    0x4FF0u /* 8 code/color pairs */
#define SPRITE_XY     0x5060u /* 8 x/y pairs */
#define WATCHDOG      0x50C0u
#define IN1           0x5040u
#define IN1_SERVICE   0x10u   /* active low */

static void copy_out(Board *b, uint16_t dest, const void *src, unsigned n)
{
	const uint8_t *p = src;
	unsigned i;

	for (i = 0; i < n; i++)
		board_mem_write(b, (uint16_t)(dest + i), p[i]);
}

/* A playing song supplies the voice's wave select. Otherwise the effect does. */
static uint8_t wave_select(const SoundChannel *wave, const SoundChannel *effect)
{
	return wave->num != 0 ? wave->w.select : effect->e.shape;
}

/* The game keeps the flips in bits 7-6. The hardware wants them in 1-0. */
static uint8_t rotate_flips(uint8_t code)
{
	return (uint8_t)((uint8_t)(code << 2) | (code >> 6));
}

static void swap_slots(WorkRam *ram, unsigned a, unsigned b)
{
	SpriteCode code = ram->sprite_out[a];
	SpritePos pos = ram->sprite_pos_out[a];

	ram->sprite_out[a] = ram->sprite_out[b];
	ram->sprite_pos_out[a] = ram->sprite_pos_out[b];
	ram->sprite_out[b] = code;
	ram->sprite_pos_out[b] = pos;
}

static void send_sprites(Board *b, WorkRam *ram)
{
	unsigned i;

	memcpy(&ram->sprite_out[1], &ram->sprite[1], 7 * sizeof(SpriteCode));
	memcpy(&ram->sprite_pos_out[0], &ram->sprite_pos[0], 7 * sizeof(SpritePos));
	for (i = SPR_RED; i <= SPR_FRUIT; i++)
		ram->sprite_out[i].code = rotate_flips(ram->sprite_out[i].code);
	/* The eaten ghost trades places with slot 2. While a power pill
	 * runs, Ms. Pac trades places with slot 1. */
	if (ram->killed_ghost_anim == 1)
		swap_slots(ram, 2, ram->ghosts_killed_pending);
	if (ram->power_pill_active != 0)
		swap_slots(ram, SPR_RED, SPR_PAC);
	copy_out(b, (uint16_t)(SPRITE_RAM + 2u), &ram->sprite_out[1], 12);
	copy_out(b, (uint16_t)(SPRITE_XY + 2u), &ram->sprite_pos_out[1], 12);
}

void vblank(Board *b)
{
	LOWER_HOOK(vblank, b);
	WorkRam *ram = work_ram(b->mem);

	board_mem_write(b, WATCHDOG, 0);
	board_mem_write(b, IRQ_ENABLE, 0);
	b->int_enabled = 0;

	copy_out(b, VOICE_FREQS, &ram->CH1_FREQ0, 16);
	board_mem_write(b, VOICE1_SELECT, wave_select(&ram->wave[0], &ram->effect[0]));
	board_mem_write(b, VOICE2_SELECT, wave_select(&ram->wave[1], &ram->effect[1]));
	board_mem_write(b, VOICE3_SELECT, wave_select(&ram->wave[2], &ram->effect[2]));
	send_sprites(b, ram);

	clock_tick(b);
	timers_run(b);
	game_mode_step(b);
	if (ram->game_mode != MODE_POWER_ON) {
		cutscene1_positions(b);
		sprites_upright(b);
		sprites_cocktail(b);
		coin_inputs(b);
		coin_meter(b);
		hud_blink(b);
	}
	/* The attract mode mutes effect channels 2 and 3. */
	if (ram->game_mode == MODE_ATTRACT) {
		ram->effect[1].num = 0;
		ram->effect[2].num = 0;
	}
	sound_effects(b);
	sound_songs(b);

	/* The service switch restarts the game. Unverified; no session
	 * presses it. */
	if (ram->game_mode != MODE_POWER_ON && (board_mem_read(b, IN1) & IN1_SERVICE) == 0) {
		b->restart = 1;
		return;
	}
	board_mem_write(b, IRQ_ENABLE, 1);
	b->int_enabled = 1;
}
