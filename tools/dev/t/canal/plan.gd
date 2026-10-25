extends SceneTree
## The canal city's layout (CanalPlan, 1.21 piece 4) holds together, before anything's built on it: no two floors
## overlap; every bridge lands on a floor at both ends over water between; every water taxi landing is on a walkway
## at the water's edge; no special building stands on a floor; every house lot stands off the floors and the water,
## and most of the walkways have houses fronting them; the berth lies in open water off the riva.
const TK := preload("res://tools/dev/test_kit.gd")
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	var P = load("res://scripts/island/canal_plan.gd")
	var fl: Array = P.floors()
	var over: Array = []
	for i in range(fl.size()):
		for j in range(i + 1, fl.size()):
			if (fl[i][1] as Rect2).intersects(fl[j][1]):
				over.append("%s/%s" % [fl[i][0], fl[j][0]])
	check("%d floors, none overlapping (%s)" % [fl.size(), over], fl.size() > 30 and over.is_empty())
	var bad: Array = []
	for b in P.BRIDGES:
		var a: Vector2 = b[0]
		var c: Vector2 = b[1]
		var d := (c - a).normalized()
		if not P.in_floor(a - d * 1.0) or not P.in_floor(c + d * 1.0) or not P.in_canal((a + c) * 0.5):
			bad.append(str([a, c]))
	check("every bridge from a floor to a floor over water (%s)" % [bad], bad.is_empty())
	var bl: Array = []
	for l in P.LANDINGS:
		var q: Vector2 = l[1]
		var w: Vector2 = l[2]
		if not P.in_floor(q) or not (P.in_canal(q + w * 2.5) or P.land_t(q + w * 2.5) > 0.0):
			bl.append(str(l[0]))
	check("every landing on a walkway by the water (%s)" % [bl], bl.is_empty())
	var sp: Array = []
	for k in P.SPECIAL:
		for f in fl:
			if (P.SPECIAL[k][0] as Rect2).intersects(f[1]):
				sp.append("%s on %s" % [k, f[0]])
	check("no building of its own on a floor (%s)" % [sp], sp.is_empty())
	var lots: Array = P.lots()
	var wrong := lots.filter(func(l): return P.in_floor((l["r"] as Rect2).get_center()) or P.in_canal((l["r"] as Rect2).get_center()))
	var fronts := lots.filter(func(l): return l["front"]).size()
	check("%d house lots, none on a floor or in the water (%d)" % [lots.size(), wrong.size()], lots.size() > 300 and wrong.is_empty())
	check("...%d of them fronting a walkway" % fronts, fronts > 120)
	check("the berth in open water off the riva", P.land_t(P.BERTH) > 3.0 and P.BERTH.y < P.FRONT_Z + 15.0)
	print("RESULT %s" % ("OK" if fails == 0 else "FAILED (%d)" % fails))
	quit(0 if fails == 0 else 1)


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1
