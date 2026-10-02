#include "lift.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static int write_all(FILE *f, const void *p, size_t n)
{
	return fwrite(p, 1, n, f) == n;
}

static int read_all(FILE *f, void *p, size_t n)
{
	return fread(p, 1, n, f) == n;
}

int corpus_open_record(Board *b, const char *dir)
{
	if (mkdir(dir, 0755) != 0 && errno != EEXIST) {
		perror(dir);
		return -1;
	}
	snprintf(b->corpus.dir, sizeof b->corpus.dir, "%s", dir);
	char path[640];
	snprintf(path, sizeof path, "%s/header", dir);
	FILE *h = fopen(path, "wb");
	if (!h)
		return -1;
	uint32_t ver = 1;
	uint32_t cycles = LIFT_CYCLES_PER_FRAME;
	char build[32];
	memset(build, 0, sizeof build);
	snprintf(build, sizeof build, "mspac-lift-1");
	if (!write_all(h, "MSPC", 4) ||
	    !write_all(h, &ver, 4) ||
	    !write_all(h, &cycles, 4) ||
	    !write_all(h, &b->corpus.dsw1, 1) ||
	    !write_all(h, "\xFF\0\0", 3) ||
	    !write_all(h, build, 32) ||
	    !write_all(h, b->corpus.reset_ram, 0x1000)) {
		fclose(h);
		return -1;
	}
	fclose(h);
	snprintf(path, sizeof path, "%s/inputs", dir);
	b->corpus.inputs = fopen(path, "wb");
	snprintf(path, sizeof path, "%s/hashes", dir);
	b->corpus.hashes = fopen(path, "w");
	if (!b->corpus.inputs || !b->corpus.hashes)
		return -1;
	uint32_t magic = 0x54504E49u; /* 'INPT' little-endian */
	uint32_t one = 1;
	write_all(b->corpus.inputs, &magic, 4);
	write_all(b->corpus.inputs, &one, 4);
	b->corpus.recording = 1;
	b->corpus.ring_i = 0;
	b->corpus.ring_n = 0;
	return 0;
}

static void save_ring(Board *b)
{
	char path[640];
	snprintf(path, sizeof path, "%s/ring", b->corpus.dir);
	FILE *f = fopen(path, "wb");
	if (!f)
		return;
	uint32_t n = b->corpus.ring_n;
	uint32_t first = 0;
	if (n == LIFT_RING)
		first = b->frame_index - LIFT_RING;
	fwrite("RING", 1, 4, f);
	fwrite(&n, 4, 1, f);
	fwrite(&first, 4, 1, f);
	uint32_t start = (n == LIFT_RING) ? b->corpus.ring_i : 0;
	for (uint32_t i = 0; i < n; i++) {
		uint32_t idx = (start + i) % LIFT_RING;
		LiftFrame *fr = &b->corpus.ring[idx];
		LiftSnap *snap = &b->corpus.snap[idx];
		fwrite(&fr->stop, 1, 1, f);
		fwrite(fr->h, 8, 5, f);
		fwrite(&fr->nreads, 2, 1, f);
		fwrite(fr->reads, 1, fr->nreads, f);
		fwrite(snap, 1, sizeof *snap, f);
	}
	fclose(f);
}

void corpus_close(Board *b)
{
	if (b->corpus.recording)
		save_ring(b);
	if (b->corpus.inputs)
		fclose(b->corpus.inputs);
	if (b->corpus.hashes)
		fclose(b->corpus.hashes);
	b->corpus.inputs = NULL;
	b->corpus.hashes = NULL;
	b->corpus.recording = 0;
	free(b->corpus.play);
	b->corpus.play = NULL;
}

