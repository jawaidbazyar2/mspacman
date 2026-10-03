/* Host side: command line, the SDL window and audio, and the frame
 * loop for play, record, replay, and check. */
#include "lift.h"
#include "dispatch.h"

#include <SDL3/SDL.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define LIFT_AUDIO_HZ 48000
#define LIFT_SAMPLES_PER_FRAME 792
#define LIFT_FRAME_NS 16500000ull

static const char *k_rom = "build/mspac.bin";
static const char *k_tiles = "mspacman/5e";
static const char *k_sprites = "mspacman/5f";
static const char *k_color = "mspacman/82s123.7f";
static const char *k_palette = "mspacman/82s126.4a";
static const char *k_wave = "mspacman/82s126.1m";

static void usage(void)
{
	fprintf(stderr,
		"usage: mspac-idiom [--rom PATH] [--free-play] [--record DIR | --replay DIR [--video] | --check N]\n"
		"  --free-play  set the coinage DIP switches to free play (replay uses the session's switches)\n"
		"  keypad 8/4/6/2 move, 0 coin, Enter 1P start, + 2P start, . rack test, F9 record, Esc quit\n");
}

static void load_assets(Board *b)
{
	video_load(b, k_tiles, k_sprites, k_color, k_palette);
	audio_load(b, k_wave);
	if (!b->gfx.have_gfx)
		fprintf(stderr, "lift: tile/sprite ROMs not found, using a fallback picture\n");
	if (!b->audio.have_prom)
		fprintf(stderr, "lift: waveform PROM not found, sound stays silent\n");
}

static int run_check(Board *b, int n)
{
	uint8_t *recs = malloc((size_t)n * LIFT_FRAME_BYTES);
	if (!recs) {
		fprintf(stderr, "lift: out of memory\n");
		return 1;
	}

	int idle = 0;
	for (int i = 0; i < n; i++) {
		board_frame(b);
		if (b->cur.stop == LIFT_STOP_IDLE)
			idle++;
		memcpy(recs + (size_t)i * LIFT_FRAME_BYTES, b->corpus.packed, LIFT_FRAME_BYTES);
	}

	b->frame_index = 0;
	b->mismatch = 0;
	board_reset(b);

	int idle2 = 0;
	for (int i = 0; i < n; i++) {
		board_frame(b);
		if (b->cur.stop == LIFT_STOP_IDLE)
			idle2++;
		if (memcmp(recs + (size_t)i * LIFT_FRAME_BYTES, b->corpus.packed,
			   LIFT_FRAME_BYTES) != 0) {
			char detail[96];
			corpus_diff_at(recs + (size_t)i * LIFT_FRAME_BYTES, b->corpus.packed,
				       detail, sizeof detail);
			fprintf(stderr, "lift-check: attract diverge at frame %d: %s\n",
				i, detail);
			free(recs);
			return 1;
		}
	}

	const char *dir = "build/lift/check-corpus";
	b->frame_index = 0;
	b->mismatch = 0;
	board_reset(b);
	if (corpus_open_record(b, dir) != 0) {
		fprintf(stderr, "lift-check: cannot record %s\n", dir);
		free(recs);
		return 1;
	}
	for (int i = 0; i < n; i++)
		board_frame(b);
	corpus_close(b);

	if (corpus_open_replay(b, dir) != 0) {
		fprintf(stderr, "lift-check: cannot replay %s\n", dir);
		free(recs);
		return 1;
	}
	while (b->frame_index < b->corpus.play_count) {
		board_frame(b);
		if (b->mismatch) {
			fprintf(stderr, "lift-check: replay mismatch: %s\n",
				b->corpus.mismatch_msg);
			corpus_close(b);
			free(recs);
			return 1;
		}
	}
	corpus_close(b);

	printf("lift-check: %d frames, idle %d/%d, replay ok\n", n, idle, idle2);
	if (idle == 0) {
		fprintf(stderr, "lift-check: attract never reached the idle loop\n");
		free(recs);
		return 1;
	}
	free(recs);
	return 0;
}

