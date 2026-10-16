extends ThemeDef
## The snow islands (docs/snow_island_plan.md): dense pine forests under snow, tall icy peaks,
## black-rock coasts and ice at the waterline, blue ice crystals that glow at night; towns of
## round pink-brick houses under green tiered roofs, iron lamp posts, cider and fur coats.
## Its plants are SnowPlants, its props SnowProps, its people's text snow_life.gd.

## Land (the keys as the jungle's, jungle_theme.gd). The mesh slots carry conifers: "giant" spruces,
## "fig" snow-laden firs, "kapok" great pines and "emergent" cedars over the forest; "tree" young
## pines and dead trees, "beach_tree" wind-bent shore pines, "shrub" saplings, "fern" junipers,
## "bush" frozen shrubs, "grass" frosted grass, "broadleaf" drifts, "bamboo" ice-crystal clusters,
## "mangrove" ice floes at the waterline, "rock" snow-capped black rocks.
const LAND := {
	"peak": [40.0, 58.0], "hills": [3, 5], "hill_h": [10.0, 22.0], "roll": 4.0, "base": 4.0,
	"ramp": [30.0, 50.0], "cliffs": [1, 3], "cliff_h": [8.0, 15.0],
	"tree": 0.5, "edge": 0.1, "beach_tree": 0.12, "fern": 0.3, "bush": 0.2, "grass": 0.3, "rock": 0.04,
	"cover": 0.72,
	"canopy": 0.8, "giants": {"giant": 5.0, "fig": 2.0, "kapok": 0.8, "emergent": 0.6},
	"bamboo": 0.025, "palm_inland": 0.0, "mangrove": 0.0,
	"broadleaf": 0.14, "shrub": 0.14, "floor": 0.35, "overgrown": 0.3,
	"forests": [
		["pine valley", {}],
		["deep spruce", {"canopy": 0.94, "giants": {"giant": 6.0, "fig": 1.0, "kapok": 2.2, "emergent": 1.0}, "shrub": 0.2, "floor": 0.45}],
		["open snowfield", {"cover": 0.45, "canopy": 0.45, "tree": 0.3, "broadleaf": 0.32, "grass": 0.45, "rock": 0.06, "shrub": 0.06}],
		["crystal slopes", {"bamboo": 0.12, "rock": 0.07, "canopy": 0.6, "giants": {"giant": 3.0, "fig": 3.0, "kapok": 0.5, "emergent": 0.5}}],
		["frozen shore", {"mangrove": 0.35, "beach_tree": 0.35, "rock": 0.05}],
		["heavy firs", {"giants": {"giant": 2.0, "fig": 5.0, "kapok": 0.5, "emergent": 0.4}, "floor": 0.5, "fern": 0.42}],
		["cedar ridge", {"giants": {"giant": 2.0, "fig": 1.0, "kapok": 1.2, "emergent": 3.2}, "tree": 0.36, "broadleaf": 0.2}],
	],
}

