class_name Buildings
extends RefCounted
## Village architecture: a configurable house builder (so no two houses on an
## island look alike), an enterable tavern with a furnished interior, and
## market stalls of different kinds. Same conventions as Props: origin at
## ground level, the front (door / customer side) faces +Z.

const WORLD_LAYER := 1


static func _xf(pos: Vector3, rot_y: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y), pos)


static func _box_col(body: Node3D, size: Vector3, pos: Vector3, rot_y: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	cs.rotation.y = rot_y
	body.add_child(cs)


## Box split into pieces no larger than `seg` along X and Z (and Y), so the
## PS1 affine texture warp stays small on big walls and floors.
static func tiled_box(mb: MeshBuilder, mat: Material, center: Vector3, size: Vector3, seg: float = 2.4,
		uv: float = 0.5, skip_bottom: bool = true, skip_top: bool = false) -> void:
	var nx := maxi(int(ceil(size.x / seg)), 1)
	var ny := maxi(int(ceil(size.y / seg)), 1)
	var nz := maxi(int(ceil(size.z / seg)), 1)
	var piece := Vector3(size.x / nx, size.y / ny, size.z / nz)
	for ix in range(nx):
		for iy in range(ny):
			for iz in range(nz):
				var c := center - size * 0.5 + Vector3((ix + 0.5) * piece.x, (iy + 0.5) * piece.y, (iz + 0.5) * piece.z)
				mb.add_box(mat, _xf(c), piece, uv, Color.WHITE, skip_bottom or iy > 0, skip_top or iy < ny - 1)


static func _marker(parent: Node3D, n: String, pos: Vector3, yaw: float = 0.0) -> void:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	m.rotation.y = yaw
	parent.add_child(m)


# ==========================================================================
# Roof helpers
# ==========================================================================
## Hip roof over w (X) x d (Z): a ridge along the longer side, four slopes.
static func add_hip_roof(mb: MeshBuilder, mat: Material, xf: Transform3D, w: float, d: float, h: float, over: float = 0.45) -> void:
	var hw := w * 0.5 + over
	var hd := d * 0.5 + over
	var along_x := w >= d
	var r := (hw - hd) if along_x else (hd - hw)
	r = maxf(r, 0.0)
	var c := [xf * Vector3(-hw, 0, -hd), xf * Vector3(hw, 0, -hd), xf * Vector3(hw, 0, hd), xf * Vector3(-hw, 0, hd)]
	var ra := xf * (Vector3(-r, h, 0) if along_x else Vector3(0, h, -r))
	var rb := xf * (Vector3(r, h, 0) if along_x else Vector3(0, h, r))
	var top := xf * Vector3(0, h, 0)
	var up := (xf.basis * Vector3.UP).normalized()
	var faces: Array
	if along_x:
		faces = [[c[0], c[1], rb, ra], [c[2], c[3], ra, rb], [c[1], c[2], rb], [c[3], c[0], ra]]
	else:
		faces = [[c[1], c[2], rb, ra], [c[3], c[0], ra, rb], [c[0], c[1], ra], [c[2], c[3], rb]]
	for f in faces:
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var mid := (a + b) * 0.5
		var out := mid - top
		out -= up * out.dot(up)
		var n := (out.normalized() * h + up * maxf(hw, hd) * 0.8).normalized()
		var L := a.distance_to(b) * 0.5
		if f.size() == 4:
			mb.add_quad(mat, a, b, f[2], f[3], Vector2(0, 2), Vector2(L, 2), Vector2(L * 0.75, 0), Vector2(L * 0.25, 0), Color.WHITE, n)
		else:
			mb.add_tri(mat, a, b, f[2], n, n, n, Vector2(0, 2), Vector2(L, 2), Vector2(L * 0.5, 0), Color.WHITE, n)
		# underside of the eaves
		if f.size() == 4:
			mb.add_quad(mat, a, f[3], f[2], b, Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color(0.55, 0.55, 0.55), -n)
		else:
			mb.add_tri(mat, a, f[2], b, -n, -n, -n, Vector2.ZERO, Vector2(0, 1), Vector2(1, 0), Color(0.55, 0.55, 0.55), -n)


## Single-slope (shed) roof, high at the back (-Z), low at the front (+Z).
static func add_shed_roof(mb: MeshBuilder, mat: Material, wall_mat: Material, xf: Transform3D, w: float, d: float, rise: float, over: float = 0.4) -> void:
	var hw := w * 0.5 + over
	var hd := d * 0.5 + over
	var drop := rise * over / d
	var a := xf * Vector3(-hw, rise + drop, -hd)
	var b := xf * Vector3(hw, rise + drop, -hd)
	var c := xf * Vector3(hw, -drop, hd)
	var e := xf * Vector3(-hw, -drop, hd)
	var n := (xf.basis * Vector3(0, d, rise)).normalized()
	mb.add_quad(mat, e, c, b, a, Vector2(0, 2.5), Vector2(w * 0.5, 2.5), Vector2(w * 0.5, 0), Vector2(0, 0), Color.WHITE, n)
	mb.add_quad(mat, e, a, b, c, Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color(0.55, 0.55, 0.55), -n)
	# wall triangles on the sides under the slope
	for s in [-1.0, 1.0]:
		var x: float = s * w * 0.5
		var t0 := xf * Vector3(x, 0, -d * 0.5)
		var t1 := xf * Vector3(x, 0, d * 0.5)
		var t2 := xf * Vector3(x, rise, -d * 0.5)
		var sn := (xf.basis * Vector3(s, 0, 0)).normalized()
		mb.add_tri(wall_mat, t0, t1, t2, sn, sn, sn, Vector2(0, rise * 0.5), Vector2(d * 0.5, rise * 0.5), Vector2(0, 0), Color.WHITE, sn)


# ==========================================================================
# House
# ==========================================================================
## A house from a spec, all optional:
##   w, d             footprint (default 6 x 5)
##   h                ground-floor wall height (2.6)
##   floors           1 or 2; h2 upper height (2.3); jetty upper overhang (0.35)
##   wall, wall2      textures (ground / upper floor); timber framing on plaster
##   roof             "gable" (ridge along X), "gable_front" (gable faces the
##                    street), "hip", "shed"; roof_tex; pitch (rise / span)
##   porch            covered porch depth along the front (0 = none)
##   lean_to          side shed: "left" / "right"
##   chimney          true / false; stilts height (raised on posts + steps)
##   door_x           door offset along the front; sign texture name
##   foundation       how far the stone base reaches below ground (slopes)
static func house(spec: Dictionary = {}) -> Node3D:
	var w: float = spec.get("w", 6.0)
	var d: float = spec.get("d", 5.0)
	var h: float = spec.get("h", 2.6)
	var floors: int = spec.get("floors", 1)
	var h2: float = spec.get("h2", 2.3)
	var jetty: float = spec.get("jetty", 0.35) if floors > 1 else 0.0
	var stilts: float = spec.get("stilts", 0.0)
	var found: float = spec.get("foundation", 1.4)
	var roof_kind: String = spec.get("roof", "gable")
	var door_x: float = spec.get("door_x", 0.0)
	var wall := PSXMat.lit(spec.get("wall", "planks"))
	var wall2 := PSXMat.lit(spec.get("wall2", spec.get("wall", "planks")))
	var roof := PSXMat.lit(spec.get("roof_tex", "thatch"), Color.WHITE, {"affine": 0.8})
	var beam := PSXMat.lit("planks_dark")
	var stone := PSXMat.lit("stone_brick")
	var door := PSXMat.lit("door", Color.WHITE, {"vertex_color": false})
	var window := PSXMat.lit("window", Color.WHITE, {"emission": Color(0.9, 0.7, 0.35), "emission_energy": 0.6, "emission_tex": "window"})
	var body := StaticBody3D.new()
	body.name = str(spec.get("name", "House"))
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var mb := MeshBuilder.new()

	# base: stone footing down into the slope, or posts for stilts
	var fl := 0.3 + stilts
	if stilts > 0.0:
		for x in [-w * 0.5 + 0.25, 0.0, w * 0.5 - 0.25]:
			for z in [-d * 0.5 + 0.25, d * 0.5 - 0.25]:
				mb.add_box(beam, _xf(Vector3(x, (fl - found) * 0.5, z)), Vector3(0.24, fl + found, 0.24), 0.6)
		mb.add_box(PSXMat.lit("planks"), _xf(Vector3(0, fl - 0.1, 0)), Vector3(w + 0.3, 0.2, d + 0.3), 0.5, Color.WHITE, false, false)
		# steps up to the door
		var n_steps := int(ceil(fl / 0.3))
		for i in range(n_steps):
			var sy := fl - (i + 1) * (fl / n_steps)
			mb.add_box(beam, _xf(Vector3(door_x, sy + 0.05, d * 0.5 + 0.35 + i * 0.32)), Vector3(1.2, 0.1, 0.32), 0.6, Color.WHITE, false)
	else:
		mb.add_box(stone, _xf(Vector3(0, (0.3 - found) * 0.5, 0)), Vector3(w + 0.3, 0.3 + found, d + 0.3), 0.5, Color.WHITE, true, false)
		mb.add_box(stone, _xf(Vector3(door_x, 0.15, d * 0.5 + 0.35)), Vector3(1.4, 0.3, 0.7), 0.6, Color.WHITE, true, false)

	# ground floor
	tiled_box(mb, wall, Vector3(0, fl + h * 0.5, 0), Vector3(w, h, d), 3.2, 0.5, true, floors == 1 and roof_kind == "shed")
	for x in [-1, 1]:
		for z in [-1, 1]:
			mb.add_box(beam, _xf(Vector3(x * w * 0.5, fl + h * 0.5, z * d * 0.5)), Vector3(0.22, h, 0.22), 0.6)
	mb.add_box(beam, _xf(Vector3(0, fl + h, 0)), Vector3(w + 0.1, 0.18, d + 0.1), 0.6)
	mb.add_box_unit_uv(door, _xf(Vector3(door_x, fl + 1.0, d * 0.5 + 0.03)), Vector3(1.0, 2.0, 0.06))
	var nwin := maxi(int(w / 2.6), 1)
	for i in range(nwin + 1):
		var x := -w * 0.5 + w * (i + 0.5) / (nwin + 1)
		if absf(x - door_x) < 1.0:
			continue
		mb.add_box_unit_uv(window, _xf(Vector3(x, fl + 1.5, d * 0.5 + 0.03)), Vector3(0.7, 0.7, 0.06))
	for s in [-1.0, 1.0]:
		mb.add_box_unit_uv(window, _xf(Vector3(s * (w * 0.5 + 0.03), fl + 1.5, 0), PI * 0.5), Vector3(0.7, 0.7, 0.06))
	mb.add_box_unit_uv(window, _xf(Vector3(w * 0.2, fl + 1.5, -d * 0.5 - 0.03)), Vector3(0.7, 0.7, 0.06))

	# upper storey (jettied out over the street, timber framed)
	var top := fl + h
	var uw := w
	var ud := d
	if floors > 1:
		uw = w + jetty * 2.0
		ud = d + jetty * 2.0
		tiled_box(mb, wall2, Vector3(0, top + h2 * 0.5 + 0.1, 0), Vector3(uw, h2, ud), 3.2, 0.5, false, roof_kind == "shed")
		for x in [-uw * 0.5, -uw * 0.17, uw * 0.17, uw * 0.5]:
			mb.add_box(beam, _xf(Vector3(x, top + h2 * 0.5 + 0.1, ud * 0.5)), Vector3(0.2, h2, 0.2), 0.6)
			mb.add_box(beam, _xf(Vector3(x, top + h2 * 0.5 + 0.1, -ud * 0.5)), Vector3(0.2, h2, 0.2), 0.6)
		mb.add_box(beam, _xf(Vector3(0, top + h2 + 0.1, 0)), Vector3(uw + 0.1, 0.18, ud + 0.1), 0.6)
		# diagonal braces on the front
		for s in [-1.0, 1.0]:
			var bx: float = s * uw * 0.34
			mb.add_box(beam, Transform3D(Basis(Vector3.BACK, s * 0.75), Vector3(bx, top + h2 * 0.5 + 0.1, ud * 0.5 + 0.02)), Vector3(0.14, h2 * 1.05, 0.08), 0.6)
		var nw2 := maxi(int(uw / 2.2), 1)
		for i in range(nw2):
			var x := -uw * 0.5 + uw * (i + 0.5) / nw2
			mb.add_box_unit_uv(window, _xf(Vector3(x, top + h2 * 0.55 + 0.1, ud * 0.5 + 0.04)), Vector3(0.65, 0.65, 0.06))
		# brackets under the jetty
		for x in [-w * 0.5 + 0.3, w * 0.5 - 0.3]:
			mb.add_box(beam, Transform3D(Basis(Vector3.RIGHT, 0.7), Vector3(x, top - 0.15, d * 0.5 + jetty * 0.5)), Vector3(0.12, 0.12, 0.6), 0.6)
		top += h2 + 0.1

	# roof
	var pitch: float = spec.get("pitch", 0.45)
	match roof_kind:
		"gable_front":
			mb.add_gable_roof(roof, _xf(Vector3(0, top + 0.09, 0)), uw, ud, uw * pitch, 0.5, 0.5, Color.WHITE, wall2)
		"hip":
			add_hip_roof(mb, roof, _xf(Vector3(0, top + 0.09, 0)), uw, ud, minf(uw, ud) * pitch)
		"shed":
			add_shed_roof(mb, roof, wall2, _xf(Vector3(0, top, 0)), uw, ud, ud * pitch * 0.6)
		_:
			mb.add_gable_roof(roof, _xf(Vector3(0, top + 0.09, 0), PI * 0.5), ud, uw, ud * pitch, 0.5, 0.5, Color.WHITE, wall2)

	if spec.get("chimney", false):
		var cx := -uw * 0.3
		mb.add_box(stone, _xf(Vector3(cx, top + 0.9, -ud * 0.15)), Vector3(0.7, 2.6, 0.7), 0.6, Color.WHITE, true, false)

	# covered porch along the front
	var porch: float = spec.get("porch", 0.0)
	if porch > 0.0:
		var pz := d * 0.5 + porch
		mb.add_box(PSXMat.lit("planks"), _xf(Vector3(0, fl - 0.08, d * 0.5 + porch * 0.5)), Vector3(w, 0.16, porch), 0.5, Color.WHITE, false, false)
		for x in [-w * 0.5 + 0.15, w * 0.5 - 0.15]:
			mb.add_box(beam, _xf(Vector3(x, fl + h * 0.45 - (0.3 + stilts) * 0.5, pz - 0.1)), Vector3(0.16, h * 0.9 + 0.3 + stilts, 0.16), 0.6)
		var porch_roof_y := fl + h * 0.9
		mb.add_quad(roof, Vector3(-w * 0.5 - 0.2, fl + h - 0.05, d * 0.5), Vector3(w * 0.5 + 0.2, fl + h - 0.05, d * 0.5),
			Vector3(w * 0.5 + 0.2, porch_roof_y - 0.2, pz + 0.3), Vector3(-w * 0.5 - 0.2, porch_roof_y - 0.2, pz + 0.3),
			Vector2(0, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, 1), Vector2(0, 1), Color.WHITE, Vector3(0, 1, 0.3).normalized())
		mb.add_quad(roof, Vector3(-w * 0.5 - 0.2, fl + h - 0.05, d * 0.5), Vector3(-w * 0.5 - 0.2, porch_roof_y - 0.2, pz + 0.3),
			Vector3(w * 0.5 + 0.2, porch_roof_y - 0.2, pz + 0.3), Vector3(w * 0.5 + 0.2, fl + h - 0.05, d * 0.5),
			Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color(0.55, 0.55, 0.55), Vector3(0, -1, -0.3).normalized())

	# lean-to shed on one side
	var lean: String = spec.get("lean_to", "")
	if lean != "":
		var s := -1.0 if lean == "left" else 1.0
		var lw := 2.2
		var lx := s * (w * 0.5 + lw * 0.5)
		var lh := h * 0.75
		mb.add_box(PSXMat.lit("planks_weathered"), _xf(Vector3(lx, fl + lh * 0.5 - 0.15, 0)), Vector3(lw, lh, d * 0.8), 0.5, Color.WHITE, true, true)
		var rx := _xf(Vector3(lx, fl + lh - 0.15, 0), -s * PI * 0.5)
		add_shed_roof(mb, roof, PSXMat.lit("planks_weathered"), rx, d * 0.8, lw, 0.6, 0.3)
		mb.add_box(stone, _xf(Vector3(lx, (0.3 - found) * 0.5 + stilts * 0.5, 0)), Vector3(lw + 0.2, 0.3 + found + stilts, d * 0.8 + 0.2), 0.5, Color.WHITE, true, false)
		_box_col(body, Vector3(lw, lh + 0.3, d * 0.8), Vector3(lx, (fl + lh) * 0.5, 0))

	var sign_tex: String = spec.get("sign", "")
	if sign_tex != "":
		var sign_m := PSXMat.lit(sign_tex, Color.WHITE, {"vertex_color": false})
		mb.add_box(beam, _xf(Vector3(w * 0.5 - 0.2, fl + h - 0.2, d * 0.5 + 0.55)), Vector3(0.08, 0.08, 1.1), 1.0)
		mb.add_box_unit_uv(sign_m, _xf(Vector3(w * 0.5 - 0.2, fl + h - 0.65, d * 0.5 + 0.9), PI * 0.5), Vector3(1.0, 0.5, 0.06))

	body.add_child(mb.to_instance())
	_box_col(body, Vector3(w + 0.3, fl + h + found, d + 0.3), Vector3(0, (fl + h - found) * 0.5, 0))
	if floors > 1:
		_box_col(body, Vector3(uw, h2, ud), Vector3(0, fl + h + h2 * 0.5 + 0.1, 0))
	return body


# ==========================================================================
# Tavern (enterable)
# ==========================================================================
## Two-storey tavern you can walk into: doorway on the front (+Z), common
## room with a bar, shelves of bottles, kegs, tables and a fireplace. Markers:
## "Barkeep" (behind the bar), "Patron1".."Patron3" (seats, facing their
## table), "Door" (just outside the entrance).
static func tavern_hall() -> Node3D:
	var w := 12.0
	var d := 9.0
	var t := 0.3          # wall thickness
	var fl := 0.3         # floor level
	var h1 := 3.6         # ground floor (room) height
	var h2 := 2.6
	var jetty := 0.4
	var door_w := 1.8
	var door_h := 2.6
	var door_x := -1.6
	var body := StaticBody3D.new()
	body.name = "Tavern"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	var plaster := PSXMat.lit("plaster")
	var stone := PSXMat.lit("stone_brick")
	var beam := PSXMat.lit("planks_dark")
	var planks := PSXMat.lit("planks")
	var roof := PSXMat.lit("roof_tiles", Color.WHITE, {"affine": 0.8})
	var window := PSXMat.lit("window", Color.WHITE, {"emission": Color(1.0, 0.75, 0.35), "emission_energy": 1.0, "emission_tex": "window"})
	var sign_m := PSXMat.lit("sign_tavern", Color.WHITE, {"vertex_color": false})

	# floor + footing
	mb.add_box(stone, _xf(Vector3(0, fl - 1.0, 0)), Vector3(w + 0.4, 2.0, d + 0.4), 0.5, Color.WHITE, true, false)
	tiled_box(mb, planks, Vector3(0, fl - 0.005, 0), Vector3(w - t * 2, 0.04, d - t * 2), 2.0, 0.6, true, false)
	_box_col(body, Vector3(w + 0.4, 2.0, d + 0.4), Vector3(0, fl - 1.0, 0))
	# steps up to the door
	mb.add_box(stone, _xf(Vector3(door_x, 0.15, d * 0.5 + 0.45)), Vector3(door_w + 0.8, 0.3, 0.9), 0.6, Color.WHITE, true, false)
	_box_col(body, Vector3(door_w + 0.8, 0.3, 0.9), Vector3(door_x, 0.15, d * 0.5 + 0.45))

	# walls: stone wainscot band + plaster, each a solid slab with both faces
	var walls := [
		# [center, size]
		[Vector3(0, 0, -d * 0.5 + t * 0.5), Vector3(w, 0, t)],
		[Vector3(-w * 0.5 + t * 0.5, 0, 0), Vector3(t, 0, d)],
		[Vector3(w * 0.5 - t * 0.5, 0, 0), Vector3(t, 0, d)],
	]
	var left_w := (door_x - door_w * 0.5) - (-w * 0.5)
	var right_w := (w * 0.5) - (door_x + door_w * 0.5)
	walls.append([Vector3(-w * 0.5 + left_w * 0.5, 0, d * 0.5 - t * 0.5), Vector3(left_w, 0, t)])
	walls.append([Vector3(w * 0.5 - right_w * 0.5, 0, d * 0.5 - t * 0.5), Vector3(right_w, 0, t)])
	for wl in walls:
		var c: Vector3 = wl[0]
		var s: Vector3 = wl[1]
		tiled_box(mb, stone, Vector3(c.x, fl + 0.5, c.z), Vector3(s.x + 0.04, 1.0, s.z + 0.04), 2.4, 0.5, true, true)
		tiled_box(mb, plaster, Vector3(c.x, fl + 1.0 + (h1 - 1.0) * 0.5, c.z), Vector3(s.x, h1 - 1.0, s.z), 2.4, 0.35, true, false)
		_box_col(body, Vector3(s.x, h1, s.z), Vector3(c.x, fl + h1 * 0.5, c.z))
	# lintel over the doorway
	mb.add_box(beam, _xf(Vector3(door_x, fl + door_h + (h1 - door_h) * 0.5, d * 0.5 - t * 0.5)), Vector3(door_w + 0.3, h1 - door_h, t + 0.06), 0.6)
	_box_col(body, Vector3(door_w, h1 - door_h, t), Vector3(door_x, fl + door_h + (h1 - door_h) * 0.5, d * 0.5 - t * 0.5))
	for s in [-1.0, 1.0]:
		mb.add_box(beam, _xf(Vector3(door_x + s * (door_w * 0.5 + 0.08), fl + door_h * 0.5, d * 0.5 - t * 0.5)), Vector3(0.18, door_h, t + 0.08), 0.6)
	# timber framing outside
	for x in [-w * 0.5, -w * 0.17, w * 0.17, w * 0.5]:
		if absf(x - door_x) < door_w * 0.5 + 0.2:
			continue
		mb.add_box(beam, _xf(Vector3(x, fl + h1 * 0.5, d * 0.5 + 0.02)), Vector3(0.22, h1, 0.06), 0.6)
		mb.add_box(beam, _xf(Vector3(x, fl + h1 * 0.5, -d * 0.5 - 0.02)), Vector3(0.22, h1, 0.06), 0.6)
	# windows on both faces of the walls
	for x in [-w * 0.36, w * 0.12, w * 0.36]:
		mb.add_box_unit_uv(window, _xf(Vector3(x, fl + 1.9, d * 0.5 + 0.02)), Vector3(1.0, 1.0, 0.04))
		mb.add_box_unit_uv(window, _xf(Vector3(x, fl + 1.9, d * 0.5 - t - 0.02)), Vector3(1.0, 1.0, 0.04))
		mb.add_box_unit_uv(window, _xf(Vector3(x, fl + 1.9, -d * 0.5 - 0.02)), Vector3(1.0, 1.0, 0.04))
		mb.add_box_unit_uv(window, _xf(Vector3(x, fl + 1.9, -d * 0.5 + t + 0.02)), Vector3(1.0, 1.0, 0.04))
	# ceiling + beams (inside)
	var cn := 6
	var cm := 4
	for i in range(cn):
		for j in range(cm):
			var x0 := -w * 0.5 + w * i / cn
			var x1 := -w * 0.5 + w * (i + 1) / cn
			var z0 := -d * 0.5 + d * j / cm
			var z1 := -d * 0.5 + d * (j + 1) / cm
			mb.add_quad(beam, Vector3(x0, fl + h1, z0), Vector3(x0, fl + h1, z1), Vector3(x1, fl + h1, z1), Vector3(x1, fl + h1, z0),
				Vector2(x0, z0) * 0.5, Vector2(x0, z1) * 0.5, Vector2(x1, z1) * 0.5, Vector2(x1, z0) * 0.5, Color(0.75, 0.75, 0.75), Vector3.DOWN)
	# light-tight backing above the ceiling tiles (no sky through the seams)
	mb.add_quad(PSXMat.flat(Color(0.12, 0.08, 0.05)), Vector3(-w * 0.5, fl + h1 + 0.03, -d * 0.5), Vector3(-w * 0.5, fl + h1 + 0.03, d * 0.5),
		Vector3(w * 0.5, fl + h1 + 0.03, d * 0.5), Vector3(w * 0.5, fl + h1 + 0.03, -d * 0.5),
		Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color.WHITE, Vector3.DOWN)
	for x in [-w * 0.3, 0.0, w * 0.3]:
		mb.add_box(beam, _xf(Vector3(x, fl + h1 - 0.15, 0)), Vector3(0.26, 0.3, d - t * 2), 0.6, Color.WHITE, false, true)

	# upper storey, jettied, timber framed + roof + chimney
	var uw := w + jetty * 2.0
	var ud := d + jetty * 2.0
	var y2 := fl + h1
	tiled_box(mb, plaster, Vector3(0, y2 + h2 * 0.5, 0), Vector3(uw, h2, ud), 3.2, 0.35, true, false)
	for x in [-uw * 0.5, -uw * 0.25, 0.0, uw * 0.25, uw * 0.5]:
		mb.add_box(beam, _xf(Vector3(x, y2 + h2 * 0.5, ud * 0.5)), Vector3(0.2, h2, 0.08), 0.6)
		mb.add_box(beam, _xf(Vector3(x, y2 + h2 * 0.5, -ud * 0.5)), Vector3(0.2, h2, 0.08), 0.6)
	mb.add_box(beam, _xf(Vector3(0, y2 + 0.05, 0)), Vector3(uw + 0.1, 0.18, ud + 0.1), 0.6)
	mb.add_box(beam, _xf(Vector3(0, y2 + h2, 0)), Vector3(uw + 0.1, 0.18, ud + 0.1), 0.6)
	for x in [-uw * 0.375, -uw * 0.125, uw * 0.125, uw * 0.375]:
		mb.add_box_unit_uv(window, _xf(Vector3(x, y2 + 1.35, ud * 0.5 + 0.04)), Vector3(0.8, 0.8, 0.06))
		mb.add_box_unit_uv(window, _xf(Vector3(x, y2 + 1.35, -ud * 0.5 - 0.04)), Vector3(0.8, 0.8, 0.06))
	mb.add_gable_roof(roof, _xf(Vector3(0, y2 + h2 + 0.09, 0), PI * 0.5), ud, uw, 3.2, 0.6, 0.5, Color.WHITE, plaster)
	_box_col(body, Vector3(uw, h2 + 3.3, ud), Vector3(0, y2 + (h2 + 3.3) * 0.5, 0))
	# fireplace on the left wall + chimney stack outside it
	var fx := -w * 0.5 + t
	mb.add_box(stone, _xf(Vector3(fx + 0.35, fl + 0.8, -0.6)), Vector3(0.7, 1.6, 0.35), 0.5)
	mb.add_box(stone, _xf(Vector3(fx + 0.35, fl + 0.8, 0.6)), Vector3(0.7, 1.6, 0.35), 0.5)
	mb.add_box(stone, _xf(Vector3(fx + 0.35, fl + 1.75, 0.0)), Vector3(0.8, 0.3, 1.6), 0.5, Color.WHITE, true, false)
	mb.add_box(beam, _xf(Vector3(fx + 0.45, fl + 1.95, 0.0)), Vector3(0.6, 0.1, 1.9), 0.6, Color.WHITE, false, false)
	mb.add_box(stone, _xf(Vector3(fx + 0.3, fl + 2.6, 0.0)), Vector3(0.6, 1.5, 1.2), 0.5, Color.WHITE, true, false)
	mb.add_box(stone, _xf(Vector3(-w * 0.5 - 0.45, y2 + 1.5, 0.0)), Vector3(0.9, h1 + h2, 1.2), 0.5, Color.WHITE, true, false)
	mb.add_box(stone, _xf(Vector3(-w * 0.5 - 0.45, y2 + h2 + 2.6, 0.0)), Vector3(0.8, 3.0, 1.0), 0.5, Color.WHITE, true, false)
	_box_col(body, Vector3(0.7, 1.6, 1.6), Vector3(fx + 0.35, fl + 0.8, 0.0))
	var fire := Props.campfire()
	fire.scale = Vector3(0.6, 0.6, 0.6)
	fire.position = Vector3(fx + 0.35, fl + 0.02, 0.0)
	body.add_child(fire)
	var fl_light := fire.get_node_or_null("FireLight") as OmniLight3D
	if fl_light:
		fl_light.omni_range = 6.0
		fl_light.light_energy = 1.6

	# the bar: an L-shaped counter in the back-right corner, shelves of bottles
	var bx := w * 0.5 - t - 2.6
	var bz := -d * 0.5 + t + 2.2
	mb.add_box(planks, _xf(Vector3(bx + 0.9, fl + 0.55, bz)), Vector3(3.8, 1.1, 0.6), 0.6, Color.WHITE, true, false)
	mb.add_box(beam, _xf(Vector3(bx + 0.9, fl + 1.13, bz + 0.05)), Vector3(4.0, 0.08, 0.8), 0.6, Color.WHITE, false, false)
	mb.add_box(planks, _xf(Vector3(bx - 0.75, fl + 0.55, bz - 0.95)), Vector3(0.6, 1.1, 1.3), 0.6, Color.WHITE, true, false)
	mb.add_box(beam, _xf(Vector3(bx - 0.75, fl + 1.13, bz - 0.95)), Vector3(0.8, 0.08, 1.5), 0.6, Color.WHITE, false, false)
	_box_col(body, Vector3(3.8, 1.1, 0.6), Vector3(bx + 0.9, fl + 0.55, bz))
	_box_col(body, Vector3(0.6, 1.1, 1.3), Vector3(bx - 0.75, fl + 0.55, bz - 0.95))
	var rng := RandomNumberGenerator.new()
	rng.seed = 411
	var glass := [PSXMat.flat(Color(0.25, 0.45, 0.2)), PSXMat.flat(Color(0.45, 0.25, 0.1)), PSXMat.flat(Color(0.6, 0.55, 0.3)), PSXMat.flat(Color(0.2, 0.3, 0.45))]
	var back := -d * 0.5 + t
	for row in range(3):
		var sy := fl + 1.3 + row * 0.55
		mb.add_box(beam, _xf(Vector3(bx + 0.9, sy, back + 0.2)), Vector3(3.6, 0.06, 0.4), 0.6, Color.WHITE, false, false)
		for i in range(9):
			var px := bx - 0.7 + i * 0.4 + rng.randf_range(-0.05, 0.05)
			var hgt := rng.randf_range(0.22, 0.34)
			mb.add_cylinder(glass[rng.randi() % glass.size()], _xf(Vector3(px, sy + 0.03, back + 0.2)), 0.06, 0.05, hgt, 5, 1.0)
			mb.add_cylinder(glass[0], _xf(Vector3(px, sy + 0.03 + hgt, back + 0.2)), 0.025, 0.02, 0.08, 4, 1.0)
	# mugs on the counter
	var mug := PSXMat.flat(Color(0.75, 0.6, 0.3))
	for i in range(4):
		mb.add_cylinder(mug, _xf(Vector3(bx - 0.2 + i * 0.7, fl + 1.17, bz + rng.randf_range(-0.1, 0.15))), 0.06, 0.06, 0.14, 5, 1.0)
	body.add_child(mb.to_instance())

	# kegs behind the bar, crates, a barrel by the door
	for p in [Vector3(w * 0.5 - t - 0.5, fl, back + 0.6), Vector3(w * 0.5 - t - 0.5, fl, back + 1.4)]:
		var keg := Props.barrel()
		keg.position = p
		body.add_child(keg)
	var crate := Props.crate(0.7)
	crate.position = Vector3(-w * 0.5 + t + 0.6, fl, back + 0.6)
	crate.rotation.y = 0.3
	body.add_child(crate)
	var barrel := Props.barrel()
	barrel.position = Vector3(door_x + door_w * 0.5 + 0.8, 0.0, d * 0.5 + 0.7)
	body.add_child(barrel)

	# tables with benches; patrons sit at the first two
	var tables := [Vector3(-2.6, fl, 1.4), Vector3(1.6, fl, 2.0), Vector3(-2.2, fl, -2.4)]
	var patron := 1
	for tp in tables:
		var tb := Props.table()
		tb.position = tp
		body.add_child(tb)
		for s in [-1.0, 1.0]:
			var bn := Props.bench()
			bn.position = tp + Vector3(0, 0, s * 0.85)
			body.add_child(bn)
		if patron <= 3 and tp != tables[2]:
			_marker(body, "Patron%d" % patron, tp + Vector3(-0.35, 0, 0.85), PI)
			patron += 1
	_marker(body, "Patron3", tables[2] + Vector3(0.35, 0, -0.85), 0.0)

	# warm light inside, hanging lanterns
	var glow := PSXMat.glow(Color(1.0, 0.75, 0.4), 2.0)
	var lmb := MeshBuilder.new()
	for x in [-w * 0.25, w * 0.15]:
		lmb.add_box(beam, _xf(Vector3(x, fl + h1 - 0.45, 0.6)), Vector3(0.04, 0.6, 0.04), 1.0)
		lmb.add_box(glow, _xf(Vector3(x, fl + h1 - 0.85, 0.6)), Vector3(0.22, 0.28, 0.22), 1.0)
	body.add_child(lmb.to_instance("Lanterns"))
	var light := OmniLight3D.new()
	light.name = "RoomLight"
	light.position = Vector3(0, fl + h1 - 1.0, 0.5)
	light.light_color = Color(1.0, 0.78, 0.5)
	light.light_energy = 1.3
	light.omni_range = 9.5
	body.add_child(light)

	# sign over the door
	var smb := MeshBuilder.new()
	smb.add_box(beam, _xf(Vector3(door_x + door_w * 0.5 + 0.6, fl + 3.2, d * 0.5 + 0.6)), Vector3(0.08, 0.08, 1.2), 1.0)
	smb.add_box_unit_uv(sign_m, _xf(Vector3(door_x + door_w * 0.5 + 0.6, fl + 2.75, d * 0.5 + 1.05), PI * 0.5), Vector3(1.2, 0.6, 0.06))
	body.add_child(smb.to_instance("Sign"))

	_marker(body, "Barkeep", Vector3(bx + 0.9, fl, bz - 0.75), 0.0)
	_marker(body, "Door", Vector3(door_x, 0.0, d * 0.5 + 1.6), 0.0)
	return body


# ==========================================================================
# Market stalls
# ==========================================================================
## A market stall of a kind ("fish", "fruit", "cloth", "pots"): counter, its
## own awning shape and goods. Customers stand on +Z; "Vendor" marker behind.
static func stall(kind: String) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Stall_" + kind
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var post := PSXMat.lit("planks_dark")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var w := 3.0
	match kind:
		"fish":
			# low table under a flat canvas sheet on four poles, ice and fish
			mb.add_box(wood, _xf(Vector3(0, 0.45, 0.35)), Vector3(w, 0.9, 0.9), 1.0, Color.WHITE, true, false)
			mb.add_box(PSXMat.flat(Color(0.82, 0.9, 0.95)), _xf(Vector3(0, 0.92, 0.35)), Vector3(w - 0.3, 0.06, 0.75), 1.0, Color.WHITE, false, false)
			var fish := [PSXMat.flat(Color(0.6, 0.65, 0.7)), PSXMat.flat(Color(0.75, 0.5, 0.35)), PSXMat.flat(Color(0.5, 0.6, 0.5))]
			for i in range(10):
				var x := -1.2 + (i % 5) * 0.6 + rng.randf_range(-0.1, 0.1)
				var z := 0.15 + (i / 5) * 0.38
				mb.add_box(fish[i % 3], _xf(Vector3(x, 0.99, z), rng.randf_range(-0.4, 0.4)), Vector3(0.42, 0.08, 0.14), 1.0)
			for x in [-w * 0.5, w * 0.5]:
				for z in [-0.6, 1.1]:
					mb.add_box(post, _xf(Vector3(x, 1.2, z)), Vector3(0.1, 2.4, 0.1), 0.8)
			var canvas := PSXMat.lit("canvas", Color.WHITE, {"affine": 0.6})
			mb.add_quad(canvas, Vector3(-w * 0.5 - 0.2, 2.45, -0.7), Vector3(w * 0.5 + 0.2, 2.45, -0.7), Vector3(w * 0.5 + 0.2, 2.3, 1.25), Vector3(-w * 0.5 - 0.2, 2.3, 1.25),
				Vector2.ZERO, Vector2(1.6, 0), Vector2(1.6, 1), Vector2(0, 1), Color.WHITE, Vector3.UP)
			mb.add_quad(canvas, Vector3(-w * 0.5 - 0.2, 2.45, -0.7), Vector3(-w * 0.5 - 0.2, 2.3, 1.25), Vector3(w * 0.5 + 0.2, 2.3, 1.25), Vector3(w * 0.5 + 0.2, 2.45, -0.7),
				Vector2.ZERO, Vector2(0, 1), Vector2(1.6, 1), Vector2(1.6, 0), Color(0.7, 0.7, 0.7), Vector3.DOWN)
			# hanging fish on a line
			mb.add_box(post, _xf(Vector3(0, 2.15, 1.1)), Vector3(w, 0.03, 0.03), 1.0)
			for i in range(5):
				mb.add_box(fish[i % 3], _xf(Vector3(-1.0 + i * 0.5, 1.9, 1.1)), Vector3(0.1, 0.45, 0.05), 1.0)
			var tub := Props.barrel()
			tub.position = Vector3(w * 0.5 + 0.5, 0, 0.4)
			body.add_child(tub)
		"fruit":
			# tiered baskets under a peaked striped awning
			mb.add_box(wood, _xf(Vector3(0, 0.5, 0.35)), Vector3(w, 1.0, 0.8), 1.0, Color.WHITE, true, false)
			mb.add_box(wood, _xf(Vector3(0, 0.8, -0.15)), Vector3(w, 0.6, 0.5), 1.0, Color.WHITE, true, false)
			var fruit := [Color(0.9, 0.55, 0.1), Color(0.85, 0.15, 0.12), Color(0.95, 0.85, 0.2), Color(0.45, 0.7, 0.2)]
			var basket := PSXMat.lit("straw")
			for i in range(5):
				var bxp := Vector3(-1.2 + i * 0.6, 1.0, 0.35)
				mb.add_cylinder(basket, _xf(bxp), 0.24, 0.27, 0.16, 6, 1.0)
				var fm := PSXMat.flat(fruit[i % fruit.size()])
				for k in range(5):
					mb.add_blob(fm, _xf(bxp + Vector3(rng.randf_range(-0.12, 0.12), 0.18 + (k / 3) * 0.08, rng.randf_range(-0.12, 0.12))), Vector3(0.07, 0.07, 0.07), rng, 0.15, 2, 4, 1.0)
			for i in range(4):
				var fm2 := PSXMat.flat(fruit[(i + 2) % fruit.size()])
				for k in range(4):
					mb.add_blob(fm2, _xf(Vector3(-1.05 + i * 0.7 + rng.randf_range(-0.15, 0.15), 1.16, -0.15 + rng.randf_range(-0.12, 0.12))), Vector3(0.07, 0.07, 0.07), rng, 0.15, 2, 4, 1.0)
			for x in [-w * 0.5, w * 0.5]:
				mb.add_box(post, _xf(Vector3(x, 1.25, 0.9)), Vector3(0.1, 2.5, 0.1), 0.8)
				mb.add_box(post, _xf(Vector3(x, 1.25, -0.6)), Vector3(0.1, 2.5, 0.1), 0.8)
			var aw := PSXMat.lit("cloth_red", Color.WHITE, {"affine": 0.6})
			mb.add_gable_roof(aw, _xf(Vector3(0, 2.5, 0.15)), 1.5, w, 0.6, 0.25, 0.6, Color.WHITE, aw)
		"cloth":
			# a rack hung with bolts and drapes, a tall pole awning
			mb.add_box(wood, _xf(Vector3(0, 0.45, 0.4)), Vector3(w, 0.9, 0.7), 1.0, Color.WHITE, true, false)
			var cols := [Color(0.66, 0.14, 0.12), Color(0.2, 0.32, 0.62), Color(0.8, 0.62, 0.2), Color(0.16, 0.42, 0.44), Color(0.36, 0.2, 0.44)]
			for i in range(5):
				mb.add_cylinder(PSXMat.lit("fabric", cols[i]), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-1.2 + i * 0.6, 1.0, 0.4)), 0.11, 0.11, 0.6, 6, 1.0)
			mb.add_box(post, _xf(Vector3(0, 2.1, -0.55)), Vector3(w + 0.2, 0.06, 0.06), 1.0)
			for x in [-w * 0.5 - 0.05, w * 0.5 + 0.05]:
				mb.add_box(post, _xf(Vector3(x, 1.1, -0.55)), Vector3(0.1, 2.2, 0.1), 0.8)
				mb.add_box(post, _xf(Vector3(x, 1.25, 1.0)), Vector3(0.1, 2.5, 0.1), 0.8)
			for i in range(4):
				var cm := PSXMat.lit("fabric", cols[(i + 1) % cols.size()])
				var x0 := -1.35 + i * 0.72
				mb.add_quad(cm, Vector3(x0, 2.08, -0.55), Vector3(x0 + 0.6, 2.08, -0.55), Vector3(x0 + 0.62, 0.95, -0.5), Vector3(x0 - 0.02, 0.95, -0.5),
					Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, Vector3.BACK)
				mb.add_quad(cm, Vector3(x0, 2.08, -0.56), Vector3(x0 - 0.02, 0.95, -0.51), Vector3(x0 + 0.62, 0.95, -0.51), Vector3(x0 + 0.6, 2.08, -0.56),
					Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color(0.7, 0.7, 0.7), Vector3.FORWARD)
			var aw2 := PSXMat.lit("cloth_blue", Color.WHITE, {"affine": 0.6})
			mb.add_quad(aw2, Vector3(-w * 0.5 - 0.2, 2.75, -0.7), Vector3(w * 0.5 + 0.2, 2.75, -0.7), Vector3(w * 0.5 + 0.2, 2.45, 1.2), Vector3(-w * 0.5 - 0.2, 2.45, 1.2),
				Vector2.ZERO, Vector2(1.6, 0), Vector2(1.6, 1), Vector2(0, 1), Color.WHITE, Vector3(0, 1, 0.15).normalized())
			mb.add_quad(aw2, Vector3(-w * 0.5 - 0.2, 2.75, -0.7), Vector3(-w * 0.5 - 0.2, 2.45, 1.2), Vector3(w * 0.5 + 0.2, 2.45, 1.2), Vector3(w * 0.5 + 0.2, 2.75, -0.7),
				Vector2.ZERO, Vector2(0, 1), Vector2(1.6, 1), Vector2(1.6, 0), Color(0.7, 0.7, 0.7), Vector3(0, -1, -0.15).normalized())
		_:
			# pots: a cart-like stand with shelves of pottery, no awning but an umbrella
			mb.add_box(wood, _xf(Vector3(0, 0.4, 0.35)), Vector3(w, 0.8, 0.8), 1.0, Color.WHITE, true, false)
			mb.add_box(wood, _xf(Vector3(0, 1.1, -0.3)), Vector3(w, 0.06, 0.45), 1.0, Color.WHITE, false, false)
			for x in [-w * 0.5 + 0.05, w * 0.5 - 0.05]:
				mb.add_box(post, _xf(Vector3(x, 0.6, -0.3)), Vector3(0.08, 1.2, 0.45), 0.8)
			var clay := [Color(0.72, 0.4, 0.22), Color(0.6, 0.32, 0.18), Color(0.82, 0.72, 0.55)]
			for i in range(7):
				var pm := PSXMat.lit("plaster", clay[i % 3])
				var px := -1.2 + i * 0.4
				var ph := rng.randf_range(0.22, 0.4)
				mb.add_cylinder(pm, _xf(Vector3(px, 0.8, 0.35)), 0.1, 0.15, ph * 0.6, 7, 1.0, Color.WHITE, false)
				mb.add_cylinder(pm, _xf(Vector3(px, 0.8 + ph * 0.6, 0.35)), 0.15, 0.07, ph * 0.4, 7, 1.0)
			for i in range(5):
				var pm2 := PSXMat.lit("plaster", clay[(i + 1) % 3])
				mb.add_cylinder(pm2, _xf(Vector3(-1.1 + i * 0.55, 1.13, -0.3)), 0.12, 0.16, 0.18, 7, 1.0)
			# wheels: it's a cart
			for s in [-1.0, 1.0]:
				mb.add_cylinder(post, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(s * (w * 0.5 + 0.05), 0.35, 0.35)), 0.35, 0.35, 0.08, 8, 1.0, Color.WHITE, true, true)
			mb.add_box(post, _xf(Vector3(w * 0.5 + 0.25, 1.4, 0.9)), Vector3(0.07, 2.8, 0.07), 0.8)
			var umb := PSXMat.lit("cloth_red", Color(1.0, 0.85, 0.6), {"affine": 0.6})
			mb.add_cylinder(umb, _xf(Vector3(w * 0.5 + 0.25, 2.45, 0.9)), 1.3, 0.05, 0.45, 8, 0.6, Color.WHITE, false, true, false)
	body.add_child(mb.to_instance())
	_box_col(body, Vector3(w, 1.0, 0.8), Vector3(0, 0.5, 0.35))
	_marker(body, "Vendor", Vector3(0, 0, -0.75), 0.0)
	return body


## Low stone wall / bollard ring for a market square (a few loose stones and a
## planter so it reads as a place, not just a clearing).
static func planter(r: float = 0.6) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Planter"
	body.collision_layer = WORLD_LAYER
	var mb := MeshBuilder.new()
	mb.add_cylinder(PSXMat.lit("stone_brick"), Transform3D.IDENTITY, r, r * 0.9, 0.55, 8, 0.6, Color.WHITE, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	mb.add_blob(PSXMat.lit("leaves"), _xf(Vector3(0, 0.8, 0)), Vector3(r * 0.9, 0.5, r * 0.9), rng, 0.25, 3, 6, 1.0)
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = 0.55
	cs.shape = cyl
	cs.position.y = 0.275
	body.add_child(cs)
	return body
