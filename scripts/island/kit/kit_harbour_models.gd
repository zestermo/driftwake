class_name HarbourModels
extends RefCounted
## The generated harbours' own models (GenHarbour): the walkways (a deck along a
## line on pilings, rope rails), an outrigger canoe, a net rack, fish traps,
## contraband under a tarp, a warehouse, a boathouse over the water, a ruined hut
## and a broken tower. Like Props: origin on the ground, front +Z.


static func _body(node_name: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = node_name
	b.collision_layer = 1
	b.collision_mask = 0
	return b


static func _xf(pos: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), pos)


static func _box_col(body: Node3D, size: Vector3, at: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = at
	cs.rotation.y = yaw
	body.add_child(cs)


## A basis whose +Y runs along `dir`.
static func _along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized())


# --------------------------------------------------------------------------
# Walkways
# --------------------------------------------------------------------------
## A deck along `pts` (its top's centre line, island space), `hw` either side,
## the boards running across, fascia boards down its edges and an underside.
## The top also goes into `top` (the walk-on collider). `tints` [lo, hi] shades
## each ~1.2 m bay (patched or rotten boards on a ruin).
static func deck_strip(mb: MeshBuilder, top: MeshBuilder, deck: Material, fascia: Material, pts: PackedVector3Array, hw: float,
		rng: RandomNumberGenerator, tints := [Color(0.86, 0.86, 0.86), Color.WHITE]) -> void:
	var n := pts.size()
	var ls := PackedVector3Array()
	var rs := PackedVector3Array()
	for i in range(n):
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, n - 1)]
		var dp := Vector2(pts[i].x - a.x, pts[i].z - a.z).normalized() if i > 0 else Vector2(b.x - pts[i].x, b.z - pts[i].z).normalized()
		var dn := Vector2(b.x - pts[i].x, b.z - pts[i].z).normalized() if i < n - 1 else dp
		var d := (dp + dn).normalized()
		var side := Vector2(-d.y, d.x)
		var k := 1.0 / maxf(side.dot(Vector2(-dp.y, dp.x)), 0.6)
		ls.append(pts[i] + Vector3(side.x, 0, side.y) * hw * k)
		rs.append(pts[i] - Vector3(side.x, 0, side.y) * hw * k)
	var dy := Vector3(0, 0.26, 0)
	var u := 0.0
	for i in range(n - 1):
		var seg := Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z)
		var len_i := seg.length()
		var dir := seg / maxf(len_i, 0.001)
		var lft := Vector3(-dir.y, 0, dir.x)
		var bays := maxi(int(round(len_i / 1.2)), 1)
		for k in range(bays):
			var t0 := float(k) / bays
			var t1 := float(k + 1) / bays
			var l0 := ls[i].lerp(ls[i + 1], t0)
			var l1 := ls[i].lerp(ls[i + 1], t1)
			var r0 := rs[i].lerp(rs[i + 1], t0)
			var r1 := rs[i].lerp(rs[i + 1], t1)
			var ua := (u + len_i * t0) * 0.5
			var ub := (u + len_i * t1) * 0.5
			var col: Color = (tints[0] as Color).lerp(tints[1], rng.randf())
			mb.add_quad(deck, l0, r0, r1, l1, Vector2(ua, 0), Vector2(ua, hw), Vector2(ub, hw), Vector2(ub, 0), col, Vector3.UP)
			top.add_quad(deck, l0, r0, r1, l1, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Color.WHITE, Vector3.UP)
		mb.add_quad(fascia, ls[i], ls[i + 1], ls[i + 1] - dy, ls[i] - dy, Vector2(u, 0) * 0.6, Vector2(u + len_i, 0) * 0.6, Vector2(u + len_i, 0.16), Vector2(u, 0.16), Color(0.8, 0.8, 0.8), lft)
		mb.add_quad(fascia, rs[i], rs[i + 1], rs[i + 1] - dy, rs[i] - dy, Vector2(u, 0) * 0.6, Vector2(u + len_i, 0) * 0.6, Vector2(u + len_i, 0.16), Vector2(u, 0.16), Color(0.8, 0.8, 0.8), -lft)
		mb.add_quad(fascia, ls[i] - dy, rs[i] - dy, rs[i + 1] - dy, ls[i + 1] - dy, Vector2.ZERO, Vector2(hw, 0), Vector2(hw, len_i * 0.5), Vector2(0, len_i * 0.5), Color(0.5, 0.5, 0.5), Vector3.DOWN)
		u += len_i
	for e in [[0, -1.0], [n - 1, 1.0]]:
		var i: int = e[0]
		var j := i + 1 if i == 0 else i - 1
		var outw := Vector3(pts[i].x - pts[j].x, 0, pts[i].z - pts[j].z).normalized()
		mb.add_quad(fascia, ls[i], rs[i], rs[i] - dy, ls[i] - dy, Vector2.ZERO, Vector2(hw, 0), Vector2(hw, 0.16), Vector2(0, 0.16), Color(0.8, 0.8, 0.8), outw)


