extends ThemeDef
## The volcanic isles (docs/volcanic_island_plan.md, 1.28): a black island round a living volcano. Grey ash over
## black ground, black sand beaches, basalt crags; a smoking cone near the middle with a caldera in its top, breached
## on the town's side, lava flows down its flanks (fixed hazards that burn: volcanic_land.gd, volcanic_hazard.gd);
## sparse hardy plants (charred trees, ash pines, fire lilies, fumaroles: VolcanicPlants). Its town is a forge town
## of basalt and dark slate. Rolled apart like the fog isle, and only from the chain's fourth layer on.

## Land (the jungle's keys, jungle_theme.gd). The mesh slots: "giant" scorched giants, "fig" great ash pines, "kapok"
## and "emergent" both; "tree" charred trees and ash pines, "beach_tree" salt-bent pines and charred trees, "shrub"
## charred whips, "bush" ash shrubs, "fern" fire lilies, "grass" wiry ash grass, "broadleaf" charred logs, pumice and
## ash drifts, "bamboo" fumaroles, "mangrove" pumice at the waterline, "rock" basalt and obsidian. The cone is the
## land's own (volcanic_land.gd): "peak" and "hills" stay low under it.
const LAND := {
	"peak": [4.0, 8.0], "hills": [1, 3], "hill_h": [4.0, 9.0], "roll": 3.0, "base": 3.6,
	"ramp": [26.0, 44.0], "cliffs": [1, 3], "cliff_h": [8.0, 16.0],
	"tree": 0.22, "edge": 0.06, "beach_tree": 0.05, "fern": 0.12, "bush": 0.16, "grass": 0.34, "rock": 0.07,
	"cover": 0.5,
	"canopy": 0.18, "giants": {"giant": 3.0, "fig": 2.0, "kapok": 0.6, "emergent": 0.6},
	"bamboo": 0.05, "palm_inland": 0.0, "mangrove": 0.06,
	"broadleaf": 0.08, "shrub": 0.12, "floor": 0.15, "overgrown": 0.1,
	"forests": [
		["ash barrens", {}],
		["scorched woods", {"canopy": 0.32, "tree": 0.34, "giants": {"giant": 5.0, "fig": 1.0, "kapok": 0.5, "emergent": 0.5}, "shrub": 0.2}],
		["cinder fields", {"cover": 0.32, "canopy": 0.08, "tree": 0.1, "grass": 0.44, "rock": 0.1, "broadleaf": 0.14}],
		["ash pine slopes", {"canopy": 0.3, "tree": 0.3, "giants": {"giant": 0.6, "fig": 5.0, "kapok": 1.0, "emergent": 1.0}, "fern": 0.16}],
		["fumarole flats", {"bamboo": 0.14, "rock": 0.09, "canopy": 0.1, "fern": 0.2, "grass": 0.26}],
	],
}

const LAND_FEATURES := preload("res://scripts/island/themes/volcanic_land.gd")

