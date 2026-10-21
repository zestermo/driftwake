class_name RadialWheel
extends CanvasLayer
## The radial wheels: emotes (T), quick items (E), loadouts (X), actions (N). Hold the key, move the
## mouse (or the right stick) toward a segment (the camera holds still), let go (or click, or A) to pick it;
## right click, B or Esc puts it away. A round wheel in the whimsical style (UIStyle, on a crisp PixelCanvas): a dark donut of
## segments in a twisted rope ring with brass nails, each segment a symbol (the entry's 24 px icon, or its
## initial in a medallion) over a short label, the one you point at gilded, greyed ones dim, the current
## choice starred, a count badge where there is one; the hub in the middle names the wheel, or the pointed
## entry in full with its second line.
## A wheel with a tap (tap_ok) opens only once its key is held HOLD s, and a quicker press is _tap().
## One wheel is open at a time, and none while input is locked (a menu, the chat line).
## Subclasses set action, title and tap_ok and fill in _list / _label / _do (and the optional ones).

const R := 118.0
const DEAD := 26.0
const HOLD := 0.2
## How far the right stick must lean to point at a segment.
const STICK := 0.5
const SILK := preload("res://assets/fonts/Silkscreen-Regular.woff2")
const DIM_FILL := Color("102d33")
const SEG_FILL := Color("16404a")

static var shown: RadialWheel

var player: Node
var action: String = ""
var title: String = ""
var tap_ok := false
var entries: Array = []
var _canvas: PixelCanvas
var _root: Control
var _font: Font
var _open := false
var _down := false
var _held := 0.0
var _vec := Vector2.ZERO
var _pick := -1
var _k := 0.0
## What each entry shows, read as the wheel opens: [label, sub, icon, badge].
var _shown: Array = []


# ---- what a wheel fills in ----
func _list() -> Array:
	return []


func _label(_id) -> String:
	return ""


## A second line, shown in the hub when the entry is pointed at ("" = none).
func _sub(_id) -> String:
	return ""


func _icon(_id) -> Texture2D:
	return null


## A small count on the segment ("" = none).
func _badge(_id) -> String:
	return ""


## Shown but greyed (out of stock).
func _dim(_id) -> bool:
	return false


## The current choice (starred).
func _current(_id) -> bool:
	return false


func _do(_id) -> void:
	pass


func _tap() -> void:
	pass


## The hub's words with nothing picked.
func _title() -> String:
	return title


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.name = "Wheel"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.draw.connect(_draw_wheel)
	_canvas = PixelCanvas.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.ui.add_child(_root)
	_font = UIStyle.get_theme().default_font
	_root.visible = false


func is_open() -> bool:
	return _open


func _can_open() -> bool:
	if player == null or player.input_locked or not player.is_local:
		return false
	if shown != null and shown != self:
		return false
	var menu := get_node_or_null("/root/GameMenu")
	return not (menu and menu.is_open()) and not get_node("/root/Dialogue").active


func _open_now() -> void:
	_open = true
	shown = self
	_vec = Vector2.ZERO
	_pick = -1
	entries = _list()
	_shown = entries.map(func(id): return [_label(id), _sub(id), _icon(id), _badge(id)])
	_restyle()


## The label and sub line each entry shows now ([label, sub]).
func shown_text(i: int) -> Array:
	return [_shown[i][0], _shown[i][1]]


func _release() -> void:
	_down = false
	if _open:
		var pick := _pick
		_close()
		if pick >= 0 and pick < entries.size() and not _dim(entries[pick]):
			_do(entries[pick])
	elif tap_ok and _can_open():
		_tap()


func _process(delta: float) -> void:
	if not _down and Input.is_action_just_pressed(action) and _can_open():
		_down = true
		_held = 0.0
		if not tap_ok:
			_open_now()
	if _down and not Input.is_action_pressed(action):
		_release()
	if _down and not _open:
		_held += delta / maxf(Engine.time_scale, 0.05)
		if _held >= HOLD:
			if _can_open():
				_open_now()
			else:
				_down = false
	if _open and not _can_open():
		_close()
		_down = false
	# the right stick points straight at a plank (the camera holds still meanwhile); let go and the pick stays
	if _open:
		var st: Vector2 = Pad.stick()
		if st.length() > STICK:
			_aim(st.normalized() * R)
	_k = move_toward(_k, 1.0 if _open else 0.0, delta * (9.0 if _open else 12.0))
	_root.visible = _k > 0.0
	if _root.visible:
		_root.modulate.a = clampf(_k * 1.5, 0.0, 1.0)
		_root.queue_redraw()


func _close() -> void:
	_open = false
	if shown == self:
		shown = null


func _exit_tree() -> void:
	if shown == self:
		shown = null


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseMotion:
		_aim((_vec + (event as InputEventMouseMotion).screen_relative).limit_length(R))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_LEFT:
			_confirm()
		elif b == MOUSE_BUTTON_RIGHT:
			_cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		# the pad: A picks (as a click), B puts it away (the wheel has the face buttons while it's open)
		var j := (event as InputEventJoypadButton).button_index
		if j == JOY_BUTTON_A:
			_confirm()
		elif j == JOY_BUTTON_B:
			_cancel()
		if j in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_close()
		_down = false
		get_viewport().set_input_as_handled()


