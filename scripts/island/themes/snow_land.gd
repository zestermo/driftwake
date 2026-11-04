extends RefCounted
## The snow island's own land (SnowTheme.plan_land / shape / steps): the island's summit
## raised into a tall icy peak with a small flat top (the castle's or the lookout's ground)
## and walkable flanks, sharper spires round it that break the skyline (passes left where
## a site stands), wind-carved drifts, frozen lakes in hollows and a frozen river from the
## peak's foot to the sea; then the ice laid over the lakes and the river, and blue
## crystal clusters on the high steep ground. Plan and shape are numbers only (the
## worker); steps make the nodes.

## The main peak's flat top (m across, radius) and its flanks' curve (higher: steeper near the top).
const TOP_R := 13.0
const PEAK_K := 1.6
## How far round a site the spires and drifts give way (m: none within the first, all past the second).
const SITE_CLEAR := [34.0, 72.0]
## The ice sits this far over the ground cut for it (the vertex snap: ground and a surface laid on it mustn't fight);
## the banks rise at least as far over it, and the ice runs on under them (ICE_PAST), so its edge is always buried and
## the shore is the ground coming up through the ice: no lip to snag on, no sheet hanging over a drop (1.30).
const ICE_LIFT := 0.6
## The river's ice under the frozen water's level: its level runs this far under the land beside it.
const RIVER_SINK := 1.4
## The ice past the bed's edge (m), the bank's climb out of the bed (m past the edge), and where it eases back into the land.
const ICE_PAST := 3.0
const BANK_RISE := 2.5
const PLANT_PAD := 2.0
## No tree, bush or rock this near a cave's mouth (a trunk in the way and you can't walk in).
const MOUTH_CLEAR := 9.0
const VIS := 700.0


static func plan(isl, rng: RandomNumberGenerator) -> Dictionary:
	var r: float = isl.radius
	var main_c: Vector2 = isl._bumps[0][0]
	var lp := {}
	lp["main"] = {"c": main_c, "h": rng.randf_range(68.0, 90.0), "r": rng.randf_range(215.0, 255.0)}
	var spires: Array = []
	var a0 := rng.randf() * TAU
	# (more than will stand: those on a site's ground or the way up give way)
	for k in range(rng.randi_range(5, 8)):
		var a := a0 + TAU * k / 8.0 + rng.randf_range(-0.3, 0.3)
		var c := Vector2.from_angle(a) * r * rng.randf_range(0.45, 0.72)
		if c.distance_to(main_c) < 110.0:
			continue
		# (always under the summit, whose peak is the island's crown)
		spires.append({"c": c, "h": rng.randf_range(0.65, 0.9) * float(lp["main"]["h"]), "r": rng.randf_range(38.0, 60.0), "k": rng.randf_range(1.2, 1.5)})
	lp["spires"] = spires
	var lakes: Array = []
	for k in range(rng.randi_range(2, 3)):
		var c := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.3, 0.62)
		var lr := rng.randf_range(16.0, 28.0)
		if c.distance_to(main_c) < float(lp["main"]["r"]) * 0.5 or spires.any(func(s): return c.distance_to(s["c"]) < float(s["r"]) + lr + 10.0) \
				or lakes.any(func(o): return c.distance_to(o["c"]) < float(o["r"]) + lr + 30.0):
			continue
		# (in a hollow a metre under the land there: the base's and the peak's flank)
		lakes.append({"c": c, "r": lr, "level": float(isl._height_natural(c)) + _cone(lp["main"], c) - 1.0})
		# (a place's levelled ground cut a step into the bank)
		isl.reserve_area(c, lr + ICE_PAST + 4.0)
	lp["lakes"] = lakes
	# the river: from the main peak's foot outward to the sea, wandering
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var at: Vector2 = main_c + dir * float(lp["main"]["r"]) * 0.55
	var pts := PackedVector2Array([at])
	var side := Vector2(-dir.y, dir.x)
	var wob := 0.0
	while at.length() < r + 30.0 and pts.size() < 60:
		wob = clampf(wob + rng.randf_range(-0.35, 0.35), -0.6, 0.6)
		at += (dir + side * wob).normalized() * 18.0
		pts.append(at)
	lp["river"] = pts
	lp["river_w"] = rng.randf_range(4.5, 7.0)
	lp["river_lvl"] = _river_levels(isl, lp, pts)
	lp["river_grid"] = _river_grid(pts, lp["river_lvl"], float(isl.half))
	var drift := FastNoiseLite.new()
	drift.seed = rng.randi()
	drift.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	drift.frequency = 0.016
	drift.fractal_octaves = 2
	lp["drift"] = drift
	var crag := FastNoiseLite.new()
	crag.seed = rng.randi()
	crag.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	crag.frequency = 0.045
	crag.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	crag.fractal_octaves = 3
	lp["crag"] = crag
	return lp


