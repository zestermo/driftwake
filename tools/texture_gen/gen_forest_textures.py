#!/usr/bin/env python3
"""
The forest island theme's textures (docs/forest_island_plan.md): an autumn woodland's ground
(leaf litter, loam paths, mossy granite, a pebbly shore), its crowns (maple reds, oak russets,
birch golds, beech copper, dark fir needles), barks (birch, beech), the floor's cutout cards
(bracken, dry grass, an autumn shrub), and the lumber town's logs, shingles, plaster and river
cobbles, the castle's mossy stone. 64x64, tileable, palette-quantized, a fixed seed each, like
gen_psx_textures.py (whose helpers this imports).

    py tools/texture_gen/gen_forest_textures.py              # all of them
    py tools/texture_gen/gen_forest_textures.py leaves_maple  # just these (names below)
"""
from __future__ import annotations

import math
import sys

import numpy as np
from PIL import Image, ImageDraw

from gen_psx_textures import save, fbm, norm, ramp, pal, hexc, to_img, periodic_noise

SOIL = pal("2a1d14", "33241a", "3d2c1f", "473425")
LITTER = [pal("8a2a18", "a3341c", "b84322"), pal("b4561c", "c86a22", "d9822c"), pal("c99a2c", "d8ae38", "e6c24a"),
          pal("6e4424", "805230", "93623a"), pal("5a5a22", "6b6a2a", "7c7a34")]


def _leaf_specks(rgb, rng, n, palettes, size=(1, 2)):
    """Little leaf shapes strewn over rgb: a diamond each, a darker vein pixel under it."""
    for _ in range(n):
        x, y = rng.integers(0, 64, 2)
        p = palettes[rng.integers(0, len(palettes))]
        c = p[rng.integers(0, len(p))]
        r = rng.integers(size[0], size[1] + 1)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if abs(dx) + abs(dy) <= r:
                    rgb[(y + dy) % 64, (x + dx) % 64] = c
        rgb[(y + r) % 64, x] = SOIL[0]


def gen_forest_litter():
    """The forest floor: fallen leaves in reds, oranges, golds and browns over dark loam, green blades between."""
    rng = np.random.default_rng(8101)
    n = fbm(64, 4, 3, rng)
    rgb = ramp(norm(n) * 0.99, pal("3a2a1c", "4a3522", "5a4228", "4f4a26", "5c5a2c"))
    _leaf_specks(rgb, rng, 150, LITTER, (1, 2))
    for _ in range(40):
        x, y = rng.integers(0, 64, 2)
        for k in range(rng.integers(2, 4)):
            rgb[(y - k) % 64, x] = hexc("6a7a2e") if rng.random() < 0.6 else hexc("4c5a22")
    save(to_img(rgb), "forest_litter")


def gen_forest_dirt():
    """Trodden loam on paths and in the town: dark brown earth, ruts, a few leaves pressed flat, pebbles."""
    rng = np.random.default_rng(8102)
    n = fbm(64, 4, 4, rng) * 0.7 + rng.random((64, 64)) * 0.3
    x = np.arange(64)[None, :] / 64.0
    ruts = np.abs(np.sin((x * 2 + periodic_noise(64, 4, rng) * 0.3) * math.tau)) * 0.2
    rgb = ramp(norm(n + ruts), pal("2e2016", "3a2a1c", "463322", "523d29", "5e4730"))
    _leaf_specks(rgb, rng, 18, [LITTER[0], LITTER[1], LITTER[3]], (0, 1))
    for _ in range(26):
        px, py = rng.integers(0, 64, 2)
        rgb[py, px] = hexc("7a7062") if rng.random() < 0.5 else hexc("231810")
    save(to_img(rgb), "forest_dirt")


