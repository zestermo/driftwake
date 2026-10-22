#!/usr/bin/env python3
"""
The other weapons' drawn elements (1.18.4's weapon mastery pass), each a variation on the cutlass's
water, the katana's cloud and the axe's fire, from one palette and one decoration per element:

    shadow  (dagger)        ink-black smoke with a crimson rim, wisps curling off it, crimson motes
    twin    (dual wield)    a cyan stream and a violet one wound round each other, sparkles
    venom   (twin daggers)  viper green, hollow bubbles rising off it, drips falling from the tail
    powder  (corsair)       dark powder smoke with a scarlet flash along the crest, gold sparks
    gold    (pistol)        a gold flash streak, four-pointed glints along it, grey smoke puffs
    gale    (fists)         white wind with sky-blue bands, gust hooks curling off the crest

Usage (from the project root):
    py tools/texture_gen/gen_drawn_fx.py [element ...]    (no names: all of them)

Output (assets/textures/fx/), per element:
    flip_<el>_slash.png, flip_<el>_cloud.png: 16 frames of 128 px in a 4x4 grid (FX.flipbook)
    <el>_trail.png: 8 frames of 256x64 stacked, tiling along their length (PetalRibbon, the auras)
and a preview at tools/dev/out/flipbook/drawn.png. Deterministic (a seed per sheet). Built on
gen_katana_fx.py's strokes and frames.
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

from gen_katana_fx import (FR, N, PX, RAD, TRAIL_FRAMES, TRAIL_H, TRAIL_W, U, V, _trail_put, _trail_spiral,
                           curl, frame_rgba, gobs, hexc, put, sheet, stroke)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures", "fx")
PREVIEW = os.path.join(ROOT, "tools", "dev", "out", "flipbook")


def pal(*cs: str) -> list:
    return [hexc(c) for c in cs]


# Each element: its body (8: the dark inner edge up to the white-hot crest), a second body for "twin", the
# decoration, the specks' colours and a seed.
ELEMENTS = {
    "shadow": {"body": pal("07050a", "16101c", "241826", "35202f", "4a2534", "8e1f33", "d8304a", "ff7a8a"),
               "deco": "wisps", "specks": pal("ff7a8a", "d8304a", "8e1f33", "4a2534"), "seed": 9511},
    "twin": {"body": pal("0d2c4a", "125a86", "1b86b8", "2fb0dd", "5fd0f0", "9fe8fb", "d6f7ff", "ffffff"),
             "body2": pal("2a1452", "45218a", "6230b8", "8150dc", "a27aee", "c4a6f7", "e6d8ff", "ffffff"),
             "deco": "twin", "specks": pal("ffffff", "c4a6f7", "9fe8fb", "6230b8"), "seed": 9521},
    "venom": {"body": pal("0d2410", "174a1a", "236e22", "39952e", "5cbd3c", "93dc52", "cff27a", "f6ffd0"),
              "deco": "bubbles", "specks": pal("f6ffd0", "cff27a", "93dc52", "39952e"), "seed": 9531},
    "powder": {"body": pal("100d0c", "231d1b", "38302c", "4e4540", "6b5f57", "c2321f", "ff6a2a", "ffd36a"),
               "deco": "sparks", "specks": pal("fff2b0", "ffd36a", "ffa83b", "c2321f"), "seed": 9541},
    "gold": {"body": pal("3a2408", "6a4410", "9c6a18", "c99424", "ecbd3e", "fbd96a", "fff0a8", "ffffff"),
             "deco": "glints", "specks": pal("ffffff", "fff0a8", "ecbd3e", "9c6a18"), "seed": 9551},
    "gale": {"body": pal("5c7d99", "7f9fba", "a3c1d8", "c4dcec", "deedf7", "eef7fc", "f8fcff", "ffffff"),
             "deco": "hooks", "specks": pal("ffffff", "eef7fc", "c4dcec", "a3c1d8"), "seed": 9561},
}


def shade(body: list, side: np.ndarray, s: np.ndarray, t: float) -> np.ndarray:
    """A body across a stroke, outside (+1) to inside (-1): the crest bright to white, flow lines racing
    along the middle, darker bands inside and a dark line at the inner edge."""
    rgb = np.empty(side.shape + (3,))
    rgb[:] = body[4]
    rgb[side < -0.18 + 0.1 * np.sin(s * 7.0 - t * 5.0)] = body[3]
    rgb[side < -0.5 + 0.08 * np.sin(s * 11.0 + t * 4.0)] = body[2]
    rgb[side < -0.72 + 0.06 * np.sin(s * 17.0 - t * 3.0)] = body[1]
    rgb[side > 0.12 + 0.08 * np.sin(s * 9.0 + t * 6.0)] = body[5]
    for off, fq, ph in ((0.32, 12.0, 0.0), (-0.05, 9.0, 1.4), (-0.38, 7.0, 2.6)):
        ln = np.abs(side - off - 0.05 * np.sin(s * fq * 0.6 - t * 8.0 + ph)) < 0.07
        dash = np.sin(s * fq - t * 14.0 + ph) > -0.2
        rgb[ln & dash] = body[6] if off > 0.0 else body[5]
    rgb[side > 0.56] = body[6]
    rgb[side > 0.8] = body[7]
    rgb[side < -0.86 + 0.07 * np.sin(s * 23.0 + t * 2.0)] = body[0]
    return rgb


def ring(img: np.ndarray, x: float, y: float, r: float, col: np.ndarray, fill=None) -> None:
    """A hollow ring (a bubble), frame coords."""
    d = np.sqrt((U - x) ** 2 + (V - y) ** 2)
    if fill is not None:
        m = d < r
        img[m, :3] = fill
        img[m, 3] = 255.0
    m = np.abs(d - r) < 1.1 * PX
    img[m, :3] = col
    img[m, 3] = 255.0


def glint(img: np.ndarray, x: float, y: float, size: float, col: np.ndarray, core: np.ndarray) -> None:
    """A four-pointed star."""
    du, dv = np.abs(U - x), np.abs(V - y)
    star = (du * dv < 0.0009 * size) & (du + dv < size)
    img[star, :3] = col
    img[star, 3] = 255.0
    c = du + dv < size * 0.35
    img[c, :3] = core
    img[c, 3] = 255.0


def decorate(el: dict, img: np.ndarray, pts: np.ndarray, w: np.ndarray, nrm: np.ndarray, s: np.ndarray, t: float,
             k: float, rng_items: list) -> None:
    """The element's decoration along a stroke's outside edge (k: how much of it is left, 0..1)."""
    body = el["body"]
    deco = el["deco"]
    n = len(s)
    if n < 4 or k <= 0.05:
        return
    for i, (sp, a, z) in enumerate(rng_items):
        j = int(np.clip((sp + 0.3 * t) % 1.0 * (n - 1), 1, n - 2))
        if w[j] < 2.5 * PX:
            continue
        p = pts[j] + nrm[j] * w[j] * 0.8
        if deco == "wisps":
            curl(img, p[0], p[1], (5.0 + 4.0 * z) * k, a + t * 3.0, 1.2 if i % 2 else -1.2, body[6] if i % 3 else body[1], 2)
        elif deco == "hooks":
            curl(img, p[0], p[1], (6.0 + 5.0 * z) * k, a + t * 2.0, -1.1, body[7], 2)
        elif deco == "bubbles":
            q = (t * 1.6 + z) % 1.0
            ring(img, p[0] + nrm[j][0] * q * 0.2, p[1] + nrm[j][1] * q * 0.2 - 0.12 * q, (0.025 + 0.03 * z) * k * (1.0 - 0.5 * q),
                 body[6], body[3] if i % 2 else None)
        elif deco == "sparks":
            q = (t * 2.0 + z) % 1.0
            put(img, p[0] + nrm[j][0] * q * 0.3, p[1] + nrm[j][1] * q * 0.3, el["specks"][min(int(q * 4), 3)], 2 if q < 0.5 else 1)
        elif deco == "glints":
            if (i + int(t * 8)) % 3 == 0:
                glint(img, p[0], p[1], (0.06 + 0.05 * z) * k, body[6], body[7])
        elif deco == "twin":
            pass


def crescent(el: dict, curl_s: float = 0.22, small: bool = False) -> list:
    """A slash: the element's crescent swept across, its head curling in, decorated along its crest, then
    breaking from the tail into round puffs that shrink away while specks fly off."""
    rng = np.random.default_rng(el["seed"])
    cx, cy, r0 = 0.0, 0.2, 0.6
    a0, sweep, ck = 0.9 * np.pi, np.pi, 1.4

    def path(s):
        ang = a0 + np.minimum(s, 1.0) * sweep + np.maximum(s - 1.0, 0.0) * ck * np.pi
        rad = r0 * (1.0 - 0.55 * (np.maximum(s - 1.0, 0.0) / max(curl_s, 1e-3)) ** 1.5)
        return np.stack([cx + np.cos(ang) * rad, cy + np.sin(ang) * rad], -1)
    items = [(rng.uniform(0.05, 0.95), rng.uniform(0, 6.3), rng.uniform(0, 1)) for _ in range(9)]
    specks = [(rng.uniform(0.1, 1.1), rng.uniform(0.12, 0.6), rng.uniform(0.04, 0.12)) for _ in range(16)]
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
            w = (0.02 + 0.13 * np.sin(np.pi * x ** 0.8) ** 0.6) * (0.75 if small else 1.0)
            w *= np.clip((s - tail) / 0.12, 0.15, 1.0) * np.clip((head - s) / 0.05, 0.25, 1.0)
            w = gobs(s, w, tail, head, brk)
            k, near, side, nrm, tan = stroke(pts, w)
            img = frame_rgba(shade(el["body"], side, s[k], t), near < 1.0)
            if el["deco"] == "twin":
                # the second stream wound round the first
                off = (0.55 * np.sin(s * 14.0 - t * 9.0))[:, None] * nrm * w[:, None]
                k2, near2, side2, _, _ = stroke(pts + off, w * 0.45)
                m2 = near2 < 1.0
                rgb2 = shade(el["body2"], side2, s[k2], t)
                img[m2, :3] = rgb2[m2]
                img[m2, 3] = 255.0
            decorate(el, img, pts, w, nrm, s, t, 1.0 - 0.5 * brk, items)
            if el["deco"] == "venom" or el["deco"] == "bubbles":
                # drips falling off the tail as it breaks
                for j in range(4):
                    q = (brk * 1.3 - j * 0.15)
                    if 0.0 < q < 1.0:
                        sp = tail + (head - tail) * (0.1 + 0.2 * j)
                        p = path(np.array([sp]))[0]
                        ring(img, p[0], p[1] + 0.35 * q * q, 0.03 * (1.0 - q * 0.5), el["body"][2], el["body"][4])

        for sp, t0, off in specks:
            tt = (t - t0) / 0.45
            if tt < 0.0 or tt > 1.0 or sp > head:
                continue
            p0 = path(np.array([min(sp, 1.0)]))[0]
            nn = (p0 - np.array([cx, cy])) / r0
            p = p0 + nn * (off + 0.18 * tt) + np.array([0.0, -0.25]) * tt * tt
            put(img, p[0], p[1], el["specks"][min(int(tt * 4), 3)], 2 if tt < 0.45 else 1)
        frames.append(img)
    return frames


def cloud(el: dict) -> list:
    """A burst of the element: lobes billowing out from a bright knot, light at the top through the body's
    bands to its dark rim underneath, the element's decoration on them, then shrinking away as they part."""
    rng = np.random.default_rng(el["seed"] + 1)
    body = el["body"]
    lob = [(rng.uniform(0, 2 * np.pi), rng.uniform(0.17, 0.3), rng.uniform(0.3, 0.5)) for _ in range(7)]
    items = [(rng.uniform(0, 6.3), rng.uniform(0.05, 0.35), rng.uniform(0.6, 1.0)) for _ in range(10)]
    frames = []
    for i in range(N):
        t = i / (N - 1)
        grow = min(t / 0.3, 1.0) ** 0.6
        gone = min(max(0.0, (t - 0.42) / 0.58), 1.0)
        img = np.zeros((FR, FR, 4))
        for j, (a, rr, dd) in enumerate(lob):
            aa = a + 0.5 * t
            dist = dd * (0.35 + 0.65 * grow) * (1.0 + 0.45 * gone)
            r = rr * (0.4 + 0.6 * grow) * (1.0 - gone) ** 1.1
            if r < 2.0 * PX:
                continue
            bb = body if j % 2 == 0 or "body2" not in el else el["body2"]
            cx, cy = np.cos(aa) * dist, np.sin(aa) * dist * 0.8 - 0.18 * gone
            d = np.sqrt((U - cx) ** 2 + (V - cy) ** 2)
            disc = d < r
            col = np.empty((FR, FR, 3))
            col[:] = bb[4]
            col[(V - cy) < -r * 0.25] = bb[5]
            col[(V - cy) > r * 0.25] = bb[3]
            col[(V - cy) > r * 0.6] = bb[2]
            col[d > r - 2.2 * PX] = bb[2]
            col[(d > r - 2.2 * PX) & ((V - cy) > r * 0.4)] = bb[0]
            col[(d > r - 2.2 * PX) & ((V - cy) < -r * 0.4)] = bb[6]
            img[disc, :3] = col[disc]
            img[disc, 3] = 255.0
            if r > 6.0 * PX:
                if el["deco"] in ("wisps", "hooks"):
                    curl(img, cx, cy, r / PX * 0.55, aa + t * 2.0, 1.1 if j % 2 else -1.1, bb[6] if el["deco"] == "hooks" else bb[1], 1)
                elif el["deco"] == "bubbles":
                    ring(img, cx + r * 0.3, cy - r * 0.3, r * 0.25, bb[6])
                elif el["deco"] == "glints" and j % 2 == 0:
                    glint(img, cx, cy - r * 0.2, r * 0.6, bb[6], bb[7])
        if t < 0.4:
            knot = RAD < 0.16 * grow * (1.0 - t)
            img[knot, :3] = body[7]
            img[knot, 3] = 255.0
        for a0, t0, sp in items:
            tt = (t - t0) / 0.5
            if 0.0 <= tt <= 1.0:
                p = np.array([np.cos(a0), np.sin(a0) * 0.7]) * (0.3 + 0.6 * tt * sp) + np.array([0.0, -0.2 * tt])
                if el["deco"] == "bubbles":
                    ring(img, p[0], p[1], 0.035 * (1.0 - 0.5 * tt), body[6])
                else:
                    put(img, p[0], p[1], el["specks"][min(int(tt * 4), 3)], 2 if tt < 0.5 else 1)
        frames.append(img)
    return frames


