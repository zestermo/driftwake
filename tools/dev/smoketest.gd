extends SceneTree
## The island smoke test (land.ps1 runs it on every landing): each fixed chain seed's first
## islands built the way the world builds them (worker thread, then a step a frame), then a
## captain at each one's village and beast for a moment. Fails on a script error while they
## build and run (SCRIPT ERROR in the log), a non-finite transform, a missing service (inn, store, cookhouse, job board,
## elder) or an island that doesn't finish. Prints what each seed rolled.
## `-- list <from> <to>`: just what each seed's first islands roll (prepare only), to pick seeds.
const TK = preload("res://tools/dev/test_kit.gd")
## Seven islands between them (three forks and a lone one): every village layout and harbour kind,
## every beast, the temple on six, set pieces cenote, sea arch, old fort, hot springs, volcano vent (see `list`).
const SEEDS := [1, 12, 36, 9]
const BUILD_LIMIT := 60.0

class ErrorLog extends Logger:
	var errors: Array = []
	var _m := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			_m.lock()
			errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file, line])
			_m.unlock()

	func take() -> Array:
		_m.lock()
		var out := errors.duplicate()
		errors.clear()
		_m.unlock()
		return out

var t := 0.0
var step := 0
var until := 0
var fails := 0
var seeds: Array = []
var si := 0
var started := 0.0
var p
var w
var visits: Array = []
var home := Vector3.ZERO
var errlog := ErrorLog.new()
var listing: Array = []


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() >= 3 and a[0] == "list":
		listing = range(int(a[1]), int(a[2]) + 1)
	else:
		OS.add_logger(errlog)
		seeds = TK.seeds_of(SEEDS)
		TK.use_seed(self, int(seeds[0]))
	change_scene_to_file("res://scenes/world/world.tscn")


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


func finish() -> void:
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()


func _process(d: float) -> bool:
	t += d
	if TK.ticking(until):
		return false
	match step:
		0:
			w = root.get_node_or_null("World/Islands")
			if t < 1.5 or w == null:
				return false
			if not listing.is_empty():
				_list()
				quit()
				return true
			p = get_first_node_in_group("player")
			p.health_component.max_health = 999999.0
			p.health_component.current_health = 999999.0
			home = p.global_position
			started = t
			step = 1
		1:
			if not w.chain_ready():
				if t - started > BUILD_LIMIT:
					check("seed %d: its islands finish building (still going after %.0f s)" % [seeds[si], BUILD_LIMIT], false)
					finish()
					return true
				return false
			w.set_process(false)
			_errors("building seed %d's islands" % seeds[si])
			print("   seed %d built in %.1f s" % [seeds[si], t - started])
			visits.clear()
			var c = w.chain()
			for id in c.start_next:
				var isl = w.chain_islands[id]
				_report(isl)
				visits.append([isl, _village_spot(isl), "village"])
				var b: Vector2 = isl.sites["boss"]
				visits.append([isl, b + (isl.sites["village"] - b).normalized() * 30.0, "beast"])
			step = 2
		2:
			if not visits.is_empty():
				var v: Array = visits.pop_front()
				var isl = v[0]
				var q: Vector2 = v[1]
				_put(isl.to_global(Vector3(q.x, isl.walk_height(q.x, q.y) + 1.0, q.y)))
				until = TK.wait_ticks(60)
				return false
			for id in w.chain().start_next:
				var isl = w.chain_islands[id]
				var bad := _bad_xforms(isl)
				check("[%s] every transform finite after a while %s" % [isl.island_name, bad], bad.is_empty())
			var bad_p := _bad_xforms(p)
			check("seed %d: the captain's transforms finite %s" % [seeds[si], bad_p], bad_p.is_empty())
			_errors("seed %d's islands running" % seeds[si])
			si += 1
			if si >= seeds.size():
				print("   %d seeds in %.0f s" % [seeds.size(), t])
				finish()
				return true
			# (home first: standing where the next chain puts an island would be arriving there)
			_put(home)
			TK.use_seed(self, int(seeds[si]))
			w.set_process(true)
			w.sync_chain_islands()
			started = t
			step = 1
	return false


func _put(at: Vector3) -> void:
	p.state_machine.force_state("Idle", {})
	p.velocity = Vector3.ZERO
	p.global_position = at
	p.reset_physics_interpolation()


func _errors(doing: String) -> void:
	var e := errlog.take()
	# (not "script error" in the name: the runner stops a suite on any line saying that)
	check("no runtime errors %s %s" % [doing, e.slice(0, 3)], e.is_empty())


func _rolls(isl, n: Dictionary) -> String:
	return "%s (%s, Lv %d): village %s, harbour %s, interiors %s, places %s, beast %s, minis %s, roamer %s" % [n["name"], n["theme"], int(n["level"]),
		isl.village_plan["layout"], isl.harbour.kind, isl.interiors.map(func(e): return e["kind"]),
		isl.places.map(func(pl): return "%s:%s" % [pl.get("role", "?"), pl["kind"]]), n["beast"], n["minis"], n["roamer"]]


func _report(isl) -> void:
	var n: Dictionary = isl.node
	print("   seed %d: %s" % [seeds[si], _rolls(isl, n)])
	var tag: String = isl.island_name
	var vil = isl.get_node("Site_village/Village")
	var kinds: Array = vil.buildings.map(func(x): return x["kind"])
	var npcs: Array = get_nodes_in_group("npcs").filter(func(x): return x.get_parent() == isl)
	var missing: Array = []
	for k in ["inn", "trade", "cook", "elder"]:
		if not kinds.has(k):
			missing.append(k + " building")
	if isl.find_child("Rest", true, false) == null:
		missing.append("the inn's rest")
	if isl.get_node("Site_village").find_children("NoticeBoard*", "", true, false).is_empty():
		missing.append("job board")
	for who in [["elder", "dialogue_id", "elder"], ["trader", "shop_id", "trader"], ["cook", "shop_id", "cook"]]:
		if not npcs.any(func(x): return x.get(who[1]) == isl.save_key(who[2])):
			missing.append(who[0])
	check("[%s] its services: inn, store, cookhouse, job board, elder (%s; missing %s)" % [tag, vil.layout, missing], missing.is_empty())
	var arena = isl.get_node("Site_boss/Arena")
	check("[%s] its beast in its arena (%s)" % [tag, arena.kind], is_instance_valid(arena.boss))
	var bad := _bad_xforms(isl)
	check("[%s] every transform finite once built %s" % [tag, bad], bad.is_empty())


## (a road into the village, past the heart: that may be a deck or a market)
func _village_spot(isl) -> Vector2:
	var road: PackedVector2Array = isl.get_node("Site_village/Village").streets[0]
	for q in road:
		if q.distance_to(isl.sites["village"]) > 22.0:
			return q
	return road[road.size() - 1]


func _bad_xforms(n: Node3D) -> Array:
	var bad: Array = []
	for c in [n] + n.find_children("*", "Node3D", true, false):
		if not (c as Node3D).global_transform.is_finite():
			bad.append(str(n.get_path_to(c)))
	return bad.slice(0, 5)


func _list() -> void:
	var gm = root.get_node("GameManager")
	for s in listing:
		gm.chain_seed = s
		var c = w.chain()
		for id in c.start_next:
			var n: Dictionary = c.node(id)
			load("res://scripts/island/island_theme.gd").meshes(str(n["theme"]))
			var g = load("res://scripts/island/gen_island.gd").new()
			g.prepare(n)
			print("seed %d: %s" % [s, _rolls(g, n)])
			g.free()
