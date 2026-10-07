class_name Props
extends RefCounted
## Procedural PSX prop factory. Every function returns a ready-to-add Node3D
## (mesh + simple collision) built from MeshBuilder parts and PSXMat materials.
## Origins are at ground level; +Z is the "front" of buildings unless noted.

const WORLD_LAYER := 1


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
static func _body(node_name: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = node_name
	b.collision_layer = WORLD_LAYER
	b.collision_mask = 0
	return b


static func _add_box_col(body: Node3D, size: Vector3, pos: Vector3, rot_y: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	cs.rotation.y = rot_y
	body.add_child(cs)


static func _add_cyl_col(body: Node3D, radius: float, height: float, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = pos + Vector3(0, height * 0.5, 0)
	body.add_child(cs)


static func _xf(pos: Vector3, rot_y: float = 0.0, scale: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(scale), pos)


static func _xf_basis(basis: Basis, pos: Vector3) -> Transform3D:
	return Transform3D(basis, pos)


# --------------------------------------------------------------------------
# Vegetation meshes (used through MultiMesh by the island scatterer)
# --------------------------------------------------------------------------
static func palm_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("palm_bark", Color.WHITE, {"affine": 0.6})
	var frond := PSXMat.cutout("palm_frond", Color(0.95, 1.0, 0.9), 0.25, 9.0)
	var height := rng.randf_range(6.5, 9.0)
	var lean := Vector3(rng.randf_range(1.2, 2.6), 0, 0)
	var segs := 7
	var prev := Vector3.ZERO
	var r0 := 0.27
	for i in range(segs):
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var p0 := lean * (t0 * t0) + Vector3.UP * height * t0
		var p1 := lean * (t1 * t1) + Vector3.UP * height * t1
		var dir := (p1 - p0).normalized()
		var basis := Basis(Quaternion(Vector3.UP, dir))
		var ra := lerpf(r0, 0.15, t0)
		var rb := lerpf(r0, 0.15, t1)
		mb.add_cylinder(bark, Transform3D(basis, p0), ra, rb, p0.distance_to(p1) + 0.02, 5, 1.0, Color.WHITE, false, false, true)
		prev = p1
	var top := prev
	# coconuts
	var nut := PSXMat.flat(Color(0.32, 0.22, 0.12))
	for k in range(3):
		var a := TAU * k / 3.0 + rng.randf()
		mb.add_box(nut, _xf(top + Vector3(cos(a) * 0.22, -0.25, sin(a) * 0.22), a), Vector3(0.24, 0.24, 0.24), 1.0)
	# fronds: two bent quads each, frond texture u along length
	var n_fronds := 8
	for f in range(n_fronds):
		var a := TAU * f / n_fronds + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x)
		var w := rng.randf_range(0.7, 0.9)
		var l1 := rng.randf_range(1.8, 2.3)
		var l2 := rng.randf_range(2.0, 2.6)
		var p0 := top
		var p1 := top + out * l1 + Vector3.UP * rng.randf_range(0.3, 0.7)
		var p2 := p1 + out * l2 + Vector3.DOWN * rng.randf_range(1.2, 1.9)
		var col := Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.15))
		var n1 := (p1 - p0).cross(side).normalized()
		if n1.y < 0: n1 = -n1
		var n2 := (p2 - p1).cross(side).normalized()
		if n2.y < 0: n2 = -n2
		mb.add_quad(frond, p0 - side * w * 0.6, p0 + side * w * 0.6, p1 + side * w, p1 - side * w,
			Vector2(0, 0), Vector2(0, 1), Vector2(0.48, 1), Vector2(0.48, 0), col, n1)
		mb.add_quad(frond, p1 - side * w, p1 + side * w, p2 + side * w * 0.4, p2 - side * w * 0.4,
			Vector2(0.48, 0), Vector2(0.48, 1), Vector2(1, 1), Vector2(1, 0), col, n2)
	return mb.commit()


static func jungle_tree_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("bark")
	var leaves := PSXMat.lit("leaves", Color(0.95, 1.0, 0.95), {"affine": 0.5})
	var h := rng.randf_range(4.5, 7.0)
	mb.add_cylinder(bark, Transform3D.IDENTITY, 0.42, 0.26, h, 6, 0.8)
	# root flare
	for k in range(3):
		var a := TAU * k / 3.0 + rng.randf()
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.BACK, deg_to_rad(55))
		mb.add_box(bark, Transform3D(b, Vector3(cos(a) * 0.3, 0.2, sin(a) * 0.3)), Vector3(0.18, 0.9, 0.18), 0.8)
	# branches
	for k in range(2):
		var a := TAU * k / 2.0 + rng.randf_range(0, 1.5)
		var b := Basis(Vector3.UP, -a) * Basis(Vector3.BACK, deg_to_rad(-50))
		mb.add_cylinder(bark, Transform3D(b, Vector3(0, h * 0.7, 0)), 0.14, 0.08, 2.0, 5, 0.8)
	# canopy blobs
	var blobs := rng.randi_range(3, 4)
	for k in range(blobs):
		var a := TAU * k / blobs + rng.randf()
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.8, 1.6) + Vector3.UP * (h + rng.randf_range(-0.3, 1.2))
		var r := rng.randf_range(1.6, 2.4)
		var col := Color.WHITE.darkened(rng.randf_range(0.0, 0.2))
		mb.add_blob(leaves, _xf(off, rng.randf() * TAU), Vector3(r, r * 0.75, r), rng, 0.2, 3, 6, 0.6, col)
	mb.add_blob(leaves, _xf(Vector3.UP * (h + 1.2)), Vector3(2.0, 1.5, 2.0), rng, 0.2, 3, 6, 0.6)
	return mb.commit()


static func pine_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("bark")
	var leaves := PSXMat.lit("leaves", Color(0.75, 0.9, 0.8))
	var h := rng.randf_range(5.0, 7.0)
	mb.add_cylinder(bark, Transform3D.IDENTITY, 0.25, 0.15, h * 0.5, 5, 0.8)
	for k in range(3):
		var y := h * (0.25 + k * 0.22)
		var r := 2.0 - k * 0.5
		mb.add_cone(leaves, _xf(Vector3(0, y, 0), rng.randf()), r, 2.4, 6, 0.6)
	return mb.commit()


static func bush_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new()
	var m := PSXMat.cutout("bush", Color.WHITE, 0.06, 1.4)
	var s := rng.randf_range(1.2, 1.9)
	mb.add_cross_cards(m, _xf(Vector3.ZERO, rng.randf() * PI), s * 1.2, s, 3)
	return mb.commit()


