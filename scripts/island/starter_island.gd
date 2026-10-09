class_name StarterIsland
extends Island
## Brinehollow — the hand-designed starter island.
##
## Everything is generated from code so it is easy to tweak:
##   * terrain: a 630 m chunk at 3 m resolution with a designed height function
##     (village plateau, lighthouse hill, jungle highlands, a sheltered cove,
##     the deep forest to the west, a broad beach to the north-west)
##   * per-vertex splat painting for dirt paths / sand / grass
##   * buildings, props, vegetation (MultiMesh), NPCs, loot and ambience
##
## Layout (local coordinates, -Z is north / towards the dock):
##   Village square  (0, -62)      Training yard (-58, -38)
##   Lighthouse hill (78, -30)     Jungle ruins  (-62, 58)
##   Castaway cove   (78, 92)      Dock: north shore, straight out from the village
##   Deep forest   (-125, 70)      Bug queen's cave (-150, 45)
##   Pirate den   (-112, -112) on the north-west beach

const EXTENT := 630.0
const CELL := 3.0
const RES := 210
const HALF := EXTENT * 0.5
## Ships keep out of these circles ([centre, radius], island space): the old
## island, the western lobes and the two long points.
const NO_GO := [[Vector2(0, 0), 225.0], [Vector2(-100, 5), 225.0], [Vector2(-120, 220), 75.0], [Vector2(-100, -215), 70.0]]
## The land fits inside this far from the centre (navmesh bake).
const LAND_R := 305.0
const WATER := 0.0
const SEAFLOOR := -26.0

const VILLAGE := Vector2(0, -62)
const TRAINING := Vector2(-58, -38)
const HILL := Vector2(78, -30)
const RUINS := Vector2(-62, 58)
const COVE := Vector2(80, 94)
const CAMP := Vector2(65, 76)
const JUNGLE_HIGH := Vector2(-48, 40)
const JUNGLE_STASH := Vector2(-92, 14)
## Smugglers' camp on the low shore south-west of the cove.
const SMUGGLERS := Vector2(46, 110)
const FOREST := Vector2(-125, 70)
const CAVE := Vector2(-150, 45)
const DEN := Vector2(-112, -112)

## The harbour pier: from the sea wall out to its head (the ship lies alongside).
const DOCK_LENGTH := 28.0
const PIER_HW := 3.0
## Wooden piers' deck height (the den's, the harbour's side piers).
const DOCK_DECK_Y := 1.7

var heights := PackedFloat32Array()
var paths: Array = []        # Array of PackedVector2Array (smoothed)
var path_widths: Array = []  # half widths
var path_bounds: Array = []  # Rect2 per path (grown by width)
var exclusions: Array = []   # [Vector2 center, float radius]

var dock_shore := Vector2.ZERO
var dock_dir := Vector2(0, -1)
var player_spawn_local := Vector3.ZERO

var _coast_noise := FastNoiseLite.new()
var _roll_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
## Bays and headlands: shifts the coast in and out across the map.
var _shape_noise := FastNoiseLite.new()
var _flat_zones: Array = []  # [Vector2 center, float target, float r_in, float r_out]
var _rng := RandomNumberGenerator.new()
var _tree_colliders: StaticBody3D


# ==========================================================================
# Entry point
# ==========================================================================
## Build the whole island. Call after the node is inside the tree.
func build(world_seed: int) -> Dictionary:
	island_name = "Brinehollow"
	island_type = "town"
	_rng.seed = world_seed + 1337
	_setup_noise(world_seed)
	_setup_flat_zones()
	_setup_port()
	dock_shore = _quay_pt(0.0, 0.0)
	_define_paths()
	_generate_heights()
	_build_terrain()

	_tree_colliders = StaticBody3D.new()
	_tree_colliders.name = "VegetationColliders"
	_tree_colliders.collision_layer = 1
	_tree_colliders.collision_mask = 0
	add_child(_tree_colliders)

	_build_dock()
	_build_village()
	_build_port()
	_build_training_yard()
	_build_lighthouse()
	_build_ruins()
	_build_cove()
	_build_beach_camp()
	_build_scuttlebugs()
	_build_smugglers_camp()
	_build_den()
	_build_cave()
	_scatter_vegetation()
	_build_spitters()
	_spawn_npcs()
	_spawn_loot()
	_add_arrival_zone()

	# the ship lies alongside the pier's head, against its fender
	var dock_end := _dock_point(DOCK_LENGTH - 4.0)
	var side := Vector3(-dock_dir.y, 0, dock_dir.x)
	return {
		"island": self,
		"dock_world_pos": to_global(Vector3(dock_end.x, 0, dock_end.y) + side * (PIER_HW + 4.4 + 0.5)),
		"dock_outward": Vector3(dock_dir.x, 0, dock_dir.y),
		"player_spawn": to_global(player_spawn_local),
	}


# ==========================================================================
# Height function
# ==========================================================================
func _setup_noise(world_seed: int) -> void:
	_coast_noise.seed = world_seed + 11
	_coast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast_noise.frequency = 0.02
	_coast_noise.fractal_octaves = 3
	_roll_noise.seed = world_seed + 23
	_roll_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_roll_noise.frequency = 0.018
	_roll_noise.fractal_octaves = 3
	_shape_noise.seed = world_seed + 53
	_shape_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_shape_noise.frequency = 0.0065
	_shape_noise.fractal_octaves = 3
	_detail_noise.seed = world_seed + 37
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.09
	_detail_noise.fractal_octaves = 2


static func _gauss(p: Vector2, c: Vector2, sigma: float) -> float:
	return exp(-p.distance_squared_to(c) / (2.0 * sigma * sigma))


static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Extra coast by bearing: x = the forest lobe (west/south-west), y = the beach
## lobe (north-west). The old coast (dock, cliffs, cove) gets none.
static func _coast_extra(ang: float) -> Vector2:
	var forest := 1.0 - _smooth(30.0, 70.0, _bearing_off(ang, 160.0))
	var beach := 1.0 - _smooth(18.0, 42.0, _bearing_off(ang, -138.0))
	return Vector2(85.0 * forest, 62.0 * beach)


## How freely the coast wanders by bearing: held still by the dock and along
## the cove and the smugglers' shore.
static func _wild(ang: float) -> float:
	return _smooth(10.0, 30.0, _bearing_off(ang, -90.0)) * _smooth(12.0, 32.0, _bearing_off(ang, 57.0))


## Degrees between bearing `ang` (radians) and `deg`.
static func _bearing_off(ang: float, deg: float) -> float:
	return absf(rad_to_deg(angle_difference(ang, deg_to_rad(deg))))


## Points and bays by bearing (metres added to the coast): the forest point to
## the south-west, a spit sheltering the den's beach, a rocky spit past the
## lighthouse, bays biting into the west and south coasts.
static func _capes(ang: float) -> float:
	return 70.0 * (1.0 - _smooth(2.0, 15.0, _bearing_off(ang, 118.0))) \
		+ 42.0 * (1.0 - _smooth(2.0, 11.0, _bearing_off(ang, -114.0))) \
		+ 34.0 * (1.0 - _smooth(2.0, 10.0, _bearing_off(ang, -52.0))) \
		- 48.0 * (1.0 - _smooth(4.0, 16.0, _bearing_off(ang, 190.0))) \
		- 34.0 * (1.0 - _smooth(4.0, 15.0, _bearing_off(ang, 96.0)))


## Land kept round these places whatever the bays do: [centre, radius].
const LAND_KEEP := [[VILLAGE, 52.0], [TRAINING, 30.0], [HILL, 22.0], [RUINS, 30.0], [JUNGLE_STASH, 16.0],
	[CAVE, 52.0], [DEN, 26.0], [FOREST, 40.0]]


## How much of the broad north-west beach `p` is on (0..1).
func _beach_lobe(p: Vector2) -> float:
	return _coast_extra(atan2(p.y, p.x)).y / 62.0


## Natural terrain before flattening.
func _height_natural(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.length()
	var ang := atan2(z, x)
	var ext := _coast_extra(ang)
	var r := 126.0 + _coast_noise.get_noise_2d(cos(ang) * 50.0, sin(ang) * 50.0) * 16.0 + maxf(ext.x, ext.y) + _capes(ang)
	var t := d - r + _shape_noise.get_noise_2d(x, z) * 34.0 * _wild(ang)
	for k in LAND_KEEP:
		t = minf(t, p.distance_to(k[0]) - float(k[1]))
	var bw := ext.y / 62.0
	var h: float
	if t < 0.0:
		h = lerpf(0.5, 4.3, pow(clampf(-t / (44.0 + 46.0 * bw), 0.0, 1.0), 0.85))
	else:
		h = lerpf(0.5, SEAFLOOR, _smooth(0.0, 60.0, t))
	var inland := clampf(-t / 35.0 - 0.15, 0.0, 1.0)
	h += _roll_noise.get_noise_2d(x, z) * 2.6 * inland * (1.0 - 0.6 * bw)
	h += _detail_noise.get_noise_2d(x, z) * 0.45 * inland
	# jungle highlands to the south-west, rolling forest hills past them
	h += 5.5 * _gauss(p, JUNGLE_HIGH, 38.0) * inland
	h += 4.0 * _gauss(p, FOREST, 42.0) * inland
	# lighthouse hill (falls into the sea as a cliff on the east side)
	h += 19.0 * _gauss(p, HILL, 23.0)
	return h


func _height_fn(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h := _height_natural(x, z)
	for zone in _flat_zones:
		var w := 1.0 - _smooth(zone[2], zone[3], p.distance_to(zone[0]))
		if w > 0.0:
			h = lerpf(h, zone[1], w)
	# carve the cove (a sheltered bay opening to the south-east)
	var g := 1.0 - _smooth(10.0, 32.0, p.distance_to(COVE))
	if g > 0.0:
		h = lerpf(h, -3.5, g)
	# level sandy shelf for the castaway camp on the cove beach
	var cw := 1.0 - _smooth(4.0, 9.0, p.distance_to(CAMP))
	if cw > 0.0:
		h = lerpf(h, 1.5, cw)
	# the harbour: ground under the quay kept low (the quay is built over it),
	# the waterfront behind it levelled to the quay's top
	if _port_ready:
		var pw := _port_x_weight(x)
		if pw > 0.0:
			var dz := z - _quay_z(x)
			if dz > -6.0 and dz < PLAT_D:
				h = lerpf(h, minf(h, QUAY_Y - 0.6), pw)
			elif dz >= PLAT_D:
				h = lerpf(h, QUAY_Y - 0.2, pw * (1.0 - _smooth(28.0, 38.0, dz)))
	return h


func _setup_flat_zones() -> void:
	_flat_zones = [
		[VILLAGE, _height_natural(VILLAGE.x, VILLAGE.y), 24.0, 40.0],
		[TRAINING, _height_natural(TRAINING.x, TRAINING.y), 12.0, 21.0],
		[HILL, _height_natural(HILL.x, HILL.y), 11.0, 17.0],
		[RUINS, _height_natural(RUINS.x, RUINS.y), 10.0, 18.0],
		[SMUGGLERS, maxf(_height_natural(SMUGGLERS.x, SMUGGLERS.y), 1.5), 11.0, 18.0],
		[CAVE, _height_natural(CAVE.x, CAVE.y), 30.0, 44.0],
		[DEN, 1.8, 24.0, 38.0],
	]


func _generate_heights() -> void:
	heights.resize((RES + 1) * (RES + 1))
	for iz in range(RES + 1):
		for ix in range(RES + 1):
			heights[iz * (RES + 1) + ix] = _height_fn(-HALF + ix * CELL, -HALF + iz * CELL)


func _h(ix: int, iz: int) -> float:
	ix = clampi(ix, 0, RES)
	iz = clampi(iz, 0, RES)
	return heights[iz * (RES + 1) + ix]


## Exact terrain height (matches the rendered triangles). Local coordinates.
func height_at(x: float, z: float) -> float:
	var fx := (x + HALF) / CELL
	var fz := (z + HALF) / CELL
	var ix := clampi(int(floor(fx)), 0, RES - 1)
	var iz := clampi(int(floor(fz)), 0, RES - 1)
	var u := clampf(fx - ix, 0.0, 1.0)
	var v := clampf(fz - iz, 0.0, 1.0)
	var h00 := _h(ix, iz)
	var h10 := _h(ix + 1, iz)
	var h01 := _h(ix, iz + 1)
	var h11 := _h(ix + 1, iz + 1)
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


## Where you stand at p: the terrain, or the quay's paving over it.
func hv(p: Vector2) -> float:
	if _port_ready and _on_platform(p):
		return QUAY_Y
	return height_at(p.x, p.y)


func walk_height(x: float, z: float) -> float:
	return hv(Vector2(x, z))


## The story's fights on this island, in world space ("smugglers", "den", "cave").
func place_of(place: String) -> Vector3:
	var p: Vector2 = {"smugglers": SMUGGLERS, "den": DEN, "cave": CAVE}[place]
	return to_global(Vector3(p.x, hv(p) + 1.5, p.y))


## Where a new captain wakes: on the sand just past the quay's west end, a
## couple of metres up from the waterline, head to the sea, facing the town.
## [world position, model yaw].
func wake_spot() -> Array:
	var x := port_x0 - 9.0
	var z := -96.0
	while z > -200.0 and height_at(x, z) > 0.9:
		z -= 0.5
	var p := Vector2(x, z + 2.5)
	return [to_global(Vector3(p.x, hv(p), p.y)), atan2(-0.45, -1.0)]


func _slope_at(p: Vector2) -> float:
	var e := 1.5
	var dx := height_at(p.x + e, p.y) - height_at(p.x - e, p.y)
	var dz := height_at(p.x, p.y + e) - height_at(p.x, p.y - e)
	var n := Vector3(-dx, 2.0 * e, -dz).normalized()
	return 1.0 - n.y


func _ground_max(c: Vector2, r: float) -> float:
	var m := hv(c)
	for i in range(8):
		var a := TAU * i / 8.0
		m = maxf(m, hv(c + Vector2(cos(a), sin(a)) * r))
	return m


func _ground_min(c: Vector2, r: float) -> float:
	var m := hv(c)
	for i in range(8):
		var a := TAU * i / 8.0
		m = minf(m, hv(c + Vector2(cos(a), sin(a)) * r))
	return m


# ==========================================================================
# Dock + paths
# ==========================================================================
## Along the harbour pier from its root at the sea wall (dock_shore).
func _dock_point(dist: float) -> Vector2:
	return dock_shore + dock_dir * dist


static func _catmull(pts: Array, sub: int = 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1):
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		for s in range(sub):
			var t := float(s) / sub
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _add_path(pts: Array, half_width: float) -> void:
	var smooth := _catmull(pts)
	paths.append(smooth)
	path_widths.append(half_width)
	var rect := Rect2(smooth[0], Vector2.ZERO)
	for q in smooth:
		rect = rect.expand(q)
	path_bounds.append(rect.grow(half_width + 4.0))


func _define_paths() -> void:
	var dock_root := dock_shore + Vector2(0, 2)
	_add_path([dock_root, Vector2(1, -100), Vector2(0, -84), VILLAGE + Vector2(0, -12)], 1.8)
	_add_path([VILLAGE + Vector2(-10, 4), Vector2(-30, -46), Vector2(-44, -40), TRAINING + Vector2(10, 0)], 1.4)
	_add_path([VILLAGE + Vector2(11, 3), Vector2(32, -52), Vector2(50, -44), Vector2(63, -36), HILL + Vector2(-6, 2)], 1.4)
	_add_path([VILLAGE + Vector2(-3, 14), Vector2(-10, -24), Vector2(-20, 2), Vector2(-34, 28), Vector2(-48, 46), RUINS + Vector2(6, -5)], 1.3)
	_add_path([VILLAGE + Vector2(4, 14), Vector2(16, -18), Vector2(32, 16), Vector2(46, 44), CAMP + Vector2(-2, -4)], 1.3)
	_add_path([VILLAGE + Vector2(0, 12), VILLAGE + Vector2(0, 16)], 1.6)
	# into the deep forest to the cave, and off the training path to the den
	_add_path([RUINS + Vector2(-9, 5), Vector2(-84, 64), Vector2(-104, 56), Vector2(-118, 47), CAVE + Vector2(29, 0)], 1.2)
	_add_path([Vector2(-44, -41), Vector2(-52, -56), Vector2(-72, -74), Vector2(-90, -92), DEN + Vector2(11, 11)], 1.3)


func _path_dist(p: Vector2) -> float:
	var best := 9999.0
	for i in range(paths.size()):
		if not (path_bounds[i] as Rect2).has_point(p):
			continue
		var pts: PackedVector2Array = paths[i]
		for j in range(pts.size() - 1):
			var a := pts[j]
			var b := pts[j + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t) - path_widths[i])
	return best


func _path_weight(p: Vector2) -> float:
	var d := _path_dist(p)
	return 1.0 - _smooth(-0.6, 0.6, d)


func _excluded(p: Vector2, pad: float = 0.0) -> bool:
	for e in exclusions:
		if p.distance_to(e[0]) < float(e[1]) + pad:
			return true
	return false


# ==========================================================================
# Terrain mesh
# ==========================================================================
func _disk(p: Vector2, c: Vector2, r_in: float, r_out: float) -> float:
	return 1.0 - _smooth(r_in, r_out, p.distance_to(c))


func _build_terrain() -> void:
	var n := (RES + 1) * (RES + 1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n)
	norms.resize(n)
	cols.resize(n)
	var dock_root := dock_shore
	for iz in range(RES + 1):
		for ix in range(RES + 1):
			var i := iz * (RES + 1) + ix
			var x := -HALF + ix * CELL
			var z := -HALF + iz * CELL
			var h := heights[i]
			verts[i] = Vector3(x, h, z)
			var dx := _h(ix - 1, iz) - _h(ix + 1, iz)
			var dz := _h(ix, iz - 1) - _h(ix, iz + 1)
			norms[i] = Vector3(dx, 2.0 * CELL, dz).normalized()
			var p := Vector2(x, z)
			var dirt := 0.0
			var sand := 0.0
			if h > -1.0:
				dirt = maxf(_path_weight(p), _disk(p, VILLAGE, 12.0, 17.0))
				dirt = maxf(dirt, _disk(p, TRAINING, 10.0, 13.0))
				dirt = maxf(dirt, _disk(p, RUINS, 8.0, 11.0))
				dirt = maxf(dirt, _disk(p, HILL, 5.0, 8.0))
				dirt = maxf(dirt, _disk(p, CAVE, 20.0, 25.0))
				# packed earth behind the quay, among the waterfront houses
				var pw := _port_x_weight(x)
				if pw > 0.0 and z - _quay_z(x) > PLAT_D - 1.0:
					dirt = maxf(dirt, pw * (1.0 - _smooth(22.0, 32.0, z - _quay_z(x))))
				dirt = maxf(dirt, _disk(p, dock_root, 3.0, 6.0) * 0.6)
				sand = 1.0 - _smooth(1.7, 2.8, h)
				sand = maxf(sand, _disk(p, CAMP, 4.0, 9.0))
				dirt *= 1.0 - _disk(p, CAMP, 0.0, 9.0)
				sand *= 1.0 - dirt
			cols[i] = Color(dirt, 0.0, sand, 1.0)
	var idx := PackedInt32Array()
	idx.resize(RES * RES * 6)
	var k := 0
	for iz in range(RES):
		for ix in range(RES):
			var tl := iz * (RES + 1) + ix
			var tr := tl + 1
			var bl := tl + (RES + 1)
			var br := bl + 1
			idx[k] = tl; idx[k + 1] = tr; idx[k + 2] = bl
			idx[k + 3] = tr; idx[k + 4] = br; idx[k + 5] = bl
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, PSXMat.terrain(true, WATER))

	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	var mi := MeshInstance3D.new()
	mi.name = "MeshInstance3D"
	mi.mesh = mesh
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


