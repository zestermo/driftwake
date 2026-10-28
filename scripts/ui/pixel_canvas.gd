class_name PixelCanvas
extends SubViewportContainer
## A crisp UI canvas: a SubViewport the size of the window divided by a whole number k (at least
## 360 tall), shown k times larger from the corner, so pixel fonts, frames and icons land on whole
## screen pixels at any window size. 1280x720 and 1920x1080 are a 640x360 canvas, 1600x900 is 800x450. With "Finer
## menus" (video fine_ui, the default) a window that's at least twice FINE_H tall gets a canvas at least FINE_H tall:
## 1920x1080 is 960x540, 2560x1440 1280x720 (smaller windows as before).
## Build into `ui` (themed, full rect); `canvas` is its size. Off screen, nothing inside processes
## or takes input (a hidden screen in it can't eat keys).

signal refit
const MIN_H := 360.0
const FINE_H := 540.0

var ui: Control
var canvas := Vector2(640, 360)
var _vp: SubViewport


func _init() -> void:
	stretch = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.snap_2d_transforms_to_pixel = true
	_vp.snap_2d_vertices_to_pixel = true
	_vp.gui_embed_subwindows = true
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	ui = Control.new()
	ui.theme = UIStyle.get_theme()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp.add_child(ui)
	visibility_changed.connect(_on_visibility)


func _ready() -> void:
	get_tree().root.size_changed.connect(fit)
	Settings.changed.connect(func(sec, key, _v):
		if sec == "video" and key == "fine_ui":
			fit())
	fit()
	_on_visibility()


func _on_visibility() -> void:
	if is_inside_tree():
		_vp.process_mode = Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED


## Size to the window (scaled back out of the 800x450 canvas_items stretch the parent lives in).
func fit() -> void:
	var win := get_tree().root
	var px := Vector2(win.size)
	var k := maxi(1, floori(px.y / MIN_H))
	if Settings.get_value("video", "fine_ui") and floori(px.y / FINE_H) >= 2:
		k = floori(px.y / FINE_H)
	canvas = (px / k).floor()
	stretch_shrink = k
	scale = Vector2.ONE * (win.get_visible_rect().size.y / px.y)
	position = Vector2.ZERO
	size = canvas * k
	refit.emit()


## A world point on a 2D canvas `vs` big that covers the window (the game camera is the
## root's: a canvas inside a PixelCanvas has none of its own).
static func project(cam: Camera3D, pos: Vector3, vs: Vector2) -> Vector2:
	return cam.unproject_position(pos) * (vs / cam.get_viewport().get_visible_rect().size)
