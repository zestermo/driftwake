extends SceneTree
## The volcanic isle's foundations (scripts/island/themes/volcanic_theme.gd, volcanic_land.gd, volcanic_hazard.gd,
## VolcanicPlants): registered and rolled apart, never before the chain's fourth layer; every mesh slot filled. On a
## few islands made volcanic: one cone, its caldera's floor well under the rim, the boss's ground on that floor, the
## rim breached toward the town by a gully you can walk up, the town off the cone, the lookout on the rim; lava flows
## with hot stretches, crusted where a path crosses and near the town; nothing growing on the flows. Built: the lava
## mesh, the plume, and the hazard burning (and throwing out) a captain standing in hot lava but not on a crossing.
const TK := preload("res://tools/dev/test_kit.gd")
const SEEDS := [5, 11, 23]
var stage
var fails := 0


class ErrorLog extends Logger:
	var errors: Array = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors.append(rationale if rationale != "" else code)


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var IT = load("res://scripts/island/themes/island_themes.gd")
	var CH = load("res://scripts/world/chain.gd")
	var VL = load("res://scripts/island/themes/volcanic_land.gd")
	var v = IT.of("volcanic")
	check("the volcanic isle is registered, rolled apart from the fourth layer", v != null and v.apart and v.from_layer == 4)
	var total := 0
	var found := 0
	var early := 0
	var firsts: Array = []
	for s in range(1, 81):
		var c = CH.make(s, Vector2.ZERO, Vector2(0, -1))
		for n in c.nodes:
			total += 1
			if str(n["theme"]) == "volcanic":
				found += 1
				if int(n["layer"]) < 4:
					early += 1
				if firsts.size() < 4:
					firsts.append("%d:%d" % [s, int(n["id"])])
	print("VOLCANIC ISLANDS (chain seed:node): %s" % [firsts])
	check("volcanic isles turn up in chains (%d of %d islands)" % [found, total], found > total / 40 and found < total / 4)
	check("...never before the fourth layer (%d)" % early, early == 0)
	var m: Dictionary = load("res://scripts/island/island_theme.gd").meshes("volcanic")
	var bad: Array = []
	for k in ["tree", "beach_tree", "bush", "fern", "grass", "rock", "mangrove", "bamboo", "broadleaf", "shrub"]:
		if not m.has(k) or (m[k] as Array).is_empty() or not (m[k] as Array).all(func(e): return e is Mesh):
			bad.append(k)
	for k in ["giant", "fig", "kapok", "emergent", "roof"]:
		if not m.has(k) or (m[k] as Array).is_empty() or not (m[k] as Array).all(func(e): return e is Array and e[0] is Mesh and e[1] is Mesh and e[2] is Vector3):
			bad.append(k)
	check("every mesh slot the scatter reads is filled %s" % [bad], bad.is_empty())
	var built := false
	for sd in SEEDS:
		var c = CH.make(sd, Vector2.ZERO, Vector2(0, -1))
		var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
		n["theme"] = "volcanic"
		n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": v.beasts[v.bosses[0]]["names"][0], "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
		var isl = load("res://scripts/island/gen_island.gd").new()
		var errlog := ErrorLog.new()
		OS.add_logger(errlog)
		isl.prepare(n)
		OS.remove_logger(errlog)
		var tag := "[%d] " % sd
		check(tag + "prepared without an error %s" % [errlog.errors], errlog.errors.is_empty())
		var L: Dictionary = isl.land_plan
		var cone: Dictionary = L["cone"]
		var cc: Vector2 = cone["c"]
		print("%s r %.0f, %s, cone foot %.0f rim %.0f h %.0f; prepare %s" % [tag, isl.radius, isl.forest, cone["foot"], cone["rim"], cone["h"], isl.build_ms])
		var floor_y: float = isl.hv(cc)
		var rim_y := 0.0
		var bd: Vector2 = VL.breach_dir(isl, L)
		for k in range(12):
			var dir := Vector2.from_angle(TAU * k / 12.0)
			if absf(angle_difference(dir.angle(), bd.angle())) > 1.0:
				rim_y = maxf(rim_y, isl.hv(cc + dir * float(cone["rim"])))
		check(tag + "a caldera: its floor %.0f m, the rim %.0f m (%.0f over it)" % [floor_y, rim_y, rim_y - floor_y], rim_y - floor_y > 18.0 and floor_y > 30.0)
		check(tag + "the boss's ground is the caldera's floor", (isl.sites["boss"] as Vector2).distance_to(cc) < 1.0)
		var steep := 0.0
		var steep_at := 0.0
		var prev: float = isl.hv(cc + bd * 10.0)
		for k in range(1, 40):
			var q := cc + bd * (10.0 + k * 4.0)
			if q.distance_to(cc) > float(cone["foot"]) * 0.9:
				break
			var y: float = isl.hv(q)
			if absf(y - prev) / 4.0 > steep:
				steep = absf(y - prev) / 4.0
				steep_at = 10.0 + k * 4.0
			prev = y
		check(tag + "the breach's gully climbs at a walkable grade (steepest %.2f, %.0f m out)" % [steep, steep_at], steep < 0.85)
		check(tag + "the town off the cone (%.0f m from its middle)" % (isl.sites["village"] as Vector2).distance_to(cc),
			(isl.sites["village"] as Vector2).distance_to(cc) > float(cone["foot"]) * 0.75)
		var sm: Vector2 = isl.sites["summit"]
		check(tag + "the lookout on the rim", absf(sm.distance_to(cc) - float(cone["rim"])) < 6.0)
		var hot: Array = []
		for f in range((L["flows"] as Array).size()):
			var pts: PackedVector2Array = L["flows"][f]["pts"]
			for j in range(2, pts.size() - 3):
				if VL.hot_at(isl, f, pts[j]):
					hot.append(pts[j])
		check(tag + "lava flows with hot stretches (%d points)" % hot.size(), hot.size() >= 6)
		check(tag + "...none near the town", hot.all(func(q): return q.distance_to(isl.sites["village"]) > VL.COLD_SITE))
		var crossed := 0
		for q in hot:
			if isl.path_dist(q) < VL.COLD_PATH:
				crossed += 1
		check(tag + "...crusted where a path crosses (%d hot on a path)" % crossed, crossed == 0)
		var on_flow := 0
		for key in isl._buckets.keys():
			if key[1] == "rock":
				continue
			for xf in isl._buckets[key]:
				var near: Array = VL.flow_near(L, Vector2(xf.origin.x, xf.origin.z))
				if float(near[0]) < float(L["flows"][int(near[1])]["w"]) * 0.5:
					on_flow += 1
		check(tag + "nothing grows on the flows (%d)" % on_flow, on_flow < 6)
		if not built and not hot.is_empty():
			built = true
			isl.name = "VolcanicIsland"
			stage.add_child(isl)
			for s in isl._theme.steps(isl):
				s[1].call()
			var lava: Node3D = isl.get_node("VolcanicLava")
			check(tag + "built: the lava mesh, its hazard, the plume", lava.get_node_or_null("Lava") != null and lava.get_node_or_null("LavaHazard") != null
				and isl.get_node_or_null("VolcanicPlume") != null)
			var hz = lava.get_node("LavaHazard")
			var p = stage.player
			var hp0: float = p.health_component.current_health
			var q: Vector2 = hot[hot.size() / 2]
			p.global_position = isl.to_global(Vector3(q.x, isl.hv(q), q.y))
			hz._physics_process(0.25)
			var hp1: float = p.health_component.current_health
			check(tag + "standing in hot lava burns (%.0f -> %.0f) and throws you up and out (%.1f up)" % [hp0, hp1, p.velocity.y], hp1 < hp0 and p.velocity.y > 5.0)
			hz._grace = 0.0
			var v0: Vector2 = isl.sites["village"]
			p.global_position = isl.to_global(Vector3(v0.x, isl.hv(v0), v0.y))
			hz._physics_process(0.25)
			check(tag + "...but not in the town", p.health_component.current_health == hp1)
			isl.queue_free()
		else:
			isl.free()
	check("a volcanic island was built", built)
	return TK.done(fails)
