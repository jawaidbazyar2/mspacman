#!/usr/bin/env python3
"""Remove '#' only before true symbolic names (not hex immediates).

SjASMPlus uses # as a hex prefix, so (#CH1_W_NUM) is invalid, but (#4E9C) / #EC
must keep the '#'.

Also recovers damage from older runs that stripped # from A-F-leading hex
(e.g. db EC,#92 -> db #EC,#92).

Usage:
  python3 py/fix_hash_symbols.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from ram_symbols import SYMBOLS  # noqa: E402

ASM = ROOT / "src" / "mspac.asm"
SYM_NAMES = {name for name, _ in SYMBOLS.values()}

# (#Name) where Name is not pure hex
RE_MEM_SYM = re.compile(r"\(#([A-Za-z_][A-Za-z0-9_]*)\)")
# #Name as immediate / operand where Name is not pure hex
RE_HASH_IDENT = re.compile(r"#([A-Za-z_][A-Za-z0-9_]*)\b")

REG_PAIRS = {"af", "bc", "de", "hl", "ix", "iy", "sp"}


def is_pure_hex(name: str) -> bool:
    return bool(re.fullmatch(r"[0-9A-Fa-f]+", name)) and len(name) in (1, 2, 3, 4)


def strip_hash_if_symbol(name: str) -> bool:
    """True => remove '#'; False => keep '#'."""
    if is_pure_hex(name):
        return False
    return True


def recover_hex_tokens(code: str) -> str:
    """Put '#' back on bare 2/4-digit hex immediates (not registers/symbols)."""

    # db/dw lists
    def db_sub(m: re.Match) -> str:
        head, args = m.group(1), m.group(2)
        parts = []
        for tok in args.split(","):
            t = tok.strip()
            if not t:
                parts.append(tok)
                continue
            if t.startswith("#"):
                parts.append(t)
            elif re.fullmatch(r"[0-9A-Fa-f]{2}", t, re.I) or re.fullmatch(
                r"[0-9A-Fa-f]{4}", t, re.I
            ):
                parts.append("#" + t.upper())
            else:
                parts.append(t)
        return head + ",".join(parts)

    code = re.sub(r"(^\s*d[bw]\s+)(.+)$", db_sub, code, flags=re.I)

    # ld r,#nn / cp nn / and nn etc. where nn is 2 hex digits starting A-F (or any bare hex)
    def imm8_sub(m: re.Match) -> str:
        pref, tok = m.group(1), m.group(2)
        low = tok.lower()
        if low in REG_PAIRS or low in SYM_NAMES or low.startswith("j_"):
            return m.group(0)
        if re.fullmatch(r"[0-9A-Fa-f]{2}", tok, re.I):
            return pref + "#" + tok.upper()
        return m.group(0)

    code = re.sub(
        r"\b((?:ld\s+(?:a|b|c|d|e|h|l)\s*,\s*|cp\s+|and\s+|or\s+|xor\s+|"
        r"add\s+a\s*,\s*|adc\s+a\s*,\s*|sbc\s+a\s*,\s*|sub\s+|rst\s+))"
        r"([A-Fa-f][0-9A-Fa-f])\b",
        imm8_sub,
        code,
        flags=re.I,
    )

    # ld rr,xxxx 4-digit hex immediate missing #
    def imm16_sub(m: re.Match) -> str:
        pref, tok = m.group(1), m.group(2)
        if tok.lower() in SYM_NAMES or tok.lower().startswith("j_"):
            return m.group(0)
        return pref + "#" + tok.upper()

    code = re.sub(
        r"\b(ld\s+(?:bc|de|hl|ix|iy|sp)\s*,\s*)([A-Fa-f][0-9A-Fa-f]{3})\b",
        imm16_sub,
        code,
        flags=re.I,
    )
    return code


def transform_line(line: str) -> str:
    if not line.strip() or line.lstrip().startswith(";"):
        return line

    # Split trailing comment so we don't alter @ refs
    body, cmt = line, ""
    if "\t;" in line:
        body, cmt = line.split("\t;", 1)
        cmt = "\t;" + cmt
    elif " ;" in line:
        idx = line.rfind(" ;")
        body, cmt = line[:idx], line[idx:]

    def mem_sub(m: re.Match) -> str:
        name = m.group(1)
        if strip_hash_if_symbol(name):
            return f"({name})"
        return m.group(0)

    def hash_sub(m: re.Match) -> str:
        name = m.group(1)
        if strip_hash_if_symbol(name):
            return name
        return m.group(0)

    body = RE_MEM_SYM.sub(mem_sub, body)
    body = RE_HASH_IDENT.sub(hash_sub, body)
    body = recover_hex_tokens(body)
    return body + cmt


def main() -> int:
    data = ASM.read_bytes()
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        text = data.decode("latin-1")

    out = []
    for line in text.splitlines(keepends=True):
        if line.endswith("\r\n"):
            ending, raw = "\r\n", line[:-2]
        elif line.endswith("\n"):
            ending, raw = "\n", line[:-1]
        else:
            ending, raw = "", line
        out.append(transform_line(raw) + ending)

    ASM.write_bytes("".join(out).encode("latin-1", errors="replace"))
    print(f"{ASM}: normalized #hex vs #symbols")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