## The settlement style over KitStyle.BRINEHOLLOW: houses of basalt and dark timber under slate, iron lamps burning
## orange, soot on everything; leather, canvas and iron.
const STYLE := {
	"lamp": Color(1.0, 0.6, 0.3),
	"lamp_range": 12.0,
	"paving": "volcanic_cinder",
	"quay_wall": Color(0.34, 0.33, 0.34),
	"quay_cope": Color(0.26, 0.25, 0.26),
	"iron": Color(0.14, 0.13, 0.13),
	"row_walls": ["stone_brick", "planks_dark", "volcanic_basalt", "stone_brick", "planks_dark"],
	"row_upper": ["planks_dark", "stone_brick", "planks_grey"],
	"row_roofs": ["gable", "gable_front", "hip", "gable"],
	"row_roof_tex": ["volcanic_slate", 0.85, "shingles"],
	"row_awnings": ["red", "", "", "red", ""],
	"pennants": [Color(0.78, 0.26, 0.12), Color(0.2, 0.2, 0.22), Color(0.86, 0.6, 0.18), Color(0.5, 0.48, 0.46), Color(0.62, 0.16, 0.1)],
	"washing": [Color(0.7, 0.66, 0.6), Color(0.42, 0.4, 0.38), Color(0.6, 0.3, 0.2), Color(0.5, 0.44, 0.36), Color(0.3, 0.3, 0.32)],
	"rugs": [["canvas", Color(0.6, 0.56, 0.52)], ["cloth_red", Color(0.7, 0.55, 0.5)]],
	"goods": [Color(0.4, 0.4, 0.42), Color(0.62, 0.36, 0.2), Color(0.86, 0.6, 0.2), Color(0.3, 0.26, 0.24), Color(0.74, 0.7, 0.62)],
	"tent": Color(0.58, 0.54, 0.5),
	"camp_tent": Color(0.4, 0.36, 0.33),
	"rough": {"flowers": false, "trim": Color(0.2, 0.18, 0.17), "wall": "planks_dark", "roof_tex": "volcanic_slate", "beam": "planks_dark", "pitch": 0.6, "eaves": 0.5},
	"crew_flag": Color(0.62, 0.2, 0.12),
	"pirate_flag": Color(0.1, 0.09, 0.09),
	"high_birds": "dark",
	"ambient_bugs": false,
	"mat": {"wall": "stone_brick", "beam": "planks_dark", "floor": "planks", "deck": "planks_weathered", "post": "planks_dark",
		"rail": "planks_dark", "roof": "volcanic_slate", "thatch": "volcanic_slate", "rope": "rope", "stone": "stone_brick", "cloth": "canvas",
		"weave": "planks_dark"},
	"house": {"w": [5.0, 6.8], "d": [4.2, 5.4], "h": [2.6, 3.0], "walls": ["stone_brick", "stone_brick", "planks_dark", "volcanic_basalt"],
		"roofs": ["gable", "hip", "gable_front"], "roof_tex": ["volcanic_slate", "volcanic_slate", "shingles"], "pitch": [0.55, 0.7], "eaves": 0.45,
		"beam": "planks_dark", "floor": "planks", "poles": false, "lashings": false, "stilts": false,
		"porch": [0.3, 1.0, 1.6], "flowers": 0.0, "chimney": 0.95,
		"trims": [Color(0.2, 0.18, 0.17), Color(0.5, 0.2, 0.12), Color(0.36, 0.34, 0.32), Color(0.62, 0.42, 0.18), Color(0.16, 0.18, 0.22)]},
	"inn": {"w": 9.0, "d": 7.0, "h": 3.0, "roof": "hip", "wall": "stone_brick", "porch": 2.0, "flowers": false},
	"stall": {"canopies": ["canvas", "cloth_red", "canvas"], "post": "planks_dark"},
	"pier": {"deck": "planks_weathered", "post": "planks_dark", "rail": "planks_dark", "lashings": false, "rope_rail": true},
	"props": {"crate": "crate", "barrel": "barrel", "lamp": "lantern_post", "marker": "notice_board"},
	"yard_fences": 0.15,
	"village_layouts": {"town": 4, "hamlets": 1, "post": 2, "stilts": 0, "ruins": 1, "medina": 0},
	"folk": {
		"pick": {"skin": [Color(0.92, 0.78, 0.64), Color(0.84, 0.66, 0.5), Color(0.72, 0.54, 0.4), Color(0.58, 0.42, 0.3), Color(0.44, 0.3, 0.22)],
			"hair_color": [Color(0.14, 0.11, 0.09), Color(0.32, 0.2, 0.12), Color(0.6, 0.28, 0.12), Color(0.5, 0.48, 0.46), Color(0.84, 0.82, 0.78), Color(0.1, 0.09, 0.09)],
			"hat": ["bandana", "cap", "none", "none", "knit", "bandana"], "hat_fem": ["bandana", "coif", "none", "none"],
			"top": ["shirt", "tunic", "shirt"], "top_fem": ["blouse", "tunic", "shirt"], "sleeves": ["short", "short", "long"],
			"vest": ["vest", "none", "jerkin", "vest"], "coat": ["none", "none", "jacket"],
			"legs": ["trousers", "breeches"], "legs_fem": ["trousers", "skirt", "trousers"], "feet": ["boots", "tall_boots", "boots"],
			"belt": ["wide_belt", "belt", "wide_belt"], "gloves": [true, false, true],
			"top_color": [Color(0.7, 0.66, 0.6), Color(0.46, 0.42, 0.38), Color(0.32, 0.3, 0.3), Color(0.58, 0.3, 0.2), Color(0.24, 0.24, 0.26)],
			"vest_color": [Color(0.34, 0.24, 0.16), Color(0.22, 0.2, 0.2), Color(0.42, 0.3, 0.2)],
			"coat_color": [Color(0.3, 0.26, 0.22), Color(0.2, 0.2, 0.22), Color(0.46, 0.32, 0.22)],
			"legs_color": [Color(0.24, 0.2, 0.17), Color(0.2, 0.2, 0.22), Color(0.34, 0.26, 0.2), Color(0.3, 0.28, 0.26)],
			"hat_color": [Color(0.62, 0.18, 0.1), Color(0.24, 0.22, 0.22), Color(0.5, 0.44, 0.38), Color(0.78, 0.5, 0.16)]},
		"set": {"eyepatch": false, "scarf": false},
	},
	"music": "desert_night",
	"music_town": "desert_town_night",
	"ambience": "desert",
	"ground": {"grass": "volcanic_ash", "sand": "volcanic_sand", "wet_sand": "volcanic_sand", "dirt": "volcanic_cinder", "rock": "volcanic_basalt",
		"seafloor": "seafloor", "cliff": "volcanic_basalt"},
	"arena": "open",
	"cave_look": {"rock": ["volcanic_basalt", Color(1.0, 1.0, 1.0)], "moss": ["volcanic_ash", Color(0.9, 0.88, 0.86)], "turf": ["volcanic_ash", Color.WHITE],
		"wall": ["volcanic_basalt", Color(0.85, 0.8, 0.78)], "floor": ["volcanic_cinder", Color(0.9, 0.88, 0.86)]},
	# hazy under the smoke: clear now and then, mostly overcast, rain and a storm sometimes; an ash-brown haze
	"weather": [0.25, 0.75, 0.92],
	"haze": 0.35,
	"haze_color": Color(0.52, 0.47, 0.43, 0.6),
	"storm_color": Color(0.3, 0.26, 0.24),
	"rock_tint": Color(0.3, 0.29, 0.3),
	"moss_tint": Color(0.46, 0.44, 0.4),
	"temple_stone": Color(0.42, 0.4, 0.4),
	"fort_stone": Color(0.46, 0.44, 0.44),
	"water_tint": Color(0.22, 0.34, 0.36, 0.86),
	"falls_tint": Color(0.78, 0.82, 0.82, 0.85),
	"spring_tint": Color(0.5, 0.7, 0.6, 0.85),
	"travertine": Color(0.86, 0.8, 0.6),
	"wreck_hull": Color(0.3, 0.27, 0.25),
	"bone": Color(0.86, 0.82, 0.74),
	"basalt": Color(0.18, 0.17, 0.18),
	"lava": Color(1.0, 0.45, 0.12),
	"crystal": Color(1.0, 0.5, 0.2),
	"rust": Color(0.46, 0.26, 0.16),
	"harbour_kinds": ["wharf", "wharf", "cove", "ruins"],
	"harbour_wild_kinds": ["landing", "cove", "wharf", "ruins"],
	"harbour_pile": "planks_dark",
	"harbour_deck": "planks_weathered",
	"harbour_roof": "volcanic_slate",
	"harbour_walls": ["stone_brick", "planks_dark", "volcanic_basalt"],
	"harbour_tarp": Color(0.42, 0.38, 0.34),
	"harbour_floats": [Color(0.78, 0.3, 0.12), Color(0.3, 0.3, 0.32), Color(0.86, 0.6, 0.2)],
	"harbour_signal": Color(1.0, 0.45, 0.15),
}

