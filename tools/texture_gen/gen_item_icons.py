"""Item icons, ink and cel (2026-11-11): the drawn items (food, ingredients, materials, Driftfruit, coin and
treasure) in the skill icons' style: flat colour, one hard shadow along the lower right, a light edge up and left,
black ink round every part. No plate and no frame: one object on a transparent ground, filling most of the tile.

Each is a description of parts in 0..1 coordinates (gen_skill_icons.Icon), so it renders at any size.

    py tools/texture_gen/gen_item_icons.py            # review sheets -> tools/dev/out/iconreview/items_new.png (old beside
                                                      # new in slots), items_new_sizes.png (48 and 16 px)
    py tools/texture_gen/gen_item_icons.py --write    # also assets/textures/icons/<id>.png (32 px), <id>_16.png, <id>_48.png
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_skill_icons import (BONE, CLOTH, CYAN, DUST, FUR, GOLD, ICONS, INK, IRON, LEAF, LEATHER, MEAT, REVIEW, ROOT, SHADE, SILVER, SMOKE,  # noqa: E402
    SNAKE, STEEL, STONE, TEAL, WATER, WHITE, WOOD, Icon, arc, axe, cutlass, hx, katana, oval, pistol, ramp, up)

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


TUSK = ramp("6a5420", "a8883a", "e0c468", "f6e6a0", "fffbe0")
SANDP = ramp("5a2c0a", "a85e18", "e09a30", "f8cc70", "fff0c0")
SUN = ramp("7a4a06", "c8881a", "f8c030", "ffe478", "fff8c8")
RED = ramp("5a0c10", "a81c1c", "e03a2a", "ff7a5a", "ffc8b0")
BERRY = ramp("16205a", "2c44a8", "4a74e0", "9cc0ff", "ffffff")
DATE = ramp("1e0c06", "40200e", "6a3a18", "9a6230", "d09a60")
URCHIN = ramp("1e0c3a", "3c1c6a", "6a34a0", "a070d8", "dcc0ff")
GHOST = ramp("3a6a70", "8ac8c8", "d8f6f0", "f4fffb", "ffffff")
GREEN = ramp("143a12", "2a7a22", "4cb03a", "96e060", "e0fab0")
CLAY = ramp("4a160c", "8a2e18", "c0502a", "e88a58", "ffc8a0")
POT = ramp("0c0a12", "1e1c28", "34323e", "56546a", "8886a0")
CERAM = ramp("0c2a52", "1858a0", "2e96d8", "86d8f4", "e8fbff")
JADE = ramp("0f3a2a", "1c6a4a", "3a9a70", "86d0a8", "d8f8e4")
CRUST = ramp("5a300c", "a0621c", "d89a3a", "f4c870", "ffeab8")
PINKF = ramp("7a2a30", "c85a5a", "f49a8c", "ffd0c0", "ffffff")
BEAR_F = ramp("3a2416", "5e3e28", "7a5236", "a87e58", "d8b890")
BUBBLE_F = ramp("3a7a9a", "6ab8d8", "9ce0f8", "d8f6ff", "ffffff")
CLOCK_F = ramp("6a4a18", "a07828", "d0a038", "f8d888", "fff6d0")
ECHO_F = ramp("1e4a7a", "3a7ab8", "6aaee0", "d0ecff", "ffffff")
GUST_F = ramp("3a7a6a", "5eaa94", "8ed0b8", "e0fff4", "ffffff")
IRON_F = ramp("4a505a", "70767f", "9aa0ab", "d8dee8", "ffffff")
VINE_F = ramp("1e5a18", "357a26", "4a9a36", "7ac85a", "c8f0a0")
WOLF_F = ramp("3a3430", "5e5850", "8a8478", "b0aa9c", "dcd8cc")


# ----------------------------------------------------------------------------------------------------------------
# More shared pieces
# ----------------------------------------------------------------------------------------------------------------
def plate(ic, mat=WHITE, y=0.68, rx=0.47, ry=0.25):
    ic.part(ic.poly(oval((0.50, y), rx, ry, 24)), mat, shadow=0.05)
    ic.flat(ic.poly(oval((0.50, y - 0.01), rx * 0.74, ry * 0.66, 24)), mat[1] * 0.35 + mat[2] * 0.65)


def sack(ic, mat=CREAM, tied=True):
    ic.part(ic.poly([(0.22, 0.36), (0.78, 0.36), (0.92, 0.80), (0.78, 0.96), (0.22, 0.96), (0.08, 0.80)]), mat, shadow=0.09)
    if tied:
        ic.part(ic.poly([(0.36, 0.36), (0.24, 0.08), (0.50, 0.18), (0.76, 0.08), (0.64, 0.36)]), mat, shadow=0.04)
        ic.part(ic.capsule((0.36, 0.36), (0.64, 0.36), 0.075), WOOD, shadow=0.03)


def skewer(ic, a, b, chunks, stick=WOOD, w=0.05):
    """A stick from a to b with chunks on it: (where along it, radius, ramp)."""
    ic.part(ic.capsule(a, b, w), stick, metal=(stick is STEEL), shadow=0.02)
    for t, r, mat in chunks:
        ic.part(ic.circle((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), r), mat, shadow=r * 0.4)


def spark(ic, c, r, col="fff6c4"):
    ic.flat(ic.star(c, r, 4, 0.24, 0.0), hx(col))


# ----------------------------------------------------------------------------------------------------------------
# Weapons (the plain ones' pictures; a weapon in a slot shows its own model)
# ----------------------------------------------------------------------------------------------------------------
def axe_item(ic):
    axe(ic, (0.16, 0.92), -52.0, 0.86)


def cutlass_item(ic):
    cutlass(ic, (0.14, 0.88), (0.88, 0.10), bend=0.08, w=0.14)


def katana_item(ic):
    katana(ic, (0.06, 0.94), (0.92, 0.06), bend=0.13, w=0.075)


def pistol_item(ic):
    pistol(ic, (0.14, 0.42), 6.0, 0.80)


# ----------------------------------------------------------------------------------------------------------------
# The other Driftfruit
# ----------------------------------------------------------------------------------------------------------------
def bear_fruit(ic):
    driftfruit(ic, BEAR_F)


def bubble_fruit(ic):
    driftfruit(ic, BUBBLE_F, hx("e88ad0"))


def clockwork_fruit(ic):
    driftfruit(ic, CLOCK_F)


def echo_fruit(ic):
    driftfruit(ic, ECHO_F)


def gust_fruit(ic):
    driftfruit(ic, GUST_F)


def iron_fruit(ic):
    driftfruit(ic, IRON_F)


def vine_fruit(ic):
    driftfruit(ic, VINE_F)


def wolf_fruit(ic):
    driftfruit(ic, WOLF_F)


# ----------------------------------------------------------------------------------------------------------------
# Beast parts
# ----------------------------------------------------------------------------------------------------------------
def bear_claw(ic):
    # Bear King Claw: "a hooked black claw torn from the snow's king"
    ic.part(ic.path(arc((0.40, 0.48), 0.40, -66.0, 118.0, 1.0, 14), 0.28, 0.03), IRON, metal=True, shadow=0.05)
    ic.part(ic.circle((0.56, 0.14), 0.15) | ic.circle((0.74, 0.20), 0.12) | ic.circle((0.40, 0.16), 0.12), WHITE, shadow=0.04)


def tusk(ic):
    # Boar Tusk: "a curved yellow tusk"
    ic.part(ic.path(arc((0.66, 0.40), 0.46, 212.0, 78.0, 1.0, 14), 0.21, 0.03), TUSK, shadow=0.05)
    ic.part(ic.circle((0.27, 0.16), 0.125), AMBER, shadow=0.04)


def ivory(ic):
    # Silverback Ivory: "a tusk snapped from the jungle's king, thick as a forearm"
    ic.part(ic.path([(0.16, 0.84), (0.30, 0.64), (0.50, 0.44), (0.72, 0.26), (0.94, 0.10)], 0.32, 0.04), CREAM, shadow=0.08)
    ic.part(ic.poly([(0.02, 0.82), (0.10, 0.66), (0.18, 0.76), (0.26, 0.70), (0.30, 0.92), (0.16, 0.98), (0.12, 0.88)]), CREAM, shadow=0.03)
    for t in ((0.30, 0.60), (0.40, 0.52)):
        ic.flat(ic.capsule((t[0] - 0.07, t[1] - 0.07), (t[0] + 0.08, t[1] + 0.08), 0.025), CREAM[1])


def knuckle(ic):
    # Silverback Knuckle: "a knuckle bone callused hard as stone"
    ic.part(ic.capsule((0.32, 0.68), (0.68, 0.32), 0.25), BONE, shadow=0.07)
    for c in ((0.18, 0.64), (0.34, 0.84), (0.66, 0.16), (0.84, 0.34)):
        ic.part(ic.circle(c, 0.16), BONE, shadow=0.05)
    for x, y in ((0.20, 0.60), (0.36, 0.82), (0.82, 0.30), (0.64, 0.20)):
        ic.flat(ic.circle((x, y), 0.045), STONE[2])


def mandible(ic):
    # Sand King Mandible: "a saw-toothed mandible as long as a cutlass"
    c, r = (0.30, 0.32), 0.58
    pts = arc(c, r, -18.0, 96.0, 1.0, 14)
    for k in range(2, 13):
        p = pts[k]
        d = math.hypot(c[0] - p[0], c[1] - p[1])
        nx, ny = (c[0] - p[0]) / d, (c[1] - p[1]) / d
        ic.part(ic.poly([(p[0] - ny * 0.045, p[1] + nx * 0.045), (p[0] + nx * 0.17, p[1] + ny * 0.17), (p[0] + ny * 0.045, p[1] - nx * 0.045)]), CREAM, shadow=0.02)
    ic.part(ic.path(pts, 0.22, 0.05), SANDP, metal=True, shadow=0.05)
    ic.part(ic.circle(pts[0], 0.13), AMBER, shadow=0.04)


def bear_hide(ic):
    # Bear King Hide: "a patch of the great bear's white hide"
    pelt = ic.poly([(0.50, 0.06), (0.66, 0.20), (0.94, 0.12), (0.84, 0.40), (0.80, 0.60), (0.96, 0.88), (0.70, 0.80), (0.50, 0.94), (0.30, 0.80), (0.04, 0.88),
        (0.20, 0.60), (0.16, 0.40), (0.06, 0.12), (0.34, 0.20)])
    ic.part(pelt, WHITE, shadow=0.07)
    for x, y in ((0.36, 0.34), (0.56, 0.30), (0.46, 0.50), (0.66, 0.50), (0.34, 0.64), (0.56, 0.70)):
        ic.flat(ic.capsule((x, y), (x + 0.04, y + 0.09), 0.03) & pelt, WHITE[1])


def chitin_shard(ic):
    # Chitin Shard: "a piece of a big bug's shell, hard as horn"
    shard = ic.poly([(0.18, 0.12), (0.56, 0.05), (0.86, 0.28), (0.92, 0.62), (0.66, 0.95), (0.54, 0.66), (0.28, 0.76), (0.10, 0.46)])
    ic.part(shard, TEAL, metal=True, shadow=0.08)
    for r in (0.26, 0.42, 0.58):
        ic.flat(ic.path(arc((0.20, 0.14), r, 10.0, 70.0), 0.03) & shard, TEAL[1])


def sand_plate(ic):
    # Sand King Plate: "an armour plate off the great worm's back, amber and ridged"
    for y, rx in ((0.74, 0.44), (0.58, 0.42), (0.42, 0.37), (0.28, 0.28)):
        ic.part(ic.poly(oval((0.50, y), rx, 0.20, 20)), SANDP, metal=True, shadow=0.05)


def snakeskin(ic):
    # Snakeskin: "a whole patterned skin"
    strip = ic.poly([(0.30, 0.36), (0.96, 0.16), (0.88, 0.34), (0.98, 0.50), (0.36, 0.74)])
    ic.part(strip, SNAKE, shadow=0.05)
    for t in (0.30, 0.52, 0.74):
        x, y = 0.33 + 0.62 * t, 0.55 - 0.22 * t
        ic.flat(ic.poly([(x - 0.08, y), (x, y - 0.10), (x + 0.08, y), (x, y + 0.10)]) & strip, SNAKE[0])
        ic.flat(ic.circle((x, y), 0.025), hx("ffd23a"))
    ic.part(ic.circle((0.26, 0.58), 0.23), SNAKE, shadow=0.07)
    ic.flat(ic.path(arc((0.26, 0.58), 0.12, 0.0, 300.0), 0.03), SNAKE[0])


def plume(ic):
    # Bright Plume: "a jungle bird's tail feather, orange and blue"
    vane = ic.lens((0.20, 0.86), (0.92, 0.06), 0.44)
    ic.part(vane, ORANGE, shadow=0.06)
    ic.flat(vane & ic.circle((0.92, 0.06), 0.42), hx("3a70c2"))
    ic.flat(vane & ic.circle((0.92, 0.06), 0.24), hx("78b9ee"))
    for t in (0.30, 0.48, 0.66):
        x, y = 0.20 + 0.72 * t, 0.86 - 0.80 * t
        ic.flat(ic.capsule((x, y), (x - 0.02, y - 0.16), 0.02) & vane, ORANGE[1])
    ic.part(ic.capsule((0.06, 0.98), (0.84, 0.14), 0.04), CREAM, shadow=0.01)


# ----------------------------------------------------------------------------------------------------------------
# More materials
# ----------------------------------------------------------------------------------------------------------------
def copper_sheet(ic):
    # Copper Sheet: "bright copper sheathing off a fine hull"
    ic.part(ic.poly([(0.14, 0.58), (0.62, 0.30), (0.94, 0.56), (0.46, 0.90)]), COPPER, metal=True, shadow=0.05)
    top = ic.poly([(0.06, 0.42), (0.56, 0.12), (0.90, 0.40), (0.40, 0.74)])
    ic.part(top, COPPER, metal=True, shadow=0.06)
    ic.flat(ic.lens((0.22, 0.42), (0.56, 0.22), 0.06) & top, COPPER[4])
    for x, y in ((0.14, 0.43), (0.55, 0.19), (0.82, 0.41), (0.41, 0.67)):
        ic.flat(ic.circle((x, y), 0.028), COPPER[0])
    ic.part(ic.poly([(0.40, 0.74), (0.52, 0.66), (0.58, 0.78), (0.48, 0.86)]), COPPER, metal=True, shadow=0.03)


# ----------------------------------------------------------------------------------------------------------------
# More ingredients
# ----------------------------------------------------------------------------------------------------------------
def rice(ic):
    # Sack of Rice: "dry, white, and enough for a crew": the sack open, the rice heaped in it
    sack(ic, tied=False)
    ic.part(ic.poly(oval((0.50, 0.36), 0.30, 0.12, 20)), CREAM, shadow=0.03)
    ic.part(ic.poly([(0.24, 0.36), (0.36, 0.20), (0.50, 0.14), (0.64, 0.20), (0.76, 0.36), (0.50, 0.44)]), WHITE, shadow=0.04)
    for x, y in ((0.40, 0.28), (0.54, 0.24), (0.60, 0.33), (0.46, 0.36)):
        ic.flat(ic.capsule((x, y), (x + 0.04, y + 0.015), 0.025), WHITE[1])
    for x, y in ((0.84, 0.94), (0.94, 0.88)):
        ic.part(ic.capsule((x, y), (x + 0.03, y - 0.02), 0.045), WHITE, shadow=0.0)


def flour(ic):
    # Bag of Flour: "milled wheat": the bag tied, the ear of wheat on it
    sack(ic, mat=WHITE)
    for k in range(4):
        y = 0.56 + 0.085 * k
        for sgn in (-1.0, 1.0):
            ic.flat(ic.lens((0.50, y + 0.05), (0.50 + sgn * 0.10, y - 0.03), 0.045), CRUST[1])
    ic.flat(ic.capsule((0.50, 0.50), (0.50, 0.90), 0.025), CRUST[1])


def salt(ic):
    # Sea Salt: "boiled out of the sea in a pan"
    bowl(ic, WHITE, hot=False, y=0.60)
    ic.part(ic.poly([(0.22, 0.60), (0.36, 0.38), (0.50, 0.30), (0.64, 0.38), (0.78, 0.60), (0.50, 0.68)]), WHITE, shadow=0.05)
    spark(ic, (0.78, 0.26), 0.09, "ffffff")
    spark(ic, (0.24, 0.30), 0.06, "ffffff")


def ember_salt(ic):
    # Ember Salt: "red-black salt scraped off cooling lava. It crackles on the tongue."
    bowl(ic, POT, wood=POT, hot=False, y=0.60)
    ic.part(ic.poly([(0.22, 0.60), (0.36, 0.38), (0.50, 0.30), (0.64, 0.38), (0.78, 0.60), (0.50, 0.68)]), RED, shadow=0.05)
    for x, y in ((0.40, 0.50), (0.56, 0.44), (0.62, 0.56), (0.48, 0.38)):
        ic.flat(ic.circle((x, y), 0.03), POT[0])
    spark(ic, (0.78, 0.24), 0.10, "ffc93a")
    spark(ic, (0.24, 0.28), 0.07, "ffc93a")


def pepper(ic):
    # Peppercorns: "black and hot"
    for x, y in ((0.26, 0.76), (0.50, 0.80), (0.74, 0.76), (0.38, 0.56), (0.62, 0.56), (0.50, 0.36)):
        ball(ic, (x, y), 0.145, POT, shadow=0.05)


def mushroom(ic):
    # Wood Mushrooms: "brown caps from under the trees"
    for (x, y), s in (((0.66, 0.52), 0.78), ((0.36, 0.44), 1.0)):
        ic.part(ic.poly([(x - 0.07 * s, y), (x + 0.07 * s, y), (x + 0.10 * s, y + 0.46 * s), (x - 0.10 * s, y + 0.46 * s)]), CREAM, shadow=0.04)
        ic.part(ic.circle((x, y), 0.30 * s) & ~below_y(ic, y + 0.03 * s), AMBER, shadow=0.07)
        for dx, dy in ((-0.12, -0.12), (0.08, -0.17), (0.14, -0.05)):
            ic.flat(ic.circle((x + dx * s, y + dy * s), 0.035 * s), AMBER[3])


def seaweed(ic):
    # Kelp: "green ribbons from the shallows"
    for x, lean, h in ((0.26, -0.06, 0.74), (0.50, 0.04, 0.86), (0.74, -0.04, 0.70)):
        pts = [(x, 0.96), (x + lean + 0.07, 0.96 - h * 0.33), (x + lean - 0.07, 0.96 - h * 0.66), (x + lean * 2, 0.96 - h)]
        ic.part(ic.path(pts, 0.17, 0.08), GREEN, shadow=0.04)
        ic.flat(ic.path(pts, 0.03, 0.02), GREEN[0])


def oyster(ic):
    # Oyster: "prised off a reef rock"
    ic.part(ic.poly([(0.10, 0.44), (0.30, 0.14), (0.62, 0.08), (0.90, 0.26), (0.94, 0.50), (0.50, 0.56)]), STONE, shadow=0.05)
    ic.flat(ic.poly([(0.20, 0.42), (0.34, 0.22), (0.60, 0.16), (0.82, 0.30), (0.84, 0.46), (0.50, 0.50)]), SHELL[3])
    ic.part(ic.poly([(0.06, 0.60), (0.20, 0.50), (0.50, 0.46), (0.80, 0.50), (0.96, 0.62), (0.84, 0.86), (0.50, 0.96), (0.18, 0.86)]), STONE, shadow=0.07)
    ic.part(ic.poly(oval((0.50, 0.68), 0.30, 0.15, 18)), CREAM, shadow=0.04)
    ic.flat(ic.poly(oval((0.44, 0.65), 0.10, 0.05, 12)), hx("ffffff"))


def sea_urchin(ic):
    # Sea Urchin: "spines outside, sweet roe inside"
    ic.part(ic.star((0.50, 0.54), 0.47, 13, 0.55, 0.2), URCHIN, shadow=0.03)
    ball(ic, (0.50, 0.54), 0.25, URCHIN, shadow=0.08)
    for x, y in ((0.44, 0.60), (0.58, 0.52), (0.52, 0.68)):
        ic.flat(ic.circle((x, y), 0.025), URCHIN[3])


def fire_chili(ic):
    # Fire Chili: "a wrinkled red pod from the jungle"
    pts = [(0.76, 0.22), (0.74, 0.44), (0.60, 0.64), (0.40, 0.78), (0.14, 0.86)]
    ic.part(ic.path(pts, 0.24, 0.05), RED, shadow=0.06)
    ic.flat(ic.path([(0.70, 0.30), (0.66, 0.46), (0.54, 0.60)], 0.035), RED[4])
    for x, y in ((0.58, 0.70), (0.44, 0.80)):
        ic.flat(ic.capsule((x, y), (x + 0.05, y - 0.06), 0.02), RED[0])
    ic.part(ic.poly([(0.64, 0.24), (0.76, 0.12), (0.90, 0.22), (0.86, 0.34)]), GREEN, shadow=0.03)
    ic.part(ic.capsule((0.80, 0.16), (0.90, 0.04), 0.055), GREEN, shadow=0.02)


def frost_berries(ic):
    # Frost Berries: "blue berries picked under the snow"
    ic.part(ic.lens((0.50, 0.30), (0.90, 0.10), 0.20), GREEN, shadow=0.03)
    ic.part(ic.capsule((0.50, 0.32), (0.46, 0.14), 0.045), WOOD, shadow=0.02)
    for x, y in ((0.30, 0.48), (0.66, 0.50), (0.48, 0.60), (0.30, 0.76), (0.66, 0.78)):
        ball(ic, (x, y), 0.175, BERRY, shadow=0.06)
    spark(ic, (0.14, 0.24), 0.09, "ffffff")
    spark(ic, (0.88, 0.62), 0.06, "ffffff")


def desert_dates(ic):
    # Desert Dates: "sticky and dark, from the oasis palms"
    ic.part(ic.path([(0.50, 0.04), (0.50, 0.26), (0.30, 0.40)], 0.05) | ic.capsule((0.50, 0.26), (0.72, 0.40), 0.05), CRUST, shadow=0.02)
    for (x, y), tilt in (((0.26, 0.56), -0.06), ((0.50, 0.50), 0.0), ((0.74, 0.56), 0.06), ((0.38, 0.80), -0.03), ((0.64, 0.80), 0.03)):
        ic.part(ic.poly(oval((x, y), 0.125, 0.17, 14)), DATE, shadow=0.05)
        ic.flat(ic.capsule((x - 0.05 + tilt, y - 0.08), (x - 0.05 + tilt, y - 0.02), 0.03), DATE[4])


def black_truffle(ic):
    # Black Truffle: "dug from under the old oaks by a very proud pig"
    ic.part(ic.circle((0.36, 0.50), 0.28) | ic.circle((0.52, 0.38), 0.22) | ic.circle((0.48, 0.66), 0.22) | ic.circle((0.24, 0.66), 0.16), POT, shadow=0.08)
    for x, y in ((0.30, 0.40), (0.46, 0.34), (0.38, 0.58), (0.24, 0.68), (0.50, 0.70)):
        ic.flat(ic.circle((x, y), 0.03), POT[3])
    cut = ic.poly(oval((0.72, 0.68), 0.22, 0.24, 16))
    ic.part(cut, POT, shadow=0.04)
    ic.flat(ic.poly(oval((0.72, 0.68), 0.17, 0.19, 16)), DUST[3])
    for pts in ([(0.60, 0.62), (0.72, 0.68), (0.84, 0.60)], [(0.66, 0.80), (0.72, 0.68), (0.80, 0.80)], [(0.72, 0.52), (0.72, 0.68)]):
        ic.flat(ic.path(pts, 0.025) & cut, POT[1])


def ghost_lily(ic):
    # Ghost Lily: "a pale bloom from the fog marshes ... faintly glowing"
    ic.part(ic.path([(0.50, 0.60), (0.46, 0.80), (0.52, 0.98)], 0.06), GREEN, shadow=0.02)
    c = (0.50, 0.42)
    for k in range(6):
        a = math.radians(-90.0 + 60.0 * k)
        ic.part(ic.lens((c[0] + math.cos(a) * 0.06, c[1] + math.sin(a) * 0.06), (c[0] + math.cos(a) * 0.42, c[1] + math.sin(a) * 0.40), 0.24), GHOST, shadow=0.04)
    ic.part(ic.circle(c, 0.09), GOLD, shadow=0.03)
    spark(ic, (0.88, 0.14), 0.08, "ffffff")


def sea_grapes(ic):
    # Sea Grapes: "little green beads off the atoll's reef"
    ic.part(ic.path([(0.16, 0.90), (0.36, 0.62), (0.56, 0.40), (0.84, 0.12)], 0.055), GREEN, shadow=0.02)
    for x, y in ((0.22, 0.70), (0.36, 0.82), (0.30, 0.50), (0.50, 0.66), (0.46, 0.34), (0.66, 0.50), (0.62, 0.20), (0.82, 0.32)):
        ball(ic, (x, y), 0.105, GREEN, shadow=0.04)


def jungle_fruit(ic):
    # Sunfruit: "sweet and sticky - the monkeys know where they grow"
    body = ic.circle((0.50, 0.62), 0.34) | ic.poly([(0.26, 0.48), (0.50, 0.14), (0.74, 0.48)])
    ic.part(body, SUN, shadow=0.10)
    for k in range(7):
        a = math.radians(-90.0 + (k - 3) * 28.0)
        ic.flat(ic.lens((0.50 + math.cos(a) * 0.10, 0.62 + math.sin(a) * 0.10), (0.50 + math.cos(a) * 0.27, 0.62 + math.sin(a) * 0.27), 0.05) & body, SUN[1])
    ic.flat(ic.circle((0.50, 0.62), 0.07), SUN[1])
    leaf_on(ic, (0.50, 0.16), -15.0, 0.15)
    ic.part(ic.circle((0.80, 0.86), 0.05) | ic.poly([(0.76, 0.84), (0.80, 0.72), (0.84, 0.84)]), SUN, shadow=0.02)


# ----------------------------------------------------------------------------------------------------------------
# Cooked on its own
# ----------------------------------------------------------------------------------------------------------------
def boar_haunch(ic):
    # Boar Haunch: "a wild boar's haunch, roasted over the fire"
    ic.part(ic.capsule((0.62, 0.40), (0.88, 0.14), 0.10), CREAM, shadow=0.03)
    ic.part(ic.circle((0.86, 0.10), 0.075) | ic.circle((0.93, 0.18), 0.075), CREAM, shadow=0.03)
    meat = ic.circle((0.40, 0.62), 0.33) | ic.circle((0.56, 0.46), 0.20)
    ic.part(meat, MEAT, shadow=0.10)
    ic.flat(ic.poly(oval((0.30, 0.50), 0.10, 0.06, 12)), MEAT[4])
    for x, y in ((0.36, 0.70), (0.50, 0.64), (0.44, 0.82)):
        ic.flat(ic.capsule((x - 0.05, y - 0.04), (x + 0.05, y + 0.04), 0.03) & meat, MEAT[0])


def crab_meat(ic):
    # Crab Claw: "cracked and roasted in its shell"
    ic.part(ic.poly([(0.06, 0.86), (0.16, 0.62), (0.40, 0.56), (0.48, 0.76), (0.24, 0.94)]), RED, shadow=0.05)
    ic.part(ic.poly([(0.36, 0.60), (0.48, 0.30), (0.76, 0.10), (0.94, 0.16), (0.74, 0.34), (0.94, 0.44), (0.70, 0.52), (0.56, 0.78)]), RED, shadow=0.07)
    ic.part(ic.poly([(0.56, 0.74), (0.74, 0.56), (0.96, 0.60), (0.80, 0.80), (0.60, 0.86)]), RED, shadow=0.05)
    ic.flat(ic.poly([(0.84, 0.13), (0.94, 0.16), (0.86, 0.22)]) | ic.poly([(0.88, 0.60), (0.96, 0.60), (0.90, 0.68)]), hx("fff6e0"))
    ic.flat(ic.path([(0.50, 0.44), (0.56, 0.52), (0.52, 0.60)], 0.025), RED[0])


# ----------------------------------------------------------------------------------------------------------------
# More dishes
# ----------------------------------------------------------------------------------------------------------------
def peppered_boar(ic):
    # "Boar seared black with pepper"
    plate(ic)
    slab = ic.poly([(0.18, 0.56), (0.30, 0.36), (0.58, 0.30), (0.80, 0.42), (0.84, 0.62), (0.64, 0.76), (0.34, 0.76)])
    ic.part(slab, MEAT, shadow=0.08)
    ic.flat(ic.path([(0.22, 0.56), (0.32, 0.40), (0.56, 0.34)], 0.04) & slab, hx("ffe2c6"))
    for x, y in ((0.40, 0.50), (0.56, 0.46), (0.68, 0.56), (0.48, 0.64), (0.60, 0.66), (0.34, 0.62)):
        ic.flat(ic.circle((x, y), 0.03), POT[0])
    steam(ic, 0.52, 0.28, 0.20)


def porridge(ic):
    # Sailor's Porridge: "oats, hardtack and fruit, boiled thick"
    bowl(ic, CREAM)
    bits(ic, ((0.36, 0.00, 0.05, "f6921e"), (0.56, -0.03, 0.045, "e03a2a"), (0.64, 0.05, 0.04, "f6921e"), (0.46, 0.06, 0.03, "a8883a")))


def citrus_tart(ic):
    # "Sweet pastry and sharp fruit"
    ic.part(ic.poly(oval((0.50, 0.66), 0.46, 0.28, 24)), CRUST, shadow=0.07)
    ic.part(ic.poly(oval((0.50, 0.58), 0.46, 0.26, 24)), CRUST, shadow=0.03)
    ic.part(ic.poly(oval((0.50, 0.58), 0.37, 0.19, 24)), SUN, shadow=0.03)
    for x, y in ((0.34, 0.56), (0.56, 0.50), (0.60, 0.66)):
        ic.part(ic.poly(oval((x, y), 0.105, 0.065, 14)), ORANGE, shadow=0.02)
        ic.flat(ic.capsule((x - 0.07, y), (x + 0.07, y), 0.018) | ic.capsule((x, y - 0.04), (x, y + 0.04), 0.018), ORANGE[4])
    ic.part(ic.lens((0.40, 0.70), (0.52, 0.64), 0.07), GREEN, shadow=0.02)


def reef_salad(ic):
    # "Kelp, shellfish and salt"
    bowl(ic, GREEN, hot=False, y=0.56)
    for a, b in (((0.26, 0.54), (0.38, 0.26)), ((0.44, 0.56), (0.50, 0.20)), ((0.62, 0.56), (0.70, 0.28)), ((0.74, 0.54), (0.86, 0.38))):
        ic.part(ic.lens(a, b, 0.16), GREEN, shadow=0.03)
    ic.part(ic.poly([(0.30, 0.56), (0.36, 0.44), (0.48, 0.42), (0.56, 0.54), (0.44, 0.62)]), SHELL, shadow=0.03)
    ic.flat(ic.circle((0.66, 0.56), 0.035), hx("ffffff"))


def forest_curry(ic):
    # "Mushrooms and spice over rice"
    bowl(ic, BROTH, wood=JADE)
    ic.flat(ic.poly(oval((0.50, 0.53), 0.37, 0.115, 24)) & ~right_x(ic, 0.46), hx("ffffff"))
    for x, y in ((0.60, 0.50), (0.72, 0.55)):
        ic.part(ic.circle((x, y), 0.065) & ~below_y(ic, y + 0.01), AMBER, shadow=0.02)
    bits(ic, ((0.56, 0.06, 0.03, "96e060"),))


def island_skewers(ic):
    # "Meat and fruit on a stick, charred"
    skewer(ic, (0.06, 0.70), (0.90, 0.10), ((0.26, 0.105, MEAT), (0.46, 0.10, SUN), (0.66, 0.105, MEAT), (0.84, 0.09, GREEN)))
    skewer(ic, (0.14, 0.96), (0.96, 0.38), ((0.26, 0.105, ORANGE), (0.46, 0.105, MEAT), (0.66, 0.10, GREEN), (0.84, 0.095, MEAT)))


def dune_skewers(ic):
    # "Spiced meat and dates charred on iron"
    for dy in (0.0, 0.30):
        skewer(ic, (0.04, 0.30 + dy), (0.96, 0.20 + dy), ((0.26, 0.11, MEAT), (0.48, 0.10, DATE), (0.70, 0.11, MEAT)), stick=STEEL, w=0.045)
        ic.part(ring_o(ic, (0.07, 0.30 + dy), 0.075), STEEL, metal=True, shadow=0.02)
    for x, y in ((0.30, 0.80), (0.56, 0.84), (0.80, 0.78)):
        ic.flat(ic.circle((x, y), 0.025), RED[2])


def captains_feast(ic):
    # "A bit of everything, done properly"
    plate(ic, GOLD, y=0.72, rx=0.48, ry=0.24)
    ic.part(ic.capsule((0.62, 0.40), (0.84, 0.20), 0.08), CREAM, shadow=0.02)
    ic.part(ic.circle((0.85, 0.17), 0.065), CREAM, shadow=0.02)
    ic.part(ic.circle((0.48, 0.54), 0.25) | ic.circle((0.60, 0.44), 0.15), MEAT, shadow=0.08)
    ball(ic, (0.22, 0.68), 0.12, ORANGE, shadow=0.04)
    for x, y in ((0.70, 0.74), (0.80, 0.68), (0.76, 0.82)):
        ball(ic, (x, y), 0.07, GREEN, shadow=0.03, shine=False)
    ic.part(ic.lens((0.26, 0.86), (0.56, 0.80), 0.12), WATER, shadow=0.03)
    steam(ic, 0.36, 0.26, 0.20)


def jungle_pepperpot(ic):
    # "Meat and greens stewed black with fire chilies"
    bowl(ic, DATE, wood=POT)
    for a, b in (((0.32, 0.54), (0.46, 0.48)), ((0.56, 0.58), (0.70, 0.52))):
        ic.part(ic.path([a, b], 0.07, 0.03), RED, shadow=0.02)
    bits(ic, ((0.50, -0.03, 0.035, "96e060"), (0.40, 0.07, 0.03, "96e060")))


def reef_ceviche(ic):
    # Reef-Fruit Ceviche: "raw fish cooked in fruit juice and chili. Cold, sharp, quick."
    bowl(ic, ramp("5a7a2a", "a8c860", "dcf0a0", "f4ffd0", "ffffff"), wood=WOOD, hot=False, y=0.56)
    for x, y in ((0.36, 0.55), (0.52, 0.60), (0.62, 0.52)):
        ic.part(ic.poly([(x - 0.06, y - 0.04), (x + 0.06, y - 0.04), (x + 0.06, y + 0.04), (x - 0.06, y + 0.04)]), PINKF, shadow=0.02)
    ic.flat(ic.circle((0.46, 0.50), 0.03) | ic.circle((0.70, 0.60), 0.025), RED[2])
    ic.part(ic.circle((0.80, 0.42), 0.17) & ~below_y(ic, 0.44), GREEN, shadow=0.03)
    ic.flat(ic.circle((0.80, 0.42), 0.11) & ~below_y(ic, 0.42), GREEN[4])


def frostberry_pie(ic):
    # "A thick crust round blue berries"
    ic.part(ic.poly(oval((0.50, 0.68), 0.46, 0.27, 24)), CRUST, shadow=0.07)
    top = ic.poly(oval((0.50, 0.58), 0.46, 0.25, 24))
    ic.part(top, CRUST, shadow=0.03)
    fill = ic.poly(oval((0.50, 0.58), 0.36, 0.18, 24))
    ic.flat(fill, BERRY[1])
    for x in (0.30, 0.50, 0.70):
        ic.flat(ic.capsule((x - 0.10, 0.42), (x + 0.10, 0.74), 0.06) & fill, CRUST[2])
        ic.flat(ic.capsule((x + 0.10, 0.42), (x - 0.10, 0.74), 0.06) & fill, CRUST[3])
    for x, y in ((0.40, 0.58), (0.60, 0.58), (0.50, 0.48), (0.50, 0.68)):
        ic.flat(ic.circle((x, y), 0.035), BERRY[3])
    steam(ic, 0.50, 0.28, 0.20)


def ice_cod_chowder(ic):
    # "Fish, grain and tart berries in cream"
    bowl(ic, WHITE, wood=ramp("1b3572", "3a70c2", "78b9ee", "c2ecff", "ffffff"))
    bits(ic, ((0.36, 0.02, 0.04, "4a74e0"), (0.60, -0.04, 0.04, "4a74e0"), (0.66, 0.05, 0.035, "4a74e0")))
    ic.part(ic.poly([(0.42, 0.50), (0.54, 0.46), (0.58, 0.56), (0.46, 0.60)]), CREAM, shadow=0.02)


def date_bread(ic):
    # "Flat bread folded round dates and spice": the round of bread, half of it folded over the dates
    ic.part(ic.poly(oval((0.50, 0.60), 0.46, 0.30, 24)), CRUST, shadow=0.07)
    for x, y in ((0.24, 0.56), (0.38, 0.72), (0.40, 0.46), (0.50, 0.60)):
        ic.part(ic.poly(oval((x, y), 0.085, 0.06, 12)), DATE, shadow=0.02)
    flap = ic.poly(oval((0.57, 0.57), 0.40, 0.28, 24)) & right_x(ic, 0.56)
    ic.part(flap, CRUST, shadow=0.05)
    ic.flat(flap & ~right_x(ic, 0.60), CRUST[3])
    for x, y in ((0.70, 0.46), (0.82, 0.60), (0.70, 0.70)):
        ic.flat(ic.circle((x, y), 0.03) & flap, CRUST[1])


def truffle_risotto(ic):
    # "Rice stirred slow with truffle shavings"
    plate(ic)
    ic.part(ic.poly([(0.20, 0.66), (0.28, 0.46), (0.50, 0.36), (0.72, 0.46), (0.80, 0.66), (0.50, 0.76)]), CREAM, shadow=0.07)
    for x, y, a in ((0.40, 0.50, 20.0), (0.56, 0.46, -30.0), (0.62, 0.60, 10.0), (0.44, 0.64, -15.0)):
        ic.part(ic.lens((x - 0.07, y + 0.07 * math.tan(math.radians(a))), (x + 0.07, y - 0.07 * math.tan(math.radians(a))), 0.07), POT, shadow=0.02)
    ic.part(ic.lens((0.24, 0.42), (0.34, 0.30), 0.07), GREEN, shadow=0.02)
    steam(ic, 0.52, 0.30, 0.20)


def hunters_stew(ic):
    # "Game, grain and truffle, left on the embers overnight": the pot it was left in
    ic.part(ic.path(arc((0.50, 0.50), 0.42, 200.0, 340.0), 0.045), POT, metal=True, shadow=0.02)
    ic.part(ic.poly([(0.10, 0.50), (0.90, 0.50), (0.84, 0.82), (0.68, 0.96), (0.32, 0.96), (0.16, 0.82)]), POT, metal=True, shadow=0.09)
    ic.part(ic.poly(oval((0.50, 0.50), 0.42, 0.14, 24)), POT, metal=True, shadow=0.03)
    ic.part(ic.poly(oval((0.50, 0.51), 0.35, 0.10, 24)), BROTH, shadow=0.02)
    ic.part(ic.circle((0.40, 0.50), 0.075), MEAT, shadow=0.02)
    ic.part(ic.capsule((0.58, 0.50), (0.72, 0.40), 0.05), CREAM, shadow=0.02)
    bits(ic, ((0.56, 0.04, 0.03, "1e1c28"), (0.30, 0.02, 0.025, "96e060")), y=0.51)
    for x in (0.36, 0.64):
        ic.flat(ic.path([(x, 0.98), (x - 0.03, 0.90), (x + 0.03, 0.86)], 0.035), RED[3])


def lily_broth(ic):
    # "A clear broth with a ghost lily floating in it"
    bowl(ic, ramp("3a7a70", "8accc0", "d0f4e8", "f0fff8", "ffffff"), wood=WHITE)
    c = (0.50, 0.52)
    for k in range(6):
        a = math.radians(60.0 * k)
        ic.part(ic.lens(c, (c[0] + math.cos(a) * 0.17, c[1] + math.sin(a) * 0.075), 0.085), GHOST, shadow=0.0)
    ic.flat(ic.circle(c, 0.035), hx("f8d660"))


def mist_dumplings(ic):
    # "Steamed parcels of meat and lily": the steamer, three in it
    ic.part(ic.poly([(0.06, 0.58), (0.94, 0.58), (0.94, 0.84), (0.80, 0.94), (0.20, 0.94), (0.06, 0.84)]), CRUST, shadow=0.07)
    for y in (0.70, 0.82):
        ic.flat(ic.capsule((0.08, y), (0.92, y), 0.025), CRUST[1])
    ic.part(ic.poly(oval((0.50, 0.58), 0.44, 0.17, 24)), CRUST, shadow=0.03)
    ic.flat(ic.poly(oval((0.50, 0.59), 0.37, 0.12, 24)), CRUST[1])
    for x, y in ((0.32, 0.56), (0.68, 0.56), (0.50, 0.62)):
        ic.part(ic.circle((x, y), 0.13) & ~below_y(ic, y + 0.05), WHITE, shadow=0.04)
        ic.flat(ic.capsule((x, y - 0.11), (x, y - 0.05), 0.025) | ic.capsule((x - 0.05, y - 0.09), (x - 0.03, y - 0.04), 0.02) | ic.capsule((x + 0.05, y - 0.09), (x + 0.03, y - 0.04), 0.02), WHITE[1])
    steam(ic, 0.50, 0.34, 0.24)


def lava_grill(ic):
    # Lava-Stone Grill: "meat and fish seared on a hot stone"
    ic.part(ic.poly([(0.04, 0.70), (0.20, 0.60), (0.82, 0.58), (0.96, 0.68), (0.90, 0.88), (0.12, 0.90)]), POT, shadow=0.06)
    for pts in ([(0.14, 0.86), (0.26, 0.78), (0.38, 0.86)], [(0.52, 0.88), (0.64, 0.78), (0.74, 0.84), (0.86, 0.78)]):
        ic.flat(ic.path(pts, 0.035), hx("ff7a3a"))
    ic.part(ic.poly([(0.04, 0.70), (0.20, 0.60), (0.82, 0.58), (0.96, 0.68), (0.50, 0.76)]), POT, shadow=0.0)
    ic.part(ic.poly(oval((0.32, 0.60), 0.19, 0.11, 16)), MEAT, shadow=0.04)
    for dx in (-0.08, 0.0, 0.08):
        ic.flat(ic.capsule((0.32 + dx - 0.03, 0.55), (0.32 + dx + 0.03, 0.65), 0.025), MEAT[0])
    ic.part(ic.poly([(0.80, 0.56), (0.94, 0.46), (0.92, 0.66)]), BROTH, shadow=0.02)
    ic.part(ic.lens((0.52, 0.62), (0.84, 0.56), 0.15), BROTH, shadow=0.04)
    steam(ic, 0.50, 0.36, 0.24)


def ember_curry(ic):
    # "Greens and grain in a curry that crackles"
    bowl(ic, ramp("6a1408", "b83414", "f0641e", "ffa040", "ffe0a0"), wood=CLAY)
    bits(ic, ((0.36, 0.02, 0.04, "96e060"), (0.56, -0.03, 0.035, "fff6c4"), (0.64, 0.05, 0.04, "96e060")))
    spark(ic, (0.16, 0.26), 0.08, "ffc93a")
    spark(ic, (0.86, 0.22), 0.09, "ffc93a")


def lagoon_poke(ic):
    # "Raw reef fish on rice with sea grapes"
    bowl(ic, WHITE, wood=TEAL, hot=False, y=0.56)
    for x, y in ((0.34, 0.52), (0.48, 0.58), (0.44, 0.46)):
        ic.part(ic.poly([(x - 0.065, y - 0.045), (x + 0.065, y - 0.045), (x + 0.065, y + 0.045), (x - 0.065, y + 0.045)]), PINKF, shadow=0.02)
    for x, y in ((0.62, 0.50), (0.70, 0.56), (0.62, 0.60), (0.74, 0.48)):
        ball(ic, (x, y), 0.05, GREEN, shadow=0.02, shine=False)


def pearl_broth(ic):
    # Pearl Diver's Broth: "fish, sea grapes and spice in a hot broth"
    bowl(ic, SUN, wood=SHELL)
    for x, y in ((0.34, 0.52), (0.42, 0.57), (0.36, 0.60)):
        ball(ic, (x, y), 0.045, GREEN, shadow=0.02, shine=False)
    ic.part(ic.poly([(0.52, 0.50), (0.68, 0.46), (0.72, 0.58), (0.56, 0.60)]), WHITE, shadow=0.02)
    ic.flat(ic.circle((0.60, 0.44), 0.025), RED[2])


def below_y(ic, y):
    return ic.poly([(-0.1, y), (1.1, y), (1.1, 1.1), (-0.1, 1.1)])


def right_x(ic, x):
    return ic.poly([(x, -0.1), (1.1, -0.1), (1.1, 1.1), (x, 1.1)])


def ring_o(ic, c, r):
    return ic.circle(c, r) & ~ic.circle(c, r * 0.5)


ITEMS = [
    # coin, treasure, drink
    ("gold", gold), ("treasure", treasure), ("pearl", pearl), ("rum", rum), ("tonic", tonic),
    # materials and beast parts
    ("timber", timber), ("iron", iron), ("copper", copper_sheet), ("canvas", canvas), ("bear_claw", bear_claw), ("bear_hide", bear_hide),
    ("chitin_shard", chitin_shard), ("ivory", ivory), ("knuckle", knuckle), ("mandible", mandible), ("plume", plume), ("sand_plate", sand_plate),
    ("snakeskin", snakeskin), ("tusk", tusk),
    # weapons
    ("axe", axe_item), ("cutlass", cutlass_item), ("katana", katana_item), ("pistol", pistol_item),
    # Driftfruit
    ("ember_fruit", ember_fruit), ("storm_fruit", storm_fruit), ("gust_fruit", gust_fruit), ("wolf_fruit", wolf_fruit), ("bear_fruit", bear_fruit),
    ("iron_fruit", iron_fruit), ("bubble_fruit", bubble_fruit), ("clockwork_fruit", clockwork_fruit), ("echo_fruit", echo_fruit), ("vine_fruit", vine_fruit),
    # ingredients
    ("tangerine", tangerine), ("jungle_fruit", jungle_fruit), ("coconut", coconut), ("egg", egg), ("rice", rice), ("flour", flour), ("salt", salt),
    ("pepper", pepper), ("mushroom", mushroom), ("seaweed", seaweed), ("oyster", oyster), ("sea_urchin", sea_urchin), ("fire_chili", fire_chili),
    ("frost_berries", frost_berries), ("desert_dates", desert_dates), ("black_truffle", black_truffle), ("ghost_lily", ghost_lily),
    ("ember_salt", ember_salt), ("sea_grapes", sea_grapes),
    # food
    ("biscuit", biscuit), ("fish", fish), ("boar_haunch", boar_haunch), ("crab_meat", crab_meat), ("stew", stew),
    # dishes
    ("fish_stew", fish_stew), ("peppered_boar", peppered_boar), ("porridge", porridge), ("citrus_tart", citrus_tart), ("island_skewers", island_skewers),
    ("reef_salad", reef_salad), ("forest_curry", forest_curry), ("captains_feast", captains_feast), ("jungle_pepperpot", jungle_pepperpot),
    ("reef_ceviche", reef_ceviche), ("frostberry_pie", frostberry_pie), ("ice_cod_chowder", ice_cod_chowder), ("date_bread", date_bread),
    ("dune_skewers", dune_skewers), ("truffle_risotto", truffle_risotto), ("hunters_stew", hunters_stew), ("lily_broth", lily_broth),
    ("mist_dumplings", mist_dumplings), ("lava_grill", lava_grill), ("ember_curry", ember_curry), ("lagoon_poke", lagoon_poke), ("pearl_broth", pearl_broth),
]
SIZES = (16, 32, 48)


def render(fn, n):
    ic = Icon(n)
    fn(ic)
    return ic.finish()


def old_icon(name):
    """The 24 px drawing this replaces (git's HEAD copy once the file has been redrawn)."""
    p = os.path.join(ICONS, name + ".png")
    im = Image.open(p).convert("RGBA") if os.path.exists(p) else None
    if im is not None and im.size == (24, 24):
        return im
    try:
        import io
        import subprocess
        raw = subprocess.run(["git", "show", "HEAD~0:assets/textures/icons/%s.png" % name], cwd=ROOT, capture_output=True, check=True).stdout
        im = Image.open(io.BytesIO(raw)).convert("RGBA")
        return im if im.size == (24, 24) else None
    except Exception:
        return None


def review():
    """Every item, the old drawing beside the new, as a 1080p screen shows a 42 px inventory slot (the 960x540 canvas
    at 2x): the old 24 px at 1.5x, the new 32 px at 1x. Then every one at 16 px (toasts, lists) and 48 px (cards)."""
    bg, text, fill, rim = (26, 28, 41, 255), (205, 210, 224, 255), (14, 40, 46, 255), (190, 150, 70, 255)
    per, pair = 8, 84 * 2 + 4 + 12
    rows = (len(ITEMS) + per - 1) // per
    sheet = Image.new("RGBA", (16 + per * pair + 4, 8 + rows * 106 + 8), bg)
    d = ImageDraw.Draw(sheet)
    for i, (name, fn) in enumerate(ITEMS):
        x0, y0 = 16 + (i % per) * pair, 8 + (i // per) * 106
        d.text((x0, y0), name, fill=text)
        for k, im in enumerate((old_icon(name), render(fn, 32))):
            x = x0 + k * 88
            d.rectangle([x, y0 + 14, x + 83, y0 + 97], fill=fill, outline=rim)
            if im is not None:
                im = up(im, 3 if k == 0 else 2)
                sheet.alpha_composite(im, (x + (84 - im.width) // 2, y0 + 14 + (84 - im.height) // 2))
    os.makedirs(REVIEW, exist_ok=True)
    out = os.path.join(REVIEW, "items_new.png")
    sheet.save(out)
    print("  wrote", os.path.relpath(out, ROOT))
    per2 = 20
    rows2 = (len(ITEMS) + per2 - 1) // per2
    small = Image.new("RGBA", (16 + per2 * 100, 8 + rows2 * 104), bg)
    for i, (name, fn) in enumerate(ITEMS):
        x0, y0 = 16 + (i % per2) * 100, 8 + (i // per2) * 104
        small.alpha_composite(up(render(fn, 48), 2), (x0, y0))
        small.alpha_composite(up(render(fn, 16), 2), (x0 + 60, y0 + 64))
    out = os.path.join(REVIEW, "items_new_sizes.png")
    small.save(out)
    print("  wrote", os.path.relpath(out, ROOT))


def main():
    review()
    if "--write" in sys.argv:
        for name, fn in ITEMS:
            for n in SIZES:
                p = os.path.join(ICONS, name + (".png" if n == 32 else "_%d.png" % n))
                render(fn, n).save(p)
        print("  wrote %d items at %s px" % (len(ITEMS), ", ".join(str(n) for n in SIZES)))


if __name__ == "__main__":
    main()