# ==========================================================================
# Placement helpers
# ==========================================================================
static func face_yaw(dir: Vector2) -> float:
	return atan2(dir.x, dir.y)


## Place a prop on the ground. `footprint` > 0 sits it on the highest point
## under its footprint and reserves the area from vegetation.
func place(node: Node3D, p: Vector2, yaw: float = 0.0, footprint: float = 0.0, y_offset: float = 0.0) -> Node3D:
	var y := _ground_max(p, footprint) if footprint > 0.0 else hv(p)
	node.position = Vector3(p.x, y + y_offset, p.y)
	node.rotation.y = yaw
	add_child(node)
	if footprint > 0.0:
		exclusions.append([p, footprint + 1.5])
	return node


func reserve(p: Vector2, r: float) -> void:
	exclusions.append([p, r])


func _local_point(node: Node3D, local: Vector3) -> Vector2:
	var w := node.transform * local
	return Vector2(w.x, w.z)


# ==========================================================================
# Structures
# ==========================================================================
var _tavern: Node3D
var _harbor: Node3D
var _smithy: Node3D
var _stall_a: Node3D
var _stall_b: Node3D
var _keeper_hut: Node3D

## The harbour pier: a stone jetty out from the sea wall, flush with the quay.
## Coping and bollards along both sides, a timber fender down the east side
## where the ship lies, ladders at the head, a lamp at the end.
func _build_dock() -> void:
	var body := StaticBody3D.new()
	body.name = "HarbourPier"
	body.collision_layer = 1
	body.collision_mask = 0
	var shell := MeshBuilder.new()
	var mb := MeshBuilder.new()
	var cob := PSXMat.lit("cobbles", Color.WHITE, {"affine": 0.6})
	var wall := PSXMat.lit("stone_brick", Color(0.85, 0.82, 0.76), {"affine": 0.6})
	var cope := PSXMat.lit("stone_brick", Color(0.7, 0.68, 0.64))
	var iron := PSXMat.lit("metal", Color(0.22, 0.22, 0.24))
	var wood := PSXMat.lit("planks_dark")
	var y := QUAY_Y
	var bottom := -5.0
	var x0 := dock_shore.x - PIER_HW
	var x1 := dock_shore.x + PIER_HW
	var z0 := dock_shore.y + 0.5
	var z1 := dock_shore.y - DOCK_LENGTH
	# the top in four lengths (small texture warp), the sides and the head
	for k in range(4):
		var za := lerpf(z0, z1, k / 4.0)
		var zb := lerpf(z0, z1, (k + 1) / 4.0)
		shell.add_quad(cob, Vector3(x0, y, za), Vector3(x1, y, za), Vector3(x1, y, zb), Vector3(x0, y, zb),
			Vector2(x0, za) * 0.4, Vector2(x1, za) * 0.4, Vector2(x1, zb) * 0.4, Vector2(x0, zb) * 0.4, Color.WHITE, Vector3.UP)
		for s in [-1.0, 1.0]:
			var x: float = dock_shore.x + s * PIER_HW
			shell.add_quad(wall, Vector3(x, y, za), Vector3(x, y, zb), Vector3(x, 0.4, zb), Vector3(x, 0.4, za),
				Vector2(za, 0) * 0.4, Vector2(zb, 0) * 0.4, Vector2(zb, 0.5), Vector2(za, 0.5), Color.WHITE, Vector3(s, 0, 0))
			shell.add_quad(wall, Vector3(x, 0.4, za), Vector3(x, 0.4, zb), Vector3(x, bottom, zb), Vector3(x, bottom, za),
				Vector2(za, 0.5), Vector2(zb, 0.5), Vector2(zb, 2.6), Vector2(za, 2.6), Color(0.55, 0.6, 0.55), Vector3(s, 0, 0))
	shell.add_quad(wall, Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, bottom, z1), Vector3(x0, bottom, z1),
		Vector2(x0, 0) * 0.4, Vector2(x1, 0) * 0.4, Vector2(x1, 2.6), Vector2(x0, 2.6), Color(0.85, 0.85, 0.85), Vector3.FORWARD)
	var shell_mesh := shell.commit()
	var shell_i := MeshInstance3D.new()
	shell_i.name = "PierShell"
	shell_i.mesh = shell_mesh
	shell_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(shell_i)
	var cs_shell := CollisionShape3D.new()
	cs_shell.shape = shell_mesh.create_trimesh_shape()
	body.add_child(cs_shell)
	# coping down both sides and across the head
	for s in [-1.0, 1.0]:
		var cx: float = dock_shore.x + s * (PIER_HW - 0.25)
		mb.add_box(cope, Transform3D(Basis(), Vector3(cx, y + 0.06, (z0 + z1) * 0.5)), Vector3(0.62, 0.18, z0 - z1), 0.8, Color.WHITE, false)
	mb.add_box(cope, Transform3D(Basis(), Vector3(dock_shore.x, y + 0.06, z1 + 0.25)), Vector3(PIER_HW * 2.0, 0.18, 0.62), 0.8, Color.WHITE, false)
	# bollards, both sides
	for d in [5.0, 12.0, 19.0, DOCK_LENGTH - 1.2]:
		for s in [-1.0, 1.0]:
			var q := _dock_point(d) + Vector2(s * (PIER_HW - 0.5), 0)
			mb.add_cylinder(iron, Transform3D(Basis(), Vector3(q.x, y + 0.1, q.y)), 0.16, 0.2, 0.42, 7, 1.0)
			mb.add_cylinder(iron, Transform3D(Basis(), Vector3(q.x, y + 0.52, q.y)), 0.24, 0.24, 0.07, 7, 1.0)
	# the timber fender where the ship lies (east side), a rubbing strake along it
	var fx := x1 + 0.12
	var fz := z1 + 1.0
	while fz < dock_shore.y - 6.0:
		mb.add_box(wood, Transform3D(Basis(), Vector3(fx, (y - 0.6) * 0.5 + 0.1, fz)), Vector3(0.24, y + 0.6, 0.26), 1.0)
		fz += 1.6
	mb.add_box(wood, Transform3D(Basis(), Vector3(fx + 0.1, y - 0.25, (z1 + dock_shore.y - 6.0) * 0.5)), Vector3(0.16, 0.22, dock_shore.y - 6.0 - z1), 1.0, Color.WHITE, false)
	var dressing := mb.to_instance("PierDressing")
	body.add_child(dressing)
	add_child(body)
	# ladders for swimmers: at the head and down the west side
	for spec in [[_dock_point(DOCK_LENGTH), Vector2(0, -1)], [_dock_point(DOCK_LENGTH - 4.0) - Vector2(PIER_HW, 0), Vector2(-1, 0)],
			[_dock_point(9.0) - Vector2(PIER_HW, 0), Vector2(-1, 0)]]:
		var at: Vector2 = spec[0]
		var lad := Ladder.new()
		lad.length = QUAY_Y + 1.2
		lad.rail = 0.0
		lad.deck_depth = 0.9
		lad.position = Vector3(at.x, QUAY_Y, at.y)
		lad.rotation.y = face_yaw(spec[1])
		add_child(lad)
	for d in range(0, int(DOCK_LENGTH) + 4, 4):
		reserve(_dock_point(d), PIER_HW + 0.5)
	# lamps at the head and halfway, cargo waiting to go aboard
	for lp in [[_dock_point(DOCK_LENGTH - 0.9) - Vector2(PIER_HW - 0.6, 0), true], [_dock_point(13.0) - Vector2(PIER_HW - 0.6, 0), false]]:
		var post := place(Props.lantern_post(), lp[0], face_yaw(Vector2(1, 0)) - PI * 0.5)
		if lp[1]:
			var nl := NightLight.make(Color(1.0, 0.75, 0.42), 1.6, 10.0)
			nl.position = Vector3(0.55, 2.0, 0.0)
			post.add_child(nl)
	place(Props.barrel(), _dock_point(15.0) + Vector2(-1.6, 0.2), 0.0)
	place(Props.barrel(), _dock_point(15.6) + Vector2(-1.9, -0.5), 0.0)
	place(Props.crate(0.8), _dock_point(16.6) + Vector2(-1.5, 0), 0.3)
	place(Props.rope_coil(), _dock_point(DOCK_LENGTH - 2.5) + Vector2(1.8, 0))
	place(Props.rope_coil(), _dock_point(10.0) + Vector2(1.9, 0))
	# docking area (board the ship) at the end of the dock
	var area := Interactable.new()
	area.name = "DockingArea"
	area.collision_layer = 512
	area.collision_mask = 0
	area.prompt_text = "Board ship"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 4.0
	cs.shape = sph
	area.add_child(cs)
	area.position = _v3(_dock_point(DOCK_LENGTH - 2.0)) + Vector3(0, QUAY_Y + 1.0, 0)
	add_child(area)
	player_spawn_local = _v3(dock_shore - dock_dir * 4.0) + Vector3(0, hv(dock_shore - dock_dir * 4.0) + 1.0, 0)


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0, p.y)


func _build_village() -> void:
	place(Props.well(), VILLAGE, 0.0, 1.6)
	reserve(VILLAGE, 13.0)  # keep the plaza clear of rocks and bushes

	# the tavern: walk in through the door on the plaza side
	_tavern = place(Buildings.tavern_hall(), VILLAGE + Vector2(-24, -2), face_yaw(Vector2(1, 0)), 8.0)
	reserve(_marker_point(_tavern, "Door"), 3.0)
	# a couple of tables outside for fine evenings
	for off in [Vector2(-12.5, -8.0), Vector2(-12.5, 5.0)]:
		var tp: Vector2 = VILLAGE + off
		place(Props.table(), tp, 0.0, 1.0)
		place(Props.bench(), tp + Vector2(0, 1.0), 0.0)
		place(Props.bench(), tp + Vector2(0, -1.0), 0.0)
	place(Props.barrel(), VILLAGE + Vector2(-16.5, -10.5), 0.0)
	place(Props.barrel(), VILLAGE + Vector2(-17.3, -9.8), 0.0)

	# houses: every one a different shape
	_house({"w": 6.0, "d": 5.0, "floors": 2, "wall": "plaster", "wall2": "plaster", "roof": "gable_front",
		"roof_tex": "roof_tiles", "chimney": true, "pitch": 0.55}, VILLAGE + Vector2(23, -3), Vector2(-1, 0))
	_house({"w": 7.0, "d": 5.0, "roof": "hip", "wall": "planks", "roof_tex": "roof_tiles", "porch": 1.8, "door_x": -1.5},
		VILLAGE + Vector2(-20, 20), Vector2(1, -0.5))
	_house({"w": 4.5, "d": 4.0, "h": 2.4, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch",
		"lean_to": "right", "chimney": true}, VILLAGE + Vector2(-17, -25), Vector2(1, 0.3))
	_harbor = _house({"w": 9.0, "d": 5.5, "h": 3.0, "roof": "shed", "wall": "planks_weathered", "roof_tex": "roof_tiles",
		"porch": 1.6, "sign": "sign_fish", "door_x": 2.0, "name": "Harbor", "lamp_light": true}, VILLAGE + Vector2(15, -28), Vector2(-1, 0))
	_house({"w": 4.0, "d": 4.5, "floors": 2, "wall": "stone_brick", "wall2": "planks", "roof": "gable",
		"roof_tex": "thatch", "pitch": 0.75, "jetty": 0.3}, VILLAGE + Vector2(-9, -31), Vector2(1, 0.2))
	_house({"w": 5.5, "d": 4.5, "h": 2.5, "roof": "hip", "wall": "plaster", "roof_tex": "thatch", "lean_to": "left", "pitch": 0.5},
		VILLAGE + Vector2(27, 12), Vector2(-1, -0.4))
	_build_market()

	place(Props.signpost([PI, 0.0, PI * 0.75, PI * 0.25]), VILLAGE + Vector2(2.5, 17), 0.0, 0.6)

	# the smithy, the sea chapel, the harbour warehouse and two more houses
	_smithy = place(Buildings.smithy(), Vector2(-38, -78), face_yaw(Vector2(1, 0.25)), 4.6)
	place(Buildings.chapel(), Vector2(42, -82), face_yaw(Vector2(-1, 0.35)), 6.2)
	var wh := _house({"w": 9.0, "d": 6.0, "h": 3.6, "roof": "gable", "wall": "planks_weathered", "roof_tex": "roof_tiles", "door_x": -2.2,
		"name": "Warehouse", "flowers": false, "trim": Color(0.55, 0.5, 0.45), "lamp_light": true, "pitch": 0.38}, Vector2(20, -106), Vector2(-1, 0))
	for k in range(4):
		var cp := _local_point(wh, Vector3(1.0 + (k % 2) * 1.0, 0, 4.0 + (k / 2) * 0.9))
		place(Props.crate(0.75 + 0.1 * (k % 2)), cp, 0.3 * k, 0.0)
	place(Props.barrel(), _local_point(wh, Vector3(3.6, 0, 3.6)))
	place(Props.barrel(), _local_point(wh, Vector3(4.1, 0, 4.2)))
	_house({"w": 5.5, "d": 4.5, "floors": 2, "wall": "plaster", "wall2": "planks", "roof": "gable", "roof_tex": "thatch",
		"chimney": true, "jetty": 0.3, "trim": Buildings.TRIM_COLORS[0]}, Vector2(-30, -100), Vector2(1, 0.4))
	_house({"w": 6.0, "d": 4.5, "h": 2.5, "roof": "hip", "wall": "stone_brick", "roof_tex": "roof_tiles", "porch": 1.5,
		"chimney": true}, Vector2(-30, -24), Vector2(0.7, -1))
	_dress_village()

	# lantern posts along the main road
	var main: PackedVector2Array = paths[0]
	for i in range(3, main.size(), 5):
		var a := main[i]
		var b := main[mini(i + 1, main.size() - 1)]
		var tangent := (b - a).normalized()
		var side := Vector2(-tangent.y, tangent.x) * (2.9 if i % 2 == 0 else -2.9)
		var lp := place(Props.lantern_post(), a + side, face_yaw(-side), 0.4)
		lp.rotation.y = face_yaw(-side) - PI * 0.5


const MARKET := Vector2(13, -49)  # = VILLAGE + (13, 13)


## Place a Buildings.house on the ground. Its stone footing reaches down to
## the lowest ground under it (or it stands on stilts), so nothing floats on
## a slope.
func _house(spec: Dictionary, p: Vector2, face: Vector2, on_stilts: bool = false) -> Node3D:
	var r := maxf(float(spec.get("w", 6.0)), float(spec.get("d", 5.0))) * 0.6
	var top := _ground_max(p, r)
	var low := _ground_min(p, r)
	if on_stilts:
		spec["stilts"] = maxf(top - low + 0.6, 1.0)
		spec["foundation"] = 0.6
		return place(Buildings.house(spec), p, face_yaw(face), r, low - top)
	spec["foundation"] = top - low + 0.8
	return place(Buildings.house(spec), p, face_yaw(face), r)


## Island-space point of a named Marker3D inside a placed prop.
func _marker_point(node: Node3D, marker: String) -> Vector2:
	var m := node.get_node_or_null(marker) as Node3D
	return _local_point(node, m.position if m else Vector3.ZERO)


func _marker_y(node: Node3D, marker: String) -> float:
	var m := node.get_node_or_null(marker) as Node3D
	return (node.transform * (m.position if m else Vector3.ZERO)).y


## Facing (as a direction) of a named marker inside a placed prop.
func _marker_face(node: Node3D, marker: String) -> Vector2:
	var m := node.get_node_or_null(marker) as Node3D
	var yaw := node.rotation.y + (m.rotation.y if m else 0.0)
	return Vector2(sin(yaw), cos(yaw))


var _stall_fish: Node3D
var _stall_pots: Node3D
var _stall_cloth: Node3D


