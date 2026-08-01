#!/usr/bin/env python3
"""Assign j_xxxx labels to jp/jr/call/djnz numeric targets in a listing-format asm.

Default: rewrite src/mspac.asm in place (working copy).
Does not touch the read-only master ./mspac.asm.

Usage:
  python3 py/label_control_flow.py
  python3 py/label_control_flow.py path/to/file.asm
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ctrl_with_bytes = re.compile(
    r"^(?P<pre>[0-9A-Fa-f]{4}\s*:?\s+[0-9A-Fa-f]{2}(?:\s*[0-9A-Fa-f]{2}){0,8}\s+)"
    r"(?P<op>jp|jr|call|djnz)\s+(?P<operand>\S+)",
    re.I,
)
ctrl_addr_mnem = re.compile(
    r"^(?P<pre>[0-9A-Fa-f]{4}\s+)"
    r"(?P<op>jp|jr|call|djnz)\s+(?P<operand>\S+)",
    re.I,
)
addr_line = re.compile(
    r"^([0-9A-Fa-f]{4})\s*:?\s+(?:[0-9A-Fa-f]{2}(?:\s*[0-9A-Fa-f]{2}){0,15}|[a-zA-Z])",
    re.I,
)


def parse_target(operand: str):
    op = operand.strip()
    if re.match(r"^[+-]#", op) or re.match(r"^[+-]0x", op, re.I):
        return None, None
    cond, dest = None, op
    if "," in op:
        left, right = op.split(",", 1)
        left, right = left.strip(), right.strip()
        if re.fullmatch(r"[a-z]+", left, re.I) and (
            right.startswith("#")
            or right.lower().startswith("0x")
            or re.search(r"[Hh]$", right)
            or re.fullmatch(r"[0-9A-Fa-f]{2,4}", right)
        ):
            cond, dest = left, right
        else:
            return None, None
    if dest.startswith("("):
        return None, None
    for pat in (
        r"#([0-9A-Fa-f]{1,4})$",
        r"0x([0-9A-Fa-f]{1,4})$",
        r"([0-9A-Fa-f]{1,4})[Hh]$",
    ):
        m = re.fullmatch(pat, dest, re.I)
        if m:
            return int(m.group(1), 16), cond
    return None, None


def match_ctrl(s: str):
    if s.lstrip().startswith(";"):
        return None
    m = ctrl_with_bytes.match(s)
    if m:
        return m
    m = ctrl_addr_mnem.match(s)
    if not m:
        return None
    rest = s[m.end("pre") :]
    if re.match(
        r"^[0-9A-Fa-f]{2}(\s*[0-9A-Fa-f]{2}){0,7}\s+(jp|jr|call|djnz)\b",
        rest,
        re.I,
    ):
        return None
    return m


def line_addr(s: str):
    if s.lstrip().startswith(";"):
        return None
    m = addr_line.match(s)
    return int(m.group(1), 16) if m else None


def lab(a: int) -> str:
    return f"j_{a:04x}"


def read_text(path: Path) -> str:
    data = path.read_bytes()
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


def label_file(path: Path) -> None:
    text = read_text(path)
    lines = text.splitlines(keepends=True)

    targets = set()
    for line in lines:
        m = match_ctrl(line.rstrip("\n"))
        if not m:
            continue
        addr, _ = parse_target(m.group("operand"))
        if addr is not None:
            targets.add(addr)

    new_lines = []
    rewrite_count = 0
    for line in lines:
        s = line.rstrip("\n")
        ending = line[len(s) :]
        m = match_ctrl(s)
        if not m:
            new_lines.append(line)
            continue
        addr, cond = parse_target(m.group("operand"))
        if addr is None:
            new_lines.append(line)
            continue
        new_operand = f"{cond},{lab(addr)}" if cond else lab(addr)
        new_lines.append(
            s[: m.start("operand")] + new_operand + s[m.end("operand") :] + ending
        )
        rewrite_count += 1

    addr_to_line = {}
    all_addrs = []
    for i, line in enumerate(new_lines):
        a = line_addr(line.rstrip("\n"))
        if a is None:
            continue
        all_addrs.append((a, i))
        addr_to_line.setdefault(a, i)

    missing = sorted(t for t in targets if t not in addr_to_line)

    def nearest_insert(addr: int) -> int:
        best = None
        for a, i in all_addrs:
            d = abs(a - addr)
            score = d + (0 if a >= addr else 0.5)
            if best is None or score < best[0]:
                best = (score, a, i)
        if best is None:
            return 0
        _, a, i = best
        return i if a >= addr else i + 1

    insert_at = {}
    equ_addrs = []
    for addr in sorted(targets):
        if addr in addr_to_line:
            insert_at.setdefault(addr_to_line[addr], []).append((addr, True))
        else:
            dists = [abs(a - addr) for a, _ in all_addrs]
            if not dists or min(dists) > 0x100:
                equ_addrs.append(addr)
            else:
                insert_at.setdefault(nearest_insert(addr), []).append((addr, False))

    equ_block = []
    if equ_addrs:
        equ_block += [
            "\n;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;\n",
            ";; Jump/call targets with no code listing (RAM/IO/etc.)\n",
        ]
        for addr in equ_addrs:
            equ_block.append(f"{lab(addr)}\tEQU\t#{addr:04X}\n")
        equ_block.append(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;\n\n")

    final = []
    equ_emitted = False
    first_code = all_addrs[0][1] if all_addrs else 0
    inserted = 0
    for i, line in enumerate(new_lines):
        if not equ_emitted and i >= first_code:
            final.extend(equ_block)
            equ_emitted = True
        if i in insert_at:
            for addr, exact in sorted(insert_at[i], key=lambda x: x[0]):
                name = lab(addr)
                if any(
                    final[j].lstrip().startswith(name + ":")
                    for j in range(max(0, len(final) - 5), len(final))
                ):
                    continue
                if exact:
                    final.append(f"{name}:\n")
                else:
                    final.append(
                        f"{name}:\t\t; target {addr:04X}h (no exact listing line)\n"
                    )
                inserted += 1
        final.append(line)
    if not equ_emitted:
        final = equ_block + final

    path.write_bytes("".join(final).encode("latin-1", errors="replace"))
    print(
        f"{path}: targets={len(targets)} exact={len(targets) - len(missing)} "
        f"orphans={len(missing)} rewrite={rewrite_count} inserted={inserted} "
        f"equ={len(equ_addrs)}"
    )
    if missing:
        print("orphans:", " ".join(f"{a:04x}" for a in missing))


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "src" / "mspac.asm"
    if not path.is_file():
        print(f"missing file: {path}", file=sys.stderr)
        return 1
    if path.resolve() == (ROOT / "mspac.asm").resolve():
        print("refusing to modify read-only master mspac.asm", file=sys.stderr)
        return 1
    label_file(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
