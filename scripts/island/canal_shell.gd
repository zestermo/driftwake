class_name CanalShell
extends RefCounted
## The canal city's shell (docs/v1_21_plan.md, piece 4): brick quay walls down into every canal and along the riva's
## sea edge, the low wall round the coast, the bridges (arched decks you walk over, parapets either side), the campanile
## and the church's dome over the piazza, the houses behind the streets as massing in blocks, the walkways' floors,
## and walls closing every gap a floor opens onto. Each piece one mesh, built on the worker (CanalIsland.prepare), its
## colliders as data, as CapitalShell's.

const P := preload("res://scripts/island/canal_plan.gd")
const M := preload("res://scripts/island/capital_models.gd")
const FAR := 3200.0
const MASS := 2400.0
const NEAR := 650.0
const CHUNK := 64.0
## The faded colours of the lagoon's houses, and its roofs.
const WALLS := [Color(0.92, 0.7, 0.46), Color(0.84, 0.5, 0.38), Color(0.94, 0.72, 0.68), Color(0.72, 0.8, 0.64), Color(0.95, 0.88, 0.74),
	Color(0.66, 0.74, 0.84), Color(0.76, 0.42, 0.32), Color(0.9, 0.82, 0.6)]
const ROOFS := [Color(0.92, 0.66, 0.52), Color(0.82, 0.56, 0.46), Color(1.0, 0.76, 0.6)]


static func build(build_ms: Dictionary) -> Array:
	var out: Array = []
	for step in [["quays", _quays], ["coast", _coast], ["bridges", _bridges], ["landmarks", _landmarks], ["massing", _massing], ["floors", _floors]]:
		var t0 := Time.get_ticks_usec()
		(step[1] as Callable).call(out)
		build_ms["shell " + str(step[0])] = int((Time.get_ticks_usec() - t0) / 1000)
	return out


static func _piece(out: Array, piece_name: String, mb: MeshBuilder, cols: Array, range_end: float, shadow: bool, faces: Array = []) -> void:
	mb.fold_tints()
	var split := Occluders.take(cols)
	out.append({"name": piece_name, "mesh": mb.commit(), "range": range_end, "shadow": shadow, "cols": split[0], "faces": faces, "occ": split[1]})


static func brick() -> Material:
	return PSXMat.lit("stone_brick", Color(0.92, 0.66, 0.54))


