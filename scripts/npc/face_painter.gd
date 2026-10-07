class_name FacePainter
extends RefCounted
## Paints anime-style faces (64x64, nearest filtered) that BodyBuilder wraps
## around the front of the head with a cylindrical projection: u follows the
## angle around the head (front = 0.5, +-SPAN at the edges), v follows height
## from Y_TOP (hairline) down to the chin. Features are drawn in that space,
## so they curve around the head instead of sitting on a flat card.

const SIZE := 64
const SPAN := deg_to_rad(80.0)
const Y_TOP := 0.36
const Y_BOT := 0.0
const LIT_SHADER := preload("res://shaders/psx/psx_lit.gdshader")

const LASH := Color(0.1, 0.07, 0.06)
const WHITE := Color(0.97, 0.95, 0.9)
const LIP := Color(0.42, 0.16, 0.13)
const MOUTH_IN := Color(0.3, 0.08, 0.07)
const TONGUE := Color(0.8, 0.36, 0.34)
const TEETH := Color(0.98, 0.97, 0.93)

static var _cache: Dictionary = {}
## (faces are painted on a worker thread too, see Humanoid.prebuild)
static var _lock := Mutex.new()

var img: Image
## The hair style's hairline (BodyBuilder.HAIRLINES): above it the face
## texture is hair-coloured, so the forehead/scalp under the hair never shows
## skin through it.
var hairline: Array = []


## UV for a head-local point (y already divided by any vertical head stretch).
static func uv(p: Vector3, yk: float = 1.0) -> Vector2:
	var a := atan2(p.x, -p.z)
	return Vector2(0.5 + a / (2.0 * SPAN), (Y_TOP - p.y / yk) / (Y_TOP - Y_BOT))


## Whether a head quad (by its center) belongs to the face region.
static func pick(center: Vector3, yk: float = 1.0) -> bool:
	return absf(atan2(center.x, -center.z)) < SPAN - 0.05 and center.y / yk < Y_TOP + 0.01


## Pixel position for an angle (degrees, + = character's left... viewer's right) and head height.
static func px(angle_deg: float, y: float) -> Vector2:
	return Vector2((0.5 + deg_to_rad(angle_deg) / (2.0 * SPAN)) * SIZE, (Y_TOP - y) / (Y_TOP - Y_BOT) * SIZE)


static func material(lk: Dictionary, eye_scale: float, hairline: Array = []) -> Material:
	var key := str(hairline.hash()) + "|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%.2f" % [lk.get("eyes", 0), lk.get("brows", 0), lk.get("mouth", 0),
		lk.get("marks", "none"), lk.get("facial_hair", "none"), lk.get("eyepatch", false), lk.get("body", "masc"),
		(lk.get("eye_color", Color.BROWN) as Color).to_html(), (lk.get("hair_color", Color.BLACK) as Color).to_html(),
		(lk.get("skin", Color.WHITE) as Color).to_html(), lk.get("head", "round"), lk.get("style", ""), eye_scale]
	_lock.lock()
	var hit: Material = _cache.get(key)
	_lock.unlock()
	if hit:
		return hit
	var fp := FacePainter.new()
	fp.hairline = hairline
	fp.paint(lk, eye_scale)
	var m := ShaderMaterial.new()
	m.shader = LIT_SHADER
	m.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(fp.img))
	m.set_shader_parameter("albedo_color", lk.get("skin", Color.WHITE))
	m.set_shader_parameter("decal_mode", true)
	m.set_shader_parameter("use_vertex_color", false)
	m.set_shader_parameter("affine_amount", 0.0)
	_lock.lock()
	if _cache.has(key):
		m = _cache[key]
	else:
		_cache[key] = m
	_lock.unlock()
	return m


