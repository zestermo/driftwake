extends SceneTree
## The theme land hooks (ThemeDef.radius, plan_land, shape): the base hooks are the base land, the jungle's
## islands are the jungle's size with no land plan; a theme that sinks its inland 6 m (a test theme, the jungle's
## files with its own shape) keeps the jungle island's draws (radius, capes, hills: the plan has its own stream)
## and changes the land away from the sites, while every site's levelled ground, its kept land and the dock's
## flat hold.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var fails := 0


const SINK := """extends "res://scripts/island/themes/jungle_theme.gd"

func _init() -> void:
	super()
	name = "sink_test"
	style = style.merged({"arena": "open"})

func plan_land(_isl, rng: RandomNumberGenerator) -> Dictionary:
	return {"drop": 6.0, "roll": rng.randf()}

func shape(isl, _p: Vector2, h: float) -> float:
	return h - float(isl.land_plan["drop"]) * clampf(h - 3.0, 0.0, 1.0)

func village_at(isl, _p: Vector2) -> Vector2:
	return isl.dock_shore * 0.3

func cover(_isl, _p: Vector2, _c: float) -> float:
	return 0.0

func growth(_isl, _p: Vector2) -> Vector2:
	return Vector2(0.0, 1.0)

func paint(_isl, _p: Vector2, _h: float, splat: Color) -> Color:
	return Color(splat.r, splat.g, 1.0, 1.0)
"""


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
	var TD = load("res://scripts/island/themes/theme_def.gd")
	var base = TD.new()
	check("the base hooks are the base land: no plan, shape gives h back", base.plan_land(null, RandomNumberGenerator.new()).is_empty() and base.shape(null, Vector2(3, 4), 7.25) == 7.25)
	check("the jungle's islands are 300-450 m", IT.of("jungle").radius == [300.0, 450.0])
	var c = load("res://scripts/world/chain.gd").make(4242, Vector2.ZERO, Vector2(0, -1))
	var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
	n["theme"] = "jungle"
	var t = IT.of("jungle")
	n.merge({"beast": t.bosses[0], "beast_look": 0, "beast_name": t.beasts[t.bosses[0]]["names"][0], "minis": [t.minis[0]], "roamer": t.roamers[0]}, true)
	load("res://scripts/island/island_theme.gd").meshes("jungle")
	var j = load("res://scripts/island/gen_island.gd").new()
	j.prepare(n)
	check("a jungle island has no land plan and its radius in range (r %.0f)" % j.radius, j.land_plan.is_empty() and j.radius >= 300.0 and j.radius <= 450.0)
	IT.all()
	var sink := GDScript.new()
	sink.source_code = SINK
	sink.reload()
	IT._by_name["sink_test"] = sink.new()
	var sn := n.duplicate(true)
	sn["theme"] = "sink_test"
	load("res://scripts/island/island_theme.gd").meshes("sink_test")
	var s = load("res://scripts/island/gen_island.gd").new()
	s.prepare(sn)
	check("the plan is made and the base land's draws don't move (radius, capes, summit and hills)",
		s.land_plan.has("drop") and s.radius == j.radius and str(s._capes) == str(j._capes) and str(s._bumps) == str(j._bumps))
	var sunk := 0
	var probes := 0
	for k in range(64):
		var q: Vector2 = Vector2.from_angle(k * TAU / 64.0) * float(j.radius) * (0.2 + 0.5 * float(k % 4) / 3.0)
		if j.hv(q) > 6.0 and s.sites.values().all(func(v): return q.distance_to(v) > 60.0):
			probes += 1
			if s.hv(q) < j.hv(q) - 4.0:
				sunk += 1
	check("the theme's shape changes the land away from the sites (%d of %d high probes sunk)" % [sunk, probes], probes > 4 and sunk * 10 >= probes * 7)
	var flat_ok := true
	var bad: Array = []
	for z in s._flat:
		var at: Vector2 = z[0]
		if absf(s.hv(at) - float(z[1])) > 0.25:
			flat_ok = false
			bad.append("%s %.2f vs %.2f" % [at, s.hv(at), z[1]])
	check("every flat holds its level under the shape %s" % [bad], flat_ok)
	var kept := true
	for site in ["village", "boss", "camp", "lair", "ruins"]:
		var p: Vector2 = s.sites[site]
		for a in range(8):
			if s.hv(p + Vector2.from_angle(a * TAU / 8.0) * 12.0) < 0.6:
				kept = false
	check("the sites' kept land stays land round each site", kept)
	var dock: Vector2 = s.dock_shore - s.dock_dir * 8.0
	check("the dock's flat ground is at 2 m (%.2f)" % s.hv(dock), absf(s.hv(dock) - 2.0) < 0.3)
	check("village_at moves the village (%s: its dock shore x 0.3)" % s.sites["village"], s.sites["village"] == s.dock_shore * 0.3)
	var kinds := {}
	for k in s._buckets.keys():
		kinds[k[1]] = true
	check("growth's plants 0 and cover 0: only rocks are scattered (%s), no undergrowth" % [kinds.keys()],
		kinds.keys() == ["rock"] and Array(s._thick).max() == 0)
	var cols: PackedColorArray = s._arrays[Mesh.ARRAY_COLOR]
	check("paint reaches the terrain's splat (every vertex's sand 1)", Array(cols).all(func(c): return c.b == 1.0))
	check("an open arena: the boss's floor kept clear, no ring of giants", s.canopy_arenas.size() == 1 and not s.canopy_arenas[0][3]
		and s.arena_ring(s.sites["boss"]).is_empty() and s.reserved_in(s.sites["boss"], 3.0) and j.canopy_arenas[0][3] and not j.arena_ring(j.sites["boss"]).is_empty())
	j.free()
	s.free()
	IT._by_name.erase("sink_test")
	return TK.done(fails)
