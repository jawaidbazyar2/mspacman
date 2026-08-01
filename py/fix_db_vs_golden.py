#!/usr/bin/env python3
"""Fix `db` lines whose listing hex disagrees with boot1-6.

Only touches lines that are already `db` (data). Does not convert instructions.
Keeps the original trailing comment (author notes).

Usage:
  python3 py/fix_db_vs_golden.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASM = ROOT / "src" / "mspac.asm"

DB_AT = re.compile(
    r"^(\s*)db\t([^\t;]+)(\s*;\s*@([0-9A-Fa-f]{4})\b.*)$"
)


def load_golden() -> bytes:
    parts = [(ROOT / n).read_bytes() for n in ("boot1", "boot2", "boot3", "boot4")]
    parts.append(bytes(0x4000))
    parts.extend((ROOT / n).read_bytes() for n in ("boot5", "boot6"))
    return b"".join(parts)


def main() -> int:
    golden = load_golden()
    text = ASM.read_bytes().decode("latin-1")
    out: list[str] = []
    n = 0
    for line in text.splitlines(keepends=True):
        raw = line.rstrip("\r\n")
        ending = line[len(raw) :] or "\n"
        m = DB_AT.match(raw)
        if not m:
            out.append(raw + ending)
            continue
        indent, _ops, cmt, addr_s = m.group(1), m.group(2), m.group(3), m.group(4)
        addr = int(addr_s, 16)
        # Determine length from existing db operands
        ops = [o.strip() for o in m.group(2).split(",") if o.strip()]
        blen = len(ops)
        if blen < 1 or addr + blen > len(golden):
            out.append(raw + ending)
            continue
        # Skip gap-fill markers (already golden)
        if "gap-fill from golden" in cmt:
            out.append(raw + ending)
            continue
        want = golden[addr : addr + blen]
        body = ",".join(f"#{b:02X}" for b in want)
        old = bytes(int(o.lstrip("#"), 16) for o in ops if re.fullmatch(r"#?[0-9A-Fa-f]+", o))
        if old == want:
            out.append(raw + ending)
            continue
        out.append(f"{indent}db\t{body}\t\t{cmt.lstrip()}\n")
        n += 1
    ASM.write_bytes("".join(out).encode("latin-1", errors="replace"))
    print(f"{ASM}: fixed_db_vs_golden={n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
