extends SceneTree
## How chain islands' build costs scale with their size: each theme's islands built at multiples of
## its own radius range (ThemeDef.radius scaled for the run only), on fixed chain seeds (each seed's
## first regular island of that theme), the way the world builds them (prepare on a worker, then the
## finish steps, timed one by one). Per build: prepare ms, main-thread total and worst step, nodes,
## MultiMesh instances, geometry estimate, static memory, terrain grid, what failed to place, errors.
## Then the chain's spacing with the bigger radii (Chain._make_room) over many chain seeds.
## Headless. Args: [themes | -] [multipliers | -] [chain seeds | -] [out file]
## (defaults: jungle,desert,snow  1.0,1.5,2.0  777,31337,4242  res://tools/dev/out/sizesweep.txt)
const TK = preload("res://tools/dev/test_kit.gd")
const THEMES = preload("res://scripts/island/themes/island_themes.gd")
## The sloop's best speed (Ship.MAX_SPEED 11 x 1.15 upgraded sails x 1.2 FAIR_BOOST) and its plain one (m/s).
const SAIL_FAST := 15.18
const SAIL_PLAIN := 11.0
const SPACING_SEEDS := 300
const SITES := ["dock", "village", "boss", "camp", "lair", "ruins", "summit"]

class ErrorLog extends Logger:
	var errors: Array = []
	var _m := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_m.lock()
		errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line])
		_m.unlock()

	func take() -> Array:
		_m.lock()
		var out := errors.duplicate()
		errors.clear()
		_m.unlock()
		return out

var themes: Array = ["jungle", "desert", "snow"]
var mults: Array = [1.0, 1.5, 2.0]
var seeds: Array = [777, 31337, 4242]
var out_path := "res://tools/dev/out/sizesweep.txt"
var errlog := ErrorLog.new()
var w
var t := 0.0
var step := 0
var wait := 0
var jobs: Array = []
var rows: Array = []
var spacing: Array = []
var _freed: Dictionary = {}


func _initialize():
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "-":
		themes = Array(a[0].split(","))
	if a.size() > 1 and a[1] != "-":
		mults = Array(a[1].split(",")).map(func(s): return float(s))
	if a.size() > 2 and a[2] != "-":
		seeds = Array(a[2].split(",")).map(func(s): return int(s))
	if a.size() > 3:
		out_path = a[3]
	OS.add_logger(errlog)
	TK.use_seed(self, int(seeds[0]))
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if wait > 0:
		wait -= 1
		return false
	match step:
		0:
			w = root.get_node_or_null("World/Islands")
			if w == null or t < 1.5 or not w.chain_ready():
				return false
			w.set_process(false)
			for n in root.find_children("*", "CharacterCreator", true, false):
				n._finish(true)
			errlog.take()
			for th in themes:
				for s in seeds:
					for m in mults:
						jobs.append([th, int(s), float(m)])
			print("sizesweep: %d builds (%s x %s x seeds %s)" % [jobs.size(), themes, mults, seeds])
			step = 1
			wait = 3
		1:
			if not _freed.is_empty():
				var r: Dictionary = _freed
				r["mem_left_mb"] = (_mem() - float(r["mem0"])) / 1048576.0
				_freed = {}
			if jobs.is_empty():
				_spacing()
				_report()
				quit()
				return true
			_freed = _build(jobs.pop_front())
			wait = 6
	return false


func _mem() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC)


## `s`'s first regular island of `theme` (else any of that theme), or {}.
func _pick(theme: String, s: int) -> Dictionary:
	TK.use_seed(self, s)
	var c = w.chain()
	var any := {}
	for n in c.nodes:
		if str(n["theme"]) != theme:
			continue
		if str(n["role"]) == "regular":
			return n
		if any.is_empty():
			any = n
	return any


