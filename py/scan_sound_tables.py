"""List the envelope types and song commands the ROM's sound tables use.

Usage: python3 py/scan_sound_tables.py [ROM]

ROM defaults to build/mspac.bin (the mapped $0000-$9FFF image). Addresses
and the song byte format follow idiom/sound.c:

  effects  8-byte entries, one per request bit, copied to channel +3..+10.
           Entry byte 6 is the volume; its top nibble is the envelope type.
  songs    four pointers per channel (bit 0, then the three intermission
           tunes). Bytes below $F0 are notes. $F0 jumps to the next word;
           $F1-$F4 take one argument ($F4 sets the envelope type); $F5-$FE
           do nothing; $FF ends the song, but the bytes after it still run
           until the next note.
  scripts  cutscene sets of six script pointers at $81F0 (idiom/cutscene.c).
           Command $F5 stores its argument as the channel 3 effect bits,
           so those arguments are the only other source of effect requests.
"""
import sys

EFFECTS = {"ch1": 0x3B30, "ch2": 0x3B40, "ch3": 0x3B80}
SONGS = {"ch1": 0x9685, "ch2": 0x967D, "ch3": 0x968D}
NOTE_DURATIONS = 0x3BB0
SCRIPTS = 0x81F0
SCRIPT_SETS = {"act 1": 0x00, "act 2": 0x0C, "act 3": 0x18,
               "walk blinky": 0x24, "walk pinky": 0x30, "walk inky": 0x3C,
               "walk sue": 0x48, "walk ms pac": 0x54}
# Bytes per script command; anything not listed runs as MOVE (4 bytes).
SCRIPT_LEN = {0xF1: 3, 0xF2: 2, 0xF3: 3, 0xF5: 2, 0xF6: 1, 0xF7: 1, 0xF8: 1}


def rom16(rom, a):
    return rom[a] | (rom[a + 1] << 8)


def scan_effects(rom):
    print("effects (bit: type, entry bytes)")
    types = {}
    for ch, base in EFFECTS.items():
        for bit in range(8):
            a = base + 8 * bit
            entry = rom[a:a + 8]
            t = entry[6] >> 4
            note = ""
            if a + 8 > NOTE_DURATIONS and a < NOTE_DURATIONS + 0x18:
                note = "  (overlaps the note tables)"
            sweep = "back+forth" if entry[3] & 0x80 else "one way   "
            reps = entry[5] or "forever"
            print(f"  {ch} bit {bit} @{a:04X}: type {t:2d}  {sweep}  repeats {reps!s:7s}"
                  f"  {entry.hex(' ')}{note}")
            types.setdefault(t, []).append(f"{ch}.{bit}")
    return types


def walk_song(rom, start):
    """Return (types set by $F4, commands seen, jump targets)."""
    types, cmds, jumps = set(), set(), []
    seen = set()
    p = start
    ended = False
    while p not in seen and len(seen) < 4096:
        seen.add(p)
        op = rom[p]
        p += 1
        if op < 0xF0:
            if ended:
                break
            continue
        cmds.add(op)
        if op == 0xF0:
            target = rom16(rom, p)
            jumps.append(target)
            p = target
        elif op in (0xF1, 0xF2, 0xF3):
            p += 1
        elif op == 0xF4:
            types.add(rom[p])
            p += 1
        elif op == 0xFF:
            ended = True
    return types, cmds, jumps


def scan_songs(rom):
    print("songs (channel, slot: start, types, commands)")
    types = {}
    for ch, table in SONGS.items():
        for slot in range(4):
            start = rom16(rom, table + 2 * slot)
            t, cmds, jumps = walk_song(rom, start)
            names = " ".join(f"{c:02X}" for c in sorted(cmds))
            extra = f"  jumps to {' '.join(f'{j:04X}' for j in jumps)}" if jumps else ""
            print(f"  {ch} slot {slot} @{start:04X}: types {sorted(t)}  cmds {names}{extra}")
            for x in t:
                types.setdefault(x, []).append(f"{ch}.{slot}")
    return types


def scan_scripts(rom):
    print("cutscene $F5 arguments (channel 3 effect bits)")
    bits = 0
    for name, off in SCRIPT_SETS.items():
        args = []
        for actor in range(6):
            p = rom16(rom, SCRIPTS + off + 2 * actor)
            for _ in range(2048):
                op = rom[p]
                if op == 0xFF:
                    break
                if op == 0xF5:
                    args.append(rom[p + 1])
                    bits |= rom[p + 1]
                p += SCRIPT_LEN.get(op, 4)
        print(f"  {name:12s}: {' '.join(f'{a:02X}' for a in args) or '-'}")
    print(f"  bits ever set: {bits:08b}")
    return bits


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "build/mspac.bin"
    with open(path, "rb") as f:
        rom = f.read()
    eff = scan_effects(rom)
    print()
    song = scan_songs(rom)
    print()
    scan_scripts(rom)
    print()
    print("envelope types used:")
    for t in range(16):
        users = eff.get(t, []) + song.get(t, [])
        print(f"  {t:2d}: {', '.join(users) if users else '-'}")


if __name__ == "__main__":
    main()
