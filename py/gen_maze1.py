#!/usr/bin/env python3
"""Decode Ms. Pac-Man maze 1 into an upright 28x31 tilemap for the IIgs harness.

Replays the Z80 wall RLE decoder (#241F), horizontal mirror, pellet offset walk
(#2453 with FF bitmap), and power-pill pokes (#94EC / #8B35) against a synthetic
VRAM image built from golden boot ROMs, then remaps Pac-Man VRAM to a row-major
28x31 maze-only grid.

When build/gfx/tiles6.bin is present, also writes maze1_cells.bin — per-cell 6×6
4bpp graphics with shared-edge stitching so thin wall stems meet at corners.

Usage:
  python3 py/gen_maze1.py
  python3 py/gen_maze1.py --out build/gfx --ppm
"""

from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "build" / "gfx"
BOOTS = [ROOT / f"boot{i}" for i in range(1, 7)]

MAZE1_RLE = 0x88C1
MAZE1_PELLETS = 0x8A3B
MAZE1_POWER = 0x8B35

TILE_EMPTY = 0x40
TILE_DOT = 0x10
TILE_POWER = 0x14
MAZE_COLOR = 0x1D

COLS = 28
ROWS_MID = 32
ROWS_OUT = 31  # IIgs design: maze-only 28x31
TILE_W = 6
TILE_BYTES = 18  # 6 rows × 3 bytes


def load_rom_image() -> bytearray:
    """Map boot1..boot6 into a 64K image (4000-7FFF gap left zero)."""
    img = bytearray(0x10000)
    for i, path in enumerate(BOOTS):
        data = path.read_bytes()
        if len(data) != 0x1000:
            raise SystemExit(f"{path}: expected 4096 bytes, got {len(data)}")
        base = i * 0x1000 if i < 4 else 0x8000 + (i - 4) * 0x1000
        img[base : base + 0x1000] = data
    return img


def decode_walls(vram: bytearray, rom: bytes, rle_addr: int) -> None:
    """Port of #241F wall RLE + horizontal mirror."""
    hl = 0x4000
    bc = rle_addr
    while True:
        a = rom[bc]
        if a == 0:
            return
        if a < 0x80:
            hl = (hl + a - 1) & 0xFFFF
            bc = (bc + 1) & 0xFFFF
            a = rom[bc]
        hl = (hl + 1) & 0xFFFF
        vram[hl - 0x4000] = a
        # mirror: HL' = #83E0 + 2*(L & #1F) - HL; tile ^= 1
        low = hl & 0x1F
        mirror = (0x83E0 + (low * 2) - hl) & 0xFFFF
        vram[mirror - 0x4000] = a ^ 0x01
        bc = (bc + 1) & 0xFFFF


def draw_dots(vram: bytearray, rom: bytes, pellet_addr: int) -> None:
    """Port of #2453 with pill_bitmap all FF (task #12 init)."""
    hl = 0x4000
    iy = pellet_addr
    for _ in range(0x1E):
        a = 0xFF
        for _bit in range(8):
            e = rom[iy]
            iy += 1
            hl = (hl + e) & 0xFFFF
            carry = (a & 0x80) != 0
            a = ((a << 1) | (1 if carry else 0)) & 0xFF  # rlca
            if carry:
                vram[hl - 0x4000] = TILE_DOT


def draw_power_pills(vram: bytearray, rom: bytes, table_addr: int) -> None:
    """Port of #94F7 — four little-endian VRAM addresses, tile #14."""
    for i in range(4):
        addr = rom[table_addr + i * 2] | (rom[table_addr + i * 2 + 1] << 8)
        vram[addr - 0x4000] = TILE_POWER


def vram_mid_to_xy(off: int) -> tuple[int, int] | None:
    """Map VRAM offset 0x40..0x3BF → upright (x, y) in the 28x32 middle."""
    if not 0x40 <= off < 0x3C0:
        return None
    col_from_right = (off - 0x40) // 32
    row = (off - 0x40) % 32
    x = 27 - col_from_right
    return x, row


def extract_28x31(vram: bytearray) -> bytes:
    """Upright row-major 28x31 from middle playfield (32 VRAM rows).

    Drop the empty top middle row (y=0: FD/FC padding) and keep y=1..31 so the
    bottom border (D5/DD/DC/D4) is included. Older extract kept y=0..30 and
    clipped the bottom edge while leaving a blank strip at the top.
    """
    grid = [[TILE_EMPTY] * COLS for _ in range(ROWS_OUT)]
    for off in range(0x40, 0x3C0):
        xy = vram_mid_to_xy(off)
        if xy is None:
            continue
        x, y = xy
        y_out = y - 1  # skip empty VRAM row 0
        if not 0 <= y_out < ROWS_OUT:
            continue
        grid[y_out][x] = vram[off]
    out = bytearray()
    for y in range(ROWS_OUT):
        out.extend(grid[y])
    return bytes(out)


def unpack_tile6(blob: bytes, code: int) -> list[list[int]]:
    """Unpack one 6×6 4bpp tile (3 bytes/row) to pen grid."""
    base = (code & 0xFF) * TILE_BYTES
    if base + TILE_BYTES > len(blob):
        raise IndexError(code)
    out = [[0] * TILE_W for _ in range(TILE_W)]
    for y in range(TILE_W):
        row = blob[base + y * 3 : base + y * 3 + 3]
        pens: list[int] = []
        for b in row:
            pens.append((b >> 4) & 0xF)
            pens.append(b & 0xF)
        out[y] = pens
    return out


