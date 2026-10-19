extends ThemeDef
## The jungle: steaming islands under a closed canopy of giants, figs and kapoks, stilt huts of
## bamboo and woven palm, tiki torches, baskets and clay pots, a mossy green stone; the ape,
## the strangler, the shade and the mantis queen in its arenas, the alpha boar at the ruins,
## the behemoth on its floor. Its plants are JunglePlants, its props JungleProps, its people's
## text jungle_life.gd, its beasts scripts/enemies/beasts/ (and the ape, scripts/enemies/jungle_ape.gd).

## Land: "peak" the main summit's height, "hills" how many and how high, "roll" the inland swell,
## "base" the height where the beach ramp levels off, "ramp" the beach ramp's width, "cliffs" how
## many stretches of coast drop sheer (with "cliff_h", their top). Plants (chances per grid cell):
## "tree" in the thick of it, "edge" where the cover thins, "beach_tree" on the sand,
## "fern"/"bush"/"grass" undergrowth, "rock" scattered boulders; "cover" how much of the inland is
## overgrown (0..1, the rest clearings). The canopy: "canopy" the chance of a big tree per 10 m cell
## in the thick of it, "giants" what kind ({mesh list: weight}: canopy trees, strangler figs, kapoks,
## emergents); "bamboo" clumps and "palm_inland" palms (5 m grid, in the cover), "mangrove" at the
## waterline. The floor: "broadleaf" big-leaved plants, "shrub" understory trees, "floor" a second
## layer of ferns and grass under thick cover, "overgrown" how much of that grows on the trails (the
## dock road stays clear). "forests": [name, overrides] - each island grows one, picked from its seed.
const LAND := {
	"peak": [24.0, 36.0], "hills": [2, 4], "hill_h": [6.0, 14.0], "roll": 3.0, "base": 4.4,
	"ramp": [38.0, 62.0], "cliffs": [1, 2], "cliff_h": [7.0, 12.0],
	"tree": 0.46, "edge": 0.12, "beach_tree": 0.42, "fern": 0.44, "bush": 0.26, "grass": 0.26, "rock": 0.025,
	"cover": 0.76,
	"canopy": 0.74, "giants": {"giant": 6.0, "fig": 1.0, "kapok": 0.8, "emergent": 1.0},
	"bamboo": 0.07, "palm_inland": 0.0, "mangrove": 0.0,
	"broadleaf": 0.24, "shrub": 0.14, "floor": 0.5, "overgrown": 0.45,
	"forests": [
		["mixed", {}],
		["old growth", {"canopy": 0.92, "giants": {"giant": 5.0, "fig": 1.5, "kapok": 2.2, "emergent": 2.4}, "bamboo": 0.03, "shrub": 0.18}],
		["bamboo thicket", {"bamboo": 0.3, "canopy": 0.5, "tree": 0.28, "shrub": 0.08}],
		["mangrove coast", {"mangrove": 0.5, "beach_tree": 0.2}],
		["palm fringe", {"beach_tree": 0.7, "palm_inland": 0.09, "canopy": 0.55}],
		["strangler figs", {"giants": {"giant": 3.0, "fig": 4.0, "kapok": 0.6, "emergent": 1.0}, "overgrown": 0.6}],
	],
}

