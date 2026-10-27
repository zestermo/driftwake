#!/usr/bin/env python3
"""
Driftwake PSX texture generator.

Generates small, tileable, palette-quantized pixel textures in the spirit of
PS1-era games. Every texture is deterministic (fixed seeds), so re-running the
script reproduces the same files.

Usage (from the project root):
    pip install numpy pillow
    python tools/texture_gen/gen_psx_textures.py

Output: assets/textures/psx/*.png
Tweak the palettes / parameters below and re-run to restyle the island.

A theme's textures live in their own generator (tools/texture_gen/gen_<theme>_textures.py) that
imports the helpers from here (from gen_psx_textures import save, fbm, norm, ramp, pal, hexc,
to_img, periodic_noise, planks) and runs on its own; nothing here runs on import.
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "psx")


# --------------------------------------------------------------------------
# Noise helpers (all periodic so textures tile seamlessly)
# --------------------------------------------------------------------------
def periodic_noise(size: int, cells: int, rng: np.random.Generator) -> np.ndarray:
    """Smooth value noise that tiles. size x size, `cells` lattice cells across."""
    grid = rng.random((cells, cells))
    coords = np.arange(size) * cells / size
    i0 = np.floor(coords).astype(int)
    f = coords - i0
    f = f * f * (3 - 2 * f)  # smoothstep
    i1 = (i0 + 1) % cells
    i0 = i0 % cells
    # rows (y) then cols (x)
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fx = f[None, :]
    fy = f[:, None]
    top = a * (1 - fx) + b * fx
    bot = c * (1 - fx) + d * fx
    return top * (1 - fy) + bot * fy


def fbm(size: int, base_cells: int, octaves: int, rng: np.random.Generator, gain=0.5) -> np.ndarray:
    out = np.zeros((size, size))
    amp = 1.0
    total = 0.0
    cells = base_cells
    for _ in range(octaves):
        if cells > size:
            break
        out += periodic_noise(size, cells, rng) * amp
        total += amp
        amp *= gain
        cells *= 2
    return out / total


def norm(a: np.ndarray) -> np.ndarray:
    lo, hi = a.min(), a.max()
    return (a - lo) / (hi - lo + 1e-9)


def ramp(values: np.ndarray, palette: list[tuple[int, int, int]]) -> np.ndarray:
    """Map 0..1 values onto a discrete palette (hard steps = PSX look)."""
    pal = np.array(palette, dtype=np.uint8)
    idx = np.clip((values * len(pal)).astype(int), 0, len(pal) - 1)
    return pal[idx]


def to_img(rgb: np.ndarray, alpha: np.ndarray | None = None) -> Image.Image:
    if alpha is None:
        return Image.fromarray(rgb.astype(np.uint8), "RGB")
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb.astype(np.uint8), a]), "RGBA")


def save(img: Image.Image, name: str) -> None:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    img.save(path)
    print("  wrote", os.path.relpath(path, ROOT), img.size)


def hexc(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def pal(*hexes: str) -> list[tuple[int, int, int]]:
    return [hexc(h) for h in hexes]


# --------------------------------------------------------------------------
# Ground textures
# --------------------------------------------------------------------------
def gen_grass():
    rng = np.random.default_rng(101)
    n = fbm(64, 4, 4, rng) * 0.7 + rng.random((64, 64)) * 0.3
    rgb = ramp(norm(n), pal("2b4a1c", "35591f", "3f6823", "4a7628", "58862e", "6a9636"))
    # blade specks
    for _ in range(120):
        x, y = rng.integers(0, 64, 2)
        h = rng.integers(2, 4)
        c = hexc("7aa63e") if rng.random() < 0.6 else hexc("2a4419")
        for k in range(h):
            rgb[(y - k) % 64, x] = c
    save(to_img(rgb), "grass")


def gen_sand():
    rng = np.random.default_rng(202)
    n = fbm(64, 4, 3, rng) * 0.6 + rng.random((64, 64)) * 0.4
    rgb = ramp(norm(n), pal("a8925e", "b8a16a", "c4ae76", "cfb982", "dac590"))
    for _ in range(40):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("8a7448") if rng.random() < 0.5 else hexc("eee0b0")
    save(to_img(rgb), "sand")


def gen_wet_sand():
    rng = np.random.default_rng(203)
    n = fbm(64, 4, 3, rng) * 0.6 + rng.random((64, 64)) * 0.4
    rgb = ramp(norm(n), pal("6b5c3c", "776746", "83724f", "8e7d58"))
    save(to_img(rgb), "wet_sand")


def gen_dirt():
    rng = np.random.default_rng(303)
    n = fbm(64, 4, 4, rng) * 0.7 + rng.random((64, 64)) * 0.3
    rgb = ramp(norm(n), pal("4a3420", "583e26", "664a2d", "735535", "80603d"))
    # pebbles
    for _ in range(28):
        x, y = rng.integers(0, 64, 2)
        c = hexc("8e7f6a") if rng.random() < 0.5 else hexc("6e6252")
        rgb[y, x] = c
        rgb[y, (x + 1) % 64] = c
        rgb[(y + 1) % 64, x] = hexc("3a2a1a")
    save(to_img(rgb), "dirt")


def gen_rock():
    rng = np.random.default_rng(404)
    n = fbm(64, 4, 5, rng)
    cracks = np.abs(periodic_noise(64, 8, rng) - 0.5) < 0.035
    rgb = ramp(norm(n), pal("4a4744", "57534f", "64605a", "716c65", "7e7870", "8b857c"))
    rgb[cracks] = hexc("2f2c2a")
    save(to_img(rgb), "rock")


def gen_seafloor():
    rng = np.random.default_rng(505)
    n = fbm(64, 4, 3, rng) * 0.7 + rng.random((64, 64)) * 0.3
    rgb = ramp(norm(n), pal("1d332c", "233d34", "2a473c", "315143"))
    save(to_img(rgb), "seafloor")


def gen_water():
    rng = np.random.default_rng(606)
    n = fbm(64, 4, 3, rng)
    bands = (np.sin((norm(n) * 6.0) * math.pi) * 0.5 + 0.5)
    rgb = ramp(bands * 0.7 + rng.random((64, 64)) * 0.3,
               pal("1f5a80", "235f86", "28668d", "2d6c93"))
    # sparse highlight glints
    for _ in range(14):
        x, y = rng.integers(0, 64, 2)
        w = rng.integers(2, 4)
        for k in range(w):
            rgb[y, (x + k) % 64] = hexc("6fa8c8")
    save(to_img(rgb), "water")


# --------------------------------------------------------------------------
# Wood / building textures
# --------------------------------------------------------------------------
def planks(seed: int, palette, name: str, plank_h=8, gap="2a1c10"):
    rng = np.random.default_rng(seed)
    grain = periodic_noise(64, 2, rng)[:, :1] * 0  # placeholder for shape
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    rows = 64 // plank_h
    for r in range(rows):
        shade = rng.random() * 0.35
        g = fbm(64, 4, 3, rng)
        # stretch grain horizontally
        g = np.repeat(g[r * plank_h:(r + 1) * plank_h, ::4], 4, axis=1)[:, :64]
        vals = np.clip(norm(g) * 0.65 + shade, 0, 0.999)
        rgb[r * plank_h:(r + 1) * plank_h] = ramp(vals, palette)
        rgb[r * plank_h] = hexc(gap)
        # butt joint
        jx = rng.integers(0, 64)
        rgb[r * plank_h:(r + 1) * plank_h, jx] = hexc(gap)
        # nails
        for nx in ((jx + 2) % 64, (jx - 3) % 64):
            ny = r * plank_h + plank_h // 2
            rgb[ny, nx] = hexc("1a1a1a")
    del grain
    save(to_img(rgb), name)


def gen_bark():
    rng = np.random.default_rng(707)
    n = fbm(64, 4, 4, rng)
    # vertical streaks
    streak = np.repeat(rng.random((1, 16)), 4, axis=1).repeat(64, axis=0)
    v = norm(n * 0.5 + streak * 0.5)
    rgb = ramp(v, pal("2e2016", "3b2a1c", "4a3523", "58412b", "654b31"))
    save(to_img(rgb), "bark")


def gen_palm_bark():
    rng = np.random.default_rng(708)
    n = fbm(64, 4, 3, rng)
    rings = (np.arange(64)[:, None] % 8) / 8.0
    v = norm(n * 0.35 + rings * 0.65)
    rgb = ramp(v, pal("4d3b26", "5e4a30", "6f593a", "806844", "8d754d"))
    rgb[::8] = hexc("3a2a1a")
    save(to_img(rgb), "palm_bark")


def gen_thatch():
    rng = np.random.default_rng(808)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    base = fbm(64, 4, 3, rng)
    palette = pal("6e5a2c", "806a35", "927a3f", "a38948", "b39952", "c2a75d")
    rgb[:] = ramp(norm(base) * 0.5, palette)
    # straw strokes running downwards
    for _ in range(520):
        x, y = rng.integers(0, 64, 2)
        L = rng.integers(4, 10)
        c = palette[rng.integers(2, len(palette))]
        for k in range(L):
            rgb[(y + k) % 64, (x + k // 4) % 64] = c
    # layered rows
    for y in range(0, 64, 16):
        rgb[y:y + 2] = (rgb[y:y + 2] * 0.6).astype(np.uint8)
    save(to_img(rgb), "thatch")


# --------------------------------------------------------------------------
# Jungle building textures (KitStyle.JUNGLE)
# --------------------------------------------------------------------------
def gen_bamboo():
    """Vertical bamboo culms side by side, rounded by shading, dark node rings."""
    rng = np.random.default_rng(2101)
    palette = pal("4c4424", "5d542b", "706433", "82743b", "938343", "a2904c")
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    x = 0
    while x < 64:
        w = int(rng.integers(7, 10)) if 64 - x > 12 else 64 - x
        across = np.abs(np.linspace(-1, 1, w))
        streak = fbm(64, 4, 2, rng)[:, :1]
        v = np.clip((1 - across[None, :] ** 2) * 0.75 + streak * 0.35 - 0.05, 0, 0.999)
        rgb[:, x:x + w] = ramp(v, palette)
        rgb[:, x] = hexc("3a3518")
        y0 = int(rng.integers(0, 64))
        gap = int(rng.integers(18, 26))
        for y in range(y0, y0 + 64, gap):
            rgb[y % 64, x:x + w] = hexc("4a4420")
            rgb[(y + 1) % 64, x + 1:x + w - 1] = hexc("ae9e5a")
        x += w
    for _ in range(40):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("4f4a22")
    save(to_img(rgb), "bamboo")


def gen_woven():
    """Woven palm-strip matting for hut walls: a basket weave of tan strips."""
    rng = np.random.default_rng(2102)
    palette = pal("5e4826", "735a30", "88703c", "9d8448", "b09754", "c2a862")
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    cell = 8
    for cy in range(0, 64, cell):
        for cx in range(0, 64, cell):
            horiz = ((cx // cell) + (cy // cell)) % 2 == 0
            tone = rng.random() * 0.25
            for k in range(2):
                for t in range(4):
                    edge = 1 - abs(t - 1.5) / 1.5
                    for s in range(cell):
                        along = 1 - abs(s - (cell - 1) / 2) / ((cell - 1) / 2)
                        v = np.clip(0.25 + edge * 0.35 + along * 0.25 + tone + rng.random() * 0.12, 0, 0.999)
                        c = palette[int(v * len(palette))]
                        if horiz:
                            rgb[cy + k * 4 + t, cx + s] = c
                        else:
                            rgb[cy + s, cx + k * 4 + t] = c
            if horiz:
                rgb[cy + 3:cy + 5, cx] = hexc("3a2a14")
            else:
                rgb[cy, cx + 3:cx + 5] = hexc("3a2a14")
    save(to_img(rgb), "woven")


def gen_palm_thatch():
    """Palm-leaf thatch: overlapping rows of dried fronds, leaflets hanging in chevrons."""
    rng = np.random.default_rng(2103)
    palette = pal("4a3a1c", "5e4a24", "74602e", "8a7238", "9e8442", "8a8a3c", "6e7a30")
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    rgb[:] = ramp(norm(fbm(64, 4, 3, rng)) * 0.4, palette)
    for row in range(0, 64, 16):
        for x in range(0, 64, 2):
            c = palette[rng.integers(1, len(palette))]
            L = int(rng.integers(10, 17))
            lean = 1 if (x // 6) % 2 == 0 else -1
            for k in range(L):
                rgb[(row + k) % 64, (x + lean * (k // 5)) % 64] = c
        rgb[(row + 15) % 64] = (rgb[(row + 15) % 64] * 0.5).astype(np.uint8)
        rgb[row % 64] = (rgb[row % 64] * 0.75).astype(np.uint8)
        for x in range(0, 64, 4):
            rgb[(row + 14 - int(rng.integers(0, 3))) % 64, x] = hexc("2e2410")
    save(to_img(rgb), "palm_thatch")


def gen_flagstones():
    """Irregular stone slabs with mossy joints (jungle paving and plazas)."""
    rng = np.random.default_rng(2104)
    pts = rng.random((14, 2)) * 64
    yy, xx = np.mgrid[0:64, 0:64]
    d1 = np.full((64, 64), 1e9)
    d2 = np.full((64, 64), 1e9)
    owner = np.zeros((64, 64), dtype=int)
    for i, (px, py) in enumerate(pts):
        for ox in (-64, 0, 64):
            for oy in (-64, 0, 64):
                d = np.hypot(xx - (px + ox), yy - (py + oy))
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                owner = np.where(closer, i, owner)
                d1 = np.where(closer, d, d1)
    shade = rng.random(len(pts)) * 0.35
    n = fbm(64, 4, 3, rng)
    v = np.clip(shade[owner] + norm(n) * 0.5 + 0.1, 0, 0.999)
    rgb = ramp(v, pal("575a4e", "63675a", "6f7366", "7b7f70", "878a7a"))
    joint = (d2 - d1) < 1.6
    moss = ramp(norm(fbm(64, 8, 2, rng)), pal("27361a", "2f4220", "3a5026"))
    rgb[joint] = moss[joint]
    for _ in range(50):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("4a5e2c")
    save(to_img(rgb), "flagstones")


def gen_vines():
    """32x128 hanging lianas: two or three wavy strands with leaves along them. Alpha-cut."""
    W, H = 32, 128
    rng = np.random.default_rng(2105)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    greens = pal("1f3d14", "28501a", "32621f", "3f7426", "4f8a2e")
    for k in range(3):
        x0 = 6 + k * 10 + rng.integers(-2, 3)
        phase = rng.uniform(0, 6.28)
        amp = rng.uniform(1.0, 2.5)
        top = int(rng.integers(0, 10))
        end = H - int(rng.integers(0, 40))
        prev = None
        for y in range(top, end):
            x = int(x0 + amp * math.sin(y / 9.0 + phase))
            if prev is not None:
                d.line([prev, (x, y)], fill=hexc("4a3a20") + (255,))
            prev = (x, y)
            if y % 5 == 0:
                c = greens[rng.integers(0, len(greens))]
                side = 1 if (y // 5) % 2 == 0 else -1
                d.polygon([(x, y), (x + side * 4, y - 2), (x + side * 5, y + 1), (x + side * 2, y + 2)], fill=c + (255,))
    save(img, "vines")


def gen_broadleaf():
    """A big glossy tropical leaf (elephant ear / banana), midrib along y. Alpha-cut."""
    S = 64
    rng = np.random.default_rng(2106)
    yy, xx = np.mgrid[0:S, 0:S]
    t = yy / (S - 1)
    half = np.sin(np.clip(t, 0, 1) * math.pi) ** 0.8 * 0.46 * S * (1 - 0.15 * t)
    dx = xx - S / 2 + 0.5
    inside = np.abs(dx) < half
    n = fbm(S, 4, 2, rng)
    v = np.clip(0.35 + norm(n) * 0.3 + (1 - np.abs(dx) / (half + 1e-3)) * 0.25, 0, 0.999)
    rgb = ramp(v, pal("1e4416", "275a1b", "317022", "3d842a", "4c9834", "5daa3e"))
    veins = (np.abs(((yy - np.abs(dx) * 0.6) % 7)) < 1.0) & inside
    rgb[veins] = (rgb[veins] * 0.8).astype(np.uint8)
    rib = np.abs(dx) < 1.0
    rgb[rib] = hexc("8aa858")
    alpha = inside.astype(float)
    save(to_img(rgb, alpha), "broadleaf")


def gen_stone_brick():
    rng = np.random.default_rng(909)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    palette = pal("5f5a52", "6c665d", "797268", "867e73", "938a7e")
    n = fbm(64, 4, 4, rng)
    rgb[:] = ramp(norm(n), palette)
    mortar = hexc("3c3833")
    bh = 16
    for r in range(4):
        y0 = r * bh
        rgb[y0] = mortar
        off = 0 if r % 2 == 0 else 16
        for x in range(off, 64 + off, 32):
            rgb[y0:y0 + bh, x % 64] = mortar
        # per-brick shade
        for x in range(off - 32, 64, 32):
            s = rng.uniform(0.85, 1.12)
            xs = slice(max(0, x + 1), min(64, x + 32))
            rgb[y0 + 1:y0 + bh, xs] = np.clip(rgb[y0 + 1:y0 + bh, xs] * s, 0, 255)
    save(to_img(rgb), "stone_brick")


def gen_cobbles():
    """Rounded paving stones in loose rows, dark joints (the village plaza)."""
    rng = np.random.default_rng(912)
    n = fbm(64, 4, 3, rng)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    rgb[:] = hexc("3a362f")
    palette = pal("5c574e", "6a645a", "777065", "847c70", "90887b")
    rows = 6
    for r in range(rows):
        y0 = r * 64 // rows
        y1 = (r + 1) * 64 // rows
        x = int(rng.integers(0, 8))
        while x < 64 + 8:
            w = int(rng.integers(8, 13))
            shade = rng.uniform(0.0, 1.0)
            for y in range(y0 + 1, y1):
                for xx in range(x + 1, x + w - 1):
                    ly = (y - y0) / (y1 - y0)
                    lx = (xx - x) / w
                    # round the corners
                    if (lx < 0.14 or lx > 0.86) and (ly < 0.2 or ly > 0.8):
                        continue
                    v = shade * 0.55 + n[y % 64, xx % 64] * 0.35 + (1.0 - ly) * 0.1
                    rgb[y % 64, xx % 64] = palette[min(len(palette) - 1, int(v * len(palette)))]
            x += w
    for _ in range(30):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("4d5a3a")
    save(to_img(rgb), "cobbles")


def gen_sign_smithy():
    """Smithy sign: an anvil on dark wood."""
    W, H = 32, 16
    img = Image.new("RGB", (W, H), hexc("3a2a1c"))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, H - 1], outline=hexc("1e140c"))
    d.polygon([(7, 5), (24, 5), (24, 7), (19, 9), (19, 11), (22, 12), (10, 12), (13, 11), (13, 9), (9, 7)], fill=hexc("8c9096"))
    d.line([(7, 5), (24, 5)], fill=hexc("c8ccd2"))
    d.point((4, 4), fill=hexc("e89a40"))
    d.point((27, 11), fill=hexc("e89a40"))
    save(img, "sign_smithy")


def gen_plaster():
    rng = np.random.default_rng(1001)
    n = fbm(64, 4, 4, rng)
    stains = fbm(64, 2, 2, rng)
    v = norm(n * 0.6 + stains * 0.4)
    rgb = ramp(v, pal("b8ad96", "c6bba3", "d2c8b0", "ddd4bd", "e7dfca"))
    # exposed bricks patch
    for _ in range(3):
        x, y = rng.integers(0, 56, 2)
        rgb[y:y + 3, x:x + 6] = hexc("8a5a40")
        rgb[y + 1, x:x + 6] = hexc("6a4430")
    save(to_img(rgb), "plaster")


def gen_roof_tiles():
    rng = np.random.default_rng(1101)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    palette = pal("6e2e1e", "823824", "94432a", "a54e31", "b45a39")
    n = fbm(64, 4, 3, rng)
    for y in range(64):
        for x in range(64):
            row = y // 8
            lx = (x + (4 if row % 2 else 0)) % 8
            curve = 1.0 - abs(lx - 3.5) / 4.0
            ly = (y % 8) / 8.0
            v = curve * 0.6 + n[y, x] * 0.3 + (1 - ly) * 0.1
            rgb[y, x] = palette[min(len(palette) - 1, int(v * len(palette)))]
        if y % 8 == 7:
            rgb[y] = hexc("3e180f")
    save(to_img(rgb), "roof_tiles")


def gen_cloth(seed, a, b, name, stripes=True):
    rng = np.random.default_rng(seed)
    n = rng.random((64, 64)) * 0.25
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    for x in range(64):
        c = a if (x // 8) % 2 == 0 or not stripes else b
        rgb[:, x] = c
    rgb = np.clip(rgb * (0.85 + n[..., None]), 0, 255).astype(np.uint8)
    rgb[::4] = (rgb[::4] * 0.9).astype(np.uint8)
    save(to_img(rgb), name)


def gen_fabric():
    """Neutral weave, tinted by vertex color for clothes."""
    rng = np.random.default_rng(1201)
    n = fbm(32, 4, 2, rng) * 0.5 + rng.random((32, 32)) * 0.5
    weave = ((np.arange(32)[:, None] + np.arange(32)[None, :]) % 2) * 0.12
    v = np.clip(0.72 + (norm(n) - 0.5) * 0.25 + weave, 0, 1)
    g = (v * 255).astype(np.uint8)
    rgb = np.dstack([g, g, g])
    save(to_img(rgb), "fabric")


def gen_fabric_patterns():
    """Fabric skins (1.24, tailors): the fabric weave with a pattern woven in, grayscale and tinted in game by the
    piece's colour, so a dark stripe or check reads in any dye. 32x32 like fabric (3 tiles a metre on a body)."""
    rng = np.random.default_rng(1203)
    n = fbm(32, 4, 2, rng) * 0.5 + rng.random((32, 32)) * 0.5
    weave = ((np.arange(32)[:, None] + np.arange(32)[None, :]) % 2) * 0.12
    base = np.clip(0.72 + (norm(n) - 0.5) * 0.25 + weave, 0, 1)
    ys, xs = np.mgrid[0:32, 0:32]

    def out(v, name):
        g = (np.clip(v, 0, 1) * 255).astype(np.uint8)
        save(to_img(np.dstack([g, g, g])), name)

    # stripes: broad dark bands across, a fine one between (sailors' ticking)
    v = base.copy()
    v[(ys % 8) < 3] *= 0.55
    v[(ys % 8) == 5] *= 0.8
    out(v, "fabric_stripes")
    # check: two crossing sets of bands, darker where they cross (a plaid)
    v = base.copy()
    a = (xs % 16) < 6
    b = (ys % 16) < 6
    v[a] *= 0.72
    v[b] *= 0.72
    v[(xs % 16) == 10] *= 0.85
    v[(ys % 16) == 10] *= 0.85
    out(v, "fabric_check")
    # brocade: a pale diamond lattice with a dot in each cell (rich coats)
    v = base.copy() * 0.82
    d = (np.abs((xs % 16) - 8) + np.abs((ys % 16) - 8))
    v[d == 7] = np.clip(v[d == 7] * 1.45, 0, 1)
    v[d <= 1] = np.clip(v[d <= 1] * 1.4, 0, 1)
    out(v, "fabric_brocade")
    # patched: squares of other cloth sewn on, stitched round
    v = base.copy()
    for (x0, y0, w, h, k) in [(3, 4, 10, 9, 0.68), (18, 15, 11, 12, 1.12), (6, 22, 8, 7, 0.82)]:
        v[y0:y0 + h, x0:x0 + w] *= k
        v[y0, x0:x0 + w:2] *= 0.6
        v[y0 + h - 1, x0:x0 + w:2] *= 0.6
        v[y0:y0 + h:2, x0] *= 0.6
        v[y0:y0 + h:2, x0 + w - 1] *= 0.6
    out(v, "fabric_patched")


