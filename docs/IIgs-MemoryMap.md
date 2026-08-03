# IIgs harness memory map (v1)

Authoritative addresses live in [`iigs/equates.s`](../iigs/equates.s). Host inject paths: [`py/gs2_render_test.py`](../py/gs2_render_test.py). Sizes below match current `make gfx` / `make maze` / `make iigs` outputs.

**Convention:** `BB/AAAA` = bank `BB`, offset `AAAA`. Long address `$bbAAAA`.

While running: **DB = `$02`** (code bank), **DP = `$0000`**, **stack** = `$01FF` (bank `$00` / current stack bank after `TCS`). SHR blits temporarily set **DB = `$01`**.

---

## Bank overview

| Bank | Role |
|------|------|
| `$00` | Soft-switches, page-3 trampoline, stack |
| `$01` | SHR shadow (`$2000–$9FFF`) + PF **BCK** strip (`$A000+`) — SHR shadow only |
| `$02` | Harness code + game/render RAM |
| `$03` | Injected graphics / maze assets (read-only at runtime) |
| `$E1` | Displayed SHR (tracks `$01` SHR region; host PNG capture) |

```
$00  soft-switches, CALL 768 stub
$01  SHR $2000–9FFF ──shadow──► $E1   |  BCK strip $A000+ (S_BCK stride)
$02  code | … | tilemap | actors | dirty | scratch
$03  tiles | sprites/masks even+odd | maze | stitched cells
```

---

## Bank `$00` — I/O and entry

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$00/0300` | (trampoline) | 6 | `CLC` / `XCE` / `JML $020000` — Applesoft `CALL 768` |
| `$E0/C000` | `KBD` | — | Key data + pending (bit 7) |
| `$E0/C010` | `KBDSTRB` | — | Clear keyboard strobe |
| `$E1/C019` | `RDVBLBAR` | — | VBL sense (bit7 set in VBL) |
| `$E0/C029` | `NEWVIDEO` | — | SHR enable (`$C1` in harness) |
| `$E0/C035` | `SHADOW` | — | `$F7`: inhibit all shadowing except SHR (bit3=0) |
| `$E0/C034` | `BORDCOLOR` | — | Border colour nibble |
| `$E0/C050` | `TXTCLR` | — | Graphics mode |

Stack pointer initialized to `$01FF` at `Start`.

### Direct page (`DP = $0000`)

High DP holds the Y-order key arrays (actor records are not moved):

| DP | Symbol | Size | Notes |
|----|--------|------|-------|
| `$EA`–`$EB` | `DP_KEYI` / `DP_KEYY` | 2 | insertion temps |
| `$EC`–`$ED` | `DP_YOFF` | 2 | `ACT_Y` / `ACT_OY` field offset |
| `$EE`–`$EF` | `DP_I` / `DP_J` | 2 | sort loop indices |
| `$F0`–`$F5` | `DP_SORT` | 6 | actor indices, Y-ascending |
| `$F6`–`$FB` | `DP_YKEY` | 6 | Y low for actor `0..5` (by actor #) |

---

## Bank `$01` — SHR + playfield backing strip

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$01/2000`–`$01/9CFF` | `SHR_PIXELS` | 32000 | 320×200 4bpp; stride **`S_SHR` = 160** |
| `$01/9D00`–`$01/9DFF` | `SHR_SCB` | 256 | Scanline control (palette 0, 320 mode) |
| `$01/9E00`–`$01/9E1F` | `SHR_PALETTE` | 32 | Palette 0 (16× SHR `$0RGB` words) |
| `$01/A000`–… | `BCK_PIXELS` / `BCK_BASE` | `BCK_CLEAR_BYTES` | Maze/tiles only; stride **`S_BCK` = 88** (176 px from X=72); zeroed in `InitSHR` |

Playfield blit origin: **(76, 7)**; size **168×186** (28×31 × 6×6). BCK origin X = `SPR_BASE_X` (72) so 14×12 erase fits. `BckXY`: `ROW_BCK[Y] + (X-72)/2`.

`SHADOW=$F7` before BCK clear (IOLC off → `$01/A000+` is RAM). Soft-switches via `$E0`/`$E1`, not `$00`. Do **not** poke `$E1` SHR pixels on the hot path.

---

## Bank `$02` — code and working RAM

Merlin `org $0000` → loaded at `$02/0000`.

### Code

| Address | Size | Notes |
|---------|------|-------|
| `$02/0000`–… | `harness.bin` | Code + compiled ghost/fruit/Ms. Pac blits (keep below `$8000`) |
| …–`$02/7FFF` | — | **Free** after code (working RAM starts at `$8000`) |

