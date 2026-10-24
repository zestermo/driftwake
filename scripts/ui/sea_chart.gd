extends Control
## The held map's page (MapHold draws it into the sheet in the captain's hands, at SIZE px: one page
## pixel to one of the PS1 grid's). The sea chart: a parchment map that fills in as you sail
## (GameManager.charted): islands you've come near, with their names; reefs,
## whirlpools, fog banks and wrecks you've passed close to; an X for every
## treasure map you hold. Your captain and the ship are marked; north is up.
## In Brinehollow's sea it's centred on Brinehollow; out on the chain it fits
## the island the crew is at and the ones the log pose points to, each with
## its theme, level and danger, and a course line to each.
## On an island it opens on the island's own page (MapIsleView: the fog of war, `?` marks, what's
## been found); the wheel zooms: in round the captain, out to the whole island, out again to the
## chart, where the islands standing in the world that we've charted show their real coasts. The
## mouse is a pen on it (`pen`, `press`): marks are set and taken off where it points.

const SIZE := Vector2(448, 256)
## World metres from Brinehollow shown to each edge (the chart is square-ish).
const REACH := 1400.0
## Brinehollow's land, about: its forest and beach reach further west.
const BRINEHOLLOW_R := 300.0
const BRINEHOLLOW_OFFSET := Vector2(-45, 80)
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
## The island page, and whether it's the one showing (the island we're on; else the chart).
var isle: MapIsleView
var on_isle := false
## Where the pen points (page px), drawn over everything.
var pen := Vector2(-20, -20)
var _nib: Control
## Behind the chart's ink: the paper, then each standing island's land (key -> Control), and the
## names of the islands drawn that way this frame (no circle for them).
var _paper: Control
var _lands := {}
var _landed := {}


func _init() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load("res://assets/fonts/Silkscreen-Regular.woff2")
	_font_big = load("res://assets/fonts/PixelifySans-Regular.woff2")
	_paper = Control.new()
	_paper.name = "Paper"
	_paper.show_behind_parent = true
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paper.draw.connect(func():
		var ink := Color(0.3, 0.2, 0.12)
		_paper.draw_rect(Rect2(Vector2.ZERO, SIZE), MapIsleView.PAPER)
		_paper.draw_rect(Rect2(Vector2(5, 5), SIZE - Vector2(10, 10)), Color(ink, 0.7), false, 1.0)
		_paper.draw_rect(Rect2(Vector2(8, 8), SIZE - Vector2(16, 16)), Color(ink, 0.35), false, 1.0))
	add_child(_paper)
	isle = MapIsleView.new()
	isle.visible = false
	add_child(isle)
	_nib = Control.new()
	_nib.name = "Pen"
	_nib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nib.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nib.draw.connect(_draw_pen)
	add_child(_nib)


## Opens on the island our captain is on, or the chart at sea.
func on_open() -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var d := MapIsles.at(get_tree(), Vector2(me.global_position.x, me.global_position.z)) if me else {}
	if d.is_empty():
		isle.d = {}
	else:
		isle.show_isle(d, SIZE)
	show_isle(not d.is_empty())


## The island page (true) or the chart.
func show_isle(on: bool) -> void:
	on_isle = on and not isle.d.is_empty()
	isle.visible = on_isle
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()
	_nib.queue_redraw()
	var w := _world()
	if w:
		_view(w, get_node("/root/GameManager"))
		_place_lands()


## The standing islands' land on the chart (charted ones, and the one we're at), from their heights
## through map_land.gdshader with the sea left as the chart's paper.
func _place_lands() -> void:
	var gm := get_node("/root/GameManager")
	var keep := {}
	_landed.clear()
	for d in MapIsles.all(get_tree()):
		var key := str(d["key"])
		keep[key] = true
		if not _lands.has(key):
			_lands[key] = _land_for(d)
		var c: Control = _lands[key]
		var r: Rect2 = d["rect"]
		var o: Vector2 = d["o"]
		var known: bool = key == "brinehollow" or gm.charted.has("island:" + str(d["name"])) or (gm.chain_at >= 0 and key == "isle%d" % gm.chain_at)
		c.visible = not on_isle and known and _inside(o + r.get_center())
		if c.visible:
			_landed[str(d["name"])] = true
			var at := SIZE * 0.5 + (o + r.position - _centre) * _k
			if c.position != at or c.size != r.size * _k:
				c.position = at
				c.size = r.size * _k
				c.queue_redraw()
	for key in _lands.keys():
		if not keep.has(key):
			(_lands[key] as Node).queue_free()
			_lands.erase(key)


func _land_for(d: Dictionary) -> Control:
	var c := Control.new()
	c.name = "Land_" + str(d["key"])
	c.show_behind_parent = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = MapIsleView.LAND
	m.set_shader_parameter("sea_clear", true)
	m.set_shader_parameter("heights", MapIsles.heights_tex(d))
	m.set_shader_parameter("cells", float(d["cells"]))
	m.set_shader_parameter("extent", (d["rect"] as Rect2).size.x)
	c.material = m
	c.draw.connect(func(): c.draw_texture_rect(MapIsles.heights_tex(d), Rect2(Vector2.ZERO, c.size), false))
	add_child(c)
	move_child(c, 1)
	return c