def gen_mail():
    """Riveted mail: rows of rings, each a bright rim round a dark hole, the rows offset (grayscale, tinted in game)."""
    rng = np.random.default_rng(1305)
    size, cw, rh = 64, 4, 4
    v = np.full((size, size), 0.34)
    ys, xs = np.mgrid[0:size, 0:size]
    for r in range(size // rh):
        cy = r * rh + 2
        for c in range(size // cw):
            cx = c * cw + (2 if r % 2 else 0)
            dx = (xs - cx + size // 2) % size - size // 2
            dy = (ys - cy + size // 2) % size - size // 2
            d = np.sqrt(dx * dx + dy * dy)
            # a ring lit from above: bright on its upper rim, dull below, dark in the middle and between rings
            rim = (d >= 0.8) & (d < 1.8)
            v = np.where(rim, np.maximum(v, 0.9 - np.clip(dy + 1, 0, None) * 0.14), v)
    v += (rng.random((size, size)) - 0.5) * 0.08
    pal_g = [0.28, 0.42, 0.58, 0.72, 0.86, 0.96]
    q = np.array(pal_g)[np.clip((norm(v) * len(pal_g)).astype(int), 0, len(pal_g) - 1)]
    g = (q * 255).astype(np.uint8)
    save(to_img(np.dstack([g, g, g])), "mail")


def gen_metal():
    rng = np.random.default_rng(1301)
    n = fbm(32, 2, 3, rng)
    streak = np.repeat(rng.random((32, 1)), 32, axis=1)
    v = norm(n * 0.4 + streak * 0.6)
    rgb = ramp(v, pal("5a6068", "6e757e", "848b94", "9aa1aa", "b4bbc4", "d4dae0"))
    save(to_img(rgb), "metal")


def gen_straw():
    rng = np.random.default_rng(1401)
    rgb = np.zeros((32, 32, 3), dtype=np.uint8)
    palette = pal("8a6f30", "a0833b", "b59746", "c8aa55", "d9bc66")
    rgb[:] = palette[1]
    for _ in range(160):
        x, y = rng.integers(0, 32, 2)
        c = palette[rng.integers(0, len(palette))]
        for k in range(rng.integers(3, 7)):
            rgb[(y + k) % 32, x] = c
    # rope bands
    rgb[10:12] = hexc("5c4320")
    rgb[22:24] = hexc("5c4320")
    save(to_img(rgb), "straw")


# --------------------------------------------------------------------------
# Foliage (alpha cutout)
# --------------------------------------------------------------------------
def gen_leaves():
    """Opaque leafy texture for jungle tree canopy blobs."""
    rng = np.random.default_rng(1501)
    palette = pal("1d3a14", "254a18", "2e5a1d", "386b22", "447c29", "558f31")
    n = fbm(64, 4, 3, rng)
    rgb = ramp(norm(n) * 0.6, palette)
    for _ in range(170):
        x, y = rng.integers(0, 64, 2)
        c = palette[rng.integers(2, len(palette))]
        # little leaf diamond
        for dy, dx in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1)):
            rgb[(y + dy) % 64, (x + dx) % 64] = c
        rgb[(y + 2) % 64, x] = palette[0]
    save(to_img(rgb), "leaves")


def gen_palm_frond():
    """64x32 frond: stem along x, leaflets angled out. Alpha-cut."""
    W, H = 64, 32
    rng = np.random.default_rng(1601)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    greens = pal("2c5a1c", "356a22", "3f7a28", "4c8a30", "5d9c38")
    cy = H // 2
    for x in range(2, W - 2, 2):
        t = x / W
        length = int((1 - abs(t - 0.45) * 1.5) * (H // 2 - 1))
        length = max(2, length)
        c = greens[rng.integers(0, len(greens))]
        d.line([(x, cy), (x + 4, cy - length)], fill=c + (255,))
        c = greens[rng.integers(0, len(greens))]
        d.line([(x, cy), (x + 4, cy + length)], fill=c + (255,))
    d.line([(0, cy), (W - 1, cy)], fill=hexc("6b5a2a") + (255,))
    save(img, "palm_frond")


def gen_bush():
    W = 64
    rng = np.random.default_rng(1701)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    greens = pal("1f4016", "28501a", "32621f", "3d7425", "4b862c", "5a9834")
    for _ in range(260):
        x = rng.normal(32, 13)
        y = rng.normal(40, 11)
        if not (2 < x < 62 and 4 < y < 63):
            continue
        r = rng.integers(1, 4)
        c = greens[min(len(greens) - 1, int((63 - y) / 64 * len(greens) + rng.integers(0, 2)))]
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (255,))
    save(img, "bush")


def gen_thornbrush():
    """Dry thornbrush card: tangled bare tan/brown stems with thorns and a few
    withered leaves (alpha cutout)."""
    W = 64
    rng = np.random.default_rng(1777)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stems = pal("4a3220", "5e4229", "765634", "8e6c42", "a88452")
    for _ in range(34):
        x = rng.uniform(4, 60)
        y = 63.0
        ang = rng.uniform(-1.2, 1.2) - np.pi / 2
        c = stems[rng.integers(0, len(stems))] + (255,)
        for _seg in range(rng.integers(5, 10)):
            l = rng.uniform(4, 9)
            nx, ny = x + np.cos(ang) * l, y + np.sin(ang) * l
            d.line([(x, y), (nx, ny)], fill=c, width=1)
            # thorns
            if rng.random() < 0.7:
                tx, ty = (x + nx) / 2, (y + ny) / 2
                d.point((tx + rng.choice([-1, 1]), ty), fill=hexc("c8a878") + (255,))
            x, y = nx, ny
            ang += rng.uniform(-0.7, 0.7)
            if not (1 < x < 63 and 1 < y < 64):
                break
    for _ in range(40):
        x, y = rng.uniform(4, 60), rng.uniform(12, 60)
        d.point((x, y), fill=pal("6a6a2a", "7a6a30", "8a7a3a")[rng.integers(0, 3)] + (255,))
        d.point((x + 1, y), fill=pal("6a6a2a", "7a6a30", "8a7a3a")[rng.integers(0, 3)] + (255,))
    save(img, "thornbrush")


def gen_grass_tuft():
    W = 32
    rng = np.random.default_rng(1801)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    greens = pal("355a1f", "416b25", "4e7c2b", "5d8e33", "6fa03c")
    for _ in range(22):
        x0 = rng.integers(4, 28)
        h = rng.integers(10, 30)
        lean = rng.integers(-5, 6)
        c = greens[rng.integers(0, len(greens))]
        d.line([(x0, 31), (x0 + lean, 31 - h)], fill=c + (255,))
    # a few flowers
    for _ in range(3):
        x, y = rng.integers(6, 26), rng.integers(6, 18)
        c = [hexc("e8d860"), hexc("e88aa0"), hexc("f0f0f0")][rng.integers(0, 3)]
        d.point((x, y), fill=c + (255,))
    save(img, "grass_tuft")


def gen_fern():
    W = 64
    rng = np.random.default_rng(1802)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    greens = pal("24461a", "2e5820", "386a26", "447c2d")
    for i in range(7):
        ang = math.radians(-160 + i * 23 + rng.uniform(-6, 6))
        L = rng.uniform(22, 30)
        x1 = 32 + math.cos(ang) * L
        y1 = 62 + math.sin(ang) * L
        d.line([(32, 62), (x1, y1)], fill=greens[0] + (255,))
        for t in np.linspace(0.15, 0.95, 9):
            px = 32 + (x1 - 32) * t
            py = 62 + (y1 - 62) * t
            s = (1 - t) * 6 + 1
            c = greens[rng.integers(1, len(greens))]
            d.line([(px, py), (px - s * math.sin(ang) * 0.9, py + s * math.cos(ang) * 0.9 - s)], fill=c + (255,))
            d.line([(px, py), (px + s * math.sin(ang) * 0.9, py - s * math.cos(ang) * 0.9 - s)], fill=c + (255,))
    save(img, "fern")


# --------------------------------------------------------------------------
# Special
# --------------------------------------------------------------------------
def gen_driftstone():
    """Dark monolith stone; glyphs stored in a separate emission mask."""
    rng = np.random.default_rng(1901)
    n = fbm(64, 4, 5, rng)
    rgb = ramp(norm(n), pal("1b1d22", "22252b", "2a2e35", "33373f", "3c414a"))
    glyph = np.zeros((64, 64))
    # carve rows of angular glyphs
    for row in range(5):
        y0 = 6 + row * 11
        x = 6
        while x < 58:
            w = rng.integers(3, 6)
            shape = rng.integers(0, 5)
            for k in range(7):
                if shape == 0:
                    glyph[y0 + k, x] = 1
                elif shape == 1:
                    glyph[y0 + k, x + min(k, w - 1)] = 1
                elif shape == 2:
                    glyph[y0 + (0 if k < w else 6), x + min(k, w - 1)] = 1
                    glyph[y0 + k, x] = 1
                elif shape == 3:
                    glyph[y0 + 3, x + min(k, w - 1)] = 1
                    glyph[y0 + k, x + w // 2] = 1
                else:
                    if k % 2 == 0:
                        glyph[y0 + k, x + (k // 2) % w] = 1
            x += w + 2
    rgb[glyph > 0] = hexc("0e0f12")
    save(to_img(rgb), "driftstone")
    g = (glyph * 255).astype(np.uint8)
    save(Image.fromarray(np.dstack([g, g, g]), "RGB"), "driftstone_glow")


def gen_rope():
    rng = np.random.default_rng(2001)
    rgb = np.zeros((16, 16, 3), dtype=np.uint8)
    for y in range(16):
        for x in range(16):
            v = ((x + y) % 4) / 4.0 * 0.6 + rng.random() * 0.2
            rgb[y, x] = ramp(np.array([[v]]), pal("5a4320", "6e5428", "826430", "967538"))[0, 0]
    save(to_img(rgb), "rope")


def gen_sign_tavern():
    """Hanging tavern sign: mug icon on dark wood."""
    W, H = 32, 16
    img = Image.new("RGB", (W, H), hexc("4a3220"))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, H - 1], outline=hexc("2a1c10"))
    # mug
    d.rectangle([11, 4, 18, 12], fill=hexc("c8a040"), outline=hexc("2a1c10"))
    d.rectangle([11, 3, 18, 5], fill=hexc("f0ece0"))
    d.rectangle([19, 6, 21, 10], outline=hexc("c8a040"))
    save(img, "sign_tavern")


def gen_sign_fish():
    W, H = 32, 16
    img = Image.new("RGB", (W, H), hexc("3e4a52"))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W - 1, H - 1], outline=hexc("1e252a"))
    d.ellipse([7, 5, 21, 11], fill=hexc("b0c4cc"))
    d.polygon([(21, 8), (26, 4), (26, 12)], fill=hexc("b0c4cc"))
    d.point((10, 7), fill=hexc("1e252a"))
    save(img, "sign_fish")


def gen_window():
    W = 16
    img = Image.new("RGB", (W, W), hexc("2a1c10"))
    d = ImageDraw.Draw(img)
    d.rectangle([2, 2, 13, 13], fill=hexc("e8c060"))
    d.rectangle([2, 2, 13, 6], fill=hexc("f4d880"))
    d.line([(7, 2), (7, 13)], fill=hexc("2a1c10"))
    d.line([(2, 7), (13, 7)], fill=hexc("2a1c10"))
    save(img, "window")


def gen_door():
    W, H = 16, 32
    img = Image.new("RGB", (W, H), hexc("4a3020"))
    d = ImageDraw.Draw(img)
    for x in range(0, W, 4):
        d.line([(x, 0), (x, H)], fill=hexc("2e1c12"))
    d.rectangle([0, 0, W - 1, H - 1], outline=hexc("22140c"))
    d.line([(0, 8), (W, 8)], fill=hexc("6a6a6a"))
    d.line([(0, 24), (W, 24)], fill=hexc("6a6a6a"))
    d.point((12, 16), fill=hexc("d0b050"))
    save(img, "door")


def gen_door_panel():
    """A panelled door leaf, 32x64, pale so a tint paints it (Buildings.panel_door): stiles and
    rails round four raised panels, bevels lit from the top left, a faint vertical grain."""
    W, H = 32, 64
    rng = np.random.default_rng(7611)
    grain = norm(periodic_noise(64, 16, rng))[:H, :W] * 0.6 + rng.random((H, W)) * 0.4
    v = 0.55 + (grain - 0.5) * 0.22
    for x in (0, 1, W - 2, W - 1):
        v[:, x] -= 0.12
    v[0:2, :] -= 0.1
    v[H - 2:, :] -= 0.14
    panels = [(4, 5, 14, 31), (18, 5, 28, 31), (4, 37, 14, 57), (18, 37, 28, 57)]
    for x0, y0, x1, y1 in panels:
        v[y0:y1, x0:x1] -= 0.26
        v[y0 + 2:y1 - 2, x0 + 2:x1 - 2] += 0.2
        v[y0 + 1, x0 + 1:x1 - 1] += 0.24
        v[y0 + 1:y1 - 1, x0 + 1] += 0.18
        v[y1 - 2, x0 + 1:x1 - 1] -= 0.06
        v[y0 + 1:y1 - 1, x1 - 2] -= 0.06
        v[y0 + 2:y1 - 2, x0 + 2:x1 - 2] += (grain[y0 + 2:y1 - 2, x0 + 2:x1 - 2] - 0.5) * 0.1
    v[33:35, 2:W - 2] -= 0.05
    rgb = ramp(np.clip(v, 0, 0.999), pal("4a453e", "6e675c", "8e867a", "aaa294", "c2baab", "d8d1c2", "ebe5d7"))
    save(to_img(rgb), "door_panel")


# --------------------------------------------------------------------------
# Faces (16x16, transparent background -> skin shows through)
# Laid out in a 4x2 atlas (64x32).
# --------------------------------------------------------------------------
def gen_faces():
    atlas = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(atlas)
    EYE = hexc("16120e") + (255,)
    WHITE = hexc("f2eee4") + (255,)
    MOUTH = hexc("5a2a22") + (255,)
    BROW = hexc("2e2016") + (255,)
    BEARD_D = hexc("3a2a1c") + (255,)
    BEARD_G = hexc("b8b4ac") + (255,)

    def face(ix, iy, kind):
        ox, oy = ix * 16, iy * 16
        # eyes
        if kind == "sleepy":
            d.line([(ox + 4, oy + 7), (ox + 6, oy + 7)], fill=EYE)
            d.line([(ox + 9, oy + 7), (ox + 11, oy + 7)], fill=EYE)
        else:
            d.point((ox + 4, oy + 7), fill=WHITE)
            d.point((ox + 5, oy + 7), fill=EYE)
            d.point((ox + 10, oy + 7), fill=EYE)
            d.point((ox + 11, oy + 7), fill=WHITE)
        # brows
        if kind in ("stern", "captain"):
            d.line([(ox + 3, oy + 5), (ox + 6, oy + 6)], fill=BROW)
            d.line([(ox + 9, oy + 6), (ox + 12, oy + 5)], fill=BROW)
        elif kind != "sleepy":
            d.line([(ox + 4, oy + 5), (ox + 6, oy + 5)], fill=BROW)
            d.line([(ox + 9, oy + 5), (ox + 11, oy + 5)], fill=BROW)
        # nose
        d.point((ox + 8, oy + 9), fill=(0, 0, 0, 70))
        # mouth / beard
        if kind == "beard":
            d.rectangle([ox + 3, oy + 10, ox + 12, oy + 15], fill=BEARD_D)
            d.line([(ox + 6, oy + 11), (ox + 9, oy + 11)], fill=MOUTH)
        elif kind == "greybeard":
            d.rectangle([ox + 3, oy + 10, ox + 12, oy + 15], fill=BEARD_G)
            d.line([(ox + 6, oy + 11), (ox + 9, oy + 11)], fill=MOUTH)
        elif kind == "smile":
            d.line([(ox + 5, oy + 11), (ox + 6, oy + 12)], fill=MOUTH)
            d.line([(ox + 6, oy + 12), (ox + 9, oy + 12)], fill=MOUTH)
            d.line([(ox + 9, oy + 12), (ox + 10, oy + 11)], fill=MOUTH)
        elif kind == "captain":
            # stubble + scar
            for sx in range(4, 12, 2):
                d.point((ox + sx, oy + 13), fill=(40, 30, 20, 120))
            d.line([(ox + 6, oy + 12), (ox + 9, oy + 12)], fill=MOUTH)
            d.line([(ox + 11, oy + 4), (ox + 12, oy + 9)], fill=hexc("9a4a40") + (255,))
        elif kind == "eyepatch":
            d.rectangle([ox + 9, oy + 6, ox + 12, oy + 8], fill=EYE)
            d.line([(ox + 2, oy + 4), (ox + 13, oy + 8)], fill=EYE)
            d.line([(ox + 6, oy + 12), (ox + 9, oy + 12)], fill=MOUTH)
        else:
            d.line([(ox + 6, oy + 12), (ox + 9, oy + 12)], fill=MOUTH)

    kinds = ["plain", "smile", "beard", "greybeard", "stern", "sleepy", "captain", "eyepatch"]
    for i, k in enumerate(kinds):
        face(i % 4, i // 4, k)
    save(atlas, "faces")


# --------------------------------------------------------------------------
# Item icons (24x24, transparent) -> assets/textures/icons/
# --------------------------------------------------------------------------
ICON_OUT = os.path.join(ROOT, "assets", "textures", "icons")


def _icon(name, draw_fn):
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_fn(d)
    # 1px dark outline around opaque pixels for readability
    a = np.array(img)
    alpha = a[..., 3] > 0
    out = np.zeros_like(alpha)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        out |= np.roll(np.roll(alpha, dy, 0), dx, 1)
    edge = out & ~alpha
    a[edge] = (20, 14, 10, 255)
    img = Image.fromarray(a, "RGBA")
    os.makedirs(ICON_OUT, exist_ok=True)
    path = os.path.join(ICON_OUT, name + ".png")
    img.save(path)
    print("  wrote", os.path.relpath(path, ROOT))


def gen_icons():
    steel = hexc("c8d0d8") + (255,)
    steel_d = hexc("7a8490") + (255,)
    brass = hexc("e0b050") + (255,)
    wood = hexc("6a4628") + (255,)

    def cutlass(d):
        d.line([(5, 19), (17, 7)], fill=steel, width=2)
        d.line([(17, 7), (19, 4)], fill=steel, width=1)
        d.line([(6, 19), (18, 7)], fill=steel_d)
        d.line([(3, 16), (8, 21)], fill=brass, width=2)
        d.line([(2, 21), (4, 19)], fill=wood, width=2)

    def axe(d):
        d.line([(5, 21), (16, 6)], fill=wood, width=2)
        d.polygon([(13, 3), (21, 6), (19, 13), (14, 9)], fill=steel)
        d.line([(19, 6), (18, 12)], fill=steel_d)

    def rum(d):
        d.rectangle([8, 9, 15, 21], fill=hexc("5a3014") + (255,))
        d.rectangle([10, 4, 13, 9], fill=hexc("5a3014") + (255,))
        d.rectangle([10, 2, 13, 4], fill=hexc("c8a070") + (255,))
        d.rectangle([8, 13, 15, 17], fill=hexc("e8dcc0") + (255,))
        d.line([(10, 15), (13, 15)], fill=hexc("a02818") + (255,))
        d.line([(9, 10), (9, 20)], fill=hexc("8a5a30") + (255,))

    def gold(d):
        for (x, y) in ((6, 14), (12, 15), (9, 10), (15, 11)):
            d.ellipse([x - 4, y - 3, x + 4, y + 3], fill=brass)
            d.ellipse([x - 2, y - 2, x + 2, y + 1], fill=hexc("fff0a0") + (255,))

    def treasure(d):
        d.polygon([(12, 3), (19, 9), (12, 21), (5, 9)], fill=hexc("40c0b0") + (255,))
        d.polygon([(12, 3), (15, 9), (12, 21), (9, 9)], fill=hexc("90f0e0") + (255,))
        d.line([(5, 9), (19, 9)], fill=hexc("208070") + (255,))

    def katana(d):
        # long, gently curved blade, round guard, dark wrapped two-hand hilt
        d.line([(9, 15), (15, 9)], fill=steel, width=2)
        d.line([(15, 9), (19, 5)], fill=steel, width=2)
        d.line([(19, 5), (21, 2)], fill=steel, width=1)
        d.line([(10, 15), (20, 5)], fill=steel_d)
        d.ellipse([6, 14, 10, 18], fill=hexc("4a4848") + (255,))
        d.line([(2, 22), (8, 16)], fill=hexc("2a2230") + (255,), width=2)
        d.point([(3, 21), (5, 19), (7, 17)], fill=hexc("8a7a90") + (255,))
        d.point([(2, 22)], fill=brass)

    def fish(d):
        # a grilled fish on a skewer, char lines across it
        d.line([(2, 20), (21, 4)], fill=hexc("8a6a40") + (255,), width=1)
        d.ellipse([5, 8, 17, 16], fill=hexc("c08048") + (255,))
        d.polygon([(16, 12), (22, 7), (22, 17)], fill=hexc("a86a38") + (255,))
        d.ellipse([6, 9, 9, 12], fill=hexc("f0e0c0") + (255,))
        d.point((7, 10), fill=hexc("201010") + (255,))
        for x in (10, 12, 14):
            d.line([(x, 9), (x - 1, 15)], fill=hexc("5a3018") + (255,))

    def stew(d):
        # a wooden bowl of stew, steam rising
        d.chord([3, 8, 21, 22], 0, 180, fill=hexc("6a4628") + (255,))
        d.ellipse([3, 9, 21, 15], fill=hexc("8a4a20") + (255,))
        for (x, y) in ((8, 12), (13, 11), (16, 13)):
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=hexc("d8a040") + (255,))
        d.point((11, 13), fill=hexc("60a040") + (255,))
        for x in (8, 13):
            d.line([(x, 7), (x + 1, 5), (x, 3)], fill=hexc("e8e8e8") + (200,))

    def biscuit(d):
        # a square of hardtack, docked with holes
        d.rectangle([4, 5, 19, 20], fill=hexc("d8b878") + (255,))
        d.rectangle([4, 5, 19, 7], fill=hexc("e8cc90") + (255,))
        for (x, y) in ((8, 10), (12, 10), (16, 10), (8, 15), (12, 15), (16, 15)):
            d.point((x, y), fill=hexc("8a6a38") + (255,))

    def boar_haunch(d):
        # a roast haunch, bone sticking out
        d.ellipse([3, 7, 17, 20], fill=hexc("8a4a20") + (255,))
        d.ellipse([5, 8, 14, 14], fill=hexc("b8743a") + (255,))
        d.line([(15, 9), (21, 4)], fill=hexc("eee4cc") + (255,), width=2)
        d.ellipse([19, 2, 23, 6], fill=hexc("eee4cc") + (255,))

    def tusk(d):
        d.arc([4, 3, 22, 25], 180, 280, fill=hexc("eee4cc") + (255,), width=3)
        d.line([(4, 15), (6, 17)], fill=hexc("8a6a40") + (255,), width=2)

    def chitin_shard(d):
        d.polygon([(5, 18), (11, 3), (19, 8), (16, 21)], fill=hexc("2e6a62") + (255,))
        d.polygon([(11, 3), (19, 8), (14, 10)], fill=hexc("5aa89a") + (255,))
        d.line([(9, 14), (15, 12)], fill=hexc("f0c850") + (255,))

    def plume(d):
        d.line([(5, 21), (18, 4)], fill=hexc("e8e0d0") + (255,))
        d.polygon([(18, 4), (14, 6), (8, 15), (6, 19), (10, 16), (16, 10)], fill=hexc("f08a18") + (255,))
        d.polygon([(18, 4), (19, 9), (13, 15), (10, 16)], fill=hexc("2a60d8") + (255,))

    def jungle_fruit(d):
        d.ellipse([5, 7, 19, 21], fill=hexc("f0a020") + (255,))
        d.ellipse([7, 9, 12, 13], fill=hexc("ffd870") + (255,))
        d.polygon([(12, 7), (17, 2), (19, 5)], fill=hexc("4a9a30") + (255,))

    def snakeskin(d):
        for k in range(5):
            y = 4 + k * 4
            d.line([(3 + k, y), (20 - k, y + 2)], fill=hexc("4a8a2a") + (255,), width=3)
            d.point((11, y + 1), fill=hexc("d8e070") + (255,))

    def crab_meat(d):
        d.ellipse([3, 9, 13, 19], fill=hexc("d0401a") + (255,))
        d.polygon([(11, 10), (21, 4), (19, 10)], fill=hexc("d0401a") + (255,))
        d.polygon([(12, 14), (21, 15), (18, 10)], fill=hexc("f08a5a") + (255,))

    def tonic(d):
        # a round glass flask of sea-green tonic, corked, a glint on the glass
        d.ellipse([5, 8, 19, 22], fill=hexc("c8e8e0") + (255,))
        d.chord([6, 9, 18, 21], 200, 340, fill=hexc("c8e8e0") + (255,))
        d.chord([6, 9, 18, 21], -20, 200, fill=hexc("2fb8a0") + (255,))
        d.ellipse([7, 15, 17, 20], fill=hexc("1f8a7a") + (255,))
        d.rectangle([10, 4, 13, 9], fill=hexc("c8e8e0") + (255,))
        d.rectangle([9, 2, 14, 4], fill=hexc("a0703a") + (255,))
        d.point([(8, 12), (9, 11)], fill=(255, 255, 255, 255))

    gen_food_icons()
    _icon("tonic", tonic)
    _icon("boar_haunch", boar_haunch)
    _icon("tusk", tusk)
    _icon("chitin_shard", chitin_shard)
    _icon("plume", plume)
    _icon("jungle_fruit", jungle_fruit)
    _icon("snakeskin", snakeskin)
    _icon("crab_meat", crab_meat)
    _icon("cutlass", cutlass)
    _icon("katana", katana)
    _icon("axe", axe)
    _icon("rum", rum)
    _icon("gold", gold)
    _icon("treasure", treasure)
    _icon("fish", fish)
    _icon("stew", stew)
    _icon("biscuit", biscuit)


def gen_part_icons():
    """1.23 beast pass: what a boss's broken parts drop (BeastParts)."""
    def c(h, a=255):
        return hexc(h) + (a,)

    def ivory(d):
        # a thick curved tusk, its broken root dark and jagged
        d.arc([2, 2, 24, 26], 175, 285, fill=c("f4ecd4"), width=5)
        d.arc([4, 4, 22, 24], 185, 280, fill=c("c8b890"), width=1)
        d.polygon([(2, 14), (7, 13), (5, 17), (8, 19), (3, 20)], fill=c("8a6a40"))

    def knuckle(d):
        # a gnarled knuckle bone, callused grey on top
        d.ellipse([4, 8, 20, 19], fill=c("e2d8bc"))
        for x in (6, 10, 14):
            d.ellipse([x, 5, x + 5, 11], fill=c("8a8680"))
        d.line([(6, 15), (18, 15)], fill=c("a89a78"))

    def sand_plate(d):
        # an amber armour plate off the Sand King's back, ridged
        d.polygon([(3, 16), (8, 5), (16, 4), (21, 13), (16, 21), (7, 21)], fill=c("b07a30"))
        d.polygon([(8, 5), (16, 4), (14, 9), (9, 10)], fill=c("e8b860"))
        for y in (12, 16):
            d.line([(6, y), (18, y - 1)], fill=c("6a4418"))

    def mandible(d):
        # a curved mandible, saw-toothed on the inside
        d.arc([3, 3, 23, 23], 200, 330, fill=c("3a2a1a"), width=4)
        for (x, y) in ((8, 8), (12, 6), (16, 7)):
            d.polygon([(x, y), (x + 2, y + 4), (x - 1, y + 3)], fill=c("e8dcc0"))

    def bear_claw(d):
        # three hooked claws on a scrap of hide
        d.rectangle([4, 16, 20, 21], fill=c("6a5240"))
        for x in (6, 11, 16):
            d.polygon([(x, 16), (x + 3, 16), (x + 4, 9), (x + 2, 4), (x + 1, 9)], fill=c("2a2420"))
            d.point((x + 2, 6), fill=c("8a8680"))

    def bear_hide(d):
        # a white pelt, ragged edges
        d.polygon([(3, 6), (8, 3), (16, 4), (21, 7), (20, 18), (14, 21), (6, 20), (3, 15)], fill=c("e8ecf0"))
        for (x, y) in ((7, 9), (13, 8), (10, 14), (16, 15)):
            d.line([(x, y), (x + 2, y + 2)], fill=c("a8b0bc"))

    _icon("ivory", ivory)
    _icon("knuckle", knuckle)
    _icon("sand_plate", sand_plate)
    _icon("mandible", mandible)
    _icon("bear_claw", bear_claw)
    _icon("bear_hide", bear_hide)


def gen_food_icons():
    """v1.18 cooking: the raw ingredients (Food.INGREDIENTS), the galley's meals (Food.MEALS) and the pearl."""
    def c(h, a=255):
        return hexc(h) + (a,)

    def sack(d, body, spill):
        d.polygon([(6, 8), (18, 8), (20, 21), (4, 21)], fill=c(body))
        d.line([(6, 8), (18, 8)], fill=c("8a7448"), width=2)
        d.polygon([(8, 4), (16, 4), (18, 8), (6, 8)], fill=c("b89a60"))
        d.line([(9, 6), (15, 6)], fill=c("6a4628"))
        for (x, y) in ((8, 14), (15, 16), (11, 18), (13, 12)):
            d.point((x, y), fill=c(spill))

    def rice(d):
        sack(d, "d8c8a0", "fff8e8")
        for (x, y) in ((3, 22), (5, 21), (20, 22), (21, 21)):
            d.point((x, y), fill=c("fff8e8"))

    def flour(d):
        sack(d, "e8e0cc", "c8b890")
        d.ellipse([9, 12, 15, 17], outline=c("a08a60"))

    def salt(d):
        d.chord([4, 10, 20, 22], 0, 180, fill=c("6a4628"))
        d.ellipse([4, 12, 20, 17], fill=c("f4f4ee"))
        d.polygon([(8, 14), (12, 7), (16, 14)], fill=c("ffffff"))
        d.point([(10, 11), (13, 12)], fill=c("c8d8e0"))

    def pepper(d):
        for (x, y) in ((8, 9), (14, 8), (11, 13), (16, 14), (7, 16), (12, 18), (17, 19)):
            d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=c("2a2018"))
            d.point((x - 1, y - 1), fill=c("6a5a48"))

    def mushroom(d):
        for (x, s) in ((8, 1.0), (15, 0.8)):
            w = int(6 * s)
            d.rectangle([x - 1, 13, x + 1, 21], fill=c("e8dcc0"))
            d.chord([x - w, 6 + int(4 * (1 - s)), x + w, 18], 180, 360, fill=c("8a5a30"))
            d.point([(x - 2, 9 + int(3 * (1 - s))), (x + 2, 10 + int(3 * (1 - s)))], fill=c("d8b080"))

    def seaweed(d):
        for (x0, col) in ((7, "2e7a3a"), (12, "3e9a48"), (17, "2a6a34")):
            pts = [(x0 + (1 if k % 2 else -1), 22 - k * 3) for k in range(7)]
            d.line(pts, fill=c(col), width=3)

    def coconut(d):
        d.ellipse([4, 5, 20, 21], fill=c("6a4020"))
        d.ellipse([6, 7, 13, 13], fill=c("8a5a30"))
        for (x, y) in ((10, 9), (14, 9), (12, 12)):
            d.point((x, y), fill=c("2a1a0a"))
        d.line([(6, 16), (18, 18)], fill=c("4a2a10"))

    def egg(d):
        for (x, y) in ((8, 13), (15, 12)):
            d.ellipse([x - 4, y - 6, x + 4, y + 6], fill=c("e8e4d0"))
            d.point([(x - 1, y - 2), (x + 2, y + 1), (x, y + 3)], fill=c("8a7a60"))
        d.chord([2, 16, 22, 23], 180, 360, fill=c("8a6a40"))

    def oyster(d):
        d.ellipse([3, 8, 21, 20], fill=c("8a8478"))
        d.ellipse([5, 10, 19, 18], fill=c("e8d8d0"))
        d.ellipse([10, 12, 14, 16], fill=c("fff8f0"))
        d.arc([3, 4, 21, 16], 200, 340, fill=c("5a564c"), width=2)

    def sea_urchin(d):
        for k in range(12):
            a = k * math.pi / 6
            d.line([(12, 13), (12 + int(10 * math.cos(a)), 13 + int(9 * math.sin(a)))], fill=c("3a1a4a"))
        d.ellipse([7, 8, 17, 18], fill=c("5a2a6a"))
        d.point([(10, 11), (13, 10)], fill=c("a070b0"))

    def pearl(d):
        d.ellipse([6, 6, 18, 18], fill=c("e8e4e8"))
        d.ellipse([8, 8, 13, 13], fill=c("ffffff"))
        d.arc([6, 6, 18, 18], 20, 120, fill=c("b8b0c0"))

    def bowl(d, food, bits, steam=True):
        d.chord([3, 8, 21, 22], 0, 180, fill=c("6a4628"))
        d.ellipse([3, 9, 21, 15], fill=c(food))
        for (x, y, col) in bits:
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=c(col))
        if steam:
            for x in (8, 15):
                d.line([(x, 7), (x + 1, 5), (x, 3)], fill=c("e8e8e8", 200))

    def fish_stew(d):
        bowl(d, "c8a060", [(8, 12, "f0e0c0"), (13, 11, "e8783a"), (16, 13, "f0e0c0"), (11, 13, "60a040")])

    def porridge(d):
        bowl(d, "e8dcb8", [(9, 12, "f08a28"), (14, 11, "f08a28"), (12, 13, "c89858")])

    def reef_salad(d):
        bowl(d, "3e8a48", [(8, 12, "e8d8d0"), (13, 11, "8a3a9a"), (16, 13, "f4f4ee"), (11, 13, "5ab060")], steam=False)

    def forest_curry(d):
        bowl(d, "d89a28", [(8, 12, "8a5a30"), (13, 11, "fff8e8"), (16, 13, "8a5a30"), (11, 13, "a83018")])

    def peppered_boar(d):
        d.ellipse([2, 15, 22, 22], fill=c("c8c0b0"))
        d.ellipse([5, 9, 19, 19], fill=c("5a2a10"))
        d.ellipse([7, 10, 15, 15], fill=c("8a4a20"))
        for (x, y) in ((9, 12), (13, 13), (16, 15), (11, 16)):
            d.point((x, y), fill=c("1a1008"))

    def citrus_tart(d):
        d.chord([3, 8, 21, 22], 0, 180, fill=c("c89048"))
        d.ellipse([3, 9, 21, 16], fill=c("f0a020"))
        for (x, y) in ((8, 12), (12, 11), (16, 12)):
            d.pieslice([x - 3, y - 3, x + 3, y + 3], 0, 180, fill=c("ffd870"))
        d.line([(3, 14), (21, 14)], fill=c("a87030"))

    def island_skewers(d):
        for (dx, cols) in ((0, ("8a4a20", "f0a020", "8a4a20")), (5, ("f08a28", "8a4a20", "60a040"))):
            d.line([(3 + dx, 21), (16 + dx, 3)], fill=c("c8a070"))
            for k, col in enumerate(cols):
                x = 6 + dx + k * 3
                y = 17 - k * 4
                d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=c(col))

    def captains_feast(d):
        d.ellipse([1, 13, 23, 23], fill=c("d8c8a0"))
        d.ellipse([3, 8, 13, 18], fill=c("8a4a20"))
        d.line([(11, 10), (15, 6)], fill=c("eee4cc"), width=2)
        d.ellipse([12, 11, 21, 17], fill=c("c08048"))
        d.polygon([(20, 14), (23, 11), (23, 17)], fill=c("a86a38"))
        d.ellipse([15, 4, 20, 9], fill=c("f08a28"))
        d.point((17, 4), fill=c("4a9a30"))

    for name, fn in (("rice", rice), ("flour", flour), ("salt", salt), ("pepper", pepper), ("mushroom", mushroom),
                     ("seaweed", seaweed), ("coconut", coconut), ("egg", egg), ("oyster", oyster),
                     ("sea_urchin", sea_urchin), ("pearl", pearl), ("fish_stew", fish_stew), ("porridge", porridge),
                     ("reef_salad", reef_salad), ("forest_curry", forest_curry), ("peppered_boar", peppered_boar),
                     ("citrus_tart", citrus_tart), ("island_skewers", island_skewers), ("captains_feast", captains_feast)):
        _icon(name, fn)


