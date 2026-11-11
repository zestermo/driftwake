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
CYAN = ramp("0c3a48", "1a8ea0", "52dcea", "b8f6fb", "ffffff")
VIOLET = ramp("2c1458", "6a34b8", "b274ff", "dcc0ff", "ffffff")
BLOOD = ramp("3a0612", "8a1030", "e0244e", "ff8aa0", "ffe0e6")
VENOM = ramp("1d5a12", "3fa01e", "8fdc2c", "dcff6a", "fbffd0")
SNAKE = ramp("0f3312", "1f6a24", "3fa23a", "86d24a", "d8f58a")
TREES = {
    "sword": ("123262", "4db8ff"),
    "katana": ("3a1c48", "ff9ecc"),
    "axe": ("4a1c0a", "ff8026"),
    "pistol": ("3e2c10", "ffbf40"),
    "dual": ("0f3a44", "5ae6f2"),
    "corsair": ("4a1210", "ff5742"),
    "dagger": ("3a0c22", "f22660"),
    "dual_dagger": ("163a10", "72f24c"),
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
    return Image.fromarray(out, "RGBA")


def frame(n, tree, ult=False):
    """The plate's edge, drawn over the art (a close-up runs off the tile): ink with a bright inner line, gold for an ult."""
    mid = hx(TREES[tree][1])
    out = np.zeros((n, n, 4), np.uint8)
    line = hx("f8d660") if ult else mid
    edge = hx("7a4c14") if ult else INK
    for sl in ((0, slice(None)), (n - 1, slice(None)), (slice(None), 0), (slice(None), n - 1)):
        out[sl + (slice(0, 3),)] = edge
        out[sl + (3,)] = 255
    out[1, 1:-1, :3] = out[1:-1, 1, :3] = np.clip(line, 0, 255)
    out[-2, 1:-1, :3] = out[1:-1, -2, :3] = np.clip(line * (0.8 if ult else 0.45), 0, 255)
    out[1, 1:-1, 3] = out[1:-1, 1, 3] = out[-2, 1:-1, 3] = out[1:-1, -2, 3] = 255
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
    # "A cut so fast it flies: a crescent of wind": the crescent leaving the blade that threw it
    ic.glow(ic.circle((0.58, 0.42), 0.50) & ~ic.circle((0.36, 0.64), 0.52), WIND, depth=0.10)
    ic.glow(ic.lens((0.66, 0.97), (0.84, 0.84), 0.06), WIND, depth=0.03)
    cutlass(ic, (-0.32, 1.30), (0.56, 0.44), bend=0.09, w=0.17)


def riposte(ic):
    # "the first blow is turned aside and answered": close on their dark blade stopped on yours, the spark between
    ic.part(ic.poly([(-0.10, 0.02), (0.06, -0.08), (0.70, 0.62), (0.58, 0.74)]), IRON, metal=True, shadow=0.05)
    cutlass(ic, (-0.34, 1.26), (0.92, 0.02), bend=-0.07, w=0.19)
    ic.glow(ic.star((0.42, 0.46), 0.33, 8, 0.36, 0.2), SPARK, depth=0.09, ink=True)


def swordfish(ic):
    # "Five lightning thrusts driving forward": the point driven home, the thrusts before it still hanging in the air
    for y, x0, x1 in ((0.12, 0.30, 0.80), (0.28, 0.46, 0.96), (0.72, 0.46, 0.96), (0.88, 0.30, 0.80)):
        ic.glow(ic.poly([(x0, y - 0.055), (x1, y), (x0, y + 0.055)]), WIND, depth=0.045)
    cutlass(ic, (-1.10, 0.50), (0.86, 0.50), bend=-0.05, w=0.20, guard=False)
    ic.glow(ic.star((0.88, 0.50), 0.16, 6, 0.4, 0.0), SPARK, depth=0.06, ink=True)


def kraken_wake(ic):
    # "Flash between up to six enemies ... every one of them is torn open at once": six cuts through one point
    for ang in (0.0, 60.0, 120.0):
        a = math.radians(ang + 15.0)
        ic.glow(ic.lens((0.5 - math.cos(a) * 0.60, 0.5 - math.sin(a) * 0.60), (0.5 + math.cos(a) * 0.60, 0.5 + math.sin(a) * 0.60), 0.17), WIND, depth=0.06)
    cutlass(ic, (-0.22, 1.22), (0.80, 0.14), bend=0.07, w=0.14)
    ic.glow(ic.star((0.50, 0.50), 0.20, 6, 0.45, math.radians(45.0)), SPARK, depth=0.07, ink=True)


def undertow(ic):
    # "Plant the blade: a whirlpool drags every foe in": the whirlpool winding in to the blade stood in its eye
    for turn in (0.0, 120.0, 240.0):
        pts = []
        for k in range(9):
            t = k / 8.0
            a = math.radians(turn + 250.0 * t)
            r = 0.60 * (1.0 - 0.74 * t)
            pts.append((0.5 + math.cos(a) * r, 0.64 + math.sin(a) * r * 0.62))
        ic.glow(ic.path(pts, 0.045, 0.15), WATER, depth=0.06)
    ic.glow(ic.circle((0.50, 0.66), 0.11), WATER, depth=0.06)
    cutlass(ic, (0.50, -0.50), (0.50, 0.72), bend=0.04, w=0.17)


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


def grip_hand(ic, at, angle, size, thumb=True):
    """A hand closed round a grip that runs along `angle` through `at`: the four fingers wrapped over it, the thumb
    laid along it toward +u (pressing a guard, say)."""
    f = Frame(at, angle, size)
    ic.part(ic.poly(f.pts([(-0.50, -0.34), (-0.36, -0.46), (0.36, -0.46), (0.50, -0.34), (0.52, 0.30), (0.40, 0.46), (-0.40, 0.46), (-0.52, 0.30)])), SKIN, shadow=0.05)
    for u in (-0.25, 0.0, 0.25):
        ic.flat(ic.capsule(f.pt(u, -0.40), f.pt(u, 0.16), 0.035 * size / 0.4), hx("8a4a3a"))
    if thumb:
        ic.part(ic.capsule(f.pt(0.20, -0.50), f.pt(0.78, -0.42), 0.20 * size), SKIN, shadow=0.04)


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
    # "Dash straight through the enemy line with a single drawing cut": the blade itself streaking across, close
    for y, x1 in ((0.14, 0.52), (0.27, 0.34), (0.80, 0.44), (0.92, 0.66)):
        ic.glow(ic.lens((0.03, y), (x1, y), 0.05), MOON, depth=0.03)
    ic.glow(ic.lens((-0.05, 0.60), (1.05, 0.30), 0.17), MOON, depth=0.06)
    katana(ic, (-0.22, 1.00), (0.97, 0.26), bend=-0.13, w=0.12)


def iai_counter(ic):
    # "Slip the blade home and wait, hand on the hilt": close on the hand, the guard thumbed off the sheath's mouth,
    # the first sliver of steel catching the light
    katana(ic, (-0.36, 0.26), (2.10, 1.36), bend=-0.20, w=0.18, sheathed=True, drawn=0.085, cord=PETAL)
    grip_hand(ic, (0.07, 0.41), 24.0, 0.44)
    ic.glow(ic.star((0.70, 0.50), 0.17, 4, 0.2, 0.0), MOON, depth=0.045, ink=True)


def wind_sever(ic):
    # "a towering blade of wind tearing along the ground": the blade of wind standing over the ground it tears up
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.90), (1.0, 0.90), (1.0, 1.0)]), STONE, shadow=0.03)
    wind_blade(ic, 0.56, 1.0, h=0.90, depth=0.10)
    for pts in ([(0.06, 0.90), (0.16, 0.70), (0.26, 0.90)], [(0.24, 0.90), (0.31, 0.78), (0.38, 0.90)], [(0.80, 0.90), (0.90, 0.74), (0.96, 0.90)]):
        ic.part(ic.poly(pts), STONE, shadow=0.04)


