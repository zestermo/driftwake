#!/usr/bin/env python3
"""
The cutlass's water (Kraken's Wake, the awakened blade), drawn the way ukiyo-e prints draw
water: smooth flowing bodies of blue, thin light lines running along them like brush
strokes, foam claws curling over off the outer edge, little spiral eddies, bubbles, and
the water breaking into round gobs rather than tearing.

Usage (from the project root):
    py tools/texture_gen/gen_water_fx.py [name ...]    (no names: all of them)

Output (assets/textures/fx/):
    flip_water_slash.png, flip_water_swirl.png, flip_water_curl.png: 16 frames of 128 px in a
        4x4 grid, played once over a particle's life by FX.flipbook
    water_trail.png: 8 frames of 256x64 stacked, tiling along their length: the strip
        WaterRibbon and BladeWater flow along
and a preview at tools/dev/out/flipbook/water.png. Deterministic (a seed per sheet).
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

# navy, deep, mid, bright, light, pale, foam
TIDE = ["0e2f6b", "1a4f9e", "2671c6", "3f95e2", "79c3f3", "c2e9ff", "ffffff"]


def hexc(s: str) -> np.ndarray:
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


PAL = [hexc(c) for c in TIDE]


def stroke(pts: np.ndarray, widths: np.ndarray) -> tuple:
    """A thick line along pts (n x 2, frame coords) that is a union of discs of the given
    widths: per pixel the nearest sample's index, its distance in widths, the offset across
    the line in widths (+: left of travel, the outside of a clockwise curve); and per sample
    the left normal."""
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


def shade(side: np.ndarray, s: np.ndarray, t: float, flow: float = 1.0) -> np.ndarray:
    """Water across a stroke, outside (+1) to inside (-1): foam, pale, bright with light
    lines running along it in dashes, mid, deep, a navy inner line."""
    rgb = np.empty((FR, FR, 3))
    rgb[:] = PAL[2]
    rgb[side < -0.34 + 0.1 * np.sin(s * 7.0 - t * 5.0 * flow)] = PAL[1]
    rgb[side > 0.2 + 0.08 * np.sin(s * 11.0 + t * 6.0)] = PAL[3]
    for off, fq, ph in ((-0.6, 9.0, 0.0), (-0.14, 13.0, 1.7), (0.36, 7.0, 3.1)):
        ln = np.abs(side - off - 0.06 * np.sin(s * fq * 0.7 - t * 8.0 * flow + ph)) < 0.075
        dash = np.sin(s * fq - t * 14.0 * flow + ph) > -0.25
        rgb[ln & dash] = PAL[4] if off > -0.4 else PAL[3]
    rgb[side > 0.6] = PAL[5]
    rgb[side > 0.74 + 0.06 * np.sin(s * 19.0 - t * 16.0 * flow)] = PAL[6]
    rgb[side < -0.84] = PAL[0]
    return rgb


def frame(rgb: np.ndarray, mask: np.ndarray) -> np.ndarray:
    rgba = np.zeros((FR, FR, 4))
    rgba[..., :3] = rgb
    rgba[..., 3] = mask.astype(float) * 255.0
    return rgba


def put(img: np.ndarray, x: float, y: float, col: np.ndarray, size: int = 1) -> None:
    px = int((x + 1) * FR / 2)
    py = int((y + 1) * FR / 2)
    if px < 0 or py < 0 or px + size > FR or py + size > FR:
        return
    img[py:py + size, px:px + size, :3] = col
    img[py:py + size, px:px + size, 3] = 255.0


def bubble(img: np.ndarray, x: float, y: float, r_px: float, col: np.ndarray) -> None:
    """A hollow bubble (a dot when it's small)."""
    if r_px < 1.3:
        put(img, x, y, col, 2 if r_px > 0.8 else 1)
        return
    for a in np.linspace(0, 2 * np.pi, int(r_px * 8), endpoint=False):
        put(img, x + np.cos(a) * r_px * PX, y + np.sin(a) * r_px * PX, col)


def curl(img: np.ndarray, x: float, y: float, r_px: float, a0: float, turn: float, col: np.ndarray, thick: int = 2) -> None:
    """A little spiral winding in from angle a0 (a foam claw, an eddy)."""
    n = int(r_px * abs(turn) * 10) + 10
    for i in range(n):
        f = i / (n - 1)
        a = a0 + turn * 2 * np.pi * f
        r = r_px * (1.0 - 0.8 * f)
        put(img, x + np.cos(a) * r * PX, y + np.sin(a) * r * PX, col, thick if f < 0.45 else 1)


def claws(img: np.ndarray, pts: np.ndarray, w: np.ndarray, nrm: np.ndarray, tan: np.ndarray, s: np.ndarray,
          spacing: float, phase: float, size: float = 1.0, inner: bool = True) -> None:
    """Foam claws curling over off the outer edge every `spacing` along it (riding along with
    `phase`), and smaller eddies just inside the inner edge between them."""
    if len(s) < 3:
        return
    first = np.floor((s[0] - phase) / spacing) * spacing + phase
    c = first
    while c <= s[-1]:
        j = int(np.argmin(np.abs(s - c)))
        if w[j] > 3.0 * PX and 1 <= j < len(s) - 2:
            r = (2.0 + 0.32 * w[j] / PX) * size
            n = nrm[j]
            bx, by = pts[j] + n * w[j] * 0.8
            cx, cy = bx + n[0] * r * PX, by + n[1] * r * PX
            a0 = np.arctan2(-n[1], -n[0])
            # wind toward the way the water runs, so it curls over forward
            turn = 1.2 if (-np.sin(a0) * tan[j, 0] + np.cos(a0) * tan[j, 1]) > 0 else -1.2
            curl(img, cx, cy, r, a0, turn, PAL[6], 2)
            if inner and w[j] > 6.0 * PX:
                ex, ey = pts[j] - n * w[j] * 0.45
                curl(img, ex + tan[j, 0] * w[j] * 0.9, ey + tan[j, 1] * w[j] * 0.9, r * 0.6, a0 + np.pi, -turn, PAL[4], 1)
        c += spacing


def gobs(s: np.ndarray, w: np.ndarray, tail: float, head: float, brk: float, freq: float = 34.0) -> np.ndarray:
    """The trailing part pinched into round gobs that shrink away (widths to ~0 between)."""
    if brk <= 0.0:
        return w
    trailing = np.clip(1.0 - (s - tail) / max((head - tail) * (0.3 + 0.6 * brk), 1e-3), 0.0, 1.0)
    g = 0.5 + 0.5 * np.sin(s * freq)
    keep = np.clip((g - brk * 0.95 * np.minimum(trailing * 2.0, 1.0)) / 0.3, 0.0, 1.0)
    return w * np.where(trailing > 0.0, np.maximum(keep, 1e-3), 1.0) * (1.0 - 0.3 * brk)


def bubbles_along(img: np.ndarray, pts: np.ndarray, w: np.ndarray, nrm: np.ndarray, s: np.ndarray,
                  specs: list, t: float) -> None:
    """Bubbles rising off the outside edge and drifting out (specs: s, start t, life, px out, radius)."""
    for sp, t0, life, out, r in specs:
        tt = (t - t0) / life
        if tt < 0.0 or tt > 1.0 or sp < s[0] or sp > s[-1]:
            continue
        j = int(np.argmin(np.abs(s - sp)))
        p = pts[j] + nrm[j] * (w[j] * 0.9 + (out + 10.0 * tt) * PX)
        bubble(img, p[0], p[1] - 4.0 * tt * PX, r * (1.0 - 0.5 * tt), PAL[6] if tt < 0.6 else PAL[5])


def gen_water_slash() -> list:
    """A crescent of water cut through the air: the head sweeps over the top and curls in on
    itself, foam claws riding along the outside, then it pinches into gobs from the tail
    that burst into bubbles and droplets."""
    rng = np.random.default_rng(7321)
    cx, cy, r0 = 0.0, 0.18, 0.64
    curl_s = 0.24
    specs = [(rng.uniform(0.05, 1.1), rng.uniform(0.15, 0.7), rng.uniform(0.25, 0.4), rng.uniform(0, 5), rng.uniform(1.0, 2.8))
             for _ in range(34)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        head = (1.0 + curl_s) * min(t / 0.3, 1.0) ** 0.7
        tail = (1.0 + curl_s) * max(0.0, (t - 0.42) / 0.58) ** 1.3
        brk = max(0.0, (t - 0.42) / 0.58)
        if head - tail < 0.02:
            frames.append(np.zeros((FR, FR, 4)))
            continue
        s = np.linspace(tail, head, 120)
        ang = 0.9 * np.pi + np.minimum(s, 1.0) * np.pi + np.maximum(s - 1.0, 0.0) * 1.3 * np.pi
        rad = r0 * (1.0 - 0.62 * (np.maximum(s - 1.0, 0.0) / curl_s) ** 1.5)
        pts = np.stack([cx + np.cos(ang) * rad, cy + np.sin(ang) * rad], -1)
        x = np.clip(s / (1.0 + curl_s), 0.0, 1.0)
        w = 0.02 + 0.14 * np.sin(np.pi * x ** 0.8) ** 0.6
        w *= np.clip((s - tail) / 0.12, 0.15, 1.0) * np.clip((head - s) / 0.05, 0.25, 1.0)
        w = gobs(s, w, tail, head, brk)
        k, near, side, nrm, tan = stroke(pts, w)
        img = frame(shade(side, s[k], t), near < 1.0)
        claws(img, pts, w, nrm, tan, s, 0.13, t * 0.25, 1.45)
        bubbles_along(img, pts, w, nrm, s, specs, t)
        frames.append(img)
    return frames


def gen_water_swirl() -> list:
    """A whirl of water: two arms spiralling out from a dark eye, spinning fast then slowing,
    foam claws on the outside of every coil and eddies inside, then flung apart into gobs
    and bubbles."""
    rng = np.random.default_rng(7322)
    specs = [(rng.uniform(0.3, 1.0), rng.uniform(0.3, 0.8), rng.uniform(0.25, 0.4), rng.uniform(0, 4), rng.uniform(1.0, 2.6))
             for _ in range(16)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        grow = min(t / 0.35, 1.0) ** 0.6
        gone = max(0.0, (t - 0.5) / 0.5)
        spin = 2.6 * np.pi * (1.0 - (1.0 - t) ** 2)
        r_out = 0.3 + 0.52 * grow + 0.1 * gone
        img = np.zeros((FR, FR, 4))
        for arm in range(2):
            s = np.linspace(0.0, 1.0, 120)
            ang = arm * np.pi + spin + s * 2.2 * np.pi
            rad = 0.07 + (r_out - 0.07) * s
            pts = np.stack([np.cos(ang) * rad, np.sin(ang) * rad], -1)
            w = (0.025 + 0.12 * s ** 0.9) * np.clip((1.0 - s) / 0.08, 0.2, 1.0)
            w = gobs(s[::-1], w[::-1], 0.0, 1.0, gone, 30.0)[::-1]
            k, near, side, nrm, tan = stroke(pts, w)
            m = near < 1.0
            rgb = shade(side, s[k] * 2.0, t, 1.6)
            img[m, :3] = rgb[m]
            img[m, 3] = 255.0
            claws(img, pts, w, nrm, tan, s, 0.22, t * 0.3 + arm * 0.11, 0.9)
            bubbles_along(img, pts, w, nrm, s, specs[arm::2], t)
        if t < 0.55:
            eye = (RAD < 0.1 + 0.05 * grow) & (RAD > 0.05)
            img[eye, :3] = PAL[0]
            img[eye, 3] = 255.0
        frames.append(img)
    return frames


def gen_water_curl() -> list:
    """The tip of a wave curling over (the ends of the water's ribbons): a tongue of water
    rising from the bottom of the frame and rolling over into a curl, claws of foam along
    its back, hanging, then pinching into gobs and bubbles as it falls."""
    rng = np.random.default_rng(7323)
    specs = [(rng.uniform(0.3, 1.8), rng.uniform(0.3, 0.8), rng.uniform(0.25, 0.4), rng.uniform(0, 5), rng.uniform(1.0, 2.6))
             for _ in range(16)]
    ln = 1.9
    frames = []
    for i in range(N):
        t = i / (N - 1)
        grow = min(t / 0.4, 1.0) ** 0.65
        bend = 0.4 + 0.6 * grow
        brk = max(0.0, (t - 0.55) / 0.45)
        sink = 0.35 * brk ** 1.5
        s = np.linspace(0.0, ln * (0.25 + 0.75 * grow), 130)
        theta = -np.pi / 2 + 1.6 * bend * s ** 2
        ds = s[1] - s[0]
        pts = np.stack([-0.4 + np.cumsum(np.cos(theta)) * ds, 1.0 + sink + np.cumsum(np.sin(theta)) * ds], -1)
        x = s / ln
        w = (0.035 + 0.24 * (1.0 - x) ** 1.3) * np.clip((s[-1] - s) / 0.08, 0.25, 1.0)
        # it breaks from the tip back
        w = gobs(s[::-1], w[::-1], 0.0, s[-1], brk, 26.0)[::-1]
        k, near, side, nrm, tan = stroke(pts, w)
        img = frame(shade(side, s[k] * 1.4, t, 1.3), (near < 1.0) & (V < 0.97))
        claws(img, pts, w, nrm, tan, s, 0.3, t * 0.2)
        bubbles_along(img, pts, w, nrm, s, specs, t)
        frames.append(img)
    return frames


TRAIL_W = 256
TRAIL_H = 64
TRAIL_FRAMES = 8


def gen_water_trail() -> Image.Image:
    """The water on the ribbons: a strip tiling along its length, 8 frames that loop (all the
    movement advances a whole spacing over the loop). Top = the outside: a foam crest with
    claws curling over it and bubbles rising off it; light lines running along the body;
    deep blue below, small eddies along the inner edge."""
    out = np.zeros((TRAIL_H * TRAIL_FRAMES, TRAIL_W, 4))
    yy, xx = np.mgrid[0:TRAIL_H, 0:TRAIL_W]
    fx = xx / TRAIL_W
    rng = np.random.default_rng(7324)
    bub = [(rng.uniform(0, TRAIL_W), rng.uniform(0, 1), rng.uniform(1.0, 2.6)) for _ in range(14)]

    def put_px(img, x, y, col, size=1):
        x = int(x) % TRAIL_W
        y = int(y)
        if 0 <= y and y + size <= TRAIL_H:
            for dx in range(size):
                img[y:y + size, (x + dx) % TRAIL_W, :3] = col
                img[y:y + size, (x + dx) % TRAIL_W, 3] = 255.0

    def spiral_px(img, x, y, r, a0, turn, col, thick):
        n = int(r * abs(turn) * 10) + 10
        for i in range(n):
            f = i / (n - 1)
            a = a0 + turn * 2 * np.pi * f
            rr = r * (1.0 - 0.8 * f)
            put_px(img, x + np.cos(a) * rr, y + np.sin(a) * rr, col, thick if f < 0.45 else 1)

    for f in range(TRAIL_FRAMES):
        p = f / TRAIL_FRAMES
        ph = 2 * np.pi * p

        def top_at(x):
            q = x / TRAIL_W
            return 17.0 + 3.0 * np.sin(2 * np.pi * q * 2 + ph) + 1.5 * np.sin(2 * np.pi * q * 5 - ph * 2)

        top = top_at(xx)
        bot = 52.0 + 2.5 * np.sin(2 * np.pi * fx * 3 - ph) + 1.5 * np.sin(2 * np.pi * fx * 7 + ph)
        body = (yy >= top) & (yy <= bot)
        depth = (yy - top) / np.maximum(bot - top, 1.0)
        img = np.zeros((TRAIL_H, TRAIL_W, 4))
        rgb = np.empty((TRAIL_H, TRAIL_W, 3))
        rgb[:] = PAL[2]
        rgb[depth > 0.62 + 0.08 * np.sin(2 * np.pi * fx * 4 - ph * 2)] = PAL[1]
        rgb[depth < 0.3 + 0.06 * np.sin(2 * np.pi * fx * 6 + ph)] = PAL[3]
        for j, (fr, kq, m, dq) in enumerate(((0.3, 3, 1, 5), (0.46, 2, -1, 4), (0.62, 4, 2, 6), (0.8, 3, 1, 7))):
            yl = top + (bot - top) * fr + 1.8 * np.sin(2 * np.pi * fx * kq - ph * m + j)
            dash = np.sin(2 * np.pi * fx * dq - ph * 2 + j * 1.3) > -0.3
            rgb[(np.abs(yy - yl) < 0.75) & dash] = PAL[4] if fr < 0.55 else PAL[3]
        rgb[yy < top + 4.5 + 1.2 * np.sin(2 * np.pi * fx * 6 + ph)] = PAL[5]
        rgb[yy < top + 2.2] = PAL[6]
        rgb[yy > bot - 1.5] = PAL[0]
        img[..., :3] = rgb
        img[..., 3] = body * 255.0
        # claws of foam curling over the crest, riding forward a spacing per loop
        for c in range(8):
            x0 = c * 32 + 6 * np.sin(c * 2.1) + p * 32
            y0 = top_at(x0 % TRAIL_W)
            r = 5.5 if c % 2 == 0 else 3.5
            spiral_px(img, x0 + r, y0 - r + 1, r, np.pi * 0.5, -1.25, PAL[6], 2)
        # eddies just inside the inner edge
        for c in range(4):
            x0 = c * 64 + 20 + p * 64
            spiral_px(img, x0, 44.0 + 2.0 * np.sin(c * 1.9), 3.5, 0.0, 1.4, PAL[4], 1)
        # bubbles rising off the crest
        for bx, off, r in bub:
            q = (p + off) % 1.0
            x = bx + q * 24
            y = top_at(x % TRAIL_W) - 2.0 - 12.0 * q
            rr = r * (1.0 - 0.4 * q)
            if rr < 1.3:
                put_px(img, x, y, PAL[6], 1)
            else:
                for a in np.linspace(0, 2 * np.pi, int(rr * 8), endpoint=False):
                    put_px(img, x + np.cos(a) * rr, y + np.sin(a) * rr, PAL[6 if q < 0.6 else 5])
        out[f * TRAIL_H:(f + 1) * TRAIL_H] = img
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


SHEETS = {
    "water_slash": gen_water_slash,
    "water_swirl": gen_water_swirl,
    "water_curl": gen_water_curl,
}


def sheet(frames: list) -> Image.Image:
    out = np.zeros((COLS * FR, COLS * FR, 4))
    for i, f in enumerate(frames):
        r, c = divmod(i, COLS)
        out[r * FR:(r + 1) * FR, c * FR:(c + 1) * FR] = f
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    names = sys.argv[1:] or list(SHEETS) + ["water_trail"]
    for n in names:
        if n not in SHEETS and n != "water_trail":
            raise SystemExit("no sheet '%s' (have: %s, water_trail)" % (n, ", ".join(SHEETS)))
    os.makedirs(OUT, exist_ok=True)
    for name, gen in SHEETS.items():
        if name in names:
            img = sheet(gen())
            img.save(os.path.join(OUT, "flip_%s.png" % name))
            print("  wrote assets/textures/fx/flip_%s.png %s" % (name, img.size))
    if "water_trail" in names:
        img = gen_water_trail()
        img.save(os.path.join(OUT, "water_trail.png"))
        print("  wrote assets/textures/fx/water_trail.png %s" % (img.size,))
    os.makedirs(PREVIEW, exist_ok=True)
    imgs = [Image.open(os.path.join(OUT, "flip_%s.png" % n)).convert("RGBA") for n in SHEETS]
    trail = Image.open(os.path.join(OUT, "water_trail.png")).convert("RGBA")
    w = sum(im.width for im in imgs) + trail.width + 8 * len(imgs)
    canvas = Image.new("RGBA", (w, COLS * FR), (205, 175, 120, 255))
    x = 0
    for im in imgs + [trail]:
        canvas.alpha_composite(im, (x, 0))
        x += im.width + 8
    canvas.save(os.path.join(PREVIEW, "water.png"))
    print("  preview tools/dev/out/flipbook/water.png")


if __name__ == "__main__":
    main()
