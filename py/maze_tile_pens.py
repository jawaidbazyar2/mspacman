#!/usr/bin/env python3
"""Which 2bpp pens the maze wall tiles use, across all four maze layouts.

Decodes each maze's walls (#9474 table, gen_maze1's #241F RLE port) from a
mapped ROM image, then reports, for every wall tile code, the pens it uses
in the arcade 8x8 art (5e) and in the IIgs 6x6 art (build/gfx/tiles6.bin).

Usage:
  python3 py/maze_tile_pens.py [--image build/mspac.bin] [--tiles mspacman/5e]
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "py"))

import gen_maze1 as gm  # noqa: E402
import gen_shr_gfx as gg  # noqa: E402

MAZE_TABLE = 0x9474


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--image", type=Path, default=ROOT / "build" / "mspac.bin")
    ap.add_argument("--tiles", type=Path, default=ROOT / "mspacman" / "5e")
    ap.add_argument("--tiles6", type=Path, default=ROOT / "build" / "gfx" / "tiles6.bin")
    args = ap.parse_args()

    rom = bytearray(0x10000)
    data = args.image.read_bytes()
    rom[: len(data)] = data
    t5e = args.tiles.read_bytes()
    t6 = args.tiles6.read_bytes()

    union8: set[int] = set()
    union6: set[int] = set()
    for m in range(4):
        rle = rom[MAZE_TABLE + 2 * m] | rom[MAZE_TABLE + 2 * m + 1] << 8
        vram = bytearray([gm.TILE_EMPTY] * 0x400)
        gm.decode_walls(vram, rom, rle)
        codes = Counter(b for b in vram if b != gm.TILE_EMPTY)
        print(f"maze {m + 1} (RLE ${rle:04X}): {len(codes)} wall tile codes")
        by_pens8: dict[tuple[int, ...], list[int]] = {}
        for code in sorted(codes):
            pens8 = tuple(sorted({p for row in gg.decode_tile(t5e, code) for p in row}))
            raw6 = t6[code * 18 : code * 18 + 18]
            pens6 = {b >> 4 for b in raw6} | {b & 15 for b in raw6}
            union8 |= set(pens8)
            union6 |= pens6
            by_pens8.setdefault(pens8, []).append(code)
        for pens, cs in sorted(by_pens8.items()):
            print(f"  pens {pens}: " + " ".join(f"{c:02X}" for c in cs))
    print(f"all mazes, 8x8 arcade art: pens {sorted(union8)}")
    print(f"all mazes, 6x6 IIgs art:   pens {sorted(union6)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
