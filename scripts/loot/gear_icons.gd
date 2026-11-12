class_name GearIcons
extends RefCounted
## 32x32 pixel-art icons for gear, drawn at runtime in the item's own colors
## (so a navy long coat gets a navy icon). Same style as the painted item
## icons (gen_item_icons.py), ink and cel: flat colour, a hard shadow lower right,
## a light edge upper left, ink round each part. The shapes are laid out on a
## 24 grid (_shapes) and drawn K times that.

const SIZE := 32
const K := SIZE / 24.0
const OUTLINE := Color8(14, 12, 20)
const GOLD := Color(0.88, 0.69, 0.31)
const STEEL := Color(0.78, 0.82, 0.85)
const LEATHER := Color(0.36, 0.22, 0.12)

static var _cache: Dictionary = {}


static func icon(it: ItemData) -> Texture2D:
	var main := _main_color(it)
	var second := _second_color(it)
	# very dark cloth still needs to read against the dark slot
	if main.get_luminance() < 0.16:
		main = main.lightened(0.22)
	if second.get_luminance() < 0.16:
		second = second.lightened(0.22)
	var pat := ""
	for k in it.look.keys():
		if str(k).ends_with("_pattern"):
			pat = str(it.look[k])
	var key := "%s|%s|%s|%s" % [it.icon_kind, main.to_html(), second.to_html(), pat]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for layer in _shapes(str(Gear.SHAPE_OF.get(it.icon_kind, it.icon_kind)), it.look):
		var col: Color = main
		match str(layer[0]):
			"b": col = second
			"d": col = main.darkened(0.3)
			"l": col = main.lightened(0.25)
			"g": col = GOLD
			"s": col = STEEL
			"k": col = Color(0.08, 0.07, 0.07)
			"w": col = LEATHER
			"r": col = Color(0.78, 0.16, 0.18)
			"i": col = Color(0.92, 0.88, 0.76)
		_fill(img, layer[1], col, str(layer[0]) in ["d", "l"])
	if pat != "":
		_pattern(img, pat)
	_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _main_color(it: ItemData) -> Color:
	var lk := it.look
	if it.icon_kind == "crown":
		return GOLD
	if it.icon_kind in Gear.STEEL_PIECES:
		return STEEL
	for k in ["hat_color", "face_color", "wraps_color", "backpack_color", "top_color", "vest_color", "coat_color", "gloves_color", "legs_color", "feet_color", "scarf_color", "apron_color", "cape_color", "cloak_color"]:
		if lk.has(k) and lk[k] is Color:
			return lk[k]
	if lk.has("belt"):
		return lk.get("sash_color", Color.RED) if str(lk["belt"]) == "sash" else lk.get("belt_color", LEATHER)
	match it.icon_kind:
		"earring": return GOLD
		"eyepatch": return Color(0.12, 0.1, 0.09)
		"pauldron", "pauldron_r", "pauldrons": return STEEL
		"pouch", "bandolier", "goggles", "baldric": return LEATHER
		"spyglass": return Color(0.82, 0.66, 0.3)
		"necklace", "shark_tooth": return Color(0.92, 0.88, 0.76)
	return Color(0.7, 0.7, 0.7)


static func _second_color(it: ItemData) -> Color:
	var lk := it.look
	if lk.has("trim_color") and lk["trim_color"] is Color:
		return lk["trim_color"]
	if lk.has("sash_color") and lk["sash_color"] is Color:
		return lk["sash_color"]
	if lk.has("motley_color") and lk["motley_color"] is Color:
		return lk["motley_color"]
	return GOLD


