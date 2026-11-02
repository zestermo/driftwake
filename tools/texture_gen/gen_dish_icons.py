"""1.28 island ingredients and dishes: their 24x24 item icons (assets/textures/icons/), drawn like
gen_psx_textures.gen_icons' food (its _icon adds the dark outline). Run: py tools/texture_gen/gen_dish_icons.py"""
from __future__ import annotations

import math

from gen_psx_textures import _icon, hexc


def c(s, a=255):
    return hexc(s) + (a,)


def bowl(d, food, bits, steam=True, rim="6a4628"):
    d.chord([3, 8, 21, 22], 0, 180, fill=c(rim))
    d.ellipse([3, 9, 21, 15], fill=c(food))
    for (x, y, col) in bits:
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=c(col))
    if steam:
        for x in (8, 15):
            d.line([(x, 7), (x + 1, 5), (x, 3)], fill=c("e8e8e8", 200))


def plate(d, col="d8d0c0"):
    d.ellipse([1, 14, 23, 22], fill=c(col))
    d.ellipse([3, 15, 21, 21], fill=c("eee8dc"))


# ---- ingredients ----
def fire_chili(d):
    d.polygon([(6, 8), (10, 6), (17, 14), (19, 20), (14, 17)], fill=c("d0281a"))
    d.line([(9, 8), (16, 15)], fill=c("ff6a50"))
    d.line([(6, 8), (4, 4)], fill=c("3a8a28"), width=2)


def frost_berries(d):
    for (x, y) in ((8, 13), (13, 11), (16, 15), (11, 17), (7, 18)):
        d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=c("3a5ab8"))
        d.point((x - 1, y - 1), fill=c("c8e0ff"))
    d.line([(12, 4), (13, 10)], fill=c("4a6a3a"))
    d.polygon([(12, 4), (17, 3), (15, 7)], fill=c("5a8a4a"))


def desert_dates(d):
    for (x, y) in ((8, 12), (14, 10), (12, 16), (17, 16)):
        d.ellipse([x - 3, y - 4, x + 3, y + 4], fill=c("6a3014"))
        d.line([(x - 1, y - 2), (x - 1, y + 2)], fill=c("a0582a"))


def black_truffle(d):
    d.ellipse([4, 7, 20, 21], fill=c("2a1e18"))
    for (x, y) in ((8, 11), (13, 10), (16, 14), (10, 16), (14, 18)):
        d.point((x, y), fill=c("5a4838"))
    d.chord([4, 12, 20, 21], 0, 180, fill=c("3a2a20"))
    d.arc([7, 14, 17, 20], 200, 340, fill=c("c8b8a0"))


def ghost_lily(d):
    for k in range(5):
        a = -math.pi / 2 + k * 2 * math.pi / 5
        x, y = 12 + 7 * math.cos(a), 12 + 7 * math.sin(a)
        d.polygon([(12, 12), (x - 2 * math.sin(a), y + 2 * math.cos(a)), (x, y), (x + 2 * math.sin(a), y - 2 * math.cos(a))], fill=c("e0ecf0"))
    d.ellipse([10, 10, 14, 14], fill=c("b8f0e0"))
    d.line([(12, 19), (12, 23)], fill=c("6a8a7a"))


def ember_salt(d):
    d.chord([3, 10, 21, 22], 0, 180, fill=c("4a3a30"))
    d.ellipse([4, 9, 20, 16], fill=c("3a1410"))
    for (x, y) in ((8, 12), (12, 11), (15, 13), (10, 14), (17, 11)):
        d.rectangle([x - 1, y - 1, x, y], fill=c("ff5a20"))
    d.point([(13, 13), (7, 11)], fill=c("ffd060"))


def sea_grapes(d):
    d.line([(12, 22), (12, 4)], fill=c("2a7a3a"))
    for y in range(5, 20, 3):
        for dx in (-3, 3):
            d.ellipse([12 + dx - 2, y - 2, 12 + dx + 2, y + 2], fill=c("60c860"))
            d.point((12 + dx - 1, y - 1), fill=c("c8ffc0"))


# ---- dishes ----
def jungle_pepperpot(d):
    bowl(d, "5a2010", [(8, 12, "d0281a"), (13, 11, "8a4a20"), (16, 13, "3e8a48"), (11, 13, "d0281a")])


