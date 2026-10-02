# Ms. Pac-Man Z80 rebuild (mspacmab / boot1–boot6)
#
# Working source: src/mspac.asm
# Read-only master: ./mspac.asm (do not edit)
#
# Assembler: vendored SjASMPlus

SJASMPLUS ?= sjasmplus/build/sjasmplus

SRC_DIR   := src
BUILD_DIR := build

ASM       := $(SRC_DIR)/mspac.asm
BIN       := $(BUILD_DIR)/mspac.bin
LST       := $(BUILD_DIR)/mspac.lst
ERR       := $(BUILD_DIR)/mspac.err

# Golden mspacmab ROMs at repo root
BOOTS     := boot1 boot2 boot3 boot4 boot5 boot6

GFX_DIR   := $(BUILD_DIR)/gfx
TILE_ROM  := mspacman/5e
SPRITE_ROM := mspacman/5f
COLOR_ROM := mspacman/82s123.7f
PALETTE_ROM := mspacman/82s126.4a

MERLIN32  ?= $(HOME)/src/Merlin32_v1.2_b2/MacOs/Merlin32
MERLIN_LIB ?= $(HOME)/src/Merlin32_v1.2_b2/Library
IIGS_DIR  := iigs
IIGS_BUILD := $(BUILD_DIR)/iigs
IIGS_BIN  := $(IIGS_BUILD)/harness.bin
IIGS_GAME_BIN := $(IIGS_BUILD)/game.bin
IIGS_GSOS_BIN := $(IIGS_BUILD)/MSPACMAN.SYS16
CP2       ?= $(HOME)/src/cp2_1.0.5_osx-x64_sc/cp2
IIGS_GSOS_DISK ?= $(HOME)/src/IIgsDisks/mspacmangs.2mg

GSSQUARED ?= $(HOME)/src/gssquared/build/GSSquared
# Python gs2debug: Makefile/CI spawn only (iigs-test / iigs-demo).
# Live debug is the gs2-debug MCP server (.cursor/mcp.json) — see AGENTS.md.
GS2_PY    := $(HOME)/src/gssquared/clients/python/src

LIFT_DIR := lift
LIFT_BIN := $(BUILD_DIR)/lift/mspac-lift
LIFT_SRCS := $(LIFT_DIR)/main.c $(LIFT_DIR)/board.c $(LIFT_DIR)/video.c \
	$(LIFT_DIR)/audio.c $(LIFT_DIR)/input.c $(LIFT_DIR)/corpus.c \
	$(LIFT_DIR)/third_party/Z80/sources/Z80.c
SDL_CFLAGS := -I/usr/local/include
SDL_LIBS := -L/usr/local/lib -lSDL3 -Wl,-rpath,/usr/local/lib

.PHONY: all clean verify sjasmplus-check gfx gfx-ppm palette maze tiles-preview \
	iigs iigs-test iigs-demo iigs-game iigs-game-test iigs-game-demo iigs-gsos \
	lift lift-check

all: $(BIN)

$(BUILD_DIR)/lift:
	mkdir -p $(BUILD_DIR)/lift

# Phase-1 Z80 host. CPU image is the assembled working source.
lift: $(LIFT_BIN)

$(LIFT_BIN): $(LIFT_SRCS) $(LIFT_DIR)/lift.h $(BIN) | $(BUILD_DIR)/lift
	cc -std=c11 -O2 -Wall -Wextra \
		-I $(LIFT_DIR)/third_party/Z80/API \
		-I $(LIFT_DIR)/third_party/Zeta/API \
		$(SDL_CFLAGS) \
		-DZ80_STATIC -DZ80_WITH_EXECUTE \
		-o $@ $(LIFT_SRCS) $(SDL_LIBS)

lift-check: $(LIFT_BIN)
	$(LIFT_BIN) --check 600

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Assemble working copy with SjASMPlus.
# --raw writes a flat binary; listing goes beside it for debugging.
$(BIN): $(ASM) $(SRC_DIR)/ram.inc $(SJASMPLUS) | $(BUILD_DIR)
	$(SJASMPLUS) \
		-i $(SRC_DIR) \
		--raw=$(BIN) \
		--lst=$(LST) \
		--fullpath \
		$(ASM) 2>$(ERR)