## The settlement style, over KitStyle.BRINEHOLLOW (the keys that differ; a nested table whole).
const STYLE := {
	"row_walls": ["woven", "bamboo", "planks_weathered", "woven"],
	"row_upper": ["woven", "bamboo"],
	"row_roofs": ["gable", "hip", "gable_front"],
	"row_roof_tex": ["palm_thatch", 1.0, "palm_thatch"],
	"row_awnings": ["", "red", "", "green", ""],
	"lamp": Color(1.0, 0.66, 0.32),
	"lamp_range": 12.0,
	# generated harbours (GenHarbour): the kinds this theme's roll from; pilings, decks, roofs and walls; tarps, net floats, the smugglers' signal lamp
	"harbour_kinds": ["stilts", "cove", "wharf", "ruins"],
	"harbour_wild_kinds": ["landing", "landing", "cove", "ruins", "stilts"],
	"harbour_pile": "palm_bark",
	"harbour_deck": "planks_weathered",
	"harbour_roof": "thatch",
	"harbour_walls": ["planks", "planks_weathered", "planks"],
	"harbour_tarp": Color(0.52, 0.48, 0.38),
	"harbour_floats": [Color(0.9, 0.55, 0.2), Color(0.88, 0.86, 0.8), Color(0.75, 0.25, 0.18)],
	"harbour_signal": Color(1.0, 0.32, 0.22),
	"paving": "flagstones",
	"quay_wall": Color(0.68, 0.74, 0.62),
	"quay_cope": Color(0.58, 0.63, 0.52),
	"iron": Color(0.26, 0.2, 0.16),
	"pennants": [Color(0.85, 0.2, 0.18), Color(0.98, 0.78, 0.18), Color(0.12, 0.55, 0.52), Color(0.95, 0.5, 0.15), Color(0.3, 0.62, 0.22)],
	"washing": [Color(0.92, 0.88, 0.76), Color(0.85, 0.32, 0.22), Color(0.2, 0.55, 0.55), Color(0.95, 0.72, 0.25), Color(0.6, 0.3, 0.5)],
	"goods": [Color(0.98, 0.62, 0.12), Color(0.95, 0.85, 0.25), Color(0.45, 0.3, 0.16), Color(0.92, 0.35, 0.25), Color(0.45, 0.72, 0.2)],
	"tent": Color(0.82, 0.76, 0.56),
	"camp_tent": Color(0.52, 0.5, 0.38),
	"rough": {"flowers": false, "trim": Color(0.34, 0.28, 0.2), "beam": "bamboo", "poles": true, "lashings": true, "pitch": 0.62, "eaves": 0.75},
	"crew_flag": Color(0.72, 0.28, 0.2),

	"mat": {"wall": "woven", "beam": "bamboo", "floor": "planks_weathered", "deck": "planks_weathered", "post": "palm_bark",
		"rail": "bamboo", "roof": "palm_thatch", "thatch": "palm_thatch", "rope": "rope", "stone": "stone_brick", "cloth": "canvas",
		"weave": "straw"},
	"house": {"w": [4.0, 5.5], "d": [3.5, 4.5], "h": [2.2, 2.5], "walls": ["woven", "bamboo", "woven", "planks_weathered"],
		"roofs": ["gable", "hip", "gable", "gable_front"], "roof_tex": ["palm_thatch"], "pitch": [0.68, 0.8], "eaves": 0.85,
		"beam": "bamboo", "floor": "planks_weathered", "poles": true, "lashings": true, "stilts": true,
		"porch": [0.5, 1.2, 1.6], "flowers": 0.25, "chimney": 0.0,
		"trims": [Color(0.42, 0.3, 0.2), Color(0.55, 0.36, 0.2), Color(0.25, 0.42, 0.38), Color(0.62, 0.26, 0.18)]},
	"inn": {"w": 8.0, "d": 6.0, "h": 2.8, "roof": "hip", "wall": "bamboo", "porch": 2.0, "flowers": false},
	"stall": {"canopies": ["palm_thatch", "cloth_red", "palm_thatch"], "post": "bamboo"},
	"pier": {"deck": "planks_weathered", "post": "palm_bark", "rail": "bamboo", "lashings": true, "rope_rail": true},
	"props": {"crate": "basket", "barrel": "pot", "lamp": "torch_post", "marker": "totem"},
	"folk": {
		"pick": {"skin": [Color(0.80, 0.60, 0.44), Color(0.72, 0.52, 0.38), Color(0.62, 0.43, 0.30), Color(0.50, 0.34, 0.23), Color(0.38, 0.25, 0.17)],
			"hair_color": [Color(0.08, 0.06, 0.05), Color(0.08, 0.06, 0.05), Color(0.18, 0.11, 0.07), Color(0.32, 0.20, 0.11)],
			"hat": ["none", "none", "straw", "bandana", "none"], "top": ["bare", "tunic", "bare", "shirt"], "top_fem": ["blouse", "tunic", "blouse"],
			"sleeves": ["none", "short"], "legs": ["shorts", "shorts", "trousers"], "legs_fem": ["skirt", "skirt", "shorts"],
			"feet": ["barefoot", "barefoot", "shoes"], "belt": ["sash", "sash", "none"], "marks": ["none", "none", "none", "war_paint"],
			"top_color": [Color(0.90, 0.88, 0.80), Color(0.80, 0.62, 0.20), Color(0.16, 0.42, 0.44), Color(0.66, 0.14, 0.12), Color(0.68, 0.36, 0.18)],
			"legs_color": [Color(0.82, 0.76, 0.62), Color(0.62, 0.52, 0.38), Color(0.18, 0.34, 0.20), Color(0.40, 0.28, 0.18), Color(0.66, 0.14, 0.12)],
			"sash_color": [Color(0.66, 0.14, 0.12), Color(0.80, 0.62, 0.20), Color(0.16, 0.42, 0.44), Color(0.36, 0.20, 0.44)],
			"hat_color": [Color(0.66, 0.14, 0.12), Color(0.80, 0.62, 0.20), Color(0.16, 0.42, 0.44)]},
		"set": {"coat": "none", "vest": "none", "eyepatch": false, "gloves": false, "scarf": false},
	},
	"music": "island",
	"ambience": "jungle",
	"weather": [0.3, 0.56, 0.88],
	"haze": 0.15,
	# landmarks and set pieces (KitLandmarks, KitSetPieces): rock, carved stone, water, bone, lava, crystal
	"rock_tint": Color(0.62, 0.62, 0.55),
	"moss_tint": Color(0.5, 0.64, 0.4),
	"temple_stone": Color(0.74, 0.76, 0.66),
	"fort_stone": Color(0.8, 0.78, 0.72),
	"water_tint": Color(0.3, 0.58, 0.55, 0.82),
	"falls_tint": Color(0.78, 0.9, 0.95, 0.85),
	"spring_tint": Color(0.55, 0.85, 0.82, 0.85),
	"travertine": Color(0.93, 0.88, 0.76),
	"wreck_hull": Color(0.55, 0.52, 0.46),
	"bone": Color(0.9, 0.86, 0.74),
	"basalt": Color(0.3, 0.29, 0.3),
	"lava": Color(1.0, 0.45, 0.12),
	"crystal": Color(0.4, 0.95, 0.85),
	"rust": Color(0.42, 0.32, 0.26),
}

