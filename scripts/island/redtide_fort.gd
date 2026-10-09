extends Node3D
class_name RedtideFort
## Redtide Rock: a sea stack north of Brinehollow with a palisade fort on
## top - Captain Morrow "Red Tide"'s hideout. A jetty to tie up at, a stone
## stair cut into a rubble spur curling up the cliff, a gate with guards, and
## the captain himself waiting in front of his tent; sea stacks round the
## rock and crags rearing up behind the arena. Pirate ships patrol these
## waters (see EnemyFleet).
##
## The fight (host decides, everyone sees): step inside the walls and Morrow
## comes for you. Phase two calls his crew over the walls. If every captain
## leaves (or falls), he heals and waits again. Beat him: a banner, a victory
## fanfare, and his hoard in front of the tent (each captain's own chest,
## once per character). He's back after a while for a rematch (gold only).
##
## Co-op: a spawner (net_spawner) - [boss wave, crew wave] names the nodes the
## same on every machine.

const TOP := 6.0
const WALL_R := 17.5
const WALL_H := 3.0
const GATE_HALF := 3.2
const ARENA := Vector3(0, TOP, -2.0)
const BOSS_POST := Vector3(0, TOP, -7.5)
const RESET_RANGE := 42.0
const RESPAWN := 600.0
const HOARD_ID := "redtide_hoard"

var boss: PirateBoss
var boss_gen: int = 0
var crew_gen: int = 0
var crew: Array = []
var guards: GruntCamp
var _empty_t: float = 0.0
var _dead_t: float = 0.0
var _celebrated: bool = false
var _arrived: bool = false
var _boss_ui: bool = false


func _ready() -> void:
	add_to_group("net_spawner")
	add_to_group("forts")
	_build()
	_spawn_boss.call_deferred()


# ==========================================================================
# The rock and the fort
# ==========================================================================
func _build() -> void:
	_noise.seed = 4242
	_noise.frequency = 0.09
	_wave.seed = 4243
	_wave.frequency = 0.35
	_rock_m = PSXMat.lit("rock", Color(0.78, 0.74, 0.7), {"affine": 0.5})
	_top_m = PSXMat.lit("dirt", Color(0.9, 0.85, 0.78), {"affine": 0.5})
	_grass_m = PSXMat.lit("grass", Color(0.78, 0.82, 0.62), {"affine": 0.5})
	var body := StaticBody3D.new()
	body.name = "Rock"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var mb := MeshBuilder.new()
	_build_stack(mb)
	_build_spur(mb)
	var rock_mi := mb.to_instance("RockMesh")
	body.add_child(rock_mi)
	var cs := CollisionShape3D.new()
	cs.shape = rock_mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	# a few boulders at the waterline (clear of the stair and the jetty)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in range(9):
		var a := TAU * (k + 0.37) / 9.0
		if a > 1.0 and a < 2.05:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = Props.rock_mesh(900 + k, rng.randf_range(1.6, 3.2))
		mi.position = Vector3(cos(a) * (_stack_r(a, 0.0) + 0.8), rng.randf_range(-0.6, 0.6), sin(a) * (_stack_r(a, 0.0) + 0.8))
		add_child(mi)
	# the jetty (south, toward Brinehollow) and the stone stair up to the gate
	var jetty := Props.dock(16.0, 3.6, 1.7, -8.0)
	jetty.position = Vector3(0, 0, 34.0)
	add_child(jetty)
	_build_path()
	_build_crags()
	_build_palisade()
	_build_camp()


# --------------------------------------------------------------------------
# The rock: a faceted stack, buttresses down its cliffs, grass on its ledges
# --------------------------------------------------------------------------
## The cliff's mean radius by height (fort-local y), before noise and buttresses.
const PROFILE := [[-14.0, 31.0], [-8.0, 28.0], [-3.0, 25.4], [0.0, 23.9], [1.5, 23.1], [3.0, 22.4], [4.3, 21.8], [5.3, 21.2], [TOP, 20.6]]
const RINGS_Y := [-14.0, -9.0, -5.0, -2.0, 0.0, 1.2, 2.4, 3.4, 4.3, 5.2, TOP]
const BEARINGS := 56
## Rock buttresses bulging out of the cliff: [bearing, how far out (m)].
const BUTTRESS := [[-0.4, 3.2], [-1.3, 4.0], [-2.2, 2.6], [2.6, 3.4], [0.45, 2.4], [3.4, 2.8]]
## Where the stair runs up the east side (bearing, half-width): the cliff is kept clear there.
const PATH_BEARING := 1.41
const PATH_HALF := 0.3

var _noise := FastNoiseLite.new()
var _wave := FastNoiseLite.new()
var _rock_m: Material
var _top_m: Material
var _grass_m: Material


func _round(a: float, k: int) -> float:
	return _wave.get_noise_2d(cos(a) * 3.0 + k * 50.0, sin(a) * 3.0)