## The river's distance on a GRID_CELL grid over the island's terrain, filled only within GRID_BAND of it (the land's
## hooks ask it at every point of the terrain and the scatter: walking the river's segments each time cost seconds).
const GRID_CELL := 3.0
const GRID_BAND := 40.0


## The ice's level at each of the river's points: the land there (the base, the peak's flank; no spires or drifts, which
## give way to the river) under RIVER_SINK, smoothed along the river. Plan time: the base land only (land_plan is empty).
static func _river_levels(isl, lp: Dictionary, pts: PackedVector2Array) -> PackedFloat32Array:
	var lv := PackedFloat32Array()
	for q in pts:
		var h: float = isl._height_natural(q)
		lv.append(_flank(isl, lp, q, h) - RIVER_SINK)
	for k in range(2):
		var sm := lv.duplicate()
		for i in range(1, lv.size() - 1):
			sm[i] = lv[i - 1] * 0.25 + lv[i] * 0.5 + lv[i + 1] * 0.25
		lv = sm
	return lv


static func _river_grid(pts: PackedVector2Array, lvl: PackedFloat32Array, half: float) -> Dictionary:
	var n := int(ceil(half * 2.0 / GRID_CELL)) + 1
	var d := PackedFloat32Array()
	d.resize(n * n)
	d.fill(GRID_BAND)
	var l := PackedFloat32Array()
	l.resize(n * n)
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
				var dq := q.distance_to(a + ab * t)
				if dq < d[i]:
					d[i] = dq
					l[i] = lerpf(lvl[j], lvl[j + 1], t)
	return {"n": n, "half": half, "d": d, "l": l}


## The distance from p to the river (bilinear on the grid; GRID_BAND past it).
static func _river_near(lp: Dictionary, p: Vector2) -> float:
	return _grid_at(lp, p, "d")


## The river's ice level nearest p (within GRID_BAND of it).
static func _river_level(lp: Dictionary, p: Vector2) -> float:
	return _grid_at(lp, p, "l")


