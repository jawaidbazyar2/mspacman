# Ms. Pac-Man → Apple IIgs

Port arcade Ms. Pac-Man to the **Apple IIgs**.

The near-term milestone is a trustworthy Z80 source pipeline: real assemblable instructions that rebuild **byte-identical** known-good ROMs (`boot1`–`boot6` from MAME’s `mspacmab` set). Once that foundation is solid, the codebase can evolve toward a 65816 / IIgs target (graphics, sound, input).

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

## Disclaimer

Ms. Pac-Man and Pac-Man are trademarks of their respective copyright holders (Namco, Bally/Midway, GCC, and successors). Scott Lawrence’s disassembly and this derivative work are educational / research projects and are not sanctioned by the rights holders.
