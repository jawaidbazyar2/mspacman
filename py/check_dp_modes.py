#!/usr/bin/env python3
"""Flag absolute addressing that should have been direct page.

The 65816 has no `LDA dp,Y` (only `LDX dp,Y` / `STX dp,Y`). Merlin32 accepts
`lda <SYM,y` and silently emits `LDA abs,Y` instead, which resolves against DB
— $02 in this harness — and reads the code image rather than direct page. That
bug shipped once in SortActorsByY and was invisible in the source.

This scans the Merlin listing for absolute or absolute-indexed opcodes whose
operand lands below $0100. Those are almost certainly meant to be direct page.

Usage:
  python3 py/check_dp_modes.py
  python3 py/check_dp_modes.py --listing build/iigs/harness_Output.txt
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LISTING = ROOT / "build" / "iigs" / "harness_Output.txt"

# 3-byte absolute forms that have a cheaper direct-page counterpart.
ABS_OPCODES = {
    0x0D: "ora abs",
    0x1D: "ora abs,x",
    0x19: "ora abs,y",
    0x2D: "and abs",
    0x3D: "and abs,x",
    0x39: "and abs,y",
    0x4D: "eor abs",
    0x5D: "eor abs,x",
    0x59: "eor abs,y",
    0x6D: "adc abs",
    0x7D: "adc abs,x",
    0x79: "adc abs,y",
    0x8D: "sta abs",
    0x9D: "sta abs,x",
    0x99: "sta abs,y",
    0xAD: "lda abs",
    0xBD: "lda abs,x",
    0xB9: "lda abs,y",
    0xCD: "cmp abs",
    0xDD: "cmp abs,x",
    0xD9: "cmp abs,y",
    0xED: "sbc abs",
    0xFD: "sbc abs,x",
    0xF9: "sbc abs,y",
    0xAE: "ldx abs",
    0xAC: "ldy abs",
    0x8E: "stx abs",
    0x8C: "sty abs",
    0xEC: "cpx abs",
    0xCC: "cpy abs",
}

# "00/0499 : B9 F6 00    |    lda   <{$F6},y"
LINE = re.compile(
    r"\|\s*(?P<bank>[0-9A-F]{2})/(?P<pc>[0-9A-F]{4})\s*:\s*"
    r"(?P<hex>(?:[0-9A-F]{2} )+)\s*\|(?P<text>.*)$"
)


def scan(listing: str) -> list[str]:
    problems: list[str] = []
    for raw in listing.splitlines():
        m = LINE.search(raw)
        if not m:
            continue
        parts = m.group("hex").split()
        if len(parts) != 3:
            continue
        opcode = int(parts[0], 16)
        if opcode not in ABS_OPCODES:
            continue
        operand = int(parts[2], 16) << 8 | int(parts[1], 16)
        if operand >= 0x0100:
            continue
        pc = f"{m.group('bank')}/{m.group('pc')}"
        problems.append(
            f"{pc}  {ABS_OPCODES[opcode]} ${operand:04X}  |{m.group('text').rstrip()}"
        )
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--listing", type=Path, default=DEFAULT_LISTING)
    args = ap.parse_args()

    if not args.listing.is_file():
        raise SystemExit(f"missing listing {args.listing} — run `make iigs` first")

    problems = scan(args.listing.read_text(encoding="utf-8", errors="replace"))
    if problems:
        print(f"{len(problems)} absolute access(es) below $0100 — expected direct page:")
        for p in problems:
            print(f"  {p}")
        return 1
    print(f"{args.listing.name}: no absolute accesses below $0100")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
