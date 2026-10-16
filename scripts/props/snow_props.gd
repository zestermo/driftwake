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


## A round house of pink brick under a tall cone of green tiers, snow lying on every step, a
## brick finial with a pointed clay cap on top (and smoke from it), a door at +Z under a little
## hood, small lit windows round the wall, a black-stone footing down into the ground and snow
## banked against the wall. `diameter` across the wall, `storeys` 1 or 2; origin on the ground.
static func round_house(seed_value: int, diameter: float, storeys := 1) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("RoundHouse")
	var mb := MeshBuilder.new()
	var brick := PSXMat.lit("brick_pink")
	var roof := PSXMat.lit("roof_green", Color.WHITE, {"affine": 0.7})
	var snow := PSXMat.lit("snow", Color.WHITE, {"affine": 0.5})
	var stone := PSXMat.lit("black_rock", Color.WHITE, {"affine": 0.6})
	var wood := PSXMat.lit("planks_dark")
	var clay := PSXMat.lit("roof_tiles", Color(0.95, 0.62, 0.4))
	var window := PSXMat.lit("window", Color(0.85, 0.9, 1.0), {"emission": Color(1.0, 0.74, 0.38), "emission_energy": 0.8, "emission_tex": "window"})
	var R := diameter * 0.5
	var H := rng.randf_range(2.6, 3.1) + (storeys - 1) * 2.4
	var sides := 12
	var turn := Basis(Vector3.UP, -PI / sides)
	var apothem := R * cos(PI / sides)
	mb.add_cylinder(stone, Transform3D(turn, Vector3.DOWN * 1.2), R + 0.18, R + 0.12, 1.45, sides, 0.6, Color(0.9, 0.9, 0.9), true)
	mb.add_cylinder(brick, Transform3D(turn, Vector3.UP * 0.25), R, R, H - 0.25, sides, 0.5, Color.WHITE, false, false, false)
	mb.add_cylinder(wood, Transform3D(turn, Vector3.UP * (H - 0.18)), R + 0.06, R + 0.06, 0.22, sides, 1.0, Color(0.8, 0.8, 0.8), false, false, false)
	# the roof: tiers stepping in up a tall cone, snow on each step
	var tiers := rng.randi_range(4, 6)
	var rh := R * rng.randf_range(1.8, 2.5)
	var eave := R + rng.randf_range(0.45, 0.65)
	var th := rh / tiers
	var y := H - 0.1
	for i in range(tiers):
		var r0 := eave * (1.0 - float(i) / tiers * 0.86)
		var r1 := eave * (1.0 - float(i + 1) / tiers * 0.86)
		var top := r0 * 0.84 if i < tiers - 1 else r1 * 0.5
		mb.add_cylinder(roof, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3.UP * y), r0, top, th, 14, 0.7, Color.WHITE.darkened(0.12 * (1.0 - float(i) / tiers)), false, i == 0, false)
		var lip := Transform3D(Basis(), Vector3.UP * (y + th - 0.04))
		if i < tiers - 1:
			mb.add_cylinder(snow, lip, top + 0.08, r1 * 0.9, 0.16, 14, 0.6, Color.WHITE, false, false, false)
			mb.add_cylinder(snow, Transform3D(Basis(), Vector3.UP * (y + th - 0.14)), top + 0.1, top + 0.08, 0.12, 14, 0.6, Color(0.9, 0.92, 0.96), false, false, false)
		y += th
	var peak := y
	mb.add_cylinder(snow, Transform3D(Basis(), Vector3.UP * (peak - 0.12)), eave * 0.2, 0.18, 0.3, 10, 0.6)
	# the finial: a brick chimney with a pointed clay cap
	mb.add_cylinder(brick, Transform3D(turn, Vector3.UP * (peak - 0.3)), 0.28, 0.24, 0.85, 8, 1.0, Color.WHITE, true)
	mb.add_cylinder(clay, Transform3D(Basis(), Vector3.UP * (peak + 0.5)), 0.36, 0.0, 0.75, 8, 1.0, Color.WHITE, false, true, false)
	mb.add_cylinder(clay, Transform3D(Basis(), Vector3.UP * (peak + 1.2)), 0.06, 0.02, 0.25, 5, 1.0)
	FX.chimney_smoke(body, Vector3(0, peak + 1.3, 0))
	# the door and its hood, facing +Z on a flat of the wall
	var dz := apothem + 0.02
	mb.add_box_unit_uv(PSXMat.lit("door", Color(0.85, 0.75, 0.65), {"vertex_color": false}), Transform3D(Basis(), Vector3(0, 0.25 + 1.0, dz)), Vector3(1.0, 2.0, 0.08))
	for s in [-1.0, 1.0]:
		mb.add_box(wood, Transform3D(Basis(), Vector3(s * 0.58, 0.25 + 1.05, dz + 0.04)), Vector3(0.14, 2.15, 0.1), 1.0)
		mb.add_box(wood, Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(s * 0.62, 2.55, dz + 0.3)), Vector3(0.1, 0.1, 0.8), 1.0, Color.WHITE, false)
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.25 + 2.15, dz + 0.05)), Vector3(1.36, 0.16, 0.12), 1.0)
	mb.add_gable_roof(roof, Transform3D(Basis(), Vector3(0, 2.62, dz + 0.45)), 1.6, 1.0, 0.55, 0.15, 0.7, Color.WHITE, wood)
	mb.add_box(snow, Transform3D(Basis(), Vector3(0, 3.12, dz + 0.45)), Vector3(0.3, 0.12, 1.3), 0.6)
	mb.add_box(stone, Transform3D(Basis(), Vector3(0, 0.12, dz + 0.55)), Vector3(1.5, 0.24, 0.9), 0.6, Color(0.85, 0.85, 0.85))
	# windows on other flats, a sill and a little snow on each
	var n_win := rng.randi_range(2, 4)
	var used := {}
	for k in range(n_win):
		var face: int = [2, 3, 4, 8, 9, 10][rng.randi() % 6]
		if used.has(face):
			continue
		used[face] = true
		var a := PI / 2.0 + TAU * face / sides
		var b := Basis(Vector3.UP, PI / 2.0 - a)
		var y0 := rng.randf_range(1.45, 1.65)
		for st in range(storeys):
			var c := Vector3(cos(a), 0, sin(a)) * (apothem + 0.03) + Vector3.UP * (y0 + st * 2.4)
			mb.add_box(window, Transform3D(b, c), Vector3(0.62, 0.72, 0.06), 1.0)
			mb.add_box(wood, Transform3D(b, c + b * Vector3(0, -0.42, 0.06)), Vector3(0.82, 0.08, 0.16), 1.0)
			mb.add_box(snow, Transform3D(b, c + b * Vector3(0, -0.35, 0.08)), Vector3(0.7, 0.06, 0.12), 1.0)
			mb.add_box(wood, Transform3D(b, c + b * Vector3(0, 0.42, 0.04)), Vector3(0.78, 0.1, 0.1), 1.0)
	if storeys > 1:
		mb.add_cylinder(wood, Transform3D(turn, Vector3.UP * 2.95), R + 0.05, R + 0.05, 0.16, sides, 1.0, Color(0.75, 0.75, 0.75), false, false, false)
		mb.add_cylinder(snow, Transform3D(turn, Vector3.UP * 3.1), R + 0.08, R + 0.02, 0.06, sides, 0.6, Color.WHITE, false, false, false)
	# snow banked round the foot, deeper on one side
	var drift_a := rng.randf() * TAU
	for k in range(6):
		var a := drift_a + k * 0.5
		if absf(angle_difference(a, PI / 2.0)) < 0.5:
			continue
		var at := Vector3(cos(a), 0, sin(a)) * (R + 0.25)
		mb.add_blob(snow, Transform3D(Basis(Vector3.UP, -a), at), Vector3(0.5, rng.randf_range(0.35, 0.7), 1.1), rng, 0.15, 2, 6, 0.6, Color.WHITE, 0.0)
	var mi := mb.to_instance()
	mi.visibility_range_end = 700.0
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = R + 0.1
	cyl.height = H + 1.2
	cs.shape = cyl
	cs.position = Vector3(0, (H + 1.2) * 0.5 - 1.0, 0)
	body.add_child(cs)
	var cone := CollisionShape3D.new()
	var cc := CylinderShape3D.new()
	cc.radius = eave * 0.55
	cc.height = rh * 0.7
	cone.shape = cc
	cone.position = Vector3(0, H + rh * 0.35, 0)
	body.add_child(cone)
	var door := Marker3D.new()
	door.name = "Door"
	door.position = Vector3(0, 0.25, dz + 0.9)
	body.add_child(door)
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