def trail(el: dict) -> Image.Image:
    """The element's strip, tiling along its length, 8 looping frames: the crest bright along the top, the
    body's bands below with flow lines racing along, a dark ragged edge underneath, and the decoration riding
    along the top (all of it advancing a whole spacing over the loop, so it loops)."""
    body = el["body"]
    out = np.zeros((TRAIL_H * TRAIL_FRAMES, TRAIL_W, 4))
    yy, xx = np.mgrid[0:TRAIL_H, 0:TRAIL_W]
    fx = xx / TRAIL_W
    rng = np.random.default_rng(el["seed"] + 2)
    items = [(c * 32 + rng.uniform(-5, 5), rng.uniform(0, 1), rng.uniform(0, 1)) for c in range(8)]
    for f in range(TRAIL_FRAMES):
        p = f / TRAIL_FRAMES
        ph = 2 * np.pi * p
        img = np.zeros((TRAIL_H, TRAIL_W, 4))
        top = 20.0 + 2.0 * np.sin(2 * np.pi * fx * 2 + ph) + 1.2 * np.sin(2 * np.pi * fx * 5 - ph * 2)
        bot = 50.0 + 2.5 * np.sin(2 * np.pi * fx * 4 - ph) + 1.6 * np.sin(2 * np.pi * fx * 11 + ph)
        body_m = (yy >= top) & (yy <= bot)
        depth = (yy - top) / np.maximum(bot - top, 1.0)
        rgb = np.empty((TRAIL_H, TRAIL_W, 3))
        rgb[:] = body[4]
        rgb[depth < 0.22] = body[5]
        rgb[depth > 0.42 + 0.08 * np.sin(2 * np.pi * fx * 5 - ph * 2)] = body[3]
        rgb[depth > 0.66 + 0.06 * np.sin(2 * np.pi * fx * 7 + ph)] = body[2]
        rgb[depth > 0.84 + 0.05 * np.sin(2 * np.pi * fx * 13 - ph)] = body[1]
        for j, (fr_, kq, m, dq) in enumerate(((0.12, 3, 1, 5), (0.36, 2, -1, 4), (0.56, 4, 2, 6))):
            yl = top + (bot - top) * fr_ + 1.4 * np.sin(2 * np.pi * fx * kq - ph * m + j)
            dash = np.sin(2 * np.pi * fx * dq - ph * 2 + j * 1.3) > -0.25
            rgb[(np.abs(yy - yl) < 0.75) & dash] = body[6] if fr_ < 0.3 else body[5]
        rgb[yy < top + 3.0] = body[6]
        rgb[yy < top + 1.4] = body[7]
        rgb[yy > bot - 1.8] = body[0]
        if el["deco"] == "twin":
            # the violet stream wound through the cyan one
            mid = top + (bot - top) * (0.5 + 0.3 * np.sin(2 * np.pi * fx * 3 - ph))
            band = np.abs(yy - mid) < 4.5
            b2 = el["body2"]
            rgb[band & body_m] = b2[4]
            rgb[band & body_m & (yy < mid - 2.0)] = b2[6]
            rgb[band & body_m & (yy > mid + 2.5)] = b2[2]
        img[..., :3] = rgb
        img[..., 3] = body_m * 255.0
        for j, (x0, off, z) in enumerate(items):
            x = (x0 + p * 32) % TRAIL_W
            y0 = 20.0 + 2.0 * np.sin(2 * np.pi * x / TRAIL_W * 2 + ph)
            if el["deco"] in ("wisps", "hooks"):
                r = 6.0 + 3.0 * z
                _trail_spiral(img, x + r, y0 - r + 2, r, np.pi * 0.5, -1.2 if el["deco"] == "hooks" else (1.2 if j % 2 else -1.2),
                              body[7] if el["deco"] == "hooks" else (body[6] if j % 3 else body[1]), 2)
            elif el["deco"] == "bubbles":
                q = (p + off) % 1.0
                r = 2.5 + 2.0 * z
                cy = y0 - 2.0 - 14.0 * q
                for wrap in (-TRAIL_W, 0, TRAIL_W):
                    d = np.sqrt((xx - x - wrap) ** 2 + (yy - cy) ** 2)
                    img[np.abs(d - r) < 0.8, :3] = body[6]
                    img[np.abs(d - r) < 0.8, 3] = 255.0
            elif el["deco"] in ("sparks", "glints"):
                q = (p + off) % 1.0
                c = el["specks"][min(int(q * 4), 3)]
                _trail_put(img, x + q * 14, y0 - 3.0 - 15.0 * q, c, 2 if q < 0.5 else 1)
                if el["deco"] == "glints" and q < 0.35:
                    for d in range(1, 4):
                        for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)):
                            _trail_put(img, x + dx, y0 - 3.0 + dy, body[7], 1)
            elif el["deco"] == "twin":
                q = (p + off) % 1.0
                _trail_put(img, x + q * 20, y0 - 2.0 - 12.0 * q, el["specks"][min(int(q * 4), 3)], 2 if q < 0.5 else 1)
        out[f * TRAIL_H:(f + 1) * TRAIL_H] = img
    out[out[..., 3] == 0, :3] = 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    names = sys.argv[1:] or list(ELEMENTS)
    for n in names:
        if n not in ELEMENTS:
            raise SystemExit("no element '%s' (have: %s)" % (n, ", ".join(ELEMENTS)))
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        el = ELEMENTS[name]
        for kind, frames in (("slash", crescent(el)), ("cloud", cloud(el))):
            img = sheet(frames)
            img.save(os.path.join(OUT, "flip_%s_%s.png" % (name, kind)))
            print("  wrote assets/textures/fx/flip_%s_%s.png %s" % (name, kind, img.size))
        img = trail(el)
        img.save(os.path.join(OUT, "%s_trail.png" % name))
        print("  wrote assets/textures/fx/%s_trail.png %s" % (name, img.size))
    os.makedirs(PREVIEW, exist_ok=True)
    imgs = []
    for name in ELEMENTS:
        for f in ("flip_%s_slash.png" % name, "flip_%s_cloud.png" % name, "%s_trail.png" % name):
            if os.path.exists(os.path.join(OUT, f)):
                imgs.append(Image.open(os.path.join(OUT, f)).convert("RGBA"))
    if imgs:
        w = sum(im.width for im in imgs) + 8 * len(imgs)
        h = max(im.height for im in imgs)
        canvas = Image.new("RGBA", (w, h), (110, 140, 100, 255))
        x = 0
        for im in imgs:
            canvas.alpha_composite(im, (x, 0))
            x += im.width + 8
        canvas.save(os.path.join(PREVIEW, "drawn.png"))
        print("  preview tools/dev/out/flipbook/drawn.png")


if __name__ == "__main__":
    main()
