class_name FishTable
extends RefCounted
## What bites (v1.18 fishing): catches by rarity, common to legendary, each from some waters (shore: the shallows
## under the float off a beach or a pier; sea: open water; deep: nothing in reach under it, or deeper than DEEP_M),
## some only off an island theme's coasts, some only by day or by night. The fish are items tagged "fish" (any
## galley recipe takes them), worth more the rarer they are (the rarity is the item's tier: ItemData.worth), drawn
## on the line by FishModels. A few catches are the cook's own ingredients (crab, oysters, urchins).
## The roll: every catch that fits the water, the coast and the hour weighs WEIGHT[rarity] x rare^rarity (the rod,
## the bait and Fishing's Sea Lore), the legendary x Master Angler's odds on top; drawn from a stream seeded off
## the global rng, so a seeded run lands the same fish.

## Weight per rarity before the rare odds (ItemData.Rarity 0..4), and Fishing mastery for a catch of each.
const WEIGHT := [100.0, 40.0, 13.0, 3.5, 0.6]
const XP := [10, 16, 26, 40, 80]
## Under the float deeper than SEA_M is "sea"; nothing in reach (or deeper than DEEP_M) is "deep".
const SEA_M := 4.0
const DEEP_M := 30.0
## item id -> [name, rarity, value, waters, theme ("" any), time ("" any, "day", "night"), shape, length m, body, fins,
## description] (name "" = an ingredient that already exists).
const CATCHES := {
	"fish_sardine": ["Sardine", 0, 2, ["shore", "sea"], "", "", "slim", 0.2, Color(0.55, 0.65, 0.72), Color(0.4, 0.48, 0.55),
		"Small, silver and everywhere. Salt them or eat them fast."],
	"fish_mackerel": ["Mackerel", 0, 3, ["sea", "shore", "deep"], "", "", "slim", 0.34, Color(0.25, 0.42, 0.45), Color(0.2, 0.3, 0.32),
		"Striped green and quick. Oily, and good for it."],
	"fish_bream": ["Sea Bream", 0, 3, ["shore"], "", "day", "deep", 0.3, Color(0.72, 0.68, 0.6), Color(0.55, 0.45, 0.4),
		"A plate of a fish from the shallows. Grills well."],
	"crab_meat": ["", 0, 0, ["shore"], "", "", "flat", 0.2, Color(0.8, 0.3, 0.18), Color(0.6, 0.2, 0.12), ""],
	"fish_snapper": ["Red Snapper", 1, 5, ["sea", "shore"], "", "", "deep", 0.42, Color(0.8, 0.3, 0.25), Color(0.65, 0.22, 0.18),
		"Rose-red and firm. A cook's favourite."],
	"fish_flounder": ["Flounder", 1, 5, ["shore"], "", "", "flat", 0.4, Color(0.5, 0.42, 0.32), Color(0.4, 0.34, 0.26),
		"Lies flat on the sand with both eyes looking up at you."],
	"fish_bass": ["Sea Bass", 1, 6, ["sea", "shore"], "", "night", "slim", 0.5, Color(0.35, 0.4, 0.45), Color(0.25, 0.28, 0.32),
		"Hunts the dark water. Bites best after sundown."],
	"oyster": ["", 1, 0, ["shore"], "", "", "flat", 0.12, Color(0.6, 0.58, 0.55), Color(0.4, 0.38, 0.36), ""],
	"fish_parrotfish": ["Parrotfish", 1, 6, ["shore", "sea"], "jungle", "day", "deep", 0.4, Color(0.25, 0.75, 0.6), Color(0.85, 0.45, 0.6),
		"Beaked and painted like a carnival. It chews coral."],
	"fish_grouper": ["Sand Grouper", 1, 6, ["shore", "sea"], "desert", "", "deep", 0.5, Color(0.78, 0.66, 0.42), Color(0.62, 0.5, 0.3),
		"The colour of the dunes, and as patient."],
	"fish_ice_cod": ["Ice Cod", 1, 6, ["sea", "shore"], "snow", "", "slim", 0.55, Color(0.72, 0.8, 0.86), Color(0.5, 0.6, 0.7),
		"Thrives in water that would stop your heart."],
	"fish_trout": ["Sea Trout", 1, 6, ["shore"], "forest", "", "slim", 0.45, Color(0.5, 0.52, 0.4), Color(0.62, 0.4, 0.35),
		"Comes in on the tide where the forest rivers meet the sea."],
	"sea_urchin": ["", 2, 0, ["shore"], "", "", "deep", 0.12, Color(0.25, 0.12, 0.3), Color(0.15, 0.08, 0.2), ""],
	"fish_tuna": ["Bluefin Tuna", 2, 9, ["sea", "deep"], "", "", "slim", 0.9, Color(0.15, 0.22, 0.4), Color(0.78, 0.7, 0.3),
		"A torpedo of a fish. It'll pull you off your feet."],
	"fish_swordfish": ["Swordfish", 2, 10, ["deep"], "", "day", "long", 1.2, Color(0.25, 0.3, 0.42), Color(0.2, 0.24, 0.34),
		"Its bill is sharper than some cutlasses."],
	"fish_moonfish": ["Moonfish", 2, 9, ["sea", "deep"], "", "night", "deep", 0.55, Color(0.86, 0.86, 0.92), Color(0.7, 0.55, 0.75),
		"Round, pale and shining. It only rises when the moon does."],
	"fish_lionfish": ["Lionfish", 2, 9, ["shore", "sea"], "jungle", "", "deep", 0.35, Color(0.82, 0.4, 0.3), Color(0.95, 0.86, 0.76),
		"Mind the spines. Delicious once you're past them."],
	"fish_ghost_ray": ["Ghost Ray", 3, 14, ["deep", "sea"], "", "night", "flat", 1.0, Color(0.82, 0.86, 0.9), Color(0.65, 0.72, 0.8),
		"A pale ray that glides like a sheet in the wind. Sailors call it bad luck."],
	"fish_golden_carp": ["Golden Sea Carp", 3, 14, ["shore", "sea"], "", "day", "deep", 0.6, Color(0.95, 0.75, 0.25), Color(0.95, 0.55, 0.2),
		"Scales like coins. Some say it brings fortune; it certainly fetches gold."],
	"fish_king_marlin": ["King Marlin", 4, 22, ["deep"], "", "", "long", 1.8, Color(0.12, 0.2, 0.45), Color(0.3, 0.55, 0.85),
		"The king of the open sea. Landing one is a story for the rest of your life."],
	"fish_abyss_eel": ["Abyss Eel", 4, 22, ["deep", "sea"], "", "night", "long", 1.6, Color(0.12, 0.08, 0.15), Color(0.5, 0.2, 0.7),
		"Comes up from where the light ends, its eyes aglow. Nobody knows how deep it lives."],
}
## The first legendary a captain lands teaches this galley recipe (Food.MEALS).
const LEGEND_RECIPE := "sea_legend"

