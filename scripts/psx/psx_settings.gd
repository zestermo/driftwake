extends Node
## PSX presentation (autoload "PSX").
## - Renders the game at a low internal resolution and upscales with nearest filtering.
## - Drives the global vertex-snap / affine-warp shader uniforms.
## - Adds the full-screen 15-bit color + dither pass underneath the HUD.
## Values live in the Settings autoload (video section). Hotkeys:
## F2 cycles resolution presets, F3 toggles dithering, F11 / Alt+Enter fullscreen.

signal preset_changed(preset_name: String)

const PRESETS := [
	{"name": "640x360", "size": Vector2i(640, 360)},
	{"name": "480x270", "size": Vector2i(480, 270)},
	{"name": "320x180", "size": Vector2i(320, 180)},
	{"name": "Off (native)", "size": Vector2i.ZERO},
	{"name": "960x540 (sharper)", "size": Vector2i(960, 540)},
]

var _post_layer: CanvasLayer
var _post_rect: ColorRect
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_post_pass()
	_build_toast()
	get_tree().root.size_changed.connect(_update_snap)
	get_tree().root.size_changed.connect(_update_pixelate)
	Settings.changed.connect(_on_setting_changed)
	_apply_preset()
	if Settings.get_value("video", "fullscreen"):
		_apply_window_mode()


func _exit_tree() -> void:
	PSXMat.clear_cache()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			Settings.set_value("video", "psx_preset", (preset_index() + 1) % PRESETS.size())
			_show_toast("PSX: %s" % PRESETS[preset_index()]["name"])
		elif event.keycode == KEY_F3:
			Settings.set_value("video", "dither", not Settings.get_value("video", "dither"))
			_show_toast("Dither: %s" % ("On" if Settings.get_value("video", "dither") else "Off"))
		elif event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func preset_index() -> int:
	return clampi(int(Settings.get_value("video", "psx_preset")), 0, PRESETS.size() - 1)


func toggle_fullscreen() -> void:
	if Engine.is_embedded_in_editor():
		_show_toast("Fullscreen: run the game in its own window (see README)")
		return
	Settings.set_value("video", "fullscreen", not Settings.get_value("video", "fullscreen"))
	_show_toast("Fullscreen" if Settings.get_value("video", "fullscreen") else "Windowed")


func _on_setting_changed(section: String, key: String, _value: Variant) -> void:
	if section != "video":
		return
	match key:
		"fullscreen":
			_apply_window_mode()
		"psx_preset", "dither", "wobble", "warp":
			_apply_preset()


func _apply_window_mode() -> void:
	if Engine.is_embedded_in_editor():
		return
	if Settings.get_value("video", "fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _is_lowres() -> bool:
	return PRESETS[preset_index()]["size"] != Vector2i.ZERO


func _apply_preset() -> void:
	var preset: Dictionary = PRESETS[preset_index()]
	var win := get_tree().root
	var sz: Vector2i = preset["size"]
	if _is_lowres() and sz.x <= 640:
		# The canvas (and so every menu) is always 640x360; smaller presets
		# pixelate the 3D view in the post pass instead of shrinking the canvas,
		# so the UI never ends up laid out on a 320x180 screen.
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		win.content_scale_size = Vector2i(640, 360)
	else:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		win.content_scale_size = Vector2i(640, 360)
	_post_rect.material.set_shader_parameter("enabled", bool(Settings.get_value("video", "dither")) and _is_lowres())
	_update_pixelate()
	var warp := float(Settings.get_value("video", "warp"))
	RenderingServer.global_shader_parameter_set("psx_affine", warp if _is_lowres() else 0.0)
	_update_snap()
	preset_changed.emit(preset["name"])


## The 3D pixel grid for the preset (the canvas is wider than 640 on wide
## windows, so the grid scales with it).
func pixel_res() -> Vector2:
	var preset: Vector2i = PRESETS[preset_index()]["size"]
	var vis: Vector2 = get_tree().root.get_visible_rect().size
	if preset == Vector2i.ZERO:
		return vis
	return (vis * (float(preset.x) / 640.0)).round()


func _update_pixelate() -> void:
	if _post_rect == null:
		return
	var preset: Vector2i = PRESETS[preset_index()]["size"]
	# 640x360 renders the 3D at that size; the others render finer (or the
	# window size, for 960x540) and the post pass lays the pixel grid on it
	_post_rect.material.set_shader_parameter("pixelate", _is_lowres() and preset.x != 640)
	_post_rect.material.set_shader_parameter("pixel_res", pixel_res())


func _update_snap() -> void:
	var res := Vector2(8192.0, 8192.0)
	var wobble := clampf(float(Settings.get_value("video", "wobble")), 0.0, 1.0)
	if _is_lowres() and wobble > 0.01:
		var size: Vector2 = pixel_res()
		# wobble 1.0 -> snap to half the internal resolution; lower = finer grid
		var divisor := lerpf(0.25, 2.0, wobble)
		res = size / divisor
	RenderingServer.global_shader_parameter_set("psx_snap_res", res)


func _build_post_pass() -> void:
	_post_layer = CanvasLayer.new()
	_post_layer.name = "PSXPost"
	_post_layer.layer = -1  # below the HUD (layer 1+) but above the 3D view
	add_child(_post_layer)
	_post_rect = ColorRect.new()
	_post_rect.name = "Dither"
	_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/psx/psx_post.gdshader")
	_post_rect.material = mat
	_post_layer.add_child(_post_rect)


func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 6
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.reset_size()
	_toast.position.x = (get_tree().root.get_visible_rect().size.x - _toast.size.x) * 0.5
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
