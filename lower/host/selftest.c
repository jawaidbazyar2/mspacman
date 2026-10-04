/* mspac-lower --selftest: the core, the call stub, register widths,
 * decimal mode, and the game bank, before any game logic is trusted. */
#include "game.h"
#include "hook.h"
#include "shadow.h"

#include <stdio.h>
#include <stdlib.h>

const char *lower_fail_text(uint8_t reason, uint16_t detail)
{
	static char buf[64];
	switch (reason) {
	case FAIL_BAD_TASK:
		snprintf(buf, sizeof buf, "task %02X is not in the table", detail & 0xFFu);
		return buf;
	case FAIL_NOT_EMPTY:
		return "task list did not empty";
	default:
		snprintf(buf, sizeof buf, "fail reason %u", reason);
		return buf;
	}
}

static int call(const char *name, L65Regs *r)
{
	unsigned id = lower_find(name);
	char err[192];
	if (id == (unsigned)-1) {
		fprintf(stderr, "selftest: %s is not in lower/entries.txt\n", name);
		return -1;
	}
	if (l65_call(id, r, err, sizeof err) != 0) {
		fprintf(stderr, "selftest: %s: %s\n", name, err);
		return -1;
	}
	return 0;
}

int lower_selftest(void)
{
	static Board board;
	int bad = 0;

	board_init(&board);
	g_lower_board = &board;

	for (unsigned a = 0; a < 256; a += 37) {
		for (unsigned x = 0; x < 256; x += 41) {
			L65Regs r = { (uint16_t)a, (uint16_t)x, 0 };
			if (call("st_add", &r) != 0)
				return 1;
			if ((r.a & 0xFFu) != ((a + x) & 0xFFu)) {
				fprintf(stderr, "selftest: st_add %02X+%02X gave %02X\n", a, x,
					r.a & 0xFFu);
				bad++;
			}
		}
	}

	for (unsigned a = 0; a < 100; a += 7) {
		for (unsigned x = 0; x < 100; x += 11) {
			uint8_t ba = (uint8_t)((a / 10) << 4 | a % 10);
			uint8_t bx = (uint8_t)((x / 10) << 4 | x % 10);
			bool carry;
			uint8_t want = bcd_add(ba, bx, false, &carry);
			L65Regs r = { ba, bx, 0 };
			if (call("st_bcd", &r) != 0)
				return 1;
			if ((r.a & 0xFFu) != want) {
				fprintf(stderr, "selftest: st_bcd %02X+%02X gave %02X, want %02X\n",
					ba, bx, r.a & 0xFFu, want);
				bad++;
			}
		}
	}

	L65Regs w = { 0, 0x4C44, 0xBEEF };
	if (call("st_store16", &w) != 0)
		return 1;
	if (board.mem[0x4C44] != 0xEF || board.mem[0x4C45] != 0xBE) {
		fprintf(stderr, "selftest: st_store16 wrote %02X %02X\n",
			board.mem[0x4C44], board.mem[0x4C45]);
		bad++;
	}
	L65Regs l = { 0, 0x4C44, 0 };
	if (call("st_load16", &l) != 0)
		return 1;
	if (l.x != 0xBEEF) {
		fprintf(stderr, "selftest: st_load16 read %04X\n", l.x);
		bad++;
	}
	L65Regs rom = { 0, 0x0000, 0 };
	if (call("st_load16", &rom) != 0)
		return 1;
	if (rom.x != (uint16_t)(board.rom[0] | board.rom[1] << 8)) {
		fprintf(stderr, "selftest: ROM word at $0000 read %04X\n", rom.x);
		bad++;
	}

	L65Regs fault = { 0, 0x6000, 0 };
	char err[192];
	unsigned id = lower_find("st_load16");
	if (l65_call(id, &fault, err, sizeof err) == 0) {
		fprintf(stderr, "selftest: a read at the $6000 mirror did not fault\n");
		bad++;
	}

	if (bad) {
		printf("lower: selftest %d failures\n", bad);
		return 1;
	}
	printf("lower: selftest ok\n");
	return 0;
}
