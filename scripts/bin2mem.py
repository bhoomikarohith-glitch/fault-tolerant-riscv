#!/usr/bin/env python3
"""bin2mem.py - convert a raw program image into a $readmemh file   (row 20)

The compiler produces raw bytes (a .bin file). The memories load their
contents with $readmemh, which expects text: one hex word per line.
This script does that conversion:

    bytes 13 01 50 00  ->  line "00500113"   (one 32-bit instruction)

RISC-V is little-endian: the first byte in the file is the LEAST significant
byte of the word, so each group of 4 bytes is read with 'little'.

Usage: python3 scripts/bin2mem.py input.bin output.mem
"""
import sys


def main() -> None:
    if len(sys.argv) != 3:                  # need exactly two file names
        sys.exit(__doc__)
    data = open(sys.argv[1], "rb").read()   # read all bytes
    data += b"\x00" * (-len(data) % 4)      # pad with zeros to a whole word
    with open(sys.argv[2], "w") as out:
        for i in range(0, len(data), 4):    # step through 4 bytes at a time
            word = int.from_bytes(data[i:i + 4], "little")
            out.write(f"{word:08x}\n")      # 8 hex digits, then newline


if __name__ == "__main__":
    main()
