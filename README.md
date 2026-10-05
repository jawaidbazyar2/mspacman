# Ms. Pac-Man → Apple IIgs

THIS PROJECT IS PURELY FOR EDUCATIONAL PURPOSES.

Port arcade Ms. Pac-Man to the **Apple IIgs**.

Phase 0 was: a trustworthy Z80 source pipeline: real assemblable instructions that rebuild **byte-identical** known-good ROMs (`boot1`–`boot6` from MAME’s `mspacmab` set). Once that foundation is solid, the codebase can evolve toward a 65816 / IIgs target (graphics, sound, input).

The original hand-disassembly is in ~/mspac.asm
The byte-exact assemblable Ms PacMan is in src/mspac.asm.

The first attempt to get LLM to port the src/mspac.asm Z80 directly to 65816 is in the "iigs" folder. It wasn't terrible, but it was constant Whack-a-Mole finding and fixing logic errors. Very slow grind, and I could tell it would not resolve to an accurate solution without a great deal of human effort.

However at this point I shifted strategy and went to test-driven development that did not involve me being a communication middleman between game and Agent. In my recent experience, given the sufficient and the right type of test data, Agents can rapidly converge on correct solutions. (This part always feels like Genetic Programming to me - an interesting concept from the mid 90s).

## Phase 1: Build Test Corpus through Z80 Emulation

Run the actual Z80 build using a Z80 emulator along with an I/O and board test harness borrowed from MAME.

I used that to record a lot of game play for testing.

The recording was not just my input, but the state of all RAM, video memory and machine state at end of every single frame. About 2.5KB per frame. Even on relatively long game play sessions this was a manageable amount of data, 50 - 150 MB.

My goal was to ensure algorithmic identity with the original arcade version, and, the way to verify that is to ensure identity of all input AND output. We don't care about the *rendering* of the output, so we compared the functional output - variables, the video buffer (tiles) memory and sprite locations and parameters.

I also cleaned up the Z80 code at this point, replacing bare addresses with human-readable labels for variables in RAM etc.

## Phase 2: Lift to C

I then converted the Z80 to C in two passes. The first, where the C still 'thought' in terms of Z80 registers and structure. Reading this code, you can see how the C routines are communicating through a "write memory" interface, and reading and storing values into a struct containing the Z80 registers.

We modified one routine at a time, and there was cross-calling between emulated Z80 and C until the process was complete.

The Z80-focused C is in the source folder "c".

# Phase 2.5: Lift to Idiomatic C

The second converted that to “idiomatic C” i.e. the logic was function based instead of register-side-effect based. During this phase, again, there was a combo of old and new routines and we modified one routine at a time.

I kept the RAM layout identical, because otherwise the tests wouldn't work. So the RAM was modeled as a large C struct that was unioned with the bare RAM buffer. 

The idiomatic C is in the folder "idiom".

At this point I had to decouple registers out of the test data and made new recordings;
but this C version was provably identical to the emulated Z80 version.

## Phase 3: Lower to 65816

Then did the same thing, but C down to 65816. I did not use a C compiler, the AI did the conversion to 816.

By the Transitive property of equality, Z80 == C, and C == 65816, so even though the tests were somewhat different, the coverage was not, and thus Z80 == 65816, the game logic is provably identical to the original arcade version.

Every time a function was converted from Z80 to C or from C to 65816, the entire test suite was run and results compared to original output, and that’s how the LLM knew its work each step was correct.

I then have a chunk of code that reinterprets the video RAM and renders on the GS screen

We know the 65816 version is generating exactly the same output the original Z80 game does: the RAM, Video buffer, and machine state were compared identical to the recordings done in Phase 2. 

Then we render that to the GS screen through a "iigs host" layer.

# Rendering

## Video

All coordinates of the monsters, PacMan, motion etc are calculated using original-game-pixels, then scaled to IIgs coordinates. So the timing of movement is identical to original, with the exception that original was 60Hz and the IIgs is of course 59.9226Hz. 

The original Ms PacMan screen is a normal 4:3 NTSC display but it's rotated so it's portrait mode. It's 28 x 36 tiles of 8x8, so 224 x 288 pixels. 

The original game also has a tiles+sprites system, with 16x16 sprites that can be drawn anywhere on screen, as well as flipped on the H or V axes or both. Each tile location on screen can have one of a number of 4 color palettes, as can each sprite.

