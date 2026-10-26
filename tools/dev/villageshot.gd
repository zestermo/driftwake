extends SceneTree
## A chain island's village (IslandVillage): from above, from the road in, the plaza,
## down each lane, the market, the shrine, the workshop, inside the trader's store and
## a home; captioned, then a contact sheet (<out>_sheet.png). Reads the village's own
## data (plaza, lanes, buildings, market) for its cameras.
## Args: <out_prefix> [chain seed | -] [node id | -] [layout: town, hamlets, post, stilts, ruins]
## (env VSHOT_HOUR=21: at that hour, 11 by default)
var t := 0.0
var out := ""
var cam: Camera3D
var isl
var vil
var want := -1
var shots: Array = []
var idx := 0
var settle := 0
var frames: Array = []
var caption: Label


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1 and a[1] != "-":
		root.get_node("GameManager").chain_seed = int(a[1])
	if a.size() > 2 and a[2] != "-":
		want = int(a[2])
	if a.size() > 3:
		load("res://scripts/island/village_layouts.gd").force = a[3]
	# (env VSHOT_MARKET=rows: every market that shape, KitMarket.SHAPES)
	if OS.get_environment("VSHOT_MARKET") != "":
		load("res://scripts/island/kit/kit_market.gd").force_shape = OS.get_environment("VSHOT_MARKET")
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null:
		return false
	var gm = root.get_node("GameManager")
	if want < 0:
		want = int(w.chain().start_next[0])
	if gm.chain_at != want:
		gm.apply_chain(want, false, root.get_node("Weather").world_time())
		var wx = root.get_node("Weather")
		var hour := float(OS.get_environment("VSHOT_HOUR")) if OS.get_environment("VSHOT_HOUR") != "" else 11.0
		wx.set_world_time(wx.time_at(hour))
		gm.chain_since = wx.world_time()
	if t < 1.5:
		return false
	if isl == null:
		if not w.chain_ready() or not w.chain_islands.has(want):
			return false
		_setup(w.chain_islands[want])
		return false
	settle += 1
	if settle < 10:
		return false
	var img := root.get_texture().get_image()
	img.save_png("%s_%s.png" % [out, shots[idx][0]])
	frames.append(img)
	idx += 1
	settle = 0
	if idx >= shots.size():
		_sheet()
		print("SAVED")
		quit()
		return false
	_aim()
	return false


