class_name Coast
extends RefCounted
## Where an island meets the sea. Off a beach, a sandy shelf you can wade out on
## (`shelf`, in the island's height function). Where the land stands too high
## to run down into a beach, a sea cliff (`cliffs` on the built height grid): the
## top raised to the water's edge, the foot cut deep, and a jagged rock wall along
## the waterline with scree, ledges to climb out on and the odd sea stack (`rocks`
## as data on any thread, `build` makes the nodes).

const SHELF_MID := 9.0
const SHELF_END := 40.0
const SHELF_DROP := 30.0
## Land this high within CLIFF_REACH of the waterline makes a cliff (fully at CLIFF_HI).
const CLIFF_LO := 3.0
const CLIFF_HI := 4.5
const CLIFF_REACH := 6.6
const FOOT := -4.5
const FAR := 45.0
const CHUNK := 64.0
const TINT := Color(0.78, 0.74, 0.7)


## The seabed `t` m out from the waterline with the shelf in (weight `w`): 0.5 m at
## the waterline, knee deep (-0.35) at 9 m, waist deep (-0.9) at 40 m, then down to `floor_y`.
## (shallower further out and the swell's troughs bare the sand in patches)
static func shelf(h: float, t: float, w: float, floor_y: float) -> float:
	if w <= 0.0 or t < 0.0:
		return h
	var s: float
	if t < SHELF_MID:
		s = lerpf(0.5, -0.35, t / SHELF_MID)
	elif t < SHELF_END:
		s = lerpf(-0.35, -0.9, (t - SHELF_MID) / (SHELF_END - SHELF_MID))
	else:
		s = lerpf(-0.9, floor_y, _smooth(SHELF_END, SHELF_END + SHELF_DROP, t))
	return lerpf(h, maxf(h, s), w)


## Cuts the cliffs into a height grid ((res + 1)^2 vertices `cell` apart from
## (-half, -half)). `allow` (p -> 0..1) keeps them off harbours and the like,
## `bare` (p -> height) is the ground without the shelf, given back off a cliff.
## Returns {"heights": the grid with the cliffs, "rock": the clifftop splat per vertex,
## "cols": the rock wall's columns [[centre, top, to_sea, k, ix, iz]]}.
static func cliffs(src: PackedFloat32Array, res: int, cell: float, half: float, allow: Callable, bare: Callable) -> Dictionary:
	var n := res + 1
	var heights := src.duplicate()
	var raise := PackedFloat32Array()
	var foot := PackedFloat32Array()
	var deep := PackedFloat32Array()
	var near := PackedFloat32Array()
	raise.resize(n * n)
	foot.resize(n * n)
	deep.resize(n * n)
	near.resize(n * n)
	near.fill(FAR)
	var reach := int(ceil(FAR / cell))
	var offs: Array = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var d := Vector2(dx, dz).length() * cell
			if d <= FAR:
				offs.append([dx, dz, d])
	for iz in range(1, res):
		for ix in range(1, res):
			var i := iz * n + ix
			if src[i] <= 0.0 or (src[i - 1] > 0.0 and src[i + 1] > 0.0 and src[i - n] > 0.0 and src[i + n] > 0.0):
				continue
			var top := _top(src, n, res, ix, iz, cell)
			if top <= CLIFF_LO:
				continue
			var k := _smooth(CLIFF_LO, CLIFF_HI, top) * float(allow.call(Vector2(-half + ix * cell, -half + iz * cell)))
			if k <= 0.01:
				continue
			for o in offs:
				var jx: int = ix + o[0]
				var jz: int = iz + o[1]
				if jx < 0 or jz < 0 or jx > res or jz > res:
					continue
				var j := jz * n + jx
				var d: float = o[2]
				if src[j] > 0.0:
					if d < 7.5:
						raise[j] = maxf(raise[j], k * (1.0 - _smooth(4.5, 7.5, d)))
				else:
					deep[j] = maxf(deep[j], k * (1.0 - _smooth(28.0, FAR, d)))
					if d < 24.0:
						foot[j] = maxf(foot[j], k * (1.0 - _smooth(6.0, 24.0, d)))
						near[j] = minf(near[j], d)
	var rock := PackedFloat32Array()
	rock.resize(n * n)
	for iz in range(n):
		for ix in range(n):
			var i := iz * n + ix
			var h := src[i]
			if h > 0.0:
				if raise[i] > 0.0:
					heights[i] = lerpf(h, maxf(h, _top(src, n, res, ix, iz, cell)), raise[i])
					rock[i] = raise[i]
			elif deep[i] > 0.0:
				h = lerpf(h, minf(h, float(bare.call(Vector2(-half + ix * cell, -half + iz * cell)))), deep[i])
				if foot[i] > 0.0:
					h = lerpf(h, minf(h, FOOT - near[i] * 0.25), foot[i])
				heights[i] = h
	var cols: Array = []
	for iz in range(1, res):
		for ix in range(1, res):
			var i := iz * n + ix
			if raise[i] < 0.3 or heights[i] <= 0.0:
				continue
			if heights[i - 1] > 0.0 and heights[i + 1] > 0.0 and heights[i - n] > 0.0 and heights[i + n] > 0.0:
				continue
			var to_sea := Vector2.ZERO
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if heights[i + dz * n + dx] <= 0.0:
						to_sea += Vector2(dx, dz).normalized()
			if to_sea.length() < 0.1:
				continue
			to_sea = to_sea.normalized()
			cols.append([Vector2(-half + ix * cell, -half + iz * cell) + to_sea * cell * 0.5, heights[i], to_sea, raise[i], ix, iz])
	return {"heights": heights, "rock": rock, "cols": cols}


