#!/usr/bin/env python3
"""Add LOWER_HOOK lines to functions in lower/<file>.c and list them in
lower/entries.txt under [file].

Kinds come from the C types: Board * -> B, WorkRam * -> R, Coord -> c,
uint16_t -> w, any other pointer -> p, everything else (uint8_t, bool,
int, unsigned) -> b. Results: void v, Coord c, uint16_t w, else b.
A pointer to a C local or a string cannot be marshalled: leave that
function out; it is checked through its callers.

Usage:
  python3 py/add_hooks.py FILE [FUNC ...]     # no FUNC: every function
  python3 py/add_hooks.py FILE --skip F1,F2   # every function but these
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "lower" / "entries.txt"

DEF_RE = re.compile(
    r"^(?:static\s+)?(?:inline\s+)?(?P<ret>[A-Za-z_][A-Za-z0-9_ ]*?\**)\s*"
    r"\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\((?P<params>[^)]*)\)\s*$")


def kind_of(ctype: str) -> str:
    t = ctype.replace("const", "").strip()
    if t.startswith("Board") and "*" in t:
        return "B"
    if t.startswith("WorkRam") and "*" in t:
        return "R"
    if "*" in t:
        return "p"
    if t.startswith("Coord"):
        return "c"
    if t.startswith("uint16_t"):
        return "w"
    return "b"


def result_of(ret: str) -> str:
    r = ret.replace("static", "").replace("inline", "").strip()
    if r == "void":
        return "v"
    if r.startswith("Coord"):
        return "c"
    if r.startswith("uint16_t"):
        return "w"
    return "b"


def split_param(p: str) -> tuple[str, str]:
    p = p.strip()
    m = re.match(r"^(.*?)([A-Za-z_][A-Za-z0-9_]*)$", p)
    if not m:
        raise SystemExit(f"cannot parse parameter {p!r}")
    return m.group(1).strip(), m.group(2)


def find_defs(lines: list[str]):
    """(index of the signature line, name, ret, params, index of '{')."""
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line and not line[0].isspace() and "(" in line and not line.startswith(("#", "/", " ", "\t", "}")):
            sig = line
            j = i
            while ")" not in sig and j + 1 < len(lines):
                j += 1
                sig += " " + lines[j].strip()
            if j + 1 < len(lines) and lines[j + 1].strip() == "{" and not sig.rstrip().endswith(";"):
                m = DEF_RE.match(sig.strip())
                if m:
                    params = m.group("params").strip()
                    plist = [] if params in ("", "void") else [split_param(p) for p in params.split(",")]
                    out.append((i, m.group("name"), m.group("ret"), plist, j + 1))
            i = j + 1
            continue
        i += 1
    return out


def update_manifest(group: str, entries: list[str]) -> None:
    text = MANIFEST.read_text(encoding="utf-8").rstrip("\n").split("\n")
    out = []
    i = 0
    found = False
    while i < len(text):
        if text[i].strip() == f"[{group}]":
            found = True
            existing = []
            i += 1
            while i < len(text) and not text[i].strip().startswith("["):
                if text[i].strip():
                    existing.append(text[i])
                i += 1
            names = {e.split()[0] for e in existing}
            merged = existing + [e for e in entries if e.split()[0] not in names]
            out.append(f"[{group}]")
            out += merged
            out.append("")
            continue
        out.append(text[i])
        i += 1
    if not found:
        if out and out[-1].strip():
            out.append("")
        out.append(f"[{group}]")
        out += entries
        out.append("")
    MANIFEST.write_text("\n".join(out).rstrip("\n") + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("file")
    ap.add_argument("funcs", nargs="*")
    ap.add_argument("--skip", default="")
    args = ap.parse_args()
    path = ROOT / "lower" / f"{args.file}.c"
    lines = path.read_text(encoding="utf-8").split("\n")
    defs = find_defs(lines)
    skip = {s for s in args.skip.split(",") if s}
    want = set(args.funcs) if args.funcs else {d[1] for d in defs} - skip
    missing = want - {d[1] for d in defs}
    if missing:
        raise SystemExit(f"not found in {path.name}: {', '.join(sorted(missing))}")
    entries = []
    inserts = []
    for _, name, ret, plist, brace in defs:
        if name not in want:
            continue
        kinds = [kind_of(t) for t, _ in plist]
        entries.append(f"{name}  {result_of(ret)}  {' '.join(kinds)}".rstrip())
        nxt = lines[brace + 1] if brace + 1 < len(lines) else ""
        if "LOWER_HOOK(" in nxt:
            continue
        call = ", ".join([name] + [n for _, n in plist])
        inserts.append((brace + 1, f"\tLOWER_HOOK({call});"))
    for at, text in sorted(inserts, reverse=True):
        lines.insert(at, text)
    path.write_text("\n".join(lines), encoding="utf-8")
    update_manifest(args.file, entries)
    print(f"{path.name}: {len(inserts)} hooks added, {len(entries)} manifest entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
