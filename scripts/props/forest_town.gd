class_name ForestTown
extends RefCounted
## The lumber town's buildings (ForestTheme.props through KitStyle village_models, item_models): log
## cabins with notched corners under steep shingle roofs and a fieldstone chimney, two-storey
## timber-framed houses with a jettied upper floor, the cooper's open shed, a timber store, a wayside
## shrine of carved wood; and the riverside sawmill with its water wheel, the log flume, log piles,
## a charcoal kiln, a hunter's lodge, fences and woodpiles. Each a StaticBody3D, its origin on the
## ground, its door (Door marker) at +Z, one merged mesh and box colliders.

const VIS := 520.0
const LOG_R := 0.16
## Plaster washes the timber-framed houses take (vertex colour over one plaster material).
const WASHES := [Color(0.95, 0.92, 0.84), Color(0.92, 0.84, 0.66), Color(0.9, 0.8, 0.74), Color(0.86, 0.88, 0.8), Color(0.96, 0.95, 0.92)]


static func _xf(at: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), at)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _window_mat() -> Material:
	return PSXMat.lit("window", Color(0.85, 0.9, 1.0), {"emission": Color(1.0, 0.72, 0.38), "emission_energy": 0.8, "emission_tex": "window"})


static func _finish(body: StaticBody3D, mb: MeshBuilder, vis := VIS) -> StaticBody3D:
	var mi := mb.to_instance()
	mi.visibility_range_end = vis
	body.add_child(mi)
	return body


static func _marker(body: Node3D, marker_name: String, at: Vector3, yaw := 0.0) -> void:
	var m := Marker3D.new()
	m.name = marker_name
	m.position = at
	m.rotation.y = yaw
	body.add_child(m)


## A log along local X from x0 to x1 at height y, z (its ends cut pale).
static func _log_x(mb: MeshBuilder, bark: Material, ends: Material, x0: float, x1: float, y: float, z: float, r := LOG_R, col := Color.WHITE) -> void:
	mb.add_cylinder(bark, Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(x0, y, z)), r, r, x1 - x0, 6, 0.6, col, true, true, true, ends)


static func _log_z(mb: MeshBuilder, bark: Material, ends: Material, z0: float, z1: float, y: float, x: float, r := LOG_R, col := Color.WHITE) -> void:
	mb.add_cylinder(bark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, y, z0)), r, r, z1 - z0, 6, 0.6, col, true, true, true, ends)


## A small window into `mb` on a wall facing `n` (local), lit at night, with a frame, a sill and shutters in `trim`.
static func _window(mb: MeshBuilder, at: Vector3, yaw: float, trim: Material, w := 0.6, h := 0.7) -> void:
	var b := Basis(Vector3.UP, yaw)
	mb.add_box(_window_mat(), Transform3D(b, at), Vector3(w, h, 0.06), 1.0)
	var wood := PSXMat.lit("planks_dark")
	mb.add_box(wood, Transform3D(b, at + b * Vector3(0, -h * 0.5 - 0.05, 0.06)), Vector3(w + 0.2, 0.08, 0.16), 1.0)
	mb.add_box(wood, Transform3D(b, at + b * Vector3(0, h * 0.5 + 0.05, 0.04)), Vector3(w + 0.16, 0.1, 0.1), 1.0)
	for s in [-1.0, 1.0]:
		mb.add_box(trim, Transform3D(b * Basis(Vector3.UP, s * 0.35), at + b * Vector3(s * (w * 0.5 + 0.2), 0, 0.12)), Vector3(w * 0.5, h + 0.06, 0.04), 1.0)


## A door at +Z of a wall at z, its frame and step.
static func _door(mb: MeshBuilder, z: float, y0: float, step_mat: Material) -> void:
	var wood := PSXMat.lit("planks_dark")
	mb.add_box_unit_uv(PSXMat.lit("door", Color(0.8, 0.68, 0.55), {"vertex_color": false}), _xf(Vector3(0, y0 + 1.0, z + 0.02)), Vector3(1.0, 2.0, 0.08))
	for s in [-1.0, 1.0]:
		mb.add_box(wood, _xf(Vector3(s * 0.58, y0 + 1.05, z + 0.05)), Vector3(0.14, 2.15, 0.12), 1.0)
	mb.add_box(wood, _xf(Vector3(0, y0 + 2.15, z + 0.06)), Vector3(1.36, 0.16, 0.14), 1.0)
	mb.add_box(step_mat, _xf(Vector3(0, y0 - 0.1, z + 0.45)), Vector3(1.4, 0.24, 0.8), 0.6, Color(0.85, 0.85, 0.85), true, false)