## Pilings: [foot, top, radius] each (island space), palm trunks (or squared
## timbers: `square`), darker and weedy below the tide line; `lean` leans each top
## a little off true (seeded), as on a rough jetty.
static func piles(mb: MeshBuilder, pile: Material, list: Array, rng: RandomNumberGenerator, square := false, lean := 0.0) -> void:
	for e in list:
		var foot: Vector3 = e[0]
		var top: Vector3 = e[1]
		var r: float = e[2]
		if lean > 0.0:
			foot += Vector3(rng.randf_range(-lean, lean), 0, rng.randf_range(-lean, lean))
		var wet := Vector3(foot.x, 0.25, foot.z).lerp(Vector3(top.x, 0.25, top.z), clampf((0.25 - foot.y) / maxf(top.y - foot.y, 0.01), 0.0, 1.0))
		for part in [[foot, wet, Color(0.5, 0.58, 0.5)], [wet, top, Color.WHITE]]:
			var a: Vector3 = part[0]
			var b: Vector3 = part[1]
			if b.y - a.y < 0.02:
				continue
			if square:
				Buildings.beam_between(mb, pile, a, b, r * 1.8)
				continue
			mb.add_cylinder(pile, Transform3D(_along(b - a), a), r * 1.06, r, a.distance_to(b), 6, 0.8, part[2], b == top, false)


## Rope rails: posts at `posts` (island space, their feet on the deck), two ropes
## sagging from each post to the next. `breaks`: indices of posts with no rope on to the next.
static func rope_rail(mb: MeshBuilder, post: Material, rope: Material, posts: PackedVector3Array, breaks := []) -> void:
	for i in range(posts.size()):
		mb.add_cylinder(post, _xf(posts[i]), 0.07, 0.06, 1.05, 5, 1.0)
		if i == posts.size() - 1 or breaks.has(i):
			continue
		for y in [0.95, 0.5]:
			mb.add_tube(rope, MeshBuilder.sag_points(posts[i] + Vector3(0, y, 0), posts[i + 1] + Vector3(0, y, 0), 0.12, 6), 0.025, -1.0, 3)


## A mooring post: a stout pile standing proud of the deck, a rope turned round it.
static func bollard(mb: MeshBuilder, pile: Material, rope: Material, at: Vector3) -> void:
	mb.add_cylinder(pile, _xf(at), 0.19, 0.17, 0.6, 6, 0.8)
	mb.add_cylinder(rope, _xf(at + Vector3(0, 0.28, 0)), 0.21, 0.21, 0.14, 6, 2.0, Color.WHITE, false)


# --------------------------------------------------------------------------
# Boats
# --------------------------------------------------------------------------
## A dugout canoe (bow -Z) with an outrigger float on its +X side (`outrigger`),
## a paddle in it. Sits on the ground or the water at its origin.
static func canoe(seed_v: int, outrigger := true) -> StaticBody3D:
	var body := _body("Canoe")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark", Color(0.9, 0.72, 0.55), {"affine": 0.6})
	var bark := PSXMat.lit("bark")
	var rope := PSXMat.lit("rope")
	var length := rng.randf_range(4.2, 5.4)
	var h := length * 0.5
	# [z, gunwale half width, bottom half width, gunwale y, bottom y]
	var rings := [[-h, 0.03, 0.02, 0.62, 0.42], [-h * 0.72, 0.24, 0.1, 0.52, 0.1], [-h * 0.3, 0.36, 0.17, 0.48, 0.0],
		[h * 0.3, 0.36, 0.17, 0.48, 0.0], [h * 0.72, 0.24, 0.1, 0.52, 0.1], [h, 0.03, 0.02, 0.6, 0.42]]
	for i in range(rings.size() - 1):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for s in [-1.0, 1.0]:
			var p0 := Vector3(s * float(a[1]), a[3], a[0]); var p1 := Vector3(s * float(b[1]), b[3], b[0])
			var p2 := Vector3(s * float(b[2]), b[4], b[0]); var p3 := Vector3(s * float(a[2]), a[4], a[0])
			mb.add_quad(wood, p0, p1, p2, p3, Vector2(p0.z, 0) * 0.6, Vector2(p1.z, 0) * 0.6, Vector2(p2.z, 0.4), Vector2(p3.z, 0.4), Color.WHITE, Vector3(s, -0.4, 0).normalized())
			mb.add_quad(wood, p0, p3, p2, p1, Vector2(p0.z, 0) * 0.6, Vector2(p3.z, 0.4), Vector2(p2.z, 0.4), Vector2(p1.z, 0) * 0.6, Color(0.45, 0.38, 0.32), Vector3(-s, 0.4, 0).normalized())
			Buildings.beam_between(mb, bark, p0 + Vector3(0, 0.03, 0), p1 + Vector3(0, 0.03, 0), 0.07)
		var q0 := Vector3(-float(a[2]), a[4], a[0]); var q1 := Vector3(float(a[2]), a[4], a[0])
		var q2 := Vector3(float(b[2]), b[4], b[0]); var q3 := Vector3(-float(b[2]), b[4], b[0])
		mb.add_quad(wood, q0, q1, q2, q3, Vector2.ZERO, Vector2(0.3, 0), Vector2(0.3, 1), Vector2(0, 1), Color(0.6, 0.5, 0.42), Vector3.DOWN)
		mb.add_quad(wood, q0, q3, q2, q1, Vector2.ZERO, Vector2(0, 1), Vector2(0.3, 1), Vector2(0.3, 0), Color(0.4, 0.33, 0.28), Vector3.UP)
	# a thwart, the paddle lying across
	mb.add_box(bark, _xf(Vector3(0, 0.42, h * 0.25)), Vector3(0.7, 0.05, 0.16), 1.0, Color.WHITE, false)
	var pa := rng.randf_range(-0.25, 0.25)
	mb.add_box(bark, Transform3D(Basis(Vector3.UP, pa), Vector3(0.05, 0.2, -0.2)), Vector3(0.05, 0.05, 1.5), 1.0, Color.WHITE, false)
	mb.add_box(PSXMat.lit("planks"), Transform3D(Basis(Vector3.UP, pa), Vector3(0.05, 0.2, -0.2) + Basis(Vector3.UP, pa) * Vector3(0, 0, 0.95)), Vector3(0.18, 0.03, 0.5), 1.0, Color.WHITE, false)
	var w := 0.8
	if outrigger:
		var fx := 1.45
		var fl := length * 0.58
		mb.add_cylinder(bark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(fx, 0.14, -fl * 0.5)), 0.1, 0.1, fl, 6, 1.0, Color.WHITE, false, false)
		for e in [[-fl * 0.5, -1.0], [fl * 0.5, 1.0]]:
			mb.add_cylinder(bark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5 * float(e[1])), Vector3(fx, 0.14, e[0])), 0.1, 0.0, 0.35, 6, 1.0, Color.WHITE, false, false)
		for z in [-h * 0.32, h * 0.32]:
			mb.add_cylinder(bark, Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-0.35, 0.58, z)), 0.045, 0.045, fx + 0.4, 5, 1.0)
			Buildings.beam_between(mb, bark, Vector3(fx, 0.58, z), Vector3(fx, 0.2, z + 0.15), 0.05)
			for s in [-0.33, 0.33]:
				mb.add_cylinder(rope, _xf(Vector3(s, 0.52, z)), 0.06, 0.06, 0.1, 5, 2.0)
		w = fx + 0.6
	body.add_child(mb.to_instance("CanoeMesh"))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 0.6, length)
	cs.shape = box
	cs.position = Vector3((w - 0.8) * 0.5, 0.3, 0)
	body.add_child(cs)
	return body


