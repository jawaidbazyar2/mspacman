#ifndef C_DISPATCH_H
#define C_DISPATCH_H

#include "lift.h"

void c_boot(Board *b, int census);
int c_done(Board *b);
void c_add_lift(uint16_t pc, void (*fn)(Board *b), const char *name);
void lift_call_z80(Board *b, uint16_t target);
void c_host_prove(Board *b);
void c_host_lift(Board *b, uint16_t entry);
void c_host_sentinel(Board *b);
int c_span_pc(uint16_t pc);
int c_boot_pc(uint16_t pc);
int c_boot_inside(Board *b);
int c_sched_pc(uint16_t pc);
int c_sched_inside(Board *b);
int c_run_pc(Board *b);
void c_only_frame(Board *b);
void c_only_power_on(Board *b);

void census_attach(Board *b);
int census_report(Board *b);

#endif