def twin_waves(ic):
    # "two blades of wind sent out from either side, crossing ahead of you"
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.92), (1.0, 0.92), (1.0, 1.0)]), STONE, shadow=0.03)
    wind_blade(ic, 0.66, 1.0, MOON, h=0.84, depth=0.07)
    wind_blade(ic, 0.34, -1.0, PETAL, h=0.84, depth=0.07)
    ic.glow(ic.star((0.50, 0.50), 0.13, 4, 0.3, 0.78), SPARK, depth=0.05)


def side_step(ic):
    # "meets empty air. You're already out at their side, drawing across them": where you stood, and the cut from the side
    bust(ic, (0.30, 0.46), 0.50, [hx(c) for c in ("2a2a5a", "3c3c7c", "5454a0", "7474c4", "9a9ae0")])
    ic.glow(ic.lens((0.30, 0.20), (1.04, 0.74), 0.16), PETAL, depth=0.05)
    katana(ic, (1.30, 1.42), (0.56, 0.26), bend=0.12, w=0.115)


def phantom_step(ic):
    # "Blink behind the nearest enemy and cut them down from behind": their back, and the blade already through
    ic.glow(ic.lens((1.02, 0.02), (0.16, 0.92), 0.28), PETAL, depth=0.08)
    bust(ic, (0.38, 0.54), 0.56, SHADE)
    katana(ic, (1.55, 0.78), (0.46, 0.05), bend=-0.12, w=0.115)


def petal_storm(ic):
    # "Draw and sheathe in a single motion ... cut a dozen times at once": close on the guard clicking home on the
    # sheath, the cuts behind it, the petals falling across
    for ang in (150.0, 105.0):
        a = math.radians(ang)
        ic.glow(ic.lens((0.56 - math.cos(a) * 0.62, 0.42 - math.sin(a) * 0.62), (0.56 + math.cos(a) * 0.62, 0.42 + math.sin(a) * 0.62), 0.07), MOON, depth=0.03)
    katana(ic, (-0.40, 1.22), (2.10, -0.62), bend=0.20, w=0.18, sheathed=True, cord=PETAL)
    for (x, y), turn in (((0.20, 0.20), 0.6), ((0.56, 0.14), 2.2), ((0.86, 0.40), 1.2), ((0.70, 0.80), 2.8), ((0.34, 0.90), 0.2), ((0.90, 0.88), 1.9)):
        ic.glow(ic.lens((x - math.cos(turn) * 0.12, y - math.sin(turn) * 0.12), (x + math.cos(turn) * 0.12, y + math.sin(turn) * 0.12), 0.14), PETAL, depth=0.06, ink=True)


