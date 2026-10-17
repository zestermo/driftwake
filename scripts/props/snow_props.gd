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


## A wooden fence (the village ref's) `length` along +Z from the origin: dark posts every ~2.2 m with
## snow on their tops, two rails, snow lying along the top rail and drifted against the foot.
static func fence(seed_value: int, length := 4.4) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Fence")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var snow := PSXMat.lit("snow", Color.WHITE, {"affine": 0.5})
	var h := 1.05
	var n := maxi(int(round(length / 2.2)), 1)
	for k in range(n + 1):
		var z := length * k / n
		var ph := h + rng.randf_range(-0.06, 0.08)
		mb.add_box(wood, _xf(Vector3(0, ph * 0.5 - 0.2, z), rng.randf_range(-0.08, 0.08)), Vector3(0.13, ph + 0.4, 0.13), 1.0, Color.WHITE.darkened(rng.randf() * 0.15))
		mb.add_box(snow, _xf(Vector3(0, ph + 0.04, z)), Vector3(0.17, 0.08, 0.17), 1.0, Color.WHITE, false)
	for y in [0.42, 0.86]:
		mb.add_box(wood, _xf(Vector3(0.02, y, length * 0.5)), Vector3(0.06, 0.13, length), 0.8, Color(0.9, 0.88, 0.85), false)
	mb.add_box(snow, _xf(Vector3(0.02, 0.95, length * 0.5)), Vector3(0.1, 0.05, length - 0.1), 0.6, Color.WHITE, false)
	for k in range(n):
		var z := length * (k + 0.5) / n
		mb.add_blob(snow, _xf(Vector3(rng.randf_range(-0.15, 0.15), 0.0, z), rng.randf() * TAU), Vector3(0.45, 0.22, length / n * 0.45), rng, 0.15, 3, 6, 0.6, Color.WHITE, 0.0)
	body.add_child(mb.to_instance("FenceMesh"))
	Props._add_box_col(body, Vector3(0.2, h, length), Vector3(0, h * 0.5, length * 0.5))
	return body


## A wooden tub with a little fir in it, snow on its boughs (the snow's planter); `r` the tub's radius.
static func planter(seed_value: int, r := 0.55) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Planter")
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var iron := PSXMat.lit("metal", Color(0.2, 0.2, 0.23))
	var snow := PSXMat.lit("snow", Color.WHITE, {"affine": 0.5})
	var leaf := PSXMat.lit("pine_snow")
	mb.add_cylinder(wood, _xf(Vector3.ZERO), r * 0.9, r, r * 1.1, 8, 1.0, Color.WHITE, true)
	for y in [0.2, 0.85]:
		mb.add_cylinder(iron, _xf(Vector3(0, r * 1.1 * y, 0)), r * (0.92 + y * 0.08) + 0.01, r * (0.92 + y * 0.08) + 0.01, 0.06, 8, 1.0)
	mb.add_cylinder(snow, _xf(Vector3(0, r * 1.1 - 0.02, 0)), r * 0.95, r * 0.9, 0.06, 8, 0.6)
	mb.add_cylinder(wood, _xf(Vector3(0, r * 1.1, 0)), 0.06, 0.05, 0.4, 5, 1.0)
	var fh := rng.randf_range(1.1, 1.5)
	for k in range(3):
		var y := r * 1.1 + 0.25 + k * fh * 0.26
		var rr := (0.6 - k * 0.15) * fh * 0.75
		mb.add_cone(leaf, _xf(Vector3(0, y, 0), rng.randf() * TAU), rr, fh * 0.42, 7, 0.8)
	body.add_child(mb.to_instance("PlanterMesh"))
	Props._add_box_col(body, Vector3(r * 1.8, r * 1.1, r * 1.8), Vector3(0, r * 0.55, 0))
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


## A crate (Props.crate) with snow lying on its lid.
static func crate(size: float) -> Node3D:
	var c := Props.crate(size)
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size * 1000.0)
	mb.add_blob(PSXMat.lit("snow", Color.WHITE, {"affine": 0.5}), _xf(Vector3(0, size + 0.01, 0)), Vector3(size * 0.46, 0.08, size * 0.44), rng, 0.15, 2, 6, 0.8, Color.WHITE, 0.0)
	c.add_child(mb.to_instance("Snow"))
	return c


