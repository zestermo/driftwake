class_name CapitalShell
extends RefCounted
## The royal capital's shell (docs/capital_plan.md, piece 1): what you see sailing in and what holds the district.
## The quay and the moles with the lighthouse and the harbour fort, the harbour wall and its sea gate, the sea wall
## round the coast with its towers, the palace on its hill inside its grounds' wall and the road up, the arena's
## outer walls, the bell tower and the temple's dome, the town's houses as massing in blocks, the district's
## floors, and walls closing every gap a floor opens onto. Each piece one mesh (fold_tints: a surface a texture),
## built on the worker (CapitalIsland.prepare), its colliders as data.

const P := preload("res://scripts/island/capital_plan.gd")
const M := preload("res://scripts/island/capital_models.gd")
## How far the pieces are drawn: the skyline from well out to sea, the town's floors from the district.
const FAR := 3600.0
const MASS := 2800.0
const NEAR := 700.0
const CHUNK := 72.0


static func build(build_ms: Dictionary) -> Array:
	var out: Array = []
	for step in [["quay", _quay], ["harbour wall", _harbour_wall], ["sea wall", _sea_wall], ["grounds", _grounds],
			["palace", _palace], ["arena", _arena], ["landmarks", _landmarks], ["massing", _massing], ["floors", _floors]]:
		var t0 := Time.get_ticks_usec()
		(step[1] as Callable).call(out)
		build_ms["shell " + str(step[0])] = int((Time.get_ticks_usec() - t0) / 1000)
	return out


static func _piece(out: Array, piece_name: String, mb: MeshBuilder, cols: Array, range_end: float, shadow: bool, faces: Array = []) -> void:
	mb.fold_tints()
	out.append({"name": piece_name, "mesh": mb.commit(), "range": range_end, "shadow": shadow, "cols": cols, "faces": faces})


static func _ground(q: Vector2) -> float:
	return P.ground(q)


static func _low(q: Vector2) -> float:
	return minf(P.terrain(q), P.ground(q) - P.FLOOR_DROP)


