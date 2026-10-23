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
