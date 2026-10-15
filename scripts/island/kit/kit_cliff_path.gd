class_name KitCliffPath
extends RefCounted
## A path cut into the sea cliffs round a hilltop (Grell's den on Brinehollow): a shelf
## along the face with the rock leaning out over it here and there, gaps that drop
## to the sea, a buttress with a cave room the path runs through, a broken bridge with
## a chain to swing across on, and a cleft up onto the top. One rock mass worked out
## as a distance field (the cliff band, the shelf, the buttress and the cleft's walls,
## the cave hollowed out) and meshed by surface nets, the brood cave's flat facets.
## Laid out on bearings round `c` (degrees from +x toward +z, rising clockwise seen
## from above), from the spec:
##   keys: [bearing, radius, floor y, half width, headroom, overhang] (linear between)
##   gaps: [from, to, "jump" / "swing"]   sea: bearing past which the drop is sea
##   cave: {"at", "out" (m seaward of the line), "r", "h", "tunnels": [[from, to]...]}
##   cleft: {"from": bearing, "to": island point on the top, "y": the top}
##   rails: [[from, to]...]   bridge: the "swing" gap's chain {"at": 0..1 along, "y", "len"}
## plan, carve (the terrain grid) and mesh are data (mesh on a worker); build makes the nodes.

const STEP := 0.25
const PAD := 10.0
const Y_MIN := -9.0
const CELL := 1.0
const T := 3.0
const CRAG := 2.2
const SEA_FLOOR := -6.5
const DEG := PI / 180.0
const TUNNEL_W := 1.3
const TUNNEL_H := 3.6

var c := Vector2.ZERO
var keys: Array = []
var gaps: Array = []
var rails: Array = []
var th0 := 0.0
var th1 := 0.0
var sea_from := 0.0
var cave: Dictionary = {}
var bridge: Dictionary = {}
## Hollows: rooms [cx, cz, floor y, r, h], segs [ax, az, ay, bx, bz, by, half width, h, inside (1: the cave's)].
var cav_rooms: Array = []
var cav_segs: Array = []
## Solid rock round them: the same shapes, grown by T.
var hull_rooms: Array = []
var hull_segs: Array = []
## The cleft: [from (Vector3 on the ledge), to (Vector3 on the top)].
var cleft: Array = []
var _t0 := 0.0
var _nt := 0
var _r := PackedFloat32Array()
var _y := PackedFloat32Array()
var _hw := PackedFloat32Array()
var _h := PackedFloat32Array()
var _ov := PackedFloat32Array()
var _cap := PackedFloat32Array()
var _n := FastNoiseLite.new()
var _crag := FastNoiseLite.new()
## Built (build): the bugs' nest and the chain.
var nest: ScuttlebugNest
var chain: ChainSwing


# ==========================================================================
# The plan (data)
# ==========================================================================
## `ground` (p -> height): the land before carve, for the cliff's top.
static func plan(centre: Vector2, spec: Dictionary, ground: Callable, seed_value: int) -> KitCliffPath:
	var k := KitCliffPath.new()
	k.c = centre
	k.keys = spec["keys"]
	k.gaps = spec["gaps"]
	k.rails = spec["rails"]
	k.sea_from = float(spec["sea"])
	k.cave = spec["cave"]
	k.bridge = spec["bridge"]
	k.th0 = float(k.keys[0][0])
	k.th1 = float(k.keys[k.keys.size() - 1][0])
	k._n.seed = seed_value
	k._n.frequency = 0.22
	k._n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	k._crag.seed = seed_value + 911
	k._crag.frequency = 0.08
	k._crag.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	k._crag.fractal_octaves = 2
	k._t0 = k.th0 - PAD
	k._nt = int((k.th1 - k.th0 + PAD * 2.0) / STEP) + 1
	k._r.resize(k._nt)
	k._y.resize(k._nt)
	k._hw.resize(k._nt)
	k._h.resize(k._nt)
	k._ov.resize(k._nt)
	k._cap.resize(k._nt)
	for i in range(k._nt):
		var th := k._t0 + i * STEP
		var e := k._key(th)
		k._r[i] = e[0]
		k._y[i] = e[1]
		k._hw[i] = e[2]
		k._h[i] = e[3]
		k._ov[i] = e[4]
		var wall_in: float = -e[2] - 0.35
		var top := -INF
		for u in [wall_in - 3.0, wall_in - 4.0, wall_in - 5.0]:
			var q: Vector2 = centre + Vector2.from_angle(th * DEG) * (float(e[0]) + u)
			top = maxf(top, float(ground.call(q)))
		k._cap[i] = top
	# the cave: a room in a buttress, short tunnels in and out along the line
	var cv: Dictionary = k.cave
	var rc := k.point(float(cv["at"]), float(cv["out"]))
	var fy := k.floor_at(float(cv["at"]))
	k.cav_rooms.append([rc.x, rc.y, fy, float(cv["r"]), float(cv["h"])])
	k.hull_rooms.append([rc.x, rc.y, fy, float(cv["r"]), float(cv["h"])])
	for tn in cv["tunnels"]:
		var a := k.point(float(tn[0]))
		var b := k.point(float(tn[1]))
		k.cav_segs.append([a.x, a.y, k.floor_at(float(tn[0])), b.x, b.y, k.floor_at(float(tn[1])), TUNNEL_W, TUNNEL_H, 1])
	# the cleft up onto the top: open to the sky, walled with rock
	var cl: Dictionary = spec["cleft"]
	var ca := k.point(float(cl["from"]))
	var cy := k.floor_at(float(cl["from"]))
	var cb: Vector2 = cl["to"]
	var ty := float(cl["y"])
	var on := (cb - ca).normalized()
	var beyond := cb + on * 5.0
	k.cleft = [Vector3(ca.x, cy, ca.y), Vector3(cb.x, ty, cb.y)]
	k.cav_segs.append([ca.x, ca.y, cy, cb.x, cb.y, ty, 1.3, 12.0, 0])
	k.cav_segs.append([cb.x, cb.y, ty, beyond.x, beyond.y, ty, 1.3, 12.0, 0])
	var ch := ca - on * 1.5
	k.hull_segs.append([ch.x, ch.y, cy, cb.x, cb.y, ty, 1.3, 2.4])
	return k