def moonlit_severance(ic):
    # "one draw along a 14 m line: the world goes pale ... everything on the line splits": the moon itself cut in two
    cut = Frame((0.5, 0.5), -24.0, 1.0)
    upper = ic.poly(cut.pts([(-1, -1), (1, -1), (1, -0.04), (-1, -0.04)]))
    lower = ic.poly(cut.pts([(-1, 0.04), (1, 0.04), (1, 1), (-1, 1)]))
    ic.glow(ic.circle(cut.pt(0.10, -0.04), 0.40) & upper, MOON, depth=0.17, ink=True)
    ic.glow(ic.circle(cut.pt(-0.10, 0.04), 0.40) & lower, MOON, depth=0.17, ink=True)
    ic.glow(ic.lens(cut.pt(-0.62, 0.0), cut.pt(0.62, 0.0), 0.085), PETAL, depth=0.03)


# ----------------------------------------------------------------------------------------------------------------
# Axe
# ----------------------------------------------------------------------------------------------------------------
def axe_throw(ic):
    # "Hurl your axe spinning ahead ... and comes back to your hand": the axe mid-spin, the rings it cuts in the air
    ic.glow(ic.path(arc((0.52, 0.48), 0.52, 195.0, 330.0), 0.03, 0.13), FIRE, depth=0.05)
    ic.glow(ic.path(arc((0.52, 0.48), 0.52, 15.0, 150.0), 0.03, 0.13), FIRE, depth=0.05)
    axe(ic, (-0.06, 1.08), -47.0, 1.12)


def earthsplitter(ic):
    # "drive the axe into the ground: a crack tears 9 m ahead": the head buried, the crack running on, glowing
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.66), (0.30, 0.62), (0.46, 0.70), (0.62, 0.60), (1.0, 0.66), (1.0, 1.0)]), STONE, shadow=0.05)
    crack = [(0.42, 0.68), (0.54, 0.80), (0.66, 0.74), (0.78, 0.88), (0.90, 0.82), (1.02, 0.94)]
    ic.glow(ic.path(crack, 0.15, 0.07), FIRE, depth=0.05)
    ic.flat(ic.path(crack, 0.04, 0.02), INK)
    for pts in ([(0.66, 0.56), (0.76, 0.32), (0.86, 0.58)], [(0.88, 0.60), (0.96, 0.44), (1.0, 0.62)], [(0.52, 0.54), (0.58, 0.40), (0.64, 0.56)]):
        ic.part(ic.poly(pts), STONE, shadow=0.045)
    axe(ic, (-0.14, -0.30), 54.0, 1.05)


def berserk(ic):
    # "Roar": the roaring face, the rage burning off it
    ic.glow(ic.poly([(0.0, 1.0), (-0.02, 0.56), (0.10, 0.64), (0.06, 0.28), (0.22, 0.40), (0.26, 0.06), (0.42, 0.24), (0.52, -0.04), (0.62, 0.24),
        (0.78, 0.04), (0.80, 0.40), (0.96, 0.28), (0.92, 0.62), (1.02, 0.58), (1.0, 1.0)]), FIRE, depth=0.14)
    ic.part(ic.poly([(0.20, 0.50), (0.30, 0.30), (0.70, 0.30), (0.80, 0.50), (0.78, 0.86), (0.64, 1.06), (0.36, 1.06), (0.22, 0.86)]), SKIN, shadow=0.08)
    ic.flat(ic.poly([(0.25, 0.42), (0.47, 0.55), (0.46, 0.63), (0.25, 0.52)]) | ic.poly([(0.75, 0.42), (0.53, 0.55), (0.54, 0.63), (0.75, 0.52)]), INK)
    ic.flat(ic.poly([(0.32, 0.52), (0.44, 0.59), (0.33, 0.58)]) | ic.poly([(0.68, 0.52), (0.56, 0.59), (0.67, 0.58)]), hx("fff4b4"))
    ic.flat(ic.poly([(0.34, 0.72), (0.66, 0.72), (0.70, 0.98), (0.30, 0.98)]), INK)
    ic.flat(ic.poly([(0.37, 0.73), (0.63, 0.73), (0.62, 0.79), (0.38, 0.79)]) | ic.poly([(0.34, 0.92), (0.66, 0.92), (0.67, 0.97), (0.33, 0.97)]), hx("fff8e8"))


def maelstrom(ic):
    # "Become a whirlwind of steel": two axes wheeling round one point, the wind they drag with them
    for turn in (0.0, 180.0):
        ic.glow(ic.path(arc((0.50, 0.50), 0.50, turn + 95.0, turn + 250.0), 0.03, 0.15), FIRE, depth=0.055)
    axe(ic, (0.50, 0.50), -42.0, 0.50)
    axe(ic, (0.50, 0.50), 138.0, 0.50)
    ic.part(ic.circle((0.50, 0.50), 0.085), GOLD, metal=True, shadow=0.035)


