#!/usr/bin/env python3
"""
Flipbook sprite sheets for FX (the flipbook pilot): a smoke puff that billows out and
thins, and an explosion that blooms, then breaks into smoke and embers.

16 frames of 64x64 in a 4x4 sheet (frame 0 top left, row by row), colour stepped onto a
small palette and alpha on four levels with an ordered dither (the PS1 look). The noise
is one field scaled with the puff, so it billows instead of flickering. Deterministic.

Usage (from the project root):
    py tools/texture_gen/gen_flipbooks.py

Output: assets/textures/fx/flip_smoke.png, assets/textures/fx/flip_explosion.png
(and a 3x preview of both at tools/dev/out/flipbook/sheets.png).
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "fx")
PREVIEW = os.path.join(ROOT, "tools", "dev", "out", "flipbook")

FR = 64
COLS = 4
N = 16

_yy, _xx = np.mgrid[0:FR, 0:FR]
U = (_xx + 0.5 - FR / 2) / (FR / 2)
V = (_yy + 0.5 - FR / 2) / (FR / 2)  # down is +
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0
DITHER = np.tile(BAYER, (FR // 4, FR // 4))
# toward the light (upper left)
LIGHT = np.array([-0.6, -0.8])


def hexc(s: str) -> np.ndarray:
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def periodic_noise(size: int, cells: int, rng: np.random.Generator) -> np.ndarray:
    grid = rng.random((cells, cells))
    coords = np.arange(size) * cells / size
    i0 = np.floor(coords).astype(int)
    f = coords - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    i0 = i0 % cells
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(size: int, cells: int, octaves: int, rng: np.random.Generator) -> np.ndarray:
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for _ in range(octaves):
        out += periodic_noise(size, cells, rng) * amp
        total += amp
        amp *= 0.5
        cells *= 2
    out /= total
    return (out - out.min()) / (out.max() - out.min())


def sample(field: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    """The field at frame coords (one frame width = a quarter of the field)."""
    n = field.shape[0]
    return map_coordinates(field, [v * n / 8.0, u * n / 8.0], order=1, mode="grid-wrap")


def lobes(u: np.ndarray, v: np.ndarray, cx: float, cy: float, r: float, spec: list, push: float) -> np.ndarray:
    """A cauliflower of round lobes (max union: creases between them read as billows)."""
    d = np.zeros_like(u)
    for ang, off, rad in spec:
        lx = cx + np.cos(ang) * off * r * push
        ly = cy + np.sin(ang) * off * r * push
        rr = rad * r
        d = np.maximum(d, 1.0 - ((u - lx) ** 2 + (v - ly) ** 2) / (rr * rr))
    return np.clip(d, 0.0, 1.0)


def lobe_spec(rng: np.random.Generator, k: int, centre: float) -> list:
    spec = [(0.0, 0.0, centre)]
    for i in range(k):
        spec.append((2 * np.pi * i / k + rng.uniform(-0.3, 0.3), rng.uniform(0.38, 0.58), rng.uniform(0.4, 0.55)))
    return spec


class Puff:
    """A billowing mass at time t: lobes warped by noise (so no lobe stays a circle), the
    noise riding with the puff's growth, light from the upper left on its rims and bumps."""

    def __init__(self, big, fine, spec, t, r, cx, cy, push, warp=0.22):
        self.big, self.fine, self.spec = big, fine, spec
        self.t, self.r, self.cx, self.cy, self.push, self.warp = t, r, cx, cy, push, warp

    def noise(self, u, v):
        pu = (u - self.cx) / self.r
        pv = (v - self.cy) / self.r
        t = self.t
        return 0.6 * sample(self.big, pu * 0.8, pv * 0.8 + 0.3 * t) + 0.4 * sample(self.fine, pu * 1.6 + 0.2 * t, pv * 1.6 - 0.35 * t)

    def density(self, u, v):
        pu = (u - self.cx) / self.r
        pv = (v - self.cy) / self.r
        wu = sample(self.big, pu * 0.7 + 3.1, pv * 0.7 + 1.7) - 0.5
        wv = sample(self.big, pu * 0.7 + 5.3, pv * 0.7 + 2.9) - 0.5
        w = self.warp * self.r * 2.0
        return lobes(u + wu * w, v + wv * w, self.cx, self.cy, self.r, self.spec, self.push)

    def light(self, u, v):
        """0..1: the rims and bumps facing the light bright, those away dark."""
        d = self.density(u, v)
        s = 0.14 * self.r
        rim = np.clip((d - self.density(u + LIGHT[0] * s, v + LIGHT[1] * s)) * 2.0, -0.5, 0.5)
        e = 0.06 * self.r
        bump = np.clip((self.noise(u, v) - self.noise(u + LIGHT[0] * e, v + LIGHT[1] * e)) * 9.0, -0.5, 0.5)
        return np.clip(0.5 + 0.55 * rim + 0.45 * bump, 0.0, 1.0)


