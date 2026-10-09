extends Control
## The log pose, drawn big while L is held (Player.log_pose_up): the glass
## ball in its brass cradle on a leather strap, a needle for each island it
## has set on, turning with the camera (up = the way you face), and under it
## what each island is (theme icon and name, level, distance, and how
## dangerous for you: easy / even / hard / deadly). Unset, the needle wanders
## and says why; the moment it sets, it swings round and settles.

const W := 150.0
const H := 150.0
const BALL := 26.0
const C := Vector2(W - 44.0, 44.0)
const MARKS := preload("res://scripts/ui/chain_marks.gd")

var _font: Font
var _small: Font
var _k: float = 0.0
var _t: float = 0.0
## Each needle's angle on screen, easing toward where it points.
var _ang: Array[float] = [0.0, 0.0]


func _init() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -W - 6.0
	offset_right = -6.0
	offset_top = -H - 70.0
	offset_bottom = -70.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/PixelifySans-Regular.woff2")
	_small = load("res://assets/fonts/Silkscreen-Regular.woff2")


func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("player")
	var up: bool = me != null and me.log_pose_up
	_k = move_toward(_k, 1.0 if up else 0.0, delta * (7.0 if up else 9.0))
	_t += delta
	visible = _k > 0.0
	modulate.a = clampf(_k * 1.6, 0.0, 1.0)
	if visible:
		_swing(delta, me)
		queue_redraw()


func _swing(delta: float, me: Node3D) -> void:
	var gm := get_node_or_null("/root/GameManager")
	var targets: Array = MARKS.targets(gm) if gm else []
	var cam := get_viewport().get_camera_3d()
	var heading := 0.0
	if cam:
		var f := -cam.global_basis.z
		heading = atan2(f.x, -f.z)
	for i in range(2):
		var a: float
		if targets.is_empty():
			a = _t * 0.7 + sin(_t * 1.9) * 1.4 + i * PI
		else:
			var p: Vector2 = targets[mini(i, targets.size() - 1)]["pos"]
			var to := p - Vector2(me.global_position.x, me.global_position.z)
			a = atan2(to.x, -to.y) - heading + sin(_t * 7.0 + i * 2.0) * 0.04
		_ang[i] = lerp_angle(_ang[i], a, clampf(delta * 8.0, 0.0, 1.0))


func _draw() -> void:
	# pops up from the strap with a little overshoot
	var e := _k * _k * (3.0 - 2.0 * _k)
	var s := e * (1.0 + 0.12 * sin(e * PI))
	draw_set_transform(C + Vector2(0, BALL * 2.0) * (1.0 - s), 0.0, Vector2.ONE * maxf(s, 0.01))
	var gm := get_node_or_null("/root/GameManager")
	var targets: Array = MARKS.targets(gm) if gm else []
	_draw_pose(targets)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_labels(targets, gm)


