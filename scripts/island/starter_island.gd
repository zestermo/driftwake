class_name StarterIsland
extends Island
## Brinehollow — the hand-designed starter island, and the reference the island
## kit (scripts/island/kit/, .claude/skills/driftwake-islands) is held to.
##
## Its own: the terrain (a 630 m chunk at 3 m resolution with a designed height
## function: village plateau, lighthouse hill, jungle highlands, a sheltered cove,
## the deep forest to the west, a broad beach to the north-west), the splat paint
## for paths / sand / grass, the paths, the vegetation, the bugs and the loot.
## Everything settled is a kit piece; this file is where each goes, with
## Brinehollow's own parameters and fixed seeds (SEEDS), so it stays the same island.
##
## Layout (local coordinates, -Z is north / towards the dock):
##   Village square  (0, -62)      Training yard (-58, -38)
##   Lighthouse hill (78, -30)     Jungle ruins  (-62, 58)
##   Castaway cove   (78, 92)      Dock: north shore, straight out from the village
##   Deep forest   (-125, 70)      Bug queen's cave (-150, 45)
##   Pirate den   (-160, -152) on a clifftop plateau off the north-west beach,
##                behind the rocky ridge down the point west of the harbour

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
## Grell's den on a plateau off the north-west beach: flat to DEN_IN, its cliffs at
## DEN_OUT, its hoist and pier out toward DEN_SEA.
const DEN := Vector2(-160, -152)
const DEN_TOP := 17.0
const DEN_IN := 24.0
const DEN_OUT := 30.0
const DEN_SEA := Vector2(0.301, -0.954)
## The climb up the plateau's landward face, on a circle CLIMB_R round DEN from
## CLIMB_FROM degrees: slabs [radius, top, gap to the next], the knife edge
## ["edge", length, its far end's top]; a rope ladder from the last slab (LADDER_Y).
const CLIMB_R := 33.0
const CLIMB_FROM := 46.0
const LADDER_Y := 7.6
const CLIMB := [[1.5, 2.95, 1.3], [1.35, 3.7, 1.6], [1.45, 4.45, 1.4], [1.3, 5.2, 1.7], [1.4, 5.95, 1.5], [1.35, 6.7, 0.0],
	["edge", 8.0, 7.1], [1.25, 7.1, 2.0], [1.45, LADDER_Y, 0.0]]
## The rocky spine down the point between the harbour's beach and the den's
## (x, height added, z): it hides the den from the beach you wake on.
const RIDGE := [Vector3(-83, 7, -199), Vector3(-81, 11, -182), Vector3(-80, 13, -166), Vector3(-77, 9.5, -152),
	Vector3(-78, 13, -138), Vector3(-81, 10, -120), Vector3(-83, 6, -104), Vector3(-80, 0, -92)]
const MARKET := Vector2(13, -49)  # = VILLAGE + (13, 13)

## The harbour (KitHarbour's defaults are Brinehollow's): the quay's top, its
## depth from the sea wall, the street behind, the main pier.
const QUAY_Y := 1.62
const QUAY_W := 11.0
const STREET_W := 4.5
const PLAT_D := QUAY_W + STREET_W
const DOCK_LENGTH := 28.0
const PIER_HW := 3.0
## Wooden piers' deck height (the den's, the harbour's side piers).
const DOCK_DECK_Y := 1.7
const DEN_PIER := 26.0
const SPITTERS := 9
const VEG_CELL := 70.0
## Brinehollow's fixed seeds: the same island whatever the world's seed.
const SEEDS := {"port": 7007, "village": 2626, "market": 51, "ruins": 4242, "spitters": 7171, "grell": 97, "coast": 3131, "climb": 5151}
## NightLights the kit may light (lamps, lit doorways, the camps' and the den's lanterns).
const LIGHTS := 22

var heights := PackedFloat32Array()
var paths: Array = []        # Array of PackedVector2Array (smoothed)
var path_widths: Array = []  # half widths
var path_bounds: Array = []  # Rect2 per path (grown by width)
var exclusions: Array = []   # [Vector2 center, float radius]

var dock_shore := Vector2.ZERO
var dock_dir := Vector2(0, -1)
var player_spawn_local := Vector3.ZERO
## piece -> build ms (the kit's pieces and Brinehollow's own steps).
var build_ms := {}
var kit: KitContext
var harbour: KitHarbour
var port_x0 := 0.0
var port_x1 := 0.0

var _coast_noise := FastNoiseLite.new()
var _roll_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
## Bays and headlands: shifts the coast in and out across the map.
var _shape_noise := FastNoiseLite.new()
var _flat_zones: Array = []  # [Vector2 center, float target, float r_in, float r_out]
var _rng := RandomNumberGenerator.new()
var _tree_colliders: StaticBody3D

