class_name VillageLayouts
extends RefCounted
## The pool of village layouts a generated island rolls from (IslandVillage.plan):
##   town    - a plaza and a market, lanes out lined with houses, a shrine at a lane's end
##   hamlets - a small hub with the services and a little market, and two or three hamlets
##             out along the paths (fishers', farmers', woodcutters')
##   post    - a walled trading post: a palisade with gates where the paths come in,
##             watchtowers, the market in the middle, storehouses round the wall
##   stilts  - a raised village: a deck over the plaza, walkways out to houses on tall
##             stilts, ramps down to the ground, lanes of stilt huts beyond
##   ruins   - the old village abandoned and overgrown, bugs in its plaza and caches in
##             its houses; the survivors (and the services) in a hamlet nearer the shore
##   medina  - a packed town (the desert's): the town's heart, then houses shoulder to
##             shoulder in rings and rows, a great domed hall and minarets over the roofs
## Every layout keeps the inn, the trader, the cook, the elder and the job board where its
## people are. All of it is data, worked out on GenIsland.prepare's worker thread; its
## own occupancy (`occ`) keeps the pieces apart, and what it takes is reserved from the
## plants at the end (the settlement is a clearing cut into the jungle).

## The layouts there are (a theme rolls from its style's "village_layouts" weights; Brinehollow's are these).
const POOL := {"town": 3, "hamlets": 2, "post": 2, "stilts": 2, "ruins": 1, "medina": 0}
## Tools and tests set this to build one layout (every island built after uses it).
static var force := ""

const LANE_HW := 1.3
const RING_R := 18.5
const PER_STREET := 6
## [w, d, ext: porch and steps in front] by kind
const SIZE := {"inn": [8.0, 6.0, 3.6], "trade": [6.4, 5.2, 2.4], "cook": [6.4, 5.2, 2.4], "home": [5.6, 4.6, 2.3], "elder": [6.0, 4.8, 2.3],
	"hut": [5.0, 4.2, 2.0], "tall": [5.2, 4.6, 2.0], "workshop": [7.5, 5.0, 0.6], "storehouse": [3.6, 3.0, 1.4], "shrine": [4.6, 4.6, 1.0],
	"ruin": [5.0, 4.2, 0.6], "hall": [12.0, 12.0, 1.6], "minaret": [3.4, 3.4, 0.3]}
const STREET_KINDS := ["workshop", "home", "tall", "storehouse", "hut", "home", "tall", "hut", "hut", "tall", "hut", "hut", "tall", "hut", "home", "hut"]
## Raised (stilts layout): the deck's height over the plaza and its radius.
const DECK_H := 2.6
const DECK_R := 8.5

var gi: GenIsland
var layout := ""
var kc: KitContext
var rng: RandomNumberGenerator
## The village site, and the heart (where the services, the fire and the elder are; the site but for ruins).
var site := Vector2.ZERO
var c := Vector2.ZERO
var dock := Vector2.ZERO
var to_dock := Vector2.ZERO
var dock_a := 0.0
var occ: Array = []
var dirs: Array = []
var streets: Array = []
var widths: Array = []
var reach: Array = []
var lanes: Array = []
var blds: Array = []
var items: Array = []
var quads: Array = []
var worn: Array = []
var bunting: Array = []
var hamlets: Array = []
## [point, y (INF: on the ground)]
var fires: Array = []
var market := {}
var board := {}
var extra := {}
var heart_y := INF
var plaza_r := 12.0
var clear: Array = []


static func plan(isl: GenIsland) -> Dictionary:
	var L := VillageLayouts.new()
	L.gi = isl
	L.kc = KitContext.make(isl, int(isl.node["seed"]), isl.theme, 0, {})
	L.rng = L.kc.rng(41)
	L.site = isl.sites["village"]
	L.c = L.site
	L.dock = isl.sites["dock"]
	L.to_dock = (L.dock - L.c).normalized()
	L.dock_a = L.to_dock.angle()
	var kind := force if force != "" else L._pick()
	L.layout = kind
	L.call("_" + kind)
	L._reserve()
	return {"layout": kind, "c": L.c, "heart_y": L.heart_y, "plaza_r": L.plaza_r, "to_dock": (L.dock - L.c).normalized(), "lanes": L.lanes,
		"streets": L.streets, "market": L.market, "buildings": L.blds, "items": L.items, "bunting": {"poles": L.bunting, "seed": L.rng.randi()},
		"board": L.board, "quads": L.quads, "worn": L.worn, "hamlets": L.hamlets, "fires": L.fires, "extra": L.extra}


func _pick() -> String:
	var pool: Dictionary = kc.style["village_layouts"]
	var total := 0
	for k in pool.keys():
		total += int(pool[k])
	var roll := kc.rng(40).randi() % total
	for k in pool.keys():
		roll -= int(pool[k])
		if roll < 0:
			# (the ruins' survivors need a flat spot out along a path)
			if k == "ruins" and _survivors_at() == Vector2.INF:
				return "town"
			# (...and the hamlets two spots out along the paths: without them it's a hub on its own)
			if k == "hamlets" and _hamlet_picks(_hamlet_spots(), 0).size() < 2:
				return "town"
			return k
	return pool.keys()[0]


## Where the ruins' survivors settle: the first flat open ground 55-120 m out along a path, away from the dock (INF: nowhere).
func _survivors_at() -> Vector2:
	for i in range(gi.paths.size()):
		var st := _stretch(gi.paths[i], site, 150.0)
		for e in KitVillage.along(st, 4.0, 55.0, 120.0):
			var q: Vector2 = e[0]
			if q.distance_to(dock) > 45.0 and _open_ground(q) and kc.ground_max(q, 14.0) - kc.ground_min(q, 14.0) < 3.0:
				return q
	return Vector2.INF


