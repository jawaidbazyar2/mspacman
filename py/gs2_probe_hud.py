#!/usr/bin/env python3
"""Run the IIgs harness under GSSquared and check the side-HUD demo state.

Verifies the pieces that a single SHR capture cannot show: BCD score / high
score ticking, lives / level bytes, and how many maze dots Ms. Pac has eaten
out of TILEMAP (compared against the level-1 tilemap asset).

Usage:
  PYTHONPATH=$HOME/src/gssquared/clients/python/src \\
    python3 py/gs2_probe_hud.py --run-seconds 12
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "py"))

from gs2_render_test import (  # noqa: E402
    DEFAULT_BIN,
    DEFAULT_GFX,
    DEFAULT_GS2,
    control_reset,
    inject_assets,
    install_page3_trampoline,
    launch_via_basic,
    spawn_gs2,
)

try:
    from gs2debug import Client, MEM_MAIN
except ImportError as exc:  # pragma: no cover
    raise SystemExit(f"gs2debug missing: {exc}") from exc

TILEMAP = 0x02A000
TILEMAP_LEN = 868
DIRTY_COUNT = 0x02A800
FRAME_COUNT = 0x02A900
SCORE = 0x02A908
PALETTE = 0x019E00

TILE_DOT = 0x10
TILE_POWER = 0x14


def bcd_value(lo: int, mid: int, hi: int) -> int:
    def dig(b: int) -> int:
        return (b >> 4) * 10 + (b & 0x0F)

    return dig(hi) * 10000 + dig(mid) * 100 + dig(lo)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-seconds", type=float, default=12.0)
    ap.add_argument("--gfx", type=Path, default=DEFAULT_GFX)
    ap.add_argument("--seed-score", type=int, default=None,
                    help="poke P1 score (decimal) after launch, to reach the "
                         "high-score rollover without waiting 1000 ticks")
    args = ap.parse_args()

    maze = (args.gfx / "maze1_28x31.bin").read_bytes()
    want_dots = sum(1 for b in maze if b in (TILE_DOT, TILE_POWER))

    sock = "/tmp/gs2-mspacman-hud.sock"
    proc = spawn_gs2(Path(os.environ.get("GSSQUARED", DEFAULT_GS2)), sock)
    try:
        with Client() as client:
            client.connect(sock)
            client.hello()
            time.sleep(5.0)
            control_reset(client)
            time.sleep(2.0)
            client.pause()
            client.wait_stopped(timeout=10.0)
            inject_assets(client, DEFAULT_BIN, args.gfx)
            install_page3_trampoline(client)
            launch_via_basic(client)
            if args.seed_score is not None:
                v = args.seed_score
                bcd = bytes(
                    int(f"{(v // 10 ** (2 * i)) % 100:02d}", 16) for i in range(3)
                )
                client.write_mem(MEM_MAIN, SCORE, bcd)
                print(f"seeded score {v} (BCD {bcd[2]:02X}{bcd[1]:02X}{bcd[0]:02X})")
            print(f"running {args.run_seconds}s…")
            time.sleep(args.run_seconds)
            client.pause()
            try:
                client.wait_stopped(timeout=5.0)
            except TimeoutError:
                print("WARN: no EVT_STOPPED")

            tiles = client.read_mem(MEM_MAIN, TILEMAP, TILEMAP_LEN)
            state = client.read_mem(MEM_MAIN, SCORE, 8)
            frame = client.read_mem(MEM_MAIN, FRAME_COUNT, 2)
            dirty = client.read_mem(MEM_MAIN, DIRTY_COUNT, 2)
            pal = client.read_mem(MEM_MAIN, PALETTE, 32)

            frames = frame[0] | (frame[1] << 8)
            left = sum(1 for b in tiles if b in (TILE_DOT, TILE_POWER))
            score = bcd_value(state[0], state[1], state[2])
            hiscore = bcd_value(state[3], state[4], state[5])

            print(f"frames      {frames}")
            print(f"score       {score} (BCD {state[2]:02X}{state[1]:02X}{state[0]:02X})")
            print(f"high score  {hiscore} (BCD {state[5]:02X}{state[4]:02X}{state[3]:02X})")
            print(f"lives       {state[6]}   level {state[7]}")
            print(f"dots        {left}/{want_dots} left ({want_dots - left} eaten)")
            print(f"dirty count {dirty[0] | (dirty[1] << 8)}")
            pens = [pal[i * 2] | (pal[i * 2 + 1] << 8) for i in range(16)]
            print("palette     " + " ".join(f"{w:04X}" for w in pens))
            client.quit()
        return 0
    finally:
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    raise SystemExit(main())