## Point the wheel along vec (the mouse's running sum, or the stick): past DEAD it picks the plank that way.
func _aim(vec: Vector2) -> void:
	_vec = vec
	var was := _pick
	_pick = -1
	if _vec.length() > DEAD and not entries.is_empty():
		var a := fposmod(atan2(_vec.x, -_vec.y), TAU)
		_pick = int(round(a / (TAU / entries.size()))) % entries.size()
	if _pick != was:
		_restyle()


func _confirm() -> void:
	if _pick < 0:
		return
	var id = entries[_pick]
	_close()
	_down = false
	if not _dim(id):
		_do(id)


func _cancel() -> void:
	_close()
	_down = false


## Point at an entry (tests, and the wheels that open on their current choice).
func point_at(i: int) -> void:
	_pick = i
	if entries.size() > 0 and i >= 0:
		var a := TAU * i / entries.size()
		_vec = Vector2(sin(a), -cos(a)) * R * 0.6
	_restyle()


func _restyle() -> void:
	_root.queue_redraw()


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------
## The ring's middle radius: room for every segment's symbol and label.
func _mid_r() -> float:
	return maxf(64.0, entries.size() * 50.0 / TAU)


## A label cut to `w` px: whole if it fits, else its first word, else letters off the end.
func _short(s: String, w: float) -> String:
	s = s.to_upper()
	if SILK.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x <= w:
		return s
	var first := s.get_slice(" ", 0)
	if SILK.get_string_size(first, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x <= w:
		return first
	while s.length() > 1 and SILK.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > w:
		s = s.left(-1)
	return s


func _arc_pts(c: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n + 1):
		var a := lerpf(a0, a1, float(i) / n)
		out.append(c + Vector2(sin(a), -cos(a)) * r)
	return out


## A twisted rope circle of radius r (3 px thick, dark edges).
func _rope(c: Vector2, r: float) -> void:
	_root.draw_arc(c, r, 0.0, TAU, 96, UIChrome.INK, 5.0)
	_root.draw_arc(c, r, 0.0, TAU, 96, UIChrome.ROPE_LO, 3.0)
	var n := int(TAU * r / 6.0)
	for i in range(n):
		var a := TAU * i / n
		_root.draw_arc(c, r, a, a + TAU / n * 0.5, 3, UIChrome.ROPE_HI, 3.0)


func _draw_wheel() -> void:
	var n := entries.size()
	var c := (_root.size * 0.5).round()
	var e := _k * _k * (3.0 - 2.0 * _k)
	var s := e * (1.0 + 0.08 * sin(e * PI))
	_root.draw_set_transform(c * (1.0 - s), 0.0, Vector2(s, s))
	var rm := _mid_r()
	var ri := rm - 24.0
	var ro := rm + 24.0
	var hub := minf(ri - 6.0, 44.0)
	_root.draw_circle(c, ro + 6.0, Color(0, 0, 0, 0.35))
	_root.draw_circle(c, ri, Color(UIStyle.OUTLINE, 0.8))
	for i in range(n):
		var id = entries[i]
		var a := TAU * i / n
		var half := PI / n
		var pts := _arc_pts(c, ro, a - half, a + half, 10)
		var inner := _arc_pts(c, ri, a + half, a - half, 6)
		pts.append_array(inner)
		var on := i == _pick
		var fill := UIStyle.GILT if on else (DIM_FILL if _dim(id) else SEG_FILL)
		_root.draw_colored_polygon(pts, Color(fill, 0.96))
		if on:
			var glow := _arc_pts(c, ro - 3.0, a - half, a + half, 10)
			glow.append_array(_arc_pts(c, rm + 6.0, a + half, a - half, 8))
			_root.draw_colored_polygon(glow, UIChrome.GILT_TOP)
	if n > 1:
		for i in range(n):
			var a := TAU * (i + 0.5) / n
			var d := Vector2(sin(a), -cos(a))
			_root.draw_line(c + d * ri, c + d * ro, UIChrome.INK, 3.0)
			_root.draw_line(c + d * ri, c + d * ro, UIChrome.ROPE_LO, 1.0)
	_rope(c, ro)
	_rope(c, ri)
	if n > 1:
		for i in range(n):
			var a := TAU * (i + 0.5) / n
			_draw_nail((c + Vector2(sin(a), -cos(a)) * ro).round())
	for i in range(n):
		_draw_entry(i, c, rm, minf(TAU * rm / maxf(n, 3) - 6.0, 70.0))
	_draw_hub(c, hub)
	_root.draw_set_transform(Vector2.ZERO)


func _draw_nail(p: Vector2) -> void:
	_root.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), UIChrome.INK)
	_root.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), UIChrome.GILT)
	_root.draw_rect(Rect2(p - Vector2(1, 1), Vector2(1, 1)), UIChrome.TWINKLE)


