class_name ForestPlaces
extends RefCounted
## The forest's places on the theme place hooks (ForestTheme.place_kind / plan_places / plan_place /
## place_steps): the lumber town's sawmill on its river (a water wheel turning in the stream, the log flume
## down the hill to it, log piles and timber stacks), and out in the woods the charcoal burners' camps
## (earth kilns smoking) and a hunter's lodge (antlers over the door, hides on their frames, a cache).
## Plans are numbers (the worker); steps build under the place's node in place-local coordinates (+Z its face).

## Which chain set pieces and landmarks the forest's own kinds stand in for (ForestSetPieces). A set piece and a
## landmark never share a kind (an island gets one of each at most).
const KINDS := {"volcano_vent": "forest_castle", "old_fort": "forest_castle", "cenote": "forest_gorge", "sunken_village": "forest_gorge",
	"great_tree": "forest_hollow_tree"}
const LAND := preload("res://scripts/island/themes/forest_land.gd")
const MILL_R := 16.0
const CAMP_R := 10.0
const LODGE_R := 11.0
const VIS := 520.0


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _gy(ctx: KitContext, pl: Dictionary, x: float, z: float) -> float:
	return KitLandmarks.gy(ctx, pl, x, z)


static func _at(ctx: KitContext, pl: Dictionary, x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, _gy(ctx, pl, x, z) + up, z)


## The theme's places beyond the chain's: the sawmill by the town's river, then 1-3 camps and lodges in the woods.
static func plan_places(isl, avoid: Array) -> Array:
	var out: Array = []
	var mill := _plan_sawmill(isl, avoid)
	if not mill.is_empty():
		out.append(mill)
		avoid.append([mill["at"], mill["r"]])
	var rng := _rng(hash([int(isl.node["seed"]), "forest_camps"]))
	var kinds: Array = ["charcoal", "lodge", "charcoal"].slice(0, rng.randi_range(1, 3))
	var n := {}
	for kind in kinds:
		var r: float = CAMP_R if kind == "charcoal" else LODGE_R
		var pl := {}
		for tries in range(3):
			var spot := KitWilds._spot(isl, rng, avoid, r, 0.18, 4.0, 7.0, false)
			if spot.is_empty():
				break
			if LAND.wet(isl.land_plan, spot["at"], r + 4.0) <= 0.0:
				pl = spot
				break
		if pl.is_empty():
			continue
		n[kind] = int(n.get(kind, 0)) + 1
		pl["kind"] = "forest_%s" % kind if n[kind] == 1 else "forest_%s_%d" % [kind, n[kind]]
		KitLandmarks.level(isl, pl["at"], pl["y"], r * 0.75, r + 3.0)
		pl["keep"] = [[Vector2.ZERO, r * 0.8]]
		out.append(pl)
		avoid.append([pl["at"], pl["r"]])
	return out


