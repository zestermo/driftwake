extends Node3D
class_name RedtideFort
## Redtide Rock: a mountain rising from the sea north of Brinehollow, with a
## palisade fort in the bowl of it - Captain Morrow "Red Tide"'s hideout. The
## mountain wraps round the fort, sheer inside and out, and opens only on a
## cove in front: a jetty to tie up at, a stone stair cut into a rubble spur
## curling up the cliff (the one way in), a gate with guards, and the captain
## himself waiting in front of his tent. Sea stacks round the foot. Pirate
## ships patrol these waters (see EnemyFleet).
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
	_build_massif()
	# a few boulders at the waterline in the cove (clear of the stair and the jetty)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in range(9):
		var a := TAU * (k + 0.37) / 9.0
		if (a > 1.0 and a < 2.05) or absf(angle_difference(a, OPEN_A)) > OPEN_HALF - 0.05:
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
# The mountain: a horseshoe massif round the arena, open only to the cove in
# front (+Z) where the jetty and the stair are. Sheer outside (from the sea)
# and inside (from the arena); its arms reach out into the sea either side of
# the cove.
# --------------------------------------------------------------------------
## The cove's bearing and half-width (rad): no mountain there.
const OPEN_A := PI * 0.5
const OPEN_HALF := 0.9
const MASSIF_COLS := 120
## The whole rock with its arms and sea stacks: clear sea round it (no-go for ships and the sea's features).
const REACH := 100.0
## The highest peaks: [bearing, metres, width].
const PEAKS := [[-1.75, 13.0, 0.16], [-1.15, 9.0, 0.12], [-2.55, 8.0, 0.13], [0.15, 6.0, 0.14], [2.95, 7.0, 0.12], [-0.55, 4.0, 0.1]]
## Buttresses out of the outer cliff (+) and gullies cut into it (-): [bearing, metres, width].
const SPURS := [[-0.25, 5.0, 0.07], [-1.45, 6.5, 0.08], [-2.2, 4.5, 0.07], [2.75, 5.0, 0.07], [0.45, 3.5, 0.06], [-2.95, 4.0, 0.06], [-0.85, -4.0, 0.05], [-2.0, -3.5, 0.05], [3.25, -3.0, 0.05]]

var _massif_m: Material
var _ledge_m: Material


## Radians from the nearer end of the massif (0 at the cove's sides).
func _from_cove(a: float) -> float:
	return absf(angle_difference(a, OPEN_A)) - OPEN_HALF


func _sum(list: Array, a: float) -> float:
	var s := 0.0
	for e in list:
		s += float(e[1]) * _peak(a, float(e[0]), float(e[2]))
	return s


## The massif's cross-section at bearing `a`: inner wall foot, crest, top width, crest height, outer ledge, foot.
func _col(a: float) -> Dictionary:
	var e := _from_cove(a)
	var arm := 1.0 - smoothstep(0.0, 0.75, e)
	var tip := 1.0 - smoothstep(0.0, 0.2, e)
	var back := _peak(a, -PI * 0.5, 1.25)
	var ridge := absf(_noise.get_noise_2d(cos(a) * 40.0, sin(a) * 40.0))
	var h := 22.0 + 26.0 * back + 6.0 * _round(a, 3) + 7.0 * ridge + _sum(PEAKS, a) - 7.0 * arm
	h = maxf(h, 15.0) * (1.0 - 0.3 * tip)
	var rin := 20.4 + 0.9 * _round(a, 4) + 0.5 * _noise.get_noise_2d(cos(a) * 70.0, sin(a) * 70.0) + 1.6 * (1.0 + _wave.get_noise_2d(cos(a) * 1.4 + 90.0, sin(a) * 1.4))
	var rc := rin + 7.0 + 2.5 * (_round(a, 5) + 1.0)
	var tw := (2.5 + 1.5 * (_round(a, 7) + 1.0) + 15.0 * arm) * (1.0 - 0.45 * tip)
	var hl := h * 0.5 + 3.0 * _round(a, 6)
	var x9 := rc + tw + 1.6
	var rout := x9 + 2.9 + (hl - 4.5) * 0.18 + _sum(SPURS, a) + 1.5 * _round(a, 8)
	var roll := _noise.get_noise_2d(cos(a) * 55.0 + 30.0, sin(a) * 55.0)
	return {"rin": rin, "rc": rc, "tw": tw, "h": h, "hl": hl, "x9": x9, "rout": maxf(rout, x9 + 2.0), "roll": roll}


