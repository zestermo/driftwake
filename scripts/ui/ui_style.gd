class_name UIStyle
extends RefCounted
## Shared PSX UI look, whimsical and storybook (2026-10-20): slate panels in a rope border with brass nails,
## wooden plank buttons that gild on hover, parchment pages, swallowtail ribbons, rope rules with a gold star,
## wooden keycaps, blackletter titles, a night sky behind the full-screen menus. The pixels are UIChrome's.

const CREAM := Color("f5e8c8")
const TEAL_LIGHT := Color("65c9c0")
const TEAL := Color("277f89")
const CORAL := Color("f17c62")
const SUN := Color("f2c45e")

const BG := Color("1d5e66f2")
const BG_DARK := Color("143f46f5")
const BG_LIGHT := Color("22707a")
const BORDER := SUN
const BORDER_DIM := Color("b88a3a")
const TEXT := CREAM
const TEXT_DIM := Color("dacca8")
const INK := Color("173338")
const INK_DIM := Color("4f625e")
const ACCENT := SUN
const HILITE := TEAL_LIGHT
const DANGER := CORAL
const DANGER_TEXT := Color("ffb39e")
const GOOD := Color("9be08a")
const DISABLED := Color("3c5c5f")
const DISABLED_RIM := Color("5e7470")
const TEXT_DISABLED := Color("93a8a3")
const OUTLINE := Color("0c2427")

## kind -> [corner radius, rim width, bevel (1 raised, -1 sunk, 0 none), ornate (corner caps, rivets, studs, shadow), 9-slice margin]
const KINDS := {
	"panel": [6, 3, 1, true, 20],
	"plank": [4, 1, 1, false, 5],
	"pressed": [4, 1, -1, false, 5],
	"well": [3, 1, -1, false, 4],
	"chip": [2, 1, 0, false, 3],
}

## The whimsical chrome's colours (UIChrome paints with them).
const WOOD_INK := UIChrome.INK
const PARCH := UIChrome.PARCH
const PARCH_INK := Color("2b1a0c")
const PARCH_DIM := Color("6b5a44")
const ROPE := UIChrome.ROPE_HI
const GILT := UIChrome.GILT
const RIBBON_TEXT := Color("fff3e0")

## Titles: a pixel blackletter on a 9 px grid (sizes 9, 18, 27).
const TITLE_FONT := preload("res://assets/fonts/JacquardaBastarda9-Regular.ttf")
const SILK := preload("res://assets/fonts/Silkscreen-Regular.woff2")

static var _theme: Theme
static var _images: Dictionary = {}
static var _boxes: Dictionary = {}
static var _chrome: Dictionary = {}
static var _grads: Dictionary = {}


static func _depth(fx: int, fy: int, r: int) -> int:
	if fx < r and fy < r:
		return floori(r - Vector2(r - fx - 0.5, r - fy - 0.5).length())
	return mini(fx, fy)


