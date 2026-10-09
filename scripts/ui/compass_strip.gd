extends Control
## A compass strip across the top of the screen (at the helm, aboard, or with
## chart marks set): the way the camera faces in the middle, the half circle
## either side, N/E/S/W, where the wind blows from, and the crew's chart marks
## (Net.waypoints) with how far off they are, and the log pose's needles.
## North is -z.

const W := 230.0
const H := 24.0
## Degrees from the middle to each end of the strip.
const SPAN := 90.0
const MARKS := preload("res://scripts/ui/chain_marks.gd")

var _font: Font
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_top = 4
	offset_bottom = 4 + H
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")


static func bearing(d: Vector2) -> float:
	return rad_to_deg(atan2(d.x, -d.y))


## Screen x on the strip for a bearing (INF beyond the ends).
func _x(b: float, heading: float) -> float:
	var off := wrapf(b - heading, -180.0, 180.0)
	if absf(off) > SPAN:
		return INF
	return W * 0.5 + off / SPAN * (W * 0.5 - 6.0)


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := -cam.global_basis.z
	var heading := bearing(Vector2(f.x, f.z))
	draw_rect(Rect2(0, 0, W, 12), Color(0.03, 0.03, 0.05, 0.55))
	var ink := Color(0.95, 0.92, 0.85)
	for d in range(0, 360, 15):
		var x := _x(float(d), heading)
		if x == INF:
			continue
		var major := d % 90 == 0
		draw_line(Vector2(x, 0), Vector2(x, 4 if not major else 6), Color(ink, 0.6 if not major else 1.0), 1.0)
		var lbl: String = {0: "N", 90: "E", 180: "S", 270: "W", 45: "ne", 135: "se", 225: "sw", 315: "nw"}.get(d, "")
		if lbl != "":
			var col := Color(1.0, 0.45, 0.35) if d == 0 else ink
			draw_string(_font, Vector2(x - 3, 11), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col if major else Color(ink, 0.6))
	# where the wind comes from
	var wx := get_node_or_null("/root/Weather")
	if wx:
		var wd: Vector2 = wx.wind_dir()
		var x := _x(bearing(-wd), heading)
		if x != INF:
			var c := Color(0.55, 0.85, 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(x, 12), Vector2(x - 3, 16), Vector2(x + 3, 16)]), c)
			draw_string(_font, Vector2(x - 8, 23), "wind", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(c, 0.8))
	# the chart marks
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me:
		var here := Vector2(me.global_position.x, me.global_position.z)
		for id in Net.waypoints.keys():
			var col: Color = Net.crew_color(id) if Net.active else UIStyle.ACCENT
			for p in Net.waypoints[id]:
				var to: Vector2 = p - here
				var off := wrapf(bearing(to) - heading, -180.0, 180.0)
				var x := W * 0.5 + clampf(off / SPAN, -1.0, 1.0) * (W * 0.5 - 6.0)
				var r := 3.5
				draw_colored_polygon(PackedVector2Array([Vector2(x, 2), Vector2(x + r, 2 + r), Vector2(x, 2 + r * 2), Vector2(x - r, 2 + r)]), col)
				if absf(off) <= SPAN:
					var txt := "%dm" % int(to.length())
					draw_string_outline(_font, Vector2(x - 8, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
					draw_string(_font, Vector2(x - 8, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		_draw_log_pose(heading, here)
	# where we're facing
	draw_colored_polygon(PackedVector2Array([Vector2(W * 0.5, 12), Vector2(W * 0.5 - 3, 15), Vector2(W * 0.5 + 3, 15)]), UIStyle.ACCENT)
	draw_line(Vector2(W * 0.5, 0), Vector2(W * 0.5, 12), UIStyle.ACCENT, 1.0)


## The log pose's needles on the strip, each with its island's theme icon,
## distance and danger under it (at a fork the left one's label to its left).
## Unset, one faint needle wanders about with a "?".
func _draw_log_pose(heading: float, here: Vector2) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or gm.player == null or not gm.player.has_log_pose():
		return
	var targets: Array = MARKS.targets(gm)
	if targets.is_empty():
		var x := W * 0.5 + sin(_t * 0.9) * sin(_t * 0.37 + 1.0) * (W * 0.5 - 20.0)
		_needle(x, Color(MARKS.NEEDLE_COLORS[0], 0.5))
		_label(x + 4.0, "?", Color(0.95, 0.9, 0.8, 0.7))
		return
	var marks: Array = []
	for i in range(targets.size()):
		var to: Vector2 = (targets[i]["pos"] as Vector2) - here
		var off := wrapf(bearing(to) - heading, -180.0, 180.0)
		marks.append([W * 0.5 + clampf(off / SPAN, -1.0, 1.0) * (W * 0.5 - 6.0), i, to.length()])
	marks.sort_custom(func(a, b): return a[0] < b[0])
	var lvl: int = gm.player.progression.level
	for j in range(marks.size()):
		var x: float = marks[j][0]
		var n: Dictionary = targets[marks[j][1]]
		_needle(x, MARKS.NEEDLE_COLORS[marks[j][1]])
		var theme := str(n["theme"])
		MARKS.icon(self, Vector2(x, 18), theme, 3.5, MARKS.theme_color(theme))
		var dz: Array = MARKS.danger(int(n["level"]), lvl)
		var txt := "%.1fkm %s" % [float(marks[j][2]) / 1000.0, dz[0]]
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var left := j == 0 and marks.size() > 1
		_label(x - 6.0 - w if left else x + 6.0, txt, dz[1])


## A needle standing on the strip: the coloured point up, the dark tail down.
func _needle(x: float, col: Color) -> void:
	draw_rect(Rect2(x - 2.0, -1.0, 4.0, 13.0), Color(0, 0, 0, col.a * 0.8))
	draw_colored_polygon(PackedVector2Array([Vector2(x, -1), Vector2(x + 1.5, 6), Vector2(x - 1.5, 6)]), col)
	draw_rect(Rect2(x - 1.0, 6.0, 2.0, 5.0), Color(0.15, 0.15, 0.18, col.a))


func _label(x: float, txt: String, col: Color) -> void:
	draw_string_outline(_font, Vector2(x, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
	draw_string(_font, Vector2(x, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
