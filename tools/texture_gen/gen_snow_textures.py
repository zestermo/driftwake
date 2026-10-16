#!/usr/bin/env python3
"""
The snow island theme's textures (docs/snow_island_plan.md): snow, trodden snow, ice, black
rock, the village's pink brick and green tier tiles, snow-laden pine needles, ice blocks for the
ruins, and the frozen undergrowth's cutout cards. 64x64, tileable, palette-quantized, a fixed
seed each, like gen_psx_textures.py (whose helpers this imports).

    py tools/texture_gen/gen_snow_textures.py            # all of them
    py tools/texture_gen/gen_snow_textures.py ice pine   # just these (names below)
"""
from __future__ import annotations

import math
import sys

import numpy as np
from PIL import Image, ImageDraw

from gen_psx_textures import save, fbm, norm, ramp, pal, hexc, to_img, periodic_noise

SNOW = pal("aebdd2", "bccadd", "c9d5e6", "d6e0ee", "e2eaf4", "eef3f9")


def gen_snow():
    """Wind-packed snow: soft blue-white swells, ripples along one way, a few sparkles."""
    rng = np.random.default_rng(7101)
    n = fbm(64, 4, 4, rng) * 0.75 + rng.random((64, 64)) * 0.12
    y = np.arange(64)[:, None] / 64.0
    ripple = np.sin((y * 6 + periodic_noise(64, 4, rng) * 1.4) * math.tau) * 0.08
    rgb = ramp(norm(n + ripple) * 0.85 + 0.15, SNOW)
    for _ in range(36):
        x, yy = rng.integers(0, 64, 2)
        rgb[yy, x] = hexc("ffffff") if rng.random() < 0.7 else hexc("9fb2cc")
    save(to_img(rgb), "snow")


def gen_snow_packed():
    """Trodden snow on paths and plazas: greyer, boot-worn ruts, grit and slush in them."""
    rng = np.random.default_rng(7102)
    n = fbm(64, 4, 4, rng) * 0.7 + rng.random((64, 64)) * 0.3
    x = np.arange(64)[None, :] / 64.0
    ruts = np.abs(np.sin((x * 3 + periodic_noise(64, 4, rng) * 0.4) * math.tau))
    v = norm(n) * 0.7 + ruts * 0.3
    rgb = ramp(v, pal("7f8a98", "929dab", "a5afbc", "b7c0cb", "c8d0da", "d6dde6"))
    for _ in range(40):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("5d5850") if rng.random() < 0.6 else hexc("e8eef5")
    save(to_img(rgb), "snow_packed")


def gen_ice():
    """Lake and glacier ice: cold cyan depths, pale streaks, white fracture lines."""
    rng = np.random.default_rng(7103)
    n = fbm(64, 2, 4, rng)
    streak = np.repeat(periodic_noise(64, 8, rng)[:, :1], 64, axis=1) * 0.3
    v = norm(n * 0.75 + streak)
    rgb = ramp(v, pal("4f7f9e", "5f90ae", "72a3bf", "88b6cf", "a2c9dd", "c2dceb"))
    cracks = np.abs(periodic_noise(64, 6, rng) - 0.5) < 0.022
    rgb[cracks] = hexc("e6f2fa")
    for _ in range(14):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("ffffff")
    save(to_img(rgb), "ice")


def gen_black_rock():
    """Dark basalt for cliffs and boulders: cold grey-black, cracks, frost in the hollows."""
    rng = np.random.default_rng(7104)
    n = fbm(64, 4, 5, rng)
    rgb = ramp(norm(n), pal("1e2126", "272b31", "30353c", "3a4048", "464c55", "545b65"))
    cracks = np.abs(periodic_noise(64, 8, rng) - 0.5) < 0.03
    rgb[cracks] = hexc("121418")
    frost = fbm(64, 8, 2, rng) > 0.68
    rgb[frost] = hexc("9eacbd")
    save(to_img(rgb), "black_rock")


