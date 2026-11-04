extends RefCounted
## The volcanic isle's own land (VolcanicTheme.plan_land / shape / steps; docs/volcanic_island_plan.md): one cone
## near the middle, its rim high over a caldera whose floor is the boss's ground, the rim breached on the village's
## side by a gully that climbs at a walkable grade onto the floor; lava flows down the flanks from side vents, each a
## channel between low levees ending in a cooled lobe; a crescent of lava in the caldera's back. Plan and shape are
## numbers only (the worker); steps make the lava (one mesh, an emissive flow shader, no lights), the plume and the
## hazard that burns whoever stands in it.

## The lava's surface over the ground under it (the vertex snap: a surface laid on the ground mustn't fight it).
const LAVA_LIFT := 0.22
const CHANNEL := 0.7
const LEVEE := 0.8
## The gully through the breach: full within the first (m off its axis), none past the second.
const BREACH_W := [9.0, 24.0]
## A flow within this angle of the breach is cold (crust: the way up stays clear); no hot lava this near the village, the dock or a path.
const COLD_ANGLE := 0.7
const COLD_SITE := 55.0
const COLD_PATH := 4.5
## The caldera's lava crescent: from this far out of the floor's middle to the inner wall, this half-angle round the back.
const CRESCENT_R0 := 25.0
const CRESCENT_HALF := 1.15
const GRID_CELL := 3.0
const GRID_BAND := 24.0
const VIS := 900.0
## The plants keep this far off a flow's edge.
const PLANT_PAD := 2.5


static func plan(isl, rng: RandomNumberGenerator) -> Dictionary:
	var r: float = isl.radius
	var lp := {}
	var c := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.0, 0.1)
	var foot := r * rng.randf_range(0.48, 0.56)
	# (a smaller island's cone lower, so the breach's gully keeps a walkable grade)
	var h := minf(rng.randf_range(70.0, 95.0), foot * 0.42)
	var rim := rng.randf_range(52.0, 60.0)
	var floor_r := rim - rng.randf_range(10.0, 14.0)
	var depth := rng.randf_range(25.0, 33.0)
	lp["cone"] = {"c": c, "foot": foot, "h": h, "rim": rim, "floor": floor_r, "depth": depth}
	var flows: Array = []
	var a0 := rng.randf() * TAU
	var n := rng.randi_range(3, 5)
	for k in range(n):
		var a := a0 + TAU * k / n + rng.randf_range(-0.35, 0.35)
		var d := rim + (foot - rim) * rng.randf_range(0.12, 0.32)
		var end := foot * rng.randf_range(0.82, 1.04)
		var pts := PackedVector2Array()
		var wob := 0.0
		var dir := Vector2.from_angle(a)
		var at := c + dir * d
		pts.append(at)
		while at.distance_to(c) < end and pts.size() < 40:
			wob = clampf(wob + rng.randf_range(-0.3, 0.3), -0.5, 0.5)
			var out := (at - c).normalized()
			at += (out + out.orthogonal() * wob).normalized() * 8.0
			pts.append(at)
		flows.append({"pts": pts, "w": rng.randf_range(5.0, 9.0), "a": a})
	lp["flows"] = flows
	lp["grid"] = _grid(flows, float(isl.half))
	var gully := FastNoiseLite.new()
	gully.seed = rng.randi()
	gully.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	gully.frequency = 0.03
	gully.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	gully.fractal_octaves = 3
	lp["gully"] = gully
	return lp


## The flows' distance on a GRID_CELL grid (and which flow is nearest), filled within GRID_BAND of them.
static func _grid(flows: Array, half: float) -> Dictionary:
	var n := int(ceil(half * 2.0 / GRID_CELL)) + 1
	var d := PackedFloat32Array()
	d.resize(n * n)
	d.fill(GRID_BAND)
	var which := PackedByteArray()
	which.resize(n * n)
	for fi in range(flows.size()):
		var pts: PackedVector2Array = flows[fi]["pts"]
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
					if dd < d[i]:
						d[i] = dd
						which[i] = fi
	return {"n": n, "half": half, "d": d, "which": which}