# ==========================================================================
# The layouts
# ==========================================================================
func _town() -> void:
	_streets_at(site, 62.0)
	fires.append([c, INF])
	_market_off(25.0, ["fruit", "fish", "cloth", "pots"], 9.6)
	_lanes(3)
	_services(RING_R)
	if not _shrine_at_lane_end():
		_ring("shrine", dock_a + PI, RING_R + 2.0, PI)
	_ring_fill(5, RING_R)
	_street_houses(STREET_KINDS.duplicate(), 14.0)
	_plaza(true, 2, 12.8)
	_market_dressing()
	_dress_buildings()
	_dress_streets(13.0)
	var prng := kc.rng(43)
	KitPaving.plan_disk(kc, quads, c, 10.5, prng)
	KitPaving.plan_disk(kc, quads, market["c"], 6.8, prng)
	KitPaving.plan_path(kc, quads, KitVillage.cut(streets[0], 9.0, 44.0), 1.6)
	for l in lanes:
		KitPaving.plan_path(kc, quads, KitVillage.cut(l, 0.0, 16.0), 1.15)
	_worn_fronts(prng)


## The town's heart, souk and services, then flat roofs packed close (gaps of ~0.4 m, not the town's metre):
## a ring round the plaza, rows along every street and lane, minarets, and rings further out facing in.
func _medina() -> void:
	_streets_at(site, 74.0)
	fires.append([c, INF])
	_market_off(24.0, ["fruit", "fish", "cloth", "pots"], 9.6)
	_lanes(4)
	_services(RING_R)
	var hall_a: float = _free_angle(dock_a, deg_to_rad(70.0))[0]
	for k in range(6):
		if _ring("hall", hall_a, RING_R + 6.5 + k * 3.0, PI * 0.5):
			break
	if not _shrine_at_lane_end():
		_ring("shrine", dock_a + PI, RING_R + 2.0, PI)
	_ring_fill(8, RING_R, "", 0.45, 0.35)
	var queue: Array = []
	for k in range(48):
		queue.append(["tall", "hut", "tall", "home", "hut", "tall", "hut", "hut", "tall", "hut", "tall", "home", "hut", "tall", "storehouse", "hut"][k % 16])
	_street_houses(queue, 13.0, 12, 0.3, 1.4, 0.35)
	_minarets(rng.randi_range(2, 3))
	for e in [[RING_R + 9.0, 12], [RING_R + 17.5, 14], [RING_R + 26.0, 16]]:
		_ring_fill(e[1], e[0] - 0.4, "", 0.5, 0.35)
	_plaza(true, 2, 12.8)
	_market_dressing()
	_dress_buildings()
	_dress_streets(13.0)
	var prng := kc.rng(43)
	KitPaving.plan_disk(kc, quads, c, 10.5, prng)
	KitPaving.plan_disk(kc, quads, market["c"], 6.8, prng)
	KitPaving.plan_path(kc, quads, KitVillage.cut(streets[0], 9.0, 52.0), 1.6)
	for l in lanes:
		KitPaving.plan_path(kc, quads, KitVillage.cut(l, 0.0, 24.0), 1.15)
	_worn_fronts(prng)


## n minarets spread round the heart, each as near the ring past the plaza's houses as there's room.
func _minarets(n: int) -> void:
	var a0 := rng.randf() * TAU
	for i in range(n):
		var a := a0 + TAU * i / n
		for k in range(36):
			var p := c + Vector2.from_angle(a + (k % 6 - 2.5) * 0.11) * (RING_R + 5.0 + (k / 6) * 4.5)
			if _take("minaret", p, c - p, [], 0.2):
				break


func _hamlets() -> void:
	_streets_at(site, 40.0)
	plaza_r = 8.0
	fires.append([c, INF])
	_market_off(19.0, ["fruit", "fish"], 7.0)
	_services(15.0)
	_ring_fill(3, 15.0)
	_plaza(true, 2, 9.5)
	_market_dressing()
	hamlets.append({"c": c, "kind": "hub"})
	# two or three hamlets out along the paths
	var spots := _hamlet_spots()
	var kinds := ["fishers", "farmers", "woodcutters"]
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	var k0 := rng.randi() % maxi(spots.size(), 1)
	for hc in _hamlet_picks(spots, k0):
		_hamlet(hc, kinds[hamlets.size() - 1])
	_dress_buildings()
	_dress_streets(10.0)
	var prng := kc.rng(43)
	KitPaving.plan_disk(kc, quads, c, 7.5, prng)
	KitPaving.plan_disk(kc, quads, market["c"], 5.6, prng)
	_worn_fronts(prng)


## Points along the paths 70-150 m out from the site, where hamlets may go.
func _hamlet_spots() -> Array:
	var spots: Array = []
	for i in range(gi.paths.size()):
		var st := _stretch(gi.paths[i], site, 170.0)
		for e in KitVillage.along(st, 5.0, 70.0, 150.0):
			spots.append(e[0])
	return spots


## Up to three of `spots` (from the k0-th on) on open, gentle ground, apart from the heart and each other.
func _hamlet_picks(spots: Array, k0: int) -> Array:
	var out: Array = []
	for k in range(spots.size()):
		if out.size() >= 3:
			break
		var hc: Vector2 = spots[(k + k0) % spots.size()]
		if hc.distance_to(c) < 62.0 or out.any(func(h): return hc.distance_to(h) < 55.0) or not _open_ground(hc) or kc.ground_max(hc, 11.0) - kc.ground_min(hc, 11.0) > 4.5:
			continue
		out.append(hc)
	return out


