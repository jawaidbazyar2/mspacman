# IIgs harness memory map (v1)

Shared sizes/pens live in [`iigs/equates.s`](../iigs/equates.s). **Static** host addresses are in [`iigs/mem_static.s`](../iigs/mem_static.s). Host inject: gs2-debug MCP `write_mem` (domain `MAIN`; cookbook in [`AGENTS.md`](../AGENTS.md)). `$E1` SHR tracks bank `$01` for display.

**Two assemble-time hosts** (same game bodies):

| Host | Make | Output | Memory |
|------|------|--------|--------|
| **Static** | `make iigs` / `iigs-game` | `harness.bin` / `game.bin` | Fixed banks below; inject + `CALL 768` |
| **GS/OS** | `make iigs-gsos` | `MSPACMAN.SYS16` → `~/src/IIgsDisks/mspacmangs.2mg` via `cp2` | Relocatable OMF; BCK + assets are data segments |

**Convention:** `BB/AAAA` = bank `BB`, offset `AAAA`. Long address `$bbAAAA`.

Static while running: **DB = `$02`** (code bank), **DP = `$0000`**, **stack** = `$01FF`. SHR blits temporarily set **DB = `$01`**. BCK is always **long** through `BCK_PIXELS` (never abs in bank `$01`).

---

## Bank overview (static inject)

| Bank | Role |
|------|------|
| `$00` | Soft-switches, page-3 trampoline, stack |
| `$01` | SHR shadow only (`$2000–$9FFF`) — normal SHR shadow; no IOLC/BCK hacks |
| `$02` | Harness code (the whole bank) |
| `$03` | Injected graphics / maze assets (read-only at runtime) |
| `$04` | PF **BCK** strip at `$04/2000` (`S_BCK` stride, long refs); work RAM at `$04/A000` |
| `$E1` | Displayed SHR (tracks `$01` SHR region; host PNG capture) |

```
$00  soft-switches, CALL 768 stub
$01  SHR $2000–9FFF ──shadow──► $E1
$02  code
$03  tiles | sprites/masks even+odd | maze | stitched cells
$04  BCK strip @ $2000 (S_BCK) | work RAM @ $A000: tilemap | actors | dirty | HUD | row LUTs
```

### GS/OS OMF segments

| Segment | Contents |
|---------|----------|
| Main (code) | Relocatable game; `ext BCK_PIXELS`, `ext AST_*`, `ext` work symbols |
| Bck (data) | `BCK_PIXELS ds BCK_CLEAR_BYTES` — loader patches erase/draw longs |
| Assets (data) | `PUTBIN` tiles/sprites/maze (same bytes as static bank `$03`) |
| Work (data) | Tilemap, actors, arcade `#4D`/`#4E` mirror, dirty list, row tables — `seg_work.s` |

SHR remains bank `$01` with normal shadowing (no odd-bank / shadow-all). Work RAM is an OMF data segment (not fixed `$04Axxx`). The static map mirrors that: work RAM sits outside the code bank and every reference to it is long, so the code segment and `lower_host.bin` may each fill a bank.

**65816 / Merlin caveat:** `LDX` / `LDY` have no 24-bit absolute form. `ldx >EXT_LABEL` assembles as 16-bit `LDX abs` against **DB**, so GS/OS work-segment symbols must be read with `lda >LABEL` / `tax` (see `actor_publish.s`).
---