## The sawmill: on the town's river bank 58-110 m from the town's middle (its own reserve keeps it off the houses),
## level ground a little over the water, facing the river (the wheel at +Z in the stream), the flume coming down
## from the highest ground behind it. {} where the river gives no room.
static func _plan_sawmill(isl, avoid: Array) -> Dictionary:
	if not isl.sites.has("village"):
		return {}
	var L: Dictionary = isl.land_plan
	var v: Vector2 = isl.sites["village"]
	var keep_off: Array = avoid.filter(func(e): return (e[0] as Vector2) != v)
	keep_off.append([v, 40.0])
	var best := {}
	var bs := INF
	for rv in L["rivers"]:
		var pts: PackedVector2Array = rv["pts"]
		var f: int = rv["falls"]
		var w: float = rv["w"]
		for k in range(2, pts.size() - 2):
			var sf: float = rv["surf"][k]
			if sf < LAND.FLOOR - 0.1 or (f > 0 and absi(k - f) < 5):
				continue
			var along := (pts[k + 1] - pts[k - 1]).normalized()
			var side := Vector2(-along.y, along.x)
			if side.dot(v - pts[k]) < 0.0:
				side = -side
			var c := pts[k] + side * (w + 6.5)
			var d := c.distance_to(v)
			if d < 58.0 or d > 110.0 or not KitLandmarks.clear_of(isl, c, 11.0, keep_off) or isl.reserved_in(c, 8.0) or isl.path_dist(c) < 5.0:
				continue
			var rise: float = isl.hv(c) - sf
			if rise < -0.5 or rise > 4.0 or LAND.river_dist(L, c) < w + 6.0:
				continue
			var score := absf(d - 70.0) + rise * 4.0
			if score < bs:
				bs = score
				best = {"at": c, "sf": sf, "side": side, "along": along, "w": w}
	if best.is_empty():
		return {}
	var c: Vector2 = best["at"]
	var side: Vector2 = best["side"]
	var face := -side
	var y: float = float(best["sf"]) + LAND.BANK + 0.45
	KitLandmarks.level(isl, c, y, 5.5, 8.0)
	# the flume: from the highest ground 26-40 m behind and to the side down to the river beside the wheel
	var top := Vector2.ZERO
	var th := -INF
	for k in range(14):
		var q := Vector2(lerpf(-14.0, 14.0, float(k % 7) / 6.0), -26.0 - 14.0 * float(k / 7))
		var at := c + _turn(face, q)
		var h: float = isl.hv(at)
		if h > th and isl.path_dist(at) > 2.0 and LAND.river_dist(L, at) > float(best["w"]) + 8.0:
			th = h
			top = q
	var keep: Array = [[Vector2(0, -0.5), 6.5], [Vector2(-7.5, -3.0), 3.0], [Vector2(-7.0, 3.5), 2.6], [Vector2(7.5, -2.5), 2.6]]
	var flume := {}
	if th - y > 2.5:
		var end := Vector2(5.5, 5.8)
		flume = {"from": top, "to": end, "drop": th - y}
		var n := int(top.distance_to(end) / 5.0)
		for k in range(n + 1):
			keep.append([top.lerp(end, float(k) / n), 2.0])
	return {"kind": "forest_sawmill", "at": c, "y": y, "face": face, "r": MILL_R, "keep": keep, "door": c + side * 10.0,
		"water": float(best["sf"]) - y, "river_w": best["w"], "flume": flume}


## Place-local (x, z) as an island offset for a place facing `face` (before its yaw is set).
static func _turn(face: Vector2, q: Vector2) -> Vector2:
	var v := Basis(Vector3.UP, KitContext.face_yaw(face)) * Vector3(q.x, 0.0, q.y)
	return Vector2(v.x, v.z)


