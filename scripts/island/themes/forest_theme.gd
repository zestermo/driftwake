extends ThemeDef
## The forest islands (docs/forest_island_plan.md): an autumn woodland of rolling hills, maples, oaks,
## beeches and birches in reds, oranges and golds over leaf litter, firs dark among them, rivers down
## their valleys and over falls into gorges, misty mornings; a lumber town on a river; spirits, treants,
## will-o'-wisps and cursed hunters in the deep wood. Its plants are ForestPlants, its props ForestProps,
## its land forest_land.gd, its places ForestPlaces, its people's text forest_life.gd.

## Land (the jungle's keys, jungle_theme.gd). The mesh slots: "giant" maples, "fig" oaks, "kapok" beeches
## and "emergent" firs over the forest; "tree" birches, young maples and firs, a dead snag; "beach_tree"
## shore pines and alders; "shrub" saplings, "bush" autumn shrubs, "fern" bracken, "grass" dry grass,
## "broadleaf" leaf piles, fallen logs and toadstools, "bamboo" stumps, "mangrove" cattails at the
## waterline, "rock" mossy granite. The forest's own: "roll_h" its rolling hills' height over the base
## land, "rivers" [lo, hi] how many, "river_w" their width, "falls" the chance a river drops over falls
## into a gorge. "forests" the island's woodland, one per island from its seed.
const LAND := {
	"peak": [28.0, 40.0], "hills": [4, 7], "hill_h": [8.0, 16.0], "roll": 5.0, "base": 4.6,
	"ramp": [32.0, 54.0], "cliffs": [1, 3], "cliff_h": [8.0, 14.0],
	"tree": 0.42, "edge": 0.14, "beach_tree": 0.16, "fern": 0.4, "bush": 0.24, "grass": 0.32, "rock": 0.035,
	"cover": 0.74,
	"canopy": 0.78, "giants": {"giant": 5.0, "fig": 2.0, "kapok": 1.2, "emergent": 1.0},
	"bamboo": 0.04, "palm_inland": 0.0, "mangrove": 0.06,
	"broadleaf": 0.16, "shrub": 0.16, "floor": 0.42, "overgrown": 0.35,
	"roll_h": [6.0, 10.0], "rivers": [1, 2], "river_w": [5.0, 8.0], "falls": 0.7,
	"forests": [
		["autumn maple", {}],
		["birch and pine", {"giants": {"giant": 0.8, "fig": 0.4, "kapok": 0.5, "emergent": 5.0}, "canopy": 0.62, "tree": 0.55, "fern": 0.3, "grass": 0.42}],
		["ancient oak grove", {"giants": {"giant": 1.0, "fig": 6.0, "kapok": 1.6, "emergent": 0.2}, "canopy": 0.88, "floor": 0.5, "bamboo": 0.07, "broadleaf": 0.22}],
		["misty firs", {"giants": {"giant": 1.2, "fig": 0.5, "kapok": 0.6, "emergent": 6.0}, "canopy": 0.9, "fern": 0.5, "floor": 0.55, "tree": 0.36,
			"roll_h": [8.0, 13.0], "rivers": [2, 3]}],
	],
}

const LAND_FEATURES := preload("res://scripts/island/themes/forest_land.gd")