## [distance from p to the nearest flow's middle line, that flow's index] (bilinear distance; GRID_BAND past them).
static func flow_near(lp: Dictionary, p: Vector2) -> Array:
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
	var which: PackedByteArray = g["which"]
	return [lerpf(lerpf(d[i], d[i + 1], tx), lerpf(d[i + n], d[i + n + 1], tx), tz), which[int(roundf(fz)) * n + int(roundf(fx))]]


## 0..1: how much of p is a flow's channel and levees (`pad` m further out).
static func _on_flow(lp: Dictionary, p: Vector2, pad := 0.0) -> float:
	var near := flow_near(lp, p)
	var hw: float = float(lp["flows"][int(near[1])]["w"]) * 0.5 + 1.5 + pad
	return 1.0 - smoothstep(hw, hw + 2.5, float(near[0]))


## The breach's bearing from the cone's middle: toward the village once it's placed (Vector2.ZERO before).
static func breach_dir(isl, lp: Dictionary) -> Vector2:
	if not isl.sites.has("village"):
		return Vector2.ZERO
	var v: Vector2 = isl.sites["village"] - (lp["cone"]["c"] as Vector2)
	return v.normalized() if v.length() > 1.0 else Vector2(1, 0)


## 0..1: how much p is in the breach's gully (its axis from the floor out along breach_dir).
static func _breach(isl, lp: Dictionary, p: Vector2) -> float:
	var bd := breach_dir(isl, lp)
	if bd == Vector2.ZERO:
		return 0.0
	var cone: Dictionary = lp["cone"]
	var v: Vector2 = p - (cone["c"] as Vector2)
	var along := v.dot(bd)
	if along < float(cone["floor"]) * 0.5:
		return 0.0
	return 1.0 - smoothstep(BREACH_W[0], BREACH_W[1], absf(v.cross(bd)))


## The cone's height over the base land at p, before the breach: outer flanks from the foot to the rim, the inner
## wall down to the caldera's floor.
static func _cone(lp: Dictionary, p: Vector2) -> float:
	var cone: Dictionary = lp["cone"]
	var d := p.distance_to(cone["c"])
	var h: float = cone["h"]
	var rim: float = cone["rim"]
	var fl: float = cone["floor"]
	var low := h - float(cone["depth"])
	if d >= float(cone["foot"]):
		return 0.0
	if d >= rim:
		var t := (d - rim) / (float(cone["foot"]) - rim)
		var gully: FastNoiseLite = lp["gully"]
		return h * pow(1.0 - t, 1.3) - maxf(gully.get_noise_2d(p.x, p.y), 0.0) * 7.0 * sin(t * PI)
	if d >= fl:
		return lerpf(low, h, smoothstep(fl, rim, d))
	return low


## The gully through the breach: the caldera's floor height out to the floor's edge, then down at an even grade to the foot.
static func _ramp(lp: Dictionary, p: Vector2) -> float:
	var cone: Dictionary = lp["cone"]
	var d := p.distance_to(cone["c"])
	var low := float(cone["h"]) - float(cone["depth"])
	var fl: float = cone["floor"]
	return low * (1.0 - clampf((d - fl) / (float(cone["foot"]) * 0.9 - fl), 0.0, 1.0))


static func shape(isl, p: Vector2, h: float) -> float:
	var lp: Dictionary = isl.land_plan
	# (by the distance in from the coast, not the base's height: the cone stands on low ground, and a factor that
	# wavered with the base's noise put steps in its flanks)
	var land := smoothstep(0.0, 30.0, -float(isl._coast_t(p)))
	if land <= 0.0:
		return h
	var cone := _cone(lp, p)
	var br := _breach(isl, lp, p)
	if br > 0.0:
		cone = lerpf(cone, _ramp(lp, p), br)
	# (the base raises a cliff's whole bearing to the cliff's height, which tears the middle where the bearings meet:
	# under the cone it's taken back out, as on the snow's peak)
	var mid := 1.0 - smoothstep(0.15, 0.4, p.length() / float(isl.radius))
	var s := h - (float(isl._cliff_h) - float(isl._def["base"])) * float(isl._cliff(atan2(p.y, p.x))) * mid * land + cone * land
	var near := flow_near(lp, p)
	var hw: float = float(lp["flows"][int(near[1])]["w"]) * 0.5
	var fd: float = near[0]
	if fd < hw + 4.0:
		s -= CHANNEL * (1.0 - smoothstep(hw * 0.6, hw, fd))
		s += LEVEE * (1.0 - absf(fd - hw - 1.0) / 2.0) if absf(fd - hw - 1.0) < 2.0 else 0.0
	return s


