# IIgs harness memory map (v1)

Authoritative addresses live in [`iigs/equates.s`](../iigs/equates.s). Host inject paths: [`py/gs2_render_test.py`](../py/gs2_render_test.py). Sizes below match current `make gfx` / `make maze` / `make iigs` outputs.

**Convention:** `BB/AAAA` = bank `BB`, offset `AAAA`. Long address `$bbAAAA`.

While running: **DB = `$02`** (code bank), **DP = `$0000`**, **stack** = `$01FF` (bank `$00` / current stack bank after `TCS`). SHR blits temporarily set **DB = `$01`**.

---

## Bank overview

| Bank | Role |
|------|------|
| `$00` | Soft-switches, page-3 trampoline, stack |
| `$01` | SHR shadow (pixels, SCB, palette) — **shadowing ON** |
| `$02` | Harness code + game/render RAM |
| `$03` | Injected graphics / maze assets (read-only at runtime) |
| `$E1` | Displayed SHR (tracks `$01` when shadowing on; host PNG capture) |

```
$00  soft-switches, CALL 768 stub
$01  SHR shadow ──────────────────────────► display via $E1
$02  code | … | tilemap | actors | save | dirty | scratch
$03  tiles | sprites/masks even+odd | maze | stitched cells
```

---

## Bank `$00` — I/O and entry

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$00/0300` | (trampoline) | 6 | `CLC` / `XCE` / `JML $020000` — Applesoft `CALL 768` |
| `$00/C000` | `KBD` | — | Key data + pending (bit 7) |
| `$00/C010` | `KBDSTRB` | — | Clear keyboard strobe |
| `$00/C019` | `RDVBLBAR` | — | VBL sense (IIgs: bit7 set in VBL) |
| `$00/C029` | `NEWVIDEO` | — | SHR enable (`$C1` in harness) |
| `$00/C035` | `SHADOW` | — | Bit3 clear → SHR shadowing on |
| `$00/C050` | `TXTCLR` | — | Graphics mode |

Stack pointer initialized to `$01FF` at `Start`.

---

## Bank `$01` — SHR (shadow write target)

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$01/2000`–`$01/9CFF` | `SHR_PIXELS` | 32000 | 320×200 4bpp packed (160 bytes/row) |
| `$01/9D00`–`$01/9DFF` | `SHR_SCB` | 256 | Scanline control (palette 0, 320 mode) |
| `$01/9E00`–`$01/9E1F` | `SHR_PALETTE` | 32 | Palette 0 (16× SHR `$0RGB` words) |

Playfield blit origin: **(76, 7)**; size **168×186** (28×31 × 6×6). Side gutters unused in the harness.

With shadowing on, do **not** poke `$E1` from the 65816 hot path; host capture may still read `$01` or `$E1`.

---

## Bank `$02` — code and working RAM

Merlin `org $0000` → loaded at `$02/0000`.

### Code

| Address | Size | Notes |
|---------|------|-------|
| `$02/0000`–… | ~2816 (`$0B00`) | `harness.bin` (grows with features) |
| …–`$02/6FFF` | — | **Free** (keep code below `$7000`) |

### Logical tilemap and actors

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$02/6000`–`$02/653F` | `SPR_WORK*` | 1344 | 4 actors × 336 (even+odd spr/mask, body pen baked) |
| `$02/7000`–`$02/7363` | `TILEMAP` | 868 | 28×31 tile codes (copy of `AST_MAZE`) |
| `$02/7364`–`$02/73FF` | — | — | Unused pad to actors |
| `$02/7400`–`$02/743F` | `ACTORS` | 64 | 4 actors × 16 bytes |
| `$02/7440`–`$02/74FF` | — | — | Reserved for actors 4–5 (pac/fruit) later |
| `$02/7500`–`$02/764F` | `SAVEUNDER` | 336 | 4 × 84-byte (14×12) underlays |
| `$02/7650`–`$02/77FF` | — | — | Free (must stay below dirty) |

### Actor record (`ACT_SIZE` = 16)

Base = `$027400 + index×16`. Indexed in asm as `X = ACTORS16 + index×16` with `>BANK2+field,x`.

| Off | Symbol | Type | Who writes | Who reads |
|-----|--------|------|------------|-----------|
| +0 | `ACT_X` | word | rails / logic (**new**) | `DrawSprite` |
| +2 | `ACT_Y` | word | rails / logic (**new**) | `DrawSprite` |
| +4 | `ACT_OX` | word | `CopySpritePos` / init (**old**) | `EraseSprite` |
| +6 | `ACT_OY` | word | `CopySpritePos` / init (**old**) | `EraseSprite` |
| +8 | `ACT_SPR` | byte | init / logic | `DrawSprite` |
| +9 | `ACT_FLAGS` | byte | render (`FLAG_DRAWN`) | render |
| +10 | `ACT_WP` | byte | rails (waypoint index) | rails only |
| +11 | `ACT_COLOR` | byte | init (body pen) | `DrawSprite` |
| +12…15 | — | — | reserved | — |

### Frame / dirty / demo control

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$02/7800` | `DIRTY_COUNT` | 2 | Number of dirty tile entries |
| `$02/7802`–… | `DIRTY_LIST` | pairs | `(tx,ty)` bytes; room before `$7900` |
| `$02/7900` | `FRAME_COUNT` | 2 | Frame counter |
| `$02/7902` | `EAT_INDEX` | 2 | Dirty-eat demo cursor |
| `$02/7904` | `DEMO_FREEZE` | 1 | Host≠0 → skip erase/draw/rails |
| `$02/7905`–`$02/79FF` | — | — | Free |

