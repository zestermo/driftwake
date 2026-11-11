"""Skill icons, ink and cel (2026-11-11; Zach picked this style from mock_skill_styles.py's five).

Each icon is one description of parts in 0..1 coordinates (y down), so it renders at any size: 32 px for the HUD's
skill bar, 48 px for the skill map, loadout and tooltips. A part is flat colour with one hard shadow along its lower
right, a one-pixel light edge up and left, and black ink round it and between parts; what glows (wind, fire, water)
is three hard bands, brightest at the core. Every icon sits on its tree's plate: an impact burst in the tree's colour,
gold-framed for an ultimate.

    py tools/texture_gen/gen_skill_icons.py            # review sheets -> tools/dev/out/iconreview/skills_<tree>.png
    py tools/texture_gen/gen_skill_icons.py --write    # also assets/textures/icons/skill_<id>_16 / _32 / _48.png
                                                       # (Skills.icon(id, px) picks the nearest size)
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
BOLT = ramp("5a4a08", "c8a010", "ffe652", "fff8b0", "ffffff")
DUST = ramp("4a3a26", "8a7050", "c8ac80", "ecd8b0", "fff6e0")
GALE = ramp("0f4a3a", "28b08a", "7af0c0", "d0ffec", "ffffff")
ICE = ramp("1b3572", "3a70c2", "78b9ee", "c2ecff", "ffffff")
BONE = ramp("5a4a3a", "a8987c", "e8dcc0", "fbf4e0", "ffffff")
HEAT = ramp("5a0810", "c41828", "ff4a3a", "ffb08a", "fff0e0")
IMPACT = ramp("6a4a1a", "d89a3a", "ffd27a", "fff2c8", "ffffff")
SILVER = ramp("2a3a58", "6a82a8", "b0c4e0", "e4eefa", "ffffff")
LEAFWIND = ramp("1c4a1a", "4aa83a", "a6e070", "e2f8c0", "ffffff")
LEAF = ramp("0f331c", "1c6229", "3a9a38", "86cc48", "d8f288")
AUTUMN = ramp("5a2a08", "b85a14", "f0a030", "ffd670", "fff2c0")
SOUL = ramp("0c3a30", "1ea078", "5ef0b8", "c8ffe8", "ffffff")
PINK = ramp("5a1040", "c8308a", "ff78c0", "ffc8e4", "ffffff")
WHITE = ramp("5a6478", "a8b4c8", "e8eef6", "ffffff", "ffffff")
TEAL = ramp("0c3a3a", "1e8a86", "65c9c0", "c0f2ec", "ffffff")
FUR = ramp("2a2c3a", "565a70", "8a90a8", "c0c6d8", "f0f2fa")
GLASS = ramp("0e3a22", "1e7a44", "46b46a", "a0e8b4", "e8fff0")
MEAT = ramp("4a1c0c", "8a3a1a", "c0602a", "e89a5a", "ffd0a0")
DRAGON = ramp("5a3a08", "b07a14", "e8b030", "ffe07a", "fff6c8")
TREES = {
    "sword": ("123262", "4db8ff"),
    "katana": ("3a1c48", "ff9ecc"),
    "axe": ("4a1c0a", "ff8026"),
    "pistol": ("3e2c10", "ffbf40"),
    "dual": ("0f3a44", "5ae6f2"),
    "corsair": ("4a1210", "ff5742"),
    "dagger": ("3a0c22", "f22660"),
    "dual_dagger": ("163a10", "72f24c"),
    "polearm": ("2a2058", "ffe652"),
    "hammer": ("3a3026", "ebcc94"),
    "greatsword": ("0f3a30", "bcffe0"),
    "dual_axe": ("14285c", "aee6ff"),
    "black_leg": ("4a0c12", "ff2c29"),
    "unarmed": ("5a3a1a", "fff2d9"),
    "rapier": ("2a3344", "c8d6ea"),
    "staff": ("2c3a12", "c8e04a"),
    "sickle": ("0e2e36", "8affd0"),
    "slingshot": ("4a1236", "ff61b8"),
    "long_gun": ("1c1e5a", "b8d6ff"),
    "cannon": ("3a1a58", "ffcc38"),
    "base": ("1a343c", "65c9c0"),
    "ember": ("5a2206", "ffa02a"),
    "wolf": ("2e2440", "b8a8e8"),
    "vine": ("143a1e", "5fd06a"),
    "perk": ("22263e", "f2c94c"),
    "move_ground": ("163a52", "8ad8ff"),
    "move_air": ("163a52", "8ad8ff"),
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
def cutlass(ic, hilt, tip, bend=0.09, w=0.12, guard=True, steel=None):
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
    ic.part(ic.poly(left + right[::-1]), STEEL if steel is None else steel, metal=True, shadow=0.045)
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


# ----------------------------------------------------------------------------------------------------------------
# Pieces for the heavy weapons
# ----------------------------------------------------------------------------------------------------------------
def spear(ic, butt, tip, w=0.07):
    """A spear from its butt to its point: the shaft, a gold collar with a red tassel, a leaf-shaped head."""
    dx, dy = tip[0] - butt[0], tip[1] - butt[1]
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux
    head = min(ln * 0.26, w * 5.0)
    sk = (tip[0] - ux * head, tip[1] - uy * head)
    ic.part(ic.capsule(butt, sk, w), WOOD, shadow=0.03)
    ic.part(ic.circle((sk[0] - ux * w * 1.3 + px * w * 0.9, sk[1] - uy * w * 1.3 + py * w * 0.9), w * 0.7), CLOTH, shadow=0.03)
    belly = (sk[0] + ux * head * 0.36, sk[1] + uy * head * 0.36)
    ic.part(ic.poly([(sk[0] + px * w * 0.55, sk[1] + py * w * 0.55), (belly[0] + px * w * 1.35, belly[1] + py * w * 1.35), tip,
        (belly[0] - px * w * 1.35, belly[1] - py * w * 1.35), (sk[0] - px * w * 0.55, sk[1] - py * w * 0.55)]), STEEL, metal=True, shadow=0.04)
    ic.part(ic.capsule((sk[0] - ux * w * 0.5, sk[1] - uy * w * 0.5), (sk[0] + ux * w * 0.3, sk[1] + uy * w * 0.3), w * 1.5), GOLD, metal=True, shadow=0.03)


def hammer(ic, butt, angle, size, flip=False):
    """A war hammer: the haft from `butt` along `angle`, a great square head across its far end, iron-faced."""
    f = Frame(butt, angle, size, flip)
    ic.part(ic.capsule(f.pt(0, 0), f.pt(0.84, 0), 0.085 * size), WOOD, shadow=0.035)
    ic.part(ic.capsule(f.pt(0.04, 0), f.pt(0.20, 0), 0.105 * size), LEATHER, shadow=0.03)
    ic.part(ic.poly(f.pts([(0.76, -0.34), (1.08, -0.34), (1.08, 0.34), (0.76, 0.34)])), STEEL, metal=True, shadow=0.06)
    ic.part(ic.poly(f.pts([(0.73, -0.42), (1.11, -0.42), (1.11, -0.29), (0.73, -0.29)])), IRON, metal=True, shadow=0.03)
    ic.part(ic.poly(f.pts([(0.73, 0.29), (1.11, 0.29), (1.11, 0.42), (0.73, 0.42)])), IRON, metal=True, shadow=0.03)
    ic.part(ic.circle(f.pt(0.92, 0.0), 0.075 * size), GOLD, metal=True, shadow=0.03)
    ic.part(ic.circle(f.pt(0, 0), 0.06 * size), GOLD, metal=True, shadow=0.03)


def greatsword(ic, hilt, tip, w=0.20):
    """A greatsword from its pommel to its point: a broad straight blade with a fuller, a wide crossguard, a long grip."""
    dx, dy = tip[0] - hilt[0], tip[1] - hilt[1]
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux
    b0 = (hilt[0] + ux * ln * 0.26, hilt[1] + uy * ln * 0.26)
    bl = ln * 0.74
    sh = (b0[0] + ux * bl * 0.80, b0[1] + uy * bl * 0.80)
    ic.part(ic.poly([(b0[0] + px * w * 0.5, b0[1] + py * w * 0.5), (sh[0] + px * w * 0.5, sh[1] + py * w * 0.5), tip,
        (sh[0] - px * w * 0.5, sh[1] - py * w * 0.5), (b0[0] - px * w * 0.5, b0[1] - py * w * 0.5)]), STEEL, metal=True, shadow=0.045)
    ic.flat(ic.capsule((b0[0] + ux * bl * 0.06, b0[1] + uy * bl * 0.06), (b0[0] + ux * bl * 0.62, b0[1] + uy * bl * 0.62), w * 0.2), STEEL[1])
    ic.part(ic.capsule(hilt, b0, w * 0.36), LEATHER, shadow=0.03)
    ic.part(ic.capsule((b0[0] - px * w * 1.15, b0[1] - py * w * 1.15), (b0[0] + px * w * 1.15, b0[1] + py * w * 1.15), w * 0.36), GOLD, metal=True, shadow=0.035)
    ic.part(ic.circle(hilt, w * 0.28), GOLD, metal=True, shadow=0.03)


def ground(ic, y=0.86, mat=STONE):
    ic.part(ic.poly([(0.0, 1.0), (0.0, y + 0.02), (0.30, y - 0.02), (0.50, y + 0.03), (0.72, y - 0.02), (1.0, y + 0.02), (1.0, 1.0)]), mat, shadow=0.04)


def shard(ic, x, y, h, w=0.10, lean=0.0, mat=STONE):
    ic.part(ic.poly([(x - w, y), (x + lean, y - h), (x + w, y)]), mat, shadow=0.04)


# ----------------------------------------------------------------------------------------------------------------
# Polearm (storm)
# ----------------------------------------------------------------------------------------------------------------
def hundred_thrusts(ic):
    # "drive the point out seven times in a second": the head driven home, the thrusts before it fanned behind
    for ang in (-34.0, -17.0, 17.0, 34.0):
        a = math.radians(ang)
        o = (0.10, 0.50)
        ic.glow(ic.lens((o[0] + math.cos(a) * 0.18, o[1] + math.sin(a) * 0.18), (o[0] + math.cos(a) * 0.86, o[1] + math.sin(a) * 0.86), 0.12), BOLT, depth=0.045)
    spear(ic, (-1.00, 0.50), (0.93, 0.50), w=0.10)


def dragon_sweep(ic):
    # "swing the spear round twice at the shins": the two low turns, the spear lying in them
    ic.glow(ic.path(arc((0.50, 0.66), 0.50, 160.0, 400.0, 0.46), 0.03, 0.15), BOLT, depth=0.055)
    ic.glow(ic.path(arc((0.50, 0.66), 0.30, 330.0, 560.0, 0.46), 0.02, 0.10), VIOLET, depth=0.04)
    spear(ic, (-0.20, 0.16), (0.90, 0.72), w=0.08)


def vault_strike(ic):
    # "vault over the enemy ... driving the point down into them as you come over"
    ic.glow(ic.path(arc((0.50, 0.70), 0.52, 180.0, 330.0), 0.03, 0.13), BOLT, depth=0.05)
    ground(ic, 0.88)
    ic.glow(ic.star((0.62, 0.84), 0.20, 6, 0.4, 0.5), VIOLET, depth=0.07, ink=True)
    spear(ic, (0.96, -0.50), (0.62, 0.84), w=0.10)


def thunder_javelin(ic):
    # "Hurl the spear point-first ... a crackle of lightning yanks it back to your hand"
    ic.glow(ic.path([(-0.04, 0.60), (0.20, 0.72), (0.26, 0.46), (0.50, 0.58), (0.56, 0.30), (0.80, 0.40)], 0.10, 0.06), BOLT, depth=0.04, ink=True)
    spear(ic, (-0.30, 1.22), (0.94, 0.08), w=0.09)


def windmill_guard(ic):
    # "spin the pole before you like a windmill ... blows and shots from the front are batted aside"
    ic.glow(ic.circle((0.50, 0.50), 0.47) & ~ic.circle((0.50, 0.50), 0.38), BOLT, depth=0.04)
    for ang in (20.0, 80.0):
        a = math.radians(ang)
        ic.part(ic.capsule((0.5 - math.cos(a) * 0.44, 0.5 - math.sin(a) * 0.44), (0.5 + math.cos(a) * 0.44, 0.5 + math.sin(a) * 0.44), 0.06), WOOD, shadow=0.03)
    a = math.radians(140.0)
    spear(ic, (0.5 - math.cos(a) * 0.46, 0.5 - math.sin(a) * 0.46), (0.5 + math.cos(a) * 0.50, 0.5 + math.sin(a) * 0.50), w=0.07)
    ic.part(ic.circle((0.50, 0.50), 0.07), GOLD, metal=True, shadow=0.03)
    for x, y in ((0.90, 0.20), (0.94, 0.62)):
        ic.glow(ic.star((x, y), 0.09, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def raijin_wheel(ic):
    # "spinning the spear over your head into a wheel ... the wheel bursts"
    ic.glow(ic.circle((0.50, 0.50), 0.46) & ~ic.circle((0.50, 0.50), 0.33), BOLT, depth=0.05)
    for k in range(4):
        a = math.radians(k * 90.0 + 10.0)
        b = a + 0.5
        ic.glow(ic.path([(0.5 + math.cos(a) * 0.14, 0.5 + math.sin(a) * 0.14), (0.5 + math.cos(b) * 0.26, 0.5 + math.sin(b) * 0.26), (0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.36)], 0.07, 0.04), VIOLET, depth=0.03)
    spear(ic, (0.14, 0.90), (0.88, 0.10), w=0.075)


def heavens_pike(ic):
    # "Hurl the spear straight up: it comes down on the reticle as a bolt, and ... a storm round it"
    ic.glow(ic.poly(oval((0.50, 0.84), 0.50, 0.17)) & ~ic.poly(oval((0.50, 0.84), 0.34, 0.09)), VIOLET, depth=0.04)
    ic.glow(ic.path([(0.62, -0.04), (0.40, 0.20), (0.60, 0.34), (0.44, 0.54)], 0.16, 0.10), BOLT, depth=0.05, ink=True)
    spear(ic, (0.34, -0.20), (0.50, 0.86), w=0.085)
    ic.glow(ic.star((0.50, 0.86), 0.14, 6, 0.4, 0.2), SPARK, depth=0.05, ink=True)


# ----------------------------------------------------------------------------------------------------------------
# Hammer (earth)
# ----------------------------------------------------------------------------------------------------------------
def skullcracker(ic):
    # "the head brought straight down on the enemy in front": the skull, the hammer on it
    ic.part(ic.circle((0.50, 0.76), 0.24) | ic.poly([(0.36, 0.84), (0.64, 0.84), (0.61, 1.04), (0.39, 1.04)]), BONE, shadow=0.06)
    ic.flat(ic.circle((0.40, 0.80), 0.06) | ic.circle((0.60, 0.80), 0.06) | ic.poly([(0.50, 0.86), (0.46, 0.93), (0.54, 0.93)]), INK)
    ic.flat(ic.path([(0.50, 0.54), (0.46, 0.62), (0.53, 0.68), (0.49, 0.74)], 0.03), INK)
    ic.glow(ic.star((0.50, 0.54), 0.26, 8, 0.42, 0.2), SPARK, depth=0.08, ink=True)
    hammer(ic, (0.50, -0.62), 90.0, 1.0)


def rolling_quake(ic):
    # "Three slams stepping forward ... each a shockwave wider than the last"
    ground(ic, 0.84)
    for r, w0 in ((0.30, 0.07), (0.52, 0.09), (0.76, 0.11)):
        ic.glow(ic.path(arc((0.14, 0.84), r, -78.0, -6.0), 0.03, w0), DUST, depth=0.035, ink=True)
    hammer(ic, (0.02, -0.26), 78.0, 0.92)


def cyclone_crusher(ic):
    # "Let the hammer out at arm's length and spin three times"
    ic.glow(ic.path(arc((0.50, 0.50), 0.46, 60.0, 330.0), 0.03, 0.17), DUST, depth=0.06)
    hammer(ic, (0.42, 0.56), -30.0, 0.50)


def cannonball_swing(ic):
    # "drive it low and up through the enemy in front like a golf swing: ... a light foe is launched ten paces flying"
    ic.glow(ic.path(arc((0.42, 0.40), 0.50, 150.0, 20.0), 0.03, 0.14), DUST, depth=0.05)
    ic.glow(ic.path([(0.46, 0.60), (0.66, 0.36), (0.84, 0.16)], 0.03, 0.14), SPARK, depth=0.05)
    ic.part(ic.circle((0.84, 0.16), 0.13), SHADE, metal=True, shadow=0.05)
    hammer(ic, (-0.30, 0.20), 34.0, 0.80)


def anvil_counter(ic):
    # "the first blow rings off you like a hammer on an anvil": the anvil, the blow ringing off it
    ic.part(ic.poly([(0.04, 0.54), (0.26, 0.48), (0.92, 0.48), (0.92, 0.62), (0.66, 0.64), (0.60, 0.78), (0.78, 0.88), (0.78, 1.02), (0.22, 1.02), (0.22, 0.88),
        (0.40, 0.78), (0.36, 0.64), (0.04, 0.60)]), IRON, metal=True, shadow=0.06)
    ic.glow(ic.star((0.58, 0.34), 0.30, 8, 0.4, 0.2), SPARK, depth=0.09, ink=True)
    for x, y in ((0.14, 0.24), (0.90, 0.16)):
        ic.glow(ic.star((x, y), 0.08, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def titans_fall(ic):
    # "the ground breaks in a great ring that throws everyone down, stone heaves up under them"
    ic.glow(ic.poly(oval((0.50, 0.80), 0.52, 0.19)) & ~ic.poly(oval((0.50, 0.80), 0.34, 0.10)), DUST, depth=0.05)
    for x, h, lean in ((0.08, 0.34, -0.06), (0.26, 0.24, -0.03), (0.76, 0.26, 0.03), (0.93, 0.36, 0.06)):
        shard(ic, x, 0.84, h, 0.09, lean)
    ground(ic, 0.90)
    ic.glow(ic.star((0.50, 0.80), 0.20, 8, 0.4, 0.2), SPARK, depth=0.07, ink=True)
    hammer(ic, (0.50, -0.40), 90.0, 0.92)


def mountain_breaker(ic):
    # "Three slams walking forward, each a longer line of heaving stone"
    ic.glow(ic.poly([(0.0, 0.92), (0.10, 0.70), (0.34, 0.56), (0.62, 0.34), (0.86, 0.10), (1.0, 0.10), (1.0, 0.92)]), DUST, depth=0.10)
    ground(ic, 0.90)
    for x, h, w in ((0.16, 0.24, 0.10), (0.42, 0.44, 0.13), (0.74, 0.74, 0.17)):
        shard(ic, x - w * 0.9, 0.90, h * 0.6, w * 0.7, -0.03)
        shard(ic, x, 0.90, h, w, 0.04)
        ic.flat(ic.path([(x, 0.90), (x + 0.02, 0.90 - h * 0.4), (x - 0.01, 0.90 - h * 0.6)], 0.022), INK)


# ----------------------------------------------------------------------------------------------------------------
# Greatsword (gale)
# ----------------------------------------------------------------------------------------------------------------
def guardbreaker(ic):
    # "knocks their guard up, then bring the blade straight down on them": the shield split, the blade through it
    ic.part(ic.circle((0.46, 0.56), 0.40), WOOD, shadow=0.08)
    ic.part((ic.circle((0.46, 0.56), 0.40) & ~ic.circle((0.46, 0.56), 0.33)) | ic.circle((0.46, 0.56), 0.11), IRON, metal=True, shadow=0.04)
    ic.flat(ic.path([(0.60, 0.20), (0.50, 0.38), (0.56, 0.52), (0.42, 0.70), (0.48, 0.92)], 0.05), INK)
    ic.glow(ic.star((0.54, 0.44), 0.18, 6, 0.4, 0.2), SPARK, depth=0.06, ink=True)
    greatsword(ic, (1.30, -0.62), (0.44, 0.74), w=0.19)


def crescent_gale(ic):
    # "One huge flat sweep ... flings a crescent of air off the edge"
    ic.glow(ic.circle((0.46, 0.86), 0.66) & ~ic.circle((0.42, 1.04), 0.70), GALE, depth=0.10)
    ic.glow(ic.lens((0.10, 0.62), (0.40, 0.52), 0.05), GALE, depth=0.03)
    greatsword(ic, (-0.70, 1.02), (0.96, 0.80), w=0.20)


def updraft(ic):
    # "A rising cut that tears a gust up under the enemy ... and throws them high"
    for sgn in (-1.0, 1.0):
        ic.glow(ic.path([(0.5 + sgn * 0.14, 1.02), (0.5 + sgn * 0.40, 0.70), (0.5 + sgn * 0.30, 0.40), (0.5 + sgn * 0.44, 0.08)], 0.16, 0.04), GALE, depth=0.05)
    ic.glow(ic.poly([(0.38, 0.30), (0.50, 0.02), (0.62, 0.30)]), GALE, depth=0.06)
    greatsword(ic, (0.50, 1.50), (0.50, 0.16), w=0.20)


def gatekeeper(ic):
    # "drive the blade point-down before you like a gate ... every blow and shot from the front stops on the flat"
    ground(ic, 0.88)
    ic.glow(ic.path(arc((0.64, 0.46), 0.50, 130.0, 230.0), 0.05, 0.05), GALE, depth=0.03)
    ic.glow(ic.path(arc((0.36, 0.46), 0.50, -50.0, 50.0), 0.05, 0.05), GALE, depth=0.03)
    greatsword(ic, (0.50, -0.14), (0.50, 0.94), w=0.24)
    for x, y in ((0.10, 0.34), (0.92, 0.52), (0.14, 0.70)):
        ic.glow(ic.star((x, y), 0.085, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def tempest_turns(ic):
    # "Let the blade carry you round three times ... each turn quicker than the last"
    for turn in (0.0, 120.0, 240.0):
        pts = []
        for k in range(9):
            t = k / 8.0
            a = math.radians(turn + 210.0 * t)
            r = 0.50 * (1.0 - 0.60 * t)
            pts.append((0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r))
        ic.glow(ic.path(pts, 0.04, 0.13), GALE, depth=0.05)
    greatsword(ic, (0.36, 0.64), (0.96, 0.04), w=0.14)


def skysplitter(ic):
    # "come down in one cleave: the ground splits in a line twelve paces long"
    ic.glow(ic.lens((0.50, -0.20), (0.50, 1.20), 0.34), GALE, depth=0.10)
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.72), (0.24, 0.68), (0.42, 0.74), (0.36, 1.0)]), STONE, shadow=0.05)
    ic.part(ic.poly([(1.0, 1.0), (1.0, 0.72), (0.76, 0.68), (0.58, 0.74), (0.64, 1.0)]), STONE, shadow=0.05)
    greatsword(ic, (0.50, -0.70), (0.50, 0.80), w=0.20)


def eye_of_storm(ic):
    # "a cyclone 7 m round you drags them in": the storm from above, the still eye in its middle
    for turn in (0.0, 90.0, 180.0, 270.0):
        pts = []
        for k in range(9):
            t = k / 8.0
            a = math.radians(turn + 200.0 * t)
            r = 0.56 * (1.0 - 0.66 * t)
            pts.append((0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r))
        ic.glow(ic.path(pts, 0.03, 0.16), GALE, depth=0.06)
    ic.part(ic.circle((0.50, 0.50), 0.13), SHADE, shadow=0.04)
    ic.glow(ic.star((0.50, 0.50), 0.09, 4, 0.3, 0.0), SPARK, depth=0.03)


# ----------------------------------------------------------------------------------------------------------------
# Twin axes (frost)
# ----------------------------------------------------------------------------------------------------------------
def gallows_hook(ic):
    # "Fling the left axe round the enemy ... and haul them in by the beard"
    for y in (0.24, 0.40):
        ic.glow(ic.lens((0.02, y), (0.46, y - 0.03), 0.06), ICE, depth=0.03)
    bust(ic, (0.76, 0.70), 0.50, SHADE)
    axe(ic, (-0.40, 0.24), 6.0, 0.86)


def hewing_frenzy(ic):
    # "Eight chops trading hands as fast as you can swing them"
    for k, (x, y) in enumerate(((0.20, 0.20), (0.34, 0.10), (0.66, 0.10), (0.80, 0.20))):
        ic.glow(ic.lens((x - 0.10, y + 0.16), (x + 0.10, y - 0.06), 0.07), ICE, depth=0.03)
    axe(ic, (0.26, 1.18), -64.0, 0.92)
    axe(ic, (0.74, 1.18), -116.0, 0.92, flip=True)
    ic.glow(ic.star((0.50, 0.74), 0.12, 4, 0.3, 0.0), SPARK, depth=0.05, ink=True)


def axestorm(ic):
    # "whirl four times with both axes out"
    for turn in (0.0, 180.0):
        ic.glow(ic.path(arc((0.50, 0.50), 0.48, turn + 95.0, turn + 250.0), 0.03, 0.15), ICE, depth=0.055)
    axe(ic, (0.50, 0.50), -42.0, 0.50)
    axe(ic, (0.50, 0.50), 138.0, 0.50)
    ic.part(ic.circle((0.50, 0.50), 0.08), GOLD, metal=True, shadow=0.03)
    for x, y in ((0.14, 0.16), (0.88, 0.86)):
        ic.flat(ic.star((x, y), 0.07, 4, 0.25, 0.0), hx("ffffff"))


def ravens_return(ic):
    # "they fly out on two crossing arcs ... then curve back to your hands"
    ic.glow(ic.path(arc((0.30, 0.86), 0.62, -100.0, -20.0), 0.03, 0.12), ICE, depth=0.045)
    ic.glow(ic.path(arc((0.70, 0.86), 0.62, -80.0, -160.0), 0.03, 0.12), ICE, depth=0.045)
    axe(ic, (0.52, 0.52), -40.0, 0.50)
    axe(ic, (0.48, 0.52), -140.0, 0.50, flip=True)


def raiders_haul(ic):
    # "Hook the enemy in front by the beard and swing them round you once at arm's length"
    ic.glow(ic.path(arc((0.46, 0.56), 0.44, 100.0, 380.0), 0.03, 0.14), ICE, depth=0.05)
    bust(ic, (0.82, 0.30), 0.34, SHADE)
    axe(ic, (0.20, 0.96), -58.0, 0.70)


def fimbulwinter(ic):
    # "both crashed into the ground: a great ring throws them all down, and with the frost, ice"
    ic.part(ic.poly([(0.0, 1.0), (0.04, 0.86), (0.50, 0.80), (0.96, 0.86), (1.0, 1.0)]), ICE, shadow=0.04)
    shards = [[(0.50, 0.00), (0.66, 0.50), (0.58, 0.88), (0.40, 0.88), (0.34, 0.50)],
        [(0.14, 0.24), (0.34, 0.54), (0.36, 0.90), (0.18, 0.90), (0.10, 0.58)],
        [(0.88, 0.18), (0.90, 0.58), (0.80, 0.90), (0.62, 0.90), (0.68, 0.52)],
        [(0.30, 0.54), (0.44, 0.72), (0.42, 0.94), (0.26, 0.94)],
        [(0.72, 0.58), (0.76, 0.94), (0.58, 0.94), (0.58, 0.74)]]
    for k in (1, 2, 0, 3, 4):
        ic.part(ic.poly(shards[k]), ICE, metal=True, shadow=0.07)
    for x, y in ((0.12, 0.12), (0.90, 0.08)):
        ic.flat(ic.star((x, y), 0.07, 4, 0.25, 0.0), hx("ffffff"))


def avalanche(ic):
    # "a field of ice ... that freezes everyone in it, then shatters under them"
    ic.part(ic.poly([(0.22, 0.98), (0.10, 0.50), (0.30, 0.08), (0.66, 0.04), (0.90, 0.44), (0.80, 0.98)]), ICE, metal=True, shadow=0.09)
    ic.flat(ic.circle((0.50, 0.42), 0.13) | ic.poly([(0.30, 0.94), (0.34, 0.62), (0.50, 0.54), (0.66, 0.62), (0.70, 0.94)]), hx("27468e"))
    ic.flat(ic.path([(0.30, 0.10), (0.42, 0.30), (0.34, 0.46)], 0.025) | ic.path([(0.84, 0.44), (0.70, 0.56), (0.76, 0.74)], 0.025), hx("ffffff"))
    for x, h in ((0.06, 0.20), (0.94, 0.26)):
        shard(ic, x, 1.0, h, 0.08, 0.0, ICE)


# ----------------------------------------------------------------------------------------------------------------
# Pieces for the bare-handed trees and the rapier
# ----------------------------------------------------------------------------------------------------------------
def leg(ic, hip, knee, ankle, toe, w=0.15, hot=False):
    """A kicking leg in dark trousers and a polished shoe, from the hip; `hot`: the shin and foot glowing red-hot."""
    if hot:
        ic.glow(ic.path([knee, ankle, toe], w * 2.3, w * 2.0), HEAT, depth=w * 0.55)
    ic.part(ic.capsule(hip, knee, w), SHADE, shadow=0.04)
    ic.part(ic.capsule(knee, ankle, w * 0.86), SHADE, shadow=0.04)
    ic.part(ic.path([ankle, toe], w * 1.0, w * 0.72), IRON, metal=True, shadow=0.035)
    ic.part(ic.circle((ankle[0] + (toe[0] - ankle[0]) * 0.35, ankle[1] + (toe[1] - ankle[1]) * 0.35), w * 0.2), GOLD, metal=True, shadow=0.02)


def fist_front(ic, c, size, wrist=True, skin=None):
    """A fist seen knuckles-on: four fingers folded in a row, the thumb laid across under them, the wrist bound."""
    x, y = c
    sk = SKIN if skin is None else skin
    if wrist:
        ic.part(ic.poly([(x - 0.30 * size, y + 0.42 * size), (x + 0.30 * size, y + 0.42 * size), (x + 0.26 * size, y + 0.84 * size), (x - 0.26 * size, y + 0.84 * size)]), BONE, shadow=0.03)
    ic.part(ic.poly([(x - 0.46 * size, y - 0.04 * size), (x + 0.46 * size, y - 0.04 * size), (x + 0.46 * size, y + 0.38 * size), (x + 0.34 * size, y + 0.50 * size),
        (x - 0.34 * size, y + 0.50 * size), (x - 0.46 * size, y + 0.38 * size)]), sk, shadow=0.05)
    for dx in (-0.345, -0.115, 0.115, 0.345):
        ic.part(ic.capsule((x + dx * size, y - 0.26 * size), (x + dx * size, y + 0.06 * size), 0.215 * size), sk, shadow=0.04)
    ic.part(ic.capsule((x - 0.40 * size, y + 0.22 * size), (x + 0.14 * size, y + 0.30 * size), 0.21 * size), sk, shadow=0.04)


def palm_front(ic, c, size):
    """An open hand held up, palm out."""
    x, y = c
    ic.part(ic.poly([(x - 0.26 * size, y + 0.44 * size), (x + 0.26 * size, y + 0.44 * size), (x + 0.24 * size, y + 0.84 * size), (x - 0.24 * size, y + 0.84 * size)]), BONE, shadow=0.03)
    ic.part(ic.capsule((x - 0.38 * size, y + 0.22 * size), (x - 0.66 * size, y - 0.10 * size), 0.18 * size), SKIN, shadow=0.04)
    for dx, top in ((-0.30, -0.52), (-0.10, -0.66), (0.10, -0.62), (0.30, -0.44)):
        ic.part(ic.capsule((x + dx * size, y), (x + dx * size, y + top * size), 0.185 * size), SKIN, shadow=0.04)
    ic.part(ic.poly([(x - 0.42 * size, y - 0.06 * size), (x + 0.42 * size, y - 0.06 * size), (x + 0.40 * size, y + 0.40 * size), (x + 0.28 * size, y + 0.50 * size),
        (x - 0.28 * size, y + 0.50 * size), (x - 0.40 * size, y + 0.40 * size)]), SKIN, shadow=0.06)
    ic.flat(ic.path(arc((x + 0.02 * size, y + 0.10 * size), 0.22 * size, 30.0, 150.0), 0.03 * size), hx("a25c46"))


def dragon_head(ic, at, angle, size, mat, mane):
    """A dragon's head in profile, jaws open along `angle`: horned, maned, whiskered."""
    f = Frame(at, angle, size)
    ic.part(ic.poly(f.pts([(-0.40, 0.34), (-0.92, 0.36), (-0.66, 0.14), (-0.98, -0.06), (-0.64, -0.12), (-0.86, -0.44), (-0.50, -0.30), (-0.30, -0.20)])), mane, shadow=0.05)
    ic.part(ic.poly(f.pts([(-0.34, -0.28), (-0.66, -0.80), (-0.12, -0.34)])), BONE, shadow=0.03)
    ic.flat(ic.poly(f.pts([(-0.04, 0.16), (0.62, 0.08), (0.64, 0.24), (0.06, 0.30)])), hx("5a0c14"))
    ic.part(ic.poly(f.pts([(-0.30, 0.30), (0.14, 0.24), (0.60, 0.24), (0.74, 0.36), (0.30, 0.50), (-0.22, 0.56)])), mat, shadow=0.05)
    ic.part(ic.poly(f.pts([(-0.56, 0.24), (-0.52, -0.24), (-0.12, -0.34), (0.28, -0.24), (0.68, -0.18), (0.88, 0.00), (0.62, 0.10), (0.20, 0.14), (-0.10, 0.32)])), mat, shadow=0.07)
    ic.flat(ic.poly(f.pts([(0.44, 0.11), (0.53, 0.10), (0.49, 0.24)])) | ic.poly(f.pts([(0.24, 0.13), (0.32, 0.13), (0.29, 0.25)])), hx("ffffff"))
    ic.flat(ic.lens(f.pt(-0.02, -0.12), f.pt(0.20, -0.06), 0.09 * size), hx("ffffff"))
    ic.flat(ic.circle(f.pt(0.10, -0.085), 0.03 * size), INK)
    ic.flat(ic.circle(f.pt(0.76, -0.04), 0.03 * size), INK)
    ic.flat(ic.path(f.pts([(0.82, 0.06), (1.02, 0.14), (1.06, 0.36)]), 0.035 * size), mat[3])


