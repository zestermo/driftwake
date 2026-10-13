class_name IslandTheme
extends RefCounted
## How a theme's islands are made (GenIsland): the land's shape and the plants
## and rocks on it. The chain only rolls themes that have an entry here.
##
## Land: "peak" the main summit's height, "hills" how many and how high,
## "roll" the inland swell, "base" the height where the beach ramp levels off,
## "ramp" the beach ramp's width, "cliffs" how many stretches of coast drop
## sheer (with "cliff_h", their top). Plants (chances per grid cell):
## "tree" in the thick of it, "edge" where the cover thins, "beach_tree" on
## the sand, "fern"/"bush"/"grass" undergrowth, "rock" scattered boulders;
## "cover" how much of the inland is overgrown (0..1, the rest clearings).
## The canopy: "canopy" the chance of a big tree per 10 m cell in the thick of
## it, "giants" what kind ({mesh list: weight}: canopy trees, strangler figs,
## kapoks, emergents); "bamboo" clumps and "palm_inland" palms (5 m grid, in the
## cover), "mangrove" at the waterline. The floor: "broadleaf" big-leaved plants,
## "shrub" understory trees, "floor" a second layer of ferns and grass under thick
## cover, "overgrown" how much of that grows on the trails (the dock road stays
## clear). "forests": [name, overrides] - each island grows one, picked from its seed.

const DEFS := {
	"jungle": {
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
	},
}


static func has(theme: String) -> bool:
	return DEFS.has(theme)


static func def(theme: String) -> Dictionary:
	return DEFS[theme]


## The meshes a theme's islands use, built once per theme.
static var _meshes := {}


static func meshes(theme: String) -> Dictionary:
	if not _meshes.has(theme):
		match theme:
			"jungle":
				_meshes[theme] = {
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
	return _meshes[theme]
