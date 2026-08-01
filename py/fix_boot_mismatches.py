#!/usr/bin/env python3
"""Targeted fixes where listing disagrees with boot1-6 or syntax is invalid.

Keeps author comments. Prefer real instructions; use db only for overlay stubs
/ relative forms SjASMPlus cannot express.

Usage:
  python3 py/fix_boot_mismatches.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASM = ROOT / "src" / "mspac.asm"


def main() -> int:
    lines = ASM.read_bytes().decode("latin-1").splitlines(keepends=True)
    out: list[str] = []
    stats = {"dup_song": 0, "syntax": 0, "boot_fix": 0}

    in_dup_song = False
    for line in lines:
        raw = line.rstrip("\r\n")
        ending = line[len(raw) :] or "\n"

        # Duplicate melody block after ;.org 0x9695 (no @addrs) — boots already
        # covered by the @9695/@96A5 lines above.
        if re.search(r";\s*\.org\s*0x9695", raw, re.I) or re.match(
            r"^\s*\.org\s*0x9695", raw, re.I
        ):
            in_dup_song = True
            out.append(";" + raw + ending if not raw.lstrip().startswith(";") else raw + ending)
            stats["dup_song"] += 1
            continue
        if in_dup_song:
            if re.match(r"^\s*;\s*startup song", raw, re.I) or (
                raw.strip().startswith(";") and "startup song" in raw.lower()
            ):
                in_dup_song = False
                out.append(raw + ending)
                continue
            if raw.strip() and not raw.lstrip().startswith(";"):
                out.append(";" + raw + ending)
                stats["dup_song"] += 1
                continue
            out.append(raw + ending)
            continue

        # Bare '(' line (invalid label)
        if re.match(r"^\s*\(\s*$", raw):
            out.append(";" + raw + ending)
            stats["syntax"] += 1
            continue

        # boots: 269E is ld (#4E01),a not (#4E03)
        if re.search(r"ld\s+\(game_mode_sub2\),\s*a\s*;\s*@269E", raw, re.I):
            out.append(
                "\tld\t(game_mode_sub0),a\t\t; @269E 32014E  "
                "store into subroutine # (listing said 4E03/sub2; boots have 4E01)\n"
            )
            stats["boot_fix"] += 1
            continue

        # overlay stub @8088: bytes are 36 0D 1E C9 (not ix form)
        if re.match(r"^\s*db\t#36,#0D\b", raw, re.I) and "@8088" in raw:
            out.append(
                "\tdb\t#36,#0D,#1E,#C9\t\t; @8088 360D1EC9  "
                "overlay stub (listing: ld (ix+#0d),#1e / ret)\n"
            )
            stats["boot_fix"] += 1
            continue
        if re.match(r"^\s*ret\s*;\s*@808A\s+C9", raw, re.I):
            out.append(";" + raw + ending)
            stats["boot_fix"] += 1
            continue
        if re.match(r"^\s*db\t#C9\s*;\s*@808B\b", raw, re.I):
            out.append(";" + raw + ending)
            stats["boot_fix"] += 1
            continue

        # @80CC..80D0 overlay: C9 38 08 1E D2 then jp
        if re.match(r"^\s*ret\s*;\s*@80CC\s+C9", raw, re.I):
            out.append(
                "\tdb\t#C9,#38,#08,#1E,#D2\t\t; @80CC C938081ED2  overlay stub\n"
            )
            stats["boot_fix"] += 1
            continue
        if "@80CD" in raw and (
            re.search(r"jr\s+c,\s*\+#08", raw, re.I)
            or re.match(r"^\s*db\t#38,#08\b", raw, re.I)
        ):
            out.append(";" + raw + ending)
            stats["boot_fix"] += 1
            continue
        if re.match(r"^\s*db\t#1E,#D2\s*;\s*@80CF", raw, re.I):
            out.append(";" + raw + ending)
            stats["boot_fix"] += 1
            continue

        # jr c, +#nn  → db from listing hex (generic)
        m = re.match(
            r"^(\s*)jr\s+c,\s*\+#([0-9A-Fa-f]+)\s*;\s*@([0-9A-Fa-f]{4})\s+([0-9A-Fa-f]+)\b(.*)$",
            raw,
            re.I,
        )
        if m:
            indent, _off, addr, hx, rest = m.groups()
            body = ",".join(f"#{hx[i:i+2].upper()}" for i in range(0, len(hx), 2))
            out.append(
                f"{indent}db\t{body}\t\t; @{addr} {hx.upper()}  jr c, +#{m.group(2)}{rest}\n"
            )
            stats["syntax"] += 1
            continue

        # jr j_19c4 (out of JR range; listing has short relative)
        if re.search(r"jr\s+j_19c4\s*;\s*@81AB\s+1807", raw, re.I):
            out.append(
                "\tdb\t#18,#07\t\t; @81AB 1807  jr $+9 (was jr j_19c4; out of JR range)\n"
            )
            stats["syntax"] += 1
            continue

        # @8187: boots have ED (ldi) then C9 (ret); listing overlay is mangled
        if re.match(r"^\s*ret\s*;\s*@8187\s+C9", raw, re.I):
            out.append(
                "\tdb\t#ED\t\t; @8187 ED  ldi (overlay stub; listing mangled)\n"
                "\tret\t\t; @8188 C9\n"
            )
            stats["boot_fix"] += 1
            continue
        if re.match(r"^\s*db\t#C9\s*;\s*@8188\b", raw, re.I):
            out.append(";" + raw + ending)
            stats["boot_fix"] += 1
            continue

        # Labels that must bind to a later @addr (not preceding gap-fill db)
        if re.match(r"^j_358a:\s*$", raw):
            stats["boot_fix"] += 1
            continue
        if re.match(r"^\s*pop\s+hl\s*;\s*@358A\b", raw, re.I):
            out.append("j_358a:\n")
            out.append(raw + ending)
            stats["boot_fix"] += 1
            continue
        if re.match(r"^j_2bf9:\s*$", raw):
            stats["boot_fix"] += 1
            continue
        if re.search(r";\s*@2BF9\b", raw) and re.match(
            r"^\s*ld\s+de,", raw, re.I
        ):
            out.append("j_2bf9:\n")
            out.append(raw + ending)
            stats["boot_fix"] += 1
            continue

        out.append(raw + ending)

    ASM.write_bytes("".join(out).encode("latin-1", errors="replace"))
    print(
        f"{ASM}: dup_song={stats['dup_song']} syntax={stats['syntax']} "
        f"boot_fix={stats['boot_fix']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