static func _grid_at(lp: Dictionary, p: Vector2, key: String) -> float:
	var g: Dictionary = lp["river_grid"]
	var n: int = g["n"]
	var fx := clampf((p.x + float(g["half"])) / GRID_CELL, 0.0, n - 1.001)
	var fz := clampf((p.y + float(g["half"])) / GRID_CELL, 0.0, n - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var d: PackedFloat32Array = g[key]
	var i := iz * n + ix
	return lerpf(lerpf(d[i], d[i + 1], tx), lerpf(d[i + n], d[i + n + 1], tx), tz)


## 0..1: how much of p is frozen water (the lakes and the river), `pad` m further out (the plants keep that far off:
## the scatter's second layer grows ~2 m from the spot it was judged at).
static func _ice_at(lp: Dictionary, p: Vector2, pad := 0.0) -> float:
	var k := 0.0
	for lk in lp["lakes"]:
		k = maxf(k, 1.0 - smoothstep(float(lk["r"]) + pad + 1.0, float(lk["r"]) + pad + ICE_PAST + 1.0, p.distance_to(lk["c"])))
	var w: float = float(lp["river_w"]) * 0.5 + pad
	return maxf(k, 1.0 - smoothstep(w + 1.0, w + ICE_PAST + 1.0, _river_near(lp, p)))


## No forest on the ice; the peaks' high flanks thin out to bare snow and rock.
static func cover(isl, p: Vector2, c: float) -> float:
	var lp: Dictionary = isl.land_plan
	var m: Dictionary = lp["main"]
	var high := smoothstep(0.75, 0.35, p.distance_to(m["c"]) / float(m["r"]))
	return c * (1.0 - _ice_at(lp, p, PLANT_PAD)) * (1.0 - high * 0.85)


## [plants, rocks]: nothing on the ice or in front of a cave's mouth; more rocks on the spires.
static func growth(isl, p: Vector2) -> Vector2:
	var lp: Dictionary = isl.land_plan
	var bare := 1.0 - _ice_at(lp, p, PLANT_PAD)
	for e in isl.interiors:
		if p.distance_to(e["mouth"]) < MOUTH_CLEAR:
			bare = 0.0
	var stony := 1.0
	for sp in lp["spires"]:
		stony = maxf(stony, 1.0 + 2.0 * (1.0 - smoothstep(0.4, 1.0, p.distance_to(sp["c"]) / float(sp["r"]))))
	return Vector2(bare, bare * stony)


## The high ground glazed: the rock layer (glacier rock) creeps over the peaks' upper flanks.
static func paint(_isl, _p: Vector2, h: float, splat: Color) -> Color:
	splat.g = maxf(splat.g, smoothstep(70.0, 100.0, h) * 0.7)
	return splat


## 0..1: how much a spire or drift may stand at p (none on a site's ground).
static func _clear(isl, p: Vector2) -> float:
	var k := 1.0
	for s in isl.sites.values():
		k = minf(k, smoothstep(SITE_CLEAR[0], SITE_CLEAR[1], p.distance_to(s)))
	return k


## 0..1: how much a spire may stand at p on the way up from the village to the summit (a pass through them).
static func _pass(isl, p: Vector2) -> float:
	if not (isl.sites.has("village") and isl.sites.has("summit")):
		return 1.0
	var a: Vector2 = isl.sites["village"]
	var ab: Vector2 = isl.sites["summit"] - a
	var q := a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.01), 0.0, 1.0)
	return smoothstep(SITE_CLEAR[0] + 6.0, SITE_CLEAR[1] + 10.0, p.distance_to(q))


## The main peak's height over the base land at p: a flat top, then concave flanks out to its radius.
static func _cone(m: Dictionary, p: Vector2) -> float:
	var t := clampf((p.distance_to(m["c"]) - TOP_R) / (float(m["r"]) - TOP_R), 0.0, 1.0)
	return float(m["h"]) * pow(1.0 - t, PEAK_K)


## The base land with the cliffs taken out under the peak and the peak's flank on it (`h` the base height at p).
static func _flank(isl, lp: Dictionary, p: Vector2, h: float) -> float:
	var land := smoothstep(0.5, 4.0, h)
	# (the base raises a cliff's whole bearing to the cliff's height, which tears the middle of the island where
	# the bearings meet: under the peak it's taken back out)
	var mid := 1.0 - smoothstep(0.15, 0.4, p.length() / float(isl.radius))
	var s := h - (float(isl._cliff_h) - float(isl._def["base"])) * float(isl._cliff(atan2(p.y, p.x))) * mid * land
	return s + _cone(lp["main"], p) * land


