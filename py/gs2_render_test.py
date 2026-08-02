#!/usr/bin/env python3
"""Assemble-inject-run the IIgs render harness under GSSquared and dump SHR PNG.

Injects upright tile assets from make gfx (6×6 = CW then row XOR 3) plus
stitched maze1_cells.bin. The 65816 harness blits those bytes as-is.

Default: spawn GSSquared (-p 5), wait for boot, Control-Reset to Applesoft
(not Control-OA-Reset), inject harness + gfx, CALL 768 → $02/0000,
run briefly, READMEM $E1 SHR → build/iigs/frame.png, then quit the emu.

Usage:
  PYTHONPATH=$HOME/src/gssquared/clients/python/src \\
    python3 py/gs2_render_test.py
  python3 py/gs2_render_test.py --attach /tmp/gs2.sock
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "py"))

from shr_dump_png import PIXEL_BYTES, PALETTE_BYTES, shr_to_png  # noqa: E402

try:
    from gs2debug import (
        KMOD_CTRL,
        KMOD_LCTRL,
        MEM_MAIN,
        PLATFORM_APPLE_IIGS,
        SCANCODE_F12,
        SCANCODE_LCTRL,
        Client,
        ProtocolError,
    )
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "gs2debug not found; set PYTHONPATH to gssquared/clients/python/src"
    ) from exc

DEFAULT_GS2 = Path.home() / "src" / "gssquared" / "build" / "GSSquared"
DEFAULT_SOCK = "/tmp/gs2-mspacman.sock"
DEFAULT_BIN = ROOT / "build" / "iigs" / "harness.bin"
DEFAULT_GFX = ROOT / "build" / "gfx"
DEFAULT_OUT = ROOT / "build" / "iigs" / "frame.png"

CODE_ADDR = 0x020000
TILES_ADDR = 0x030000
SPR_ADDR = 0x031200
MSK_ADDR = 0x032700
MAZE_ADDR = 0x036600
MAZE_CELLS_ADDR = 0x037000
# With SHR shadowing on, bank $01 is authoritative; $E1 tracks it.
SHR_ADDR = 0x012000
PAL_ADDR = 0x019E00

CHUNK = 0x4000


def write_mem_chunked(client: Client, domain: int, address: int, data: bytes) -> None:
    off = 0
    while off < len(data):
        piece = data[off : off + CHUNK]
        client.write_mem(domain, address + off, piece)
        off += len(piece)


def wait_socket(path: str, timeout: float = 15.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if Path(path).exists():
            # brief settle for accept()
            time.sleep(0.15)
            return
        time.sleep(0.05)
    raise TimeoutError(f"debug socket not ready: {path}")


def spawn_gs2(gs2: Path, sock: str) -> subprocess.Popen:
    if not gs2.is_file():
        raise SystemExit(f"GSSquared not found: {gs2}")
    try:
        os.unlink(sock)
    except FileNotFoundError:
        pass
    proc = subprocess.Popen(
        [str(gs2), "-p", "5", "--debug", sock, "--no-quit-confirm"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    try:
        wait_socket(sock)
    except Exception:
        proc.terminate()
        raise
    return proc


def control_reset(client: Client) -> None:
    """Control-Reset only (Ctrl+F12). Do not hold OpenApple — that is C-OA-Reset."""
    print("Control-Reset (Ctrl+F12; not Control-OA-Reset)")
    client.key_down(SCANCODE_LCTRL, KMOD_LCTRL)
    time.sleep(0.05)
    # Reset key handlers check Ctrl on the F12 event itself
    client.key_down(SCANCODE_F12, KMOD_CTRL)
    time.sleep(0.2)
    client.key_up(SCANCODE_F12, KMOD_CTRL)
    client.key_up(SCANCODE_LCTRL, 0)


def install_page3_trampoline(client: Client) -> None:
    """CLC / XCE / JML $020000 at $00/0300 for Applesoft CALL 768."""
    stub = bytes([0x18, 0xFB, 0x5C, 0x00, 0x00, 0x02])
    addr = 0x000300
    client.write_mem(MEM_MAIN, addr, stub)
    rb = client.read_mem(MEM_MAIN, addr, 6)
    if rb != stub:
        raise RuntimeError(f"page-3 trampoline write failed at $000300 rb={rb.hex()}")
    print("trampoline: CLC/XCE/JML $020000 at $00/0300 (CALL 768)")


def launch_via_basic(client: Client) -> None:
    """From Applesoft prompt, type CALL 768 to enter the trampoline."""
    st = client.get_status()
    if st.execution_mode == 2:  # PAUSED
        client.continue_()
        time.sleep(0.3)
    # GSSquared drops keys if typed too fast after Control-Reset; be deliberate.
    print("typing: CALL 768 (slow)")
    client.type_text("CALL 768\n", delay_s=0.25, hold_s=0.06)
    time.sleep(1.0)


def inject_assets(client: Client, bin_path: Path, gfx: Path) -> None:
    harness = bin_path.read_bytes()
    tiles = (gfx / "tiles6.bin").read_bytes()
    sprites = (gfx / "sprites14x12.bin").read_bytes()
    masks = (gfx / "sprites14x12.mask.bin").read_bytes()
    maze = (gfx / "maze1_28x31.bin").read_bytes()
    cells = (gfx / "maze1_cells.bin").read_bytes()

    print(f"inject harness {len(harness)} bytes @ ${CODE_ADDR:06X}")
    write_mem_chunked(client, MEM_MAIN, CODE_ADDR, harness)
    print(f"inject tiles {len(tiles)} @ ${TILES_ADDR:06X}")
    write_mem_chunked(client, MEM_MAIN, TILES_ADDR, tiles)
    print(f"inject sprites {len(sprites)} @ ${SPR_ADDR:06X}")
    write_mem_chunked(client, MEM_MAIN, SPR_ADDR, sprites)
    print(f"inject masks {len(masks)} @ ${MSK_ADDR:06X}")
    write_mem_chunked(client, MEM_MAIN, MSK_ADDR, masks)
    print(f"inject maze {len(maze)} @ ${MAZE_ADDR:06X}")
    write_mem_chunked(client, MEM_MAIN, MAZE_ADDR, maze)
    print(f"inject maze cells {len(cells)} @ ${MAZE_CELLS_ADDR:06X}")
    write_mem_chunked(client, MEM_MAIN, MAZE_CELLS_ADDR, cells)


def capture_frame(client: Client, out: Path) -> None:
    pixels = bytearray()
    # READMEM max 65536; SHR is 32000 — one call
    pixels.extend(client.read_mem(MEM_MAIN, SHR_ADDR, PIXEL_BYTES))
    palette = client.read_mem(MEM_MAIN, PAL_ADDR, PALETTE_BYTES)
    png = shr_to_png(bytes(pixels), palette)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(png)
    nonzero = sum(1 for b in pixels if b)
    print(f"wrote {out} ({len(png)} bytes PNG, {nonzero} nonzero SHR bytes)")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--gs2", type=Path, default=Path(os.environ.get("GSSQUARED", DEFAULT_GS2)))
    ap.add_argument("--socket", default=os.environ.get("GS2_SOCK", DEFAULT_SOCK))
    ap.add_argument("--attach", metavar="SOCK", help="attach to running GS2 (do not spawn/quit)")
    ap.add_argument("--bin", type=Path, default=DEFAULT_BIN)
    ap.add_argument("--gfx", type=Path, default=DEFAULT_GFX)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--run-seconds", type=float, default=1.0)
    ap.add_argument(
        "--boot-wait",
        type=float,
        default=5.0,
        help="seconds to wait after spawn before Control-Reset (default 5)",
    )
    ap.add_argument(
        "--post-reset-wait",
        type=float,
        default=2.0,
        help="seconds to wait after Control-Reset for BASIC prompt (default 2)",
    )
    args = ap.parse_args()

    for need in (
        args.bin,
        args.gfx / "tiles6.bin",
        args.gfx / "sprites14x12.bin",
        args.gfx / "sprites14x12.mask.bin",
        args.gfx / "maze1_28x31.bin",
        args.gfx / "maze1_cells.bin",
    ):
        if not Path(need).is_file():
            raise SystemExit(f"missing {need}; run: make iigs gfx maze")

    proc: subprocess.Popen | None = None
    sock = args.attach or args.socket
    own_process = args.attach is None

    try:
        if own_process:
            print(f"spawning {args.gs2} -p 5 --debug {sock}")
            proc = spawn_gs2(args.gs2, sock)

        with Client() as client:
            client.connect(sock)
            info = client.hello()
            print(f"HELLO version={info.version} max_payload={info.max_payload:#x}")
            st = client.get_status()
            print(f"status mode={st.execution_mode} platform={st.platform_id}")
            if st.platform_id != PLATFORM_APPLE_IIGS:
                raise SystemExit(f"expected IIgs platform_id=5, got {st.platform_id}")

            # Boot to Applesoft: wait → Control-Reset → BASIC prompt.
            if own_process:
                print(f"boot wait {args.boot_wait}s…")
                time.sleep(args.boot_wait)
                control_reset(client)
                print(f"post-reset wait {args.post_reset_wait}s for BASIC…")
                time.sleep(args.post_reset_wait)
            else:
                time.sleep(0.3)

            # Pause to poke memory safely, then CALL 768 from BASIC.
            client.pause()
            try:
                client.wait_stopped(timeout=10.0)
            except TimeoutError:
                print("warning: no EVT_STOPPED after pre-inject pause")

            inject_assets(client, args.bin, args.gfx)
            install_page3_trampoline(client)
            launch_via_basic(client)
            print(f"running {args.run_seconds}s…")
            time.sleep(args.run_seconds)
            client.pause()
            try:
                client.wait_stopped(timeout=5.0)
            except TimeoutError:
                print("warning: no EVT_STOPPED after pause (continuing capture)")
            capture_frame(client, args.out)

            if own_process:
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
