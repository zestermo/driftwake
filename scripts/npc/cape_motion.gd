class_name CapeMotion
extends RefCounted
## The cape lab's motion variants that don't step points in world space (BodyBuilder.cape_mode), run on a
## cape's own SpringChains every frame:
## "b"  each segment a damped swing (back, and to the side) in the anchor's space, driven by a share of how
##      that point of the body really moves (its acceleration and air drag) and gravity, limited so it never
##      swings in front of the back, and lifted off the legs;
## "c"  procedural: the same swing eased toward targets read off the body (speed lifts it back, turning sways
##      it, falling lifts the hem, a little seeded flutter), no physics: nothing can jitter.

const LEGS := ["thigh_l", "thigh_r", "shin_l", "shin_r"]
const SUB := 1.0 / 120.0
const THETA_MAX := 1.35
const SIDE_MAX := 0.4
## The cushion off the legs and the back (m) and how hard it pushes (rad/s^2 per m inside it).
const SOFT := 0.06
const SOFT_K := 2500.0

# b: the share of the body's acceleration the cloth feels, air drag per m/s, the rest pull, the
# bend between segments (both per s^2), the damping ratio
const B_INERTIA := 0.45
const B_AIR := 0.45
const B_REST := 12.0
const B_BEND := 40.0
const B_ZETA := 0.75
# c: each segment's spring (Hz, top to hem) and damping ratio
const C_HZ := [2.6, 2.1, 1.7, 1.5]
const C_ZETA := 0.8

var mode := "b"
## The back's plane (anchor-local z): nothing below a chain's root swings in front of it.
var back := 0.0
var _st: Array = []
var _g_prev := Transform3D()
var _fresh := true
var _v := Vector3.ZERO
var _vy := 0.0
var _yaw := 0.0
var _yaw_rate := 0.0
var _t := 0.0
var _phase := 0.0


static func attach(sim: SpringChains, m: String, body: Node3D, back: float) -> CapeMotion:
	var cm := CapeMotion.new()
	cm.mode = m
	cm.back = back
	cm._phase = float(hash(str(body.name)) % 1000) * 0.01
	for i in range(sim.chain_count()):
		var p: PackedVector3Array = sim.chain(i)["p"]
		var dirs: Array = []
		var lens := PackedFloat32Array()
		var reach := PackedFloat32Array()
		var lo := PackedFloat32Array()
		var mids: Array = []
		var acc := 0.0
		for j in range(p.size() - 1):
			var d := p[j + 1] - p[j]
			dirs.append(d.normalized())
			lens.append(d.length())
			reach.append(acc + d.length() * 0.5)
			acc += d.length()
			# (the lowest swing: straight down the back, never in toward it)
			lo.append(-atan2(d.z, -d.y))
			mids.append((p[j] + p[j + 1]) * 0.5)
		var n := p.size() - 1
		var z := PackedFloat32Array()
		z.resize(n)
		cm._st.append({"dirs": dirs, "len": lens, "reach": reach, "lo": lo, "mids": mids,
			"b": z.duplicate(), "s": z.duplicate(), "vb": z.duplicate(), "vs": z.duplicate(), "pv": [], "va": []})
	sim.motion = cm
	sim.back_z = back
	return cm


func update(sim: SpringChains, delta: float) -> void:
	var g := sim.get_global_transform_interpolated()
	if _fresh or g.origin.distance_to(_g_prev.origin) > 2.5:
		_fresh = false
		_g_prev = g
		_v = Vector3.ZERO
		for s in _st:
			s["pv"] = []
			s["va"] = []
	if delta <= 0.0:
		return
	_t += delta
	var basis := g.basis.orthonormalized()
	var binv := basis.inverse()
	_read_body(g, basis, delta)
	var cols := _leg_caps(sim, g.affine_inverse())
	var steps := maxi(1, ceili(delta / SUB))
	var dt := delta / steps
	for ci in range(_st.size()):
		var s: Dictionary = _st[ci]
		var f := _forces(s, g, binv, delta) if mode == "b" else []
		var tgt := _targets(s, binv) if mode == "c" else []
		for k in range(steps):
			if mode == "b":
				_step_b(s, f, dt)
			else:
				_step_c(s, tgt, dt)
			_limit(s)
		var loc := _fk(sim.chain(ci), s, cols, delta)
		sim.pose_local(sim.chain(ci), loc)
	_g_prev = g


