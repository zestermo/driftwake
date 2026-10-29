extends SceneTree
## The Edy art for the site (1.25's post): a banner with the five Edy types' symbols round the word, and a lineup of
## the five auras (abilityshot's Reinforce stills, AB_EDY per type, in tools/dev/out/edy/<type>_edy_reinforce.png),
## each with its symbol and name. Drawn at a low resolution and scaled up with hard pixel edges (the PS1 look), saved as
## <out>/edy_banner.jpg, edy_types.jpg and their -640 copies. Args: <out_dir>. Opens a window (2D drawing).

const TYPES := ["still", "ember", "crown", "storm", "tide"]
const NAMES := {"still": "STILL", "ember": "EMBER", "crown": "CROWN", "storm": "STORM", "tide": "TIDE"}
const COLORS := {"still": Color(0.42, 0.66, 1.0), "ember": Color(0.92, 0.2, 0.16), "crown": Color(1.0, 0.8, 0.3),
	"storm": Color(0.62, 0.36, 0.95), "tide": Color(0.2, 0.78, 0.66)}
const SCALE := 4
var out := "res://tools/dev/out/edy"
var step := 0


class Art extends Control:
	var kind := "banner"
	var font: Font
	var font_b: Font
	var shots := {}
	var t := 0.0

	func _draw() -> void:
		if kind == "banner":
			_banner()
		else:
			_lineup()

	func _sky() -> void:
		var h := int(size.y)
		for y in range(h):
			var k := float(y) / h
			var c := Color(0.05, 0.07, 0.16).lerp(Color(0.2, 0.11, 0.26), k)
			if k > 0.62:
				c = Color(0.06, 0.16, 0.22).lerp(Color(0.03, 0.08, 0.12), (k - 0.62) / 0.38)
			draw_line(Vector2(0, y), Vector2(size.x, y), c)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in range(70):
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.58)
			draw_rect(Rect2(p.floor(), Vector2.ONE), Color(1, 1, 1, rng.randf_range(0.25, 0.8)))
		# the sea's swell lines
		for i in range(14):
			var y := size.y * 0.66 + i * i * 0.55
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.3, 0.55, 0.6, 0.12 + i * 0.01))

	func _glow(at: Vector2, r: float, col: Color) -> void:
		for i in range(6):
			draw_circle(at, r * (1.0 - i * 0.13), Color(col, 0.035 + i * 0.02))

	func symbol(kind_: String, at: Vector2, s: float) -> void:
		var col: Color = COLORS[kind_]
		var hot := col.lightened(0.45)
		_glow(at, s * 1.15, col)
		match kind_:
			"still":
				for i in range(3):
					draw_arc(at, s * (0.28 + i * 0.26), 0, TAU, 32, col if i < 2 else Color(col, 0.6), 1.0)
				draw_circle(at, s * 0.12, hot)
			"ember":
				var pts := PackedVector2Array()
				for i in range(24):
					var a := TAU * i / 24.0
					var rr := s * (0.5 + 0.38 * pow(maxf(-sin(a), 0.0), 3.0))
					pts.append(at + Vector2(cos(a) * s * 0.5 * (1.0 - 0.45 * maxf(-sin(a), 0.0)), -absf(sin(a)) * 0.0 + sin(a) * rr * 0.9 + s * 0.15))
				draw_colored_polygon(pts, col)
				var inner := PackedVector2Array()
				for p in pts:
					inner.append(at + (p - at) * 0.5 + Vector2(0, s * 0.18))
				draw_colored_polygon(inner, hot)
			"crown":
				var w := s * 0.9
				var pts := PackedVector2Array([at + Vector2(-w, s * 0.45), at + Vector2(-w, -s * 0.35), at + Vector2(-w * 0.5, s * 0.02),
					at + Vector2(0, -s * 0.6), at + Vector2(w * 0.5, s * 0.02), at + Vector2(w, -s * 0.35), at + Vector2(w, s * 0.45)])
				draw_colored_polygon(pts, col)
				draw_rect(Rect2(at + Vector2(-w, s * 0.3), Vector2(w * 2.0, s * 0.18)), hot)
				for x in [-w, 0.0, w]:
					draw_circle(at + Vector2(x, -s * (0.6 if x == 0.0 else 0.35)), s * 0.1, hot)
			"storm":
				var pts := PackedVector2Array([at + Vector2(s * 0.15, -s * 0.8), at + Vector2(-s * 0.45, s * 0.1), at + Vector2(-s * 0.02, s * 0.1),
					at + Vector2(-s * 0.2, s * 0.8), at + Vector2(s * 0.45, -s * 0.15), at + Vector2(s * 0.02, -s * 0.15)])
				draw_colored_polygon(pts, col)
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3]]), hot, 1.0)
			"tide":
				var prev := at
				for i in range(60):
					var a := i * 0.22
					var rr := s * 0.06 * exp(0.105 * i * 0.6)
					var p := at + Vector2(cos(a), sin(a)) * minf(rr, s * 0.85)
					if i > 0:
						draw_line(prev, p, col.lerp(hot, float(i) / 60.0), 2.0)
					prev = p

	func _label(text: String, centre: Vector2, sz: int, col: Color, f: Font) -> void:
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string_outline(f, Vector2(centre.x - w * 0.5, centre.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 3, Color(0.02, 0.03, 0.06))
		draw_string(f, Vector2(centre.x - w * 0.5, centre.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

	func _banner() -> void:
		_sky()
		var c := Vector2(size.x * 0.5, size.y * 0.36)
		# the eddy behind the word: rings turning on themselves
		for i in range(5):
			draw_arc(c, 34.0 + i * 11.0, i * 0.9, i * 0.9 + PI * 1.4, 40, Color(0.79, 0.66, 1.0, 0.22 - i * 0.03), 1.0)
		_label("EDY", c + Vector2(0, 18), 64, Color(0.95, 0.92, 0.85), font_b)
		_label("THE FORCE THAT TURNS ON ITSELF", c + Vector2(0, 40), 8, Color(0.79, 0.66, 1.0), font)
		for i in range(TYPES.size()):
			var x := size.x * (0.14 + i * 0.18)
			var at := Vector2(x, size.y * 0.74)
			symbol(TYPES[i], at, 17.0)
			_label(NAMES[TYPES[i]], at + Vector2(0, 32), 10, COLORS[TYPES[i]].lightened(0.25), font)

	func _lineup() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.1))
		var cw := size.x / TYPES.size()
		for i in range(TYPES.size()):
			var tex: Texture2D = shots.get(TYPES[i])
			var x0 := cw * i
			if tex:
				# the middle of the frame, where the captain stands
				var src := Rect2(175.0 - cw * 0.5, 0, cw, size.y - 34)
				draw_texture_rect_region(tex, Rect2(Vector2(x0, 0), Vector2(cw, size.y - 34)), src)
			draw_rect(Rect2(Vector2(x0, size.y - 34), Vector2(cw, 34)), Color(0.04, 0.05, 0.1))
			draw_line(Vector2(x0, 0), Vector2(x0, size.y), Color(0.04, 0.05, 0.1), 2.0)
			symbol(TYPES[i], Vector2(x0 + cw * 0.5 - 22, size.y - 17), 8.0)
			_label(NAMES[TYPES[i]], Vector2(x0 + cw * 0.5 + 10, size.y - 13), 10, COLORS[TYPES[i]].lightened(0.25), font)


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]