static func plan(isl, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	return ForestSetPieces.plan(isl, kind, rng, avoid)


static func steps(isl, ctx: KitContext, pl: Dictionary) -> Array:
	var k := str(pl["kind"])
	if ["forest_gorge", "forest_castle", "forest_hollow_tree"].has(k):
		return ForestSetPieces.steps(isl, ctx, pl)
	if k == "forest_sawmill":
		return [func(): _mill(ctx, pl, KitLandmarks.place_node(ctx, pl)), func(): _mill_yard(isl, ctx, pl)]
	if k.begins_with("forest_charcoal"):
		return [func(): _charcoal(ctx, pl, KitLandmarks.place_node(ctx, pl))]
	if k.begins_with("forest_lodge"):
		return [func(): _lodge(isl, ctx, pl, KitLandmarks.place_node(ctx, pl))]
	push_error("ForestPlaces: no place %s" % k)
	return []


# ==========================================================================
# The sawmill
# ==========================================================================
## The mill house (timber frame and planks on a fieldstone footing, a steep shingle roof, the sash saw at its open
## end with a log on the carriage) and the water wheel turning in the river on its axle out of the wall.
static func _mill(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var body := KitLandmarks.body("Sawmill")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("forest_rock", Color.WHITE, {"affine": 0.6})
	var planks := PSXMat.lit("planks_weathered", Color(0.95, 0.88, 0.8))
	var beam := PSXMat.lit("planks_dark")
	var shingles := PSXMat.lit("shingles", Color.WHITE, {"affine": 0.7})
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	var bark := PSXMat.lit("bark", Color(0.9, 0.78, 0.64))
	var w := 8.0
	var d := 6.0
	var z0 := -0.5
	var h := 3.4
	var low := minf(minf(_gy(ctx, pl, -w * 0.5, z0 - d * 0.5), _gy(ctx, pl, w * 0.5, z0 + d * 0.5)), minf(_gy(ctx, pl, -w * 0.5, z0 + d * 0.5), _gy(ctx, pl, w * 0.5, z0 - d * 0.5)))
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, (low - 0.4 + 0.3) * 0.5, z0)), Vector3(w + 0.3, 0.3 - low + 0.4, d + 0.3), 0.6, Color(0.88, 0.88, 0.86), true, false)
	KitLandmarks.box_col(body, Vector3(w + 0.3, 0.3 - low + 0.4, d + 0.3), Vector3(0, (low - 0.4 + 0.3) * 0.5, z0))
	mb.add_box(planks, Transform3D(Basis(), Vector3(0, 0.36, z0)), Vector3(w, 0.12, d), 0.5, Color(0.8, 0.75, 0.68))
	# walls on three sides; the +X end is open onto the saw floor
	var fy := 0.42
	mb.add_box(planks, Transform3D(Basis(), Vector3(0, fy + h * 0.5, z0 - d * 0.5)), Vector3(w, h, 0.12), 0.6)
	mb.add_box(planks, Transform3D(Basis(), Vector3(-w * 0.5, fy + h * 0.5, z0)), Vector3(0.12, h, d), 0.6)
	for x in [-w * 0.5, -1.2]:
		var xw: float = (-1.2 - x) if x < -1.0 else 0.0
		if xw > 0.0:
			mb.add_box(planks, Transform3D(Basis(), Vector3(x + xw * 0.5, fy + h * 0.5, z0 + d * 0.5)), Vector3(xw, h, 0.12), 0.6)
	mb.add_box(planks, Transform3D(Basis(), Vector3(-1.2 + 0.0, fy + h - 0.5, z0 + d * 0.5)), Vector3(1.0, 1.0, 0.12), 0.6)
	mb.add_box(planks, Transform3D(Basis(), Vector3(1.6, fy + h * 0.5, z0 + d * 0.5)), Vector3(4.8 - 1.6 + 0.4, h, 0.12), 0.6)
	KitLandmarks.box_col(body, Vector3(w, h, 0.3), Vector3(0, fy + h * 0.5, z0 - d * 0.5))
	KitLandmarks.box_col(body, Vector3(0.3, h, d), Vector3(-w * 0.5, fy + h * 0.5, z0))
	KitLandmarks.box_col(body, Vector3(w * 0.5 - 1.5, h, 0.3), Vector3(-w * 0.25 - 0.85, fy + h * 0.5, z0 + d * 0.5))
	KitLandmarks.box_col(body, Vector3(3.6, h, 0.3), Vector3(2.2, fy + h * 0.5, z0 + d * 0.5))
	# its frame: posts at the corners and between, a rail under the eaves
	for x in [-w * 0.5, -w * 0.25, 0.0, w * 0.25, w * 0.5]:
		for z in [z0 - d * 0.5, z0 + d * 0.5]:
			mb.add_box(beam, Transform3D(Basis(), Vector3(x, fy + h * 0.5, z + signf(z - z0) * 0.08)), Vector3(0.22, h, 0.12), 0.8)
	for z in [z0 - d * 0.5, z0 + d * 0.5]:
		mb.add_box(beam, Transform3D(Basis(), Vector3(0, fy + h - 0.1, z + signf(z - z0) * 0.1)), Vector3(w + 0.2, 0.2, 0.14), 0.8)
		mb.add_box(beam, Transform3D(Basis(), Vector3(0, fy + 0.1, z + signf(z - z0) * 0.1)), Vector3(w + 0.2, 0.18, 0.14), 0.8)
	var rh := d * 0.5 * 1.05
	mb.add_gable_roof(shingles, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, fy + h, z0)), d, w, rh, 0.6, 0.7, Color.WHITE, planks)
	mb.add_box(beam, Transform3D(Basis(), Vector3(0, fy + h + rh + 0.06, z0)), Vector3(w + 1.4, 0.14, 0.22), 0.8)
	KitLandmarks.box_col(body, Vector3(w, rh * 0.7, d * 0.7), Vector3(0, fy + h + rh * 0.35, z0))
	# the sash saw at the open end: an upright frame, the blade, a log on the carriage running out of the door
	var sx := 2.6
	for z in [z0 - 0.7, z0 + 0.7]:
		mb.add_box(beam, Transform3D(Basis(), Vector3(sx, fy + 1.4, z)), Vector3(0.22, 2.8, 0.22), 0.8)
	mb.add_box(beam, Transform3D(Basis(), Vector3(sx, fy + 2.8, z0)), Vector3(0.24, 0.24, 1.7), 0.8)
	mb.add_box(iron, Transform3D(Basis(), Vector3(sx, fy + 1.4, z0)), Vector3(0.04, 1.6, 0.5), 1.0)
	for z in [z0 - 0.45, z0 + 0.45]:
		mb.add_box(beam, Transform3D(Basis(), Vector3(sx + 0.5, fy + 0.45, z)), Vector3(5.5, 0.16, 0.16), 0.8)
	ForestTown._log_x(mb, bark, PSXMat.flat(Color(0.8, 0.64, 0.44)), sx - 1.6, sx + 3.4, fy + 0.85, z0, 0.32)
	KitLandmarks.box_col(body, Vector3(5.2, 1.0, 1.2), Vector3(sx + 0.9, fy + 0.6, z0))
	# the wheel's axle out of the riverside wall, the bearing post in the stream
	var wy: float = float(pl["water"])
	var R := 2.5
	var wz := 7.4
	var wc := Vector3(0, wy + R * 0.62, wz)
	mb.add_cylinder(beam, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, wc.y, z0 + d * 0.5 - 0.2)), 0.16, 0.16, wz - (z0 + d * 0.5) + 1.4, 8, 0.8)
	for z in [z0 + d * 0.5 + 0.8, wz + 1.0]:
		mb.add_box(beam, Transform3D(Basis(), Vector3(0, (wy - 1.2 + wc.y) * 0.5, z)), Vector3(0.3, wc.y - wy + 1.4, 0.3), 0.8)
	KitLandmarks.box_col(body, Vector3(0.4, wc.y - wy + 1.4, 0.4), Vector3(0, (wy - 1.2 + wc.y) * 0.5, wz + 1.0))
	var mi := mb.to_instance("SawmillMesh")
	mi.visibility_range_end = VIS
	body.add_child(mi)
	node.add_child(body)
	# the wheel: two rims on spokes, paddles between, turning with the stream (game time)
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	wheel.position = wc
	var wm := MeshBuilder.new()
	var n := 12
	for s in [-0.45, 0.45]:
		for i in range(n):
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			Buildings.beam_between(wm, beam, Vector3(cos(a0) * R, sin(a0) * R, s), Vector3(cos(a1) * R, sin(a1) * R, s), 0.08)
		for i in range(6):
			var a := TAU * i / 6.0 + rng.randf() * 0.0
			Buildings.beam_between(wm, beam, Vector3(cos(a) * -R, sin(a) * -R, s), Vector3(cos(a) * R, sin(a) * R, s), 0.07)
	for i in range(n):
		var a := TAU * (i + 0.5) / n
		wm.add_box(planks, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a), sin(a), 0) * R * 0.92), Vector3(0.5, 0.06, 1.0), 1.0, Color(0.85, 0.8, 0.72))
	wm.add_cylinder(beam, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.6)), 0.32, 0.32, 1.2, 8, 0.8)
	var wmi := wm.to_instance("WheelMesh")
	wmi.visibility_range_end = 300.0
	wheel.add_child(wmi)
	node.add_child(wheel)
	var tw := wheel.create_tween().set_loops()
	tw.tween_property(wheel, "rotation:z", -TAU, 9.0).from(0.0)
	# foam where the paddles meet the water, the race's rush
	var foam := MeshBuilder.new()
	KitLandmarks.water_disc(foam, KitLandmarks.flow_mat("water", Color(0.95, 0.98, 1.0, 0.7), Vector2(0.2, 0.3)), Vector3(0, wy + 0.05, wz), 1.6, 10, 0.5)
	node.add_child(KitLandmarks.far_off(foam.to_instance("WheelFoam"), 200.0))
	KitLandmarks.loop_sound(node, "hull_rush_loop.wav", wc, 5.0, 40.0, -10.0, 1.2)
	KitLights.light(ctx, node, Vector3(-1.5, fy + 2.2, z0 + d * 0.5 + 0.4), 1.2, 9.0)


