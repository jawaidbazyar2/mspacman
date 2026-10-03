/* Host side: record and replay corpus sessions, and compare each frame
 * against the recording. */
#include "lift.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

/* Frame record, version 3, little-endian, no padding. 3176 bytes.
 *  0 u32 length
 *  4 u32 frame number
 *  8 13*u16  PC SP AF BC DE HL AF' BC' DE' HL' IX IY WZ
 * 34 8*u8    I, R slot (zero), IFF1 IFF2 IM Q INT HALT
 * 42 8       latch $5000-$5007
 * 50 32      voice $5040-$505F
 * 82 u16     watchdog, before the end-of-frame increment
 * 84 1024    tile RAM $4000
 * 1108 1024  color RAM $4400
 * 2132 1008  work RAM $4C00-$4FEF
 * 3140 16    sprite RAM $4FF0
 * 3156 16    sprite positions $5060
 * 3172 u32   generator state after this frame
 *
 * Version 2 is the same with 496 bytes of work RAM ($4C00-$4DEF). It is
 * read into the version 3 layout and the missing bytes are not compared.
 */

#define OFF_WORK    2132
#define WORK_BYTES  1008
#define WORK_V2     496
#define OFF_SPRITE  (OFF_WORK + WORK_BYTES)
#define OFF_SPRPOS  (OFF_SPRITE + 16)
#define OFF_RAND    (OFF_SPRPOS + 16)

#define MASK_REGS   1
#define MASK_STACK  2
#define MASK_V2     4

static int write_all(FILE *f, const void *p, size_t n)
{
	return f && fwrite(p, 1, n, f) == n;
}

static int read_all(FILE *f, void *p, size_t n)
{
	return f && fread(p, 1, n, f) == n;
}

static void put_u16(uint8_t *p, uint16_t v)
{
	p[0] = (uint8_t)v;
	p[1] = (uint8_t)(v >> 8);
}

static void put_u32(uint8_t *p, uint32_t v)
{
	p[0] = (uint8_t)v;
	p[1] = (uint8_t)(v >> 8);
	p[2] = (uint8_t)(v >> 16);
	p[3] = (uint8_t)(v >> 24);
}

