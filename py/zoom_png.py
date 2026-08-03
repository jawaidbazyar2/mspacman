#!/usr/bin/env python3
"""Crop and nearest-neighbour zoom a PNG, for eyeballing SHR sprite pixels.

The 320x200 captures from py/gs2_render_test.py are too small to judge a 14x12
sprite by eye. This blows a region up without smoothing so individual 4bpp
pixels stay distinguishable.

Usage:
  python3 py/zoom_png.py build/iigs/frame.png out.png --scale 6
  python3 py/zoom_png.py build/iigs/frame.png out.png --rect 90 60 60 40
"""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path


def read_png_rgb(path: Path) -> tuple[int, int, list[list[tuple[int, int, int]]]]:
    """Decode a non-interlaced 8-bit truecolor PNG (what shr_dump_png writes)."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{path}: not a PNG")
    pos = 8
    width = height = 0
    idat = bytearray()
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        tag = data[pos + 4 : pos + 8]
        body = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            width, height, depth, ctype = struct.unpack(">IIBB", body[:10])
            if depth != 8 or ctype != 2:
                raise SystemExit(f"{path}: need 8-bit truecolor, got depth={depth} type={ctype}")
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break

    raw = zlib.decompress(bytes(idat))
    stride = width * 3
    rows: list[list[tuple[int, int, int]]] = []
    prev = bytearray(stride)
    at = 0
    for _ in range(height):
        filt = raw[at]
        line = bytearray(raw[at + 1 : at + 1 + stride])
        at += 1 + stride
        for i in range(stride):
            a = line[i - 3] if i >= 3 else 0
            b = prev[i]
            c = prev[i - 3] if i >= 3 else 0
            if filt == 1:
                line[i] = (line[i] + a) & 0xFF
            elif filt == 2:
                line[i] = (line[i] + b) & 0xFF
            elif filt == 3:
                line[i] = (line[i] + (a + b) // 2) & 0xFF
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
            elif filt != 0:
                raise SystemExit(f"{path}: unsupported filter {filt}")
        rows.append([tuple(line[x * 3 : x * 3 + 3]) for x in range(width)])  # type: ignore[misc]
        prev = line
    return width, height, rows


def _chunk(tag: bytes, body: bytes) -> bytes:
    return (
        struct.pack(">I", len(body))
        + tag
        + body
        + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    )


def write_png_rgb(path: Path, rows: list[list[tuple[int, int, int]]]) -> None:
    height = len(rows)
    width = len(rows[0])
    raw = b"".join(
        b"\x00" + bytes(v for px in row for v in px) for row in rows
    )
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + _chunk(b"IDAT", zlib.compress(raw, 9))
        + _chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("src", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--scale", type=int, default=6)
    ap.add_argument(
        "--rect",
        type=int,
        nargs=4,
        metavar=("X", "Y", "W", "H"),
        help="crop region; default is the whole image",
    )
    args = ap.parse_args()

    width, height, rows = read_png_rgb(args.src)
    x, y, w, h = args.rect if args.rect else (0, 0, width, height)
    x, y = max(0, x), max(0, y)
    w, h = min(w, width - x), min(h, height - y)

    out: list[list[tuple[int, int, int]]] = []
    for ry in range(y, y + h):
        line = [px for rx in range(x, x + w) for px in [rows[ry][rx]] * args.scale]
        out.extend([line] * args.scale)

    write_png_rgb(args.out, out)
    print(f"wrote {args.out} ({w}x{h} @ {args.scale}x = {w * args.scale}x{h * args.scale})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
