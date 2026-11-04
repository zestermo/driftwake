class_name BrinehollowRooms
extends RefCounted
## Walk-in buildings for Brinehollow's chapel close (1.30): a one-room cottage you can enter, in the town's look (a
## stone footing and wainscot, plaster or planks above, timber framing, a tiled or thatched gable roof, an upper storey
## when it has one), its doorway open on the front (+Z) with the door leaf swung back inside, steps up to the sill.
## Each kind furnished for its keeper: the net loft (Netmaker Hesk), the tinker's workshop (Wick, a gadget Workbench),
## the scribe's house (Brother Aldous: shelves of books, a desk, a lectern).
## Solid all through: the floor, every wall and the lintel, the roof as a sloped shape, the furniture over 0.6 m.
## Markers: "Door" (outside, facing in), "Keeper" (where its keeper stands), "Inside" (the room's middle).
## One merged mesh a building (no shadows inside: the furniture's own mesh has none), a warm OmniLight in the room
## (no shadows, faded out past 30 m). Nothing per frame.

const T := 0.25
const FL := 0.3
const DOOR_W := 1.2
const DOOR_H := 2.2
const RANGE := 160.0
const INSIDE_RANGE := 45.0


static func _xf(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


static func _col(body: Node3D, size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = _xf(pos, yaw)
	body.add_child(cs)


static func _marker(parent: Node3D, n: String, p: Vector3, yaw := 0.0) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = p
	m.rotation.y = yaw
	parent.add_child(m)


## The building. spec: name, kind ("loft", "tinker", "scribe"), w, d, h (the room), floors (1, 2), wall, wall2,
## roof_tex, pitch, door_x, trim (Color), seed.
static func room(spec: Dictionary) -> StaticBody3D:
	var w: float = spec["w"]
	var d: float = spec["d"]
	var h: float = spec.get("h", 2.9)
	var floors: int = spec.get("floors", 1)
	var dx: float = spec.get("door_x", 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	var body := StaticBody3D.new()
	body.name = str(spec["name"])
	body.collision_layer = Buildings.WORLD_LAYER
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick")
	var wall := PSXMat.lit(spec.get("wall", "plaster"))
	var wall2 := PSXMat.lit(spec.get("wall2", spec.get("wall", "plaster")))
	var beam := PSXMat.lit("planks_dark")
	var planks := PSXMat.lit("planks")
	var roof := PSXMat.lit(spec.get("roof_tex", "roof_tiles"), Color.WHITE, {"affine": 0.8})
	var window := PSXMat.lit("window", Color.WHITE, {"emission": Color(0.95, 0.72, 0.38), "emission_energy": 0.7, "emission_tex": "window"})
	var trim := PSXMat.lit("planks", spec.get("trim", Buildings.TRIM_COLORS[0]))

	# footing and floor (the footing's top only a rim round the planks: vertex snap tilts two stacked tops apart)
	mb.add_box(stone, _xf(Vector3(0, FL - 1.0, 0)), Vector3(w + 0.3, 2.0, d + 0.3), 0.5, Color.WHITE, true, true)
	var rim := 0.15 + T
	for s: float in [-1.0, 1.0]:
		mb.add_box(stone, _xf(Vector3(0, FL - 0.05, s * (d * 0.5 + 0.15 - rim * 0.5))), Vector3(w + 0.3, 0.1, rim), 0.5)
		mb.add_box(stone, _xf(Vector3(s * (w * 0.5 + 0.15 - rim * 0.5), FL - 0.05, 0)), Vector3(rim, 0.1, d - T * 2), 0.5)
	Buildings.tiled_box(mb, planks, Vector3(0, FL - 0.005, 0), Vector3(w - T * 2, 0.04, d - T * 2), 2.0, 0.6, true, false)
	_col(body, Vector3(w + 0.3, 2.0, d + 0.3), Vector3(0, FL - 1.0, 0))
	Buildings.door_steps(body, mb, stone, dx, d * 0.5 + 0.15, FL, DOOR_W + 0.6, 0.0, 0.6)
	var leaf := Buildings.door_leaf(Buildings.door_paint(rng.seed, spec.get("trim", Buildings.TRIM_COLORS[0])))
	mb.add_box_unit_uv(leaf, _xf(Vector3(dx + DOOR_W * 0.5 - 0.04, FL + DOOR_H * 0.5, d * 0.5 - T - (DOOR_W - 0.1) * 0.5), PI * 0.5),
		Vector3(DOOR_W - 0.1, DOOR_H - 0.06, 0.05))

	# walls: a stone wainscot, the wall over it; both faces (a slab), a shape each
	var front_l := (dx - DOOR_W * 0.5) + w * 0.5
	var front_r := w * 0.5 - (dx + DOOR_W * 0.5)
	var walls := [[Vector3(0, 0, -d * 0.5 + T * 0.5), Vector3(w, 0, T)], [Vector3(-w * 0.5 + T * 0.5, 0, 0), Vector3(T, 0, d)],
		[Vector3(w * 0.5 - T * 0.5, 0, 0), Vector3(T, 0, d)],
		[Vector3(-w * 0.5 + front_l * 0.5, 0, d * 0.5 - T * 0.5), Vector3(front_l, 0, T)],
		[Vector3(w * 0.5 - front_r * 0.5, 0, d * 0.5 - T * 0.5), Vector3(front_r, 0, T)]]
	for wl in walls:
		var c: Vector3 = wl[0]
		var s: Vector3 = wl[1]
		Buildings.tiled_box(mb, stone, Vector3(c.x, FL + 0.4, c.z), Vector3(s.x + 0.04, 0.8, s.z + 0.04), 2.4, 0.5, true, true)
		Buildings.tiled_box(mb, wall, Vector3(c.x, FL + 0.8 + (h - 0.8) * 0.5, c.z), Vector3(s.x, h - 0.8, s.z), 2.4, 0.4, true, false)
		_col(body, Vector3(s.x, h, s.z), Vector3(c.x, FL + h * 0.5, c.z))
	mb.add_box(beam, _xf(Vector3(dx, FL + DOOR_H + (h - DOOR_H) * 0.5, d * 0.5 - T * 0.5)), Vector3(DOOR_W + 0.3, h - DOOR_H, T + 0.06), 0.6)
	_col(body, Vector3(DOOR_W, h - DOOR_H, T), Vector3(dx, FL + DOOR_H + (h - DOOR_H) * 0.5, d * 0.5 - T * 0.5))
	for s: float in [-1.0, 1.0]:
		mb.add_box(beam, _xf(Vector3(dx + s * (DOOR_W * 0.5 + 0.07), FL + DOOR_H * 0.5, d * 0.5 - T * 0.5)), Vector3(0.14, DOOR_H, T + 0.08), 0.6)
	# framing outside: corner posts and a sill beam
	for x: float in [-w * 0.5, w * 0.5]:
		for z: float in [-d * 0.5, d * 0.5]:
			mb.add_box(beam, _xf(Vector3(x, FL + h * 0.5, z)), Vector3(0.22, h, 0.22), 0.6)
	for z: float in [-d * 0.5 - 0.02, d * 0.5 + 0.02]:
		mb.add_box(beam, _xf(Vector3(0, FL + h - 0.08, z)), Vector3(w, 0.16, 0.06), 0.6)
	# windows: panes on both faces (the front either side of the door, the sides), shutters outside
	var wy := FL + 1.55
	var fronts: Array = []
	for x: float in [-w * 0.32, w * 0.32]:
		if absf(x - dx) > DOOR_W * 0.5 + 0.7:
			fronts.append(x)
	for x: float in fronts:
		mb.add_box_unit_uv(window, _xf(Vector3(x, wy, d * 0.5 + 0.02)), Vector3(0.8, 0.8, 0.04))
		mb.add_box_unit_uv(window, _xf(Vector3(x, wy, d * 0.5 - T - 0.02)), Vector3(0.8, 0.8, 0.04))
		Buildings.dress_window(mb, _xf(Vector3(x, wy, d * 0.5 + 0.02)), 0.8, trim, beam, true, rng)
	for s: float in [-1.0, 1.0]:
		mb.add_box_unit_uv(window, _xf(Vector3(s * (w * 0.5 + 0.02), wy, -0.2), PI * 0.5), Vector3(0.8, 0.8, 0.04))
		mb.add_box_unit_uv(window, _xf(Vector3(s * (w * 0.5 - T - 0.02), wy, -0.2), PI * 0.5), Vector3(0.8, 0.8, 0.04))
		Buildings.dress_window(mb, _xf(Vector3(s * (w * 0.5 + 0.02), wy, -0.2), s * PI * 0.5), 0.8, trim, beam, false, rng)
	# the ceiling (beams across, a light-tight backing over it)
	var cy := FL + h
	mb.add_quad(beam, Vector3(-w * 0.5, cy, -d * 0.5), Vector3(-w * 0.5, cy, d * 0.5), Vector3(w * 0.5, cy, d * 0.5), Vector3(w * 0.5, cy, -d * 0.5),
		Vector2.ZERO, Vector2(0, d * 0.5), Vector2(w * 0.5, d * 0.5), Vector2(w * 0.5, 0), Color(0.72, 0.72, 0.72), Vector3.DOWN)
	mb.add_quad(PSXMat.flat(Color(0.12, 0.08, 0.05)), Vector3(-w * 0.5, cy + 0.03, -d * 0.5), Vector3(-w * 0.5, cy + 0.03, d * 0.5),
		Vector3(w * 0.5, cy + 0.03, d * 0.5), Vector3(w * 0.5, cy + 0.03, -d * 0.5), Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color.WHITE, Vector3.DOWN)
	for k in range(3):
		var bx := -w * 0.5 + w * (k + 1) / 4.0
		mb.add_box(beam, _xf(Vector3(bx, cy - 0.12, 0)), Vector3(0.2, 0.24, d - T * 2), 0.6, Color.WHITE, false, true)

	# the upper storey (jettied, solid) or straight to the roof
	var top := cy
	var uw := w
	var ud := d
	var gable_mat := wall
	if floors > 1:
		var h2: float = spec.get("h2", 2.3)
		var jet := 0.3
		uw = w + jet * 2.0
		ud = d + jet * 2.0
		Buildings.tiled_box(mb, wall2, Vector3(0, top + h2 * 0.5, 0), Vector3(uw, h2, ud), 2.4, 0.4, false, false)
		mb.add_box(beam, _xf(Vector3(0, top + 0.05, 0)), Vector3(uw + 0.1, 0.18, ud + 0.1), 0.6)
		for x: float in [-uw * 0.5, -uw * 0.17, uw * 0.17, uw * 0.5]:
			for z: float in [-ud * 0.5 - 0.02, ud * 0.5 + 0.02]:
				mb.add_box(beam, _xf(Vector3(x, top + h2 * 0.5, z)), Vector3(0.18, h2, 0.06), 0.6)
		for x: float in [-uw * 0.3, uw * 0.3]:
			mb.add_box_unit_uv(window, _xf(Vector3(x, top + 1.2, ud * 0.5 + 0.05)), Vector3(0.7, 0.7, 0.06))
			Buildings.dress_window(mb, _xf(Vector3(x, top + 1.2, ud * 0.5 + 0.05)), 0.7, trim, beam, true, rng)
		_col(body, Vector3(uw, h2, ud), Vector3(0, top + h2 * 0.5, 0))
		top += h2
		gable_mat = wall2
	var rise: float = float(spec.get("pitch", 0.7)) * ud * 0.5
	var over := 0.45
	mb.add_gable_roof(roof, _xf(Vector3(0, top + 0.08, 0), PI * 0.5), ud, uw, rise, over, 0.5, Color.WHITE, gable_mat)
	mb.add_box(PSXMat.lit(spec.get("roof_tex", "roof_tiles"), Color(0.7, 0.62, 0.56), {"affine": 0.8}), _xf(Vector3(0, top + 0.08 + rise + 0.04, 0)), Vector3(uw + 1.1, 0.16, 0.28), 0.8)
	var drop := over * rise / (ud * 0.5)
	var ey := top + 0.08 - drop
	for s: float in [-1.0, 1.0]:
		for x: float in [-(uw * 0.5 + over), uw * 0.5 + over]:
			Buildings.beam_between(mb, beam, Vector3(x, ey, s * (ud * 0.5 + over)), Vector3(x, top + 0.08 + rise, 0), 0.06, 0.18)
	var pts := PackedVector3Array()
	for x: float in [-(uw * 0.5 + over), uw * 0.5 + over]:
		pts.append(Vector3(x, ey, -(ud * 0.5 + over)))
		pts.append(Vector3(x, ey, ud * 0.5 + over))
		pts.append(Vector3(x, top + 0.08 + rise + 0.1, 0))
		pts.append(Vector3(x, top - 0.02, 0))
	var rs := ConvexPolygonShape3D.new()
	rs.points = pts
	var rcs := CollisionShape3D.new()
	rcs.shape = rs
	body.add_child(rcs)
	if spec.get("chimney", false):
		var chx := -w * 0.5 + 0.55
		var chh := rise * 1.1 + 1.0
		mb.add_box(stone, _xf(Vector3(chx, top + 0.05 + chh * 0.5, -d * 0.5 + 0.7)), Vector3(0.7, chh, 0.7), 0.5, Color.WHITE, true, false)
		_col(body, Vector3(0.7, chh, 0.7), Vector3(chx, top + 0.05 + chh * 0.5, -d * 0.5 + 0.7))
	# a lantern by the door
	Buildings.wall_lantern(mb, Vector3(dx + DOOR_W * 0.5 + 0.4, FL + 2.1, d * 0.5), beam)

	# inside
	var fm := MeshBuilder.new()
	var keeper := Vector3(0, FL, -0.5)
	match str(spec["kind"]):
		"loft":
			keeper = _loft(body, fm, w, d, h, dx, rng)
		"tinker":
			keeper = _tinker(body, fm, w, d, h, dx, rng)
		"scribe":
			keeper = _scribe(body, fm, w, d, h, dx, rng)
	var glow := PSXMat.glow(Color(1.0, 0.76, 0.4), 2.0)
	fm.add_box(beam, _xf(Vector3(0.0, cy - 0.35, 0.3)), Vector3(0.03, 0.45, 0.03), 1.0)
	fm.add_box(glow, _xf(Vector3(0.0, cy - 0.7, 0.3)), Vector3(0.2, 0.26, 0.2), 1.0)
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = RANGE
	body.add_child(mi)
	var fmi := fm.to_instance("Furnishing")
	fmi.visibility_range_end = INSIDE_RANGE
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(fmi)
	var lamp := OmniLight3D.new()
	lamp.name = "RoomLight"
	lamp.position = Vector3(0, cy - 0.8, 0.3)
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 0.9
	lamp.omni_range = maxf(w, d) * 0.8
	lamp.shadow_enabled = false
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 25.0
	lamp.distance_fade_length = 6.0
	body.add_child(lamp)
	_marker(body, "Door", Vector3(dx, 0.0, d * 0.5 + 1.4), PI)
	_marker(body, "Keeper", keeper, 0.0)
	_marker(body, "Inside", Vector3(0, FL, 0))
	return body


## The drowned sailors' cross in the middle of the close: three stone steps, a shaft, a cross head with an anchor
## carved across it, a wreath at its foot.
static func sea_cross(seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := StaticBody3D.new()
	body.name = "SeaCross"
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.88, 0.86, 0.82))
	var dark := PSXMat.lit("stone_brick", Color(0.62, 0.62, 0.6))
	for k in range(3):
		var s := 2.4 - k * 0.6
		mb.add_box(stone, _xf(Vector3(0, -0.1 + k * 0.22 + 0.11, 0)), Vector3(s, 0.22 + (0.3 if k == 0 else 0.0), s), 0.6, Color(0.95 - k * 0.04, 0.95, 0.93), k == 0)
	mb.add_box(dark, _xf(Vector3(0, 0.56 + 1.2, 0)), Vector3(0.36, 2.4, 0.36), 0.6)
	mb.add_box(dark, _xf(Vector3(0, 2.75, 0)), Vector3(1.3, 0.3, 0.32), 0.6)
	mb.add_box(dark, _xf(Vector3(0, 3.2, 0)), Vector3(0.3, 0.7, 0.3), 0.6)
	var iron := PSXMat.lit("metal", Color(0.42, 0.4, 0.38))
	for s: float in [-1.0, 1.0]:
		var z := s * 0.19
		mb.add_box(iron, _xf(Vector3(0, 1.85, z)), Vector3(0.06, 0.9, 0.03), 1.0)
		mb.add_box(iron, _xf(Vector3(0, 2.2, z)), Vector3(0.36, 0.05, 0.03), 1.0)
		mb.add_tube(iron, MeshBuilder.curve_points(Vector3(-0.3, 1.55, z), Vector3(0, 1.25, z), Vector3(0.3, 1.55, z), 6), 0.025, -1.0, 4, 1.0)
	var leaves := PSXMat.lit("leaves", Color(0.6, 0.8, 0.55))
	var ring := PackedVector3Array()
	for k in range(9):
		var a := TAU * k / 8.0
		ring.append(Vector3(cos(a) * 0.32, 0.62, 0.45 + sin(a) * 0.32 * 0.4))
	mb.add_tube(leaves, ring, 0.07, -1.0, 5, 1.0)
	for k in range(4):
		var a := rng.randf() * TAU
		mb.add_blob(PSXMat.flat(Color(0.85, 0.2, 0.18) if k % 2 == 0 else Color(0.95, 0.9, 0.7)), _xf(Vector3(cos(a) * 0.3, 0.64, 0.45 + sin(a) * 0.12)), Vector3.ONE * 0.06, rng, 0.2, 2, 5)
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = RANGE
	body.add_child(mi)
	_col(body, Vector3(2.4, 0.5, 2.4), Vector3(0, 0.15, 0))
	_col(body, Vector3(1.2, 0.3, 1.2), Vector3(0, 0.5, 0))
	_col(body, Vector3(0.4, 3.0, 0.4), Vector3(0, 2.0, 0))
	return body


## The churchyard: a low stone wall round three sides of `size` (x, z; open toward -Z), headstones in rows, a stone
## bench. Local to its middle; heights from `ground` (local x, z -> local y).
static func churchyard(size: Vector2, ground: Callable, seed_value: int) -> StaticBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var body := StaticBody3D.new()
	body.name = "Churchyard"
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.8, 0.8, 0.76))
	var moss := PSXMat.lit("moss_stone")
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	for seg: Array in [[Vector2(-hx, -hz), Vector2(-hx, hz)], [Vector2(-hx, hz), Vector2(hx, hz)], [Vector2(hx, hz), Vector2(hx, -hz)]]:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var n := int(ceil(a.distance_to(b) / 1.5))
		for k in range(n):
			var q := a.lerp(b, (k + 0.5) / n)
			var y: float = ground.call(q.x, q.y)
			var dir := (b - a).normalized()
			var yaw := atan2(dir.x, dir.y)
			mb.add_box(stone, _xf(Vector3(q.x, y + 0.2, q.y), yaw), Vector3(0.4, 1.0, a.distance_to(b) / n + 0.05), 0.6, Color(0.9 + 0.08 * (k % 2), 0.9, 0.88), false)
			_col(body, Vector3(0.4, 1.0, a.distance_to(b) / n), Vector3(q.x, y + 0.2, q.y), yaw)
	for row in range(2):
		for k in range(3):
			var q := Vector2(-hx + 1.4 + k * (size.x - 2.8) / 2.0 + rng.randf_range(-0.2, 0.2), -hz + 1.6 + row * 2.4)
			var y: float = ground.call(q.x, q.y)
			var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.08)) * Basis(Vector3.BACK, rng.randf_range(-0.08, 0.08))
			var ht := rng.randf_range(0.7, 0.95)
			mb.add_box(stone if rng.randf() < 0.6 else moss, Transform3D(tilt, Vector3(q.x, y + ht * 0.5 - 0.1, q.y)), Vector3(0.55, ht, 0.12), 0.8)
			mb.add_cylinder(stone, Transform3D(tilt * Basis(Vector3.RIGHT, PI * 0.5), Vector3(q.x, y + ht - 0.1, q.y - 0.06)), 0.27, 0.27, 0.12, 7, 0.8, Color.WHITE, true, true)
			_col(body, Vector3(0.55, ht + 0.2, 0.2), Vector3(q.x, y + ht * 0.5, q.y))
	var mi := mb.to_instance("Mesh")
	mi.visibility_range_end = 120.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	return body


