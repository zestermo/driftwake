class_name StarterIsland
extends Island
## Brinehollow — the hand-designed starter island, and the reference the island
## kit (scripts/island/kit/, .claude/skills/driftwake-islands) is held to.
##
## Its own: the terrain (a 780 m chunk at 3 m resolution with a designed height
## function: village plateau, lighthouse hill, jungle highlands, a sheltered cove,
## the deep forest to the west, a broad beach to the north-west, and since 2026-10-17
## the southern lands: farmland, a highland, a second cove), the splat paint
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

const EXTENT := 780.0
const CELL := 3.0
const RES := 260
const HALF := EXTENT * 0.5
## The terrain grid's middle: the land grew south (2026-10-17), the grid's north edge stayed.
const GRID_C := Vector2(0, 75)
## The grid before it grew (630 m round the centre): the old land's plants and coast rock
## keep their draws on it; its vertices are the new grid's, OLD_SHIFT cells in.
const OLD_HALF := 315.0
const OLD_SHIFT := Vector2i(25, 0)
## Ships keep out of these circles ([centre, radius], island space): the old
## island, the western lobes, the two long points and the southern lands.
const NO_GO := [[Vector2(0, 0), 225.0], [Vector2(-100, 5), 225.0], [Vector2(-120, 220), 75.0], [Vector2(-100, -215), 70.0],
	[Vector2(-45, 235), 205.0]]
## The land fits inside this far from the centre (navmesh bake).
const LAND_R := 400.0
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
## Grell's cliff path (KitCliffPath): from the beach south of the den clockwise round
## its sea cliffs (bearings from DEN, degrees from +x toward +z): keys [bearing, radius,
## floor y, half width, headroom, overhang]; gaps over the sand, then the sea, and the
## broken bridge's swing; the cave in its buttress; the cleft up onto the top.
const DEN_PATH := {
	"keys": [[106.0, 31.0, 2.0, 1.15, 4.0, 0.0], [111.5, 31.5, 3.05, 1.12, 3.6, 0.6], [117.0, 32.0, 4.1, 1.1, 4.2, 0.0],
		[120.8, 32.8, 4.9, 1.1, 4.2, 0.0], [126.0, 34.2, 5.2, 1.05, 3.2, 0.9], [131.0, 35.5, 5.5, 1.05, 4.2, 0.0],
		[135.4, 36.4, 6.1, 1.0, 4.2, 0.0], [142.0, 38.0, 6.5, 1.0, 3.1, 1.2], [149.0, 39.0, 7.0, 1.0, 4.2, 0.0],
		[155.5, 38.8, 7.0, 1.0, 4.2, 0.0], [163.0, 37.5, 7.5, 1.1, 3.6, 0.5], [187.0, 36.0, 7.5, 1.1, 3.6, 0.0],
		[192.0, 35.8, 8.0, 1.0, 4.2, 0.0], [197.6, 36.0, 8.5, 1.0, 4.2, 0.0], [200.3, 36.1, 8.75, 1.05, 3.4, 0.8],
		[203.0, 36.3, 9.0, 1.1, 4.5, 0.0], [218.0, 36.5, 9.0, 1.1, 4.5, 0.0], [220.5, 36.4, 9.3, 1.0, 3.4, 0.9],
		[223.0, 36.2, 9.6, 1.0, 4.2, 0.0], [229.0, 35.6, 10.2, 1.05, 4.2, 0.0], [232.5, 35.3, 10.65, 1.1, 3.6, 0.6],
		[236.0, 35.0, 11.1, 1.1, 4.0, 0.0]],
	"gaps": [[117.0, 120.8, "jump"], [131.0, 135.4, "jump"], [149.0, 155.5, "jump"], [192.0, 197.6, "jump"],
		[203.0, 218.0, "swing"], [223.0, 229.0, "jump"]],
	"sea": 124.0,
	"landing": [109.0, 126.0, 1.3, -4.0],
	"rails": [[107.0, 115.5], [137.0, 147.5], [157.0, 162.0]],
	"cave": {"at": 175.0, "out": 3.5, "r": 6.0, "h": 6.0, "tunnels": [[158.0, 170.0], [180.0, 190.0]]},
	"bridge": {"at": 0.5, "top": 8.6, "len": 6.4},
	"cleft": {"from": 232.5, "to": Vector2(-171.66, -170.66), "y": 17.0},
}
## Where the path's warning stands on the beach: [bearing, radius from DEN].
const PATH_FOOT := [100.0, 34.0]
## Grell waits by his shack until a captain is this near his fire.
const GRELL_HOLD := 6.5
## The climb that was (2026-10-13, slabs up the landward face): gone, but its footprint's
## reserves stay so the plants grow as they did everywhere else.
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
const SEEDS := {"port": 7007, "village": 2626, "market": 51, "ruins": 4242, "spitters": 7171, "grell": 97, "coast": 3131, "climb": 5151,
	"south": 8181, "street": 8282, "upper": 8383, "shrine": 8484, "farm": 8585, "wilds": 8686}
## The southern lands (2026-10-17): a lobe of land round LOBE, LOBE_R to its coast (ragged), kept
## off the cove (COVE_SEA) and the old island's interior; the highland the falls come off, the
## farmland round the windmill hamlet, the second cove's bay on the south coast.
const LOBE := Vector2(-45, 235)
const LOBE_R := 155.0
const COVE_SEA := 58.0
const HIGHLAND := Vector2(28, 318)
const FARM := Vector2(-45, 200)
const COVE2 := Vector2(-56, 356)
const COVE2_MOUTH := Vector2(-0.12, 1.0)
## Places that keep their ground exactly as it was where the new land meets the old coast: [centre, radius].
const GROW_KEEP := [[SMUGGLERS, 26.0]]
## The rocky spine from the highland out to the south-east cape (sea cliffs at its end: the wreck's rocks).
const CAPE_TIP := Vector2(92, 372)
## The windmill hamlet's fields round FARM (KitFarm: [centre, half size, yaw, crop], rows along local X)
## and the orchard (the same rectangle form).
const FIELDS := [[Vector2(-75, 175), Vector2(7, 5), 0.2, "wheat"], [Vector2(-88, 205), Vector2(6, 8), 0.1, "greens"],
	[Vector2(-72, 238), Vector2(8, 5.5), -0.15, "wheat"], [Vector2(-42, 242), Vector2(7, 5), 0.25, "vines"],
	[Vector2(2, 208), Vector2(6, 5), 0.3, "greens"], [Vector2(-38, 168), Vector2(6, 4.5), 0.35, "wheat"]]
const ORCHARD := [Vector2(-55, 265), Vector2(9, 7), 0.1, "orchard"]
## The wild places on the far side: the falls' pool at the highland's north-west foot (its crag uphill
## toward HIGHLAND, KitLandmarks' waterfall), the wreck on the east coast's rocks (found from LOBE on
## WRECK_BEARING), the second cove (COVE2) with its landing.
const POOL := Vector2(12, 290)
const WRECK_BEARING := 24.0
## Paths before the land grew: the old pieces and plants see only these.
const OLD_PATHS := 8
## The upper town (2026-10-17): a hill climbing south from the plaza between the ruins and cove
## paths to the shrine terrace, UP_RISE over the plaza from UP_Z0 to UP_Z1 (flat to UP_Z2, then
## down), terraced in bands: each flat at its lane's height (UP_BANDS, its front) to 3 m short of
## the next, a stone block filling the step. The long stair climbs its middle (UP_X, 3 m wide) on
## a corridor sunk under it. The grid's vertex lines (3 m) fall on the bands' and corridor's edges.
const UP_X := 4.5
const UP_Z0 := -39.0
const UP_Z1 := 6.0
const UP_Z2 := 33.0
const UP_RISE := 12.0
const UP_BANDS := [-30.0, -18.0, -6.0]
const UP_SINK := 0.7
## The town's life, built last from its own file (`static func build(isl: StarterIsland)`), when it exists.
const LIFE := "res://scripts/island/brinehollow_life.gd"
## NightLights the kit may light (lamps, lit doorways, the camps' and the den's lanterns): the old
## island takes 18, the grown town's pieces after it (2026-10-17: 34, a share kept for the town's life).
const LIGHTS := 34

var heights := PackedFloat32Array()
var paths: Array = []        # Array of PackedVector2Array (smoothed)
var path_widths: Array = []  # half widths
var path_bounds: Array = []  # Rect2 per path (grown by width)
var exclusions: Array = []   # [Vector2 center, float radius]
## The reserves for `excluded`, by cell: [cell -> [[centre, r]], the ones bigger than a cell]; the
## old island's and the grown land's apart (the old plants decide on the old ones only).
var _ex_old := [{}, []]
var _ex_new := [{}, []]
const EX_CELL := 8.0
## While true, reserves are the grown land's.
var _grow_layer := false
## While true (the old island's plants deciding), only the old reserves and paths count.
var _old_only := false
## Paths path_dist sees: the old ones until the grown land's pieces start.
var _open_paths := OLD_PATHS
## The old paths as they ran before the upper town: [paths, widths, bounds].
var _frozen: Array = []

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
## The falls' pool's water line ground (its basin dug under it); the wreck's spot on the shore and out to sea.
var _pool_y := 0.0
var wreck_site: Array = []
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
## The den's sea hoist and its path (_plan_den): sea_hoist [root, tip], start and face (the
## warning at the path's foot), top (where the cleft comes up onto the plateau), route (floor
## points), jumps (KitCliffPath.jumps), guard.
var den_plan := {}
var den_path: KitCliffPath
## The old island's ground before the path was cut in (the old plants decide on it, so every
## draw is what it always was), and per vertex whether the grown ground differs from it (dilated).
var _land_heights := PackedFloat32Array()
var _changed := PackedByteArray()
var _path_task := -1
var _path_mesh := {}
var _veg_skip := false
## The square the next plants are bucketed by (the grown land's trees and rocks: 140 m).
var _veg_cell := VEG_CELL
## The new town's built pieces, their meshes folded into one at the end (TownMeshes).
var _town_parts: Array = []
## The new town's places for its people (2026-10-17; scripts/island/brinehollow_cast.gd's to use):
## "stalls" and "shops" (nodes with "Vendor" and "Customer" markers), "houses" (nodes, their doors
## on local +Z), "lanes" (PackedVector2Array each), "stair" (the long stair's walking line, island
## space Vector3s from the plaza up to the terrace).
var town_spots := {"stalls": [], "shops": [], "houses": [], "lanes": [], "stair": PackedVector3Array()}


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
	_plan_den_path()
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
	# the grown land's pieces: their reserves and paths kept apart from the old island's
	_open_grown()
	kit.timed("market street", _build_market_street)
	kit.timed("upper town", _build_upper_town)
	kit.timed("shrine terrace", _build_shrine_terrace)
	kit.timed("farmland", _build_farmland)
	kit.timed("wild places", _build_wilds)
	_grow_layer = false
	kit.timed("vegetation", _scatter_vegetation)
	kit.timed("spitters", _build_spitters)
	kit.timed("npcs", func(): KitLife.spawn(kit, BrinehollowCast.people(self)))
	kit.timed("loot", _spawn_loot)
	# the town's life (people, smoke, harbour traffic, their lights), from its own file once it's there
	if ResourceLoader.exists(LIFE):
		kit.timed("life", func(): load(LIFE).build(self))
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


