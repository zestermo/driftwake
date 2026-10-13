class_name JunglePlants
extends RefCounted
## The jungle's vegetation for GenIsland's MultiMeshes (IslandTheme.meshes). The
## big trees come as [body, detail, lean]: the body (trunk and crown) is seen from
## the sea; the detail (buttress roots, lianas, ferns in the limbs) only up close;
## lean is the way the crown leans (ring trees turn it toward a clearing). Canopy
## giants, strangler figs, kapoks and emergents over the canopy, crown-only roof
## pieces over a canopy arena; then mangroves, understory shrubs, broad-leaved
## plants and bamboo. Origins on the ground; materials shared with the rest of the
## vegetation.


static func _seg(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, uv := 0.6) -> void:
	var d := b - a
	mb.add_cylinder(mat, Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), a), r0, r1, d.length() + 0.05, sides, uv, Color.WHITE, false)


static func _bark() -> Material:
	return PSXMat.lit("bark", Color(0.82, 0.8, 0.72))


static func _leaves() -> Material:
	return PSXMat.lit("leaves", Color(0.95, 1.0, 0.95), {"affine": 0.5})


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A tapering trunk up through `n` pieces, leaning by `lean` at the top; its points.
static func _trunk(mb: MeshBuilder, h: float, lean: Vector3, radii: Array) -> Array:
	var pts: Array = []
	var n := radii.size() - 1
	for i in range(n + 1):
		pts.append(lean * pow(i / float(n), 2.0) + Vector3.UP * h * i / float(n))
	for i in range(n):
		_seg(mb, _bark(), pts[i], pts[i + 1], radii[i], radii[i + 1], 7)
	return pts


## A deep crown in three tiers round the trunk's top, darker underneath; limbs to
## the first blobs of each tier when `limbs`.
static func _crown(mb: MeshBuilder, rng: RandomNumberGenerator, base: Vector3, top: Vector3, s: float, limbs: bool) -> void:
	var leaves := _leaves()
	for tier in [[1.0, 6, [2.6, 4.8], [3.2, 4.4], 0.0], [0.8, 5, [3.0, 5.2], [2.8, 3.8], 0.15], [0.62, 4, [2.6, 4.4], [2.3, 3.2], 0.3]]:
		var y: Vector3 = base.lerp(top, float(tier[0]))
		var n: int = tier[1]
		var off := rng.randf() * TAU
		for k in range(n):
			var a := off + TAU * k / n + rng.randf_range(-0.3, 0.3)
			var c := y + Vector3(cos(a), 0, sin(a)) * rng.randf_range(tier[2][0], tier[2][1]) * s + Vector3.UP * rng.randf_range(-0.6, 1.2)
			var r := rng.randf_range(tier[3][0], tier[3][1]) * s
			if limbs and k < 2:
				_seg(mb, _bark(), y - Vector3.UP * 1.5, c - Vector3.UP * r * 0.3, 0.22, 0.1, 5)
			mb.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c), Vector3(r, r * 0.7, r), rng, 0.2, 3, 6, 0.5,
				Color.WHITE.darkened(float(tier[4]) + rng.randf_range(0.0, 0.12)))
	mb.add_blob(leaves, Transform3D(Basis(), top + Vector3.UP * 2.0), Vector3(3.8, 2.4, 3.8) * s, rng, 0.2, 3, 7, 0.5)


## Buttress roots: thin fins from the trunk out across the ground.
static func _buttresses(mb: MeshBuilder, rng: RandomNumberGenerator, r: float, reach: Array, up: Array) -> void:
	var bark := _bark()
	var n := rng.randi_range(4, 5)
	for k in range(n):
		var a := TAU * k / n + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * 0.07
		var foot := dir * (r + rng.randf_range(reach[0], reach[1])) + Vector3.DOWN * 0.2
		var top := dir * r * 0.8 + Vector3.UP * rng.randf_range(up[0], up[1])
		var root := dir * r * 0.7 + Vector3.DOWN * 0.3
		var mid := dir * (r + 0.35 * foot.length()) + Vector3.UP * 0.45 * top.y
		for s in [-1.0, 1.0]:
			var o: Vector3 = side * s
			var nrm: Vector3 = side.normalized() * s
			mb.add_tri(bark, root + o, foot + o, mid + o, nrm, nrm, nrm, Vector2(0, 1), Vector2(1, 1), Vector2(0.7, 0.4), Color(0.95, 0.92, 0.85), nrm)
			mb.add_tri(bark, root + o, mid + o, top + o, nrm, nrm, nrm, Vector2(0, 1), Vector2(0.7, 0.4), Vector2(0, 0), Color(0.95, 0.92, 0.85), nrm)
		mb.add_quad(bark, foot + side, foot - side, mid - side, mid + side, Vector2.ZERO, Vector2(0.1, 0), Vector2(0.1, 1), Vector2(0, 1), Color.WHITE, (mid - root).cross(side).normalized())


