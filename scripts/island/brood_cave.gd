class_name BroodCave
extends Node3D
## The brood cave in the deep forest: a craggy outcrop with its mouth to the
## east (+X), the chamber hollowed out of it, and a sinkhole in its top letting
## a shaft of daylight onto the brood queen's nest. Inside: dripstone hanging
## and rising, puddles under the drips, glowing lichen. Walk in and she wakes;
## leave and she settles back on her eggs, healed. Beat her and her hoard is
## yours (once per character); she's back after a long while if nobody's near.
## Origin: the cave floor's centre.

const R_IN := 17.0
const H_IN := 10.0
## The outcrop's mean foot radius (it stays inside the island's 32 m reserve).
const R_OUT := 25.0
const SINK := 1.5
const N_A := 48
## Chamber ring elevations (degrees); the mouth cuts the bands below ring MOUTH_TOP.
const RINGS := [0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 68.0, 76.0]
const MOUTH_TOP := 4
## The mouth's cells, centred on +X.
const MOUTH := [0, 1, 2]
## The outside's rings: the cliff foot level with the chamber's up to the mouth's
## top (heights here), then UP_N up to the crest and DOWN_N down to the sinkhole's rim.
const OUT_LOW := [-1.5, 0.6, 2.5, 4.4, 6.6]
const UP_N := 6
const DOWN_N := 3
## The nest and the egg clusters (bearings, radius), kept clear of dripstone.
const NEST := Vector2(-6.0, 0.0)
const EGGS := [2.3, 3.1, 3.9]
const EGG_R := 13.5
const RESET_AFTER := 6.0
const RESPAWN := 900.0
const HOARD_ID := "brood_hoard"

var queen: BroodQueen
var queen_gen: int = 0
var brood: ScuttlebugNest
var _noise := FastNoiseLite.new()
var _wave := FastNoiseLite.new()
var _arrived := false
var _boss_ui := false
var _celebrated := false
var _empty_t: float = 0.0
var _dead_t: float = 0.0
## Where water drips: [tip, puddle centre].
var _drips: Array = []
## Flat facets on the outside, for plants: [centre, normal].
var _ledges: Array = []
var _drop_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("net_spawner")
	_noise.seed = 4711
	_noise.frequency = 0.05
	_wave.seed = 1907
	_wave.frequency = 0.35
	_build_rock()
	_build_dripstone()
	_build_floor()
	_build_lichen()
	_dress_outside()
	_build_inside()
	brood = ScuttlebugNest.new()
	brood.name = "Brood"
	brood.start_empty = true
	brood.respawn_time = INF
	for a in EGGS:
		brood.add_spot(Vector3(cos(a) * 12.0, 0.0, sin(a) * 12.0))
	add_child(brood)
	_spawn_queen()


# --------------------------------------------------------------------------
# The rock: the outcrop outside, the chamber inside, the mouth through both
# --------------------------------------------------------------------------
## Bearing of grid column i (cells 0..2 straddle +X: the mouth).
func _ang(i: int) -> float:
	return TAU * (float(posmod(i, N_A)) - 1.5) / N_A


## A smooth value round the compass (about -1..1), a different one per `k`.
func _round(a: float, k: int) -> float:
	return _wave.get_noise_2d(cos(a) * 3.0 + k * 50.0, sin(a) * 3.0)


## 1 at bearing `at`, falling off over `width` radians.
func _peak(a: float, at: float, width: float) -> float:
	return exp(-pow(angle_difference(a, at) / width, 2.0))


## How far out the outcrop's foot is at bearing `a` (always well clear of the chamber).
func _foot(a: float) -> float:
	var r := R_OUT + 3.0 * _round(a, 0) + 1.2 * _wave.get_noise_2d(cos(a) * 7.0 + 300.0, sin(a) * 7.0) + 2.0 * maxf(0.0, -cos(a))
	var w := _inner_at(a, 0.0)
	return maxf(r, Vector2(w.x, w.z).length() + 2.5)


## The chamber's wall at bearing `a`, elevation `deg`: full and near upright at
## the foot, vaulting into the roof, rough all over.
func _inner_at(a: float, deg: float) -> Vector3:
	var phi := deg_to_rad(deg)
	var dir := Vector3(cos(a), 0.0, sin(a))
	var sph := dir * cos(phi) + Vector3.UP * sin(phi)
	var n := _noise.get_noise_3dv(sph * 40.0) + 0.4 * _noise.get_noise_3dv(sph * 130.0)
	var k := lerpf(1.13 + 0.07 * n, 1.0 + 0.14 * n, smoothstep(20.0, 50.0, deg))
	var f := lerpf(pow(cos(phi), 0.55), cos(phi), smoothstep(30.0, 70.0, deg))
	return dir * R_IN * f * k + Vector3.UP * (-SINK + (H_IN + SINK) * sin(phi))


## The mouth's edge columns lean in toward the top and its lintel rises in the
## middle, so it's a rough arch, not a doorway: [bearing shift, lift] for column i, ring j.
func _arch(i: int, j: int) -> Vector2:
	var c := posmod(i, N_A)
	var cell := TAU / N_A
	var k: float = [0.0, 0.05, 0.15, 0.35, 0.6][j] if j <= MOUTH_TOP else 0.0
	if c == MOUTH[0]:
		return Vector2(k * cell, 0.0)
	if c == MOUTH[MOUTH.size() - 1] + 1:
		return Vector2(-k * cell, 0.0)
	if j == MOUTH_TOP and c > MOUTH[0] and c <= MOUTH[MOUTH.size() - 1]:
		return Vector2(0.0, 1.0)
	return Vector2.ZERO