## A small market square: four different stalls in a horseshoe opening toward
## the plaza, a planter in the middle, goods stacked around.
func _build_market() -> void:
	var to_plaza := (VILLAGE - MARKET).normalized()
	var base := atan2(to_plaza.y, to_plaza.x)
	var kinds := ["fruit", "fish", "cloth", "pots"]
	var stalls: Array = []
	for i in range(4):
		var a := base + deg_to_rad(70.0 + i * 73.0)
		var sp := MARKET + Vector2(cos(a), sin(a)) * 6.2
		stalls.append(place(Buildings.stall(kinds[i]), sp, face_yaw(MARKET - sp), 2.2))
	_stall_a = stalls[0]
	_stall_fish = stalls[1]
	_stall_cloth = stalls[2]
	_stall_pots = stalls[3]
	_stall_b = _stall_cloth
	place(Buildings.planter(0.7), MARKET, 0.0, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	# wares laid out on rugs between the stalls, sacks and baskets heaped by them
	var gmb := MeshBuilder.new()
	var rugs := [PSXMat.lit("cloth_red", Color(0.9, 0.8, 0.75), {"affine": 0.6}), PSXMat.lit("cloth_blue", Color(0.9, 0.9, 0.85), {"affine": 0.6})]
	var basket := PSXMat.lit("straw")
	var sack := PSXMat.lit("canvas", Color(0.82, 0.74, 0.56))
	var goods := [Color(0.9, 0.55, 0.1), Color(0.85, 0.15, 0.12), Color(0.95, 0.85, 0.2), Color(0.45, 0.7, 0.2), Color(0.55, 0.35, 0.2)]
	for i in range(4):
		var a := base + deg_to_rad(106.0 + i * 73.0)
		var gp := MARKET + Vector2(cos(a), sin(a)) * 5.4
		if i < 3:
			var gy := hv(gp) + 0.06
			var r: Material = rugs[i % 2]
			var e1 := Vector2(cos(a), sin(a)) * 0.7
			var e2 := Vector2(-sin(a), cos(a)) * 1.0
			var v := func(q: Vector2) -> Vector3: return Vector3(q.x, gy, q.y)
			gmb.add_quad(r, v.call(gp - e1 - e2), v.call(gp + e1 - e2), v.call(gp + e1 + e2), v.call(gp - e1 + e2), Vector2.ZERO, Vector2(1, 0), Vector2(1, 1.4), Vector2(0, 1.4), Color.WHITE, Vector3.UP)
			for k in range(3):
				var bp := gp + e2 * (k - 1) * 0.6
				gmb.add_cylinder(basket, Transform3D(Basis(), Vector3(bp.x, gy, bp.y)), 0.2, 0.24, 0.2, 7, 1.0)
				var fm := PSXMat.flat(goods[(i + k) % goods.size()])
				for f in range(4):
					gmb.add_blob(fm, Transform3D(Basis(), Vector3(bp.x + rng.randf_range(-0.1, 0.1), gy + 0.24 + (f / 2) * 0.06, bp.y + rng.randf_range(-0.1, 0.1))), Vector3.ONE * 0.07, rng, 0.15, 2, 4, 1.0)
		var sp := MARKET + Vector2(cos(a + 0.25), sin(a + 0.25)) * 8.2
		for k in range(2):
			gmb.add_blob(sack, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(sp.x + k * 0.5, hv(sp) + 0.28, sp.y + (k % 2) * 0.3)), Vector3(0.3, 0.32, 0.26), rng, 0.2, 3, 6)
	add_child(gmb.to_instance("Wares"))
	for i in range(6):
		var a := rng.randf() * TAU
		var q := MARKET + Vector2(cos(a), sin(a)) * rng.randf_range(8.0, 9.5)
		if _path_dist(q) < 2.5:
			continue
		place(Props.crate(rng.randf_range(0.55, 0.8)) if i % 2 == 0 else Props.barrel(), q, rng.randf() * TAU, 0.6)
	reserve(MARKET, 9.0)


# ==========================================================================
# The harbour: a stone quay along the shore either side of the dock, piers
# with trading ships tied up, waterfront houses and shops, the harbour tower
# ==========================================================================
## The quay's top, its depth from the sea wall inland, the town street behind.
const QUAY_Y := 1.62
const QUAY_W := 11.0
const STREET_W := 4.5
## The paved platform's whole depth (quay and street), a curb at its back.
const PLAT_D := QUAY_W + STREET_W
var _port_ready := false
var _quay_x := PackedFloat32Array()
var _quay_zs := PackedFloat32Array()
var port_x0 := 0.0
var port_x1 := 0.0


## Where the quay runs: the shoreline either side of the dock, as far as it
## stays fairly straight (it stops where the coast turns away), smoothed.
func _setup_port() -> void:
	var step := 2.0
	var xs: Array = []
	var zs: Array = []
	for i in range(-34, 37):
		var x := i * step
		var z := -96.0
		while z > -200.0 and _height_fn(x, z) > 0.6:
			z -= 0.5
		xs.append(x)
		zs.append(z)
	var mid := 34
	var lo := mid
	var hi := mid
	while lo > 0 and absf(float(zs[lo - 1]) - float(zs[lo])) < 5.0 and absf(float(zs[lo - 1]) - float(zs[mid])) < 40.0:
		lo -= 1
	while hi < xs.size() - 1 and absf(float(zs[hi + 1]) - float(zs[hi])) < 5.0 and absf(float(zs[hi + 1]) - float(zs[mid])) < 40.0:
		hi += 1
	# a few metres in from the turn
	lo = mini(lo + 2, mid)
	hi = maxi(hi - 2, mid)
	for pass_i in range(3):
		var sm: Array = zs.duplicate()
		for i in range(lo, hi + 1):
			sm[i] = (float(zs[maxi(i - 1, lo)]) + float(zs[i]) * 2.0 + float(zs[mini(i + 1, hi)])) * 0.25
		zs = sm
	for i in range(lo, hi + 1):
		_quay_x.append(float(xs[i]))
		_quay_zs.append(float(zs[i]) - 2.0)
	port_x0 = _quay_x[0]
	port_x1 = _quay_x[_quay_x.size() - 1]
	_port_ready = true


## The sea wall's line at x (island space).
func _quay_z(x: float) -> float:
	var f := clampf((x - _quay_x[0]) / 2.0, 0.0, float(_quay_x.size() - 1))
	var i := mini(int(f), _quay_x.size() - 2)
	return lerpf(_quay_zs[i], _quay_zs[i + 1], f - i)


## On the quay's paving (quay and street), or out on the harbour pier?
func _on_platform(p: Vector2) -> bool:
	if absf(p.x - dock_shore.x) <= PIER_HW and p.y <= dock_shore.y + 0.5 and p.y >= dock_shore.y - DOCK_LENGTH:
		return true
	if p.x < port_x0 or p.x > port_x1:
		return false
	var dz := p.y - _quay_z(p.x)
	return dz >= 0.0 and dz <= PLAT_D


func _port_x_weight(x: float) -> float:
	return _smooth(port_x0 - 6.0, port_x0, x) * (1.0 - _smooth(port_x1, port_x1 + 6.0, x))


## The point `inland` metres in from the sea wall at x.
func _quay_pt(x: float, inland: float) -> Vector2:
	return Vector2(x, _quay_z(x) + inland)


func _build_port() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7007
	_build_quay(rng)
	_build_harbour_front(rng)
	# piers, each with its ship (x, length, ship kind, ship on the +x side?)
	var piers := [[-32.0, 24.0, "junk", false], [30.0, 26.0, "merchant", true], [46.0, 20.0, "sloop", true]]
	for pr in piers:
		var px: float = pr[0]
		if px < port_x0 + 4.0 or px > port_x1 - 2.0:
			continue
		var root := _quay_pt(px, 1.0)
		var out := Vector2(0, -1)
		var pier := Props.dock(float(pr[1]), 3.0, DOCK_DECK_Y, SEAFLOOR * 0.5)
		pier.position = Vector3(root.x, 0.0, root.y)
		pier.rotation.y = face_yaw(out)
		add_child(pier)
		var lad := Ladder.new()
		lad.length = DOCK_DECK_Y + 1.0
		lad.deck_depth = 0.9
		lad.position = Vector3(0, DOCK_DECK_Y, float(pr[1]))
		pier.add_child(lad)
		var side := 1.0 if pr[3] else -1.0
		var sp := root + out * (float(pr[1]) - 10.0) + Vector2(side * (1.5 + HullBuilder.HALF_BEAM + 0.7), 0)
		var hull := MooredHull.new()
		hull.name = "Moored_" + str(pr[2])
		hull.collision_layer = 1
		hull.collision_mask = 0
		hull.position = Vector3(sp.x, HullBuilder.FREEBOARD, sp.y)
		hull.rotation.y = face_yaw(-out)
		add_child(hull)
		match str(pr[2]):
			"junk":
				TraderShips.junk(hull)
			"merchant":
				TraderShips.merchantman(hull)
			_:
				TraderShips.sloop(hull)
		for k in range(3):
			var rc := Props.rope_coil() if k != 1 else Props.barrel()
			rc.position = Vector3(0, DOCK_DECK_Y, 0) + _v3(root + out * (6.0 + k * 6.0) + Vector2(side * 1.0, 0))
			add_child(rc)
	# longboats tied along the quay west of the dock
	for lx in [-13.0, -21.0]:
		if lx < port_x0 + 3.0:
			continue
		var q := _quay_pt(lx, -2.4)
		var boat := MooredHull.new()
		boat.name = "Longboat"
		boat.freeboard = 0.15
		boat.half_len = 2.4
		boat.collision_layer = 1
		boat.collision_mask = 0
		boat.position = Vector3(q.x, 0.15, q.y)
		boat.rotation.y = face_yaw(Vector2(1, 0.05))
		add_child(boat)
		TraderShips.longboat(boat)
	# the harbour tower at the east end, a crane at the merchantman's pier
	var tp := _quay_pt(port_x1 - 4.0, 8.0)
	place(Buildings.harbor_tower(), tp, face_yaw(Vector2(-0.6, 1)), 3.4)
	if port_x1 > 34.0:
		place(Buildings.dock_crane(), _quay_pt(25.5, 3.0), face_yaw(Vector2(0, -1)), 1.2)
	_build_waterfront(rng)
	_dress_quay(rng)


## Where the harbour's people work, set out round the pier's root: Odile's
## booth beside it, Tackett's yard (a boat on the stocks) to the east, old
## Pell mending nets on the quay edge to the west by his net loft.
var odile_at := Vector2.ZERO
var odile_face := Vector2.ZERO
var tackett_at := Vector2.ZERO
var pell_at := Vector2.ZERO

func _build_harbour_front(rng: RandomNumberGenerator) -> void:
	var r := dock_shore
	# the harbourmaster's booth, facing the pier
	var booth := place(_harbour_booth(), r + Vector2(-5.2, 4.0), face_yaw(Vector2(1, 0)), 1.6)
	odile_at = _marker_point(booth, "Keeper")
	odile_face = Vector2(1, 0)
	place(Props.crate(0.7), r + Vector2(-5.0, 6.4), 0.4, 0.6)
	place(Props.barrel(), r + Vector2(-6.2, 6.6), 0.0, 0.5)
	# Tackett's yard: a boat on the stocks, timber, sawhorses, his bench
	place(_boat_on_stocks(), r + Vector2(11.0, 7.5), face_yaw(Vector2(1, 0)), 4.6)
	var tmb := MeshBuilder.new()
	var timber := PSXMat.lit("planks", Color(0.95, 0.85, 0.7))
	var bark := PSXMat.lit("bark")
	for sx in [-1.2, 1.2]:
		tmb.add_box(bark, Transform3D(Basis(), Vector3(sx, 0.35, 0)), Vector3(0.15, 0.7, 1.0), 1.0)
	for i in range(5):
		tmb.add_box(timber, Transform3D(Basis(Vector3.UP, 0.04 * i), Vector3(0, 0.76 + i * 0.1, -0.3 + (i % 3) * 0.18)), Vector3(3.4, 0.09, 0.26), 1.0)
	place(tmb.to_instance("Timber"), r + Vector2(12.0, 12.6), 0.0, 1.9)
	var saw := MeshBuilder.new()
	for sx in [-0.8, 0.8]:
		for sz in [-1.0, 1.0]:
			Buildings.beam_between(saw, bark, Vector3(sx, 0.0, sz * 0.3), Vector3(sx, 0.7, 0.0), 0.07)
		saw.add_box(bark, Transform3D(Basis(), Vector3(sx, 0.72, 0)), Vector3(0.12, 0.1, 0.8), 1.0)
	saw.add_box(timber, Transform3D(Basis(Vector3.UP, 0.1), Vector3(0, 0.82, 0)), Vector3(2.6, 0.07, 0.3), 1.0, Color.WHITE, false)
	place(saw.to_instance("Sawhorses"), r + Vector2(6.8, 11.4), 0.2, 1.4)
	var bench := MeshBuilder.new()
	bench.add_box(timber, Transform3D(Basis(), Vector3(0, 0.85, 0)), Vector3(1.8, 0.1, 0.7), 1.0, Color.WHITE, false)
	for sx in [-0.8, 0.8]:
		for sz in [-0.28, 0.28]:
			bench.add_box(bark, Transform3D(Basis(), Vector3(sx, 0.42, sz)), Vector3(0.1, 0.85, 0.1), 1.0)
	var iron := PSXMat.lit("metal", Color(0.4, 0.4, 0.42))
	bench.add_box(iron, Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.4, 0.92, 0.05)), Vector3(0.55, 0.02, 0.14), 1.0)
	bench.add_box(bark, Transform3D(Basis(Vector3.UP, 0.3), Vector3(-0.12, 0.93, 0.13)), Vector3(0.14, 0.05, 0.06), 1.0)
	bench.add_box(bark, Transform3D(Basis(Vector3.UP, -0.5), Vector3(0.45, 0.93, -0.1)), Vector3(0.08, 0.05, 0.35), 1.0)
	bench.add_box(iron, Transform3D(Basis(Vector3.UP, -0.5), Vector3(0.52, 0.95, -0.25)), Vector3(0.16, 0.07, 0.07), 1.0)
	place(bench.to_instance("Workbench"), r + Vector2(17.4, 6.5), face_yaw(Vector2(-1, 0)), 1.2)
	tackett_at = r + Vector2(5.6, 5.0)
	# Pell's corner: his bench at the quay edge, nets, the upturned boat, the loft
	pell_at = r + Vector2(-12.5, 1.8)
	place(Props.bench(), pell_at, 0.0, 1.0)
	place(Props.net_pile(), pell_at + Vector2(1.6, 0.6), 0.0)
	place(Props.net_pile(), pell_at + Vector2(-1.4, 1.0), 1.1)
	place(Props.upturned_boat(), r + Vector2(-17.0, 6.0), 0.3, 2.0)
	place(Props.fish_rack(), r + Vector2(-9.5, 7.0), face_yaw(Vector2(1, 0)), 1.5)
	_house({"w": 5.0, "d": 4.0, "h": 2.4, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch", "porch": 1.4,
		"flowers": false, "name": "NetLoft"}, r + Vector2(-23.0, 10.5), Vector2(0, -1))
	for k in range(5):
		var fp := r + Vector2(-20.5 + k * 0.5, 7.9)
		var mb := MeshBuilder.new()
		mb.add_blob(PSXMat.flat(Color(0.9, 0.55, 0.2) if k % 2 == 0 else Color(0.85, 0.85, 0.8)), Transform3D(), Vector3.ONE * 0.12, rng, 0.1, 2, 5)
		place(mb.to_instance("Float"), fp, 0.0, 0.0, 0.1)


## Odile's booth: a counter under a canvas awning, the harbour ledger and a
## slate of ships in port. Front +Z; "Keeper" stands behind the counter.
func _harbour_booth() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "HarbourBooth"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.55, 0.35)), Vector3(2.2, 1.1, 0.55), 1.0, Color.WHITE, true)
	mb.add_box(dark, Transform3D(Basis(), Vector3(0, 1.13, 0.38)), Vector3(2.4, 0.07, 0.75), 1.0, Color.WHITE, false)
	for x in [-1.15, 1.15]:
		for z in [-1.0, 0.65]:
			mb.add_box(dark, Transform3D(Basis(), Vector3(x, 1.2, z)), Vector3(0.1, 2.4, 0.1), 1.0)
	var canvas := PSXMat.lit("cloth_blue", Color.WHITE, {"affine": 0.6})
	mb.add_quad(canvas, Vector3(-1.35, 2.55, -1.15), Vector3(1.35, 2.55, -1.15), Vector3(1.35, 2.25, 0.95), Vector3(-1.35, 2.25, 0.95), Vector2.ZERO, Vector2(1.4, 0), Vector2(1.4, 1), Vector2(0, 1), Color.WHITE, Vector3(0, 1, 0.15).normalized())
	mb.add_quad(canvas, Vector3(-1.35, 2.55, -1.15), Vector3(-1.35, 2.25, 0.95), Vector3(1.35, 2.25, 0.95), Vector3(1.35, 2.55, -1.15), Vector2.ZERO, Vector2(0, 1), Vector2(1.4, 1), Vector2(1.4, 0), Color(0.6, 0.6, 0.6), Vector3(0, -1, -0.15).normalized())
	# the ledger, an inkpot, the slate of ships behind
	mb.add_box(PSXMat.lit("leather", Color(0.45, 0.22, 0.15)), Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.3, 1.19, 0.4)), Vector3(0.5, 0.06, 0.36), 1.0)
	mb.add_box(PSXMat.flat(Color(0.9, 0.86, 0.72)), Transform3D(Basis(Vector3.UP, 0.2), Vector3(-0.3, 1.225, 0.4)), Vector3(0.44, 0.015, 0.3), 1.0)
	mb.add_cylinder(PSXMat.flat(Color(0.1, 0.1, 0.12)), Transform3D(Basis(), Vector3(0.35, 1.165, 0.45)), 0.06, 0.05, 0.1, 6, 1.0)
	mb.add_box(dark, Transform3D(Basis(), Vector3(0, 1.75, -1.02)), Vector3(1.7, 1.0, 0.06), 1.0)
	mb.add_box(PSXMat.flat(Color(0.14, 0.16, 0.15)), Transform3D(Basis(), Vector3(0, 1.75, -0.98)), Vector3(1.5, 0.85, 0.02), 1.0)
	var chalk := PSXMat.flat(Color(0.88, 0.88, 0.84))
	for k in range(5):
		mb.add_box(chalk, Transform3D(Basis(), Vector3(-0.2 + (k % 2) * 0.1, 2.05 - k * 0.15, -0.965)), Vector3(0.9 - (k % 3) * 0.2, 0.03, 0.01), 1.0)
	Buildings.wall_lantern(mb, Vector3(1.15, 1.9, 0.65), dark)
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 1.15, 0.8)
	cs.shape = box
	cs.position = Vector3(0, 0.58, 0.35)
	body.add_child(cs)
	var m := Marker3D.new()
	m.name = "Keeper"
	m.position = Vector3(0, 0, -0.4)
	body.add_child(m)
	return body


