"""Skill icons, ink and cel (2026-11-11; Zach picked this style from mock_skill_styles.py's five).

Each icon is one description of parts in 0..1 coordinates (y down), so it renders at any size: 32 px for the HUD's
skill bar, 48 px for the skill map, loadout and tooltips. A part is flat colour with one hard shadow along its lower
right, a one-pixel light edge up and left, and black ink round it and between parts; what glows (wind, fire, water)
is three hard bands, brightest at the core. Every icon sits on its tree's plate: an impact burst in the tree's colour,
gold-framed for an ultimate.

    py tools/texture_gen/gen_skill_icons.py            # review sheets -> tools/dev/out/iconreview/skills_<tree>.png
    py tools/texture_gen/gen_skill_icons.py --write    # also assets/textures/icons/skill_<id>_32.png and _48.png
                                                       # (nothing in the game reads those yet)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REVIEW = os.path.join(ROOT, "tools", "dev", "out", "iconreview")
ICONS = os.path.join(ROOT, "assets", "textures", "icons")
SS = 4


def hx(s):
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def ramp(*cols):
    """dark, shadow, base, light, glint"""
    return [hx(c) for c in cols]


INK = np.array([14, 12, 20], np.float32)
STEEL = ramp("27304f", "5a6890", "9aa8c6", "d6dfee", "ffffff")
IRON = ramp("16141c", "2c2a3a", "4a4860", "74728c", "a8a6c0")
GOLD = ramp("57300f", "a8661c", "e2a22e", "f8d660", "fff6c4")
WOOD = ramp("301a12", "5a321e", "8a5630", "b88248", "d8aa70")
LEATHER = ramp("1e1210", "3c221a", "5e3826", "845238", "a87050")
SKIN = ramp("673530", "b06a50", "e09a78", "f6c4a0", "ffe2c6")
CLOTH = ramp("5a1418", "921f22", "c83a2e", "ee6c4c", "ffa080")
WIND = ramp("123676", "2874d6", "68bdff", "c4eeff", "ffffff")
WATER = ramp("0c2a52", "1858a0", "2e96d8", "86d8f4", "e8fbff")
SPARK = ramp("7c3a10", "d8781c", "ffc93a", "fff0a0", "ffffff")
FIRE = ramp("7c1510", "c9331a", "f17c1c", "ffc93a", "fff4b4")
# each tree's plate: [deep, bright] (FX.TREE_FX's colours, darkened for the ground)
MOON = ramp("2a2a6a", "6a78d8", "aebcff", "e4eaff", "ffffff")
PETAL = ramp("5a1840", "c04a88", "ff8cc0", "ffd0e4", "ffffff")
SMOKE = ramp("2a2a34", "55566a", "8a8c9e", "bdbfcc", "e8e9f0")
STONE = ramp("282427", "4d4743", "7a7065", "ab9e8c", "d6cab6")
WRAP = ramp("1a1024", "3a2452", "5c3c80", "8a66b0", "b89ad8")
SHADE = ramp("0c0a12", "1a1826", "2c2a3c", "46445c", "6a6884")
TREES = {
    "sword": ("123262", "4db8ff"),
    "katana": ("3a1c48", "ff9ecc"),
    "axe": ("4a1c0a", "ff8026"),
    "pistol": ("3e2c10", "ffbf40"),
}


class Icon:
    def __init__(self, n):
        self.n = n
        self.rgb = np.zeros((n, n, 3), np.float32)
        self.a = np.zeros((n, n), bool)

    # ---- silhouettes -> a boolean mask at this size
    def _mask(self, draw):
        m = Image.new("L", (self.n * SS, self.n * SS), 0)
        draw(ImageDraw.Draw(m), self.n * SS)
        return np.asarray(m, np.float32).reshape(self.n, SS, self.n, SS).mean((1, 3)) >= 127.0

    def poly(self, pts):
        return self._mask(lambda d, k: d.polygon([(x * k, y * k) for x, y in pts], fill=255))

    def circle(self, c, r):
        return self._mask(lambda d, k: d.ellipse([(c[0] - r) * k, (c[1] - r) * k, (c[0] + r) * k, (c[1] + r) * k], fill=255))

    def capsule(self, a, b, w):
        def dr(d, k):
            d.line([a[0] * k, a[1] * k, b[0] * k, b[1] * k], fill=255, width=max(1, int(round(w * k))))
            for p in (a, b):
                d.ellipse([(p[0] - w / 2) * k, (p[1] - w / 2) * k, (p[0] + w / 2) * k, (p[1] + w / 2) * k], fill=255)
        return self._mask(dr)

    def path(self, pts, w0, w1=None):
        """A tube along the points, tapering from w0 to w1."""
        w1 = w0 if w1 is None else w1
        m = np.zeros((self.n, self.n), bool)
        for i in range(len(pts) - 1):
            m |= self.capsule(pts[i], pts[i + 1], w0 + (w1 - w0) * i / max(len(pts) - 2, 1))
        return m

    def star(self, c, r, points=8, inner=0.42, turn=0.0):
        pts = []
        for i in range(points * 2):
            a = turn + math.pi * i / points
            rr = r if i % 2 == 0 else r * inner
            pts.append((c[0] + math.cos(a) * rr, c[1] + math.sin(a) * rr))
        return self.poly(pts)

    def lens(self, a, b, w):
        """A cut mark: a sliver from a to b, w wide at its middle."""
        dx, dy = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(dx, dy)
        px, py = -dy / ln * w / 2, dx / ln * w / 2
        left = [(a[0] + dx * t + px * math.sin(math.pi * t), a[1] + dy * t + py * math.sin(math.pi * t)) for t in np.linspace(0, 1, 9)]
        right = [(a[0] + dx * t - px * math.sin(math.pi * t), a[1] + dy * t - py * math.sin(math.pi * t)) for t in np.linspace(1, 0, 9)]
        return self.poly(left + right)

    # ---- painting
    def _shift(self, m, dx, dy):
        out = np.zeros_like(m)
        n = self.n
        out[max(dy, 0):n + min(dy, 0), max(dx, 0):n + min(dx, 0)] = m[max(-dy, 0):n + min(-dy, 0), max(-dx, 0):n + min(-dx, 0)]
        return out

    def _ink_round(self, mask):
        ring = ndimage.binary_dilation(mask) & ~mask & self.a
        self.rgb[ring] = INK

    def part(self, mask, mat, metal=False, shadow=0.07):
        """A solid: base colour, its lower-right rim in shadow, a light edge up and left, ink where it overlaps."""
        if not mask.any():
            return
        self._ink_round(mask)
        k = max(1, int(round(self.n * shadow)))
        self.rgb[mask] = mat[2]
        self.rgb[mask & ~self._shift(mask, -k, -k)] = mat[1]
        self.rgb[mask & ~self._shift(mask, 1, 1)] = mat[4] if metal else mat[3]
        self.a |= mask

    def glow(self, mask, mat, depth=0.10, ink=False):
        """Something that glows: three hard bands, brightest at the core."""
        if not mask.any():
            return
        if ink:
            self._ink_round(mask)
        t = np.clip(ndimage.distance_transform_edt(mask) / max(depth * self.n, 1.0), 0.0, 1.0)
        self.rgb[mask] = mat[1]
        self.rgb[mask & (t > 0.34)] = mat[3]
        self.rgb[mask & (t > 0.85)] = mat[4]
        self.a |= mask

    def flat(self, mask, col):
        self.rgb[mask] = col
        self.a |= mask

    def finish(self):
        rgb, a = self.rgb.copy(), self.a.copy()
        grow = ndimage.binary_dilation(a, iterations=2 if self.n > 32 else 1)
        rgb[grow & ~a] = INK
        out = np.zeros((self.n, self.n, 4), np.uint8)
        out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        out[..., 3] = grow * 255
        return Image.fromarray(out, "RGBA")


def plate(n, tree, ult=False):
    """The tree's ground: an impact burst of rays in its colour; inked edge with a bright inner line (gold for an ult)."""
    deep, mid = hx(TREES[tree][0]), hx(TREES[tree][1])
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    ang = np.arctan2(yy - n * 0.52, xx - n * 0.46)
    ray = (np.floor(ang / (2 * np.pi / 18.0)) % 2) == 0
    out = np.zeros((n, n, 4), np.uint8)
    out[..., 3] = 255
    out[..., :3] = np.clip(np.where(ray[..., None], deep * 1.25 + mid * 0.12, deep * 0.85), 0, 255)
    line = hx("f8d660") if ult else mid
    out[[0, -1], :, :3] = hx("7a4c14") if ult else INK
    out[:, [0, -1], :3] = hx("7a4c14") if ult else INK
    out[1, 1:-1, :3] = out[1:-1, 1, :3] = np.clip(line, 0, 255)
    out[-2, 1:-1, :3] = out[1:-1, -2, :3] = np.clip(line * (0.8 if ult else 0.45), 0, 255)
    return Image.fromarray(out, "RGBA")