## A barrel (Props.barrel) with a cap of snow.
static func barrel() -> Node3D:
	var b := Props.barrel()
	var mb := MeshBuilder.new()
	var top := 0.0
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, (mi as MeshInstance3D).get_aabb().end.y)
	mb.add_cylinder(PSXMat.lit("snow", Color.WHITE, {"affine": 0.5}), _xf(Vector3(0, top - 0.01, 0)), 0.3, 0.18, 0.1, 8, 0.8)
	b.add_child(mb.to_instance("Snow"))
	return b


## A log store shed on short posts out of the drifts: notched log walls, a steep roof with snow
## lying deep on it, a door up two steps, sacks and a sledge under the eaves.
static func storehouse(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Storehouse")
	var mb := MeshBuilder.new()
	var logs := PSXMat.lit("bark", Color(0.72, 0.58, 0.48))
	var dark := PSXMat.lit("planks_dark")
	var roof := PSXMat.lit("roof_green", Color.WHITE, {"affine": 0.7})
	var snow := PSXMat.lit("snow", Color.WHITE, {"affine": 0.5})
	var w := 3.6
	var d := 3.0
	var fl := 0.6
	for x in [-w * 0.5 + 0.2, w * 0.5 - 0.2]:
		for z in [-d * 0.5 + 0.2, d * 0.5 - 0.2]:
			mb.add_cylinder(dark, _xf(Vector3(x, -0.8, z)), 0.14, 0.12, fl + 0.8, 6, 0.8)
	mb.add_box(dark, _xf(Vector3(0, fl - 0.08, 0)), Vector3(w + 0.2, 0.16, d + 0.2), 0.8, Color.WHITE, false)
	# log walls: courses of round logs, the ends crossing at the corners
	var course := 0.26
	var h := 2.0
	var k := 0
	var y := fl
	while y < fl + h:
		var long := k % 2 == 0
		for s in [-1.0, 1.0]:
			if long:
				mb.add_cylinder(logs, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(w * 0.5 + 0.25, y + course * 0.5, s * d * 0.5)), course * 0.5, course * 0.5, w + 0.5, 6, 0.8, Color.WHITE.darkened(rng.randf() * 0.15), true, true)
			else:
				mb.add_cylinder(logs, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(s * w * 0.5, y + course * 0.5, -d * 0.5 - 0.25)), course * 0.5, course * 0.5, d + 0.5, 6, 0.8, Color.WHITE.darkened(rng.randf() * 0.15), true, true)
		y += course * 0.5
		k += 1
	mb.add_box(dark, _xf(Vector3(0, fl + h * 0.5, 0)), Vector3(w - 0.1, h, d - 0.1), 0.6, Color(0.5, 0.45, 0.4))
	mb.add_gable_roof(roof, _xf(Vector3(0, fl + h + 0.05, 0), PI * 0.5), d, w, d * 0.9, 0.55, 0.6, Color.WHITE, logs)
	mb.add_box(snow, _xf(Vector3(0, fl + h + d * 0.9 + 0.08, 0)), Vector3(w + 1.0, 0.18, 0.4), 0.6)
	mb.add_box_unit_uv(PSXMat.lit("door", Color(0.8, 0.72, 0.62), {"vertex_color": false}), _xf(Vector3(0, fl + 0.75, d * 0.5 + 0.08)), Vector3(0.8, 1.45, 0.06))
	for i in range(2):
		mb.add_box(dark, _xf(Vector3(0, fl - 0.2 - i * 0.2, d * 0.5 + 0.35 + i * 0.3)), Vector3(1.0, 0.08, 0.3), 1.0, Color.WHITE, false)
	# sacks against the wall, a sledge leaning on it, drifts at the foot
	for i in range(3):
		mb.add_blob(PSXMat.lit("canvas", Color(0.82, 0.76, 0.62)), _xf(Vector3(-w * 0.5 - 0.35, 0.25, -0.6 + i * 0.5), rng.randf() * TAU), Vector3(0.24, 0.3, 0.22), rng, 0.2, 3, 6)
	var sl := Transform3D(Basis(Vector3.BACK, -1.2), Vector3(w * 0.5 + 0.35, 0.9, 0.0))
	for s in [-1.0, 1.0]:
		mb.add_box(dark, sl * _xf(Vector3(0, 0, s * 0.3)), Vector3(1.8, 0.06, 0.06), 1.0)
	for i in range(4):
		mb.add_box(PSXMat.lit("planks"), sl * _xf(Vector3(-0.6 + i * 0.4, 0.05, 0)), Vector3(0.25, 0.04, 0.7), 1.0)
	for s in [-1.0, 1.0]:
		mb.add_blob(snow, _xf(Vector3(s * (w * 0.5 + 0.2), 0.05, rng.randf_range(-0.8, 0.8))), Vector3(0.6, 0.35, 1.2), rng, 0.2, 2, 6, 0.6, Color.WHITE, 0.0)
	var mi := mb.to_instance()
	mi.visibility_range_end = 400.0
	body.add_child(mi)
	Props._add_box_col(body, Vector3(w + 0.4, fl + h + 0.8, d + 0.4), Vector3(0, (fl + h + 0.8) * 0.5 - 0.8, 0))
	return body