## A boat being built on the stocks (bow -Z): keel on blocks, stem and
## sternpost, the frames up, the lower strakes planked, shores holding her.
func _boat_on_stocks() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "BoatOnStocks"
	var mb := MeshBuilder.new()
	var oak := PSXMat.lit("planks", Color(0.98, 0.88, 0.72))
	var dark := PSXMat.lit("planks_dark")
	var keel_y := 0.95
	var top_y := 2.35
	var half := 4.2
	var hw := func(z: float) -> float: return 1.35 * sqrt(maxf(1.0 - pow(z / (half + 0.5), 2.0), 0.05))
	var frame := func(z: float, t: float) -> Vector3:
		var w: float = hw.call(z)
		var a := Vector3(-w, top_y, z)
		var c := Vector3(0, keel_y * 2.0 - top_y, z)
		var b := Vector3(w, top_y, z)
		return a * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + b * t * t
	mb.add_box(dark, Transform3D(Basis(), Vector3(0, keel_y - 0.1, 0)), Vector3(0.2, 0.25, half * 2.0 + 0.3), 1.0, Color.WHITE, false)
	mb.add_tube(dark, MeshBuilder.curve_points(Vector3(0, keel_y, -half), Vector3(0, keel_y + 0.4, -half - 0.9), Vector3(0, top_y + 0.35, -half - 0.6), 6), 0.11, -1.0, 5)
	mb.add_tube(dark, PackedVector3Array([Vector3(0, keel_y, half), Vector3(0, top_y + 0.2, half + 0.35)]), 0.11, -1.0, 5)
	var zs: Array = []
	var z := -half + 0.6
	while z < half - 0.4:
		zs.append(z)
		var pts := PackedVector3Array()
		for k in range(9):
			pts.append(frame.call(z, k / 8.0))
		mb.add_tube(oak, pts, 0.06, -1.0, 4)
		z += 0.75
	# the lower strakes are on: planks between the frames either side
	for t in [0.3, 0.36, 0.42, 0.58, 0.64, 0.7]:
		for i in range(zs.size() - 1):
			Buildings.beam_between(mb, oak, frame.call(zs[i], t), frame.call(zs[i + 1], t), 0.04, 0.2)
	# gunwale lath along the frame heads
	for t in [0.0, 1.0]:
		for i in range(zs.size() - 1):
			Buildings.beam_between(mb, oak, frame.call(zs[i], t), frame.call(zs[i + 1], t), 0.07)
	# keel blocks and shores
	for bz in [-3.0, 0.0, 3.0]:
		mb.add_box(dark, Transform3D(Basis(), Vector3(0, (keel_y - 0.22) * 0.5, bz)), Vector3(0.6, keel_y - 0.22, 0.5), 1.0)
	for sz in [-2.0, 1.6]:
		for s in [-1.0, 1.0]:
			Buildings.beam_between(mb, dark, Vector3(s * 2.3, 0.0, sz), Vector3(s * float(hw.call(sz)) * 0.9, 1.75, sz), 0.1)
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, top_y, half * 2.0 + 1.0)
	cs.shape = box
	cs.position = Vector3(0, top_y * 0.5, 0)
	body.add_child(cs)
	return body


## The quay: a paved platform on a stone sea wall with coping, bollards and
## swimmers' ladders, closed at both ends; collision boxes under its top.
func _build_quay(rng: RandomNumberGenerator) -> void:
	var mb := MeshBuilder.new()
	var cob := PSXMat.lit("cobbles", Color.WHITE, {"affine": 0.6})
	var wall := PSXMat.lit("stone_brick", Color(0.85, 0.82, 0.76), {"affine": 0.6})
	var cope := PSXMat.lit("stone_brick", Color(0.7, 0.68, 0.64))
	var iron := PSXMat.lit("metal", Color(0.22, 0.22, 0.24))
	var body := StaticBody3D.new()
	body.name = "Quay"
	body.collision_layer = 1
	body.collision_mask = 0
	var n := _quay_x.size()
	var bottom := -4.0
	# the platform's shell (paving, sea wall, curb, ends) is also its collision
	var shell := MeshBuilder.new()
	var y := QUAY_Y
	var v := func(q: Vector2, yy: float) -> Vector3: return Vector3(q.x, yy, q.y)
	# (every point's inland offset is the same, so neighbouring strips share edges)
	var mid_off := Vector2(0, QUAY_W)
	var in_off := Vector2(0, PLAT_D)
	for i in range(n - 1):
		var a := Vector2(_quay_x[i], _quay_zs[i])
		var b := Vector2(_quay_x[i + 1], _quay_zs[i + 1])
		var t := (b - a).normalized()
		var sea := Vector2(t.y, -t.x)
		if sea.y > 0.0:
			sea = -sea
		var nrm := Vector3(sea.x, 0, sea.y)
		var a_m := a + mid_off
		var b_m := b + mid_off
		var a_in := a + in_off
		var b_in := b + in_off
		# paving (two strips so the texture warp stays small), the curb at the back
		shell.add_quad(cob, v.call(a, y), v.call(b, y), v.call(b_m, y), v.call(a_m, y), a * 0.4, b * 0.4, b_m * 0.4, a_m * 0.4, Color.WHITE, Vector3.UP)
		shell.add_quad(cob, v.call(a_m, y), v.call(b_m, y), v.call(b_in, y), v.call(a_in, y), a_m * 0.4, b_m * 0.4, b_in * 0.4, a_in * 0.4, Color(0.92, 0.92, 0.92), Vector3.UP)
		shell.add_quad(cope, v.call(a_in, y), v.call(b_in, y), v.call(b_in, y - 0.8), v.call(a_in, y - 0.8), Vector2(a.x, 0) * 0.5, Vector2(b.x, 0) * 0.5, Vector2(b.x, 0.4), Vector2(a.x, 0.4), Color(0.8, 0.8, 0.8), -nrm)
		# the sea wall (wet and dark below the tide line)
		var uva := Vector2(a.x + a.y, 0) * 0.4
		var uvb := Vector2(b.x + b.y, 0) * 0.4
		shell.add_quad(wall, v.call(a, y), v.call(b, y), v.call(b, 0.4), v.call(a, 0.4), uva, uvb, uvb + Vector2(0, 0.5), uva + Vector2(0, 0.5), Color.WHITE, nrm)
		shell.add_quad(wall, v.call(a, 0.4), v.call(b, 0.4), v.call(b, bottom), v.call(a, bottom), uva + Vector2(0, 0.5), uvb + Vector2(0, 0.5), uvb + Vector2(0, 2.2), uva + Vector2(0, 2.2), Color(0.55, 0.6, 0.55), nrm)
		# coping along the edge
		var mid := (a + b) * 0.5 + sea * 0.12
		mb.add_box(cope, Transform3D(Basis(Vector3.UP, face_yaw(t)), Vector3(mid.x, y + 0.06, mid.y)), Vector3(0.62, 0.18, a.distance_to(b) + 0.04), 0.8, Color(0.85 + rng.randf() * 0.15, 0.85, 0.85), false)
	# the two ends, closed with a wall and a stone pier-head
	for e in [[0, -1.0], [n - 1, 1.0]]:
		var q := Vector2(_quay_x[e[0]], _quay_zs[e[0]])
		var q_in := q + in_off
		var nx := Vector3(float(e[1]), 0, 0)
		shell.add_quad(wall, Vector3(q.x, QUAY_Y, q.y), Vector3(q_in.x, QUAY_Y, q_in.y), Vector3(q_in.x, bottom, q_in.y), Vector3(q.x, bottom, q.y),
			Vector2(q.y, 0) * 0.4, Vector2(q_in.y, 0) * 0.4, Vector2(q_in.y, 2.2) * 0.4, Vector2(q.y, 2.2) * 0.4, Color(0.8, 0.8, 0.8), nx)
		mb.add_box(cope, Transform3D(Basis(), Vector3(q.x, QUAY_Y + 0.45, q.y + 0.4)), Vector3(1.0, 0.9, 1.0), 0.8, Color.WHITE, true)
	var shell_mesh := shell.commit()
	var shell_i := MeshInstance3D.new()
	shell_i.name = "QuayShell"
	shell_i.mesh = shell_mesh
	shell_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(shell_i)
	var cs := CollisionShape3D.new()
	cs.shape = shell_mesh.create_trimesh_shape()
	body.add_child(cs)
	# bollards and ladders along the edge, clear of the piers and the dock
	var gaps := [0.0, -32.0, 30.0, 46.0]
	var x := port_x0 + 3.0
	var k := 0
	while x < port_x1 - 2.0:
		var clear := true
		for g in gaps:
			if absf(x - float(g)) < 3.2:
				clear = false
		if clear:
			var q := _quay_pt(x, 0.45)
			mb.add_cylinder(iron, Transform3D(Basis(), Vector3(q.x, QUAY_Y + 0.1, q.y)), 0.16, 0.2, 0.42, 7, 1.0)
			mb.add_cylinder(iron, Transform3D(Basis(), Vector3(q.x, QUAY_Y + 0.52, q.y)), 0.24, 0.24, 0.07, 7, 1.0)
			if k % 3 == 1:
				var lp := _quay_pt(x + 1.6, 0.0)
				var lad := Ladder.new()
				lad.length = QUAY_Y + 1.2
				lad.deck_depth = 0.9
				lad.position = Vector3(lp.x, QUAY_Y, lp.y)
				lad.rotation.y = face_yaw(Vector2(0, -1))
				add_child(lad)
			k += 1
		x += 7.0
	var mesh_i := mb.to_instance("QuayMesh")
	mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_i)
	add_child(body)
	for i in range(0, n, 3):
		reserve(Vector2(_quay_x[i], _quay_zs[i] + PLAT_D * 0.5), PLAT_D * 0.5)


## Waterfront houses and shops packed shoulder to shoulder facing the harbour,
## a second row behind where there's room.
func _build_waterfront(rng: RandomNumberGenerator) -> void:
	var walls := ["plaster", "planks", "planks_weathered", "stone_brick", "plaster"]
	var roofs := ["gable_front", "gable_front", "gable", "hip", "gable_front"]
	var awnings := ["red", "blue", "green", "", "red", "", "blue"]
	var front := PLAT_D + 0.15
	for row in range(2):
		var x := port_x0 + 2.5
		var i := 0
		while x < port_x1 - 6.0:
			var w := rng.randf_range(4.5, 6.5)
			var d := rng.randf_range(4.5, 5.5)
			var cx := x + w * 0.5
			x += w + rng.randf_range(0.6, 1.4)
			# keep the road up from the dock open, and away from the tower
			if absf(cx) < 6.5 + w * 0.5 or cx > port_x1 - 9.0:
				continue
			var inland := front + d * 0.5 + 0.4 + row * (d + 4.0)
			var p := _quay_pt(cx, inland)
			if _excluded(p, maxf(w, d) * 0.55) or _path_dist(p) < maxf(w, d) * 0.55:
				continue
			var spec := {"w": w, "d": d, "h": rng.randf_range(2.5, 2.9), "floors": 2 if rng.randf() < 0.7 else 1,
				"wall": walls[(i + row) % walls.size()], "wall2": ["plaster", "planks", "planks_weathered"][rng.randi() % 3],
				"roof": roofs[rng.randi() % roofs.size()], "roof_tex": "roof_tiles" if rng.randf() < 0.6 else "thatch",
				"pitch": rng.randf_range(0.5, 0.75), "chimney": rng.randf() < 0.6, "jetty": rng.randf_range(0.2, 0.45),
				"seed": 900 + i + row * 50, "door_x": rng.randf_range(-0.8, 0.8)}
			if row == 0:
				spec["awning"] = awnings[i % awnings.size()]
			_house(spec, p, Vector2(0, -1))
			i += 1


## Cargo, nets, carts and lamps along the quay; dockhands about their work.
func _dress_quay(rng: RandomNumberGenerator) -> void:
	var spots := [-40.0, -26.0, -8.0, 14.0, 22.0, 37.0, 52.0]
	for sx in spots:
		if sx < port_x0 + 3.0 or sx > port_x1 - 3.0:
			continue
		var q := _quay_pt(sx, 6.5)
		if _excluded(q, 1.0):
			continue
		match int(absf(sx)) % 3:
			0:
				place(Props.crate(0.9), q, rng.randf() * TAU, 0.8)
				place(Props.crate(0.7), q + Vector2(1.0, 0.3), rng.randf() * TAU, 0.6)
				var top := Props.crate(0.6)
				place(top, q, rng.randf() * TAU, 0.0, 0.9)
			1:
				place(Props.barrel(), q, 0.0, 0.5)
				place(Props.barrel(), q + Vector2(0.8, 0.2), 0.0, 0.5)
				place(Props.net_pile(), q + Vector2(-1.2, 0.5), rng.randf() * TAU)
			_:
				place(_handcart(), q, face_yaw(Vector2(rng.randf_range(-1, 1), 1)), 1.2)
	for lx in [-24.0, 18.0, 40.0]:
		if lx < port_x0 + 2.0 or lx > port_x1 - 2.0:
			continue
		var lq := _quay_pt(lx, QUAY_W - 0.8)
		if _excluded(lq, 0.5):
			continue
		var post := place(Props.lantern_post(), lq, face_yaw(Vector2(0, -1)) - PI * 0.5, 0.4)
		var nl := NightLight.make(Color(1.0, 0.75, 0.42), 1.6, 10.0)
		nl.position = Vector3(0.55, 2.0, 0.0)
		post.add_child(nl)
	# stalls on the street where the fish comes in
	for st in [["fish", -9.5], ["fruit", 24.5]]:
		var sp := _quay_pt(float(st[1]), QUAY_W - 2.0)
		if not _excluded(sp, 1.5):
			place(Buildings.stall(st[0]), sp, face_yaw(Vector2(0, -1)), 1.8)
	# dockhands walking the quay
	# (along the back of the quay, clear of the booth, the yard and the crane)
	var a := _quay_pt(maxf(port_x0 + 4.0, -30.0), 14.0)
	var b := _quay_pt(-11.0, 14.0)
	var c := _quay_pt(minf(port_x1 - 6.0, 38.0), 13.5)
	var d := _quay_pt(22.0, 13.5)
	for spec in [[[a, b], "Dockhand Rook", ["Mind your feet, Captain. Rope everywhere, and half of it's attached to something.",
			"That junk's out of the far east. Smells of tea and gunpowder.", "Odile's got us hauling cargo since dawn. I've forgotten what my hands are for.",
			{"text": "You're the one Pell found on the west sand? You look better. Not good. Better.", "before": "see_vey"},
			{"text": "Tackett finally let that sloop go? To you? Bold. I like it.", "after": "tackett_ship"}], 0.85],
			[[c, d], "Merchant Ysolde", ["Silk, spice, and nothing the harbourmaster needs to see. Kidding. Mostly.",
			"The merchantman's mine. Well. The bank's. Well. Mine on Tuesdays.",
			{"text": "Pirates past the reef again. Bad for trade. Good for the price of rum.", "before": "morrow"},
			{"text": "Trade's picking up since Morrow fell. I might even pay the bank.", "after": "morrow"}], 1.15]]:
		var route: Array = []
		for q in spec[0]:
			route.append(Vector3(q.x, QUAY_Y, q.y))
		var nrng := RandomNumberGenerator.new()
		nrng.seed = hash(spec[1])
		var lk := CharacterLook.random_look(nrng)
		lk["name"] = spec[1]
		_npc({"name": spec[1], "voice": spec[3], "barks": spec[2], "look": lk, "waypoints": route},
			Vector2(route[0].x, route[0].z), Vector2(1, 0), QUAY_Y)


# ==========================================================================
# Village dressing: cobbles, bunting, lamps, benches, washing, a garden
# ==========================================================================
func _dress_village() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2626
	var cob := MeshBuilder.new()
	var cobbles := PSXMat.lit("cobbles", Color.WHITE, {"affine": 0.6})
	_pave_disk(cob, cobbles, VILLAGE, 12.5, rng)
	_pave_disk(cob, cobbles, MARKET, 7.0, rng)
	_pave_path(cob, cobbles, paths[0], 1.7)
	var paving := cob.to_instance("Cobbles")
	paving.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(paving)
	# a bucket and rope at the well, benches round it
	for k in range(4):
		var a := PI * 0.25 + k * PI * 0.5
		var bp := VILLAGE + Vector2(cos(a), sin(a)) * 5.5
		if _path_dist(bp) < 1.5:
			continue
		place(Props.bench(), bp, face_yaw(VILLAGE - bp) + PI * 0.5, 1.0)
	place(Buildings.planter(0.75), VILLAGE + Vector2(-8.5, 7.0), 0.0, 0.9)
	place(Buildings.planter(0.6), VILLAGE + Vector2(8.0, -8.0), 0.0, 0.8)
	# lamps round the plaza (real light after dark) and one in the market
	for q in [VILLAGE + Vector2(-9.5, -6.0), VILLAGE + Vector2(9.0, 5.5), VILLAGE + Vector2(-3.0, 11.5), MARKET + Vector2(-5.5, 6.5)]:
		var post := place(Props.lantern_post(), q, face_yaw(VILLAGE - q) - PI * 0.5, 0.4)
		var nl := NightLight.make(Color(1.0, 0.75, 0.42), 1.8, 10.0)
		nl.position = Vector3(0.55, 2.0, 0.0)
		post.add_child(nl)
	# bunting strung between poles round the plaza
	var poles: Array = []
	for k in range(10):
		var a := TAU * k / 10.0 + 0.15
		var q := VILLAGE + Vector2(cos(a), sin(a)) * 13.2
		var clear := _path_dist(q) > 1.2
		for e in exclusions:
			if float(e[1]) < 12.0 and q.distance_to(e[0]) < float(e[1]) + 0.2:
				clear = false
		if clear:
			poles.append([a, q])
	var bmb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	for pq in poles:
		var q: Vector2 = pq[1]
		bmb.add_box(wood, Transform3D(Basis(), Vector3(q.x, hv(q) + 2.1, q.y)), Vector3(0.12, 4.2, 0.12), 1.0)
		reserve(q, 0.8)
	for i in range(poles.size()):
		var a0: Array = poles[i]
		var a1: Array = poles[(i + 1) % poles.size()]
		if wrapf(float(a1[0]) - float(a0[0]), 0.0, TAU) > PI * 0.45:
			continue
		var p0: Vector2 = a0[1]
		var p1: Vector2 = a1[1]
		_bunting(bmb, Vector3(p0.x, hv(p0) + 4.0, p0.y), Vector3(p1.x, hv(p1) + 4.0, p1.y), rng)
	# and across the market between two stalls' poles
	_bunting(bmb, Vector3(MARKET.x - 6.5, hv(MARKET) + 3.4, MARKET.y - 3.0), Vector3(MARKET.x + 6.0, hv(MARKET) + 3.4, MARKET.y + 3.5), rng)
	for q in [MARKET + Vector2(-6.5, -3.0), MARKET + Vector2(6.0, 3.5)]:
		bmb.add_box(wood, Transform3D(Basis(), Vector3(q.x, hv(q) + 1.75, q.y)), Vector3(0.12, 3.5, 0.12), 1.0)
		reserve(q, 0.8)
	add_child(bmb.to_instance("Bunting"))
	# the notice board by the tavern
	var nb := VILLAGE + Vector2(-12.5, 9.0)
	place(_notice_board(rng), nb, face_yaw(VILLAGE - nb), 1.0)
	# washing lines behind the houses, a fenced vegetable plot
	_laundry(Vector2(-24.0, -98.0), Vector2(-23.0, -104.5), rng)
	_laundry(Vector2(33.0, -45.0), Vector2(37.0, -40.0), rng)
	_laundry(Vector2(-34.5, -20.0), Vector2(-38.5, -25.0), rng)
	_garden(Vector2(-25.0, -33.0), 5.0, 4.0, face_yaw(Vector2(1, -0.5)), rng)
	place(_handcart(), VILLAGE + Vector2(6.5, -30.0), face_yaw(Vector2(0.3, -1)), 1.4)


