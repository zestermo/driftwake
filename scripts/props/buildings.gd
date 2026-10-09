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
# Dressing: shutters, sills, flower boxes, trim
# ==========================================================================
## Shutter / door-frame paints a house can have (one per house).
const TRIM_COLORS := [Color(0.27, 0.42, 0.62), Color(0.25, 0.5, 0.44), Color(0.6, 0.22, 0.16), Color(0.78, 0.62, 0.26),
	Color(0.86, 0.85, 0.8), Color(0.35, 0.3, 0.45)]
const BLOOMS := [Color(0.9, 0.2, 0.22), Color(0.95, 0.82, 0.25), Color(0.92, 0.5, 0.7), Color(0.95, 0.95, 0.92), Color(0.6, 0.4, 0.85)]


## Which side a house's lean-to is on (-1 left, 1 right, 0 none).
static func lean_side(spec: Dictionary) -> float:
	match str(spec.get("lean_to", "")):
		"left":
			return -1.0
		"right":
			return 1.0
	return 0.0


## A beam (box) from a to b.
static func beam_between(mb: MeshBuilder, mat: Material, a: Vector3, b: Vector3, t: float = 0.12, t2: float = -1.0) -> void:
	var dvec := b - a
	var basis := Basis.looking_at(dvec.normalized(), Vector3.UP if absf(dvec.normalized().y) < 0.95 else Vector3.FORWARD)
	mb.add_box(mat, Transform3D(basis, (a + b) * 0.5), Vector3(t, t if t2 < 0.0 else t2, dvec.length()), 0.6)


## Shutters either side, a sill below and (maybe) a box of flowers, on a
## window whose frame is `xf` (outward +Z) and size `sz`.
static func dress_window(mb: MeshBuilder, xf: Transform3D, sz: float, trim: Material, sill: Material, flowers: bool, rng: RandomNumberGenerator) -> void:
	for s in [-1.0, 1.0]:
		# hung open, angled a little off the wall
		var hinge := Vector3(s * (sz * 0.5 + 0.03), 0, 0.04)
		var leaf := Transform3D(Basis(Vector3.UP, s * 0.35), hinge) * Transform3D(Basis(), Vector3(s * 0.17, 0, 0))
		mb.add_box(trim, xf * leaf, Vector3(0.34, sz + 0.08, 0.04), 1.2)
	mb.add_box(sill, xf * Transform3D(Basis(), Vector3(0, -sz * 0.5 - 0.05, 0.07)), Vector3(sz + 0.24, 0.08, 0.16), 0.8)
	mb.add_box(sill, xf * Transform3D(Basis(), Vector3(0, sz * 0.5 + 0.05, 0.04)), Vector3(sz + 0.16, 0.07, 0.1), 0.8)
	if not flowers:
		return
	mb.add_box(PSXMat.lit("planks"), xf * Transform3D(Basis(), Vector3(0, -sz * 0.5 - 0.2, 0.18)), Vector3(sz + 0.12, 0.2, 0.24), 1.0)
	var leaves := PSXMat.lit("leaves", Color(0.8, 1.0, 0.8))
	var bloom := PSXMat.flat(BLOOMS[rng.randi() % BLOOMS.size()])
	var bloom2 := PSXMat.flat(BLOOMS[rng.randi() % BLOOMS.size()])
	for k in range(5):
		var x := -sz * 0.45 + k * sz * 0.225
		mb.add_blob(leaves, xf * Transform3D(Basis(), Vector3(x, -sz * 0.5 - 0.06, 0.18)), Vector3(0.11, 0.09, 0.1), rng, 0.25, 2, 5, 1.0)
		mb.add_blob(bloom if k % 2 == 0 else bloom2, xf * Transform3D(Basis(), Vector3(x + 0.04, -sz * 0.5 + 0.02, 0.22)), Vector3.ONE * 0.055, rng, 0.2, 2, 4, 1.0)


## A door's frame, a step stone and (with no porch) a little hood over it.
static func dress_door(mb: MeshBuilder, at: Vector3, trim: Material, beam: Material, roof: Material, hood: bool) -> void:
	for s in [-1.0, 1.0]:
		mb.add_box(trim, _xf(at + Vector3(s * 0.58, 1.05, 0.04)), Vector3(0.14, 2.15, 0.08), 1.0)
	mb.add_box(trim, _xf(at + Vector3(0, 2.15, 0.05)), Vector3(1.36, 0.16, 0.1), 1.0)
	if not hood:
		return
	var y := at.y + 2.45
	var z := at.z
	mb.add_quad(roof, Vector3(at.x - 0.85, y, z), Vector3(at.x + 0.85, y, z), Vector3(at.x + 0.85, y - 0.35, z + 0.8), Vector3(at.x - 0.85, y - 0.35, z + 0.8),
		Vector2.ZERO, Vector2(0.85, 0), Vector2(0.85, 0.5), Vector2(0, 0.5), Color.WHITE, Vector3(0, 1, 0.45).normalized())
	mb.add_quad(roof, Vector3(at.x - 0.85, y, z), Vector3(at.x - 0.85, y - 0.35, z + 0.8), Vector3(at.x + 0.85, y - 0.35, z + 0.8), Vector3(at.x + 0.85, y, z),
		Vector2.ZERO, Vector2(0, 0.5), Vector2(0.85, 0.5), Vector2(0.85, 0), Color(0.55, 0.55, 0.55), Vector3(0, -1, -0.45).normalized())
	for s in [-1.0, 1.0]:
		beam_between(mb, beam, Vector3(at.x + s * 0.75, y - 0.75, z), Vector3(at.x + s * 0.75, y - 0.3, z + 0.65), 0.08)


