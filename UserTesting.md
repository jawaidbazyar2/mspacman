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

## Quick look (script owns the emulator)

Spawns GSSquared, boots to Applesoft, injects harness + assets, types `CALL 768`, runs the demo, then freezes and writes `build/iigs/frame.png` before quitting the emu:

```bash
make iigs-test
```

For a longer interactive window before freeze/quit:

```bash
PYTHONPATH=$HOME/src/gssquared/clients/python/src \
  python3 py/gs2_render_test.py --run-seconds 60
```

Watch the GSSquared window during the run. Press **any key** in the emulator to end the demo early (clears `$C000` via `$C010`, drops SHR, hangs). If you wait out `--run-seconds`, the host sets `DEMO_FREEZE` (`$02/7904`) and captures a PNG.

## Keep GSSquared open (attach)

**Terminal 1** — start the emulator with the debug socket:

```bash
$HOME/src/gssquared/build/GSSquared -p 5 --debug /tmp/gs2-mspacman.sock --no-quit-confirm
```

**Terminal 2** — inject and run without quitting the emu when the script exits:

```bash
cd /path/to/mspacman
PYTHONPATH=$HOME/src/gssquared/clients/python/src \
  python3 py/gs2_render_test.py \
    --attach /tmp/gs2-mspacman.sock \
    --run-seconds 120
```

Animation runs for `--run-seconds`; then the script freezes and captures `build/iigs/frame.png` but leaves GSSquared running. Keypress still ends the demo from inside the harness.

## What you should see

- Maze 1 in SHR 320×200 (pink/red walls, pellets).  
- Four ghosts on a shared waypoint loop: **red / pink / cyan / orange**, spaced around the path.  
- Smooth erase → move → draw (no mid-band “missing sprite” tear if beam waits are working).

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
