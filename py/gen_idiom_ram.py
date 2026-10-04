#!/usr/bin/env python3
"""Generate ram.h, ram.c and ram.s from py/ram_symbols.py.

Work RAM $4C00–$4FEF becomes a packed WorkRam overlay. A comment range
such as (4E16-4E33) sizes that field. Bytes with no symbol are gap
arrays so every offsetof stays on the arcade address. ram.s holds the
same fields as Merlin32 equates at their arcade addresses.

idiom/ is locked; phase 3 writes into lower/.

Usage:
  python3 py/gen_idiom_ram.py --out-dir lower
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from ram_symbols import SYMBOLS  # noqa: E402

WORK_LO = 0x4C00
WORK_HI = 0x4FEF  # inclusive
# The task list is filled as $40 bytes. The symbol comment stops short of that.
SIZE_OVERRIDE = {
    0x4CC0: 0x40,
}

# Symbols the listing does not name, or names too broadly.
# addr: (name, size, comment). They replace py/ram_symbols.py entries.
EXTRA = {
    0x4D28: ("prev_dir", 4, "ghosts' previous direction (ACT_*)"),
    0x4D2C: ("dir", 5, "actor direction (ACT_*), DIR_*"),
    0x4D99: ("tunnel_slow", 4, "ghost is in a tunnel slowdown area"),
    0x4DA0: ("substate", 4, "ghost substate while alive"),
    0x4DA7: ("frightened", 4, "ghost is blue"),
    0x4DAC: ("ghost_state", 4, "ghost state: 0 alive, else eyes/returning home"),
    0x4DB1: ("reverse", 5, "actor must reverse (ACT_*)"),
    0x4F01: ("marquee_step", 1,
             "marquee bulb phase (0-15). Inside the stack page, above its depth"),
    0x4F02: ("cutscene_script", 12,
             "cutscene actor script pointers, lo/hi per actor"),
    0x4F10: ("cutscene_frame", 6, "cutscene actor animation step"),
    0x4F18: ("cutscene_count", 6, "cutscene actor command countdown"),
    0x4F20: ("cutscene_done", 6, "cutscene actor reached its END"),
    0x4F40: ("cutscene_anim", 12,
             "cutscene actor animation table pointers, lo/hi per actor"),
    0x4F5C: ("cpu_stack", 0x4FC0 - 0x4F5C, "CPU stack (4F5C-4FBF)"),
}

# Arrays of structs. addr: (ctype, name, count, member names). Each member
# is one byte. The symbols inside the span are dropped.
SOUND_MEMBERS = [
    "num", "unused1", "cur_bit",
    "p3", "p4", "p5", "p6", "p7", "p8", "p9", "pa",
    "type", "duration", "dir", "freq", "volume",
]
SPEED_MEMBERS = ["bits[0]", "bits[1]", "bits[2]", "bits[3]"]
STRUCTS = {
    0x4C00: ("SpriteCode", "sprite", 8, ["code", "color"],
             "sprite code and color by slot (SPR_*). Code bits 7-6 are the flips"),
    0x4C10: ("SpritePos", "sprite_pos", 8, ["x", "y"],
             "sprite positions by slot, in hardware order"),
    0x4C20: ("SpriteCode", "sprite_out", 8, ["code", "color"],
             "vblank's copy of sprite[], flips rotated into bits 1-0, for $4FF0"),
    0x4C30: ("SpritePos", "sprite_pos_out", 8, ["x", "y"],
             "vblank's copy of sprite_pos[], for $5060"),
    0x4D00: ("Coord", "pos", 5, ["y", "x"],
             "actor pixel positions (ACT_*)"),
    0x4D0A: ("Coord", "mid_tile", 5, ["y", "x"],
             "actor tile, taken at the middle of the sprite"),
    0x4D14: ("Coord", "step", 5, ["y", "x"],
             "actor direction as a tile step"),
    0x4D1E: ("Coord", "next_step", 5, ["y", "x"],
             "ghosts' chosen step; Ms. Pac's wanted step"),
    0x4D31: ("Coord", "tile", 5, ["y", "x"],
             "actor tile position"),
    0x4D3E: ("Coord", "path_from", 1, ["y", "x"],
             "pathfinding: the ghost's tile"),
    0x4D40: ("Coord", "path_target", 1, ["y", "x"],
             "pathfinding: the target tile"),
    0x4D42: ("Coord", "path_try", 1, ["y", "x"],
             "pathfinding: the neighbor tile being tried"),
    0x4D46: ("SpeedPattern", "pac_speed", 2, SPEED_MEMBERS,
             "Ms. Pac speed: normal, then energized"),
    0x4D4E: ("SpeedPattern", "elroy2_speed", 1, SPEED_MEMBERS,
             "red's cruise elroy 2 speed"),
    0x4D52: ("SpeedPattern", "elroy1_speed", 1, SPEED_MEMBERS,
             "red's cruise elroy 1 speed"),
    0x4D56: ("SpeedPattern", "ghost_speed", 12, SPEED_MEMBERS,
             "ghost speeds, 3 per ghost (ACT_*): SPEED_NORMAL/BLUE/TUNNEL"),
    0x4DD2: ("Coord", "fruit_pos", 1, ["y", "x"],
             "FRUITP: fruit position"),
    0x4F30: ("Coord", "cutscene_frac", 6, ["y", "x"],
             "cutscene actor sub-pixel motion, 1/16 pixel"),
    0x4F50: ("SpriteCode", "cutscene_sprite", 6, ["code", "color"],
             "cutscene sprite codes and colors, copied to sprite[1..6]"),
    0x4E9C: ("SoundChannel", "effect", 3, SOUND_MEMBERS,
             "effect channels 1-3 (CH1_E_* ...)"),
    0x4ECC: ("SoundChannel", "wave", 3, SOUND_MEMBERS,
             "song channels 1-3 (CH1_W_* ...)"),
}

TYPEDEFS = """\
/* A position or step, Y first as the game stores it. */
typedef struct Coord {
\tuint8_t y;
\tuint8_t x;
} Coord;

