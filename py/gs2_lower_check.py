#!/usr/bin/env python3
"""Run the phase 3 IIgs build (make iigs-lower) under GSSquared.

Makefile/CI only (lower-iigs-check, iigs-lower-demo); live debugging uses
the gs2-debug MCP.

Injects build/iigs/lower_host.bin at $02/0000, lower_game.bin at $05/0000,
the tile and sprite assets at $03, and the ROM ranges of build/mspac.bin
into the game bank $06, then starts the host from Applesoft (CALL 768).

Check mode (default) replays C-only corpus sessions. For each session it
loads the first record that ended in the idle spin into the game bank,
sets CheckMode, points the replay stream at the session's logged IN0/IN1
reads (bank $07 up), and stops at FrameDone after every frame to compare
the game bank with the frame record, masked as the C-only replay masks
it, and the DOC's oscillators 0-2 (Ensoniq STATE_GET) with the values
iigs/lower_sound.s derives from the record's voice registers. The wave
tables in DOC RAM are checked once per session. Play mode (--play)
starts a fresh game and leaves it running.

Usage:
  PYTHONPATH=$HOME/src/gssquared/clients/python/src \\
    python3 py/gs2_lower_check.py [--frames N] corpus/c-shakedown ...
  python3 py/gs2_lower_check.py --play [--png out.png --run-seconds 20 | --detach]
"""

from __future__ import annotations

import argparse
import os
import struct
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "py"))

from gs2_render_test import (  # noqa: E402
    DEFAULT_GS2,
    control_reset,
    install_page3_trampoline,
    launch_via_basic,
    spawn_gs2,
    write_mem_chunked,
)
from gen_wave_data import (  # noqa: E402
    DOC_E1,
    DOC_WAVE_ADDR,
    RESOLUTION,
    SR_INT,
    TABLE_SIZE_CODE,
    doc_freq,
    doc_samples,
    wave_page,
)
from shr_dump_png import PALETTE_BYTES, PIXEL_BYTES, shr_to_png  # noqa: E402

try:
    from gs2debug import (
        BP_KIND_EXEC,
        DEVICE_ID_ENSONIQ,
        MEM_ENSONIQ,
        MEM_MAIN,
        PLATFORM_APPLE_IIGS,
        Client,
        ProtocolError,
    )
except ImportError as exc:  # pragma: no cover
    raise SystemExit("gs2debug not found; set PYTHONPATH to gssquared/clients/python/src") from exc

BUILD = ROOT / "build"
HOST_BIN = BUILD / "iigs" / "lower_host.bin"
GAME_BIN = BUILD / "iigs" / "lower_game.bin"
ROM_BIN = BUILD / "mspac.bin"
GFX = BUILD / "gfx"

HOST_ADDR = 0x020000
CHECK_MODE = 0x020003
FRAME_DONE = 0x020004
LOWER_ADDR = 0x050000
GAME = 0x060000
STREAM = 0x070000
IO_PTR = 0x001E70  # LOWER_DP + $70, bank $00
ASSETS = (
    ("tiles6.bin", 0x030000),
    ("sprites14x12.bin", 0x031200),
    ("sprites14x12.mask.bin", 0x032700),
    ("sprites14x12.odd.bin", 0x033C00),
    ("sprites14x12.odd.mask.bin", 0x035100),
)
SHR_ADDR = 0x012000
PAL_ADDR = 0x019E00

# Host block (lower/host/shadow.h, iigs/lower_io.s).
HB = GAME + 0xF000
HB_INT_ENABLED, HB_RESTART, HB_STARTED, HB_STOP, HB_RAND = 0, 1, 2, 3, 4
HB_IN0, HB_IN1, HB_DSW1, HB_REPLAY = 0x10, 0x11, 0x12, 0x13

# Frame record layout (lower/corpus.c, version 3).
FRAME_VER = 3
FRAME_BYTES = 3176
FRAME_HDR = 24
OFF_IFF1 = 36
OFF_LATCH = 42
OFF_VOICE = 50
OFF_WATCHDOG = 82
OFF_TILE = 84
OFF_COLOR = 1108
OFF_WORK = 2132
WORK_BYTES = 1008
OFF_SPRITE = OFF_WORK + WORK_BYTES
OFF_SPRPOS = OFF_SPRITE + 16
OFF_RAND = OFF_SPRPOS + 16
STACK_LO, STACK_HI = OFF_WORK + 0x301, OFF_WORK + 0x3BF

