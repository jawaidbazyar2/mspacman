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
| `lift/` | **LOCKED** — phase 1 Z80 host. |
| `idiom/` | **LOCKED** — phase 2.5 idiomatic C, the reference for phase 3. Phase 3 edits the copy in `lower/`. |
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
| `lift/` | **LOCKED** — phase 1 Z80 host. Read-only |
| `idiom/` | **LOCKED** — idiomatic C game logic, no Z80 core (phase 2.5 of `docs/MsPacManLift.md`). Read-only reference. `make idiom-check` replays `corpus/c-*` clean and must keep doing so; `make idiom-cov` for coverage |
| `lower/` | Phase 3 working tree. Starts as a copy of `idiom/`; the `.c` files get entry hooks only, and each game-logic `.c` gets a Merlin32 `.s` twin. The `mspac-lower` harness (GSSquared 65816 core only) is in `lower/host/`. Gates: `make lower-check` (shadow comparison of every hooked function), `make lower-only-check` (65816 only, plus the cycle report), and `make lower-iigs-check` (the IIgs build under GSSquared). `make iigs-lower` builds the IIgs images (`iigs/lower_host.s`, `iigs/lower_io.s`, `iigs/all_lower.s`). `make iigs-lower-demo` plays it. `make iigs-lower-gsos` builds the GS/OS application `build/iigs/MSPACLOW.SYS16` on its own 800K disk, `build/iigs/MsPacLower.2mg`. With `IIGS_LOWER_GSOS_INSTALL=1` it is also copied onto `IIGS_GSOS_DISK`. See phases 3 and 4 of `docs/MsPacManLift.md` |
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
  - `py/preview_tiles_8x8.py` — native 8×8 maze/tile PPM+PNG to check rotate/flip before scale
  - `py/gen_palette.py` — arcade PROMs → SHR palette 0 + `iigs/palette_data.s` (pen roles and the stable color map: `docs/ColorMap.md`)
 - `py/gen_tile_banks.py [--list]` — arcade color RAM banks → `iigs/tile_bank_data.s` (`TileBankPens` / `TileBankRaw`) for the lowered build's per-cell tile recolor (part of `make palette`)
  - `py/gen_maze1.py` — level-1 upright 28×31 tilemap + stitched 6×6 cells
  - `py/gen_idiom_ram.py` — generated `idiom/ram.h` / `idiom/ram.c` (packed `WorkRam` overlay with offset asserts, field names for corpus diffs). `idiom/` is locked: do not run it against `idiom/` again; phase 3 points it at `lower/`
  - `py/frame_overruns.py` — list corpus frames whose record did not end in the idle spin
  - `py/scan_sound_tables.py` — decode the ROM's effect, song and cutscene sound tables (which envelope types and song commands are reachable)
  - `py/gen_lower_entries.py` — `lower/entries.txt` → `lower/entries.s`, `lower/entry_ids.s`, `lower/host/entries.h` (run by `make lower`)
  - `py/add_hooks.py FILE [--skip F1,F2]` — add `LOWER_HOOK` lines to `lower/FILE.c` (bare name, not a path) and its manifest group
  - `py/lower_diff.py` — `lower/*.c` may differ from `idiom/*.c` only by hooks (part of `make lower-check`)
  - `py/lower_cycles.py` — per-session cycle summary of `build/lower/frame_cycles.txt` (part of `make lower-only-check`)
  - `py/omf_dump.py FILE [--relocs]` — list an OMF load file's segments (kind, length, bank size, ALIGN) and relocation records
  - `py/omf_fix_align.py FILE Seg=0x10000` — set a segment's ALIGN field; Merlin32 writes 2 for `ali BANK` (part of `make iigs-lower-gsos`)
  - `py/gs2_*.py` / `py/check_frame_count.py` — Makefile/CI only (`make iigs-test`, `make iigs-demo`, `make lower-iigs-check`, `make iigs-lower-demo`). **Do not** use these (or `gs2debug` / `PYTHONPATH`) for live debugging. One exception: `py/gs2_lower_check.py --play --detach` loads the lowered build (about 90 KB, too much for MCP `write_mem`) and exits with the emulator still running. Then attach the MCP with `connect` to `/tmp/gs2-mspacman-lower.sock`. The emulator takes one debug client at a time, so `--snap` (PNG of a running emulator) works only while the MCP is not attached.

