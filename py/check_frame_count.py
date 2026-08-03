#!/usr/bin/env python3
"""Spawn GSSquared, run harness ~1.5s, print FRAME_COUNT (no DEMO_FREEZE).

Usage:
  PYTHONPATH=…/gssquared/clients/python/src python3 py/check_frame_count.py
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

from gs2debug import MEM_MAIN, PLATFORM_APPLE_IIGS, Client

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "py"))
from gs2_render_test import (  # noqa: E402
    DEFAULT_GS2,
    control_reset,
    inject_assets,
    install_page3_trampoline,
    launch_via_basic,
    spawn_gs2,
)

FRAME = 0x028900
SHADOW = 0xE0C035


def main() -> int:
    sock = "/tmp/gs2-framecount.sock"
    try:
        os.unlink(sock)
    except FileNotFoundError:
        pass
    proc = spawn_gs2(Path(os.environ.get("GS2", DEFAULT_GS2)), sock)
    try:
        with Client() as c:
            c.connect(sock)
            c.hello()
            st = c.get_status()
            if st.platform_id != PLATFORM_APPLE_IIGS:
                raise SystemExit(f"expected IIgs platform_id=5, got {st.platform_id}")
            time.sleep(5.0)
            control_reset(c)
            time.sleep(2.0)
            c.pause()
            try:
                c.wait_stopped(timeout=10.0)
            except TimeoutError:
                pass
            inject_assets(c, ROOT / "build/iigs/harness.bin", ROOT / "build/gfx")
            install_page3_trampoline(c)
            launch_via_basic(c)
            time.sleep(1.5)
            c.pause()
            try:
                c.wait_stopped(timeout=5.0)
            except TimeoutError:
                pass
            fc = int.from_bytes(c.read_mem(MEM_MAIN, FRAME, 2), "little")
            c.continue_()
            time.sleep(1.0)
            c.pause()
            try:
                c.wait_stopped(timeout=5.0)
            except TimeoutError:
                pass
            fc2 = int.from_bytes(c.read_mem(MEM_MAIN, FRAME, 2), "little")
            sh = c.read_mem(MEM_MAIN, SHADOW, 1)[0]
            print(f"FRAME_COUNT @1.5s={fc} @+1.0s={fc2} delta={fc2 - fc}")
            print(f"SHADOW $E0/C035=${sh:02X}")
            ok = fc2 >= 10 and fc2 > fc
            print("PASS" if ok else "FAIL")
            try:
                c.quit()
            except Exception:
                pass
            return 0 if ok else 1
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except Exception:
                proc.kill()


if __name__ == "__main__":
    raise SystemExit(main())