static uint32_t get_u32(const uint8_t *p)
{
	return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
	       ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static int write_u16(FILE *f, uint16_t v)
{
	uint8_t b[2];
	put_u16(b, v);
	return write_all(f, b, 2);
}

static int write_u32(FILE *f, uint32_t v)
{
	uint8_t b[4];
	put_u32(b, v);
	return write_all(f, b, 4);
}

static int read_u16(FILE *f, uint16_t *v)
{
	uint8_t b[2];
	if (!read_all(f, b, 2))
		return 0;
	uint16_t lo = b[0];
	uint16_t hi = b[1];
	*v = (uint16_t)(lo | (uint16_t)(hi << 8));
	return 1;
}

static int read_u32(FILE *f, uint32_t *v)
{
	uint8_t b[4];
	if (!read_all(f, b, 4))
		return 0;
	*v = get_u32(b);
	return 1;
}

static void field_name(int off, char *name, size_t cap)
{
	static const char *pairs[] = {
		"PC", "SP", "AF", "BC", "DE", "HL",
		"AF'", "BC'", "DE'", "HL'", "IX", "IY", "WZ"
	};
	static const char *flags[] = {
		"I", "R", "IFF1", "IFF2", "IM", "Q", "INT", "HALT"
	};
	if (off < 4)
		snprintf(name, cap, "length+%d", off);
	else if (off < 8)
		snprintf(name, cap, "frame+%d", off - 4);
	else if (off < 34) {
		int i = off - 8;
		snprintf(name, cap, "%s+%d", pairs[i / 2], i % 2);
	} else if (off < 42) {
		snprintf(name, cap, "%s", flags[off - 34]);
	} else if (off < 50) {
		snprintf(name, cap, "latch+$%04X", 0x5000 + (off - 42));
	} else if (off < 82) {
		snprintf(name, cap, "voice+$%04X", 0x5040 + (off - 50));
	} else if (off < 84) {
		snprintf(name, cap, "watchdog+%d", off - 82);
	} else if (off < 1108) {
		snprintf(name, cap, "tile+$%04X", 0x4000 + (off - 84));
	} else if (off < 2132) {
		snprintf(name, cap, "color+$%04X", 0x4400 + (off - 1108));
	} else if (off < OFF_SPRITE) {
		uint16_t addr = (uint16_t)(0x4C00u + (unsigned)(off - OFF_WORK));
		const char *field = work_ram_name(addr);

		if (field)
			snprintf(name, cap, "%s", field);
		else
			snprintf(name, cap, "work+$%04X", addr);
	} else if (off < OFF_SPRPOS) {
		snprintf(name, cap, "sprite+$%04X", 0x4FF0 + (off - OFF_SPRITE));
	} else if (off < OFF_RAND) {
		snprintf(name, cap, "sprpos+$%04X", 0x5060 + (off - OFF_SPRPOS));
	} else {
		snprintf(name, cap, "rand+%d", off - OFF_RAND);
	}
}

/* C-only compare leaves out the register block and the CPU stack at
 * $4F01-$4FBF. The C keeps neither the way the Z80 did. */
static int masked_at(int off, int mask)
{
	if ((mask & MASK_REGS) && off >= 8 && off < 42)
		return 1;
	if ((mask & MASK_STACK) && off >= OFF_WORK + 0x301 && off <= OFF_WORK + 0x3BF)
		return 1;
	if ((mask & MASK_V2) && off >= OFF_WORK + WORK_V2 && off < OFF_SPRITE)
		return 1;
	return 0;
}

static int diff_from(const uint8_t *expect, const uint8_t *got, int mask,
		     char *msg, size_t cap)
{
	for (int off = 0; off < LIFT_FRAME_BYTES; off++) {
		if (expect[off] == got[off])
			continue;
		if (masked_at(off, mask))
			continue;
		char name[32];
		field_name(off, name, sizeof name);
		snprintf(msg, cap, "%s expected %02X got %02X",
			 name, expect[off], got[off]);
		return off;
	}
	if (cap)
		msg[0] = 0;
	return -1;
}

int corpus_diff_at(const uint8_t *expect, const uint8_t *got, char *msg, size_t cap)
{
	return diff_from(expect, got, 0, msg, cap);
}

static uint16_t get_u16(const uint8_t *p)
{
	return (uint16_t)(p[0] | (uint16_t)(p[1] << 8));
}

/* The idle spin at $238D. A record outside it ended mid-setup. */
static int idle_record(const uint8_t *rec)
{
	uint16_t pc = get_u16(rec + 8);

	return pc >= 0x238D && pc <= 0x2392;
}

/* Bytes 8-41 of a record are the Z80 registers. Only IFF1 (byte 36),
 * the interrupt enable, means anything here. */
#define OFF_IFF1 36

static void unpack_frame(Board *b, const uint8_t *rec)
{
	const uint8_t *p = rec + 42;

	b->int_enabled = rec[OFF_IFF1];
	memcpy(b->latch, p, 8);
	p += 8;
	memcpy(b->audio.reg, p, 32);
	p += 32;
	b->frames_since_kick = get_u16(p);
	p += 2;
	memcpy(b->mem + 0x4000, p, 1024);
	p += 1024;
	memcpy(b->mem + 0x4400, p, 1024);
	p += 1024;
	memcpy(b->mem + 0x4C00, p, WORK_BYTES);
	p += WORK_BYTES;
	memcpy(b->mem + 0x4FF0, p, 16);
	p += 16;
	memcpy(b->spr2, p, 16);
	p += 16;
	b->rand_state = get_u32(p);
}

/* One record from the frames file, in the version 3 layout. A version 2
 * record reads as zeros at $4DF0-$4FEF. */
static int read_record(Board *b, uint8_t *rec)
{
	if (b->corpus.file_ver == LIFT_FRAME_VER)
		return read_all(b->corpus.frames, rec, LIFT_FRAME_BYTES);
	if (!read_all(b->corpus.frames, rec, LIFT_FRAME_BYTES_V2))
		return 0;
	memmove(rec + OFF_SPRITE, rec + OFF_WORK + WORK_V2,
		LIFT_FRAME_BYTES_V2 - (OFF_WORK + WORK_V2));
	memset(rec + OFF_WORK + WORK_V2, 0, WORK_BYTES - WORK_V2);
	put_u32(rec, LIFT_FRAME_BYTES);
	return 1;
}

static int compare_mask(Board *b)
{
	int mask = MASK_REGS | MASK_STACK;

	if (b->corpus.file_ver != LIFT_FRAME_VER)
		mask |= MASK_V2;
	return mask;
}

/* C-only replay does not run the self-test or boot. It loads the first
 * record that ends in the idle spin and checks from the frame after it. */
static int seek_idle(Board *b)
{
	uint8_t rec[LIFT_FRAME_BYTES];

	b->corpus.start_frame = UINT32_MAX;
	for (uint32_t i = 0; i < b->corpus.play_count; i++) {
		b->frame_index = i;
		if (corpus_begin_frame(b) != 0)
			return -1;
		if (!read_record(b, rec))
			return -1;
		if (idle_record(rec)) {
			unpack_frame(b, rec);
			b->frame_index = i + 1;
			b->corpus.start_frame = i;
			b->started = 1;
			return 0;
		}
	}
	return -1;
}

static void pack_frame(Board *b, uint8_t *out)
{
	uint8_t *p = out;
	put_u32(p, LIFT_FRAME_BYTES);
	p += 4;
	put_u32(p, b->frame_index);
	p += 4;
	/* The register bytes stay zero but for two. PC marks a frame that
	 * ended with the task list empty, as the idle spin at $2390 did;
	 * replay starts at the first such record. IFF1 and IFF2 are the
	 * interrupt enable. */
	memset(p, 0, 34);
	put_u16(p, (uint16_t)(b->stop ? 0x2390u : 0u));
	out[OFF_IFF1] = b->int_enabled;
	out[OFF_IFF1 + 1] = b->int_enabled;
	p += 34;
	memcpy(p, b->latch, 8);
	p += 8;
	memcpy(p, b->audio.reg, 32);
	p += 32;
	put_u16(p, (uint16_t)b->frames_since_kick);
	p += 2;
	memcpy(p, b->mem + 0x4000, 1024);
	p += 1024;
	memcpy(p, b->mem + 0x4400, 1024);
	p += 1024;
	memcpy(p, b->mem + 0x4C00, WORK_BYTES);
	p += WORK_BYTES;
	memcpy(p, b->mem + 0x4FF0, 16);
	p += 16;
	memcpy(p, b->spr2, 16);
	p += 16;
	put_u32(p, b->rand_state);
	p += 4;
	if (p - out != LIFT_FRAME_BYTES)
		fprintf(stderr, "lift: frame pack is %td bytes\n", p - out);
}

static int write_file_header(FILE *f, uint8_t dsw1, uint32_t seed)
{
	uint8_t pad[3] = {0, 0, 0};
	return write_all(f, "MSPF", 4) &&
	       write_u32(f, LIFT_FRAME_VER) &&
	       write_u32(f, LIFT_FRAME_BYTES) &&
	       write_u32(f, LIFT_CYCLES_PER_FRAME) &&
	       write_all(f, &dsw1, 1) &&
	       write_all(f, pad, 3) &&
	       write_u32(f, seed);
}

static int open_session(const char *dir, uint8_t dsw1, uint32_t seed,
			FILE **frames, FILE **inputs)
{
	if (mkdir(dir, 0755) != 0 && errno != EEXIST) {
		perror(dir);
		return -1;
	}
	char path[640];
	snprintf(path, sizeof path, "%s/frames", dir);
	*frames = fopen(path, "wb");
	snprintf(path, sizeof path, "%s/inputs", dir);
	*inputs = *frames ? fopen(path, "wb") : NULL;
	if (*inputs && write_file_header(*frames, dsw1, seed) &&
	    write_u32(*inputs, 0x54504E49u) && write_u32(*inputs, 1))
		return 0;
	if (*inputs)
		fclose(*inputs);
	if (*frames)
		fclose(*frames);
	*frames = NULL;
	*inputs = NULL;
	return -1;
}

int corpus_open_record(Board *b, const char *dir)
{
	snprintf(b->corpus.dir, sizeof b->corpus.dir, "%s", dir);
	b->rand_seed = LIFT_RAND_SEED;
	b->rand_state = LIFT_RAND_SEED;
	if (open_session(dir, b->corpus.dsw1, b->rand_seed, &b->corpus.frames,
			 &b->corpus.inputs) != 0)
		return -1;
	b->corpus.file_ver = LIFT_FRAME_VER;
	b->corpus.recording = 1;
	return 0;
}

/* While replaying, write what this host produces as a new session. The
 * inputs are the replayed port reads, so a version 2 session replayed on
 * the Z80 comes out as the same play in version 3. */
int corpus_open_rewrite(Board *b, const char *dir)
{
	return open_session(dir, b->corpus.dsw1, b->rand_seed, &b->corpus.out_frames,
			    &b->corpus.out_inputs);
}

static void write_frame(Board *b, FILE *frames, FILE *inputs)
{
	uint16_t n = b->cur.nreads;

	if (!write_all(frames, b->corpus.packed, LIFT_FRAME_BYTES) ||
	    !write_u16(inputs, n) || (n && !write_all(inputs, b->cur.reads, n)))
		fprintf(stderr, "lift: frame %u write failed\n", b->frame_index);
	fflush(frames);
	fflush(inputs);
}

void corpus_close(Board *b)
{
	if (b->corpus.inputs)
		fclose(b->corpus.inputs);
	if (b->corpus.frames)
		fclose(b->corpus.frames);
	if (b->corpus.out_inputs)
		fclose(b->corpus.out_inputs);
	if (b->corpus.out_frames)
		fclose(b->corpus.out_frames);
	b->corpus.inputs = NULL;
	b->corpus.frames = NULL;
	b->corpus.out_inputs = NULL;
	b->corpus.out_frames = NULL;
	b->corpus.recording = 0;
	b->corpus.replaying = 0;
}

int corpus_begin_frame(Board *b)
{
	uint16_t n = 0;
	if (!read_u16(b->corpus.inputs, &n) || n > LIFT_MAX_READS) {
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "frame %u bad input record", b->frame_index);
		return -1;
	}
	if (n && !read_all(b->corpus.inputs, b->corpus.replay_reads, n)) {
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "frame %u truncated input record", b->frame_index);
		return -1;
	}
	b->corpus.replay_nreads = n;
	b->corpus.read_pos = 0;
	if (b->frame_index > b->corpus.start_frame &&
	    !read_record(b, b->corpus.want)) {
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "frame %u truncated record", b->frame_index);
		return -1;
	}
	return 0;
}