def dither_alpha(a: np.ndarray) -> np.ndarray:
    return np.clip(np.floor(a * 3.0 + DITHER) / 3.0, 0.0, 1.0)


def steps(x: np.ndarray, levels: list) -> np.ndarray:
    lv = np.array(levels)
    idx = np.clip((x * len(lv)).astype(int), 0, len(lv) - 1)
    return lv[idx]


def gen_smoke() -> list:
    rng = np.random.default_rng(7301)
    big = fbm(128, 4, 4, rng)
    fine = fbm(128, 8, 3, rng)
    spec = lobe_spec(rng, 7, 0.62)
    frames = []
    for i in range(N):
        t = i / (N - 1)
        r = 0.3 + 0.56 * (1 - (1 - t) ** 2.2)
        pf = Puff(big, fine, spec, t, r, 0.0, -0.08 * t, 0.75 + 0.45 * t)
        d = pf.density(U, V)
        n = pf.noise(U, V)
        thr = 0.08 + 0.85 * t ** 1.4
        # (saturated inside, so it thins along the noise, not lobe by lobe into discs)
        body = np.clip(d * 2.5, 0.0, 1.0)
        a = np.clip((body * (0.3 + 1.1 * n) - thr) / 0.22, 0.0, 1.0) * (1.0 - 0.2 * t)
        shade = np.clip(0.15 + 0.75 * pf.light(U, V) - 0.1 * V, 0.0, 1.0)
        grey = steps(shade, [0.52, 0.64, 0.76, 0.88, 1.0]) * 255.0
        rgba = np.zeros((FR, FR, 4))
        rgba[..., 0] = grey
        rgba[..., 1] = grey
        rgba[..., 2] = grey * 0.97
        rgba[..., 3] = dither_alpha(a) * 255.0
        frames.append(rgba)
    return frames


FIRE = [(1.0, hexc("fff4c8")), (0.7, hexc("ffd448")), (0.45, hexc("ff8c1c")), (0.3, hexc("dc4814")), (0.22, hexc("86280e"))]
SOOT = [hexc("362e2b"), hexc("4e4440"), hexc("6a605a"), hexc("8a8078")]
EMBER = [hexc("ffe48c"), hexc("ffa030"), hexc("e05020"), hexc("8a3010")]


