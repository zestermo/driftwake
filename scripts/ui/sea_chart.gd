extends Control
## The sea chart (M): a parchment map of the waters around Brinehollow that
## fills in as you sail (GameManager.charted): islands you've come near, with
## their names; reefs, whirlpools, fog banks and wrecks you've passed close
## to; an X for every treasure map you hold. Your captain and the ship are
## marked; north is up.

const SIZE := Vector2(560, 320)
## World metres from Brinehollow shown to each edge (the chart is square-ish).
const REACH := 1400.0
## Brinehollow's land, about (its chunk is StarterIsland.HALF across each way).
const BRINEHOLLOW_R := 168.0

var _font: Font
var _font_big: Font


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -SIZE.x * 0.5
	offset_top = -SIZE.y * 0.5
	offset_right = SIZE.x * 0.5
	offset_bottom = SIZE.y * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")
	_font_big = load("res://assets/fonts/PixelifySans-Regular.woff2")


func on_open() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _world() -> Node:
	return get_tree().current_scene.get_node_or_null("Islands") if get_tree().current_scene else null


## World x/z to chart pixels (Brinehollow at the middle, north up), held
## inside the parchment's margin (off the edge of the chart: pinned to it).
func _to_chart(p: Vector2, centre: Vector2, scale_k: float) -> Vector2:
	var c := SIZE * 0.5 + (p - centre) * scale_k
	return c.clamp(Vector2(14, 30), SIZE - Vector2(60, 22))


