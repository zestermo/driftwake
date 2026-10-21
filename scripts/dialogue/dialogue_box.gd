class_name DialogueBox
extends CanvasLayer
## PS1-style dialogue window on a crisp canvas (PixelCanvas): a parchment page with the speaker's
## name tag on its edge, typewriter text with voice blips, choices as planks (W/S or arrows to move,
## F/Space/Enter/click or 1-4 to pick) and key caps for what you can do.

signal choice_made(choice: Dictionary)

const CHARS_PER_SEC := 42.0
const TEXT_COLOR := UIStyle.PARCH_INK

var _canvas: PixelCanvas
var _root: Control
var _panel: PanelContainer
var _name_panel: PanelContainer
var _name_label: Label
var _text: Label
var _choice_box: VBoxContainer
var _arrow: Control
var _pick_hint: Control
var _blip: AudioStreamPlayer

var _typing: bool = false
## The page is out and there's nothing to pick: F goes on (the arrow blinks).
var _waiting: bool = false
var _shown_chars: float = 0.0
var _choices: Array = []
## The choice planks (Buttons).
var _choice_labels: Array = []
var _sel: int = 0
## The left stick's last step (-1 up, 0 centred, 1 down): it moves the choice once per push.
var _stick := 0
var _voice: float = 1.0
var _blip_counter: int = 0
var _t: float = 0.0


func _ready() -> void:
	layer = 10
	_build()
	_pick_hint.visible = false
	_canvas.visible = false


## The window's width on the canvas (at least 640x360), centred at the bottom.
const WIDTH := 440.0


func _build() -> void:
	_canvas = PixelCanvas.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_canvas)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.ui.add_child(_root)

	_panel = PanelContainer.new()
	var page := UIStyle.parchment(10).duplicate() as StyleBoxTexture
	page.content_margin_right = 20
	_panel.add_theme_stylebox_override("panel", page)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -WIDTH * 0.5
	_panel.offset_right = WIDTH * 0.5
	_panel.offset_top = -70
	_panel.offset_bottom = -8
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(WIDTH, 62)
	_root.add_child(_panel)
	_panel.resized.connect(_layout)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	_panel.add_child(vb)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("font_color", TEXT_COLOR)
	_text.add_theme_constant_override("line_spacing", -2)
	vb.add_child(_text)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	vb.add_child(_choice_box)

	# the footer: how to leave, how to pick, and (waiting on you) how to go on
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	vb.add_child(foot)
	foot.add_child(UIStyle.key_hint("ESC", "LEAVE", true))
	_pick_hint = UIStyle.key_hint("1-4", "CHOOSE", true)
	foot.add_child(_pick_hint)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(gap)
	_arrow = UIStyle.key_hint("F", "GO ON", true)
	foot.add_child(_arrow)

	_name_panel = PanelContainer.new()
	_name_panel.add_theme_stylebox_override("panel", UIStyle.chrome("sign", 7, 2))
	_root.add_child(_name_panel)
	_name_label = Label.new()
	_name_label.add_theme_color_override("font_color", UIStyle.GILT)
	_name_label.add_theme_color_override("font_outline_color", UIStyle.WOOD_INK)
	_name_label.add_theme_constant_override("outline_size", 3)
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
	_canvas.visible = true
	_panel.scale = Vector2(1, 0.2)
	_panel.pivot_offset = Vector2(0, _panel.size.y)
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.08)


func close() -> void:
	_canvas.visible = false
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
	# the left stick: a step each time it passes half way (its motion events repeat while held, and each
	# would count as a press of move_forward/back)
	if event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if m.axis != JOY_AXIS_LEFT_Y:
			return false
		var d := 0 if absf(m.axis_value) < 0.5 else int(signf(m.axis_value))
		if d != 0 and d != _stick:
			_select(_sel + d)
		_stick = d
		return true
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
	if wrapi(i, 0, _choice_labels.size()) == _sel and (_choice_labels[_sel] as Button).text.begins_with(">"):
		return
	_sel = wrapi(i, 0, _choice_labels.size())
	for j in range(_choice_labels.size()):
		var b: Button = _choice_labels[j]
		var on := j == _sel
		b.text = "%s %d.  %s" % [">" if on else " ", j + 1, str(_choices[j].get("text", "..."))]
		b.add_theme_stylebox_override("normal", _plank(on))
		b.add_theme_stylebox_override("hover", _plank(true))
		b.add_theme_color_override("font_color", UIStyle.WOOD_INK if on else UIStyle.PARCH)
	UIStyle.sfx("move")


## A choice's plank: wood, gilded with ink when it's the one picked.
static func _plank(on: bool) -> StyleBoxTexture:
	return UIStyle.chrome("plank_hover" if on else "plank", 6, 1)


func _clear_choices() -> void:
	for l in _choice_labels:
		l.queue_free()
	_choice_labels.clear()
	_pick_hint.visible = false


func _on_typing_done() -> void:
	if _choices.is_empty():
		_waiting = true
		return
	for j in range(_choices.size()):
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_hover_color", UIStyle.WOOD_INK)
		b.mouse_entered.connect(func(): _select(j))
		b.pressed.connect(func():
			_select(j)
			confirm_choice())
		_choice_box.add_child(b)
		_choice_labels.append(b)
	_pick_hint.visible = true
	_select(0)


func _play_select() -> void:
	UIStyle.sfx("confirm")


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