## The sledge-maker's open shed: posts, a snow-laden shed roof, a log back wall, a sledge on trestles
## half built, skis and runners on the wall, the workbench, a chopping block, shavings on the snow.
## Markers: Worker (at the sledge, facing it), Bench.
static func workshop(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Workshop")
	var mb := MeshBuilder.new()
	var dark := PSXMat.lit("planks_dark")
	var planks := PSXMat.lit("planks")
	var logs := PSXMat.lit("bark", Color(0.72, 0.58, 0.48))
	var roof := PSXMat.lit("roof_green", Color.WHITE, {"affine": 0.7})
	var snow := PSXMat.lit("snow", Color.WHITE, {"affine": 0.5})
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	var w := 7.5
	var d := 5.0
	mb.add_box(planks, _xf(Vector3(0, -0.75, 0)), Vector3(w + 0.2, 1.6, d + 0.2), 0.5, Color(0.8, 0.8, 0.8), true, false)
	Props._add_box_col(body, Vector3(w + 0.2, 1.6, d + 0.2), Vector3(0, -0.75, 0))
	for x in [-w * 0.5, 0.0, w * 0.5]:
		for z in [-d * 0.5, d * 0.5]:
			var ph := 3.4 if z < 0.0 else 2.7
			mb.add_cylinder(logs, _xf(Vector3(x, 0.0, z)), 0.16, 0.14, ph, 6, 0.6)
			Props._add_box_col(body, Vector3(0.3, ph, 0.3), Vector3(x, ph * 0.5, z))
	mb.add_box(dark, _xf(Vector3(0, 2.65, d * 0.5)), Vector3(w + 0.3, 0.16, 0.18), 0.6, Color.WHITE, false)
	mb.add_box(dark, _xf(Vector3(0, 3.35, -d * 0.5)), Vector3(w + 0.3, 0.16, 0.18), 0.6, Color.WHITE, false)
	Buildings.add_shed_roof(mb, roof, dark, _xf(Vector3(0, 2.72, 0)), w, d, 0.75, 0.6)
	mb.add_box(snow, Transform3D(Basis(Vector3.RIGHT, atan2(0.75, d + 1.2)), Vector3(0, 3.35, 0)), Vector3(w + 0.8, 0.2, d + 1.0), 0.5)
	# the log back wall
	for i in range(11):
		mb.add_cylinder(logs, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(w * 0.5, 0.15 + i * 0.29, -d * 0.5 + 0.12)), 0.15, 0.15, w, 6, 0.8, Color.WHITE.darkened(rng.randf() * 0.15), true, true)
	Props._add_box_col(body, Vector3(w, 3.2, 0.3), Vector3(0, 1.6, -d * 0.5 + 0.12))
	# the sledge on its trestles: runners curling up at the front, slats across
	var sy := 0.8
	for s in [-1.0, 1.0]:
		mb.add_tube(dark, PackedVector3Array([Vector3(1.6 - 1.5, sy, 0.4 + s * 0.45), Vector3(1.6 + 1.2, sy, 0.4 + s * 0.45), Vector3(1.6 + 1.6, sy + 0.3, 0.4 + s * 0.45), Vector3(1.6 + 1.45, sy + 0.55, 0.4 + s * 0.45)]), 0.05, 0.04, 4, 1.0)
	for i in range(6):
		mb.add_box(planks, _xf(Vector3(0.3 + i * 0.45, sy + 0.12, 0.4)), Vector3(0.3, 0.04, 1.0), 1.0)
	for x in [0.6, 2.6]:
		for s in [-1.0, 1.0]:
			Buildings.beam_between(mb, dark, Vector3(x - 0.2 * s, 0.0, 0.4 + s * 0.35), Vector3(x + 0.15 * s, sy - 0.08, 0.4), 0.07)
	Props._add_box_col(body, Vector3(3.4, 1.0, 1.1), Vector3(1.6, 0.5, 0.4))
	# skis and runners on the back wall, the bench and its tools
	for i in range(5):
		mb.add_box(planks, Transform3D(Basis(Vector3.BACK, 0.08), Vector3(-3.0 + i * 0.32, 1.3, -d * 0.5 + 0.32)), Vector3(0.12, 2.0, 0.04), 1.0, Color(0.9, 0.8, 0.7))
	var bp := Vector3(-1.4, 0.0, -d * 0.5 + 0.7)
	mb.add_box(planks, _xf(bp + Vector3(0, 0.85, 0)), Vector3(2.2, 0.08, 0.7), 1.0, Color.WHITE, false)
	for x in [-0.95, 0.95]:
		for z in [-0.25, 0.25]:
			mb.add_box(dark, _xf(bp + Vector3(x, 0.42, z)), Vector3(0.08, 0.84, 0.08), 1.0)
	mb.add_box(iron, _xf(bp + Vector3(-0.5, 0.93, 0.0), 0.4), Vector3(0.25, 0.06, 0.08), 1.0)
	mb.add_box(logs, _xf(bp + Vector3(0.4, 0.95, 0.05)), Vector3(0.5, 0.1, 0.12), 1.0)
	Props._add_box_col(body, Vector3(2.2, 0.9, 0.7), bp + Vector3(0, 0.45, 0))
	var blk := Vector3(-3.0, 0.0, d * 0.5 - 0.6)
	mb.add_cylinder(logs, _xf(blk), 0.3, 0.32, 0.5, 7, 1.0)
	mb.add_box(iron, Transform3D(Basis(Vector3.BACK, 0.5), blk + Vector3(0.05, 0.55, 0)), Vector3(0.2, 0.12, 0.04), 1.0)
	for i in range(9):
		mb.add_blob(PSXMat.flat(Color(0.85, 0.72, 0.5)), _xf(Vector3(rng.randf_range(-0.4, 2.8), 0.06, rng.randf_range(-0.4, 1.4))), Vector3(0.12, 0.02, 0.08), rng, 0.3, 2, 4)
	var mi := mb.to_instance()
	mi.visibility_range_end = 400.0
	body.add_child(mi)
	var m := Marker3D.new()
	m.name = "Worker"
	m.position = Vector3(1.6, 0.0, 1.5)
	m.rotation.y = PI
	body.add_child(m)
	var b := Marker3D.new()
	b.name = "Bench"
	b.position = bp + Vector3(0, 0, 0.8)
	b.rotation.y = PI
	body.add_child(b)
	return body


