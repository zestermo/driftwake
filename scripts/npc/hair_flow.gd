class_name HairFlow
extends RefCounted
## Long flowing hair made of many locks, the anime-figure way: layered masses
## hanging round the back, locks draped over the shoulders, bangs, tied tails and
## buns. A lock is a lens-section tube along a waved path, tapering to a point and
## shaded root to tip (an ombre when the look has "hair_tip"). Hanging locks are
## skinned to a few guide chains per mass so the hair swings with the body.

const STYLES := ["cascade", "high_tail", "waves", "mane", "princess", "court_bun", "twin_low", "half_bun"]
const SIDES := 6
const COLS := ["head", "torso", "hair_sh"]

var bb: BodyBuilder
var sim: SpringChains
var smb: MeshBuilder
var m: Material
var rng := RandomNumberGenerator.new()
var style := ""
var yk := 1.0
var top := 0.33
var root_bone := 0
var hatted := false
var c_root: Color
var c_tip: Color
var grad_hi := 0.05
var grad_lo := -0.6
# the body under the hair, in head space
var sh_x := 0.2
var sh_y := -0.12
var tz := 0.0
var td := 0.15


static func has(s: String) -> bool:
	return s in STYLES


static func hides_ears(s: String) -> bool:
	return s in STYLES and s != "high_tail"


## The cap under the locks, untextured like them.
static func shell_mat(c: Color) -> Material:
	return PSXMat.lit("", c.darkened(0.12), {"pull": 0.01})


func _init(b: BodyBuilder, s: String, hat: String) -> void:
	bb = b
	style = s
	yk = b.yk
	top = (b.head_rings[b.head_rings.size() - 1] as Array)[0]
	hatted = hat != "none"
	sim = b._sim(b.h.head)
	smb = sim.mb
	m = PSXMat.lit("", Color.WHITE, {"pull": 0.01})
	var hc: Color = b.lk.get("hair_color", Color.WHITE)
	c_root = _lin(hc)
	c_tip = _lin(b.lk.get("hair_tip", hc))
	rng.seed = hash(s + str(hc) + str(b.lk.get("name", "")))
	# never posed: the rigid locks (bangs, over the scalp) ride on it
	root_bone = sim.skel.add_bone("hair_root")
	var to_head := (b.h.neck.transform * b.h.head.transform).affine_inverse()
	var arm: Vector3 = b.h.arm_r.position
	var shp := to_head * arm
	sh_x = shp.x + 0.07
	sh_y = shp.y + 0.06
	tz = (to_head * Vector3(0, arm.y, 0.01)).z
	td = (0.13 * b.de + 0.025) / b.h.head.scale.x + 0.02
	b.colliders["hair_sh"] = {"node": b.h.torso, "a": b.h.arm_l.position + Vector3(0, 0.05, 0),
		"b": arm + Vector3(0, 0.05, 0), "r": 0.075}


## (locks are untextured: the palette colour as is, where the textured shell brightens it to make up for the texture)
static func _lin(c: Color) -> Color:
	return Color(c.r, c.g, c.b).srgb_to_linear()