## Cobbles over a ragged disk of ground, following it.
func _pave_disk(mb: MeshBuilder, mat: Material, c: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var s := 1.5
	var n := int(ceil(r / s))
	for ix in range(-n, n):
		for iz in range(-n, n):
			var a := c + Vector2(ix, iz) * s
			var mid := a + Vector2(s, s) * 0.5
			if mid.distance_to(c) > r - 0.8 + rng.randf() * 1.6:
				continue
			_pave_quad(mb, mat, a, a + Vector2(s, 0), a + Vector2(s, s), a + Vector2(0, s))


## Cobbles along a path (its half-width `hw`).
func _pave_path(mb: MeshBuilder, mat: Material, pts: PackedVector2Array, hw: float) -> void:
	var line := PackedVector2Array()
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var steps := maxi(int(ceil(a.distance_to(b) / 1.5)), 1)
		for k in range(steps):
			line.append(a.lerp(b, float(k) / steps))
	line.append(pts[pts.size() - 1])
	var sides: Array = []
	for i in range(line.size()):
		var t := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()
		sides.append(Vector2(-t.y, t.x) * hw)
	for i in range(line.size() - 1):
		var s0: Vector2 = sides[i]
		var s1: Vector2 = sides[i + 1]
		_pave_quad(mb, mat, line[i] - s0, line[i] + s0, line[i + 1] + s1, line[i + 1] - s1)


func _pave_quad(mb: MeshBuilder, mat: Material, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	if _port_ready and _on_platform(a) and _on_platform(c):
		return  # (the quay is paved already)
	var v := func(q: Vector2) -> Vector3: return Vector3(q.x, hv(q) + 0.05, q.y)
	var uv := func(q: Vector2) -> Vector2: return q * 0.4
	var na: Vector3 = v.call(a)
	var nb: Vector3 = v.call(b)
	var nc: Vector3 = v.call(c)
	var nd: Vector3 = v.call(d)
	mb.add_tri(mat, na, nb, nc, Vector3.UP, Vector3.UP, Vector3.UP, uv.call(a), uv.call(b), uv.call(c), Color.WHITE, Vector3.UP)
	mb.add_tri(mat, na, nc, nd, Vector3.UP, Vector3.UP, Vector3.UP, uv.call(a), uv.call(c), uv.call(d), Color.WHITE, Vector3.UP)


const PENNANTS := [Color(0.8, 0.18, 0.15), Color(0.95, 0.8, 0.25), Color(0.2, 0.42, 0.7), Color(0.92, 0.9, 0.84), Color(0.25, 0.55, 0.35)]


## A sagging line between a and b hung with little triangular flags.
func _bunting(mb: MeshBuilder, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var rope := PSXMat.lit("rope")
	var n := maxi(int(a.distance_to(b) / 0.55), 2)
	var sag := a.distance_to(b) * 0.08
	var prev := a
	var dir := (b - a).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := a.lerp(b, t) - Vector3.UP * sag * 4.0 * t * (1.0 - t)
		Buildings.beam_between(mb, rope, prev, p, 0.025)
		if k < n:
			var col := PSXMat.flat(PENNANTS[rng.randi() % PENNANTS.size()])
			var l := p - dir * 0.2
			var r := p + dir * 0.2
			var tip := p + Vector3.DOWN * 0.38 + side * rng.randf_range(-0.03, 0.03)
			mb.add_tri(col, l, r, tip, side, side, side, Vector2.ZERO, Vector2(1, 0), Vector2(0.5, 1), Color.WHITE, side)
			mb.add_tri(col, l, tip, r, -side, -side, -side, Vector2.ZERO, Vector2(0.5, 1), Vector2(1, 0), Color(0.8, 0.8, 0.8), -side)
		prev = p


## Two posts, a line, and the washing out on it.
func _laundry(a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_weathered")
	var ya := hv(a)
	var yb := hv(b)
	for q in [Vector3(a.x, ya, a.y), Vector3(b.x, yb, b.y)]:
		mb.add_box(wood, Transform3D(Basis(), q + Vector3(0, 1.1, 0)), Vector3(0.1, 2.2, 0.1), 1.0)
	var pa := Vector3(a.x, ya + 2.05, a.y)
	var pb := Vector3(b.x, yb + 2.05, b.y)
	Buildings.beam_between(mb, PSXMat.lit("rope"), pa, pb, 0.02)
	var dir := (pb - pa).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var cloths := [Color(0.92, 0.9, 0.85), Color(0.6, 0.72, 0.85), Color(0.8, 0.4, 0.32), Color(0.85, 0.8, 0.55), Color(0.55, 0.65, 0.5)]
	var x := 0.4
	var len := pa.distance_to(pb)
	while x < len - 0.6:
		var cw := rng.randf_range(0.4, 0.8)
		var ch := rng.randf_range(0.45, 0.9)
		var p0 := pa + dir * x - Vector3.UP * 0.05
		var p1 := pa + dir * (x + cw) - Vector3.UP * 0.05
		var col := PSXMat.lit("fabric", cloths[rng.randi() % cloths.size()])
		var lean := side * rng.randf_range(-0.08, 0.08)
		mb.add_quad(col, p0, p1, p1 + Vector3.DOWN * ch + lean, p0 + Vector3.DOWN * ch + lean, Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Color.WHITE, side)
		mb.add_quad(col, p0, p0 + Vector3.DOWN * ch + lean, p1 + Vector3.DOWN * ch + lean, p1, Vector2.ZERO, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Color(0.8, 0.8, 0.8), -side)
		x += cw + rng.randf_range(0.15, 0.4)
	add_child(mb.to_instance("Washing"))
	reserve(a, 0.8)
	reserve(b, 0.8)


## A fenced vegetable plot: rows of crops on tilled earth.
func _garden(c: Vector2, w: float, d: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	node.name = "Garden"
	var mb := MeshBuilder.new()
	var soil := PSXMat.lit("dirt", Color(0.75, 0.62, 0.5))
	var leaf := PSXMat.lit("leaves", Color(0.75, 1.0, 0.7))
	var veg := [PSXMat.flat(Color(0.95, 0.55, 0.15)), PSXMat.flat(Color(0.75, 0.15, 0.2)), PSXMat.flat(Color(0.85, 0.85, 0.4))]
	var rows := int(d / 0.8)
	for r in range(rows):
		var z := -d * 0.5 + 0.4 + r * 0.8
		mb.add_box(soil, Transform3D(Basis(), Vector3(0, 0.06, z)), Vector3(w - 0.6, 0.18, 0.45), 1.0)
		var vm: Material = veg[r % veg.size()]
		for k in range(int((w - 0.8) / 0.45)):
			var x := -w * 0.5 + 0.6 + k * 0.45
			mb.add_blob(leaf, Transform3D(Basis(), Vector3(x, 0.24, z)), Vector3(0.16, 0.13, 0.16), rng, 0.3, 2, 5, 1.0)
			if (k + r) % 3 == 0:
				mb.add_blob(vm, Transform3D(Basis(), Vector3(x + 0.05, 0.2, z + 0.1)), Vector3.ONE * 0.07, rng, 0.2, 2, 4, 1.0)
	node.add_child(mb.to_instance())
	place(node, c, yaw, maxf(w, d) * 0.5)
	# the fence round it, a gap at the front for the gate
	for seg in [[Vector2(-w * 0.5, -d * 0.5), 0.0, d], [Vector2(w * 0.5, -d * 0.5), 0.0, d], [Vector2(-w * 0.5, -d * 0.5), PI * 0.5, w],
			[Vector2(-w * 0.5, d * 0.5), PI * 0.5, w * 0.4], [Vector2(w * 0.1, d * 0.5), PI * 0.5, w * 0.4]]:
		var local: Vector2 = seg[0]
		var wp := c + local.rotated(-yaw)
		var f := Props.fence_segment(float(seg[2]), 0.8)
		f.position = Vector3(wp.x, hv(wp), wp.y)
		f.rotation.y = yaw + float(seg[1])
		add_child(f)


## A notice board: two posts, a little roof, papers pinned up.
func _notice_board(rng: RandomNumberGenerator) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "NoticeBoard"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks_dark")
	for x in [-0.8, 0.8]:
		mb.add_box(wood, Transform3D(Basis(), Vector3(x, 1.1, 0)), Vector3(0.12, 2.2, 0.12), 1.0)
	mb.add_box(PSXMat.lit("planks"), Transform3D(Basis(), Vector3(0, 1.45, 0.02)), Vector3(1.5, 1.0, 0.06), 1.0)
	mb.add_gable_roof(PSXMat.lit("thatch"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 2.2, 0)), 0.6, 1.9, 0.35, 0.1)
	var papers := [Color(0.9, 0.86, 0.72), Color(0.95, 0.93, 0.85), Color(0.85, 0.78, 0.6)]
	for k in range(6):
		var pp := Vector3(-0.55 + (k % 3) * 0.55 + rng.randf_range(-0.08, 0.08), 1.7 - (k / 3) * 0.48, 0.06)
		mb.add_box(PSXMat.flat(papers[k % 3]), Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12)), pp), Vector3(0.36, 0.42, 0.01), 1.0)
		mb.add_box(PSXMat.flat(Color(0.3, 0.25, 0.2)), Transform3D(Basis(), pp + Vector3(0, 0.08, 0.008)), Vector3(0.24, 0.03, 0.005), 1.0)
		mb.add_box(PSXMat.flat(Color(0.75, 0.15, 0.12)), Transform3D(Basis(), pp + Vector3(0, 0.19, 0.01)), Vector3(0.03, 0.03, 0.01), 1.0)
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 2.2, 0.3)
	cs.shape = box
	cs.position = Vector3(0, 1.1, 0)
	body.add_child(cs)
	return body


## A hand cart with sacks in it.
func _handcart() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Handcart"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("planks")
	var dark := PSXMat.lit("planks_dark")
	mb.add_box(wood, Transform3D(Basis(), Vector3(0, 0.6, 0)), Vector3(1.2, 0.1, 1.6), 1.0)
	for s in [-1.0, 1.0]:
		mb.add_box(wood, Transform3D(Basis(), Vector3(s * 0.6, 0.8, 0)), Vector3(0.06, 0.35, 1.6), 1.0)
		mb.add_cylinder(dark, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(s * 0.72, 0.42, 0.2)), 0.42, 0.42, 0.07, 10, 1.0, Color.WHITE, true, true)
		Buildings.beam_between(mb, dark, Vector3(s * 0.45, 0.6, 0.8), Vector3(s * 0.45, 0.15, 2.0), 0.07)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for k in range(3):
		mb.add_blob(PSXMat.lit("canvas", Color(0.8, 0.72, 0.55)), Transform3D(Basis(), Vector3(-0.3 + k * 0.3, 0.88, -0.3 + (k % 2) * 0.5)), Vector3(0.28, 0.22, 0.32), rng, 0.2, 3, 6)
	body.add_child(mb.to_instance())
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.0, 1.7)
	cs.shape = box
	cs.position = Vector3(0, 0.5, 0)
	body.add_child(cs)
	return body


func _build_training_yard() -> void:
	var w := 22.0
	var d := 16.0
	var c := TRAINING
	# fence: west, north, south sides and east side with a gate gap in the middle
	var segs := []
	for i in range(int(d / 4.0)):
		segs.append([c + Vector2(-w * 0.5, -d * 0.5 + i * 4.0), 0.0])
	for i in range(int(w / 4.0)):
		segs.append([c + Vector2(-w * 0.5 + i * 4.0, -d * 0.5), PI * 0.5])
		segs.append([c + Vector2(-w * 0.5 + i * 4.0, d * 0.5), PI * 0.5])
	for i in range(int(d / 4.0)):
		var z0 := -d * 0.5 + i * 4.0
		if z0 >= -3.0 and z0 < 3.0:
			continue
		segs.append([c + Vector2(w * 0.5, z0), 0.0])
	for s in segs:
		var f := Props.fence_segment(4.0)
		place(f, s[0], s[1])
	reserve(c, 11.0)
	var dummy_scene: PackedScene = load("res://scenes/enemies/dummy_target.tscn")
	for off in [Vector2(-5, -4), Vector2(-6, 2), Vector2(-3, 5)]:
		var dmy := dummy_scene.instantiate() as Node3D
		place(dmy, c + off, face_yaw(Vector2(1, 0)))
	place(Props.weapon_rack(), c + Vector2(2, -7), 0.0)
	place(Props.bench(), c + Vector2(6, 6.5), PI)
	place(Props.barrel(), c + Vector2(-9.5, -6.5))


func _build_lighthouse() -> void:
	place(Props.lighthouse(), HILL, face_yaw(Vector2(-1, 0.3)), 3.5, -0.3)
	# keeper's cottage on the levelled hilltop (it used to hang off the slope)
	_keeper_hut = _house({"w": 4.5, "d": 4.0, "h": 2.3, "wall": "stone_brick", "roof": "gable", "roof_tex": "roof_tiles",
		"chimney": true}, HILL + Vector2(-7.5, 5.5), Vector2(-0.6, -1))
	place(Props.barrel(), HILL + Vector2(-4.0, 8.5))
	place(Props.crate(0.7), HILL + Vector2(-3.4, 9.6))


func _build_ruins() -> void:
	var c := RUINS
	reserve(c, 9.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(9):
		var a := TAU * i / 9.0 + 0.2
		var p := c + Vector2(cos(a), sin(a)) * 7.5
		if i == 3 or i == 7:
			var fp := Props.fallen_pillar(rng.randf_range(3.5, 4.5))
			place(fp, p + Vector2(cos(a), sin(a)) * 1.5, a + PI * 0.5 + rng.randf_range(-0.3, 0.3))
			continue
		var broken := i % 2 == 0
		place(Props.ruin_pillar(rng.randf_range(2.0, 4.2) if broken else 4.4, broken, i), p, rng.randf() * TAU)
	# floor slabs
	var slab_m := PSXMat.lit("stone_brick", Color(0.75, 0.8, 0.75))
	var mb := MeshBuilder.new()
	for i in range(14):
		var p := Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5))
		var y := hv(c + p) + 0.02
		mb.add_box(slab_m, Transform3D(Basis(Vector3.UP, rng.randf() * 0.3), Vector3(p.x, y - hv(c) + 0.05, p.y)),
			Vector3(rng.randf_range(1.2, 2.0), 0.2, rng.randf_range(1.2, 2.0)), 0.6, Color.WHITE, true, false)
	var slabs := mb.to_instance("Slabs")
	slabs.position = Vector3(c.x, hv(c), c.y)
	add_child(slabs)
	var stone := place(Props.driftstone(), c, face_yaw(Vector2(0.6, -0.8)), 1.5, -0.2)
	var inter := Interactable.new()
	inter.name = "Examine"
	inter.collision_layer = 512
	inter.collision_mask = 0
	inter.prompt_text = "Examine the Driftstone"
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.8
	cs.shape = sph
	cs.position = Vector3(0, 1.5, 0)
	inter.add_child(cs)
	stone.add_child(inter)
	inter.interacted.connect(func(_p): Dialogue.start("driftstone", stone))


func _build_cove() -> void:
	# rowboat pulled up on the cove beach
	var boat_p := COVE + (CAMP - COVE).normalized() * 19.0 + Vector2(4, -2)
	place(Props.rowboat(), boat_p, face_yaw(COVE - boat_p) + 0.4, 1.5)
	place(Props.crate(0.7), CAMP + Vector2(2.5, 3.0), 0.3)
	place(Props.barrel(), CAMP + Vector2(3.4, 2.0))


func _build_beach_camp() -> void:
	# castaway camp: campfire, lean-to, log seats
	var fire := Props.campfire()
	place(fire, CAMP, 0.0, 1.5)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/campfire_loop.wav")
	snd.unit_size = 4.0
	snd.max_distance = 30.0
	snd.volume_db = -4.0
	snd.autoplay = true
	snd.bus = "Ambience"
	fire.add_child(snd)
	var tent_p := CAMP + Vector2(-3.8, -2.2)
	place(_tent(), tent_p, face_yaw(CAMP - tent_p), 2.0)
	place(_log(), CAMP + Vector2(0, 2.2), 0.2)


## Canvas A-frame tent (opening toward +Z) with a collider.
func _tent(tint: Color = Color(0.9, 0.85, 0.7)) -> StaticBody3D:
	var tent := StaticBody3D.new()
	tent.name = "Tent"
	var mb := MeshBuilder.new()
	var canvas := PSXMat.lit("canvas", tint)
	var wood := PSXMat.lit("bark")
	mb.add_gable_roof(canvas, Transform3D.IDENTITY, 2.2, 2.6, 1.6, 0.0, 0.6, Color.WHITE)
	# back wall + poles
	mb.add_tri(canvas, Vector3(-1.1, 0, -1.3), Vector3(1.1, 0, -1.3), Vector3(0, 1.6, -1.3),
		Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0), Color(0.8, 0.8, 0.8), Vector3.FORWARD)
	for z in [-1.35, 1.35]:
		mb.add_cylinder(wood, Transform3D(Basis(), Vector3(0, 0, z)), 0.05, 0.05, 1.75, 5, 1.0)
	tent.add_child(mb.to_instance())
	var tcs := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(2.2, 1.6, 2.6)
	tcs.shape = tbox
	tcs.position = Vector3(0, 0.8, 0)
	tent.add_child(tcs)
	return tent


## A log seat (along local X, top at 0.4).
func _log() -> MeshInstance3D:
	var log_mb := MeshBuilder.new()
	log_mb.add_cylinder(PSXMat.lit("bark"), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.9, 0.2, 0)), 0.2, 0.2, 1.8, 6, 1.0, Color.WHITE, true, true)
	return log_mb.to_instance("Log")


# ==========================================================================
# Smugglers' camp: a pirate crew's hideout on the shore past the cove, with
# a strongbox worth fighting for. Three cutlass grunts and two riflemen (GruntCamp).
# ==========================================================================
var smugglers: GruntCamp