## The ground round frozen water at `level`, `d` m from the bed's edge (negative inside): the bed ICE_LIFT under
## the ice, a shore climbing to ICE_LIFT over it by BANK_RISE m out, then the land `s`: higher land rises from the
## shore over BANK_EASE m or more (no wall cut into a slope), lower land is reached by a dyke easing down to it.
const BANK_EASE := 12.0
const BANK_REACH := 31.0
static func _bank(s: float, level: float, d: float) -> float:
	var rim := level + ICE_LIFT
	var g := lerpf(level - ICE_LIFT, rim, smoothstep(-0.5, BANK_RISE, d))
	if s >= rim:
		return g + (s - rim) * smoothstep(-0.5, minf(BANK_EASE + s - rim, BANK_REACH - 1.0), d)
	return lerpf(g, s, smoothstep(BANK_RISE + 1.5, minf(BANK_RISE + 9.5 + rim - s, BANK_REACH - 1.0), d))


static func shape(isl, p: Vector2, h: float) -> float:
	var lp: Dictionary = isl.land_plan
	var land := smoothstep(0.5, 4.0, h)
	if land <= 0.0:
		return h
	var s := _flank(isl, lp, p, h)
	var hw: float = float(lp["river_w"]) * 0.5
	var dr := _river_near(lp, p)
	var clear := _clear(isl, p)
	if clear > 0.0:
		var pass_k := _pass(isl, p)
		# (the spires give way to the river: it runs between them, not through a gorge)
		var by_river := smoothstep(hw + 4.0, hw + BANK_REACH, dr)
		for sp in lp["spires"]:
			var d := p.distance_to(sp["c"])
			if d < float(sp["r"]):
				var crag: FastNoiseLite = lp["crag"]
				var t := d / float(sp["r"])
				s += (float(sp["h"]) * pow(1.0 - t, float(sp["k"])) + crag.get_noise_2d(p.x * 1.6, p.y * 1.6) * 6.0 * (1.0 - t)) * clear * pass_k * land * by_river
		var drift: FastNoiseLite = lp["drift"]
		s += maxf(drift.get_noise_2d(p.x * 0.35 + p.y * 0.15, p.y * 1.4 - p.x * 0.2), 0.0) * 2.2 * clear * (0.3 + 0.7 * pass_k) * land
	for lk in lp["lakes"]:
		var d := p.distance_to(lk["c"]) - float(lk["r"])
		if d < BANK_REACH:
			s = _bank(s, float(lk["level"]), d)
	if dr - hw < BANK_REACH:
		s = lerpf(s, _bank(s, _river_level(lp, p), dr - hw), _off_lakes(lp, p))
	return s


## 0..1: how far p is off the lakes and their banks (the river gives way on them: the lake's ice is the one laid there).
static func _off_lakes(lp: Dictionary, p: Vector2) -> float:
	var k := 1.0
	for lk in lp["lakes"]:
		k = minf(k, smoothstep(float(lk["r"]) + ICE_PAST + 1.0, float(lk["r"]) + ICE_PAST + 8.0, p.distance_to(lk["c"])))
	return k


## The ice on the lakes and the river, and crystal clusters on the high steep ground.
static func steps(isl) -> Array:
	return [["snow ice", func(): _ice(isl)], ["snow crystals", func(): _crystals(isl)]]


## Whether p (or a disk of r round it) is on a cave's or dungeon's ground (KitDungeons, planned after the land:
## its rock and tunnels stand over the ground there, and a sheet of ice would cut through them).
static func _in_interior(isl, p: Vector2, r := 0.0) -> bool:
	for e in isl.interiors:
		if p.distance_to(e["at"]) < float(e["radius"]) + r + 4.0:
			return true
	return false


