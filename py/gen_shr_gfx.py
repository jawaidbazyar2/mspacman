#!/usr/bin/env python3
"""Decode Pac-Man/Ms. Pac graphics ROMs and emit scaled IIgs SHR assets.

Reads arcade 2bpp tiles (8x8) and sprites (16x16) from 5e/5f, orients them
for upright play (CW then row XOR 3), symmetrically subsamples to 6x6 / 12x12,
packs sprites into masked 14x12 even cells (7 bytes/row), and writes binary +
optional PPM contact sheets for eyeballing.

For orientation checks *before* scaling, use py/preview_tiles_8x8.py.

Usage:
  python3 py/gen_shr_gfx.py
  python3 py/gen_shr_gfx.py --out build/gfx --ppm --zoom 4
  python3 py/gen_shr_gfx.py --tiles-only
"""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TILE_ROM = ROOT / "mspacman-orig" / "5e"
DEFAULT_SPRITE_ROM = ROOT / "mspacman-orig" / "5f"
DEFAULT_COLOR_ROM = ROOT / "mspacman-orig" / "82s123.7f"
DEFAULT_PALETTE_ROM = ROOT / "mspacman-orig" / "82s126.4a"
DEFAULT_OUT = ROOT / "build" / "gfx"

NUM_TILES = 256
NUM_SPRITES = 64
TILE_SRC = 8
TILE_DST = 6
SPRITE_SRC = 16
SPRITE_ART = 12
SPRITE_CELL_W = 14  # 12 art + 2 transparent pad (right)
SPRITE_CELL_H = 12
BYTES_PER_TILE_ROW = TILE_DST // 2  # 3
BYTES_PER_SPRITE_ROW = SPRITE_CELL_W // 2  # 7

# MAME pacman charlayout / spritelayout bit offsets
_TILE_XOFFS = (64, 65, 66, 67, 0, 1, 2, 3)
_TILE_YOFFS = (0, 8, 16, 24, 32, 40, 48, 56)
_SPR_XOFFS = (
    64, 65, 66, 67,
    128, 129, 130, 131,
    192, 193, 194, 195,
    0, 1, 2, 3,
)
_SPR_YOFFS = (
    0, 8, 16, 24, 32, 40, 48, 56,
    256, 264, 272, 280, 288, 296, 304, 312,
)

# Fallback pens if color PROMs missing (PPM only)
_FALLBACK_RGB = (
    (0, 0, 0),
    (255, 0, 0),
    (255, 255, 255),
    (255, 184, 0),
)


def _get_bit(data: bytes, bit_addr: int) -> int:
    return (data[bit_addr >> 3] >> (bit_addr & 7)) & 1


def decode_tile(rom: bytes, index: int) -> list[list[int]]:
    """Decode one 8x8 2bpp tile (pen 0–3) using MAME pacman charlayout."""
    if not 0 <= index < NUM_TILES:
        raise IndexError(index)
    base_bits = index * 16 * 8
    out = [[0] * TILE_SRC for _ in range(TILE_SRC)]
    for y in range(TILE_SRC):
        for x in range(TILE_SRC):
            b0 = base_bits + _TILE_YOFFS[y] + _TILE_XOFFS[x]
            b1 = b0 + 4
            out[y][x] = _get_bit(rom, b0) | (_get_bit(rom, b1) << 1)
    return out


def decode_sprite(rom: bytes, index: int) -> list[list[int]]:
    """Decode one 16x16 2bpp sprite (pen 0–3) using MAME pacman spritelayout."""
    if not 0 <= index < NUM_SPRITES:
        raise IndexError(index)
    base_bits = index * 64 * 8
    out = [[0] * SPRITE_SRC for _ in range(SPRITE_SRC)]
    for y in range(SPRITE_SRC):
        for x in range(SPRITE_SRC):
            b0 = base_bits + _SPR_YOFFS[y] + _SPR_XOFFS[x]
            b1 = b0 + 4
            out[y][x] = _get_bit(rom, b0) | (_get_bit(rom, b1) << 1)
    return out


def rot90_cw(img: list[list[int]]) -> list[list[int]]:
    """Rotate pen map 90° clockwise."""
    n = len(img)
    return [[img[n - 1 - x][y] for x in range(n)] for y in range(n)]


def flip_v(img: list[list[int]]) -> list[list[int]]:
    """Flip pen map vertically (top ↔ bottom)."""
    return img[::-1]


def row_xor3(img: list[list[int]]) -> list[list[int]]:
    """Swap rows within each 4-row half: out[i] = in[i ^ 3].

    Reverses bevel order inside each half without moving ink between halves,
    so two-tile-tall horizontal walls still meet (unlike a full V-flip).
    """
    n = len(img)
    return [img[i ^ 3][:] for i in range(n)]


