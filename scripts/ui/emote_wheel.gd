extends CanvasLayer
## The emote wheel: hold T, move the mouse toward an emote (the camera holds still
## meanwhile), let go of T (or click) to do it; right click or Esc puts it away.
## Twelve gilt planks round a dark ring (UIStyle, on a crisp PixelCanvas), the one you point at
## lit in light teal, its name in the ornate plate in the middle. Player.emote does the rest.

const R := 118.0
const DEAD := 26.0
const ORDER := EmotePoses.ORDER

var player: Node
## The emotes on the wheel now: ORDER, plus "play" (start or stop the worn instrument: Jam) when one is worn.
var entries: Array = ORDER.duplicate()
var _canvas: PixelCanvas
var _root: Control
var _plates: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _centre: Label
var _open := false
## Let go of T before it opens again (after a click or a cancel).
var _spent := false
var _vec := Vector2.ZERO
var _pick := -1
var _k := 0.0


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
	_build_plates()
	var mid := PanelContainer.new()
	mid.name = "Centre"
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 8))
	_centre = UIStyle.label("Emotes", 12, UIStyle.ACCENT)
	_centre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_centre.custom_minimum_size = Vector2(84, 0)
	mid.add_child(_centre)
	_root.add_child(mid)
	_root.visible = false
	_restyle()


func _build_plates() -> void:
	for pc in _plates:
		pc.queue_free()
	_plates.clear()
	_labels.clear()
	for id in entries:
		var pc := PanelContainer.new()
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UIStyle.label(_label(id), 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pc.add_child(l)
		_root.add_child(pc)
		_plates.append(pc)
		_labels.append(l)


func _label(id: String) -> String:
	if id == "play":
		return "Stop" if player.jam.playing else "Play"
	return EmotePoses.LABELS[id]


## On opening: "Play" joins the wheel while an instrument is worn.
func _refresh_entries() -> void:
	var want: Array = ORDER.duplicate()
	if player.jam.worn() != "":
		want.append("play")
	if want != entries:
		entries = want
		_build_plates()
	for i in range(entries.size()):
		_labels[i].text = _label(entries[i])


func _do(id: String) -> void:
	if id == "play":
		player.jam.toggle()
	else:
		player.emote(id)


func is_open() -> bool:
	return _open


func _can_open() -> bool:
	if player == null or player.input_locked or not player.is_local:
		return false
	var menu := get_node_or_null("/root/GameMenu")
	return not (menu and menu.is_open()) and not get_node("/root/Dialogue").active


func _process(delta: float) -> void:
	var held := Input.is_action_pressed("emote")
	if not held:
		if _open and _pick >= 0:
			_close()
			_do(entries[_pick])
		elif _open:
			_close()
		_spent = false
	elif not _open and not _spent and _can_open():
		_open = true
		_vec = Vector2.ZERO
		_pick = -1
		_refresh_entries()
		_restyle()
	if _open and not _can_open():
		_close()
	_k = move_toward(_k, 1.0 if _open else 0.0, delta * (9.0 if _open else 12.0))
	_root.visible = _k > 0.0
	if _root.visible:
		_layout()


func _close() -> void:
	_open = false
	_spent = Input.is_action_pressed("emote")


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventMouseMotion:
		_vec = (_vec + (event as InputEventMouseMotion).screen_relative).limit_length(R)
		var was := _pick
		_pick = -1
		if _vec.length() > DEAD:
			var a := fposmod(atan2(_vec.x, -_vec.y), TAU)
			_pick = int(round(a / (TAU / entries.size()))) % entries.size()
		if _pick != was:
			_restyle()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_LEFT and _pick >= 0:
			var id: String = entries[_pick]
			_close()
			_do(id)
		elif b == MOUSE_BUTTON_RIGHT:
			_close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()


func _restyle() -> void:
	for i in range(_plates.size()):
		var on := i == _pick
		_plates[i].add_theme_stylebox_override("panel", UIStyle.frame(UIStyle.HILITE if on else UIStyle.BG_LIGHT, UIStyle.ACCENT if on else UIStyle.BORDER_DIM, 6, "plank", on))
		_labels[i].add_theme_color_override("font_color", UIStyle.INK if on else UIStyle.TEXT)
	_centre.text = _label(entries[_pick]) if _pick >= 0 else "Emotes"


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
	if _pick >= 0:
		var a := TAU * _pick / entries.size()
		var d := Vector2(sin(a), -cos(a))
		_root.draw_line(c + d * 46.0, c + d * (R - 22.0) * s, UIStyle.ACCENT, 3.0)
		_root.draw_arc(c, (R + 40.0) * s, a - PI * 0.5 - 0.22, a - PI * 0.5 + 0.22, 8, UIStyle.ACCENT, 4.0)
