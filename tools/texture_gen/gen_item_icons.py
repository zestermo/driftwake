"""Item icons, ink and cel (2026-11-11): the drawn items (food, ingredients, materials, Driftfruit, coin and
treasure) in the skill icons' style: flat colour, one hard shadow along the lower right, a light edge up and left,
black ink round every part. No plate and no frame: one object on a transparent ground, filling most of the tile.

Each is a description of parts in 0..1 coordinates (gen_skill_icons.Icon), so it renders at any size.

    py tools/texture_gen/gen_item_icons.py            # review sheet -> tools/dev/out/iconreview/items_new.png
    py tools/texture_gen/gen_item_icons.py --write    # also assets/textures/icons/<id>.png (and _16 / _48)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_skill_icons import (BONE, CLOTH, CYAN, DUST, FUR, GOLD, ICONS, INK, LEAF, LEATHER, MEAT, REVIEW, ROOT, SILVER, SMOKE, STEEL,  # noqa: E402
    STONE, TEAL, WATER, WHITE, WOOD, Icon, arc, hx, oval, ramp, up)

AMBER = ramp("2a1208", "5c2a10", "8e4a1c", "c47c3c", "f2b878")
COPPER = ramp("4a1c0c", "9a4418", "d87a34", "f8b070", "ffe0c0")
ORANGE = ramp("7a2c06", "c85a10", "f6921e", "ffc060", "ffeab0")
BROTH = ramp("5a2a10", "a0521c", "d0863a", "ecb468", "ffe2a8")
CREAM = ramp("6a5a40", "b8a47c", "e6d6ac", "f8eed0", "ffffff")
SHELL = ramp("5a3046", "a86a86", "e2aabc", "f8dce4", "ffffff")
EMBER_F = ramp("6a1c08", "c0401a", "ff8026", "ffb866", "ffe8c0")
STORM_F = ramp("1c2a6a", "3a5ab8", "5a8ae0", "b8d6ff", "ffffff")


# ----------------------------------------------------------------------------------------------------------------
# Shared pieces
# ----------------------------------------------------------------------------------------------------------------
def ball(ic, c, r, mat, metal=False, shadow=0.10, shine=True):
    """A round thing: its shadow down and right, a spot of light up and left."""
    ic.part(ic.circle(c, r), mat, metal=metal, shadow=shadow)
    if shine:
        ic.flat(ic.poly(oval((c[0] - r * 0.38, c[1] - r * 0.42), r * 0.26, r * 0.16, 12)), mat[4])


def leaf_on(ic, at, ang=-25.0, size=0.16, mat=LEAF):
    """A stalk and a leaf on top of a fruit at `at`."""
    ic.part(ic.capsule(at, (at[0] + 0.02, at[1] - 0.09), 0.045), WOOD, shadow=0.02)
    a = math.radians(ang)
    tip = (at[0] + 0.02 + math.cos(a) * size * 2.0, at[1] - 0.08 + math.sin(a) * size * 2.0)
    ic.part(ic.lens((at[0] + 0.02, at[1] - 0.08), tip, size), mat, shadow=0.03)


def swirl(ic, c, r, col, turn=0.0):
    """One of a Driftfruit's curls: a little spiral, inked in the fruit's own dark."""
    pts = []
    for k in range(10):
        t = k / 9.0
        a = math.radians(turn + 400.0 * t)
        pts.append((c[0] + math.cos(a) * r * (1.0 - 0.72 * t), c[1] + math.sin(a) * r * (1.0 - 0.72 * t)))
    ic.flat(ic.path(pts, 0.032), col)


def driftfruit(ic, mat, curl=None):
    """A Driftfruit: a round odd fruit in its colour, curls all over it, a stalk and a leaf."""
    c, r = (0.50, 0.58), 0.37
    ball(ic, c, r, mat, shadow=0.11)
    body = ic.circle(c, r - 0.03)
    col = mat[0] if curl is None else curl
    for (x, y), rr, turn in (((0.36, 0.60), 0.105, 0.0), ((0.60, 0.46), 0.095, 140.0), ((0.63, 0.74), 0.105, 250.0)):
        pts = []
        for k in range(10):
            t = k / 9.0
            a = math.radians(turn + 400.0 * t)
            pts.append((x + math.cos(a) * rr * (1.0 - 0.72 * t), y + math.sin(a) * rr * (1.0 - 0.72 * t)))
        ic.flat(ic.path(pts, 0.034) & body, col)
    leaf_on(ic, (0.50, 0.24))


def steam(ic, x, y, h=0.22):
    for dx in (-0.09, 0.09):
        ic.flat(ic.path([(x + dx, y), (x + dx - 0.035, y - h * 0.33), (x + dx + 0.035, y - h * 0.66), (x + dx, y - h)], 0.04), hx("eef2f8"))


def bowl(ic, soup, wood=WOOD, y=0.52, hot=True):
    """A bowl of something seen from a little above: the rim's oval, what's in it, the bowl under it."""
    ic.part(ic.poly([(0.06, y), (0.94, y), (0.80, 0.86), (0.66, 0.94), (0.34, 0.94), (0.20, 0.86)]), wood, shadow=0.08)
    ic.part(ic.poly(oval((0.50, y), 0.45, 0.17, 24)), wood, shadow=0.03)
    ic.part(ic.poly(oval((0.50, y + 0.01), 0.37, 0.115, 24)), soup, shadow=0.03)
    if hot:
        steam(ic, 0.50, y - 0.20)


def bits(ic, pts, y=0.53):
    """Things floating in a bowl: (x, dy, radius, colour hex)."""
    for x, dy, r, col in pts:
        ic.flat(ic.circle((x, y + dy), r), hx(col))


# ----------------------------------------------------------------------------------------------------------------
# Coin and treasure
# ----------------------------------------------------------------------------------------------------------------
def gold(ic):
    # a stack of coins, one stood against it showing its face
    for y in (0.78, 0.65, 0.52):
        ic.part(ic.poly(oval((0.36, y + 0.07), 0.27, 0.10, 20)) | ic.poly([(0.09, y), (0.63, y), (0.63, y + 0.07), (0.09, y + 0.07)]), GOLD, metal=True, shadow=0.03)
        ic.part(ic.poly(oval((0.36, y), 0.27, 0.10, 20)), GOLD, metal=True, shadow=0.02)
    ic.part(ic.circle((0.68, 0.66), 0.25), GOLD, metal=True, shadow=0.06)
    ic.flat(ic.circle((0.68, 0.66), 0.17) & ~ic.circle((0.68, 0.66), 0.125), GOLD[1])
    ic.flat(ic.star((0.68, 0.66), 0.09, 4, 0.4, 0.0), GOLD[1])
    ic.flat(ic.star((0.84, 0.24), 0.11, 4, 0.22, 0.0), hx("fff6c4"))


def treasure(ic):
    # a cut gem: the table, the crown round it, the point under
    gem = ic.poly([(0.30, 0.16), (0.70, 0.16), (0.94, 0.42), (0.50, 0.94), (0.06, 0.42)])
    ic.part(gem, CYAN, shadow=0.0)
    ic.flat(ic.poly([(0.30, 0.16), (0.36, 0.42), (0.06, 0.42)]), CYAN[2])
    ic.flat(ic.poly([(0.30, 0.16), (0.70, 0.16), (0.64, 0.42), (0.36, 0.42)]), CYAN[3])
    ic.flat(ic.poly([(0.70, 0.16), (0.94, 0.42), (0.64, 0.42)]), CYAN[1])
    ic.flat(ic.poly([(0.06, 0.42), (0.36, 0.42), (0.50, 0.94)]), CYAN[2])
    ic.flat(ic.poly([(0.36, 0.42), (0.64, 0.42), (0.50, 0.94)]), CYAN[3])
    ic.flat(ic.poly([(0.64, 0.42), (0.94, 0.42), (0.50, 0.94)]), CYAN[1])
    ic.flat(ic.capsule((0.08, 0.42), (0.92, 0.42), 0.03), CYAN[0])
    ic.flat(ic.poly([(0.38, 0.21), (0.52, 0.21), (0.46, 0.34), (0.40, 0.34)]), CYAN[4])
    ic.flat(ic.star((0.82, 0.18), 0.10, 4, 0.22, 0.0), hx("ffffff"))


def pearl(ic):
    # a pearl on the half of its shell
    ic.part(ic.poly([(0.04, 0.60), (0.20, 0.86), (0.50, 0.96), (0.80, 0.86), (0.96, 0.60), (0.78, 0.70), (0.50, 0.74), (0.22, 0.70)]), SHELL, shadow=0.05)
    ball(ic, (0.50, 0.46), 0.30, WHITE, shadow=0.09)
    ic.flat(ic.path(arc((0.50, 0.46), 0.22, 20.0, 110.0), 0.035), SHELL[2])


# ----------------------------------------------------------------------------------------------------------------
# Drink
# ----------------------------------------------------------------------------------------------------------------
def rum(ic):
    # a squat brown bottle, corked, its label
    ic.part(ic.poly([(0.26, 0.40), (0.38, 0.30), (0.62, 0.30), (0.74, 0.40), (0.74, 0.90), (0.68, 0.96), (0.32, 0.96), (0.26, 0.90)]), AMBER, shadow=0.08)
    ic.part(ic.poly([(0.41, 0.12), (0.59, 0.12), (0.59, 0.32), (0.41, 0.32)]), AMBER, shadow=0.04)
    ic.part(ic.poly([(0.38, 0.10), (0.62, 0.10), (0.62, 0.17), (0.38, 0.17)]), AMBER, shadow=0.02)
    ic.part(ic.poly([(0.43, 0.01), (0.57, 0.01), (0.56, 0.11), (0.44, 0.11)]), DUST, shadow=0.02)
    ic.part(ic.poly([(0.26, 0.54), (0.74, 0.54), (0.74, 0.80), (0.26, 0.80)]), CREAM, shadow=0.03)
    ic.flat(ic.poly([(0.36, 0.62), (0.64, 0.62), (0.64, 0.72), (0.36, 0.72)]), hx("c83a2e"))
    ic.flat(ic.capsule((0.33, 0.40), (0.33, 0.48), 0.035), AMBER[4])


def tonic(ic):
    # a round flask, the tonic in it, corked
    ic.part(ic.circle((0.50, 0.62), 0.34), WHITE, shadow=0.0)
    ic.part(ic.circle((0.50, 0.62), 0.34) & ic.poly([(0.0, 0.52), (1.0, 0.52), (1.0, 1.0), (0.0, 1.0)]), TEAL, shadow=0.09)
    ic.flat(ic.poly(oval((0.50, 0.52), 0.325, 0.05, 20)), TEAL[3])
    ic.part(ic.poly([(0.41, 0.14), (0.59, 0.14), (0.59, 0.33), (0.41, 0.33)]), WHITE, shadow=0.03)
    ic.part(ic.poly([(0.37, 0.12), (0.63, 0.12), (0.63, 0.19), (0.37, 0.19)]), WHITE, shadow=0.02)
    ic.part(ic.poly([(0.43, 0.02), (0.57, 0.02), (0.56, 0.13), (0.44, 0.13)]), DUST, shadow=0.02)
    ic.flat(ic.poly(oval((0.36, 0.42), 0.07, 0.045, 12)), hx("ffffff"))
    for x, y, r in ((0.42, 0.74, 0.035), (0.60, 0.66, 0.028), (0.56, 0.82, 0.022)):
        ic.flat(ic.circle((x, y), r), TEAL[4])


# ----------------------------------------------------------------------------------------------------------------
# Materials
# ----------------------------------------------------------------------------------------------------------------
def timber(ic):
    # Ship's Timber: "salvaged planks and a spar": three planks, roped
    for x, y in ((0.10, 0.30), (0.20, 0.46), (0.30, 0.62)):
        ic.part(ic.poly([(x + 0.08, y + 0.14), (x + 0.64, y - 0.08), (x + 0.63, y + 0.04), (x + 0.07, y + 0.26)]), WOOD, shadow=0.05)
        ic.part(ic.poly([(x, y), (x + 0.08, y + 0.14), (x + 0.07, y + 0.26), (x - 0.01, y + 0.12)]), DUST, shadow=0.02)
        top = ic.poly([(x, y), (x + 0.56, y - 0.22), (x + 0.64, y - 0.08), (x + 0.08, y + 0.14)])
        ic.part(top, WOOD, shadow=0.0)
        ic.flat(top, WOOD[3])
        ic.flat(ic.capsule((x + 0.12, y + 0.02), (x + 0.50, y - 0.13), 0.02) & top, WOOD[2])
    for t in (0.30, 0.72):
        a = (0.10 + 0.56 * t, 0.30 - 0.22 * t - 0.03)
        b = (0.30 + 0.56 * t + 0.07, 0.62 - 0.22 * t + 0.24)
        ic.part(ic.capsule(a, b, 0.07), CREAM, shadow=0.03)


def iron(ic):
    # Scrap Iron: "bands, knees and bolts pulled from a wreck": a knee, a length of band, a bolt across them
    ic.part(ic.path(arc((0.60, 0.70), 0.30, 185.0, 372.0, 0.80), 0.10), FUR, metal=True, shadow=0.03)
    knee = ic.poly([(0.10, 0.12), (0.34, 0.12), (0.34, 0.62), (0.80, 0.62), (0.80, 0.86), (0.10, 0.86)])
    ic.part(knee, FUR, metal=True, shadow=0.07)
    for x, y in ((0.22, 0.26), (0.22, 0.50), (0.22, 0.74), (0.45, 0.74), (0.67, 0.74)):
        ic.flat(ic.circle((x, y), 0.035), FUR[0])
    for x, y in ((0.30, 0.38), (0.56, 0.82), (0.14, 0.64)):
        ic.flat(ic.circle((x, y), 0.03), COPPER[1])
    ic.part(ic.capsule((0.46, 0.52), (0.82, 0.18), 0.085), SMOKE, metal=True, shadow=0.03)
    ic.part(ic.poly(oval((0.85, 0.15), 0.12, 0.12, 6)), SMOKE, metal=True, shadow=0.04)


def copper(ic):
    # a lump of ore, the copper showing in it
    ic.part(ic.poly([(0.10, 0.74), (0.14, 0.44), (0.34, 0.22), (0.62, 0.16), (0.86, 0.36), (0.92, 0.70), (0.72, 0.90), (0.30, 0.92)]), STONE, shadow=0.08)
    for pts in ([(0.24, 0.46), (0.40, 0.32), (0.54, 0.42), (0.46, 0.60), (0.28, 0.62)], [(0.60, 0.30), (0.76, 0.40), (0.72, 0.54), (0.58, 0.48)],
            [(0.52, 0.68), (0.74, 0.64), (0.80, 0.78), (0.62, 0.86), (0.48, 0.80)], [(0.20, 0.72), (0.34, 0.70), (0.36, 0.82), (0.24, 0.84)]):
        ic.part(ic.poly(pts), COPPER, metal=True, shadow=0.04)


def canvas(ic):
    # a bolt of sailcloth, a corner of it loose
    ic.part(ic.poly([(0.20, 0.34), (0.74, 0.20), (0.90, 0.36), (0.90, 0.62), (0.36, 0.80), (0.20, 0.60)]), CREAM, shadow=0.07)
    ic.part(ic.poly(oval((0.26, 0.48), 0.13, 0.19, 18)), CREAM, shadow=0.03)
    ic.flat(ic.path(arc((0.26, 0.48), 0.07, 0.0, 300.0, 1.4), 0.03), CREAM[1])
    for t in (0.36, 0.66):
        ic.flat(ic.poly([(0.20 + 0.54 * t, 0.34 - 0.14 * t), (0.26 + 0.54 * t, 0.325 - 0.14 * t), (0.42 + 0.54 * t, 0.78 - 0.18 * t), (0.36 + 0.54 * t, 0.80 - 0.18 * t)]), hx("3a70c2"))
    ic.part(ic.poly([(0.36, 0.80), (0.90, 0.62), (0.96, 0.84), (0.56, 0.96)]), CREAM, shadow=0.05)


# ----------------------------------------------------------------------------------------------------------------
# Driftfruit
# ----------------------------------------------------------------------------------------------------------------
def ember_fruit(ic):
    driftfruit(ic, EMBER_F)


def storm_fruit(ic):
    driftfruit(ic, STORM_F, hx("fff280"))


# ----------------------------------------------------------------------------------------------------------------
# Ingredients
# ----------------------------------------------------------------------------------------------------------------
def tangerine(ic):
    ball(ic, (0.50, 0.58), 0.37, ORANGE, shadow=0.11)
    for x, y in ((0.40, 0.70), (0.56, 0.62), (0.62, 0.80), (0.34, 0.52)):
        ic.flat(ic.circle((x, y), 0.02), ORANGE[1])
    leaf_on(ic, (0.50, 0.24), -20.0, 0.17)


def coconut(ic):
    # one whole, one split to the white
    ball(ic, (0.38, 0.42), 0.30, WOOD, shadow=0.09, shine=False)
    for x, y in ((0.30, 0.36), (0.42, 0.30), (0.40, 0.44)):
        ic.flat(ic.circle((x, y), 0.035), WOOD[0])
    ic.part(ic.poly(oval((0.62, 0.68), 0.32, 0.26, 20)), WOOD, shadow=0.07)
    ic.part(ic.poly(oval((0.62, 0.64), 0.27, 0.20, 20)), WHITE, shadow=0.04)
    ic.flat(ic.poly(oval((0.62, 0.66), 0.17, 0.11, 16)), hx("c8d4e4"))


def egg(ic):
    ic.part(ic.poly(oval((0.66, 0.60), 0.21, 0.27, 20)), CREAM, shadow=0.07)
    ic.part(ic.poly(oval((0.38, 0.52), 0.26, 0.34, 20)), CREAM, shadow=0.09)
    ic.flat(ic.poly(oval((0.30, 0.36), 0.07, 0.10, 12)), hx("ffffff"))
    for x, y in ((0.44, 0.60), (0.34, 0.70), (0.50, 0.44)):
        ic.flat(ic.circle((x, y), 0.02), CREAM[1])


def fish(ic):
    # Grilled Snapper: "Marlo's catch, charred on a stick"
    ic.part(ic.capsule((0.03, 0.97), (0.97, 0.07), 0.055), WOOD, shadow=0.02)
    ic.part(ic.poly([(0.70, 0.36), (0.84, 0.04), (0.84, 0.26), (1.00, 0.36)]), BROTH, shadow=0.04)
    body = ic.lens((0.10, 0.86), (0.80, 0.24), 0.46)
    ic.part(body, BROTH, shadow=0.08)
    for t in (0.34, 0.50, 0.66):
        x, y = 0.10 + 0.70 * t, 0.86 - 0.62 * t
        ic.flat(ic.capsule((x - 0.07, y - 0.10), (x + 0.09, y + 0.10), 0.035) & body, BROTH[0])
    ic.flat(ic.circle((0.25, 0.68), 0.04), hx("fff6e0"))
    ic.flat(ic.circle((0.25, 0.68), 0.02), INK)


def biscuit(ic):
    # ship's biscuit: two squares of hardtack
    ic.part(ic.poly([(0.30, 0.10), (0.90, 0.22), (0.80, 0.74), (0.20, 0.62)]), DUST, shadow=0.06)
    ic.part(ic.poly([(0.08, 0.36), (0.68, 0.30), (0.74, 0.88), (0.14, 0.94)]), CREAM, shadow=0.08)
    for x, y in ((0.26, 0.50), (0.52, 0.47), (0.30, 0.76), (0.56, 0.73), (0.41, 0.62)):
        ic.flat(ic.circle((x, y), 0.03), CREAM[0])


# ----------------------------------------------------------------------------------------------------------------
# Dishes
# ----------------------------------------------------------------------------------------------------------------
def stew(ic):
    bowl(ic, BROTH)
    bits(ic, ((0.34, 0.00, 0.05, "8a3a1a"), (0.52, -0.04, 0.045, "f6921e"), (0.66, 0.03, 0.05, "8a3a1a"), (0.46, 0.06, 0.035, "86cc48")))


def fish_stew(ic):
    bowl(ic, CREAM, wood=ramp("0c2a52", "1858a0", "2e96d8", "86d8f4", "e8fbff"))
    ic.part(ic.poly([(0.52, 0.52), (0.70, 0.26), (0.74, 0.40), (0.88, 0.34), (0.72, 0.56)]), WATER, shadow=0.03)
    bits(ic, ((0.30, 0.00, 0.04, "86cc48"), (0.42, 0.06, 0.035, "f6921e"), (0.44, -0.05, 0.03, "86cc48")))


ITEMS = [("gold", gold), ("treasure", treasure), ("pearl", pearl), ("rum", rum), ("tonic", tonic), ("timber", timber), ("iron", iron),
    ("copper", copper), ("canvas", canvas), ("ember_fruit", ember_fruit), ("storm_fruit", storm_fruit), ("tangerine", tangerine),
    ("coconut", coconut), ("egg", egg), ("fish", fish), ("biscuit", biscuit), ("stew", stew), ("fish_stew", fish_stew)]


def render(fn, n):
    ic = Icon(n)
    fn(ic)
    return ic.finish()


def old_icon(name):
    """Today's 24 px drawing (from git's HEAD if the file has been redrawn since)."""
    p = os.path.join(ICONS, name + ".png")
    im = Image.open(p).convert("RGBA") if os.path.exists(p) else None
    return im if im is not None and im.size == (24, 24) else None


def review():
    """Today's beside the new, as a 1080p screen shows them (the 960x540 canvas at 2x): an inventory slot is 42 px
    (84 on screen). Today: 24 px at 1.5x. New: 32 px at 1x, 36 px at 1x. Then 16 px (toasts, lists) and 48 px (cards)."""
    bg, text, fill, rim = (26, 28, 41, 255), (205, 210, 224, 255), (14, 40, 46, 255), (190, 150, 70, 255)
    per = 9
    cell = 84 + 8
    rows = (len(ITEMS) + per - 1) // per
    bands = (("today: 24 px shown at 1.5x", None), ("new, 32 px (the skill icons' size)", 32), ("new, 36 px (fills the slot as today's does)", 36))
    sheet = Image.new("RGBA", (16 + per * cell + 16 + 160, 8 + len(bands) * (20 + rows * cell) + 8), bg)
    d = ImageDraw.Draw(sheet)
    y = 8
    for label, n in bands:
        d.text((16, y + 2), label, fill=text)
        y += 20
        for i, (name, fn) in enumerate(ITEMS):
            x0, y0 = 16 + (i % per) * cell, y + (i // per) * cell
            d.rectangle([x0, y0, x0 + 83, y0 + 83], fill=fill, outline=rim)
            d.rectangle([x0 + 1, y0 + 1, x0 + 82, y0 + 82], outline=rim)
            if n is None:
                im = old_icon(name)
                im = up(im, 3) if im is not None else None
            else:
                im = up(render(fn, n), 2)
            if im is not None:
                sheet.alpha_composite(im, (x0 + (84 - im.width) // 2, y0 + (84 - im.height) // 2))
        y += rows * cell
    # the small and the large rendering, beside the bands
    x = 16 + per * cell + 16
    d.text((x, 10), "16 px and 48 px", fill=text)
    for i, (name, fn) in enumerate(ITEMS[:6]):
        sheet.alpha_composite(up(render(fn, 16), 2), (x, 30 + i * 100))
        sheet.alpha_composite(up(render(fn, 48), 2), (x + 44, 30 + i * 100))
    os.makedirs(REVIEW, exist_ok=True)
    out = os.path.join(REVIEW, "items_new.png")
    sheet.save(out)
    print("  wrote", os.path.relpath(out, ROOT))


def main():
    review()


if __name__ == "__main__":
    main()