def executioners_moon(ic):
    # "one chop: a huge blow ... and a fissure of fire ten paces down the line": the head against its moon, the fire below
    ic.glow(ic.circle((0.50, 0.40), 0.46) & ~ic.circle((0.70, 0.28), 0.42), MOON, depth=0.10)
    ic.glow(ic.poly([(0.0, 1.0), (0.04, 0.82), (0.14, 0.90), (0.22, 0.72), (0.34, 0.88), (0.46, 0.68), (0.56, 0.88), (0.68, 0.74), (0.78, 0.90),
        (0.88, 0.76), (1.0, 0.88), (1.0, 1.0)]), FIRE, depth=0.08)
    axe(ic, (1.22, -0.22), 134.0, 1.18, flip=True)


# ----------------------------------------------------------------------------------------------------------------
# Pistol
# ----------------------------------------------------------------------------------------------------------------
def bullet_storm(ic):
    # "Fan the hammer: seven shots swept across everything in front of you": close on the muzzle and the fan of shot
    m = (0.56, 0.47)
    for ang in (-54.0, -36.0, -18.0, 0.0, 18.0, 36.0, 54.0):
        a = math.radians(ang)
        ic.glow(ic.lens((m[0] + math.cos(a) * 0.14, m[1] + math.sin(a) * 0.14), (m[0] + math.cos(a) * 0.62, m[1] + math.sin(a) * 0.62), 0.09), SPARK, depth=0.04)
    ic.glow(ic.star(m, 0.23, 7, 0.45, 0.2), FIRE, depth=0.08)
    pistol(ic, (-0.40, 0.56), -4.0, 0.95)


def deadeye(ic):
    # "one shot that punches through every enemy in a line": the sights, the ball gone clean through them
    ring = ic.circle((0.50, 0.50), 0.47) & ~ic.circle((0.50, 0.50), 0.36)
    ticks = ic.capsule((0.50, -0.05), (0.50, 0.22), 0.075) | ic.capsule((0.50, 0.78), (0.50, 1.05), 0.075) | ic.capsule((-0.05, 0.50), (0.14, 0.50), 0.075)
    ic.part(ring | ticks, GOLD, metal=True, shadow=0.045)
    ic.glow(ic.lens((-0.10, 0.50), (0.84, 0.50), 0.17), SPARK, depth=0.06)
    ic.part(ic.poly([(0.66, 0.38), (0.86, 0.38), (1.00, 0.50), (0.86, 0.62), (0.66, 0.62)]), STEEL, metal=True, shadow=0.05)
    ic.flat(ic.circle((0.50, 0.50), 0.05), hx("c9331a"))


def smoke_bomb(ic):
    # "Throw down a smoke bomb": the bomb, its fuse lit, the smoke already rolling off it
    cloud = ic.circle((0.20, 0.56), 0.28) | ic.circle((0.50, 0.34), 0.32) | ic.circle((0.82, 0.54), 0.28) | ic.circle((0.30, 0.86), 0.26) | ic.circle((0.72, 0.88), 0.26)
    ic.part(cloud, SMOKE, shadow=0.10)
    ic.part(ic.circle((0.50, 0.68), 0.27), SHADE, metal=True, shadow=0.08)
    ic.part(ic.capsule((0.50, 0.40), (0.50, 0.45), 0.13), IRON, metal=True, shadow=0.03)
    ic.part(ic.path([(0.50, 0.38), (0.56, 0.26), (0.68, 0.20)], 0.045), WOOD, shadow=0.02)
    ic.glow(ic.star((0.73, 0.17), 0.17, 6, 0.4, 0.3), SPARK, depth=0.06, ink=True)


def point_blank(ic):
    # "Shove the barrel into the nearest enemy and fire": the muzzle, and nothing but the blast in front of it
    ic.glow(ic.star((0.66, 0.38), 0.52, 9, 0.5, 0.15), FIRE, depth=0.16)
    ic.glow(ic.star((0.66, 0.38), 0.22, 9, 0.5, 0.5), SPARK, depth=0.10)
    pistol(ic, (-0.52, 0.92), -24.0, 1.05)


def deaths_waltz(ic):
    # "Turn through a deadly waltz, shooting every enemy": the pistol, the turn, shots flying out all round
    for k in range(8):
        a = math.radians(k * 45.0 + 22.5)
        ic.glow(ic.lens((0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.36), (0.5 + math.cos(a) * 0.60, 0.5 + math.sin(a) * 0.60), 0.10), SPARK, depth=0.04)
    ic.glow(ic.path(arc((0.50, 0.50), 0.34, 110.0, 250.0), 0.025, 0.09), FIRE, depth=0.04)
    ic.glow(ic.path(arc((0.50, 0.50), 0.34, 290.0, 430.0), 0.025, 0.09), FIRE, depth=0.04)
    pistol(ic, (0.16, 0.72), -34.0, 0.72)


