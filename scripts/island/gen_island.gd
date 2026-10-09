class_name GenIsland
extends Island
## An island of the chain (docs/island_chain_plan.md), made from its chain node
## (seed, theme, role, level): the same on every screen.
##
## Land: a coast by bearing (a wobbling circle with capes and bays pushed out
## and in, and a stretch or two of sheer cliff), a beach ramp up to a rolling
## interior, the theme's summit and hills. The places step 6 fills in are
## planned now so the land and the paths are made for them (`sites`): the dock
## on a gentle shore, the village (by the dock or further in), the boss's
## ground on the far side, a camp, a lair, ruins and the summit's lookout, each
## on its own levelled ground with a path from the village.
## Then the dock, the theme's vegetation (MultiMesh per 70 m square, tree
## colliders and grapple crowns) and the seabed's depth for the shallows.
## Local coordinates: the island's centre at 0, -Z north.

const CELL := 3.0
const SEAFLOOR := -30.0
## Sea between the furthest coast and the edge of the island's own terrain.
const MARGIN := 80.0
const RADIUS := [300.0, 450.0]
const DOCK_DECK_Y := 1.7
const PIER_LEN := 30.0
const BERTH_DEPTH := 4.5
const SITE_GAP := 90.0
## Ground kept clear at each site's middle (m, reserve_area).
const SITE_CLEAR := {"village": 30.0, "boss": 24.0, "camp": 18.0, "lair": 14.0, "ruins": 11.0, "summit": 8.0}
const VEG_CELL := 70.0

var node: Dictionary
var theme: String
var radius: float
var extent: float
var half: float
var res: int
var heights := PackedFloat32Array()
## name -> Vector2 (island space): dock, village, boss, camp, lair, ruins, summit
var sites := {}
var dock_shore := Vector2.ZERO
var dock_dir := Vector2(0, -1)
var paths: Array = []
## cell -> [[centre, radius]] (reserve)
var exclusions := {}
## Island-space crowns of the trees in the thick of the cover (step 6's spitters).
var forest_crowns: Array = []
var build_ms := {}

var _def: Dictionary
var _rng := RandomNumberGenerator.new()
var _coast_noise := FastNoiseLite.new()
var _shape_noise := FastNoiseLite.new()
var _roll_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _cover_noise := FastNoiseLite.new()
## [bearing (rad), metres (+ cape, - bay), half width (rad)]
var _capes: Array = []
## [bearing, half width] of sheer coast
var _cliffs: Array = []
var _cliff_h := 9.0
var _ramp := 50.0
## [centre, height, sigma]
var _bumps: Array = []
## [centre, target height, r_in, r_out]
var _flat: Array = []
## [centre, radius]: land kept round every site whatever the bays do
var _keep: Array = []
var _path_bounds: Array = []
var _path_widths: Array = []
## prepare's results for finish
var _arrays: Array = []
## The terrain's triangles for its colliders, a GROUND x GROUND grid of them (worked out in prepare).
var _faces: Array = []
const GROUND := 4
var _shoal_img: Image
## [mesh, kind, cell x, cell z] -> [Transform3D]
var _buckets := {}
## [radius, height (0 = a sphere), centre]
var _shapes: Array = []
var _crowns: Array = []


## All at once (tests and tools; the world uses prepare on a worker thread, then finish).
func build(n: Dictionary) -> void:
	IslandTheme.meshes(str(n["theme"]))
	prepare(n)
	finish()


## Everything that's only numbers (the land, the sites, the paths, the terrain's
## arrays, where every plant and rock goes): safe on a worker thread, touching
## no node or server. The theme's meshes must be made first (IslandTheme.meshes,
## on the main thread).
func prepare(n: Dictionary) -> void:
	node = n
	theme = str(n["theme"])
	_def = IslandTheme.def(theme)
	_rng.seed = int(n["seed"])
	radius = _rng.randf_range(RADIUS[0], RADIUS[1])
	extent = ceilf((radius + MARGIN) * 2.0 / CELL) * CELL
	half = extent * 0.5
	res = int(extent / CELL)
	var t0 := Time.get_ticks_usec()
	_setup_shape()
	_plan_sites()
	_generate_heights()
	build_ms["land"] = _lap(t0)
	t0 = Time.get_ticks_usec()
	_define_paths()
	_terrain_arrays()
	_shoal_image()
	build_ms["arrays"] = _lap(t0)
	_plan_dock()
	_scatter_vegetation()
	# the villagers' bodies, ready for their NPCs (Humanoid.make picks them up)
	t0 = Time.get_ticks_usec()
	for lk in IslandVillage.looks(self) + [JungleApe.ape_look()]:
		var h := Humanoid.new()
		h.setup(lk)
		Humanoid.stock(h, lk)
	build_ms["bodies"] = _lap(t0)