## The settlement style over KitStyle.BRINEHOLLOW: log and timber-framed houses under steep shingle roofs,
## river cobbles, lanterns on timber posts, autumn colours.
const STYLE := {
	"lamp": Color(1.0, 0.7, 0.38),
	"lamp_range": 11.0,
	"paving": "river_cobbles",
	"quay_wall": Color(0.7, 0.7, 0.67),
	"quay_cope": Color(0.6, 0.6, 0.57),
	"iron": Color(0.22, 0.2, 0.2),
	"row_walls": ["logs", "plaster_wash", "planks_dark", "logs", "plaster_wash"],
	"row_upper": ["plaster_wash", "planks_dark", "logs"],
	"row_roofs": ["gable", "gable_front", "gable", "gable_front"],
	"row_roof_tex": ["shingles", 0.9, "roof_tiles"],
	"row_awnings": ["", "red", "", "green", ""],
	"pennants": [Color(0.72, 0.24, 0.12), Color(0.86, 0.62, 0.16), Color(0.2, 0.38, 0.22), Color(0.9, 0.86, 0.74), Color(0.5, 0.14, 0.12)],
	"washing": [Color(0.92, 0.88, 0.8), Color(0.66, 0.2, 0.14), Color(0.3, 0.42, 0.28), Color(0.82, 0.62, 0.3), Color(0.42, 0.34, 0.5)],
	"rugs": [["cloth_red", Color(0.85, 0.7, 0.55)], ["canvas", Color(0.75, 0.6, 0.42)]],
	"goods": [Color(0.78, 0.16, 0.1), Color(0.92, 0.5, 0.12), Color(0.55, 0.36, 0.2), Color(0.9, 0.72, 0.2), Color(0.42, 0.52, 0.2)],
	"tent": Color(0.84, 0.78, 0.64),
	"camp_tent": Color(0.5, 0.46, 0.36),
	"rough": {"flowers": false, "trim": Color(0.3, 0.24, 0.18), "wall": "logs", "roof_tex": "shingles", "beam": "planks_dark", "pitch": 0.9, "eaves": 0.6},
	"crew_flag": Color(0.7, 0.26, 0.16),
	"mat": {"wall": "logs", "beam": "planks_dark", "floor": "planks", "deck": "planks_weathered", "post": "planks_dark",
		"rail": "planks_dark", "roof": "shingles", "thatch": "shingles", "rope": "rope", "stone": "stone_brick", "cloth": "canvas",
		"weave": "straw"},
	"house": {"w": [5.0, 6.8], "d": [4.4, 5.6], "h": [2.6, 3.0], "walls": ["logs", "logs", "plaster_wash", "planks_dark"],
		"roofs": ["gable", "gable_front", "gable"], "roof_tex": ["shingles"], "pitch": [0.95, 1.15], "eaves": 0.55,
		"beam": "planks_dark", "floor": "planks", "poles": false, "lashings": false, "stilts": false,
		"porch": [0.45, 1.2, 1.8], "flowers": 0.3, "chimney": 0.85,
		"trims": [Color(0.55, 0.16, 0.12), Color(0.22, 0.36, 0.24), Color(0.72, 0.52, 0.2), Color(0.28, 0.22, 0.18), Color(0.86, 0.82, 0.72)]},
	"inn": {"w": 9.0, "d": 7.0, "h": 3.0, "roof": "gable", "wall": "logs", "porch": 2.2, "flowers": false},
	"stall": {"canopies": ["cloth_red", "canvas", "cloth_red"], "post": "planks_dark"},
	"pier": {"deck": "planks_weathered", "post": "planks_dark", "rail": "planks_dark", "lashings": false, "rope_rail": true},
	"props": {"crate": "crate", "barrel": "barrel", "lamp": "forest_lamp", "marker": "forest_waymark"},
	# the lumber town (ForestTown): log cabins, timber-framed houses, the cooper's shed, the timber store, a carved shrine
	"village_models": {"hut": "forest_cabin", "tall": "forest_timber_house", "workshop": "forest_workshop", "storehouse": "forest_store",
		"shrine": "forest_shrine"},
	"item_models": {"torch": "forest_lamp", "fence": "forest_fence", "woodpile": "forest_woodpile"},
	"yard_fences": 0.55,
	"village_layouts": {"town": 4, "hamlets": 2, "post": 1, "stilts": 0, "ruins": 1, "medina": 0},
	"folk": {
		"pick": {"skin": [Color(0.95, 0.80, 0.68), Color(0.90, 0.72, 0.58), Color(0.84, 0.64, 0.48), Color(0.74, 0.54, 0.40), Color(0.60, 0.42, 0.30)],
			"hair_color": [Color(0.45, 0.20, 0.10), Color(0.62, 0.30, 0.12), Color(0.30, 0.18, 0.10), Color(0.18, 0.11, 0.07), Color(0.80, 0.62, 0.34), Color(0.55, 0.52, 0.48)],
			"hat": ["knit", "cap", "hood", "slouch", "none", "none"], "hat_fem": ["hood", "knit", "none", "none", "coif"],
			"top": ["shirt", "tunic", "striped", "shirt"], "top_fem": ["blouse", "tunic", "shirt"], "sleeves": ["long", "long", "short"],
			"vest": ["vest", "jerkin", "none", "none"], "coat": ["none", "none", "jacket", "duster"],
			"legs": ["trousers", "breeches"], "legs_fem": ["skirt", "skirt", "trousers"], "feet": ["boots", "tall_boots", "boots"],
			"belt": ["belt", "wide_belt", "belt"], "scarf": [false, false, true],
			"top_color": [Color(0.62, 0.16, 0.12), Color(0.86, 0.80, 0.66), Color(0.28, 0.40, 0.24), Color(0.76, 0.52, 0.18), Color(0.44, 0.30, 0.20)],
			"vest_color": [Color(0.36, 0.24, 0.14), Color(0.22, 0.30, 0.20), Color(0.50, 0.34, 0.18)],
			"coat_color": [Color(0.40, 0.28, 0.18), Color(0.30, 0.34, 0.24), Color(0.56, 0.20, 0.12), Color(0.62, 0.50, 0.34)],
			"legs_color": [Color(0.32, 0.24, 0.16), Color(0.24, 0.26, 0.20), Color(0.40, 0.32, 0.22), Color(0.26, 0.24, 0.26)],
			"hat_color": [Color(0.62, 0.16, 0.12), Color(0.76, 0.52, 0.18), Color(0.28, 0.40, 0.24), Color(0.40, 0.28, 0.18)],
			"scarf_color": [Color(0.62, 0.16, 0.12), Color(0.80, 0.56, 0.16), Color(0.22, 0.36, 0.24)]},
		"set": {"eyepatch": false, "gloves": false},
	},
	"music": "forest",
	"music_town": "village",
	"ambience": "forest",
	"ground": {"grass": "forest_litter", "sand": "forest_beach", "wet_sand": "wet_sand", "dirt": "forest_dirt", "rock": "forest_rock", "seafloor": "seafloor", "cliff": "forest_rock"},
	"cave_look": {"rock": ["forest_rock", Color(1.0, 1.0, 1.0)], "moss": ["forest_rock", Color(0.85, 0.95, 0.75)], "turf": ["forest_litter", Color.WHITE],
		"wall": ["forest_rock", Color(0.8, 0.8, 0.78)], "floor": ["forest_dirt", Color(0.85, 0.82, 0.78)]},
	# cloudier and wetter than the jungle, mist in the hollows
	"weather": [0.24, 0.56, 0.9],
	"haze": 0.25,
	"haze_color": Color(0.8, 0.82, 0.84, 0.5),
	# (a hook for the shared weather/ground pass, nothing reads it yet: leaves drifting down under the trees, how many
	# a second round the camera on a still day, and their colours)
	"falling_leaves": {"rate": 6.0, "colors": [Color(0.78, 0.2, 0.1), Color(0.9, 0.5, 0.14), Color(0.88, 0.7, 0.2), Color(0.55, 0.34, 0.18)]},
	"storm_color": Color(0.36, 0.37, 0.4),
	# landmarks and set pieces (KitLandmarks, KitSetPieces): rock, carved stone, water, bone, lava, crystal
	"rock_tint": Color(0.62, 0.62, 0.6),
	"moss_tint": Color(0.58, 0.6, 0.36),
	"temple_stone": Color(0.72, 0.72, 0.68),
	"fort_stone": Color(0.74, 0.73, 0.7),
	"water_tint": Color(0.3, 0.52, 0.55, 0.8),
	"falls_tint": Color(0.86, 0.92, 0.95, 0.86),
	"spring_tint": Color(0.45, 0.68, 0.62, 0.85),
	"travertine": Color(0.9, 0.86, 0.76),
	"wreck_hull": Color(0.52, 0.48, 0.42),
	"bone": Color(0.9, 0.86, 0.76),
	"basalt": Color(0.3, 0.29, 0.3),
	"lava": Color(1.0, 0.45, 0.12),
	"crystal": Color(1.0, 0.68, 0.28),
	"rust": Color(0.48, 0.3, 0.2),
	"harbour_kinds": ["wharf", "wharf", "cove", "ruins"],
	"harbour_wild_kinds": ["landing", "landing", "cove", "ruins", "wharf"],
	"harbour_pile": "planks_dark",
	"harbour_deck": "planks_weathered",
	"harbour_roof": "shingles",
	"harbour_walls": ["logs", "planks_dark", "plaster_wash"],
	"harbour_tarp": Color(0.5, 0.46, 0.38),
	"harbour_floats": [Color(0.78, 0.26, 0.14), Color(0.9, 0.86, 0.76), Color(0.82, 0.6, 0.18)],
	"harbour_signal": Color(1.0, 0.45, 0.2),
}