def golden_ricochet(ic):
    # "one gilded ball bounces between every foe ... and ends in a gold burst"
    trail = [(-0.04, 0.34), (0.12, 0.86), (0.30, 0.16), (0.46, 0.82), (0.66, 0.46)]
    ic.glow(ic.path(trail, 0.04, 0.10), SPARK, depth=0.04)
    for x, y in ((0.12, 0.86), (0.30, 0.16), (0.46, 0.82)):
        ic.glow(ic.star((x, y), 0.12, 4, 0.35, 0.0), FIRE, depth=0.05, ink=True)
    ic.glow(ic.star((0.70, 0.46), 0.36, 8, 0.5, 0.2), FIRE, depth=0.10)
    ic.part(ic.circle((0.70, 0.46), 0.19), GOLD, metal=True, shadow=0.07)


# ----------------------------------------------------------------------------------------------------------------
# Pieces for the dagger trees
# ----------------------------------------------------------------------------------------------------------------
def dagger(ic, hilt, tip, w=0.13, guard=True):
    """A dagger from its pommel to its point: a short straight double-edged blade with a little belly, a stub of a
    guard, a leather grip."""
    dx, dy = tip[0] - hilt[0], tip[1] - hilt[1]
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux
    b0 = (hilt[0] + ux * ln * 0.32, hilt[1] + uy * ln * 0.32)
    bl = ln * 0.68
    belly = (b0[0] + ux * bl * 0.45, b0[1] + uy * bl * 0.45)
    ic.part(ic.poly([(b0[0] + px * w * 0.40, b0[1] + py * w * 0.40), (belly[0] + px * w * 0.5, belly[1] + py * w * 0.5), tip,
        (belly[0] - px * w * 0.5, belly[1] - py * w * 0.5), (b0[0] - px * w * 0.40, b0[1] - py * w * 0.40)]), STEEL, metal=True, shadow=0.04)
    ic.part(ic.capsule(hilt, b0, w * 0.58), LEATHER, shadow=0.035)
    if guard:
        ic.part(ic.capsule((b0[0] - px * w * 0.9, b0[1] - py * w * 0.9), (b0[0] + px * w * 0.9, b0[1] + py * w * 0.9), w * 0.42), GOLD, metal=True, shadow=0.03)
    ic.part(ic.circle(hilt, w * 0.38), GOLD, metal=True, shadow=0.03)


def knife(ic, a, b, w=0.07):
    """A throwing knife from its ring to its point."""
    m = (a[0] + (b[0] - a[0]) * 0.30, a[1] + (b[1] - a[1]) * 0.30)
    ic.part(ic.lens(m, b, w * 1.5), STEEL, metal=True, shadow=0.03)
    ic.part(ic.capsule(a, m, w * 0.6), SHADE, shadow=0.02)


def oval(c, rx, ry, steps=20):
    return [(c[0] + math.cos(2 * math.pi * k / steps) * rx, c[1] + math.sin(2 * math.pi * k / steps) * ry) for k in range(steps)]


def drop(ic, c, r, mat):
    ic.glow(ic.circle(c, r) | ic.poly([(c[0] - r * 0.8, c[1] - r * 0.3), (c[0], c[1] - r * 2.4), (c[0] + r * 0.8, c[1] - r * 0.3)]), mat, depth=r / 1.2, ink=True)


# ----------------------------------------------------------------------------------------------------------------
# Dual (two cutlasses)
# ----------------------------------------------------------------------------------------------------------------
def cross_counter(ic):
    # "Cross both blades in front of you: the first melee blow ... is caught in the X"
    ic.glow(ic.star((0.50, 0.50), 0.62, 4, 0.34, math.radians(45.0)), CYAN, depth=0.12)
    cutlass(ic, (-0.34, 1.32), (0.88, 0.02), bend=0.07, w=0.17)
    cutlass(ic, (1.34, 1.32), (0.12, 0.02), bend=-0.07, w=0.17)
    ic.glow(ic.star((0.50, 0.52), 0.17, 4, 0.3, 0.0), SPARK, depth=0.06, ink=True)


def blade_dance(ic):
    # "Dance forward through the enemy line in six spinning cuts": the two blades wheeling, each dragging its cut
    ic.glow(ic.path(arc((0.50, 0.50), 0.44, 205.0, 385.0), 0.03, 0.16), CYAN, depth=0.06)
    ic.glow(ic.path(arc((0.50, 0.50), 0.44, 25.0, 205.0), 0.03, 0.16), VIOLET, depth=0.06)
    cutlass(ic, (0.50, 0.50), (0.94, 0.16), bend=0.06, w=0.13, guard=False)
    cutlass(ic, (0.50, 0.50), (0.06, 0.84), bend=0.06, w=0.13, guard=False)
    ic.part(ic.circle((0.50, 0.50), 0.08), GOLD, metal=True, shadow=0.03)