def gen_forest_rock():
    """Grey granite for crags, cliffs and boulders: speckled, cracked, moss and lichen in patches."""
    rng = np.random.default_rng(8103)
    n = fbm(64, 4, 5, rng)
    rgb = ramp(norm(n), pal("3c3d3e", "4a4b4b", "57585a", "656667", "737475", "818283"))
    cracks = np.abs(periodic_noise(64, 8, rng) - 0.5) < 0.03
    rgb[cracks] = hexc("262728")
    moss = norm(fbm(64, 4, 3, rng)) > 0.62
    rgb[moss] = ramp(norm(fbm(64, 8, 2, rng))[moss], pal("2e3e1c", "3a4e22", "4a5e2a", "5a6c32"))
    for _ in range(30):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("a9a68c") if rng.random() < 0.5 else hexc("c0b070")
    save(to_img(rgb), "forest_rock")


def gen_forest_beach():
    """A temperate shore: grey-brown sand and pebbles, a stray leaf blown down to it."""
    rng = np.random.default_rng(8104)
    n = fbm(64, 4, 3, rng) * 0.6 + rng.random((64, 64)) * 0.4
    rgb = ramp(norm(n), pal("6f6656", "7e7462", "8d826e", "9a8f7a", "a89c86"))
    for _ in range(60):
        x, y = rng.integers(0, 64, 2)
        c = hexc("54504a") if rng.random() < 0.5 else hexc("b9b2a2")
        rgb[y, x] = c
        rgb[y, (x + 1) % 64] = c
    _leaf_specks(rgb, rng, 6, [LITTER[1], LITTER[3]], (0, 1))
    save(to_img(rgb), "forest_beach")


def _crown(seed, base, specks, name, dark):
    """Opaque crown texture for the canopy blobs: a mottled base and many leaf diamonds, dark gaps between."""
    rng = np.random.default_rng(seed)
    n = fbm(64, 4, 3, rng)
    rgb = ramp(norm(n) * 0.75, base)
    for _ in range(200):
        x, y = rng.integers(0, 64, 2)
        c = specks[rng.integers(0, len(specks))]
        for dy, dx in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1)):
            rgb[(y + dy) % 64, (x + dx) % 64] = c
        rgb[(y + 2) % 64, x] = hexc(dark)
    save(to_img(rgb), name)


def gen_leaves_maple():
    _crown(8111, pal("7a1c12", "922416", "a82e18", "bc3a1c"), pal("b02a18", "c43a1c", "d84c20", "e0642a", "c8781e"), "leaves_maple", "4e140c")


def gen_leaves_oak():
    _crown(8112, pal("6a4420", "7e5226", "92602c", "8a7430"), pal("8a5424", "a0642a", "b47a30", "8a7a2c", "c48e3a"), "leaves_oak", "3e2a16")


def gen_leaves_birch():
    _crown(8113, pal("7a6014", "8e7018", "a2821c", "6e7020"), pal("d0a426", "e0b62e", "eecb3c", "f4da5a", "b8b030"), "leaves_birch", "4a3a0c")


def gen_leaves_beech():
    _crown(8114, pal("8a3c14", "a04a18", "b45a1e", "c46a24"), pal("c0621e", "d07426", "dc8a30", "b85a1c", "e4a03c"), "leaves_beech", "52240e")


def gen_leaves_green():
    """The odd tree still green (late to turn), so a hillside isn't one flat colour."""
    _crown(8115, pal("34501c", "406020", "4c6e26", "5e7028"), pal("4e7028", "5e8030", "6e8a34", "8a8a30", "a07a2a"), "leaves_late", "16240c")


def gen_fir_needles():
    """A fir tier from its top (v 0) to its drooping rim (v 1): dark blue-green needle sprays, a few gold larch tips."""
    rng = np.random.default_rng(8116)
    needles = pal("0e1f1a", "132a22", "18352a", "1e4032", "264c3a")
    img = Image.new("RGB", (64, 64), needles[1])
    d = ImageDraw.Draw(img)
    for _ in range(300):
        x, y = rng.uniform(0, 64), rng.uniform(0, 64)
        a = math.pi / 2 + rng.uniform(-0.8, 0.8)
        L = rng.uniform(3, 7)
        c = needles[rng.integers(0, len(needles))]
        for dx in (-64, 0, 64):
            d.line([(x + dx, y), (x + dx + math.cos(a) * L, y + math.sin(a) * L)], fill=c)
    rgb = np.array(img)
    rgb[63] = hexc("0a1612")
    save(to_img(rgb), "fir_needles")


