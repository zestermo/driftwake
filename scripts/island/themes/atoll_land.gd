extends RefCounted
## The coral atoll's own land (AtollTheme.plan_land / shape / site_at / route; docs/v1_28_plan.md "Islands"): the base
## island's coast becomes the sea edge of a ring of low islets and sandbars round a calm, shallow lagoon. Along the ring
## islets (palm-grown humps of coral sand) alternate with sandbars you wade along, cut here and there by a pass where the
## sea runs in (a short swim); outside it a reef flat, then the drop-off to the open sea's floor; inside, the lagoon's
## pale floor two or three metres down with coral heads reaching up toward the surface and, somewhere, a blue hole.
## The sites go on the ring; the boss's tidal flat stands in the lagoon, a causeway of sandbar wading out to it from the
## village. Plan and shape are numbers only (the worker).

const D := preload("res://scripts/island/themes/atoll_data.gd")
const SHOALS := preload("res://scripts/island/themes/atoll_shoals.gd")


static func plan(isl, rng: RandomNumberGenerator) -> Dictionary:
	var lp := {}
	lp["w"] = rng.randf_range(D.RING_W[0], D.RING_W[1])
	lp["wob"] = [float(rng.randi_range(2, 4)), rng.randf() * TAU]
	var n := rng.randi_range(D.ISLETS[0], D.ISLETS[1])
	lp["islets"] = [float(n), rng.randf() * TAU, float(n + rng.randi_range(3, 6)), rng.randf() * TAU]
	lp["crest"] = rng.randf_range(D.ISLET_H[0], D.ISLET_H[1])
	var passes: Array = []
	var a0 := rng.randf() * TAU
	var np := rng.randi_range(D.PASSES[0], D.PASSES[1])
	for k in range(np):
		passes.append(a0 + TAU * k / np + rng.randf_range(-0.4, 0.4))
	lp["passes"] = passes
	lp["lagoon_y"] = rng.randf_range(D.LAGOON_Y[1], D.LAGOON_Y[0])
	var floor_n := FastNoiseLite.new()
	floor_n.seed = rng.randi()
	floor_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	floor_n.frequency = 0.012
	floor_n.fractal_octaves = 2
	lp["floor"] = floor_n
	var heads := FastNoiseLite.new()
	heads.seed = rng.randi()
	heads.noise_type = FastNoiseLite.TYPE_CELLULAR
	heads.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	heads.frequency = 0.035
	lp["heads"] = heads
	var heads_d := FastNoiseLite.new()
	heads_d.seed = heads.seed
	heads_d.noise_type = FastNoiseLite.TYPE_CELLULAR
	heads_d.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	heads_d.frequency = 0.035
	lp["heads_d"] = heads_d
	lp["hole_r"] = rng.randf_range(D.HOLE_R[0], D.HOLE_R[1])
	lp["hole_y"] = rng.randf_range(D.HOLE_Y[1], D.HOLE_Y[0])
	lp["hole_out"] = rng.randf_range(D.HOLE_OUT[0], D.HOLE_OUT[1])
	lp["hole_turn"] = rng.randf_range(1.1, 1.7) * (1.0 if rng.randf() < 0.5 else -1.0)
	lp["side"] = 1.0 if rng.randf() < 0.5 else -1.0
	var gaps: Array = []
	for k in range(rng.randi_range(D.CAUSEWAY_GAPS[0], D.CAUSEWAY_GAPS[1])):
		gaps.append(rng.randf_range(0.3 + k * 0.3, 0.45 + k * 0.3))
	lp["gaps"] = gaps
	var motu: Array = []
	var m0 := rng.randf() * TAU
	var nm := rng.randi_range(D.MOTU[0], D.MOTU[1])
	for k in range(nm):
		var a := m0 + TAU * k / nm + rng.randf_range(-0.5, 0.5)
		var mr: Array = D.MOTU_BIG if k == 0 else D.MOTU_R
		motu.append([Vector2.from_angle(a) * float(isl.radius) * rng.randf_range(D.MOTU_OUT[0], D.MOTU_OUT[1]), rng.randf_range(mr[0], mr[1]),
			rng.randf_range(D.ISLET_H[0], D.ISLET_H[1]) + 0.4])
	lp["motu"] = motu
	return lp