# --------------------------------------------------------------------------
# Furnishing (into fm, local to the building; returns where the keeper stands)
# --------------------------------------------------------------------------
## Netmaker Hesk's loft: nets hung on the back wall with their floats, a rack of rods, a gutting table with the
## day's catch, a barrel of salt fish and a crate of floats, a hammock slung across the left end.
static func _loft(body: StaticBody3D, fm: MeshBuilder, w: float, d: float, h: float, dx: float, rng: RandomNumberGenerator) -> Vector3:
	var xi := w * 0.5 - T
	var zi := d * 0.5 - T
	var rope := PSXMat.lit("rope", Color(0.85, 0.8, 0.7))
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	# nets: a sagging mesh of cords over the back wall, floats strung along its top
	for k in range(9):
		var x := -xi + 0.5 + k * (xi * 2.0 - 1.0) / 8.0
		fm.add_tube(rope, MeshBuilder.sag_points(Vector3(x, FL + 2.5, -zi + 0.06), Vector3(x + 0.3, FL + 0.9, -zi + 0.1), 0.15, 5), 0.015, -1.0, 3, 1.0)
	for k in range(4):
		var y := FL + 1.0 + k * 0.42
		fm.add_tube(rope, MeshBuilder.sag_points(Vector3(-xi + 0.4, y, -zi + 0.08), Vector3(xi - 0.4, y, -zi + 0.08), 0.12, 9), 0.015, -1.0, 3, 1.0)
	for k in range(7):
		fm.add_blob(PSXMat.flat(Color(0.92, 0.55, 0.18) if k % 2 == 0 else Color(0.88, 0.86, 0.8)), _xf(Vector3(-xi + 0.7 + k * (xi * 2.0 - 1.4) / 6.0, FL + 2.45, -zi + 0.14)), Vector3.ONE * 0.11, rng, 0.1, 2, 5)
	# the rod rack on the right wall: four rods leaning in its cleats
	fm.add_box(dark, _xf(Vector3(xi - 0.08, FL + 1.6, -0.4)), Vector3(0.06, 0.12, 1.6), 1.0)
	for k in range(4):
		var z := -1.0 + k * 0.4
		Buildings.beam_between(fm, PSXMat.lit("bamboo"), Vector3(xi - 0.35, FL + 0.02, z), Vector3(xi - 0.1, FL + 2.6, z + 0.15), 0.025)
		fm.add_cylinder(PSXMat.lit("metal", Color(0.6, 0.6, 0.62)), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(xi - 0.25, FL + 0.7, z + 0.05)), 0.06, 0.06, 0.05, 6, 1.0, Color.WHITE, true, true)
	# the gutting table, a board and the catch on it
	var tc := Vector3(0.9, FL, -0.75)
	fm.add_box(wood, _xf(tc + Vector3(0, 0.86, 0)), Vector3(1.7, 0.08, 0.8), 1.0)
	for sx: float in [-0.75, 0.75]:
		for sz: float in [-0.32, 0.32]:
			fm.add_box(dark, _xf(tc + Vector3(sx, 0.42, sz)), Vector3(0.08, 0.84, 0.08), 1.0)
	_col(body, Vector3(1.7, 0.9, 0.8), tc + Vector3(0, 0.45, 0))
	fm.add_box(PSXMat.lit("planks", Color(0.85, 0.75, 0.6)), _xf(tc + Vector3(-0.3, 0.92, 0.05), 0.2), Vector3(0.6, 0.04, 0.36), 1.0)
	var scale_m := PSXMat.lit("metal", Color(0.55, 0.68, 0.78))
	for k in range(3):
		fm.add_blob(scale_m, _xf(tc + Vector3(0.2 + k * 0.22, 0.95, -0.1 + k * 0.1), 0.4 + k), Vector3(0.07, 0.05, 0.22), rng, 0.08, 2, 6)
	fm.add_box(PSXMat.lit("metal", Color(0.75, 0.75, 0.78)), _xf(tc + Vector3(-0.35, 0.95, 0.05), 0.6), Vector3(0.22, 0.01, 0.04), 1.0)
	# a barrel of salt fish and a crate of floats in the back-right corner
	var bp := Vector3(xi - 0.45, FL, -zi + 0.45)
	fm.add_cylinder(wood, _xf(bp), 0.32, 0.34, 0.85, 8, 1.0, Color.WHITE, true)
	fm.add_cylinder(PSXMat.lit("metal", Color(0.4, 0.38, 0.36)), _xf(bp + Vector3(0, 0.6, 0)), 0.35, 0.35, 0.05, 8, 1.0)
	_col(body, Vector3(0.66, 0.86, 0.66), bp + Vector3(0, 0.43, 0))
	var cp := Vector3(xi - 0.45, FL, -zi + 1.25)
	fm.add_box(wood, _xf(cp + Vector3(0, 0.3, 0), 0.2), Vector3(0.6, 0.6, 0.6), 0.8)
	for k in range(3):
		fm.add_blob(PSXMat.flat(Color(0.92, 0.55, 0.18)), _xf(cp + Vector3(-0.15 + k * 0.15, 0.65, 0.05 * k)), Vector3.ONE * 0.1, rng, 0.1, 2, 5)
	_col(body, Vector3(0.6, 0.6, 0.6), cp + Vector3(0, 0.3, 0), 0.2)
	# a hammock slung across the left end, on hooks in the side walls' corners
	var ha := Vector3(-xi + 0.05, FL + 1.7, -zi + 0.35)
	var hb := Vector3(-xi + 0.05, FL + 1.7, zi - 0.6)
	var hl := MeshBuilder.sag_points(ha + Vector3(0.45, 0, 0), hb + Vector3(0.45, 0, 0), 0.75, 8)
	fm.add_tube(PSXMat.lit("canvas", Color(0.8, 0.72, 0.58)), hl, 0.2, -1.0, 6, 1.0)
	fm.add_tube(rope, PackedVector3Array([ha, hl[0]]), 0.02, -1.0, 3, 1.0)
	fm.add_tube(rope, PackedVector3Array([hb, hl[hl.size() - 1]]), 0.02, -1.0, 3, 1.0)
	# fish drying on a line by the door
	for k in range(4):
		var fp := Vector3(dx + 0.9 + k * 0.28, FL + 2.0, zi - 0.35)
		fm.add_box(rope, _xf(fp + Vector3(0, 0.15, 0)), Vector3(0.01, 0.3, 0.01), 1.0)
		fm.add_blob(scale_m, _xf(fp - Vector3(0, 0.08, 0)), Vector3(0.05, 0.18, 0.03), rng, 0.1, 2, 5)
	return tc + Vector3(0, 0, -0.85)


