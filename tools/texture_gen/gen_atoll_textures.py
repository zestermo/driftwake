#!/usr/bin/env python3
"""
The coral atoll's textures (docs/v1_28_plan.md "Islands"): bright coral sand, the islets' sandy turf, worn coral rock,
the lagoon's pale rippled floor, and its floor's cutout cards (beach grass, a white spider lily, sea grass). 64x64
(cards 32 or 64), tileable, palette-quantized, a fixed seed each, like gen_psx_textures.py (whose helpers this imports).

    py tools/texture_gen/gen_atoll_textures.py                 # all of them
    py tools/texture_gen/gen_atoll_textures.py atoll_sand      # just these (names below)
"""
from __future__ import annotations

import math
import sys

import numpy as np
from PIL import Image, ImageDraw

from gen_psx_textures import save, fbm, norm, ramp, pal, hexc, to_img, periodic_noise


def gen_atoll_sand():
    """Coral sand: near-white and warm, broken shell and coral grit in pink and cream, a darker wet grain here and there."""
    rng = np.random.default_rng(9401)
    n = fbm(64, 4, 3, rng) * 0.55 + rng.random((64, 64)) * 0.45
    rgb = ramp(norm(n), pal("cdbf9e", "d8cbab", "e2d6b8", "eae0c6", "f2ead4", "f8f2e2"))
    for _ in range(70):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = [hexc("e8b8a8"), hexc("f4d8c0"), hexc("b8a888"), hexc("ffffff")][rng.integers(0, 4)]
    for _ in range(8):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("9a8e74")
        rgb[y, (x + 1) % 64] = hexc("c8b8a0")
    save(to_img(rgb), "atoll_sand")