typedef struct SpriteCode {
\tuint8_t code;  /* sprite number and the two flip bits */
\tuint8_t color;
} SpriteCode;

typedef struct SpritePos {
\tuint8_t x;
\tuint8_t y;
} SpritePos;

/* A 32-bit speed pattern that rotates left once per call. The actor
 * steps when a 1 rotates out. Bytes 0-1 are the high word, 2-3 the low. */
typedef struct SpeedPattern {
\tuint8_t bits[4];
} SpeedPattern;

/* One sound channel, 16 bytes. Effects and songs share the layout except
 * for bytes 3-10. Effects copy those from their 8-byte table entry. Songs
 * set them with commands F1-F4 and keep the song pointer in them. */
typedef struct SoundChannel {
\tuint8_t num;      /* +0 bitmask of sounds requested */
\tuint8_t unused1;  /* +1 */
\tuint8_t cur_bit;  /* +2 the bit now playing */
\tunion {
\t\tstruct {
\t\t\tuint8_t shape;       /* +3 bits 6-4 octave shift, low bits wave select */
\t\t\tuint8_t base;        /* +4 starting frequency */
\t\t\tuint8_t step;        /* +5 added to the frequency each frame */
\t\t\tuint8_t length;      /* +6 bits 6-0 frames per sweep, bit 7 reverse */
\t\t\tuint8_t repeat_step; /* +7 added to the base on each repeat */
\t\t\tuint8_t repeats;     /* +8 sweeps left, 0 forever */
\t\t\tuint8_t volume0;     /* +9 volume; bits 7-4 also give the type */
\t\t\tuint8_t volume_step; /* +10 added to the volume on each repeat */
\t\t} e;
\t\tstruct {
\t\t\tuint8_t select;   /* +3 wave select, command F1 */
\t\t\tuint8_t octave;   /* +4 command F2 */
\t\t\tuint8_t unused5;  /* +5 */
\t\t\tuint8_t ptr_lo;   /* +6 song pointer */
\t\t\tuint8_t ptr_hi;   /* +7 */
\t\t\tuint8_t unused8;  /* +8 */
\t\t\tuint8_t volume0;  /* +9 volume, command F3 */
\t\t\tuint8_t unused10; /* +10 */
\t\t} w;
\t};
\tuint8_t type;     /* +11 volume envelope 0-15 (songs: command F4) */
\tuint8_t duration; /* +12 frames left */
\tuint8_t dir;      /* +13 effects: bit 0 sweeping back. songs: the note */
\tuint8_t freq;     /* +14 base frequency */
\tuint8_t volume;   /* +15 */
} SoundChannel;

