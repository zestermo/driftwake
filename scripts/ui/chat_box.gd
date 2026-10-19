class_name ChatBox
extends CanvasLayer
## The crew's chat (co-op only): Enter opens a line at the bottom left, Enter sends it (Esc or an empty
## line puts it away). Every captain's lines show above it, their name in their crew colour, and fade
## after SHOW s; the last LINES all come back while you type. Lines go through the host (Net.chat).
## While you type (typing) the captain stands still and no menu or wheel opens.

const LINES := 6
const SHOW := 10.0
const FADE := 1.5
const W := 300.0

static var typing := false

var player: Node
var _canvas: PixelCanvas
var _box: VBoxContainer
var _line: LineEdit
## [row, age s]
var _rows: Array = []


func _ready() -> void:
	layer = 5
	_canvas = PixelCanvas.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_box = VBoxContainer.new()
	_box.name = "Chat"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 1)
	_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_left = 10.0
	_box.offset_right = 10.0 + W
	_box.offset_top = -106.0
	_box.offset_bottom = -106.0
	_canvas.ui.add_child(_box)
	_line = LineEdit.new()
	_line.name = "Line"
	_line.max_length = Net.CHAT_MAX
	_line.placeholder_text = "Say something to the crew"
	_line.custom_minimum_size = Vector2(W, 0)
	_line.add_theme_font_size_override("font_size", 12)
	_line.add_theme_color_override("font_color", UIStyle.TEXT)
	_line.add_theme_color_override("font_placeholder_color", UIStyle.TEXT_DIM)
	_line.add_theme_color_override("caret_color", UIStyle.ACCENT)
	_line.add_theme_stylebox_override("normal", UIStyle.panel(UIStyle.BG, UIStyle.BORDER_DIM, 4))
	_line.add_theme_stylebox_override("focus", UIStyle.panel(UIStyle.BG, UIStyle.ACCENT, 4))
	_line.visible = false
	_line.text_submitted.connect(_send)
	_box.add_child(_line)
	Net.chat_line.connect(_on_line)


func _exit_tree() -> void:
	typing = false


func _can_open() -> bool:
	if not player.is_local or player.input_locked or not Net.active:
		return false
	return not GameMenu.is_open() and not get_node("/root/Dialogue").active and RadialWheel.shown == null


func _unhandled_input(event: InputEvent) -> void:
	if not typing and event.is_action_pressed("chat") and not (event is InputEventWithModifiers and event.alt_pressed) and _can_open():
		open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if typing and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return typing


func open() -> void:
	typing = true
	player.input_locked = true
	_line.text = ""
	_line.visible = true
	_line.grab_focus()


func close() -> void:
	typing = false
	player.input_locked = false
	_line.release_focus()
	_line.visible = false


func _send(text: String) -> void:
	close()
	Net.chat(text)


func _on_line(id: int, who: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var n := UIStyle.label(who + ":", 12, Net.crew_color(id) if Net.active else UIStyle.ACCENT)
	n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(n)
	var t := UIStyle.label(text, 12)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	for l: Label in [n, t]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_outline_color", UIStyle.OUTLINE)
		l.add_theme_constant_override("outline_size", 3)
	_box.add_child(row)
	_box.move_child(_line, -1)
	_rows.append([row, 0.0])
	while _rows.size() > LINES:
		(_rows.pop_front()[0] as Node).queue_free()
	if id != Net.my_id():
		UIStyle.sfx("select")


## The lines on screen now (tests): [[who, text, alpha], ...].
func shown() -> Array:
	return _rows.map(func(r): return [(r[0].get_child(0) as Label).text, (r[0].get_child(1) as Label).text, (r[0] as Control).modulate.a])


func _process(delta: float) -> void:
	for r in _rows:
		r[1] += delta
		(r[0] as Control).modulate.a = 1.0 if typing else clampf((SHOW + FADE - float(r[1])) / FADE, 0.0, 1.0)