## The chamber's grid point at column i, ring j (the arch applied).
func _inner(i: int, j: int) -> Vector3:
	var s := _arch(i, j)
	return _inner_at(_ang(i) + s.x, RINGS[j]) + Vector3.UP * s.y


## Horizontal distance to the chamber's wall at bearing `a`, about knee height.
func _wall_r(a: float) -> float:
	var p := _inner_at(a, 10.0)
	return Vector2(p.x, p.z).length()


func _out_n() -> int:
	return OUT_LOW.size() + UP_N + DOWN_N


## The outside at column i, ring j: a cliff foot (its height and steepness
## changing round the compass; fixed only at the mouth), slopes rising into a
## crest (a high crag to the west-south-west, lower ones north and south, lowest
## over the mouth), then down into the sinkhole. Crags pushed out and up by noise.
func _outer(i: int, j: int) -> Vector3:
	var s := _arch(i, j)
	var a := _ang(i) + s.x
	var dir := Vector3(cos(a), 0.0, sin(a))
	var rb := _foot(a)
	var back := maxf(0.0, -cos(a))
	var away := smoothstep(0.35, 0.9, absf(angle_difference(a, 0.0)))
	var lift := lerpf(1.0, 1.0 + 1.1 * (_round(a, 5) * 0.5 + 0.5) + 0.6 * back, away)
	var spread := lerpf(1.0, 1.0 + 2.5 * (_round(a, 6) * 0.5 + 0.5), away)
	var fr: float = [1.0, 0.985, 0.96, 0.93, 0.9][mini(j, 4)]
	var p0 := Vector2(rb * (1.0 - 0.1 * spread), OUT_LOW[4] * lift)
	var hc := 14.0 + 12.0 * _peak(a, PI + 0.35, 0.75) + 6.5 * _peak(a, -1.7, 0.5) + 4.0 * _peak(a, 1.9, 0.4) + 2.5 * _round(a, 1)
	hc = maxf(hc, p0.y + 3.0)
	var rc := 11.5 + 1.5 * _round(a, 2) + 2.0 * back
	var rim := Vector2(6.0 + 0.5 * _round(a, 3), 11.0 + 0.6 * _round(a, 4))
	var low := OUT_LOW.size()
	var p: Vector2
	var amp: float
	if j < low:
		p = Vector2(rb * (1.0 - (1.0 - fr) * spread), OUT_LOW[j] * (lift if j > 0 else 1.0))
		amp = [0.8, 1.2, 1.2, 1.2, 1.4][j]
	elif j < low + UP_N:
		# concave where `steep` is high: the slope rears up into a ridge
		var t := float(j - low + 1) / UP_N
		var steep := _round(a, 7) * 0.5 + 0.5
		var c := Vector2(lerpf(p0.x, rc, lerpf(0.55, 0.8, steep)), lerpf(p0.y, hc, lerpf(0.45, 0.25, steep)))
		p = p0.lerp(c, t).lerp(c.lerp(Vector2(rc, hc), t), t)
		amp = 2.6
	else:
		var t := float(j - low - UP_N + 1) / DOWN_N
		p = Vector2(rc, hc).lerp(rim, t)
		p.y += sin(t * PI) * 1.2
		amp = 0.4 if j == _out_n() - 1 else 2.6
	var pos := dir * p.x + Vector3.UP * p.y
	var n := _noise.get_noise_3dv(pos * 1.2) + 0.5 * _noise.get_noise_3dv(pos * 3.5)
	pos += (dir * 0.8 + Vector3.UP * 0.4) * n * amp
	if j == low + UP_N - 1:
		pos.y += 2.0 * maxf(0.0, _noise.get_noise_3dv(pos * 4.0))
	if j == 0:
		pos.y = OUT_LOW[0]
	return pos + Vector3.UP * s.y * 0.8


## Texture coordinates projected along the facet's main axis, shifted by `off`
## per facet so the rock's cracks don't line up into a grid.
func _tuv(p: Vector3, n: Vector3, s: float, off: Vector2) -> Vector2:
	var an := n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z) * s + off
	if an.x >= an.z:
		return Vector2(p.z, -p.y) * s + off
	return Vector2(p.x, -p.y) * s + off


## One flat facet facing the `hint` side, its material from `pick` (normal,
## centre), shaded in strata. `ledge`: remember it for plants if it's flat.
func _facet(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3, hint: Vector3, pick: Callable, uv: float, ledge: bool = false) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-8:
		return
	n = n.normalized()
	if n.dot(hint) < 0.0:
		n = -n
	var m := (a + b + c) / 3.0
	var band := 0.5 + 0.5 * sin(m.y * 1.9 + 2.0 * _noise.get_noise_2d(m.x * 4.0, m.z * 4.0))
	var col := Color(1, 1, 1) * (0.78 + 0.22 * band)
	col.a = 1.0
	var off := Vector2(fposmod(m.x * 7.31 + m.z * 3.17, 1.0), fposmod(m.y * 5.13 + m.x * 2.71, 1.0))
	mb.add_tri(pick.call(n, m), a, b, c, n, n, n, _tuv(a, n, uv, off), _tuv(b, n, uv, off), _tuv(c, n, uv, off), col, n)
	if ledge and n.y > 0.8 and m.y > 1.5 and absf(angle_difference(atan2(m.z, m.x), 0.0)) > 0.5:
		_ledges.append([m, n])