## 0..1: room for the shelf at p (none off the harbour, round the den or near the terrain's edge:
## the old grid's for the old island's ground).
func _shelf_room(p: Vector2, old := false) -> float:
	var edge := (1.0 - _smooth(OLD_HALF - 75.0, OLD_HALF - 35.0, maxf(absf(p.x), absf(p.y)))) if old \
		else (1.0 - _smooth(HALF - 75.0, HALF - 35.0, maxf(absf(p.x - GRID_C.x), absf(p.y - GRID_C.y))))
	return edge * _smooth(60.0, 90.0, p.distance_to(DEN)) * (1.0 - _harbour_band(p, 20.0))


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


## How far p is outside the old island's coast (negative inland).
func _old_t(p: Vector2) -> float:
	var d := p.length()
	var ang := atan2(p.y, p.x)
	var ext := _coast_extra(ang)
	var r := 126.0 + _coast_noise.get_noise_2d(cos(ang) * 50.0, sin(ang) * 50.0) * 16.0 + maxf(ext.x, ext.y) + _capes(ang)
	var t := d - r + _shape_noise.get_noise_2d(p.x, p.y) * 34.0 * _wild(ang)
	for k in LAND_KEEP:
		t = minf(t, p.distance_to(k[0]) - float(k[1]))
	return minf(t, p.distance_to(DEN) - _den_r((p - DEN).angle()) - DEN_OUT + DEN_IN)


## Natural terrain before flattening (the old island's: `old` keeps the old grid's edge).
func _height_natural(x: float, z: float, shelf := 1.0) -> float:
	var p := Vector2(x, z)
	var ang := atan2(z, x)
	var ext := _coast_extra(ang)
	var t := _old_t(p)
	var bw := ext.y / 62.0
	var h: float
	if t < 0.0:
		h = lerpf(0.5, 4.3, pow(clampf(-t / (44.0 + 46.0 * bw), 0.0, 1.0), 0.85))
	else:
		h = Coast.shelf(lerpf(0.5, SEAFLOOR, _smooth(0.0, 60.0, t)), t, shelf * _shelf_room(p, true), SEAFLOOR)
	var inland := clampf(-t / 35.0 - 0.15, 0.0, 1.0)
	h += _roll_noise.get_noise_2d(x, z) * 2.6 * inland * (1.0 - 0.6 * bw)
	h += _detail_noise.get_noise_2d(x, z) * 0.45 * inland
	# jungle highlands to the south-west, rolling forest hills past them
	h += 5.5 * _gauss(p, JUNGLE_HIGH, 38.0) * inland
	h += 4.0 * _gauss(p, FOREST, 42.0) * inland
	# lighthouse hill (falls into the sea as a cliff on the east side)
	h += 19.0 * _gauss(p, HILL, 23.0)
	return h


## The ground: the old island's, the southern lands where they stand higher, the upper town.
func _height_fn(x: float, z: float, shelf := 1.0) -> float:
	var p := Vector2(x, z)
	return _falls(p, _upper(p, maxf(_height_old(x, z, shelf), _grown(p, shelf))))


## The falls' pool: its ground levelled round it, its basin dug (KitLandmarks.POOL_DEPTH).
func _falls(p: Vector2, h: float) -> float:
	var d := p.distance_to(POOL)
	if d > 12.0:
		return h
	h = lerpf(h, _pool_y, 1.0 - _smooth(7.0, 12.0, d))
	return lerpf(h, _pool_y - KitLandmarks.POOL_DEPTH, 1.0 - _smooth(3.0, 6.4, d))


## The upper town's hill's half width at z (flat across it, then 9 m of flank down to the land).
static func _up_w(z: float) -> float:
	return minf(9.0 + 0.3 * (z - UP_Z0), 16.0)


## The hill's rise over the plaza at z: a straight climb to the terrace, flat over it, down behind.
static func _up_rise(z: float) -> float:
	return UP_RISE * clampf((z - UP_Z0) / (UP_Z1 - UP_Z0), 0.0, 1.0) * (1.0 - _smooth(UP_Z2, UP_Z2 + 25.0, z))


## The banded ground's rise at z: each band flat at its lane's rise to 3 m short of the next.
static func _up_band(z: float) -> float:
	if z < UP_BANDS[0] or z > UP_Z1:
		return _up_rise(z)
	for k in range(UP_BANDS.size()):
		var zl: float = UP_BANDS[k]
		var nx: float = UP_BANDS[k + 1] if k + 1 < UP_BANDS.size() else UP_Z1
		if z <= nx:
			if z <= nx - 3.0:
				return _up_rise(zl)
			return lerpf(_up_rise(zl), _up_rise(nx), (z - nx + 3.0) / 3.0)
	return _up_rise(z)


## 0..1: how much of the upper town's hill stands at p.
static func _up_mask(p: Vector2) -> float:
	var w := _up_w(p.y)
	return (1.0 - _smooth(w, w + 8.0, absf(p.x - UP_X))) * _smooth(UP_Z0 - 7.0, UP_Z0 - 1.0, p.y) * (1.0 - _smooth(UP_Z2 + 18.0, UP_Z2 + 28.0, p.y))


## The ground under the long stair (sunk UP_SINK under its line, easing in at its foot).
static func _up_corridor(p: Vector2) -> bool:
	return absf(p.x - UP_X) <= 1.51 and p.y >= UP_Z0 and p.y <= UP_Z1


## The upper town's ground over h (the plaza's height plus its rise), never below the land.
func _upper(p: Vector2, h: float) -> float:
	var m := _up_mask(p)
	if m <= 0.0:
		return h
	var h0: float = _flat_zones[0][1]
	var r := _up_rise(p.y) - UP_SINK * _smooth(UP_Z0, UP_Z0 + 3.0, p.y) if _up_corridor(p) else _up_band(p.y)
	return maxf(h, lerpf(h, h0 + r, m))


func _height_old(x: float, z: float, shelf := 1.0) -> float:
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


## Bays and capes round the southern lands (bearings from LOBE).
static func _lobe_capes(ang: float) -> float:
	return 40.0 * (1.0 - _smooth(2.0, 16.0, _bearing_off(ang, 45.0))) + 22.0 * (1.0 - _smooth(3.0, 18.0, _bearing_off(ang, 140.0))) \
		- 18.0 * (1.0 - _smooth(4.0, 14.0, _bearing_off(ang, 112.0))) - 30.0 * (1.0 - _smooth(5.0, 17.0, _bearing_off(ang, -8.0))) \
		+ 16.0 * (1.0 - _smooth(3.0, 12.0, _bearing_off(ang, 168.0)))


## How far p is outside the southern lands' coast (negative inland): the sea kept round the
## cove, the second cove's bay and its mouth.
func _lobe_t(p: Vector2) -> float:
	var v := p - LOBE
	var ang := atan2(v.y, v.x)
	var r := LOBE_R + _coast_noise.get_noise_2d(cos(ang) * 60.0 + 300.0, sin(ang) * 60.0) * 24.0 + _lobe_capes(ang)
	var t := v.length() - r + _shape_noise.get_noise_2d(p.x + 500.0, p.y) * 30.0
	t = maxf(t, COVE_SEA - p.distance_to(COVE))
	return maxf(t, _cove2(p))


## The second cove's bay and its mouth: > 0 in the water (how far in).
static func _cove2(p: Vector2) -> float:
	var m := Geometry2D.get_closest_point_to_segment(p, COVE2, COVE2 + COVE2_MOUTH * 70.0)
	return maxf(27.0 - p.distance_to(COVE2), 15.0 - p.distance_to(m))


