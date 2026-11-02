"""1.28 fighting staff: its techniques' skill icons (assets/textures/icons/skill_<id>.png, 24x24), leaves and wind:
spring green, leaf green, autumn gold. Drawn like gen_psx_textures.gen_skill_icons (its _icon adds the outline).
Run: py tools/texture_gen/gen_staff_icons.py"""
from __future__ import annotations

import math

from gen_psx_textures import _icon, hexc

WOOD = hexc("a06a3a") + (255,)
WOOD_D = hexc("6a4424") + (255,)
LEAF = hexc("6ac84a") + (255,)
LEAF_D = hexc("3a8a2a") + (255,)
GOLD = hexc("f8c840") + (255,)
WIND = hexc("e8fcd8") + (255,)


def staff(d, a, b):
    d.line([a, b], fill=WOOD, width=2)
    d.point(a, fill=WOOD_D)
    d.point(b, fill=WOOD_D)


def leaf(d, x, y, col=LEAF, ang=0.0):
    c, s = math.cos(ang), math.sin(ang)
    pts = [(x + c * 3, y + s * 3), (x - s * 1.5, y + c * 1.5), (x - c * 3, y - s * 3), (x + s * 1.5, y - c * 1.5)]
    d.polygon(pts, fill=col)


def leaf_wall(d):
    # the staff spun before you: a disc of blur and leaves caught in it
    d.ellipse([3, 3, 21, 21], outline=WIND)
    d.ellipse([6, 6, 18, 18], outline=LEAF_D)
    staff(d, (4, 19), (20, 5))
    leaf(d, 6, 8, LEAF, 0.6)
    leaf(d, 18, 17, GOLD, 2.2)


def rising_gale(d):
    # thrown up on the wind: the staff swept up, a curl of wind and a leaf rising
    d.arc([2, 6, 20, 24], 200, 340, fill=WIND, width=1)
    staff(d, (3, 21), (17, 4))
    leaf(d, 18, 7, GOLD, -0.8)
    leaf(d, 12, 12, LEAF, 0.3)


def thousand_leaves(d):
    # blows everywhere: a scatter of leaves and short staff strokes
    for i, (x, y) in enumerate(((5, 6), (12, 4), (19, 8), (6, 15), (14, 13), (19, 19), (9, 20))):
        leaf(d, x, y, GOLD if i % 3 == 0 else LEAF, i * 0.9)
    staff(d, (2, 12), (22, 12))


def crane_vault(d):
    # vaulting high over them: the staff planted, an arc over the top
    staff(d, (8, 22), (12, 6))
    d.arc([4, 2, 22, 18], 180, 360, fill=WIND, width=1)
    leaf(d, 20, 10, LEAF, 1.2)
    d.ellipse([15, 3, 19, 7], fill=GOLD)


def autumn_gale(d):
    # a whirlwind of gold leaves round the spun staff
    for r, col in ((10, WIND), (7, LEAF_D), (4, GOLD)):
        d.arc([12 - r, 12 - r, 12 + r, 12 + r], 30, 300, fill=col, width=1)
    for k in range(6):
        a = k * math.tau / 6
        leaf(d, 12 + 8 * math.cos(a), 12 + 8 * math.sin(a), GOLD if k % 2 else LEAF, a)
    staff(d, (6, 18), (18, 6))


def pillar_of_wind(d):
    # a pillar of wind up the planted staff, foes thrown high
    d.rectangle([9, 2, 15, 22], outline=WIND)
    staff(d, (12, 22), (12, 2))
    leaf(d, 6, 5, GOLD, 0.4)
    leaf(d, 18, 8, LEAF, 2.0)
    leaf(d, 5, 14, LEAF, 1.1)


if __name__ == "__main__":
    for fn in (leaf_wall, rising_gale, thousand_leaves, crane_vault, autumn_gale, pillar_of_wind):
        _icon("skill_" + fn.__name__, fn)