## One hamlet at hc (on a path): a fire, three to five houses round it facing in, and
## what its people work at.
func _hamlet(hc: Vector2, kind: String) -> void:
	hamlets.append({"c": hc, "kind": kind})
	fires.append([hc, INF])
	occ.append([hc, 2.2])
	clear.append([hc, 16.0])
	var want: Array = {"fishers": ["hut", "hut", "tall", "hut"], "farmers": ["storehouse", "hut", "home", "hut"], "woodcutters": ["workshop", "hut", "tall", "hut"]}[kind]
	var a0 := rng.randf() * TAU
	var placed := 0
	for k in range(72):
		if placed >= want.size():
			break
		var a := a0 + k * TAU / 36.0
		var p := hc + Vector2.from_angle(a) * (rng.randf_range(10.5, 12.5) + (2.5 if k >= 36 else 0.0))
		if _take(want[placed], p, hc - p):
			placed += 1
	var s := rng.randi()
	var hr := KitVillage._seeded(s)
	for k in range(2):
		var bp := hc + Vector2.from_angle(a0 + PI * 0.3 + k * PI) * 3.6
		KitVillage.plan_put(kc, items, occ, "bench", bp, KitContext.face_yaw(hc - bp), 1.0)
	var torches := 0
	for k in range(8):
		if torches >= 2:
			break
		var tp := hc + Vector2.from_angle(a0 + k * TAU / 8.0 + 0.2) * 6.5
		if KitVillage.plan_put(kc, items, occ, "torch", tp, 0.0, 0.5, {"lit": torches == 0}):
			torches += 1
	for k in range(10):
		var q := hc + Vector2.from_angle(a0 + 1.1 + k * TAU / 10.0) * hr.randf_range(5.5, 7.5)
		match kind:
			"fishers":
				if k % 3 == 0:
					KitVillage.plan_put(kc, items, occ, "fishrack", q, KitContext.face_yaw(hc - q) + PI * 0.5, 1.2, {"spot": {"at": q + (hc - q).normalized() * 0.9, "face": q - hc}})
				elif k % 3 == 1:
					KitVillage.plan_put(kc, items, occ, "canoe", q, KitContext.face_yaw(hc - q), 1.8)
				elif KitVillage._spot(kc, occ, q, 1.0):
					KitVillage.plan_cargo(kc, items, q, hr.randf() * TAU, hr, ["basket", "jar"][k % 2])
					occ.append([q, 1.0])
			"farmers":
				if k % 3 != 2:
					KitVillage.plan_put(kc, items, occ, "garden", q + (q - hc).normalized() * 2.0, KitContext.face_yaw(hc - q), 2.3, {"w": 3.8, "d": 2.8, "seed": hr.randi(), "spot": {"at": q, "face": q - hc}})
				elif KitVillage._spot(kc, occ, q, 1.0):
					KitVillage.plan_cargo(kc, items, q, hr.randf() * TAU, hr, "sack")
					occ.append([q, 1.0])
			_:
				if k % 3 == 0:
					KitVillage.plan_put(kc, items, occ, "woodpile", q, KitContext.face_yaw(q - hc), 1.0, {"spot": {"at": q + (hc - q).normalized() * 1.5, "face": q - hc}})
				elif k % 3 == 1:
					KitVillage.plan_put(kc, items, occ, "cart", q, KitContext.face_yaw(hc - q), 1.2)
				elif KitVillage._spot(kc, occ, q, 1.0):
					KitVillage.plan_cargo(kc, items, q, hr.randf() * TAU, hr, "crate")
					occ.append([q, 1.0])
	KitPaving.plan_disk(kc, worn, hc, 6.0, hr)


func _post() -> void:
	var r := 29.0
	_streets_at(site, 62.0)
	plaza_r = 9.0
	market = {"c": c, "kinds": ["fruit", "fish", "cloth", "pots"], "toward": c + to_dock * 10.0, "seed": rng.randi()}
	occ.append([c, 9.6])
	var fp := c + Vector2(-to_dock.y, to_dock.x) * 12.0
	fires.append([fp, INF])
	occ.append([fp, 2.2])
	_board_near(c + to_dock * 12.0)
	# gates where the streets meet the wall, the wall between them
	var gates: Array = []
	for st in streets:
		for e in KitVillage.along(st, 0.5, r, r):
			var ga: float = (e[0] - c).angle()
			if not gates.any(func(g): return absf(angle_difference(ga, float(g["a"]))) < 0.3):
				gates.append({"a": ga, "p": e[0], "t": e[1]})
	gates.sort_custom(func(x, y): return float(x["a"]) < float(y["a"]))
	var half := 3.0 / r
	var arcs: Array = []
	for i in range(gates.size()):
		var a0: float = gates[i]["a"] + half
		var a1: float = gates[(i + 1) % gates.size()]["a"] - half
		if i == gates.size() - 1:
			a1 += TAU
		if a1 - a0 > 0.05:
			arcs.append([a0, a1])
	for arc in arcs:
		var a: float = arc[0]
		while a < float(arc[1]):
			occ.append([c + Vector2.from_angle(a) * r, 1.3])
			a += 2.5 / r
	var towers: Array = []
	var by_len := arcs.duplicate()
	by_len.sort_custom(func(x, y): return float(x[1]) - float(x[0]) > float(y[1]) - float(y[0]))
	for arc in by_len.slice(0, 3):
		var ta := (float(arc[0]) + float(arc[1])) * 0.5
		var tp := c + Vector2.from_angle(ta) * (r - 3.2)
		towers.append({"p": tp, "face": tp - c})
		occ.append([tp, 2.8])
	extra["palisade"] = {"r": r, "arcs": arcs, "seed": rng.randi()}
	extra["gates"] = gates
	extra["towers"] = towers
	clear.append([c, r + 5.0])
	# round the inside of the wall, facing in
	_services(17.0)
	for k in ["storehouse", "storehouse", "workshop", "hut", "tall", "hut"]:
		_ring(k, rng.randf() * TAU, 17.0, PI)
	# outside the main gate, along the road in
	_street_houses(["hut", "tall", "hut", "storehouse", "hut", "hut"], r + 5.0, 3)
	# lamps at the gates, torches round the inside, cargo where the trade is
	var lit := 0
	for g in gates:
		var gp: Vector2 = g["p"]
		var inward := (c - gp).normalized()
		var lp: Vector2 = gp + inward * 2.6 + Vector2(-inward.y, inward.x) * 3.4
		if KitVillage.plan_put(kc, items, occ, "lamp", lp, KitContext.face_yaw(c - lp) - PI * 0.5, 0.6, {"lit": lit < 3}):
			lit += 1
		var cq: Vector2 = gp + inward * 3.5 - Vector2(-inward.y, inward.x) * 3.6
		if KitVillage._spot(kc, occ, cq, 1.1):
			KitVillage.plan_cargo(kc, items, cq, KitContext.face_yaw(inward), rng, ["crate", "barrel", "sack"][rng.randi() % 3])
			occ.append([cq, 1.1])
	for k in range(12):
		var tq := c + Vector2.from_angle(k * TAU / 12.0 + 0.13) * 21.5
		KitVillage.plan_put(kc, items, occ, "torch", tq, 0.0, 0.5, {"lit": false})
	for k in range(4):
		var bp := c + Vector2.from_angle(dock_a + PI * 0.25 + k * PI * 0.5) * 11.2
		KitVillage.plan_put(kc, items, occ, "bench", bp, KitContext.face_yaw(c - bp), 1.0)
	for k in range(12):
		var wp := c + Vector2.from_angle(dock_a + PI * 0.6 + k * TAU / 12.0) * 12.5
		if KitVillage.plan_put(kc, items, occ, "well", wp, KitContext.face_yaw(c - wp), 1.7, {"spot": {"at": wp + (c - wp).normalized() * 1.7, "face": wp - c}}):
			break
	_dress_buildings()
	_dress_streets(r + 3.0)
	var prng := kc.rng(43)
	KitPaving.plan_disk(kc, quads, c, 9.5, prng)
	for g in gates:
		KitPaving.plan_path(kc, quads, PackedVector2Array([g["p"] - g["t"] * 4.0, g["p"] + g["t"] * 4.0]), 1.6)
	_worn_fronts(prng)
	KitPaving.plan_disk(kc, worn, c, 15.0, prng)


