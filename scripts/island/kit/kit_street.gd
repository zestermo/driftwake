class_name KitStreet
extends RefCounted
## A town's streets and its hillside (Brinehollow's market street and upper town, 2026-10-17):
## shopfronts (a KitContext.house with its awning and sign, a counter of wares beside the door,
## "Vendor" behind it and "Customer" before it), street stalls of their own (a barrow and a rug laid
## with wares, under a parasol), shade cloths strung across a street, stone stairs (steps, side
## curbs, one slanted collider a flight) and retaining walls along a terrace's edge. All in island
## space; the meshes merged per piece, ranged, small ones unshadowed.

const RANGE := 150.0


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


static func _box(body: Node3D, size: Vector3, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = xf
	body.add_child(cs)


static func _marker(parent: Node3D, n: String, p: Vector3, yaw := 0.0) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = p
	m.rotation.y = yaw
	parent.add_child(m)


static func _ranged(mi: GeometryInstance3D, shadow := true) -> GeometryInstance3D:
	mi.visibility_range_end = RANGE
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Wares on a surface `y` up at local (x, z) over `w` x `d` (into mb): baskets of the style's goods,
## a stack of bolts or jars by kind.
static func _wares(mb: MeshBuilder, kind: String, c: Vector3, w: float, d: float, goods: Array, rng: RandomNumberGenerator) -> void:
	match kind:
		"cloth":
			for k in range(int(w / 0.45)):
				var col: Color = [Color(0.7, 0.2, 0.18), Color(0.2, 0.35, 0.6), Color(0.85, 0.75, 0.4), Color(0.3, 0.5, 0.3)][(k + rng.randi()) % 4]
				mb.add_cylinder(PSXMat.lit("fabric", col), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(-w * 0.5 + 0.25 + k * 0.45, 0.12, -d * 0.42)),
					0.12, 0.12, d * 0.85, 6, 1.0, Color.WHITE, true, true)
		"pots":
			var clay := PSXMat.lit("plaster", Color(0.72, 0.42, 0.28))
			for k in range(int(w / 0.4)):
				var s := rng.randf_range(0.8, 1.2)
				mb.add_cylinder(clay, _xf(c + Vector3(-w * 0.5 + 0.2 + k * 0.4, 0.0, rng.randf_range(-0.1, 0.1))), 0.13 * s, 0.09 * s, 0.32 * s, 7, 1.0)
		_:
			var basket := PSXMat.lit("straw")
			for k in range(int(w / 0.5)):
				var bp := c + Vector3(-w * 0.5 + 0.25 + k * 0.5, 0.0, rng.randf_range(-0.08, 0.08))
				mb.add_cylinder(basket, _xf(bp), 0.2, 0.17, 0.16, 7, 1.0)
				var fm := PSXMat.flat(goods[(k + rng.randi()) % goods.size()])
				for f in range(4):
					mb.add_blob(fm, _xf(bp + Vector3(rng.randf_range(-0.08, 0.08), 0.18 + (f / 2) * 0.06, rng.randf_range(-0.08, 0.08))), Vector3.ONE * 0.07, rng, 0.15, 2, 4, 1.0)


## A shop: KitContext.house(spec) at p facing `face` (give the spec its "awning" and "sign"), and a
## trestle counter of `kind` wares out front on the side away from the door, with "Vendor" behind it
## (facing the street) and "Customer" before it. Returns the house.
static func shopfront(ctx: KitContext, spec: Dictionary, p: Vector2, face: Vector2, kind: String, rng: RandomNumberGenerator) -> Node3D:
	var house := ctx.house(spec, p, face)
	var w: float = spec.get("w", 6.0)
	var d: float = spec.get("d", 5.0)
	var dx: float = spec.get("door_x", 0.0)
	var side := -1.0 if dx >= 0.0 else 1.0
	var cx := dx + side * 1.9
	var cz := d * 0.5 + 1.15
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	mb.add_box(wood, _xf(Vector3(cx, 0.86, cz)), Vector3(1.7, 0.08, 0.7), 1.0)
	for sx: float in [-0.75, 0.75]:
		for sz: float in [-0.28, 0.28]:
			mb.add_box(dark, _xf(Vector3(cx + sx, 0.42, cz + sz)), Vector3(0.08, 0.84, 0.08), 1.0)
	mb.add_box(dark, _xf(Vector3(cx, 0.3, cz)), Vector3(1.55, 0.05, 0.55), 1.0)
	_wares(mb, kind, Vector3(cx, 0.9, cz), 1.5, 0.55, ctx.style["goods"], rng)
	var stand := StaticBody3D.new()
	stand.name = "Counter"
	stand.add_child(_ranged(mb.to_instance("CounterMesh"), false))
	_box(stand, Vector3(1.75, 0.95, 0.75), _xf(Vector3(cx, 0.47, cz)))
	house.add_child(stand)
	_marker(house, "Vendor", Vector3(cx, 0.0, cz - 0.75), 0.0)
	_marker(house, "Customer", Vector3(cx, 0.0, cz + 1.25), PI)
	ctx.reserve(ctx.local_point(house, Vector3(cx, 0, cz + 0.4)), 1.6)
	return house