## The yard: log piles waiting to be sawn, sawn timber stacked to dry, sawdust, a cart, and the flume down the hill.
static func _mill_yard(isl, ctx: KitContext, pl: Dictionary) -> void:
	var rng := _rng(int(pl["seed"]) + 3)
	var node := KitLandmarks.node_of(ctx, pl)
	var body := KitLandmarks.body("MillYard")
	var mb := MeshBuilder.new()
	ForestTown.log_pile(mb, body, _at(ctx, pl, -7.5, -3.0, 0.0), PI * 0.5 + rng.randf_range(-0.2, 0.2), 4, 4.5, rng, 0.24)
	ForestTown.log_pile(mb, body, _at(ctx, pl, 7.5, -2.5, 0.0), rng.randf_range(-0.2, 0.2), 3, 3.8, rng, 0.22)
	# sawn boards drying in a crossed stack
	var boards := PSXMat.lit("planks", Color(0.95, 0.86, 0.7))
	var bp := _at(ctx, pl, -7.0, 3.5)
	for k in range(7):
		var yaw := 0.0 if k % 2 == 0 else PI * 0.5
		for j in range(4):
			var o := Basis(Vector3.UP, yaw) * Vector3((j - 1.5) * 0.45, 0, 0)
			mb.add_box(boards, Transform3D(Basis(Vector3.UP, yaw), bp + o + Vector3.UP * (0.08 + k * 0.1)), Vector3(0.3, 0.06, 2.6), 0.6)
	KitLandmarks.box_col(body, Vector3(2.6, 0.8, 2.6), bp + Vector3.UP * 0.4)
	var dust := PSXMat.flat(Color(0.86, 0.74, 0.52))
	for k in range(10):
		var q := Vector2(rng.randf_range(2.0, 7.0), rng.randf_range(-3.0, 1.5))
		mb.add_blob(dust, Transform3D(Basis(), _at(ctx, pl, q.x, q.y, -0.05)), Vector3(rng.randf_range(0.4, 0.9), 0.08, rng.randf_range(0.3, 0.7)), rng, 0.2, 2, 5, 1.0, Color.WHITE, 0.0)
	var cart := KitVillage.handcart()
	cart.position = _at(ctx, pl, 5.5, -6.0)
	cart.rotation.y = rng.randf() * TAU
	node.add_child(cart)
	var fl: Dictionary = pl["flume"]
	if not fl.is_empty():
		_flume(ctx, pl, mb, body, fl["from"], fl["to"], rng)
	var mi := mb.to_instance("YardMesh")
	mi.visibility_range_end = VIS
	body.add_child(mi)
	node.add_child(body)


