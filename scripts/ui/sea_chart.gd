extends Control
## The sea chart (M): a parchment map that fills in as you sail
## (GameManager.charted): islands you've come near, with their names; reefs,
## whirlpools, fog banks and wrecks you've passed close to; an X for every
## treasure map you hold. Your captain and the ship are marked; north is up.
## In Brinehollow's sea it's centred on Brinehollow; out on the chain it fits
## the island the crew is at and the ones the log pose points to, each with
## its theme, level and danger, and a course line to each.

const SIZE := Vector2(560, 320)
## World metres from Brinehollow shown to each edge (the chart is square-ish).
const REACH := 1400.0
## Brinehollow's land, about: its forest and beach reach further west.
const BRINEHOLLOW_R := 200.0
const BRINEHOLLOW_OFFSET := Vector2(-45, 0)
## A chain island's shore, about, before it's built (m).
const ISLE_R := 380.0
const MARKS := preload("res://scripts/ui/chain_marks.gd")
## The needles' colours, dark enough for the parchment.
const COURSE := [Color(0.72, 0.12, 0.08), Color(0.12, 0.28, 0.7)]

var _font: Font
var _font_big: Font
## The view: world point at the chart's middle, pixels per metre, and whether
## things off the chart are pinned to its edge (Brinehollow's sea) or left off.
var _centre := Vector2.ZERO
var _k := 1.0
var _pin := true


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -SIZE.x * 0.5
	offset_top = -SIZE.y * 0.5
	offset_right = SIZE.x * 0.5
	offset_bottom = SIZE.y * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")
	_font_big = load("res://assets/fonts/PixelifySans-Regular.woff2")


func on_open() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _world() -> Node:
	return get_tree().current_scene.get_node_or_null("Islands") if get_tree().current_scene else null


## Where the ship and our captain are (world x/z).
func _crew() -> Array:
	var pts: Array = []
	for n in [get_tree().get_first_node_in_group("ship"), get_tree().get_first_node_in_group("player")]:
		if n:
			pts.append(Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z))
	return pts


## Brinehollow's sea: Brinehollow in the middle, REACH to the edge (further
## while you're out past it). On the chain: fitted round the island we're at,
## the islands the log pose points to, the ship and you.
func _view(w: Node, gm: Node) -> void:
	var sc: Vector2 = w.get("starter_center")
	var half := SIZE * 0.5
	if gm.chain_at < 0:
		_centre = sc
		_pin = true
		var reach := REACH
		for p in _crew():
			var d: Vector2 = (p - sc).abs()
			reach = maxf(reach, maxf(d.x * half.y / (half.x - 60.0), d.y) + 120.0)
		_k = minf(half.x, half.y) / reach
		return
	_pin = false
	var box := Rect2(gm.chain().node(gm.chain_at)["pos"], Vector2.ZERO).grow(ISLE_R + 70.0)
	for n in MARKS.targets(gm):
		box = box.merge(Rect2(n["pos"], Vector2.ZERO).grow(ISLE_R + 70.0))
	for p in _crew():
		box = box.expand(p)
	_centre = box.get_center()
	_k = minf(minf((half.x - 70.0) / (box.size.x * 0.5), (half.y - 40.0) / (box.size.y * 0.5)), minf(half.x, half.y) / REACH)


## World x/z to chart pixels (north up), held inside the parchment's margin
## (off the edge of the chart: pinned to it).
func _to_chart(p: Vector2) -> Vector2:
	var c := SIZE * 0.5 + (p - _centre) * _k
	return c.clamp(Vector2(14, 30), SIZE - Vector2(60, 22))


func _inside(p: Vector2) -> bool:
	var c := SIZE * 0.5 + (p - _centre) * _k
	return c == c.clamp(Vector2(14, 30), SIZE - Vector2(60, 22))