sjasmplus-check:
	@test -x $(SJASMPLUS) || { \
		echo "missing $(SJASMPLUS); build with:"; \
		echo "  cd sjasmplus && cmake -DCMAKE_BUILD_TYPE=Release -S . -B build && cmake --build build"; \
		exit 1; \
	}
	@$(SJASMPLUS) --version

# After a successful assemble, compare 4KB slices to golden boots.
# Map: 0000/1000/2000/3000/8000/9000 → boot1..boot6
verify: $(BIN)
	python3 py/verify_boots.py $(BIN)

# Scale arcade 5e/5f graphics to IIgs 6x6 tiles / 14x12 even sprites.
gfx: $(TILE_ROM) $(SPRITE_ROM) palette
	python3 py/gen_shr_gfx.py --tiles $(TILE_ROM) --sprites $(SPRITE_ROM) --out $(GFX_DIR)

# Same as gfx, plus PPM contact sheets under build/gfx/ppm/ for eyeballing.
gfx-ppm: $(TILE_ROM) $(SPRITE_ROM) palette
	python3 py/gen_shr_gfx.py --tiles $(TILE_ROM) --sprites $(SPRITE_ROM) --out $(GFX_DIR) --ppm

# SHR palette from 82s123.7f / 82s126.4a (maze pal #1D in slots 0–3).
palette:
	python3 py/gen_palette.py --out $(GFX_DIR) --asm $(IIGS_DIR)/palette_data.s

# Decode level-1 maze tilemap (28x31) + stitched cells (needs tiles6.bin).
maze: boot1 boot2 boot3 boot4 boot5 boot6
	python3 py/gen_maze1.py --out $(GFX_DIR)
	$(MAKE) rails

# Waypoint loop for four-ghost rail demo (Merlin rails_data.s).
.PHONY: rails
rails: $(GFX_DIR)/maze1_28x31.bin
	python3 py/gen_ghost_rails.py --maze $(GFX_DIR)/maze1_28x31.bin --out $(IIGS_DIR)/rails_data.s

# Native 8×8 maze + tile sheet (no 6×6 scale) to validate rotate/flip.
# Example: make tiles-preview COMPARE=native,cw,upright
COMPARE ?=
tiles-preview: maze
	python3 py/preview_tiles_8x8.py --orient upright \
		$(if $(COMPARE),--compare $(COMPARE),) \
		--out $(GFX_DIR)/ppm

# Shared compiled blit deps
IIGS_COMPILED := $(IIGS_DIR)/compiled_ghosts.s $(IIGS_DIR)/compiled_fruits.s \
		$(IIGS_DIR)/compiled_points.s $(IIGS_DIR)/compiled_mspac.s

# Assemble IIgs rail demo → build/iigs/harness.bin
iigs: palette rails gfx $(IIGS_COMPILED) $(IIGS_BIN)

# Assemble IIgs game-logic build → build/iigs/game.bin
iigs-game: palette gfx maze $(IIGS_COMPILED) $(IIGS_GAME_BIN)

# Relocatable GS/OS S16 → build/iigs/MSPACMAN.SYS16, then cp2 onto disk image
iigs-gsos: palette gfx maze $(IIGS_COMPILED) $(IIGS_GSOS_BIN)
	cd $(IIGS_BUILD) && $(CP2) add --overwrite --strip-paths "$(IIGS_GSOS_DISK)" MSPACMAN.SYS16
	$(CP2) set-attr "$(IIGS_GSOS_DISK)" type=0xb3,aux=0x0000 MSPACMAN.SYS16

$(IIGS_DIR)/compiled_ghosts.s: py/gen_compiled_ghosts.py \
		$(GFX_DIR)/sprites14x12.bin $(GFX_DIR)/sprites14x12.mask.bin \
		$(GFX_DIR)/sprites14x12.odd.bin $(GFX_DIR)/sprites14x12.odd.mask.bin
	python3 py/gen_compiled_ghosts.py --gfx $(GFX_DIR) -o $(IIGS_DIR)/compiled_ghosts.s

$(IIGS_DIR)/compiled_fruits.s: py/gen_compiled_fruits.py \
		$(SPRITE_ROM) $(COLOR_ROM) $(PALETTE_ROM) py/gen_shr_gfx.py py/gen_palette.py
	python3 py/gen_compiled_fruits.py --sprites $(SPRITE_ROM) -o $(IIGS_DIR)/compiled_fruits.s

