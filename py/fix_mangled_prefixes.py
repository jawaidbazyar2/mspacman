#!/usr/bin/env python3
"""Comment out leftover `--HHHH` overlay/listing artifacts.

These are not safe to promote to instructions: the mnemonic often describes
an original/patched form while the bootleg bytes differ. Prefer leaving the
text as a comment and letting gap-fill supply golden bytes.

Usage:
  python3 py/fix_mangled_prefixes.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASM = ROOT / "src" / "mspac.asm"

MANGLED = re.compile(r"^\s*--[0-9A-Fa-f]{0,8}\b")
ELLIPSIS_INSN = re.compile(r"^\s*\S+\s*\.\.\.")
BAD_RELOC = re.compile(r"#\.\+")  # e.g. ld (ix#+.06) listing artifacts
BARE_HEX = re.compile(r"^\s*0x[0-9A-Fa-f]+\s*$")


def main() -> int:
    text = ASM.read_bytes().decode("latin-1")
    out: list[str] = []
    n = 0
    for line in text.splitlines(keepends=True):
        raw = line.rstrip("\r\n")
        ending = line[len(raw) :] or "\n"
        if not raw.strip() or raw.lstrip().startswith(";"):
            out.append(raw + ending)
            continue
        if (
            MANGLED.match(raw)
            or ELLIPSIS_INSN.match(raw)
            or BAD_RELOC.search(raw)
            or BARE_HEX.match(raw)
            or re.match(r"^\s*-SHADOW\b", raw, re.I)
            or re.match(r"^\s*\(.*\):\s*$", raw)  # (label): invalid
        ):
            out.append(";" + raw + ending)
            n += 1
            continue
        out.append(raw + ending)
    ASM.write_bytes("".join(out).encode("latin-1", errors="replace"))
    print(f"{ASM}: mangled_or_ellipsis_commented={n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