func _draw_pose(targets: Array) -> void:
	var leather := Color(0.42, 0.25, 0.13)
	var brass := Color(0.92, 0.72, 0.32)
	var brass_dk := Color(0.55, 0.38, 0.14)
	var ink := Color(0.08, 0.05, 0.04)
	# the strap, stitched along both edges
	var sy := BALL + 8.0
	draw_rect(Rect2(-BALL * 2.2, sy - 7.0, BALL * 4.4, 14.0), ink)
	draw_rect(Rect2(-BALL * 2.2 + 1.0, sy - 6.0, BALL * 4.4 - 2.0, 12.0), leather)
	for i in range(int(BALL * 4.4 / 6.0)):
		var x := -BALL * 2.2 + 4.0 + i * 6.0
		for y in [sy - 4.0, sy + 3.0]:
			draw_line(Vector2(x, y), Vector2(x + 3.0, y), leather.lightened(0.35), 1.0)
	# the cradle: a cup on the strap, a cap on top, a post either side
	var cup := PackedVector2Array([Vector2(-15, sy - 4), Vector2(15, sy - 4), Vector2(11, BALL - 4), Vector2(-11, BALL - 4)])
	draw_colored_polygon(cup, brass)
	draw_polyline(cup + PackedVector2Array([cup[0]]), ink, 1.0)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (BALL + 3.0)
		draw_rect(Rect2(x - 2.0, -BALL + 2.0, 4.0, BALL * 2.0 - 2.0), ink)
		draw_rect(Rect2(x - 1.0, -BALL + 3.0, 2.0, BALL * 2.0 - 4.0), brass)
	draw_rect(Rect2(-BALL - 5.0, -BALL - 1.0, BALL * 2.0 + 10.0, 4.0), ink)
	draw_rect(Rect2(-BALL - 4.0, -BALL, BALL * 2.0 + 8.0, 2.0), brass_dk)
	var cap := PackedVector2Array([Vector2(-8, -BALL - 1), Vector2(8, -BALL - 1), Vector2(5, -BALL - 7), Vector2(-5, -BALL - 7)])
	draw_colored_polygon(cap, brass)
	draw_polyline(cap + PackedVector2Array([cap[0]]), ink, 1.0)
	# the glass, water-clear with a tint toward the bottom
	draw_circle(Vector2.ZERO, BALL + 1.0, ink)
	draw_circle(Vector2.ZERO, BALL, Color(0.62, 0.84, 0.95, 0.55))
	draw_circle(Vector2(0, BALL * 0.35), BALL * 0.7, Color(0.4, 0.66, 0.85, 0.35))
	# the needles, floating flat in the ball (seen from above at a slant)
	for i in range(maxi(targets.size(), 1)):
		var d := Vector2(sin(_ang[i]), -cos(_ang[i]) * 0.62) * (BALL - 5.0)
		var side := Vector2(-d.y, d.x).normalized() * 2.5
		draw_colored_polygon(PackedVector2Array([d, side, -side]), MARKS.NEEDLE_COLORS[i])
		draw_colored_polygon(PackedVector2Array([-d * 0.8, side, -side]), Color(0.15, 0.15, 0.18))
	draw_circle(Vector2.ZERO, 2.5, brass)
	# light on the glass
	draw_arc(Vector2.ZERO, BALL - 3.0, PI * 1.08, PI * 1.45, 8, Color(1, 1, 1, 0.85), 2.0)
	draw_circle(Vector2(-BALL * 0.42, -BALL * 0.5), 2.0, Color(1, 1, 1, 0.9))
	draw_arc(Vector2.ZERO, BALL, 0.0, TAU, 32, Color(0.9, 0.97, 1.0, 0.7), 1.0)


func _draw_labels(targets: Array, gm: Node) -> void:
	var top := C.y + BALL * 2.0 + 14.0
	var me := get_tree().get_first_node_in_group("player")
	if targets.is_empty():
		var why := "The needle won't settle"
		if gm and me and gm.chain_at < 0 and me.progression.level < gm.LOG_POSE_LEVEL:
			why += " (Lv %d)" % gm.LOG_POSE_LEVEL
		_text([[why, Color(0.95, 0.9, 0.8)]], top, 12, _font)
		if gm and gm.chain_at >= 0 and not gm.log_pose_set():
			_text([["%d min more here, or slay its beast" % ceili(gm.log_pose_wait() / 60.0), Color(0.85, 0.8, 0.7)]], top + 13.0, 8, _small)
		return
	var lvl: int = me.progression.level
	var here := Vector2((me as Node3D).global_position.x, (me as Node3D).global_position.z)
	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		var y := top + i * 26.0
		var nm := str(t["name"])
		_text([[nm, MARKS.NEEDLE_COLORS[i].lightened(0.35)]], y, 12, _font)
		var nw := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var theme := str(t["theme"])
		MARKS.icon(self, Vector2(W - 4.0 - nw - 8.0, y - 4.0), theme, 4.0, MARKS.theme_color(theme))
		var dz: Array = MARKS.danger(int(t["level"]), lvl)
		var dist := here.distance_to(t["pos"])
		_text([["%s  %.1f km  " % [Chain.describe(t), dist / 1000.0], Color(0.88, 0.85, 0.78)], [dz[0], dz[1]]], y + 12.0, 8, _small)
	if targets.size() > 1:
		_text([["A fork: sail to the one you'd take", Color(0.85, 0.8, 0.7)]], top + targets.size() * 26.0, 8, _small)


## Coloured pieces [text, colour] on one line, right-aligned to the strap's right end.
func _text(parts: Array, y: float, size: int, f: Font) -> void:
	var w := 0.0
	for pt in parts:
		w += f.get_string_size(pt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(W - 4.0 - w, y)
	for pt in parts:
		draw_string_outline(f, at, pt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color.BLACK)
		draw_string(f, at, pt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size, pt[1])
		at.x += f.get_string_size(pt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
