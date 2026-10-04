#!/usr/bin/env python3
"""Set the ALIGN field of named segments in an OMF (v2) load file.

Merlin32's linker stores its internal code for `ali BANK` / `ali PAGE`
(2 / 1) in the segment header's ALIGN field instead of $10000 / $100.
This rewrites the field in place.

Usage:
  python3 py/omf_fix_align.py FILE.SYS16 Game=0x10000 [Seg=0x100 ...]
"""

from __future__ import annotations

import sys
from pathlib import Path

ALIGN_OFF = 28  # u32 in the segment header


def seg_name(h: bytes) -> str:
    lablen, dispname = h[13], int.from_bytes(h[40:42], "little")
    at = dispname + 10  # past LOADNAME
    if lablen == 0:
        return h[at + 1:at + 1 + h[at]].decode("latin-1").strip()
    return h[at:at + lablen].decode("latin-1").strip()


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    path = Path(argv[1])
    want = {k: int(v, 0) for k, v in (a.split("=", 1) for a in argv[2:])}
    data = bytearray(path.read_bytes())
    off = 0
    while off < len(data):
        bytecnt = int.from_bytes(data[off:off + 4], "little")
        if bytecnt == 0:
            break
        name = seg_name(bytes(data[off:off + bytecnt]))
        if name in want:
            data[off + ALIGN_OFF:off + ALIGN_OFF + 4] = want.pop(name).to_bytes(4, "little")
            print(f"{path.name}: segment {name} ALIGN set")
        off += bytecnt
    if want:
        print(f"{path.name}: no segment named {', '.join(want)}", file=sys.stderr)
        return 1
    path.write_bytes(bytes(data))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
