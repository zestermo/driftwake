class_name KitStyle
extends RefCounted
## How a settlement looks, by theme: the kit pieces read their materials, palettes
## and lamp colours from here (KitContext.style) instead of literals. Brinehollow's
## timber-and-stone harbour town is the first style; a theme's style overrides it.

const BRINEHOLLOW := {
	# lamp posts: the flame's colour and reach (energy is the piece's)
	"lamp": Color(1.0, 0.75, 0.42),
	"lamp_range": 10.0,
	# paving and the quay
	"paving": "cobbles",
	"quay_wall": Color(0.85, 0.82, 0.76),
	"quay_cope": Color(0.7, 0.68, 0.64),
	"iron": Color(0.22, 0.22, 0.24),
	# houses along a waterfront: walls by position, upper storeys, roofs, awnings by position
	"row_walls": ["plaster", "planks", "planks_weathered", "stone_brick", "plaster"],
	"row_upper": ["plaster", "planks", "planks_weathered"],
	"row_roofs": ["gable_front", "gable_front", "gable", "hip", "gable_front"],
	"row_awnings": ["red", "blue", "green", "", "red", "", "blue"],
	# [the tiled roof's texture, its share, the other roof]
	"row_roof_tex": ["roof_tiles", 0.6, "thatch"],
	# textiles
	"pennants": [Color(0.8, 0.18, 0.15), Color(0.95, 0.8, 0.25), Color(0.2, 0.42, 0.7), Color(0.92, 0.9, 0.84), Color(0.25, 0.55, 0.35)],
	"washing": [Color(0.92, 0.9, 0.85), Color(0.6, 0.72, 0.85), Color(0.8, 0.4, 0.32), Color(0.85, 0.8, 0.55), Color(0.55, 0.65, 0.5)],
	"rugs": [["cloth_red", Color(0.9, 0.8, 0.75)], ["cloth_blue", Color(0.9, 0.9, 0.85)]],
	"goods": [Color(0.9, 0.55, 0.1), Color(0.85, 0.15, 0.12), Color(0.95, 0.85, 0.2), Color(0.45, 0.7, 0.2), Color(0.55, 0.35, 0.2)],
	# camps: a castaway's canvas, pirates' patched canvas, their houses, their colours
	"tent": Color(0.9, 0.85, 0.7),
	"camp_tent": Color(0.62, 0.55, 0.45),
	"rough": {"flowers": false, "trim": Color(0.36, 0.34, 0.32)},
	"crew_flag": Color(0.75, 0.3, 0.28),
	"pirate_flag": Color(0.18, 0.16, 0.16),
}

## The jungle's changes to Brinehollow's style (phase 2's theme work grows this).
const JUNGLE := {
	"row_walls": ["planks", "planks_weathered", "planks"],
	"row_upper": ["planks", "planks_weathered"],
	"row_roofs": ["gable", "hip", "gable_front"],
	"row_roof_tex": ["thatch", 1.0, "thatch"],
	"lamp": Color(1.0, 0.72, 0.4),
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
}


static func get_style(style_name: String) -> Dictionary:
	match style_name:
		"brinehollow":
			return BRINEHOLLOW
		"jungle":
			return BRINEHOLLOW.merged(JUNGLE, true)
	push_error("KitStyle: no style %s" % style_name)
	return {}