def gen_atoll_turf():
    """The islets' tops: coral sand half held by creeping beach vine and short grass, a fallen palm leaflet."""
    rng = np.random.default_rng(9402)
    n = fbm(64, 4, 4, rng) * 0.7 + rng.random((64, 64)) * 0.3
    rgb = ramp(norm(n), pal("5e7a3a", "6c8a42", "7c9a4a", "93a85e", "b8b886", "d6caa4"))
    sandy = norm(fbm(64, 8, 2, rng)) > 0.68
    rgb[sandy] = ramp(norm(fbm(64, 8, 2, rng))[sandy], pal("c8bc98", "d6caa8", "e2d8bc"))
    for _ in range(30):
        x, y = rng.integers(0, 64, 2)
        for k in range(rng.integers(2, 5)):
            rgb[(y - k) % 64, (x + k // 2) % 64] = hexc("4a6a2a")
    for _ in range(6):
        x, y = rng.integers(0, 64, 2)
        for k in range(6):
            rgb[y % 64, (x + k) % 64] = hexc("a89a5a")
    save(to_img(rgb), "atoll_turf")


def gen_atoll_coral():
    """Worn reef rock: pale coral limestone pitted with holes, pink coralline crust, a green weed stain low down."""
    rng = np.random.default_rng(9403)
    n = fbm(64, 4, 5, rng)
    rgb = ramp(norm(n), pal("8a8270", "9c9480", "aea690", "c0b8a2", "d0c8b2", "ddd6c2"))
    pits = norm(periodic_noise(64, 10, rng)) < 0.16
    rgb[pits] = hexc("5e5848")
    crust = norm(fbm(64, 8, 2, rng)) > 0.74
    rgb[crust] = ramp(norm(fbm(64, 8, 2, rng))[crust], pal("c08a8a", "d49c98", "e2b0a8"))
    weed = norm(fbm(64, 4, 3, rng)) < 0.2
    rgb[weed] = ramp(norm(fbm(64, 8, 2, rng))[weed], pal("6a7a4e", "7a8a5a"))
    save(to_img(rgb), "atoll_coral")


def gen_atoll_seafloor():
    """The lagoon's floor: the same coral sand as the beaches (atoll_sand's palette, so the waterline has no seam),
    laid in soft wave ripples with their shaded troughs, shell grit in the hollows (reads turquoise through the
    shallows; the grass, rubble and shells on it are meshes, AtollSeabed)."""
    rng = np.random.default_rng(9404)
    x = np.arange(64)[None, :] / 64.0
    y = np.arange(64)[:, None] / 64.0
    rip = np.sin((x * 4 + y * 1 + periodic_noise(64, 4, rng) * 0.45) * math.tau) * 0.5 + 0.5
    rip = rip ** 1.6
    n = fbm(64, 4, 3, rng) * 0.35 + rng.random((64, 64)) * 0.25 + rip * 0.4
    rgb = ramp(norm(n), pal("cdbf9e", "d8cbab", "e2d6b8", "eae0c6", "f2ead4", "f8f2e2"))
    for _ in range(50):
        px, py = rng.integers(0, 64, 2)
        if rip[py, px] < 0.35:
            rgb[py, px] = [hexc("e8b8a8"), hexc("b8a888"), hexc("ffffff"), hexc("f4d8c0")][rng.integers(0, 4)]
    save(to_img(rgb), "atoll_seafloor")


def gen_atoll_grass():
    """A cutout card: tufts of salt-tough beach grass, green to straw, a seed head or two."""
    rng = np.random.default_rng(9421)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    blades = pal("4e7a32", "5e8a3a", "6e9a44", "8aa856", "b8b072", "a8a060")
    for _ in range(24):
        x0 = rng.integers(3, 29)
        h = rng.integers(8, 28)
        lean = rng.integers(-6, 7)
        d.line([(x0, 31), (x0 + lean, 31 - h)], fill=blades[rng.integers(0, len(blades))] + (255,))
    for _ in range(3):
        x0 = rng.integers(6, 26)
        d.line([(x0, 31), (x0 + 2, 4)], fill=hexc("a89a5a") + (255,))
        d.ellipse([x0, 2, x0 + 3, 7], fill=hexc("c8b878") + (255,))
    save(img, "atoll_grass")


def gen_atoll_lily():
    """A cutout card: a beach spider lily, strap leaves fanned from the sand and white thread-petalled flowers."""
    rng = np.random.default_rng(9422)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(11):
        ang = math.radians(-160 + i * 14 + rng.uniform(-5, 5))
        L = rng.uniform(18, 32)
        d.line([(32, 63), (32 + math.cos(ang) * L, 63 + math.sin(ang) * L)], fill=pal("3e6e2e", "4a7e36", "5a8e40")[rng.integers(0, 3)] + (255,), width=3)
    for i in range(3):
        x = 32 + rng.uniform(-10, 10)
        y = rng.uniform(10, 22)
        d.line([(32, 62), (x, y + 6)], fill=hexc("5a8e40") + (255,), width=2)
        for k in range(6):
            a = math.radians(k * 60 + rng.uniform(-10, 10))
            d.line([(x, y + 4), (x + math.cos(a) * 8, y + 4 + math.sin(a) * 6)], fill=pal("f4f2ea", "ffffff", "e8e6dc")[k % 3] + (255,))
        d.ellipse([x - 2, y + 2, x + 2, y + 6], fill=hexc("f8f4e0") + (255,))
        d.point((x, y + 4), fill=hexc("d8c860") + (255,))
    save(img, "atoll_lily")


def gen_atoll_seagrass():
    """A cutout card: ribbons of sea grass for the lagoon's floor, swaying (drawn upright; the shader sways it)."""
    rng = np.random.default_rng(9423)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(14):
        x0 = rng.integers(3, 29)
        h = rng.integers(12, 30)
        bend = rng.uniform(-4, 4)
        pts = [(x0 + bend * math.sin(t / 6.0 * math.pi * 0.5) * (t / 6.0), 31 - h * t / 6.0) for t in range(7)]
        d.line(pts, fill=pal("3e6a3a", "4a7a44", "5a8a4e", "6e9a58")[rng.integers(0, 4)] + (255,), width=2)
    save(img, "atoll_seagrass")


ALL = {
    "atoll_sand": gen_atoll_sand, "atoll_turf": gen_atoll_turf, "atoll_coral": gen_atoll_coral, "atoll_seafloor": gen_atoll_seafloor,
    "atoll_grass": gen_atoll_grass, "atoll_lily": gen_atoll_lily, "atoll_seagrass": gen_atoll_seagrass,
}


def main():
    names = sys.argv[1:] or list(ALL)
    for n in names:
        ALL[n]()


if __name__ == "__main__":
    sys.exit(main())