## Bank `$00` — I/O and entry

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$00/0300` | (trampoline) | 6 | `CLC` / `XCE` / `JML $020000` — Applesoft `CALL 768` |
| `$E0/C000` | `KBD` | — | Key data + pending (bit 7) |
| `$E0/C010` | `KBDSTRB` | — | Clear keyboard strobe |
| `$E1/C019` | `RDVBLBAR` | — | VBL sense (bit7 set in VBL) |
| `$E0/C029` | `NEWVIDEO` | — | SHR enable (`$C1` in harness) |
| `$E0/C035` | `SHADOW` | — | `$B7`: inhibit text/HGR/aux/TEXT2; bit3=0 SHR on; bit6=0 IOLC intact |
| `$E0/C034` | `BORDCOLOR` | — | Border colour nibble |
| `$E0/C050` | `TXTCLR` | — | Graphics mode |

Stack pointer initialized to `$01FF` at `Start`.

### Direct page (`DP = $0000`)

Low DP holds the render / harness scratch. It used to live at `$02/AA00` and be
reached with long addressing; direct page is always bank `$00`, so it stays
reachable across the `DB = $01` switch in the blits at 4 cycles / 2 bytes
instead of 6 / 4. Always spell these with an explicit `<`.

| DP | Symbol | Notes |
|----|--------|-------|
| `$10` | `R_X` | Screen / temp X |
| `$12` | `R_Y` | Screen / temp Y |
| `$14` | `R_TX` | Tile X |
| `$16` | `R_TY` | Tile Y |
| `$18` | `R_TILE` | Tile code |
| `$1A` | `R_OFF` | Byte offset / mul scratch |
| `$1C` | `R_DEST` | SHR offset (`ROW_ADDR[Y]+X/2`) |
| `$1E` | `R_ROW` | Row counter |
| `$20` | `R_IDX` | Sprite index |
| `$22` | `R_CARRY` | Nibble / mul scratch |
| `$24` | `R_TMP` | General temp |
| `$26` | `R_ACT` | Actor index |
| `$28` | `R_BASE` | Actor base (`index×16` into `ACTORS`) |
| `$2A` | `R_SAVE` | Scratch |
| `$2C` | `R_BODY` | Body pen for remap |
| `$2E` | `R_BTMP` | Blit temp |
| `$30` | `R_BDEST` | BCK offset (`ROW_BCK[Y]+(X-72)/2`) |
| `$32` | `R_PEN` | HUD glyph ink pen (`BlitTileAbs`) |
| `$34`–`$E9` | — | Free |

High DP holds the Y-order key arrays (actor records are not moved):

| DP | Symbol | Size | Notes |
|----|--------|------|-------|
| `$EA`–`$EB` | `DP_KEYI` / `DP_KEYY` | 2 | insertion temps |
| `$EC`–`$ED` | `DP_YOFF` | 2 | `ACT_Y` / `ACT_OY` field offset |
| `$EE`–`$EF` | `DP_I` / `DP_J` | 2 | sort loop indices |
| `$F0`–`$F5` | `DP_SORT` | 6 | actor indices, Y-ascending |
| `$F6`–`$FB` | `DP_YKEY` | 6 | Y low for actor `0..5` (by actor #) |

Index these with **X**, never Y: the 65816 has no `LDA dp,Y`, and Merlin32
silently demotes it to `LDA abs,Y`, which resolves against `DB = $02` and reads
the code image instead of direct page.

---

## Bank `$01` — SHR shadow

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$01/2000`–`$01/9CFF` | `SHR_PIXELS` | 32000 | 320×200 4bpp; stride **`S_SHR` = 160** |
| `$01/9D00`–`$01/9DFF` | `SHR_SCB` | 256 | Scanline control (palette 0, 320 mode) |
| `$01/9E00`–`$01/9E1F` | `SHR_PALETTE` | 32 | Palette 0 (16× SHR `$0RGB` words) |

Playfield blit origin: **(76, 7)**; size **168×186** (28×31 × 6×6). Soft-switches via `$E0`/`$E1`. Do **not** poke `$E1` SHR pixels on the hot path.

## Bank `$04` — playfield backing strip (static)

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$04/2000`–… | `BCK_PIXELS` | `BCK_CLEAR_BYTES` | Maze/tiles only; stride **`S_BCK` = 88**; long `>BCK_PIXELS,x` |

BCK origin X = `SPR_BASE_X` (72) so 14×12 erase fits. `BckXY`: `ROW_BCK[Y] + (X-72)/2`. GS/OS: same symbol is an OMF data-segment label (loader-relocated).

---

## Bank `$02` — code

Merlin `org $0000` → loaded at `$02/0000`.

| Address | Size | Notes |
|---------|------|-------|
| `$02/0000`–… | `lower_host.bin` / `harness.bin` / `game.bin` | Code + compiled ghost/fruit/Ms. Pac blits. May fill the bank (`make iigs-lower` checks ≤ 64 KB) |

## Bank `$04` from `$A000` — working RAM

All references are long (`>SYMBOL`), as the GS/OS `Work` segment requires.

### Logical tilemap and actors

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$04/A000`–`$04/A363` | `TILEMAP` | 868 | 28×31 tile codes (copy of `AST_MAZE`) |
| `$04/A364`–`$04/A3FF` | — | — | Unused pad to actors |
| `$04/A400`–`$04/A45F` | `ACTORS` | 96 | 6 actors × 16 bytes (4 ghosts + fruit + Ms. Pac) |
| `$04/A460`–`$04/A59F` | `RAM4D` | 320 | **Game build:** arcade `#4D00`–`#4E3F` mirror (actor physics, speeds, modes, dots). Demo unused. |
| `$04/A5A0`–`$04/A7FF` | — | — | Free |

### Actor record (`ACT_SIZE` = 16)

Base = `$04A400 + index×16`. Indexed in asm as `X = index×16` with `>ACTORS+field,x`.

| Off | Symbol | Type | Who writes | Who reads |
|-----|--------|------|------------|-----------|
| +0 | `ACT_X` | word | rails / logic (**new**) | `DrawSprite` |
| +2 | `ACT_Y` | word | rails / logic (**new**) | `DrawSprite` |
| +4 | `ACT_OX` | word | `CopySpritePos` / init (**old**) | Y-sort (`ACT_OY` path) |
| +6 | `ACT_OY` | word | `CopySpritePos` / init (**old**) | Y-sort before `WaitVBL` |
| +8 | `ACT_SPR` | byte | rails / fruit / pac (ghost `$20–$27`, fruit `$00–$07`, Ms. Pac `dir*3+mouth`) | `DrawSprite` → ghost/fruit/MsPac blit table |
| +9 | `ACT_FLAGS` | byte | render (`FLAG_DRAWN`) | render |
| +10 | `ACT_WP` | byte | rails (waypoint index; ghosts + Ms. Pac) | rails only |
| +11 | `ACT_COLOR` | byte | init (ghost body pen 5/7/9/11; unused for fruit/Ms. Pac) | `DrawSprite` → `GhostBlitTable` |
| +12 | `ACT_DEST` | word | `DrawSprite` (SHR offset) | `EraseSprite` |
| +14 | `ACT_BDEST` | word | `DrawSprite` (BCK offset) | `EraseSprite` |