## The nodes, meshes and colliders from what prepare worked out, all at once
## (tests and tools; the world runs finish_steps a frame at a time).
func finish() -> void:
	for s in finish_steps():
		run_step(s)


## finish's work in pieces ([name, Callable]), in order (main thread, in the tree).
func finish_steps() -> Array:
	island_name = str(node["name"])
	island_type = theme
	is_generated = true
	var steps: Array = [["terrain", _terrain_node]]
	for i in range(GROUND * GROUND):
		steps.append(["ground", _terrain_collider.bind(i)])
	steps += [
		["dock", func(): _build_dock(); _add_arrival_zone()],
		["plants", _vegetation_meshes],
		["colliders", _vegetation_colliders],
	]
	steps.append_array(IslandContent.steps(self))
	return steps


## Runs one of finish_steps; its ms (steps of the same name add up in build_ms).
func run_step(s: Array) -> int:
	var t0 := Time.get_ticks_usec()
	(s[1] as Callable).call()
	var ms := _lap(t0)
	build_ms[s[0]] = int(build_ms.get(s[0], 0)) + ms
	return ms


func _lap(t0: int) -> int:
	return int((Time.get_ticks_usec() - t0) / 1000)


# ==========================================================================
# The land's shape
# ==========================================================================
func _setup_shape() -> void:
	var s := int(node["seed"])
	for pair in [[_coast_noise, 0.02, 3], [_shape_noise, 0.006, 3], [_roll_noise, 0.016, 3], [_detail_noise, 0.09, 2], [_cover_noise, 0.011, 3]]:
		var nz: FastNoiseLite = pair[0]
		s += 17
		nz.seed = s
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.frequency = pair[1]
		nz.fractal_octaves = pair[2]
	for i in range(_rng.randi_range(3, 6)):
		var sign_ := 1.0 if _rng.randf() < 0.55 else -1.0
		_capes.append([_rng.randf() * TAU, sign_ * radius * _rng.randf_range(0.08, 0.2), deg_to_rad(_rng.randf_range(6.0, 18.0))])
	_ramp = _rng.randf_range(_def["ramp"][0], _def["ramp"][1])
	_cliff_h = _rng.randf_range(_def["cliff_h"][0], _def["cliff_h"][1])
	for i in range(_rng.randi_range(_def["cliffs"][0], _def["cliffs"][1])):
		_cliffs.append([_rng.randf() * TAU, deg_to_rad(_rng.randf_range(14.0, 30.0))])
	var peak_at := Vector2.from_angle(_rng.randf() * TAU) * radius * _rng.randf_range(0.0, 0.3)
	_bumps.append([peak_at, _rng.randf_range(_def["peak"][0], _def["peak"][1]), radius * _rng.randf_range(0.18, 0.26)])
	for i in range(_rng.randi_range(_def["hills"][0], _def["hills"][1])):
		var at := Vector2.from_angle(_rng.randf() * TAU) * radius * _rng.randf_range(0.25, 0.6)
		_bumps.append([at, _rng.randf_range(_def["hill_h"][0], _def["hill_h"][1]), _rng.randf_range(22.0, 48.0)])


## How far the coast reaches along bearing `ang` (before the 2D wobble).
func _coast_r(ang: float) -> float:
	var r := radius * 0.8 + _coast_noise.get_noise_2d(cos(ang) * 60.0, sin(ang) * 60.0) * radius * 0.12
	for c in _capes:
		r += float(c[1]) * (1.0 - _smooth(0.2, 1.0, absf(angle_difference(ang, c[0])) / float(c[2])))
	return minf(r, radius)


## 0..1: how much of a cliff the coast is along `ang`.
func _cliff(ang: float) -> float:
	var k := 0.0
	for c in _cliffs:
		k = maxf(k, 1.0 - _smooth(0.55, 1.0, absf(angle_difference(ang, c[0])) / float(c[1])))
	return k


## Signed distance from the coast (- inland), with the sites' land kept.
func _coast_t(p: Vector2) -> float:
	var ang := atan2(p.y, p.x)
	var t := p.length() - _coast_r(ang) + _shape_noise.get_noise_2d(p.x, p.y) * 30.0
	for k in _keep:
		t = minf(t, p.distance_to(k[0]) - float(k[1]))
	return t