## The ring's width at bearing a.
static func ring_w(lp: Dictionary, a: float) -> float:
	var wob: Array = lp["wob"]
	return float(lp["w"]) * (1.0 + D.RING_WOBBLE * sin(float(wob[0]) * a + float(wob[1])))


## 0..1: how much of the ring at bearing a is islet (the rest sandbar).
static func islet_at(lp: Dictionary, a: float) -> float:
	var s: Array = lp["islets"]
	var m := 0.5 + 0.32 * sin(float(s[0]) * a + float(s[1])) + 0.18 * sin(float(s[2]) * a + float(s[3]))
	return smoothstep(D.ISLET_AT - 0.06, D.ISLET_AT + 0.06, m)


## 0..1: how much bearing a is in a pass through the ring (none near the dock or the village).
static func pass_at(isl, lp: Dictionary, a: float) -> float:
	var k := 0.0
	for pa in lp["passes"]:
		var off := absf(angle_difference(a, float(pa)))
		if off > D.PASS_HALF * 2.0:
			continue
		var clear := true
		for s in ["dock", "village"]:
			if isl.sites.has(s) and absf(angle_difference(float(pa), (isl.sites[s] as Vector2).angle())) < 0.45:
				clear = false
		if clear:
			k = maxf(k, 1.0 - smoothstep(D.PASS_HALF, D.PASS_HALF * 2.0, off))
	return k


## The lagoon's floor at p (the floor's swell, coral heads reaching up).
static func lagoon_y(lp: Dictionary, p: Vector2) -> float:
	var y: float = float(lp["lagoon_y"]) + (lp["floor"] as FastNoiseLite).get_noise_2d(p.x, p.y) * 0.3
	var hv: float = (lp["heads"] as FastNoiseLite).get_noise_2d(p.x, p.y) * 0.5 + 0.5
	if hv > D.HEADS_AT:
		var core := 1.0 - smoothstep(0.08, 0.5, (lp["heads_d"] as FastNoiseLite).get_noise_2d(p.x, p.y) + 1.0)
		y = lerpf(y, D.HEADS_Y, core * smoothstep(D.HEADS_AT, D.HEADS_AT + 0.1, hv))
	return y


## Is p on a coral head (spear-diving ground)?
static func on_head(lp: Dictionary, p: Vector2) -> bool:
	return lagoon_y(lp, p) > D.HEADS_Y - 0.6


## The ring's height across its band at bearing a, `u` of the way in (0 the sea's edge, 1 the lagoon's).
static func _ring_y(isl, lp: Dictionary, a: float, u: float) -> float:
	var hump := sin(PI * clampf(u, 0.0, 1.0))
	var islet := 0.45 + float(lp["crest"]) * pow(hump, 0.7)
	var bar := D.BAR_Y + D.BAR_CREST * hump
	var y := lerpf(bar, islet, islet_at(lp, a))
	return lerpf(y, D.PASS_Y, pass_at(isl, lp, a))


static func shape(isl, p: Vector2, h: float) -> float:
	# (the dock's search runs on the base land: its coast is the ring's sea edge)
	if not isl.sites.has("dock"):
		return h
	var lp: Dictionary = isl.land_plan
	var t: float = isl._coast_t(p)
	var a := atan2(p.y, p.x)
	var w := ring_w(lp, a)
	var s: float
	if t >= 0.0:
		var reef := lerpf(_ring_y(isl, lp, a, 0.0), D.REEF_Y, smoothstep(0.0, 4.0, t))
		s = lerpf(h, lerpf(reef, GenIsland.SEAFLOOR, smoothstep(D.REEF_FLAT, D.REEF_FLAT + D.DROP, t)), isl._shelf_room(p))
		return s
	s = lerpf(_ring_y(isl, lp, a, -t / w), lagoon_y(lp, p), smoothstep(w, w + D.LAGOON_EDGE, -t))
	if lp.has("causeway"):
		s = _causeway(lp, p, s)
	if isl.sites.has("village"):
		var vd := p.distance_to(isl.sites["village"])
		if vd < D.VILLAGE_R * 1.2:
			s = maxf(s, lerpf(s, D.VILLAGE_Y, 1.0 - smoothstep(D.VILLAGE_R * 0.55, D.VILLAGE_R * 1.15, vd)))
	for mo in lp["motu"]:
		var d := p.distance_to(mo[0])
		var r: float = mo[1]
		if d < r * 1.2:
			s = maxf(s, lerpf(s, float(mo[2]), 1.0 - smoothstep(r * 0.45, r * 1.15, d)))
	if lp.has("hole"):
		s = basin_y(lp, p, s)
	return s


