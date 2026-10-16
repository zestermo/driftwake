class_name DesertPlants
extends RefCounted
## The desert's plants and rocks for GenIsland's MultiMeshes (DesertTheme.meshes): date palms in
## clumps with a skirt of dead fronds, flat-crowned acacias, dead trees, column and barrel cacti,
## prickly pear, dry scrub, tumbleweed, dry grass, reeds for the water, and sandstone boulders.
## Origins on the ground; materials shared (vertex colour for shade).


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _seg(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, uv := 0.6, col := Color.WHITE) -> void:
	var d := b - a
	mb.add_cylinder(mat, Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), a), r0, r1, d.length() + 0.04, sides, uv, col, false)


static func _bark() -> Material:
	return PSXMat.lit("bark", Color(0.86, 0.8, 0.7))


static func _dry_leaves() -> Material:
	return PSXMat.lit("leaves", Color(0.9, 0.92, 0.66), {"affine": 0.5})


static func _frond() -> Material:
	return PSXMat.cutout("palm_frond", Color(0.88, 0.95, 0.78), 0.2, 9.0)


static func _cactus() -> Material:
	return PSXMat.lit("cactus")


## A frond from `top` out along `out`, arching up then drooping (two bent quads), `droop` 0 stiff .. 1 hanging.
static func _frond_at(mb: MeshBuilder, mat: Material, top: Vector3, out: Vector3, l: float, w: float, rise: float, droop: float, col: Color) -> void:
	var side := Vector3(-out.z, 0, out.x)
	var p1 := top + out * l * 0.48 + Vector3.UP * rise
	var p2 := p1 + out * l * 0.52 + Vector3.DOWN * (0.4 + droop * 2.2)
	var n1 := (p1 - top).cross(side).normalized()
	if n1.y < 0: n1 = -n1
	var n2 := (p2 - p1).cross(side).normalized()
	if n2.y < 0: n2 = -n2
	mb.add_quad(mat, top - side * w * 0.5, top + side * w * 0.5, p1 + side * w, p1 - side * w, Vector2(0, 0), Vector2(0, 1), Vector2(0.48, 1), Vector2(0.48, 0), col, n1)
	mb.add_quad(mat, p1 - side * w, p1 + side * w, p2 + side * w * 0.35, p2 - side * w * 0.35, Vector2(0.48, 0), Vector2(0.48, 1), Vector2(1, 1), Vector2(1, 0), col, n2)


