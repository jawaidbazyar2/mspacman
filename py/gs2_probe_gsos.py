#!/usr/bin/env python3
"""Boot mspacmangs.2mg under GSSquared, auto-launch START, dump SHR.

Copies the disk, installs MSPACMAN.SYS16 as START (GS/OS boot app), runs
briefly, writes build/iigs/gsos_frame.png, and prints crude motion / garbage
heuristics for the top gutters vs playfield.

Usage:
  PYTHONPATH=$HOME/src/gssquared/clients/python/src \\
    python3 py/gs2_probe_gsos.py --run-seconds 8
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "py"))

from gs2_render_test import DEFAULT_GS2  # noqa: E402
from shr_dump_png import PALETTE_BYTES, PIXEL_BYTES, shr_to_png  # noqa: E402

try:
    from gs2debug import MEM_MAIN, PLATFORM_APPLE_IIGS, Client
except ImportError as exc:  # pragma: no cover
    raise SystemExit(f"gs2debug missing: {exc}") from exc

CP2 = Path(os.environ.get("CP2", Path.home() / "src/cp2_1.0.5_osx-x64_sc/cp2"))
DISK = Path(os.environ.get("IIGS_GSOS_DISK", Path.home() / "src/IIgsDisks/mspacmangs.2mg"))
SHR_ADDR = 0x012000
PAL_ADDR = 0x019E00
S_SHR = 160


def prepare_boot_disk(src: Path) -> Path:
    """Temp 2MG with START = MSPACMAN.SYS16 so GS/OS launches the game."""
    if not src.is_file():
        raise SystemExit(f"missing disk {src}")
    if not CP2.is_file():
        raise SystemExit(f"missing cp2 at {CP2}")
    tdir = Path(tempfile.mkdtemp(prefix="mspac-gsos-"))
    tmp = tdir / "boot.2mg"
    shutil.copy2(src, tmp)
    sys16 = ROOT / "build/iigs/MSPACMAN.SYS16"
    start_host = tdir / "START"
    shutil.copy2(sys16, start_host)
    subprocess.run(
        [str(CP2), "add", "--overwrite", "--strip-paths", str(tmp), str(start_host)],
        check=True,
    )
    subprocess.run(
        [str(CP2), "set-attr", str(tmp), "type=0xb3,aux=0x0000", "START"],
        check=True,
    )
    return tmp


def spawn_gs2_disk(gs2: Path, sock: str, disk: Path) -> subprocess.Popen:
    if not gs2.is_file():
        raise SystemExit(f"GSSquared not found: {gs2}")
    try:
        os.unlink(sock)
    except FileNotFoundError:
        pass
    proc = subprocess.Popen(
        [
            str(gs2),
            "-p",
            "5",
            f"-ds7d1={disk}",
            "--debug",
            sock,
            "--no-quit-confirm",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    # reuse wait from spawn_gs2 by connecting briefly
    deadline = time.monotonic() + 20.0
    while time.monotonic() < deadline:
        if Path(sock).exists():
            time.sleep(0.15)
            return proc
        time.sleep(0.05)
    proc.terminate()
    raise TimeoutError(f"debug socket not ready: {sock}")


def dump_shr(client: Client, out: Path) -> bytes:
    pixels = client.read_mem(MEM_MAIN, SHR_ADDR, PIXEL_BYTES)
    palette = client.read_mem(MEM_MAIN, PAL_ADDR, PALETTE_BYTES)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(shr_to_png(bytes(pixels), palette))
    return bytes(pixels)


def row_nonzero(pixels: bytes, y: int) -> int:
    base = y * S_SHR
    return sum(1 for b in pixels[base : base + S_SHR] if b)


def pf_checksum(pixels: bytes) -> int:
    """Checksum playfield band (y=7..192, x bytes for px 76..243)."""
    total = 0
    for y in range(7, 193):
        base = y * S_SHR + 38  # 76/2
        for b in pixels[base : base + 84]:
            total = (total + b) & 0xFFFFFFFF
    return total


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-seconds", type=float, default=8.0,
                    help="time after boot wait to let the game run")
    ap.add_argument("--boot-wait", type=float, default=45.0,
                    help="seconds to wait for GS/OS + START launch")
    ap.add_argument("--out", type=Path, default=ROOT / "build/iigs/gsos_frame.png")
    ap.add_argument("--disk", type=Path, default=DISK)
    args = ap.parse_args()

    sys16 = ROOT / "build/iigs/MSPACMAN.SYS16"
    if not sys16.is_file():
        raise SystemExit(f"missing {sys16}; run make iigs-gsos first")

    boot = prepare_boot_disk(args.disk)
    sock = "/tmp/gs2-mspac-gsos.sock"
    gs2 = Path(os.environ.get("GSSQUARED", str(DEFAULT_GS2)))
    print(f"boot disk {boot}")
    proc = spawn_gs2_disk(gs2, sock, boot)
    try:
        with Client() as client:
            client.connect(sock)
            client.hello()
            assert client.get_status().platform_id == PLATFORM_APPLE_IIGS
            print(f"waiting {args.boot_wait}s for GS/OS + START…")
            time.sleep(args.boot_wait)
            print(f"running {args.run_seconds}s…")
            time.sleep(max(0.0, args.run_seconds * 0.5))
            client.pause()
            client.wait_stopped(timeout=10.0)
            pix1 = dump_shr(client, args.out.with_name("gsos_frame_a.png"))
            c1 = pf_checksum(pix1)
            client.continue_()
            time.sleep(max(0.5, args.run_seconds * 0.5))
            client.pause()
            client.wait_stopped(timeout=10.0)
            pix2 = dump_shr(client, args.out)
            c2 = pf_checksum(pix2)

            top = [row_nonzero(pix2, y) for y in range(0, 12)]
            print(f"top-row nonzero counts (y0..11): {top}")
            print(f"playfield checksum t0={c1:#x} t1={c2:#x} delta={c2 - c1}")
            print(f"wrote {args.out}")
            # Heuristics
            top_busy = sum(top[:4])
            if top_busy > 200:
                print("WARN: top gutters look busy (possible tile/sprite garbage)")
            if c1 == c2:
                print("WARN: playfield checksum unchanged (sprites may be frozen)")
            else:
                print("OK: playfield pixels changed between samples")
            client.quit()
        return 0
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        shutil.rmtree(boot.parent, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
