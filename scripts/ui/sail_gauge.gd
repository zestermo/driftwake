extends Control
## Aboard the crew's ship: a little compass rose with the bow up (north
## marked), the wind as an arrow (pale: sailing normally, green: a fair wind
## giving her extra speed), the speed in knots, the sails as set and the
## anchor if she's riding to it.

const R := 22.0

var ship: Node3D
var _font: Font


func _ready() -> void:
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")
	custom_minimum_size = Vector2(64, 74)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## A world direction (x, z) on the dial: the bow is up.
func _dial(v: Vector2, heading: float) -> Vector2:
	var fwd := Vector2(-sin(heading), -cos(heading))
	var right := Vector2(cos(heading), -sin(heading))
	return Vector2(v.dot(right), -v.dot(fwd))


func _draw() -> void:
	if ship == null or not is_instance_valid(ship):
		return
	var c := Vector2(size.x * 0.5, R + 2.0)
	var heading: float = ship.get("_heading")
	draw_circle(c, R, Color(0.04, 0.05, 0.08, 0.6))
	draw_arc(c, R, 0.0, TAU, 24, Color(0.85, 0.8, 0.65, 0.8), 1.0)
	# north
	var n := _dial(Vector2(0, -1), heading).normalized()
	draw_line(c + n * (R - 5.0), c + n * R, Color(1.0, 0.35, 0.3), 2.0)
	draw_string(_font, c + n * (R - 10.0) + Vector2(-3, 3), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.45, 0.4))
	# the wind, blowing across the dial
	var wx := get_node_or_null("/root/Weather")
	if wx:
		var wd: Vector2 = wx.wind_dir()
		var d := _dial(wd, heading).normalized()
		var eff: float = ship.call("wind_effect")
		var col := Color(0.8, 0.82, 0.85).lerp(Color(0.45, 1.0, 0.45), clampf((eff - 1.0) / Ship.FAIR_BOOST, 0.0, 1.0))
		var tail := c - d * (R - 4.0)
		var tip := c + d * (R - 4.0)
		draw_line(tail, tip, col, 2.0)
		var side := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([tip + d * 2.0, tip - d * 5.0 + side * 4.0, tip - d * 5.0 - side * 4.0]), col)
	# our bow
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 5), c + Vector2(-4, 5)]), Color(0.95, 0.9, 0.75))
	# speed, sails, anchor
	var kn := absf(float(ship.get("speed"))) * 1.944
	var y := c.y + R + 10.0
	draw_string(_font, Vector2(0, y), "%.1f kn" % kn, HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(0.95, 0.92, 0.85))
	var steps := int(roundf(float(ship.get("sail")) * 3.0))
	for i in range(3):
		var r := Rect2(size.x * 0.5 - 13.0 + i * 9.0, y + 3.0, 7.0, 4.0)
		draw_rect(r, Color(0.95, 0.9, 0.75) if i < steps else Color(0.3, 0.3, 0.32, 0.8))
	if bool(ship.get("anchored")):
		draw_string(_font, Vector2(0, y + 17.0), "ANCHORED", HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, Color(1.0, 0.8, 0.4))