## A date palm: one to three straight trunks from one root, each a crown of stiff fronds
## over a skirt of dead ones hanging brown, orange date clusters under the green (7-12 m).
static func date_palm(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("palm_bark", Color(0.92, 0.84, 0.72), {"affine": 0.6})
	var frond := _frond()
	var dead := PSXMat.cutout("palm_frond", Color(0.62, 0.48, 0.3), 0.1, 9.0)
	var dates := PSXMat.flat(Color(0.82, 0.42, 0.12))
	var n := 1 + (rng.randi() % 3 if rng.randf() < 0.55 else 0)
	for t in range(n):
		var h := rng.randf_range(7.0, 11.5) * (1.0 if t == 0 else rng.randf_range(0.55, 0.85))
		var a := rng.randf() * TAU
		var lean := Vector3(cos(a), 0, sin(a)) * (rng.randf_range(0.2, 0.9) if t == 0 else rng.randf_range(1.0, 2.0))
		var foot := Vector3(cos(a), 0, sin(a)) * (0.0 if t == 0 else 0.45)
		var prev := foot
		var segs := 6
		for i in range(1, segs + 1):
			var k := float(i) / segs
			var p := foot + lean * k * k + Vector3.UP * h * k
			_seg(mb, bark, prev, p, lerpf(0.34, 0.24, k - 1.0 / segs), lerpf(0.34, 0.24, k), 6, 1.0, Color.WHITE.darkened(0.08 * (i % 2)))
			prev = p
		var top := prev
		# the skirt of old fronds, hanging close round the trunk under the crown
		for f in range(9):
			var fa := TAU * f / 9.0 + rng.randf_range(-0.2, 0.2)
			var out := Vector3(cos(fa), 0, sin(fa))
			var side := Vector3(-out.z, 0, out.x)
			var a0 := top + Vector3.DOWN * 0.4 + out * 0.25
			var a1 := a0 + out * 0.7 + Vector3.DOWN * rng.randf_range(1.6, 2.4)
			mb.add_quad(dead, a0 - side * 0.35, a0 + side * 0.35, a1 + side * 0.2, a1 - side * 0.2, Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color.WHITE.darkened(rng.randf() * 0.2), out)
		# the green crown: stiff, rising, only the outer half bending down
		var nf := rng.randi_range(11, 14)
		for f in range(nf):
			var fa := TAU * f / nf + rng.randf_range(-0.15, 0.15)
			var up := 1.0 if f % 2 == 0 else 0.4
			_frond_at(mb, frond, top, Vector3(cos(fa), 0, sin(fa)), rng.randf_range(3.4, 4.4), rng.randf_range(0.55, 0.7), up + rng.randf_range(0.2, 0.6), rng.randf_range(0.2, 0.6),
				Color.WHITE.darkened(rng.randf_range(0.0, 0.18)))
		for k in range(rng.randi_range(2, 4)):
			var da := rng.randf() * TAU
			mb.add_blob(dates, Transform3D(Basis(), top + Vector3(cos(da) * 0.45, -0.7, sin(da) * 0.45)), Vector3(0.22, 0.4, 0.22), rng, 0.25, 2, 5, 1.0)
	return mb.commit()


## An umbrella-thorn acacia: a short trunk forking low into spreading limbs, a flat crown in pads (3.5-6 m).
static func acacia(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var bark := _bark()
	var leaves := _dry_leaves()
	var h := rng.randf_range(3.5, 5.8)
	var fork := Vector3(rng.randf_range(-0.3, 0.3), h * rng.randf_range(0.35, 0.5), rng.randf_range(-0.3, 0.3))
	_seg(mb, bark, Vector3.ZERO, fork, 0.24, 0.18, 6)
	var n := rng.randi_range(3, 4)
	var off := rng.randf() * TAU
	var tops: Array = []
	for k in range(n):
		var a := off + TAU * k / n + rng.randf_range(-0.3, 0.3)
		var end := Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.6, 2.8) + Vector3.UP * (h + rng.randf_range(-0.4, 0.3))
		var mid := fork.lerp(end, 0.5) + Vector3(cos(a), 0, sin(a)) * 0.3
		_seg(mb, bark, fork, mid, 0.16, 0.11, 5)
		_seg(mb, bark, mid, end, 0.11, 0.06, 5)
		tops.append(end)
	for e in tops:
		var r := rng.randf_range(1.6, 2.3)
		mb.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), e + Vector3.UP * 0.25), Vector3(r, 0.42, r), rng, 0.18, 2, 7, 0.5,
			Color.WHITE.darkened(rng.randf_range(0.0, 0.12)))
	var mid_top := fork.lerp(Vector3(0, h + 0.4, 0), 0.9)
	mb.add_blob(leaves, Transform3D(Basis(), mid_top + Vector3.UP * 0.3), Vector3(2.4, 0.45, 2.4), rng, 0.18, 2, 7, 0.5)
	# the crown's underside in shade
	mb.add_blob(leaves, Transform3D(Basis(), mid_top - Vector3.UP * 0.05), Vector3(2.8, 0.25, 2.8), rng, 0.1, 2, 7, 0.5, Color(0.6, 0.6, 0.5))
	return mb.commit()


## A big acacia for the theme's "giant" lists ([body, detail, lean]): wider, older, its crown in two tiers.
static func old_acacia(seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var body := MeshBuilder.new()
	var bark := _bark()
	var leaves := _dry_leaves()
	var h := rng.randf_range(7.5, 9.5)
	var fork := Vector3(0, h * 0.4, 0)
	_seg(body, bark, Vector3.ZERO, fork, 0.5, 0.36, 7)
	for k in range(5):
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var end := Vector3(cos(a), 0, sin(a)) * rng.randf_range(3.0, 4.6) + Vector3.UP * (h + rng.randf_range(-0.6, 0.4))
		_seg(body, bark, fork, end, 0.26, 0.1, 5)
		var r := rng.randf_range(2.4, 3.2)
		body.add_blob(leaves, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), end + Vector3.UP * 0.3), Vector3(r, 0.55, r), rng, 0.18, 2, 7, 0.5, Color.WHITE.darkened(rng.randf_range(0.0, 0.12)))
	body.add_blob(leaves, Transform3D(Basis(), Vector3.UP * (h + 0.5)), Vector3(4.2, 0.6, 4.2), rng, 0.18, 2, 8, 0.5)
	var detail := MeshBuilder.new()
	var thorn := PSXMat.flat(Color(0.7, 0.62, 0.48))
	for k in range(4):
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0, sin(a))
		_seg(detail, bark, root * 0.3 + Vector3.UP * 0.2, root * rng.randf_range(1.2, 1.8) + Vector3.DOWN * 0.15, 0.14, 0.05, 4)
	for k in range(10):
		var a := rng.randf() * TAU
		detail.add_box(thorn, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 0.4, rng.randf_range(0.8, fork.y), sin(a) * 0.4)), Vector3(0.03, 0.03, 0.25), 1.0, Color.WHITE, false)
	return [body.commit(), detail.commit(), Vector3.ZERO]