## Lianas hanging from under a crown, `spread` out from its middle.
static func _lianas(mb: MeshBuilder, rng: RandomNumberGenerator, centre: Vector3, spread: Array, count: int, length: Array) -> void:
	var vine := PSXMat.cutout("vines", Color(0.9, 1.0, 0.9))
	for k in range(count):
		var a := rng.randf() * TAU
		var L := rng.randf_range(length[0], length[1])
		var at := centre + Vector3(cos(a), 0, sin(a)) * rng.randf_range(spread[0], spread[1]) + Vector3.DOWN * L
		mb.add_card(vine, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), rng.randf_range(0.7, 1.1), L, Rect2(0, 0, 1, 1), Color.WHITE.darkened(rng.randf() * 0.2))


static func _ferns_at(mb: MeshBuilder, at: Vector3, n: int) -> void:
	var fern := PSXMat.cutout("fern", Color.WHITE, 0.08, 1.0)
	for k in range(n):
		mb.add_cross_cards(fern, Transform3D(Basis(Vector3.UP, k * 1.3), at + Vector3(cos(k * 2.1), 0, sin(k * 2.1)) * 0.9), 1.4, 1.0, 2)


## A canopy giant (13-18 m): a pale buttressed trunk, limbs into a deep crown.
## A strangler fig (`fig`) is a lattice of roots grown round its dead host instead.
static func canopy_tree(seed_value: int, fig := false) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(13.0, 18.0)
	var lean := Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7))
	var pts: Array
	if fig:
		pts = _trunk(body, h, lean, [0.35, 0.3, 0.28, 0.24])
		var roots := _bark()
		for k in range(7):
			var line := PackedVector3Array()
			var a0 := TAU * k / 7.0
			for j in range(7):
				var t := j / 6.0
				var a := a0 + t * (1.2 if k % 2 == 0 else -1.2)
				var r := lerpf(1.5, 0.4, pow(t, 0.6))
				line.append(lean * pow(t * 0.7, 2.0) + Vector3(cos(a) * r, h * 0.7 * t - 0.3, sin(a) * r))
			body.add_tube(roots, line, 0.16, 0.08, 4, 1.0, Color(0.85, 0.82, 0.72))
	else:
		pts = _trunk(body, h, lean, [0.8, 0.6, 0.45, 0.32])
	var top: Vector3 = pts[pts.size() - 1]
	_crown(body, rng, pts[0], top, 1.0, true)
	var detail := MeshBuilder.new()
	if fig:
		_lianas(detail, rng, top - Vector3.UP * 0.8, [0.5, 3.0], rng.randi_range(9, 12), [6.0, 12.0])
	else:
		_buttresses(detail, rng, 0.8, [1.5, 2.3], [2.2, 3.2])
		_lianas(detail, rng, top - Vector3.UP * 0.8, [1.5, 4.0], rng.randi_range(6, 9), [4.0, 9.0])
	_ferns_at(detail, pts[2].lerp(top, 0.3), 3)
	return [body.commit(), detail.commit(), lean]