## The flat point `r` out along bearing `a` of column `c`, the arms hooked in round the cove (more the further out).
func _bent(a: float, c: Dictionary, r: float) -> Vector3:
	var hook := -signf(angle_difference(OPEN_A, a)) * 0.24 * (1.0 - smoothstep(0.0, 0.5, _from_cove(a)))
	var aj := a + hook * smoothstep(float(c["rin"]) + 8.0, float(c["rout"]) + 6.0, r)
	return Vector3(cos(aj) * r, 0.0, sin(aj) * r)


## The massif's foot at the waterline (radius) at bearing `a`.
func _foot_r(a: float) -> float:
	return float(_col(a)["rout"])


## The profile from the buried inner foot (under the arena's rim, so no gap opens between) over the crest to the
## sea floor: [r, y] (solid below the line).
func _profile(c: Dictionary) -> Array:
	var rin: float = c["rin"]
	var rc: float = c["rc"]
	var tw: float = c["tw"]
	var h: float = c["h"]
	var hl: float = c["hl"]
	var x9: float = c["x9"]
	var rout: float = c["rout"]
	var wall := h - TOP
	var roll: float = c["roll"]
	return [
		[19.0, TOP - 1.5], [rin, TOP + 0.4], [rin + 0.5, TOP + wall * 0.2], [rin + 0.9, TOP + wall * 0.36],
		[rin + 2.1, TOP + wall * 0.38], [rin + 2.5, TOP + wall * 0.6], [rin + 3.7, TOP + wall * 0.64],
		[rc - 1.6, h - 2.5], [rc, h], [rc + tw * 0.5, h - 1.5 + roll * 2.5], [rc + tw, h - 3.0 - roll],
		[x9, hl + 2.0], [x9 + 1.4, hl], [rout - 1.0, 4.5], [rout - 1.8, 1.2], [rout, -1.0], [rout + 6.0, -14.0], [rout + 14.0, -36.0],
	]


func _massif_pick(n: Vector3, m: Vector3) -> Material:
	if n.y > 0.8 and _noise.get_noise_2d(m.x * 1.7, m.z * 1.7) > -0.15:
		_green.append([m, n])
		return _grass_m
	if n.y > 0.45 and m.y > TOP:
		return _ledge_m
	# the red strata the rock's named for, in wavy bands
	if m.y > 2.0 and sin(m.y * 0.42 + 2.6 * _noise.get_noise_2d(m.x * 0.6, m.z * 0.6)) > 0.72:
		return _band_m
	return _massif_m


## Grassy facets ([centre, normal]) as the massif's built: where its plants go.
var _green: Array = []
var _band_m: Material


