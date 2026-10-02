#include "lift.h"

#include <SDL3/SDL.h>

void input_poll(Board *b)
{
	if (b->corpus.replaying)
		return;
	const bool *keys = SDL_GetKeyboardState(NULL);
	uint8_t in0 = 0;
	uint8_t in1 = 0;
	if (keys[SDL_SCANCODE_KP_8])
		in0 |= 0x01;
	if (keys[SDL_SCANCODE_KP_4])
		in0 |= 0x02;
	if (keys[SDL_SCANCODE_KP_6])
		in0 |= 0x04;
	if (keys[SDL_SCANCODE_KP_2])
		in0 |= 0x08;
	if (keys[SDL_SCANCODE_KP_0])
		in0 |= 0x20;
	if (keys[SDL_SCANCODE_KP_ENTER])
		in1 |= 0x20;
	b->input.clear_in0 = in0;
	b->input.clear_in1 = in1;
}