_Static_assert(sizeof(SoundChannel) == 16, "SoundChannel");
_Static_assert(offsetof(SoundChannel, e.volume_step) == 10, "SoundChannel.e");
_Static_assert(offsetof(SoundChannel, w.ptr_lo) == 6, "SoundChannel.w");
_Static_assert(offsetof(SoundChannel, volume) == 15, "SoundChannel.volume");
"""
RANGE_RE = re.compile(r"\(([0-9A-Fa-f]{4})-([0-9A-Fa-f]{4})\)")
IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def c_comment(text: str) -> str:
    return text.replace("*/", "* /")


def span_size(addr: int, comment: str, nxt: int) -> int:
    if addr in SIZE_OVERRIDE:
        size = SIZE_OVERRIDE[addr]
    else:
        m = RANGE_RE.search(comment)
        if m and int(m.group(1), 16) == addr:
            size = int(m.group(2), 16) - addr + 1
        else:
            size = 1
    if size < 1:
        raise SystemExit(f"{addr:#06x} has size {size}")
    limit = min(nxt, WORK_HI + 1)
    if addr + size > limit:
        raise SystemExit(
            f"{addr:#06x} span {size} runs into {limit:#06x} ({comment})"
        )
    return size


Row = tuple  # (addr, size, name, comment, struct or None)


def fields() -> list[Row]:
    """Rows covering WORK_LO..WORK_HI. struct is (ctype, count, members)."""
    spans = []
    for addr, (ctype, name, count, members, comment) in STRUCTS.items():
        spans.append((addr, addr + count * len(members)))
    for addr, (_, size, _) in EXTRA.items():
        spans.append((addr, addr + size))

    def covered_by_override(a: int) -> bool:
        return any(lo <= a < hi for lo, hi in spans)

    syms = sorted(
        (a, n, c) for a, (n, c) in SYMBOLS.items()
        if WORK_LO <= a <= WORK_HI and not covered_by_override(a)
    )
    for addr, name, _ in syms:
        if not IDENT_RE.match(name):
            raise SystemExit(f"bad C name {name} at {addr:#06x}")
    entries: dict[int, Row] = {}
    for i, (addr, name, comment) in enumerate(syms):
        nxt = syms[i + 1][0] if i + 1 < len(syms) else WORK_HI + 1
        nxt = min([nxt] + [lo for lo, _ in spans if lo > addr])
        entries[addr] = (addr, span_size(addr, comment, nxt), name, comment, None)
    for addr, (name, size, comment) in EXTRA.items():
        entries[addr] = (addr, size, name, comment, None)
    for addr, (ctype, name, count, members, comment) in STRUCTS.items():
        entries[addr] = (addr, count * len(members), name, comment,
                         (ctype, count, members))

    out: list[Row] = []
    cursor = WORK_LO
    starts = sorted(entries)
    i = 0
    while cursor <= WORK_HI:
        if i < len(starts) and starts[i] == cursor:
            row = entries[cursor]
            out.append(row)
            cursor += row[1]
            i += 1
            if i < len(starts) and starts[i] < cursor:
                raise SystemExit(f"{starts[i]:#06x} sits inside {row[2]}")
        else:
            end = starts[i] if i < len(starts) else WORK_HI + 1
            out.append((cursor, end - cursor, f"gap_{cursor:04x}", "undocumented", None))
            cursor = end
    covered = sum(r[1] for r in out)
    if covered != WORK_HI - WORK_LO + 1:
        raise SystemExit(f"covered {covered} bytes, want {WORK_HI - WORK_LO + 1}")
    names = [r[2] for r in out]
    if len(names) != len(set(names)):
        raise SystemExit("duplicate field name")
    return out


def emit_header(rows: list[Row]) -> str:
    lines = [
        "/* Generated by py/gen_idiom_ram.py from py/ram_symbols.py.",
        " * Work RAM $4C00-$4FEF overlaid on Board.mem. Do not insert padding.",
        " */",
        "#ifndef IDIOM_RAM_H",
        "#define IDIOM_RAM_H",
        "",
        "#include <stddef.h>",
        "#include <stdint.h>",
        "",
        "#define WORK_RAM_BASE 0x4C00u",
        "#define WORK_RAM_END  0x4FEFu",
        "#define WORK_RAM_SIZE 0x3F0u",
        "",
        TYPEDEFS,
        "typedef struct WorkRam {",
    ]
    for addr, size, name, comment, struct in rows:
        if struct and struct[1] == 1:
            decl = f"\t{struct[0]} {name};"
        elif struct:
            decl = f"\t{struct[0]} {name}[{struct[1]}];"
        elif size == 1:
            decl = f"\tuint8_t {name};"
        else:
            decl = f"\tuint8_t {name}[{size}];"
        lines.append(f"{decl} /* ${addr:04X} {c_comment(comment)} */")
    lines += [
        "} WorkRam;",
        "",
        "_Static_assert(sizeof(WorkRam) == WORK_RAM_SIZE, \"WorkRam size\");",
    ]
    for addr, _, name, _, _ in rows:
        lines.append(
            f"_Static_assert(offsetof(WorkRam, {name}) == 0x{addr - WORK_LO:X}u,"
            f" \"{name}\");"
        )
    lines += [
        "",
        "/* Values the program stores. The addresses stay these bytes. */",
        "#define MAIN_TASK_LIST 0x4CC0u",
        "#define STACK_TOP      0x4FC0u",
        "",
        "static inline WorkRam *work_ram(uint8_t *mem)",
        "{",
        "\treturn (WorkRam *)(void *)(mem + WORK_RAM_BASE);",
        "}",
        "",
        "/* Absolute arcade address of a work-RAM byte, as the task list stores it. */",
        "static inline uint8_t *work_byte(WorkRam *ram, uint16_t addr)",
        "{",
        "\treturn (uint8_t *)ram + (unsigned)(addr - WORK_RAM_BASE);",
        "}",
        "",
        "const char *work_ram_name(uint16_t addr);",
        "",
        "#endif",
        "",
    ]
    return "\n".join(lines)


def emit_names(rows: list[Row]) -> str:
    names = [""] * (WORK_HI - WORK_LO + 1)
    for addr, size, name, _, struct in rows:
        for i in range(size):
            if struct:
                members = struct[2]
                n, m = divmod(i, len(members))
                index = "" if struct[1] == 1 else f"[{n}]"
                names[addr - WORK_LO + i] = f"{name}{index}.{members[m]}"
            elif size == 1:
                names[addr - WORK_LO + i] = name
            else:
                names[addr - WORK_LO + i] = f"{name}+{i}"
    lines = [
        "/* Generated by py/gen_idiom_ram.py. Names for corpus diffs. */",
        "#include \"ram.h\"",
        "",
        "const char *work_ram_name(uint16_t addr)",
        "{",
        "\tstatic const char *const names[WORK_RAM_SIZE] = {",
    ]
    for i, name in enumerate(names):
        if name:
            lines.append(f"\t\t[{i}] = \"{name}\",")
    lines += [
        "\t};",
        "\tunsigned off = (unsigned)addr - WORK_RAM_BASE;",
        "",
        "\tif (off >= WORK_RAM_SIZE)",
        "\t\treturn 0;",
        "\treturn names[off];",
        "}",
        "",
    ]
    return "\n".join(lines)


def asm_name(name: str) -> str:
    return name.replace("[", "_").replace("]", "")


def emit_asm(rows: list[Row]) -> str:
    """Merlin32 equates. A struct array gets its base, its stride, and one
    equate per member of element 0; index the rest with the stride."""
    lines = [
        "* Generated by py/gen_idiom_ram.py from py/ram_symbols.py.",
        "* Work RAM fields at their arcade addresses in the game bank.",
        "",
        "WORK_RAM_BASE equ $4C00",
        "WORK_RAM_END equ $4FEF",
        "MAIN_TASK_LIST equ $4CC0",
        "",
    ]
    for addr, size, name, comment, struct in rows:
        lines.append(f"{name} equ ${addr:04X} ; {comment}")
        if struct:
            members = struct[2]
            lines.append(f"{name}_SIZE equ {len(members)}")
            lines.append(f"{name}_COUNT equ {struct[1]}")
            for i, m in enumerate(members):
                lines.append(f"{name}_{asm_name(m)} equ ${addr + i:04X}")
        elif size > 1:
            lines.append(f"{name}_LEN equ {size}")
    # Member offsets inside the structs, for indexed access.
    seen = set()
    for _, _, _, _, struct in rows:
        if not struct or struct[0] in seen:
            continue
        seen.add(struct[0])
        for i, m in enumerate(struct[2]):
            lines.append(f"{struct[0]}_{asm_name(m)} equ {i}")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out-dir", default="lower",
                    help="directory for ram.h, ram.c and ram.s")
    args = ap.parse_args()
    out = ROOT / args.out_dir
    if out.resolve() == (ROOT / "idiom").resolve():
        raise SystemExit("idiom/ is locked; pass --out-dir lower")
    rows = fields()
    hdr = out / "ram.h"
    src = out / "ram.c"
    asm = out / "ram.s"
    hdr.write_text(emit_header(rows), encoding="utf-8")
    src.write_text(emit_names(rows), encoding="utf-8")
    asm.write_text(emit_asm(rows), encoding="utf-8")
    print(f"wrote {hdr}, {src} and {asm} ({len(rows)} fields)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