# iigs/lower_sound.s: DOC RAM wave tables and oscillators 0-2, laid out
# by py/gen_wave_data.py.
WAVE_PROM = ROOT / "mspacman" / "82s126.1m"
# GSSquared's Ensoniq STATE_GET v1 blob (soundglu.cpp pack_ensoniq_state).
ENS_BLOB = 16 + 32 * 24
ENS_REGE1, ENS_RATE, ENS_OSC, ENS_OSC_SIZE = 9, 12, 16, 24


class Session:
    def __init__(self, path: Path) -> None:
        self.name = path.name
        frames = (path / "frames").read_bytes()
        magic, ver, nbytes = frames[:4], *struct.unpack_from("<II", frames, 4)
        if magic != b"MSPF" or ver != FRAME_VER or nbytes != FRAME_BYTES:
            raise SystemExit(f"{path}: need an MSPF version {FRAME_VER} session")
        self.dsw1 = frames[16]
        body = frames[FRAME_HDR:]
        self.records = [body[i : i + FRAME_BYTES] for i in range(0, len(body), FRAME_BYTES)]
        inputs = (path / "inputs").read_bytes()
        if inputs[:4] != b"INPT":
            raise SystemExit(f"{path}: bad inputs header")
        self.reads: list[bytes] = []
        off = 8
        while off < len(inputs):
            (n,) = struct.unpack_from("<H", inputs, off)
            self.reads.append(inputs[off + 2 : off + 2 + n])
            off += 2 + n
        self.start = next(
            i for i, r in enumerate(self.records)
            if 0x238D <= struct.unpack_from("<H", r, 8)[0] <= 0x2392
        )


def field(off: int) -> str:
    if off < OFF_VOICE:
        return f"latch+${0x5000 + off - OFF_LATCH:04X}"
    if off < OFF_WATCHDOG:
        return f"voice+${0x5040 + off - OFF_VOICE:04X}"
    if off < OFF_COLOR:
        return f"tile+${0x4000 + off - OFF_TILE:04X}"
    if off < OFF_WORK:
        return f"color+${0x4400 + off - OFF_COLOR:04X}"
    if off < OFF_SPRITE:
        return f"work+${0x4C00 + off - OFF_WORK:04X}"
    if off < OFF_SPRPOS:
        return f"sprite+${0x4FF0 + off - OFF_SPRITE:04X}"
    if off < OFF_RAND:
        return f"sprpos+${0x5060 + off - OFF_SPRPOS:04X}"
    return f"rand+{off - OFF_RAND}"


def load_state(client: Client, rec: bytes, dsw1: int) -> None:
    """The game bank as the C-only replay's unpack_frame leaves the Board."""
    w = lambda addr, data: write_mem_chunked(client, MEM_MAIN, addr, bytes(data))  # noqa: E731
    w(GAME + 0x4000, bytes(0x1000))
    w(GAME + 0x5000, bytes(0x100))
    w(HB, bytes(0x20))
    w(GAME + 0x5000, rec[OFF_LATCH : OFF_LATCH + 8])
    w(GAME + 0x5040, rec[OFF_VOICE : OFF_VOICE + 32])
    w(GAME + 0x4000, rec[OFF_TILE : OFF_TILE + 1024])
    w(GAME + 0x4400, rec[OFF_COLOR : OFF_COLOR + 1024])
    w(GAME + 0x4C00, rec[OFF_WORK : OFF_WORK + WORK_BYTES])
    w(GAME + 0x4FF0, rec[OFF_SPRITE : OFF_SPRITE + 16])
    w(GAME + 0x5060, rec[OFF_SPRPOS : OFF_SPRPOS + 16])
    w(HB + HB_RAND, rec[OFF_RAND : OFF_RAND + 4])
    w(HB + HB_INT_ENABLED, [rec[OFF_IFF1]])
    w(HB + HB_STARTED, [1])
    w(HB + HB_IN0, [0xFF, 0xFF, dsw1, 1])


