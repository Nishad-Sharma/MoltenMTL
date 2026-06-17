#!/usr/bin/env python3
"""Convert a binary (P6) PPM to PNG using only the Python standard library."""
import sys, struct, zlib


def read_p6(path):
    with open(path, "rb") as f:
        data = f.read()
    # Parse header: magic, width, height, maxval, then raw bytes.
    tokens = []
    i = 0
    while len(tokens) < 4:
        # skip whitespace
        while i < len(data) and data[i] in b" \t\r\n":
            i += 1
        # skip comments
        if i < len(data) and data[i:i+1] == b"#":
            while i < len(data) and data[i] not in b"\r\n":
                i += 1
            continue
        start = i
        while i < len(data) and data[i] not in b" \t\r\n":
            i += 1
        tokens.append(data[start:i])
    magic, width, height, maxval = tokens
    assert magic == b"P6", "only binary P6 PPM supported"
    i += 1  # single whitespace separator after maxval
    width, height = int(width), int(height)
    pixels = data[i:i + width * height * 3]
    return width, height, pixels


def write_png(path, width, height, rgb):
    def chunk(tag, payload):
        c = tag + payload
        return struct.pack(">I", len(payload)) + c + struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)

    # Add a filter byte (0 = none) at the start of each scanline.
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        raw += rgb[y * stride:(y + 1) * stride]

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit, truecolor
    idat = zlib.compress(bytes(raw), 9)
    with open(path, "wb") as f:
        f.write(sig)
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", idat))
        f.write(chunk(b"IEND", b""))


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    w, h, px = read_p6(src)
    write_png(dst, w, h, px)
    print(f"wrote {dst} ({w}x{h})")
