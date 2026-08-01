#!/usr/bin/env python3
"""Finalize src/mspac.asm for a mapped SjASMPlus build.

- Comment leftover junk / prose / mangled listing lines
- Turn `................ ; @AAAA HEX...` back into db #..
- Insert org #0000 at code start
- Before first @8000 code, pad with ds and org #8000 (boot5/boot6 map)

Usage:
  python3 py/finalize_assemble.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASM = ROOT / "src" / "mspac.asm"

DOTS_DB = re.compile(
    r"^(\s*)\.+(\s*;\s*@([0-9A-Fa-f]{4})\s+([0-9A-Fa-f]+)\b.*)$"
)
AT_REF = re.compile(r";\s*@([0-9A-Fa-f]{4})\b")

# Lines to comment (non-assemblable)
JUNK = re.compile(
    r"^\s*("
    r"`|"
    r"\.{2,}|"
    r"entry\s+\d|"
    r"if\s+MSPACMAN|"
    r"#else|"
    r"#endif|"
    r"else\b|"
    r"endif\b|"
    r"0x[0-9a-f]+,\s*\"|"
    r"--\s*$|"
    r"[0-9A-Fa-f]{2}--|"  # mangled cd66-- etc
    r"dd[0-9a-f]{2}--|"
    r"[0-9A-F]{8}(?:\s+[0-9A-F]{8})+"  # raw hex tables
    r")",
    re.I,
)

# Hex-only table lines like "0258 0708 0960 ..."
HEX_ROW = re.compile(r"^\s*([0-9A-Fa-f]{4}\s+){3,}[0-9A-Fa-f]{4}\s*$")
# Compact hex blobs with @ comment already handled; bare blobs:
HEX_BLOB = re.compile(r"^\s*[0-9A-Fa-f]{8,}(?:\s+[0-9A-Fa-f]{8,})+\s*(;.*)?$")


def is_codeish(line: str) -> bool:
    s = line.lstrip()
    if not s or s.startswith(";") or s.startswith(";;"):
        return False
    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:", s):
        return True
    if s.startswith("\t") or (line[:1].isspace() and not s.startswith(";")):
        # indented instruction/db
        return bool(
            re.match(
                r"^(org|ds|dw|db|include|ld|jp|jr|call|ret|push|pop|inc|dec|"
                r"add|adc|sub|sbc|and|or|xor|cp|bit|res|set|rst|ex|di|ei|"
                r"nop|halt|djnz|im|in|out|rl|rr|sla|sra|srl|scf|ccf|cpl|neg|"
                r"ldi|ldd|cpi|assert)\b",
                s,
                re.I,
            )
        )
    return False


def main() -> int:
    text = ASM.read_bytes().decode("latin-1")
    lines = text.splitlines(keepends=True)

    # Pass 1: clean / convert lines
    cleaned: list[str] = []
    stats = {"junk": 0, "dots": 0}
    for line in lines:
        raw = line.rstrip("\r\n")
        ending = line[len(raw) :]
        stripped = raw.lstrip()

        if stripped.startswith(";") or stripped.startswith(";;") or not stripped:
            cleaned.append(line)
            continue

        # dots placeholder with hex in comment -> db
        m = DOTS_DB.match(raw)
        if m:
            indent, rest_cmt, _addr, hx = m.group(1), m.group(2), m.group(3), m.group(4)
            if len(hx) % 2 == 0 and re.fullmatch(r"[0-9A-Fa-f]+", hx):
                db = ",".join(f"#{hx[i:i+2].upper()}" for i in range(0, len(hx), 2))
                cleaned.append(f"{indent}db\t{db}\t\t{rest_cmt.lstrip()}" + ending)
                stats["dots"] += 1
                continue

        if (
            JUNK.match(raw)
            or HEX_ROW.match(raw)
            or HEX_BLOB.match(raw)
            or stripped == "`"
            or re.match(r"^\s*DB\s*;", raw)  # empty DB
            or re.match(r"^\s*db\s*;", raw)
        ):
            cleaned.append(";" + raw + ending)
            stats["junk"] += 1
            continue

        # Mangled instructions containing --
        if re.search(r"#--|--\s|----", raw) and not stripped.startswith(";"):
            cleaned.append(";" + raw + ending)
            stats["junk"] += 1
            continue

        cleaned.append(line)

    # Memory map (org #0000 / pad to #8000) is owned by py/sync_pc_golden.py
    ASM.write_bytes("".join(cleaned).encode("latin-1", errors="replace"))
    print(
        f"{ASM}: junk_commented={stats['junk']} dots_to_db={stats['dots']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