## Each kind: its zones, how likely an island has it, how many groups (dens) when it does.
const FAUNA := {
	"boar": {"zones": ["floor"], "p": 0.6, "dens": [2, 5]},
	"leaper": {"zones": ["floor"], "p": 0.5, "dens": [2, 6]},
	"roller": {"zones": ["floor", "shore"], "p": 0.45, "dens": [2, 5]},
	"mite": {"zones": ["floor", "cave"], "p": 0.45, "dens": [1, 3]},
	"burrower": {"zones": ["floor", "shore"], "p": 0.4, "dens": [2, 5]},
	"bat": {"zones": ["canopy", "cave"], "p": 0.55, "dens": [2, 4]},
	"toucan": {"zones": ["canopy"], "p": 0.55, "dens": [3, 6]},
	"monkey": {"zones": ["canopy"], "p": 0.5, "dens": [1, 3]},
	"snake": {"zones": ["floor", "swamp"], "p": 0.55, "dens": [3, 8]},
	"crab": {"zones": ["shore"], "p": 0.6, "dens": [3, 6]},
}
const CREATURES := {
	"boar": "res://scripts/enemies/fauna/boar.gd",
	"leaper": "res://scripts/enemies/fauna/leaper_bug.gd",
	"roller": "res://scripts/enemies/fauna/roller_bug.gd",
	"mite": "res://scripts/enemies/fauna/swarm_mite.gd",
	"burrower": "res://scripts/enemies/fauna/burrower.gd",
	"bat": "res://scripts/enemies/fauna/bat.gd",
	"toucan": "res://scripts/enemies/fauna/toucan.gd",
	"monkey": "res://scripts/enemies/fauna/monkey.gd",
	"snake": "res://scripts/enemies/fauna/snake.gd",
	"crab": "res://scripts/enemies/fauna/crab.gd",
}