## The log flume: a plank V-trough on trestles from the landing up the hill down to the river beside the wheel,
## water running in it, a log or two riding it, logs waiting at its head.
static func _flume(ctx: KitContext, pl: Dictionary, mb: MeshBuilder, body: StaticBody3D, a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	var planks := PSXMat.lit("planks_weathered", Color(0.9, 0.84, 0.76))
	var post := PSXMat.lit("bark", Color(0.85, 0.72, 0.6))
	var y0 := _gy(ctx, pl, a.x, a.y) + 1.1
	var y1 := float(pl["water"]) + 1.3
	var n := maxi(int(a.distance_to(b) / 3.0), 2)
	var dir := (b - a).normalized()
	var side := Vector3(-dir.y, 0, dir.x)
	var pts := PackedVector3Array()
	for k in range(n + 1):
		var t := float(k) / n
		var q := a.lerp(b, t)
		pts.append(Vector3(q.x, lerpf(y0, y1, t), q.y))
	for k in range(n):
		var p0 := pts[k]
		var p1 := pts[k + 1]
		for s in [-1.0, 1.0]:
			var o: Vector3 = side * 0.38 * s
			var lift := Vector3.UP * 0.32
			mb.add_quad(planks, p0 + o * 0.25, p1 + o * 0.25, p1 + o + lift, p0 + o + lift, Vector2(0, 0), Vector2(1.5, 0), Vector2(1.5, 0.4), Vector2(0, 0.4), Color.WHITE, (o.normalized() * -1.0 + Vector3.UP).normalized())
			mb.add_quad(planks, p0 + o + lift, p1 + o + lift, p1 + o * 0.25, p0 + o * 0.25, Vector2(0, 0), Vector2(1.5, 0), Vector2(1.5, 0.4), Vector2(0, 0.4), Color(0.7, 0.7, 0.7), (o.normalized() - Vector3.UP).normalized())
	for k in range(n + 1):
		var p := pts[k]
		var g := _gy(ctx, pl, p.x, p.z)
		if p.y - g < 0.3:
			continue
		for s in [-1.0, 1.0]:
			var foot: Vector3 = p + side * 0.55 * s
			mb.add_cylinder(post, Transform3D(Basis(), Vector3(foot.x, g - 0.2, foot.z)), 0.08, 0.07, p.y - g + 0.25, 5, 0.8)
		Buildings.beam_between(mb, post, p + side * 0.6 + Vector3.DOWN * 0.1, p - side * 0.6 + Vector3.DOWN * 0.1, 0.06)
		if p.y - g > 2.0:
			Buildings.beam_between(mb, post, Vector3(p.x, g + 0.3, p.z) + side * 0.55, p - side * 0.55 + Vector3.DOWN * 0.2, 0.05)
	var water := PackedVector3Array()
	for p in pts:
		water.append(p + Vector3.UP * 0.12)
	KitLandmarks.ribbon(mb, KitLandmarks.flow_mat("water", ctx.style["water_tint"], Vector2(0.0, -1.4)), water, 0.42, 0.42, side, Vector3.UP, 0.5)
	var bark := PSXMat.lit("bark", Color(0.9, 0.78, 0.64))
	var ends := PSXMat.flat(Color(0.8, 0.64, 0.44))
	for t in [0.35, 0.7]:
		var p := pts[0].lerp(pts[n], t)
		var dd := (pts[n] - pts[0]).normalized()
		mb.add_cylinder(bark, Transform3D(Basis(Quaternion(Vector3.UP, dd)), p + Vector3.UP * 0.25 - dd * 1.1), 0.18, 0.17, 2.2, 6, 0.6, Color.WHITE, true, true, true, ends)
	ForestTown.log_pile(mb, body, Vector3(a.x, _gy(ctx, pl, a.x, a.y), a.y) - Vector3(dir.x, 0, dir.y) * 2.5, atan2(dir.x, dir.y) + PI * 0.5, 3, 3.4, rng, 0.2)
	for k in range(0, n + 1, 3):
		var g := _gy(ctx, pl, pts[k].x, pts[k].z)
		if pts[k].y - g > 0.3:
			KitLandmarks.box_col(body, Vector3(0.3, pts[k].y - g + 0.4, 0.3), Vector3(pts[k].x, (pts[k].y + g) * 0.5, pts[k].z) + side * 0.55)


# ==========================================================================
# In the woods
# ==========================================================================
## The charcoal burners' camp: earth-covered kilns smoking (one glowing at a vent), one stacked but not yet covered,
## cordwood, the burners' bark lean-to, a fire, sacks of charcoal.
static func _charcoal(ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var body := KitLandmarks.body("CharcoalCamp")
	var mb := MeshBuilder.new()
	var earth := PSXMat.lit("forest_dirt", Color(0.6, 0.56, 0.52), {"affine": 0.6})
	var bark := PSXMat.lit("bark", Color(0.9, 0.78, 0.64))
	var ends := PSXMat.flat(Color(0.8, 0.64, 0.44))
	var ember := PSXMat.glow(Color(1.0, 0.45, 0.15), 2.0)
	var kilns := rng.randi_range(2, 3)
	for k in range(kilns):
		var a := TAU * k / kilns + rng.randf_range(-0.3, 0.3)
		var q := Vector2(cos(a), sin(a)) * rng.randf_range(3.5, 5.0)
		var r := rng.randf_range(1.6, 2.2)
		var at := _at(ctx, pl, q.x, q.y, -0.2)
		if k == kilns - 1 and rng.randf() < 0.6:
			# stacked billets in a cone, not yet covered
			for ring in range(4):
				var rr := r * (1.0 - ring * 0.24)
				var m := int(rr * 5.0)
				for i in range(m):
					var b := TAU * i / m
					var dir := Vector3(cos(b), 0, sin(b))
					mb.add_cylinder(bark, Transform3D(Basis(Quaternion(Vector3.UP, (dir * 0.25 + Vector3.UP).normalized())), at + dir * rr * 0.7 + Vector3.UP * ring * 0.5), 0.08, 0.08, 0.7, 5, 1.0, Color.WHITE.darkened(rng.randf() * 0.2), true, false, true, ends)
		else:
			mb.add_blob(earth, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(r, r * 0.68, r), rng, 0.1, 4, 9, 0.5, Color.WHITE, 0.0)
			mb.add_box(ember, Transform3D(Basis(Vector3.UP, a), at + Vector3(cos(a) * r * 0.9, 0.3, sin(a) * r * 0.9)), Vector3(0.24, 0.16, 0.1), 1.0)
			KitLandmarks.puffs(node, at + Vector3.UP * (r * 0.68 + 0.1), Color(0.55, 0.52, 0.5, 0.4), 6, 1.4, 0.7, 0.4)
		KitLandmarks.cyl_col(body, r * 0.9, r * 0.6, at + Vector3.UP * r * 0.3)
	ForestTown.log_pile(mb, body, _at(ctx, pl, -5.5, -3.0), rng.randf() * TAU, 3, 2.6, rng, 0.14)
	# the lean-to: bark slabs on a ridge pole between two forked posts
	var lt := _at(ctx, pl, 1.0, -6.0)
	var yaw := rng.randf_range(-0.3, 0.3)
	var bb := Basis(Vector3.UP, yaw)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(bark, Transform3D(bb, lt + bb * Vector3(s * 1.4, -0.2, 0)), 0.08, 0.07, 1.9, 5, 0.8)
	mb.add_cylinder(bark, Transform3D(bb * Basis(Vector3.BACK, PI * 0.5), lt + bb * Vector3(1.6, 1.65, 0)), 0.07, 0.07, 3.2, 5, 0.8)
	for i in range(7):
		var x := -1.35 + i * 0.45
		mb.add_box(bark, Transform3D(bb * Basis(Vector3.RIGHT, 0.85), lt + bb * Vector3(x, 0.85, -0.75)), Vector3(0.44, 0.06, 2.3), 0.6, Color.WHITE.darkened(rng.randf() * 0.2))
	KitLandmarks.box_col_xf(body, Vector3(3.0, 1.6, 1.6), Transform3D(bb, lt + bb * Vector3(0, 0.8, -0.7)))
	var sack := PSXMat.lit("canvas", Color(0.42, 0.38, 0.34))
	for i in range(rng.randi_range(3, 5)):
		var q := Vector2(-2.0 + i * 0.6, -4.2 + rng.randf_range(-0.3, 0.3))
		mb.add_blob(sack, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), _at(ctx, pl, q.x, q.y, 0.3)), Vector3(0.32, 0.38, 0.28), rng, 0.15, 3, 6, 0.8)
	var coal := PSXMat.flat(Color(0.1, 0.1, 0.11))
	for i in range(8):
		var q := Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(-1.5, 2.5))
		mb.add_blob(coal, Transform3D(Basis(), _at(ctx, pl, q.x, q.y, -0.05)), Vector3(0.5, 0.06, 0.4), rng, 0.3, 2, 5, 1.0, Color.WHITE, 0.0)
	var mi := mb.to_instance("CampMesh")
	mi.visibility_range_end = VIS
	body.add_child(mi)
	node.add_child(body)
	KitCamps.campfire(ctx.under(node), KitLandmarks.lp(pl, 0.5, -3.2), 1.0)
	KitLights.light(ctx, node, _at(ctx, pl, 0.5, -3.2, 0.8), 1.4, 9.0)