# --------------------------------------------------------------------------
# Fishing gear, cargo
# --------------------------------------------------------------------------
## Two forked poles and a bar, a net hung to dry with floats along its foot, a
## second net bundled over one end.
static func net_rack(seed_v: int, pole_tex: String, floats: Array) -> StaticBody3D:
	var body := _body("NetRack")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	var pole := PSXMat.lit(pole_tex)
	var net := PSXMat.lit("rope", Color(0.62, 0.68, 0.6))
	var half := rng.randf_range(1.5, 1.9)
	for x in [-half, half]:
		mb.add_cylinder(pole, _xf(Vector3(x, -0.2, 0)), 0.08, 0.06, 2.45, 5, 1.0)
		for s in [-1.0, 1.0]:
			mb.add_tube(pole, PackedVector3Array([Vector3(x, 2.15, 0), Vector3(x + s * 0.14, 2.45, 0)]), 0.04, 0.03, 4)
	mb.add_cylinder(pole, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(half + 0.3, 2.22, 0)), 0.05, 0.05, half * 2.0 + 0.6, 5, 1.0)
	var cols := int(half * 2.0 / 0.32)
	var foot := PackedVector3Array()
	for i in range(cols + 1):
		var x := -half + 0.15 + i * (half * 2.0 - 0.3) / cols
		var drop := 0.45 + rng.randf_range(0.0, 0.25) + 0.25 * sin(float(i) / cols * PI)
		var b := Vector3(x + rng.randf_range(-0.05, 0.05), drop, 0.04)
		foot.append(b)
		mb.add_tube(net, MeshBuilder.curve_points(Vector3(x, 2.2, 0.05), Vector3(x, (2.2 + drop) * 0.5, 0.12), b, 3), 0.02, -1.0, 3)
	for y in [1.85, 1.45, 1.05]:
		mb.add_tube(net, MeshBuilder.sag_points(Vector3(-half + 0.15, y, 0.07), Vector3(half - 0.15, y, 0.07), 0.12, 8), 0.02, -1.0, 3)
	mb.add_tube(net, foot, 0.03, -1.0, 3)
	for i in range(0, foot.size(), 2):
		mb.add_blob(PSXMat.flat(floats[(i / 2) % floats.size()]), _xf(foot[i]), Vector3.ONE * 0.09, rng, 0.1, 2, 5)
	mb.add_blob(net, _xf(Vector3(-half + 0.5, 2.1, 0)), Vector3(0.45, 0.32, 0.22), rng, 0.25, 3, 6, 2.0, Color(0.85, 0.85, 0.85))
	body.add_child(mb.to_instance("NetMesh"))
	KitLandmarks.box_col(body, Vector3(half * 2.0, 2.3, 0.3), Vector3(0, 1.15, 0))
	return body


