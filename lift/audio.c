#include "lift.h"

#include <stdio.h>
#include <string.h>

/* Namco WSG as wired on mspacmab: 3 voices, low-nibble samples,
 * registers at $5040 (waveform select $5045/$504A/$504F, freq/vol at $5050).
 * One output sample steps the 192 kHz phase accumulator four times.
 */

void audio_load(Board *b, const char *prom_path)
{
	memset(b->audio.prom, 0, sizeof b->audio.prom);
	b->audio.have_prom = 0;
	FILE *f = fopen(prom_path, "rb");
	if (!f)
		return;
	size_t n = fread(b->audio.prom, 1, sizeof b->audio.prom, f);
	fclose(f);
	b->audio.have_prom = n == sizeof b->audio.prom;
}

static int voice_sample(Board *b, int ch)
{
	if (!b->audio.have_prom || !b->latch[1])
		return 0;
	const uint8_t *r = b->audio.reg;
	int wave = r[5 + ch * 5] & 7;
	int vol = r[0x15 + ch * 5] & 0x0f;
	if (vol == 0)
		return 0;
	uint32_t freq = 0;
	if (ch == 0)
		freq = r[0x10] & 0x0f;
	freq += (uint32_t)(r[0x11 + ch * 5] & 0x0f) << 4;
	freq += (uint32_t)(r[0x12 + ch * 5] & 0x0f) << 8;
	freq += (uint32_t)(r[0x13 + ch * 5] & 0x0f) << 12;
	freq += (uint32_t)(r[0x14 + ch * 5] & 0x0f) << 16;
	b->audio.counter[ch] += freq * 4u;
	int pos = (int)((b->audio.counter[ch] >> 16) & 31);
	int nib = b->audio.prom[(wave << 5) | pos] & 0x0f;
	return (nib - 8) * vol;
}

void audio_render(Board *b, float *out, int nsamples)
{
	for (int i = 0; i < nsamples; i++) {
		int mix = voice_sample(b, 0) + voice_sample(b, 1) + voice_sample(b, 2);
		out[i] = (float)mix / 128.0f;
	}
}
