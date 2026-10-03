/* The entry points the host calls each frame. */
#ifndef C_DISPATCH_H
#define C_DISPATCH_H

#include "game.h"

/* One frame: the vertical blank, then the main task list. */
void c_only_frame(Board *b);
/* $234B through the ei at $238C. */
void game_start(Board *b);
/* Drain the task list at $4C82. 0 when it is empty. */
int sched_tasks(Board *b);

#endif