def gen_explosion() -> list:
    rng = np.random.default_rng(7302)
    big = fbm(128, 4, 4, rng)
    fine = fbm(128, 8, 3, rng)
    spec = lobe_spec(rng, 6, 0.66)
    sparks = [(rng.uniform(0, 2 * np.pi), rng.uniform(0.55, 0.95)) for _ in range(14)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        r = 0.22 + 0.56 * (1 - np.exp(-t * 9.0)) + 0.1 * t
        pf = Puff(big, fine, spec, t, r, 0.0, -0.16 * t ** 1.3, 0.8 + 0.35 * t)
        d = pf.density(U, V)
        n = pf.noise(U, V)
        # the heat dies from the rim in, leaving hot pockets inside the soot a while
        heat = 1.8 * np.exp(-t * 4.8)
        temp = d ** 0.6 * heat * (0.15 + 1.7 * n ** 1.6)
        thr = 0.05 + 0.85 * max(0.0, (t - 0.3) / 0.7) ** 1.3
        body = np.clip(d * 2.5, 0.0, 1.0)
        a = np.clip((body * (0.3 + 1.1 * n) - thr) / 0.22, 0.0, 1.0)
        shade = np.clip(0.1 + 0.8 * pf.light(U, V) - 0.1 * V, 0.0, 1.0)
        idx = np.clip((shade * len(SOOT)).astype(int), 0, len(SOOT) - 1)
        rgb = np.array(SOOT)[idx]
        fire = np.zeros_like(d, dtype=bool)
        for lim, col in reversed(FIRE):
            m = temp > lim
            rgb[m] = col
            fire |= m
        alpha = np.where(fire & (a > 0.2), 1.0, a * (0.92 - 0.15 * t))
        # the first frames: a hot core and spikes (the bloom)
        if i < 2:
            rad = np.sqrt(U ** 2 + V ** 2)
            ang = np.arctan2(V, U)
            reach = [0.95, 0.7][i]
            for k in range(8):
                a0 = k * np.pi / 4 + 0.2
                diff = np.abs((ang - a0 + np.pi) % (2 * np.pi) - np.pi)
                long = reach * (1.0 if k % 2 == 0 else 0.65)
                m = (rad < long * (1.0 - diff / 0.22)) & (diff < 0.22)
                rgb[m] = FIRE[0][1] if i == 0 else FIRE[1][1]
                rgb[m & (rad > long * 0.6)] = FIRE[1][1] if i == 0 else FIRE[2][1]
                alpha = np.where(m, 1.0, alpha)
        rgba = np.zeros((FR, FR, 4))
        rgba[..., :3] = rgb
        rgba[..., 3] = dither_alpha(alpha) * 255.0
        # embers thrown out of it, falling a little and cooling
        if 0.1 < t < 0.92:
            for ang, sp in sparks:
                x = np.cos(ang) * (0.18 + sp * t ** 0.7)
                y = np.sin(ang) * (0.18 + sp * t ** 0.7) + 0.3 * t * t
                if abs(x) > 0.95 or abs(y) > 0.95:
                    continue
                px = int((x + 1) * FR / 2)
                py = int((y + 1) * FR / 2)
                col = EMBER[min(len(EMBER) - 1, int(t * len(EMBER)))]
                size = 2 if t < 0.5 else 1
                rgba[py:py + size, px:px + size, :3] = col
                rgba[py:py + size, px:px + size, 3] = 255.0
        frames.append(rgba)
    return frames


def sheet(frames: list) -> Image.Image:
    rows = (len(frames) + COLS - 1) // COLS
    out = np.zeros((rows * FR, COLS * FR, 4))
    for i, f in enumerate(frames):
        r, c = divmod(i, COLS)
        out[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR] = f
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    smoke = sheet(gen_smoke())
    boom = sheet(gen_explosion())
    smoke.save(os.path.join(OUT, "flip_smoke.png"))
    boom.save(os.path.join(OUT, "flip_explosion.png"))
    print("  wrote assets/textures/fx/flip_smoke.png, flip_explosion.png", smoke.size)
    os.makedirs(PREVIEW, exist_ok=True)
    w, h = smoke.size
    prev = Image.new("RGBA", (w * 2 + 8, h), (40, 70, 110, 255))
    prev.alpha_composite(smoke, (0, 0))
    prev.alpha_composite(boom, (w + 8, 0))
    prev.resize((prev.width * 3, prev.height * 3), Image.NEAREST).save(os.path.join(PREVIEW, "sheets.png"))


if __name__ == "__main__":
    main()