static func fern_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new()
	var m := PSXMat.cutout("fern", Color.WHITE, 0.08, 1.0)
	var s := rng.randf_range(0.9, 1.4)
	mb.add_cross_cards(m, _xf(Vector3.ZERO, rng.randf() * PI), s * 1.3, s, 3)
	return mb.commit()


static func grass_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var m := PSXMat.cutout("grass_tuft", Color.WHITE, 0.08, 0.7)
	mb.add_cross_cards(m, Transform3D.IDENTITY, 0.8, 0.7, 2)
	return mb.commit()


static func rock_mesh(seed_value: int, radius: float = 1.0, mossy: bool = false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new()
	var tint := Color(0.85, 0.95, 0.8) if mossy else Color.WHITE
	var m := PSXMat.lit("rock", tint, {"affine": 0.6})
	var radii := Vector3(radius * rng.randf_range(0.9, 1.3), radius * rng.randf_range(0.55, 0.85), radius * rng.randf_range(0.8, 1.2))
	mb.add_blob(m, _xf(Vector3(0, radii.y * 0.45, 0), rng.randf() * TAU), radii, rng, 0.22, 4, 7, 0.5, Color.WHITE, -0.5)
	return mb.commit()


## Scuttlebug burrow: a low dirt mound with a dark hole dug into its front,
## a few pebbles and scratch marks around it. Origin on the ground, hole -Z.
static func burrow(seed_value: int = 909) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mb := MeshBuilder.new()
	var dirt := PSXMat.lit("dirt", Color(0.82, 0.7, 0.58), {"affine": 0.6})
	var dark := PSXMat.flat(Color(0.05, 0.035, 0.025))
	mb.add_blob(dirt, _xf(Vector3(0, 0.05, 0.15)), Vector3(1.05, 0.45, 0.95), rng, 0.15, 4, 8, 0.6, Color.WHITE, -0.1)
	# the hole: a dark oval set into the mound's front slope
	var hole := Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, 0.2, -0.6))
	mb.add_cylinder(dark, hole * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 0.3, 0.26, 0.06, 7, 0.5, Color.WHITE, true, false, false)
	# spoil heap in front of the hole
	mb.add_blob(dirt, _xf(Vector3(0.1, 0.0, -1.05)), Vector3(0.5, 0.14, 0.38), rng, 0.2, 3, 6, 0.6, Color(0.9, 0.85, 0.8), -0.1)
	var rock := PSXMat.lit("rock", Color(0.8, 0.78, 0.72), {"affine": 0.6})
	for i in range(4):
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.0, 1.5)
		mb.add_blob(rock, _xf(Vector3(cos(a) * r, 0.03, sin(a) * r)), Vector3.ONE * rng.randf_range(0.08, 0.15), rng, 0.25, 3, 5)
	var n := Node3D.new()
	n.name = "Burrow"
	n.add_child(mb.to_instance())
	return n


# --------------------------------------------------------------------------
# Small props
# --------------------------------------------------------------------------
static func barrel() -> Node3D:
	var body := _body("Barrel")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var band := PSXMat.lit("metal", Color(0.55, 0.55, 0.6))
	mb.add_cylinder(wood, Transform3D.IDENTITY, 0.34, 0.38, 0.5, 8, 1.2, Color.WHITE, false)
	mb.add_cylinder(wood, _xf(Vector3(0, 0.5, 0)), 0.38, 0.34, 0.5, 8, 1.2, Color.WHITE, true)
	mb.add_cylinder(band, _xf(Vector3(0, 0.15, 0)), 0.36, 0.37, 0.06, 8, 1.0, Color.WHITE, false)
	mb.add_cylinder(band, _xf(Vector3(0, 0.8, 0)), 0.37, 0.36, 0.06, 8, 1.0, Color.WHITE, false)
	body.add_child(mb.to_instance())
	_add_cyl_col(body, 0.38, 1.0, Vector3.ZERO)
	return body


static func crate(size: float = 0.8) -> Node3D:
	var body := _body("Crate")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks", Color(0.9, 0.85, 0.75))
	var dark := PSXMat.lit("planks_dark")
	mb.add_box(wood, _xf(Vector3(0, size * 0.5, 0)), Vector3.ONE * size, 1.0 / size, Color.WHITE, true, false)
	# corner trims
	for x in [-1, 1]:
		for z in [-1, 1]:
			mb.add_box(dark, _xf(Vector3(x * size * 0.47, size * 0.5, z * size * 0.47)), Vector3(0.08, size + 0.02, 0.08), 1.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3.ONE * size, Vector3(0, size * 0.5, 0))
	return body


static func lantern_post(height: float = 2.6) -> Node3D:
	var body := _body("LanternPost")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var glass := PSXMat.glow(Color(1.0, 0.75, 0.35), 2.5)
	var metal := PSXMat.flat(Color(0.15, 0.15, 0.17))
	mb.add_box(wood, _xf(Vector3(0, height * 0.5, 0)), Vector3(0.16, height, 0.16), 1.0)
	mb.add_box(wood, _xf(Vector3(0.3, height - 0.1, 0)), Vector3(0.7, 0.1, 0.1), 1.0)
	mb.add_box(glass, _xf(Vector3(0.55, height - 0.45, 0)), Vector3(0.22, 0.3, 0.22), 1.0, Color.WHITE, false)
	mb.add_pyramid_roof(metal, _xf(Vector3(0.55, height - 0.3, 0)), 0.26, 0.26, 0.18, 0.02, 1.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(0.2, height, 0.2), Vector3(0, height * 0.5, 0))
	return body


static func fence_segment(length: float, height: float = 1.1) -> Node3D:
	var body := _body("Fence")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_weathered")
	mb.add_box(wood, _xf(Vector3(0, height * 0.5, 0)), Vector3(0.14, height, 0.14), 1.0)
	mb.add_box(wood, _xf(Vector3(0, height * 0.5, length)), Vector3(0.14, height, 0.14), 1.0)
	mb.add_box(wood, _xf(Vector3(0, height * 0.75, length * 0.5)), Vector3(0.06, 0.12, length), 0.8)
	mb.add_box(wood, _xf(Vector3(0, height * 0.35, length * 0.5)), Vector3(0.06, 0.12, length), 0.8)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(0.2, height, length), Vector3(0, height * 0.5, length * 0.5))
	return body


