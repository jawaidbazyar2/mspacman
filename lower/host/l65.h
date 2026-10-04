/* The 65816 that runs lower.bin: GSSquared's core on a three-bank map.
 *
 *   bank $00  direct page $0000-$00FF, stack below $0FFF, the call stub
 *   bank $01  the game bank, served by the bus callbacks (the Board)
 *   bank $02  lower.bin, read-only
 */
#ifndef LOWER_L65_H
#define LOWER_L65_H

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

#define L65_GAME_BANK 0x01u
#define L65_CODE_BANK 0x02u
#define L65_STACK_TOP 0x0FFFu
#define L65_STUB      0x0300u
#define L65_DP_SIZE   0x100u

/* WDM signatures. */
#define L65_WDM_RETURN 0x01u  /* back to the host */
#define L65_WDM_FAIL   0x02u  /* sched.c fail(): A holds the reason */

typedef struct L65Regs {
	uint16_t a, x, y;
} L65Regs;

typedef uint8_t (*l65_read_fn)(uint16_t addr, int *fault);
typedef void (*l65_write_fn)(uint16_t addr, uint8_t value, int *fault);

int l65_init(const char *bin_path);
void l65_set_bus(l65_read_fn rd, l65_write_fn wr);
/* Direct-page bytes, for arguments past the registers. */
void l65_poke_dp(uint8_t off, uint8_t value);
uint8_t l65_peek_dp(uint8_t off);
/* Call entry `n` of the table at the start of lower.bin. On return
 * `regs` holds the exit A, X, Y. 0 on a clean return; otherwise `err`
 * says what went wrong. */
int l65_call(unsigned n, L65Regs *regs, char *err, size_t cap);
uint64_t l65_cycles(void);
/* Instruction trace of later calls to `f`; NULL stops tracing. */
void l65_trace(FILE *f);
/* Set when lower.bin ran sched.c fail(): A held the reason, X the
 * detail. Cleared by l65_call. */
int l65_failed(uint8_t *reason, uint16_t *detail);

#ifdef __cplusplus
}
#endif

#endif
