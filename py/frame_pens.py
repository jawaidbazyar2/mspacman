#!/usr/bin/env python3
"""Map a captured SHR frame PNG back to palette pen indices and print a region.

py/gs2_render_test.py writes RGB; when something unexpected lands on screen it
is much easier to debug in pen space (which asset drew it) than in RGB.

Usage:
  python3 py/frame_pens.py build/iigs/frame.png --rect 0 0 76 60
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

DEFAULT_PALETTE = Path("build/gfx/palette.bin")


def load_palette(path: Path) -> list[tuple[int, int, int]]:
    data = path.read_bytes()
    pens = []
    for i in range(16):
        word = data[i * 2] | (data[i * 2 + 1] << 8)
        r = (word >> 8) & 0xF
        g = (word >> 4) & 0xF
        b = word & 0xF
        pens.append((r * 17, g * 17, b * 17))
    return pens


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("src", type=Path)
    ap.add_argument("--palette", type=Path, default=DEFAULT_PALETTE)
    ap.add_argument("--rect", nargs=4, type=int, metavar=("X", "Y", "W", "H"),
                    default=[0, 0, 320, 200])
    opts = ap.parse_args()

    pens = load_palette(opts.palette)
    img = Image.open(opts.src).convert("RGB")
    x0, y0, w, h = opts.rect

    counts: dict[int, int] = {}
    print("     " + "".join(f"{(x0 + x) % 10}" for x in range(w)))
    for y in range(y0, y0 + h):
        row = []
        for x in range(x0, x0 + w):
            rgb = img.getpixel((x, y))
            pen = pens.index(rgb) if rgb in pens else -1
            counts[pen] = counts.get(pen, 0) + 1
            row.append("." if pen == 0 else ("?" if pen < 0 else f"{pen:X}"))
        print(f"{y:4d} " + "".join(row))

    print("\npen counts (pen: pixels)")
    for pen, n in sorted(counts.items()):
        rgb = pens[pen] if pen >= 0 else None
        print(f"  {pen:>2}: {n:6d}  {rgb}")


if __name__ == "__main__":
    main()