## The frame drawn at one image pixel per canvas pixel (also exported for the website by tools/dev/webframes.gd).
static func frame_image(fill: Color, rim: Color, kind: String = "panel", glow: bool = false) -> Image:
	var key := [fill, rim, kind, glow]
	if _images.has(key):
		return _images[key]
	var k: Array = KINDS[kind]
	var r: int = k[0]
	var rw: int = k[1]
	var bevel: int = k[2]
	var orn: bool = k[3]
	var o := 1 if glow or orn else 0
	var s: int = int(k[4]) * 2 + 1
	var n := s + o * 2
	var hi := rim.lerp(CREAM, 0.55)
	var lo := rim.darkened(0.4)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var sx := x - o
			var sy := y - o
			var fx := mini(sx, s - 1 - sx)
			var fy := mini(sy, s - 1 - sy)
			var d := _depth(fx, fy, r)
			var lit := (sy * 2 < s) if fy < fx else (sx * 2 < s)
			var c := Color(0, 0, 0, 0)
			if d < -1:
				pass
			elif d == -1:
				if glow:
					c = Color(rim, 0.5)
				elif orn and not lit:
					c = Color(0, 0, 0, 0.35)
			elif d == 0:
				c = OUTLINE
			elif d <= rw:
				if rw == 1:
					c = rim.lerp(CREAM, 0.3) if lit else rim.darkened(0.25)
				elif d == 1:
					c = hi if lit else rim
				elif d == rw:
					c = rim if lit else lo
				else:
					c = rim
			elif bevel != 0 and d == rw + 1:
				c = Color(fill.darkened(0.5), fill.a)
			elif bevel != 0 and d == rw + 2:
				c = fill.lightened(0.15) if lit == (bevel > 0) else fill.darkened(0.2)
			elif d > rw:
				c = fill
			if orn and d > rw and d <= rw + 2:
				if fx + fy <= 13:
					c = rim if d == rw + 1 else rim.darkened(0.25)
				elif fx + fy == 14:
					c = OUTLINE
			img.set_pixel(x, y, c)
	if orn:
		for a in [o + 3, n - 1 - o - 4]:
			for b in [o + 3, n - 1 - o - 4]:
				img.set_pixel(a, b, CREAM)
				img.set_pixel(a + 1, b, CORAL)
				img.set_pixel(a, b + 1, CORAL)
				img.set_pixel(a + 1, b + 1, CORAL.darkened(0.45))
		for t in [15, 16, 17]:
			var col := CREAM if t == 16 else lo
			for a in [o + t, n - 1 - o - t]:
				img.set_pixel(o + 2, a, col)
				img.set_pixel(n - 1 - o - 2, a, col)
				img.set_pixel(a, o + 2, col)
				img.set_pixel(a, n - 1 - o - 2, col)
	_images[key] = img
	return img


## A rounded gilt 9-slice (shared: copy it before changing its margins). Kinds in KINDS; glow: a soft ring of the rim colour outside.
static func frame(fill: Color, rim: Color, pad: int = 6, kind: String = "panel", glow: bool = false) -> StyleBoxTexture:
	var key := [fill, rim, pad, kind, glow]
	if _boxes.has(key):
		return _boxes[key]
	var k: Array = KINDS[kind]
	var o := 1 if glow or k[3] else 0
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(frame_image(fill, rim, kind, glow))
	sb.set_texture_margin_all(int(k[4]) + o)
	sb.set_expand_margin_all(o)
	var lr := maxi(pad, 7) if k[3] else pad
	var tb := maxi(pad - 2, 6) if k[3] else maxi(pad - 2, 0)
	sb.content_margin_left = lr
	sb.content_margin_right = lr
	sb.content_margin_top = tb
	sb.content_margin_bottom = tb
	_boxes[key] = sb
	return sb


## The menus' panel: slate in a rope border with brass nails. Other colours keep the old gilt frame
## (a danger confirm's coral rim).
static func panel(fill: Color = BG, rim: Color = BORDER, pad: int = 10) -> StyleBoxTexture:
	if fill == BG and rim == BORDER:
		return chrome("slate", maxi(pad, 8), maxi(pad - 2, 6))
	return frame(fill, rim, pad, "panel")


## A chrome 9-slice (UIChrome.KINDS: parchment, paper, slate, plank..., sign, sign_on, ribbon, ribbon_gold,
## keycap, scroll, beam, board, well, rope). Shared: copy it before changing it. pad -1: the kind's own margins.
static func chrome(kind: String, lr: int = -1, tb: int = -1) -> StyleBoxTexture:
	var key := [kind, lr, tb]
	if _chrome.has(key):
		return _chrome[key]
	var k: Array = UIChrome.KINDS[kind]
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(UIChrome.image(kind))
	sb.texture_margin_left = k[0]
	sb.texture_margin_top = k[1]
	sb.texture_margin_right = k[2]
	sb.texture_margin_bottom = k[3]
	var mode := StyleBoxTexture.AXIS_STRETCH_MODE_TILE if k[4] else StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_horizontal = mode
	sb.axis_stretch_vertical = mode
	sb.content_margin_left = k[5] if lr < 0 else lr
	sb.content_margin_right = k[5] if lr < 0 else lr
	sb.content_margin_top = k[6] if tb < 0 else tb
	sb.content_margin_bottom = k[6] if tb < 0 else tb
	_chrome[key] = sb
	return sb


