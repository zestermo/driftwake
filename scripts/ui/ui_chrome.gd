class_name UIChrome
extends RefCounted
## The whimsical menu chrome painted pixel by pixel (one image pixel per canvas pixel): wooden beams and planks,
## gilded signs, parchment with burnt edges, slate in a rope border, swallowtail ribbons, wooden keycaps, a
## doubloon, a scroll nameplate. UIStyle.chrome(kind) turns each into a 9-slice; these are the images.

const INK := Color("2b1a0c")
const WOOD_HI := Color("86603b")
const WOOD := Color("694627")
const WOOD_LO := Color("4c311a")
const PLANK_HI := Color("7a5534")
const PLANK_LO := Color("5a3b22")
const RIM_HI := Color("9c7448")
const RIM_LO := Color("6e4b2b")
const ROPE_HI := Color("e3c487")
const ROPE_LO := Color("a8823f")
const ROPE_DIM := Color("c9a15a")
const ROPE_DARK := Color("8a6a2c")
const GILT_TOP := Color("ffe9a3")
const GILT := Color("f2c45e")
const GILT_LO := Color("d9a640")
const GILT_RIM_HI := Color("fff0b8")
const GILT_RIM_LO := Color("c99a3e")
const PARCH := Color("f3e6c4")
const PARCH_RIM := Color("d9b77a")
const BURN := Color("7a4a1e")
const WAX := Color("d0453a")
const WAX_LO := Color("9a2e24")
const RIBBON_HI := Color("e0644f")
const RIBBON_LO := Color("b5402f")
const SLATE_HI := Color("1f6068f0")
const SLATE_LO := Color("0e2c32f2")
const TWINKLE := Color("fff3c9")

## kind -> [margin left, top, right, bottom, tile (true) or stretch the middle, content pad lr, tb]
const KINDS := {
	"parchment": [21, 21, 21, 21, true, 11, 9],
	"paper": [8, 8, 8, 8, true, 6, 4],
	"slate": [10, 10, 10, 10, true, 8, 6],
	"plank": [5, 5, 5, 5, false, 6, 3],
	"plank_hover": [5, 5, 5, 5, false, 6, 3],
	"plank_pressed": [5, 5, 5, 5, false, 6, 3],
	"plank_dim": [5, 5, 5, 5, false, 6, 3],
	"plank_focus": [5, 5, 5, 5, false, 6, 3],
	"sign": [6, 6, 6, 6, false, 6, 3],
	"sign_on": [6, 6, 6, 6, false, 6, 3],
	"ribbon": [7, 0, 7, 0, false, 9, 1],
	"ribbon_gold": [7, 0, 7, 0, false, 9, 1],
	"keycap": [4, 4, 4, 5, false, 3, 1],
	"scroll": [10, 4, 5, 4, true, 4, 2],
	"beam": [0, 0, 0, 0, true, 0, 0],
	"board": [0, 6, 0, 3, true, 8, 3],
	"well": [4, 4, 4, 4, true, 4, 2],
	"rope": [0, 0, 0, 0, true, 0, 0],
}

## Height of the beam (the menus' top bar, its rope included) and the board (the key-hint bar, rope on top).
const BEAM_H := 28
const BOARD_H := 18

static var _images: Dictionary = {}


static func image(kind: String) -> Image:
	if _images.has(kind):
		return _images[kind]
	var img: Image
	match kind:
		"parchment":
			img = _parchment(63, 63, [9, 4, 10, 6], true)
		"paper":
			img = _parchment(20, 20, [4, 2, 5, 3], false)
		"slate":
			img = _slate()
		"plank":
			img = _plank(14, [3, 4, 3, 4], RIM_HI, RIM_LO, PLANK_HI, PLANK_LO, true)
		"plank_hover":
			img = _plank(14, [3, 4, 3, 4], GILT_RIM_HI, GILT_RIM_LO, GILT_TOP, GILT_LO, false)
		"plank_pressed":
			img = _plank(14, [3, 4, 3, 4], GILT_RIM_LO, GILT_RIM_HI, GILT_LO, GILT, false)
		"plank_dim":
			img = _plank(14, [3, 4, 3, 4], Color("6f675c"), Color("4f4840"), Color("5e564c"), Color("47413a"), true)
		"plank_focus":
			img = _focus(14, [3, 4, 3, 4])
		"sign":
			img = _plank(16, [4, 6, 3, 5], RIM_HI, RIM_LO, PLANK_HI, PLANK_LO, true)
		"sign_on":
			img = _plank(16, [4, 6, 3, 5], GILT_RIM_HI, GILT_RIM_LO, GILT_TOP, GILT_LO, false)
		"ribbon":
			img = _ribbon(RIBBON_HI, RIBBON_LO, WAX_LO)
		"ribbon_gold":
			img = _ribbon(Color("ffe08a"), GILT_LO, Color("b88a3a"))
		"keycap":
			img = _keycap()
		"scroll":
			img = _scroll()
		"beam":
			img = _beam()
		"board":
			img = _board()
		"well":
			img = _well()
		"rope":
			img = _rope_strip(3)
	_images[kind] = img
	return img