def upright_tile(img: list[list[int]]) -> list[list[int]]:
    """Cabinet ROM → upright playfield tile.

    90° CW (MAME ROT90), then row XOR 3 so line map is
    0↔3, 1↔2, 4↔7, 5↔6. Do not full-V-flip: that packs horizontal walls
    into opposite halves and opens a black gap through DF/E5 runs.
    """
    return row_xor3(rot90_cw(img))


def area_resample(src: list[list[int]], dst_w: int, dst_h: int) -> list[list[int]]:
    """Coverage-weighted majority vote from src pens onto dst grid."""
    src_h = len(src)
    src_w = len(src[0])
    out = [[0] * dst_w for _ in range(dst_h)]
    for y in range(dst_h):
        y0 = y * src_h / dst_h
        y1 = (y + 1) * src_h / dst_h
        for x in range(dst_w):
            x0 = x * src_w / dst_w
            x1 = (x + 1) * src_w / dst_w
            weights = [0.0, 0.0, 0.0, 0.0]
            sy0 = int(y0)
            sy1 = min(src_h, int(y1) + (0 if y1 == int(y1) else 1))
            sx0 = int(x0)
            sx1 = min(src_w, int(x1) + (0 if x1 == int(x1) else 1))
            for sy in range(sy0, sy1):
                row_lo = max(y0, float(sy))
                row_hi = min(y1, float(sy + 1))
                row_cov = row_hi - row_lo
                if row_cov <= 0:
                    continue
                for sx in range(sx0, sx1):
                    col_lo = max(x0, float(sx))
                    col_hi = min(x1, float(sx + 1))
                    col_cov = col_hi - col_lo
                    if col_cov <= 0:
                        continue
                    weights[src[sy][sx]] += row_cov * col_cov
            out[y][x] = max(range(4), key=lambda p: weights[p])
    return out


# Symmetric 8→6 source indices (i[k] + i[5-k] == 7) so xor-1 H-flips stay matched
# and both edge pixels of thin wall stems survive.
_TILE_SCALE_IDX = (0, 1, 3, 4, 6, 7)
# Symmetric 16→12 for sprites
_SPR_SCALE_IDX = (0, 1, 2, 3, 5, 6, 9, 10, 12, 13, 14, 15)


def subsample_symmetric(src: list[list[int]], idx: tuple[int, ...]) -> list[list[int]]:
    """Nearest subsample with a symmetric index list (preserves edge ink)."""
    return [[src[iy][ix] for ix in idx] for iy in idx]


def make_centered_pellet(size: int = 8) -> list[list[int]]:
    """Upright pellet: 2×2 pen-1 block centered (arcade 0x10 is colon-shaped after ROT90)."""
    out = [[0] * size for _ in range(size)]
    c0 = size // 2 - 1
    for y in range(c0, c0 + 2):
        for x in range(c0, c0 + 2):
            out[y][x] = 1
    return out


def make_power_pill(size: int = 8) -> list[list[int]]:
    """Solid octagon/disc pen-1 (ROM+scale pinches 0x14 into an H/bowtie)."""
    out = [[0] * size for _ in range(size)]
    # Radius-ish fill; works for 8×8 and survives symmetric 8→6 subsample.
    mid = (size - 1) / 2.0
    rad = size * 0.42
    for y in range(size):
        for x in range(size):
            if (x - mid) ** 2 + (y - mid) ** 2 <= rad * rad:
                out[y][x] = 1
    return out


def pad_sprite_14x12(art: list[list[int]]) -> list[list[int]]:
    """Left-align 12x12 art in a 14x12 cell; right two columns transparent (pen 0)."""
    if len(art) != SPRITE_ART or len(art[0]) != SPRITE_ART:
        raise ValueError("expected 12x12 art")
    cell = []
    for row in art:
        cell.append(list(row) + [0, 0])
    return cell


def mask_from_pens(img: list[list[int]]) -> list[list[int]]:
    """Per-pixel mask: 0xF where pen != 0, else 0 (nibble-oriented for packing)."""
    return [[0xF if p else 0 for p in row] for row in img]


def pack_4bpp_rows(img: list[list[int]]) -> bytes:
    """Pack rows as SHR 320 4bpp: high nibble = left pixel, low = right."""
    out = bytearray()
    for row in img:
        if len(row) % 2:
            raise ValueError("row width must be even for 4bpp packing")
        for i in range(0, len(row), 2):
            out.append(((row[i] & 0xF) << 4) | (row[i + 1] & 0xF))
    return bytes(out)