## Each kind: its zones, how likely an island has it, how many groups (dens), a group's size ("pack" [lo, hi] round a
## lead) and the chance each follower is a young one. Ordinary woodland animals - red deer herds round a stag, boar,
## red foxes, a wolf pack now and then, bats, shore crabs - and the folklore that walks among them: will-o'-wisps,
## wood sprites (under the leaves by day, up at night) and treantlings (stumps that walk).
const FAUNA := {
	"deer": {"zones": ["floor"], "p": 0.85, "dens": [2, 4], "pack": [3, 5], "young": 0.4},
	"boar": {"zones": ["floor"], "p": 0.55, "dens": [1, 3]},
	"fox": {"zones": ["floor"], "p": 0.5, "dens": [1, 3], "pack": [1, 2], "young": 0.3},
	"wolf": {"zones": ["floor"], "p": 0.3, "dens": [1, 2], "pack": [3, 4]},
	"wisp": {"zones": ["floor"], "p": 0.75, "dens": [2, 4], "pack": [2, 4]},
	"sprite": {"zones": ["floor"], "p": 0.6, "dens": [2, 4], "pack": [2, 3]},
	"treant": {"zones": ["floor"], "p": 0.55, "dens": [2, 4], "pack": [1, 2]},
	"bat": {"zones": ["canopy", "cave"], "p": 0.45, "dens": [1, 3]},
	"crab": {"zones": ["shore"], "p": 0.4, "dens": [2, 4]},
}
const CREATURES := {
	"deer": "res://scripts/enemies/fauna/deer.gd",
	"boar": "res://scripts/enemies/fauna/boar.gd",
	"fox": "res://scripts/enemies/fauna/red_fox.gd",
	"wolf": "res://scripts/enemies/fauna/wolf.gd",
	"wisp": "res://scripts/enemies/fauna/wisp.gd",
	"sprite": "res://scripts/enemies/fauna/wood_sprite.gd",
	"treant": "res://scripts/enemies/fauna/treant.gd",
	"bat": "res://scripts/enemies/fauna/bat.gd",
	"crab": "res://scripts/enemies/fauna/crab.gd",
	"mite": "res://scripts/enemies/fauna/swarm_mite.gd",
}