## The settlement style, over KitStyle.BRINEHOLLOW (the keys that differ; a nested table whole).
const STYLE := {
	"row_walls": ["brick_pink", "planks_dark", "brick_pink", "stone_brick", "planks"],
	"row_upper": ["planks_dark", "brick_pink", "planks"],
	"row_roofs": ["hip", "gable", "gable_front", "hip"],
	"row_roof_tex": ["roof_green", 0.7, "planks_dark"],
	"row_awnings": ["red", "", "green", "", "red", "blue"],
	"lamp": Color(1.0, 0.72, 0.4),
	"lamp_range": 12.0,
	# generated harbours (GenHarbour): the kinds this theme's roll from; pilings, decks, roofs and walls; tarps, net floats, the smugglers' signal lamp
	"harbour_kinds": ["wharf", "wharf", "cove", "ruins"],
	"harbour_wild_kinds": ["landing", "landing", "cove", "ruins", "wharf"],
	"harbour_pile": "planks_dark",
	"harbour_deck": "planks_weathered",
	"harbour_roof": "roof_green",
	"harbour_walls": ["planks_dark", "brick_pink", "planks"],
	"harbour_tarp": Color(0.46, 0.44, 0.42),
	"harbour_floats": [Color(0.8, 0.2, 0.16), Color(0.9, 0.88, 0.84), Color(0.2, 0.4, 0.6)],
	"harbour_signal": Color(1.0, 0.4, 0.2),
	"paving": "snow_packed",
	"quay_wall": Color(0.56, 0.58, 0.64),
	"quay_cope": Color(0.46, 0.48, 0.54),
	"iron": Color(0.2, 0.2, 0.23),
	"pennants": [Color(0.8, 0.16, 0.14), Color(0.18, 0.45, 0.3), Color(0.94, 0.92, 0.86), Color(0.86, 0.6, 0.18), Color(0.2, 0.32, 0.6)],
	"washing": [Color(0.92, 0.9, 0.85), Color(0.7, 0.2, 0.18), Color(0.3, 0.42, 0.62), Color(0.55, 0.5, 0.42), Color(0.2, 0.4, 0.3)],
	"goods": [Color(0.55, 0.4, 0.28), Color(0.85, 0.82, 0.76), Color(0.75, 0.2, 0.16), Color(0.4, 0.3, 0.22), Color(0.6, 0.7, 0.8)],
	"tent": Color(0.82, 0.78, 0.7),
	"camp_tent": Color(0.48, 0.44, 0.4),
	"rough": {"flowers": false, "trim": Color(0.3, 0.26, 0.24), "beam": "planks_dark", "pitch": 0.75, "eaves": 0.6},
	"crew_flag": Color(0.72, 0.18, 0.16),

	"mat": {"wall": "brick_pink", "beam": "planks_dark", "floor": "planks", "deck": "planks_weathered", "post": "planks_dark",
		"rail": "planks_dark", "roof": "roof_green", "thatch": "roof_green", "rope": "rope", "stone": "stone_brick", "cloth": "canvas",
		"weave": "planks_dark"},
	"house": {"w": [5.0, 6.5], "d": [4.5, 5.5], "h": [2.6, 3.0], "walls": ["brick_pink", "brick_pink", "planks_dark", "stone_brick"],
		"roofs": ["gable", "hip", "gable_front"], "roof_tex": ["roof_green", "roof_green", "planks_dark"], "pitch": [0.75, 0.95], "eaves": 0.6,
		"beam": "planks_dark", "floor": "planks", "poles": false, "lashings": false, "stilts": false,
		"porch": [0.4, 1.2, 1.8], "flowers": 0.0, "chimney": 0.85,
		"trims": [Color(0.86, 0.84, 0.78), Color(0.24, 0.4, 0.3), Color(0.6, 0.2, 0.16), Color(0.3, 0.26, 0.24), Color(0.22, 0.32, 0.5)]},
	"inn": {"w": 9.0, "d": 7.0, "h": 3.0, "roof": "hip", "wall": "brick_pink", "porch": 2.2, "flowers": false},
	"stall": {"canopies": ["cloth_red", "canvas", "cloth_red"], "post": "planks_dark"},
	"pier": {"deck": "planks_weathered", "post": "planks_dark", "rail": "planks_dark", "lashings": false, "rope_rail": true},
	"props": {"crate": "crate", "barrel": "barrel", "lamp": "snow_lamp", "marker": "snow_waymark"},
	"village_models": {"hut": "snow_round_house", "tall": "snow_round_house_tall"},
	# (no fur hats or mittens exist yet: knit caps, hoods and coifs, leather gloves stand in)
	"folk": {
		"pick": {"skin": [Color(0.96, 0.82, 0.70), Color(0.92, 0.74, 0.60), Color(0.87, 0.67, 0.50), Color(0.80, 0.60, 0.44)],
			"hair_color": [Color(0.82, 0.66, 0.38), Color(0.88, 0.87, 0.84), Color(0.45, 0.20, 0.10), Color(0.18, 0.11, 0.07), Color(0.62, 0.56, 0.48)],
			"hat": ["knit", "hood", "knit", "coif", "hood", "none"], "top": ["shirt", "tunic", "doublet"], "top_fem": ["blouse", "tunic", "shirt"],
			"sleeves": ["long"], "coat": ["greatcoat", "longcoat", "duster", "jacket", "greatcoat"], "legs": ["trousers", "breeches"],
			"legs_fem": ["skirt", "trousers", "skirt"], "feet": ["tall_boots", "boots", "tall_boots"], "belt": ["belt", "wide_belt", "none"],
			"scarf": [true, true, false], "gloves": [true, true, false], "mantle": [false, false, false, true],
			"top_color": [Color(0.90, 0.88, 0.80), Color(0.82, 0.76, 0.62), Color(0.40, 0.10, 0.12), Color(0.55, 0.55, 0.55)],
			"coat_color": [Color(0.62, 0.52, 0.38), Color(0.40, 0.28, 0.18), Color(0.66, 0.14, 0.12), Color(0.82, 0.76, 0.62), Color(0.28, 0.28, 0.30), Color(0.14, 0.18, 0.34)],
			"legs_color": [Color(0.24, 0.17, 0.12), Color(0.28, 0.28, 0.30), Color(0.14, 0.18, 0.34), Color(0.40, 0.28, 0.18)],
			"hat_color": [Color(0.66, 0.14, 0.12), Color(0.90, 0.88, 0.80), Color(0.18, 0.34, 0.20), Color(0.62, 0.52, 0.38), Color(0.20, 0.32, 0.62)],
			"scarf_color": [Color(0.66, 0.14, 0.12), Color(0.80, 0.62, 0.20), Color(0.16, 0.42, 0.44), Color(0.90, 0.88, 0.80), Color(0.36, 0.20, 0.44)],
			"mantle_color": [Color(0.82, 0.76, 0.62), Color(0.62, 0.52, 0.38), Color(0.90, 0.88, 0.80)]},
		"set": {"eyepatch": false, "vest": "none"},
	},
	"music": "snow",
	"music_town": "snow_town",
	"ambience": "snow",
	"ground": {"grass": "snow", "sand": "snow_beach", "wet_sand": "shingle_wet", "dirt": "snow_packed", "rock": "glacier_rock", "seafloor": "seafloor", "cliff": "black_rock"},
	"cave_look": {"rock": ["black_rock", Color(0.9, 0.92, 0.96)], "moss": ["glacier_rock", Color(0.95, 0.97, 1.0)], "turf": ["snow", Color.WHITE],
		"wall": ["glacier_rock", Color(0.7, 0.78, 0.88)], "floor": ["snow_packed", Color(0.8, 0.84, 0.9)]},
	# mostly overcast and white with haze (the fog's colour is Weather's: the weather pass themes it)
	"weather": [0.15, 0.8, 0.95],
	"haze": 0.4,
	# landmarks and set pieces (KitLandmarks, KitSetPieces): rock, carved stone, water, bone, lava, crystal
	"rock_tint": Color(0.44, 0.46, 0.52),
	"moss_tint": Color(0.86, 0.9, 0.96),
	"temple_stone": Color(0.78, 0.8, 0.86),
	"fort_stone": Color(0.72, 0.72, 0.76),
	"water_tint": Color(0.32, 0.5, 0.62, 0.85),
	"falls_tint": Color(0.86, 0.94, 1.0, 0.88),
	"spring_tint": Color(0.6, 0.85, 0.95, 0.85),
	"travertine": Color(0.92, 0.93, 0.96),
	"wreck_hull": Color(0.5, 0.52, 0.56),
	"bone": Color(0.9, 0.88, 0.82),
	"basalt": Color(0.2, 0.21, 0.24),
	"lava": Color(1.0, 0.45, 0.12),
	"crystal": Color(0.45, 0.75, 1.0),
	"rust": Color(0.4, 0.32, 0.28),
}