# --------------------------------------------------------------------------
# Devil Fruit: the Ember Fruit's icon + swirl texture, and skill icons
# --------------------------------------------------------------------------
def gen_power_icons():
    Y = hexc("fff2a0") + (255,)
    O = hexc("ff9a2a") + (255,)
    R = hexc("e0441a") + (255,)
    D = hexc("8a1c0c") + (255,)
    W = (255, 255, 240, 255)

    def flame(d, cx, by, h, w):
        """A flame tongue: red outer, orange, yellow core."""
        for col, k in ((R, 1.0), (O, 0.72), (Y, 0.42)):
            hh, ww = h * k, w * k
            d.polygon([(cx - ww, by), (cx - ww * 0.8, by - hh * 0.45), (cx - ww * 0.2, by - hh * 0.7),
                       (cx, by - hh), (cx + ww * 0.35, by - hh * 0.55), (cx + ww, by - hh * 0.3), (cx + ww, by)], fill=col)

    def ember_fruit(d):
        # round fruit with curling swirls, a stem and a leaf
        d.ellipse([3, 5, 21, 22], fill=hexc("e8541c") + (255,))
        d.ellipse([5, 6, 15, 13], fill=hexc("ff8a3a") + (255,))
        for (x, y) in ((8, 15), (14, 11), (16, 17)):
            d.arc([x - 3, y - 3, x + 3, y + 3], 0, 300, fill=D)
            d.point((x, y), fill=D)
        d.line([(12, 6), (13, 2)], fill=hexc("5a3a1a") + (255,), width=1)
        d.polygon([(13, 3), (18, 1), (20, 4), (15, 5)], fill=hexc("4a9a30") + (255,))

    def fire_fist(d):
        # a fist trailing fire
        flame(d, 8, 20, 9, 7)
        d.polygon([(4, 15), (10, 9), (14, 13), (8, 19)], fill=O)
        d.rectangle([12, 8, 20, 16], fill=hexc("e8b088") + (255,))
        for x in (14, 16, 18):
            d.line([(x, 8), (x, 12)], fill=hexc("a06a48") + (255,))
        d.rectangle([12, 14, 16, 18], fill=hexc("d09070") + (255,))

    def flame_dash(d):
        # speed streaks of fire ending in a burst
        for i, y in enumerate((7, 12, 17)):
            d.line([(2 + i * 2, y), (15, y)], fill=R, width=2)
            d.line([(6 + i * 2, y), (15, y)], fill=O, width=1)
        flame(d, 17, 21, 16, 5)
        d.ellipse([15, 9, 21, 15], fill=Y)

    def fire_ring(d):
        d.ellipse([1, 13, 23, 22], outline=R, width=2)
        d.ellipse([3, 14, 21, 21], outline=O, width=1)
        for cx, by, h in ((3, 18, 8), (21, 18, 8), (7, 21, 9), (17, 21, 9), (8, 15, 6), (16, 15, 6)):
            flame(d, cx, by, h, 2.5)
        # a figure at the center, arms flung out
        K = hexc("3a2418") + (255,)
        d.rectangle([11, 9, 13, 17], fill=K)
        d.ellipse([10, 5, 14, 9], fill=K)
        d.line([(7, 9), (17, 9)], fill=K, width=1)

    def ember_field(d):
        d.polygon([(1, 20), (12, 15), (23, 20), (12, 23)], fill=hexc("6a1c08") + (255,))
        for cx, h in ((6, 9), (12, 14), (18, 10), (9, 7), (15, 8)):
            flame(d, cx, 20, h, 3)

    def inferno(d):
        # a pillar of fire on a burst ring
        d.ellipse([1, 16, 23, 23], fill=R)
        d.ellipse([4, 17, 20, 22], fill=O)
        flame(d, 12, 21, 21, 7)
        d.rectangle([10, 6, 14, 18], fill=Y)
        for (x, y) in ((3, 6), (21, 9), (5, 12), (19, 3)):
            d.point((x, y), fill=Y)

    _icon("ember_fruit", ember_fruit)
    _icon("skill_fire_fist", fire_fist)
    _icon("skill_flame_dash", flame_dash)
    _icon("skill_fire_ring", fire_ring)
    _icon("skill_ember_field", ember_field)
    _icon("skill_inferno", inferno)


