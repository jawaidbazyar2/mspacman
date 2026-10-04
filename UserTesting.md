# User testing — IIgs rail harness in GSSquared

How to build and run the Merlin32 soft-render harness (four ghosts on rails) under [GSSquared](https://github.com/) so you can watch motion live.

Live peek/poke/breakpoints/keys use the **gs2-debug MCP** server (`.cursor/mcp.json`) — same protocol tools as the old Python `gs2debug` client. Agent cookbook: [`AGENTS.md`](AGENTS.md) § GSSquared live debug. `make iigs-demo` / `make iigs-test` still spawn via `py/gs2_*.py` for the one-command human/CI path.

## Prerequisites

| Dependency | Default path (override with env / make vars) |
|------------|-----------------------------------------------|
| GSSquared binary | `$HOME/src/gssquared/build/GSSquared` (`GSSQUARED`) |
| gs2-debug MCP | `.cursor/mcp.json` → `gs2-mcp --gs2-bin` that GSSquared |
| Merlin32 | `$HOME/src/Merlin32_v1.2_b2/MacOs/Merlin32` |
| Tile/sprite ROMs | `mspacman-orig/5e`, `5f` (+ color/palette PROMs for palette) |
| CPU boots (maze decode) | `boot1`–`boot6` in repo root |

## Build

```bash
cd /path/to/mspacman
make gfx maze iigs
```

- `make gfx` — 6×6 tiles + 14×12 sprites/masks  
- `make maze` — level-1 tilemap + stitched cells + ghost rails (`iigs/rails_data.s`)  
- `make iigs` — Merlin32 → `build/iigs/harness.bin`

## Interactive demo (one command)

Builds if needed, spawns GSSquared, injects, runs the rail demo, waits for **Enter in that terminal**, then quits the emulator:

```bash
make iigs-demo
```

- Watch the GSSquared window (border = phase profiler).  
- **Any key in the emulator** → 65816 `ExitDemo`.  
- **Enter in the terminal** → quit GSSquared.

## Still-frame CI-style capture

Spawns GSSquared, runs briefly, freezes, writes `build/iigs/frame.png`, quits:

```bash
make iigs-test
```

Timed run without the interactive waiter: `make iigs-test` (short capture) or MCP `launch` IIgs, inject, then `pause` / `read_mem` as in [`AGENTS.md`](AGENTS.md).

## What you should see

- Maze 1 in SHR 320×200 (pink/red walls, pellets).  
- Four ghosts on a shared waypoint loop: **red / pink / cyan / orange**, spaced around the path.  
- Erase-all → dirty tiles → draw-all by Y → commit → rails (move is outside the blit hole).  
- Ghost draw uses **compiled** 65816 blits (`compiled_ghosts.s`); eyes/walk anim via `ACT_SPR` only.  
- **Side HUD:** `1UP` + score over three Ms. Pac life icons (left), `HIGH SCORE` + `10000` over the level fruit (right). Score climbs by 10 every 300 frames (~5 s); beating the high score copies it across.  
- Ms. Pac clears pellets as she goes, leaving a black trail behind her — they must not flicker back in on the next erase.  
- **Border color = phase profiler** (width of each color ≈ time in that phase):

| Border | Phase |
|--------|--------|
| Purple | `EraseSprite` (each actor erase) |
| Green | `DrawSprite` (each actor draw) |
| Light blue | `CopySpritePos` |
| Orange | `AdvanceRails` (+ eat/score/fruit/blink) |
| Yellow | `SortActorsByY` (once; order for next erase+draw) |
| Black | `WaitVBL` slack — **no black ⇒ work fills the frame** |
| White | `DEMO_FREEZE` (host capture) |

Order in time: purple ×6 → green ×6 → light blue → orange → yellow → **black** → (repeat).

State check without eyeballing pixels: MCP `pause` + `wait_stopped` + `read_mem` domain `MAIN` (static host):

| What | Address | Length |
|------|---------|--------|
| `FRAME_COUNT` | `0x04A900` | 2 |
| score + high score (BCD) | `0x04A908` | 6 |
| `LIVES` / `LEVEL` | `0x04A90E` | 1+1 |
| `TILEMAP` (dots eaten vs `maze1_28x31.bin`) | `0x04A000` | 868 |

Poke P1 score to hit the 10000 high-score copy without waiting 1000 ticks: `write_mem` at `0x04A908`.

## MCP tools (live debug)

Same names as the old Python `Client` methods. Typical session: `launch` (platform `IIgs`) → boot/reset/inject → `pause` / `wait_stopped` → `read_mem` / `write_mem` / `bp_set` / `type_text`. Stop with `quit`. See [`AGENTS.md`](AGENTS.md).

## Notes

- Boot path uses **Control-Reset** (Ctrl+F12), not Control-OpenApple-Reset.  
- Entry is Applesoft `CALL 768` → page-3 trampoline → `$02/0000`.  
- Design detail: [`docs/IIgs-Design.md`](docs/IIgs-Design.md) §3.3.  
- CI-style still check: `make iigs-test` → inspect `build/iigs/frame.png`.