The IIgs screen is normal 4:3 and 320x200, and is a bare frame buffer with no sprites. Also, the 16-color palette is for the entire display, so we clearly have a challenge fitting the display here.

First, color mapping is done. We use palette color flipping in only one place, at the end of a level where the maze flashes, which is done by erasing the sprites and dot tiles, then changing the two palette entries. 

All other sprite/tile palette colors are mapped into the 16-color IIgs palette. Some of the entries change per level.

I chose to scale the graphics 6/8, which if I did my math right provides same aspect ratio as the original game. But it does mean I can write whole bytes and not mess with 4-bit updates which would be S L O W. On the IIgs 320 mode, one byte is two pixels. So this scale maintains the aspect ratio and keeps all writes byte-aligned.

The sprites are all compiled, so instead of trying to copy pixel data, it’s just a 816 subroutine that writes a sprite to RAM, performing overlay and transparency (with color 0).

Python programs generate the various compiled sprites from ppm source files.

Tiles are only ever drawn on 6-pixel boundaries. Sprites, however, can be drawn at arbitrary pixel locations. So, I generate two routines for each sprite, one at even pixel, one at odd pixel, and, the 12x12 sprite is inside a 14x12 container, so we still have a byte boundary no matter the sprite position.

Another key optimization is that the maze (tiles) is rendered first to a backing store. Sprites have to be drawn, then erased and drawn at new location if they moved. The erase is done by just copying the backing store pixels back into the frame buffer. Each new level, a new backing store is generated.

Credit to fatdog for cleaning up the rescaled tiles and sprites. Going from 8x8 to 6x6 is not easy, but he is a master at this!

## Audio

The audio in PacMan/Ms PacMan is a wavetable based, though each wave is relatively lores 4-bit x 32 samples. There are 8 different waves used in the game, so at startup the IIgs version converts them to 32KB of ensoniq data (4KB per wave), loads the DOC with them, then the game just triggers them at varying frequencies as needed. (edited)

## Input

There is a key mapped to each arcade Pac-Man input: the stick, the 1- and 2-player start buttons, insert coin, and a rack-test switch that skips a level. The stick is the arrow keys, WASD, or the numeric keypad (8 up, 4 left, 6 right, 2 down). The keypad shares ASCII codes with the number row, so the IIgs keypad bit tells them apart: number-row 1, 2, and 5 stay the buttons below, and those same keys on the keypad do not.

| Key | Action |
|-----|--------|
| C or 5 | Insert coin |
| 1 | Start 1-player game |
| 2 | Start 2-player game |
| WASD, arrows, or keypad 8/4/6/2 | Steer Pac-Man |
| Control-S | Skip to the next level |
| Esc | Pause |
| Open Apple-Q | Quit |

# Conclusion

I could have done the exact same process writing code manually, with the same success. It just would have taken 50 times longer.

GS2's AI Agent MCP interface was stupendously helpful as the agent could trivially exercise the game and inspect what was going on , during debugging.

The fun part is that of course at one point I had a version of the game written in idiomatic C, using SDL3 library for I/O, graphics, sound. This is arcade identical (same graphics), but super small. This is the code base in the "idiom" folder.

# Disclaimer

Ms. Pac-Man and Pac-Man are trademarks of and copyrighted by Namco, Bally/Midway, GCC, and successors. Scott Lawrence’s disassembly and this derivative work are educational / research projects and are not sanctioned by the rights holders. Nobody is making money off this in any way. I just hope folks enjoy some nostalgia overload. And, I wanted to explore techniques for using AI to port retro code bases to modern systems, which I believe I achieved splendidly.

# Original README

## Original source

This work builds on Scott Lawrence’s annotated disassembly of the bootleg Ms. Pac-Man ROMs:

