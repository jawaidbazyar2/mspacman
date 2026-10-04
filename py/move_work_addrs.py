#!/usr/bin/env python3
"""Rewrite doc peek addresses after the static work block moved $02/A000 -> $04/A000.

Usage: python3 py/move_work_addrs.py FILE...
Rewrites 0x02Axxx and $02Axxx (6-digit work-block addresses), and $02/Axxx in
markdown table rows, to bank $04.
"""
import re
import sys

PAT = re.compile(r"(0x|\$)02(A[0-9A-Fa-f]{3})\b")
# $02/Axxx in markdown table rows (prose keeps its history).
ROW_PAT = re.compile(r"\$02/(A[0-9A-F]{3})\b")

for name in sys.argv[1:]:
    text = open(name, encoding="utf-8").read()
    new, n = PAT.subn(r"\g<1>04\2", text)
    lines = new.split("\n")
    for i, line in enumerate(lines):
        if line.startswith("|"):
            lines[i], k = ROW_PAT.subn(r"$04/\1", line)
            n += k
    new = "\n".join(lines)
    if n:
        open(name, "w", encoding="utf-8").write(new)
    print(f"{name}: {n}")