## Wicker fish traps: `n` long baskets lying on their sides, stacked.
static func fish_traps(seed_v: int, n := 3) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	var wicker := PSXMat.lit("straw", Color(0.9, 0.78, 0.55))
	for i in range(n):
		var top := i >= 2
		var at := Vector3(-0.35 + (i % 2) * 0.7 if not top else 0.0, 0.3 + (0.52 if top else 0.0), rng.randf_range(-0.1, 0.1))
		var b := Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)) * Basis(Vector3.RIGHT, PI * 0.5)
		mb.add_cylinder(wicker, Transform3D(b, at + b * Vector3(0, -0.45, 0)), 0.3, 0.22, 0.9, 7, 1.6, Color.WHITE, false, false)
		mb.add_cylinder(wicker, Transform3D(b, at + b * Vector3(0, -0.45, 0)), 0.22, 0.04, 0.35, 7, 1.6, Color(0.6, 0.5, 0.36), false, false)
		mb.add_cone(wicker, Transform3D(b, at + b * Vector3(0, 0.45, 0)), 0.22, 0.2, 7, 1.6, Color(0.85, 0.85, 0.85))
	return mb.to_instance("FishTrap")


## Sacks heaped on a pallet, a basket of fruit beside.
static func sacks(seed_v: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	var canvas := PSXMat.lit("canvas", Color(0.85, 0.75, 0.55))
	mb.add_box(PSXMat.lit("planks_dark"), _xf(Vector3(0, 0.07, 0)), Vector3(1.6, 0.14, 1.1), 1.0)
	for i in range(7):
		var top := i >= 4
		var at := Vector3(-0.5 + (i % 4) * 0.34 + (0.17 if top else 0.0), 0.14 + (0.3 if top else 0.0), rng.randf_range(-0.25, 0.25))
		if top and i == 6:
			at.x = 0.0
		mb.add_blob(canvas, Transform3D(Basis(Vector3.UP, rng.randf() * PI) * Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0.17, 0)), Vector3(0.2, 0.32, 0.17), rng, 0.12, 4, 7, 2.0, Color(0.8 + rng.randf() * 0.2, 0.85, 0.8))
	mb.add_cylinder(PSXMat.lit("straw"), _xf(Vector3(1.15, 0, 0.2)), 0.3, 0.34, 0.36, 7, 1.0)
	for k in range(6):
		mb.add_blob(PSXMat.flat([Color(0.9, 0.55, 0.1), Color(0.95, 0.85, 0.2), Color(0.45, 0.7, 0.2)][k % 3]), _xf(Vector3(1.05 + (k % 3) * 0.1, 0.38, 0.1 + (k / 3) * 0.16)), Vector3.ONE * 0.09, rng, 0.1, 2, 5)
	return mb.to_instance("Wares")


## Sawn timber stacked on bearers.
static func timber(seed_v: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks", Color(0.95, 0.85, 0.7))
	var bark := PSXMat.lit("bark")
	for sx in [-1.2, 1.2]:
		mb.add_box(bark, _xf(Vector3(sx, 0.1, 0)), Vector3(0.18, 0.2, 1.2), 1.0)
	for row in range(3):
		for k in range(4 - row):
			mb.add_box(wood, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.04, 0.04)), Vector3(rng.randf_range(-0.1, 0.1), 0.25 + row * 0.16, -0.39 + k * 0.26 + row * 0.13)), Vector3(3.2, 0.14, 0.24), 1.0, Color(0.85 + rng.randf() * 0.15, 0.9, 0.9))
	return mb.to_instance("Timber")


## Crates and kegs under a roped canvas tarp (`tarp` its colour).
static func contraband(seed_v: int, tarp: Color) -> StaticBody3D:
	var body := _body("Contraband")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks", Color(0.85, 0.75, 0.6))
	var keg := PSXMat.lit("planks_dark")
	var canvas := PSXMat.lit("canvas", tarp, {"affine": 0.6})
	var rope := PSXMat.lit("rope")
	# [x, z, half x, half z, height]
	var items := [[-0.55, -0.2, 0.45, 0.45, 0.9], [0.45, -0.25, 0.4, 0.4, 0.8], [-0.4, 0.5, 0.35, 0.3, 0.6 + rng.randf() * 0.4], [0.5, 0.5, 0.38, 0.38, 1.25]]
	for it in items:
		mb.add_box(wood, _xf(Vector3(it[0], float(it[4]) * 0.5, it[1]), rng.randf_range(-0.1, 0.1)), Vector3(float(it[2]) * 2.0, it[4], float(it[3]) * 2.0), 1.0)
	mb.add_cylinder(keg, _xf(Vector3(1.3, 0, 0.1)), 0.32, 0.3, 0.8, 7, 1.2)
	mb.add_cylinder(keg, _xf(Vector3(1.25, 0, -0.6)), 0.3, 0.3, 0.75, 7, 1.2)
	var height := func(x: float, z: float) -> float:
		var y := 0.12
		for it in items:
			if absf(x - float(it[0])) < float(it[2]) + 0.12 and absf(z - float(it[1])) < float(it[3]) + 0.12:
				y = maxf(y, float(it[4]) + 0.04)
		return y
	var nx := 9
	var nz := 7
	var grid: Array = []
	for i in range(nx):
		var row := PackedVector3Array()
		for k in range(nz):
			var x := lerpf(-1.15, 1.05, float(i) / (nx - 1))
			var z := lerpf(-0.85, 0.95, float(k) / (nz - 1))
			var edge := i == 0 or k == 0 or i == nx - 1 or k == nz - 1
			var y: float = 0.15 if edge else height.call(x, z) + rng.randf_range(-0.03, 0.03)
			row.append(Vector3(x, y, z))
		grid.append(row)
	var mid := Vector3(0, 0.4, 0.05)
	for i in range(nx - 1):
		for k in range(nz - 1):
			var a: Vector3 = grid[i][k]; var b: Vector3 = grid[i + 1][k]; var c: Vector3 = grid[i + 1][k + 1]; var d: Vector3 = grid[i][k + 1]
			var nrm := (b - a).cross(d - a).normalized()
			if nrm.dot((a + c) * 0.5 - mid) < 0.0:
				nrm = -nrm
			var uv := Vector2(a.x, a.z) * 0.8
			mb.add_quad(canvas, a, b, c, d, uv, uv + Vector2(0.2, 0), uv + Vector2(0.2, 0.2), uv + Vector2(0, 0.2), Color.WHITE, nrm)
			mb.add_quad(canvas, a, d, c, b, uv, uv + Vector2(0, 0.2), uv + Vector2(0.2, 0.2), uv + Vector2(0.2, 0), Color(0.5, 0.5, 0.5), -nrm)
	for k in [2, 4]:
		var pts := PackedVector3Array()
		for i in range(nx):
			pts.append((grid[i][k] as Vector3) + Vector3(0, 0.03, 0))
		mb.add_tube(rope, pts, 0.025, -1.0, 3)
	body.add_child(mb.to_instance("ContrabandMesh"))
	KitLandmarks.box_col(body, Vector3(2.9, 1.2, 1.8), Vector3(0.15, 0.6, 0.05))
	return body