## Keys interpolated at bearing th (clamped at the ends): [radius, floor, half width, headroom, overhang].
func _key(th: float) -> Array:
	if th <= float(keys[0][0]):
		return (keys[0] as Array).slice(1)
	for j in range(keys.size() - 1):
		var a: Array = keys[j]
		var b: Array = keys[j + 1]
		if th <= float(b[0]):
			var t := (th - float(a[0])) / (float(b[0]) - float(a[0]))
			return [lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t), lerpf(a[4], b[4], t), lerpf(a[5], b[5], t)]
	return (keys[keys.size() - 1] as Array).slice(1)


func _lk(arr: PackedFloat32Array, th: float) -> float:
	var f := clampf((th - _t0) / STEP, 0.0, _nt - 1.001)
	var i := int(f)
	return lerpf(arr[i], arr[i + 1], f - i)


func radius_at(th: float) -> float:
	return _lk(_r, th)


func floor_at(th: float) -> float:
	return _lk(_y, th)


func half_at(th: float) -> float:
	return _lk(_hw, th)


## Island point on the path's line at bearing th, `off` m seaward of it.
func point(th: float, off := 0.0) -> Vector2:
	return c + Vector2.from_angle(th * DEG) * (radius_at(th) + off)


## The path's floor at bearing th (island space, on its line).
func floor_point(th: float, off := 0.0) -> Vector3:
	var q := point(th, off)
	return Vector3(q.x, floor_at(th), q.y)


## Along the path at th (island space, level).
func tangent(th: float) -> Vector2:
	return (point(th + 0.2) - point(th - 0.2)).normalized()


## Bearing of island point p from the centre, unwrapped to the path's range.
func bearing(p: Vector2) -> float:
	var th := rad_to_deg(atan2(p.y - c.y, p.x - c.x))
	if th < th0 - 120.0:
		th += 360.0
	return th


## The gap at bearing th, or [].
func gap_at(th: float) -> Array:
	for g in gaps:
		if th > float(g[0]) and th < float(g[1]):
			return g
	return []


## The gaps as the jumps they are: {"from", "to" (Vector3 floor at each lip), "len" (m), "rise", "kind", "dir" (Vector3)}.
func jumps() -> Array:
	var out: Array = []
	for g in gaps:
		var a := floor_point(float(g[0]))
		var b := floor_point(float(g[1]))
		var flat := Vector2(b.x - a.x, b.z - a.z)
		out.append({"from": a, "to": b, "len": flat.length(), "rise": b.y - a.y, "kind": g[2],
			"dir": Vector3(flat.x, 0.0, flat.y).normalized(), "at": [g[0], g[1]]})
	return out


## Floor points along the solid path every ~`step` m (no gaps), from the foot.
func route(step := 1.5) -> Array:
	var out: Array = []
	var th := th0
	while th <= th1:
		if gap_at(th).is_empty():
			out.append(floor_point(th))
		th += step / (radius_at(th) * DEG)
	return out


func _end(th: float) -> float:
	return _sm(th1, th1 + 4.0, th) + 1.0 - _sm(th0 - 4.0, th0, th)


func _sea(th: float) -> float:
	return _sm(sea_from - 6.0, sea_from + 6.0, th)