func _peak(a: float, at: float, width: float) -> float:
	return exp(-pow(angle_difference(a, at) / width, 2.0))


## 1 on the stair's side of the rock, 0 elsewhere.
func _path_mask(a: float) -> float:
	return 1.0 - smoothstep(PATH_HALF, PATH_HALF + 0.25, absf(angle_difference(a, PATH_BEARING)))


## The cliff's radius at bearing `a`, height `y`.
func _stack_r(a: float, y: float) -> float:
	if y >= TOP - 0.01:
		return maxf(20.6 + 0.9 * _round(a, 1), 20.1)
	var base := float(PROFILE[0][1])
	for i in range(PROFILE.size() - 1):
		if y <= float(PROFILE[i + 1][0]):
			var t := (y - float(PROFILE[i][0])) / (float(PROFILE[i + 1][0]) - float(PROFILE[i][0]))
			base = lerpf(float(PROFILE[i][1]), float(PROFILE[i + 1][1]), t)
			break
	var n := 2.0 * _round(a, 0) + 1.2 * _noise.get_noise_3d(cos(a) * 25.0, y * 1.3, sin(a) * 25.0)
	for b in BUTTRESS:
		n += float(b[1]) * _peak(a, float(b[0]), 0.16) * clampf((TOP - y) / 8.0, 0.0, 1.0)
	var m := _path_mask(a)
	return base + n * (1.0 - 0.8 * m) - 1.2 * m * clampf((TOP - 0.5 - y) / 3.0, 0.0, 1.0)


func _stack_pick(n: Vector3, m: Vector3) -> Material:
	return _grass_m if n.y > 0.82 and m.y < TOP - 0.3 and m.y > 0.6 else _rock_m