## The hunter's lodge: a log cabin with antlers over its door, hides stretched on frames, a deer hung from a pole,
## a skinning bench, a cache of the hunter's takings.
static func _lodge(isl, ctx: KitContext, pl: Dictionary, node: Node3D) -> void:
	var rng := _rng(int(pl["seed"]))
	var cabin := ForestTown.log_cabin(rng.randi(), rng.randf_range(5.2, 6.2))
	cabin.position = _at(ctx, pl, 0, -2.5)
	node.add_child(cabin)
	var body := KitLandmarks.body("LodgeYard")
	var mb := MeshBuilder.new()
	var bone := PSXMat.flat(Color(0.86, 0.8, 0.68))
	var wood := PSXMat.lit("bark", Color(0.85, 0.72, 0.6))
	var hide := PSXMat.lit("leather", Color(0.78, 0.6, 0.42))
	# antlers over the door
	var door := cabin.position + Vector3(0, 2.75, cabin.get_node("Door").position.z - 0.85)
	for s in [-1.0, 1.0]:
		var tip := door + Vector3(s * 0.8, 0.7, 0.1)
		var pts := MeshBuilder.curve_points(door + Vector3(s * 0.1, 0, 0), door + Vector3(s * 0.6, 0.1, 0.15), tip, 5)
		mb.add_tube(bone, pts, 0.05, 0.02, 4, 1.0)
		for t in [1, 3]:
			mb.add_tube(bone, PackedVector3Array([pts[t], pts[t] + Vector3(s * 0.05, 0.3, 0.1)]), 0.03, 0.012, 4, 1.0)
	mb.add_blob(bone, Transform3D(Basis(), door + Vector3(0, -0.1, 0.05)), Vector3(0.12, 0.1, 0.14), rng, 0.05, 2, 5)
	# hides on their frames
	for k in range(rng.randi_range(2, 3)):
		var q := Vector2(-4.5 + k * 1.6, 2.5 + rng.randf_range(-0.4, 0.4))
		var at := _at(ctx, pl, q.x, q.y)
		var yaw := rng.randf_range(-0.3, 0.3)
		var b := Basis(Vector3.UP, yaw)
		for s in [-1.0, 1.0]:
			mb.add_cylinder(wood, Transform3D(b * Basis(Vector3.BACK, s * 0.12), at + b * Vector3(s * 0.7, -0.1, 0)), 0.04, 0.04, 2.0, 4, 1.0)
		mb.add_cylinder(wood, Transform3D(b * Basis(Vector3.BACK, PI * 0.5), at + b * Vector3(0.85, 1.85, 0)), 0.035, 0.035, 1.7, 4, 1.0)
		mb.add_quad(hide, at + b * Vector3(-0.55, 0.5, 0), at + b * Vector3(0.55, 0.5, 0), at + b * Vector3(0.6, 1.7, 0), at + b * Vector3(-0.6, 1.7, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Color.WHITE, b * Vector3.BACK)
		mb.add_quad(hide, at + b * Vector3(0.55, 0.5, -0.01), at + b * Vector3(-0.55, 0.5, -0.01), at + b * Vector3(-0.6, 1.7, -0.01), at + b * Vector3(0.6, 1.7, -0.01), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Color(0.8, 0.8, 0.8), b * Vector3.FORWARD)
		KitLandmarks.box_col_xf(body, Vector3(1.5, 2.0, 0.2), Transform3D(b, at + Vector3.UP))
	# a deer hung by its hind legs from a pole between two posts, the skinning bench under it
	var dp := _at(ctx, pl, 4.5, 2.0)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(wood, Transform3D(Basis(), dp + Vector3(s * 1.1, -0.1, 0)), 0.07, 0.06, 2.6, 5, 0.8)
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), dp + Vector3(1.3, 2.4, 0)), 0.05, 0.05, 2.6, 5, 0.8)
	var fur := PSXMat.lit("fur", Color(0.62, 0.42, 0.28))
	mb.add_blob(fur, Transform3D(Basis(), dp + Vector3(0, 1.55, 0)), Vector3(0.28, 0.6, 0.25), rng, 0.1, 3, 6, 0.6)
	mb.add_blob(fur, Transform3D(Basis(), dp + Vector3(0, 0.85, 0.05)), Vector3(0.12, 0.22, 0.15), rng, 0.1, 3, 5, 0.6)
	for s in [-1.0, 1.0]:
		mb.add_cylinder(fur, Transform3D(Basis(Vector3.BACK, s * 0.15), dp + Vector3(s * 0.1, 2.0, 0)), 0.05, 0.035, 0.42, 4, 1.0)
	KitLandmarks.box_col(body, Vector3(2.6, 2.6, 0.4), dp + Vector3(0, 1.3, 0))
	var planks := PSXMat.lit("planks_dark")
	mb.add_box(planks, Transform3D(Basis(), dp + Vector3(0, 0.75, 1.0)), Vector3(1.6, 0.1, 0.6), 1.0)
	for x in [-0.7, 0.7]:
		mb.add_box(planks, Transform3D(Basis(), dp + Vector3(x, 0.36, 1.0)), Vector3(0.08, 0.72, 0.5), 1.0)
	var mi := mb.to_instance("LodgeMesh")
	mi.visibility_range_end = VIS
	body.add_child(mi)
	node.add_child(body)
	KitCamps.campfire(ctx.under(node), KitLandmarks.lp(pl, 0.0, 4.0), 1.0)
	KitLights.light(ctx, node, _at(ctx, pl, 0.0, 4.0, 0.8), 1.4, 9.0)
	KitLandmarks.chest(ctx, pl, _at(ctx, pl, -2.6, 0.2), PI, str(pl["kind"]) + "_cache", KitLandmarks.loot(isl, rng, false), 0.85)
