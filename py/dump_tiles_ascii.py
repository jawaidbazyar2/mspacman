#!/usr/bin/env python3
"""Dump packed 4bpp tiles/sprites from build/gfx as ASCII art.

Used to confirm HUD glyph tile codes (score digits $00-$09, ASCII text $40-$5B)
survive the arcade 8x8 -> IIgs 6x6 scale, and to pick sprite frames for the HUD
life icons, before wiring them into the side HUD.

Usage:
  python3 py/dump_tiles_ascii.py 0x00-0x09
  python3 py/dump_tiles_ascii.py 0x31 0x48 0x49 --tiles build/gfx/tiles6.bin
  python3 py/dump_tiles_ascii.py 0x2D 0x2F 0x35 --sprites
"""

from __future__ import annotations

import argparse
from pathlib import Path

TILE_H = 6
BYTES_ROW = 3
TILE_BYTES = TILE_H * BYTES_ROW

SPR_H = 12
SPR_BYTES_ROW = 7
SPR_BYTES = SPR_H * SPR_BYTES_ROW

DEFAULT_TILES = Path("build/gfx/tiles6.bin")
DEFAULT_SPRITES = Path("build/gfx/sprites14x12.bin")


def parse_codes(args: list[str]) -> list[int]:
    codes: list[int] = []
    for arg in args:
        if "-" in arg[1:]:
            sep = arg.index("-", 1)
            lo = int(arg[:sep], 0)
            hi = int(arg[sep + 1 :], 0)
            codes.extend(range(lo, hi + 1))
        else:
            codes.append(int(arg, 0))
    return codes


def cell_rows(data: bytes, code: int, height: int, stride: int) -> list[list[int]]:
    base = code * height * stride
    rows = []
    for y in range(height):
        off = base + y * stride
        pens = []
        for b in data[off : off + stride]:
            pens.append(b >> 4)
            pens.append(b & 0x0F)
        rows.append(pens)
    return rows


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("codes", nargs="+", help="tile codes / ranges (e.g. 0x00-0x09)")
    ap.add_argument("--tiles", type=Path, default=DEFAULT_TILES)
    ap.add_argument("--sprites", nargs="?", type=Path, const=DEFAULT_SPRITES,
                    help="dump 14x12 sprite cells instead of 6x6 tiles")
    opts = ap.parse_args()

    if opts.sprites:
        path, height, stride, kind = opts.sprites, SPR_H, SPR_BYTES_ROW, "sprite"
    else:
        path, height, stride, kind = opts.tiles, TILE_H, BYTES_ROW, "tile"

    data = path.read_bytes()
    for code in parse_codes(opts.codes):
        if (code + 1) * height * stride > len(data):
            raise SystemExit(f"{kind} ${code:02X} past end of {path}")
        rows = cell_rows(data, code, height, stride)
        pens = {p for row in rows for p in row}
        print(f"{kind} ${code:02X} ({code})  pens={sorted(pens)}")
        for row in rows:
            print("  " + "".join("." if p == 0 else f"{p:X}" for p in row))
        print()


if __name__ == "__main__":
    main()
