class_name BrinehollowModels
extends RefCounted
## Brinehollow's own buildings and fittings (2026-10-17, the upper town): the shrine on its terrace, the
## torii-like gate at the head of the long stair, stone lanterns, a teahouse with its veranda and benches.
## Each a StaticBody3D built round its own origin, its front (door, steps) toward +Z, one merged mesh
## (vertex-tinted, shared materials) and box colliders; markers for the people who'll use them.

const RANGE := 400.0


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


static func _body(n: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.collision_layer = 1
	b.collision_mask = 0
	return b


static func _box(body: Node3D, size: Vector3, p: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.transform = _xf(p, yaw)
	body.add_child(cs)


static func _marker(parent: Node3D, n: String, p: Vector3, yaw := 0.0) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = p
	m.rotation.y = yaw
	parent.add_child(m)


static func _done(body: StaticBody3D, mb: MeshBuilder, range_end := RANGE) -> StaticBody3D:
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = range_end
	body.add_child(mi)
	return body


## A hip roof whose eaves sweep up at the corners: eaves `over` out round a w x d plan at height y,
## the corners `lift` higher than the middles, up `h` to a ridge along X. Top and underside.
static func flared_roof(mb: MeshBuilder, mat: Material, under: Material, c: Vector3, w: float, d: float, h: float, over: float, lift: float) -> void:
	var W := w * 0.5 + over
	var D := d * 0.5 + over
	var rl := maxf((w - d) * 0.5, 0.0)
	var y := c.y
	var a := c + Vector3(-W, lift, -D)
	var b := c + Vector3(W, lift, -D)
	var cc := c + Vector3(W, lift, D)
	var dd := c + Vector3(-W, lift, D)
	var mf := c + Vector3(0, 0, -D)
	var mk := c + Vector3(0, 0, D)
	var ml := c + Vector3(-W, 0, 0)
	var mr := c + Vector3(W, 0, 0)
	var r1 := c + Vector3(-rl, h, 0)
	var r2 := c + Vector3(rl, h, 0)
	var faces := [[a, mf, r1], [mf, r2, r1], [mf, b, r2], [cc, mk, r2], [mk, r1, r2], [mk, dd, r1],
		[b, mr, r2], [mr, cc, r2], [dd, ml, r1], [ml, a, r1]]
	for f in faces:
		var p0: Vector3 = f[0]
		var p1: Vector3 = f[1]
		var p2: Vector3 = f[2]
		var n := (p1 - p0).cross(p2 - p0).normalized()
		if n.y < 0.0:
			n = -n
		var uv := func(q: Vector3) -> Vector2: return Vector2(q.x + q.z * 0.3, q.z - q.y * 1.4) * 0.45
		mb.add_tri(mat, p0, p1, p2, n, n, n, uv.call(p0), uv.call(p1), uv.call(p2), Color.WHITE, n)
		mb.add_tri(under, p0 + Vector3.DOWN * 0.12, p1 + Vector3.DOWN * 0.12, p2 + Vector3.DOWN * 0.12, -n, -n, -n,
			uv.call(p0), uv.call(p1), uv.call(p2), Color(0.55, 0.5, 0.48), -n)
	# the ridge beam and its upturned ends
	var ridge := PSXMat.lit("planks_dark")
	Buildings.beam_between(mb, ridge, r1 + Vector3(-0.3, 0.08, 0), r2 + Vector3(0.3, 0.08, 0), 0.16)
	for s: float in [-1.0, 1.0]:
		var e := (r2 if s > 0.0 else r1) + Vector3(s * 0.3, 0.08, 0)
		Buildings.beam_between(mb, ridge, e, e + Vector3(s * 0.35, 0.4, 0), 0.12)


## The shrine: a hall on a stone plinth with a veranda round it and steps up the front, two roofs (the
## lower flared over the veranda, a smaller one over it), a rope with paper streamers over the doors, an
## offering box and a bell. Markers "Priest" (in the doorway), "Worshipper" (before the box), "Door".
static func shrine(seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := _body("Shrine")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick")
	var flag := PSXMat.lit("flagstones", Color(0.95, 0.92, 0.86))
	var post := PSXMat.lit("planks_dark")
	var red := PSXMat.lit("planks", Color(0.78, 0.26, 0.18))
	var board := PSXMat.lit("planks")
	var plaster := PSXMat.lit("plaster", Color(0.96, 0.93, 0.86))
	var roof := PSXMat.lit("roof_tiles", Color(0.5, 0.56, 0.62), {"affine": 0.8})
	var under := PSXMat.lit("planks_dark", Color(0.8, 0.75, 0.7))
	var w := 8.0
	var d := 6.5
	var base := 1.2
	# the plinth and its steps
	mb.add_box(stone, _xf(Vector3(0, base * 0.5 - 0.4, 0)), Vector3(w + 2.4, base + 0.8, d + 2.4), 0.6, Color(0.85, 0.85, 0.85))
	mb.add_box(flag, _xf(Vector3(0, base + 0.02, 0)), Vector3(w + 2.5, 0.06, d + 2.5), 0.6)
	var n := 6
	for i in range(n):
		var y := base - (i + 1) * base / n
		var z := (d + 2.4) * 0.5 + 0.2 + i * 0.32
		mb.add_box(stone, _xf(Vector3(0, (y - 0.4) * 0.5 + 0.03, z)), Vector3(3.2, y + 0.46, 0.34), 0.6, Color(0.8, 0.8, 0.8))
		mb.add_box(flag, _xf(Vector3(0, y + 0.04, z)), Vector3(3.24, 0.05, 0.36), 0.6)
	_box(body, Vector3(w + 2.4, base + 0.8, d + 2.4), Vector3(0, base * 0.5 - 0.4, 0))
	var run := n * 0.32
	var stair := Basis(Vector3.RIGHT, atan2(base, run))
	var cs := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(3.2, 0.2, Vector2(run, base).length() + 0.2)
	cs.shape = sb
	cs.transform = Transform3D(stair, Vector3(0, base * 0.5 - 0.05, (d + 2.4) * 0.5 + run * 0.5))
	body.add_child(cs)
	# the veranda's posts (red), the hall's walls: plastered panels in a dark frame, lattice doors in front
	var fl := base + 0.06
	var h := 3.2
	for x: float in [-w * 0.5 - 0.6, -w * 0.25, w * 0.25, w * 0.5 + 0.6]:
		for z: float in [-d * 0.5 - 0.6, d * 0.5 + 0.6]:
			mb.add_cylinder(red, _xf(Vector3(x, fl, z)), 0.17, 0.15, h + 0.2, 8, 0.6)
	for z: float in [-d * 0.5 - 0.6, 0.0, d * 0.5 + 0.6]:
		for x: float in [-w * 0.5 - 0.6, w * 0.5 + 0.6]:
			mb.add_cylinder(red, _xf(Vector3(x, fl, z)), 0.17, 0.15, h + 0.2, 8, 0.6)
	mb.add_box(plaster, _xf(Vector3(0, fl + h * 0.5, 0)), Vector3(w - 0.4, h, d - 0.4), 0.5, Color.WHITE, true)
	for x: float in [-w * 0.5 + 0.2, w * 0.5 - 0.2]:
		for z: float in [-d * 0.5 + 0.2, d * 0.5 - 0.2]:
			mb.add_box(post, _xf(Vector3(x, fl + h * 0.5, z)), Vector3(0.26, h, 0.26), 0.6)
	mb.add_box(post, _xf(Vector3(0, fl + h - 0.1, 0)), Vector3(w + 1.6, 0.24, d + 1.6), 0.6)
	mb.add_box(red, _xf(Vector3(0, fl + h - 0.45, d * 0.5 + 0.62)), Vector3(w + 1.4, 0.18, 0.16), 0.6)
	var lattice := PSXMat.lit("planks_dark", Color(0.6, 0.4, 0.3))
	for k in range(4):
		var x := -2.4 + k * 1.6
		mb.add_box(PSXMat.lit("plaster", Color(0.85, 0.8, 0.66)), _xf(Vector3(x, fl + 1.2, d * 0.5 - 0.17)), Vector3(1.5, 2.4, 0.06), 0.6)
		for j in range(5):
			mb.add_box(lattice, _xf(Vector3(x, fl + 0.2 + j * 0.5, d * 0.5 - 0.13)), Vector3(1.5, 0.05, 0.05), 1.0)
		for j in range(4):
			mb.add_box(lattice, _xf(Vector3(x - 0.56 + j * 0.37, fl + 1.2, d * 0.5 - 0.13)), Vector3(0.05, 2.4, 0.05), 1.0)
	# the veranda's boards and a low rail round it but for the front
	mb.add_box(board, _xf(Vector3(0, fl + 0.03, 0)), Vector3(w + 1.5, 0.06, d + 1.5), 0.5)
	for s: float in [-1.0, 1.0]:
		Buildings.beam_between(mb, red, Vector3(s * (w * 0.5 + 0.6), fl + 0.6, -d * 0.5 - 0.6), Vector3(s * (w * 0.5 + 0.6), fl + 0.6, d * 0.5 + 0.6), 0.08)
	Buildings.beam_between(mb, red, Vector3(-w * 0.5 - 0.6, fl + 0.6, -d * 0.5 - 0.6), Vector3(w * 0.5 + 0.6, fl + 0.6, -d * 0.5 - 0.6), 0.08)
	_box(body, Vector3(w - 0.4, h, d - 0.4), Vector3(0, fl + h * 0.5, 0))
	# the roofs: the lower sweeping out over the veranda, the upper over a short clerestory
	flared_roof(mb, roof, under, Vector3(0, fl + h + 0.05, 0), w + 1.2, d + 1.2, 1.7, 1.1, 0.55)
	mb.add_box(plaster, _xf(Vector3(0, fl + h + 1.6, 0)), Vector3(w * 0.55, 1.1, d * 0.5), 0.5, Color(0.9, 0.88, 0.82))
	mb.add_box(post, _xf(Vector3(0, fl + h + 2.15, 0)), Vector3(w * 0.55 + 0.2, 0.2, d * 0.5 + 0.2), 0.6)
	flared_roof(mb, roof, under, Vector3(0, fl + h + 2.2, 0), w * 0.6, d * 0.55, 1.9, 0.9, 0.45)
	# the rope over the doors, its streamers; the offering box; the bell and its rope
	var rope := PSXMat.lit("rope", Color(0.95, 0.88, 0.7))
	var ra := Vector3(-3.0, fl + h - 0.75, d * 0.5 + 0.75)
	var rb := Vector3(3.0, fl + h - 0.75, d * 0.5 + 0.75)
	mb.add_tube(rope, MeshBuilder.sag_points(ra, rb, 0.45, 10), 0.11, 0.11, 6, 1.0)
	var paper := PSXMat.flat(Color(0.97, 0.97, 0.94))
	for k in range(5):
		var t := (k + 1) / 6.0
		var q := ra.lerp(rb, t) + Vector3.DOWN * 0.45 * 4.0 * t * (1.0 - t)
		for j in range(3):
			var off := 0.12 * (1.0 if j % 2 == 0 else -1.0)
			mb.add_box(paper, _xf(q + Vector3(off * 0.5, -0.2 - j * 0.16, 0.02)), Vector3(0.14, 0.16, 0.01), 1.0)
	mb.add_box(post, _xf(Vector3(0, base + 0.4, d * 0.5 + 1.25)), Vector3(1.4, 0.8, 0.7), 0.6)
	mb.add_box(lattice, _xf(Vector3(0, base + 0.82, d * 0.5 + 1.25)), Vector3(1.3, 0.04, 0.6), 1.0)
	_box(body, Vector3(1.4, 0.8, 0.7), Vector3(0, base + 0.4, d * 0.5 + 1.25))
	var brass := PSXMat.lit("metal", Color(0.85, 0.65, 0.3))
	mb.add_cylinder(brass, _xf(Vector3(0.0, fl + h - 0.95, d * 0.5 + 0.75)), 0.2, 0.12, 0.3, 8, 1.0, Color.WHITE, true, true)
	mb.add_tube(PSXMat.lit("fabric", Color(0.8, 0.2, 0.18)), PackedVector3Array([Vector3(0.0, fl + h - 0.95, d * 0.5 + 0.75), Vector3(0.05, fl + 0.6, d * 0.5 + 0.85)]), 0.04, 0.04, 4, 1.0)
	_marker(body, "Priest", Vector3(0, fl, d * 0.5 + 0.3), 0.0)
	_marker(body, "Worshipper", Vector3(0, base, d * 0.5 + 1.9), PI)
	_marker(body, "Door", Vector3(0, 0, (d + 2.4) * 0.5 + run + 0.8), PI)
	return _done(body, mb)


## A gate of two posts and two beams (the top one curving up at its ends), vermilion, over a path
## (across X, `span` between the posts).
static func gate(span := 4.4, h := 4.6) -> StaticBody3D:
	var body := _body("ShrineGate")
	var mb := MeshBuilder.new()
	var red := PSXMat.lit("plaster", Color(0.82, 0.25, 0.16))
	var black := PSXMat.lit("planks_dark", Color(0.35, 0.3, 0.28))
	var stone := PSXMat.lit("stone_brick")
	for s: float in [-1.0, 1.0]:
		mb.add_cylinder(stone, _xf(Vector3(s * span * 0.5, -0.2, 0)), 0.36, 0.32, 0.6, 8, 0.6)
		mb.add_cylinder(red, _xf(Vector3(s * span * 0.5, 0.35, 0)), 0.24, 0.21, h - 0.35, 8, 0.6)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = h
		cs.shape = cyl
		cs.position = Vector3(s * span * 0.5, h * 0.5, 0)
		body.add_child(cs)
	mb.add_box(red, _xf(Vector3(0, h - 0.95, 0)), Vector3(span + 1.0, 0.3, 0.26), 0.6)
	mb.add_box(red, _xf(Vector3(0, h - 0.48, 0)), Vector3(0.3, 0.6, 0.2), 0.6)
	# the top beam: a shallow upward curve, black-capped
	var pts := PackedVector3Array()
	for k in range(9):
		var t := float(k) / 8.0 * 2.0 - 1.0
		pts.append(Vector3(t * (span * 0.5 + 1.2), h - 0.1 + 0.35 * t * t, 0))
	mb.add_tube(red, pts, 0.2, 0.2, 6, 0.6, Color.WHITE, true, true)
	var cap := PackedVector3Array()
	for q in pts:
		cap.append(q + Vector3(0, 0.2, 0))
	mb.add_tube(black, cap, 0.14, 0.14, 6, 0.6, Color.WHITE, true, true)
	return _done(body, mb)


## A stone lantern: a footed post, a fire box with glowing windows, a broad cap, a knob. "Flame" at
## its light. Seeded for its weathering.
static func stone_lantern(seed_value: int, s := 1.0) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := _body("StoneLantern")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.9, 0.9, 0.86).darkened(rng.randf_range(0.0, 0.15)))
	var glow := PSXMat.lit("window", Color.WHITE, {"emission": Color(0.95, 0.7, 0.35), "emission_energy": 0.9, "emission_tex": "window"})
	mb.add_cylinder(stone, _xf(Vector3(0, 0, 0)), 0.42 * s, 0.38 * s, 0.22 * s, 6, 0.6)
	mb.add_cylinder(stone, _xf(Vector3(0, 0.22 * s, 0)), 0.16 * s, 0.14 * s, 0.8 * s, 6, 0.6)
	mb.add_cylinder(stone, _xf(Vector3(0, 1.02 * s, 0)), 0.36 * s, 0.3 * s, 0.14 * s, 6, 0.6)
	mb.add_box(stone, _xf(Vector3(0, 1.36 * s, 0)), Vector3(0.44, 0.4, 0.44) * s, 0.6)
	for k in range(4):
		var a := k * PI * 0.5
		mb.add_box_unit_uv(glow, Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * 0.225 * s + Vector3(0, 1.36 * s, 0)), Vector3(0.26, 0.24, 0.02) * s)
	mb.add_cylinder(stone, _xf(Vector3(0, 1.56 * s, 0)), 0.5 * s, 0.12 * s, 0.32 * s, 6, 0.6)
	mb.add_blob(stone, _xf(Vector3(0, 1.92 * s, 0)), Vector3.ONE * 0.1 * s, rng, 0.1, 2, 5, 0.6)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35 * s
	cyl.height = 1.9 * s
	cs.shape = cyl
	cs.position = Vector3(0, 0.95 * s, 0)
	body.add_child(cs)
	_marker(body, "Flame", Vector3(0, 1.36 * s, 0))
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = 160.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	return body