func paint(lk: Dictionary, eye_scale: float) -> void:
	img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fem := str(lk.get("body", "masc")) == "fem"
	var hair: Color = lk.get("hair_color", Color(0.2, 0.12, 0.08))
	var skin: Color = lk.get("skin", Color(0.85, 0.65, 0.5))
	var marks := str(lk.get("marks", "none"))
	if not hairline.is_empty():
		var hc := hair.darkened(0.15)
		for x in range(SIZE):
			var a := ((float(x) + 0.5) / SIZE - 0.5) * 2.0 * SPAN
			var hl := BodyBuilder._hairline(hairline, a) + 0.015
			for y in range(SIZE):
				var hy := Y_TOP - (float(y) + 0.5) / SIZE * (Y_TOP - Y_BOT)
				if hy > hl:
					img.set_pixel(x, y, Color(hc.r, hc.g, hc.b, 1.0))
	_marks_under(marks, skin)
	if str(lk.get("facial_hair", "none")) == "stubble":
		_stubble(hair)
	var es := eye_scale * (1.12 if fem else 1.0)
	var eye_style := int(lk.get("eyes", 0)) % 6
	for side in [-1, 1]:
		var c := px(23.0 * side, 0.165)
		_eye(c, side, eye_style, es, fem, lk.get("eye_color", Color(0.3, 0.2, 0.1)))
		_brow(c, side, int(lk.get("brows", 0)) % 5, es, fem, hair.darkened(0.3))
	_nose_shade(skin)
	_mouth(int(lk.get("mouth", 0)) % 6, fem)
	_marks_over(marks, skin)
	if lk.get("eyepatch", false):
		_eyepatch()


# --------------------------------------------------------------------------
# primitives
# --------------------------------------------------------------------------
func _put(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(c))


func _line(a: Vector2, b: Vector2, c: Color, thick: int = 1) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / maxf(n, 1))
		for t in range(thick):
			_put(int(round(p.x)), int(round(p.y)) + t, c)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	for y in range(int(floor(c.y - ry)), int(ceil(c.y + ry)) + 1):
		for x in range(int(floor(c.x - rx)), int(ceil(c.x + rx)) + 1):
			var dx := (x + 0.5 - c.x) / maxf(rx, 0.01)
			var dy := (y + 0.5 - c.y) / maxf(ry, 0.01)
			if dx * dx + dy * dy <= 1.0:
				_put(x, y, col)


# --------------------------------------------------------------------------
# features
# --------------------------------------------------------------------------
func _eye(c: Vector2, side: int, style: int, s: float, fem: bool, iris: Color) -> void:
	var w := 4.6 * s
	var hgt := (4.4 if fem else 3.4) * s
	var outer := c.x - side * w      # outer corner (toward the ear)
	var inner := c.x + side * w * 0.9
	match style:
		5:  # simple dot eyes
			_ellipse(c, 1.6 * s, 2.4 * s, LASH)
			_put(int(c.x - 0.5), int(c.y - 1.5 * s), WHITE)
			return
		1:  # narrow / sharp
			hgt *= 0.55
		2:  # wide
			hgt *= 1.3
			w *= 1.08
		3:  # hooded / sleepy
			hgt *= 0.9
	# sclera
	_ellipse(c, w, hgt, WHITE)
	# iris (darker toward the top, anime-style) + pupil + highlights
	var ir := Vector2(w * 0.5, hgt * 0.92)
	var ic := c + Vector2(0, hgt * 0.05)
	_ellipse(ic, ir.x, ir.y, iris)
	_ellipse(ic + Vector2(0, -ir.y * 0.45), ir.x, ir.y * 0.5, iris.darkened(0.45))
	_ellipse(ic + Vector2(0, ir.y * 0.15), ir.x * 0.42, ir.y * 0.48, Color(0.04, 0.03, 0.03))
	_put(int(ic.x - ir.x * 0.4), int(ic.y - ir.y * 0.45), WHITE)
	_put(int(ic.x - ir.x * 0.4) + 1, int(ic.y - ir.y * 0.45), WHITE)
	_put(int(ic.x + ir.x * 0.35), int(ic.y + ir.y * 0.4), Color(1, 1, 1, 0.8))
	# lids
	var top := c.y - hgt
	match style:
		3:  # heavy lid covers the top half
			_clear_rect(Vector2(c.x - w - 1, top - 1), Vector2(c.x + w + 1, c.y - 1.0))
			_line(Vector2(outer, c.y - 0.5), Vector2(inner, c.y - 1.0), LASH, 2)
		4:  # fierce: brow-side slant, inner corner pulled down
			_clear_tri(Vector2(inner, top - 1), Vector2(inner, c.y), Vector2(c.x - side * w * 0.1, top - 1))
			_line(Vector2(outer - side, top), Vector2(inner, c.y - hgt * 0.15), LASH, 2)
		_:
			_line(Vector2(outer - side * 0.5, c.y - hgt * 0.35), Vector2(c.x, top - 0.5), LASH, 2)
			_line(Vector2(c.x, top - 0.5), Vector2(inner, c.y - hgt * 0.6), LASH, 2)
	# outer lash flick + lower lid
	if fem:
		_line(Vector2(outer - side * 0.5, c.y - hgt * 0.4), Vector2(outer - side * 2.0, c.y - hgt * 0.9), LASH)
	_line(Vector2(outer + side * 0.5, c.y + hgt * 0.75), Vector2(c.x + side * w * 0.3, c.y + hgt + 0.3), Color(LASH, 0.45))