func _init() -> void:
	name = "forest"
	display = "Forest"
	blurb = "an autumn isle of deep woods and rivers"
	island_names = ["Emberwood", "Hollowmere", "Russet", "Thornfield", "Oakhaven", "Fallowmoor", "Grimbark", "Ashgrove"]
	weight = 1.0
	color = Color(0.9, 0.4, 0.16)
	glyph = _glyph
	flocks = 0
	land = LAND
	radius = [340.0, 460.0]
	style = STYLE
	arena_dress = _dress_stones
	props = {
		"forest_lamp": func(_rng: RandomNumberGenerator, size: float) -> Node3D: return ForestProps.lamp_post(2.6 * size),
		"forest_waymark": func(rng: RandomNumberGenerator, _size: float) -> Node3D: return ForestProps.waymark(rng.randi()),
		# the town's buildings by kind (style village_models), `size` the plot across
		"forest_cabin": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.log_cabin(rng.randi(), size, 1 if rng.randf() < 0.7 else 2),
		"forest_timber_house": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.timber_house(rng.randi(), size),
		"forest_workshop": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.workshop(rng.randi(), size),
		"forest_store": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.storehouse(rng.randi(), size),
		"forest_shrine": func(rng: RandomNumberGenerator, _size: float) -> Node3D: return ForestTown.shrine(rng.randi()),
		"forest_fence": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.fence(rng.randi(), 4.4 * size),
		"forest_woodpile": func(rng: RandomNumberGenerator, size: float) -> Node3D: return ForestTown.woodpile(rng.randi(), size),
	}
	life = preload("res://scripts/island/themes/forest_life.gd").TEXT
	encounters = preload("res://scripts/island/themes/forest_encounters.gd").TEXT
	# the antlered spirit of the wood and the walking oak are the forest's own; the jungle's serpent coils in the roots
	# and its shade prowls as a lynx, so a branching chain never runs the pool dry
	bosses = ["stag_king", "elder_treant", "serpent", "stalker"]
	minis = ["moss_golem", "huntsman", "boar"]
	roamers = ["wild_hunt"]
	beasts = {
		"stag_king": {"script": "res://scripts/enemies/beasts/stag_king.gd", "names": ["The Stag King", "The Antlered One", "Old Crownhorn"], "looks": 3,
			"banner": ["The Stag King's Grove", "Standing stones, antlers hung on them, offerings rotting. The wood holds its breath."], "dress": _dress_grove},
		"elder_treant": {"script": "res://scripts/enemies/beasts/elder_treant.gd", "names": ["The Elder Treant", "Old Oakheart", "The Walking Wood"], "looks": 3,
			"banner": ["The Elder's Hollow", "Roots torn up, oaks pushed over. Something here is older than the island."], "dress": _dress_hollow},
		"serpent": {"script": "res://scripts/enemies/beasts/strangler.gd", "names": ["The Root Coil", "Old Bramble", "The Hollow Serpent"], "looks": 3},
		"stalker": {"script": "res://scripts/enemies/beasts/stalker.gd", "names": ["The Grey Lynx", "Leafshadow", "The Quiet Death"], "looks": 3},
		"moss_golem": {"script": "res://scripts/enemies/beasts/moss_golem.gd", "names": ["The Moss Golem", "Old Stones", "Cairnback", "The Mossheart"], "site": "ruins"},
		# (a "camp" mini leads the outlaws' camp in its captain's place: IslandContent._camp)
		"huntsman": {"script": "res://scripts/enemies/huntsman.gd", "names": ["The Cursed Huntsman", "Black Herne", "Lord Wulfric's Huntsman", "The Antlered Man"],
			"site": "camp", "camp": true},
		"boar": {"script": "res://scripts/enemies/beasts/alpha_boar.gd", "names": ["Acornmaw", "Old Bristle", "Rootgrubber", "Ironhide"], "site": "lair"},
		"wild_hunt": {"script": "res://scripts/enemies/beasts/wild_hunt.gd", "names": ["The Wild Hunt", "The Night Rider", "The Pale Elk"]},
	}
	fauna = FAUNA
	creatures = CREATURES
	cave_fauna = {"ceiling": "bat", "floor": ["mite", "sprite", "treant"]}


