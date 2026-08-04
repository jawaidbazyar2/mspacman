#!/usr/bin/env python3
"""Probe ghost chase/scatter state in game.bin after N seconds.

Usage (repo root):
  PYTHONPATH=$HOME/src/gssquared/clients/python/src \\
    python3 py/gs2_probe_ghost_chase.py [--seconds 10]
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GS2_PY = Path(
    os.environ.get(
        "GS2_PY",
        Path.home() / "src" / "gssquared" / "clients" / "python" / "src",
    )
)
sys.path.insert(0, str(GS2_PY))
sys.path.insert(0, str(ROOT / "py"))

from gs2debug import MEM_MAIN, PLATFORM_APPLE_IIGS, Client  # noqa: E402
from gs2_render_test import (  # noqa: E402
    DEFAULT_GS2,
    control_reset,
    inject_assets,
    install_page3_trampoline,
    launch_via_basic,
    spawn_gs2,
)

FRAME_COUNT = 0x028900
LEVEL_STATE = 0x028564
POWER_PILL_ACT = 0x028506
GHOST_ORIENT_IDX = 0x028521
GHOST_ORIENT_CNT = 0x028522
GHOST_ORIENT_TBL = 0x0284E6
PAC_TILE_Y, PAC_TILE_X = 0x028499, 0x02849A
RED_TILE_Y, RED_TILE_X = 0x02846A, 0x02846B
RED_DIR = 0x02848C
RED_FRIGHT = 0x028507
RED_SUBSTATE = 0x028500
RED_REVERSE = 0x028511
PATH_DST_Y, PATH_DST_X = 0x0284A0, 0x0284A1


def u8(client: Client, addr: int) -> int:
    return client.read_mem(MEM_MAIN, addr, 1)[0]


def u16(client: Client, addr: int) -> int:
    b = client.read_mem(MEM_MAIN, addr, 2)
    return b[0] | (b[1] << 8)


def dump(client: Client, label: str) -> None:
    idx = u8(client, GHOST_ORIENT_IDX)
    cnt = u16(client, GHOST_ORIENT_CNT)
    thr0 = u16(client, GHOST_ORIENT_TBL)
    mode = "chase" if (idx & 1) else "scatter"
    print(
        f"{label}: frame={u16(client, FRAME_COUNT)} "
        f"level_state={u8(client, LEVEL_STATE)} "
        f"power={u8(client, POWER_PILL_ACT)} "
        f"orient_idx={idx} ({mode}) cnt=${cnt:04X} thr0=${thr0:04X}"
    )
    print(
        f"  pac_tile=({u8(client, PAC_TILE_Y):02X},{u8(client, PAC_TILE_X):02X}) "
        f"red_tile=({u8(client, RED_TILE_Y):02X},{u8(client, RED_TILE_X):02X}) "
        f"red_dir={u8(client, RED_DIR)} fright={u8(client, RED_FRIGHT)} "
        f"sub={u8(client, RED_SUBSTATE)} rev={u8(client, RED_REVERSE)} "
        f"path_dst=({u8(client, PATH_DST_Y):02X},{u8(client, PATH_DST_X):02X})"
    )
    tbl = client.read_mem(MEM_MAIN, GHOST_ORIENT_TBL, 14)
    words = [tbl[i] | (tbl[i + 1] << 8) for i in range(0, 14, 2)]
    print("  orient_tbl:", " ".join(f"${w:04X}" for w in words))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--seconds", type=float, default=10.0)
    args = ap.parse_args()

    bin_path = ROOT / "build/iigs/game.bin"
    gfx = ROOT / "build/gfx"
    sock = "/tmp/gs2-ghost-chase.sock"
    gs2 = Path(os.environ.get("GSSQUARED", str(DEFAULT_GS2)))
    if not bin_path.is_file():
        raise SystemExit(f"missing {bin_path}; run make iigs-game")

    proc = spawn_gs2(gs2, sock)
    try:
        with Client() as client:
            client.connect(sock)
            client.hello()
            assert client.get_status().platform_id == PLATFORM_APPLE_IIGS
            time.sleep(5.0)
            control_reset(client)
            time.sleep(2.0)
            client.pause()
            client.wait_stopped(timeout=10.0)
            inject_assets(client, bin_path, gfx)
            install_page3_trampoline(client)
            launch_via_basic(client)

            # Sample while running: pause/dump/continue at checkpoints
            checkpoints = [1.5, 8.0, 10.0, 12.0, 15.0, 20.0, args.seconds]
            # unique sorted positive times
            checkpoints = sorted({t for t in checkpoints if t > 0})
            elapsed = 0.0
            for t in checkpoints:
                wait = max(0.0, t - elapsed)
                if wait:
                    time.sleep(wait)
                elapsed = t
                client.pause()
                client.wait_stopped(timeout=5.0)
                dump(client, f"t~{t}s")
                # distance² red→pac in arcade tile space
                pty, ptx = u8(client, PAC_TILE_Y), u8(client, PAC_TILE_X)
                rty, rtx = u8(client, RED_TILE_Y), u8(client, RED_TILE_X)
                dy = abs(pty - rty)
                dx = abs(ptx - rtx)
                print(f"  dist2_red_pac={dy*dy + dx*dx} red_px=({u8(client, 0x028460):02X},{u8(client, 0x028461):02X})")
                client.continue_()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except Exception:
            proc.kill()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