## The ground's height at fort-local (x, z) (SkyBirds' flocks, islandshot's "~"): the arena's top inside the
## mountain, its crest over it, the sea outside.
func height_at(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var a := atan2(z, x)
	if _from_cove(a) < 0.0:
		return TOP if r < 22.0 else 0.0
	var c := _col(a)
	if r < float(c["rin"]):
		return TOP
	return float(c["h"]) if r < float(c["rout"]) else 0.0


func _build_massif() -> void:
	_massif_m = PSXMat.lit("rock", Color(0.74, 0.66, 0.62), {"affine": 0.5})
	_ledge_m = PSXMat.lit("rock", Color(0.7, 0.72, 0.58), {"affine": 0.5})
	_band_m = PSXMat.lit("rock", Color(0.8, 0.52, 0.44), {"affine": 0.5})
	var span := TAU - 2.0 * OPEN_HALF
	var a0 := OPEN_A + OPEN_HALF
	var cols: Array = []
	for k in range(MASSIF_COLS):
		var a := a0 + span * k / (MASSIF_COLS - 1)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var c := _col(a)
		var prof := _profile(c)
		var row: Array = []
		for j in range(prof.size()):
			var r: float = prof[j][0]
			var y: float = prof[j][1]
			# (the buried foot and the sea floor stay put; the faces between get a shove)
			if j > 0 and j < prof.size() - 1:
				r += 0.9 * _noise.get_noise_3d(dir.x * 60.0, y * 0.8, dir.z * 60.0)
				y += 0.35 * _noise.get_noise_3d(dir.x * 90.0 + 7.0, y * 1.7, dir.z * 90.0)
			row.append(_bent(a, c, r) + Vector3(0, y, 0))
		cols.append([a, prof, row])
	var mb := MeshBuilder.new()
	for k in range(cols.size() - 1):
		var c0: Array = cols[k]
		var c1: Array = cols[k + 1]
		var am := (float(c0[0]) + float(c1[0])) * 0.5
		var rad := Vector3(cos(am), 0.0, sin(am))
		var prof: Array = c0[1]
		for j in range(prof.size() - 1):
			var dr: float = float(prof[j + 1][0]) - float(prof[j][0])
			var dy: float = float(prof[j + 1][1]) - float(prof[j][1])
			var hint := (rad * -dy + Vector3.UP * dr).normalized()
			_cell(mb, c0[2][j], c1[2][j], c1[2][j + 1], c0[2][j + 1], hint, _massif_pick, (j + k) % 2 == 0)
	# the arms' ends, sheer onto the cove: the profile closed down to the sea floor
	for end in [[cols[0], 1.0], [cols[cols.size() - 1], -1.0]]:
		var a: float = end[0][0]
		var hint := Vector3(sin(a), 0.0, -cos(a)) * float(end[1])
		var row: Array = end[0][2]
		var prof: Array = end[0][1]
		var poly := PackedVector2Array()
		for j in range(prof.size()):
			poly.append(Vector2(float(prof[j][0]), float(prof[j][1])))
		poly.append(Vector2(float(prof[0][0]), -36.0))
		var pts: Array = row.duplicate()
		pts.append(Vector3((row[0] as Vector3).x, -36.0, (row[0] as Vector3).z))
		var tris := Geometry2D.triangulate_polygon(poly)
		for t in range(0, tris.size(), 3):
			_facet(mb, pts[tris[t]], pts[tris[t + 1]], pts[tris[t + 2]], hint, _massif_pick)
	var body := StaticBody3D.new()
	body.name = "Massif"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var mi := mb.to_instance("MassifMesh")
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	_dress_massif(cols)


## Plants on the grassy facets (tufts, bushes and ferns; pines on the high tops, seen from the sea) and boulders
## along the foot (in the surf, nothing to stand on: no colliders). MultiMeshes, no shadows.
func _dress_massif(cols: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4251
	var kinds := {"tuft": [Props.grass_mesh(), 140.0], "bush": [Props.bush_mesh(4252), 220.0], "fern": [Props.fern_mesh(4253), 180.0], "pine": [Props.pine_mesh(4254), 900.0]}
	var xfs := {"tuft": [], "bush": [], "fern": [], "pine": []}
	for g in _green:
		var m: Vector3 = g[0]
		var n: Vector3 = g[1]
		var up := Basis(Vector3.UP.cross(n).normalized(), Vector3.UP.angle_to(n) * 0.5) if n.y < 0.999 else Basis()
		var roll := rng.randf()
		var kind := "tuft"
		if m.y > 16.0 and n.y > 0.9 and roll < 0.1:
			kind = "pine"
		elif roll < 0.3:
			kind = "bush"
		elif roll < 0.45:
			kind = "fern"
		elif roll > 0.85:
			continue
		var s := rng.randf_range(0.7, 1.3) if kind != "pine" else rng.randf_range(0.6, 1.0)
		if kind == "pine":
			up = Basis()
		var b := (up * Basis(Vector3.UP, rng.randf() * TAU)).scaled(Vector3.ONE * s)
		(xfs[kind] as Array).append(Transform3D(b, m - n * 0.1))
		# (a second tuft beside most: the grass reads as a patch, not dots)
		if kind == "tuft" and rng.randf() < 0.7:
			var off := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
			(xfs["tuft"] as Array).append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), m + off - n * 0.15))
	for kind in xfs:
		var list: Array = xfs[kind]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = kinds[kind][0]
		mm.instance_count = list.size()
		for i in range(list.size()):
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Massif_" + kind
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = kinds[kind][1]
		mmi.visibility_range_end_margin = float(kinds[kind][1]) * 0.1
		add_child(mmi)
	# boulders in the surf along the foot
	var mb := MeshBuilder.new()
	for k in range(0, cols.size(), 2):
		var a: float = cols[k][0]
		var c := _col(a)
		if rng.randf() < 0.35:
			continue
		var r := rng.randf_range(0.9, 2.4)
		var p := _bent(a, c, float(c["rout"]) + rng.randf_range(0.2, 2.5)) + Vector3(0, rng.randf_range(-1.4, -0.2), 0)
		mb.add_blob(_massif_m, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p), Vector3(r * 1.3, r * 0.8, r), rng, 0.25, 3, 6, 0.5, Color(1, 1, 1) * rng.randf_range(0.7, 0.9), 0.0)
	var foot := mb.to_instance("FootRocks")
	foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foot.visibility_range_end = 400.0
	foot.visibility_range_end_margin = 40.0
	add_child(foot)


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
	var starts: Array = []
	for i in range(1, ctl.size() - 2):
		var p0: Vector3 = ctl[i - 1]
		var p1: Vector3 = ctl[i]
		var p2: Vector3 = ctl[i + 1]
		var p3: Vector3 = ctl[i + 2]
		var n := int(p1.distance_to(p2) / 0.25) + 1
		starts.append(_curve.size())
		for k in range(n):
			var t := float(k) / n
			# Catmull-Rom
			var t2 := t * t
			var t3 := t2 * t
			_curve.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	_curve.append(PATH[PATH.size() - 1])
	starts.append(_curve.size() - 1)
	# heights even along each flight by flat distance (the spline's own bunched up round the bends into a 54-degree
	# lip nobody could walk up)
	for s in range(starts.size() - 1):
		var i0: int = starts[s]
		var i1: int = starts[s + 1]
		var flat := PackedFloat32Array([0.0])
		for i in range(i0 + 1, i1 + 1):
			var a: Vector3 = _curve[i - 1]
			var b: Vector3 = _curve[i]
			flat.append(flat[flat.size() - 1] + Vector2(b.x - a.x, b.z - a.z).length())
		var y0: float = (PATH[s] as Vector3).y
		var y1: float = (PATH[s + 1] as Vector3).y
		for i in range(i0, i1 + 1):
			var pt: Vector3 = _curve[i]
			pt.y = lerpf(y0, y1, flat[i - i0] / maxf(flat[flat.size() - 1], 0.001))
			_curve[i] = pt
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


