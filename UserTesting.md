# User testing — IIgs rail harness in GSSquared

How to build and run the Merlin32 soft-render harness (four ghosts on rails) under [GSSquared](https://github.com/) so you can watch motion live.

## Prerequisites

| Dependency | Default path (override with env / make vars) |
|------------|-----------------------------------------------|
| GSSquared binary | `$HOME/src/gssquared/build/GSSquared` (`GSSQUARED`) |
| GSSquared Python client | `$HOME/src/gssquared/clients/python/src` (`PYTHONPATH`) |
| Merlin32 | `$HOME/src/Merlin32_v1.1/MacOs/Merlin32` |
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

Same thing directly:

```bash
python3 py/gs2_run_demo.py
```

- Watch the GSSquared window (border = phase profiler).  
- **Any key in the emulator** → 65816 `ExitDemo`.  
- **Enter in the terminal** → quit GSSquared.

## Still-frame CI-style capture

Spawns GSSquared, runs briefly, freezes, writes `build/iigs/frame.png`, quits:

```bash
make iigs-test
```

Timed run without the interactive waiter:

```bash
PYTHONPATH=$HOME/src/gssquared/clients/python/src \
  python3 py/gs2_render_test.py --run-seconds 60
```

## What you should see

- Maze 1 in SHR 320×200 (pink/red walls, pellets).  
- Four ghosts on a shared waypoint loop: **red / pink / cyan / orange**, spaced around the path.  
- Smooth erase → draw → commit → rails (move is outside the blit hole).  
- **Border color = phase profiler** (width of each color ≈ time in that phase):

| Border | Phase |
|--------|--------|
| Purple | `EraseAllSprites` (fast after unroll — easy to miss) |
| Green | `DrawAllSprites` (usually the wide band) |
| Light blue | `CopySpritePos` |
| Orange | `AdvanceRails` |
| Black | `WaitVBL` slack — **no black ⇒ work fills the frame** (orange→purple can look “yellow”) |
| White | `DEMO_FREEZE` (host capture) |

Order in time: purple → green → light blue → orange → **black** → (repeat). Yellowish flash at the wrap usually means orange+purple with **no black** (budget full), not a mystery fifth color.

## Useful flags

| Flag | Meaning |
|------|---------|
| `--gs2 PATH` | GSSquared binary (default `$GSSQUARED` or `~/src/gssquared/build/GSSquared`) |
| `--socket PATH` | Debug socket when spawning (default `/tmp/gs2-mspacman.sock`) |
| `--attach SOCK` | Attach to an already-running GS2; do not spawn or quit it |
| `--run-seconds N` | Seconds of live demo before host freeze + PNG |
| `--bin` / `--gfx` / `--out` | Harness binary, asset dir, PNG path |

## Notes

- Boot path uses **Control-Reset** (Ctrl+F12), not Control-OpenApple-Reset.  
- Entry is Applesoft `CALL 768` → page-3 trampoline → `$02/0000`.  
- Design detail: [`docs/IIgs-Design.md`](docs/IIgs-Design.md) §3.3.  
- CI-style still check: `make iigs-test` → inspect `build/iigs/frame.png`.
