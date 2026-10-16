#!/usr/bin/env python3
"""
Flipbook sprite sheets for FX (scripts/game/fx.gd: FX.flipbook and the blocks over it): the
library of puffs, plumes, flashes and licks the game's effects are built from.

Every sheet is 16 frames of 64x64 in a 4x4 grid (frame 0 top left, row by row), colour
stepped onto a small palette and alpha on four levels with an ordered dither (the PS1 look).
The noise is one field scaled with the puff, so it billows instead of flickering. Deterministic:
each sheet has its own seed, so changing one never changes another.

Usage (from the project root):
    py tools/texture_gen/gen_flipbooks.py [name ...]    (no names: every sheet)

Output: assets/textures/fx/flip_<name>.png per sheet (SHEETS at the bottom) and a labelled 2x
preview of them all at tools/dev/out/flipbook/sheets.png.
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image, ImageDraw
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
RAD = np.sqrt(U ** 2 + V ** 2)
ANG = np.arctan2(V, U)
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0
DITHER = np.tile(BAYER, (FR // 4, FR // 4))
# toward the light (upper left)
LIGHT = np.array([-0.6, -0.8])
UP = -np.pi / 2


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


# a column: a core with lobes stacked up it and a crown at the top (the splash, the lick, the wisp)
COLUMN = [(0.0, 0.0, 0.62), (UP, 0.55, 0.5), (UP - 0.6, 0.45, 0.38), (UP + 0.6, 0.45, 0.38),
          (np.pi / 2, 0.38, 0.5), (np.pi, 0.28, 0.42), (0.0, 0.28, 0.42)]


class Puff:
    """A billowing mass at time t: lobes warped by noise (so no lobe stays a circle), the
    noise riding with the puff's growth, light from the upper left on its rims and bumps.
    `sy` makes it that many times as tall as wide; `scroll` runs the noise up it (flames)."""

    def __init__(self, big, fine, spec, t, r, cx, cy, push, warp=0.22, sy=1.0, scroll=0.0):
        self.big, self.fine, self.spec = big, fine, spec
        self.t, self.r, self.cx, self.cy, self.push, self.warp = t, r, cx, cy, push, warp
        self.sy, self.scroll = sy, scroll

    def _v(self, v):
        if self.sy == 1.0:
            return v
        return self.cy + (v - self.cy) / self.sy

    def noise(self, u, v):
        v = self._v(v)
        pu = (u - self.cx) / self.r
        pv = (v - self.cy) / self.r
        t = self.t
        s = self.scroll * t
        return 0.6 * sample(self.big, pu * 0.8, pv * 0.8 + 0.3 * t + s) + 0.4 * sample(self.fine, pu * 1.6 + 0.2 * t, pv * 1.6 - 0.35 * t + s * 1.5)

    def density(self, u, v):
        v = self._v(v)
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


def palette(shade: np.ndarray, cols: list) -> np.ndarray:
    """Shade 0..1 stepped onto the colours (dark first)."""
    pal = np.array([hexc(c) for c in cols])
    idx = np.clip((shade * len(pal)).astype(int), 0, len(pal) - 1)
    return pal[idx]


def frame(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    rgba = np.zeros((FR, FR, 4))
    rgba[..., :3] = rgb
    rgba[..., 3] = dither_alpha(np.clip(alpha, 0.0, 1.0)) * 255.0
    return rgba


def dot(rgba: np.ndarray, x: float, y: float, col: np.ndarray, size: int = 1) -> None:
    if abs(x) > 0.96 or abs(y) > 0.96:
        return
    px = int((x + 1) * FR / 2)
    py = int((y + 1) * FR / 2)
    rgba[py:py + size, px:px + size, :3] = col
    rgba[py:py + size, px:px + size, 3] = 255.0


def line(rgba: np.ndarray, x0: float, y0: float, x1: float, y1: float, col: np.ndarray, size: int = 1) -> None:
    n = max(2, int(np.hypot(x1 - x0, y1 - y0) * FR))
    for k in range(n + 1):
        f = k / n
        dot(rgba, x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, col, size)


def star_mask(reach: float, spikes: int, phase: float, half: float, alt: float = 0.65) -> np.ndarray:
    """Thin spikes out of the middle, every other one shorter."""
    m = np.zeros((FR, FR), dtype=bool)
    for k in range(spikes):
        a0 = k * 2 * np.pi / spikes + phase
        diff = np.abs((ANG - a0 + np.pi) % (2 * np.pi) - np.pi)
        long = reach * (1.0 if k % 2 == 0 else alt)
        m |= (RAD < long * (1.0 - diff / half)) & (diff < half)
    return m


def shade_of(pf: Puff, lo: float = 0.15, span: float = 0.75) -> np.ndarray:
    return np.clip(lo + span * pf.light(U, V) - 0.1 * V, 0.0, 1.0)


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


# the matter palettes, dark to light
BROWN = ["4a3929", "61492f", "7a5e3f", "927455", "a98a68"]
SAND = ["8c7340", "a98d52", "c3a86a", "d8c184", "e6d49e"]
SNOW = ["8ea4bc", "a8bcd0", "c3d3e2", "dde8f1", "f5f9fc"]
MIST = ["b7cfe0", "cbdeeb", "dfecf4", "eef5f9", "ffffff"]
WATER = ["7fb2d6", "a3cce6", "c8e2f2", "e6f3fa", "ffffff"]
GORE = ["1e0003", "2e0006", "40040a", "54080f", "661016"]
WISP = ["6a6662", "837f7a", "9c9892", "b5b1ab", "cdc9c3"]
POWDER = ["3c3835", "5a534e", "7a726a", "9a9188", "b5ada4"]


def gen_puff(seed: int, pal: list, *, sy: float = 1.0, base: float = 0.0, rise: float = -0.08, settle: float = 0.0,
             speed: float = 2.2, grow: float = 0.56, k: int = 7, centre: float = 0.62, thin: float = 1.0,
             amax: float = 1.0, fade: float = 0.0, thr0: float = 0.08, grain: float = 0.0, sparkle: int = 0,
             warp: float = 0.22, push: tuple = (0.75, 0.45), ground: float = 0.0) -> list:
    """The puff family: a mass that billows out (`speed`, `grow`), drifts (`rise`, sinks late with
    `settle`), thins along its noise from `fade` on; squashed `sy`, never saturating when `thin` < 1,
    speckled with `grain`, with `sparkle` bright points (snow), cut flat at `ground` (a cloud sitting
    on the ground)."""
    rng = np.random.default_rng(seed)
    big = fbm(128, 4, 4, rng)
    fine = fbm(128, 8, 3, rng)
    spec = lobe_spec(rng, k, centre)
    speck = rng.random((FR, FR))
    stars = [(rng.uniform(0, 2 * np.pi), rng.uniform(0.15, 0.7)) for _ in range(sparkle)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        r = 0.3 + grow * (1 - (1 - t) ** speed)
        cy = base + rise * t + settle * t * t
        pf = Puff(big, fine, spec, t, r, 0.0, cy, push[0] + push[1] * t, warp, sy)
        d = pf.density(U, V)
        n = pf.noise(U, V)
        thr = thr0 + 0.85 * max(0.0, (t - fade) / (1.0 - fade)) ** 1.4
        body = np.clip(d * 2.5 * thin, 0.0, 1.0)
        a = np.clip((body * (0.3 + 1.1 * n) - thr) / 0.22, 0.0, 1.0) * (1.0 - 0.2 * t) * amax
        if grain > 0.0:
            a = a * np.where(speck < 0.4, 1.0 - grain, 1.0)
        if ground > 0.0:
            a = a * np.clip((ground - V) / 0.06, 0.0, 1.0)
        rgb = palette(shade_of(pf), pal)
        rgba = frame(rgb, a)
        if t < 0.7:
            for ang, off in stars:
                x = np.cos(ang) * off * r * 1.3
                y = cy + np.sin(ang) * off * r * 1.3 * sy
                px = int((x + 1) * FR / 2)
                py = int((y + 1) * FR / 2)
                if 0 <= px < FR and 0 <= py < FR and rgba[py, px, 3] > 60:
                    rgba[py, px, :3] = 255.0
                    rgba[py, px, 3] = 255.0
        frames.append(rgba)
    return frames


def gen_splash() -> list:
    """White water: a column heaving up, breaking into droplets at the top, falling back on a
    spreading foam disc."""
    rng = np.random.default_rng(7311)
    big = fbm(128, 4, 4, rng)
    fine = fbm(128, 8, 3, rng)
    drops = [(rng.uniform(-2.7, -0.45), rng.uniform(0.7, 1.7), rng.uniform(0.0, 0.25)) for _ in range(30)]
    water = 0.62
    frames = []
    for i in range(N):
        t = i / (N - 1)
        up = min(t / 0.4, 1.0) ** 0.6
        fall = max(0.0, (t - 0.5) / 0.5) ** 1.4
        top = water - 0.95 * up + 0.8 * fall
        bottom = water + 0.1
        height = max(bottom - top, 0.15)
        cy = (bottom + top) / 2
        rx = 0.16 + 0.2 * up + 0.3 * fall
        pf = Puff(big, fine, COLUMN, t, rx, 0.0, cy, 0.85, warp=0.4, sy=(height / 2) / rx, scroll=1.5)
        d = pf.density(U, V)
        n = pf.noise(U, V)
        frac = np.clip((V - top) / max(bottom - top, 1e-3), 0.0, 1.0)
        body = np.clip(d * 2.2 * 0.85 * (1.0 - 0.5 * (1.0 - frac) ** 1.5), 0.0, 1.0)
        thr = 0.1 + 0.9 * max(0.0, (t - 0.3) / 0.7) ** 1.3
        a = np.clip((body * (0.4 + 1.0 * n) - thr) / 0.22, 0.0, 1.0)
        rgb = palette(shade_of(pf, 0.3, 0.7), WATER)
        if t > 0.08:
            ell = (U / (0.3 + 0.65 * t)) ** 2 + ((V - water - 0.05) / 0.1) ** 2
            fm = ell < 1.0
            a[fm] = np.maximum(a[fm], 0.9 - 0.6 * t)
            rgb[fm] = hexc(WATER[3 if t < 0.5 else 2])
        rgba = frame(rgb, a)
        for ang, sp, delay in drops:
            tt = t - 0.1 - delay
            if tt <= 0.0:
                continue
            y0 = water - 0.95 * min((0.1 + delay) / 0.4, 1.0) ** 0.6
            x = np.cos(ang) * sp * tt
            y = y0 + np.sin(ang) * sp * tt + 2.4 * tt * tt
            if y > water:
                continue
            dot(rgba, x, y, hexc(WATER[4]), 2 if tt < 0.3 else 1)
        frames.append(rgba)
    return frames


def hot_frame(temp: np.ndarray) -> tuple:
    """Fire colours by temperature: opaque where it burns, a dithered dark-red rim round that."""
    rgb = np.zeros((FR, FR, 3))
    alpha = np.zeros((FR, FR))
    for lim, col in reversed(FIRE):
        m = temp > lim
        rgb[m] = col
        alpha[m] = 1.0 if lim > 0.25 else 0.67
    return rgb, alpha


def gen_fire() -> list:
    """A lick of flame: a tongue that grows up from its base, flickers (the noise runs up it),
    then lifts off and burns out from the bottom."""
    rng = np.random.default_rng(7312)
    big = fbm(128, 4, 4, rng)
    fine = fbm(128, 8, 3, rng)
    frames = []
    for i in range(N):
        t = i / (N - 1)
        lift = max(0.0, (t - 0.5) / 0.5) ** 1.3
        bottom = 0.85 - 1.2 * lift
        height = 0.6 + 0.9 * min(t / 0.35, 1.0) ** 0.7 - 0.6 * lift
        top = bottom - height
        cy = (bottom + top) / 2
        rx = 0.3 + 0.08 * np.sin(t * np.pi) - 0.12 * lift
        pf = Puff(big, fine, COLUMN, t, rx, 0.0, cy, 0.85, warp=0.28, sy=(height / 2) / rx, scroll=1.6)
        d = pf.density(U, V)
        n = pf.noise(U, V)
        frac = np.clip((V - top) / max(bottom - top, 1e-3), 0.0, 1.0)
        taper = 1.0 - 0.6 * (1.0 - frac) ** 1.6
        temp = d ** 0.7 * taper * (0.45 + 1.4 * n ** 1.3) * (1.35 - 0.8 * lift)
        rgb, alpha = hot_frame(temp)
        frames.append(frame(rgb, alpha))
    return frames


def gen_fireball() -> list:
    """A ball of fire that blooms, burns from the rim in and shrinks away hot (no soot: the
    explosion sheet has that), throwing a few embers."""
    rng = np.random.default_rng(7313)
    big = fbm(128, 4, 4, rng)
    fine = fbm(128, 8, 3, rng)
    spec = lobe_spec(rng, 6, 0.66)
    sparks = [(rng.uniform(0, 2 * np.pi), rng.uniform(0.5, 0.9)) for _ in range(10)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        r = 0.22 + 0.62 * (1 - np.exp(-t * 7.0)) - 0.3 * max(0.0, (t - 0.55) / 0.45) ** 1.5
        pf = Puff(big, fine, spec, t, r, 0.0, -0.1 * t, 0.8 + 0.3 * t)
        d = pf.density(U, V)
        n = pf.noise(U, V)
        heat = 1.9 * np.exp(-t * 2.4)
        temp = d ** 0.6 * heat * (0.2 + 1.6 * n ** 1.5)
        if i == 0:
            temp = np.maximum(temp, 2.0 * np.clip(1.0 - RAD / 0.45, 0.0, 1.0))
        rgb, alpha = hot_frame(temp)
        rgba = frame(rgb, alpha)
        if 0.25 < t < 0.95:
            for ang, sp in sparks:
                x = np.cos(ang) * (0.2 + sp * (t - 0.2) ** 0.7)
                y = np.sin(ang) * (0.2 + sp * (t - 0.2) ** 0.7) + 0.4 * t * t
                dot(rgba, x, y, EMBER[min(len(EMBER) - 1, int(t * len(EMBER)))], 2 if t < 0.55 else 1)
        frames.append(rgba)
    return frames


def gen_muzzle() -> list:
    """Black powder going off: a star flash with a hot heart, and a ring of powder smoke puffs
    thrown out round it that drift apart and thin."""
    rng = np.random.default_rng(7314)
    big = fbm(128, 4, 4, rng)
    fine = fbm(128, 8, 3, rng)
    spec = lobe_spec(rng, 5, 0.6)
    angs = [(2 * np.pi * k / 5 + rng.uniform(-0.3, 0.3), rng.uniform(0.8, 1.2)) for k in range(5)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        ring_r = 0.08 + 0.55 * (1 - np.exp(-t * 3.5))
        pr = 0.28 + 0.2 * t
        d = np.zeros((FR, FR))
        for ang, k in angs:
            pf = Puff(big, fine, spec, t, pr * k, np.cos(ang) * ring_r, np.sin(ang) * ring_r * 0.85, 0.8)
            d = np.maximum(d, pf.density(U, V))
        whole = Puff(big, fine, spec, t, 1.0, 0.0, 0.0, 1.0)
        n = whole.noise(U, V)
        body = np.clip(d * 2.5, 0.0, 1.0)
        thr = 0.1 + 0.8 * max(0.0, (t - 0.35) / 0.65) ** 1.3
        a = np.clip((body * (0.35 + 1.0 * n) - thr) / 0.22, 0.0, 1.0) * (0.9 - 0.2 * t)
        s = int(0.08 * FR)
        d_lit = np.roll(np.roll(d, -int(round(LIGHT[1] * s)), 0), -int(round(LIGHT[0] * s)), 1)
        rim = np.clip((d - d_lit) * 2.0, -0.5, 0.5)
        shade = np.clip(0.2 + 0.7 * (0.5 + 0.55 * rim + 0.45 * (n - 0.5)) - 0.1 * V, 0.0, 1.0)
        rgb = palette(shade, POWDER)
        glow = np.clip(1.0 - t / 0.3, 0.0, 1.0) * np.clip(1.0 - RAD / (ring_r + pr), 0.0, 1.0)
        rgb[glow > 0.35] = FIRE[2][1]
        rgb[glow > 0.6] = FIRE[1][1]
        if t < 0.22:
            k = 1.0 - t / 0.22
            m = star_mask(0.95 * k, 8, 0.2, 0.2)
            rgb[m] = FIRE[1][1]
            rgb[m & (RAD < 0.5 * k)] = FIRE[0][1]
            a[m] = 1.0
            disc = RAD < 0.32 * k
            rgb[disc] = FIRE[0][1]
            a[disc] = 1.0
        frames.append(frame(rgb, a))
    return frames


def gen_sparks() -> list:
    """A burst of sparks: streaks flung out from a flash that slow, fall and cool."""
    rng = np.random.default_rng(7315)
    sp = [(rng.uniform(0, 2 * np.pi), rng.uniform(0.55, 1.0), rng.uniform(0.1, 0.22)) for _ in range(20)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        rgba = np.zeros((FR, FR, 4))
        if t < 0.18:
            k = 1.0 - t / 0.18
            m = star_mask(0.75 * k, 6, 0.3, 0.3) | (RAD < 0.3 * k)
            rgba[m, :3] = FIRE[1][1]
            rgba[m, 3] = 255.0
            core = RAD < 0.2 * k
            rgba[core, :3] = FIRE[0][1]
        keep = 1.0 - max(0.0, (t - 0.7) / 0.3)
        for j, (ang, s, ln) in enumerate(sp):
            if (j * 0.37) % 1.0 > keep:
                continue
            travel = s * (1 - np.exp(-t * 3.2)) * 1.15
            hx = np.cos(ang) * travel
            hy = np.sin(ang) * travel + 1.0 * t * t
            vx = np.cos(ang) * s * 3.2 * np.exp(-t * 3.2)
            vy = np.sin(ang) * s * 3.2 * np.exp(-t * 3.2) + 2.0 * t
            vl = max(np.hypot(vx, vy), 1e-3)
            tail = ln * (1.0 - 0.6 * t)
            col = EMBER[min(len(EMBER) - 1, int(t * len(EMBER)))]
            line(rgba, hx - vx / vl * tail, hy - vy / vl * tail, hx, hy, col, 2 if t < 0.4 else 1)
        frames.append(rgba)
    return frames


GLINT_GREY = [hexc("8c8c8c"), hexc("b3b3b3"), hexc("d9d9d9"), hexc("ffffff")]


def arm_mask(reach: float, dx: float, dy: float, w: float) -> np.ndarray:
    along = U * dx + V * dy
    across = -U * dy + V * dx
    return (np.abs(along) < reach) & (np.abs(across) < w * (1.0 - np.abs(along) / max(reach, 1e-3)))


def gen_glint() -> list:
    """A star of light (grey-white: the burst's colour tints it): four points that flare out
    fast and shrink away, a halo, and a thin ring racing out of it."""
    frames = []
    for i in range(N):
        t = i / (N - 1)
        k = min(t / 0.2, 1.0) * (1.0 - max(0.0, (t - 0.2) / 0.8)) ** 1.3
        rgb = np.zeros((FR, FR, 3))
        a = np.zeros((FR, FR))
        halo = RAD < 0.3 * k
        rgb[halo] = GLINT_GREY[0]
        a[halo] = 0.5
        if 0.15 < t < 0.85:
            rr = 0.15 + 0.75 * t
            ring = np.abs(RAD - rr) < 0.035
            rgb[ring] = GLINT_GREY[1]
            a[ring] = 0.8 * (1.0 - t)
        arms = arm_mask(0.95 * k, 0.0, 1.0, 0.09) | arm_mask(0.7 * k, 1.0, 0.0, 0.09)
        arms |= arm_mask(0.35 * k, 0.707, 0.707, 0.06) | arm_mask(0.35 * k, 0.707, -0.707, 0.06)
        rgb[arms] = GLINT_GREY[2]
        a[arms] = 1.0
        core = RAD < 0.12 * k
        rgb[core] = GLINT_GREY[3]
        a[core] = 1.0
        frames.append(frame(rgb, a))
    return frames


def gen_magic() -> list:
    """A burst of light (grey-white, tinted per weapon tree in the game): a soft core that
    blooms and thins to a ring, motes thrown out of it."""
    rng = np.random.default_rng(7317)
    big = fbm(128, 4, 4, rng)
    motes = [2 * np.pi * k / 8 + rng.uniform(-0.2, 0.2) for k in range(8)]
    greys = [hexc("8c8c8c"), hexc("b3b3b3"), hexc("d9d9d9"), hexc("ffffff")]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        r = 0.2 + 0.6 * (1 - np.exp(-t * 5.0))
        n = sample(big, U * 0.9 + 0.3 * t, V * 0.9 - 0.2 * t)
        core = np.clip(1.0 - (RAD / r) ** 2, 0.0, 1.0) * (0.45 + 0.9 * n) - (0.1 + 0.9 * max(0.0, (t - 0.25) / 0.75) ** 1.2)
        a = np.clip(core / 0.25, 0.0, 1.0)
        shade = np.clip(1.0 - RAD / r * 0.6 + 0.2 * (n - 0.5), 0.0, 1.0)
        idx = np.clip((shade * len(greys)).astype(int), 0, len(greys) - 1)
        rgb = np.array(greys)[idx]
        rr = 0.2 + 0.72 * t
        ring = np.abs(RAD - rr) < 0.045
        a[ring] = np.maximum(a[ring], 0.9 * (1.0 - t))
        rgb[ring] = greys[2]
        rgba = frame(rgb, a)
        if t < 0.9:
            dist = 0.15 + 0.8 * t ** 0.8
            for ang in motes:
                dot(rgba, np.cos(ang) * dist, np.sin(ang) * dist, greys[3], 2 if t < 0.5 else 1)
        frames.append(rgba)
    return frames


def gen_wisp() -> list:
    """Thin tall smoke (a chimney's): a narrow column rising, widening at the top as it
    thins away."""
    rng = np.random.default_rng(7318)
    big = fbm(128, 4, 4, rng)
    fine = fbm(128, 8, 3, rng)
    frames = []
    for i in range(N):
        t = i / (N - 1)
        rx = 0.45 + 0.25 * t
        ry = 0.75 + 0.2 * t
        cy = 0.2 - 0.35 * t
        pf = Puff(big, fine, COLUMN, t, rx, 0.0, cy, 0.85, warp=0.32, sy=ry / rx, scroll=0.9)
        d = pf.density(U, V)
        n = pf.noise(U, V)
        frac = np.clip((V - (cy - ry)) / (2 * ry), 0.0, 1.0)
        widen = 0.5 + 0.5 * (1.0 - frac)
        body = np.clip(d * 2.0 * widen * 0.8, 0.0, 1.0)
        thr = 0.14 + 0.75 * t ** 1.6
        a = np.clip((body * (0.3 + 1.1 * n) - thr) / 0.22, 0.0, 1.0) * 0.75
        rgb = palette(shade_of(pf), WISP)
        frames.append(frame(rgb, a))
    return frames


SHEETS = {
    "smoke": gen_smoke,
    "explosion": gen_explosion,
    "dust": lambda: gen_puff(7303, BROWN, speed=3.0, rise=-0.05, settle=0.12, fade=0.1),
    "dust_low": lambda: gen_puff(7304, BROWN, sy=0.5, base=0.3, grow=0.5, speed=2.6, rise=0.0, push=(0.85, 0.35), fade=0.15, ground=0.74),
    "sand": lambda: gen_puff(7305, SAND, speed=3.0, rise=-0.05, settle=0.12, fade=0.1, grain=0.55),
    "snow": lambda: gen_puff(7306, SNOW, speed=2.6, rise=-0.04, settle=0.1, fade=0.1, sparkle=7),
    "mist": lambda: gen_puff(7307, MIST, sy=0.75, thin=0.55, speed=2.0, grow=0.6, amax=0.7, warp=0.3),
    "blood": lambda: gen_puff(7308, GORE, thin=0.55, speed=4.0, grow=0.5, rise=-0.04, thr0=0.12, amax=0.85, warp=0.3),
    "splash": gen_splash,
    "fire": gen_fire,
    "fireball": gen_fireball,
    "muzzle": gen_muzzle,
    "sparks": gen_sparks,
    "glint": gen_glint,
    "magic": gen_magic,
    "wisp": gen_wisp,
}


def sheet(frames: list) -> Image.Image:
    rows = (len(frames) + COLS - 1) // COLS
    out = np.zeros((rows * FR, COLS * FR, 4))
    for i, f in enumerate(frames):
        r, c = divmod(i, COLS)
        out[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR] = f
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def preview(images: dict) -> None:
    os.makedirs(PREVIEW, exist_ok=True)
    cell = COLS * FR + 8
    label = 12
    cols = 4
    rows = (len(images) + cols - 1) // cols
    canvas = Image.new("RGBA", (cols * cell, rows * (cell + label)), (40, 70, 110, 255))
    draw = ImageDraw.Draw(canvas)
    for i, (name, img) in enumerate(images.items()):
        r, c = divmod(i, cols)
        x, y = c * cell, r * (cell + label)
        draw.text((x + 2, y), name, fill=(255, 255, 255, 255))
        canvas.alpha_composite(img, (x, y + label))
    canvas.resize((canvas.width * 2, canvas.height * 2), Image.NEAREST).save(os.path.join(PREVIEW, "sheets.png"))


def main() -> None:
    names = sys.argv[1:] or list(SHEETS)
    for n in names:
        if n not in SHEETS:
            raise SystemExit("no sheet '%s' (have: %s)" % (n, ", ".join(SHEETS)))
    os.makedirs(OUT, exist_ok=True)
    images = {}
    for name, gen in SHEETS.items():
        path = os.path.join(OUT, "flip_%s.png" % name)
        if name in names:
            img = sheet(gen())
            img.save(path)
            print("  wrote assets/textures/fx/flip_%s.png %s" % (name, img.size))
        else:
            img = Image.open(path).convert("RGBA")
        images[name] = img
    preview(images)
    print("  preview tools/dev/out/flipbook/sheets.png (%d sheets, %.1f MB of RGBA8 with mips)" % (
        len(images), sum(im.width * im.height * 4 * 4 / 3 for im in images.values()) / 1e6))


if __name__ == "__main__":
    main()