## Parchment for a panel that reads like a page (the skills menu's side cards, the dialogue box).
static func parchment(pad: int = 11, ornate: bool = true) -> StyleBoxTexture:
	return chrome("parchment" if ornate else "paper", pad, maxi(pad - 2, 4))


## A copy of a frame with its own content margins.
static func framed(fill: Color, rim: Color, kind: String, lr: int, tb: int) -> StyleBoxTexture:
	var sb := frame(fill, rim, 0, kind).duplicate() as StyleBoxTexture
	sb.content_margin_left = lr
	sb.content_margin_right = lr
	sb.content_margin_top = tb
	sb.content_margin_bottom = tb
	return sb


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	# Ligatures off: Pixelify's "fi" ligature turns "Outfit" into "OutAt".
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	var ts := TextServerManager.get_primary_interface()
	fv.opentype_features = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0}
	t.default_font = fv
	# compact by default: everything has to fit a 640x360 canvas with room
	# to spare at the edges
	t.default_font_size = 12
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "Panel", panel())
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("normal", "Button", chrome("plank", 5, 3))
	t.set_stylebox("hover", "Button", chrome("plank_hover", 5, 3))
	t.set_stylebox("pressed", "Button", chrome("plank_pressed", 5, 3))
	t.set_stylebox("hover_pressed", "Button", chrome("plank_pressed", 5, 3))
	t.set_stylebox("focus", "Button", chrome("plank_focus", 5, 3))
	t.set_stylebox("disabled", "Button", chrome("plank_dim", 5, 3))
	t.set_color("font_color", "Button", PARCH)
	t.set_color("font_hover_color", "Button", WOOD_INK)
	t.set_color("font_pressed_color", "Button", WOOD_INK)
	t.set_color("font_hover_pressed_color", "Button", WOOD_INK)
	t.set_color("font_focus_color", "Button", PARCH)
	t.set_color("font_disabled_color", "Button", Color("a39a8c"))
	t.set_color("font_outline_color", "Button", Color(WOOD_INK, 0.75))
	t.set_constant("outline_size", "Button", 0)
	t.set_stylebox("normal", "LineEdit", chrome("well", 5, 3))
	t.set_stylebox("focus", "LineEdit", chrome("plank_focus", 5, 3))
	t.set_color("font_color", "LineEdit", PARCH_INK)
	t.set_color("font_placeholder_color", "LineEdit", PARCH_DIM)
	t.set_color("font_selected_color", "LineEdit", PARCH_INK)
	t.set_color("caret_color", "LineEdit", PARCH_INK)
	t.set_color("selection_color", "LineEdit", Color(GILT, 0.6))
	t.set_stylebox("slider", "HSlider", chrome("rope", 0, 1))
	t.set_stylebox("grabber_area", "HSlider", framed(GILT, UIChrome.GILT_LO, "chip", 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", framed(UIChrome.GILT_TOP, UIChrome.GILT_LO, "chip", 0, 2))
	t.set_icon("grabber", "HSlider", _knob(GILT))
	t.set_icon("grabber_highlight", "HSlider", _knob(CREAM))
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, framed(Color("3a2614"), UIChrome.WOOD_LO, "chip", 3, 3))
		t.set_stylebox("grabber", bar, chrome("plank", 3, 3))
		t.set_stylebox("grabber_highlight", bar, chrome("plank_hover", 3, 3))
		t.set_stylebox("grabber_pressed", bar, chrome("plank_pressed", 3, 3))
	var rope := chrome("rope", 0, 0).duplicate() as StyleBoxTexture
	rope.content_margin_top = 1
	rope.content_margin_bottom = 2
	t.set_stylebox("separator", "HSeparator", rope)
	t.set_constant("separation", "HSeparator", 6)
	t.set_stylebox("panel", "TooltipPanel", chrome("paper", 5, 3))
	t.set_color("font_color", "TooltipLabel", PARCH_INK)
	_theme = t
	return t


## A round slider knob: outlined, lit from the top left.
static func _knob(fill: Color) -> ImageTexture:
	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	for y in range(9):
		for x in range(9):
			var d := Vector2(x - 4, y - 4).length()
			if d > 4.4:
				continue
			var c := fill
			if d > 3.4:
				c = OUTLINE
			elif x + y <= 5:
				c = fill.lerp(Color.WHITE, 0.5)
			elif x + y >= 11:
				c = fill.darkened(0.3)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func label(text: String, size: int = 12, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A heading in the blackletter: gilt on a dark outline (`on_paper`: brown ink on parchment).
static func title(text: String, size: int = 18, on_paper: bool = false) -> Label:
	var l := label(text, size, PARCH_INK if on_paper else GILT)
	l.add_theme_font_override("font", TITLE_FONT)
	if not on_paper:
		l.add_theme_color_override("font_outline_color", WOOD_INK)
		l.add_theme_constant_override("outline_size", 2)
		l.add_theme_color_override("font_shadow_color", Color(CORAL.darkened(0.55), 0.9))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 1)
		l.add_theme_constant_override("shadow_outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Draw a blackletter title on a canvas item (its baseline at `pos`).
static func draw_title(ci: CanvasItem, pos: Vector2, text: String, size: int = 18, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, on_paper: bool = false) -> void:
	if on_paper:
		ci.draw_string(TITLE_FONT, pos, text, align, w, size, PARCH_INK)
		return
	ci.draw_string_outline(TITLE_FONT, pos + Vector2(0, 1), text, align, w, size, 2, Color(CORAL.darkened(0.55), 0.9))
	ci.draw_string_outline(TITLE_FONT, pos, text, align, w, size, 2, WOOD_INK)
	ci.draw_string(TITLE_FONT, pos, text, align, w, size, GILT)


## A swallowtail banner heading (red, or `gold`) in Silkscreen 8.
static func ribbon(text: String, gold: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chrome("ribbon_gold" if gold else "ribbon"))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text.to_upper(), 8, PARCH_INK if gold else RIBBON_TEXT)
	l.add_theme_font_override("font", SILK)
	if not gold:
		l.add_theme_color_override("font_shadow_color", Color("6e1f17"))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 1)
	p.add_child(l)
	return p