func _build_smugglers_camp() -> void:
	var c := SMUGGLERS
	var to_sea := Vector2(1, 0.15).normalized()
	var side := Vector2(-to_sea.y, to_sea.x)
	var at := func(f: float, s_: float) -> Vector2: return c + to_sea * f + side * s_
	reserve(c, 16.0)
	# campfire with crackle
	var fire := Props.campfire()
	place(fire, c, 0.0, 1.5)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/campfire_loop.wav")
	snd.unit_size = 4.0
	snd.max_distance = 30.0
	snd.volume_db = -4.0
	snd.autoplay = true
	snd.bus = "Ambience"
	fire.add_child(snd)
	var log_a: Vector2 = at.call(0.0, 2.3)
	var log_b: Vector2 = at.call(-2.3, -0.2)
	place(_log(), log_a, face_yaw(c - log_a) + PI * 0.5)
	place(_log(), log_b, face_yaw(c - log_b) + PI * 0.5)
	# tents (darker, patched canvas) facing the fire
	for tp in [at.call(-6.0, -3.5), at.call(-5.5, 4.0), at.call(-1.5, -6.5)]:
		place(_tent(Color(0.62, 0.55, 0.45)), tp, face_yaw(c - tp), 2.0)
	# contraband: crate stacks and barrels
	var stash: Vector2 = at.call(3.5, -4.5)
	place(Props.crate(0.9), stash, 0.2, 1.0)
	var top_crate := Props.crate(0.7)
	place(top_crate, stash, 0.7, 0.0, 0.9)
	place(Props.crate(0.8), stash + side * -1.1, -0.3, 1.0)
	for k in range(3):
		place(Props.barrel(), at.call(2.0 + k * 0.9, 5.2 + (k % 2) * 0.5))
	# rowboat pulled up on the beach, weapon rack, lanterns, crew flag
	var boat: Vector2 = at.call(10.0, 1.0)
	place(Props.rowboat(), boat, face_yaw(to_sea) + 0.25, 1.5)
	place(Props.weapon_rack(), at.call(1.5, 4.2), face_yaw(c - at.call(1.5, 4.2)))
	for lp in [at.call(-3.0, 3.0), at.call(4.0, -1.5)]:
		place(Props.lantern_post(2.4), lp)
	var pole := MeshBuilder.new()
	pole.add_cylinder(PSXMat.lit("bark"), Transform3D.IDENTITY, 0.07, 0.05, 4.2, 5, 1.0)
	var flag_mat := PSXMat.lit("cloth_red", Color(0.75, 0.3, 0.28))
	pole.add_card(flag_mat, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 3.8, 0.45)), 0.9, 0.55, Rect2(0, 0, 0.5, 0.5))
	pole.add_card(flag_mat, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 3.8, 0.45)), 0.9, 0.55, Rect2(0, 0, 0.5, 0.5))
	place(pole.to_instance("CrewFlag"), at.call(-3.0, -1.0), 0.4)
	# the strongbox: treasure, gold, the crew's best hat - and the prize
	# they were smuggling: a Devil Fruit
	var chest_p: Vector2 = at.call(-8.5, 0.5)
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var items: Array[ItemStack] = []
	var fruit := ItemStack.new()
	fruit.item = load("res://resources/items/ember_fruit.tres")
	fruit.quantity = 1
	items.append(fruit)
	for it in [[load("res://resources/items/treasure.tres"), 2], [load("res://resources/items/gold.tres"), 6]]:
		var st := ItemStack.new()
		st.item = it[0]
		st.quantity = it[1]
		items.append(st)
	var hat := ItemStack.new()
	hat.item = Gear.make("head", "tricorn", {"hat": "tricorn", "hat_color": CharacterLook.CLOTH[5], "trim_color": CharacterLook.TRIM[4]}, "Smuggler Captain's Tricorn")
	hat.quantity = 1
	items.append(hat)
	bag.setup(items)
	bag.save_id = "smugglers_strongbox"
	place(bag, chest_p, face_yaw(c - chest_p))
	var chest_mesh := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if chest_mesh:
		chest_mesh.mesh = Props.treasure_chest_mesh()
		chest_mesh.position = Vector3.ZERO
		chest_mesh.scale = Vector3.ONE * 1.15

	# the crew
	smugglers = GruntCamp.new()
	smugglers.name = "SmugglersCamp"
	add_child(smugglers)
	var g_yaw := func(from: Vector2, look_at: Vector2) -> float:
		var d := look_at - from
		return atan2(-d.x, -d.y)
	var v3 := func(q: Vector2) -> Vector3: return Vector3(q.x, hv(q), q.y)
	var sit_a: Vector2 = log_a + (c - log_a).normalized() * 0.15
	var sit_b: Vector2 = log_b + (c - log_b).normalized() * 0.15
	smugglers.add_grunt({"post": v3.call(sit_a), "yaw": g_yaw.call(sit_a, c), "mode": "sit", "seat_y": 0.42, "seed": 11})
	smugglers.add_grunt({"post": v3.call(sit_b), "yaw": g_yaw.call(sit_b, c), "mode": "sit", "seat_y": 0.42, "seed": 23})
	var toward_wren := (CAMP - c).normalized()
	var guard_p := c + toward_wren * 9.0
	smugglers.add_grunt({"post": v3.call(guard_p), "yaw": g_yaw.call(guard_p, guard_p + toward_wren), "mode": "stand", "seed": 37, "role": "rifle"})
	var route := [v3.call(at.call(-4.0, -1.0)), v3.call(at.call(-0.5, -5.0)), v3.call(at.call(3.5, -2.5)), v3.call(at.call(1.0, 3.5))]
	smugglers.add_grunt({"post": route[0], "yaw": 0.0, "mode": "patrol", "patrol": route, "seed": 41})
	var boat_guard: Vector2 = at.call(7.5, 2.5)
	smugglers.add_grunt({"post": v3.call(boat_guard), "yaw": g_yaw.call(boat_guard, boat_guard + to_sea), "mode": "stand", "seed": 53, "role": "rifle"})


# ==========================================================================
# The pirate den: a hostile crew's harbour on the north-west beach. A pier
# with their sloop tied up, shacks, a lookout tower, the captain and his
# strongbox. The crew comes back a while after it's beaten (GruntCamp).
# ==========================================================================
var den: GruntCamp
const DEN_PIER := 26.0

func _build_den() -> void:
	var c := DEN
	# the pier runs out the shortest way to the sea
	var f := Vector2(-1, -1).normalized()
	var best := INF
	for k in range(32):
		var dir := Vector2(cos(k * TAU / 32.0), sin(k * TAU / 32.0))
		for d in range(10, 120, 2):
			if hv(c + dir * d) < 0.0:
				if d < best:
					best = d
					f = dir
				break
	var s := Vector2(-f.y, f.x)
	var shore := c
	for i in range(160):
		shore += f
		if _height_fn(shore.x, shore.y) < 0.8:
			break
	var root := shore - f * 4.0
	var at := func(fw: float, sd: float) -> Vector2: return c + f * fw + s * sd
	var pier_pt := func(d: float) -> Vector2: return root + f * d
	reserve(c, 20.0)

	var pier := Props.dock(DEN_PIER, 3.2, DOCK_DECK_Y, SEAFLOOR * 0.5)
	pier.position = _v3(root)
	pier.rotation.y = face_yaw(f)
	add_child(pier)
	var lad := Ladder.new()
	lad.length = DOCK_DECK_Y + 1.0
	lad.deck_depth = 0.9
	lad.position = Vector3(0, DOCK_DECK_Y, DEN_PIER)
	pier.add_child(lad)
	for d in range(0, int(DEN_PIER) + 6, 4):
		reserve(pier_pt.call(float(d)), 3.0)

	# their sloop, tied up alongside, bow out to sea
	var hull := MooredHull.new()
	hull.name = "DenSloop"
	hull.collision_layer = 1
	hull.collision_mask = 0
	var sloop_p: Vector2 = pier_pt.call(DEN_PIER - 10.0) + s * (1.6 + HullBuilder.HALF_BEAM + 0.6)
	hull.position = Vector3(sloop_p.x, HullBuilder.FREEBOARD, sloop_p.y)
	hull.rotation.y = face_yaw(-f)
	add_child(hull)
	var model := Node3D.new()
	hull.add_child(model)
	HullBuilder.build(model, {"hull": Color(0.55, 0.45, 0.4), "sail": Color(0.62, 0.56, 0.48), "trim": Color(0.5, 0.2, 0.18), "emblem": "jolly"})
	HullBuilder.collide(hull)
	for k in range(3):
		var bollard := Props.barrel() if k == 1 else Props.rope_coil()
		bollard.position = Vector3(0, DOCK_DECK_Y, 0) + _v3(pier_pt.call(DEN_PIER - 4.0 - k * 6.0) + s * 1.1)
		add_child(bollard)
	place(Props.crate(0.8), pier_pt.call(3.0) - s * 1.0, 0.4, 0.0, DOCK_DECK_Y - hv(pier_pt.call(3.0) - s * 1.0))

	# shacks: the captain's (biggest, set back), two crew shacks, a net shed on stilts
	var cap_p: Vector2 = at.call(-11.0, -5.0)
	# (no flower boxes for pirates; tarred grey shutters)
	var rough := {"flowers": false, "trim": Color(0.36, 0.34, 0.32)}
	_house({"w": 7.5, "d": 5.5, "h": 2.8, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch",
		"porch": 1.8, "lean_to": "left", "name": "CaptainsShack"}.merged(rough), cap_p, f)
	var shack_a: Vector2 = at.call(-6.0, 10.0)
	_house({"w": 5.0, "d": 4.0, "h": 2.3, "roof": "shed", "wall": "planks_weathered", "roof_tex": "thatch"}.merged(rough), shack_a, c - shack_a)
	var shack_b: Vector2 = at.call(2.0, -14.0)
	_house({"w": 4.5, "d": 4.0, "h": 2.3, "roof": "gable", "wall": "planks", "roof_tex": "thatch", "chimney": true}.merged(rough), shack_b, c - shack_b)
	var shed: Vector2 = shore + s * 13.0 - f * 2.0
	_house({"w": 4.5, "d": 3.5, "h": 2.2, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch", "porch": 1.2}.merged(rough), shed, f, true)

	# the lookout tower by the shore, its ladder on the landward side
	var tower_p: Vector2 = shore - f * 7.0 - s * 9.0
	place(_lookout_tower(), tower_p, face_yaw(-f), 2.6)

	# campfire with log seats, contraband, the crew's colours
	var fire := Props.campfire()
	place(fire, c, 0.0, 1.5)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = load("res://assets/audio/campfire_loop.wav")
	snd.unit_size = 4.0
	snd.max_distance = 30.0
	snd.volume_db = -4.0
	snd.autoplay = true
	snd.bus = "Ambience"
	fire.add_child(snd)
	var log_a: Vector2 = at.call(0.0, 2.4)
	var log_b: Vector2 = at.call(-2.4, -0.4)
	place(_log(), log_a, face_yaw(c - log_a) + PI * 0.5)
	place(_log(), log_b, face_yaw(c - log_b) + PI * 0.5)
	var stash: Vector2 = at.call(5.0, 5.0)
	place(Props.crate(0.9), stash, 0.3, 1.0)
	place(Props.crate(0.7), stash, 0.9, 0.0, 0.9)
	place(Props.crate(0.8), stash + s * 1.2, -0.2, 1.0)
	for k in range(4):
		place(Props.barrel(), at.call(6.5 + (k % 2) * 0.9, 2.0 - k * 0.8))
	place(Props.weapon_rack(), at.call(-3.0, 6.0), face_yaw(c - at.call(-3.0, 6.0)))
	place(Props.fish_rack(), shore + s * 6.0 - f * 3.0, face_yaw(s), 1.5)
	place(Props.net_pile(), shore + s * 8.5 - f * 1.0)
	place(Props.rowboat(), shore - s * 6.0 + f * 1.0, face_yaw(f) + 0.3, 1.5)
	for lp in [at.call(3.0, -3.0), at.call(-7.0, 4.0), root - s * 2.2]:
		place(Props.lantern_post(2.4), lp)
	var pole := MeshBuilder.new()
	pole.add_cylinder(PSXMat.lit("bark"), Transform3D.IDENTITY, 0.08, 0.06, 6.0, 5, 1.0)
	var flag_mat := PSXMat.lit("cloth_red", Color(0.18, 0.16, 0.16))
	pole.add_card(flag_mat, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 5.5, 0.6)), 1.2, 0.75, Rect2(0, 0, 0.5, 0.5))
	pole.add_card(flag_mat, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 5.5, 0.6)), 1.2, 0.75, Rect2(0, 0, 0.5, 0.5))
	var jolly := HullBuilder.jolly_material()
	pole.add_card(jolly, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.01, 5.5, 0.6)), 0.9, 0.55, Rect2(0, 0, 1, 1))
	pole.add_card(jolly, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-0.01, 5.5, 0.6)), 0.9, 0.55, Rect2(0, 0, 1, 1))
	place(pole.to_instance("DenFlag"), at.call(4.0, -6.0), 0.3)

	# the captain's strongbox on his porch
	var box_p: Vector2 = cap_p + f * 4.6 + s * 2.2
	var C := CharacterLook.CLOTH
	_strongbox(box_p, face_yaw(f), "den_strongbox", [["treasure", 4], ["gold", 15], ["rum", 2],
		[Gear.make("coat", "longcoat", {"coat": "longcoat", "coat_color": C[5], "trim_color": CharacterLook.TRIM[4]}, "Harbor Captain's Longcoat", 2), 1],
		[ItemDB.tiered("pistol", 2), 1]])

	# the crew
	den = GruntCamp.new()
	den.name = "PirateDen"
	den.respawn_time = 180.0
	den.respawn_clearance = 60.0
	den.position = Vector3(c.x, 0.0, c.y)
	add_child(den)
	var g_yaw := func(from: Vector2, look_at: Vector2) -> float:
		var d := look_at - from
		return atan2(-d.x, -d.y)
	var v3 := func(q: Vector2, y: float = INF) -> Vector3: return Vector3(q.x - c.x, hv(q) if y == INF else y, q.y - c.y)
	var sit_a: Vector2 = log_a + (c - log_a).normalized() * 0.15
	var sit_b: Vector2 = log_b + (c - log_b).normalized() * 0.15
	den.add_grunt({"post": v3.call(sit_a), "yaw": g_yaw.call(sit_a, c), "mode": "sit", "seat_y": 0.42, "seed": 61})
	den.add_grunt({"post": v3.call(sit_b), "yaw": g_yaw.call(sit_b, c), "mode": "sit", "seat_y": 0.42, "seed": 67})
	var route := [v3.call(at.call(-4.0, 7.0)), v3.call(at.call(4.0, 8.0)), v3.call(at.call(6.0, -8.0)), v3.call(at.call(-5.0, -9.0))]
	den.add_grunt({"post": route[0], "yaw": 0.0, "mode": "patrol", "patrol": route, "seed": 71})
	var pier_guard: Vector2 = root + s * 2.6 - f * 1.5
	den.add_grunt({"post": v3.call(pier_guard), "yaw": g_yaw.call(pier_guard, pier_guard - f), "mode": "stand", "seed": 79})
	var tower_guard: Vector2 = tower_p - f * 3.0
	den.add_grunt({"post": v3.call(tower_guard), "yaw": g_yaw.call(tower_guard, tower_guard - f), "mode": "stand", "seed": 83, "role": "rifle"})
	var pier_end: Vector2 = pier_pt.call(DEN_PIER - 3.0)
	den.add_grunt({"post": v3.call(pier_end, DOCK_DECK_Y), "yaw": g_yaw.call(pier_end, pier_end - f), "mode": "stand", "seed": 89, "role": "rifle"})
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var lk := PirateGrunt.crew_look(rng)
	lk.merge({"name": "Captain Grell", "body": "masc", "build": "broad", "height": 1.12, "hat": "tricorn", "hat_color": C[5],
		"coat": "longcoat", "coat_color": C[13], "trim_color": CharacterLook.TRIM[4], "facial_hair": "beard",
		"vest": "brigandine", "eyepatch": true, "marks": "scar"}, true)
	var cap_post: Vector2 = cap_p + f * 5.0 - s * 1.0
	den.add_grunt({"post": v3.call(cap_post), "yaw": g_yaw.call(cap_post, cap_post + f), "mode": "stand", "seed": 97,
		"look": lk, "captain": true, "title": "Captain Grell"})


## The brood queen's cave on its clearing in the deep forest (BroodCave).
var cave: BroodCave

func _build_cave() -> void:
	reserve(CAVE, 32.0)
	cave = BroodCave.new()
	cave.name = "BroodCave"
	cave.position = Vector3(CAVE.x, hv(CAVE), CAVE.y)
	add_child(cave)


