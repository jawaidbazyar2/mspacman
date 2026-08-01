#!/usr/bin/env python3
"""Comment out known non-assemblable junk lines in src/mspac.asm.

Usage:
  python3 py/comment_junk_lines.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASM = ROOT / "src" / "mspac.asm"

JUNK = re.compile(
    r"^\s*("
    r"----|"
    r"\+-+|"
    r"!|"
    r"offset\s+\d|"
    r"P\s+0x|"
    r"012C\s|"
    # pac leftover pellet/speed dumps: "-D2 D2 D2 ..." or "-01 03 04 ..."
    r"-[0-9A-Fa-f]{2}(?:\s+[0-9A-Fa-f]{2}){2,}|"
    r"--\s*$|"
    r"1140--|"
    # xxd / hexdump style leftover pages
    r"[0-9A-Fa-f]{8}\s{2,}|"
    # raw nybble/bit tables without db
    r"[0-9A-F]{8}(?:\s+[0-9A-F]{8})+\s*$|"
    r"[0-9A-Fa-f]{2}(?:\s+[0-9A-Fa-f]{2}){7,}\s*$|"
    # decoded text / table captions / score legends (not instructions)
    r"CHARACTER\s*/\s*NICKNAME|"
    r"-?SPEEDY|"
    r"(BLINKY|PINKY|INKY|CLYDE|SUE|POKEY|BASHFUL|SPEED\?|XX\s+YY\s+CC)\s*$|"
    r"[A-H]{6,}\s*$|"  # AAAAAAAA … HHHHHHHH tile rows
    r"\d{3,4}\s*$|"  # bare 700 / 1000 / 5000 score table captions
    r"0x[0-9A-Fa-f]+\s*$|"
    r"\.org\b|"
    r"[0-9A-Fa-f]{4}\s+.*PAC-MAN|"
    r"[0-9A-Fa-f]{4}\s+.*Midway|"
    r"@\s*1980\s+Midway"
    r")",
    re.I,
)


def main() -> int:
    data = ASM.read_bytes()
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        text = data.decode("latin-1")

    n = 0
    out = []
    for line in text.splitlines(keepends=True):
        raw = line.rstrip("\r\n")
        ending = line[len(raw) :]
        if raw.lstrip().startswith(";"):
            out.append(line)
            continue
        if JUNK.match(raw):
            out.append(";" + raw + ending)
            n += 1
        else:
            out.append(line)
    ASM.write_bytes("".join(out).encode("latin-1", errors="replace"))
    print(f"{ASM}: commented junk_lines={n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
