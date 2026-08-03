#!/usr/bin/env python3
"""Generates the app icon PNG (no third-party imaging deps).

Draws a dark rounded-square-free 1024x1024 canvas with a `</>` glyph made of
simple line segments — iOS applies the mask, so the artwork is a flat square.
"""
import struct
import zlib
from pathlib import Path

SIZE = 1024
BG_TOP = (11, 15, 23)
BG_BOTTOM = (25, 36, 58)
ACCENT = (98, 180, 255)
ACCENT_2 = (195, 232, 141)


def blend(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def make_canvas():
    return [[blend(BG_TOP, BG_BOTTOM, y / (SIZE - 1)) for _ in range(SIZE)] for y in range(SIZE)]


def draw_line(px, x0, y0, x1, y1, color, width):
    """Anti-aliased-ish thick line via distance test on the bounding box."""
    dx, dy = x1 - x0, y1 - y0
    length2 = dx * dx + dy * dy
    if length2 == 0:
        return
    half = width / 2
    min_x = max(0, int(min(x0, x1) - half - 2))
    max_x = min(SIZE - 1, int(max(x0, x1) + half + 2))
    min_y = max(0, int(min(y0, y1) - half - 2))
    max_y = min(SIZE - 1, int(max(y0, y1) + half + 2))
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            t = ((x - x0) * dx + (y - y0) * dy) / length2
            t = max(0.0, min(1.0, t))
            px_, py_ = x0 + t * dx, y0 + t * dy
            dist = ((x - px_) ** 2 + (y - py_) ** 2) ** 0.5
            if dist <= half - 1:
                px[y][x] = color
            elif dist < half + 1:
                alpha = (half + 1 - dist) / 2
                px[y][x] = blend(px[y][x], color, alpha)


def write_png(path, pixels):
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for r, g, b in row:
            raw += bytes((r, g, b))

    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", header)
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    Path(path).write_bytes(png)


def main():
    px = make_canvas()
    w = 46
    # "<"
    draw_line(px, 390, 512, 250, 400, ACCENT, w)
    draw_line(px, 390, 512, 250, 624, ACCENT, w)
    # "/"
    draw_line(px, 590, 330, 434, 694, ACCENT_2, w)
    # ">"
    draw_line(px, 634, 512, 774, 400, ACCENT, w)
    draw_line(px, 634, 512, 774, 624, ACCENT, w)
    # caret underline
    draw_line(px, 300, 800, 724, 800, (60, 78, 105), 26)

    out = Path(__file__).resolve().parent.parent / "CodeForge/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    write_png(out, px)
    print(f"wrote {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
