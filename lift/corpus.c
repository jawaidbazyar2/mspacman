#include "lift.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

/* Frame record, little-endian, no padding. 2660 bytes.
 *  0 u32 length
 *  4 u32 frame number
 *  8 13*u16  PC SP AF BC DE HL AF' BC' DE' HL' IX IY WZ
 * 34 8*u8    I R IFF1 IFF2 IM Q INT HALT
 * 42 8       latch $5000-$5007
 * 50 32      voice $5040-$505F
 * 82 u16     watchdog, before the end-of-frame increment
 * 84 1024    tile RAM $4000
 * 1108 1024  color RAM $4400
 * 2132 496   work RAM $4C00
 * 2628 16    sprite RAM $4FF0
 * 2644 16    sprite positions $5060
 */

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
	*v = (uint16_t)b[0] | ((uint16_t)b[1] << 8);
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
	} else if (off < 2628) {
		snprintf(name, cap, "work+$%04X", 0x4C00 + (off - 2132));
	} else if (off < 2644) {
		snprintf(name, cap, "sprite+$%04X", 0x4FF0 + (off - 2628));
	} else {
		snprintf(name, cap, "sprpos+$%04X", 0x5060 + (off - 2644));
	}
}

int corpus_diff_at(const uint8_t *expect, const uint8_t *got, char *msg, size_t cap)
{
	for (int off = 0; off < LIFT_FRAME_BYTES; off++) {
		if (expect[off] == got[off])
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

static void pack_frame(Board *b, uint8_t *out)
{
	uint8_t *p = out;
	put_u32(p, LIFT_FRAME_BYTES);
	p += 4;
	put_u32(p, b->frame_index);
	p += 4;
	uint16_t pairs[13] = {
		Z80_PC(b->cpu), Z80_SP(b->cpu), Z80_AF(b->cpu), Z80_BC(b->cpu),
		Z80_DE(b->cpu), Z80_HL(b->cpu), Z80_AF_(b->cpu), Z80_BC_(b->cpu),
		Z80_DE_(b->cpu), Z80_HL_(b->cpu), Z80_IX(b->cpu), Z80_IY(b->cpu),
		Z80_MEMPTR(b->cpu)
	};
	for (int i = 0; i < 13; i++) {
		put_u16(p, pairs[i]);
		p += 2;
	}
	*p++ = b->cpu.i;
	*p++ = b->cpu.r;
	*p++ = b->cpu.iff1;
	*p++ = b->cpu.iff2;
	*p++ = b->cpu.im;
	*p++ = b->cpu.q;
	*p++ = b->cpu.int_line;
	*p++ = b->cpu.halt_line;
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
	memcpy(p, b->mem + 0x4C00, 496);
	p += 496;
	memcpy(p, b->mem + 0x4FF0, 16);
	p += 16;
	memcpy(p, b->spr2, 16);
	p += 16;
	if (p - out != LIFT_FRAME_BYTES)
		fprintf(stderr, "lift: frame pack is %td bytes\n", p - out);
}

static int write_file_header(FILE *f, uint8_t dsw1)
{
	uint8_t pad[3] = {0, 0, 0};
	return write_all(f, "MSPF", 4) &&
	       write_u32(f, 1) &&
	       write_u32(f, LIFT_FRAME_BYTES) &&
	       write_u32(f, LIFT_CYCLES_PER_FRAME) &&
	       write_all(f, &dsw1, 1) &&
	       write_all(f, pad, 3);
}

int corpus_open_record(Board *b, const char *dir)
{
	if (mkdir(dir, 0755) != 0 && errno != EEXIST) {
		perror(dir);
		return -1;
	}
	snprintf(b->corpus.dir, sizeof b->corpus.dir, "%s", dir);
	char path[640];
	snprintf(path, sizeof path, "%s/frames", dir);
	b->corpus.frames = fopen(path, "wb");
	if (!b->corpus.frames || !write_file_header(b->corpus.frames, b->corpus.dsw1)) {
		if (b->corpus.frames)
			fclose(b->corpus.frames);
		b->corpus.frames = NULL;
		return -1;
	}
	snprintf(path, sizeof path, "%s/inputs", dir);
	b->corpus.inputs = fopen(path, "wb");
	if (!b->corpus.inputs) {
		fclose(b->corpus.frames);
		b->corpus.frames = NULL;
		return -1;
	}
	if (!write_u32(b->corpus.inputs, 0x54504E49u) || !write_u32(b->corpus.inputs, 1)) {
		corpus_close(b);
		return -1;
	}
	b->corpus.recording = 1;
	return 0;
}

void corpus_close(Board *b)
{
	if (b->corpus.inputs)
		fclose(b->corpus.inputs);
	if (b->corpus.frames)
		fclose(b->corpus.frames);
	b->corpus.inputs = NULL;
	b->corpus.frames = NULL;
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
	return 0;
}

void corpus_note_frame(Board *b)
{
	pack_frame(b, b->corpus.packed);
	if (b->corpus.recording) {
		uint16_t n = b->cur.nreads;
		if (!write_all(b->corpus.frames, b->corpus.packed, LIFT_FRAME_BYTES) ||
		    !write_u16(b->corpus.inputs, n) ||
		    (n && !write_all(b->corpus.inputs, b->cur.reads, n)))
			fprintf(stderr, "lift: frame %u write failed\n", b->frame_index);
		fflush(b->corpus.frames);
		fflush(b->corpus.inputs);
	}
	if (!b->corpus.replaying || b->mismatch)
		return;
	if (b->cur.nreads != b->corpus.replay_nreads) {
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "frame %u input count expected %u got %u",
			 b->frame_index, b->corpus.replay_nreads, b->cur.nreads);
		b->mismatch = 1;
		return;
	}
	uint8_t expect[LIFT_FRAME_BYTES];
	if (!read_all(b->corpus.frames, expect, LIFT_FRAME_BYTES)) {
		snprintf(b->corpus.mismatch_msg, sizeof b->corpus.mismatch_msg,
			 "frame %u truncated record", b->frame_index);
		b->mismatch = 1;
		return;
	}
	char detail[96];
	if (corpus_diff_at(expect, b->corpus.packed, detail, sizeof detail) >= 0) {
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
	uint32_t ver = 0, bytes = 0, cycles = 0;
	uint8_t dsw = 0, pad[3];
	if (!read_all(fr, magic, 4) || memcmp(magic, "MSPF", 4) != 0 ||
	    !read_u32(fr, &ver) || ver != 1 ||
	    !read_u32(fr, &bytes) || bytes != LIFT_FRAME_BYTES ||
	    !read_u32(fr, &cycles) || cycles != LIFT_CYCLES_PER_FRAME ||
	    !read_all(fr, &dsw, 1) || !read_all(fr, pad, 3)) {
		fclose(fr);
		fprintf(stderr, "lift: bad frames header in %s\n", dir);
		return -1;
	}
	if (fseek(fr, 0, SEEK_END) != 0) {
		fclose(fr);
		return -1;
	}
	long sz = ftell(fr);
	if (sz < LIFT_FRAME_HDR || (sz - LIFT_FRAME_HDR) % LIFT_FRAME_BYTES != 0) {
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
	b->corpus.frames = fr;
	b->corpus.inputs = in;
	b->corpus.play_count = (uint32_t)((sz - LIFT_FRAME_HDR) / LIFT_FRAME_BYTES);
	b->corpus.replaying = 1;
	b->corpus.recording = 0;
	b->frame_index = 0;
	b->mismatch = 0;
	b->corpus.mismatch_msg[0] = 0;
	board_reset(b);
	return 0;
}