def capture(client: Client) -> bytes:
    """The game bank packed in frame-record order (registers left zero)."""
    out = bytearray(FRAME_BYTES)
    io = client.read_mem(MEM_MAIN, GAME + 0x5000, 0x70)
    out[OFF_LATCH : OFF_LATCH + 8] = bytes(b & 1 for b in io[0:8])
    out[OFF_VOICE : OFF_VOICE + 32] = bytes(b & 0x0F for b in io[0x40:0x60])
    vid = client.read_mem(MEM_MAIN, GAME + 0x4000, 0x800)
    out[OFF_TILE:OFF_WORK] = vid
    work = client.read_mem(MEM_MAIN, GAME + 0x4C00, 0x400)
    out[OFF_WORK:OFF_SPRPOS] = work
    out[OFF_SPRPOS:OFF_RAND] = io[0x60:0x70]
    out[OFF_RAND : OFF_RAND + 4] = client.read_mem(MEM_MAIN, HB + HB_RAND, 4)
    return bytes(out)


def first_diff(want: bytes, got: bytes) -> int:
    for off in range(OFF_LATCH, FRAME_BYTES):
        if OFF_WATCHDOG <= off < OFF_TILE or STACK_LO <= off <= STACK_HI:
            continue
        if want[off] != got[off]:
            return off
    return -1


def doc_expected(rec: bytes) -> list[tuple[int, int, int]]:
    """(freq, vol, wavetable pointer) per oscillator 0-2, as lower_sound.s
    derives them from a frame record's voice registers and $5001."""
    voice = [b & 0x0F for b in rec[OFF_VOICE : OFF_VOICE + 32]]
    on = rec[OFF_LATCH + 1] & 1
    out = []
    for v in range(3):
        nib = [voice[0x10 + 5 * v + k] for k in range(5)]
        if v:
            nib[0] = 0
        # VolScale in lower_sound.s: linear, WSG 15 -> DOC $80.
        vol = (voice[0x15 + 5 * v] * 0x80) // 15 if on else 0
        out.append((doc_freq(nib), vol, wave_page(voice[5 + 5 * v]) << 8))
    return out


def doc_diff(rec: bytes, blob: bytes) -> str:
    """'' when the DOC's oscillators 0-2 match the record, else the first difference."""
    if len(blob) != ENS_BLOB:
        return f"Ensoniq state is {len(blob)} bytes, expected {ENS_BLOB}"
    if blob[ENS_REGE1] != DOC_E1:
        return f"DOC $E1 expected {DOC_E1:02X} got {blob[ENS_REGE1]:02X}"
    (rate,) = struct.unpack_from("<I", blob, ENS_RATE)
    if rate != SR_INT:
        return f"DOC output rate expected {SR_INT} got {rate}"
    for o, (freq, vol, ptr) in enumerate(doc_expected(rec)):
        base = ENS_OSC + o * ENS_OSC_SIZE
        (got_freq,) = struct.unpack_from("<H", blob, base)
        got_ctl, got_vol = blob[base + 4], blob[base + 5]
        (got_ptr,) = struct.unpack_from("<I", blob, base + 8)
        got_size, got_res = blob[base + 12], blob[base + 13]
        want = (freq, vol, ptr, 0, TABLE_SIZE_CODE, RESOLUTION)
        got = (got_freq, got_vol, got_ptr, got_ctl, got_size, got_res)
        if want != got:
            names = ("freq", "vol", "wave ptr", "control", "table size", "resolution")
            i = next(i for i in range(6) if want[i] != got[i])
            return f"DOC osc {o} {names[i]} expected {want[i]:X} got {got[i]:X}"
    return ""


def doc_ram_diff(client: Client) -> str:
    want = doc_samples(WAVE_PROM.read_bytes())
    got = client.read_mem(MEM_ENSONIQ, DOC_WAVE_ADDR, len(want))
    if got == want:
        return ""
    off = next(i for i in range(len(want)) if want[i] != got[i])
    return f"DOC RAM ${DOC_WAVE_ADDR + off:04X} expected {want[off]:02X} got {got[off]:02X}"


