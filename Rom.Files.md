# Ms. Pac-Man ROM Memory Map

## How the hardware is put together

Arcade Pac-Man is one big printed circuit board (the **main board** / main PCB). It has:

- a **Z80 CPU** (the processor that runs the game)
- **program ROMs** in sockets labeled **6E, 6F, 6H, 6J** — these hold executable code
- **graphics ROMs** in sockets labeled **5E and 5F** — these hold tile/sprite pixel data (mazes, characters, fruits). The video hardware reads them; the CPU does not execute them as program code
- RAM, sound, video, and I/O circuitry for the cabinet

Socket names like `6E` mean “column 6, row E” on the board silkscreen. That is why MAME ROM files are often named `pacman.6e`, `5e`, etc.

### What Ms. Pac-Man added

Ms. Pac-Man was originally a **conversion kit** for an existing Pac-Man cabinet, not a wholly new game board. General Computer Corporation (GCC) / Midway shipped:

1. An **auxiliary board** (daughterboard) — a small PCB with a ribbon cable that plugs into the main board’s **Z80 CPU socket** (the CPU chip moves onto the aux board).
2. Replacement **graphics ROMs** for main-board sockets **5E and 5F** (new mazes, Ms. Pac sprite, etc.).

So in a real machine you still have the Pac-Man main board, plus a piggyback aux board doing the “Ms. Pac-Man” part of the software.

```
                    ┌─────────────────────────┐
                    │   Aux board (GCC)       │
                    │   Z80 + U5, U6, U7 ROMs │
                    │   + decode/patch logic  │
                    └───────────┬─────────────┘
                                │ ribbon cable
                                ▼
┌───────────────────────────────────────────────┐
│  Pac-Man main board                           │
│  program ROMs 6E–6J  │  graphics ROMs 5E, 5F  │
│  video, sound, I/O, RAM                       │
└───────────────────────────────────────────────┘
```

### What the aux board actually does

On stock Pac-Man, the four program ROMs fill CPU addresses `0x0000`–`0x3FFF`. Those same bytes are also mirrored at `0x8000`–`0xBFFF` (the original hardware ignored address bit A15).

The aux board sits between the CPU and the main board and **chooses which ROMs answer** for a given address:

- Much of Pac-Man’s original code in `6E`–`6J` still runs.
- For certain addresses, the aux board **disables** the main-board program ROMs and **enables** its own chips (`U5`, `U6`, `U7`) instead — Ms. Pac-Man code, new mazes/logic, cutscenes, etc.
- It also installs small **8-byte patches** inside the low Pac-Man ROM range (`0x0000`–`0x2FFF`). Those patches usually jump into the new code living at `0x8000+`.
- Decode can be turned on/off via special “trap” addresses (copy-protection). With decode off, the machine behaves like Pac-Man.

In short: **main board = Pac-Man base platform; aux board = Ms. Pac-Man software overlay + protection.**

### Why `5e` is not the same as `u5`

| Name | Where it lives | What it is |
|------|----------------|------------|
| `5e` / `mspacman.5e` | Main board socket **5E** | Graphics data (tiles) |
| `5f` / `mspacman.5f` | Main board socket **5F** | Graphics data (sprites) |
| `u5`, `u6`, `u7` | Aux board chips **U5**, **U6**, **U7** | Program code the Z80 runs |

They share a similar-looking label only by coincidence of board labeling conventions. They do **not** share the same memory role or address space. Older dumps sometimes called aux program images `boot5`/`boot6`, which made the mix-up with `5e`/`5f` even easier.

---

## Main Program ROMs (Row 6 sockets / base set)

On the main board. In MAME these are often the shared Pac-Man images (`pacman.6e`, …); some sets also use `mspacman.6e`-style names.

| File | Alias | Address range | Size |
|------|-------|---------------|------|
| `mspacman.6e` / `pacman.6e` | boot1 | `0x0000` – `0x0FFF` | 4KB |
| `mspacman.6f` / `pacman.6f` | boot2 | `0x1000` – `0x1FFF` | 4KB |
| `mspacman.6h` / `pacman.6h` | boot3 | `0x2000` – `0x2FFF` | 4KB |
| `mspacman.6j` / `pacman.6j` | boot4 | `0x3000` – `0x3FFF` | 4KB |

## Auxiliary Board Program ROMs (GCC daughterboard)

On the aux board: `U5` is a 2KB 2716; `U6` and `U7` are 4KB 2532s. MAME names them `u5`, `u6`, `u7`.

| File | Alias | Address range | Size |
|------|-------|---------------|------|
| `u5` | boot5 (older dumps) | `0x8000` – `0x87FF` | 2KB |
| `u6` | boot6 (older dumps) | `0x9000` – `0x9FFF` | 4KB |
| `u7` | — | `0xB000` – `0xBFFF` | 4KB |

There is a gap at `0xA000`–`0xAFFF`. On real hardware the aux logic also overlays `0x3000`–`0x3FFF` and maps patch bytes into low memory when decode is enabled; the table above is how MAME loads the ROM *files* into the `maincpu` region.

## Graphics ROMs (Row 5 sockets) — not CPU program space

| File | Socket | MAME region | Role |
|------|--------|-------------|------|
| `5e` / `mspacman.5e` | 5E | `gfx1` | Character / tile graphics |
| `5f` / `mspacman.5f` | 5F | `gfx1` | Sprite graphics |

These replace the Pac-Man graphics chips on the main PCB so the screen shows Ms. Pac-Man art. They are not Z80 program ROMs and are not mapped at `0x8000+` in CPU space.
