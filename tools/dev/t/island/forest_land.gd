extends SceneTree
## The forest's foundations (scripts/island/themes/forest_theme.gd, forest_land.gd, ForestPlants): registered after
## the desert; every mesh slot the scatter reads filled (big trees as [body, detail, lean]) and the same from the
## same seed; the canopy about a forest's height; its style (river cobbles, log walls and shingle roofs, its lamp
## with a Flame, its waymark, the autumn ground). On a few chain islands made forest: its size, its woodland from
## the list, rivers whose surface only falls toward the sea and reaches it, their beds cut under the water, falls
## with a pool at their foot, the town beside a river, autumn trees thick and nothing growing in the water; built,
## its rivers' water, the falls' pool to swim in and bridges where the paths cross. Prints the chain seeds that
## open on a forest (for genshot / islandshot).
const TK := preload("res://tools/dev/test_kit.gd")
const SEEDS := [5, 7, 13]
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


func _seeded() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return rng


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	var IT = load("res://scripts/island/themes/island_themes.gd")
	var CH = load("res://scripts/world/chain.gd")
	var KS = load("res://scripts/island/kit/kit_style.gd")
	var FL = load("res://scripts/island/themes/forest_land.gd")
	var FP = load("res://scripts/props/forest_plants.gd")
	var f = IT.of("forest")
	var names: Array = IT.all().map(func(t): return t.name)
	check("the forest is registered after the desert (%s)" % [names], names.slice(0, 4) == ["jungle", "snow", "desert", "forest"])
	var firsts: Array = []
	for s in range(1, 400):
		var cs = CH.make(s, Vector2.ZERO, Vector2(0, -1))
		if cs.node(int(cs.start_next[0]))["theme"] == "forest":
			firsts.append(s)
		if firsts.size() >= 6:
			break
	print("FOREST FIRST ISLANDS: chain seeds %s" % [firsts])
	check("some chains open on a forest", not firsts.is_empty())
	var m: Dictionary = load("res://scripts/island/island_theme.gd").meshes("forest")
	var bad: Array = []
	for k in ["tree", "beach_tree", "bush", "fern", "grass", "rock", "mangrove", "bamboo", "broadleaf", "shrub"]:
		if not m.has(k) or (m[k] as Array).is_empty() or not (m[k] as Array).all(func(e): return e is Mesh):
			bad.append(k)
	for k in ["giant", "fig", "kapok", "emergent", "roof"]:
		if not m.has(k) or (m[k] as Array).is_empty() or not (m[k] as Array).all(func(e): return e is Array and e[0] is Mesh and e[1] is Mesh and e[2] is Vector3):
			bad.append(k)
	check("every mesh slot the scatter reads is filled, big trees as [body, detail, lean] %s" % [bad], bad.is_empty())
	var a: Array = FP.maple(861)
	check("a maple is the same from the same seed, another from another", (a[0] as Mesh).get_aabb() == (FP.maple(861)[0] as Mesh).get_aabb()
		and (a[0] as Mesh).get_aabb() != (FP.maple(862)[0] as Mesh).get_aabb())
	var canopy: float = load("res://scripts/island/kit/kit_landmarks.gd").canopy("forest")
	check("the woods stand about a canopy's height (%.1f m)" % canopy, canopy > 15.0 and canopy < 30.0)
	var st: Dictionary = KS.of("forest")
	var lamp: Node3D = KS.prop(st, "lamp", _seeded())
	var mark: Node3D = KS.prop(st, "marker", _seeded())
	check("the forest style: river cobbles, log walls under shingles, steep roofs, its lamp with a Flame and its waymark, the autumn ground, its woodland bed, wetter than the jungle and misty",
		st["paving"] == "river_cobbles" and (st["house"]["walls"] as Array).has("logs") and (st["house"]["roof_tex"] as Array).has("shingles")
		and float(st["house"]["pitch"][0]) > 0.9 and lamp.get_node_or_null("Flame") != null and mark != null and st["ground"]["grass"] == "forest_litter"
		and st["ground"]["cliff"] == "forest_rock" and st["ambience"] == "forest" and load("res://scripts/world/ambience.gd").LOOPS.has("forest")
		and float(st["weather"][2]) > float(KS.of("jungle")["weather"][2]) and float(st["haze"]) > 0.0)
	lamp.free()
	mark.free()
	var variants := {}
	var built := false
	for sd in SEEDS:
		var c = CH.make(sd, Vector2.ZERO, Vector2(0, -1))
		var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
		n["theme"] = "forest"
		n.merge({"beast": f.bosses[0], "beast_look": 0, "beast_name": f.beasts[f.bosses[0]]["names"][0], "minis": [f.minis[0]], "roamer": f.roamers[0]}, true)
		var isl = load("res://scripts/island/gen_island.gd").new()
		var errlog := ErrorLog.new()
		OS.add_logger(errlog)
		isl.prepare(n)
		OS.remove_logger(errlog)
		var tag := "[%d] " % sd
		check(tag + "built without an error %s" % [errlog.errors], errlog.errors.is_empty())
		var L: Dictionary = isl.land_plan
		variants[isl.forest] = true
		print("%s r %.0f, %s: %d rivers, falls %s; built %s" % [tag, isl.radius, isl.forest, L["rivers"].size(), L["rivers"].map(func(rv): return rv["falls"] > 0), isl.build_ms])
		check(tag + "a forest's size (r %.0f in 340-460)" % isl.radius, isl.radius >= 340.0 and isl.radius <= 460.0)
		check(tag + "its woodland from the list (%s)" % isl.forest, f.land["forests"].any(func(e): return e[0] == isl.forest))
		check(tag + "a river or more", not (L["rivers"] as Array).is_empty())
		for rv in L["rivers"]:
			var sf: PackedFloat32Array = rv["surf"]
			var pts: PackedVector2Array = rv["pts"]
			var falls := true
			for k in range(1, sf.size()):
				falls = falls and sf[k] <= sf[k - 1]
			check(tag + "the river's surface only falls (%.1f to %.1f m) and it reaches the sea" % [sf[0], sf[sf.size() - 1]], falls and sf[sf.size() - 1] < 0.0 and isl.hv(pts[pts.size() - 1]) < 0.0)
			var cut := 0
			var land := 0
			for k in range(sf.size()):
				if sf[k] < 1.0 or isl.sites.values().any(func(q): return (q as Vector2).distance_to(pts[k]) < 50.0):
					continue
				land += 1
				if absf(isl.hv(pts[k]) - (sf[k] - FL.BED)) < 0.6:
					cut += 1
			check(tag + "its bed is cut under the water away from the sites (%d of %d points)" % [cut, land], land == 0 or cut >= land * 0.75)
		for fl in FL.falls_of(L):
			var foot: Vector2 = fl["foot"]
			# (a site's flat, a place's levelled ground or a cave may have filled a falls in: it isn't built there)
			if isl.sites.values().any(func(q): return (q as Vector2).distance_to(foot) < 50.0) or isl.places.any(func(pl): return (pl["at"] as Vector2).distance_to(foot) < float(pl["r"]) + 10.0) \
					or isl.interiors.any(func(e): return (e["at"] as Vector2).distance_to(foot) < float(e["radius"]) + 10.0):
				continue
			var top: float = isl.hv(fl["top"] - fl["dir"] * 3.0)
			check(tag + "the falls drop %.1f m into a pool %.1f m deep" % [top - isl.hv(fl["foot"]), float(fl["y"]) - isl.hv(fl["foot"])],
				top - isl.hv(fl["foot"]) > 5.0 and float(fl["y"]) - isl.hv(fl["foot"]) > 1.8)
		var v: Vector2 = isl.sites["village"]
		var vd: float = FL.river_dist(L, v)
		check(tag + "the town beside a river (%.0f m from its middle)" % vd, vd > 40.0 and vd < 75.0)
		var giants := 0
		var wet := 0
		for key in isl._buckets.keys():
			if key[1] == "giant":
				giants += (isl._buckets[key] as Array).size()
			if key[1] == "rock":
				continue
			for xf in isl._buckets[key]:
				if FL.wet(L, Vector2(xf.origin.x, xf.origin.z)) > 0.9:
					wet += 1
		check(tag + "the woods are thick (%d big trees) and nothing grows in the rivers (%d)" % [giants, wet], giants > 300 and wet < 15)
		if not built and not FL.falls_of(L).is_empty():
			built = true
			isl.name = "ForestIsland"
			stage.add_child(isl)
			for s in isl._theme.steps(isl):
				s[1].call()
			var rivers: Node3D = isl.get_node("ForestRivers")
			check(tag + "built: the rivers' water, a pool at the falls' foot to swim in", rivers.get_node_or_null("Water") != null
				and not rivers.find_children("*", "InlandPool", false, false).is_empty())
			var br = isl.get_node_or_null("ForestBridges")
			print("%s bridges: %s" % [tag, br.find_children("*", "CollisionShape3D", false, false).size() if br != null else 0])
			isl.queue_free()
		else:
			isl.free()
	check("a falls was built on one of the islands", built)
	check("the woodland varies: %s" % [variants.keys()], variants.size() >= 2)
	return TK.done(fails)
