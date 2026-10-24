class_name KitWayside
extends RefCounted
## What lies along the way between places on a chain island (1.20, docs/v1_20_plan.md "Between places": paths with
## shape, not open fields; a reason to wander off the path). Walking each of the island's paths, every SPACING m (off
## its ends, near the sites) something beside it - a fallen trunk, a cluster of boulders, the stub of a ruined wall
## (the desert: bleached bones for trunks; the snow: caps of snow on everything) - and now and then a find: a
## wayside shrine, a lone chest (its own save key: once per character), a camp somebody left. Never on a path
## (walkers keep their ways), never in a reserved place, never in the water or on a steep slope. One mesh for the
## lot (a visibility range), simple colliders on the solid things. Seeded from the island: the same on every screen.

const SPACING := Vector2(26.0, 38.0)
## How far off the path's line things lie (m), and how much clear of any path they keep.
const OFF := Vector2(2.6, 6.0)
const PATH_CLEAR := 1.8
## A find every this many metres of path, about.
const FIND_EVERY := 110.0
const ENDS := 20.0
const VIS := 200.0


static func steps(isl: GenIsland) -> Array:
	return [["wayside", func(): build(isl)]]


static func build(isl: GenIsland) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(isl.node["seed"]), "wayside"])
	var ctx := KitContext.make(isl, hash([int(isl.node["seed"]), "wayside"]), isl.theme, 0, isl.build_ms)
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "WaysideBody"
	var mats := _mats(isl.theme)
	var placed: Array = []
	var n_find := 0
	var since_find := FIND_EVERY * rng.randf_range(0.3, 0.8)
	for path in isl.paths:
		var pts: PackedVector2Array = path
		if pts.size() < 2:
			continue
		var total := 0.0
		for i in range(1, pts.size()):
			total += pts[i].distance_to(pts[i - 1])
		var d := ENDS + rng.randf_range(0.0, SPACING.x)
		while d < total - ENDS:
			var at := _along(pts, d)
			var p: Vector2 = at[0]
			var dir: Vector2 = at[1]
			var side := Vector2(-dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			var q := p + side * rng.randf_range(OFF.x, OFF.y)
			since_find += SPACING.y
			if _ok(isl, q, placed):
				placed.append([q, 4.0])
				if since_find >= FIND_EVERY:
					since_find = 0.0
					_find(isl, ctx, mb, body, rng, mats, q, dir, n_find)
					n_find += 1
				else:
					match rng.randi() % 3:
						0:
							_trunk(isl, mb, body, rng, mats, q, dir)
						1:
							_boulders(isl, mb, body, rng, mats, q)
						2:
							_wall(isl, mb, body, rng, mats, q, dir)
			d += rng.randf_range(SPACING.x, SPACING.y)
	var mi := mb.to_instance("Wayside")
	mi.visibility_range_end = VIS
	isl.add_child(mi)
	isl.add_child(body)


## [point, unit direction] `d` m along the path.
static func _along(pts: PackedVector2Array, d: float) -> Array:
	var acc := 0.0
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if acc + seg >= d:
			var u := (d - acc) / maxf(seg, 0.001)
			return [pts[i - 1].lerp(pts[i], u), (pts[i] - pts[i - 1]).normalized()]
		acc += seg
	return [pts[pts.size() - 1], (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()]


## Clear for something here: on land, not steep, not reserved, off every path, not on top of the last ones.
static func _ok(isl: GenIsland, q: Vector2, placed: Array) -> bool:
	if q.length() > isl.radius * 0.92 or isl.hv(q) < 0.8:
		return false
	if KitLandmarks.grad(isl, q, 1.5).length() > 0.45:
		return false
	if not KitLandmarks.clear_of(isl, q, 2.5, placed):
		return false
	for path in isl.paths:
		for pt in (path as PackedVector2Array):
			if pt.distance_squared_to(q) < PATH_CLEAR * PATH_CLEAR + 4.0:
				return false
	return true


## Clear of every path by PATH_CLEAR (a single piece: a boulder of a cluster, a block of a wall, a stump).
static func _off_path(isl: GenIsland, o: Vector2) -> bool:
	for path in isl.paths:
		for pt in (path as PackedVector2Array):
			if pt.distance_squared_to(o) < PATH_CLEAR * PATH_CLEAR:
				return false
	return true


static func _mats(theme: String) -> Dictionary:
	var m := {"rock": PSXMat.lit("rock", Color(0.8, 0.82, 0.78)), "wood": PSXMat.lit("bark", Color(0.9, 0.85, 0.8)),
		"stone": PSXMat.lit("stone_brick", Color(0.8, 0.82, 0.78)), "moss": PSXMat.lit("leaves", Color(0.42, 0.6, 0.3)),
		"snow": null, "bone": null}
	match theme:
		"desert":
			m["rock"] = PSXMat.lit("sandstone", Color(0.95, 0.9, 0.82))
			m["stone"] = PSXMat.lit("sandstone")
			m["bone"] = PSXMat.flat(Color(0.92, 0.88, 0.76))
			m["moss"] = null
		"snow":
			m["rock"] = PSXMat.lit("rock", Color(0.55, 0.6, 0.68))
			m["snow"] = PSXMat.flat(Color(0.93, 0.96, 1.0))
			m["moss"] = null
		"forest":
			m["moss"] = PSXMat.lit("leaves", Color(0.55, 0.62, 0.28))
	return m


static func _gy(isl: GenIsland, q: Vector2) -> float:
	return isl.hv(q)


## A fallen trunk lying beside the way (its stump by it now and then); the desert's are a beast's bleached bones.
static func _trunk(isl: GenIsland, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, m: Dictionary, q: Vector2, dir: Vector2) -> void:
	var y := _gy(isl, q)
	var yaw := atan2(dir.x, dir.y) + rng.randf_range(-0.6, 0.6)
	if m["bone"] != null:
		var b := Basis(Vector3.UP, yaw)
		var o := Vector3(q.x, y, q.y)
		mb.add_tube(m["bone"], PackedVector3Array([o + b * Vector3(0, 0.2, -1.6), o + b * Vector3(0, 0.3, 0), o + b * Vector3(0, 0.2, 1.6)]), 0.14, 0.1, 5, 1.0)
		for k in range(5):
			var z := -1.2 + k * 0.6
			for s in [-1.0, 1.0]:
				mb.add_tube(m["bone"], MeshBuilder.curve_points(o + b * Vector3(0, 0.3, z), o + b * Vector3(s * 0.8, 0.8, z), o + b * Vector3(s * 0.9, -0.1, z), 4), 0.07, 0.04, 4, 1.0)
		return
	var ln := rng.randf_range(3.5, 6.0)
	var r := rng.randf_range(0.28, 0.45)
	# (both ends off the paths too: it lies beside the way, not across it)
	var dir3 := Vector2.from_angle(PI * 0.5 - yaw)
	if not _off_path(isl, q + dir3 * ln * 0.5) or not _off_path(isl, q - dir3 * ln * 0.5):
		return
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
	var at := Vector3(q.x, y + r * 0.8, q.y)
	mb.add_cylinder(m["wood"], Transform3D(b, at - Basis(Vector3.UP, yaw) * Vector3(0, 0, ln * 0.5)), r, r * 0.8, ln, 7, 0.8, Color.WHITE.darkened(rng.randf() * 0.15), true, true)
	if m["moss"] != null:
		mb.add_blob(m["moss"], Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, r * 0.75, 0)), Vector3(r * 0.9, r * 0.25, ln * 0.3), rng, 0.3, 3, 5, 0.8)
	if m["snow"] != null:
		mb.add_blob(m["snow"], Transform3D(Basis(Vector3.UP, yaw), at + Vector3(0, r * 0.85, 0)), Vector3(r * 0.95, r * 0.3, ln * 0.45), rng, 0.2, 3, 5, 0.8)
	KitLandmarks.box_col_xf(body, Vector3(r * 2.0, r * 2.0, ln), Transform3D(Basis(Vector3.UP, yaw), at))
	if rng.randf() < 0.4:
		var sq := q + Vector2.from_angle(rng.randf() * TAU) * (ln * 0.5 + 0.6)
		if not _off_path(isl, sq):
			return
		mb.add_cylinder(m["wood"], Transform3D(Basis(), Vector3(sq.x, _gy(isl, sq) - 0.1, sq.y)), r * 1.15, r, 0.6, 7, 0.8)