## A fieldstone chimney up the outside of a wall at local x (the gable end at -x / +x), its top over the ridge, smoke.
static func _chimney(body: Node3D, mb: MeshBuilder, x: float, out: float, top: float, rng: RandomNumberGenerator) -> void:
	var stone := PSXMat.lit("forest_rock", Color(0.95, 0.92, 0.88), {"affine": 0.6})
	var y := -0.3
	var w := 1.1
	while y < top:
		var h := rng.randf_range(0.28, 0.4)
		mb.add_box(stone, _xf(Vector3(x + out * (w * 0.5), y + h * 0.5, 0), rng.randf_range(-0.05, 0.05)), Vector3(w, h, w * 0.9), 0.8, Color.WHITE.darkened(rng.randf() * 0.18))
		y += h
		if y > top * 0.45:
			w = 0.8
	mb.add_box(stone, _xf(Vector3(x + out * 0.4, top + 0.06, 0)), Vector3(0.95, 0.12, 0.85), 0.8, Color(0.8, 0.8, 0.8))
	FX.chimney_smoke(body, Vector3(x + out * 0.4, top + 0.3, 0))
	Props._add_box_col(body, Vector3(1.1, top + 0.3, 1.0), Vector3(x + out * 0.55, (top + 0.3) * 0.5 - 0.3, 0))


