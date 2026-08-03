#!/usr/bin/env python3
"""Shared compiled-blit emitter for the IIgs sprite generators.

All three generators (ghosts / fruits / Ms. Pac) used to emit one 8-bit
operation per opaque byte. Adjacent opaque bytes can instead be written as a
single 16-bit operation, which is cheaper per byte:

    solid byte    lda #imm8  + sta abs,y                 =  7 cyc,  5 bytes
    partial byte  lda abs,y  + and + ora + sta abs,y     = 13 cyc, 12 bytes
    solid pair    lda #imm16 + sta abs,y                 =  9 cyc,  6 bytes
    partial pair  lda abs,y  + and16 + ora16 + sta abs,y = 17 cyc, 14 bytes

A pair holding one transparent byte is never widened: preserving the
transparent half forces the 17-cycle read-modify-write, which loses to a plain
7-cycle store. A per-row dynamic program over the 7 columns picks the cheapest
mix of singles and adjacent pairs. Pairs are (col, col+1) with col+1 <= 6, so a
16-bit store never spills past the cell into the neighbouring column.

The chosen operations are then segregated by width across the whole sprite, so
each blit carries only two mode switches:

    LABEL
        php
        rep #$20
        <16-bit ops, any row>
        sep #$20
        <8-bit ops, any row>
        plp
        rts

Both switches are always emitted even when a section is empty, so every blit
ends in 8-bit state and the trailing `mx %00` the generators append (plus the
`mx %00` after each `put` in iigs/all.s) stays correct.

Self-test (simulates both strategies against a background and compares, over
every possible row mask pattern):
  python3 py/blit_emit.py
"""

from __future__ import annotations

ROWS = 12
COLS = 7
ROW_BYTES = 160
SHR_BASE = 0x2000

# Cycle costs used by the pairing DP. Only relative order matters.
COST_SOLID_BYTE = 7
COST_PARTIAL_BYTE = 13
COST_SOLID_PAIR = 9
COST_PARTIAL_PAIR = 17


class BlitStats:
    """Operation counts for one generator run."""

    def __init__(self) -> None:
        self.solid_bytes = 0
        self.partial_bytes = 0
        self.solid_pairs = 0
        self.partial_pairs = 0
        self.cycles = 0

    def __str__(self) -> str:
        return (
            f"{self.solid_pairs} solid + {self.partial_pairs} partial word ops, "
            f"{self.solid_bytes} solid + {self.partial_bytes} partial byte ops, "
            f"~{self.cycles} cycles"
        )


def _byte_cost(m: int) -> int:
    if m == 0:
        return 0
    return COST_SOLID_BYTE if m == 0xFF else COST_PARTIAL_BYTE


def _pair_cost(a: int, b: int) -> int | None:
    """Cost of writing bytes a,b as one 16-bit op, or None if not worthwhile."""
    if a == 0 or b == 0:
        # Widening would need an RMW just to preserve the transparent half.
        return None
    return COST_SOLID_PAIR if a == 0xFF and b == 0xFF else COST_PARTIAL_PAIR


def plan_row(mask_row: bytes) -> list[tuple[int, int]]:
    """Cheapest cover of one 7-byte row as (col, width) ops, width 1 or 2.

    Transparent bytes are dropped entirely.
    """
    n = len(mask_row)
    inf = float("inf")
    best: list[float] = [inf] * (n + 1)
    choice: list[tuple[int, int] | None] = [None] * (n + 1)
    best[0] = 0.0
    for i in range(n):
        if best[i] == inf:
            continue
        single = best[i] + _byte_cost(mask_row[i])
        if single < best[i + 1]:
            best[i + 1] = single
            choice[i + 1] = (i, 1)
        if i + 1 < n:
            pc = _pair_cost(mask_row[i], mask_row[i + 1])
            if pc is not None and best[i] + pc < best[i + 2]:
                best[i + 2] = best[i] + pc
                choice[i + 2] = (i, 2)

    ops: list[tuple[int, int]] = []
    pos = n
    while pos > 0:
        col, width = choice[pos]  # type: ignore[misc]
        if width == 2 or mask_row[col] != 0:
            ops.append((col, width))
        pos = col
    ops.reverse()
    return ops


