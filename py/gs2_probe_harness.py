#!/usr/bin/env python3
"""Spawn GS2, run harness briefly, dump diagnostic RAM (TILEMAP/WORK/SHR/PC)."""

from __future__ import annotations

import os
import subprocess
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


def dump(client: Client, addr: int, n: int, label: str) -> None:
    b = client.read_mem(MEM_MAIN, addr, n)
    nz = sum(1 for x in b if x)
    print(f"{label:12} ${addr:06X}: nz={nz:5}/{n:<5} head={b[:16].hex()}")


def main() -> int:
    sock = "/tmp/gs2-mspacman-probe.sock"
    gs2 = Path(os.environ.get("GSSQUARED", DEFAULT_GS2))
    proc = spawn_gs2(gs2, sock)
    try:
        with Client() as client:
            client.connect(sock)
            info = client.hello()
            print(f"HELLO v={info.version}")
            time.sleep(5.0)
            control_reset(client)
            time.sleep(2.0)
            client.pause()
            client.wait_stopped(timeout=10.0)
            inject_assets(client, DEFAULT_BIN, DEFAULT_GFX)
            install_page3_trampoline(client)
            launch_via_basic(client)
            time.sleep(2.0)
            client.pause()
            try:
                client.wait_stopped(timeout=5.0)
            except TimeoutError:
                print("WARN: no EVT_STOPPED")
            st = client.get_status()
            print(f"status mode={st.execution_mode} raw={st!r}")
            dump(client, 0x020000, 16, "CODE")
            dump(client, 0x027000, 32, "TILEMAP")
            dump(client, 0x026000, 32, "SPR_WORK")
            dump(client, 0x027400, 16, "ACTOR0")
            dump(client, 0x012000, 64, "SHR_$01")
            dump(client, 0xE12000, 64, "SHR_$E1")
            dump(client, 0x027904, 4, "FREEZE/FC")
            try:
                client.quit()
            except Exception:
                pass
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
        try:
            os.unlink(sock)
        except FileNotFoundError:
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
