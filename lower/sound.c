/* The sound engine: three effect channels and three song channels.
 *
 * Each frame the vertical blank runs the effects, then the songs. A
 * channel's `num` holds one bit per requested sound; the highest set bit
 * plays. The routine writes four frequency bytes for its voice and
 * returns the volume, which the caller stores in the voice's volume byte.
 * vblank copies those bytes to the sound hardware at the start of the
 * next frame.
 */
#include "game.h"

#include <string.h>

/* ROM tables. */
#define VOLUME_TYPES   0x2F02u /* jump table for the 16 envelope types */
#define NOTE_DURATIONS 0x3BB0u /* frames per note, by bits 7-5 of a note */
#define NOTE_FREQS     0x3BB8u /* base frequency, by bits 3-0 of a note */
#define EFFECTS_CH1    0x3B30u /* 8 bytes per effect bit */
#define EFFECTS_CH2    0x3B40u
#define EFFECTS_CH3    0x3B80u
#define SONGS_CH1      0x9685u /* song pointers per channel */
#define SONGS_CH2      0x967Du
#define SONGS_CH3      0x968Du

/* Song bytes from $F0 up are commands. */
enum {
	SONG_JUMP = 0xF0,     /* the next word is the new song pointer */
	SONG_SELECT = 0xF1,   /* the next byte sets the wave select */
	SONG_OCTAVE = 0xF2,   /* the next byte sets the octave */
	SONG_VOLUME = 0xF3,   /* the next byte sets the volume */
	SONG_TYPE = 0xF4,     /* the next byte sets the envelope type */
	SONG_END = 0xFF       /* clear this song's bit */
};

static uint8_t swap_nibbles(uint8_t v)
{
	return (uint8_t)((uint8_t)(v << 4) | (v >> 4));
}

/* Stop the channel's current sound. Returns the volume, 0. */
static uint8_t silence(SoundChannel *ch, uint8_t *freq)
{
	if (ch->cur_bit == 0)
		return 0;
	ch->cur_bit = 0;
	ch->dir = 0;
	ch->freq = 0;
	ch->volume = 0;
	freq[0] = 0;
	freq[1] = 0;
	freq[2] = 0;
	freq[3] = 0;
	return 0;
}

/* Lower the volume by one, stopping at 0. */
static uint8_t fade(SoundChannel *ch)
{
	uint8_t v = (uint8_t)(ch->volume & 0x0Fu);

	if (v == 0)
		return 0;
	ch->volume = --v;
	return v;
}

/* Apply the channel's envelope type and return the volume. */
static uint8_t envelope(Board *b, SoundChannel *ch)
{
	uint16_t target = rom16(b, (uint16_t)(VOLUME_TYPES + (uint8_t)(ch->type << 1)));
	uint8_t counter = work_ram(b->mem)->SOUND_COUNTER;

	switch (target) {
	case 0x2F22: /* type 0: hold */
		return ch->volume;
	case 0x2F26: /* type 1: fade every frame */
		return fade(ch);
	case 0x2F2B: /* type 2: fade every 2nd frame */
		return (counter & 1u) ? ch->volume : fade(ch);
	/* Types 3 and up are dead in Ms. Pac-Man. No song or requested
	 * effect uses them; py/scan_sound_tables.py lists the tables. Types
	 * 4 and 7 appear only in channel 3 bits 6-7, whose entries run into
	 * the note tables and which nothing requests. */
	case 0x2F3C: /* type 3: every 4th */
		return (counter & 3u) ? ch->volume : fade(ch);
	case 0x2F43: /* type 4: every 8th */
		return (counter & 7u) ? ch->volume : fade(ch);
	default:
		/* Types 5-15 point at bare RETs. The volume is whatever the
		 * dispatch left in A: the low byte of that address. */
		return (uint8_t)target;
	}
}

/* Store a frequency as the voice's four nibble bytes. Each byte also
 * keeps the other nibble; the hardware ignores the top four bits. */
static uint8_t set_freq(Board *b, SoundChannel *ch, uint8_t *freq, uint16_t f)
{
	freq[0] = (uint8_t)f;
	freq[1] = swap_nibbles((uint8_t)f);
	freq[2] = (uint8_t)(f >> 8);
	freq[3] = swap_nibbles((uint8_t)(f >> 8));
	return envelope(b, ch);
}

static uint8_t set_shifted_freq(Board *b, SoundChannel *ch, uint8_t *freq,
				uint8_t base, uint8_t shift)
{
	uint16_t f = base;

	while (shift-- != 0)
		f = (uint16_t)(f << 1);
	return set_freq(b, ch, freq, f);
}

