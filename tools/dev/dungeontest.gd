extends SceneTree
## The generated islands' interiors (KitDungeons, KitTemple, Dungeon): every
## island plans one to three caves from the pool (no kind twice), the temple rolls
## on some; their spots keep clear of the village and the dock, a path reaches each
## mouth, chambers and free slots for creatures are in the POI data, the same node
## plans the same interiors. In the world (chain seed 5: a smugglers' grotto and
## the temple; seed 1: bug tunnels; seed 2: a root cavern under its giant tree):
## rock to walk in, crews, a nav zone,
## asleep while nobody's near and awake once a captain comes; the crew fights you
## inside; a captain walks in from the mouth to the end room; the chest opens once
## (the save remembers it); the temple's gate holds until both levers are pulled
## (a guest catching up gets the same gate), then you walk in to the altar and the
## warden; the brood mother wakes when you're in her chamber, her hoard comes
## once per character; the root cavern's end nest cleared sets its flag.
const SEEDS := [1, 2, 3, 4, 7, 12]
var t := 0.0
var step := 0
var wait := 0.0
var p
var gm
var world
var isl
var fails := 0
var KD
var route: Array = []
var ri := 0
var stuck_t := 0.0
var best := INF
var walk_t := 0.0
var cave
var temple
var info: Dictionary


func _initialize():
	root.get_node("GameManager").chain_seed = 5
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond: fails += 1


func finish() -> void:
	Input.action_release("move_forward")
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


func put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.global_position = at + Vector3.UP * 0.6
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func heal() -> void:
	p.health_component.max_health = 90000.0
	p.health_component.current_health = 90000.0


## Walk the route (world points): face each in turn and hold forward. True once at the end.
func walking(d: float) -> bool:
	walk_t += d
	var to: Vector3 = route[ri] - p.global_position
	var flat := Vector2(to.x, to.z)
	if flat.length() < 1.3:
		ri += 1
		best = INF
		stuck_t = 0.0
		if ri >= route.size():
			Input.action_release("move_forward")
			Input.action_release("move_right")
			return true
		return false
	var rig := p.get_viewport().get_camera_3d().get_parent().get_parent() as Node3D
	rig.global_rotation.y = atan2(-to.x, -to.z)
	Input.action_press("move_forward")
	# (up against a crate or a body: sidestep a moment, as a player would)
	if stuck_t > 1.0 and fmod(stuck_t, 1.5) < 0.6:
		Input.action_press("move_right")
	else:
		Input.action_release("move_right")
	if flat.length() < best - 0.3:
		best = flat.length()
		stuck_t = 0.0
	else:
		stuck_t += d
	return false


func start_walk(pts: Array) -> void:
	route = pts
	ri = 0
	best = INF
	stuck_t = 0.0
	walk_t = 0.0


func cave_route(d, e: Dictionary) -> Array:
	var out: Array = []
	var ent: Dictionary = e["tunnels"][0]
	var o: Vector2 = e["mouth_dir"]
	out.append(d.to_global(KD.loc(e, e["mouth"] + o * 4.0, float(e["mouth_y"]) + 0.3)))
	var pts: Array = ent["pts"]
	for i in range(pts.size() - 2, -1, -1):
		out.append(d.to_global(KD.loc(e, pts[i], float(ent["ys"][i]) + 0.3)))
	var chain: Array = e["rooms"].filter(func(r): return r["role"] != "side")
	for i in range(1, chain.size()):
		var tun: Dictionary = e["tunnels"][i]
		for k in range(tun["pts"].size()):
			out.append(d.to_global(KD.loc(e, tun["pts"][k], float(tun["ys"][k]) + 0.3)))
	var end: Dictionary = KD.room_of(e, "end")
	out.append(d.to_global(KD.loc(e, end["c"], float(end["y"]) + 0.3)))
	return out