func _build_stack(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4244
	var pts: Array = []
	for y in RINGS_Y:
		var row: Array = []
		for k in range(BEARINGS):
			var a := TAU * k / BEARINGS
			var r := _stack_r(a, float(y))
			var jy := 0.0 if (y == RINGS_Y[0] or y >= TOP) else rng.randf_range(-0.3, 0.3)
			row.append(Vector3(cos(a) * r, float(y) + jy, sin(a) * r))
		pts.append(row)
	for i in range(pts.size() - 1):
		for k in range(BEARINGS):
			var k2 := (k + 1) % BEARINGS
			var a := TAU * (k + 0.5) / BEARINGS
			_cell(mb, pts[i][k], pts[i][k2], pts[i + 1][k2], pts[i + 1][k], Vector3(cos(a), 0.0, sin(a)), _stack_pick, (i + k) % 2 == 0)
	# the flat top (the fort stands on it): an inner disc and the ring out to the rim
	var top_row: Array = pts[pts.size() - 1]
	var c := Vector3(0, TOP, 0)
	for k in range(BEARINGS):
		var k2 := (k + 1) % BEARINGS
		var a0 := TAU * k / BEARINGS
		var a1 := TAU * k2 / BEARINGS
		var i0 := Vector3(cos(a0) * 11.0, TOP, sin(a0) * 11.0)
		var i1 := Vector3(cos(a1) * 11.0, TOP, sin(a1) * 11.0)
		var r0: Vector3 = top_row[k]
		var r1: Vector3 = top_row[k2]
		mb.add_tri(_top_m, c, i1, i0, Vector3.UP, Vector3.UP, Vector3.UP, Vector2(c.x, c.z) * 0.25, Vector2(i1.x, i1.z) * 0.25, Vector2(i0.x, i0.z) * 0.25, Color.WHITE, Vector3.UP)
		mb.add_quad(_top_m, i0, i1, r1, r0, Vector2(i0.x, i0.z) * 0.25, Vector2(i1.x, i1.z) * 0.25, Vector2(r1.x, r1.z) * 0.25, Vector2(r0.x, r0.z) * 0.25, Color(0.92, 0.92, 0.92), Vector3.UP)


## Texture coordinates projected along the facet's main axis, offset per facet
## (the rock texture's cracks don't line up into a grid).
func _tuv(p: Vector3, n: Vector3, off: Vector2) -> Vector2:
	var an := n.abs()
	if an.y >= an.x and an.y >= an.z:
		return Vector2(p.x, p.z) * 0.3 + off
	if an.x >= an.z:
		return Vector2(p.z, -p.y) * 0.3 + off
	return Vector2(p.x, -p.y) * 0.3 + off


## One flat facet facing the `hint` side, its material from `pick`, shaded in strata.
func _facet(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3, hint: Vector3, pick: Callable) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-8:
		return
	n = n.normalized()
	if n.dot(hint) < 0.0:
		n = -n
	var m := (a + b + c) / 3.0
	var band := 0.5 + 0.5 * sin(m.y * 1.7 + 2.0 * _noise.get_noise_2d(m.x * 3.0, m.z * 3.0))
	var col := Color(1, 1, 1) * (0.74 + 0.26 * band)
	col.a = 1.0
	var off := Vector2(fposmod(m.x * 7.31 + m.z * 3.17, 1.0), fposmod(m.y * 5.13 + m.x * 2.71, 1.0))
	mb.add_tri(pick.call(n, m), a, b, c, n, n, n, _tuv(a, n, off), _tuv(b, n, off), _tuv(c, n, off), col, n)


func _cell(mb: MeshBuilder, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, pick: Callable, flip: bool) -> void:
	if flip:
		_facet(mb, a, b, c, hint, pick)
		_facet(mb, a, c, d, hint, pick)
	else:
		_facet(mb, a, b, d, hint, pick)
		_facet(mb, b, c, d, hint, pick)


# --------------------------------------------------------------------------
# The way up: stone steps on a rubble spur from the jetty round to the gate
# --------------------------------------------------------------------------
## The stair's line (fort-local, feet height): off the jetty's head, out east
## round a buttress and back in to the gate.
const PATH := [Vector3(0.0, 1.72, 33.9), Vector3(6.2, 2.9, 29.6), Vector3(8.2, 4.2, 24.8), Vector3(4.6, TOP - 0.03, 21.6), Vector3(0.0, TOP, 19.2)]
const PATH_W := 3.0
const STEP_RUN := 0.95


## The stair's line as a smooth curve through PATH (sharp corners left a lip
## on the inside of each bend), every ~0.25 m: [points], [distance along].
var _curve: Array = []
var _curve_s: PackedFloat32Array


func _curve_pts() -> Array:
	if not _curve.is_empty():
		return _curve
	var ctl: Array = [PATH[0]] + PATH + [PATH[PATH.size() - 1]]
	for i in range(1, ctl.size() - 2):
		var p0: Vector3 = ctl[i - 1]
		var p1: Vector3 = ctl[i]
		var p2: Vector3 = ctl[i + 1]
		var p3: Vector3 = ctl[i + 2]
		var n := int(p1.distance_to(p2) / 0.25) + 1
		for k in range(n):
			var t := float(k) / n
			# Catmull-Rom
			var t2 := t * t
			var t3 := t2 * t
			_curve.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	_curve.append(PATH[PATH.size() - 1])
	_curve_s = PackedFloat32Array([0.0])
	for i in range(1, _curve.size()):
		_curve_s.append(_curve_s[i - 1] + (_curve[i] as Vector3).distance_to(_curve[i - 1]))
	return _curve


func _path_len() -> float:
	_curve_pts()
	return _curve_s[_curve_s.size() - 1]


## [point, flat direction] at `s` metres along the stair.
func _path_at(s: float) -> Array:
	var pts := _curve_pts()
	var i := clampi(_curve_s.bsearch(s) - 1, 0, pts.size() - 2)
	var a: Vector3 = pts[i]
	var b: Vector3 = pts[i + 1]
	var t := clampf((s - _curve_s[i]) / maxf(_curve_s[i + 1] - _curve_s[i], 0.0001), 0.0, 1.0)
	var d := b - a
	d.y = 0.0
	return [a.lerp(b, t), d.normalized()]


## Flat distance from `p` to the stair's line.
func _path_dist(p: Vector3) -> float:
	var pts := _curve_pts()
	var best := INF
	var q := Vector2(p.x, p.z)
	for i in range(pts.size() - 1):
		var a := Vector2((pts[i] as Vector3).x, (pts[i] as Vector3).z)
		var b := Vector2((pts[i + 1] as Vector3).x, (pts[i + 1] as Vector3).z)
		best = minf(best, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
	return best


## The rubble mass the steps are cut into, from the stair's edges down into the sea.
func _build_spur(mb: MeshBuilder) -> void:
	var L := _path_len()
	var n := int(L / 1.2) + 1
	var rows: Array = []
	for i in range(n + 1):
		var at := _path_at(L * i / n)
		var c: Vector3 = at[0]
		var side := (at[1] as Vector3).cross(Vector3.UP).normalized()
		var j := _noise.get_noise_2d(c.x * 2.0, c.z * 2.0)
		var top_y := c.y - 0.42
		rows.append([
			c - side * (PATH_W * 0.5 + 3.4 + 1.2 * j) + Vector3(0, -6.0 - c.y, 0),
			c - side * (PATH_W * 0.5 + 0.9 + 0.3 * j) + Vector3(0, top_y - c.y - 0.9, 0),
			c - side * (PATH_W * 0.5 + 0.2) + Vector3(0, top_y - c.y, 0),
			c + side * (PATH_W * 0.5 + 0.2) + Vector3(0, top_y - c.y, 0),
			c + side * (PATH_W * 0.5 + 0.9 - 0.3 * j) + Vector3(0, top_y - c.y - 0.9, 0),
			c + side * (PATH_W * 0.5 + 3.4 - 1.2 * j) + Vector3(0, -6.0 - c.y, 0),
		])
	for i in range(rows.size() - 1):
		var r0: Array = rows[i]
		var r1: Array = rows[i + 1]
		for k in range(r0.size() - 1):
			var mid: Vector3 = ((r0[k] as Vector3) + (r0[k + 1] as Vector3)) * 0.5
			var c0: Vector3 = _path_at(_path_len() * i / (rows.size() - 1))[0]
			var hint := (mid - c0 + Vector3(0, 0.5, 0)).normalized()
			_cell(mb, r0[k], r0[k + 1], r1[k + 1], r1[k], hint, _stack_pick, (i + k) % 2 == 0)
	# the foot of the spur by the jetty: closed off
	var e: Array = rows[0]
	var back := -(_path_at(0.0)[1] as Vector3)
	for k in range(1, e.size() - 1):
		_facet(mb, e[0], e[k], e[k + 1], back, _stack_pick)


## The stone steps (flagstones, two to a step), boulders along the edges, and
## a smooth ramp underneath to walk on (no step-up on stairs).
func _build_path() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4245
	var stone := PSXMat.lit("rock", Color(0.86, 0.82, 0.76), {"affine": 0.5})
	var mb := MeshBuilder.new()
	var L := _path_len()
	var steps := int(L / STEP_RUN)
	for i in range(steps):
		var at := _path_at((i + 0.5) * L / steps)
		var c: Vector3 = at[0]
		var d: Vector3 = at[1]
		var side := d.cross(Vector3.UP).normalized()
		var yaw := atan2(-d.x, -d.z) + rng.randf_range(-0.05, 0.05)
		var w1 := PATH_W * rng.randf_range(0.38, 0.62)
		for half in [[-(PATH_W - w1) * 0.5, w1], [w1 * 0.5, PATH_W - w1]]:
			var w: float = half[1] - 0.05
			var x: float = half[0]
			var top := c.y + rng.randf_range(-0.03, 0.03)
			var shade := Color(1, 1, 1) * rng.randf_range(0.82, 1.0)
			mb.add_box(stone, Transform3D(Basis(Vector3.UP, yaw), c + side * x + Vector3(0, top - c.y - 0.2, 0)), Vector3(w, 0.4, L / steps + 0.08), 0.5, shade)
	# boulders along both edges, bigger ones at the turns
	var body := StaticBody3D.new()
	body.name = "Stair"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var s := 0.6
	while s < L - 1.5:
		var at := _path_at(s)
		var c: Vector3 = at[0]
		var side := (at[1] as Vector3).cross(Vector3.UP).normalized()
		for sgn in [-1.0, 1.0]:
			if rng.randf() < 0.3:
				continue
			var r := rng.randf_range(0.3, 0.75)
			var p: Vector3 = c + side * float(sgn) * (PATH_W * 0.5 + 0.25 + r * 0.6) + Vector3(0, -0.35, 0)
			# (on the inside of a bend it would sit on the next flight)
			if _path_dist(p) < PATH_W * 0.5 + r * 0.85 + 0.05:
				continue
			mb.add_blob(_rock_m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(r * 1.2, r, r), rng, 0.25, 3, 6, 0.5, Color(1, 1, 1) * rng.randf_range(0.75, 0.95), 0.0)
			if r > 0.55:
				var bc := CollisionShape3D.new()
				var sp := SphereShape3D.new()
				sp.radius = r * 0.85
				bc.shape = sp
				bc.position = p + Vector3(0, r * 0.3, 0)
				body.add_child(bc)
		s += rng.randf_range(1.2, 2.0)
	body.add_child(mb.to_instance("StairMesh"))
	# what you walk on: one smooth ribbon along the stair's line (steps you
	# can't step up; a smooth slope under them)
	var faces := PackedVector3Array()
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var n := int(L / 0.5) + 1
	for i in range(n + 1):
		var at := _path_at(L * i / n)
		var c: Vector3 = at[0]
		var side := (at[1] as Vector3).cross(Vector3.UP).normalized() * (PATH_W * 0.5 + 0.2)
		var l := c - side
		var r := c + side
		if i > 0:
			faces.append_array([prev_l, prev_r, r, prev_l, r, l])
		prev_l = l
		prev_r = r
	# (and past the ends: onto the jetty's planks and over the rim)
	var first := _path_at(0.0)
	var last := _path_at(L)
	for e in [[first[0], -(first[1] as Vector3)], [last[0], last[1]]]:
		var c: Vector3 = e[0]
		var d: Vector3 = e[1]
		var side := d.cross(Vector3.UP).normalized() * (PATH_W * 0.5 + 0.2)
		faces.append_array([c - side, c + side, c + side + d * 0.8, c - side, c + side + d * 0.8, c - side + d * 0.8])
	var walk := ConcavePolygonShape3D.new()
	walk.set_faces(faces)
	walk.backface_collision = true
	var wc := CollisionShape3D.new()
	wc.shape = walk
	body.add_child(wc)


# --------------------------------------------------------------------------
# Crags: sea stacks round the rock, rocks rearing up behind the arena
# --------------------------------------------------------------------------
## [bearing, distance, base radius, height above the sea, base y]
const CRAGS := [
	[-0.35, 34.0, 3.2, 12.0, -6.0], [-1.15, 38.5, 4.2, 16.0, -6.0], [-1.8, 31.5, 2.6, 8.0, -6.0],
	[-2.5, 36.0, 3.6, 13.0, -6.0], [2.75, 33.5, 3.0, 9.5, -6.0], [0.4, 38.0, 2.4, 7.0, -6.0],
	# behind the tent, out past the palisade, bedded in the rim
	[-1.62, 21.8, 2.3, TOP + 8.5, TOP - 3.0], [-1.95, 21.2, 1.7, TOP + 5.5, TOP - 3.0],
	[-1.28, 21.0, 1.5, TOP + 4.5, TOP - 3.0], [-2.35, 21.4, 1.9, TOP + 6.5, TOP - 3.0],
]


func _build_crags() -> void:
	var body := StaticBody3D.new()
	body.name = "Crags"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4246
	for cg in CRAGS:
		var a: float = cg[0]
		var at := Vector3(cos(a) * float(cg[1]), float(cg[4]), sin(a) * float(cg[1]))
		var pts := _spire(mb, at, float(cg[2]), float(cg[3]) - float(cg[4]), rng)
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		cs.shape = shape
		body.add_child(cs)
	body.add_child(mb.to_instance("CragMesh"))


## A jagged spire from `base` up `h` m: a faceted, leaning, tapering column.
## Returns its points (for a convex collider).
func _spire(mb: MeshBuilder, base: Vector3, r0: float, h: float, rng: RandomNumberGenerator) -> PackedVector3Array:
	var sides := 7
	var ts := [0.0, 0.3, 0.55, 0.75, 0.9]
	var lean := Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
	var rows: Array = []
	var all := PackedVector3Array()
	for t in ts:
		var row: Array = []
		var r := r0 * (1.0 - 0.78 * pow(float(t), 1.15))
		for k in range(sides):
			var a := TAU * (k + rng.randf_range(-0.2, 0.2)) / sides
			var rr := r * rng.randf_range(0.75, 1.2)
			var p := base + Vector3(cos(a) * rr, h * float(t) + rng.randf_range(-0.3, 0.3), sin(a) * rr) + lean * h * float(t)
			row.append(p)
			all.append(p)
		rows.append(row)
	var tip := base + Vector3(rng.randf_range(-0.3, 0.3), h, rng.randf_range(-0.3, 0.3)) + lean * h
	all.append(tip)
	for i in range(rows.size() - 1):
		for k in range(sides):
			var k2 := (k + 1) % sides
			var a: Vector3 = rows[i][k]
			var hint := Vector3(a.x - base.x, 0.0, a.z - base.z).normalized()
			_cell(mb, rows[i][k], rows[i][k2], rows[i + 1][k2], rows[i + 1][k], hint, _stack_pick, (i + k) % 2 == 0)
	var last: Array = rows[rows.size() - 1]
	for k in range(sides):
		var a: Vector3 = last[k]
		_facet(mb, a, last[(k + 1) % sides], tip, Vector3(a.x - base.x, 0.4, a.z - base.z).normalized(), _stack_pick)
	return all


func _build_palisade() -> void:
	var body := StaticBody3D.new()
	body.name = "Palisade"
	body.collision_layer = 1
	add_child(body)
	var logs := PSXMat.lit("bark", Color(0.85, 0.75, 0.62))
	var mb := MeshBuilder.new()
	var circ := TAU * WALL_R
	var count := int(circ / 0.55)
	var gate_a := atan2(GATE_HALF, WALL_R)
	for k in range(count):
		var a := TAU * k / count
		# gate at +Z (a = PI/2)
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < gate_a:
			continue
		var h := WALL_H + (0.25 if k % 3 == 0 else 0.0)
		var p := Vector3(cos(a) * WALL_R, TOP - 0.4, sin(a) * WALL_R)
		mb.add_cylinder(logs, Transform3D(Basis(), p), 0.26, 0.24, h + 0.4, 5, 0.8)
		mb.add_cone(logs, Transform3D(Basis(), p + Vector3(0, h + 0.4, 0)), 0.24, 0.35, 5)
	# gate posts and a lintel with a skull board
	for sx in [-1.0, 1.0]:
		var gp := Vector3(sx * GATE_HALF, TOP - 0.4, sqrt(WALL_R * WALL_R - GATE_HALF * GATE_HALF))
		mb.add_cylinder(logs, Transform3D(Basis(), gp), 0.34, 0.32, WALL_H + 1.6, 6, 0.8)
	var gz := sqrt(WALL_R * WALL_R - GATE_HALF * GATE_HALF)
	mb.add_box(PSXMat.lit("planks_dark"), Transform3D(Basis(), Vector3(0, TOP + WALL_H + 0.9, gz)), Vector3(GATE_HALF * 2.0 + 0.8, 0.35, 0.4), 1.0)
	body.add_child(mb.to_instance("Logs"))
	var sk := MeshBuilder.new()
	sk.add_card(HullBuilder.jolly_material(), Transform3D(Basis.IDENTITY, Vector3(0, TOP + WALL_H + 1.6, gz + 0.22)), 1.4, 1.4)
	sk.add_card(HullBuilder.jolly_material(), Transform3D(Basis(Vector3.UP, PI), Vector3(0, TOP + WALL_H + 1.6, gz - 0.22)), 1.4, 1.4)
	add_child(sk.to_instance("GateSkull"))
	# wall collision: straight segments around the ring
	var segs := 36
	for k in range(segs):
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var mid := (a0 + a1) * 0.5
		if absf(wrapf(mid - PI * 0.5, -PI, PI)) < gate_a + 0.02:
			continue
		var p0 := Vector3(cos(a0), 0, sin(a0)) * WALL_R
		var p1 := Vector3(cos(a1), 0, sin(a1)) * WALL_R
		var c := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.6, WALL_H + 1.0, p0.distance_to(p1) + 0.3)
		c.shape = b
		c.transform = Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), (p0 + p1) * 0.5 + Vector3(0, TOP + (WALL_H + 1.0) * 0.5 - 0.4, 0))
		body.add_child(c)