### Frame / dirty / demo control

| Address | Symbol | Size | Notes |
|---------|--------|------|-------|
| `$04/A800` | `DIRTY_COUNT` | 2 | Number of dirty tile entries |
| `$04/A802`–… | `DIRTY_LIST` | pairs | `(tx,ty)` bytes; room before `$8900` |
| `$04/A900` | `FRAME_COUNT` | 2 | Frame counter |
| `$04/A902` | `EAT_INDEX` | 2 | Dirty-eat demo cursor |
| `$04/A904` | `DEMO_FREEZE` | 1 | Host≠0 → skip erase/draw/rails |
| `$04/A906` | `POWER_FLASH_CNT` | 1 | `BlinkPowerPills` period counter |
| `$04/A908`–`$04/A90A` | `SCORE_LO/MID/HI` | 3 | P1 score, BCD lo/mid/hi (arcade `#4E80`) |
| `$04/A90B`–`$04/A90D` | `HISCORE_LO/MID/HI` | 3 | High score, BCD (arcade `#4E88`) |
| `$04/A90E` | `LIVES` | 1 | Lives shown in HUD (arcade `#4E15`) |
| `$04/A90F` | `LEVEL` | 1 | Level number, 0 = cherry (arcade `#4E13`) |
| `$04/A910` | `CREDITS` | 1 | Credits shown in HUD, BCD, `$FF` = free play (arcade `#4E6E`) |
| `$04/A911`–`$04/A913` | `SCORE2_LO/MID/HI` | 3 | P2 score, BCD lo/mid/hi (arcade `#4E84`) |
| `$04/A914`–`$04/A9FF` | — | — | Free |
| `$04/AB00`–`$04/ACFF` | `ROW_ADDR` | 512 | `ScreenXY` LUT: `[y] = y*S_SHR` |
| `$04/AD00`–`$04/AEFF` | `ROW_BCK` | 512 | `BckXY` LUT: `[y] = y*S_BCK` |

| `$04/AA00`–`$04/AAFF` | — | — | Free (was `R_*`; scratch moved to low DP) |

`ACTORS` = `$04A400` (long base; `X = index×16`).  
`BANK_WORK` / `BANK2` = `$020000` for HUD string / score BCD offsets (`>BANK2,x`).

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
| `ACT_OX`/`ACT_OY` (old) | `CopySpritePos` after draw | Y-sort |
| `ACT_DEST`/`ACT_BDEST` | `DrawSprite` | `EraseSprite` |
| `ACT_SPR` / `ACT_COLOR` | Rails / init | `DrawSprite` (compiled `GhostBlitGo` / `FruitBlitGo` / `MsPacBlitGo`) |
| `ACT_WP` | Rails | Rails only |
| `ACT_FLAGS` | Render | Render |
| `TILEMAP` / dirty list | Game logic | Tile redraw (`DrawTile` → SHR + BCK) |
| BCK strip (`BCK_PIXELS`) | `DrawMaze` / `DrawTile` | `EraseSprite` (long restore → SHR) |
| `$03/*` assets | Host inject (MCP `write_mem`) | Render (read) |
| SHR `$01/2000` | Render | Display |

---

## Game-build arcade RAM (`RAM4D` @ `$04A460` == `#4D00`)

Field equates in [`iigs/equates.s`](../iigs/equates.s) (`PAC_X`, `RED_DIR`, `DOTS_EATEN`, `LEVEL_STATE`, …). Offsets match [`src/ram.inc`](../src/ram.inc). Soft `STICK_IN0` / fruit timers sit just after the `#4E` block (`$04A590+`).

`ActorPublish` converts arcade pixel (Y,X) → upright SHR `ACT_X`/`ACT_Y` (tile map from `j_0065` / `gen_maze1` upright extract, then ×6/8 + `SPR_BASE_*`).

## Dual builds

| Artifact | Link unit | `FrameTick` | Uses `RAM4D` |
|----------|-----------|-------------|--------------|
| `harness.bin` | `link_demo.s` | `DemoTick` | no |
| `game.bin` | `link_game.s` | `LogicTick` | yes |

## Gaps / constraints

1. **Code must fit bank `$02`**; working RAM is in bank `$04` at `$A000`. Reach it only with long addressing.
2. Six actors: 6×16 = 96 → actors through `$845F`; game RAM starts at `$8460`.
3. Dirty playfield changes must update **both** SHR and the BCK strip.
4. Odd sprite/mask forms are **host-injected** (not generated on target in the current harness).

When this map changes, update [`iigs/equates.s`](../iigs/equates.s) first, then this file.