var _tavern: Node3D
var _harbor: Node3D
var _smithy: Node3D
var _stall_a: Node3D
var _stall_b: Node3D
var _stall_fish: Node3D
var _stall_pots: Node3D
var _stall_cloth: Node3D
var _keeper_hut: Node3D
## Where the harbour's people work (KitHarbour.build_front).
var odile_at := Vector2.ZERO
var odile_face := Vector2.ZERO
var tackett_at := Vector2.ZERO
var pell_at := Vector2.ZERO
var smugglers: GruntCamp
var den: GruntCamp
var cave: BroodCave
var bug_nest: ScuttlebugNest
var spitters: ScuttlebugNest
## Island-space crowns of the big deep-forest trees (where the spitters hide).
var forest_crowns: Array = []
## The cliffs' rock wall (Coast.cliffs) and the clifftop splat.
var coast_cols: Array = []
var _coast_rock := PackedFloat32Array()
## The den's hoists and its climb (_plan_den): sea_hoist and hoist [root, tip], climb
## (the pieces from the foot up), start and face (the warning at its foot), top, ladder_y, guard.
var den_plan := {}


# ==========================================================================
# Entry point
# ==========================================================================
## Build the whole island. Call after the node is inside the tree.
func build(world_seed: int) -> Dictionary:
	island_name = "Brinehollow"
	island_type = "town"
	_rng.seed = world_seed + 1337
	var t0 := Time.get_ticks_usec()
	_setup_noise(world_seed)
	_setup_flat_zones()
	harbour = KitHarbour.plan(_height_fn, {})
	port_x0 = harbour.s0
	port_x1 = harbour.s1
	dock_shore = harbour.dock
	_define_paths()
	_generate_heights()
	_plan_den()
	build_ms["land"] = int((Time.get_ticks_usec() - t0) / 1000)
	kit = KitContext.make(self, world_seed, "brinehollow", LIGHTS, build_ms)
	kit.paved = harbour.on_platform
	kit.timed("terrain", _build_terrain)

	_tree_colliders = StaticBody3D.new()
	_tree_colliders.name = "VegetationColliders"
	_tree_colliders.collision_layer = 1
	_tree_colliders.collision_mask = 0
	add_child(_tree_colliders)

	kit.timed("pier", _build_pier)
	kit.timed("village", _build_village)
	kit.timed("market", _build_market)
	kit.timed("village", _build_village_rest)
	kit.timed("village dressing", _dress_village)
	kit.timed("village", func(): KitVillage.road_lamps(kit, paths[0]))
	_build_port()
	kit.timed("training yard", func(): KitCamps.training_yard(kit, TRAINING))
	kit.timed("lighthouse", _build_lighthouse)
	kit.timed("ruins", func(): KitLandmarks.ruins(kit, RUINS, kit.rng(0, SEEDS["ruins"])))
	kit.timed("cove", _build_cove)
	kit.timed("cove", func(): KitCamps.castaway(kit, CAMP, Vector2(-3.8, -2.2), Vector2(0, 2.2)))
	kit.timed("scuttlebugs", _build_scuttlebugs)
	kit.timed("smugglers", _build_smugglers_camp)
	kit.timed("den", _build_den)
	kit.timed("cave", func(): cave = KitCave.cave(kit, CAVE))
	kit.timed("vegetation", _scatter_vegetation)
	kit.timed("spitters", _build_spitters)
	kit.timed("npcs", func(): KitLife.spawn(kit, BrinehollowCast.people(self)))
	kit.timed("loot", _spawn_loot)
	_add_arrival_zone()
	kit.timed("draw lod", func(): DrawLOD.apply(self))

	# the ship lies alongside the pier's head, against its fender
	var dock_end := harbour.dock_point(DOCK_LENGTH - 4.0)
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
	[CAVE, 52.0], [FOREST, 40.0]]


## The den plateau's top edge from DEN on bearing `ang` (its face falls to DEN_OUT -
## DEN_IN further out): round on the climb's side, bitten in and out toward the sea.
static func _den_r(ang: float) -> float:
	var sea := _smooth(50.0, 72.0, _bearing_off(ang, 77.0))
	return DEN_IN + sea * (2.0 + 3.0 * sin(ang * 3.0 + 0.7) + 1.5 * sin(ang * 5.0 + 2.1))


## How much of the broad north-west beach `p` is on (0..1).
func _beach_lobe(p: Vector2) -> float:
	return _coast_extra(atan2(p.y, p.x)).y / 62.0


## 0..1: how far p is into the harbour's sea front (its quay and `pad` m past each end).
func _harbour_band(p: Vector2, pad: float) -> float:
	if harbour == null:
		return 0.0
	var s := harbour.s_of(p)
	return _smooth(harbour.s0 - pad - 20.0, harbour.s0 - pad, s) * (1.0 - _smooth(harbour.s1 + pad, harbour.s1 + pad + 20.0, s)) \
		* (1.0 - _smooth(30.0, 60.0, harbour.t_of(p) - harbour.wall(s)))


## 0..1: room for the shelf at p (none off the harbour, round the den or near the terrain's edge).
func _shelf_room(p: Vector2) -> float:
	return (1.0 - _smooth(HALF - 75.0, HALF - 35.0, maxf(absf(p.x), absf(p.y)))) * _smooth(60.0, 90.0, p.distance_to(DEN)) \
		* (1.0 - _harbour_band(p, 20.0))


## 0..1: where a cliff may stand (not at the harbour or the castaway's camp).
func _cliff_allow(p: Vector2) -> float:
	return (1.0 - _harbour_band(p, 25.0)) * _smooth(25.0, 40.0, p.distance_to(CAMP))


