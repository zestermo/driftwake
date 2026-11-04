extends SceneTree
## The Admiralty's stronghold (StrongholdIsland, 1.27): sailing in, from above, side-on, the quay and the grand stair,
## the ward, the bridge, the keep, the arsenal and the prison; each captioned, then a contact sheet (<out>_sheet.png).
## Args: <out_prefix> [chain seed | -]  (CSHOT_HOUR=18.4 renders at that hour, 11 by default; CSHOT_ONLY=quay,keep just those)
var t := 0.0
var out := ""
var cam: Camera3D
var isl
var want := -1
var shots: Array = []
var idx := 0
var settle := 0
var frames: Array = []
var caption: Label
## (1.30, CSHOT_SCOURING=1) the Scouring under way: the smoke at full, and before each shot a few shells bursting round
## where it looks, caught mid-burst.
var sc
var shot_at := 0.0


func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 1 and a[1] != "-":
		root.get_node("GameManager").chain_seed = int(a[1])
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null:
		return false
	var gm = root.get_node("GameManager")
	# (the stronghold is off the chain: it builds while a captain is near it, so the captain sails over to it)
	if want < 0:
		want = w.chain().stronghold_id()
		var me = get_first_node_in_group("player")
		if me == null or want < 0:
			want = -1
			return false
		var sp: Vector2 = w.chain().node(want)["pos"]
		me.global_position = Vector3(sp.x + 300.0, 2.0, sp.y + 300.0)
		me.reset_physics_interpolation()
		var wx = root.get_node("Weather")
		var hour := float(OS.get_environment("CSHOT_HOUR")) if OS.get_environment("CSHOT_HOUR") != "" else 11.0
		wx.set_world_time(wx.time_at(hour))
		gm.chain_since = wx.world_time()
	if t < 1.5:
		return false
	if isl == null:
		if not w.chain_islands.has(want):
			return false
		_setup(w.chain_islands[want])
		return false
	settle += 1
	if settle < 10:
		return false
	if sc and float(root.get_node("Ocean").clock()) < shot_at + 1.1:
		return false
	if sc:
		print("scouring %s: %s, %d shells pending, %d blazes, %d ships, smoke %.2f" % [shots[idx][0], sc.state, sc._pending.size(), sc.fx.blazes.size(), sc.fx.ships.size(), root.get_node("Weather").smoke])
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
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
	print("stronghold %d %s (Lv %d, chain seed %d): built %s" % [int(isl.node["id"]), isl.island_name, int(isl.node["level"]),
		int(root.get_node("GameManager").chain_seed), isl.build_ms])
	var tris := 0
	var draws := 0
	var by_piece := {}
	for mi in isl.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh:
			draws += mi.mesh.get_surface_count()
			var key := str(mi.get_parent().name).get_slice("_", 0)
			for s in range(mi.mesh.get_surface_count()):
				var arr = mi.mesh.surface_get_arrays(s)
				var n: int = (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] else arr[Mesh.ARRAY_VERTEX].size()) / 3
				tris += n
				by_piece[key] = int(by_piece.get(key, 0)) + n
	print("stronghold: triangles by piece %s" % by_piece)
	print("stronghold: %d mesh instances, %d surfaces, %d triangles, %d collision shapes, %d nodes" % [isl.find_children("*", "MeshInstance3D", true, false).size(),
		draws, tris, isl.find_children("*", "CollisionShape3D", true, false).size(), isl.find_children("*", "", true, false).size()])
	var hud = get_first_node_in_group("hud")
	if hud: hud.visible = false
	root.get_node("Settings").set_value("video", "perf_overlay", false, false)
	cam = Camera3D.new(); cam.fov = 60; cam.far = 4000
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
	var ship = get_first_node_in_group("ship")
	var moor: Array = isl.mooring()
	ship.place(moor[0], moor[1])
	# (the captain in the plaza, unseen: its people and the toughs wake for a captain nearby, and people hide past 230 m
	# from every captain: the plaza is within that of the throne hall, the docks and the slum alike)
	var me = get_first_node_in_group("player")
	me.global_position = isl.city_global(Vector2(0, 10), 12.3)
	me.reset_physics_interpolation()
	me.visible = false
	shots = [
		["approach", "sailing in", Vector2(60, 420), 30.0, Vector2(0, -40), 20.0],
		["aerial", "from high above", Vector2(220, 260), 220.0, Vector2(0, -30), 0.0],
		["side", "the rock side-on", Vector2(200, -40), 40.0, Vector2(0, -40), 10.0],
		["quay", "the Landing's quay and the grand stair", Vector2(-30, 52), 1.7, Vector2(0, 14), 6.0],
		["stair", "up the grand stair", Vector2(0, 35), 1.7, Vector2(0, 10), 4.0],
		["ward", "the Lower Ward toward the bridge", Vector2(0, 14), 1.7, Vector2(0, -60), 14.0],
		["bridge", "on the Bridge of Judgement", Vector2(0, -22), 1.7, Vector2(0, -86), 14.0],
		["keep", "the Keep", Vector2(0, -56), 1.7, Vector2(0, -86), 18.0],
		["arsenal", "the Arsenal's foundry", Vector2(50, -4), 1.7, Vector2(84, -21), 8.0],
		["prison", "the Prison Tower", Vector2(-50, -4), 1.7, Vector2(-82, -18), 16.0],
		["verdict", "the Verdict from the ward", Vector2(-10, 16), 1.7, Vector2(0, -86), 130.0],
		["verdict_sea", "the Verdict from out at sea", Vector2(-120, 700), 6.0, Vector2(0, -86), 90.0],
		["cove", "the west cove and its drain", Vector2(-138, -6), 1.7, Vector2(-108.6, -14), 2.5],
		["reefs", "the reefs off its east side", Vector2(230, 70), 5.0, Vector2(120, 0), 2.0],
		["mess_in", "inside the Mess Hall", Vector2(-20.5, 1), 1.7, Vector2(-40, 1), 1.0],
		["barracks_in", "inside the Barracks", Vector2(20.5, 1), 1.7, Vector2(40, 1), 1.0],
		["casting_in", "inside the Casting Hall", Vector2(70.5, -23), 1.8, Vector2(96, -23), 2.0],
		["command_door", "the Command Hall's door", Vector2(0, -50), 1.7, Vector2(0, -62), 8.0],
		["command_in", "inside the Command Hall", Vector2(0, -64.5), 2.0, Vector2(0, -104), 3.0],
		["sea_gate", "the sea gate from outside", Vector2(18, 170), 4.0, Vector2(18, 96), 16.0],
		["arcade", "the arcade over the Landing", Vector2(-20, 40), 1.7, Vector2(10, 58), 20.0],
		# (1.30, the acts) the Landing's gate down across the stair, the winch; the Verdict's roof and its balcony
		["gate", "the Landing's gate (act 1), its winch on the left", Vector2(3, 30), 1.7, Vector2(0, 18.6), 10.0],
		["roof_below", "the Verdict's roof over the Command Hall's door", Vector2(0, -36), 1.7, Vector2(0, -56), 33.0],
		["roof", "on the Verdict's roof, Vane's stand (act 3)", Vector2(-12, -61), 35.0, Vector2(6, -50), 32.0],
		["casting_pour", "the Casting Hall: Kesh's foundry", Vector2(70.5, -16), 2.4, Vector2(90, -28), 1.0],
		["perch", "the perch up the ward's front wall, its rack of long guns", Vector2(5, 13), 3.0, Vector2(30, 16), 6.0],
		["cells", "the prison yard's cell block, where the riot breaks out", Vector2(-76, 8), 2.0, Vector2(-91, 5), 2.0],
		["yard", "the prison yard: Marrow's riot, the cell block, the catwalks", Vector2(-60, 9), 5.0, Vector2(-80, 2), 1.0],
		# looking up from underneath: what a gap in the geometry would show
		["up_tower", "up at a ward tower", Vector2(40.0, 13.0), 1.7, Vector2(44.6, 18.6), 30.0],
		["under_bridge", "under the bridge from the chasm", Vector2(10.0, -31.0), 1.5, Vector2(0, -31.0), 18.0],
		["up_gate", "up under the keep gate", Vector2(0, -46.0), 1.7, Vector2(0, -52.0), 14.0],
		["up_verdict", "up the Verdict from its foot", Vector2(6.0, -58.0), 1.7, Vector2(0, -86.0), 160.0],
		# (1.30 round 7, the art pass) the districts dressed, at ground level
		["foundry_yard", "the foundry's yard: slag, coal, the tramway, the crucible", Vector2(60, 10), 1.7, Vector2(96, -20), 2.0],
		["cellblock", "the cell block's tiers and catwalks over Marrow's yard", Vector2(-66, 10), 1.7, Vector2(-92, 5), 6.0],
		["battery", "the quay's battery and the moored warships", Vector2(-20, 48), 1.7, Vector2(-60, 90), 3.0],
		["warships", "the warships moored round the harbour", Vector2(10, 150), 12.0, Vector2(0, 70), 4.0],
		["hall_side", "the Command Hall's desks and shelves", Vector2(14, -66), 1.7, Vector2(20, -100), 2.0],
		# (1.30, the Scouring's ring: with CSHOT_SCOURING)
		["ring", "the warships' ring from over the keep", Vector2(0, -70), 60.0, Vector2(-170, 150), 0.0],
	]
	var only := OS.get_environment("CSHOT_ONLY")
	if only != "":
		shots = shots.filter(func(e): return e[0] in only.split(","))
	if OS.get_environment("CSHOT_SCOURING") == "1":
		sc = isl.city.get_node("Scouring")
		sc.grace = 0.0
		sc.count = 0.0
		me.health_component.max_health = 1.0e7
		me.health_component.current_health = 1.0e7
		# (once the ship's settled at her mooring, inside the ring)
		settle = -1000000
		await create_timer(2.0).timeout
		root.get_node("GameManager").world_flags["sh_seal_keep"] = true
		await create_timer(1.0).timeout
		# (a fortress already burning: fourteen shells over its districts, each setting a great fire)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for j in range(14):
			var r: Rect2 = StrongholdPlan.DISTRICTS[j % StrongholdPlan.DISTRICTS.size()][1]
			var hit: Array = sc._from_sky(isl.city_global(Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y)), 0.0))
			sc._fire(hit[0], hit[1], hit[2], float(root.get_node("Ocean").clock()) + 0.5 + j * 0.15, 800000 + j, true)
		await create_timer(7.0).timeout
		settle = 0
	_aim()