$(IIGS_DIR)/compiled_points.s: py/gen_compiled_points.py \
		$(SPRITE_ROM) py/gen_shr_gfx.py
	python3 py/gen_compiled_points.py --sprites $(SPRITE_ROM) -o $(IIGS_DIR)/compiled_points.s

$(IIGS_DIR)/compiled_mspac.s: py/gen_compiled_mspac.py \
		$(SPRITE_ROM) $(COLOR_ROM) $(PALETTE_ROM) py/gen_shr_gfx.py py/gen_palette.py
	python3 py/gen_compiled_mspac.py --sprites $(SPRITE_ROM) -o $(IIGS_DIR)/compiled_mspac.s

$(IIGS_DIR)/ghost_work_blit.s: py/gen_ghost_work_blit.py
	python3 py/gen_ghost_work_blit.py -o $(IIGS_DIR)/ghost_work_blit.s

$(IIGS_BUILD):
	mkdir -p $(IIGS_BUILD)

IIGS_DEMO_SRCS := $(IIGS_DIR)/link_demo.s $(IIGS_DIR)/all_demo.s \
		$(IIGS_DIR)/mem_static.s $(IIGS_DIR)/equates.s \
		$(IIGS_DIR)/frame_body.s $(IIGS_DIR)/demo_tick.s \
		$(IIGS_DIR)/shr_body.s $(IIGS_DIR)/render_body.s \
		$(IIGS_COMPILED) \
		$(IIGS_DIR)/rails_body.s $(IIGS_DIR)/hud_body.s \
		$(IIGS_DIR)/rails_data.s $(IIGS_DIR)/palette_data.s

IIGS_GAME_SRCS := $(IIGS_DIR)/link_game.s $(IIGS_DIR)/all_game.s \
		$(IIGS_DIR)/mem_static.s $(IIGS_DIR)/equates.s \
		$(IIGS_DIR)/frame_body.s $(IIGS_DIR)/game_tick.s \
		$(IIGS_DIR)/input_adapt.s $(IIGS_DIR)/logic_data.s \
		$(IIGS_DIR)/maze_state.s $(IIGS_DIR)/ghost_ai.s \
		$(IIGS_DIR)/mspac_move.s $(IIGS_DIR)/ghost_move.s \
		$(IIGS_DIR)/collide.s $(IIGS_DIR)/fruit.s \
		$(IIGS_DIR)/leave_house.s \
		$(IIGS_DIR)/play_tick.s $(IIGS_DIR)/level_fsm.s \
		$(IIGS_DIR)/actor_publish.s $(IIGS_DIR)/game_init.s \
		$(IIGS_DIR)/shr_body.s $(IIGS_DIR)/render_body.s \
		$(IIGS_COMPILED) \
		$(IIGS_DIR)/hud_body.s $(IIGS_DIR)/palette_data.s

IIGS_GSOS_SRCS := $(IIGS_DIR)/link_gsos_game.s $(IIGS_DIR)/all_gsos_main.s \
		$(IIGS_DIR)/mem_gsos.s $(IIGS_DIR)/gsos_entry.s \
		$(IIGS_DIR)/seg_bck.s $(IIGS_DIR)/seg_assets.s $(IIGS_DIR)/seg_work.s \
		$(IIGS_DIR)/equates.s $(IIGS_DIR)/frame_body.s \
		$(IIGS_DIR)/game_tick.s $(IIGS_DIR)/input_adapt.s \
		$(IIGS_DIR)/logic_data.s $(IIGS_DIR)/maze_state.s \
		$(IIGS_DIR)/ghost_ai.s $(IIGS_DIR)/mspac_move.s \
		$(IIGS_DIR)/ghost_move.s $(IIGS_DIR)/collide.s \
		$(IIGS_DIR)/fruit.s $(IIGS_DIR)/leave_house.s \
		$(IIGS_DIR)/play_tick.s $(IIGS_DIR)/level_fsm.s \
		$(IIGS_DIR)/actor_publish.s $(IIGS_DIR)/game_init.s \
		$(IIGS_DIR)/shr_body.s $(IIGS_DIR)/render_body.s \
		$(IIGS_COMPILED) \
		$(IIGS_DIR)/hud_body.s $(IIGS_DIR)/palette_data.s