func _build(job: Array) -> Dictionary:
	var theme: String = job[0]
	var s: int = job[1]
	var m: float = job[2]
	var n := _pick(theme, s)
	var r := {"theme": theme, "seed": s, "x": m}
	if n.is_empty():
		r["skip"] = "no %s island in chain %d" % [theme, s]
		rows.append(r)
		print("   skipped: %s" % r["skip"])
		return {}
	load("res://scripts/island/island_theme.gd").meshes(theme)
	var def = THEMES.of(theme)
	var keep: Array = def.radius.duplicate()
	def.radius = [float(keep[0]) * m, float(keep[1]) * m]
	var g = load("res://scripts/island/gen_island.gd").new()
	g.name = "SizeSweepIsle"
	g.position = Vector3(n["pos"].x, 0.0, n["pos"].y)
	var mem0 := _mem()
	var t0 := Time.get_ticks_usec()
	var task := WorkerThreadPool.add_task(g.prepare.bind(n))
	WorkerThreadPool.wait_for_task_completion(task)
	var prep_ms := (Time.get_ticks_usec() - t0) / 1000.0
	def.radius = keep
	var mem_prep := _mem()
	w.add_child(g)
	var steps: Array = g.finish_steps()
	var main := 0.0
	var worst := 0.0
	var worst_name := ""
	var by_name := {}
	for st in steps:
		var ts := Time.get_ticks_usec()
		g.run_step(st)
		var ms := (Time.get_ticks_usec() - ts) / 1000.0
		main += ms
		by_name[st[0]] = maxf(float(by_name.get(st[0], 0.0)), ms)
		if ms > worst:
			worst = ms
			worst_name = st[0]
	var mem1 := _mem()
	var land := 0
	for h in g.heights:
		if h > 0.3:
			land += 1
	var cost := _cost(g)
	r.merge({"name": n["name"], "id": int(n["id"]), "r": g.radius, "res": g.res, "land_ha": land * pow(float(g.get_script().CELL), 2.0) / 10000.0,
		"prep_ms": prep_ms, "main_ms": main, "steps": steps.size(), "worst_ms": worst, "worst_step": worst_name,
		"nodes": g.find_children("*", "", true, false).size(), "mm": cost["mm"], "geo_mb": cost["geo"] / 1048576.0,
		"shapes": cost["shapes"], "mem0": mem0, "mem_prep_mb": (mem_prep - mem0) / 1048576.0, "mem_mb": (mem1 - mem0) / 1048576.0,
		"places": g.places.size(), "interiors": g.interiors.size(), "missing": _missing(g), "errors": errlog.take(),
		"worst_by_name": by_name, "build_ms": g.build_ms.duplicate()})
	rows.append(r)
	print("   %s x%.1f seed %d %s: r %.0f, res %d, prepare %d ms, main %d ms over %d steps (worst %d %s), nodes %d, mm %d, mem +%.1f MB, errors %d %s" % [
		theme, m, s, n["name"], g.radius, g.res, prep_ms, main, steps.size(), worst, worst_name, r["nodes"], r["mm"], r["mem_mb"],
		r["errors"].size(), r["missing"]])
	g.queue_free()
	return r


## MultiMesh instances, a geometry memory estimate (each mesh once: 32 bytes a vertex, 2-4 an index;
## 48 a MultiMesh instance; the dummy renderer keeps no GPU buffers, so static memory leaves these out)
## and collision shapes.
func _cost(g: Node) -> Dictionary:
	var c := {"mm": 0, "geo": 0, "shapes": 0}
	var seen := {}
	for gi in g.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh:
			var mm: MultiMesh = (gi as MultiMeshInstance3D).multimesh
			c["mm"] += mm.instance_count
			c["geo"] += mm.instance_count * 48
			mesh = mm.mesh
		if mesh == null or not mesh is ArrayMesh or seen.has(mesh.get_instance_id()):
			continue
		seen[mesh.get_instance_id()] = true
		for si in range(mesh.get_surface_count()):
			var v := (mesh as ArrayMesh).surface_get_array_len(si)
			c["geo"] += v * 32 + (mesh as ArrayMesh).surface_get_array_index_len(si) * (2 if v < 65536 else 4)
	c["shapes"] = g.find_children("*", "CollisionShape3D", true, false).size()
	return c


## What a built island lacks: sites, the village's services, its beast.
func _missing(g: Node) -> Array:
	var out: Array = []
	for k in SITES:
		if not g.sites.has(k):
			out.append("site " + k)
	var vil = g.get_node_or_null("Site_village/Village")
	if vil == null:
		out.append("village")
	else:
		var kinds: Array = vil.buildings.map(func(x): return x["kind"])
		for k in ["inn", "trade", "cook", "elder"]:
			if not kinds.has(k):
				out.append(k)
	var arena = g.get_node_or_null("Site_boss/Arena")
	if arena == null or not is_instance_valid(arena.boss):
		out.append("beast")
	return out