- **Repository:** [BleuLlama/GameDocs](https://github.com/BleuLlama/GameDocs) — especially [`disassemble/mspac.asm`](https://github.com/BleuLlama/GameDocs/blob/master/disassemble/mspac.asm)
- **Author site copy:** [umlautllama.com `mspac.asm`](http://umlautllama.com/projects/pacdocs/mspac/mspac.asm)

In this repo, that listing is kept as the read-only master file `mspac.asm`. Editable / assemblable work lives under `src/` (mainly `src/mspac.asm`). Do not edit the master listing in place.

Hardware and ROM-map notes: [Rom.Files.md](Rom.Files.md). Agent-oriented conventions: [AGENTS.md](AGENTS.md).

## Golden ROMs

Reassembly is verified against MAME **`mspacmab`** (Ms. Pac-Man bootleg, set 1):

| File | Load address | Size | CRC32 |
|------|--------------|------|--------|
| `boot1` | `0x0000`–`0x0FFF` | 4KB | `d16b31b7` |
| `boot2` | `0x1000`–`0x1FFF` | 4KB | `0d32de5e` |
| `boot3` | `0x2000`–`0x2FFF` | 4KB | `1821ee0b` |
| `boot4` | `0x3000`–`0x3FFF` | 4KB | `165a9dd8` |
| `boot5` | `0x8000`–`0x8FFF` | 4KB | `8c3e6de6` |
| `boot6` | `0x9000`–`0x9FFF` | 4KB | `368cb165` |

### Where to get `boot1`–`boot6`

These are the six CPU program ROMs from the MAME ROM set **`mspacmab`** (full name: *Ms. Pac-Man (bootleg, set 1)*).

1. Obtain a MAME `mspacmab` ROM set (typically distributed as `mspacmab.zip`). ROM images are copyrighted; you must source them legally for your jurisdiction (e.g. dumps from boards you own, or other licensed channels). This project does not redistribute ROMs.
2. Extract `boot1` through `boot6` from that zip into the **repository root** (same directory as the `Makefile`).
3. Confirm CRCs match the table above (MAME’s expected checksums are also listed in the driver: [`src/mame/pacman/pacman.cpp`](https://github.com/mamedev/mame/blob/master/src/mame/pacman/pacman.cpp) — search for `mspacmab`).

If you already have `mspacmab.zip` in the repo root, unzip it there:

```bash
unzip -j mspacmab.zip boot1 boot2 boot3 boot4 boot5 boot6 -d .
```

The set also contains graphics/PROM files (`5e`, `5f`, `82s123.7f`, …); those are not needed for `make verify`. The encrypted original Midway/GCC set (`u5`/`u6`/`u7` under `mspacman`) is **not** the reassembly target.

## Requirements

- macOS (tested on arm64) or another Unix-like host with a C++ toolchain
- [CMake](https://cmake.org/) (to build the vendored assembler)
- Python 3 (for `make verify`)

Assembler: **[SjASMPlus](https://github.com/z00m128/sjasmplus)** v1.23.1, vendored under `sjasmplus/`.

## Build

### 1. Build SjASMPlus (once)

```bash
cd sjasmplus
cmake -DCMAKE_BUILD_TYPE=Release -S . -B build
cmake --build build
./build/sjasmplus --version
cd ..
```

The binary used by the Makefile is `sjasmplus/build/sjasmplus`.

### 2. Assemble

```bash
make
```

This assembles `src/mspac.asm` into `build/mspac.bin` (flat binary via SjASMPlus `--raw`), with a listing at `build/mspac.lst`.

### 3. Verify against golden ROMs

```bash
make verify
```

Compares 4KB slices of `build/mspac.bin` at `0x0000` / `0x1000` / `0x2000` / `0x3000` / `0x8000` / `0x9000` to `boot1`–`boot6`.

### Useful targets

| Target | Action |
|--------|--------|
| `make` / `make all` | Assemble `src/mspac.asm` → `build/mspac.bin` |
| `make verify` | Byte-compare assembled image to `boot1`–`boot6` |
| `make sjasmplus-check` | Confirm the local SjASMPlus binary exists and print its version |
| `make clean` | Remove `build/` |

## Layout

```
mspacman/
  mspac.asm          # read-only master annotated disassembly
  src/mspac.asm      # working assemblable Z80 source
  src/ram.inc        # RAM / I/O EQU symbols
  boot1 … boot6      # golden mspacmab CPU ROMs
  py/                # Python helpers (labeling, gap fill, verify, …)
  docs/              # IIgs port design notes
  sjasmplus/         # vendored SjASMPlus
  Makefile
  Rom.Files.md       # hardware / ROM map notes
  AGENTS.md          # conventions for AI agents working in this repo
```

IIgs display / tile-scale decisions: [docs/IIgs-Design.md](docs/IIgs-Design.md).

## Status

`make` + `make verify` currently produce a byte-identical rebuild of `boot1`–`boot6`. The Apple IIgs port itself is not started yet; the Z80 reassembly pipeline is the foundation for that work. Early IIgs design notes (tile scale, HUD layout) live in `docs/IIgs-Design.md`.

## Make targets

Each stage of the port has a build target and a check target. Hosts that play or replay (`lift`, `c`, `idiom`, `lower`) need SDL3. The 65816 targets need [Merlin32](https://brutaldeluxe.fr/products/crossdevtools/merlin/). Playing or checking the IIgs build needs [GSSquared](https://github.com/). The GS/OS disk also needs `cp2` and `assets/template.2mg`.

### Z80 and the C hosts

| Target | What it does |
|--------|----------------|
| `make` / `make all` | Assemble `src/mspac.asm` → `build/mspac.bin` |
| `make verify` | Byte-compare that image to `boot1`–`boot6` |
| `make sjasmplus-check` | Confirm the vendored SjASMPlus binary and print its version |
| `make lift` | Phase 1 Z80 host → `build/lift/mspac-lift` |
| `make lift-check` | Run that host’s 600-frame self-check |
| `make c` | Phase 2 host → `build/c/mspac-c` |
| `make c-check` | Replay `testplay2` |
| `make c-only-check` | Replay with no Z80 instructions executed |
| `make idiom` | Idiomatic C host → `build/idiom/mspac-idiom` |
| `make idiom-check` | Replay every `corpus/c-*` session |
| `make idiom-cov` | Coverage report in `build/idiom/cov/report.txt` |

### 65816 game logic

| Target | What it does |
|--------|----------------|
| `make lower` | Assemble `lower/*.s` → `build/lower/lower.bin`, and build the shadow harness `build/lower/mspac-lower` |
| `make lower-check` | Shadow-compare every lowered function against `corpus/c-*` |
| `make lower-only` | 65816-only harness `build/lower/mspac-lower-only` (no game-logic C linked) |
| `make lower-only-check` | Replay the corpus on that harness and summarize cycles |
| `make lower-cov` | Coverage report in `build/lower/cov/report.txt` |

### Graphics

Art comes from `assets/tiles_6x6_clean.ppm` and `assets/sprites_14x12_clean.ppm`. Palette and sound data come from the PROMs under `mspacman/` (`82s123.7f`, `82s126.4a`, `82s126.1m`).

| Target | What it does |
|--------|----------------|
| `make gfx` | 6×6 tiles and 14×12 sprites in `build/gfx/`, plus the palette |
| `make gfx-ppm` | The same, and PPM contact sheets under `build/gfx/ppm/` |
| `make palette` | SHR palette and tile color banks → `iigs/palette_data.s`, `iigs/tile_bank_data.s` |
| `make maze` | Level-1 28×31 tilemap (needs `boot1`–`boot6`) |
| `make tiles-preview` | Native 8×8 sheets to check rotate and flip (`COMPARE=native,cw,upright`) |
| `make gfx-rom` | ROM-scaled sheets from `mspacman/5e` and `5f` under `build/gfx/rom/`, for reference |

### Apple IIgs

`make iigs-lower` is the game: lowered 65816 logic plus the SHR renderer. It writes `build/iigs/lower_game.bin` and `build/iigs/lower_host.bin`.

| Target | What it does |
|--------|----------------|
| `make iigs-lower` | Build those two images (art, compiled sprites, palette, and `build/mspac.bin` included) |
| `make iigs-lower-demo` | Boot them in GSSquared and leave the game running |
| `make lower-iigs-check` | Replay corpus sessions in GSSquared and compare each frame. `LOWER_IIGS_SESSIONS` picks the sessions (default `c-shakedown`, `c-attract`, `c-play1`); `LOWER_IIGS_FRAMES` caps frames per session (default 600, `0` for all) |
| `make iigs-lower-gsos` | GS/OS application `build/iigs/gsos/MSPACMAN.SYS16` on a bootable copy of the template, `build/iigs/MsPacMan.2mg`. `IIGS_LOWER_GSOS_INSTALL=1` also copies it onto `IIGS_GSOS_DISK` |
| `make iigs-gsos-prod` | The same disk with the border phase colors turned off |

`make clean` removes `build/`.

