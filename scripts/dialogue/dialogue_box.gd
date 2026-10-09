class_name DialogueBox
extends CanvasLayer
## PS1-style dialogue window: speaker tag, typewriter text with voice blips,
## and a choice list (W/S or arrows to move, F/Space/Enter/click or 1-4 to pick).

signal choice_made(choice: Dictionary)

const CHARS_PER_SEC := 42.0
const BORDER := Color(0.86, 0.74, 0.45)
const BG := Color(0.04, 0.05, 0.09, 0.9)
const TEXT_COLOR := Color(0.95, 0.93, 0.86)
const CHOICE_COLOR := Color(0.7, 0.7, 0.66)
const CHOICE_SEL_COLOR := Color(1.0, 0.85, 0.35)

var _root: Control
var _panel: PanelContainer
var _name_panel: PanelContainer
var _name_label: Label
var _text: Label
var _choice_box: VBoxContainer
var _arrow: Label
var _blip: AudioStreamPlayer

var _typing: bool = false
## The page is out and there's nothing to pick: F goes on (the arrow blinks).
var _waiting: bool = false
var _shown_chars: float = 0.0
var _choices: Array = []
var _choice_labels: Array[Label] = []
var _sel: int = 0
var _voice: float = 1.0
var _blip_counter: int = 0
var _t: float = 0.0


func _ready() -> void:
	layer = 10
	_build()
	_root.visible = false


func _style(bg: Color, border: Color, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad - 2
	sb.content_margin_bottom = pad - 2
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(3, 3)
	return sb


## The window's width on the UI canvas (PSX.UI_SIZE), centred at the bottom.
const WIDTH := 460.0


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.get_theme()
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 9))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -WIDTH * 0.5
	_panel.offset_right = WIDTH * 0.5
	_panel.offset_top = -78
	_panel.offset_bottom = -14
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(WIDTH, 64)
	_root.add_child(_panel)
	_panel.resized.connect(_layout)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	_panel.add_child(vb)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("font_color", TEXT_COLOR)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	_text.add_theme_constant_override("line_spacing", 1)
	vb.add_child(_text)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 0)
	vb.add_child(_choice_box)

	# the footer: how to leave, and (waiting on you) how to go on
	var foot := HBoxContainer.new()
	vb.add_child(foot)
	var leave := Label.new()
	leave.text = "Esc  leave"
	leave.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	leave.add_theme_font_size_override("font_size", 8)
	leave.add_theme_color_override("font_color", Color(0.55, 0.52, 0.46))
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(leave)
	_arrow = Label.new()
	_arrow.text = "F  >"
	_arrow.add_theme_font_override("font", load("res://assets/fonts/Silkscreen-Regular.woff2"))
	_arrow.add_theme_font_size_override("font_size", 8)
	_arrow.add_theme_color_override("font_color", BORDER)
	foot.add_child(_arrow)

	_name_panel = PanelContainer.new()
	_name_panel.add_theme_stylebox_override("panel", _style(Color(0.18, 0.1, 0.06, 0.95), BORDER, 5))
	_name_panel.anchor_top = 1.0
	_name_panel.anchor_bottom = 1.0
	_root.add_child(_name_panel)
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", CHOICE_SEL_COLOR)
	_name_label.add_theme_font_override("font", load("res://assets/fonts/PixelifySans-SemiBold.woff2"))
	_name_panel.add_child(_name_label)

	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://assets/audio/blip.wav")
	_blip.volume_db = -10.0
	_blip.bus = "UI"
	add_child(_blip)


func _layout() -> void:
	# keep the name tag sitting on the panel's top edge (inset from its left) as it grows
	_name_panel.position = Vector2(_panel.position.x + 10, _panel.position.y - _name_panel.size.y + 4)


func open() -> void:
	_root.visible = true
	_panel.scale = Vector2(1, 0.2)
	_panel.pivot_offset = Vector2(0, _panel.size.y)
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.08)


func close() -> void:
	_root.visible = false
	_typing = false
	_waiting = false
	_clear_choices()


func show_line(speaker: String, text: String, choices: Array, voice: float) -> void:
	_voice = voice
	_name_panel.visible = speaker != ""
	_name_label.text = speaker
	_name_panel.reset_size()
	_layout.call_deferred()
	_text.text = text
	_text.visible_characters = 0
	_shown_chars = 0.0
	_typing = true
	_choices = choices
	_clear_choices()
	_waiting = false


func is_typing() -> bool:
	return _typing


func finish_typing() -> void:
	_text.visible_characters = -1
	_typing = false
	_on_typing_done()


func has_choices() -> bool:
	return not _choice_labels.is_empty()


func confirm_choice() -> void:
	if _choice_labels.is_empty():
		return
	var c: Dictionary = _choices[_sel]
	_play_select()
	_clear_choices()
	choice_made.emit(c)


## Returns true if the event was consumed for choice navigation.
func handle_input(event: InputEvent) -> bool:
	if _choice_labels.is_empty() or _typing:
		return false
	if event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_select(_sel - 1)
		return true
	if event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_select(_sel + 1)
		return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select(_sel - 1)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select(_sel + 1)
			return true
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k >= KEY_1 and k <= KEY_9:
			var idx := k - KEY_1
			if idx < _choice_labels.size():
				_select(idx)
				confirm_choice()
				return true
	return false


func _select(i: int) -> void:
	if _choice_labels.is_empty():
		return
	_sel = wrapi(i, 0, _choice_labels.size())
	for j in range(_choice_labels.size()):
		var lbl := _choice_labels[j]
		var raw := str(_choices[j].get("text", "..."))
		if j == _sel:
			lbl.text = "> %d. %s" % [j + 1, raw]
			lbl.add_theme_color_override("font_color", CHOICE_SEL_COLOR)
		else:
			lbl.text = "  %d. %s" % [j + 1, raw]
			lbl.add_theme_color_override("font_color", CHOICE_COLOR)
	_blip.pitch_scale = 1.6
	_blip.play()


func _clear_choices() -> void:
	for l in _choice_labels:
		l.queue_free()
	_choice_labels.clear()


func _on_typing_done() -> void:
	if _choices.is_empty():
		_waiting = true
		return
	for c in _choices:
		var lbl := Label.new()
		_choice_box.add_child(lbl)
		_choice_labels.append(lbl)
	_select(0)


func _play_select() -> void:
	_blip.pitch_scale = 2.0
	_blip.play()


func _process(delta: float) -> void:
	_t += delta
	_arrow.modulate.a = (1.0 if fmod(_t, 0.8) < 0.5 else 0.2) if _waiting else 0.0
	if not _typing:
		return
	var prev := int(_shown_chars)
	var total := _text.get_total_character_count()
	var speed := CHARS_PER_SEC
	if prev > 0 and prev <= _text.text.length():
		var ch := _text.text[prev - 1]
		if ch in [".", "!", "?"]:
			speed *= 0.18
		elif ch == ",":
			speed *= 0.4
	_shown_chars += speed * delta
	var now := int(_shown_chars)
	if now != prev:
		_text.visible_characters = now
		_blip_counter += now - prev
		if _blip_counter >= 2:
			_blip_counter = 0
			if prev < _text.text.length() and _text.text[prev] != " ":
				_blip.pitch_scale = _voice * randf_range(0.92, 1.08)
				_blip.play()
	if now >= total:
		_typing = false
		_text.visible_characters = -1
		_on_typing_done()