def gen_birch_bark():
    """White birch bark: chalky white, black lenticel dashes across, dark knots."""
    rng = np.random.default_rng(8117)
    n = fbm(64, 4, 3, rng)
    rgb = ramp(norm(n) * 0.6 + 0.4, pal("b8b4aa", "c8c4ba", "d6d2c8", "e2ded4", "ece8de"))
    for _ in range(46):
        x, y = rng.integers(0, 64, 2)
        L = rng.integers(3, 10)
        for k in range(L):
            rgb[y, (x + k) % 64] = hexc("1e1c1a") if rng.random() < 0.8 else hexc("4a4640")
    for _ in range(4):
        x, y = rng.integers(0, 64, 2)
        for dy in range(-2, 3):
            for dx in range(-1, 2):
                rgb[(y + dy) % 64, (x + dx) % 64] = hexc("262420")
    save(to_img(rgb), "birch_bark")


def gen_beech_bark():
    """Smooth beech bark: elephant grey, faint rings, green-grey algae patches."""
    rng = np.random.default_rng(8118)
    n = fbm(64, 2, 3, rng)
    rings = np.sin(np.arange(64)[:, None] / 64.0 * math.tau * 5 + periodic_noise(64, 4, rng) * 2) * 0.12
    rgb = ramp(norm(n + rings), pal("5c5c58", "6a6a66", "787874", "868682", "94948e"))
    algae = norm(fbm(64, 4, 2, rng)) > 0.7
    rgb[algae] = hexc("6a7460")
    save(to_img(rgb), "beech_bark")


def gen_bracken():
    """A cutout card: autumn bracken, rust and orange fronds arching from the ground, a few still green."""
    rng = np.random.default_rng(8121)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(7):
        ang = math.radians(-160 + i * 23 + rng.uniform(-6, 6))
        L = rng.uniform(22, 30)
        x1 = 32 + math.cos(ang) * L
        y1 = 62 + math.sin(ang) * L
        tones = [pal("6e3414", "84421a", "9a5220", "b06428"), pal("7a5a1c", "906c22", "a8802a", "be9634"), pal("3e5220", "4a6226", "567030", "647c36")][
            0 if rng.random() < 0.55 else (1 if rng.random() < 0.7 else 2)]
        d.line([(32, 62), (x1, y1)], fill=tones[0] + (255,))
        for t in np.linspace(0.15, 0.95, 9):
            px = 32 + (x1 - 32) * t
            py = 62 + (y1 - 62) * t
            s = (1 - t) * 6 + 1
            c = tones[rng.integers(1, len(tones))]
            d.line([(px, py), (px - s * math.sin(ang) * 0.9, py + s * math.cos(ang) * 0.9 - s)], fill=c + (255,))
            d.line([(px, py), (px + s * math.sin(ang) * 0.9, py - s * math.cos(ang) * 0.9 - s)], fill=c + (255,))
    save(img, "bracken")


def gen_autumn_grass():
    """A cutout card: pale gold and tawny dry grass, a seed head or two."""
    rng = np.random.default_rng(8122)
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    straw = pal("8a7a3a", "a08c42", "b49e4c", "c8b25a", "7a6a34", "6a7230")
    for _ in range(24):
        x0 = rng.integers(4, 28)
        h = rng.integers(8, 28)
        lean = rng.integers(-5, 6)
        d.line([(x0, 31), (x0 + lean, 31 - h)], fill=straw[rng.integers(0, len(straw))] + (255,))
        if rng.random() < 0.2:
            d.point((x0 + lean, 31 - h), fill=hexc("e0d090") + (255,))
    save(img, "autumn_grass")