/* A song note's frequency. Bit 4 of the note raises it an octave. */
static uint8_t song_freq(Board *b, SoundChannel *ch, uint8_t *freq)
{
	uint8_t shift = (uint8_t)(((ch->dir & 0x10u) ? 1u : 0u) + ch->w.octave);

	return set_shifted_freq(b, ch, freq, ch->freq, shift);
}

/* Start a note. Bits 7-5 pick the duration. Bits 4-0, when not zero,
 * are the pitch; zero holds the previous pitch. */
static uint8_t play_note(Board *b, SoundChannel *ch, uint8_t *freq, uint8_t note)
{
	if ((note & 0x1Fu) != 0)
		ch->dir = note;
	ch->volume = (ch->type & 0x08u) ? 0 : ch->w.volume0;
	ch->duration = rom8(b, (uint16_t)(NOTE_DURATIONS + (note >> 5)));
	if ((note & 0x1Fu) != 0)
		ch->freq = rom8(b, (uint16_t)(NOTE_FREQS + (note & 0x0Fu)));
	return song_freq(b, ch, freq);
}

static uint16_t song_ptr(const SoundChannel *ch)
{
	return (uint16_t)(ch->w.ptr_lo | (uint16_t)((uint16_t)ch->w.ptr_hi << 8));
}

static void set_song_ptr(SoundChannel *ch, uint16_t p)
{
	ch->w.ptr_lo = (uint8_t)p;
	ch->w.ptr_hi = (uint8_t)(p >> 8);
}

static uint8_t song_byte(Board *b, SoundChannel *ch)
{
	uint16_t p = song_ptr(ch);

	set_song_ptr(ch, (uint16_t)(p + 1u));
	return rom8(b, p);
}

/* Run song bytes from `p` until a note plays. */
static uint8_t run_song(Board *b, SoundChannel *ch, uint8_t *freq, uint16_t p)
{
	set_song_ptr(ch, p);
	for (;;) {
		uint8_t op = song_byte(b, ch);

		if (op < SONG_JUMP)
			return play_note(b, ch, freq, op);
		/* No song in the ROM jumps or uses $F5-$FE, so those cases
		 * are dead. */
		switch (op) {
		case SONG_JUMP:
			set_song_ptr(ch, rom16(b, song_ptr(ch)));
			break;
		case SONG_SELECT:
			ch->w.select = song_byte(b, ch);
			break;
		case SONG_OCTAVE:
			ch->w.octave = song_byte(b, ch);
			break;
		case SONG_VOLUME:
			ch->w.volume0 = song_byte(b, ch);
			break;
		case SONG_TYPE:
			ch->type = song_byte(b, ch);
			break;
		case SONG_END:
			/* The bytes after the end marker still run. */
			ch->num &= (uint8_t)~ch->cur_bit;
			silence(ch, freq);
			break;
		default:
			break; /* $F5-$FE do nothing */
		}
	}
}

/* Bit 0 is the start song. Bit 1 is the intermission tune, which
 * depends on the level. */
static uint16_t song_start(Board *b, uint16_t table, uint8_t bit_index)
{
	uint8_t level = work_ram(b->mem)->level_number;
	uint8_t which = 0;

	if (bit_index == 1)
		which = level == 1 ? 1 : level == 4 ? 2 : 3;
	return rom16(b, (uint16_t)(table + (uint16_t)(which << 1)));
}

/* The highest set bit of a nonzero mask, and its index 0-7. */
static uint8_t top_bit(uint8_t mask, uint8_t *index)
{
	uint8_t bit = 0x80;
	uint8_t i = 7;

	while ((mask & bit) == 0) {
		bit >>= 1;
		i--;
	}
	*index = i;
	return bit;
}

/* One song channel. Returns the volume. */
static uint8_t song_channel(Board *b, SoundChannel *ch, uint8_t *freq,
			    uint16_t table)
{
	uint8_t index;
	uint8_t bit;

	if (ch->num == 0)
		return silence(ch, freq);
	bit = top_bit(ch->num, &index);
	if ((ch->cur_bit & bit) == 0) {
		ch->cur_bit = bit;
		return run_song(b, ch, freq, song_start(b, table, index));
	}
	if (--ch->duration != 0)
		return song_freq(b, ch, freq);
	return run_song(b, ch, freq, song_ptr(ch));
}

/* An effect's frequency: step it, then shift by the octave. */
static uint8_t effect_freq(Board *b, SoundChannel *ch, uint8_t *freq)
{
	ch->freq = (uint8_t)(ch->freq + ch->e.step);
	return set_shifted_freq(b, ch, freq, ch->freq,
				(uint8_t)((ch->e.shape & 0x70u) >> 4));
}

