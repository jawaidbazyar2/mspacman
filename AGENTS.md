# AGENTS.md — Ms. Pac-Man → Apple IIgs

Guidance for AI agents working in this repository.

## Project goal

Port arcade Ms. Pac-Man to the **Apple IIgs**.

Near-term milestone: establish a trustworthy Z80 source pipeline that can be reassembled into **byte-identical** known-good ROMs, then evolve that codebase toward an IIgs target (65816 / IIgs hardware, graphics, sound, input).

## Prime directive: assemble real Z80

**The working source must remain real Z80 instructions** (`ld`, `jp`, `call`, `djnz`, …), not an ASCII hex dump of the ROMs.

1. **Assemble actual instructions.** Edit and fix mnemonics, operands, labels, and symbols until the assembled output matches `boot1`–`boot6`.
2. **`boot1`–`boot6` are the byte source of truth.** The disassembly listing can be wrong in places. When listing and boots disagree, fix the working source so the **instruction stream** emits the boot bytes — do not “solve” mismatches by replacing large regions with `db`.
3. **`db` is only for gaps (and rare last-resort bytes).** Use `db` to fill address ranges the listing does not cover, or for irreducible data tables. Replacing working instructions with `db` from the golden ROMs to force a green verify is **forbidden**.
4. **Never flatten the disassembly into a ROM dump.** Do not rewrite `src/mspac.asm` (or any assemblable source) into “label + `db` of every boot byte” with mnemonics demoted to comments. That destroys the reassembly milestone and is not progress, even if `make verify` passes.
5. **Preserve author commentary.** Scott Lawrence’s (and contributors’) comments about what the code is doing are critical for the IIgs port. Keep them on the instruction lines. Do not strip, summarize away, or orphan them when transforming source.

### Forbidden anti-pattern (do not repeat)

In a prior session, a helper rebuilt the body as golden-ROM `db` lines so verify passed. That was a **step backward**: an ASCII ROM dump with bookmarks, not a reassembled program. **Never do that again.**

## Read-only master source

**`mspac.asm` is the read-only master source.**

- Do **not** edit, reformat, “fix,” or overwrite `mspac.asm`.
- Treat it as documentation + ground-truth commentary from Scott Lawrence’s annotated disassembly of the bootleg set.
- All assemblable / regenerated source must live in **other** files (under `src/`).
- When comments, labels, or behavior are unclear, prefer reading `mspac.asm` over inventing semantics.
- If generated source disagrees with `mspac.asm`, investigate — do not “correct” `mspac.asm` to match generated output.

`mspac.asm` is a **listing-format** annotated disassembly (address + hex + mnemonic + comments), **not** assemblable as-is. The author’s own header notes it may *eventually* become reassemblable; that work must produce **new** files — never mutate the master listing in place.

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

### When listing and boots disagree

1. Prefer fixing the **instruction** (typo’d opcode, wrong immediate, bad label target, missing/extra insn).
2. If the listing documents a hack/bugfix that is *not* in `mspacmab`, keep the bootleg bytes (match boots) and leave a short comment pointing at the listing note.
3. Use a one-off `db` **only** when there is no credible instruction form (padding, raw tables with no mnemonic, or a single irreducible mismatch after investigation).

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

**`--raw` note:** SjASMPlus `--raw` concatenates emitted bytes; `ORG` alone does not insert holes. Pad the `4000–7FFF` gap explicitly (e.g. `ds #8000-$` before high ROM) so `boot5`/`boot6` land at `0x8000`/`0x9000`.

Prefer invoking the **local** binary (`sjasmplus/build/sjasmplus`), not a system-wide install, unless the user asks otherwise.

## Working copy

Editable Z80 work lives under **`src/`** (e.g. `src/mspac.asm`). That is a working copy derived from the read-only master; transform and assemble that tree, not `./mspac.asm`.

## Python helpers (`py/`)

**All Python helper scripts must be saved under `py/` before they are executed.**

