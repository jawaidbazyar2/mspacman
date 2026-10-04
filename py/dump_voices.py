#!/usr/bin/env python3
"""Print a corpus session's WSG voice registers frame by frame, as the
lowered host's DOC adapter (iigs/lower_sound.s) sees them.

One line per frame where $5001 or any voice's wave, frequency or volume
changes: frame, sound enable, tile/color bytes changed that frame, then
per voice wave/F(hex)/vol and the DOC frequency word D.

Usage:
  python3 py/dump_voices.py corpus/c-play1 [--first N] [--last M] [--tiles K]
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_wave_data import doc_freq  # noqa: E402

FRAME_HDR, FRAME_BYTES = 24, 3176
OFF_LATCH, OFF_VOICE = 42, 50
OFF_TILE, OFF_WORK = 84, 2132  # video and color RAM


def voices(rec: bytes) -> tuple:
    r = [b & 0x0F for b in rec[OFF_VOICE : OFF_VOICE + 32]]
    out = [rec[OFF_LATCH + 1] & 1]
    for v in range(3):
        nib = [r[0x10 + 5 * v + k] for k in range(5)]
        if v:
            nib[0] = 0
        f = sum(n << (4 * k) for k, n in enumerate(nib))
        out.append((r[5 + 5 * v] & 7, f, r[0x15 + 5 * v], doc_freq(nib)))
    return tuple(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("session", type=Path)
    ap.add_argument("--first", type=int, default=0)
    ap.add_argument("--last", type=int, default=-1)
    ap.add_argument("--tiles", type=int, default=0,
                    help="also print frames that change at least this many tile/color bytes")
    ap.add_argument("--stats", action="store_true",
                    help="only print the range of F over audible voice-frames")
    args = ap.parse_args()
    frames = (args.session / "frames").read_bytes()
    (nbytes,) = struct.unpack_from("<I", frames, 8)
    if nbytes != FRAME_BYTES:
        raise SystemExit(f"{args.session}: unexpected record size {nbytes}")
    body = frames[FRAME_HDR:]
    n = len(body) // FRAME_BYTES
    last = n - 1 if args.last < 0 else min(args.last, n - 1)
    if args.stats:
        audible = [(f, v) for i in range(n)
                   for _, f, vol, _ in [x for x in voices(body[i * FRAME_BYTES:(i + 1) * FRAME_BYTES])[1:]]
                   for v in [vol] if vol and f]
        fs = sorted(f for f, _ in audible)
        if fs:
            print(f"{args.session.name}: {len(fs)} audible voice-frames, "
                  f"F min {fs[0]:05X} p1 {fs[len(fs) // 100]:05X} max {fs[-1]:05X}")
        return 0
    prev = None
    prev_vid = None
    for i in range(args.first, last + 1):
        rec = body[i * FRAME_BYTES : (i + 1) * FRAME_BYTES]
        cur = voices(rec)
        vid = rec[OFF_TILE:OFF_WORK]
        cells = 0 if prev_vid is None else sum(a != b for a, b in zip(vid, prev_vid))
        prev_vid = vid
        if cur != prev or (args.tiles and cells >= args.tiles):
            vs = "  ".join(f"w{w} F={f:05X} v{vol:X} D={d:04X}" for w, f, vol, d in cur[1:])
            print(f"{i:6d} on={cur[0]} cells={cells:4d}  {vs}")
            prev = cur
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