## Where the forge town goes: off the cone, pushed out along the way from its middle while there's land.
static func village_at(isl, p: Vector2) -> Vector2:
	return _off_cone(isl, p, 1.05, 40.0)


## The boss's ground is the caldera's floor; the summit's lookout stands on the rim beside the breach; the camp,
## the lair and the ruins keep to the lower flanks.
static func site_at(isl, site: String, p: Vector2) -> Vector2:
	var lp: Dictionary = isl.land_plan
	var cone: Dictionary = lp["cone"]
	match site:
		"boss":
			return cone["c"]
		"summit":
			var bd := breach_dir(isl, lp)
			return (cone["c"] as Vector2) + bd.rotated(0.75) * (float(cone["rim"]) + 2.0)
		"camp", "lair", "ruins":
			# (off the breach's gully too: a site's levelled ground on it would be a step in the way up)
			var bd := breach_dir(isl, lp)
			var v: Vector2 = p - (cone["c"] as Vector2)
			if v.dot(bd) > 0.0 and absf(v.cross(bd)) < BREACH_W[1] + 30.0:
				p = (cone["c"] as Vector2) + v.rotated(0.8 if v.cross(bd) < 0.0 else -0.8)
			return _off_cone(isl, p, 0.95, 30.0)
	return p


static func _off_cone(isl, p: Vector2, k: float, inset: float) -> Vector2:
	var cone: Dictionary = isl.land_plan["cone"]
	var c: Vector2 = cone["c"]
	var dir := (p - c).normalized() if p.distance_to(c) > 1.0 else Vector2(1, 0)
	var q := p
	while q.distance_to(c) < float(cone["foot"]) * k and isl._coast_t(q + dir * 4.0) < -inset:
		q += dir * 4.0
	return q


## Sparse: nothing on the cone's upper flanks or in the caldera, nothing on the flows.
static func cover(isl, p: Vector2, c: float) -> float:
	var lp: Dictionary = isl.land_plan
	var cone: Dictionary = lp["cone"]
	var high := 1.0 - smoothstep(0.5, 0.85, p.distance_to(cone["c"]) / float(cone["foot"]))
	return c * (1.0 - _on_flow(lp, p, PLANT_PAD)) * (1.0 - high)


## [plants, rocks]: no plants on the flows or high on the cone; more rocks on its flanks.
static func growth(isl, p: Vector2) -> Vector2:
	var lp: Dictionary = isl.land_plan
	var cone: Dictionary = lp["cone"]
	var t := p.distance_to(cone["c"]) / float(cone["foot"])
	var flow := 1.0 - _on_flow(lp, p, PLANT_PAD)
	var bare := flow * smoothstep(0.55, 0.8, t)
	for e in isl.interiors:
		if p.distance_to(e["mouth"]) < 9.0:
			bare = 0.0
	var stony := 1.0 + 2.5 * (1.0 - smoothstep(0.5, 1.0, t))
	return Vector2(bare, flow * stony * (0.0 if t < 0.3 else 1.0))


## Basalt (the rock layer) over the cone's upper flanks, its inner walls and the flows' beds; ash the rest.
static func paint(isl, p: Vector2, _h: float, splat: Color) -> Color:
	var lp: Dictionary = isl.land_plan
	var cone: Dictionary = lp["cone"]
	var t := p.distance_to(cone["c"]) / float(cone["foot"])
	var rock := smoothstep(0.7, 0.4, t) * 0.75
	var d := p.distance_to(cone["c"])
	if d < float(cone["rim"]) + 3.0 and d > float(cone["floor"]) - 2.0:
		rock = 1.0
	rock = maxf(rock, _on_flow(lp, p) * 0.9)
	splat.g = maxf(splat.g, rock * (1.0 - splat.r))
	return splat