static func _new(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


## How far in from a box's edge a pixel is (0 = the outline), each corner cut to its own radius
## ([top left, top right, bottom right, bottom left]); negative outside.
static func depth(x: int, y: int, w: int, h: int, radii: Array) -> int:
	var fx := mini(x, w - 1 - x)
	var fy := mini(y, h - 1 - y)
	var right := x * 2 >= w
	var r: int = radii[(1 if right else 0) if y * 2 < h else (2 if right else 3)]
	if fx < r and fy < r:
		return floori(r - Vector2(r - fx - 0.5, r - fy - 0.5).length())
	return mini(fx, fy)


## Is this pixel on the lit (top or left) side of the box?
static func _lit(x: int, y: int, w: int, h: int) -> bool:
	var fx := mini(x, w - 1 - x)
	var fy := mini(y, h - 1 - y)
	return (y * 2 < h) if fy <= fx else (x * 2 < w)


static func _rope(x: int, y: int) -> Color:
	return ROPE_HI if posmod(x + y, 4) < 2 else ROPE_LO


## Parchment: a dark outline, a gilt band, the paper burnt toward its hand-cut edges, faint grain;
## `ornate` adds a red wax seal in the top right corner and a coffee ring in the bottom left.
static func _parchment(w: int, h: int, radii: Array, ornate: bool) -> Image:
	var img := _new(w, h)
	var p0 := 4 if ornate else 1
	var burn := [0.5, 0.34, 0.22, 0.14, 0.09, 0.05, 0.03] if ornate else [0.38, 0.18, 0.08]
	for y in range(h):
		for x in range(w):
			var d := depth(x, y, w, h, radii)
			if d < 0:
				continue
			var c := INK
			if d >= p0:
				c = PARCH
				if y % 3 == 0:
					c = c.blend(Color(ROPE_DARK, 0.08))
				var k := d - p0
				if k < burn.size():
					c = c.blend(Color(BURN, burn[k]))
			elif d > 0 and d < 3:
				c = PARCH_RIM.lerp(Color.WHITE, 0.25) if d == 1 and _lit(x, y, w, h) else PARCH_RIM
				if not _lit(x, y, w, h):
					c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	if ornate:
		_coffee_ring(img, Vector2(12.5, h - 12.5), 8.0)
		_seal(img, Vector2(w - 11.5, 10.5))
	return img


static func _coffee_ring(img: Image, c: Vector2, r: float) -> void:
	for y in range(int(c.y - r - 2), int(c.y + r + 2)):
		for x in range(int(c.x - r - 2), int(c.x + r + 2)):
			var v := Vector2(x + 0.5, y + 0.5) - c
			var a := rad_to_deg(v.angle())
			if a > 110.0 and a < 165.0:
				continue
			var dd := absf(v.length() - r)
			if dd < 0.55:
				_blend(img, x, y, Color(ROPE_DARK, 0.26))
			elif dd < 1.4 and v.length() < r:
				_blend(img, x, y, Color(ROPE_DARK, 0.07))


static func _seal(img: Image, c: Vector2) -> void:
	for y in range(int(c.y) - 7, int(c.y) + 8):
		for x in range(int(c.x) - 7, int(c.x) + 8):
			var dd := (Vector2(x + 0.5, y + 0.5) - c).length()
			if dd <= 4.2:
				img.set_pixel(x, y, WAX)
			elif dd <= 5.3:
				img.set_pixel(x, y, WAX_LO)
			elif dd <= 6.0:
				_blend(img, x, y, Color(INK, 0.45))
	var cx := int(c.x)
	var cy := int(c.y)
	for q in [Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 2), Vector2i(1, 2)]:
		img.set_pixel(cx + q.x, cy + q.y, WAX_LO)
	img.set_pixel(cx - 2, cy - 3, Color("ff8f80"))
	img.set_pixel(cx - 3, cy - 2, Color("ff8f80"))
	img.set_pixel(cx - 2, cy - 2, Color.WHITE)
	for q in [Vector2i(-3, 5), Vector2i(-3, 6), Vector2i(2, 5)]:
		img.set_pixel(cx + q.x, cy + q.y, WAX_LO)