func _aim():
	var s: Array = shots[idx]
	caption.text = "%s  -  %s" % [isl.island_name, s[1]]
	var from: Vector2 = s[2]
	var to: Vector2 = s[4]
	cam.global_position = isl.city_global(from, _base(from) + float(s[3]))
	cam.look_at(isl.city_global(to, _base(to) + float(s[5])), Vector3.UP)
	if sc:
		sc.fx.level = 1.0
		shot_at = float(root.get_node("Ocean").clock())
		var rng := RandomNumberGenerator.new()
		rng.seed = idx
		var dir := (to - from).normalized()
		for j in range(4):
			var q: Vector2 = from + dir * rng.randf_range(40.0, 90.0) + Vector2(-dir.y, dir.x) * rng.randf_range(-28.0, 28.0)
			var hit: Array = sc._from_sky(isl.city_global(q, 0.0))
			sc._fire(hit[0], hit[1], hit[2], shot_at + 0.45 + j * 0.15, 900000 + idx * 10 + j)


## The height a shot's heights are over: a district or way's floor, else the rock, else the sea.
func _base(q: Vector2) -> float:
	var g := StrongholdPlan.ground(q)
	if g > -INF:
		return g
	return maxf(StrongholdPlan.terrain(q), 0.0) if StrongholdPlan.land_t(q) < 0.0 else 0.0


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