# ----------------------------------------------------------------------------------------------------------------
# Shared pieces
# ----------------------------------------------------------------------------------------------------------------
def cutlass(ic, hilt, tip, bend=0.09, w=0.12, guard=True):
    """A cutlass from the pommel end `hilt` to its `tip`: a curved single-edged blade widening toward the point, a brass
    crossguard and knuckle bow, a leather grip. `bend` bows the blade to its right-hand side (negative: the other)."""
    dx, dy = tip[0] - hilt[0], tip[1] - hilt[1]
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux
    b0 = (hilt[0] + ux * ln * 0.24, hilt[1] + uy * ln * 0.24)
    ctrl = ((b0[0] + tip[0]) / 2 + px * bend, (b0[1] + tip[1]) / 2 + py * bend)
    left, right = [], []
    for t in np.linspace(0.0, 1.0, 12):
        cx = (1 - t) ** 2 * b0[0] + 2 * (1 - t) * t * ctrl[0] + t * t * tip[0]
        cy = (1 - t) ** 2 * b0[1] + 2 * (1 - t) * t * ctrl[1] + t * t * tip[1]
        tx = 2 * (1 - t) * (ctrl[0] - b0[0]) + 2 * t * (tip[0] - ctrl[0])
        ty = 2 * (1 - t) * (ctrl[1] - b0[1]) + 2 * t * (tip[1] - ctrl[1])
        tl = math.hypot(tx, ty)
        nx, ny = -ty / tl, tx / tl
        ww = w * (0.78 + 0.42 * t) * (1.0 if t < 0.78 else max(0.0, (1.0 - t) / 0.22) ** 0.7)
        left.append((cx + nx * ww * 0.5, cy + ny * ww * 0.5))
        right.append((cx - nx * ww * 0.5, cy - ny * ww * 0.5))
    ic.part(ic.poly(left + right[::-1]), STEEL, metal=True, shadow=0.045)
    ic.part(ic.capsule(hilt, b0, w * 0.62), LEATHER, shadow=0.04)
    if guard:
        g = w * 1.25
        ic.part(ic.capsule((b0[0] - px * g, b0[1] - py * g), (b0[0] + px * g, b0[1] + py * g), w * 0.55), GOLD, metal=True, shadow=0.035)
        sgn = 1.0 if bend >= 0 else -1.0
        bow = [(b0[0] + px * g * sgn, b0[1] + py * g * sgn), ((hilt[0] + b0[0]) / 2 + px * g * 1.25 * sgn, (hilt[1] + b0[1]) / 2 + py * g * 1.25 * sgn),
            (hilt[0] + px * g * 0.35 * sgn, hilt[1] + py * g * 0.35 * sgn)]
        ic.part(ic.path(bow, w * 0.36), GOLD, metal=True, shadow=0.03)
    ic.part(ic.circle(hilt, w * 0.5), GOLD, metal=True, shadow=0.035)