static func bench() -> Node3D:
	var body := _body("Bench")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	mb.add_box(wood, _xf(Vector3(0, 0.45, 0)), Vector3(1.8, 0.08, 0.4), 1.0, Color.WHITE, false)
	for x in [-0.75, 0.75]:
		mb.add_box(wood, _xf(Vector3(x, 0.22, 0)), Vector3(0.08, 0.45, 0.36), 1.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(1.8, 0.5, 0.4), Vector3(0, 0.25, 0))
	return body


static func table() -> Node3D:
	var body := _body("Table")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	mb.add_box(wood, _xf(Vector3(0, 0.78, 0)), Vector3(1.4, 0.08, 0.9), 1.0, Color.WHITE, false)
	for x in [-0.6, 0.6]:
		for z in [-0.35, 0.35]:
			mb.add_box(wood, _xf(Vector3(x, 0.38, z)), Vector3(0.08, 0.76, 0.08), 1.0)
	# mugs
	var mug := PSXMat.flat(Color(0.75, 0.6, 0.3))
	mb.add_cylinder(mug, _xf(Vector3(0.3, 0.82, 0.1)), 0.06, 0.06, 0.14, 5, 1.0)
	mb.add_cylinder(mug, _xf(Vector3(-0.35, 0.82, -0.15)), 0.06, 0.06, 0.14, 5, 1.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(1.4, 0.82, 0.9), Vector3(0, 0.41, 0))
	return body


static func rope_coil() -> Node3D:
	var n := Node3D.new()
	n.name = "RopeCoil"
	var mb := MeshBuilder.new()
	var rope := PSXMat.lit("rope")
	mb.add_cylinder(rope, Transform3D.IDENTITY, 0.35, 0.3, 0.18, 8, 2.0)
	n.add_child(mb.to_instance())
	return n


static func fish_rack() -> Node3D:
	var body := _body("FishRack")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_weathered")
	var fish := PSXMat.flat(Color(0.62, 0.7, 0.72))
	for x in [-1.0, 1.0]:
		mb.add_box(wood, _xf(Vector3(x, 0.9, 0)), Vector3(0.1, 1.8, 0.1), 1.0)
	mb.add_box(wood, _xf(Vector3(0, 1.75, 0)), Vector3(2.2, 0.08, 0.08), 1.0)
	for i in range(5):
		mb.add_box(fish, _xf(Vector3(-0.8 + i * 0.4, 1.45, 0), 0.0), Vector3(0.12, 0.45, 0.05), 1.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(2.2, 1.8, 0.2), Vector3(0, 0.9, 0))
	return body


static func rowboat() -> Node3D:
	var body := _body("Rowboat")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	# hull: two angled sides + bottom + bow/stern
	var L := 3.6
	var W := 1.2
	mb.add_box(dark, _xf(Vector3(0, 0.12, 0)), Vector3(W * 0.7, 0.12, L * 0.85), 1.0)
	for s in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, deg_to_rad(-25.0 * s))
		mb.add_box(wood, Transform3D(b, Vector3(s * W * 0.45, 0.35, 0)), Vector3(0.08, 0.55, L * 0.85), 1.0, Color.WHITE, false, false)
	mb.add_box(wood, _xf(Vector3(0, 0.35, L * 0.45), PI * 0.25), Vector3(0.6, 0.55, 0.6), 1.0)
	mb.add_box(wood, _xf(Vector3(0, 0.35, -L * 0.43)), Vector3(W * 0.95, 0.55, 0.1), 1.0)
	mb.add_box(dark, _xf(Vector3(0, 0.45, 0)), Vector3(W * 0.9, 0.06, 0.3), 1.0)
	# oars
	mb.add_box(wood, _xf(Vector3(0.25, 0.55, -0.2), 0.15), Vector3(0.06, 0.06, 2.4), 1.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(W, 0.7, L), Vector3(0, 0.35, 0))
	return body


static func treasure_chest_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var gold := PSXMat.lit("metal", Color(1.0, 0.8, 0.35), {"emission": Color(0.6, 0.4, 0.1), "emission_energy": 0.6})
	mb.add_box(wood, _xf(Vector3(0, 0.2, 0)), Vector3(0.7, 0.4, 0.45), 1.5, Color.WHITE, true, false)
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.35, 0.4, 0)), 0.225, 0.225, 0.7, 6, 1.5)
	mb.add_box(gold, _xf(Vector3(0, 0.38, 0.23)), Vector3(0.12, 0.16, 0.04), 2.0)
	for x in [-0.25, 0.25]:
		mb.add_box(gold, _xf(Vector3(x, 0.32, 0)), Vector3(0.05, 0.66, 0.47), 2.0)
	return mb.commit()


## Where you fell: a low mound of earth, a weathered headstone and a candle
## (your belongings are buried here until you come back for them).
static func grave_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var earth := PSXMat.lit("dirt", Color(0.75, 0.62, 0.48))
	var stone := PSXMat.lit("rock", Color(0.78, 0.78, 0.76))
	var flame := PSXMat.glow(Color(1.0, 0.75, 0.35), 3.0)
	mb.add_blob(earth, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0.35)), Vector3(0.5, 0.16, 0.85), rng, 0.15, 5, 8, 1.5)
	mb.add_box(stone, Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0, 0.45, -0.35)), Vector3(0.62, 0.9, 0.14), 1.2)
	mb.add_cylinder(stone, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.31, 0.88, -0.37)), 0.31, 0.31, 0.62, 8, 1.2, Color.WHITE, true, true)
	mb.add_box(PSXMat.lit("planks_dark", Color(0.3, 0.25, 0.2)), Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0, 0.62, -0.27)), Vector3(0.3, 0.06, 0.02), 1.0)
	mb.add_cylinder(PSXMat.lit("", Color(0.92, 0.88, 0.75)), Transform3D(Basis.IDENTITY, Vector3(0.36, 0.0, -0.12)), 0.04, 0.04, 0.16, 6, 1.0)
	mb.add_box(flame, Transform3D(Basis.IDENTITY, Vector3(0.36, 0.2, -0.12)), Vector3(0.04, 0.07, 0.04), 1.0)
	return mb.commit()


