#!/usr/bin/env python3
"""
Driftwake emblem: a sloop under sail on the sea, in a gilt-rimmed medallion.

Usage (from the project root):
    py tools/texture_gen/gen_icon.py              # writes assets/branding/*
    py tools/texture_gen/gen_icon.py --preview D  # also a zoomed contact sheet of every size in D
    py tools/texture_gen/gen_icon.py --dump 16    # print the spec drawn at 16 px as a grid (a start for hand-tuning)

Writes:
    assets/branding/icon.png         256 px master (project config/icon, the window and taskbar icon)
    assets/branding/icon.ico         16, 24, 32, 48, 64, 128, 256 (the exe icon, both exes)
    assets/branding/boot_splash.png  640x360: the emblem and the wordmark on deep teal (shown 2x)
    web/site/favicon.svg             the 16 px drawing as crisp SVG rects

Sizes 16 and 24 are hand-drawn grids; 32 and 64 are drawn from the shape spec below,
48 is 24 doubled, 128 and 256 are 64 at 2x and 4x (nearest-neighbour throughout).
"""
from __future__ import annotations

import math
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "branding")

# scripts/ui/ui_style.gd roles
CREAM = (0xF5, 0xE8, 0xC8)
CREAM_DIM = (0xDA, 0xCC, 0xA8)
TEAL_LIGHT = (0x65, 0xC9, 0xC0)
TEAL = (0x27, 0x7F, 0x89)
TEAL_DARK = (0x1D, 0x5E, 0x66)
CORAL = (0xF1, 0x7C, 0x62)
SUN = (0xF2, 0xC4, 0x5E)
GILT = (0xB8, 0x8A, 0x3A)
OUTLINE = (0x0C, 0x24, 0x27)

KEYS = {
    ".": None, "o": OUTLINE, "t": TEAL, "d": TEAL_DARK, "l": TEAL_LIGHT, "c": CREAM,
    "s": CREAM_DIM, "r": CORAL, "y": SUN, "g": GILT,
}

# Hand-drawn small sizes (same picture as the spec, re-placed pixel by pixel).
# 16 drops the gilt rim: the outline alone leaves room for the picture.
GRID_16 = [
    ".....oooooo.....",
    "...oottorrtoo...",
    "..otyttoctttto..",
    ".otyyysocctttto.",
    ".otyyssocccttto.",
    "ottysssoccccttto",
    "otttsssoccccttto",
    "ottssssoccccctto",
    "otsssssoccccccto",
    "ottoooooooooooto",
    "olrrrrrrrrrrrrlo",
    ".ocrrrrrrrrrrco.",
    ".olcooooooooclo.",
    "..ollcllllcllo..",
    "...ooddddddoo...",
    ".....oooooo.....",
]

GRID_24 = [
    "........oooooooo........",
    ".....ooooggggggoooo.....",
    "....oogggttorrrgggoo....",
    "...oogtttttoccttttgoo...",
    "..oogtttttsocccttttgoo..",
    ".oogyyyytssoccccttttgoo.",
    ".ogyyyyysssocccccttttgo.",
    ".ogyyyyssssocccccttttgo.",
    "oogyyyyssssocccccctttgoo",
    "ogttyysssssoccccccttttgo",
    "ogttttsssssoccccccctttgo",
    "ogtttssssssoccccccctttgo",
    "ogtttssssssoccccccctttgo",
    "ogtttttttttooooooootttgo",
    "ogttrrrrrrrrrrrrrrrrrtgo",
    "oogllrrrrrrrrrrrrrrrlgoo",
    ".oglllrrrrrrrrrrrrrllgo.",
    ".oglcllcclclclccccllcgo.",
    ".ooglldllllllldllldlgoo.",
    "..oogllllllllllllllgoo..",
    "...oogllldddllllddgoo...",
    "....oogggddddddgggoo....",
    ".....ooooggggggoooo.....",
    "........oooooooo........",
]


def _grid(rows: list[str]) -> Image.Image:
    n = len(rows)
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(rows):
        assert len(row) == n, f"row {y} is {len(row)} wide, not {n}"
        for x, ch in enumerate(row):
            col = KEYS[ch]
            if col is not None:
                px[x, y] = col + (255,)
    return im


# The shape spec, in 64-unit space (y down), sampled at pixel centres for any size.
HORIZON = 41.0


