# AGENTS.md — Ms. Pac-Man → Apple IIgs

Guidance for AI agents working in this repository.

## Project goal

Port arcade Ms. Pac-Man to the **Apple IIgs**.

Near-term milestone: establish a trustworthy Z80 source pipeline that can be reassembled into **byte-identical** known-good ROMs, then evolve that codebase toward an IIgs target (65816 / IIgs hardware, graphics, sound, input).

## Read-only master source

**`mspac.asm` is the read-only master source.**

- Do **not** edit, reformat, “fix,” or overwrite `mspac.asm`.
- Treat it as documentation + ground-truth commentary from Scott Lawrence’s annotated disassembly of the bootleg set.
- All assemblable / regenerated source must live in **other** files (e.g. under a future `src/` tree).
- When comments, labels, or behavior are unclear, prefer reading `mspac.asm` over inventing semantics.
- If generated source disagrees with `mspac.asm`, investigate — do not “correct” `mspac.asm` to match generated output.

`mspac.asm` is a **listing-format** annotated disassembly (address + hex + mnemonic + comments), **not** assemblable as-is. The author’s own header notes it may *eventually* become reassemblable; that work, if done, must produce **new** files — never mutate the master listing in place.

## Golden ROMs (build truth)

Reassembly success is measured against MAME **`mspacmab`** (Ms. Pac-Man bootleg, set 1):

| File   | Load address     | Size | CRC32      |
|--------|------------------|------|------------|
| `boot1` | `0x0000`–`0x0FFF` | 4KB | `d16b31b7` |
| `boot2` | `0x1000`–`0x1FFF` | 4KB | `0d32de5e` |
| `boot3` | `0x2000`–`0x2FFF` | 4KB | `1821ee0b` |
| `boot4` | `0x3000`–`0x3FFF` | 4KB | `165a9dd8` |
| `boot5` | `0x8000`–`0x8FFF` | 4KB | `8c3e6de6` |
| `boot6` | `0x9000`–`0x9FFF` | 4KB | `368cb165` |

These files live at the repo root. `mspacmab.zip` is the archive they came from.

**Do not** use the original Midway/GCC encrypted set (`u5`/`u6`/`u7`) as the reassembly golden target. That set is kept for reference under `mspacman-orig/` if present.

### `mspacman` vs `mspacmab` (short)

- **`mspacman`**: original hardware — Pac-Man main board + GCC aux daughterboard; encrypted `u5`/`u6`/`u7`; runtime patch/decode.
- **`mspacmab`**: bootleg — decrypted Ms. Pac code permanently merged into plain `boot1`–`boot6`; no aux board. This matches `mspac.asm` and is the right base for an IIgs port.

Hardware / ROM map notes: `Rom.Files.md`.

## Assembler: SjASMPlus

This project uses **[SjASMPlus](https://github.com/z00m128/sjasmplus)** (vendored under `sjasmplus/`).

| Item | Value |
|------|--------|
| Version built here | **v1.23.1** |
| Binary | `sjasmplus/build/sjasmplus` |
| Platform | macOS, arm64 |

### Build (macOS / CMake)

```bash
cd sjasmplus
cmake -DCMAKE_BUILD_TYPE=Release -S . -B build
cmake --build build
./build/sjasmplus --version
```

Clone originally used recursive submodules (`git clone --recursive`). Lua is bundled; `ENABLE_LUA` defaults on. Apple Clang may warn that `-s` is obsolete; that is harmless.

### Why SjASMPlus

- Flexible Z80 syntax (closer to the Maxam-like `#` immediates in `mspac.asm` than strict `0x`-only assemblers).
- Practical multi-output / `ORG` workflow for splitting into `boot1`–`boot6`.
- Actively maintained; suitable for arcade ROM rebuild workflows.

Prefer invoking the **local** binary (`sjasmplus/build/sjasmplus`), not a system-wide install, unless the user asks otherwise.

## Working conventions for agents

1. **Never modify** `mspac.asm`, `boot1`–`boot6`, or other golden ROM binaries unless the user explicitly requests it.
2. New assemblable source, tools, Makefiles, and IIgs port code go in new paths — do not overwrite master artifacts.
3. Reassembly verification: assemble → emit six 4KB images (or one map that is split) → CRC/byte-compare to `boot1`–`boot6`.
4. Listing hex in `mspac.asm` is a useful cross-check but is incomplete / has known mismatches (hacks, bugfix notes, typos). **Golden ROMs win** for byte identity; `mspac.asm` wins for intent and documentation.
5. Keep changes focused; do not expand into IIgs port work until the Z80 rebuild pipeline is solid, unless the user asks to move on.
6. Do not commit unless asked. Do not treat `sjasmplus/` third-party tree as something to casually edit.

## Useful layout

```
mspacman/
  AGENTS.md           ← this file
  Rom.Files.md        ← hardware / ROM map notes
  mspac.asm           ← READ-ONLY master disassembly listing
  boot1 … boot6       ← golden mspacmab CPU ROMs
  mspacmab.zip
  mspacman-orig/      ← original mspacman ROM set (reference)
  sjasmplus/          ← vendored assembler + build/
```

## Out of scope until asked

- Editing `mspac.asm` “to make it assemble”
- Targeting encrypted `mspacman` `u5`/`u6`/`u7` as the build output
- Installing sjasmplus system-wide
- Broad IIgs scaffolding before ROM-identical Z80 rebuild works