func _draw() -> void:
	var paper := Color(0.86, 0.78, 0.6)
	draw_rect(Rect2(Vector2.ZERO, SIZE), paper)
	draw_rect(Rect2(Vector2(3, 3), SIZE - Vector2(6, 6)), Color(0.45, 0.33, 0.2), false, 2.0)
	var ink := Color(0.3, 0.2, 0.12)
	var sea_ink := Color(0.55, 0.62, 0.62, 0.5)
	var w := _world()
	var gm := get_node_or_null("/root/GameManager")
	if w == null or gm == null:
		return
	var centre: Vector2 = w.get("starter_center")
	var k := minf(SIZE.x, SIZE.y) * 0.5 / REACH
	# a faint grid of the sea (every 500 m)
	for i in range(-8, 9):
		var x := SIZE.x * 0.5 + i * 500.0 * k
		var y := SIZE.y * 0.5 + i * 500.0 * k
		if x > 6.0 and x < SIZE.x - 6.0:
			draw_line(Vector2(x, 6), Vector2(x, SIZE.y - 6), sea_ink, 1.0)
		if y > 6.0 and y < SIZE.y - 6.0:
			draw_line(Vector2(6, y), Vector2(SIZE.x - 6, y), sea_ink, 1.0)
	draw_string(_font_big, Vector2(14, 22), "Sea Chart", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	# islands
	_island(Vector2(centre), BRINEHOLLOW_R, "Brinehollow", centre, k, true)
	for info in w.get("island_infos"):
		var nm := str(info.get("name", "?"))
		_island(info["pos"], float(info["radius"]), nm, centre, k, gm.charted.has("island:" + nm))
	var rt = w.get("redtide")
	if rt and gm.charted.has("island:Redtide Rock"):
		var rp := Vector2(rt.position.x, rt.position.z)
		var c := _to_chart(rp, centre, k)
		draw_circle(c, 4.0, Color(0.45, 0.2, 0.15))
		draw_string(_font, c + Vector2(6, 3), "Redtide Rock", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.15, 0.1))
	# what's been seen at sea
	var sf := get_tree().get_first_node_in_group("sea_features")
	if sf:
		for i in range(sf.reefs.size()):
			if gm.charted.has("reef:%d" % i):
				var c := _to_chart(sf.reefs[i][0], centre, k)
				for j in range(4):
					var o := Vector2(cos(j * 1.7), sin(j * 2.3)) * 3.0
					draw_circle(c + o, 1.5, ink)
				draw_string(_font, c + Vector2(5, 3), "reef", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		for i in range(sf.whirls.size()):
			if gm.charted.has("whirl:%d" % i):
				var c := _to_chart(sf.whirls[i][0], centre, k)
				draw_arc(c, 5.0, 0.0, TAU * 0.8, 10, Color(0.2, 0.3, 0.5), 1.5)
				draw_arc(c, 2.5, 1.0, TAU * 0.9, 8, Color(0.2, 0.3, 0.5), 1.5)
				draw_string(_font, c + Vector2(7, 3), "whirlpool", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.3, 0.5))
		for i in range(sf.fogs.size()):
			if gm.charted.has("fog:%d" % i):
				var c := _to_chart(sf.fogs[i][0], centre, k)
				draw_circle(c, float(sf.fogs[i][1]) * k, Color(0.95, 0.95, 0.95, 0.35))
				draw_string(_font, c + Vector2(-8, 3), "fog", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.4, 0.4))
		for i in range(sf.wrecks.size()):
			if gm.charted.has("wreck:%d" % i):
				var c := _to_chart(sf.wrecks[i][0], centre, k)
				draw_line(c + Vector2(-4, 2), c + Vector2(4, -1), ink, 2.0)
				draw_line(c + Vector2(0, 0), c + Vector2(1, -6), ink, 1.0)
				draw_string(_font, c + Vector2(6, 3), "wreck" + (" (picked over)" if gm.opened.has("wreck_%d" % i) else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		if sf.sea_king and gm.charted.has("king"):
			var c := _to_chart(sf.sea_king.lair, centre, k)
			var serp := Color(0.25, 0.4, 0.35)
			var pts := PackedVector2Array()
			for j in range(9):
				pts.append(c + Vector2(-8 + j * 2.0, sin(j * 1.3) * 2.5))
			draw_polyline(pts, serp, 1.5)
			draw_circle(pts[pts.size() - 1], 1.8, serp)
			draw_string(_font, c + Vector2(-26, 12), "here be a Sea King", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, serp)
		# X marks the spot
		for t in gm.maps.keys():
			var ti := int(t)
			if ti < sf.treasures.size() and not gm.opened.has("treasure_%d" % ti):
				var p3: Vector3 = sf.treasures[ti][0]
				var c := _to_chart(Vector2(p3.x, p3.z), centre, k)
				var red := Color(0.75, 0.1, 0.08)
				draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), red, 2.0)
				draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), red, 2.0)
	# the ship and our captain
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if ship:
		var c := _to_chart(Vector2(ship.global_position.x, ship.global_position.z), centre, k)
		var h: float = ship.global_rotation.y
		var f := Vector2(-sin(h), -cos(h))
		var r := Vector2(f.y, -f.x)
		draw_colored_polygon(PackedVector2Array([c + f * 7.0, c - f * 5.0 + r * 4.0, c - f * 5.0 - r * 4.0]), Color(0.15, 0.3, 0.55))
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me:
		var c := _to_chart(Vector2(me.global_position.x, me.global_position.z), centre, k)
		draw_circle(c, 3.0, Color(0.85, 0.15, 0.1))
		draw_arc(c, 5.0, 0.0, TAU, 12, Color(0.85, 0.15, 0.1), 1.0)
	# north
	var nc := Vector2(SIZE.x - 26, 30)
	draw_line(nc + Vector2(0, 12), nc + Vector2(0, -12), ink, 2.0)
	draw_colored_polygon(PackedVector2Array([nc + Vector2(0, -14), nc + Vector2(4, -6), nc + Vector2(-4, -6)]), ink)
	draw_string(_font, nc + Vector2(-3, -17), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	draw_string(_font, Vector2(14, SIZE.y - 10), "M: close", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)


func _island(pos: Vector2, radius: float, nm: String, centre: Vector2, k: float, known: bool) -> void:
	if not known:
		return
	var c := _to_chart(pos, centre, k)
	var r := maxf(radius * k, 4.0)
	draw_circle(c, r, Color(0.66, 0.55, 0.35))
	draw_arc(c, r, 0.0, TAU, 16, Color(0.4, 0.3, 0.18), 1.5)
	draw_string(_font, c + Vector2(-r, r + 9.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.2, 0.12))