## Draw a ribbon with its text from `pos` (top left); returns its rect.
static func draw_ribbon(ci: CanvasItem, pos: Vector2, text: String, gold: bool = false) -> Rect2:
	var s := text.to_upper()
	var w := SILK.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 18.0
	var r := Rect2(pos, Vector2(w, 12))
	ci.draw_style_box(chrome("ribbon_gold" if gold else "ribbon"), r)
	if not gold:
		ci.draw_string(SILK, pos + Vector2(9, 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("6e1f17"))
	ci.draw_string(SILK, pos + Vector2(9, 9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, PARCH_INK if gold else RIBBON_TEXT)
	return r


## A rope divider with a gold star in the middle, as a control (7 px tall).
static func rule() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 7)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): draw_rule(c, Rect2(Vector2.ZERO, c.size)))
	return c


static func draw_rule(ci: CanvasItem, r: Rect2) -> void:
	var y := floorf(r.get_center().y) - 1.0
	ci.draw_style_box(chrome("rope", 0, 0), Rect2(r.position.x, y, r.size.x, 3))
	draw_star(ci, Vector2(floorf(r.get_center().x), y + 1.0), 7, GILT, true)


## A four-point twinkle `n` px across (odd), centred on `c`.
static func draw_star(ci: CanvasItem, c: Vector2, n: int = 7, col: Color = UIChrome.TWINKLE, outline: bool = false) -> void:
	var key := "star%d%s%s" % [n, col.to_html(), outline]
	if not _grads.has(key):
		_grads[key] = ImageTexture.create_from_image(UIChrome.star(n, Color(col, 1.0), outline))
	var t: Texture2D = _grads[key]
	ci.draw_texture(t, (c - t.get_size() * 0.5).floor(), Color(1, 1, 1, col.a))


## A doubloon `d` px across centred on `c` with `text` on its face.
static func draw_coin(ci: CanvasItem, c: Vector2, text: String, d: int = 19) -> void:
	var key := "coin%d" % d
	if not _grads.has(key):
		_grads[key] = ImageTexture.create_from_image(UIChrome.coin(d))
	var p := (c - Vector2(d, d) * 0.5).floor()
	ci.draw_texture(_grads[key], p)
	ci.draw_string(SILK, Vector2(p.x, p.y + d * 0.5 + 4.0), text, HORIZONTAL_ALIGNMENT_CENTER, d, 8, PARCH_INK)


