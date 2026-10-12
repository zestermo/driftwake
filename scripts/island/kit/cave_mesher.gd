class_name CaveMesher
extends RefCounted
## A cave system as one rock mass, worked out as numbers only (safe on a worker
## thread): domed rooms with flat floors joined by tunnels, hollowed out of a hull
## that follows them and runs on down into the ground. Distance fields meshed by
## surface nets, every facet flat with its own normal and projected UVs (the brood
## cave's look). The cave's own space: shapes and results relative to its origin.
##   room: [cx, cz, floor y, radius, height]
##   seg:  [ax, az, ay, bx, bz, by, half width, height, hull (1/0)]
##         (no hull: a mouth, the tunnel cutting out through the rock round it)

const T := 3.0
const ROUGH := 0.7
const CRAG := 2.4

var rooms: Array = []
var segs: Array = []
## The shapes the fields look at (all of them, or a grid column's neighbours while meshing).
var _rs: Array = []
var _ss: Array = []
var _n := FastNoiseLite.new()
var _crag := FastNoiseLite.new()


static func make(room_list: Array, seg_list: Array, seed_value: int) -> CaveMesher:
	var m := CaveMesher.new()
	m.rooms = room_list
	m.segs = seg_list
	m._rs = room_list
	m._ss = seg_list
	m._n.seed = seed_value
	m._n.frequency = 0.16
	m._n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	m._crag.seed = seed_value + 911
	m._crag.frequency = 0.07
	m._crag.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	m._crag.fractal_octaves = 2
	return m


## Inside the hollow (< 0), the distance to its walls roughly.
func cav(x: float, y: float, z: float) -> float:
	var best := 1e9
	var rough := _n.get_noise_3d(x, y, z) * ROUGH
	for r in _rs:
		var dx: float = x - r[0]
		var dz: float = z - r[1]
		var l := sqrt(dx * dx + dz * dz)
		if l > float(r[3]) + 4.0:
			continue
		var qy := maxf(y - float(r[2]), 0.0) / float(r[4])
		var e := sqrt(pow(l / float(r[3]), 2.0) + qy * qy) - 1.0
		best = minf(best, maxf(e * minf(r[3], r[4]) + rough, float(r[2]) - y))
	for s in _ss:
		var ax: float = s[0]
		var az: float = s[1]
		var abx: float = float(s[3]) - ax
		var abz: float = float(s[4]) - az
		var t := clampf(((x - ax) * abx + (z - az) * abz) / maxf(abx * abx + abz * abz, 0.0001), 0.0, 1.0)
		var dx := x - (ax + abx * t)
		var dz := z - (az + abz * t)
		var l := sqrt(dx * dx + dz * dz)
		var w: float = s[6]
		if l > w + 4.0:
			continue
		var fy := lerpf(s[2], s[5], t)
		var h: float = s[7]
		var qy := maxf(y - fy - h * 0.35, 0.0) / (h * 0.65)
		var e := sqrt(pow(l / w, 2.0) + qy * qy) - 1.0
		best = minf(best, maxf(e * minf(w, h * 0.65) + rough, fy - y))
	return best


## Inside the hull (< 0): the rooms and tunnels grown by T, run down into the ground, crags on top.
func outer(x: float, y: float, z: float) -> float:
	var acc := 1e9
	for r in _rs:
		var dx: float = x - r[0]
		var dz: float = z - r[1]
		var hr: float = float(r[3]) + T
		var l := sqrt(dx * dx + dz * dz)
		if l > hr + 10.0:
			continue
		var hh: float = float(r[4]) + T
		var qy := maxf(y - float(r[2]), 0.0) / hh
		acc = _smin(acc, (sqrt(pow(l / hr, 2.0) + qy * qy) - 1.0) * minf(hr, hh), 5.0)
	for s in _ss:
		if float(s[8]) == 0.0:
			continue
		var ax: float = s[0]
		var az: float = s[1]
		var abx: float = float(s[3]) - ax
		var abz: float = float(s[4]) - az
		var t := clampf(((x - ax) * abx + (z - az) * abz) / maxf(abx * abx + abz * abz, 0.0001), 0.0, 1.0)
		var dx := x - (ax + abx * t)
		var dz := z - (az + abz * t)
		var w: float = float(s[6]) + T
		var l := sqrt(dx * dx + dz * dz)
		if l > w + 10.0:
			continue
		var fy := lerpf(s[2], s[5], t)
		var hh: float = float(s[7]) + T
		var qy := maxf(y - fy, 0.0) / hh
		acc = _smin(acc, (sqrt(pow(l / w, 2.0) + qy * qy) - 1.0) * minf(w, hh), 5.0)
	return acc + _crag.get_noise_3d(x, y, z) * CRAG


func rock(x: float, y: float, z: float) -> float:
	var o := outer(x, y, z)
	if o > 2.0:
		return o
	return maxf(o, -cav(x, y, z))


static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


