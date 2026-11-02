"""1.28 chain sickle: its techniques' skill icons (assets/textures/icons/skill_<id>.png, 24x24), ghostfire: pale
ghost-white, sickly green flame, a cold teal. Run: py tools/texture_gen/gen_sickle_icons.py"""
from __future__ import annotations

import math

from gen_psx_textures import _icon, hexc

STEEL = hexc("c8d0d0") + (255,)
CHAIN = hexc("8a8a90") + (255,)
FLAME = hexc("6af06a") + (255,)
FLAME_D = hexc("2a8a3a") + (255,)
TEAL = hexc("60e0d0") + (255,)
PALE = hexc("e8fff0") + (255,)


def sickle(d, x, y, r=5):
    d.arc([x - r, y - r, x + r, y + r], 180, 360, fill=STEEL, width=2)
    d.line([(x + r, y), (x + r, y + 5)], fill=hexc("6a4424") + (255,), width=2)


def chain(d, pts):
    for a, b in zip(pts, pts[1:]):
        d.line([a, b], fill=CHAIN)
    for p in pts[::2]:
        d.point(p, fill=PALE)


def flame(d, x, y, h=6):
    d.polygon([(x - 2, y), (x, y - h), (x + 2, y)], fill=FLAME)
    d.point((x, y - h // 2), fill=PALE)


def binding_coil(d):
    d.ellipse([6, 4, 18, 20], outline=CHAIN)
    d.ellipse([8, 7, 16, 17], outline=FLAME_D)
    d.rectangle([10, 8, 14, 18], fill=hexc("5a4a40") + (255,))
    chain(d, [(2, 22), (6, 18), (8, 14)])


def serpent_lash(d):
    chain(d, [(2, 20), (6, 14), (10, 16), (14, 10), (18, 12), (21, 6)])
    d.ellipse([19, 3, 23, 7], fill=CHAIN)
    flame(d, 12, 12, 5)


def reel_and_reap(d):
    chain(d, [(22, 12), (16, 12), (10, 12)])
    d.ellipse([20, 10, 24, 14], fill=CHAIN)
    sickle(d, 7, 12, 5)
    flame(d, 15, 10, 4)


def hook_step(d):
    chain(d, [(3, 20), (9, 14), (15, 9), (20, 5)])
    sickle(d, 15, 16, 4)
    d.line([(1, 12), (6, 12)], fill=TEAL)


def harvest_of_souls(d):
    d.ellipse([2, 2, 22, 22], outline=FLAME)
    d.ellipse([5, 5, 19, 19], outline=FLAME_D)
    for k in range(5):
        a = k * math.tau / 5
        flame(d, int(12 + 9 * math.cos(a)), int(14 + 9 * math.sin(a)), 4)
    sickle(d, 12, 12, 4)


def soul_chain(d):
    chain(d, [(1, 12), (5, 12), (9, 12), (13, 12), (17, 12), (21, 12)])
    for x in (4, 10, 16):
        d.ellipse([x - 2, 4, x + 2, 9], fill=PALE)
        d.point((x, 10), fill=TEAL)
    flame(d, 20, 12, 6)


if __name__ == "__main__":
    for fn in (binding_coil, serpent_lash, reel_and_reap, hook_step, harvest_of_souls, soul_chain):
        _icon("skill_" + fn.__name__, fn)