### Logical tilemap and actors

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$02/6000`–`$02/653F` | (free) | 1344 | Was `SPR_WORK*`; ghosts use compiled blits now |
| `$02/8000`–`$02/8363` | `TILEMAP` | 868 | 28×31 tile codes (copy of `AST_MAZE`) |
| `$02/8364`–`$02/83FF` | — | — | Unused pad to actors |
| `$02/8400`–`$02/845F` | `ACTORS` | 96 | 6 actors × 16 bytes (4 ghosts + fruit + Ms. Pac) |
| `$02/8460`–`$02/87FF` | — | — | Free (was save-under; erase uses `$01` BCK) |

### Actor record (`ACT_SIZE` = 16)

Base = `$028400 + index×16`. Indexed in asm as `X = ACTORS16 + index×16` with `>BANK2+field,x`.

| Off | Symbol | Type | Who writes | Who reads |
|-----|--------|------|------------|-----------|
| +0 | `ACT_X` | word | rails / logic (**new**) | `DrawSprite` |
| +2 | `ACT_Y` | word | rails / logic (**new**) | `DrawSprite` |
| +4 | `ACT_OX` | word | `CopySpritePos` / init (**old**) | `EraseSprite` |
| +6 | `ACT_OY` | word | `CopySpritePos` / init (**old**) | `EraseSprite` |
| +8 | `ACT_SPR` | byte | rails / fruit / pac (ghost `$20–$27`, fruit `$00–$07`, Ms. Pac `dir*3+mouth`) | `DrawSprite` → ghost/fruit/MsPac blit table |
| +9 | `ACT_FLAGS` | byte | render (`FLAG_DRAWN`) | render |
| +10 | `ACT_WP` | byte | rails (waypoint index; ghosts + Ms. Pac) | rails only |
| +11 | `ACT_COLOR` | byte | init (ghost body pen 5/7/9/11; unused for fruit/Ms. Pac) | `DrawSprite` → `GhostBlitTable` |
| +12…15 | — | — | reserved | — |

### Frame / dirty / demo control

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$02/8800` | `DIRTY_COUNT` | 2 | Number of dirty tile entries |
| `$02/8802`–… | `DIRTY_LIST` | pairs | `(tx,ty)` bytes; room before `$8900` |
| `$02/8900` | `FRAME_COUNT` | 2 | Frame counter |
| `$02/8902` | `EAT_INDEX` | 2 | Dirty-eat demo cursor |
| `$02/8904` | `DEMO_FREEZE` | 1 | Host≠0 → skip erase/draw/rails |
| `$02/8905`–`$02/89FF` | — | — | Free |
| `$02/8B00`–`$02/8CFF` | `ROW_ADDR` | 512 | `ScreenXY` LUT: `[y] = y*S_SHR` |
| `$02/8D00`–`$02/8EFF` | `ROW_BCK` | 512 | `BckXY` LUT: `[y] = y*S_BCK` |

### Render / harness scratch

| Address | Symbol | Notes |
|---------|--------|-------|
| `$02/8A00` | `R_X` | Screen / temp X |
| `$02/8A02` | `R_Y` | Screen / temp Y |
| `$02/8A04` | `R_TX` | Tile X |
| `$02/8A06` | `R_TY` | Tile Y |
| `$02/8A08` | `R_TILE` | Tile code |
| `$02/8A0A` | `R_OFF` | Byte offset / mul scratch |
| `$02/8A0C` | `R_DEST` | SHR offset (`ROW_ADDR[Y]+X/2`) |
| `$02/8A0E` | `R_ROW` | Row counter |
| `$02/8A10` | `R_IDX` | Sprite index |
| `$02/8A12` | `R_CARRY` | Nibble / mul scratch |
| `$02/8A14` | `R_TMP` | General temp |
| `$02/8A16` | `R_ACT` | Actor index |
| `$02/8A18` | `R_BASE` | Actor base (`ACTORS16+…`) |
| `$02/8A1A` | `R_SAVE` | Scratch |
| `$02/8A1C` | `R_BODY` | Body pen for remap |
| `$02/8A1E` | `R_BTMP` | Blit temp |
| `$02/8A20` | `R_BDEST` | BCK offset (`ROW_BCK[Y]+(X-72)/2`) |
| `$02/8A22`–`$02/8AFF` | — | Free (Y-sort keys live in high DP) |

`BANK2` = `$020000` (long base for `,x` with 16-bit offset).  
`ACTORS16` = `$8400`.

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

## Ownership (register model)

| Region | Publisher | Consumer |
|--------|-----------|----------|
| `ACT_X`/`ACT_Y` (new) | Rails / game logic | Draw |
| `ACT_OX`/`ACT_OY` (old) | `CopySpritePos` after draw | Erase |
| `ACT_SPR` / `ACT_COLOR` | Rails / init | `DrawSprite` (compiled `GhostBlitGo` / `FruitBlitGo` / `MsPacBlitGo`) |
| `ACT_WP` | Rails | Rails only |
| `ACT_FLAGS` | Render | Render |
| `TILEMAP` / dirty list | Game logic | Tile redraw (`DrawTile` → SHR + BCK) |
| BCK strip (`$01/A000`) | `DrawMaze` / `DrawTile` | `EraseSprite` (abs restore → SHR) |
| `$03/*` assets | Host inject | Render (read) |
| SHR `$01/2000` | Render | Display |

---

## Gaps / constraints

1. **Code must stay below `$02/8000`** (working RAM starts there).
2. Six actors: 6×16 = 96 → actors through `$845F`.
3. Dirty playfield changes must update **both** SHR and the BCK strip.
4. Odd sprite/mask forms are **host-injected** (not generated on target in the current harness).

When this map changes, update [`iigs/equates.s`](../iigs/equates.s) first, then this file.