## Slate in a twisted rope border with a brass nail in each corner.
static func _slate() -> Image:
	var w := 24
	var h := 24
	var radii := [6, 4, 7, 4]
	var img := _new(w, h)
	for y in range(h):
		for x in range(w):
			var d := depth(x, y, w, h, radii)
			if d < 0:
				continue
			var c: Color
			if d == 0 or d == 3:
				c = INK
			elif d < 3:
				c = _rope(x, y)
				if not _lit(x, y, w, h):
					c = c.darkened(0.12)
			else:
				c = SLATE_HI.lerp(SLATE_LO, 0.45)
				if d == 4 and y * 2 < h and mini(x, w - 1 - x) > 3:
					c = c.lerp(Color("f5e8c8"), 0.1)
			img.set_pixel(x, y, c)
	for p in [Vector2i(6, 6), Vector2i(w - 7, 6), Vector2i(6, h - 7), Vector2i(w - 7, h - 7)]:
		nail(img, p)
	return img


## A 3x3 brass nail centred on `p`.
static func nail(img: Image, p: Vector2i) -> void:
	for q in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		_blend(img, p.x + q.x, p.y + q.y, Color(INK, 0.55))
	img.set_pixel(p.x, p.y - 1, TWINKLE)
	img.set_pixel(p.x - 1, p.y, TWINKLE)
	img.set_pixel(p.x, p.y, GILT)
	img.set_pixel(p.x + 1, p.y, Color("a8742a"))
	img.set_pixel(p.x, p.y + 1, Color("a8742a"))


## A wooden (or gilded) plank: dark outline, a rim lit from the top, the face shaded top to bottom
## with grain, a highlight under its top edge.
static func _plank(n: int, radii: Array, rim_hi: Color, rim_lo: Color, hi: Color, lo: Color, grain: bool) -> Image:
	var img := _new(n, n)
	for y in range(n):
		for x in range(n):
			var d := depth(x, y, n, n, radii)
			if d < 0:
				continue
			var f := float(y) / float(n - 1)
			var c := INK
			if d == 1:
				c = rim_hi.lerp(rim_lo, f)
			elif d >= 2:
				c = hi.lerp(lo, f)
				if grain and y % 2 == 1:
					c = c.blend(Color(INK, 0.14))
				if d == 2 and y * 2 < n:
					c = c.lerp(Color(1, 0.95, 0.8), 0.22 if grain else 0.5)
				elif d == 2:
					c = c.darkened(0.22)
			img.set_pixel(x, y, c)
	return img


## Keyboard / pad focus: a gilt ring and a soft glow over whatever plank is under it.
static func _focus(n: int, radii: Array) -> Image:
	var img := _new(n, n)
	for y in range(n):
		for x in range(n):
			var d := depth(x, y, n, n, radii)
			if d == 0:
				img.set_pixel(x, y, GILT_TOP)
			elif d == 1:
				img.set_pixel(x, y, Color(GILT, 0.45))
	return img