func _process(d: float) -> bool:
	t += d
	if t > 300.0:
		check("timed out at step %d" % step, false)
		finish()
		return true
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = get_first_node_in_group("player")
			gm = root.get_node("GameManager")
			world = root.get_node("World/Islands")
			KD = load("res://scripts/island/kit/kit_dungeons.gd")
			_plans()
			step = 1
		1:
			if gm.chain_seed != 5:
				gm.chain_seed = 5
			if world._built_seed != 5 or not world.chain_ready():
				return false
			isl = world.chain_islands[world.chain().start_next[0]]
			print("   %s: %s" % [isl.island_name, isl.interiors.map(func(e): return e["kind"])])
			cave = null
			temple = null
			for e in isl.interiors:
				var n = isl.get_node_or_null(str(e["name"]))
				if e["kind"] == "temple":
					temple = n
				else:
					cave = n
			check("seed 5's island has its smugglers' grotto and the temple in the world", cave != null and temple != null and cave.info["kind"] == "smugglers_grotto")
			info = cave.info
			check("...rock to walk on with a collider", cave.get_node("Rock").get_child_count() >= 3 and temple.get_node("Stone") is StaticBody3D)
			var crew = cave.get_node("Enemies/Crew")
			var cap = crew.grunts.filter(func(g): return g.captain)
			print("   grotto crew %d, boss %s" % [crew.grunts.size(), cap[0].title if not cap.is_empty() else "none"])
			check("...a crew of 6+ and its boss at the end", crew.grunts.size() >= 6 and cap.size() == 1 and str(cap[0].title).begins_with("Boss "))
			var bags: Array = isl.find_children("*", "LootBag", true, false)
			check("...its chest kept in the save as %s" % info["reward"], bags.any(func(b): return b.save_id == info["reward"]))
			check("...the temple's hoard as %s" % temple.info["reward"], bags.any(func(b): return b.save_id == temple.info["reward"]))
			var bk = world.get_node("NavBaker")
			check("...each with a navmesh zone", bk._zones.any(func(z): return z["node"] == cave) and bk._zones.any(func(z): return z["node"] == temple))
			check("...lights inside within the budget (%d, %d)" % [cave.lights.size(), temple.lights.size()], cave.lights.size() >= 1 and cave.lights.size() <= 3 and temple.lights.size() <= 4)
			wait = 1.2
			step = 2
		2:
			check("asleep with nobody near: enemies stopped, lights out", cave.enemies.process_mode == Node.PROCESS_MODE_DISABLED and not cave.lights[0].visible)
			heal()
			var o: Vector2 = info["mouth_dir"]
			put(cave.to_global(KD.loc(info, info["mouth"] + o * 4.0, float(info["mouth_y"]))))
			wait = 1.2
			step = 3
		3:
			check("a captain at the mouth: awake, lights on", cave.enemies.process_mode == Node.PROCESS_MODE_INHERIT and cave.lights[0].visible)
			check("...and the banner", cave._arrived)
			# into the middle room, by the crew's fire
			var mid: Dictionary = KD.room_of(info, "mid")
			put(cave.to_global(KD.loc(info, mid["c"], float(mid["y"]))))
			wait = 4.0
			step = 4
		4:
			var crew = cave.get_node("Enemies/Crew")
			var fighting: Array = crew.grunts.filter(func(g): return is_instance_valid(g) and g.in_combat())
			check("the crew fights you inside (%d on you, %.0f hp lost)" % [fighting.size(), 90000.0 - p.health_component.current_health], fighting.size() >= 2)
			var near := false
			for g in fighting:
				if g.global_position.distance_to(p.global_position) < 4.0:
					near = true
			check("...and reaches you across the floor", near)
			for g in crew.grunts:
				if is_instance_valid(g):
					g.health.take_damage(9999999.0)
			wait = 1.0
			step = 5
		5:
			check("their boss beaten: the flag is set", root.get_node("Dialogue").has_flag(str(info["flag"])))
			heal()
			start_walk(cave_route(cave, info))
			put(route[0])
			wait = 0.5
			step = 6
		6:
			if walking(d):
				var end: Dictionary = KD.room_of(info, "end")
				var floor_y: float = cave.to_global(KD.loc(info, end["c"], end["y"])).y
				check("a captain walks in from the mouth to the end room (%.0f s, %d points)" % [walk_t, route.size()], true)
				check("...standing on its floor (%.2f m over)" % (p.global_position.y - floor_y), absf(p.global_position.y - floor_y) < 0.5)
				var bag = cave.get_node("Hoard")
				var gold0: int = p.inventory_component.count("gold")
				bag.take_all(p)
				check("the chest opens: gold in your bag (%d)" % (p.inventory_component.count("gold") - gold0), p.inventory_component.count("gold") > gold0)
				check("...and the save remembers it (once per captain)", gm.opened.has(str(info["reward"])))
				step = 7
			elif stuck_t > 6.0 or walk_t > 60.0:
				check("a captain walks in from the mouth to the end room (stuck at point %d of %d, %s)" % [ri, route.size(), p.global_position], false)
				Input.action_release("move_forward")
				step = 7
		7:
			# the temple: up the stairs into the hall, then to the gate
			info = temple.info
			heal()
			for c in temple.enemies.get_children():
				if c.get("grunts") != null:
					for g in c.grunts:
						if is_instance_valid(g) and not g.captain:
							g.health.take_damage(9999999.0)
				elif c.get("spots") != null:
					for s in c.spots:
						if s["bug"] != null and is_instance_valid(s["bug"]):
							s["bug"].health.take_damage(9999999.0)
			var foot: Vector3 = temple.to_global(Vector3(0, 0, float(load("res://scripts/island/kit/kit_temple.gd").PLINTH[3]) + float(info["stair_len"]) + 2.0))
			start_walk([temple.to_global(Vector3(0, 0.3, 9.0)), temple.to_global(Vector3(0, 0.3, 0.0)), temple.to_global(Vector3(0, 0.3, -12.0))])
			put(foot)
			wait = 1.0
			step = 8
		8:
			if walking(d) or stuck_t > 3.0 or walk_t > 40.0:
				Input.action_release("move_forward")
				var l: Vector3 = temple.to_local(p.global_position)
				check("up the stairs and through the hall (%.0f s)" % walk_t, ri >= 2)
				check("...the sanctum's gate holds you back (at z %.1f)" % l.z, l.z > -8.0 and not temple.gate_col.disabled)
				temple.levers[0].get_node("Lever").interacted.emit(p)
				wait = 0.6
				step = 9
		9:
			check("one lever pulled: the gate still shut", temple.gate_mask == 1 and not temple.gate_col.disabled and not temple.levers[0].get_node("Lever").enabled)
			temple.levers[1].get_node("Lever").interacted.emit(p)
			wait = 2.8
			step = 10
		10:
			check("both pulled: the gate sinks open", temple.gate_col.disabled and temple.gate.position.y < -4.0)
			check("...the co-op state says so", temple.net_gen() == [temple.boss_gen, 3])
			temple.net_set_gen([temple.boss_gen, 0])
			var shut: bool = not temple.gate_col.disabled
			temple.net_set_gen([temple.boss_gen, 3])
			check("...a guest catching up gets the same gate (shut, then open)", shut and temple.gate_col.disabled)
			var cap = temple._captain()
			check("the warden waits in the sanctum (%s, level %d)" % [cap.title if cap else "none", temple.boss_camp.level], cap != null and str(cap.title).begins_with("Warden ") and temple.boss_camp.level == int(info["level"]) + 1)
			cap.health.take_damage(9999999.0)
			heal()
			start_walk([temple.to_global(Vector3(0, 0.3, -12.0)), temple.to_global(Vector3(0, 0.3, -15.5))])
			wait = 0.5
			step = 11
		11:
			if walking(d) or stuck_t > 3.0 or walk_t > 30.0:
				Input.action_release("move_forward")
				check("through the gate to the altar (%.0f s)" % walk_t, ri >= route.size())
				check("the warden beaten: the temple's flag", root.get_node("Dialogue").has_flag(str(info["flag"])))
				var bag = temple.get_node("Hoard")
				bag.take_all(p)
				check("the temple's hoard opens, remembered", gm.opened.has(str(info["reward"])))
				# (every chain's first island is isle0: the next seed's chests have the same keys)
				gm.opened.clear()
				gm.chain_seed = 1
				step = 12
		12:
			# seed 1: the bug tunnels and the brood mother
			if world._built_seed != 1 or not world.chain_ready():
				return false
			isl = world.chain_islands[world.chain().start_next[0]]
			cave = isl.get_node("Dungeon0")
			info = cave.info
			check("seed 1: bug tunnels with the brood mother asleep in the last chamber", info["kind"] == "bug_tunnels" and cave.queen != null and cave.queen.state == 0)
			var bugs = cave.get_node("Enemies/Bugs")
			check("...bugs in the burrows and spitters in the roof", bugs.spots.size() >= 4 and bugs.spots.any(func(s): return s.has("anchor")))
			heal()
			var end: Dictionary = KD.room_of(info, "end")
			put(cave.to_global(KD.loc(info, end["c"], end["y"])))
			wait = 1.5
			step = 13
		13:
			check("in her chamber she wakes", cave.queen.state != 0)
			check("...the boss bar shows her", get_first_node_in_group("hud")._boss_box.visible)
			cave.call_brood()
			wait = 0.5
			step = 14
		14:
			check("her brood crawls out when she calls (%d)" % cave.brood_alive(), cave.brood_alive() >= 2)
			cave.queen.health.take_damage(9999999.0)
			wait = 1.0
			step = 15
		15:
			var bag = cave.get_node_or_null("Hoard")
			check("beaten: her hoard on the nest", bag != null and bag.save_id == info["reward"])
			check("...her flag", root.get_node("Dialogue").has_flag(str(info["flag"])))
			bag.take_all(p)
			wait = 0.3
			step = 16
		16:
			cave._victory(p)
			check("her hoard comes once per character (none the second time)", gm.opened.has(str(info["reward"])) and cave.get_node_or_null("Hoard") == null)
			gm.opened.clear()
			gm.chain_seed = 2
			step = 17
		17:
			# seed 2: a root cavern, its end room held by a nest of big bugs
			if world._built_seed != 2 or not world.chain_ready():
				return false
			isl = world.chain_islands[world.chain().start_next[0]]
			cave = isl.get_node("Dungeon0")
			info = cave.info
			check("seed 2: a root cavern under its giant tree", info["kind"] == "root_cavern" and cave.get_node_or_null("GiantTree") != null)
			check("...its chest waiting at the end", cave.get_node_or_null("Hoard") != null)
			var end: Dictionary = KD.room_of(info, "end")
			put(cave.to_global(KD.loc(info, end["c"], end["y"])))
			wait = 1.5
			step = 18
		18:
			var holders = cave.get_node("Enemies/EndNest")
			check("the end room held by big bugs (%d alive)" % holders.alive_count(), holders.alive_count() >= 2 and holders.spots.any(func(s): return s["big"]))
			for s in holders.spots:
				if s["bug"] != null and is_instance_valid(s["bug"]):
					s["bug"].health.take_damage(9999999.0)
			wait = 1.0
			step = 19
		19:
			check("the nest cleared: its flag", root.get_node("Dialogue").has_flag(str(info["flag"])))
			finish()
	return false


