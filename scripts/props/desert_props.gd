class_name DesertProps
extends RefCounted
## The desert's props and the buildings Buildings.house can't make: clay urns and water jars,
## brass lantern posts, carved waymarkers. Origins on the ground, facing +Z; seeded.


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _body(n: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = n
	body.collision_layer = 1
	body.collision_mask = 0
	return body


static func _brass() -> Material:
	return PSXMat.lit("metal", Color(1.05, 0.8, 0.42))


static func _clay() -> Material:
	return PSXMat.lit("adobe", Color(0.86, 0.56, 0.38))


static func _cyl_col(body: Node3D, r: float, h: float, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	cs.shape = cyl
	cs.position = at
	body.add_child(cs)


static func _box_col(body: Node3D, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = at
	body.add_child(cs)


## A tall clay urn (a water jar): a lathe with a narrow neck and a lip, dark painted bands; `size` ~1 (1.1 m).
static func urn(size: float, seed_value: int) -> Node3D:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var s := size * rng.randf_range(0.85, 1.1)
	var rings: Array = []
	for r in [[0.0, 0.16], [0.05, 0.24], [0.35, 0.36], [0.62, 0.34], [0.86, 0.16], [0.98, 0.13], [1.02, 0.18], [1.08, 0.17]]:
		rings.append([float(r[0]) * s, float(r[1]) * s, float(r[1]) * s])
	mb.add_loft(_clay(), Transform3D.IDENTITY, rings, MeshBuilder.profile_circle(10), 1.2, Color.WHITE.darkened(rng.randf_range(0.0, 0.15)), true, false)
	var band := PSXMat.flat(Color(0.28, 0.2, 0.16))
	for y in [0.45, 0.52]:
		mb.add_cylinder(band, Transform3D(Basis(), Vector3(0, y * s, 0)), 0.362 * s, 0.358 * s, 0.03 * s, 10, 1.0)
	var body := _body("Urn")
	body.add_child(mb.to_instance("UrnMesh"))
	_cyl_col(body, 0.34 * s, 1.05 * s, Vector3(0, 0.52 * s, 0))
	return body


## A lantern post: a sandstone footing, a dark iron post, a scrolled arm with a pierced brass lantern
## (glowing panes, an onion cap) hanging from it. "Flame" marks where its light goes.
static func lantern_post(h: float) -> Node3D:
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("sandstone")
	var iron := PSXMat.lit("metal", Color(0.3, 0.26, 0.22))
	var brass := _brass()
	var glow := PSXMat.glow(Color(1.0, 0.72, 0.35), 1.6)
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(0.5, 0.4, 0.5), 0.8)
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, 0.43, 0)), Vector3(0.38, 0.06, 0.38), 0.8)
	mb.add_cylinder(iron, Transform3D(Basis(), Vector3(0, 0.46, 0)), 0.06, 0.05, h - 0.46, 6, 1.0)
	mb.add_box(iron, Transform3D(Basis(), Vector3(0.28, h - 0.08, 0)), Vector3(0.62, 0.05, 0.05), 1.0, Color.WHITE, false)
	mb.add_tube(iron, MeshBuilder.curve_points(Vector3(0.02, h - 0.4, 0), Vector3(0.12, h - 0.12, 0), Vector3(0.38, h - 0.08, 0), 5), 0.025, 0.02, 4, 1.0)
	var lx := 0.55
	var top := h - 0.2
	mb.add_cylinder(iron, Transform3D(Basis(), Vector3(lx, top - 0.02, 0)), 0.012, 0.012, 0.14, 3, 1.0)
	var body_y := top - 0.5
	mb.add_loft(brass, Transform3D(Basis(), Vector3(lx, body_y, 0)), [[0.0, 0.05, 0.05], [0.04, 0.13, 0.13], [0.06, 0.14, 0.14]], MeshBuilder.profile_circle(8), 1.0)
	mb.add_cylinder(glow, Transform3D(Basis(), Vector3(lx, body_y + 0.06, 0)), 0.12, 0.12, 0.24, 8, 1.0)
	for k in range(8):
		var a := TAU * k / 8.0
		mb.add_box(brass, Transform3D(Basis(Vector3.UP, -a), Vector3(lx + cos(a) * 0.125, body_y + 0.18, sin(a) * 0.125)), Vector3(0.025, 0.26, 0.025), 1.0)
	mb.add_loft(brass, Transform3D(Basis(), Vector3(lx, body_y + 0.3, 0)), [[0.0, 0.15, 0.15], [0.05, 0.16, 0.16], [0.12, 0.12, 0.12], [0.2, 0.05, 0.05], [0.26, 0.015, 0.015]],
		MeshBuilder.profile_circle(8), 1.0)
	var root := _body("LanternPost")
	root.add_child(mb.to_instance("PostMesh"))
	_box_col(root, Vector3(0.5, h, 0.5), Vector3(0, h * 0.5, 0))
	var m := Marker3D.new()
	m.name = "Flame"
	m.position = Vector3(lx, body_y + 0.18, 0)
	root.add_child(m)
	return root


## A waymarker: a carved sandstone stele on a plinth, a sun cut into its face, a cairn beside it.
static func waymarker(seed_value: int) -> Node3D:
	var rng := _rng(seed_value)
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("sandstone")
	var dark := PSXMat.flat(Color(0.42, 0.3, 0.2))
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, 0.12, 0)), Vector3(0.9, 0.24, 0.6), 0.8, Color(0.85, 0.85, 0.85))
	var outline := PackedVector2Array([Vector2(-0.3, 0), Vector2(0.3, 0), Vector2(0.28, 1.4), Vector2(0.18, 1.62), Vector2(0, 1.7), Vector2(-0.18, 1.62), Vector2(-0.28, 1.4)])
	mb.add_extrude(stone, Transform3D(Basis(), Vector3(0, 0.24, -0.1)), outline, 0.2, 0.8)
	for k in range(8):
		var a := TAU * k / 8.0
		mb.add_box(dark, Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * 0.12, 1.45 + sin(a) * 0.12, 0.105)), Vector3(0.03, 0.09, 0.01), 1.0)
	mb.add_cylinder(dark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.45, 0.1)), 0.06, 0.06, 0.012, 8, 1.0)
	var rock := PSXMat.lit("desert_rock")
	for k in range(rng.randi_range(3, 5)):
		var s := rng.randf_range(0.12, 0.22) * (1.0 - k * 0.12)
		mb.add_blob(rock, Transform3D(Basis(), Vector3(0.62, 0.08 + k * 0.17, rng.randf_range(-0.05, 0.05))), Vector3(s * 1.3, s * 0.8, s), rng, 0.15, 2, 5, 1.0)
	var body := _body("Waymarker")
	body.add_child(mb.to_instance("MarkerMesh"))
	_box_col(body, Vector3(0.9, 1.9, 0.6), Vector3(0, 0.95, 0))
	return body
