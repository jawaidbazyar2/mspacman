#!/usr/bin/env python3
"""Check that jp/jr/call/djnz targets do not land in db-only regions.

Scans assemblable source (default: src/mspac.asm). Uses `; @AAAA HEX` listing
refs to map addresses. Listing hex is taken only from the first contiguous
byte-pair run after `@AAAA` (stops at a double-space or non-hex text so
decoded values like `00b4 (180)` are not counted as ROM bytes).

Also validates little-endian word destinations in `db` tables that immediately
follow `rst #20` (computed jump tables).

Usage:
  python3 py/check_cf_into_db.py
  python3 py/check_cf_into_db.py src/mspac.asm
  python3 py/check_cf_into_db.py --json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

LABEL_RE = re.compile(r"^([A-Za-z_][\w]*)\s*:")
INSN_RE = re.compile(r"^\s*(?:[A-Za-z_][\w]*\s*:\s*)?([a-zA-Z_.][\w.]*)\b")
BRANCH_RE = re.compile(
    r"^\s*(?:(?P<label>\w+)\s*:\s*)?(?P<op>jp|jr|call|djnz)\s+(?P<operand>[^;]+)",
    re.I,
)
# First contiguous hex-byte run after @AAAA (no double-space inside the run).
AT_RE = re.compile(
    r";\s*@([0-9A-Fa-f]{4})\b(?:\s+((?:[0-9A-Fa-f]{2})(?:\s?[0-9A-Fa-f]{2})*))?"
)
RST20_RE = re.compile(r"\brst\s+(?:#?20|20h)\b", re.I)
COND_RE = re.compile(r"^[a-z]+$", re.I)
ROM_RANGES = ((0x0000, 0x4000), (0x8000, 0xA000))


def in_rom(addr: int) -> bool:
    return any(lo <= addr < hi for lo, hi in ROM_RANGES)


def parse_listing_hex(blob: str | None) -> list[int]:
    if not blob:
        return []
    return [int(x, 16) for x in re.findall(r"[0-9A-Fa-f]{2}", blob)]


def count_db_operands(body: str) -> int | None:
    m = re.match(r"^\s*(?:[\w.]+\s*:\s*)?db\b(.*)$", body, re.I)
    if not m:
        return None
    parts = re.findall(
        r"#([0-9A-Fa-f]+)|'([^'])'|\"([^\"]*)\"|([0-9A-Fa-f]+)[Hh]\b|(\d+)\b",
        m.group(1),
    )
    n = 0
    for a, b, c, d, e in parts:
        if a:
            n += 1
        elif b or d or e:
            n += 1
        elif c:
            n += len(c)
    return n or None


def branch_dest(operand: str) -> str | None:
    op = operand.strip()
    if "," in op:
        left, right = [x.strip() for x in op.split(",", 1)]
        if COND_RE.fullmatch(left):
            op = right
        else:
            return None
    if op.startswith("("):
        return None
    return op


def resolve_dest(dest: str, label_addr: dict[str, int]) -> tuple[int | None, str]:
    if dest in label_addr:
        return label_addr[dest], "label"
    m = re.fullmatch(r"j_([0-9A-Fa-f]{4})", dest)
    if m:
        return int(m.group(1), 16), "j_implied"
    for pat in (
        r"\$([0-9A-Fa-f]{1,4})",
        r"#([0-9A-Fa-f]{1,4})",
        r"0x([0-9A-Fa-f]{1,4})",
        r"([0-9A-Fa-f]{1,4})[Hh]",
    ):
        m = re.fullmatch(pat, dest, re.I)
        if m:
            return int(m.group(1), 16), "abs"
    return None, "unresolved"


def build_maps(lines: list[str]):
    addr_kind: dict[int, str] = {}
    addr_owner: dict[int, tuple] = {}
    addr_start: dict[int, bool] = {}
    label_addr: dict[str, int] = {}
    pending: list[str] = []

    for i, line in enumerate(lines, 1):
        lm = LABEL_RE.match(line)
        if lm:
            pending.append(lm.group(1))
            rest = line.split(":", 1)[1].strip()
            if not rest or rest.startswith(";"):
                continue

        if line.lstrip().startswith(";"):
            continue

        am = AT_RE.search(line)
        if not am:
            continue

        addr = int(am.group(1), 16)
        hexblob = parse_listing_hex(am.group(2))
        for lab in pending:
            label_addr[lab] = addr
        pending = []

        body = line.split(";", 1)[0]
        im = INSN_RE.match(body)
        if not im:
            continue
        op = im.group(1).lower()
        if op in ("db", "defb"):
            kind = "db"
            size = len(hexblob) if hexblob else (count_db_operands(body) or 1)
        elif op in ("dw", "defw"):
            kind = "dw"
            size = len(hexblob) if hexblob else 2
        elif op in ("ds", "org", "include", "assert", "equ", "macro", "endm"):
            continue
        else:
            kind = "insn"
            size = len(hexblob) if hexblob else 1

        for off in range(max(size, 1)):
            a = addr + off
            if a in addr_kind:
                continue
            addr_kind[a] = kind
            addr_owner[a] = (i, addr, kind, line.strip()[:120])
            addr_start[a] = off == 0

    return addr_kind, addr_owner, addr_start, label_addr


def analyze(path: Path) -> dict:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    addr_kind, addr_owner, addr_start, label_addr = build_maps(lines)

    into_db: list[dict] = []
    mid_insn: list[dict] = []
    ok = 0
    indirect = 0
    unknown: list[dict] = []

    for i, line in enumerate(lines, 1):
        if line.lstrip().startswith(";"):
            continue
        m = BRANCH_RE.match(line)
        if not m:
            continue
        op = m.group("op").lower()
        dest = branch_dest(m.group("operand"))
        if dest is None:
            indirect += 1
            continue
        tgt, how = resolve_dest(dest, label_addr)
        if tgt is None:
            unknown.append(
                {"line": i, "op": op, "dest": dest, "reason": "unresolved", "text": line.strip()[:100]}
            )
            continue
        if not in_rom(tgt):
            unknown.append(
                {
                    "line": i,
                    "op": op,
                    "dest": dest,
                    "target": f"${tgt:04X}",
                    "reason": "non_rom",
                    "text": line.strip()[:100],
                }
            )
            continue
        kind = addr_kind.get(tgt)
        if kind is None:
            unknown.append(
                {
                    "line": i,
                    "op": op,
                    "dest": dest,
                    "target": f"${tgt:04X}",
                    "reason": "no_coverage",
                    "text": line.strip()[:100],
                }
            )
            continue
        owner = addr_owner[tgt]
        start = addr_start.get(tgt, False)
        if kind in ("db", "dw"):
            into_db.append(
                {
                    "line": i,
                    "op": op,
                    "dest": dest,
                    "target": f"${tgt:04X}",
                    "kind": kind,
                    "mid_byte": not start,
                    "via": how,
                    "owner_line": owner[0],
                    "owner_start": f"${owner[1]:04X}",
                    "owner_text": owner[3],
                    "branch_text": line.strip()[:100],
                }
            )
        elif kind == "insn" and not start:
            mid_insn.append(
                {
                    "line": i,
                    "op": op,
                    "dest": dest,
                    "target": f"${tgt:04X}",
                    "owner_line": owner[0],
                    "owner_start": f"${owner[1]:04X}",
                    "owner_text": owner[3],
                    "branch_text": line.strip()[:100],
                }
            )
        else:
            ok += 1

    # rst #20 jump tables: following db word pairs
    rst20_bad: list[dict] = []
    rst20_ok = 0
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.lstrip().startswith(";") and RST20_RE.search(line.split(";", 1)[0]):
            table_line = i + 1
            j = i + 1
            while j < len(lines):
                s = lines[j].strip()
                if not s or s.startswith(";") or LABEL_RE.match(lines[j]):
                    j += 1
                    continue
                if not re.match(r"^\s*db\b", lines[j], re.I):
                    break
                am = AT_RE.search(lines[j])
                hx = parse_listing_hex(am.group(2) if am else None)
                if not hx:
                    imms = re.findall(r"#([0-9A-Fa-f]{1,2})", lines[j].split(";", 1)[0])
                    hx = [int(x, 16) for x in imms]
                for k in range(0, len(hx) - 1, 2):
                    tgt = hx[k] | (hx[k + 1] << 8)
                    if not in_rom(tgt):
                        continue
                    kind = addr_kind.get(tgt)
                    start = addr_start.get(tgt, False)
                    if kind == "insn" and start:
                        rst20_ok += 1
                    else:
                        owner = addr_owner.get(tgt)
                        rst20_bad.append(
                            {
                                "table_line": table_line,
                                "db_line": j + 1,
                                "target": f"${tgt:04X}",
                                "kind": kind,
                                "mid_byte": (False if kind is None else not start),
                                "owner_line": owner[0] if owner else None,
                                "owner_text": owner[3] if owner else None,
                                "db_text": lines[j].strip()[:100],
                            }
                        )
                j += 1
            i = j
            continue
        i += 1

    # Labels that sit on db (informational)
    labels_on_db = []
    cf_targets: set[int] = set()
    for i, line in enumerate(lines, 1):
        if line.lstrip().startswith(";"):
            continue
        m = BRANCH_RE.match(line)
        if not m:
            continue
        dest = branch_dest(m.group("operand"))
        if dest is None:
            continue
        tgt, _ = resolve_dest(dest, label_addr)
        if tgt is not None:
            cf_targets.add(tgt)

    for lab, a in sorted(label_addr.items(), key=lambda kv: kv[1]):
        if addr_kind.get(a) in ("db", "dw"):
            owner = addr_owner[a]
            labels_on_db.append(
                {
                    "label": lab,
                    "addr": f"${a:04X}",
                    "branched": a in cf_targets,
                    "owner_line": owner[0],
                    "owner_text": owner[3],
                }
            )

    return {
        "path": str(path),
        "coverage": {
            "total": len(addr_kind),
            "insn": sum(1 for v in addr_kind.values() if v == "insn"),
            "db": sum(1 for v in addr_kind.values() if v == "db"),
            "dw": sum(1 for v in addr_kind.values() if v == "dw"),
            "labels": len(label_addr),
        },
        "branches_ok": ok,
        "indirect": indirect,
        "into_db": into_db,
        "mid_insn": mid_insn,
        "unknown": unknown,
        "rst20_ok": rst20_ok,
        "rst20_bad": rst20_bad,
        "labels_on_db": labels_on_db,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "asm",
        nargs="?",
        type=Path,
        default=ROOT / "src" / "mspac.asm",
        help="assemblable source (default: src/mspac.asm)",
    )
    ap.add_argument("--json", action="store_true", help="emit JSON")
    args = ap.parse_args()
    path = args.asm if args.asm.is_absolute() else ROOT / args.asm
    if not path.is_file():
        print(f"error: not found: {path}", file=sys.stderr)
        return 2

    result = analyze(path)
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        c = result["coverage"]
        print(f"File: {result['path']}")
        print(
            f"Coverage: {c['total']} bytes "
            f"(insn={c['insn']} db={c['db']} dw={c['dw']}) labels={c['labels']}"
        )
        print(f"Static branches onto insn start: {result['branches_ok']}")
        print(f"Indirect jp/call (hl/ix/…): {result['indirect']}")
        print(f"Branches into db/dw: {len(result['into_db'])}")
        for b in result["into_db"]:
            mid = " MID" if b["mid_byte"] else " START"
            print(
                f"  L{b['line']}: {b['op']} {b['dest']} -> {b['target']} "
                f"({b['kind']}{mid})"
            )
            print(f"    owner L{b['owner_line']} {b['owner_start']}: {b['owner_text']}")
        print(f"Branches mid-instruction (insn): {len(result['mid_insn'])}")
        for b in result["mid_insn"]:
            print(f"  L{b['line']}: {b['op']} {b['dest']} -> {b['target']}")
            print(f"    owner L{b['owner_line']} {b['owner_start']}: {b['owner_text']}")
        print(f"Unresolved / non-ROM / no coverage: {len(result['unknown'])}")
        for u in result["unknown"]:
            print(
                f"  L{u['line']}: {u['op']} {u['dest']} "
                f"[{u['reason']}] {u.get('target','')}"
            )
        print(
            f"rst #20 table destinations: ok={result['rst20_ok']} "
            f"bad={len(result['rst20_bad'])}"
        )
        for b in result["rst20_bad"]:
            print(
                f"  table L{b['table_line']} db L{b['db_line']}: -> {b['target']} "
                f"kind={b['kind']} mid={b['mid_byte']}"
            )
            if b["owner_text"]:
                print(f"    owner L{b['owner_line']}: {b['owner_text']}")
        branched_db = [x for x in result["labels_on_db"] if x["branched"]]
        print(
            f"Labels on db/dw: {len(result['labels_on_db'])} "
            f"(also branched-to: {len(branched_db)})"
        )
        for x in branched_db:
            print(f"  {x['label']} {x['addr']} L{x['owner_line']}: {x['owner_text']}")

    failed = bool(result["into_db"] or result["rst20_bad"])
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