## The deep basin's rim radius at bearing a from its middle (wobbling).
static func basin_r(lp: Dictionary, a: float) -> float:
	var hole: Array = lp["hole"]
	var w: Array = lp["basin_wob"]
	return float(hole[1]) * (1.0 + D.BASIN_WOB * sin(3.0 * a + float(w[0])) + D.BASIN_WOB * 0.5 * sin(5.0 * a + float(w[1])))


## The deep basin over the lagoon floor s: a reef crest round its lip, the upper wall down to a ledge, the lower wall
## to its rolling floor.
static func basin_y(lp: Dictionary, p: Vector2, s: float) -> float:
	var hole: Array = lp["hole"]
	var off: Vector2 = p - (hole[0] as Vector2)
	var d := off.length()
	if d > float(hole[1]) * (1.0 + D.BASIN_WOB * 1.5) + D.BASIN_RIM + 2.0:
		return s
	var r := basin_r(lp, off.angle())
	var u := d / r
	var fy: float = hole[2]
	var crest := 1.0 - smoothstep(0.0, D.BASIN_RIM, absf(d - r - 2.0))
	if u >= 0.97:
		s = maxf(s, lerpf(s, D.BASIN_CREST, crest))
	var ledge := lerpf(D.BASIN_CREST, fy, D.LEDGE_K)
	var y: float
	if u > D.LEDGE[1]:
		y = lerpf(ledge, D.BASIN_CREST, smoothstep(D.LEDGE[1], 1.0, u))
	elif u > D.LEDGE[0]:
		y = lerpf(ledge - 2.5, ledge, smoothstep(D.LEDGE[0], D.LEDGE[1], u))
	elif u > D.FLOOR_U:
		y = lerpf(fy, ledge - 2.5, smoothstep(D.FLOOR_U, D.LEDGE[0], u))
	else:
		y = fy + (lp["floor"] as FastNoiseLite).get_noise_2d(p.x * 2.5, p.y * 2.5) * D.BASIN_ROLL
	return minf(s, y)


## Where the basin's ledge runs (u of the rim's radius) and its depth.
static func basin_ledge(lp: Dictionary) -> Vector2:
	return Vector2((D.LEDGE[0] + D.LEDGE[1]) * 0.5, lerpf(D.BASIN_CREST, float(lp["hole"][2]), D.LEDGE_K) - 1.2)


## The causeway's sandbar from the village to the boss's flat, with a swim or two across it.
static func _causeway(lp: Dictionary, p: Vector2, s: float) -> float:
	var cw: Array = lp["causeway"]
	var a: Vector2 = cw[0]
	var ab: Vector2 = (cw[1] as Vector2) - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var d := p.distance_to(a + ab * t)
	if d > D.CAUSEWAY_HW + 6.0:
		return s
	var crest := D.BAR_Y + D.BAR_CREST * (1.0 - smoothstep(0.0, D.CAUSEWAY_HW, d))
	for g in lp["gaps"]:
		var gd := absf(t - float(g)) * ab.length()
		crest = lerpf(-1.9, crest, smoothstep(D.CAUSEWAY_GAP * 0.6, D.CAUSEWAY_GAP + 2.0, gd))
	return maxf(s, lerpf(crest, s, smoothstep(D.CAUSEWAY_HW, D.CAUSEWAY_HW + 6.0, d)))


## [the sea's edge, the lagoon's edge] along bearing a (m from the island's middle).
static func ring_r(isl, a: float) -> Array:
	var lp: Dictionary = isl.land_plan
	var dir := Vector2.from_angle(a)
	var w := ring_w(lp, a)
	var r: float = isl.radius + 40.0
	while r > 10.0 and isl._coast_t(dir * r) > 0.0:
		r -= 2.0
	var r0 := r
	while r > 10.0 and isl._coast_t(dir * r) > -w:
		r -= 2.0
	return [r0, r]


## The island point on the ring at bearing a, `u` of the way across it (0 the sea's edge, 1 the lagoon's).
static func ring_point(isl, a: float, u: float) -> Vector2:
	var rr := ring_r(isl, a)
	return Vector2.from_angle(a) * lerpf(rr[0], rr[1], u)