# --------------------------------------------------------------------------
# Buildings
# --------------------------------------------------------------------------
## A timber warehouse: plank walls on a footing (`found` m below the origin for
## a slope), big double doors at the front with one leaf open, a loft door
## above under a hoist beam with a crate on its rope, high windows down the
## sides, a gable roof with its end over the doors. spec: w, d, h, wall, roof, seed, found.
static func warehouse(spec: Dictionary) -> StaticBody3D:
	var body := _body("Warehouse")
	var w: float = spec["w"]
	var d: float = spec["d"]
	var h: float = spec["h"]
	var found: float = spec["found"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	var mb := MeshBuilder.new()
	var wall := PSXMat.lit(spec["wall"])
	var roof := PSXMat.lit(spec["roof"], Color.WHITE, {"affine": 0.8})
	var beam := PSXMat.lit("planks_dark")
	var stone := PSXMat.lit("stone_brick")
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	var window := PSXMat.lit("window", Color.WHITE, {"emission": Color(0.9, 0.7, 0.35), "emission_energy": 0.6, "emission_tex": "window"})
	var fl := 0.35
	mb.add_box(stone, _xf(Vector3(0, (fl - found) * 0.5, 0)), Vector3(w + 0.3, fl + found, d + 0.3), 0.5, Color.WHITE, true, false)
	mb.add_box(stone, _xf(Vector3(0, fl * 0.5, d * 0.5 + 0.7)), Vector3(3.6, fl, 1.2), 0.6, Color.WHITE, true, false)
	Buildings.tiled_box(mb, wall, Vector3(0, fl + h * 0.5, 0), Vector3(w, h, d), 3.2)
	var nx := maxi(int(w / 2.6), 2)
	var nz := maxi(int(d / 2.6), 2)
	for i in range(nx + 1):
		var x := -w * 0.5 + w * i / nx
		for z in [-d * 0.5, d * 0.5]:
			mb.add_box(beam, _xf(Vector3(x, fl + h * 0.5, z)), Vector3(0.24, h, 0.24), 0.6)
	for k in range(1, nz):
		var z := -d * 0.5 + d * k / nz
		for x in [-w * 0.5, w * 0.5]:
			mb.add_box(beam, _xf(Vector3(x, fl + h * 0.5, z)), Vector3(0.24, h, 0.24), 0.6)
	mb.add_box(beam, _xf(Vector3(0, fl + h, 0)), Vector3(w + 0.12, 0.2, d + 0.12), 0.6)
	mb.add_box(beam, _xf(Vector3(0, fl + 0.1, 0)), Vector3(w + 0.08, 0.2, d + 0.08), 0.6)
	# the doors: one leaf shut, one swung open; the loft door above
	var dw := 1.5
	var dh := minf(2.8, h - 0.5)
	mb.add_box(PSXMat.flat(Color(0.08, 0.07, 0.06)), _xf(Vector3(0, fl + dh * 0.5, d * 0.5 + 0.01)), Vector3(dw * 2.0, dh, 0.04), 1.0)
	mb.add_box(beam, _xf(Vector3(-dw * 0.5, fl + dh * 0.5, d * 0.5 + 0.06)), Vector3(dw, dh, 0.1), 0.8)
	mb.add_box(beam, Transform3D(Basis(Vector3.UP, 1.9), Vector3(dw, fl + dh * 0.5, d * 0.5 + 0.06) + Basis(Vector3.UP, 1.9) * Vector3(-dw * 0.5, 0, 0)), Vector3(dw, dh, 0.1), 0.8)
	for x in [-dw - 0.1, dw + 0.1]:
		mb.add_box(beam, _xf(Vector3(x, fl + dh * 0.5, d * 0.5 + 0.08)), Vector3(0.2, dh + 0.1, 0.14), 0.8)
	mb.add_box(beam, _xf(Vector3(0, fl + dh + 0.08, d * 0.5 + 0.08)), Vector3(dw * 2.0 + 0.5, 0.2, 0.14), 0.8)
	for k in range(2):
		mb.add_box(iron, _xf(Vector3(-dw * 0.5, fl + 0.6 + k * (dh - 1.2), d * 0.5 + 0.12)), Vector3(dw - 0.2, 0.08, 0.03), 1.0)
	var top := fl + h
	var pitch := float(spec.get("pitch", 0.42))
	var ridge := w * pitch
	mb.add_box(beam, _xf(Vector3(0, top + ridge * 0.4, d * 0.5 + 0.06)), Vector3(1.2, 1.2, 0.1), 0.8)
	mb.add_box(PSXMat.flat(Color(0.08, 0.07, 0.06)), _xf(Vector3(0, top + ridge * 0.4, d * 0.5 + 0.03)), Vector3(1.0, 1.0, 0.02), 1.0)
	# the hoist: a beam out over the doors, its block, the rope and a crate on it
	var hy := top + ridge * 0.4 + 0.9
	mb.add_box(beam, _xf(Vector3(0, hy, d * 0.5 + 0.5)), Vector3(0.26, 0.26, 2.2), 0.6)
	Buildings.beam_between(mb, beam, Vector3(0, hy - 1.1, d * 0.5 + 0.05), Vector3(0, hy - 0.1, d * 0.5 + 1.0), 0.14)
	mb.add_cylinder(iron, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.1, hy - 0.3, d * 0.5 + 1.4)), 0.15, 0.15, 0.2, 7, 1.0, Color.WHITE, true, true)
	var cy := rng.randf_range(fl + 2.4, hy - 1.4)
	mb.add_tube(PSXMat.lit("rope"), PackedVector3Array([Vector3(0, hy - 0.3, d * 0.5 + 1.4), Vector3(0, cy + 0.75, d * 0.5 + 1.4)]), 0.025, -1.0, 4)
	for s in [-1.0, 1.0]:
		mb.add_tube(PSXMat.lit("rope"), PackedVector3Array([Vector3(0, cy + 0.75, d * 0.5 + 1.4), Vector3(s * 0.32, cy + 0.6, d * 0.5 + 1.4)]), 0.02, -1.0, 3)
	mb.add_box(PSXMat.lit("planks", Color(0.9, 0.85, 0.75)), _xf(Vector3(0, cy + 0.3, d * 0.5 + 1.4), rng.randf_range(-0.3, 0.3)), Vector3(0.65, 0.6, 0.65), 1.1, Color.WHITE, false)
	# high windows down the sides, a lantern by the doors
	for s in [-1.0, 1.0]:
		for k in range(nz):
			var z := -d * 0.5 + d * (k + 0.5) / nz
			var wx := Transform3D(Basis(Vector3.UP, s * PI * 0.5), Vector3(s * (w * 0.5 + 0.03), fl + h - 0.75, z))
			mb.add_box_unit_uv(window, wx, Vector3(0.7, 0.5, 0.06))
			mb.add_box(beam, wx * _xf(Vector3(0, -0.3, 0.04)), Vector3(0.9, 0.07, 0.12), 0.8)
	Buildings.wall_lantern(mb, Vector3(dw + 0.55, fl + 2.1, d * 0.5), beam)
	# the roof, its ridge and barge boards
	mb.add_gable_roof(roof, _xf(Vector3(0, top + 0.1, 0)), w, d, ridge, 0.55, 0.5, Color.WHITE, wall)
	mb.add_box(PSXMat.lit(spec["roof"], Color(0.7, 0.66, 0.62), {"affine": 0.8}), _xf(Vector3(0, top + 0.1 + ridge + 0.04, 0)), Vector3(0.3, 0.18, d + 1.2), 0.8)
	for z in [-(d * 0.5 + 0.55), d * 0.5 + 0.55]:
		for s in [-1.0, 1.0]:
			Buildings.beam_between(mb, beam, Vector3(s * (w * 0.5 + 0.55), top + 0.1 - 0.55 * pitch * 2.0, z), Vector3(0, top + 0.1 + ridge, z), 0.16, 0.07)
	body.add_child(mb.to_instance("WarehouseMesh"))
	KitLandmarks.box_col(body, Vector3(w + 0.3, fl + h + found, d + 0.3), Vector3(0, (fl + h - found) * 0.5, 0))
	Buildings._marker(body, "Door", Vector3(0, 0, d * 0.5 + 1.4))
	return body


