#!/usr/bin/env python3
"""Convert an IIgs SHR 320x200 4bpp framebuffer (+ palette) to a PNG.

Usage:
  python3 py/shr_dump_png.py pixels.bin palette.bin out.png
  # or as a library: shr_to_png(pixels, palette_words) -> bytes PNG
"""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path

WIDTH = 320
HEIGHT = 200
PIXEL_BYTES = WIDTH * HEIGHT // 2  # 32000
PALETTE_BYTES = 32  # 16 × 16-bit


def shr_color_to_rgb(word: int) -> tuple[int, int, int]:
    """IIgs SHR 12-bit color $0RGB: bits 0–3 Blue, 4–7 Green, 8–11 Red."""
    b = (word & 0x0F) * 17
    g = ((word >> 4) & 0x0F) * 17
    r = ((word >> 8) & 0x0F) * 17
    return r, g, b


def decode_palette(pal: bytes) -> list[tuple[int, int, int]]:
    if len(pal) < PALETTE_BYTES:
        raise ValueError(f"palette needs {PALETTE_BYTES} bytes, got {len(pal)}")
    out: list[tuple[int, int, int]] = []
    for i in range(16):
        w = pal[i * 2] | (pal[i * 2 + 1] << 8)
        out.append(shr_color_to_rgb(w))
    return out


def pixels_to_rgb(pixels: bytes, palette: list[tuple[int, int, int]]) -> bytes:
    if len(pixels) < PIXEL_BYTES:
        raise ValueError(f"pixels need {PIXEL_BYTES} bytes, got {len(pixels)}")
    rows: list[bytes] = []
    for y in range(HEIGHT):
        row = bytearray()
        base = y * (WIDTH // 2)
        for x in range(0, WIDTH, 2):
            b = pixels[base + x // 2]
            hi = (b >> 4) & 0x0F
            lo = b & 0x0F
            row.extend(palette[hi])
            row.extend(palette[lo])
        rows.append(b"\x00" + bytes(row))  # filter none
    return b"".join(rows)


def _chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(
        ">I", zlib.crc32(tag + data) & 0xFFFFFFFF
    )


def shr_to_png(pixels: bytes, palette: bytes) -> bytes:
    rgb_pal = decode_palette(palette)
    raw = pixels_to_rgb(pixels, rgb_pal)
    ihdr = struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(raw, 9))
        + _chunk(b"IEND", b"")
    )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("pixels", type=Path)
    ap.add_argument("palette", type=Path)
    ap.add_argument("out", type=Path)
    args = ap.parse_args()
    png = shr_to_png(args.pixels.read_bytes(), args.palette.read_bytes())
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(png)
    print(f"wrote {args.out} ({len(png)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
