#!/usr/bin/env python3
"""Build a rook-connected waypoint loop through maze-1 open tiles for the IIgs demo.

Walks build/gfx/maze1_28x31.bin (open = pellet 0x10 / power 0x14), finds a long
simple cycle via DFS, expands it to axis-aligned corner waypoints, and writes
iigs/rails_data.s for Merlin32.

Usage:
  python3 py/gen_ghost_rails.py
  python3 py/gen_ghost_rails.py --maze build/gfx/maze1_28x31.bin --out iigs/rails_data.s
"""

from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MAZE = ROOT / "build" / "gfx" / "maze1_28x31.bin"
DEFAULT_OUT = ROOT / "iigs" / "rails_data.s"
COLS, ROWS = 28, 31
OPEN = {0x10, 0x14}


def load_open(maze: bytes) -> set[tuple[int, int]]:
    if len(maze) != COLS * ROWS:
        raise SystemExit(f"maze: expected {COLS * ROWS} bytes, got {len(maze)}")
    return {
        (x, y)
        for y in range(ROWS)
        for x in range(COLS)
        if maze[y * COLS + x] in OPEN
    }


def neighbors(p: tuple[int, int], open_cells: set[tuple[int, int]]) -> list[tuple[int, int]]:
    x, y = p
    out = []
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        q = (x + dx, y + dy)
        if q in open_cells:
            out.append(q)
    return out


def find_cycle(open_cells: set[tuple[int, int]]) -> list[tuple[int, int]]:
    """DFS for a simple cycle; keep the longest found from a few starts."""
    best: list[tuple[int, int]] = []

    def dfs(start: tuple[int, int], cur: tuple[int, int], path: list[tuple[int, int]], seen: set[tuple[int, int]]) -> None:
        nonlocal best
        for nxt in neighbors(cur, open_cells):
            if nxt == start and len(path) >= 8:
                if len(path) > len(best):
                    best = path[:]
                continue
            if nxt in seen:
                continue
            # Prefer continuing straight when possible (stable corridors)
            seen.add(nxt)
            path.append(nxt)
            dfs(start, nxt, path, seen)
            path.pop()
            seen.remove(nxt)

    # Seed from corridor-like cells (degree 2) first, then others
    seeds = sorted(open_cells, key=lambda p: (len(neighbors(p, open_cells)) != 2, p[1], p[0]))
    for start in seeds[:40]:
        seen = {start}
        dfs(start, start, [start], seen)
        if len(best) >= 60:
            break
    if len(best) < 8:
        raise SystemExit("could not find a usable open-tile cycle")
    return best


def to_waypoints(cycle: list[tuple[int, int]]) -> list[tuple[int, int]]:
    """Keep corners + every cell so rails are rook-connected tile steps.

    Adjacent cycle cells are already 4-neighbors; emit the full cycle as
    waypoints (closed by wrapping). Drop consecutive duplicates only.
    """
    if not cycle:
        return []
    # Ensure closed: last neighbor of first
    path = cycle[:]
    if path[0] in neighbors(path[-1], set(path)) or True:
        # cycle from DFS is a loop of cells; adjacent in list may not be neighbors
        # if DFS order skipped — rebuild by walking unique ordered cycle edges
        pass
    # Re-order into a consecutive neighbor walk starting at path[0]
    ordered = [path[0]]
    remaining = set(path[1:])
    while remaining:
        cur = ordered[-1]
        opts = [n for n in neighbors(cur, remaining | {ordered[0]}) if n in remaining]
        if not opts:
            # jump to any remaining (should not happen for a true cycle)
            ordered.append(remaining.pop())
            continue
        # Prefer cell that keeps us on the cycle set toward closing
        nxt = opts[0]
        for o in opts:
            if o == path[0] and len(remaining) == 1:
                nxt = o
                break
        ordered.append(nxt)
        remaining.discard(nxt)
    # Compact to direction-change corners + endpoints of each straight run
    if len(ordered) < 2:
        return ordered
    wps = [ordered[0]]
    for i in range(1, len(ordered) - 1):
        x0, y0 = ordered[i - 1]
        x1, y1 = ordered[i]
        x2, y2 = ordered[i + 1]
        d1 = (x1 - x0, y1 - y0)
        d2 = (x2 - x1, y2 - y1)
        if d1 != d2:
            wps.append(ordered[i])
    wps.append(ordered[-1])
    # Close: if first/last not equal, append first for wrap target
    if wps[0] != wps[-1]:
        wps.append(wps[0])
    # Expand corners-only back into unit rook steps for 65816 simple stepper
    expanded: list[tuple[int, int]] = [wps[0]]
    for i in range(len(wps) - 1):
        x0, y0 = wps[i]
        x1, y1 = wps[i + 1]
        if x0 != x1 and y0 != y1:
            raise SystemExit(f"non-rook segment {(x0, y0)} -> {(x1, y1)}")
        while (x0, y0) != (x1, y1):
            if x0 < x1:
                x0 += 1
            elif x0 > x1:
                x0 -= 1
            elif y0 < y1:
                y0 += 1
            else:
                y0 -= 1
            expanded.append((x0, y0))
    # Drop final duplicate of start for modular wrap (last == first)
    if len(expanded) > 1 and expanded[0] == expanded[-1]:
        expanded.pop()
    return expanded


def write_rails_asm(path: Path, waypoints: list[tuple[int, int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    n = len(waypoints)
    starts = [0, n // 4, n // 2, (3 * n) // 4]
    lines = [
        "*",
        "* Generated by py/gen_ghost_rails.py - do not edit by hand",
        f"* {n} rook-step waypoints (tile x,y pairs), wraps in 65816",
        "*",
        "",
        f"RAIL_LEN       equ {n}",
        f"RAIL_START0    equ {starts[0]}",
        f"RAIL_START1    equ {starts[1]}",
        f"RAIL_START2    equ {starts[2]}",
        f"RAIL_START3    equ {starts[3]}",
        "",
        "RailPath",
    ]
    row: list[str] = []
    for i, (x, y) in enumerate(waypoints):
        row.append(f"{x},{y}")
        if len(row) == 8 or i == len(waypoints) - 1:
            lines.append("\tdb\t" + ",".join(row))
            row = []
    lines.append("")
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--maze", type=Path, default=DEFAULT_MAZE)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()
    if not args.maze.is_file():
        raise SystemExit(f"missing {args.maze}; run: make maze")
    open_cells = load_open(args.maze.read_bytes())
    cycle = find_cycle(open_cells)
    waypoints = to_waypoints(cycle)
    write_rails_asm(args.out, waypoints)
    print(f"wrote {args.out} ({len(waypoints)} waypoints from cycle len {len(cycle)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