# ----------------------------------------------------------------------------------------------------------------
# Sword (the cutlass)
# ----------------------------------------------------------------------------------------------------------------
def flying_slash(ic):
    # "A cut so fast it flies: a crescent of wind": the crescent leaving the blade that threw it, two wisps behind it
    ic.glow(ic.circle((0.57, 0.43), 0.43) & ~ic.circle((0.39, 0.61), 0.45), WIND, depth=0.085)
    ic.glow(ic.lens((0.60, 0.95), (0.76, 0.84), 0.05), WIND, depth=0.03)
    ic.glow(ic.lens((0.80, 0.86), (0.94, 0.72), 0.05), WIND, depth=0.03)
    cutlass(ic, (0.10, 0.90), (0.60, 0.40), bend=0.07)


def riposte(ic):
    # "the first blow is turned aside and answered": their dark blade stopped on yours, the spark where they meet
    ic.part(ic.poly([(0.97, 0.06), (0.99, 0.18), (0.50, 0.56), (0.42, 0.50)]), IRON, metal=True, shadow=0.04)
    cutlass(ic, (0.14, 0.93), (0.56, 0.08), bend=-0.045, w=0.105)
    ic.glow(ic.star((0.50, 0.47), 0.25, 8, 0.36, 0.2), SPARK, depth=0.07, ink=True)


def swordfish(ic):
    # "Five lightning thrusts driving forward": the blade thrust home, four after-images of the point beside it
    for y, x0, x1 in ((0.16, 0.34, 0.80), (0.31, 0.44, 0.92), (0.69, 0.44, 0.92), (0.84, 0.34, 0.80)):
        ic.glow(ic.poly([(x0, y - 0.035), (x1, y), (x0, y + 0.035)]), WIND, depth=0.035)
    ic.glow(ic.star((0.90, 0.50), 0.13, 6, 0.4, 0.0), SPARK, depth=0.05)
    cutlass(ic, (0.07, 0.50), (0.88, 0.50), bend=-0.035, w=0.125)


def kraken_wake(ic):
    # "Flash between up to six enemies ... every one of them is torn open at once": six cuts through one point
    for ang in (0.0, 60.0, 120.0):
        a = math.radians(ang + 15.0)
        ic.glow(ic.lens((0.5 - math.cos(a) * 0.47, 0.5 - math.sin(a) * 0.47), (0.5 + math.cos(a) * 0.47, 0.5 + math.sin(a) * 0.47), 0.13), WIND, depth=0.05)
    ic.glow(ic.star((0.50, 0.50), 0.17, 6, 0.45, math.radians(45.0)), SPARK, depth=0.06)
    cutlass(ic, (0.20, 0.86), (0.74, 0.20), bend=0.06, w=0.10)


def undertow(ic):
    # "Plant the blade: a whirlpool drags every foe in": the whirlpool's arms winding in to the blade stood in its eye
    for turn in (0.0, 120.0, 240.0):
        pts = []
        for i in range(9):
            t = i / 8.0
            a = math.radians(turn + 250.0 * t)
            r = 0.46 * (1.0 - 0.72 * t)
            pts.append((0.5 + math.cos(a) * r, 0.58 + math.sin(a) * r * 0.62))
        ic.glow(ic.path(pts, 0.035, 0.12), WATER, depth=0.05)
    ic.glow(ic.circle((0.50, 0.60), 0.085), WATER, depth=0.05)
    cutlass(ic, (0.50, 0.04), (0.50, 0.66), bend=0.035, w=0.115)


# ----------------------------------------------------------------------------------------------------------------
# More shared pieces
# ----------------------------------------------------------------------------------------------------------------
class Frame:
    """A piece's own axes: `u` along it from `origin` toward `angle` (degrees, 0 = right, 90 = down), `v` across it
    (to its right-hand side, or the left with flip), both in units of `size`."""
    def __init__(self, origin, angle, size, flip=False):
        self.o, self.s = origin, size
        a = math.radians(angle)
        self.ux, self.uy = math.cos(a), math.sin(a)
        self.f = -1.0 if flip else 1.0

    def pt(self, u, v):
        return (self.o[0] + (u * self.ux - v * self.uy * self.f) * self.s, self.o[1] + (u * self.uy + v * self.ux * self.f) * self.s)

    def pts(self, uv):
        return [self.pt(u, v) for u, v in uv]


def arc(c, r, a0, a1, squash=1.0, steps=10):
    return [(c[0] + math.cos(math.radians(a0 + (a1 - a0) * i / steps)) * r, c[1] + math.sin(math.radians(a0 + (a1 - a0) * i / steps)) * r * squash)
        for i in range(steps + 1)]