void corpus_note_frame(Board *b)
{
	pack_frame(b, b->corpus.packed);
	if (b->corpus.recording)
		write_frame(b, b->corpus.frames, b->corpus.inputs);
	if (b->corpus.out_frames)
		write_frame(b, b->corpus.out_frames, b->corpus.out_inputs);
	if (!b->corpus.replaying || b->mismatch)
		return;
	if (b->cur.nreads != b->corpus.replay_nreads) {
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "frame %u input count expected %u got %u",
			 b->frame_index, b->corpus.replay_nreads, b->cur.nreads);
		b->mismatch = 1;
		return;
	}
	char detail[96];
	if (diff_from(b->corpus.want, b->corpus.packed, compare_mask(b), detail,
		      sizeof detail) >= 0) {
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "frame %u %s", b->frame_index, detail);
		b->mismatch = 1;
	}
}

int corpus_open_replay(Board *b, const char *dir)
{
	char path[640];
	snprintf(path, sizeof path, "%s/frames", dir);
	FILE *fr = fopen(path, "rb");
	if (!fr) {
		perror(path);
		return -1;
	}
	char magic[4];
	uint32_t ver = 0, bytes = 0, cycles = 0, seed = 0;
	uint8_t dsw = 0, pad[3];
	if (!read_all(fr, magic, 4) || memcmp(magic, "MSPF", 4) != 0 ||
	    !read_u32(fr, &ver) || !read_u32(fr, &bytes) ||
	    !((ver == LIFT_FRAME_VER && bytes == LIFT_FRAME_BYTES) ||
	      (ver == 2 && bytes == LIFT_FRAME_BYTES_V2)) ||
	    !read_u32(fr, &cycles) || cycles != LIFT_CYCLES_PER_FRAME ||
	    !read_all(fr, &dsw, 1) || !read_all(fr, pad, 3) ||
	    !read_u32(fr, &seed)) {
		fclose(fr);
		fprintf(stderr, "lift: bad frames header in %s (need MSPF version 2 or %u)\n",
			dir, LIFT_FRAME_VER);
		return -1;
	}
	if (fseek(fr, 0, SEEK_END) != 0) {
		fclose(fr);
		return -1;
	}
	long sz = ftell(fr);
	if (sz < LIFT_FRAME_HDR || (sz - LIFT_FRAME_HDR) % (long)bytes != 0) {
		fclose(fr);
		fprintf(stderr, "lift: frames length is not a whole number of records\n");
		return -1;
	}
	if (fseek(fr, LIFT_FRAME_HDR, SEEK_SET) != 0) {
		fclose(fr);
		return -1;
	}

	snprintf(path, sizeof path, "%s/inputs", dir);
	FILE *in = fopen(path, "rb");
	if (!in) {
		fclose(fr);
		perror(path);
		return -1;
	}
	uint32_t imagic = 0, iver = 0;
	if (!read_u32(in, &imagic) || imagic != 0x54504E49u ||
	    !read_u32(in, &iver) || iver != 1) {
		fclose(in);
		fclose(fr);
		fprintf(stderr, "lift: bad inputs header in %s\n", dir);
		return -1;
	}

	b->corpus.dsw1 = dsw;
	b->rand_seed = seed;
	b->corpus.frames = fr;
	b->corpus.inputs = in;
	b->corpus.file_ver = ver;
	b->corpus.play_count = (uint32_t)((sz - LIFT_FRAME_HDR) / (long)bytes);
	b->corpus.replaying = 1;
	b->corpus.recording = 0;
	b->frame_index = 0;
	b->mismatch = 0;
	b->corpus.mismatch_msg[0] = 0;
	board_reset(b);
	if (seek_idle(b) != 0) {
		fprintf(stderr, "lift: %s has no record in the idle spin\n", dir);
		corpus_close(b);
		return -1;
	}
	return 0;
}