## A barrow stall: a two-wheeled cart heaped with `kind` wares under a parasol, "Vendor" behind its
## handles and "Customer" in front (+Z).
static func barrow(kind: String, goods: Array, cloth: String, seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := StaticBody3D.new()
	body.name = "Barrow_" + kind
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	mb.add_box(wood, _xf(Vector3(0, 0.72, 0)), Vector3(1.7, 0.08, 1.0), 1.0)
	for s: float in [-1.0, 1.0]:
		mb.add_box(wood, _xf(Vector3(0, 0.86, s * 0.48)), Vector3(1.7, 0.22, 0.05), 1.0)
		mb.add_cylinder(dark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.25, 0.42, s * 0.58)), 0.42, 0.42, 0.07, 10, 1.0, Color.WHITE, true, true)
		Buildings.beam_between(mb, dark, Vector3(-0.85, 0.72, s * 0.3), Vector3(-1.9, 0.82, s * 0.3), 0.06)
	mb.add_box(dark, _xf(Vector3(0.7, 0.36, 0)), Vector3(0.06, 0.72, 0.06), 1.0)
	_wares(mb, kind, Vector3(0, 0.76, 0), 1.5, 0.8, goods, rng)
	# the parasol on a pole at the barrow's side
	var pole_at := Vector3(0.55, 0.0, -0.4)
	mb.add_cylinder(dark, _xf(pole_at), 0.04, 0.04, 2.5, 5, 1.0)
	var canvas := PSXMat.lit(cloth, Color.WHITE, {"affine": 0.6})
	var top := pole_at + Vector3(0, 2.55, 0)
	var n := 8
	for k in range(n):
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var e0 := pole_at + Vector3(cos(a0) * 1.25, 2.1, sin(a0) * 1.25)
		var e1 := pole_at + Vector3(cos(a1) * 1.25, 2.1, sin(a1) * 1.25)
		var nrm := (e1 - top).cross(e0 - top).normalized()
		mb.add_tri(canvas, top, e1, e0, nrm, nrm, nrm, Vector2(0.5, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE if k % 2 == 0 else Color(0.85, 0.85, 0.85), nrm)
		mb.add_tri(canvas, top, e0, e1, -nrm, -nrm, -nrm, Vector2(0.5, 0), Vector2(0, 1), Vector2(1, 1), Color(0.6, 0.6, 0.6), -nrm)
	body.add_child(_ranged(mb.to_instance("BarrowMesh")))
	_box(body, Vector3(1.8, 1.0, 1.25), _xf(Vector3(0, 0.5, 0)))
	_marker(body, "Vendor", Vector3(-1.4, 0, 0.75), PI * 0.5)
	_marker(body, "Customer", Vector3(0.1, 0, 1.4), PI)
	return body


## A rug laid on the ground with wares on it, a stool and a parasol behind: "Vendor" on the stool,
## "Customer" in front (+Z).
static func rug_stall(kind: String, goods: Array, rug: Array, cloth: String, seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := StaticBody3D.new()
	body.name = "Rug_" + kind
	var mb := MeshBuilder.new()
	var rm := PSXMat.lit(rug[0], rug[1], {"affine": 0.6})
	mb.add_quad(rm, Vector3(-1.1, 0.04, -0.75), Vector3(1.1, 0.04, -0.75), Vector3(1.1, 0.04, 0.75), Vector3(-1.1, 0.04, 0.75),
		Vector2.ZERO, Vector2(1, 0), Vector2(1, 1.4), Vector2(0, 1.4), Color.WHITE, Vector3.UP)
	_wares(mb, kind, Vector3(-0.2, 0.05, 0.25), 1.5, 0.6, goods, rng)
	_wares(mb, kind, Vector3(0.2, 0.05, -0.3), 1.0, 0.5, goods, rng)
	var dark := PSXMat.lit("planks_dark")
	mb.add_cylinder(PSXMat.lit("planks"), _xf(Vector3(0, 0.0, -1.2)), 0.22, 0.2, 0.42, 7, 1.0)
	var pole_at := Vector3(0.9, 0.0, -1.1)
	mb.add_cylinder(dark, _xf(pole_at), 0.04, 0.04, 2.3, 5, 1.0)
	var canvas := PSXMat.lit(cloth, Color.WHITE, {"affine": 0.6})
	var top := pole_at + Vector3(-0.6, 2.4, 0.5)
	var n := 8
	for k in range(n):
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var e0 := top + Vector3(cos(a0) * 1.3, -0.45, sin(a0) * 1.3)
		var e1 := top + Vector3(cos(a1) * 1.3, -0.45, sin(a1) * 1.3)
		var nrm := (e1 - top).cross(e0 - top).normalized()
		mb.add_tri(canvas, top, e1, e0, nrm, nrm, nrm, Vector2(0.5, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE if k % 2 == 0 else Color(0.85, 0.85, 0.85), nrm)
		mb.add_tri(canvas, top, e0, e1, -nrm, -nrm, -nrm, Vector2(0.5, 0), Vector2(0, 1), Vector2(1, 1), Color(0.6, 0.6, 0.6), -nrm)
	Buildings.beam_between(mb, dark, pole_at + Vector3(0, 2.3, 0), top, 0.04)
	body.add_child(_ranged(mb.to_instance("RugMesh"), false))
	_box(body, Vector3(0.5, 0.45, 0.5), _xf(Vector3(0, 0.22, -1.2)))
	_marker(body, "Vendor", Vector3(0, 0.42, -1.2), 0.0)
	_marker(body, "Customer", Vector3(0, 0, 1.3), PI)
	return body


## A shade cloth strung between a and b (island space, their tops), sagging, into mb; its two
## poles too when `poles`.
static func shade(ctx: KitContext, mb: MeshBuilder, a: Vector2, b: Vector2, h: float, width: float, cloth: String, poles := true) -> void:
	var ya := ctx.hv(a) + h
	var yb := ctx.hv(b) + h
	var A := Vector3(a.x, ya, a.y)
	var B := Vector3(b.x, yb, b.y)
	var dir := (B - A).normalized()
	var side := Vector3(-dir.z, 0, dir.x) * width * 0.5
	var mat := PSXMat.lit(cloth, Color.WHITE, {"affine": 0.6})
	var n := 6
	for k in range(n):
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var p0 := A.lerp(B, t0) - Vector3.UP * 0.5 * 4.0 * t0 * (1.0 - t0)
		var p1 := A.lerp(B, t1) - Vector3.UP * 0.5 * 4.0 * t1 * (1.0 - t1)
		mb.add_quad(mat, p0 - side, p1 - side, p1 + side, p0 + side, Vector2(0, t0 * 2.0), Vector2(0, t1 * 2.0), Vector2(1, t1 * 2.0), Vector2(1, t0 * 2.0), Color.WHITE, Vector3.DOWN)
		mb.add_quad(mat, p0 - side, p0 + side, p1 + side, p1 - side, Vector2(0, t0 * 2.0), Vector2(1, t0 * 2.0), Vector2(1, t1 * 2.0), Vector2(0, t1 * 2.0), Color(0.75, 0.75, 0.75), Vector3.UP)
	if poles:
		var dark := PSXMat.lit("planks_dark")
		for q: Vector3 in [A, B]:
			mb.add_box(dark, _xf(Vector3(q.x, q.y - (h + 0.1) * 0.5, q.z)), Vector3(0.12, h + 0.1, 0.12), 1.0)
		ctx.reserve(a, 0.6)
		ctx.reserve(b, 0.6)


## A flight of stone steps from `a` (the foot) up to `b` (island space, on the walking surface),
## `w` wide, rises about 0.2 m, curbs either side; one slanted collider over the nosings. Into mb and
## body (island space).
static func stairs(mb: MeshBuilder, body: StaticBody3D, a: Vector3, b: Vector3, w: float, curbs := true) -> void:
	var stone := PSXMat.lit("stone_brick")
	var tread := PSXMat.lit("flagstones", Color(0.95, 0.92, 0.86))
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var run := flat.length()
	var rise := b.y - a.y
	var n := maxi(int(ceil(absf(rise) / 0.2)), 1)
	var f := Vector3(flat.x, 0, flat.y) / run
	var yaw := atan2(f.x, f.z)
	var s := Vector3(f.z, 0, -f.x)
	for i in range(n):
		var t0 := float(i) / n
		var y := a.y + rise * (i + 1) / n
		var c := a + f * run * (t0 + 0.5 / n)
		var depth := run / n + 0.02
		var foot := a.y + rise * i / n - 0.6
		mb.add_box(stone, _xf(Vector3(c.x, (y + foot) * 0.5, c.z), yaw), Vector3(w, y - foot, depth), 0.7, Color(0.85, 0.85, 0.85), false)
		mb.add_box(tread, _xf(Vector3(c.x, y + 0.02, c.z), yaw), Vector3(w + 0.04, 0.05, depth + 0.04), 0.7, Color.WHITE, false)
	if curbs:
		for sd: float in [-1.0, 1.0]:
			var off: Vector3 = s * sd * (w * 0.5 + 0.18)
			var lo := a + off
			var hi := b + off
			for i in range(n):
				var t0 := float(i) / n
				var c := lo.lerp(hi, t0 + 0.5 / n)
				mb.add_box(stone, _xf(c + Vector3(0, 0.15, 0), yaw), Vector3(0.36, 0.9, run / n + 0.02), 0.7, Color(0.78, 0.78, 0.78), false)
	var len3 := Vector3(flat.x, rise, flat.y).length()
	var basis := Basis.looking_at(Vector3(flat.x, rise, flat.y).normalized(), Vector3.UP)
	_box(body, Vector3(w, 0.2, len3), Transform3D(basis, (a + b) * 0.5 + Vector3(0, 0.12, 0) + basis.y * -0.1))


## A retaining wall along `pts` (island space, its top edge), `thick` through, hanging down to below
## the ground either side, `lift` over the top edge with a flagged coping (0: flush, a terrace's
## block); a sloping run steps down in pieces of about a metre. Colliders per piece. Into mb and body.
static func wall(ctx: KitContext, mb: MeshBuilder, body: StaticBody3D, pts: PackedVector3Array, thick := 0.7, lift := 0.25) -> void:
	var stone := PSXMat.lit("stone_brick")
	var cope := PSXMat.lit("flagstones", Color(0.9, 0.88, 0.82))
	for i in range(pts.size() - 1):
		var flat := Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z)
		var n := maxi(int(ceil(flat.length() / 1.0)), 1) if absf(pts[i + 1].y - pts[i].y) > 0.15 else 1
		for k in range(n):
			var p0 := pts[i].lerp(pts[i + 1], float(k) / n)
			var p1 := pts[i].lerp(pts[i + 1], float(k + 1) / n)
			var mid := (p0 + p1) * 0.5
			var len := flat.length() / n
			if len < 0.05:
				continue
			var yaw := atan2(flat.x, flat.y) + PI * 0.5
			var low := minf(ctx.ground_min(Vector2(mid.x, mid.z), thick * 0.5 + 0.6), minf(p0.y, p1.y)) - 0.4
			var top := (p0.y + p1.y) * 0.5 + lift
			mb.add_box(stone, _xf(Vector3(mid.x, (top + low) * 0.5, mid.z), yaw), Vector3(len + 0.05, top - low, thick), 0.6, Color(0.82, 0.8, 0.78), false)
			if lift > 0.0:
				mb.add_box(cope, _xf(Vector3(mid.x, top + 0.04, mid.z), yaw), Vector3(len + 0.1, 0.09, thick + 0.14), 0.6, Color.WHITE, false)
			_box(body, Vector3(len, top - low, thick), _xf(Vector3(mid.x, (top + low) * 0.5, mid.z), yaw))


## Steps laid down the ground from a to b (island space), `w` wide, a tread about every 0.5 m, each
## on the highest ground under it, stone blocks down into it; a slanted collider over every three.
static func ground_stairs(ctx: KitContext, mb: MeshBuilder, body: StaticBody3D, a: Vector2, b: Vector2, w: float) -> void:
	var stone := PSXMat.lit("stone_brick")
	var tread := PSXMat.lit("flagstones", Color(0.95, 0.92, 0.86))
	var run := a.distance_to(b)
	var n := maxi(int(run / 0.5), 1)
	var f := (b - a) / run
	var s := Vector2(-f.y, f.x)
	var yaw := atan2(f.x, f.y)
	var tops: Array = []
	for i in range(n):
		var c := a + f * run * (i + 0.5) / n
		var top := maxf(ctx.ground_max(c, 0.3), maxf(ctx.hv(c + s * w * 0.5), ctx.hv(c - s * w * 0.5))) + 0.06
		tops.append(Vector3(c.x, top, c.y))
		var low := ctx.ground_min(c, w * 0.5) - 0.5
		mb.add_box(stone, _xf(Vector3(c.x, (top + low) * 0.5, c.y), yaw), Vector3(w, top - low, run / n + 0.02), 0.7, Color(0.85, 0.85, 0.85), false)
		mb.add_box(tread, _xf(Vector3(c.x, top + 0.02, c.y), yaw), Vector3(w + 0.04, 0.05, run / n + 0.04), 0.7)
	for i in range(0, n - 1, 3):
		var p0: Vector3 = tops[i]
		var p1: Vector3 = tops[mini(i + 3, n - 1)]
		var d := p1 - p0
		var basis := Basis.looking_at(d.normalized(), Vector3.UP)
		_box(body, Vector3(w, 0.2, d.length() + 0.3), Transform3D(basis, (p0 + p1) * 0.5 + basis.y * -0.08))


## A merged piece (mesh + colliders) built in island space, added under the context's parent.
static func finish(ctx: KitContext, mb: MeshBuilder, body: StaticBody3D, shadow := true) -> StaticBody3D:
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = 400.0
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	ctx.add(body)
	return body
