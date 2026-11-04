class_name PixelCanvas
extends SubViewportContainer
## A crisp UI canvas: a SubViewport the size of the window divided by a whole number k (at least
## MIN_H = 540 tall, PSX.UI_SIZE), shown k times larger from the corner, so pixel fonts, frames and icons land on
## whole screen pixels: 1920x1080 and 3840x2160 are 960x540, 2560x1440 1280x720, a 1280x720 window 1280x720
## (k 1). A window under 540 tall still gets a 540-tall canvas, shrunk to fit (smoothed, not crisp).
## Build into `ui` (themed, full rect); `canvas` is its size. Off screen, nothing inside processes
## or takes input (a hidden screen in it can't eat keys).

signal refit
const MIN_H := 540.0

var ui: Control
var canvas := Vector2(960, 540)
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
	fit()
	_on_visibility()


func _on_visibility() -> void:
	if is_inside_tree():
		_vp.process_mode = Node.PROCESS_MODE_INHERIT if is_visible_in_tree() else Node.PROCESS_MODE_DISABLED


## Size to the window (scaled back out of the root's PSX.UI_SIZE canvas_items stretch the parent lives in).
func fit() -> void:
	var win := get_tree().root
	var px := Vector2(win.size).max(Vector2.ONE)
	var k := maxi(1, floori(px.y / MIN_H))
	canvas = (px / k).floor() if px.y >= MIN_H else (px * (MIN_H / px.y)).floor()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if px.y >= MIN_H else CanvasItem.TEXTURE_FILTER_LINEAR
	stretch_shrink = k
	scale = Vector2.ONE * (win.get_visible_rect().size.y / (canvas.y * k))
	position = Vector2.ZERO
	size = canvas * k
	refit.emit()


## A world point on a 2D canvas `vs` big that covers the window (the game camera is the
## root's: a canvas inside a PixelCanvas has none of its own).
static func project(cam: Camera3D, pos: Vector3, vs: Vector2) -> Vector2:
	return cam.unproject_position(pos) * (vs / cam.get_viewport().get_visible_rect().size)