## Layers of [color code, polygon]. Codes: m main, d dark, l light, b second
## (trim / sash), g gold, s steel, k black, w leather, r red, i ivory.
static func _shapes(kind: String, look: Dictionary) -> Array:
	match kind:
		"slouch":
			return [["m", [Vector2(1, 16), Vector2(5, 13), Vector2(19, 13), Vector2(23, 16), Vector2(19, 19), Vector2(5, 19)]],
				["m", [Vector2(7, 14), Vector2(8, 8), Vector2(16, 8), Vector2(17, 14)]],
				["m", [Vector2(3, 15), Vector2(4, 6), Vector2(8, 8), Vector2(7, 15)]],
				["d", [Vector2(7, 12), Vector2(17, 12), Vector2(17, 14), Vector2(7, 14)]],
				["g", [Vector2(4, 9), Vector2(7, 9), Vector2(7, 12), Vector2(4, 12)]],
				["i", [Vector2(5, 9), Vector2(2, 3), Vector2(4, 2), Vector2(7, 8)]]]
		"helm":
			return [["m", [Vector2(5, 13), Vector2(6, 6), Vector2(12, 3), Vector2(18, 6), Vector2(19, 13)]],
				["m", [Vector2(4, 12), Vector2(8, 12), Vector2(8, 20), Vector2(5, 19)]],
				["m", [Vector2(16, 12), Vector2(20, 12), Vector2(19, 19), Vector2(16, 20)]],
				["m", [Vector2(11, 12), Vector2(13, 12), Vector2(13, 18), Vector2(11, 18)]],
				["d", [Vector2(4, 11), Vector2(20, 11), Vector2(20, 13), Vector2(4, 13)]],
				["l", [Vector2(11, 2), Vector2(13, 2), Vector2(13, 6), Vector2(11, 6)]]]
		"harness":
			return [["m", [Vector2(5, 3), Vector2(9, 3), Vector2(20, 20), Vector2(16, 21)]],
				["m", [Vector2(15, 3), Vector2(19, 3), Vector2(8, 21), Vector2(4, 20)]],
				["s", [Vector2(10, 9), Vector2(14, 9), Vector2(14, 13), Vector2(10, 13)]],
				["k", [Vector2(11, 10), Vector2(13, 10), Vector2(13, 12), Vector2(11, 12)]]]
		"admiral":
			return [["m", [Vector2(7, 5), Vector2(17, 5), Vector2(19, 23), Vector2(13, 23), Vector2(12, 10), Vector2(11, 23), Vector2(5, 23)]],
				["m", [Vector2(7, 5), Vector2(2, 9), Vector2(1, 17), Vector2(5, 17), Vector2(7, 11)]],
				["m", [Vector2(17, 5), Vector2(22, 9), Vector2(23, 17), Vector2(19, 17), Vector2(17, 11)]],
				["b", [Vector2(10, 5), Vector2(12, 10), Vector2(12, 23), Vector2(10, 23)]],
				["b", [Vector2(14, 5), Vector2(12, 10), Vector2(12, 23), Vector2(14, 23)]],
				["b", [Vector2(2, 4), Vector2(8, 4), Vector2(8, 6), Vector2(2, 8)]],
				["b", [Vector2(16, 4), Vector2(22, 4), Vector2(22, 8), Vector2(16, 6)]],
				["b", [Vector2(1, 15), Vector2(5, 15), Vector2(5, 17), Vector2(1, 17)]],
				["b", [Vector2(19, 15), Vector2(23, 15), Vector2(23, 17), Vector2(19, 17)]]]
		"slops":
			return [["m", [Vector2(7, 3), Vector2(17, 3), Vector2(18, 11), Vector2(22, 21), Vector2(13, 21), Vector2(12, 10), Vector2(11, 21), Vector2(2, 21), Vector2(6, 11)]],
				["d", [Vector2(7, 3), Vector2(17, 3), Vector2(17, 5), Vector2(7, 5)]],
				["d", [Vector2(2, 19), Vector2(11, 19), Vector2(11, 21), Vector2(2, 21)]],
				["d", [Vector2(13, 19), Vector2(22, 19), Vector2(22, 21), Vector2(13, 21)]]]
		"cavalier_boots":
			return [["m", [Vector2(4, 7), Vector2(10, 7), Vector2(10, 16), Vector2(13, 18), Vector2(13, 21), Vector2(3, 21), Vector2(4, 16)]],
				["m", [Vector2(14, 8), Vector2(20, 8), Vector2(20, 16), Vector2(23, 18), Vector2(23, 21), Vector2(13, 21), Vector2(14, 16)]],
				["l", [Vector2(2, 3), Vector2(12, 3), Vector2(11, 8), Vector2(3, 8)]],
				["l", [Vector2(12, 4), Vector2(22, 4), Vector2(21, 9), Vector2(13, 9)]],
				["g", [Vector2(7, 16), Vector2(9, 16), Vector2(9, 18), Vector2(7, 18)]],
				["g", [Vector2(17, 16), Vector2(19, 16), Vector2(19, 18), Vector2(17, 18)]]]
		"baldric":
			return [["m", [Vector2(16, 2), Vector2(21, 3), Vector2(8, 22), Vector2(3, 21)]],
				["g", [Vector2(10, 9), Vector2(15, 9), Vector2(15, 14), Vector2(10, 14)]],
				["d", [Vector2(12, 11), Vector2(13, 11), Vector2(13, 12), Vector2(12, 12)]]]
		"spyglass":
			return [["m", [Vector2(3, 17), Vector2(17, 3), Vector2(21, 7), Vector2(7, 21)]],
				["w", [Vector2(12, 8), Vector2(16, 12), Vector2(12, 16), Vector2(8, 12)]],
				["l", [Vector2(16, 4), Vector2(17, 3), Vector2(21, 7), Vector2(20, 8)]]]
		"kettle":
			return [["m", [Vector2(6, 12), Vector2(7, 6), Vector2(12, 3), Vector2(17, 6), Vector2(18, 12)]],
				["m", [Vector2(3, 12), Vector2(21, 12), Vector2(23, 17), Vector2(1, 17)]],
				["d", [Vector2(4, 13), Vector2(20, 13), Vector2(20, 14), Vector2(4, 14)]],
				["l", [Vector2(10, 5), Vector2(12, 4), Vector2(12, 9), Vector2(10, 9)]]]
		"fez":
			return [["m", [Vector2(7, 17), Vector2(8, 5), Vector2(16, 5), Vector2(17, 17)]],
				["d", [Vector2(7, 15), Vector2(17, 15), Vector2(17, 17), Vector2(7, 17)]],
				["k", [Vector2(15, 5), Vector2(17, 5), Vector2(19, 12), Vector2(17, 12)]],
				["k", [Vector2(16, 11), Vector2(20, 11), Vector2(20, 16), Vector2(16, 16)]]]
		"headband":
			return [["m", [Vector2(3, 9), Vector2(21, 9), Vector2(21, 14), Vector2(3, 14)]],
				["d", [Vector2(18, 12), Vector2(23, 15), Vector2(21, 19), Vector2(17, 15)]],
				["l", [Vector2(5, 10), Vector2(19, 10), Vector2(19, 11), Vector2(5, 11)]]]
		"crown":
			return [["m", [Vector2(4, 20), Vector2(4, 12), Vector2(20, 12), Vector2(20, 20)]],
				["m", [Vector2(4, 12), Vector2(4, 4), Vector2(8, 9), Vector2(12, 3), Vector2(16, 9), Vector2(20, 4), Vector2(20, 12)]],
				["d", [Vector2(4, 18), Vector2(20, 18), Vector2(20, 20), Vector2(4, 20)]],
				["r", [Vector2(10, 14), Vector2(14, 14), Vector2(14, 17), Vector2(10, 17)]]]
		"coif":
			var layers := [["m", [Vector2(4, 21), Vector2(5, 8), Vector2(12, 3), Vector2(19, 8), Vector2(20, 21)]],
				["k", [Vector2(8, 20), Vector2(8, 11), Vector2(12, 8), Vector2(16, 11), Vector2(16, 20)]]]
			for y in [7, 11, 15, 19]:
				layers.append(["d", [Vector2(4, y), Vector2(20, y), Vector2(20, y + 1), Vector2(4, y + 1)]])
			return layers
		"doublet":
			var layers := [["m", [Vector2(7, 4), Vector2(17, 4), Vector2(18, 15), Vector2(20, 20), Vector2(4, 20), Vector2(6, 15)]],
				["m", [Vector2(7, 4), Vector2(3, 8), Vector2(2, 16), Vector2(6, 16), Vector2(7, 10)]],
				["m", [Vector2(17, 4), Vector2(21, 8), Vector2(22, 16), Vector2(18, 16), Vector2(17, 10)]],
				["d", [Vector2(6, 15), Vector2(18, 15), Vector2(18, 16), Vector2(6, 16)]]]
			for y in [6, 9, 12]:
				layers.append(["g", [Vector2(11, y), Vector2(13, y), Vector2(13, y + 2), Vector2(11, y + 2)]])
			return layers
		"kimono":
			return [["m", [Vector2(6, 4), Vector2(18, 4), Vector2(19, 22), Vector2(5, 22)]],
				["m", [Vector2(6, 4), Vector2(1, 9), Vector2(1, 17), Vector2(7, 16), Vector2(7, 10)]],
				["m", [Vector2(18, 4), Vector2(23, 9), Vector2(23, 17), Vector2(17, 16), Vector2(17, 10)]],
				["d", [Vector2(14, 4), Vector2(18, 4), Vector2(11, 14), Vector2(9, 14)]],
				["d", [Vector2(6, 4), Vector2(10, 4), Vector2(16, 14), Vector2(13, 14)]]]
		"jerkin":
			var layers := [["m", [Vector2(6, 4), Vector2(18, 4), Vector2(19, 12), Vector2(18, 20), Vector2(6, 20), Vector2(5, 12)]],
				["d", [Vector2(9, 4), Vector2(12, 7), Vector2(15, 4)]]]
			for y in [8, 11, 14, 17]:
				layers.append(["i", [Vector2(10, y), Vector2(14, y + 1), Vector2(14, y + 2), Vector2(10, y + 1)]])
			return layers
		"padded":
			var layers := [["m", [Vector2(6, 4), Vector2(18, 4), Vector2(19, 12), Vector2(19, 21), Vector2(5, 21), Vector2(5, 12)]],
				["d", [Vector2(9, 4), Vector2(12, 7), Vector2(15, 4)]],
				["d", [Vector2(11, 7), Vector2(13, 7), Vector2(13, 21), Vector2(11, 21)]]]
			for y in [9, 13, 17]:
				layers.append(["d", [Vector2(6, y), Vector2(18, y), Vector2(18, y + 1), Vector2(6, y + 1)]])
			return layers
		"scale":
			var layers := [["w", [Vector2(6, 4), Vector2(18, 4), Vector2(19, 12), Vector2(17, 20), Vector2(7, 20), Vector2(5, 12)]],
				["k", [Vector2(9, 4), Vector2(12, 7), Vector2(15, 4)]]]
			for row in range(4):
				var y := 7 + row * 3
				for x in ([7, 11, 15] if row % 2 == 0 else [9, 13]):
					layers.append(["m", [Vector2(x, y), Vector2(x + 3, y), Vector2(x + 3, y + 3), Vector2(x, y + 3)]])
			return layers
		"haori":
			return [["m", [Vector2(7, 4), Vector2(17, 4), Vector2(18, 17), Vector2(13, 17), Vector2(12, 8), Vector2(11, 17), Vector2(6, 17)]],
				["m", [Vector2(7, 4), Vector2(1, 8), Vector2(1, 16), Vector2(7, 16), Vector2(7, 10)]],
				["m", [Vector2(17, 4), Vector2(23, 8), Vector2(23, 16), Vector2(17, 16), Vector2(17, 10)]],
				["d", [Vector2(9, 4), Vector2(11, 4), Vector2(11, 17), Vector2(9, 17)]],
				["d", [Vector2(13, 4), Vector2(15, 4), Vector2(15, 17), Vector2(13, 17)]],
				["b", [Vector2(8, 10), Vector2(16, 10), Vector2(16, 11), Vector2(8, 11)]]]
		"duster":
			return [["m", [Vector2(7, 4), Vector2(17, 4), Vector2(19, 23), Vector2(13, 23), Vector2(12, 9), Vector2(11, 23), Vector2(5, 23)]],
				["m", [Vector2(7, 4), Vector2(2, 8), Vector2(1, 16), Vector2(5, 16), Vector2(7, 10)]],
				["m", [Vector2(17, 4), Vector2(22, 8), Vector2(23, 16), Vector2(19, 16), Vector2(17, 10)]],
				["d", [Vector2(7, 1), Vector2(17, 1), Vector2(17, 5), Vector2(12, 8), Vector2(7, 5)]]]
		"frock":
			var layers := [["m", [Vector2(7, 4), Vector2(17, 4), Vector2(19, 22), Vector2(5, 22)]],
				["m", [Vector2(7, 4), Vector2(2, 8), Vector2(1, 16), Vector2(5, 16), Vector2(7, 10)]],
				["m", [Vector2(17, 4), Vector2(22, 8), Vector2(23, 16), Vector2(19, 16), Vector2(17, 10)]],
				["d", [Vector2(9, 4), Vector2(12, 7), Vector2(15, 4)]],
				["b", [Vector2(1, 14), Vector2(5, 14), Vector2(5, 16), Vector2(1, 16)]],
				["b", [Vector2(19, 14), Vector2(23, 14), Vector2(23, 16), Vector2(19, 16)]]]
			for y in [8, 12, 16]:
				for x in [9, 13]:
					layers.append(["g", [Vector2(x, y), Vector2(x + 2, y), Vector2(x + 2, y + 2), Vector2(x, y + 2)]])
			return layers
		"bracers":
			var layers := [["m", [Vector2(3, 5), Vector2(10, 5), Vector2(11, 19), Vector2(2, 19)]],
				["m", [Vector2(14, 5), Vector2(21, 5), Vector2(22, 19), Vector2(13, 19)]]]
			for y in [7, 11, 15]:
				layers.append(["d", [Vector2(3, y), Vector2(10, y), Vector2(10, y + 1), Vector2(3, y + 1)]])
				layers.append(["d", [Vector2(14, y), Vector2(21, y), Vector2(21, y + 1), Vector2(14, y + 1)]])
			return layers
		"long_gloves":
			return [["m", [Vector2(3, 21), Vector2(3, 3), Vector2(10, 3), Vector2(11, 12), Vector2(12, 14), Vector2(11, 21)]],
				["m", [Vector2(13, 21), Vector2(13, 12), Vector2(14, 3), Vector2(21, 3), Vector2(21, 21)]],
				["d", [Vector2(3, 3), Vector2(10, 3), Vector2(10, 6), Vector2(3, 6)]],
				["d", [Vector2(14, 3), Vector2(21, 3), Vector2(21, 6), Vector2(14, 6)]],
				["d", [Vector2(3, 17), Vector2(11, 17), Vector2(11, 21), Vector2(3, 21)]],
				["d", [Vector2(13, 17), Vector2(21, 17), Vector2(21, 21), Vector2(13, 21)]]]
		"hakama":
			return [["m", [Vector2(6, 3), Vector2(18, 3), Vector2(23, 21), Vector2(13, 21), Vector2(12, 12), Vector2(11, 21), Vector2(1, 21)]],
				["d", [Vector2(6, 3), Vector2(18, 3), Vector2(18, 5), Vector2(6, 5)]],
				["d", [Vector2(7, 6), Vector2(8, 6), Vector2(5, 21), Vector2(4, 21)]],
				["d", [Vector2(16, 6), Vector2(17, 6), Vector2(20, 21), Vector2(19, 21)]]]
		"leathers":
			return [["m", [Vector2(6, 3), Vector2(18, 3), Vector2(19, 21), Vector2(13, 21), Vector2(12, 9), Vector2(11, 21), Vector2(5, 21)]],
				["d", [Vector2(6, 3), Vector2(18, 3), Vector2(18, 5), Vector2(6, 5)]],
				["l", [Vector2(6, 13), Vector2(11, 13), Vector2(11, 16), Vector2(6, 16)]],
				["l", [Vector2(13, 13), Vector2(18, 13), Vector2(18, 16), Vector2(13, 16)]]]
		"sandals":
			return [["m", [Vector2(3, 10), Vector2(10, 10), Vector2(11, 21), Vector2(2, 21)]],
				["m", [Vector2(14, 10), Vector2(21, 10), Vector2(22, 21), Vector2(13, 21)]],
				["d", [Vector2(3, 13), Vector2(10, 13), Vector2(10, 15), Vector2(3, 15)]],
				["d", [Vector2(14, 13), Vector2(21, 13), Vector2(21, 15), Vector2(14, 15)]],
				["d", [Vector2(6, 10), Vector2(8, 10), Vector2(8, 13), Vector2(6, 13)]],
				["d", [Vector2(17, 10), Vector2(19, 10), Vector2(19, 13), Vector2(17, 13)]]]
		"sabatons":
			return [["w", [Vector2(4, 8), Vector2(10, 8), Vector2(10, 16), Vector2(13, 18), Vector2(13, 21), Vector2(3, 21), Vector2(4, 16)]],
				["w", [Vector2(14, 9), Vector2(20, 9), Vector2(20, 16), Vector2(23, 18), Vector2(23, 21), Vector2(13, 21), Vector2(14, 16)]],
				["m", [Vector2(4, 15), Vector2(10, 15), Vector2(13, 18), Vector2(13, 21), Vector2(3, 21)]],
				["m", [Vector2(14, 16), Vector2(20, 16), Vector2(23, 18), Vector2(23, 21), Vector2(13, 21)]],
				["l", [Vector2(4, 10), Vector2(10, 10), Vector2(10, 12), Vector2(4, 12)]],
				["l", [Vector2(14, 11), Vector2(20, 11), Vector2(20, 13), Vector2(14, 13)]]]
		"wide_belt":
			return [["m", [Vector2(1, 6), Vector2(23, 6), Vector2(23, 17), Vector2(1, 17)]],
				["d", [Vector2(1, 11), Vector2(23, 11), Vector2(23, 12), Vector2(1, 12)]],
				["g", [Vector2(8, 6), Vector2(16, 6), Vector2(16, 11), Vector2(8, 11)]],
				["g", [Vector2(8, 12), Vector2(16, 12), Vector2(16, 17), Vector2(8, 17)]],
				["d", [Vector2(10, 7), Vector2(14, 7), Vector2(14, 10), Vector2(10, 10)]],
				["d", [Vector2(10, 13), Vector2(14, 13), Vector2(14, 16), Vector2(10, 16)]]]
		"necklace":
			var layers := [["k", [Vector2(2, 4), Vector2(4, 4), Vector2(12, 12), Vector2(20, 4), Vector2(22, 4), Vector2(12, 14)]]]
			for i in range(5):
				var x := 6 + i * 3
				var y := 8 + (2 if i in [1, 3] else (4 if i == 2 else 0))
				layers.append(["m", [Vector2(x, y), Vector2(x + 2, y), Vector2(x + 1, y + 6)]])
			return layers
		"shark_tooth":
			return [["k", [Vector2(2, 3), Vector2(4, 3), Vector2(12, 9), Vector2(20, 3), Vector2(22, 3), Vector2(12, 11)]],
				["w", [Vector2(10, 9), Vector2(14, 9), Vector2(14, 12), Vector2(10, 12)]],
				["m", [Vector2(7, 12), Vector2(17, 12), Vector2(15, 16), Vector2(12, 22), Vector2(9, 16)]],
				["d", [Vector2(12, 13), Vector2(17, 12), Vector2(15, 16), Vector2(12, 22)]]]
		"goggles":
			return [["m", [Vector2(1, 9), Vector2(23, 9), Vector2(23, 13), Vector2(1, 13)]],
				["g", [Vector2(3, 7), Vector2(11, 7), Vector2(11, 15), Vector2(3, 15)]],
				["g", [Vector2(13, 7), Vector2(21, 7), Vector2(21, 15), Vector2(13, 15)]],
				["s", [Vector2(5, 9), Vector2(9, 9), Vector2(9, 13), Vector2(5, 13)]],
				["s", [Vector2(15, 9), Vector2(19, 9), Vector2(19, 13), Vector2(15, 13)]]]
		"mantle":
			var layers := [["m", [Vector2(5, 5), Vector2(19, 5), Vector2(23, 16), Vector2(1, 16)]]]
			for i in range(6):
				var x := 1 + i * 4
				layers.append(["m", [Vector2(x, 16), Vector2(x + 4, 16), Vector2(x + 2, 20)]])
			layers.append(["d", [Vector2(5, 5), Vector2(19, 5), Vector2(19, 7), Vector2(5, 7)]])
			layers.append(["g", [Vector2(10, 5), Vector2(14, 5), Vector2(14, 8), Vector2(10, 8)]])
			return layers
		"tricorn":
			return [["m", [Vector2(2, 14), Vector2(7, 10), Vector2(12, 6), Vector2(17, 10), Vector2(22, 14), Vector2(17, 16), Vector2(12, 14), Vector2(7, 16)]],
				["d", [Vector2(8, 13), Vector2(12, 8), Vector2(16, 13), Vector2(12, 12)]]]
		"bicorne":
			return [["m", [Vector2(1, 15), Vector2(5, 10), Vector2(12, 6), Vector2(19, 10), Vector2(23, 15), Vector2(12, 16)]],
				["g", [Vector2(15, 10), Vector2(17, 10), Vector2(17, 12), Vector2(15, 12)]]]
		"straw":
			return [["m", [Vector2(1, 15), Vector2(6, 12), Vector2(18, 12), Vector2(23, 15), Vector2(18, 18), Vector2(6, 18)]],
				["l", [Vector2(7, 13), Vector2(8, 7), Vector2(16, 7), Vector2(17, 13)]],
				["d", [Vector2(7, 12), Vector2(17, 12), Vector2(17, 13), Vector2(7, 13)]]]
		"cap":
			return [["m", [Vector2(5, 14), Vector2(6, 8), Vector2(12, 5), Vector2(18, 8), Vector2(19, 14)]],
				["d", [Vector2(3, 14), Vector2(21, 14), Vector2(21, 16), Vector2(3, 16)]]]
		"knit":
			return [["m", [Vector2(5, 16), Vector2(6, 8), Vector2(12, 4), Vector2(18, 8), Vector2(19, 16)]],
				["d", [Vector2(5, 14), Vector2(19, 14), Vector2(19, 18), Vector2(5, 18)]],
				["l", [Vector2(11, 2), Vector2(13, 2), Vector2(13, 4), Vector2(11, 4)]]]
		"bandana":
			return [["m", [Vector2(4, 15), Vector2(5, 9), Vector2(12, 5), Vector2(19, 9), Vector2(20, 15)]],
				["d", [Vector2(18, 13), Vector2(23, 17), Vector2(21, 20), Vector2(17, 15)]],
				["l", [Vector2(8, 10), Vector2(9, 10), Vector2(9, 11), Vector2(8, 11)]]]
		"hood":
			return [["m", [Vector2(4, 20), Vector2(5, 8), Vector2(12, 3), Vector2(19, 8), Vector2(20, 20)]],
				["k", [Vector2(8, 19), Vector2(8, 11), Vector2(12, 8), Vector2(16, 11), Vector2(16, 19)]]]
		"shirt", "tunic", "blouse", "striped":
			var ln := 20 if kind == "tunic" else 17
			var sl := str(look.get("sleeves", "long"))
			var sleeve_end := 16 if sl == "long" else (11 if sl == "short" else 8)
			var arms := 4 if kind == "blouse" else 3
			var layers := [["m", [Vector2(7, 5), Vector2(17, 5), Vector2(18, ln), Vector2(6, ln)]]]
			if sl != "none":
				layers.append(["m", [Vector2(7, 5), Vector2(3, 8), Vector2(arms - 1, sleeve_end), Vector2(arms + 3, sleeve_end), Vector2(7, 10)]])
				layers.append(["m", [Vector2(17, 5), Vector2(21, 8), Vector2(25 - arms, sleeve_end), Vector2(21 - arms, sleeve_end), Vector2(17, 10)]])
			if kind == "striped":
				for y in [7, 10, 13, 16]:
					layers.append(["k", [Vector2(7, y), Vector2(17, y), Vector2(17, y + 1), Vector2(7, y + 1)]])
			else:
				layers.append(["d", [Vector2(10, 5), Vector2(14, 5), Vector2(12, 9)]])
			return layers
		"vest":
			return [["m", [Vector2(6, 4), Vector2(11, 4), Vector2(12, 12), Vector2(12, 19), Vector2(6, 19)]],
				["m", [Vector2(13, 4), Vector2(18, 4), Vector2(18, 19), Vector2(12, 19), Vector2(12, 12)]],
				["g", [Vector2(10, 13), Vector2(11, 13), Vector2(11, 14), Vector2(10, 14)]],
				["g", [Vector2(10, 16), Vector2(11, 16), Vector2(11, 17), Vector2(10, 17)]]]
		"corset":
			return [["m", [Vector2(6, 4), Vector2(18, 4), Vector2(16, 12), Vector2(18, 20), Vector2(6, 20), Vector2(8, 12)]],
				["k", [Vector2(11, 6), Vector2(13, 6), Vector2(13, 18), Vector2(11, 18)]]]
		"jacket", "longcoat", "captain":
			var bot := 17 if kind == "jacket" else 22
			var layers := [["m", [Vector2(7, 4), Vector2(17, 4), Vector2(19, bot), Vector2(13, bot), Vector2(12, 9), Vector2(11, bot), Vector2(5, bot)]],
				["m", [Vector2(7, 4), Vector2(2, 8), Vector2(1, 16), Vector2(5, 16), Vector2(7, 10)]],
				["m", [Vector2(17, 4), Vector2(22, 8), Vector2(23, 16), Vector2(19, 16), Vector2(17, 10)]],
				["d", [Vector2(9, 4), Vector2(12, 9), Vector2(15, 4)]]]
			if kind == "captain":
				layers.append(["b", [Vector2(1, 14), Vector2(5, 14), Vector2(5, 16), Vector2(1, 16)]])
				layers.append(["b", [Vector2(19, 14), Vector2(23, 14), Vector2(23, 16), Vector2(19, 16)]])
				layers.append(["b", [Vector2(5, 4), Vector2(9, 4), Vector2(8, 6), Vector2(4, 6)]])
				layers.append(["b", [Vector2(15, 4), Vector2(19, 4), Vector2(20, 6), Vector2(16, 6)]])
			return layers
		"gloves":
			return [["m", [Vector2(4, 20), Vector2(4, 10), Vector2(6, 6), Vector2(10, 6), Vector2(11, 12), Vector2(12, 14), Vector2(11, 20)]],
				["m", [Vector2(13, 20), Vector2(13, 12), Vector2(14, 7), Vector2(18, 7), Vector2(20, 11), Vector2(20, 20)]],
				["d", [Vector2(4, 17), Vector2(11, 17), Vector2(11, 20), Vector2(4, 20)]],
				["d", [Vector2(13, 17), Vector2(20, 17), Vector2(20, 20), Vector2(13, 20)]]]
		"trousers", "breeches", "shorts":
			var bot := 21 if kind == "trousers" else (16 if kind == "breeches" else 13)
			var layers := [["m", [Vector2(6, 3), Vector2(18, 3), Vector2(19, bot), Vector2(13, bot), Vector2(12, 9), Vector2(11, bot), Vector2(5, bot)]],
				["d", [Vector2(6, 3), Vector2(18, 3), Vector2(18, 5), Vector2(6, 5)]]]
			if kind == "breeches":
				layers.append(["l", [Vector2(5, 16), Vector2(11, 16), Vector2(11, 21), Vector2(6, 21)]])
				layers.append(["l", [Vector2(13, 16), Vector2(19, 16), Vector2(18, 21), Vector2(13, 21)]])
			return layers
		"skirt":
			return [["m", [Vector2(8, 3), Vector2(16, 3), Vector2(21, 21), Vector2(3, 21)]],
				["d", [Vector2(8, 3), Vector2(16, 3), Vector2(16, 5), Vector2(8, 5)]]]
		"boots", "tall_boots", "shoes":
			var top := 4 if kind == "tall_boots" else (10 if kind == "boots" else 14)
			var layers := [["m", [Vector2(4, top), Vector2(10, top), Vector2(10, 16), Vector2(13, 18), Vector2(13, 21), Vector2(3, 21), Vector2(4, 16)]],
				["m", [Vector2(14, top + 1), Vector2(20, top + 1), Vector2(20, 16), Vector2(23, 18), Vector2(23, 21), Vector2(13, 21), Vector2(14, 16)]],
				["d", [Vector2(3, 20), Vector2(13, 20), Vector2(13, 21), Vector2(3, 21)]],
				["d", [Vector2(13, 20), Vector2(23, 20), Vector2(23, 21), Vector2(13, 21)]]]
			if kind == "tall_boots":
				layers.append(["l", [Vector2(3, 4), Vector2(11, 4), Vector2(11, 7), Vector2(3, 7)]])
				layers.append(["l", [Vector2(13, 5), Vector2(21, 5), Vector2(21, 8), Vector2(13, 8)]])
			if kind == "shoes":
				layers.append(["g", [Vector2(7, 15), Vector2(9, 15), Vector2(9, 17), Vector2(7, 17)]])
				layers.append(["g", [Vector2(17, 16), Vector2(19, 16), Vector2(19, 18), Vector2(17, 18)]])
			return layers
		"belt":
			return [["m", [Vector2(1, 9), Vector2(23, 9), Vector2(23, 14), Vector2(1, 14)]],
				["g", [Vector2(9, 8), Vector2(15, 8), Vector2(15, 15), Vector2(9, 15)]],
				["d", [Vector2(11, 10), Vector2(13, 10), Vector2(13, 13), Vector2(11, 13)]]]
		"sash":
			return [["m", [Vector2(1, 8), Vector2(23, 8), Vector2(23, 13), Vector2(1, 13)]],
				["m", [Vector2(15, 11), Vector2(19, 11), Vector2(21, 22), Vector2(17, 22)]],
				["d", [Vector2(14, 8), Vector2(19, 8), Vector2(19, 13), Vector2(14, 13)]]]
		"belt_sash":
			return [["b", [Vector2(1, 7), Vector2(23, 7), Vector2(23, 15), Vector2(1, 15)]],
				["b", [Vector2(15, 13), Vector2(19, 13), Vector2(21, 22), Vector2(17, 22)]],
				["w", [Vector2(1, 9), Vector2(23, 9), Vector2(23, 12), Vector2(1, 12)]],
				["g", [Vector2(9, 8), Vector2(13, 8), Vector2(13, 13), Vector2(9, 13)]]]
		"scarf":
			return [["m", [Vector2(4, 6), Vector2(20, 6), Vector2(20, 11), Vector2(4, 11)]],
				["m", [Vector2(14, 9), Vector2(18, 9), Vector2(19, 21), Vector2(15, 21)]],
				["d", [Vector2(15, 19), Vector2(19, 19), Vector2(19, 21), Vector2(15, 21)]]]
		"pauldron_r":
			# (1.30.3) the right one: the left's plate mirrored
			var out := []
			for layer in _shapes("pauldron", look):
				var pts := []
				for p in layer[1]:
					pts.append(Vector2(24 - p.x, p.y))
				out.append([layer[0], pts])
			return out
		"pauldrons":
			# the pair: two smaller plates side by side
			var pair := []
			for side in [-1.0, 1.0]:
				for layer in _shapes("pauldron", look):
					var pts := []
					for p in layer[1]:
						var q := Vector2(12 + (p.x - 12) * 0.55, 3 + p.y * 0.8)
						pts.append(Vector2(12 + side * 5.5 + (q.x - 12) * side, q.y + 2))
					pair.append([layer[0], pts])
			return pair
		"pauldron":
			return [["s", [Vector2(3, 16), Vector2(5, 8), Vector2(12, 4), Vector2(19, 8), Vector2(21, 16), Vector2(12, 13)]],
				["k", [Vector2(11, 7), Vector2(13, 7), Vector2(13, 9), Vector2(11, 9)]],
				["l", [Vector2(5, 15), Vector2(6, 10), Vector2(8, 9), Vector2(7, 14)]]]
		"earring":
			return [["g", [Vector2(8, 8), Vector2(12, 4), Vector2(16, 8), Vector2(17, 13), Vector2(12, 20), Vector2(7, 13)]],
				["k", [Vector2(10, 9), Vector2(12, 7), Vector2(14, 9), Vector2(14, 13), Vector2(12, 17), Vector2(10, 13)]]]
		"eyepatch":
			return [["w", [Vector2(1, 8), Vector2(23, 5), Vector2(23, 7), Vector2(1, 10)]],
				["m", [Vector2(7, 9), Vector2(16, 8), Vector2(16, 14), Vector2(12, 17), Vector2(8, 14)]]]
		"pouch":
			return [["m", [Vector2(5, 8), Vector2(19, 8), Vector2(19, 19), Vector2(5, 19)]],
				["d", [Vector2(5, 6), Vector2(19, 6), Vector2(19, 12), Vector2(12, 14), Vector2(5, 12)]],
				["g", [Vector2(11, 11), Vector2(13, 11), Vector2(13, 13), Vector2(11, 13)]]]
		"apron":
			return [["m", [Vector2(7, 4), Vector2(17, 4), Vector2(17, 10), Vector2(20, 11), Vector2(19, 22), Vector2(5, 22), Vector2(4, 11), Vector2(7, 10)]],
				["d", [Vector2(9, 14), Vector2(15, 14), Vector2(15, 17), Vector2(9, 17)]]]
		"cavalier":
			return [["m", [Vector2(1, 15), Vector2(5, 12), Vector2(19, 12), Vector2(23, 15), Vector2(19, 17), Vector2(5, 17)]],
				["m", [Vector2(7, 13), Vector2(8, 6), Vector2(16, 6), Vector2(17, 13)]],
				["d", [Vector2(7, 11), Vector2(17, 11), Vector2(17, 13), Vector2(7, 13)]],
				["l", [Vector2(14, 7), Vector2(19, 2), Vector2(22, 3), Vector2(17, 9)]]]
		"morion":
			return [["m", [Vector2(1, 15), Vector2(4, 11), Vector2(20, 11), Vector2(23, 15), Vector2(20, 13), Vector2(4, 13)]],
				["m", [Vector2(6, 12), Vector2(7, 6), Vector2(12, 4), Vector2(17, 6), Vector2(18, 12)]],
				["l", [Vector2(11, 1), Vector2(13, 1), Vector2(13, 6), Vector2(11, 6)]],
				["g", [Vector2(17, 10), Vector2(19, 10), Vector2(19, 12), Vector2(17, 12)]]]
		"turban":
			return [["m", [Vector2(4, 16), Vector2(4, 9), Vector2(8, 4), Vector2(16, 4), Vector2(20, 9), Vector2(20, 16)]],
				["d", [Vector2(4, 12), Vector2(20, 9), Vector2(20, 11), Vector2(4, 14)]],
				["d", [Vector2(5, 7), Vector2(19, 11), Vector2(19, 13), Vector2(5, 9)]],
				["g", [Vector2(11, 9), Vector2(13, 9), Vector2(13, 12), Vector2(11, 12)]]]
		"cuirass", "brigandine":
			var layers := [["m", [Vector2(6, 4), Vector2(18, 4), Vector2(19, 12), Vector2(17, 19), Vector2(7, 19), Vector2(5, 12)]],
				["d", [Vector2(7, 19), Vector2(17, 19), Vector2(17, 22), Vector2(7, 22)]],
				["d", [Vector2(9, 4), Vector2(12, 7), Vector2(15, 4)]]]
			if kind == "cuirass":
				layers.append(["l", [Vector2(11, 7), Vector2(13, 7), Vector2(13, 18), Vector2(11, 18)]])
			else:
				for y in [8, 12, 16]:
					for x in [8, 12, 16]:
						layers.append(["s", [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]])
			return layers
		"mail":
			var layers := [["m", [Vector2(7, 4), Vector2(17, 4), Vector2(21, 9), Vector2(19, 12), Vector2(19, 22), Vector2(5, 22), Vector2(5, 12), Vector2(3, 9)]],
				["d", [Vector2(9, 4), Vector2(12, 7), Vector2(15, 4)]]]
			for y in [10, 14, 18]:
				layers.append(["d", [Vector2(6, y), Vector2(18, y), Vector2(18, y + 1), Vector2(6, y + 1)]])
			return layers
		"greatcoat":
			return [["m", [Vector2(7, 4), Vector2(17, 4), Vector2(19, 22), Vector2(13, 22), Vector2(12, 9), Vector2(11, 22), Vector2(5, 22)]],
				["m", [Vector2(7, 4), Vector2(2, 8), Vector2(1, 16), Vector2(5, 16), Vector2(7, 10)]],
				["m", [Vector2(17, 4), Vector2(22, 8), Vector2(23, 16), Vector2(19, 16), Vector2(17, 10)]],
				["d", [Vector2(5, 4), Vector2(19, 4), Vector2(23, 10), Vector2(1, 10)]],
				["b", [Vector2(9, 4), Vector2(12, 8), Vector2(15, 4)]]]
		"gauntlets":
			return [["m", [Vector2(3, 21), Vector2(3, 8), Vector2(6, 5), Vector2(10, 5), Vector2(11, 11), Vector2(11, 21)]],
				["m", [Vector2(13, 21), Vector2(13, 11), Vector2(14, 6), Vector2(18, 6), Vector2(21, 10), Vector2(21, 21)]],
				["l", [Vector2(3, 14), Vector2(11, 14), Vector2(11, 16), Vector2(3, 16)]],
				["l", [Vector2(13, 14), Vector2(21, 14), Vector2(21, 16), Vector2(13, 16)]]]
		"greaves":
			return [["w", [Vector2(4, 4), Vector2(10, 4), Vector2(10, 16), Vector2(13, 18), Vector2(13, 21), Vector2(3, 21), Vector2(4, 16)]],
				["w", [Vector2(14, 5), Vector2(20, 5), Vector2(20, 16), Vector2(23, 18), Vector2(23, 21), Vector2(13, 21), Vector2(14, 16)]],
				["m", [Vector2(4, 4), Vector2(9, 4), Vector2(9, 15), Vector2(4, 15)]],
				["m", [Vector2(14, 5), Vector2(19, 5), Vector2(19, 15), Vector2(14, 15)]],
				["l", [Vector2(5, 3), Vector2(8, 3), Vector2(8, 6), Vector2(5, 6)]],
				["l", [Vector2(15, 4), Vector2(18, 4), Vector2(18, 7), Vector2(15, 7)]]]
		"cape":
			return [["m", [Vector2(7, 3), Vector2(17, 3), Vector2(21, 22), Vector2(3, 22)]],
				["d", [Vector2(7, 3), Vector2(17, 3), Vector2(17, 5), Vector2(7, 5)]],
				["g", [Vector2(6, 3), Vector2(8, 3), Vector2(8, 5), Vector2(6, 5)]],
				["g", [Vector2(16, 3), Vector2(18, 3), Vector2(18, 5), Vector2(16, 5)]]]
		"cloak":
			var layers := [["m", [Vector2(7, 5), Vector2(17, 5), Vector2(23, 20), Vector2(1, 20)]],
				["l", [Vector2(5, 4), Vector2(19, 4), Vector2(21, 9), Vector2(3, 9)]]]
			for i in range(5):
				var x := 7 + i * 2.5
				layers.append(["d", [Vector2(x, 2), Vector2(x + 1.5, 2), Vector2(x + 1.5, 5), Vector2(x, 5)]])
			layers.append(["d", [Vector2(1, 19), Vector2(23, 19), Vector2(23, 22), Vector2(1, 22)]])
			layers.append(["g", [Vector2(11, 6), Vector2(13, 6), Vector2(13, 8), Vector2(11, 8)]])
			return layers
		"bandolier":
			return [["m", [Vector2(4, 2), Vector2(8, 2), Vector2(21, 20), Vector2(17, 22)]],
				["g", [Vector2(8, 7), Vector2(10, 7), Vector2(10, 9), Vector2(8, 9)]],
				["g", [Vector2(11, 11), Vector2(13, 11), Vector2(13, 13), Vector2(11, 13)]],
				["g", [Vector2(14, 15), Vector2(16, 15), Vector2(16, 17), Vector2(14, 17)]]]
		# (1.29) the face slot and the wraps
		"mask", "iron_mask", "oni":
			var face := [Vector2(5, 4), Vector2(19, 4), Vector2(20, 11), Vector2(17, 18), Vector2(12, 21), Vector2(7, 18), Vector2(4, 11)]
			var layers := [["m", face], ["d", [Vector2(11, 9), Vector2(13, 9), Vector2(14, 15), Vector2(10, 15)]]]
			if kind == "iron_mask":
				layers.append(["k", [Vector2(5, 9), Vector2(19, 9), Vector2(19, 11), Vector2(5, 11)]])
				for p in [Vector2(6, 5), Vector2(17, 5), Vector2(6, 15), Vector2(17, 15)]:
					layers.append(["l", [p, p + Vector2(1, 0), p + Vector2(1, 1), p + Vector2(0, 1)]])
			else:
				layers.append(["k", [Vector2(6, 9), Vector2(10, 8), Vector2(10, 10), Vector2(6, 11)]])
				layers.append(["k", [Vector2(14, 8), Vector2(18, 9), Vector2(18, 11), Vector2(14, 10)]])
			if kind == "oni":
				layers.append(["i", [Vector2(4, 6), Vector2(1, 0), Vector2(7, 4)]])
				layers.append(["i", [Vector2(20, 6), Vector2(23, 0), Vector2(17, 4)]])
				layers.append(["k", [Vector2(9, 16), Vector2(15, 16), Vector2(15, 18), Vector2(9, 18)]])
				layers.append(["i", [Vector2(9, 16), Vector2(10, 16), Vector2(10, 19), Vector2(9, 19)]])
				layers.append(["i", [Vector2(14, 16), Vector2(15, 16), Vector2(15, 19), Vector2(14, 19)]])
			return layers
		"half_mask":
			return [["k", [Vector2(1, 11), Vector2(4, 10), Vector2(4, 12), Vector2(1, 13)]],
				["k", [Vector2(23, 11), Vector2(20, 10), Vector2(20, 12), Vector2(23, 13)]],
				["m", [Vector2(3, 9), Vector2(10, 7), Vector2(12, 9), Vector2(14, 7), Vector2(21, 9), Vector2(20, 15), Vector2(14, 15), Vector2(12, 13), Vector2(10, 15), Vector2(4, 15)]],
				["k", [Vector2(6, 10), Vector2(10, 10), Vector2(10, 12), Vector2(6, 12)]],
				["k", [Vector2(14, 10), Vector2(18, 10), Vector2(18, 12), Vector2(14, 12)]]]
		"kerchief":
			return [["m", [Vector2(2, 6), Vector2(22, 6), Vector2(20, 12), Vector2(12, 22), Vector2(4, 12)]],
				["d", [Vector2(2, 6), Vector2(22, 6), Vector2(22, 8), Vector2(2, 8)]],
				["d", [Vector2(11, 12), Vector2(13, 12), Vector2(12, 19)]]]
		"mouth_guard":
			return [["m", [Vector2(3, 7), Vector2(21, 7), Vector2(19, 15), Vector2(12, 18), Vector2(5, 15)]],
				["d", [Vector2(1, 8), Vector2(4, 8), Vector2(4, 10), Vector2(1, 10)]],
				["d", [Vector2(20, 8), Vector2(23, 8), Vector2(23, 10), Vector2(20, 10)]],
				["g", [Vector2(7, 10), Vector2(9, 10), Vector2(9, 12), Vector2(7, 12)]],
				["g", [Vector2(15, 10), Vector2(17, 10), Vector2(17, 12), Vector2(15, 12)]]]
		"bandage", "eye_wrap":
			var layers := [["m", [Vector2(3, 8), Vector2(21, 8), Vector2(21, 13), Vector2(3, 13)]],
				["d", [Vector2(3, 10), Vector2(21, 10), Vector2(21, 11), Vector2(3, 11)]],
				["m", [Vector2(17, 12), Vector2(20, 12), Vector2(22, 21), Vector2(19, 21)]],
				["m", [Vector2(19, 12), Vector2(21, 12), Vector2(17, 20), Vector2(15, 19)]]]
			if kind == "eye_wrap":
				layers.append(["m", [Vector2(3, 4), Vector2(7, 3), Vector2(16, 13), Vector2(12, 15)]])
			layers.append(["r", [Vector2(8, 9), Vector2(10, 9), Vector2(10, 11), Vector2(8, 11)]])
			return layers
		"arm_wraps":
			var layers := [["m", [Vector2(3, 21), Vector2(3, 7), Vector2(6, 4), Vector2(10, 4), Vector2(11, 9), Vector2(11, 21)]],
				["m", [Vector2(13, 21), Vector2(13, 9), Vector2(14, 4), Vector2(18, 4), Vector2(21, 7), Vector2(21, 21)]]]
			for y in [8, 12, 16]:
				layers.append(["d", [Vector2(3, y + 1), Vector2(11, y), Vector2(11, y + 1), Vector2(3, y + 2)]])
				layers.append(["d", [Vector2(13, y), Vector2(21, y + 1), Vector2(21, y + 2), Vector2(13, y + 1)]])
			return layers
		"foot_wraps":
			var layers := [["i", [Vector2(4, 4), Vector2(10, 4), Vector2(10, 17), Vector2(13, 19), Vector2(13, 21), Vector2(3, 21), Vector2(4, 17)]],
				["i", [Vector2(14, 5), Vector2(20, 5), Vector2(20, 17), Vector2(23, 19), Vector2(23, 21), Vector2(13, 21), Vector2(14, 17)]],
				["m", [Vector2(4, 9), Vector2(10, 9), Vector2(10, 18), Vector2(12, 19), Vector2(12, 20), Vector2(4, 20)]],
				["m", [Vector2(14, 10), Vector2(20, 10), Vector2(20, 18), Vector2(22, 19), Vector2(22, 20), Vector2(14, 20)]]]
			for y in [11, 14, 17]:
				layers.append(["d", [Vector2(4, y), Vector2(10, y + 1), Vector2(10, y + 2), Vector2(4, y + 1)]])
				layers.append(["d", [Vector2(14, y + 1), Vector2(20, y), Vector2(20, y + 1), Vector2(14, y + 2)]])
			return layers
		"backpack":
			return [["m", [Vector2(6, 5), Vector2(18, 5), Vector2(19, 18), Vector2(5, 18)]],
				["d", [Vector2(5, 3), Vector2(19, 3), Vector2(19, 6), Vector2(5, 6)]],
				["d", [Vector2(7, 6), Vector2(17, 6), Vector2(17, 11), Vector2(7, 11)]],
				["g", [Vector2(9, 10), Vector2(11, 10), Vector2(11, 12), Vector2(9, 12)]],
				["g", [Vector2(13, 10), Vector2(15, 10), Vector2(15, 12), Vector2(13, 12)]],
				["r", [Vector2(3, 18), Vector2(21, 18), Vector2(21, 22), Vector2(3, 22)]],
				["s", [Vector2(20, 9), Vector2(23, 9), Vector2(23, 13), Vector2(20, 13)]],
				["i", [Vector2(1, 9), Vector2(4, 9), Vector2(4, 14), Vector2(1, 14)]]]
		"parachute":
			return [["m", [Vector2(7, 3), Vector2(17, 3), Vector2(22, 10), Vector2(21, 18), Vector2(19, 21), Vector2(13, 21), Vector2(12, 11),
					Vector2(11, 21), Vector2(5, 21), Vector2(3, 18), Vector2(2, 10)]],
				["d", [Vector2(7, 3), Vector2(17, 3), Vector2(17, 5), Vector2(7, 5)]],
				["d", [Vector2(5, 19), Vector2(11, 19), Vector2(11, 21), Vector2(5, 21)]],
				["d", [Vector2(13, 19), Vector2(19, 19), Vector2(19, 21), Vector2(13, 21)]],
				["l", [Vector2(5, 9), Vector2(6, 9), Vector2(7, 16), Vector2(6, 16)]]]
		"jester":
			return [["m", [Vector2(6, 21), Vector2(6, 15), Vector2(9, 11), Vector2(12, 11), Vector2(12, 21)]],
				["b", [Vector2(12, 21), Vector2(12, 11), Vector2(15, 11), Vector2(18, 15), Vector2(18, 21)]],
				["m", [Vector2(8, 13), Vector2(4, 7), Vector2(1, 11), Vector2(3, 8), Vector2(7, 9), Vector2(10, 12)]],
				["b", [Vector2(16, 13), Vector2(20, 7), Vector2(23, 11), Vector2(21, 8), Vector2(17, 9), Vector2(14, 12)]],
				["m", [Vector2(11, 11), Vector2(12, 3), Vector2(13, 11)]],
				["g", [Vector2(0, 11), Vector2(2, 11), Vector2(2, 13), Vector2(0, 13)]],
				["g", [Vector2(22, 11), Vector2(24, 11), Vector2(24, 13), Vector2(22, 13)]],
				["g", [Vector2(11, 1), Vector2(13, 1), Vector2(13, 3), Vector2(11, 3)]]]
		"motley":
			return [["m", [Vector2(7, 4), Vector2(12, 4), Vector2(12, 20), Vector2(6, 20), Vector2(6, 11), Vector2(3, 12), Vector2(1, 9)]],
				["b", [Vector2(12, 4), Vector2(17, 4), Vector2(23, 9), Vector2(21, 12), Vector2(18, 11), Vector2(18, 20), Vector2(12, 20)]],
				["b", [Vector2(6, 20), Vector2(9, 20), Vector2(7.5, 23)]],
				["m", [Vector2(15, 20), Vector2(18, 20), Vector2(16.5, 23)]],
				["g", [Vector2(9, 6), Vector2(10, 6), Vector2(10, 7), Vector2(9, 7)]],
				["g", [Vector2(14, 6), Vector2(15, 6), Vector2(15, 7), Vector2(14, 7)]]]
		"motley_hose":
			return [["b", [Vector2(7, 3), Vector2(12, 3), Vector2(12, 21), Vector2(7, 21)]],
				["m", [Vector2(12, 3), Vector2(17, 3), Vector2(17, 21), Vector2(12, 21)]],
				["d", [Vector2(7, 3), Vector2(17, 3), Vector2(17, 5), Vector2(7, 5)]]]
		"curled":
			return [["m", [Vector2(2, 20), Vector2(4, 14), Vector2(10, 14), Vector2(12, 18), Vector2(19, 18), Vector2(22, 14), Vector2(19, 11), Vector2(17, 13),
					Vector2(19, 14), Vector2(18, 16), Vector2(13, 21), Vector2(2, 21)]],
				["b", [Vector2(4, 14), Vector2(10, 14), Vector2(10, 16), Vector2(4, 16)]],
				["g", [Vector2(16, 11), Vector2(18, 11), Vector2(18, 13), Vector2(16, 13)]]]
	return [["m", [Vector2(5, 5), Vector2(19, 5), Vector2(19, 19), Vector2(5, 19)]]]