func _setup(island) -> void:
	isl = island
	vil = isl.get_node("Site_village/Village")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
	var hud = get_first_node_in_group("hud")
	if hud: hud.visible = false
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	for g in ["player", "ship"]:
		var n = get_first_node_in_group(g)
		if n: n.visible = false
	print("village of %s (%s): %d buildings %s, %d lanes, %d hamlets, %d work spots, %d seats, built %s" % [isl.island_name, vil.layout, vil.buildings.size(),
		vil.buildings.map(func(b): return b["kind"]), vil.lanes.size(), vil.hamlets.size(), vil.work_spots.size(), vil.seats.size(), isl.build_ms])
	cam = Camera3D.new(); cam.fov = 62; cam.far = 3000; cam.near = 0.05
	root.add_child(cam); cam.current = true
	var cl := CanvasLayer.new()
	cl.layer = 100
	root.add_child(cl)
	caption = Label.new()
	caption.position = Vector2(12, 8)
	caption.add_theme_font_size_override("font_size", 22)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	caption.add_theme_constant_override("outline_size", 6)
	cl.add_child(caption)
	var c: Vector2 = vil.plaza["c"]
	var td: Vector2 = (isl.sites["dock"] - c).normalized()
	var sd := Vector2(-td.y, td.x)
	var road: PackedVector2Array = vil.streets[0]
	var r0: Vector2 = road[road.size() - 1]
	for q in road:
		if q.distance_to(c) > 28.0:
			r0 = q
			break
	# [name, caption, camera (island space), target, ortho size]
	var site: Vector2 = isl.sites["village"]
	var hy: float = vil.plaza["y"] if vil.plaza["y"] != INF else _h(c)
	shots = [
		["top", "from above (%s)" % vil.layout, Vector3(site.x, _h(site) + 120.0, site.y), Vector3(site.x, 0, site.y - 0.001), 170.0],
		["aerial", "from over the road in", _g(c + td * 55.0 + sd * 20.0, 34.0), _g(c - td * 10.0, 0.0), 0.0],
		["road", "walking in from the dock", _g(r0, 1.7), _g(c, 2.0), 0.0],
		["plaza", "the heart", Vector3(c.x, hy, c.y) + Vector3(sd.x * 7.0 - td.x * 2.0, 1.7, sd.y * 7.0 - td.y * 2.0), Vector3(c.x, hy, c.y) + Vector3(-sd.x * 6.0 + td.x * 4.0, 1.2, -sd.y * 6.0 + td.y * 4.0), 0.0],
	]
	if not vil.market.is_empty():
		var mc: Vector2 = vil.market["c"]
		var mout: Vector2 = (c - mc).normalized() if mc.distance_to(c) > 1.0 else td
		shots.append(["market", "the market", _g(mc + mout * 11.0, 2.0), _g(mc, 1.0), 0.0])
	for h in vil.hamlets:
		if h["kind"] != "hub":
			var hc: Vector2 = h["c"]
			shots.append(["hamlet_" + h["kind"], "the %s' hamlet" % h["kind"] if h["kind"] != "survivors" else "the survivors", Vector3(hc.x, _h(hc) + 16.0, hc.y + 0.01) + Vector3(td.x, 0, td.y) * 12.0, _g(hc, 0.0), 0.0])
	if vil.layout == "ruins":
		shots.append(["site", "the old village", _g(site + sd * 5.0 + td * 4.0, 2.5), _g(site - sd * 10.0 - td * 6.0, 1.0), 0.0])
	if vil.layout == "stilts":
		shots.append(["under", "under the deck", _g(site + sd * 13.0 + td * 3.0, 1.6), _g(site - sd * 4.0, 2.0), 0.0])
	for g in isl.find_children("Gate*", "", true, false).slice(0, 1):
		var gp: Vector3 = isl.to_local(g.global_position)
		var away: Vector2 = (Vector2(gp.x, gp.z) - site).normalized()
		shots.append(["gate", "a gate from outside", _g(Vector2(gp.x, gp.z) + away * 12.0 + Vector2(-away.y, away.x) * 3.0, 1.8), gp + Vector3(0, 2.5, 0), 0.0])
	for i in range(vil.lanes.size()):
		var l: PackedVector2Array = vil.lanes[i]
		var q: Vector2 = l[mini(4, l.size() - 1)]
		var q2: Vector2 = l[mini(l.size() - 1, l.size() / 2 + 4)]
		shots.append(["lane%d" % i, "down lane %d" % (i + 1), _g(q, 1.7), _g(q2, 1.6), 0.0])
	for b in vil.buildings:
		var n: Node3D = b["node"]
		var p: Vector2 = b["p"]
		var f: Vector2 = b["face"]
		var s := Vector2(-f.y, f.x)
		match str(b["kind"]):
			"shrine", "workshop", "storehouse":
				shots.append([b["kind"], "the %s" % b["kind"], _g(p + f * 9.0 + s * 4.0, 2.2), _g(p, 1.2), 0.0])
			"trade", "home", "elder", "cook":
				if shots.any(func(sh): return sh[0] == b["kind"]):
					continue
				var fl: float = (n.get_node("Inside") as Node3D).position.y
				var eye: Vector3 = isl.to_local(n.to_global(Vector3(0.6, fl + 1.65, 1.9)))
				var look: Vector3 = isl.to_local(n.to_global(Vector3(-0.3, fl + 0.9, -2.0)))
				shots.append([b["kind"], "inside: %s" % b["kind"], eye, look, 0.0])
	_aim()


func _h(p: Vector2) -> float:
	return isl.height_at(p.x, p.y)


func _g(p: Vector2, up: float) -> Vector3:
	return Vector3(p.x, maxf(_h(p), 0.0) + up, p.y)


func _aim():
	var s: Array = shots[idx]
	caption.text = "%s  -  %s" % [isl.island_name, s[1]]
	if float(s[4]) > 0.0:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(s[4])
		cam.global_position = isl.to_global(s[2])
		cam.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.global_position = isl.to_global(s[2])
		cam.look_at(isl.to_global(s[3]), Vector3.UP)


func _sheet() -> void:
	var w: int = frames[0].get_width() / 2
	var h: int = frames[0].get_height() / 2
	var cols := 3
	var rows := ceili(frames.size() / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.08))
	for i in range(frames.size()):
		var f: Image = frames[i]
		f.convert(Image.FORMAT_RGB8)
		f.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(f, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png("%s_sheet.png" % out)
