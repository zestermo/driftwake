class_name KitStyle
extends RefCounted
## How a settlement looks, by theme: the kit pieces read their materials, palettes
## and lamp colours from here (KitContext.style, KitStyle.of(theme)) instead of
## literals. Brinehollow's timber-and-stone harbour town is the base style and has
## every key; a theme's table replaces whole keys of it (nested tables too), so a
## new theme is a const like JUNGLE plus a line in STYLES.

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

	# the material palette: the texture each part is made of (PSXMat shares one material per texture)
	"mat": {"wall": "planks", "beam": "planks_dark", "floor": "planks", "deck": "planks_weathered", "post": "planks_dark",
		"rail": "planks_dark", "roof": "roof_tiles", "thatch": "thatch", "rope": "rope", "stone": "stone_brick", "cloth": "canvas",
		"weave": "straw"},
	# a settlement's houses (KitStyle.house_spec rolls a Buildings.house spec from it):
	# pools to pick from, [lo, hi] ranges, chances (0..1) and fixed values
	"house": {"w": [5.0, 7.0], "d": [4.0, 5.5], "h": [2.4, 2.8], "walls": ["plaster", "planks", "planks_weathered", "stone_brick"],
		"roofs": ["gable_front", "gable", "hip"], "roof_tex": ["roof_tiles", "roof_tiles", "thatch"], "pitch": [0.42, 0.5], "eaves": 0.5,
		"beam": "planks_dark", "floor": "planks", "poles": false, "lashings": false, "stilts": false,
		"porch": [0.3, 1.2, 1.8], "flowers": 0.65, "chimney": 0.4,
		"trims": [Color(0.27, 0.42, 0.62), Color(0.25, 0.5, 0.44), Color(0.6, 0.22, 0.16), Color(0.78, 0.62, 0.26), Color(0.86, 0.85, 0.8), Color(0.35, 0.3, 0.45)]},
	# the inn: what it changes from a rolled house
	"inn": {"w": 8.0, "d": 6.0, "h": 2.8, "roof": "hip", "wall": "planks_weathered", "porch": 2.0, "flowers": false},
	# market stalls: their canopies (texture names) and posts
	"stall": {"canopies": ["cloth_red", "cloth_blue", "canvas"], "post": "planks_dark"},
	# a timber pier: deck, posts (round "poles" or square), rails, rope lashed at the deck, a rope rail
	"pier": {"deck": "planks_weathered", "post": "planks_dark", "rail": "planks_dark", "lashings": false, "rope_rail": false},
	# the props a kit asks for by slot, and the model each style makes for it (KitStyle.prop)
	"props": {"crate": "crate", "barrel": "barrel", "lamp": "lantern_post", "marker": "notice_board"},
	# its people (KitStyle.folk_look): pools a villager's look picks from ("<key>_fem" for women), then fixed values
	"folk": {
		"pick": {"hat": ["none", "none", "cap", "knit", "bandana"], "top": ["shirt", "shirt", "tunic"], "top_fem": ["blouse", "shirt", "tunic"],
			"sleeves": ["long", "short"], "legs": ["trousers", "breeches"], "legs_fem": ["skirt", "trousers"], "feet": ["boots", "shoes"],
			"belt": ["belt", "belt", "none"],
			"top_color": [Color(0.90, 0.88, 0.80), Color(0.82, 0.76, 0.62), Color(0.20, 0.32, 0.62), Color(0.55, 0.55, 0.55), Color(0.66, 0.14, 0.12)],
			"legs_color": [Color(0.40, 0.28, 0.18), Color(0.24, 0.17, 0.12), Color(0.28, 0.28, 0.30), Color(0.14, 0.18, 0.34)]},
		"set": {"coat": "none", "eyepatch": false, "gloves": false},
	},
	# what you hear: Music's track on foot here (Music.TRACKS), Ambience's bed (Ambience.LOOPS; "" none)
	"music": "island",
	"ambience": "",
	# the weather here (Weather): where clear, cloudy and rain end on a 0..1 roll (the rest is storm), extra fog
	"weather": [0.36, 0.66, 0.86],
	"haze": 0.0,
}