## A grid cell as two facets (split on alternate diagonals so the rock doesn't grid).
func _cell(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, pick: Callable, flip: bool, uv: float, ledge: bool = false) -> void:
	if flip:
		_facet(mb, a, b, c, hint, pick, uv, ledge)
		_facet(mb, a, c, d, hint, pick, uv, ledge)
	else:
		_facet(mb, a, b, d, hint, pick, uv, ledge)
		_facet(mb, b, c, d, hint, pick, uv, ledge)


func _build_rock() -> void:
	var mb := MeshBuilder.new()
	var rock := PSXMat.lit("rock", Color(0.66, 0.63, 0.58), {"affine": 0.6})
	var moss := PSXMat.lit("rock", Color(0.55, 0.66, 0.45), {"affine": 0.6})
	var turf := PSXMat.lit("grass", Color(0.9, 1.0, 0.88), {"affine": 0.6})
	var wall := PSXMat.lit("rock", Color(0.58, 0.54, 0.52), {"affine": 0.6})
	# grass on the flats, moss on the gentler slopes, bare rock on the steep
	var outside := func(n: Vector3, m: Vector3) -> Material:
		var patch := _noise.get_noise_3dv(m * 2.5)
		return turf if n.y > 0.86 and patch > -0.15 else (moss if n.y > 0.6 and patch > -0.35 else rock)
	var bare := func(_n: Vector3, _m: Vector3) -> Material:
		return rock
	var dark := func(_n: Vector3, _m: Vector3) -> Material:
		return wall
	var on := _out_n()
	var outer: Array = []
	var inner: Array = []
	for i in range(N_A + 1):
		var o: Array = []
		for j in range(on):
			o.append(_outer(i, j))
		outer.append(o)
		var w: Array = []
		for j in range(RINGS.size()):
			w.append(_inner(i, j))
		inner.append(w)
	for i in range(N_A):
		var gap := i in MOUTH
		for j in range(on - 1):
			if gap and j < MOUTH_TOP:
				continue
			var a: Vector3 = outer[i][j]
			var b: Vector3 = outer[i + 1][j]
			var d: Vector3 = outer[i][j + 1]
			_cell(mb, a, b, outer[i + 1][j + 1], d, (d - a).cross(b - a), outside, (i + j) % 2 == 0, 0.32, true)
		for j in range(RINGS.size() - 1):
			if gap and j < MOUTH_TOP:
				continue
			var a: Vector3 = inner[i][j]
			var b: Vector3 = inner[i + 1][j]
			var d: Vector3 = inner[i][j + 1]
			_cell(mb, a, b, inner[i + 1][j + 1], d, (b - a).cross(d - a), dark, (i + j) % 2 == 1, 0.4)
		# the sinkhole's throat, from the chamber's roof up to the crater's rim
		var top := RINGS.size() - 1
		var am := TAU * (float(i) - 1.0) / N_A
		var toward := Vector3(-cos(am), 0.6, -sin(am))
		_cell(mb, inner[i][top], inner[i + 1][top], outer[i + 1][on - 1], outer[i][on - 1], toward, bare, i % 2 == 0, 0.4)
		if gap:
			_cell(mb, inner[i][MOUTH_TOP], inner[i + 1][MOUTH_TOP], outer[i + 1][MOUTH_TOP], outer[i][MOUTH_TOP], Vector3.DOWN, bare, i % 2 == 0, 0.32)
	# the mouth's sides, facing into the opening
	for e in [[MOUTH[0], 1.0], [MOUTH[MOUTH.size() - 1] + 1, -1.0]]:
		var c: int = e[0]
		var a := _ang(c)
		var side := Vector3(-sin(a), 0.0, cos(a)) * float(e[1])
		for j in range(MOUTH_TOP):
			_cell(mb, inner[c][j], inner[c][j + 1], outer[c][j + 1], outer[c][j], side, bare, j % 2 == 0, 0.32)
	# boulders fallen round the foot (not across the way in)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3313
	for k in range(18):
		var a := TAU * k / 18.0 + rng.randf_range(-0.12, 0.12)
		if absf(angle_difference(a, 0.0)) < 0.45:
			continue
		var r := _foot(a) * rng.randf_range(0.97, 1.06)
		var s := rng.randf_range(1.6, 3.8)
		mb.add_blob(moss if k % 3 == 0 else rock, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r, s * 0.25, sin(a) * r)),
			Vector3(s, s * 0.7, s * 0.85), rng, 0.25, 4, 7, 0.4, Color.WHITE, -0.5)
	var mesh := mb.commit()
	var body := StaticBody3D.new()
	body.name = "Dome"
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


