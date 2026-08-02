#!/usr/bin/env python3
"""Rewrite hard-coded long addresses in iigs/render_body.s to named equates.

Usage:
  python3 py/label_render_addrs.py
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RENDER = ROOT / "iigs" / "render_body.s"

# Longer / more specific first.
REPLACEMENTS: list[tuple[str, str]] = [
    (r">\$037002", ">AST_MAZE_CELLS+2"),
    (r">\$037001", ">AST_MAZE_CELLS+1"),
    (r">\$037000", ">AST_MAZE_CELLS"),
    (r">\$036600", ">AST_MAZE"),
    (r">\$035100", ">AST_MSK_ODD"),
    (r">\$033C00", ">AST_SPR_ODD"),
    (r">\$032700", ">AST_MSK_EVEN"),
    (r">\$031200", ">AST_SPR_EVEN"),
    (r">\$030002", ">AST_TILES+2"),
    (r">\$030001", ">AST_TILES+1"),
    (r">\$030000", ">AST_TILES"),
    (r">\$027803", ">DIRTY_LIST+1"),
    (r">\$027802", ">DIRTY_LIST"),
    (r">\$027800", ">DIRTY_COUNT"),
    (r">\$027902", ">EAT_INDEX"),
    (r">\$027900", ">FRAME_COUNT"),
    (r">\$027000", ">TILEMAP"),
    (r">\$027A1E", ">R_BTMP"),
    (r">\$027A1C", ">R_BODY"),
    (r">\$027A1A", ">R_SAVE"),
    (r">\$027A18", ">R_BASE"),
    (r">\$027A16", ">R_ACT"),
    (r">\$027A14", ">R_TMP"),
    (r">\$027A12", ">R_CARRY"),
    (r">\$027A10", ">R_IDX"),
    (r">\$027A0E", ">R_ROW"),
    (r">\$027A0C", ">R_DEST"),
    (r">\$027A0A", ">R_OFF"),
    (r">\$027A08", ">R_TILE"),
    (r">\$027A06", ">R_TY"),
    (r">\$027A04", ">R_TX"),
    (r">\$027A02", ">R_Y"),
    (r">\$027A00", ">R_X"),
    # Actor fields (X = ACTORS16+…). Save-under rows fixed afterward.
    (r">\$02000B", ">BANK2+ACT_COLOR"),
    (r">\$020009", ">BANK2+ACT_FLAGS"),
    (r">\$020008", ">BANK2+ACT_SPR"),
    (r">\$020006", ">BANK2+ACT_OY"),
    (r">\$020005", ">BANK2+5"),
    (r">\$020004", ">BANK2+ACT_OX"),
    (r">\$020003", ">BANK2+3"),
    (r">\$020002", ">BANK2+ACT_Y"),
    (r">\$020001", ">BANK2+1"),
    (r">\$020000", ">BANK2"),
    (r"#\$7400", "#ACTORS16"),
    (r"#\$7500", "#SAVEUNDER16"),
    (r"adc\t#76\b", "adc\t#PF_ORIGIN_X"),
    (r"adc\t#160-7\b", "adc\t#SHR_ROW_BYTES-7"),
    (r"adc\t#160\b", "adc\t#SHR_ROW_BYTES"),
]


def ensure_bank2_equates(text: str) -> str:
    if re.search(r"^BANK2\s+equ\b", text, re.M):
        return text
    return text.replace(
        "R_BTMP         equ $027A1E\n",
        "R_BTMP         equ $027A1E\n"
        "* Bank $02 long base: >BANK2+field,x with X = ACTORS16 / SAVEUNDER16\n"
        "BANK2          equ $020000\n"
        "ACTORS16       equ $7400\n"
        "SAVEUNDER16    equ $7500\n",
        1,
    )


def fix_saveunder_rows(text: str) -> str:
    """]er / ]su: X is save-under pointer — byte offsets 0..6, not ACT_*."""

    def fix(block: str) -> str:
        return (
            block.replace(">BANK2+ACT_OY,x", ">BANK2+6,x")
            .replace(">BANK2+ACT_OX,x", ">BANK2+4,x")
            .replace(">BANK2+ACT_Y,x", ">BANK2+2,x")
        )

    text = re.sub(
        r"(\]er\tsep\t#\$20\n)(.*?)(\n\trep\t#\$20\n\ttxa\n\tclc\n\tadc\t#7)",
        lambda m: m.group(1) + fix(m.group(2)) + m.group(3),
        text,
        count=1,
        flags=re.S,
    )
    text = re.sub(
        r"(\]su\tsep\t#\$20\n)(.*?)(\n\trep\t#\$20\n\ttxa\n\tclc\n\tadc\t#7)",
        lambda m: m.group(1) + fix(m.group(2)) + m.group(3),
        text,
        count=1,
        flags=re.S,
    )
    return text


def transform(text: str) -> str:
    text = ensure_bank2_equates(text)
    for pat, repl in REPLACEMENTS:
        text = re.sub(pat, repl, text)
    text = fix_saveunder_rows(text)
    # Screen Y origin only (row strides are adc #7 then tax/sta R_OFF, not sta R_Y)
    text = re.sub(r"adc\t#7(\n\tsta\t>R_Y)", r"adc\t#PF_ORIGIN_Y\1", text)
    return text


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    src = RENDER.read_text(encoding="utf-8")
    out = transform(src)
    # Remaining hard-coded $02… / $03… longs?
    left = sorted(set(re.findall(r">\$[0-9A-Fa-f]+", out)))
    if args.dry_run:
        print(out)
        print("remaining:", left, file=__import__("sys").stderr)
        return 0
    RENDER.write_text(out, encoding="utf-8")
    print(f"updated {RENDER}")
    if left:
        print("remaining hard-coded longs:", ", ".join(left))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
