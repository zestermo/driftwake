class_name CanalStyle
extends RefCounted
## The canal city's own style over the capital's (KitStyle.of("canal")): faded brick and coloured plaster under
## terracotta, warm lamps, working people (shipwrights, boatmen, porters, merchants) in rolled sleeves and aprons as
## much as good coats. Not a theme: the same city in every world (docs/v1_21_plan.md).

static var STYLE: Dictionary = CapitalStyle.STYLE.merged({
	"lamp": Color(1.0, 0.74, 0.42),
	"pennants": [Color(0.62, 0.16, 0.14), Color(0.92, 0.74, 0.22), Color(0.24, 0.42, 0.34), Color(0.95, 0.92, 0.86)],
	"goods": [Color(0.86, 0.5, 0.2), Color(0.7, 0.16, 0.2), Color(0.95, 0.8, 0.3), Color(0.36, 0.56, 0.3), Color(0.34, 0.4, 0.62)],
	"folk": {
		"pick": {"hat": ["none", "none", "cap", "cap", "straw", "tricorn"], "top": ["shirt", "shirt", "tunic", "doublet"], "top_fem": ["blouse", "blouse", "tunic"],
			"sleeves": ["short", "long", "short"], "vest": ["none", "vest", "jerkin", "jerkin"], "coat": ["none", "none", "none", "jacket"],
			"legs": ["trousers", "slops", "breeches"], "legs_fem": ["skirt", "skirt", "trousers"], "feet": ["boots", "shoes", "boots"],
			"belt": ["belt", "sash", "belt_sash"],
			"top_color": [Color(0.94, 0.9, 0.82), Color(0.56, 0.22, 0.18), Color(0.3, 0.42, 0.56), Color(0.82, 0.66, 0.36), Color(0.36, 0.48, 0.34), Color(0.88, 0.8, 0.66)],
			"legs_color": [Color(0.3, 0.24, 0.18), Color(0.2, 0.2, 0.24), Color(0.5, 0.4, 0.3), Color(0.24, 0.26, 0.36)]},
		"set": {"eyepatch": false, "gloves": false},
	},
	"music": "island",
	"music_town": "village",
}, true)
