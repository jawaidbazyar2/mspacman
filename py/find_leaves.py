#!/usr/bin/env python3
"""CALL targets in src/mspac.asm whose bodies never CALL, RST, JP (HL/IX/IY), or HALT.

Usage: python3 py/find_leaves.py [leaves.txt]
"""

import re
import sys
from pathlib import Path

ASM = Path(__file__).resolve().parents[1] / "src" / "mspac.asm"

ADDR = re.compile(r";\s*@([0-9A-Fa-f]{4})\s+([0-9A-Fa-f]+)")
CALL = re.compile(r"^\tcall\s+([A-Za-z_][\w]*)\b", re.I)
LABEL = re.compile(r"^([A-Za-z_][\w]*):\s*(?:;.*)?$")

CALL_OPS = {0xCD, 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC}
COND_RET = {0xC0, 0xC8, 0xD0, 0xD8, 0xE0, 0xE8, 0xF0, 0xF8}
COND_JP = {0xC2, 0xCA, 0xD2, 0xDA, 0xE2, 0xEA, 0xF2, 0xFA}
COND_JR = {0x20, 0x28, 0x30, 0x38, 0x10}


def s8(b: int) -> int:
    return b - 256 if b >= 128 else b


def is_rst(op: int) -> bool:
    return (op & 0xC7) == 0xC7


def main() -> None:
    lines = ASM.read_text(errors="replace").splitlines()
    code: dict[int, bytes] = {}
    names: dict[str, int] = {}
    pending = None
    for line in lines:
        m = LABEL.match(line)
        if m:
            pending = m.group(1)
            continue
        am = ADDR.search(line)
        if not am:
            continue
        addr = int(am.group(1), 16)
        hexbytes = am.group(2)
        if len(hexbytes) % 2:
            continue
        try:
            raw = bytes.fromhex(hexbytes)
        except ValueError:
            continue
        if raw:
            code[addr] = raw
            if pending and pending not in names:
                names[pending] = addr
            pending = None

    call_targets = set()
    for line in lines:
        m = CALL.match(line)
        if m and m.group(1) in names:
            call_targets.add(names[m.group(1)])

    leaves = []
    for entry in sorted(call_targets):
        if entry not in code:
            continue
        seen: set[int] = set()
        stack = [entry]
        bad = False
        rets = 0
        steps = 0
        while stack:
            pc = stack.pop()
            if pc in seen:
                continue
            raw = code.get(pc)
            if raw is None:
                bad = True
                break
            seen.add(pc)
            steps += 1
            if steps > 4096:
                bad = True
                break
            op = raw[0]
            n = len(raw)
            if op in (0xDD, 0xFD) and n >= 2 and raw[1] == 0xE9:
                bad = True
                break
            if op == 0xED and n >= 2 and raw[1] in (0x45, 0x4D):
                rets += 1
                continue
            if op == 0xE9 or op == 0x76 or op in CALL_OPS or is_rst(op):
                bad = True
                break
            if op == 0xC9:
                rets += 1
                continue
            if op in COND_RET:
                rets += 1
                stack.append((pc + 1) & 0xFFFF)
                continue
            if op == 0xC3 and n >= 3:
                stack.append(raw[1] | (raw[2] << 8))
                continue
            if op == 0x18 and n >= 2:
                stack.append((pc + 2 + s8(raw[1])) & 0xFFFF)
                continue
            if op in COND_JP and n >= 3:
                stack.append(raw[1] | (raw[2] << 8))
                stack.append((pc + 3) & 0xFFFF)
                continue
            if op in COND_JR and n >= 2:
                stack.append((pc + 2 + s8(raw[1])) & 0xFFFF)
                stack.append((pc + 2) & 0xFFFF)
                continue
            stack.append((pc + n) & 0xFFFF)
        if bad or rets == 0:
            continue
        size = sum(len(code[a]) for a in seen)
        name = next((nm for nm, ad in names.items() if ad == entry), f"j_{entry:04x}")
        leaves.append((size, entry, name))

    leaves.sort()
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    text = "".join(f"{addr:04X} {size} {name}\n" for size, addr, name in leaves)
    if out_path:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(text)
    sys.stdout.write(text)
    print(f"{len(leaves)} call leaves", file=sys.stderr)


if __name__ == "__main__":
    main()
