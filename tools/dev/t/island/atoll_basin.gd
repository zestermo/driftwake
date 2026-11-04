extends SceneTree
## The coral atoll's deep basin (1.30, atoll_land.basin_y + atoll_basin.gd): every atoll has one, a great sink in the
## lagoon beside its middle, its floor 25-35 m down and 45 m+ across its rim, clear of the causeway, the boss's flat,
## the village and the lagoon islets; towering coral pillars stand on its floor (solid), with tables, fans, arches,
## overhangs, a swim-through cave, reef over its walls; and its floor is in a diver's reach: breathing vents on the
## ledge and the floor each a breath's dive from the last.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var v = load("res://scripts/island/themes/island_themes.gd").of("atoll")
	load("res://scripts/island/island_theme.gd").meshes("atoll")
	var D = load("res://scripts/island/themes/atoll_data.gd")
	var SW = load("res://scripts/player_states/swim_state.gd")
	for cs in [11, 5, 23]:
		var c = load("res://scripts/world/chain.gd").make(cs, Vector2.ZERO, Vector2(0, -1))
		var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
		n["theme"] = "atoll"
		n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": "x", "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
		var isl = load("res://scripts/island/gen_island.gd").new()
		isl.prepare(n)
		stage.add_child(isl)
		var L = isl._theme.LAND_FEATURES
		var lp: Dictionary = isl.land_plan
		var hole: Array = lp["hole"]
		var hc: Vector2 = hole[0]
		var r: float = hole[1]
		var deep := 0.0
		var floor_sum := 0.0
		var k := 0
		for i in range(40):
			var q := hc + Vector2.from_angle(TAU * i / 40.0) * r * 0.3 * float(i % 4) / 3.0
			floor_sum += isl.hv(q)
			deep = minf(deep, isl.hv(q))
			k += 1
		var mean := floor_sum / k
		check("chain %d: a deep basin (floor %.1f m, deepest %.1f, rim %.0f m)" % [cs, mean, deep, r], mean < -24.0 and deep > -38.0 and r >= 45.0)
		var rim: float = isl.hv(hc + Vector2.from_angle(0.4) * (float(L.basin_r(lp, 0.4)) + 2.0))
		check("...a reef crest round its lip (%.1f m)" % rim, rim > -2.6 and rim < -0.6)
		var cw: Array = lp["causeway"]
		var ab: Vector2 = (cw[1] as Vector2) - (cw[0] as Vector2)
		var t := clampf((hc - (cw[0] as Vector2)).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var off := hc.distance_to((cw[0] as Vector2) + ab * t)
		var motu_ok: bool = (lp["motu"] as Array).all(func(mo): return hc.distance_to(mo[0]) > float(mo[1]) + r)
		check("...clear of the causeway (%.0f m off), the boss's flat, the village and the islets" % off,
			off > r + D.CAUSEWAY_HW and hc.distance_to(isl.sites["boss"]) > r + 30.0 and hc.distance_to(isl.sites["village"]) > r + D.VILLAGE_R and motu_ok)
		var inner: float = L.ring_r(isl, hc.angle())[1]
		check("...inside the lagoon (%.0f + %.0f < %.0f)" % [hc.length(), r, inner], hc.length() + r < inner)
		if cs != 11:
			isl.queue_free()
			continue
		for s in isl._theme.steps(isl):
			if str(s[0]) in ["atoll reef", "atoll basin"]:
				s[1].call()
		var bn: Node3D = isl.get_node("AtollBasin")
		var body: StaticBody3D = bn.get_node("Rock")
		var pillars: Array = bn.get_meta("pillars")
		check("towering coral pillars on its floor (%d), solid" % pillars.size(), pillars.size() >= D.PILLARS[0] and body.get_child_count() >= pillars.size() + 6)
		var drawn := true
		for m in ["Pillars", "Reefwork", "Vents"]:
			var gi := bn.get_node_or_null(m) as GeometryInstance3D
			drawn = drawn and gi != null and gi.visibility_range_end > 100.0 and gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		check("...its rock drawn (pillars, reefwork, vents), ranged, unshadowed", drawn)
		check("...a swim-through cave or two (%d)" % (bn.get_meta("caves") as Array).size(), (bn.get_meta("caves") as Array).size() >= 1)
		var reef: Node3D = isl.get_node("AtollReef")
		var corals := 0
		for g in reef.get_children():
			if g is MultiMeshInstance3D:
				var gp: Vector3 = (g as Node3D).position
				if Vector2(gp.x, gp.z).distance_to(hc) < r + 40.0:
					corals += (g as MultiMeshInstance3D).multimesh.instance_count
		check("...reef over its walls (%d corals round it)" % corals, corals > 3000)
		# the reach: from the surface to a ledge vent on a breath, the ledge to a floor vent on the next, and the floor up
		var vents: Array = bn.get_meta("vents")
		var depths: Array = vents.map(func(q): return -float(isl.hv(q)))
		depths.sort()
		var ledge: float = depths[0]
		var floor_v: float = depths[depths.size() - 1]
		var down: float = ledge / SW.DESCEND + 1.0
		var on: float = (floor_v - ledge) / SW.DESCEND + 1.0
		var up: float = (-mean) / SW.ASCEND + 1.0
		check("breathing vents on the ledge and the floor (%s m)" % str(depths.map(func(x): return snappedf(x, 0.1))), vents.size() >= D.VENTS[0] and ledge < 16.0 and floor_v > 22.0)
		check("...each a breath's dive (%.1f s, %.1f s, up %.1f s of %.0f)" % [down, on, up, SW.BREATH], down < SW.BREATH * 0.8 and on < SW.BREATH * 0.8 and up < SW.BREATH * 0.8)
		isl.queue_free()
	return TK.done(fails)