## A swallowtail banner 12 px tall: notched ends, shaded face, folds at the tails.
static func _ribbon(hi: Color, lo: Color, fold: Color) -> Image:
	var w := 16
	var h := 12
	var img := _new(w, h)
	for y in range(h):
		var notch := 4 - absi(int(floor(abs(y - 5.5)))) if y > 0 and y < h - 1 else 0
		notch = maxi(notch, 0)
		var xl := notch
		var xr := w - 1 - notch
		for x in range(xl, xr + 1):
			var c := hi.lerp(lo, float(y) / float(h - 1))
			if y == 0 or y == h - 1 or x == xl or x == xr:
				c = INK
			elif y == 1:
				c = c.lerp(Color.WHITE, 0.25)
			elif y == h - 2:
				c = c.darkened(0.18)
			elif x <= 5 or x >= w - 6:
				c = c.lerp(fold, 0.35)
			if (x == 6 or x == w - 7) and y > 0 and y < h - 1:
				c = fold.darkened(0.2)
			img.set_pixel(x, y, c)
	return img


## A round wooden keycap: cream face lit from the top left, a brown lip and a dark shadow under it.
static func _keycap() -> Image:
	var w := 11
	var bh := 10
	var img := _new(w, bh + 2)
	var radii := [4, 3, 4, 3]
	for y in range(bh):
		for x in range(w):
			var d := depth(x, y, w, bh, radii)
			if d < 0:
				continue
			var c := INK
			if d > 0:
				var t := clampf((Vector2(x, y) - Vector2(w * 0.4, bh * 0.3)).length() / 7.0, 0.0, 1.0)
				c = Color("fbf2da").lerp(Color("d9c79a"), t)
			img.set_pixel(x, y, c)
	for x in range(w):
		if img.get_pixel(x, bh - 1).a > 0.0:
			var edge := img.get_pixel(maxi(x - 1, 0), bh - 1).a == 0.0 or img.get_pixel(mini(x + 1, w - 1), bh - 1).a == 0.0 or x == 0 or x == w - 1
			img.set_pixel(x, bh, INK if edge else ROPE_DARK)
			img.set_pixel(x, bh + 1, INK)
	return img


## The nameplate: a parchment scroll, round on the left (where the doubloon sits), its right end curling.
static func _scroll() -> Image:
	var w := 19
	var h := 19
	var radii := [9, 3, 4, 9]
	var img := _new(w, h)
	for y in range(h):
		for x in range(w):
			var d := depth(x, y, w, h, radii)
			if d < 0:
				continue
			var c := INK
			if d > 0:
				c = PARCH
				if y % 3 == 0:
					c = c.blend(Color(ROPE_DARK, 0.07))
				var curl := w - 1 - x
				if curl < 4:
					c = c.blend(Color(ROPE_DARK, [0.45, 0.32, 0.2, 0.1][curl]))
				if d == 1 and y * 2 > h:
					c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	return img


## Rows of rope `h` tall: a dark line, twisted stripes, a dark line.
static func _rope_strip(h: int) -> Image:
	var img := _new(8, h)
	for y in range(h):
		for x in range(8):
			img.set_pixel(x, y, _rope(x, y).darkened(0.1 if y == h - 1 else 0.0))
	return img


## The top bar: a warm wooden beam (two planks per tile, grain, knots) over a twisted rope.
static func _beam() -> Image:
	var w := 140
	var img := _new(w, BEAM_H)
	var wood_h := BEAM_H - 6
	for y in range(BEAM_H):
		for x in range(w):
			var c := Color(0, 0, 0, 0)
			if y < wood_h:
				var f := float(y) / float(wood_h - 1)
				c = WOOD_HI.lerp(WOOD, f / 0.55) if f < 0.55 else WOOD.lerp(WOOD_LO, (f - 0.55) / 0.45)
				if y % 3 == 2:
					c = c.blend(Color(INK, 0.16))
				if x % 70 == 0:
					c = c.blend(Color(INK, 0.38))
				elif x % 70 == 1:
					c = c.lerp(Color(1, 0.9, 0.7), 0.08)
				if y == 0:
					c = c.lerp(Color(1, 0.9, 0.7), 0.2)
				elif y == wood_h - 1:
					c = c.blend(Color(INK, 0.6))
			elif y == wood_h or y == wood_h + 3:
				c = INK
			elif y < wood_h + 3:
				c = _rope(x, y)
			elif y == wood_h + 4:
				c = Color(0, 0, 0, 0.35)
			else:
				c = Color(0, 0, 0, 0.15)
			img.set_pixel(x, y, c)
	for k in [[Vector2(17, 8), 3.5], [Vector2(53, 15), 2.5], [Vector2(99, 6), 3.0], [Vector2(124, 14), 4.0]]:
		_knot(img, k[0], k[1])
	return img