# --------------------------------------------------------------------------
# The menus' frame: a night sky, the wooden beam with its hanging signs, the key board.
# --------------------------------------------------------------------------
static func _gradient(key: String, cols: Array, offs: Array, from := Vector2(0.5, 0.5), to := Vector2(1.0, 0.5)) -> GradientTexture2D:
	if _grads.has(key):
		return _grads[key]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = from
	t.fill_to = to
	t.width = 320
	t.height = 180
	_grads[key] = t
	return t


static var _stars: PackedVector3Array = PackedVector3Array()


## The menus' night sky over `r`: deep teal, soft violet and teal nebulae, twinkling stars, a dark rim and a
## dashed map border. `t` is game time in seconds (the twinkle).
static func draw_sky(ci: CanvasItem, r: Rect2, t: float, border: bool = true) -> void:
	if _stars.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in range(110):
			_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	ci.draw_texture_rect(_gradient("sky", [Color("1f5560"), Color("10313a"), Color("081a1f")], [0.0, 0.45, 1.0], Vector2(0.38, 0.55), Vector2(1.05, 0.9)), r, false)
	ci.draw_texture_rect(_gradient("neb_v", [Color(0.79, 0.66, 1.0, 0.13), Color(0.79, 0.66, 1.0, 0.0)], [0.0, 0.7]),
		Rect2(r.position + r.size * Vector2(-0.22, 0.0), r.size * Vector2(0.8, 0.6)), false)
	ci.draw_texture_rect(_gradient("neb_t", [Color(0.4, 0.79, 0.75, 0.13), Color(0.4, 0.79, 0.75, 0.0)], [0.0, 0.7]),
		Rect2(r.position + r.size * Vector2(0.37, 0.35), r.size * Vector2(0.9, 0.7)), false)
	for s in _stars:
		var big := s.z > 0.82
		var a := (0.35 if not big else 0.6) + 0.3 * sin(t * (1.1 + s.z) + s.x * 40.0)
		ci.draw_rect(Rect2((r.position + Vector2(s.x, s.y) * r.size).floor(), Vector2(2, 2) if big and s.z > 0.95 else Vector2(1, 1)),
			Color(UIChrome.TWINKLE if big else TEXT_DIM, clampf(a, 0.1, 1.0)))
	ci.draw_texture_rect(_gradient("vignette", [Color(0.02, 0.06, 0.07, 0.0), Color(0.02, 0.06, 0.07, 0.0), Color(0.02, 0.06, 0.07, 0.55)], [0.0, 0.55, 1.0], Vector2(0.5, 0.5), Vector2(1.08, 1.08)), r, false)
	if border:
		var b := r.grow(-3.0)
		var col := Color(0.855, 0.8, 0.66, 0.22)
		ci.draw_dashed_line(b.position + Vector2(6, 0), Vector2(b.end.x - 6, b.position.y), col, 1.0, 3.0)
		ci.draw_dashed_line(Vector2(b.position.x + 6, b.end.y), b.end - Vector2(6, 0), col, 1.0, 3.0)
		ci.draw_dashed_line(b.position + Vector2(0, 6), Vector2(b.position.x, b.end.y - 6), col, 1.0, 3.0)
		ci.draw_dashed_line(Vector2(b.end.x, b.position.y + 6), b.end - Vector2(0, 6), col, 1.0, 3.0)


## The tab icon textures by name (UIIcons: crown, swords, compass, chest, fruit).
static func tab_icon(id: String) -> Texture2D:
	return UIIcons.tex(id)


## The menus' top bar across `w`: the wooden beam over its rope, the compass-rose emblem, a hanging wooden sign
## per tab ([[label, icon texture], ...]; the `active` one gilded, hanging lower, twinkling), and on the right
## the parchment nameplate with a doubloon (`level`, `frac` of the way to the next). Returns each sign's rect.
static func draw_topbar(ci: CanvasItem, w: float, tabs: Array, active: int, t: float, level: int = -1, frac: float = 0.0, plate_text: String = "") -> Array:
	ci.draw_style_box(chrome("beam", 0, 0), Rect2(-2, 0, w + 4, UIChrome.BEAM_H))
	_draw_emblem(ci, Vector2(15, 12))
	var rects := draw_tabs(ci, 32.0, 0.0, tabs, active, t)
	if level >= 0:
		draw_plate(ci, Vector2(w - 8.0, 2.0), level, frac, plate_text)
	return rects