## The southern lands' ground (land, shelf or seabed), sunk out of the way where the old island's
## interior is and round GROW_KEEP.
func _grown(p: Vector2, shelf: float) -> float:
	var t := _lobe_t(p)
	if t > 75.0:
		return SEAFLOOR * 2.0
	var w := _smooth(-30.0, -6.0, _old_t(p))
	for k in GROW_KEEP:
		w *= _smooth(float(k[1]), float(k[1]) + 18.0, p.distance_to(k[0]))
	if w <= 0.0:
		return SEAFLOOR * 2.0
	var h: float
	if t < 0.0:
		h = lerpf(0.5, 4.3, pow(clampf(-t / 50.0, 0.0, 1.0), 0.85))
	else:
		# (no wading shelf in the second cove: deep enough to swim and moor in)
		h = Coast.shelf(lerpf(0.5, SEAFLOOR * 0.35, _smooth(0.0, 24.0, t)), t, shelf * _shelf_room(p) * (1.0 - _smooth(2.0, 8.0, _cove2(p))), SEAFLOOR) \
			if _cove2(p) > 0.0 else Coast.shelf(lerpf(0.5, SEAFLOOR, _smooth(0.0, 60.0, t)), t, shelf * _shelf_room(p), SEAFLOOR)
	var inland := clampf(-t / 35.0 - 0.15, 0.0, 1.0)
	h += (_roll_noise.get_noise_2d(p.x, p.y) * 2.6 + _detail_noise.get_noise_2d(p.x, p.y) * 0.45) * inland
	h += (16.0 * _gauss(p, HIGHLAND, 36.0) + 3.0 * _gauss(p, FARM, 70.0)) * inland
	var spine := Geometry2D.get_closest_point_to_segment(p, HIGHLAND, CAPE_TIP).distance_to(p)
	h += 9.0 * (1.0 - _smooth(5.0, 18.0, spine)) * _smooth(-1.0, 4.0, -t)
	return lerpf(SEAFLOOR * 2.0, h, w)


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
	_pool_y = maxf(_height_old(POOL.x, POOL.y), _grown(POOL, 1.0))
	var dir := Vector2.from_angle(deg_to_rad(WRECK_BEARING))
	var d := LOBE_R * 0.6
	while _lobe_t(LOBE + dir * d) < 0.0:
		d += 0.5
	wreck_site = [LOBE + dir * (d - 2.0), dir]


## The grid's (0, 0) vertex, island space.
static func grid_origin() -> Vector2:
	return GRID_C - Vector2(HALF, HALF)


## The terrain grid's square, island space.
static func grid_rect() -> Rect2:
	return Rect2(grid_origin(), Vector2(EXTENT, EXTENT))


## The ground (and the old island's, for its plants), its cliffs and their rock; which vertices
## the grown land changed. The coast rock keeps the old grid's indices for its seeds.
func _generate_heights() -> void:
	var n := (RES + 1) * (RES + 1)
	var o := grid_origin()
	var t0 := Time.get_ticks_usec()
	# (a row a task on the worker threads: the height function only reads)
	var rows: Array = []
	rows.resize(RES + 1)
	var task := WorkerThreadPool.add_group_task(func(iz: int):
		var a := PackedFloat32Array()
		var b := PackedFloat32Array()
		a.resize(RES + 1)
		b.resize(RES + 1)
		for ix in range(RES + 1):
			var x := -HALF + ix * CELL + GRID_C.x
			var z := -HALF + iz * CELL + GRID_C.y
			var h := _height_old(x, z)
			a[ix] = h
			b[ix] = _falls(Vector2(x, z), _upper(Vector2(x, z), maxf(h, _grown(Vector2(x, z), 1.0))))
		rows[iz] = [a, b], RES + 1)
	WorkerThreadPool.wait_for_group_task_completion(task)
	var old := PackedFloat32Array()
	heights = PackedFloat32Array()
	for r in rows:
		old.append_array(r[0])
		heights.append_array(r[1])
	var t1 := Time.get_ticks_usec()
	var coast := Coast.cliffs(heights, RES, CELL, HALF, _cliff_allow, func(p: Vector2) -> float: return _height_fn(p.x, p.y, 0.0), GRID_C)
	heights = coast["heights"]
	_coast_rock = coast["rock"]
	coast_cols = coast["cols"]
	for c in coast_cols:
		c[4] = int(c[4]) - OLD_SHIFT.x
		c[5] = int(c[5]) - OLD_SHIFT.y
	var t2 := Time.get_ticks_usec()
	_land_heights = Coast.cliffs(old, RES, CELL, HALF, _cliff_allow, func(p: Vector2) -> float: return _height_old(p.x, p.y, 0.0), GRID_C)["heights"]
	var t3 := Time.get_ticks_usec()
	_changed.resize(n)
	_changed.fill(0)
	for i in range(n):
		if absf(heights[i] - _land_heights[i]) <= 0.002:
			continue
		var ix := i % (RES + 1)
		var iz := i / (RES + 1)
		for dz in range(maxi(iz - 1, 0), mini(iz + 2, RES + 1)):
			for dx in range(maxi(ix - 1, 0), mini(ix + 2, RES + 1)):
				_changed[dz * (RES + 1) + dx] = 1
	build_ms["land: heights"] = int((t1 - t0) / 1000)
	build_ms["land: cliffs"] = int((t2 - t1) / 1000)
	build_ms["land: old cliffs"] = int((t3 - t2) / 1000)
	build_ms["land: changed"] = int((Time.get_ticks_usec() - t3) / 1000)
	assert(o.x + OLD_SHIFT.x * CELL == -OLD_HALF and o.y + OLD_SHIFT.y * CELL == -OLD_HALF)


## Did the grown land change the ground round p (from the old island's)?
func _grown_at(p: Vector2) -> bool:
	var o := grid_origin()
	var ix := clampi(int(round((p.x - o.x) / CELL)), 0, RES)
	var iz := clampi(int(round((p.y - o.y) / CELL)), 0, RES)
	return _changed[iz * (RES + 1) + ix] == 1


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


## The den's sea hoist (from the rim out over its drop); rock along the ridge and round
## the plateau's landward rim, and none where the hoist and the pier come down the sea
## cliff (nor where the old climb's hoist stood: its gap in the rim is kept).
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
	den_plan = {"sea_hoist": [sea, sea_tip]}
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


## Grell's cliff path: planned on the land as it was, then cut into it (its rock is meshed
## on a worker while the rest builds); no coast rock where it runs; its foot, its top and
## the guard up there.
func _plan_den_path() -> void:
	den_path = KitCliffPath.plan(DEN, DEN_PATH, func(p: Vector2) -> float: return height_at(p.x, p.y), SEEDS["climb"])
	heights = den_path.carve(heights, RES, CELL, HALF, GRID_C)
	_path_task = WorkerThreadPool.add_task(func(): _path_mesh = den_path.mesh())
	coast_cols = coast_cols.filter(func(c: Array) -> bool: return not den_path.covers(c[0], 6.0))
	var foot := DEN + Vector2.from_angle(deg_to_rad(PATH_FOOT[0])) * float(PATH_FOOT[1])
	var top: Vector2 = DEN_PATH["cleft"]["to"]
	var inward := (DEN - top).normalized()
	den_plan.merge({"start": foot, "face": (den_path.point(den_path.th0) - foot).normalized(), "top": top,
		"route": den_path.route(), "jumps": den_path.jumps(), "guard": [top + inward * 2.5, top - inward * 3.0]})


## The trodden way along the beach from the den path's old end to the cliff path's foot.
func _den_trail() -> PackedVector2Array:
	var pts := PackedVector2Array([climb_start()[0]])
	for e in [[55.0, 35.5], [72.0, 36.0], [88.0, 35.0], PATH_FOOT]:
		pts.append(DEN + Vector2.from_angle(deg_to_rad(e[0])) * float(e[1]))
	pts.append(den_path.point(den_path.th0))
	return pts


## The old climb's footprint, reserved as it was (KitCamps' den climb, until 2026-10-15).
func _old_climb_reserves() -> void:
	for e in climb_pieces():
		if e["k"] == "slab":
			reserve(e["at"], float(e["r"]) + 1.0)
		else:
			for q in e["line"]:
				reserve(Vector2(q.x, q.z), 2.0)
	reserve(climb_start()[0], 3.5)


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
	var fx := (x + HALF - GRID_C.x) / CELL
	var fz := (z + HALF - GRID_C.y) / CELL
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
## foot of its cliff path, then the top of the path once you're on it, then the den.
func guide_to(place: String, from: Vector3) -> Vector3:
	if place != "den":
		return place_of(place)
	var l := to_local(from)
	var at := Vector2(l.x, l.z)
	if at.distance_to(DEN) < DEN_OUT + 4.0 and l.y > DEN_TOP - 3.0:
		return place_of("den")
	var start: Vector2 = den_plan["start"]
	var on := at.distance_to(start) < 10.0
	for q in den_plan["route"]:
		on = on or (at.distance_to(Vector2(q.x, q.z)) < 4.0 and absf(l.y - q.y) < 3.0)
	if on:
		var top: Vector2 = den_plan["top"]
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


func _add_path(pts: Array, half_width: float, at := -1) -> void:
	var smooth := _catmull(pts)
	var rect := Rect2(smooth[0], Vector2.ZERO)
	for q in smooth:
		rect = rect.expand(q)
	if at >= 0:
		paths[at] = smooth
		path_widths[at] = half_width
		path_bounds[at] = rect.grow(half_width + 4.0)
		return
	paths.append(smooth)
	path_widths.append(half_width)
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
	# (the old pieces and plants keep to the paths as they ran before the upper town)
	_frozen = [paths.duplicate(), path_widths.duplicate(), path_bounds.duplicate()]
	# the ruins and cove paths now skirt the upper town's hill
	_add_path([VILLAGE + Vector2(-3, 14), Vector2(-14, -36), Vector2(-26, -14), Vector2(-33, 8), Vector2(-34, 28), Vector2(-48, 46), RUINS + Vector2(6, -5)], 1.3, 3)
	_add_path([VILLAGE + Vector2(4, 14), Vector2(20, -38), Vector2(32, -14), Vector2(40, 12), Vector2(46, 44), CAMP + Vector2(-2, -4)], 1.3, 4)
	# the southern lands (worn in now, seen by path_dist once their pieces build): off the cove path
	# south over the old bay to the windmill hamlet, on to the highland's foot, and down from the ruins
	_add_path([Vector2(40, 12), Vector2(26, 58), Vector2(12, 104), Vector2(-2, 150), Vector2(-24, 186), FARM + Vector2(12, -8)], 1.3)
	_add_path([FARM + Vector2(12, -8), Vector2(-14, 232), Vector2(4, 262), Vector2(14, 278)], 1.2)
	_add_path([RUINS + Vector2(-4, 9), Vector2(-74, 110), Vector2(-66, 150), FARM + Vector2(-7, -16)], 1.2)
	# the upper town: the long stair, the second row's lanes (UP_BANDS)
	_add_path([Vector2(UP_X, UP_Z0 - 1.0), Vector2(UP_X, UP_Z1 + 2.0)], 1.6)
	for k in range(UP_BANDS.size()):
		var zl: float = UP_BANDS[k]
		var w := _up_w(zl) + 3.0
		_add_path([Vector2(UP_X - w, zl), Vector2(UP_X + w, zl)], 1.2)
	# the switchback down the terrace's back to the cove path
	_add_path([Vector2(UP_X + 11.0, UP_Z2 - 1.5), Vector2(-6, 39), Vector2(16, 46), Vector2(30, 49), Vector2(44, 42)], 1.3)
	# out to the wild places: from the highland's foot round to the wreck, from the farm down to the second cove
	var ws: Vector2 = wreck_site[0] - (wreck_site[1] as Vector2) * 13.0
	_add_path([Vector2(14, 278), Vector2(40, 284), ws.lerp(Vector2(40, 284), 0.4), ws], 1.1)
	_add_path([Vector2(-14, 232), Vector2(-36, 284), Vector2(-46, 312), COVE2 + Vector2(4, -31)], 1.1)