func _place(n: Node3D, p: Vector3, yaw: float = 0.0) -> Node3D:
	add_child(n)
	n.position = p
	n.rotation.y = yaw
	return n


func _build_camp() -> void:
	# Morrow's big tent at the north end, his chair in front of it
	var tent := MeshBuilder.new()
	var canvas := PSXMat.lit("canvas", Color(0.62, 0.22, 0.18), {"affine": 0.6})
	var pole := PSXMat.lit("bark")
	var tp := Vector3(0, TOP, -12.5)
	tent.add_gable_roof(canvas, Transform3D(Basis(), tp + Vector3(0, 0.0, 0)), 6.0, 5.0, 3.4)
	tent.add_cylinder(pole, Transform3D(Basis(), tp + Vector3(0, 0, 2.5)), 0.1, 0.08, 3.6, 5, 1.0)
	tent.add_cylinder(pole, Transform3D(Basis(), tp + Vector3(0, 0, -2.5)), 0.1, 0.08, 3.6, 5, 1.0)
	add_child(tent.to_instance("Tent"))
	var tent_body := StaticBody3D.new()
	tent_body.collision_layer = 1
	tent_body.position = tp + Vector3(0, 1.4, 0)
	var tcs := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(5.2, 2.8, 4.6)
	tcs.shape = tb
	tent_body.add_child(tcs)
	add_child(tent_body)
	var chair := MeshBuilder.new()
	var red := PSXMat.lit("cloth_red", Color(0.8, 0.3, 0.25))
	var dk := PSXMat.lit("planks_dark")
	var cp := Vector3(0, TOP, -9.3)
	chair.add_box(dk, Transform3D(Basis(), cp + Vector3(0, 0.25, 0)), Vector3(1.2, 0.5, 1.0), 1.0)
	chair.add_box(red, Transform3D(Basis(), cp + Vector3(0, 0.53, 0.05)), Vector3(1.0, 0.08, 0.8), 1.0)
	chair.add_box(dk, Transform3D(Basis(), cp + Vector3(0, 1.2, -0.45)), Vector3(1.2, 1.9, 0.14), 1.0)
	chair.add_box(red, Transform3D(Basis(), cp + Vector3(0, 1.15, -0.37)), Vector3(0.9, 1.4, 0.04), 1.0)
	for sx in [-0.6, 0.6]:
		chair.add_box(dk, Transform3D(Basis(), cp + Vector3(sx, 0.75, 0.0)), Vector3(0.14, 0.5, 0.9), 1.0)
	add_child(chair.to_instance("Chair"))
	# braziers (fire you can see from the sea), lanterns, the crew flag
	for bp in [Vector3(-4.5, TOP, -9.5), Vector3(4.5, TOP, -9.5), Vector3(-6.5, TOP, 13.5), Vector3(6.5, TOP, 13.5)]:
		var br := MeshBuilder.new()
		br.add_cylinder(PSXMat.lit("metal", Color(0.3, 0.28, 0.26)), Transform3D(Basis(), bp), 0.12, 0.1, 1.3, 5, 1.0)
		br.add_cylinder(PSXMat.lit("metal", Color(0.3, 0.28, 0.26)), Transform3D(Basis(), bp + Vector3(0, 1.3, 0)), 0.32, 0.5, 0.3, 6, 1.0)
		add_child(br.to_instance("Brazier"))
		var fire := Node3D.new()
		add_child(fire)
		fire.position = bp + Vector3(0, 1.65, 0)
		FX.flame_emitter(fire, 0.3, 14, 0.55, 0.6)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.3)
		light.light_energy = 1.4
		light.omni_range = 7.0
		fire.add_child(light)
	var flag := MeshBuilder.new()
	var fp := Vector3(9.5, TOP, -11.0)
	flag.add_cylinder(pole, Transform3D(Basis(), fp), 0.1, 0.07, 9.0, 5, 1.0)
	var cloth := PSXMat.lit("cloth_red", Color(0.25, 0.22, 0.22))
	flag.add_card(cloth, Transform3D(Basis.IDENTITY, fp + Vector3(1.1, 8.2, 0)), 2.2, 1.4, Rect2(0, 0, 0.5, 0.5))
	add_child(flag.to_instance("FlagPole"))
	var fj := MeshBuilder.new()
	fj.add_card(HullBuilder.jolly_material(), Transform3D(Basis.IDENTITY, fp + Vector3(1.1, 8.2, 0.02)), 1.3, 1.2)
	fj.add_card(HullBuilder.jolly_material(), Transform3D(Basis(Vector3.UP, PI), fp + Vector3(1.1, 8.2, -0.02)), 1.3, 1.2)
	add_child(fj.to_instance("FlagSkull"))
	# stores along the walls
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in range(10):
		var a := PI * 0.5 + PI * 0.25 + (PI * 1.5) * k / 9.0
		var p := Vector3(cos(a) * (WALL_R - 1.4), TOP, sin(a) * (WALL_R - 1.4))
		var pr: Node3D = Props.barrel() if k % 3 != 0 else Props.crate(rng.randf_range(0.7, 1.0))
		_place(pr, p, rng.randf() * TAU)
	_place(Props.weapon_rack(), Vector3(-8.0, TOP, -4.0), PI * 0.5)
	_place(Props.weapon_rack(), Vector3(8.0, TOP, -4.0), -PI * 0.5)
	# the gate guards
	guards = GruntCamp.new()
	guards.name = "Guards"
	guards.respawn_time = 180.0
	add_child(guards)
	# (yaws are world-space: facing out of the gate is the fort's +Z)
	var out_yaw := global_rotation.y + PI
	guards.add_grunt({"post": Vector3(-2.4, TOP, 14.0), "yaw": out_yaw, "mode": "stand", "seed": 301})
	guards.add_grunt({"post": Vector3(2.4, TOP, 14.0), "yaw": out_yaw, "mode": "stand", "seed": 302})
	guards.add_grunt({"post": Vector3(-9.0, TOP, -6.0), "yaw": out_yaw - 0.6, "mode": "stand", "role": "rifle", "seed": 303})