func _height_natural(p: Vector2) -> float:
	var t := _coast_t(p)
	var cl := _cliff(atan2(p.y, p.x))
	var base := lerpf(float(_def["base"]), _cliff_h, cl)
	var ramp := lerpf(_ramp, 6.0, cl)
	var h: float
	if t < 0.0:
		h = lerpf(lerpf(0.5, _cliff_h * 0.6, cl), base, pow(clampf(-t / ramp, 0.0, 1.0), 0.85))
	else:
		h = lerpf(lerpf(0.5, -2.0, cl), SEAFLOOR, _smooth(0.0, lerpf(60.0, 22.0, cl), t))
	var inland := clampf(-t / 40.0 - 0.1, 0.0, 1.0)
	h += _roll_noise.get_noise_2d(p.x, p.y) * float(_def["roll"]) * inland
	h += _detail_noise.get_noise_2d(p.x, p.y) * 0.45 * inland
	for b in _bumps:
		h += float(b[1]) * _gauss(p, b[0], b[2]) * inland
	return h


func _height_fn(p: Vector2) -> float:
	var h := _height_natural(p)
	for z in _flat:
		var w := 1.0 - _smooth(z[2], z[3], p.distance_to(z[0]))
		if w > 0.0:
			h = lerpf(h, z[1], w)
	# a berth dredged off the pier's head, deep enough for the ship
	var b := 1.0 - _smooth(10.0, 24.0, p.distance_to(dock_shore + dock_dir * (PIER_LEN - 2.0)))
	if b > 0.0:
		h = minf(h, lerpf(h, -BERTH_DEPTH, b))
	return h


func _generate_heights() -> void:
	heights.resize((res + 1) * (res + 1))
	for iz in range(res + 1):
		for ix in range(res + 1):
			heights[iz * (res + 1) + ix] = _height_fn(Vector2(-half + ix * CELL, -half + iz * CELL))


static func _gauss(p: Vector2, c: Vector2, sigma: float) -> float:
	return exp(-p.distance_squared_to(c) / (2.0 * sigma * sigma))


static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _h(ix: int, iz: int) -> float:
	return heights[clampi(iz, 0, res) * (res + 1) + clampi(ix, 0, res)]


## Exact terrain height (matches the rendered triangles). Local coordinates.
func height_at(x: float, z: float) -> float:
	var fx := (x + half) / CELL
	var fz := (z + half) / CELL
	var ix := clampi(int(floor(fx)), 0, res - 1)
	var iz := clampi(int(floor(fz)), 0, res - 1)
	var u := clampf(fx - ix, 0.0, 1.0)
	var v := clampf(fz - iz, 0.0, 1.0)
	var h00 := _h(ix, iz)
	var h10 := _h(ix + 1, iz)
	var h01 := _h(ix, iz + 1)
	var h11 := _h(ix + 1, iz + 1)
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


func hv(p: Vector2) -> float:
	return height_at(p.x, p.y)


func walk_height(x: float, z: float) -> float:
	return height_at(x, z)


func _slope_at(p: Vector2) -> float:
	var e := 1.5
	var dx := height_at(p.x + e, p.y) - height_at(p.x - e, p.y)
	var dz := height_at(p.x, p.y + e) - height_at(p.x, p.y - e)
	return 1.0 - Vector3(-dx, 2.0 * e, -dz).normalized().y


func _ground_min(c: Vector2, r: float) -> float:
	var m := hv(c)
	for i in range(8):
		m = minf(m, hv(c + Vector2.from_angle(TAU * i / 8.0) * r))
	return m


# ==========================================================================
# Sites (where step 6's places go)
# ==========================================================================
func _plan_sites() -> void:
	# the dock: a gentle stretch of coast (no cliff), the shore where the land runs out
	var best := 0.0
	var best_cl := 2.0
	for k in range(24):
		var a := _rng.randf() * TAU
		var cl := _cliff(a) + absf(_coast_r(a) - radius * 0.8) / radius
		if cl < best_cl:
			best_cl = cl
			best = a
	dock_dir = Vector2.from_angle(best)
	var r := 0.0
	while r < radius + 40.0 and _height_natural(dock_dir * r) > 0.4:
		r += 1.0
	dock_shore = dock_dir * r
	sites["dock"] = dock_shore
	_keep.append([dock_shore - dock_dir * 20.0, 26.0])
	# the village: by the dock half the time, otherwise well inland
	var inland := _rng.randf_range(60.0, 90.0) if _rng.randf() < 0.5 else _rng.randf_range(130.0, 190.0)
	sites["village"] = _settle(dock_shore - dock_dir * inland, 30.0)
	# the boss's ground on the far side, the others round about
	sites["boss"] = _settle(-dock_dir * radius * _rng.randf_range(0.5, 0.62), 26.0)
	var peak: Vector2 = _bumps[0][0]
	sites["summit"] = peak
	# the others round about: the try furthest from every site so far (SITE_GAP is enough)
	for site in ["camp", "lair", "ruins"]:
		var pick := Vector2.ZERO
		var pick_gap := -1.0
		for k in range(40):
			var at := _settle(Vector2.from_angle(_rng.randf() * TAU) * radius * _rng.randf_range(0.3, 0.68), 18.0)
			var gap := INF
			for q in sites.values():
				gap = minf(gap, at.distance_to(q))
			if gap > pick_gap:
				pick_gap = gap
				pick = at
			if gap > SITE_GAP:
				break
		sites[site] = pick
	for site in sites.keys():
		if site != "dock" and site != "summit":
			_keep.append([sites[site], 30.0])
	# the sites' cores stay clear of trees and rocks (what's built there comes later)
	for site in SITE_CLEAR.keys():
		reserve_area(sites[site], SITE_CLEAR[site])
	# levelled ground for each (the summit keeps its top)
	_flat.append([sites["village"], _height_natural(sites["village"]), 26.0, 44.0])
	_flat.append([sites["boss"], _height_natural(sites["boss"]), 22.0, 36.0])
	_flat.append([sites["camp"], _height_natural(sites["camp"]), 14.0, 24.0])
	_flat.append([sites["lair"], _height_natural(sites["lair"]), 16.0, 26.0])
	_flat.append([sites["ruins"], _height_natural(sites["ruins"]), 10.0, 18.0])
	_flat.append([dock_shore - dock_dir * 8.0, 2.0, 8.0, 16.0])