## A dead tree: a pale twisted trunk, bare limbs forking twice, no leaf left (3-6 m).
static func dead_tree(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("bark", Color(0.95, 0.9, 0.82))
	var h := rng.randf_range(3.0, 5.5)
	var a := rng.randf() * TAU
	var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.3, 1.2)
	var mid := lean * 0.4 + Vector3.UP * h * 0.55
	var top := lean + Vector3.UP * h
	mb.add_tube(wood, MeshBuilder.curve_points(Vector3.ZERO, mid, top, 5), 0.26, 0.1, 5, 0.6, Color(0.85, 0.82, 0.76))
	var forks: Array = [[mid, 2.2, 0.12], [top, 1.6, 0.08]]
	for f in forks:
		var from: Vector3 = f[0]
		for k in range(rng.randi_range(2, 3)):
			var b := rng.randf() * TAU
			var end := from + Vector3(cos(b), 0, sin(b)) * float(f[1]) + Vector3.UP * rng.randf_range(0.6, 1.8)
			var ctrl := from.lerp(end, 0.5) + Vector3.UP * 0.4
			mb.add_tube(wood, MeshBuilder.curve_points(from, ctrl, end, 4), float(f[2]), 0.03, 4, 0.8, Color(0.9, 0.86, 0.8))
			var tw := end + Vector3(cos(b + 0.8), 0.5, sin(b + 0.8)) * 0.7
			mb.add_tube(wood, PackedVector3Array([end, tw]), 0.03, 0.015, 3, 1.0)
	return mb.commit()