## A boathouse over the water, open to the sea at its +Z end: a landing across
## the back and a walk down each side at its floor (origin = the floor's top),
## plank walls, a thatched gable roof, its pilings `depth` m down to the bottom.
## spec: w, l, depth, roof, wall, pile.
static func boathouse(spec: Dictionary) -> StaticBody3D:
	var body := _body("Boathouse")
	var w: float = spec["w"]
	var l: float = spec["l"]
	var depth: float = spec["depth"]
	var mb := MeshBuilder.new()
	var deck := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.5})
	var wall := PSXMat.lit(spec["wall"])
	var beam := PSXMat.lit("planks_dark")
	var roof := PSXMat.lit(spec["roof"], Color.WHITE, {"affine": 0.8})
	var pile := PSXMat.lit(spec["pile"])
	var walk := 1.3
	var h := 2.7
	for s in [-1.0, 1.0]:
		var x: float = s * (w * 0.5 - walk * 0.5)
		mb.add_box(deck, _xf(Vector3(x, -0.12, 0), PI * 0.5), Vector3(l, 0.24, walk), 0.5, Color.WHITE, false)
		KitLandmarks.box_col(body, Vector3(walk, 0.3, l), Vector3(x, -0.15, 0))
		Buildings.tiled_box(mb, wall, Vector3(s * w * 0.5, h * 0.5 + 0.6, -0.4), Vector3(0.12, h - 1.2, l - 0.8), 2.4)
		KitLandmarks.box_col(body, Vector3(0.14, h, l - 0.8), Vector3(s * w * 0.5, h * 0.5, -0.4))
		var z := -l * 0.5
		while z <= l * 0.5 + 0.01:
			for xx in [s * w * 0.5, s * (w * 0.5 - walk)]:
				mb.add_cylinder(pile, _xf(Vector3(xx, -depth - 0.5, z)), 0.16, 0.14, depth + 0.5 + (h if absf(xx) > w * 0.5 - 0.1 else -0.05), 6, 0.8)
			z += 2.4
	mb.add_box(deck, _xf(Vector3(0, -0.12, -l * 0.5 + walk * 0.5)), Vector3(w - walk * 2.0, 0.24, walk), 0.5, Color.WHITE, false)
	KitLandmarks.box_col(body, Vector3(w, 0.3, walk), Vector3(0, -0.15, -l * 0.5 + walk * 0.5))
	# the back wall, a door through it to the landing ashore
	var side_w := (w - 1.4) * 0.5
	for s in [-1.0, 1.0]:
		Buildings.tiled_box(mb, wall, Vector3(s * (0.7 + side_w * 0.5), h * 0.5, -l * 0.5), Vector3(side_w, h, 0.12), 2.4)
		KitLandmarks.box_col(body, Vector3(side_w, h, 0.14), Vector3(s * (0.7 + side_w * 0.5), h * 0.5, -l * 0.5))
	Buildings.tiled_box(mb, wall, Vector3(0, 2.25 + (h - 2.25) * 0.5, -l * 0.5), Vector3(1.4, h - 2.25, 0.12), 2.4)
	for s in [-0.75, 0.75]:
		mb.add_box(beam, _xf(Vector3(s, 1.1, -l * 0.5)), Vector3(0.16, 2.25, 0.2), 0.8)
	mb.add_box(beam, _xf(Vector3(0, h, l * 0.5 - 0.1)), Vector3(w + 0.2, 0.22, 0.22), 0.6)
	mb.add_box(beam, _xf(Vector3(0, h, -l * 0.5)), Vector3(w + 0.2, 0.22, 0.22), 0.6)
	mb.add_gable_roof(roof, _xf(Vector3(0, h + 0.1, 0)), w, l, w * 0.45, 0.6, 0.5, Color.WHITE, wall)
	mb.add_box(PSXMat.lit(spec["roof"], Color(0.7, 0.66, 0.62), {"affine": 0.8}), _xf(Vector3(0, h + 0.14 + w * 0.45, 0)), Vector3(0.3, 0.18, l + 1.3), 0.8)
	body.add_child(mb.to_instance("BoathouseMesh"))
	return body