def gen_autumn_bush():
    """A cutout card: a hazel or bramble shrub turning, leaves red at the top, gold and green below."""
    rng = np.random.default_rng(8123)
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stems = pal("3a2a1c", "4a3624")
    for _ in range(14):
        x, y = rng.uniform(24, 40), 63.0
        ang = rng.uniform(-1.0, 1.0) - math.pi / 2
        for _s in range(rng.integers(3, 6)):
            L = rng.uniform(5, 9)
            nx, ny = x + math.cos(ang) * L, y + math.sin(ang) * L
            d.line([(x, y), (nx, ny)], fill=stems[rng.integers(0, 2)] + (255,))
            x, y = nx, ny
            ang += rng.uniform(-0.5, 0.5)
    tones = [pal("b02a18", "c43a1c", "d84c20"), pal("c86a22", "d9822c", "e09a34"), pal("c99a2c", "d8ae38"), pal("5a6a26", "6a7a2e")]
    for _ in range(280):
        x = rng.normal(32, 13)
        y = rng.normal(36, 12)
        if not (2 < x < 62 and 4 < y < 63):
            continue
        band = min(3, max(0, int((y - 14) / 14 + rng.normal(0, 0.6))))
        p = tones[band]
        r = rng.integers(1, 3)
        d.ellipse([x - r, y - r, x + r, y + r], fill=p[rng.integers(0, len(p))] + (255,))
    save(img, "autumn_bush")