func build() -> void:
	var y_hi := top - 0.02
	match style:
		"cascade":
			# centre part, waist length, a soft wave, curtain bangs into face-framing locks
			_bangs_part(0.0, [0.07, 0.09, 0.12, 0.17])
			_mass(104.0, 256.0, 12, 0.95, {"y0": 0.24 * yk, "amp": 0.01, "freq": 1.3, "vol": 0.03, "w": 0.058, "d": 0.017, "shade": 0.72})
			_mass(110.0, 250.0, 15, 1.08, {"y0": y_hi, "amp": 0.014, "freq": 1.4, "vol": 0.045, "w": 0.05})
			for s in [-1.0, 1.0]:
				_mass(s * 56.0, s * 90.0, 3, 0.85, {"y0": 0.3 * yk, "fwd": 1.0, "amp": 0.012, "freq": 1.5, "w": 0.044})
				_mass(s * 94.0, s * 112.0, 2, 1.0, {"y0": y_hi, "fwd": -1.0, "amp": 0.014, "freq": 1.4, "w": 0.048})
		"waves":
			# big loose waves to mid-back, parted on the left, lots of volume
			_bangs_side(-1.0, 8, 0.15)
			_mass(100.0, 260.0, 12, 0.8, {"y0": 0.23 * yk, "amp": 0.028, "freq": 2.4, "vol": 0.07, "w": 0.06, "d": 0.018, "shade": 0.72})
			_mass(106.0, 254.0, 16, 0.9, {"y0": y_hi, "amp": 0.034, "freq": 2.6, "vol": 0.09, "w": 0.052})
			for s in [-1.0, 1.0]:
				_mass(s * 54.0, s * 96.0, 4, 0.76, {"y0": 0.3 * yk, "fwd": 1.0, "amp": 0.032, "freq": 2.6, "vol": 0.04, "w": 0.048})
		"princess":
			# very long and wavy, side bangs, an antenna strand
			_bangs_part(-14.0, [0.06, 0.08, 0.1, 0.14])
			_ahoge()
			_mass(100.0, 260.0, 13, 1.25, {"y0": 0.23 * yk, "amp": 0.024, "freq": 2.0, "vol": 0.08, "w": 0.06, "d": 0.018, "shade": 0.72})
			_mass(105.0, 255.0, 17, 1.4, {"y0": y_hi, "amp": 0.03, "freq": 2.1, "vol": 0.1, "w": 0.052})
			for s in [-1.0, 1.0]:
				_mass(s * 54.0, s * 94.0, 4, 1.15, {"y0": 0.3 * yk, "fwd": 1.0, "amp": 0.026, "freq": 2.2, "vol": 0.03, "w": 0.046})
		"court_bun":
			# straight and black, blunt bangs, side locks cut long, a bun pinned on the crown
			_bangs_blunt()
			_mass(104.0, 256.0, 12, 0.92, {"y0": 0.24 * yk, "amp": 0.003, "freq": 1.0, "w": 0.058, "d": 0.017, "shade": 0.72, "tip": 6.0})
			_mass(110.0, 250.0, 15, 1.0, {"y0": y_hi, "amp": 0.004, "freq": 1.0, "vol": 0.01, "w": 0.05, "tip": 6.0})
			for s in [-1.0, 1.0]:
				_mass(s * 62.0, s * 80.0, 2, 0.9, {"y0": 0.29 * yk, "fwd": 1.0, "amp": 0.003, "freq": 1.0, "w": 0.046, "tip": 6.0})
			if not hatted:
				var at := Vector3(0, top + 0.03, 0.06)
				_bun(at, 0.064)
				var gold := PSXMat.lit("metal", Color(0.95, 0.76, 0.32))
				_pin(at + Vector3(-0.11, -0.02, 0.0), at + Vector3(0.12, 0.035, 0.0), gold, 0.006)
				_pin(at + Vector3(-0.09, 0.05, 0.02), at + Vector3(0.1, -0.03, 0.03), gold, 0.005)
		"half_bun":
			# the top half wound into a bun, the rest falling in waves
			_bangs_side(1.0, 7, 0.12)
			_mass(102.0, 258.0, 12, 0.82, {"y0": 0.22 * yk, "amp": 0.026, "freq": 2.4, "vol": 0.06, "w": 0.06, "d": 0.018, "shade": 0.72})
			_mass(108.0, 252.0, 14, 0.88, {"y0": 0.27 * yk, "amp": 0.03, "freq": 2.5, "vol": 0.07, "w": 0.052})
			for s in [-1.0, 1.0]:
				_mass(s * 56.0, s * 92.0, 3, 0.7, {"y0": 0.29 * yk, "fwd": 1.0, "amp": 0.028, "freq": 2.4, "w": 0.044})
			if not hatted:
				var tie := bb._hair_pt(PI, 0.3 * yk, bb.hair_off + 0.03)
				for a in [150.0, 120.0, 90.0, 60.0, 35.0, -35.0, -60.0, -90.0, -120.0, -150.0]:
					_gather(a, tie, 0.034)
				_bun(tie + Vector3(0, 0.02, 0.03), 0.06)
		"high_tail":
			# a long tail tied high at the back, swept bangs, two long locks framing the face
			_bangs_side(1.0, 7, 0.1)
			var tie := bb._hair_pt(PI, (0.29 if not hatted else 0.19) * yk, bb.hair_off + 0.012)
			for a in [150.0, 125.0, 100.0, 75.0, 50.0, -50.0, -75.0, -100.0, -125.0, -150.0]:
				_gather(a, tie, 0.034)
			_mass(140.0, 220.0, 5, 0.1, {"y0": 0.2 * yk, "w": 0.05, "shade": 0.85, "tip": 1.4})
			for s in [-1.0, 1.0]:
				_mass(s * 60.0, s * 64.0, 1, 0.62, {"y0": 0.28 * yk, "fwd": 1.0, "amp": 0.012, "freq": 1.4, "w": 0.034})
			var up := 0.0 if hatted else 1.0
			var ctrl := PackedVector3Array([tie, tie + Vector3(0, 0.07 * up, 0.07), tie + Vector3(0, 0.02 * up, 0.17),
				tie + Vector3(0, -0.2, 0.23), tie + Vector3(0, -0.55, 0.22), tie + Vector3(0, -0.9, 0.18), tie + Vector3(0, -1.15, 0.14)])
			grad_hi = 0.0
			var g := _bundle(ctrl, 15, 0.028, 0.06, {"amp": 0.022, "freq": 1.6, "w": 0.05, "spread": 1.7})
			_band(tie + (ctrl[1] - tie).normalized() * 0.016, (ctrl[1] - tie).normalized(), 0.05, (g["bones"] as PackedInt32Array)[0])
		"twin_low":
			# two low tails behind the ears, brought forward over the shoulders, banded near the ends
			_bangs_part(0.0, [0.08, 0.085, 0.09, 0.15])
			_mass(112.0, 248.0, 9, 0.12, {"y0": 0.22 * yk, "w": 0.05, "shade": 0.85, "tip": 1.4})
			grad_hi = 0.0
			for s in [-1.0, 1.0]:
				var tie := bb._hair_pt(deg_to_rad(s * 118.0), 0.1 * yk, bb.hair_off + 0.02)
				for a in [s * 60.0, s * 80.0, s * 100.0]:
					_gather(a, tie, 0.034)
				# parted down the back: from the crown and the nape round to each tie
				for a in [s * 176.0, s * 160.0, s * 142.0, s * 124.0]:
					_gather(a, tie, 0.04, top - 0.02)
				for a in [s * 172.0, s * 150.0]:
					_gather(a, tie, 0.04, 0.2 * yk)
				var ctrl := PackedVector3Array([tie, tie + Vector3(s * 0.01, -0.07, -0.09), tie + Vector3(s * 0.0, -0.2, -0.22),
					tie + Vector3(s * -0.01, -0.4, -0.27), tie + Vector3(s * -0.01, -0.58, -0.27), tie + Vector3(s * -0.01, -0.74, -0.25)])
				var g := _bundle(ctrl, 10, 0.024, 0.046, {"amp": 0.006, "freq": 1.2, "w": 0.042, "spread": 1.5})
				var gb: PackedInt32Array = g["bones"]
				var c: PackedVector3Array = g["path"]
				_band(c[1], (c[2] - c[0]).normalized(), 0.048, gb[0])
				var k := int(c.size() * 0.72)
				_band(c[k], (c[k + 1] - c[k - 1]).normalized(), 0.04, gb[gb.size() - 2])
		"mane":
			# a lion's mane: thick pointed locks standing out all round and sweeping back
			# rows of thick pointed locks, crown to nape, all sweeping back and out
			# [height, count, half arc from the back (deg), length, up, out, droop]
			for row in [[top - 0.012, 9, 125.0, 0.3, 0.55, 0.35, 0.1], [0.3 * yk, 12, 140.0, 0.38, 0.25, 0.75, 0.15],
					[0.23 * yk, 13, 120.0, 0.46, -0.05, 0.85, 0.22], [0.15 * yk, 9, 70.0, 0.42, -0.3, 0.5, 0.12]]:
				var cnt: int = row[1]
				if hatted and float(row[0]) > 0.2 * yk:
					continue
				for i in range(cnt):
					var a := 180.0 + lerpf(-float(row[2]), float(row[2]), (i + 0.5) / cnt) + rng.randf_range(-5.0, 5.0)
					var ar := deg_to_rad(a)
					var rad := Vector3(sin(ar), 0, -cos(ar))
					var side := absf(sin(ar))
					var dir := (rad * float(row[5]) + Vector3(0, float(row[4]), 0) + Vector3(0, 0, 0.75)).normalized()
					var lgt: float = float(row[3]) * lerpf(1.0, 0.75, side) * rng.randf_range(0.85, 1.15)
					_spike_lock(a, row[0], dir, lgt, minf(0.2 * lgt, 0.075), float(row[6]) * rng.randf_range(0.7, 1.3))
			# the fringe: big points over the brow, flicking out to the sides
			for i in range(0 if hatted else 7):
				var t := i / 6.0
				_bang(lerpf(-20.0, 20.0, t), lerpf(-62.0, 62.0, t), lerpf(0.17, 0.2, absf(t - 0.5) * 2.0) * yk, 0.05, (t - 0.5) * 0.08, 1.1)
			_mass(118.0, 242.0, 11, 0.7, {"y0": 0.2 * yk, "amp": 0.014, "freq": 1.6, "vol": 0.14, "flick": 0.06,
				"w": 0.068, "d": 0.022, "tip": 1.2, "curl": 0.8})
			for s in [-1.0, 1.0]:
				_mass(s * 70.0, s * 100.0, 3, 0.48, {"y0": 0.22 * yk, "fwd": -1.0, "vol": 0.1, "flick": 0.05, "w": 0.06, "tip": 1.2, "curl": 0.8})
	grad_lo = minf(grad_lo, grad_hi - 0.2)


