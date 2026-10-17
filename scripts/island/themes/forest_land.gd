extends RefCounted
## The forest island's own land (ForestTheme.plan_land / shape / steps): rolling hills over the
## base land, and rivers from the summit's flanks down to the sea in their valleys. A river's
## surface only ever falls toward the sea (worked out along it in the plan from the land it
## crosses), so where the land rises it cuts in, and where a river drops over falls it runs on in
## a gorge until the land comes down to meet it: a cross-section that is a wide valley where the
## cut is shallow and steep walls where it is deep. The lumber town stands beside a river. Steps
## lay the water (a flowing strip, the falls, a pool you swim in at their foot) and plank bridges
## where the paths cross. Plan and shape are numbers only (the worker); steps make the nodes.

## How far round a site the hills give way (m: none within the first, all past the second).
const SITE_CLEAR := [30.0, 60.0]
## The river's depth under its surface (wading), and the falls' pool's.
const BED := 0.9
const POOL_DEPTH := 2.6
## The bank's edge stands this far over the water.
const BANK := 0.35
## The lowest a river's surface runs inland (where the land is lower, its banks are raised to hold it).
const FLOOR := 1.4
## The river's distance (and its surface there) on a GRID_CELL grid, filled within GRID_BAND of it.
const GRID_CELL := 3.0
const GRID_BAND := 34.0
## Where the town stands off its river (m from the water's middle): its flats and kept land end short of it.
const TOWN_OFF := 47.0
const PLANT_PAD := 1.5
const MOUTH_CLEAR := 9.0
const VIS := 650.0