def emit_blit(
    label: str,
    spr: bytes,
    msk: bytes,
    stats: BlitStats | None = None,
    word16: bool = True,
) -> list[str]:
    """Emit one compiled masked blit. Y = SHR offset, DBR = $01, ends in RTS."""
    if stats is None:
        stats = BlitStats()

    words: list[str] = []
    bytes_: list[str] = []

    for row in range(ROWS):
        base = row * COLS
        mask_row = msk[base : base + COLS]
        addr_base = SHR_BASE + row * ROW_BYTES
        ops = plan_row(mask_row) if word16 else [(c, 1) for c in range(COLS)]

        for col, width in ops:
            i = base + col
            addr = addr_base + col
            if width == 1:
                m = msk[i]
                if m == 0:
                    continue
                s = spr[i] & m
                if m == 0xFF:
                    bytes_.append(f"\tlda\t#${s:02X}")
                    bytes_.append(f"\tsta\t${addr:04X},y")
                    stats.solid_bytes += 1
                    stats.cycles += COST_SOLID_BYTE
                else:
                    bytes_.append(f"\tlda\t${addr:04X},y")
                    bytes_.append(f"\tand\t#${m ^ 0xFF:02X}")
                    bytes_.append(f"\tora\t#${s:02X}")
                    bytes_.append(f"\tsta\t${addr:04X},y")
                    stats.partial_bytes += 1
                    stats.cycles += COST_PARTIAL_BYTE
            else:
                # Little-endian: low byte is the lower column.
                m = msk[i] | (msk[i + 1] << 8)
                s = (spr[i] & msk[i]) | ((spr[i + 1] & msk[i + 1]) << 8)
                if m == 0xFFFF:
                    words.append(f"\tlda\t#${s:04X}")
                    words.append(f"\tsta\t${addr:04X},y")
                    stats.solid_pairs += 1
                    stats.cycles += COST_SOLID_PAIR
                else:
                    words.append(f"\tlda\t${addr:04X},y")
                    words.append(f"\tand\t#${m ^ 0xFFFF:04X}")
                    words.append(f"\tora\t#${s:04X}")
                    words.append(f"\tsta\t${addr:04X},y")
                    stats.partial_pairs += 1
                    stats.cycles += COST_PARTIAL_PAIR

    lines = [label, "\tphp", "\trep\t#$20"]
    lines += words
    lines.append("\tsep\t#$20")
    lines += bytes_
    lines += ["\tplp", "\trts", ""]
    return lines


# --------------------------------------------------------------------------
# Self-check: run the emitted instruction stream against a background and
# confirm word16 output lands the same 84 bytes as the byte-only output.
# --------------------------------------------------------------------------


def simulate(lines: list[str], background: bytearray) -> bytearray:
    """Execute an emitted blit against a bank-$01-shaped byte array (Y = 0)."""
    mem = bytearray(background)
    wide = False  # m flag: False = 8-bit A, True = 16-bit A
    acc = 0
    for raw in lines:
        text = raw.strip()
        if not text or text.startswith("*") or not text.startswith(("lda", "and", "ora", "sta", "rep", "sep", "php", "plp", "rts")):
            continue
        op, _, arg = text.partition("\t")
        arg = arg.strip()
        if op == "rep":
            wide = True
            continue
        if op == "sep":
            wide = False
            continue
        if op in ("php", "plp", "rts"):
            continue
        mask = 0xFFFF if wide else 0xFF
        if arg.startswith("#$"):
            value = int(arg[2:], 16)
            if op == "lda":
                acc = value & mask
            elif op == "and":
                acc &= value & mask
            elif op == "ora":
                acc |= value & mask
            else:
                raise AssertionError(f"immediate operand on {op}")
            continue
        addr = int(arg.split(",")[0].lstrip("$"), 16)
        if op == "lda":
            acc = mem[addr] | (mem[addr + 1] << 8) if wide else mem[addr]
        elif op == "sta":
            mem[addr] = acc & 0xFF
            if wide:
                mem[addr + 1] = (acc >> 8) & 0xFF
        else:
            raise AssertionError(f"memory operand on {op}")
    return mem


def default_background() -> bytearray:
    """Deterministic non-uniform fill, so masked-off bits show up if dropped."""
    size = SHR_BASE + ROWS * ROW_BYTES + COLS + 2
    return bytearray((i * 37 + (i >> 5) * 11) & 0xFF for i in range(size))


def check_equivalence(
    spr: bytes, msk: bytes, background: bytearray | None = None
) -> None:
    """Raise if the word16 blit differs from the byte-only blit."""
    if background is None:
        background = default_background()
    ref = simulate(emit_blit("REF", spr, msk, word16=False), background)
    got = simulate(emit_blit("GOT", spr, msk, word16=True), background)
    if ref != got:
        for row in range(ROWS):
            for col in range(COLS):
                a = SHR_BASE + row * ROW_BYTES + col
                if ref[a] != got[a]:
                    raise AssertionError(
                        f"row {row} col {col}: byte-only ${ref[a]:02X} != word16 ${got[a]:02X}"
                    )
        raise AssertionError("blit outputs differ outside the sprite cell")


def _self_test() -> int:
    import itertools
    import random

    rng = random.Random(20260802)
    size = SHR_BASE + ROWS * ROW_BYTES + COLS + 2
    checked = 0

    # Packed 4bpp means a mask nibble is all-or-nothing, so these four values
    # are the complete alphabet. 4**7 is every possible row pattern, and a blit
    # is 12 independent rows, so sweeping rows is total coverage.
    alphabet = (0x00, 0x0F, 0xF0, 0xFF)
    rows = list(itertools.product(alphabet, repeat=COLS))

    # Pack the patterns 12 at a time so each check exercises a whole blit.
    for start in range(0, len(rows), ROWS):
        chunk = rows[start : start + ROWS]
        while len(chunk) < ROWS:
            chunk.append(rng.choice(rows))
        msk = bytes(b for row in chunk for b in row)
        spr = bytes(rng.randrange(256) for _ in range(ROWS * COLS))
        bg = bytearray(rng.randrange(256) for _ in range(size))
        check_equivalence(spr, msk, bg)
        checked += 1

    print(
        f"blit_emit self-test: {checked} blits covering all {len(rows)} row "
        "mask patterns, word16 == byte-only"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(_self_test())