## `p` pulled toward the middle until it's well inland (land kept round it later).
func _settle(p: Vector2, inset: float) -> Vector2:
	var q := p
	for i in range(30):
		if _coast_t(q) < -inset:
			return q
		q *= 0.92
	return q


# ==========================================================================
# Paths
# ==========================================================================
func _define_paths() -> void:
	var v: Vector2 = sites["village"]
	_add_path([dock_shore - dock_dir * 2.0, _mid(dock_shore, v, 0.5, 12.0), v], 1.8)
	for site in ["boss", "camp", "lair", "ruins", "summit"]:
		var to: Vector2 = sites[site]
		_add_path([v, _mid(v, to, 0.35, 30.0), _mid(v, to, 0.7, 30.0), to], 1.3)


## A point `k` of the way from a to b, pushed `wander` m to either side.
func _mid(a: Vector2, b: Vector2, k: float, wander: float) -> Vector2:
	var d := b - a
	return a + d * k + Vector2(-d.y, d.x).normalized() * _rng.randf_range(-wander, wander)


func _add_path(pts: Array, hw: float) -> void:
	var smooth := StarterIsland._catmull(pts)
	paths.append(smooth)
	_path_widths.append(hw)
	var rect := Rect2(smooth[0], Vector2.ZERO)
	for q in smooth:
		rect = rect.expand(q)
	_path_bounds.append(rect.grow(hw + 4.0))


func _path_dist(p: Vector2) -> float:
	var best := 9999.0
	for i in range(paths.size()):
		if not (_path_bounds[i] as Rect2).has_point(p):
			continue
		var pts: PackedVector2Array = paths[i]
		for j in range(pts.size() - 1):
			var a := pts[j]
			var ab := pts[j + 1] - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t) - float(_path_widths[i]))
	return best


## Keep the ground round `p` (radius `r`, up to EXCL_CELL) clear of anything scattered later.
func reserve(p: Vector2, r: float) -> void:
	var k := Vector2i(floori(p.x / EXCL_CELL), floori(p.y / EXCL_CELL))
	if not exclusions.has(k):
		exclusions[k] = []
	exclusions[k].append([p, r])


## A big round area kept clear: small disks over it (a single big one would
## sit in one cell, out of reach of checks a few cells away).
func reserve_area(c: Vector2, r: float) -> void:
	var x := -r
	while x <= r:
		var z := -r
		while z <= r:
			if Vector2(x, z).length() <= r:
				reserve(c + Vector2(x, z), 3.5)
			z += 5.0
		x += 5.0