## A wayside shrine: a black-stone plinth up two steps, a tall carved ice-bear on it under a small
## green tiered roof on four posts, offerings of candles and pine sprigs, lanterns either side.
## Markers: Keeper (beside the idol, facing it), Pray (at the foot of the steps).
static func shrine(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := Props._body("Shrine")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("black_rock", Color(0.9, 0.9, 0.95), {"affine": 0.6})
	var ice := PSXMat.lit("ice", Color(0.85, 0.95, 1.0), {"emission": Color(0.3, 0.6, 1.0), "emission_energy": 0.6, "affine": 0.3})
	var dark := PSXMat.lit("planks_dark")
	var roof := PSXMat.lit("roof_green", Color.WHITE, {"affine": 0.7})
	var snow := PSXMat.lit("snow", Color.WHITE, {"affine": 0.5})
	var t1 := 0.4
	var t2 := 0.8
	mb.add_box(stone, _xf(Vector3(0, t1 * 0.5 - 0.3, 0)), Vector3(4.4, t1 + 0.6, 4.4), 0.6, Color.WHITE, true, false)
	mb.add_box(stone, _xf(Vector3(0, (t1 + t2) * 0.5, -0.3)), Vector3(3.0, t2 - t1, 2.8), 0.6, Color(0.9, 0.9, 0.9), true, false)
	Props._add_box_col(body, Vector3(4.4, t1 + 0.6, 4.4), Vector3(0, t1 * 0.5 - 0.3, 0))
	Props._add_box_col(body, Vector3(3.0, t2 - t1, 2.8), Vector3(0, (t1 + t2) * 0.5, -0.3))
	for i in range(2):
		mb.add_box(stone, _xf(Vector3(0, t1 * (i + 0.5) / 2.0 + t1 * 0.5 - 0.2, 2.4 + 0.35 * (1 - i))), Vector3(1.6, 0.2, 0.35), 0.6)
	# the ice-bear: a glowing carved bear up on its hind legs
	var ip := Vector3(0, t2, -0.9)
	mb.add_blob(ice, _xf(ip + Vector3(0, 0.8, 0)), Vector3(0.45, 0.8, 0.38), rng, 0.15, 3, 7, 0.8)
	mb.add_blob(ice, _xf(ip + Vector3(0, 1.75, -0.05)), Vector3(0.3, 0.28, 0.3), rng, 0.12, 3, 6, 0.8)
	mb.add_blob(ice, _xf(ip + Vector3(0, 1.68, 0.25)), Vector3(0.14, 0.12, 0.18), rng, 0.1, 2, 6, 0.8)
	for s in [-1.0, 1.0]:
		mb.add_blob(ice, _xf(ip + Vector3(s * 0.22, 2.0, -0.05)), Vector3(0.08, 0.08, 0.06), rng, 0.1, 2, 5, 0.8)
		mb.add_tube(ice, PackedVector3Array([ip + Vector3(s * 0.4, 1.3, 0.0), ip + Vector3(s * 0.55, 1.6, 0.25), ip + Vector3(s * 0.45, 1.85, 0.35)]), 0.12, 0.08, 5, 0.8)
	Props._add_box_col(body, Vector3(0.9, 2.2, 0.8), ip + Vector3(0, 1.1, 0))
	# posts and the tiered roof
	for x in [-1.3, 1.3]:
		for z in [-1.6, 0.9]:
			mb.add_cylinder(dark, _xf(Vector3(x, t2, z)), 0.11, 0.1, 2.6, 6, 0.8)
			Props._add_box_col(body, Vector3(0.24, 3.4, 0.24), Vector3(x, 1.7, z))
	for i in range(3):
		var r := 2.3 - i * 0.65
		var y := t2 + 2.6 + i * 0.55
		mb.add_cylinder(roof, Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(0, y, -0.35)), r, r * 0.7, 0.6, 4, 0.7, Color.WHITE, false, i == 0, false)
		mb.add_cylinder(snow, Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(0, y + 0.56, -0.35)), r * 0.72, r * 0.5, 0.12, 4, 0.6, Color.WHITE, false, false, false)
	mb.add_cylinder(PSXMat.lit("roof_tiles", Color(0.95, 0.62, 0.4)), _xf(Vector3(0, t2 + 4.3, -0.35)), 0.2, 0.0, 0.6, 6, 1.0)
	# offerings: candles and pine sprigs; lanterns at the steps
	var flame := PSXMat.glow(Color(1.0, 0.75, 0.35), 3.0)
	var wax := PSXMat.flat(Color(0.93, 0.9, 0.8))
	for i in range(5):
		var op := ip + Vector3(-0.8 + i * 0.4, 0.0, 0.7 + (i % 2) * 0.15)
		if i % 2 == 0:
			mb.add_cylinder(wax, _xf(op), 0.035, 0.03, 0.2, 5, 1.0)
			mb.add_box(flame, _xf(op + Vector3(0, 0.24, 0)), Vector3(0.04, 0.07, 0.04), 1.0)
		else:
			mb.add_cone(PSXMat.lit("pine_snow", Color(0.9, 1.0, 0.95)), _xf(op), 0.12, 0.3, 5, 1.0)
	for s in [-1.0, 1.0]:
		var lp := Vector3(s * 1.4, t1, 2.0)
		mb.add_cylinder(dark, _xf(lp), 0.05, 0.05, 1.3, 5, 1.0)
		mb.add_box(flame, _xf(lp + Vector3(0, 1.45, 0)), Vector3(0.18, 0.24, 0.18), 1.0)
		mb.add_pyramid_roof(dark, _xf(lp + Vector3(0, 1.58, 0)), 0.24, 0.24, 0.16, 0.03, 1.0)
	var mi := mb.to_instance()
	mi.visibility_range_end = 400.0
	body.add_child(mi)
	var k := Marker3D.new()
	k.name = "Keeper"
	k.position = ip + Vector3(0.85, 0.0, 0.7)
	k.rotation.y = atan2(-0.85, -0.7)
	body.add_child(k)
	var pr := Marker3D.new()
	pr.name = "Pray"
	pr.position = Vector3(0, 0.0, 3.6)
	pr.rotation.y = PI
	body.add_child(pr)
	return body