static var _icons: Dictionary = {}


static func rarity_of(id: String) -> int:
	return int(CATCHES[id][1])


## [shape, length m, body, fins] (FishModels.fish).
static func look_of(id: String) -> Array:
	var c: Array = CATCHES[id]
	return [c[6], c[7], c[8], c[9]]


## (ItemDB._load_all) the new fish into the item table: raw ingredients tagged fish, their rarity their tier.
static func make_items(items: Dictionary) -> void:
	for id in CATCHES.keys():
		var c: Array = CATCHES[id]
		if str(c[0]) == "":
			continue
		var it := ItemData.new()
		it.id = id
		it.display_name = str(c[0])
		it.rarity = int(c[1]) as ItemData.Rarity
		it.value = int(c[2])
		it.description = str(c[10])
		it.item_type = ItemData.ItemType.LOOT
		it.ingredient = "fish"
		it.max_stack = 20
		it.icon_kind = "fish"
		it.icon = icon(id)
		items[id] = it


static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var lk := look_of(id)
		_icons[id] = WeaponDesigns.mesh_icon(FishModels.fish(str(lk[0]), float(lk[1]), lk[2], lk[3]), Basis(), -0.35)
	return _icons[id]


## The water under a float at `spot` (the calm sea level): "shore", "sea" or "deep".
static func water_at(tree: SceneTree, spot: Vector3) -> String:
	var d: float = tree.root.get_node("Ocean").depth_at(spot, [], true)
	if d == INF or d > DEEP_M:
		return "deep"
	return "sea" if d > SEA_M else "shore"


## The coast's theme there ("" off Brinehollow, on the light stage and far out at sea).
static func theme_at(tree: SceneTree, spot: Vector3) -> String:
	var wg := tree.get_first_node_in_group("world_gen")
	if wg == null or not ("chain_islands" in wg):
		return ""
	# (loaded, not named: ItemDB names this class, and test scripts name ItemDB before the autoloads exist)
	var t: Array = load("res://scripts/island/kit/kit_style.gd").around(tree, spot)
	return "" if float(t[1]) <= 0.0 or str(t[0]) == "brinehollow" else str(t[0])


## The catches that can bite in `water` off a `theme` coast, by night or day.
static func pool(water: String, theme: String, night: bool) -> Array:
	var out: Array = []
	for id in CATCHES.keys():
		var c: Array = CATCHES[id]
		if water in c[3] and (c[4] == "" or c[4] == theme) and (c[5] == "" or (c[5] == "night") == night):
			out.append(id)
	return out


## One catch from `ids`, the rarer weighted up by `rare` (and the legendary by `legend` on top), from `rng`.
static func roll(ids: Array, rare: float, legend: float, rng: RandomNumberGenerator) -> String:
	var ws: Array = []
	var total := 0.0
	for id in ids:
		var r := rarity_of(id)
		var w: float = WEIGHT[r] * pow(rare, r) * (legend if r == 4 else 1.0)
		ws.append(w)
		total += w
	var x := rng.randf() * total
	for i in range(ids.size()):
		x -= float(ws[i])
		if x <= 0.0:
			return ids[i]
	return ids[ids.size() - 1]
