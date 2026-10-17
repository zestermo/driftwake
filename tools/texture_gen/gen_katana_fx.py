#!/usr/bin/env python3
"""
The katana's drawn slashes: a clean crescent of steel for the plain blade, and once its
element is awakened (the katana tree's mastery) billowing steel-blue pixel clouds drawn the
way ukiyo-e prints draw cloud (round lobes outlined in light, little spiral curls inside,
edges rolling over) shedding sakura petals.

Usage (from the project root):
    py tools/texture_gen/gen_katana_fx.py [name ...]    (no names: all of them)

Output (assets/textures/fx/):
    flip_steel_slash.png, flip_katana_slash.png, flip_katana_cloud.png: 16 frames of 128 px in
        a 4x4 grid, played once over a particle's life by FX.flipbook
    flip_sakura.png: 16 frames of 64 px, a petal turning over as it falls
    steel_trail.png, petal_trail.png: 8 frames of 256x64 stacked, tiling along their length:
        the strips PetalRibbon and BladePetals flow along
and a preview at tools/dev/out/flipbook/katana.png. Deterministic (a seed per sheet).
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "fx")
PREVIEW = os.path.join(ROOT, "tools", "dev", "out", "flipbook")

FR = 128
COLS = 4
N = 16
PX = 2.0 / FR

_yy, _xx = np.mgrid[0:FR, 0:FR]
U = (_xx + 0.5 - FR / 2) / (FR / 2)
V = (_yy + 0.5 - FR / 2) / (FR / 2)  # down is +
RAD = np.sqrt(U ** 2 + V ** 2)


def hexc(s: str) -> np.ndarray:
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


# plain steel: dark line, deep, mid, light, pale, bright, white; and dust
STEEL = [hexc(c) for c in ["3a4252", "5c6779", "8592a6", "aebacb", "d3dbe6", "edf1f7", "ffffff"]]
DUST = [hexc(c) for c in ["8c8172", "ada392", "cfc7b6"]]
# the awakened cloud: navy line, deep, mid, light, pale, foam, white
SKY = [hexc(c) for c in ["1f2d55", "35528e", "5b80c0", "8fb0e2", "bed4f3", "e3edfc", "ffffff"]]
# sakura: deep, rose, pink, pale, blush
SAKURA = [hexc(c) for c in ["b23c70", "dd6c9c", "f39dc0", "ffcfe2", "fff0f6"]]


def stroke(pts: np.ndarray, widths: np.ndarray) -> tuple:
    """A thick line along pts (n x 2, frame coords), a union of discs of the given widths: per
    pixel the nearest sample, its distance in widths, the offset across in widths (+: left of
    travel, the outside of a clockwise curve); per sample the left normal and the tangent."""
    du = U[..., None] - pts[:, 0]
    dv = V[..., None] - pts[:, 1]
    rel = (du ** 2 + dv ** 2) / np.maximum(widths, 1e-4) ** 2
    k = np.argmin(rel, axis=-1)
    near = np.sqrt(np.take_along_axis(rel, k[..., None], -1)[..., 0])
    n = len(pts)
    tan = pts[np.minimum(np.arange(n) + 1, n - 1)] - pts[np.maximum(np.arange(n) - 1, 0)]
    tan /= np.maximum(np.linalg.norm(tan, axis=-1, keepdims=True), 1e-6)
    nrm = np.stack([tan[:, 1], -tan[:, 0]], -1)
    side = ((U - pts[k, 0]) * nrm[k, 0] + (V - pts[k, 1]) * nrm[k, 1]) / np.maximum(widths[k], 1e-4)
    return k, near, side, nrm, tan


def put(img: np.ndarray, x: float, y: float, col: np.ndarray, size: int = 1) -> None:
    px = int((x + 1) * FR / 2)
    py = int((y + 1) * FR / 2)
    if px < 0 or py < 0 or px + size > img.shape[1] or py + size > img.shape[0]:
        return
    img[py:py + size, px:px + size, :3] = col
    img[py:py + size, px:px + size, 3] = 255.0


def curl(img: np.ndarray, x: float, y: float, r_px: float, a0: float, turn: float, col: np.ndarray, thick: int = 1) -> None:
    """A little spiral winding in from angle a0 (a cloud's curl, a gust's hook)."""
    n = int(r_px * abs(turn) * 10) + 10
    for i in range(n):
        f = i / (n - 1)
        a = a0 + turn * 2 * np.pi * f
        r = r_px * (1.0 - 0.75 * f)
        put(img, x + np.cos(a) * r * PX, y + np.sin(a) * r * PX, col, thick if f < 0.4 else 1)


def gobs(s: np.ndarray, w: np.ndarray, tail: float, head: float, brk: float, freq: float = 30.0) -> np.ndarray:
    """The trailing part pinched into round puffs that shrink away (widths to ~0 between)."""
    if brk <= 0.0:
        return w
    trailing = np.clip(1.0 - (s - tail) / max((head - tail) * (0.3 + 0.6 * brk), 1e-3), 0.0, 1.0)
    g = 0.5 + 0.5 * np.sin(s * freq)
    keep = np.clip((g - brk * 0.95 * np.minimum(trailing * 2.0, 1.0)) / 0.3, 0.0, 1.0)
    return w * np.where(trailing > 0.0, np.maximum(keep, 1e-3), 1.0) * (1.0 - 0.3 * brk)


def petal(img: np.ndarray, x: float, y: float, size_px: float, ang: float, flip: float, scale: float = PX) -> None:
    """One sakura petal: a rounded teardrop with a notch at its wide end, foreshortened by `flip`
    (-1..1: turning over, its back paler)."""
    pal = SAKURA if flip >= 0 else [SAKURA[1], SAKURA[2], SAKURA[3], SAKURA[4], SAKURA[4]]
    sx = size_px
    sy = size_px * max(abs(flip), 0.2) * 1.05
    ca, sa = np.cos(ang), np.sin(ang)
    h, w = img.shape[:2]
    rr = int(sx + 2)
    cx = (x + 1) / scale
    cy = (y + 1) / scale
    for oy in range(-rr, rr + 1):
        for ox in range(-rr, rr + 1):
            px, py = int(cx + ox), int(cy + oy)
            if px < 0 or py < 0 or px >= w or py >= h:
                continue
            lx = (ox * ca + oy * sa) / sx
            ly = (-ox * sa + oy * ca) / max(sy, 0.5)
            # a teardrop: narrow at -x, round at +x, a notch in the round end
            t = (lx + 1.0) * 0.5
            half = 0.62 * np.sqrt(max(t, 0.0)) * np.sqrt(max(1.0 - t, 0.0)) * 2.0 * (0.55 + 0.45 * t)
            if lx < -1.0 or lx > 1.0 or abs(ly) > half:
                continue
            if lx > 0.72 and abs(ly) < 0.16:
                continue
            c = pal[2]
            if ly > half * 0.35:
                c = pal[1]
            if ly < -half * 0.4 or lx < -0.6:
                c = pal[3]
            if abs(ly) < 0.08 and -0.5 < lx < 0.5:
                c = pal[4] if flip >= 0 else pal[3]
            img[py, px, :3] = c
            img[py, px, 3] = 255.0


def frame_rgba(rgb: np.ndarray, mask: np.ndarray) -> np.ndarray:
    rgba = np.zeros((FR, FR, 4))
    rgba[..., :3] = rgb
    rgba[..., 3] = mask.astype(float) * 255.0
    return rgba


def shade_steel(side: np.ndarray, s: np.ndarray, t: float) -> np.ndarray:
    """Steel across a stroke, outside (+1) to inside (-1): a white edge, bright and pale with thin
    speed lines racing along, light, a mid band and a dark line inside."""
    rgb = np.empty((FR, FR, 3))
    rgb[:] = STEEL[3]
    rgb[side < -0.25 + 0.08 * np.sin(s * 9.0 - t * 6.0)] = STEEL[2]
    rgb[side > 0.25] = STEEL[4]
    for off, fq, ph in ((-0.05, 15.0, 0.0), (0.42, 11.0, 1.9), (-0.5, 8.0, 3.3)):
        ln = np.abs(side - off) < 0.07
        dash = np.sin(s * fq - t * 18.0 + ph) > -0.1
        rgb[ln & dash] = STEEL[5] if off > -0.3 else STEEL[3]
    rgb[side > 0.62] = STEEL[5]
    rgb[side > 0.8] = STEEL[6]
    rgb[side < -0.82] = STEEL[1]
    return rgb


def shade_sky(side: np.ndarray, s: np.ndarray, t: float) -> np.ndarray:
    """Cloud across a stroke: white and foam outside, pale, light with thin light lines like a
    brush's, mid, deep, a navy line inside."""
    rgb = np.empty((FR, FR, 3))
    rgb[:] = SKY[3]
    rgb[side < -0.3 + 0.1 * np.sin(s * 7.0 - t * 4.0)] = SKY[2]
    rgb[side < -0.66 + 0.06 * np.sin(s * 13.0 + t * 3.0)] = SKY[1]
    rgb[side > 0.18 + 0.08 * np.sin(s * 10.0 + t * 5.0)] = SKY[4]
    for off, fq, ph in ((-0.42, 9.0, 0.0), (0.0, 12.0, 1.4)):
        ln = np.abs(side - off - 0.05 * np.sin(s * fq * 0.6 - t * 7.0 + ph)) < 0.07
        dash = np.sin(s * fq - t * 12.0 + ph) > -0.2
        rgb[ln & dash] = SKY[4]
    rgb[side > 0.58] = SKY[5]
    rgb[side > 0.8] = SKY[6]
    rgb[side < -0.86] = SKY[0]
    return rgb


