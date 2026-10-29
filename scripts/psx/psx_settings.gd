extends Node
## PSX presentation (autoload "PSX").
## - Renders the game at a low internal resolution and upscales with nearest filtering.
## - Drives the global vertex-snap / affine-warp shader uniforms.
## - Adds the full-screen 15-bit color + dither pass underneath the HUD.
## Values live in the Settings autoload (video section). Hotkeys:
## F2 toggles pixelation, F3 toggles dithering, F11 / Alt+Enter fullscreen.

## The UI's canvas: menus and the HUD are laid out on this many pixels and
## drawn at the window's own resolution (the pixel fonts stay hard-edged, just
## finer); the 3D's pixel grid is GRID's, laid on by the post pass.
const UI_SIZE := Vector2i(800, 450)

## The one pixel grid (at 800 UI pixels across; coarser grids made distant things too hard to see).
const GRID := Vector2i(960, 540)

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
	_apply_frames()
	if Settings.tool_run():
		_tool_window()
	elif Settings.get_value("video", "fullscreen"):
		if OS.has_feature("web"):
			# (a browser only goes fullscreen from a click or key press)
			Settings.set_value("video", "fullscreen", false)
		else:
			_apply_window_mode()


func _exit_tree() -> void:
	PSXMat.clear_cache()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			Settings.set_value("video", "pixelate", not pixelated())
			_show_toast("Pixelation: %s" % ("On" if pixelated() else "Off"))
		elif event.keycode == KEY_F3:
			Settings.set_value("video", "dither", not Settings.get_value("video", "dither"))
			_show_toast("Dither: %s" % ("On" if Settings.get_value("video", "dither") else "Off"))
		elif event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func pixelated() -> bool:
	return bool(Settings.get_value("video", "pixelate"))


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
		"pixelate", "dither", "wobble", "warp":
			_apply_preset()
		"vsync", "max_fps":
			_apply_frames()


## A test or render tool's window (`--script`): never fullscreen whatever the player's saved setting says,
## never takes the focus, out of the way in the bottom-right corner of the screen, so it doesn't cover
## or interrupt whatever Zach is doing (it still renders: off to the side, not minimized).
func _tool_window() -> void:
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var size := DisplayServer.window_get_size()
	DisplayServer.window_set_position(area.end - size - Vector2i(8, 8))


func _apply_window_mode() -> void:
	if Engine.is_embedded_in_editor() or Settings.tool_run():
		return
	if Settings.get_value("video", "fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_preset() -> void:
	var win := get_tree().root
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = UI_SIZE
	_post_rect.material.set_shader_parameter("enabled", bool(Settings.get_value("video", "dither")) and pixelated())
	_update_pixelate()
	var warp := float(Settings.get_value("video", "warp"))
	RenderingServer.global_shader_parameter_set("psx_affine", warp if pixelated() else 0.0)
	_update_snap()


## The 3D pixel grid (wider windows widen the canvas, and the grid with it).
func pixel_res() -> Vector2:
	var vis: Vector2 = get_tree().root.get_visible_rect().size
	if not pixelated():
		return vis
	return (vis * (float(GRID.x) / float(UI_SIZE.x))).round()


func _update_pixelate() -> void:
	if _post_rect == null:
		return
	_post_rect.material.set_shader_parameter("pixelate", pixelated())
	_post_rect.material.set_shader_parameter("pixel_res", pixel_res())
	# render the 3D at the grid's own size: the post pass samples one texel
	# per cell, so every pixel past that was drawn and thrown away
	var win := get_tree().root
	win.scaling_3d_scale = clampf(pixel_res().y / maxf(float(win.size.y), 1.0), 0.25, 1.0) if pixelated() else 1.0


func _update_snap() -> void:
	var res := Vector2(8192.0, 8192.0)
	var wobble := clampf(float(Settings.get_value("video", "wobble")), 0.0, 1.0)
	if pixelated() and wobble > 0.01:
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


## (1.26) Vsync and the frame cap (never in a test or render run: those keep the engine's own).
func _apply_frames() -> void:
	if Settings.tool_run():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Settings.get_value("video", "vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(Settings.get_value("video", "max_fps"))