func _stilts() -> void:
	_streets_at(site, 62.0)
	plaza_r = DECK_R
	heart_y = kc.hv(c) + DECK_H
	fires.append([c, heart_y])
	occ.append([c, DECK_R + 0.6])
	# ramps down where the first streets leave the deck
	var ramps: Array = []
	for i in range(mini(streets.size(), 3)):
		var u := Vector2.from_angle(float(dirs[i]))
		ramps.append({"a": c + u * (DECK_R - 0.4), "b": c + u * (DECK_R + 8.5), "y": heart_y})
		for k in range(5):
			occ.append([c + u * (DECK_R + 1.5 + k * 1.8), 1.4])
	_market_off(27.0, ["fruit", "fish", "cloth"], 8.6)
	_lanes(2)
	# the raised ring: every door at the deck's height, a walkway out to each
	var before := blds.size()
	_services(20.0)
	_ring_fill(4, 20.5)
	var walks: Array = []
	var gaps: Array = dirs.slice(0, ramps.size())
	for b in blds.slice(before):
		b["raised"] = heart_y
		var f: Vector2 = b["face"]
		var front: Vector2 = b["p"] + f * (float(b["d"]) * 0.5 + _deck_ext(b["kind"]))
		var start: Vector2 = c + (front - c).normalized() * (DECK_R - 0.3)
		walks.append({"a": start, "b": front, "y": heart_y})
		gaps.append((front - c).angle())
		for k in range(int(start.distance_to(front) / 2.0)):
			occ.append([start.lerp(front, (k + 0.5) / (start.distance_to(front) / 2.0)), 1.1])
	extra["deck"] = {"c": c, "r": DECK_R, "y": heart_y, "gaps": gaps}
	extra["ramps"] = ramps
	extra["walks"] = walks
	_street_houses(STREET_KINDS.duplicate(), 30.0)
	# on the deck: benches round the hearth, lamps, jars; under it, the well
	for k in range(4):
		var bp := c + Vector2.from_angle(dock_a + PI * 0.25 + k * PI * 0.5) * 4.6
		KitVillage.plan_put(kc, items, [], "bench", bp, KitContext.face_yaw(c - bp), 1.0, {"y": heart_y})
	for k in range(2):
		var lp := c + Vector2.from_angle(dock_a + PI * 0.5 + k * PI) * (DECK_R - 1.0)
		var lamp := {"k": "lamp", "p": lp, "yaw": KitContext.face_yaw(c - lp) - PI * 0.5, "lit": true, "y": heart_y}
		items.append(lamp)
	for k in range(3):
		var jp := c + Vector2.from_angle(dock_a + 1.0 + k * TAU / 3.0) * (DECK_R - 1.6)
		KitVillage.plan_cargo(kc, items, jp, rng.randf() * TAU, rng, "jar")
		for it in items.slice(items.size() - 4):
			it["y"] = heart_y
	for k in range(12):
		var wp := c + Vector2.from_angle(dock_a + PI * 0.6 + k * TAU / 12.0) * 13.5
		if KitVillage.plan_put(kc, items, occ, "well", wp, KitContext.face_yaw(c - wp), 1.7, {"spot": {"at": wp + (c - wp).normalized() * 1.7, "face": wp - c}}):
			break
	_board_near(c + to_dock * (DECK_R + 3.0))
	_market_dressing()
	_dress_buildings()
	_dress_streets(18.0)
	var prng := kc.rng(43)
	KitPaving.plan_disk(kc, quads, market["c"], 6.4, prng)
	_worn_fronts(prng)
	KitPaving.plan_disk(kc, worn, c, DECK_R + 3.0, prng)