# --------------------------------------------------------------------------
# Dripstone, puddles and drips
# --------------------------------------------------------------------------
## Room for dripstone at `p` with `room` to spare: off the nest, the egg
## clusters and the brood's spots, the way in, the middle (the fight) and the
## back wall's foot behind the eggs.
func _clear(p: Vector3, room: float) -> bool:
	var f := Vector2(p.x, p.z)
	var a := atan2(f.y, f.x)
	if f.distance_to(NEST) < 6.5 + room or f.length() < 9.0 or absf(angle_difference(a, 0.0)) < 0.5:
		return false
	if absf(angle_difference(a, 3.1)) < 1.1 and f.length() > 14.8:
		return false
	for e in EGGS:
		var c := Vector2(cos(e), sin(e))
		if f.distance_to(c * EGG_R) < 3.6 + room or f.distance_to(c * 12.0) < 2.6 + room:
			return false
	return true


## A stalactite (`down`) hanging from `root` or a stalagmite rising from it:
## flared where it meets the rock, tapering to a point in lumpy rings. Returns the tip.
func _dripstone(mb: MeshBuilder, mat: Material, root: Vector3, length: float, r0: float, down: bool, rng: RandomNumberGenerator, col: Color) -> Vector3:
	var s := -1.0 if down else 1.0
	var lean := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (0.02 if down else 0.08) * length
	var ph := rng.randf() * TAU
	var rings: Array = [[-s * 0.8, r0 * 1.5, r0 * 1.5]]
	var n := maxi(3, int(length * 2.5))
	for k in range(n + 1):
		var t := float(k) / n
		var r := r0 * (1.0 + 0.35 * pow(1.0 - t, 6.0)) * pow(1.0 - t * 0.97, 1.3) * (1.0 + 0.1 * sin(ph + t * 11.0))
		rings.append([s * length * t, r, r, lean.y * t * t, lean.x * t * t])
	mb.add_loft(mat, Transform3D(Basis(), root), rings, MeshBuilder.profile_circle(6), 1.5, col, down, not down)
	return root + Vector3(lean.x, s * length, lean.y)


## A column where a stalactite and a stalagmite met: floor to roof, pinched in the middle.
func _column(mb: MeshBuilder, mat: Material, p: Vector3, top: float, r0: float, rng: RandomNumberGenerator, col: Color) -> void:
	var ph := rng.randf() * TAU
	var rings: Array = []
	var n := int(top * 2.0)
	for k in range(n + 1):
		var t := float(k) / n
		var r := r0 * (0.45 + 0.55 * pow(absf(2.0 * t - 1.0), 1.6)) * (1.0 + 0.1 * sin(ph + t * 14.0))
		rings.append([lerpf(-0.4, top + 0.8, t), r, r])
	mb.add_loft(mat, Transform3D(Basis(), p), rings, MeshBuilder.profile_circle(7), 1.5, col)