func _clear_rect(a: Vector2, b: Vector2) -> void:
	for y in range(int(a.y), int(b.y) + 1):
		for x in range(int(a.x), int(b.x) + 1):
			if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func _clear_tri(a: Vector2, b: Vector2, c: Vector2) -> void:
	var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)))
	var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)))
	for y in range(int(lo.y), int(hi.y) + 1):
		for x in range(int(lo.x), int(hi.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.point_is_inside_triangle(p, a, b, c) and x >= 0 and y >= 0 and x < SIZE and y < SIZE:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func _brow(eye: Vector2, side: int, style: int, s: float, fem: bool, col: Color) -> void:
	var w := 5.2 * s
	var y := eye.y - (6.5 if fem else 5.2) * s
	var outer := Vector2(eye.x - side * w, y + 0.5)
	var inner := Vector2(eye.x + side * w * 0.8, y)
	var thick := 1 if fem else 2
	match style:
		0:  # natural arc
			_line(outer, Vector2(eye.x, y - 1), col, thick)
			_line(Vector2(eye.x, y - 1), inner, col, thick)
		1:  # thick
			_line(outer, inner, col, 3)
		2:  # thin arch
			_line(outer + Vector2(0, 1), Vector2(eye.x - side, y - 2), col)
			_line(Vector2(eye.x - side, y - 2), inner, col)
		3:  # stern: inner end low
			_line(outer + Vector2(0, -1.5), inner + Vector2(0, 2), col, thick + 1)
		4:  # worried: inner end high
			_line(outer + Vector2(0, 1.5), inner + Vector2(0, -2), col, thick)


func _nose_shade(skin: Color) -> void:
	var c := px(0.0, 0.112)
	_put(int(c.x) - 1, int(c.y), Color(skin.darkened(0.35), 0.8))
	_put(int(c.x), int(c.y), Color(skin.darkened(0.25), 0.6))


func _mouth(style: int, fem: bool) -> void:
	var c := px(0.0, 0.072)
	var w := 3.6 if fem else 4.4
	match style:
		0:  # neutral
			_line(c + Vector2(-w, 0), c + Vector2(w, 0), LIP)
		1:  # smile
			_line(c + Vector2(-w - 1, -1), c + Vector2(-w * 0.4, 1), LIP)
			_line(c + Vector2(-w * 0.4, 1), c + Vector2(w * 0.4, 1), LIP)
			_line(c + Vector2(w * 0.4, 1), c + Vector2(w + 1, -1), LIP)
		2:  # big toothy grin
			for y in range(-2, 4):
				var hw := (w + 3.0) * sqrt(maxf(0.0, 1.0 - pow((y - 0.5) / 3.6, 2.0)))
				_line(c + Vector2(-hw, y), c + Vector2(hw, y), TEETH)
			_line(c + Vector2(-w - 3, -2), c + Vector2(w + 3, -2), LIP)
			_line(c + Vector2(-w - 3, -2), c + Vector2(-w * 0.5, 3.5), LIP)
			_line(c + Vector2(w + 3, -2), c + Vector2(w * 0.5, 3.5), LIP)
			_line(c + Vector2(-w * 0.5, 3.5), c + Vector2(w * 0.5, 3.5), LIP)
			_line(c + Vector2(-w - 1, 0.5), c + Vector2(w + 1, 0.5), Color(LIP, 0.4))
		3:  # frown
			_line(c + Vector2(-w, 1), c + Vector2(-w * 0.4, -0.5), LIP)
			_line(c + Vector2(-w * 0.4, -0.5), c + Vector2(w * 0.4, -0.5), LIP)
			_line(c + Vector2(w * 0.4, -0.5), c + Vector2(w, 1), LIP)
		4:  # smirk
			_line(c + Vector2(-w, 0), c + Vector2(w * 0.5, 0), LIP)
			_line(c + Vector2(w * 0.5, 0), c + Vector2(w + 1.5, -2), LIP)
		5:  # open
			_ellipse(c + Vector2(0, 1), 2.4, 2.8, MOUTH_IN)
			_ellipse(c + Vector2(0, 2.4), 1.6, 1.2, TONGUE)


func _stubble(hair: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var mouth := px(0.0, 0.072)
	for y in range(int(px(0, 0.11).y), SIZE):
		for x in range(8, SIZE - 8):
			var dx := absf(x - SIZE * 0.5)
			if dx > 23.0 - (y - 40) * 0.3:
				continue
			if absf(y - mouth.y) < 2.0 and dx < 6.0:
				continue
			if rng.randf() < 0.22:
				_put(x, y, Color(hair.darkened(0.15), 0.55))


func _marks_under(marks: String, skin: Color) -> void:
	match marks:
		"blush":
			for side in [-1, 1]:
				_ellipse(px(30.0 * side, 0.125), 3.6, 1.6, Color(0.95, 0.4, 0.4, 0.38))
		"freckles":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in range(14):
				var side := -1 if i % 2 == 0 else 1
				var p := px(side * rng.randf_range(14.0, 38.0), rng.randf_range(0.115, 0.14))
				_put(int(p.x), int(p.y), Color(skin.darkened(0.4), 0.85))


func _marks_over(marks: String, skin: Color) -> void:
	match marks:
		"scar":
			# small stitched scar under the (viewer's) left eye
			var a := px(-30.0, 0.135)
			var b := px(-20.0, 0.128)
			_line(a, b, Color(0.62, 0.28, 0.24))
			for t in [0.25, 0.5, 0.75]:
				var m := a.lerp(b, t)
				_line(m + Vector2(0, -1), m + Vector2(0, 1), Color(0.62, 0.28, 0.24, 0.9))
		"war_paint":
			for side in [-1, 1]:
				var c := px(23.0 * side, 0.165)
				for i in range(3):
					_line(c + Vector2(-side * 2 + i * side, 6), c + Vector2(-side * 2 + i * side + side * 3, 11), Color(0.55, 0.08, 0.08, 0.9))
		"age_lines":
			for side in [-1, 1]:
				var c := px(23.0 * side, 0.165)
				_line(c + Vector2(-side * 6, 0), c + Vector2(-side * 8, 2), Color(skin.darkened(0.4), 0.7))
				_line(px(10.0 * side, 0.1), px(13.0 * side, 0.07), Color(skin.darkened(0.35), 0.7))


func _eyepatch() -> void:
	var c := px(23.0, 0.165)
	_ellipse(c, 6.0, 5.0, Color(0.05, 0.04, 0.04))
	_line(c + Vector2(-5, -4), px(-80.0, 0.232), LASH, 2)
	_line(c + Vector2(5, -3), px(80.0, 0.2), LASH, 2)