func _ruins() -> void:
	# the old village, overgrown: broken houses round its plaza and along two lanes
	_streets_at(site, 62.0)
	_lanes(2)
	var old := blds.size()
	_ring_fill(6, RING_R, "ruin")
	_street_houses(["ruin", "ruin", "ruin", "ruin", "ruin", "ruin", "ruin", "ruin", "ruin", "ruin"], 14.0, 4)
	for k in range(12):
		var wp := c + Vector2.from_angle(dock_a + PI * 0.6 + k * TAU / 12.0) * 7.5
		if KitVillage.plan_put(kc, items, occ, "well", wp, KitContext.face_yaw(c - wp), 1.7):
			break
	var nest: Array = []
	for k in range(20):
		if nest.size() >= 5:
			break
		var a := TAU * k / 7.0 + rng.randf_range(-0.3, 0.3)
		var bp := c + Vector2.from_angle(a) * rng.randf_range(4.5, 11.0)
		if KitVillage._spot(kc, occ, bp, 1.4, 0.6):
			nest.append([bp, nest.is_empty()])
			occ.append([bp, 1.6])
	extra["nest"] = {"c": c, "burrows": nest}
	var caches: Array = []
	for b in blds.slice(old):
		if caches.size() < 3 and (rng.randf() < 0.45 or caches.is_empty()):
			caches.append({"p": b["p"], "face": b["face"], "key": "village_cache_%d" % (caches.size() + 1)})
	extra["caches"] = caches
	for b in blds.slice(old):
		for k in range(2):
			var q: Vector2 = b["p"] + Vector2.from_angle(rng.randf() * TAU) * (float(b["w"]) * 0.5 + 1.6)
			KitVillage.plan_put(kc, items, occ, "rubble", q, rng.randf() * TAU, 1.0, {"seed": rng.randi()})
	var prng := kc.rng(43)
	var old_cobbles: Array = []
	KitPaving.plan_disk(kc, old_cobbles, c, 10.5, prng)
	for q in old_cobbles:
		if prng.randf() < 0.45:
			quads.append(q)
	clear.append([site, 30.0])
	# the survivors: a hamlet on a path nearer the shore, the services round its fire
	c = _survivors_at()
	plaza_r = 7.0
	fires.append([c, INF])
	occ.append([c, 2.2])
	clear.append([c, 22.0])
	hamlets.append({"c": c, "kind": "survivors"})
	var keep := streets.duplicate()
	var keep_w := widths.duplicate()
	var keep_r := reach.duplicate()
	_streets_through(c, 30.0)
	_services(14.0)
	_ring_fill(2, 14.0)
	_plaza(true, 2, 0.0)
	_dress_buildings()
	_dress_streets(8.0)
	streets = keep + streets
	widths = keep_w + widths
	reach = keep_r + reach
	KitPaving.plan_disk(kc, worn, c, 8.0, prng)
	_worn_fronts(prng)


# ==========================================================================
# Pieces the layouts share
# ==========================================================================
## The streets out of the village site: every path's stretch from its plaza end to `reach_m` from it.
func _streets_at(at: Vector2, reach_m: float) -> void:
	streets = []
	widths = []
	dirs = []
	for i in range(gi.paths.size()):
		var st := _stretch(gi.paths[i], at, reach_m)
		if st.size() > 1:
			streets.append(st)
			widths.append(1.8 if i == 0 else 1.3)
			dirs.append(_heading(st, at))
	reach = []
	reach.resize(streets.size())
	reach.fill(0.0)


## The streets through a point on a path (a hamlet's): the path both ways from it, `half` m each.
func _streets_through(at: Vector2, half: float) -> void:
	streets = []
	widths = []
	dirs = []
	for path in gi.paths:
		var best := -1
		for j in range(path.size()):
			if path[j].distance_to(at) < 3.0 and (best < 0 or path[j].distance_to(at) < path[best].distance_to(at)):
				best = j
		if best < 0:
			continue
		var fwd := PackedVector2Array()
		var bwd := PackedVector2Array()
		for j in range(best, path.size()):
			fwd.append(path[j])
			if path[j].distance_to(at) > half:
				break
		for j in range(best, -1, -1):
			bwd.append(path[j])
			if path[j].distance_to(at) > half:
				break
		for st in [fwd, bwd]:
			if st.size() > 1:
				streets.append(st)
				widths.append(1.3)
				dirs.append(_heading(st, at))
	reach = []
	reach.resize(streets.size())
	reach.fill(half)


## The part of a path from its end at `at` out to `reach_m` from it (empty if it doesn't end there).
static func _stretch(path: PackedVector2Array, at: Vector2, reach_m: float) -> PackedVector2Array:
	var pts := path
	if path[path.size() - 1].distance_to(at) < 3.0:
		pts = PackedVector2Array()
		for i in range(path.size() - 1, -1, -1):
			pts.append(path[i])
	elif path[0].distance_to(at) > 3.0:
		return PackedVector2Array()
	var out := PackedVector2Array()
	for q in pts:
		out.append(q)
		if q.distance_to(at) > reach_m:
			break
	return out


## The way a street leaves `at` (its bearing 18 m out).
static func _heading(st: PackedVector2Array, at: Vector2) -> float:
	for q in st:
		if q.distance_to(at) >= 18.0:
			return (q - at).angle()
	return (st[st.size() - 1] - at).angle()


## [the bearing furthest from every one in `dirs` and at least `off` from `avoid`, that distance].
func _free_angle(avoid: float, off: float) -> Array:
	var best := [0.0, -1.0]
	var k0 := rng.randi() % 72
	for k in range(72):
		var a := TAU * ((k + k0) % 72) / 72.0
		if absf(angle_difference(a, avoid)) < off:
			continue
		var gap := PI
		for d in dirs:
			gap = minf(gap, absf(angle_difference(a, float(d))))
		if gap > best[1] + 0.001:
			best = [a, gap]
	return best


## A market off the plaza in the widest gap between the streets, `r` out.
func _market_off(r: float, kinds: Array, clear_r: float) -> void:
	var a: float = _free_angle(dock_a, deg_to_rad(40.0))[0]
	var mc := c + Vector2.from_angle(a) * r
	market = {"c": mc, "kinds": kinds, "toward": c, "seed": rng.randi()}
	dirs.append(a)
	occ.append([mc, clear_r])
	clear.append([mc, clear_r + 1.0])


