#!/usr/bin/env python3
"""
The axe's drawn slashes: a heavy crescent of iron shedding dust for the plain axe, and once its
element is awakened (the axe tree's mastery) molten fire drawn the way flame-breathing art draws it
(tongues of flame licking off a crescent, hot yellow at the crest through orange to crimson, a
charred edge inside, embers flying and ash drifting off).

Usage (from the project root):
    py tools/texture_gen/gen_axe_fx.py [name ...]    (no names: all of them)

Output (assets/textures/fx/):
    flip_axe_slash.png, flip_ember_slash.png, flip_ember_cloud.png: 16 frames of 128 px in a 4x4
        grid, played once over a particle's life by FX.flipbook
    flip_cinder.png: 16 frames of 64 px, an ember flaring and cooling
    flip_ash.png: 16 frames of 64 px, a flake of ash tumbling (looped)
    axe_trail.png, ember_trail.png: 8 frames of 256x64 stacked, tiling along their length: the
        strips PetalRibbon and BladeEmbers flow along
and a preview at tools/dev/out/flipbook/axe.png. Deterministic (a seed per sheet). Built on
gen_katana_fx.py's strokes and frames.
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

from gen_katana_fx import (COLS, FR, N, PX, RAD, TRAIL_FRAMES, TRAIL_H, TRAIL_W, U, V, _trail_put, _trail_spiral,
                           curl, frame_rgba, gobs, hexc, put, sheet, stroke)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "fx")
PREVIEW = os.path.join(ROOT, "tools", "dev", "out", "flipbook")

# the plain axe: dark line, deep, mid, light, pale, bright, white (heavier, darker than the katana's)
IRON = [hexc(c) for c in ["2b2e35", "474c56", "6c737f", "959ca8", "bfc5ce", "e3e7ec", "ffffff"]]
# dust and grit off the bite: dark, mid, light, pale
DUST = [hexc(c) for c in ["6b5d4b", "8a7a63", "ab9d86", "cdc2ad"]]
# fire: char, deep, crimson, red-orange, orange, amber, yellow, white-hot
FIRE = [hexc(c) for c in ["2a0f0c", "5c1813", "9e2117", "d33c18", "f2711e", "ffa83b", "ffd85e", "fff4c6"]]
# ash: dark, mid, light, pale
ASH = [hexc(c) for c in ["3b3734", "5f5954", "8b847d", "b5aea6"]]


def shade_iron(side: np.ndarray, s: np.ndarray, t: float) -> np.ndarray:
    """Iron across a stroke, outside (+1) to inside (-1): a white edge, pale steel with speed lines,
    a heavy dark band inside and a dark line at the inner edge."""
    rgb = np.empty((FR, FR, 3))
    rgb[:] = IRON[3]
    rgb[side < -0.1 + 0.08 * np.sin(s * 8.0 - t * 5.0)] = IRON[2]
    rgb[side < -0.55 + 0.06 * np.sin(s * 13.0 + t * 4.0)] = IRON[1]
    rgb[side > 0.3] = IRON[4]
    for off, fq, ph in ((0.12, 13.0, 0.0), (0.48, 10.0, 1.7), (-0.35, 7.0, 3.1)):
        ln = np.abs(side - off) < 0.07
        dash = np.sin(s * fq - t * 16.0 + ph) > -0.1
        rgb[ln & dash] = IRON[5] if off > 0.0 else IRON[3]
    rgb[side > 0.64] = IRON[5]
    rgb[side > 0.8] = IRON[6]
    rgb[side < -0.84] = IRON[0]
    return rgb


def shade_fire(side: np.ndarray, s: np.ndarray, t: float) -> np.ndarray:
    """Fire across a stroke: white-hot and yellow at the crest, amber with yellow flow lines racing
    along, orange, red-orange, crimson, and a ragged charred edge inside."""
    rgb = np.empty((FR, FR, 3))
    rgb[:] = FIRE[4]
    rgb[side < -0.18 + 0.1 * np.sin(s * 7.0 - t * 5.0)] = FIRE[3]
    rgb[side < -0.5 + 0.08 * np.sin(s * 11.0 + t * 4.0)] = FIRE[2]
    rgb[side < -0.72 + 0.06 * np.sin(s * 17.0 - t * 3.0)] = FIRE[1]
    rgb[side > 0.12 + 0.08 * np.sin(s * 9.0 + t * 6.0)] = FIRE[5]
    for off, fq, ph in ((0.32, 12.0, 0.0), (-0.05, 9.0, 1.4), (-0.38, 7.0, 2.6)):
        ln = np.abs(side - off - 0.05 * np.sin(s * fq * 0.6 - t * 8.0 + ph)) < 0.07
        dash = np.sin(s * fq - t * 14.0 + ph) > -0.2
        rgb[ln & dash] = FIRE[6] if off > 0.0 else FIRE[5]
    rgb[side > 0.56] = FIRE[6]
    rgb[side > 0.8] = FIRE[7]
    rgb[side < -0.86 + 0.07 * np.sin(s * 23.0 + t * 2.0)] = FIRE[0]
    return rgb


def tongue(img: np.ndarray, base: np.ndarray, out: np.ndarray, back: np.ndarray, h: float, w0: float, lean: float, t: float) -> None:
    """A tongue of flame from `base` licking out along `out` and curling back along `back`: amber,
    a yellow core, a red-orange outline, the tip hooked over."""
    f = np.linspace(0.0, 1.0, 18)
    pts = base + out * (h * f * (1.0 - 0.35 * f))[:, None] + back * (lean * h * f ** 1.5)[:, None]
    ws = np.maximum(w0 * (1.0 - f) ** 0.7 * (1.0 + 0.2 * np.sin(f * 6.0 + t * 9.0)), 0.6 * PX)
    k, near, side, _, _ = stroke(pts, ws)
    m = near < 1.0
    col = np.empty((FR, FR, 3))
    col[:] = FIRE[5]
    col[(side < 0.35) & (side > -0.5)] = FIRE[6]
    col[(np.abs(side + 0.1) < 0.18) & (f[k] < 0.45)] = FIRE[7]
    col[(near > 0.7) & (side > 0.0)] = FIRE[3]
    img[m, :3] = col[m]
    img[m, 3] = 255.0


def licks(img: np.ndarray, pts: np.ndarray, w: np.ndarray, nrm: np.ndarray, tan: np.ndarray, s: np.ndarray,
          spacing: float, phase: float, size: float, t: float) -> None:
    """Tongues of flame licking off the outside edge every `spacing` (riding along with `phase`),
    leaning back against the way the crescent travels."""
    if len(s) < 3:
        return
    c = np.floor((s[0] - phase) / spacing) * spacing + phase
    i = 0
    while c <= s[-1]:
        j = int(np.argmin(np.abs(s - c)))
        if w[j] > 3.0 * PX and 1 <= j < len(s) - 2:
            h = w[j] * (1.5 + 0.5 * np.sin(i * 2.3 + t * 6.0)) * size
            tongue(img, pts[j] + nrm[j] * (w[j] * 0.3), nrm[j], -tan[j], h, w[j] * 0.75, 1.15, t)
        c += spacing
        i += 1


def specks(img: np.ndarray, t: float, items: list, at, pal: list, life: float, drift: np.ndarray) -> None:
    """Small specks (embers, ash, grit) let go along a stroke and drifting: items are (s, t0, off);
    at(s) gives the point and the outward normal there."""
    for sp, t0, off in items:
        tt = (t - t0) / life
        if tt < 0.0 or tt > 1.0:
            continue
        p0, n = at(sp)
        if p0 is None:
            continue
        p = p0 + n * (off + 0.18 * tt) + drift * tt * tt
        c = pal[min(int(tt * len(pal)), len(pal) - 1)]
        put(img, p[0], p[1], c, 2 if tt < 0.45 else 1)


def _arc(cx: float, cy: float, r0: float, a0: float, sweep: float, curl_s: float, curl_k: float):
    def at(s: np.ndarray):
        ang = a0 + np.minimum(s, 1.0) * sweep + np.maximum(s - 1.0, 0.0) * curl_k * np.pi
        rad = r0 * (1.0 - 0.55 * (np.maximum(s - 1.0, 0.0) / max(curl_s, 1e-3)) ** 1.5)
        return np.stack([cx + np.cos(ang) * rad, cy + np.sin(ang) * rad], -1)
    return at


def gen_axe_slash() -> list:
    """The plain axe's bite: a heavy crescent of iron hacked across, a white edge with speed lines
    racing along it, a dark band inside, then breaking from the tail while clods of dust and grit
    fall off the inner edge."""
    rng = np.random.default_rng(9411)
    cx, cy, r0 = 0.0, 0.22, 0.64
    path = _arc(cx, cy, r0, 0.92 * np.pi, np.pi * 0.95, 0.08, 2.0)
    clods = [(rng.uniform(0.0, 1.0), rng.uniform(0.25, 0.75), rng.uniform(-0.12, 0.02)) for _ in range(30)]
    puffs = [(rng.uniform(0.15, 0.95), rng.uniform(0.35, 0.6), rng.uniform(0.04, 0.07)) for _ in range(5)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        head = 1.08 * min(t / 0.24, 1.0) ** 0.7
        tail = 1.08 * max(0.0, (t - 0.36) / 0.64) ** 1.25
        brk = max(0.0, (t - 0.38) / 0.62)
        img = np.zeros((FR, FR, 4))
        if head - tail >= 0.02:
            s = np.linspace(tail, head, 120)
            pts = path(s)
            x = np.clip(s / 1.08, 0.0, 1.0)
            w = 0.02 + 0.115 * np.sin(np.pi * x ** 0.8) ** 0.6
            w *= np.clip((s - tail) / 0.14, 0.1, 1.0) * np.clip((head - s) / 0.05, 0.3, 1.0)
            w = gobs(s, w, tail, head, brk * 0.85, 34.0)
            k, near, side, nrm, tan = stroke(pts, w)
            img = frame_rgba(shade_iron(side, s[k], t), near < 1.0)
        # puffs of dust rolling off the inner edge, shrinking away
        for sp, t0, r in puffs:
            tt = (t - t0) / 0.5
            if tt < 0.0 or tt > 1.0 or sp > head:
                continue
            p = path(np.array([sp]))[0]
            n = (p - np.array([cx, cy])) / r0
            q = p - n * (0.1 + 0.12 * tt) + np.array([0.0, 0.05 * tt])
            rr = r * (1.0 + 0.6 * tt) * (1.0 - tt) ** 0.6
            d = np.sqrt((U - q[0]) ** 2 + (V - q[1]) ** 2)
            disc = d < rr
            img[disc, :3] = DUST[2]
            img[disc & ((V - q[1]) > rr * 0.3), :3] = DUST[1]
            img[disc & (d > rr - 1.6 * PX) & ((V - q[1]) < 0), :3] = DUST[3]
            img[disc, 3] = 255.0

        def at(sp):
            if sp > head:
                return None, None
            p = path(np.array([sp]))[0]
            return p, -(p - np.array([cx, cy])) / r0
        specks(img, t, clods, at, [DUST[3], DUST[2], DUST[1], DUST[0]], 0.42, np.array([0.0, 0.3]))
        frames.append(img)
    return frames


def gen_ember_slash() -> list:
    """The awakened bite: a crescent of fire swept across, tongues of flame licking off its crest
    and curling back, the head curling in on itself, then breaking from the tail into round gouts
    that char away; embers fly off the crest and ash drifts off the inner edge."""
    rng = np.random.default_rng(9412)
    cx, cy, r0 = 0.0, 0.2, 0.6
    curl_s = 0.22
    path = _arc(cx, cy, r0, 0.9 * np.pi, np.pi, curl_s, 1.4)
    embers = [(rng.uniform(0.1, 1.1), rng.uniform(0.12, 0.6), rng.uniform(0.04, 0.12)) for _ in range(16)]
    ash = [(rng.uniform(0.0, 1.0), rng.uniform(0.4, 0.75), rng.uniform(-0.14, -0.04)) for _ in range(12)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        head = (1.0 + curl_s) * min(t / 0.28, 1.0) ** 0.7
        tail = (1.0 + curl_s) * max(0.0, (t - 0.42) / 0.58) ** 1.3
        brk = max(0.0, (t - 0.42) / 0.58)
        img = np.zeros((FR, FR, 4))
        if head - tail >= 0.02:
            s = np.linspace(tail, head, 120)
            pts = path(s)
            x = np.clip(s / (1.0 + curl_s), 0.0, 1.0)
            w = 0.025 + 0.14 * np.sin(np.pi * x ** 0.8) ** 0.6
            w *= np.clip((s - tail) / 0.12, 0.15, 1.0) * np.clip((head - s) / 0.05, 0.25, 1.0)
            w = gobs(s, w, tail, head, brk)
            k, near, side, nrm, tan = stroke(pts, w)
            rgb = shade_fire(side, s[k], t)
            # the gouts left behind char from the outside in as they go
            charring = (s[k] < tail + (head - tail) * 0.35 * brk) & (brk > 0.3)
            rgb[charring & (side < 0.2)] = FIRE[1]
            rgb[charring & (side < -0.4)] = ASH[1]
            img = frame_rgba(rgb, near < 1.0)
            licks(img, pts, w, nrm, tan, s, 0.13, t * 0.32, 1.0 - 0.45 * brk, t)

        def at_out(sp):
            if sp > head:
                return None, None
            p = path(np.array([min(sp, 1.0)]))[0]
            return p, (p - np.array([cx, cy])) / r0

        def at_in(sp):
            if sp > head or sp < tail:
                return None, None
            p = path(np.array([sp]))[0]
            return p, (p - np.array([cx, cy])) / r0
        specks(img, t, embers, at_out, [FIRE[7], FIRE[6], FIRE[5], FIRE[4], FIRE[3]], 0.45, np.array([0.0, -0.25]))
        specks(img, t, ash, at_in, [ASH[3], ASH[2], ASH[1]], 0.6, np.array([0.04, 0.18]))
        frames.append(img)
    return frames


def gen_ember_cloud() -> list:
    """A gout of fire: lobes billowing out from a white-hot knot, yellow at the heart through orange
    to crimson rims with a charred outline underneath, curls in them, then dying into dark char and
    ash-grey puffs as they part; embers thrown out."""
    rng = np.random.default_rng(9413)
    lob = [(rng.uniform(0, 2 * np.pi), rng.uniform(0.17, 0.3), rng.uniform(0.3, 0.5)) for _ in range(7)]
    sparks = [(rng.uniform(0.0, 6.3), rng.uniform(0.05, 0.35), rng.uniform(0.6, 1.0)) for _ in range(10)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        grow = min(t / 0.3, 1.0) ** 0.6
        gone = min(max(0.0, (t - 0.42) / 0.58), 1.0)
        spin = 0.5 * t
        img = np.zeros((FR, FR, 4))
        for j, (a, rr, dd) in enumerate(lob):
            aa = a + spin
            dist = dd * (0.35 + 0.65 * grow) * (1.0 + 0.45 * gone)
            r = rr * (0.4 + 0.6 * grow) * (1.0 - gone) ** 1.1
            if r < 2.0 * PX:
                continue
            cx, cy = np.cos(aa) * dist, np.sin(aa) * dist * 0.8 - 0.22 * gone
            d = np.sqrt((U - cx) ** 2 + (V - cy) ** 2)
            disc = d < r
            hot = [FIRE[6], FIRE[5], FIRE[4], FIRE[3], FIRE[2], FIRE[0]]
            if gone > 0.35:
                hot = [FIRE[4], FIRE[3], FIRE[2], FIRE[1], ASH[1], ASH[0]]
            if gone > 0.7:
                hot = [ASH[3], ASH[2], ASH[1], ASH[1], ASH[0], ASH[0]]
            col = np.empty((FR, FR, 3))
            col[:] = hot[1]
            col[(V - cy) < -r * 0.25] = hot[0]
            col[(V - cy) > r * 0.25] = hot[2]
            col[(V - cy) > r * 0.6] = hot[3]
            col[d > r - 2.2 * PX] = hot[3]
            col[(d > r - 2.2 * PX) & ((V - cy) > r * 0.4)] = hot[5]
            img[disc, :3] = col[disc]
            img[disc, 3] = 255.0
            if r > 6.0 * PX:
                curl(img, cx, cy, r / PX * 0.55, aa + t * 2.0, 1.1 if j % 2 else -1.1, hot[0], 1)
        # tongues of flame leaping off the top while it burns
        lick_k = grow * max(0.0, 1.0 - gone * 1.6)
        if lick_k > 0.1:
            for j, (ox, hh, lean) in enumerate(((-0.2, 0.42, -0.5), (0.04, 0.55, 0.35), (0.25, 0.36, 0.6))):
                h = hh * lick_k * (1.0 + 0.15 * np.sin(t * 14.0 + j * 2.0))
                tongue(img, np.array([ox, -0.12 * grow]), np.array([0.0, -1.0]), np.array([1.0, 0.0]) * np.sign(lean),
                       h, 0.1 * lick_k, abs(lean), t)
        if t < 0.45:
            knot = RAD < 0.17 * grow * (1.0 - t)
            img[knot, :3] = FIRE[7]
            img[knot, 3] = 255.0
        for a0, t0, sp in sparks:
            tt = (t - t0) / 0.5
            if 0.0 <= tt <= 1.0:
                p = np.array([np.cos(a0), np.sin(a0) * 0.7]) * (0.3 + 0.6 * tt * sp) + np.array([0.0, -0.2 * tt])
                put(img, p[0], p[1], [FIRE[7], FIRE[6], FIRE[5], FIRE[3]][min(int(tt * 4), 3)], 2 if tt < 0.5 else 1)
        frames.append(img)
    return frames


def gen_cinder() -> list:
    """An ember flaring and cooling over its life (64 px): a white-hot four-pointed spark that
    shrinks through yellow and orange to a dull red speck."""
    fr = 64
    yy, xx = np.mgrid[0:fr, 0:fr]
    u = (xx + 0.5 - fr / 2) / (fr / 2)
    v = (yy + 0.5 - fr / 2) / (fr / 2)
    frames = []
    for i in range(N):
        t = i / (N - 1)
        img = np.zeros((fr, fr, 4))
        size = 0.55 * (1.0 - 0.75 * t) * (1.0 + 0.15 * np.sin(i * 2.7))
        star = (np.abs(u) * np.abs(v) < 0.006 * (1.0 - t) + 0.001) & (np.abs(u) + np.abs(v) < size)
        core = np.abs(u) + np.abs(v) < size * 0.45
        pal = [FIRE[7], FIRE[6], FIRE[5], FIRE[4], FIRE[3], FIRE[2], FIRE[1]]
        c0 = pal[min(int(t * 6.0), 6)]
        c1 = pal[min(int(t * 6.0) + 1, 6)]
        img[star | core, :3] = c1
        img[core, :3] = c0
        img[star | core, 3] = 255.0
        frames.append(img)
    return frames


def gen_ash() -> list:
    """A flake of ash tumbling as it drifts (64 px, a loop): a ragged grey flake, foreshortened as it
    turns, its back darker, one edge still glowing."""
    fr = 64
    yy, xx = np.mgrid[0:fr, 0:fr]
    rng = np.random.default_rng(9415)
    rag = rng.uniform(0.75, 1.0, 9)
    frames = []
    for i in range(N):
        t = i / N
        img = np.zeros((fr, fr, 4))
        ang = 0.4 + np.pi * t
        flip = np.cos(2 * np.pi * t)
        ca, sa = np.cos(ang), np.sin(ang)
        lx = ((xx - fr / 2) * ca + (yy - fr / 2) * sa) / 22.0
        ly = (-(xx - fr / 2) * sa + (yy - fr / 2) * ca) / max(abs(flip) * 16.0, 3.0)
        a = np.arctan2(ly, lx)
        edge = np.interp((a + np.pi) / (2 * np.pi) * 9, np.arange(10), np.append(rag, rag[0]))
        r = np.sqrt(lx ** 2 + ly ** 2)
        m = r < edge
        pal = ASH if flip >= 0 else [ASH[0], ASH[0], ASH[1], ASH[2]]
        col = np.empty((fr, fr, 3))
        col[:] = pal[2]
        col[ly > 0.3] = pal[1]
        col[r > edge - 0.18] = pal[1]
        col[(r > edge - 0.2) & (lx > 0.45)] = FIRE[3] if flip >= 0 else FIRE[2]
        img[m, :3] = col[m]
        img[m, 3] = 255.0
        frames.append(img)
    return frames


def gen_axe_trail() -> Image.Image:
    """The plain axe's strip, tiling along its length, 8 looping frames: a white edge with heavy gust
    hooks curling off it, speed lines along a broad iron body, a dark band inside, and the inner edge
    shedding clods of dust and grit."""
    out = np.zeros((TRAIL_H * TRAIL_FRAMES, TRAIL_W, 4))
    yy, xx = np.mgrid[0:TRAIL_H, 0:TRAIL_W]
    fx = xx / TRAIL_W
    rng = np.random.default_rng(9421)
    clods = [(rng.uniform(0, TRAIL_W), rng.uniform(0, 1), rng.integers(1, 4)) for _ in range(26)]
    puffs = [(c * 64 + rng.uniform(0, 30), rng.uniform(0, 1), rng.uniform(3.5, 5.5)) for c in range(4)]
    for f in range(TRAIL_FRAMES):
        p = f / TRAIL_FRAMES
        ph = 2 * np.pi * p

        def top_at(x):
            q = x / TRAIL_W
            return 16.0 + 2.0 * np.sin(2 * np.pi * q * 2 + ph) + 1.2 * np.sin(2 * np.pi * q * 5 - ph * 2)

        def bot_at(x):
            q = x / TRAIL_W
            return 47.0 + 3.0 * np.sin(2 * np.pi * q * 3 - ph) + 2.0 * np.sin(2 * np.pi * q * 8 + ph * 2)

        top = top_at(xx)
        bot = bot_at(xx)
        body = (yy >= top) & (yy <= bot)
        depth = (yy - top) / np.maximum(bot - top, 1.0)
        img = np.zeros((TRAIL_H, TRAIL_W, 4))
        rgb = np.empty((TRAIL_H, TRAIL_W, 3))
        rgb[:] = IRON[3]
        rgb[depth > 0.45 + 0.08 * np.sin(2 * np.pi * fx * 4 - ph * 2)] = IRON[2]
        rgb[depth > 0.75 + 0.05 * np.sin(2 * np.pi * fx * 6 + ph)] = IRON[1]
        rgb[depth < 0.24] = IRON[4]
        for j, (fr_, kq, m, dq) in enumerate(((0.3, 3, 1, 6), (0.5, 2, -1, 5), (0.66, 4, 2, 7))):
            yl = top + (bot - top) * fr_ + 1.2 * np.sin(2 * np.pi * fx * kq - ph * m + j)
            dash = np.sin(2 * np.pi * fx * dq - ph * 2 + j * 1.3) > -0.1
            rgb[(np.abs(yy - yl) < 0.7) & dash] = IRON[5] if fr_ < 0.45 else IRON[3]
        rgb[yy < top + 3.5] = IRON[5]
        rgb[yy < top + 1.6] = IRON[6]
        rgb[yy > bot - 1.8] = IRON[0]
        img[..., :3] = rgb
        img[..., 3] = body * 255.0
        for c in range(4):
            x0 = c * 64 + 11 * np.sin(c * 2.1) + p * 64
            y0 = top_at(x0 % TRAIL_W)
            r = 5.5 if c % 2 == 0 else 4.0
            _trail_spiral(img, x0 + r, y0 - r + 1, r, np.pi * 0.5, -1.2, IRON[6], 2)
        # dust puffs rolling off the inner edge, and clods and grit falling from it
        for x0, off, r0 in puffs:
            q = (p + off) % 1.0
            x = (x0 + q * 40) % TRAIL_W
            yb = bot_at(x) + 1.0 + 7.0 * q
            r = r0 * (1.0 + 0.5 * q) * (1.0 - q) ** 0.5
            for wrap in (-TRAIL_W, 0, TRAIL_W):
                d = np.sqrt((xx - x - wrap) ** 2 + (yy - yb) ** 2)
                disc = d < r
                img[disc, :3] = DUST[2]
                img[disc & (yy > yb + r * 0.3), :3] = DUST[1]
                img[disc & (d > r - 1.3) & (yy < yb), :3] = DUST[3]
                img[disc, 3] = 255.0
        for gx, off, sz in clods:
            q = (p + off) % 1.0
            x = gx + q * 30
            yb = bot_at(x % TRAIL_W)
            _trail_put(img, x, yb + 2.0 + 13.0 * q * q, DUST[3 if q < 0.3 else (2 if q < 0.6 else 1)], int(sz) if q < 0.6 else 1)
        out[f * TRAIL_H:(f + 1) * TRAIL_H] = img
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def gen_ember_trail() -> Image.Image:
    """The awakened strip, tiling along its length, 8 looping frames: a row of flame tongues licking
    up off the top and curling back (amber with yellow cores, red-orange outlines), a molten body
    from yellow through orange to crimson with yellow flow lines racing along, a ragged charred
    edge underneath, embers rising off the tongues and flakes of ash drifting down off the char."""
    out = np.zeros((TRAIL_H * TRAIL_FRAMES, TRAIL_W, 4))
    yy, xx = np.mgrid[0:TRAIL_H, 0:TRAIL_W]
    fx = xx / TRAIL_W
    rng = np.random.default_rng(9422)
    tongues = [(c * 32 + rng.uniform(-5, 5), rng.uniform(17.0, 24.0), rng.uniform(10.0, 13.0)) for c in range(8)]
    embers = [(rng.uniform(0, TRAIL_W), rng.uniform(0, 1), rng.integers(1, 3)) for _ in range(16)]
    ash = [(rng.uniform(0, TRAIL_W), rng.uniform(0, 1)) for _ in range(12)]
    base = 26.0
    for f in range(TRAIL_FRAMES):
        p = f / TRAIL_FRAMES
        ph = 2 * np.pi * p
        img = np.zeros((TRAIL_H, TRAIL_W, 4))
        bot = 51.0 + 2.5 * np.sin(2 * np.pi * fx * 4 - ph) + 1.6 * np.sin(2 * np.pi * fx * 11 + ph)
        top = base + 1.5 * np.sin(2 * np.pi * fx * 3 + ph)
        body = (yy >= top) & (yy <= bot)
        depth = (yy - base) / np.maximum(bot - base, 1.0)
        rgb = np.empty((TRAIL_H, TRAIL_W, 3))
        rgb[:] = FIRE[4]
        rgb[depth < 0.22] = FIRE[5]
        rgb[depth > 0.42 + 0.08 * np.sin(2 * np.pi * fx * 5 - ph * 2)] = FIRE[3]
        rgb[depth > 0.66 + 0.06 * np.sin(2 * np.pi * fx * 7 + ph)] = FIRE[2]
        rgb[depth > 0.84 + 0.05 * np.sin(2 * np.pi * fx * 13 - ph)] = FIRE[1]
        for j, (fr_, kq, m, dq) in enumerate(((0.12, 3, 1, 5), (0.36, 2, -1, 4), (0.56, 4, 2, 6))):
            yl = base + (bot - base) * fr_ + 1.4 * np.sin(2 * np.pi * fx * kq - ph * m + j)
            dash = np.sin(2 * np.pi * fx * dq - ph * 2 + j * 1.3) > -0.25
            rgb[(np.abs(yy - yl) < 0.75) & dash] = FIRE[6] if fr_ < 0.3 else FIRE[5]
        rgb[yy > bot - 1.8] = FIRE[0]
        img[..., :3] = rgb
        img[..., 3] = body * 255.0
        # tongues of flame licking up off the top, leaning back (toward -x: behind the motion)
        for j, (x0, h0, w0) in enumerate(tongues):
            cxl = (x0 + p * 32) % TRAIL_W
            h = h0 * (1.0 + 0.18 * np.sin(ph * 2 + j * 1.9))
            for wrap in (-TRAIL_W, 0, TRAIL_W):
                fy = np.clip((base + 4.0 - yy) / h, 0.0, 1.0)
                cx = cxl + wrap - 16.0 * fy ** 1.5 * (h / 20.0)
                hw = w0 * (1.0 - fy) ** 0.75 * (1.0 + 0.2 * np.sin(fy * 6.0 + ph * 2 + j))
                dx = xx - cx
                inside = (yy <= base + 4.0) & (yy >= base + 4.0 - h) & (np.abs(dx) < hw)
                img[inside, :3] = FIRE[5]
                img[inside & (dx < hw * 0.3) & (dx > -hw * 0.55), :3] = FIRE[6]
                img[inside & (np.abs(dx + hw * 0.1) < hw * 0.18) & (fy < 0.45), :3] = FIRE[7]
                img[inside & (dx > hw - 1.4), :3] = FIRE[3]
                img[inside, 3] = 255.0
        # embers rising off the tongues, ash drifting down off the char
        for ex, off, sz in embers:
            q = (p + off) % 1.0
            x = ex + q * 26
            y = base - 8.0 - 18.0 * q
            _trail_put(img, x, y, [FIRE[7], FIRE[6], FIRE[5], FIRE[3]][min(int(q * 4), 3)], int(sz) if q < 0.5 else 1)
        for ax, off in ash:
            q = (p + off) % 1.0
            x = ax + q * 20 + 2.0 * np.sin(q * 9.0)
            yb = 51.0 + 2.5 * np.sin(2 * np.pi * (x % TRAIL_W) / TRAIL_W * 4 - ph)
            _trail_put(img, x, yb + 2.0 + 9.0 * q, ASH[3 if q < 0.4 else 2], 2 if q < 0.5 else 1)
        out[f * TRAIL_H:(f + 1) * TRAIL_H] = img
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


SHEETS = {
    "axe_slash": gen_axe_slash,
    "ember_slash": gen_ember_slash,
    "ember_cloud": gen_ember_cloud,
    "cinder": gen_cinder,
    "ash": gen_ash,
}
TRAILS = {
    "axe_trail": gen_axe_trail,
    "ember_trail": gen_ember_trail,
}


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
    canvas = Image.new("RGBA", (w, h), (110, 140, 100, 255))
    x = 0
    for im in imgs:
        canvas.alpha_composite(im, (x, 0))
        x += im.width + 8
    canvas.save(os.path.join(PREVIEW, "axe.png"))
    print("  preview tools/dev/out/flipbook/axe.png")


if __name__ == "__main__":
    main()
