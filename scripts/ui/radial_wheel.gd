class_name RadialWheel
extends CanvasLayer
## The radial wheels: emotes (T), quick items (E), loadouts (X), actions (N). Hold the key, move the
## mouse toward a plank (the camera holds still), let go (or click) to pick it; right click or Esc
## puts it away. Gilt planks round a dark ring (UIStyle, on a crisp PixelCanvas), the one you point at
## lit in light teal, its name in the ornate plate in the middle; the current choice has a sun rim.
## A wheel with a tap (tap_ok) opens only once its key is held HOLD s, and a quicker press is _tap().
## One wheel is open at a time, and none while input is locked (a menu, the chat line).
## Subclasses set action, title and tap_ok and fill in _list / _label / _do (and the optional ones).

const R := 118.0
const DEAD := 26.0
const HOLD := 0.2
const SUB_FONT := preload("res://assets/fonts/Silkscreen-Regular.woff2")

static var shown: RadialWheel

var player: Node
var action: String = ""
var title: String = ""
var tap_ok := false
var entries: Array = []
var _canvas: PixelCanvas
var _root: Control
var _plates: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _subs: Array[Label] = []
var _centre: Label
var _open := false
var _down := false
var _held := 0.0
var _vec := Vector2.ZERO
var _pick := -1
var _k := 0.0


# ---- what a wheel fills in ----
func _list() -> Array:
	return []


func _label(_id) -> String:
	return ""


## A second, smaller line under the label ("" = none).
func _sub(_id) -> String:
	return ""


func _icon(_id) -> Texture2D:
	return null


## Shown but greyed (out of stock).
func _dim(_id) -> bool:
	return false


## The current choice (a sun rim).
func _current(_id) -> bool:
	return false


func _do(_id) -> void:
	pass


func _tap() -> void:
	pass


## The centre plate's words with nothing picked.
func _title() -> String:
	return title


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.name = "Wheel"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_ring)
	_canvas = PixelCanvas.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.ui.add_child(_root)
	var mid := PanelContainer.new()
	mid.name = "Centre"
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 8))
	_centre = UIStyle.label(title, 12, UIStyle.ACCENT)
	_centre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centre.custom_minimum_size = Vector2(84, 0)
	mid.add_child(_centre)
	_root.add_child(mid)
	_root.visible = false


func _build_plates() -> void:
	for pc in _plates:
		pc.queue_free()
	_plates.clear()
	_labels.clear()
	_subs.clear()
	for id in entries:
		var pc := PanelContainer.new()
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(row)
		var tex := _icon(id)
		if tex:
			var ic := TextureRect.new()
			ic.texture = tex
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.custom_minimum_size = Vector2(16, 16)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var l := UIStyle.label(_label(id), 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		var s := UIStyle.label("", 8, UIStyle.TEXT_DIM)
		s.add_theme_font_override("font", SUB_FONT)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(s)
		_root.add_child(pc)
		_plates.append(pc)
		_labels.append(l)
		_subs.append(s)


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
	var want := _list()
	if want != entries or _plates.size() != want.size():
		entries = want
		_build_plates()
	for i in range(entries.size()):
		_labels[i].text = _label(entries[i])
		_subs[i].text = _sub(entries[i])
		_subs[i].visible = _subs[i].text != ""
	_restyle()


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
	_k = move_toward(_k, 1.0 if _open else 0.0, delta * (9.0 if _open else 12.0))
	_root.visible = _k > 0.0
	if _root.visible:
		_layout()


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
		_vec = (_vec + (event as InputEventMouseMotion).screen_relative).limit_length(R)
		var was := _pick
		_pick = -1
		if _vec.length() > DEAD and not entries.is_empty():
			var a := fposmod(atan2(_vec.x, -_vec.y), TAU)
			_pick = int(round(a / (TAU / entries.size()))) % entries.size()
		if _pick != was:
			_restyle()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_LEFT and _pick >= 0:
			var id = entries[_pick]
			_close()
			_down = false
			if not _dim(id):
				_do(id)
		elif b == MOUSE_BUTTON_RIGHT:
			_close()
			_down = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_close()
		_down = false
		get_viewport().set_input_as_handled()


## Point at an entry (tests, and the wheels that open on their current choice).
func point_at(i: int) -> void:
	_pick = i
	if entries.size() > 0 and i >= 0:
		var a := TAU * i / entries.size()
		_vec = Vector2(sin(a), -cos(a)) * R * 0.6
	_restyle()


func _restyle() -> void:
	for i in range(_plates.size()):
		var on := i == _pick
		var id = entries[i]
		var dim := _dim(id)
		var rim := UIStyle.ACCENT if on or _current(id) else UIStyle.BORDER_DIM
		_plates[i].add_theme_stylebox_override("panel", UIStyle.frame(UIStyle.HILITE if on else (UIStyle.DISABLED if dim else UIStyle.BG_LIGHT), rim, 6, "plank", on))
		_labels[i].add_theme_color_override("font_color", UIStyle.INK if on else (UIStyle.TEXT_DISABLED if dim else UIStyle.TEXT))
		_subs[i].add_theme_color_override("font_color", UIStyle.INK_DIM if on else UIStyle.TEXT_DIM)
	_centre.text = _label(entries[_pick]) if _pick >= 0 else _title()


## The planks round the ring (popping out from the middle as it opens).
func _layout() -> void:
	var c := _root.size * 0.5
	var e := _k * _k * (3.0 - 2.0 * _k)
	var s := e * (1.0 + 0.1 * sin(e * PI))
	for i in range(_plates.size()):
		var a := TAU * i / _plates.size()
		var pc := _plates[i]
		pc.size = pc.get_combined_minimum_size()
		pc.position = c + Vector2(sin(a), -cos(a)) * R * s - pc.size * 0.5
	var mid := _root.get_node("Centre") as PanelContainer
	mid.size = mid.get_combined_minimum_size()
	mid.position = c - mid.size * 0.5
	_root.modulate.a = clampf(_k * 1.5, 0.0, 1.0)
	_root.queue_redraw()


func _draw_ring() -> void:
	var c := _root.size * 0.5
	var s := _k * _k * (3.0 - 2.0 * _k)
	_root.draw_circle(c, (R + 40.0) * s, Color(UIStyle.OUTLINE, 0.55))
	_root.draw_arc(c, (R + 40.0) * s, 0.0, TAU, 64, UIStyle.BORDER_DIM, 2.0)
	_root.draw_arc(c, (R - 34.0) * s, 0.0, TAU, 48, Color(UIStyle.BORDER_DIM, 0.6), 1.0)
	if _pick >= 0 and not entries.is_empty():
		var a := TAU * _pick / entries.size()
		var d := Vector2(sin(a), -cos(a))
		_root.draw_line(c + d * 46.0, c + d * (R - 22.0) * s, UIStyle.ACCENT, 3.0)
		_root.draw_arc(c, (R + 40.0) * s, a - PI * 0.5 - 0.22, a - PI * 0.5 + 0.22, 8, UIStyle.ACCENT, 4.0)
