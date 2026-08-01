#!/usr/bin/env python3
"""Compare build/mspac.bin slices to golden boot1–boot6.

Usage:
  python3 py/verify_boots.py [build/mspac.bin]
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SLICES = [
    ("boot1", 0x0000),
    ("boot2", 0x1000),
    ("boot3", 0x2000),
    ("boot4", 0x3000),
    ("boot5", 0x8000),
    ("boot6", 0x9000),
]


def main() -> int:
    bin_path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "build" / "mspac.bin"
    b = bin_path.read_bytes()
    bad = 0
    print(f"{bin_path}: {len(b)} bytes")
    for name, off in SLICES:
        want = (ROOT / name).read_bytes()
        got = b[off : off + 0x1000]
        if len(got) < 0x1000:
            print(f"{name}: SHORT ({len(got)} bytes)")
            bad += 1
            continue
        if got == want:
            print(f"{name}: OK")
            continue
        mism = next(i for i in range(0x1000) if got[i] != want[i])
        n = sum(1 for i in range(0x1000) if got[i] != want[i])
        print(
            f"{name}: DIFF  mismatches={n}  first=@{off + mism:04X} "
            f"got={got[mism]:02X} want={want[mism]:02X}"
        )
        bad += 1
    return bad


if __name__ == "__main__":
    raise SystemExit(main())