## The body's smoothed speed, vertical speed and turn rate (physics interpolation moves the anchor in
## straight pieces between ticks: raw differences would step at every tick).
func _read_body(g: Transform3D, basis: Basis, delta: float) -> void:
	var k := 1.0 - exp(-delta / 0.05)
	var raw := (g.origin - _g_prev.origin) / delta
	_v = _v.lerp(raw, k)
	_vy = lerpf(_vy, raw.y, k)
	var fwd := -basis.z
	var yaw := atan2(-fwd.x, -fwd.z)
	var dy := wrapf(yaw - _yaw, -PI, PI)
	_yaw = yaw
	_yaw_rate = lerpf(_yaw_rate, dy / delta, k)


## b: the specific force on each segment in the anchor's space: gravity, minus a share of how fast that
## point of the body speeds up, minus air drag on how fast it moves.
func _forces(s: Dictionary, g: Transform3D, binv: Basis, delta: float) -> Array:
	var mids: Array = s["mids"]
	var pv: Array = s["pv"]
	var va: Array = s["va"]
	var out: Array = []
	var k := 1.0 - exp(-delta / 0.1)
	for j in range(mids.size()):
		var w := g * (mids[j] as Vector3)
		if pv.size() <= j:
			pv.append(w)
			va.append(Vector3.ZERO)
		var v := ((w - (pv[j] as Vector3)) / delta)
		var vs: Vector3 = (va[j] as Vector3).lerp(v, k)
		var a := (vs - (va[j] as Vector3)) / delta
		pv[j] = w
		va[j] = vs
		out.append(binv * (Vector3(0, -9.8, 0) - a * B_INERTIA - vs * B_AIR))
	return out


static func _dir_at(r: Vector3, b: float, sd: float) -> Vector3:
	return Basis(Vector3.BACK, sd) * (Basis(Vector3.RIGHT, -b) * r)


func _step_b(s: Dictionary, f: Array, dt: float) -> void:
	var b: PackedFloat32Array = s["b"]
	var sd: PackedFloat32Array = s["s"]
	var vb: PackedFloat32Array = s["vb"]
	var vs: PackedFloat32Array = s["vs"]
	var reach: PackedFloat32Array = s["reach"]
	for j in range(b.size()):
		var v: Vector3 = Basis(Vector3.RIGHT, -b[j]) * (s["dirs"][j] as Vector3)
		var tb := Basis(Vector3.BACK, sd[j]) * v.cross(Vector3.RIGHT).normalized()
		var d := Basis(Vector3.BACK, sd[j]) * v
		var ts := Vector3.BACK.cross(d).normalized()
		var le := maxf(reach[j], 0.08)
		var w := sqrt(9.8 / le + B_REST)
		var c := 2.0 * B_ZETA * w
		var pb := b[j - 1] if j > 0 else 0.0
		var ps := sd[j - 1] if j > 0 else 0.0
		var fj: Vector3 = f[j]
		var ab := fj.dot(tb) / le - B_REST * b[j] - B_BEND * (b[j] - pb) - c * vb[j]
		var as_ := fj.dot(ts) / le - B_REST * sd[j] - B_BEND * (sd[j] - ps) - c * vs[j]
		vb[j] += ab * dt
		vs[j] += as_ * dt
		b[j] += vb[j] * dt
		sd[j] += vs[j] * dt
	s["b"] = b
	s["s"] = sd
	s["vb"] = vb
	s["vs"] = vs


## c: where each segment wants to be from what the body is doing.
func _targets(s: Dictionary, binv: Basis) -> Array:
	var n: int = (s["b"] as PackedFloat32Array).size()
	var vl := binv * _v
	var fwd := clampf(-vl.z / 9.0, 0.0, 1.0)
	var down := binv * Vector3.DOWN
	var lean_b := atan2(down.z, -down.y)
	var lean_s := atan2(down.x, -down.y)
	var spin := clampf(absf(_yaw_rate) * 0.06, 0.0, 0.55)
	var fall := clampf(-_vy * 0.05, 0.0, 0.45)
	var sway := clampf(-_yaw_rate * 0.1 - vl.x * 0.03, -0.3, 0.3)
	var out: Array = []
	for j in range(n):
		var w := lerpf(0.55, 1.0, float(j) / maxf(n - 1, 1))
		var fl := 0.05 * fwd * (sin(_t * 9.0 + _phase - j * 0.9) * 0.6 + sin(_t * 14.3 + _phase * 1.7 - j * 1.3) * 0.4)
		var tb := lean_b * 0.85 + (0.6 * fwd + spin + fall) * w + fl * w
		var tsd := lean_s * 0.85 + sway * w + fl * 0.5 * w
		out.append(Vector2(tb, tsd))
	return out


