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
	"row_roof_tex": ["shingles", 0.8, "thatch"],
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
		"rail": "planks_dark", "roof": "shingles", "thatch": "thatch", "rope": "rope", "stone": "stone_brick", "cloth": "canvas",
		"weave": "straw"},
	"house": {"w": [5.0, 6.8], "d": [4.4, 5.6], "h": [2.6, 3.0], "walls": ["logs", "logs", "plaster_wash", "planks_dark"],
		"roofs": ["gable", "gable_front", "gable"], "roof_tex": ["shingles", "shingles", "thatch"], "pitch": [0.95, 1.15], "eaves": 0.55,
		"beam": "planks_dark", "floor": "planks", "poles": false, "lashings": false, "stilts": false,
		"porch": [0.45, 1.2, 1.8], "flowers": 0.3, "chimney": 0.85,
		"trims": [Color(0.55, 0.16, 0.12), Color(0.22, 0.36, 0.24), Color(0.72, 0.52, 0.2), Color(0.28, 0.22, 0.18), Color(0.86, 0.82, 0.72)]},
	"inn": {"w": 9.0, "d": 7.0, "h": 3.0, "roof": "gable", "wall": "logs", "porch": 2.2, "flowers": false},
	"stall": {"canopies": ["cloth_red", "canvas", "cloth_red"], "post": "planks_dark"},
	"pier": {"deck": "planks_weathered", "post": "planks_dark", "rail": "planks_dark", "lashings": false, "rope_rail": true},
	"props": {"crate": "crate", "barrel": "barrel", "lamp": "forest_lamp", "marker": "forest_waymark"},
	"yard_fences": 0.4,
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
	"music": "island",
	"music_town": "village",
	"ambience": "",
	"ground": {"grass": "forest_litter", "sand": "forest_beach", "wet_sand": "wet_sand", "dirt": "forest_dirt", "rock": "forest_rock", "seafloor": "seafloor", "cliff": "forest_rock"},
	"cave_look": {"rock": ["forest_rock", Color(1.0, 1.0, 1.0)], "moss": ["forest_rock", Color(0.85, 0.95, 0.75)], "turf": ["forest_litter", Color.WHITE],
		"wall": ["forest_rock", Color(0.8, 0.8, 0.78)], "floor": ["forest_dirt", Color(0.85, 0.82, 0.78)]},
	# cloudier and wetter than the jungle, mist in the hollows
	"weather": [0.24, 0.56, 0.9],
	"haze": 0.25,
	"haze_color": Color(0.8, 0.82, 0.84, 0.5),
	"storm_color": Color(0.36, 0.37, 0.4),
	# landmarks and set pieces (KitLandmarks, KitSetPieces): rock, carved stone, water, bone, lava, crystal
	"rock_tint": Color(0.62, 0.62, 0.6),
	"moss_tint": Color(0.58, 0.6, 0.36),
	"temple_stone": Color(0.72, 0.72, 0.68),
	"fort_stone": Color(0.74, 0.73, 0.7),
	"water_tint": Color(0.26, 0.4, 0.36, 0.86),
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

## Each kind: its zones, how likely an island has it, how many groups (dens); a "pack" [lo, hi] round a lead.
const FAUNA := {
	"boar": {"zones": ["floor"], "p": 0.6, "dens": [2, 4]},
	"wolf": {"zones": ["floor"], "p": 0.45, "dens": [1, 3], "pack": [3, 4]},
	"snake": {"zones": ["floor"], "p": 0.4, "dens": [2, 5]},
	"mite": {"zones": ["floor", "cave"], "p": 0.35, "dens": [1, 2]},
	"bat": {"zones": ["canopy", "cave"], "p": 0.55, "dens": [1, 3]},
	"crab": {"zones": ["shore"], "p": 0.5, "dens": [2, 5]},
}
const CREATURES := {
	"boar": "res://scripts/enemies/fauna/boar.gd",
	"wolf": "res://scripts/enemies/fauna/wolf.gd",
	"snake": "res://scripts/enemies/fauna/snake.gd",
	"mite": "res://scripts/enemies/fauna/swarm_mite.gd",
	"bat": "res://scripts/enemies/fauna/bat.gd",
	"crab": "res://scripts/enemies/fauna/crab.gd",
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
	props = {
		"forest_lamp": func(_rng: RandomNumberGenerator, size: float) -> Node3D: return ForestProps.lamp_post(2.6 * size),
		"forest_waymark": func(rng: RandomNumberGenerator, _size: float) -> Node3D: return ForestProps.waymark(rng.randi()),
	}
	life = preload("res://scripts/island/themes/forest_life.gd").TEXT
	# (interim: the jungle's and the snow's beasts and wildlife, renamed, until the forest's own)
	bosses = ["serpent", "stalker", "great_bear"]
	minis = ["boar"]
	roamers = ["behemoth"]
	beasts = {
		"serpent": {"script": "res://scripts/enemies/beasts/strangler.gd", "names": ["The Root Coil", "Old Bramble", "The Hollow Serpent"], "looks": 3},
		"stalker": {"script": "res://scripts/enemies/beasts/stalker.gd", "names": ["The Grey Shade", "Leafshadow", "The Quiet Death"], "looks": 3},
		"great_bear": {"script": "res://scripts/enemies/beasts/great_bear.gd", "names": ["The Bear of the Wood", "Old Ursa", "Barkhide"], "looks": 3,
			"banner": ["The Bear's Wood", "Bark torn off the trees higher than your head. Something heavy sleeps here."]},
		"boar": {"script": "res://scripts/enemies/beasts/alpha_boar.gd", "names": ["Acornmaw", "Old Bristle", "Rootgrubber", "Ironhide"], "site": "ruins"},
		"behemoth": {"script": "res://scripts/enemies/beasts/behemoth.gd", "names": ["The Mossback", "Old Oakhide", "The Walking Hill"]},
	}
	fauna = FAUNA
	creatures = CREATURES
	cave_fauna = {"ceiling": "bat", "floor": ["mite", "snake"]}


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
