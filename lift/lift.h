/* Shared state for the phase-1 mspacmab host. */
#ifndef LIFT_H
#define LIFT_H

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

#include "Z80.h"

#define LIFT_CYCLES_PER_FRAME 50688
#define LIFT_WATCHDOG_FRAMES  16
#define LIFT_FB_W             288
#define LIFT_FB_H             224
#define LIFT_SCREEN_W         224
#define LIFT_SCREEN_H         288
#define LIFT_RING             256
#define LIFT_MAX_READS        256
#define LIFT_MAX_LIFTS        64
#define LIFT_DSW1_DEFAULT     0xC9

enum {
	LIFT_STOP_BUDGET = 0,
	LIFT_STOP_IDLE = 1
};

typedef struct {
	uint64_t h[5];
	uint8_t stop;
	uint16_t nreads;
	uint8_t reads[LIFT_MAX_READS];
} LiftFrame;

/* Full images of the hashed regions, for the last LIFT_RING frames. */
typedef struct {
	uint8_t work[0x1F0];
	uint8_t video[0x400];
	uint8_t color[0x400];
	uint8_t spr[0x10];
	uint8_t spr2[16];
} LiftSnap;

typedef struct {
	int have_gfx;
	int have_prom;
	uint8_t tile[256][8][8];
	uint8_t sprite[64][16][16];
	uint8_t rgb[32][3];
	uint8_t lookup[256];
} LiftGfx;

typedef struct {
	uint8_t reg[32];
	uint32_t counter[3];
	uint8_t prom[256];
	int have_prom;
} LiftAudio;

typedef struct {
	uint8_t clear_in0;
	uint8_t clear_in1;
	int quit;
	int toggle_record;
} LiftInput;

typedef struct {
	int recording;
	int replaying;
	char dir[512];
	LiftFrame *play;
	uint32_t play_count;
	uint32_t play_pos;
	uint16_t read_pos;
	FILE *inputs;
	FILE *hashes;
	uint8_t dsw1;
	uint8_t reset_ram[0x1000];
	LiftFrame ring[LIFT_RING];
	LiftSnap snap[LIFT_RING];
	uint32_t ring_i;
	uint32_t ring_n;
} LiftCorpus;

typedef struct Board {
	Z80 cpu;
	uint8_t mem[65536];
	uint8_t rom[65536];
	uint8_t spr2[16];
	uint8_t latch[8];
	uint32_t frames_since_kick;
	int irq_seen;
	int stop;
	zusize cycles_left;
	uint16_t lift_pc[LIFT_MAX_LIFTS];
	int lift_count;
	int lift_hit;
	LiftFrame cur;
	LiftGfx gfx;
	LiftAudio audio;
	LiftInput input;
	LiftCorpus corpus;
	uint32_t frame_index;
	int mismatch;
} Board;

void board_init(Board *b);
void board_load_cpu(Board *b, const char *path);
void board_reset(Board *b);
void board_frame(Board *b);
void board_lift_add(Board *b, uint16_t pc);

void video_load(Board *b, const char *tile_path, const char *sprite_path,
		const char *color_path, const char *pal_path);
void video_render(Board *b, uint8_t *rgb, int pitch);

void audio_load(Board *b, const char *prom_path);
void audio_render(Board *b, float *out, int nsamples);

void input_poll(Board *b);

int corpus_open_record(Board *b, const char *dir);
int corpus_open_replay(Board *b, const char *dir);
void corpus_note_frame(Board *b);
void corpus_close(Board *b);

#endif