# ==========================================================================
# The captain
# ==========================================================================
func _spawn_boss() -> void:
	if boss and is_instance_valid(boss) and boss.state != PirateGrunt.S.DEAD:
		boss.queue_free()
	boss = PirateBoss.new()
	boss.name = "Morrow_%d" % boss_gen
	# (facing the gate)
	boss.setup({"post": to_global(BOSS_POST), "yaw": global_rotation.y + PI, "mode": "stand", "seed": 999, "look": PirateBoss.morrow_look()})
	boss.arena = self
	boss.camp = null
	add_child(boss)
	boss.global_position = to_global(BOSS_POST) + Vector3.UP * 0.2
	boss.reset_physics_interpolation()
	_celebrated = false
	_dead_t = 0.0


## Phase two: over the walls they come.
func call_crew() -> void:
	if Net.is_client():
		return
	# the last call's crew still standing (the fight was reset) rejoin instead
	crew = crew.filter(func(g): return is_instance_valid(g) and g.state != PirateGrunt.S.DEAD)
	if not crew.is_empty():
		for g in crew:
			g.alert()
		return
	crew_gen += 1
	_spawn_crew(true)
	Net.spawned(self, net_gen())
	Net.fx("sfx", ["horn", to_global(ARENA), 2.0, 0.03, 1.1])


