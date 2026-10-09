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

const DEFS := {
	"jungle": {
		"peak": [24.0, 36.0], "hills": [2, 4], "hill_h": [6.0, 14.0], "roll": 3.0, "base": 4.4,
		"ramp": [38.0, 62.0], "cliffs": [1, 2], "cliff_h": [7.0, 12.0],
		"tree": 0.62, "edge": 0.07, "beach_tree": 0.3, "fern": 0.32, "bush": 0.16, "grass": 0.3, "rock": 0.025,
		"cover": 0.7,
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
				}
	return _meshes[theme]