def katana(ic, hilt, tip, bend=0.11, w=0.07, sheathed=False, drawn=0.0, cord=None):
    """A katana from the end of its grip to its point (or its sheath's end): a slim blade with a real curve, bowed
    `bend` to its right-hand side (negative: its left) with the edge on the outside of the curve, a single edge
    running up to a slanted point on the back, a round guard (the tsuba) seen at an angle, a small collar, and a long
    wrapped grip with a flat cap, no pommel. `sheathed`: in its curved lacquered sheath (gold mouth and end, a cord in
    `cord`'s colours), with `drawn` of the blade's length showing between guard and mouth."""
    mx, my = (hilt[0] + tip[0]) / 2, (hilt[1] + tip[1]) / 2
    dx, dy = tip[0] - hilt[0], tip[1] - hilt[1]
    ln = math.hypot(dx, dy)
    ctrl = (mx - dy / ln * bend * 2.0, my + dx / ln * bend * 2.0)
    sgn = 1.0 if bend >= 0 else -1.0

    def at(t):
        c = ((1 - t) ** 2 * hilt[0] + 2 * (1 - t) * t * ctrl[0] + t * t * tip[0], (1 - t) ** 2 * hilt[1] + 2 * (1 - t) * t * ctrl[1] + t * t * tip[1])
        tx = 2 * (1 - t) * (ctrl[0] - hilt[0]) + 2 * t * (tip[0] - ctrl[0])
        ty = 2 * (1 - t) * (ctrl[1] - hilt[1]) + 2 * t * (tip[1] - ctrl[1])
        tl = math.hypot(tx, ty)
        return c, (tx / tl, ty / tl), (-ty / tl * sgn, tx / tl * sgn)   # the point, along, toward the edge

    def strip(t0, t1, edge_w, back_w, point=False, steps=12):
        e, b = [], []
        for k in range(steps + 1):
            t = t0 + (t1 - t0) * k / steps
            c, _al, n = at(t)
            ew = edge_w
            if point and k / steps > 0.84:
                ew = edge_w - (edge_w + back_w) * (k / steps - 0.84) / 0.16
            e.append((c[0] + n[0] * ew, c[1] + n[1] * ew))
            b.append((c[0] - n[0] * back_w, c[1] - n[1] * back_w))
        return e + b[::-1]

    def band(t, half, thick, mat, metal=True):
        c, _al, n = at(t)
        ic.part(ic.capsule((c[0] - n[0] * half, c[1] - n[1] * half), (c[0] + n[0] * half, c[1] + n[1] * half), thick), mat, metal=metal, shadow=0.025)

    tg = 0.30   # where the grip ends and the guard sits
    if sheathed:
        ts = tg + 0.035 + drawn
        if drawn > 0.0:
            ic.part(ic.poly(strip(tg, ts + 0.02, w * 0.5, w * 0.5)), STEEL, metal=True, shadow=0.03)
        ic.part(ic.poly(strip(ts, 1.0, w * 0.78, w * 0.78)) | ic.circle(at(1.0)[0], w * 0.78), SHADE, metal=True, shadow=0.04)
        band(ts + 0.012, w * 0.80, w * 0.5, IRON)   # (the mouth: dark, so it isn't read as a second guard)
        ic.part(ic.circle(at(1.0)[0], w * 0.84) | ic.poly(strip(0.95, 1.0, w * 0.84, w * 0.84, steps=3)), GOLD, metal=True, shadow=0.03)
        band(ts + 0.16, w * 0.86, w * 0.72, cord if cord is not None else CLOTH, metal=False)
    else:
        ic.part(ic.poly(strip(tg, 1.0, w * 0.5, w * 0.5, point=True)), STEEL, metal=True, shadow=0.03)
        band(tg + 0.045, w * 0.5, w * 0.6, GOLD)
    # the grip: dark wrap with the pale diamonds of the ray skin showing through, a flat cap on its end
    ic.part(ic.poly(strip(0.0, tg, w * 0.6, w * 0.6, steps=6)), WRAP, shadow=0.03)
    for t in (0.055, 0.125, 0.195, 0.265):
        c, al, n = at(t)
        d = w * 0.34
        ic.flat(ic.poly([(c[0] - al[0] * d, c[1] - al[1] * d), (c[0] + n[0] * d, c[1] + n[1] * d), (c[0] + al[0] * d, c[1] + al[1] * d), (c[0] - n[0] * d, c[1] - n[1] * d)]), hx("efe2c4"))
    band(0.0, w * 0.52, w * 0.55, GOLD)
    # the guard: a disc seen at an angle, so an oval across the blade (not a bar)
    c, al, n = at(tg)
    ic.part(ic.poly([(c[0] + n[0] * math.cos(a) * w * 1.75 + al[0] * math.sin(a) * w * 0.72, c[1] + n[1] * math.cos(a) * w * 1.75 + al[1] * math.sin(a) * w * 0.72)
        for a in np.linspace(0, 2 * math.pi, 16, endpoint=False)]), GOLD, metal=True, shadow=0.035)
    ic.flat(ic.circle(c, w * 0.42), GOLD[1])


def axe(ic, butt, angle, size, flip=False, mat=STEEL):
    """A bearded axe: the haft from `butt` along `angle`, the head near its far end with the edge to its right
    (left with flip)."""
    f = Frame(butt, angle, size, flip)
    ic.part(ic.capsule(f.pt(0, 0), f.pt(1.0, 0), 0.075 * size / 0.8), WOOD, shadow=0.035)
    ic.part(ic.capsule(f.pt(0.04, 0), f.pt(0.20, 0), 0.095 * size / 0.8), LEATHER, shadow=0.03)
    ic.part(ic.poly(f.pts([(0.72, 0.03), (0.96, 0.03), (0.94, -0.13), (0.76, -0.13)])), IRON, metal=True, shadow=0.03)
    ic.part(ic.poly(f.pts([(0.66, -0.04), (1.00, -0.04), (1.10, 0.20), (1.04, 0.40), (0.84, 0.47), (0.62, 0.40), (0.56, 0.26), (0.72, 0.16)])), mat, metal=True, shadow=0.055)
    ic.part(ic.circle(f.pt(0, 0), 0.055 * size / 0.8), GOLD, metal=True, shadow=0.03)