## Up to n lanes out from the plaza in the gaps between the streets (each a new path).
func _lanes(n: int) -> void:
	for k in range(n):
		var best: Array = _free_angle(dock_a, deg_to_rad(55.0))
		if best[1] < deg_to_rad(30.0):
			return
		dirs.append(best[0])
		var ctrl := _lane(best[0])
		if ctrl.is_empty():
			continue
		gi._add_path(ctrl, LANE_HW)
		var pts: PackedVector2Array = gi.paths[gi.paths.size() - 1]
		lanes.append(pts)
		streets.append(pts)
		widths.append(LANE_HW)
		reach.append(0.0)


## A lane's control points out along bearing `a` from the plaza's edge, as far as the
## land allows (44-62 m, a little bend); empty when there's under 24 m of it.
func _lane(a: float) -> Array:
	var u := Vector2.from_angle(a)
	var n := Vector2(-u.y, u.x)
	var length := rng.randf_range(44.0, 62.0)
	var bend := rng.randf_range(-8.0, 8.0)
	var r0 := 12.0
	var got_to := r0
	var dd := r0
	while dd <= r0 + length:
		if not _open_ground(c + u * dd + n * bend * pow((dd - r0) / length, 2.0)):
			break
		got_to = dd
		dd += 2.0
	var got := got_to - r0
	if got < 24.0:
		return []
	return [c + u * (r0 - 2.0), c + u * (r0 + got * 0.5) + n * bend * 0.25 * pow(got / length, 2.0), c + u * got_to + n * bend * pow(got / length, 2.0)]


## Ground the village may spread over: land, clear of the harbour and the other sites
## and (out past the village site's own clearing) of anything reserved.
func _open_ground(q: Vector2) -> bool:
	if kc.hv(q) < 2.0 or q.distance_to(dock) < 38.0:
		return false
	for s in ["boss", "camp", "lair", "ruins", "summit"]:
		if q.distance_to(gi.sites[s]) < 45.0:
			return false
	return q.distance_to(site) < 34.0 or not gi.excluded(q, 1.5)


## [w, d, ext] for a building of `kind` (huts, tall houses and ruins vary).
func _size(kind: String) -> Array:
	var s: Array = SIZE[kind]
	if kind == "hut" or kind == "tall" or kind == "ruin":
		return [snappedf(s[0] + rng.randf_range(-0.6, 0.8), 0.1), snappedf(s[1] + rng.randf_range(-0.5, 0.5), 0.1), s[2]]
	return s


## Takes the plot at p for a `kind` (door toward `face`) if it's clear (by `gap` of everything taken): into `blds` and `occ`.
func _take(kind: String, p: Vector2, face: Vector2, sz: Array = [], gap := 1.0) -> bool:
	var s: Array = sz if not sz.is_empty() else _size(kind)
	var f := face.normalized()
	if not KitVillage.plot_clear(kc, occ, p, f, s[0], s[1], s[2], 0.6, gap) or not _open_ground(p) or not _open_ground(p + f * (s[1] * 0.5 + s[2])):
		return false
	blds.append({"kind": kind, "p": p, "face": f, "w": s[0], "d": s[1], "ext": s[2], "seed": rng.randi()})
	occ.append_array(KitVillage.plot_circles(p, f, s[0], s[1], s[2]))
	return true


## A `kind` on a ring round the heart at radius r, facing in, as near bearing `a` as there's room (within `spread`).
func _ring(kind: String, a: float, r: float, spread: float) -> bool:
	var k := 0
	while k * deg_to_rad(4.0) <= spread:
		for sg in ([1.0] if k == 0 else [1.0, -1.0]):
			var p := c + Vector2.from_angle(a + float(sg) * k * deg_to_rad(4.0)) * r
			if _take(kind, p, c - p):
				return true
		k += 1
	return false


## The inn across from the road in, the store and the cookhouse either side of it, the elder's house.
## Each goes further out until it finds room: every village with people must have all four.
func _services(r: float) -> void:
	var flip := 1.0 if rng.randf() < 0.5 else -1.0
	for e in [["inn", (-to_dock).angle(), r + 5.0], ["trade", dock_a + flip * deg_to_rad(58.0), r + 0.5],
			["cook", dock_a - flip * deg_to_rad(58.0), r + 0.5], ["elder", dock_a + flip * deg_to_rad(140.0), r + 0.5]]:
		var k := 0
		while not _ring(e[0], e[1], float(e[2]) + k * 2.5, PI):
			k += 1
			if k > 10:
				push_error("VillageLayouts: no room for the %s round %s (island seed %d, %s)" % [e[0], c, int(gi.node["seed"]), layout])
				break


## Up to n more houses (`kind`, or huts and a `tall` share of tall houses) round the heart at about r, `gap` apart.
func _ring_fill(n: int, r: float, kind := "", tall := 0.3, gap := 1.0) -> void:
	var a0 := rng.randf() * TAU
	var got := 0
	for k in range(72):
		if got >= n:
			return
		var a := a0 + k * TAU / 72.0
		var kd := kind if kind != "" else ("tall" if rng.randf() < tall else "hut")
		var p := c + Vector2.from_angle(a) * (r + rng.randf_range(-0.3, 1.2))
		if _take(kd, p, c - p, [], gap):
			got += 1


## The shrine where the longest lane ends, facing back along it.
func _shrine_at_lane_end() -> bool:
	if lanes.is_empty():
		return false
	var longest: PackedVector2Array = lanes[0]
	for l in lanes:
		if KitVillage.along(l, 1.0).size() > KitVillage.along(longest, 1.0).size():
			longest = l
	var t := (longest[longest.size() - 1] - longest[longest.size() - 2]).normalized()
	return _take("shrine", longest[longest.size() - 1] + t * 5.5, -t)