def gen_devil_fruit_tex():
    """Ember Fruit skin: orange-red with dark curling swirls (tiles around)."""
    n = 32
    img = Image.new("RGB", (n, n), hexc("e05018"))
    d = ImageDraw.Draw(img)
    rng = np.random.default_rng(4242)
    for y in range(n):
        for x in range(n):
            if rng.random() < 0.25:
                d.point((x, y), fill=hexc("f06a28") if rng.random() < 0.6 else hexc("c8401a"))
    for (x, y) in ((6, 8), (22, 6), (14, 20), (28, 24), (4, 26)):
        for k in range(3):
            r = 5 - k * 1.6
            d.arc([x - r, y - r, x + r, y + r], 30 + k * 40, 330, fill=hexc("6a120a"))
    d.rectangle([0, 0, n, 2], fill=hexc("ff9a40"))
    save(img, "devil_fruit_ember")


# --------------------------------------------------------------------------
# Skill map icons (body techniques, sword, gun, Haki, Wolf and Vine fruits),
# the pistol, the Wolf / Vine fruit icons and their skins
# --------------------------------------------------------------------------
def gen_skill_icons():
    W_ = (255, 255, 245, 255)
    BLUE = hexc("8fd0ff") + (255,)
    BLUE_D = hexc("3a78c0") + (255,)
    STEEL = hexc("d0d8e0") + (255,)
    STEEL_D = hexc("7a8490") + (255,)
    GOLD = hexc("e8b850") + (255,)
    WOOD = hexc("7a4a28") + (255,)
    PURP = hexc("6a3a9a") + (255,)
    BLACK = hexc("1a1222") + (255,)
    PINK = hexc("f07ac0") + (255,)
    GREEN = hexc("5ac040") + (255,)
    GREEN_D = hexc("2e7a22") + (255,)
    FUR = hexc("a89880") + (255,)
    FUR_D = hexc("6a5a48") + (255,)
    RED = hexc("e04030") + (255,)
    SKIN = hexc("e8b088") + (255,)

    def soru(d):
        for i, x in enumerate((4, 9, 14)):
            a = 90 + i * 60
            d.rectangle([x, 6, x + 4, 18], fill=(150, 200, 255, a))
        d.ellipse([16, 5, 21, 10], fill=SKIN)
        d.rectangle([16, 10, 21, 18], fill=BLUE_D)
        d.line([(2, 20), (22, 20)], fill=BLUE, width=1)

    def tekkai(d):
        d.polygon([(12, 2), (21, 6), (19, 17), (12, 22), (5, 17), (3, 6)], fill=STEEL_D)
        d.polygon([(12, 4), (19, 7), (17, 16), (12, 20), (7, 16), (5, 7)], fill=STEEL)
        d.line([(8, 9), (16, 15)], fill=STEEL_D, width=2)
        d.line([(16, 9), (8, 15)], fill=STEEL_D, width=2)

    def flying_slash(d):
        d.arc([2, 3, 22, 21], 200, 340, fill=W_, width=3)
        d.arc([4, 6, 20, 19], 205, 335, fill=BLUE, width=2)
        d.line([(6, 20), (11, 15)], fill=STEEL, width=2)
        d.line([(4, 22), (6, 20)], fill=WOOD, width=2)

    def tiger_rush(d):
        for y in (8, 12, 16):
            d.line([(2, y), (12, y)], fill=BLUE, width=1)
        d.line([(10, 16), (22, 6)], fill=STEEL, width=2)
        d.line([(11, 17), (22, 8)], fill=STEEL_D)
        d.line([(8, 18), (11, 15)], fill=GOLD, width=2)

    def pistol_(d):
        d.rectangle([4, 8, 19, 11], fill=STEEL_D)
        d.rectangle([4, 7, 19, 8], fill=STEEL)
        d.polygon([(12, 10), (17, 10), (14, 20), (9, 20)], fill=WOOD)
        d.rectangle([9, 19, 14, 21], fill=GOLD)
        d.point((16, 6), fill=STEEL)

    def bullet_storm(d):
        for a in range(-2, 3):
            x2 = 20
            y2 = 12 + a * 4
            d.line([(8, 12), (x2, y2)], fill=GOLD, width=1)
            d.ellipse([x2 - 1, y2 - 1, x2 + 1, y2 + 1], fill=W_)
        d.rectangle([2, 10, 9, 13], fill=STEEL_D)
        d.polygon([(4, 12), (7, 12), (6, 18), (3, 18)], fill=WOOD)

    def armament(d):
        # a fist hardened black, crackling with purple
        for grow, col in ((1, PURP), (0, BLACK)):
            d.rectangle([6 - grow, 9 - grow, 18 + grow, 19 + grow], fill=col)
            for x in (7, 10, 13, 16):
                d.rectangle([x - grow, 6 - grow, x + 2 + grow, 10], fill=col)
            d.rectangle([4 - grow, 12 - grow, 7, 17 + grow], fill=col)
        d.line([(8, 12), (11, 14), (9, 16), (13, 18)], fill=hexc("c08ae8") + (255,))
        d.line([(19, 4), (21, 2)], fill=hexc("c08ae8") + (255,))
        d.line([(2, 8), (4, 10)], fill=hexc("c08ae8") + (255,))

    def foresight(d):
        d.ellipse([2, 7, 22, 17], fill=PINK)
        d.ellipse([7, 8, 17, 16], fill=W_)
        d.ellipse([9, 9, 15, 15], fill=PURP)
        d.ellipse([11, 11, 13, 13], fill=BLACK)
        for x, y in ((3, 3), (21, 4), (2, 20), (20, 21)):
            d.point((x, y), fill=PINK)

    def rending_fang(d):
        for i in range(3):
            x = 6 + i * 5
            d.line([(x, 3), (x + 4, 21)], fill=W_, width=2)
            d.line([(x + 1, 3), (x + 5, 21)], fill=RED, width=1)

    def pounce(d):
        d.arc([3, 6, 21, 26], 190, 350, fill=FUR, width=2)
        d.ellipse([15, 3, 21, 9], fill=FUR)
        d.polygon([(19, 3), (21, 0), (21, 4)], fill=FUR_D)
        for x in (2, 6, 10):
            d.line([(x, 20), (x + 2, 22)], fill=FUR_D)

    def howl(d):
        d.polygon([(6, 22), (8, 10), (12, 6), (16, 2), (17, 7), (14, 12), (14, 22)], fill=FUR)
        d.polygon([(15, 2), (18, 0), (18, 4)], fill=FUR_D)
        for r in (4, 7):
            d.arc([16 - r, 4 - r, 16 + r + 4, 4 + r + 4], 280, 360, fill=W_)

    def vine_snare(d):
        d.ellipse([9, 10, 15, 16], fill=hexc("8a6a3a") + (255,))
        for a, b in (((12, 10), (8, 3)), ((12, 10), (17, 4)), ((9, 14), (3, 18)), ((15, 14), (21, 19))):
            d.line([a, b], fill=GREEN_D, width=2)
            d.line([a, b], fill=GREEN, width=1)
        d.polygon([(7, 3), (10, 2), (9, 5)], fill=GREEN)
        d.polygon([(17, 4), (20, 3), (18, 6)], fill=GREEN)

    def vine_swing(d):
        d.line([(12, 1), (12, 4)], fill=GREEN_D, width=2)
        d.arc([2, -6, 22, 16], 20, 160, fill=GREEN_D, width=2)
        d.arc([2, -6, 22, 16], 20, 160, fill=GREEN, width=1)
        d.ellipse([3, 9, 8, 14], fill=SKIN)
        d.rectangle([4, 14, 8, 21], fill=BLUE_D)

    def thorn_whip(d):
        pts = [(2, 20), (7, 14), (11, 15), (15, 9), (19, 8), (22, 3)]
        d.line(pts, fill=GREEN_D, width=3)
        d.line(pts, fill=GREEN, width=1)
        for x, y in ((6, 15), (12, 13), (17, 8)):
            d.point((x, y - 2), fill=hexc("e8d8a0") + (255,))

    def fruit_icon(base, light, line_c, leaf):
        def f(d):
            d.ellipse([3, 5, 21, 22], fill=base)
            d.ellipse([5, 6, 15, 13], fill=light)
            for (x, y) in ((8, 15), (14, 11), (16, 17)):
                d.arc([x - 3, y - 3, x + 3, y + 3], 0, 300, fill=line_c)
                d.point((x, y), fill=line_c)
            d.line([(12, 6), (13, 2)], fill=hexc("5a3a1a") + (255,), width=1)
            d.polygon([(13, 3), (18, 1), (20, 4), (15, 5)], fill=leaf)
        return f

    _icon("skill_soru", soru)
    _icon("skill_tekkai", tekkai)
    _icon("skill_flying_slash", flying_slash)
    _icon("skill_tiger_rush", tiger_rush)
    _icon("pistol", pistol_)
    _icon("skill_bullet_storm", bullet_storm)
    _icon("skill_armament_coat", armament)
    _icon("skill_foresight", foresight)
    _icon("skill_rending_fang", rending_fang)
    _icon("skill_pounce", pounce)
    _icon("skill_howl", howl)
    _icon("skill_vine_snare", vine_snare)
    _icon("skill_vine_swing", vine_swing)
    _icon("skill_thorn_whip", thorn_whip)
    _icon("wolf_fruit", fruit_icon(hexc("8a8478") + (255,), hexc("b0aa9c") + (255,), hexc("3a3430") + (255,), hexc("4a9a30") + (255,)))
    _icon("vine_fruit", fruit_icon(hexc("4a9a36") + (255,), hexc("7ac85a") + (255,), hexc("1e5a18") + (255,), hexc("9ad860") + (255,)))


