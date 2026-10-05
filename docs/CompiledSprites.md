# Compiled sprites (lowered IIgs build)

This catalogs the **precompiled masked blit tables** linked into `all_lower.s` and how **lowered game code** routes arcade sprite codes to them. HUD life icons and the level fruit reuse the same tables from `hud_body.s` (not separate compiled data).

Generators live under `py/gen_compiled_*.py`; outputs are `iigs/compiled_*.s` (regenerate with `make gfx` + the Makefile rules for each file).

---

## Tables at a glance

| Table | Source | Index formula | ROM sprite indices baked |
|-------|--------|---------------|---------------------------|
| **GhostBlitTable** | `gen_compiled_ghosts.py` | `ACT_COLOR×16 + (ACT_SPR&7)×2 + (X&1)` | Walk `$20–$27`; fright `$1C–$1D` (×2 frames) |
| **MsPacBlitTable** | `gen_compiled_mspac.py` | `(ACT_SPR&$1F)×2 + (X&1)` | Ms Pac `$2D,$2F,$31,$33–$37`; Pac `$19–$1B,$1A,$2E,$32` (+ flips) |
| **FruitBlitTable** | `gen_compiled_fruits.py` | `(ACT_SPR&7)×2 + (X&1)` | `$00–$07` (level fruit types) |
| **PointsBlitTable** | `gen_compiled_points.py` | Ghost: `(ACT_SPR&3)×2 + (X&1)`; fruit score: `(4+(ACT_SPR&7))×2 + (X&1)` | Ghost `$28–$2B`; fruit pop `$08–$0F` |
| **ActBlitTable** | `gen_compiled_acts.py` | `(ACT_SPR&7)×2 + (X&1)` when `FLAG_CLAPPER` | Act slate `$10–$17` (bank `#16` white) |

Each table entry is an **even/odd 14×12 cell pair** (7 bytes/row × 12 rows per blit).

**Ghost `ACT_COLOR` slots** (`equates.s` / `GhostBlitTable` rows): `0–3` Blinky/Pinky/Inky/Clyde walk; `4` frightened; `5` end-of-fright flash; `6` eyes (body stripped).

---

## Render dispatch (`render_body.s` → `DrawSprite`)

Order for each actor (after `FLAG_NODRAW` / Y clip):

1. **`FLAG_CLAPPER`** → `ActBlitGo` / `ActBlitTable`
2. Actor **4 (fruit)** → `FruitBlitGo` or `PointsBlitGo` if `FLAG_POINTS`
3. Actor **5 (Ms Pac)** → `MsPacBlitGo`
4. **Ghosts** → `PointsBlitGo` if `FLAG_POINTS`; else `MsPacBlitGo` if `FLAG_CHAR`; else `GhostBlitGo`

`SortActorsByY` may draw **Act 3 head** again when `FLAG_ACT3` and `ACT_SPR=0` (see below); that still calls `DrawSprite`, so it follows the same dispatch.

---

## Publish paths (arcade → `ACT_*`)

### Lowered host (`iigs/lower_host.s` — `LowerSprites`)

Reads hardware-style `G_SPRITE` / positions from the game bank (`lower.bin` mirror), not `actor_publish.s` (static harness only).

| Slot | Arcade code range | Flags / fields | Compiled table |
|------|-------------------|----------------|----------------|
| Ghosts 1–4 | `$10–$17` | `FLAG_CLAPPER`, `ACT_SPR = code&7` | ActBlitTable |
| Ghosts 1–4 | `$30,$18,$2C,$07,$0F` | `FLAG_ACT3`, `ACT_SPR = 0..4` (see `:a3tab`) | **Act3BlitTable (missing — see gaps)** |
| Ghosts 1–4 | `$20–$27` (+ H/V in code bits 7/6) | `ACT_COLOR` = ghost / eyes; `ACT_SPR` = frame | GhostBlitTable |
| Ghosts 1–4 | `$1C–$1D` | `ACT_COLOR` fright/flash; `ACT_SPR = code&1` | GhostBlitTable |
| Ghosts 1–4 | `$28–$2B` | `FLAG_POINTS`, `ACT_SPR = code-$28` | PointsBlitTable |
| Ghosts 1–4 | `$32,$19,$1A,$1B,$2E,$2D,$2F,$37,$31,$33,$34,$35,$36` (+ flips) | `FLAG_CHAR`, `ACT_SPR` = Ms Pac / Pac pose 0–23 | MsPacBlitTable |
| Ms Pac 5 | `$10–$17` | clapper | ActBlitTable |
| Ms Pac 5 | act3 set above | `FLAG_ACT3` | **(missing table)** |
| Ms Pac 5 | `$20+` walk / `$34–$3F` death spin | `ACT_SPR` 0–11 or spin poses | MsPacBlitTable |
| Fruit 6 | `$00–$07` | `ACT_SPR` = type | FruitBlitTable |
| Fruit 6 | `$08–$0F` | `FLAG_POINTS` (eat-fruit score) | PointsBlitTable |
| Fruit 6 | `$10–$17` | clapper | ActBlitTable |

Color byte `$00` → `FLAG_NODRAW` (hidden), same as arcade “off”.

### Lower C (`lower/*.c`) — codes written before publish

