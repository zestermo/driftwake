class_name StarterIsland
extends Island
## Brinehollow — the hand-designed starter island.
##
## Everything is generated from code so it is easy to tweak:
##   * terrain: a 420 m chunk at 3 m resolution with a designed height function
##     (village plateau, lighthouse hill, jungle highlands, a sheltered cove)
##   * per-vertex splat painting for dirt paths / sand / grass
##   * buildings, props, vegetation (MultiMesh), NPCs, loot and ambience
##
## Layout (local coordinates, -Z is north / towards the dock):
##   Village square  (0, -62)      Training yard (-58, -38)
##   Lighthouse hill (78, -30)     Jungle ruins  (-62, 58)
##   Castaway cove   (78, 92)      Dock: north shore, straight out from the village

const EXTENT := 420.0
const CELL := 3.0
const RES := 140
const HALF := EXTENT * 0.5
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

const DOCK_LENGTH := 34.0
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
	_find_dock()
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
	_build_training_yard()
	_build_lighthouse()
	_build_ruins()
	_build_cove()
	_build_beach_camp()
	_build_scuttlebugs()
	_build_smugglers_camp()
	_scatter_vegetation()
	_spawn_npcs()
	_spawn_loot()
	_add_arrival_zone()
	_add_ambience()

	var dock_end := _dock_point(DOCK_LENGTH)
	var side := Vector3(-dock_dir.y, 0, dock_dir.x)
	return {
		"island": self,
		"dock_world_pos": to_global(Vector3(dock_end.x, 0, dock_end.y) + side * 6.0),
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
	_detail_noise.seed = world_seed + 37
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.09
	_detail_noise.fractal_octaves = 2


static func _gauss(p: Vector2, c: Vector2, sigma: float) -> float:
	return exp(-p.distance_squared_to(c) / (2.0 * sigma * sigma))


static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Natural terrain before flattening.
func _height_natural(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.length()
	var ang := atan2(z, x)
	var r := 126.0 + _coast_noise.get_noise_2d(cos(ang) * 50.0, sin(ang) * 50.0) * 16.0
	var t := d - r
	var h: float
	if t < 0.0:
		h = lerpf(0.5, 4.3, pow(clampf(-t / 44.0, 0.0, 1.0), 0.85))
	else:
		h = lerpf(0.5, SEAFLOOR, _smooth(0.0, 60.0, t))
	var inland := clampf(-t / 35.0 - 0.15, 0.0, 1.0)
	h += _roll_noise.get_noise_2d(x, z) * 2.6 * inland
	h += _detail_noise.get_noise_2d(x, z) * 0.45 * inland
	# jungle highlands to the south-west
	h += 5.5 * _gauss(p, JUNGLE_HIGH, 38.0) * inland
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
	return h


func _setup_flat_zones() -> void:
	_flat_zones = [
		[VILLAGE, _height_natural(VILLAGE.x, VILLAGE.y), 24.0, 40.0],
		[TRAINING, _height_natural(TRAINING.x, TRAINING.y), 12.0, 21.0],
		[HILL, _height_natural(HILL.x, HILL.y), 11.0, 17.0],
		[RUINS, _height_natural(RUINS.x, RUINS.y), 10.0, 18.0],
		[SMUGGLERS, maxf(_height_natural(SMUGGLERS.x, SMUGGLERS.y), 1.5), 11.0, 18.0],
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


func hv(p: Vector2) -> float:
	return height_at(p.x, p.y)


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
func _find_dock() -> void:
	var p := VILLAGE
	for i in range(200):
		p += dock_dir
		if _height_fn(p.x, p.y) < 0.8:
			break
	dock_shore = p - dock_dir * 5.0  # start the dock on the beach


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
var _stall_a: Node3D
var _stall_b: Node3D
var _keeper_hut: Node3D

func _build_dock() -> void:
	var dock := Props.dock(DOCK_LENGTH, 3.6, DOCK_DECK_Y, SEAFLOOR * 0.5)
	dock.position = Vector3(dock_shore.x, 0.0, dock_shore.y)
	dock.rotation.y = face_yaw(dock_dir)
	add_child(dock)
	# ladders at the end of the dock for swimmers (end + both sides)
	for spec in [[Vector3(0, DOCK_DECK_Y, DOCK_LENGTH), 0.0], [Vector3(1.8, DOCK_DECK_Y, DOCK_LENGTH - 3.0), PI * 0.5],
			[Vector3(-1.8, DOCK_DECK_Y, DOCK_LENGTH - 3.0), -PI * 0.5]]:
		var lad := Ladder.new()
		lad.length = DOCK_DECK_Y + 1.0
		lad.rail = 0.0
		lad.deck_depth = 0.9
		lad.position = spec[0]
		lad.rotation.y = spec[1]
		dock.add_child(lad)
	for d in range(0, int(DOCK_LENGTH) + 6, 4):
		reserve(_dock_point(d), 3.5)
	# props on the dock
	var side := Vector2(-dock_dir.y, dock_dir.x)
	var b := Props.barrel()
	b.position = Vector3(0, DOCK_DECK_Y, 0) + _v3(_dock_point(10.0) + side * 1.2)
	add_child(b)
	var c := Props.crate(0.8)
	c.position = Vector3(0, DOCK_DECK_Y, 0) + _v3(_dock_point(11.2) + side * 1.1)
	c.rotation.y = 0.3
	add_child(c)
	var rope := Props.rope_coil()
	rope.position = Vector3(0, DOCK_DECK_Y, 0) + _v3(_dock_point(24.0) - side * 1.1)
	add_child(rope)
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
	area.position = _v3(_dock_point(DOCK_LENGTH - 2.0)) + Vector3(0, DOCK_DECK_Y + 1.0, 0)
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
		"porch": 1.6, "sign": "sign_fish", "door_x": 2.0, "name": "Harbor"}, VILLAGE + Vector2(15, -28), Vector2(-1, 0))
	_house({"w": 4.0, "d": 4.5, "floors": 2, "wall": "stone_brick", "wall2": "planks", "roof": "gable",
		"roof_tex": "thatch", "pitch": 0.75, "jetty": 0.3}, VILLAGE + Vector2(-9, -31), Vector2(1, 0.2))
	_house({"w": 5.5, "d": 4.5, "h": 2.5, "roof": "hip", "wall": "plaster", "roof_tex": "thatch", "lean_to": "left", "pitch": 0.5},
		VILLAGE + Vector2(27, 12), Vector2(-1, -0.4))
	# a fisher's shack up on stilts along the beach
	var beach := dock_shore - dock_dir * 3.0 + Vector2(-dock_dir.y, dock_dir.x) * 17.0
	_house({"w": 5.0, "d": 4.0, "h": 2.3, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch", "porch": 1.4},
		beach, -dock_dir, true)

	_build_market()

	place(Props.fish_rack(), dock_shore + Vector2(8, 6), face_yaw(Vector2(-1, 0)), 1.5)
	place(Props.barrel(), dock_shore + Vector2(6, 9), 0.0)
	place(Props.crate(), dock_shore + Vector2(7, 10.5), 0.5)

	place(Props.signpost([PI, 0.0, PI * 0.75, PI * 0.25]), VILLAGE + Vector2(2.5, 17), 0.0, 0.6)

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
	for i in range(6):
		var a := rng.randf() * TAU
		var q := MARKET + Vector2(cos(a), sin(a)) * rng.randf_range(8.0, 9.5)
		if _path_dist(q) < 2.5:
			continue
		place(Props.crate(rng.randf_range(0.55, 0.8)) if i % 2 == 0 else Props.barrel(), q, rng.randf() * TAU, 0.6)
	reserve(MARKET, 9.0)


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
	# the old sailor's beach spot near the dock
	var pell_spot := dock_shore + Vector2(-13, 3)
	place(Props.upturned_boat(), pell_spot + Vector2(-2.5, 0), 0.3, 2.0)
	place(Props.net_pile(), pell_spot + Vector2(1.2, 1.5), 0.0)


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
# Scuttlebugs: a few knee-high beetles around burrows in the jungle along
# the ruins path (the tavern regulars warn you about them).
# ==========================================================================
var bug_nest: ScuttlebugNest

func _build_scuttlebugs() -> void:
	bug_nest = ScuttlebugNest.new()
	bug_nest.name = "ScuttlebugNest"
	add_child(bug_nest)
	# rough spots: off the ruins path, each nudged to clear, gentle ground
	var wanted := [[Vector2(-27, 18), false], [Vector2(-40, 31), false], [Vector2(-37, 48), false], [Vector2(-56, 37), true]]
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
			var jung := 1.0 - _smooth(50.0, 80.0, p.distance_to(JUNGLE_HIGH))
			var vill := 1.0 - _smooth(28.0, 45.0, p.distance_to(VILLAGE))
			var hill := 1.0 - _smooth(18.0, 40.0, p.distance_to(HILL))
			var cove := 1.0 - _smooth(20.0, 40.0, p.distance_to(COVE))
			var p_palm := (0.32 * beach + 0.05 * (1.0 - beach) * (1.0 - jung) + 0.06 * jung + 0.15 * cove) * (1.0 - 0.75 * vill) * (1.0 - hill)
			var p_jungle := 0.6 * jung * (1.0 - beach) * (1.0 - vill)
			var p_rock := 0.02 + 0.1 * hill
			if roll < p_palm:
				_add_tree(buckets, palms, p, h, rng, 0.35, 3.0)
			elif roll < p_palm + p_jungle:
				_add_tree(buckets, jungle, p, h, rng, 0.45, 3.5, rng.randf_range(0.85, 1.25))
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
			var jung := 1.0 - _smooth(50.0, 80.0, p.distance_to(JUNGLE_HIGH))
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

	# --- commit MultiMeshes ---
	var vegetation := Node3D.new()
	vegetation.name = "Vegetation"
	add_child(vegetation)
	for mesh in buckets.keys():
		var xforms: Array = buckets[mesh]
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
		vegetation.add_child(mmi)


func _bucket(buckets: Dictionary, mesh: Mesh, xf: Transform3D) -> void:
	if not buckets.has(mesh):
		buckets[mesh] = []
	buckets[mesh].append(xf)


func _add_tree(buckets: Dictionary, meshes: Array, p: Vector2, h: float, rng: RandomNumberGenerator,
		col_r: float, col_h: float, s: float = -1.0) -> void:
	if s < 0.0:
		s = rng.randf_range(0.85, 1.15)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
	var tree_mesh: Mesh = meshes[rng.randi() % meshes.size()]
	var xf := Transform3D(basis, Vector3(p.x, h - 0.15, p.y))
	_bucket(buckets, tree_mesh, xf)
	# the crown is something a vine can latch onto
	GrapplePoints.add(self, xf * GrapplePoints.crown_of(tree_mesh))
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = col_r * s
	shape.height = col_h
	cs.shape = shape
	cs.position = Vector3(p.x, h + col_h * 0.5, p.y)
	_tree_colliders.add_child(cs)
	reserve(p, 1.2)


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
	npc.ground_func = height_at
	npc.position = Vector3(p.x, hv(p) if y == INF else y, p.y)
	add_child(npc)
	return npc


func _spawn_npcs() -> void:
	# Harbormaster at the foot of the dock
	var odile_p := dock_shore + Vector2(3.2, 2.5)
	_npc({
		"name": "Harbormaster Odile", "dialogue": "odile", "voice": 1.15,
		"look": {"body": "fem", "build": "average", "height": 1.02, "skin": CharacterLook.SKIN_TONES[4],
			"head": "square", "nose": "straight", "eyes": 4, "brows": 3, "mouth": 0, "eye_color": CharacterLook.EYE_COLORS[0],
			"hair": "bun", "hair_color": CharacterLook.HAIR_COLORS[0], "hat": "cap", "hat_color": CharacterLook.CLOTH[8],
			"top": "shirt", "top_color": CharacterLook.CLOTH[1], "coat": "jacket", "coat_color": CharacterLook.CLOTH[8],
			"trim_color": CharacterLook.TRIM[0], "legs": "trousers", "legs_color": CharacterLook.CLOTH[6],
			"feet": "tall_boots", "feet_color": CharacterLook.LEATHER[0], "belt": "belt", "belt_color": CharacterLook.LEATHER[1],
			"pouch": true},
	}, odile_p, -dock_dir)

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

	# Old net-mender on the beach
	_npc({
		"name": "Old Pell", "dialogue": "pell", "voice": 0.82,
		"look": {"body": "masc", "build": "slim", "height": 0.96, "skin": CharacterLook.SKIN_TONES[3],
			"head": "long", "nose": "hooked", "eyes": 3, "brows": 4, "mouth": 0, "marks": "age_lines",
			"hair": "crop", "hair_color": CharacterLook.HAIR_COLORS[8], "facial_hair": "long_beard", "hat": "straw",
			"hat_color": CharacterLook.CLOTH[13], "top": "tunic", "top_color": CharacterLook.CLOTH[10], "sleeves": "short",
			"legs": "breeches", "legs_color": CharacterLook.CLOTH[2], "feet": "barefoot", "belt": "sash",
			"sash_color": CharacterLook.CLOTH[1], "scarf": true, "scarf_color": CharacterLook.CLOTH[13]},
	}, dock_shore + Vector2(-11.5, 4.5), dock_dir)

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
		"name": "Marlo", "voice": 0.85,
		"barks": [
			"Fresh off the boat! Well. Fresh-ish. Off a boat.",
			"Snapper, mackerel, something with too many teeth. Pick one.",
			"Gus buys my fish for his stew. Don't ask him what else goes in it.",
		],
		"look": {"body": "masc", "build": "stout", "skin": CharacterLook.SKIN_TONES[2],
			"head": "square", "nose": "broad", "eyes": 0, "brows": 1, "mouth": 2,
			"hair": "crop", "hair_color": CharacterLook.HAIR_COLORS[1], "facial_hair": "moustache", "hat": "cap",
			"hat_color": CharacterLook.CLOTH[10], "top": "shirt", "top_color": CharacterLook.CLOTH[0], "sleeves": "short",
			"apron": true, "apron_color": CharacterLook.CLOTH[7], "legs": "breeches", "legs_color": CharacterLook.CLOTH[8],
			"feet": "boots", "feet_color": CharacterLook.LEATHER[1], "belt": "belt", "belt_color": CharacterLook.LEATHER[1]},
	}, _marker_point(_stall_fish, "Vendor"), _marker_face(_stall_fish, "Vendor"))
	_npc({
		"name": "Sela", "voice": 1.2,
		"barks": [
			"Sailcloth, silk, and wool from three islands over. Touch with your eyes, Captain.",
			"That coat of yours has seen weather. I could patch it. For a price.",
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
		"name": "Old Ida", "voice": 1.05,
		"barks": [
			"Pots, jugs, jars. Everything here holds water except my patience.",
			"Thrown on my own wheel, fired in my own kiln, dropped by my own nephew.",
			"Buy a jar for your rum, Captain. Barrels are for people with crews.",
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
			"The scuttlebugs come out under the jungle trees. Hit 'em when they're dizzy from charging."],
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
	for q in [dock_shore + Vector2(4, 3), dock_shore + Vector2(8, 4.5), VILLAGE + Vector2(8, -26), VILLAGE + Vector2(3, -14)]:
		fish_route.append(Vector3(q.x, hv(q), q.y))
	_npc({
		"name": "Bram", "voice": 0.95,
		"barks": [
			"Nets came up empty again. Fish are skittish this season.",
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
		# the island (the Wolf Fruit in the ruins, the Vine Fruit up the hill)
		var extra := ""
		if s[0] == CAMP + Vector2(-6.0, -4.0):
			extra = "pistol"
		elif s[0] == RUINS + Vector2(-1.5, 2.2):
			extra = "wolf_fruit"
		elif s[0] == HILL + Vector2(4.0, 3.5):
			extra = "vine_fruit"
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
	sph.radius = 150.0
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


func _add_ambience() -> void:
	var ocean := AudioStreamPlayer.new()
	ocean.name = "OceanAmbience"
	ocean.stream = load("res://assets/audio/ocean_loop.wav")
	ocean.volume_db = -14.0
	ocean.autoplay = true
	ocean.bus = "Ambience"
	add_child(ocean)