## The pen: a nib over the page with its point at `pen`.
func _draw_pen() -> void:
	var ink := Color(0.25, 0.15, 0.08)
	_nib.draw_colored_polygon(PackedVector2Array([pen, pen + Vector2(3, -8), pen + Vector2(8, -3)]), ink)
	_nib.draw_line(pen + Vector2(5, -5), pen + Vector2(14, -14), ink, 2.0)
	_nib.draw_rect(Rect2(pen - Vector2(0, 1), Vector2(1, 1)), Color(0.9, 0.85, 0.7))


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
	var ink := Color(0.3, 0.2, 0.12)
	var sea_ink := Color(0.55, 0.62, 0.62, 0.5)
	if on_isle:
		_draw_isle_page(ink)
		return
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
			draw_string(_font, c + Vector2(-26, 12), "here be a Leviathan", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, serp)
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
	# the crew: a dot each in their colour
	for p in get_tree().get_nodes_in_group("players"):
		if not p.is_local:
			draw_circle(_to_chart(Vector2(p.global_position.x, p.global_position.z)), 2.5, Net.crew_color(p.net_id).darkened(0.35))
	_north(ink)
	# the crew's marks: numbered flags in their colours
	for id in Net.waypoints.keys():
		var col: Color = Net.crew_color(id) if Net.active else Color(0.75, 0.1, 0.08)
		var pts: Array = Net.waypoints[id]
		for i in range(pts.size()):
			var c := _to_chart(pts[i])
			draw_line(c, c + Vector2(0, -10), ink, 1.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -10), c + Vector2(7, -7.5), c + Vector2(0, -5)]), col)
			draw_string(_font, c + Vector2(3, 8), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	MapMarks.draw_all(self, _to_chart, _font)
	_hints()


func _north(ink: Color) -> void:
	var nc := Vector2(SIZE.x - 26, 30)
	draw_line(nc + Vector2(0, 12), nc + Vector2(0, -12), ink, 2.0)
	draw_colored_polygon(PackedVector2Array([nc + Vector2(0, -14), nc + Vector2(4, -6), nc + Vector2(-4, -6)]), ink)
	draw_string(_font, nc + Vector2(-3, -17), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)


func _hints() -> void:
	var pairs: Array = [["LMB", "MARK"], ["RMB", "UNMARK"], ["C", "CLEAR"]]
	if not isle.d.is_empty():
		pairs.append(["WHEEL", "ZOOM"])
	pairs.append(["M", "PUT AWAY"])
	UIStyle.draw_hints(self, Vector2(14, SIZE.y - 10), pairs, _font, true)


## The island page's own: its name and what's found of it, north, the hints (the island's drawn by `isle`).
func _draw_isle_page(ink: Color) -> void:
	var d := isle.d
	var gm := get_node("/root/GameManager")
	var n := 0
	for s in d["spots"]:
		if MapFog.found(gm, str(d["key"]), str(s["id"])):
			n += 1
	draw_string(_font_big, Vector2(14, 22), str(d["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	var tw := _font_big.get_string_size(str(d["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(_font, Vector2(22 + tw, 21), "%d of %d places found" % [n, d["spots"].size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	_north(ink)
	_hints()


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
	elif _landed.has(str(n["name"])):
		pass
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


## A mouse button with the pen at `at` (page px): the wheel goes between the island and the chart; a
## click sets a mark there (up to Net.MAX_WAYPOINTS of ours); a right-click near one of ours takes it off.
func press(button: int, at: Vector2) -> void:
	if button == MOUSE_BUTTON_WHEEL_UP:
		if not on_isle:
			show_isle(true)
		else:
			isle.step_zoom(1)
		return
	if button == MOUSE_BUTTON_WHEEL_DOWN:
		if on_isle and not isle.step_zoom(-1):
			show_isle(false)
		return
	var w := _world()
	if w == null:
		return
	_view(w, get_node("/root/GameManager"))
	var mine: Array = (Net.waypoints.get(Net.my_id(), []) as Array).duplicate()
	if button == MOUSE_BUTTON_LEFT:
		if at.y < 30.0 or at.y > SIZE.y - 22.0:
			return
		if mine.size() >= Net.MAX_WAYPOINTS:
			mine.pop_front()
		mine.append(isle.page_to_world(at) if on_isle else _centre + (at - SIZE * 0.5) / _k)
		Net.set_waypoints(mine)
		UIStyle.sfx("confirm")
	elif button == MOUSE_BUTTON_RIGHT:
		var best := -1
		var best_d := 12.0
		for i in range(mine.size()):
			var d := (isle.world_to_frame(mine[i]) + isle.frame.position if on_isle else _to_chart(mine[i])).distance_to(at)
			if d < best_d:
				best_d = d
				best = i
		if best >= 0:
			mine.remove_at(best)
			Net.set_waypoints(mine)


## C: our marks and our G marker, gone.
func clear_marks() -> void:
	Net.set_waypoints([])
	Net.unmark()


func _island(pos: Vector2, radius: float, nm: String) -> void:
	if not _shown(pos):
		return
	var c := _to_chart(pos)
	var r := maxf(radius * _k, 4.0)
	if not _landed.has(nm):
		draw_circle(c, r, Color(0.66, 0.55, 0.35))
		draw_arc(c, r, 0.0, TAU, 16, Color(0.4, 0.3, 0.18), 1.5)
	draw_string(_font, c + Vector2(-r, r + 9.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 0.2, 0.12))