static func campfire() -> Node3D:
	var n := Node3D.new()
	n.name = "Campfire"
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("rock")
	var bark := PSXMat.lit("bark")
	var ember := PSXMat.glow(Color(1.0, 0.45, 0.15), 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(8):
		var a := TAU * i / 8.0
		mb.add_blob(stone, _xf(Vector3(cos(a) * 0.75, 0.08, sin(a) * 0.75)), Vector3(0.2, 0.14, 0.2), rng, 0.2, 3, 5, 1.0)
	for i in range(3):
		var a := TAU * i / 3.0
		var b := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, deg_to_rad(60))
		mb.add_cylinder(bark, Transform3D(b, Vector3(cos(a) * 0.35, 0.0, sin(a) * 0.35)), 0.08, 0.06, 0.8, 5, 1.0)
	mb.add_blob(ember, _xf(Vector3(0, 0.08, 0)), Vector3(0.3, 0.08, 0.3), rng, 0.1, 2, 5, 1.0)
	n.add_child(mb.to_instance())
	# flames
	var p := CPUParticles3D.new()
	p.name = "Flames"
	p.amount = 24
	p.lifetime = 0.7
	p.position = Vector3(0, 0.15, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.22
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.3))
	grad.set_color(1, Color(0.8, 0.15, 0.05))
	p.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	quad.material = fm
	p.mesh = quad
	n.add_child(p)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.position = Vector3(0, 0.8, 0)
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.set_script(load("res://scripts/props/flicker_light.gd"))
	n.add_child(light)
	return n


# --------------------------------------------------------------------------
# Buildings
# --------------------------------------------------------------------------
## Simple house: plank walls on a stone footing, thatch gable roof.
## Front door faces +Z. `foundation` extends below origin to hide slopes.
static func hut(w: float = 6.0, d: float = 5.0, wall_h: float = 2.6, wall_tex: String = "planks",
		roof_tex: String = "thatch", sign_tex: String = "") -> Node3D:
	var body := _body("Hut")
	var mb := MeshBuilder.new()
	var wall := PSXMat.lit(wall_tex)
	var stone := PSXMat.lit("stone_brick")
	var roof := PSXMat.lit(roof_tex, Color.WHITE, {"affine": 0.8})
	var beam := PSXMat.lit("planks_dark")
	var door := PSXMat.lit("door", Color.WHITE, {"vertex_color": false})
	var window := PSXMat.lit("window", Color.WHITE, {"emission": Color(0.9, 0.7, 0.35), "emission_energy": 0.6, "emission_tex": "window"})
	var found_h := 1.6
	mb.add_box(stone, _xf(Vector3(0, -found_h * 0.5 + 0.3, 0)), Vector3(w + 0.3, found_h, d + 0.3), 0.5, Color.WHITE, true, false)
	mb.add_box(wall, _xf(Vector3(0, 0.3 + wall_h * 0.5, 0)), Vector3(w, wall_h, d), 0.5, Color.WHITE, true, true)
	# corner beams
	for x in [-1, 1]:
		for z in [-1, 1]:
			mb.add_box(beam, _xf(Vector3(x * w * 0.5, 0.3 + wall_h * 0.5, z * d * 0.5)), Vector3(0.22, wall_h, 0.22), 0.6)
	mb.add_box(beam, _xf(Vector3(0, 0.3 + wall_h, 0)), Vector3(w + 0.1, 0.18, d + 0.1), 0.6)
	# door + windows (slightly proud of the wall)
	mb.add_box_unit_uv(door, _xf(Vector3(0, 0.3 + 1.0, d * 0.5 + 0.03)), Vector3(1.0, 2.0, 0.06))
	for x in [-w * 0.3, w * 0.3]:
		mb.add_box_unit_uv(window, _xf(Vector3(x, 0.3 + 1.5, d * 0.5 + 0.03)), Vector3(0.7, 0.7, 0.06))
	mb.add_box_unit_uv(window, _xf(Vector3(w * 0.5 + 0.03, 0.3 + 1.5, 0), PI * 0.5), Vector3(0.7, 0.7, 0.06))
	mb.add_box_unit_uv(window, _xf(Vector3(-w * 0.5 - 0.03, 0.3 + 1.5, 0), PI * 0.5), Vector3(0.7, 0.7, 0.06))
	# doorstep
	mb.add_box(stone, _xf(Vector3(0, 0.15, d * 0.5 + 0.35)), Vector3(1.4, 0.3, 0.7), 0.6, Color.WHITE, true, false)
	# roof (ridge along Z means gables at front/back: rotate so ridge runs along X)
	var roof_h := minf(w, d) * 0.45
	mb.add_gable_roof(roof, _xf(Vector3(0, 0.3 + wall_h + 0.09, 0), PI * 0.5), d, w, roof_h, 0.5, 0.5, Color.WHITE, wall)
	if sign_tex != "":
		var sign_m := PSXMat.lit(sign_tex, Color.WHITE, {"vertex_color": false})
		mb.add_box(beam, _xf(Vector3(w * 0.5 - 0.2, 0.3 + wall_h - 0.2, d * 0.5 + 0.55)), Vector3(0.08, 0.08, 1.1), 1.0)
		mb.add_box_unit_uv(sign_m, _xf(Vector3(w * 0.5 - 0.2, 0.3 + wall_h - 0.65, d * 0.5 + 0.9), PI * 0.5), Vector3(1.0, 0.5, 0.06))
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(w + 0.3, wall_h + 0.3 + found_h, d + 0.3), Vector3(0, (wall_h + 0.3 - found_h + 0.3) * 0.5, 0))
	return body