def gen_technique_icons():
    """Weapon and unarmed technique icons (TechniqueState) and Conqueror's Haki."""
    W_ = (255, 255, 245, 255)
    BLUE = hexc("8fd0ff") + (255,)
    STEEL = hexc("d0d8e0") + (255,)
    STEEL_D = hexc("7a8490") + (255,)
    GOLD = hexc("e8b850") + (255,)
    WOOD = hexc("7a4a28") + (255,)
    PINK = hexc("f0a0c8") + (255,)
    RED = hexc("e04030") + (255,)
    RED_D = hexc("8a1c18") + (255,)
    SKIN = hexc("e8b088") + (255,)
    SKIN_D = hexc("b07850") + (255,)
    SMOKE = hexc("9a9a96") + (255,)
    SMOKE_L = hexc("c8c8c4") + (255,)
    DUST = hexc("c8a878") + (255,)
    BLACK = hexc("1a1222") + (255,)
    PURP = hexc("6a3a9a") + (255,)

    def blade(d, a, b, w=2):
        d.line([a, b], fill=STEEL, width=w)

    def fist(d, x, y, col=SKIN, shade=SKIN_D):
        d.rectangle([x, y, x + 6, y + 5], fill=col)
        for k in (1, 3, 5):
            d.point((x + k, y), fill=shade)
        d.rectangle([x, y + 4, x + 3, y + 7], fill=shade)

    def riposte(d):
        # a blade held upright, a blow glancing off it in sparks
        blade(d, (12, 3), (12, 17))
        d.line([(9, 17), (15, 17)], fill=GOLD, width=1)
        d.line([(12, 18), (12, 22)], fill=WOOD, width=2)
        d.line([(2, 8), (10, 9)], fill=STEEL_D, width=2)
        for x, y in ((14, 6), (16, 4), (17, 8), (15, 10)):
            d.point((x, y), fill=GOLD)
        d.line([(15, 12), (21, 6)], fill=W_)

    def iai_counter(d):
        # a sheathed katana, the blade a hair out of the scabbard, a blow glancing off
        d.line([(3, 20), (19, 6)], fill=hexc("2a2230") + (255,), width=3)
        d.line([(16, 9), (21, 4)], fill=STEEL, width=1)
        d.ellipse([14, 8, 18, 12], fill=GOLD)
        d.line([(2, 6), (9, 9)], fill=STEEL_D, width=2)
        for x, y in ((10, 6), (12, 4), (12, 9)):
            d.point((x, y), fill=GOLD)

    def cross_counter(d):
        # two blades crossed upright, sparks where they meet
        blade(d, (6, 21), (17, 3))
        blade(d, (18, 21), (7, 3))
        for x, y in ((12, 9), (10, 8), (14, 8), (12, 11)):
            d.point((x, y), fill=GOLD)
        d.line([(1, 12), (6, 12)], fill=STEEL_D, width=2)

    def swordfish(d):
        for i, y in enumerate((5, 9, 13, 17, 21)):
            d.line([(4 + i, y), (20 - abs(2 - i) * 2, y)], fill=STEEL if i == 2 else BLUE, width=1)
        d.line([(1, 13), (6, 13)], fill=WOOD, width=2)

    def kraken(d):
        # a ring of cut marks round a centre
        for k in range(6):
            a = k * math.pi / 3
            x, y = 12 + math.cos(a) * 8, 12 + math.sin(a) * 8
            d.line([(x - 2, y - 2), (x + 2, y + 2)], fill=W_, width=1)
        d.arc([2, 2, 22, 22], 0, 360, fill=BLUE, width=1)
        blade(d, (8, 16), (16, 8))

    def wind_sever(d):
        d.arc([4, 0, 22, 26], 200, 330, fill=W_, width=3)
        d.arc([6, 2, 20, 24], 205, 325, fill=BLUE, width=2)
        d.line([(1, 22), (23, 22)], fill=DUST, width=1)
        d.line([(3, 20), (8, 15)], fill=STEEL, width=2)

    def twin_waves(d):
        # two blades of wind crossing in an X along the ground
        d.arc([1, 2, 19, 26], 210, 330, fill=W_, width=2)
        d.arc([5, 2, 23, 26], 210, 330, fill=BLUE, width=2)
        d.line([(4, 20), (20, 6)], fill=W_, width=1)
        d.line([(4, 6), (20, 20)], fill=BLUE, width=1)
        d.line([(1, 22), (23, 22)], fill=DUST, width=1)

    def side_step(d):
        # a fading figure on the left, the swordsman out to the side, the drawing cut across
        d.ellipse([3, 4, 7, 8], fill=(150, 200, 255, 90))
        d.rectangle([3, 8, 7, 18], fill=(150, 200, 255, 90))
        d.line([(8, 13), (13, 13)], fill=W_, width=1)
        d.ellipse([15, 5, 19, 9], fill=SKIN)
        d.rectangle([15, 9, 19, 18], fill=hexc("3a5a8a") + (255,))
        d.arc([4, 6, 22, 22], 150, 230, fill=STEEL, width=2)

    def falling_moon(d):
        # a full moon drawn by the blade over a figure turning, a crescent along the ground
        d.arc([3, 1, 21, 19], 0, 360, fill=W_, width=1)
        d.arc([5, 3, 19, 17], 200, 340, fill=BLUE, width=2)
        blade(d, (12, 10), (12, 2))
        d.arc([2, 18, 22, 26], 180, 360, fill=W_, width=2)

    def phantom(d):
        for i, x in enumerate((3, 8)):
            d.ellipse([x, 4, x + 4, 8], fill=(150, 200, 255, 80 + i * 60))
            d.rectangle([x, 8, x + 4, 18], fill=(150, 200, 255, 80 + i * 60))
        d.ellipse([15, 4, 19, 8], fill=SKIN)
        d.rectangle([15, 8, 19, 18], fill=hexc("3a5a8a") + (255,))
        blade(d, (17, 12), (23, 5))

    def petals(d):
        for x, y in ((4, 5), (16, 3), (20, 12), (6, 16), (13, 10), (10, 20), (19, 19)):
            d.ellipse([x - 2, y - 1, x + 2, y + 1], fill=PINK)
        d.line([(3, 21), (21, 3)], fill=STEEL, width=1)
        d.line([(2, 22), (5, 19)], fill=hexc("2a2230") + (255,), width=2)

    def axe_icon(d, cx, cy):
        d.line([(cx - 6, cy + 6), (cx + 4, cy - 4)], fill=WOOD, width=2)
        d.polygon([(cx + 1, cy - 7), (cx + 7, cy - 3), (cx + 4, cy + 1)], fill=STEEL)

    def axe_throw(d):
        d.arc([2, 3, 22, 21], 180, 360, fill=SMOKE_L, width=1)
        d.arc([2, 3, 22, 21], 0, 120, fill=SMOKE_L, width=1)
        axe_icon(d, 14, 11)

    def earthsplitter(d):
        d.polygon([(1, 18), (23, 18), (23, 23), (1, 23)], fill=hexc("6a4a2a") + (255,))
        d.line([(4, 18), (8, 21), (12, 18), (16, 22), (20, 19)], fill=BLACK, width=1)
        axe_icon(d, 10, 9)

    def berserk(d):
        d.ellipse([6, 4, 18, 16], fill=SKIN)
        d.polygon([(8, 11), (16, 11), (14, 15), (10, 15)], fill=RED_D)
        d.line([(8, 7), (11, 9)], fill=BLACK)
        d.line([(16, 7), (13, 9)], fill=BLACK)
        for x in (2, 21):
            d.line([(x, 4), (x, 14)], fill=RED, width=1)

    def maelstrom(d):
        for r, c in ((10, SMOKE_L), (7, BLUE), (4, W_)):
            d.arc([12 - r, 12 - r, 12 + r, 12 + r], 30, 300, fill=c, width=1)
        axe_icon(d, 13, 12)

    def blade_dance(d):
        d.arc([2, 4, 22, 20], 0, 360, fill=BLUE, width=1)
        blade(d, (4, 12), (11, 12))
        blade(d, (13, 12), (20, 12))
        d.ellipse([10, 9, 14, 15], fill=SKIN)

    def cross_fang(d):
        blade(d, (4, 4), (20, 20))
        blade(d, (20, 4), (4, 20))
        d.point([(12, 12)], fill=W_)
        d.line([(2, 22), (22, 22)], fill=DUST, width=1)

    def tempest(d):
        for k in range(8):
            a = k * math.pi / 4
            d.line([(12 + math.cos(a) * 4, 12 + math.sin(a) * 4), (12 + math.cos(a + 0.5) * 10, 12 + math.sin(a + 0.5) * 10)], fill=STEEL if k % 2 else BLUE)
        d.ellipse([10, 10, 14, 14], fill=SKIN)

    def gun(d, x, y):
        d.rectangle([x, y, x + 9, y + 2], fill=STEEL_D)
        d.polygon([(x + 5, y + 2), (x + 8, y + 2), (x + 6, y + 8), (x + 3, y + 8)], fill=WOOD)

    def deadeye(d):
        d.ellipse([9, 3, 23, 17], outline=RED, width=1)
        d.line([(16, 1), (16, 19)], fill=RED)
        d.line([(7, 10), (23, 10)], fill=RED)
        gun(d, 1, 14)

    def smoke_bomb(d):
        for x, y, r in ((7, 12, 6), (15, 10, 7), (11, 16, 5), (17, 17, 4)):
            d.ellipse([x - r, y - r, x + r, y + r], fill=SMOKE if r < 6 else SMOKE_L)
        d.ellipse([9, 17, 14, 22], fill=BLACK)
        d.line([(13, 17), (15, 15)], fill=GOLD)

    def point_blank(d):
        gun(d, 2, 9)
        for a in (-0.5, 0.0, 0.5):
            d.line([(12, 10), (12 + math.cos(a) * 10, 10 + math.sin(a) * 10)], fill=GOLD)
        d.ellipse([11, 8, 15, 12], fill=W_)

    def waltz(d):
        gun(d, 0, 4)
        gun(d, 13, 15)
        d.arc([3, 3, 21, 21], 200, 340, fill=GOLD, width=1)
        d.arc([3, 3, 21, 21], 20, 160, fill=GOLD, width=1)

    SCAR = hexc("ff5a42") + (255,)

    def parley(d):
        # a blade held across, a blow glancing off it, the pistol's muzzle flash below
        blade(d, (3, 6), (17, 10))
        d.line([(2, 2), (8, 6)], fill=STEEL_D, width=2)
        for x, y in ((9, 5), (11, 4), (10, 8)):
            d.point((x, y), fill=GOLD)
        gun(d, 6, 15)
        d.ellipse([16, 13, 21, 18], fill=SCAR)
        d.ellipse([17, 14, 20, 17], fill=W_)

    def grapeshot(d):
        # a pistol and a wide fan of shot
        gun(d, 1, 10)
        for a in (-0.7, -0.35, 0.0, 0.35, 0.7):
            d.line([(11, 11), (11 + math.cos(a) * 12, 11 + math.sin(a) * 12)], fill=GOLD if a else W_)
        d.ellipse([9, 9, 13, 13], fill=SCAR)

    def crossfire(d):
        # a dash line through a figure, a shot back into it
        d.line([(1, 16), (22, 16)], fill=SMOKE_L, width=1)
        body(d, 9, 6, hexc("3a5a8a") + (255,))
        blade(d, (14, 18), (22, 13))
        d.line([(3, 9), (9, 10)], fill=GOLD)
        d.ellipse([1, 7, 4, 10], fill=SCAR)

    def broadside(d):
        # a raised cutlass and cannon blasts bursting below it
        for x, y, r in ((5, 18, 4), (12, 20, 3), (19, 17, 4)):
            d.ellipse([x - r, y - r, x + r, y + r], fill=SCAR)
            d.ellipse([x - r + 2, y - r + 2, x + r - 2, y + r - 2], fill=GOLD)
        blade(d, (12, 13), (12, 1))
        d.line([(9, 13), (15, 13)], fill=GOLD, width=1)
        for x in (3, 21):
            d.line([(x, 4), (x, 9)], fill=SMOKE_L)

    def body(d, x, y, col):
        d.ellipse([x, y, x + 4, y + 4], fill=SKIN)
        d.rectangle([x, y + 4, x + 4, y + 11], fill=col)

    CRIM = hexc("f02a5c") + (255,)
    CRIM_D = hexc("6a1030") + (255,)
    VENOM = hexc("74f04c") + (255,)
    VENOM_L = hexc("d0ff5a") + (255,)

    def dagger(d, grip, tip, guard_col=GOLD):
        # a short blade from `grip` to `tip`, a cross guard and a dark grip behind it
        gx, gy = grip
        tx, ty = tip
        dx, dy = tx - gx, ty - gy
        n = max(math.hypot(dx, dy), 1.0)
        ux, uy = dx / n, dy / n
        d.line([(gx, gy), (tx, ty)], fill=STEEL, width=2)
        d.line([(gx - uy * 3, gy + ux * 3), (gx + uy * 3, gy - ux * 3)], fill=guard_col, width=1)
        d.line([(gx, gy), (gx - ux * 4, gy - uy * 4)], fill=WOOD, width=2)

    def slip(d):
        # a fading afterimage where the blow fell, you behind it with the blade in
        d.ellipse([3, 4, 7, 8], fill=(240, 60, 100, 90))
        d.rectangle([3, 8, 7, 18], fill=(240, 60, 100, 90))
        d.line([(1, 12), (9, 12)], fill=STEEL_D, width=2)
        body(d, 14, 5, hexc("3a2a4a") + (255,))
        dagger(d, (14, 13), (8, 11))

    def cutthroat(d):
        # a dagger drawn across a crimson line
        d.line([(3, 12), (21, 10)], fill=CRIM, width=2)
        for x, y in ((6, 14), (10, 15), (15, 14)):
            d.point((x, y), fill=CRIM_D)
        dagger(d, (18, 19), (8, 6))

    def knife_fan(d):
        for a in (-1.0, -0.5, 0.0, 0.5, 1.0):
            ang = -math.pi / 4 + a * 0.55
            x2, y2 = 3 + math.cos(ang) * 19, 21 + math.sin(ang) * 19
            dagger(d, (3 + math.cos(ang) * 9, 21 + math.sin(ang) * 9), (x2, y2), CRIM)

    def red_eclipse(d):
        d.ellipse([2, 2, 22, 22], fill=CRIM)
        d.ellipse([4, 3, 22, 21], fill=BLACK)
        dagger(d, (7, 17), (17, 7), CRIM)

    def viper_flurry(d):
        for i, y in enumerate((4, 8, 12, 16, 20)):
            x0 = 2 + (i % 2) * 3
            d.line([(x0, y), (16 + (i % 2) * 4, y)], fill=VENOM if i % 2 else STEEL, width=1)
            d.point((x0 - 1, y), fill=WOOD)
        d.ellipse([18, 9, 22, 15], fill=VENOM_L)

    def scissor_leap(d):
        d.arc([1, 4, 17, 26], 200, 330, fill=SMOKE_L, width=1)
        dagger(d, (12, 20), (22, 10), VENOM)
        dagger(d, (22, 20), (12, 10), VENOM)

    def bleeding_edge(d):
        dagger(d, (5, 19), (17, 5))
        dagger(d, (19, 19), (7, 5))
        for x, y in ((11, 15), (13, 18), (9, 20)):
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=CRIM)
        d.point((12, 9), fill=W_)

    def hundred_fangs(d):
        pts = [(12 + math.cos(k * 3 * math.pi / 4 - math.pi / 2) * 10, 12 + math.sin(k * 3 * math.pi / 4 - math.pi / 2) * 10) for k in range(9)]
        for k in range(8):
            d.line([pts[k], pts[k + 1]], fill=VENOM if k % 2 else VENOM_L, width=1)
        d.ellipse([10, 10, 14, 14], fill=W_)

    def hip_toss(d):
        body(d, 4, 10, hexc("3a5a8a") + (255,))
        d.arc([4, 0, 22, 18], 200, 340, fill=W_, width=1)
        d.ellipse([16, 2, 20, 6], fill=SKIN)
        d.rectangle([16, 6, 22, 9], fill=RED_D)

    def cannonball(d):
        # a straight punch, and a body bowled down the line into two more
        fist(d, 1, 9)
        d.line([(8, 12), (11, 12)], fill=W_)
        d.ellipse([11, 8, 17, 14], fill=RED_D)
        for x in (18, 21):
            d.line([(x, 7), (x + 2, 17)], fill=SMOKE_L, width=2)
        for y in (6, 18):
            d.line([(9, y), (16, y)], fill=W_)

    def meteor(d):
        # an overhand driven into cracked ground under dark star glints, a ring going out
        EMB = hexc("ffb030") + (255,)
        d.ellipse([2, 18, 22, 23], outline=EMB)
        for x0, x1 in ((12, 5), (12, 19), (12, 9), (12, 16)):
            d.line([(x0, 20), (x1, 23)], fill=BLACK)
        d.rectangle([10, 3, 14, 12], fill=SKIN_D)
        fist(d, 8, 11)
        d.ellipse([7, 10, 17, 19], outline=EMB)
        for cx, cy in ((4, 6), (20, 8)):
            d.line([(cx - 3, cy), (cx + 3, cy)], fill=RED)
            d.line([(cx, cy - 3), (cx, cy + 3)], fill=RED)
            d.point((cx, cy), fill=BLACK)

    def hundred(d):
        for x, y in ((2, 3), (9, 6), (3, 11), (10, 14), (4, 18)):
            fist(d, x + 6, y)
        for y in (5, 12, 19):
            d.line([(1, y), (6, y)], fill=W_)

    def rising_dragon(d):
        fist(d, 9, 2)
        d.rectangle([10, 9, 14, 20], fill=SKIN_D)
        for x in (5, 19):
            d.line([(x, 22), (x, 8)], fill=W_)
        d.arc([4, 6, 20, 26], 200, 340, fill=GOLD, width=1)

    def palm(d):
        d.rectangle([3, 8, 10, 16], fill=SKIN)
        for k in range(4):
            d.line([(10, 8 + k * 2), (13, 8 + k * 2)], fill=SKIN)
        for r in (4, 7, 10):
            d.arc([12 - r, 12 - r, 12 + r, 12 + r], -50, 50, fill=W_, width=1)

    def sea_king(d):
        fist(d, 2, 9)
        for y in (6, 10, 14, 18):
            d.line([(10, y), (23, y)], fill=SMOKE_L if y % 8 else W_, width=1)
        d.arc([8, 2, 24, 22], -60, 60, fill=BLUE, width=2)

    def conqueror(d):
        d.ellipse([3, 3, 21, 21], fill=BLACK)
        d.ellipse([6, 6, 18, 18], fill=PURP)
        for k in range(8):
            a = k * math.pi / 4
            d.line([(12 + math.cos(a) * 7, 12 + math.sin(a) * 7), (12 + math.cos(a) * 11, 12 + math.sin(a) * 11)], fill=RED)
        d.ellipse([10, 10, 14, 14], fill=RED)

    # storm (polearm), earth (hammer), frost (twin axes), gale (greatsword), heat (black-leg): FX.TREE_FX identities
    LEM = hexc("ffe652") + (255,)
    LEM_W = hexc("fffbd8") + (255,)
    VIO = hexc("9f7aff") + (255,)
    SAND = hexc("ebcd96") + (255,)
    SAND_D = hexc("8c765c") + (255,)
    ROCK = hexc("5a4a3a") + (255,)
    ICE = hexc("aee6ff") + (255,)
    ICE_D = hexc("5c8cff") + (255,)
    FROST = hexc("f5ffff") + (255,)
    JADE = hexc("bdffe1") + (255,)
    SEA = hexc("48cc9e") + (255,)
    HEAT = hexc("ff2c29") + (255,)
    HEAT_D = hexc("b50a1a") + (255,)
    HEAT_W = hexc("fff2d2") + (255,)

    def spear(d, a, b):
        ax, ay = a
        bx, by = b
        n = max(math.hypot(bx - ax, by - ay), 1.0)
        ux, uy = (bx - ax) / n, (by - ay) / n
        d.line([(ax, ay), (bx - ux * 4, by - uy * 4)], fill=WOOD, width=2)
        hx, hy = bx - ux * 5, by - uy * 5
        d.polygon([(hx - uy * 2, hy + ux * 2), (bx, by), (hx + uy * 2, hy - ux * 2)], fill=STEEL)

    def bolt(d, x, y, col, s=1.0):
        d.line([(x + 2 * s, y), (x - 1 * s, y + 4 * s), (x + 2 * s, y + 4 * s), (x - 1 * s, y + 9 * s)], fill=col, width=1)

    def hundred_thrusts(d):
        spear(d, (3, 12), (22, 12))
        for y, x0, x1 in ((6, 8, 17), (9, 4, 14), (15, 4, 14), (18, 8, 17)):
            d.line([(x0, y), (x1, y)], fill=LEM if y in (9, 15) else VIO, width=1)
        d.point((21, 6), fill=LEM_W)
        d.point((21, 18), fill=LEM_W)

    def dragon_sweep(d):
        d.line([(1, 20), (23, 20)], fill=DUST, width=1)
        d.arc([1, 8, 23, 24], 190, 350, fill=LEM, width=2)
        d.arc([4, 11, 20, 23], 200, 340, fill=VIO, width=1)
        spear(d, (3, 18), (20, 14))
        d.point((20, 22), fill=LEM_W)

    def vault_strike(d):
        d.line([(1, 22), (23, 22)], fill=DUST, width=1)
        d.line([(4, 22), (7, 13)], fill=WOOD, width=2)
        d.arc([3, 1, 21, 21], 200, 310, fill=VIO, width=1)
        spear(d, (12, 3), (18, 18))
        for x, y in ((16, 21), (20, 20), (14, 20)):
            d.point((x, y), fill=LEM)
        d.ellipse([17, 17, 20, 20], fill=LEM_W)

    def raijin_wheel(d):
        for r, c in ((10, VIO), (7, LEM)):
            d.arc([12 - r, 12 - r, 12 + r, 12 + r], 20, 330, fill=c, width=2 if r == 10 else 1)
        spear(d, (3, 3), (21, 21))
        spear(d, (21, 3), (3, 21))
        bolt(d, 10, 7, LEM_W, 0.8)

    def thunder_javelin(d):
        # the spear flying point-first along a line, the lightning tether jagging back from its butt
        for x, c in ((2, VIO), (5, LEM)):
            d.line([(x, 16), (x + 6, 13)], fill=c, width=1)
        spear(d, (7, 14), (22, 7))
        d.line([(7, 14), (5, 17), (8, 18), (4, 22)], fill=LEM_W, width=1)
        for x, y in ((15, 13), (18, 12), (12, 15)):
            d.point((x, y), fill=VIO)
        d.point((22, 7), fill=LEM_W)

    def windmill_guard(d):
        # the pole spun upright in a ring before you, a shot glancing off it
        d.ellipse([3, 3, 21, 21], outline=VIO, width=1)
        d.arc([5, 5, 19, 19], 200, 340, fill=LEM, width=2)
        spear(d, (5, 19), (19, 5))
        d.line([(20, 20), (23, 23)], fill=LEM_W, width=1)
        d.line([(17, 15), (20, 20)], fill=STEEL, width=1)
        d.point((16, 14), fill=LEM_W)

    def hammer_head(d, cx, cy, w=10, h=6, col=SAND, shade=SAND_D):
        d.rectangle([cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2], fill=col)
        d.rectangle([cx - w // 2, cy + h // 2 - 1, cx + w // 2, cy + h // 2], fill=shade)
        d.line([(cx - w // 2, cy - h // 2), (cx - w // 2, cy + h // 2)], fill=ROCK, width=1)

    def skullcracker(d):
        d.line([(12, 1), (12, 10)], fill=WOOD, width=2)
        hammer_head(d, 12, 10, 12, 5)
        d.ellipse([6, 14, 18, 22], fill=W_)
        d.rectangle([9, 21, 15, 23], fill=SMOKE_L)
        for x, y in ((9, 17), (9, 18), (15, 17), (15, 18)):
            d.point((x, y), fill=BLACK)
        d.line([(12, 14), (11, 17), (13, 19)], fill=ROCK)
        for x in (3, 21):
            d.line([(x, 8), (x, 13)], fill=SAND)

    def rolling_quake(d):
        for i, (x, r) in enumerate(((5, 3), (12, 5), (19, 7))):
            d.ellipse([x - r, 21 - r // 2, x + r, 23], outline=SAND if i < 2 else W_)
            d.line([(x, 20), (x - 1, 20 - 2 - i * 2)], fill=ROCK, width=2)
            hammer_head(d, x, 17 - i * 2 - 2, 4 + i * 2, 3 + i, SAND, SAND_D)
        d.point((3, 15), fill=SAND_D)
        d.point((22, 9), fill=SAND_D)

    def cyclone_crusher(d):
        d.arc([2, 2, 22, 22], 30, 300, fill=SAND, width=1)
        d.arc([5, 5, 19, 19], 60, 330, fill=SAND_D, width=1)
        d.line([(12, 12), (19, 6)], fill=WOOD, width=2)
        hammer_head(d, 19, 6, 7, 6)
        d.ellipse([9, 9, 15, 15], fill=SKIN)
        d.line([(2, 20), (7, 21)], fill=ROCK, width=2)

    def titans_fall(d):
        d.line([(11, 2), (11, 12)], fill=WOOD, width=3)
        hammer_head(d, 11, 5, 16, 8)
        d.rectangle([3, 3, 19, 4], fill=W_)
        d.ellipse([1, 17, 23, 23], outline=SAND)
        for x0, x1 in ((11, 3), (11, 19), (11, 7), (11, 15)):
            d.line([(x0, 19), (x1, 23)], fill=BLACK)
        for x, y in ((3, 15), (20, 14), (6, 11), (18, 9)):
            d.rectangle([x, y, x + 2, y + 2], fill=SAND_D)

    def cannonball_swing(d):
        # the head swept up from low behind in an arc, a body flying off it up and away, dust where it scraped
        d.arc([2, 4, 22, 28], 120, 250, fill=SAND_D, width=1)
        d.line([(9, 21), (3, 15)], fill=WOOD, width=2)
        hammer_head(d, 3, 13, 5, 6)
        d.ellipse([16, 3, 21, 8], fill=SKIN)
        d.line([(18, 8), (14, 12)], fill=SMOKE_L, width=2)
        for x, y in ((9, 10), (12, 8), (11, 12)):
            d.point((x, y), fill=W_)
        d.line([(1, 23), (8, 23)], fill=SAND, width=1)
        d.point((10, 22), fill=ROCK)

    def anvil_counter(d):
        # the hammer planted head-down, a blow ringing off the haft, the ground cracked under the head
        d.line([(12, 2), (12, 16)], fill=WOOD, width=2)
        hammer_head(d, 12, 18, 10, 5)
        d.rectangle([10, 1, 14, 3], fill=SKIN)
        d.arc([4, 4, 20, 14], 200, 340, fill=W_, width=1)
        d.line([(20, 7), (15, 9)], fill=STEEL, width=1)
        for x, y in ((16, 6), (17, 10), (14, 7)):
            d.point((x, y), fill=W_)
        d.line([(3, 23), (8, 21), (12, 23), (17, 21), (22, 23)], fill=ROCK, width=1)

    def chain(d, a, b, col=SMOKE_L):
        for k in range(1, 7):
            t = k / 7
            d.point((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t + math.sin(t * math.pi) * 3), fill=col)

    def gallows_hook(d):
        axe_icon(d, 6, 14)
        chain(d, (10, 12), (17, 8))
        d.arc([15, 3, 23, 12], 270, 120, fill=ICE_D, width=2)
        d.ellipse([18, 10, 22, 14], fill=SKIN)
        d.line([(19, 14), (22, 14)], fill=ICE, width=1)
        d.point((20, 16), fill=FROST)

    def hewing_frenzy(d):
        axe_icon(d, 7, 11)
        axe_icon(d, 17, 13)
        for x0, y0, x1, y1 in ((2, 4, 9, 2), (13, 3, 21, 5), (3, 20, 10, 22)):
            d.line([(x0, y0), (x1, y1)], fill=ICE, width=1)
        for x, y in ((12, 19), (14, 21), (11, 22)):
            d.point((x, y), fill=FROST)
        d.line([(10, 8), (16, 16)], fill=ICE_D, width=1)

    def axestorm(d):
        d.arc([2, 2, 22, 22], 0, 360, fill=ICE, width=1)
        d.arc([6, 6, 18, 18], 40, 320, fill=ICE_D, width=1)
        axe_icon(d, 5, 7)
        axe_icon(d, 19, 17)
        d.ellipse([10, 10, 14, 14], fill=FROST)

    def fimbulwinter(d):
        for k in range(6):
            a = k * math.pi / 3
            x2, y2 = 12 + math.cos(a) * 11, 12 + math.sin(a) * 11
            d.line([(12, 12), (x2, y2)], fill=ICE if k % 2 else FROST, width=1)
            mx, my = 12 + math.cos(a) * 7, 12 + math.sin(a) * 7
            for s in (-1, 1):
                d.line([(mx, my), (mx + math.cos(a + s * 0.9) * 3, my + math.sin(a + s * 0.9) * 3)], fill=ICE_D)
        blade(d, (6, 18), (18, 6))
        blade(d, (18, 18), (6, 6))
        d.ellipse([10, 10, 14, 14], fill=ICE_D)

    def ravens_return(d):
        # two loops fanning out from the bottom, crossing at the top, an axe flying on each
        d.ellipse([2, 2, 14, 22], outline=ICE_D, width=1)
        d.ellipse([10, 2, 22, 22], outline=SMOKE_L, width=1)
        axe_icon(d, 6, 9)
        axe_icon(d, 18, 9)
        d.ellipse([10, 19, 14, 23], fill=SKIN)
        for x, y in ((12, 3), (10, 5), (14, 5)):
            d.point((x, y), fill=FROST)

    def raiders_haul(d):
        # a body swung round at the end of a hooked haft, the circle of the swing round you, a foe bowled over ahead
        d.arc([3, 3, 21, 21], 200, 520, fill=ICE_D, width=1)
        d.ellipse([10, 10, 14, 14], fill=SKIN)
        d.line([(12, 12), (19, 6)], fill=WOOD, width=2)
        d.polygon([(18, 4), (22, 5), (20, 8)], fill=STEEL)
        d.ellipse([18, 1, 23, 6], fill=SKIN)
        d.line([(2, 19), (7, 22)], fill=SMOKE_L, width=2)
        for x, y in ((4, 17), (8, 20), (3, 22)):
            d.point((x, y), fill=FROST)

    def greatblade(d, a, b, col=STEEL):
        ax, ay = a
        bx, by = b
        n = max(math.hypot(bx - ax, by - ay), 1.0)
        ux, uy = (bx - ax) / n, (by - ay) / n
        d.line([(ax, ay), (bx, by)], fill=col, width=4)
        d.line([(ax, ay), (bx, by)], fill=W_, width=1)
        gx, gy = ax + ux * 4, ay + uy * 4
        d.line([(gx - uy * 5, gy + ux * 5), (gx + uy * 5, gy - ux * 5)], fill=GOLD, width=2)
        d.line([(ax, ay), (ax - ux * 4, ay - uy * 4)], fill=WOOD, width=2)

    def guardbreaker(d):
        greatblade(d, (12, 10), (12, 1))
        d.polygon([(4, 14), (20, 14), (18, 21), (12, 23), (6, 21)], fill=STEEL_D)
        d.line([(12, 13), (10, 18), (13, 22)], fill=BLACK)
        for x, y in ((3, 18), (21, 17), (7, 23), (17, 23)):
            d.rectangle([x, y, x + 1, y + 1], fill=JADE)
        d.line([(2, 12), (6, 14)], fill=SEA)
        d.line([(22, 12), (18, 14)], fill=SEA)

    def crescent_gale(d):
        greatblade(d, (2, 18), (13, 8))
        d.arc([4, 1, 22, 21], 285, 75, fill=JADE, width=2)
        d.arc([7, 4, 19, 18], 290, 70, fill=SEA, width=1)
        for y in (6, 12, 21):
            d.line([(2, y), (8, y)], fill=SEA)

    def tempest_turns(d):
        for r, c in ((10, SEA), (7, JADE), (4, W_)):
            d.arc([12 - r, 12 - r, 12 + r, 12 + r], 20 + r * 12, 300 + r * 12, fill=c, width=1)
        greatblade(d, (4, 20), (19, 5))
        d.ellipse([10, 10, 14, 14], fill=SKIN)
        d.point((12, 12), fill=W_)

    def updraft(d):
        # the rising cut, a gust swept up under a foe thrown high
        greatblade(d, (3, 22), (15, 8))
        for x, c in ((15, SEA), (19, JADE)):
            d.arc([x - 4, 6, x + 4, 22], 280, 80, fill=c, width=1)
        d.ellipse([16, 1, 21, 6], fill=SKIN)
        d.line([(18, 6), (18, 9)], fill=BLUE, width=2)
        for x in (6, 10):
            d.line([(x, 23), (x + 2, 18)], fill=SEA)

    def gatekeeper(d):
        # the blade driven point-down before you, a shot stopped on its flat
        d.line([(1, 22), (23, 22)], fill=ROCK)
        greatblade(d, (11, 3), (11, 21))
        d.rectangle([7, 4, 15, 5], fill=STEEL_D)
        d.line([(23, 12), (17, 12)], fill=LEM_W)
        for x, y in ((15, 10), (15, 14), (14, 12)):
            d.point((x, y), fill=JADE)
        d.arc([3, 0, 19, 16], 200, 340, fill=SEA, width=1)

    def skysplitter(d):
        greatblade(d, (12, 12), (12, 0))
        d.line([(12, 15), (10, 18), (13, 20), (11, 23)], fill=BLACK, width=2)
        d.line([(12, 15), (10, 18), (13, 20), (11, 23)], fill=JADE, width=1)
        for x in (3, 20):
            d.arc([x - 6, 14, x + 6, 28], 200, 340, fill=SEA if x < 10 else JADE, width=1)
        d.line([(4, 6), (8, 8)], fill=SEA)
        d.line([(20, 6), (16, 8)], fill=SEA)

    def leg(d, hip, foot, col=HEAT_D, boot=BLACK):
        d.line([hip, foot], fill=col, width=4)
        fx, fy = foot
        d.rectangle([fx - 1, fy - 2, fx + 4, fy + 2], fill=boot)

    def rising_heel(d):
        # a leg swung straight up the front, a foe's head knocked up off the heel, lines of the launch
        d.line([(1, 22), (23, 22)], fill=DUST, width=1)
        leg(d, (6, 22), (7, 14), HEAT_D)
        leg(d, (7, 14), (9, 3), HEAT)
        d.line([(7, 14), (9, 3)], fill=HEAT_W, width=1)
        d.ellipse([14, 2, 19, 7], fill=SKIN)
        for x in (15, 18, 21):
            d.line([(x, 10), (x, 15)], fill=HEAT_W)
        d.arc([4, -2, 16, 10], 200, 320, fill=HEAT, width=1)

    def hailstorm_heels(d):
        leg(d, (3, 20), (4, 12), HEAT_D)
        for a in (-0.9, -0.45, 0.0, 0.45):
            ex, ey = 6 + math.cos(a) * 14, 12 + math.sin(a) * 14
            d.line([(6, 12), (ex, ey)], fill=HEAT if a else HEAT_W, width=1)
            d.ellipse([ex - 1, ey - 1, ex + 1, ey + 1], fill=HEAT_W)
        d.ellipse([18, 16, 23, 21], fill=HEAT_D)
        d.line([(9, 21), (16, 21)], fill=HEAT_W)

    def sky_chase(d):
        # a ring stamped on the air below, a body carried up to a foe tumbling above, a heel on its way down
        d.ellipse([2, 19, 12, 22], outline=HEAT_W)
        d.line([(7, 18), (10, 11)], fill=HEAT_D, width=1)
        leg(d, (9, 13), (16, 7), HEAT)
        d.line([(9, 13), (16, 7)], fill=HEAT_W, width=1)
        d.ellipse([16, 1, 21, 6], fill=SKIN)
        d.line([(17, 6), (22, 9)], fill=BLUE, width=2)
        for x in (3, 5):
            d.line([(x, 9), (x, 15)], fill=HEAT_W)

    def last_course(d):
        d.ellipse([1, 17, 23, 23], outline=HEAT)
        for x, h in ((4, 5), (8, 7), (12, 9), (16, 7), (20, 5)):
            d.polygon([(x - 2, 20), (x, 20 - h), (x + 2, 20)], fill=HEAT if h < 9 else HEAT_W)
        leg(d, (6, 2), (14, 13), HEAT)
        d.line([(6, 2), (14, 13)], fill=HEAT_W, width=1)
        d.rectangle([13, 12, 18, 16], fill=BLACK)
        for x, y in ((3, 8), (20, 6), (19, 12)):
            d.line([(x, y), (x + 2, y - 4)], fill=HEAT)

    def cleaver_kick(d):
        # a leg swung up over the top, its crescent of air flung off the foot down the line
        d.arc([1, 3, 15, 17], 200, 330, fill=HEAT_D, width=1)
        leg(d, (5, 22), (9, 5), HEAT)
        d.line([(5, 22), (9, 5)], fill=HEAT_W, width=1)
        d.arc([10, 3, 22, 21], 290, 70, fill=HEAT, width=3)
        d.arc([12, 5, 20, 19], 300, 60, fill=HEAT_W, width=1)
        for y in (8, 12, 16):
            d.line([(3, y + 1), (6, y)], fill=HEAT_W)

    def flambe_dash(d):
        # a flying side kick streaking along the line, a trail of crimson fire behind it
        for x, h in ((2, 4), (5, 6), (8, 5), (11, 7)):
            d.polygon([(x - 2, 16), (x, 16 - h), (x + 2, 16)], fill=HEAT_D if h < 6 else HEAT)
        d.line([(1, 14), (12, 14)], fill=HEAT_W, width=1)
        leg(d, (11, 12), (20, 12), HEAT)
        d.line([(11, 12), (20, 12)], fill=HEAT_W, width=1)
        leg(d, (11, 13), (13, 18), HEAT_D)
        d.ellipse([7, 6, 11, 10], fill=SKIN)
        d.line([(9, 10), (11, 12)], fill=BLACK, width=2)

    for name, fn in (("cleaver_kick", cleaver_kick), ("flambe_dash", flambe_dash)):
        _icon("skill_" + name, fn)

    # --- 1.24 ranged kinds: long guns (starlight), the cannon (brimstone), the slingshot (trickster's spark) ---
    STAR = hexc("c8dcff") + (255,)
    INDIGO = hexc("5a62e6") + (255,)
    SULPH = hexc("ffd040") + (255,)
    VIOLET = hexc("9a48d8") + (255,)
    IRON = hexc("4a4a50") + (255,)
    BRONZE = hexc("d89850") + (255,)
    HOTPINK = hexc("ff60b8") + (255,)
    TANG = hexc("ffa030") + (255,)
    FIREC = hexc("ff7020") + (255,)
    TAR = hexc("2a2418") + (255,)

    def musket(d, a, b):
        # a long gun from the butt `a` to the muzzle `b`: the wooden stock, the steel barrel on along it
        ax, ay = a
        bx, by = b
        mx, my = ax + (bx - ax) * 0.35, ay + (by - ay) * 0.35
        d.line([(ax, ay), (mx, my)], fill=WOOD, width=3)
        d.line([(mx, my), (bx, by)], fill=STEEL, width=1)
        d.line([(mx, my + 1), (ax + (bx - ax) * 0.7, ay + (by - ay) * 0.7 + 1)], fill=WOOD, width=1)

    def puff(d, x, y, r=3, col=SMOKE_L):
        d.ellipse([x - r, y - r, x + r, y + r], fill=col)

    def pin_shot(d):
        # a shot streaking into a foe, a ring at its feet nailing it to the ground
        musket(d, (1, 14), (12, 12))
        d.line([(12, 12), (19, 11)], fill=STAR, width=1)
        d.ellipse([17, 4, 21, 8], fill=SKIN)
        d.rectangle([17, 8, 21, 17], fill=BLUE)
        d.ellipse([13, 18, 23, 22], outline=INDIGO)
        for x in (14, 22):
            d.line([(x, 17), (x, 21)], fill=STAR)

    def powder_burst(d):
        # fired from the hip: a cone of fire and shot, the smoke rolling
        musket(d, (1, 18), (9, 15))
        d.polygon([(9, 15), (22, 7), (22, 22)], fill=FIREC)
        d.polygon([(9, 15), (18, 11), (18, 19)], fill=SULPH)
        for x, y in ((20, 9), (21, 14), (19, 19), (16, 12)):
            d.point((x, y), fill=W_)
        puff(d, 6, 9, 3)

    def volley_line(d):
        # three shots fanned out to three foes
        musket(d, (1, 13), (8, 12))
        for y in (4, 12, 20):
            d.line([(8, 12), (19, y)], fill=STAR, width=1)
            d.ellipse([19, y - 2, 23, y + 2], fill=SKIN)
        puff(d, 9, 10, 2)

    def stock_sweep(d):
        # the gun swung round butt first, an arc of air behind it
        d.arc([2, 2, 22, 22], 30, 300, fill=STAR, width=1)
        musket(d, (19, 9), (5, 16))
        d.rectangle([18, 7, 21, 11], fill=WOOD)

    def hawkeye(d):
        # a sight's ring on the foes, shots falling on each like stars
        d.ellipse([3, 3, 21, 21], outline=STAR)
        d.line([(12, 1), (12, 7)], fill=STAR)
        d.line([(12, 17), (12, 23)], fill=STAR)
        d.line([(1, 12), (7, 12)], fill=STAR)
        d.line([(17, 12), (23, 12)], fill=STAR)
        for x, y in ((9, 10), (15, 14)):
            d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=W_)
            d.line([(x + 4, y - 6), (x, y)], fill=INDIGO)

    def cannon(d, a, b, col=BRONZE):
        # a hand cannon from the breech `a` to the muzzle `b`
        d.line([a, b], fill=col, width=5)
        d.line([a, b], fill=W_ if col == BRONZE else STEEL_D, width=1)
        d.ellipse([b[0] - 3, b[1] - 3, b[0] + 3, b[1] + 3], fill=IRON)

    def blast(d, x, y, r):
        d.ellipse([x - r, y - r, x + r, y + r], fill=FIREC)
        d.ellipse([x - r // 2, y - r // 2, x + r // 2, y + r // 2], fill=SULPH)
        for k in range(6):
            a = k * math.pi / 3
            d.point((x + math.cos(a) * (r + 2), y + math.sin(a) * (r + 2)), fill=VIOLET)

    def canister_shot(d):
        cannon(d, (1, 16), (8, 13))
        for k in range(7):
            a = -0.55 + k * 0.18
            d.point((10 + math.cos(a) * 12, 13 + math.sin(a) * 12), fill=SULPH)
            d.point((10 + math.cos(a) * 7, 13 + math.sin(a) * 7), fill=IRON)
        puff(d, 9, 9, 3)

    def chain_shot(d):
        # two balls on a chain spinning down the line
        d.arc([4, 4, 20, 20], 200, 340, fill=SMOKE_L, width=1)
        d.line([(6, 16), (18, 8)], fill=STEEL_D, width=1)
        for x, y in ((6, 16), (18, 8)):
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=IRON)
            d.point((x - 1, y - 1), fill=STEEL)

    def mortar_lob(d):
        # three shells on high arcs onto the ground ahead
        cannon(d, (2, 22), (6, 15))
        for x in (14, 18, 22):
            d.arc([4, 4, 2 * x - 4, 40], 200, 270, fill=SMOKE_L, width=1)
            d.ellipse([x - 2, 19, x + 2, 23], fill=FIREC)

    def rocket_charge(d):
        # fired backwards: the blast behind, the gunner hurled forward through a foe
        blast(d, 4, 14, 3)
        cannon(d, (13, 12), (7, 14))
        d.ellipse([12, 6, 16, 10], fill=SKIN)
        for y in (9, 13, 17):
            d.line([(17, y), (22, y)], fill=SULPH)

    def leviathan_shell(d):
        cannon(d, (1, 22), (8, 15), IRON)
        blast(d, 17, 9, 6)
        d.ellipse([9, 2, 23, 16], outline=VIOLET)
        for x in (12, 21):
            d.line([(x, 17), (x - 2, 23)], fill=FIREC)

    def fork(d, x, y):
        # a slingshot's fork, its band drawn back
        d.line([(x, y + 7), (x, y + 2)], fill=WOOD, width=2)
        d.line([(x, y + 2), (x - 3, y - 2)], fill=WOOD, width=2)
        d.line([(x, y + 2), (x + 3, y - 2)], fill=WOOD, width=2)

    def pellet(d, x, y, col):
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=col)
        d.point((x - 1, y - 1), fill=W_)

    def fire_pellet(d):
        fork(d, 4, 13)
        d.line([(8, 12), (14, 10)], fill=TANG)
        for x, h in ((15, 5), (18, 8), (21, 5)):
            d.polygon([(x - 2, 20), (x, 20 - h), (x + 2, 20)], fill=FIREC)
        pellet(d, 18, 10, SULPH)

    def smoke_pellet(d):
        fork(d, 4, 13)
        for x, y, r in ((15, 12, 5), (19, 8, 3), (19, 16, 4), (11, 9, 3)):
            puff(d, x, y, r, SMOKE if r > 4 else SMOKE_L)
        pellet(d, 9, 13, SMOKE)

    def blast_pellet(d):
        fork(d, 4, 13)
        blast(d, 17, 11, 4)
        d.line([(7, 12), (12, 11)], fill=TANG)

    def sticky_pellet(d):
        fork(d, 4, 13)
        d.ellipse([11, 15, 23, 21], fill=TAR)
        for x in (13, 17, 21):
            d.line([(x, 15), (x, 11)], fill=TAR, width=1)
        pellet(d, 17, 9, TAR)

    def bag_of_tricks(d):
        # a fan of five pellets of every colour
        fork(d, 4, 14)
        for k, col in enumerate((FIREC, TAR, SULPH, SMOKE, HOTPINK)):
            a = -0.7 + k * 0.35
            d.line([(7, 14), (7 + math.cos(a) * 9, 14 + math.sin(a) * 9)], fill=TANG)
            pellet(d, 7 + math.cos(a) * 13, 14 + math.sin(a) * 13, col)

    for name, fn in (("pin_shot", pin_shot), ("powder_burst", powder_burst), ("volley_line", volley_line), ("stock_sweep", stock_sweep),
                     ("hawkeye", hawkeye), ("canister_shot", canister_shot), ("chain_shot", chain_shot), ("mortar_lob", mortar_lob),
                     ("rocket_charge", rocket_charge), ("leviathan_shell", leviathan_shell), ("fire_pellet", fire_pellet),
                     ("smoke_pellet", smoke_pellet), ("blast_pellet", blast_pellet), ("sticky_pellet", sticky_pellet),
                     ("bag_of_tricks", bag_of_tricks)):
        _icon("skill_" + name, fn)

    for name, fn in (("riposte", riposte), ("iai_counter", iai_counter), ("cross_counter", cross_counter),
                     ("swordfish", swordfish), ("kraken_wake", kraken),
                     ("wind_sever", wind_sever), ("phantom_step", phantom), ("petal_storm", petals),
                     ("twin_waves", twin_waves), ("side_step", side_step), ("falling_moon", falling_moon),
                     ("axe_throw", axe_throw), ("earthsplitter", earthsplitter), ("berserk", berserk), ("maelstrom", maelstrom),
                     ("blade_dance", blade_dance), ("cross_fang", cross_fang), ("steel_tempest", tempest),
                     ("parley", parley), ("grapeshot", grapeshot), ("crossfire", crossfire), ("broadside", broadside),
                     ("deadeye", deadeye), ("smoke_bomb", smoke_bomb), ("point_blank", point_blank), ("deaths_waltz", waltz),
                     ("hip_toss", hip_toss), ("cannonball_fist", cannonball), ("meteor_fist", meteor),
                     ("hundred_fists", hundred), ("rising_dragon", rising_dragon), ("palm_strike", palm),
                     ("sea_king_fist", sea_king), ("conquerors_haki", conqueror),
                     ("slip", slip), ("cutthroat", cutthroat), ("knife_fan", knife_fan), ("red_eclipse", red_eclipse),
                     ("viper_flurry", viper_flurry), ("scissor_leap", scissor_leap), ("bleeding_edge", bleeding_edge),
                     ("hundred_fangs", hundred_fangs),
                     ("hundred_thrusts", hundred_thrusts), ("dragon_sweep", dragon_sweep), ("vault_strike", vault_strike),
                     ("raijin_wheel", raijin_wheel), ("thunder_javelin", thunder_javelin), ("windmill_guard", windmill_guard),
                     ("skullcracker", skullcracker), ("rolling_quake", rolling_quake),
                     ("cyclone_crusher", cyclone_crusher), ("titans_fall", titans_fall),
                     ("cannonball_swing", cannonball_swing), ("anvil_counter", anvil_counter), ("gallows_hook", gallows_hook),
                     ("hewing_frenzy", hewing_frenzy), ("axestorm", axestorm), ("fimbulwinter", fimbulwinter),
                     ("ravens_return", ravens_return), ("raiders_haul", raiders_haul),
                     ("guardbreaker", guardbreaker), ("crescent_gale", crescent_gale), ("tempest_turns", tempest_turns), ("updraft", updraft), ("gatekeeper", gatekeeper),
                     ("skysplitter", skysplitter), ("rising_heel", rising_heel), ("hailstorm_heels", hailstorm_heels),
                     ("sky_chase", sky_chase), ("last_course", last_course)):
        _icon("skill_" + name, fn)


def gen_move_icons():
    """The Adventure trees' moves (Acrobatics, Defense, Swimming): a node's "icon" in SkillTrees (skill_move_<name>)."""
    W_ = (255, 255, 245, 255)
    SKY = hexc("a8dcff") + (255,)
    BLUE = hexc("5aa8e8") + (255,)
    SEA = hexc("2e6ea8") + (255,)
    FOAM = hexc("e8f6ff") + (255,)
    MOON = hexc("f4eec0") + (255,)
    DUST = hexc("c8a878") + (255,)
    DUST_D = hexc("8a6e4c") + (255,)
    STEEL = hexc("d0d8e0") + (255,)
    STEEL_D = hexc("7a8490") + (255,)
    GOLD = hexc("e8b850") + (255,)
    WOOD = hexc("7a4a28") + (255,)
    SKIN = hexc("e8b088") + (255,)
    BODY = hexc("3a5aa0") + (255,)
    GHOST = hexc("b8dcff") + (255,)
    GREEN = hexc("9ce08a") + (255,)

    def figure(d, x, y, col=BODY):
        # a little standing body: head, trunk, legs
        d.ellipse([x - 2, y, x + 2, y + 4], fill=SKIN)
        d.rectangle([x - 2, y + 5, x + 2, y + 11], fill=col)
        d.line([(x - 1, y + 12), (x - 2, y + 17)], fill=col, width=2)
        d.line([(x + 1, y + 12), (x + 2, y + 17)], fill=col, width=2)

    def roll(d):
        # a body tucked into a ball, the arc of the roll over it, dust behind
        d.arc([3, 3, 21, 21], 200, 20, fill=W_, width=1)
        d.ellipse([7, 9, 17, 19], fill=BODY)
        d.ellipse([9, 10, 13, 14], fill=SKIN)
        d.polygon([(19, 4), (22, 7), (18, 8)], fill=W_)
        for x in (2, 4, 6):
            d.point((x, 20), fill=DUST)
        d.line([(1, 21), (22, 21)], fill=DUST_D)

    def sidestep(d):
        # a body leaning off the line, a blade passing through where it stood
        figure(d, 15, 4)
        d.line([(10, 3), (10, 21)], fill=STEEL_D)
        d.line([(3, 10), (12, 13)], fill=STEEL, width=2)
        for y in (8, 12, 16):
            d.line([(18, y), (22, y)], fill=W_)

    def afterimage(d):
        # a pale copy struck through, the body already gone to the side
        figure(d, 8, 4, GHOST)
        d.line([(2, 4), (14, 18)], fill=W_, width=1)
        figure(d, 18, 4)

    def moonstep(d):
        # a crescent moon under two stamping feet, a ring of air
        d.arc([4, 12, 20, 22], 200, 340, fill=MOON, width=2)
        d.rectangle([8, 4, 10, 12], fill=BODY)
        d.rectangle([14, 4, 16, 12], fill=BODY)
        d.rectangle([7, 12, 11, 14], fill=WOOD)
        d.rectangle([13, 12, 17, 14], fill=WOOD)
        for x, y in ((3, 6), (21, 6), (12, 2)):
            d.line([(x, y), (x, y + 3)], fill=W_)

    def featherfall(d):
        d.line([(16, 3), (7, 20)], fill=W_, width=1)
        for k in range(5):
            y = 6 + k * 3
            x = 15 - k * 2
            d.line([(x, y), (x + 5, y - 2)], fill=SKY)
            d.line([(x, y), (x - 4, y + 1)], fill=SKY)

    def crash(d):
        # a fist planted in cracked ground, a ring thrown out
        d.ellipse([1, 16, 23, 23], outline=DUST)
        for x1, y1 in ((4, 22), (20, 22), (8, 23), (16, 23)):
            d.line([(12, 19), (x1, y1)], fill=DUST_D)
        d.rectangle([10, 4, 14, 14], fill=BODY)
        d.rectangle([9, 14, 15, 18], fill=SKIN)
        for x in (5, 19):
            d.line([(x, 6), (x, 12)], fill=W_)

    def disarm(d):
        # a blade knocked spinning up out of a hand, a spark where the parry met it
        d.line([(4, 20), (10, 14)], fill=STEEL, width=2)
        d.line([(14, 4), (20, 10)], fill=STEEL, width=2)
        d.line([(19, 2), (22, 5)], fill=GOLD, width=2)
        d.arc([10, 0, 24, 14], 120, 300, fill=W_)
        for x, y in ((12, 12), (10, 10), (14, 12), (12, 15)):
            d.point((x, y), fill=GOLD)

    def shove(d):
        # an open palm and the rings of the shove ahead of it
        d.rectangle([2, 8, 8, 16], fill=SKIN)
        for k in range(4):
            d.line([(8, 8 + k * 2), (11, 8 + k * 2)], fill=SKIN)
        for r in (5, 8, 11):
            d.arc([10 - r, 12 - r, 10 + r, 12 + r], -50, 50, fill=W_, width=1)
        d.polygon([(20, 9), (23, 12), (20, 15)], fill=W_)

    def rolling_guard(d):
        # a blade held across, the curl of a roll round it
        d.arc([2, 2, 22, 22], 30, 300, fill=W_, width=1)
        d.line([(5, 15), (19, 9)], fill=STEEL, width=2)
        d.line([(4, 16), (6, 14)], fill=WOOD, width=2)
        d.polygon([(20, 4), (23, 8), (18, 8)], fill=W_)

    def planted(d):
        # feet set wide in the ground behind a blade held across, sparks off its edge
        d.line([(1, 22), (23, 22)], fill=DUST_D)
        d.line([(9, 14), (4, 21)], fill=BODY, width=2)
        d.line([(15, 14), (20, 21)], fill=BODY, width=2)
        d.rectangle([9, 7, 15, 14], fill=BODY)
        d.line([(5, 6), (19, 6)], fill=STEEL, width=2)
        for x, y in ((3, 4), (2, 7), (4, 9)):
            d.point((x, y), fill=GOLD)

    def dolphin(d):
        # a swimmer arcing up out of a wave, spray off the kick
        d.arc([2, 14, 22, 26], 180, 360, fill=SEA, width=2)
        d.arc([4, 4, 20, 22], 200, 330, fill=BODY, width=3)
        d.ellipse([16, 6, 20, 10], fill=SKIN)
        for x, y in ((3, 12), (5, 10), (2, 15)):
            d.point((x, y), fill=FOAM)
        d.line([(2, 19), (22, 19)], fill=BLUE)

    def glide(d):
        # a long, flat streamline on the water, a wake drawn out behind
        d.line([(1, 16), (23, 16)], fill=BLUE)
        d.line([(6, 12), (20, 12)], fill=BODY, width=3)
        d.line([(20, 12), (23, 11)], fill=SKIN, width=2)
        d.ellipse([16, 9, 20, 13], fill=SKIN)
        for y, x1 in ((18, 14), (20, 9)):
            d.line([(1, y), (x1, y)], fill=FOAM)
        d.point((22, 15), fill=GREEN)

    for name, fn in (("roll", roll), ("sidestep", sidestep), ("afterimage", afterimage), ("moonstep", moonstep),
                     ("featherfall", featherfall), ("crash", crash), ("disarm", disarm), ("shove", shove),
                     ("rolling_guard", rolling_guard), ("planted", planted), ("dolphin", dolphin), ("glide", glide)):
        _icon("skill_move_" + name, fn)


def gen_fruit_skins():
    for name, base, dots, swirl, top in (("devil_fruit_wolf", "8a8478", ("a09a8c", "6a645a"), "2a2420", "c0b8a8"),
                                          ("devil_fruit_vine", "4a9a36", ("62b04a", "36802a"), "1a4a14", "a0e070")):
        n = 32
        img = Image.new("RGB", (n, n), hexc(base))
        d = ImageDraw.Draw(img)
        rng = np.random.default_rng(hash(name) % 9999)
        for y in range(n):
            for x in range(n):
                if rng.random() < 0.25:
                    d.point((x, y), fill=hexc(dots[0]) if rng.random() < 0.6 else hexc(dots[1]))
        for (x, y) in ((6, 8), (22, 6), (14, 20), (28, 24), (4, 26)):
            for k in range(3):
                r = 5 - k * 1.6
                d.arc([x - r, y - r, x + r, y + r], 30 + k * 40, 330, fill=hexc(swirl))
        d.rectangle([0, 0, n, 2], fill=hexc(top))
        save(img, name)


# --------------------------------------------------------------------------
# Particle sprites -> assets/textures/fx/
# --------------------------------------------------------------------------
FX_OUT = os.path.join(ROOT, "assets", "textures", "fx")


def gen_fx():
    os.makedirs(FX_OUT, exist_ok=True)
    # dust puff: chunky soft circle with a few holes, white (tinted by particle color)
    rng = np.random.default_rng(2101)
    n = 16
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.sqrt((xx - 7.5) ** 2 + (yy - 7.5) ** 2) / 7.5
    noise = rng.random((n, n)) * 0.35
    a = np.clip(1.15 - d - noise * d, 0, 1)
    a = np.round(a * 4) / 4  # 4 alpha steps = PS1 look
    shade = np.clip(1.0 - (yy / n) * 0.35, 0, 1)
    rgb = np.dstack([shade, shade, shade]) * 255
    Image.fromarray(np.dstack([rgb, a * 255]).astype(np.uint8), "RGBA").save(os.path.join(FX_OUT, "dust.png"))
    # sparkle: 4-point star
    img = Image.new("RGBA", (9, 9), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    dr.line([(4, 0), (4, 8)], fill=(255, 255, 255, 255))
    dr.line([(0, 4), (8, 4)], fill=(255, 255, 255, 255))
    dr.point([(3, 3), (5, 3), (3, 5), (5, 5)], fill=(255, 255, 255, 170))
    for p_ in [(4, 0), (4, 8), (0, 4), (8, 4)]:
        dr.point(p_, fill=(255, 255, 255, 140))
    img.save(os.path.join(FX_OUT, "sparkle.png"))
    # impact flash: blocky burst
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    for ang in range(0, 360, 45):
        r = 7 if ang % 90 == 0 else 5
        x = 7.5 + math.cos(math.radians(ang)) * r
        y = 7.5 + math.sin(math.radians(ang)) * r
        dr.line([(7.5, 7.5), (x, y)], fill=(255, 255, 255, 255), width=2)
    dr.ellipse([5, 5, 10, 10], fill=(255, 255, 255, 255))
    img.save(os.path.join(FX_OUT, "impact.png"))
    print("  wrote assets/textures/fx/{dust,sparkle,impact}.png")


def gen_face_parts():
    """Character-creator face sprites, composed at runtime over the skin tone.
    32x32 tiles, 8 per row. Row 0 eyes, row 1 brows, row 2 mouths, row 3 marks.
    Marker colors are recolored in game: magenta = iris (eye color),
    green = hair-colored (brows, stubble)."""
    T = 32
    atlas = Image.new("RGBA", (T * 8, T * 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(atlas)
    LASH = hexc("1e1612") + (255,)
    WHITE = hexc("f0ece2") + (255,)
    IRIS = (255, 0, 255, 255)
    PUPIL = hexc("0e0a08") + (255,)
    HAIR = (0, 255, 0, 255)
    LIP = hexc("8a3e34") + (255,)
    LIP_D = hexc("5a2620") + (255,)
    TEETH = hexc("f2eee6") + (255,)

    def px(ox, oy, pts, c):
        for x, y in pts:
            d.point((ox + x, oy + y), fill=c)

    def line(ox, oy, a, b, c):
        d.line([(ox + a[0], oy + a[1]), (ox + b[0], oy + b[1])], fill=c)

    def rect(ox, oy, a, b, c):
        d.rectangle([ox + a[0], oy + a[1], ox + b[0], oy + b[1]], fill=c)

    # ---- eyes (left eye centered x=10, right eye x=21; rows ~11..15).
    # Slightly larger than life so they read at PS1 resolutions.
    def eye_pair(ix, style):
        ox, oy = ix * T, 0
        for cx, flip in ((10, 1), (21, -1)):
            outer = cx - 4 * flip
            if style == 0:  # plain
                rect(ox, oy, (cx - 3, 12), (cx + 3, 14), WHITE)
                rect(ox, oy, (cx - 1, 12), (cx + 1, 14), IRIS)
                px(ox, oy, [(cx, 13)], PUPIL)
                px(ox, oy, [(cx - 1, 12)], WHITE)
                line(ox, oy, (cx - 3, 11), (cx + 3, 11), LASH)
                px(ox, oy, [(outer, 12)], LASH)
            elif style == 1:  # narrow
                rect(ox, oy, (cx - 3, 13), (cx + 3, 14), WHITE)
                rect(ox, oy, (cx - 1, 13), (cx + 1, 14), IRIS)
                px(ox, oy, [(cx, 13)], PUPIL)
                line(ox, oy, (cx - 3, 12), (cx + 3, 12), LASH)
                px(ox, oy, [(outer, 13)], LASH)
                line(ox, oy, (cx - 2, 15), (cx + 2, 15), LASH[:3] + (90,))
            elif style == 2:  # wide
                rect(ox, oy, (cx - 3, 11), (cx + 3, 15), WHITE)
                rect(ox, oy, (cx - 1, 12), (cx + 1, 14), IRIS)
                px(ox, oy, [(cx, 13)], PUPIL)
                px(ox, oy, [(cx - 1, 12)], WHITE)
                line(ox, oy, (cx - 3, 10), (cx + 3, 10), LASH)
            elif style == 3:  # hooded / sleepy
                rect(ox, oy, (cx - 3, 13), (cx + 3, 14), WHITE)
                rect(ox, oy, (cx - 1, 13), (cx + 1, 14), IRIS)
                px(ox, oy, [(cx, 14)], PUPIL)
                line(ox, oy, (cx - 3, 12), (cx + 3, 12), LASH)
                line(ox, oy, (cx - 3, 11), (cx + 3, 11), LASH[:3] + (80,))
            elif style == 4:  # sharp, outer corner lifted
                rect(ox, oy, (cx - 3, 12), (cx + 3, 13), WHITE)
                rect(ox, oy, (cx - 1, 12), (cx + 1, 13), IRIS)
                px(ox, oy, [(cx, 13)], PUPIL)
                inner = cx + 3 * flip
                line(ox, oy, (inner, 12), (cx - 3 * flip, 10), LASH)
                px(ox, oy, [(outer, 10), (outer, 11)], LASH)
            elif style == 5:  # big round
                rect(ox, oy, (cx - 3, 11), (cx + 3, 15), WHITE)
                rect(ox, oy, (cx - 2, 11), (cx + 1, 15), IRIS)
                rect(ox, oy, (cx - 1, 12), (cx, 14), PUPIL)
                px(ox, oy, [(cx - 2, 11), (cx - 1, 12)], WHITE)
                line(ox, oy, (cx - 3, 10), (cx + 3, 10), LASH)
                px(ox, oy, [(outer, 11)], LASH)
    for i in range(6):
        eye_pair(i, i)

    # ---- brows (row 1), hair-colored marker
    def brows(ix, style):
        ox, oy = ix * T, T
        for cx, flip in ((10, 1), (21, -1)):
            inner = cx + 3 * flip
            outer = cx - 4 * flip
            if style == 0:  # natural
                line(ox, oy, (outer, 9), (inner, 8), HAIR)
                line(ox, oy, (cx - 1 * flip, 8), (inner, 8), HAIR)
            elif style == 1:  # thick
                rect(ox, oy, (min(outer, inner), 7), (max(outer, inner), 8), HAIR)
            elif style == 2:  # thin arched
                line(ox, oy, (outer, 9), (cx, 7), HAIR)
                line(ox, oy, (cx, 7), (inner, 8), HAIR)
            elif style == 3:  # stern (low inner)
                line(ox, oy, (outer, 7), (inner, 9), HAIR)
                line(ox, oy, (outer, 8), (inner - flip, 9), HAIR)
            elif style == 4:  # worried (high inner)
                line(ox, oy, (outer, 9), (inner, 7), HAIR)
    for i in range(5):
        brows(i, i)

    # ---- mouths (row 2), centered x 15.5, rows ~22..26
    def mouth(ix, style):
        ox, oy = ix * T, T * 2
        if style == 0:  # neutral
            line(ox, oy, (12, 23), (19, 23), LIP_D)
            line(ox, oy, (13, 24), (18, 24), LIP[:3] + (120,))
        elif style == 1:  # smile
            line(ox, oy, (12, 22), (13, 23), LIP_D)
            line(ox, oy, (13, 23), (18, 23), LIP_D)
            line(ox, oy, (18, 23), (19, 22), LIP_D)
            line(ox, oy, (14, 24), (17, 24), LIP[:3] + (140,))
        elif style == 2:  # grin with teeth
            rect(ox, oy, (12, 22), (19, 24), LIP_D)
            rect(ox, oy, (13, 22), (18, 23), TEETH)
            line(ox, oy, (11, 21), (12, 22), LIP_D)
            line(ox, oy, (19, 22), (20, 21), LIP_D)
        elif style == 3:  # frown
            line(ox, oy, (12, 24), (13, 23), LIP_D)
            line(ox, oy, (13, 23), (18, 23), LIP_D)
            line(ox, oy, (18, 23), (19, 24), LIP_D)
        elif style == 4:  # smirk
            line(ox, oy, (12, 23), (17, 23), LIP_D)
            line(ox, oy, (17, 23), (19, 22), LIP_D)
            px(ox, oy, [(20, 22)], LIP_D[:3] + (120,))
        elif style == 5:  # open "o"
            rect(ox, oy, (14, 22), (17, 25), LIP_D)
            rect(ox, oy, (15, 23), (16, 24), hexc("3a1612") + (255,))
    for i in range(6):
        mouth(i, i)

    # ---- marks (row 3)
    ox, oy = 0, T * 3  # 0 stubble (hair marker, sparse)
    rng = np.random.default_rng(77)
    for y in range(20, 32):
        for x in range(3, 29):
            # jaw-shaped region, skip mouth line
            if abs(x - 15.5) > 13 - (y - 20) * 0.35 or (22 <= y <= 24 and 11 <= x <= 20):
                continue
            if rng.random() < 0.2:
                d.point((ox + x, oy + y), fill=(0, 255, 0, 105))
    ox = T  # 1 freckles
    for x, y in [(6, 17), (8, 18), (10, 17), (7, 19), (21, 17), (23, 18), (25, 17), (24, 19), (14, 18), (17, 18)]:
        d.point((ox + x, oy + y), fill=hexc("8a5236") + (170,))
    ox = T * 2  # 2 scar over the right eye (viewer's right)
    line(ox, oy, (24, 7), (21, 19), hexc("b0645a") + (255,))
    line(ox, oy, (25, 8), (22, 19), hexc("d88a7c") + (160,))
    ox = T * 3  # 3 eyepatch (strap + patch over viewer-right eye)
    line(ox, oy, (0, 8), (31, 13), LASH)
    rect(ox, oy, (19, 11), (25, 16), hexc("141010") + (255,))
    rect(ox, oy, (20, 16), (24, 17), hexc("141010") + (255,))
    ox = T * 4  # 4 blush
    for cx in (8, 23):
        rect(ox, oy, (cx - 2, 18), (cx + 2, 19), hexc("d0645a") + (90,))
    ox = T * 5  # 5 war paint: dark band across the eyes
    rect(ox, oy, (3, 11), (28, 17), hexc("1a1a22") + (150,))
    ox = T * 6  # 6 age lines
    for cx, flip in ((9, 1), (22, -1)):
        line(ox, oy, (cx - 4 * flip, 15), (cx - 5 * flip, 17), hexc("6a4434") + (110,))
    line(ox, oy, (10, 20), (11, 24), hexc("6a4434") + (90,))
    line(ox, oy, (21, 20), (20, 24), hexc("6a4434") + (90,))
    line(ox, oy, (11, 7), (20, 7), hexc("6a4434") + (70,))
    save(atlas, "face_parts")


def gen_hair():
    """Strand texture for hair and beards (grayscale, tinted in game)."""
    rng = np.random.default_rng(1301)
    w = h = 32
    v = np.full((h, w), 0.78)
    for x in range(w):
        streak = rng.uniform(-0.18, 0.12)
        v[:, x] += streak
    # wavy dark strands
    for _ in range(14):
        x0 = rng.uniform(0, w)
        for y in range(h):
            x = int(x0 + math.sin(y * 0.4 + x0) * 1.2) % w
            v[y, x] -= 0.22
    v += (rng.random((h, w)) - 0.5) * 0.08
    g = (np.clip(v, 0, 1) * 255).astype(np.uint8)
    save(to_img(np.dstack([g, g, g])), "hair")


def gen_leather():
    """Mottled leather with a stitch line (grayscale, tinted in game)."""
    rng = np.random.default_rng(1302)
    n = fbm(32, 3, 2, rng)
    v = 0.74 + (norm(n) - 0.5) * 0.22 + (rng.random((32, 32)) - 0.5) * 0.06
    v[3, ::3] -= 0.25  # stitching
    v[28, 1::3] -= 0.25
    g = (np.clip(v, 0, 1) * 255).astype(np.uint8)
    save(to_img(np.dstack([g, g, g])), "leather")


def gen_scales():
    """Overlapping serpent scales in rows (grayscale, coloured in game by vertex colour)."""
    rng = np.random.default_rng(1401)
    size, cw, rh, rad = 64, 8, 8, 6.2
    v = np.full((size, size), 0.5)
    n = fbm(size, 4, 2, rng)
    ys, xs = np.mgrid[0:size, 0:size]
    # rows drawn from the bottom up: each row's scales lie over the row below's tops
    for r in range(size // rh - 1, -1, -1):
        cy = r * rh
        for c in range(size // cw):
            cx = c * cw + (cw // 2 if r % 2 else 0)
            dx = (xs - cx + size // 2) % size - size // 2
            dy = (ys - cy + size // 2) % size - size // 2
            d = np.sqrt(dx * dx + (dy * 0.9) ** 2)
            m = (d < rad) & (dy >= -1)
            shade = 0.92 - d / rad * 0.38 - np.clip(dy, 0, None) / rad * 0.12
            shade = np.where(d > rad - 1.2, 0.36, shade)
            v = np.where(m, shade, v)
    v = v * (0.88 + n * 0.24)
    pal_g = [0.34, 0.46, 0.58, 0.7, 0.82, 0.94]
    q = np.array(pal_g)[np.clip((norm(v) * len(pal_g)).astype(int), 0, len(pal_g) - 1)]
    g = (q * 255).astype(np.uint8)
    save(to_img(np.dstack([g, g, g])), "scales")


def gen_fur():
    """Coarse shaggy fur in clumps running down the texture (grayscale, tinted in game)."""
    rng = np.random.default_rng(1402)
    size = 64
    v = np.full((size, size), 0.5)
    for _ in range(55):
        x0 = rng.uniform(0, size)
        y0 = rng.uniform(0, size)
        length = rng.integers(10, 20)
        w = rng.uniform(1.2, 2.6)
        lean = rng.uniform(-0.25, 0.25)
        lit = rng.uniform(0.62, 0.82)
        for i in range(length):
            k = i / length
            x = x0 + lean * i + math.sin(i * 0.35 + x0) * 0.6
            y = int(y0 + i) % size
            half = w * (1.0 - k * 0.7)
            for xx in range(int(x - half - 1), int(x + half + 2)):
                d = abs(xx - x) / max(half, 0.5)
                if d < 1.0:
                    v[y, xx % size] = max(v[y, xx % size], lit * (1.0 - d * 0.45) * (1.0 - k * 0.35))
                elif d < 1.6:
                    v[y, xx % size] = min(v[y, xx % size], 0.4)
    v += (rng.random((size, size)) - 0.5) * 0.06
    pal_g = [0.46, 0.55, 0.64, 0.73, 0.82]
    q = np.array(pal_g)[np.clip((norm(v) * len(pal_g)).astype(int), 0, len(pal_g) - 1)]
    g = (q * 255).astype(np.uint8)
    save(to_img(np.dstack([g, g, g])), "fur")


def gen_will_icons():
    """The 1.24 Will paths' skills (WillArts): Still Point, Berserk, Call the Wind, Twin Finisher, Plant the Flag, Glimpse."""
    W_ = (255, 255, 245, 255)
    PALE = hexc("bcd8ff") + (255,)
    PALE_D = hexc("6a86b8") + (255,)
    RED = hexc("e8322a") + (255,)
    RED_D = hexc("8a1810") + (255,)
    SEA = hexc("4aa8e8") + (255,)
    SEA_L = hexc("bfe8ff") + (255,)
    GOLD = hexc("f0c040") + (255,)
    GOLD_D = hexc("9a6a18") + (255,)
    WOOD = hexc("6a4628") + (255,)
    CLOTH = hexc("d8d0b8") + (255,)
    BLACK = (24, 18, 22, 255)
    VIOLET = hexc("b48af0") + (255,)

    def still_point(d):
        # a clock face held still: rings round a dot, the hands stopped
        d.ellipse([3, 3, 21, 21], outline=PALE_D, width=2)
        d.ellipse([6, 6, 18, 18], outline=PALE, width=1)
        d.line([(12, 12), (12, 6)], fill=W_, width=1)
        d.line([(12, 12), (16, 14)], fill=W_, width=1)
        d.ellipse([11, 11, 13, 13], fill=W_)
        for x, y in ((1, 12), (22, 12), (12, 1), (12, 22)):
            d.point((x, y), fill=PALE)

    def berserk(d):
        # a fist up in red mist, rage lines off it
        d.polygon([(4, 22), (8, 14), (16, 14), (20, 22)], fill=RED_D)
        d.rectangle([7, 7, 17, 15], fill=RED)
        for x in (7, 10, 13, 16):
            d.rectangle([x, 5, x + 1, 8], fill=RED)
        for a, b in (((2, 4), (5, 7)), ((22, 4), (19, 7)), ((12, 0), (12, 3))):
            d.line([a, b], fill=W_, width=1)

    def call_wind(d):
        # a sail filled by three gusts
        d.line([(15, 2), (15, 22)], fill=WOOD, width=2)
        d.polygon([(14, 4), (14, 18), (5, 16), (3, 10), (5, 5)], fill=CLOTH)
        for y in (6, 11, 16):
            d.line([(17, y), (22, y - 1)], fill=SEA_L, width=1)
            d.point((20, y + 1), fill=SEA)

    def twin_finisher(d):
        # two blades crossed, a star where they meet
        d.line([(3, 21), (20, 4)], fill=hexc("d0d8e0") + (255,), width=2)
        d.line([(4, 4), (21, 21)], fill=hexc("d0d8e0") + (255,), width=2)
        d.line([(2, 19), (6, 23)], fill=GOLD, width=2)
        d.line([(18, 23), (22, 19)], fill=GOLD, width=2)
        d.polygon([(12, 7), (13, 11), (17, 12), (13, 13), (12, 17), (11, 13), (7, 12), (11, 11)], fill=GOLD)

    def plant_flag(d):
        # a flag driven into the ground, a ring of green round its foot
        d.ellipse([3, 17, 21, 23], outline=hexc("7ae07a") + (255,), width=1)
        d.line([(9, 2), (9, 20)], fill=WOOD, width=2)
        d.polygon([(10, 3), (21, 6), (10, 10)], fill=BLACK)
        d.ellipse([13, 5, 16, 8], fill=W_)

    def glimpse(d):
        # an eye through a wall: bricks, and the eye bright over them
        for y in (4, 10, 16):
            off = 0 if y % 12 == 4 else 4
            for x in range(-4 + off, 24, 8):
                d.rectangle([x, y, x + 6, y + 4], fill=hexc("5a5048") + (255,))
        d.ellipse([3, 8, 21, 16], fill=VIOLET)
        d.ellipse([8, 9, 16, 15], fill=W_)
        d.ellipse([10, 10, 14, 14], fill=BLACK)

    def swell(d):
        # a wave curling over a deck rail, a figure thrown off it
        d.rectangle([2, 18, 22, 21], fill=WOOD)
        d.arc([3, 4, 21, 26], 180, 300, fill=SEA, width=3)
        d.arc([6, 8, 18, 22], 190, 290, fill=SEA_L, width=1)
        d.ellipse([17, 3, 20, 6], fill=BLACK)
        d.line([(18, 6), (21, 10)], fill=BLACK, width=1)

    for name, fn in (("will_swell", swell), ("will_still_point", still_point), ("will_berserk", berserk), ("will_wind", call_wind),
                     ("will_twin", twin_finisher), ("will_flag", plant_flag), ("will_glimpse", glimpse)):
        _icon("skill_" + name, fn)


def main():
    if "will_icons" in sys.argv[1:]:
        gen_will_icons()
        return
    if "beasts" in sys.argv[1:]:
        gen_scales(); gen_fur()
        return
    if "icons" in sys.argv[1:]:
        gen_icons()
        return
    if "part_icons" in sys.argv[1:]:
        gen_part_icons()
        return
    if "techniques" in sys.argv[1:]:
        gen_technique_icons()
        return
    if "moves" in sys.argv[1:]:
        gen_move_icons()
        return
    if "village" in sys.argv[1:]:
        gen_cobbles(); gen_sign_smithy()
        return
    if "clothes" in sys.argv[1:]:
        gen_fabric_patterns(); gen_mail()
        return
    if "doors" in sys.argv[1:]:
        gen_door_panel()
        return
    if "technique_icons" in sys.argv[1:]:
        gen_technique_icons()
        return
    if "ships" in sys.argv[1:]:
        # the Admiralty's painted hull: blue-grey planks, white seams
        planks(3104, pal("4a525c", "56606a", "626c76", "6e7882", "7a848e"), "planks_grey", plank_h=8, gap="2a3038")
        return
    if "jungle" in sys.argv[1:]:
        gen_bamboo(); gen_woven(); gen_palm_thatch(); gen_flagstones(); gen_vines(); gen_broadleaf()
        return
    os.makedirs(OUT, exist_ok=True)
    print("Generating PSX textures ->", os.path.relpath(OUT, ROOT))
    gen_grass(); gen_sand(); gen_wet_sand(); gen_dirt(); gen_rock(); gen_seafloor(); gen_water()
    planks(3101, pal("6b4a2a", "7a5632", "88623a", "967042", "a37c4a"), "planks")
    planks(3102, pal("3e2a1a", "4a3220", "563a26", "62442c", "6e4d32"), "planks_dark")
    planks(3103, pal("7a7466", "878070", "948c7c", "a19888", "aea494"), "planks_weathered", plank_h=8, gap="3a3630")
    gen_bark(); gen_palm_bark(); gen_thatch(); gen_stone_brick(); gen_plaster(); gen_roof_tiles()
    gen_cobbles(); gen_sign_smithy()
    gen_bamboo(); gen_woven(); gen_palm_thatch(); gen_flagstones(); gen_vines(); gen_broadleaf()
    gen_cloth(1210, hexc("b03a2e"), hexc("e8e0cc"), "cloth_red")
    gen_cloth(1211, hexc("2e5a8a"), hexc("e8e0cc"), "cloth_blue")
    gen_cloth(1212, hexc("d8d0b8"), hexc("d8d0b8"), "canvas", stripes=False)
    gen_fabric(); gen_fabric_patterns(); gen_mail(); gen_metal(); gen_straw()
    gen_leaves(); gen_palm_frond(); gen_bush(); gen_grass_tuft(); gen_fern()
    gen_driftstone(); gen_rope(); gen_sign_tavern(); gen_sign_fish(); gen_window(); gen_door(); gen_door_panel()
    gen_faces()
    gen_face_parts(); gen_hair(); gen_leather()
    gen_scales(); gen_fur()
    gen_icons()
    gen_power_icons()
    gen_skill_icons()
    gen_technique_icons()
    gen_will_icons()
    gen_move_icons()
    gen_fruit_skins()
    gen_thornbrush()
    gen_devil_fruit_tex()
    gen_fx()
    print("done.")


if __name__ == "__main__":
    sys.exit(main())
