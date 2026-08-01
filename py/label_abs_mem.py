#!/usr/bin/env python3
"""Replace documented absolute memory addresses in src/mspac.asm with symbols.

Rewrites:
  (#4E02)           -> (game_mode_sub1)
  ld hl,#4C80       -> ld hl,task_list_tail_ptr
  ld de,#CH1_W_NUM  -> left alone if already symbolic

Only touches non-comment listing/code lines. Does not modify ./mspac.asm.

Usage:
  python3 py/label_abs_mem.py
  python3 py/label_abs_mem.py path/to/file.asm
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from ram_symbols import SYMBOLS  # noqa: E402

# (#4e02) or (#4E02)
MEM_REF = re.compile(r"\(#([0-9A-Fa-f]{4})\)")
# ld rr,#4c80  / ld ix,#4ecc  (16-bit immediate address)
LD_RR_IMM = re.compile(
    r"\b(ld)\s+(bc|de|hl|ix|iy|sp)\s*,\s*#([0-9A-Fa-f]{4})\b",
    re.I,
)
# Already-symbolic forms like (#CH1_W_NUM) or ld hl,#SONG_TABLE_1 — leave alone
ALREADY_SYM = re.compile(r"\(#?[A-Za-z_][A-Za-z0-9_]*\)|,\s*#?[A-Za-z_][A-Za-z0-9_]*\b")


def read_text(path: Path) -> str:
    data = path.read_bytes()
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


def transform_line(line: str) -> tuple[str, int]:
    if not line.strip() or line.lstrip().startswith(";"):
        return line, 0
    # Skip pure comment continuations / prose without listing address
    n = 0

    def mem_sub(m: re.Match) -> str:
        nonlocal n
        addr = int(m.group(1), 16)
        if addr not in SYMBOLS:
            return m.group(0)
        n += 1
        return f"({SYMBOLS[addr][0]})"

    out = MEM_REF.sub(mem_sub, line)

    def ld_sub(m: re.Match) -> str:
        nonlocal n
        addr = int(m.group(3), 16)
        if addr not in SYMBOLS:
            return m.group(0)
        n += 1
        return f"{m.group(1)} {m.group(2)},{SYMBOLS[addr][0]}"

    out = LD_RR_IMM.sub(ld_sub, out)
    return out, n


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "src" / "mspac.asm"
    if path.resolve() == (ROOT / "mspac.asm").resolve():
        print("refusing to modify read-only master mspac.asm", file=sys.stderr)
        return 1
    text = read_text(path)
    total = 0
    used = set()
    out_lines = []
    for line in text.splitlines(keepends=True):
        ending = ""
        raw = line
        if line.endswith("\r\n"):
            ending = "\r\n"
            body = line[:-2]
        elif line.endswith("\n"):
            ending = "\n"
            body = line[:-1]
        else:
            body = line
        new_body, n = transform_line(body)
        if n:
            for m in MEM_REF.finditer(body):
                a = int(m.group(1), 16)
                if a in SYMBOLS:
                    used.add(a)
            for m in LD_RR_IMM.finditer(body):
                a = int(m.group(3), 16)
                if a in SYMBOLS:
                    used.add(a)
        total += n
        out_lines.append(new_body + ending)

    path.write_bytes("".join(out_lines).encode("latin-1", errors="replace"))
    unused = sorted(set(SYMBOLS) - used)
    print(f"{path}: replacements={total}, symbols_used={len(used)}/{len(SYMBOLS)}")
    if unused:
        print(f"documented but not referenced in code operands ({len(unused)}):")
        for a in unused[:40]:
            print(f"  #{a:04X} {SYMBOLS[a][0]}")
        if len(unused) > 40:
            print(f"  ... +{len(unused) - 40} more")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
