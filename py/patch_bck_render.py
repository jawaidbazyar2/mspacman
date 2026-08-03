#!/usr/bin/env python3
"""SUPERSEDED — do not re-run. One-shot $01/A000 BCK strip port, already applied.

iigs/render_body.s has moved on since this ran and is now hand-maintained:
EraseSprite restores from the cached ACT_DEST / ACT_BDEST rather than
recomputing from ACT_OX / ACT_OY, and the R_* scratch lives in direct page
(`<R_xxx`), not at $02/8A00. Re-running would revert both. Kept only as a
record of how the BCK strip port was made.

Merlin parses a+b*c left-to-right, so EraseSprite uses decimal row
offsets (r*88 / r*160), not S_BCK*n / S_SHR*n.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "iigs" / "render_body.s"

DRAW_TILE_MAZE = r"""
DrawTile
* Write tile to SHR ($01) and BCK strip ($01/A000), strides S_SHR / S_BCK.
	php
	phb
	sep	#$20
	lda	#BANK_SHR
	pha
	plb
	rep	#$30
	lda	>R_TX
	asl
	clc
	adc	>R_TX
	asl
	clc
	adc	#PF_ORIGIN_X
	sta	>R_X
	lda	>R_TY
	asl
	clc
	adc	>R_TY
	asl
	clc
	adc	#PF_ORIGIN_Y
	sta	>R_Y
	jsr	ScreenXY
	jsr	BckXY
	lda	>R_TILE
	and	#$00FF
	jsr	Mul18
	tax
	lda	#6
	sta	>R_ROW
	lda	>R_DEST
	tay
* 3 bytes/row: word @0 then overlapped word @1. X=tile src, Y=SHR, R_BDEST=BCK.
]tr	lda	>AST_TILES,x
	sta	$2000,y
	sta	>R_BTMP
	lda	>AST_TILES+1,x
	sta	$2001,y
	sta	>R_TMP
	phx
	lda	>R_BDEST
	tax
	lda	>R_BTMP
	sta	BCK_BASE,x
	lda	>R_TMP
	sta	BCK_BASE+1,x
	plx
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#S_SHR
	tay
	lda	>R_BDEST
	clc
	adc	#S_BCK
	sta	>R_BDEST
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]tr
	plb
	plp
	rts

DrawMaze
* Pre-stitched 6×6 cells → SHR + BCK (DBR=$01). No bank-$04 mirror.
	php
	phb
	sep	#$20
	lda	#BANK_SHR
	pha
	plb
	rep	#$30
	lda	#0
	sta	>R_TY
]my	lda	#0
	sta	>R_TX
]mx	lda	>R_TX
	asl
	clc
	adc	>R_TX
	asl
	clc
	adc	#PF_ORIGIN_X
	sta	>R_X
	lda	>R_TY
	asl
	clc
	adc	>R_TY
	asl
	clc
	adc	#PF_ORIGIN_Y
	sta	>R_Y
	jsr	ScreenXY
	jsr	BckXY
	lda	>R_TY
	asl
	asl
	asl
	asl
	asl
	sta	>R_TMP
	lda	>R_TY
	asl
	asl
	sta	>R_OFF
	lda	>R_TMP
	sec
	sbc	>R_OFF
	clc
	adc	>R_TX
	jsr	Mul18
	tax
	lda	#6
	sta	>R_ROW
	lda	>R_DEST
	tay
]mc	lda	>AST_MAZE_CELLS,x
	sta	$2000,y
	sta	>R_BTMP
	lda	>AST_MAZE_CELLS+1,x
	sta	$2001,y
	sta	>R_TMP
	phx
	lda	>R_BDEST
	tax
	lda	>R_BTMP
	sta	BCK_BASE,x
	lda	>R_TMP
	sta	BCK_BASE+1,x
	plx
	txa
	clc
	adc	#3
	tax
	tya
	clc
	adc	#S_SHR
	tay
	lda	>R_BDEST
	clc
	adc	#S_BCK
	sta	>R_BDEST
	lda	>R_ROW
	dec
	sta	>R_ROW
	bne	]mc
	lda	>R_TX
	inc
	sta	>R_TX
	lda	>R_TX
	cmp	#28
	bcs	:ny
	brl	]mx
:ny	lda	>R_TY
	inc
	sta	>R_TY
	lda	>R_TY
	cmp	#31
	bcs	:mdone
	brl	]my
:mdone	plb
	plp
	rts
""".lstrip("\n")


def erase_kernel() -> str:
    lines = [
        "* Unrolled 12×7. Row r offsets: BCK r*88+{0,2,4,5} / SHR r*160+…",
        "* Decimal only — Merlin a+b*c is left-to-right (breaks S_BCK*n).",
    ]
    for r in range(12):
        bo = r * 88
        so = r * 160
        for off in (0, 2, 4, 5):
            lines.append(f"\tlda\tBCK_BASE+{bo + off},x")
            lines.append(f"\tsta\t|SHR_PIXELS+{so + off},y")
    return "\n".join(lines) + "\n"


def main() -> None:
    t = PATH.read_text()

    old_r = """R_BTMP         equ $028A1E
* High DP (DP=$0000): Y-sort keys — actor records are never moved
"""
    new_r = """R_BTMP         equ $028A1E
R_BDEST        equ $028A20	; BCK strip offset (BckXY)
* High DP (DP=$0000): Y-sort keys — actor records are never moved
"""
    if "R_BDEST" not in t:
        if old_r not in t:
            raise SystemExit("R_BTMP block not found")
        t = t.replace(old_r, new_r, 1)

    old_init = """InitRowAddr