## Wick's workshop: the gadget Workbench against the back wall under a board of tools, shelves of parts and jars,
## a vice on a stump, a crate of salvage, a great cog leant on the wall, sparks' scorch on the floor.
static func _tinker(body: StaticBody3D, fm: MeshBuilder, w: float, d: float, h: float, dx: float, rng: RandomNumberGenerator) -> Vector3:
	var xi := w * 0.5 - T
	var zi := d * 0.5 - T
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	var metal := PSXMat.lit("metal", Color(0.62, 0.6, 0.58))
	var brass := PSXMat.lit("metal", Color(0.85, 0.66, 0.32))
	var bench_x := -1.0
	Workbench.place(body, Vector3(bench_x, FL, -zi + Workbench.D * 0.5 + 0.05), PI)
	# the tool board over it
	fm.add_box(dark, _xf(Vector3(bench_x, FL + 1.75, -zi + 0.03)), Vector3(1.8, 0.9, 0.04), 1.0)
	for k in range(7):
		var tx := bench_x - 0.75 + k * 0.25
		var long := 0.25 + 0.15 * float(k % 3)
		fm.add_box(metal if k % 2 == 0 else wood, _xf(Vector3(tx, FL + 1.85 - long * 0.3, -zi + 0.07)), Vector3(0.05, long, 0.03), 1.0)
		fm.add_box(metal, _xf(Vector3(tx, FL + 1.85 + long * 0.2, -zi + 0.07)), Vector3(0.14, 0.05, 0.03), 1.0)
	# shelves on the left wall: jars, coils, cogs
	for row in range(3):
		var sy := FL + 0.9 + row * 0.55
		fm.add_box(wood, _xf(Vector3(-xi + 0.2, sy, 0.2)), Vector3(0.36, 0.04, 1.8), 1.0)
		for k in range(5):
			var z := -0.55 + k * 0.38
			match (k + row) % 3:
				0:
					fm.add_cylinder(PSXMat.flat(Color(0.35, 0.5, 0.42)), _xf(Vector3(-xi + 0.2, sy + 0.02, z)), 0.07, 0.07, 0.2, 6, 1.0)
				1:
					fm.add_cylinder(brass, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-xi + 0.15, sy + 0.1, z)), 0.09, 0.09, 0.04, 8, 1.0, Color.WHITE, true, true)
				_:
					fm.add_cylinder(PSXMat.lit("rope", Color(0.8, 0.5, 0.3)), _xf(Vector3(-xi + 0.2, sy + 0.02, z)), 0.09, 0.09, 0.1, 7, 1.0)
	_col(body, Vector3(0.4, 2.0, 1.9), Vector3(-xi + 0.2, FL + 1.0, 0.2))
	for z: float in [-0.75, 1.15]:
		fm.add_box(dark, _xf(Vector3(-xi + 0.2, FL + 1.05, z)), Vector3(0.36, 2.1, 0.05), 1.0)
	# a vice on a stump by the right wall
	var vp := Vector3(xi - 0.6, FL, -0.4)
	fm.add_cylinder(PSXMat.lit("bark"), _xf(vp), 0.3, 0.28, 0.75, 7, 0.8)
	fm.add_box(metal, _xf(vp + Vector3(0, 0.85, 0)), Vector3(0.18, 0.2, 0.3), 1.0)
	Buildings.beam_between(fm, metal, vp + Vector3(0, 0.88, 0.2), vp + Vector3(0, 0.88, 0.45), 0.02)
	_col(body, Vector3(0.6, 0.95, 0.6), vp + Vector3(0, 0.47, 0))
	# a crate of salvage, a great cog against the back wall's right end
	var cp := Vector3(xi - 0.5, FL, -zi + 0.5)
	fm.add_box(wood, _xf(cp + Vector3(0, 0.3, 0), 0.15), Vector3(0.65, 0.6, 0.65), 0.8)
	for k in range(4):
		fm.add_box(metal, _xf(cp + Vector3(rng.randf_range(-0.2, 0.2), 0.63, rng.randf_range(-0.2, 0.2)), rng.randf() * TAU), Vector3(0.18, 0.05, 0.07), 1.0)
	_col(body, Vector3(0.65, 0.65, 0.65), cp + Vector3(0, 0.32, 0), 0.15)
	var gc := Vector3(1.2, FL + 0.62, -zi + 0.12)
	var gb := Basis(Vector3.RIGHT, PI * 0.5 - 0.15)
	fm.add_cylinder(brass, Transform3D(gb, gc), 0.55, 0.55, 0.08, 12, 1.0, Color.WHITE, true, true)
	for k in range(12):
		var a := TAU * k / 12.0
		fm.add_box(brass, Transform3D(gb * Basis(Vector3.UP, a), gc + gb * (Vector3(cos(a), 0, sin(a)) * 0.6) + gb * Vector3(0, 0.04, 0)), Vector3(0.12, 0.08, 0.1), 1.0)
	# scorch on the floor before the bench
	fm.add_quad(PSXMat.flat(Color(0.12, 0.1, 0.09)), Vector3(bench_x - 0.5, FL + 0.012, -zi + 0.9), Vector3(bench_x - 0.5, FL + 0.012, -zi + 1.5),
		Vector3(bench_x + 0.4, FL + 0.012, -zi + 1.5), Vector3(bench_x + 0.4, FL + 0.012, -zi + 0.9), Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color.WHITE, Vector3.UP)
	return Vector3(bench_x + 1.4, FL, -zi + 1.0)