def load_prom_colors(color_rom: Path) -> list[tuple[int, int, int]]:
    """Decode 82s123.7f style RGB (MAME pacman weights) → 16 colors."""
    data = color_rom.read_bytes()
    colors: list[tuple[int, int, int]] = []
    for i in range(16):
        b = data[i] if i < len(data) else 0
        r = ((b >> 0) & 1) * 0x21 + ((b >> 1) & 1) * 0x47 + ((b >> 2) & 1) * 0x97
        g = ((b >> 3) & 1) * 0x21 + ((b >> 4) & 1) * 0x47 + ((b >> 5) & 1) * 0x97
        bl = ((b >> 6) & 1) * 0x51 + ((b >> 7) & 1) * 0xAE
        colors.append((r, g, bl))
    return colors


def load_palette_pens(palette_rom: Path, palette_index: int) -> list[int]:
    """Return 4 color-ROM indices for a hardware palette bank."""
    data = palette_rom.read_bytes()
    base = (palette_index & 63) * 4
    return [data[base + i] & 0x0F for i in range(4)]


def pens_to_rgb_rows(
    img: list[list[int]],
    pen_rgb: list[tuple[int, int, int]],
) -> list[list[tuple[int, int, int]]]:
    return [[pen_rgb[p & 3] for p in row] for row in img]