func _pillar(body: StaticBody3D, p: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	cs.shape = cyl
	cs.position = p + Vector3.UP * h * 0.5
	body.add_child(cs)


func _build_dripstone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6620
	var mb := MeshBuilder.new()
	var stone := PSXMat.lit("rock", Color(0.78, 0.73, 0.64))
	var body: StaticBody3D = get_node("Dome")
	# stalactites in clusters under the vault (tips kept above the fight in the middle)
	var made := 0
	var tries := 0
	while made < 18 and tries < 300:
		tries += 1
		var a := rng.randf() * TAU
		var deg := rng.randf_range(38.0, 71.0)
		var root := _inner_at(a, deg)
		var low := 4.8 if Vector2(root.x, root.z).length() < 12.5 else 2.8
		var length := minf(rng.randf_range(1.2, 3.8), root.y - low)
		if length < 0.7:
			continue
		made += 1
		var tip := _dripstone(mb, stone, root, length, length * rng.randf_range(0.14, 0.2), true, rng, Color.WHITE * rng.randf_range(0.85, 1.05))
		for k in range(rng.randi_range(1, 3)):
			var r2 := _inner_at(a + rng.randf_range(-0.07, 0.07), deg + rng.randf_range(-4.0, 4.0))
			var l2 := minf(rng.randf_range(0.3, 1.0), r2.y - low)
			if l2 > 0.2:
				_dripstone(mb, stone, r2, l2, l2 * 0.2, true, rng, Color.WHITE * rng.randf_range(0.85, 1.05))
		var under := Vector3(tip.x, 0.0, tip.z)
		if length < 1.6:
			continue
		if Vector2(tip.x, tip.z).length() > 12.0 and rng.randf() < 0.5 and _clear(under, 0.5):
			# grown up to meet it
			var h := minf(rng.randf_range(0.6, 1.8), tip.y - 1.0)
			_dripstone(mb, stone, under, h, h * 0.3, false, rng, Color.WHITE * 0.9)
			if h * 0.3 >= 0.3:
				_pillar(body, under, h * 0.22, h)
		elif _drips.size() < 8 and Vector2(tip.x, tip.z).distance_to(NEST) > 5.0:
			_drips.append([tip, Vector3(tip.x, 0.08, tip.z)])
	# stalagmites round the walls, a few small ones further in
	made = 0
	tries = 0
	while made < 24 and tries < 500:
		tries += 1
		var a := rng.randf() * TAU
		var wr := _wall_r(a)
		var r := rng.randf_range(9.5, wr - 0.8)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var near_wall := r > 12.5
		var h := rng.randf_range(0.8, 3.8) if near_wall else rng.randf_range(0.4, 1.4)
		var r0 := h * rng.randf_range(0.17, 0.25)
		if not _clear(p, r0):
			continue
		made += 1
		_dripstone(mb, stone, p, h, r0, false, rng, Color.WHITE * rng.randf_range(0.82, 1.0))
		if r0 >= 0.3:
			_pillar(body, p, r0 * 0.75, h)
		for k in range(rng.randi_range(0, 3)):
			var q := p + Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			var hs := rng.randf_range(0.25, 0.7)
			if _clear(q, 0.1):
				_dripstone(mb, stone, q, hs, hs * 0.25, false, rng, Color.WHITE * rng.randf_range(0.82, 1.0))
	# columns where the roof comes down to meet the floor
	for a in [1.2, 5.05]:
		var r := _wall_r(a) - 2.4
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var top := 0.0
		for deg in range(0, 77):
			var w := _inner_at(a, float(deg))
			if Vector2(w.x, w.z).length() < r:
				top = w.y
				break
		_column(mb, stone, p, top, 0.75, rng, Color.WHITE * 0.92)
		_pillar(body, p, 0.42, top)
	# puddles under the drips: water in a damp stain
	var water := PSXMat.lit("water", Color(0.3, 0.4, 0.46), {"emission": Color(0.1, 0.18, 0.22), "emission_energy": 0.6})
	var damp := PSXMat.flat(Color(0.14, 0.13, 0.12))
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	for d in _drips:
		var c: Vector3 = d[1]
		var size := rng.randf_range(0.5, 1.2)
		var pool := PackedVector2Array()
		var stain := PackedVector2Array()
		for k in range(10):
			var t := TAU * k / 10.0
			var r := size * rng.randf_range(0.7, 1.15)
			pool.append(Vector2(cos(t), sin(t)) * r)
			stain.append(Vector2(cos(t), sin(t)) * (r + rng.randf_range(0.2, 0.45)))
		mb.add_extrude(damp, Transform3D(flat, Vector3(c.x, 0.055, c.z)), stain, 0.012, 1.0)
		mb.add_extrude(water, Transform3D(flat, Vector3(c.x, 0.07, c.z)), pool, 0.02, 0.8)
		_drip_fx(d[0], 0.08, rng.randf_range(1.6, 3.2), rng.randf())
	var inst := mb.to_instance("Dripstone")
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## A drop falling from `tip` every `interval` s (`phase` 0..1 through it) and a
## ripple spreading on the puddle when it lands.
func _drip_fx(tip: Vector3, floor_y: float, interval: float, phase: float) -> void:
	if _drop_mat == null:
		_drop_mat = _fx_mat(null, Color(0.75, 0.9, 1.0, 0.85))
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in range(32):
			for x in range(32):
				var r := Vector2(x - 15.5, y - 15.5).length()
				if r > 11.0 and r < 14.5:
					img.set_pixel(x, y, Color.WHITE)
		_ring_mat = _fx_mat(ImageTexture.create_from_image(img), Color.WHITE)
	var fall := sqrt(2.0 * maxf(tip.y - floor_y, 0.1) / 9.8)
	var drop := CPUParticles3D.new()
	drop.name = "Drip"
	drop.amount = 1
	drop.lifetime = interval
	drop.preprocess = phase * interval
	drop.local_coords = true
	drop.position = tip
	drop.direction = Vector3.DOWN
	drop.spread = 0.0
	drop.initial_velocity_min = 0.0
	drop.initial_velocity_max = 0.0
	drop.gravity = Vector3(0, -9.8, 0)
	var dm := BoxMesh.new()
	dm.size = Vector3(0.025, 0.08, 0.025)
	dm.material = _drop_mat
	drop.mesh = dm
	add_child(drop)
	var ring := CPUParticles3D.new()
	ring.name = "Ripple"
	ring.amount = 1
	ring.lifetime = interval
	ring.preprocess = fposmod(phase * interval - fall, interval)
	ring.local_coords = true
	ring.position = Vector3(tip.x, floor_y + 0.015, tip.z)
	ring.gravity = Vector3.ZERO
	ring.initial_velocity_min = 0.0
	ring.initial_velocity_max = 0.0
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.5, 0.5)
	pm.material = _ring_mat
	ring.mesh = pm
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.15))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1.0, 1.0))
	ring.scale_amount_curve = sc
	ring.scale_amount_min = 1.6
	ring.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.95, 1.0, 0.85))
	g.set_color(1, Color(0.8, 0.95, 1.0, 0.0))
	g.add_point(0.3, Color(0.8, 0.95, 1.0, 0.0))
	ring.color_ramp = g
	add_child(ring)


