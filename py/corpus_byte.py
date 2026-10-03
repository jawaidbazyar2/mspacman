"""Print one machine byte across a range of MSPF frame records.

Usage: python3 py/corpus_byte.py DIR ADDR FIRST LAST

ADDR is hex: $4000-$47FF (tile/color), $4C00-$4FEF (work RAM; version 2
records stop at $4DEF), $4FF0-$4FFF (sprite RAM), $5060-$506F (sprite
positions). The value is printed only on frames where it changes.
"""
import struct
import sys

HDR = 24
WORK = 2132


def offset(addr, work_bytes):
    sprite = WORK + work_bytes
    if 0x4000 <= addr < 0x4800:
        return 84 + (addr - 0x4000)
    if 0x4C00 <= addr < 0x4C00 + work_bytes:
        return WORK + (addr - 0x4C00)
    if 0x4FF0 <= addr < 0x5000:
        return sprite + (addr - 0x4FF0)
    if 0x5060 <= addr < 0x5070:
        return sprite + 16 + (addr - 0x5060)
    raise SystemExit(f"{addr:04X} is not in a frame record")


def main():
    d, addr = sys.argv[1], int(sys.argv[2].lstrip("$"), 16)
    first, last = int(sys.argv[3]), int(sys.argv[4])
    data = open(f"{d}/frames", "rb").read()
    ver, rec = struct.unpack_from("<2I", data, 4)
    off = offset(addr, 1008 if ver >= 3 else 496)
    prev = None
    for i in range(first, last + 1):
        v = data[HDR + i * rec + off]
        if v != prev:
            print(f"{i:6} ${addr:04X} = {v:02X}")
            prev = v


if __name__ == "__main__":
    main()
