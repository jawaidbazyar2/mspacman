"""Check ArcadeToScreen's lookup tables against the arithmetic they replace.

Usage: python3 py/check_arcade_to_screen.py [--bin build/iigs/lower_host.bin]

Reads ArcTileX / ArcSubX / ArcTileY / ArcSubY from iigs/actor_publish.s,
checks R_X and R_Y for every arcade x and y byte against the old
tile*6 + ASR(sub*6, 3) code, and with --bin checks that the assembled
host image holds the same table bytes.
"""
import argparse
import re
import struct
import sys

SRC = "iigs/actor_publish.s"
SPR_BASE_X, SPR_BASE_Y, SPR_Y_LIMIT = 72, 4, 189
NAMES = ("ArcTileX", "ArcSubX", "ArcTileY", "ArcSubY")


def tables(path):
    out, cur = {}, None
    for line in open(path):
        m = re.match(r"(\w+)?\s+dw\s+(.*?)(\s*;.*)?$", line)
        if not m:
            cur = None
            continue
        if m.group(1):
            cur = m.group(1)
            out[cur] = []
        if cur:
            out[cur] += [int(v) for v in m.group(2).split(",")]
    return {n: out[n] for n in NAMES}


def asr3(v):
    return v >> 3  # Python >> on negatives is arithmetic


def old_x(ax):
    t = (27 - (((ax >> 3) - 2) & 0xFF)) & 0xFF
    return (t * 6 + SPR_BASE_X + asr3((4 - (ax & 7)) * 6)) & 0xFFFF


def old_y(ay):
    if ay >> 3 == 0:
        return SPR_Y_LIMIT
    return (((ay >> 3) - 1) * 6 + SPR_BASE_Y + asr3(((ay & 7) - 4) * 6)) & 0xFFFF


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bin")
    args = ap.parse_args()
    t = tables(SRC)
    bad = 0
    for v in range(256):
        nx = (t["ArcTileX"][v >> 3] + t["ArcSubX"][v & 7]) & 0xFFFF
        ny = SPR_Y_LIMIT if v >> 3 == 0 else (t["ArcTileY"][v >> 3] + t["ArcSubY"][v & 7]) & 0xFFFF
        if nx != old_x(v):
            print(f"x={v:#04x}: table {nx} old {old_x(v)}")
            bad += 1
        if ny != old_y(v):
            print(f"y={v:#04x}: table {ny} old {old_y(v)}")
            bad += 1
    if args.bin:
        img = open(args.bin, "rb").read()
        words = [w & 0xFFFF for n in NAMES for w in t[n]]
        blob = struct.pack(f"<{len(words)}H", *words)
        if img.find(blob) < 0:
            print(f"{args.bin}: the tables are not in the image as written")
            bad += 1
    if bad:
        sys.exit(1)
    print("ArcadeToScreen tables: ok (256 x, 256 y" + (", image" if args.bin else "") + ")")


if __name__ == "__main__":
    main()