static func _draw_emblem(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_circle(c + Vector2(0, 1), 11.5, Color(0, 0, 0, 0.35))
	ci.draw_circle(c, 11.0, WOOD_INK)
	ci.draw_circle(c, 10.0, UIChrome.ROPE_DIM)
	ci.draw_circle(c, 8.5, WOOD_INK)
	ci.draw_circle(c, 7.5, Color("1a4a52"))
	ci.draw_circle(c + Vector2(-1, -1), 5.0, Color("2a6a73"))
	var e := UIIcons.tex("emblem", 0.5)
	ci.draw_texture(e, (c - e.get_size() * 0.5).floor())


## Hanging signs from `top` starting at `x`; returns their rects.
static func draw_tabs(ci: CanvasItem, x: float, top: float, tabs: Array, active: int, t: float) -> Array:
	var rects: Array = []
	var tilts := [-2.0, 1.5, -1.0, 2.0, -1.5]
	var drops := [0.0, 2.0, 1.0, 3.0, 1.0]
	for i in range(tabs.size()):
		var on := i == active
		var label_s := str(tabs[i][0]).to_upper()
		var icon: Texture2D = tabs[i][1]
		var tw := SILK.get_string_size(label_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var w := roundf(tw + 16.0 + 4.0 + (16.0 if on else 12.0))
		var h := 22.0 if on else 20.0
		var y: float = top + 4.0 + drops[i % drops.size()] + (4.0 if on else 0.0)
		var r := Rect2(x, y, w, h)
		for rx in [x + 6.0, x + w - 8.0]:
			ci.draw_rect(Rect2(rx + 2.0, top, 1, y - top + 1.0), Color(WOOD_INK, 0.6))
			for ry in range(int(top), int(y) + 2):
				ci.draw_rect(Rect2(rx, ry, 2, 1), UIChrome.ROPE_HI if (ry + (1 if rx > x + 10.0 else 0)) % 2 == 0 else UIChrome.ROPE_LO)
			ci.draw_rect(Rect2(rx - 1.0, top, 4, 1), WOOD_INK)
		var c := r.get_center()
		ci.draw_set_transform(c + Vector2(0, 2), deg_to_rad(tilts[i % tilts.size()]), Vector2.ONE)
		ci.draw_rect(Rect2(-r.size * 0.5 + Vector2(1, 0), r.size), Color(0, 0, 0, 0.3))
		ci.draw_set_transform(c, deg_to_rad(tilts[i % tilts.size()]), Vector2.ONE)
		ci.draw_style_box(chrome("sign_on" if on else "sign", 0, 0), Rect2(-r.size * 0.5, r.size))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var ix := x + (8.0 if on else 6.0)
		ci.draw_texture(icon, Vector2(ix, floorf(c.y) - 8.0))
		var tp := Vector2(ix + 20.0, floorf(c.y) + 4.0)
		if not on:
			ci.draw_string(SILK, tp + Vector2(0, 1), label_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, WOOD_INK)
		ci.draw_string(SILK, tp, label_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, WOOD_INK if on else PARCH)
		if on:
			draw_star(ci, Vector2(r.end.x - 1.0, r.position.y + 1.0), 7, Color(UIChrome.TWINKLE, 0.55 + 0.45 * sin(t * 3.0)), true)
		rects.append(r)
		x += w + 6.0
	return rects


## The parchment nameplate ending at `right` (top at y): a doubloon with the level, a line of text, an XP bar.
static func draw_plate(ci: CanvasItem, at: Vector2, level: int, frac: float, text: String = "") -> Rect2:
	var s := text if text != "" else "CAPTAIN · LEVEL %d" % level
	var tw := SILK.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := maxf(tw, 52.0) + 30.0
	var r := Rect2(at.x - w, at.y + 2.0, w, 19)
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.3))
	ci.draw_style_box(chrome("scroll", 0, 0), r)
	draw_coin(ci, r.position + Vector2(9, 9), str(level))
	ci.draw_string(SILK, r.position + Vector2(21, 9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("5a3b22"))
	var bar := Rect2(r.position + Vector2(21, 12), Vector2(w - 28.0, 3))
	ci.draw_rect(bar.grow(1.0), UIChrome.ROPE_DARK)
	ci.draw_rect(bar, Color("d9cdb0"))
	ci.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(frac, 0.0, 1.0)), 3)), TEAL)
	return r