## Two-storey tavern with plaster walls, timber framing, tile roof and an
## outdoor bar counter + awning on its front (+Z).
static func tavern() -> Node3D:
	var w := 11.0
	var d := 8.0
	var h := 5.2
	var fl := 0.3  # floor level above ground
	var top := fl + h
	var body := _body("Tavern")
	var mb := MeshBuilder.new()
	var plaster := PSXMat.lit("plaster")
	var beam := PSXMat.lit("planks_dark")
	var stone := PSXMat.lit("stone_brick")
	var roof := PSXMat.lit("roof_tiles", Color.WHITE, {"affine": 0.8})
	var door := PSXMat.lit("door", Color.WHITE, {"vertex_color": false})
	var window := PSXMat.lit("window", Color.WHITE, {"emission": Color(1.0, 0.75, 0.35), "emission_energy": 1.0, "emission_tex": "window"})
	var awning := PSXMat.lit("cloth_red", Color.WHITE, {"affine": 0.6})
	var wood := PSXMat.lit("planks")
	var sign_m := PSXMat.lit("sign_tavern", Color.WHITE, {"vertex_color": false})
	mb.add_box(stone, _xf(Vector3(0, fl - 1.0, 0)), Vector3(w + 0.4, 2.0, d + 0.4), 0.5, Color.WHITE, true, false)
	mb.add_box(stone, _xf(Vector3(0, fl + 0.6, 0)), Vector3(w, 1.2, d), 0.5, Color.WHITE, true, true)
	mb.add_box(plaster, _xf(Vector3(0, (fl + 1.2 + top) * 0.5, 0)), Vector3(w, top - fl - 1.2, d), 0.35, Color.WHITE, true, true)
	# timber frame
	for x in [-w * 0.5, -w * 0.17, w * 0.17, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]:
			mb.add_box(beam, _xf(Vector3(x, fl + h * 0.5, z)), Vector3(0.24, h, 0.24), 0.6)
	for y in [fl + 1.2, fl + 2.9, top]:
		mb.add_box(beam, _xf(Vector3(0, y, d * 0.5)), Vector3(w + 0.1, 0.2, 0.26), 0.6)
		mb.add_box(beam, _xf(Vector3(0, y, -d * 0.5)), Vector3(w + 0.1, 0.2, 0.26), 0.6)
		mb.add_box(beam, _xf(Vector3(w * 0.5, y, 0)), Vector3(0.26, 0.2, d + 0.1), 0.6)
		mb.add_box(beam, _xf(Vector3(-w * 0.5, y, 0)), Vector3(0.26, 0.2, d + 0.1), 0.6)
	# windows
	for x in [-w * 0.34, 0.0, w * 0.34]:
		mb.add_box_unit_uv(window, _xf(Vector3(x, fl + 3.9, d * 0.5 + 0.04)), Vector3(0.9, 0.9, 0.06))
		mb.add_box_unit_uv(window, _xf(Vector3(x, fl + 3.9, -d * 0.5 - 0.04)), Vector3(0.9, 0.9, 0.06))
	for x in [-w * 0.34, w * 0.34]:
		mb.add_box_unit_uv(window, _xf(Vector3(x, fl + 2.1, d * 0.5 + 0.04)), Vector3(0.9, 0.9, 0.06))
	mb.add_box_unit_uv(door, _xf(Vector3(0, fl + 1.1, d * 0.5 + 0.04)), Vector3(1.3, 2.2, 0.06))
	# roof
	mb.add_gable_roof(roof, _xf(Vector3(0, top + 0.1, 0), PI * 0.5), d, w, 3.0, 0.6, 0.5, Color.WHITE, plaster)
	# chimney
	mb.add_box(stone, _xf(Vector3(-w * 0.32, top + 2.1, -d * 0.2)), Vector3(0.9, 3.0, 0.9), 0.6, Color.WHITE, true, false)
	# outdoor bar: counter + awning posts + sloped awning (on the ground)
	var cz := d * 0.5 + 2.4
	mb.add_box(wood, _xf(Vector3(1.5, 0.55, cz)), Vector3(4.2, 1.1, 0.6), 1.0, Color.WHITE, true, false)
	mb.add_box(beam, _xf(Vector3(1.5, 1.12, cz)), Vector3(4.4, 0.08, 0.75), 1.0, Color.WHITE, true, false)
	for x in [-1.0, 4.0]:
		mb.add_box(beam, _xf(Vector3(x, 1.4, cz + 0.6)), Vector3(0.14, 2.8, 0.14), 0.8)
	var ay0 := 3.3
	var ay1 := 2.8
	mb.add_quad(awning, Vector3(-1.3, ay0, d * 0.5 + 0.1), Vector3(4.3, ay0, d * 0.5 + 0.1),
		Vector3(4.3, ay1, cz + 0.8), Vector3(-1.3, ay1, cz + 0.8),
		Vector2(0, 0), Vector2(2.8, 0), Vector2(2.8, 1.4), Vector2(0, 1.4), Color.WHITE, Vector3(0, 0.95, 0.3).normalized())
	mb.add_quad(awning, Vector3(-1.3, ay0, d * 0.5 + 0.1), Vector3(-1.3, ay1, cz + 0.8),
		Vector3(4.3, ay1, cz + 0.8), Vector3(4.3, ay0, d * 0.5 + 0.1),
		Vector2(0, 0), Vector2(0, 1.4), Vector2(2.8, 1.4), Vector2(2.8, 0), Color(0.7, 0.7, 0.7), Vector3(0, -0.95, -0.3).normalized())
	# hanging sign
	mb.add_box(beam, _xf(Vector3(-w * 0.5 + 0.8, 3.6, d * 0.5 + 0.7)), Vector3(0.08, 0.08, 1.4), 1.0)
	mb.add_box_unit_uv(sign_m, _xf(Vector3(-w * 0.5 + 0.8, 3.1, d * 0.5 + 1.2), PI * 0.5), Vector3(1.2, 0.6, 0.06))
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(w + 0.4, top + 1.7, d + 0.4), Vector3(0, (top + 1.7) * 0.5 - 1.7, 0))
	_add_box_col(body, Vector3(4.2, 1.2, 0.6), Vector3(1.5, 0.6, cz))
	return body


## Market stall with striped cloth awning. Customer side faces +Z.
static func market_stall(cloth: String = "cloth_red", goods: Color = Color(0.85, 0.55, 0.2)) -> Node3D:
	var body := _body("MarketStall")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var post := PSXMat.lit("planks_dark")
	var aw := PSXMat.lit(cloth, Color.WHITE, {"affine": 0.6})
	var g := PSXMat.flat(goods)
	var g2 := PSXMat.flat(goods.lightened(0.25))
	mb.add_box(wood, _xf(Vector3(0, 0.5, 0.4)), Vector3(2.8, 1.0, 0.7), 1.0, Color.WHITE, true, false)
	for x in [-1.35, 1.35]:
		mb.add_box(post, _xf(Vector3(x, 1.2, 0.8)), Vector3(0.12, 2.4, 0.12), 0.8)
		mb.add_box(post, _xf(Vector3(x, 1.4, -0.8)), Vector3(0.12, 2.8, 0.12), 0.8)
	mb.add_quad(aw, Vector3(-1.5, 2.85, -0.9), Vector3(1.5, 2.85, -0.9), Vector3(1.5, 2.35, 1.1), Vector3(-1.5, 2.35, 1.1),
		Vector2(0, 0), Vector2(1.5, 0), Vector2(1.5, 1), Vector2(0, 1), Color.WHITE, Vector3(0, 1, 0.25).normalized())
	mb.add_quad(aw, Vector3(-1.5, 2.85, -0.9), Vector3(-1.5, 2.35, 1.1), Vector3(1.5, 2.35, 1.1), Vector3(1.5, 2.85, -0.9),
		Vector2(0, 0), Vector2(0, 1), Vector2(1.5, 1), Vector2(1.5, 0), Color(0.7, 0.7, 0.7), Vector3(0, -1, -0.25).normalized())
	# goods on the counter
	var rng := RandomNumberGenerator.new()
	rng.seed = int(goods.r * 1000)
	for i in range(9):
		var p := Vector3(-1.1 + (i % 5) * 0.55, 1.08, 0.25 + (i / 5) * 0.3)
		mb.add_box(g if i % 2 == 0 else g2, _xf(p, rng.randf()), Vector3(0.22, 0.16, 0.22), 1.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(2.8, 1.0, 0.7), Vector3(0, 0.5, 0.4))
	return body