## A log cabin `w` across (+Z its front, w * 0.8 deep): logs laid in courses notched at the corners and
## running past them, a steep shingle gable roof with a ridge board, planked gables, a fieldstone chimney
## on one end, small shuttered windows, a plank door, a woodpile and a chopping block by the wall, a
## fieldstone footing down into the ground. `storeys` 2 lifts a loft under the roof with a window in the gable.
static func log_cabin(seed_value: int, w: float, storeys := 1) -> Node3D:
	var rng := _rng(seed_value)
	var body := Props._body("LogCabin")
	var mb := MeshBuilder.new()
	var bark := PSXMat.lit("bark", Color(0.86, 0.72, 0.58))
	var ends := PSXMat.flat(Color(0.78, 0.62, 0.42))
	var stone := PSXMat.lit("forest_rock", Color.WHITE, {"affine": 0.6})
	var shingles := PSXMat.lit("shingles", Color.WHITE, {"affine": 0.7})
	var gable := PSXMat.lit("planks_dark")
	var trims := [Color(0.55, 0.16, 0.12), Color(0.22, 0.36, 0.24), Color(0.72, 0.52, 0.2), Color(0.86, 0.82, 0.72)]
	var trim := PSXMat.lit("planks", trims[rng.randi() % trims.size()])
	w = clampf(w, 4.4, 7.5)
	var d := snappedf(w * rng.randf_range(0.74, 0.86), 0.1)
	var hx := w * 0.5
	var hz := d * 0.5
	var courses := 8 + (storeys - 1) * 3
	var ch := LOG_R * 1.9
	var wall_h := courses * ch + 0.25
	mb.add_box(stone, _xf(Vector3(0, -0.45, 0)), Vector3(w + 0.3, 1.3, d + 0.3), 0.6, Color(0.85, 0.85, 0.85), true, false)
	var over := 0.32
	for i in range(courses):
		var y := 0.25 + LOG_R + i * ch
		var tint := Color.WHITE.darkened(rng.randf() * 0.14)
		# alternate courses run long past the corners, the front's broken by the door
		if i % 2 == 0:
			for z in [-hz, hz]:
				if z > 0.0 and y < 2.35:
					_log_x(mb, bark, ends, -hx - over, -0.65, y, z, LOG_R, tint)
					_log_x(mb, bark, ends, 0.65, hx + over, y, z, LOG_R, tint)
				else:
					_log_x(mb, bark, ends, -hx - over, hx + over, y, z, LOG_R, tint)
			for x in [-hx, hx]:
				_log_z(mb, bark, ends, -hz + LOG_R, hz - LOG_R, y + ch * 0.5, x, LOG_R, tint)
		else:
			for x in [-hx, hx]:
				_log_z(mb, bark, ends, -hz - over, hz + over, y, x, LOG_R, tint)
			for z in [-hz, hz]:
				if z > 0.0 and y < 2.35:
					_log_x(mb, bark, ends, -hx + LOG_R, -0.65, y + ch * 0.5, z, LOG_R, tint)
					_log_x(mb, bark, ends, 0.65, hx - LOG_R, y + ch * 0.5, z, LOG_R, tint)
				else:
					_log_x(mb, bark, ends, -hx + LOG_R, hx - LOG_R, y + ch * 0.5, z, LOG_R, tint)
	# the chinking behind the logs (so no light shows through)
	mb.add_box(PSXMat.lit("plaster_wash", Color(0.62, 0.56, 0.46)), _xf(Vector3(0, wall_h * 0.5 + 0.1, 0)), Vector3(w - 0.12, wall_h - 0.2, d - 0.12), 0.5, Color.WHITE, true, true)
	_door(mb, hz + LOG_R, 0.25, stone)
	for side in [[Vector3(-hx - LOG_R - 0.02, 1.45, -hz * 0.3), -PI * 0.5], [Vector3(hx + LOG_R + 0.02, 1.45, hz * 0.25), PI * 0.5], [Vector3(-hx * 0.55, 1.45, hz + LOG_R + 0.02), 0.0],
			[Vector3(hx * 0.55, 1.45, hz + LOG_R + 0.02), 0.0], [Vector3(0, 1.45, -hz - LOG_R - 0.02), PI]]:
		if rng.randf() < 0.75:
			_window(mb, side[0], side[1], trim)
	# the roof: steep, its ridge along X, planked gables at either end
	var pitch := rng.randf_range(0.95, 1.2)
	var rh := hz * pitch + 0.2
	var roof_y := wall_h + 0.05
	mb.add_gable_roof(shingles, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, roof_y, 0)), d + 0.1, w + 0.1, rh, 0.55, 0.7, Color.WHITE, gable)
	mb.add_box(gable, _xf(Vector3(0, roof_y + rh + 0.06, 0)), Vector3(w + 1.25, 0.12, 0.22), 0.8)
	if storeys > 1:
		_window(mb, Vector3(hx + 0.08, roof_y + rh * 0.4, 0), PI * 0.5, trim, 0.55, 0.6)
	# the chimney up the far gable
	var cx := -hx - LOG_R if rng.randf() < 0.5 else hx + LOG_R
	_chimney(body, mb, cx, signf(cx), roof_y + rh + 0.9, rng)
	# the porch roof over the door now and then, on two posts
	if rng.randf() < 0.55:
		var post := PSXMat.lit("bark", Color(0.8, 0.66, 0.52))
		for s in [-1.0, 1.0]:
			mb.add_cylinder(post, _xf(Vector3(s * 1.0, 0.2, hz + 1.5)), 0.09, 0.08, 2.4, 6, 0.8)
		Buildings.add_shed_roof(mb, shingles, gable, _xf(Vector3(0, 2.55, hz + 0.85)), 2.6, 1.6, 0.35, 0.3)
		Props._add_box_col(body, Vector3(0.2, 2.4, 0.2), Vector3(-1.0, 1.4, hz + 1.5))
		Props._add_box_col(body, Vector3(0.2, 2.4, 0.2), Vector3(1.0, 1.4, hz + 1.5))
	# a woodpile against a side wall under a little lean-to, a chopping block with the axe in it
	var wx := -cx
	var wz := rng.randf_range(-hz * 0.4, hz * 0.2)
	var wp := Vector3(wx + signf(wx) * 0.5, 0.0, wz)
	for row in range(4):
		for k in range(5 - row % 2):
			var z := wz - 0.9 + k * 0.38 + (row % 2) * 0.19
			mb.add_cylinder(bark, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(wp.x - 0.35, 0.12 + row * 0.24, z)), 0.11, 0.11, 0.7, 6, 1.0, Color.WHITE.darkened(rng.randf() * 0.2), true, true, true, ends)
	Props._add_box_col(body, Vector3(0.8, 1.0, 2.0), wp + Vector3(0, 0.5, 0.0))
	var blk := Vector3(wx + signf(wx) * 1.6, 0.0, hz + 1.0)
	mb.add_cylinder(bark, _xf(blk), 0.3, 0.32, 0.5, 7, 1.0, Color.WHITE, true, false, true, ends)
	mb.add_box(PSXMat.lit("metal", Color(0.4, 0.4, 0.42)), Transform3D(Basis(Vector3.BACK, 0.5), blk + Vector3(0.05, 0.56, 0)), Vector3(0.22, 0.12, 0.04), 1.0)
	mb.add_box(PSXMat.lit("planks"), Transform3D(Basis(Vector3.BACK, 0.5), blk + Vector3(0.28, 0.82, 0)), Vector3(0.05, 0.6, 0.05), 1.0)
	Props._add_box_col(body, Vector3(w + 0.4, wall_h + 0.4, d + 0.4), Vector3(0, (wall_h + 0.4) * 0.5 - 0.3, 0))
	Props._add_box_col(body, Vector3(w + 0.6, rh * 0.8, d * 0.7), Vector3(0, roof_y + rh * 0.4, 0))
	_marker(body, "Door", Vector3(0, 0.25, hz + 1.0))
	return _finish(body, mb)