## The highest ground within CLIFF_REACH of a vertex.
static func _top(src: PackedFloat32Array, n: int, res: int, ix: int, iz: int, cell: float) -> float:
	var top := src[iz * n + ix]
	var r := int(CLIFF_REACH / cell)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var jx := ix + dx
			var jz := iz + dz
			if jx < 0 or jz < 0 or jx > res or jz > res or Vector2(dx, dz).length() * cell > CLIFF_REACH:
				continue
			top = maxf(top, src[jz * n + jx])
	return top


## The cliffs' rock as arrays, a set per CHUNK square (data: any thread).
## `ground` (p -> seabed) stands the sea stacks on the bottom.
## {Vector2i: [vertices, normals, colours, uvs, collider faces]}
static func rocks(cols: Array, seed_value: int, ground: Callable) -> Dictionary:
	var out := {}
	for c in cols:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, c[4], c[5]])
		var at: Vector2 = c[0]
		var key := Vector2i(floori(at.x / CHUNK), floori(at.y / CHUNK))
		if not out.has(key):
			out[key] = [[], [], [], [], []]
		var a: Array = out[key]
		var top: float = c[1]
		var k: float = c[3]
		var to_sea: Vector2 = c[2]
		var along := Vector2(-to_sea.y, to_sea.x)
		var shade := rng.randf_range(0.86, 1.05)
		var crown := rng.randf_range(1.2, 3.0) if rng.randf() < 0.18 else rng.randf_range(-0.15, 0.5)
		var r := rng.randf_range(1.7, 2.7) * (0.8 if crown > 1.0 else 1.0)
		var cc := at + to_sea * rng.randf_range(-0.3, 1.2)
		_column(a, rng, cc, FOOT - 1.5, top + crown, r, rng.randi_range(6, 7), shade, true)
		if k > 0.5 and rng.randf() < 0.14:
			_ledge(a, rng, cc + to_sea * (r * 1.15 + rng.randf_range(1.0, 1.3)), to_sea, along, rng.randf_range(0.55, 0.85), shade)
		if k > 0.6 and rng.randf() < 0.035:
			var sp := at + to_sea * rng.randf_range(9.0, 17.0) + along * rng.randf_range(-4.0, 4.0)
			var g := float(ground.call(sp))
			if g < -2.0:
				_column(a, rng, sp, g - 1.0, rng.randf_range(3.0, minf(11.0, top + 2.0)), rng.randf_range(1.6, 3.0), 6, shade * 0.95, true)
		for s in range(rng.randi_range(0, 3)):
			var q := at + to_sea * rng.randf_range(2.4, 5.0) + along * rng.randf_range(-1.6, 1.6)
			_column(a, rng, q, rng.randf_range(-3.0, -1.5), rng.randf_range(-0.6, 0.35), rng.randf_range(0.35, 0.9), 5, shade * 0.9, false)
	for key in out.keys():
		var a: Array = out[key]
		out[key] = [PackedVector3Array(a[0]), PackedVector3Array(a[1]), PackedColorArray(a[2]), PackedVector2Array(a[3]), PackedVector3Array(a[4])]
	return out