static func steps(isl) -> Array:
	return [["volcanic lava", func(): _lava(isl)], ["volcanic plume", func(): _plume(isl)], ["volcanic eruptions", func(): _eruptions(isl)]]


## The rumbles and bursts (volcanic_eruptions.gd).
static func _eruptions(isl) -> void:
	var e := Node3D.new()
	e.set_script(load("res://scripts/island/themes/volcanic_eruptions.gd"))
	e.name = "VolcanicEruptions"
	e.set("isl", isl)
	isl.add_child(e)


## Whether island point q is hot lava along flow `f` (its index): not on a cold flow, a path's crossing, near the
## village or the dock, or a place or cave's ground.
static func hot_at(isl, f: int, q: Vector2) -> bool:
	var lp: Dictionary = isl.land_plan
	var fl: Dictionary = lp["flows"][f]
	var bd := breach_dir(isl, lp)
	if bd != Vector2.ZERO and absf(angle_difference(float(fl["a"]), bd.angle())) < COLD_ANGLE:
		return false
	for s in ["village", "dock"]:
		if isl.sites.has(s) and q.distance_to(isl.sites[s]) < COLD_SITE:
			return false
	if isl.path_dist(q) < COLD_PATH:
		return false
	for pl in isl.places:
		if q.distance_to(pl["at"]) < float(pl.get("r", 0.0)) + 4.0:
			return false
	for e in isl.interiors:
		if q.distance_to(e["at"]) < float(e["radius"]) + 4.0:
			return false
	return true


## In the caldera's lava crescent?
static func in_crescent(isl, q: Vector2) -> bool:
	var lp: Dictionary = isl.land_plan
	var cone: Dictionary = lp["cone"]
	var v: Vector2 = q - (cone["c"] as Vector2)
	var bd := breach_dir(isl, lp)
	return v.length() > CRESCENT_R0 and v.length() < float(cone["floor"]) - 1.0 and absf(angle_difference(v.angle(), (-bd).angle())) < CRESCENT_HALF


## Whether a walker at island point q (feet at y) is standing in hot lava.
static func burning(isl, q: Vector2, y: float) -> bool:
	if y > float(isl.hv(q)) + 1.0:
		return false
	var lp: Dictionary = isl.land_plan
	if in_crescent(isl, q):
		return true
	var near := flow_near(lp, q)
	if float(near[0]) > float(lp["flows"][int(near[1])]["w"]) * 0.5 - 0.6:
		return false
	return hot_at(isl, int(near[1]), q)