## An emergent (26-32 m) towering over the canopy: a tall bare trunk, great fins,
## limbs spreading into a flat umbrella crown.
static func emergent_tree(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var leaves := _leaves()
	var body := MeshBuilder.new()
	var h := rng.randf_range(26.0, 32.0)
	var lean := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
	var pts := _trunk(body, h, lean, [1.1, 0.8, 0.6, 0.48, 0.36])
	var top: Vector3 = pts[4]
	var fork: Vector3 = pts[3].lerp(pts[4], 0.4)
	var n_limb := rng.randi_range(4, 5)
	for k in range(n_limb):
		var a := TAU * k / n_limb + rng.randf_range(-0.25, 0.25)
		var end := top + Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.0, 6.0) + Vector3.UP * rng.randf_range(0.5, 2.5)
		_seg(body, _bark(), fork, end, 0.3, 0.14, 5)
		var r := rng.randf_range(4.0, 5.4)
		body.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), end + Vector3.UP * 0.6), Vector3(r, r * 0.5, r), rng, 0.18, 3, 7, 0.5, Color.WHITE.darkened(rng.randf_range(0.0, 0.12)))
		var lo: Vector3 = fork.lerp(end, 0.55) + Vector3.DOWN * rng.randf_range(1.0, 2.0)
		var r2 := rng.randf_range(2.6, 3.4)
		body.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), lo), Vector3(r2, r2 * 0.6, r2), rng, 0.18, 3, 6, 0.5, Color.WHITE.darkened(rng.randf_range(0.2, 0.3)))
	body.add_blob(leaves, Transform3D(Basis(), top + Vector3.UP * 2.4), Vector3(4.6, 2.4, 4.6), rng, 0.18, 3, 7, 0.5)
	var detail := MeshBuilder.new()
	_buttresses(detail, rng, 1.1, [2.6, 3.6], [3.8, 5.0])
	_lianas(detail, rng, top - Vector3.UP * 0.5, [2.5, 5.5], rng.randi_range(5, 7), [6.0, 12.0])
	return [body.commit(), detail.commit(), lean]


## A kapok (24-30 m): a straight grey trunk on huge buttresses, its crown in
## flat layers one over another.
static func kapok_tree(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var leaves := _leaves()
	var body := MeshBuilder.new()
	var h := rng.randf_range(24.0, 30.0)
	var lean := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	var pts := _trunk(body, h, lean, [1.0, 0.75, 0.6, 0.45, 0.32])
	for layer in [[0.72, 6.5, 0.3], [0.86, 5.2, 0.15], [1.0, 3.8, 0.0]]:
		var y: Vector3 = pts[0].lerp(pts[4], float(layer[0]))
		var w: float = layer[1]
		for k in range(4):
			var a := TAU * k / 4.0 + rng.randf_range(-0.4, 0.4)
			var c := y + Vector3(cos(a), 0, sin(a)) * w * 0.45
			if k < 2:
				_seg(body, _bark(), y + Vector3.DOWN * 0.8, c, 0.22, 0.1, 5)
			body.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c), Vector3(w * 0.6, 1.1, w * 0.6), rng, 0.15, 2, 7, 0.5,
				Color.WHITE.darkened(float(layer[2]) + rng.randf_range(0.0, 0.1)))
	var detail := MeshBuilder.new()
	_buttresses(detail, rng, 1.0, [3.0, 4.2], [4.5, 6.0])
	_lianas(detail, rng, pts[3], [1.5, 4.0], rng.randi_range(4, 6), [5.0, 10.0])
	return [body.commit(), detail.commit(), lean]