## The grown land's paths count from here on (its pieces and plants).
func _open_grown() -> void:
	_open_paths = paths.size()
	_grow_layer = true


## Distance to the nearest path's edge, of paths `from` to `n` (-1: those open; the old ones while
## the old plants decide). Before the grown land's pieces (and while the old plants decide) the old
## paths run as they did before the upper town, unless `live`.
func _path_dist(p: Vector2, n := -1, from := 0, live := false) -> float:
	if n < 0:
		n = OLD_PATHS if _old_only else _open_paths
	var frozen := not live and (_old_only or _open_paths == OLD_PATHS)
	var best := 9999.0
	for i in range(from, n):
		var old := frozen and i < OLD_PATHS
		if not ((_frozen[2][i] if old else path_bounds[i]) as Rect2).has_point(p):
			continue
		var pts: PackedVector2Array = _frozen[0][i] if old else paths[i]
		var hw: float = _frozen[1][i] if old else path_widths[i]
		for j in range(pts.size() - 1):
			var a := pts[j]
			var b := pts[j + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t) - hw)
	return best


func path_dist(p: Vector2) -> float:
	return _path_dist(p)


## The terrain's wear: every path, open or not.
func _path_weight(p: Vector2) -> float:
	var d := _path_dist(p, paths.size(), 0, true)
	return 1.0 - _smooth(-0.6, 0.6, d)


func _excluded(p: Vector2, pad: float = 0.0, under := INF) -> bool:
	return _ex_hit(_ex_old, p, pad, under) or (not _old_only and _ex_hit(_ex_new, p, pad, under))


static func _ex_hit(ex: Array, p: Vector2, pad: float, under: float) -> bool:
	for e in ex[1]:
		if float(e[1]) < under and p.distance_to(e[0]) < float(e[1]) + pad:
			return true
	var reach := maxf(EX_CELL + pad, 0.0)
	var cells: Dictionary = ex[0]
	for cx in range(floori((p.x - reach) / EX_CELL), floori((p.x + reach) / EX_CELL) + 1):
		for cz in range(floori((p.y - reach) / EX_CELL), floori((p.y + reach) / EX_CELL) + 1):
			var list = cells.get(Vector2i(cx, cz))
			if list == null:
				continue
			for e in list:
				if float(e[1]) < under and p.distance_to(e[0]) < float(e[1]) + pad:
					return true
	return false


func excluded(p: Vector2, pad: float, under := INF) -> bool:
	return _excluded(p, pad, under)


## The places on the map (tools/dev/bhmapshot.gd).
func map_places() -> Array:
	return [VILLAGE, MARKET, TRAINING, HILL, RUINS, COVE, CAMP, SMUGGLERS, FOREST, CAVE, DEN, LOBE, HIGHLAND, FARM, COVE2, CAPE_TIP]


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
	var trail := _den_trail()
	for iz in range(RES + 1):
		for ix in range(RES + 1):
			var i := iz * (RES + 1) + ix
			var x := -HALF + ix * CELL + GRID_C.x
			var z := -HALF + iz * CELL + GRID_C.y
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
				if p.distance_to(DEN) < 50.0:
					var td := INF
					for j in range(trail.size() - 1):
						td = minf(td, Geometry2D.get_closest_point_to_segment(p, trail[j], trail[j + 1]).distance_to(p))
					dirt = maxf(dirt, 1.0 - _smooth(0.7, 1.9, td))
				dirt = maxf(dirt, _disk(p, TRAINING, 10.0, 13.0))
				dirt = maxf(dirt, _disk(p, RUINS, 8.0, 11.0))
				dirt = maxf(dirt, _disk(p, HILL, 5.0, 8.0))
				dirt = maxf(dirt, _disk(p, CAVE, 20.0, 25.0))
				dirt = maxf(dirt, _disk(p, DEN, 13.0, 19.0) * 0.8)
				# packed earth behind the quay, among the waterfront houses
				dirt = maxf(dirt, harbour.earth(x, z))
				dirt = maxf(dirt, _disk(p, dock_root, 3.0, 6.0) * 0.6)
				# the fields' tilled ground, the hamlet's yard
				dirt = maxf(dirt, maxf(KitFarm.tilled(FIELDS, p) * 0.9, _disk(p, FARM, 8.0, 12.0) * 0.75))
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
	var e := [p, r]
	exclusions.append(e)
	var ex: Array = _ex_new if _grow_layer else _ex_old
	if r > EX_CELL:
		ex[1].append(e)
		return
	var key := Vector2i(floori(p.x / EX_CELL), floori(p.y / EX_CELL))
	if not ex[0].has(key):
		ex[0][key] = []
	ex[0][key].append(e)


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
		"lean_to": "right", "chimney": true, "lamp_light": true, "awning": "blue"}, VILLAGE + Vector2(-17, -25), Vector2(1, 0))
	_harbor = kit.house({"w": 9.0, "d": 5.5, "h": 3.0, "roof": "shed", "wall": "planks_weathered", "roof_tex": "roof_tiles",
		"porch": 1.6, "sign": "sign_fish", "door_x": 2.0, "name": "Harbor", "lamp_light": true}, VILLAGE + Vector2(15, -28), Vector2(-1, 0))
	kit.house({"w": 4.0, "d": 4.5, "floors": 2, "wall": "stone_brick", "wall2": "planks", "roof": "gable",
		"roof_tex": "thatch", "pitch": 0.75, "jetty": 0.3, "awning": "red"}, VILLAGE + Vector2(-9, -31), Vector2(1, 0))
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


# ==========================================================================
# The grown town (2026-10-17): the market street, the upper town (KitStreet)
# ==========================================================================
## Bram's walk up from the harbour (brinehollow_cast.gd): the street keeps it clear.
func _bram_walk() -> Array:
	return [dock_shore + Vector2(-8.0, 9.0), dock_shore + Vector2(3.0, 12.0), VILLAGE + Vector2(1.5, -26), VILLAGE + Vector2(3, -14)]


func _off_walk(q: Vector2, r: float) -> bool:
	var w := _bram_walk()
	for i in range(w.size() - 1):
		if Geometry2D.get_closest_point_to_segment(q, w[i], w[i + 1]).distance_to(q) < r:
			return false
	return true