def pistol(ic, at, angle, size, flip=False):
    """A flintlock: `at` is the back of the lock, the barrel runs along `angle`; the grip hangs to its right (left with flip)."""
    f = Frame(at, angle, size, flip)
    ic.part(ic.poly(f.pts([(-0.02, -0.02), (0.58, -0.02), (0.58, 0.11), (0.24, 0.13), (0.16, 0.22), (0.10, 0.52), (-0.10, 0.52), (-0.05, 0.20), (-0.12, 0.06)])), WOOD, shadow=0.05)
    ic.part(ic.capsule(f.pt(0.10, -0.08), f.pt(1.0, -0.08), 0.13 * size), STEEL, metal=True, shadow=0.04)
    ic.part(ic.capsule(f.pt(0.93, -0.08), f.pt(1.0, -0.08), 0.17 * size), GOLD, metal=True, shadow=0.03)
    ic.part(ic.poly(f.pts([(0.06, -0.14), (0.16, -0.30), (0.25, -0.26), (0.22, -0.13)])), IRON, metal=True, shadow=0.03)
    ic.part(ic.path(f.pts([(0.25, 0.13), (0.31, 0.25), (0.42, 0.23), (0.44, 0.12)]), 0.04 * size), GOLD, metal=True, shadow=0.02)
    ic.part(ic.circle(f.pt(0.0, 0.52), 0.075 * size), GOLD, metal=True, shadow=0.03)


def bust(ic, c, s, mat):
    """Someone seen from the shoulders up."""
    ic.part(ic.poly([(c[0] - s * 0.62, c[1] + s * 0.95), (c[0] - s * 0.50, c[1] + s * 0.30), (c[0], c[1] + s * 0.12), (c[0] + s * 0.50, c[1] + s * 0.30),
        (c[0] + s * 0.62, c[1] + s * 0.95)]), mat, shadow=0.05)
    ic.part(ic.circle((c[0], c[1] - s * 0.18), s * 0.36), mat, shadow=0.05)


def wind_blade(ic, foot, lean, mat=MOON, h=0.86, depth=0.07):
    """A standing blade of wind on the ground at `foot` (x), leaning right (+1) or left (-1)."""
    cx = foot - lean * 0.34
    m = ic.circle((cx, 0.56), 0.60) & ~ic.circle((cx - lean * 0.17, 0.62), 0.60) & ic.poly([(0, 0.92 - h), (1, 0.92 - h), (1, 0.92), (0, 0.92)])
    ic.glow(m, mat, depth=depth)


# ----------------------------------------------------------------------------------------------------------------
# Katana
# ----------------------------------------------------------------------------------------------------------------
def tiger_rush(ic):
    # "Dash straight through the enemy line with a single drawing cut": one long cut across, the dash's streaks behind
    for y, x1 in ((0.20, 0.50), (0.32, 0.36), (0.74, 0.40), (0.86, 0.56)):
        ic.glow(ic.lens((0.03, y), (x1, y), 0.045), MOON, depth=0.03)
    ic.glow(ic.lens((0.02, 0.56), (0.99, 0.44), 0.20), MOON, depth=0.07)
    katana(ic, (0.06, 0.80), (0.94, 0.30), bend=-0.10)


def iai_counter(ic):
    # "Slip the blade home and wait, hand on the hilt": the sheathed sword, the hand on its grip, the first glint of steel
    katana(ic, (0.05, 0.36), (0.96, 0.74), bend=-0.13, w=0.085, sheathed=True, drawn=0.05, cord=PETAL)
    ic.part(ic.poly([(0.07, 0.38), (0.13, 0.18), (0.30, 0.14), (0.36, 0.30), (0.30, 0.46), (0.14, 0.50)]), SKIN, shadow=0.06)
    for x in (0.17, 0.235, 0.30):
        ic.flat(ic.capsule((x, 0.20), (x - 0.02, 0.31), 0.022), hx("8a4a3a"))
    ic.glow(ic.star((0.47, 0.30), 0.19, 4, 0.22, 0.0), MOON, depth=0.05, ink=True)


def wind_sever(ic):
    # "a towering blade of wind tearing along the ground": the blade of wind standing over the ground it tears up
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.90), (1.0, 0.90), (1.0, 1.0)]), STONE, shadow=0.03)
    wind_blade(ic, 0.62, 1.0, h=0.90, depth=0.085)
    for pts in ([(0.10, 0.90), (0.18, 0.74), (0.26, 0.90)], [(0.80, 0.90), (0.90, 0.78), (0.95, 0.90)]):
        ic.part(ic.poly(pts), STONE, shadow=0.04)
    katana(ic, (0.03, 0.74), (0.46, 0.30), bend=0.07, w=0.06)


def twin_waves(ic):
    # "two blades of wind sent out from either side, crossing ahead of you"
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.92), (1.0, 0.92), (1.0, 1.0)]), STONE, shadow=0.03)
    wind_blade(ic, 0.66, 1.0, MOON, h=0.84, depth=0.07)
    wind_blade(ic, 0.34, -1.0, PETAL, h=0.84, depth=0.07)
    ic.glow(ic.star((0.50, 0.50), 0.13, 4, 0.3, 0.78), SPARK, depth=0.05)


def side_step(ic):
    # "meets empty air. You're already out at their side, drawing across them": where you stood, the step round, the cut
    bust(ic, (0.27, 0.42), 0.40, [hx(c) for c in ("2a2a5a", "3c3c7c", "5454a0", "7474c4", "9a9ae0")])
    ic.glow(ic.path(arc((0.42, 0.50), 0.42, 150.0, 20.0, 0.72), 0.03, 0.11), MOON, depth=0.045)
    katana(ic, (0.52, 0.96), (0.96, 0.26), bend=0.09, w=0.065)
    ic.glow(ic.lens((0.52, 0.30), (0.98, 0.62), 0.10), PETAL, depth=0.04)


