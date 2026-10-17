#!/usr/bin/env python3
"""
Driftwake drape textures: the cape's fabric and the cloak's canvas with vertical fold shading painted in (soft
darker troughs and lighter crests, stepped into a few bands with a 4x4 ordered dither at their edges, PS1 style).
Two folds per tile, uneven, wobbling a little down the tile; tiles both ways. BodyBuilder lays the u of a sheet's
columns evenly from collar to hem, so the folds gather at the collar and fan toward the hem with the cloth.

    py tools/texture_gen/gen_drape_textures.py

Writes assets/textures/psx/drape_fabric.png and drape_canvas.png (64x64). Nothing else is regenerated.
"""
from __future__ import annotations

import math

import numpy as np

from gen_psx_textures import fbm, norm, save, to_img

S = 64
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
# the light across a fold, trough to crest, in steps
LEVELS = np.array([0.7, 0.82, 0.93, 1.0, 1.07])


def folds() -> np.ndarray:
    """S x S brightness multiplier: two uneven folds across, their edges dithered."""
    u = (np.arange(S) + 0.5) / S
    v = (np.arange(S) + 0.5) / S
    uu = u[None, :] + 0.035 * np.sin(2 * math.pi * v[:, None]) + 0.012 * np.sin(4 * math.pi * v[:, None] + 1.3)
    # uneven: one broad fold and one narrower, warped round the tile
    w = uu + 0.07 * np.sin(2 * math.pi * uu)
    shade = 0.5 + 0.5 * np.cos(4 * math.pi * w)
    # crests narrower and brighter than the troughs are wide (cloth hangs in rounded pleats)
    shade = shade ** 1.6
    yy, xx = np.mgrid[0:S, 0:S]
    t = shade * (len(LEVELS) - 1) + BAYER[yy % 4, xx % 4] * 0.9
    idx = np.clip(np.round(t).astype(int), 0, len(LEVELS) - 1)
    return LEVELS[idx]


def gen_drape_fabric() -> None:
    rng = np.random.default_rng(1301)
    n = fbm(S, 4, 2, rng) * 0.5 + rng.random((S, S)) * 0.5
    weave = ((np.arange(S)[:, None] + np.arange(S)[None, :]) % 2) * 0.12
    v = np.clip((0.72 + (norm(n) - 0.5) * 0.25 + weave) * folds(), 0, 1)
    g = (v * 255).astype(np.uint8)
    save(to_img(np.dstack([g, g, g])), "drape_fabric")


def gen_drape_canvas() -> None:
    rng = np.random.default_rng(1312)
    n = rng.random((S, S)) * 0.25
    base = np.array([0xd8, 0xd0, 0xb8], dtype=float)
    rgb = base[None, None, :] * (0.85 + n[..., None])
    rgb[::4] *= 0.9
    rgb *= folds()[..., None]
    save(to_img(np.clip(rgb, 0, 255).astype(np.uint8)), "drape_canvas")


if __name__ == "__main__":
    gen_drape_fabric()
    gen_drape_canvas()