## The quay-to-plaza road as a market street: cobbled out to its stalls, shopfronts where a house
## fits back from it, barrows, rugs and stalls between, shade cloths and bunting across, lamps.
func _build_market_street() -> void:
	var rng := kit.rng(0, SEEDS["street"])
	var road: PackedVector2Array = paths[0]
	var goods: Array = kit.style["goods"]
	var quads: Array = []
	for sd: float in [-1.0, 1.0]:
		var line := PackedVector2Array()
		for e in KitVillage.along(road, 1.5):
			line.append(e[0])
		for i in range(line.size() - 1):
			var t0 := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()
			var t1 := (line[mini(i + 2, line.size() - 1)] - line[i]).normalized()
			var n0 := Vector2(-t0.y, t0.x) * sd
			var n1 := Vector2(-t1.y, t1.x) * sd
			if line[i].distance_to(VILLAGE) < 14.0:
				continue
			KitPaving._quad(kit, quads, line[i] + n0 * 1.7, line[i] + n0 * 3.7, line[i + 1] + n1 * 3.7, line[i + 1] + n1 * 1.7)
	KitPaving.build(kit, quads, "StreetCobbles")
	var length := 0.0
	for i in range(road.size() - 1):
		length += road[i].distance_to(road[i + 1])
	var stalls := ["fruit", "cloth", "pots", "fish"]
	var cloths := ["awning_red", "awning_blue", "awning_gold", "awning_green"]
	var shop_walls := ["plaster", "planks", "stone_brick", "plaster"]
	var shop_signs := ["", "sign_fish", "", ""]
	var across: Array = []
	var n_shop := 0
	var n_stall := 0
	# a lamp a third of the way up either side, on the cobbles' edge
	for k in range(2):
		var e: Array = KitVillage.along(road, length, length / 3.0 * (k + 1))[0]
		var nrm := Vector2(-e[1].y, e[1].x) * (1.0 if k == 0 else -1.0)
		for tries in range(6):
			var lp: Vector2 = e[0] + nrm * 3.5 + e[1] * (tries - 3) * 1.3
			if not _excluded(lp, 0.4) and _off_walk(lp, 1.0):
				KitLights.post(kit, lp, face_yaw(-nrm) - PI * 0.5, 0.3)
				break
	# shopfronts, square to the street and shoulder to shoulder where the old houses leave room
	var fronts: Array = []
	for e in KitVillage.along(road, 1.0, 6.0, length - 4.0):
		var q: Vector2 = e[0]
		var t: Vector2 = e[1]
		for sd: float in [-1.0, 1.0]:
			var nrm := Vector2(-t.y, t.x) * sd
			var w := rng.randf_range(4.6, 5.6)
			var d := rng.randf_range(4.3, 4.8)
			var sp := q + nrm * (5.6 + d * 0.5)
			if _ex_hit(_ex_old, sp, maxf(w, d) * 0.6, INF) or _path_dist(sp) < maxf(w, d) * 0.6 or not _off_walk(sp, maxf(w, d) * 0.5 + 1.0) \
					or fronts.any(func(f: Array) -> bool: return sp.distance_to(f[0]) < (w + float(f[1])) * 0.5 + 0.5) \
					or _ex_hit(_ex_new, q + nrm * 4.4, 0.8, INF):
				continue
			var kind: String = stalls[n_shop % stalls.size()]
			var spec := {"w": w, "d": d, "h": rng.randf_range(2.6, 2.9), "floors": 2, "wall": shop_walls[n_shop % 4], "wall2": "plaster",
				"roof": ["gable_front", "gable", "hip"][rng.randi() % 3], "roof_tex": "roof_tiles" if rng.randf() < 0.7 else "thatch",
				"pitch": rng.randf_range(0.5, 0.7), "jetty": 0.3, "door_x": rng.randf_range(0.8, 1.2) * (1.0 if rng.randf() < 0.5 else -1.0),
				"awning": ["red", "blue", "green"][n_shop % 3], "sign": shop_signs[n_shop % 4], "seed": 8300 + n_shop,
				"name": "Shop%d" % n_shop, "smoke": false}
			town_spots["shops"].append(KitStreet.shopfront(kit, spec, sp, -nrm, kind, rng))
			fronts.append([sp, w])
			n_shop += 1
	for e in KitVillage.along(road, 3.3, 7.0, length - 5.0):
		var q: Vector2 = e[0]
		var t: Vector2 = e[1]
		var row: Array = []
		for sd: float in [-1.0, 1.0]:
			var nrm := Vector2(-t.y, t.x) * sd
			var kind: String = stalls[(n_shop + n_stall) % stalls.size()]
			var st := q + nrm * 4.7
			var shop_at: Array = fronts.filter(func(f: Array) -> bool: return (f[0] as Vector2).distance_to(q + nrm * 7.9) < 2.2)
			if not shop_at.is_empty():
				row.append(q + nrm * 5.4)
				continue
			if _excluded(st, 1.7) or _path_dist(st) < 1.0 or not _off_walk(st, 1.4):
				continue
			var node: Node3D
			match n_stall % 3:
				0:
					node = Buildings.stall(kind)
				1:
					node = KitStreet.barrow(kind, goods, cloths[n_stall % 4], rng.randi())
				_:
					var rugs: Array = kit.style["rugs"]
					node = KitStreet.rug_stall(kind, goods, rugs[n_stall % rugs.size()], cloths[(n_stall + 1) % 4], rng.randi())
			node.name = "StreetStall%d" % n_stall
			kit.place(node, st, face_yaw(-nrm), 1.6)
			town_spots["stalls"].append(node)
			row.append(st + nrm * 1.2)
			n_stall += 1
		if row.size() == 2:
			across.append(row)
	# shade cloths and bunting across the street between what lines it
	var mb := MeshBuilder.new()
	for k in range(across.size()):
		var a: Vector2 = across[k][0]
		var b: Vector2 = across[k][1]
		if k % 2 == 0:
			KitStreet.shade(kit, mb, a, b, 3.4, 1.6, cloths[k % 4])
		else:
			KitVillage.pole(kit, mb, a, 3.6)
			KitVillage.pole(kit, mb, b, 3.6)
			KitVillage.bunting(kit, mb, Vector3(a.x, hv(a) + 3.5, a.y), Vector3(b.x, hv(b) + 3.5, b.y), rng)
	# barrows and rugs into the gaps left
	for e in KitVillage.along(road, 2.2, 5.0, length - 4.0):
		var q: Vector2 = e[0]
		var t: Vector2 = e[1]
		for sd: float in [-1.0, 1.0]:
			var nrm := Vector2(-t.y, t.x) * sd
			var st := q + nrm * 4.6
			if _excluded(st, 1.2) or _path_dist(st) < 1.2 or not _off_walk(st, 1.4):
				continue
			var kind: String = stalls[n_stall % stalls.size()]
			var node: Node3D = KitStreet.barrow(kind, goods, cloths[n_stall % 4], rng.randi()) if n_stall % 2 == 0 \
				else KitStreet.rug_stall(kind, goods, kit.style["rugs"][n_stall % kit.style["rugs"].size()], cloths[(n_stall + 1) % 4], rng.randi())
			node.name = "StreetStall%d" % n_stall
			kit.place(node, st, face_yaw(-nrm), 1.3)
			town_spots["stalls"].append(node)
			n_stall += 1
	# and the edges dressed: cargo, planters, benches facing the street, a cart, barrels by the doors
	var items: Array = []
	var occ: Array = []
	var k := 0
	for e in KitVillage.along(road, 1.7, 3.0, length - 3.0):
		var q: Vector2 = e[0]
		var t: Vector2 = e[1]
		for sd: float in [-1.0, 1.0]:
			var nrm := Vector2(-t.y, t.x) * sd
			var at := q + nrm * 4.25
			if _excluded(at, 0.8) or not _off_walk(at, 1.2) or not KitVillage.occ_free(occ, at, 0.9):
				continue
			match k % 5:
				0, 3:
					KitVillage.plan_cargo(kit, items, at, face_yaw(t), rng, ["crate", "barrel", "sack", "basket"][k % 4])
					occ.append([at, 1.0])
				1:
					KitVillage.plan_put(kit, items, occ, "planter", at, 0.0, 0.7, {"r": 0.5})
				2:
					KitVillage.plan_put(kit, items, occ, "bench", at + nrm * 0.2, face_yaw(-nrm), 1.0)
				_:
					KitVillage.plan_put(kit, items, occ, "cart", at + nrm * 0.3, face_yaw(t), 1.2)
			kit.reserve(at, 0.9)
			k += 1
	var built: Array = KitVillage.build_items(kit, items).map(func(e: Array): return e[1]).filter(func(n): return n != null)
	KitVillage.build_cargo(kit, items)
	_town_parts.append_array(town_spots["shops"] + town_spots["stalls"] + built)
	var mi := mb.to_instance("StreetCloths")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = KitStreet.RANGE
	kit.add(mi)


## The upper town: the long stair up the hill's middle, the bands' retaining blocks, the second row
## of houses on the two lower bands with their lanes paved, a yard's worth of dressing each, steps
## down the flanks from the second lane to the ruins and cove paths.
func _build_upper_town() -> void:
	var rng := kit.rng(0, SEEDS["upper"])
	var h0: float = _flat_zones[0][1]
	var lv := func(zl: float) -> float: return h0 + _up_rise(zl)
	# the long stair: flights between landings at each lane, up to the terrace's edge
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "LongStair"
	var line := PackedVector3Array([Vector3(UP_X, h0, UP_Z0)])
	for zl: float in UP_BANDS:
		line.append(Vector3(UP_X, lv.call(zl), zl - 1.5))
		line.append(Vector3(UP_X, lv.call(zl), zl + 1.5))
	line.append(Vector3(UP_X, h0 + UP_RISE, UP_Z1))
	for i in range(line.size() - 1):
		var a := line[i]
		var b := line[i + 1]
		if absf(b.y - a.y) < 0.01:
			# a landing, flagged, as wide as the stair and its curbs' gap for the lane
			var c := (a + b) * 0.5
			mb.add_box(PSXMat.lit("stone_brick"), Transform3D(Basis(), Vector3(c.x, c.y - 0.7, c.z)), Vector3(3.1, 1.4, b.z - a.z + 0.02), 0.7, Color(0.85, 0.85, 0.85), false)
			mb.add_box(PSXMat.lit("flagstones", Color(0.95, 0.92, 0.86)), Transform3D(Basis(), Vector3(c.x, c.y + 0.02, c.z)), Vector3(3.14, 0.05, b.z - a.z + 0.04), 0.7)
			KitStreet._box(body, Vector3(3.1, 0.3, b.z - a.z), Transform3D(Basis(), Vector3(c.x, c.y - 0.13, c.z)))
		else:
			KitStreet.stairs(mb, body, a, b, 3.0)
			# its sides walled down to the band beside it
			for sd: float in [-1.0, 1.0]:
				var x := UP_X + sd * 1.9
				KitStreet.wall(kit, mb, body, PackedVector3Array([Vector3(x, a.y - 0.1, a.z), Vector3(x, b.y - 0.1, b.z)]), 0.36, 0.0)
	town_spots["stair"] = line
	_town_parts.append(KitStreet.finish(kit, mb, body))
	# the bands' retaining blocks (the step to the next band, but where the stair climbs through)
	var wb := MeshBuilder.new()
	var wbody := StaticBody3D.new()
	wbody.name = "TerraceWalls"
	var steps := [UP_BANDS[1], UP_BANDS[2], UP_Z1]
	for nx: float in steps:
		var w := _up_w(nx) + 7.0
		for sd: float in [-1.0, 1.0]:
			var run := PackedVector3Array()
			var x := UP_X + sd * 1.9
			while absf(x - UP_X) < w:
				var top := hv(Vector2(x, nx))
				if top - hv(Vector2(x, nx - 3.0)) < 0.6:
					break
				run.append(Vector3(x, top - 0.02, nx - 1.5))
				x += sd * 1.5
			if run.size() >= 2:
				KitStreet.wall(kit, wb, wbody, run, 3.0, 0.0)
	_town_parts.append(KitStreet.finish(kit, wb, wbody))
	# the second row: houses on the two lower bands facing their lanes, doors to the north
	var occ: Array = []
	for nx: float in steps:
		for k in range(-12, 13):
			occ.append([Vector2(UP_X + k * 2.5, nx - 1.6), 1.5])
	var walls := ["plaster", "planks", "planks_weathered", "stone_brick", "plaster"]
	var roofs := ["gable", "hip", "gable_front", "gable"]
	var items: Array = []
	var n := 0
	for b in range(2):
		var zl: float = UP_BANDS[b]
		var zc := zl + 5.4
		var xs := [-1.2, -7.6, 10.2, 16.6] if b == 0 else [-1.2, -7.6, -14.0, 10.2, 16.6, 23.0]
		for x: float in xs:
			var w := rng.randf_range(4.6, 5.4)
			var d := rng.randf_range(4.2, 4.6)
			var p := Vector2(x, zc)
			if _ex_hit(_ex_old, p, maxf(w, d) * 0.6, INF):
				continue
			var spec := {"w": w, "d": d, "h": rng.randf_range(2.4, 2.8), "floors": 2 if rng.randf() < 0.55 else 1,
				"wall": walls[(n + b) % walls.size()], "wall2": "plaster" if rng.randf() < 0.6 else "planks",
				"roof": roofs[rng.randi() % roofs.size()], "roof_tex": "roof_tiles" if rng.randf() < 0.6 else "thatch",
				"pitch": rng.randf_range(0.45, 0.75), "jetty": rng.randf_range(0.2, 0.4), "door_x": rng.randf_range(-0.9, 0.9),
				"chimney": rng.randf() < 0.4, "smoke": false, "seed": 8400 + n, "name": "UpperHouse%d" % n,
				"lamp_light": n % 4 == 1, "lean_to": ["", "", "left", "right"][rng.randi() % 4]}
			var house := kit.house(spec, p, Vector2(0, -1))
			town_spots["houses"].append(house)
			occ.append_array(KitVillage.plot_circles(p, Vector2(0, -1), w, d, 1.6))
			KitVillage.plan_yard(kit, items, occ, p, Vector2(0, -1), w, d, d * 0.5 + 0.8, rng)
			n += 1
	# the lanes along each band's front, flagged, and steps down the second's flanks to the paths
	var lq: Array = []
	for k in range(UP_BANDS.size()):
		var lane: PackedVector2Array = paths[OLD_PATHS + 4 + k]
		town_spots["lanes"].append(lane)
		# (flagged from the block's edge to the doors)
		var front := PackedVector2Array()
		for q in lane:
			front.append(q + Vector2(0, 1.2))
		KitPaving.plan_path(kit, lq, front, 2.1)
	KitPaving.build(kit, lq, "Lanes", "flagstones", Color(0.92, 0.9, 0.84))
	var fb := MeshBuilder.new()
	var fbody := StaticBody3D.new()
	fbody.name = "FlankSteps"
	for b in [1, 2]:
		var zl: float = UP_BANDS[b]
		for sd: float in [-1.0, 1.0]:
			var top := Vector2(UP_X + sd * (_up_w(zl) - 0.5), zl)
			var foot := Vector2(UP_X + sd * (_up_w(zl) + 9.5), zl)
			KitStreet.ground_stairs(kit, fb, fbody, top, foot, 2.2)
			town_spots["lanes"].append(PackedVector2Array([top, foot]))
	_town_parts.append(KitStreet.finish(kit, fb, fbody))
	var built: Array = KitVillage.build_items(kit, items).map(func(e: Array): return e[1]).filter(func(n): return n != null)
	KitVillage.build_cargo(kit, items)
	_town_parts.append_array(town_spots["houses"] + built)


