#!/usr/bin/env python3
"""One-shot interactive rail-demo launcher for GSSquared.

Builds the harness if needed, spawns the emulator, injects assets, starts the
demo, then waits for Enter in *this* terminal before quitting GSSquared.

Usage (from repo root):
  python3 py/gs2_run_demo.py
  make iigs-demo

Border colors: red=erase, green=draw, blue=copy, orange=rails, black=VBL wait.
Any key in the *emulator* ends the 65816 demo (ExitDemo); Enter here quits GS2.
"""

from __future__ import annotations

import argparse
import os
import subprocess
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
if str(GS2_PY) not in sys.path:
    sys.path.insert(0, str(GS2_PY))
sys.path.insert(0, str(ROOT / "py"))

import gs2_render_test as rt  # noqa: E402

try:
    from gs2debug import MEM_MAIN, PLATFORM_APPLE_IIGS, Client, ProtocolError
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        f"gs2debug not found; expected under {GS2_PY} (or set GS2_PY / PYTHONPATH)"
    ) from exc


def ensure_build(build: bool) -> None:
    gfx_ok = (rt.DEFAULT_GFX / "tiles6.bin").is_file() and (
        rt.DEFAULT_GFX / "maze1_cells.bin"
    ).is_file()
    bin_ok = rt.DEFAULT_BIN.is_file()
    if not build and bin_ok and gfx_ok:
        return
    targets = []
    if not gfx_ok or build:
        targets.extend(["gfx", "maze"])
    targets.append("iigs")
    print(f"building: make {' '.join(targets)}")
    subprocess.check_call(["make", *targets], cwd=ROOT)


def wait_enter() -> None:
    print()
    print("Demo running — watch GSSquared (border = phase profiler).")
    print("  Emulator key  → end 65816 demo (ExitDemo)")
    print("  Enter here    → quit GSSquared")
    print()
    try:
        input("Press Enter to quit… ")
    except EOFError:
        # Non-interactive: keep running until killed
        print("(no stdin — sleeping forever; Ctrl+C to stop)")
        while True:
            time.sleep(3600)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--gs2",
        type=Path,
        default=Path(os.environ.get("GSSQUARED", rt.DEFAULT_GS2)),
    )
    ap.add_argument("--socket", default=os.environ.get("GS2_SOCK", rt.DEFAULT_SOCK))
    ap.add_argument(
        "--no-build",
        action="store_true",
        help="do not run make; require existing harness + gfx",
    )
    ap.add_argument("--boot-wait", type=float, default=5.0)
    ap.add_argument("--post-reset-wait", type=float, default=2.0)
    args = ap.parse_args()

    ensure_build(build=not args.no_build)

    for need in (
        rt.DEFAULT_BIN,
        rt.DEFAULT_GFX / "tiles6.bin",
        rt.DEFAULT_GFX / "sprites14x12.bin",
        rt.DEFAULT_GFX / "sprites14x12.mask.bin",
        rt.DEFAULT_GFX / "sprites14x12.odd.bin",
        rt.DEFAULT_GFX / "sprites14x12.odd.mask.bin",
        rt.DEFAULT_GFX / "maze1_28x31.bin",
        rt.DEFAULT_GFX / "maze1_cells.bin",
    ):
        if not Path(need).is_file():
            raise SystemExit(f"missing {need}; try without --no-build")

    proc: subprocess.Popen | None = None
    sock = args.socket
    try:
        print(f"spawning {args.gs2} -p 5 --debug {sock}")
        proc = rt.spawn_gs2(args.gs2, sock)

        with Client() as client:
            client.connect(sock)
            info = client.hello()
            print(f"HELLO version={info.version} max_payload={info.max_payload:#x}")
            st = client.get_status()
            if st.platform_id != PLATFORM_APPLE_IIGS:
                raise SystemExit(f"expected IIgs platform_id=5, got {st.platform_id}")

            print(f"boot wait {args.boot_wait}s…")
            time.sleep(args.boot_wait)
            rt.control_reset(client)
            print(f"post-reset wait {args.post_reset_wait}s…")
            time.sleep(args.post_reset_wait)

            client.pause()
            try:
                client.wait_stopped(timeout=10.0)
            except TimeoutError:
                print("warning: no EVT_STOPPED after pre-inject pause")

            rt.inject_assets(client, rt.DEFAULT_BIN, rt.DEFAULT_GFX)
            rt.install_page3_trampoline(client)
            # Ensure freeze off for live demo
            client.write_mem(MEM_MAIN, rt.DEMO_FREEZE_ADDR, bytes([0]))
            rt.launch_via_basic(client)

            wait_enter()

            try:
                client.quit()
            except (ProtocolError, OSError, RuntimeError) as exc:
                print(f"quit via protocol failed: {exc}")
        return 0
    finally:
        if proc is not None and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
