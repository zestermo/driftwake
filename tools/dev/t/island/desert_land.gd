extends SceneTree
## The desert's land on a few islands (a chain node made desert): its size, the land plan's features, the wadi
## running out to the sea, the capital level on the plateau when it moves up there, no site in a dune trough,
## the land variant from its list, plants sparse (almost none deep in the dunes), and the ground's textures.
## Prints the chain seeds whose first island is a desert (for genshot / islandshot).
const TK := preload("res://tools/dev/test_kit.gd")
const SEEDS := [2, 7, 1999]
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
	var d = IT.of("desert")
	var names: Array = IT.all().map(func(t): return t.name)
	check("the desert is registered after the jungle and snow (%s)" % [names], names.slice(0, 3) == ["jungle", "snow", "desert"])
	var firsts: Array = []
	for s in range(1, 400):
		var cs = CH.make(s, Vector2.ZERO, Vector2(0, -1))
		if cs.node(int(cs.start_next[0]))["theme"] == "desert":
			firsts.append(s)
		if firsts.size() >= 4:
			break
	print("DESERT FIRST ISLANDS: chain seeds %s" % [firsts])
	check("some chains open on a desert", not firsts.is_empty())
	load("res://scripts/island/island_theme.gd").meshes("desert")
	var variants := {}
	for sd in SEEDS:
		var c = CH.make(sd, Vector2.ZERO, Vector2(0, -1))
		var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
		n["theme"] = "desert"
		n.merge({"beast": d.bosses[0], "beast_look": 0, "beast_name": d.beasts[d.bosses[0]]["names"][0], "minis": [d.minis[0]], "roamer": d.roamers[0]}, true)
		var isl = load("res://scripts/island/gen_island.gd").new()
		var errlog := ErrorLog.new()
		OS.add_logger(errlog)
		isl.prepare(n)
		OS.remove_logger(errlog)
		var tag := "[%d] " % sd
		check(tag + "built without an error %s" % [errlog.errors], errlog.errors.is_empty())
		var L: Dictionary = isl.land_plan
		variants[isl.forest] = true
		print("%s r %.0f, %s: plateau %s capital %s, %d mesas, %d ridges, %d dune fields, %d wadis, %d canyons, %d salt, %d oases; built %s" % [tag, isl.radius, isl.forest,
			not (L["plateau"] as Array).is_empty(), L["capital"], L["mesas"].size(), L["ridges"].size(), L["dunes"].size(), L["wadis"].size(), L["canyons"].size(),
			L["salt"].size(), L["oases"].size(), isl.build_ms])
		check(tag + "a desert's size (r %.0f in 480-640)" % isl.radius, isl.radius >= 480.0 and isl.radius <= 640.0)
		# every wadi runs out to the sea: its far end under water, its bed reaching the waterline
		for wd in L["wadis"]:
			var pts: PackedVector2Array = wd[0]
			var wet := false
			for k in range(40):
				if isl.hv(_along(pts, 0.6 + 0.4 * k / 39.0)) < 0.5:
					wet = true
			check(tag + "the wadi reaches the sea", wet and isl.hv(pts[pts.size() - 1]) < 0.0)
		# the capital up on the plateau, its ground level
		if L["capital"]:
			var v: Vector2 = isl.sites["village"]
			var pl: Array = L["plateau"]
			var lo := INF
			var hi := -INF
			for k in range(16):
				var q: Vector2 = v + Vector2.from_angle(k * TAU / 16.0) * 20.0
				lo = minf(lo, isl.hv(q))
				hi = maxf(hi, isl.hv(q))
			check(tag + "the capital on the plateau (%.1f m up, %.0f m from its middle), flat within 20 m (%.2f m)" % [isl.hv(v), v.distance_to(pl[0]), hi - lo],
				v.distance_to(pl[0]) < float(pl[1]) and hi - lo < 1.5 and isl.hv(v) > 8.0)
		# no site in a dune trough: in a dune field, the ground 45 m round no more than 3 m above it
		var troughs: Array = []
		for site in ["village", "boss", "camp", "lair", "ruins"]:
			var p: Vector2 = isl.sites[site]
			var ring := 0.0
			for k in range(12):
				ring += isl.hv(p + Vector2.from_angle(k * TAU / 12.0) * 45.0) / 12.0
			if isl._theme._zone(isl, p).r > 0.2 and ring - isl.hv(p) > 3.0:
				troughs.append(site)
		check(tag + "no site in a dune trough %s" % [troughs], troughs.is_empty())
		# sparse on purpose: few plants, almost none deep in the dune fields
		var plants := 0
		var on_dunes := 0
		for key in isl._buckets.keys():
			if key[1] == "rock":
				continue
			for xf in isl._buckets[key]:
				plants += 1
				if isl._theme._zone(isl, Vector2(xf.origin.x, xf.origin.z)).r > 0.8:
					on_dunes += 1
		check(tag + "plants sparse (%d over %.2f km2) and almost none deep in the dunes (%d)" % [plants, PI * isl.radius * isl.radius / 1e6, on_dunes],
			plants < 30000 and on_dunes < 20)
		isl.free()
	check("the land varies: %s" % [variants.keys()], variants.size() >= 2)
	var st: Dictionary = load("res://scripts/island/kit/kit_style.gd").of("desert")
	check("the ground: dune sand, sandstone cliffs; an open arena; the desert's music, town music and bed",
		st["ground"]["grass"] == "desert_sand" and st["ground"]["cliff"] == "desert_rock" and st["arena"] == "open" and st["music"] == "desert"
		and st["music_town"] == "desert_town" and st["ambience"] == "desert")
	return TK.done(fails)


static func _along(pts: PackedVector2Array, t: float) -> Vector2:
	var f := t * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return pts[i].lerp(pts[i + 1], f - i)