## A teahouse: a long low room behind a deep veranda under one sweeping roof, its front open but for
## cloth hangings at the door, red-felt benches and a parasol out front, paper lanterns under the eaves.
## Markers "Vendor" (behind the counter), "Customer", "Seat1".."Seat3" (on the benches, facing out).
static func teahouse(seed_value: int, w := 8.0, d := 5.0) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := _body("Teahouse")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick")
	var post := PSXMat.lit("planks_dark")
	var board := PSXMat.lit("planks")
	var plaster := PSXMat.lit("plaster", Color(0.95, 0.9, 0.8))
	var roof := PSXMat.lit("thatch" if rng.randf() < 0.5 else "roof_tiles", Color(0.85, 0.82, 0.78), {"affine": 0.8})
	var under := PSXMat.lit("planks_dark", Color(0.8, 0.75, 0.7))
	var felt := PSXMat.lit("fabric", Color(0.78, 0.16, 0.14))
	var fl := 0.45
	var h := 2.6
	var ver := 2.2
	mb.add_box(stone, _xf(Vector3(0, (fl - 1.0) * 0.5, 0.0 + ver * 0.5)), Vector3(w + 0.4, fl + 1.0, d + ver + 0.4), 0.6, Color(0.85, 0.85, 0.85))
	mb.add_box(board, _xf(Vector3(0, fl + 0.02, ver * 0.5)), Vector3(w + 0.3, 0.06, d + ver + 0.3), 0.5)
	_box(body, Vector3(w + 0.4, fl + 1.0, d + ver + 0.4), Vector3(0, (fl - 1.0) * 0.5, ver * 0.5))
	# the back room: walls on three sides, the front open behind a counter but for the door's hangings
	mb.add_box(plaster, _xf(Vector3(0, fl + h * 0.5, -d * 0.5 + 0.1)), Vector3(w, h, 0.2), 0.5)
	for s: float in [-1.0, 1.0]:
		mb.add_box(plaster, _xf(Vector3(s * (w * 0.5 - 0.1), fl + h * 0.5, 0)), Vector3(0.2, h, d), 0.5)
	_box(body, Vector3(w, h, 0.3), Vector3(0, fl + h * 0.5, -d * 0.5 + 0.1))
	for s: float in [-1.0, 1.0]:
		_box(body, Vector3(0.3, h, d), Vector3(s * (w * 0.5 - 0.1), fl + h * 0.5, 0))
	mb.add_box(board, _xf(Vector3(-w * 0.22, fl + 0.5, d * 0.5 - 0.6)), Vector3(w * 0.45, 1.0, 0.5), 0.6, Color(0.85, 0.8, 0.75))
	_box(body, Vector3(w * 0.45, 1.0, 0.5), Vector3(-w * 0.22, fl + 0.5, d * 0.5 - 0.6))
	var clay := PSXMat.lit("plaster", Color(0.7, 0.45, 0.3))
	for k in range(5):
		mb.add_cylinder(clay, _xf(Vector3(-w * 0.4 + k * 0.4, fl + 1.0, d * 0.5 - 0.6)), 0.08, 0.06, 0.14, 6, 1.0)
	var cloths := [Color(0.2, 0.3, 0.55), Color(0.55, 0.15, 0.15)]
	for k in range(4):
		var x := w * 0.18 + k * 0.38
		mb.add_box(PSXMat.lit("fabric", cloths[k % 2]), _xf(Vector3(x, fl + h - 0.45, d * 0.5)), Vector3(0.34, 0.8, 0.03), 1.0)
	# posts along the veranda's edge, the roof sweeping out over it
	for x: float in [-w * 0.5, -w * 0.17, w * 0.17, w * 0.5]:
		mb.add_cylinder(post, _xf(Vector3(x, fl, d * 0.5 + ver - 0.1)), 0.11, 0.1, h + 0.1, 6, 0.6)
	mb.add_box(post, _xf(Vector3(0, fl + h + 0.05, d * 0.5 + ver - 0.1)), Vector3(w + 0.3, 0.18, 0.2), 0.6)
	flared_roof(mb, roof, under, Vector3(0, fl + h + 0.15, ver * 0.5), w, d + ver, 1.6, 0.8, 0.35)
	# red-felt benches out front, a parasol, paper lanterns under the eaves
	var glow := PSXMat.lit("canvas", Color(1.0, 0.85, 0.6), {"emission": Color(1.0, 0.6, 0.3), "emission_energy": 0.8, "emission_tex": "canvas"})
	var seats := [Vector3(-w * 0.3, fl, d * 0.5 + ver * 0.55), Vector3(w * 0.05, fl, d * 0.5 + ver * 0.55), Vector3(w * 0.35, fl, d * 0.5 + ver + 1.1)]
	for i in range(seats.size()):
		var q: Vector3 = seats[i]
		var y0 := q.y if i < 2 else 0.0
		mb.add_box(post, _xf(Vector3(q.x, y0 + 0.2, q.z)), Vector3(1.5, 0.4, 0.45), 0.8)
		mb.add_box(felt, _xf(Vector3(q.x, y0 + 0.43, q.z)), Vector3(1.6, 0.06, 0.55), 0.8)
		_box(body, Vector3(1.6, 0.46, 0.55), Vector3(q.x, y0 + 0.23, q.z))
		_marker(body, "Seat%d" % (i + 1), Vector3(q.x, y0 + 0.46, q.z), 0.0)
	var pp := Vector3(w * 0.35, 0.0, d * 0.5 + ver + 1.9)
	mb.add_cylinder(post, _xf(pp), 0.04, 0.04, 2.4, 5, 1.0)
	var pc := PSXMat.lit("fabric", Color(0.8, 0.22, 0.18))
	var top := pp + Vector3(0, 2.5, 0)
	for k in range(10):
		var a0 := TAU * k / 10.0
		var a1 := TAU * (k + 1) / 10.0
		var e0 := pp + Vector3(cos(a0) * 1.4, 2.05, sin(a0) * 1.4)
		var e1 := pp + Vector3(cos(a1) * 1.4, 2.05, sin(a1) * 1.4)
		var nrm := (e1 - top).cross(e0 - top).normalized()
		mb.add_tri(pc, top, e1, e0, nrm, nrm, nrm, Vector2(0.5, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE if k % 2 == 0 else Color(0.85, 0.85, 0.85), nrm)
		mb.add_tri(pc, top, e0, e1, -nrm, -nrm, -nrm, Vector2(0.5, 0), Vector2(0, 1), Vector2(1, 1), Color(0.6, 0.6, 0.6), -nrm)
	for k in range(4):
		var x := -w * 0.375 + k * w * 0.25
		var lp := Vector3(x, fl + h - 0.35, d * 0.5 + ver - 0.1)
		mb.add_tube(PSXMat.lit("rope"), PackedVector3Array([lp + Vector3(0, 0.35, 0), lp + Vector3(0, 0.18, 0)]), 0.015, 0.015, 3, 1.0)
		mb.add_blob(glow, _xf(lp), Vector3(0.17, 0.22, 0.17), rng, 0.05, 2, 6, 1.0)
	_marker(body, "Vendor", Vector3(-w * 0.22, fl, d * 0.5 - 1.2), 0.0)
	_marker(body, "Customer", Vector3(-w * 0.22, fl, d * 0.5 + 0.2), PI)
	_marker(body, "Lantern", Vector3(0, fl + h - 0.35, d * 0.5 + ver - 0.1))
	return _done(body, mb, 300.0)
