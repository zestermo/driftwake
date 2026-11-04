class_name BrinehollowLighthouse
extends RefCounted
## Brinehollow's lighthouse (1.30, replacing Props.lighthouse there): a tall tapered tower banded red and white on an
## octagonal stone plinth, its door up a flight of steps facing the town, slit windows up the shaft; at the top a
## corbelled gallery with a railing you can walk round, the watch room, the glazed lamp room with its turning lens and
## beam, a copper dome, ball and vane. F at the door climbs to the gallery ("the tower's 104 steps"), F at the watch
## room's door climbs down. Ambrose keeps watch up there with his telescope ("Keeper" marker, facing out to sea, -Z).
## Local: the plinth's ground at the origin, the door on +Z. Markers Door (outside its steps), Gallery (where you come
## out), Keeper. One merged mesh, the lamp's own; colliders for the plinth, the shaft, the gallery deck and its rail,
## the lamp room. Per frame: the lens turns (spinner), as before.

const PLINTH_TOP := 1.1
const SHAFT_H := 20.0
const R0 := 2.5
const R1 := 1.75
const GALLERY_R := 2.9
const WATCH_R := 1.55
const STEPS := 104


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


static func gallery_y() -> float:
	return PLINTH_TOP + SHAFT_H


static func tower() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Lighthouse"
	body.collision_layer = Buildings.WORLD_LAYER
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick")
	var white := PSXMat.lit("plaster", Color(1.0, 1.0, 0.97))
	var red := PSXMat.lit("plaster", Color(0.74, 0.18, 0.14))
	var iron := PSXMat.lit("metal", Color(0.2, 0.21, 0.23))
	var copper := PSXMat.lit("metal", Color(0.42, 0.66, 0.58))
	var glass := PSXMat.glow(Color(1.0, 0.9, 0.58), 1.6)
	var window := PSXMat.lit("window", Color.WHITE, {"emission": Color(0.95, 0.72, 0.38), "emission_energy": 0.8, "emission_tex": "window"})
	var gy := gallery_y()

	# the plinth, its coping, the steps up to the door
	mb.add_cylinder(stone, _xf(Vector3(0, -1.5, 0)), 3.7, 3.5, 1.5 + PLINTH_TOP, 8, 0.5, Color(0.9, 0.9, 0.88), true)
	mb.add_cylinder(PSXMat.lit("flagstones", Color(0.9, 0.88, 0.82)), _xf(Vector3(0, PLINTH_TOP - 0.02, 0)), 3.6, 3.6, 0.1, 8, 0.6, Color.WHITE, true)
	_cyl(body, 3.6, 1.5 + PLINTH_TOP, Vector3(0, -1.5, 0))
	Buildings.door_steps(body, mb, stone, 0.0, 3.45, PLINTH_TOP, 1.9, 0.0, 1.5)
	# the shaft in bands, red and white, tapering
	var bands := 5
	for i in range(bands):
		var y0 := PLINTH_TOP + SHAFT_H * i / bands
		var ra := lerpf(R0, R1, float(i) / bands)
		var rb := lerpf(R0, R1, float(i + 1) / bands)
		mb.add_cylinder(red if i % 2 == 1 else white, _xf(Vector3(0, y0, 0)), ra, rb, SHAFT_H / bands, 12, 0.4, Color.WHITE, false)
	_cyl(body, (R0 + lerpf(R0, R1, 0.5)) * 0.5, SHAFT_H * 0.5, Vector3(0, PLINTH_TOP, 0))
	_cyl(body, (lerpf(R0, R1, 0.5) + R1) * 0.5, SHAFT_H * 0.5, Vector3(0, PLINTH_TOP + SHAFT_H * 0.5, 0))
	# the door in a stone surround, a lamp over it
	var dz := R0 - 0.02
	mb.add_box(stone, _xf(Vector3(0, PLINTH_TOP + 1.25, dz - 0.05)), Vector3(1.7, 2.6, 0.3), 0.5)
	mb.add_box(stone, _xf(Vector3(0, PLINTH_TOP + 2.65, dz + 0.02)), Vector3(1.9, 0.25, 0.45), 0.5, Color(0.8, 0.8, 0.78))
	Buildings.panel_door(mb, _xf(Vector3(0, PLINTH_TOP, dz + 0.11)), 1.0, 2.2, Buildings.door_leaf(Color(0.2, 0.32, 0.3)), PSXMat.lit("planks_dark"))
	Buildings.wall_lantern(mb, Vector3(0.95, PLINTH_TOP + 2.2, dz + 0.1), PSXMat.lit("planks_dark"))
	# slit windows climbing the shaft, a quarter turn each
	for k in range(5):
		var y := PLINTH_TOP + 4.0 + k * 3.4
		var a := PI * 0.5 * k + PI * 0.25
		var r := lerpf(R0, R1, (y - PLINTH_TOP) / SHAFT_H) + 0.02
		var b := Basis(Vector3.UP, a)
		mb.add_box_unit_uv(window, Transform3D(b, b * Vector3(0, 0, r) + Vector3(0, y, 0)), Vector3(0.4, 0.8, 0.06))
		mb.add_box(stone, Transform3D(b, b * Vector3(0, 0, r + 0.02) + Vector3(0, y - 0.48, 0)), Vector3(0.6, 0.1, 0.16), 0.6)
	# the gallery: corbels flaring out under a deck, a railing round it
	mb.add_cylinder(stone, _xf(Vector3(0, gy - 0.7, 0)), R1, GALLERY_R - 0.1, 0.7, 12, 0.5, Color(0.92, 0.92, 0.9), false)
	for k in range(12):
		var a := TAU * k / 12.0
		var b := Basis(Vector3.UP, a)
		mb.add_box(stone, Transform3D(b, b * Vector3(0, 0, R1 + 0.35) + Vector3(0, gy - 1.05, 0)), Vector3(0.3, 0.7, 0.6), 0.6)
	mb.add_cylinder(iron, _xf(Vector3(0, gy - 0.08, 0)), GALLERY_R, GALLERY_R, 0.16, 16, 0.6, Color.WHITE, true, true)
	var deck := CylinderShape3D.new()
	deck.radius = GALLERY_R
	deck.height = 0.3
	var dcs := CollisionShape3D.new()
	dcs.shape = deck
	dcs.position = Vector3(0, gy - 0.15, 0)
	body.add_child(dcs)
	var posts := 24
	for k in range(posts):
		var a := TAU * k / posts
		mb.add_box(iron, _xf(Vector3(cos(a) * (GALLERY_R - 0.1), gy + 0.55, sin(a) * (GALLERY_R - 0.1))), Vector3(0.06, 1.1, 0.06), 1.0)
	for y: float in [0.55, 1.1]:
		var ring := PackedVector3Array()
		for k in range(posts + 1):
			var a := TAU * k / posts
			ring.append(Vector3(cos(a) * (GALLERY_R - 0.1), gy + y, sin(a) * (GALLERY_R - 0.1)))
		mb.add_tube(iron, ring, 0.035, -1.0, 4, 1.0)
	for k in range(12):
		var a := TAU * (k + 0.5) / 12.0
		var b := Basis(Vector3.UP, -a + PI * 0.5)
		var rcs := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(TAU * GALLERY_R / 12.0 + 0.1, 1.2, 0.12)
		rcs.shape = rb
		rcs.transform = Transform3D(b, Vector3(cos(a) * (GALLERY_R - 0.05), gy + 0.6, sin(a) * (GALLERY_R - 0.05)))
		body.add_child(rcs)
	# the watch room (a door out onto the gallery), the lamp room's glazing on it, the dome
	mb.add_cylinder(white, _xf(Vector3(0, gy, 0)), WATCH_R, WATCH_R, 1.1, 12, 0.4, Color.WHITE, false)
	Buildings.panel_door(mb, _xf(Vector3(0, gy, WATCH_R + 0.02)), 0.8, 1.05, Buildings.door_leaf(Color(0.2, 0.32, 0.3)), PSXMat.lit("planks_dark"))
	mb.add_cylinder(iron, _xf(Vector3(0, gy + 1.1, 0)), WATCH_R + 0.1, WATCH_R + 0.1, 0.12, 12, 0.6, Color.WHITE, true)
	var lr := 1.3
	var ly := gy + 1.22
	var lh := 1.9
	mb.add_cylinder(glass, _xf(Vector3(0, ly, 0)), lr, lr, lh, 8, 0.6, Color.WHITE, false)
	for k in range(8):
		var a := TAU * k / 8.0 + PI / 8.0
		mb.add_box(iron, _xf(Vector3(cos(a) * lr, ly + lh * 0.5, sin(a) * lr), -a), Vector3(0.07, lh, 0.07), 1.0)
	mb.add_cylinder(iron, _xf(Vector3(0, ly + lh * 0.5, 0)), lr + 0.02, lr + 0.02, 0.05, 8, 0.6, Color.WHITE, false)
	mb.add_cylinder(iron, _xf(Vector3(0, ly + lh, 0)), lr + 0.2, lr + 0.2, 0.12, 8, 0.6, Color.WHITE, true, true)
	mb.add_cylinder(copper, _xf(Vector3(0, ly + lh + 0.12, 0)), lr + 0.15, lr * 0.8, 0.45, 8, 0.6, Color.WHITE, false)
	mb.add_cone(copper, _xf(Vector3(0, ly + lh + 0.57, 0)), lr * 0.8, 0.85, 8, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 104
	var tip := ly + lh + 1.42
	mb.add_blob(copper, _xf(Vector3(0, tip + 0.15, 0)), Vector3.ONE * 0.22, rng, 0.05, 3, 6)
	mb.add_cylinder(iron, _xf(Vector3(0, tip + 0.3, 0)), 0.03, 0.02, 0.9, 4, 1.0)
	mb.add_box(iron, _xf(Vector3(0.15, tip + 1.0, 0)), Vector3(0.55, 0.16, 0.02), 1.0)
	mb.add_box(iron, _xf(Vector3(0, tip + 0.75, 0)), Vector3(0.5, 0.02, 0.02), 1.0)
	mb.add_box(iron, _xf(Vector3(0, tip + 0.75, 0)), Vector3(0.02, 0.02, 0.5), 1.0)
	_cyl(body, WATCH_R + 0.05, lh + 1.3, Vector3(0, gy, 0))
	# Ambrose's telescope on its tripod, at the rail facing out to sea
	var tp := Vector3(0.7, gy, -GALLERY_R + 0.55)
	for k in range(3):
		var a := TAU * k / 3.0
		Buildings.beam_between(mb, PSXMat.lit("planks_dark"), tp + Vector3(cos(a) * 0.35, 0.0, sin(a) * 0.35), tp + Vector3(0, 1.1, 0), 0.025)
	var brass := PSXMat.lit("metal", Color(0.85, 0.66, 0.32))
	var sb := Basis(Vector3.RIGHT, PI * 0.5 + 0.12)
	mb.add_cylinder(brass, Transform3D(sb, tp + Vector3(0, 1.15, -0.45)), 0.07, 0.05, 0.9, 7, 1.0, Color.WHITE, true, true)
	var mi := mb.to_instance("Mesh")
	body.add_child(mi)

	# the lamp: a turning lens and its beam, a glow in the lamp room
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = Vector3(0, ly + lh * 0.5, 0)
	lamp.set_script(load("res://scripts/props/spinner.gd"))
	lamp.set("speed", 0.9)
	var lmb := MeshBuilder.new()
	var lens := PSXMat.glow(Color(1.0, 0.95, 0.7), 6.0)
	lmb.add_cylinder(lens, _xf(Vector3(0, -0.45, 0)), 0.42, 0.42, 0.9, 8, 1.0, Color.WHITE, true, true)
	lmb.add_box(lens, Transform3D.IDENTITY, Vector3(0.36, 0.5, 1.9), 1.0, Color.WHITE, false)
	lamp.add_child(lmb.to_instance("Lens"))
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.92, 0.7)
	spot.light_energy = 6.0
	spot.spot_range = 120.0
	spot.spot_angle = 9.0
	spot.rotation.x = deg_to_rad(-6)
	lamp.add_child(spot)
	body.add_child(lamp)
	var omni := OmniLight3D.new()
	omni.position = Vector3(0, ly + lh * 0.5, 0)
	omni.light_color = Color(1.0, 0.85, 0.55)
	omni.light_energy = 1.5
	omni.omni_range = 10.0
	body.add_child(omni)

	# climbing: F at the door up, F at the watch room's door down
	var up := _climb(body, "ClimbUp", "Climb the lighthouse", Vector3(0, PLINTH_TOP + 1.0, R0 + 0.7), 1.3)
	up.interacted.connect(func(p: Player): _move(p, body.to_global(Vector3(0, gy + 0.1, WATCH_R + 0.75)), body.global_rotation.y,
		"You climb the tower's %d steps." % STEPS))
	var down := _climb(body, "ClimbDown", "Climb down", Vector3(0, gy + 0.9, WATCH_R + 0.3), 0.9)
	down.interacted.connect(func(p: Player): _move(p, body.to_global(Vector3(0, 0.25, R0 + 4.2)), body.global_rotation.y,
		"Back down the %d steps." % STEPS))
	_marker(body, "Door", Vector3(0, 0, R0 + 4.2), 0.0)
	_marker(body, "Gallery", Vector3(0, gy, WATCH_R + 0.75), 0.0)
	_marker(body, "Keeper", Vector3(-0.5, gy, -GALLERY_R + 0.75), PI)
	return body