static func well() -> Node3D:
	var body := _body("Well")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick")
	var wood := PSXMat.lit("planks_dark")
	var roof := PSXMat.lit("roof_tiles")
	var water := PSXMat.lit("water", Color(0.6, 0.7, 0.8))
	mb.add_cylinder(stone, Transform3D.IDENTITY, 1.1, 1.1, 0.9, 8, 0.6, Color.WHITE, false)
	mb.add_cylinder(stone, Transform3D.IDENTITY, 0.85, 0.85, 0.9, 8, 0.6, Color.WHITE, false)  # inner (back faces handled by cull)
	mb.add_cylinder(water, _xf(Vector3(0, 0.0, 0)), 0.85, 0.85, 0.4, 8, 0.6, Color.WHITE, true)
	for x in [-0.95, 0.95]:
		mb.add_box(wood, _xf(Vector3(x, 1.2, 0)), Vector3(0.14, 1.6, 0.14), 0.8)
	mb.add_box(wood, _xf(Vector3(0, 1.75, 0)), Vector3(2.1, 0.12, 0.12), 0.8)
	mb.add_gable_roof(roof, _xf(Vector3(0, 2.0, 0)), 1.6, 2.1, 0.7, 0.15, 0.6)
	# bucket
	mb.add_cylinder(wood, _xf(Vector3(0.3, 1.0, 0)), 0.14, 0.17, 0.25, 6, 1.0)
	body.add_child(mb.to_instance())
	_add_cyl_col(body, 1.1, 0.9, Vector3.ZERO)
	return body


## Lighthouse on a stone base. Lantern room glows and a lamp lens rotates.
static func lighthouse() -> Node3D:
	var body := _body("Lighthouse")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick")
	var white := PSXMat.lit("plaster", Color(1.0, 1.0, 0.98))
	var red := PSXMat.lit("plaster", Color(0.75, 0.2, 0.15))
	var dark := PSXMat.flat(Color(0.12, 0.12, 0.14))
	var glass := PSXMat.glow(Color(1.0, 0.9, 0.55), 1.6)
	var roof := PSXMat.lit("roof_tiles", Color(0.8, 0.3, 0.25))
	mb.add_cylinder(stone, _xf(Vector3(0, -1.5, 0)), 3.2, 3.0, 3.6, 8, 0.5, Color.WHITE, true)
	var y := 2.1
	var r := 2.3
	var band_h := 2.4
	for i in range(5):
		var r2 := r - 0.16
		mb.add_cylinder(red if i % 2 == 1 else white, _xf(Vector3(0, y, 0)), r, r2, band_h, 8, 0.4, Color.WHITE, false, false, false)
		y += band_h
		r = r2
	# door
	var door := PSXMat.lit("door", Color.WHITE, {"vertex_color": false})
	mb.add_box_unit_uv(door, _xf(Vector3(0, 3.1, 2.25)), Vector3(1.0, 2.0, 0.1))
	# gallery
	mb.add_cylinder(dark, _xf(Vector3(0, y, 0)), 2.2, 2.2, 0.25, 8, 0.6, Color.WHITE, true, true)
	for i in range(16):
		var a := TAU * i / 16.0
		mb.add_box(dark, _xf(Vector3(cos(a) * 2.1, y + 0.6, sin(a) * 2.1)), Vector3(0.06, 0.9, 0.06), 1.0)
	mb.add_cylinder(dark, _xf(Vector3(0, y + 1.0, 0)), 2.15, 2.15, 0.08, 16, 0.6, Color.WHITE, false, false)
	# lantern room
	mb.add_cylinder(glass, _xf(Vector3(0, y + 0.25, 0)), 1.2, 1.2, 1.8, 8, 0.6, Color.WHITE, false, false, false)
	mb.add_cone(roof, _xf(Vector3(0, y + 2.05, 0)), 1.5, 1.3, 8, 0.6)
	mb.add_cylinder(dark, _xf(Vector3(0, y + 3.3, 0)), 0.08, 0.04, 0.6, 4, 1.0)
	body.add_child(mb.to_instance())
	_add_cyl_col(body, 2.4, y + 3.0, Vector3(0, 0, 0))
	# rotating lamp
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(0, y + 1.1, 0)
	lamp.set_script(load("res://scripts/props/spinner.gd"))
	lamp.set("speed", 0.9)
	var lmb := MeshBuilder.new()
	var lens := PSXMat.glow(Color(1.0, 0.95, 0.7), 6.0)
	lmb.add_box(lens, Transform3D.IDENTITY, Vector3(0.5, 0.5, 2.0), 1.0, Color.WHITE, false)
	lamp.add_child(lmb.to_instance())
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.92, 0.7)
	spot.light_energy = 6.0
	spot.spot_range = 120.0
	spot.spot_angle = 9.0
	spot.rotation.x = deg_to_rad(-6)
	lamp.add_child(spot)
	body.add_child(lamp)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, y + 1.1, 0)
	omni.light_color = Color(1.0, 0.85, 0.55)
	omni.light_energy = 1.5
	omni.omni_range = 10.0
	body.add_child(omni)
	return body