# ---------------------------------------------------------------- masses

## A layer of hanging locks round angles a0..a1 (degrees, 0 = front, + = right),
## `length` below where they start; guide chains every ~30 degrees carry them.
func _mass(a0: float, a1: float, count: int, length: float, o: Dictionary) -> void:
	var y0: float = o.get("y0", 0.3 * yk)
	if hatted:
		y0 = minf(y0, 0.2 * yk)
	var w: float = o.get("w", 0.035)
	var d: float = o.get("d", 0.013)
	grad_lo = minf(grad_lo, y0 - length)
	var ng := clampi(int(absf(a1 - a0) / 30.0) + 1, 1, 6) if count > 1 else 1
	var guides: Array = []
	for g in range(ng):
		var ga := lerpf(a0, a1, g / float(maxi(ng - 1, 1))) if ng > 1 else (a0 + a1) * 0.5
		var plain := o.duplicate()
		plain["amp"] = 0.0
		plain["flick"] = 0.0
		var gp := _hang(ga, y0, length, plain)
		guides.append(_guide(gp, ga))
	for i in range(count):
		var a := lerpf(a0, a1, (i + 0.5 + rng.randf_range(-0.3, 0.3)) / count) if count > 1 else (a0 + a1) * 0.5
		var lo := o.duplicate()
		# neighbours wave together (a wave runs across the mass), not each its own way
		lo["ph"] = deg_to_rad(a) * 1.3 + rng.randf_range(-0.5, 0.5)
		lo["amp"] = float(o.get("amp", 0.0)) * rng.randf_range(0.85, 1.15)
		var path := _hang(a, y0 + rng.randf_range(-0.01, 0.01), length * rng.randf_range(0.86, 1.06), lo)
		var best: Dictionary = guides[0]
		for gd in guides:
			if absf(angle_difference(deg_to_rad(a), gd["a"])) < absf(angle_difference(deg_to_rad(a), best["a"])):
				best = gd
		_lock(path, w * rng.randf_range(0.85, 1.15), d, {"bones": _bones_y(path, best), "shade": o.get("shade", 1.0),
			"tip": o.get("tip", 2.2), "curl": o.get("curl", 0.55)})