def gen_brick_pink():
    """The village's round houses: rosy red and pink bricks in courses, pale mortar."""
    rng = np.random.default_rng(7105)
    n = fbm(64, 4, 3, rng)
    tones = [pal("8a3a34", "9a443c", "a84e44"), pal("b0625a", "be7068", "c97c72"), pal("a04840", "b0544a", "bb6056")]
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    rgb[:] = hexc("d9c7bb")
    bh = 8
    for r in range(64 // bh):
        y0 = r * bh
        off = 0 if r % 2 == 0 else 8
        for x0 in range(off - 16, 64, 16):
            tone = tones[rng.integers(0, len(tones))]
            for yy in range(y0 + 1, y0 + bh):
                for xx in range(x0 + 1, x0 + 16):
                    v = n[yy % 64, xx % 64] * 0.7 + rng.random() * 0.3
                    rgb[yy % 64, xx % 64] = tone[min(len(tone) - 1, int(v * len(tone)))]
    save(to_img(rgb), "brick_pink")


def gen_roof_green():
    """Tier roof tiles: rows of rounded moss-green tiles, a dark lip under each row."""
    rng = np.random.default_rng(7106)
    palette = pal("23412e", "2c5036", "365f3f", "416e47", "4e7e51", "5c8e5c")
    n = fbm(64, 4, 3, rng)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    for y in range(64):
        row = y // 8
        for x in range(64):
            lx = (x + (4 if row % 2 else 0)) % 8
            curve = 1.0 - abs(lx - 3.5) / 4.0
            ly = (y % 8) / 8.0
            v = curve * 0.55 + n[y, x] * 0.3 + (1 - ly) * 0.15
            rgb[y, x] = palette[min(len(palette) - 1, int(v * len(palette)))]
        if y % 8 == 7:
            rgb[y] = hexc("16291c")
    save(to_img(rgb), "roof_green")


def gen_pine_snow():
    """A pine tier from its top (v 0) to its drooping rim (v 1): snow lying on the upper
    half with a ragged lower edge, then dark blue-green needle sprays."""
    rng = np.random.default_rng(7107)
    needles = pal("10251f", "163128", "1c3c30", "234838", "2c5541")
    img = Image.new("RGB", (64, 64), needles[1])
    d = ImageDraw.Draw(img)
    for _ in range(260):
        x, y = rng.uniform(0, 64), rng.uniform(0, 64)
        a = math.pi / 2 + rng.uniform(-0.8, 0.8)
        L = rng.uniform(3, 7)
        c = needles[rng.integers(0, len(needles))]
        for dx in (-64, 0, 64):
            d.line([(x + dx, y), (x + dx + math.cos(a) * L, y + math.sin(a) * L)], fill=c)
    rgb = np.array(img)
    edge = 30 + periodic_noise(64, 8, rng)[0] * 16 + rng.random(64) * 4
    snow = norm(fbm(64, 4, 3, rng))
    for x in range(64):
        e = int(edge[x])
        for y in range(e):
            rgb[y, x] = SNOW[min(len(SNOW) - 1, int((0.45 + snow[y, x] * 0.55) * len(SNOW)))]
        rgb[e, x] = hexc("8796ab")
    save(to_img(rgb), "pine_snow")


def gen_ice_block():
    """Ruin towers' stacked blocks: big pale blue-grey ice-stone, frosted joints."""
    rng = np.random.default_rng(7108)
    n = fbm(64, 4, 4, rng)
    rgb = ramp(norm(n) * 0.8 + 0.2, pal("7d93a8", "8ea3b7", "9fb3c6", "b0c3d4", "c1d2e1", "d3e1ec"))
    joint = hexc("e8f0f7")
    shade = hexc("6c8297")
    for r in range(2):
        y0 = r * 32
        rgb[y0] = joint
        rgb[(y0 + 31) % 64] = shade
        off = 0 if r == 0 else 20
        for x in (off, off + 40):
            rgb[y0:y0 + 32, x % 64] = joint
            rgb[y0:y0 + 32, (x + 63) % 64] = shade
    for _ in range(18):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("f4f8fc")
    save(to_img(rgb), "ice_block")


def gen_frost_shrub():
    """A cutout card: a dark twiggy shrub, snow caught on its upper twigs."""
    rng = np.random.default_rng(7109)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stems = pal("2a2420", "362e28", "443a31")
    tips = []
    for _ in range(26):
        x, y = rng.uniform(22, 42), 63.0
        ang = rng.uniform(-1.0, 1.0) - math.pi / 2
        c = stems[rng.integers(0, len(stems))] + (255,)
        for _seg in range(rng.integers(4, 8)):
            L = rng.uniform(4, 8)
            nx, ny = x + math.cos(ang) * L, y + math.sin(ang) * L
            d.line([(x, y), (nx, ny)], fill=c, width=1)
            x, y = nx, ny
            ang += rng.uniform(-0.6, 0.6)
            if not (1 < x < 63 and 2 < y < 64):
                break
        tips.append((x, y))
    greens = pal("1d3a2e", "25473a", "2f5646")
    for _ in range(90):
        x, y = rng.normal(32, 11), rng.normal(36, 12)
        if 2 < x < 62 and 4 < y < 62:
            d.point((x, y), fill=greens[rng.integers(0, 3)] + (255,))
    for x, y in tips:
        d.ellipse([x - 2, y - 1, x + 2, y + 1], fill=hexc("e6edf6") + (255,))
    for _ in range(60):
        x, y = rng.normal(32, 12), rng.normal(22, 9)
        if 2 < x < 62 and 2 < y < 60:
            d.point((x, y), fill=SNOW[rng.integers(3, 6)] + (255,))
    save(img, "frost_shrub")


def gen_frost_grass():
    """A cutout card: pale dry grass poking through the snow, rimed at the tips."""
    rng = np.random.default_rng(7110)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    straw = pal("8a7e62", "9c8f70", "ada07f", "bfb391")
    for _ in range(20):
        x0 = rng.integers(4, 28)
        h = rng.integers(8, 26)
        lean = rng.integers(-5, 6)
        d.line([(x0, 31), (x0 + lean, 31 - h)], fill=straw[rng.integers(0, len(straw))] + (255,))
        d.point((x0 + lean, 31 - h), fill=hexc("eef3f9") + (255,))
    save(img, "frost_grass")


ALL = {
    "snow": gen_snow, "snow_packed": gen_snow_packed, "ice": gen_ice, "black_rock": gen_black_rock,
    "brick_pink": gen_brick_pink, "roof_green": gen_roof_green, "pine_snow": gen_pine_snow,
    "ice_block": gen_ice_block, "frost_shrub": gen_frost_shrub, "frost_grass": gen_frost_grass,
}


def main():
    names = sys.argv[1:] or list(ALL)
    for n in names:
        ALL[n]()


if __name__ == "__main__":
    sys.exit(main())
