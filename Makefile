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

.PHONY: all clean verify sjasmplus-check gfx gfx-ppm

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
gfx: $(TILE_ROM) $(SPRITE_ROM)
	python3 py/gen_shr_gfx.py --tiles $(TILE_ROM) --sprites $(SPRITE_ROM) --out $(GFX_DIR)

# Same as gfx, plus PPM contact sheets under build/gfx/ppm/ for eyeballing.
gfx-ppm: $(TILE_ROM) $(SPRITE_ROM)
	python3 py/gen_shr_gfx.py --tiles $(TILE_ROM) --sprites $(SPRITE_ROM) --out $(GFX_DIR) --ppm

clean:
	rm -rf $(BUILD_DIR)