## A hanging lock's path: down over the skull at angle a_deg, then off the head,
## turning in front of (fwd 1) or behind (fwd -1) the shoulder, flaring out
## (vol), waving (amp, freq, ph) and clearing the shoulders and chest.
func _hang(a_deg: float, y0: float, length: float, o: Dictionary) -> PackedVector3Array:
	var n := 18
	var fwd: float = o.get("fwd", 0.0)
	var amp: float = o.get("amp", 0.0)
	var freq: float = o.get("freq", 1.0)
	var ph: float = o.get("ph", 0.0)
	var vol: float = o.get("vol", 0.0)
	var flick: float = o.get("flick", 0.0)
	a_deg = wrapf(a_deg, -180.0, 180.0)
	var sgn := 1.0 if a_deg >= 0.0 else -1.0
	# below the jaw a lock turns to lie in front of the shoulder (fwd 1) or on the
	# back (otherwise: nothing hangs off the point of the shoulder)
	var a_end := sgn * 30.0 if fwd > 0.0 else sgn * maxf(absf(a_deg), 140.0 if fwd < 0.0 else 138.0)
	var path := PackedVector3Array()
	for i in range(n):
		# (rings closer together over the skull, where the lock bends most)
		var s := pow(float(i) / (n - 1), 1.3)
		var y := y0 - length * s
		var b := smoothstep(0.12 * yk, sh_y + 0.02, y)
		var a := deg_to_rad(lerpf(a_deg, a_end, b))
		var lift := -0.006 + 0.008 * smoothstep(0.0, 0.08, s) + vol * smoothstep(0.1 * yk, sh_y - 0.25, y)
		var p := bb._hair_pt(a, y, bb.hair_off + lift)
		var tng := Vector3(cos(a), 0, sin(a))
		var rad := Vector3(sin(a), 0, -cos(a))
		var wv := smoothstep(0.08, 0.4, s)
		p += tng * amp * sin(ph + s * freq * TAU) * wv + rad * amp * 0.5 * cos(ph * 1.3 + s * freq * TAU) * wv
		p += rad * flick * s * s * s
		path.append(_clear_body(p))
	return path


