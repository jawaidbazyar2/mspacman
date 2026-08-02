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
TILE_ROM  := mspacman-orig/5e
SPRITE_ROM := mspacman-orig/5f

MERLIN32  ?= $(HOME)/src/Merlin32_v1.1/MacOs/Merlin32
MERLIN_LIB ?= $(HOME)/src/Merlin32_v1.1/Library
IIGS_DIR  := iigs
IIGS_BUILD := $(BUILD_DIR)/iigs
IIGS_BIN  := $(IIGS_BUILD)/harness.bin

GSSQUARED ?= $(HOME)/src/gssquared/build/GSSquared
GS2_PY    := $(HOME)/src/gssquared/clients/python/src

.PHONY: all clean verify sjasmplus-check gfx gfx-ppm palette maze tiles-preview iigs iigs-test iigs-demo

all: $(BIN)

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

# Assemble IIgs render harness with Merlin32 → build/iigs/harness.bin
iigs: palette rails gfx $(IIGS_DIR)/compiled_ghosts.s $(IIGS_BIN)

$(IIGS_DIR)/compiled_ghosts.s: py/gen_compiled_ghosts.py \
		$(GFX_DIR)/sprites14x12.bin $(GFX_DIR)/sprites14x12.mask.bin \
		$(GFX_DIR)/sprites14x12.odd.bin $(GFX_DIR)/sprites14x12.odd.mask.bin
	python3 py/gen_compiled_ghosts.py --gfx $(GFX_DIR) -o $(IIGS_DIR)/compiled_ghosts.s

$(IIGS_DIR)/ghost_work_blit.s: py/gen_ghost_work_blit.py
	python3 py/gen_ghost_work_blit.py -o $(IIGS_DIR)/ghost_work_blit.s

$(IIGS_BUILD):
	mkdir -p $(IIGS_BUILD)

$(IIGS_BIN): $(IIGS_DIR)/link.s $(IIGS_DIR)/all.s $(IIGS_DIR)/equates.s \
		$(IIGS_DIR)/shr_body.s $(IIGS_DIR)/render_body.s \
		$(IIGS_DIR)/compiled_ghosts.s \
		$(IIGS_DIR)/harness_body.s $(IIGS_DIR)/rails_data.s \
		$(IIGS_DIR)/palette_data.s \
		$(MERLIN32) | $(IIGS_BUILD)
	cd $(IIGS_DIR) && $(MERLIN32) $(MERLIN_LIB) link.s
	mv -f $(IIGS_DIR)/harness.bin $(IIGS_BIN)
	@rm -f $(IIGS_DIR)/_FileInformation.txt $(IIGS_DIR)/harness.bin_Output.txt 2>/dev/null; true

# Spawn GSSquared, inject harness + assets, dump SHR frame PNG.
iigs-test: gfx maze iigs
	PYTHONPATH=$(GS2_PY) python3 py/gs2_render_test.py \
		--gs2 $(GSSQUARED) \
		--bin $(IIGS_BIN) \
		--gfx $(GFX_DIR) \
		--out $(IIGS_BUILD)/frame.png \
		--run-seconds 2.0

# Interactive demo: one process builds (if needed), spawns GS2, waits for Enter.
iigs-demo:
	GS2_PY=$(GS2_PY) GSSQUARED=$(GSSQUARED) python3 py/gs2_run_demo.py

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(IIGS_DIR)/harness.bin $(IIGS_DIR)/_FileInformation.txt \
		$(IIGS_DIR)/*_Output.txt 2>/dev/null; true
