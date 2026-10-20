#!/usr/bin/env python3
"""
The royal capital's textures (scripts/island/capital_*.gd): white limestone ashlar for its walls, towers, quays and
palace, and the pale paving slabs of its plaza and avenues. 64x64, tileable, palette-quantized, fixed seeds, the
helpers from gen_psx_textures.py.

    py tools/texture_gen/gen_capital_textures.py
"""
from __future__ import annotations

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from gen_psx_textures import save, fbm, norm, ramp, pal, hexc, to_img  # noqa: E402


def gen_limestone():
    """Dressed white limestone in courses of long blocks, a warm cream in the joints, each block its own shade."""
    rng = np.random.default_rng(8101)
    n = fbm(64, 4, 4, rng)
    rgb = ramp(norm(n * 0.8 + rng.random((64, 64)) * 0.2), pal("e2dccd", "e9e3d6", "efeadf", "f4f0e7", "faf7f0"))
    joint = hexc("c3b9a6")
    bh = 16
    for r in range(4):
        y0 = r * bh
        rgb[y0] = joint
        off = int(rng.integers(0, 32))
        x = off
        while x < 64 + off:
            w = int(rng.choice([21, 32, 43]))
            rgb[y0:y0 + bh, x % 64] = joint
            s = rng.uniform(0.92, 1.06)
            for xx in range(x + 1, x + w):
                rgb[y0 + 1:y0 + bh, xx % 64] = np.clip(rgb[y0 + 1:y0 + bh, xx % 64] * s, 0, 255)
            x += w
    for _ in range(22):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("b8ae99")
    save(to_img(rgb), "limestone")


def gen_capital_slabs():
    """Big pale rectangular paving slabs in a running bond (the plaza, the avenues, the quays), worn darker joints."""
    rng = np.random.default_rng(8102)
    n = fbm(64, 4, 3, rng)
    rgb = ramp(norm(n * 0.7 + rng.random((64, 64)) * 0.3), pal("a9a397", "b5afa2", "c0baad", "cac4b7", "d3cec2"))
    joint = hexc("7f796e")
    rows = 3
    for r in range(rows):
        y0 = r * 64 // rows
        y1 = (r + 1) * 64 // rows
        rgb[y0] = joint
        off = 0 if r % 2 == 0 else 16
        for x in range(off, 64 + off, 32):
            rgb[y0:y1, x % 64] = joint
            s = rng.uniform(0.9, 1.08)
            for xx in range(x + 1, x + 32):
                rgb[y0 + 1:y1, xx % 64] = np.clip(rgb[y0 + 1:y1, xx % 64] * s, 0, 255)
    for _ in range(30):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("938d81")
    save(to_img(rgb), "capital_slabs")


def _wall(rng: np.random.Generator) -> np.ndarray:
    n = fbm(64, 4, 4, rng)
    stains = fbm(64, 2, 2, rng)
    return ramp(norm(n * 0.6 + stains * 0.4), pal("d9d3c6", "e1dccf", "e8e4d8", "eeebe1", "f4f1e9"))


def _facade(name: str, seed: int, arched: bool) -> None:
    """One bay of a town house, 3 m wide by a storey 3 m tall: lime-washed wall, a window with shutters and a sill
    (or an arched one over a little iron balcony), a string course at the floor line. Near white: a house's tint
    colours it. Its glow mask (the panes) lights the windows at night."""
    rng = np.random.default_rng(seed)
    rgb = _wall(rng)
    glow = np.zeros((64, 64, 3), dtype=np.uint8)
    rgb[62:64] = hexc("b9b2a3")
    rgb[61] = hexc("cfc8ba")
    x0, x1, y0, y1 = 22, 42, 16, 47
    frame = hexc("bdb4a2")
    rgb[y0 - 2:y1 + 1, x0 - 2:x1 + 2] = frame
    pane = pal("2a3440", "33404d", "3d4b59")
    yy, xx = np.mgrid[0:64, 0:64]
    win = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
    if arched:
        cx, cy, r = (x0 + x1 - 1) / 2.0, y0 + 10, (x1 - x0) / 2.0
        top = (yy < cy) & (np.hypot(xx - cx, yy - cy) > r)
        win &= ~top
        rgb[(yy >= y0 - 2) & (yy < cy) & (np.hypot(xx - cx, yy - cy) > r + 2) & (xx >= x0 - 2) & (xx < x1 + 2)] = _wall(rng)[(yy >= y0 - 2) & (yy < cy) & (np.hypot(xx - cx, yy - cy) > r + 2) & (xx >= x0 - 2) & (xx < x1 + 2)]
    shade = ramp(norm(yy[win].astype(float) + rng.random(win.sum()) * 6.0), pane)
    rgb[win] = shade
    mull = win & ((xx == (x0 + x1) // 2) | (yy == (y0 + y1) // 2 + 2))
    rgb[mull] = frame
    glow[win & ~mull] = hexc("ffffff")
    if arched:
        rail = hexc("2b2b30")
        rgb[y1 - 1:y1 + 1, x0 - 6:x1 + 6] = rail
        rgb[y1 + 6:y1 + 8, x0 - 6:x1 + 6] = rail
        for x in range(x0 - 6, x1 + 6, 3):
            rgb[y1 + 1:y1 + 6, x] = rail
        rgb[y1 + 8:y1 + 10, x0 - 7:x1 + 7] = hexc("a69e8e")
    else:
        sh = pal("4f6a78", "5a7685", "668392")
        for sx0 in (x0 - 11, x1 + 2):
            band = ramp(norm(xx[y0:y1, sx0:sx0 + 9].astype(float) % 3 + rng.random((y1 - y0, 9))), sh)
            rgb[y0:y1, sx0:sx0 + 9] = band
            rgb[y0:y1:5, sx0:sx0 + 9] = hexc("3f5663")
        rgb[y1 + 1:y1 + 4, x0 - 4:x1 + 4] = hexc("b0a796")
    save(to_img(rgb), name)
    save(to_img(glow), name + "_glow")


def gen_facades():
    _facade("capital_facade_a", 8103, False)
    _facade("capital_facade_b", 8104, True)


if __name__ == "__main__":
    gen_limestone()
    gen_capital_slabs()
    gen_facades()
