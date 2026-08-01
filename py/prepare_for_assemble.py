#!/usr/bin/env python3
"""Comment out non-assemblable prose / patch notes in src/mspac.asm.

- Comment every line before the first `include "ram.inc"` (documentation header),
  except leave that include active.
- Comment column-0 aspirational patch lines: ORG/JP/CALL/NOP/GLOBAL/equ-style
  notes that are not real indented code (SjASMPlus treats col-0 words as labels).

Does not touch ./mspac.asm.

Usage:
  python3 py/prepare_for_assemble.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASM = ROOT / "src" / "mspac.asm"

COL0_PATCH = re.compile(
    r"^(ORG|JP|CALL|NOP|GLOBAL|EQU|DEFC|DL|DW|DB)\b",
    re.I,
)


def main() -> int:
    text = ASM.read_bytes()
    try:
        s = text.decode("utf-8")
    except UnicodeDecodeError:
        s = text.decode("latin-1")

    lines = s.splitlines(keepends=True)
    out: list[str] = []
    before_include = True
    header_n = 0
    patch_n = 0

    for line in lines:
        raw = line.rstrip("\r\n")
        ending = line[len(raw) :]
        stripped = raw.lstrip()

        if before_include:
            if re.match(r'^include\s+"ram\.inc"', stripped, re.I):
                before_include = False
                # SjASMPlus: directives/instructions must not start in column 0
                # (column 0 is for labels). Force a leading tab.
                if not raw[:1].isspace():
                    out.append("\t" + stripped + ending)
                else:
                    out.append(raw + ending)
                continue
            if stripped.startswith(";") or stripped.startswith(";;") or not stripped:
                out.append(raw + ending)
            else:
                out.append(";" + raw + ending)
                header_n += 1
            continue

        # After include: comment column-0 patch/pseudo lines (not labels like j_xxxx:)
        if (
            stripped
            and not stripped.startswith(";")
            and not stripped.startswith("!")
            and not raw[:1].isspace()
            and COL0_PATCH.match(stripped)
            and not re.match(r"^[A-Za-z_][A-Za-z0-9_]*:", stripped)
        ):
            out.append(";" + raw + ending)
            patch_n += 1
            continue

        out.append(raw + ending)

    ASM.write_bytes("".join(out).encode("latin-1", errors="replace"))
    print(f"{ASM}: commented header_lines={header_n}, col0_patch_lines={patch_n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