## Each kind: its zones, how likely an island has it, how many groups (dens) when it does; the snow's own
## kinds a "pack" [lo, hi] round a lead and the chance a follower is "young" (FaunaSpawner's default group).
const FAUNA := {
	"wolf": {"zones": ["floor"], "p": 0.75, "dens": [2, 4], "pack": [3, 5]},
	"snow_hare": {"zones": ["floor"], "p": 0.7, "dens": [3, 6], "pack": [2, 4]},
	"snow_bear": {"zones": ["floor"], "p": 0.5, "dens": [1, 3], "pack": [1, 2], "young": 0.8},
	"shagback": {"zones": ["floor"], "p": 0.5, "dens": [1, 2], "pack": [3, 5], "young": 0.3},
	"walrus": {"zones": ["shore"], "p": 0.6, "dens": [1, 3], "pack": [3, 6], "young": 0.35},
	"mite": {"zones": ["floor", "cave"], "p": 0.35, "dens": [1, 2]},
	"bat": {"zones": ["cave"], "p": 0.5, "dens": [1, 3]},
}
const CREATURES := {
	"wolf": "res://scripts/enemies/fauna/wolf.gd",
	"snow_hare": "res://scripts/enemies/fauna/snow_hare.gd",
	"snow_bear": "res://scripts/enemies/fauna/snow_bear.gd",
	"shagback": "res://scripts/enemies/fauna/shagback.gd",
	"walrus": "res://scripts/enemies/fauna/walrus.gd",
	"mite": "res://scripts/enemies/fauna/swarm_mite.gd",
	"bat": "res://scripts/enemies/fauna/bat.gd",
}