## Pushes a point out of the neck, shoulders and chest (an ellipse per height).
func _clear_body(p: Vector3, margin: float = 0.0) -> Vector3:
	if p.y > sh_y + 0.2:
		return p
	var b := smoothstep(sh_y + 0.2, sh_y - 0.02, p.y)
	var hw := lerpf(0.075, sh_x, b) + 0.02 + margin
	var zc := lerpf(0.0, tz, b)
	# (the chest is flatter than the back of the shoulders)
	var hd := lerpf(0.075, td * (0.8 if p.z < zc else 1.0), b) + 0.015 + margin
	var v := Vector2(p.x / hw, (p.z - zc) / hd)
	var l := v.length()
	if l >= 1.0:
		return p
	v = v / l if l > 1e-4 else Vector2(0, 1)
	return Vector3(v.x * hw, p.y, zc + v.y * hd)


## A spring chain along a lock's path from where it leaves the skull.
func _guide(path: PackedVector3Array, a_deg: float) -> Dictionary:
	var free_y := 0.14 * yk
	var start := 0
	for i in range(path.size()):
		if path[i].y <= free_y:
			start = maxi(i - 1, 0)
			break
	var pts := PackedVector3Array()
	var segs := 5
	for k in range(segs + 1):
		pts.append(path[int(round(lerpf(start, path.size() - 1, k / float(segs))))])
	var bones := sim.add_chain(pts, 0.1, 0.07, 1.0, COLS)
	return {"pts": pts, "bones": bones, "a": deg_to_rad(a_deg)}


## Bone per ring of a hanging lock by height against its guide (above the guide: rigid).
func _bones_y(path: PackedVector3Array, g: Dictionary) -> PackedInt32Array:
	var gp: PackedVector3Array = g["pts"]
	var gb: PackedInt32Array = g["bones"]
	var out := PackedInt32Array()
	for p in path:
		var bone := root_bone
		if p.y < gp[0].y:
			bone = gb[gb.size() - 1]
			for i in range(gp.size() - 1):
				if p.y >= gp[i + 1].y:
					bone = gb[i]
					break
		out.append(bone)
	return out


# ---------------------------------------------------------------- tails, buns, bangs

## A tied bundle of locks along a centre line through ctrl (from the tie):
## the locks ring the line, fuller below the tie, spreading at the tips.
func _bundle(ctrl: PackedVector3Array, count: int, r0: float, r_mid: float, o: Dictionary) -> Dictionary:
	var c := _spline(ctrl, 20)
	var nc := c.size()
	for i in range(nc):
		c[i] = _clear_body(c[i], r_mid * 0.8)
	var idx := PackedInt32Array()
	var gp := PackedVector3Array()
	for k in range(6):
		idx.append(int(round(lerpf(0, nc - 1, k / 5.0))))
		gp.append(c[idx[k]])
	var gb := sim.add_chain(gp, 0.08, 0.06, 1.0, COLS)
	var amp: float = o.get("amp", 0.01)
	var freq: float = o.get("freq", 1.0)
	var spread: float = o.get("spread", 1.3)
	var w: float = o.get("w", 0.034)
	# one frame carried down the line (a frame rebuilt per point flips where the tail turns vertical)
	var sds := PackedVector3Array()
	var sd0 := (c[1] - c[0]).normalized().cross(Vector3.UP)
	if sd0.length_squared() < 1e-4:
		sd0 = Vector3.RIGHT
	for i in range(nc):
		var tng := (c[mini(i + 1, nc - 1)] - c[maxi(i - 1, 0)]).normalized()
		sd0 = (sd0 - tng * sd0.dot(tng)).normalized()
		sds.append(sd0)
	for kk in range(count):
		var inner := kk >= count * 0.6
		var phi := TAU * kk / count + rng.randf_range(-0.25, 0.25) + (0.4 if inner else 0.0)
		var rk := 0.45 if inner else 1.0
		var ph := rng.randf() * TAU
		var nl := int(nc * rng.randf_range(0.8, 1.0))
		var path := PackedVector3Array()
		var outs := PackedVector3Array()
		var bones := PackedInt32Array()
		for i in range(nl):
			var s := float(i) / (nc - 1)
			var tng := (c[mini(i + 1, nc - 1)] - c[maxi(i - 1, 0)]).normalized()
			var sd := sds[i]
			var up := sd.cross(tng).normalized()
			var rr := lerpf(r0, r_mid, smoothstep(0.0, 0.15, s)) * lerpf(1.0, 0.7, smoothstep(0.2, 0.7, s)) * lerpf(1.0, spread, smoothstep(0.7, 1.0, s)) * rk
			var dir := sd * cos(phi) + up * sin(phi)
			path.append(c[i] + dir * rr + sd * amp * sin(ph + s * freq * TAU) * smoothstep(0.1, 0.4, s))
			outs.append(dir)
			var seg := 0
			for k in range(5):
				if i >= idx[k]:
					seg = k
			bones.append(gb[seg])
		_lock(path, w * rng.randf_range(0.85, 1.15) * (0.8 if inner else 1.0), 0.014, {"bones": bones, "outs": outs, "by_s": true,
			"tip": 2.0, "curl": 0.5, "root_k": 0.45, "shade": 0.8 if inner else 1.0})
	return {"bones": gb, "path": c}