# ==========================================================================
# The chain's spacing with bigger radii
# ==========================================================================
func _spacing() -> void:
	var origin: Vector2 = w.starter_center
	var heading: Vector2 = Vector2(w.redtide.position.x, w.redtide.position.z) - origin
	var red := Vector2(w.redtide.position.x, w.redtide.position.z)
	var home_r: float = float(load("res://scripts/island/starter_island.gd").HALF)
	var chain_script = load("res://scripts/world/chain.gd")
	var keep := {}
	for th in THEMES.all():
		keep[th.name] = th.radius.duplicate()
	for scope in ["desert+snow", "all"]:
		for m in mults:
			for th in THEMES.all():
				var k: Array = keep[th.name]
				var grow: bool = scope == "all" or th.name in ["desert", "snow"]
				th.radius = [float(k[0]) * (m if grow else 1.0), float(k[1]) * (m if grow else 1.0)]
			var e := {"scope": scope, "x": m, "legs": 0, "leg_min": INF, "leg_sum": 0.0, "first_min": INF, "tog_min": INF, "tog_over": 0,
				"tog_at": "", "chart_over": 0, "home_min": INF, "home_over": 0, "red_min": INF, "red_over": 0, "far_max": 0.0, "bad_seeds": []}
			errlog.take()
			for s in range(1, SPACING_SEEDS + 1):
				var c = chain_script.make(s, origin, heading)
				if not errlog.take().is_empty():
					e["bad_seeds"].append(s)
				var nodes: Array = c.nodes
				var rr := func(n: Dictionary) -> float: return float(THEMES.of(n["theme"]).radius[1])
				var gap := func(a: Dictionary, b: Dictionary) -> float: return (a["pos"] as Vector2).distance_to(b["pos"]) - rr.call(a) - rr.call(b)
				# (what stands in the world at once: the island the crew is at and the ones its log pose points to)
				var groups: Array = [c.start_next]
				for i in range(nodes.size()):
					var a: Dictionary = nodes[i]
					var pa: Vector2 = a["pos"]
					e["far_max"] = maxf(e["far_max"], pa.distance_to(origin))
					var hg: float = pa.distance_to(origin) - rr.call(a) - home_r
					e["home_min"] = minf(e["home_min"], hg)
					e["home_over"] += 1 if hg < 0.0 else 0
					var rg: float = pa.distance_to(red) - rr.call(a) - 40.0
					e["red_min"] = minf(e["red_min"], rg)
					e["red_over"] += 1 if rg < 0.0 else 0
					groups.append([i] + a["next"])
					for nid in a["next"]:
						var g: float = gap.call(a, nodes[nid])
						e["legs"] += 1
						e["leg_sum"] += g
						e["leg_min"] = minf(e["leg_min"], g)
					for j in range(i + 1, nodes.size()):
						e["chart_over"] += 1 if gap.call(a, nodes[j]) < 0.0 else 0
				for grp in groups:
					for x in range(grp.size()):
						for y in range(x + 1, grp.size()):
							var g: float = gap.call(nodes[grp[x]], nodes[grp[y]])
							if g < e["tog_min"]:
								e["tog_min"] = g
								e["tog_at"] = "chain %d, layers %d/%d" % [s, int(nodes[grp[x]]["layer"]), int(nodes[grp[y]]["layer"])]
							e["tog_over"] += 1 if g < 0.0 else 0
				for id in c.start_next:
					e["first_min"] = minf(e["first_min"], (nodes[id]["pos"] as Vector2).distance_to(origin) - rr.call(nodes[id]) - home_r)
			spacing.append(e)
	for th in THEMES.all():
		th.radius = keep[th.name]


