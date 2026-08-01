#!/usr/bin/env python3
"""Convert non-instruction data dump lines into `db`, keeping comments.

- Lines with `; @AAAA HEX` whose left side is not a Z80 opcode → `db` from hex,
  original left text kept in the comment (decoded ASCII, etc.).
- Gas-style `.byte 0x.., ...` → `db #.., ...`

Does not touch real Z80 opcode lines.

Usage:
  python3 py/data_lines_to_db.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASM = ROOT / "src" / "mspac.asm"

AT_HEX = re.compile(
    r"^(\s*)(.+?)\s*;\s*@([0-9A-Fa-f]{4})\s+([0-9A-Fa-f]+)\b(.*)$"
)
DOT_BYTE = re.compile(r"^(\s*)\.byte\s+(.+?)(\s*;.*)?$", re.I)

OPCODE = re.compile(
    r"^(org|ds|dw|db|include|assert|ld|jp|jr|call|ret|reti|retn|push|pop|"
    r"inc|dec|add|adc|sub|sbc|and|or|xor|cp|bit|res|set|rst|ex|exx|di|ei|"
    r"nop|halt|djnz|im|in|out|rl|rr|rlc|rrc|sla|sra|srl|sll|scf|ccf|cpl|neg|"
    r"ldi|ldd|ldir|lddr|cpi|cpd|cpir|cpdr|ini|ind|inir|indr|outi|outd|"
    r"otir|otdr|rla|rra|rlca|rrca|daa)\b",
    re.I,
)


def convert_dot_byte_operands(ops: str) -> str | None:
    parts = []
    for tok in ops.split(","):
        t = tok.strip()
        if not t:
            continue
        m = re.fullmatch(r"0x([0-9A-Fa-f]+)", t)
        if m:
            parts.append(f"#{int(m.group(1), 16):02X}")
            continue
        m = re.fullmatch(r"#?([0-9A-Fa-f]+)", t)
        if m and re.fullmatch(r"[0-9A-Fa-f]+", m.group(1)):
            v = int(m.group(1), 16)
            parts.append(f"#{v:02X}")
            continue
        return None
    return ",".join(parts) if parts else None


def main() -> int:
    text = ASM.read_bytes().decode("latin-1")
    out: list[str] = []
    n_at = 0
    n_dot = 0
    for line in text.splitlines(keepends=True):
        raw = line.rstrip("\r\n")
        ending = line[len(raw) :] or "\n"
        if not raw.strip() or raw.lstrip().startswith(";"):
            out.append(raw + ending)
            continue

        dm = DOT_BYTE.match(raw)
        if dm:
            body = convert_dot_byte_operands(dm.group(2))
            if body:
                cmt = dm.group(3) or ""
                # SjASMPlus: column-0 identifiers are labels — always indent db
                indent = dm.group(1) if dm.group(1).strip() == "" and dm.group(1) else "\t"
                if not indent or not indent[0].isspace():
                    indent = "\t"
                out.append(f"{indent}db\t{body}{cmt}\n")
                n_dot += 1
                continue

        m = AT_HEX.match(raw)
        if not m:
            out.append(raw + ending)
            continue
        indent, left, addr, hx, rest = (
            m.group(1),
            m.group(2).strip(),
            m.group(3),
            m.group(4),
            m.group(5),
        )
        if OPCODE.match(left):
            out.append(raw + ending)
            continue
        if len(hx) % 2 or not re.fullmatch(r"[0-9A-Fa-f]+", hx):
            out.append(raw + ending)
            continue
        body = ",".join(f"#{hx[i:i+2].upper()}" for i in range(0, len(hx), 2))
        cmt = f"; @{addr} {hx.upper()}"
        if left:
            cmt += f"  {left}"
        if rest.strip():
            cmt += " " + rest.strip()
        out.append(f"{indent}db\t{body}\t\t{cmt}\n")
        n_at += 1

    ASM.write_bytes("".join(out).encode("latin-1", errors="replace"))
    print(f"{ASM}: data_lines_to_db={n_at} dot_byte={n_dot}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