## Draw something at `p`? (Off the chart on the chain, it's left off.)
func _shown(p: Vector2) -> bool:
	return _pin or _inside(p)


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
	_view(w, gm)
	var sc: Vector2 = w.get("starter_center")
	# a faint grid of the sea (every 500 m from Brinehollow)
	var lo := _centre - SIZE * 0.5 / _k
	var hi := _centre + SIZE * 0.5 / _k
	for i in range(floori((lo.x - sc.x) / 500.0), ceili((hi.x - sc.x) / 500.0) + 1):
		var x := SIZE.x * 0.5 + (sc.x + i * 500.0 - _centre.x) * _k
		if x > 6.0 and x < SIZE.x - 6.0:
			draw_line(Vector2(x, 6), Vector2(x, SIZE.y - 6), sea_ink, 1.0)
	for i in range(floori((lo.y - sc.y) / 500.0), ceili((hi.y - sc.y) / 500.0) + 1):
		var y := SIZE.y * 0.5 + (sc.y + i * 500.0 - _centre.y) * _k
		if y > 6.0 and y < SIZE.y - 6.0:
			draw_line(Vector2(6, y), Vector2(SIZE.x - 6, y), sea_ink, 1.0)
	var chain = gm.chain()
	var title := "Sea Chart"
	if gm.chain_at >= 0:
		title += " - " + str(chain.node(gm.chain_at)["name"])
	draw_string(_font_big, Vector2(14, 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	# islands
	_island(sc + BRINEHOLLOW_OFFSET, BRINEHOLLOW_R, "Brinehollow")
	var rt = w.get("redtide")
	if rt and gm.charted.has("island:Redtide Rock") and _shown(Vector2(rt.position.x, rt.position.z)):
		var c := _to_chart(Vector2(rt.position.x, rt.position.z))
		draw_circle(c, 4.0, Color(0.45, 0.2, 0.15))
		draw_string(_font, c + Vector2(6, 3), "Redtide Rock", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.15, 0.1))
	_chain_islands(w, gm, chain, sc, ink)
	# what's been seen at sea
	var sf := get_tree().get_first_node_in_group("sea_features")
	if sf:
		for i in range(sf.reefs.size()):
			if gm.charted.has("reef:%d" % i) and _shown(sf.reefs[i][0]):
				var c := _to_chart(sf.reefs[i][0])
				for j in range(4):
					var o := Vector2(cos(j * 1.7), sin(j * 2.3)) * 3.0
					draw_circle(c + o, 1.5, ink)
				draw_string(_font, c + Vector2(5, 3), "reef", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		for i in range(sf.whirls.size()):
			if gm.charted.has("whirl:%d" % i) and _shown(sf.whirls[i][0]):
				var c := _to_chart(sf.whirls[i][0])
				draw_arc(c, 5.0, 0.0, TAU * 0.8, 10, Color(0.2, 0.3, 0.5), 1.5)
				draw_arc(c, 2.5, 1.0, TAU * 0.9, 8, Color(0.2, 0.3, 0.5), 1.5)
				draw_string(_font, c + Vector2(7, 3), "whirlpool", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.3, 0.5))
		for i in range(sf.fogs.size()):
			if gm.charted.has("fog:%d" % i) and _shown(sf.fogs[i][0]):
				var c := _to_chart(sf.fogs[i][0])
				draw_circle(c, float(sf.fogs[i][1]) * _k, Color(0.95, 0.95, 0.95, 0.35))
				draw_string(_font, c + Vector2(-8, 3), "fog", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.4, 0.4))
		for i in range(sf.wrecks.size()):
			if gm.charted.has("wreck:%d" % i) and _shown(sf.wrecks[i][0]):
				var c := _to_chart(sf.wrecks[i][0])
				draw_line(c + Vector2(-4, 2), c + Vector2(4, -1), ink, 2.0)
				draw_line(c + Vector2(0, 0), c + Vector2(1, -6), ink, 1.0)
				draw_string(_font, c + Vector2(6, 3), "wreck" + (" (picked over)" if gm.opened.has("wreck_%d" % i) else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		if sf.sea_king and gm.charted.has("king") and _shown(sf.sea_king.lair):
			var c := _to_chart(sf.sea_king.lair)
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
				if not _shown(Vector2(p3.x, p3.z)):
					continue
				var c := _to_chart(Vector2(p3.x, p3.z))
				var red := Color(0.75, 0.1, 0.08)
				draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), red, 2.0)
				draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), red, 2.0)
	# the ship and our captain
	var ship := get_tree().get_first_node_in_group("ship") as Node3D
	if ship:
		var c := _to_chart(Vector2(ship.global_position.x, ship.global_position.z))
		var h: float = ship.global_rotation.y
		var f := Vector2(-sin(h), -cos(h))
		var r := Vector2(f.y, -f.x)
		draw_colored_polygon(PackedVector2Array([c + f * 7.0, c - f * 5.0 + r * 4.0, c - f * 5.0 - r * 4.0]), Color(0.15, 0.3, 0.55))
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me:
		var c := _to_chart(Vector2(me.global_position.x, me.global_position.z))
		draw_circle(c, 3.0, Color(0.85, 0.15, 0.1))
		draw_arc(c, 5.0, 0.0, TAU, 12, Color(0.85, 0.15, 0.1), 1.0)
	# north
	var nc := Vector2(SIZE.x - 26, 30)
	draw_line(nc + Vector2(0, 12), nc + Vector2(0, -12), ink, 2.0)
	draw_colored_polygon(PackedVector2Array([nc + Vector2(0, -14), nc + Vector2(4, -6), nc + Vector2(-4, -6)]), ink)
	draw_string(_font, nc + Vector2(-3, -17), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	# the crew's marks: numbered flags in their colours
	for id in Net.waypoints.keys():
		var col: Color = Net.crew_color(id) if Net.active else Color(0.75, 0.1, 0.08)
		var pts: Array = Net.waypoints[id]
		for i in range(pts.size()):
			var c := _to_chart(pts[i])
			draw_line(c, c + Vector2(0, -10), ink, 1.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(7, -7.5), c + Vector2(0, -5)]), col)
			draw_string(_font, c + Vector2(3, 8), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	draw_string(_font, Vector2(14, SIZE.y - 10), "Click: set a mark   Right-click: remove   C: clear your marks   M: close", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)


## The chain's islands: the one we're at (marked), where the log pose points
## (a course line from here in the needle's colour; not built yet: a dashed
## shore), and any other built one we've charted.
func _chain_islands(w: Node, gm: Node, chain, sc: Vector2, ink: Color) -> void:
	var targets: Array = MARKS.targets(gm)
	var built := {}
	for info in w.get("island_infos"):
		built[int(info["id"])] = float(info["radius"])
	var from: Vector2 = chain.node(gm.chain_at)["pos"] if gm.chain_at >= 0 else sc
	for i in range(targets.size()):
		var a := _to_chart(from)
		var b := _to_chart(targets[i]["pos"])
		var n := int(a.distance_to(b) / 6.0)
		for j in range(n):
			if j % 2 == 0:
				draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), COURSE[i], 1.0)
	var target_ids: Array = targets.map(func(t): return int(t["id"]))
	if gm.chain_at >= 0:
		_chain_island(chain.node(gm.chain_at), built.get(gm.chain_at, 0.0), ink, true)
	for i in range(targets.size()):
		_chain_island(targets[i], built.get(int(targets[i]["id"]), 0.0), COURSE[i], false)
	for id in built.keys():
		var nm := str(chain.node(id)["name"])
		if id != gm.chain_at and not target_ids.has(id) and gm.charted.has("island:" + nm):
			_chain_island(chain.node(id), built[id], ink, false)