## Plank dock running from local origin along +Z for `length` meters.
## Deck top sits at `deck_y` (local). Posts reach down to `floor_y`.
static func dock(length: float, width: float = 3.6, deck_y: float = 1.7, floor_y: float = -8.0) -> Node3D:
	var body := _body("Dock")
	var mb := MeshBuilder.new()
	var deck := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.5})
	var post := PSXMat.lit("planks_dark")
	var rope := PSXMat.lit("rope")
	# deck planks run across the dock: rotate texture by building as boxes along X
	var seg := 4.0
	var n := int(ceil(length / seg))
	for i in range(n):
		var z0 := i * seg
		var L := minf(seg, length - z0)
		mb.add_box(deck, _xf(Vector3(0, deck_y - 0.12, z0 + L * 0.5), PI * 0.5), Vector3(L, 0.24, width), 0.5, Color.WHITE, false, false)
	# stringers
	for x in [-width * 0.5 + 0.1, width * 0.5 - 0.1]:
		mb.add_box(post, _xf(Vector3(x, deck_y - 0.35, length * 0.5)), Vector3(0.16, 0.22, length), 0.6)
	# posts
	var post_h := deck_y + 0.6 - floor_y
	var z := 0.0
	while z <= length + 0.01:
		for x in [-width * 0.5, width * 0.5]:
			mb.add_cylinder(post, _xf(Vector3(x, floor_y, z)), 0.16, 0.16, post_h, 6, 0.6, Color.WHITE, true)
		z += seg
	# bollards + rope rails near the end
	for x in [-width * 0.5 + 0.3, width * 0.5 - 0.3]:
		mb.add_cylinder(post, _xf(Vector3(x, deck_y, length - 1.0)), 0.18, 0.2, 0.5, 6, 1.0)
		mb.add_cylinder(rope, _xf(Vector3(x, deck_y + 0.25, length - 1.0)), 0.22, 0.22, 0.12, 6, 2.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(width, 0.3, length), Vector3(0, deck_y - 0.15, length * 0.5))
	return body


# --------------------------------------------------------------------------
# Ruins + Driftstone
# --------------------------------------------------------------------------
static func ruin_pillar(height: float, broken: bool, seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := _body("Pillar")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.85, 0.9, 0.85))
	var moss := PSXMat.lit("leaves", Color(0.8, 0.9, 0.7))
	mb.add_box(stone, _xf(Vector3(0, 0.2, 0)), Vector3(1.2, 0.4, 1.2), 0.6, Color.WHITE, true, false)
	mb.add_cylinder(stone, _xf(Vector3(0, 0.4, 0)), 0.45, 0.4, height, 8, 0.6, Color.WHITE, not broken)
	if broken:
		# jagged top
		for i in range(3):
			var a := TAU * i / 3.0 + rng.randf()
			mb.add_box(stone, _xf(Vector3(cos(a) * 0.2, 0.4 + height + 0.15, sin(a) * 0.2), a), Vector3(0.3, 0.3 + rng.randf() * 0.3, 0.3), 0.6)
	else:
		mb.add_box(stone, _xf(Vector3(0, 0.4 + height + 0.15, 0)), Vector3(1.1, 0.3, 1.1), 0.6, Color.WHITE, true, false)
	# moss clump
	mb.add_blob(moss, _xf(Vector3(0.3, 0.45, 0.2)), Vector3(0.4, 0.2, 0.35), rng, 0.2, 2, 5, 1.0)
	body.add_child(mb.to_instance())
	_add_cyl_col(body, 0.5, height + 0.5, Vector3.ZERO)
	return body


static func fallen_pillar(length: float) -> Node3D:
	var body := _body("FallenPillar")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.85, 0.9, 0.85))
	mb.add_cylinder(stone, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(length * 0.5, 0.4, 0)), 0.42, 0.4, length, 8, 0.6, Color.WHITE, true, true)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(length, 0.8, 0.8), Vector3(0, 0.4, 0))
	return body


static func driftstone() -> Node3D:
	var body := _body("Driftstone")
	var mb := MeshBuilder.new()
	var base := PSXMat.lit("stone_brick", Color(0.6, 0.65, 0.65))
	var mono := PSXMat.lit("driftstone", Color.WHITE, {
		"vertex_color": false, "emission_tex": "driftstone_glow",
		"emission": Color(0.3, 0.95, 0.9), "emission_energy": 2.2, "emission_pulse": 0.35, "affine": 0.4})
	mb.add_box(base, _xf(Vector3(0, 0.25, 0)), Vector3(2.4, 0.5, 1.6), 0.6, Color.WHITE, true, false)
	mb.add_box(base, _xf(Vector3(0, 0.6, 0)), Vector3(1.9, 0.2, 1.1), 0.6, Color.WHITE, true, false)
	# slightly tilted monolith, glyph faces front and back
	var b := Basis(Vector3.BACK, deg_to_rad(4)) * Basis(Vector3.UP, deg_to_rad(-6))
	var xf := Transform3D(b, Vector3(0, 0.7 + 1.6, 0))
	mb.add_box_unit_uv(mono, xf, Vector3(1.3, 3.2, 0.45))
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(1.4, 3.9, 0.6), Vector3(0, 1.95, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 1.0, 0.9)
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position = Vector3(0, 2.2, 0.8)
	body.add_child(light)
	return body


# --------------------------------------------------------------------------
# Training dummy (visual only — combat logic lives in dummy_target.gd)
# --------------------------------------------------------------------------
static func straw_dummy_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var straw := PSXMat.lit("straw")
	var wood := PSXMat.lit("planks_dark")
	var sack := PSXMat.lit("canvas", Color(0.85, 0.8, 0.65))
	mb.add_cylinder(wood, Transform3D.IDENTITY, 0.07, 0.07, 1.9, 5, 1.0)
	mb.add_cylinder(straw, _xf(Vector3(0, 0.75, 0)), 0.32, 0.28, 0.8, 7, 1.5, Color.WHITE, true, true)
	mb.add_box(wood, _xf(Vector3(0, 1.35, 0)), Vector3(1.3, 0.1, 0.1), 1.0)
	mb.add_cylinder(straw, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.62, 1.35, 0)), 0.12, 0.12, 1.24, 5, 1.5, Color.WHITE, true, true)
	mb.add_blob(sack, _xf(Vector3(0, 1.72, 0)), Vector3(0.22, 0.25, 0.22), RandomNumberGenerator.new(), 0.1, 3, 6, 1.5)
	return mb.commit()


static func weapon_rack() -> Node3D:
	var body := _body("WeaponRack")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var steel := PSXMat.lit("metal")
	for x in [-0.9, 0.9]:
		mb.add_box(wood, _xf(Vector3(x, 0.7, 0)), Vector3(0.1, 1.4, 0.3), 1.0)
	mb.add_box(wood, _xf(Vector3(0, 1.2, 0)), Vector3(1.9, 0.08, 0.08), 1.0)
	mb.add_box(wood, _xf(Vector3(0, 0.3, 0)), Vector3(1.9, 0.08, 0.3), 1.0)
	for i in range(4):
		var x := -0.6 + i * 0.4
		mb.add_box(steel, _xf(Vector3(x, 0.85, 0.05), 0.0), Vector3(0.05, 1.1, 0.02), 1.0)
		mb.add_box(wood, _xf(Vector3(x, 1.38, 0.05)), Vector3(0.18, 0.04, 0.04), 1.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(1.9, 1.4, 0.3), Vector3(0, 0.7, 0))
	return body