## A lantern on a bracket beside a door (glowing; the real light is the caller's).
static func wall_lantern(mb: MeshBuilder, at: Vector3, beam: Material) -> void:
	var glow := PSXMat.glow(Color(1.0, 0.78, 0.4), 2.2)
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	mb.add_box(beam, _xf(at + Vector3(0, 0.25, 0.18)), Vector3(0.05, 0.05, 0.36), 1.0)
	mb.add_box(iron, _xf(at + Vector3(0, 0.12, 0.34)), Vector3(0.24, 0.05, 0.24), 1.0)
	mb.add_box(glow, _xf(at + Vector3(0, -0.06, 0.34)), Vector3(0.18, 0.28, 0.18), 1.0)
	mb.add_box(iron, _xf(at + Vector3(0, -0.23, 0.34)), Vector3(0.22, 0.05, 0.22), 1.0)


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
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", hash([w, d, h, roof_kind, door_x])))
	var trim := PSXMat.lit("planks", spec.get("trim", TRIM_COLORS[rng.randi() % TRIM_COLORS.size()]))
	var flowers: bool = spec.get("flowers", rng.randf() < 0.65)
	var porch: float = spec.get("porch", 0.0)
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
	dress_door(mb, Vector3(door_x, fl, d * 0.5), trim, beam, roof, porch <= 0.0 and stilts <= 0.0)
	var nwin := maxi(int(w / 2.6), 1)
	for i in range(nwin + 1):
		var x := -w * 0.5 + w * (i + 0.5) / (nwin + 1)
		if absf(x - door_x) < 1.0:
			continue
		var wx := _xf(Vector3(x, fl + 1.5, d * 0.5 + 0.03))
		mb.add_box_unit_uv(window, wx, Vector3(0.7, 0.7, 0.06))
		dress_window(mb, wx, 0.7, trim, beam, flowers and porch <= 0.0, rng)
	for s in [-1.0, 1.0]:
		var sx := _xf(Vector3(s * (w * 0.5 + 0.03), fl + 1.5, 0), s * PI * 0.5)
		mb.add_box_unit_uv(window, sx, Vector3(0.7, 0.7, 0.06))
		if not (lean_side(spec) == s):
			dress_window(mb, sx, 0.7, trim, beam, false, rng)
	var back_win := _xf(Vector3(w * 0.2, fl + 1.5, -d * 0.5 - 0.03), PI)
	mb.add_box_unit_uv(window, back_win, Vector3(0.7, 0.7, 0.06))
	dress_window(mb, back_win, 0.7, trim, beam, false, rng)
	if spec.get("lantern", true):
		var lx := door_x + (0.95 if door_x + 0.95 < w * 0.5 - 0.2 else -0.95)
		wall_lantern(mb, Vector3(lx, fl + 1.95, d * 0.5), beam)
		if spec.get("lamp_light", false):
			var nl := NightLight.make(Color(1.0, 0.75, 0.42), 1.2, 7.0)
			nl.position = Vector3(lx, fl + 1.9, d * 0.5 + 0.6)
			body.add_child(nl)

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
			var ux := _xf(Vector3(x, top + h2 * 0.55 + 0.1, ud * 0.5 + 0.04))
			mb.add_box_unit_uv(window, ux, Vector3(0.65, 0.65, 0.06))
			dress_window(mb, ux, 0.65, trim, beam, flowers, rng)
		# brackets under the jetty
		for x in [-w * 0.5 + 0.3, w * 0.5 - 0.3]:
			mb.add_box(beam, Transform3D(Basis(Vector3.RIGHT, 0.7), Vector3(x, top - 0.15, d * 0.5 + jetty * 0.5)), Vector3(0.12, 0.12, 0.6), 0.6)
		top += h2 + 0.1

	# roof, with a ridge cap, barge boards up the gables and fascias on the eaves
	var pitch: float = spec.get("pitch", 0.45)
	var cap := PSXMat.lit(spec.get("roof_tex", "thatch"), Color(0.7, 0.66, 0.62), {"affine": 0.8})
	var y0 := top + 0.09
	match roof_kind:
		"gable_front":
			mb.add_gable_roof(roof, _xf(Vector3(0, y0, 0)), uw, ud, uw * pitch, 0.5, 0.5, Color.WHITE, wall2)
			var ry := y0 + uw * pitch
			mb.add_box(cap, _xf(Vector3(0, ry + 0.03, 0)), Vector3(0.26, 0.16, ud + 1.1), 0.8)
			for z in [-(ud * 0.5 + 0.5), ud * 0.5 + 0.5]:
				for s in [-1.0, 1.0]:
					beam_between(mb, beam, Vector3(s * (uw * 0.5 + 0.5), y0 - pitch, z), Vector3(0, ry, z), 0.16, 0.06)
			for s in [-1.0, 1.0]:
				mb.add_box(beam, _xf(Vector3(s * (uw * 0.5 + 0.52), y0 - pitch - 0.05, 0)), Vector3(0.06, 0.18, ud + 1.0), 0.8)
		"hip":
			var hh := minf(uw, ud) * pitch
			add_hip_roof(mb, roof, _xf(Vector3(0, y0, 0)), uw, ud, hh)
			var hw := uw * 0.5 + 0.45
			var hd := ud * 0.5 + 0.45
			var r := absf(hw - hd)
			var ra := Vector3(-r, y0 + hh, 0) if uw >= ud else Vector3(0, y0 + hh, -r)
			var rb := Vector3(r, y0 + hh, 0) if uw >= ud else Vector3(0, y0 + hh, r)
			if r > 0.05:
				beam_between(mb, cap, ra, rb, 0.24, 0.16)
			for c in [Vector3(-hw, y0, -hd), Vector3(hw, y0, -hd), Vector3(hw, y0, hd), Vector3(-hw, y0, hd)]:
				var near := ra if (rb - c).length() > (ra - c).length() else rb
				beam_between(mb, cap, c, near, 0.18, 0.12)
		"shed":
			add_shed_roof(mb, roof, wall2, _xf(Vector3(0, top, 0)), uw, ud, ud * pitch * 0.6)
		_:
			mb.add_gable_roof(roof, _xf(Vector3(0, y0, 0), PI * 0.5), ud, uw, ud * pitch, 0.5, 0.5, Color.WHITE, wall2)
			var ry := y0 + ud * pitch
			mb.add_box(cap, _xf(Vector3(0, ry + 0.03, 0)), Vector3(uw + 1.1, 0.16, 0.26), 0.8)
			for x in [-(uw * 0.5 + 0.5), uw * 0.5 + 0.5]:
				for s in [-1.0, 1.0]:
					beam_between(mb, beam, Vector3(x, y0 - pitch, s * (ud * 0.5 + 0.5)), Vector3(x, ry, 0), 0.06, 0.16)
			for s in [-1.0, 1.0]:
				mb.add_box(beam, _xf(Vector3(0, y0 - pitch - 0.05, s * (ud * 0.5 + 0.52))), Vector3(uw + 1.0, 0.18, 0.06), 0.8)

	if spec.get("chimney", false):
		var cx := -uw * 0.3
		mb.add_box(stone, _xf(Vector3(cx, top + 0.9, -ud * 0.15)), Vector3(0.7, 2.6, 0.7), 0.6, Color.WHITE, true, false)
		mb.add_box(stone, _xf(Vector3(cx, top + 2.25, -ud * 0.15)), Vector3(0.86, 0.12, 0.86), 0.6)
		mb.add_cylinder(PSXMat.lit("plaster", Color(0.72, 0.42, 0.28)), _xf(Vector3(cx, top + 2.3, -ud * 0.15)), 0.13, 0.11, 0.3, 6, 1.0)
		if spec.get("smoke", true):
			FX.chimney_smoke(body, Vector3(cx, top + 2.7, -ud * 0.15))

	# a few things about the place (only on level ground, it's not built on slopes)
	if found <= 1.15 and stilts <= 0.0 and spec.get("clutter", true):
		if rng.randf() < 0.75:
			var side := -1.0 if lean_side(spec) > 0.0 else 1.0
			var bp := Vector3(side * (w * 0.5 + 0.5), 0.0, -d * 0.5 + 0.55)
			mb.add_cylinder(PSXMat.lit("planks_dark"), _xf(bp), 0.34, 0.36, 0.85, 8, 1.0, Color.WHITE, true)
			for y in [0.18, 0.66]:
				mb.add_cylinder(PSXMat.lit("metal", Color(0.4, 0.38, 0.36)), _xf(bp + Vector3(0, y, 0)), 0.37, 0.37, 0.05, 8, 1.0)
			mb.add_cylinder(PSXMat.lit("water", Color(0.5, 0.6, 0.65)), _xf(bp + Vector3(0, 0.78, 0)), 0.3, 0.3, 0.02, 8, 1.0)
			_box_col(body, Vector3(0.65, 0.85, 0.65), bp + Vector3(0, 0.42, 0))
		if rng.randf() < 0.55 and lean_side(spec) == 0.0:
			var side2 := 1.0 if rng.randf() < 0.5 else -1.0
			# split logs stacked against a side wall, ends out
			var z0 := d * 0.1
			var bark := PSXMat.lit("bark")
			var lb := Basis(Vector3.BACK, side2 * PI * 0.5)
			for row in range(3):
				for k in range(4 - row):
					var z := z0 - (3 - row) * 0.13 + k * 0.26
					mb.add_cylinder(bark, Transform3D(lb, Vector3(side2 * (w * 0.5 + 0.7), 0.13 + row * 0.22, z)), 0.12, 0.12, 0.6, 6, 1.0, Color.WHITE, true, true)
			_box_col(body, Vector3(0.6, 0.7, 1.1), Vector3(side2 * (w * 0.5 + 0.4), 0.35, z0))
		if porch <= 0.0 and rng.randf() < 0.5:
			var bz := Vector3(door_x + (-1.6 if door_x > -w * 0.5 + 2.2 else 1.6), 0.0, d * 0.5 + 0.55)
			var seat := PSXMat.lit("planks")
			mb.add_box(seat, _xf(bz + Vector3(0, 0.42, 0)), Vector3(1.2, 0.07, 0.34), 1.0)
			for s in [-1.0, 1.0]:
				mb.add_box(beam, _xf(bz + Vector3(s * 0.48, 0.2, 0)), Vector3(0.08, 0.4, 0.3), 1.0)

	# covered porch along the front
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

	# a shopfront awning: striped cloth on two poles, a scalloped edge
	var awn: String = spec.get("awning", "")
	if awn != "" and porch <= 0.0:
		var cloth := PSXMat.lit("cloth_blue" if awn == "blue" else "cloth_red", Color(0.55, 1.15, 0.65) if awn == "green" else Color.WHITE, {"affine": 0.6})
		var aw := minf(w - 0.6, 4.2)
		var ay := fl + 2.45
		var ad := 1.7
		var z0 := d * 0.5 + 0.05
		var a0 := Vector3(-aw * 0.5, ay, z0); var a1 := Vector3(aw * 0.5, ay, z0)
		var a2 := Vector3(aw * 0.5, ay - 0.55, z0 + ad); var a3 := Vector3(-aw * 0.5, ay - 0.55, z0 + ad)
		var an := Vector3(0, ad, 0.55).normalized()
		mb.add_quad(cloth, a0, a1, a2, a3, Vector2.ZERO, Vector2(aw * 0.5, 0), Vector2(aw * 0.5, 0.9), Vector2(0, 0.9), Color.WHITE, an)
		mb.add_quad(cloth, a0, a3, a2, a1, Vector2.ZERO, Vector2(0, 0.9), Vector2(aw * 0.5, 0.9), Vector2(aw * 0.5, 0), Color(0.6, 0.6, 0.6), -an)
		var nsc := int(aw / 0.5)
		for k in range(nsc):
			var x0 := -aw * 0.5 + k * aw / nsc
			var x1 := x0 + aw / nsc
			var tip := Vector3((x0 + x1) * 0.5, ay - 0.85, z0 + ad + 0.01)
			mb.add_tri(cloth, Vector3(x0, ay - 0.55, z0 + ad + 0.01), Vector3(x1, ay - 0.55, z0 + ad + 0.01), tip, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector2(0, 0.9), Vector2(0.25, 0.9), Vector2(0.12, 1.0), Color.WHITE, Vector3.BACK)
			mb.add_tri(cloth, Vector3(x0, ay - 0.55, z0 + ad), tip - Vector3(0, 0, 0.02), Vector3(x1, ay - 0.55, z0 + ad), Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2(0, 0.9), Vector2(0.12, 1.0), Vector2(0.25, 0.9), Color(0.6, 0.6, 0.6), Vector3.FORWARD)
		for s in [-1.0, 1.0]:
			mb.add_box(beam, _xf(Vector3(s * aw * 0.5, (fl + ay - 0.55) * 0.5, z0 + ad)), Vector3(0.08, ay - 0.55, 0.08), 1.0)
		# goods out front: a crate and a basket
		mb.add_box(PSXMat.lit("planks", Color(0.9, 0.85, 0.75)), _xf(Vector3(-aw * 0.3, fl + 0.3, z0 + 0.7)), Vector3(0.7, 0.6, 0.6), 1.2)
		mb.add_cylinder(PSXMat.lit("straw"), _xf(Vector3(aw * 0.32, fl, z0 + 0.8)), 0.26, 0.3, 0.32, 7, 1.0)

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
	# roof trim: ridge tiles, barge boards, fascias
	var ry := y2 + h2 + 0.09 + 3.2
	var drop := 0.6 * 3.2 / (ud * 0.5)
	var ey := y2 + h2 + 0.09 - drop
	mb.add_box(PSXMat.lit("roof_tiles", Color(0.7, 0.6, 0.55), {"affine": 0.8}), _xf(Vector3(0, ry + 0.04, 0)), Vector3(uw + 1.3, 0.18, 0.3), 0.8)
	for x in [-(uw * 0.5 + 0.6), uw * 0.5 + 0.6]:
		for s in [-1.0, 1.0]:
			beam_between(mb, beam, Vector3(x, ey, s * (ud * 0.5 + 0.6)), Vector3(x, ry, 0), 0.07, 0.2)
	for s in [-1.0, 1.0]:
		mb.add_box(beam, _xf(Vector3(0, ey - 0.06, s * (ud * 0.5 + 0.62))), Vector3(uw + 1.2, 0.2, 0.07), 0.8)
	# shutters and flower boxes (front), shutters (back), on both floors
	var trim := PSXMat.lit("planks", Color(0.25, 0.5, 0.44))
	var drng := RandomNumberGenerator.new()
	drng.seed = 77
	for x in [-w * 0.36, w * 0.12, w * 0.36]:
		dress_window(mb, _xf(Vector3(x, fl + 1.9, d * 0.5 + 0.02)), 1.0, trim, beam, true, drng)
		dress_window(mb, _xf(Vector3(x, fl + 1.9, -d * 0.5 - 0.02), PI), 1.0, trim, beam, false, drng)
	for x in [-uw * 0.375, -uw * 0.125, uw * 0.125, uw * 0.375]:
		dress_window(mb, _xf(Vector3(x, y2 + 1.35, ud * 0.5 + 0.04)), 0.8, trim, beam, true, drng)
	# lanterns either side of the door, and its real light after dark
	for s in [-1.0, 1.0]:
		wall_lantern(mb, Vector3(door_x + s * (door_w * 0.5 + 0.45), fl + 2.5, d * 0.5), beam)
	var door_light := NightLight.make(Color(1.0, 0.72, 0.4), 1.4, 9.0)
	door_light.position = Vector3(door_x, fl + 2.6, d * 0.5 + 1.0)
	body.add_child(door_light)
	FX.chimney_smoke(body, Vector3(-w * 0.5 - 0.45, y2 + h2 + 4.3, 0.0))
	# outside: a bench under the window, the menu board, kegs stacked by the wall
	var bench := Props.bench()
	bench.position = Vector3(w * 0.25, 0.0, d * 0.5 + 0.7)
	body.add_child(bench)
	var board_x := door_x - door_w * 0.5 - 0.9
	mb.add_box(beam, Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(board_x, 0.55, d * 0.5 + 1.25)), Vector3(0.7, 1.1, 0.05), 1.0)
	mb.add_box(beam, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(board_x, 0.55, d * 0.5 + 1.55)), Vector3(0.7, 1.1, 0.05), 1.0)
	mb.add_box(PSXMat.flat(Color(0.12, 0.14, 0.13)), Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(board_x, 0.62, d * 0.5 + 1.215)), Vector3(0.58, 0.8, 0.02), 1.0)
	for k in range(4):
		mb.add_box(PSXMat.flat(Color(0.9, 0.9, 0.85)), Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(board_x - 0.05 + (k % 2) * 0.08, 0.86 - k * 0.15, d * 0.5 + 1.21)), Vector3(0.36 - (k % 2) * 0.1, 0.03, 0.01), 1.0)
	_box_col(body, Vector3(0.7, 1.0, 0.4), Vector3(board_x, 0.5, d * 0.5 + 1.4))
	for k in range(3):
		var kp := [Vector3(w * 0.5 + 0.55, 0.0, -1.2), Vector3(w * 0.5 + 0.55, 0.0, -0.4), Vector3(w * 0.5 + 0.55, 0.85, -0.8)][k] as Vector3
		var keg := Props.barrel()
		keg.position = kp
		keg.rotation.y = k * 0.7
		body.add_child(keg)
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
	# a tapped keg on the end of the counter
	mb.add_cylinder(planks, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(bx + 2.65, fl + 1.38, bz)), 0.22, 0.22, 0.5, 8, 1.0, Color.WHITE, true, true)
	mb.add_box(PSXMat.lit("metal", Color(0.8, 0.65, 0.35)), _xf(Vector3(bx + 2.1, fl + 1.3, bz)), Vector3(0.1, 0.06, 0.06), 1.0)
	_tavern_inside(body, mb, w, d, t, fl, h1, beam, planks, rng)
	body.add_child(mb.to_instance())
	# two cutlasses crossed on the back wall, flats to the room
	for s in [-1.0, 1.0]:
		var blade := MeshInstance3D.new()
		blade.mesh = Props.weapon_mesh("cutlass")
		var b := Basis(Vector3.BACK, -s * 0.5) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.BACK, PI * 0.5)
		blade.transform = Transform3D(b, Vector3(-2.2 - s * 0.35, fl + 1.95, -(d * 0.5 - t) + 0.05))
		body.add_child(blade)

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