## The rock's nodes from `rocks`: a mesh and a collider per square, under one body.
static func build(parent: Node3D, chunks: Dictionary) -> void:
	if chunks.is_empty():
		return
	var mat := PSXMat.lit("rock", TINT, {"affine": 0.5})
	var body := StaticBody3D.new()
	body.name = "CoastRocks"
	body.collision_layer = 1
	body.collision_mask = 0
	for key in chunks.keys():
		var c: Array = chunks[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = c[0]
		arr[Mesh.ARRAY_NORMAL] = c[1]
		arr[Mesh.ARRAY_COLOR] = c[2]
		arr[Mesh.ARRAY_TEX_UV] = c[3]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = "Rocks_%d_%d" % [key.x, key.y]
		mi.mesh = mesh
		mi.visibility_range_end = 900.0
		body.add_child(mi)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(c[4])
		var cs := CollisionShape3D.new()
		cs.name = "Shape_%d_%d" % [key.x, key.y]
		cs.shape = shape
		body.add_child(cs)
	parent.add_child(body)


## A jagged rock column from y0 to y1 round `at`, wider at the foot, a low cone on top.
static func _column(a: Array, rng: RandomNumberGenerator, at: Vector2, y0: float, y1: float, r: float, sides: int, shade: float, solid: bool) -> void:
	var rings := clampi(2 + int((y1 - y0) / 4.0), 2, 6)
	var phase := rng.randf() * TAU
	var pts: Array = []
	for j in range(rings + 1):
		var f := float(j) / rings
		var y := lerpf(y0, y1, f) + (rng.randf_range(-0.5, 0.5) if j > 0 and j < rings else 0.0)
		var rr := r * lerpf(1.25, 0.78, f)
		var mid := at + Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
		var row: Array = []
		for s in range(sides):
			var q := mid + Vector2.from_angle(phase + TAU * (s + rng.randf_range(-0.2, 0.2)) / sides) * rr * rng.randf_range(0.8, 1.2)
			row.append(Vector3(q.x, y, q.y))
		pts.append(row)
	var c3 := Vector3(at.x, 0.0, at.y)
	for j in range(rings):
		for s in range(sides):
			var s2 := (s + 1) % sides
			var p0: Vector3 = pts[j][s]
			var p1: Vector3 = pts[j][s2]
			var p2: Vector3 = pts[j + 1][s2]
			var p3: Vector3 = pts[j + 1][s]
			var out := (p0 + p1 + p2 + p3) * 0.25 - c3
			out.y = 0.0
			_tri(a, p0, p1, p2, out, shade, solid)
			_tri(a, p0, p2, p3, out, shade, solid)
	var cap := Vector3(at.x, y1 + 0.15, at.y)
	var last: Array = pts[rings]
	for s in range(sides):
		_tri(a, cap, last[s], last[(s + 1) % sides], Vector3.UP, shade, solid)


## A flat-topped slab at the cliff's foot, `y_top` over the sea: room to climb out and stand.
static func _ledge(a: Array, rng: RandomNumberGenerator, c: Vector2, to_sea: Vector2, along: Vector2, y_top: float, shade: float) -> void:
	var ring: Array = []
	var foot: Array = []
	for s in range(6):
		var ang := TAU * s / 6.0
		var off := along * cos(ang) * 1.9 + to_sea * sin(ang) * 1.5
		off *= rng.randf_range(0.9, 1.1)
		ring.append(Vector3(c.x + off.x, y_top, c.y + off.y))
		foot.append(Vector3(c.x + off.x * 1.3, -3.0, c.y + off.y * 1.3))
	var c3 := Vector3(c.x, y_top, c.y)
	for s in range(6):
		var s2 := (s + 1) % 6
		var out: Vector3 = (ring[s] + ring[s2]) * 0.5 - c3
		out.y = 0.0
		_tri(a, foot[s], foot[s2], ring[s2], out, shade, true)
		_tri(a, foot[s], ring[s2], ring[s], out, shade, true)
		_tri(a, c3, ring[s], ring[s2], Vector3.UP, shade, true)


## One flat-shaded facet facing `hint`, wound as Godot's front faces, shaded in
## strata and darker where the sea wets it; `solid` ones go in the collider too.
static func _tri(a: Array, p0: Vector3, p1: Vector3, p2: Vector3, hint: Vector3, shade: float, solid: bool) -> void:
	var nrm := (p1 - p0).cross(p2 - p0)
	if nrm.length_squared() < 1e-8:
		return
	nrm = nrm.normalized()
	if nrm.dot(hint) < 0.0:
		nrm = -nrm
	else:
		var sw := p1
		p1 = p2
		p2 = sw
	var m := (p0 + p1 + p2) / 3.0
	var band := 0.82 + 0.18 * sin(m.y * 1.9 + m.x * 0.13 + m.z * 0.11)
	var wet := 0.75 if m.y < 0.35 else 1.0
	var col := Color(1, 1, 1) * shade * band * wet
	col.a = 1.0
	var off := Vector2(fposmod(m.x * 7.31 + m.z * 3.17, 1.0), fposmod(m.y * 5.13 + m.x * 2.71, 1.0))
	for p in [p0, p1, p2]:
		a[0].append(p)
		a[1].append(nrm)
		a[2].append(col)
		a[3].append(_uv(p, nrm, off))
		if solid:
			a[4].append(p)


## Texture coordinates projected along the facet's main axis (as Redtide's rock).
static func _uv(p: Vector3, n: Vector3, off: Vector2) -> Vector2:
	var an := n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z) * 0.3 + off
	if an.x >= an.z:
		return Vector2(p.z, -p.y) * 0.3 + off
	return Vector2(p.x, -p.y) * 0.3 + off


static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