### Render / harness scratch

| Address | Symbol | Notes |
|---------|--------|-------|
| `$02/7A00` | `R_X` | Screen / temp X |
| `$02/7A02` | `R_Y` | Screen / temp Y |
| `$02/7A04` | `R_TX` | Tile X |
| `$02/7A06` | `R_TY` | Tile Y |
| `$02/7A08` | `R_TILE` | Tile code |
| `$02/7A0A` | `R_OFF` | Byte offset / mul scratch |
| `$02/7A0C` | `R_DEST` | SHR offset |
| `$02/7A0E` | `R_ROW` | Row counter |
| `$02/7A10` | `R_IDX` | Sprite index |
| `$02/7A12` | `R_CARRY` | Nibble / mul scratch |
| `$02/7A14` | `R_TMP` | General temp |
| `$02/7A16` | `R_ACT` | Actor index |
| `$02/7A18` | `R_BASE` | Actor base (`ACTORS16+…`) |
| `$02/7A1A` | `R_SAVE` | Save-under pointer |
| `$02/7A1C` | `R_BODY` | Body pen for remap |
| `$02/7A1E` | `R_BTMP` | Blit temp |
| `$02/7A20`–… | — | Further scratch if needed |

`BANK2` = `$020000` (long base for `,x` with 16-bit offset).  
`ACTORS16` = `$7400`, `SAVEUNDER16` = `$7500`.

---

## Bank `$03` — injected assets

Host writes these before `CALL 768`. Packed 4bpp; already upright (CW + row XOR 3).

| Address | Symbol | Size | Source file |
|---------|--------|------|-------------|
| `$03/0000`–`$03/11FF` | `AST_TILES` | 4608 | `tiles6.bin` (256 × 18) |
| `$03/1200`–`$03/26FF` | `AST_SPR_EVEN` | 5376 | `sprites14x12.bin` (64 × 84) |
| `$03/2700`–`$03/3BFF` | `AST_MSK_EVEN` | 5376 | `sprites14x12.mask.bin` |
| `$03/3C00`–`$03/50FF` | `AST_SPR_ODD` | 5376 | `sprites14x12.odd.bin` |
| `$03/5100`–`$03/65FF` | `AST_MSK_ODD` | 5376 | `sprites14x12.odd.mask.bin` |
| `$03/6600`–`$03/6963` | `AST_MAZE` | 868 | `maze1_28x31.bin` |
| `$03/6964`–`$03/6FFF` | — | — | Gap (unused) |
| `$03/7000`–`$03/AD07` | `AST_MAZE_CELLS` | 15624 | `maze1_cells.bin` (868 × 18) |
| `$03/AD08`–… | — | — | Free |

---

## Save-under layout

| Actor | Save base | Bytes |
|-------|-----------|-------|
| 0 | `$02/7500` | 84 |
| 1 | `$02/7554` | 84 |
| 2 | `$02/75A8` | 84 |
| 3 | `$02/75FC` | 84 |

Formula: `SAVEUNDER16 + index × 84`. One cell = 7 bytes × 12 rows.

---

## Ownership (register model)

| Region | Publisher | Consumer |
|--------|-----------|----------|
| `ACT_X`/`ACT_Y` (new) | Rails / game logic | Draw |
| `ACT_OX`/`ACT_OY` (old) | `CopySpritePos` after draw | Erase |
| `ACT_SPR` / `ACT_COLOR` | Logic / init | Draw |
| `ACT_WP` | Rails | Rails only |
| `ACT_FLAGS` | Render | Render |
| `TILEMAP` / dirty list | Game logic | Tile redraw |
| `SAVEUNDER` | Draw (capture) / Erase (restore) | Render only — erase does **not** re-blit bank `$03` maze |
| `$03/*` assets | Host inject | Render (read) |
| SHR `$01` | Render | Display |

---

## Gaps / constraints

1. **Code must stay below `$02/7000`.**
2. **Save-under must stay below `$02/7800`** (dirty list).
3. Expanding to 6 actors: 6×16 = 96 → actors through `$745F`; 6×84 = 504 → save through `$76F7` (still under `$7800`).
4. Odd sprite/mask forms are **host-injected** (not generated on target in the current harness).

When this map changes, update [`iigs/equates.s`](../iigs/equates.s) first, then this file.