def cross_fang(ic):
    # "crash down with both blades crossed, knocking down everything in front of you": the two cuts driven into the ground
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.84), (0.30, 0.80), (0.50, 0.86), (0.72, 0.80), (1.0, 0.84), (1.0, 1.0)]), STONE, shadow=0.04)
    ic.glow(ic.lens((0.06, -0.04), (0.74, 0.90), 0.24), CYAN, depth=0.08)
    ic.glow(ic.lens((0.94, -0.04), (0.26, 0.90), 0.24), VIOLET, depth=0.08)
    for pts in ([(0.08, 0.82), (0.16, 0.62), (0.24, 0.82)], [(0.78, 0.82), (0.88, 0.64), (0.94, 0.84)]):
        ic.part(ic.poly(pts), STONE, shadow=0.04)
    ic.glow(ic.star((0.50, 0.80), 0.20, 6, 0.4, 0.5), SPARK, depth=0.07, ink=True)


def steel_tempest(ic):
    # "spin in place with them out: a storm of cuts drags in everything around you"
    for k in range(6):
        a = math.radians(k * 60.0)
        c = (0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.36)
        t = a + math.radians(70.0)
        ic.glow(ic.lens((c[0] - math.cos(t) * 0.26, c[1] - math.sin(t) * 0.26), (c[0] + math.cos(t) * 0.26, c[1] + math.sin(t) * 0.26), 0.12), CYAN if k % 2 == 0 else VIOLET, depth=0.045)
    cutlass(ic, (0.50, 0.50), (0.82, 0.22), bend=0.05, w=0.12, guard=False)
    cutlass(ic, (0.50, 0.50), (0.18, 0.78), bend=0.05, w=0.12, guard=False)
    ic.part(ic.circle((0.50, 0.50), 0.075), GOLD, metal=True, shadow=0.03)


def twin_comet(ic):
    # "a dive onto the foe you face: the ground bursts round you, an X of light tears ten paces on"
    # (two comets side by side, still falling: Cross Fang is the pair already landed)
    for (hx_, hy), mat in (((0.44, 0.74), CYAN), ((0.76, 0.52), VIOLET)):
        ic.glow(ic.path([(hx_ - 0.62, hy - 0.86), (hx_ - 0.30, hy - 0.42), (hx_, hy)], 0.03, 0.26), mat, depth=0.07)
        ic.glow(ic.circle((hx_, hy), 0.17), mat, depth=0.10, ink=True)
    for x, y, r in ((0.84, 0.12, 0.07), (0.14, 0.80, 0.06), (0.90, 0.86, 0.08)):
        ic.glow(ic.star((x, y), r, 4, 0.3, 0.0), SPARK, depth=r / 2.5)


# ----------------------------------------------------------------------------------------------------------------
# Corsair (cutlass and pistol)
# ----------------------------------------------------------------------------------------------------------------
def parley(ic):
    # "turned aside on the blade, and the pistol is put to their chest and fired": the raised blade, the pistol under it going off
    ic.glow(ic.star((0.80, 0.30), 0.30, 8, 0.45, 0.2), FIRE, depth=0.10)
    pistol(ic, (0.10, 0.94), -40.0, 0.78)
    cutlass(ic, (-0.10, 1.34), (0.30, 0.02), bend=-0.07, w=0.17)


def grapeshot(ic):
    # "A pistol packed with shot: one blast tears across everything in a wide cone"
    ic.glow(ic.poly([(0.32, 0.50), (1.06, -0.06), (1.06, 1.06)]), FIRE, depth=0.16)
    for x, y in ((0.60, 0.36), (0.66, 0.60), (0.80, 0.22), (0.84, 0.48), (0.84, 0.76), (0.96, 0.34), (0.96, 0.62)):
        ic.part(ic.circle((x, y), 0.055), SHADE, metal=True, shadow=0.03)
    pistol(ic, (-0.62, 0.60), -4.0, 1.0)


def crossfire(ic):
    # "a cut that breaks their guard, turn, and shoot them in the back": the cut one way, the shot back across it
    ic.glow(ic.lens((0.00, 0.06), (1.00, 0.86), 0.24), FIRE, depth=0.08)
    ic.glow(ic.path([(1.02, 0.14), (0.62, 0.50), (0.24, 0.84)], 0.03, 0.12), SPARK, depth=0.045)
    ic.part(ic.circle((0.22, 0.86), 0.10), GOLD, metal=True, shadow=0.05)
    ic.glow(ic.star((0.52, 0.50), 0.15, 4, 0.3, 0.0), SPARK, depth=0.05, ink=True)


def broadside(ic):
    # "Raise your cutlass and call the broadside ... cannon fire lands on every one of them"
    for (x, y), r in (((0.56, 0.30), 0.13), ((0.80, 0.56), 0.12), ((0.52, 0.76), 0.11)):
        ic.glow(ic.path([(x + 0.50, y - 0.50), (x + 0.20, y - 0.20), (x, y)], 0.03, r * 1.7), FIRE, depth=0.05)
        ic.part(ic.circle((x, y), r), SHADE, metal=True, shadow=0.05)
    cutlass(ic, (0.02, 1.40), (0.20, 0.03), bend=-0.05, w=0.17)