void corpus_note_frame(Board *b)
{
	uint32_t slot_i = b->corpus.ring_i;
	LiftFrame *slot = &b->corpus.ring[slot_i];
	LiftSnap *snap = &b->corpus.snap[slot_i];
	*slot = b->cur;
	memcpy(snap->work, b->mem + 0x4C00, sizeof snap->work);
	memcpy(snap->video, b->mem + 0x4000, sizeof snap->video);
	memcpy(snap->color, b->mem + 0x4400, sizeof snap->color);
	memcpy(snap->spr, b->mem + 0x4FF0, sizeof snap->spr);
	memcpy(snap->spr2, b->spr2, sizeof snap->spr2);
	b->corpus.ring_i = (b->corpus.ring_i + 1) % LIFT_RING;
	if (b->corpus.ring_n < LIFT_RING)
		b->corpus.ring_n++;

	if (!b->corpus.recording)
		return;
	uint16_t n = b->cur.nreads;
	fwrite(&n, 2, 1, b->corpus.inputs);
	if (n)
		fwrite(b->cur.reads, 1, n, b->corpus.inputs);
	fprintf(b->corpus.hashes, "%u %u %016llx %016llx %016llx %016llx %016llx\n",
		b->frame_index - 1, b->cur.stop,
		(unsigned long long)b->cur.h[0],
		(unsigned long long)b->cur.h[1],
		(unsigned long long)b->cur.h[2],
		(unsigned long long)b->cur.h[3],
		(unsigned long long)b->cur.h[4]);
	fflush(b->corpus.hashes);
	fflush(b->corpus.inputs);
}

int corpus_open_replay(Board *b, const char *dir)
{
	char path[640];
	snprintf(path, sizeof path, "%s/header", dir);
	FILE *h = fopen(path, "rb");
	if (!h) {
		perror(path);
		return -1;
	}
	char magic[4];
	uint32_t ver = 0, cycles = 0;
	uint8_t dsw = 0, pad[3];
	char build[32];
	if (!read_all(h, magic, 4) || memcmp(magic, "MSPC", 4) != 0 ||
	    !read_all(h, &ver, 4) || !read_all(h, &cycles, 4) ||
	    !read_all(h, &dsw, 1) || !read_all(h, pad, 3) ||
	    !read_all(h, build, 32) ||
	    !read_all(h, b->corpus.reset_ram, 0x1000)) {
		fclose(h);
		fprintf(stderr, "lift: bad header in %s\n", dir);
		return -1;
	}
	fclose(h);
	b->corpus.dsw1 = dsw;

	snprintf(path, sizeof path, "%s/inputs", dir);
	FILE *in = fopen(path, "rb");
	snprintf(path, sizeof path, "%s/hashes", dir);
	FILE *hs = fopen(path, "r");
	if (!in || !hs) {
		if (in) fclose(in);
		if (hs) fclose(hs);
		return -1;
	}
	uint32_t imagic = 0, iver = 0;
	if (!read_all(in, &imagic, 4) || imagic != 0x54504E49u || !read_all(in, &iver, 4)) {
		fclose(in);
		fclose(hs);
		return -1;
	}

	size_t cap = 1024;
	LiftFrame *frames = calloc(cap, sizeof *frames);
	uint32_t count = 0;
	while (1) {
		unsigned idx = 0, stop = 0;
		unsigned long long hh[5];
		int got = fscanf(hs, "%u %u %llx %llx %llx %llx %llx",
				 &idx, &stop, &hh[0], &hh[1], &hh[2], &hh[3], &hh[4]);
		if (got != 7)
			break;
		if (count == cap) {
			cap *= 2;
			frames = realloc(frames, cap * sizeof *frames);
		}
		uint16_t n = 0;
		if (!read_all(in, &n, 2) || n > LIFT_MAX_READS) {
			free(frames);
			fclose(in);
			fclose(hs);
			fprintf(stderr, "lift: bad input record at frame %u\n", count);
			return -1;
		}
		LiftFrame *fr = &frames[count++];
		memset(fr, 0, sizeof *fr);
		fr->stop = (uint8_t)stop;
		fr->nreads = n;
		if (n && !read_all(in, fr->reads, n)) {
			free(frames);
			fclose(in);
			fclose(hs);
			return -1;
		}
		for (int i = 0; i < 5; i++)
			fr->h[i] = (uint64_t)hh[i];
	}
	fclose(in);
	fclose(hs);
	b->corpus.play = frames;
	b->corpus.play_count = count;
	b->corpus.play_pos = 0;
	b->corpus.replaying = 1;
	b->frame_index = 0;
	b->mismatch = 0;
	board_reset(b);
	return 0;
}
