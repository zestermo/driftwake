class_name SnowProps
extends RefCounted
## The snow islands' props (SnowTheme.props, through KitStyle.prop): an iron lamp post with a
## snow-capped lantern, and a waymark cairn of black stones with a pole and a red rag.


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


## An iron post, a scrolled arm, a four-paned lantern under a little snow-capped roof.
static func lamp_post(height: float) -> Node3D:
	var body := Props._body("SnowLamp")
	var mb := MeshBuilder.new()
	var iron := PSXMat.lit("metal", Color(0.2, 0.2, 0.23))
	var snow := PSXMat.lit("snow", Color.WHITE, {"affine": 0.5})
	mb.add_cylinder(iron, _xf(Vector3.ZERO), 0.14, 0.11, 0.35, 6, 1.0, Color.WHITE, true)
	mb.add_cylinder(iron, _xf(Vector3(0, 0.35, 0)), 0.055, 0.045, height - 0.35, 6, 1.0)
	mb.add_tube(iron, MeshBuilder.curve_points(Vector3(0, height - 0.5, 0), Vector3(0.05, height - 0.05, 0), Vector3(0.45, height - 0.1, 0), 6), 0.03, 0.025, 4, 1.0)
	var at := Vector3(0.45, height - 0.62, 0)
	mb.add_box(iron, _xf(at + Vector3(0, 0.02, 0)), Vector3(0.3, 0.04, 0.3), 1.0, Color.WHITE, false)
	mb.add_box(PSXMat.glow(Color(1.0, 0.76, 0.4), 2.2), _xf(at + Vector3(0, 0.22, 0)), Vector3(0.22, 0.36, 0.22), 1.0)
	for k in range(4):
		var a := TAU * k / 4.0 + PI / 4.0
		mb.add_box(iron, _xf(at + Vector3(cos(a) * 0.15, 0.22, sin(a) * 0.15)), Vector3(0.035, 0.4, 0.035), 1.0)
	mb.add_pyramid_roof(iron, _xf(at + Vector3(0, 0.42, 0)), 0.3, 0.3, 0.22, 0.04, 1.0)
	mb.add_cylinder(snow, _xf(at + Vector3(0, 0.48, 0)), 0.17, 0.04, 0.12, 6, 0.6)
	mb.add_cylinder(iron, _xf(at + Vector3(0, 0.6, 0)), 0.03, 0.03, 0.12, 4, 1.0)
	mb.add_cylinder(snow, _xf(Vector3(0, -0.02, 0)), 0.32, 0.18, 0.12, 6, 0.6)
	body.add_child(mb.to_instance())
	var m := Marker3D.new()
	m.name = "Flame"
	m.position = at + Vector3(0, 0.22, 0)
	body.add_child(m)
	Props._add_box_col(body, Vector3(0.24, height, 0.24), Vector3(0, height * 0.5, 0))
	return body


## A cairn of black stones, snow on them, a pole wedged in its top with a red rag for a flag.
static func waymark(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Waymark")
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("black_rock", Color.WHITE, {"affine": 0.6})
	var snow := PSXMat.lit("snow", Color.WHITE, {"affine": 0.5})
	var y := 0.0
	var r := 0.55
	for k in range(4):
		var s := Vector3(r * rng.randf_range(0.9, 1.1), r * 0.55, r * rng.randf_range(0.85, 1.05))
		mb.add_blob(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.05, 0.05), y + s.y * 0.8, rng.randf_range(-0.05, 0.05))), s, rng, 0.2, 3, 6, 1.0, Color.WHITE.darkened(rng.randf() * 0.15), -0.6)
		mb.add_blob(snow, Transform3D(Basis(), Vector3(0, y + s.y * 1.55, 0)), Vector3(s.x * 0.6, s.y * 0.25, s.z * 0.55), rng, 0.15, 2, 6, 0.6)
		y += s.y * 1.3
		r *= 0.78
	var wood := PSXMat.lit("planks_dark")
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, 0.06), Vector3(0, y - 0.3, 0)), 0.04, 0.035, 1.6, 5, 1.0)
	var top := Vector3(-0.07, y + 1.2, 0)
	var rag := PSXMat.lit("cloth_red")
	mb.add_quad(rag, top, top + Vector3(0.05, -0.32, 0), top + Vector3(0.62, -0.38, 0.12), top + Vector3(0.55, -0.04, 0.1), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color.WHITE, Vector3.BACK)
	mb.add_quad(rag, top + Vector3(0.55, -0.04, 0.1), top + Vector3(0.62, -0.38, 0.12), top + Vector3(0.05, -0.32, 0), top, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0), Color(0.7, 0.7, 0.7), Vector3.FORWARD)
	body.add_child(mb.to_instance())
	Props._add_box_col(body, Vector3(1.0, y, 1.0), Vector3(0, y * 0.5, 0))
	return body