static func _sm(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


static func _seg_t(x: float, z: float, s: Array) -> float:
	var abx: float = float(s[3]) - float(s[0])
	var abz: float = float(s[4]) - float(s[1])
	return clampf(((x - float(s[0])) * abx + (z - float(s[1])) * abz) / maxf(abx * abx + abz * abz, 0.0001), 0.0, 1.0)


# ==========================================================================
# The terrain under it (data)
# ==========================================================================
## Cut the height grid ((res + 1)^2 vertices `cell` apart from (-half, -half)) away under
## the rock: down behind the cliff face and under the cave and cleft (hidden in the rock),
## down to the sea floor below the shelf where the drop is the sea. Returns the cut grid.
func carve(src: PackedFloat32Array, res: int, cell: float, half: float) -> PackedFloat32Array:
	var heights := src.duplicate()
	var n := res + 1
	var reach := 0.0
	for i in range(_nt):
		reach = maxf(reach, _r[i] + 12.0)
	var i0 := clampi(int((c.x - reach + half) / cell), 0, res)
	var i1 := clampi(int((c.x + reach + half) / cell) + 1, 0, res)
	var k0 := clampi(int((c.y - reach + half) / cell), 0, res)
	var k1 := clampi(int((c.y + reach + half) / cell) + 1, 0, res)
	for iz in range(k0, k1 + 1):
		for ix in range(i0, i1 + 1):
			var p := Vector2(-half + ix * cell, -half + iz * cell)
			var vi := iz * n + ix
			var h := heights[vi]
			var th := bearing(p)
			if th > _t0 and th < _t0 + (_nt - 1) * STEP:
				var hw := half_at(th)
				var u := p.distance_to(c) - radius_at(th)
				var wall_in := -hw - 0.35
				var along := 1.0 - minf(_end(th), 1.0)
				if along > 0.0 and u > wall_in - 4.5 and u < hw + 6.0:
					var behind := _sm(wall_in - 4.5, wall_in - 3.0, u)
					var tgt := minf(h, floor_at(th) - 1.5)
					var sea := _sea(th) * (1.0 - _sm(hw + 3.0, hw + 6.0, u)) * _sm(wall_in - 0.5, wall_in + 0.8, u)
					tgt = lerpf(tgt, minf(tgt, SEA_FLOOR), sea)
					h = lerpf(h, minf(h, tgt), behind * along)
			for r in hull_rooms:
				if p.distance_to(Vector2(r[0], r[1])) < float(r[3]) + 1.5:
					h = minf(h, float(r[2]) - 1.5)
			if not cleft.is_empty():
				var a: Vector3 = cleft[0]
				var b: Vector3 = cleft[1]
				var t := clampf((p - Vector2(a.x, a.z)).dot(Vector2(b.x - a.x, b.z - a.z)) / Vector2(b.x - a.x, b.z - a.z).length_squared(), 0.0, 1.0)
				if p.distance_to(Vector2(a.x, a.z).lerp(Vector2(b.x, b.z), t)) < 2.4:
					h = minf(h, lerpf(a.y, b.y, t) - 1.2)
			heights[vi] = h
	return heights


## Is p (island) where the path changed the land (plants there are left out)? `inland`:
## how far behind the cliff face it reaches.
func covers(p: Vector2, inland := 3.2) -> bool:
	if p.distance_to(c) > 64.0:
		return false
	var th := bearing(p)
	if th > th0 - 6.0 and th < th1 + 6.0:
		var u := p.distance_to(c) - radius_at(th)
		if u > -half_at(th) - 0.35 - inland and u < half_at(th) + 7.0:
			return true
	for r in hull_rooms:
		if p.distance_to(Vector2(r[0], r[1])) < float(r[3]) + T + CRAG + 1.0:
			return true
	for s in hull_segs:
		var t := _seg_t(p.x, p.y, s)
		if p.distance_to(Vector2(s[0], s[1]).lerp(Vector2(s[3], s[4]), t)) < float(s[6]) + T + CRAG + 1.0:
			return true
	return false


# ==========================================================================
# The rock's field
# ==========================================================================
## Rock (< 0) or air at an island point.
func rock(x: float, y: float, z: float) -> float:
	var v := _band(x, y, z)
	var o := _outer(x, y, z)
	if o < 8.0:
		v = _smin(v, o, 1.5)
	return maxf(v, -_cav(x, y, z, false))


## The cliff band (the face behind the path, leaning out over it in places, its top
## falling back into the land) and the shelf under the path, gaps cut through it.
func _band(x: float, y: float, z: float) -> float:
	var d := Vector2(x - c.x, z - c.y)
	var th := bearing(Vector2(x, z))
	var f := (th - _t0) / STEP
	if f < 0.0 or f > _nt - 1.001:
		return 50.0
	var i := int(f)
	var w := f - i
	var rr := lerpf(_r[i], _r[i + 1], w)
	var yf := lerpf(_y[i], _y[i + 1], w)
	var hw := lerpf(_hw[i], _hw[i + 1], w)
	var hh := lerpf(_h[i], _h[i + 1], w)
	var ov := lerpf(_ov[i], _ov[i + 1], w)
	var cap := lerpf(_cap[i], _cap[i + 1], w)
	var u := d.length() - rr
	var wall_in := -hw - 0.35
	var wall := wall_in + _n.get_noise_3d(x, y, z) * 0.45
	var top := yf + hh
	if y > top:
		var kk := y - top
		wall += ov * _sm(0.0, 0.9, kk) * (1.0 - _sm(1.8, 4.2, kk)) - maxf(kk - 2.2, 0.0) * 0.16
	elif y < yf - 0.3:
		wall -= minf(yf - 0.3 - y, 5.0) * 0.06
	wall -= _end(th) * 9.0
	var b := u - wall
	var capy := cap + 1.2 - maxf(wall_in - u - 2.5, 0.0) + _crag.get_noise_2d(x * 2.0, z * 2.0) * 0.8
	b = maxf(b, y - capy)
	if th < th0 or th > th1:
		return b
	var edge := hw + 0.28 + _n.get_noise_3d(x * 1.9 + 40.0, y * 1.9, z * 1.9) * 0.16 - maxf(yf - 0.25 - y, 0.0) * 0.7
	var a := maxf(u - edge, y - yf)
	var m := rr * DEG
	for g in gaps:
		var into := minf(th - float(g[0]), float(g[1]) - th) * m
		if into > -3.0:
			a = maxf(a, into - 0.25 + maxf(yf - y, 0.0) * 0.3)
	return _smin(a, b, 0.5)


## The buttress round the cave and the cleft's walls (CaveMesher's hull), crags on top.
func _outer(x: float, y: float, z: float) -> float:
	var acc := 1e9
	for r in hull_rooms:
		var hr: float = float(r[3]) + T
		var l := Vector2(x - r[0], z - r[1]).length()
		if l > hr + 10.0:
			continue
		var hh: float = float(r[4]) + T
		var qy := maxf(y - float(r[2]), 0.0) / hh
		acc = _smin(acc, (sqrt(pow(l / hr, 2.0) + qy * qy) - 1.0) * minf(hr, hh), 5.0)
	for s in hull_segs:
		var t := _seg_t(x, z, s)
		var l := Vector2(x, z).distance_to(Vector2(s[0], s[1]).lerp(Vector2(s[3], s[4]), t))
		var ww: float = float(s[6]) + T
		if l > ww + 10.0:
			continue
		var fy := lerpf(s[2], s[5], t)
		var hh: float = float(s[7]) + T
		var qy := maxf(y - fy, 0.0) / hh
		acc = _smin(acc, (sqrt(pow(l / ww, 2.0) + qy * qy) - 1.0) * minf(ww, hh), 5.0)
	if acc > 40.0:
		return acc
	return acc + _crag.get_noise_3d(x, y, z) * CRAG


## Inside a hollow (< 0): the cave (`inside_only`: just it) and the cleft.
func _cav(x: float, y: float, z: float, inside_only: bool) -> float:
	var best := 1e9
	var rough := _n.get_noise_3d(x * 1.3, y * 1.3 + 17.0, z * 1.3) * 0.55
	for r in cav_rooms:
		var l := Vector2(x - r[0], z - r[1]).length()
		if l > float(r[3]) + 4.0:
			continue
		var qy := maxf(y - float(r[2]), 0.0) / float(r[4])
		var e := sqrt(pow(l / float(r[3]), 2.0) + qy * qy) - 1.0
		best = minf(best, maxf(e * minf(r[3], r[4]) + rough, float(r[2]) - y))
	for s in cav_segs:
		if inside_only and int(s[8]) == 0:
			continue
		var t := _seg_t(x, z, s)
		var l := Vector2(x, z).distance_to(Vector2(s[0], s[1]).lerp(Vector2(s[3], s[4]), t))
		var ww: float = s[6]
		if l > ww + 4.0:
			continue
		var fy := lerpf(s[2], s[5], t)
		var h: float = s[7]
		var qy := maxf(y - fy - h * 0.35, 0.0) / (h * 0.65)
		var e := sqrt(pow(l / ww, 2.0) + qy * qy) - 1.0
		best = minf(best, maxf(e * minf(ww, h * 0.65) + rough * 0.6, fy - y))
	return best


## Columns the field is worked out on (the rest is air).
func _near(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	var th := bearing(p)
	if th > _t0 and th < _t0 + (_nt - 1) * STEP:
		var hw := half_at(th)
		var u := p.distance_to(c) - radius_at(th)
		if u > -hw - 0.35 - 8.5 and u < hw + 5.5:
			return true
	for r in hull_rooms:
		if p.distance_to(Vector2(r[0], r[1])) < float(r[3]) + T + CRAG + 2.5:
			return true
	for s in hull_segs + cav_segs:
		var t := _seg_t(x, z, s)
		var reach: float = float(s[6]) + (T + CRAG + 2.5 if s.size() == 8 else 1.5)
		if p.distance_to(Vector2(s[0], s[1]).lerp(Vector2(s[3], s[4]), t)) < reach:
			return true
	return false


## The roof over (x, z) above floor y.
func ceiling(x: float, z: float, y: float) -> float:
	var h := y + 0.5
	while h < y + 30.0 and rock(x, h, z) > 0.0:
		h += 0.2
	return h


## Where the rock is going out from (x, z) at height y along bearing `a` (radians, island):
## [point, normal out of the rock] or [] past `reach`.
func wall(x: float, z: float, y: float, a: float, reach: float) -> Array:
	var d := Vector3(cos(a), 0.0, sin(a))
	var r := 0.5
	while r < reach:
		var p := Vector3(x, y, z) + d * r
		if rock(p.x, p.y, p.z) < 0.0:
			var e := 0.2
			var g := Vector3(rock(p.x + e, p.y, p.z) - rock(p.x - e, p.y, p.z), rock(p.x, p.y + e, p.z) - rock(p.x, p.y - e, p.z),
				rock(p.x, p.y, p.z + e) - rock(p.x, p.y, p.z - e))
			return [p - d * 0.1, g.normalized() if g.length_squared() > 1e-8 else -d]
		r += 0.2
	return []


# ==========================================================================
# The mesh (data: a worker)
# ==========================================================================
## Surface nets over the columns near the rock: {"surfaces": {key: {v, n, uv, c}}, "faces"
## (collision), "ledges" ([centre, normal]: flat rock off the path, for plants), "under"
## (overhangs' undersides by the path, for roots), "tris", "ms"}. Keys: path, rock, moss,
## turf outside; cave, cave_floor inside.
func mesh() -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var lo := Vector3(INF, Y_MIN, INF)
	var hi := Vector3(-INF, 0.0, -INF)
	for i in range(_nt):
		var q := c + Vector2.from_angle((_t0 + i * STEP) * DEG) * _r[i]
		lo.x = minf(lo.x, q.x - 12.0)
		lo.z = minf(lo.z, q.y - 12.0)
		hi.x = maxf(hi.x, q.x + 12.0)
		hi.z = maxf(hi.z, q.y + 12.0)
		hi.y = maxf(hi.y, _cap[i] + 4.0)
	for r in hull_rooms:
		var e: float = float(r[3]) + T + CRAG + 3.0
		lo.x = minf(lo.x, float(r[0]) - e)
		lo.z = minf(lo.z, float(r[1]) - e)
		hi.x = maxf(hi.x, float(r[0]) + e)
		hi.z = maxf(hi.z, float(r[1]) + e)
		hi.y = maxf(hi.y, float(r[2]) + float(r[4]) + T + CRAG + 2.0)
	for s in hull_segs:
		hi.y = maxf(hi.y, maxf(s[2], s[5]) + float(s[7]) + T + CRAG + 2.0)
		for q in [Vector2(s[0], s[1]), Vector2(s[3], s[4])]:
			lo.x = minf(lo.x, q.x - 12.0)
			lo.z = minf(lo.z, q.y - 12.0)
			hi.x = maxf(hi.x, q.x + 12.0)
			hi.z = maxf(hi.z, q.y + 12.0)
	var cell := CELL
	var nx := int(ceil((hi.x - lo.x) / cell))
	var ny := int(ceil((hi.y - lo.y) / cell))
	var nz := int(ceil((hi.z - lo.z) / cell))
	var sx := nx + 1
	var sxy := sx * (ny + 1)
	var near := PackedByteArray()
	near.resize(sx * (nz + 1))
	var vals := PackedFloat32Array()
	vals.resize(sxy * (nz + 1))
	vals.fill(1.0)
	for k in range(nz + 1):
		for i in range(sx):
			var x := lo.x + i * cell
			var z := lo.z + k * cell
			if not _near(x, z):
				continue
			near[k * sx + i] = 1
			for j in range(ny + 1):
				vals[k * sxy + j * sx + i] = rock(x, lo.y + j * cell, z)
	# cell columns with a near corner
	var cols: Array = []
	for k in range(nz):
		for i in range(nx):
			if near[k * sx + i] + near[k * sx + i + 1] + near[(k + 1) * sx + i] + near[(k + 1) * sx + i + 1] > 0:
				cols.append(Vector2i(i, k))
	var cell_v := PackedInt32Array()
	cell_v.resize(nx * ny * nz)
	cell_v.fill(-1)
	var verts := PackedVector3Array()
	var corner := []
	for cc in range(8):
		corner.append(Vector3i(cc & 1, (cc >> 1) & 1, (cc >> 2) & 1))
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var cv := PackedFloat32Array()
	cv.resize(8)
	for col in cols:
		var i: int = col.x
		var k: int = col.y
		for j in range(ny):
			var neg := 0
			for cc in range(8):
				var o: Vector3i = corner[cc]
				cv[cc] = vals[(k + o.z) * sxy + (j + o.y) * sx + i + o.x]
				if cv[cc] < 0.0:
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
				sum += Vector3(corner[e[0]]).lerp(Vector3(corner[e[1]]), v0 / (v0 - v1))
				cnt += 1
			cell_v[(k * ny + j) * nx + i] = verts.size()
			verts.append(lo + (Vector3(i, j, k) + sum / cnt) * cell)
	var out := {"surfaces": {}, "faces": PackedVector3Array(), "ledges": [], "under": [], "tris": 0}
	for col in cols:
		var i: int = col.x
		var k: int = col.y
		for j in range(ny + 1):
			var v0 := vals[k * sxy + j * sx + i]
			if j > 0 and j < ny and k > 0:
				var v1 := vals[k * sxy + j * sx + i + 1]
				if (v0 < 0.0) != (v1 < 0.0):
					_quad(out, verts, cell_v[((k - 1) * ny + j - 1) * nx + i], cell_v[((k - 1) * ny + j) * nx + i],
						cell_v[(k * ny + j) * nx + i], cell_v[(k * ny + j - 1) * nx + i], Vector3.RIGHT * (1.0 if v0 < 0.0 else -1.0))
			if j < ny and i > 0 and k > 0:
				var v1 := vals[k * sxy + (j + 1) * sx + i]
				if (v0 < 0.0) != (v1 < 0.0):
					_quad(out, verts, cell_v[((k - 1) * ny + j) * nx + i - 1], cell_v[((k - 1) * ny + j) * nx + i],
						cell_v[(k * ny + j) * nx + i], cell_v[(k * ny + j) * nx + i - 1], Vector3.UP * (1.0 if v0 < 0.0 else -1.0))
			if i > 0 and j > 0 and j < ny:
				var v1 := vals[(k + 1) * sxy + j * sx + i]
				if (v0 < 0.0) != (v1 < 0.0):
					_quad(out, verts, cell_v[(k * ny + j - 1) * nx + i - 1], cell_v[(k * ny + j - 1) * nx + i],
						cell_v[(k * ny + j) * nx + i], cell_v[(k * ny + j) * nx + i - 1], Vector3.BACK * (1.0 if v0 < 0.0 else -1.0))
	out["ms"] = int((Time.get_ticks_usec() - t0) / 1000)
	return out


func _quad(out: Dictionary, verts: PackedVector3Array, a: int, b: int, cc: int, d: int, want: Vector3) -> void:
	if a < 0 or b < 0 or cc < 0 or d < 0:
		return
	if verts[a].distance_squared_to(verts[cc]) <= verts[b].distance_squared_to(verts[d]):
		_tri(out, verts[a], verts[b], verts[cc], want)
		_tri(out, verts[a], verts[cc], verts[d], want)
	else:
		_tri(out, verts[a], verts[b], verts[d], want)
		_tri(out, verts[b], verts[cc], verts[d], want)


func _tri(out: Dictionary, a: Vector3, b: Vector3, cc: Vector3, want: Vector3) -> void:
	var n := (b - a).cross(cc - a)
	if n.length_squared() < 1e-8:
		return
	n = n.normalized()
	if n.dot(want) < 0.0:
		n = -n
	if (cc - a).cross(b - a).dot(n) < 0.0:
		var t := b
		b = cc
		cc = t
	var m := (a + b + cc) / 3.0
	var key := _kind(m, n)
	var shade := 0.9 + 0.14 * sin(m.y * 1.9 + m.x * 0.13 + m.z * 0.11)
	if n.y < -0.3:
		shade *= 0.66
	if key == "cave" or key == "cave_floor":
		shade *= 0.85
	elif m.y < 0.4:
		shade *= 0.75
	if not out["surfaces"].has(key):
		out["surfaces"][key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray()}
	var s: Dictionary = out["surfaces"][key]
	var off := Vector2(fposmod(m.x * 7.31 + m.z * 3.17, 1.0), fposmod(m.y * 5.13 + m.x * 2.71, 1.0))
	var uv := 0.4 if key == "path" or key == "cave_floor" else 0.32
	var col := Color(shade, shade, shade)
	s["v"].append_array([a, b, cc])
	s["n"].append_array([n, n, n])
	s["uv"].append_array([CaveMesher._tuv(a, n, uv, off), CaveMesher._tuv(b, n, uv, off), CaveMesher._tuv(cc, n, uv, off)])
	s["c"].append_array([col, col, col])
	out["faces"].append_array([a, b, cc])
	out["tris"] = int(out["tris"]) + 1
	if key == "turf" or key == "moss":
		if n.y > 0.8 and m.y > 0.6 and (out["ledges"] as Array).size() < 600:
			out["ledges"].append([m, n])
	elif key == "rock" and n.y < -0.55 and (out["under"] as Array).size() < 300:
		var th := bearing(Vector2(m.x, m.z))
		if th > th0 and th < th1:
			var u := Vector2(m.x, m.z).distance_to(c) - radius_at(th)
			if u > -half_at(th) - 0.5 and u < half_at(th) + 0.5 and m.y - floor_at(th) > 2.2 and m.y - floor_at(th) < 5.0:
				out["under"].append([m, n])


## What a facet at m (normal n) is: the path's floor, the cave's walls or floor, or the rock
## outside by how flat it is (turf on the flats, moss on the gentler slopes, in patches).
func _kind(m: Vector3, n: Vector3) -> String:
	var inside := absf(_cav(m.x, m.y, m.z, true)) < 1.0
	if inside:
		return "cave_floor" if n.y > 0.75 else "cave"
	if n.y > 0.75:
		var th := bearing(Vector2(m.x, m.z))
		if th >= th0 and th <= th1 and gap_at(th).is_empty():
			var u := Vector2(m.x, m.z).distance_to(c) - radius_at(th)
			if absf(m.y - floor_at(th)) < 0.35 and absf(u) < half_at(th) + 0.45:
				return "path"
		if not cleft.is_empty():
			var a: Vector3 = cleft[0]
			var b: Vector3 = cleft[1]
			var t := clampf((Vector2(m.x, m.z) - Vector2(a.x, a.z)).dot(Vector2(b.x - a.x, b.z - a.z)) / Vector2(b.x - a.x, b.z - a.z).length_squared(), 0.0, 1.2)
			if Vector2(m.x, m.z).distance_to(Vector2(a.x, a.z).lerp(Vector2(b.x, b.z), t)) < 1.6 and absf(m.y - lerpf(a.y, b.y, minf(t, 1.0))) < 0.6:
				return "path"
	var patch := _crag.get_noise_3d(m.x * 2.5, m.y * 2.5, m.z * 2.5)
	if n.y > 0.8 and patch > -0.3 and m.y > 0.8:
		return "turf"
	if n.y > 0.4 and patch > -0.45 and m.y > 0.5:
		return "moss"
	return "rock"


# ==========================================================================
# The nodes (main thread)
# ==========================================================================
const LOOK := {"rock": ["rock", Coast.TINT], "moss": ["rock", Color(0.56, 0.7, 0.42)], "turf": ["grass", Color(0.8, 0.95, 0.7)],
	"path": ["dirt", Color(0.98, 0.62, 0.46)], "cave": ["rock", Color(0.6, 0.57, 0.53)], "cave_floor": ["dirt", Color(0.72, 0.62, 0.54)]}
const CAVE_LIGHT := Color(0.62, 1.0, 0.82)


## The path in the world from its mesh (`m`, mesh()): the rock and its colliders (a
## box under every stretch of floor, so its lips are exact), cable railings, roots, ferns,
## the broken bridge and its chain, the cave's dripstone, lichen and light, its bugs
## (`nest`: small ones, a brute, spitters from the roof) and at the foot (`foot`, `face`
## toward the path) the crew's warning: their colours, a skull on a pike, two torches.
func build(ctx: KitContext, m: Dictionary, rng: RandomNumberGenerator, foot: Vector2, face: Vector2) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "DenPath"
	body.collision_layer = 1
	body.collision_mask = 0
	ctx.put(body, Vector3.ZERO)
	var outside := MeshInstance3D.new()
	outside.name = "Rock"
	outside.mesh = _surfaces(m["surfaces"], ["rock", "moss", "turf", "path"])
	body.add_child(outside)
	var inside := MeshInstance3D.new()
	inside.name = "Cave"
	inside.mesh = _surfaces(m["surfaces"], ["cave", "cave_floor"])
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inside.visibility_range_end = 160.0
	body.add_child(inside)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(m["faces"])
	var cs := CollisionShape3D.new()
	cs.name = "RockShape"
	cs.shape = shape
	body.add_child(cs)
	_floors(body)
	var mb := MeshBuilder.new()
	_rails(mb, body)
	_roots(mb, m["under"], rng)
	_bridge(ctx, mb, body, rng)
	var dress := mb.to_instance("Dressing")
	dress.visibility_range_end = 260.0
	body.add_child(dress)
	_plants(body, m["ledges"], rng)
	_cave(ctx, body, rng)
	_warning(ctx, foot, face)
	return body


func _surfaces(surfs: Dictionary, wanted: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in wanted:
		if not surfs.has(key):
			continue
		var s: Dictionary = surfs[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s["v"]
		arrays[Mesh.ARRAY_NORMAL] = s["n"]
		arrays[Mesh.ARRAY_TEX_UV] = s["uv"]
		arrays[Mesh.ARRAY_COLOR] = s["c"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, PSXMat.lit(LOOK[key][0], LOOK[key][1], {"affine": 0.5}))
	return mesh


## The solid stretches between the gaps, [from, to] bearings.
func spans() -> Array:
	var out: Array = []
	var a := th0
	for g in gaps:
		out.append([a, float(g[0])])
		a = float(g[1])
	out.append([a, th1])
	return out


## A thin box under every metre or so of floor (and up the cleft), its top on the floor.
func _floors(body: StaticBody3D) -> void:
	for sp in spans():
		var mid := (float(sp[0]) + float(sp[1])) * 0.5
		var n := maxi(1, ceili((float(sp[1]) - float(sp[0])) * DEG * radius_at(mid) / 1.2))
		for i in range(n):
			var ta := lerpf(sp[0], sp[1], float(i) / n)
			var tb := lerpf(sp[0], sp[1], float(i + 1) / n)
			_floor_box(body, floor_point(ta), floor_point(tb), half_at((ta + tb) * 0.5))
	var a: Vector3 = cleft[0]
	var b: Vector3 = cleft[1]
	var n := ceili(Vector2(b.x - a.x, b.z - a.z).length() / 1.5)
	for i in range(n):
		_floor_box(body, a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), 1.25)
	var on := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	_floor_box(body, b, b + on * 3.0, 1.25)


func _floor_box(body: StaticBody3D, a: Vector3, b: Vector3, hw: float) -> void:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(hw * 2.0, 0.4, d.length())
	cs.shape = box
	cs.transform = Transform3D(basis, (a + b) * 0.5 - basis.y * 0.2)
	body.add_child(cs)


## Iron posts and a cable on the drop side of the rails' stretches (a collider along each).
func _rails(mb: MeshBuilder, body: StaticBody3D) -> void:
	var iron := PSXMat.lit("metal", Color(0.5, 0.36, 0.28))
	var cable := PSXMat.lit("metal", Color(0.62, 0.6, 0.56))
	for rl in rails:
		var n := maxi(1, ceili((float(rl[1]) - float(rl[0])) * DEG * radius_at(float(rl[0])) / 2.1))
		var prev := Vector3.INF
		for i in range(n + 1):
			var th := lerpf(rl[0], rl[1], float(i) / n)
			var p := floor_point(th, half_at(th) - 0.12)
			mb.add_cylinder(iron, Transform3D(Basis(Vector3.RIGHT, 0.06 * (1 if i % 2 == 0 else -1)), p + Vector3.DOWN * 0.15), 0.035, 0.03, 1.2, 4, 1.0)
			mb.add_box(iron, Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.98), Vector3(0.09, 0.05, 0.09), 1.0)
			if prev != Vector3.INF:
				for hy in [0.95, 0.5]:
					mb.add_tube(cable, MeshBuilder.sag_points(prev + Vector3.UP * hy, p + Vector3.UP * hy, 0.07, 5), 0.014, 0.014, 4, 1.0)
				var d := p - prev
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.1, 1.0, d.length())
				cs.shape = box
				cs.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (p + prev) * 0.5 + Vector3.UP * 0.5)
				body.add_child(cs)
			prev = p