static func plan(isl, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = isl._def
	var r: float = isl.radius
	var lp := {}
	var hills := FastNoiseLite.new()
	hills.seed = rng.randi()
	hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	hills.frequency = 0.0075
	hills.fractal_octaves = 3
	lp["hills"] = hills
	lp["hill_h"] = rng.randf_range(d["roll_h"][0], d["roll_h"][1])
	var main_c: Vector2 = isl._bumps[0][0]
	# the set piece's gorge wants falls on the first river, and big ones
	var gorge := str(ForestPlaces.KINDS.get(str(isl.node.get("setpiece", "")), "")) == "forest_gorge"
	var rivers: Array = []
	# the first river runs down past the harbour's side of the island, so the town can stand on it near the dock
	var a0 := _dock_angle(isl) + rng.randf_range(0.55, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
	var n := rng.randi_range(d["rivers"][0], d["rivers"][1])
	for i in range(n):
		var dir := Vector2.from_angle(a0 + TAU * i / maxf(n, 1) + rng.randf_range(-0.4, 0.4))
		var at: Vector2 = main_c + dir * rng.randf_range(32.0, 55.0)
		var pts := PackedVector2Array([at])
		var side := Vector2(-dir.y, dir.x)
		var wob := 0.0
		while at.length() < r + 30.0 and pts.size() < 80:
			wob = clampf(wob + rng.randf_range(-0.3, 0.3), -0.55, 0.55)
			at += (dir + side * wob).normalized() * 12.0
			pts.append(at)
		var w := rng.randf_range(d["river_w"][0], d["river_w"][1]) * 0.5
		var want_falls := (gorge and i == 0) or rng.randf() < float(d["falls"])
		var drop := rng.randf_range(14.0, 19.0) if gorge and i == 0 else rng.randf_range(6.0, 11.0)
		# the land it crosses (the hills included), and the lowest its surface may run there (over the sea till the coast)
		var nat := PackedFloat32Array()
		var floor_at := PackedFloat32Array()
		for k in range(pts.size()):
			var h: float = isl._height_natural(pts[k])
			nat.append(h + _hill(lp, pts[k], h))
			floor_at.append(lerpf(FLOOR, -1.5, smoothstep(-30.0, 5.0, float(isl._coast_t(pts[k])))))
		var surf := _profile(nat, floor_at, -1, 0.0)
		# the falls: the furthest down the first half where the river can drop and still run over its floor
		var falls := -1
		if want_falls:
			for k in range(5, int(pts.size() * 0.5)):
				if surf[k - 1] - drop >= FLOOR + 2.0:
					falls = k
			# (the gorge's river always gets its falls: as big as the land there allows)
			if falls < 0 and gorge and i == 0:
				var hi := 5
				for k in range(5, maxi(int(pts.size() * 0.5), 6)):
					if surf[k - 1] > surf[hi - 1]:
						hi = k
				var room := surf[hi - 1] - FLOOR - 2.0
				if room >= 5.0:
					falls = hi
					drop = minf(drop, room)
		if falls > 0:
			surf = _profile(nat, floor_at, falls, drop)
		rivers.append({"pts": pts, "surf": surf, "w": w, "falls": falls, "drop": drop if falls > 0 else 0.0})
	lp["rivers"] = rivers
	lp["grid"] = _grid(rivers, float(isl.half))
	lp["gorge"] = gorge
	return lp


## The bearing GenIsland._plan_sites will pick for the dock (its first draws, from a copy of the island's stream:
## the gentlest stretch of coast of 24 tries), so the land can plan round it; the real dock is GenIsland's.
static func _dock_angle(isl) -> float:
	var r2 := RandomNumberGenerator.new()
	r2.seed = isl._rng.seed
	r2.state = isl._rng.state
	var best := 0.0
	var best_cl := 2.0
	for k in range(24):
		var a := r2.randf() * TAU
		var cl: float = float(isl._cliff(a)) + absf(float(isl._coast_r(a)) - float(isl.radius) * 0.8) / float(isl.radius)
		if cl < best_cl:
			best_cl = cl
			best = a
	return best


## A river's surface along its points: from a metre under the land at its source, down a little each step and a
## metre under the land it crosses, never up, never under its floor; at `falls` it drops `drop` at once.
static func _profile(nat: PackedFloat32Array, floor_at: PackedFloat32Array, falls: int, drop: float) -> PackedFloat32Array:
	var surf := PackedFloat32Array()
	var s := nat[0] - 1.0
	for k in range(nat.size()):
		if k > 0:
			var next := maxf(minf(s - 0.12, nat[k] - 1.0), floor_at[k])
			if k == falls:
				next = minf(next, s - drop)
			s = minf(s, next)
		surf.append(s)
	return surf


## The rolling hills over the base land at p (`h` the base's height: none on the beach).
static func _hill(lp: Dictionary, p: Vector2, h: float) -> float:
	var nz: FastNoiseLite = lp["hills"]
	return (nz.get_noise_2d(p.x, p.y) + 0.35) * float(lp["hill_h"]) * smoothstep(2.0, 9.0, h)


static func _grid(rivers: Array, half: float) -> Dictionary:
	var n := int(ceil(half * 2.0 / GRID_CELL)) + 1
	var dist := PackedFloat32Array()
	var surf := PackedFloat32Array()
	var wide := PackedFloat32Array()
	dist.resize(n * n)
	surf.resize(n * n)
	wide.resize(n * n)
	dist.fill(GRID_BAND)
	for rv in rivers:
		var pts: PackedVector2Array = rv["pts"]
		var sf: PackedFloat32Array = rv["surf"]
		for j in range(pts.size() - 1):
			var a := pts[j]
			var ab := pts[j + 1] - a
			var lo := Vector2(minf(a.x, pts[j + 1].x), minf(a.y, pts[j + 1].y)) - Vector2.ONE * GRID_BAND
			var hi := Vector2(maxf(a.x, pts[j + 1].x), maxf(a.y, pts[j + 1].y)) + Vector2.ONE * GRID_BAND
			for iz in range(maxi(0, floori((lo.y + half) / GRID_CELL)), mini(n, ceili((hi.y + half) / GRID_CELL) + 1)):
				for ix in range(maxi(0, floori((lo.x + half) / GRID_CELL)), mini(n, ceili((hi.x + half) / GRID_CELL) + 1)):
					var q := Vector2(-half + ix * GRID_CELL, -half + iz * GRID_CELL)
					var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
					var i := iz * n + ix
					var dd := q.distance_to(a + ab * t)
					if dd < dist[i]:
						dist[i] = dd
						# (the falls' step is sharp: the segment into it keeps the upper surface to its end)
						surf[i] = sf[j] if j + 1 == int(rv["falls"]) else lerpf(sf[j], sf[j + 1], t)
						wide[i] = float(rv["w"])
	return {"n": n, "half": half, "d": dist, "s": surf, "w": wide}


## [distance to the nearest river's middle, its surface there, its half width] (GRID_BAND far off).
static func near(lp: Dictionary, p: Vector2) -> Vector3:
	var g: Dictionary = lp["grid"]
	var n: int = g["n"]
	var fx := clampf((p.x + float(g["half"])) / GRID_CELL, 0.0, n - 1.001)
	var fz := clampf((p.y + float(g["half"])) / GRID_CELL, 0.0, n - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var d: PackedFloat32Array = g["d"]
	var i := iz * n + ix
	var dd := lerpf(lerpf(d[i], d[i + 1], tx), lerpf(d[i + n], d[i + n + 1], tx), tz)
	# (surface and width from the nearest grid point: blending across two rivers' or the falls' cells would make a slope)
	var k := i + (1 if tx > 0.5 else 0) + (n if tz > 0.5 else 0)
	return Vector3(dd, g["s"][k], g["w"][k])


## 0..1: how much of p is river (its channel, `pad` m further out).
static func wet(lp: Dictionary, p: Vector2, pad := 0.0) -> float:
	var nr := near(lp, p)
	if nr.x >= GRID_BAND - 1.0:
		return 0.0
	return 1.0 - smoothstep(nr.z + pad, nr.z + pad + 2.0, nr.x)


## The falls' foot (island point) and the pool's surface, for each river that has falls.
static func falls_of(lp: Dictionary) -> Array:
	var out: Array = []
	for ri in range((lp["rivers"] as Array).size()):
		var rv: Dictionary = lp["rivers"][ri]
		var f: int = rv["falls"]
		if f > 0:
			var pts: PackedVector2Array = rv["pts"]
			var dir := (pts[f] - pts[f - 1]).normalized()
			out.append({"top": pts[f] - dir, "foot": pts[f] + dir * (float(rv["w"]) + 2.5), "dir": dir, "y_top": float(rv["surf"][f - 1]),
				"y": float(rv["surf"][f]), "w": float(rv["w"]), "drop": float(rv["drop"]), "river": ri, "k": f})
	return out


## The exact distance from p to the nearest river's middle (any distance; `near` stops at GRID_BAND).
static func river_dist(lp: Dictionary, p: Vector2) -> float:
	var best := INF
	for rv in lp["rivers"]:
		var pts: PackedVector2Array = rv["pts"]
		for j in range(pts.size() - 1):
			var a := pts[j]
			var ab := pts[j + 1] - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best


static func _clear(isl, p: Vector2) -> float:
	var k := 1.0
	for s in isl.sites.values():
		k = minf(k, smoothstep(SITE_CLEAR[0], SITE_CLEAR[1], p.distance_to(s)))
	return k


## Beside its river: the river's point nearest where GenIsland would have put the town, on the side facing it.
static func village_at(isl, p: Vector2) -> Vector2:
	var lp: Dictionary = isl.land_plan
	var best := p
	var bd := INF
	for rv in lp["rivers"]:
		var pts: PackedVector2Array = rv["pts"]
		var f: int = rv["falls"]
		for k in range(1, pts.size() - 1):
			if float(rv["surf"][k]) < FLOOR - 0.1 or (f > 0 and absi(k - f) < 6):
				continue
			var along := (pts[k + 1] - pts[k - 1]).normalized()
			var side := Vector2(-along.y, along.x)
			if side.dot(p - pts[k]) < 0.0:
				side = -side
			var q := pts[k] + side * (TOWN_OFF + float(rv["w"]))
			if isl._coast_t(q) > -34.0 or river_dist(lp, q) < TOWN_OFF - 2.0:
				continue
			# (down in the valley rather than up the summit's flank)
			var dd := q.distance_to(p) + maxf(0.0, float(rv["surf"][k]) - 10.0) * 6.0
			if dd < bd:
				bd = dd
				best = q
	return best if bd < 340.0 else p


static func shape(isl, p: Vector2, h: float) -> float:
	var lp: Dictionary = isl.land_plan
	var land := smoothstep(0.5, 4.0, h)
	if land <= 0.0:
		return h
	var s := h + _hill(lp, p, h) * _clear(isl, p)
	var nr := near(lp, p)
	if nr.x < GRID_BAND - 1.0:
		var w := nr.z
		var sf := nr.y
		# (where the land is lower than the river may run, its banks are raised to hold it)
		if sf > 0.5 and s < sf + BANK:
			s += (sf + BANK - s) * (1.0 - smoothstep(w + 1.5, w + 6.0, nr.x))
		if nr.x < w:
			s = minf(s, sf - BED * (1.0 - pow(nr.x / w, 2.0)) - 0.1)
		else:
			# a wide valley where the cut is shallow, gorge walls where it is deep
			var cut := s - sf
			var bank_w := lerpf(22.0, 4.5, clampf(cut / 9.0, 0.0, 1.0))
			if nr.x < w + bank_w:
				s = minf(s, lerpf(sf + BANK, s, smoothstep(w, w + bank_w, nr.x)))
	for fl in falls_of(lp):
		var fd := p.distance_to(fl["foot"])
		var pr: float = float(fl["w"]) + 2.5
		if fd < pr + 3.0:
			s = minf(s, lerpf(float(fl["y"]) - POOL_DEPTH, s, smoothstep(pr - 1.5, pr + 3.0, fd)))
	return s


## No forest in the water; the banks open, grass and stones.
static func cover(isl, p: Vector2, c: float) -> float:
	return c * (1.0 - wet(isl.land_plan, p, PLANT_PAD + 2.0))


## [plants, rocks]: nothing in the river or in front of a cave's mouth, stones along the banks.
static func growth(isl, p: Vector2) -> Vector2:
	var lp: Dictionary = isl.land_plan
	var bare := 1.0 - wet(lp, p, PLANT_PAD)
	for e in isl.interiors:
		if p.distance_to(e["mouth"]) < MOUTH_CLEAR:
			bare = 0.0
	var bank := wet(lp, p, 5.0) * bare
	return Vector2(bare, bare * (1.0 + bank * 2.5))


## The river's bed and the gravel at its edge as rock, its banks trodden mud.
static func paint(isl, p: Vector2, _h: float, splat: Color) -> Color:
	var lp: Dictionary = isl.land_plan
	var bed := wet(lp, p, 0.6)
	var mud := wet(lp, p, 3.0) * (1.0 - bed)
	splat.g = maxf(splat.g, bed)
	splat.r = maxf(splat.r, mud * 0.7) * (1.0 - bed)
	splat.b *= 1.0 - maxf(bed, mud)
	return splat


static func steps(isl) -> Array:
	return [["forest river", func(): _water(isl)], ["forest bridges", func(): _bridges(isl)]]


static func _in_interior(isl, p: Vector2, r := 0.0) -> bool:
	for e in isl.interiors:
		if p.distance_to(e["at"]) < float(e["radius"]) + r + 4.0:
			return true
	return false


## The water: a flowing strip along each river where its bed is (not where a site's flat filled it), the falls,
## foam at their foot and a pool there you swim in.
static func _water(isl) -> void:
	var lp: Dictionary = isl.land_plan
	var st: Dictionary = KitStyle.of(isl.theme)
	var flow := KitLandmarks.flow_mat("water", st["water_tint"], Vector2(0.0, -0.45))
	var mb := MeshBuilder.new()
	for rv in lp["rivers"]:
		var pts: PackedVector2Array = rv["pts"]
		var sf: PackedFloat32Array = rv["surf"]
		var w: float = float(rv["w"]) + 0.7
		var f: int = rv["falls"]
		var v := 0.0
		for j in range(pts.size() - 1):
			var a := pts[j]
			var b := pts[j + 1]
			var ya := sf[j]
			var yb := sf[j] if j + 1 == f else sf[j + 1]
			if (ya < 0.15 and yb < 0.15) or not _bed(isl, a, ya) or not _bed(isl, b, yb) or _in_interior(isl, a) or _in_interior(isl, b):
				continue
			var na := ((pts[j + 1] - pts[maxi(j - 1, 0)]).normalized()).orthogonal() * w
			var nb := ((pts[mini(j + 2, pts.size() - 1)] - a).normalized()).orthogonal() * w
			var dv := a.distance_to(b) * 0.25
			mb.add_quad(flow, Vector3(a.x - na.x, ya, a.y - na.y), Vector3(a.x + na.x, ya, a.y + na.y), Vector3(b.x + nb.x, yb, b.y + nb.y), Vector3(b.x - nb.x, yb, b.y - nb.y),
				Vector2(0, v), Vector2(w * 0.5, v), Vector2(w * 0.5, v + dv), Vector2(0, v + dv), Color.WHITE, Vector3.UP)
			v += dv
	var node := Node3D.new()
	node.name = "ForestRivers"
	isl.add_child(node)
	for fl in falls_of(lp):
		if not _bed(isl, fl["foot"], float(fl["y"]) - POOL_DEPTH + BED) or _in_interior(isl, fl["foot"]):
			continue
		_falls(node, mb, st, fl)
	if not mb.is_empty():
		var mi := mb.to_instance("Water")
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = VIS
		node.add_child(mi)


## Whether the ground at p is the river's bed under surface y (a site's flat may have filled it in).
static func _bed(isl, p: Vector2, y: float) -> bool:
	return absf(float(isl.hv(p)) - (y - BED)) < 0.8


## The falls: a curtain from the upper river down to the pool, a brighter sheet in front, foam and mist at the foot.
static func _falls(node: Node3D, mb: MeshBuilder, st: Dictionary, fl: Dictionary) -> void:
	var top: Vector2 = fl["top"]
	var foot: Vector2 = fl["foot"]
	var dir: Vector2 = fl["dir"]
	var y0: float = fl["y_top"]
	var y1: float = fl["y"]
	var w: float = float(fl["w"]) + 0.6
	var side := Vector3(-dir.y, 0, dir.x)
	var curve := PackedVector3Array()
	var lip := Vector3(top.x, y0, top.y)
	for k in range(9):
		var s := float(k) / 8.0
		var at := lip + Vector3(dir.x, 0, dir.y) * (3.2 * sqrt(s)) + Vector3.UP * (y1 - y0) * s
		curve.append(at)
	KitLandmarks.ribbon(mb, KitLandmarks.flow_mat("water", st["falls_tint"], Vector2(0.05, -1.2), 0.4), curve, w * 2.0, w * 2.3, side, Vector3(dir.x, 0, dir.y), 0.45)
	var front := PackedVector3Array()
	for q in curve:
		front.append(q + Vector3(dir.x, 0, dir.y) * 0.15)
	KitLandmarks.ribbon(mb, KitLandmarks.flow_mat("canvas", st["falls_tint"], Vector2(-0.04, -2.0), 0.3), front, w * 1.4, w * 1.8, side, Vector3(dir.x, 0, dir.y), 0.6)
	var pool_r := float(fl["w"]) + 2.5
	KitLandmarks.water_disc(mb, KitLandmarks.flow_mat("water", st["water_tint"], Vector2(0.02, 0.05)), Vector3(foot.x, y1, foot.y), pool_r + 0.6, 18, 0.22)
	var hit := top + dir * 3.2
	KitLandmarks.water_disc(mb, KitLandmarks.flow_mat("water", Color(0.95, 0.98, 1.0, 0.75), Vector2(0.15, 0.32)), Vector3(hit.x, y1 + 0.04, hit.y), w + 0.6, 10, 0.5)
	var pool := InlandPool.make(pool_r)
	pool.position = Vector3(foot.x, y1, foot.y)
	node.add_child(pool)
	KitLandmarks.puffs(node, Vector3(hit.x, y1 + 0.4, hit.y), Color(0.92, 0.96, 1.0, 0.35), 10, 1.6, 0.6, 1.0)
	KitLandmarks.loop_sound(node, "hull_rush_loop.wav", Vector3(hit.x, y1 + 1.0, hit.y), 7.0, 55.0, -4.0, 0.75)


## Plank footbridges where a path crosses a river (one per crossing), rails each side, a collider to walk on.
static func _bridges(isl) -> void:
	var lp: Dictionary = isl.land_plan
	var planks := PSXMat.lit("planks_weathered", Color(0.9, 0.85, 0.78))
	var post := PSXMat.lit("planks_dark", Color.WHITE)
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "ForestBridges"
	body.collision_layer = 1
	body.collision_mask = 0
	var done: Array = []
	for path in isl.paths:
		var pts: PackedVector2Array = path
		for k in range(pts.size()):
			var nr := near(lp, pts[k])
			if nr.x > nr.z * 0.6 or done.any(func(q): return (q as Vector2).distance_to(pts[k]) < 16.0):
				continue
			var c := pts[k]
			if not _bed(isl, c, nr.y) or _in_interior(isl, c):
				continue
			# across the river: the way the distance grows fastest
			var e := 1.5
			var g := Vector2(near(lp, c + Vector2(e, 0)).x - near(lp, c - Vector2(e, 0)).x, near(lp, c + Vector2(0, e)).x - near(lp, c - Vector2(0, e)).x)
			if g.length() < 0.01:
				continue
			var across := g.normalized()
			var half := nr.z + 3.0
			var a := c - across * half
			var b := c + across * half
			var ya: float = float(isl.hv(a))
			var yb: float = float(isl.hv(b))
			var deck := maxf(nr.y + 0.5, maxf(ya, yb) - 0.15)
			if deck - minf(ya, yb) > 3.0:
				continue
			done.append(c)
			var along := Vector3(across.x, 0, across.y)
			var side := Vector3(-across.y, 0, across.x)
			var yaw := atan2(along.x, along.z)
			var mid := Vector3(c.x, deck, c.y)
			var span := half * 2.0 + 1.0
			mb.add_box(planks, Transform3D(Basis(Vector3.UP, yaw), mid), Vector3(2.2, 0.16, span), 0.6)
			for sd in [-1.0, 1.0]:
				mb.add_box(post, Transform3D(Basis(Vector3.UP, yaw), mid + side * 1.05 * sd + Vector3.UP * 0.9), Vector3(0.1, 0.1, span), 0.6)
				for t in [-0.5, -0.17, 0.17, 0.5]:
					var at: Vector3 = mid + along * span * t * 0.95 + side * 1.05 * sd
					var foot: float = minf(float(isl.hv(Vector2(at.x, at.z))), nr.y - BED)
					mb.add_box(post, Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, (foot + deck + 0.95) * 0.5, at.z)), Vector3(0.14, deck + 0.95 - foot, 0.14), 0.6)
			KitLandmarks.box_col_xf(body, Vector3(2.2, 0.3, span), Transform3D(Basis(Vector3.UP, yaw), mid - Vector3.UP * 0.07))
	if mb.is_empty():
		body.free()
		return
	var mi := mb.to_instance("Bridges")
	mi.visibility_range_end = 400.0
	body.add_child(mi)
	isl.add_child(body)