def _in_poly(x: float, y: float, pts: list[tuple[float, float]]) -> bool:
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def _curve(a, b, bulge: float, steps: int = 12) -> list[tuple[float, float]]:
    # a to b, bowed sideways by `bulge` (a filled sail's belly)
    (ax, ay), (bx, by) = a, b
    nx, ny = by - ay, -(bx - ax)
    ln = math.hypot(nx, ny)
    nx, ny = nx / ln, ny / ln
    return [(ax + (bx - ax) * t + nx * bulge * math.sin(math.pi * t),
             ay + (by - ay) * t + ny * bulge * math.sin(math.pi * t)) for t in (i / steps for i in range(steps + 1))]


MAINSAIL = [(33.5, 7.0)] + _curve((33.5, 7.0), (51.0, 36.0), 4.5)[1:] + [(33.5, 36.0)]
JIB = [(29.0, 10.0), (29.0, 36.0), (13.0, 36.0)] + _curve((13.0, 36.0), (29.0, 10.0), 3.0)[1:-1]
HULL = [(9.0, 37.0), (55.0, 38.5), (50.0, 46.0), (18.0, 46.0)]
PENNANT = [(32.5, 3.5), (42.0, 6.0), (32.5, 8.5)]


def _spec_colour(u: float, v: float):
    col = TEAL
    if (u - 15.0) ** 2 + (v - 19.5) ** 2 <= 7.5 ** 2:
        col = SUN
    if v >= HORIZON:
        col = TEAL_LIGHT
        depth = v - HORIZON
        band = depth + 1.6 * math.sin(u * 0.32 + depth * 0.4)
        if band > 8.0 and (band % 7.0) < 2.2:
            col = TEAL_DARK
        if depth > 15:
            col = TEAL_DARK
    if _in_poly(u, v, HULL):
        col = CORAL
        if v > 42.5:
            col = OUTLINE if v < 44.0 else CORAL
    if _in_poly(u, v, JIB):
        col = CREAM_DIM
    if _in_poly(u, v, MAINSAIL):
        col = CREAM
    if 30.0 <= u < 32.5 and 3.5 <= v < 37.5:
        col = OUTLINE
    if 31.0 <= u < 52.0 and 35.5 <= v < 37.5:
        col = OUTLINE
    if _in_poly(u, v, PENNANT):
        col = CORAL
    # bow wave and wake: foam where the hull meets the sea
    if 44.5 <= v < 47.5 and (u < 19.0 and u > 6.0 or u > 49.0 and u < 59.0):
        if (v - 44.5) < 1.5 + 1.5 * math.sin(u * 0.7):
            col = CREAM
    if 46.0 <= v < 48.0 and 18.0 <= u < 50.0:
        col = CREAM if int(u * 0.5) % 3 else TEAL_LIGHT
    return col


