#!/usr/bin/env python3
"""Convert a raw .bin image into a $readmemh-compatible .hex file.

Each output line is one 32-bit word (8 hex digits), reassembled from 4
little-endian bytes of the input (RISC-V is little-endian). The input is
zero-padded to a multiple of 4 bytes if needed.
"""
import os
import sys


def bin2hex(in_path, out_path):
    with open(in_path, "rb") as f:
        data = f.read()

    data += b"\x00" * ((-len(data)) % 4)

    with open(out_path, "w") as f:
        for i in range(0, len(data), 4):
            b0, b1, b2, b3 = data[i:i + 4]
            f.write("%02x%02x%02x%02x\n" % (b3, b2, b1, b0))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} input.bin")
    in_path = sys.argv[1]
    out_path = os.path.splitext(in_path)[0] + ".hex"
    bin2hex(in_path, out_path)