## The common room's dressing: a rug, a swordfish over the fire, a sea chart,
## a ship's wheel and a net on the walls, candles, plates and mugs on the
## tables, herbs drying from the beams, barrels in the corner.
static func _tavern_inside(body: StaticBody3D, mb: MeshBuilder, w: float, d: float, t: float, fl: float, h1: float, beam: Material, planks: Material, rng: RandomNumberGenerator) -> void:
	var xi := w * 0.5 - t
	var zi := d * 0.5 - t
	# rug under the front tables
	var rug := PSXMat.lit("cloth_red", Color(0.85, 0.75, 0.7), {"affine": 0.6})
	mb.add_quad(rug, Vector3(-3.6, fl + 0.015, 0.0), Vector3(-3.6, fl + 0.015, 2.9), Vector3(0.6, fl + 0.015, 2.9), Vector3(0.6, fl + 0.015, 0.0),
		Vector2.ZERO, Vector2(0, 1.5), Vector2(2, 1.5), Vector2(2, 0), Color.WHITE, Vector3.UP)
	# a swordfish mounted over the mantel
	var fish := PSXMat.lit("metal", Color(0.42, 0.55, 0.7))
	var belly := PSXMat.lit("metal", Color(0.8, 0.82, 0.85))
	var fx := -xi + 0.06
	var fy := fl + 2.55
	mb.add_box(planks, _xf(Vector3(fx, fy, 0)), Vector3(0.05, 0.45, 1.5), 1.0)
	mb.add_blob(fish, _xf(Vector3(fx + 0.12, fy + 0.02, 0)), Vector3(0.08, 0.16, 0.55), rng, 0.08, 3, 6)
	mb.add_blob(belly, _xf(Vector3(fx + 0.13, fy - 0.06, 0.05)), Vector3(0.06, 0.07, 0.4), rng, 0.08, 2, 5)
	mb.add_cone(fish, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(fx + 0.12, fy + 0.02, 0.5)), 0.035, 0.75, 4)
	mb.add_tri(fish, Vector3(fx + 0.12, fy + 0.15, -0.2), Vector3(fx + 0.12, fy + 0.42, -0.05), Vector3(fx + 0.12, fy + 0.15, 0.15),
		Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector2.ZERO, Vector2(0, 1), Vector2(1, 0), Color.WHITE, Vector3.RIGHT)
	mb.add_tri(fish, Vector3(fx + 0.12, fy, -0.55), Vector3(fx + 0.12, fy + 0.22, -0.78), Vector3(fx + 0.12, fy - 0.2, -0.78),
		Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector2.ZERO, Vector2(0, 1), Vector2(1, 0), Color.WHITE, Vector3.RIGHT)
	# a sea chart pinned to the back wall
	var paper := PSXMat.flat(Color(0.86, 0.8, 0.62))
	var ink := PSXMat.flat(Color(0.35, 0.28, 0.2))
	mb.add_box(beam, _xf(Vector3(-0.6, fl + 2.25, -zi + 0.02)), Vector3(1.3, 0.95, 0.04), 1.0)
	mb.add_box(paper, _xf(Vector3(-0.6, fl + 2.25, -zi + 0.045)), Vector3(1.15, 0.8, 0.02), 1.0)
	for k in range(5):
		mb.add_box(ink, _xf(Vector3(-1.0 + rng.randf() * 0.8, fl + 1.95 + rng.randf() * 0.6, -zi + 0.058)), Vector3(rng.randf_range(0.1, 0.3), 0.025, 0.01), 1.0)
	mb.add_box(PSXMat.flat(Color(0.75, 0.12, 0.1)), Transform3D(Basis(Vector3.BACK, 0.78), Vector3(-0.25, fl + 2.1, -zi + 0.06)), Vector3(0.12, 0.025, 0.01), 1.0)
	mb.add_box(PSXMat.flat(Color(0.75, 0.12, 0.1)), Transform3D(Basis(Vector3.BACK, -0.78), Vector3(-0.25, fl + 2.1, -zi + 0.06)), Vector3(0.12, 0.025, 0.01), 1.0)
	# a ship's wheel on the right wall
	var wheel_at := Vector3(xi - 0.08, fl + 2.2, 1.4)
	var wb := Basis(Vector3.BACK, PI * 0.5)
	mb.add_cylinder(planks, Transform3D(wb, wheel_at + Vector3(0.04, 0, 0)), 0.5, 0.5, 0.06, 10, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(PSXMat.flat(Color(0.3, 0.2, 0.12)), Transform3D(wb, wheel_at + Vector3(0.0, 0, 0)), 0.42, 0.42, 0.07, 10, 1.0, Color.WHITE, true, true)
	for k in range(8):
		var a := TAU * k / 8.0
		var dir := Vector3(0, sin(a), cos(a))
		beam_between(mb, beam, wheel_at - Vector3(0.02, 0, 0), wheel_at - Vector3(0.02, 0, 0) + dir * 0.68, 0.05)
	# a net with floats hung in the front-right corner
	var rope := PSXMat.lit("rope", Color(0.85, 0.8, 0.7))
	for k in range(6):
		var z := 2.4 + k * 0.28
		beam_between(mb, rope, Vector3(xi - 0.05, fl + 3.3, z), Vector3(xi - 0.05, fl + 1.6 + (k % 2) * 0.2, z + 0.2), 0.02)
		beam_between(mb, rope, Vector3(xi - 0.05, fl + 3.3, z + 0.28), Vector3(xi - 0.05, fl + 1.7, z), 0.02)
	for k in range(4):
		mb.add_blob(PSXMat.flat(Color(0.9, 0.55, 0.2) if k % 2 == 0 else Color(0.85, 0.85, 0.8)), _xf(Vector3(xi - 0.1, fl + 1.9 + k * 0.35, 2.6 + (k % 2) * 0.8)), Vector3.ONE * 0.1, rng, 0.1, 2, 5)
	# candles, plates and mugs on the tables
	var wax := PSXMat.flat(Color(0.93, 0.9, 0.8))
	var flame := PSXMat.glow(Color(1.0, 0.75, 0.35), 3.0)
	var plate := PSXMat.flat(Color(0.82, 0.8, 0.74))
	var mug := PSXMat.flat(Color(0.75, 0.6, 0.3))
	for tp in [Vector3(-2.6, fl, 1.4), Vector3(1.6, fl, 2.0), Vector3(-2.2, fl, -2.4)]:
		var top: float = tp.y + 0.78
		mb.add_cylinder(wax, _xf(tp + Vector3(0.05, 0.78, 0)), 0.035, 0.03, 0.16, 5, 1.0)
		mb.add_box(flame, _xf(tp + Vector3(0.05, 0.98, 0)), Vector3(0.04, 0.07, 0.04), 1.0)
		for s in [-1.0, 1.0]:
			mb.add_cylinder(plate, _xf(Vector3(tp.x + s * 0.4, top, tp.z + s * 0.18)), 0.13, 0.11, 0.025, 7, 1.0)
			mb.add_cylinder(mug, _xf(Vector3(tp.x - s * 0.35, top, tp.z - s * 0.2)), 0.05, 0.05, 0.12, 5, 1.0)
	# herbs and onions drying from the beams
	var herb := PSXMat.lit("leaves", Color(0.7, 0.85, 0.55))
	var onion := PSXMat.flat(Color(0.85, 0.7, 0.45))
	for k in range(6):
		var hx: float = [-w * 0.3, 0.0, w * 0.3][k % 3]
		var hz := -1.6 + (k / 3) * 2.6 + rng.randf_range(-0.3, 0.3)
		mb.add_box(rope, _xf(Vector3(hx, fl + h1 - 0.45, hz)), Vector3(0.02, 0.3, 0.02), 1.0)
		mb.add_blob(herb if k % 2 == 0 else onion, _xf(Vector3(hx, fl + h1 - 0.7, hz)), Vector3(0.12, 0.2, 0.12), rng, 0.25, 3, 5)
	# barrels and a sack heaped in the front-left corner
	for p in [Vector3(-xi + 0.45, fl, zi - 0.45), Vector3(-xi + 1.15, fl, zi - 0.4)]:
		mb.add_cylinder(planks, _xf(p), 0.33, 0.35, 0.85, 8, 1.0, Color.WHITE, true)
		mb.add_cylinder(PSXMat.lit("metal", Color(0.4, 0.38, 0.36)), _xf(p + Vector3(0, 0.62, 0)), 0.36, 0.36, 0.05, 8, 1.0)
		_box_col(body, Vector3(0.65, 0.85, 0.65), p + Vector3(0, 0.42, 0))
	mb.add_blob(PSXMat.lit("canvas", Color(0.75, 0.68, 0.52)), _xf(Vector3(-xi + 0.5, fl + 0.25, zi - 1.2)), Vector3(0.3, 0.28, 0.3), rng, 0.2, 3, 6)


# ==========================================================================
# Smithy and chapel
# ==========================================================================
## An open-fronted smithy (front +Z): stone floor, a back wall hung with tools,
## a forge with glowing coals and a chimney, an anvil on a stump, a quench
## trough and a grindstone under a shed roof on posts. Marker "Smith" at the
## anvil (facing it).
static func smithy() -> Node3D:
	var w := 7.0
	var d := 5.0
	var body := StaticBody3D.new()
	body.name = "Smithy"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick")
	var beam := PSXMat.lit("planks_dark")
	var planks := PSXMat.lit("planks_weathered")
	var roof := PSXMat.lit("roof_tiles", Color(0.85, 0.8, 0.78), {"affine": 0.8})
	var iron := PSXMat.lit("metal", Color(0.32, 0.32, 0.34))
	var coals := PSXMat.glow(Color(1.0, 0.45, 0.12), 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	# floor slab (reaching down into the ground) and the back and left walls
	mb.add_box(stone, _xf(Vector3(0, -0.5, 0)), Vector3(w + 0.3, 1.2, d + 0.3), 0.5, Color.WHITE, true, false)
	_box_col(body, Vector3(w + 0.3, 1.2, d + 0.3), Vector3(0, -0.5, 0))
	tiled_box(mb, stone, Vector3(0, 0.1 + 0.6, -d * 0.5 + 0.15), Vector3(w, 1.2, 0.3), 2.4, 0.5)
	tiled_box(mb, planks, Vector3(0, 1.3 + 1.0, -d * 0.5 + 0.15), Vector3(w, 2.0, 0.26), 2.4, 0.5)
	_box_col(body, Vector3(w, 3.2, 0.3), Vector3(0, 1.7, -d * 0.5 + 0.15))
	tiled_box(mb, planks, Vector3(-w * 0.5 + 0.13, 0.1 + 0.6, -0.4), Vector3(0.26, 1.2, d - 1.0), 2.4, 0.5)
	_box_col(body, Vector3(0.26, 1.2, d - 1.0), Vector3(-w * 0.5 + 0.13, 0.7, -0.4))
	# posts and the shed roof (high at the back)
	for x in [-w * 0.5 + 0.15, 0.0, w * 0.5 - 0.15]:
		mb.add_box(beam, _xf(Vector3(x, 1.4, d * 0.5 - 0.15)), Vector3(0.22, 2.6, 0.22), 0.6)
		_box_col(body, Vector3(0.22, 2.6, 0.22), Vector3(x, 1.4, d * 0.5 - 0.15))
	mb.add_box(beam, _xf(Vector3(0, 2.75, d * 0.5 - 0.15)), Vector3(w + 0.2, 0.2, 0.24), 0.6)
	add_shed_roof(mb, roof, planks, _xf(Vector3(0, 2.85, 0)), w, d, 1.0, 0.45)
	# the forge: a stone hearth, glowing coals, a hood and its chimney
	var fp := Vector3(w * 0.5 - 1.3, 0.1, -d * 0.5 + 1.05)
	mb.add_box(stone, _xf(fp + Vector3(0, 0.45, 0)), Vector3(1.8, 0.9, 1.3), 0.5)
	mb.add_box(coals, _xf(fp + Vector3(0, 0.92, 0.05)), Vector3(1.2, 0.06, 0.8), 1.0)
	for k in range(6):
		mb.add_blob(PSXMat.flat(Color(0.12, 0.1, 0.09)), _xf(fp + Vector3(rng.randf_range(-0.5, 0.5), 0.96, rng.randf_range(-0.3, 0.35))), Vector3.ONE * 0.08, rng, 0.2, 2, 4)
	mb.add_cylinder(stone, _xf(fp + Vector3(0, 1.8, -0.1)), 0.95, 0.35, 0.9, 4, 0.5)
	mb.add_box(stone, _xf(fp + Vector3(0, 3.6, -0.1)), Vector3(0.7, 2.8, 0.7), 0.5, Color.WHITE, true, false)
	mb.add_box(stone, _xf(fp + Vector3(0, 5.05, -0.1)), Vector3(0.86, 0.12, 0.86), 0.5)
	_box_col(body, Vector3(1.8, 0.9, 1.3), fp + Vector3(0, 0.45, 0))
	FX.chimney_smoke(body, fp + Vector3(0, 5.4, -0.1))
	# bellows beside it
	mb.add_box(PSXMat.lit("leather", Color(0.55, 0.38, 0.25)), Transform3D(Basis(Vector3.RIGHT, 0.2), fp + Vector3(-1.25, 0.55, -0.1)), Vector3(0.5, 0.25, 0.9), 1.0)
	# the anvil on its stump
	var ap := Vector3(0.6, 0.1, 0.4)
	mb.add_cylinder(PSXMat.lit("bark"), _xf(ap), 0.32, 0.36, 0.55, 7, 1.0)
	mb.add_box(iron, _xf(ap + Vector3(0, 0.62, 0)), Vector3(0.28, 0.14, 0.22), 1.0)
	mb.add_box(iron, _xf(ap + Vector3(0, 0.78, 0)), Vector3(0.62, 0.16, 0.24), 1.0)
	mb.add_cone(iron, Transform3D(Basis(Vector3.BACK, PI * 0.5), ap + Vector3(-0.31, 0.78, 0)), 0.08, 0.3, 4)
	mb.add_box(iron, Transform3D(Basis(Vector3.UP, 0.4), ap + Vector3(0.15, 0.9, 0.0)), Vector3(0.3, 0.05, 0.05), 1.0)
	mb.add_box(PSXMat.lit("bark"), Transform3D(Basis(Vector3.UP, 0.4), ap + Vector3(0.0, 0.9, 0.06)), Vector3(0.05, 0.05, 0.28), 1.0)
	_box_col(body, Vector3(0.7, 0.9, 0.7), ap + Vector3(0, 0.45, 0))
	# quench trough and grindstone
	var tp := Vector3(w * 0.5 - 1.1, 0.1, 0.9)
	mb.add_box(planks, _xf(tp + Vector3(0, 0.3, 0)), Vector3(1.2, 0.6, 0.55), 1.0, Color.WHITE, true, false)
	mb.add_box(PSXMat.lit("water", Color(0.35, 0.45, 0.5)), _xf(tp + Vector3(0, 0.58, 0)), Vector3(1.05, 0.02, 0.42), 1.0)
	_box_col(body, Vector3(1.2, 0.6, 0.55), tp + Vector3(0, 0.3, 0))
	var gp := Vector3(-w * 0.5 + 1.2, 0.1, 1.5)
	for s in [-1.0, 1.0]:
		mb.add_box(beam, _xf(gp + Vector3(s * 0.22, 0.4, 0)), Vector3(0.08, 0.8, 0.5), 1.0)
	mb.add_cylinder(PSXMat.lit("rock", Color(0.8, 0.78, 0.72)), Transform3D(Basis(Vector3.BACK, PI * 0.5), gp + Vector3(0.1, 0.8, 0)), 0.38, 0.38, 0.18, 10, 1.0, Color.WHITE, true, true)
	_box_col(body, Vector3(0.6, 1.0, 0.8), gp + Vector3(0, 0.5, 0))
	# tools on the back wall: hammers, tongs, horseshoes
	var wz := -d * 0.5 + 0.32
	mb.add_box(beam, _xf(Vector3(-0.8, 2.0, wz)), Vector3(3.2, 0.1, 0.06), 1.0)
	for k in range(7):
		var x := -2.2 + k * 0.45
		match k % 3:
			0:
				mb.add_box(PSXMat.lit("bark"), _xf(Vector3(x, 1.7, wz + 0.03)), Vector3(0.04, 0.5, 0.04), 1.0)
				mb.add_box(iron, _xf(Vector3(x, 1.48, wz + 0.04)), Vector3(0.16, 0.08, 0.08), 1.0)
			1:
				for s in [-1.0, 1.0]:
					mb.add_box(iron, Transform3D(Basis(Vector3.BACK, s * 0.12), Vector3(x + s * 0.03, 1.65, wz + 0.03)), Vector3(0.025, 0.6, 0.025), 1.0)
			_:
				mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 1.75, wz + 0.02)), 0.09, 0.09, 0.03, 6, 1.0)
	# a rack of finished blades, iron stock in the corner
	var rack := Props.weapon_rack()
	rack.position = Vector3(-w * 0.5 + 0.6, 0.1, -0.6)
	rack.rotation.y = PI * 0.5
	body.add_child(rack)
	for k in range(5):
		mb.add_box(iron, Transform3D(Basis(Vector3.BACK, 0.12 + k * 0.03), Vector3(-w * 0.5 + 0.5 + k * 0.07, 0.75, -d * 0.5 + 0.55)), Vector3(0.04, 1.3, 0.04), 1.0)
	# the sign on the front post
	var sign_m := PSXMat.lit("sign_smithy", Color.WHITE, {"vertex_color": false})
	mb.add_box(beam, _xf(Vector3(-w * 0.5 + 0.15, 2.3, d * 0.5 + 0.4)), Vector3(0.08, 0.08, 0.8), 1.0)
	mb.add_box_unit_uv(sign_m, _xf(Vector3(-w * 0.5 + 0.15, 1.9, d * 0.5 + 0.6), PI * 0.5), Vector3(1.0, 0.5, 0.06))
	body.add_child(mb.to_instance())
	var glow := NightLight.make(Color(1.0, 0.5, 0.2), 1.3, 7.0, true)
	glow.position = fp + Vector3(0, 1.6, 0.9)
	body.add_child(glow)
	_marker(body, "Smith", ap + Vector3(-0.1, -0.1, -0.8), 0.0)
	return body


