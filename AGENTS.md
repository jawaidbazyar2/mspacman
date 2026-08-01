# AGENTS.md — Ms. Pac-Man → Apple IIgs

Guidance for AI agents working in this repository.

## Project goal

Port arcade Ms. Pac-Man to the **Apple IIgs**.

**Z80 reassembly milestone: complete.** Working source under `src/` assembles with SjASMPlus to a mapped image that byte-matches golden `boot1`–`boot6` (`make verify`). Near-term work is the **IIgs port** (65816 / SHR graphics, sound, input) guided by `docs/IIgs-Design.md`, using the locked Z80 listing and source as behavioral reference.

## LOCKED: `mspac.asm` and Z80 rebuild artifacts

**Do not edit these unless the user explicitly requests it:**

| Path | Role |
|------|------|
| `mspac.asm` | **LOCKED** — read-only master annotated disassembly (Scott Lawrence listing). Documentation + commentary ground truth. |
| `src/mspac.asm` | **LOCKED** — verified assemblable Z80 working source (real instructions + author comments). |
| `boot1` … `boot6` | **LOCKED** — golden `mspacmab` CPU ROMs (byte truth). |
| Other golden ROM binaries | **LOCKED** unless explicitly requested. |

- Do **not** reformat, “fix,” regenerate, or overwrite locked `mspac.asm` / `src/mspac.asm` as part of casual IIgs work.
- When comments, labels, or behavior are unclear, **read** the locked sources — do not invent semantics or “correct” them to match new code.
- If IIgs work needs assemblable Z80 changes, **ask first**; do not silently unlock or re-pipeline the Z80 tree.
- `mspac.asm` (repo root) is a **listing-format** annotated disassembly (address + hex + mnemonic + comments), not assemblable as-is. The assemblable tree is `src/`; both are locked.

## Prime directive: assemble real Z80 (maintenance)

If the user explicitly unlocks Z80 work, the working source must remain **real Z80 instructions** (`ld`, `jp`, `call`, `djnz`, …), not an ASCII hex dump of the ROMs.

1. **Assemble actual instructions.** Edit and fix mnemonics, operands, labels, and symbols until the assembled output matches `boot1`–`boot6`.
2. **`boot1`–`boot6` are the byte source of truth.** The disassembly listing can be wrong in places. When listing and boots disagree, fix the working source so the **instruction stream** emits the boot bytes — do not “solve” mismatches by replacing large regions with `db`.
3. **`db` is only for gaps (and rare last-resort bytes).** Use `db` to fill address ranges the listing does not cover, or for irreducible data tables. Replacing working instructions with `db` from the golden ROMs to force a green verify is **forbidden**.
4. **Never flatten the disassembly into a ROM dump.** Do not rewrite `src/mspac.asm` (or any assemblable source) into “label + `db` of every boot byte” with mnemonics demoted to comments. That destroys the reassembly milestone and is not progress, even if `make verify` passes.
5. **Preserve author commentary.** Scott Lawrence’s (and contributors’) comments about what the code is doing are critical for the IIgs port. Keep them on the instruction lines. Do not strip, summarize away, or orphan them when transforming source.

### Forbidden anti-pattern (do not repeat)

In a prior session, a helper rebuilt the body as golden-ROM `db` lines so verify passed. That was a **step backward**: an ASCII ROM dump with bookmarks, not a reassembled program. **Never do that again.**

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

Hardware / ROM map notes: `Rom.Files.md`. Design notes for the IIgs target: `docs/IIgs-Design.md`.

### When listing and boots disagree (Z80 maintenance only)

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

## Working tree (post-rebuild)

| Path | Status |
|------|--------|
| `mspac.asm`, `src/mspac.asm` | **LOCKED** — reference only for IIgs work |
| `src/ram.inc` | Generated RAM/I/O symbols; treat as Z80-side support (avoid drive-by edits) |
| `docs/IIgs-Design.md` | IIgs display / render / input decisions |
| New IIgs code | New paths (e.g. under `iigs/` or as agreed) — do not overwrite locked Z80 artifacts |

## Python helpers (`py/`)

**All Python helper scripts must be saved under `py/` before they are executed.**

- Do not run one-off `python3 <<'PY' ...` transforms as the only copy of important logic.
- Write (or update) a script in `py/` first, then run that file.
- Keep helpers reusable and documented with a short module docstring / usage line.
- Helpers that touch Z80 source must **preserve instructions and author comments**. Gap-fill helpers may insert `db` only for missing address ranges. Do not run Z80 transform pipelines against locked sources unless the user explicitly unlocks that work.
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
  - `py/gen_shr_gfx.py` — scale `5e`/`5f` → IIgs 6×6 tiles / 14×12 sprites (+ optional PPM previews)

## Working conventions for agents

1. **Never modify** locked `mspac.asm`, `src/mspac.asm`, `boot1`–`boot6`, or other golden ROM binaries unless the user explicitly requests it.
2. IIgs port code, tools, and docs go in new or agreed paths — do not overwrite locked Z80 artifacts. Prefer `docs/` for design, `py/` for helpers, and a dedicated IIgs tree for 65816 work.
3. **Save Python helpers to `py/` before running them** (see above).
4. Z80 verification (when touching unlocked Z80): assemble → mapped image → byte-compare to `boot1`–`boot6` (`make verify` / `py/verify_boots.py`).
5. For arcade behavior: **boots win for bytes**; **listing / locked source wins for comments and intent**.
6. IIgs port work is in scope; follow `docs/IIgs-Design.md`. Keep changes focused on the asked task.
7. Do not commit unless asked. Do not treat `sjasmplus/` third-party tree as something to casually edit.

## Useful layout

```
mspacman/
  AGENTS.md           ← this file
  Rom.Files.md        ← hardware / ROM map notes
  docs/IIgs-Design.md ← IIgs port design decisions
  mspac.asm           ← LOCKED master disassembly listing
  src/mspac.asm       ← LOCKED assemblable Z80 (verify-clean)
  src/ram.inc         ← documented RAM/I/O EQU symbols (generated)
  py/                 ← Python helpers (save here before running)
  Makefile
  boot1 … boot6       ← golden mspacmab CPU ROMs (byte truth)
  mspacmab.zip
  mspacman-orig/      ← original mspacman ROM set (reference)
  sjasmplus/          ← vendored assembler + build/
```

## Out of scope until asked

- Editing locked `mspac.asm` / `src/mspac.asm` (including “to make it assemble” or re-running the transform pipeline)
- Targeting encrypted `mspacman` `u5`/`u6`/`u7` as the build output
- Installing sjasmplus system-wide
- Flattening source into a golden-ROM `db` image to force verify
