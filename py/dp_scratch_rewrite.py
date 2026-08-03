#!/usr/bin/env python3
"""Move the R_* render scratch from bank $02 into low direct page.

The scratch used to live at $02/8A00-$02/8A21 and was reached with long
addressing (`>R_TMP`, 6 cycles / 4 bytes). Direct page is always bank $00, so
it survives the DBR=$01 switch the blit routines do while costing only
4 cycles / 2 bytes. DP is $0000 (set once by the `tcd` in iigs/all.s).

This rewrites:
  iigs/render_body.s   `>R_xxx`     -> `<R_xxx`
  iigs/harness_body.s  `>$028Axx`   -> `<R_xxx`
  py/gen_ghost_work_blit.py  emitted `>R_TMP` -> `<R_TMP`

Idempotent: re-running on already-converted sources is a no-op.

Usage:
  python3 py/dp_scratch_rewrite.py
  python3 py/dp_scratch_rewrite.py --check    # report only, do not write
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Old bank-$02 address -> symbol. Kept here so the harness source, which spelled
# the scratch as raw long addresses, can be lifted to symbols in one pass.
ADDR_TO_SYM = {
    "028A00": "R_X",
    "028A02": "R_Y",
    "028A04": "R_TX",
    "028A06": "R_TY",
    "028A08": "R_TILE",
    "028A0A": "R_OFF",
    "028A0C": "R_DEST",
    "028A0E": "R_ROW",
    "028A10": "R_IDX",
    "028A12": "R_CARRY",
    "028A14": "R_TMP",
    "028A16": "R_ACT",
    "028A18": "R_BASE",
    "028A1A": "R_SAVE",
    "028A1C": "R_BODY",
    "028A1E": "R_BTMP",
    "028A20": "R_BDEST",
}

LONG_SYM = re.compile(r">(R_[A-Z]+)\b")
LONG_ADDR = re.compile(r">\$(028A[0-9A-Fa-f]{2})\b")


def to_dp_symbols(text: str) -> tuple[str, int]:
    """Rewrite long scratch references to direct-page form."""
    n = 0

    def sym_sub(m: re.Match[str]) -> str:
        nonlocal n
        n += 1
        return "<" + m.group(1)

    def addr_sub(m: re.Match[str]) -> str:
        nonlocal n
        key = m.group(1).upper()
        if key not in ADDR_TO_SYM:
            raise SystemExit(f"unmapped scratch address ${key}")
        n += 1
        return "<" + ADDR_TO_SYM[key]

    text = LONG_ADDR.sub(addr_sub, text)
    text = LONG_SYM.sub(sym_sub, text)
    return text, n


TARGETS = (
    Path("iigs/render_body.s"),
    Path("iigs/harness_body.s"),
    Path("py/gen_ghost_work_blit.py"),
)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check", action="store_true", help="report only")
    args = ap.parse_args()

    total = 0
    for rel in TARGETS:
        path = ROOT / rel
        src = path.read_text(encoding="utf-8")
        out, n = to_dp_symbols(src)
        total += n
        print(f"{rel}: {n} reference(s)")
        if n and not args.check:
            path.write_text(out, encoding="utf-8")

    if not args.check:
        stale = LONG_SYM.search((ROOT / "iigs/render_body.s").read_text())
        if stale:
            raise SystemExit(f"long scratch reference survived: {stale.group(0)}")
    print(f"total {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