## A strongbox (a LootBag with the treasure-chest model). `items`: [id or ItemData, count].
func _strongbox(p: Vector2, yaw: float, save_id: String, items: Array, size: float = 1.15) -> LootBag:
	var bag := (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate() as LootBag
	var stacks: Array[ItemStack] = []
	for e in items:
		var st := ItemStack.new()
		st.item = e[0] if e[0] is ItemData else ItemDB.get_item(str(e[0]))
		st.quantity = int(e[1])
		stacks.append(st)
	bag.setup(stacks)
	bag.save_id = save_id
	place(bag, p, yaw)
	var chest_mesh := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
	chest_mesh.mesh = Props.treasure_chest_mesh()
	chest_mesh.position = Vector3.ZERO
	chest_mesh.scale = Vector3.ONE * size
	return bag


## A lookout tower: four posts, a railed platform at 6 m, a ladder up the
## +Z side.
func _lookout_tower() -> StaticBody3D:
	const H := 6.0
	const W := 1.4
	var body := StaticBody3D.new()
	body.name = "LookoutTower"
	var mb := MeshBuilder.new()
	var wood := PSXMat.lit("bark")
	var planks := PSXMat.lit("planks_dark")
	for sx in [-W, W]:
		for sz in [-W, W]:
			mb.add_cylinder(wood, Transform3D(Basis(), Vector3(sx, -0.6, sz)), 0.14, 0.12, H + 1.8, 5, 1.0)
			_cyl_col(body, 0.14, H + 1.8, Vector3(sx, H * 0.5 + 0.3, sz))
	# cross bracing on the sides
	for side in range(4):
		var b := Basis(Vector3.UP, side * PI * 0.5)
		mb.add_box(wood, Transform3D(b * Basis(Vector3.BACK, atan2(W * 2.0, 4.5)), b * Vector3(0, 2.8, W)), Vector3(0.1, Vector2(W * 2.0, 4.5).length(), 0.1), 1.0)
	mb.add_box(planks, Transform3D(Basis(), Vector3(0, H, 0)), Vector3(W * 2 + 0.6, 0.18, W * 2 + 0.6), 0.6)
	_box_col(body, Vector3(W * 2 + 0.6, 0.2, W * 2 + 0.6), Vector3(0, H, 0))
	# rail on three sides, the ladder side open above the rungs
	var e := W + 0.3
	for k in range(4):
		var b := Basis(Vector3.UP, k * PI * 0.5)
		var top := b * Vector3(0, H + 1.0, e)
		if k == 0:
			for x in [-e, e]:
				mb.add_box(wood, Transform3D(Basis(), Vector3(x, H + 0.5, e)), Vector3(0.1, 1.0, 0.1), 1.0)
			mb.add_box(wood, Transform3D(Basis(), Vector3(0, H + 1.0, e)), Vector3(e * 2, 0.08, 0.08), 1.0)
			continue
		mb.add_box(planks, Transform3D(b, b * Vector3(0, H + 0.5, e)), Vector3(e * 2, 1.0, 0.08), 0.6)
		_box_col(body, (b * Vector3(e * 2, 1.0, 0.1)).abs(), b * Vector3(0, H + 0.5, e))
		mb.add_box(wood, Transform3D(b, top), Vector3(e * 2 + 0.1, 0.1, 0.14), 1.0)
	# a little roof against the sun
	mb.add_pyramid_roof(PSXMat.lit("thatch"), Transform3D(Basis(), Vector3(0, H + 2.3, 0)), e * 2 + 0.5, e * 2 + 0.5, 1.1)
	for x in [-e, e]:
		for z in [-e, e]:
			mb.add_box(wood, Transform3D(Basis(), Vector3(x, H + 1.65, z)), Vector3(0.08, 1.3, 0.08), 1.0)
	body.add_child(mb.to_instance("TowerMesh"))
	var lad := Ladder.new()
	lad.length = H
	lad.rail = 1.0
	lad.deck_depth = 1.0
	lad.position = Vector3(0, H + 0.09, e)
	body.add_child(lad)
	return body


func _cyl_col(body: Node3D, r: float, h: float, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	cs.shape = shape
	cs.position = at
	body.add_child(cs)


func _box_col(body: Node3D, size: Vector3, at: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = at
	body.add_child(cs)


# ==========================================================================
# Scuttlebugs: a few knee-high beetles around burrows in the jungle along
# the ruins path (the tavern regulars warn you about them).
# ==========================================================================
var bug_nest: ScuttlebugNest

func _build_scuttlebugs() -> void:
	bug_nest = ScuttlebugNest.new()
	bug_nest.name = "ScuttlebugNest"
	add_child(bug_nest)
	# rough spots: off the ruins path and through the deep forest, each nudged
	# to clear, gentle ground
	var wanted := [[Vector2(-27, 18), false], [Vector2(-40, 31), false], [Vector2(-37, 48), false], [Vector2(-56, 37), true],
		[Vector2(-88, 78), false], [Vector2(-102, 38), false], [Vector2(-118, 90), true], [Vector2(-94, 106), false],
		[Vector2(-142, 100), false], [Vector2(-126, 16), false], [Vector2(-160, 80), true]]
	for w in wanted:
		var p := _find_burrow_spot(w[0])
		var yaw := face_yaw(-_nearest_path_dir(p))  # hole (-Z) faces the path
		var b := Props.burrow(int(absf(p.x * 13.0 + p.y * 7.0)))
		place(b, p, yaw, 0.0, -0.08)
		reserve(p, 4.5)
		var front := p + Vector2(-sin(yaw), -cos(yaw)) * 1.8
		bug_nest.add_spot(Vector3(front.x, hv(front), front.y), bool(w[1]))


func _find_burrow_spot(c: Vector2) -> Vector2:
	var best := c
	var best_score := INF
	for i in range(40):
		var a := float(i) * 2.399
		var r := sqrt(float(i)) * 1.2
		var p := c + Vector2(cos(a), sin(a)) * r
		var pd := _path_dist(p)
		if pd < 5.0 or hv(p) < 1.5 or _excluded(p, 2.0):
			continue
		var score := _slope_at(p) * 10.0 + r * 0.1 + absf(pd - 7.0) * 0.05
		if score < best_score:
			best_score = score
			best = p
	return best


## Spitters hiding up in the big deep-forest trees, well apart, clear of the
## cave mouth and the burrows.
var spitters: ScuttlebugNest
const SPITTERS := 9

func _build_spitters() -> void:
	spitters = ScuttlebugNest.new()
	spitters.name = "SpitterRoosts"
	spitters.respawn_time = 60.0
	add_child(spitters)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var taken: Array = []
	for s in bug_nest.spots:
		taken.append(Vector2((s["pos"] as Vector3).x, (s["pos"] as Vector3).z))
	var order := range(forest_crowns.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for i in order:
		if spitters.spots.size() >= SPITTERS:
			break
		var crown: Vector3 = forest_crowns[i]
		var a := rng.randf() * TAU
		var anchor := crown + Vector3(cos(a) * 1.4, -1.3, sin(a) * 1.4)
		var g := Vector2(anchor.x, anchor.z)
		if g.distance_to(FOREST) > 72.0 or g.distance_to(CAVE) < 36.0 or _slope_at(g) > 0.3 or anchor.y - hv(g) < 6.0:
			continue
		var clear := true
		for q in taken:
			if g.distance_to(q) < 16.0:
				clear = false
				break
		if not clear:
			continue
		taken.append(g)
		spitters.add_spitter(anchor, Vector3(g.x, hv(g), g.y))


## Direction from p toward the nearest path (the burrow's hole faces it).
func _nearest_path_dir(p: Vector2) -> Vector2:
	var best := Vector2(0, -1)
	var bd := INF
	for path in paths:
		var pts: PackedVector2Array = path
		for q in pts:
			var d := p.distance_squared_to(q)
			if d < bd:
				bd = d
				best = q - p
	return best.normalized() if best.length() > 0.01 else Vector2(0, -1)


# ==========================================================================
# Vegetation
# ==========================================================================
func _scatter_vegetation() -> void:
	var palms := [Props.palm_mesh(11), Props.palm_mesh(12), Props.palm_mesh(13)]
	var jungle := [Props.jungle_tree_mesh(21), Props.jungle_tree_mesh(22), Props.jungle_tree_mesh(23)]
	var bushes := [Props.bush_mesh(31), Props.bush_mesh(32)]
	var ferns := [Props.fern_mesh(41), Props.fern_mesh(42)]
	var grass := Props.grass_mesh()
	var rocks := [Props.rock_mesh(51, 1.0), Props.rock_mesh(52, 1.0, true), Props.rock_mesh(53, 1.0)]
	var buckets := {}
	var rng := _rng

	# --- trees and rocks on a 5 m jittered grid ---
	var step := 5.0
	var x := -HALF + 3.0
	while x < HALF - 3.0:
		var z := -HALF + 3.0
		while z < HALF - 3.0:
			var p := Vector2(x + rng.randf_range(-2.0, 2.0), z + rng.randf_range(-2.0, 2.0))
			z += step
			var h := hv(p)
			if h < -1.6:
				continue
			if _excluded(p, 1.0):
				continue
			var slope := _slope_at(p)
			var pd := _path_dist(p)
			var roll := rng.randf()
			if h < 0.7:
				if h > -1.4 and roll < 0.05:
					_add_rock(buckets, rocks, p, rng.randf_range(0.6, 1.6), rng)
				continue
			if slope > 0.5:
				if roll < 0.35:
					_add_rock(buckets, rocks, p, rng.randf_range(0.8, 2.2), rng)
				continue
			if pd < 3.0:
				continue
			var beach := 1.0 - _smooth(2.0, 3.8, h)
			var jung := _jungle(p)
			var deep := 1.0 - _smooth(30.0, 75.0, p.distance_to(FOREST))
			var vill := 1.0 - _smooth(28.0, 45.0, p.distance_to(VILLAGE))
			var hill := 1.0 - _smooth(18.0, 40.0, p.distance_to(HILL))
			var cove := 1.0 - _smooth(20.0, 40.0, p.distance_to(COVE))
			# the broad north-west beach stays mostly open sand
			var p_palm := (0.32 * beach * (1.0 - 0.75 * _beach_lobe(p)) + 0.05 * (1.0 - beach) * (1.0 - jung) + 0.06 * jung + 0.15 * cove) * (1.0 - 0.75 * vill) * (1.0 - hill)
			var p_jungle := (0.6 + 0.2 * deep) * jung * (1.0 - beach) * (1.0 - vill)
			var p_rock := 0.02 + 0.1 * hill
			if roll < p_palm:
				_add_tree(buckets, palms, p, h, rng, 0.35, 3.0)
			elif roll < p_palm + p_jungle:
				var tree := _add_tree(buckets, jungle, p, h, rng, 0.45, 3.5, rng.randf_range(0.85, 1.25) + 0.3 * deep)
				if deep > 0.3:
					forest_crowns.append(tree)
			elif roll < p_palm + p_jungle + p_rock:
				_add_rock(buckets, rocks, p, rng.randf_range(0.5, 1.8), rng)
		x += step

	# --- undergrowth on a 2.5 m grid ---
	step = 2.5
	x = -HALF + 3.0
	while x < HALF - 3.0:
		var z := -HALF + 3.0
		while z < HALF - 3.0:
			var p := Vector2(x + rng.randf_range(-1.1, 1.1), z + rng.randf_range(-1.1, 1.1))
			z += step
			var h := hv(p)
			if h < 1.4:
				continue
			if _excluded(p, -0.5):
				continue
			if _slope_at(p) > 0.45:
				continue
			var pd := _path_dist(p)
			if pd < 0.6:
				continue
			if p.distance_to(VILLAGE) < 15.0 or p.distance_to(TRAINING) < 11.0 or p.distance_to(RUINS) < 9.0:
				continue
			var beach := 1.0 - _smooth(2.2, 3.6, h)
			var jung := _jungle(p)
			var roll := rng.randf()
			var p_fern := 0.32 * jung * (1.0 - beach)
			var p_bush := (0.05 + 0.14 * jung) * (1.0 - beach * 0.7)
			var p_grass := (0.3 * (1.0 - jung * 0.5) + 0.05) * (1.0 - beach * 0.8)
			if pd < 2.0:
				p_fern = 0.0
				p_bush = 0.0
				p_grass *= 0.5
			var basis := Basis(Vector3.UP, rng.randf() * TAU)
			if roll < p_fern:
				_bucket(buckets, ferns[rng.randi() % ferns.size()], Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(p.x, h - 0.05, p.y)))
			elif roll < p_fern + p_bush:
				_bucket(buckets, bushes[rng.randi() % bushes.size()], Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), Vector3(p.x, h - 0.1, p.y)))
			elif roll < p_fern + p_bush + p_grass:
				_bucket(buckets, grass, Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), Vector3(p.x, h - 0.05, p.y)))
		x += step

	# --- commit MultiMeshes: one per mesh per VEG_CELL square, so only the
	# squares in view (and in the sun's shadow range) are drawn; the small
	# stuff stops drawing a little way off ---
	var vegetation := Node3D.new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	for key in buckets.keys():
		var mesh: Mesh = key[0]
		var xforms: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in range(xforms.size()):
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if mesh == grass or ferns.has(mesh):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 90.0
		elif bushes.has(mesh):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 160.0
		vegetation.add_child(mmi)


const VEG_CELL := 70.0

## Island-space crowns of the big deep-forest trees (where the spitters hide).
var forest_crowns: Array = []


func _jungle(p: Vector2) -> float:
	return maxf(1.0 - _smooth(50.0, 80.0, p.distance_to(JUNGLE_HIGH)), 1.0 - _smooth(72.0, 112.0, p.distance_to(FOREST)))


func _bucket(buckets: Dictionary, mesh: Mesh, xf: Transform3D) -> void:
	var key := [mesh, floori(xf.origin.x / VEG_CELL), floori(xf.origin.z / VEG_CELL)]
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(xf)


func _add_tree(buckets: Dictionary, meshes: Array, p: Vector2, h: float, rng: RandomNumberGenerator,
		col_r: float, col_h: float, s: float = -1.0) -> Vector3:
	if s < 0.0:
		s = rng.randf_range(0.85, 1.15)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
	var tree_mesh: Mesh = meshes[rng.randi() % meshes.size()]
	var xf := Transform3D(basis, Vector3(p.x, h - 0.15, p.y))
	_bucket(buckets, tree_mesh, xf)
	# the crown is something a vine can latch onto
	var crown := xf * GrapplePoints.crown_of(tree_mesh)
	GrapplePoints.add(self, crown)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = col_r * s
	shape.height = col_h
	cs.shape = shape
	cs.position = Vector3(p.x, h + col_h * 0.5, p.y)
	_tree_colliders.add_child(cs)
	reserve(p, 1.2)
	return crown