# --------------------------------------------------------------------------
static func _quay(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var lime := M.mat("lime")
	var x := -P.QUAY_END_X
	var k := 0
	while x < P.QUAY_END_X - 0.01:
		var w := minf(6.0, P.QUAY_END_X - x)
		var c := Vector2(x + w * 0.5, P.FRONT_Z - 1.0)
		var t := M.xf(M.v3(c, (P.QUAY_Y - 10.0) * 0.5))
		mb.add_box(lime, t, Vector3(w + 0.02, P.QUAY_Y + 10.0, 3.0), 0.5, Color(0.93, 0.9, 0.85) * (0.97 + 0.03 * float(k % 2)), true, true)
		M.box(cols, t, Vector3(w, P.QUAY_Y + 10.0, 3.0))
		mb.add_box(lime, M.xf(M.v3(Vector2(c.x, P.FRONT_Z - 0.1), P.QUAY_Y + 0.08)), Vector3(w + 0.02, 0.18, 1.0), 0.6, Color(0.82, 0.8, 0.75), false)
		if k % 2 == 0 and absf(c.x - P.BERTH.x) > 14.0:
			mb.add_cylinder(M.mat("iron"), M.xf(M.v3(Vector2(c.x, P.FRONT_Z - 0.6), P.QUAY_Y + 0.15)), 0.26, 0.2, 0.55, 8, 1.0, Color(0.5, 0.5, 0.52))
			mb.add_cylinder(M.mat("iron"), M.xf(M.v3(Vector2(c.x, P.FRONT_Z - 0.6), P.QUAY_Y + 0.68)), 0.34, 0.34, 0.12, 8, 1.0, Color(0.5, 0.5, 0.52))
		x += w
		k += 1
	var dark := M.mat("dark")
	var fx := P.BERTH.x - 12.0
	while fx < P.BERTH.x + 12.0:
		mb.add_box(dark, M.xf(M.v3(Vector2(fx, P.FRONT_Z + 0.15), P.QUAY_Y - 2.4)), Vector3(0.3, 4.8, 0.3), 1.0, Color(0.7, 0.6, 0.5))
		fx += 2.0
	for bx in [P.BERTH.x - 9.0, P.BERTH.x + 9.0]:
		mb.add_cylinder(M.mat("iron"), M.xf(M.v3(Vector2(bx, P.FRONT_Z - 0.6), P.QUAY_Y + 0.15)), 0.3, 0.24, 0.6, 8, 1.0, Color(0.45, 0.45, 0.47))
	for lx in [-120.0, -60.0, 70.0, 128.0]:
		for r in range(7):
			mb.add_box(M.mat("iron"), M.xf(M.v3(Vector2(lx, P.FRONT_Z + 0.1), P.QUAY_Y - 0.4 - r * 0.45)), Vector3(0.6, 0.05, 0.08), 1.0, Color(0.5, 0.5, 0.5), false)
	for m in [P.MOLE_E, P.MOLE_W]:
		_mole(mb, cols, m)
	M.lighthouse(mb, cols, P.MOLE_E[2], P.MOLE_Y)
	M.round_tower(mb, cols, P.MOLE_W[2], P.MOLE_Y, 6.5, 9.0, false, 12.0)
	M.flag(mb, M.v3(P.MOLE_W[2], P.MOLE_Y + 11.6), M.BLUE)
	_piece(out, "Quay", mb, cols, FAR, true)


## A mole: stone blocks from the sea floor up to the walk, a parapet on its sea side.
static func _mole(mb: MeshBuilder, cols: Array, pts: Array) -> void:
	var lime := M.mat("lime")
	var basin := P.BASIN.get_center()
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(ceili(a.distance_to(b) / 7.0), 1)
		var dir := (b - a).normalized()
		var side := Vector2(dir.y, -dir.x)
		if side.dot(basin - (a + b) * 0.5) > 0.0:
			side = -side
		for k in range(n):
			var c := a.lerp(b, (k + 0.5) / n)
			var L := a.distance_to(b) / n + 0.3
			var t := M.xf(M.v3(c, (P.MOLE_Y - 11.0) * 0.5), M.yaw_of(dir))
			mb.add_box(lime, t, Vector3(P.MOLE_HW * 2.0, P.MOLE_Y + 11.0, L), 0.5, Color(0.9, 0.88, 0.83) * (0.96 + 0.04 * float(k % 2)), true, false)
			M.box(cols, t, Vector3(P.MOLE_HW * 2.0, P.MOLE_Y + 11.0, L))
			var pc := c + side * (P.MOLE_HW - 0.45)
			var pt := M.xf(M.v3(pc, P.MOLE_Y + 0.6), M.yaw_of(dir))
			mb.add_box(lime, pt, Vector3(0.9, 1.2, L), 0.5, Color(0.86, 0.84, 0.8))
			M.box(cols, pt, Vector3(0.9, 1.2, L))
	var head: Vector2 = pts[pts.size() - 1]
	mb.add_cylinder(lime, M.xf(M.v3(head, -11.0)), 9.0, 8.0, P.MOLE_Y + 11.0, 14, 0.5, Color(0.9, 0.88, 0.83), true, false, false)
	M.cyl(cols, M.v3(head, -11.0), 8.0, P.MOLE_Y + 11.0)


# --------------------------------------------------------------------------
static func _harbour_wall(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var lime := M.mat("lime")
	var ends := sqrt(pow(P.LAND_R - P.SEA_WALL_IN, 2.0) - pow(P.WALL_Z - P.LAND_C.y, 2.0))
	for run in [[Vector2(-ends, P.WALL_Z), Vector2(-70.6, P.WALL_Z)], [Vector2(-64.4, P.WALL_Z), Vector2(-9.0, P.WALL_Z)], [Vector2(9.0, P.WALL_Z), Vector2(ends, P.WALL_Z)]]:
		M.wall_run(mb, cols, run, 9.0, P.WALL_T, _ground, _low)
	for sx in [-1.0, 1.0]:
		M.wall_run(mb, cols, [Vector2(sx * P.QUAY_END_X, P.WALL_Z + 1.5), Vector2(sx * P.QUAY_END_X, P.FRONT_Z + 2.0)], 6.0, 2.4, _ground, _low)
		for x in [50.0, 100.0]:
			M.square_tower(mb, cols, Vector2(sx * x, P.WALL_Z), P.QUAY_Y, 8.0, 14.0, 0.0, x > 60.0, 3.0)
		M.round_tower(mb, cols, Vector2(sx * P.QUAY_END_X, P.WALL_Z), P.QUAY_Y, 5.0, 14.0, true, 3.0, true)
		M.round_tower(mb, cols, Vector2(sx * P.QUAY_END_X, P.FRONT_Z + 2.0), P.QUAY_Y, 3.6, 8.0, false, 12.0)
	M.gatehouse(mb, cols, M.xf(M.v3(Vector2(0, P.WALL_Z), P.QUAY_Y)), 18.0, 10.0, 13.0, 6.0, 4.6, 4.2)
	var pt := M.xf(M.v3(Vector2(-67.5, P.WALL_Z), P.base(P.WALL_Z)))
	M.arch_wall(mb, lime, pt, 6.2, 9.0, P.WALL_T, 2.6, 2.1, Color(0.93, 0.91, 0.87))
	for s in [-1.0, 1.0]:
		M.box(cols, pt * Transform3D(Basis(), Vector3(s * 2.25, 4.5, 0)), Vector3(1.7, 9.0, P.WALL_T))
	_piece(out, "HarbourWall", mb, cols, FAR, true)


# --------------------------------------------------------------------------
static func _sea_wall(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var r := P.LAND_R - P.SEA_WALL_IN
	var a0 := asin((P.FRONT_Z - 4.0 - P.LAND_C.y) / r)
	var a1 := PI - a0 - TAU
	var n := 160
	var pts: Array = []
	for k in range(n + 1):
		var a := lerpf(a0, a1, float(k) / n)
		pts.append(P.LAND_C + Vector2(cos(a), sin(a)) * r)
	M.wall_run(mb, cols, pts, 7.5, 3.0, _ground, _low)
	for k in range(6, n - 3, 11):
		var p: Vector2 = pts[k]
		M.round_tower(mb, cols, p, P.ground(p), 4.2, 11.0 + 2.0 * float(k % 3), true, 6.0, k % 22 == 6)
	_piece(out, "SeaWall", mb, cols, FAR, true)


# --------------------------------------------------------------------------
static func _grounds(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var n := 56
	var runs: Array = [[]]
	for k in range(n + 1):
		var a := PI * 0.5 + TAU * k / n
		var p := P.HILL_C + Vector2(cos(a), sin(a)) * P.GROUNDS_R
		if P.land_t(p) < -P.SEA_WALL_IN - 1.0 and (absf(p.x - P.PALACE_GATE.x) > 9.0 or p.y < P.HILL_C.y):
			(runs[-1] as Array).append(p)
		elif not (runs[-1] as Array).is_empty():
			runs.append([])
	for run in runs:
		if run.size() >= 2:
			M.wall_run(mb, cols, run, 8.0, 2.6, _ground, _low)
	for k in range(4, n, 7):
		var a := PI * 0.5 + TAU * k / n
		var p := P.HILL_C + Vector2(cos(a), sin(a)) * P.GROUNDS_R
		if P.land_t(p) < -P.SEA_WALL_IN - 1.0:
			M.round_tower(mb, cols, p, P.ground(p), 3.6, 11.0, true, 6.0)
	M.gatehouse(mb, cols, M.xf(M.v3(P.PALACE_GATE, P.ground(P.PALACE_GATE))), 18.0, 9.0, 12.0, 5.0, 4.0, 3.8, true)
	var road := [Vector2(0, -72), Vector2(-36, -84), Vector2(30, -100), Vector2(-20, -113), Vector2(0, -120)]
	var slab := M.mat("slabs")
	var lime := M.mat("lime")
	var rng := RandomNumberGenerator.new()
	rng.seed = 6113
	for i in range(road.size() - 1):
		var a: Vector2 = road[i]
		var b: Vector2 = road[i + 1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var steps := ceili(a.distance_to(b) / 3.0)
		for k in range(steps):
			var p0 := a.lerp(b, float(k) / steps)
			var p1 := a.lerp(b, float(k + 1) / steps)
			var y0 := P.ground(p0) + 0.45
			var y1 := P.ground(p1) + 0.45
			mb.add_quad(slab, M.v3(p0 - side * 2.6, y0), M.v3(p0 + side * 2.6, y0), M.v3(p1 + side * 2.6, y1), M.v3(p1 - side * 2.6, y1),
				Vector2.ZERO, Vector2(2.6, 0), Vector2(2.6, 1.5), Vector2(0, 1.5), Color(0.92, 0.9, 0.86), Vector3.UP)
			for s: float in [-1.0, 1.0]:
				var e0: Vector2 = p0 + side * s * 2.85
				var e1: Vector2 = p1 + side * s * 2.85
				var mid: Vector2 = (e0 + e1) * 0.5
				mb.add_box(lime, M.xf(M.v3(mid, (y0 + y1) * 0.5 + 0.1), M.yaw_of(dir)), Vector3(0.45, 1.6, e0.distance_to(e1) + 0.05), 0.6, Color(0.9, 0.88, 0.84))
			if k % 3 == 1:
				var cp := p0 + side * (4.4 if k % 2 == 0 else -4.4)
				M.cypress(mb, M.v3(cp, P.terrain(cp)), rng.randf_range(6.0, 8.5), rng)
	for k in range(26):
		var a := rng.randf() * TAU
		var d := rng.randf_range(P.HILL_R0 + 6.0, P.GROUNDS_R - 8.0)
		var p := P.HILL_C + Vector2(cos(a), sin(a)) * d
		if P.land_t(p) < -12.0:
			M.cypress(mb, M.v3(p, P.terrain(p)), rng.randf_range(6.0, 10.0), rng)
	_piece(out, "PalaceGrounds", mb, cols, FAR, true)


static func _palace(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	M.palace(mb, cols, P.HILL_C, P.HILL_TOP, _ground, _low)
	_piece(out, "Palace", mb, cols, FAR, true)


static func _arena(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	M.arena(mb, cols, P.ARENA_C, P.ARENA_R, P.PLAZA_Y)
	_piece(out, "Arena", mb, cols, FAR, true)


# --------------------------------------------------------------------------
static func _landmarks(out: Array) -> void:
	var mb := MeshBuilder.new()
	var cols: Array = []
	var bell := Vector2(38.0, -31.0)
	M.square_tower(mb, cols, bell, P.PLAZA_Y, 6.5, 27.0, 0.0, true, 2.0)
	for f in range(4):
		var yaw := f * PI * 0.5
		var t := M.xf(M.v3(bell, P.PLAZA_Y), yaw) * Transform3D(Basis(), Vector3(0, 0, 3.27))
		mb.add_box(M.mat("dark"), t * Transform3D(Basis(), Vector3(0, 23.6, 0)), Vector3(2.2, 3.4, 0.06), 1.0, Color(0.18, 0.16, 0.15), false)
		mb.add_cylinder(M.mat("lime"), t * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 18.5, 0.02)), 1.3, 1.3, 0.12, 12, 1.0, Color(0.96, 0.95, 0.92))
		mb.add_box(M.mat("iron"), t * Transform3D(Basis(Vector3.BACK, 0.6), Vector3(0, 18.5, 0.2)), Vector3(0.08, 1.0, 0.04), 1.0, Color.WHITE, false)
		mb.add_box(M.mat("iron"), t * Transform3D(Basis(Vector3.BACK, -1.9), Vector3(0, 18.5, 0.2)), Vector3(0.08, 0.7, 0.04), 1.0, Color.WHITE, false)
	var tc := P.TEMPLE.get_center() + Vector2(4.0, 2.0)
	var ty := P.ground(tc)
	var tt := M.xf(M.v3(tc, 0.0))
	mb.add_box(M.mat("lime"), M.xf(M.v3(tc, ty - 1.0)), Vector3(27.0, 3.6, 33.0), 0.5, Color(0.9, 0.88, 0.84), true, false)
	M.facade_box(mb, M.mat("facade_b"), tt, 26.0, 32.0, ty + 0.8, 12.0, Color(0.98, 0.95, 0.88))
	mb.add_box(M.mat("lime"), M.xf(M.v3(tc, ty + 13.0)), Vector3(26.8, 0.5, 32.8), 0.6, Color(0.92, 0.9, 0.86), false)
	M._hip(mb, M.xf(M.v3(tc, ty + 13.2)), 26.0, 32.0, 4.0, 0.3, Color.WHITE)
	M.dome(mb, M.v3(tc, ty + 15.0), 8.5, 4.0, Color(0.62, 0.75, 0.68))
	M.box(cols, M.xf(M.v3(tc, ty + 6.0)), Vector3(26.0, 14.0, 32.0))
	for s in [-1.0, 1.0]:
		M.square_tower(mb, cols, tc + Vector2(14.5, s * 17.0), ty, 5.0, 19.0, 0.0, true, 2.0)
	_piece(out, "Landmarks", mb, cols, FAR, true)


# --------------------------------------------------------------------------
## The town's houses behind the district's in chunks (one mesh each, no colliders: the district's houses and the
## walls seal them off), and every gap a floor opens onto a wall with a door shut in it.
static func _massing(out: Array) -> void:
	var lots := P.lots()
	var chunks := {}
	for l in lots:
		if l["front"] or l["keep"] or P.special_hit(l["cell"]):
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
			var r: Rect2 = l["r"]
			var corners := [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]
			var low := INF
			var top := -INF
			for p in corners:
				low = minf(low, _low(p))
				top = maxf(top, P.ground(p))
			if top - low > 6.0:
				continue
			var sd := int(l["seed"])
			if sd % 19 == 0 and minf(r.size.x, r.size.y) >= 6.5:
				M.square_tower(mb, cols, r.get_center(), top, minf(r.size.x, r.size.y) - 1.2, 16.0 + float(sd % 9), 0.0, sd % 2 == 0, top - low + 0.5)
				continue
			M.house(mb, l, low - 0.5, top)
		_piece(out, "Houses_%d_%d" % [key.x, key.y], mb, [], MASS, false)
	var mb := MeshBuilder.new()
	var cols: Array = []
	for o in P.openings(lots):
		_barrier(mb, cols, o[0], o[1], o[2])
	_piece(out, "Barriers", mb, cols, NEAR, true)


## A wall across a gap, with a door shut in it when there's room: a lane the city's other districts lie up (1.20).
static func _barrier(mb: MeshBuilder, cols: Array, a: Vector2, b: Vector2, n: Vector2) -> void:
	var c := (a + b) * 0.5 + n * 0.3
	var L := a.distance_to(b) + 1.0
	var y := minf(P.ground(a), P.ground(b)) - 1.0
	var top := maxf(P.ground(a), P.ground(b)) + 4.6
	var yaw := M.yaw_of(-n)
	var t := M.xf(M.v3(c, (y + top) * 0.5), yaw)
	mb.add_box(M.mat("wash"), t, Vector3(L, top - y, 0.8), 0.5, Color(0.95, 0.92, 0.86))
	mb.add_box(M.mat("lime"), M.xf(M.v3(c, top + 0.1), yaw), Vector3(L + 0.2, 0.25, 1.0), 0.6, Color(0.88, 0.86, 0.82), false)
	M.box(cols, t, Vector3(L, top - y, 0.8))
	if L >= 2.4:
		var door := M.xf(M.v3(c - n * 0.42, P.ground(c)), yaw)
		Buildings.panel_door(mb, door, minf(L - 1.0, 1.8), 2.4, Buildings.door_leaf(Color(0.42, 0.3, 0.22)), M.mat("lime"))


# --------------------------------------------------------------------------
## The district's floors: a grid over each one's rect at the designed ground, one surface a texture, their faces
## the collider.
static func _floors(out: Array) -> void:
	var mb := MeshBuilder.new()
	var shapes: Array = []
	for f in P.FLOORS:
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
				var p: Array = c.map(func(q): return M.v3(q, P.ground(q)))
				var shade := 0.94 + 0.06 * float((ix * 7 + iz * 13) % 3) / 2.0
				mb.add_quad(m, p[0], p[1], p[2], p[3], c[0] * uv, c[1] * uv, c[2] * uv, c[3] * uv, Color(shade, shade, shade), Vector3.UP)
				faces.append_array([p[0], p[1], p[2], p[0], p[2], p[3]])
		shapes.append(faces)
	_piece(out, "Floors", mb, [], NEAR, false, shapes)