## Each kind: its zones, how likely an island has it, how many groups, a group's size. Hardy things: monitor lizards
## basking on the warm rock, scorpions and snakes in the cinders, crabs on the black sand, bats in the lava tubes.
const FAUNA := {
	"lizard": {"zones": ["floor"], "p": 0.85, "dens": [2, 5], "pack": [1, 2], "young": 0.4},
	"scorpion": {"zones": ["floor"], "p": 0.6, "dens": [2, 5], "pack": [1, 3], "young": 0.0},
	"snake": {"zones": ["floor"], "p": 0.45, "dens": [1, 4]},
	"crab": {"zones": ["shore"], "p": 0.8, "dens": [3, 6]},
	"mite": {"zones": ["floor", "cave"], "p": 0.35, "dens": [1, 2]},
	"bat": {"zones": ["cave"], "p": 0.7, "dens": [1, 3]},
}
const CREATURES := {
	"lizard": "res://scripts/enemies/fauna/monitor_lizard.gd",
	"scorpion": "res://scripts/enemies/fauna/scorpion.gd",
	"snake": "res://scripts/enemies/fauna/snake.gd",
	"crab": "res://scripts/enemies/fauna/crab.gd",
	"mite": "res://scripts/enemies/fauna/swarm_mite.gd",
	"bat": "res://scripts/enemies/fauna/bat.gd",
}