static func _climb(body: Node3D, n: String, prompt: String, at: Vector3, r: float) -> Interactable:
	var it := Interactable.new()
	it.name = n
	it.collision_layer = 512
	it.collision_mask = 0
	it.prompt_text = prompt
	it.gesture = "open"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	cs.shape = sph
	it.add_child(cs)
	it.position = at
	body.add_child(it)
	return it


## The captain up or down the tower: there, facing `yaw`, a toast.
static func _move(p: Player, to: Vector3, yaw: float, say: String) -> void:
	p.global_position = to
	p.velocity = Vector3.ZERO
	p.rotation.y = yaw
	p.reset_physics_interpolation()
	p.get_tree().call_group("hud", "show_toast", say)


static func _cyl(body: Node3D, r: float, h: float, base: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = base + Vector3(0, h * 0.5, 0)
	body.add_child(cs)


static func _marker(parent: Node3D, n: String, p: Vector3, yaw := 0.0) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = p
	m.rotation.y = yaw
	parent.add_child(m)


## The signal mast by the keeper's cottage: a pole with a yard, a halyard and three flags.
static func signal_mast(seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := StaticBody3D.new()
	body.name = "SignalMast"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var rope := PSXMat.lit("rope", Color(0.85, 0.8, 0.7))
	mb.add_cylinder(PSXMat.lit("stone_brick"), _xf(Vector3(0, -0.3, 0)), 0.55, 0.5, 0.6, 8, 0.6)
	mb.add_cylinder(wood, _xf(Vector3(0, 0.0, 0)), 0.12, 0.07, 8.0, 6, 0.8)
	mb.add_box(wood, _xf(Vector3(0, 6.6, 0)), Vector3(2.6, 0.08, 0.08), 0.8)
	var cols := [Color(0.8, 0.2, 0.15), Color(0.95, 0.85, 0.3), Color(0.2, 0.35, 0.65)]
	for k in range(3):
		var x := -1.0 + k * 1.0
		mb.add_tube(rope, PackedVector3Array([Vector3(x, 6.6, 0), Vector3(x, 5.6, 0)]), 0.012, -1.0, 3, 1.0)
		var flag := PSXMat.lit("fabric", cols[k], {"affine": 0.6})
		var sway := rng.randf_range(0.1, 0.3)
		mb.add_quad(flag, Vector3(x, 6.5, 0), Vector3(x + 0.55, 6.45, sway), Vector3(x + 0.55, 5.95, sway), Vector3(x, 5.9, 0),
			Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3.FORWARD)
		mb.add_quad(flag, Vector3(x, 5.9, 0), Vector3(x + 0.55, 5.95, sway), Vector3(x + 0.55, 6.45, sway), Vector3(x, 6.5, 0),
			Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2.ZERO, Color(0.8, 0.8, 0.8), Vector3.BACK)
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = 300.0
	body.add_child(mi)
	_cyl(body, 0.3, 8.0, Vector3(0, -0.3, 0))
	return body


## The fog bell: a bronze bell hung in a timber frame with a little roof, its pull rope.
static func fog_bell() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "FogBell"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var bronze := PSXMat.lit("metal", Color(0.72, 0.52, 0.28))
	for x: float in [-0.7, 0.7]:
		mb.add_box(wood, _xf(Vector3(x, 1.2, 0)), Vector3(0.16, 2.4, 0.16), 0.8)
	mb.add_box(wood, _xf(Vector3(0, 2.35, 0)), Vector3(1.7, 0.16, 0.18), 0.8)
	mb.add_gable_roof(PSXMat.lit("roof_tiles"), _xf(Vector3(0, 2.45, 0), PI * 0.5), 0.9, 1.9, 0.45, 0.1, 0.6)
	mb.add_cylinder(bronze, _xf(Vector3(0, 1.55, 0)), 0.42, 0.24, 0.7, 10, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(bronze, _xf(Vector3(0, 1.48, 0)), 0.46, 0.42, 0.08, 10, 1.0, Color.WHITE, true, true)
	mb.add_tube(PSXMat.lit("rope", Color(0.85, 0.8, 0.7)), PackedVector3Array([Vector3(0, 1.5, 0), Vector3(0.1, 0.9, 0.2)]), 0.02, -1.0, 3, 1.0)
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = 160.0
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.6, 2.5, 0.5)
	cs.shape = b
	cs.position = Vector3(0, 1.25, 0)
	body.add_child(cs)
	return body
