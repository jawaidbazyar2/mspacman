#!/usr/bin/env python3
"""Check that lower/ is still the locked idiom/ plus entry hooks.

For each idiom/*.c and *.h, the lower/ copy must match once its
LOWER_HOOK(...) lines are dropped. A file with any other difference must
say why in a "LOWER-FIX:" comment near its top; those are listed, not
failed. Anything else fails.

Usage:
  python3 py/lower_diff.py
"""

from __future__ import annotations

import difflib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IDIOM = ROOT / "idiom"
LOWER = ROOT / "lower"
HOOK_RE = re.compile(r"^\s*LOWER_HOOK\(.*\);\s*$")


def main() -> int:
    bad = 0
    hooks = 0
    fixes = []
    for src in sorted(list(IDIOM.glob("*.c")) + list(IDIOM.glob("*.h"))):
        dst = LOWER / src.name
        if not dst.exists():
            print(f"lower_diff: {dst.relative_to(ROOT)} is missing")
            bad += 1
            continue
        a = src.read_text(encoding="utf-8").splitlines()
        b_all = dst.read_text(encoding="utf-8").splitlines()
        b = [ln for ln in b_all if not HOOK_RE.match(ln)]
        hooks += len(b_all) - len(b)
        if a == b:
            continue
        head = "\n".join(b_all[:30])
        if "LOWER-FIX:" in head:
            fixes.append(dst.name)
            continue
        print(f"lower_diff: {dst.relative_to(ROOT)} differs from idiom/ by more than hooks:")
        for line in list(difflib.unified_diff(a, b, "idiom/" + src.name,
                                              "lower/" + src.name, lineterm="",
                                              n=1))[:20]:
            print("  " + line)
        bad += 1
    for name in fixes:
        print(f"lower_diff: {name} carries a LOWER-FIX")
    if bad:
        print(f"lower_diff: {bad} file(s) differ")
        return 1
    print(f"lower_diff: ok, {hooks} hooks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