## The lava: each flow's hot stretches as a strip following the ground (a crust where it's cold, the lobe at its end
## crusted over), the caldera's crescent; one mesh for the hot, one for the crust; a hazard node to burn in it.
static func _lava(isl) -> void:
	var lp: Dictionary = isl.land_plan
	var hot := MeshBuilder.new()
	var crust := MeshBuilder.new()
	var lava := KitLandmarks.flow_mat("volcanic_lava", Color(1.0, 0.62, 0.32), Vector2(0.0, 0.08), 2.4)
	var cold := PSXMat.lit("volcanic_basalt", Color(0.75, 0.68, 0.66), {"affine": 0.6})
	for f in range(lp["flows"].size()):
		var fl: Dictionary = lp["flows"][f]
		var pts: PackedVector2Array = fl["pts"]
		var hw: float = float(fl["w"]) * 0.5
		var v := 0.0
		for j in range(pts.size() - 1):
			var a := pts[j]
			var b := pts[j + 1]
			var side := (b - a).normalized().orthogonal()
			var t := float(j) / (pts.size() - 1)
			# (narrowing to the vent at the top, spreading into the lobe at the end)
			var wa := hw * (0.6 + 0.4 * minf(t * 4.0, 1.0)) * (1.0 + maxf(t - 0.85, 0.0) * 3.0)
			var t1 := float(j + 1) / (pts.size() - 1)
			var wb := hw * (0.6 + 0.4 * minf(t1 * 4.0, 1.0)) * (1.0 + maxf(t1 - 0.85, 0.0) * 3.0)
			var mid := a.lerp(b, 0.5)
			var is_hot := j < pts.size() - 3 and hot_at(isl, f, mid)
			var mb := hot if is_hot else crust
			var m: Material = lava if is_hot else cold
			var q := [a - side * wa, a + side * wa, b + side * wb, b - side * wb]
			var y := func(p2: Vector2) -> float: return float(isl.hv(p2)) + LAVA_LIFT
			var dv := a.distance_to(b) * 0.12
			mb.add_quad(m, Vector3(q[0].x, y.call(q[0]), q[0].y), Vector3(q[1].x, y.call(q[1]), q[1].y), Vector3(q[2].x, y.call(q[2]), q[2].y), Vector3(q[3].x, y.call(q[3]), q[3].y),
				Vector2(0, v), Vector2(wa * 0.24, v), Vector2(wb * 0.24, v + dv), Vector2(0, v + dv), Color.WHITE, Vector3.UP)
			v += dv
	# the caldera's crescent: a fan of quads following the floor
	var cone: Dictionary = lp["cone"]
	var c: Vector2 = cone["c"]
	var back := (-breach_dir(isl, lp)).angle()
	var rings := 4
	var segs := 16
	for i in range(segs):
		for k in range(rings):
			var a0 := back - CRESCENT_HALF + 2.0 * CRESCENT_HALF * i / segs
			var a1 := back - CRESCENT_HALF + 2.0 * CRESCENT_HALF * (i + 1) / segs
			var r0 := lerpf(CRESCENT_R0, float(cone["floor"]) - 1.0, float(k) / rings)
			var r1 := lerpf(CRESCENT_R0, float(cone["floor"]) - 1.0, float(k + 1) / rings)
			var ps := [c + Vector2.from_angle(a0) * r0, c + Vector2.from_angle(a1) * r0, c + Vector2.from_angle(a1) * r1, c + Vector2.from_angle(a0) * r1]
			var vs: Array = []
			for p2 in ps:
				vs.append(Vector3(p2.x, float(isl.hv(p2)) + LAVA_LIFT, p2.y))
			hot.add_quad(lava, vs[0], vs[1], vs[2], vs[3], ps[0] * 0.12, ps[1] * 0.12, ps[2] * 0.12, ps[3] * 0.12, Color.WHITE, Vector3.UP)
	var node := Node3D.new()
	node.name = "VolcanicLava"
	for pair in [[hot, "Lava"], [crust, "Crust"]]:
		var mb: MeshBuilder = pair[0]
		if mb.is_empty():
			continue
		# (1.30) the cooled crust is walked on, not waded through (the hot flow stays the hazard you stand in)
		if pair[1] == "Crust":
			var body := StaticBody3D.new()
			body.name = "CrustCol"
			body.collision_layer = 1
			body.collision_mask = 0
			mb.faces_since({}, body)
			node.add_child(body)
		var mi := mb.to_instance(pair[1])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = VIS
		node.add_child(mi)
	var hz := Node3D.new()
	hz.set_script(load("res://scripts/island/themes/volcanic_hazard.gd"))
	hz.name = "LavaHazard"
	hz.set("isl", isl)
	node.add_child(hz)
	isl.add_child(node)


## The cone's plume: smoke rising out of the caldera, seen from the sea; embers over the lava.
static func _plume(isl) -> void:
	var lp: Dictionary = isl.land_plan
	var cone: Dictionary = lp["cone"]
	var c: Vector2 = cone["c"]
	var node := Node3D.new()
	node.name = "VolcanicPlume"
	isl.add_child(node)
	var y := float(isl.hv(c))
	# (high over the caldera's floor: a puff that size up close is a grey wall in front of the boss fight)
	var smoke := KitLandmarks.puffs(node, Vector3(c.x, y + 34.0, c.y), Color(0.56, 0.54, 0.52, 0.4), 14, 16.0, 3.2, 12.0)
	smoke.lifetime = 14.0
	smoke.visibility_range_end = 1600.0
	var back := c + (-breach_dir(isl, lp)) * (CRESCENT_R0 + 8.0)
	var embers := KitLandmarks.puffs(node, Vector3(back.x, float(isl.hv(back)) + 0.6, back.y), Color(1.0, 0.5, 0.15, 0.8), 10, 0.3, 2.4, 9.0)
	embers.visibility_range_end = 220.0
