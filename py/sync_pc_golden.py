#!/usr/bin/env python3
"""Insert golden `db` ONLY for address gaps; keep real Z80 + comments.

Rules (see AGENTS.md):
  - Never rewrite instructions into a ROM dump.
  - Gap-fill missing address ranges from boot1-6.
  - Lines with `; @AAAA` but no listing hex still count (size estimated).
  - On overlapping `; @AAAA` emits, comment the line out (text preserved).
  - Place `org #0000` before first code; pad to `#8000` before high ROM.

Usage:
  python3 py/sync_pc_golden.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "py"))
from z80_size import estimate_size  # noqa: E402

ASM = ROOT / "src" / "mspac.asm"

# Optional hex after @addr
AT_LINE = re.compile(
    r"^(\s*)(\S+.*?)\s*;\s*@([0-9A-Fa-f]{4})(?:\s+([0-9A-Fa-f]+))?\b(.*)$"
)
LABEL_ONLY = re.compile(r"^([A-Za-z_][A-Za-z0-9_.]*):(\s*(;.*)?)?$")

AT_TYPOS = {
    0x4445: 0x0445,
    0x3FFD: 0x33FD,
}

MAP_ORG0_MARK = ";; CPU memory map (mspacmab): 0000-3FFF, 8000-9FFF"
MAP_HIGH_MARK = ";; Pad through 4000-7FFF (RAM/IO hole), then aux/high ROM"
GAP_MARK = ";; gap-fill from golden boots"


def load_golden() -> bytes:
    parts = [(ROOT / n).read_bytes() for n in ("boot1", "boot2", "boot3", "boot4")]
    parts.append(bytes(0x4000))
    parts.extend((ROOT / n).read_bytes() for n in ("boot5", "boot6"))
    img = b"".join(parts)
    assert len(img) == 0xA000, hex(len(img))
    return img


def db_bytes(data: bytes, addr: int) -> list[str]:
    lines = [f"\t; {GAP_MARK} ${addr:04X}-${addr + len(data) - 1:04X}\n"]
    for i in range(0, len(data), 16):
        chunk = data[i : i + 16]
        body = ",".join(f"#{b:02X}" for b in chunk)
        lines.append(f"\tdb\t{body}\t\t; @{addr + i:04X}\n")
    return lines


def strip_prior(lines: list[str]) -> list[str]:
    out: list[str] = []
    skip = False
    for line in lines:
        raw = line.rstrip("\r\n")
        if GAP_MARK in raw or MAP_ORG0_MARK in raw or MAP_HIGH_MARK in raw:
            skip = True
            continue
        if skip:
            if (
                raw.startswith(";;;;;;;;")
                or raw.strip().startswith("db\t")
                or raw.strip()
                in (
                    "org\t#0000",
                    "org #0000",
                    "org\t#8000",
                    "org #8000",
                    "assert\t$ <= #4000",
                    "ds\t#8000 - $",
                )
                or raw.startswith(";; CPU")
                or raw.startswith(";; Pad")
                or raw.startswith(";; gap-fill")
            ):
                continue
            if not raw.strip():
                skip = False
                continue
            skip = False
        if raw.strip() in ("org\t#0000", "org #0000"):
            continue
        out.append(line)
    return out


def insn_len(left: str, hx: str | None) -> int | None:
    if hx and len(hx) % 2 == 0 and re.fullmatch(r"[0-9A-Fa-f]+", hx):
        return len(hx) // 2
    return estimate_size(left)


def main() -> int:
    golden = load_golden()
    lines = strip_prior(ASM.read_bytes().decode("latin-1").splitlines(keepends=True))

    # Pass 1: all @addrs that will emit (after typo fix), for out-of-order detection
    all_addrs: list[int] = []
    for line in lines:
        raw = line.rstrip("\r\n")
        if not raw.strip() or raw.lstrip().startswith(";"):
            continue
        raw = re.sub(
            r";\s*@([0-9A-Fa-f]{4})\b",
            lambda m: f"; @{AT_TYPOS[int(m.group(1), 16)]:04X}"
            if int(m.group(1), 16) in AT_TYPOS
            else m.group(0),
            raw,
        )
        m = AT_LINE.match(raw)
        if not m:
            continue
        left, addr_s, hx = m.group(2).strip(), m.group(3), m.group(4)
        if insn_len(left, hx) is None:
            continue
        all_addrs.append(int(addr_s, 16))
    addr_set = set(all_addrs)

    out: list[str] = []
    last_end = 0
    saw_high = False
    inserted_org0 = False
    inserted_high = False
    stats = {
        "gaps": 0,
        "gap_bytes": 0,
        "typos": 0,
        "overlaps_commented": 0,
        "reorder_commented": 0,
        "premature_commented": 0,
        "sized_nohex": 0,
        "unsized": 0,
        "org0": 0,
        "high": 0,
    }

    def emit_gap(to_addr: int) -> None:
        nonlocal last_end, inserted_high
        if to_addr <= last_end:
            return

        if last_end < 0x8000 <= to_addr:
            if last_end < 0x4000:
                chunk = golden[last_end:0x4000]
                if chunk:
                    out.extend(db_bytes(chunk, last_end))
                    stats["gaps"] += 1
                    stats["gap_bytes"] += len(chunk)
                last_end = 0x4000
            if not inserted_high:
                out.append("\n;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;\n")
                out.append(MAP_HIGH_MARK + "\n")
                out.append("\tds\t#8000 - $\n")
                out.append("\torg\t#8000\n")
                out.append(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;\n\n")
                inserted_high = True
                stats["high"] = 1
            last_end = max(last_end, 0x8000)

        if to_addr <= last_end:
            return
        if 0x4000 <= last_end < 0x8000:
            last_end = 0x8000
            if to_addr <= last_end:
                return

        chunk = golden[last_end:to_addr]
        if chunk:
            out.extend(db_bytes(chunk, last_end))
            stats["gaps"] += 1
            stats["gap_bytes"] += len(chunk)
        last_end = to_addr

    for line in lines:
        raw = line.rstrip("\r\n")
        ending = line[len(raw) :] or "\n"

        def typo_repl(m: re.Match[str]) -> str:
            a = int(m.group(1), 16)
            if a in AT_TYPOS:
                stats["typos"] += 1
                return f"; @{AT_TYPOS[a]:04X}"
            return m.group(0)

        raw = re.sub(r";\s*@([0-9A-Fa-f]{4})\b", typo_repl, raw)

        if not raw.strip() or raw.lstrip().startswith(";"):
            out.append(raw + ending)
            continue

        s = raw.lstrip()

        if not inserted_org0:
            m_early = AT_LINE.match(raw)
            is_entry = s.startswith("j_0000:") or (
                m_early and int(m_early.group(3), 16) < 0x4000
            )
            if is_entry:
                out.append("\n;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;\n")
                out.append(MAP_ORG0_MARK + "\n")
                out.append("\torg\t#0000\n")
                out.append(";;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;\n\n")
                inserted_org0 = True
                stats["org0"] = 1
                last_end = 0

        if LABEL_ONLY.match(s):
            out.append(raw + ending)
            continue

        m = AT_LINE.match(raw)
        if not m:
            out.append(raw + ending)
            continue

        left = m.group(2).strip()
        addr = int(m.group(3), 16)
        hx = m.group(4)
        blen = insn_len(left, hx)
        if blen is None:
            stats["unsized"] += 1
            out.append(raw + ending)
            continue
        if hx is None:
            stats["sized_nohex"] += 1

        if saw_high and addr < 0x8000:
            out.append(";" + raw + ending)
            stats["reorder_commented"] += 1
            continue

        if addr < last_end:
            out.append(";" + raw + ending)
            stats["overlaps_commented"] += 1
            continue

        # Premature out-of-order line: jumping forward over addresses that
        # appear later in the file (e.g. leftover @35B0 before real @3435).
        if addr > last_end:
            skipped = [
                a
                for a in addr_set
                if last_end <= a < addr and a != addr
            ]
            if skipped:
                out.append(";" + raw + ending)
                stats["premature_commented"] += 1
                continue
            emit_gap(addr)

        out.append(raw + ending)
        last_end = addr + blen
        if addr >= 0x8000:
            saw_high = True

    if last_end and last_end < 0xA000:
        emit_gap(0xA000)

    ASM.write_bytes("".join(out).encode("latin-1", errors="replace"))
    print(
        f"{ASM}: gaps={stats['gaps']} gap_bytes={stats['gap_bytes']} "
        f"typos={stats['typos']} overlaps_commented={stats['overlaps_commented']} "
        f"reorder_commented={stats['reorder_commented']} "
        f"premature_commented={stats['premature_commented']} "
        f"sized_nohex={stats['sized_nohex']} unsized={stats['unsized']} "
        f"org0={stats['org0']} high={stats['high']} last_end={last_end:#x}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
