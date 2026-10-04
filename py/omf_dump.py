#!/usr/bin/env python3
"""Dump the segments of an Apple IIgs OMF (v2) load file: header fields and
relocation records, to check what the GS/OS loader will patch.

Usage:
  python3 py/omf_dump.py FILE.SYS16 [--relocs]
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

SUPER_TYPES = {0: "RELOC2", 1: "RELOC3"}


def u(b: bytes, off: int, n: int) -> int:
    return int.from_bytes(b[off:off + n], "little")


def body(seg: bytes, start: int, numlen: int, show: bool) -> dict:
    """Walk the body records. Returns counts by record kind."""
    counts: dict[str, int] = {}
    pc = 0
    off = start

    def note(kind: str, text: str = "") -> None:
        counts[kind] = counts.get(kind, 0) + 1
        if show and text:
            print(f"    {kind:<10} {text}")

    while off < len(seg):
        op = seg[off]
        off += 1
        if op == 0x00:
            note("END")
            break
        if 0x01 <= op <= 0xDF:
            pc += op
            off += op
            note("CONST")
        elif op == 0xF2:
            n = u(seg, off, 4)
            off += 4 + n
            pc += n
            note("LCONST")
        elif op == 0xF1:
            n = u(seg, off, 4)
            off += 4
            pc += n
            note("DS", f"{n:#x} bytes")
        elif op == 0xE2:
            cnt, shift = seg[off], struct.unpack("b", seg[off + 1:off + 2])[0]
            at, val = u(seg, off + 2, 4), u(seg, off + 6, 4)
            off += 10
            note("RELOC", f"@{at:06X} {cnt}B shift {shift} -> {val:06X}")
        elif op == 0xE3:
            cnt, shift = seg[off], struct.unpack("b", seg[off + 1:off + 2])[0]
            at, fil, sg, val = u(seg, off + 2, 4), u(seg, off + 6, 2), u(seg, off + 8, 2), u(seg, off + 10, 4)
            off += 14
            note("INTERSEG", f"@{at:06X} {cnt}B shift {shift} -> file {fil} seg {sg} +{val:06X}")
        elif op == 0xF5:
            cnt, shift = seg[off], struct.unpack("b", seg[off + 1:off + 2])[0]
            at, val = u(seg, off + 2, 2), u(seg, off + 4, 2)
            off += 6
            note("cRELOC", f"@{at:04X} {cnt}B shift {shift} -> {val:04X}")
        elif op == 0xF6:
            cnt, shift = seg[off], struct.unpack("b", seg[off + 1:off + 2])[0]
            at, sg, val = u(seg, off + 2, 2), seg[off + 4], u(seg, off + 5, 2)
            off += 7
            note("cINTERSEG", f"@{at:04X} {cnt}B shift {shift} -> seg {sg} +{val:04X}")
        elif op == 0xF7:
            n = u(seg, off, 4)
            kind = seg[off + 4]
            name = SUPER_TYPES.get(kind, f"INTERSEG{kind - 1}" if 2 <= kind <= 37 else f"type{kind}")
            off += 4 + n
            note(f"SUPER-{name}", f"{n - 1} bytes")
        else:
            note("UNKNOWN", f"opcode {op:#x} at {off - 1:#x}")
            break
    return counts


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("file", type=Path)
    ap.add_argument("--relocs", action="store_true", help="list each record")
    args = ap.parse_args()
    data = args.file.read_bytes()
    off = 0
    while off < len(data):
        h = data[off:]
        bytecnt = u(h, 0, 4)
        if bytecnt == 0:
            break
        length, lablen, numlen, version = u(h, 8, 4), h[13], h[14], h[15]
        banksize, kind, org, align = u(h, 16, 4), u(h, 20, 2), u(h, 24, 4), u(h, 28, 4)
        segnum, dispname, dispdata = u(h, 34, 2), u(h, 40, 2), u(h, 42, 2)
        name_off = dispname + 10
        n = h[name_off] if lablen == 0 else lablen
        name = h[name_off + (1 if lablen == 0 else 0):][:n].decode("latin-1")
        print(f"segment {segnum} '{name}' kind {kind:#06x} length {length:#x} "
              f"banksize {banksize:#x} align {align:#x} org {org:#x} v{version}")
        counts = body(h[:bytecnt], dispdata, numlen, args.relocs)
        print("    " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
        off += bytecnt
    return 0


if __name__ == "__main__":
    sys.exit(main())