## The land (forest_land.gd): rolling hills, rivers in their valleys, falls into gorges, the town by a river.
func plan_land(isl, rng: RandomNumberGenerator) -> Dictionary:
	return LAND_FEATURES.plan(isl, rng)


func shape(isl, p: Vector2, h: float) -> float:
	return LAND_FEATURES.shape(isl, p, h)


func village_at(isl, p: Vector2) -> Vector2:
	return LAND_FEATURES.village_at(isl, p)


func cover(isl, p: Vector2, c: float) -> float:
	return LAND_FEATURES.cover(isl, p, c)


func growth(isl, p: Vector2) -> Vector2:
	return LAND_FEATURES.growth(isl, p)


func paint(isl, p: Vector2, h: float, splat: Color) -> Color:
	return LAND_FEATURES.paint(isl, p, h, splat)


func steps(isl) -> Array:
	return LAND_FEATURES.steps(isl)


func place_kind(kind: String) -> String:
	return ForestPlaces.KINDS.get(kind, "")


## The sawmill on the town's river, charcoal burners' camps and a hunter's lodge out in the woods (forest_places.gd).
func plan_places(isl, avoid: Array) -> Array:
	return ForestPlaces.plan_places(isl, avoid)


func plan_place(isl, kind: String, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	return ForestPlaces.plan(isl, kind, rng, avoid)


func place_steps(isl, ctx, pl: Dictionary) -> Array:
	return ForestPlaces.steps(isl, ctx, pl)


func meshes() -> Dictionary:
	return {
		"tree": [ForestPlants.birch(821), ForestPlants.birch(822), ForestPlants.young_maple(823), ForestPlants.young_maple(824, true), ForestPlants.young_fir(825), ForestPlants.snag(826)],
		"beach_tree": [ForestPlants.shore_pine(811), ForestPlants.shore_pine(812), ForestPlants.alder(813)],
		"bush": [ForestPlants.shrub_card(831), ForestPlants.shrub_card(832), ForestPlants.leaf_bush(833), ForestPlants.leaf_bush(834, "leaves_birch")],
		"fern": [ForestPlants.bracken(841), ForestPlants.bracken(842)],
		"grass": [ForestPlants.dry_grass()],
		"rock": [ForestPlants.boulder(851), ForestPlants.boulder(852), ForestPlants.boulder(853)],
		# big trees: [body, detail, lean]
		"giant": [ForestPlants.maple(861), ForestPlants.maple(862), ForestPlants.maple(863, true)],
		"fig": [ForestPlants.oak(865), ForestPlants.oak(866), ForestPlants.oak(867, true)],
		"kapok": [ForestPlants.beech(875), ForestPlants.beech(876)],
		"emergent": [ForestPlants.fir(871), ForestPlants.fir(872)],
		"roof": [ForestPlants.crown_roof(868), ForestPlants.crown_roof(869)],
		"mangrove": [ForestPlants.cattails(885), ForestPlants.cattails(886)],
		"bamboo": [ForestPlants.stump(881), ForestPlants.stump(882), ForestPlants.toadstool_ring(883)],
		"broadleaf": [ForestPlants.leaf_pile(891), ForestPlants.leaf_pile(892), ForestPlants.fallen_log(893), ForestPlants.toadstool_ring(894)],
		"shrub": [ForestPlants.sapling(895), ForestPlants.sapling(896, "leaves_birch"), ForestPlants.sapling(897, "leaves_late")],
	}


## A maple leaf: five pointed lobes on a stem.
static func _glyph(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for e in [[-90, 1.0], [-118, 0.45], [-150, 0.95], [-178, 0.5], [160, 0.85], [115, 0.3], [65, 0.3], [20, 0.85], [-2, 0.5], [-30, 0.95], [-62, 0.45]]:
		pts.append(p + Vector2.from_angle(deg_to_rad(float(e[0]))) * s * float(e[1]) + Vector2(0, -s * 0.1))
	pts.append(pts[0])
	ci.draw_polyline(pts, col, 1.0)
	ci.draw_line(p + Vector2(0, s * 0.2), p + Vector2(s * 0.15, s), col, 1.0)


## The Stag King's grove (BeastArena, a beast's "dress"): a ring of mossy standing stones round the floor, antlers
## hung on some, offerings at their feet (apples, candles guttered out), a ring of toadstools, a white stag's skull
## on a cairn. Arena-local (the floor's middle at 0, its ground y0).
static func _dress_grove(arena, body: StaticBody3D, mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	var isl = arena.isl
	var r := float(BeastArena.FLOOR_R)
	var stone := PSXMat.lit("moss_stone", Color(0.95, 0.95, 0.92), {"affine": 0.6})
	var bone := PSXMat.flat(Color(0.88, 0.84, 0.74))
	var apple := PSXMat.flat(Color(0.75, 0.15, 0.1))
	var gy := func(q: Vector2) -> float: return float(isl.hv(c + q)) - y0
	var n := rng.randi_range(7, 9)
	var a0 := rng.randf() * TAU
	for k in range(n):
		var a := a0 + TAU * k / n + rng.randf_range(-0.12, 0.12)
		var q := Vector2.from_angle(a) * (r + rng.randf_range(0.5, 2.0))
		var h := rng.randf_range(2.2, 4.0)
		var w := rng.randf_range(0.9, 1.3)
		var base := Vector3(q.x, gy.call(q) - 0.3, q.y)
		var b := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.BACK, rng.randf_range(-0.08, 0.08))
		mb.add_box(stone, Transform3D(b, base + Vector3(0, h * 0.5, 0)), Vector3(w, h, w * 0.45), 0.6, Color.WHITE.darkened(rng.randf() * 0.15))
		KitLandmarks.box_col_xf(body, Vector3(w, h, w * 0.45), Transform3D(b, base + Vector3(0, h * 0.5, 0)))
		if k % 3 == 0:
			var at := base + Vector3(0, h * 0.82, 0) - Vector3(cos(a), 0, sin(a)) * w * 0.25
			for s in [-1.0, 1.0]:
				var side: Vector3 = Vector3(-sin(a), 0, cos(a)) * s
				mb.add_tube(bone, MeshBuilder.curve_points(at, at + side * 0.5 + Vector3.UP * 0.3, at + side * 0.7 + Vector3.UP * 0.9, 4), 0.05, 0.02, 4, 1.0)
		for j in range(3):
			var o := q * 0.9 + Vector2.from_angle(rng.randf() * TAU) * 0.5
			mb.add_blob(apple, Transform3D(Basis(), Vector3(o.x, gy.call(o) + 0.06, o.y)), Vector3(0.08, 0.075, 0.08), rng, 0.05, 2, 5)
	var cap := PSXMat.flat(Color(0.8, 0.14, 0.1))
	var stem := PSXMat.flat(Color(0.92, 0.88, 0.8))
	for k in range(26):
		var a := TAU * k / 26.0 + rng.randf_range(-0.05, 0.05)
		var q := Vector2.from_angle(a) * (r - 1.5)
		var at := Vector3(q.x, gy.call(q), q.y)
		mb.add_cylinder(stem, Transform3D(Basis(), at), 0.05, 0.04, 0.25, 4, 1.0)
		mb.add_cylinder(cap, Transform3D(Basis(), at + Vector3.UP * 0.22), 0.16, 0.04, 0.1, 6, 1.0)
	var cq := Vector2.from_angle(a0 + PI / n) * (r - 3.5)
	var cy: float = gy.call(cq)
	for k in range(4):
		var s := 0.7 - k * 0.14
		mb.add_blob(stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cq.x, cy + k * 0.38, cq.y)), Vector3(s, s * 0.5, s), rng, 0.2, 3, 6, 0.6)
	var sk := Vector3(cq.x, cy + 1.5, cq.y)
	mb.add_blob(bone, Transform3D(Basis(), sk), Vector3(0.22, 0.18, 0.32), rng, 0.08, 3, 6)
	for s in [-1.0, 1.0]:
		mb.add_tube(bone, MeshBuilder.curve_points(sk + Vector3(s * 0.1, 0.12, 0.05), sk + Vector3(s * 0.6, 0.4, 0.2), sk + Vector3(s * 0.8, 1.1, 0.0), 5), 0.05, 0.02, 4, 1.0)
	KitLandmarks.cyl_col(body, 0.8, 1.6, Vector3(cq.x, cy + 0.8, cq.y))