## A piece of canopy with no trunk of its own, closing the roof over a canopy
## arena (the ring trees round it carry it, as far as anyone under it can tell).
static func canopy_roof(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var h := rng.randf_range(14.0, 17.0)
	_crown(body, rng, Vector3.UP * h * 0.6, Vector3.UP * h, 1.0, false)
	var detail := MeshBuilder.new()
	_lianas(detail, rng, Vector3.UP * (h - 1.0), [0.5, 5.0], rng.randi_range(8, 11), [6.0, 11.0])
	return [body.commit(), detail.commit(), Vector3.ZERO]


## A mangrove at the waterline: a short trunk on arching stilt roots, a dark
## round crown.
static func mangrove_mesh(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var roots := _bark()
	var leaves := _leaves()
	var h := rng.randf_range(3.5, 5.5)
	_seg(mb, roots, Vector3.UP * 1.2, Vector3.UP * h, 0.2, 0.14, 5)
	for k in range(rng.randi_range(7, 9)):
		var a := TAU * k / 8.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0, sin(a))
		var out := rng.randf_range(1.4, 2.3)
		var from := Vector3.UP * rng.randf_range(1.2, 2.2) + dir * 0.1
		var line := PackedVector3Array([from, from + dir * out * 0.45 + Vector3.UP * 0.35, dir * out * 0.85 + Vector3.UP * 0.4, dir * out + Vector3.DOWN * 0.8])
		mb.add_tube(roots, line, 0.07, 0.05, 4, 1.0, Color(0.75, 0.7, 0.62))
	for k in range(4):
		var a := TAU * k / 4.0 + rng.randf()
		var r := rng.randf_range(1.5, 2.2)
		mb.add_blob(leaves, Transform3D(Basis(), Vector3(cos(a) * 1.1, h + rng.randf_range(-0.4, 0.5), sin(a) * 1.1)), Vector3(r, r * 0.7, r), rng, 0.2, 3, 6, 0.5,
			Color(0.75, 0.85, 0.72).darkened(rng.randf() * 0.15))
	return mb.commit()


## A short understory tree for the forest floor: a thin stem, two or three low clumps.
static func shrub_mesh(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var leaves := _leaves()
	var h := rng.randf_range(1.6, 2.8)
	_seg(mb, _bark(), Vector3.ZERO, Vector3.UP * h, 0.08, 0.05, 4)
	for k in range(rng.randi_range(2, 3)):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.8, 1.3)
		mb.add_blob(leaves, Transform3D(Basis(), Vector3(cos(a) * 0.5, h - k * 0.5, sin(a) * 0.5)), Vector3(r, r * 0.65, r), rng, 0.2, 2, 5, 0.5,
			Color(0.85, 1.0, 0.8).darkened(rng.randf_range(0.1, 0.3)))
	return mb.commit()


## Big glossy leaves fanned out low over the ground (elephant ear, young banana).
static func broadleaf_mesh(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := PSXMat.cutout("broadleaf", Color.WHITE, 0.05, 1.2)
	var n := rng.randi_range(5, 7)
	for k in range(n):
		var a := TAU * k / n + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var L := rng.randf_range(1.0, 1.7)
		var w := L * 0.32
		var base := dir * 0.15 + Vector3.UP * rng.randf_range(0.35, 0.8)
		var mid := base + dir * L * 0.5 + Vector3.UP * rng.randf_range(0.15, 0.35)
		var tip := base + dir * L + Vector3.DOWN * rng.randf_range(0.0, 0.3)
		var col := Color.WHITE.darkened(rng.randf_range(0.0, 0.2))
		mb.add_quad(m, base - side * w * 0.3, base + side * w * 0.3, mid + side * w, mid - side * w, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0.5), Vector2(0, 0.5), col, Vector3.UP)
		mb.add_quad(m, mid - side * w, mid + side * w, tip + side * w * 0.2, tip - side * w * 0.2, Vector2(0, 0.5), Vector2(1, 0.5), Vector2(1, 0), Vector2(0, 0), col, Vector3.UP)
	return mb.commit()


## A clump of bamboo culms, leafy at the tops.
static func bamboo_clump(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var culm := PSXMat.lit("bamboo")
	var leaf := PSXMat.cutout("fern", Color(0.95, 1.05, 0.75), 0.1, 6.0)
	for k in range(rng.randi_range(8, 12)):
		var a := rng.randf() * TAU
		var foot := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.9)
		var h := rng.randf_range(4.5, 8.0)
		var tip := foot + Vector3(cos(a), 0, sin(a)) * h * rng.randf_range(0.05, 0.2) + Vector3.UP * h
		_seg(mb, culm, foot, tip, 0.08, 0.06, 5, 0.5)
		for j in range(3):
			var at := foot.lerp(tip, 0.6 + j * 0.17)
			var yaw := rng.randf() * TAU
			mb.add_card(leaf, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.5), at), 1.3, 1.1, Rect2(0, 0, 1, 1), Color.WHITE.darkened(rng.randf() * 0.2))
	return mb.commit()