func _init() -> void:
	name = "volcanic"
	display = "Volcanic Isle"
	blurb = "a black isle round a smoking volcano"
	island_names = ["Emberhold", "Cinderfall", "Ashkeep", "Slagrock", "Hearthmount", "Brimstone Key", "Obsidia", "Kilnrock", "Pyrewatch", "Scoria"]
	# (rolled apart: its own chance on a regular island, from the fourth layer on; every other island stays as it was)
	weight = 0.22
	apart = true
	from_layer = 4
	color = Color(1.0, 0.45, 0.2)
	glyph = _glyph
	flocks = 0
	land = LAND
	radius = [340.0, 440.0]
	style = STYLE
	props = {}
	life = preload("res://scripts/island/themes/volcanic_life.gd").TEXT
	encounters = preload("res://scripts/island/themes/volcanic_encounters.gd").TEXT
	bosses = ["basilisk", "serpent"]
	minis = ["boar"]
	roamers = ["behemoth"]
	beasts = {
		"basilisk": {"script": "res://scripts/enemies/beasts/basilisk.gd", "names": ["The Cinder Basilisk", "Old Slagjaw", "The Ash-Eye"], "looks": 3,
			"banner": ["The Caldera", "The ground is warm through your boots. Something big has worn a path round the lava."]},
		"serpent": {"script": "res://scripts/enemies/beasts/strangler.gd", "names": ["The Ash Coil", "Old Brimstone", "The Cinder Serpent"], "looks": 3,
			"banner": ["The Smoking Hollow", "Scales the size of shields in the ash. The smoke here coils as if something breathes it."]},
		"boar": {"script": "res://scripts/enemies/beasts/alpha_boar.gd", "names": ["Ashtusk", "Old Scorch", "Cindermaw", "Slagback"], "site": "lair"},
		"behemoth": {"script": "res://scripts/enemies/beasts/behemoth.gd", "names": ["The Cinderhorn", "Old Slagback", "The Ash Grazer"]},
	}
	fauna = FAUNA
	creatures = CREATURES
	cave_fauna = {"ceiling": "bat", "floor": ["mite", "scorpion", "snake"]}


