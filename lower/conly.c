/* The frame loop for replay. */
#include "dispatch.h"

/* One frame: the vertical blank, then the task list until it is empty.
 * The self-test is not run; power-on and the service switch go straight
 * to game_start. Neither happens in the corpus, which starts from a
 * running snapshot. */
void c_only_frame(Board *b)
{
	LOWER_HOOK(c_only_frame, b);
	if (b->started && b->latch[0] && b->int_enabled) {
		vblank(b);
		if (b->restart) {
			b->restart = 0;
			game_start(b);
			return;
		}
	}
	if (!b->started)
		game_start(b);
	if (sched_tasks(b) != 0)
		return;
	b->stop = 1;
}