def boot(client: Client, own: bool) -> None:
    info = client.hello()
    st = client.get_status()
    if st.platform_id != PLATFORM_APPLE_IIGS:
        raise SystemExit(f"expected IIgs platform_id=5, got {st.platform_id}")
    print(f"HELLO version={info.version}")
    if own:
        time.sleep(5.0)
        control_reset(client)
        time.sleep(2.0)
    client.pause()
    client.wait_stopped(timeout=10.0)


def inject(client: Client, check_mode: int) -> None:
    write_mem_chunked(client, MEM_MAIN, HOST_ADDR, HOST_BIN.read_bytes())
    for name, addr in ASSETS:
        write_mem_chunked(client, MEM_MAIN, addr, (GFX / name).read_bytes())
    game = GAME_BIN.read_bytes()
    write_mem_chunked(client, MEM_MAIN, LOWER_ADDR, game)
    if client.read_mem(MEM_MAIN, LOWER_ADDR, 64) != game[:64]:
        raise SystemExit("bank $05 did not take lower_game.bin; is the emulated IIgs RAM large enough?")
    rom = ROM_BIN.read_bytes()
    write_mem_chunked(client, MEM_MAIN, GAME, rom[:0x4000])
    write_mem_chunked(client, MEM_MAIN, GAME + 0x8000, rom[0x8000:0xA000])
    client.write_mem(MEM_MAIN, CHECK_MODE, bytes([check_mode]))
    install_page3_trampoline(client)


def last_frame(s: Session, frames: int) -> int:
    last = len(s.records) - 1
    return last if frames <= 0 else min(last, s.start + frames)


def preload(client: Client, s: Session, end: int) -> None:
    """The session's start state and its replay stream, before the host runs."""
    load_state(client, s.records[s.start], s.dsw1)
    stream = b"".join(s.reads[s.start + 1 : end + 1])
    if stream:
        write_mem_chunked(client, MEM_MAIN, STREAM, stream)
    client.write_mem(MEM_MAIN, IO_PTR, STREAM.to_bytes(3, "little"))


def check_session(client: Client, s: Session, end: int) -> bool:
    """Called stopped at FrameDone after the first replayed frame."""
    ptr = STREAM
    audible = 0
    t0 = time.monotonic()
    bad = doc_ram_diff(client)
    if bad:
        print(f"{s.name}: {bad}")
        return False
    for i in range(s.start + 1, end + 1):
        if i > s.start + 1:
            client.continue_()
            try:
                client.wait_stopped(timeout=30.0)
            except TimeoutError:
                client.pause()
                ev = client.wait_stopped(timeout=5.0)
                print(f"{s.name}: frame {i} never reached FrameDone; paused at ${ev.pc:06X}")
                return False
        got = capture(client)
        now = int.from_bytes(client.read_mem(MEM_MAIN, IO_PTR, 3), "little")
        if now - ptr != len(s.reads[i]):
            print(f"{s.name}: frame {i} input count expected {len(s.reads[i])} got {now - ptr}")
            return False
        ptr = now
        off = first_diff(s.records[i], got)
        if off >= 0:
            print(f"{s.name}: frame {i} {field(off)} expected {s.records[i][off]:02X} got {got[off]:02X}")
            return False
        bad = doc_diff(s.records[i], client.state_get(DEVICE_ID_ENSONIQ))
        if bad:
            print(f"{s.name}: frame {i} {bad}")
            return False
        audible += any(vol for _, vol, _ in doc_expected(s.records[i]))
    n = end - s.start
    print(f"{s.name}: frames {s.start + 1}-{end} ok ({n} frames, {audible} with sound, "
          f"{time.monotonic() - t0:.1f}s)")
    return True