## The sea chapel (front +Z): a stone hall with buttresses and tall windows,
## a bell tower over the door with an open belfry, a bronze bell and a
## weathervane. Closed.
static func chapel() -> Node3D:
	var w := 6.0
	var d := 10.0
	var h := 4.2
	var body := StaticBody3D.new()
	body.name = "Chapel"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	# whitewashed walls, grey stone dressings
	var stone := PSXMat.lit("plaster", Color(1.0, 1.0, 1.02))
	var dark := PSXMat.lit("stone_brick", Color(0.85, 0.84, 0.8))
	var beam := PSXMat.lit("planks_dark")
	var roof := PSXMat.lit("roof_tiles", Color(0.75, 0.82, 0.9), {"affine": 0.8})
	var window := PSXMat.lit("window", Color(0.8, 0.9, 1.0), {"emission": Color(0.8, 0.85, 1.0), "emission_energy": 0.7, "emission_tex": "window"})
	var bronze := PSXMat.lit("metal", Color(0.85, 0.6, 0.3))
	mb.add_box(dark, _xf(Vector3(0, -0.6, 0)), Vector3(w + 0.5, 1.6, d + 0.5), 0.5, Color.WHITE, true, false)
	tiled_box(mb, stone, Vector3(0, 0.2 + h * 0.5, 0), Vector3(w, h, d), 2.4, 0.5)
	_box_col(body, Vector3(w + 0.5, h + 1.6, d + 0.5), Vector3(0, (h + 0.2 - 1.4) * 0.5, 0))
	mb.add_gable_roof(roof, _xf(Vector3(0, h + 0.29, 0)), w, d, 2.6, 0.5, 0.5, Color.WHITE, stone)
	mb.add_box(PSXMat.lit("roof_tiles", Color(0.6, 0.65, 0.72), {"affine": 0.8}), _xf(Vector3(0, h + 0.29 + 2.62, 0)), Vector3(0.28, 0.18, d + 1.1), 0.8)
	_box_col(body, Vector3(w, 2.6, d), Vector3(0, h + 1.5, 0))
	# buttresses and tall windows down both sides
	for s in [-1.0, 1.0]:
		for k in range(4):
			var z := -d * 0.5 + 1.2 + k * 2.55
			mb.add_box(dark, Transform3D(Basis(), Vector3(s * (w * 0.5 + 0.3), 1.4, z)), Vector3(0.6, 2.8, 0.55), 0.5)
			mb.add_box(dark, Transform3D(Basis(Vector3.BACK, -s * 0.5), Vector3(s * (w * 0.5 + 0.15), 3.0, z)), Vector3(0.4, 0.9, 0.5), 0.5)
			if k < 3:
				var wz := z + 1.27
				mb.add_box_unit_uv(window, _xf(Vector3(s * (w * 0.5 + 0.02), 2.4, wz), PI * 0.5), Vector3(0.6, 1.6, 0.05))
				mb.add_box(dark, _xf(Vector3(s * (w * 0.5 + 0.06), 3.3, wz)), Vector3(0.08, 0.16, 0.8), 0.5)
	# the tower over the door
	var tw := 2.6
	var tz := d * 0.5 - tw * 0.5 + 0.4
	var th := 8.0
	tiled_box(mb, stone, Vector3(0, 0.2 + th * 0.5, tz), Vector3(tw, th, tw), 2.4, 0.5)
	_box_col(body, Vector3(tw, th, tw), Vector3(0, 0.2 + th * 0.5, tz))
	mb.add_box(dark, _xf(Vector3(0, th + 0.25, tz)), Vector3(tw + 0.3, 0.2, tw + 0.3), 0.5)
	for x in [-tw * 0.5 + 0.2, tw * 0.5 - 0.2]:
		for z in [tz - tw * 0.5 + 0.2, tz + tw * 0.5 - 0.2]:
			mb.add_box(stone, _xf(Vector3(x, th + 1.25, z)), Vector3(0.4, 1.8, 0.4), 0.5)
	mb.add_box(dark, _xf(Vector3(0, th + 2.2, tz)), Vector3(tw + 0.3, 0.2, tw + 0.3), 0.5)
	add_hip_roof(mb, roof, _xf(Vector3(0, th + 2.3, tz)), tw, tw, 2.2, 0.25)
	# the bell, its yoke, and the weathervane
	mb.add_box(beam, _xf(Vector3(0, th + 2.0, tz)), Vector3(tw - 0.4, 0.14, 0.14), 1.0)
	mb.add_cylinder(bronze, _xf(Vector3(0, th + 1.05, tz)), 0.45, 0.22, 0.75, 8, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(bronze, _xf(Vector3(0, th + 1.8, tz)), 0.22, 0.1, 0.18, 8, 1.0)
	mb.add_box(PSXMat.lit("metal", Color(0.3, 0.3, 0.32)), _xf(Vector3(0, th + 4.8, tz)), Vector3(0.05, 0.9, 0.05), 1.0)
	mb.add_box(PSXMat.lit("metal", Color(0.3, 0.3, 0.32)), Transform3D(Basis(Vector3.UP, 0.6), Vector3(0, th + 5.0, tz)), Vector3(0.05, 0.05, 0.9), 1.0)
	mb.add_tri(PSXMat.lit("metal", Color(0.3, 0.3, 0.32)), Vector3(0, th + 5.12, tz), Vector3(0, th + 4.88, tz), Vector3(0, th + 5.0, tz) + Basis(Vector3.UP, 0.6) * Vector3(0, 0, 0.62),
		Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT, Vector2.ZERO, Vector2(0, 1), Vector2(1, 0), Color.WHITE, Vector3.RIGHT)
	# door with a stone arch, a round window over it
	var fz := tz + tw * 0.5
	mb.add_box_unit_uv(PSXMat.lit("door", Color.WHITE, {"vertex_color": false}), _xf(Vector3(0, 0.2 + 1.3, fz + 0.03)), Vector3(1.4, 2.6, 0.06))
	for s in [-1.0, 1.0]:
		mb.add_box(dark, _xf(Vector3(s * 0.85, 0.2 + 1.4, fz + 0.08)), Vector3(0.3, 2.8, 0.18), 0.5)
	mb.add_box(dark, _xf(Vector3(0, 0.2 + 2.9, fz + 0.08)), Vector3(2.0, 0.3, 0.18), 0.5)
	mb.add_cylinder(window, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 4.6, fz + 0.06)), 0.45, 0.45, 0.04, 10, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(dark, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 4.6, fz + 0.03)), 0.6, 0.6, 0.06, 10, 0.5, Color.WHITE, true, true)
	# two steps down from the door
	for k in range(2):
		var top := 0.2 - k * 0.1
		mb.add_box(dark, _xf(Vector3(0, (top - 0.6) * 0.5, fz + 0.2 + k * 0.35)), Vector3(2.2 + k * 0.3, top + 0.6, 0.35), 0.5, Color.WHITE, true, false)
	body.add_child(mb.to_instance())
	var lamp := NightLight.make(Color(0.95, 0.85, 0.65), 1.0, 7.0)
	lamp.position = Vector3(0, 3.0, fz + 1.4)
	body.add_child(lamp)
	return body