func _init() -> void:
	name = "jungle"
	display = "Jungle"
	blurb = "a steaming jungle isle"
	island_names = ["Verdant", "Kalani", "Mosswater", "Tambor", "Orchid", "Viper", "Greenmaw", "Tikal"]
	weight = 1.0
	color = Color(0.3, 0.88, 0.45)
	glyph = _glyph
	flocks = 2
	land = LAND
	radius = [300.0, 450.0]
	style = STYLE
	props = {
		"basket": func(rng: RandomNumberGenerator, size: float) -> Node3D: return JungleProps.basket(0.8 * size, rng.randi()),
		"pot": func(rng: RandomNumberGenerator, size: float) -> Node3D: return JungleProps.pot(size, rng.randi()),
		"torch_post": func(_rng: RandomNumberGenerator, size: float) -> Node3D: return JungleProps.torch_post(2.4 * size),
		"totem": func(rng: RandomNumberGenerator, _size: float) -> Node3D: return JungleProps.totem(rng.randi()),
	}
	life = preload("res://scripts/island/themes/jungle_life.gd").TEXT
	encounters = preload("res://scripts/island/themes/jungle_encounters.gd").TEXT
	bosses = ["ape", "serpent", "stalker", "mantis"]
	minis = ["boar"]
	roamers = ["behemoth"]
	beasts = {
		# (the ape is JungleApe, built by BeastArena itself; its body is stocked ahead with the villagers')
		"ape": {"script": "res://scripts/enemies/jungle_ape.gd", "names": ["The Silverback"], "looks": 1, "stock": func() -> Dictionary: return JungleApe.ape_look()},
		"serpent": {"script": "res://scripts/enemies/beasts/strangler.gd", "names": ["The Strangler", "Old Coil", "Mother of Vines"], "looks": 3},
		"stalker": {"script": "res://scripts/enemies/beasts/stalker.gd", "names": ["The Shade", "Nightmaw", "The Spotted Death"], "looks": 3},
		"mantis": {"script": "res://scripts/enemies/beasts/mantis_queen.gd", "names": ["The Mantis Queen", "The Orchid Queen", "The Leaf Queen"], "looks": 3},
		"boar": {"script": "res://scripts/enemies/beasts/alpha_boar.gd", "names": ["Tuskmaw", "Old Gristle", "Mudking", "Ironbristle"], "site": "ruins"},
		"behemoth": {"script": "res://scripts/enemies/beasts/behemoth.gd", "names": ["The Thornback", "Old Ironhide", "The Mossback"]},
	}
	fauna = FAUNA
	creatures = CREATURES
	cave_fauna = {"ceiling": "bat", "floor": ["mite", "burrower", "snake"]}


func meshes() -> Dictionary:
	return {
		"tree": [Props.jungle_tree_mesh(121), Props.jungle_tree_mesh(122), Props.jungle_tree_mesh(123), Props.jungle_tree_mesh(124)],
		"beach_tree": [Props.palm_mesh(111), Props.palm_mesh(112), Props.palm_mesh(113)],
		"bush": [Props.bush_mesh(131), Props.bush_mesh(132)],
		"fern": [Props.fern_mesh(141), Props.fern_mesh(142)],
		"grass": [Props.grass_mesh()],
		"rock": [Props.rock_mesh(151, 1.0), Props.rock_mesh(152, 1.0, true), Props.rock_mesh(153, 1.0, true)],
		# big trees: [body, detail, lean]
		"giant": [JunglePlants.canopy_tree(161), JunglePlants.canopy_tree(162)],
		"fig": [JunglePlants.canopy_tree(165, true)],
		"kapok": [JunglePlants.kapok_tree(175)],
		"emergent": [JunglePlants.emergent_tree(171), JunglePlants.emergent_tree(172)],
		"roof": [JunglePlants.canopy_roof(168)],
		"mangrove": [JunglePlants.mangrove_mesh(185)],
		"bamboo": [JunglePlants.bamboo_clump(181), JunglePlants.bamboo_clump(182)],
		"broadleaf": [JunglePlants.broadleaf_mesh(191), JunglePlants.broadleaf_mesh(192)],
		"shrub": [JunglePlants.shrub_mesh(195), JunglePlants.shrub_mesh(196)],
	}


## A palm: a leaning trunk and fronds drooping off its top.
static func _glyph(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	var top := p + Vector2(s * 0.3, -s * 0.6)
	ci.draw_line(p + Vector2(-s * 0.2, s), top, col, 1.0)
	for a in [-2.6, -1.9, -1.2, -0.5]:
		var tip := top + Vector2(cos(a), sin(a) + 0.9) * s * 0.75
		ci.draw_line(top, tip, col, 1.0)