## Roots hanging from the rock leaning out over the path.
func _roots(mb: MeshBuilder, under: Array, rng: RandomNumberGenerator) -> void:
	var bark := PSXMat.lit("bark", Color(0.62, 0.5, 0.4))
	var used: Array = []
	for e in under:
		var p: Vector3 = e[0]
		if rng.randf() > 0.45 or used.any(func(q): return (q as Vector3).distance_to(p) < 1.3):
			continue
		used.append(p)
		var l := rng.randf_range(0.5, 1.4)
		var side := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
		mb.add_tube(bark, MeshBuilder.curve_points(p + Vector3.UP * 0.15, p + side + Vector3.DOWN * l * 0.5, p + side * 0.4 + Vector3.DOWN * l, 5),
			0.045, 0.012, 4, 1.0)


## Ferns and grass on the rock's flats and along the path's edges (MultiMeshes, no shadows).
func _plants(body: StaticBody3D, ledges: Array, rng: RandomNumberGenerator) -> void:
	var fern := Props.fern_mesh(43)
	var grass := Props.grass_mesh()
	var ferns: Array = []
	var tufts: Array = []
	for e in ledges:
		var p: Vector3 = e[0]
		var roll := rng.randf()
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		if roll < 0.3:
			ferns.append(Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.55, 0.95)), p + Vector3.DOWN * 0.05))
		elif roll < 0.7:
			tufts.append(Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), p + Vector3.DOWN * 0.05))
	var tunnels: Array = cave["tunnels"]
	var dark := [float(tunnels[0][0]) + 2.0, float(tunnels[tunnels.size() - 1][1]) - 2.0]
	for sp in spans():
		var th: float = sp[0]
		while th < float(sp[1]):
			for sd in [-1.0, 1.0]:
				if rng.randf() < 0.55 and (th < dark[0] or th > dark[1]):
					var q := floor_point(th, sd * (half_at(th) + rng.randf_range(-0.15, 0.1)))
					var b := Basis(Vector3.UP, rng.randf() * TAU)
					if sd < 0.0 and rng.randf() < 0.4:
						ferns.append(Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.5, 0.8)), q + Vector3.DOWN * 0.05))
					else:
						tufts.append(Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.7, 1.1)), q + Vector3.DOWN * 0.05))
			th += 0.9 / (radius_at(th) * DEG)
	for pl in [[fern, ferns, "Ferns"], [grass, tufts, "Grass"]]:
		var xs: Array = pl[1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pl[0]
		mm.instance_count = xs.size()
		for i in range(xs.size()):
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = pl[2]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 90.0
		body.add_child(mmi)


## The broken bridge over the "swing" gap: posts at both lips, its two chains still slung
## across with a crossbeam between them, its deck gone but for planks hanging off the lips,
## and from the crossbeam the chain you swing on.
func _bridge(ctx: KitContext, mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var g: Array = []
	for e in gaps:
		if e[2] == "swing":
			g = e
	var ta: float = g[0]
	var tb: float = g[1]
	var wood := PSXMat.lit("planks_dark")
	var beam := PSXMat.lit("bark", Color(0.7, 0.6, 0.5))
	var iron := PSXMat.lit("metal", Color(0.46, 0.4, 0.36))
	var rope := PSXMat.lit("rope")
	var plank := PSXMat.lit("planks_weathered")
	var top := 4.6
	var tops: Array = []
	for th in [ta, tb]:
		var row: Array = []
		for sd in [-1.0, 1.0]:
			var p := floor_point(th, sd * (half_at(th) + 0.05)) + Vector3.DOWN * 0.6
			mb.add_cylinder(beam, Transform3D(Basis.IDENTITY, p), 0.14, 0.12, top + 0.75, 6, 1.0)
			KitLandmarks.cyl_col(body, 0.14, top + 0.2, p + Vector3.UP * (0.6 + (top + 0.2) * 0.5))
			row.append(p + Vector3.UP * (top + 0.6))
		tops.append(row)
		# planks hanging off the lip, a rope still on them
		var lip := floor_point(th)
		var out := Vector3(tangent(th).x, 0.0, tangent(th).y) * (1.0 if th == ta else -1.0)
		for k in range(3):
			var sd := (k - 1) * 0.55
			var side := Vector3(-out.z, 0.0, out.x)
			var hang := rng.randf_range(0.9, 1.6)
			var at := lip + side * sd + out * 0.15 + Vector3.DOWN * 0.1
			var b := Basis.looking_at(out, Vector3.UP) * Basis(Vector3.RIGHT, -rng.randf_range(1.0, 1.35)) * Basis(Vector3.FORWARD, rng.randf_range(-0.2, 0.2))
			mb.add_box(plank, Transform3D(b, at + b * Vector3(0, 0, -hang * 0.5)), Vector3(0.45, 0.05, hang), 0.8, Color.WHITE, false, false)
		mb.add_tube(rope, MeshBuilder.sag_points(lip - Vector3(0, 0.05, 0) + Vector3(-out.z, 0, out.x) * 0.8, lip + out * 0.6 + Vector3.DOWN * 1.8, 0.2, 4), 0.025, 0.025, 4, 1.0)
	var at_k := float(bridge["at"])
	var mids: Array = []
	for sd in range(2):
		var a: Vector3 = tops[0][sd]
		var b: Vector3 = tops[1][sd]
		var sag := 0.6
		mb.add_tube(iron, MeshBuilder.sag_points(a, b, sag, 10), 0.045, 0.045, 5, 1.0)
		mids.append(a.lerp(b, at_k) + Vector3.DOWN * sag * 4.0 * at_k * (1.0 - at_k))
	# the crossbeam the chain hangs from, lashed to both chains
	var m0: Vector3 = mids[0]
	var m1: Vector3 = mids[1]
	mb.add_cylinder(beam, Transform3D(Basis.looking_at((m1 - m0).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5), m0 + (m0 - m1).normalized() * 0.2),
		0.11, 0.11, m0.distance_to(m1) + 0.4, 5, 1.0)
	for q in [m0, m1]:
		mb.add_box(rope, Transform3D(Basis.IDENTITY, q + Vector3.DOWN * 0.05), Vector3(0.18, 0.2, 0.18), 1.0)
	var anchor := (m0 + m1) * 0.5 + Vector3.DOWN * 0.1
	chain = ChainSwing.new()
	chain.name = "BridgeChain"
	chain.length = float(bridge["len"])
	var grab := floor_point(ta - 0.55 / (radius_at(ta) * DEG))
	chain.grab_from = ctx.isl.to_global(grab)
	ctx.put(chain, anchor)
	# a red rag on its ring so it reads from the lip
	var rag := PSXMat.lit("cloth_red")
	for turn in [0.0, PI]:
		mb.add_card(rag, Transform3D(Basis(Vector3.UP, turn), anchor + Vector3.DOWN * (chain.length - 0.25) + Vector3(0.08, 0, 0)), 0.22, 0.35, Rect2(0, 0, 0.5, 0.5))


## The cave room: dripstone (stalactites clear of the fight, stalagmites off the way
## through, colliders on the big ones), glowing lichen and fungus, a light, and its bugs.
func _cave(ctx: KitContext, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var r: Array = cav_rooms[0]
	var rc := Vector2(r[0], r[1])
	var fy: float = r[2]
	var rr: float = r[3]
	var a: Array = cav_segs[0]
	var b: Array = cav_segs[1]
	var way0 := Vector2(a[0], a[1])
	var way1 := Vector2(b[3], b[4])
	var off_way := func(q: Vector2) -> float:
		return Geometry2D.get_closest_point_to_segment(q, way0, way1).distance_to(q)
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("rock", Color(0.74, 0.7, 0.62))
	var used: Array = []
	# the bugs: the brute on the seaward side, small ones about, spitters up in the roof
	var out_dir := (rc - c).normalized()
	nest = ScuttlebugNest.new()
	nest.name = "DenCaveBugs"
	nest.respawn_time = 180.0
	nest.respawn_clearance = 30.0
	var brute := rc + out_dir * 2.6
	nest.add_spot(Vector3(brute.x, fy, brute.y), true, true)
	used.append(brute)
	for k in range(5):
		var q := rc + Vector2.from_angle(TAU * k / 5.0 + 0.4) * rr * rng.randf_range(0.35, 0.62)
		nest.add_spot(Vector3(q.x, fy, q.y))
		used.append(q)
	var anchors: Array = []
	for k in range(3):
		var q := rc + Vector2.from_angle(TAU * k / 3.0 + 1.1) * rr * 0.42
		var roof := ceiling(q.x, q.y, fy)
		if roof - fy < 4.6:
			q = rc.lerp(q, 0.5)
			roof = ceiling(q.x, q.y, fy)
		nest.add_spitter(Vector3(q.x, roof - 0.45, q.y), Vector3(q.x, fy, q.y))
		anchors.append(q)
	ctx.put(nest, Vector3.ZERO)
	# stalactites (tips well over head height), stalagmites at the walls off the way through
	for k in range(14):
		var q := rc + Vector2.from_angle(rng.randf() * TAU) * rr * sqrt(rng.randf()) * 0.85
		var roof := ceiling(q.x, q.y, fy)
		var length := minf(rng.randf_range(0.8, 2.2), roof - fy - 3.4)
		if length < 0.5 or anchors.any(func(s): return (s as Vector2).distance_to(q) < 1.6):
			continue
		KitDungeons._spike(mb, stone, Vector3(q.x, roof + 0.6, q.y), length + 0.6, (length + 0.6) * rng.randf_range(0.13, 0.19), true, rng)
	var mites := 0
	for k in range(40):
		if mites >= 6:
			break
		var q := rc + Vector2.from_angle(rng.randf() * TAU) * rr * rng.randf_range(0.62, 0.86)
		if float(off_way.call(q)) < 2.3 or used.any(func(s): return (s as Vector2).distance_to(q) < 1.8):
			continue
		used.append(q)
		mites += 1
		var h := rng.randf_range(0.6, 2.1)
		var r0 := h * rng.randf_range(0.2, 0.28)
		KitDungeons._spike(mb, stone, Vector3(q.x, fy - 0.3, q.y), h + 0.3, r0, false, rng)
		if r0 >= 0.25:
			KitLandmarks.cyl_col(body, r0 * 0.75, h, Vector3(q.x, fy + h * 0.5, q.y))
	# lichen in colonies low on the walls, fungus at their feet
	var bright := PSXMat.glow(Color(0.35, 1.0, 0.75), 1.9)
	var dim := PSXMat.glow(Color(0.25, 0.62, 0.95), 1.3)
	var fungus := PSXMat.glow(Color(0.35, 0.95, 0.85), 2.2)
	var stalk := PSXMat.lit("", Color(0.75, 0.72, 0.6))
	for k in range(9):
		var hit := wall(rc.x, rc.y, fy + rng.randf_range(0.8, 2.4), TAU * k / 9.0 + rng.randf_range(-0.2, 0.2), rr + 3.0)
		if hit.is_empty():
			continue
		var p: Vector3 = hit[0]
		var nrm: Vector3 = hit[1]
		var t1 := nrm.cross(Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := nrm.cross(t1)
		var bs := Basis(t1, nrm, t1.cross(nrm))
		for j in range(rng.randi_range(6, 11)):
			var s := rng.randf_range(0.08, 0.22)
			var o := t1 * rng.randf_range(-0.6, 0.6) + t2 * rng.randf_range(-0.6, 0.6) * 1.4
			mb.add_blob(dim if k % 3 == 0 else bright, Transform3D(bs, p + nrm * 0.05 + o), Vector3(s, 0.03, s * rng.randf_range(0.7, 1.5)), rng, 0.3, 2, 5, 1.0)
		if k % 2 == 0:
			var foot := Vector3(p.x, fy, p.z) + Vector3(nrm.x, 0.0, nrm.z).normalized() * 0.5
			for f in range(3):
				var q := foot + Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
				var h := rng.randf_range(0.2, 0.5)
				mb.add_cylinder(stalk, Transform3D(Basis(), q), 0.04, 0.03, h, 4, 1.0)
				mb.add_blob(fungus, Transform3D(Basis(), q + Vector3.UP * h), Vector3(0.14, 0.06, 0.14), rng, 0.2, 2, 5, 1.0)
	var dressing := mb.to_instance("CaveDressing")
	dressing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dressing.visibility_range_end = 140.0
	body.add_child(dressing)
	if ctx.take_light():
		var nl := NightLight.make(CAVE_LIGHT, 1.3, rr + 5.0, true)
		nl.name = "CaveLight"
		nl.position = Vector3(rc.x, ceiling(rc.x, rc.y, fy) - 1.4, rc.y)
		body.add_child(nl)


## At the foot of the path: the crew's colours, a skull on a pike, two torches (one lit after dark).
func _warning(ctx: KitContext, foot: Vector2, face: Vector2) -> void:
	var side := Vector2(-face.y, face.x)
	ctx.place(KitCamps.flag("PathFlag", {"h": 5.0, "r": [0.08, 0.06], "cloth": ctx.style["pirate_flag"], "at": [4.5, 0.6],
		"size": Vector2(1.2, 0.75), "jolly": true}), foot - side * 2.2, KitContext.face_yaw(side))
	var pike := MeshBuilder.new()
	var bone := PSXMat.lit("", Color(0.86, 0.82, 0.7))
	var dark := PSXMat.lit("", Color(0.08, 0.07, 0.06))
	pike.add_cylinder(PSXMat.lit("bark"), Transform3D.IDENTITY, 0.06, 0.04, 2.3, 5, 1.0)
	pike.add_box(bone, Transform3D(Basis.IDENTITY, Vector3(0, 2.38, 0)), Vector3(0.28, 0.26, 0.3), 1.0, Color.WHITE, false)
	pike.add_box(bone, Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 0.05)), Vector3(0.2, 0.1, 0.2), 1.0)
	for x in [-0.07, 0.07]:
		pike.add_box(dark, Transform3D(Basis.IDENTITY, Vector3(x, 2.4, 0.15)), Vector3(0.08, 0.08, 0.02), 1.0)
	ctx.place(pike.to_instance("SkullPike"), foot + side * 2.2, KitContext.face_yaw(-face))
	for k in [-1.0, 1.0]:
		var t := KitHouses.torch(2.3)
		ctx.place(t, foot + side * k * 1.2 - face * 0.4, 0.0, 0.0, 0.0, false)
		if k > 0.0:
			KitLights.light(ctx, t, Vector3(0, 2.6, 0), 1.2, 9.0)