func _init() -> void:
	name = "snow"
	display = "Snow"
	blurb = "a frozen isle of pines and icy peaks"
	island_names = ["Frosthelm", "Rimeholt", "Whitecap", "Glacia", "Icefang", "Winterhold", "Hoarfell", "Snowmere"]
	weight = 1.0
	color = Color(0.72, 0.88, 1.0)
	glyph = _glyph
	flocks = 0
	land = LAND
	radius = [300.0, 450.0]
	style = STYLE
	props = {
		"snow_lamp": func(_rng: RandomNumberGenerator, size: float) -> Node3D: return SnowProps.lamp_post(2.6 * size),
		"snow_waymark": func(rng: RandomNumberGenerator, _size: float) -> Node3D: return SnowProps.waymark(rng.randi()),
		"snow_round_house": func(rng: RandomNumberGenerator, size: float) -> Node3D: return SnowProps.round_house(rng.randi(), size),
		"snow_round_house_tall": func(rng: RandomNumberGenerator, size: float) -> Node3D: return SnowProps.round_house(rng.randi(), size, 2),
	}
	life = preload("res://scripts/island/themes/snow_life.gd").TEXT
	# (the serpent is the jungle's, coiled in the pines: a fourth so a branching chain never runs the pool dry)
	bosses = ["snow_leopard", "great_bear", "ice_golem", "serpent"]
	minis = ["frost_alpha"]
	roamers = ["rimeback"]
	beasts = {
		"snow_leopard": {"script": "res://scripts/enemies/beasts/snow_leopard.gd", "names": ["The White Shade", "The Pale Death", "Ghostpaw"], "looks": 3,
			"banner": ["The White Shade's Run", "Pawprints in the snow, then none. Something is watching you."]},
		"great_bear": {"script": "res://scripts/enemies/beasts/great_bear.gd", "names": ["The Bear King", "Old Whitemaw", "The Snow Tyrant"], "looks": 3,
			"banner": ["The Bear King's Den", "Pines torn from the ground, bones under the snow. Something huge sleeps here."]},
		"ice_golem": {"script": "res://scripts/enemies/beasts/ice_golem.gd", "names": ["The Ice Golem", "The Glacier's Heart", "Rimehulk"], "looks": 3,
			"banner": ["The Frozen Hollow", "The crystals here hum. The ice underfoot is breathing."]},
		"serpent": {"script": "res://scripts/enemies/beasts/strangler.gd", "names": ["The Ice Coil", "Old Rimescale", "The Pine Strangler"], "looks": 3},
		"frost_alpha": {"script": "res://scripts/enemies/beasts/frost_alpha.gd", "names": ["Frostfang", "Old Rime", "Whitefang", "The Howler"], "site": "ruins"},
		"rimeback": {"script": "res://scripts/enemies/beasts/rimeback.gd", "names": ["The Rimeback", "Old Glacier", "The Snowhorn"]},
	}
	fauna = FAUNA
	creatures = CREATURES
	cave_fauna = {"ceiling": "bat", "floor": ["mite"]}


func meshes() -> Dictionary:
	return {
		"tree": [SnowPlants.young_pine(721), SnowPlants.young_pine(722), SnowPlants.young_pine(723), SnowPlants.young_pine(724), SnowPlants.dead_tree(725)],
		"beach_tree": [SnowPlants.bent_pine(711), SnowPlants.bent_pine(712), SnowPlants.dead_tree(713)],
		"bush": [SnowPlants.frost_shrub(731), SnowPlants.frost_shrub(732)],
		"fern": [SnowPlants.juniper(741), SnowPlants.juniper(742)],
		"grass": [SnowPlants.frost_grass()],
		"rock": [SnowPlants.snow_rock(751), SnowPlants.snow_rock(752), SnowPlants.snow_rock(753)],
		# big trees: [body, detail, lean]
		"giant": [SnowPlants.spruce(761), SnowPlants.spruce(762), SnowPlants.spruce(763)],
		"fig": [SnowPlants.fir(765), SnowPlants.fir(766)],
		"kapok": [SnowPlants.great_pine(775)],
		"emergent": [SnowPlants.cedar(771), SnowPlants.cedar(772)],
		"roof": [SnowPlants.bough_roof(768)],
		"mangrove": [SnowPlants.ice_floe(785), SnowPlants.ice_floe(786)],
		"bamboo": [SnowPlants.crystal_cluster(781), SnowPlants.crystal_cluster(782, 1.3)],
		"broadleaf": [SnowPlants.drift(791), SnowPlants.drift(792)],
		"shrub": [SnowPlants.sapling(795), SnowPlants.sapling(796)],
	}


## A six-armed snowflake.
static func _glyph(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	for k in range(3):
		var d := Vector2.from_angle(PI / 2.0 + PI * k / 3.0) * s
		ci.draw_line(p - d, p + d, col, 1.0)
		for e in [-1.0, 1.0]:
			var at: Vector2 = p + d * 0.55 * e
			ci.draw_line(at, at + d.rotated(0.8) * 0.3 * e, col, 1.0)
			ci.draw_line(at, at + d.rotated(-0.8) * 0.3 * e, col, 1.0)
