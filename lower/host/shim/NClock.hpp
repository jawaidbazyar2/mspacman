/* Stand-in for GSSquared's NClock: the 65816 core only counts cycles. */
#pragma once

#include <cstdint>

class NClock {
	uint64_t cycles_ = 0;

public:
	uint64_t get_cycles() { return cycles_; }
	void incr_cycles() { ++cycles_; }
};