## One chain island: its shore (dashed while unbuilt), its name, and under it
## the theme icon, "Jungle  Lv 7" and the danger for our captain. Off the
## chart (Brinehollow's sea): an arrow at the edge the way it lies, and how far.
func _chain_island(n: Dictionary, radius: float, col: Color, here: bool) -> void:
	var pos: Vector2 = n["pos"]
	var c := _to_chart(pos)
	var r := maxf((radius if radius > 0.0 else ISLE_R) * _k, 4.0)
	var off := not _inside(pos)
	var ink := Color(0.3, 0.2, 0.12)
	if off:
		var d := (pos - _centre).normalized()
		var s := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([c + d * 7.0, c - d * 3.0 + s * 5.0, c - d * 3.0 - s * 5.0]), col)
		r = 6.0
	elif radius > 0.0:
		draw_circle(c, r, Color(0.66, 0.55, 0.35))
		draw_arc(c, r, 0.0, TAU, 24, Color(0.4, 0.3, 0.18), 1.5)
	else:
		for j in range(12):
			draw_arc(c, r, j * TAU / 12.0, (j + 0.5) * TAU / 12.0, 3, Color(0.4, 0.3, 0.18), 1.0)
	if here:
		draw_arc(c, r + 4.0, 0.0, TAU, 24, Color(0.75, 0.12, 0.08), 1.5)
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var line1 := str(n["name"]) + ("  (here)" if here else "")
	if off:
		line1 += "  %.1f km" % (Vector2(me.global_position.x, me.global_position.z).distance_to(pos) / 1000.0)
	var line2 := Chain.describe(n) + "  "
	var dz: Array = MARKS.danger(int(n["level"]), me.progression.level)
	var w1 := _font.get_string_size(line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w2 := 10.0 + _font.get_string_size(line2 + dz[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var at := Vector2(c.x - maxf(w1, w2) * 0.5, c.y + r + 9.0)
	if at.y > SIZE.y - 30.0:
		at.y = c.y - r - 14.0
	at.x = clampf(at.x, 8.0, SIZE.x - 8.0 - maxf(w1, w2))
	draw_string(_font, at, line1, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	var theme := str(n["theme"])
	MARKS.icon(self, at + Vector2(3, 6), theme, 3.5, MARKS.theme_color(theme, true))
	draw_string(_font, at + Vector2(10, 9), line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	var lw := _font.get_string_size(line2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_string(_font, at + Vector2(10 + lw, 9), dz[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, (dz[1] as Color).darkened(0.45))


## Click: a mark there (up to Net.MAX_WAYPOINTS of ours); right-click near
## one of ours: it's gone.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var w := _world()
	if w == null:
		return
	_view(w, get_node("/root/GameManager"))
	var mine: Array = (Net.waypoints.get(Net.my_id(), []) as Array).duplicate()
	var at: Vector2 = event.position
	if event.button_index == MOUSE_BUTTON_LEFT:
		if at.y < 30.0 or at.y > SIZE.y - 22.0:
			return
		if mine.size() >= Net.MAX_WAYPOINTS:
			mine.pop_front()
		mine.append(_centre + (at - SIZE * 0.5) / _k)
		Net.set_waypoints(mine)
		get_node("/root/GameMenu").call("_play")
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		var best := -1
		var best_d := 12.0
		for i in range(mine.size()):
			var d := _to_chart(mine[i]).distance_to(at)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			mine.remove_at(best)
			Net.set_waypoints(mine)
		accept_event()


## C: our marks and our G marker, gone.
func clear_marks() -> void:
	Net.set_waypoints([])
	Net.unmark()


func _island(pos: Vector2, radius: float, nm: String) -> void:
	if not _shown(pos):
		return
	var c := _to_chart(pos)
	var r := maxf(radius * _k, 4.0)
	draw_circle(c, r, Color(0.66, 0.55, 0.35))
	draw_arc(c, r, 0.0, TAU, 16, Color(0.4, 0.3, 0.18), 1.5)
	draw_string(_font, c + Vector2(-r, r + 9.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.2, 0.12))