## Houses along both sides of every street from `start` m out (lanes first), from `queue`, at most `per` a street,
## [gap_lo, gap_hi] m between neighbours along it, `gap` clear of everything else.
func _street_houses(queue: Array, start: float, per := PER_STREET, gap_lo := 1.5, gap_hi := 4.5, gap := 1.0) -> void:
	for i in range(queue.size() - 1, 4, -1):
		var j := rng.randi_range(4, i)
		var tmp = queue[i]
		queue[i] = queue[j]
		queue[j] = tmp
	var order: Array = range(streets.size() - lanes.size(), streets.size()) + range(streets.size() - lanes.size())
	for si in order:
		var got := 0
		var nexts := {1.0: start + 1.0 + rng.randf() * 3.0, -1.0: start + 1.0 + rng.randf() * 3.0}
		for e in KitVillage.along(streets[si], 1.0, start):
			for side in [1.0, -1.0]:
				if queue.is_empty() or got >= per or e[2] < nexts[side]:
					continue
				var kind: String = queue[0]
				var sz := _size(kind)
				var t: Vector2 = e[1]
				var nrm := Vector2(-t.y, t.x) * float(side)
				var p: Vector2 = e[0] + nrm * (float(widths[si]) + 1.0 + sz[2] + sz[1] * 0.5)
				if _take(kind, p, -nrm, sz, gap):
					queue.pop_front()
					got += 1
					reach[si] = e[2] + sz[0] * 0.5
					nexts[side] = e[2] + sz[0] + rng.randf_range(gap_lo, gap_hi)
				else:
					nexts[side] = e[2] + 1.0


## The job board beside the way in at q (whichever side of the road has room), or
## further out round q until it fits.
func _board_near(q: Vector2) -> void:
	var t := (q - c).normalized()
	var s := Vector2(-t.y, t.x)
	var cands: Array = []
	for i in range(24):
		var sd := -1.0 if i % 2 == 0 else 1.0
		var k := (i / 2) % 4
		var along: float = [0.0, 2.5, -2.5][i / 8]
		cands.append(q + t * along + s * sd * (3.0 + k * 0.8))
	for ring in range(1, 13):
		for k in range(16):
			cands.append(q + Vector2.from_angle(t.angle() + PI * 0.5 + k * TAU / 16.0) * (3.0 + ring * 1.2))
	for bq in cands:
		if KitVillage._spot(kc, occ, bq, 1.2, 0.5):
			board = {"p": bq, "face": c - bq}
			if heart_y != INF and bq.distance_to(c) < DECK_R - 1.0:
				board["y"] = heart_y
			occ.append([bq, 1.2])
			return
	push_error("VillageLayouts: no room for the job board near %s (island seed %d, %s)" % [q, int(gi.node["seed"]), layout])


## Round the heart: benches round the fire, a well, lamps, planters, a signpost and the
## job board by the road in, bunting on a ring (`bunting_r` 0: none).
func _plaza(well: bool, lamps: int, bunting_r: float) -> void:
	_board_near(c + to_dock * (plaza_r - 1.5))
	for k in range(4):
		var bp := c + Vector2.from_angle(PI * 0.25 + k * TAU / 4.0 + dock_a) * minf(5.2, plaza_r - 2.0)
		KitVillage.plan_put(kc, items, occ, "bench", bp, KitContext.face_yaw(c - bp), 1.0)
	if well:
		for k in range(12):
			var wp := c + Vector2.from_angle(dock_a + PI * 0.5 + k * TAU / 12.0) * minf(8.0, plaza_r - 1.0)
			if KitVillage.plan_put(kc, items, occ, "well", wp, KitContext.face_yaw(c - wp), 1.7, {"spot": {"at": wp + (c - wp).normalized() * 1.7, "face": wp - c}}):
				break
	var lit := 0
	for k in range(16):
		if lit >= lamps:
			break
		var lp := c + Vector2.from_angle(dock_a + PI * 0.2 + k * TAU / 16.0) * (plaza_r - 1.6)
		if KitVillage.plan_put(kc, items, occ, "lamp", lp, KitContext.face_yaw(c - lp) - PI * 0.5, 0.6, {"lit": true}):
			lit += 1
	for k in range(6):
		var pp := c + Vector2.from_angle(dock_a + 0.4 + k * TAU / 6.0) * (plaza_r - 3.2)
		KitVillage.plan_put(kc, items, occ, "planter", pp, 0.0, 0.9, {"r": 0.7})
	var arrows: Array = []
	for a in dirs.slice(0, 4):
		arrows.append(atan2(-sin(a), cos(a)))
	var side := Vector2(-to_dock.y, to_dock.x)
	for s in [1.0, -1.0]:
		if KitVillage.plan_put(kc, items, occ, "sign", c + to_dock * (plaza_r - 3.5) + side * float(s) * 2.6, 0.0, 0.5, {"arrows": arrows}):
			break
	if bunting_r > 0.0:
		bunting = KitVillage.plan_bunting_ring(kc, occ, c, bunting_r, 10)


## A lamp at the market's mouth, a line of bunting across it.
func _market_dressing() -> void:
	var mc: Vector2 = market["c"]
	var out := (mc - c).normalized()
	var ms := Vector2(-out.y, out.x)
	var lp := mc - out * 6.2 + ms * 4.6
	KitVillage.plan_put(kc, items, occ, "lamp", lp, KitContext.face_yaw(mc - lp) - PI * 0.5, 0.5, {"lit": true})
	var poles: Array = []
	for s in [-1.0, 1.0]:
		var q: Vector2 = mc + ms * float(s) * 6.9 - out * 1.5
		if kc.path_dist(q) > 1.0 and kc.hv(q) > 1.2:
			poles.append(q)
	market["poles"] = poles