## The river's ice as stations every ~RIVER_STEP m: [point, side (unit, mitred: neighbours share their edges), level,
## laid]. It starts ICE_PAST + the half width back up the bed (its end under the head of the bed) and is laid where the
## bed is (or next to it, so a run's end is under the ground that filled it), off the lakes and caves, down to where
## the ice is under the sea.
const RIVER_STEP := 3.0
static func _river_strip(isl, lp: Dictionary) -> Array:
	var pts: PackedVector2Array = lp["river"]
	var lvl: PackedFloat32Array = lp["river_lvl"]
	var hw: float = float(lp["river_w"]) * 0.5
	var line: Array = [[pts[0] - (pts[1] - pts[0]).normalized() * (hw + ICE_PAST), lvl[0]]]
	for j in range(pts.size() - 1):
		var k := maxi(1, ceili(pts[j].distance_to(pts[j + 1]) / RIVER_STEP))
		for i in range(k):
			line.append([pts[j].lerp(pts[j + 1], float(i) / k), lerpf(lvl[j], lvl[j + 1], float(i) / k)])
	line.append([pts[pts.size() - 1], lvl[lvl.size() - 1]])
	var out: Array = []
	var good: Array = []
	var low: Array = []
	for i in range(line.size()):
		var a: Vector2 = line[maxi(i - 1, 0)][0]
		var b: Vector2 = line[mini(i + 1, line.size() - 1)][0]
		var p: Vector2 = line[i][0]
		var n0 := (p - a).normalized().orthogonal() if i > 0 else (b - p).normalized().orthogonal()
		var n1 := (b - p).normalized().orthogonal() if i < line.size() - 1 else n0
		var side := (n0 + n1).normalized()
		side /= maxf(side.dot(n0), 0.5)
		var l: float = line[i][1]
		var g: float = isl.hv(p)
		var edge := side.normalized() * (hw + ICE_PAST)
		var banks := minf(float(isl.hv(p + edge)), float(isl.hv(p - edge)))
		good.append(_off_lakes(lp, p) >= 1.0 and not _in_interior(isl, p) and l > -0.6 and g < l - 0.2 and g > l - ICE_LIFT - 0.3 and banks > l + 0.1)
		low.append(minf(g, banks) - 0.15)
		out.append([p, side, l, false])
	# (where the bed or its banks stop - a site's levelled ground, a cave, a lake - the ice slopes down into the ground
	# over the next station: its end is buried too)
	for i in range(out.size()):
		if good[i]:
			out[i][3] = true
		elif (i > 0 and good[i - 1]) or (i < out.size() - 1 and good[i + 1]):
			out[i][2] = minf(float(out[i][2]), float(low[i]))
			out[i][3] = true
	return out


## One triangle of ice, drawn up and in the collider facing up (a face's front is the side its winding shows: the
## old ice collider's faces were wound to face down, and Jolt lets a body through a mesh shape's back faces, so
## captains fell through the ice onto the bed under it).
static func _sheet(mb: MeshBuilder, mat: Material, faces: PackedVector3Array, t: Array, col: Color) -> void:
	var a: Vector3 = t[0]
	var b: Vector3 = t[1]
	var c: Vector3 = t[2]
	if (b - a).cross(c - a).y > 0.0:
		var x := b
		b = c
		c = x
	mb.add_tri(mat, a, b, c, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(a.x, a.z) * 0.12, Vector2(b.x, b.z) * 0.12, Vector2(c.x, c.z) * 0.12, col, Vector3.UP)
	faces.append_array([a, b, c])