## The roof over (x, z) above floor y (where the hollow ends going up).
func ceiling(x: float, z: float, y: float) -> float:
	var h := y + 0.5
	while h < y + 30.0 and cav(x, h, z) < 0.0:
		h += 0.25
	return h


## Where the wall is going out from (x, z) at height y along bearing `a`:
## [point, normal into the hollow], or [] if it's further than `reach`.
func wall(x: float, z: float, y: float, a: float, reach: float) -> Array:
	var d := Vector3(cos(a), 0.0, sin(a))
	var r := 0.5
	while r < reach:
		var p := Vector3(x, y, z) + d * r
		if cav(p.x, p.y, p.z) >= 0.0:
			var e := 0.2
			var g := Vector3(cav(p.x + e, p.y, p.z) - cav(p.x - e, p.y, p.z), cav(p.x, p.y + e, p.z) - cav(p.x, p.y - e, p.z),
				cav(p.x, p.y, p.z + e) - cav(p.x, p.y, p.z - e))
			return [p - d * 0.1, -g.normalized() if g.length_squared() > 1e-8 else -d]
		r += 0.25
	return []


## The mesh: {"surfaces": {key: {v, n, uv, c}}, "faces" (collision), "ledges"
## ([centre, normal] of flat facets outside, for plants), "tris"}. Keys: floor and
## wall inside; turf, moss and rock outside. `y_min` is under the ground everywhere.
func mesh(cell: float, y_min: float) -> Dictionary:
	var lo := Vector3(INF, y_min, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for r in rooms:
		var e: float = float(r[3]) + T + CRAG + 3.0
		lo.x = minf(lo.x, float(r[0]) - e)
		lo.z = minf(lo.z, float(r[1]) - e)
		hi.x = maxf(hi.x, float(r[0]) + e)
		hi.z = maxf(hi.z, float(r[1]) + e)
		hi.y = maxf(hi.y, float(r[2]) + float(r[4]) + T + CRAG + 2.0)
	for s in segs:
		var e: float = float(s[6]) + T + CRAG + 3.0
		for q in [Vector2(s[0], s[1]), Vector2(s[3], s[4])]:
			lo.x = minf(lo.x, q.x - e)
			lo.z = minf(lo.z, q.y - e)
			hi.x = maxf(hi.x, q.x + e)
			hi.z = maxf(hi.z, q.y + e)
		hi.y = maxf(hi.y, maxf(s[2], s[5]) + float(s[7]) + T + CRAG + 2.0)
	var nx := int(ceil((hi.x - lo.x) / cell))
	var ny := int(ceil((hi.y - lo.y) / cell))
	var nz := int(ceil((hi.z - lo.z) / cell))
	var sx := nx + 1
	var sxy := sx * (ny + 1)
	var vals := PackedFloat32Array()
	vals.resize(sxy * (nz + 1))
	# (a column at a time, looking only at the shapes near it: both fields skip anything further anyway)
	for k in range(nz + 1):
		var z := lo.z + k * cell
		for i in range(sx):
			var x := lo.x + i * cell
			_rs = rooms.filter(func(r): return Vector2(x - r[0], z - r[1]).length() < float(r[3]) + T + 11.0)
			_ss = segs.filter(func(s): return Geometry2D.get_closest_point_to_segment(Vector2(x, z), Vector2(s[0], s[1]), Vector2(s[3], s[4])).distance_to(Vector2(x, z)) < float(s[6]) + T + 11.0)
			for j in range(ny + 1):
				vals[k * sxy + j * sx + i] = rock(x, lo.y + j * cell, z)
	_rs = rooms
	_ss = segs
	# one vertex per cell the surface passes through: the mean of its edges' crossings
	var cell_v := PackedInt32Array()
	cell_v.resize(nx * ny * nz)
	cell_v.fill(-1)
	var verts := PackedVector3Array()
	var corner := []
	for c in range(8):
		corner.append(Vector3i(c & 1, (c >> 1) & 1, (c >> 2) & 1))
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var cv := PackedFloat32Array()
	cv.resize(8)
	for k in range(nz):
		for j in range(ny):
			for i in range(nx):
				var neg := 0
				for c in range(8):
					var o: Vector3i = corner[c]
					cv[c] = vals[(k + o.z) * sxy + (j + o.y) * sx + i + o.x]
					if cv[c] < 0.0:
						neg += 1
				if neg == 0 or neg == 8:
					continue
				var sum := Vector3.ZERO
				var cnt := 0
				for e in edges:
					var v0: float = cv[e[0]]
					var v1: float = cv[e[1]]
					if (v0 < 0.0) == (v1 < 0.0):
						continue
					var t := v0 / (v0 - v1)
					sum += Vector3(corner[e[0]]).lerp(Vector3(corner[e[1]]), t)
					cnt += 1
				cell_v[(k * ny + j) * nx + i] = verts.size()
				verts.append(lo + (Vector3(i, j, k) + sum / cnt) * cell)
	# each vertex inside the hollow's skin or the hull's
	var inner := PackedByteArray()
	inner.resize(verts.size())
	for vi in range(verts.size()):
		var p := verts[vi]
		inner[vi] = 1 if absf(cav(p.x, p.y, p.z)) < absf(outer(p.x, p.y, p.z)) else 0
	var out := {"surfaces": {}, "faces": PackedVector3Array(), "ledges": [], "tris": 0}
	# a quad round every grid edge the surface crosses, facing out of the rock
	for k in range(nz + 1):
		for j in range(ny + 1):
			for i in range(nx + 1):
				var v0 := vals[k * sxy + j * sx + i]
				if i < nx and j > 0 and j < ny and k > 0 and k < nz:
					var v1 := vals[k * sxy + j * sx + i + 1]
					if (v0 < 0.0) != (v1 < 0.0):
						_quad(out, verts, inner, cell_v[((k - 1) * ny + j - 1) * nx + i], cell_v[((k - 1) * ny + j) * nx + i],
							cell_v[(k * ny + j) * nx + i], cell_v[(k * ny + j - 1) * nx + i], Vector3.RIGHT * (1.0 if v0 < 0.0 else -1.0))
				if j < ny and i > 0 and i < nx and k > 0 and k < nz:
					var v1 := vals[k * sxy + (j + 1) * sx + i]
					if (v0 < 0.0) != (v1 < 0.0):
						_quad(out, verts, inner, cell_v[((k - 1) * ny + j) * nx + i - 1], cell_v[((k - 1) * ny + j) * nx + i],
							cell_v[(k * ny + j) * nx + i], cell_v[(k * ny + j) * nx + i - 1], Vector3.UP * (1.0 if v0 < 0.0 else -1.0))
				if k < nz and i > 0 and i < nx and j > 0 and j < ny:
					var v1 := vals[(k + 1) * sxy + j * sx + i]
					if (v0 < 0.0) != (v1 < 0.0):
						_quad(out, verts, inner, cell_v[(k * ny + j - 1) * nx + i - 1], cell_v[(k * ny + j - 1) * nx + i],
							cell_v[(k * ny + j) * nx + i], cell_v[(k * ny + j) * nx + i - 1], Vector3.BACK * (1.0 if v0 < 0.0 else -1.0))
	return out


func _quad(out: Dictionary, verts: PackedVector3Array, inner: PackedByteArray, a: int, b: int, c: int, d: int, want: Vector3) -> void:
	if verts[a].distance_squared_to(verts[c]) <= verts[b].distance_squared_to(verts[d]):
		_tri(out, verts, inner, a, b, c, want)
		_tri(out, verts, inner, a, c, d, want)
	else:
		_tri(out, verts, inner, a, b, d, want)
		_tri(out, verts, inner, b, c, d, want)


func _tri(out: Dictionary, verts: PackedVector3Array, inner: PackedByteArray, ia: int, ib: int, ic: int, want: Vector3) -> void:
	var a := verts[ia]
	var b := verts[ib]
	var c := verts[ic]
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-8:
		return
	n = n.normalized()
	if n.dot(want) < 0.0:
		n = -n
	# (Godot's front face: (c - a) x (b - a) points out)
	if (c - a).cross(b - a).dot(n) < 0.0:
		var t := b
		b = c
		c = t
	var m := (a + b + c) / 3.0
	var inside := int(inner[ia]) + int(inner[ib]) + int(inner[ic]) >= 2
	var key: String
	var uv := 0.4
	var shade := 0.78 + 0.22 * (0.5 + 0.5 * sin(m.y * 1.9 + 2.0 * _n.get_noise_2d(m.x * 4.0, m.z * 4.0)))
	if inside:
		key = "floor" if n.y > 0.7 else "wall"
	else:
		var patch := _crag.get_noise_3d(m.x * 2.5, m.y * 2.5, m.z * 2.5)
		key = "turf" if n.y > 0.86 and patch > -0.15 else ("moss" if n.y > 0.6 and patch > -0.35 else "rock")
		uv = 0.32
		if n.y > 0.85 and (out["ledges"] as Array).size() < 400:
			out["ledges"].append([m, n])
	if not out["surfaces"].has(key):
		out["surfaces"][key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray()}
	var s: Dictionary = out["surfaces"][key]
	var off := Vector2(fposmod(m.x * 7.31 + m.z * 3.17, 1.0), fposmod(m.y * 5.13 + m.x * 2.71, 1.0))
	var col := Color(shade, shade, shade)
	s["v"].append_array([a, b, c])
	s["n"].append_array([n, n, n])
	s["uv"].append_array([_tuv(a, n, uv, off), _tuv(b, n, uv, off), _tuv(c, n, uv, off)])
	s["c"].append_array([col, col, col])
	out["faces"].append_array([a, b, c])
	out["tris"] = int(out["tris"]) + 1


static func _tuv(p: Vector3, n: Vector3, s: float, off: Vector2) -> Vector2:
	var an := n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z) * s + off
	if an.x >= an.z:
		return Vector2(p.z, -p.y) * s + off
	return Vector2(p.x, -p.y) * s + off
