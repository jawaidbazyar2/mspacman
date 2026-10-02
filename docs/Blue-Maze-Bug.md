# Blue-maze bug (original arcade)

The first maze is sometimes the wrong color: deep blue (easy to read as purple) instead of peach. This is a known bug in the original Ms. Pac-Man ROMs, not a lift defect. Phase 1 and phase 2 both show it because both run those bytes. Do not "fix" it in the C port; a fix would diverge from the phase 1 oracle.

Don Hodges documented it in 2008 ([ms_pacman_bugs.htm](http://donhodges.com/ms_pacman_bugs.htm)). The locked listing records it as `BUGFIX03`.

## When it happens

Insert a credit during the first second of attract mode, after the marquee appears and before Blinky does. Coin in after Blinky is on screen and the first maze stays peach.

## Why

Attract mode, at the start of subroutine 0, inserts a one-second timed task:

```
058A  F7        RST  #30
058B  4A 02 00          ; timer $4A (1 second), task 2, parameter 0
```

Task 2 increments `game_mode_sub1` (`$4E02`). Inserting a credit clears `$4E02` to 0 (`$040B`), but that timed task is still queued, so it later stores 1.

When the game starts, task 1 colors the maze (`$0677`, parameter `$01`). The color routine at `$9580` expects `$4E02` to be 0 (or `$10` while the demo maze is running). Any other value skips the level table and paints color `$01`, the Midway-logo palette, instead of level 1's `$1D`.

`$4E02` is cleared again later (`$06B3`), after the maze has already been colored.

## Colors

Wall color is pen 2 of the color code in color RAM (`$4400`), via `82s126.4a` and `82s123.7f`.

| Code | Used for | Wall pen (R, G, B) |
|------|----------|--------------------|
| `$1D` | Levels 1–2 (and 18–21) | peach `(255, 184, 174)` |
| `$01` | Midway logo, and this bug | deep blue `(33, 33, 255)` |

The level table is at `$95AE`: `$1D`, `$1D`, then `$16` ×3, `$14` ×4, `$07` ×4, `$18` ×4, `$1D` ×4.

## Hodges' fixes (not applied)

Either change shortens or removes the window. Neither is in `boot1`–`boot6`.

- At `$058B`, timer `$4A` → `$41` (1/10 second). Attract mode changes: Blinky appears sooner. A very fast coin-in can still hit the window.
- At `$0677`, jump to a hook that clears `$4E02` before queueing the color task, then return to `$067A`. Attract timing stays the same, and the window is gone.