## The shrine terrace at the top of the long stair: the gate at the stair's head, the flagged way up
## between stone lanterns to the shrine, benches, a parapet along the terrace's front, the old tree; the
## third band below it with the teahouse beside the stair, two shops and a house; the switchback down
## the terrace's back to the cove path, trodden and walled on its drop.
func _build_shrine_terrace() -> void:
	var rng := kit.rng(0, SEEDS["shrine"])
	var h0: float = _flat_zones[0][1]
	var top := h0 + UP_RISE
	# the third band: the teahouse west of the stair, shops east of it, a house at the west end
	var zc: float = UP_BANDS[2] + 5.4
	var tea := BrinehollowModels.teahouse(rng.randi(), 7.4, 3.4)
	var tp := Vector2(UP_X - 7.1, UP_Z1 - 3.0 - 1.9)
	kit.place(tea, tp, PI, 0.0)
	kit.reserve(tp + Vector2(0, -1.4), 5.2)
	town_spots["teahouse"] = tea
	KitLights.light(kit, tea, tea.get_node("Lantern").position, 1.2, 8.0)
	var specs := [[Vector2(UP_X + 5.7, zc), "pots", "plaster", "red"], [Vector2(UP_X + 11.9, zc), "cloth", "planks", "blue"]]
	for i in range(specs.size()):
		var s: Array = specs[i]
		var spec := {"w": rng.randf_range(4.8, 5.4), "d": 4.3, "h": 2.6, "floors": 2, "wall": s[2], "wall2": "plaster", "roof": "hip",
			"roof_tex": "roof_tiles", "pitch": 0.55, "jetty": 0.3, "door_x": 1.0, "awning": s[3], "seed": 8500 + i, "name": "HillShop%d" % i, "smoke": false}
		town_spots["shops"].append(KitStreet.shopfront(kit, spec, s[0], Vector2(0, -1), s[1], rng))
	var house := kit.house({"w": 4.4, "d": 4.3, "h": 2.5, "floors": 2, "wall": "stone_brick", "wall2": "plaster", "roof": "gable",
		"roof_tex": "thatch", "pitch": 0.7, "jetty": 0.3, "door_x": 0.6, "seed": 8510, "name": "UpperHouse%d" % town_spots["houses"].size(),
		"smoke": false}, Vector2(UP_X - 15.6, zc), Vector2(0, -1))
	town_spots["houses"].append(house)
	# the terrace: the gate, the way up, lanterns either side, the shrine at its back
	var quads: Array = []
	KitPaving.plan_path(kit, quads, PackedVector2Array([Vector2(UP_X, UP_Z1 + 0.2), Vector2(UP_X, 19.6)]), 1.9)
	KitPaving.plan_disk(kit, quads, Vector2(UP_X, 15.5), 4.6, rng)
	KitPaving.build(kit, quads, "ShrineWay", "flagstones", Color(0.95, 0.93, 0.88))
	var gate := BrinehollowModels.gate()
	kit.put(gate, Vector3(UP_X, top, UP_Z1 + 2.3), 0.0)
	town_spots["gate"] = gate
	for s: float in [-1.0, 1.0]:
		kit.reserve(Vector2(UP_X + s * 2.2, UP_Z1 + 2.3), 0.8)
	var lanterns: Array = []
	for z: float in [10.5, 13.4, 17.8]:
		for s: float in [-1.0, 1.0]:
			var lp := Vector2(UP_X + s * 2.9, z)
			var ln := BrinehollowModels.stone_lantern(rng.randi(), 1.0 if z < 17.0 else 1.15)
			kit.place(ln, lp, 0.0, 0.0)
			kit.reserve(lp, 0.6)
			lanterns.append(ln)
			if z > 17.0:
				KitLights.light(kit, ln, (ln.get_node("Flame") as Node3D).position, 1.3, 9.0)
	town_spots["lanterns"] = lanterns
	var shrine := BrinehollowModels.shrine(rng.randi())
	var sp := Vector2(UP_X, 25.4)
	kit.place(shrine, sp, PI, 0.0)
	kit.reserve(sp, 6.6)
	town_spots["shrine"] = shrine
	# the pagoda on the terrace's west side: the mark the harbour sees
	var pagoda := BrinehollowModels.pagoda(rng.randi(), 4)
	var pg := Vector2(UP_X - 10.6, 23.0)
	kit.place(pagoda, pg, PI, 0.0, 0.8)
	kit.reserve(pg, 4.6)
	town_spots["pagoda"] = pagoda
	var parts: Array = [tea, gate, shrine, house] + lanterns + town_spots["shops"].slice(-2)
	for s: float in [-1.0, 1.0]:
		var bp := Vector2(UP_X + s * 6.2, 14.6)
		parts.append(kit.place(Props.bench(), bp, face_yaw(Vector2(-s, 0)) + PI * 0.5, 0.8))
		parts.append(kit.place(Buildings.planter(0.6), Vector2(UP_X + s * 6.4, 18.6), 0.0, 0.7))
	# the old tree behind the shrine, a rope round it
	var tree_p := Vector2(UP_X + 12.5, 27.0)
	var tree := StaticBody3D.new()
	tree.name = "OldTree"
	var tmi := MeshInstance3D.new()
	tmi.mesh = Props.jungle_tree_mesh(24)
	tmi.scale = Vector3.ONE * 1.9
	tree.add_child(tmi)
	KitLandmarks.cyl_col(tree, 0.9, 6.0, Vector3.ZERO)
	var rmb := MeshBuilder.new()
	var ring := PackedVector3Array()
	for k in range(13):
		var a := TAU * k / 12.0
		ring.append(Vector3(cos(a) * 0.95, 1.6 + 0.06 * sin(a * 3.0), sin(a) * 0.95))
	rmb.add_tube(PSXMat.lit("rope", Color(0.95, 0.88, 0.7)), ring, 0.09, 0.09, 5, 1.0)
	for k in range(4):
		var a := TAU * k / 4.0 + 0.4
		rmb.add_box(PSXMat.flat(Color(0.97, 0.97, 0.94)), Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 1.0, 1.35, sin(a) * 1.0)), Vector3(0.14, 0.35, 0.01), 1.0)
	tree.add_child(rmb.to_instance("Rope"))
	kit.place(tree, tree_p, rng.randf() * TAU, 0.0, -0.15)
	kit.reserve(tree_p, 3.0)
	parts.append(tree)
	_town_parts.append_array(parts)
	# a parapet along the terrace's front edge but where the stair comes up
	var pb := MeshBuilder.new()
	var pbody := StaticBody3D.new()
	pbody.name = "TerraceParapet"
	var w := _up_w(UP_Z1)
	for s: float in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		var x := UP_X + s * 1.9
		while absf(x - UP_X) < w - 0.5:
			pts.append(Vector3(x, top, UP_Z1 + 0.35))
			x += s * 1.6
		KitStreet.wall(kit, pb, pbody, pts, 0.4, 0.55)
	_town_parts.append(KitStreet.finish(kit, pb, pbody))
	# the switchback down the back: trodden, a low wall on its drop, a lamp post at each turn
	var lane: PackedVector2Array = paths[OLD_PATHS + 4 + UP_BANDS.size()]
	town_spots["lanes"].append(lane)
	var lq: Array = []
	KitPaving.plan_path(kit, lq, lane, 1.4)
	KitPaving.build(kit, lq, "Switchback", "dirt", Color(0.85, 0.75, 0.62))
	for q in [Vector2(-6, 39), Vector2(16, 46)]:
		var lp: Vector2 = q + (Vector2(-2.2, 0.6) if q.x < 0.0 else Vector2(2.2, 0.6))
		if not _excluded(lp, 0.4):
			KitLights.post(kit, lp, 0.0, 0.3, 0.0)
	KitStreet.merge_meshes(kit, _town_parts, "TownMeshes")


