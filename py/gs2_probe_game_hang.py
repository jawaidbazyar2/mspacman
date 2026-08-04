#!/usr/bin/env python3
"""Probe game.bin for LogicTick hang (orange border / stuck FRAME_COUNT).

Usage (repo root):
  PYTHONPATH=$HOME/src/gssquared/clients/python/src \\
    python3 py/gs2_probe_game_hang.py
"""

from __future__ import annotations

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
PAC_Y, PAC_X = 0x028468, 0x028469
RED_Y, RED_X = 0x028460, 0x028461
LEVEL_STATE = 0x028564
DOTS_EATEN = 0x02856E
BORDCOLOR = 0xE0C034
DIRTY_COUNT = 0x028800


def u8(client: Client, addr: int) -> int:
    return client.read_mem(MEM_MAIN, addr, 1)[0]


def u16(client: Client, addr: int) -> int:
    b = client.read_mem(MEM_MAIN, addr, 2)
    return b[0] | (b[1] << 8)


def main() -> int:
    bin_path = ROOT / "build/iigs/game.bin"
    gfx = ROOT / "build/gfx"
    sock = "/tmp/gs2-game-hang.sock"
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

            time.sleep(0.8)
            samples = []
            for i in range(10):
                time.sleep(0.5)
                client.pause()
                ev = client.wait_stopped(timeout=5.0)
                pc = getattr(ev, "pc", None)
                row = {
                    "i": i,
                    "fc": u16(client, FRAME_COUNT),
                    "pac": (u8(client, PAC_X), u8(client, PAC_Y)),
                    "red": (u8(client, RED_X), u8(client, RED_Y)),
                    "level_state": u8(client, LEVEL_STATE),
                    "dots": u8(client, DOTS_EATEN),
                    "dirty": u16(client, DIRTY_COUNT),
                    "border": u8(client, BORDCOLOR) & 0x0F,
                    "pc": None if pc is None else f"${pc:06X}",
                }
                samples.append(row)
                print(row)
                client.continue_()

            fcs = [s["fc"] for s in samples]
            if fcs[-1] <= fcs[0] + 2:
                print("FAIL: FRAME_COUNT not advancing — hung", fcs)
                # Keep last pause state for inspection: pause again
                client.pause()
                ev = client.wait_stopped(timeout=5.0)
                print("stuck pc", f"${ev.pc:06X}" if ev else None)
                try:
                    tw = client.get_trace(ago=0, count=5)
                    print("trace entries", tw.returned if hasattr(tw, "returned") else tw)
                except Exception as exc:
                    print("trace err", exc)
                return 1
            print("OK: FRAME_COUNT advanced", fcs[0], "→", fcs[-1])
            try:
                client.quit()
            except Exception:
                pass
            return 0
    finally:
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except Exception:
                proc.kill()


if __name__ == "__main__":
    raise SystemExit(main())