- Do not run one-off `python3 <<'PY' ...` transforms as the only copy of important logic.
- Write (or update) a script in `py/` first, then run that file.
- Keep helpers reusable and documented with a short module docstring / usage line.
- Helpers must **preserve instructions and author comments**. Gap-fill helpers may insert `db` only for missing address ranges.
- Existing helpers:
  - `py/label_control_flow.py` — `j_xxxx` labels for control-flow targets
  - `py/ram_symbols.py` — curated documented RAM/I/O symbol table
  - `py/gen_ram_inc.py` — generates `src/ram.inc`
  - `py/label_abs_mem.py` — rewrites documented `(#addr)` / `ld rr,#addr` to symbols
  - `py/strip_listing_columns.py` — removes leading addr/hex columns; keeps `; @AAAA HEX` refs; writes `build/listing_index.txt`
  - `py/prepare_for_assemble.py` — comments doc header + column-0 ORG/JP patch notes for SjASMPlus
  - `py/fix_hash_symbols.py` — `#symbol` vs `#hex` normalization for SjASMPlus
  - `py/comment_junk_lines.py` / `py/comment_pseudo_ops.py` — strip non-asm junk (`END=` stops assembly!)
  - `py/finalize_assemble.py` — comment leftover junk, dots→`db` where listing has hex
  - `py/data_lines_to_db.py` — non-opcode dump lines / `.byte` → `db`, keep decoded text in comments
  - `py/z80_size.py` — estimate instruction sizes for gap tracking when listing hex is missing
  - `py/sync_pc_golden.py` — insert golden `db` **only for address gaps**; never replace instruction lines
  - `py/fix_db_vs_golden.py` — correct existing `db` data lines when listing hex ≠ boots
  - `py/fix_mangled_prefixes.py` — comment `--HHHH` / `...` overlay artifacts (do not promote to opcodes)
  - `py/fix_boot_mismatches.py` — targeted instruction/stub fixes where listing ≠ boots
  - `py/verify_boots.py` — compare `build/mspac.bin` slices to `boot1`–`boot6`

## Working conventions for agents

1. **Never modify** `mspac.asm`, `boot1`–`boot6`, or other golden ROM binaries unless the user explicitly requests it.
2. New assemblable source, tools, Makefiles, and IIgs port code go in new paths — do not overwrite master artifacts. Prefer `src/` for asm work and `py/` for Python helpers.
3. **Save Python helpers to `py/` before running them** (see above).
4. Reassembly verification: assemble → mapped image → byte-compare to `boot1`–`boot6` (`make verify` / `py/verify_boots.py`).
5. Listing hex is a useful cross-check but incomplete / has typos. **Boots win for bytes**; **listing wins for comments and intent**. Resolve conflicts by fixing instructions, not by dumping ROMs into `db`.
6. Keep changes focused; do not expand into IIgs port work until the Z80 rebuild pipeline is solid, unless the user asks to move on.
7. Do not commit unless asked. Do not treat `sjasmplus/` third-party tree as something to casually edit.

## Useful layout

```
mspacman/
  AGENTS.md           ← this file
  Rom.Files.md        ← hardware / ROM map notes
  mspac.asm           ← READ-ONLY master disassembly listing
  src/mspac.asm       ← working copy (editable) — real Z80 + comments
  src/ram.inc         ← documented RAM/I/O EQU symbols (generated)
  py/                 ← Python helpers (save here before running)
  Makefile
  boot1 … boot6       ← golden mspacmab CPU ROMs (byte truth)
  mspacmab.zip
  mspacman-orig/      ← original mspacman ROM set (reference)
  sjasmplus/          ← vendored assembler + build/
```

## Out of scope until asked

- Editing `mspac.asm` “to make it assemble”
- Targeting encrypted `mspacman` `u5`/`u6`/`u7` as the build output
- Installing sjasmplus system-wide
- Broad IIgs scaffolding before ROM-identical Z80 rebuild works
- Flattening source into a golden-ROM `db` image to force verify