func _fx_mat(tex: Texture2D, col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


# --------------------------------------------------------------------------
# The floor and the lichen
# --------------------------------------------------------------------------
## Packed dirt with patches of bare rock, damp round the puddles and darker at
## the walls, a tongue of it out through the mouth. Visual only: the island's
## ground (flat here) is under it.
func _build_floor() -> void:
	var mb := MeshBuilder.new()
	var dirt := PSXMat.lit("dirt", Color(0.6, 0.55, 0.5))
	var stone := PSXMat.lit("rock", Color(0.5, 0.47, 0.44))
	var fr := [0.0, 0.18, 0.36, 0.54, 0.7, 0.84, 0.94, 1.0]
	var grid: Array = []
	for i in range(N_A + 1):
		var a := _ang(i)
		var c := posmod(i, N_A)
		var edge := _foot(a) - 0.6 if c >= MOUTH[0] and c <= MOUTH[MOUTH.size() - 1] + 1 else _wall_r(a) * 0.97
		var row: Array = []
		for f in fr:
			var p := Vector3(cos(a), 0.0, sin(a)) * edge * float(f)
			p.y = 0.03 + 0.03 * (_noise.get_noise_2d(p.x * 6.0, p.z * 6.0) * 0.5 + 0.5)
			row.append(p)
		grid.append(row)
	for i in range(N_A):
		for k in range(fr.size() - 1):
			var q: Array = [grid[i][k], grid[i + 1][k], grid[i + 1][k + 1], grid[i][k + 1]]
			for t in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = q[t[0]]
				var b: Vector3 = q[t[1]]
				var c: Vector3 = q[t[2]]
				if (b - a).cross(c - a).length_squared() < 1e-8:
					continue
				var m := (a + b + c) / 3.0
				var shade := 0.85 + 0.15 * _noise.get_noise_2d(m.x * 9.0, m.z * 9.0)
				for d in _drips:
					shade *= lerpf(0.6, 1.0, clampf((Vector2(m.x, m.z).distance_to(Vector2(d[1].x, d[1].z)) - 0.6) / 2.0, 0.0, 1.0))
				if float(fr[k]) > 0.83 and m.length() < R_IN * 1.2:
					shade *= 0.8
				var col := Color(shade, shade, shade)
				var mat := stone if _noise.get_noise_2d(m.x * 3.0 + 40.0, m.z * 3.0) > 0.2 else dirt
				mb.add_tri(mat, a, b, c, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(a.x, a.z) * 0.4, Vector2(b.x, b.z) * 0.4, Vector2(c.x, c.z) * 0.4, col, Vector3.UP)
	var inst := mb.to_instance("Floor")
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## A patch of glowing lichen on the rock at `p` facing `nrm`: flattened blobs
## smeared in streaks down the wall.
func _lichen_patch(mb: MeshBuilder, mat: Material, p: Vector3, nrm: Vector3, rng: RandomNumberGenerator, spread: float = 0.45) -> void:
	var t1 := nrm.cross(Vector3.UP if absf(nrm.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := nrm.cross(t1)
	var b := Basis(t1, nrm, t1.cross(nrm))
	for k in range(rng.randi_range(6, 12)):
		var off := t1 * rng.randf_range(-spread, spread) + t2 * rng.randf_range(-spread, spread) * 1.4
		var s := rng.randf_range(0.08, 0.22)
		mb.add_blob(mat, Transform3D(b, p + nrm * 0.03 + off), Vector3(s, 0.03, s * rng.randf_range(0.7, 1.5)), rng, 0.3, 2, 5, 1.0)


func _build_lichen() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var mb := MeshBuilder.new()
	var bright := PSXMat.glow(Color(0.35, 1.0, 0.75), 1.9)
	var dim := PSXMat.glow(Color(0.25, 0.62, 0.95), 1.3)
	var mid := Vector3(0, H_IN * 0.3, 0)
	# colonies low on the walls, spreading up in streaks; a few strays in the vault
	for k in range(11):
		var a := TAU * (k + 0.5) / 11.0 + rng.randf_range(-0.2, 0.2)
		if absf(angle_difference(a, 0.0)) < 0.4:
			continue
		var deg := rng.randf_range(10.0, 30.0)
		var mat := dim if k % 4 == 0 else bright
		for q in range(rng.randi_range(4, 8)):
			var p := _inner_at(a + rng.randf_range(-0.1, 0.1), deg + rng.randf_range(-6.0, 12.0))
			_lichen_patch(mb, mat, p, (mid - p).normalized(), rng, 0.6)
	for k in range(8):
		var p := _inner_at(rng.randf() * TAU, rng.randf_range(45.0, 70.0))
		_lichen_patch(mb, dim, p, (mid - p).normalized(), rng, 0.3)
	for d in _drips:
		var c: Vector3 = d[1]
		var t := rng.randf() * TAU
		_lichen_patch(mb, bright, c + Vector3(cos(t), -0.04, sin(t)) * 1.4, Vector3.UP, rng, 0.3)
	var inst := mb.to_instance("Lichen")
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	for a in [1.35, 4.75]:
		var r := _wall_r(a) - 3.0
		var l := OmniLight3D.new()
		l.name = "LichenLight"
		l.position = Vector3(cos(a) * r, 2.0, sin(a) * r)
		l.light_color = Color(0.4, 0.95, 0.85)
		l.light_energy = 1.1
		l.omni_range = 12.0
		l.shadow_enabled = false
		add_child(l)


# --------------------------------------------------------------------------
# Outside: plants on the ledges, vines over the mouth, scree at the foot
# --------------------------------------------------------------------------
func _dress_outside() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5157
	var kinds := [Props.fern_mesh(41), Props.fern_mesh(42), Props.bush_mesh(43)]
	var taken: Array = []
	var trees := 0
	var plants := 0
	for k in range(_ledges.size()):
		var e: Array = _ledges[rng.randi() % _ledges.size()]
		var p: Vector3 = e[0]
		var room := 7.0 if p.y > 10.0 and trees < 3 else 2.5
		var ok := true
		for q in taken:
			if (q as Vector3).distance_to(p) < room:
				ok = false
				break
		if not ok:
			continue
		var mi := MeshInstance3D.new()
		if room > 5.0:
			mi.mesh = Props.jungle_tree_mesh(77 + trees)
			mi.scale = Vector3.ONE * rng.randf_range(0.6, 0.8)
			trees += 1
		elif plants < 26:
			mi.mesh = kinds[plants % kinds.size()]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			plants += 1
		else:
			continue
		mi.position = p - Vector3.UP * 0.05
		mi.rotation.y = rng.randf() * TAU
		add_child(mi)
		taken.append(p)
	# vines over the mouth and down the face either side of it
	var vb := MeshBuilder.new()
	var vine := PSXMat.lit("leaves", Color(0.55, 0.8, 0.45))
	var leaf := PSXMat.lit("leaves", Color(0.7, 0.95, 0.6))
	for i in range(MOUTH[0] - 1, MOUTH[MOUTH.size() - 1] + 2):
		for k in range(3):
			var top := _outer(i, MOUTH_TOP).lerp(_outer(i + 1, MOUTH_TOP), rng.randf())
			var out := Vector3(top.x, 0.0, top.z).normalized()
			var l := rng.randf_range(0.8, 3.2)
			var pts := MeshBuilder.curve_points(top - out * 0.1, top + out * 0.35 + Vector3.DOWN * l * 0.5, top + Vector3.DOWN * l + out * 0.15, 6)
			vb.add_tube(vine, pts, 0.035, 0.02, 4, 2.0)
			for q in range(2):
				vb.add_blob(leaf, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), pts[rng.randi_range(2, 6)]), Vector3(0.16, 0.1, 0.12), rng, 0.3, 2, 5, 1.0)
	add_child(vb.to_instance("Vines"))
	# scree round the foot (no collision: small stuff you walk through)
	var sb := MeshBuilder.new()
	var rock := PSXMat.lit("rock", Color(0.66, 0.63, 0.58), {"affine": 0.6})
	var moss := PSXMat.lit("rock", Color(0.55, 0.66, 0.45), {"affine": 0.6})
	for k in range(60):
		var a := rng.randf() * TAU
		if absf(angle_difference(a, 0.0)) < 0.32:
			continue
		var r := _foot(a) + rng.randf_range(-0.5, 3.0)
		var s := rng.randf_range(0.2, 0.75)
		sb.add_blob(moss if rng.randf() < 0.3 else rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * r, s * 0.2, sin(a) * r)),
			Vector3(s, s * 0.6, s * 0.8), rng, 0.25, 3, 5, 0.6, Color.WHITE, -0.4)
	var scree := sb.to_instance("Scree")
	scree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scree)


