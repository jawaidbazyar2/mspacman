#!/usr/bin/env python3
"""Summarize 65816 cycles per frame from `make lower-only-check`.

The log has one line per frame: session, frame number, cycles. Prints the
mean, the 99th percentile, and the max per session and over the corpus,
the share of frames past the IIgs budget, and the worst frames.

Usage:
  python3 py/lower_cycles.py build/lower/frame_cycles.txt [--budget N] [--worst N]
"""

from __future__ import annotations

import argparse
import sys
from collections import defaultdict
from pathlib import Path

# 2.8 MHz over a 60 Hz frame, before slow-RAM and refresh stalls.
DEFAULT_BUDGET = 2_800_000 // 60


def stats(values: list[int]) -> tuple[int, int, int]:
    s = sorted(values)
    return sum(s) // len(s), s[(len(s) * 99) // 100], s[-1]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("log", type=Path)
    ap.add_argument("--budget", type=int, default=DEFAULT_BUDGET)
    ap.add_argument("--worst", type=int, default=5)
    args = ap.parse_args()

    if not args.log.exists():
        print(f"lower_cycles: no log at {args.log}", file=sys.stderr)
        return 1
    by_session: dict[str, list[int]] = defaultdict(list)
    rows: list[tuple[int, str, int]] = []
    for line in args.log.read_text().splitlines():
        session, frame, cycles = line.split()
        name = Path(session).name
        by_session[name].append(int(cycles))
        rows.append((int(cycles), name, int(frame)))
    if not rows:
        print("lower_cycles: empty log", file=sys.stderr)
        return 1

    print(f"{'session':<16} {'frames':>8} {'mean':>8} {'99th':>8} {'max':>8} {'over':>6}")
    for name in sorted(by_session):
        v = by_session[name]
        mean, p99, mx = stats(v)
        over = sum(1 for c in v if c > args.budget)
        print(f"{name:<16} {len(v):>8} {mean:>8} {p99:>8} {mx:>8} {over:>6}")
    allv = [r[0] for r in rows]
    mean, p99, mx = stats(allv)
    over = sum(1 for c in allv if c > args.budget)
    print(f"{'corpus':<16} {len(allv):>8} {mean:>8} {p99:>8} {mx:>8} {over:>6}")
    print(f"budget {args.budget} cycles per frame; {100.0 * over / len(allv):.2f}% of frames over")
    print("worst frames:")
    for cycles, name, frame in sorted(rows, reverse=True)[: args.worst]:
        print(f"  {name} frame {frame}: {cycles}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