static func _knot(img: Image, c: Vector2, rx: float) -> void:
	for y in range(int(c.y) - 3, int(c.y) + 4):
		for x in range(int(c.x - rx) - 2, int(c.x + rx) + 3):
			var e := Vector2((x + 0.5 - c.x) / rx, (y + 0.5 - c.y) / 1.4).length()
			if e < 0.75:
				_blend(img, x, y, Color(INK, 0.5))
			elif e < 1.25:
				_blend(img, x, y, Color(INK, 0.22))
			elif e < 1.6 and y < int(c.y):
				_blend(img, x, y, Color(1, 0.9, 0.7, 0.08))


## The key-hint bar: a rope along the top of a dark wooden board.
static func _board() -> Image:
	var w := 8
	var img := _new(w, BOARD_H)
	for y in range(BOARD_H):
		for x in range(w):
			var c: Color
			if y == 0 or y == 3:
				c = INK
			elif y < 3:
				c = _rope(x, y)
			else:
				var f := float(y - 4) / float(BOARD_H - 5)
				c = WOOD.lerp(WOOD_LO, f)
				if y % 3 == 0:
					c = c.blend(Color(INK, 0.16))
				if y == 4:
					c = c.blend(Color(INK, 0.4))
			img.set_pixel(x, y, c)
	return img


## A text field: a sunk paper well.
static func _well() -> Image:
	var n := 12
	var img := _new(n, n)
	for y in range(n):
		for x in range(n):
			var d := depth(x, y, n, n, [3, 2, 3, 2])
			if d < 0:
				continue
			var c := INK
			if d == 1:
				c = BURN.lerp(PARCH, 0.35) if _lit(x, y, n, n) else PARCH
			elif d > 1:
				c = PARCH.lerp(Color.WHITE, 0.15)
			img.set_pixel(x, y, c)
	return img


## A doubloon `d` px across: a gold face lit from the top left in a dark, gold, dark rim.
static func coin(d: int) -> Image:
	var key := "coin%d" % d
	if _images.has(key):
		return _images[key]
	var img := _new(d, d)
	var c := Vector2(d, d) * 0.5
	var r := d * 0.5
	for y in range(d):
		for x in range(d):
			var dd := (Vector2(x + 0.5, y + 0.5) - c).length()
			if dd > r:
				continue
			var col := INK
			if dd <= r - 3.0:
				var t := clampf((Vector2(x + 0.5, y + 0.5) - Vector2(d * 0.35, d * 0.3)).length() / (r * 1.3), 0.0, 1.0)
				col = TWINKLE.lerp(GILT, t / 0.45) if t < 0.45 else GILT.lerp(Color("a8742a"), (t - 0.45) / 0.55)
			elif dd <= r - 2.0:
				col = INK
			elif dd <= r - 1.0:
				col = ROPE_HI
			img.set_pixel(x, y, col)
	_images[key] = img
	return img


## A four-point star `n` px across (odd): long arms, a fat middle, a dark outline when `outline`.
static func star(n: int, col: Color, outline: bool) -> Image:
	var key := "star%d%s%s" % [n, col.to_html(), outline]
	if _images.has(key):
		return _images[key]
	var pad := 1 if outline else 0
	var s := n + pad * 2
	var img := _new(s, s)
	var m := floori(n / 2.0)
	var mask := {}
	for i in range(n):
		mask[Vector2i(i, m)] = true
		mask[Vector2i(m, i)] = true
	for q in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if n >= 7:
			mask[Vector2i(m, m) + q] = true
	if outline:
		for p in mask.keys():
			for q in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o: Vector2i = p + q
				if not mask.has(o):
					img.set_pixel(o.x + pad, o.y + pad, INK)
	for p in mask.keys():
		img.set_pixel(p.x + pad, p.y + pad, col)
	img.set_pixel(m + pad, m + pad, col.lerp(Color.WHITE, 0.6))
	_images[key] = img
	return img