# --------------------------------------------------------------------------
# Inside: the nest, egg sacs, bones, glowing fungus, the light
# --------------------------------------------------------------------------
func _build_inside() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 905
	var mb := MeshBuilder.new()
	var silk := PSXMat.lit("canvas", Color(0.85, 0.88, 0.78))
	var egg := PSXMat.glow(Color(0.55, 0.9, 0.35), 0.9)
	var bone := PSXMat.lit("", Color(0.9, 0.86, 0.74))
	var fungus := PSXMat.glow(Color(0.35, 0.95, 0.85), 2.2)
	var stalk := PSXMat.lit("", Color(0.75, 0.72, 0.6))
	# the nest: a low ring of silk-bound debris at the back
	for k in range(14):
		var a := TAU * k / 14.0
		var p := Vector3(NEST.x + cos(a) * 4.2, 0.1, NEST.y + sin(a) * 4.2)
		mb.add_blob(silk, Transform3D(Basis(Vector3.UP, a), p), Vector3(1.0, 0.45, 0.6), rng, 0.25, 3, 6)
	# egg sacs in clusters along the wall (where the brood hatches)
	for a in EGGS:
		var c := Vector3(cos(a) * EGG_R, 0.0, sin(a) * EGG_R)
		for e in range(5):
			var off := Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2))
			mb.add_blob(egg, Transform3D(Basis(), c + off + Vector3(0, 0.35, 0)), Vector3.ONE * rng.randf_range(0.35, 0.55), rng, 0.15, 3, 6)
		mb.add_blob(silk, Transform3D(Basis(), c + Vector3(0, 0.15, 0)), Vector3(2.0, 0.3, 2.0), rng, 0.3, 3, 7)
	# what's left of the queen's dinners
	for k in range(9):
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, 14.0)
		var p := Vector3(cos(a) * r, 0.09, sin(a) * r)
		if p.x > 8.0 and absf(p.z) < 5.0:
			continue
		mb.add_box(bone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5), p), Vector3(0.08, rng.randf_range(0.5, 0.9), 0.08), 1.0)
	mb.add_blob(bone, Transform3D(Basis(), Vector3(-9.0, 0.2, 7.0)), Vector3(0.25, 0.22, 0.28), rng, 0.1, 3, 6)
	# glowing fungus round the foot of the walls
	for k in range(22):
		var a := TAU * k / 22.0 + rng.randf_range(-0.1, 0.1)
		if absf(angle_difference(a, 0.0)) < 0.35:
			continue
		var r := _wall_r(a) - rng.randf_range(0.6, 1.6)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		for f in range(3):
			var q := p + Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
			var h := rng.randf_range(0.2, 0.55)
			mb.add_cylinder(stalk, Transform3D(Basis(), q), 0.04, 0.03, h, 4, 1.0)
			mb.add_cylinder(fungus, Transform3D(Basis(), q + Vector3(0, h, 0)), 0.16, 0.02, 0.1, 6, 1.0, Color.WHITE, false, true)
	# rubble along the walls
	var rocks := MeshBuilder.new()
	var rock := PSXMat.lit("rock", Color(0.5, 0.48, 0.45), {"affine": 0.6})
	for k in range(12):
		var a := rng.randf() * TAU
		if absf(angle_difference(a, 0.0)) < 0.45:
			continue
		var r := _wall_r(a) - rng.randf_range(0.8, 2.5)
		rocks.add_blob(rock, Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * r, 0.2, sin(a) * r)), Vector3.ONE * rng.randf_range(0.6, 1.4), rng, 0.25, 3, 6)
	var inside := mb.to_instance("Inside")
	inside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inside)
	add_child(rocks.to_instance("Rubble"))
	var glow := OmniLight3D.new()
	glow.name = "FungusLight"
	glow.position = Vector3(0, 4.0, 0)
	glow.light_color = Color(0.45, 0.95, 0.8)
	glow.light_energy = 1.4
	glow.omni_range = 24.0
	glow.shadow_enabled = false
	add_child(glow)


