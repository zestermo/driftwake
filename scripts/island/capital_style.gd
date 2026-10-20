class_name CapitalStyle
extends RefCounted
## The royal capital's own style over Brinehollow's (KitStyle.of("capital")): white limestone and lime-washed
## plaster under terracotta, royal blue and gold, townsfolk in their good clothes. Not a theme: the capital is
## the same in every world whatever theme its chain node rolled (docs/capital_plan.md).

const STYLE := {
	"lamp": Color(1.0, 0.8, 0.5),
	"lamp_range": 11.0,
	"paving": "capital_slabs",
	"quay_wall": Color(0.93, 0.9, 0.84),
	"quay_cope": Color(0.84, 0.8, 0.74),
	"row_walls": ["plaster_wash", "limestone", "plaster_wash", "plaster", "plaster_wash"],
	"row_upper": ["plaster_wash", "plaster", "limestone"],
	"row_awnings": ["blue", "red", "gold", "", "green", "blue", ""],
	"row_roof_tex": ["roof_tiles", 1.0, "roof_tiles"],
	"pennants": [Color(0.16, 0.24, 0.58), Color(0.92, 0.74, 0.22), Color(0.95, 0.93, 0.88), Color(0.68, 0.16, 0.14)],
	"goods": [Color(0.92, 0.6, 0.12), Color(0.8, 0.14, 0.18), Color(0.95, 0.85, 0.25), Color(0.4, 0.62, 0.22), Color(0.5, 0.3, 0.6)],
	"mat": {"wall": "plaster_wash", "beam": "planks_dark", "floor": "planks", "deck": "planks_weathered", "post": "limestone",
		"rail": "metal", "roof": "roof_tiles", "thatch": "roof_tiles", "rope": "rope", "stone": "limestone", "cloth": "canvas",
		"weave": "straw"},
	"house": {"w": [6.0, 9.0], "d": [6.0, 8.0], "h": [3.0, 3.4], "walls": ["plaster_wash", "plaster_wash", "plaster", "limestone"],
		"roofs": ["hip", "gable", "gable_front"], "roof_tex": ["roof_tiles"], "pitch": [0.32, 0.4], "eaves": 0.45,
		"beam": "planks_dark", "floor": "planks", "poles": false, "lashings": false, "stilts": false,
		"porch": [0.0, 1.2, 1.8], "flowers": 0.8, "chimney": 0.3,
		"trims": [Color(0.16, 0.26, 0.56), Color(0.2, 0.42, 0.36), Color(0.62, 0.2, 0.14), Color(0.8, 0.62, 0.24), Color(0.3, 0.3, 0.34)]},
	"inn": {"w": 12.0, "d": 9.0, "h": 3.4, "roof": "hip", "wall": "plaster_wash", "porch": 0.0, "flowers": true},
	"stall": {"canopies": ["awning_blue", "awning_red", "awning_gold", "awning_green"], "post": "planks_dark"},
	"folk": {
		"pick": {"hat": ["none", "none", "none", "cap", "tricorn", "straw"], "top": ["shirt", "tunic", "doublet"], "top_fem": ["blouse", "blouse", "tunic"],
			"sleeves": ["long", "long", "short"], "vest": ["none", "none", "vest", "jerkin"], "coat": ["none", "none", "none", "jacket", "frock"],
			"legs": ["trousers", "breeches"], "legs_fem": ["skirt", "skirt", "trousers"], "feet": ["boots", "shoes", "tall_boots"],
			"belt": ["belt", "sash", "belt_sash"],
			"top_color": [Color(0.94, 0.92, 0.86), Color(0.18, 0.26, 0.56), Color(0.62, 0.16, 0.16), Color(0.82, 0.68, 0.32), Color(0.3, 0.46, 0.4), Color(0.48, 0.32, 0.5)],
			"legs_color": [Color(0.3, 0.24, 0.18), Color(0.16, 0.16, 0.2), Color(0.86, 0.82, 0.72), Color(0.18, 0.22, 0.38)]},
		"set": {"eyepatch": false, "gloves": false},
	},
	"music": "island",
	"music_town": "village",
	"ambience": "",
	"high_birds": "dark",
	"ambient_bugs": false,
	"weather": [0.5, 0.78, 0.92],
	"haze": 0.0,
}