var _prebuilt_crew: int = -1
var _prebuilt_boss: int = -1


## The looks of wave `g`'s crew (as _spawn_crew seeds them).
func _crew_looks(g: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + g
	var out: Array = []
	for i in range(3 + clampi(Net.crew_size() - 2, 0, 2)):
		out.append(PirateGrunt.look_for({"seed": rng.randi()}))
	return out


func _spawn_crew(leap: bool) -> void:
	var n := 3 + clampi(Net.crew_size() - 2, 0, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 500 + crew_gen
	for i in range(n):
		var a := PI * 0.5 + PI * 0.4 + (PI * 1.2) * float(i) / maxf(n - 1, 1)
		var wall := Vector3(cos(a) * (WALL_R - 0.2), TOP + WALL_H + 0.3, sin(a) * (WALL_R - 0.2))
		var land := Vector3(cos(a) * 10.0, TOP + 0.1, sin(a) * 10.0)
		var g := PirateGrunt.new()
		g.name = "MC%d_%d" % [crew_gen, i]
		g.setup({"post": to_global(land), "yaw": 0.0, "mode": "stand", "role": "sword", "seed": rng.randi()})
		g.boarder = true
		add_child(g)
		g.global_position = to_global(wall)
		g.reset_physics_interpolation()
		crew.append(g)
		if leap and not Net.is_client():
			g.leap(to_global(land), 0.9 + 0.1 * i)


func net_gen():
	return [boss_gen, crew_gen]


func net_set_gen(g) -> void:
	var arr: Array = g
	if arr.size() < 2:
		return
	if int(arr[0]) != boss_gen:
		boss_gen = int(arr[0])
		_spawn_boss()
	if int(arr[1]) != crew_gen:
		crew_gen = int(arr[1])
		_spawn_crew(false)


func _process(delta: float) -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	var center := to_global(ARENA)
	if me and not _arrived and me.global_position.distance_to(global_position) < 75.0:
		_arrived = true
		get_tree().call_group("hud", "show_banner", "Redtide Rock", "Captain Morrow's hideout", true)
	_boss_hud(me)
	var alive: bool = boss != null and is_instance_valid(boss) and boss.state != PirateGrunt.S.DEAD
	if boss != null and is_instance_valid(boss) and not alive and not _celebrated:
		_celebrated = true
		_victory()
	if Net.is_client():
		return
	# step inside the walls and he comes for you
	if alive and boss.state == PirateGrunt.S.IDLE:
		for p in Net.all_players():
			var lp := to_local((p as Node3D).global_position)
			if Vector2(lp.x, lp.z).length() < WALL_R - 0.5 and lp.y > TOP - 1.0 and p.has_method("is_standing") and p.is_standing():
				boss.alert()
				break
	if alive and boss.in_combat():
		# the crew he'll call in phase two, built on a worker thread meanwhile
		if _prebuilt_crew != crew_gen + 1:
			_prebuilt_crew = crew_gen + 1
			Humanoid.prebuild(_crew_looks(crew_gen + 1))
		var near := false
		for p in Net.all_players():
			var pp := p as Node3D
			if pp.global_position.distance_to(center) < RESET_RANGE and p.has_method("is_standing") and p.is_standing():
				near = true
		_empty_t = 0.0 if near else _empty_t + delta
		if _empty_t > 5.0:
			_empty_t = 0.0
			boss.reset_fight()
	elif not alive:
		if _prebuilt_boss != boss_gen + 1:
			_prebuilt_boss = boss_gen + 1
			Humanoid.prebuild([PirateBoss.morrow_look()])
		_dead_t += delta
		if _dead_t > RESPAWN:
			for p in Net.all_players():
				if (p as Node3D).global_position.distance_to(center) < 70.0:
					return
			boss_gen += 1
			_spawn_boss()
			Net.spawned(self, net_gen())


func _boss_hud(me: Node3D) -> void:
	var show := me != null and boss != null and is_instance_valid(boss) and boss.state != PirateGrunt.S.DEAD \
		and boss.in_combat() and me.global_position.distance_to(to_global(ARENA)) < RESET_RANGE + 8.0
	if show:
		get_tree().call_group("hud", "show_boss", "Captain Morrow \"Red Tide\"", boss.health_frac(), boss.phase)
		_boss_ui = true
	elif _boss_ui:
		_boss_ui = false
		get_tree().call_group("hud", "hide_boss")


## Beaten: banner, fanfare, and his hoard for each captain (once per character).
func _victory() -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and me.global_position.distance_to(to_global(ARENA)) < 70.0:
		get_tree().call_group("hud", "show_banner", "Captain Morrow defeated!", "The Red Tide recedes", true)
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
	var add := func(it: ItemData, q: int) -> void:
		if it == null:
			return
		var st := ItemStack.new()
		st.item = it
		st.quantity = q
		items.append(st)
	add.call(load("res://resources/items/morrow_cutlass.tres"), 1)
	add.call(Gear.make("coat", "captain", {"coat": "captain", "coat_color": CharacterLook.CLOTH[13], "trim_color": CharacterLook.TRIM[0]}, "Red Tide Coat"), 1)
	add.call(load("res://resources/items/gold.tres"), 40)
	add.call(load("res://resources/items/treasure.tres"), 4)
	add.call(load("res://resources/items/rum.tres"), 2)
	bag.setup(items)
	bag.save_id = HOARD_ID
	bag.name = "Hoard"
	add_child(bag)
	bag.position = Vector3(0, TOP, -9.0 + 1.6)
	var cm := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if cm:
		cm.mesh = Props.treasure_chest_mesh()
		cm.position = Vector3.ZERO
		cm.scale = Vector3.ONE * 1.3
	FX.sparkle(bag.global_position + Vector3(0, 0.8, 0), 20, Color(1.0, 0.85, 0.4))