def lobes(img: np.ndarray, pts: np.ndarray, w: np.ndarray, nrm: np.ndarray, s: np.ndarray,
          spacing: float, phase: float, size: float, t: float) -> None:
    """Round cloud lobes billowing off the outside edge every `spacing` (riding along with
    `phase`), each outlined in light with a spiral curl tucked in it."""
    if len(s) < 3:
        return
    c = np.floor((s[0] - phase) / spacing) * spacing + phase
    i = 0
    while c <= s[-1]:
        j = int(np.argmin(np.abs(s - c)))
        if w[j] > 3.0 * PX and 1 <= j < len(s) - 2:
            r = w[j] * (0.62 + 0.2 * np.sin(i * 2.3)) * size
            n = nrm[j]
            cx, cy = pts[j] + n * (w[j] * 0.55)
            d = np.sqrt((U - cx) ** 2 + (V - cy) ** 2)
            disc = d < r
            img[disc, :3] = SKY[4]
            img[disc & (d > r - 2.2 * PX), :3] = SKY[6]
            img[disc & (d < r * 0.55) & ((U - cx) * n[0] + (V - cy) * n[1] < 0)] = np.append(SKY[3], 255.0)
            img[disc, 3] = 255.0
            if r > 5.0 * PX:
                a0 = np.arctan2(n[1], n[0]) + np.pi * 0.6
                curl(img, cx, cy, r / PX * 0.55, a0 + t * 1.5, 1.1 if i % 2 == 0 else -1.1, SKY[6], 1)
        c += spacing
        i += 1