/* Copy the effect's 8 table bytes and set up its first sweep. */
static void load_effect(Board *b, SoundChannel *ch, uint16_t table,
			uint8_t index)
{
	uint8_t *params = &ch->e.shape;
	uint16_t src = (uint16_t)(table + (uint16_t)(index << 3));
	unsigned i;

	for (i = 0; i < 8; i++)
		params[i] = rom8(b, (uint16_t)(src + i));
	ch->duration = (uint8_t)(ch->e.length & 0x7Fu);
	ch->freq = ch->e.base;
	ch->type = (uint8_t)(ch->e.volume0 >> 4);
	if ((ch->type & 0x08u) == 0) {
		ch->volume = ch->e.volume0;
		ch->dir = 0;
	}
}

/* One effect channel. Returns the volume. */
static uint8_t effect_channel(Board *b, SoundChannel *ch, uint8_t *freq,
			      uint16_t table)
{
	for (;;) {
		uint8_t index;
		uint8_t bit;

		if (ch->num == 0)
			return silence(ch, freq);
		bit = top_bit(ch->num, &index);
		if ((ch->cur_bit & bit) == 0) {
			ch->cur_bit = bit;
			load_effect(b, ch, table, index);
		}
		if (--ch->duration != 0)
			return effect_freq(b, ch, freq);

		/* End of a sweep. The last repeat clears the request. */
		if (ch->e.repeats != 0 && --ch->e.repeats == 0) {
			ch->num &= (uint8_t)~bit;
			continue;
		}
		ch->duration = (uint8_t)(ch->e.length & 0x7Fu);
		if (ch->e.length & 0x80u) {
			/* Sweep back and forth. Every other sweep is the way back. */
			ch->e.step = (uint8_t)-ch->e.step;
			if ((ch->dir & 0x01u) == 0) {
				ch->dir |= 0x01u;
				return effect_freq(b, ch, freq);
			}
			/* Dead: the only two back-and-forth effects (credit,
			 * fruit) have 2 repeats, which run out here first. */
			ch->dir &= (uint8_t)~0x01u;
		}
		ch->e.base = (uint8_t)(ch->e.base + ch->e.repeat_step);
		ch->freq = ch->e.base;
		ch->e.volume0 = (uint8_t)(ch->e.volume0 + ch->e.volume_step);
		if ((ch->type & 0x08u) == 0)
			ch->volume = ch->e.volume0;
		return effect_freq(b, ch, freq);
	}
}

/* $2D0C  run the three effect channels */
void sound_effects(Board *b)
{
	LOWER_HOOK(sound_effects, b);
	WorkRam *ram = work_ram(b->mem);

	ram->CH1_VOL = effect_channel(b, &ram->effect[0], &ram->CH1_FREQ0, EFFECTS_CH1);
	ram->CH2_VOL = effect_channel(b, &ram->effect[1], &ram->CH2_FREQ1, EFFECTS_CH2);
	ram->CH3_VOL = effect_channel(b, &ram->effect[2], &ram->CH3_FREQ1, EFFECTS_CH3);
	ram->CH1_FREQ4 = 0;
}

/* $2CC1 -> $9797  intermission sprites, then the three song channels.
 * A song's volume replaces the effect's only while the song plays. */
void sound_songs(Board *b)
{
	LOWER_HOOK(sound_songs, b);
	WorkRam *ram = work_ram(b->mem);
	static const struct {
		uint16_t table;
		size_t freq;
		size_t vol;
	} k_song[3] = {
		{SONGS_CH1, offsetof(WorkRam, CH1_FREQ0), offsetof(WorkRam, CH1_VOL)},
		{SONGS_CH2, offsetof(WorkRam, CH2_FREQ1), offsetof(WorkRam, CH2_VOL)},
		{SONGS_CH3, offsetof(WorkRam, CH3_FREQ1), offsetof(WorkRam, CH3_VOL)},
	};
	uint8_t *base = (uint8_t *)ram;
	unsigned i;

	if (ram->intermission_flag != 0)
		memcpy(&ram->sprite[SPR_RED], ram->cutscene_sprite,
		       sizeof ram->cutscene_sprite);
	/* Player 2 on a cocktail table: sprite $3F becomes $FF. Out of
	 * scope for the port. */
	if ((ram->player_number & ram->dip_cocktail) != 0 &&
	    ram->sprite[SPR_PAC].code == 0x3F)
		ram->sprite[SPR_PAC].code = 0xFF;

	for (i = 0; i < 3; i++) {
		SoundChannel *ch = &ram->wave[i];
		uint8_t vol = song_channel(b, ch, base + k_song[i].freq, k_song[i].table);

		if (ch->num != 0)
			base[k_song[i].vol] = vol;
	}
}
