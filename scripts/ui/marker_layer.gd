extends Control
class_name MarkerLayer
## Crew map markers (G / middle mouse): a diamond over the marked spot with
## who placed it and how far it is. Off screen, it sticks to the screen edge
## and points the way. One marker per captain (a new one replaces the old);
## they fade after LIFETIME. A marker on an enemy follows it (and goes away
## when it dies).

const LIFETIME := 12.0
const EDGE := 14.0

## id -> {name, pos, target, t, color}
var markers: Dictionary = {}
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")


func add(id: int, who: String, pos: Vector3, target: Node, color: Color) -> void:
	markers[id] = {"name": who, "pos": pos, "target": target, "t": LIFETIME, "color": color,
		"enemy": target != null}


func _process(delta: float) -> void:
	for id in markers.keys():
		var m: Dictionary = markers[id]
		m["t"] = float(m["t"]) - delta
		var tg = m["target"]
		if m["enemy"]:
			if tg == null or not is_instance_valid(tg) or not tg.is_inside_tree() or _dead(tg):
				m["t"] = minf(float(m["t"]), 0.0)
			else:
				m["pos"] = (tg as Node3D).global_position + Vector3(0, 2.3, 0)
		if float(m["t"]) <= 0.0:
			markers.erase(id)
	queue_redraw()


func _dead(n: Node) -> bool:
	if n.has_method("is_dead"):
		return bool(n.is_dead())
	var hc = n.get("health_component")
	return hc != null and float(hc.current_health) <= 0.0


## Where `pos` goes on screen: [spot, on screen?, the raw projection]
## (off screen: pinned to the edge, toward it).
func _place(cam: Camera3D, pos: Vector3, vs: Vector2) -> Array:
	var behind := cam.is_position_behind(pos)
	var sp := cam.unproject_position(pos)
	if behind:
		sp = vs - sp
	var inside := not behind and Rect2(Vector2(EDGE, EDGE), vs - Vector2(EDGE, EDGE) * 2.0).has_point(sp)
	var c := sp
	if not inside:
		var mid := vs * 0.5
		var d := sp - mid
		if behind and d.length() < 1.0:
			d = Vector2(0, 1)
		var half := mid - Vector2(EDGE, EDGE)
		var k := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
		c = mid + d * k
	return [c, inside, sp]


## The crew's chart marks (Net.waypoints): a small flag over each, numbered.
func _draw_waypoints(cam: Camera3D, vs: Vector2, me: Node3D) -> void:
	for id in Net.waypoints.keys():
		var col: Color = Net.crew_color(id) if Net.active else Color(1.0, 0.85, 0.3)
		var pts: Array = Net.waypoints[id]
		for i in range(pts.size()):
			var p: Vector2 = pts[i]
			var pos := Vector3(p.x, 3.0, p.y)
			var pl := _place(cam, pos, vs)
			var c: Vector2 = pl[0]
			draw_line(c + Vector2(0, 6), c + Vector2(0, -8), Color(0, 0, 0, 0.8), 3.0)
			draw_line(c + Vector2(0, 6), c + Vector2(0, -8), col, 1.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, -5), c + Vector2(0, -2)]), col)
			var txt := "%d  %dm" % [i + 1, int(Vector2(me.global_position.x, me.global_position.z).distance_to(p))] if me else str(i + 1)
			var tp := Vector2(clampf(c.x - 10.0, 2.0, vs.x - 40.0), c.y + 16.0)
			draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color.BLACK)
			draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vs := get_viewport_rect().size
	var me := get_tree().get_first_node_in_group("player") as Node3D
	_draw_waypoints(cam, vs, me)
	for id in markers.keys():
		var m: Dictionary = markers[id]
		var pos: Vector3 = m["pos"]
		var col: Color = m["color"]
		var a := clampf(float(m["t"]) / 1.5, 0.0, 1.0)
		col.a = a
		var pl := _place(cam, pos, vs)
		var c: Vector2 = pl[0]
		var inside: bool = pl[1]
		var sp: Vector2 = pl[2]
		# pulse for the first second
		var life := LIFETIME - float(m["t"])
		var r := 5.0 + maxf(0.0, 1.0 - life) * 4.0
		var dia := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		var out := PackedVector2Array([c + Vector2(0, -r - 1.5), c + Vector2(r + 1.5, 0), c + Vector2(0, r + 1.5), c + Vector2(-r - 1.5, 0)])
		draw_colored_polygon(out, Color(0, 0, 0, 0.75 * a))
		var fill := col
		if m["enemy"]:
			fill = Color(1.0, 0.25, 0.2, a)
		draw_colored_polygon(dia, fill)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.4), c + Vector2(r * 0.4, 0), c + Vector2(0, r * 0.4), c + Vector2(-r * 0.4, 0)]), Color(1, 1, 1, 0.8 * a))
		if not inside:
			# an arrow nub toward the spot
			var dir := (sp - c).normalized() if (sp - c).length() > 0.5 else (sp - vs * 0.5).normalized()
			var tip := c + dir * (r + 6.0)
			var side := Vector2(-dir.y, dir.x) * 3.0
			draw_colored_polygon(PackedVector2Array([tip, c + dir * (r + 1.0) + side, c + dir * (r + 1.0) - side]), fill)
		var dist := ""
		if me:
			dist = "%dm" % int(me.global_position.distance_to(pos))
		var txt := "%s  %s" % [str(m["name"]), dist]
		var fs := 8
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := Vector2(clampf(c.x - w * 0.5, 2.0, vs.x - w - 2.0), c.y + r + 10.0)
		if tp.y > vs.y - 4.0:
			tp.y = c.y - r - 4.0
		draw_string_outline(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, a))
		draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, a))