static func upturned_boat() -> Node3D:
	var body := _body("UpturnedBoat")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_weathered")
	mb.add_gable_roof(wood, _xf(Vector3(0, 0.0, 0)), 1.3, 3.4, 0.7, 0.0, 1.0, Color.WHITE, wood)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(1.3, 0.7, 3.4), Vector3(0, 0.35, 0))
	return body


static func net_pile() -> Node3D:
	var n := Node3D.new()
	n.name = "Nets"
	var mb := MeshBuilder.new()
	var rope := PSXMat.lit("rope", Color(0.8, 0.85, 0.75))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	mb.add_blob(rope, _xf(Vector3(0, 0.1, 0)), Vector3(0.8, 0.25, 0.6), rng, 0.25, 3, 6, 2.0, Color.WHITE, -0.4)
	n.add_child(mb.to_instance())
	return n


static func signpost(arrows: Array) -> Node3D:
	## arrows: Array of yaw angles (radians) for each board
	var body := _body("Signpost")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var board := PSXMat.lit("planks")
	mb.add_box(wood, _xf(Vector3(0, 1.2, 0)), Vector3(0.14, 2.4, 0.14), 1.0)
	for i in range(arrows.size()):
		var a: float = arrows[i]
		var b := Basis(Vector3.UP, a)
		mb.add_box(board, Transform3D(b, Vector3(0, 2.1 - i * 0.35, 0) + b * Vector3(0.55, 0, 0)), Vector3(1.0, 0.26, 0.06), 1.0)
		mb.add_box(board, Transform3D(b * Basis(Vector3.BACK, PI * 0.25), Vector3(0, 2.1 - i * 0.35, 0) + b * Vector3(1.07, 0, 0)), Vector3(0.18, 0.18, 0.06), 1.0)
	body.add_child(mb.to_instance())
	_add_box_col(body, Vector3(0.2, 2.4, 0.2), Vector3(0, 1.2, 0))
	return body


# --------------------------------------------------------------------------
# Hand-held items (grip at the origin, business end along -Z)
# --------------------------------------------------------------------------
## Built once per model and shared (a grunt drawing his pistol mid-fight, a
## dropped blade): instances recolour them with overrides, never the mesh.
static var _weapons: Dictionary = {}


static func weapon_mesh(kind: String) -> ArrayMesh:
	if not _weapons.has(kind):
		_weapons[kind] = _build_weapon(kind)
	return _weapons[kind]


static func _build_weapon(kind: String) -> ArrayMesh:
	# cutlasses, katanas, axes and pistols in all their designs and tiers
	if kind.get_slice(":", 0) in WeaponDesigns.BASE_ITEM:
		return WeaponDesigns.build(kind)
	# the riflemen's long musket: grip at the origin, barrel 1.1 m forward,
	# stock back to the shoulder
	var mb := MeshBuilder.new()
	var steel := PSXMat.lit("metal")
	var brass := PSXMat.lit("metal", Color(1.0, 0.78, 0.4))
	var wood := PSXMat.lit("planks", Color(0.7, 0.45, 0.26))
	mb.add_cylinder(steel, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.06, -0.2)), 0.024, 0.022, 1.15, 6, 2.0)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.035, -0.45)), Vector3(0.06, 0.06, 0.75), 2.0)
	mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, -0.01, 0.22)), Vector3(0.06, 0.11, 0.5), 2.0)
	mb.add_box(brass, Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, -0.06, 0.47)), Vector3(0.065, 0.13, 0.04), 2.0)
	mb.add_box(brass, Transform3D(Basis(), Vector3(0, 0.06, -0.62)), Vector3(0.05, 0.05, 0.03), 2.0)
	mb.add_box(steel, Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.1, 0.0)), Vector3(0.02, 0.05, 0.02), 2.0)
	var m := mb.commit()
	m.set_meta("model", kind)  # co-op: other players rebuild the same weapon by name
	return m


## A Devil Fruit held in the hand: a swirled round fruit with a curled stem
## and a leaf.
static func devil_fruit_mesh(skin: String = "devil_fruit_ember") -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var r := 0.085
	mb.add_blob(PSXMat.lit(skin), Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.06)), Vector3(r, r * 0.95, r), rng, 0.06, 5, 8, 1.0 / (TAU * r))
	mb.add_cylinder(PSXMat.flat(Color(0.35, 0.22, 0.1)), Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(0, r * 0.9, -0.06)), 0.01, 0.006, 0.05, 4, 1.0)
	mb.add_card(PSXMat.flat(Color(0.3, 0.6, 0.2)), Transform3D(Basis(Vector3.FORWARD, -1.0), Vector3(0.03, r + 0.02, -0.06)), 0.05, 0.035)
	var m := mb.commit()
	m.set_meta("model", skin)
	return m


## A tied canvas sack (dropped items).
static func sack_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var canvas := PSXMat.lit("canvas", Color(0.85, 0.75, 0.55))
	var rope := PSXMat.lit("planks", Color(0.6, 0.45, 0.25))
	mb.add_blob(canvas, Transform3D(Basis.IDENTITY, Vector3(0, 0.17, 0)), Vector3(0.2, 0.17, 0.18), rng, 0.12, 5, 8, 2.0)
	mb.add_cylinder(canvas, Transform3D(Basis.IDENTITY, Vector3(0, 0.33, 0)), 0.07, 0.04, 0.09, 6, 1.0)
	mb.add_cylinder(rope, Transform3D(Basis.IDENTITY, Vector3(0, 0.33, 0)), 0.075, 0.075, 0.025, 6, 1.0)
	var m := mb.commit()
	m.set_meta("model", "sack")
	return m


static func bottle_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var glass := PSXMat.lit("", Color(0.35, 0.22, 0.1), {"emission": Color(0.25, 0.12, 0.04), "emission_energy": 0.4})
	var cork := PSXMat.flat(Color(0.7, 0.55, 0.35))
	var b := Basis(Vector3.RIGHT, -PI * 0.5)  # bottle axis along -Z
	mb.add_cylinder(glass, Transform3D(b, Vector3(0, 0, 0.08)), 0.06, 0.06, 0.18, 6, 2.0)
	mb.add_cylinder(glass, Transform3D(b, Vector3(0, 0, -0.1)), 0.06, 0.025, 0.06, 6, 2.0)
	mb.add_cylinder(cork, Transform3D(b, Vector3(0, 0, -0.16)), 0.025, 0.025, 0.05, 5, 2.0)
	var m := mb.commit()
	m.set_meta("model", "bottle")
	return m