func _excluded(p: Vector2, pad: float) -> bool:
	var c := Vector2i(floori(p.x / EXCL_CELL), floori(p.y / EXCL_CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for e in exclusions.get(c + Vector2i(dx, dz), []):
				if p.distance_to(e[0]) < float(e[1]) + pad:
					return true
	return false


## (a grid of what's reserved: each check looks at the 3 x 3 cells round it)
const EXCL_CELL := 8.0


# ==========================================================================
# Terrain mesh, seabed for the shallows
# ==========================================================================
func _terrain_arrays() -> void:
	var n := (res + 1) * (res + 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n)
	norms.resize(n)
	cols.resize(n)
	var disks := []
	for site in ["village", "boss", "camp", "lair", "ruins"]:
		disks.append([sites[site], 12.0 if site == "village" else 8.0])
	for iz in range(res + 1):
		for ix in range(res + 1):
			var i := iz * (res + 1) + ix
			var p := Vector2(-half + ix * CELL, -half + iz * CELL)
			var h := heights[i]
			verts[i] = Vector3(p.x, h, p.y)
			norms[i] = Vector3(_h(ix - 1, iz) - _h(ix + 1, iz), 2.0 * CELL, _h(ix, iz - 1) - _h(ix, iz + 1)).normalized()
			var dirt := 0.0
			var sand := 0.0
			if h > -1.0:
				# (wide enough to always catch a vertex: paths are narrower than a cell)
				dirt = 1.0 - _smooth(0.4, 2.2, _path_dist(p))
				for d in disks:
					dirt = maxf(dirt, 1.0 - _smooth(d[1], float(d[1]) + 5.0, p.distance_to(d[0])))
				sand = (1.0 - _smooth(1.7, 2.8, h)) * (1.0 - dirt)
			cols[i] = Color(dirt, 0.0, sand, 1.0)
	var idx := PackedInt32Array()
	idx.resize(res * res * 6)
	var k := 0
	for iz in range(res):
		for ix in range(res):
			var tl := iz * (res + 1) + ix
			var bl := tl + res + 1
			idx[k] = tl; idx[k + 1] = tl + 1; idx[k + 2] = bl
			idx[k + 3] = tl + 1; idx[k + 4] = bl + 1; idx[k + 5] = bl
			k += 6
	_faces = []
	for gz in range(GROUND):
		for gx in range(GROUND):
			var f := PackedVector3Array()
			for iz in range(gz * res / GROUND, (gz + 1) * res / GROUND):
				for ix in range(gx * res / GROUND, (gx + 1) * res / GROUND):
					var q := (iz * res + ix) * 6
					for j in range(6):
						f.append(verts[idx[q + j]])
			_faces.append(f)
	_arrays.resize(Mesh.ARRAY_MAX)
	_arrays[Mesh.ARRAY_VERTEX] = verts
	_arrays[Mesh.ARRAY_NORMAL] = norms
	_arrays[Mesh.ARRAY_COLOR] = cols
	_arrays[Mesh.ARRAY_INDEX] = idx


func _terrain_node() -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	mesh.surface_set_material(0, PSXMat.terrain(true, 0.0))
	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)


## One square of the ground's collider, a body each (a frame each: the physics
## engine builds a mesh shape as it joins, ~150 ms for the whole island at once).
func _terrain_collider(i: int) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground%d" % i
	body.collision_layer = 1
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(_faces[i])
	_faces[i] = PackedVector3Array()
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


## The seabed's depth for the ocean's shallows, an L8 texel per vertex.
func _shoal_image() -> void:
	var data := PackedByteArray()
	data.resize((res + 1) * (res + 1))
	for i in range(data.size()):
		data[i] = int(clampf(-heights[i] / Ocean.SHOAL_DEPTH, 0.0, 1.0) * 255.0)
	_shoal_img = Image.create_from_data(res + 1, res + 1, false, Image.FORMAT_L8, data)


## The shallows for the ocean: [texture, the world rect it covers (x0, z0, size, 1)].
func shallows() -> Array:
	var g := global_position
	return [ImageTexture.create_from_image(_shoal_img), Vector4(g.x - half - CELL * 0.5, g.z - half - CELL * 0.5, extent + CELL, 1.0)]


# ==========================================================================
# The dock: a timber pier out from the shore to deep enough water
# ==========================================================================
const PIER_HW := 2.0
## (the pier's local +z runs out to sea; it starts this far up the beach)
const PIER_Z0 := -6.0


func _plan_dock() -> void:
	var d := PIER_Z0
	while d < PIER_LEN + 4.0:
		reserve(dock_shore + dock_dir * d, PIER_HW + 1.5)
		d += 4.0
	sites["dock_end"] = dock_shore + dock_dir * PIER_LEN


func _build_dock() -> void:
	var length := PIER_LEN
	var hw := PIER_HW
	var z0 := PIER_Z0
	var body := StaticBody3D.new()
	body.name = "Pier"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector3(dock_shore.x, 0.0, dock_shore.y)
	body.rotation.y = StarterIsland.face_yaw(dock_dir)
	add_child(body)
	var deck := PSXMat.lit("planks_weathered", Color.WHITE, {"affine": 0.5})
	var dark := PSXMat.lit("planks_dark")
	var mb := MeshBuilder.new()
	mb.add_box(deck, Transform3D(Basis(), Vector3(0, DOCK_DECK_Y - 0.15, (z0 + length) * 0.5)), Vector3(hw * 2.0, 0.3, length - z0), 0.5, Color.WHITE, false)
	var z := z0 + 1.0
	while z < length:
		for s in [-1.0, 1.0]:
			var post_at := Vector3(s * (hw - 0.2), 0, z)
			var ground := hv(dock_shore + dock_dir * z)
			mb.add_cylinder(dark, Transform3D(Basis(), post_at + Vector3(0, ground - 0.5, 0)), 0.17, 0.15, DOCK_DECK_Y + 0.9 - ground, 6, 0.6)
		z += 4.0
	for s in [-1.0, 1.0]:
		mb.add_box(dark, Transform3D(Basis(), Vector3(s * (hw - 0.1), DOCK_DECK_Y + 0.05, (z0 + length) * 0.5)), Vector3(0.2, 0.12, length - z0), 0.6)
	body.add_child(mb.to_instance("PierMesh"))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(hw * 2.0, 0.3, length - z0)
	cs.shape = box
	cs.position = Vector3(0, DOCK_DECK_Y - 0.15, (z0 + length) * 0.5)
	body.add_child(cs)
	var lad := Ladder.new()
	lad.length = DOCK_DECK_Y + 1.2
	lad.rail = 0.0
	lad.deck_depth = 0.9
	lad.position = Vector3(0, DOCK_DECK_Y, length)
	body.add_child(lad)
	var post := Props.lantern_post()
	post.position = Vector3(-hw + 0.5, DOCK_DECK_Y, length - 1.0)
	body.add_child(post)
	var area := Interactable.new()
	area.name = "DockingArea"
	area.collision_layer = 512
	area.collision_mask = 0
	area.prompt_text = "Board ship"
	var acs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 4.0
	acs.shape = sph
	area.add_child(acs)
	area.position = Vector3(0, DOCK_DECK_Y + 1.0, length - 2.0)
	body.add_child(area)


## Where a ship lies alongside the pier's head (world), and her heading out.
func mooring() -> Array:
	var side := Vector2(-dock_dir.y, dock_dir.x)
	var at: Vector2 = sites["dock_end"] + side * 6.0 - dock_dir * 4.0
	return [to_global(Vector3(at.x, 0.0, at.y)), atan2(-dock_dir.x, -dock_dir.y)]


# ==========================================================================
# Vegetation
# ==========================================================================
## 0..1: how overgrown the inland is at p (the theme's cover, with clearings,
## kept off the sites).
func _cover(p: Vector2) -> float:
	var c := _smooth(-0.15, 0.2, _cover_noise.get_noise_2d(p.x, p.y) + float(_def["cover"]) - 0.5)
	for site in ["village", "boss", "camp", "lair", "ruins"]:
		c *= _smooth(20.0, 42.0, p.distance_to(sites[site]))
	return c


## Where every plant and rock goes (prepare: data only; _vegetation_meshes and _colliders make them).
func _scatter_vegetation() -> void:
	var m := IslandTheme.meshes(theme)
	var buckets := _buckets
	var reach := minf(half - 3.0, radius + 20.0)
	var t_veg := Time.get_ticks_usec()
	# trees and rocks on a 5 m jittered grid
	var x := -reach
	while x < reach:
		var z := -reach
		while z < reach:
			var p := Vector2(x + _rng.randf_range(-2.0, 2.0), z + _rng.randf_range(-2.0, 2.0))
			z += 5.0
			var h := hv(p)
			if h < -1.6 or _excluded(p, 1.0):
				continue
			var roll := _rng.randf()
			if h < 0.7:
				if h > -1.4 and roll < 0.05:
					_add_rock(buckets, m["rock"], p, _rng.randf_range(0.6, 1.6))
				continue
			var slope := _slope_at(p)
			if slope > 0.5:
				if roll < 0.35:
					_add_rock(buckets, m["rock"], p, _rng.randf_range(0.8, 2.2))
				continue
			if _path_dist(p) < 3.0:
				continue
			var beach := 1.0 - _smooth(2.0, 3.8, h)
			var cov := _cover(p) * (1.0 - beach)
			var p_beach := float(_def["beach_tree"]) * beach
			var p_tree := float(_def["tree"]) * cov + float(_def["edge"]) * (1.0 - cov) * (1.0 - beach)
			var p_rock := float(_def["rock"])
			if roll < p_beach:
				_add_tree(buckets, m["beach_tree"], p, h, 0.35, 3.0, _rng.randf_range(0.85, 1.15))
			elif roll < p_beach + p_tree:
				var crown := _add_tree(buckets, m["tree"], p, h, 0.45, 3.5, _rng.randf_range(0.85, 1.25) + 0.3 * cov)
				if cov > 0.7:
					forest_crowns.append(crown)
			elif roll < p_beach + p_tree + p_rock:
				_add_rock(buckets, m["rock"], p, _rng.randf_range(0.5, 1.8))
		x += 5.0
	build_ms["trees"] = _lap(t_veg)
	t_veg = Time.get_ticks_usec()
	# undergrowth on a 2.5 m grid
	x = -reach
	while x < reach:
		var z := -reach
		while z < reach:
			var p := Vector2(x + _rng.randf_range(-1.1, 1.1), z + _rng.randf_range(-1.1, 1.1))
			z += 2.5
			var h := hv(p)
			if h < 1.4 or _excluded(p, -0.5) or _slope_at(p) > 0.45:
				continue
			var pd := _path_dist(p)
			if pd < 0.6:
				continue
			var beach := 1.0 - _smooth(2.2, 3.6, h)
			var cov := _cover(p)
			var p_fern := float(_def["fern"]) * cov * (1.0 - beach)
			var p_bush := (0.05 + float(_def["bush"]) * cov) * (1.0 - beach * 0.7)
			var p_grass := (float(_def["grass"]) * (1.0 - cov * 0.5) + 0.05) * (1.0 - beach * 0.8)
			if pd < 2.0:
				p_fern = 0.0
				p_bush = 0.0
				p_grass *= 0.5
			var roll := _rng.randf()
			var b := Basis(Vector3.UP, _rng.randf() * TAU)
			var kind := ""
			if roll < p_fern:
				kind = "fern"
			elif roll < p_fern + p_bush:
				kind = "bush"
			elif roll < p_fern + p_bush + p_grass:
				kind = "grass"
			if kind != "":
				var list: Array = m[kind]
				var s := _rng.randf_range(0.8, 1.4)
				_bucket(buckets, list[_rng.randi() % list.size()], kind, Transform3D(b.scaled(Vector3.ONE * s), Vector3(p.x, h - (0.1 if kind == "bush" else 0.05), p.y)))
		x += 2.5
	build_ms["undergrowth"] = _lap(t_veg)


## One MultiMesh per mesh per VEG_CELL square (only the squares in view are drawn).
func _vegetation_meshes() -> void:
	var veg := Node3D.new()
	veg.name = "Vegetation"
	add_child(veg)
	for key in _buckets.keys():
		var xforms: Array = _buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = key[0]
		mm.instance_count = xforms.size()
		for i in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		match str(key[1]):
			"grass", "fern":
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 90.0
			"bush":
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 160.0
		veg.add_child(mmi)


## The tree and rock colliders, the grapple crowns.
func _vegetation_colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "VegetationColliders"
	body.collision_layer = 1
	body.collision_mask = 0
	for s in _shapes:
		var cs := CollisionShape3D.new()
		if float(s[1]) > 0.0:
			var cyl := CylinderShape3D.new()
			cyl.radius = s[0]
			cyl.height = s[1]
			cs.shape = cyl
		else:
			var sph := SphereShape3D.new()
			sph.radius = s[0]
			cs.shape = sph
		cs.position = s[2]
		body.add_child(cs)
	# (filled before it joins the tree: each shape added to a body in the tree rebuilds its whole compound)
	add_child(body)
	for c in _crowns:
		GrapplePoints.add(self, c)


func _bucket(buckets: Dictionary, mesh: Mesh, kind: String, xf: Transform3D) -> void:
	var key := [mesh, kind, floori(xf.origin.x / VEG_CELL), floori(xf.origin.z / VEG_CELL)]
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(xf)


func _add_tree(buckets: Dictionary, meshes: Array, p: Vector2, h: float, col_r: float, col_h: float, s: float) -> Vector3:
	var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
	var mesh: Mesh = meshes[_rng.randi() % meshes.size()]
	var xf := Transform3D(b, Vector3(p.x, h - 0.15, p.y))
	_bucket(buckets, mesh, "tree", xf)
	var crown := xf * GrapplePoints.crown_of(mesh)
	_crowns.append(crown)
	_shapes.append([col_r * s, col_h, Vector3(p.x, h + col_h * 0.5, p.y)])
	reserve(p, 1.2)
	return crown


func _add_rock(buckets: Dictionary, meshes: Array, p: Vector2, s: float) -> void:
	var h := _ground_min(p, s * 0.8)
	var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.2), s))
	_bucket(buckets, meshes[_rng.randi() % meshes.size()], "rock", Transform3D(b, Vector3(p.x, h - 0.1 * s, p.y)))
	if s > 0.7:
		_shapes.append([s * 0.85, 0.0, Vector3(p.x, h + s * 0.1, p.y)])
	reserve(p, s)