## GSSquared live debug (MCP)

The **gs2-debug** MCP server (`.cursor/mcp.json`) is the debug interface. Same protocol tools as the old Python `gs2debug` client (`read_mem`, `write_mem`, `pause`, `wait_stopped`, `bp_set`, `type_text`, …) — call them as MCP tools, do not spawn Python against `gssquared/clients/python`.

Config: `gs2-mcp --gs2-bin …/gssquared/build/GSSquared`. One emulator at a time. After `bp_set`, `step_into`, or `pause`, call `wait_stopped`. Stop the emu with `quit` (protocol QUIT), not `kill`.

### Bring-up (static inject)

Addresses: [`iigs/mem_static.s`](iigs/mem_static.s). Binaries from `make gfx maze iigs` (or `iigs-game`). Domain `MAIN`. Chunk `write_mem` at ≤16KB (`data` is hex).

1. `launch` with platform `IIgs` (or `5`). Wait ~5s for ROM boot.
2. Control-Reset (Ctrl+F12, **not** OpenApple): `key_down` scancode `224` mod `0x40`, then scancode `69` mod `0xC0`; `key_up` `69` / `0xC0`, then `224` / `0`. Wait ~2s for Applesoft.
3. `pause` + `wait_stopped`.
4. `write_mem` inject: harness `0x020000`, tiles `0x030000`, sprites `0x031200`, masks `0x032700`, odd sprites `0x033C00`, odd masks `0x035100`, maze `0x036600`, cells `0x037000`.
5. Trampoline at `0x000300`: `18 FB 5C 00 00 02` (`CLC` / `XCE` / `JML $020000`).
6. `continue_exec`, then `type_text` `"CALL 768\n"` with `delay_s` ~0.25 (GS2 drops keys if typed too fast after reset).

### Booting a GS/OS disk

Mount disk images on slot 7, drive 1, which is faster than the slot 5 3.5" drive: `launch` with `extra_args` `["-ds7d1=/abs/path/disk.2mg"]`. A GS/OS volume with no `System:Start` boots straight into the first S16 application in its root. To test `MSPACLOW.SYS16` that way, copy `IIGS_GSOS_DISK` into `build/`, swap the application in with `cp2`, and boot the copy. Do not modify the original disk.

### Peek while running

`pause` + `wait_stopped`, then `read_mem`. Useful static-host locations:

| Symbol | Address | Size |
|--------|---------|------|
| `TILEMAP` | `0x02A000` | 868 |
| `FRAME_COUNT` | `0x02A900` | 2 |
| `DEMO_FREEZE` | `0x02A904` | 1 |
| `SCORE_*` / `HISCORE_*` | `0x02A908` | 6 |
| `LIVES` / `LEVEL` | `0x02A90E` | 1+1 |
| SHR pixels | `0x012000` | 32000 |
| SHR palette | `0x019E00` | 32 |

Freeze a completed draw: poke `DEMO_FREEZE=1` at `0x02A904`, `continue_exec`, settle, `pause` again.

Makefile PNG dump (`make iigs-test`) still uses `py/gs2_render_test.py` under the hood — that is CI, not the agent debug path.

## Working conventions for agents

1. **Never modify** locked `mspac.asm`, `src/mspac.asm`, `boot1`–`boot6`, other golden ROM binaries, `lift/`, or `idiom/` unless the user explicitly requests it.
2. IIgs port code, tools, and docs go in new or agreed paths — do not overwrite locked Z80 artifacts. Prefer `docs/` for design, `py/` for helpers, and a dedicated IIgs tree for 65816 work.
3. **Save Python helpers to `py/` before running them** (see above).
4. Z80 verification (when touching unlocked Z80): assemble → mapped image → byte-compare to `boot1`–`boot6` (`make verify` / `py/verify_boots.py`).
5. For arcade behavior: **boots win for bytes**; **listing / locked source wins for comments and intent**.
6. IIgs port work is in scope; follow `docs/IIgs-Design.md`. Keep changes focused on the asked task.
7. Live GSSquared debugging uses the **gs2-debug MCP** tools. Do not drive the emu via `gs2debug` / `PYTHONPATH=…/clients/python` from agent sessions.
8. Do not commit unless asked. Do not treat `sjasmplus/` third-party tree as something to casually edit.

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
  .cursor/mcp.json    ← gs2-debug MCP (live GSSquared debug)
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