# --------------------------------------------------------------------------
## Every canal's edges where land meets it: a brick wall from the bed up to a stone coping at the quay, in runs (cut
## where another canal crosses); a wall face, its coping and its collider.
static func _quays(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var b := brick()
	var lime := M.mat("lime")
	for c in P.CANALS:
		var r: Rect2 = c[1]
		var edges := [[r.position, Vector2(r.end.x, r.position.y), Vector2(0, -1)], [Vector2(r.position.x, r.end.y), r.end, Vector2(0, 1)],
			[r.position, Vector2(r.position.x, r.end.y), Vector2(-1, 0)], [Vector2(r.end.x, r.position.y), r.end, Vector2(1, 0)]]
		for e in edges:
			var a: Vector2 = e[0]
			var bb: Vector2 = e[1]
			var n: Vector2 = e[2]
			var steps := int(a.distance_to(bb) / 2.0)
			var run0 := -1
			for i in range(steps + 1):
				var land := false
				if i < steps:
					var p := a.lerp(bb, (i + 0.5) / steps) + n * 0.8
					land = not P.in_canal(p) and P.land_t(p) < -0.5
				if land and run0 < 0:
					run0 = i
				elif not land and run0 >= 0:
					_wall(mb, cols, b, lime, a.lerp(bb, float(run0) / steps), a.lerp(bb, float(i) / steps), n)
					run0 = -1
	_piece(out, "Quays", mb, cols, FAR, false)


## A quay wall from a to b, its land on the `n` side (frame): brick from below the bed to the quay, a coping on top.
static func _wall(mb: MeshBuilder, cols: Array, b: Material, lime: Material, a: Vector2, c: Vector2, n: Vector2) -> void:
	var mid := (a + c) * 0.5 + n * 0.3
	var L := a.distance_to(c) + 0.6
	var yaw := M.yaw_of(n)
	var lo := P.CANAL_BED - 1.0
	var t := M.xf(M.v3(mid, (lo + P.QUAY_Y) * 0.5), yaw)
	mb.add_box(b, t, Vector3(L, P.QUAY_Y - lo, 0.6), 0.6, Color(0.95, 0.9, 0.86), true, false)
	mb.add_box(lime, M.xf(M.v3(mid - n * 0.05, P.QUAY_Y + 0.08), yaw), Vector3(L, 0.16, 0.8), 0.6, Color(0.88, 0.86, 0.82), false)
	M.box(cols, t, Vector3(L, P.QUAY_Y - lo, 0.6))
	# a band of green slime at the waterline
	mb.add_box(PSXMat.flat(Color(0.26, 0.34, 0.24)), M.xf(M.v3(mid - n * 0.02, 0.05), yaw), Vector3(L, 0.5, 0.64), 1.0, Color.WHITE, false)


## The riva's sea edge (a quay wall the length of the harbour front but for the Grand Canal's mouth) and a low brick
## wall round the rest of the coast.
static func _coast(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var b := brick()
	var lime := M.mat("lime")
	for r in P.RIVA:
		_wall(mb, cols, b, lime, Vector2((r as Rect2).position.x, P.FRONT_Z), Vector2((r as Rect2).end.x, P.FRONT_Z), Vector2(0, -1))
	var rr := P.LAND_R - 2.5
	var a0 := asin((P.FRONT_Z - 2.0 - P.LAND_C.y) / rr)
	var n := 140
	var run: Array = []
	for k in range(n + 1):
		var a := lerpf(a0, PI - a0 - TAU, float(k) / n)
		var p := P.LAND_C + Vector2(cos(a), sin(a)) * rr
		if P.in_canal(p, 3.0):
			if run.size() >= 2:
				M.wall_run(mb, cols, run, 2.4, 1.2, func(q): return P.QUAY_Y, func(q): return P.terrain(q), 6.0, false)
			run = []
			continue
		run.append(p)
	if run.size() >= 2:
		M.wall_run(mb, cols, run, 2.4, 1.2, func(q): return P.QUAY_Y, func(q): return P.terrain(q), 6.0, false)
	_piece(out, "Coast", mb, cols, FAR, false)


# --------------------------------------------------------------------------
## The bridges: an arched deck of stone slabs from floor to floor, rising `rise` at the middle, brick sides under a
## stone parapet each side; a tilted collider under each step of the deck, the parapets solid.
static func _bridges(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var slab := M.mat("slabs")
	var lime := M.mat("lime")
	var b := brick()
	for br in P.BRIDGES:
		var a: Vector2 = br[0]
		var c: Vector2 = br[1]
		var w: float = br[2]
		var rise: float = br[3]
		var dir := (c - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var a2 := a - dir * 1.5
		var c2 := c + dir * 1.5
		var steps := 10
		for k in range(steps):
			var t0 := float(k) / steps
			var t1 := float(k + 1) / steps
			var p0 := a2.lerp(c2, t0)
			var p1 := a2.lerp(c2, t1)
			var y0 := P.QUAY_Y + rise * sin(PI * t0)
			var y1 := P.QUAY_Y + rise * sin(PI * t1)
			var hw := w * 0.5
			mb.add_quad(slab, M.v3(p0 - side * hw, y0), M.v3(p0 + side * hw, y0), M.v3(p1 + side * hw, y1), M.v3(p1 - side * hw, y1),
				Vector2.ZERO, Vector2(w * 0.5, 0), Vector2(w * 0.5, 0.8), Vector2(0, 0.8), Color(0.9, 0.88, 0.84), Vector3.UP)
			var e0 := M.v3(p0, y0)
			var e1 := M.v3(p1, y1)
			M.box(cols, Transform3D(Basis.looking_at(e1 - e0, Vector3.UP), (e0 + e1) * 0.5) * Transform3D(Basis(), Vector3(0, -0.2, 0)), Vector3(w, 0.4, e0.distance_to(e1) + 0.25))
			for s: float in [-1.0, 1.0]:
				var q0 := p0 + side * s * (hw + 0.2)
				var q1 := p1 + side * s * (hw + 0.2)
				var pm := (q0 + q1) * 0.5
				var ym := (y0 + y1) * 0.5
				mb.add_box(lime, M.xf(M.v3(pm, ym + 0.5), M.yaw_of(dir)), Vector3(0.4, 1.0, q0.distance_to(q1) + 0.05), 0.6, Color(0.92, 0.9, 0.86))
				M.box(cols, M.xf(M.v3(pm, ym + 0.5), M.yaw_of(dir)), Vector3(0.4, 1.0, q0.distance_to(q1) + 0.05))
				# the brick side under the deck down to the arch
				var under := 0.0 + 1.2 * (1.0 - sin(PI * (t0 + t1) * 0.5))
				mb.add_box(b, M.xf(M.v3(pm, (ym + under) * 0.5 - 0.1), M.yaw_of(dir)), Vector3(0.5, ym - under, q0.distance_to(q1) + 0.05), 0.6, Color(0.92, 0.88, 0.84))
			# the arch's soffit
			var u0 := 1.2 * (1.0 - sin(PI * t0))
			var u1 := 1.2 * (1.0 - sin(PI * t1))
			mb.add_quad(b, M.v3(p0 + side * w * 0.5, u0), M.v3(p0 - side * w * 0.5, u0), M.v3(p1 - side * w * 0.5, u1), M.v3(p1 + side * w * 0.5, u1),
				Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color(0.7, 0.62, 0.58), Vector3.DOWN)
	_piece(out, "Bridges", mb, cols, FAR, true)


# --------------------------------------------------------------------------
## The campanile by the piazza (a tall brick shaft, a belfry of arches, a green pyramid spire) and the church's dome.
static func _landmarks(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var b := brick()
	var lime := M.mat("lime")
	var cr: Rect2 = P.SPECIAL["campanile"][0]
	var cc := cr.get_center()
	var w := cr.size.x
	var shaft := 34.0
	mb.add_box(b, M.xf(M.v3(cc, P.QUAY_Y + shaft * 0.5 - 1.0)), Vector3(w, shaft + 2.0, w), 0.5, Color(0.86, 0.5, 0.4))
	M.box(cols, M.xf(M.v3(cc, P.QUAY_Y + shaft * 0.5 - 1.0)), Vector3(w, shaft + 2.0, w))
	Occluders.box(cols, M.xf(M.v3(cc, P.QUAY_Y + shaft * 0.5)), Vector3(w - 0.4, shaft, w - 0.4))
	for f in range(4):
		var yaw := f * PI * 0.5
		var t := M.xf(M.v3(cc, P.QUAY_Y + shaft), yaw) * Transform3D(Basis(), Vector3(0, 0, w * 0.5 - 0.3))
		M.arch_wall(mb, lime, t, w, 5.0, 0.6, w * 0.5, 3.0, Color(0.96, 0.94, 0.9))
		mb.add_box(M.mat("dark"), t * Transform3D(Basis(), Vector3(0, 2.0, -0.4)), Vector3(w * 0.5, 3.2, 0.06), 1.0, Color(0.15, 0.13, 0.12), false)
	mb.add_box(lime, M.xf(M.v3(cc, P.QUAY_Y + shaft + 5.2)), Vector3(w + 0.6, 0.5, w + 0.6), 0.6, Color(0.94, 0.92, 0.88), false)
	mb.add_cone(PSXMat.lit("metal", Color(0.45, 0.62, 0.52)), M.xf(M.v3(cc, P.QUAY_Y + shaft + 5.45), PI * 0.25), w * 0.72, 9.0, 4, 1.0)
	M.flag(mb, M.v3(cc, P.QUAY_Y + shaft + 14.5), M.GOLD)
	var ch: Rect2 = P.SPECIAL["church"][0]
	M.dome(mb, M.v3(ch.get_center() - Vector2(0, 2.0), P.QUAY_Y + 15.0), 6.5, 3.0, Color(0.5, 0.62, 0.56))
	_piece(out, "Landmarks", mb, cols, FAR, true)


# --------------------------------------------------------------------------
## The houses that don't front a walkway, as massing in chunks (no colliders: the walkways' houses and the barriers
## seal them off): coloured facades, tiled roofs, the lagoon's funnel chimneys.
static func _massing(out: Array) -> void:
	var lots := P.lots()
	var chunks := {}
	var far := {}
	for l in lots:
		# (1.27) a walkway house is the district's up close; out past its range, massing like the rest, or every walkway
		# and calle shows a gap of bare ground from the lagoon and from above
		if l["front"]:
			var fk := Vector2i(floori(l["c"].x / (CHUNK * 2.5)), floori(l["c"].y / (CHUNK * 2.5)))
			if not far.has(fk):
				far[fk] = []
			far[fk].append(l)
			continue
		var c: Vector2 = l["c"]
		var key := Vector2i(floori(c.x / CHUNK), floori(c.y / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(l)
	var keys := chunks.keys()
	keys.sort()
	for key in keys:
		var mb := MeshBuilder.new()
		var cols: Array = []
		for l in chunks[key]:
			house(mb, cols, l, false)
		_piece(out, "Houses_%d_%d" % [key.x, key.y], mb, cols.filter(func(c): return c.has("occ")), MASS, false)
	var fkeys := far.keys()
	fkeys.sort()
	for key in fkeys:
		var fmb := MeshBuilder.new()
		var fcols: Array = []
		for l in far[key]:
			house(fmb, fcols, l, false)
		_piece(out, "FarFronts_%d_%d" % [key.x, key.y], fmb, [], MASS, false)
		(out[out.size() - 1] as Dictionary)["begin"] = CanalDistrict.RANGE - 10.0
	var mb := MeshBuilder.new()
	var cols: Array = []
	for o in P.openings(lots):
		_barrier(mb, cols, o[0], o[1], o[2])
	_piece(out, "Barriers", mb, cols, NEAR, true)


## A lagoon house on lot `l`: a stone plinth, coloured facade storeys, a cornice, a tiled roof and a funnel chimney or
## two. `solid` gives it a collider (the walkways' houses; the massing has none). Returns its frame transform and size.
static func house(mb: MeshBuilder, cols: Array, l: Dictionary, solid: bool, hollow := false) -> Array:
	var r: Rect2 = l["r"]
	var face: Vector2 = l["face"]
	var w := r.size.x if absf(face.y) > 0.5 else r.size.y
	var d := r.size.y if absf(face.y) > 0.5 else r.size.x
	var t := M.xf(M.v3(r.get_center(), 0.0), M.yaw_of(face))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(l["seed"])
	var col: Color = WALLS[rng.randi() % WALLS.size()]
	var y0 := P.QUAY_Y
	var h := 3.6 + float(maxi(int(l["floors"]), 2) - 1) * M.STOREY
	mb.add_box(M.mat("lime"), t * Transform3D(Basis(), Vector3(0, y0 * 0.5 - 0.8, 0)), Vector3(w + 0.08, y0 + 1.6, d + 0.08), 0.5, Color(0.86, 0.84, 0.8), true, false)
	M.facade_box(mb, M.mat("facade_a") if rng.randf() < 0.5 else M.mat("facade_b"), t, w, d, y0 + 0.2, h, col)
	mb.add_box(M.mat("lime"), t * Transform3D(Basis(), Vector3(0, y0 + 0.2 + h + 0.1, 0)), Vector3(w + 0.24, 0.22, d + 0.24), 0.6, Color(0.94, 0.92, 0.88), false)
	M.roof(mb, str(l["roof"]), t, w, d, y0 + 0.4 + h, ROOFS[rng.randi() % ROOFS.size()], rng)
	for k in range(rng.randi_range(1, 2)):
		var cp := t * Vector3(rng.randf_range(-w * 0.3, w * 0.3), 0, rng.randf_range(-d * 0.3, d * 0.3))
		chimney(mb, Vector3(cp.x, y0 + h + 1.2, cp.z), rng)
	var cell: Rect2 = l["cell"]
	# (1.27: a walk-in house is hollowed by CapitalInteriors instead; the solid one's top meets its roof, walked on)
	if hollow:
		return [t, w, d, h]
	if solid:
		M.box(cols, M.xf(M.v3(cell.get_center(), (y0 + h + 0.4 - 1.0) * 0.5)), Vector3(cell.size.x, y0 + h + 0.4 + 1.0, cell.size.y))
	Occluders.box(cols, t * Transform3D(Basis(), Vector3(0, y0 + h * 0.5, 0)), Vector3(w - 0.3, h, d - 0.3))
	return [t, w, d, h]


## The chimney tops built since the island's prepare cleared it (CitySmoke), city frame.
static var smoke_tops: Array = []


## The lagoon's funnel chimney: a plastered stack flaring to a wide cone at the top.
static func chimney(mb: MeshBuilder, at: Vector3, rng: RandomNumberGenerator) -> void:
	var wash := M.mat("wash")
	var ht := rng.randf_range(2.2, 3.2)
	mb.add_cylinder(wash, M.xf(at), 0.28, 0.24, ht, 6, 0.6, Color(0.92, 0.86, 0.78))
	mb.add_cylinder(wash, M.xf(at + Vector3(0, ht, 0)), 0.26, 0.6, 0.8, 6, 0.6, Color(0.86, 0.6, 0.48), true, false)
	smoke_tops.append(at + Vector3(0, ht + 1.0, 0))


## A wall across a gap a floor opens onto: plastered brick, a door shut in it (a lane further into the block).
static func _barrier(mb: MeshBuilder, cols: Array, a: Vector2, b: Vector2, n: Vector2) -> void:
	var c := (a + b) * 0.5 + n * 0.3
	var L := a.distance_to(b) + 1.0
	var y := P.QUAY_Y - 1.0
	var top := P.QUAY_Y + 4.6
	var yaw := M.yaw_of(-n)
	var t := M.xf(M.v3(c, (y + top) * 0.5), yaw)
	mb.add_box(M.mat("wash"), t, Vector3(L, top - y, 0.8), 0.5, Color(0.92, 0.78, 0.64))
	mb.add_box(M.mat("lime"), M.xf(M.v3(c, top + 0.1), yaw), Vector3(L + 0.2, 0.25, 1.0), 0.6, Color(0.88, 0.86, 0.82), false)
	M.box(cols, t, Vector3(L, top - y, 0.8))
	Occluders.box(cols, t, Vector3(L - 1.0, top - y, 0.8))
	if L >= 2.4:
		var door := M.xf(M.v3(c - n * 0.42, P.QUAY_Y), yaw)
		Buildings.panel_door(mb, door, minf(L - 1.0, 1.6), 2.4, Buildings.door_leaf(Color(0.3, 0.36, 0.28)), M.mat("lime"))


# --------------------------------------------------------------------------
## The walkways' floors: a grid over each one's rect at the quay, one surface a texture, their faces the collider.
static func _floors(out: Array) -> void:
	var mb := MeshBuilder.new()
	var shapes: Array = []
	for f in P.floors():
		var r: Rect2 = f[1]
		var m := PSXMat.lit(str(f[2]))
		var uv := 0.5 if str(f[2]) == "capital_slabs" else 0.6
		var nx := maxi(ceili(r.size.x / 2.0), 1)
		var nz := maxi(ceili(r.size.y / 2.0), 1)
		var faces := PackedVector3Array()
		for ix in range(nx):
			if ix % 16 == 0 and not faces.is_empty():
				shapes.append(faces)
				faces = PackedVector3Array()
			for iz in range(nz):
				var q0 := r.position + Vector2(r.size.x * ix / nx, r.size.y * iz / nz)
				var q1 := r.position + Vector2(r.size.x * (ix + 1) / nx, r.size.y * (iz + 1) / nz)
				var c := [Vector2(q0.x, q0.y), Vector2(q1.x, q0.y), Vector2(q1.x, q1.y), Vector2(q0.x, q1.y)]
				var p: Array = c.map(func(q): return M.v3(q, P.QUAY_Y))
				var shade := 0.94 + 0.06 * float((ix * 7 + iz * 13) % 3) / 2.0
				mb.add_quad(m, p[0], p[1], p[2], p[3], c[0] * uv, c[1] * uv, c[2] * uv, c[3] * uv, Color(shade, shade, shade), Vector3.UP)
				faces.append_array([p[0], p[1], p[2], p[0], p[2], p[3]])
		shapes.append(faces)
	_piece(out, "Floors", mb, [], NEAR, false, shapes)