## The land (volcanic_land.gd): the cone and its caldera, the breach, the lava flows.
func plan_land(isl, rng: RandomNumberGenerator) -> Dictionary:
	return LAND_FEATURES.plan(isl, rng)


func shape(isl, p: Vector2, h: float) -> float:
	return LAND_FEATURES.shape(isl, p, h)


func village_at(isl, p: Vector2) -> Vector2:
	return LAND_FEATURES.village_at(isl, p)


func site_at(isl, site: String, p: Vector2) -> Vector2:
	return LAND_FEATURES.site_at(isl, site, p)


func cover(isl, p: Vector2, c: float) -> float:
	return LAND_FEATURES.cover(isl, p, c)


func growth(isl, p: Vector2) -> Vector2:
	return LAND_FEATURES.growth(isl, p)


func paint(isl, p: Vector2, h: float, splat: Color) -> Color:
	return LAND_FEATURES.paint(isl, p, h, splat)


func steps(isl) -> Array:
	return LAND_FEATURES.steps(isl)


func meshes() -> Dictionary:
	return {
		"tree": [VolcanicPlants.charred_tree(1101), VolcanicPlants.charred_tree(1102), VolcanicPlants.charred_tree(1103), VolcanicPlants.ash_pine(1104), VolcanicPlants.ash_pine(1105)],
		"beach_tree": [VolcanicPlants.ash_pine(1111, true), VolcanicPlants.ash_pine(1112, true), VolcanicPlants.charred_tree(1113)],
		"bush": [VolcanicPlants.ash_shrub(1121), VolcanicPlants.ash_shrub(1122)],
		"fern": [VolcanicPlants.fire_lily(1131), VolcanicPlants.fire_lily(1132)],
		"grass": [VolcanicPlants.grass()],
		"rock": [VolcanicPlants.basalt_rock(1141), VolcanicPlants.basalt_rock(1142), VolcanicPlants.basalt_rock(1143), VolcanicPlants.obsidian_rock(1144)],
		# big trees: [body, detail, lean]
		"giant": [VolcanicPlants.scorched_giant(1151), VolcanicPlants.scorched_giant(1152), VolcanicPlants.scorched_giant(1153)],
		"fig": [VolcanicPlants.great_pine(1155), VolcanicPlants.great_pine(1156)],
		"kapok": [VolcanicPlants.scorched_giant(1157)],
		"emergent": [VolcanicPlants.great_pine(1158)],
		"roof": [VolcanicPlants.limb_roof(1161)],
		"mangrove": [VolcanicPlants.pumice(1171), VolcanicPlants.pumice(1172)],
		"bamboo": [VolcanicPlants.fumarole(1175), VolcanicPlants.fumarole(1176)],
		"broadleaf": [VolcanicPlants.charred_log(1181), VolcanicPlants.ash_drift(1182), VolcanicPlants.pumice(1183), VolcanicPlants.ash_drift(1184)],
		"shrub": [VolcanicPlants.whip(1191), VolcanicPlants.whip(1192)],
	}


## A volcano: a cone with a notch in its top and a puff of smoke.
static func _glyph(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	var w := s * 0.95
	var top := p.y - s * 0.3
	ci.draw_polyline(PackedVector2Array([Vector2(p.x - w, p.y + s * 0.75), Vector2(p.x - s * 0.3, top), Vector2(p.x - s * 0.1, top + s * 0.15),
		Vector2(p.x + s * 0.1, top + s * 0.15), Vector2(p.x + s * 0.3, top), Vector2(p.x + w, p.y + s * 0.75)]), col, 1.0)
	ci.draw_arc(Vector2(p.x + s * 0.1, top - s * 0.4), s * 0.22, 0.0, TAU, 6, col, 1.0)