## The Elder Treant's hollow: oaks it pushed over lying across the edge of the floor, their root plates torn up
## standing on end with the earth still in them, boulders turned out, splintered stumps. Arena-local.
static func _dress_hollow(arena, body: StaticBody3D, mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	var isl = arena.isl
	var r := float(BeastArena.FLOOR_R)
	var bark := PSXMat.lit("bark", Color(0.9, 0.8, 0.68))
	var ends := PSXMat.flat(Color(0.75, 0.6, 0.42))
	var earth := PSXMat.lit("forest_dirt", Color(0.85, 0.8, 0.75), {"affine": 0.6})
	var rock := PSXMat.lit("forest_rock", Color.WHITE, {"affine": 0.6})
	var leaves := PSXMat.lit("leaves_oak", Color(0.8, 0.72, 0.62), {"affine": 0.5})
	var gy := func(q: Vector2) -> float: return float(isl.hv(c + q)) - y0
	for k in range(rng.randi_range(2, 3)):
		var a := rng.randf() * TAU
		var foot := Vector2.from_angle(a) * (r + 1.5)
		var dir := Vector2.from_angle(a + PI + rng.randf_range(-0.9, 0.9))
		var L := rng.randf_range(9.0, 13.0)
		var tip := foot + dir * L
		var p0 := Vector3(foot.x, gy.call(foot) + 0.6, foot.y)
		var p1 := Vector3(tip.x, gy.call(tip) + 0.35, tip.y)
		mb.add_tube(bark, PackedVector3Array([p0, p0.lerp(p1, 0.5) + Vector3.UP * 0.1, p1]), 0.65, 0.3, 7, 0.6, Color.WHITE, true, true)
		for j in range(3):
			var t := rng.randf_range(0.4, 0.95)
			var at := p0.lerp(p1, t)
			var out := Vector3(dir.y, rng.randf_range(0.2, 0.8), -dir.x) * (1.0 if j % 2 == 0 else -1.0)
			mb.add_tube(bark, PackedVector3Array([at, at + out * 1.5, at + out * 2.6 + Vector3.UP * 0.4]), 0.2, 0.06, 5, 0.8)
			mb.add_blob(leaves, Transform3D(Basis(), at + out * 2.6 + Vector3.UP * 0.5), Vector3(1.0, 0.6, 0.9), rng, 0.25, 3, 5, 0.6)
		var steps := int(L / 1.5)
		for j in range(steps):
			var q := foot.lerp(tip, (j + 0.5) / steps)
			KitLandmarks.cyl_col(body, 0.65, 1.3, Vector3(q.x, gy.call(q) + 0.3, q.y))
		# the root plate, on end
		var plate := Vector3(foot.x, gy.call(foot), foot.y) - Vector3(dir.x, 0, dir.y) * 0.8
		var pb := Basis(Vector3.UP, -atan2(dir.y, dir.x)) * Basis(Vector3.BACK, PI * 0.5)
		mb.add_cylinder(earth, Transform3D(pb, plate + Vector3.UP * 1.6), 1.9, 1.7, 0.7, 9, 0.5, Color.WHITE, true, true)
		for j in range(8):
			var ra := TAU * j / 8.0
			var rq := plate + Vector3.UP * 1.6 + pb * Vector3(cos(ra) * 1.7, 0.0, sin(ra) * 1.7)
			mb.add_tube(bark, PackedVector3Array([rq, rq + pb * Vector3(cos(ra) * 0.8, rng.randf_range(-0.6, 0.2), sin(ra) * 0.8)]), 0.12, 0.03, 4, 1.0)
		KitLandmarks.cyl_col(body, 1.6, 3.2, plate + Vector3.UP * 1.6)
	for k in range(7):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(r * 0.6, r + 2.5)
		var s := rng.randf_range(0.5, 1.2)
		mb.add_blob(rock, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(q.x, gy.call(q) + s * 0.2, q.y)), Vector3(s, s * 0.7, s * 0.9), rng, 0.25, 3, 6, 0.5)
	for k in range(3):
		var q := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(r * 0.5, r - 1.0)
		var at := Vector3(q.x, gy.call(q) - 0.1, q.y)
		mb.add_cylinder(bark, Transform3D(Basis(), at), 0.55, 0.5, 0.9, 7, 0.8)
		for j in range(5):
			var a := TAU * j / 5.0
			mb.add_cone(bark, Transform3D(Basis(), at + Vector3(cos(a) * 0.3, 0.9, sin(a) * 0.3)), 0.2, rng.randf_range(0.3, 0.8), 4)
		mb.add_cylinder(ends, Transform3D(Basis(), at + Vector3.UP * 0.9), 0.48, 0.48, 0.02, 7, 1.0)
		KitLandmarks.cyl_col(body, 0.55, 1.0, at + Vector3.UP * 0.5)


