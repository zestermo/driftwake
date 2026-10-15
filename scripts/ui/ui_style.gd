class_name UIStyle
extends RefCounted
## Shared PSX UI look: deep-teal panels in a gilt pixel frame, cream text, plank buttons.

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

static var _theme: Theme
static var _images: Dictionary = {}
static var _boxes: Dictionary = {}


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


static func panel(fill: Color = BG, rim: Color = BORDER, pad: int = 10) -> StyleBoxTexture:
	return frame(fill, rim, pad, "panel")


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
	t.set_stylebox("normal", "Button", frame(BG_LIGHT, BORDER_DIM, 5, "plank"))
	t.set_stylebox("hover", "Button", frame(HILITE, SUN, 5, "plank"))
	t.set_stylebox("pressed", "Button", frame(SUN, BORDER_DIM, 5, "pressed"))
	t.set_stylebox("hover_pressed", "Button", frame(SUN, CREAM, 5, "pressed"))
	t.set_stylebox("focus", "Button", frame(Color(0, 0, 0, 0), SUN, 5, "plank", true))
	t.set_stylebox("disabled", "Button", frame(DISABLED, DISABLED_RIM, 5, "plank"))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_stylebox("normal", "LineEdit", frame(CREAM, BORDER_DIM, 4, "well"))
	t.set_stylebox("focus", "LineEdit", frame(Color(0, 0, 0, 0), SUN, 4, "well", true))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_DIM)
	t.set_color("font_selected_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", Color(TEAL_LIGHT, 0.7))
	t.set_stylebox("slider", "HSlider", framed(BG_DARK, BORDER_DIM, "chip", 0, 3))
	t.set_stylebox("grabber_area", "HSlider", framed(SUN, BORDER_DIM, "chip", 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", framed(SUN, CREAM, "chip", 0, 3))
	t.set_icon("grabber", "HSlider", _knob(SUN))
	t.set_icon("grabber_highlight", "HSlider", _knob(CREAM))
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, framed(BG_DARK, BORDER_DIM, "chip", 3, 3))
		t.set_stylebox("grabber", bar, framed(BG_LIGHT, BORDER_DIM, "chip", 3, 3))
		t.set_stylebox("grabber_highlight", bar, framed(HILITE, SUN, "chip", 3, 3))
		t.set_stylebox("grabber_pressed", bar, framed(SUN, BORDER_DIM, "chip", 3, 3))
	var rule := StyleBoxLine.new()
	rule.color = BORDER_DIM
	rule.thickness = 1
	t.set_stylebox("separator", "HSeparator", rule)
	t.set_constant("separation", "HSeparator", 6)
	t.set_stylebox("panel", "TooltipPanel", frame(CREAM, BORDER_DIM, 5, "plank"))
	t.set_color("font_color", "TooltipLabel", INK)
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


static func title(text: String) -> Label:
	var l := label(text, 22, ACCENT)
	l.add_theme_font_override("font", load("res://assets/fonts/PixelifySans-SemiBold.woff2"))
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_shadow_color", CORAL.darkened(0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


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
	var sb := framed(CREAM if not on_paper else Color("e8d6ae"), BORDER_DIM, "chip", 2, 0)
	sb.content_margin_top = 1
	chip.add_theme_stylebox_override("panel", sb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := label(key, 8, INK)
	k.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	chip.add_child(k)
	return chip


## A key cap and what it does ("TAB" "CLOSE"), in Silkscreen 8: cream text outlined for teal,
## ink (`on_paper`) for parchment.
static func key_hint(key: String, what: String, on_paper: bool = false) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(key_cap(key, on_paper))
	var l := label(what, 8, INK if on_paper else TEXT)
	l.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not on_paper:
		l.add_theme_color_override("font_outline_color", OUTLINE)
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
		ci.draw_style_box(frame(CREAM, BORDER_DIM, 0, "chip"), Rect2(x, pos.y - 8.0, kw + 6.0, 11.0))
		ci.draw_string(font, Vector2(x + 3.0, pos.y), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
		x += kw + 9.0
		var l := str(p[1])
		if not on_paper:
			ci.draw_string_outline(font, Vector2(x, pos.y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, OUTLINE)
		ci.draw_string(font, Vector2(x, pos.y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK if on_paper else TEXT)
		x += font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0
	return x


static func stepper_text(value: String) -> String:
	return "<  %s  >" % value