def start_host(client: Client, tries: int = 3) -> bool:
    """CALL 768 until the first frame stops at FrameDone. GSSquared can
    drop typed keys, which leaves Applesoft waiting at its prompt."""
    for _ in range(tries):
        launch_via_basic(client)
        try:
            client.wait_stopped(timeout=15.0)
            return True
        except TimeoutError:
            client.pause()
            ev = client.wait_stopped(timeout=5.0)
            print(f"no first frame; paused at ${ev.pc:06X}")
            if ev.pc >> 16 in (0x02, 0x05):
                return False
            client.type_text("\n", delay_s=0.25, hold_s=0.06)
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("sessions", nargs="*", type=Path)
    ap.add_argument("--gs2", type=Path, default=Path(os.environ.get("GSSQUARED", DEFAULT_GS2)))
    ap.add_argument("--socket", default="/tmp/gs2-mspacman-lower.sock")
    ap.add_argument("--frames", type=int, default=600, help="frames per session (0: all)")
    ap.add_argument("--play", action="store_true", help="start a fresh game and leave it running")
    ap.add_argument("--png", type=Path, help="with --play: capture the SHR screen here")
    ap.add_argument("--run-seconds", type=float, default=10.0)
    ap.add_argument("--detach", action="store_true",
                    help="with --play: leave the emulator running for the gs2-debug MCP")
    ap.add_argument("--snap", type=Path,
                    help="capture the SHR screen of an already running (--detach) emulator")
    args = ap.parse_args()

    for need in [HOST_BIN, GAME_BIN, ROM_BIN] + [GFX / n for n, _ in ASSETS]:
        if not need.is_file():
            raise SystemExit(f"missing {need}; run: make iigs-lower")
    if not args.play and not args.sessions and not args.snap:
        raise SystemExit("name at least one corpus session, or --play")

    if args.snap:
        with Client() as client:
            client.connect(args.socket)
            client.hello()
            client.pause()
            client.wait_stopped(timeout=5.0)
            pixels = client.read_mem(MEM_MAIN, SHR_ADDR, PIXEL_BYTES)
            palette = client.read_mem(MEM_MAIN, PAL_ADDR, PALETTE_BYTES)
            client.continue_()
        args.snap.parent.mkdir(parents=True, exist_ok=True)
        args.snap.write_bytes(shr_to_png(pixels, palette))
        print(f"wrote {args.snap}")
        return 0

    if args.play:
        proc = spawn_gs2(args.gs2, args.socket)
        with Client() as client:
            client.connect(args.socket)
            boot(client, True)
            inject(client, 0)
            launch_via_basic(client)
            if args.png:
                time.sleep(args.run_seconds)
                client.pause()
                client.wait_stopped(timeout=5.0)
                pixels = client.read_mem(MEM_MAIN, SHR_ADDR, PIXEL_BYTES)
                palette = client.read_mem(MEM_MAIN, PAL_ADDR, PALETTE_BYTES)
                args.png.parent.mkdir(parents=True, exist_ok=True)
                args.png.write_bytes(shr_to_png(pixels, palette))
                print(f"wrote {args.png}")
                client.quit()
                return 0
            print("running: keys arrows, WASD, or keypad 8/4/6/2, 5 coin, 1/2 start, Esc pause, Open Apple-Q quit")
            if args.detach:
                print(f"detached; attach the gs2-debug MCP to {args.socket}")
                return 0
            input("press Enter here to close the emulator...")
            try:
                client.quit()
            except (ProtocolError, OSError, RuntimeError):
                pass
        proc.wait(timeout=5)
        return 0

    ok = True
    for path in args.sessions:
        s = Session(path)
        proc = spawn_gs2(args.gs2, args.socket)
        try:
            with Client() as client:
                client.connect(args.socket)
                boot(client, True)
                inject(client, 1)
                end = last_frame(s, args.frames)
                preload(client, s, end)
                client.bp_set(kind=BP_KIND_EXEC, address=FRAME_DONE, domain=MEM_MAIN)
                if not start_host(client):
                    print(f"{s.name}: the host never reached FrameDone")
                    ok = False
                else:
                    ok = check_session(client, s, end) and ok
                try:
                    client.quit()
                except (ProtocolError, OSError, RuntimeError):
                    pass
        finally:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    proc.kill()
    print("lower-iigs-check:", "ok" if ok else "FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
