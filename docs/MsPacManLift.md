# Ms. Pac-Man Lift

Spec for getting arcade Ms. Pac-Man game logic onto the Apple IIgs by lifting through a runnable C checkpoint, with one recorded play corpus as the oracle for every later phase.

This supersedes the logic-port approach in [IIgs-Design.md](IIgs-Design.md) §6 (semantic 65816 written straight from the Z80). Display, palette, sprite, HUD, and keyboard decisions in that document stay in force. The IIgs SHR renderer is the destination for finished logic. It is not re-derived here.

Behavioral reference: locked [`src/mspac.asm`](../src/mspac.asm) and the listing [`mspac.asm`](../mspac.asm). Byte truth for the CPU image: `boot1`–`boot6` (`mspacmab`). RAM and I/O names: [`src/ram.inc`](../src/ram.inc).

---

## Why a checkpoint

The Z80 is hand-written and the control flow is tangled. Translating it straight into 65816 loses information in one step, and a wrong frame cannot be blamed on the lift or the lower.

C that actually runs is the middle checkpoint. The same play corpus is replayed against the all-Z80 machine, the C machine, and the 65816 machine. A mismatch names the phase that introduced it.

Only game logic is lifted. Video, sound, coin and stick wiring, and the interrupt plumbing are rewritten for each host. On the IIgs that rewrite already exists for the picture and the keyboard.

---

## What the machine is

The emulated board is **`mspacmab`**: decrypted Ms. Pac-Man already merged into plain `boot1`–`boot6`. There is no GCC aux-board address trap to emulate. Do not target encrypted `u5`/`u6`/`u7`.

| Image | CPU addresses | Size |
|-------|----------------|------|
| `boot1` | `$0000`–`$0FFF` | 4KB |
| `boot2` | `$1000`–`$1FFF` | 4KB |
| `boot3` | `$2000`–`$2FFF` | 4KB |
| `boot4` | `$3000`–`$3FFF` | 4KB |
| `boot5` | `$8000`–`$8FFF` | 4KB |
| `boot6` | `$9000`–`$9FFF` | 4KB |

`$4000`–`$7FFF` and `$A000`–`$FFFF` are not program ROM. Graphics ROMs `5e` and `5f` are video hardware, not CPU code.

All three phases share one logical machine image:

- `uint8_t mem[65536]` (or the 65816 equivalent of those bytes).
- Bytes the Z80 treats as bytes stay 8-bit. Ghost targets, timers, and positions wrap at 256, and some of that wrap is player-visible behavior. Widen a value only when the Z80 uses a register pair or a stored 16-bit pointer.
- 16-bit values are little-endian, matching the Z80 and the 65816.
- Named fields are packed overlays on `mem[]` at the `ram.inc` addresses (`red_x` at `$4D01` is that byte, not a copy).

---

## Phases

| Phase | Machine | Done when |
|-------|---------|-----------|
| 1 | Vendored Z80 core + arcade hardware | A playable build records a deterministic per-frame corpus, and bazyar has played the coverage set |
| 2 | C, one Z80 routine at a time | Every lifted routine is C, and replay of the phase 1 corpus matches per frame |
| 3 | 65816, one C routine at a time | Every lifted routine is 65816, and replay of the same corpus matches per frame |

Phase 1 data is the only acceptance oracle. Later phases do not invent a second corpus.

---

## Phase 1 — Z80 and hardware, with per-frame checkpoints

A host program runs the `mspacmab` image on a vendored Z80 core and a model of the hardware the game actually touches.

### CPU

