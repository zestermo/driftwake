#!/usr/bin/env python3
"""
The desert theme's textures (scripts/island/themes/desert_theme.gd): its ground (dune sand, beach, cracked
hardpan, banded sandstone rock), its towns (adobe plaster, sandstone ashlar, glazed dome tiles, striped souk
awnings, rugs) and its plants (cactus skin, dry grass, reeds). 64x64, tileable, palette-quantized, fixed seeds,
the helpers from gen_psx_textures.py.

    py tools/texture_gen/gen_desert_textures.py
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from gen_psx_textures import save, fbm, norm, ramp, pal, hexc, to_img, periodic_noise  # noqa: E402


def _ripples(size: int, rng: np.random.Generator, waves: int, wobble: float) -> np.ndarray:
    """Wind ripples: a periodic sawtooth across x, bent by smooth noise (sharp crest, soft back)."""
    y, x = np.mgrid[0:size, 0:size] / size
    bend = periodic_noise(size, 4, rng) * wobble
    t = (x * waves + y * 1.0 + bend * waves) % 1.0
    return np.where(t < 0.25, t / 0.25, 1.0 - (t - 0.25) / 0.75)


def gen_desert_sand():
    rng = np.random.default_rng(7101)
    n = fbm(64, 4, 3, rng)
    r = _ripples(64, rng, 5, 0.12)
    v = norm(n * 0.55 + r * 0.3 + rng.random((64, 64)) * 0.15)
    rgb = ramp(v, pal("b88a4c", "c69a56", "d2a962", "dcb66e", "e5c27c", "eecd8c"))
    for _ in range(26):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("9c7240") if rng.random() < 0.6 else hexc("f6dca4")
    save(to_img(rgb), "desert_sand")


def gen_desert_beach():
    rng = np.random.default_rng(7102)
    n = fbm(64, 4, 3, rng) * 0.6 + rng.random((64, 64)) * 0.4
    rgb = ramp(norm(n), pal("cdb07c", "d8bd88", "e2c994", "ead3a0", "f1ddae"))
    for _ in range(36):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("a88a5c") if rng.random() < 0.5 else hexc("fbf0d0")
    save(to_img(rgb), "desert_beach")


def _cells(size: int, n: int, rng: np.random.Generator) -> tuple[np.ndarray, np.ndarray]:
    """Periodic Voronoi: distance to the nearest site and to the second nearest (edges where they meet)."""
    pts = rng.random((n, 2)) * size
    y, x = np.mgrid[0:size, 0:size]
    d1 = np.full((size, size), 1e9)
    d2 = np.full((size, size), 1e9)
    for px, py in pts:
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d = np.hypot(x - px - ox, y - py - oy)
                d2 = np.where(d < d1, d1, np.minimum(d2, d))
                d1 = np.minimum(d1, d)
    return d1, d2


def gen_desert_hardpan():
    """Pale baked clay and salt crust, cracked into plates (paths, plazas, salt flats)."""
    rng = np.random.default_rng(7103)
    d1, d2 = _cells(64, 34, rng)
    n = fbm(64, 4, 3, rng)
    plate = norm(n * 0.7 + norm(d1) * 0.15 + rng.random((64, 64)) * 0.15)
    rgb = ramp(plate, pal("cdb38c", "d5bd98", "dcc6a2", "e3cfac", "eadab8"))
    crack = (d2 - d1) < 0.7
    rgb[crack] = hexc("b09670")
    save(to_img(rgb), "desert_hardpan")


def gen_desert_rock():
    """Sandstone in ochre and rust bands, cracked: the ridges, mesas, cliffs and boulders."""
    rng = np.random.default_rng(7104)
    n = fbm(64, 4, 5, rng)
    y = np.arange(64)[:, None] / 64.0
    bands = (np.sin((y * 4.0 + periodic_noise(64, 4, rng) * 0.25) * np.pi * 2) + 1) * 0.5
    v = norm(n * 0.6 + bands * 0.4)
    rgb = ramp(v, pal("6e3f24", "84502c", "9a6236", "ad7442", "bf8850", "cf9c62"))
    cracks = np.abs(periodic_noise(64, 6, rng) - 0.5) < 0.018
    rgb[cracks] = hexc("4a2a18")
    save(to_img(rgb), "desert_rock")


def gen_adobe():
    """Smooth lime plaster over mud brick, near white so a house's colour comes from its tint."""
    rng = np.random.default_rng(7201)
    n = fbm(64, 4, 4, rng)
    stains = fbm(64, 2, 2, rng)
    v = norm(n * 0.5 + stains * 0.5)
    rgb = ramp(v, pal("d4ccbd", "dcd5c7", "e3ddd1", "eae5db", "f1ece3"))
    x, y = rng.integers(0, 56, 2)
    rgb[y:y + 3, x:x + 5] = hexc("c4a888")
    rgb[y + 1, x:x + 5] = hexc("b8987a")
    save(to_img(rgb), "adobe")