## The windmill hamlet in the southern lands (KitFarm): a yard round a well at FARM, the windmill on its
## rise, a barn, two farmhouses and a shed, haystacks and carts; the fields round it with their fences
## and scarecrows, the orchard by the way to the highland.
func _build_farmland() -> void:
	var rng := kit.rng(0, SEEDS["farm"])
	var parts: Array = []
	var yard: Array = []
	kit.place(Props.well(), FARM, 0.0, 1.6)
	var mill := BrinehollowModels.windmill(rng.randi())
	var mp := FARM + Vector2(-15, 14)
	kit.place(mill, mp, face_yaw(FARM - mp), 3.2)
	town_spots["windmill"] = mill
	var barn := kit.house({"w": 9.0, "d": 6.5, "h": 3.4, "roof": "gable", "wall": "planks_weathered", "roof_tex": "thatch", "pitch": 0.6,
		"door_x": 0.0, "flowers": false, "seed": 8600, "name": "Barn"}, FARM + Vector2(14, 8), Vector2(-1, -0.3))
	var homes := [kit.house({"w": 6.0, "d": 5.0, "floors": 2, "wall": "plaster", "wall2": "planks", "roof": "gable", "roof_tex": "thatch",
			"pitch": 0.7, "jetty": 0.3, "door_x": -1.0, "chimney": true, "smoke": false, "seed": 8601, "name": "Farmhouse0", "lamp_light": true},
			FARM + Vector2(0, 15), Vector2(0, -1)),
		kit.house({"w": 5.5, "d": 4.5, "wall": "stone_brick", "roof": "hip", "roof_tex": "thatch", "pitch": 0.55, "porch": 1.4, "door_x": 0.8,
			"seed": 8602, "name": "Farmhouse1", "smoke": false}, FARM + Vector2(-14, -3), Vector2(1, 0.1)),
		kit.house({"w": 4.0, "d": 3.5, "h": 2.3, "wall": "planks_weathered", "roof": "shed", "roof_tex": "thatch", "lean_to": "left",
			"seed": 8603, "name": "Shed", "smoke": false}, FARM + Vector2(16, -5), Vector2(-1, 0.2))]
	parts.append_array([barn] + homes)
	town_spots["farm"] = [barn] + homes
	KitLights.post(kit, FARM + Vector2(3.2, 3.2), 0.0, 0.3)
	# the yard's clutter: haystacks by the barn, carts, a trough, cargo by the doors
	var hmb := MeshBuilder.new()
	for q in [FARM + Vector2(19, 15), FARM + Vector2(21.5, 11.5), FARM + Vector2(-8, 22)]:
		BrinehollowModels.haystack(hmb, Vector3(q.x, hv(q) - 0.1, q.y), rng.randf_range(0.85, 1.15), rng)
		kit.reserve(q, 2.0)
	var hay := StaticBody3D.new()
	hay.name = "Haystacks"
	for q in [FARM + Vector2(19, 15), FARM + Vector2(21.5, 11.5), FARM + Vector2(-8, 22)]:
		KitLandmarks.cyl_col(hay, 1.2, 2.0, Vector3(q.x, hv(q), q.y))
	hay.add_child(hmb.to_instance("Mesh"))
	kit.add(hay)
	parts.append(hay)
	var items: Array = []
	var occ: Array = []
	for e in [[FARM + Vector2(7, 5), "cart", 0.6], [FARM + Vector2(-6, 8), "cart", 2.4], [FARM + Vector2(9, 12), "cargo", 0.0],
			[FARM + Vector2(-9, 4), "cargo", 1.0], [FARM + Vector2(5, -6), "bench", PI], [FARM + Vector2(-4, -7), "planter", 0.0]]:
		var q: Vector2 = e[0]
		if _excluded(q, 0.8):
			continue
		match str(e[1]):
			"cargo":
				KitVillage.plan_cargo(kit, items, q, float(e[2]), rng, ["sack", "basket", "barrel"][rng.randi() % 3])
			"planter":
				KitVillage.plan_put(kit, items, occ, "planter", q, 0.0, 0.7, {"r": 0.55})
			_:
				KitVillage.plan_put(kit, items, occ, str(e[1]), q, float(e[2]), 1.2)
		kit.reserve(q, 1.2)
	parts.append_array(KitVillage.build_items(kit, items).map(func(x: Array): return x[1]).filter(func(n): return n != null))
	KitVillage.build_cargo(kit, items)
	var yq: Array = []
	KitPaving.plan_disk(kit, yq, FARM, 10.0, rng)
	KitPaving.build(kit, yq, "FarmYard", "dirt", Color(0.85, 0.75, 0.62))
	# the fields, the orchard
	var fields: Array = []
	for i in range(FIELDS.size()):
		fields.append(KitFarm.field(kit, FIELDS[i], rng, i))
	parts.append_array(fields)
	town_spots["fields"] = FIELDS
	town_spots["orchard"] = KitFarm.orchard(kit, ORCHARD, rng)
	KitStreet.merge_meshes(kit, parts, "FarmMeshes")


## The wild places on the far side, each with its chest (fixed names, bare save keys): the falls off
## the highland into a swimmable pool (KitLandmarks' waterfall: its InlandPool), the wreck heeled over
## on the east coast among rocks, the second cove's beach with a fisher's hut, a jetty and a boat.
func _build_wilds() -> void:
	var rng := kit.rng(0, SEEDS["wilds"])
	# the falls
	var u := (HIGHLAND - POOL).normalized()
	var crag := POOL + u * KitLandmarks.CRAG_OFF
	var fpl := {"kind": "waterfall", "role": "landmark", "at": POOL, "y": _pool_y, "face": -u, "yaw": face_yaw(-u), "r": 16.0,
		"keep": [], "water": _pool_y - 0.35, "lip": maxf(11.5, hv(crag) - _pool_y + 8.5), "seed": SEEDS["wilds"] + 1}
	KitLandmarks._waterfall(kit, fpl, KitLandmarks.place_node(kit, fpl))
	KitLandmarks._waterfall_dressing(kit, fpl, [["gold", 24], ["treasure", 2], [ItemDB.tiered("cutlass", 2), 1]])
	kit.reserve(POOL, KitLandmarks.POOL_R + 2.0)
	kit.reserve(crag, 7.5)
	# (the falls seen from the way in: no trees in front)
	for k in range(3):
		kit.reserve(POOL - u * (9.0 + k * 5.0), 4.5 + k * 1.0)
	town_spots["falls"] = KitLandmarks.node_of(kit, fpl)
	# the wreck, bow up the beach, stern in the surf, rocks round her
	var out: Vector2 = wreck_site[1]
	var wat: Vector2 = wreck_site[0]
	var wpl := {"kind": "wreck", "role": "landmark", "at": wat, "y": hv(wat), "face": out.rotated(0.35), "yaw": face_yaw(out.rotated(0.35)),
		"r": 14.0, "keep": [], "heel": -0.38, "pitch": 0.07, "seed": SEEDS["wilds"] + 2}
	var wnode := KitLandmarks.place_node(kit, wpl)
	KitLandmarks._wreck(kit, wpl, wnode)
	KitLandmarks._wreck_dressing(null, kit, wpl, [["gold", 30], ["treasure", 3], ["rum", 2],
		[Gear.make("coat", "longcoat", {"coat": "longcoat", "coat_color": CharacterLook.CLOTH[8], "trim_color": CharacterLook.TRIM[2]}, "Drowned Mate's Coat", 2), 1]])
	kit.reserve(wat, 12.5)
	var mats := KitLandmarks.rock_mats(kit)
	var rmb := MeshBuilder.new()
	var rocks := StaticBody3D.new()
	rocks.name = "WreckRocks"
	var at: Array = []
	for k in range(9):
		var q := wat + out * rng.randf_range(4.0, 14.0) + out.orthogonal() * rng.randf_range(-11.0, 11.0)
		if q.distance_to(wat + out * 3.0) < 6.0:
			continue
		var g := hv(q)
		at.append(Vector3(q.x, g, q.y))
		KitLandmarks.cyl_col(rocks, 1.3, 2.4, Vector3(q.x, g - 0.4, q.y))
	KitLandmarks.boulders(rmb, mats, at, rng, 1.4, 2.8)
	rocks.add_child(rmb.to_instance("Mesh"))
	kit.add(rocks)
	town_spots["wreck"] = wnode
	# the second cove: a fisher's hut at the back of the beach, a jetty out, a boat drawn up, nets drying
	var beach := COVE2 + Vector2(-4, -30)
	var hut := kit.house({"w": 3.8, "d": 3.2, "h": 2.3, "wall": "planks_weathered", "roof": "shed", "roof_tex": "thatch", "door_x": 0.6,
		"seed": 8700, "name": "FisherHut", "smoke": false, "flowers": false}, beach + Vector2(-6, -4), (COVE2 - beach).normalized())
	var jf := COVE2 + Vector2(3, -24)
	var jt := COVE2 + Vector2(1, -12)
	var jetty := KitHouses.walkway(kit, jf, jt, 1.1, 1.8)
	jetty.name = "CoveJetty"
	kit.reserve(jf.lerp(jt, 0.5), 6.0)
	kit.place(Props.rowboat(), beach + Vector2(5, 3), face_yaw(COVE2 - beach) + 0.6, 1.5)
	kit.place(Props.fish_rack(), beach + Vector2(-1, -3), face_yaw(Vector2(1, 0)), 1.0)
	var items: Array = [["gold", 16], ["treasure", 1], ["rum", 1], [ItemDB.tiered("pistol", 1), 1]]
	KitCamps.strongbox(kit, kit.local_point(hut, Vector3(-1.6, 0, 2.2)), face_yaw((COVE2 - beach).normalized()), "cove2_chest", items, 0.9)
	town_spots["cove2"] = {"hut": hut, "jetty": [jf, jt], "beach": beach}
	town_spots["piers"] = [[jf, jt]]


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