## The village on the ring beside the dock, toward the lagoon (its stilt town walks out over the water from there).
static func village_at(isl, _p: Vector2) -> Vector2:
	var lp: Dictionary = isl.land_plan
	return ring_point(isl, (isl.sites["dock"] as Vector2).angle() + D.VILLAGE_TURN * float(lp["side"]), D.VILLAGE_U)


## The boss's tidal flat in the lagoon away from the village (the causeway and the blue hole planned with it); the
## summit on the ring's broadest islet; the camp, the lair and the ruins on the ring at their bearings.
static func site_at(isl, site: String, p: Vector2) -> Vector2:
	var lp: Dictionary = isl.land_plan
	var v: Vector2 = isl.sites["village"]
	var va := v.angle()
	match site:
		"boss":
			var far := ring_r(isl, va + PI)[1] as float
			var b := -v.normalized() * far * D.BOSS_OUT
			lp["causeway"] = [ring_point(isl, va, 1.0), b]
			_plan_basin(isl, lp, v, b)
			var hole: Array = lp["hole"]
			for mo in lp["motu"]:
				for k in range(16):
					var c: Vector2 = mo[0]
					var cw: Array = lp["causeway"]
					var ab: Vector2 = (cw[1] as Vector2) - (cw[0] as Vector2)
					var t := clampf((c - (cw[0] as Vector2)).dot(ab) / ab.length_squared(), 0.0, 1.0)
					var clear: bool = c.distance_to(v) > D.MOTU_KEEP and c.distance_to((cw[0] as Vector2) + ab * t) > float(mo[1]) + 14.0 \
						and c.distance_to(b) > float(mo[1]) + 45.0 and c.distance_to(hole[0]) > float(mo[1]) + float(hole[1]) * 1.15 + D.BASIN_RIM + 8.0
					if clear:
						break
					mo[0] = c.rotated(0.45)
			return b
		"cave":
			# (a lagoon islet's: the ring's islets are narrow and the paths run along them)
			var mo: Array = lp["motu"][absi(int(p.x * 7.0 + p.y * 13.0)) % (lp["motu"] as Array).size()]
			return (mo[0] as Vector2) + (p - (mo[0] as Vector2)).normalized() * float(mo[1]) * 0.15
		"summit":
			var best := va + PI
			var best_k := -1.0
			for k in range(72):
				var a := TAU * k / 72.0
				if absf(angle_difference(a, va)) < 0.5:
					continue
				var m := islet_at(lp, a) - pass_at(isl, lp, a) + 0.001 * cos(a - va - PI)
				if m > best_k:
					best_k = m
					best = a
			return ring_point(isl, best, 0.5)
		"camp", "lair", "ruins":
			var a := p.angle()
			if absf(angle_difference(a, va)) < 0.4:
				a = va + (0.6 if angle_difference(va, a) < 0.0 else -0.6)
			for k in range(8):
				if pass_at(isl, lp, a) <= 0.0:
					break
				a += D.PASS_HALF * 2.0
			return ring_point(isl, a, 0.5)
	return p


## The deep basin (land "hole"): beside the causeway near the lagoon's middle, its rim BASIN_OFF m clear of the
## causeway's crest, away from the village and the boss's flat, all of it inside the lagoon (smaller until it fits).
static func _plan_basin(isl, lp: Dictionary, v: Vector2, b: Vector2) -> void:
	var cw: Array = lp["causeway"]
	var a0: Vector2 = cw[0]
	var ab: Vector2 = (cw[1] as Vector2) - a0
	var n := ab.normalized().orthogonal()
	var r := float(lp["hole_r"])
	var brng := RandomNumberGenerator.new()
	brng.seed = hash([float(lp["hole_r"]), float(lp["hole_turn"]), "basin"])
	lp["basin_wob"] = [brng.randf() * TAU, brng.randf() * TAU]
	var best := Vector2.ZERO
	for shrink in range(8):
		var reach := r * (1.0 + D.BASIN_WOB * 1.5) + D.BASIN_RIM
		for side in [float(lp["side"]), -float(lp["side"])]:
			for t in [0.55, 0.45, 0.65, 0.35, 0.75]:
				var c: Vector2 = a0 + ab * t + n * side * (reach + D.CAUSEWAY_HW + D.BASIN_OFF)
				var inner: float = ring_r(isl, c.angle())[1]
				if c.length() + reach < inner - 8.0 and c.distance_to(v) > reach + D.VILLAGE_R + D.BASIN_KEEP \
						and c.distance_to(b) > reach + D.BASIN_KEEP:
					lp["hole"] = [c, r, float(lp["hole_y"])]
					return
				if best == Vector2.ZERO:
					best = c
		r *= 0.9
	lp["hole"] = [best, r, float(lp["hole_y"])]