def reef_ceviche(d):
    bowl(d, "f0e0b0", [(8, 12, "f4f0ea"), (13, 11, "d0281a"), (16, 13, "f0a020"), (11, 13, "f4f0ea")], steam=False, rim="c8c0b0")


def frostberry_pie(d):
    d.chord([3, 8, 21, 22], 0, 180, fill=c("c89048"))
    d.ellipse([3, 9, 21, 16], fill=c("3a4aa8"))
    for x in (7, 11, 15, 19):
        d.line([(x, 10), (x - 3, 15)], fill=c("e0b070"))
    d.line([(3, 14), (21, 14)], fill=c("a87030"))


def ice_cod_chowder(d):
    bowl(d, "eee8d8", [(8, 12, "f8f4ec"), (13, 11, "3a5ab8"), (16, 13, "d8c8a0"), (11, 13, "3a5ab8")])


def date_bread(d):
    d.ellipse([2, 9, 22, 20], fill=c("d8a860"))
    d.ellipse([4, 10, 20, 17], fill=c("e8c080"))
    for (x, y) in ((8, 13), (13, 12), (16, 15)):
        d.ellipse([x - 2, y - 1, x + 2, y + 1], fill=c("6a3014"))


def dune_skewers(d):
    for dx in (0, 5):
        d.line([(3 + dx, 21), (16 + dx, 3)], fill=c("8a8a90"))
        for k, col in enumerate(("8a4a20", "6a3014", "8a4a20")):
            x = 6 + dx + k * 3
            y = 17 - k * 4
            d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=c(col))


def truffle_risotto(d):
    bowl(d, "e8dcb8", [(8, 12, "2a1e18"), (13, 11, "2a1e18"), (16, 13, "5ab060"), (11, 13, "fff8e8")], rim="d8d0c0")


def hunters_stew(d):
    bowl(d, "7a4020", [(8, 12, "5a2a10"), (13, 11, "2a1e18"), (16, 13, "c89858"), (11, 13, "5a2a10")])


def lily_broth(d):
    bowl(d, "b8d8c8", [(16, 13, "6a8a7a")], rim="5a6a70")
    for k in range(5):
        a = k * 2 * math.pi / 5
        d.line([(11, 12), (11 + int(3 * math.cos(a)), 12 + int(2 * math.sin(a)))], fill=c("f4fcff"))


def mist_dumplings(d):
    plate(d, "8a9aa0")
    for (x, y) in ((8, 15), (16, 15), (12, 12)):
        d.ellipse([x - 4, y - 3, x + 4, y + 3], fill=c("eee8e0"))
        d.line([(x - 2, y - 2), (x, y - 3), (x + 2, y - 2)], fill=c("b8b0a8"))
    for x in (9, 15):
        d.line([(x, 7), (x + 1, 5), (x, 3)], fill=c("e8e8e8", 200))


def lava_grill(d):
    d.rectangle([2, 14, 22, 21], fill=c("2a2420"))
    d.line([(2, 14), (22, 14)], fill=c("ff5a20"))
    d.ellipse([4, 9, 13, 15], fill=c("5a2a10"))
    d.ellipse([12, 8, 21, 14], fill=c("c88050"))
    d.line([(6, 11), (10, 13)], fill=c("1a1008"))
    d.line([(14, 10), (19, 12)], fill=c("6a3a20"))


def ember_curry(d):
    bowl(d, "c84a18", [(8, 12, "3e8a48"), (13, 11, "fff8e8"), (16, 13, "ff8a28"), (11, 13, "3a1410")])


def lagoon_poke(d):
    bowl(d, "f4f0ea", [(8, 12, "e86a50"), (13, 11, "60c860"), (16, 13, "e86a50"), (11, 13, "60c860")], steam=False, rim="2a6a8a")


def pearl_broth(d):
    bowl(d, "d8c8a0", [(8, 12, "60c860"), (13, 11, "f4f0ea"), (16, 13, "60c860")], rim="2a6a8a")
    d.ellipse([10, 10, 13, 13], fill=c("fffaff"))


if __name__ == "__main__":
    for fn in (fire_chili, frost_berries, desert_dates, black_truffle, ghost_lily, ember_salt, sea_grapes,
               jungle_pepperpot, reef_ceviche, frostberry_pie, ice_cod_chowder, date_bread, dune_skewers,
               truffle_risotto, hunters_stew, lily_broth, mist_dumplings, lava_grill, ember_curry, lagoon_poke, pearl_broth):
        _icon(fn.__name__, fn)