# ==========================================================================
# The report
# ==========================================================================
func _report() -> void:
	var L: Array = []
	L.append("# Island size sweep, %s" % Time.get_date_string_from_system())
	L.append("")
	L.append("Each theme's radius range x mult; per chain seed its first regular island of that theme. prep = GenIsland.prepare on a worker;")
	L.append("main = the finish steps on the main thread (the world runs one a frame), worst = the longest one; res = terrain cells a side")
	L.append("(3 m); mem = static memory added by the build (CPU side: the dummy renderer keeps no meshes), left = still held a few frames")
	L.append("after it was freed; geo = estimated mesh + MultiMesh buffers (GPU side).")
	L.append("")
	L.append("| theme | x | seed | island | r m | res | land ha | prep ms | main ms | steps | worst ms | worst step | nodes | mm inst | shapes | geo MB | mem MB | left MB | places | caves | missing | errors |")
	L.append("|---|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|")
	for r in rows:
		if r.has("skip"):
			L.append("| %s | %.1f | %d | %s |" % [r["theme"], r["x"], r["seed"], r["skip"]])
			continue
		L.append("| %s | %.1f | %d | %s | %d | %d | %.1f | %d | %d | %d | %d | %s | %d | %d | %d | %.1f | %.1f | %.1f | %d | %d | %s | %d |" % [
			r["theme"], r["x"], r["seed"], r["name"], int(r["r"]), r["res"], r["land_ha"], int(r["prep_ms"]), int(r["main_ms"]), r["steps"],
			int(r["worst_ms"]), r["worst_step"], r["nodes"], r["mm"], r["shapes"], r["geo_mb"], r["mem_mb"], float(r.get("mem_left_mb", 0.0)),
			r["places"], r["interiors"], ", ".join(r["missing"]) if not r["missing"].is_empty() else "-", r["errors"].size()])
	L.append("")
	L.append("## Means by theme and size (and the growth over x1.0 as a power of the radius: 2 = with area)")
	L.append("")
	L.append("| theme | x | r m | land ha | prep ms | main ms | worst ms | nodes | mm inst | geo MB | mem MB | exp prep | exp main | exp worst | exp mem | exp geo |")
	L.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for th in themes:
		var base := {}
		for m in mults:
			var g := rows.filter(func(r): return r["theme"] == th and is_equal_approx(float(r["x"]), float(m)) and not r.has("skip"))
			if g.is_empty():
				continue
			var mean := {}
			for k in ["r", "land_ha", "prep_ms", "main_ms", "worst_ms", "nodes", "mm", "geo_mb", "mem_mb"]:
				mean[k] = g.reduce(func(acc, r): return acc + float(r[k]), 0.0) / g.size()
			if base.is_empty():
				base = mean
			var ex := func(k: String) -> String:
				if float(mean["r"]) <= float(base["r"]) * 1.01 or float(base[k]) <= 0.0:
					return "-"
				return "%.2f" % (log(float(mean[k]) / float(base[k])) / log(float(mean["r"]) / float(base["r"])))
			L.append("| %s | %.1f | %d | %.0f | %d | %d | %d | %d | %d | %.1f | %.1f | %s | %s | %s | %s | %s |" % [th, m, int(mean["r"]), mean["land_ha"],
				int(mean["prep_ms"]), int(mean["main_ms"]), int(mean["worst_ms"]), int(mean["nodes"]), int(mean["mm"]), mean["geo_mb"], mean["mem_mb"],
				ex.call("prep_ms"), ex.call("main_ms"), ex.call("worst_ms"), ex.call("mem_mb"), ex.call("geo_mb")])
	L.append("")
	L.append("## Slowest steps and prepare stages (ms, per build)")
	L.append("")
	for r in rows:
		if r.has("skip"):
			continue
		var wb: Dictionary = r["worst_by_name"]
		var names: Array = wb.keys()
		names.sort_custom(func(x, y): return float(wb[x]) > float(wb[y]))
		var prep := {}
		for k in ["land", "places", "arrays", "shore", "harbour plan", "trees", "undergrowth", "thicket", "bodies", "dungeon_plan"]:
			if r["build_ms"].has(k):
				prep[k] = r["build_ms"][k]
		L.append("- %s x%.1f seed %d: steps %s; prepare %s" % [r["theme"], r["x"], r["seed"],
			", ".join(names.slice(0, 5).map(func(k): return "%s %d" % [k, int(wb[k])])), JSON.stringify(prep)])
	L.append("")
	L.append("## Errors while building")
	L.append("")
	var any := false
	for r in rows:
		if r.has("skip") or r["errors"].is_empty():
			continue
		any = true
		L.append("- %s x%.1f seed %d (%d): %s" % [r["theme"], r["x"], r["seed"], r["errors"].size(), " | ".join(r["errors"].slice(0, 4))])
	if not any:
		L.append("- none")
	L.append("")
	L.append("## Chain spacing (%d chain seeds, Chain._make_room with the scaled radius[1]; gaps coast to coast at full radius)" % SPACING_SEEDS)
	L.append("")
	L.append("Sail = the shortest leg at the sloop's best speed (%.1f m/s; plain %.0f m/s)." % [SAIL_FAST, SAIL_PLAIN])
	L.append("")
	L.append("Loaded together = the island the crew is at and the ones its log pose points to (or Brinehollow's first layer); chart overlaps =")
	L.append("any two islands of a chain on the same water (never in the world together); home = Brinehollow (StarterIsland.HALF), Redtide 40 m.")
	L.append("")
	L.append("| grown | x | legs | leg min m | leg mean m | sail min s | first leg min m | together min m | together < 0 | home min m | home < 0 | Redtide min m | Redtide < 0 | chart overlaps | furthest m |")
	L.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
	for e in spacing:
		L.append("| %s | %.1f | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d |" % [e["scope"], e["x"], e["legs"], int(e["leg_min"]),
			int(e["leg_sum"] / maxf(e["legs"], 1.0)), int(e["leg_min"] / SAIL_FAST), int(e["first_min"]), int(e["tog_min"]), e["tog_over"],
			int(e["home_min"]), e["home_over"], int(e["red_min"]), e["red_over"], e["chart_over"], int(e["far_max"])])
	L.append("")
	for e in spacing:
		L.append("- %s x%.1f: closest loaded pair at %s; chain seeds with errors in Chain.make: %s" % [e["scope"], e["x"], e["tog_at"],
			str(e["bad_seeds"].slice(0, 12)) + (" (%d)" % e["bad_seeds"].size() if not e["bad_seeds"].is_empty() else "")])
	var path := ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(L) + "\n")
	f.close()
	print("")
	for l in L:
		print(l)
	print("")
	print("written: %s" % path)