def powder_trail(ic):
    # "the powder laid round them as you go; then the ring goes up under all of them at once"
    ring = ic.poly(oval((0.50, 0.66), 0.50, 0.26)) & ~ic.poly(oval((0.50, 0.66), 0.34, 0.15))
    flames = np.zeros_like(ring)
    for x, top in ((0.08, 0.30), (0.26, 0.10), (0.50, 0.00), (0.74, 0.12), (0.92, 0.30)):
        flames |= ic.poly([(x - 0.10, 0.66), (x - 0.05, top + 0.22), (x, top), (x + 0.06, top + 0.24), (x + 0.10, 0.66)])
    ic.glow(ring | flames, FIRE, depth=0.07)
    ic.part(ic.poly([(0.38, 0.52), (0.62, 0.52), (0.66, 0.78), (0.34, 0.78)]), WOOD, shadow=0.05)
    ic.part(ic.poly([(0.36, 0.56), (0.64, 0.56), (0.645, 0.61), (0.355, 0.61)]) | ic.poly([(0.345, 0.69), (0.655, 0.69), (0.66, 0.74), (0.34, 0.74)]), IRON, metal=True, shadow=0.02)
    ic.glow(ic.star((0.50, 0.46), 0.11, 6, 0.4, 0.2), SPARK, depth=0.04, ink=True)


# ----------------------------------------------------------------------------------------------------------------
# Dagger
# ----------------------------------------------------------------------------------------------------------------
def slip(ic):
    # "you're behind them with the blade in their back": their back, the dagger in it
    bust(ic, (0.42, 0.56), 0.60, SHADE)
    ic.glow(ic.star((0.50, 0.60), 0.20, 6, 0.4, 0.3), BLOOD, depth=0.07, ink=True)
    dagger(ic, (1.08, -0.06), (0.50, 0.60), w=0.15)


def cutthroat(ic):
    # "open their throat before they can turn": the blade drawn across, the red line it leaves
    ic.glow(ic.lens((-0.04, 0.70), (1.04, 0.48), 0.20), BLOOD, depth=0.07)
    drop(ic, (0.30, 0.90), 0.045, BLOOD)
    drop(ic, (0.60, 0.88), 0.055, BLOOD)
    dagger(ic, (-0.34, 0.22), (0.92, 0.46), w=0.17)


def knife_fan(ic):
    # "Flick five throwing knives out in a fan"
    o = (0.06, 0.96)
    ic.glow(ic.path(arc(o, 0.50, -88.0, -2.0), 0.04, 0.10), BLOOD, depth=0.04)
    for ang in (-82.0, -62.0, -44.0, -26.0, -8.0):
        a = math.radians(ang)
        knife(ic, (o[0] + math.cos(a) * 0.52, o[1] + math.sin(a) * 0.52), (o[0] + math.cos(a) * 1.02, o[1] + math.sin(a) * 1.02), w=0.085)


def red_eclipse(ic):
    # "Melt into the dark and cut every enemy around you ... every wound opens at once": the eclipse, the blade in it
    ic.glow(ic.circle((0.50, 0.50), 0.47), BLOOD, depth=0.10)
    ic.part(ic.circle((0.54, 0.46), 0.36), SHADE, shadow=0.08)
    dagger(ic, (0.42, 0.10), (0.58, 0.86), w=0.13)


def blood_moon_mark(ic):
    # "each cut and bleeding; then every wound opens at once": the blood moon, the mark cut across it
    ic.glow(ic.circle((0.50, 0.46), 0.42), BLOOD, depth=0.20, ink=True)
    ic.flat(ic.lens((0.16, 0.14), (0.80, 0.80), 0.10) | ic.lens((0.84, 0.14), (0.20, 0.80), 0.10), SHADE[0])
    drop(ic, (0.34, 0.94), 0.045, BLOOD)
    drop(ic, (0.62, 0.96), 0.04, BLOOD)


# ----------------------------------------------------------------------------------------------------------------
# Twin daggers
# ----------------------------------------------------------------------------------------------------------------
def viper_flurry(ic):
    # "the blades striking in turn like a snake": the viper itself, mouth open, fangs out
    ic.flat(ic.poly([(-0.05, 0.44), (0.70, 0.44), (0.92, 0.60), (0.60, 0.80), (-0.05, 0.74)]), hx("3a0612"))
    ic.part(ic.poly([(-0.05, 0.60), (0.30, 0.66), (0.64, 0.74), (0.90, 0.86), (0.56, 1.02), (-0.05, 0.98)]), SNAKE, shadow=0.06)
    ic.part(ic.poly([(-0.05, 0.10), (0.44, 0.04), (0.84, 0.22), (1.00, 0.42), (0.66, 0.50), (0.30, 0.46), (-0.05, 0.50)]), SNAKE, shadow=0.07)
    ic.flat(ic.poly([(0.58, 0.48), (0.69, 0.49), (0.64, 0.74)]) | ic.poly([(0.80, 0.46), (0.91, 0.45), (0.87, 0.68)]), hx("fbffe8"))
    ic.flat(ic.circle((0.56, 0.25), 0.075), hx("ffd23a"))
    ic.flat(ic.capsule((0.56, 0.19), (0.56, 0.31), 0.035), INK)
    drop(ic, (0.645, 0.86), 0.04, VENOM)


