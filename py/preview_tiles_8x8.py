#!/usr/bin/env python3
"""Preview maze / tile ROM at 8×8 (and optional 6×6 sheets) to check rotate/flip.

Uses the same MAME decode + orientation helpers as gen_shr_gfx.py, then paints
maze1 at 8×8 and contact sheets at 8×8 / 6×6 with palette #1D colors.
Write PPM + PNG under build/gfx/ppm/ for eyeballing before (or after) scaling.

Usage:
  python3 py/preview_tiles_8x8.py
  python3 py/preview_tiles_8x8.py --orient upright --compare native,cw
  python3 py/preview_tiles_8x8.py --sheet-only
  make tiles-preview
"""

from __future__ import annotations

import argparse
import importlib.util
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "build" / "gfx" / "ppm"
DEFAULT_MAZE = ROOT / "build" / "gfx" / "maze1_28x31.bin"
MAZE_PAL = 0x1D
COLS, ROWS = 28, 31
TILE = 8

ORIENTs = ("native", "cw", "upright", "ccw", "cw_vf", "cw_hf", "180")


def _load_gfx():
    path = ROOT / "py" / "gen_shr_gfx.py"
    spec = importlib.util.spec_from_file_location("gen_shr_gfx", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def _load_palette():
    path = ROOT / "py" / "gen_palette.py"
    spec = importlib.util.spec_from_file_location("gen_palette", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def orient_tile(g, img: list[list[int]], how: str) -> list[list[int]]:
    if how == "native":
        return img
    if how == "cw":
        return g.rot90_cw(img)
    if how == "upright":
        return g.upright_tile(img)  # CW then row XOR 3
    if how == "ccw":
        t = img
        return [[t[x][7 - y] for x in range(8)] for y in range(8)]
    if how == "cw_vf":
        return g.flip_v(g.rot90_cw(img))
    if how == "cw_hf":
        return [row[::-1] for row in g.rot90_cw(img)]
    if how == "180":
        return g.flip_v([row[::-1] for row in img])
    raise SystemExit(f"unknown --orient {how!r}; choose from {ORIENTs}")


def special_tile(g, code: int) -> list[list[int]] | None:
    """Same hand replacements gen_shr_gfx uses (dots / power pills)."""
    if code in (0x10, 0x11):
        return g.make_centered_pellet(8)
    if code in (0x14, 0x15):
        return g.make_power_pill(8)
    return None


def pen_rgb_maze(pal_mod, color_rom: Path, palette_rom: Path) -> list[tuple[int, int, int]]:
    colors = pal_mod.load_prom_colors(color_rom)
    pens = pal_mod.load_palette_pens(palette_rom, MAZE_PAL)
    return [colors[p & 15] for p in pens]


def render_maze(
    tilemap: bytes,
    tiles: list[list[list[int]]],
    pen_rgb: list[tuple[int, int, int]],
) -> list[list[tuple[int, int, int]]]:
    """Paint maze from a tile bank (8×8 or 6×6 — size taken from tiles[0])."""
    th = len(tiles[0])
    tw = len(tiles[0][0])
    w, h = COLS * tw, ROWS * th
    out = [[(0, 0, 0) for _ in range(w)] for _ in range(h)]
    for ty in range(ROWS):
        for tx in range(COLS):
            code = tilemap[ty * COLS + tx]
            tile = tiles[code & 0xFF]
            for y in range(th):
                for x in range(tw):
                    out[ty * th + y][tx * tw + x] = pen_rgb[tile[y][x] & 3]
    return out


def render_sheet(
    tiles: list[list[list[int]]],
    pen_rgb: list[tuple[int, int, int]],
    cols: int = 16,
    pad: int = 1,
) -> list[list[tuple[int, int, int]]]:
    th = len(tiles[0])
    tw = len(tiles[0][0])
    rows = (len(tiles) + cols - 1) // cols
    pad_rgb = (40, 40, 40)
    sw = cols * tw + (cols + 1) * pad
    sh = rows * th + (rows + 1) * pad
    sheet = [[pad_rgb for _ in range(sw)] for _ in range(sh)]
    for i, tile in enumerate(tiles):
        r, c = divmod(i, cols)
        y0 = pad + r * (th + pad)
        x0 = pad + c * (tw + pad)
        for y in range(th):
            for x in range(tw):
                sheet[y0 + y][x0 + x] = pen_rgb[tile[y][x] & 3]
    return sheet


def scale_bank_6(g, bank8: list[list[list[int]]]) -> list[list[list[int]]]:
    """Same 8→6 symmetric subsample as gen_shr_gfx production tiles."""
    return [g.subsample_symmetric(t, g._TILE_SCALE_IDX) for t in bank8]


def write_ppm(path: Path, pixels: list[list[tuple[int, int, int]]], zoom: int = 1) -> None:
    h = len(pixels)
    w = len(pixels[0]) if h else 0
    zw, zh = w * zoom, h * zoom
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as f:
        f.write(f"P6\n{zw} {zh}\n255\n".encode("ascii"))
        for y in range(zh):
            row = pixels[y // zoom]
            for x in range(zw):
                f.write(struct.pack("BBB", *row[x // zoom]))


def write_png(path: Path, pixels: list[list[tuple[int, int, int]]], zoom: int = 1) -> None:
    """Minimal RGB PNG (no deps) via zlib."""
    h = len(pixels)
    w = len(pixels[0]) if h else 0
    zw, zh = w * zoom, h * zoom
    raw = bytearray()
    for y in range(zh):
        raw.append(0)
        row = pixels[y // zoom]
        for x in range(zw):
            raw.extend(row[x // zoom])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", zw, zh, 8, 2, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def build_tile_bank(g, rom: bytes, how: str, *, use_specials: bool) -> list[list[list[int]]]:
    bank: list[list[list[int]]] = []
    for i in range(256):
        special = special_tile(g, i) if use_specials else None
        if special is not None:
            bank.append(special)
        else:
            bank.append(orient_tile(g, g.decode_tile(rom, i), how))
    return bank


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tiles", type=Path, default=ROOT / "mspacman-orig" / "5e")
    ap.add_argument("--maze", type=Path, default=DEFAULT_MAZE)
    ap.add_argument("--color-rom", type=Path, default=ROOT / "mspacman-orig" / "82s123.7f")
    ap.add_argument("--palette-rom", type=Path, default=ROOT / "mspacman-orig" / "82s126.4a")
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument(
        "--orient",
        default="upright",
        choices=ORIENTs,
        help="orientation applied to ROM tiles (default: upright = production CW+row^3)",
    )
    ap.add_argument(
        "--compare",
        default="",
        help="comma-separated orients to also emit (e.g. native,cw,upright)",
    )
    ap.add_argument("--zoom", type=int, default=2, help="nearest-neighbor zoom (default 2)")
    ap.add_argument("--sheet-only", action="store_true", help="skip maze render")
    ap.add_argument("--maze-only", action="store_true", help="skip contact sheet")
    ap.add_argument(
        "--no-6x6",
        action="store_true",
        help="skip 6×6 maze + contact sheets (8×8 still written)",
    )
    ap.add_argument(
        "--no-specials",
        action="store_true",
        help="do not substitute hand-made dot/power-pill tiles",
    )
    args = ap.parse_args()
    if args.zoom < 1:
        raise SystemExit("--zoom must be >= 1")

    g = _load_gfx()
    pal = _load_palette()
    rom = args.tiles.read_bytes()
    if len(rom) != 4096:
        raise SystemExit(f"{args.tiles}: expected 4096 bytes")
    pen_rgb = pen_rgb_maze(pal, args.color_rom, args.palette_rom)
    use_specials = not args.no_specials

    orients = [args.orient]
    if args.compare.strip():
        for part in args.compare.split(","):
            part = part.strip()
            if part and part not in orients:
                if part not in ORIENTs:
                    raise SystemExit(f"unknown compare orient {part!r}")
                orients.append(part)

    if not args.sheet_only and not args.maze.is_file():
        raise SystemExit(f"missing {args.maze}; run: make maze")

    maze_bytes = args.maze.read_bytes() if not args.sheet_only else b""
    if maze_bytes and len(maze_bytes) != COLS * ROWS:
        raise SystemExit(f"{args.maze}: expected {COLS * ROWS} bytes")

    for how in orients:
        bank = build_tile_bank(g, rom, how, use_specials=use_specials)
        tag = how
        if not args.maze_only:
            sheet = render_sheet(bank, pen_rgb)
            ppm = args.out / f"tiles_8x8_{tag}.ppm"
            png = args.out / f"tiles_8x8_{tag}.png"
            write_ppm(ppm, sheet, zoom=args.zoom)
            write_png(png, sheet, zoom=args.zoom)
            print(f"wrote {ppm} and {png.name}")
            if not args.no_6x6:
                bank6 = scale_bank_6(g, bank)
                sheet6 = render_sheet(bank6, pen_rgb)
                ppm6 = args.out / f"tiles_6x6_{tag}.ppm"
                png6 = args.out / f"tiles_6x6_{tag}.png"
                write_ppm(ppm6, sheet6, zoom=args.zoom)
                write_png(png6, sheet6, zoom=args.zoom)
                print(f"wrote {ppm6} and {png6.name}")
        if not args.sheet_only:
            maze_px = render_maze(maze_bytes, bank, pen_rgb)
            ppm = args.out / f"maze1_8x8_{tag}.ppm"
            png = args.out / f"maze1_8x8_{tag}.png"
            write_ppm(ppm, maze_px, zoom=args.zoom)
            write_png(png, maze_px, zoom=args.zoom)
            print(f"wrote {ppm} and {png.name}")
            if not args.no_6x6:
                bank6 = scale_bank_6(g, bank)
                maze6 = render_maze(maze_bytes, bank6, pen_rgb)
                ppm6 = args.out / f"maze1_6x6_{tag}.ppm"
                png6 = args.out / f"maze1_6x6_{tag}.png"
                write_ppm(ppm6, maze6, zoom=args.zoom)
                write_png(png6, maze6, zoom=args.zoom)
                print(f"wrote {ppm6} and {png6.name}")

    print(f"orients={orients} specials={use_specials} zoom={args.zoom}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
