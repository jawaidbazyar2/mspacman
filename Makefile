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
WAVE_ROM  := mspacman/82s126.1m
# Hand-cleaned 6x6 tile / 14x12 sprite contact sheets: the game's art.
CLEAN_ART_DIR := assets
CLEAN_ART := $(CLEAN_ART_DIR)/tiles_6x6_clean.ppm $(CLEAN_ART_DIR)/sprites_14x12_clean.ppm
GFX_BINS := $(addprefix $(GFX_DIR)/,tiles6.bin sprites14x12.bin sprites14x12.mask.bin \
	sprites14x12.odd.bin sprites14x12.odd.mask.bin)

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

.PHONY: all clean verify sjasmplus-check gfx gfx-ppm gfx-rom palette maze tiles-preview \
	iigs iigs-test iigs-demo iigs-game iigs-game-test iigs-game-demo iigs-gsos \
	iigs-lower lower-iigs-check iigs-lower-demo iigs-lower-gsos iigs-gsos-prod FORCE \
	lift lift-check c c-check c-only-check idiom idiom-check idiom-cov \
	lower lower-check lower-cov lower-only lower-only-check

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

# Phase-2 host: a copy of the phase-1 sources under c/, plus lifted routines.
# lift/ itself stays the pure Z80 host.
C_BIN := $(BUILD_DIR)/c/mspac-c
C_SRCS := $(wildcard c/*.c) c/fiber_arm64.S $(LIFT_DIR)/third_party/Z80/sources/Z80.c

$(BUILD_DIR)/c:
	mkdir -p $(BUILD_DIR)/c

c: $(C_BIN)

$(C_BIN): $(wildcard c/*.c) $(wildcard c/*.h) c/fiber_arm64.S $(BIN) | $(BUILD_DIR)/c
	cc -std=c11 -O2 -Wall -Wextra -Wconversion -fno-strict-aliasing \
		-I c \
		-I $(LIFT_DIR)/third_party/Z80/API \
		-I $(LIFT_DIR)/third_party/Zeta/API \
		$(SDL_CFLAGS) \
		-DZ80_STATIC -DZ80_WITH_EXECUTE \
		-o $@ $(C_SRCS) $(SDL_LIBS)

c-check: $(C_BIN)
	$(C_BIN) --replay testplay2

# Phase 2 exit: no Z80 instruction runs.
c-only-check: $(C_BIN)
	$(C_BIN) --c-only --replay testplay2
	$(C_BIN) --c-only --check 600

# Phase 2.5 host. Always C-only. Replay masks Z80 registers and the stack.
IDIOM_BIN := $(BUILD_DIR)/idiom/mspac-idiom
IDIOM_SRCS := $(wildcard idiom/*.c)
IDIOM_CFLAGS := -std=c11 -O2 -Wall -Wextra -Wconversion -fno-strict-aliasing \
	-I idiom \
	$(SDL_CFLAGS)

$(BUILD_DIR)/idiom:
	mkdir -p $(BUILD_DIR)/idiom

idiom: $(IDIOM_BIN)

$(IDIOM_BIN): $(wildcard idiom/*.c) $(wildcard idiom/*.h) $(BIN) | $(BUILD_DIR)/idiom
	cc $(IDIOM_CFLAGS) -o $@ $(IDIOM_SRCS) $(SDL_LIBS)

idiom-check: $(IDIOM_BIN)
	@fail=0; \
	for d in corpus/c-*; do \
		echo "idiom-check: $$d"; \
		$(IDIOM_BIN) --replay "$$d" || fail=1; \
	done; \
	exit $$fail

IDIOM_COV_BIN := $(BUILD_DIR)/idiom/mspac-idiom-cov
IDIOM_PROF := $(BUILD_DIR)/idiom/cov
LLVM_PROFDATA := $(shell xcrun --find llvm-profdata 2>/dev/null || echo llvm-profdata)
LLVM_COV := $(shell xcrun --find llvm-cov 2>/dev/null || echo llvm-cov)

idiom-cov: $(wildcard idiom/*.c) $(wildcard idiom/*.h) | $(BUILD_DIR)/idiom
	cc $(IDIOM_CFLAGS) -fprofile-instr-generate -fcoverage-mapping \
		-o $(IDIOM_COV_BIN) $(IDIOM_SRCS) $(SDL_LIBS)
	rm -rf $(IDIOM_PROF)
	mkdir -p $(IDIOM_PROF)
	fail=0; \
	for d in corpus/c-*; do \
		name=$$(basename "$$d"); \
		LLVM_PROFILE_FILE="$(IDIOM_PROF)/$$name-%p.profraw" \
			$(IDIOM_COV_BIN) --replay "$$d" || fail=1; \
	done; \
	$(LLVM_PROFDATA) merge -sparse $(IDIOM_PROF)/*.profraw -o $(IDIOM_PROF)/cov.profdata; \
	$(LLVM_COV) report $(IDIOM_COV_BIN) -instr-profile=$(IDIOM_PROF)/cov.profdata \
		> $(IDIOM_PROF)/report.txt; \
	$(LLVM_COV) show $(IDIOM_COV_BIN) -instr-profile=$(IDIOM_PROF)/cov.profdata \
		-show-branches=count > $(IDIOM_PROF)/show.txt; \
	echo "idiom-cov: $(IDIOM_PROF)/report.txt"; \
	exit $$fail

# Phase 3. lower/ is the working copy of the locked idiom/; lower/*.s is
# its 65816. mspac-lower runs both on GSSquared's 65816 core.
LOWER_DIR := lower
LOWER_BUILD := $(BUILD_DIR)/lower
LOWER_BIN := $(LOWER_BUILD)/lower.bin
LOWER_EXE := $(LOWER_BUILD)/mspac-lower
LOWER_ONLY_EXE := $(LOWER_BUILD)/mspac-lower-only
GS2_SRC ?= $(HOME)/src/gssquared/src
LOWER_LOGIC := actor attract clock coin cutscene difficulty draw fright fruit \
	ghost hud maze mode pac play rng sched score siren sound sprite start \
	target task vblank conly
LOWER_HOSTC := board corpus video audio input ram
LOWER_HDRS := $(wildcard $(LOWER_DIR)/*.h) $(wildcard $(LOWER_DIR)/host/*.h)
LOWER_CFLAGS := -std=c11 -O2 -Wall -Wextra -Wconversion -fno-strict-aliasing \
	-I $(LOWER_DIR) -I $(LOWER_DIR)/host -include $(LOWER_DIR)/host/hook.h \
	$(SDL_CFLAGS)
LOWER_CXXFLAGS := -std=c++17 -O2 -w -I $(LOWER_DIR)/host/shim -I $(GS2_SRC) \
	-I $(LOWER_DIR)/host $(SDL_CFLAGS)
LOWER_CORE_OBJS := $(LOWER_BUILD)/cpu65.o $(LOWER_BUILD)/gs2cpu.o
LOWER_C_SRCS := $(foreach f,$(LOWER_LOGIC) $(LOWER_HOSTC),$(LOWER_DIR)/$(f).c) \
	$(LOWER_DIR)/host/shadow.c $(LOWER_DIR)/host/selftest.c
LOWER_ASM := $(wildcard $(LOWER_DIR)/*.s)

$(LOWER_BUILD):
	mkdir -p $(LOWER_BUILD)

$(LOWER_DIR)/entries.s $(LOWER_DIR)/host/entries.h $(LOWER_DIR)/entry_ids.s: $(LOWER_DIR)/entries.txt py/gen_lower_entries.py
	python3 py/gen_lower_entries.py

$(LOWER_BUILD)/cpu65.o: $(LOWER_DIR)/host/cpu65.cpp $(LOWER_DIR)/host/l65.h \
		$(LOWER_DIR)/host/shim/NClock.hpp | $(LOWER_BUILD)
	c++ $(LOWER_CXXFLAGS) -c -o $@ $<

$(LOWER_BUILD)/gs2cpu.o: $(GS2_SRC)/cpu.cpp | $(LOWER_BUILD)
	c++ $(LOWER_CXXFLAGS) -c -o $@ $<

$(LOWER_BIN): $(LOWER_ASM) $(LOWER_DIR)/entries.s $(MERLIN32) | $(LOWER_BUILD)
	rm -f $(LOWER_DIR)/lower.bin $(LOWER_DIR)/error_output.txt $(LOWER_DIR)/*_Error.txt
	cd $(LOWER_DIR) && $(MERLIN32) -V $(MERLIN_LIB) link.s > merlin.log; \
		rm -f *_Error.txt; \
		if grep "\[Error\]" merlin.log; then rm -f merlin.log error_output.txt; exit 1; fi; \
		rm -f merlin.log; test -f lower.bin
	mv -f $(LOWER_DIR)/lower.bin $@
	@mv -f $(LOWER_DIR)/lower.bin_S01_Main_Output.txt $(LOWER_BUILD)/lower_Output.txt 2>/dev/null; \
		mv -f $(LOWER_DIR)/lower.bin_Symbols.txt $(LOWER_BUILD)/lower_Symbols.txt 2>/dev/null; \
		rm -f $(LOWER_DIR)/_FileInformation.txt $(LOWER_DIR)/error_output.txt; true
	@echo "lower.bin $$(wc -c < $@) bytes"

$(LOWER_EXE): $(LOWER_C_SRCS) $(LOWER_DIR)/main.c $(LOWER_HDRS) \
		$(LOWER_DIR)/host/entries.h $(LOWER_CORE_OBJS) | $(LOWER_BUILD)
	cc $(LOWER_CFLAGS) -c -o $(LOWER_BUILD)/main.o \
		-Dmain=idiom_main -Dboard_init=lower_board_init $(LOWER_DIR)/main.c
	$(foreach s,$(LOWER_C_SRCS),cc $(LOWER_CFLAGS) -c -o $(LOWER_BUILD)/$(notdir $(s:.c=.o)) $(s) &&) true
	c++ -o $@ $(LOWER_BUILD)/main.o $(LOWER_CORE_OBJS) \
		$(foreach s,$(LOWER_C_SRCS),$(LOWER_BUILD)/$(notdir $(s:.c=.o))) \
		$(SDL_LIBS)

lower: $(LOWER_BIN) $(LOWER_EXE)

# Self-test, then every C-only session with every lowered function
# shadowed, then the idiom/ vs lower/ hook check.
lower-check: lower
	$(LOWER_EXE) --selftest
	@fail=0; \
	for d in corpus/c-*; do \
		echo "lower-check: $$d"; \
		$(LOWER_EXE) --asm=all --replay "$$d" || fail=1; \
	done; \
	python3 py/lower_diff.py || fail=1; \
	exit $$fail

# Stage 3b: the host C and lower.bin, no game-logic C. The frame entry is
# the 65816's c_only_frame (lower/host/only.c).
LOWER_ONLY_BUILD := $(LOWER_BUILD)/only
LOWER_ONLY_SRCS := $(foreach f,$(LOWER_HOSTC),$(LOWER_DIR)/$(f).c) \
	$(LOWER_DIR)/host/shadow.c $(LOWER_DIR)/host/selftest.c $(LOWER_DIR)/host/only.c
LOWER_FRAME_LOG := $(LOWER_BUILD)/frame_cycles.txt

$(LOWER_ONLY_EXE): $(LOWER_ONLY_SRCS) $(LOWER_DIR)/main.c $(LOWER_HDRS) \
		$(LOWER_DIR)/host/entries.h $(LOWER_CORE_OBJS) | $(LOWER_BUILD)
	mkdir -p $(LOWER_ONLY_BUILD)
	cc $(LOWER_CFLAGS) -DLOWER_ONLY -c -o $(LOWER_ONLY_BUILD)/main.o \
		-Dmain=idiom_main -Dboard_init=lower_board_init $(LOWER_DIR)/main.c
	$(foreach s,$(LOWER_ONLY_SRCS),cc $(LOWER_CFLAGS) -DLOWER_ONLY -c \
		-o $(LOWER_ONLY_BUILD)/$(notdir $(s:.c=.o)) $(s) &&) true
	c++ -o $@ $(LOWER_ONLY_BUILD)/main.o $(LOWER_CORE_OBJS) \
		$(foreach s,$(LOWER_ONLY_SRCS),$(LOWER_ONLY_BUILD)/$(notdir $(s:.c=.o))) \
		$(SDL_LIBS)

lower-only: $(LOWER_BIN) $(LOWER_ONLY_EXE)

# Every C-only session on the 65816 alone, then the cycle report.
lower-only-check: lower-only
	@rm -f $(LOWER_FRAME_LOG); fail=0; \
	for d in corpus/c-*; do \
		echo "lower-only-check: $$d"; \
		$(LOWER_ONLY_EXE) --frame-log $(LOWER_FRAME_LOG) --replay "$$d" || fail=1; \
	done; \
	python3 py/lower_cycles.py $(LOWER_FRAME_LOG) || fail=1; \
	exit $$fail

LOWER_COV_EXE := $(LOWER_BUILD)/mspac-lower-cov
LOWER_PROF := $(LOWER_BUILD)/cov

lower-cov: $(LOWER_C_SRCS) $(LOWER_DIR)/main.c $(LOWER_HDRS) $(LOWER_DIR)/host/entries.h \
		$(LOWER_CORE_OBJS) $(LOWER_BIN)
	cc $(LOWER_CFLAGS) -fprofile-instr-generate -fcoverage-mapping -c \
		-o $(LOWER_BUILD)/cov-main.o -Dmain=idiom_main -Dboard_init=lower_board_init \
		$(LOWER_DIR)/main.c
	$(foreach s,$(LOWER_C_SRCS),cc $(LOWER_CFLAGS) -fprofile-instr-generate -fcoverage-mapping \
		-c -o $(LOWER_BUILD)/cov-$(notdir $(s:.c=.o)) $(s) &&) true
	c++ -fprofile-instr-generate -o $(LOWER_COV_EXE) $(LOWER_BUILD)/cov-main.o \
		$(LOWER_CORE_OBJS) \
		$(foreach s,$(LOWER_C_SRCS),$(LOWER_BUILD)/cov-$(notdir $(s:.c=.o))) $(SDL_LIBS)
	rm -rf $(LOWER_PROF)
	mkdir -p $(LOWER_PROF)
	fail=0; \
	for d in corpus/c-*; do \
		name=$$(basename "$$d"); \
		LLVM_PROFILE_FILE="$(LOWER_PROF)/$$name-%p.profraw" \
			$(LOWER_COV_EXE) --replay "$$d" || fail=1; \
	done; \
	$(LLVM_PROFDATA) merge -sparse $(LOWER_PROF)/*.profraw -o $(LOWER_PROF)/cov.profdata; \
	$(LLVM_COV) report $(LOWER_COV_EXE) -instr-profile=$(LOWER_PROF)/cov.profdata \
		> $(LOWER_PROF)/report.txt; \
	$(LLVM_COV) show $(LOWER_COV_EXE) -instr-profile=$(LOWER_PROF)/cov.profdata \
		-show-branches=count > $(LOWER_PROF)/show.txt; \
	echo "lower-cov: $(LOWER_PROF)/report.txt"; \
	exit $$fail

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

# IIgs 6x6 tiles / 14x12 even+odd sprites from the cleaned contact sheets.
gfx: $(GFX_BINS) palette

$(GFX_DIR)/tiles6.bin: $(CLEAN_ART) py/gen_shr_gfx.py
	python3 py/gen_shr_gfx.py --from-ppm $(CLEAN_ART_DIR) --out $(GFX_DIR)

$(filter-out $(GFX_DIR)/tiles6.bin,$(GFX_BINS)): $(GFX_DIR)/tiles6.bin ;

# Same as gfx, plus PPM contact sheets of the cleaned art under build/gfx/ppm/.
gfx-ppm: $(CLEAN_ART) palette
	python3 py/gen_shr_gfx.py --from-ppm $(CLEAN_ART_DIR) --out $(GFX_DIR) --ppm

# The ROM scale of 5e/5f (the starting point the sheets were cleaned from),
# with PPM contact sheets, under build/gfx/rom/. The game does not use it.
gfx-rom: $(TILE_ROM) $(SPRITE_ROM)
	python3 py/gen_shr_gfx.py --tiles $(TILE_ROM) --sprites $(SPRITE_ROM) --color-rom $(COLOR_ROM) \
		--out $(GFX_DIR)/rom --ppm

# SHR palette from 82s123.7f / 82s126.4a (maze pal #1D in slots 0–3),
# and the arcade tile color banks as SHR pen maps (docs/ColorMap.md).
palette:
	python3 py/gen_palette.py --color-rom $(COLOR_ROM) --palette-rom $(PALETTE_ROM) \
		--out $(GFX_DIR) --asm $(IIGS_DIR)/palette_data.s
	python3 py/gen_tile_banks.py --color-rom $(COLOR_ROM) --palette-rom $(PALETTE_ROM) \
		-o $(IIGS_DIR)/tile_bank_data.s

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
		$(IIGS_DIR)/compiled_points.s $(IIGS_DIR)/compiled_mspac.s \
		$(IIGS_DIR)/compiled_acts.s

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
		$(GFX_DIR)/sprites14x12.odd.bin $(GFX_DIR)/sprites14x12.odd.mask.bin \
		$(PALETTE_ROM) py/gen_palette.py
	python3 py/gen_compiled_ghosts.py --gfx $(GFX_DIR) --palette-rom $(PALETTE_ROM) -o $(IIGS_DIR)/compiled_ghosts.s

$(IIGS_DIR)/compiled_fruits.s: py/gen_compiled_fruits.py \
		$(GFX_DIR)/sprites14x12.bin $(PALETTE_ROM) py/gen_shr_gfx.py py/gen_palette.py
	python3 py/gen_compiled_fruits.py --gfx $(GFX_DIR) --palette-rom $(PALETTE_ROM) -o $(IIGS_DIR)/compiled_fruits.s

$(IIGS_DIR)/compiled_points.s: py/gen_compiled_points.py \
		$(GFX_DIR)/sprites14x12.bin py/gen_shr_gfx.py
	python3 py/gen_compiled_points.py --gfx $(GFX_DIR) -o $(IIGS_DIR)/compiled_points.s

$(IIGS_DIR)/compiled_mspac.s: py/gen_compiled_mspac.py \
		$(GFX_DIR)/sprites14x12.bin $(PALETTE_ROM) py/gen_shr_gfx.py py/gen_palette.py
	python3 py/gen_compiled_mspac.py --gfx $(GFX_DIR) --palette-rom $(PALETTE_ROM) -o $(IIGS_DIR)/compiled_mspac.s

$(IIGS_DIR)/compiled_acts.s: py/gen_compiled_acts.py \
		$(GFX_DIR)/sprites14x12.bin $(PALETTE_ROM) py/gen_shr_gfx.py py/gen_palette.py
	python3 py/gen_compiled_acts.py --gfx $(GFX_DIR) --palette-rom $(PALETTE_ROM) -o $(IIGS_DIR)/compiled_acts.s

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

# Phase 3 on the IIgs: lower/*.s with iigs/lower_io.s for io.s ->
# lower_game.bin ($05/0000), and the renderer host -> lower_host.bin
# ($02/0000). Both assemble in staging copies under build/iigs/.
IIGS_LOWER_GAME := $(IIGS_BUILD)/lower_game.bin
IIGS_LOWER_HOST := $(IIGS_BUILD)/lower_host.bin
IIGS_LOWER_STAGE := $(IIGS_BUILD)/stage
IIGS_WAVE_DATA := $(IIGS_DIR)/wave_data.s

# DOC wave samples and frequency tables from the WSG sound PROM.
$(IIGS_WAVE_DATA): $(WAVE_ROM) py/gen_wave_data.py
	python3 py/gen_wave_data.py --prom $(WAVE_ROM) -o $@

# Assemble in DIR with LINK; fail on any Merlin error line.
define merlin_in
	cd $(1) && $(MERLIN32) -V $(MERLIN_LIB) $(2) > merlin.log; \
		if grep "\[Error\]" merlin.log; then exit 1; fi; true
endef

$(IIGS_LOWER_GAME): $(LOWER_ASM) $(LOWER_DIR)/entries.s $(IIGS_DIR)/lower_io.s \
		$(MERLIN32) | $(IIGS_BUILD)
	rm -rf $(IIGS_LOWER_STAGE)/game
	mkdir -p $(IIGS_LOWER_STAGE)/game
	cp $(LOWER_DIR)/*.s $(IIGS_LOWER_STAGE)/game/
	cp $(IIGS_DIR)/lower_io.s $(IIGS_LOWER_STAGE)/game/io.s
	$(call merlin_in,$(IIGS_LOWER_STAGE)/game,link.s)
	cp $(IIGS_LOWER_STAGE)/game/lower.bin $@
	@echo "lower_game.bin $$(wc -c < $@) bytes"

$(IIGS_LOWER_HOST): $(wildcard $(IIGS_DIR)/*.s) $(IIGS_WAVE_DATA) $(LOWER_DIR)/entry_ids.s \
		$(MERLIN32) | $(IIGS_BUILD)
	rm -rf $(IIGS_LOWER_STAGE)/host
	mkdir -p $(IIGS_LOWER_STAGE)/host
	cp $(IIGS_DIR)/*.s $(LOWER_DIR)/entry_ids.s $(IIGS_LOWER_STAGE)/host/
	$(call merlin_in,$(IIGS_LOWER_STAGE)/host,link_lower.s)
	cp $(IIGS_LOWER_STAGE)/host/lower_host.bin $@
	@sz=$$(wc -c < $@); \
		if [ $$sz -gt 65536 ]; then \
			echo "error: lower_host.bin is $$sz bytes (must fit bank \$$02)"; exit 1; \
		fi; \
		echo "lower_host.bin $$sz bytes"

iigs-lower: palette gfx $(IIGS_COMPILED) $(BIN) $(IIGS_LOWER_GAME) $(IIGS_LOWER_HOST)

# Replay C-only sessions on GSSquared through lower_game.bin and compare
# the game bank with each frame record. LOWER_IIGS_FRAMES caps the frames
# per session (0: all).
LOWER_IIGS_SESSIONS ?= corpus/c-shakedown corpus/c-attract corpus/c-play1
LOWER_IIGS_FRAMES ?= 600
lower-iigs-check: iigs-lower
	PYTHONPATH=$(GS2_PY) python3 py/gs2_lower_check.py --gs2 $(GSSQUARED) \
		--frames $(LOWER_IIGS_FRAMES) $(LOWER_IIGS_SESSIONS)

# Play it: spawn GSSquared with the lowered game and leave it running.
iigs-lower-demo: iigs-lower
	PYTHONPATH=$(GS2_PY) python3 py/gs2_lower_check.py --gs2 $(GSSQUARED) --play

# The lowered game as a GS/OS S16 application, MSPACMAN.SYS16: the host
# (code segment) plus data segments for the bank-aligned game bank (ROM
# image and lower.bin at $A000), the BCK strip, the art and the renderer's
# work RAM. The disk is a copy of $(IIGS_GSOS_TEMPLATE), a minimal GS/OS
# boot volume (MSPACMAN) with no System:Start and no application of its
# own. The launcher boots only a root file named *.SYS16, *.SYSTEM or
# START, so the name must keep .SYS16. Add only the application to the
# copy; never write the template. It is built in $(IIGS_BUILD)/gsos
# because the frozen iigs-gsos target owns $(IIGS_GSOS_BIN).
# IIGS_LOWER_GSOS_INSTALL=1 also copies it onto $(IIGS_GSOS_DISK).
# make iigs-gsos-prod builds the same disk with GSOS_PROD=1: no border
# phase colors (SetBorder is an RTS).
IIGS_LOWER_GSOS_DIR := $(IIGS_BUILD)/gsos
IIGS_LOWER_GSOS := $(IIGS_LOWER_GSOS_DIR)/MSPACMAN.SYS16
IIGS_LOWER_DISK ?= $(IIGS_BUILD)/MsPacMan.2mg
IIGS_GSOS_TEMPLATE := assets/template.2mg
IIGS_LOWER_GSOS_STAGE := $(IIGS_LOWER_STAGE)/gsos
GSOS_PROD ?= 0
IIGS_LOWER_GSOS_MODE := $(IIGS_BUILD)/gsos_mode

# Rewritten only when GSOS_PROD changes, so switching modes reassembles.
$(IIGS_LOWER_GSOS_MODE): FORCE | $(IIGS_BUILD)
	@echo "GSOS_PROD=$(GSOS_PROD)" | cmp -s - $@ || echo "GSOS_PROD=$(GSOS_PROD)" > $@

FORCE:

$(IIGS_LOWER_GSOS): $(LOWER_ASM) $(LOWER_DIR)/entries.s $(LOWER_DIR)/entry_ids.s \
		$(wildcard $(IIGS_DIR)/*.s) $(IIGS_WAVE_DATA) $(BIN) $(GFX_BINS) py/omf_fix_align.py \
		$(IIGS_LOWER_GSOS_MODE) $(MERLIN32) | $(IIGS_BUILD)
	rm -rf $(IIGS_LOWER_GSOS_STAGE)
	mkdir -p $(IIGS_LOWER_GSOS_STAGE)/game $(IIGS_LOWER_GSOS_STAGE)/host
	cp $(LOWER_DIR)/*.s $(IIGS_LOWER_GSOS_STAGE)/game/
	cp $(IIGS_DIR)/lower_io.s $(IIGS_LOWER_GSOS_STAGE)/game/io.s
	sed -i '' 's/^	org	\$$0000/	org	$$A000/' $(IIGS_LOWER_GSOS_STAGE)/game/all.s
	printf '\tdsk\tlower_a000.bin\n\torg\t$$A000\n\ttyp\t$$06\n\tasm\tall.s\n\tsna\tMain\n' \
		> $(IIGS_LOWER_GSOS_STAGE)/game/link_a000.s
	$(call merlin_in,$(IIGS_LOWER_GSOS_STAGE)/game,link_a000.s)
	@sz=$$(wc -c < $(IIGS_LOWER_GSOS_STAGE)/game/lower_a000.bin); \
		if [ $$sz -gt 20480 ]; then \
			echo "error: lower_a000.bin is $$sz bytes (must fit \$$A000-\$$EFFF)"; exit 1; \
		fi
	cp $(IIGS_DIR)/*.s $(LOWER_DIR)/entry_ids.s $(BIN) $(GFX_BINS) \
		$(IIGS_LOWER_GSOS_STAGE)/game/lower_a000.bin $(IIGS_LOWER_GSOS_STAGE)/host/
	@if [ "$(GSOS_PROD)" = 1 ]; then \
		sed -i '' 's/^GSOS_PROD      equ 0/GSOS_PROD      equ 1/' $(IIGS_LOWER_GSOS_STAGE)/host/mem_gsos.s && \
		grep -q '^GSOS_PROD      equ 1' $(IIGS_LOWER_GSOS_STAGE)/host/mem_gsos.s && \
		echo "GSOS_PROD=1: border profiler off"; \
	fi
	$(call merlin_in,$(IIGS_LOWER_GSOS_STAGE)/host,link_gsos_lower.s)
	python3 py/omf_fix_align.py $(IIGS_LOWER_GSOS_STAGE)/host/MSPACMAN.SYS16 Game=0x10000
	mkdir -p $(IIGS_LOWER_GSOS_DIR)
	cp $(IIGS_LOWER_GSOS_STAGE)/host/MSPACMAN.SYS16 $@
	@echo "MSPACMAN.SYS16 $$(wc -c < $@) bytes"

iigs-lower-gsos: palette gfx $(IIGS_COMPILED) $(IIGS_LOWER_GSOS) $(IIGS_GSOS_TEMPLATE)
	rm -f "$(IIGS_LOWER_DISK)"
	cp $(IIGS_GSOS_TEMPLATE) "$(IIGS_LOWER_DISK)"
	cd $(IIGS_LOWER_GSOS_DIR) && $(CP2) add --strip-paths --no-strip-ext "$(abspath $(IIGS_LOWER_DISK))" MSPACMAN.SYS16
	$(CP2) set-attr "$(IIGS_LOWER_DISK)" type=0xb3,aux=0x0000 MSPACMAN.SYS16
	@if [ "$(IIGS_LOWER_GSOS_INSTALL)" = 1 ]; then \
		cd $(IIGS_LOWER_GSOS_DIR) && $(CP2) add --overwrite --strip-paths --no-strip-ext "$(IIGS_GSOS_DISK)" MSPACMAN.SYS16 && \
		$(CP2) set-attr "$(IIGS_GSOS_DISK)" type=0xb3,aux=0x0000 MSPACMAN.SYS16; \
	fi
	$(CP2) catalog "$(IIGS_LOWER_DISK)"

iigs-gsos-prod:
	$(MAKE) iigs-lower-gsos GSOS_PROD=1

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
