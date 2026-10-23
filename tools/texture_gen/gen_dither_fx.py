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
    for name, im in sheets.items():
        im.save(os.path.join(OUT, name + ".png"))
    prev = Image.new("RGBA", (COLS * S, 2 * S * len(sheets)), (60, 50, 40, 255))
    for i, im in enumerate(sheets.values()):
        prev.alpha_composite(im, (0, i * 2 * S))
    prev.resize((prev.width * 2, prev.height * 2), Image.NEAREST).save(os.path.join(PREVIEW, "dither.png"))
    print("wrote", ", ".join(sheets))


if __name__ == "__main__":
    main()