def phantom_step(ic):
    # "Blink behind the nearest enemy and cut them down from behind": them, dark, and the cut opening behind them
    ic.glow(ic.lens((0.98, 0.04), (0.20, 0.90), 0.26), PETAL, depth=0.08)
    bust(ic, (0.40, 0.52), 0.52, SHADE)
    katana(ic, (0.98, 0.60), (0.60, 0.06), bend=-0.08, w=0.065)
    for x, y in ((0.08, 0.16), (0.16, 0.30), (0.05, 0.40)):
        ic.glow(ic.star((x, y), 0.055, 4, 0.4, 0.78), MOON, depth=0.03)


def petal_storm(ic):
    # "Draw and sheathe in a single motion ... cut a dozen times at once": the cuts, the blade, the petals falling round it
    for ang in (20.0, 80.0, 140.0):
        a = math.radians(ang)
        ic.glow(ic.lens((0.5 - math.cos(a) * 0.48, 0.5 - math.sin(a) * 0.48), (0.5 + math.cos(a) * 0.48, 0.5 + math.sin(a) * 0.48), 0.07), MOON, depth=0.03)
    katana(ic, (0.16, 0.88), (0.84, 0.12), bend=0.10)
    for i in range(7):
        a = math.radians(i * 360.0 / 7.0 + 10.0)
        c = (0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.36)
        t = a + 1.1
        ic.glow(ic.lens((c[0] - math.cos(t) * 0.10, c[1] - math.sin(t) * 0.10), (c[0] + math.cos(t) * 0.10, c[1] + math.sin(t) * 0.10), 0.11), PETAL, depth=0.05, ink=True)


def moonlit_severance(ic):
    # "one draw along a 14 m line: the world goes pale ... everything on the line splits": the moon itself cut in two
    cut = Frame((0.5, 0.5), -24.0, 1.0)
    upper = ic.poly(cut.pts([(-1, -1), (1, -1), (1, -0.035), (-1, -0.035)]))
    lower = ic.poly(cut.pts([(-1, 0.035), (1, 0.035), (1, 1), (-1, 1)]))
    ic.glow(ic.circle(cut.pt(0.09, -0.035), 0.33) & upper, MOON, depth=0.15, ink=True)
    ic.glow(ic.circle(cut.pt(-0.09, 0.035), 0.33) & lower, MOON, depth=0.15, ink=True)
    ic.glow(ic.lens(cut.pt(-0.52, 0.0), cut.pt(0.52, 0.0), 0.075), PETAL, depth=0.03)
    katana(ic, (0.03, 0.97), (0.46, 0.70), bend=0.06, w=0.06)


# ----------------------------------------------------------------------------------------------------------------
# Axe
# ----------------------------------------------------------------------------------------------------------------
def axe_throw(ic):
    # "Hurl your axe spinning ahead ... and comes back to your hand": the axe mid-spin, the rings it cuts in the air
    ic.glow(ic.path(arc((0.50, 0.50), 0.44, 200.0, 330.0), 0.03, 0.10), FIRE, depth=0.04)
    ic.glow(ic.path(arc((0.50, 0.50), 0.44, 20.0, 150.0), 0.03, 0.10), FIRE, depth=0.04)
    axe(ic, (0.22, 0.80), -48.0, 0.74)


def earthsplitter(ic):
    # "drive the axe into the ground: a crack tears 9 m ahead": the axe buried, the crack running on, glowing
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.70), (0.30, 0.66), (0.44, 0.72), (0.60, 0.64), (1.0, 0.70), (1.0, 1.0)]), STONE, shadow=0.05)
    crack = [(0.40, 0.70), (0.52, 0.80), (0.62, 0.76), (0.74, 0.88), (0.86, 0.84), (0.99, 0.94)]
    ic.glow(ic.path(crack, 0.10, 0.05), FIRE, depth=0.035)
    ic.flat(ic.path(crack, 0.03, 0.015), INK)
    for pts in ([(0.66, 0.60), (0.74, 0.42), (0.82, 0.60)], [(0.86, 0.62), (0.94, 0.50), (0.97, 0.66)], [(0.52, 0.56), (0.57, 0.44), (0.62, 0.58)]):
        ic.part(ic.poly(pts), STONE, shadow=0.04)
    axe(ic, (0.06, 0.08), 52.0, 0.74)


def berserk(ic):
    # "Roar": the roaring face, the rage burning off it
    ic.glow(ic.poly([(0.06, 0.96), (0.02, 0.60), (0.14, 0.66), (0.10, 0.34), (0.26, 0.44), (0.30, 0.12), (0.44, 0.28), (0.52, 0.02), (0.60, 0.28),
        (0.74, 0.10), (0.76, 0.42), (0.92, 0.32), (0.88, 0.64), (0.98, 0.60), (0.94, 0.96)]), FIRE, depth=0.13)
    ic.part(ic.poly([(0.26, 0.50), (0.34, 0.34), (0.66, 0.34), (0.74, 0.50), (0.72, 0.80), (0.60, 0.96), (0.40, 0.96), (0.28, 0.80)]), SKIN, shadow=0.07)
    ic.flat(ic.poly([(0.30, 0.44), (0.47, 0.54), (0.46, 0.60), (0.30, 0.52)]) | ic.poly([(0.70, 0.44), (0.53, 0.54), (0.54, 0.60), (0.70, 0.52)]), INK)
    ic.flat(ic.poly([(0.36, 0.52), (0.44, 0.565), (0.36, 0.56)]) | ic.poly([(0.64, 0.52), (0.56, 0.565), (0.64, 0.56)]), hx("fff4b4"))
    ic.flat(ic.poly([(0.38, 0.70), (0.62, 0.70), (0.66, 0.90), (0.34, 0.90)]), INK)
    ic.flat(ic.poly([(0.40, 0.71), (0.60, 0.71), (0.59, 0.76), (0.41, 0.76)]) | ic.poly([(0.38, 0.85), (0.62, 0.85), (0.63, 0.89), (0.37, 0.89)]), hx("fff8e8"))