def gen_logs():
    """A log wall: round logs laid in courses (8 px each), bark-brown with pale ends of the grain, dark chinks between."""
    rng = np.random.default_rng(8131)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    palette = pal("3a2616", "4a321c", "5a3e22", "6a4a2a", "7a5832", "8a663a")
    g = fbm(64, 8, 3, rng)
    for y in range(64):
        ly = (y % 8) / 7.0
        curve = 1.0 - abs(ly - 0.45) * 2.0
        for x in range(64):
            v = curve * 0.65 + g[y, (x // 3) % 64] * 0.3
            rgb[y, x] = palette[min(len(palette) - 1, max(0, int(v * len(palette))))]
        if y % 8 == 7:
            rgb[y] = hexc("1e140c")
    for _ in range(20):
        x, y = rng.integers(0, 64), rng.integers(0, 8) * 8 + 3
        rgb[y, x] = hexc("2a1c10")
        rgb[y, (x + 1) % 64] = hexc("2a1c10")
    save(to_img(rgb), "logs")


def gen_shingles():
    """Wood shingle roofing: rows of split shakes in grey-brown, staggered joints, moss creeping in."""
    rng = np.random.default_rng(8132)
    palette = pal("3a3028", "463a30", "524436", "5e4e3e", "6a5846", "766250")
    n = fbm(64, 4, 3, rng)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    for row in range(8):
        off = rng.integers(0, 8)
        x = -off
        while x < 64:
            w = rng.integers(5, 9)
            shade = rng.random() * 0.4
            for y in range(row * 8, row * 8 + 8):
                ly = (y % 8) / 8.0
                for xx in range(x, x + w):
                    v = shade + n[y, xx % 64] * 0.35 + ly * 0.25
                    rgb[y, xx % 64] = palette[min(len(palette) - 1, int(v * len(palette)))]
            for y in range(row * 8, row * 8 + 8):
                rgb[y, (x + w - 1) % 64] = hexc("221a14")
            x += w
        rgb[row * 8 + 7] = hexc("1a140e")
    moss = norm(fbm(64, 4, 3, rng)) > 0.72
    rgb[moss] = ramp(norm(fbm(64, 8, 2, rng))[moss], pal("3a4a22", "46582a", "526630"))
    save(to_img(rgb), "shingles")


def gen_plaster_wash():
    """Lime plaster between timbers: warm off-white, uneven, a little dirt low down (tinted by vertex colour)."""
    rng = np.random.default_rng(8133)
    n = fbm(64, 4, 4, rng) * 0.7 + rng.random((64, 64)) * 0.3
    rgb = ramp(norm(n), pal("bdb4a0", "c8bfab", "d2cab6", "dcd4c0", "e4dcc8"))
    for _ in range(14):
        x, y = rng.integers(0, 64, 2)
        rgb[y, x] = hexc("a69c88")
    save(to_img(rgb), "plaster_wash")


def gen_river_cobbles():
    """The town's paving: rounded river stones in greys and browns, moss and leaves in the joints."""
    rng = np.random.default_rng(8134)
    rgb = np.zeros((64, 64, 3), dtype=np.uint8)
    rgb[:] = hexc("2e2a1e")
    img = Image.fromarray(rgb, "RGB")
    d = ImageDraw.Draw(img)
    tones = pal("6a665e", "78736a", "868076", "5e5a52", "7c6e5a", "8a7a64")
    for gy in range(0, 64, 8):
        for gx in range(0, 64, 8):
            cx = gx + 4 + rng.uniform(-1.5, 1.5) + (4 if (gy // 8) % 2 else 0)
            cy = gy + 4 + rng.uniform(-1.0, 1.0)
            rx, ry = rng.uniform(2.6, 3.8), rng.uniform(2.2, 3.4)
            c = tones[rng.integers(0, len(tones))]
            for dx in (-64, 0, 64):
                for dy in (-64, 0, 64):
                    d.ellipse([cx - rx + dx, cy - ry + dy, cx + rx + dx, cy + ry + dy], fill=c)
                    d.point((cx - rx * 0.4 + dx, cy - ry * 0.5 + dy), fill=hexc("9c968a"))
    rgb = np.array(img)
    joint = np.all(rgb == hexc("2e2a1e"), axis=-1)
    moss = norm(fbm(64, 4, 2, rng)) > 0.55
    rgb[joint & moss] = hexc("3e4a22")
    _leaf_specks(rgb, rng, 10, [LITTER[0], LITTER[1], LITTER[2]], (0, 1))
    save(to_img(rgb), "river_cobbles")


def gen_moss_stone():
    """The castle's walls: big grey ashlar blocks, mortar lines, moss down from the top of each course, ivy dark."""
    rng = np.random.default_rng(8135)
    n = fbm(64, 4, 4, rng)
    rgb = ramp(norm(n) * 0.8 + 0.1, pal("4a4a48", "565654", "626260", "6e6e6a", "7a7a76"))
    for r in range(4):
        y0 = r * 16
        rgb[y0] = hexc("2c2c2a")
        off = 0 if r % 2 == 0 else 12
        for x in (off, off + 24, off + 48):
            rgb[y0:y0 + 16, x % 64] = hexc("2c2c2a")
        moss = fbm(64, 8, 2, rng)[0]
        for x in range(64):
            for k in range(int(1 + moss[x] * 5)):
                rgb[(y0 + 1 + k) % 64, x] = pal("2e4a1c", "3a5a22", "46682a")[min(2, k)]
    save(to_img(rgb), "moss_stone")


def gen_wisp_glow():
    """A soft round glow for will-o'-wisps and spirit lights (white, its alpha falling off; tinted by the material)."""
    size = 32
    y, x = np.mgrid[0:size, 0:size]
    r = np.sqrt((x - 15.5) ** 2 + (y - 15.5) ** 2) / 15.5
    a = np.clip(1.0 - r, 0, 1) ** 1.6
    a = np.round(a * 6) / 6
    rgb = np.full((size, size, 3), 255, dtype=np.uint8)
    save(to_img(rgb, a), "wisp_glow")


ALL = {
    "forest_litter": gen_forest_litter, "forest_dirt": gen_forest_dirt, "forest_rock": gen_forest_rock, "forest_beach": gen_forest_beach,
    "leaves_maple": gen_leaves_maple, "leaves_oak": gen_leaves_oak, "leaves_birch": gen_leaves_birch, "leaves_beech": gen_leaves_beech,
    "leaves_late": gen_leaves_green, "fir_needles": gen_fir_needles, "birch_bark": gen_birch_bark, "beech_bark": gen_beech_bark,
    "bracken": gen_bracken, "autumn_grass": gen_autumn_grass, "autumn_bush": gen_autumn_bush,
    "logs": gen_logs, "shingles": gen_shingles, "plaster_wash": gen_plaster_wash, "river_cobbles": gen_river_cobbles,
    "moss_stone": gen_moss_stone, "wisp_glow": gen_wisp_glow,
}


def main():
    names = sys.argv[1:] or list(ALL)
    for n in names:
        ALL[n]()


if __name__ == "__main__":
    sys.exit(main())