## Brother Aldous's house: shelves of books floor to ceiling on the back wall, a writing desk with a candle, ink and an
## open book, a lectern with the chapel's great book, a chart of the island on the wall, a rack of scrolls.
static func _scribe(body: StaticBody3D, fm: MeshBuilder, w: float, d: float, h: float, dx: float, rng: RandomNumberGenerator) -> Vector3:
	var xi := w * 0.5 - T
	var zi := d * 0.5 - T
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	var spines := [Color(0.55, 0.16, 0.12), Color(0.18, 0.3, 0.45), Color(0.3, 0.42, 0.25), Color(0.5, 0.38, 0.2), Color(0.25, 0.2, 0.18), Color(0.7, 0.6, 0.35)]
	# the shelves: two bays on the back wall
	for bay: float in [-1.15, 1.15]:
		var c := Vector3(bay, FL, -zi + 0.2)
		for s: float in [-1.0, 1.0]:
			fm.add_box(dark, _xf(c + Vector3(s * 0.95, 1.1, 0)), Vector3(0.06, 2.2, 0.38), 1.0)
		for row in range(5):
			var sy := 0.08 + row * 0.44
			fm.add_box(wood, _xf(c + Vector3(0, sy, 0)), Vector3(1.9, 0.04, 0.36), 1.0)
			var x := -0.88
			while x < 0.85:
				var bw := rng.randf_range(0.05, 0.1)
				var bh := rng.randf_range(0.26, 0.36)
				var lean := 0.0 if rng.randf() < 0.85 else 0.25
				fm.add_box(PSXMat.flat(spines[rng.randi() % spines.size()]), Transform3D(Basis(Vector3.BACK, lean), c + Vector3(x + bw * 0.5, sy + 0.02 + bh * 0.5, 0.02)), Vector3(bw, bh, 0.24), 1.0)
				x += bw + 0.01 + (0.12 if rng.randf() < 0.08 else 0.0)
		_col(body, Vector3(1.95, 2.25, 0.4), c + Vector3(0, 1.12, 0))
	# the desk, its stool, what's on it
	var dc := Vector3(xi - 0.75, FL, -0.1)
	fm.add_box(wood, _xf(dc + Vector3(0, 0.78, 0)), Vector3(0.8, 0.06, 1.4), 1.0)
	for sz: float in [-0.62, 0.62]:
		fm.add_box(dark, _xf(dc + Vector3(0, 0.38, sz)), Vector3(0.7, 0.76, 0.06), 1.0)
	_col(body, Vector3(0.8, 0.82, 1.4), dc + Vector3(0, 0.41, 0))
	var paper := PSXMat.flat(Color(0.88, 0.83, 0.68))
	fm.add_box(PSXMat.flat(Color(0.45, 0.2, 0.14)), _xf(dc + Vector3(0, 0.82, 0.1), 0.1), Vector3(0.32, 0.03, 0.44), 1.0)
	fm.add_box(paper, _xf(dc + Vector3(0, 0.84, 0.1), 0.1), Vector3(0.3, 0.012, 0.42), 1.0)
	fm.add_box(paper, _xf(dc + Vector3(0.05, 0.815, -0.4), -0.3), Vector3(0.22, 0.01, 0.3), 1.0)
	fm.add_cylinder(PSXMat.flat(Color(0.1, 0.1, 0.12)), _xf(dc + Vector3(0.15, 0.81, -0.15)), 0.035, 0.03, 0.07, 6, 1.0)
	Buildings.beam_between(fm, PSXMat.flat(Color(0.92, 0.9, 0.85)), dc + Vector3(0.15, 0.86, -0.15), dc + Vector3(0.05, 1.05, -0.2), 0.008)
	fm.add_cylinder(PSXMat.flat(Color(0.93, 0.9, 0.8)), _xf(dc + Vector3(0.2, 0.81, 0.5)), 0.03, 0.025, 0.16, 5, 1.0)
	fm.add_box(PSXMat.glow(Color(1.0, 0.75, 0.35), 3.0), _xf(dc + Vector3(0.2, 1.0, 0.5)), Vector3(0.035, 0.06, 0.035), 1.0)
	fm.add_cylinder(wood, _xf(dc + Vector3(-0.6, 0, 0)), 0.18, 0.16, 0.45, 7, 1.0)
	# the lectern with the great book
	var lc := Vector3(-xi + 0.8, FL, 0.3)
	fm.add_box(dark, _xf(lc + Vector3(0, 0.55, 0)), Vector3(0.12, 1.1, 0.12), 1.0)
	fm.add_box(dark, _xf(lc + Vector3(0, 0.03, 0)), Vector3(0.5, 0.06, 0.5), 1.0)
	var lb := Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -0.4)
	fm.add_box(wood, Transform3D(lb, lc + Vector3(0, 1.12, 0)), Vector3(0.6, 0.05, 0.42), 1.0)
	fm.add_box(paper, Transform3D(lb, lc + Vector3(0, 1.16, 0)), Vector3(0.56, 0.04, 0.38), 1.0)
	_col(body, Vector3(0.5, 1.2, 0.5), lc + Vector3(0, 0.6, 0))
	# the island's chart on the left wall, scrolls racked under it
	fm.add_box(dark, _xf(Vector3(-xi + 0.03, FL + 1.75, -0.9)), Vector3(0.04, 0.8, 1.1), 1.0)
	fm.add_box(paper, _xf(Vector3(-xi + 0.055, FL + 1.75, -0.9)), Vector3(0.02, 0.68, 0.98), 1.0)
	fm.add_blob(PSXMat.flat(Color(0.45, 0.6, 0.35)), _xf(Vector3(-xi + 0.07, FL + 1.72, -0.92)), Vector3(0.01, 0.2, 0.3), rng, 0.3, 2, 6)
	for k in range(6):
		fm.add_cylinder(paper, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-xi + 0.12, FL + 0.95 + (k % 2) * 0.1, -1.3 + k * 0.15)), 0.045, 0.045, 0.36, 6, 1.0, Color.WHITE, true, true)
	return dc + Vector3(-0.55, 0, 0.0)