## A lock combed along the scalp to a tie point, from the hairline at a_deg (or
## from height y0): the shortest way over the head, so hair drawn back from the
## brow goes over the crown, not round the side.
func _gather(a_deg: float, tie: Vector3, w: float, y0: float = -1.0) -> void:
	if hatted:
		return
	var ar := deg_to_rad(a_deg)
	var ys := y0 if y0 > 0.0 else BodyBuilder._hairline(BodyBuilder.hairline_for(style), ar) * yk + 0.006
	var c0 := Vector3(0, 0.16 * yk, 0)
	var p0 := bb._hair_pt(ar, ys, 0.0) - c0
	var p1 := tie - c0
	var path := PackedVector3Array()
	var n := 12
	for i in range(n):
		var t := float(i) / (n - 1)
		var d := p0.normalized().slerp(p1.normalized(), t)
		var ang := atan2(d.x, -d.z)
		# where the ray from the centre meets the scalp (a few steps: the head isn't a sphere)
		var slope := d.y / maxf(Vector2(d.x, d.z).length(), 0.05)
		var y := c0.y + d.y * lerpf(p0.length(), p1.length(), t)
		for it in range(3):
			var q := bb._hair_pt(ang, minf(y, top - 0.004), 0.0)
			y = c0.y + slope * Vector2(q.x, q.z).length()
		path.append(bb._hair_pt(ang, minf(y, top - 0.004), bb.hair_off + 0.003 + 0.006 * t))
	path[n - 1] = tie
	_lock(path, w, 0.009, {"tip": 8.0, "curl": 0.3, "root_k": 1.0, "shade": 0.95})


## A bun wound from locks round a ball of hair.
func _bun(at: Vector3, r: float) -> void:
	var was := smb.bone
	smb.bone = root_bone
	var brng := RandomNumberGenerator.new()
	brng.seed = 7
	smb.add_blob(m, Transform3D(Basis(), at), Vector3(r, r * 0.85, r), brng, 0.04, 4, 8, 3.0, c_root * 0.85)
	smb.bone = was
	for k in range(6):
		var tilt := Basis(Vector3(cos(k * 1.1), 0.4, sin(k * 1.1)).normalized(), 0.9 + 0.3 * k)
		var path := PackedVector3Array()
		var outs := PackedVector3Array()
		for i in range(12):
			var th := TAU * 0.75 * i / 11.0 + k
			var off := tilt * Vector3(cos(th), 0, sin(th)) * r * 0.96
			path.append(at + off)
			outs.append(off.normalized())
		_lock(path, r * 0.5, 0.012, {"outs": outs, "tip": 3.0, "curl": 0.3, "root_k": 0.4})


## A lock that stands out from the scalp at (a_deg, y) along dir and droops.
func _spike_lock(a_deg: float, y: float, dir: Vector3, length: float, w: float, droop: float) -> void:
	var root := bb._hair_pt(deg_to_rad(a_deg), y, bb.hair_off - 0.006)
	var path := PackedVector3Array()
	for i in range(9):
		var s := i / 8.0
		path.append(root + dir * length * s + Vector3(0, -droop * s * s, 0))
	_lock(path, w, w * 0.4, {"tip": 1.1, "curl": 0.45, "root_k": 0.7})


## Bangs from a part at part_deg: locks combed forward over the crown, falling to
## `lengths` below the hairline (centre outward, both sides).
func _bangs_part(part_deg: float, lengths: Array) -> void:
	if hatted:
		return
	for s in [-1.0, 1.0]:
		for i in range(lengths.size()):
			var a_b: float = part_deg + s * (8.0 + i * 15.0)
			_bang(part_deg + s * 3.0, a_b + s * (4.0 + i * 3.0), 0.272 * yk - float(lengths[i]), 0.034, s * 0.012 * (i + 1))