def scissor_leap(ic):
    # "scissor both blades through them as you land": the two daggers closing like shears, the cuts they leave
    ic.glow(ic.lens((0.02, 0.30), (0.98, 0.52), 0.16), VENOM, depth=0.055)
    ic.glow(ic.lens((0.02, 0.70), (0.98, 0.48), 0.16), VENOM, depth=0.055)
    dagger(ic, (-0.20, 1.20), (0.82, 0.10), w=0.15)
    dagger(ic, (1.20, 1.20), (0.18, 0.10), w=0.15)
    ic.glow(ic.star((0.50, 0.52), 0.14, 4, 0.3, 0.0), SPARK, depth=0.05, ink=True)


def bleeding_edge(ic):
    # "Whet the blades against each other": edge on edge, the sparks, the edges running
    ic.part(ic.poly([(-0.06, 0.80), (0.06, 0.96), (1.06, 0.30), (0.98, 0.10), (0.40, 0.42)]), STEEL, metal=True, shadow=0.05)
    ic.part(ic.poly([(-0.06, 0.20), (0.04, 0.04), (0.62, 0.36), (1.06, 0.72), (0.98, 0.90)]), STEEL, metal=True, shadow=0.05)
    for (x, y), r in (((0.56, 0.44), 0.20), ((0.30, 0.20), 0.08), ((0.78, 0.28), 0.07), ((0.70, 0.70), 0.07)):
        ic.glow(ic.star((x, y), r, 4, 0.3, 0.3), SPARK, depth=r / 3.0, ink=True)
    drop(ic, (0.22, 0.84), 0.05, VENOM)
    drop(ic, (0.88, 0.96), 0.045, VENOM)


def hundred_fangs(ic):
    # "cutting everyone close each time until your path draws a star; then the star bursts"
    pts = [(0.5 + math.cos(math.radians(-90.0 + k * 144.0)) * 0.50, 0.52 + math.sin(math.radians(-90.0 + k * 144.0)) * 0.50) for k in range(5)]
    for k in range(5):
        ic.glow(ic.lens(pts[k], pts[(k + 1) % 5], 0.11), VENOM, depth=0.04)
    ic.glow(ic.star((0.50, 0.54), 0.17, 5, 0.45, math.radians(-90.0)), SPARK, depth=0.06, ink=True)


def serpents_nest(ic):
    # "Venom pools out 7 m round you; you dart between everyone in it": the pool, the serpents rising out of it
    ic.glow(ic.poly(oval((0.50, 0.82), 0.52, 0.20)), VENOM, depth=0.07)
    for x, lean, top in ((0.22, -0.10, 0.34), (0.52, 0.08, 0.14), (0.80, -0.06, 0.40)):
        body = [(x, 0.84), (x + lean, 0.66), (x - lean * 0.8, top + 0.20), (x + lean * 0.6, top + 0.06)]
        ic.part(ic.path(body, 0.13, 0.10), SNAKE, shadow=0.045)
        head = (x + lean * 0.6 + (0.06 if lean > 0 else -0.06), top + 0.02)
        ic.part(ic.poly(oval(head, 0.10, 0.065)), SNAKE, shadow=0.04)
        ic.flat(ic.circle((head[0] + (0.03 if lean > 0 else -0.03), head[1] - 0.01), 0.022), hx("ffd23a"))


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
    "dual": [("cross_counter", "Crossed Counter", False, cross_counter), ("blade_dance", "Blade Dance", False, blade_dance),
        ("cross_fang", "Cross Fang", False, cross_fang), ("steel_tempest", "Tempest of Steel  (ult)", True, steel_tempest),
        ("twin_comet", "Twin Comet  (ult)", True, twin_comet)],
    "corsair": [("parley", "Parley", False, parley), ("grapeshot", "Grapeshot", False, grapeshot), ("crossfire", "Crossfire", False, crossfire),
        ("broadside", "Broadside  (ult)", True, broadside), ("powder_trail", "Powder Trail  (ult)", True, powder_trail)],
    "dagger": [("slip", "Slip", False, slip), ("cutthroat", "Cutthroat", False, cutthroat), ("knife_fan", "Knife Fan", False, knife_fan),
        ("red_eclipse", "Red Eclipse  (ult)", True, red_eclipse), ("blood_moon_mark", "Blood Moon Mark  (ult)", True, blood_moon_mark)],
    "dual_dagger": [("viper_flurry", "Viper Flurry", False, viper_flurry), ("scissor_leap", "Scissor Leap", False, scissor_leap),
        ("bleeding_edge", "Bleeding Edge", False, bleeding_edge), ("hundred_fangs", "Hundred Fangs  (ult)", True, hundred_fangs),
        ("serpents_nest", "Serpent's Nest  (ult)", True, serpents_nest)],
}


def render(fn, n, tree, ult):
    ic = Icon(n)
    fn(ic)
    base = plate(n, tree, ult)
    base.alpha_composite(ic.finish())
    base.alpha_composite(frame(n, tree, ult))
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