# ==========================================================================
# Putting things on the land (IslandContent; main thread)
# ==========================================================================
## A node at a site's middle on the ground, holding what's built there (its
## nav zone parses just this).
func site_node(site: String) -> Node3D:
	var n := get_node_or_null("Site_" + site) as Node3D
	if n == null:
		n = Node3D.new()
		n.name = "Site_" + site
		var p: Vector2 = sites[site]
		n.position = Vector3(p.x, hv(p), p.y)
		add_child(n)
	return n


## Put `node` on the ground at island point `p` under `parent` (a site node or
## the island). `footprint` > 0 stands it on the highest ground under it.
func place(node: Node3D, parent: Node3D, p: Vector2, yaw: float = 0.0, footprint: float = 0.0, y_offset: float = 0.0) -> Node3D:
	var y := _ground_max(p, footprint) if footprint > 0.0 else hv(p)
	parent.add_child(node)
	node.global_position = to_global(Vector3(p.x, y + y_offset, p.y))
	node.global_rotation.y = yaw
	return node


func _ground_max(c: Vector2, r: float) -> float:
	var m := hv(c)
	for i in range(8):
		m = maxf(m, hv(c + Vector2.from_angle(TAU * i / 8.0) * r))
	return m


## A Buildings.house whose footing reaches the lowest ground under it (or on stilts).
func house(spec: Dictionary, parent: Node3D, p: Vector2, face: Vector2, on_stilts: bool = false) -> Node3D:
	var r := maxf(float(spec.get("w", 6.0)), float(spec.get("d", 5.0))) * 0.6
	var top := _ground_max(p, r)
	var low := _ground_min(p, r)
	if on_stilts:
		spec["stilts"] = maxf(top - low + 0.6, 1.0)
		spec["foundation"] = 0.6
		return place(Buildings.house(spec), parent, p, StarterIsland.face_yaw(face), r, low - top)
	spec["foundation"] = top - low + 0.8
	return place(Buildings.house(spec), parent, p, StarterIsland.face_yaw(face), r)