## A cluster of boulders, the biggest solid.
static func _boulders(isl: GenIsland, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, m: Dictionary, q: Vector2) -> void:
	for k in range(rng.randi_range(3, 5)):
		var o := q + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 2.2)
		if not _off_path(isl, o):
			continue
		var s := rng.randf_range(0.4, 1.6) * (1.3 if k == 0 else 1.0)
		var at := Vector3(o.x, _gy(isl, o) + s * 0.25, o.y)
		mb.add_blob(m["rock"], Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Vector3(s, s * 0.7, s * 0.9), rng, 0.25, 3, 6, 0.7, Color.WHITE.darkened(rng.randf() * 0.15))
		if m["snow"] != null:
			mb.add_blob(m["snow"], Transform3D(Basis(), at + Vector3(0, s * 0.55, 0)), Vector3(s * 0.8, s * 0.22, s * 0.7), rng, 0.2, 3, 5, 0.8)
		elif m["moss"] != null and rng.randf() < 0.5:
			mb.add_blob(m["moss"], Transform3D(Basis(), at + Vector3(0, s * 0.5, 0)), Vector3(s * 0.6, s * 0.15, s * 0.5), rng, 0.3, 3, 5, 0.8)
		if s > 0.9:
			KitLandmarks.cyl_col(body, s * 0.75, s * 1.1, at)