def maelstrom(ic):
    # "Become a whirlwind of steel": two axes wheeling round one point, the wind they drag with them
    for turn in (0.0, 180.0):
        ic.glow(ic.path(arc((0.50, 0.50), 0.45, turn + 100.0, turn + 250.0), 0.025, 0.12), FIRE, depth=0.045)
    axe(ic, (0.50, 0.50), -40.0, 0.46)
    axe(ic, (0.50, 0.50), 140.0, 0.46)
    ic.part(ic.circle((0.50, 0.50), 0.07), GOLD, metal=True, shadow=0.03)


def executioners_moon(ic):
    # "one chop: a huge blow ... and a fissure of fire ten paces down the line": the axe against its moon, the fire below
    ic.glow(ic.circle((0.58, 0.40), 0.36) & ~ic.circle((0.74, 0.30), 0.32), MOON, depth=0.08)
    ic.glow(ic.poly([(0.0, 1.0), (0.04, 0.86), (0.14, 0.92), (0.22, 0.78), (0.34, 0.90), (0.46, 0.74), (0.56, 0.90), (0.68, 0.78), (0.78, 0.92),
        (0.88, 0.80), (1.0, 0.90), (1.0, 1.0)]), FIRE, depth=0.07)
    axe(ic, (0.92, 0.08), 132.0, 0.80, flip=True)


# ----------------------------------------------------------------------------------------------------------------
# Pistol
# ----------------------------------------------------------------------------------------------------------------
def bullet_storm(ic):
    # "Fan the hammer: seven shots swept across everything in front of you"
    m = (0.60, 0.50)
    for ang in (-52.0, -34.0, -17.0, 0.0, 17.0, 34.0, 52.0):
        a = math.radians(ang)
        ic.glow(ic.lens((m[0] + math.cos(a) * 0.10, m[1] + math.sin(a) * 0.10), (m[0] + math.cos(a) * 0.42, m[1] + math.sin(a) * 0.42), 0.06), SPARK, depth=0.03)
    ic.glow(ic.star(m, 0.17, 7, 0.45, 0.2), FIRE, depth=0.06)
    pistol(ic, (0.06, 0.56), -6.0, 0.52)


def deadeye(ic):
    # "one shot that punches through every enemy in a line": the sights, the shot gone clean through them
    ring = ic.circle((0.52, 0.50), 0.36) & ~ic.circle((0.52, 0.50), 0.27)
    ticks = ic.capsule((0.52, 0.06), (0.52, 0.26), 0.06) | ic.capsule((0.52, 0.74), (0.52, 0.94), 0.06) | ic.capsule((0.08, 0.50), (0.26, 0.50), 0.06)
    ic.part(ring | ticks, GOLD, metal=True, shadow=0.035)
    ic.glow(ic.lens((0.02, 0.50), (0.90, 0.50), 0.12), SPARK, depth=0.045)
    ic.part(ic.poly([(0.80, 0.42), (0.92, 0.42), (0.99, 0.50), (0.92, 0.58), (0.80, 0.58)]), STEEL, metal=True, shadow=0.04)
    ic.flat(ic.circle((0.52, 0.50), 0.045), hx("c9331a"))


def smoke_bomb(ic):
    # "Throw down a smoke bomb": the bomb, its fuse lit, the smoke already rolling off it
    cloud = ic.circle((0.26, 0.56), 0.22) | ic.circle((0.50, 0.40), 0.26) | ic.circle((0.76, 0.54), 0.22) | ic.circle((0.36, 0.76), 0.20) | ic.circle((0.66, 0.78), 0.20)
    ic.part(cloud, SMOKE, shadow=0.09)
    ic.part(ic.circle((0.50, 0.66), 0.21), SHADE, metal=True, shadow=0.07)
    ic.part(ic.capsule((0.50, 0.44), (0.50, 0.48), 0.10), IRON, metal=True, shadow=0.03)
    ic.part(ic.path([(0.50, 0.42), (0.54, 0.32), (0.64, 0.26)], 0.035), WOOD, shadow=0.02)
    ic.glow(ic.star((0.68, 0.22), 0.14, 6, 0.4, 0.3), SPARK, depth=0.05, ink=True)


def point_blank(ic):
    # "Shove the barrel into the nearest enemy and fire: a blast that throws them off their feet"
    ic.glow(ic.star((0.66, 0.42), 0.40, 9, 0.5, 0.15), FIRE, depth=0.13)
    ic.glow(ic.star((0.66, 0.42), 0.17, 9, 0.5, 0.5), SPARK, depth=0.08)
    pistol(ic, (0.04, 0.70), -24.0, 0.56)


def deaths_waltz(ic):
    # "Turn through a deadly waltz, shooting every enemy": the pistol, the turn, shots flying out all round
    for i in range(8):
        a = math.radians(i * 45.0 + 22.5)
        ic.glow(ic.lens((0.5 + math.cos(a) * 0.33, 0.5 + math.sin(a) * 0.33), (0.5 + math.cos(a) * 0.49, 0.5 + math.sin(a) * 0.49), 0.07), SPARK, depth=0.03)
    ic.glow(ic.path(arc((0.50, 0.50), 0.30, 120.0, 250.0), 0.02, 0.07), FIRE, depth=0.03)
    ic.glow(ic.path(arc((0.50, 0.50), 0.30, 300.0, 430.0), 0.02, 0.07), FIRE, depth=0.03)
    pistol(ic, (0.27, 0.62), -32.0, 0.50)