## A column cactus: a ribbed trunk and one to three arms turning up (2-5 m).
static func column_cactus(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := _cactus()
	var h := rng.randf_range(2.2, 4.8)
	var r := rng.randf_range(0.22, 0.32)
	_lathe_column(mb, m, Vector3.ZERO, h, r)
	for k in range(rng.randi_range(1, 3)):
		var a := rng.randf() * TAU
		var y := rng.randf_range(h * 0.3, h * 0.6)
		var out := Vector3(cos(a), 0, sin(a))
		var elbow := Vector3(0, y, 0) + out * rng.randf_range(0.6, 0.9)
		var up := rng.randf_range(0.8, h - y)
		mb.add_tube(m, MeshBuilder.curve_points(Vector3(0, y, 0), Vector3(0, y, 0) + out * 0.7 + Vector3.DOWN * 0.1, elbow + Vector3.UP * 0.25, 4), r * 0.7, r * 0.7, 7, 1.0)
		_lathe_column(mb, m, elbow + Vector3.UP * 0.2, up, r * 0.72)
	return mb.commit()


static func _lathe_column(mb: MeshBuilder, m: Material, at: Vector3, h: float, r: float) -> void:
	var rings := [[0.0, r, r], [h * 0.85, r * 0.98, r * 0.98], [h * 0.96, r * 0.7, r * 0.7], [h, r * 0.2, r * 0.2]]
	mb.add_loft(m, Transform3D(Basis(), at), rings, MeshBuilder.profile_circle(10), 1.0)


## A barrel cactus: a squat ribbed ball, a ring of yellow flowers on top (0.4-0.8 m).
static func barrel_cactus(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := _cactus()
	var flower := PSXMat.flat(Color(0.95, 0.78, 0.2))
	for k in range(rng.randi_range(1, 3)):
		var a := rng.randf() * TAU
		var s := rng.randf_range(0.3, 0.45) * (1.0 if k == 0 else 0.7)
		var at := Vector3(cos(a), 0, sin(a)) * (0.0 if k == 0 else 0.55)
		mb.add_loft(m, Transform3D(Basis(), at), [[0.0, s * 0.8, s * 0.8], [s * 0.6, s, s], [s * 1.3, s * 0.8, s * 0.8], [s * 1.6, s * 0.25, s * 0.25]], MeshBuilder.profile_circle(10), 1.0)
		for f in range(5):
			var fa := TAU * f / 5.0
			mb.add_box(flower, Transform3D(Basis(Vector3.UP, fa), at + Vector3(cos(fa) * s * 0.3, s * 1.6, sin(fa) * s * 0.3)), Vector3(0.07, 0.05, 0.07), 1.0)
	return mb.commit()


## Prickly pear: flat oval pads growing off each other, a few red fruits on the rims (1-1.6 m).
static func prickly_pear(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := _cactus()
	var fruit := PSXMat.flat(Color(0.75, 0.15, 0.25))
	var pads: Array = [[Vector3(0, 0.3, 0), rng.randf() * TAU, 0.0]]
	var i := 0
	while i < pads.size() and pads.size() < 9:
		var p: Array = pads[i]
		for k in range(rng.randi_range(1, 2)):
			if pads.size() >= 9:
				break
			var yaw := float(p[1]) + rng.randf_range(-0.9, 0.9)
			var tilt := float(p[2]) + rng.randf_range(-0.6, 0.6)
			var b := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, tilt)
			pads.append([(p[0] as Vector3) + b * Vector3(0, 0.42, 0), yaw, tilt])
		i += 1
	for p in pads:
		var b := Basis(Vector3.UP, float(p[1])) * Basis(Vector3.FORWARD, float(p[2]))
		mb.add_blob(m, Transform3D(b, p[0]), Vector3(0.24, 0.3, 0.06), rng, 0.08, 3, 8, 1.0, Color.WHITE.darkened(rng.randf() * 0.15))
		if rng.randf() < 0.35:
			mb.add_blob(fruit, Transform3D(b, (p[0] as Vector3) + b * Vector3(0.1, 0.3, 0)), Vector3(0.05, 0.07, 0.05), rng, 0.1, 2, 5)
	return mb.commit()


## Dry scrub: a low tangle of thorny stems (cross cards) on a dusty-olive mound.
static func scrub(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := PSXMat.cutout("thornbrush", Color(0.95, 0.9, 0.8), 0.05, 1.2)
	var s := rng.randf_range(0.9, 1.5)
	mb.add_cross_cards(m, Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3.ZERO), s * 1.3, s, 3)
	return mb.commit()


## Saltbush: a grey-green rounded shrub, low and wide.
static func saltbush(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var leaves := PSXMat.lit("leaves", Color(0.78, 0.82, 0.66), {"affine": 0.5})
	for k in range(rng.randi_range(3, 5)):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.45, 0.75)
		mb.add_blob(leaves, Transform3D(Basis(), Vector3(cos(a) * 0.4, r * 0.5, sin(a) * 0.4)), Vector3(r, r * 0.7, r), rng, 0.2, 2, 6, 0.6,
			Color.WHITE.darkened(rng.randf_range(0.0, 0.2)), -0.2)
	return mb.commit()


## A tumbleweed: a ball of dry twigs caught where the wind left it.
static func tumbleweed(seed_value: int) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var twig := PSXMat.flat(Color(0.62, 0.5, 0.32))
	var r := rng.randf_range(0.35, 0.6)
	var c := Vector3(0, r * 0.85, 0)
	for k in range(14):
		var a := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * r
		var b := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * r
		mb.add_tube(twig, MeshBuilder.curve_points(c + a, c + (a + b) * 0.2, c + b, 4), 0.018, 0.012, 3, 1.0, Color.WHITE.darkened(rng.randf() * 0.25))
	return mb.commit()


static func dry_grass() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var m := PSXMat.cutout("dry_grass", Color.WHITE, 0.1, 0.6)
	mb.add_cross_cards(m, Transform3D.IDENTITY, 0.8, 0.6, 2)
	return mb.commit()


## Reeds in a clump at the water (oasis pools, the wadi's damp bed, the waterline).
static func reeds(seed_value: int, big := false) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := PSXMat.cutout("reeds", Color.WHITE, 0.15, 2.0)
	var s := rng.randf_range(1.4, 2.0) * (1.4 if big else 1.0)
	for k in range(3 if big else 2):
		var a := rng.randf() * TAU
		mb.add_cross_cards(m, Transform3D(Basis(Vector3.UP, rng.randf() * PI), Vector3(cos(a), 0, sin(a)) * 0.5 * k), s * 0.6, s, 2)
	return mb.commit()


## A sandstone boulder: blocky, cracked flat on top (wind-cut), banded.
static func boulder(seed_value: int, flat := false) -> ArrayMesh:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var m := PSXMat.lit("desert_rock", Color.WHITE, {"affine": 0.6})
	var radii := Vector3(rng.randf_range(0.9, 1.3), rng.randf_range(0.5, 0.8) * (0.45 if flat else 1.0), rng.randf_range(0.8, 1.2))
	mb.add_blob(m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, radii.y * 0.45, 0)), radii, rng, 0.16, 3, 6, 0.5, Color.WHITE, -0.4)
	# a flat wind-cut cap
	mb.add_blob(m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, radii.y * 0.95, 0)), Vector3(radii.x * 0.8, radii.y * 0.18, radii.z * 0.8), rng, 0.1, 2, 6, 0.5, Color(1.05, 1.0, 0.95), 0.0)
	return mb.commit()
