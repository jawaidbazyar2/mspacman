#!/usr/bin/env python3
"""Comment animation-command pseudo EQUs (LOOP/END/…) and fix ld (hl),nn hex.

The bare line `END = FF` was treated by SjASMPlus as end-of-source, so all
later labels (boot5/boot6) were never defined.

Usage:
  python3 py/comment_pseudo_ops.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASM = ROOT / "src" / "mspac.asm"

PSEUDO = re.compile(
    r"^\s*(LOOP|SETPOS|SETN|SETCHAR|PLAYSOUND|PAUSE|SHOWACT|CLEARACT|END)\s*=",
    re.I,
)
PSEUDO_DASH = re.compile(r"^\s*-\s*=")
COLOR_NOTE = re.compile(r"^\s*A B \(color\)")


def main() -> int:
    text = ASM.read_bytes().decode("latin-1")
    out = []
    n = 0
    for line in text.splitlines(keepends=True):
        raw = line.rstrip("\r\n")
        ending = line[len(raw) :]
        if raw.lstrip().startswith(";"):
            out.append(line)
            continue
        if PSEUDO.match(raw) or PSEUDO_DASH.match(raw) or COLOR_NOTE.match(raw):
            out.append(";" + raw + ending)
            n += 1
        else:
            out.append(line)
    text2 = "".join(out)
    text2, n2 = re.subn(
        r"(\bld\s+\(\s*hl\s*\)\s*,\s*)([A-Fa-f0-9]{2})\b",
        lambda m: f"{m.group(1)}#{m.group(2).upper()}",
        text2,
        flags=re.I,
    )
    ASM.write_bytes(text2.encode("latin-1", errors="replace"))
    print(f"{ASM}: commented_pseudo={n}, fixed_ld_hl_imm={n2}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