def gen_desert_flags():
    """Big irregular sandstone flags for a town's squares and streets, sand in the joints."""
    rng = np.random.default_rng(7204)
    d1, d2 = _cells(64, 10, rng)
    n = fbm(64, 4, 3, rng)
    v = norm(n * 0.6 + rng.random((64, 64)) * 0.2 + norm(d1) * 0.2)
    rgb = ramp(v, pal("c4a274", "cdad80", "d6b88c", "dec298", "e5cca4"))
    joint = (d2 - d1) < 1.4
    rgb[joint] = hexc("a8885c")
    save(to_img(rgb), "desert_flags")


def gen_sandstone():
    """Dressed sandstone blocks in courses (quays, palace walls, minarets, tombs)."""
    rng = np.random.default_rng(7202)
    n = fbm(64, 4, 4, rng)
    rgb = ramp(norm(n), pal("b08a5a", "bd9766", "c9a372", "d3ae7e", "dcb98a"))
    mortar = hexc("8a6a46")
    bh = 16
    for r in range(4):
        y0 = r * bh
        rgb[y0] = mortar
        off = 0 if r % 2 == 0 else 21
        for x in range(off, 64 + off, 42 if r % 2 == 0 else 32):
            rgb[y0:y0 + bh, x % 64] = mortar
        s = rng.uniform(0.9, 1.08)
        rgb[y0 + 1:y0 + bh] = np.clip(rgb[y0 + 1:y0 + bh] * s, 0, 255)
    for _ in range(18):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("9a764c")
    save(to_img(rgb), "sandstone")


def gen_glaze():
    """Glazed tiles for domes, near white (a dome's tint gives its gold, green, blue or rose), a star in each."""
    rng = np.random.default_rng(7203)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    base = ramp(norm(fbm(64, 4, 2, rng) * 0.5 + rng.random((64, 64)) * 0.5), pal("c8c8c8", "d6d6d6", "e2e2e2", "ececec"))
    rgb[:] = base
    for y in range(64):
        for x in range(64):
            lx, ly = x % 16, y % 16
            if lx == 0 or ly == 0:
                rgb[y, x] = hexc("6a6a6a")
            elif abs(lx - 8) + abs(ly - 8) in (3, 4):
                rgb[y, x] = hexc("9a9a9a")
            elif abs(lx - 8) + abs(ly - 8) < 2:
                rgb[y, x] = hexc("fafafa")
    save(to_img(rgb), "glaze")


def gen_awnings():
    """Striped souk canvas: madder red, indigo, saffron and leaf green on undyed cream."""
    for seed, a, b, name in [(7301, "a83a26", "e8dcc0", "awning_red"), (7302, "2e4a86", "e8dcc0", "awning_blue"),
                             (7303, "d49a28", "f0e6cc", "awning_gold"), (7304, "3e7a46", "e8dcc0", "awning_green")]:
        rng = np.random.default_rng(seed)
        n = rng.random((64, 64)) * 0.2
        rgb = np.zeros((64, 64, 3), dtype=np.uint8)
        for x in range(64):
            k = x % 16
            rgb[:, x] = hexc(a) if k < 6 else (hexc(b) if k < 14 else hexc(a))
        rgb = np.clip(rgb * (0.86 + n[..., None]), 0, 255).astype(np.uint8)
        rgb[::4] = (rgb[::4] * 0.92).astype(np.uint8)
        save(to_img(rgb), name)


