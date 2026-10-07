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

    _icon("cutlass", cutlass)
    _icon("katana", katana)
    _icon("axe", axe)
    _icon("rum", rum)
    _icon("gold", gold)
    _icon("treasure", treasure)
    _icon("fish", fish)
    _icon("stew", stew)
    _icon("biscuit", biscuit)


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


def main():
    if "icons" in sys.argv[1:]:
        gen_icons()
        return
    os.makedirs(OUT, exist_ok=True)
    print("Generating PSX textures ->", os.path.relpath(OUT, ROOT))
    gen_grass(); gen_sand(); gen_wet_sand(); gen_dirt(); gen_rock(); gen_seafloor(); gen_water()
    planks(3101, pal("6b4a2a", "7a5632", "88623a", "967042", "a37c4a"), "planks")
    planks(3102, pal("3e2a1a", "4a3220", "563a26", "62442c", "6e4d32"), "planks_dark")
    planks(3103, pal("7a7466", "878070", "948c7c", "a19888", "aea494"), "planks_weathered", plank_h=8, gap="3a3630")
    gen_bark(); gen_palm_bark(); gen_thatch(); gen_stone_brick(); gen_plaster(); gen_roof_tiles()
    gen_cloth(1210, hexc("b03a2e"), hexc("e8e0cc"), "cloth_red")
    gen_cloth(1211, hexc("2e5a8a"), hexc("e8e0cc"), "cloth_blue")
    gen_cloth(1212, hexc("d8d0b8"), hexc("d8d0b8"), "canvas", stripes=False)
    gen_fabric(); gen_metal(); gen_straw()
    gen_leaves(); gen_palm_frond(); gen_bush(); gen_grass_tuft(); gen_fern()
    gen_driftstone(); gen_rope(); gen_sign_tavern(); gen_sign_fish(); gen_window(); gen_door()
    gen_faces()
    gen_face_parts(); gen_hair(); gen_leather()
    gen_icons()
    gen_power_icons()
    gen_skill_icons()
    gen_fruit_skins()
    gen_thornbrush()
    gen_devil_fruit_tex()
    gen_fx()
    print("done.")


if __name__ == "__main__":
    sys.exit(main())
