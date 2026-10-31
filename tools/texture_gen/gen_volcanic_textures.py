#!/usr/bin/env python3
"""
The volcanic isle's textures (docs/volcanic_island_plan.md): grey ash over black ground, black sand, cinder paths,
basalt, a lava crust glowing in its cracks, dark slate roofs, and its floor's cutout cards (wiry ash grass, fire
lilies). 64x64 (cards 32 or 64), tileable, palette-quantized, a fixed seed each, like gen_psx_textures.py (whose
helpers this imports).

    py tools/texture_gen/gen_volcanic_textures.py                  # all of them
    py tools/texture_gen/gen_volcanic_textures.py volcanic_lava    # just these (names below)
"""
from __future__ import annotations

import math
import sys

import numpy as np
from PIL import Image, ImageDraw

from gen_psx_textures import save, fbm, norm, ramp, pal, hexc, to_img, periodic_noise


def gen_volcanic_ash():
    """The cone's and the wilds' ground: grey ash drifted over black cinder, a pale pumice fleck, a scorched blade."""
    rng = np.random.default_rng(9101)
    n = fbm(64, 4, 4, rng) * 0.75 + rng.random((64, 64)) * 0.25
    rgb = ramp(norm(n), pal("2c2a29", "383533", "44413e", "504c48", "5c5853", "68645e"))
    dark = norm(fbm(64, 8, 2, rng)) > 0.78
    rgb[dark] = hexc("1e1c1c")
    for _ in range(40):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("8a857c") if rng.random() < 0.7 else hexc("a39d92")
    for _ in range(14):
        x, y = rng.integers(0, 64, 2)
        for k in range(rng.integers(2, 4)):
            rgb[(y - k) % 64, x] = hexc("4a4430")
    save(to_img(rgb), "volcanic_ash")


def gen_volcanic_sand():
    """Black sand: fine glittering basalt grains, a grey streak where the sea left ash, a white shell bit."""
    rng = np.random.default_rng(9102)
    n = fbm(64, 4, 3, rng) * 0.5 + rng.random((64, 64)) * 0.5
    rgb = ramp(norm(n), pal("141416", "1c1c1f", "242428", "2c2c31", "36363b"))
    x = np.arange(64)[None, :] / 64.0
    streak = (np.sin((x * 2 + periodic_noise(64, 4, rng) * 0.4) * math.tau) > 0.85)
    rgb[streak] = hexc("3e3d3e")
    for _ in range(60):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("5a5a62") if rng.random() < 0.7 else hexc("7a7884")
    for _ in range(4):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("c8c2b4")
    save(to_img(rgb), "volcanic_sand")


def gen_volcanic_cinder():
    """Paths and the forge town's ground: trodden red-brown cinder and scoria, cart ruts, a glint of slag."""
    rng = np.random.default_rng(9103)
    n = fbm(64, 4, 4, rng) * 0.6 + rng.random((64, 64)) * 0.4
    x = np.arange(64)[None, :] / 64.0
    ruts = np.abs(np.sin((x * 2 + periodic_noise(64, 4, rng) * 0.3) * math.tau)) * 0.18
    rgb = ramp(norm(n + ruts), pal("2a1c18", "34231d", "3e2a22", "4a3328", "553b2e", "5e4234"))
    for _ in range(70):
        px, py = rng.integers(0, 64, 2)
        c = [hexc("1a1414"), hexc("6e4a38"), hexc("2a2a2e")][rng.integers(0, 3)]
        rgb[py, px] = c
        rgb[py, (px + 1) % 64] = c
    for _ in range(10):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("7a7c86")
    save(to_img(rgb), "volcanic_cinder")


def gen_volcanic_basalt():
    """Basalt for crags, cliffs and the cone's high flanks: near-black, columnar cracks, rusty iron stains, ash in the joints."""
    rng = np.random.default_rng(9104)
    n = fbm(64, 4, 5, rng)
    rgb = ramp(norm(n), pal("17171a", "1f1f23", "27272c", "303036", "3a3a40", "45454c"))
    x = np.arange(64)
    cols = (np.abs(((x[None, :] + (periodic_noise(64, 4, rng) * 6).astype(int)) % 16) - 8) < 1)
    rgb[cols] = hexc("0e0e10")
    cracks = np.abs(periodic_noise(64, 8, rng) - 0.5) < 0.025
    rgb[cracks] = hexc("0c0c0e")
    stain = norm(fbm(64, 4, 3, rng)) > 0.72
    rgb[stain] = ramp(norm(fbm(64, 8, 2, rng))[stain], pal("3a2620", "4a2e22", "5a3626"))
    for _ in range(26):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("6a6662")
    save(to_img(rgb), "volcanic_basalt")