## The key-hint board along the bottom of `w` (its top at y): a rope over dark wood, the hints on wooden keycaps.
static func draw_board(ci: CanvasItem, y: float, w: float, pairs: Array) -> void:
	ci.draw_style_box(chrome("board", 0, 0), Rect2(-2, y, w + 4, UIChrome.BOARD_H))
	draw_hints(ci, Vector2(10, y + 14), pairs, SILK)


## Shrink a centered panel (via scale) if it would run off the screen,
## keeping `margin` canvas pixels clear on every side. Call after layout.
static func fit_to_screen(c: Control, margin: float = 10.0) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.scale = Vector2.ONE
	var vis := c.get_viewport_rect().size
	var sz := c.get_combined_minimum_size().max(c.size)
	var k := minf(1.0, minf((vis.x - margin * 2.0) / maxf(sz.x, 1.0), (vis.y - margin * 2.0) / maxf(sz.y, 1.0)))
	c.pivot_offset = sz * 0.5
	c.scale = Vector2(k, k)


## The menus' sounds on the UI bus: name -> [file in res://assets/audio, volume_db].
const SOUNDS := {
	"move": ["ui_move", -10.0], "confirm": ["ui_confirm", -7.0], "back": ["ui_back", -7.0], "deny": ["ui_deny", -6.0],
	"open": ["ui_open", -6.0], "close": ["ui_close", -6.0], "equip": ["equip", -5.0], "unequip": ["unequip", -5.0],
	"buy": ["ui_buy", -5.0], "sell": ["ui_sell", -5.0], "coin": ["coin", -8.0], "level_up": ["level_up", -3.0],
	"quest_accept": ["quest_accept", -4.0], "quest_done": ["quest_done", -3.0], "select": ["select", -8.0],
	"sizzle": ["sizzle", -6.0],
}
## A button whose text is one of these sounds "back" when pressed, the rest "confirm".
const BACK_WORDS := ["Back", "Cancel", "Close", "Leave", "Resume", "Not yet", "No"]
static var _sound_players: Dictionary = {}
## Every menu sound played, newest last (tests read it).
static var played: Array = []
static var _last_ms: int = -1000
static var _count: int = 0


## A player per menu sound under `host` (GameMenu: it runs while the game is paused).
static func make_sound_players(host: Node) -> void:
	for k in SOUNDS:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.wav" % SOUNDS[k][0])
		p.volume_db = SOUNDS[k][1]
		p.bus = "UI"
		p.max_polyphony = 3
		host.add_child(p)
		_sound_players[k] = p


## Play a menu sound (SOUNDS). A "move" right after another sound is dropped (the focus
## landing on a screen's first button as it opens, a click focusing what it pressed).
## The attention pip: a small gold square with a slow pulse, centred on `c`, on anything there's something new to do in
## (a menu tab, the Perks button, a Will path, the level badge, a new item). The same mark everywhere, so it's learned once.
static func draw_pip(ci: CanvasItem, c: Vector2, t: float) -> void:
	var a := 0.5 + 0.5 * sin(t * 4.0)
	c = c.round()
	ci.draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), Color(GILT, 0.12 + 0.2 * a))
	ci.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), OUTLINE)
	ci.draw_rect(Rect2(c - Vector2(2, 2), Vector2(4, 4)), GILT.lerp(CREAM, 0.25 * a))
	ci.draw_rect(Rect2(c - Vector2(2, 2), Vector2(1, 1)), CREAM)


