"""Print a few fields of MSPF frame records (version 2 or 3).

Usage: python3 py/corpus_peek.py DIR FIRST LAST

One line per frame: PC, SP, HL, I, IFF1, latch $5000, the IN count from
`inputs`, the task head, and game mode $4E00 (version 3 only).
"""
import struct
import sys

HDR = 24
WORK = 2132


def input_counts(path):
    counts = []
    with open(path, "rb") as f:
        f.read(8)
        while True:
            raw = f.read(2)
            if len(raw) < 2:
                break
            n = struct.unpack("<H", raw)[0]
            f.read(n)
            counts.append(n)
    return counts


def main():
    d, first, last = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    data = open(f"{d}/frames", "rb").read()
    ver, rec = struct.unpack_from("<2I", data, 4)
    counts = input_counts(f"{d}/inputs")
    for i in range(first, last + 1):
        o = HDR + i * rec
        pc, sp, af, bc, de, hl = struct.unpack_from("<6H", data, o + 8)
        reg_i = data[o + 34]
        iff1 = data[o + 36]
        latch0 = data[o + 42]
        w = data[o + WORK:]
        head = w[0x82] | (w[0x83] << 8)
        mode = f" mode={w[0x200]:02X}" if ver >= 3 else ""
        print(f"{i:6} pc={pc:04X} sp={sp:04X} hl={hl:04X} i={reg_i:02X} "
              f"iff1={iff1} l0={latch0} in={counts[i]} head={head:04X}{mode}")


if __name__ == "__main__":
    main()