static int replay_headless(Board *b)
{
	while (b->frame_index < b->corpus.play_count && !b->mismatch)
		board_frame(b);
	if (b->mismatch) {
		fprintf(stderr, "lift: replay mismatch: %s\n", b->corpus.mismatch_msg);
		return 1;
	}
	printf("lift: replay frames %u-%u ok\n",
	       b->corpus.start_frame + 1, b->corpus.play_count - 1);
	return 0;
}

static char *session_dir(void)
{
	time_t now = time(NULL);
	struct tm tm;
	localtime_r(&now, &tm);
	char *dir = malloc(64);
	if (!dir)
		return NULL;
	strftime(dir, 64, "corpus/session-%Y%m%d-%H%M%S", &tm);
	return dir;
}

static int play(Board *b, int show_video)
{
	if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) {
		fprintf(stderr, "lift: SDL_Init: %s\n", SDL_GetError());
		return 1;
	}

	SDL_Window *win = NULL;
	SDL_Renderer *ren = NULL;
	SDL_Texture *tex = NULL;
	uint8_t *pixels = NULL;
	if (show_video) {
		win = SDL_CreateWindow("Ms. Pac-Man",
				       LIFT_SCREEN_W * 3, LIFT_SCREEN_H * 3, 0);
		ren = win ? SDL_CreateRenderer(win, NULL) : NULL;
		tex = ren ? SDL_CreateTexture(ren, SDL_PIXELFORMAT_RGB24,
					      SDL_TEXTUREACCESS_STREAMING,
					      LIFT_SCREEN_W, LIFT_SCREEN_H) : NULL;
		if (!tex) {
			fprintf(stderr, "lift: video: %s\n", SDL_GetError());
			SDL_Quit();
			return 1;
		}
		SDL_SetTextureScaleMode(tex, SDL_SCALEMODE_NEAREST);
		pixels = malloc((size_t)LIFT_SCREEN_W * LIFT_SCREEN_H * 3);
	}

	SDL_AudioSpec spec;
	SDL_zero(spec);
	spec.format = SDL_AUDIO_F32;
	spec.channels = 1;
	spec.freq = LIFT_AUDIO_HZ;
	/* One small hardware buffer. The default queue was holding a third of a second. */
	SDL_SetHint(SDL_HINT_AUDIO_DEVICE_SAMPLE_FRAMES, "512");
	SDL_AudioStream *audio = SDL_OpenAudioDeviceStream(
		SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, NULL, NULL);
	float samples[LIFT_SAMPLES_PER_FRAME];
	if (audio)
		SDL_ResumeAudioStreamDevice(audio);

	uint64_t t0 = SDL_GetTicksNS();
	uint32_t shown = 0;
	int rc = 0;

	while (!b->input.quit) {
		SDL_Event ev;
		while (SDL_PollEvent(&ev)) {
			if (ev.type == SDL_EVENT_QUIT)
				b->input.quit = 1;
			if (ev.type == SDL_EVENT_KEY_DOWN && !ev.key.repeat) {
				if (ev.key.scancode == SDL_SCANCODE_ESCAPE)
					b->input.quit = 1;
				if (ev.key.scancode == SDL_SCANCODE_F9)
					b->input.toggle_record = 1;
			}
		}
		if (b->input.quit)
			break;

		if (b->input.toggle_record && !b->corpus.replaying) {
			b->input.toggle_record = 0;
			if (b->corpus.recording) {
				corpus_close(b);
				fprintf(stderr, "lift: recording stopped\n");
			} else {
				char *dir = session_dir();
				board_reset(b);
				b->frame_index = 0;
				b->mismatch = 0;
				if (dir && corpus_open_record(b, dir) == 0)
					fprintf(stderr, "lift: recording %s\n", dir);
				else
					fprintf(stderr, "lift: could not start recording\n");
				free(dir);
				t0 = SDL_GetTicksNS();
				shown = 0;
			}
		}

		if (!b->corpus.replaying)
			input_poll(b);
		board_frame(b);
		if (b->corpus.replaying && b->mismatch) {
			fprintf(stderr, "lift: replay mismatch: %s\n",
				b->corpus.mismatch_msg);
			rc = 1;
			break;
		}
		if (b->corpus.replaying && b->frame_index >= b->corpus.play_count)
			break;

		if (show_video) {
			video_render(b, pixels, LIFT_SCREEN_W * 3);
			SDL_UpdateTexture(tex, NULL, pixels, LIFT_SCREEN_W * 3);
			SDL_RenderTexture(ren, tex, NULL, NULL);
			SDL_RenderPresent(ren);
		}
		if (audio) {
			/* Keep at most two frames queued. A startup hitch used to
			 * fast-forward the loop and leave a third of a second sitting here. */
			int queued = SDL_GetAudioStreamQueued(audio);
			if (queued > (int)sizeof samples * 2)
				SDL_ClearAudioStream(audio);
			audio_render(b, samples, LIFT_SAMPLES_PER_FRAME);
			SDL_PutAudioStreamData(audio, samples,
					       (int)sizeof samples);
		}

		if (!b->corpus.replaying) {
			shown++;
			uint64_t target = t0 + (uint64_t)shown * LIFT_FRAME_NS;
			uint64_t now = SDL_GetTicksNS();
			if (now < target)
				SDL_DelayNS(target - now);
			else if (now > target + LIFT_FRAME_NS)
				t0 = now - (uint64_t)shown * LIFT_FRAME_NS;
		}
	}

	free(pixels);
	if (tex)
		SDL_DestroyTexture(tex);
	if (ren)
		SDL_DestroyRenderer(ren);
	if (win)
		SDL_DestroyWindow(win);
	if (audio)
		SDL_DestroyAudioStream(audio);
	SDL_Quit();
	return rc;
}

