#!/usr/bin/env python3
"""Unlifted CALL targets, including ones frontier.py hides.

Prints every CALL target that is not in c_add_lift. Routines that return
and do not RST, JP (HL), or HALT are listed with their unlifted callees.
The rest are listed with the reason the walk stopped.

Usage: python3 py/remaining.py
"""

import re
from pathlib import Path

ASM = Path(__file__).resolve().parents[1] / "src" / "mspac.asm"
DISPATCH = Path(__file__).resolve().parents[1] / "c" / "dispatch.c"

ADDR = re.compile(r";\s*@([0-9A-Fa-f]{4})\s+([0-9A-Fa-f]+)")
CALL = re.compile(r"^\tcall\s+([A-Za-z_][\w]*)\b", re.I)
LABEL = re.compile(r"^([A-Za-z_][\w]*):\s*(?:;.*)?$")
LIFT = re.compile(r"c_add_lift\(0x([0-9A-Fa-f]+)")

CALL_OPS = {0xCD, 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC}
COND_RET = {0xC0, 0xC8, 0xD0, 0xD8, 0xE0, 0xE8, 0xF0, 0xF8}
COND_JP = {0xC2, 0xCA, 0xD2, 0xDA, 0xE2, 0xEA, 0xF2, 0xFA}
COND_JR = {0x20, 0x28, 0x30, 0x38, 0x10}


def s8(b: int) -> int:
    return b - 256 if b >= 128 else b


def is_rst(op: int) -> bool:
    return (op & 0xC7) == 0xC7


def main() -> None:
    lifted = {int(m.group(1), 16) for m in LIFT.finditer(DISPATCH.read_text())}
    lines = ASM.read_text(errors="replace").splitlines()
    code: dict[int, bytes] = {}
    names: dict[str, int] = {}
    by_addr: dict[int, str] = {}
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
                by_addr.setdefault(addr, pending)
            pending = None

    call_targets = set()
    for line in lines:
        m = CALL.match(line)
        if m and m.group(1) in names:
            call_targets.add(names[m.group(1)])

    ready = []
    blocked = []
    for entry in sorted(call_targets):
        if entry in lifted or entry not in code:
            continue
        seen: set[int] = set()
        stack = [entry]
        reason = ""
        rets = 0
        foreign: list[int] = []
        steps = 0
        while stack:
            pc = stack.pop()
            if pc in seen:
                continue
            raw = code.get(pc)
            if raw is None:
                reason = f"missing bytes at {pc:04X}"
                break
            seen.add(pc)
            steps += 1
            if steps > 4096:
                reason = "walk limit"
                break
            op = raw[0]
            n = len(raw)
            if op in (0xDD, 0xFD) and n >= 2 and raw[1] == 0xE9:
                reason = f"jp (index) at {pc:04X}"
                break
            if op == 0xED and n >= 2 and raw[1] in (0x45, 0x4D):
                rets += 1
                continue
            if op == 0xE9:
                reason = f"jp (hl) at {pc:04X}"
                break
            if op == 0x76:
                reason = f"halt at {pc:04X}"
                break
            if is_rst(op):
                reason = f"rst ${op & 0x38:02X} at {pc:04X}"
                break
            if op in CALL_OPS and n >= 3:
                dest = raw[1] | (raw[2] << 8)
                if dest not in lifted:
                    foreign.append(dest)
                stack.append((pc + n) & 0xFFFF)
                continue
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
        name = by_addr.get(entry, f"j_{entry:04x}")
        if reason or rets == 0:
            if not reason:
                reason = "does not return"
            blocked.append((entry, name, reason))
            continue
        uniq = []
        for dest in foreign:
            if dest not in uniq:
                uniq.append(dest)
        callee = ", ".join(by_addr.get(c, f"{c:04X}") for c in uniq)
        ready.append((len(uniq), entry, name, callee))

    print(f"lifted {len(lifted)}")
    print(f"unlifted call targets that return: {len(ready)}")
    for nforeign, entry, name, callee in ready:
        print(f"  {nforeign} {entry:04X} {name} -> {callee}")
    print(f"unlifted call targets the walk rejects: {len(blocked)}")
    for entry, name, reason in blocked:
        print(f"  {entry:04X} {name}: {reason}")


if __name__ == "__main__":
    main()
