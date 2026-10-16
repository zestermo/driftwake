extends SceneTree
## The snow's land (snow_land.gd through the theme land hooks), on three chain islands made snow: the summit is
## the island's highest ground, a tall peak with a small flat top (the castle's or the lookout's ground) and
## pointed spires round it break the skyline; the trail up to it stays walkable (no stretch steeper than 50 deg);
## the frozen river runs from the peak's foot into the sea; the frozen lakes are level; nothing grows on the ice;
## the village's ground is flat; the same seed makes the same land.
const TK := preload("res://tools/dev/test_kit.gd")
const SEEDS := [4242, 77, 1301]
var SL
var stage
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _island(seed_v: int):
	var c = load("res://scripts/world/chain.gd").make(seed_v, Vector2.ZERO, Vector2(0, -1))
	var n: Dictionary = c.node(int(c.start_next[0])).duplicate(true)
	n.merge({"theme": "snow", "beast": "snow_leopard", "beast_look": 0, "minis": ["frost_alpha"], "roamer": "rimeback"}, true)
	var gi = load("res://scripts/island/gen_island.gd").new()
	gi.prepare(n)
	return gi


## Whether the snow's land changed the ground at p (a trail's steepness there is the snow's doing, not the base land's cliffs).
func _shaped(gi, p: Vector2) -> bool:
	var lp: Dictionary = gi.land_plan
	gi.land_plan = {}
	var base: float = gi._height_natural(p)
	gi.land_plan = lp
	return absf(gi._height_natural(p) - base) > 1.0


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	load("res://scripts/island/island_theme.gd").meshes("snow")
	SL = load("res://scripts/island/themes/snow_land.gd")
	for sv in SEEDS:
		var gi = _island(sv)
		var lp: Dictionary = gi.land_plan
		var top := -INF
		for h in gi.heights:
			top = maxf(top, h)
		var summit: Vector2 = gi.sites["summit"]
		var sh: float = gi.hv(summit)
		var spread := 0.0
		for a in range(8):
			spread = maxf(spread, absf(gi.hv(summit + Vector2.from_angle(a * TAU / 8.0) * 7.0) - sh))
		check("[%d] the summit is the highest ground, a tall peak (%.0f m of %.0f) with a flat top (%.1f m in 7 m)" % [sv, sh, top, spread],
			sh >= top - 3.0 and sh > 70.0 and spread < 2.5)
		var tall := 0
		for sp in lp["spires"]:
			var c: Vector2 = sp["c"]
			var rise: float = gi.hv(c) - gi.hv(c + (c - summit).normalized() * float(sp["r"]) * 1.2)
			if rise > 30.0:
				tall += 1
		check("[%d] pointed spires break the skyline (%d of %d rise 30 m+)" % [sv, tall, (lp["spires"] as Array).size()], tall >= 2)
		var worst := 0.0
		var where := Vector2.ZERO
		for path in gi.paths:
			var pts: PackedVector2Array = path
			if pts[pts.size() - 1].distance_to(summit) > 3.0:
				continue
			for j in range(pts.size() - 1):
				var a := pts[j]
				var b := pts[j + 1]
				var L := a.distance_to(b)
				var s := 0.0
				while s + 2.0 <= L:
					var p0 := a.lerp(b, s / L)
					var p1 := a.lerp(b, (s + 2.0) / L)
					var g := absf(gi.hv(p1) - gi.hv(p0)) / 2.0
					if g > worst and gi.hv(p0) > 0.5 and _shaped(gi, p0) and gi.sites.values().all(func(v): return p0.distance_to(v) > 46.0):
						worst = g
						where = p0
					s += 2.0
		check("[%d] the trail up the peak is walkable past the sites' levelled ground (steepest %.0f deg at %s)" % [sv, rad_to_deg(atan(worst)), where], worst < tan(deg_to_rad(50.0)))
		var river: PackedVector2Array = lp["river"]
		check("[%d] the frozen river runs from the peak's foot (%.0f m up) into the sea (%.1f m)" % [sv, gi.hv(river[0]), gi.hv(river[river.size() - 1])],
			gi.hv(river[0]) > 8.0 and gi.hv(river[river.size() - 1]) < 0.0)
		var level := true
		for lk in lp["lakes"]:
			var c: Vector2 = lk["c"]
			for a in range(6):
				if absf(gi.hv(c + Vector2.from_angle(a * TAU / 6.0) * float(lk["r"]) * 0.7) - gi.hv(c)) > 0.3 and gi.sites.values().all(func(v): return c.distance_to(v) > 72.0):
					level = false
		check("[%d] the frozen lakes are level (%d)" % [sv, (lp["lakes"] as Array).size()], level)
		var on_ice: Array = []
		for k in gi._buckets.keys():
			for xf in gi._buckets[k]:
				var q := Vector2((xf as Transform3D).origin.x, (xf as Transform3D).origin.z)
				if SL._ice_at(lp, q) > 0.99:
					on_ice.append([k[1], q])
		check("[%d] nothing grows on the ice %s" % [sv, on_ice], on_ice.is_empty())
		var v: Vector2 = gi.sites["village"]
		var vs := 0.0
		for a in range(8):
			vs = maxf(vs, absf(gi.hv(v + Vector2.from_angle(a * TAU / 8.0) * 18.0) - gi.hv(v)))
		check("[%d] the village stands on flat ground (%.1f m within 18 m)" % [sv, vs], vs < 2.0)
		if sv == SEEDS[0]:
			var again = _island(sv)
			check("the same seed makes the same land", again.heights == gi.heights and str(again.land_plan["spires"]) == str(lp["spires"]))
			again.free()
		gi.free()
	return TK.done(fails)