## The paths: along the ring from the village round to each site on it (wading the sandbars, swimming a pass), straight
## down the causeway to the boss's flat. `pts` the base's (kept for the dock road).
static func route(isl, site: String, pts: Array) -> Array:
	var v: Vector2 = isl.sites["village"]
	match site:
		"dock":
			return pts
		"boss":
			var cw: Array = isl.land_plan["causeway"]
			return [v, cw[0], (cw[0] as Vector2).lerp(cw[1], 0.5), cw[1]]
	var to: Vector2 = isl.sites[site]
	var a0 := v.angle()
	var span := angle_difference(a0, to.angle())
	var r_mid := (ring_r(isl, a0)[0] as float) * 0.95
	var n := maxi(int(absf(span) * r_mid / 28.0), 2)
	var out: Array = [v]
	for k in range(1, n):
		out.append(ring_point(isl, a0 + span * k / n, 0.5))
	out.append(to)
	return out


## Plants only on the islets (and the land kept round the sites): none on the sandbars or in the lagoon.
static func cover(isl, p: Vector2, c: float) -> float:
	return c * smoothstep(1.0, 2.0, float(isl.hv(p)))


## [plants, rocks]: palms and scrub where it's dry; a little coral rubble on the sandbars, none in the lagoon.
static func growth(isl, p: Vector2) -> Vector2:
	var h: float = isl.hv(p)
	return Vector2(smoothstep(0.6, 1.3, h), lerpf(0.25, 1.0, smoothstep(0.0, 1.0, h)))


## Coral sand everywhere low; worn rock round the islets' sea faces; nothing trodden under the water. The alpha is the
## seabed's kind (PSXMat.terrain's "deep"): the lagoon's and the reef's pale sand, going over to the open sea's dark
## floor down the drop-off outside the ring (so the island's square of seabed meets the sea's without a line).
static func paint(isl, p: Vector2, h: float, splat: Color) -> Color:
	var t: float = isl._coast_t(p)
	splat.a = 1.0 - smoothstep(D.REEF_FLAT + D.DROP * 0.35, D.REEF_FLAT + D.DROP * 1.6, t)
	if h < 0.25:
		splat.r = 0.0
		splat.g = 0.0
		splat.b = 1.0
		return splat
	if t > -8.0 and t < 2.0:
		var rock := (1.0 - smoothstep(0.0, 8.0, -t)) * islet_at(isl.land_plan, atan2(p.y, p.x)) * 0.65
		splat.g = maxf(splat.g, rock * (1.0 - splat.r))
	return splat


static func steps(isl) -> Array:
	return [["atoll spots", func(): AtollSpots.build(isl)], ["atoll shoals", func(): SHOALS.build(isl)],
		["atoll reef", func(): await load("res://scripts/island/themes/atoll_reef.gd").build(isl)], ["atoll water", func(): _water(isl)]] \
		+ load("res://scripts/island/themes/atoll_basin.gd").steps(isl) \
		+ [["atoll harvest", func(): await load("res://scripts/island/themes/atoll_reef.gd").harvest(isl)],
			["atoll deep life", func(): load("res://scripts/island/themes/atoll_deeplife.gd").build(isl)]] \
		+ load("res://scripts/island/themes/atoll_seabed.gd").steps(isl)


## The lagoon's clear water (atoll_water.gd): a disc over it, the lagoon's edge on average.
static func _water(isl) -> void:
	var w: Node3D = load("res://scripts/island/themes/atoll_water.gd").new()
	w.name = "AtollWater"
	var r := 0.0
	for k in range(32):
		r += float(ring_r(isl, TAU * k / 32.0)[1]) / 32.0
	w.radius = r + 6.0
	isl.add_child(w)