def rapier(ic, hilt, tip, w=0.05):
    """A rapier from its pommel to its point: a needle of a blade, a gold cup and knuckle bow."""
    dx, dy = tip[0] - hilt[0], tip[1] - hilt[1]
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux
    b0 = (hilt[0] + ux * ln * 0.20, hilt[1] + uy * ln * 0.20)
    ic.part(ic.poly([(b0[0] + px * w * 0.5, b0[1] + py * w * 0.5), tip, (b0[0] - px * w * 0.5, b0[1] - py * w * 0.5)]), STEEL, metal=True, shadow=0.02)
    ic.part(ic.capsule(hilt, b0, w * 0.9), LEATHER, shadow=0.03)
    ic.part(ic.path([(b0[0] + px * w * 2.2, b0[1] + py * w * 2.2), ((hilt[0] + b0[0]) / 2 + px * w * 2.7, (hilt[1] + b0[1]) / 2 + py * w * 2.7),
        (hilt[0] + px * w * 0.9, hilt[1] + py * w * 0.9)], w * 0.7), GOLD, metal=True, shadow=0.025)
    c = (b0[0] + ux * w * 0.5, b0[1] + uy * w * 0.5)
    ic.part(ic.poly([(c[0] + px * math.cos(a) * w * 2.5 + ux * math.sin(a) * w * 1.3, c[1] + py * math.cos(a) * w * 2.5 + uy * math.sin(a) * w * 1.3)
        for a in np.linspace(0, 2 * math.pi, 16, endpoint=False)]), GOLD, metal=True, shadow=0.035)
    ic.part(ic.circle(hilt, w * 0.9), GOLD, metal=True, shadow=0.03)


def ghost_bust(ic, c, s, mat):
    """Someone's image: a flat glowing shape of them."""
    m = ic.poly([(c[0] - s * 0.62, c[1] + s * 0.95), (c[0] - s * 0.50, c[1] + s * 0.30), (c[0], c[1] + s * 0.12), (c[0] + s * 0.50, c[1] + s * 0.30),
        (c[0] + s * 0.62, c[1] + s * 0.95)]) | ic.circle((c[0], c[1] - s * 0.18), s * 0.36)
    ic.glow(m, mat, depth=s * 0.22, ink=True)


# ----------------------------------------------------------------------------------------------------------------
# Black-leg (heat)
# ----------------------------------------------------------------------------------------------------------------
def rising_heel(ic):
    # "swing your heel straight up under their chin": the leg straight up, the arc it came through
    ic.glow(ic.path(arc((0.30, 0.86), 0.66, -5.0, -85.0), 0.03, 0.16), HEAT, depth=0.06)
    leg(ic, (0.10, 1.30), (0.30, 0.74), (0.50, 0.26), (0.68, 0.08), w=0.17)
    ic.glow(ic.star((0.74, 0.12), 0.14, 6, 0.4, 0.3), SPARK, depth=0.05, ink=True)


