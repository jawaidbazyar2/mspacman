/* The board state shared by the game and the host: memory, latches,
 * inputs, audio, video, and the corpus recorder. */
#ifndef LIFT_H
#define LIFT_H

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

#include "ram.h"

/* Stored in the corpus header. */
#define LIFT_CYCLES_PER_FRAME 50688
#define LIFT_WATCHDOG_FRAMES  16
#define LIFT_FB_W             288
#define LIFT_FB_H             224
#define LIFT_SCREEN_W         224
#define LIFT_SCREEN_H         288
#define LIFT_MAX_READS        256
#define LIFT_DSW1_DEFAULT     0xC9
#define LIFT_FRAME_VER        3
#define LIFT_FRAME_HDR        24
#define LIFT_FRAME_BYTES      3176
/* Version 2 records stop work RAM at $4DEF. */
#define LIFT_FRAME_BYTES_V2   2664
/* Session seed. A draw is one step of state = state * MUL + ADD. */
#define LIFT_RAND_SEED        1u
#define LIFT_RAND_MUL         1664525u
#define LIFT_RAND_ADD         1013904223u

enum {
	LIFT_STOP_BUDGET = 0,
	LIFT_STOP_IDLE = 1
};

typedef struct {
	uint8_t stop;
	uint16_t nreads;
	uint8_t reads[LIFT_MAX_READS];
} LiftFrame;

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
	uint32_t play_count;
	uint16_t read_pos;
	uint16_t replay_nreads;
	uint8_t replay_reads[LIFT_MAX_READS];
	FILE *inputs;
	FILE *frames;
	FILE *out_frames;
	FILE *out_inputs;
	uint32_t file_ver;
	uint8_t dsw1;
	uint8_t reset_ram[0x1000];
	uint8_t packed[LIFT_FRAME_BYTES];
	char mismatch_msg[160];
	/* Replay: the record it started from and the record this frame is
	 * checked against. */
	uint32_t start_frame;
	uint8_t want[LIFT_FRAME_BYTES];
} LiftCorpus;

typedef struct Board {
	/* The Z80's interrupt enable: vblank runs only while it is set. */
	uint8_t int_enabled;
	uint8_t mem[65536];
	uint8_t rom[65536];
	uint8_t spr2[16];
	uint8_t latch[8];
	uint32_t frames_since_kick;
	int stop;
	/* Set once $234B has finished. Replay sets it from the idle snapshot. */
	int started;
	/* vblank saw the service switch and did not return to the task list. */
	int restart;
	LiftFrame cur;
	LiftGfx gfx;
	LiftAudio audio;
	LiftInput input;
	LiftCorpus corpus;
	uint32_t frame_index;
	int mismatch;
	uint32_t rand_seed;
	uint32_t rand_state;
} Board;

void board_init(Board *b);
void board_load_rom(Board *b, const char *path);
void board_reset(Board *b);
void board_frame(Board *b);
uint8_t board_mem_read(Board *b, uint16_t addr);
void board_mem_write(Board *b, uint16_t addr, uint8_t data);
/* Next draw. One step per `ld a,r` at $8768, $87D2, or $956C. */
uint8_t lift_random_byte(Board *b);

void video_load(Board *b, const char *tile_path, const char *sprite_path,
		const char *color_path, const char *pal_path);
void video_render(Board *b, uint8_t *rgb, int pitch);

void audio_load(Board *b, const char *prom_path);
void audio_render(Board *b, float *out, int nsamples);

void input_poll(Board *b);

int corpus_open_record(Board *b, const char *dir);
int corpus_open_rewrite(Board *b, const char *dir);
int corpus_open_replay(Board *b, const char *dir);
int corpus_begin_frame(Board *b);
void corpus_note_frame(Board *b);
void corpus_close(Board *b);
/* -1 when the records match. Otherwise the first differing offset, with a field name in msg. */
int corpus_diff_at(const uint8_t *expect, const uint8_t *got, char *msg, size_t cap);

#endif