func _make(kind: String, w: int, h: int) -> SubViewport:
	var sv := SubViewport.new()
	sv.size = Vector2i(w, h)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	var art := Art.new()
	art.kind = kind
	art.size = Vector2(w, h)
	art.font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	art.font_b = load("res://assets/fonts/PixelifySans-SemiBold.woff2")
	for t in TYPES:
		var path := ProjectSettings.globalize_path("res://tools/dev/out/edy/%s_edy_reinforce.png" % t)
		if FileAccess.file_exists(path):
			art.shots[t] = ImageTexture.create_from_image(Image.load_from_file(path))
	sv.add_child(art)
	root.add_child(sv)
	return sv


func _save(sv: SubViewport, name_: String, k: int = SCALE) -> void:
	var img := sv.get_texture().get_image()
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	var dir := ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_jpg(dir + "/%s.jpg" % name_, 0.92)
	var small := img.duplicate() as Image
	small.resize(640, int(640.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_NEAREST)
	small.save_jpg(dir + "/%s-640.jpg" % name_, 0.9)
	print("wrote %s/%s.jpg (%dx%d)" % [dir, name_, img.get_width(), img.get_height()])


var _b: SubViewport
var _l: SubViewport


func _process(_d: float) -> bool:
	step += 1
	if step == 1:
		_b = _make("banner", 400, 225)
		# (the lineup at the stills' own pixels: 160 px round the captain from each 400x260 frame)
		_l = _make("lineup", 800, 294)
	elif step == 6:
		_save(_b, "edy_banner")
		_save(_l, "edy_types", 2)
		return true
	return false