func _step_c(s: Dictionary, tgt: Array, dt: float) -> void:
	var b: PackedFloat32Array = s["b"]
	var sd: PackedFloat32Array = s["s"]
	var vb: PackedFloat32Array = s["vb"]
	var vs: PackedFloat32Array = s["vs"]
	for j in range(b.size()):
		var w0 := TAU * float(C_HZ[mini(j, C_HZ.size() - 1)])
		var t: Vector2 = tgt[j]
		vb[j] += (w0 * w0 * (t.x - b[j]) - 2.0 * C_ZETA * w0 * vb[j]) * dt
		vs[j] += (w0 * w0 * (t.y - sd[j]) - 2.0 * C_ZETA * w0 * vs[j]) * dt
		b[j] += vb[j] * dt
		sd[j] += vs[j] * dt
	s["b"] = b
	s["s"] = sd
	s["vb"] = vb
	s["vs"] = vs


func _limit(s: Dictionary) -> void:
	var b: PackedFloat32Array = s["b"]
	var sd: PackedFloat32Array = s["s"]
	var vb: PackedFloat32Array = s["vb"]
	var vs: PackedFloat32Array = s["vs"]
	var lo: PackedFloat32Array = s["lo"]
	for j in range(b.size()):
		if b[j] < lo[j]:
			b[j] = lo[j]
			vb[j] = maxf(vb[j], 0.0)
		elif b[j] > THETA_MAX:
			b[j] = THETA_MAX
			vb[j] = minf(vb[j], 0.0)
		if absf(sd[j]) > SIDE_MAX:
			sd[j] = clampf(sd[j], -SIDE_MAX, SIDE_MAX)
			vs[j] = 0.0
	s["b"] = b
	s["s"] = sd
	s["vb"] = vb
	s["vs"] = vs


## The legs' capsules in the anchor's space (drawn transforms, like the anchor's).
func _leg_caps(sim: SpringChains, inv: Transform3D) -> Array:
	var out: Array = []
	for key in LEGS:
		if not sim.colliders.has(key):
			continue
		var c: Dictionary = sim.colliders[key]
		var node: Node3D = c["node"]
		var t := inv * node.get_global_transform_interpolated()
		out.append([t * (c["a"] as Vector3), t * (c["b"] as Vector3), float(c["r"]) * t.basis.get_scale().x])
	return out


## Points down the chain from the swing angles. Within SOFT of a leg a segment is eased back
## (so it slows before it touches: a hard stop alone made the hem pop when a lunge swept a leg into it); one
## inside swings back until clear, its speed into the leg dropped: the cloth rides over the legs, never through.
func _fk(c: Dictionary, s: Dictionary, cols: Array, delta: float) -> PackedVector3Array:
	var p: PackedVector3Array = c["p"]
	var lens: PackedFloat32Array = s["len"]
	var b: PackedFloat32Array = s["b"]
	var vb: PackedFloat32Array = s["vb"]
	var sd: PackedFloat32Array = s["s"]
	var loc := PackedVector3Array([p[0]])
	for j in range(lens.size()):
		var a := loc[j]
		var r: Vector3 = s["dirs"][j]
		var x := a + _dir_at(r, b[j], sd[j]) * lens[j]
		var legs := _gap(x, a, cols, false)
		if legs < SOFT:
			vb[j] += (SOFT - legs) * SOFT_K * delta
		if minf(legs, x.z - back) < 0.0:
			# the least swing back that clears (bisected: stepping it made the hem jump)
			var lo_b := b[j]
			var hi_b := minf(b[j] + 0.9, THETA_MAX)
			if _gap(a + _dir_at(r, hi_b, sd[j]) * lens[j], a, cols) >= 0.0:
				for k in range(8):
					var mid := (lo_b + hi_b) * 0.5
					if _gap(a + _dir_at(r, mid, sd[j]) * lens[j], a, cols) < 0.0:
						lo_b = mid
					else:
						hi_b = mid
			b[j] = hi_b
			vb[j] = maxf(vb[j], 0.0)
		loc.append(a + _dir_at(r, b[j], sd[j]) * lens[j])
	s["b"] = b
	s["vb"] = vb
	return loc


## How far the segment a-x is from the legs and (with `plane`) the back's plane (negative: inside).
func _gap(x: Vector3, a: Vector3, cols: Array, plane := true) -> float:
	var g := x.z - back if plane else INF
	for o in SpringChains.PROBES:
		for cap in cols:
			var st := SpringChains._closest_segments(a + o, x + o, cap[0], cap[1])
			g = minf(g, (st[0] as Vector3).distance_to(st[1]) - float(cap[2]))
	return g
