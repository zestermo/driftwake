#!/usr/bin/env python3
"""
Style samples for 1.19's effects pass (not used by the game yet): four directions for replacing the plain
circles and rings, each drawn on the same five subjects, so Zach can pick one before anything is wired.

    dither     chunky pixel sprites, Bayer-dithered fills, a 1 px dark hand-drawn outline that boils
    chart      sea-chart ink: a rope ring with knots, a compass rose, contour lines and shoreline hatching
    woodcut    a two-colour stamp: key black plus one spot colour, carved gouge lines and sawtooth edges
    painterly  brush dabs (bristled, oriented along the stroke) quantised to a small palette per effect

Subjects (8 frames of 64 px each, the game's flipbook size at PSX resolution): an enemy's ground telegraph
charging up, a rain puddle loop, a blood puddle loop, a poison puddle loop, a hit burst.

Usage (from the project root):
    py tools/texture_gen/gen_fx_style_samples.py

Output (tools/dev/out/fx_styles/): compare.gif (every style and subject animated on dirt, side by side),
compare.png (its first and fifth frames), sheet_<style>.png (all eight frames of each subject).
Deterministic.
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "tools", "dev", "out", "fx_styles")
GROUND = os.path.join(ROOT, "assets", "textures", "psx", "dirt.png")

S = 64
FRAMES = 8
_yy, _xx = np.mgrid[0:S, 0:S].astype(np.float64) + 0.5
DX = _xx - S / 2
DY = _yy - S / 2
R = np.hypot(DX, DY)
A = np.arctan2(DY, DX)
# angle measured clockwise from straight up, 0..2pi (for sweeps)
UP_ANG = np.mod(np.arctan2(DX, -DY), 2 * np.pi)
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0
DITH = np.tile(BAYER, (S // 4, S // 4))


def hexc(h: str, a: int = 255) -> np.ndarray:
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a], dtype=np.uint8)


def blank() -> np.ndarray:
    return np.zeros((S, S, 4), dtype=np.uint8)


def wob(a: np.ndarray, seed: int, amp: float = 1.0, lo: int = 2, hi: int = 7) -> np.ndarray:
    """A smooth closed wobble round the circle: a few harmonics with seeded phases."""
    rng = np.random.default_rng(seed)
    out = np.zeros_like(a)
    for k in range(lo, hi):
        out += np.sin(k * a + rng.uniform(0, 2 * np.pi)) / k
    return out * amp


def outline(mask: np.ndarray) -> np.ndarray:
    grown = mask.copy()
    for ax, sh in ((0, 1), (0, -1), (1, 1), (1, -1)):
        grown |= np.roll(mask, sh, axis=ax)
    return grown & ~mask


def hash01(seed: int) -> np.ndarray:
    return np.random.default_rng(seed).random((S, S))


def ease_out(t: float) -> float:
    return 1 - (1 - t) ** 2


PUDDLE_KINDS = ("rain", "blood", "poison")


# ------------------------------------------------------------------------------------------------ dither

A_PUD = {"rain": ("121a20", "22303a", "3e5666", "8fb3c4", "e6f4fa"),
         "blood": ("1a0204", "3a0408", "6e0a10", "b0242a", "ff9a8a"),
         "poison": ("0d2008", "1d4a14", "3f8a22", "93dc52", "f0ffc0")}


def a_telegraph(f: int) -> np.ndarray:
    t = f / (FRAMES - 1)
    img = blank()
    rr = 27 + wob(A, 100 + f // 2, 0.9)          # boils every two frames, like a redrawn cel
    inside = R < rr - 1.5
    img[inside & (DITH < 0.22)] = hexc("6a1410")
    pr = t * (rr - 1.5)
    img[inside & (R < pr) & (DITH < 0.55)] = hexc("d8402a")
    img[inside & (np.abs(R - pr) < 1.0)] = hexc("ffb040")
    img[np.abs(R - rr) < 1.6] = hexc("ff8a2a")
    for k in range(4):                           # chevrons closing in
        ang = k * np.pi / 2 + np.pi / 4
        u = DX * np.cos(ang) + DY * np.sin(ang)
        v = -DX * np.sin(ang) + DY * np.cos(ang)
        u0 = 20 - 9 * t
        img[(u >= u0) & (u <= u0 + 5) & (np.abs(v) <= (u - u0) * 0.9)] = hexc("ffe08a")
    if f == FRAMES - 1:
        img[inside & (DITH < 0.8)] = hexc("ffd27a")
    img[outline(img[..., 3] > 0)] = hexc("2a0a08")
    return img


def a_puddle(f: int, kind: str) -> np.ndarray:
    ol, deep, mid, light, hi = (hexc(c) for c in A_PUD[kind])
    t = f / FRAMES
    p = 2 * np.pi * t
    rr = 23 + wob(A, 210, 2.4) + 0.8 * np.sin(3 * A + p)
    m = R < rr
    img = blank()
    img[m] = deep
    img[m & (DITH < (1 - R / rr) * 0.95)] = mid
    if kind == "poison":                         # bubbles that swell and pop
        for i, (bx, by, ph) in enumerate(((-7, 3, 0.0), (6, -5, 0.35), (3, 9, 0.7), (-3, -9, 0.15))):
            q = (t + ph) % 1.0
            br = 1.0 + 3.5 * q
            d = np.hypot(DX - bx, DY - by)
            if q < 0.85:
                img[m & (np.abs(d - br) < 0.7)] = light
                img[m & (np.abs(DX - (bx - br * 0.5)) < 0.5) & (np.abs(DY - (by - br * 0.5)) < 0.5)] = hi
            else:
                img[m & (np.abs(d - br - 1.5) < 0.5) & (DITH < 0.5)] = light
    else:                                        # ripples, one every half loop
        for k in range(2):
            q = (t + k * 0.5) % 1.0
            ripple = q * rr * 0.9
            img[m & (np.abs(R - ripple) < 0.8) & (DITH < 1.0 - q * 0.8)] = light
    img[m & (np.abs(DX + 8) < 2) & (np.abs(DY + 9) < 0.5)] = hi
    img[m & (np.abs(DX + 4.5) < 0.5) & (np.abs(DY + 9) < 0.5)] = hi
    img[outline(m)] = ol
    return img


def a_burst(f: int) -> np.ndarray:
    t = f / (FRAMES - 1)
    e = ease_out(t)
    rs = 6 + 24 * e
    star = rs * (0.45 + 0.55 * np.abs(np.cos(3.5 * (A - 0.3))) ** 6)
    m = R < star
    if t > 0.4:
        m &= R > (t - 0.4) / 0.6 * rs * 0.9
    img = blank()
    hot = ("fffbe8", "ffe36a", "ff8a2a") if t < 0.5 else ("ffe36a", "ff8a2a", "c2321f")
    frac = R / np.maximum(star, 1e-3)
    img[m] = hexc(hot[2])
    img[m & (frac < 0.75)] = hexc(hot[1])
    img[m & (frac < 0.4)] = hexc(hot[0])
    if t > 0.15:
        rng = np.random.default_rng(311)
        for ang in rng.uniform(0, 2 * np.pi, 9):
            d = 8 + 30 * e * rng.uniform(0.7, 1.0)
            x, y = np.cos(ang) * d, np.sin(ang) * d
            img[(np.abs(DX - x) < 1.0) & (np.abs(DY - y) < 1.0)] = hexc(hot[1])
    if t > 0.7:
        img[DITH < (t - 0.7) / 0.3] = 0
    img[outline(img[..., 3] > 0)] = hexc("2a0a08")
    return img


# ------------------------------------------------------------------------------------------------ chart

INK = "2b1e14"
SEPIA = "7a4e26"
RED_INK = "a8261c"
B_PUD = {"rain": ("1c3348", "4f86a8"), "blood": ("3e0a0a", "9a2a22"), "poison": ("1e4214", "5f9a2a")}


def b_telegraph(f: int) -> np.ndarray:
    t = f / (FRAMES - 1)
    img = blank()
    rot = t * 0.5
    star = 17 * (0.3 + 0.7 * np.abs(np.cos(4 * (A - rot))) ** 10)
    sm = R < star
    half = np.sin(8 * (A - rot)) > 0
    img[sm & half] = hexc(RED_INK, 150)
    img[sm & ~half] = hexc("e8d2a8", 110)
    img[outline(sm)] = hexc(INK, 200)
    rr = 26.0
    band = np.abs(R - rr) < 2.3
    twist = np.mod(A * rr * 0.5 + (R - rr) * 1.3, 3.0) < 1.5
    img[band & twist] = hexc(INK)
    img[band & ~twist] = hexc("b08048")
    for k in range(8):
        ang = k * np.pi / 4 + np.pi / 8
        img[np.hypot(DX - np.cos(ang) * rr, DY - np.sin(ang) * rr) < 3.0] = hexc(INK)
    sweep = (np.abs(R - (rr - 4.5)) < 0.7) & (UP_ANG < t * 2 * np.pi + 1e-6) & (np.mod(UP_ANG * rr, 4.0) < 2.5)
    img[sweep] = hexc(RED_INK)
    if f == FRAMES - 1:
        x = ((np.abs(DX - DY) < 1.7) | (np.abs(DX + DY) < 1.7)) & (R < 10)
        img[x] = hexc(RED_INK)
    return img


def b_puddle(f: int, kind: str) -> np.ndarray:
    ink, wash = B_PUD[kind]
    t = f / FRAMES
    rr = 23 + wob(A, 220, 2.2)
    m = R < rr
    img = blank()
    img[m] = hexc(wash, 165)
    for n in range(4):                           # contours drifting outward, the inner ones dotted
        q = (n + t) / 4.0
        lr = q * rr * (1 + 0.06 * wob(A, 230 + n))
        line = (np.abs(R - lr) < 0.55) & (np.mod(A * lr, 3.2) < 1.8)
        img[line & m] = hexc(ink, int(230 - 120 * q))
    img[np.abs(R - rr) < 0.65] = hexc(ink)
    ticks = (R > rr + 1) & (R < rr + 3.2) & (np.mod(A * 30 / np.pi + 0.5, 2.0) < 0.35)
    img[ticks] = hexc(ink, 200)
    rng = np.random.default_rng(240)
    for _ in range(5):                           # soundings
        x, y = rng.uniform(-12, 12, 2)
        img[(np.abs(DX - x) < 0.5) & (np.abs(DY - y) < 0.5)] = hexc(ink)
    if kind == "poison":
        for bx, by, ph in ((-6, 4, 0.0), (7, -4, 0.5)):
            br = 1 + 3 * ((t + ph) % 1)
            img[np.abs(np.hypot(DX - bx, DY - by) - br) < 0.55] = hexc(ink)
    return img


def b_burst(f: int) -> np.ndarray:
    t = f / (FRAMES - 1)
    e = ease_out(t)
    img = blank()
    fade = 1.0 if t < 0.6 else 1 - (t - 0.6) / 0.4 * 0.8
    rb = 4 + 13 * e
    blot = R < rb * (1 + 0.28 * wob(A, 330))
    hatch = np.mod(DX + DY, 3.0) < 1.0
    img[blot] = hexc(RED_INK, int(200 * fade))
    img[blot & hatch] = hexc(INK, int(255 * fade))
    rng = np.random.default_rng(331)
    for k in range(10):
        ang = rng.uniform(0, 2 * np.pi)
        d = 8 + 26 * e * rng.uniform(0.6, 1.0)
        dr = 2.4 * (1 - t) + 0.8
        img[np.hypot(DX - np.cos(ang) * d, DY - np.sin(ang) * d) < dr] = hexc(INK, int(255 * fade))
    for k in range(8):                           # cartographer's rays
        ang = k * np.pi / 4
        u = DX * np.cos(ang) + DY * np.sin(ang)
        v = -DX * np.sin(ang) + DY * np.cos(ang)
        img[(np.abs(v) < 0.5) & (u > rb + 2) & (u < rb + 6 + 10 * e)] = hexc(SEPIA, int(220 * fade))
    return img


# ------------------------------------------------------------------------------------------------ woodcut

KEY = "17110d"
PAPER = "f1e3c6"
C_SPOT = {"rain": "6fa4c4", "blood": "c42a2a", "poison": "7cc44a"}


def c_telegraph(f: int) -> np.ndarray:
    t = f / (FRAMES - 1)
    img = blank()
    rr = 26.0
    saw = np.mod(A / (2 * np.pi) * 24, 1.0)
    ring = (R > rr - 4) & (R < rr + 3 * saw)
    img[ring] = hexc(KEY)
    img[ring & (np.abs(np.sin(12 * A)) < 0.12) & (R < rr)] = 0
    inner = R < rr - 5
    swept = inner & (UP_ANG <= t * 2 * np.pi + 1e-6)
    img[swept] = hexc("c43a24")
    img[swept & (np.mod(R, 5.0) < 1.1)] = hexc(PAPER)
    img[R < 3.2] = hexc(KEY)
    if f == FRAMES - 1:
        img[inner] = hexc("c43a24")
        img[inner & (np.mod(R + 2.5, 5.0) < 1.1)] = hexc(PAPER)
    return img


def c_puddle(f: int, kind: str) -> np.ndarray:
    t = f / FRAMES
    rr = 23 + wob(A, 250, 1.8) + 1.4 * np.abs(np.sin(9 * A))
    m = R < rr
    img = blank()
    img[m] = hexc(KEY)
    spot = hexc(C_SPOT[kind])
    for k in range(3):
        q = (t + k / 3) % 1.0
        lr = q * rr * 0.85 * (1 + 0.1 * wob(A, 260 + k))
        img[m & (np.abs(R - lr) < 0.9 + 0.5 * (1 - q))] = spot
    shine = m & (np.abs(A + 2.3) < 0.45) & (R > rr * 0.55) & (R < rr * 0.68)
    img[shine] = hexc(PAPER)
    if kind == "poison":
        for bx, by, ph in ((-5, 6, 0.0), (8, 2, 0.5)):
            br = 1.5 + 3 * ((t + ph) % 1)
            img[m & (np.hypot(DX - bx, DY - by) < br)] = spot
            img[m & (np.hypot(DX - bx, DY - by) < br - 1.2)] = hexc(KEY)
    return img


def c_burst(f: int) -> np.ndarray:
    t = f / (FRAMES - 1)
    e = ease_out(t)
    rs = 7 + 23 * e
    rot = 0.2 + 0.3 * t
    spikes = np.abs(np.cos(4 * (A - rot))) ** 3
    outer = R < rs * (0.42 + 0.58 * spikes)
    inner = R < rs * 0.62 * (0.42 + 0.58 * spikes)
    img = blank()
    img[outer] = hexc(KEY)
    img[inner] = hexc("e85a1e" if t < 0.6 else "c43a24")
    img[outer & (np.abs(np.sin(8 * (A - rot))) < 0.07) & (R > rs * 0.25)] = hexc(PAPER)
    img[R < rs * 0.2 * (1 - t)] = hexc(PAPER)
    if t > 0.6:
        img[hash01(340) < (t - 0.6) / 0.4] = 0
    return img


# ------------------------------------------------------------------------------------------------ painterly

S2 = S * 2
_y2, _x2 = np.mgrid[0:S2, 0:S2].astype(np.float64)
X2 = (_x2 + 0.5) / 2 - S / 2
Y2 = (_y2 + 0.5) / 2 - S / 2


class Canvas:
    def __init__(self) -> None:
        self.rgb = np.zeros((S2, S2, 3))
        self.a = np.zeros((S2, S2))

    def dab(self, cx: float, cy: float, ang: float, length: float, width: float, col: str, alpha: float = 1.0,
            seed: float = 0.0) -> None:
        c = hexc(col)[:3].astype(np.float64)
        u = (X2 - cx) * np.cos(ang) + (Y2 - cy) * np.sin(ang)
        v = -(X2 - cx) * np.sin(ang) + (Y2 - cy) * np.cos(ang)
        taper = 1 - 0.35 * np.clip(u / (length / 2), -1, 1)           # thick head, thin tail
        d = np.hypot(u / (length / 2), v / (width / 2 * taper))
        bristle = 0.88 + 0.12 * np.sin(v * 4.5 + seed)
        k = np.clip((1 - d) * 4, 0, 1) * bristle * alpha
        self.rgb = self.rgb * (1 - k[..., None]) + c * k[..., None]
        self.a = self.a + k * (1 - self.a)

    def finish(self, pal: list) -> np.ndarray:
        rgb = self.rgb.reshape(S, 2, S, 2, 3).mean(axis=(1, 3))
        a = self.a.reshape(S, 2, S, 2).mean(axis=(1, 3))
        cols = np.array([hexc(c)[:3] for c in pal], dtype=np.float64)
        idx = np.argmin(((rgb[..., None, :] - cols[None, None]) ** 2).sum(-1), axis=-1)
        img = blank()
        on = a > 0.3 + 0.35 * DITH
        img[..., :3] = cols[idx].astype(np.uint8)
        img[..., 3] = np.where(on, 255, 0)
        return img


D_TEL = ["5a1410", "9a2414", "d8461e", "f08a2a", "ffc860", "fff0c0"]
D_PUD = {"rain": ["1e2a36", "2f4558", "4d6e84", "86aabd", "d4ecf4"],
         "blood": ["2e0406", "560a0e", "86161a", "c03a32", "f4a090"],
         "poison": ["173d12", "2c6a1c", "4f9a2a", "93d052", "e4f8a8"]}
D_BURST = ["7a2410", "d8461e", "f6a03a", "ffe08a", "fffbe8"]


def d_telegraph(f: int) -> np.ndarray:
    t = f / (FRAMES - 1)
    cv = Canvas()
    rng = np.random.default_rng(400 + f // 2)
    for k in range(26):
        ang = k / 26 * 2 * np.pi + rng.uniform(-0.05, 0.05)
        rr = 25 + rng.uniform(-0.8, 0.8)
        cv.dab(np.cos(ang) * rr, np.sin(ang) * rr, ang + np.pi / 2, 10, 6, "9a2414" if k % 3 else "d8461e", 1, k)
    n = int(4 + 22 * t)
    for i in range(n):                           # a spiral of strokes winding in as it charges
        q = i / 26
        ang = -q * 3.2 * np.pi - t * np.pi
        rr = 22 * (1 - q)
        cv.dab(np.cos(ang) * rr, np.sin(ang) * rr, ang + np.pi / 2 - 0.4, 8, 4.5, "f08a2a" if i % 2 else "d8461e",
               0.9, i)
    if f == FRAMES - 1:
        cv.dab(0, 0, 0.3, 16, 14, "ffc860")
        cv.dab(-1, -1, 0.3, 8, 6, "fff0c0")
    return cv.finish(D_TEL)


def d_puddle(f: int, kind: str) -> np.ndarray:
    pal = D_PUD[kind]
    t = f / FRAMES
    p = 2 * np.pi * t
    cv = Canvas()
    for k in range(11):                          # the body: round strokes laid round the rim, breathing
        ang = k / 11 * 2 * np.pi + 0.4
        s = 1 + 0.06 * np.sin(p + k * 1.7)
        rr = 13 + 1.5 * np.sin(k * 2.3)
        cv.dab(np.cos(ang) * rr, np.sin(ang) * rr, ang + np.pi / 2, 18 * s, 13 * s, pal[1], 1, k)
    cv.dab(0, 0, 0.5, 30, 26, pal[1])
    cv.dab(1, 1, 0.5, 20, 16, pal[0], 0.8)
    for k in range(3):                           # the swirl going round
        ang = p + k * 2 * np.pi / 3
        rr = 10
        cv.dab(np.cos(ang) * rr, np.sin(ang) * rr, ang + np.pi / 2, 12, 3, pal[2], 0.9, k)
    if kind == "poison":
        for bx, by, ph in ((-6, 5, 0.0), (6, -4, 0.5)):
            br = 2 + 4 * ((t + ph) % 1)
            cv.dab(bx, by, 0, br * 2, br * 2, pal[3], 0.8)
            cv.dab(bx - br * 0.3, by - br * 0.3, 0, br * 0.6, br * 0.6, pal[4], 1)
    cv.dab(-8, -9, -0.5, 7, 2.5, pal[3])
    cv.dab(-9, -9.5, -0.5, 3, 1.5, pal[4])
    return cv.finish(pal)


def d_burst(f: int) -> np.ndarray:
    t = f / (FRAMES - 1)
    e = ease_out(t)
    cv = Canvas()
    for k in range(6):                           # petals flung out, curling as they go
        ang = k / 6 * 2 * np.pi + 0.3 + e * 0.6
        rr = 5 + 19 * e
        col = D_BURST[3] if t < 0.4 else D_BURST[2] if t < 0.75 else D_BURST[1]
        cv.dab(np.cos(ang) * rr, np.sin(ang) * rr, ang + np.pi, 13 * (1 - 0.5 * t), 6 * (1 - 0.4 * t), col, 1, k)
    if t < 0.75:
        core = 11 * (1 - t) + 2
        cv.dab(0, 0, 0.0, core * 2, core * 2, D_BURST[3])
        cv.dab(0, 0, 0.0, core, core, D_BURST[4])
    rng = np.random.default_rng(431)
    for k in range(8):
        ang = rng.uniform(0, 2 * np.pi) + e * 1.2
        rr = 8 + 25 * e * rng.uniform(0.7, 1.0)
        cv.dab(np.cos(ang) * rr, np.sin(ang) * rr, ang + 1.2, 4 * (1 - t) + 1.5, 2, D_BURST[2], 1 - 0.6 * t, k)
    return cv.finish(D_BURST)


# ------------------------------------------------------------------------------------------------ previews

STYLES = {
    "dither": (a_telegraph, a_puddle, a_burst),
    "chart": (b_telegraph, b_puddle, b_burst),
    "woodcut": (c_telegraph, c_puddle, c_burst),
    "painterly": (d_telegraph, d_puddle, d_burst),
}
SUBJECTS = ["telegraph", "rain", "blood", "poison", "burst"]
BLURB = {
    "dither": "chunky pixels, dithered fills, boiling outline",
    "chart": "sea-chart ink: rope, compass, contours",
    "woodcut": "two-colour stamp, carved gouges",
    "painterly": "brush dabs, small palette per effect",
}


def frames_of(style: str, subject: str) -> list:
    tel, pud, burst = STYLES[style]
    if subject == "telegraph":
        return [tel(f) for f in range(FRAMES)]
    if subject == "burst":
        return [burst(f) for f in range(FRAMES)]
    return [pud(f, subject) for f in range(FRAMES)]


def on_ground(img: np.ndarray, ground: Image.Image) -> Image.Image:
    fx = Image.fromarray(img, "RGBA")
    out = ground.copy()
    out.alpha_composite(fx)
    return out.convert("RGB")


def font(size: int):
    for name in ("arialbd.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    dirt = Image.open(GROUND).convert("RGBA")
    ground = dirt.resize((S, S), Image.NEAREST) if dirt.size[0] < S else dirt.crop((0, 0, S, S))
    allf = {(st, su): frames_of(st, su) for st in STYLES for su in SUBJECTS}
    up = 3
    cell = S * up
    lab_w, head_h, gap = 210, 34, 6
    w = lab_w + len(SUBJECTS) * (cell + gap)
    h = head_h + len(STYLES) * (cell + gap)
    big, small = font(18), font(13)
    gif = []
    for f in range(FRAMES):
        im = Image.new("RGB", (w, h), (24, 22, 26))
        dr = ImageDraw.Draw(im)
        for j, su in enumerate(SUBJECTS):
            dr.text((lab_w + j * (cell + gap) + 8, 8), su + (" puddle" if su in PUDDLE_KINDS else ""), fill=(230, 220, 200),
                    font=big)
        for i, st in enumerate(STYLES):
            y = head_h + i * (cell + gap)
            dr.text((10, y + 10), st.upper(), fill=(255, 210, 120), font=big)
            words, line, ly = BLURB[st].split(), "", y + 40
            for wd in words:                      # wrap the blurb into the label column
                if dr.textlength(line + " " + wd, font=small) > lab_w - 20:
                    dr.text((10, ly), line.strip(), fill=(200, 195, 185), font=small)
                    line, ly = "", ly + 17
                line += " " + wd
            dr.text((10, ly), line.strip(), fill=(200, 195, 185), font=small)
            for j, su in enumerate(SUBJECTS):
                tile = on_ground(allf[(st, su)][f], ground).resize((cell, cell), Image.NEAREST)
                im.paste(tile, (lab_w + j * (cell + gap), y))
        gif.append(im)
    gif[0].save(os.path.join(OUT, "compare.gif"), save_all=True, append_images=gif[1:], duration=130, loop=0)
    still = Image.new("RGB", (w, h * 2 + 10), (24, 22, 26))
    still.paste(gif[2], (0, 0))
    still.paste(gif[6], (0, h + 10))
    still.save(os.path.join(OUT, "compare.png"))
    # per style: every frame of every subject
    for st in STYLES:
        sh = Image.new("RGB", (FRAMES * (S * 2 + 2), len(SUBJECTS) * (S * 2 + 2)), (24, 22, 26))
        for j, su in enumerate(SUBJECTS):
            for f, img in enumerate(allf[(st, su)]):
                sh.paste(on_ground(img, ground).resize((S * 2, S * 2), Image.NEAREST), (f * (S * 2 + 2), j * (S * 2 + 2)))
        sh.save(os.path.join(OUT, f"sheet_{st}.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