def gen_rug():
    """A kilim: bands of lozenges in madder, indigo and saffron, a fringe of borders."""
    rng = np.random.default_rng(7401)
    cols = [hexc("8e2a1e"), hexc("c45a2a"), hexc("2a3a6e"), hexc("d8a838"), hexc("eadcc0"), hexc("3a2a22")]
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    for y in range(64):
        band = y // 16
        for x in range(64):
            lx, ly = x % 16, y % 16
            d = abs(lx - 8) + abs(ly - 8)
            if ly in (0, 15):
                c = cols[5]
            elif d < 3:
                c = cols[3]
            elif d < 5:
                c = cols[2 if band % 2 else 4]
            elif d < 7:
                c = cols[1]
            else:
                c = cols[0]
            rgb[y, x] = c
    rgb = np.clip(rgb * (0.88 + rng.random((64, 64, 1)) * 0.18), 0, 255).astype(np.uint8)
    save(to_img(rgb), "rug_kilim")


def gen_cactus():
    """Cactus skin: vertical ribs, light on the crests, spine dots down them."""
    rng = np.random.default_rng(7501)
    x = np.arange(64)[None, :]
    rib = (np.cos(x / 64.0 * np.pi * 2 * 8) + 1) * 0.5
    v = norm(np.repeat(rib, 64, axis=0) * 0.7 + fbm(64, 4, 3, rng) * 0.3)
    rgb = ramp(v, pal("2e4a26", "3a5a2e", "4a6c36", "5a7e40", "6e924c"))
    for y in range(2, 64, 5):
        for k in range(8):
            xx = int(k * 8 + 4 + (y // 5) % 2)
            rgb[y % 64, xx % 64] = hexc("e8dcb0")
    save(to_img(rgb), "cactus")


def gen_dry_grass():
    """Bleached tufts of desert grass (alpha cutout)."""
    W = 32
    rng = np.random.default_rng(7502)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    tans = pal("8a6e3a", "a08244", "b8984e", "ccae62", "dcc078")
    for _ in range(26):
        x0 = rng.integers(3, 29)
        h = rng.integers(8, 30)
        lean = rng.integers(-7, 8)
        c = tans[rng.integers(0, len(tans))]
        d.line([(x0, 31), (x0 + lean, 31 - h)], fill=c + (255,))
    save(img, "dry_grass")


def gen_reeds():
    """Tall green reeds with brown heads, for oasis pools and the wadi's damp bed (alpha cutout)."""
    W = 32
    rng = np.random.default_rng(7503)
    img = Image.new("RGBA", (W, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    greens = pal("3a5a26", "4a6e2c", "5a8034", "6e943e", "8aa64a")
    for _ in range(18):
        x0 = rng.integers(2, 30)
        h = rng.integers(30, 62)
        lean = rng.integers(-5, 6)
        c = greens[rng.integers(0, len(greens))]
        d.line([(x0, 63), (x0 + lean, 63 - h)], fill=c + (255,))
        if rng.random() < 0.45:
            tx, ty = x0 + lean, 63 - h
            d.rectangle([tx - 1, ty, tx, ty + 4], fill=hexc("6a4424") + (255,))
    save(img, "reeds")


def main():
    gen_desert_sand()
    gen_desert_beach()
    gen_desert_hardpan()
    gen_desert_rock()
    gen_adobe()
    gen_sandstone()
    gen_desert_flags()
    gen_glaze()
    gen_awnings()
    gen_rug()
    gen_cactus()
    gen_dry_grass()
    gen_reeds()


if __name__ == "__main__":
    main()
