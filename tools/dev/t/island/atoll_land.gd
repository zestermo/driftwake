extends SceneTree
## The coral atoll's foundations (scripts/island/themes/atoll_theme.gd, atoll_land.gd, atoll_town.gd, atoll_spots.gd,
## AtollPlants): registered and rolled apart from the second layer; every mesh slot filled. On a few islands made atolls:
## a lagoon two or three metres deep in the middle, the reef dropping off outside, islets on the ring, the paths round
## the ring wadeable (bar a pass), the boss's flat dry in the lagoon at the end of a wadeable causeway, the village on
## land; fishing and spear spots of both kinds. Built: the stilt town's boardwalk over the water, its huts and the pearl
## trader, its platforms' fishing spots, and the island's spot markers.
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
	var AL = load("res://scripts/island/themes/atoll_land.gd")
	var SP = load("res://scripts/island/themes/atoll_spots.gd")
	var v = IT.of("atoll")
	check("the atoll is registered, rolled apart from the second layer", v != null and v.apart and v.from_layer == 2)
	var total := 0
	var found := 0
	var early := 0
	for s in range(1, 81):
		var c = CH.make(s, Vector2.ZERO, Vector2(0, -1))
		for n in c.nodes:
			total += 1
			if str(n["theme"]) == "atoll":
				found += 1
				if int(n["layer"]) < 2:
					early += 1
	check("atolls turn up in chains (%d of %d islands)" % [found, total], found > total / 40 and found < total / 4)
	check("...never on the first layer (%d)" % early, early == 0)
	var m: Dictionary = load("res://scripts/island/island_theme.gd").meshes("atoll")
	var bad: Array = []
	for k in ["tree", "beach_tree", "bush", "fern", "grass", "rock", "mangrove", "bamboo", "broadleaf", "shrub"]:
		if not m.has(k) or (m[k] as Array).is_empty() or not (m[k] as Array).all(func(e): return e is Mesh):
			bad.append(k)
	for k in ["giant", "fig", "kapok", "emergent", "roof"]:
		if not m.has(k) or (m[k] as Array).is_empty() or not (m[k] as Array).all(func(e): return e is Array and e[0] is Mesh and e[1] is Mesh and e[2] is Vector3):
			bad.append(k)
	check("every mesh slot the scatter reads is filled %s" % [bad], bad.is_empty())
	var built := false
	var towns := 0
	for sd in SEEDS:
		var c = CH.make(sd, Vector2.ZERO, Vector2(0, -1))
		var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
		n["theme"] = "atoll"
		n.merge({"beast": v.bosses[0], "beast_look": 0, "beast_name": v.beasts[v.bosses[0]]["names"][0], "minis": [v.minis[0]], "roamer": v.roamers[0]}, true)
		var isl = load("res://scripts/island/gen_island.gd").new()
		var errlog := ErrorLog.new()
		OS.add_logger(errlog)
		isl.prepare(n)
		OS.remove_logger(errlog)
		var tag := "[%d] " % sd
		check(tag + "prepared without an error %s" % [errlog.errors], errlog.errors.is_empty())
		var L: Dictionary = isl.land_plan
		print("%s r %.0f, %s, ring w %.0f, prepare %s" % [tag, isl.radius, isl.forest, L["w"], isl.build_ms])
		var b: Vector2 = isl.sites["boss"]
		var vil: Vector2 = isl.sites["village"]
		# the lagoon: points between the middle and the ring's inner edge, off the boss's flat, the causeway and the hole
		var depths: Array = []
		for k in range(16):
			var a := TAU * k / 16.0
			var inner: float = AL.ring_r(isl, a)[1]
			var q := Vector2.from_angle(a) * inner * 0.6
			if q.distance_to(b) < 50.0 or q.distance_to((L["hole"] as Array)[0]) < 30.0:
				continue
			depths.append(-float(isl.hv(q)))
		var deep: Array = depths.filter(func(dd): return dd > 1.3 and dd < 5.0)
		check(tag + "a shallow lagoon inside the ring (%d of %d points 1.3-5 m deep: %s)" % [deep.size(), depths.size(), depths.map(func(dd): return snappedf(dd, 0.1))], deep.size() >= depths.size() * 0.6)
		var outer: float = AL.ring_r(isl, (-vil).angle() + 0.7)[0]
		var off: float = isl.hv(Vector2.from_angle((-vil).angle() + 0.7) * (outer + 60.0))
		check(tag + "the reef drops off outside the ring (%.0f m)" % off, off < -12.0)
		var islets := 0
		for k in range(72):
			var a := TAU * k / 72.0
			if float(isl.hv(AL.ring_point(isl, a, 0.5))) > 1.4:
				islets += 1
		check(tag + "islets on the ring (%d of 72 bearings dry)" % islets, islets >= 12 and islets <= 66)
		var wade := 0
		var all := 0
		for path in isl.paths.slice(2):
			for q in path:
				all += 1
				if float(isl.hv(q)) > -1.0:
					wade += 1
		check(tag + "the paths round the ring and down the causeway are wadeable (%d of %d points)" % [wade, all], wade >= all * 0.85)
		check(tag + "the boss's flat stands dry in the lagoon (%.1f m)" % isl.hv(b), isl.hv(b) > 0.2 and b.length() < float(AL.ring_r(isl, b.angle())[1]))
		check(tag + "the village on land (%.1f m)" % isl.hv(vil), isl.hv(vil) > 0.8)
		var spots: Array = SP.list(isl)
		var kinds := {}
		for s in spots:
			kinds[s["kind"]] = true
		check(tag + "fishing and spear spots (%d: %s)" % [spots.size(), kinds.keys()], kinds.has("line") and kinds.has("spear"))
		var town: Array = isl.places.filter(func(pl): return pl["kind"] == "atoll_stilts")
		towns += town.size()
		if not built and not town.is_empty():
			built = true
			isl.name = "AtollIsland"
			stage.add_child(isl)
			for s in isl._theme.steps(isl):
				s[1].call()
			for s in load("res://scripts/island/kit/kit_landmarks.gd").steps(isl):
				if s[0] == "atoll_stilts":
					s[1].call()
			var tn: Node3D = isl.get_node("Place_atoll_stilts")
			var walk = tn.find_child("AtollTown", true, false)
			check(tag + "built: the stilt town's boardwalk, its huts", walk != null and tn.find_child("StiltHut0", true, false) != null)
			var at: Vector2 = town[0]["at"]
			check(tag + "...out over the water (%.1f m under its middle)" % isl.hv(at), isl.hv(at) < -0.5)
			var trader := tn.find_children("*", "NPC", true, false).filter(func(np): return str(np.get("shop_id")) != "")
			check(tag + "...its pearl trader keeps a shop", trader.size() == 1)
			var pier: Array = get_nodes_in_group("fishing_spots").filter(func(mk): return mk.get_meta("where") == "pier")
			check(tag + "...its platforms are fishing spots (%d)" % pier.size(), pier.size() >= 3)
			check(tag + "the island's spots are marked (%d spear spots)" % get_nodes_in_group("spear_spots").size(), get_nodes_in_group("spear_spots").size() >= 1)
			isl.queue_free()
		else:
			isl.free()
	check("a stilt town on most atolls (%d of %d)" % [towns, SEEDS.size()], towns >= 2)
	check("an atoll was built", built)
	return TK.done(fails)