## The plans as data, island by island.
func _plans() -> void:
	var CH = load("res://scripts/world/chain.gd")
	var rp := Vector2(world.redtide.position.x, world.redtide.position.z)
	var temples := 0
	var all_cave := true
	var clear := true
	var paths := true
	var shapes := true
	var slots := true
	var most := 0
	for s in SEEDS:
		var c = CH.make(s, world.starter_center, rp - world.starter_center)
		var n: Dictionary = c.node(int(c.start_next[0]))
		load("res://scripts/island/island_theme.gd").meshes(str(n["theme"]))
		var g = load("res://scripts/island/gen_island.gd").new()
		g.prepare(n)
		var caves: Array = g.interiors.filter(func(e): return KD.POOL.has(e["kind"]))
		var kinds := {}
		for e in caves:
			kinds[e["kind"]] = true
		if caves.is_empty() or kinds.size() != caves.size():
			all_cave = false
		most = maxi(most, caves.size())
		for e in g.interiors:
			if e["kind"] == "temple":
				temples += 1
				if e["rooms"].size() != 4:
					shapes = false
			elif e["rooms"].size() < 2 or KD.room_of(e, "end").is_empty() or e["tunnels"].size() < e["rooms"].size():
				shapes = false
			var m: Vector2 = e["mouth"]
			if m.distance_to(g.sites["village"]) < 60.0 or m.distance_to(g.sites["dock"]) < 50.0 or g.hv(m) < 1.0:
				clear = false
				print("   seed %d %s: mouth %.0f m from the village, %.0f from the dock, h %.1f" % [s, e["kind"], m.distance_to(g.sites["village"]), m.distance_to(g.sites["dock"]), g.hv(m)])
			var o: Vector2 = e["mouth_dir"]
			if g.path_dist(m + o * (5.5 if e["kind"] == "temple" else 3.5)) > 4.0:
				paths = false
				print("   seed %d %s: no path at the mouth (%.1f m)" % [s, e["kind"], g.path_dist(m + o * 3.5)])
			var poi: Dictionary = KD.poi(e)
			if not (poi.has("at") and poi.has("radius") and poi.has("kind") and poi.has("mouth")):
				shapes = false
			var cham: Array = poi["chambers"]
			if cham.size() != e["rooms"].size() or not poi["boss_slot"] is Vector3 or cham.any(func(ch): return (ch["slots"]["floor"] as Array).is_empty()):
				slots = false
		print("   seed %d %s: %s (plan %d ms)" % [s, n["name"], g.interiors.map(func(e): return e["kind"]), int(g.build_ms["dungeon_plan"])])
		if s == SEEDS[0]:
			var again = load("res://scripts/island/gen_island.gd").new()
			again.prepare(n)
			var same: bool = again.interiors.size() == g.interiors.size()
			for i in range(mini(again.interiors.size(), g.interiors.size())):
				var a: Dictionary = again.interiors[i]
				var b: Dictionary = g.interiors[i]
				same = same and a["kind"] == b["kind"] and a["at"] == b["at"] and a["radius"] == b["radius"] and a["rooms"].size() == b["rooms"].size()
				if a.has("mesh"):
					same = same and a["mesh"]["tris"] == b["mesh"]["tris"]
			check("the same node plans the same interiors (co-op guests build them too)", same)
			again.free()
		g.free()
	check("every island plans a cave from the pool, no kind twice", all_cave)
	check("...some islands more than one (up to %d)" % most, most >= 2)
	check("chambers with free floor slots and a boss slot in the POI data", slots)
	check("the temple rolls on some islands, not all (%d of %d)" % [temples, SEEDS.size()], temples > 0 and temples < SEEDS.size())
	check("rooms, tunnels and an end room; POI data for a planner", shapes)
	check("mouths on land, clear of the village and the dock", clear)
	check("a path reaches each mouth", paths)
