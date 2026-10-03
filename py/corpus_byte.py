"""Print one machine byte across a range of MSPF frame records.

Usage: python3 py/corpus_byte.py DIR ADDR FIRST LAST

ADDR is hex: $4000-$47FF (tile/color), $4C00-$4DEF (work RAM), $4FF0-$4FFF
(sprite RAM), $5060-$506F (sprite positions). The value is printed only
on frames where it changes.
"""
import sys

HDR = 24
REC = 2664


def offset(addr):
    if 0x4000 <= addr < 0x4800:
        return 84 + (addr - 0x4000)
    if 0x4C00 <= addr < 0x4DF0:
        return 2132 + (addr - 0x4C00)
    if 0x4FF0 <= addr < 0x5000:
        return 2628 + (addr - 0x4FF0)
    if 0x5060 <= addr < 0x5070:
        return 2644 + (addr - 0x5060)
    raise SystemExit(f"{addr:04X} is not in a frame record")


def main():
    d, addr = sys.argv[1], int(sys.argv[2].lstrip("$"), 16)
    first, last = int(sys.argv[3]), int(sys.argv[4])
    off = offset(addr)
    data = open(f"{d}/frames", "rb").read()
    prev = None
    for i in range(first, last + 1):
        v = data[HDR + i * REC + off]
        if v != prev:
            print(f"{i:6} ${addr:04X} = {v:02X}")
            prev = v


if __name__ == "__main__":
    main()