## Every forest boss's ground (ThemeDef.arena_dress, 1.20, docs/v1_20_plan.md "Arenas": an ancient grove): a ring of
## old standing stones under the giants, moss on them, leaning, one fallen; the way in kept open. The Stag King's own
## grove has its ring already (_dress_grove), so not there. Arena-local (the floor's middle at 0, its ground y0).
static func _dress_stones(arena, body: StaticBody3D, mb: MeshBuilder, rng: RandomNumberGenerator, c: Vector2, y0: float) -> void:
	if str(arena.kind) == "stag_king":
		return
	var isl = arena.isl
	var r := float(BeastArena.FLOOR_R)
	var stone := PSXMat.lit("moss_stone", Color(0.95, 0.95, 0.92), {"affine": 0.6})
	var gy := func(q: Vector2) -> float: return float(isl.hv(c + q)) - y0
	var ent: float = (arena._ground()["entry"] as Vector2).angle()
	var n := rng.randi_range(8, 10)
	var a0 := rng.randf() * TAU
	var fallen := rng.randi() % n
	for k in range(n):
		var a := a0 + TAU * k / n + rng.randf_range(-0.1, 0.1)
		if absf(wrapf(a - ent, -PI, PI)) < 0.32:
			continue
		var q := Vector2.from_angle(a) * (r - 2.5 + rng.randf_range(0.0, 1.0))
		var h := rng.randf_range(3.2, 5.6)
		var w := rng.randf_range(1.3, 1.9)
		var base := Vector3(q.x, gy.call(q) - 0.3, q.y)
		if k == fallen:
			# fallen on its side across the floor's edge
			var b := Basis(Vector3.UP, -a + rng.randf_range(-0.5, 0.5)) * Basis(Vector3.BACK, PI * 0.5)
			mb.add_box(stone, Transform3D(b, base + Vector3(0, w * 0.3, 0)), Vector3(w, h, w * 0.5), 0.6, Color.WHITE.darkened(0.2))
			KitLandmarks.box_col_xf(body, Vector3(w, h, w * 0.5), Transform3D(b, base + Vector3(0, w * 0.3, 0)))
			continue
		var b := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12)) * Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08))
		mb.add_box(stone, Transform3D(b, base + Vector3(0, h * 0.5, 0)), Vector3(w, h, w * 0.45), 0.6, Color.WHITE.darkened(rng.randf() * 0.18))
		# a cap stone across the tallest pairs (a trilithon) now and then
		if h > 4.8 and rng.randf() < 0.4:
			mb.add_box(stone, Transform3D(b, base + Vector3(0, h + 0.25, 0)), Vector3(w * 1.6, 0.5, w * 0.5), 0.6, Color.WHITE.darkened(0.1))
		KitLandmarks.box_col_xf(body, Vector3(w, h, w * 0.45), Transform3D(b, base + Vector3(0, h * 0.5, 0)))