## The stub of a ruined wall: a few courses of stone in a broken row.
static func _wall(isl: GenIsland, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, m: Dictionary, q: Vector2, dir: Vector2) -> void:
	var yaw := atan2(dir.x, dir.y) + rng.randf_range(-0.3, 0.3)
	var b := Basis(Vector3.UP, yaw + PI * 0.5)
	var n := rng.randi_range(2, 4)
	for k in range(n):
		var o := q + Vector2.from_angle(yaw + PI * 0.5).rotated(PI * 0.5) * ((k - (n - 1) * 0.5) * 1.6)
		if not _off_path(isl, o):
			continue
		var h := rng.randf_range(0.5, 1.5)
		var at := Vector3(o.x, _gy(isl, o) - 0.15 + h * 0.5, o.y)
		mb.add_box(m["stone"], Transform3D(b, at), Vector3(1.55, h, 0.6), 0.7, Color.WHITE.darkened(rng.randf() * 0.2))
		KitLandmarks.box_col_xf(body, Vector3(1.55, h, 0.6), Transform3D(b, at))
		if m["snow"] != null:
			mb.add_box(m["snow"], Transform3D(b, at + Vector3(0, h * 0.5 + 0.06, 0)), Vector3(1.5, 0.12, 0.62), 0.7)
		elif m["moss"] != null and rng.randf() < 0.5:
			mb.add_blob(m["moss"], Transform3D(b, at + Vector3(0, h * 0.5, 0)), Vector3(0.6, 0.12, 0.35), rng, 0.3, 3, 5, 0.8)


## A find: a wayside shrine, a lone chest or a camp somebody left, in turn (seeded).
static func _find(isl: GenIsland, ctx: KitContext, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator, m: Dictionary, q: Vector2, dir: Vector2, n: int) -> void:
	var y := _gy(isl, q)
	var yaw := atan2(-dir.x, -dir.y)
	match (n + int(isl.node["seed"])) % 3:
		0:
			# a shrine: a plinth, a little roofed niche, an offering bowl and a candle stub
			var b := Basis(Vector3.UP, yaw)
			mb.add_box(m["stone"], Transform3D(b, Vector3(q.x, y + 0.35, q.y)), Vector3(1.1, 0.7, 0.9), 0.7)
			mb.add_box(m["stone"], Transform3D(b, Vector3(q.x, y + 1.15, q.y)), Vector3(0.8, 0.9, 0.7), 0.7)
			mb.add_box(m["wood"], Transform3D(b * Basis(Vector3.BACK, 0.0), Vector3(q.x, y + 1.7, q.y)), Vector3(1.1, 0.12, 0.95), 0.7)
			mb.add_cylinder(PSXMat.flat(Color(0.55, 0.38, 0.22)), Transform3D(Basis(), Vector3(q.x, y + 0.72, q.y) + b * Vector3(0, 0, -0.42)), 0.18, 0.12, 0.08, 6, 1.0)
			mb.add_cylinder(PSXMat.flat(Color(0.92, 0.88, 0.72)), Transform3D(Basis(), Vector3(q.x, y + 0.72, q.y) + b * Vector3(0.3, 0, -0.42)), 0.05, 0.05, 0.16, 5, 1.0)
			KitLandmarks.box_col_xf(body, Vector3(1.1, 1.8, 0.9), Transform3D(b, Vector3(q.x, y + 0.9, q.y)))
		1:
			# a lone chest, half under a rock
			KitCamps.strongbox(ctx, q, yaw, "wayside_%d_%d" % [int(isl.node["id"]), n], KitLandmarks.loot(isl, rng, false), 1.0)
			_boulders(isl, mb, body, rng, m, q + Vector2.from_angle(yaw) * 1.4)
		2:
			# a camp somebody left: a ring of stones round cold ashes, a bedroll, a log to sit on
			for k in range(7):
				var o := q + Vector2.from_angle(TAU * k / 7.0) * 0.75
				mb.add_blob(m["rock"], Transform3D(Basis(), Vector3(o.x, _gy(isl, o) + 0.08, o.y)), Vector3(0.22, 0.15, 0.2), rng, 0.2, 2, 5, 0.7)
			mb.add_blob(PSXMat.flat(Color(0.12, 0.11, 0.1)), Transform3D(Basis(), Vector3(q.x, y + 0.03, q.y)), Vector3(0.55, 0.04, 0.55), rng, 0.1, 2, 6, 1.0)
			var bq := q + Vector2.from_angle(yaw) * 1.8
			mb.add_box(PSXMat.flat(Color(0.45, 0.3, 0.2)), Transform3D(Basis(Vector3.UP, yaw), Vector3(bq.x, _gy(isl, bq) + 0.08, bq.y)), Vector3(0.7, 0.14, 1.8), 1.0)
			var lq := q - Vector2.from_angle(yaw) * 1.7
			mb.add_cylinder(m["wood"], Transform3D(Basis(Vector3.UP, yaw + PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(lq.x, _gy(isl, lq) + 0.22, lq.y) - Basis(Vector3.UP, yaw + PI * 0.5) * Vector3(0, 0, 0.9)), 0.22, 0.2, 1.8, 6, 0.8)