## A hut fallen in: its floor on short stilts with boards gone, walls of
## upright boards broken off at all heights (the door's side lowest), the
## rafters bare but for a hank of thatch, boards and a post down in the sand.
static func ruined_hut(seed_v: int, w: float, d: float, stilts: float) -> StaticBody3D:
	var body := _body("RuinedHut")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	var wall := PSXMat.lit("planks_weathered")
	var beam := PSXMat.lit("planks_dark")
	var floor_m := PSXMat.lit("planks", Color(0.75, 0.72, 0.65))
	var fl := stilts + 0.2
	for x in [-w * 0.5 + 0.2, 0.0, w * 0.5 - 0.2]:
		for z in [-d * 0.5 + 0.2, d * 0.5 - 0.2]:
			mb.add_box(beam, _xf(Vector3(x, (fl - 0.6) * 0.5, z)), Vector3(0.22, fl + 0.6, 0.22), 0.6)
	var boards := int(d / 0.5)
	for k in range(boards):
		if rng.randf() < 0.18:
			continue
		var z := -d * 0.5 + (k + 0.5) * d / boards
		mb.add_box(floor_m, _xf(Vector3(0, fl - 0.05, z), rng.randf_range(-0.03, 0.03)), Vector3(w, 0.1, d / boards - 0.04), 0.5, Color(0.8 + rng.randf() * 0.2, 0.8, 0.8), false)
	# walls: upright boards, broken off; the front's door gap
	var wall_h := 2.3
	for side in range(4):
		var b := Basis(Vector3.UP, side * PI * 0.5)
		var span := w if side % 2 == 0 else d
		var out := (d if side % 2 == 0 else w) * 0.5
		var n := int(span / 0.32)
		var low := rng.randf_range(0.2, 0.7)
		for k in range(n):
			var x := -span * 0.5 + (k + 0.5) * span / n
			if side == 0 and absf(x) < 0.55:
				continue
			var t := float(k) / n
			var hh := wall_h * clampf(1.0 - absf(t - low) * rng.randf_range(0.8, 2.4), 0.12, 1.0) * rng.randf_range(0.75, 1.0)
			if rng.randf() < 0.12:
				continue
			mb.add_box(wall, Transform3D(b, b * Vector3(x, fl + hh * 0.5, out)), Vector3(span / n - 0.03, hh, 0.06), 0.6, Color(0.8 + rng.randf() * 0.2, 0.8 + rng.randf() * 0.2, 0.8))
		mb.add_box(beam, Transform3D(b, b * Vector3(-span * 0.5, fl + wall_h * 0.5, out)), Vector3(0.18, wall_h, 0.18), 0.6)
	# bare rafters, one fallen across; a hank of thatch on the ridge
	var ry := fl + wall_h + w * 0.4
	for k in range(3):
		var z := -d * 0.5 + d * k / 2.0
		if k == 1 and rng.randf() < 0.6:
			Buildings.beam_between(mb, beam, Vector3(-w * 0.5, fl + 0.2, z - 0.6), Vector3(w * 0.3, fl + wall_h * 0.8, z + 0.3), 0.12)
			continue
		for s in [-1.0, 1.0]:
			Buildings.beam_between(mb, beam, Vector3(s * (w * 0.5 + 0.3), fl + wall_h - 0.1, z), Vector3(0, ry, z), 0.12)
	Buildings.beam_between(mb, beam, Vector3(0, ry, -d * 0.5), Vector3(0, ry - 0.3, d * 0.5), 0.14)
	mb.add_blob(PSXMat.lit("thatch"), _xf(Vector3(rng.randf_range(-0.5, 0.5), ry - 0.15, -d * 0.3)), Vector3(0.9, 0.25, 0.7), rng, 0.3, 3, 6, 1.0)
	for k in range(4):
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(w * 0.6, w * 0.9)
		mb.add_box(wall, Transform3D(Basis(Vector3.UP, rng.randf() * PI) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)), p + Vector3(0, 0.04, 0)), Vector3(0.3, 0.05, rng.randf_range(1.2, 2.2)), 0.6)
	body.add_child(mb.to_instance("RuinMesh"))
	KitLandmarks.box_col(body, Vector3(w, fl + 0.6, d), Vector3(0, (fl - 0.6) * 0.5, 0))
	for side in range(1, 4):
		var b := Basis(Vector3.UP, side * PI * 0.5)
		var span := w if side % 2 == 0 else d
		var out := (d if side % 2 == 0 else w) * 0.5
		_box_col(body, Vector3(span, 1.0, 0.1), b * Vector3(0, fl + 0.5, out), side * PI * 0.5)
	return body


