class_name GearIcons
extends RefCounted
## 24x24 pixel-art icons for gear, drawn at runtime in the item's own colors
## (so a navy long coat gets a navy icon). Same style as the generated item
## icons: flat fills, a little top-down shading, 1px dark outline.

const SIZE := 24
const OUTLINE := Color(0.08, 0.055, 0.04)
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
	var key := "%s|%s|%s" % [it.icon_kind, main.to_html(), second.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for layer in _shapes(it.icon_kind, it.look):
		var col: Color = main
		match str(layer[0]):
			"b": col = second
			"d": col = main.darkened(0.3)
			"l": col = main.lightened(0.25)
			"g": col = GOLD
			"s": col = STEEL
			"k": col = Color(0.08, 0.07, 0.07)
			"w": col = LEATHER
		_fill(img, layer[1], col)
	_outline(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _main_color(it: ItemData) -> Color:
	var lk := it.look
	for k in ["hat_color", "top_color", "vest_color", "coat_color", "gloves_color", "legs_color", "feet_color", "scarf_color", "apron_color"]:
		if lk.has(k) and lk[k] is Color:
			return lk[k]
	if lk.has("belt"):
		return lk.get("sash_color", Color.RED) if str(lk["belt"]) == "sash" else lk.get("belt_color", LEATHER)
	match it.icon_kind:
		"earring": return GOLD
		"eyepatch": return Color(0.12, 0.1, 0.09)
		"pauldron": return STEEL
		"pouch": return LEATHER
	return Color(0.7, 0.7, 0.7)


static func _second_color(it: ItemData) -> Color:
	var lk := it.look
	if lk.has("trim_color") and lk["trim_color"] is Color:
		return lk["trim_color"]
	if lk.has("sash_color") and lk["sash_color"] is Color:
		return lk["sash_color"]
	return GOLD


## Layers of [color code, polygon]. Codes: m main, d dark, l light, b second
## (trim / sash), g gold, s steel, k black, w leather.
static func _shapes(kind: String, look: Dictionary) -> Array:
	match kind:
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
		"shirt", "tunic", "blouse":
			var ln := 20 if kind == "tunic" else 17
			var sl := str(look.get("sleeves", "long"))
			var sleeve_end := 16 if sl == "long" else (11 if sl == "short" else 8)
			var arms := 4 if kind == "blouse" else 3
			var layers := [["m", [Vector2(7, 5), Vector2(17, 5), Vector2(18, ln), Vector2(6, ln)]]]
			if sl != "none":
				layers.append(["m", [Vector2(7, 5), Vector2(3, 8), Vector2(arms - 1, sleeve_end), Vector2(arms + 3, sleeve_end), Vector2(7, 10)]])
				layers.append(["m", [Vector2(17, 5), Vector2(21, 8), Vector2(25 - arms, sleeve_end), Vector2(21 - arms, sleeve_end), Vector2(17, 10)]])
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
	return [["m", [Vector2(5, 5), Vector2(19, 5), Vector2(19, 19), Vector2(5, 19)]]]


## Even-odd polygon fill sampled at pixel centers, shaded lighter at the top.
static func _fill(img: Image, poly: Array, col: Color) -> void:
	var pts := PackedVector2Array()
	for p in poly:
		pts.append(p)
	var miny := SIZE
	var maxy := 0
	for p in pts:
		miny = mini(miny, int(floor(p.y)))
		maxy = maxi(maxy, int(ceil(p.y)))
	for y in range(maxi(miny, 0), mini(maxy + 1, SIZE)):
		for x in range(SIZE):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				var shade := 1.12 - 0.26 * float(y) / SIZE
				img.set_pixel(x, y, Color(col.r * shade, col.g * shade, col.b * shade, 1.0))


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