## A treasure chest (LootBag) with `items` ([id or ItemData, count]); `key` names it in the save.
func strongbox(parent: Node3D, p: Vector2, yaw: float, key: String, items: Array, size: float = 1.15, y_offset: float = 0.0) -> LootBag:
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var stacks: Array[ItemStack] = []
	for e in items:
		var st := ItemStack.new()
		st.item = e[0] if e[0] is ItemData else ItemDB.get_item(str(e[0]))
		st.quantity = int(e[1])
		stacks.append(st)
	bag.setup(stacks)
	bag.save_id = save_key(key)
	place(bag, parent, p, yaw, 0.0, y_offset)
	var chest_mesh := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	chest_mesh.mesh = Props.treasure_chest_mesh()
	chest_mesh.position = Vector3.ZERO
	chest_mesh.scale = Vector3.ONE * size
	return bag


## A name for something of this island in the save (chests opened, ...).
func save_key(key: String) -> String:
	return "isle%d_%s" % [int(node["id"]), key]


## World faces of the ground within `r` of world point `c` (the nav baker's ground for a site).
func terrain_faces(c: Vector3, r: float) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var lc := c - global_position
	var o := global_position
	var x0 := clampi(int(floor((lc.x - r + half) / CELL)), 0, res - 1)
	var x1 := clampi(int(ceil((lc.x + r + half) / CELL)), 0, res - 1)
	var z0 := clampi(int(floor((lc.z - r + half) / CELL)), 0, res - 1)
	var z1 := clampi(int(ceil((lc.z + r + half) / CELL)), 0, res - 1)
	for iz in range(z0, z1):
		for ix in range(x0, x1):
			var tl := o + Vector3(-half + ix * CELL, _h(ix, iz), -half + iz * CELL)
			var tr := o + Vector3(-half + (ix + 1) * CELL, _h(ix + 1, iz), -half + iz * CELL)
			var bl := o + Vector3(-half + ix * CELL, _h(ix, iz + 1), -half + (iz + 1) * CELL)
			var br := o + Vector3(-half + (ix + 1) * CELL, _h(ix + 1, iz + 1), -half + (iz + 1) * CELL)
			faces.append(tl); faces.append(tr); faces.append(bl)
			faces.append(tr); faces.append(br); faces.append(bl)
	return faces


# ==========================================================================
# Arrival
# ==========================================================================
func _add_arrival_zone() -> void:
	var area := Area3D.new()
	area.name = "ArrivalZone"
	area.collision_layer = 0
	area.collision_mask = 2  # PlayerBody
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius + 30.0
	cs.shape = sph
	area.add_child(cs)
	add_child(area)
	var blurb: String = Chain.THEMES[theme]["blurb"]
	area.body_entered.connect(func(b: Node3D):
		if b.is_in_group("player") and b.get("is_local"):
			get_tree().call_group("hud", "show_banner", island_name, "%s  (Lv %d)" % [blurb.capitalize(), int(node["level"])], true))