## Captain Grell's den on its clifftop (comes back 3 minutes after it's beaten), and the path up to it.
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
		"seeds": [61, 67, 71, 79, 83, 89, 97], "captain": lk, "title": "Captain Grell", "hold_r": GRELL_HOLD,
		"ladder_lock": "den_ladder"}, "PirateDen")
	_old_climb_reserves()
	WorkerThreadPool.wait_for_task_completion(_path_task)
	build_ms["den path rock"] = int(_path_mesh["ms"])
	den_path.build(kit, _path_mesh, kit.rng(0, SEEDS["climb"]), den_plan["start"], den_plan["face"])
	_path_mesh = {}


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
	# (found on the ground as it was before the land grew, so they're where they always were)
	var built := heights
	heights = _land_heights
	var found: Array = wanted.map(func(w: Array) -> Vector2: return _find_burrow_spot(w[0]))
	heights = built
	for i in range(wanted.size()):
		var w: Array = wanted[i]
		var p: Vector2 = found[i]
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
	for k in range(OLD_PATHS):
		var pts: PackedVector2Array = _frozen[0][k]
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
	# (the old island's plants grow from its ground as it was before the den path was cut in and
	# the land grew, and decide on its reserves and paths only, so every draw is what it always
	# was; where the path, the grown land or a newer piece changed things they're left out, and
	# the grown land's own scatter fills in)
	var built := heights
	heights = _land_heights
	_old_only = true

	# --- trees and rocks on a 5 m jittered grid ---
	var step := 5.0
	var x := -OLD_HALF + 3.0
	while x < OLD_HALF - 3.0:
		var z := -OLD_HALF + 3.0
		while z < OLD_HALF - 3.0:
			var p := Vector2(x + rng.randf_range(-2.0, 2.0), z + rng.randf_range(-2.0, 2.0))
			z += step
			_veg_skip = den_path.covers(p) or _grown_at(p) or _ex_hit(_ex_new, p, 1.0, INF) or _path_dist(p, paths.size(), 0, true) < 3.0
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
	x = -OLD_HALF + 3.0
	while x < OLD_HALF - 3.0:
		var z := -OLD_HALF + 3.0
		while z < OLD_HALF - 3.0:
			var p := Vector2(x + rng.randf_range(-1.1, 1.1), z + rng.randf_range(-1.1, 1.1))
			z += step
			_veg_skip = den_path.covers(p) or _grown_at(p) or _ex_hit(_ex_new, p, -0.5, INF) or _path_dist(p, paths.size(), 0, true) < 0.6
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
	_veg_skip = false
	heights = built
	_old_only = false
	_scatter_grown(buckets, {"palms": palms, "jungle": jungle, "bushes": bushes, "ferns": ferns, "grass": grass, "rocks": rocks})

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
		elif key.size() == 4:
			# (the grown land's trees and rocks, in bigger squares: fewer draws from the town)
			mmi.visibility_range_end = 320.0 if rocks.has(mesh) else 700.0
		vegetation.add_child(mmi)


func _jungle(p: Vector2) -> float:
	return maxf(1.0 - _smooth(50.0, 80.0, p.distance_to(JUNGLE_HIGH)), 1.0 - _smooth(72.0, 112.0, p.distance_to(FOREST)))


## The southern lands' jungle: the old jungle's edge, the highland's wilds, groves in the open.
func _jungle_south(p: Vector2) -> float:
	var grove := _smooth(0.2, 0.45, _shape_noise.get_noise_2d(p.x * 2.3 + 900.0, p.y * 2.3)) * 0.55
	return maxf(maxf(_jungle(p), 1.0 - _smooth(45.0, 95.0, p.distance_to(HIGHLAND))), grove) * (1.0 - _open(p))


## 0..1: the farmland round the windmill hamlet.
func _farm(p: Vector2) -> float:
	return 1.0 - _smooth(60.0, 95.0, p.distance_to(FARM))


## 0..1: open ground (the farmland, the upper town): no woods, few trees.
func _open(p: Vector2) -> float:
	return maxf(_farm(p), _up_mask(p))


## The grown land's plants (where the old island's scatter left off: outside its grid, or where the
## ground changed): the same kinds by the same rules, each lattice point its own seed so a piece
## built later changes only the plants round it.
func _scatter_grown(buckets: Dictionary, m: Dictionary) -> void:
	var o := grid_origin()
	var rng := RandomNumberGenerator.new()
	var mine := func(p: Vector2) -> bool:
		return p.x < -OLD_HALF + 1.0 or p.x > OLD_HALF - 5.0 or p.y < -OLD_HALF + 1.0 or p.y > OLD_HALF - 5.0 or _grown_at(p)
	var nx := int((EXTENT - 6.0) / 5.0)
	_veg_cell = 140.0
	for ix in range(nx):
		for iz in range(nx):
			rng.seed = hash([SEEDS["south"], ix, iz])
			var p := o + Vector2(3.0 + ix * 5.0 + rng.randf_range(-2.0, 2.0), 3.0 + iz * 5.0 + rng.randf_range(-2.0, 2.0))
			if not mine.call(p):
				continue
			var h := hv(p)
			if h < -1.6 or _excluded(p, 1.0):
				continue
			var slope := _slope_at(p)
			var roll := rng.randf()
			if h < 0.7:
				if h > -1.4 and roll < 0.05:
					_add_rock(buckets, m["rocks"], p, rng.randf_range(0.6, 1.6), rng)
				continue
			if slope > 0.5:
				if roll < 0.35:
					_add_rock(buckets, m["rocks"], p, rng.randf_range(0.8, 2.2), rng)
				continue
			if _path_dist(p) < 3.0:
				continue
			var beach := 1.0 - _smooth(2.0, 3.8, h)
			var jung := _jungle_south(p)
			var farm := _open(p)
			var p_palm := (0.32 * beach + 0.05 * (1.0 - beach) * (1.0 - jung) + 0.06 * jung) * (1.0 - 0.85 * farm)
			var p_jungle := (0.62 * jung + 0.05 * (1.0 - farm)) * (1.0 - beach)
			var p_rock := 0.02 + 0.03 * farm
			if roll < p_palm:
				_add_tree(buckets, m["palms"], p, h, rng, 0.35, 3.0)
			elif roll < p_palm + p_jungle:
				_add_tree(buckets, m["jungle"], p, h, rng, 0.45, 3.5, rng.randf_range(0.85, 1.25))
			elif roll < p_palm + p_jungle + p_rock:
				_add_rock(buckets, m["rocks"], p, rng.randf_range(0.5, 1.8), rng)
	_veg_cell = VEG_CELL
	nx = int((EXTENT - 6.0) / 2.5)
	for ix in range(nx):
		for iz in range(nx):
			rng.seed = hash([SEEDS["south"] + 1, ix, iz])
			var p := o + Vector2(3.0 + ix * 2.5 + rng.randf_range(-1.1, 1.1), 3.0 + iz * 2.5 + rng.randf_range(-1.1, 1.1))
			if not mine.call(p):
				continue
			var h := hv(p)
			if h < 1.4 or _excluded(p, -0.5) or _slope_at(p) > 0.45:
				continue
			var pd := _path_dist(p)
			if pd < 0.6:
				continue
			var beach := 1.0 - _smooth(2.2, 3.6, h)
			var jung := _jungle_south(p)
			var farm := _open(p)
			var roll := rng.randf()
			var p_fern := 0.32 * jung * (1.0 - beach)
			var p_bush := (0.08 + 0.14 * jung) * (1.0 - beach * 0.7) * (1.0 - 0.6 * farm)
			var p_grass := (0.3 * (1.0 - jung * 0.5) + 0.05 + 0.15 * farm) * (1.0 - beach * 0.8)
			if pd < 2.0:
				p_fern = 0.0
				p_bush = 0.0
				p_grass *= 0.5
			var basis := Basis(Vector3.UP, rng.randf() * TAU)
			if roll < p_fern:
				_bucket(buckets, m["ferns"][rng.randi() % 2], Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(p.x, h - 0.05, p.y)))
			elif roll < p_fern + p_bush:
				_bucket(buckets, m["bushes"][rng.randi() % 2], Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), Vector3(p.x, h - 0.1, p.y)))
			elif roll < p_fern + p_bush + p_grass:
				_bucket(buckets, m["grass"], Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), Vector3(p.x, h - 0.05, p.y)))


func _bucket(buckets: Dictionary, mesh: Mesh, xf: Transform3D) -> void:
	if _veg_skip:
		return
	var key := [mesh, floori(xf.origin.x / VEG_CELL), floori(xf.origin.z / VEG_CELL)] if _veg_cell == VEG_CELL \
		else [mesh, floori(xf.origin.x / _veg_cell), floori(xf.origin.z / _veg_cell), _veg_cell]
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
	reserve(p, 1.2)
	if _veg_skip:
		return crown
	GrapplePoints.add(self, crown)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = col_r * s
	shape.height = col_h
	cs.shape = shape
	cs.position = Vector3(p.x, h + col_h * 0.5, p.y)
	_tree_colliders.add_child(cs)
	return crown


func _add_rock(buckets: Dictionary, meshes: Array, p: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	var h := _ground_min(p, s * 0.8)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
	_bucket(buckets, meshes[rng.randi() % meshes.size()], Transform3D(basis, Vector3(p.x, h - 0.1 * s, p.y)))
	if s > 0.7 and not _veg_skip:
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