## The stair line's height at the point of it nearest `p` (flat).
func _line_y(p: Vector3) -> float:
	var pts := _curve_pts()
	var best := INF
	var y := 0.0
	var q := Vector2(p.x, p.z)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var a2 := Vector2(a.x, a.z)
		var ab := Vector2(b.x, b.z) - a2
		var t := clampf((q - a2).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := q.distance_to(a2 + ab * t)
		if d < best:
			best = d
			y = lerpf(a.y, b.y, t)
	return y


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
	# what you walk on: a smooth slope under the steps (steps you can't step up), a fine grid over the stair's
	# corridor at the height of the line's nearest point (a ribbon along the line bunched up on the inside of the
	# bends into a lip too steep to walk)
	var faces := PackedVector3Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for pt in _curve_pts():
		lo = Vector2(minf(lo.x, pt.x), minf(lo.y, pt.z))
		hi = Vector2(maxf(hi.x, pt.x), maxf(hi.y, pt.z))
	var reach := PATH_W * 0.5 + 0.2
	var cell := 0.4
	var nx := int((hi.x - lo.x + 2.0 * reach) / cell) + 2
	var nz := int((hi.y - lo.y + 2.0 * reach) / cell) + 2
	var grid := {}
	for gz in range(nz):
		for gx in range(nx):
			var v := Vector3(lo.x - reach + gx * cell, 0.0, lo.y - reach + gz * cell)
			if _path_dist(v) <= reach + cell:
				v.y = _line_y(v)
				grid[Vector2i(gx, gz)] = v
	for key in grid:
		var k: Vector2i = key
		var a: Vector3 = grid[k]
		var b = grid.get(k + Vector2i(1, 0))
		var c = grid.get(k + Vector2i(1, 1))
		var d = grid.get(k + Vector2i(0, 1))
		if b == null or c == null or d == null:
			continue
		if _path_dist((a + c) * 0.5) > reach:
			continue
		faces.append_array([a, b, c, a, c, d])
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
## Sea stacks off the mountain's foot: [bearing, gap past the foot, base radius, height above the sea]
const CRAGS := [
	[-0.35, 9.0, 3.2, 14.0], [-1.15, 13.0, 4.2, 19.0], [-1.95, 7.0, 2.6, 9.0],
	[-2.5, 11.0, 3.6, 15.0], [2.95, 8.0, 3.0, 10.5], [0.3, 12.0, 2.4, 8.0],
]
## Stacks out past the cove's mouth: [bearing, distance, base radius, height above the sea]
const MOUTH := [[1.12, 80.0, 2.8, 12.0], [1.9, 86.0, 2.2, 9.0]]
## Spires on the crest: [bearing, height, base radius]
const CREST := [[-1.75, 11.0, 2.6], [-1.62, 7.0, 1.8], [-1.15, 8.5, 2.2], [-2.55, 9.0, 2.4], [-2.35, 5.5, 1.6],
	[0.15, 7.0, 2.0], [-0.55, 6.0, 1.8], [2.95, 7.5, 2.1], [2.6, 5.0, 1.5], [-0.95, 4.5, 1.4], [0.6, 6.0, 2.0], [2.52, 6.5, 2.0]]


func _build_crags() -> void:
	var body := StaticBody3D.new()
	body.name = "Crags"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4246
	var spires: Array = []
	for cg in CRAGS:
		var a: float = cg[0]
		var c := _col(a)
		spires.append([_bent(a, c, float(c["rout"]) + float(cg[1])) + Vector3(0, -6.0, 0), float(cg[2]), float(cg[3]) + 6.0])
	for cg in MOUTH:
		var a: float = cg[0]
		spires.append([Vector3(cos(a) * float(cg[1]), -6.0, sin(a) * float(cg[1])), float(cg[2]), float(cg[3]) + 6.0])
	for cg in CREST:
		var a: float = cg[0]
		var c := _col(a)
		spires.append([_bent(a, c, float(c["rc"]) + 0.6) + Vector3(0, float(c["h"]) - 3.0, 0), float(cg[2]), float(cg[1]) + 3.0])
	for s in spires:
		var pts := _spire(mb, s[0], s[1], s[2], rng)
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		cs.shape = shape
		body.add_child(cs)
	_arch(mb, body, rng)
	body.add_child(mb.to_instance("CragMesh"))


## A sea arch off the west arm's tip: a ragged rock bow from the arm's cliff out into the sea and down.
const ARCH_SPAN := 24.0
const ARCH_H := 17.0


func _arch(mb: MeshBuilder, body: StaticBody3D, rng: RandomNumberGenerator) -> void:
	var a := OPEN_A + OPEN_HALF + 0.03
	var c := _col(a)
	var root := _bent(a, c, float(c["rout"]) - 3.0)
	var out := (_bent(a, c, float(c["rout"]) + 30.0) - root).normalized()
	var foot := root + out * ARCH_SPAN
	var side := out.cross(Vector3.UP).normalized()
	var sides := 7
	var rings: Array = []
	var n := 14
	for i in range(n + 1):
		var t := float(i) / n
		var centre := root.lerp(foot, t) + Vector3(0, -8.0 + (ARCH_H + 8.0) * sin(PI * t), 0)
		# (the lintel lifted and thinned mid-span, the legs thick)
		var along := (foot - root) + Vector3(0, (ARCH_H + 8.0) * PI * cos(PI * t), 0)
		var nrm := along.cross(side).normalized()
		var thick := lerpf(4.2, 2.4, sin(PI * t)) * rng.randf_range(0.85, 1.15)
		var wide := lerpf(4.8, 3.0, sin(PI * t)) * rng.randf_range(0.85, 1.15)
		var ring: Array = []
		for k in range(sides):
			var th := TAU * (k + rng.randf_range(-0.15, 0.15)) / sides
			ring.append(centre + side * cos(th) * wide * rng.randf_range(0.8, 1.15) + nrm * sin(th) * thick * rng.randf_range(0.8, 1.15))
		rings.append([centre, ring])
	for i in range(rings.size() - 1):
		var r0: Array = rings[i][1]
		var r1: Array = rings[i + 1][1]
		var pts := PackedVector3Array()
		for k in range(sides):
			var k2 := (k + 1) % sides
			var mid: Vector3 = ((rings[i][0] as Vector3) + (rings[i + 1][0] as Vector3)) * 0.5
			_cell(mb, r0[k], r0[k2], r1[k2], r1[k], ((r0[k] as Vector3) - mid).normalized(), _stack_pick, (i + k) % 2 == 0)
			pts.append(r0[k])
			pts.append(r1[k])
		var cs := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		cs.shape = shape
		body.add_child(cs)


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
	Seat.add(self, cp + Vector3(0, 0.57, 0.1), 0.57, Vector3(0, 0, 1))
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
	guards.add_grunt({"post": Vector3(-2.4, TOP, 14.0), "yaw": out_yaw, "mode": "stand", "seed": 301, "elite": true})
	guards.add_grunt({"post": Vector3(2.4, TOP, 14.0), "yaw": out_yaw, "mode": "stand", "seed": 302, "elite": true})
	guards.add_grunt({"post": Vector3(-9.0, TOP, -6.0), "yaw": out_yaw - 0.6, "mode": "stand", "role": "rifle", "seed": 303, "elite": true})


# ==========================================================================
# The captain
# ==========================================================================
## The fight's middle (where a phase change's leap lands him: BossReset).
func centre() -> Vector3:
	return to_global(ARENA)


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
		g.setup({"post": to_global(land), "yaw": 0.0, "mode": "stand", "role": "sword", "seed": rng.randi(), "elite": true})
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
	if me and not _arrived and me.global_position.distance_to(global_position) < REACH + 15.0:
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
			# near the fort, or near Morrow himself wherever the fight took him
			if (pp.global_position.distance_to(center) < RESET_RANGE or pp.global_position.distance_to(boss.global_position) < 35.0) \
					and p.has_method("is_standing") and p.is_standing():
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
		get_tree().call_group("hud", "show_boss", "Captain Morrow \"Red Tide\"", boss.health_frac(), boss.phase, boss)
		_boss_ui = true
	elif _boss_ui:
		_boss_ui = false
		get_tree().call_group("hud", "hide_boss")


## Beaten: banner, fanfare, and his hoard for each captain (once per character).
func _victory() -> void:
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me and me.global_position.distance_to(to_global(ARENA)) < 70.0:
		get_tree().call_group("hud", "show_banner", "Captain Morrow defeated!", "The Red Tide recedes", true)
		# (the story villain's second Edy point, on top of his boss's: WillPaths.SOURCES)
		me.progression.will_point(1, "Captain Morrow")
		var music := get_node_or_null("/root/Music")
		if music:
			music.victory()
		# his log pose, off his wrist (after the victory banner has had its moment)
		if me.has_method("give_log_pose") and not me.has_log_pose():
			get_tree().create_timer(4.5).timeout.connect(func():
				if is_instance_valid(me):
					me.give_log_pose())
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