The CPU is the existing [Z80 library](https://github.com/redcode/Z80) (Manuel Sainz de Baranda y Goñi, LGPL-3.0-or-later), vendored and built with `Z80_WITH_EXECUTE`. It emulates documented and undocumented behavior, including `DAA` and the flag results a later lift has to match. This project emulates the board around that core.

The host supplies the callbacks: opcode fetch, memory read, memory write, port in, port out. Those callbacks are the hardware model below. The library keeps the programmer's model in one struct; a shadow snapshot is a copy of that struct plus `mem[]`.

MAME stays an outside check on RAM images. Call interception for phase 2 lives in this process, on the fetch callback, where a lifted PC can be seen before the instruction runs.

Intercept a lifted address by PC, then return to the host loop. Leave the library trap opcode alone (`Z80_HOOK`, `0x64`, `ld h,h`). That byte is a real instruction and may occur in the ROM.

The core is stepped only from the host loop. A C routine that still needs Z80 code returns to that loop with a sentinel PC; the loop runs the core until PC and SP say the callee returned. `z80_execute` stays at the top of that loop, not inside a fetch or memory callback.

### Hardware surface

Model the devices the CPU reads and writes. Take addresses from [`src/ram.inc`](../src/ram.inc) and the MAME `mspacmab` driver when those two disagree; do not invent a third map.

| Region | Role |
|--------|------|
| `$4000`–`$43FF` | Tile video RAM |
| `$4400`–`$47FF` | Color RAM |
| `$4C00`–`$4FEF` | Work RAM: sprites-in-waiting, actors, timers, task lists, sound state, scores |
| `$4FF0`–`$4FFF` | Hardware sprite RAM |
| `$5000` | `IN0` — stick, rack test, coins, service |
| `$5001`–`$5007` | IRQ enable, sound enable, flip, lamps, coin lockout, coin counter |
| `$5040` | `IN1` — second stick, service, start, cocktail |
| `$5045`–`$505F` | Namco WSG voice registers |
| `$5060`–`$506F` | Sprite position ports |
| `$5080` | `DSW1` |
| `$50C0` | Watchdog kick |

The watchdog must be honored or the game resets itself. DIP switches are fixed for a recording and stored in the corpus header.

VBLANK is the clock: interrupt mode 1, `RST 38` at `$0038`, about 60.6 Hz, as the bootleg does (`$0038` → `$1F9B` → `$008D`). The main loop and the ISR keep their original shape. "Wait for the next frame" stays a wait. Do not flatten the frame into a single function during phase 1.

### Host presentation (SDL3)

Phases 1 and 2 present the machine through SDL3. Phase 3 does not: the IIgs build keeps the SHR renderer and the keyboard latch in [IIgs-Design.md](IIgs-Design.md).

This Mac has SDL 3.1.9 under `/usr/local` (`SDL3/SDL.h`, `libSDL3`). Link that.

**Input.** The stick is the numeric keypad, read level-sensitive (`SDL_GetKeyboardState` on the keypad scancodes) and written active-low into `IN0`, the same bit order as `STICK_IN0` in [`iigs/input_adapt.s`](../iigs/input_adapt.s):

| Key | Scancode | `IN0` bit cleared |
|-----|----------|-------------------|
| 8 | `SDL_SCANCODE_KP_8` | bit 0, up |
| 4 | `SDL_SCANCODE_KP_4` | bit 1, left |
| 6 | `SDL_SCANCODE_KP_6` | bit 2, right |
| 2 | `SDL_SCANCODE_KP_2` | bit 3, down |

A held key leaves its bit clear; a released key sets it. Two held keys clear two bits. The corpus still records the byte the CPU got back from the port read, not the SDL event.

Coin and 1-player start, which the play corpus has to include, are keypad 0 and keypad Enter, wired to the coin and start bits on `IN0` / `IN1`.

**Video.** Each emulated frame, build the 224×288 cabinet picture from video RAM, color RAM, sprite RAM, sprite positions, `5e`/`5f`, and the color PROMs. Upload it to an SDL texture and present with nearest-neighbor integer scaling. While a session is being recorded, present once per frame and pace the loop to the arcade VBLANK (about 60.6 Hz). Unthrottled replay may skip presentation.

**Audio.** Open an SDL3 playback stream and mix the three Namco WSG voices from the voice registers and the waveform PROM. That playback is for the person playing. The oracle stays the register and RAM hashes, not the samples.

### Checkpoint

Capture once per frame, at a fixed point: the CPU has finished that frame's VBLANK work and is waiting for the next interrupt.

Each frame records:

| Field | Contents |
|-------|----------|
| Frame index | Monotonic from reset |
| Input | The byte returned by each `IN0` / `IN1` read, in read order. Record what the program observed, not the host key event |
| Coins and starts | Frame-indexed edges, if they are not already fully described by those port reads |
| Hashes | Separate digests of work RAM (`$4C00`–`$4FEF`), video RAM, color RAM, sprite RAM, and sprite position ports |
| Ring buffer | Full images of those regions for the last few hundred frames, so a mismatch can be inspected |

The stored corpus is the hash chain plus the input trace plus the header (reset RAM image, DIP settings, interrupt period). Full 64K dumps of every frame are not the corpus. A ten-minute session of raw RAM is gigabytes, and the hash chain is what replay compares.

Regenerating a session means playing it again by hand. Get the capture format right before a long play.

### Determinism gate

Before any session is trusted:

1. Pin reset RAM to a recorded image (not "whatever was in the array").
2. Pin DIP switches, interrupt period, and the order of port reads.
3. Replay the same input trace twice on the all-Z80 build.
4. Require identical hash chains.

If two all-Z80 runs diverge, the corpus cannot be an oracle. Find the unpinned input (an unread timer, an unlatched coin, a watchdog edge) and pin it.

### Play that has to be in the corpus

bazyar plays in real time at the arcade frame rate. Attract mode is included by letting it run; it is deterministic and exercises AI without input.

The corpus has to leave the happy path. One careful hour of survival mostly records the routes a decent player takes. Deliberately include:

- Attract mode for several full cycles, at the head of a trace
- Coin, start, and a full life of ordinary play
- Death in the ghost-house doorway and death in a tunnel
- All four ghosts eaten on one energizer
- An energizer expiring while ghosts are still blue
- Fruit arriving and leaving uneaten, and fruit eaten
- The extra life at 10,000 points
- Cornering
- Each intermission
- Enough later levels that the speed and timing tables change

Several sessions are fine. Each session is one trace with its own header. Replay never splices them.

### Phase 1 exit

- The game is playable on the host.
- Two replays of a trace produce one hash chain.
- The coverage list above exists as saved traces.
- A short trace also matches MAME's work-RAM image at end of frame, as a sanity check that the core's callbacks and the hardware map are the real board.

---

## Phase 2 — Z80 to C, one routine at a time

Replace Z80 subroutines with C functions until the logic is all C. The SDL3 window, keypad, and WSG playback stay as in phase 1. The phase 1 traces are replayed unthrottled, with no frame-rate cap. The first mismatched frame is the bug. Everything after it is fallout.

### How a routine is lifted

A `CALL` with one entry and a `RET` is a C function. `DJNZ` is a loop. A conditional branch is `if` / `else`. A jump table or `JP (HL)` is a `switch` or a function-pointer table. `JP` used as a tail call is a call plus return. A routine that falls into the next one is two functions, the first ending in a call to the second.

`goto` is for a branch into the middle of a loop body, and the comment says what the Z80 did. Do not emit a `while (1) switch (pc)` interpreter.

Write the body the way the Z80 wrote it:

- Do not merge two routines that look alike. A one-byte difference is usually load-bearing.
- Do not reorder stores the interrupt or the video hardware can observe.
- Do not derive a constant. If the table says `0x1B`, the C says `0x1B`.
- Keep the Z80 label as the function name (`sub_8e3f`, `j_2966`) until traces confirm a better one.
- Do not delete stores that look redundant.

Types: `uint8_t` for bytes, `uint16_t` for pairs and pointers, `int8_t` for a value the code actually treats as signed. No `int`, no bare `char`. C promotes `uint8_t` arithmetic to `int`, so a comparison or a shift on a sum can keep bits the Z80 never had. Assign back through a `uint8_t` when the Z80 would have wrapped, and build with `-Wconversion`. Compile overlays with `-fno-strict-aliasing`.

Scores are BCD. The lift needs a `DAA` helper or an explicit BCD add. That shows up at 10,000.

### Contract table

Every routine, before it is lifted, gets a row:

| Column | Meaning |
|--------|---------|
| Entry | Registers and the RAM fields it reads |
| Exit | Registers and RAM it writes |
| Clobbers | Registers destroyed |
| Flags live-out | Which of Z, C, S, P/V the caller still tests |
| Interrupt | Whether the original could be interrupted mid-routine |
| Stack | Normal frame, or stack surgery |

Stack surgery (popping the return address, pushing a computed address and `RET`ing to it) has no mechanical C equivalent. Those routines use an explicit return code the caller checks, or `setjmp` / `longjmp` in the worst case. They are listed, not papered over. They are also the routines phase 3 cannot lower blindly: `JSL` / `RTL` will not reproduce the trick.

### Mixed execution

Until a routine is flipped to C-only, the process is a mix. Emulated Z80 and C call each other. Both see the same `mem[]`, the same ports, and the same emulated stack.

**Z80 calls C.** On a PC that has been lifted, snapshot the machine, run the Z80 routine, save the result, restore the snapshot, run the C, compare. Then commit the Z80 result and continue. The game stays on the phase 1 trajectory no matter how wrong the C was, and one session reports every lifted routine that diverged. Recorded per-call traces are the wrong tool: a routine may read a byte the trace never captured. The snapshot is the whole machine, so the input cannot be missed.

Compare registers, `mem[]` deltas, and flags. Flags first: a `CALL` followed by `JR NZ` is normal. Shadow mode says which flags ever differ. The contract row records which of those the caller actually tests. When a routine has survived extended play in shadow mode, flip it to C-only.

**C calls Z80.** Push a sentinel return address that cannot be a real PC, set PC, and return to the host loop. The loop runs the Z80 core until SP is back and PC is the sentinel. The same loop already handles the other direction, so a Z80 callee may itself hit a lifted PC, run C, and that C may ask for Z80 again, without nesting `z80_execute`.

Locals that are pure scratch may live on the host stack. Anything the Z80 stored at a fixed address stays at that address.

Lift leaves first. A leaf has no callee to marshal, so the boundary is only registers and memory. Hardware-facing writers and anything still shaped like a task-list trampoline go last.

### What shadow mode does not replace

Shadow mode keeps the Z80 answer, so it will not catch a routine that is right in isolation but moves the interrupt or the watchdog relative to the rest of the frame. Acceptance is still a full replay of each phase 1 trace, C-only, comparing the per-frame hash chain. One bug per replay: stop at the first mismatched frame, fix it, run again.

Lifted code costs no Z80 cycles, so the interrupt can land in a different place. The original main loop is VBLANK-gated, and finishing early then waiting is usually harmless. If a replay shows frame drift, charge the lifted routine an approximate cycle count. Default is to leave cycles uncharged until a trace says otherwise.

Default is also that a lifted C routine runs with the interrupt masked, matching most of these routines. The contract column flags the exceptions: long routines the ISR was allowed to cut, and any byte the ISR writes while the main line is in that routine. Lift the ISR path after the routines it calls are stable.

### Phase 2 exit

- Every routine in the logic set is C-only. The Z80 core is no longer on the call path.
- Every phase 1 trace replays to the same hash chain.
- The contract table covers the set, including the stack-surgery list.

---

## Phase 3 — C to 65816, one routine at a time

Lower the C functions to 65816 until the logic is all 65816. The oracle does not change. Replay the phase 1 traces and compare the same per-frame hashes.

### Mixed execution, again

The workstation host stays the test harness. A routine under conversion runs as 65816; its callees and callers stay C until they are lowered. Both use the same `mem[]`.

At each call, snapshot, run the C function, save the result, restore, run the 65816, compare, commit the C result. The trajectory stays on the phase 1 path, and one replay lists every lowered routine that diverged. Acceptance, after the routine is flipped to 65816-only, is a full unthrottled replay of the phase 1 hash chain.

The 65816 execution vehicle for this phase is in-process on the workstation (a small 65816 core, or an equivalent that runs the assembled bytes against `mem[]`). Per-routine comparison does not depend on GSSquared frame timing. GSSquared is for the integrated IIgs build, where the existing SHR renderer draws and the lowered logic is what advances `$4D00`–`$4E3F` and the rest of the work RAM.

### Lowering rules

The C function and its contract row are the source. The 65816 routine must produce the same `mem[]` writes and the same explicit results. Match 8-bit wrap. Match BCD. Keep little-endian 16-bit stores so a work-RAM image from the IIgs is comparable byte for byte with phase 1.

Do not restructure a function in the same pass that lowers it. A mismatch would have two causes. Ugly 65816 that matches the hashes is the input to a later cleanup.

The stack-surgery list from phase 2 is lowered by hand. `JSL` / `RTL` get a normal frame. The return-code convention from the C side is the one that carries over.

Rendering, palette, sprite blit, HUD chrome, and keyboard latch stay the IIgs code described in [IIgs-Design.md](IIgs-Design.md). Phase 3 does not port video RAM into SHR. It ports the logic that decides what the next frame's actors, dots, scores, and mode are. The existing game-build logic in `iigs/*.s` is the prototype this phase replaces once the traces match.

### Phase 3 exit

- Every lifted routine is 65816, running in the integrated IIgs build.
- Every phase 1 trace, applied to that build's input latch, produces the same work-RAM, video-RAM, color-RAM, and sprite-state hashes.
- Attract, death, energizer, fruit, 10,000-point life, intermissions, and later-level speed changes all pass on those traces.

---

## Corpus format

One directory per session under a single tree (location to be chosen when phase 1 is built). A session contains:

| File | Role |
|------|------|
| `header` | Reset RAM image, DIP byte, interrupt period, capture-point description, emulator build id |
| `inputs` | Frame-indexed `IN0` / `IN1` read values, plus coin and start edges |
| `hashes` | Per-frame digests, one row per frame, regions in a fixed column order |
| `ring` | Optional tail of full region images for the last N frames |

Replay is a pure function of `header` + `inputs`. Host key timing is not an input.

Hash columns, fixed order: work RAM, video RAM, color RAM, sprite RAM, sprite positions. A mismatch names the region before anyone opens a dump.

---

## Out of scope for this spec

- Writing a Z80 CPU emulator. The CPU is the vendored [Z80 library](https://github.com/redcode/Z80); this project emulates the board
- Editing locked `mspac.asm`, `src/mspac.asm`, or `boot1`–`boot6`
- Re-implementing the SHR renderer, palette, or sprite blit
- Sample-exact WSG audio as an acceptance test. SDL3 plays the voices; the corpus hashes the registers
- Encrypted original-hardware `mspacman` (`u5`/`u6`/`u7` and aux-board traps)
