#!/usr/bin/env python3
"""Refactor IIgs asm: BCK_BASE→BCK_PIXELS long; BANK2 actor idiom→ACTORS+field.

Usage:
  python3 py/refactor_actor_bck.py
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IIGS = ROOT / "iigs"

# Actor field offsets (must match equates.s)
FIELDS = {
    0: "ACT_X",
    2: "ACT_Y",
    4: "ACT_OX",
    6: "ACT_OY",
    8: "ACT_SPR",
    9: "ACT_FLAGS",
    10: "ACT_WP",
    11: "ACT_COLOR",
    12: "ACT_DEST",
    14: "ACT_BDEST",
}


def refactor_bank2_actors(text: str) -> str:
    """>BANK2+ACT_*,x → >ACTORS+ACT_*,x; >$0200xx,x → field form."""
    text = re.sub(r">BANK2\+(ACT_\w+)", r">ACTORS+\1", text)
    # Hardcoded >$0200xx,x from rails (low byte = field offset)
    for off, name in FIELDS.items():
        text = re.sub(
            rf">\$0200{off:02X}\b",
            f">ACTORS+{name}",
            text,
            flags=re.IGNORECASE,
        )
    # Bare >BANK2,x used as Y-word at X=ACTORS16+idx*16+ACT_OY — leave BANK2
    # for HUD/score (bank-$02 offset idiom); only touch actor comment blocks later.
    return text


def refactor_bck(text: str) -> str:
    text = re.sub(r"\bBCK_BASE\b", "BCK_PIXELS", text)
    return text


def drop_actors16_add(text: str) -> str:
    """Remove clc/adc #ACTORS16 (X becomes index*16 only)."""
    # Multi-line: clc \n adc #ACTORS16
    text = re.sub(
        r"\tclc\n\tadc\t#ACTORS16\n",
        "",
        text,
    )
    text = re.sub(r"\tadc\t#ACTORS16\n", "", text)
    text = re.sub(r"\tadc\t#\$8400\n", "", text)
    # ldx #$8400 → ldx #0 ; #$8410 → #16 etc.
    def ldx_actor(m: re.Match) -> str:
        off = int(m.group(1), 16)
        if off < 0x8400 or off > 0x8450:
            return m.group(0)
        idx_off = off - 0x8400
        return f"\tldx\t#{idx_off}"

    text = re.sub(r"\tldx\t#\$84([0-9A-Fa-f]{2})\b", ldx_actor, text)
    text = re.sub(r"\tldx\t#ACTORS16\b", "\tldx\t#0", text)
    return text


def main() -> None:
    files = [
        "render_body.s",
        "rails_body.s",
        "harness_body.s",
        "hud_body.s",
        "actor_publish.s",
        "game_init.s",
        "level_fsm.s",
        "shr_body.s",
    ]
    for name in files:
        path = IIGS / name
        if not path.exists():
            continue
        text = path.read_text()
        orig = text
        text = refactor_bck(text)
        text = refactor_bank2_actors(text)
        text = drop_actors16_add(text)
        if text != orig:
            path.write_text(text)
            print(f"updated {name}")
        else:
            print(f"unchanged {name}")


if __name__ == "__main__":
    main()
