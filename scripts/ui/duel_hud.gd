extends CanvasLayer
## The duel's words on screen (Duel makes it): the challenge to answer (Y / N, the time left under it) and
## the big banners (3, 2, 1, Fight!, Victory, Defeated, Draw), on a crisp PixelCanvas in UIStyle.

var duel: Node
var _canvas: PixelCanvas
var _ask: PanelContainer
var _ask_text: Label
var _ask_bar: ProgressBar
var _banner: VBoxContainer
var _big: Label
var _sub: Label
var _tween: Tween
var _chime: AudioStreamPlayer


func _ready() -> void:
	layer = 5
	_canvas = PixelCanvas.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	var ui := _canvas.ui
	_ask = PanelContainer.new()
	_ask.name = "Challenge"
	_ask.add_theme_stylebox_override("panel", UIStyle.panel(UIStyle.BG, UIStyle.BORDER, 8))
	_ask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ask.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ask.add_child(vb)
	_ask_text = UIStyle.label("", 12, UIStyle.TEXT)
	_ask_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_ask_text)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 12)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_child(UIStyle.key_hint("Y", "ACCEPT"))
	keys.add_child(UIStyle.key_hint("N", "DECLINE"))
	vb.add_child(keys)
	_ask_bar = ProgressBar.new()
	_ask_bar.show_percentage = false
	_ask_bar.max_value = 1.0
	_ask_bar.custom_minimum_size = Vector2(0, 3)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UIStyle.BG_DARK, 0.85)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UIStyle.SUN
	_ask_bar.add_theme_stylebox_override("background", bg)
	_ask_bar.add_theme_stylebox_override("fill", fg)
	_ask_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_ask_bar)
	ui.add_child(_ask)
	_banner = VBoxContainer.new()
	_banner.name = "Banner"
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_theme_constant_override("separation", 0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	_big = UIStyle.title("")
	_big.add_theme_font_size_override("font_size", 34)
	_big.add_theme_constant_override("outline_size", 6)
	_sub = UIStyle.label("", 12, UIStyle.TEXT)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_outline_color", UIStyle.OUTLINE)
	_sub.add_theme_constant_override("outline_size", 4)
	_banner.add_child(_big)
	_banner.add_child(_sub)
	ui.add_child(_banner)
	_chime = AudioStreamPlayer.new()
	_chime.stream = load("res://assets/audio/discover_chime.wav")
	_chime.volume_db = -6.0
	_chime.bus = "UI"
	add_child(_chime)


func _process(_delta: float) -> void:
	var vs := _canvas.canvas
	_ask.reset_size()
	_ask.position = Vector2(roundf((vs.x - _ask.size.x) * 0.5), 44.0)
	_banner.size = Vector2(vs.x, 80.0)
	_banner.position = Vector2(0.0, roundf(vs.y * 0.24))
	_banner.pivot_offset = _banner.size * 0.5


## The challenge we've been sent ("" none) and how much of the time to answer is left.
func ask(from_name: String, left: float) -> void:
	var was := _ask.visible
	_ask.visible = from_name != ""
	if not _ask.visible:
		return
	_ask_text.text = "%s challenges you to a duel" % from_name
	_ask_bar.value = left
	if not was:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p:
			FX.sfx("parry", p.global_position + Vector3(0, 1.6, 0), -8.0, 0.0, 1.3)


func asking() -> bool:
	return _ask.visible


func banner_text() -> String:
	return _big.text if _banner.modulate.a > 0.0 else ""


## A word across the middle that pops in and fades (a countdown beat, the result).
func big(text: String, sub: String, chime: bool = false) -> void:
	_big.text = text
	_sub.text = sub
	_sub.visible = sub != ""
	if _tween:
		_tween.kill()
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(1.35, 1.35)
	var hold := 0.55 if text.length() <= 6 and sub == "" else 2.2
	_tween = create_tween()
	_tween.tween_property(_banner, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold)
	_tween.tween_property(_banner, "modulate:a", 0.0, 0.3)
	if chime:
		_chime.play()


func _input(event: InputEvent) -> void:
	if not _ask.visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).physical_keycode
	if k == KEY_Y or k == KEY_N:
		duel.answer(k == KEY_Y)
		_ask.visible = false
		get_viewport().set_input_as_handled()
