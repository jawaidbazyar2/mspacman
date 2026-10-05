# Ms. Pac-Man → Apple IIgs

Port arcade Ms. Pac-Man to the **Apple IIgs**.

Phase 0 was: a trustworthy Z80 source pipeline: real assemblable instructions that rebuild **byte-identical** known-good ROMs (`boot1`–`boot6` from MAME’s `mspacmab` set). Once that foundation is solid, the codebase can evolve toward a 65816 / IIgs target (graphics, sound, input).

This code is in the "iigs" folder, and was an attempt to get the LLM to convert Z80 directly to 65816. It wasn't terrible, but it was constant Whack-a-Mole finding and fixing logic errors. Very slow grind, and I could tell it would not resolve to an accurate solution without a great deal of human effort.

However at this point I shifted strategy and went to test-driven development that did not involve me being a communication middleman between game and Agent. In my recent experience, given the sufficient and the right type of test data, Agents can rapidly converge on correct solutions. (This part always feels like Genetic Programming to me - an interesting concept from the mid 90s).

## Phase 1: Build Test Corpus through Z80 Emulation

Run the actual Z80 build using a Z80 emulator along with an I/O and board test harness borrowed from MAME.

I used that to record a lot of game play for testing.

The recording was not just my input, but the state of all RAM, video memory and machine state at end of every single frame. About 2.5KB per frame. Even on relatively long game play sessions this was a manageable amount of data, 50 - 150 MB.

My goal was to ensure algorithmic identity with the original arcade version, and, the way to verify that is to ensure identity of all input AND output. We don't care about the *rendering* of the output, so we compared the functional output - variables, the video buffer (tiles) memory and sprite locations and parameters.

## Phase 2: Lift to C

I then converted the Z80 to C in two passes, the first, where the C still 'thought' in terms of Z80 registers, and the second, which converted that to “idiomatic C” i.e. the logic was function based instead of register-side-effect based.

The Z80-focused C is in the source folder "c". The idiomatic C is in the folder "idiom".

At this point I had to decouple registers out of the test data and made new recordings;
but this C version was provably identical to the emulated Z80 version.

## Phase 3: Lower to 65816

Then did the same thing, but C down to 65816. I did not use a C compiler, the AI did the conversion to 816.

By the Transitive property of equality, Z80 == C, and C == 65816, so even though the tests were somewhat different, the coverage was not, and thus Z80 == 65816, the game logic is provably identical to the original arcade version.

Every time a function was converted from Z80 to C or from C to 65816, the entire test suite was run and results compared to original output, and that’s how the LLM knew its work each step was correct.

I then have a chunk of code that reinterprets the video RAM and renders on the GS screen

We know the 65816 version is generating exactly the same output the original Z80 game does: the RAM, Video buffer, and machine state were compared identical to the recordings done in Phase 2. 

Then we render that to the GS screen.

# Rendering

## Video

All coordinates of the monsters, PacMan, motion etc are calculated using original-game-pixels, then scaled to IIgs coordinates. So the timing of movement is identical to original.

The sprites are all compiled, so instead of trying to copy pixel data, it’s just a 816 subroutine that writes a sprite to RAM

The graphics scaling is 6/8, which if I did my math right provides same aspect ratio as the original game. But it does mean I can write whole bytes and not mess with 4-bit updates which would be S L O W.

## Audio

The audio in PacMan/Ms PacMan is a wavetable based, though each wave is relatively lores 4-bit x 32 samples. There are 8 different waves used in the game, so at startup the IIgs version converts them to 32KB of ensoniq data (4KB per wave), loads the DOC with them, then the game just triggers them at varying frequencies as needed. (edited)

## Input

There is a key mapped to each arcade PacMan input: arrows to what was joystick on the game; 1 and 2 player start buttons, insert Coin; and a Rack Test switch that skips a level.

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