def _spec(n: int) -> Image.Image:
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    c = n / 2.0
    r_in = n / 2.0 - 1.0
    rim = max(1, n // 32)

    def inside(x, y):
        return (x + 0.5 - c) ** 2 + (y + 0.5 - c) ** 2 <= r_in ** 2

    for y in range(n):
        for x in range(n):
            if inside(x, y):
                u, v = (x + 0.5) * 64.0 / n, (y + 0.5) * 64.0 / n
                px[x, y] = _spec_colour(u, v) + (255,)
    def edge_dist(x, y):
        for d in range(1, rim + 1):
            if any(not inside(x + dx, y + dy) for dx in range(-d, d + 1) for dy in range(-d, d + 1)
                   if abs(dx) + abs(dy) <= d):
                return d
        return 0

    # gilt rim (a bright outer pixel when it's 2 wide), then the dark outline just outside the disc
    for y in range(n):
        for x in range(n):
            if inside(x, y):
                d = edge_dist(x, y)
                if d:
                    px[x, y] = (SUN if d == 1 and rim > 1 else GILT) + (255,)
    for y in range(n):
        for x in range(n):
            if not inside(x, y) and any(inside(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                px[x, y] = OUTLINE + (255,)
    return im


def _up(im: Image.Image, k: int) -> Image.Image:
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def sizes() -> dict[int, Image.Image]:
    g16, g24 = _grid(GRID_16), _grid(GRID_24)
    s32, s64 = _spec(32), _spec(64)
    return {16: g16, 24: g24, 32: s32, 48: _up(g24, 2), 64: s64, 128: _up(s64, 2), 256: _up(s64, 4)}


# 5x7 wordmark for the splash
FONT = {
    "D": ["1110.", "1..1.", "1...1", "1...1", "1...1", "1..1.", "1110."],
    "R": ["1111.", "1...1", "1...1", "1111.", "1.1..", "1..1.", "1...1"],
    "I": ["111", ".1.", ".1.", ".1.", ".1.", ".1.", "111"],
    "F": ["11111", "1....", "1....", "1111.", "1....", "1....", "1...."],
    "T": ["11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.."],
    "W": ["1...1", "1...1", "1...1", "1.1.1", "1.1.1", "11.11", "1...1"],
    "A": [".111.", "1...1", "1...1", "11111", "1...1", "1...1", "1...1"],
    "K": ["1...1", "1..1.", "1.1..", "11...", "1.1..", "1..1.", "1...1"],
    "E": ["11111", "1....", "1....", "1111.", "1....", "1....", "11111"],
}


def splash(emblem64: Image.Image) -> Image.Image:
    w, h = 640, 360
    im = Image.new("RGBA", (w, h), TEAL + (255,))
    em = _up(emblem64, 2)
    ey = 92
    im.alpha_composite(em, ((w - em.width) // 2, ey))
    word, k, gap = "DRIFTWAKE", 3, 1
    cols = sum(len(FONT[ch][0]) + gap for ch in word) - gap
    x0, y0 = (w - cols * k) // 2, ey + em.height + 22
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    cx = 0
    for ch in word:
        glyph = FONT[ch]
        for gy, row in enumerate(glyph):
            for gx, bit in enumerate(row):
                if bit == "1":
                    for yy in range(k):
                        for xx in range(k):
                            mp[x0 + (cx + gx) * k + xx, y0 + gy * k + yy] = 255
        cx += len(glyph[0]) + gap
    px = im.load()
    for y in range(h):
        for x in range(w):
            if mp[x, y]:
                continue
            if any(0 <= x + dx < w and 0 <= y + dy < h and mp[x + dx, y + dy]
                   for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)):
                px[x, y] = OUTLINE + (255,)
    for y in range(h):
        for x in range(w):
            if mp[x, y]:
                px[x, y] = (CREAM if (y - y0) < 4 * k else SUN) + (255,)
    return im


def favicon_svg(im: Image.Image) -> str:
    px = im.load()
    rects = []
    for y in range(im.height):
        x = 0
        while x < im.width:
            p = px[x, y]
            if p[3] == 0:
                x += 1
                continue
            run = 1
            while x + run < im.width and px[x + run, y] == p:
                run += 1
            rects.append(f'<rect x="{x}" y="{y}" width="{run}" height="1" fill="#{p[0]:02x}{p[1]:02x}{p[2]:02x}"/>')
            x += run
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" shape-rendering="crispEdges">'
            + "".join(rects) + "</svg>\n")


def dump(n: int) -> None:
    inv = {v: k for k, v in KEYS.items() if v}
    im = _spec(n)
    for y in range(n):
        print('    "' + "".join(inv[im.getpixel((x, y))[:3]] if im.getpixel((x, y))[3] else "."
                             for x in range(n)) + '",')


def main() -> None:
    if "--dump" in sys.argv:
        dump(int(sys.argv[sys.argv.index("--dump") + 1]))
        return
    os.makedirs(OUT, exist_ok=True)
    s = sizes()
    s[256].save(os.path.join(OUT, "icon.png"))
    order = [256, 128, 64, 48, 32, 24, 16]
    s[256].save(os.path.join(OUT, "icon.ico"), format="ICO", sizes=[(n, n) for n in order],
                append_images=[s[n] for n in order[1:]])
    splash(s[64]).save(os.path.join(OUT, "boot_splash.png"))
    with open(os.path.join(ROOT, "web", "site", "favicon.svg"), "w", encoding="utf-8", newline="\n") as f:
        f.write(favicon_svg(s[16]))
    if "--preview" in sys.argv:
        d = sys.argv[sys.argv.index("--preview") + 1]
        os.makedirs(d, exist_ok=True)
        sheet = Image.new("RGBA", (16 * 8 + 24 * 6 + 32 * 4 + 48 * 3 + 64 * 2 + 70, 260), (200, 200, 200, 255))
        x = 10
        for n, k in ((16, 8), (24, 6), (32, 4), (48, 3), (64, 2)):
            sheet.alpha_composite(_up(s[n], k), (x, 10))
            sheet.alpha_composite(s[n], (x, 160))
            x += n * k + 10
        sheet.save(os.path.join(d, "icon_sheet.png"))
        _up(s[256], 1).save(os.path.join(d, "icon_256.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