$(IIGS_BIN): $(IIGS_DEMO_SRCS) $(MERLIN32) | $(IIGS_BUILD)
	rm -f $(IIGS_DIR)/harness.bin
	cd $(IIGS_DIR) && $(MERLIN32) -V $(MERLIN_LIB) link_demo.s; \
		test -f harness.bin
	mv -f $(IIGS_DIR)/harness.bin $(IIGS_BIN)
	@mv -f $(IIGS_DIR)/_Output.txt $(IIGS_BUILD)/harness_Output.txt 2>/dev/null; true
	@rm -f $(IIGS_DIR)/_FileInformation.txt $(IIGS_DIR)/harness.bin_Output.txt \
		$(IIGS_DIR)/error_output.txt 2>/dev/null; true

$(IIGS_GAME_BIN): $(IIGS_GAME_SRCS) $(MERLIN32) | $(IIGS_BUILD)
	rm -f $(IIGS_DIR)/game.bin
	cd $(IIGS_DIR) && $(MERLIN32) -V $(MERLIN_LIB) link_game.s; \
		test -f game.bin
	mv -f $(IIGS_DIR)/game.bin $(IIGS_GAME_BIN)
	@sz=$$(wc -c < $(IIGS_GAME_BIN)); \
		if [ $$sz -ge 40960 ]; then \
			echo "error: game.bin is $$sz bytes (must be < \$$A000 work RAM)"; exit 1; \
		fi; \
		echo "game.bin $$sz bytes (work RAM @ \$$A000)"
	@mv -f $(IIGS_DIR)/_Output.txt $(IIGS_BUILD)/game_Output.txt 2>/dev/null; true
	@rm -f $(IIGS_DIR)/_FileInformation.txt $(IIGS_DIR)/game.bin_Output.txt \
		$(IIGS_DIR)/error_output.txt 2>/dev/null; true

$(IIGS_GSOS_BIN): $(IIGS_GSOS_SRCS) $(GFX_DIR)/tiles6.bin $(GFX_DIR)/maze1_cells.bin \
		$(MERLIN32) | $(IIGS_BUILD)
	rm -f $(IIGS_DIR)/MSPACMAN.SYS16
	cd $(IIGS_DIR) && $(MERLIN32) -V $(MERLIN_LIB) link_gsos_game.s; \
		test -f MSPACMAN.SYS16
	mv -f $(IIGS_DIR)/MSPACMAN.SYS16 $(IIGS_GSOS_BIN)
	@mv -f $(IIGS_DIR)/_Output.txt $(IIGS_BUILD)/gsos_Output.txt 2>/dev/null; true
	@rm -f $(IIGS_DIR)/_FileInformation.txt $(IIGS_DIR)/MSPACMAN.SYS16_Output.txt \
		$(IIGS_DIR)/MSPACMAN.SYS16_S0*_Output.txt $(IIGS_DIR)/MSPACMAN.SYS16_Symbols.txt \
		$(IIGS_DIR)/error_output.txt 2>/dev/null; true

# Spawn GSSquared, inject harness + assets, dump SHR frame PNG.
iigs-test: gfx maze iigs
	PYTHONPATH=$(GS2_PY) python3 py/gs2_render_test.py \
		--gs2 $(GSSQUARED) \
		--bin $(IIGS_BIN) \
		--gfx $(GFX_DIR) \
		--out $(IIGS_BUILD)/frame.png \
		--run-seconds 2.0

iigs-game-test: gfx maze iigs-game
	PYTHONPATH=$(GS2_PY) python3 py/gs2_render_test.py \
		--gs2 $(GSSQUARED) \
		--bin $(IIGS_GAME_BIN) \
		--gfx $(GFX_DIR) \
		--out $(IIGS_BUILD)/game_frame.png \
		--run-seconds 2.0

# Interactive demo: one process builds (if needed), spawns GS2, waits for Enter.
iigs-demo:
	GS2_PY=$(GS2_PY) GSSQUARED=$(GSSQUARED) python3 py/gs2_run_demo.py

iigs-game-demo:
	GS2_PY=$(GS2_PY) GSSQUARED=$(GSSQUARED) python3 py/gs2_run_demo.py --bin $(IIGS_GAME_BIN) --make-target iigs-game

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(IIGS_DIR)/harness.bin $(IIGS_DIR)/game.bin $(IIGS_DIR)/MSPACMAN.SYS16 \
		$(IIGS_DIR)/_FileInformation.txt $(IIGS_DIR)/*_Output.txt 2>/dev/null; true