def hailstorm_heels(ic):
    # "a hail of snapping kicks at every height": the foot, and where it has just been
    for (x, y), dy in (((0.60, 0.16), -0.05), ((0.72, 0.44), 0.0), ((0.60, 0.74), 0.05)):
        ic.glow(ic.lens((0.10, y - dy * 2.0), (x - 0.12, y), 0.10), HEAT, depth=0.04)
        ic.part(ic.path([(x - 0.14, y - dy), (x + 0.20, y + dy)], 0.17, 0.12), IRON, metal=True, shadow=0.04)
        ic.glow(ic.star((x + 0.26, y + dy), 0.09, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def sky_chase(ic):
    # "Stamp on the air up to a foe you've launched": the shoe on a step of air, the steps below it
    for y, rx in ((0.92, 0.26), (0.72, 0.34)):
        ic.glow(ic.poly(oval((0.44, y), rx, rx * 0.30)) & ~ic.poly(oval((0.44, y), rx * 0.62, rx * 0.15)), HEAT, depth=0.03)
    ic.glow(ic.poly(oval((0.50, 0.50), 0.44, 0.14)) & ~ic.poly(oval((0.50, 0.50), 0.28, 0.07)), SPARK, depth=0.04, ink=True)
    leg(ic, (0.96, -0.36), (0.70, 0.06), (0.52, 0.36), (0.30, 0.42), w=0.18)


def cleaver_kick(ic):
    # "A high crescent kick so fast it cuts the air: a blade of it shoots off your foot"
    ic.glow(ic.circle((0.56, 0.46), 0.48) & ~ic.circle((0.36, 0.56), 0.50), HEAT, depth=0.09)
    leg(ic, (-0.30, 1.10), (0.06, 0.66), (0.36, 0.36), (0.56, 0.22), w=0.16)


def flambe_dash(ic):
    # "A hop as the leg heats, then a flying side kick that streaks five paces through the line"
    ic.glow(ic.poly([(-0.04, 0.30), (0.20, 0.36), (0.10, 0.50), (0.30, 0.52), (0.16, 0.68), (0.40, 0.70), (-0.04, 0.92)]), FIRE, depth=0.10)
    for y in (0.16, 0.90):
        ic.glow(ic.lens((0.04, y), (0.60, y), 0.05), HEAT, depth=0.025)
    leg(ic, (-0.40, 0.50), (0.20, 0.52), (0.62, 0.50), (0.92, 0.44), w=0.20, hot=True)


def last_course(ic):
    # "Spin on one foot until your leg glows red-hot ... and the heel brought down": the heel coming down, burning
    ic.glow(ic.poly([(0.30, 0.94), (0.14, 0.60), (0.30, 0.66), (0.26, 0.34), (0.44, 0.48), (0.50, 0.10), (0.62, 0.40), (0.82, 0.22), (0.78, 0.56),
        (0.96, 0.52), (0.84, 0.94)]), FIRE, depth=0.13)
    leg(ic, (1.20, -0.30), (0.90, 0.14), (0.62, 0.50), (0.44, 0.74), w=0.19, hot=True)
    ic.glow(ic.star((0.42, 0.80), 0.20, 8, 0.4, 0.2), SPARK, depth=0.07, ink=True)


def volcano_course(ic):
    # "Stamp the ground five times: it erupts under up to five foes"
    ground(ic, 0.84)
    for x, top, w in ((0.20, 0.34, 0.11), (0.50, 0.06, 0.15), (0.80, 0.30, 0.11)):
        ic.glow(ic.poly([(x - w, 0.86), (x - w * 0.7, top + 0.30), (x - w * 1.1, top + 0.18), (x - w * 0.3, top + 0.16), (x, top), (x + w * 0.4, top + 0.18),
            (x + w * 1.1, top + 0.14), (x + w * 0.7, top + 0.32), (x + w, 0.86)]), FIRE, depth=w * 0.75, ink=True)
        shard(ic, x - w * 1.5, 0.86, 0.12, 0.06, -0.02)
        shard(ic, x + w * 1.5, 0.86, 0.10, 0.05, 0.02)


# ----------------------------------------------------------------------------------------------------------------
# Unarmed
# ----------------------------------------------------------------------------------------------------------------
def hip_toss(ic):
    # "whoever threw it goes over your shoulder": your arms up, them upside down over you
    ic.glow(ic.path(arc((0.50, 0.96), 0.70, 195.0, 345.0), 0.04, 0.16), IMPACT, depth=0.06)
    c, sz = (0.52, 0.30), 0.44
    ic.part(ic.poly([(c[0] - sz * 0.62, c[1] - sz * 0.80), (c[0] - sz * 0.50, c[1] - sz * 0.15), (c[0], c[1] + sz * 0.03), (c[0] + sz * 0.50, c[1] - sz * 0.15),
        (c[0] + sz * 0.62, c[1] - sz * 0.80)]), SHADE, shadow=0.05)
    ic.part(ic.circle((c[0], c[1] + sz * 0.33), sz * 0.36), SHADE, shadow=0.05)
    for x0, x1 in ((0.26, 0.40), (0.76, 0.62)):
        ic.part(ic.capsule((x0, 1.10), (x1, 0.66), 0.13), SKIN, shadow=0.04)
        ic.part(ic.circle((x1, 0.62), 0.085), SKIN, shadow=0.03)
    ic.glow(ic.star((0.90, 0.80), 0.11, 6, 0.4, 0.2), SPARK, depth=0.04, ink=True)


def cannonball_fist(ic):
    # "they're launched down the line like a cannonball": the blow's ring, what it sent flying
    ic.glow(ic.poly(oval((0.20, 0.50), 0.15, 0.44)) & ~ic.poly(oval((0.20, 0.50), 0.08, 0.32)), IMPACT, depth=0.04)
    ic.glow(ic.lens((0.10, 0.50), (0.78, 0.50), 0.34), IMPACT, depth=0.09)
    for y, x0 in ((0.14, 0.34), (0.86, 0.34)):
        ic.glow(ic.lens((x0, y), (0.98, y), 0.055), IMPACT, depth=0.03)
    ic.part(ic.circle((0.72, 0.50), 0.22), SHADE, metal=True, shadow=0.08)


def meteor_fist(ic):
    # "a burning overhand driven into the ground: the earth cracks": the meteor it lands like
    ic.glow(ic.path([(1.06, -0.06), (0.78, 0.22), (0.46, 0.58)], 0.06, 0.40), FIRE, depth=0.10)
    ground(ic, 0.86)
    ic.flat(ic.path([(0.44, 0.84), (0.34, 0.92), (0.40, 1.0)], 0.035) | ic.path([(0.46, 0.84), (0.60, 0.90), (0.56, 1.0)], 0.03), INK)
    ic.part(ic.poly([(0.26, 0.60), (0.36, 0.44), (0.54, 0.42), (0.64, 0.56), (0.60, 0.76), (0.42, 0.82), (0.28, 0.74)]), STONE, shadow=0.07)
    for x, lean in ((0.12, -0.03), (0.84, 0.03)):
        shard(ic, x, 0.86, 0.18, 0.07, lean)
    ic.glow(ic.star((0.44, 0.84), 0.13, 6, 0.4, 0.2), SPARK, depth=0.05, ink=True)


def hundred_fists(ic):
    # "A blur of punches": fists, everywhere at once
    ic.glow(ic.star((0.50, 0.50), 0.56, 12, 0.6, 0.1), IMPACT, depth=0.09)
    for (x, y), sz in (((0.18, 0.22), 0.27), ((0.82, 0.20), 0.27), ((0.15, 0.76), 0.25), ((0.85, 0.76), 0.25)):
        fist_front(ic, (x, y), sz, wrist=False)
    fist_front(ic, (0.50, 0.46), 0.50)


def rising_dragon(ic):
    # "A leaping uppercut that launches you and everyone in front of you into the air": the dragon, rising
    pts = []
    for k in range(13):
        t = k / 12.0
        a = math.radians(160.0 + 400.0 * t)
        pts.append((0.46 + math.cos(a) * (0.42 - 0.22 * t), 0.98 - 0.70 * t + math.sin(a) * 0.05))
    ic.glow(ic.path(pts, 0.17, 0.07), IMPACT, depth=0.06)
    dragon_head(ic, (0.52, 0.46), -30.0, 0.56, DRAGON, CLOTH)


def palm_strike(ic):
    # "Drive an open palm forward: a burst of air hurls everything in a cone"
    for r, w0 in ((0.30, 0.06), (0.48, 0.08), (0.66, 0.10)):
        ic.glow(ic.path(arc((0.30, 0.46), r, -50.0, 50.0), w0 * 0.6, w0), IMPACT, depth=0.03, ink=True)
    palm_front(ic, (0.30, 0.52), 0.50)


def sea_king_fist(ic):
    # "Your fist takes the power and glows": the leviathan in it
    ic.glow(ic.poly([(-0.04, 1.04), (-0.04, 0.72), (0.14, 0.60), (0.30, 0.74), (0.50, 0.62), (0.70, 0.76), (0.88, 0.62), (1.04, 0.72), (1.04, 1.04)]), WATER, depth=0.09)
    ic.part(ic.path([(0.10, 1.04), (0.30, 0.78), (0.14, 0.50), (0.34, 0.30)], 0.24, 0.20), WATER, shadow=0.06)
    for x, y in ((0.16, 0.66), (0.20, 0.40)):
        ic.part(ic.poly([(x - 0.02, y - 0.06), (x - 0.16, y - 0.02), (x - 0.02, y + 0.06)]), CYAN, shadow=0.02)
    dragon_head(ic, (0.56, 0.34), 14.0, 0.60, WATER, CYAN)
    for x, y, r in ((0.90, 0.14, 0.04), (0.80, 0.58, 0.035)):
        ic.glow(ic.circle((x, y), r), WATER, depth=r, ink=True)


def typhoon_rush(ic):
    # "Walk into them under a storm of fists in a ring of wind"
    for turn in (0.0, 90.0, 180.0, 270.0):
        pts = []
        for k in range(9):
            t = k / 8.0
            a = math.radians(turn + 190.0 * t)
            r = 0.56 * (1.0 - 0.50 * t)
            pts.append((0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r))
        ic.glow(ic.path(pts, 0.03, 0.13), IMPACT, depth=0.05)
    for ang in (90.0, 210.0, 330.0):
        a = math.radians(ang)
        fist_front(ic, (0.5 + math.cos(a) * 0.25, 0.5 + math.sin(a) * 0.25), 0.26, wrist=False)


# ----------------------------------------------------------------------------------------------------------------
# Rapier (silver and glass)
# ----------------------------------------------------------------------------------------------------------------
def needle_rain(ic):
    # "Eight thrusts in under a second, the point everywhere at once"
    for k, (x, y) in enumerate(((0.30, 0.04), (0.56, 0.02), (0.80, 0.10), (0.94, 0.34), (0.98, 0.60))):
        ic.glow(ic.lens((x - 0.44, y + 0.50), (x, y), 0.045), SILVER, depth=0.02)
        ic.glow(ic.star((x, y), 0.06, 4, 0.3, 0.0), SPARK, depth=0.025)
    rapier(ic, (-0.06, 1.06), (0.78, 0.22), w=0.07)


def glass_step(ic):
    # "a silver image of you stays standing where you were ... while you thrust": the image, the thrust from beside it
    ghost_bust(ic, (0.38, 0.50), 0.60, SILVER)
    ic.flat(ic.lens((0.22, 0.30), (0.34, 0.14), 0.035) | ic.lens((0.46, 0.84), (0.56, 0.70), 0.03), hx("ffffff"))
    rapier(ic, (1.30, 0.98), (0.46, 0.50), w=0.07)


def glass_feint(ic):
    # "your mirror image is behind them; out of it you come with the real thrust": the looking-glass, the point out of it
    ic.part(ic.poly(oval((0.42, 0.46), 0.38, 0.44)), GOLD, metal=True, shadow=0.05)
    ic.glow(ic.poly(oval((0.42, 0.46), 0.30, 0.36)), SILVER, depth=0.14, ink=True)
    ic.flat(ic.lens((0.24, 0.40), (0.40, 0.18), 0.04), hx("ffffff"))
    ic.part(ic.capsule((0.42, 0.90), (0.42, 1.06), 0.12), GOLD, metal=True, shadow=0.03)
    ic.part(ic.poly([(0.40, 0.42), (0.48, 0.50), (0.99, 0.80)]), STEEL, metal=True, shadow=0.02)
    ic.glow(ic.star((0.45, 0.46), 0.11, 4, 0.3, 0.3), SPARK, depth=0.04, ink=True)


def balestra(ic):
    # "a hop forward and a lunge that covers seven paces in a blink"
    ic.glow(ic.lens((-0.05, 0.62), (0.90, 0.40), 0.18), SILVER, depth=0.06)
    for y, x1 in ((0.20, 0.50), (0.88, 0.60)):
        ic.glow(ic.lens((0.02, y), (x1, y - 0.03), 0.05), SILVER, depth=0.025)
    rapier(ic, (-0.26, 0.70), (0.97, 0.38), w=0.075)
    ic.glow(ic.star((0.95, 0.38), 0.09, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def hall_of_mirrors(ic):
    # "you are everywhere at once: a mirror image of you thrusts at each": the mirrors, a thrust out of each
    for x, top, lean in ((0.18, 0.14, -0.06), (0.50, 0.04, 0.0), (0.82, 0.14, 0.06)):
        ic.part(ic.poly([(x - 0.15 + lean, top), (x + 0.15 + lean, top), (x + 0.15, top + 0.74), (x - 0.15, top + 0.74)]), GOLD, metal=True, shadow=0.04)
        ic.glow(ic.poly([(x - 0.10 + lean, top + 0.05), (x + 0.10 + lean, top + 0.05), (x + 0.10, top + 0.69), (x - 0.10, top + 0.69)]), SILVER, depth=0.07, ink=True)
        ic.part(ic.poly([(x - 0.02 + lean * 0.5, top + 0.34), (x + 0.03 + lean * 0.5, top + 0.36), (0.50 + (x - 0.5) * 0.25, 1.02)]), STEEL, metal=True, shadow=0.02)


def silver_meridian(ic):
    # "hold the point on the line, still as glass; then one perfect lunge fourteen paces through everything on it"
    ic.glow(ic.circle((0.50, 0.50), 0.44) & ~ic.circle((0.50, 0.50), 0.36), SILVER, depth=0.03)
    ic.glow(ic.lens((-0.10, 0.50), (1.10, 0.50), 0.16), SILVER, depth=0.06)
    rapier(ic, (-0.30, 0.50), (0.96, 0.50), w=0.075)
    ic.glow(ic.star((0.94, 0.50), 0.10, 4, 0.25, 0.0), SPARK, depth=0.035, ink=True)


# ----------------------------------------------------------------------------------------------------------------
# Pieces for the staff, the chain sickle and the slingshot
# ----------------------------------------------------------------------------------------------------------------
def staff(ic, a, b, w=0.075):
    """A bo staff: wood, gold-capped, bound at the middle."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    ic.part(ic.capsule(a, b, w), WOOD, shadow=0.03)
    for t0, t1, mat in ((0.0, 0.07, GOLD), (0.93, 1.0, GOLD), (0.44, 0.56, CLOTH)):
        ic.part(ic.capsule((a[0] + dx * t0, a[1] + dy * t0), (a[0] + dx * t1, a[1] + dy * t1), w * 1.2), mat, metal=(mat is GOLD), shadow=0.025)


def leaf(ic, c, ang, size, mat=LEAF):
    a = math.radians(ang)
    e0 = (c[0] - math.cos(a) * size, c[1] - math.sin(a) * size)
    e1 = (c[0] + math.cos(a) * size, c[1] + math.sin(a) * size)
    ic.part(ic.lens(e0, e1, size * 1.05), mat, shadow=0.03)
    ic.flat(ic.capsule((c[0] - math.cos(a) * size * 0.6, c[1] - math.sin(a) * size * 0.6), (c[0] + math.cos(a) * size * 0.6, c[1] + math.sin(a) * size * 0.6), size * 0.12), mat[0])


def chain(ic, pts, link=0.05, mat=IRON):
    """A chain along the points: a link every `link`."""
    run = 0.0
    nxt = 0.0
    for k in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[k], pts[k + 1]
        seg = math.hypot(x1 - x0, y1 - y0)
        while nxt <= run + seg:
            t = (nxt - run) / max(seg, 1e-6)
            ic.part(ic.circle((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t), link * 0.52), mat, metal=True, shadow=0.02)
            nxt += link
        run += seg


def sickle(ic, at, angle, size, flip=False):
    """A kama: a short haft from `at` along `angle`, the hooked blade at its far end curving back to its right-hand side."""
    f = Frame(at, angle, size, flip)
    ic.part(ic.capsule(f.pt(0, 0), f.pt(0.74, 0), 0.10 * size), WOOD, shadow=0.03)
    ic.part(ic.capsule(f.pt(0.02, 0), f.pt(0.20, 0), 0.125 * size), LEATHER, shadow=0.025)
    c = f.pt(0.62, 0.42)
    outer, inner = [], []
    for k in range(13):
        t = k / 12.0
        a = math.radians(-110.0 + 175.0 * t)
        r_o = 0.46 * size
        r_i = (0.46 - 0.17 * (1.0 - t) ** 0.8) * size
        d = (math.cos(a), math.sin(a))
        o = Frame(c, angle, 1.0, flip)
        outer.append(o.pt(d[0] * r_o, d[1] * r_o))
        inner.append(o.pt(d[0] * r_i, d[1] * r_i))
    ic.part(ic.poly(outer + inner[::-1]), STEEL, metal=True, shadow=0.04)
    ic.part(ic.capsule(f.pt(0.70, -0.02), f.pt(0.80, -0.02), 0.15 * size), GOLD, metal=True, shadow=0.025)


def sling(ic, at, angle, size):
    """A slingshot: the fork up along `angle` from the grip at `at`, its band between the tines."""
    f = Frame(at, angle, size)
    ic.part(ic.capsule(f.pt(0, 0), f.pt(0.50, 0), 0.13 * size), WOOD, shadow=0.035)
    for v in (-0.30, 0.30):
        ic.part(ic.path([f.pt(0.46, 0), f.pt(0.66, v * 0.8), f.pt(1.0, v)], 0.12 * size, 0.10 * size), WOOD, shadow=0.035)
        ic.part(ic.capsule(f.pt(0.92, v), f.pt(1.0, v), 0.14 * size), CLOTH, shadow=0.02)
    ic.part(ic.capsule(f.pt(0.02, 0), f.pt(0.26, 0), 0.155 * size), LEATHER, shadow=0.03)


def pellet(ic, c, r, mat=SHADE):
    ic.part(ic.circle(c, r), mat, metal=True, shadow=r * 0.45)


def crane(ic, c, s):
    """A crane in flight, seen from the side, heading right: white, black-tipped wings, a red crown."""
    x, y = c
    ic.part(ic.poly([(x - 0.10 * s, y - 0.04 * s), (x - 0.50 * s, y - 0.62 * s), (x - 0.20 * s, y - 0.50 * s), (x + 0.16 * s, y - 0.08 * s)]), WHITE, shadow=0.04)
    ic.flat(ic.poly([(x - 0.50 * s, y - 0.62 * s), (x - 0.34 * s, y - 0.40 * s), (x - 0.24 * s, y - 0.50 * s)]), INK)
    ic.part(ic.poly(oval((x, y), 0.30 * s, 0.14 * s)), WHITE, shadow=0.04)
    ic.part(ic.path([(x + 0.22 * s, y - 0.04 * s), (x + 0.42 * s, y - 0.20 * s), (x + 0.56 * s, y - 0.30 * s)], 0.085 * s, 0.06 * s), WHITE, shadow=0.03)
    ic.part(ic.circle((x + 0.60 * s, y - 0.33 * s), 0.07 * s), WHITE, shadow=0.02)
    ic.flat(ic.circle((x + 0.59 * s, y - 0.385 * s), 0.04 * s), hx("e0242e"))
    ic.part(ic.poly([(x + 0.65 * s, y - 0.36 * s), (x + 0.86 * s, y - 0.32 * s), (x + 0.65 * s, y - 0.29 * s)]), GOLD, shadow=0.02)
    ic.part(ic.poly([(x - 0.04 * s, y + 0.06 * s), (x - 0.56 * s, y + 0.50 * s), (x - 0.20 * s, y + 0.46 * s), (x + 0.20 * s, y + 0.08 * s)]), WHITE, shadow=0.04)
    ic.flat(ic.poly([(x - 0.56 * s, y + 0.50 * s), (x - 0.36 * s, y + 0.34 * s), (x - 0.24 * s, y + 0.46 * s)]), INK)
    ic.flat(ic.capsule((x - 0.28 * s, y + 0.02 * s), (x - 0.66 * s, y + 0.10 * s), 0.03 * s), INK)


def wisp(ic, c, r, mat=SOUL):
    """A soul: a little flame with two dark eyes."""
    ic.glow(ic.circle(c, r) | ic.poly([(c[0] - r * 0.85, c[1] - r * 0.3), (c[0] + r * 0.3, c[1] - r * 2.3), (c[0] + r * 0.85, c[1] - r * 0.3)]), mat, depth=r * 0.9, ink=True)
    ic.flat(ic.circle((c[0] - r * 0.35, c[1]), r * 0.2) | ic.circle((c[0] + r * 0.35, c[1]), r * 0.2), INK)


# ----------------------------------------------------------------------------------------------------------------
# Staff (leaves and wind)
# ----------------------------------------------------------------------------------------------------------------
def leaf_wall(ic):
    # "Spin the staff before you so fast it's a wall": the wall of leaves it makes, the staff across it
    for (x, y), ang, mat in (((0.22, 0.24), 60.0, LEAF), ((0.52, 0.16), 95.0, AUTUMN), ((0.80, 0.26), 125.0, LEAF), ((0.14, 0.60), 20.0, AUTUMN),
            ((0.86, 0.62), 160.0, AUTUMN), ((0.30, 0.86), -30.0, LEAF), ((0.70, 0.86), 210.0, LEAF)):
        leaf(ic, (x, y), ang, 0.21, mat)
    ic.glow(ic.circle((0.50, 0.52), 0.25), LEAFWIND, depth=0.10)
    staff(ic, (0.04, 0.94), (0.96, 0.10), w=0.085)


def rising_gale(ic):
    # "The staff swept up under the enemy you face, throwing them high, and you up after them on the wind"
    for sgn in (-1.0, 1.0):
        ic.glow(ic.path([(0.5 + sgn * 0.10, 1.02), (0.5 + sgn * 0.42, 0.66), (0.5 + sgn * 0.26, 0.36), (0.5 + sgn * 0.40, 0.04)], 0.17, 0.04), LEAFWIND, depth=0.055)
    for (x, y), ang, mat in (((0.28, 0.20), -60.0, AUTUMN), ((0.72, 0.30), -110.0, LEAF), ((0.50, 0.10), -90.0, LEAF)):
        leaf(ic, (x, y), ang, 0.13, mat)
    staff(ic, (-0.10, 0.96), (0.84, 0.50), w=0.085)


def thousand_leaves(ic):
    # "Both ends of the staff everywhere at once ... like leaves in a gale"
    ic.glow(ic.lens((-0.05, 0.36), (1.05, 0.64), 0.30), LEAFWIND, depth=0.07)
    staff(ic, (-0.20, 0.34), (1.20, 0.66), w=0.10)
    for (x, y), ang, mat in (((0.14, 0.14), 20.0, LEAF), ((0.40, 0.10), -30.0, AUTUMN), ((0.66, 0.16), 40.0, LEAF), ((0.90, 0.22), -10.0, AUTUMN),
            ((0.10, 0.76), 30.0, AUTUMN), ((0.34, 0.86), -20.0, LEAF), ((0.60, 0.90), 15.0, AUTUMN), ((0.86, 0.84), -40.0, LEAF)):
        leaf(ic, (x, y), ang, 0.11, mat)


def crane_vault(ic):
    # "Plant the staff and vault high over the enemy": the crane itself, over the planted staff
    staff(ic, (0.22, 1.10), (0.36, 0.40), w=0.075)
    ic.glow(ic.path(arc((0.50, 0.92), 0.58, 200.0, 330.0), 0.03, 0.10), LEAFWIND, depth=0.04)
    crane(ic, (0.52, 0.44), 0.62)


def autumn_gale(ic):
    # "a whirlwind of leaves drags every enemy close in while the staff spins round you faster and faster"
    arms = []
    for turn in (0.0, 120.0, 240.0):
        pts = []
        for k in range(9):
            t = k / 8.0
            a = math.radians(turn + 220.0 * t)
            r = 0.52 * (1.0 - 0.62 * t)
            pts.append((0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r))
        arms.append(pts)
        ic.glow(ic.path(pts, 0.035, 0.13), LEAFWIND, depth=0.05)
    for k, pts in enumerate(arms):
        for j, mat in ((1, AUTUMN), (4, LEAF if k % 2 else AUTUMN)):
            leaf(ic, pts[j], 40.0 + 70.0 * k + 30.0 * j, 0.10, mat)
    staff(ic, (0.30, 0.70), (0.70, 0.30), w=0.07)


def pillar_of_wind(ic):
    # "a pillar of wind and leaves throws every enemy round you high into the air"
    for y, rx in ((0.10, 0.44), (0.30, 0.36), (0.50, 0.28), (0.70, 0.20), (0.88, 0.13)):
        ic.glow(ic.poly(oval((0.50, y), rx, 0.12)), LEAFWIND, depth=0.05, ink=True)
    staff(ic, (0.50, 1.10), (0.50, 0.30), w=0.07)
    for (x, y), ang, mat in (((0.12, 0.34), 30.0, AUTUMN), ((0.88, 0.22), -40.0, LEAF), ((0.84, 0.60), 60.0, AUTUMN), ((0.18, 0.72), -20.0, LEAF)):
        leaf(ic, (x, y), ang, 0.10, mat)


# ----------------------------------------------------------------------------------------------------------------
# Chain sickle (cold green fire)
# ----------------------------------------------------------------------------------------------------------------
def binding_coil(ic):
    # "The chain thrown round the enemy you face and pulled tight: bound and held where they stand"
    bust(ic, (0.50, 0.50), 0.74, SHADE)
    for y, dx in ((0.56, 0.0), (0.72, 0.03), (0.88, -0.02)):
        chain(ic, [(0.02 + dx, y + 0.06), (0.50, y - 0.03), (0.98 + dx, y + 0.06)], link=0.075)
    ic.glow(ic.star((0.84, 0.50), 0.11, 4, 0.3, 0.0), SOUL, depth=0.04, ink=True)


def serpent_lash(ic):
    # "The chain cracked out three times like a striking snake"
    pts = [(-0.04, 0.86), (0.14, 0.60), (0.34, 0.74), (0.52, 0.46), (0.70, 0.56), (0.80, 0.30)]
    ic.glow(ic.path(pts, 0.10, 0.14), SOUL, depth=0.04)
    chain(ic, pts, link=0.07)
    sickle(ic, (0.76, 0.36), -70.0, 0.44)
    ic.glow(ic.star((0.90, 0.08), 0.10, 6, 0.4, 0.2), SPARK, depth=0.04, ink=True)


def reel_and_reap(ic):
    # "yanked in hard, and the sickle waiting for them: three cuts and a reaping"
    ic.glow(ic.circle((0.50, 0.52), 0.50) & ~ic.circle((0.36, 0.66), 0.50), SOUL, depth=0.08)
    chain(ic, [(0.02, 0.96), (0.14, 0.80), (0.10, 0.62)], link=0.07)
    sickle(ic, (0.06, 1.02), -52.0, 1.02)


def hook_step(ic):
    # "The chain cast round the enemy you face and you pull yourself across to them in a blink"
    bust(ic, (0.80, 0.34), 0.44, SHADE)
    for y in (0.24, 0.92):
        ic.glow(ic.lens((0.02, y + 0.10), (0.46, y - 0.06), 0.06), SOUL, depth=0.03)
    chain(ic, [(-0.04, 0.96), (0.30, 0.70), (0.62, 0.46)], link=0.085)
    sickle(ic, (0.50, 0.58), -40.0, 0.50)


def harvest_of_souls(ic):
    # "The chain catches fire with a cold green flame and you whirl it round you wider and wider"
    ring = ic.circle((0.50, 0.52), 0.46) & ~ic.circle((0.50, 0.52), 0.30)
    for k in range(8):
        a = math.radians(k * 45.0 + 10.0)
        c = (0.5 + math.cos(a) * 0.42, 0.52 + math.sin(a) * 0.42)
        ring |= ic.poly([(c[0] - math.sin(a) * 0.08, c[1] + math.cos(a) * 0.08), (0.5 + math.cos(a + 0.25) * 0.60, 0.52 + math.sin(a + 0.25) * 0.60),
            (c[0] + math.sin(a) * 0.08, c[1] - math.cos(a) * 0.08)])
    ic.glow(ring, SOUL, depth=0.07)
    chain(ic, arc((0.50, 0.52), 0.37, 0.0, 345.0, 1.0, 24), link=0.085)
    wisp(ic, (0.50, 0.58), 0.10)


def soul_chain(ic):
    # "The burning chain cast out along a line fourteen paces long, catching everyone on it by the soul"
    ic.glow(ic.lens((-0.10, 0.74), (1.10, 0.54), 0.26), SOUL, depth=0.07)
    chain(ic, [(-0.04, 0.72), (0.50, 0.64), (1.04, 0.56)], link=0.085)
    for x, y, r in ((0.20, 0.42, 0.10), (0.52, 0.34, 0.12), (0.82, 0.30, 0.10)):
        wisp(ic, (x, y), r)


# ----------------------------------------------------------------------------------------------------------------
# Slingshot (tricks)
# ----------------------------------------------------------------------------------------------------------------
def fire_pellet(ic):
    # "A pellet packed with fire": the pellet away off the fork, burning
    ic.glow(ic.poly([(0.36, 0.66), (0.44, 0.44), (0.30, 0.44), (0.50, 0.22), (0.50, 0.06), (0.70, 0.10), (0.94, 0.04), (0.90, 0.30), (0.96, 0.50), (0.74, 0.54), (0.60, 0.70)]), FIRE, depth=0.11)
    pellet(ic, (0.70, 0.30), 0.13, CLOTH)
    sling(ic, (-0.06, 1.06), -48.0, 0.70)


def smoke_pellet(ic):
    # "a thick cloud where it lands blinds everyone in it"
    cloud = ic.circle((0.24, 0.62), 0.26) | ic.circle((0.50, 0.40), 0.32) | ic.circle((0.78, 0.60), 0.26) | ic.circle((0.40, 0.84), 0.22) | ic.circle((0.66, 0.86), 0.22)
    ic.part(cloud, SMOKE, shadow=0.10)
    ic.flat(ic.path(arc((0.30, 0.60), 0.13, 200.0, 330.0), 0.03) | ic.path(arc((0.54, 0.38), 0.16, 200.0, 330.0), 0.03) | ic.path(arc((0.74, 0.62), 0.11, 210.0, 320.0), 0.03), SMOKE[1])
    pellet(ic, (0.50, 0.90), 0.09, SHADE)
    for x, y in ((0.14, 0.20), (0.88, 0.22)):
        ic.glow(ic.star((x, y), 0.07, 4, 0.3, 0.0), PINK, depth=0.03)


def blast_pellet(ic):
    # "A pellet of black powder: it goes off where it lands"
    ic.glow(ic.star((0.52, 0.52), 0.52, 10, 0.5, 0.1), FIRE, depth=0.15)
    ic.glow(ic.star((0.52, 0.52), 0.24, 10, 0.5, 0.4), SPARK, depth=0.10)
    pellet(ic, (0.52, 0.54), 0.15, SHADE)
    ic.part(ic.path([(0.52, 0.40), (0.58, 0.30)], 0.035), WOOD, shadow=0.02)
    ic.glow(ic.star((0.60, 0.26), 0.08, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def sticky_pellet(ic):
    # "A pellet of hot tar: everyone in the splash is stuck where they stand"
    splat = ic.poly(oval((0.50, 0.66), 0.44, 0.22))
    for x, y, r in ((0.24, 0.56, 0.17), (0.50, 0.48, 0.22), (0.76, 0.56, 0.17), (0.36, 0.78, 0.15), (0.66, 0.80, 0.15)):
        splat |= ic.circle((x, y), r)
    for a, b in (((0.32, 0.46), (0.14, 0.10)), ((0.68, 0.46), (0.88, 0.16))):
        splat |= ic.path([a, b], 0.07, 0.025)
    ic.part(splat, SHADE, metal=True, shadow=0.07)
    for x, y in ((0.12, 0.90), (0.90, 0.88), (0.30, 0.96)):
        ic.part(ic.circle((x, y), 0.05), SHADE, metal=True, shadow=0.02)
    ic.flat(ic.lens((0.34, 0.60), (0.52, 0.52), 0.05), hx("8a88a8"))
    ic.glow(ic.star((0.78, 0.14), 0.09, 4, 0.3, 0.0), PINK, depth=0.03, ink=True)


def bag_of_tricks(ic):
    # "Empty the pouch: five trick pellets, one after another"
    ic.part(ic.poly([(0.22, 0.98), (0.14, 0.66), (0.32, 0.46), (0.68, 0.46), (0.86, 0.66), (0.78, 0.98)]), LEATHER, shadow=0.08)
    ic.part(ic.poly([(0.30, 0.50), (0.26, 0.36), (0.50, 0.42), (0.74, 0.36), (0.70, 0.50)]), LEATHER, shadow=0.04)
    ic.part(ic.capsule((0.30, 0.48), (0.70, 0.48), 0.06), GOLD, metal=True, shadow=0.02)
    for (x, y), mat in (((0.14, 0.26), CLOTH), ((0.36, 0.12), SMOKE), ((0.62, 0.10), SHADE), ((0.86, 0.24), FIRE), ((0.50, 0.26), PINK)):
        pellet(ic, (x, y), 0.085, mat)


def fireworks_finale(ic):
    # "A stone straight up bursts into a shower of sparks"
    for k in range(12):
        a = math.radians(k * 30.0)
        mat = (PINK, SPARK, FIRE)[k % 3]
        ic.glow(ic.lens((0.5 + math.cos(a) * 0.16, 0.46 + math.sin(a) * 0.16), (0.5 + math.cos(a) * 0.50, 0.46 + math.sin(a) * 0.50), 0.08), mat, depth=0.03)
        ic.glow(ic.circle((0.5 + math.cos(a) * 0.52, 0.46 + math.sin(a) * 0.52), 0.04), mat, depth=0.03)
    ic.glow(ic.star((0.50, 0.46), 0.16, 8, 0.45, 0.2), SPARK, depth=0.06, ink=True)


# ----------------------------------------------------------------------------------------------------------------
# Pieces for the guns and the base skills
# ----------------------------------------------------------------------------------------------------------------
def musket(ic, at, angle, size):
    """A long gun: `at` is the lock, the barrel runs along `angle`, the stock and butt behind it."""
    f = Frame(at, angle, size)
    ic.part(ic.poly(f.pts([(-0.36, -0.02), (-0.32, 0.22), (-0.06, 0.11), (0.52, 0.07), (0.52, -0.01), (0.02, -0.03), (-0.26, -0.08)])), WOOD, shadow=0.045)
    ic.part(ic.capsule(f.pt(0.06, -0.06), f.pt(1.0, -0.06), 0.085 * size), STEEL, metal=True, shadow=0.03)
    for u in (0.46, 0.78):
        ic.part(ic.capsule(f.pt(u, -0.10), f.pt(u, 0.05), 0.045 * size), GOLD, metal=True, shadow=0.02)
    ic.part(ic.poly(f.pts([(0.02, -0.10), (0.08, -0.22), (0.16, -0.19), (0.15, -0.09)])), IRON, metal=True, shadow=0.02)
    ic.part(ic.path(f.pts([(0.06, 0.09), (0.11, 0.18), (0.20, 0.16), (0.22, 0.08)]), 0.03 * size), GOLD, metal=True, shadow=0.015)


def cannon(ic, at, angle, size):
    """A hand cannon: `at` is its breech, the muzzle along `angle`: black iron, gold-banded."""
    f = Frame(at, angle, size)
    ic.part(ic.poly(f.pts([(0.0, -0.21), (0.90, -0.16), (0.90, 0.16), (0.0, 0.21)])), SHADE, metal=True, shadow=0.07)
    ic.part(ic.poly(f.pts([(0.86, -0.21), (1.0, -0.21), (1.0, 0.21), (0.86, 0.21)])), GOLD, metal=True, shadow=0.04)
    for u in (0.10, 0.50):
        ic.part(ic.poly(f.pts([(u, -0.225), (u + 0.09, -0.22), (u + 0.09, 0.22), (u, 0.225)])), GOLD, metal=True, shadow=0.03)
    ic.part(ic.circle(f.pt(-0.08, 0.0), 0.085 * size), GOLD, metal=True, shadow=0.03)


def eye(ic, c, w, iris):
    """An open eye `w` wide: white, a glowing iris, a dark pupil, a glint."""
    ic.part(ic.lens((c[0] - w / 2, c[1]), (c[0] + w / 2, c[1]), w * 0.62), WHITE, shadow=0.04)
    ic.glow(ic.circle(c, w * 0.21), iris, depth=w * 0.12, ink=True)
    ic.flat(ic.circle(c, w * 0.09), INK)
    ic.flat(ic.circle((c[0] - w * 0.07, c[1] - w * 0.08), w * 0.035), hx("ffffff"))


def heart(ic, c, s, mat):
    m = ic.circle((c[0] - s * 0.25, c[1] - s * 0.18), s * 0.30) | ic.circle((c[0] + s * 0.25, c[1] - s * 0.18), s * 0.30) | ic.poly([(c[0] - s * 0.53, c[1] - s * 0.06), (c[0] + s * 0.53, c[1] - s * 0.06), (c[0], c[1] + s * 0.58)])
    ic.part(m, mat, shadow=0.06)


def crown(ic, c, s):
    x, y = c
    ic.part(ic.poly([(x - 0.5 * s, y + 0.30 * s), (x - 0.56 * s, y - 0.26 * s), (x - 0.28 * s, y + 0.02 * s), (x, y - 0.44 * s), (x + 0.28 * s, y + 0.02 * s),
        (x + 0.56 * s, y - 0.26 * s), (x + 0.5 * s, y + 0.30 * s)]), GOLD, metal=True, shadow=0.06)
    ic.part(ic.poly([(x - 0.52 * s, y + 0.22 * s), (x + 0.52 * s, y + 0.22 * s), (x + 0.50 * s, y + 0.40 * s), (x - 0.50 * s, y + 0.40 * s)]), GOLD, metal=True, shadow=0.03)
    for dx, col in ((-0.28, "e0242e"), (0.0, "3aa0ff"), (0.28, "e0242e")):
        ic.flat(ic.circle((x + dx * s, y + 0.31 * s), 0.055 * s), hx(col))
    for dx, dy in ((-0.56, -0.26), (0.0, -0.44), (0.56, -0.26)):
        ic.part(ic.circle((x + dx * s, y + dy * s), 0.07 * s), GOLD, metal=True, shadow=0.02)


# ----------------------------------------------------------------------------------------------------------------
# Long gun (starlight)
# ----------------------------------------------------------------------------------------------------------------
def pin_shot(ic):
    # "put a ball into the enemy in your sights ... it nails them where they stand"
    bust(ic, (0.74, 0.50), 0.56, SHADE)
    ic.glow(ic.lens((-0.05, 0.86), (0.72, 0.52), 0.13), MOON, depth=0.045)
    ic.glow(ic.star((0.70, 0.54), 0.17, 6, 0.4, 0.2), SPARK, depth=0.06, ink=True)
    ic.part(ic.poly([(0.66, 0.60), (0.74, 0.60), (0.72, 1.04), (0.68, 1.04)]), STEEL, metal=True, shadow=0.02)
    ic.part(ic.capsule((0.62, 0.60), (0.78, 0.60), 0.06), STEEL, metal=True, shadow=0.02)


def powder_burst(ic):
    # "A double charge fired from the hip: a cone of fire and shot"
    ic.part(ic.circle((0.56, 0.18), 0.20) | ic.circle((0.82, 0.24), 0.18) | ic.circle((0.60, 0.84), 0.20) | ic.circle((0.84, 0.78), 0.18), SMOKE, shadow=0.08)
    ic.glow(ic.poly([(0.36, 0.50), (0.70, 0.22), (0.66, 0.38), (1.04, 0.30), (0.80, 0.50), (1.04, 0.70), (0.66, 0.62), (0.70, 0.78)]), FIRE, depth=0.11)
    musket(ic, (-0.86, 0.60), -4.0, 1.30)


def volley_line(ic):
    # "Three paper cartridges, loaded and fired as fast as you can bite them"
    for k, x in enumerate((0.22, 0.50, 0.78)):
        ic.glow(ic.lens((x, 0.50), (x + 0.06, -0.04), 0.09), MOON, depth=0.035)
        ic.part(ic.capsule((x, 0.62), (x, 0.92), 0.17), BONE, shadow=0.05)
        ic.part(ic.circle((x, 0.58), 0.085), GOLD, metal=True, shadow=0.04)
        ic.flat(ic.capsule((x - 0.07, 0.80), (x + 0.07, 0.80), 0.025), BONE[1])
        ic.part(ic.poly([(x - 0.08, 0.94), (x + 0.08, 0.94), (x + 0.03, 1.04), (x - 0.03, 1.04)]), BONE, shadow=0.02)


def stock_sweep(ic):
    # "Let the gun out at arm's length, butt first, and swing round once"
    ic.glow(ic.path(arc((0.44, 0.50), 0.48, 100.0, 330.0), 0.03, 0.15), MOON, depth=0.055)
    musket(ic, (0.56, 0.42), 150.0, 1.05)
    ic.glow(ic.star((0.88, 0.22), 0.14, 6, 0.4, 0.2), SPARK, depth=0.05, ink=True)


def hawkeye(ic):
    # "time slows while every enemy ahead is marked": the hawk's eye
    ic.part(ic.poly([(-0.04, 0.34), (0.50, 0.12), (1.04, 0.26), (1.04, 0.44), (0.52, 0.30), (-0.04, 0.52)]), SHADE, shadow=0.05)
    eye(ic, (0.50, 0.58), 0.92, MOON)
    for x, y in ((0.10, 0.90), (0.90, 0.90)):
        ic.glow(ic.star((x, y), 0.07, 4, 0.3, 0.0), SPARK, depth=0.03)


def constellation(ic):
    # "one shot straight up; it splits into stars that fall on up to eight foes"
    stars = [(0.14, 0.30), (0.34, 0.12), (0.56, 0.26), (0.80, 0.10), (0.88, 0.42), (0.62, 0.52)]
    for k in range(len(stars) - 1):
        ic.flat(ic.capsule(stars[k], stars[k + 1], 0.022), MOON[2])
    ic.glow(ic.lens((0.36, 1.04), (0.56, 0.30), 0.10), MOON, depth=0.04)
    for k, (x, y) in enumerate(stars):
        ic.glow(ic.star((x, y), 0.11 if k % 2 == 0 else 0.085, 4, 0.3, 0.0), SPARK, depth=0.04, ink=True)


# ----------------------------------------------------------------------------------------------------------------
# Cannon (gold and violet)
# ----------------------------------------------------------------------------------------------------------------
def canister_shot(ic):
    # "A canister of grape fired point-blank: a cone of a dozen balls"
    ic.glow(ic.poly([(0.30, 0.50), (1.06, -0.04), (1.06, 1.04)]), FIRE, depth=0.15)
    for x, y in ((0.52, 0.40), (0.56, 0.62), (0.68, 0.26), (0.72, 0.50), (0.70, 0.76), (0.86, 0.16), (0.88, 0.40), (0.90, 0.62), (0.86, 0.86)):
        pellet(ic, (x, y), 0.05)
    cannon(ic, (-0.56, 0.50), 0.0, 0.92)


def chain_shot(ic):
    # "Two balls on a chain, spinning down the line"
    ic.glow(ic.path(arc((0.50, 0.50), 0.46, 200.0, 330.0), 0.03, 0.11), VIOLET, depth=0.04)
    ic.glow(ic.path(arc((0.50, 0.50), 0.46, 20.0, 150.0), 0.03, 0.11), VIOLET, depth=0.04)
    chain(ic, [(0.26, 0.72), (0.74, 0.28)], link=0.085)
    pellet(ic, (0.22, 0.76), 0.19)
    pellet(ic, (0.78, 0.24), 0.19)


def mortar_lob(ic):
    # "Tip the cannon up and lob three shells high"
    for (x0, x1, top), r in (((0.24, 0.50, 0.30), 0.075), ((0.26, 0.74, 0.12), 0.085), ((0.28, 0.98, 0.26), 0.075)):
        pts = [(x0 + (x1 - x0) * t, 0.74 - (0.74 - top) * (1.0 - (2.0 * t - 1.0) ** 2) * 1.0 + (0.20 * t)) for t in np.linspace(0.0, 0.62, 8)]
        ic.glow(ic.path(pts, 0.025, 0.07), FIRE, depth=0.03)
        pellet(ic, pts[-1], r)
    cannon(ic, (0.02, 1.04), -62.0, 0.56)


def rocket_charge(ic):
    # "Turn the muzzle behind you and fire: the recoil hurls you ten paces forward"
    ic.glow(ic.poly([(0.34, 0.50), (0.14, 0.14), (0.16, 0.36), (-0.06, 0.24), (0.04, 0.50), (-0.06, 0.76), (0.16, 0.64), (0.14, 0.86)]), FIRE, depth=0.11)
    for y in (0.14, 0.86):
        ic.glow(ic.lens((0.40, y), (0.98, y), 0.06), VIOLET, depth=0.03)
    cannon(ic, (1.02, 0.50), 180.0, 0.76)


def leviathan_shell(ic):
    # "one giant shell at the reticle"
    ic.glow(ic.poly([(1.04, -0.04), (0.60, 0.10), (0.74, 0.20), (0.44, 0.24), (0.60, 0.36), (0.50, 0.50), (0.78, 0.46), (0.82, 0.62), (0.94, 0.36)]), FIRE, depth=0.10)
    f = Frame((0.84, 0.16), 135.0, 0.86)
    ic.part(ic.poly(f.pts([(0.0, -0.24), (0.62, -0.24), (0.86, -0.14), (1.0, 0.0), (0.86, 0.14), (0.62, 0.24), (0.0, 0.24)])), SHADE, metal=True, shadow=0.08)
    ic.part(ic.poly(f.pts([(0.10, -0.25), (0.22, -0.25), (0.22, 0.25), (0.10, 0.25)])), GOLD, metal=True, shadow=0.03)
    ic.part(ic.poly(f.pts([(0.50, -0.25), (0.58, -0.25), (0.58, 0.25), (0.50, 0.25)])), GOLD, metal=True, shadow=0.03)
    ic.glow(ic.star((0.14, 0.86), 0.12, 4, 0.3, 0.0), VIOLET, depth=0.04, ink=True)


def hellfire_barrage(ic):
    # "five shells walked out from your feet down the line, each burst bigger than the last"
    ground(ic, 0.88)
    for x, r in ((0.12, 0.10), (0.30, 0.15), (0.54, 0.22), (0.86, 0.32)):
        ic.glow(ic.star((x, 0.86 - r * 0.9), r, 8, 0.5, 0.2 + x), FIRE, depth=r * 0.34, ink=True)
        ic.glow(ic.star((x, 0.86 - r * 0.9), r * 0.42, 8, 0.5, 0.6 + x), SPARK, depth=r * 0.2)


# ----------------------------------------------------------------------------------------------------------------
# Base (the body and the will)
# ----------------------------------------------------------------------------------------------------------------
def soru(ic):
    # "Kick off the ground so fast you vanish": where you were, and the streak you left
    ghost_bust(ic, (0.24, 0.48), 0.52, TEAL)
    for y, x0 in ((0.24, 0.46), (0.46, 0.38), (0.68, 0.46)):
        ic.glow(ic.lens((x0, y), (1.04, y - 0.04), 0.10), TEAL, depth=0.04)
    for x, r in ((0.16, 0.07), (0.30, 0.09), (0.44, 0.06)):
        ic.part(ic.circle((x, 0.94), r), SMOKE, shadow=0.03)


def tekkai(ic):
    # "Harden your whole body": a body of iron, the blows ringing off it
    bust(ic, (0.50, 0.52), 0.74, STEEL)
    for x, y in ((0.30, 0.78), (0.50, 0.84), (0.70, 0.78)):
        ic.part(ic.circle((x, y), 0.035), IRON, metal=True, shadow=0.015)
    for x, y, r in ((0.12, 0.26, 0.11), (0.90, 0.40, 0.09)):
        ic.glow(ic.star((x, y), r, 4, 0.3, 0.0), SPARK, depth=0.04, ink=True)


def edy_reinforce(ic):
    # "Edy through your whole body"
    ic.glow(ic.poly([(0.06, 1.0), (0.00, 0.56), (0.14, 0.64), (0.12, 0.26), (0.30, 0.40), (0.38, 0.04), (0.50, 0.22), (0.62, 0.04), (0.70, 0.40),
        (0.88, 0.26), (0.86, 0.64), (1.00, 0.56), (0.94, 1.0)]), TEAL, depth=0.12)
    bust(ic, (0.50, 0.60), 0.56, SHADE)
    ic.glow(ic.star((0.50, 0.80), 0.10, 4, 0.3, 0.0), TEAL, depth=0.04, ink=True)


def armament_coat(ic):
    # "Pour your Edy into your weapon": the blade gone black with it
    ic.glow(ic.lens((-0.10, 1.10), (0.96, 0.02), 0.50), VIOLET, depth=0.10)
    cutlass(ic, (-0.30, 1.30), (0.86, 0.08), bend=0.08, w=0.19, steel=SHADE)
    for x, y, r in ((0.86, 0.10, 0.10), (0.30, 0.34, 0.07), (0.78, 0.60, 0.07)):
        ic.glow(ic.star((x, y), r, 4, 0.3, 0.0), SPARK, depth=0.035, ink=True)


def foresight(ic):
    # "Sense what's coming": the eye that sees it
    for r in (0.50, 0.38):
        ic.glow(ic.path(arc((0.50, 0.52), r, 200.0, 340.0), 0.04, 0.04), TEAL, depth=0.03)
    eye(ic, (0.50, 0.56), 0.84, TEAL)
    ic.glow(ic.star((0.50, 0.14), 0.09, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def will_swell(ic):
    # "stamp the deck and a wave rolls over it": the wave over the planks
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.80), (1.0, 0.72), (1.0, 1.0)]), WOOD, shadow=0.04)
    for x in (0.26, 0.54, 0.80):
        ic.flat(ic.capsule((x, 0.79 - x * 0.08), (x - 0.02, 1.0), 0.02), WOOD[0])
    ic.glow(ic.poly([(-0.04, 0.82), (-0.04, 0.40), (0.20, 0.16), (0.50, 0.08), (0.78, 0.20), (0.92, 0.42), (0.84, 0.60), (0.72, 0.44), (0.56, 0.36), (0.44, 0.48),
        (0.50, 0.66), (0.70, 0.76)]), WATER, depth=0.10, ink=True)
    for x, y in ((0.90, 0.24), (0.98, 0.56), (0.80, 0.10)):
        ic.glow(ic.circle((x, y), 0.035), WATER, depth=0.03, ink=True)


def will_wind(ic):
    # "whistle up a wind, 25% more sail speed": the sail full of it
    ic.part(ic.capsule((0.70, -0.04), (0.70, 1.04), 0.07), WOOD, shadow=0.03)
    ic.part(ic.poly([(0.68, 0.10), (0.26, 0.20), (0.12, 0.50), (0.24, 0.82), (0.68, 0.88), (0.54, 0.50)]), BONE, shadow=0.08)
    ic.part(ic.capsule((0.50, 0.10), (0.88, 0.10), 0.06), WOOD, shadow=0.02)
    for y, x1 in ((0.30, 0.50), (0.52, 0.42), (0.74, 0.50)):
        ic.glow(ic.path([(1.02, y - 0.06), (0.86, y + 0.02), (x1 + 0.34, y)], 0.03, 0.07), WIND, depth=0.03)


def will_twin(ic):
    # "you and your linked crewmate close on the nearest foe from both sides and cross your weapons through them"
    ic.glow(ic.star((0.50, 0.50), 0.50, 4, 0.3, math.radians(45.0)), PINK, depth=0.10)
    cutlass(ic, (-0.28, 1.28), (0.84, 0.06), bend=0.06, w=0.15)
    katana(ic, (1.30, 1.30), (0.14, 0.06), bend=0.10, w=0.085)
    for dx in (-0.07, 0.07):
        ic.part(ic.circle((0.50 + dx, 0.52), 0.11) & ~ic.circle((0.50 + dx, 0.52), 0.065), GOLD, metal=True, shadow=0.03)


def will_glimpse(ic):
    # "you see every foe and closed chest ... through walls": the eye through the stones
    ic.part(ic.poly([(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]), STONE, shadow=0.03)
    for y in (0.26, 0.52, 0.78):
        ic.flat(ic.capsule((0.0, y), (1.0, y), 0.03), STONE[0])
    for x, y0 in ((0.30, 0.0), (0.70, 0.0), (0.16, 0.26), (0.52, 0.26), (0.86, 0.26), (0.34, 0.52), (0.72, 0.52), (0.20, 0.78), (0.58, 0.78)):
        ic.flat(ic.capsule((x, y0), (x, y0 + 0.26), 0.03), STONE[0])
    ic.glow(ic.lens((0.08, 0.52), (0.92, 0.52), 0.56), VIOLET, depth=0.10, ink=True)
    eye(ic, (0.50, 0.52), 0.66, VIOLET)


def will_flag(ic):
    # "Drive your flag into the ground: ... every captain within 6 m of it mends"
    ic.glow(ic.poly(oval((0.46, 0.86), 0.50, 0.15)) & ~ic.poly(oval((0.46, 0.86), 0.34, 0.08)), VENOM, depth=0.04)
    ground(ic, 0.90)
    ic.part(ic.capsule((0.30, 1.0), (0.30, 0.06), 0.065), WOOD, shadow=0.03)
    ic.part(ic.poly([(0.32, 0.10), (0.94, 0.16), (0.82, 0.34), (0.96, 0.54), (0.32, 0.56)]), SHADE, shadow=0.07)
    ic.part(ic.circle((0.58, 0.31), 0.10) | ic.poly([(0.52, 0.36), (0.64, 0.36), (0.62, 0.46), (0.54, 0.46)]), BONE, shadow=0.03)
    ic.flat(ic.circle((0.545, 0.31), 0.028) | ic.circle((0.615, 0.31), 0.028), INK)
    ic.part(ic.circle((0.30, 0.05), 0.055), GOLD, metal=True, shadow=0.02)
    for x, y in ((0.74, 0.72), (0.10, 0.62)):
        ic.flat(ic.capsule((x - 0.06, y), (x + 0.06, y), 0.04) | ic.capsule((x, y - 0.06), (x, y + 0.06), 0.04), VENOM[3])


def will_still_point(ic):
    # "Find the still point: for 3 s every foe ... moves and strikes at half speed": the clock held still
    ic.glow(ic.circle((0.50, 0.50), 0.50) & ~ic.circle((0.50, 0.50), 0.42), CYAN, depth=0.035)
    ic.part(ic.circle((0.50, 0.50), 0.38), GOLD, metal=True, shadow=0.05)
    ic.part(ic.circle((0.50, 0.50), 0.31), BONE, shadow=0.06)
    for k in range(12):
        a = math.radians(k * 30.0)
        ic.flat(ic.capsule((0.5 + math.cos(a) * 0.24, 0.5 + math.sin(a) * 0.24), (0.5 + math.cos(a) * 0.28, 0.5 + math.sin(a) * 0.28), 0.03 if k % 3 == 0 else 0.018), INK)
    ic.flat(ic.capsule((0.50, 0.50), (0.50, 0.27), 0.035) | ic.capsule((0.50, 0.50), (0.66, 0.56), 0.045) | ic.circle((0.50, 0.50), 0.04), INK)


def will_berserk(ic):
    # "every blow you land heals you ... and blows on you land 20% harder": the heart on fire
    ic.glow(ic.poly([(0.08, 0.96), (0.02, 0.56), (0.16, 0.64), (0.12, 0.26), (0.30, 0.40), (0.36, 0.06), (0.50, 0.26), (0.64, 0.04), (0.72, 0.40),
        (0.90, 0.24), (0.86, 0.64), (0.98, 0.56), (0.92, 0.96)]), FIRE, depth=0.12)
    heart(ic, (0.50, 0.56), 0.62, HEAT)
    ic.flat(ic.path([(0.52, 0.42), (0.44, 0.56), (0.54, 0.64), (0.48, 0.80)], 0.035), INK)


def conquerors_haki(ic):
    # "Unleash the will of a king: weak foes around you ... faint on the spot"
    for r, w0 in ((0.50, 0.07), (0.36, 0.05)):
        ic.glow(ic.circle((0.50, 0.56), r) & ~ic.circle((0.50, 0.56), r - w0), HEAT, depth=0.03)
    for pts in ([(0.10, 0.06), (0.22, 0.26), (0.14, 0.30), (0.26, 0.48)], [(0.90, 0.06), (0.78, 0.26), (0.86, 0.30), (0.74, 0.48)],
            [(0.06, 0.94), (0.20, 0.80), (0.14, 0.74), (0.28, 0.64)], [(0.94, 0.94), (0.80, 0.80), (0.86, 0.74), (0.72, 0.64)]):
        ic.glow(ic.path(pts, 0.07, 0.035), VIOLET, depth=0.03, ink=True)
    crown(ic, (0.50, 0.52), 0.62)


# ----------------------------------------------------------------------------------------------------------------
# Fruit powers that have a picture of their own (the rest show their fruit: Skills.icon)
# ----------------------------------------------------------------------------------------------------------------
def flames(ic, pts, depth=0.12, mat=FIRE):
    ic.glow(ic.poly(pts), mat, depth=depth)


def wolf_head(ic, at, angle, size):
    """A wolf's head in profile, muzzle along `angle`: tall ears, a long narrow muzzle, a ruff."""
    f = Frame(at, angle, size)
    ic.part(ic.poly(f.pts([(-0.40, 0.50), (-0.96, 0.62), (-0.74, 0.34), (-1.02, 0.18), (-0.72, 0.08), (-0.94, -0.16), (-0.56, -0.12)])), FUR, shadow=0.05)
    ic.part(ic.poly(f.pts([(-0.62, -0.10), (-0.70, -0.66), (-0.40, -0.24)])), FUR, shadow=0.03)
    ic.flat(ic.poly(f.pts([(0.02, 0.26), (0.72, 0.20), (0.74, 0.32), (0.10, 0.40)])), hx("3a0612"))
    ic.part(ic.poly(f.pts([(-0.04, 0.36), (0.34, 0.30), (0.72, 0.30), (0.78, 0.38), (0.40, 0.48), (0.04, 0.56), (-0.30, 0.72), (-0.24, 0.50)])), FUR, shadow=0.04)
    ic.part(ic.poly(f.pts([(-0.64, 0.42), (-0.62, -0.12), (-0.32, -0.30), (0.02, -0.22), (0.28, -0.10), (0.82, 0.02), (0.92, 0.14), (0.80, 0.22), (0.30, 0.24),
        (0.02, 0.40), (-0.26, 0.56)])), FUR, shadow=0.07)
    ic.part(ic.poly(f.pts([(-0.46, -0.20), (-0.40, -0.86), (-0.12, -0.28)])), FUR, shadow=0.04)
    ic.flat(ic.poly(f.pts([(-0.40, -0.30), (-0.38, -0.66), (-0.24, -0.32)])), hx("5a3a4a"))
    ic.flat(ic.poly(f.pts([(0.58, 0.22), (0.66, 0.21), (0.63, 0.34)])) | ic.poly(f.pts([(0.40, 0.24), (0.47, 0.23), (0.44, 0.34)])), hx("ffffff"))
    ic.flat(ic.poly(f.pts([(-0.06, -0.10), (0.18, -0.02), (0.12, 0.04), (-0.04, -0.02)])), hx("ffd23a"))
    ic.flat(ic.circle(f.pt(0.07, -0.02), 0.025 * size), INK)
    ic.flat(ic.capsule(f.pt(-0.12, -0.14), f.pt(0.20, -0.07), 0.03 * size), INK)
    ic.flat(ic.circle(f.pt(0.88, 0.10), 0.055 * size), INK)


def fire_fist(ic):
    # "Hurl a ball of fire where you aim. It bursts on impact": the ball of fire, thrown
    flames(ic, [(-0.04, 1.04), (0.06, 0.70), (0.00, 0.50), (0.22, 0.58), (0.20, 0.34), (0.40, 0.44), (0.44, 0.14), (0.62, 0.20), (0.90, 0.10), (0.96, 0.40),
        (0.88, 0.62), (0.62, 0.72), (0.52, 0.94), (0.36, 0.84), (0.24, 1.04)], 0.14)
    ic.glow(ic.circle((0.66, 0.38), 0.24), SPARK, depth=0.13)
    for x, y in ((0.14, 0.18), (0.92, 0.84)):
        ic.glow(ic.star((x, y), 0.07, 4, 0.3, 0.0), SPARK, depth=0.03)


def fire_ring(ic):
    # "A ring of fire explodes out around you"
    ring = ic.poly(oval((0.50, 0.56), 0.50, 0.34)) & ~ic.poly(oval((0.50, 0.56), 0.30, 0.17))
    for k in range(9):
        a = math.radians(200.0 + k * 17.5)
        c = (0.5 + math.cos(a) * 0.44, 0.56 + math.sin(a) * 0.30)
        ring |= ic.poly([(c[0] - 0.07, c[1]), (c[0] + math.cos(a) * 0.04, c[1] - 0.30 - 0.06 * (k % 2)), (c[0] + 0.07, c[1])])
    ic.glow(ring, FIRE, depth=0.07)
    ic.glow(ic.star((0.50, 0.58), 0.10, 4, 0.3, 0.0), SPARK, depth=0.04)


def flame_dash(ic):
    # "Burst forward in a streak of fire"
    flames(ic, [(-0.04, 0.44), (0.20, 0.30), (0.12, 0.44), (0.42, 0.22), (0.36, 0.40), (0.72, 0.24), (0.98, 0.50), (0.72, 0.76), (0.36, 0.60), (0.42, 0.80),
        (0.12, 0.58), (0.20, 0.72), (-0.04, 0.60)], 0.13)
    for y in (0.10, 0.90):
        ic.glow(ic.lens((0.10, y), (0.80, y), 0.05), FIRE, depth=0.025)
    ic.glow(ic.circle((0.78, 0.50), 0.13), SPARK, depth=0.08)


def ember_field(ic):
    # "Set the ground ahead ablaze"
    ic.part(ic.poly([(0.0, 1.0), (0.0, 0.52), (1.0, 0.44), (1.0, 1.0)]), SHADE, shadow=0.04)
    for x, y, h in ((0.20, 0.62, 0.34), (0.56, 0.56, 0.42), (0.86, 0.60, 0.30), (0.36, 0.84, 0.36), (0.74, 0.88, 0.40), (0.08, 0.92, 0.26)):
        w = h * 0.36
        ic.glow(ic.poly([(x - w, y), (x - w * 0.6, y - h * 0.5), (x - w * 0.9, y - h * 0.7), (x, y - h), (x + w * 0.5, y - h * 0.55), (x + w, y - h * 0.75), (x + w, y)]), FIRE, depth=w * 0.7, ink=True)


def inferno(ic):
    # "a pillar of fire floors everything around you"
    ic.glow(ic.poly(oval((0.50, 0.86), 0.52, 0.16)) & ~ic.poly(oval((0.50, 0.86), 0.36, 0.08)), FIRE, depth=0.04)
    flames(ic, [(0.26, 0.90), (0.20, 0.56), (0.30, 0.64), (0.26, 0.28), (0.38, 0.40), (0.42, 0.06), (0.52, 0.22), (0.60, -0.04), (0.66, 0.34), (0.76, 0.20),
        (0.72, 0.60), (0.82, 0.54), (0.74, 0.90)], 0.14)
    ground(ic, 0.92)


def rending_fang(ic):
    # "Lunge at the nearest enemy and rake it three times"
    for k, dx in enumerate((-0.26, 0.0, 0.26)):
        ic.glow(ic.lens((0.34 + dx, 0.00), (0.66 + dx, 1.00), 0.17), BLOOD if k != 1 else MOON, depth=0.055, ink=True)
    for x, y in ((0.16, 0.86), (0.88, 0.14)):
        ic.glow(ic.star((x, y), 0.07, 4, 0.3, 0.0), SPARK, depth=0.03)


def pounce(ic):
    # "A huge bounding leap toward where you aim"
    ic.glow(ic.path(arc((0.30, 0.96), 0.70, -120.0, -30.0), 0.03, 0.14), MOON, depth=0.05)
    wolf_head(ic, (0.54, 0.50), 16.0, 0.48)


def howl(ic):
    # "Howl: for 8 s you hit 25% harder and run faster"
    ic.glow(ic.circle((0.70, 0.28), 0.30), MOON, depth=0.14)
    wolf_head(ic, (0.50, 0.66), -48.0, 0.48)


def vine_snare(ic):
    # "a seed that bursts into grasping vines, rooting enemies where they stand"
    ic.part(ic.poly([(0.06, 1.0), (0.22, 0.86), (0.50, 0.82), (0.78, 0.86), (0.94, 1.0)]), STONE, shadow=0.04)
    ic.glow(ic.circle((0.50, 0.46), 0.16), VENOM, depth=0.10)
    for sgn in (-1, 1):
        cx = 0.5 + sgn * 0.02
        pts = [(cx + sgn * 0.10, 0.92), (cx + sgn * 0.32, 0.74), (cx + sgn * 0.42, 0.46), (cx + sgn * 0.30, 0.20), (cx + sgn * 0.08, 0.12), (cx - sgn * 0.02, 0.26)]
        ic.part(ic.path(pts, 0.14, 0.055), LEAF, shadow=0.045)
        for (x, y), (ox, oy) in (((cx + sgn * 0.41, 0.58), (sgn * 0.12, -0.03)), ((cx + sgn * 0.34, 0.28), (sgn * 0.10, -0.09))):
            ic.part(ic.poly([(x, y - 0.045), (x + ox, y + oy), (x, y + 0.045)]), LEAF, shadow=0.02)
    ic.part(ic.path([(0.50, 0.96), (0.46, 0.78), (0.56, 0.64), (0.50, 0.52)], 0.12, 0.055), LEAF, shadow=0.04)


def vine_swing(ic):
    # "Shoot a vine at whatever you aim at and swing from it": the vine round its branch, the swing under it
    ic.glow(ic.path(arc((0.30, 0.10), 0.84, 28.0, 80.0), 0.03, 0.14), LEAFWIND, depth=0.05)
    ic.part(ic.capsule((-0.06, 0.16), (1.06, 0.08), 0.13), WOOD, shadow=0.04)
    ic.part(ic.circle((0.30, 0.13), 0.115) & ~ic.circle((0.30, 0.13), 0.05), LEAF, shadow=0.03)
    ic.part(ic.path([(0.32, 0.22), (0.38, 0.44), (0.54, 0.66), (0.80, 0.86)], 0.085, 0.075), LEAF, shadow=0.03)
    for (x, y), ang in (((0.46, 0.44), 20.0), ((0.60, 0.80), 150.0), ((0.16, 0.30), 100.0)):
        leaf(ic, (x, y), ang, 0.10)
    ic.glow(ic.star((0.84, 0.88), 0.09, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def thorn_whip(ic):
    # "Lash a thorned vine through everything in a line in front of you"
    pts = [(-0.04, 0.84), (0.16, 0.58), (0.36, 0.70), (0.56, 0.40), (0.76, 0.50), (0.94, 0.18)]
    ic.glow(ic.path(pts, 0.16, 0.10), LEAFWIND, depth=0.04)
    ic.part(ic.path(pts, 0.085, 0.05), LEAF, shadow=0.03)
    for k in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[k], pts[k + 1]
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        nx, ny = -(y1 - y0), (x1 - x0)
        ln = math.hypot(nx, ny)
        sgn = 1.0 if k % 2 == 0 else -1.0
        ic.part(ic.poly([(mx - (x1 - x0) * 0.16, my - (y1 - y0) * 0.16), (mx + nx / ln * 0.10 * sgn, my + ny / ln * 0.10 * sgn), (mx + (x1 - x0) * 0.16, my + (y1 - y0) * 0.16)]), LEAF, shadow=0.02)
    ic.glow(ic.star((0.94, 0.16), 0.10, 6, 0.4, 0.2), SPARK, depth=0.04, ink=True)


def falling_moon(ic):
    # "one turn over forward with it held out (the point draws a full moon), a dive"
    ic.glow(ic.circle((0.50, 0.46), 0.45) & ~ic.circle((0.50, 0.46), 0.33), MOON, depth=0.045)
    ic.glow(ic.lens((0.50, 0.10), (0.50, 1.04), 0.16), PETAL, depth=0.05)
    katana(ic, (0.44, -0.46), (0.52, 0.94), bend=0.05, w=0.10)


# ----------------------------------------------------------------------------------------------------------------
# Perks
# ----------------------------------------------------------------------------------------------------------------
def perk_c_focus(ic):
    # "Your ultimate charges 15% faster, and you win 10% more experience": a cut gem, catching the light
    ic.part(ic.poly([(0.50, 0.08), (0.84, 0.36), (0.50, 0.94), (0.16, 0.36)]), CYAN, metal=True, shadow=0.10)
    ic.flat(ic.capsule((0.16, 0.36), (0.84, 0.36), 0.03) | ic.capsule((0.36, 0.36), (0.50, 0.08), 0.025) | ic.capsule((0.64, 0.36), (0.50, 0.08), 0.025)
        | ic.capsule((0.36, 0.36), (0.50, 0.94), 0.025) | ic.capsule((0.64, 0.36), (0.50, 0.94), 0.025), CYAN[0])
    ic.glow(ic.star((0.76, 0.18), 0.12, 4, 0.25, 0.0), SPARK, depth=0.04, ink=True)


def perk_t_bounty(ic):
    # "+15% damage to elites and bosses": the wanted poster
    ic.part(ic.poly([(0.16, 0.06), (0.86, 0.10), (0.82, 0.96), (0.14, 0.92)]), BONE, shadow=0.06)
    ic.flat(ic.poly([(0.24, 0.14), (0.78, 0.17), (0.78, 0.26), (0.24, 0.23)]), hx("8a1c1c"))
    ic.part(ic.circle((0.50, 0.50), 0.17) | ic.poly([(0.40, 0.58), (0.60, 0.58), (0.58, 0.74), (0.42, 0.74)]), SHADE, shadow=0.04)
    ic.flat(ic.circle((0.44, 0.50), 0.04) | ic.circle((0.57, 0.50), 0.04), BONE[2])
    ic.flat(ic.poly([(0.26, 0.82), (0.74, 0.84), (0.74, 0.88), (0.26, 0.86)]), BONE[0])


def perk_t_hands(ic):
    # "You eat and drink 35% faster": the bottle, snatched up
    for y in (0.26, 0.50, 0.74):
        ic.glow(ic.lens((0.02, y + 0.10), (0.40, y), 0.06), SPARK, depth=0.03)
    f = Frame((0.40, 0.92), -66.0, 0.86)
    ic.part(ic.poly(f.pts([(0.0, -0.20), (0.52, -0.20), (0.66, -0.08), (0.92, -0.08), (0.92, 0.08), (0.66, 0.08), (0.52, 0.20), (0.0, 0.20)])), GLASS, metal=True, shadow=0.06)
    ic.part(ic.poly(f.pts([(0.12, -0.21), (0.40, -0.21), (0.40, 0.21), (0.12, 0.21)])), BONE, shadow=0.03)
    ic.part(ic.poly(f.pts([(0.90, -0.10), (1.02, -0.10), (1.02, 0.10), (0.90, 0.10)])), WOOD, shadow=0.02)


def perk_t_hide(ic):
    # "+10 defense and +30 max health": a hide shield, studded
    ic.part(ic.poly([(0.14, 0.10), (0.86, 0.10), (0.86, 0.52), (0.50, 0.96), (0.14, 0.52)]), LEATHER, shadow=0.09)
    ic.part(ic.poly([(0.14, 0.10), (0.86, 0.10), (0.86, 0.52), (0.50, 0.96), (0.14, 0.52)]) & ~ic.poly([(0.22, 0.18), (0.78, 0.18), (0.78, 0.50), (0.50, 0.84), (0.22, 0.50)]), IRON, metal=True, shadow=0.03)
    for x, y in ((0.36, 0.32), (0.64, 0.32), (0.50, 0.50), (0.38, 0.62), (0.62, 0.62)):
        ic.part(ic.circle((x, y), 0.045), GOLD, metal=True, shadow=0.02)


def perk_t_learner(ic):
    # "15% more experience, and every tree learns 15% faster": the open book
    ic.part(ic.poly([(0.04, 0.34), (0.50, 0.44), (0.96, 0.34), (0.96, 0.84), (0.50, 0.94), (0.04, 0.84)]), LEATHER, shadow=0.05)
    ic.part(ic.poly([(0.10, 0.30), (0.50, 0.40), (0.50, 0.86), (0.10, 0.78)]), BONE, shadow=0.05)
    ic.part(ic.poly([(0.90, 0.30), (0.50, 0.40), (0.50, 0.86), (0.90, 0.78)]), BONE, shadow=0.05)
    for y in (0.48, 0.58, 0.68):
        ic.flat(ic.capsule((0.18, y - 0.04), (0.42, y + 0.02), 0.022) | ic.capsule((0.58, y + 0.02), (0.82, y - 0.04), 0.022), BONE[0])
    ic.glow(ic.star((0.50, 0.18), 0.15, 4, 0.25, 0.0), SPARK, depth=0.05, ink=True)


def perk_t_legend(ic):
    # "+60 max health, +8 defense, and ...": the star in its laurels
    for sgn in (-1.0, 1.0):
        for k in range(5):
            a = math.radians(100.0 + k * 34.0)
            c = (0.5 + sgn * math.cos(a) * -0.38, 0.54 + math.sin(a) * 0.38)
            leaf(ic, c, (math.degrees(a) - 60.0) * sgn + (0.0 if sgn > 0 else 180.0), 0.10, LEAF)
    ic.part(ic.star((0.50, 0.48), 0.30, 5, 0.42, math.radians(-90.0)), GOLD, metal=True, shadow=0.06)


def perk_t_presence(ic):
    # "Common foes' blows hit you 25% softer": the captain's hat
    ic.glow(ic.star((0.50, 0.46), 0.50, 10, 0.6, 0.1), IMPACT, depth=0.08)
    ic.part(ic.poly([(0.04, 0.70), (0.20, 0.52), (0.50, 0.60), (0.80, 0.52), (0.96, 0.70), (0.50, 0.84)]), SHADE, shadow=0.06)
    ic.part(ic.poly([(0.24, 0.56), (0.32, 0.24), (0.50, 0.16), (0.68, 0.24), (0.76, 0.56), (0.50, 0.64)]), SHADE, shadow=0.07)
    ic.part(ic.poly([(0.26, 0.50), (0.50, 0.58), (0.74, 0.50), (0.75, 0.57), (0.50, 0.65), (0.25, 0.57)]), GOLD, metal=True, shadow=0.02)
    ic.part(ic.circle((0.50, 0.38), 0.085), BONE, shadow=0.03)
    ic.flat(ic.circle((0.47, 0.38), 0.022) | ic.circle((0.53, 0.38), 0.022), INK)


def perk_t_rally(ic):
    # "You get a crewmate up 50% faster": the horn
    f = Frame((0.14, 0.74), -30.0, 0.80)
    ic.part(ic.poly(f.pts([(0.0, -0.05), (0.60, -0.12), (0.96, -0.36), (1.02, 0.34), (0.60, 0.12), (0.0, 0.05)])), GOLD, metal=True, shadow=0.07)
    ic.part(ic.poly(f.pts([(0.92, -0.40), (1.04, -0.40), (1.08, 0.38), (0.96, 0.38)])), GOLD, metal=True, shadow=0.03)
    ic.part(ic.capsule(f.pt(-0.08, 0.0), f.pt(0.04, 0.0), 0.10), IRON, metal=True, shadow=0.02)
    for r in (0.20, 0.34):
        ic.glow(ic.path(arc((0.80, 0.26), r, -80.0, 20.0), 0.04, 0.04), IMPACT, depth=0.03, ink=True)


def perk_t_seadog(ic):
    # "Aboard a ship your stamina refills twice as fast": the anchor
    ic.part(ic.circle((0.50, 0.16), 0.11) & ~ic.circle((0.50, 0.16), 0.05), IRON, metal=True, shadow=0.03)
    ic.part(ic.capsule((0.50, 0.26), (0.50, 0.86), 0.10), IRON, metal=True, shadow=0.04)
    ic.part(ic.capsule((0.28, 0.36), (0.72, 0.36), 0.08), IRON, metal=True, shadow=0.03)
    ic.part(ic.path(arc((0.50, 0.56), 0.34, 20.0, 160.0), 0.10, 0.10), IRON, metal=True, shadow=0.04)
    for sgn in (-1.0, 1.0):
        ic.part(ic.poly([(0.5 + sgn * 0.40, 0.56), (0.5 + sgn * 0.24, 0.62), (0.5 + sgn * 0.34, 0.78)]), IRON, metal=True, shadow=0.03)
    ic.glow(ic.lens((0.02, 0.94), (0.98, 0.94), 0.10), WATER, depth=0.04)


def perk_t_treasure(ic):
    # "Closed chests within 60 m show on your compass": the chest, shining
    ic.glow(ic.star((0.50, 0.40), 0.52, 10, 0.55, 0.1), SPARK, depth=0.07)
    ic.part(ic.poly([(0.12, 0.50), (0.88, 0.50), (0.88, 0.92), (0.12, 0.92)]), WOOD, shadow=0.07)
    ic.part(ic.poly([(0.12, 0.50), (0.20, 0.30), (0.80, 0.30), (0.88, 0.50)]), WOOD, shadow=0.05)
    for x in (0.24, 0.72):
        ic.part(ic.poly([(x, 0.30), (x + 0.07, 0.30), (x + 0.07, 0.92), (x, 0.92)]), GOLD, metal=True, shadow=0.02)
    ic.part(ic.poly([(0.10, 0.47), (0.90, 0.47), (0.90, 0.54), (0.10, 0.54)]), GOLD, metal=True, shadow=0.02)
    ic.part(ic.poly([(0.44, 0.48), (0.56, 0.48), (0.56, 0.66), (0.44, 0.66)]), GOLD, metal=True, shadow=0.03)
    ic.flat(ic.circle((0.50, 0.57), 0.028), INK)


def perk_t_warlord(ic):
    # "+12% damage with everything": crossed blades under a red star
    cutlass(ic, (0.02, 1.08), (0.82, 0.14), bend=0.06, w=0.14)
    cutlass(ic, (0.98, 1.08), (0.18, 0.14), bend=-0.06, w=0.14)
    ic.part(ic.star((0.50, 0.30), 0.22, 5, 0.45, math.radians(-90.0)), CLOTH, shadow=0.05)


def perk_t_wind(ic):
    # "Once a fight, dropping below 30% health refills your stamina and energy": breath coming back
    for turn in (0.0, 180.0):
        pts = []
        for k in range(9):
            t = k / 8.0
            a = math.radians(turn + 250.0 * t)
            r = 0.50 * (1.0 - 0.55 * t)
            pts.append((0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r))
        ic.glow(ic.path(pts, 0.035, 0.13), WIND, depth=0.05)
    heart(ic, (0.50, 0.50), 0.36, VENOM)


def perk_v_adren(ic):
    # "Below 35% health you hit 25% harder": the heart, struck by lightning
    heart(ic, (0.50, 0.52), 0.78, HEAT)
    ic.glow(ic.poly([(0.60, 0.06), (0.34, 0.50), (0.50, 0.52), (0.40, 0.94), (0.70, 0.42), (0.52, 0.40)]), BOLT, depth=0.05, ink=True)


def perk_v_last(ic):
    # "a blow that would kill you leaves you at 1 health instead": the heart, bound up and still beating
    heart(ic, (0.50, 0.52), 0.78, HEAT)
    ic.flat(ic.path([(0.50, 0.30), (0.42, 0.48), (0.54, 0.58), (0.46, 0.86)], 0.035), INK)
    ic.part(ic.poly([(0.12, 0.50), (0.88, 0.36), (0.90, 0.48), (0.14, 0.62)]), BONE, shadow=0.03)
    ic.part(ic.poly([(0.18, 0.30), (0.84, 0.60), (0.80, 0.70), (0.14, 0.40)]), BONE, shadow=0.03)


def perk_v_mend(ic):
    # "Out of combat you heal 2.5 health a second": the green cross
    ic.glow(ic.circle((0.50, 0.50), 0.46), VENOM, depth=0.20)
    ic.part(ic.poly([(0.38, 0.14), (0.62, 0.14), (0.62, 0.38), (0.86, 0.38), (0.86, 0.62), (0.62, 0.62), (0.62, 0.86), (0.38, 0.86), (0.38, 0.62), (0.14, 0.62),
        (0.14, 0.38), (0.38, 0.38)]), WHITE, shadow=0.06)
    leaf(ic, (0.80, 0.18), -40.0, 0.11)


def perk_v_stomach(ic):
    # "Food and drink heal you 40% more": the joint of meat
    ic.part(ic.capsule((0.20, 0.82), (0.44, 0.58), 0.10), BONE, shadow=0.03)
    ic.part(ic.circle((0.14, 0.82), 0.075) | ic.circle((0.20, 0.90), 0.075), BONE, shadow=0.03)
    ic.part(ic.poly(oval((0.60, 0.42), 0.32, 0.28)), MEAT, shadow=0.10)
    ic.flat(ic.lens((0.48, 0.30), (0.66, 0.24), 0.05), MEAT[4])
    for x, y in ((0.86, 0.14), (0.90, 0.72)):
        ic.glow(ic.star((x, y), 0.07, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


# ----------------------------------------------------------------------------------------------------------------
# Movement (the skill map's moves): a mix of small posed figures, things and arrows, so no two look alike
# ----------------------------------------------------------------------------------------------------------------
def man(ic, head, chest, hip, arms, legs, w=0.075, mat=None):
    """A little figure: `arms` and `legs` are lists of points from the chest and the hip."""
    m = BONE if mat is None else mat
    for pts in legs:
        ic.part(ic.path([hip] + list(pts), w * 1.15, w), m, shadow=0.025)
    ic.part(ic.capsule(chest, hip, w * 1.9), m, shadow=0.035)
    for pts in arms:
        ic.part(ic.path([chest] + list(pts), w, w * 0.85), m, shadow=0.025)
    ic.part(ic.circle(head, w * 1.45), m, shadow=0.03)


def boot(ic, knee, ankle, toe, w=0.17):
    """A sea boot from the knee down: leather, a turned cuff, a gold buckle."""
    ic.part(ic.capsule(knee, ankle, w), LEATHER, shadow=0.04)
    ic.part(ic.path([ankle, toe], w * 1.05, w * 0.78), LEATHER, shadow=0.04)
    ic.part(ic.capsule((knee[0] - w * 0.1, knee[1]), (knee[0] + w * 0.1, knee[1]), w * 1.3), BONE, shadow=0.03)
    ic.part(ic.circle((ankle[0] + (toe[0] - ankle[0]) * 0.3, ankle[1] + (toe[1] - ankle[1]) * 0.3), w * 0.2), GOLD, metal=True, shadow=0.02)


def cloud(ic, c, sz):
    x, y = c
    ic.part(ic.circle((x - 0.42 * sz, y + 0.08 * sz), 0.30 * sz) | ic.circle((x, y - 0.10 * sz), 0.40 * sz) | ic.circle((x + 0.44 * sz, y + 0.06 * sz), 0.32 * sz)
        | ic.poly([(x - 0.66 * sz, y + 0.10 * sz), (x + 0.70 * sz, y + 0.10 * sz), (x + 0.60 * sz, y + 0.36 * sz), (x - 0.56 * sz, y + 0.36 * sz)]), WHITE, shadow=0.05)


def chevron(ic, c, sz, ang, mat=WIND, depth=0.05):
    f = Frame(c, ang, sz)
    ic.glow(ic.poly(f.pts([(-0.50, -0.50), (0.06, -0.50), (0.56, 0.0), (0.06, 0.50), (-0.50, 0.50), (0.0, 0.0)])), mat, depth=depth, ink=True)


def wall(ic, x0, x1):
    ic.part(ic.poly([(x0, -0.02), (x1, -0.02), (x1, 1.02), (x0, 1.02)]), STONE, shadow=0.04)
    for k, y in enumerate((0.18, 0.40, 0.62, 0.84)):
        ic.flat(ic.capsule((x0, y), (x1, y), 0.025), STONE[0])
        xm = x0 + (x1 - x0) * (0.35 if k % 2 == 0 else 0.68)
        ic.flat(ic.capsule((xm, y), (xm, y + 0.22), 0.025), STONE[0])


def move_roll(ic):
    # "Your dodge is a tumbling roll"
    ic.glow(ic.path(arc((0.50, 0.54), 0.44, 150.0, 400.0), 0.03, 0.13), WIND, depth=0.05)
    ic.part(ic.circle((0.50, 0.58), 0.25), BONE, shadow=0.07)
    ic.part(ic.circle((0.66, 0.40), 0.11), BONE, shadow=0.03)
    ic.flat(ic.path(arc((0.50, 0.58), 0.15, 200.0, 330.0), 0.03), BONE[0])
    ground(ic, 0.90)


def move_sidestep(ic):
    # a step aside: where you stood, where you are
    ghost_bust(ic, (0.28, 0.50), 0.50, WIND)
    for y in (0.34, 0.56, 0.78):
        ic.glow(ic.lens((0.34, y), (0.62, y), 0.05), WIND, depth=0.025)
    bust(ic, (0.72, 0.50), 0.50, BONE)


def move_rolling_guard(ic):
    # a roll with your guard up
    ic.glow(ic.path(arc((0.42, 0.54), 0.42, 120.0, 330.0), 0.03, 0.12), WIND, depth=0.05)
    ic.part(ic.circle((0.40, 0.58), 0.22), BONE, shadow=0.06)
    ic.part(ic.circle((0.30, 0.38), 0.10), BONE, shadow=0.03)
    ic.part(ic.circle((0.70, 0.52), 0.25), WOOD, shadow=0.06)
    ic.part((ic.circle((0.70, 0.52), 0.25) & ~ic.circle((0.70, 0.52), 0.19)) | ic.circle((0.70, 0.52), 0.07), IRON, metal=True, shadow=0.03)
    ground(ic, 0.90)


def move_afterimage(ic):
    # an image of you left behind
    ghost_bust(ic, (0.20, 0.50), 0.44, WIND)
    ghost_bust(ic, (0.46, 0.50), 0.48, WIND)
    bust(ic, (0.74, 0.50), 0.52, BONE)


def move_shove(ic):
    # a shove: the open hand, them going over
    for y in (0.30, 0.50, 0.70):
        ic.glow(ic.lens((0.44, y), (0.66, y), 0.055), SPARK, depth=0.03, ink=True)
    f = Frame((0.84, 0.56), 24.0, 0.44)
    ic.part(ic.poly(f.pts([(-0.62, 0.95), (-0.50, 0.30), (0.0, 0.12), (0.50, 0.30), (0.62, 0.95)])), SHADE, shadow=0.05)
    ic.part(ic.circle(f.pt(0.0, -0.18), 0.36 * 0.44), SHADE, shadow=0.05)
    palm_front(ic, (0.24, 0.50), 0.44)


def move_disarm(ic):
    # their blade knocked out of their hand, turning in the air
    ic.glow(ic.path(arc((0.52, 0.44), 0.44, 200.0, 320.0), 0.03, 0.10), WIND, depth=0.04)
    ic.glow(ic.path(arc((0.52, 0.44), 0.44, 20.0, 140.0), 0.03, 0.10), WIND, depth=0.04)
    cutlass(ic, (0.24, 0.72), (0.82, 0.14), bend=0.06, w=0.13)
    ic.glow(ic.star((0.22, 0.86), 0.13, 6, 0.4, 0.2), SPARK, depth=0.05, ink=True)


def move_planted(ic):
    # feet planted: nothing moves you
    ground(ic, 0.76)
    for x in (0.30, 0.70):
        ic.flat(ic.path([(x, 0.78), (x - 0.06, 0.88), (x + 0.02, 1.0)], 0.03), INK)
    boot(ic, (0.30, 0.14), (0.30, 0.62), (0.14, 0.72), w=0.19)
    boot(ic, (0.70, 0.14), (0.70, 0.62), (0.86, 0.72), w=0.19)
    for x in (0.50,):
        chevron(ic, (x, 0.40), 0.26, 90.0, SPARK, 0.04)


def move_slidekick(ic):
    # a slide in low, boot first
    ground(ic, 0.84)
    for x, r in ((0.10, 0.08), (0.22, 0.10), (0.36, 0.07)):
        ic.part(ic.circle((x, 0.80), r), SMOKE, shadow=0.03)
    man(ic, (0.30, 0.44), (0.40, 0.56), (0.56, 0.68), [[(0.30, 0.70), (0.22, 0.78)], [(0.50, 0.44)]], [[(0.76, 0.66), (0.94, 0.60)], [(0.70, 0.78), (0.82, 0.80)]], w=0.085)
    ic.glow(ic.star((0.94, 0.56), 0.09, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def move_dashstrike(ic):
    # a dash that ends in a cut
    for y, x1 in ((0.18, 0.56), (0.82, 0.56)):
        ic.glow(ic.lens((0.02, y), (x1, y), 0.06), WIND, depth=0.03)
    ic.glow(ic.lens((-0.05, 0.56), (0.84, 0.44), 0.26), WIND, depth=0.08)
    cutlass(ic, (-0.50, 0.66), (0.92, 0.40), bend=-0.05, w=0.16, guard=False)
    ic.glow(ic.star((0.90, 0.40), 0.10, 4, 0.3, 0.0), SPARK, depth=0.035, ink=True)


def move_twindash(ic):
    # two dashes, one after the other
    for y in (0.14, 0.86):
        ic.glow(ic.lens((0.02, y), (0.60, y), 0.05), WIND, depth=0.025)
    chevron(ic, (0.30, 0.50), 0.50, 0.0)
    chevron(ic, (0.68, 0.50), 0.50, 0.0)


def move_crash(ic):
    # a landing that hits like a blow
    ic.glow(ic.poly(oval((0.50, 0.84), 0.52, 0.17)) & ~ic.poly(oval((0.50, 0.84), 0.34, 0.08)), SPARK, depth=0.04)
    ground(ic, 0.88)
    for x, lean in ((0.12, -0.04), (0.88, 0.04)):
        shard(ic, x, 0.88, 0.22, 0.08, lean)
    boot(ic, (0.56, -0.12), (0.52, 0.56), (0.34, 0.74), w=0.21)
    ic.glow(ic.star((0.42, 0.84), 0.15, 8, 0.4, 0.2), SPARK, depth=0.05, ink=True)


def move_dolphin(ic):
    # a leap out of the water and back in
    ic.glow(ic.path(arc((0.50, 0.92), 0.50, 200.0, 340.0), 0.03, 0.08), WIND, depth=0.03)
    body = [(0.16, 0.66), (0.26, 0.40), (0.48, 0.26), (0.70, 0.30), (0.86, 0.48)]
    ic.part(ic.path(body, 0.10, 0.20) | ic.path([(0.70, 0.30), (0.86, 0.48), (0.96, 0.56)], 0.20, 0.07), WATER, shadow=0.06)
    ic.part(ic.poly([(0.44, 0.24), (0.50, 0.04), (0.62, 0.24)]), WATER, shadow=0.03)
    ic.part(ic.poly([(0.20, 0.60), (0.02, 0.56), (0.12, 0.72), (0.06, 0.90), (0.24, 0.74)]), WATER, shadow=0.03)
    ic.flat(ic.circle((0.78, 0.40), 0.025), INK)
    ic.glow(ic.poly([(-0.04, 1.04), (-0.04, 0.84), (0.16, 0.76), (0.34, 0.86), (0.52, 0.78), (0.72, 0.88), (0.90, 0.78), (1.04, 0.86), (1.04, 1.04)]), WATER, depth=0.07, ink=True)


def move_airdash(ic):
    # a dash with nothing under you
    cloud(ic, (0.30, 0.80), 0.40)
    for y in (0.20, 0.56):
        ic.glow(ic.lens((0.02, y), (0.46, y), 0.05), WIND, depth=0.025)
    chevron(ic, (0.62, 0.38), 0.56, 0.0)


def move_skydash(ic):
    # a dash up into the sky
    cloud(ic, (0.24, 0.84), 0.34)
    ic.glow(ic.lens((0.06, 0.92), (0.52, 0.48), 0.10), WIND, depth=0.04)
    chevron(ic, (0.62, 0.38), 0.54, -45.0)
    for x, y in ((0.14, 0.20), (0.90, 0.80)):
        ic.glow(ic.star((x, y), 0.07, 4, 0.3, 0.0), SPARK, depth=0.03)


def move_skyleap(ic):
    # a leap over the clouds
    cloud(ic, (0.50, 0.84), 0.50)
    pts = arc((0.50, 0.86), 0.56, 200.0, 325.0)
    ic.glow(ic.path(pts, 0.05, 0.12), WIND, depth=0.045, ink=True)
    chevron(ic, pts[-1], 0.30, 60.0)
    ic.glow(ic.star((0.50, 0.14), 0.09, 4, 0.3, 0.0), SPARK, depth=0.03, ink=True)


def move_skywalk(ic):
    # steps across the sky: the prints you leave on the air
    for (x, y), sz in (((0.20, 0.80), 0.15), ((0.50, 0.54), 0.17), ((0.78, 0.26), 0.19)):
        ic.glow(ic.poly(oval((x, y + sz * 0.5), sz * 1.5, sz * 0.5)) & ~ic.poly(oval((x, y + sz * 0.5), sz * 1.0, sz * 0.26)), WIND, depth=0.03)
        ic.part(ic.poly(oval((x, y - sz * 0.25), sz * 0.48, sz * 0.72)), BONE, shadow=0.03)
        ic.part(ic.poly(oval((x, y + sz * 0.70), sz * 0.36, sz * 0.26)), BONE, shadow=0.02)


def move_geppo(ic):
    # a kick off the air itself
    ic.glow(ic.poly(oval((0.46, 0.80), 0.48, 0.15)) & ~ic.poly(oval((0.46, 0.80), 0.30, 0.07)), WIND, depth=0.04, ink=True)
    for x in (0.16, 0.46, 0.76):
        ic.glow(ic.lens((x, 0.98), (x, 0.86), 0.05), WIND, depth=0.025)
    boot(ic, (0.66, -0.10), (0.54, 0.50), (0.32, 0.66), w=0.20)
    ic.glow(ic.star((0.40, 0.78), 0.11, 6, 0.4, 0.2), SPARK, depth=0.04, ink=True)


def move_moonstep(ic):
    # a second step, off the moon
    ic.glow(ic.circle((0.42, 0.60), 0.38) & ~ic.circle((0.58, 0.48), 0.36), SPARK, depth=0.08, ink=True)
    boot(ic, (0.86, -0.10), (0.70, 0.30), (0.50, 0.40), w=0.16)
    for x, y in ((0.90, 0.70), (0.14, 0.16)):
        ic.glow(ic.star((x, y), 0.07, 4, 0.3, 0.0), SPARK, depth=0.03)


def move_heavenward(ic):
    # straight up
    ic.glow(ic.poly([(0.36, 1.04), (0.36, 0.46), (0.16, 0.46), (0.50, 0.04), (0.84, 0.46), (0.64, 0.46), (0.64, 1.04)]), WIND, depth=0.10, ink=True)
    for x, y in ((0.14, 0.78), (0.86, 0.72), (0.14, 0.18)):
        ic.glow(ic.star((x, y), 0.07, 4, 0.3, 0.0), SPARK, depth=0.03)


def move_glide(ic):
    # your coat spread like a wing
    for y, x0 in ((0.20, 0.60), (0.84, 0.50)):
        ic.glow(ic.lens((x0, y), (0.98, y - 0.04), 0.05), WIND, depth=0.025)
    ic.part(ic.poly([(0.06, 0.30), (0.50, 0.16), (0.94, 0.34), (0.74, 0.50), (0.50, 0.44), (0.26, 0.52)]), CLOTH, shadow=0.07)
    ic.flat(ic.capsule((0.50, 0.18), (0.50, 0.44), 0.025) | ic.capsule((0.50, 0.18), (0.26, 0.50), 0.02) | ic.capsule((0.50, 0.18), (0.74, 0.48), 0.02), CLOTH[0])
    man(ic, (0.50, 0.52), (0.50, 0.62), (0.50, 0.76), [[(0.30, 0.50)], [(0.70, 0.50)]], [[(0.44, 0.92)], [(0.58, 0.90)]], w=0.06)


def move_featherfall(ic):
    # "a longer one lands soft": a feather, coming down
    ic.glow(ic.path([(0.80, 0.06), (0.62, 0.30), (0.78, 0.52), (0.56, 0.76), (0.66, 0.96)], 0.04, 0.08), WIND, depth=0.03)
    f = Frame((0.20, 0.84), -52.0, 0.86)
    ic.part(ic.poly(f.pts([(0.10, 0.0), (0.30, -0.16), (0.62, -0.20), (0.96, -0.06), (1.0, 0.02), (0.70, 0.16), (0.36, 0.14)])), WHITE, shadow=0.06)
    ic.flat(ic.capsule(f.pt(-0.10, 0.02), f.pt(0.94, -0.01), 0.022), WHITE[0])
    for u in (0.36, 0.56, 0.76):
        ic.flat(ic.capsule(f.pt(u, 0.0), f.pt(u + 0.07, 0.13), 0.018) | ic.capsule(f.pt(u, 0.0), f.pt(u + 0.08, -0.16), 0.018), WHITE[1])


def move_walljump(ic):
    # off the wall and away
    wall(ic, -0.02, 0.26)
    pts = arc((0.26, 0.90), 0.60, -84.0, -20.0)
    ic.glow(ic.path(pts, 0.04, 0.11), WIND, depth=0.04, ink=True)
    chevron(ic, pts[-1], 0.26, 30.0)
    man(ic, (0.50, 0.50), (0.46, 0.60), (0.40, 0.72), [[(0.60, 0.50)], [(0.38, 0.48)]], [[(0.28, 0.66)], [(0.30, 0.84)]], w=0.065)


def move_wallkick(ic):
    # a kick against the wall
    wall(ic, 0.74, 1.02)
    for y in (0.24, 0.80):
        ic.glow(ic.lens((0.02, y), (0.44, y), 0.05), WIND, depth=0.025)
    boot(ic, (-0.10, 0.34), (0.44, 0.48), (0.70, 0.44), w=0.20)
    ic.glow(ic.star((0.74, 0.44), 0.14, 6, 0.4, 0.2), SPARK, depth=0.05, ink=True)


def move_wallrun(ic):
    # running along the wall
    wall(ic, 0.70, 1.02)
    for y, r in ((0.90, 0.07), (0.76, 0.05)):
        ic.part(ic.circle((0.64, y), r), SMOKE, shadow=0.02)
    man(ic, (0.36, 0.30), (0.42, 0.40), (0.50, 0.56), [[(0.30, 0.52)], [(0.56, 0.30)]], [[(0.66, 0.50)], [(0.52, 0.76), (0.66, 0.80)]], w=0.07)
    chevron(ic, (0.30, 0.14), 0.22, -90.0)


SKILLS = {
    "sword": [("flying_slash", "Flying Slash", False, flying_slash), ("riposte", "Riposte", False, riposte),
        ("swordfish", "Swordfish Flurry", False, swordfish), ("kraken_wake", "Kraken's Wake  (ult)", True, kraken_wake),
        ("undertow", "Undertow  (ult)", True, undertow)],
    "katana": [("tiger_rush", "Tiger Rush", False, tiger_rush), ("iai_counter", "Iai Counter", False, iai_counter),
        ("wind_sever", "Wind Severer", False, wind_sever), ("twin_waves", "Twin Waves", False, twin_waves),
        ("side_step", "Side Step", False, side_step), ("phantom_step", "Phantom Step", False, phantom_step),
        ("petal_storm", "Thousand Petals  (ult)", True, petal_storm), ("moonlit_severance", "Moonlit Severance  (ult)", True, moonlit_severance),
        ("falling_moon", "Falling Moon (air move)", False, falling_moon)],
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
    "polearm": [("hundred_thrusts", "Hundred Thrusts", False, hundred_thrusts), ("dragon_sweep", "Dragon Sweep", False, dragon_sweep),
        ("vault_strike", "Vaulting Strike", False, vault_strike), ("thunder_javelin", "Thunder Javelin", False, thunder_javelin),
        ("windmill_guard", "Windmill Guard", False, windmill_guard), ("raijin_wheel", "Raijin's Wheel  (ult)", True, raijin_wheel),
        ("heavens_pike", "Heaven's Pike  (ult)", True, heavens_pike)],
    "hammer": [("skullcracker", "Skullcracker", False, skullcracker), ("rolling_quake", "Rolling Quake", False, rolling_quake),
        ("cyclone_crusher", "Cyclone Crusher", False, cyclone_crusher), ("cannonball_swing", "Cannonball Swing", False, cannonball_swing),
        ("anvil_counter", "Anvil Counter", False, anvil_counter), ("titans_fall", "Titan's Fall  (ult)", True, titans_fall),
        ("mountain_breaker", "Mountain Breaker  (ult)", True, mountain_breaker)],
    "greatsword": [("guardbreaker", "Guardbreaker", False, guardbreaker), ("crescent_gale", "Crescent Gale", False, crescent_gale),
        ("updraft", "Updraft", False, updraft), ("gatekeeper", "Gatekeeper", False, gatekeeper), ("tempest_turns", "Tempest Turns", False, tempest_turns),
        ("skysplitter", "Skysplitter  (ult)", True, skysplitter), ("eye_of_storm", "Eye of the Storm  (ult)", True, eye_of_storm)],
    "dual_axe": [("gallows_hook", "Gallows Hook", False, gallows_hook), ("hewing_frenzy", "Hewing Frenzy", False, hewing_frenzy),
        ("axestorm", "Axestorm", False, axestorm), ("ravens_return", "Ravens' Return", False, ravens_return),
        ("raiders_haul", "Raider's Haul", False, raiders_haul), ("fimbulwinter", "Fimbulwinter  (ult)", True, fimbulwinter),
        ("avalanche", "Avalanche  (ult)", True, avalanche)],
    "black_leg": [("rising_heel", "Rising Heel", False, rising_heel), ("hailstorm_heels", "Hailstorm Heels", False, hailstorm_heels),
        ("sky_chase", "Sky Chase", False, sky_chase), ("cleaver_kick", "Cleaver Kick", False, cleaver_kick), ("flambe_dash", "Flambe Dash", False, flambe_dash),
        ("last_course", "Last Course  (ult)", True, last_course), ("volcano_course", "Volcano Course  (ult)", True, volcano_course)],
    "unarmed": [("hip_toss", "Shoulder Throw", False, hip_toss), ("cannonball_fist", "Cannonball Fist", False, cannonball_fist),
        ("meteor_fist", "Meteor Fist", False, meteor_fist), ("hundred_fists", "Hundred Fists", False, hundred_fists),
        ("rising_dragon", "Rising Dragon", False, rising_dragon), ("palm_strike", "Shockwave Palm", False, palm_strike),
        ("sea_king_fist", "Leviathan Fist  (ult)", True, sea_king_fist), ("typhoon_rush", "Typhoon Rush  (ult)", True, typhoon_rush)],
    "rapier": [("needle_rain", "Needle Rain", False, needle_rain), ("glass_step", "Glass Step", False, glass_step),
        ("glass_feint", "Looking-Glass Feint", False, glass_feint), ("balestra", "Balestra", False, balestra),
        ("hall_of_mirrors", "Hall of Mirrors  (ult)", True, hall_of_mirrors), ("silver_meridian", "Silver Meridian  (ult)", True, silver_meridian)],
    "staff": [("leaf_wall", "Leaf Wall", False, leaf_wall), ("rising_gale", "Rising Gale", False, rising_gale),
        ("thousand_leaves", "Thousand Leaves", False, thousand_leaves), ("crane_vault", "Crane Vault", False, crane_vault),
        ("autumn_gale", "Autumn Gale  (ult)", True, autumn_gale), ("pillar_of_wind", "Pillar of Wind  (ult)", True, pillar_of_wind)],
    "sickle": [("binding_coil", "Binding Coil", False, binding_coil), ("serpent_lash", "Serpent Lash", False, serpent_lash),
        ("reel_and_reap", "Reel and Reap", False, reel_and_reap), ("hook_step", "Hook Step", False, hook_step),
        ("harvest_of_souls", "Harvest of Souls  (ult)", True, harvest_of_souls), ("soul_chain", "Soul Chain  (ult)", True, soul_chain)],
    "slingshot": [("fire_pellet", "Fire Pellet", False, fire_pellet), ("smoke_pellet", "Smoke Pellet", False, smoke_pellet),
        ("blast_pellet", "Blast Pellet", False, blast_pellet), ("sticky_pellet", "Sticky Pellet", False, sticky_pellet),
        ("bag_of_tricks", "Bag of Tricks  (ult)", True, bag_of_tricks), ("fireworks_finale", "Fireworks Finale  (ult)", True, fireworks_finale)],
    "long_gun": [("pin_shot", "Pinning Shot", False, pin_shot), ("powder_burst", "Powder Burst", False, powder_burst),
        ("volley_line", "Volley Line", False, volley_line), ("stock_sweep", "Stock Sweep", False, stock_sweep),
        ("hawkeye", "Hawkeye  (ult)", True, hawkeye), ("constellation", "Constellation  (ult)", True, constellation)],
    "cannon": [("canister_shot", "Canister Shot", False, canister_shot), ("chain_shot", "Chain Shot", False, chain_shot),
        ("mortar_lob", "Mortar Lob", False, mortar_lob), ("rocket_charge", "Rocket Charge", False, rocket_charge),
        ("leviathan_shell", "Leviathan Shell  (ult)", True, leviathan_shell), ("hellfire_barrage", "Hellfire Barrage  (ult)", True, hellfire_barrage)],
    "base": [("soru", "Squall Step", False, soru), ("tekkai", "Ballast", False, tekkai), ("edy_reinforce", "Reinforce", False, edy_reinforce),
        ("armament_coat", "Infuse", False, armament_coat), ("foresight", "Foresight", False, foresight), ("will_swell", "Swell", False, will_swell),
        ("will_wind", "Call the Wind", False, will_wind), ("will_twin", "Twin Finisher", False, will_twin), ("will_glimpse", "Glimpse", False, will_glimpse),
        ("will_flag", "Plant the Flag", False, will_flag), ("will_still_point", "Still Point", False, will_still_point),
        ("will_berserk", "Berserk (Fury Will)", False, will_berserk), ("conquerors_haki", "Captain's Will  (ult)", True, conquerors_haki)],
    "ember": [("fire_fist", "Cinder Fist", False, fire_fist), ("fire_ring", "Blazing Ring", False, fire_ring), ("flame_dash", "Flame Dash", False, flame_dash),
        ("ember_field", "Ember Field", False, ember_field), ("inferno", "Great Inferno  (ult)", True, inferno)],
    "wolf": [("rending_fang", "Rending Fang", False, rending_fang), ("pounce", "Pounce", False, pounce), ("howl", "Alpha Howl", False, howl)],
    "vine": [("vine_snare", "Vine Snare", False, vine_snare), ("vine_swing", "Vine Swing", False, vine_swing), ("thorn_whip", "Thorn Whip", False, thorn_whip)],
    "perk": [("perk_c_focus", "Focus", False, perk_c_focus), ("perk_t_bounty", "Bounty Hunter", False, perk_t_bounty), ("perk_t_hands", "Quick Hands", False, perk_t_hands),
        ("perk_t_hide", "Thick Hide", False, perk_t_hide), ("perk_t_learner", "Quick Learner", False, perk_t_learner), ("perk_t_legend", "Living Legend", False, perk_t_legend),
        ("perk_t_presence", "Captain's Presence", False, perk_t_presence), ("perk_t_rally", "Rallying Cry", False, perk_t_rally),
        ("perk_t_seadog", "Sea Dog", False, perk_t_seadog), ("perk_t_treasure", "Treasure Sense", False, perk_t_treasure),
        ("perk_t_warlord", "Warlord", False, perk_t_warlord), ("perk_t_wind", "Second Wind", False, perk_t_wind), ("perk_v_adren", "Adrenaline", False, perk_v_adren),
        ("perk_v_last", "Last Stand", False, perk_v_last), ("perk_v_mend", "Mend", False, perk_v_mend), ("perk_v_stomach", "Iron Stomach", False, perk_v_stomach)],
    "move_ground": [("move_roll", "Roll", False, move_roll), ("move_sidestep", "Sidestep", False, move_sidestep),
        ("move_rolling_guard", "Rolling Guard", False, move_rolling_guard), ("move_afterimage", "Afterimage", False, move_afterimage),
        ("move_shove", "Shove", False, move_shove), ("move_disarm", "Disarm", False, move_disarm), ("move_planted", "Planted", False, move_planted),
        ("move_slidekick", "Slide Kick", False, move_slidekick), ("move_dashstrike", "Dash Strike", False, move_dashstrike),
        ("move_twindash", "Twin Dash", False, move_twindash), ("move_crash", "Crash Landing", False, move_crash), ("move_dolphin", "Dolphin", False, move_dolphin)],
    "move_air": [("move_airdash", "Air Dash", False, move_airdash), ("move_skydash", "Sky Dash", False, move_skydash), ("move_skyleap", "Sky Leap", False, move_skyleap),
        ("move_skywalk", "Sky Walk", False, move_skywalk), ("move_geppo", "Air Step", False, move_geppo), ("move_moonstep", "Moon Step", False, move_moonstep),
        ("move_heavenward", "Heavenward", False, move_heavenward), ("move_glide", "Glide", False, move_glide), ("move_featherfall", "Feather Fall", False, move_featherfall),
        ("move_walljump", "Wall Jump", False, move_walljump), ("move_wallkick", "Wall Kick", False, move_wallkick), ("move_wallrun", "Wall Run", False, move_wallrun)],
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
                for n in (16, 32, 48):
                    p = os.path.join(ICONS, "skill_%s_%d.png" % (sid, n))
                    render(fn, n, tree, ult).save(p)
                    print("  wrote", os.path.relpath(p, ROOT))


if __name__ == "__main__":
    main()
