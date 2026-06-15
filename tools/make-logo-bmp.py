#!/usr/bin/env python3
'Convert PNG to Rockchip U-Boot logo.bmp (480x272 grayscale, BMP3 top-down).'
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

TARGET_W = 480
TARGET_H = 272
MAX_BYTES = 391734
FILE_HEADER_SIZE = 14
DIB_HEADER_SIZE = 40
PIXEL_OFFSET = FILE_HEADER_SIZE + DIB_HEADER_SIZE
ROW_BYTES = ((TARGET_W * 3 + 3) // 4) * 4
PIXEL_BYTES = ROW_BYTES * TARGET_H
EXPECTED_SIZE = PIXEL_OFFSET + PIXEL_BYTES
BM_MAGIC = bytes.fromhex('424d')

def _load_image(path: Path):
    try:
        from PIL import Image
    except ImportError as exc:
        raise SystemExit('Pillow required: apt install python3-pil (WSL) or python3-pil on build host') from exc
    return Image.open(path).convert('RGBA')

def _letterbox_rgba(img, width: int, height: int):
    from PIL import Image
    src_w, src_h = img.size
    scale = min(width / src_w, height / src_h)
    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))
    resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (width, height), (0, 0, 0, 255))
    canvas.paste(resized, ((width - new_w) // 2, (height - new_h) // 2), resized)
    return canvas

def _rgba_to_gray_bytes(canvas) -> bytes:
    pixels = canvas.load()
    rows: list[bytes] = []
    for y in range(TARGET_H):
        row = bytearray()
        for x in range(TARGET_W):
            r, g, b, a = pixels[x, y]
            if a < 128:
                gray = 0
            else:
                gray = int(0.299 * r + 0.587 * g + 0.114 * b)
            row.extend((gray, gray, gray))
        pad = ROW_BYTES - len(row)
        if pad:
            row.extend(bytes(pad))
        rows.append(bytes(row))
    merged = bytearray()
    for chunk in rows:
        merged.extend(chunk)
    return bytes(merged)

PACK_I = chr(60) + chr(73)
PACK_HH = chr(60) + chr(72) + chr(72)
PACK_i = chr(60) + chr(105)
PACK_ii = chr(60) + chr(105) + chr(105)


def write_bmp(pixel_data: bytes, out_path: Path) -> None:
    if len(pixel_data) != PIXEL_BYTES:
        msg = 'Internal error: pixel block %s != %s' % (len(pixel_data), PIXEL_BYTES)
        raise SystemExit(msg)
    file_size = EXPECTED_SIZE
    if file_size > MAX_BYTES:
        raise SystemExit('BMP would be %s bytes, max %s' % (file_size, MAX_BYTES))
    header = bytearray()
    header.extend(BM_MAGIC)
    header.extend(struct.pack(PACK_I, file_size))
    header.extend(struct.pack(PACK_HH, 0, 0))
    header.extend(struct.pack(PACK_I, PIXEL_OFFSET))
    header.extend(struct.pack(PACK_I, DIB_HEADER_SIZE))
    header.extend(struct.pack(PACK_i, TARGET_W))
    header.extend(struct.pack(PACK_i, -TARGET_H))
    header.extend(struct.pack(PACK_HH, 1, 24))
    header.extend(struct.pack(PACK_I, 0))
    header.extend(struct.pack(PACK_I, PIXEL_BYTES))
    header.extend(struct.pack(PACK_ii, 2835, 2835))
    header.extend(struct.pack(PACK_I, 0))
    header.extend(struct.pack(PACK_I, 0))
    if len(header) != PIXEL_OFFSET:
        raise SystemExit('Header size %s != %s' % (len(header), PIXEL_OFFSET))
    out_path.write_bytes(bytes(header) + pixel_data)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('input', type=Path, help='Source PNG')
    ap.add_argument('output', type=Path, help='Output logo.bmp')
    args = ap.parse_args()
    img = _load_image(args.input)
    canvas = _letterbox_rgba(img, TARGET_W, TARGET_H)
    pixel_data = _rgba_to_gray_bytes(canvas)
    write_bmp(pixel_data, args.output)
    out_size = args.output.stat().st_size
    print('Wrote %s (%sx%s, %s bytes, Pillow)' % (args.output, TARGET_W, TARGET_H, out_size))
    if out_size != EXPECTED_SIZE:
        raise SystemExit('Unexpected size %s, expected %s' % (out_size, EXPECTED_SIZE))
    return 0


if __name__ == '__main__':
    sys.exit(main())