def gen_steel_slash() -> list:
    """The plain blade's cut: a thin crescent of steel drawn across, bright at its outer edge,
    speed lines racing along it, a gust's hook at the head, then thinning from the tail into
    grains of dust."""
    rng = np.random.default_rng(8411)
    cx, cy, r0 = 0.0, 0.22, 0.66
    grains = [(rng.uniform(0.0, 1.0), rng.uniform(0.3, 0.8), rng.uniform(-0.5, 0.5)) for _ in range(26)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        head = 1.08 * min(t / 0.28, 1.0) ** 0.7
        tail = 1.08 * max(0.0, (t - 0.38) / 0.62) ** 1.25
        brk = max(0.0, (t - 0.4) / 0.6)
        img = np.zeros((FR, FR, 4))
        if head - tail >= 0.02:
            s = np.linspace(tail, head, 120)
            ang = 0.92 * np.pi + np.minimum(s, 1.0) * np.pi * 0.95 + np.maximum(s - 1.0, 0.0) * 2.0 * np.pi
            rad = r0 * (1.0 - 0.5 * (np.maximum(s - 1.0, 0.0) / 0.08) ** 1.5)
            pts = np.stack([cx + np.cos(ang) * rad, cy + np.sin(ang) * rad], -1)
            x = np.clip(s / 1.08, 0.0, 1.0)
            w = 0.012 + 0.085 * np.sin(np.pi * x ** 0.8) ** 0.7
            w *= np.clip((s - tail) / 0.14, 0.1, 1.0) * np.clip((head - s) / 0.05, 0.3, 1.0)
            w = gobs(s, w, tail, head, brk * 0.8, 40.0)
            k, near, side, nrm, tan = stroke(pts, w)
            img = frame_rgba(shade_steel(side, s[k], t), near < 1.0)
        # dust off the tail
        for sp, t0, off in grains:
            tt = (t - t0) / 0.4
            if tt < 0.0 or tt > 1.0 or sp > head:
                continue
            a = 0.92 * np.pi + sp * np.pi * 0.95
            p = np.array([cx + np.cos(a) * (r0 + off * 0.12), cy + np.sin(a) * (r0 + off * 0.12)])
            p += np.array([np.cos(a), np.sin(a)]) * 0.12 * tt + np.array([0.0, -0.06 * tt])
            put(img, p[0], p[1], DUST[2 if tt < 0.5 else 1], 2 if tt < 0.4 else 1)
        frames.append(img)
    return frames


def gen_katana_slash() -> list:
    """The awakened cut: a billowing crescent of steel-blue cloud swept across, lobes rolling
    over off its outside edge with curls tucked in them, the head curling in on itself, then
    breaking from the tail into round puffs, sakura petals thrown off it."""
    rng = np.random.default_rng(8412)
    cx, cy, r0 = 0.0, 0.2, 0.62
    curl_s = 0.22
    pet = [(rng.uniform(0.1, 1.1), rng.uniform(0.15, 0.6), rng.uniform(0.0, 6.3), rng.uniform(2.2, 3.6), rng.uniform(0.6, 1.4))
           for _ in range(9)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        head = (1.0 + curl_s) * min(t / 0.3, 1.0) ** 0.7
        tail = (1.0 + curl_s) * max(0.0, (t - 0.42) / 0.58) ** 1.3
        brk = max(0.0, (t - 0.42) / 0.58)
        img = np.zeros((FR, FR, 4))
        if head - tail >= 0.02:
            s = np.linspace(tail, head, 120)
            ang = 0.9 * np.pi + np.minimum(s, 1.0) * np.pi + np.maximum(s - 1.0, 0.0) * 1.4 * np.pi
            rad = r0 * (1.0 - 0.6 * (np.maximum(s - 1.0, 0.0) / curl_s) ** 1.5)
            pts = np.stack([cx + np.cos(ang) * rad, cy + np.sin(ang) * rad], -1)
            x = np.clip(s / (1.0 + curl_s), 0.0, 1.0)
            w = 0.025 + 0.15 * np.sin(np.pi * x ** 0.8) ** 0.6
            w *= np.clip((s - tail) / 0.12, 0.15, 1.0) * np.clip((head - s) / 0.05, 0.25, 1.0)
            w = gobs(s, w, tail, head, brk)
            k, near, side, nrm, tan = stroke(pts, w)
            img = frame_rgba(shade_sky(side, s[k], t), near < 1.0)
            lobes(img, pts, w, nrm, s, 0.15, t * 0.3, 1.0 - 0.4 * brk, t)
        for sp, t0, a0, sz, spin in pet:
            tt = (t - t0) / 0.55
            if tt < 0.0 or tt > 1.0 or sp > head:
                continue
            a = 0.9 * np.pi + min(sp, 1.0) * np.pi
            out = np.array([np.cos(a), np.sin(a)])
            p = np.array([cx, cy]) + out * (r0 + 0.1 + 0.3 * tt) + np.array([0.06 * np.sin(tt * 5 + a0), 0.25 * tt * tt])
            petal(img, p[0], p[1], sz, a0 + spin * tt * 6.0, np.cos(a0 + tt * 7.0))
        frames.append(img)
    return frames


def gen_katana_cloud() -> list:
    """A puff of awakened cloud: lobes billowing out from a knot, outlined in light with curls in
    them, turning a little, then shrinking apart into small puffs; a petal or two let go."""
    rng = np.random.default_rng(8413)
    lob = [(rng.uniform(0, 2 * np.pi), rng.uniform(0.18, 0.3), rng.uniform(0.32, 0.5)) for _ in range(6)]
    pet = [(rng.uniform(0.0, 6.3), rng.uniform(0.2, 0.45), rng.uniform(2.0, 3.2)) for _ in range(3)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        grow = min(t / 0.35, 1.0) ** 0.6
        gone = max(0.0, (t - 0.45) / 0.55)
        spin = 0.6 * t
        img = np.zeros((FR, FR, 4))
        for j, (a, rr, dd) in enumerate(lob):
            aa = a + spin
            dist = dd * (0.35 + 0.65 * grow) * (1.0 + 0.5 * gone)
            r = rr * (0.4 + 0.6 * grow) * (1.0 - gone) ** 1.2
            if r < 2.0 * PX:
                continue
            cx, cy = np.cos(aa) * dist, np.sin(aa) * dist * 0.8 - 0.1 * gone
            d = np.sqrt((U - cx) ** 2 + (V - cy) ** 2)
            disc = d < r
            col = np.empty((FR, FR, 3))
            col[:] = SKY[3]
            col[(V - cy) > r * 0.25] = SKY[2]
            col[(V - cy) > r * 0.6] = SKY[1]
            col[(V - cy) < -r * 0.3] = SKY[4]
            col[d > r - 2.2 * PX] = SKY[6]
            col[(d > r - 2.2 * PX) & ((V - cy) > r * 0.45)] = SKY[0]
            img[disc, :3] = col[disc]
            img[disc, 3] = 255.0
            if r > 6.0 * PX:
                curl(img, cx, cy, r / PX * 0.55, aa + t * 2.0, 1.1 if j % 2 else -1.1, SKY[5], 1)
        if t < 0.5:
            knot = RAD < 0.16 * grow * (1.0 - t)
            img[knot, :3] = SKY[4]
            img[knot, 3] = 255.0
        for a0, t0, sz in pet:
            tt = (t - t0) / 0.6
            if 0.0 <= tt <= 1.0:
                p = np.array([np.cos(a0), np.sin(a0) * 0.6]) * (0.45 + 0.35 * tt) + np.array([0.0, 0.3 * tt * tt])
                petal(img, p[0], p[1], sz, a0 + tt * 5.0, np.cos(a0 * 2 + tt * 8.0))
        frames.append(img)
    return frames


def gen_sakura() -> list:
    """A petal turning over as it falls: 16 frames round one tumble (rotating and foreshortening,
    its back showing paler when it's over), in a 64 px frame."""
    fr = 64
    frames = []
    for i in range(N):
        t = i / N
        img = np.zeros((fr, fr, 4))
        petal(img, 0.0, 0.0, 22.0, 0.5 + 2 * np.pi * t * 0.5, np.cos(2 * np.pi * t), 2.0 / fr)
        frames.append(img)
    return frames


TRAIL_W = 256
TRAIL_H = 64
TRAIL_FRAMES = 8


def _trail_put(img, x, y, col, size=1):
    x = int(x) % TRAIL_W
    y = int(y)
    if 0 <= y and y + size <= TRAIL_H:
        for dx in range(size):
            img[y:y + size, (x + dx) % TRAIL_W, :3] = col
            img[y:y + size, (x + dx) % TRAIL_W, 3] = 255.0


def _trail_spiral(img, x, y, r, a0, turn, col, thick=1):
    n = int(r * abs(turn) * 10) + 10
    for i in range(n):
        f = i / (n - 1)
        a = a0 + turn * 2 * np.pi * f
        rr = r * (1.0 - 0.75 * f)
        _trail_put(img, x + np.cos(a) * rr, y + np.sin(a) * rr, col, thick if f < 0.4 else 1)


def gen_steel_trail() -> Image.Image:
    """The plain blade's strip, tiling along its length, 8 looping frames: a white edge with gust
    hooks curling off it, speed lines racing along a pale steel body, a darker inner band, the
    inner edge fraying into grains of dust."""
    out = np.zeros((TRAIL_H * TRAIL_FRAMES, TRAIL_W, 4))
    yy, xx = np.mgrid[0:TRAIL_H, 0:TRAIL_W]
    fx = xx / TRAIL_W
    rng = np.random.default_rng(8421)
    grains = [(rng.uniform(0, TRAIL_W), rng.uniform(0, 1), rng.integers(1, 3)) for _ in range(22)]
    for f in range(TRAIL_FRAMES):
        p = f / TRAIL_FRAMES
        ph = 2 * np.pi * p

        def top_at(x):
            q = x / TRAIL_W
            return 20.0 + 2.0 * np.sin(2 * np.pi * q * 2 + ph) + 1.0 * np.sin(2 * np.pi * q * 5 - ph * 2)

        top = top_at(xx)
        bot = 46.0 + 3.0 * np.sin(2 * np.pi * fx * 3 - ph) + 2.0 * np.sin(2 * np.pi * fx * 8 + ph * 2)
        body = (yy >= top) & (yy <= bot)
        depth = (yy - top) / np.maximum(bot - top, 1.0)
        img = np.zeros((TRAIL_H, TRAIL_W, 4))
        rgb = np.empty((TRAIL_H, TRAIL_W, 3))
        rgb[:] = STEEL[3]
        rgb[depth > 0.6 + 0.08 * np.sin(2 * np.pi * fx * 4 - ph * 2)] = STEEL[2]
        rgb[depth < 0.28] = STEEL[4]
        for j, (fr_, kq, m, dq) in enumerate(((0.36, 3, 1, 6), (0.52, 2, -1, 5), (0.7, 4, 2, 7))):
            yl = top + (bot - top) * fr_ + 1.2 * np.sin(2 * np.pi * fx * kq - ph * m + j)
            dash = np.sin(2 * np.pi * fx * dq - ph * 2 + j * 1.3) > -0.1
            rgb[(np.abs(yy - yl) < 0.7) & dash] = STEEL[5] if fr_ < 0.6 else STEEL[4]
        rgb[yy < top + 3.5] = STEEL[5]
        rgb[yy < top + 1.6] = STEEL[6]
        rgb[yy > bot - 1.5] = STEEL[1]
        img[..., :3] = rgb
        img[..., 3] = body * 255.0
        # gust hooks curling off the edge, riding forward a spacing per loop
        for c in range(4):
            x0 = c * 64 + 9 * np.sin(c * 2.1) + p * 64
            y0 = top_at(x0 % TRAIL_W)
            r = 4.5 if c % 2 == 0 else 3.0
            _trail_spiral(img, x0 + r, y0 - r + 1, r, np.pi * 0.5, -1.2, STEEL[6], 2)
        # grains of dust fraying off the inner edge
        for gx, off, sz in grains:
            q = (p + off) % 1.0
            x = gx + q * 32
            yb = 46.0 + 3.0 * np.sin(2 * np.pi * (x % TRAIL_W) / TRAIL_W * 3 - ph)
            _trail_put(img, x, yb + 2.0 + 10.0 * q, DUST[2 if q < 0.5 else 1], int(sz) if q < 0.6 else 1)
        out[f * TRAIL_H:(f + 1) * TRAIL_H] = img
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def gen_petal_trail() -> Image.Image:
    """The awakened strip, tiling along its length, 8 looping frames: a row of round cloud lobes
    billowing along the top (outlined white, curls tucked in them), light brush lines running
    through a steel-blue body, a scalloped navy inner edge, and sakura petals tumbling off the
    lobes."""
    out = np.zeros((TRAIL_H * TRAIL_FRAMES, TRAIL_W, 4))
    yy, xx = np.mgrid[0:TRAIL_H, 0:TRAIL_W]
    fx = xx / TRAIL_W
    rng = np.random.default_rng(8422)
    lob = [(c * 32 + rng.uniform(-4, 4), rng.uniform(12.0, 16.0)) for c in range(8)]
    pets = [(rng.uniform(0, TRAIL_W), rng.uniform(0, 1), rng.uniform(0, 6.3), rng.uniform(2.6, 3.8)) for _ in range(7)]
    for f in range(TRAIL_FRAMES):
        p = f / TRAIL_FRAMES
        ph = 2 * np.pi * p
        img = np.zeros((TRAIL_H, TRAIL_W, 4))
        base = 25.0
        bot = 50.0 + 2.5 * np.sin(2 * np.pi * fx * 4 - ph) + 1.5 * np.sin(2 * np.pi * fx * 9 + ph)
        # the lobes ride along a whole spacing per loop, swelling and easing as they go
        top = np.full((TRAIL_H, TRAIL_W), base)
        cents = []
        for j, (x0, r0) in enumerate(lob):
            cxl = (x0 + p * 32) % TRAIL_W
            r = r0 * (1.0 + 0.12 * np.sin(ph + j * 1.7))
            cyl = base + r * 0.25
            cents.append((cxl, cyl, r))
            for wrap in (-TRAIL_W, 0, TRAIL_W):
                dx = xx - (cxl + wrap)
                inside = np.abs(dx) < r
                yt = cyl - np.sqrt(np.maximum(r * r - dx * dx, 0.0))
                top = np.where(inside, np.minimum(top, yt), top)
        body = (yy >= top) & (yy <= bot)
        depth = (yy - base) / np.maximum(bot - base, 1.0)
        rgb = np.empty((TRAIL_H, TRAIL_W, 3))
        rgb[:] = SKY[3]
        rgb[depth > 0.5 + 0.08 * np.sin(2 * np.pi * fx * 5 - ph * 2)] = SKY[2]
        rgb[depth > 0.8 + 0.05 * np.sin(2 * np.pi * fx * 7 + ph)] = SKY[1]
        rgb[depth < 0.18] = SKY[4]
        for j, (fr_, kq, m, dq) in enumerate(((0.36, 3, 1, 5), (0.6, 2, -1, 4))):
            yl = base + (bot - base) * fr_ + 1.6 * np.sin(2 * np.pi * fx * kq - ph * m + j)
            dash = np.sin(2 * np.pi * fx * dq - ph * 2 + j * 1.3) > -0.25
            rgb[(np.abs(yy - yl) < 0.75) & dash] = SKY[4]
        rgb[yy > bot - 1.5] = SKY[0]
        img[..., :3] = rgb
        img[..., 3] = body * 255.0
        # each lobe: pale inside, outlined white along its top, a curl tucked in it
        for j, (cxl, cyl, r) in enumerate(cents):
            for wrap in (-TRAIL_W, 0, TRAIL_W):
                d = np.sqrt((xx - cxl - wrap) ** 2 + (yy - cyl) ** 2)
                disc = (d < r) & (yy <= cyl + r * 0.2)
                img[disc, :3] = SKY[4]
                img[disc & (yy < cyl - r * 0.1), :3] = SKY[5]
                rim = (d < r) & (d > r - 2.0) & (yy < cyl + 1.0)
                img[rim, :3] = SKY[6]
            _trail_spiral(img, cxl + 1.0, cyl - r * 0.15, r * 0.5, ph * 0.5 + j, 1.15 if j % 2 else -1.15, SKY[6], 1)
        # petals tumbling up and back off the lobes
        for px0, off, a0, sz in pets:
            q = (p + off) % 1.0
            x = (px0 + q * 40) % TRAIL_W
            y = base - 3.0 - 16.0 * q
            sub = np.zeros((TRAIL_H, TRAIL_W, 4))
            petal(sub, x / (TRAIL_W / 2.0) - 1.0, y / (TRAIL_W / 2.0) - 1.0, sz, a0 + q * 6.0, np.cos(a0 + q * 9.0), 2.0 / TRAIL_W)
            m = sub[..., 3] > 0
            img[m] = sub[m]
        out[f * TRAIL_H:(f + 1) * TRAIL_H] = img
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


SHEETS = {
    "steel_slash": gen_steel_slash,
    "katana_slash": gen_katana_slash,
    "katana_cloud": gen_katana_cloud,
    "sakura": gen_sakura,
}
TRAILS = {
    "steel_trail": gen_steel_trail,
    "petal_trail": gen_petal_trail,
}


def sheet(frames: list) -> Image.Image:
    fr = frames[0].shape[0]
    out = np.zeros((COLS * fr, COLS * fr, 4))
    for i, f in enumerate(frames):
        r, c = divmod(i, COLS)
        out[r * fr:(r + 1) * fr, c * fr:(c + 1) * fr] = f
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    names = sys.argv[1:] or list(SHEETS) + list(TRAILS)
    for n in names:
        if n not in SHEETS and n not in TRAILS:
            raise SystemExit("no sheet '%s' (have: %s)" % (n, ", ".join(list(SHEETS) + list(TRAILS))))
    os.makedirs(OUT, exist_ok=True)
    for name, gen in SHEETS.items():
        if name in names:
            img = sheet(gen())
            img.save(os.path.join(OUT, "flip_%s.png" % name))
            print("  wrote assets/textures/fx/flip_%s.png %s" % (name, img.size))
    for name, gen in TRAILS.items():
        if name in names:
            img = gen()
            img.save(os.path.join(OUT, "%s.png" % name))
            print("  wrote assets/textures/fx/%s.png %s" % (name, img.size))
    os.makedirs(PREVIEW, exist_ok=True)
    imgs = [Image.open(os.path.join(OUT, "flip_%s.png" % n)).convert("RGBA") for n in SHEETS]
    imgs += [Image.open(os.path.join(OUT, "%s.png" % n)).convert("RGBA") for n in TRAILS]
    w = sum(im.width for im in imgs) + 8 * len(imgs)
    h = max(im.height for im in imgs)
    canvas = Image.new("RGBA", (w, h), (120, 150, 110, 255))
    x = 0
    for im in imgs:
        canvas.alpha_composite(im, (x, 0))
        x += im.width + 8
    canvas.save(os.path.join(PREVIEW, "katana.png"))
    print("  preview tools/dev/out/flipbook/katana.png")


if __name__ == "__main__":
    main()