## A segment's symbol over its short label, its count badge and the current-choice star.
func _draw_entry(i: int, c: Vector2, rm: float, w: float) -> void:
	var id = entries[i]
	var a := TAU * i / entries.size()
	var p := (c + Vector2(sin(a), -cos(a)) * rm).round()
	var on := i == _pick
	var dim := _dim(id)
	var tex: Texture2D = _shown[i][2]
	var sym := Rect2(p + Vector2(-12, -17), Vector2(24, 24))
	if tex:
		_root.draw_texture_rect(tex, sym, false, Color(0.55, 0.6, 0.62, 0.5) if dim and not on else Color.WHITE)
	else:
		var mc := sym.get_center()
		_root.draw_circle(mc, 11.0, UIChrome.INK)
		_root.draw_circle(mc, 10.0, UIChrome.WOOD_LO if on else (SkillTreeDraw.DIM_RIM if dim else UIChrome.ROPE_DIM))
		_root.draw_circle(mc, 9.0, SkillTreeDraw.NODE_BG if not on else UIChrome.WOOD)
		var letter := str(_shown[i][0]).left(1).to_upper()
		_root.draw_string(_font, Vector2(mc.x - 11.0, mc.y + 5.0), letter, HORIZONTAL_ALIGNMENT_CENTER, 22.0, 12,
			SkillTreeDraw.TEXT_OFF if dim else UIStyle.GILT)
	var label := _short(str(_shown[i][0]), w)
	var lp := Vector2(p.x - w * 0.5, p.y + 16.0)
	if on:
		_root.draw_string(SILK, lp, label, HORIZONTAL_ALIGNMENT_CENTER, w, 8, UIChrome.INK)
	else:
		_root.draw_string_outline(SILK, lp, label, HORIZONTAL_ALIGNMENT_CENTER, w, 8, 2, UIStyle.OUTLINE)
		_root.draw_string(SILK, lp, label, HORIZONTAL_ALIGNMENT_CENTER, w, 8, SkillTreeDraw.TEXT_OFF if dim else UIStyle.CREAM)
	var badge := str(_shown[i][3])
	if badge != "":
		var bw := SILK.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0
		var br := Rect2(sym.end.x - bw + 4.0, sym.end.y - 8.0, bw, 9)
		_root.draw_rect(br.grow(1.0), UIChrome.INK)
		_root.draw_rect(br, UIStyle.CORAL if dim else UIStyle.CREAM)
		_root.draw_string(SILK, br.position + Vector2(2, 8), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UIChrome.INK)
	if _current(id):
		UIStyle.draw_star(_root, sym.position + Vector2(1, 1), 7, UIChrome.TWINKLE, true)


## The hub: the wheel's name in blackletter, or the pointed entry's full name and second line.
func _draw_hub(c: Vector2, r: float) -> void:
	_root.draw_circle(c, r + 2.0, UIChrome.INK)
	_root.draw_circle(c, r + 1.0, UIStyle.GILT)
	_root.draw_circle(c, r - 1.0, UIChrome.INK)
	_root.draw_circle(c, r - 2.0, Color("143f46"))
	_root.draw_circle(c + Vector2(-2, -3), r - 8.0, Color("1a4a52"))
	var w := r * 1.7
	if _pick < 0 or _pick >= entries.size():
		var t := _title()
		if UIStyle.TITLE_FONT.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= w:
			UIStyle.draw_title(_root, Vector2(c.x - w * 0.5, c.y + 5.0), t, 18, HORIZONTAL_ALIGNMENT_CENTER, w)
		else:
			var lines := _wrap(t, w, _font, 12)
			for j in range(mini(lines.size(), 3)):
				_root.draw_string(_font, Vector2(c.x - w * 0.5, c.y + 4.0 + (j - (mini(lines.size(), 3) - 1) * 0.5) * 11.0), lines[j], HORIZONTAL_ALIGNMENT_CENTER, w, 12, UIStyle.GILT)
		return
	var name_lines := _wrap(str(_shown[_pick][0]), w, _font, 12)
	var sub_lines := _wrap(str(_shown[_pick][1]).to_upper(), w, SILK, 8)
	name_lines.resize(mini(name_lines.size(), 2))
	sub_lines.resize(mini(sub_lines.size(), 3))
	var h := name_lines.size() * 11.0 + sub_lines.size() * 9.0
	var y := c.y - h * 0.5 + 9.0
	for l in name_lines:
		_root.draw_string(_font, Vector2(c.x - w * 0.5, y), l, HORIZONTAL_ALIGNMENT_CENTER, w, 12, UIStyle.CREAM)
		y += 11.0
	var dim := _dim(entries[_pick])
	for l in sub_lines:
		_root.draw_string(SILK, Vector2(c.x - w * 0.5, y - 1.0), l, HORIZONTAL_ALIGNMENT_CENTER, w, 8, UIStyle.DANGER_TEXT if dim else UIStyle.TEXT_DIM)
		y += 9.0


func _wrap(text: String, w: float, font: Font, sz: int) -> Array:
	var out: Array = []
	var line := ""
	for wd in text.split(" ", false):
		var trial := wd if line == "" else line + " " + wd
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w and line != "":
			out.append(line)
			line = wd
		else:
			line = trial
	if line != "":
		out.append(line)
	return out
