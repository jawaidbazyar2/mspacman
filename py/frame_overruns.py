"""List frames whose record did not end in the idle spin ($238D-$2392).

Usage: python3 py/frame_overruns.py DIR [DIR ...]

A frame that ends elsewhere was still running main-line work when the next
VBLANK came. Consecutive such frames are grouped into one run. Each run
prints its first and last frame, its length, the PCs it stopped on, and
game mode $4E00 (version 3 records only; version 2 prints '--').
"""
import struct
import sys

HDR = 24
WORK = 2132


def runs(d):
    data = open(f"{d}/frames", "rb").read()
    ver, rec = struct.unpack_from("<2I", data, 4)
    n = (len(data) - HDR) // rec
    out = []
    cur = None
    for i in range(n):
        o = HDR + i * rec
        pc = struct.unpack_from("<H", data, o + 8)[0]
        mode = data[o + WORK + 0x200] if ver >= 3 else None
        idle = 0x238D <= pc <= 0x2392
        if idle:
            if cur:
                out.append(cur)
                cur = None
            continue
        if cur is None:
            cur = {"first": i, "last": i, "pcs": [], "mode": mode}
        cur["last"] = i
        cur["pcs"].append(pc)
    if cur:
        out.append(cur)
    return ver, n, out


def main():
    for d in sys.argv[1:]:
        ver, n, out = runs(d)
        total = sum(r["last"] - r["first"] + 1 for r in out)
        print(f"{d}: version {ver}, {n} frames, {len(out)} runs, "
              f"{total} frames not idle")
        for r in out:
            mode = "--" if r["mode"] is None else f"{r['mode']:02X}"
            pcs = " ".join(f"{p:04X}" for p in r["pcs"][:8])
            more = " ..." if len(r["pcs"]) > 8 else ""
            print(f"  {r['first']:6}-{r['last']:<6} len={len(r['pcs']):3} "
                  f"mode={mode} pc {pcs}{more}")


if __name__ == "__main__":
    main()