| Source | Codes | Notes |
|--------|-------|--------|
| `sprite.c` / `ghost_frames` | `$1C+phase`, `$20+dir×2+phase` | Normal play ghosts |
| `face_pac` / `pac_code` | `$30–$37` family | Ms Pac mouth (→ poses via host) |
| `fright.c` | `$1C`, `$20` (eyes), `$28+count` | Fright / eaten ghost points |
| `fruit.c` | `$00–$07` from ROM `#879D` | Level fruit |
| `pac.c` | `fruit_points+2` → `$08–$0F`; death `$34+` | Score pop / death anim |
| `maze.c` `place_actors` | `$20×4`, `$2C`, `$3F` | Attract intro layout |
| `cutscene.c` act 1 | `$10–$17` quarters, `$3F` hide pac | Pac-Man intermission hook (Ms Pac acts use scripts) |
| `cutscene.c` `cmd_move` | bytes from ROM anim tables | All intermission script frames |
| `run_cutscene` / ROM `#81F0` | per-script `CMD_ANIM` tables | See cutscene ROM set below |

Pac-Man-only hooks in `cutscene2_sprites` / `cutscene3_sprites` are documented in `lower/cutscene.c` as **never reached** in Ms Pac (states `$4E07` / `$4E08` are Pac-only).

### HUD (`hud_body.s`)

| Use | Index | Table |
|-----|-------|--------|
| Life icon | `MSPAC_LIFE_SPR` (7) → `(7×2)×2` even parity | MsPacBlitTable (W closed mouth, `$2D`+H) |
| Level fruit | `LEVEL` capped at 7 → `(type×2)×2` | FruitBlitTable |

Score digits use **tiles**, not compiled sprites.

---

## MsPacBlitTable slot map (`ACT_SPR`)

| `ACT_SPR` | Meaning | Sheet / ROM index |
|-----------|---------|-------------------|
| 0–11 | Ms Pac: 4 dirs × 3 mouths | `$2F,$37,$2D,$34,$31,$33,$35,$36` + flips |
| 12–23 | Pac-Man (Act 1 big Pac on ghost slots): dir×3 + mouth | `$1B,$19,$32,$1A,$2E` + flips |
| 7 | HUD life icon (fixed slot) | same as W closed |

Death spin (`$34–$3F` on pac slot) maps to poses `3,6,10,9,1,…` via `:spin` in `lower_host.s`, all within 0–11.

---

## Cutscene animation bytes (ROM, `build/mspac.bin`)

From `CMD_ANIM` tables referenced by script sets at `$81F0` (18 unique anim tables, **59** distinct sprite bytes with `& $3F`, excluding `$FF` terminators):

Typical ranges: fruit `$00–$07`, clapper `$10–$17`, walk `$20–$27`, points `$28–$2B`, Ms Pac / act `$2D–$37`, act3-related `$07,$0F,$18,$2C,$30`, hide `$3F`.

Placeholder **`$1F`** appears as a one-frame anim (empty sheet cell — intentional blank).

---

## Coverage check: uses vs compiled tables

### Covered by existing compiled data

- In-game ghosts, fright, eyes, points pop-ups.
- Ms Pac walk, death spin, Pac-on-ghost-slot (`FLAG_CHAR`) for listed `:charSpr` codes.
- Fruit and fruit score pop-ups.
- Act 1 clapper / board (`$10–$17`).
- HUD life + level fruit icons.

### Gaps (publish or ROM use **without** a matching blit table / draw path)

| Issue | Sprite codes | Where used |
|-------|--------------|------------|
| **`Act3BlitTable` not generated or wired in `DrawSprite`** | `$30` head, `$18` body, `$2C` wing, `$07` sack, `$0F` junior | `lower_host.s` `:a3tab` + `FLAG_ACT3`; Act 3 intermission scripts; anim tables use `$18`/`$2C` |
| **`DrawSprite` ignores `FLAG_ACT3`** | same | Published actors fall through to ghost/fruit/pac routing → wrong or hidden |
| **Blank anim frame** | `$1F` | ROM anim (harmless if never shown) |
| **Attract intro `$2C` on pac slot** | `$2C` | `maze.c` `place_actors` — host maps via open-mouth pose logic, not a direct ROM blit |

No compiled table is required for **`$3F`** (hidden pac) or **tile-only HUD**.

---

## Build inclusion (`iigs/all_lower.s`)

```
compiled_ghosts.s
compiled_fruits.s
compiled_points.s
compiled_mspac.s
compiled_acts.s
```

Static / frozen builds (`all_game.s`, etc.) omit `compiled_acts.s`; the **lowered** GS/OS and flat lower images include acts.

---

## Quick reference: generator → ROM indices

**Ghosts:** `$20–$27` × banks `#01,#03,#05,#07`; fright/flash `$1C–$1D` × `#11,#12`; eyes = walk with body pen dropped.

**Fruits:** `$00–$07` with per-type color banks from `#879D` (Junior uses bank `#09` override in generator).

**Points:** `$28–$2B`, `$08–$0F` — white pen 1.

**Acts:** `$10–$17` — bank `#16`.

**Ms Pac / Pac:** see `py/gen_compiled_mspac.py` `FRAMES` and `PAC_FRAMES`.