# ==========================================================================
# Harbour: the harbourmaster's tower, a dockside crane
# ==========================================================================
## An eight-sided stone tower by the quay: a battered base, three storeys of
## arched windows, a corbelled gallery with a rail, a tall tiled cap and a flag.
static func harbor_tower() -> Node3D:
	var body := StaticBody3D.new()
	body.name = "HarbourTower"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("stone_brick", Color(0.92, 0.86, 0.78))
	var band := PSXMat.lit("stone_brick", Color(0.7, 0.66, 0.6))
	var roof := PSXMat.lit("roof_tiles", Color.WHITE, {"affine": 0.8})
	var wood := PSXMat.lit("planks_dark")
	var window := PSXMat.lit("window", Color.WHITE, {"emission": Color(1.0, 0.75, 0.38), "emission_energy": 0.8, "emission_tex": "window"})
	var r := 2.6
	var h := 13.0
	var n := 8
	# the base flares out into the ground; the shaft; band courses
	mb.add_cylinder(band, Transform3D(Basis(Vector3.UP, PI / n), Vector3(0, -1.5, 0)), r + 0.7, r + 0.15, 3.0, n, 0.5)
	mb.add_cylinder(stone, Transform3D(Basis(Vector3.UP, PI / n), Vector3(0, 1.5, 0)), r + 0.1, r, h - 1.5, n, 0.5, Color.WHITE, false)
	for y in [1.5, 5.3, 9.1]:
		mb.add_cylinder(band, Transform3D(Basis(Vector3.UP, PI / n), Vector3(0, y, 0)), r + 0.18, r + 0.18, 0.22, n, 0.5)
	# windows on alternate faces, the door at the front (+Z)
	for lvl in range(3):
		var wy := 3.3 + lvl * 3.8
		for k in range(n):
			if (k + lvl) % 2 == 1:
				continue
			var a := TAU * k / n
			var out := Vector3(sin(a), 0, cos(a))
			if lvl == 0 and k == 0:
				continue
			var wxf := Transform3D(Basis(Vector3.UP, a), out * (r * cos(PI / n) + 0.03) + Vector3(0, wy, 0))
			mb.add_box_unit_uv(window, wxf, Vector3(0.6, 1.0, 0.06))
			mb.add_cylinder(band, wxf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.5, -0.02)), 0.36, 0.36, 0.1, 6, 1.0)
			mb.add_box(band, wxf * Transform3D(Basis(), Vector3(0, -0.56, 0.06)), Vector3(0.8, 0.1, 0.16), 1.0)
	var dz := r * cos(PI / n) + 0.04
	mb.add_box_unit_uv(PSXMat.lit("door", Color.WHITE, {"vertex_color": false}), Transform3D(Basis(), Vector3(0, 1.0 + 0.1, dz)), Vector3(1.1, 2.2, 0.06))
	mb.add_box(band, Transform3D(Basis(), Vector3(0, 2.35, dz + 0.05)), Vector3(1.5, 0.25, 0.14), 1.0)
	# the gallery on corbels, its rail, the cap
	var gy := h
	for k in range(n * 2):
		var a := TAU * k / (n * 2)
		mb.add_box(band, Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * (r + 0.25) + Vector3(0, gy - 0.35, 0)), Vector3(0.25, 0.5, 0.5), 1.0, Color.WHITE, false)
	mb.add_cylinder(band, Transform3D(Basis(Vector3.UP, PI / n), Vector3(0, gy, 0)), r + 0.75, r + 0.75, 0.25, n, 0.5, Color.WHITE, true, true)
	for k in range(n * 3):
		var a := TAU * k / (n * 3)
		mb.add_box(wood, Transform3D(Basis(), Vector3(sin(a), 0, cos(a)) * (r + 0.62) + Vector3(0, gy + 0.55, 0)), Vector3(0.08, 0.85, 0.08), 1.0)
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.UP, PI / (n * 3)), Vector3(0, gy + 0.95, 0)), r + 0.62, r + 0.62, 0.08, n * 3, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(stone, Transform3D(Basis(Vector3.UP, PI / n), Vector3(0, gy, 0)), r - 0.4, r - 0.4, 2.6, n, 0.5, Color.WHITE, false)
	for k in range(4):
		var a := TAU * k / 4.0 + PI / 4.0
		mb.add_box_unit_uv(window, Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * ((r - 0.4) * cos(PI / n) + 0.03) + Vector3(0, gy + 1.3, 0)), Vector3(0.55, 0.9, 0.06))
	mb.add_cone(roof, Transform3D(Basis(Vector3.UP, PI / n), Vector3(0, gy + 2.6, 0)), r + 0.3, 4.2, n)
	mb.add_cylinder(roof, Transform3D(Basis(Vector3.UP, PI / n), Vector3(0, gy + 2.45, 0)), r + 0.32, r + 0.32, 0.15, n, 0.6, Color(0.6, 0.6, 0.6), false, true)
	mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, gy + 6.6, 0)), 0.05, 0.04, 2.2, 5, 1.0)
	var flag := PSXMat.lit("cloth_blue")
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, gy + 8.1, 0.06)), 1.2, 0.7, Rect2(0, 0, 0.5, 0.5))
	mb.add_card(flag, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, gy + 8.1, 0.06)), 1.2, 0.7, Rect2(0, 0, 0.5, 0.5))
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r + 0.15
	cyl.height = h + 1.0
	cs.shape = cyl
	cs.position = Vector3(0, (h + 1.0) * 0.5 - 1.0, 0)
	body.add_child(cs)
	var lamp := NightLight.make(Color(1.0, 0.78, 0.45), 1.6, 14.0)
	lamp.position = Vector3(0, gy + 1.4, 0)
	body.add_child(lamp)
	return body