def write_ppm(
    path: Path,
    pixels: list[list[tuple[int, int, int]]],
    zoom: int = 1,
) -> None:
    """Write binary P6 PPM (optionally nearest-neighbor zoomed)."""
    h = len(pixels)
    w = len(pixels[0]) if h else 0
    zw, zh = w * zoom, h * zoom
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as f:
        f.write(f"P6\n{zw} {zh}\n255\n".encode("ascii"))
        for y in range(zh):
            src_y = y // zoom
            row = pixels[src_y]
            for x in range(zw):
                f.write(struct.pack("BBB", *row[x // zoom]))


def contact_sheet(
    images: list[list[list[int]]],
    pen_rgb: list[tuple[int, int, int]],
    cols: int,
    pad: int = 1,
    pad_rgb: tuple[int, int, int] = (32, 32, 32),
) -> list[list[tuple[int, int, int]]]:
    """Pack images into a padded RGB contact sheet."""
    if not images:
        return []
    th = len(images[0])
    tw = len(images[0][0])
    rows = (len(images) + cols - 1) // cols
    sheet_w = cols * tw + (cols + 1) * pad
    sheet_h = rows * th + (rows + 1) * pad
    sheet = [[pad_rgb for _ in range(sheet_w)] for _ in range(sheet_h)]
    for i, img in enumerate(images):
        r, c = divmod(i, cols)
        y0 = pad + r * (th + pad)
        x0 = pad + c * (tw + pad)
        rgb = pens_to_rgb_rows(img, pen_rgb)
        for y in range(th):
            for x in range(tw):
                sheet[y0 + y][x0 + x] = rgb[y][x]
    return sheet


def default_pen_rgb(
    color_rom: Path | None,
    palette_rom: Path | None,
    palette_index: int,
) -> list[tuple[int, int, int]]:
    if color_rom and color_rom.is_file() and palette_rom and palette_rom.is_file():
        colors = load_prom_colors(color_rom)
        pens = load_palette_pens(palette_rom, palette_index)
        return [colors[p] for p in pens]
    return list(_FALLBACK_RGB)


def generate(
    tile_rom_path: Path,
    sprite_rom_path: Path,
    out_dir: Path,
    *,
    color_rom: Path | None,
    palette_rom: Path | None,
    palette_index: int,
    write_ppm_flag: bool,
    zoom: int,
    tiles_only: bool,
    sprites_only: bool,
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    pen_rgb = default_pen_rgb(color_rom, palette_rom, palette_index)

    tiles8: list[list[list[int]]] = []
    tiles6: list[list[list[int]]] = []
    if not sprites_only:
        tile_rom = tile_rom_path.read_bytes()
        if len(tile_rom) != 4096:
            raise SystemExit(f"{tile_rom_path}: expected 4096 bytes, got {len(tile_rom)}")
        tile_blob = bytearray()
        for i in range(NUM_TILES):
            if i in (0x10, 0x11):
                t8 = make_centered_pellet(TILE_SRC)
            elif i in (0x14, 0x15):
                t8 = make_power_pill(TILE_SRC)
            else:
                t8 = upright_tile(decode_tile(tile_rom, i))
            t6 = subsample_symmetric(t8, _TILE_SCALE_IDX)
            tiles8.append(t8)
            tiles6.append(t6)
            packed = pack_4bpp_rows(t6)
            if len(packed) != TILE_DST * BYTES_PER_TILE_ROW:
                raise RuntimeError("tile pack size mismatch")
            tile_blob.extend(packed)
        (out_dir / "tiles6.bin").write_bytes(tile_blob)
        print(f"wrote {out_dir / 'tiles6.bin'} ({len(tile_blob)} bytes, {NUM_TILES} tiles)")

    sprites16: list[list[list[int]]] = []
    sprites12: list[list[list[int]]] = []
    sprites14: list[list[list[int]]] = []
    if not tiles_only:
        sprite_rom = sprite_rom_path.read_bytes()
        if len(sprite_rom) != 4096:
            raise SystemExit(f"{sprite_rom_path}: expected 4096 bytes, got {len(sprite_rom)}")
        spr_blob = bytearray()
        mask_blob = bytearray()
        for i in range(NUM_SPRITES):
            s16 = rot90_cw(decode_sprite(sprite_rom, i))
            s12 = subsample_symmetric(s16, _SPR_SCALE_IDX)
            s14 = pad_sprite_14x12(s12)
            m14 = mask_from_pens(s14)
            sprites16.append(s16)
            sprites12.append(s12)
            sprites14.append(s14)
            packed = pack_4bpp_rows(s14)
            mpacked = pack_4bpp_rows(m14)
            if len(packed) != SPRITE_CELL_H * BYTES_PER_SPRITE_ROW:
                raise RuntimeError("sprite pack size mismatch")
            spr_blob.extend(packed)
            mask_blob.extend(mpacked)
        (out_dir / "sprites14x12.bin").write_bytes(spr_blob)
        (out_dir / "sprites14x12.mask.bin").write_bytes(mask_blob)
        print(
            f"wrote {out_dir / 'sprites14x12.bin'} "
            f"({len(spr_blob)} bytes, {NUM_SPRITES} even frames)"
        )
        print(f"wrote {out_dir / 'sprites14x12.mask.bin'} ({len(mask_blob)} bytes)")

    if write_ppm_flag:
        ppm_dir = out_dir / "ppm"
        if tiles8:
            write_ppm(
                ppm_dir / "tiles_8x8.ppm",
                contact_sheet(tiles8, pen_rgb, cols=16),
                zoom=zoom,
            )
            write_ppm(
                ppm_dir / "tiles_6x6.ppm",
                contact_sheet(tiles6, pen_rgb, cols=16),
                zoom=zoom,
            )
            print(f"wrote {ppm_dir / 'tiles_8x8.ppm'} and tiles_6x6.ppm (zoom={zoom})")
        if sprites16:
            write_ppm(
                ppm_dir / "sprites_16x16.ppm",
                contact_sheet(sprites16, pen_rgb, cols=8),
                zoom=zoom,
            )
            write_ppm(
                ppm_dir / "sprites_12x12.ppm",
                contact_sheet(sprites12, pen_rgb, cols=8),
                zoom=zoom,
            )
            write_ppm(
                ppm_dir / "sprites_14x12.ppm",
                contact_sheet(sprites14, pen_rgb, cols=8),
                zoom=zoom,
            )
            print(
                f"wrote {ppm_dir / 'sprites_16x16.ppm'}, "
                f"sprites_12x12.ppm, sprites_14x12.ppm (zoom={zoom})"
            )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tiles", type=Path, default=DEFAULT_TILE_ROM, help="path to 5e tile ROM")
    ap.add_argument("--sprites", type=Path, default=DEFAULT_SPRITE_ROM, help="path to 5f sprite ROM")
    ap.add_argument("--color-rom", type=Path, default=DEFAULT_COLOR_ROM, help="82s123.7f for PPM colors")
    ap.add_argument(
        "--palette-rom",
        type=Path,
        default=DEFAULT_PALETTE_ROM,
        help="82s126.4a for PPM pen mapping",
    )
    ap.add_argument(
        "--palette",
        type=int,
        default=0x1D,
        help="hardware palette index for PPM (default 0x1D maze-1)",
    )
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT, help="output directory")
    ap.add_argument("--ppm", action="store_true", help="write PPM contact sheets under out/ppm/")
    ap.add_argument("--zoom", type=int, default=4, help="nearest-neighbor zoom for PPM (default 4)")
    ap.add_argument("--tiles-only", action="store_true")
    ap.add_argument("--sprites-only", action="store_true")
    args = ap.parse_args()
    if args.tiles_only and args.sprites_only:
        raise SystemExit("choose at most one of --tiles-only / --sprites-only")
    if args.zoom < 1:
        raise SystemExit("--zoom must be >= 1")

    generate(
        args.tiles,
        args.sprites,
        args.out,
        color_rom=args.color_rom,
        palette_rom=args.palette_rom,
        palette_index=args.palette,
        write_ppm_flag=args.ppm,
        zoom=args.zoom,
        tiles_only=args.tiles_only,
        sprites_only=args.sprites_only,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