def pack_tile6(img: list[list[int]]) -> bytes:
    out = bytearray()
    for y in range(TILE_W):
        for x in range(0, TILE_W, 2):
            out.append(((img[y][x] & 0xF) << 4) | (img[y][x + 1] & 0xF))
    return bytes(out)


def stitch_maze_cells(tilemap: bytes, tiles6: bytes) -> bytes:
    """Per-cell copies of tiles6 with neighbor edge repair (thin-line joins)."""
    grid = [
        [unpack_tile6(tiles6, tilemap[y * COLS + x]) for x in range(COLS)]
        for y in range(ROWS_OUT)
    ]
    # Vertical edges: bottom of (x,y) ↔ top of (x,y+1)
    for y in range(ROWS_OUT - 1):
        for x in range(COLS):
            for xx in range(TILE_W):
                a = grid[y][x][TILE_W - 1][xx]
                b = grid[y + 1][x][0][xx]
                if a != b:
                    m = a or b if (a == 0 or b == 0) else max(a, b)
                    grid[y][x][TILE_W - 1][xx] = m
                    grid[y + 1][x][0][xx] = m
    # Horizontal edges: right of (x,y) ↔ left of (x+1,y)
    for y in range(ROWS_OUT):
        for x in range(COLS - 1):
            for yy in range(TILE_W):
                a = grid[y][x][yy][TILE_W - 1]
                b = grid[y][x + 1][yy][0]
                if a != b:
                    m = a or b if (a == 0 or b == 0) else max(a, b)
                    grid[y][x][yy][TILE_W - 1] = m
                    grid[y][x + 1][yy][0] = m
    out = bytearray()
    for y in range(ROWS_OUT):
        for x in range(COLS):
            out.extend(pack_tile6(grid[y][x]))
    return bytes(out)


def write_ppm(path: Path, tiles: bytes, zoom: int = 8) -> None:
    """Tiny ASCII-ish color preview (tile code → gray / blue / yellow)."""
    w, h = COLS * zoom, ROWS_OUT * zoom
    rows: list[bytes] = []
    for y in range(ROWS_OUT):
        for _zy in range(zoom):
            line = bytearray()
            for x in range(COLS):
                t = tiles[y * COLS + x]
                if t == TILE_EMPTY:
                    rgb = (0, 0, 0)
                elif t == TILE_DOT:
                    rgb = (255, 184, 174)
                elif t == TILE_POWER:
                    rgb = (255, 255, 255)
                elif t >= 0xC0:
                    rgb = (33, 33, 222)  # wall-ish
                else:
                    rgb = (80, 80, 80)
                line.extend(bytes(rgb) * zoom)
            rows.append(bytes(line))
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as f:
        f.write(f"P6\n{w} {h}\n255\n".encode())
        f.write(b"".join(rows))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--ppm", action="store_true", help="write maze1_28x31.ppm preview")
    ap.add_argument("--zoom", type=int, default=8)
    args = ap.parse_args()

    for p in BOOTS:
        if not p.is_file():
            raise SystemExit(f"missing golden ROM {p}")

    rom = load_rom_image()
    vram = bytearray([TILE_EMPTY] * 0x400)
    decode_walls(vram, rom, MAZE1_RLE)
    draw_dots(vram, rom, MAZE1_PELLETS)
    draw_power_pills(vram, rom, MAZE1_POWER)
    tiles = extract_28x31(vram)
    colors = bytes([MAZE_COLOR] * (COLS * ROWS_OUT))

    args.out.mkdir(parents=True, exist_ok=True)
    tile_path = args.out / "maze1_28x31.bin"
    color_path = args.out / "maze1_color.bin"
    tile_path.write_bytes(tiles)
    color_path.write_bytes(colors)
    print(f"wrote {tile_path} ({len(tiles)} bytes, {COLS}x{ROWS_OUT})")
    print(f"wrote {color_path} ({len(colors)} bytes, color #{MAZE_COLOR:02X})")

    dots = sum(1 for b in tiles if b == TILE_DOT)
    powers = sum(1 for b in tiles if b == TILE_POWER)
    walls = sum(1 for b in tiles if b not in (TILE_EMPTY, TILE_DOT, TILE_POWER))
    print(f"stats: walls={walls} dots={dots} power={powers}")

    tiles6_path = args.out / "tiles6.bin"
    if tiles6_path.is_file():
        cells = stitch_maze_cells(tiles, tiles6_path.read_bytes())
        cells_path = args.out / "maze1_cells.bin"
        cells_path.write_bytes(cells)
        print(f"wrote {cells_path} ({len(cells)} bytes, stitched 6x6 cells)")
    else:
        print(f"note: {tiles6_path} missing — skip maze1_cells.bin (run make gfx first)")

    if args.ppm:
        ppm = args.out / "ppm" / "maze1_28x31.ppm"
        write_ppm(ppm, tiles, zoom=args.zoom)
        print(f"wrote {ppm}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
