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

.PHONY: all clean verify sjasmplus-check

all: $(BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Assemble working copy with SjASMPlus.
# --raw writes a flat binary; listing goes beside it for debugging.
$(BIN): $(ASM) $(SJASMPLUS) | $(BUILD_DIR)
	$(SJASMPLUS) \
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
	@python3 -c '\
from pathlib import Path; import sys; \
b = Path("$(BIN)").read_bytes(); \
slices = [("boot1",0x0000),("boot2",0x1000),("boot3",0x2000),("boot4",0x3000),("boot5",0x8000),("boot6",0x9000)]; \
bad = 0; \
\
for name, off in slices: \
    ok = Path(name).read_bytes() == b[off:off+0x1000]; \
    print("%s: %s" % (name, "OK" if ok else "DIFF")); \
    bad += not ok; \
sys.exit(bad)'

clean:
	rm -rf $(BUILD_DIR)