## The ridge down the point: [distance to its line, its height there].
static func _ridge_at(p: Vector2) -> Vector2:
	var best := Vector2(INF, 0.0)
	if p.x < -110.0 or p.x > -45.0 or p.y > -75.0:
		return best
	for i in range(RIDGE.size() - 1):
		var a := Vector2(RIDGE[i].x, RIDGE[i].z)
		var b := Vector2(RIDGE[i + 1].x, RIDGE[i + 1].z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best.x:
			best = Vector2(d, lerpf(RIDGE[i].y, RIDGE[i + 1].y, t))
	return best


## 0..1: bare rock in the splat (the ridge, the plateau's face).
func _crag(p: Vector2) -> float:
	var rg := _ridge_at(p)
	var dd := p.distance_to(DEN) - _den_r((p - DEN).angle()) + DEN_IN
	return maxf((1.0 - _smooth(3.0, 9.0, rg.x)) * _smooth(3.0, 7.0, rg.y),
		_smooth(DEN_IN - 1.5, DEN_IN + 0.5, dd) * (1.0 - _smooth(DEN_OUT - 0.5, DEN_OUT + 1.5, dd)))


## Natural terrain before flattening.
func _height_natural(x: float, z: float, shelf := 1.0) -> float:
	var p := Vector2(x, z)
	var d := p.length()
	var ang := atan2(z, x)
	var ext := _coast_extra(ang)
	var r := 126.0 + _coast_noise.get_noise_2d(cos(ang) * 50.0, sin(ang) * 50.0) * 16.0 + maxf(ext.x, ext.y) + _capes(ang)
	var t := d - r + _shape_noise.get_noise_2d(x, z) * 34.0 * _wild(ang)
	for k in LAND_KEEP:
		t = minf(t, p.distance_to(k[0]) - float(k[1]))
	t = minf(t, p.distance_to(DEN) - _den_r((p - DEN).angle()) - DEN_OUT + DEN_IN)
	var bw := ext.y / 62.0
	var h: float
	if t < 0.0:
		h = lerpf(0.5, 4.3, pow(clampf(-t / (44.0 + 46.0 * bw), 0.0, 1.0), 0.85))
	else:
		h = Coast.shelf(lerpf(0.5, SEAFLOOR, _smooth(0.0, 60.0, t)), t, shelf * _shelf_room(p), SEAFLOOR)
	var inland := clampf(-t / 35.0 - 0.15, 0.0, 1.0)
	h += _roll_noise.get_noise_2d(x, z) * 2.6 * inland * (1.0 - 0.6 * bw)
	h += _detail_noise.get_noise_2d(x, z) * 0.45 * inland
	# jungle highlands to the south-west, rolling forest hills past them
	h += 5.5 * _gauss(p, JUNGLE_HIGH, 38.0) * inland
	h += 4.0 * _gauss(p, FOREST, 42.0) * inland
	# lighthouse hill (falls into the sea as a cliff on the east side)
	h += 19.0 * _gauss(p, HILL, 23.0)
	return h


func _height_fn(x: float, z: float, shelf := 1.0) -> float:
	var p := Vector2(x, z)
	var h := _height_natural(x, z, shelf)
	for zone in _flat_zones:
		var w := 1.0 - _smooth(zone[2], zone[3], p.distance_to(zone[0]))
		if w > 0.0:
			h = lerpf(h, zone[1], w)
	# a dry beach under the den's climb whatever the coast does, the den's plateau (its
	# sea sides become cliffs in Coast.cliffs), the rocky ridge on dry land
	var dd := p.distance_to(DEN)
	if absf(dd - CLIMB_R) < 10.0:
		var cw := (1.0 - _smooth(5.0, 10.0, absf(dd - CLIMB_R))) * (1.0 - _smooth(36.0, 50.0, _bearing_off((p - DEN).angle(), CLIMB_FROM + 30.0)))
		h = lerpf(h, 2.0, cw)
	if dd < DEN_OUT + 8.0:
		var dr := _den_r((p - DEN).angle())
		h = lerpf(h, DEN_TOP, 1.0 - _smooth(dr, dr + DEN_OUT - DEN_IN, dd))
	var rg := _ridge_at(p)
	if rg.x < 10.0:
		h += rg.y * (1.0 - _smooth(2.0, 10.0, rg.x)) * _smooth(0.0, 1.5, h)
	# carve the cove (a sheltered bay opening to the south-east)
	var g := 1.0 - _smooth(10.0, 32.0, p.distance_to(COVE))
	if g > 0.0:
		h = lerpf(h, -3.5, g)
	# level sandy shelf for the castaway camp on the cove beach
	var cw := 1.0 - _smooth(4.0, 9.0, p.distance_to(CAMP))
	if cw > 0.0:
		h = lerpf(h, 1.5, cw)
	# the harbour: ground under the quay kept low, the waterfront levelled to its top
	if harbour:
		h = harbour.shape(x, z, h)
	return h


func _setup_flat_zones() -> void:
	_flat_zones = [
		[VILLAGE, _height_natural(VILLAGE.x, VILLAGE.y), 24.0, 40.0],
		[TRAINING, _height_natural(TRAINING.x, TRAINING.y), 12.0, 21.0],
		[HILL, _height_natural(HILL.x, HILL.y), 11.0, 17.0],
		[RUINS, _height_natural(RUINS.x, RUINS.y), 10.0, 18.0],
		[SMUGGLERS, maxf(_height_natural(SMUGGLERS.x, SMUGGLERS.y), 1.5), 11.0, 18.0],
		[CAVE, _height_natural(CAVE.x, CAVE.y), 30.0, 44.0],
		[climb_start()[0], 2.0, 5.0, 11.0],
	]


func _generate_heights() -> void:
	heights.resize((RES + 1) * (RES + 1))
	for iz in range(RES + 1):
		for ix in range(RES + 1):
			heights[iz * (RES + 1) + ix] = _height_fn(-HALF + ix * CELL, -HALF + iz * CELL)
	var coast := Coast.cliffs(heights, RES, CELL, HALF, _cliff_allow, func(p: Vector2) -> float: return _height_fn(p.x, p.y, 0.0))
	heights = coast["heights"]
	_coast_rock = coast["rock"]
	coast_cols = coast["cols"]


## A point on the climb's circle `sig` m along it from its foot (`r` from DEN).
static func _climb_at(sig: float, r := CLIMB_R) -> Vector2:
	return DEN + Vector2.from_angle(deg_to_rad(CLIMB_FROM) + sig / r) * r


## The climb's pieces from the foot up: slabs {"k": "slab", "at", "y", "r", "out" (off the cliff)} and the
## knife edge {"k": "edge", "line" (its top's middle), "w", "at", "r" (half its length), "y"}.
static func climb_pieces() -> Array:
	var out: Array = []
	var sig := 0.0
	var last := 0.0
	var joined := false
	for e in CLIMB:
		if e[0] is String:
			var y0: float = out[out.size() - 1]["y"]
			var line: Array = []
			for k in range(9):
				var q := _climb_at(last + float(e[1]) * k / 8.0)
				line.append(Vector3(q.x, lerpf(y0, e[2], k / 8.0), q.y))
			out.append({"k": "edge", "line": line, "w": 0.8, "at": _climb_at(last + float(e[1]) * 0.5), "r": float(e[1]) * 0.5, "y": float(e[2])})
			sig = last + float(e[1])
			joined = true
			continue
		var at_sig := sig if joined or out.is_empty() else sig + float(e[0])
		joined = false
		var q := _climb_at(at_sig)
		out.append({"k": "slab", "at": q, "y": float(e[1]), "r": float(e[0]), "out": (q - DEN).normalized()})
		last = at_sig
		sig = at_sig + float(e[0]) + float(e[2])
	return out


## Where the climb starts (the crew's warning) and the way on to its first slab.
static func climb_start() -> Array:
	var p := _climb_at(-4.0, CLIMB_R + 1.0)
	return [p, (_climb_at(0.0) - p).normalized()]


## The den's hoists (each from the rim out over its drop), the climb and the guard at
## its top; rock along the ridge and round the plateau's landward rim, and none
## where the hoist and the pier come down the sea cliff.
func _plan_den() -> void:
	var sea := _rim_out(DEN_SEA)
	var d := DEN.distance_to(sea) + 1.0
	while height_at(DEN.x + DEN_SEA.x * d, DEN.y + DEN_SEA.y * d) > -1.5:
		d += 0.5
	var sea_tip := DEN + DEN_SEA * (d + 1.5)
	var pieces := climb_pieces()
	var u := ((pieces[pieces.size() - 1]["at"] as Vector2) - DEN).normalized()
	var root := _rim_out(u)
	var tip := DEN + u * (CLIMB_R - 0.9)
	var start := climb_start()
	den_plan = {"sea_hoist": [sea, sea_tip], "hoist": [root, tip], "climb": pieces, "start": start[0], "face": start[1],
		"top": DEN_TOP, "ladder_y": LADDER_Y, "guard": [root - u * 2.5, root + u * 4.0]}
	coast_cols = coast_cols.filter(func(c: Array) -> bool:
		return Geometry2D.get_closest_point_to_segment(c[0], sea, sea_tip + DEN_SEA * 4.0).distance_to(c[0]) > 6.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEEDS["coast"] + 1
	var n := 0
	var steps := int(TAU * (DEN_IN + 0.8) / 3.2)
	for k in range(steps):
		var dir := Vector2.from_angle(TAU * k / steps)
		var at := DEN + dir * (DEN_IN + rng.randf_range(0.6, 2.4))
		var lift := rng.randf_range(-2.5, 1.5)
		if rng.randf() < 0.35 or height_at(DEN.x + dir.x * (DEN_OUT + 3.0), DEN.y + dir.y * (DEN_OUT + 3.0)) < 0.5:
			continue
		if Geometry2D.get_closest_point_to_segment(at, root, tip).distance_to(at) < 5.5:
			continue
		coast_cols.append([at, DEN_TOP + lift, -dir, 0.45, 20000 + n, 1])
		reserve(at, 2.5)
		n += 1
	for i in range(RIDGE.size() - 1):
		var a := Vector2(RIDGE[i].x, RIDGE[i].z)
		var b := Vector2(RIDGE[i + 1].x, RIDGE[i + 1].z)
		var side := (b - a).normalized().orthogonal()
		var count := int(a.distance_to(b) / 3.0)
		for k in range(count):
			var t := float(k) / count
			var lift := lerpf(RIDGE[i].y, RIDGE[i + 1].y, t)
			if lift < 4.0:
				continue
			var spots := [[a.lerp(b, t) + side * rng.randf_range(-2.0, 2.0), rng.randf_range(-0.5, 4.0), side * (1.0 if rng.randf() < 0.5 else -1.0)]]
			if lift > 6.0 and k % 2 == 0:
				for sg in [-1.0, 1.0]:
					spots.append([a.lerp(b, t) + side * sg * rng.randf_range(4.5, 6.5), rng.randf_range(0.3, 1.5), side * sg])
			for sp in spots:
				var q: Vector2 = sp[0]
				var g := height_at(q.x, q.y)
				if g < 1.0:
					continue
				coast_cols.append([q, g + float(sp[1]), sp[2], 0.45, 20000 + n, 2])
				reserve(q, 2.5)
				n += 1


## The last point out along `dir` from DEN still on the plateau's top.
func _rim_out(dir: Vector2) -> Vector2:
	var d := 10.0
	while height_at(DEN.x + dir.x * d, DEN.y + dir.y * d) > DEN_TOP - 0.4:
		d += 0.5
	return DEN + dir * (d - 1.0)


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
	if harbour and harbour.on_platform(p):
		return QUAY_Y
	return height_at(p.x, p.y)


func walk_height(x: float, z: float) -> float:
	return hv(Vector2(x, z))


## The story's fights on this island, in world space ("smugglers", "den", "cave").
func place_of(place: String) -> Vector3:
	var p: Vector2 = {"smugglers": SMUGGLERS, "den": DEN, "cave": CAVE}[place]
	return to_global(Vector3(p.x, hv(p) + 1.5, p.y))


## Where the story's marker leads for `place` from `from` (world): for the den, the
## foot of its climb, then the top of the climb once you're on it, then the den.
func guide_to(place: String, from: Vector3) -> Vector3:
	if place != "den":
		return place_of(place)
	var l := to_local(from)
	var at := Vector2(l.x, l.z)
	if at.distance_to(DEN) < DEN_OUT + 4.0 and l.y > DEN_TOP - 3.0:
		return place_of("den")
	var start: Vector2 = den_plan["start"]
	var on := at.distance_to(start) < 10.0
	for e in den_plan["climb"]:
		on = on or at.distance_to(e["at"]) < float(e["r"]) + 2.5
	if on:
		var top: Vector2 = den_plan["hoist"][0]
		return to_global(Vector3(top.x, DEN_TOP + 1.5, top.y))
	return to_global(Vector3(start.x, hv(start) + 2.5, start.y))


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


## The harbour's sea wall line, point and walk-on test in island space (KitHarbour).
func _quay_z(x: float) -> float:
	return harbour.wall(x)


func _quay_pt(x: float, inland: float) -> Vector2:
	return harbour.quay_pt(x, inland)


func _on_platform(p: Vector2) -> bool:
	return harbour.on_platform(p)


## Along the harbour pier from its root at the sea wall (dock_shore).
func _dock_point(dist: float) -> Vector2:
	return harbour.dock_point(dist)


# ==========================================================================
# Paths
# ==========================================================================
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
	# into the deep forest to the cave, and off the training path round the ridge to the den's climb
	_add_path([RUINS + Vector2(-9, 5), Vector2(-84, 64), Vector2(-104, 56), Vector2(-118, 47), CAVE + Vector2(29, 0)], 1.2)
	_add_path([Vector2(-44, -41), Vector2(-60, -62), Vector2(-90, -80), Vector2(-112, -100), Vector2(-128, -120), climb_start()[0]], 1.3)


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


func path_dist(p: Vector2) -> float:
	return _path_dist(p)


func _path_weight(p: Vector2) -> float:
	var d := _path_dist(p)
	return 1.0 - _smooth(-0.6, 0.6, d)


func _excluded(p: Vector2, pad: float = 0.0, under := INF) -> bool:
	for e in exclusions:
		if float(e[1]) < under and p.distance_to(e[0]) < float(e[1]) + pad:
			return true
	return false


func excluded(p: Vector2, pad: float, under := INF) -> bool:
	return _excluded(p, pad, under)


## Brinehollow's save ids are its own names (chests, strongboxes).
func save_key(key: String) -> String:
	return key


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
			var rock := maxf(_coast_rock[i], _crag(p))
			if h > -1.0:
				dirt = maxf(_path_weight(p), _disk(p, VILLAGE, 12.0, 17.0))
				dirt = maxf(dirt, _disk(p, TRAINING, 10.0, 13.0))
				dirt = maxf(dirt, _disk(p, RUINS, 8.0, 11.0))
				dirt = maxf(dirt, _disk(p, HILL, 5.0, 8.0))
				dirt = maxf(dirt, _disk(p, CAVE, 20.0, 25.0))
				dirt = maxf(dirt, _disk(p, DEN, 13.0, 19.0) * 0.8)
				# packed earth behind the quay, among the waterfront houses
				dirt = maxf(dirt, harbour.earth(x, z))
				dirt = maxf(dirt, _disk(p, dock_root, 3.0, 6.0) * 0.6)
				sand = 1.0 - _smooth(1.7, 2.8, h)
				sand = maxf(sand, _disk(p, CAMP, 4.0, 9.0))
				dirt *= (1.0 - _disk(p, CAMP, 0.0, 9.0)) * (1.0 - rock)
				sand *= (1.0 - dirt) * (1.0 - rock)
			cols[i] = Color(dirt, rock, sand, 1.0)
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
	Coast.build(self, Coast.rocks(coast_cols, SEEDS["coast"], func(p: Vector2) -> float: return height_at(p.x, p.y)))


# ==========================================================================
# Placement (Brinehollow's own builders below use these; kit pieces use `kit`)
# ==========================================================================
static func face_yaw(dir: Vector2) -> float:
	return atan2(dir.x, dir.y)


## Place a prop on the ground. `footprint` > 0 sits it on the highest point
## under its footprint and reserves the area from vegetation.
func place(node: Node3D, p: Vector2, yaw: float = 0.0, footprint: float = 0.0, y_offset: float = 0.0) -> Node3D:
	return kit.place(node, p, yaw, footprint, y_offset)


func reserve(p: Vector2, r: float) -> void:
	exclusions.append([p, r])


# ==========================================================================
# The layout: Brinehollow's settlement, piece by piece (scripts/island/kit/)
# ==========================================================================
## The harbour pier (lamp lit at its head), and where a new game starts.
func _build_pier() -> void:
	harbour.build_pier(kit)
	player_spawn_local = KitContext.v3(dock_shore - dock_dir * 4.0) + Vector3(0, hv(dock_shore - dock_dir * 4.0) + 1.0, 0)


## The well and the plaza, the tavern, tables outside it, the first houses (every one a different shape).
func _build_village() -> void:
	kit.place(Props.well(), VILLAGE, 0.0, 1.6)
	kit.reserve(VILLAGE, 13.0)
	_tavern = KitCave.inn(kit, VILLAGE + Vector2(-24, -2), Vector2(1, 0))
	for off in [Vector2(-12.5, -8.0), Vector2(-12.5, 5.0)]:
		KitVillage.table_set(kit, VILLAGE + off)
	kit.place(Props.barrel(), VILLAGE + Vector2(-16.5, -10.5), 0.0)
	kit.place(Props.barrel(), VILLAGE + Vector2(-17.3, -9.8), 0.0)
	kit.house({"w": 6.0, "d": 5.0, "floors": 2, "wall": "plaster", "wall2": "plaster", "roof": "gable_front",
		"roof_tex": "roof_tiles", "chimney": true, "pitch": 0.55, "lamp_light": true}, VILLAGE + Vector2(23, -3), Vector2(-1, 0))
	kit.house({"w": 7.0, "d": 5.0, "roof": "hip", "wall": "planks", "roof_tex": "roof_tiles", "porch": 1.8, "door_x": -1.5, "lamp_light": true},
		VILLAGE + Vector2(-20, 20), Vector2(1, -0.5))
	kit.house({"w": 4.5, "d": 4.0, "h": 2.4, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch",
		"lean_to": "right", "chimney": true, "lamp_light": true}, VILLAGE + Vector2(-17, -25), Vector2(1, 0.3))
	_harbor = kit.house({"w": 9.0, "d": 5.5, "h": 3.0, "roof": "shed", "wall": "planks_weathered", "roof_tex": "roof_tiles",
		"porch": 1.6, "sign": "sign_fish", "door_x": 2.0, "name": "Harbor", "lamp_light": true}, VILLAGE + Vector2(15, -28), Vector2(-1, 0))
	kit.house({"w": 4.0, "d": 4.5, "floors": 2, "wall": "stone_brick", "wall2": "planks", "roof": "gable",
		"roof_tex": "thatch", "pitch": 0.75, "jetty": 0.3}, VILLAGE + Vector2(-9, -31), Vector2(1, 0.2))
	kit.house({"w": 5.5, "d": 4.5, "h": 2.5, "roof": "hip", "wall": "plaster", "roof_tex": "thatch", "lean_to": "left", "pitch": 0.5, "lamp_light": true},
		VILLAGE + Vector2(27, 12), Vector2(-1, -0.4))


## A small market square off the plaza: four stalls, their vendors at the "Vendor" markers.
func _build_market() -> void:
	var stalls := KitMarket.build(kit, MARKET, VILLAGE, ["fruit", "fish", "cloth", "pots"], kit.rng(0, SEEDS["market"]))
	_stall_a = stalls[0]
	_stall_fish = stalls[1]
	_stall_cloth = stalls[2]
	_stall_pots = stalls[3]
	_stall_b = _stall_cloth


## The signpost, the smithy, the sea chapel, the harbour warehouse and two more houses.
func _build_village_rest() -> void:
	kit.place(Props.signpost([PI, 0.0, PI * 0.75, PI * 0.25]), VILLAGE + Vector2(2.5, 17), 0.0, 0.6)
	_smithy = kit.place(Buildings.smithy(), Vector2(-38, -78), face_yaw(Vector2(1, 0.25)), 4.6)
	KitLandmarks.chapel(kit, Vector2(42, -82), Vector2(-1, 0.35))
	var wh := kit.house({"w": 9.0, "d": 6.0, "h": 3.6, "roof": "gable", "wall": "planks_weathered", "roof_tex": "roof_tiles", "door_x": -2.2,
		"name": "Warehouse", "flowers": false, "trim": Color(0.55, 0.5, 0.45), "lamp_light": true, "pitch": 0.38}, Vector2(20, -106), Vector2(-1, 0))
	for k in range(4):
		var cp := kit.local_point(wh, Vector3(1.0 + (k % 2) * 1.0, 0, 4.0 + (k / 2) * 0.9))
		kit.place(Props.crate(0.75 + 0.1 * (k % 2)), cp, 0.3 * k, 0.0)
	kit.place(Props.barrel(), kit.local_point(wh, Vector3(3.6, 0, 3.6)))
	kit.place(Props.barrel(), kit.local_point(wh, Vector3(4.1, 0, 4.2)))
	kit.house({"w": 5.5, "d": 4.5, "floors": 2, "wall": "plaster", "wall2": "planks", "roof": "gable", "roof_tex": "thatch",
		"chimney": true, "jetty": 0.3, "trim": Buildings.TRIM_COLORS[0], "lamp_light": true}, Vector2(-30, -100), Vector2(1, 0.4))
	kit.house({"w": 6.0, "d": 4.5, "h": 2.5, "roof": "hip", "wall": "stone_brick", "roof_tex": "roof_tiles", "porch": 1.5,
		"chimney": true, "lamp_light": true}, Vector2(-30, -24), Vector2(0.7, -1))


## Cobbles on the plaza, the market and the main road; benches, planters and lamps
## round the well; bunting round the plaza and across the market; the notice
## board; washing lines behind the houses, a vegetable plot, a handcart.
func _dress_village() -> void:
	var rng := kit.rng(0, SEEDS["village"])
	var quads: Array = []
	KitPaving.plan_disk(kit, quads, VILLAGE, 12.5, rng)
	KitPaving.plan_disk(kit, quads, MARKET, 7.0, rng)
	KitPaving.plan_path(kit, quads, paths[0], 1.7)
	KitPaving.build(kit, quads)
	KitVillage.benches_round(kit, VILLAGE, 5.5)
	kit.place(Buildings.planter(0.75), VILLAGE + Vector2(-8.5, 7.0), 0.0, 0.9)
	kit.place(Buildings.planter(0.6), VILLAGE + Vector2(8.0, -8.0), 0.0, 0.8)
	for q in [VILLAGE + Vector2(-9.5, -6.0), VILLAGE + Vector2(9.0, 5.5), VILLAGE + Vector2(-3.0, 11.5), MARKET + Vector2(-5.5, 6.5)]:
		KitLights.post(kit, q, face_yaw(VILLAGE - q) - PI * 0.5, 0.4, 1.8)
	var bmb := MeshBuilder.new()
	KitVillage.bunting_ring(kit, bmb, VILLAGE, 13.2, rng)
	KitVillage.bunting(kit, bmb, Vector3(MARKET.x - 6.5, hv(MARKET) + 3.4, MARKET.y - 3.0), Vector3(MARKET.x + 6.0, hv(MARKET) + 3.4, MARKET.y + 3.5), rng)
	for q in [MARKET + Vector2(-6.5, -3.0), MARKET + Vector2(6.0, 3.5)]:
		KitVillage.pole(kit, bmb, q, 3.5)
	kit.add(bmb.to_instance("Bunting"))
	var nb := VILLAGE + Vector2(-12.5, 9.0)
	kit.place(KitVillage.notice_board(rng), nb, face_yaw(VILLAGE - nb), 1.0)
	KitVillage.laundry(kit, Vector2(-24.0, -98.0), Vector2(-23.0, -104.5), rng)
	KitVillage.laundry(kit, Vector2(33.0, -45.0), Vector2(37.0, -40.0), rng)
	KitVillage.laundry(kit, Vector2(-34.5, -20.0), Vector2(-38.5, -25.0), rng)
	KitVillage.garden(kit, Vector2(-25.0, -33.0), 5.0, 4.0, face_yaw(Vector2(1, -0.5)), rng)
	kit.place(KitVillage.handcart(), VILLAGE + Vector2(6.5, -30.0), face_yaw(Vector2(0.3, -1)), 1.4)


## The harbour: the quay, the harbour front (Odile, Tackett, Pell), side piers
## with a junk, a merchantman and a sloop, longboats, the harbour tower and crane,
## the waterfront rows, the quay's dressing, the dockhands. One stream of rng.
func _build_port() -> void:
	var rng := kit.rng(0, SEEDS["port"])
	kit.timed("quay", func(): harbour.build_quay(kit, rng, [0.0, -32.0, 30.0, 46.0]))
	kit.timed("harbour front", func():
		var who := harbour.build_front(kit, rng)
		odile_at = who["keeper"]
		odile_face = who["keeper_face"]
		tackett_at = who["shipwright"]
		pell_at = who["mender"])
	kit.timed("piers", func():
		harbour.build_piers(kit, [[-32.0, 24.0, "junk", false], [30.0, 26.0, "merchant", true], [46.0, 20.0, "sloop", true]])
		harbour.build_longboats(kit, [-13.0, -21.0])
		KitLandmarks.harbour_tower(kit, harbour.quay_pt(port_x1 - 4.0, 8.0), Vector2(-0.6, 1))
		if port_x1 > 34.0:
			KitLandmarks.crane(kit, harbour.quay_pt(25.5, 3.0), Vector2(0, -1)))
	kit.timed("waterfront", func(): harbour.build_waterfront(kit, harbour.plan_waterfront(kit, rng)))
	kit.timed("quay dressing", func():
		kit.build_list(harbour.plan_dressing(kit, rng, [-40.0, -26.0, -8.0, 14.0, 22.0, 37.0, 52.0], [-24.0, 18.0, 40.0], [["fish", -9.5], ["fruit", 24.5]])))
	kit.timed("npcs", func(): KitLife.spawn(kit, BrinehollowCast.dockhands(self)))


func _build_lighthouse() -> void:
	# (the keeper's cottage on the levelled hilltop)
	_keeper_hut = KitLandmarks.lighthouse(kit, HILL, Vector2(-1, 0.3), {"w": 4.5, "d": 4.0, "h": 2.3, "wall": "stone_brick", "roof": "gable",
		"roof_tex": "roof_tiles", "chimney": true}, Vector2(-7.5, 5.5), Vector2(-0.6, -1), [Vector2(-4.0, 8.5), Vector2(-3.4, 9.6)])


## A rowboat pulled up on the cove beach, a crate and a barrel by the castaway's camp.
func _build_cove() -> void:
	var boat_p := COVE + (CAMP - COVE).normalized() * 19.0 + Vector2(4, -2)
	kit.place(Props.rowboat(), boat_p, face_yaw(COVE - boat_p) + 0.4, 1.5)
	kit.place(Props.crate(0.7), CAMP + Vector2(2.5, 3.0), 0.3)
	kit.place(Props.barrel(), CAMP + Vector2(3.4, 2.0))


## The smugglers on the shore past the cove, watching Wren's camp: their
## strongbox holds the crew's best hat (and, with fruits in the world, the Ember Fruit).
func _build_smugglers_camp() -> void:
	var items: Array = []
	if DevilFruits.IN_WORLD:
		items.append([load("res://resources/items/ember_fruit.tres"), 1])
	items.append([load("res://resources/items/treasure.tres"), 2])
	items.append([load("res://resources/items/gold.tres"), 6])
	items.append([Gear.make("head", "tricorn", {"hat": "tricorn", "hat_color": CharacterLook.CLOTH[5], "trim_color": CharacterLook.TRIM[4]}, "Smuggler Captain's Tricorn"), 1])
	smugglers = KitCamps.pirate_camp(kit, SMUGGLERS, Vector2(1, 0.15).normalized(), CAMP, ["smugglers_strongbox", items], [11, 23, 37, 41, 53], "SmugglersCamp")


## Captain Grell's den on its clifftop (comes back 3 minutes after it's beaten), and the climb up to it.
func _build_den() -> void:
	var C := CharacterLook.CLOTH
	var lk := PirateGrunt.crew_look(kit.rng(0, SEEDS["grell"]))
	lk.merge({"name": "Captain Grell", "body": "masc", "build": "broad", "height": 1.12, "hat": "tricorn", "hat_color": C[5],
		"coat": "longcoat", "coat_color": C[13], "trim_color": CharacterLook.TRIM[4], "facial_hair": "beard",
		"vest": "brigandine", "eyepatch": true, "marks": "scar"}, true)
	den = KitCamps.den(kit, DEN, {"to_sea": DEN_SEA, "hoist": den_plan["sea_hoist"], "top": DEN_TOP, "guard": den_plan["guard"],
		"pier": DEN_PIER, "deck_y": DOCK_DECK_Y, "floor_y": SEAFLOOR * 0.5,
		"hull": {"hull": Color(0.55, 0.45, 0.4), "sail": Color(0.62, 0.56, 0.48), "trim": Color(0.5, 0.2, 0.18), "emblem": "jolly"},
		"chest": ["den_strongbox", [["treasure", 4], ["gold", 15], ["rum", 2],
			[Gear.make("coat", "longcoat", {"coat": "longcoat", "coat_color": C[5], "trim_color": CharacterLook.TRIM[4]}, "Harbor Captain's Longcoat", 2), 1],
			[ItemDB.tiered("pistol", 2), 1]]],
		"seeds": [61, 67, 71, 79, 83, 89, 97], "captain": lk, "title": "Captain Grell"}, "PirateDen")
	KitCamps.den_climb(kit, den_plan, kit.rng(0, SEEDS["climb"]))


# ==========================================================================
# Scuttlebugs: a few knee-high beetles around burrows in the jungle along
# the ruins path (the tavern regulars warn you about them).
# ==========================================================================
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
func _build_spitters() -> void:
	spitters = ScuttlebugNest.new()
	spitters.name = "SpitterRoosts"
	spitters.respawn_time = 60.0
	add_child(spitters)
	var rng := kit.rng(0, SEEDS["spitters"])
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
		elif s[0] == RUINS + Vector2(-1.5, 2.2) and DevilFruits.IN_WORLD:
			extra = "wolf_fruit"
		elif s[0] == HILL + Vector2(4.0, 3.5) and DevilFruits.IN_WORLD:
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
