#!/usr/bin/env python3
"""
The Admiralty stronghold's textures (1.30 round 7: Marineford / Enies Lobby, a white-and-blue naval citadel).

    py tools/texture_gen/gen_admiralty_textures.py

admiralty_stone   pale dressed ashlar, big courses, cool grey mortar (walls, towers, the keep)
admiralty_roof    dark-blue glazed tiles (tower caps, the keep's roofs, colonnade roofs)
admiralty_paving  large pale slabs with a darker border course (plazas, wall walks)
admiralty_banner  the Admiralty's banner: navy field, gold border, the white gull crest (one picture per banner)
"""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw

from gen_psx_textures import save, fbm, norm, ramp, pal, hexc, to_img


def gen_stone():
    rng = np.random.default_rng(3001)
    n = fbm(64, 4, 4, rng)
    grain = fbm(64, 16, 2, rng)
    rgb = ramp(norm(n * 0.7 + grain * 0.3), pal("b9bec6", "c6cbd2", "d1d5db", "dadde2", "e3e5e8"))
    mortar = hexc("8f96a2")
    bh = 16
    for r in range(4):
        y0 = r * bh
        rgb[y0] = mortar
        off = 0 if r % 2 == 0 else 16
        for x in range(off, 64 + off, 32):
            rgb[y0:y0 + bh, x % 64] = mortar
        for x in range(off - 32, 64, 32):
            s = rng.uniform(0.93, 1.05)
            xs = slice(max(0, x + 1), min(64, x + 32))
            rgb[y0 + 1:y0 + bh, xs] = np.clip(rgb[y0 + 1:y0 + bh, xs] * s, 0, 255)
        # a lit top edge and a shaded foot on each course
        rgb[y0 + 1] = np.clip(rgb[y0 + 1].astype(int) + 10, 0, 255)
        rgb[y0 + bh - 1] = np.clip(rgb[y0 + bh - 1].astype(int) - 14, 0, 255)
    for _ in range(18):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("a8aeb8")
    save(to_img(rgb), "admiralty_stone")


def gen_roof():
    rng = np.random.default_rng(3002)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    palette = pal("15213f", "1c2b52", "243766", "2d447a", "3a5490")
    n = fbm(64, 4, 3, rng)
    for y in range(64):
        for x in range(64):
            row = y // 8
            lx = (x + (4 if row % 2 else 0)) % 8
            curve = 1.0 - abs(lx - 3.5) / 4.0
            ly = (y % 8) / 8.0
            v = curve * 0.6 + n[y, x] * 0.25 + (1 - ly) * 0.15
            rgb[y, x] = palette[min(len(palette) - 1, int(v * len(palette)))]
        if y % 8 == 7:
            rgb[y] = hexc("0c1428")
    # the glaze's glints
    for _ in range(40):
        x, y = rng.integers(0, 64, 2)
        if y % 8 < 3:
            rgb[y, x] = hexc("6a86c0")
    save(to_img(rgb), "admiralty_roof")


def gen_paving():
    rng = np.random.default_rng(3003)
    n = fbm(64, 4, 3, rng)
    rgb = ramp(norm(n), pal("a9adb3", "b4b8be", "bec2c7", "c8cbcf"))
    joint = hexc("7b818b")
    # two big slabs a row, rows offset, 32 px = 1 m at the paving's uv
    for r in range(2):
        y0 = r * 32
        rgb[y0] = joint
        off = 0 if r == 0 else 16
        for x in range(off, 64 + off, 32):
            rgb[y0:y0 + 32, x % 64] = joint
        for x in range(off - 32, 64, 32):
            s = rng.uniform(0.92, 1.06)
            xs = slice(max(0, x + 1), min(64, x + 32))
            rgb[y0 + 1:y0 + 32, xs] = np.clip(rgb[y0 + 1:y0 + 32, xs] * s, 0, 255)
    for _ in range(26):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("969ba3")
    save(to_img(rgb), "admiralty_paving")


## The gull: wings spread in a shallow M, head and tail down the middle (x in -1..1, y up), as in the game's crest.
GULL = [(0.0, 0.30), (0.10, 0.40), (0.30, 0.52), (0.55, 0.60), (0.80, 0.56), (1.0, 0.44), (0.78, 0.40), (0.55, 0.38),
        (0.32, 0.26), (0.14, 0.12), (0.10, -0.10), (0.20, -0.36), (0.0, -0.26)]


def gull_points(cx, cy, s, sy=1.0):
    right = [(cx + x * s, cy - y * s * sy) for x, y in GULL]
    left = [(cx - x * s, cy - y * s * sy) for x, y in reversed(GULL[1:-1])]
    return right + left


def gen_banner():
    W, H = 64, 64
    img = Image.new("RGB", (W, H), hexc("1d2c5c"))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(3004)
    weave = (rng.random((H, W)) * 14).astype(int)
    px = img.load()
    for y in range(H):
        for x in range(W):
            r, g, b = px[x, y]
            k = weave[y, x] - 7
            px[x, y] = (max(0, r + k), max(0, g + k), max(0, b + k))
    gold = hexc("d6a93c")
    d.rectangle([2, 2, W - 3, H - 3], outline=gold)
    d.rectangle([4, 4, W - 5, H - 5], outline=hexc("9c7426"))
    # the ring behind the gull, then the gull (squashed: the banner stretches the picture tall)
    d.ellipse([12, 10, 51, 38], outline=gold, width=2)
    d.polygon(gull_points(32, 24, 22, 0.7), fill=hexc("eef0f4"), outline=hexc("b8bec8"))
    # a gold bar and the white stripe under it
    d.rectangle([10, 46, 53, 48], fill=gold)
    d.rectangle([10, 51, 53, 52], fill=hexc("d8dde6"))
    save(img, "admiralty_banner")


def gen_wanted():
    """Four wanted posters pinned edge to edge (notice boards, the barracks' walls): parchment, a dark WANTED bar, a
    portrait, the bounty's line of figures."""
    rng = np.random.default_rng(3005)
    img = Image.new("RGB", (64, 64), hexc("4a3a28"))
    d = ImageDraw.Draw(img)
    faces = ["8a6a50", "a07858", "6e5040", "b08868"]
    for i in range(4):
        x0 = (i % 2) * 32 + 1
        y0 = (i // 2) * 32 + 1
        d.rectangle([x0, y0, x0 + 29, y0 + 29], fill=hexc("d8c8a0"))
        d.rectangle([x0 + 3, y0 + 2, x0 + 26, y0 + 5], fill=hexc("3a2a1c"))
        d.rectangle([x0 + 6, y0 + 8, x0 + 23, y0 + 21], fill=hexc("b8a880"), outline=hexc("5a4a34"))
        d.ellipse([x0 + 10, y0 + 10, x0 + 19, y0 + 19], fill=hexc(faces[i]))
        d.rectangle([x0 + 9, y0 + 18, x0 + 20, y0 + 21], fill=hexc("5a4030"))
        for k in range(int(rng.integers(5, 9))):
            d.point((x0 + 5 + k * 2, y0 + 24), fill=hexc("3a2a1c"))
            d.point((x0 + 5 + k * 2, y0 + 25), fill=hexc("3a2a1c"))
        d.line([(x0 + 4, y0 + 27), (x0 + 25, y0 + 27)], fill=hexc("8a7a5a"))
    save(img, "admiralty_wanted")


if __name__ == "__main__":
    gen_stone()
    gen_roof()
    gen_paving()
    gen_banner()
    gen_wanted()
