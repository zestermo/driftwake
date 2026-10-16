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
## The ice sits this far over the ground cut for it (the vertex snap: ground and a surface laid on it mustn't fight).
const ICE_LIFT := 0.6
const RIVER_DEPTH := 2.0
const PLANT_PAD := 2.0
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
	var drift := FastNoiseLite.new()
	drift.seed = rng.randi()
	drift.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	drift.frequency = 0.03
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


## 0..1: how much of p is frozen water (the lakes and the river), `pad` m further out (the plants keep that far off:
## the scatter's second layer grows ~2 m from the spot it was judged at).
static func _ice_at(lp: Dictionary, p: Vector2, pad := 0.0) -> float:
	var k := 0.0
	for lk in lp["lakes"]:
		k = maxf(k, 1.0 - smoothstep(float(lk["r"]) + pad, float(lk["r"]) + pad + 3.0, p.distance_to(lk["c"])))
	var w: float = float(lp["river_w"]) * 0.5 + pad
	return maxf(k, 1.0 - smoothstep(w + 0.5, w + 3.0, _river_dist(lp["river"], p)))


## No forest on the ice; the peaks' high flanks thin out to bare snow and rock.
static func cover(isl, p: Vector2, c: float) -> float:
	var lp: Dictionary = isl.land_plan
	var m: Dictionary = lp["main"]
	var high := smoothstep(0.75, 0.35, p.distance_to(m["c"]) / float(m["r"]))
	return c * (1.0 - _ice_at(lp, p, PLANT_PAD)) * (1.0 - high * 0.85)


## [plants, rocks]: nothing on the ice; more rocks on the spires.
static func growth(isl, p: Vector2) -> Vector2:
	var lp: Dictionary = isl.land_plan
	var bare := 1.0 - _ice_at(lp, p, PLANT_PAD)
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


static func _river_dist(pts: PackedVector2Array, p: Vector2) -> float:
	var best := INF
	for j in range(pts.size() - 1):
		var a := pts[j]
		var ab := pts[j + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## The main peak's height over the base land at p: a flat top, then concave flanks out to its radius.
static func _cone(m: Dictionary, p: Vector2) -> float:
	var t := clampf((p.distance_to(m["c"]) - TOP_R) / (float(m["r"]) - TOP_R), 0.0, 1.0)
	return float(m["h"]) * pow(1.0 - t, PEAK_K)


static func shape(isl, p: Vector2, h: float) -> float:
	var lp: Dictionary = isl.land_plan
	var land := smoothstep(0.5, 4.0, h)
	if land <= 0.0:
		return h
	# (the base raises a cliff's whole bearing to the cliff's height, which tears the middle of the island where
	# the bearings meet: under the peak it's taken back out)
	var mid := 1.0 - smoothstep(0.15, 0.4, p.length() / float(isl.radius))
	var s := h - (float(isl._cliff_h) - float(isl._def["base"])) * float(isl._cliff(atan2(p.y, p.x))) * mid * land
	s += _cone(lp["main"], p) * land
	var clear := _clear(isl, p)
	if clear > 0.0:
		var pass_k := _pass(isl, p)
		for sp in lp["spires"]:
			var d := p.distance_to(sp["c"])
			if d < float(sp["r"]):
				var crag: FastNoiseLite = lp["crag"]
				var t := d / float(sp["r"])
				s += (float(sp["h"]) * pow(1.0 - t, float(sp["k"])) + crag.get_noise_2d(p.x * 1.6, p.y * 1.6) * 6.0 * (1.0 - t)) * clear * pass_k * land
		var drift: FastNoiseLite = lp["drift"]
		s += maxf(drift.get_noise_2d(p.x * 0.35 + p.y * 0.15, p.y * 1.4 - p.x * 0.2), 0.0) * 3.2 * clear * (0.3 + 0.7 * pass_k) * land
	for lk in lp["lakes"]:
		var d := p.distance_to(lk["c"])
		var lr: float = lk["r"]
		if d < lr + 12.0:
			var bed: float = float(lk["level"]) - ICE_LIFT
			s = lerpf(bed, s, smoothstep(lr - 1.0, lr + 12.0, d)) if d > lr - 1.0 else bed
	var w: float = lp["river_w"]
	var dr := _river_dist(lp["river"], p)
	if dr < w * 0.5 + 6.0:
		s -= RIVER_DEPTH * (1.0 - smoothstep(w * 0.5, w * 0.5 + 6.0, dr))
	return s


## The ice on the lakes and the river, and crystal clusters on the high steep ground.
static func steps(isl) -> Array:
	return [["snow ice", func(): _ice(isl)], ["snow crystals", func(): _crystals(isl)]]


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
		if absf(float(isl.hv(c)) - (float(lk["level"]) - ICE_LIFT)) > 0.3:
			continue
		var y: float = lk["level"]
		var lr: float = float(lk["r"]) + 1.0
		var n := 20
		for i in range(n):
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var p0 := Vector3(c.x, y, c.y)
			var p1 := Vector3(c.x + cos(a0) * lr, y, c.y + sin(a0) * lr)
			var p2 := Vector3(c.x + cos(a1) * lr, y, c.y + sin(a1) * lr)
			mb.add_tri(ice, p0, p1, p2, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(c.x, c.y) * 0.12, Vector2(p1.x, p1.z) * 0.12, Vector2(p2.x, p2.z) * 0.12, Color.WHITE, Vector3.UP)
			faces.append_array([p0, p2, p1])
	var pts: PackedVector2Array = lp["river"]
	var hw: float = float(lp["river_w"]) * 0.5 + 1.0
	for j in range(pts.size() - 1):
		var a := pts[j]
		var b := pts[j + 1]
		var side := (b - a).normalized().orthogonal() * hw
		var ya := maxf(float(isl.hv(a)), -0.8) + ICE_LIFT
		var yb := maxf(float(isl.hv(b)), -0.8) + ICE_LIFT
		if ya < 0.2 and yb < 0.2:
			continue
		var q := [Vector3(a.x - side.x, ya, a.y - side.y), Vector3(a.x + side.x, ya, a.y + side.y), Vector3(b.x + side.x, yb, b.y + side.y), Vector3(b.x - side.x, yb, b.y - side.y)]
		mb.add_quad(ice, q[0], q[1], q[2], q[3], Vector2(q[0].x, q[0].z) * 0.12, Vector2(q[1].x, q[1].z) * 0.12, Vector2(q[2].x, q[2].z) * 0.12, Vector2(q[3].x, q[3].z) * 0.12, Color(0.95, 0.97, 1.0), Vector3.UP)
		faces.append_array([q[0], q[2], q[1], q[0], q[3], q[2]])
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
	var node := Node3D.new()
	node.name = "SnowCrystals"
	for i in range(kinds.size()):
		var list: Array = xfs[i]
		if list.is_empty():
			continue
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