## A wooden jib crane on the quay (jib swung out toward +Z, over the water),
## a crate hanging off its hook.
static func dock_crane() -> Node3D:
	var body := StaticBody3D.new()
	body.name = "DockCrane"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	var iron := PSXMat.lit("metal", Color(0.3, 0.3, 0.32))
	var rope := PSXMat.lit("rope")
	mb.add_box(PSXMat.lit("stone_brick"), _xf(Vector3(0, 0.15, 0)), Vector3(1.6, 0.3, 1.6), 0.6)
	mb.add_box(wood, _xf(Vector3(0, 2.9, 0)), Vector3(0.36, 5.5, 0.36), 0.6)
	for s in [-1.0, 1.0]:
		beam_between(mb, wood, Vector3(s * 0.7, 0.3, -0.5), Vector3(0, 2.4, 0), 0.16)
	# the jib and its brace
	beam_between(mb, wood, Vector3(0, 5.2, -0.6), Vector3(0, 5.6, 4.2), 0.24)
	beam_between(mb, wood, Vector3(0, 3.2, 0.15), Vector3(0, 5.5, 2.4), 0.18)
	# treadwheel drum, rope over the sheave and down to the hook
	mb.add_cylinder(wood, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.6, 1.2, -0.7)), 0.55, 0.55, 1.2, 10, 1.0, Color.WHITE, true, true)
	mb.add_cylinder(iron, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.1, 5.45, 4.1)), 0.18, 0.18, 0.2, 8, 1.0, Color.WHITE, true, true)
	mb.add_tube(rope, PackedVector3Array([Vector3(0, 1.2, -0.7), Vector3(0, 5.3, -0.4), Vector3(0, 5.6, 4.1), Vector3(0, 2.6, 4.1)]), 0.03, -1.0, 4)
	mb.add_box(iron, _xf(Vector3(0, 2.5, 4.1)), Vector3(0.18, 0.2, 0.06), 1.0, Color.WHITE, false)
	for s in [-1.0, 1.0]:
		mb.add_tube(rope, PackedVector3Array([Vector3(0, 2.45, 4.1), Vector3(s * 0.35, 1.9, 4.1)]), 0.02, -1.0, 4)
	mb.add_box(PSXMat.lit("planks", Color(0.9, 0.85, 0.75)), _xf(Vector3(0, 1.45, 4.1)), Vector3(0.9, 0.9, 0.9), 1.1, Color.WHITE, false)
	body.add_child(mb.to_instance())
	_box_col(body, Vector3(1.6, 5.8, 1.6), Vector3(0, 2.9, 0))
	_marker(body, "Hook", Vector3(0, 1.0, 4.1))
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
