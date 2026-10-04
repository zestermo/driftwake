class_name Reticle
extends Control
## Small pixel crosshair. Full cross in combat stance, a dot otherwise.
## Turns red when the camera is aimed at an enemy within reach.

var armed: bool = false
var on_target: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(15, 15)
	size = Vector2(15, 15)


func _process(_delta: float) -> void:
	# Keep centered on the (possibly resized / expanded-aspect) viewport.
	var vp := get_viewport_rect().size
	position = (vp * 0.5 - size * 0.5).floor()


func _draw() -> void:
	var c := Vector2(7, 7)
	var col := Color(1.0, 0.3, 0.25) if on_target else Color(1, 1, 1, 0.9)
	var shadow := Color(0, 0, 0, 0.75)
	if armed:
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var a: Vector2 = c + dir * 2.0
			var b: Vector2 = c + dir * 6.0
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), shadow, 1.0)
			draw_line(a, b, col, 1.0)
		draw_rect(Rect2(c, Vector2(1, 1)), col)
	else:
		draw_rect(Rect2(c + Vector2(0, 0), Vector2(2, 2)), shadow)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.6))


func set_state(is_armed: bool, is_on_target: bool) -> void:
	if is_armed != armed or is_on_target != on_target:
		armed = is_armed
		on_target = is_on_target
		queue_redraw()
