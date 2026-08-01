#!/usr/bin/env python3
"""Strip leading listing address/hex columns from src/mspac.asm.

Moves them to trailing reference comments:
  0195  3a004e    ld a,(game_mode) ; foo
    ->  ld a,(game_mode)           ; @0195 3A004E  foo

Also writes build/listing_index.txt (original addr -> new source line).

Does not modify the read-only master ./mspac.asm.

Usage:
  python3 py/strip_listing_columns.py
  python3 py/strip_listing_columns.py path/to/file.asm
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ASM = ROOT / "src" / "mspac.asm"
INDEX_PATH = ROOT / "build" / "listing_index.txt"

# Common Z80 mnemonics / directives that end a hex-byte run
MNEMONICS = {
    "adc", "add", "and", "bit", "call", "ccf", "cp", "cpd", "cpdr", "cpi", "cpir",
    "cpl", "daa", "dec", "di", "djnz", "ei", "ex", "exx", "halt", "im", "in",
    "inc", "ind", "indr", "ini", "inir", "jp", "jr", "ld", "ldd", "lddr", "ldi",
    "ldir", "neg", "nop", "or", "otdr", "otir", "out", "outd", "outi", "pop",
    "push", "res", "ret", "reti", "retn", "rl", "rla", "rlc", "rlca", "rld",
    "rr", "rra", "rrc", "rrca", "rrd", "rst", "sbc", "scf", "set", "sla", "sll",
    "sra", "srl", "sub", "xor",
    # assembler-ish that sometimes appear after an address in this file
    "db", "dw", "defb", "defw", "defs", "ds", "org", "equ", "include",
}

ADDR_PREFIX = re.compile(r"^([0-9A-Fa-f]{4})\s*:?\s+(.*)$")
HEX_BYTE = re.compile(r"^([0-9A-Fa-f]{2})\b")
HEX_RUN = re.compile(r"^([0-9A-Fa-f]{2,})")  # glued bytes


def read_text(path: Path) -> str:
    data = path.read_bytes()
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


def split_hex_prefix(rest: str) -> tuple[list[str], str]:
    """Pull leading hex bytes (spaced or glued) off rest; return (bytes, remainder)."""
    bytes_out: list[str] = []
    s = rest.lstrip()
    if not s:
        return [], rest

    # Prefer token-wise: "3a 00 4e    ld ..." or "3a004e    ld ..."
    # First try glued run only if followed by whitespace + mnemonic/comment/end
    m_run = HEX_RUN.match(s)
    if m_run and len(m_run.group(1)) >= 2 and len(m_run.group(1)) % 2 == 0:
        glued = m_run.group(1)
        after = s[m_run.end() :]
        after_st = after.lstrip()
        first = after_st.split(None, 1)[0].lower() if after_st else ""
        first = first.rstrip(":")
        if (
            not after_st
            or after_st.startswith(";")
            or first in MNEMONICS
            or re.match(r"^[a-zA-Z_][a-zA-Z0-9_]*$", first)
            and first.lower() in MNEMONICS
        ):
            for i in range(0, len(glued), 2):
                bytes_out.append(glued[i : i + 2].upper())
            return bytes_out, after

    # Spaced bytes: "94 08\t\t; comment" or "00 01 02 03 ..."
    while True:
        m = HEX_BYTE.match(s)
        if not m:
            break
        # Don't treat mnemonic-looking tokens as hex (none are 2-hex-only among MNEMONICS
        # except we could confuse "or" — not hex. "ad" isn't a mnemonic. OK.)
        nbytes_would = bytes_out + [m.group(1).upper()]
        after = s[m.end() :].lstrip()
        # Stop before a mnemonic word
        if after:
            tok = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\b", after)
            if tok and tok.group(1).lower() in MNEMONICS:
                bytes_out.append(m.group(1).upper())
                s = s[m.end() :]
                break
        bytes_out.append(m.group(1).upper())
        s = s[m.end() :]
        # require whitespace or end between spaced bytes
        if s.startswith(" ") or s.startswith("\t"):
            s = s.lstrip()
            continue
        if not s or s.startswith(";"):
            break
        # glued remainder without space — only if even hex
        m2 = HEX_RUN.match(s)
        if m2 and len(m2.group(1)) % 2 == 0 and re.fullmatch(r"[0-9A-Fa-f]+", m2.group(1)):
            glued = m2.group(1)
            for i in range(0, len(glued), 2):
                bytes_out.append(glued[i : i + 2].upper())
            s = s[m2.end() :]
        break

    return bytes_out, s


def normalize_mnemonic_spacing(body: str) -> str:
    body = body.strip()
    if not body:
        return body
    if body.startswith(";"):
        return body
    # keep one tab indent for code/data
    return "\t" + body


def transform_line(line: str) -> tuple[str, int | None]:
    """Return (new_line_without_newline, original_addr_or_None)."""
    if not line.strip():
        return line, None

    # Preserve full-line comments / labels / bare directives without addr prefix
    stripped = line.lstrip()
    if stripped.startswith(";") or stripped.startswith("!"):
        return line, None
    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*:\s*(;.*)?$", stripped):
        return line, None
    if re.match(r"^(include|INCLUDE|ORG|org|EQU|equ)\b", stripped):
        return line, None
    # Prose / hack notes (no address column)
    m_addr = ADDR_PREFIX.match(line)
    if not m_addr:
        return line, None

    addr = int(m_addr.group(1), 16)
    rest = m_addr.group(2)
    hex_bytes, after = split_hex_prefix(rest)
    after = after.lstrip() if after is not None else ""

    hex_str = "".join(hex_bytes) if hex_bytes else ""
    ref = f"@{addr:04X}"
    if hex_str:
        ref += f" {hex_str}"

    if not after:
        # Pure data bytes
        if hex_bytes:
            db = ",".join(f"#{b}" for b in hex_bytes)
            return f"\tdb\t{db}\t\t; {ref}", addr
        return line, None

    if after.startswith(";"):
        # Data + comment only
        if hex_bytes:
            db = ",".join(f"#{b}" for b in hex_bytes)
            comment = after[1:].lstrip()
            if comment:
                return f"\tdb\t{db}\t\t; {ref}  {comment}", addr
            return f"\tdb\t{db}\t\t; {ref}", addr
        return f"\t\t\t; {ref}  {after[1:].lstrip()}", addr

    # Mnemonic / code line: split existing comment
    code = after
    comment = ""
    if "\t;" in code:
        code, comment = code.split("\t;", 1)
        comment = comment.lstrip()
    elif " ;" in code:
        # only split on space-semicolon near end-ish; avoid `#;` unlikely
        idx = code.find(" ;")
        # Prefer last " ;" for safety
        idx = code.rfind(" ;")
        if idx != -1:
            comment = code[idx + 2 :].lstrip()
            code = code[:idx].rstrip()
    elif code.startswith(";") is False and re.search(r"\s+;", code):
        parts = re.split(r"\s+;", code, maxsplit=1)
        if len(parts) == 2:
            code, comment = parts[0].rstrip(), parts[1].lstrip()

    code = code.strip()
    # If what remains isn't an instruction (still looks like hex-only residue), DB it
    tok0 = code.split(None, 1)[0].lower().rstrip(":") if code else ""
    if hex_bytes and tok0 and tok0 not in MNEMONICS and re.fullmatch(r"[0-9A-Fa-f]{2,}", tok0):
        # misparsed; treat whole as data — shouldn't happen often
        pass

    if hex_bytes and (not code or tok0 not in MNEMONICS) and re.match(
        r"^[0-9A-Fa-f]{2}(\s+[0-9A-Fa-f]{2})*$", code.replace(",", " ")
    ):
        db = ",".join(f"#{b}" for b in hex_bytes)
        if comment:
            return f"\tdb\t{db}\t\t; {ref}  {comment}", addr
        return f"\tdb\t{db}\t\t; {ref}", addr

    # Sound-doc lines with address but no hex: "2cc4  ld ix,..."
    if not hex_bytes and code:
        if comment:
            return f"\t{code}\t\t; {ref}  {comment}", addr
        return f"\t{code}\t\t; {ref}", addr

    if code:
        if comment:
            return f"\t{code}\t\t; {ref}  {comment}", addr
        return f"\t{code}\t\t; {ref}", addr

    if hex_bytes:
        db = ",".join(f"#{b}" for b in hex_bytes)
        return f"\tdb\t{db}\t\t; {ref}", addr

    return line, None


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_ASM
    if path.resolve() == (ROOT / "mspac.asm").resolve():
        print("refusing to modify read-only master mspac.asm", file=sys.stderr)
        return 1

    text = read_text(path)
    out_lines: list[str] = []
    index: list[tuple[int, int, str]] = []  # addr, new_lineno, snippet
    converted = 0
    for line in text.splitlines(keepends=True):
        if line.endswith("\r\n"):
            ending, body = "\r\n", line[:-2]
        elif line.endswith("\n"):
            ending, body = "\n", line[:-1]
        else:
            ending, body = "", line
        new_body, addr = transform_line(body)
        if addr is not None and new_body != body:
            converted += 1
        out_lines.append(new_body + ending)
        if addr is not None:
            lineno = len(out_lines)
            snippet = new_body.strip()[:80]
            index.append((addr, lineno, snippet))

    path.write_bytes("".join(out_lines).encode("latin-1", errors="replace"))

    INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    with INDEX_PATH.open("w", encoding="utf-8") as f:
        f.write("# original_addr  source_line  snippet\n")
        for addr, lineno, snippet in index:
            f.write(f"{addr:04X}\t{lineno}\t{snippet}\n")

    print(f"{path}: converted_lines={converted}, index_entries={len(index)}")
    print(f"wrote {INDEX_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