def gen_volcanic_lava():
    """Lava: a dark crust broken into plates, the cracks between them glowing orange to yellow (the glow is the texture's
    own, scaled by the material's emission)."""
    rng = np.random.default_rng(9105)
    cells = periodic_noise(64, 6, rng)
    edge = np.abs(cells - 0.5)
    heat = norm(fbm(64, 4, 3, rng))
    glow = np.clip(1.0 - edge / 0.12, 0, 1) * (0.55 + 0.45 * heat)
    crust = ramp(norm(fbm(64, 8, 3, rng)), pal("2a1410", "3a1a12", "4a2214", "5e2c16"))
    hot = ramp(glow, pal("7a2a0c", "b8400e", "e0641a", "f89a2a", "ffd060"))
    rgb = np.where((glow > 0.18)[..., None], hot, crust)
    pools = norm(fbm(64, 4, 2, rng)) > 0.8
    rgb[pools] = ramp(norm(fbm(64, 8, 2, rng))[pools], pal("e86a1c", "f8902a", "ffb840", "ffdc78"))
    save(to_img(rgb), "volcanic_lava")


def gen_volcanic_slate():
    """The forge town's roofs: overlapping dark slate tiles, soot along the rows, an ochre rust streak."""
    rng = np.random.default_rng(9106)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    tones = pal("23252a", "2b2e34", "33363d", "3b3f46")
    for row in range(8):
        off = 4 if row % 2 else 0
        for col in range(8):
            c = np.array(tones[rng.integers(0, len(tones))], dtype=np.int32)
            y0, x0 = row * 8, (col * 8 + off) % 64
            for dy in range(8):
                for dx in range(8):
                    v = c + int(rng.integers(-4, 5))
                    if dy == 7 or dx == 0:
                        v = np.array(hexc("121316"))
                    rgb[y0 + dy, (x0 + dx) % 64] = np.clip(v, 0, 255)
    soot = norm(fbm(64, 4, 2, rng)) > 0.7
    rgb[soot] = (rgb[soot] * 0.7).astype(np.uint8)
    for _ in range(3):
        x = rng.integers(0, 64)
        for y in range(rng.integers(10, 30)):
            rgb[y, x] = hexc("5a3a22")
    save(to_img(rgb), "volcanic_slate")


def gen_volcanic_grass():
    """A cutout card: wiry ash grass, grey-green and straw blades dusted pale, a scorched black one."""
    rng = np.random.default_rng(9121)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    blades = pal("5a5c48", "6a6a52", "7a785e", "8a866a", "4a4a3c", "2a2624")
    for _ in range(22):
        x0 = rng.integers(4, 28)
        h = rng.integers(7, 26)
        lean = rng.integers(-5, 6)
        d.line([(x0, 31), (x0 + lean, 31 - h)], fill=blades[rng.integers(0, len(blades))] + (255,))
    save(img, "volcanic_grass")


def gen_volcanic_lily():
    """A cutout card: a fire lily, dark spiky leaves and orange-red trumpet flowers that grow in ash."""
    rng = np.random.default_rng(9122)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(9):
        ang = math.radians(-150 + i * 15 + rng.uniform(-5, 5))
        L = rng.uniform(16, 30)
        x1 = 32 + math.cos(ang) * L
        y1 = 62 + math.sin(ang) * L
        d.line([(32, 62), (x1, y1)], fill=pal("2e3a26", "3a4a2e", "465636")[rng.integers(0, 3)] + (255,), width=2)
    for i in range(4):
        x = 32 + rng.uniform(-12, 12)
        y = rng.uniform(8, 26)
        d.line([(32, 62), (x, y + 6)], fill=hexc("3a4a2e") + (255,))
        for k in range(5):
            a = math.radians(-90 + (k - 2) * 28)
            d.line([(x, y + 4), (x + math.cos(a) * 6, y + 4 + math.sin(a) * 7)], fill=pal("d8481c", "f06a1e", "f89a2a")[k % 3] + (255,), width=2)
        d.point((x, y + 3), fill=hexc("ffd060") + (255,))
    save(img, "volcanic_lily")


ALL = {
    "volcanic_ash": gen_volcanic_ash, "volcanic_sand": gen_volcanic_sand, "volcanic_cinder": gen_volcanic_cinder,
    "volcanic_basalt": gen_volcanic_basalt, "volcanic_lava": gen_volcanic_lava, "volcanic_slate": gen_volcanic_slate,
    "volcanic_grass": gen_volcanic_grass, "volcanic_lily": gen_volcanic_lily,
}


def main():
    names = sys.argv[1:] or list(ALL)
    for n in names:
        ALL[n]()


if __name__ == "__main__":
    sys.exit(main())
