#!/usr/bin/env python3
"""Rewrite Merlin32-hostile long-addr RMW (inc/dec/stz >addr) to lda/op/sta.

Usage: python3 py/fix_merlin_long_rmw.py [files...]
Default: iigs game-logic sources that use >RAM equates.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT = [
    ROOT / "iigs" / "ghost_ai.s",
    ROOT / "iigs" / "ghost_move.s",
    ROOT / "iigs" / "mspac_move.s",
    ROOT / "iigs" / "play_tick.s",
    ROOT / "iigs" / "level_fsm.s",
    ROOT / "iigs" / "fruit.s",
    ROOT / "iigs" / "collide.s",
    ROOT / "iigs" / "game_init.s",
    ROOT / "iigs" / "maze_state.s",
]

# Optional local label (:name) before the opcode.
PAT = re.compile(
    r"^([ \t]*)(:[A-Za-z0-9_]+\t)?(inc|dec|stz)\t>(\S+)(.*)$", re.M
)


def rewrite(text: str) -> tuple[str, int]:
    def repl(m: re.Match[str]) -> str:
        ind, lab, op, sym, rest = (
            m.group(1),
            m.group(2) or "",
            m.group(3),
            m.group(4),
            m.group(5),
        )
        if op == "stz":
            return f"{ind}{lab}lda\t#0{rest}\n{ind}\tsta\t>{sym}"
        return f"{ind}{lab}lda\t>{sym}{rest}\n{ind}\t{op}\n{ind}\tsta\t>{sym}"

    return PAT.subn(repl, text)


def main() -> int:
    paths = [Path(p) for p in sys.argv[1:]] or DEFAULT
    for p in paths:
        t = p.read_text()
        t2, n = rewrite(t)
        if n:
            p.write_text(t2)
            print(f"{p}: {n} replacements")
        else:
            print(f"{p}: no change")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
