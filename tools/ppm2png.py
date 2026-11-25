#!/usr/bin/env python3
"""
ppm2png.py -- mengubah gambar PPM (dari simulasi atau F12 di versi PC) menjadi PNG.
Tanpa pustaka tambahan; gambar diperbesar agar mudah dilihat.

Pemakaian:
    python3 tools/ppm2png.py build/frame.ppm build/frame.png [skala]
"""
import struct
import sys
import zlib


def read_ppm(path):
    data = open(path, "rb").read()
    tokens, pos = [], 0
    while len(tokens) < 4:
        while data[pos:pos + 1].isspace():
            pos += 1
        if data[pos:pos + 1] == b"#":
            while data[pos:pos + 1] not in (b"\n", b""):
                pos += 1
            continue
        start = pos
        while not data[pos:pos + 1].isspace():
            pos += 1
        tokens.append(data[start:pos])
    magic, w, h, maxval = tokens[0], int(tokens[1]), int(tokens[2]), int(tokens[3])
    pos += 1
    if magic == b"P6":
        px = data[pos:pos + w * h * 3]
    elif magic == b"P3":
        vals = [int(v) for v in data[pos:].split()]
        px = bytes(v * 255 // maxval for v in vals[:w * h * 3])
    else:
        sys.exit("format tidak didukung: " + magic.decode())
    return w, h, px


def write_png(path, w, h, px, scale):
    raw = bytearray()
    for y in range(h):
        row = bytearray()
        for x in range(w):
            row += px[(y * w + x) * 3:(y * w + x) * 3 + 3] * scale
        for _ in range(scale):
            raw += b"\0" + row

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w * scale, h * scale, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(path, "wb").write(png)


def main():
    if len(sys.argv) < 3:
        sys.exit("pemakaian: ppm2png.py <masukan.ppm> <keluaran.png> [skala]")
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    w, h, px = read_ppm(sys.argv[1])
    write_png(sys.argv[2], w, h, px, scale)
    print(f"{sys.argv[2]}: {w * scale}x{h * scale}")


if __name__ == "__main__":
    main()