## Bangs swept across from a part on the `side` (-1 left, 1 right): count locks,
## longest over the far eye.
func _bangs_side(side: float, count: int, longest: float) -> void:
	if hatted:
		return
	var part := side * 42.0
	for i in range(count):
		var t := float(i) / (count - 1)
		var a_b := lerpf(part + side * 12.0, -side * 66.0, t)
		var lgt := lerpf(0.05, longest, 1.0 - absf(t - 0.65) * 1.4)
		_bang(part, a_b - side * 10.0 * t, 0.272 * yk - lgt, 0.036, -side * 0.02 * t)
	for i in range(3):
		_bang(part, part + side * (14.0 + i * 13.0), 0.25 * yk - 0.04 * i, 0.034, side * 0.01)


## Straight-cut bangs across the brow, from the crown.
func _bangs_blunt() -> void:
	if hatted:
		return
	for i in range(11):
		var a := lerpf(-56.0, 56.0, i / 10.0)
		_bang(a * 0.15, a, 0.205 * yk, 0.03, 0.0, 6.0)


func _bang(a0: float, a1: float, y_end: float, w: float, sweep: float, tip: float = 1.8) -> void:
	var path := PackedVector3Array()
	var n := 11
	for i in range(n):
		var t := float(i) / (n - 1)
		var a := deg_to_rad(lerpf(a0, a1, smoothstep(0.0, 0.6, t)))
		var y := lerpf(top - 0.004, y_end, t)
		var p := bb._hair_pt(a, y, bb.hair_off + 0.001 + 0.016 * smoothstep(0.35, 1.0, t))
		p += Vector3(cos(a), 0, sin(a)) * sweep * t * t
		path.append(p)
	_lock(path, w, 0.011, {"tip": tip, "curl": 0.6, "root_k": 0.6})


## The antenna strand springing up off the crown and curling forward.
func _ahoge() -> void:
	if hatted:
		return
	var p0 := bb._hair_pt(deg_to_rad(15.0), top - 0.006, bb.hair_off)
	var path := _spline(PackedVector3Array([p0, p0 + Vector3(0.0, 0.06, 0.01), p0 + Vector3(0.01, 0.11, -0.02),
		p0 + Vector3(0.015, 0.125, -0.065), p0 + Vector3(0.01, 0.1, -0.095)]), 12)
	_lock(path, 0.02, 0.008, {"tip": 1.5, "curl": 0.4, "root_k": 1.0})


## A hair stick from a to b with a bead at b.
func _pin(a: Vector3, b: Vector3, mat: Material, r: float) -> void:
	var was := smb.bone
	smb.bone = root_bone
	var dir := (b - a).normalized()
	smb.add_cylinder(mat, Transform3D(Basis(Quaternion(Vector3.UP, dir)), a), r, r * 0.6, a.distance_to(b), 5, 2.0, Color.WHITE, true, true)
	var brng := RandomNumberGenerator.new()
	brng.seed = 3
	smb.add_blob(mat, Transform3D(Basis(), b), Vector3.ONE * r * 2.6, brng, 0.0, 3, 6, 2.0)
	smb.bone = was


## A tie round a tail at c, along axis.
func _band(c: Vector3, axis: Vector3, r: float, bone: int) -> void:
	var was := smb.bone
	smb.bone = bone
	smb.add_loft(bb._cloth("sash_color"), Transform3D(Basis(Quaternion(Vector3.UP, axis)), c),
		[[-0.012, r, r], [0.012, r, r]], MeshBuilder.profile_oct(0.5), 3.0, Color.WHITE, true, true)
	smb.bone = was


# ---------------------------------------------------------------- the lock