func _add_rock(buckets: Dictionary, meshes: Array, p: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	var h := _ground_min(p, s * 0.8)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
	_bucket(buckets, meshes[rng.randi() % meshes.size()], Transform3D(basis, Vector3(p.x, h - 0.1 * s, p.y)))
	if s > 0.7:
		var cs := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = s * 0.85
		cs.shape = shape
		cs.position = Vector3(p.x, h + s * 0.1, p.y)
		_tree_colliders.add_child(cs)
	reserve(p, s)


# ==========================================================================
# NPCs
# ==========================================================================
## `face` is the direction the NPC looks at when idle.
func _npc(cfg: Dictionary, p: Vector2, face: Vector2, y: float = INF) -> NPC:
	var npc := NPC.new()
	cfg["yaw"] = atan2(-face.x, -face.y)
	npc.setup(cfg)
	npc.ground_func = walk_height
	npc.position = Vector3(p.x, hv(p) if y == INF else y, p.y)
	add_child(npc)
	return npc


func _spawn_npcs() -> void:
	# Harbormaster at her booth by the pier
	_npc({
		"name": "Harbormaster Odile", "dialogue": "odile", "voice": 1.15,
		"look": {"body": "fem", "build": "average", "height": 1.02, "skin": CharacterLook.SKIN_TONES[4],
			"head": "square", "nose": "straight", "eyes": 4, "brows": 3, "mouth": 0, "eye_color": CharacterLook.EYE_COLORS[0],
			"hair": "bun", "hair_color": CharacterLook.HAIR_COLORS[0], "hat": "cap", "hat_color": CharacterLook.CLOTH[8],
			"top": "shirt", "top_color": CharacterLook.CLOTH[1], "coat": "jacket", "coat_color": CharacterLook.CLOTH[8],
			"trim_color": CharacterLook.TRIM[0], "legs": "trousers", "legs_color": CharacterLook.CLOTH[6],
			"feet": "tall_boots", "feet_color": CharacterLook.LEATHER[0], "belt": "belt", "belt_color": CharacterLook.LEATHER[1],
			"pouch": true},
	}, odile_at, odile_face)

	# the shipwright by the boat he's building (talk: his yard, GameMenu "yard")
	_npc({
		"name": "Shipwright Tackett", "dialogue": "tackett", "voice": 0.78,
		"look": {"body": "masc", "build": "broad", "height": 1.0, "skin": CharacterLook.SKIN_TONES[2],
			"head": "square", "nose": "broad", "eyes": 2, "brows": 1, "mouth": 2,
			"hair": "crop", "hair_color": CharacterLook.HAIR_COLORS[3], "facial_hair": "chops", "hat": "none",
			"top": "shirt", "top_color": CharacterLook.CLOTH[2], "sleeves": "short", "apron": true, "apron_color": CharacterLook.LEATHER[1],
			"legs": "trousers", "legs_color": CharacterLook.CLOTH[6], "feet": "boots", "feet_color": CharacterLook.LEATHER[0],
			"belt": "belt", "belt_color": CharacterLook.LEATHER[2]},
	}, tackett_at, Vector2(-1, 0.25))

	# Tavern keeper behind his bar, inside
	var gus_p := _marker_point(_tavern, "Barkeep")
	_npc({
		"name": "Gus Brannock", "dialogue": "gus", "voice": 0.72,
		"look": {"body": "masc", "build": "stout", "height": 1.05, "skin": CharacterLook.SKIN_TONES[1],
			"head": "round", "nose": "broad", "eyes": 0, "brows": 1, "mouth": 1,
			"hair": "bald", "hair_color": CharacterLook.HAIR_COLORS[1], "facial_hair": "beard", "hat": "none",
			"top": "shirt", "top_color": CharacterLook.CLOTH[0], "sleeves": "short", "apron": true, "apron_color": CharacterLook.CLOTH[0],
			"legs": "trousers", "legs_color": CharacterLook.CLOTH[3], "feet": "boots", "feet_color": CharacterLook.LEATHER[1],
			"belt": "belt", "belt_color": CharacterLook.LEATHER[2]},
	}, gus_p, _marker_face(_tavern, "Barkeep"), _marker_y(_tavern, "Barkeep"))

	# the old net-mender on his bench at the quay's edge, looking out to sea
	_npc({
		"name": "Old Pell", "dialogue": "pell", "voice": 0.82, "seated": true,
		"look": {"body": "masc", "build": "slim", "height": 0.96, "skin": CharacterLook.SKIN_TONES[3],
			"head": "long", "nose": "hooked", "eyes": 3, "brows": 4, "mouth": 0, "marks": "age_lines",
			"hair": "crop", "hair_color": CharacterLook.HAIR_COLORS[8], "facial_hair": "long_beard", "hat": "straw",
			"hat_color": CharacterLook.CLOTH[13], "top": "tunic", "top_color": CharacterLook.CLOTH[10], "sleeves": "short",
			"legs": "breeches", "legs_color": CharacterLook.CLOTH[2], "feet": "barefoot", "belt": "sash",
			"sash_color": CharacterLook.CLOTH[1], "scarf": true, "scarf_color": CharacterLook.CLOTH[13]},
	}, pell_at, dock_dir, QUAY_Y)

	# Retired marine in the training yard
	_npc({
		"name": "Sergeant Vey", "dialogue": "vey", "voice": 0.9,
		"look": {"body": "masc", "build": "broad", "height": 1.05, "skin": CharacterLook.SKIN_TONES[5],
			"head": "square", "nose": "broad", "eyes": 1, "brows": 3, "mouth": 3,
			"hair": "crop", "hair_color": CharacterLook.HAIR_COLORS[7], "facial_hair": "chops", "hat": "bicorne",
			"hat_color": CharacterLook.CLOTH[5], "top": "shirt", "top_color": CharacterLook.CLOTH[0],
			"coat": "jacket", "coat_color": CharacterLook.CLOTH[13], "trim_color": CharacterLook.TRIM[2],
			"legs": "trousers", "legs_color": CharacterLook.CLOTH[0], "feet": "tall_boots", "feet_color": CharacterLook.LEATHER[0],
			"belt": "belt", "belt_color": CharacterLook.LEATHER[0], "pauldron": true},
	}, TRAINING + Vector2(3, 2), Vector2(1, 0))

	# Trader at the fruit stall in the market
	_npc({
		"name": "Nessa", "dialogue": "nessa", "voice": 1.25,
		"look": {"body": "fem", "build": "average", "skin": CharacterLook.SKIN_TONES[6],
			"head": "round", "nose": "small", "eyes": 5, "brows": 2, "mouth": 1,
			"hair": "braids", "hair_color": CharacterLook.HAIR_COLORS[0], "hat": "bandana", "hat_color": CharacterLook.CLOTH[15],
			"top": "blouse", "top_color": CharacterLook.CLOTH[13], "vest": "corset", "vest_color": CharacterLook.CLOTH[3],
			"legs": "skirt", "legs_color": CharacterLook.CLOTH[14], "feet": "shoes", "feet_color": CharacterLook.LEATHER[2],
			"belt": "sash", "sash_color": CharacterLook.CLOTH[15], "earring": true},
	}, _marker_point(_stall_a, "Vendor"), _marker_face(_stall_a, "Vendor"))

	# the other market vendors
	_npc({
		"name": "Marlo", "voice": 0.85, "shop": "marlo",
		"barks": [
			"Fresh off the boat! Well. Fresh-ish. Off a boat.",
			"Snapper, mackerel, something with too many teeth. Pick one.",
			"Gus buys my fish for his stew. Don't ask him what else goes in it.",
			{"text": "Smugglers gone off the south beach, and the boats come home full. Coincidence? Marlo thinks not.", "after": "smugglers"},
		],
		"look": {"body": "masc", "build": "stout", "skin": CharacterLook.SKIN_TONES[2],
			"head": "square", "nose": "broad", "eyes": 0, "brows": 1, "mouth": 2,
			"hair": "crop", "hair_color": CharacterLook.HAIR_COLORS[1], "facial_hair": "moustache", "hat": "cap",
			"hat_color": CharacterLook.CLOTH[10], "top": "shirt", "top_color": CharacterLook.CLOTH[0], "sleeves": "short",
			"apron": true, "apron_color": CharacterLook.CLOTH[7], "legs": "breeches", "legs_color": CharacterLook.CLOTH[8],
			"feet": "boots", "feet_color": CharacterLook.LEATHER[1], "belt": "belt", "belt_color": CharacterLook.LEATHER[1]},
	}, _marker_point(_stall_fish, "Vendor"), _marker_face(_stall_fish, "Vendor"))
	_npc({
		"name": "Clothier Sela", "voice": 1.2, "shop": "sela",
		"barks": [
			"Sailcloth, silk, and wool from three islands over. Touch with your eyes, Captain.",
			"That coat of yours has seen weather. Sell me the old one, wear something better.",
			"Blue's the fashion this season. Blue's always the fashion at sea.",
		],
		"look": {"body": "fem", "build": "slim", "height": 1.03, "skin": CharacterLook.SKIN_TONES[5],
			"head": "long", "nose": "small", "eyes": 4, "brows": 2, "mouth": 4,
			"hair": "long", "hair_color": CharacterLook.HAIR_COLORS[0], "hat": "none",
			"top": "blouse", "top_color": CharacterLook.CLOTH[16], "vest": "vest", "vest_color": CharacterLook.CLOTH[15],
			"legs": "skirt", "legs_color": CharacterLook.CLOTH[9], "feet": "shoes", "feet_color": CharacterLook.LEATHER[3],
			"belt": "sash", "sash_color": CharacterLook.CLOTH[15], "earring": true, "scarf": true, "scarf_color": CharacterLook.CLOTH[9]},
	}, _marker_point(_stall_cloth, "Vendor"), _marker_face(_stall_cloth, "Vendor"))
	_npc({
		"name": "Old Ida", "voice": 1.05, "shop": "ida",
		"barks": [
			"Pots, jugs, jars. Everything here holds water except my patience.",
			"Thrown on my own wheel, fired in my own kiln, dropped by my own nephew.",
			"Hardtack, Captain. Packed in my jars, it'll outlast your ship.",
		],
		"look": {"body": "fem", "build": "average", "height": 0.92, "skin": CharacterLook.SKIN_TONES[1],
			"head": "round", "nose": "hooked", "eyes": 3, "brows": 4, "mouth": 0, "marks": "age_lines",
			"hair": "bun", "hair_color": CharacterLook.HAIR_COLORS[8], "hat": "knit", "hat_color": CharacterLook.CLOTH[2],
			"top": "tunic", "top_color": CharacterLook.CLOTH[12], "sleeves": "long", "apron": true, "apron_color": CharacterLook.CLOTH[2],
			"legs": "skirt", "legs_color": CharacterLook.CLOTH[4], "feet": "shoes", "feet_color": CharacterLook.LEATHER[1], "belt": "none"},
	}, _marker_point(_stall_pots, "Vendor"), _marker_face(_stall_pots, "Vendor"))

	# tavern regulars, seated
	var patrons := [
		{"name": "Dunk", "voice": 0.78, "barks": [
			"Another round? Don't mind if I do. Don't mind if I don't, either.",
			"I was a pirate once. For an afternoon. Lovely afternoon.",
			"Mind the bugs in the jungle, friend. Big ones. Head-butt you right off your feet."],
		 "look": {"body": "masc", "build": "stout", "skin": CharacterLook.SKIN_TONES[3], "hair": "short",
			"hair_color": CharacterLook.HAIR_COLORS[3], "facial_hair": "beard", "top": "shirt", "top_color": CharacterLook.CLOTH[2],
			"vest": "vest", "vest_color": CharacterLook.CLOTH[4], "legs": "trousers", "legs_color": CharacterLook.CLOTH[3], "hat": "none"}},
		{"name": "Moira", "voice": 1.15, "barks": [
			"Gus says the rum's aged. Aged a week, maybe.",
			"You've the look of someone who's going to do something foolish. I like it.",
			"The scuttlebugs come out under the jungle trees. Hit 'em when they're dizzy from charging.",
			{"text": "Grell's lot used to drink here and never pay. You've done Gus a favour, and Gus doesn't forget those.", "after": "grell"}],
		 "look": {"body": "fem", "build": "average", "skin": CharacterLook.SKIN_TONES[0], "hair": "ponytail",
			"hair_color": CharacterLook.HAIR_COLORS[5], "top": "blouse", "top_color": CharacterLook.CLOTH[9],
			"vest": "corset", "vest_color": CharacterLook.CLOTH[14], "legs": "skirt", "legs_color": CharacterLook.CLOTH[5], "hat": "none"}},
		{"name": "Quiet Tobin", "voice": 0.95, "barks": ["...", "Mm.", "...the sea remembers."],
		 "look": {"body": "masc", "build": "slim", "skin": CharacterLook.SKIN_TONES[6], "hair": "long",
			"hair_color": CharacterLook.HAIR_COLORS[0], "hat": "hood", "hat_color": CharacterLook.CLOTH[6],
			"top": "tunic", "top_color": CharacterLook.CLOTH[6], "coat": "longcoat", "coat_color": CharacterLook.CLOTH[5],
			"legs": "trousers", "legs_color": CharacterLook.CLOTH[5]}},
	]
	for i in range(patrons.size()):
		var cfg: Dictionary = patrons[i]
		cfg["seated"] = true
		var mk := "Patron%d" % (i + 1)
		_npc(cfg, _marker_point(_tavern, mk), _marker_face(_tavern, mk), _marker_y(_tavern, mk))

	# the smith at his anvil
	_npc({
		"name": "Haldor the Smith", "voice": 0.7,
		"barks": [
			"Every blade on this island's been through my fire. Twice, if the owner was careless.",
			"Bring me something to mend and gold to mend it with. Not in that order.",
			{"text": "Bug chitin? Takes an edge better than iron, I'll grant. Smells worse.", "before": "queen"},
			{"text": "That's queen chitin on Tackett's keel, I hear. I'd have made a fine blade of it. Typical.", "after": "queen"},
			"Hear that hammer? That's the sound of Brinehollow not being robbed.",
		],
		"look": {"body": "masc", "build": "broad", "height": 1.06, "skin": CharacterLook.SKIN_TONES[4],
			"head": "square", "nose": "broad", "eyes": 1, "brows": 1, "mouth": 3, "marks": "scar",
			"hair": "bald", "hair_color": CharacterLook.HAIR_COLORS[1], "facial_hair": "beard", "hat": "none",
			"top": "bare", "apron": true, "apron_color": CharacterLook.LEATHER[0],
			"legs": "trousers", "legs_color": CharacterLook.CLOTH[6], "feet": "boots", "feet_color": CharacterLook.LEATHER[0],
			"belt": "belt", "belt_color": CharacterLook.LEATHER[1], "gloves": true, "gloves_color": CharacterLook.LEATHER[2]},
	}, _marker_point(_smithy, "Smith"), _marker_face(_smithy, "Smith"), _marker_y(_smithy, "Smith"))

	# Lighthouse keeper on the hill
	_npc({
		"name": "Keeper Ambrose", "dialogue": "ambrose", "voice": 0.8,
		"look": {"body": "masc", "build": "average", "skin": CharacterLook.SKIN_TONES[1],
			"head": "long", "nose": "straight", "eyes": 3, "brows": 0, "mouth": 0, "eye_color": CharacterLook.EYE_COLORS[4],
			"hair": "short", "hair_color": CharacterLook.HAIR_COLORS[7], "facial_hair": "beard", "hat": "hood",
			"hat_color": CharacterLook.CLOTH[6], "top": "shirt", "top_color": CharacterLook.CLOTH[7],
			"coat": "longcoat", "coat_color": CharacterLook.CLOTH[3], "legs": "trousers", "legs_color": CharacterLook.CLOTH[4],
			"feet": "boots", "feet_color": CharacterLook.LEATHER[1], "belt": "belt", "belt_color": CharacterLook.LEATHER[1],
			"gloves": true, "gloves_color": CharacterLook.LEATHER[2]},
	}, HILL + Vector2(-5, 4.5), Vector2(-1, 0.2))

	# Castaway at the cove campfire
	_npc({
		"name": "Wren", "dialogue": "wren", "voice": 1.1,
		"look": {"body": "fem", "build": "slim", "skin": CharacterLook.SKIN_TONES[3],
			"head": "round", "nose": "small", "eyes": 4, "brows": 0, "mouth": 4, "marks": "freckles",
			"hair": "wild", "hair_color": CharacterLook.HAIR_COLORS[4], "hat": "bandana", "hat_color": CharacterLook.CLOTH[13],
			"top": "shirt", "top_color": CharacterLook.CLOTH[1], "sleeves": "none",
			"legs": "shorts", "legs_color": CharacterLook.CLOTH[2], "feet": "barefoot", "belt": "belt_sash",
			"belt_color": CharacterLook.LEATHER[2], "sash_color": CharacterLook.CLOTH[10], "eyepatch": true, "earring": true},
	}, CAMP + Vector2(-1.5, 1.8), Vector2(1.5, -1.8))

	# Wandering villagers with one-liners
	var ring: Array = []
	for i in range(5):
		var a := TAU * i / 5.0
		var q := VILLAGE + Vector2(cos(a), sin(a)) * 9.0
		ring.append(Vector3(q.x, hv(q), q.y))
	_npc({
		"name": "Tilly", "voice": 1.3,
		"barks": [
			"Morning, Captain! Mind the chickens. We don't have chickens. Yet.",
			"Gus waters the rum, but don't tell him I said so.",
			"If you're heading into the jungle, take a lantern. Or a braver friend.",
			"The lighthouse keeper talks to the sea. Sometimes I think it answers.",
			"Something up in the big trees out west spits. Mind your head in the deep woods.",
			{"text": "Is it true you can't remember anything? Not even your birthday? I'd pick a new one. Something in summer.", "before": "smugglers"},
			{"text": "They say you put Captain Grell in the sand! Mum says you're a hero. Dad says you're trouble.", "after": "grell"},
		],
		"look": {"body": "fem", "build": "average", "height": 0.93, "skin": CharacterLook.SKIN_TONES[0],
			"head": "round", "nose": "small", "eyes": 2, "brows": 2, "mouth": 1, "marks": "freckles", "eye_color": CharacterLook.EYE_COLORS[2],
			"hair": "bun", "hair_color": CharacterLook.HAIR_COLORS[4], "hat": "none",
			"top": "blouse", "top_color": CharacterLook.CLOTH[12], "apron": true, "apron_color": CharacterLook.CLOTH[1],
			"legs": "skirt", "legs_color": CharacterLook.CLOTH[3], "feet": "shoes", "feet_color": CharacterLook.LEATHER[1],
			"belt": "none"},
		"waypoints": ring,
	}, Vector2(ring[0].x, ring[0].z), Vector2(0, 1))

	var fish_route: Array = []
	for q in [dock_shore + Vector2(-8.0, 9.0), dock_shore + Vector2(3.0, 12.0), VILLAGE + Vector2(8, -26), VILLAGE + Vector2(3, -14)]:
		fish_route.append(Vector3(q.x, hv(q), q.y))
	_npc({
		"name": "Bram", "voice": 0.95,
		"barks": [
			{"text": "Nets came up empty again. The smugglers on the south beach scare the fish. And me.", "before": "smugglers"},
			{"text": "Boats are safe off the south beach again. Drinks are on me. Well. On Gus.", "after": "smugglers"},
			"Saw lights out past the reef last night. Not lanterns. Something else.",
			"Odile won't let me tie up past sundown. Says the tide gets hungry.",
		],
		"look": {"body": "masc", "build": "broad", "skin": CharacterLook.SKIN_TONES[4],
			"head": "round", "nose": "straight", "eyes": 0, "brows": 1, "mouth": 0,
			"hair": "short", "hair_color": CharacterLook.HAIR_COLORS[2], "facial_hair": "stubble", "hat": "knit",
			"hat_color": CharacterLook.CLOTH[17], "top": "shirt", "top_color": CharacterLook.CLOTH[1], "sleeves": "short",
			"vest": "vest", "vest_color": CharacterLook.CLOTH[8], "trim_color": CharacterLook.TRIM[1],
			"legs": "trousers", "legs_color": CharacterLook.CLOTH[8], "feet": "boots", "feet_color": CharacterLook.LEATHER[0],
			"belt": "belt", "belt_color": CharacterLook.LEATHER[1]},
		"waypoints": fish_route,
	}, Vector2(fish_route[0].x, fish_route[0].z), Vector2(0, 1))


# ==========================================================================
# Loot, arrival banner, ambience
# ==========================================================================
func _spawn_loot() -> void:
	var bag_scene: PackedScene = load("res://scenes/loot/loot_bag.tscn")
	var gold: ItemData = load("res://resources/items/gold.tres")
	var treasure: ItemData = load("res://resources/items/treasure.tres")
	var chest := Props.treasure_chest_mesh()
	var spots := [
		[RUINS + Vector2(-1.5, 2.2), treasure, 1],
		[JUNGLE_STASH, treasure, 1],
		[CAMP + Vector2(-6.0, -4.0), gold, 3],
		[HILL + Vector2(4.0, 3.5), gold, 2],
		[COVE + Vector2(9, -21), gold, 2],
	]
	reserve(JUNGLE_STASH, 3.5)
	# the jungle stash is walled in by dry thornbrush: fire gets you in
	for k in range(4):
		var a := float(k) * PI * 0.5
		var off := Vector2(sin(a), cos(a)) * 2.1
		var bp := JUNGLE_STASH + off
		var thorn := Burnable.new().setup(Vector3(4.6, 2.9, 0.9))
		thorn.name = "Thornbrush%d" % k
		thorn.position = Vector3(bp.x, minf(hv(bp), hv(JUNGLE_STASH)) - 0.25, bp.y)
		thorn.rotation.y = a
		add_child(thorn)
	for s in spots:
		var bag := bag_scene.instantiate() as LootBag
		var stack := ItemStack.new()
		stack.item = s[1]
		stack.quantity = s[2]
		var items: Array[ItemStack] = [stack]
		if s[0] == RUINS + Vector2(-1.5, 2.2):
			var axe := ItemStack.new()
			axe.item = ItemDB.get_item("boarding_axe")
			axe.quantity = 1
			items.append(axe)
		# a few pieces of gear to find
		var gear: ItemData = null
		if s[0] == RUINS + Vector2(-1.5, 2.2):
			gear = Gear.make("accessory", "pauldron", {"pauldron": true}, "Ruin-Warden's Pauldron")
		elif s[0] == CAMP + Vector2(-6.0, -4.0):
			gear = Gear.make("hands", "gloves", {"gloves": true, "gloves_color": CharacterLook.LEATHER[2]})
		elif s[0] == HILL + Vector2(4.0, 3.5):
			gear = Gear.make("head", "bandana", {"hat": "bandana", "hat_color": CharacterLook.CLOTH[13]})
		elif s[0] == COVE + Vector2(9, -21):
			gear = Gear.make("vest", "vest", {"vest": "vest", "vest_color": CharacterLook.CLOTH[11]}, "Weathered Green Vest")
		if gear:
			var gs := ItemStack.new()
			gs.item = gear
			gs.quantity = 1
			items.append(gs)
		# a pistol in the old camp's stash; two more Devil Fruits hidden on
		# the island (the Wolf Fruit in the ruins, the Vine Fruit up the hill);
		# a katana in the cove
		var extra := ""
		if s[0] == CAMP + Vector2(-6.0, -4.0):
			extra = "pistol"
		elif s[0] == RUINS + Vector2(-1.5, 2.2):
			extra = "wolf_fruit"
		elif s[0] == HILL + Vector2(4.0, 3.5):
			extra = "vine_fruit"
		elif s[0] == COVE + Vector2(9, -21):
			extra = "katana"
		if extra != "" and ItemDB.get_item(extra):
			var es := ItemStack.new()
			es.item = ItemDB.get_item(extra)
			es.quantity = 1
			items.append(es)
		bag.setup(items, false)
		var p: Vector2 = s[0]
		bag.save_id = "chest_%d_%d" % [int(round(p.x)), int(round(p.y))]
		bag.position = Vector3(p.x, hv(p), p.y)
		add_child(bag)
		var mi := bag.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mi:
			mi.mesh = chest
			mi.position = Vector3.ZERO
			mi.rotation.y = _rng.randf() * TAU


func _add_arrival_zone() -> void:
	var area := Area3D.new()
	area.name = "ArrivalZone"
	area.collision_layer = 0
	area.collision_mask = 2  # PlayerBody
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 200.0
	cs.shape = sph
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(func(b: Node3D):
		if b.is_in_group("player"):
			get_tree().call_group("hud", "show_banner", "Brinehollow", "A quiet fishing village"))
	Dialogue.dialogue_event.connect(_on_dialogue_event)


func _on_dialogue_event(event_name: String) -> void:
	if event_name == "driftstone_read" and not Dialogue.has_flag("driftstone_found"):
		Dialogue.set_flag("driftstone_found")
		get_tree().call_group("hud", "show_banner", "Driftstone", "The first of many?", true)