def golden_ricochet(ic):
    # "one gilded ball bounces between every foe ... and ends in a gold burst"
    trail = [(0.03, 0.40), (0.16, 0.84), (0.34, 0.20), (0.50, 0.80), (0.70, 0.46)]
    ic.glow(ic.path(trail, 0.03, 0.075), SPARK, depth=0.03)
    for x, y in ((0.16, 0.84), (0.34, 0.20), (0.50, 0.80)):
        ic.glow(ic.star((x, y), 0.10, 4, 0.35, 0.0), FIRE, depth=0.04, ink=True)
    ic.glow(ic.star((0.72, 0.46), 0.27, 8, 0.5, 0.2), FIRE, depth=0.08)
    ic.part(ic.circle((0.72, 0.46), 0.15), GOLD, metal=True, shadow=0.06)


SKILLS = {
    "sword": [("flying_slash", "Flying Slash", False, flying_slash), ("riposte", "Riposte", False, riposte),
        ("swordfish", "Swordfish Flurry", False, swordfish), ("kraken_wake", "Kraken's Wake  (ult)", True, kraken_wake),
        ("undertow", "Undertow  (ult)", True, undertow)],
    "katana": [("tiger_rush", "Tiger Rush", False, tiger_rush), ("iai_counter", "Iai Counter", False, iai_counter),
        ("wind_sever", "Wind Severer", False, wind_sever), ("twin_waves", "Twin Waves", False, twin_waves),
        ("side_step", "Side Step", False, side_step), ("phantom_step", "Phantom Step", False, phantom_step),
        ("petal_storm", "Thousand Petals  (ult)", True, petal_storm), ("moonlit_severance", "Moonlit Severance  (ult)", True, moonlit_severance)],
    "axe": [("axe_throw", "Hatchet Throw", False, axe_throw), ("earthsplitter", "Earthsplitter", False, earthsplitter),
        ("berserk", "Berserk", False, berserk), ("maelstrom", "Maelstrom  (ult)", True, maelstrom),
        ("executioners_moon", "Executioner's Moon  (ult)", True, executioners_moon)],
    "pistol": [("bullet_storm", "Bullet Storm", False, bullet_storm), ("deadeye", "Deadeye", False, deadeye),
        ("smoke_bomb", "Smoke Bomb", False, smoke_bomb), ("point_blank", "Point Blank", False, point_blank),
        ("deaths_waltz", "Death's Waltz  (ult)", True, deaths_waltz), ("golden_ricochet", "Golden Ricochet  (ult)", True, golden_ricochet)],
}


def render(fn, n, tree, ult):
    ic = Icon(n)
    fn(ic)
    base = plate(n, tree, ult)
    base.alpha_composite(ic.finish())
    return base


def up(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def review(tree):
    skills = SKILLS[tree]
    bg, slate, text = (26, 28, 41, 255), (22, 58, 66, 255), (205, 210, 224, 255)
    pad, cell = 16, 144
    w = pad + len(skills) * (cell + pad)
    sheet = Image.new("RGBA", (max(w, 560), 30 + 96 + 36 + cell + 36 + 96 + 30), bg)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 8), "%s: today (24 px)" % tree, fill=text)
    d.text((pad, 30 + 96 + 12), "new, 48 px (skill map, loadout, tooltips)", fill=text)
    y_bar = 30 + 96 + 36 + cell + 14
    d.text((pad, y_bar), "new, 32 px in skill-bar slots (as on a 1080p screen), today's beside them", fill=text)
    for i, (sid, name, ult, fn) in enumerate(skills):
        x = pad + i * (cell + pad)
        # (a skill with no icon of its own today borrows another's: Skills' "icon" field)
        old_path = os.path.join(ICONS, "skill_%s.png" % sid)
        if os.path.exists(old_path):
            sheet.alpha_composite(up(Image.open(old_path).convert("RGBA"), 4), (x + 24, 30))
        else:
            d.text((x + 24, 70), "(borrows one)", fill=(150, 150, 165, 255))
        sheet.alpha_composite(up(render(fn, 48, tree, ult), 3), (x, 30 + 96 + 30))
        d.text((x, 30 + 96 + 30 + cell + 2), name, fill=(235, 225, 190, 255))

    def bar(size, imgs):
        slot = size + 4
        im = Image.new("RGBA", (len(imgs) * (slot + 3) + 3, slot + 6), slate)
        dd = ImageDraw.Draw(im)
        for i, t in enumerate(imgs):
            x0 = 3 + i * (slot + 3)
            dd.rectangle([x0, 3, x0 + slot - 1, 3 + slot - 1], fill=(14, 40, 46, 255), outline=(190, 150, 70, 255))
            if t is not None:
                im.alpha_composite(t, (x0 + 2, 5))
        return up(im, 2)
    new_bar = bar(32, [render(s[3], 32, tree, s[2]) for s in skills])
    olds = []
    for s in skills:
        p = os.path.join(ICONS, "skill_%s.png" % s[0])
        olds.append(Image.open(p).convert("RGBA") if os.path.exists(p) else None)
    sheet.alpha_composite(new_bar, (pad, y_bar + 16))
    sheet.alpha_composite(bar(24, olds), (pad + new_bar.width + 24, y_bar + 16 + (new_bar.height - 68) // 2))
    os.makedirs(REVIEW, exist_ok=True)
    out = os.path.join(REVIEW, "skills_%s.png" % tree)
    sheet.save(out)
    print("  wrote", os.path.relpath(out, ROOT))


def main():
    write = "--write" in sys.argv
    for tree, skills in SKILLS.items():
        review(tree)
        if write:
            for sid, _name, ult, fn in skills:
                for n in (32, 48):
                    p = os.path.join(ICONS, "skill_%s_%d.png" % (sid, n))
                    render(fn, n, tree, ult).save(p)
                    print("  wrote", os.path.relpath(p, ROOT))


if __name__ == "__main__":
    main()
