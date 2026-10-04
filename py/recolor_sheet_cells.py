#!/usr/bin/env python3
"""Swap one pen color for another inside chosen cells of a cleaned contact sheet.

Works on the --from-ppm sheets read by py/gen_shr_gfx.py (zoom 4, 1-pixel
gutters, pens drawn black / red / white / amber = 0 / 1 / 2 / 3). Only the
named cells change; gutters and every other cell are left as they are.

Usage:
  python3 py/recolor_sheet_cells.py assets/tiles_6x6_clean.ppm --cells 14,15 --from 2 --to 1
  python3 py/recolor_sheet_cells.py SHEET --cells 14,15 --from 2 --to 1 --sprites
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "py"))

import gen_shr_gfx as gg  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("sheet", type=Path)
    ap.add_argument("--cells", required=True, help="comma-separated hex cell codes")
    ap.add_argument("--from", dest="src", type=int, required=True, help="pen to replace (0-3)")
    ap.add_argument("--to", dest="dst", type=int, required=True, help="new pen (0-3)")
    ap.add_argument("--sprites", action="store_true", help="sprite sheet layout (14x12, 8 columns)")
    args = ap.parse_args()

    if args.sprites:
        count, cols, cw, ch = gg.NUM_SPRITES, 8, gg.SPRITE_CELL_W, gg.SPRITE_CELL_H
    else:
        count, cols, cw, ch = gg.NUM_TILES, 16, gg.TILE_DST, gg.TILE_DST
    gg.read_contact_sheet(args.sheet, count, cols, cw, ch)  # validates the layout

    data = bytearray(args.sheet.read_bytes())
    w, h, pix = gg.read_ppm(args.sheet)
    base = len(data) - w * h * 3
    src_rgb = bytes(gg._FALLBACK_RGB[args.src])
    dst_rgb = bytes(gg._FALLBACK_RGB[args.dst])
    zoom, pad = gg.CLEAN_ZOOM, gg.CLEAN_PAD

    changed = 0
    for code in (int(c, 16) for c in args.cells.split(",")):
        r, c = divmod(code, cols)
        y0 = (pad + r * (ch + pad)) * zoom
        x0 = (pad + c * (cw + pad)) * zoom
        for y in range(y0, y0 + ch * zoom):
            for x in range(x0, x0 + cw * zoom):
                o = base + (y * w + x) * 3
                if data[o : o + 3] == src_rgb:
                    data[o : o + 3] = dst_rgb
                    changed += 1
    args.sheet.write_bytes(data)
    print(f"{args.sheet}: {changed // (zoom * zoom)} pixels pen {args.src} -> {args.dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