## Every building's own dressing: tables at the inn, cargo at the shops, planters at the shrine, the rest a yard.
func _dress_buildings() -> void:
	for b in blds:
		if b.has("dressed"):
			continue
		b["dressed"] = true
		var p: Vector2 = b["p"]
		var f: Vector2 = b["face"]
		var s := Vector2(-f.y, f.x)
		var brng := KitVillage._seeded(int(b["seed"]) + 7)
		var front: float = float(b["d"]) * 0.5 + float(b["ext"])
		match str(b["kind"]):
			"inn":
				if b.has("raised"):
					continue
				for sd in [-1.0, 1.0]:
					KitVillage.plan_put(kc, items, occ, "table", p + f * (front - 0.6) + s * float(sd) * 4.0, KitContext.face_yaw(s), 1.5)
				var kq := p + s * (float(b["w"]) * 0.5 + 1.0)
				if KitVillage._spot(kc, occ, kq, 1.0):
					KitVillage.plan_cargo(kc, items, kq, KitContext.face_yaw(f), brng, "barrel")
					occ.append([kq, 1.0])
			"trade", "cook":
				var cq := p + f * (front - 1.2) + s * 2.4
				if KitVillage._spot(kc, occ, cq, 0.9):
					KitVillage.plan_cargo(kc, items, cq, KitContext.face_yaw(f), brng, "crate" if b["kind"] == "trade" else "basket")
					occ.append([cq, 0.9])
				if b["kind"] == "cook" and not b.has("raised"):
					KitVillage.plan_put(kc, items, occ, "table", p + f * (front - 0.4) - s * 3.4, KitContext.face_yaw(s), 1.5)
				KitVillage.plan_yard(kc, items, occ, p, f, float(b["w"]), float(b["d"]), front, brng)
			"shrine", "hall":
				for sd in [-1.0, 1.0]:
					KitVillage.plan_put(kc, items, occ, "planter", p + f * (front + 0.4) + s * float(sd) * 2.6, 0.0, 0.8, {"r": 0.55})
			"ruin", "minaret":
				pass
			_:
				KitVillage.plan_yard(kc, items, occ, p, f, float(b["w"]), float(b["d"]), front, brng)
		if float(kc.style["yard_fences"]) > 0.0 and ["hut", "tall", "home", "elder"].has(str(b["kind"])) and not b.has("raised"):
			_yard_fences(b, float(kc.style["yard_fences"]))


## A run of fence along each side wall of b's yard (back corner to front corner, a little out from the wall) where
## there's room, each side at `chance` (its own stream: the yard's draws don't move).
func _yard_fences(b: Dictionary, chance: float) -> void:
	var frng := KitVillage._seeded(int(b["seed"]) + 13)
	var f: Vector2 = (b["face"] as Vector2).normalized()
	var s := Vector2(-f.y, f.x)
	for sd in [-1.0, 1.0]:
		if frng.randf() >= chance:
			continue
		var a: Vector2 = b["p"] + s * float(sd) * (float(b["w"]) * 0.5 + 0.8) - f * (float(b["d"]) * 0.5 + 0.6)
		var pts := [a, a + f * 2.2, a + f * 4.4]
		if pts.all(func(q): return KitVillage._spot(kc, occ, q, 0.35)):
			items.append({"k": "fence", "p": a, "yaw": KitContext.face_yaw(f), "len": 4.4})
			for q in pts:
				occ.append([q, 0.35])


## Along every street with houses on it, from `from` m out to just past its last house.
func _dress_streets(from: float) -> void:
	for si in range(streets.size()):
		KitVillage.plan_lane(kc, items, occ, streets[si], float(widths[si]), KitVillage._seeded(rng.randi()), 8.0, from, maxf(float(reach[si]) + 6.0, from + 10.0))


## Trodden earth in front of every door (not over the paths or the cobbles).
func _worn_fronts(prng: RandomNumberGenerator) -> void:
	kc.paved = func(q: Vector2) -> bool:
		if kc.path_dist(q) < 0.2 or q.distance_to(c) < plaza_r - 0.4:
			return true
		return not market.is_empty() and q.distance_to(market["c"]) < 7.9
	for b in blds:
		if b.has("raised") or b.has("worn"):
			continue
		b["worn"] = true
		var f: Vector2 = b["face"]
		KitPaving.plan_disk(kc, worn, b["p"] + f * (float(b["d"]) * 0.5 + float(b["ext"]) * 0.5), maxf(float(b["ext"]) * 0.5, 1.0) + 2.0, prng)


## How far a raised building's front reaches past its wall (the walkway meets it there).
static func _deck_ext(kind: String) -> float:
	match kind:
		"trade", "cook", "home", "elder":
			return 1.5
		"inn":
			return 2.0
	return 1.2


## What the village takes is kept clear of the plants: its buildings and their yards,
## every dressed thing, the streets' sides as far as their houses, its clearings.
func _reserve() -> void:
	for b in blds:
		for e in KitVillage.plot_circles(b["p"], b["face"], b["w"], b["d"], b["ext"]):
			gi.reserve(e[0], float(e[1]) + 2.5)
	for it in items:
		gi.reserve(it["p"], 1.6)
	for si in range(streets.size()):
		for e in KitVillage.along(streets[si], 4.0, 6.0, float(reach[si]) + 6.0):
			var t: Vector2 = e[1]
			for s in [-1.0, 1.0]:
				gi.reserve(e[0] + Vector2(-t.y, t.x) * float(s) * (float(widths[si]) + 2.5), 2.5)
	for cl in clear:
		gi.reserve_area(cl[0], cl[1])
	if not market.is_empty():
		gi.reserve_area(market["c"], 10.0)
	for w in extra.get("walks", []):
		for k in range(int(w["a"].distance_to(w["b"]) / 3.0) + 1):
			gi.reserve(w["a"].lerp(w["b"], k / maxf(w["a"].distance_to(w["b"]) / 3.0, 1.0)), 2.5)