static func _ice(isl) -> void:
	var lp: Dictionary = isl.land_plan
	var mb := MeshBuilder.new()
	var ice := PSXMat.lit("ice", Color(0.92, 0.97, 1.0), {"affine": 0.4})
	var body := StaticBody3D.new()
	body.name = "SnowIce"
	body.collision_layer = 1
	body.collision_mask = 0
	var faces := PackedVector3Array()
	for lk in lp["lakes"]:
		var c: Vector2 = lk["c"]
		# (a site's flat may have filled a lake in: no ice where the ground isn't the bed)
		if absf(float(isl.hv(c)) - (float(lk["level"]) - ICE_LIFT)) > 0.3 or _in_interior(isl, c, float(lk["r"])):
			continue
		var y: float = lk["level"]
		var n := 32
		# (a ring on the bed's edge, and the rim out under the bank; where something levelled the bank away, the rim
		# slopes down into the ground there instead of hanging over it)
		var inner: Array = []
		var rim: Array = []
		for i in range(n):
			var d := Vector2.from_angle(TAU * i / n)
			var q: Vector2 = c + d * (float(lk["r"]) + ICE_PAST)
			var g: float = isl.hv(q)
			inner.append(Vector3(c.x + d.x * (float(lk["r"]) - 1.0), y, c.y + d.y * (float(lk["r"]) - 1.0)))
			rim.append(Vector3(q.x, y if g > y + 0.1 else minf(y, g - 0.15), q.y))
		var mid := Vector3(c.x, y, c.y)
		for i in range(n):
			var j := (i + 1) % n
			_sheet(mb, ice, faces, [mid, inner[i], inner[j]], Color.WHITE)
			_sheet(mb, ice, faces, [inner[i], rim[i], rim[j]], Color.WHITE)
			_sheet(mb, ice, faces, [inner[i], rim[j], inner[j]], Color.WHITE)
	var strip := _river_strip(isl, lp)
	var hw: float = float(lp["river_w"]) * 0.5 + ICE_PAST
	for j in range(strip.size() - 1):
		var a: Array = strip[j]
		var b: Array = strip[j + 1]
		if not (a[3] and b[3]):
			continue
		var pa: Vector2 = a[0]
		var pb: Vector2 = b[0]
		var sa: Vector2 = a[1] * hw
		var sb: Vector2 = b[1] * hw
		var q := [Vector3(pa.x - sa.x, a[2], pa.y - sa.y), Vector3(pa.x + sa.x, a[2], pa.y + sa.y), Vector3(pb.x + sb.x, b[2], pb.y + sb.y), Vector3(pb.x - sb.x, b[2], pb.y - sb.y)]
		_sheet(mb, ice, faces, [q[0], q[1], q[2]], Color(0.95, 0.97, 1.0))
		_sheet(mb, ice, faces, [q[0], q[2], q[3]], Color(0.95, 0.97, 1.0))
	if mb.is_empty():
		return
	var mi := mb.to_instance("Ice")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = VIS
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	isl.add_child(body)


## Crystal clusters on the peaks' and spires' steep high ground, one MultiMesh per kind (they glow by themselves).
static func _crystals(isl) -> void:
	var lp: Dictionary = isl.land_plan
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isl.node["seed"]) + 4471
	var kinds: Array = IslandTheme.meshes(isl.theme)["bamboo"]
	var xfs: Array = []
	for k in kinds:
		xfs.append([])
	var hills: Array = [lp["main"]] + lp["spires"]
	for hl in hills:
		var c: Vector2 = hl["c"]
		var hr: float = hl["r"]
		for i in range(26):
			var p := c + Vector2.from_angle(rng.randf() * TAU) * hr * rng.randf_range(0.2, 0.85)
			var y: float = isl.hv(p)
			if y < 14.0 or isl.excluded(p, 1.0) or isl.path_dist(p) < 3.0:
				continue
			var s := rng.randf_range(0.8, 2.2)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
			(xfs[rng.randi() % kinds.size()] as Array).append(Transform3D(b.scaled(Vector3.ONE * s), Vector3(p.x, y - 0.3, p.y)))
	# (1.30) a column each, about the cluster's core: they stand on the slopes captains climb
	var node := StaticBody3D.new()
	node.name = "SnowCrystals"
	node.collision_layer = 1
	node.collision_mask = 0
	for i in range(kinds.size()):
		var list: Array = xfs[i]
		if list.is_empty():
			continue
		var box: AABB = (kinds[i] as Mesh).get_aabb()
		for xf in list:
			var s: float = (xf as Transform3D).basis.get_scale().x
			KitLandmarks.cyl_col(node, minf(box.size.x, box.size.z) * 0.3 * s, box.end.y * s * 0.85, (xf as Transform3D).origin + Vector3.UP * box.end.y * s * 0.425)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = kinds[i]
		mm.instance_count = list.size()
		for j in range(list.size()):
			mm.set_instance_transform(j, list[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = VIS
		node.add_child(mmi)
	isl.add_child(node)