# --------------------------------------------------------------------------
# The queen and the fight
# --------------------------------------------------------------------------
func _spawn_queen() -> void:
	if queen and is_instance_valid(queen) and queen.state != Scuttlebug.S.DEAD:
		queen.queue_free()
	var nest := to_global(Vector3(NEST.x, 0.0, NEST.y))
	queen = BroodQueen.new().queen(nest)
	queen.name = "Queen_%d" % queen_gen
	queen.cave = self
	add_child(queen)
	queen.global_position = nest + Vector3.UP * 0.4
	queen.reset_physics_interpolation()
	_celebrated = false
	_dead_t = 0.0


func call_brood() -> void:
	brood.call_out()


func brood_alive() -> int:
	return brood.alive_count()


func inside(p: Vector3) -> bool:
	var l := to_local(p)
	return Vector2(l.x, l.z).length() < R_IN - 0.5 and l.y > -1.0 and l.y < H_IN


func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and not _arrived and me.global_position.distance_to(global_position) < 40.0:
		_arrived = true
		get_tree().call_group("hud", "show_banner", "The Brood Cave", "Something big nests in the dark", true)
	var alive := queen != null and is_instance_valid(queen) and queen.state != Scuttlebug.S.DEAD
	_boss_hud(me, alive)
	if queen != null and is_instance_valid(queen) and not alive and not _celebrated:
		_celebrated = true
		_victory(me)
	if Net.is_client():
		return
	if alive:
		var any_in := false
		for p in Net.all_players():
			if inside((p as Node3D).global_position) and p.has_method("is_standing") and p.is_standing():
				any_in = true
		if any_in:
			_empty_t = 0.0
			queen.wake()
		elif queen.in_combat():
			_empty_t += delta
			if _empty_t > RESET_AFTER:
				_empty_t = 0.0
				queen.reset_fight()
	else:
		_dead_t += delta
		if _dead_t > RESPAWN:
			for p in Net.all_players():
				if (p as Node3D).global_position.distance_to(global_position) < 70.0:
					return
			queen_gen += 1
			_spawn_queen()
			Net.spawned(self, net_gen())


func _boss_hud(me: Node3D, alive: bool) -> void:
	var show := me != null and alive and queen.in_combat() and me.global_position.distance_to(global_position) < R_OUT + 10.0
	if show:
		get_tree().call_group("hud", "show_boss", "The Brood Queen", queen.health_frac(), queen.phase)
		_boss_ui = true
	elif _boss_ui:
		_boss_ui = false
		get_tree().call_group("hud", "hide_boss")


## Beaten: banner, fanfare, and her hoard on the nest (once per character).
func _victory(me: Node3D) -> void:
	if me and me.global_position.distance_to(global_position) < 60.0:
		get_tree().call_group("hud", "show_banner", "The Brood Queen is slain!", "Her hoard lies in the nest", true)
		var music := get_node_or_null("/root/Music")
		if music:
			music.victory()
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.get("opened") != null and (gm.opened as Dictionary).has(HOARD_ID):
		return
	if get_node_or_null("Hoard"):
		return
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var items: Array[ItemStack] = []
	for e in [[ItemDB.tiered("queens_fang", 3), 1], [ItemDB.get_item("gold"), 60], [ItemDB.get_item("treasure"), 6], [ItemDB.get_item("rum"), 2],
			[Gear.make("accessory", "pauldron", {"pauldron": true}, "Chitin Pauldron", 3), 1]]:
		var st := ItemStack.new()
		st.item = e[0]
		st.quantity = e[1]
		items.append(st)
	bag.setup(items)
	bag.save_id = HOARD_ID
	bag.name = "Hoard"
	add_child(bag)
	bag.position = Vector3(NEST.x, 0.0, NEST.y)
	var cm := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	cm.mesh = Props.treasure_chest_mesh()
	cm.position = Vector3.ZERO
	cm.scale = Vector3.ONE * 1.4
	FX.sparkle(bag.global_position + Vector3(0, 0.8, 0), 24, Color(0.7, 1.0, 0.45))


func net_gen():
	return queen_gen


func net_set_gen(g) -> void:
	if int(g) == queen_gen:
		return
	queen_gen = int(g)
	_spawn_queen()