* ROW_ADDR[y] = y*160 for y=0..255 (word table @ $02/8B00).
	php
	rep	#$30
	ldx	#0
	lda	#0
]i	sta	>ROW_ADDR,x
	clc
	adc	#160
	inx
	inx
	cpx	#512
	bcc	]i
	plp
	rts

ScreenXY
* R_DEST = ROW_ADDR[Y] + X/2. Long,X: DBR may be $01 during blit.
	lda	>R_Y
	and	#$00FF
	asl
	tax
	lda	>ROW_ADDR,x
	sta	>R_DEST
	lda	>R_X
	lsr
	clc
	adc	>R_DEST
	sta	>R_DEST
	rts
"""
    new_init = """InitRowAddr
* ROW_ADDR[y]=y*S_SHR, ROW_BCK[y]=y*S_BCK (y=0..255).
	php
	rep	#$30
	ldx	#0
	lda	#0
]i	sta	>ROW_ADDR,x
	clc
	adc	#S_SHR
	inx
	inx
	cpx	#512
	bcc	]i
	ldx	#0
	lda	#0
]j	sta	>ROW_BCK,x
	clc
	adc	#S_BCK
	inx
	inx
	cpx	#512
	bcc	]j
	plp
	rts

ScreenXY
* R_DEST = ROW_ADDR[Y] + X/2. Long,X: DBR may be $01 during blit.
	lda	>R_Y
	and	#$00FF
	asl
	tax
	lda	>ROW_ADDR,x
	sta	>R_DEST
	lda	>R_X
	lsr
	clc
	adc	>R_DEST
	sta	>R_DEST
	rts

BckXY
* R_BDEST = ROW_BCK[Y] + (X-BCK_ORIGIN_X)/2. Strip is S_BCK-wide @ $01/A000.
	lda	>R_Y
	and	#$00FF
	asl
	tax
	lda	>ROW_BCK,x
	sta	>R_BDEST
	lda	>R_X
	sec
	sbc	#BCK_ORIGIN_X
	lsr
	clc
	adc	>R_BDEST
	sta	>R_BDEST
	rts
"""
    if "\nBckXY\n" not in t:
        if old_init not in t:
            raise SystemExit("InitRowAddr/ScreenXY block not found")
        t = t.replace(old_init, new_init, 1)

    # Replace CopyBgToShr through end of DrawMaze (label at column 0)
    start = t.find("\nCopyBgToShr\n")
    end = t.find("\nSortActorsByY\n")
    if start < 0 or end < 0:
        raise SystemExit("CopyBgToShr/DrawMaze region not found")
    start += 1  # skip leading newline
    end += 1
    new_draw = DRAW_TILE_MAZE.rstrip() + "\n\n"
    t = t[:start] + new_draw + t[end:]

    # Replace EraseSprite through DrawSprite — labels at column 0 only
    # (avoid matching `jsr EraseSprite` / `jsr DrawSprite`)
    estart = t.find("\nEraseSprite\n")
    eend = t.find("\nDrawSprite\n", estart)
    if estart < 0 or eend < 0:
        raise SystemExit("EraseSprite region not found")
    estart += 1
    eend += 1
    erase = """EraseSprite
* A = actor index. Position from ACT_OX/OY (old).
* Restore 14×12: abs,X load BCK (S_BCK) → abs,Y store SHR (S_SHR), DBR=$01.
* Merlin parses a+b*c left-to-right — use decimal row offsets, not S_BCK*n.
	php
	rep	#$30
	sta	>R_ACT
	sep	#$20
	lda	#BRD_ERASE
	jsr	SetBorder
	phb
	lda	#BANK_SHR
	pha
	plb
	rep	#$30
	lda	>R_ACT
	asl
	asl
	asl
	asl
	clc
	adc	#ACTORS16
	sta	>R_BASE
	tax
	lda	>BANK2+ACT_FLAGS,x
	and	#$0001
	bne	:er
	plb
	plp
	rts
:er	lda	>BANK2+ACT_OX,x
	sta	>R_X
	lda	>BANK2+ACT_OY,x
	sta	>R_Y
	jsr	ScreenXY
	jsr	BckXY
	lda	>R_BDEST
	tax
	lda	>R_DEST
	tay
"""
    erase += erase_kernel()
    erase += """	lda	>R_BASE
	tax
	sep	#$20
	lda	>BANK2+ACT_FLAGS,x
	and	#$FE
	sta	>BANK2+ACT_FLAGS,x
	plb
	plp
	rts

"""
    t = t[:estart] + erase + t[eend:]

    t = t.replace(
        "* Compiled ghost / fruit / Ms. Pac blit only (no save-under; erase uses $04).",
        "* Compiled ghost / fruit / Ms. Pac blit only (no save-under; erase uses BCK).",
    )

    if "BG_PIXELS" in t or "BANK_BG" in t or "CopyBgToShr" in t:
        raise SystemExit("BG_$04 symbols still present after patch")

    PATH.write_text(t)
    print(f"patched {PATH} ({PATH.stat().st_size} bytes)")
    # sanity: first few erase addresses
    for s in ("BCK_BASE+0,x", "BCK_BASE+88,x", "BCK_BASE+176,x", "|SHR_PIXELS+320,y"):
        assert s in t, s


if __name__ == "__main__":
    if "--i-know-this-is-superseded" not in sys.argv:
        raise SystemExit(
            "py/patch_bck_render.py is superseded and would revert "
            "iigs/render_body.s — see the module docstring."
        )
    main()
