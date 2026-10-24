#!/usr/bin/env python3
"""
The fog isle theme's textures (docs/v1_20_plan.md): a haunted grey shore's ground (dead moor turf, black
mud, dark lichened rock, a grey shingle beach) and its floor's cutout cards (pale dead grass, grey-brown
withered bracken). 64x64 (cards 32 or 64), tileable, palette-quantized, a fixed seed each, like
gen_psx_textures.py (whose helpers this imports).

    py tools/texture_gen/gen_fog_textures.py             # all of them
    py tools/texture_gen/gen_fog_textures.py fog_moor    # just these (names below)
"""
from __future__ import annotations

import math
import sys

import numpy as np
from PIL import Image, ImageDraw

from gen_psx_textures import save, fbm, norm, ramp, pal, hexc, to_img, periodic_noise


def gen_fog_moor():
    """The fog isle's ground: dead grey-green turf and moss over black peat, pale withered blades, a bone-white fleck."""
    rng = np.random.default_rng(8601)
    n = fbm(64, 4, 4, rng)
    rgb = ramp(norm(n) * 0.99, pal("2a2c26", "343730", "3f4239", "4a4d42", "55574b", "5f6052"))
    for _ in range(70):
        x, y = rng.integers(0, 64, 2)
        for k in range(rng.integers(2, 5)):
            rgb[(y - k) % 64, (x + (k // 2) * (1 if rng.random() < 0.5 else -1)) % 64] = hexc("77786a") if rng.random() < 0.55 else hexc("6a6656")
    for _ in range(10):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("a9a79a")
    save(to_img(rgb), "fog_moor")


def gen_fog_mud():
    """Paths and the village: black wet mud, puddles catching the grey sky, footprints and ruts."""
    rng = np.random.default_rng(8602)
    n = fbm(64, 4, 4, rng) * 0.7 + rng.random((64, 64)) * 0.3
    x = np.arange(64)[None, :] / 64.0
    ruts = np.abs(np.sin((x * 2 + periodic_noise(64, 4, rng) * 0.3) * math.tau)) * 0.2
    rgb = ramp(norm(n + ruts), pal("1c1a18", "24221f", "2d2a26", "36332e", "403c36"))
    wet = norm(fbm(64, 4, 3, rng)) > 0.74
    rgb[wet] = ramp(norm(fbm(64, 8, 2, rng))[wet], pal("4a4e50", "585c5e", "666a6c"))
    for _ in range(20):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("6e6a62") if rng.random() < 0.5 else hexc("141210")
    save(to_img(rgb), "fog_mud")


def gen_fog_rock():
    """Dark slate for crags, cliffs and stones: near-black, cracked, grey-green lichen in patches, a white fleck or two."""
    rng = np.random.default_rng(8603)
    n = fbm(64, 4, 5, rng)
    rgb = ramp(norm(n), pal("26282a", "303234", "3a3c3e", "444648", "4e5052", "5a5c5e"))
    cracks = np.abs(periodic_noise(64, 8, rng) - 0.5) < 0.03
    rgb[cracks] = hexc("161718")
    lichen = norm(fbm(64, 4, 3, rng)) > 0.64
    rgb[lichen] = ramp(norm(fbm(64, 8, 2, rng))[lichen], pal("4a5248", "586052", "666e5e", "747a6a"))
    for _ in range(24):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("9a9c92") if rng.random() < 0.6 else hexc("b8b8ae")
    save(to_img(rgb), "fog_rock")


def gen_fog_beach():
    """A grey shingle strand: rounded grey and slate pebbles in grey sand, a pale shell, a strand of black weed."""
    rng = np.random.default_rng(8604)
    n = fbm(64, 4, 3, rng) * 0.6 + rng.random((64, 64)) * 0.4
    rgb = ramp(norm(n), pal("4e4e4a", "5a5a55", "666660", "72716a", "7e7c74"))
    for _ in range(90):
        x, y = rng.integers(0, 64, 2)
        c = [hexc("3a3b3c"), hexc("8a8a84"), hexc("56585a"), hexc("9c9a92")][rng.integers(0, 4)]
        for dy in range(2):
            for dx in range(2):
                rgb[(y + dy) % 64, (x + dx) % 64] = c
    for _ in range(6):
        x, y = rng.integers(0, 64, 2)
        for k in range(rng.integers(4, 9)):
            rgb[y % 64, (x + k) % 64] = hexc("1e2420")
            y += rng.integers(-1, 2)
    for _ in range(8):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("d0ccc0")
    save(to_img(rgb), "fog_beach")


def gen_fog_grass():
    """A cutout card: pale dead grass, bone and ash-coloured blades, a seed head or two."""
    rng = np.random.default_rng(8621)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    straw = pal("6e6c5e", "7e7c6c", "8e8a78", "9e9a88", "5e6052", "6a705e")
    for _ in range(24):
        x0 = rng.integers(4, 28)
        h = rng.integers(8, 28)
        lean = rng.integers(-6, 7)
        d.line([(x0, 31), (x0 + lean, 31 - h)], fill=straw[rng.integers(0, len(straw))] + (255,))
        if rng.random() < 0.2:
            d.point((x0 + lean, 31 - h), fill=hexc("b8b4a2") + (255,))
    save(img, "fog_grass")


def gen_fog_bracken():
    """A cutout card: withered bracken, grey-brown fronds curling over, a few black and broken."""
    rng = np.random.default_rng(8622)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(7):
        ang = math.radians(-160 + i * 23 + rng.uniform(-6, 6))
        L = rng.uniform(18, 28)
        x1 = 32 + math.cos(ang) * L
        y1 = 62 + math.sin(ang) * L + rng.uniform(0, 8)
        tones = [pal("3e3630", "4a423a", "564e44", "625a4e"), pal("4a4a40", "56564a", "626254", "6e6e5e"), pal("1e1c1a", "2a2724", "36322e", "423d38")][
            0 if rng.random() < 0.5 else (1 if rng.random() < 0.7 else 2)]
        d.line([(32, 62), (x1, y1)], fill=tones[0] + (255,))
        for t in np.linspace(0.15, 0.95, 9):
            px = 32 + (x1 - 32) * t
            py = 62 + (y1 - 62) * t
            s = (1 - t) * 5 + 1
            c = tones[rng.integers(1, len(tones))]
            d.line([(px, py), (px - s * math.sin(ang) * 0.9, py + s * math.cos(ang) * 0.9 + s * 0.4)], fill=c + (255,))
            d.line([(px, py), (px + s * math.sin(ang) * 0.9, py - s * math.cos(ang) * 0.9 + s * 0.4)], fill=c + (255,))
    save(img, "fog_bracken")


ALL = {
    "fog_moor": gen_fog_moor, "fog_mud": gen_fog_mud, "fog_rock": gen_fog_rock, "fog_beach": gen_fog_beach,
    "fog_grass": gen_fog_grass, "fog_bracken": gen_fog_bracken,
}


def main():
    names = sys.argv[1:] or list(ALL)
    for n in names:
        ALL[n]()


if __name__ == "__main__":
    sys.exit(main())