## A timber-framed house `w` across, two storeys: a fieldstone ground floor (or plaster), the upper floor
## jettied out over it, plaster panels between dark posts, rails and braces, a steep shingle roof with its
## gable to the street (+Z), the gable framed too; lit windows, a flower box, a plank door.
static func timber_house(seed_value: int, w: float) -> Node3D:
	var rng := _rng(seed_value)
	var body := Props._body("TimberHouse")
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("forest_rock", Color.WHITE, {"affine": 0.6})
	var plaster := PSXMat.lit("plaster_wash")
	var beam := PSXMat.lit("planks_dark", Color(0.62, 0.52, 0.44))
	var shingles := PSXMat.lit("shingles", Color.WHITE, {"affine": 0.7})
	var trims := [Color(0.55, 0.16, 0.12), Color(0.22, 0.36, 0.24), Color(0.72, 0.52, 0.2), Color(0.3, 0.32, 0.46)]
	var trim := PSXMat.lit("planks", trims[rng.randi() % trims.size()])
	var wash: Color = WASHES[rng.randi() % WASHES.size()]
	w = clampf(w, 4.8, 7.0)
	var d := snappedf(w * rng.randf_range(0.85, 1.0), 0.1)
	var h1 := 2.6
	var h2 := 2.4
	var jet := 0.35
	var hx := w * 0.5
	var hz := d * 0.5
	var stone_ground := rng.randf() < 0.55
	mb.add_box(stone, _xf(Vector3(0, -0.45, 0)), Vector3(w + 0.2, 1.1, d + 0.2), 0.6, Color(0.85, 0.85, 0.85), true, false)
	if stone_ground:
		mb.add_box(stone, _xf(Vector3(0, h1 * 0.5 + 0.05, 0)), Vector3(w, h1 - 0.1, d), 0.6, Color(0.92, 0.92, 0.9))
	else:
		mb.add_box(plaster, _xf(Vector3(0, h1 * 0.5 + 0.05, 0)), Vector3(w, h1 - 0.1, d), 0.5, wash)
	# the upper floor out over it on the jetty
	var ux := hx + jet
	var uz := hz + jet
	var y2 := h1
	mb.add_box(beam, _xf(Vector3(0, y2 + 0.08, 0)), Vector3(w + jet * 2.0 + 0.1, 0.18, d + jet * 2.0 + 0.1), 0.8)
	for k in range(int(w / 0.5) + 1):
		var x := -hx + k * (w / int(w / 0.5))
		mb.add_box(beam, _xf(Vector3(x, y2 - 0.06, hz + jet * 0.5)), Vector3(0.12, 0.12, jet + 0.1), 1.0)
	mb.add_box(plaster, _xf(Vector3(0, y2 + 0.15 + h2 * 0.5, 0)), Vector3(ux * 2.0, h2, uz * 2.0), 0.5, wash)
	# its frame: corner posts, a middle rail, studs, braces at the corners, on the front and the sides
	var fy0 := y2 + 0.17
	var fy1 := y2 + 0.15 + h2
	for face in [[Vector3(0, 0, uz + 0.04), 0.0, ux], [Vector3(0, 0, -uz - 0.04), PI, ux], [Vector3(ux + 0.04, 0, 0), PI * 0.5, uz], [Vector3(-ux - 0.04, 0, 0), -PI * 0.5, uz]]:
		var b := Basis(Vector3.UP, float(face[1]))
		var o: Vector3 = face[0]
		var half: float = face[2]
		for y in [fy0 + 0.06, fy1 - 0.06, (fy0 + fy1) * 0.5]:
			mb.add_box(beam, Transform3D(b, o + Vector3.UP * y), Vector3(half * 2.0, 0.14, 0.06), 1.0)
		var n := maxi(2, int(half * 2.0 / 1.1))
		for k in range(n + 1):
			var x := -half + half * 2.0 * k / n
			mb.add_box(beam, Transform3D(b, o + b * Vector3(x, 0, 0) + Vector3.UP * (fy0 + fy1) * 0.5), Vector3(0.14, fy1 - fy0, 0.06), 1.0)
		for s in [-1.0, 1.0]:
			var a := o + b * Vector3(s * half, 0, 0) + Vector3.UP * fy0
			var c := o + b * Vector3(s * (half - 1.0), 0, 0) + Vector3.UP * ((fy0 + fy1) * 0.5)
			Buildings.beam_between(mb, beam, a, c, 0.06)
	# a plastered ground floor is framed too: posts at the corners and beside the door, a sill beam
	if not stone_ground:
		for x in [-hx, -0.75, 0.75, hx]:
			mb.add_box(beam, _xf(Vector3(x, h1 * 0.5 + 0.05, hz + 0.03)), Vector3(0.14, h1 - 0.1, 0.06), 1.0)
		for x in [-hx, hx]:
			mb.add_box(beam, _xf(Vector3(x, h1 * 0.5 + 0.05, -hz - 0.03)), Vector3(0.14, h1 - 0.1, 0.06), 1.0)
		mb.add_box(beam, _xf(Vector3(0, 0.12, hz + 0.04)), Vector3(w, 0.16, 0.08), 1.0)
	# windows: two up front, one each side up, the ground floor's either side of the door
	for x in [-ux * 0.5, ux * 0.5]:
		_window(mb, Vector3(x, y2 + 1.35, uz + 0.06), 0.0, trim, 0.6, 0.75)
		mb.add_box(PSXMat.lit("planks", Color(0.5, 0.36, 0.22)), _xf(Vector3(x, y2 + 0.82, uz + 0.25)), Vector3(0.8, 0.18, 0.24), 1.0)
		var fl := PSXMat.flat([Color(0.85, 0.2, 0.15), Color(0.95, 0.7, 0.2), Color(0.9, 0.85, 0.75)][rng.randi() % 3])
		for k in range(4):
			mb.add_blob(fl, _xf(Vector3(x - 0.3 + k * 0.2, y2 + 0.98, uz + 0.25)), Vector3(0.1, 0.08, 0.1), rng, 0.2, 2, 5)
	for s in [-1.0, 1.0]:
		_window(mb, Vector3(s * (ux + 0.06), y2 + 1.35, 0), s * PI * 0.5, trim, 0.55, 0.7)
		_window(mb, Vector3(s * hx * 0.55, 1.45, hz + 0.04), 0.0, trim, 0.55, 0.65)
	_door(mb, hz, 0.0, stone)
	# the roof: steep, ridge front to back so the gable faces the street; its gable framed
	var pitch := rng.randf_range(1.0, 1.25)
	var rh := ux * pitch
	var ry := y2 + 0.15 + h2
	mb.add_gable_roof(shingles, _xf(Vector3(0, ry, 0)), ux * 2.0 + 0.05, uz * 2.0, rh, 0.5, 0.7, Color.WHITE, plaster)
	mb.add_box(beam, Transform3D(Basis(), Vector3(0, ry + rh + 0.05, 0)), Vector3(0.2, 0.12, uz * 2.0 + 1.1), 0.8)
	for zs in [-1.0, 1.0]:
		var z: float = zs * (uz + 0.05)
		Buildings.beam_between(mb, beam, Vector3(-ux, ry, z), Vector3(0, ry + rh, z), 0.07)
		Buildings.beam_between(mb, beam, Vector3(ux, ry, z), Vector3(0, ry + rh, z), 0.07)
		mb.add_box(beam, _xf(Vector3(0, ry + rh * 0.5, z)), Vector3(0.12, rh, 0.06), 1.0)
		mb.add_box(beam, _xf(Vector3(0, ry + rh * 0.35, z)), Vector3(ux * 1.3, 0.12, 0.06), 1.0)
	_window(mb, Vector3(0, ry + rh * 0.45, uz + 0.1), 0.0, trim, 0.45, 0.5)
	var cx := hx * 0.45 * (1.0 if rng.randf() < 0.5 else -1.0)
	var stone_c := PSXMat.lit("forest_rock", Color(0.95, 0.92, 0.88), {"affine": 0.6})
	mb.add_box(stone_c, _xf(Vector3(cx, ry + rh * 0.6, -uz * 0.4)), Vector3(0.7, rh * 1.2, 0.7), 0.8)
	FX.chimney_smoke(body, Vector3(cx, ry + rh * 1.2 + 0.2, -uz * 0.4))
	Props._add_box_col(body, Vector3(w + 0.2, h1 + 0.5, d + 0.2), Vector3(0, (h1 + 0.5) * 0.5 - 0.3, 0))
	Props._add_box_col(body, Vector3(ux * 2.0, h2 + 0.2, uz * 2.0), Vector3(0, y2 + h2 * 0.5 + 0.1, 0))
	Props._add_box_col(body, Vector3(ux * 1.6, rh * 0.8, uz * 2.0), Vector3(0, ry + rh * 0.4, 0))
	_marker(body, "Door", Vector3(0, 0.0, hz + 0.9))
	return _finish(body, mb)
