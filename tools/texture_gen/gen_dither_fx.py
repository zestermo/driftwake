#!/usr/bin/env python3
"""
1.19's dither effects (the style Zach picked from gen_fx_style_samples.py): chunky pixel sprites, Bayer-dithered
fills and a 1 px dark outline that boils from frame to frame. Drawn by the "dither" functions there.

Usage (from the project root):
    py tools/texture_gen/gen_dither_fx.py

Output (assets/textures/fx/), each 8 frames of 64 px in a 4x2 grid (256x128), read by the PSX decal shader's
sheet mode (shaders/psx/psx_decal_body.gdshaderinc, PSXMat.decal_sheet):
    dither_telegraph.png        an enemy's ground warning charging up, frame 0 -> 7 over its wind-up. Palette
                                indices, not colours: grey 0.2 outline, 0.4 deep fill, 0.6 body, 0.8 highlight
                                (FX.telegraph colours them from the caller's colour)
    dither_puddle_<kind>.png    rain / poison puddle loops in full colour
    dither_ring[_wide].png      FX.ring's shockwave (indices like the telegraph; band 0.12 / 0.3 of the radius)
    dither_blood.png            blood splats, 4x4: two round and two directed (spatter to +U), each a row of
                                4 frames landing (FX._place_splat)
    flip_dither_muzzle.png      a gun's or cannon's flare, 4x4 frames (FX.blast, cannon_blast, powder_burst)
    flip_dither_hit.png         a hit burst, 4x4 frames in FX.flipbook's format (impact, parry_sparks)
and a preview at tools/dev/out/flipbook/dither.png. Deterministic.
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image

import gen_fx_style_samples as fs
from gen_fx_style_samples import A, DITH, DX, DY, FRAMES, R, S, blank, outline, wob

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "fx")
PREVIEW = os.path.join(ROOT, "tools", "dev", "out", "flipbook")
COLS = 4


def idx(level: int) -> np.ndarray:
    g = int(round(level * 0.2 * 255))
    return np.array([g, g, g, 255], dtype=np.uint8)


def telegraph(f: int) -> np.ndarray:
    """The dither telegraph in palette indices, its ring at the quad's edge (the warning's radius)."""
    t = f / (FRAMES - 1)
    img = blank()
    # Kept quiet (Zach: "more subtle, don't fully fill the areas"): a thin ring dark only on its outside, a
    # sparse speckle inside, the charge a thin dithered edge with a faint wake, never a solid fill.
    rr = 30.0 + wob(A, 100 + f // 2, 0.6)
    inside = R < rr - 1.0
    img[inside & (DITH < 0.07)] = idx(2)
    ring = np.abs(R - rr) < 0.75
    img[ring] = idx(3)
    img[outline(ring) & (R > rr)] = idx(1)
    pr = t * (rr - 1.0)
    img[inside & (R < pr) & (R > pr - 3.5) & (DITH < 0.22)] = idx(3)
    img[inside & (np.abs(R - pr) < 0.7) & (DITH < 0.6)] = idx(4)
    for k in range(4):                           # small chevrons closing in
        ang = k * np.pi / 2 + np.pi / 4
        u = DX * np.cos(ang) + DY * np.sin(ang)
        v = -DX * np.sin(ang) + DY * np.cos(ang)
        u0 = 24 - 10 * t
        img[(u >= u0) & (u <= u0 + 3) & (np.abs(v) <= (u - u0) * 0.9)] = idx(4)
    if f == FRAMES - 1:                          # about to land: the rim's band lights, still dithered
        img[inside & (R > rr - 4) & (DITH < 0.45)] = idx(4)
    return img


def ring(f: int, width: float) -> np.ndarray:
    """FX.ring's shockwave in palette indices: a band at the quad's edge `width` of the radius thick, a bright
    leading pixel and a dark one outside it, thinning and breaking into dithered dashes as it spreads."""
    t = f / (FRAMES - 1)
    img = blank()
    rr = 30.5 + wob(A, 500 + f // 2, 0.5)
    w = max(width * 30.0 * (1 - 0.55 * t), 1.2)
    band = (R < rr) & (R > rr - w)
    seg = np.floor((A + np.pi) / (2 * np.pi) * 18)  # 18 dashes round, dropping out one by one
    keep = (np.random.default_rng(510).random(18)[seg.astype(int) % 18] > (t - 0.15) * 0.85) & (DITH > t * t * 0.7)
    band &= keep
    img[band] = idx(3)
    if t < 0.6:
        img[band & (R > rr - 1.2)] = idx(4)
    wake = (R < rr - w) & (R > rr - w - 3) & (DITH < 0.15 * (1 - t))
    img[wake] = idx(2)
    img[outline(band) & (R >= rr - 0.5)] = idx(1)
    return img


def hit(f: int, n: int = 16) -> np.ndarray:
    """A small hit burst in colour (flip format, 16 frames): a white-hot chunky star that opens into a ring,
    a few flung pixels, dithered away; kept small (Zach: subtle)."""
    t = f / (n - 1)
    e = 1 - (1 - t) ** 2
    rs = 5 + 19 * e
    # nine uneven spikes (lengths and angles jittered): an impact flash, not a cartoon star
    rng = np.random.default_rng(605)
    star = rs * 0.3 * np.ones_like(R)
    for k in range(9):
        ak = k / 9 * 2 * np.pi + rng.uniform(-0.2, 0.2)
        lk = rng.uniform(0.45, 1.0)
        da = np.angle(np.exp(1j * (A - ak)))
        star = np.maximum(star, rs * lk * np.clip(1 - np.abs(da) * 9 / (2 * np.pi) * 2.2, 0, 1) ** 1.5)
    m = R < star
    if t > 0.4:
        m &= R > (t - 0.4) / 0.6 * rs * 0.8
    img = blank()
    hot = ("fffbe8", "ffe36a", "ff9a3a") if t < 0.45 else ("ffe36a", "ff9a3a", "d0402a")
    frac = R / np.maximum(star, 1e-3)
    img[m] = fs.hexc(hot[2])
    img[m & ((frac < 0.7) | (R < rs * 0.3))] = fs.hexc(hot[1])
    img[m & (R < rs * 0.22)] = fs.hexc(hot[0])
    if 0.1 < t < 0.85:
        rng = np.random.default_rng(611)
        for ang in rng.uniform(0, 2 * np.pi, 6):
            d = 7 + 22 * e * rng.uniform(0.7, 1.0)
            img[(np.abs(DX - np.cos(ang) * d) < 1.0) & (np.abs(DY - np.sin(ang) * d) < 1.0)] = fs.hexc(hot[1])
    if t > 0.55:
        img[DITH < (t - 0.55) / 0.45] = 0
    img[outline(img[..., 3] > 0)] = fs.hexc("2a0a08")
    return img


def muzzle(f: int, n: int = 16) -> np.ndarray:
    """A gun's or a cannon's flare (flip format, 16 frames): uneven flame tongues round a white-hot core at
    once, shrinking and opening as it cools to orange, then dithered powder smoke."""
    t = f / (n - 1)
    rs = 27 * (1 - 0.45 * t) if t > 0.06 else 18
    rng = np.random.default_rng(805)
    shape = rs * 0.42 * np.ones_like(R)
    for k in range(7):                           # tongues: rounder than the hit's spikes
        ak = k / 7 * 2 * np.pi + rng.uniform(-0.3, 0.3)
        lk = rng.uniform(0.55, 1.0)
        da = np.angle(np.exp(1j * (A - ak)))
        shape = np.maximum(shape, rs * lk * np.clip(1 - np.abs(da) * 7 / (2 * np.pi) * 1.6, 0, 1) ** 0.7)
    shape *= 1 + 0.08 * wob(A, 810 + f // 2)
    m = R < shape
    if t > 0.3:
        m &= R > (t - 0.3) / 0.7 * rs * 0.55
    img = blank()
    frac = R / np.maximum(shape, 1e-3)
    if t < 0.5:
        hot = ("fffbe8", "ffe36a", "ff9a3a", "c2321f") if t < 0.25 else ("ffe36a", "ff9a3a", "d0402a", "7a2410")
        img[m] = fs.hexc(hot[3])
        img[m & (frac < 0.85)] = fs.hexc(hot[2])
        img[m & (frac < 0.6)] = fs.hexc(hot[1])
        img[m & (frac < 0.35)] = fs.hexc(hot[0])
        ol = fs.hexc("2a0a08")
    else:                                        # cooled to powder smoke
        img[m & (DITH < 0.75)] = fs.hexc("6b625a")
        img[m & (frac < 0.6) & (DITH < 0.5)] = fs.hexc("8e8478")
        img[m & (frac > 0.85) & (DITH < 0.4)] = fs.hexc("c2321f")
        ol = fs.hexc("2a2624")
    if t > 0.55:
        img[DITH < (t - 0.55) / 0.45] = 0
    img[outline(img[..., 3] > 0)] = ol
    return img


BLOOD = [fs.hexc(c) for c in ("1a0204", "3a0408", "6e0a10", "8e1418", "d86a60")]


def splat(variant: int, k: int, directed: bool) -> np.ndarray:
    """A blood splat landing (k 0..3: flung, spreading, pooling, settled): a lumpy pool with satellite blobs,
    fingers and droplets (onward to +X, the quad's +U, when `directed`), dithered darker in the middle, a
    glint and a dark outline. Its main pool is 10 px across the radius (FX's splat unit)."""
    ol, deep, mid, light, hi = BLOOD
    rng = np.random.default_rng(700 + variant * 31 + int(directed) * 7)
    p = (0.35, 0.65, 0.9, 1.0)[k]
    r0 = 10.0
    m = R < r0 * p * (1 + 0.16 * wob(A, 710 + variant))
    for _ in range(rng.integers(1, 4)):           # satellite lumps
        a = rng.uniform(0, 2 * np.pi)
        c = np.array([np.cos(a), np.sin(a)]) * rng.uniform(0.35, 0.7) * r0
        m |= np.hypot(DX - c[0], DY - c[1]) < rng.uniform(0.45, 0.8) * r0 * p
    for _ in range(rng.integers(2, 5)):           # fingers
        a = rng.uniform(-0.7, 0.7) if directed else rng.uniform(0, 2 * np.pi)
        u = DX * np.cos(a) + DY * np.sin(a)
        v = -DX * np.sin(a) + DY * np.cos(a)
        tip = rng.uniform(1.25, 1.75) * r0 * p
        m |= (u > 0.5 * r0 * p) & (u < tip) & (np.abs(v) < (tip - u) * 0.16 + 0.3)
    drops = np.zeros_like(m)
    for _ in range(rng.integers(5, 11)):          # droplets: flung out, landing by the third frame
        a = rng.uniform(-0.9, 0.9) if directed and rng.random() < 0.75 else rng.uniform(0, 2 * np.pi)
        d = rng.uniform(1.1, 2.6) * r0 * min(1.0, p * 1.15)
        rd = rng.uniform(0.6, 2.4)
        drops |= np.hypot(DX - np.cos(a) * d, DY - np.sin(a) * d) < rd
    m &= R < 31
    drops &= (R < 31) & ~m
    img = blank()
    img[m | drops] = mid
    img[m & (R < r0 * 0.55 * p) & (DITH < 0.6)] = deep
    img[m & (R < r0 * 0.3 * p)] = deep
    img[m & (np.abs(DX + r0 * 0.35 * p) < 1.0) & (np.abs(DY + r0 * 0.4 * p) < 0.5)] = hi
    img[m & (np.abs(DX + r0 * 0.35 * p - 2) < 0.5) & (np.abs(DY + r0 * 0.4 * p) < 0.5)] = light
    img[outline(m | drops)] = ol
    return img


def sheet(frames: list) -> Image.Image:
    rows = (len(frames) + COLS - 1) // COLS
    im = Image.new("RGBA", (COLS * S, rows * S), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        im.paste(Image.fromarray(fr, "RGBA"), ((i % COLS) * S, (i // COLS) * S))
    return im


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)
    sheets = {"dither_telegraph": sheet([telegraph(f) for f in range(FRAMES)])}
    for kind in ("rain", "poison"):
        sheets[f"dither_puddle_{kind}"] = sheet([fs.a_puddle(f, kind) for f in range(FRAMES)])
    sheets["dither_ring"] = sheet([ring(f, 0.12) for f in range(FRAMES)])
    sheets["dither_ring_wide"] = sheet([ring(f, 0.3) for f in range(FRAMES)])
    # the hit burst in FX.flipbook's format (flip_<name>.png, 4x4 frames of 64 px)
    sheets["flip_dither_hit"] = sheet([hit(f) for f in range(16)])
    sheets["flip_dither_muzzle"] = sheet([muzzle(f) for f in range(16)])
    # blood: rows 0-1 round splats, rows 2-3 directed, each row one splat landing over 4 frames
    sheets["dither_blood"] = sheet([splat(v, k, v >= 2) for v in range(4) for k in range(4)])
    for name, im in sheets.items():
        im.save(os.path.join(OUT, name + ".png"))
    prev = Image.new("RGBA", (COLS * S, sum(im.height for im in sheets.values())), (60, 50, 40, 255))
    y = 0
    for im in sheets.values():
        prev.alpha_composite(im, (0, y))
        y += im.height
    prev.resize((prev.width * 2, prev.height * 2), Image.NEAREST).save(os.path.join(PREVIEW, "dither.png"))
    print("wrote", ", ".join(sheets))


if __name__ == "__main__":
    main()
