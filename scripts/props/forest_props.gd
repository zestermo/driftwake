class_name ForestProps
extends RefCounted
## The forest islands' props (ForestTheme.props through KitStyle): the lumber town's lantern post and
## waymark. Origins on the ground; one merged mesh and a box collider each.


static func _xf(at: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at)


## A lantern post: a squared timber post, a bracket out to an iron lantern under a little shingle hood.
static func lamp_post(height: float) -> Node3D:
	var body := Props._body("ForestLamp")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var iron := PSXMat.lit("metal", Color(0.22, 0.2, 0.2))
	mb.add_box(PSXMat.lit("forest_rock", Color.WHITE, {"affine": 0.6}), _xf(Vector3(0, 0.15, 0)), Vector3(0.5, 0.3, 0.5), 1.0)
	mb.add_box(wood, _xf(Vector3(0, height * 0.5, 0)), Vector3(0.16, height, 0.16), 1.0)
	mb.add_box(wood, _xf(Vector3(0.28, height - 0.15, 0)), Vector3(0.62, 0.1, 0.1), 1.0)
	mb.add_box(wood, Transform3D(Basis(Vector3.BACK, -0.75), Vector3(0.14, height - 0.36, 0)), Vector3(0.06, 0.4, 0.06), 1.0)
	var at := Vector3(0.52, height - 0.62, 0)
	mb.add_cylinder(iron, _xf(at + Vector3(0, 0.36, 0)), 0.015, 0.015, 0.16, 4, 1.0)
	mb.add_box(iron, _xf(at), Vector3(0.24, 0.04, 0.24), 1.0, Color.WHITE, false)
	mb.add_box(PSXMat.glow(Color(1.0, 0.7, 0.36), 2.2), _xf(at + Vector3(0, 0.17, 0)), Vector3(0.17, 0.28, 0.17), 1.0)
	for k in range(4):
		var a := TAU * k / 4.0 + PI / 4.0
		mb.add_box(iron, _xf(at + Vector3(cos(a) * 0.12, 0.17, sin(a) * 0.12)), Vector3(0.03, 0.32, 0.03), 1.0)
	mb.add_gable_roof(PSXMat.lit("shingles"), _xf(at + Vector3(0, 0.34, 0)), 0.3, 0.3, 0.16, 0.06, 1.0)
	body.add_child(mb.to_instance())
	var m := Marker3D.new()
	m.name = "Flame"
	m.position = at + Vector3(0, 0.17, 0)
	body.add_child(m)
	Props._add_box_col(body, Vector3(0.3, height, 0.3), Vector3(0, height * 0.5, 0))
	return body


## A waymark: a weathered post with arrow boards pointing off, an owl carved on its top, a shingle cap.
static func waymark(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Waymark")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_weathered")
	var dark := PSXMat.lit("planks_dark")
	var h := rng.randf_range(2.0, 2.4)
	mb.add_cylinder(dark, _xf(Vector3(0, -0.1, 0)), 0.12, 0.1, h + 0.1, 6, 1.0)
	for k in range(rng.randi_range(2, 3)):
		var yaw := rng.randf() * TAU
		var y := h - 0.35 - k * 0.32
		var b := Basis(Vector3.UP, yaw)
		mb.add_box(wood, Transform3D(b, Vector3(0, y, 0) + b * Vector3(0.38, 0, 0)), Vector3(0.62, 0.18, 0.04), 1.0, Color.WHITE.darkened(rng.randf() * 0.2))
		mb.add_tri(wood, Vector3(0, y + 0.13, 0) + b * Vector3(0.69, 0, 0.0), Vector3(0, y - 0.13, 0) + b * Vector3(0.69, 0, 0.0), Vector3(0, y, 0) + b * Vector3(0.86, 0, 0),
			b * Vector3.BACK, b * Vector3.BACK, b * Vector3.BACK, Vector2(0, 0), Vector2(0, 1), Vector2(1, 0.5), Color.WHITE, b * Vector3.BACK)
	var owl := PSXMat.lit("bark", Color(0.85, 0.75, 0.62))
	mb.add_blob(owl, _xf(Vector3(0, h + 0.18, 0)), Vector3(0.13, 0.2, 0.12), rng, 0.08, 3, 6, 1.0)
	mb.add_blob(owl, _xf(Vector3(0, h + 0.42, 0.01)), Vector3(0.11, 0.1, 0.1), rng, 0.05, 3, 6, 1.0)
	var eye := PSXMat.flat(Color(0.95, 0.75, 0.2))
	for s in [-1.0, 1.0]:
		mb.add_box(eye, _xf(Vector3(0.045 * s, h + 0.44, 0.1)), Vector3(0.04, 0.04, 0.02), 1.0)
		mb.add_cone(owl, _xf(Vector3(0.07 * s, h + 0.5, 0)), 0.03, 0.08, 4)
	mb.add_gable_roof(PSXMat.lit("shingles"), _xf(Vector3(0, h + 0.58, 0)), 0.36, 0.36, 0.18, 0.06, 1.0)
	body.add_child(mb.to_instance())
	Props._add_box_col(body, Vector3(0.3, h, 0.3), Vector3(0, h * 0.5, 0))
	return body