int main(int argc, char **argv)
{
	const char *record = NULL;
	const char *replay = NULL;
	int check_n = 0;
	int video = 1;
	int free_play = 0;

	for (int i = 1; i < argc; i++) {
		if (strcmp(argv[i], "--rom") == 0 && i + 1 < argc) {
			k_rom = argv[++i];
		} else if (strcmp(argv[i], "--record") == 0 && i + 1 < argc) {
			record = argv[++i];
		} else if (strcmp(argv[i], "--replay") == 0 && i + 1 < argc) {
			replay = argv[++i];
			video = 0;
		} else if (strcmp(argv[i], "--video") == 0) {
			video = 1;
		} else if (strcmp(argv[i], "--check") == 0 && i + 1 < argc) {
			check_n = atoi(argv[++i]);
			video = 0;
		} else if (strcmp(argv[i], "--free-play") == 0) {
			free_play = 1;
		} else if (strcmp(argv[i], "--help") == 0) {
			usage();
			return 0;
		} else {
			usage();
			return 1;
		}
	}

	Board *b = calloc(1, sizeof *b);
	if (!b) {
		fprintf(stderr, "lift: out of memory\n");
		return 1;
	}
	board_init(b);
	if (free_play)
		b->corpus.dsw1 &= (uint8_t)~0x03u;
	board_load_rom(b, k_rom);
	load_assets(b);

	int rc = 0;
	if (check_n > 0) {
		rc = run_check(b, check_n);
	} else if (replay) {
		if (corpus_open_replay(b, replay) != 0)
			rc = 1;
		else if (video)
			rc = play(b, 1);
		else
			rc = replay_headless(b);
	} else {
		if (record && corpus_open_record(b, record) != 0)
			rc = 1;
		else
			rc = play(b, 1);
	}

	corpus_close(b);
	free(b);
	return rc;
}