## Even-odd polygon fill sampled at pixel centers, shaded lighter at the top.
## One layer, ink and cel like the painted icons (gen_item_icons.py): its flat colour, a hard shadow along its lower
## right, a light edge up and left, ink where it lies over what's already drawn. `plain`: a fold or a band of the
## garment's own cloth (codes d and l), flat and uninked.
static func _fill(img: Image, poly: Array, col: Color, plain := false) -> void:
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(p * K)
	var miny := SIZE
	var maxy := 0
	for p in pts:
		miny = mini(miny, int(floor(p.y)))
		maxy = maxi(maxy, int(ceil(p.y)))
	var mask := {}
	for y in range(maxi(miny, 0), mini(maxy + 1, SIZE)):
		for x in range(SIZE):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				mask[Vector2i(x, y)] = true
	var deep := 2 if mask.size() > 90 else 1
	var dark := Color(col.r * 0.62, col.g * 0.6, col.b * 0.7)
	var light := col.lerp(Color.WHITE, 0.35)
	for q in mask.keys():
		var c := col
		if not plain:
			if not mask.has(q + Vector2i(-1, -1)):
				c = light
			elif not mask.has(q + Vector2i(deep, deep)):
				c = dark
		img.set_pixelv(q, c)
	if plain:
		return
	for q in mask.keys():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var e: Vector2i = q + d
			if not mask.has(e) and e.x >= 0 and e.y >= 0 and e.x < SIZE and e.y < SIZE and img.get_pixelv(e).a > 0.0:
				img.set_pixelv(e, OUTLINE)


## A tailor's skin over the filled shape (Gear.PATTERN_NAMES): stripes, a check, a brocade lattice, a patch.
static func _pattern(img: Image, pat: String) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			var c := img.get_pixel(x, y)
			if c.a == 0.0 or c.is_equal_approx(OUTLINE):
				continue
			var k := 1.0
			match pat:
				"stripes": k = 0.62 if y % 5 == 0 else 1.0
				"check": k = (0.75 if x % 8 < 2 else 1.0) * (0.75 if y % 8 < 2 else 1.0)
				"brocade": k = 1.35 if (x + y) % 8 == 0 or (x - y + 32) % 8 == 0 else 0.9
				"patched": k = 0.7 if x in range(17, 24) and y in range(15, 22) else 1.0
			img.set_pixel(x, y, Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), 1.0))


static func _outline(img: Image) -> void:
	var edge: Array = []
	for y in range(SIZE):
		for x in range(SIZE):
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE and img.get_pixel(q.x, q.y).a > 0.0:
					edge.append(Vector2i(x, y))
					break
	for e in edge:
		img.set_pixelv(e, OUTLINE)
