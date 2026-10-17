"""Item icons for the ship upgrades (24x24, transparent, a 1 px dark outline, like gen_psx_textures' icons):
the salvage (timber, iron, canvas, copper) and the grove's tangerine -> assets/textures/icons/.

    py tools/texture_gen/gen_ship_icons.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "textures", "icons")


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def icon(name, draw_fn):
    img = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(img))
    a = np.array(img)
    alpha = a[..., 3] > 0
    out = np.zeros_like(alpha)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        out |= np.roll(np.roll(alpha, dy, 0), dx, 1)
    a[out & ~alpha] = (20, 14, 10, 255)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    Image.fromarray(a, "RGBA").save(path)
    print("  wrote", os.path.relpath(path, ROOT))


def timber(d):
    # three planks stacked slantwise, a rope round them
    for k, c in enumerate(("8a5a30", "a8743e", "c8904c")):
        y = 15 - k * 4
        d.polygon([(3, y + 3), (19, y - 3), (21, y), (5, y + 6)], fill=hexc(c))
        d.line([(5, y + 4), (19, y - 1)], fill=hexc("5a3818"))
    d.line([(11, 4), (13, 19)], fill=hexc("d8c088"), width=2)


def iron(d):
    # an iron knee and two bolts
    d.polygon([(4, 4), (9, 4), (9, 15), (20, 15), (20, 20), (4, 20)], fill=hexc("6a7078"))
    d.line([(5, 5), (5, 19), (19, 19)], fill=hexc("a8b0b8"))
    d.polygon([(9, 15), (9, 11), (13, 15)], fill=hexc("4a5058"))
    for (x, y) in ((15, 6), (19, 9)):
        d.rectangle([x - 1, y - 4, x + 1, y + 4], fill=hexc("8a929a"))
        d.rectangle([x - 2, y - 5, x + 2, y - 4], fill=hexc("c0c8d0"))


def canvas(d):
    # a roll of sailcloth tied with rope
    d.ellipse([3, 7, 9, 19], fill=hexc("c8bea0"))
    d.rectangle([6, 7, 19, 19], fill=hexc("eee6cc"))
    d.ellipse([16, 7, 22, 19], fill=hexc("f8f2e0"))
    d.ellipse([18, 11, 20, 15], fill=hexc("b8ae90"))
    for x in (9, 15):
        d.line([(x, 7), (x, 19)], fill=hexc("a07a40"), width=2)
    d.line([(7, 10), (17, 10)], fill=hexc("d8d0b4"))


def copper(d):
    # two copper sheets, one turned up, a glint
    d.polygon([(2, 15), (14, 11), (22, 15), (10, 20)], fill=hexc("b8642c"))
    d.polygon([(4, 11), (14, 6), (21, 10), (11, 15)], fill=hexc("e08a48"))
    d.line([(6, 11), (14, 7)], fill=hexc("ffc890"))
    d.point([(15, 8), (16, 8), (15, 9)], fill=(255, 245, 220, 255))
    for (x, y) in ((7, 12), (17, 11), (12, 14)):
        d.point((x, y), fill=hexc("8a4018"))


def tangerine(d):
    d.ellipse([4, 7, 19, 21], fill=hexc("f08a18"))
    d.ellipse([6, 9, 11, 13], fill=hexc("ffc060"))
    d.point([(9, 17), (14, 15), (15, 18), (12, 12)], fill=hexc("c86a10"))
    d.line([(12, 7), (12, 4)], fill=hexc("6a4a20"))
    d.polygon([(12, 5), (18, 2), (20, 5), (14, 7)], fill=hexc("3a8a28"))


if __name__ == "__main__":
    for n, f in (("timber", timber), ("iron", iron), ("canvas", canvas), ("copper", copper), ("tangerine", tangerine)):
        icon(n, f)
