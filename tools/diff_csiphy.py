#!/usr/bin/env python3
import sys
import struct

def section_name(offset):
    if offset < 0x200: return "Lane 0"
    if offset < 0x400: return "Lane 1"
    if offset < 0x600: return "Lane 2"
    if offset < 0x700: return "Lane 3"
    if offset < 0x800: return "Clk Lane"
    if offset < 0x900: return "Common/Ctrl"
    if offset < 0xa00: return "Top/Misc 1"
    if offset < 0xb00: return "Top/Misc 2"
    return "Top/Misc 3"

def main():
    if len(sys.argv) < 3:
        print("Usage: diff_csiphy.py <csiphy1.bin> <csiphy4.bin>")
        sys.exit(1)

    with open(sys.argv[1], "rb") as f1, open(sys.argv[2], "rb") as f2:
        d1 = f1.read(0x1000)
        d2 = f2.read(0x1000)

    u1 = struct.unpack(f"<{len(d1)//4}I", d1)
    u2 = struct.unpack(f"<{len(d2)//4}I", d2)

    diffs = 0
    print(f"{'Offset':<8} {'Section':<12} {'CSIPHY1 (rear)':<16} {'CSIPHY4 (front)':<16}")
    print("-" * 55)
    for i in range(min(len(u1), len(u2))):
        off = i * 4
        if u1[i] != u2[i]:
            diffs += 1
            print(f"0x{off:03x}    {section_name(off):<12} 0x{u1[i]:08x}       0x{u2[i]:08x}")

    print("-" * 55)
    print(f"Total differences: {diffs} / {min(len(u1), len(u2))} registers")

if __name__ == "__main__":
    main()