static func sfx(what: String) -> void:
	var now := Time.get_ticks_msec()
	if what == "move" and now - _last_ms < 150:
		return
	_last_ms = now
	_count += 1
	played.append(what)
	if played.size() > 40:
		played.pop_front()
	var p: AudioStreamPlayer = _sound_players[what]
	p.pitch_scale = randf_range(0.98, 1.02)
	p.play()


## Sounds for a button: a tick on hover or focus, and on press "confirm" (or "back", or
## `sound`), unless what it does plays a sound of its own (buy, equip, deny...).
static func button_sounds(b: BaseButton, sound: String = "") -> void:
	if sound == "":
		sound = "back" if b is Button and (b as Button).text in BACK_WORDS else "confirm"
	b.mouse_entered.connect(func():
		if not b.disabled:
			sfx("move"))
	b.focus_entered.connect(func(): sfx("move"))
	b.pressed.connect(func():
		var n := _count
		(func():
			if _count == n:
				sfx(sound)).call_deferred())


static func button(text: String, min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 0)
	b.focus_mode = Control.FOCUS_ALL
	button_sounds(b)
	return b


## A button for something that can't be undone (delete, overwrite): a coral plank.
static func danger(b: Button) -> Button:
	b.add_theme_stylebox_override("normal", frame(CORAL.darkened(0.35), BORDER_DIM, 5, "plank"))
	b.add_theme_stylebox_override("hover", frame(CORAL, SUN, 5, "plank"))
	return b


## A "< value >" selector that emits "stepped"(-1) from its left half, a right-click or left
## on a keyboard / pad, and "stepped"(1) from its right half, right or accept. The listener wraps.
static func stepper(min_width: float = 0.0) -> Button:
	var b := button("", min_width)
	b.add_user_signal("stepped", [{"name": "d", "type": TYPE_INT}])
	b.gui_input.connect(func(ev: InputEvent):
		var d := 0
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				d = -1 if ev.position.x < b.size.x * 0.5 else 1
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				d = -1
		elif ev.is_action_pressed("ui_left", true):
			d = -1
		elif ev.is_action_pressed("ui_right", true) or ev.is_action_pressed("ui_accept"):
			d = 1
		if d != 0 and not b.disabled:
			b.accept_event()
			sfx("select")
			b.emit_signal("stepped", d))
	return b


## A key cap ("F", "TAB"): its label is the cap's only child.
static func key_cap(key: String, on_paper: bool = false) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := chrome("keycap", 3, 0).duplicate() as StyleBoxTexture
	sb.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", sb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := label(key, 8, PARCH_INK)
	k.add_theme_font_override("font", SILK)
	chip.add_child(k)
	return chip


## A key cap and what it does ("TAB" "CLOSE"), in Silkscreen 8: cream text outlined for teal,
## ink (`on_paper`) for parchment.
static func key_hint(key: String, what: String, on_paper: bool = false) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(key_cap(key, on_paper))
	var l := label(what, 8, PARCH_INK if on_paper else PARCH)
	l.add_theme_font_override("font", SILK)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not on_paper:
		l.add_theme_color_override("font_outline_color", WOOD_INK)
		l.add_theme_constant_override("outline_size", 2)
	hb.add_child(l)
	return hb


## Key caps and what they do ([["TAB", "NEXT TREE"], ...]) drawn in a row from `pos` (the
## text's baseline) on a canvas item, for the screens drawn by hand; returns where the row ends.
static func draw_hints(ci: CanvasItem, pos: Vector2, pairs: Array, font: Font, on_paper: bool = false) -> float:
	var x := pos.x
	for p in pairs:
		var k := str(p[0])
		var kw := font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		ci.draw_style_box(chrome("keycap", 0, 0), Rect2(x, pos.y - 9.0, kw + 7.0, 13.0))
		ci.draw_string(font, Vector2(x + 4.0, pos.y), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, PARCH_INK)
		x += kw + 10.0
		var l := str(p[1])
		if not on_paper:
			ci.draw_string_outline(font, Vector2(x, pos.y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, WOOD_INK)
		ci.draw_string(font, Vector2(x, pos.y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, PARCH_INK if on_paper else PARCH)
		x += font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0
	return x


static func stepper_text(value: String) -> String:
	return "<  %s  >" % value