## The jungle: stilt huts of bamboo and woven palm under steep palm-leaf thatch,
## rope-lashed posts, tiki torches, baskets and clay pots, a mossy green stone.
const JUNGLE := {
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
}

const STYLES := {"brinehollow": BRINEHOLLOW, "jungle": JUNGLE}
## How far past an island's radius its style still holds (blending out over it).
const REACH := 140.0


static func of(style_name: String) -> Dictionary:
	var st: Dictionary = BRINEHOLLOW.merged(STYLES[style_name], true)
	st.make_read_only()
	return st


static func get_style(style_name: String) -> Dictionary:
	return of(style_name)


static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


## A Buildings.house spec for one of the style's houses (merge your own over it: name, lantern...).
static func house_spec(st: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var h: Dictionary = st["house"]
	var porch: Array = h["porch"]
	return {"w": rng.randf_range(h["w"][0], h["w"][1]), "d": rng.randf_range(h["d"][0], h["d"][1]), "h": rng.randf_range(h["h"][0], h["h"][1]),
		"wall": _pick(rng, h["walls"]), "roof": _pick(rng, h["roofs"]), "roof_tex": _pick(rng, h["roof_tex"]),
		"pitch": rng.randf_range(h["pitch"][0], h["pitch"][1]), "eaves": h["eaves"], "beam": h["beam"], "floor": h["floor"],
		"poles": h["poles"], "lashings": h["lashings"],
		"porch": rng.randf_range(porch[1], porch[2]) if rng.randf() < float(porch[0]) else 0.0,
		"flowers": rng.randf() < float(h["flowers"]), "chimney": rng.randf() < float(h["chimney"]),
		"trim": _pick(rng, h["trims"]), "seed": rng.randi()}


## The style's model for a kit's prop slot ("crate", "barrel", "lamp", "marker"). A
## lamp has a "Flame" marker where its light goes.
static func prop(st: Dictionary, slot: String, rng: RandomNumberGenerator, size := 1.0) -> Node3D:
	match str(st["props"][slot]):
		"crate":
			return Props.crate(0.8 * size)
		"barrel":
			return Props.barrel()
		"lantern_post":
			var post := Props.lantern_post(2.4 * size)
			var m := Marker3D.new()
			m.name = "Flame"
			m.position = Vector3(0.55, 2.4 * size - 0.2, 0)
			post.add_child(m)
			return post
		"notice_board":
			return KitVillage.notice_board(rng)
		"basket":
			return JungleProps.basket(0.8 * size, rng.randi())
		"pot":
			return JungleProps.pot(size, rng.randi())
		"torch_post":
			return JungleProps.torch_post(2.4 * size)
		"totem":
			return JungleProps.totem(rng.randi())
	push_error("KitStyle: no prop %s" % st["props"][slot])
	return null


## A villager of the style: CharacterLook.random_look, then the style's pools and fixed values.
static func folk_look(st: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var lk := CharacterLook.random_look(rng)
	var pools: Dictionary = st["folk"]["pick"]
	var fem: bool = lk["body"] == "fem"
	for k in pools:
		if k.ends_with("_fem"):
			continue
		var pool: Array = pools[k + "_fem"] if fem and pools.has(k + "_fem") else pools[k]
		lk[k] = _pick(rng, pool)
	lk.merge(st["folk"]["set"], true)
	return lk


## Which style holds at world point `pos` and how strongly (1 on a themed island,
## fading to 0 over REACH past its coast): [style name, weight]. Home waters are Brinehollow's.
static func around(tree: SceneTree, pos: Vector3) -> Array:
	var wg := tree.get_first_node_in_group("world_gen")
	var best := ["brinehollow", 0.0]
	for isl in wg.chain_islands.values():
		var d := Vector2(pos.x - isl.position.x, pos.z - isl.position.z).length()
		var k := 1.0 - smoothstep(float(isl.radius), float(isl.radius) + REACH, d)
		if k > float(best[1]):
			best = [str(isl.theme), k]
	return best