## The stump of a stone harbour tower: an eight-sided shaft broken off at a
## slant, open inside, its gap of a door, blocks fallen round its foot, weed on
## the top courses.
static func tower_stump(seed_v: int) -> StaticBody3D:
	var body := _body("HarbourTower")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.85, 0.82, 0.74))
	var band := PSXMat.lit("stone_brick", Color(0.62, 0.62, 0.56))
	var weed := PSXMat.lit("leaves", Color(0.7, 0.9, 0.6))
	var n := 8
	var r := 2.5
	var tilt := rng.randf() * TAU
	mb.add_cylinder(band, Transform3D(Basis(Vector3.UP, PI / n), Vector3(0, -1.2, 0)), r + 0.7, r + 0.2, 1.8, n, 0.5)
	var pw := 2.0 * r * sin(PI / n) + 0.05
	for k in range(n):
		var a := TAU * (k + 0.5) / n
		var hh := 5.0 + 2.6 * cos(a - tilt) + rng.randf_range(-0.6, 0.6)
		var b := Basis(Vector3.UP, a)
		var c := Vector3(sin(a), 0, cos(a)) * r * cos(PI / n)
		if k == 0:
			mb.add_box(stone, Transform3D(b, c + Vector3(0, 2.6 + (hh - 2.6) * 0.5, 0)), Vector3(pw, hh - 2.6, 0.6), 0.5, Color.WHITE, false)
			continue
		var y0 := 0.0
		while y0 < hh - 0.05:
			var ch := minf(1.2, hh - y0)
			mb.add_box(stone, Transform3D(b, c + Vector3(0, y0 + ch * 0.5, 0)), Vector3(pw, ch, 0.6), 0.5, Color(0.85 + rng.randf() * 0.15, 0.9, 0.9))
			y0 += ch
		mb.add_blob(weed, Transform3D(b, c + Vector3(0, hh, 0)), Vector3(pw * 0.45, 0.25, 0.4), rng, 0.3, 2, 5, 1.0)
		_box_col(body, Vector3(pw, hh, 0.6), c + Vector3(0, hh * 0.5, 0), a)
	for k in range(7):
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(r + 0.8, r + 3.5)
		mb.add_box(stone, Transform3D(Basis(Vector3.UP, rng.randf() * PI) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3)), p + Vector3(0, 0.2, 0)), Vector3(rng.randf_range(0.6, 1.1), 0.5, rng.randf_range(0.5, 0.8)), 0.5, Color.WHITE)
	body.add_child(mb.to_instance("TowerMesh"))
	return body