## A lock along path: a lens cross-section `w` half-wide and `d` thick whose
## edges curl in toward the head (curl), widening from root_k at the root, then
## narrowing to a point (tip: higher = later and blunter). Skinned per ring
## to `bones` (rigid when none), its width laid across `outs` (default: away
## from the head). Coloured by height (or along it, by_s) from root to tip.
func _lock(path: PackedVector3Array, w: float, d: float, o: Dictionary = {}) -> void:
	var n := path.size()
	if n < 2:
		return
	var bones: PackedInt32Array = o.get("bones", PackedInt32Array())
	var outs: PackedVector3Array = o.get("outs", PackedVector3Array())
	var curl: float = o.get("curl", 0.55)
	var tip: float = o.get("tip", 2.2)
	var root_k: float = o.get("root_k", 0.55)
	var by_s: bool = o.get("by_s", false)
	var shade: float = float(o.get("shade", 1.0)) * rng.randf_range(0.9, 1.06)
	var u0 := rng.randf()
	var cum := PackedFloat32Array([0.0])
	for i in range(1, n):
		cum.append(cum[i - 1] + path[i].distance_to(path[i - 1]))
	var total := maxf(cum[n - 1], 1e-4)
	var pos: Array = []
	var nor: Array = []
	var cols := PackedColorArray()
	var sheen := PackedFloat32Array()
	for i in range(n):
		var p := path[i]
		var tng := (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var out := outs[i] if outs.size() == n else p - Vector3(0, minf(p.y, 0.15 * yk), 0)
		var nrm := out - tng * out.dot(tng)
		nrm = nrm.normalized() if nrm.length_squared() > 1e-10 else Vector3.BACK
		var side := tng.cross(nrm).normalized()
		var u := cum[i] / total
		var k := lerpf(root_k, 1.0, smoothstep(0.0, 0.1, u)) * pow(maxf(1.0 - pow(u, tip), 0.0), 0.6)
		var dk := d * lerpf(1.0, 0.55, u) * sqrt(k)
		var rp := PackedVector3Array()
		var rn := PackedVector3Array()
		for q in range(SIDES):
			var th := TAU * q / SIDES
			var cx := cos(th)
			var cy := sin(th)
			rp.append(p + side * (cx * w * k) + nrm * (cy * dk - curl * cx * cx * w * k * 0.35))
			rn.append((side * cx * 0.7 + nrm * cy).normalized())
		pos.append(rp)
		nor.append(rn)
		var t := u if by_s else clampf((grad_hi - p.y) / maxf(grad_hi - grad_lo, 0.05), 0.0, 1.0)
		var c := c_root.lerp(c_tip, smoothstep(0.0, 1.0, t)) * shade
		c.a = 1.0
		cols.append(c)
		# the sheen band round the head (an anime "angel ring"), on the locks' upper faces
		sheen.append(1.0 + 0.3 * exp(-pow((p.y - 0.255 * yk) / 0.022, 2.0)))
	for i in range(n - 1):
		var b0 := bones[i] if bones.size() == n else root_bone
		var b1 := bones[i + 1] if bones.size() == n else root_bone
		var ra: PackedVector3Array = pos[i]
		var rb: PackedVector3Array = pos[i + 1]
		var na: PackedVector3Array = nor[i]
		var nb: PackedVector3Array = nor[i + 1]
		var v0 := cum[i] * 4.0
		var v1 := cum[i + 1] * 4.0
		for q in range(SIDES):
			var q1 := (q + 1) % SIDES
			var sq := sin(TAU * q / SIDES)
			var sq1 := sin(TAU * q1 / SIDES)
			var dq := 0.72 if sq < -0.1 else 1.0
			var dq1 := 0.72 if sq1 < -0.1 else 1.0
			var ca := cols[i] * dq * (sheen[i] if sq > 0.3 else 1.0)
			var cb := cols[i] * dq1 * (sheen[i] if sq1 > 0.3 else 1.0)
			var cc := cols[i + 1] * dq1 * (sheen[i + 1] if sq1 > 0.3 else 1.0)
			var cd := cols[i + 1] * dq * (sheen[i + 1] if sq > 0.3 else 1.0)
			ca.a = 1.0; cb.a = 1.0; cc.a = 1.0; cd.a = 1.0
			var ua := Vector2(u0 + q * 0.12, v0)
			var ub := Vector2(u0 + (q + 1) * 0.12, v0)
			var uc := Vector2(u0 + (q + 1) * 0.12, v1)
			var ud := Vector2(u0 + q * 0.12, v1)
			smb.add_tri(m, ra[q], ra[q1], rb[q1], na[q], na[q1], nb[q1], ua, ub, uc, Color.WHITE, na[q] + na[q1] + nb[q1],
				PackedInt32Array([b0, b0, b1]), PackedColorArray([ca, cb, cc]))
			smb.add_tri(m, ra[q], rb[q1], rb[q], na[q], nb[q1], nb[q], ua, uc, ud, Color.WHITE, na[q] + nb[q1] + nb[q],
				PackedInt32Array([b0, b1, b1]), PackedColorArray([ca, cc, cd]))


## Catmull-Rom through pts, n samples.
static func _spline(pts: PackedVector3Array, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var segs := pts.size() - 1
	for i in range(n):
		var f := float(i) / (n - 1) * segs
		var k := mini(int(f), segs - 1)
		var t := f - k
		var p0 := pts[maxi(k - 1, 0)]
		var p3 := pts[mini(k + 2, segs)]
		out.append(pts[k].cubic_interpolate(pts[k + 1], p0, p3, t))
	return out
