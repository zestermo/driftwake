extends RefCounted
## Brinehollow's traders (ShopScreen; the NPC's "shop" or a dialogue event
## "shop:<id>"). Each: a name, a line, what's for sale ([item id, price] -
## "<id>@<tier>" for another tier - or [gear slot, style, look, tier, price])
## and what they'll buy (item kind -> the share of its worth they pay; gold
## and things worth nothing aren't bought).

const SHOPS := {
	"nessa": {
		"name": "Nessa's Notions", "line": "Sea-gems at full price. Nobody on this island pays better.",
		"stock": [["rum", 9], ["biscuit", 3], ["tonic", 30],
			["accessory", "earring", {"earring": true}, 1, 40],
			["accessory", "eyepatch", {"eyepatch": true}, 0, 25],
			["accessory", "pouch", {"pouch": true}, 0, 30]],
		"buys": {"loot": 1.0, "gear": 0.5, "weapon": 0.5},
	},
	"gus": {
		"name": "The Salted Gull", "line": "Rum, stew, and a dry seat. Pick two.",
		"stock": [["rum", 8], ["stew", 18]],
		"buys": {"consumable": 0.4},
	},
	"corin": {
		"name": "Corin's Strings and Skins", "line": "Strings, skins and bellows. All in tune, give or take a gale.",
		"stock": [["tin_whistle", 35], ["bodhran", 60], ["concertina", 110], ["fiddle", 140], ["hurdy_gurdy", 175]],
		"buys": {},
	},
	"haldor": {
		"name": "Haldor's Forge", "line": "Every blade on the rack came out of that fire. I'll buy your spares, too.",
		"stock": [["cutlass", 45], ["hunting_hanger", 40], ["naval_sabre", 70], ["hatchet", 30], ["boarding_axe", 70],
			["pistol", 90], ["duelling_pistol", 130], ["wakizashi", 120],
			["dagger", 28], ["stiletto", 45], ["main_gauche", 60], ["kukri@1", 110],
			["scimitar@1", 140], ["bearded_axe@1", 160], ["cutlass@1", 110], ["katana", 180]],
		"buys": {"weapon": 0.6},
	},
	"marlo": {
		"name": "Marlo's Fish", "line": "Grilled while you wait. Mostly while you wait.",
		"stock": [["fish", 5], ["crab_meat", 5], ["seaweed", 3]],
		"buys": {"ingredient": 0.5},
	},
	"sela": {
		"name": "Sela's Clothier", "line": "Clothes and leathers. I'll take your old ones off your hands, too.",
		"stock": [
			["head", "bandana", {"hat": "bandana", "hat_color": Color(0.66, 0.14, 0.12)}, 0, 15],
			["head", "tricorn", {"hat": "tricorn", "hat_color": Color(0.1, 0.09, 0.09)}, 0, 45],
			["head", "bicorne", {"hat": "bicorne", "hat_color": Color(0.14, 0.18, 0.34)}, 1, 85],
			["coat", "jacket", {"coat": "jacket", "coat_color": Color(0.4, 0.28, 0.18), "trim_color": Color(0.62, 0.52, 0.38)}, 0, 50],
			["coat", "longcoat", {"coat": "longcoat", "coat_color": Color(0.36, 0.12, 0.1), "trim_color": Color(0.85, 0.7, 0.3)}, 0, 90],
			["coat", "captain", {"coat": "captain", "coat_color": Color(0.14, 0.18, 0.34), "trim_color": Color(0.9, 0.75, 0.3)}, 1, 190],
			["vest", "corset", {"vest": "corset", "vest_color": Color(0.24, 0.17, 0.12)}, 1, 70],
			["vest", "vest", {"vest": "vest", "vest_color": Color(0.16, 0.42, 0.44)}, 0, 30],
			["hands", "gloves", {"gloves": true, "gloves_color": Color(0.24, 0.17, 0.12)}, 0, 25],
			["head", "cavalier", {"hat": "cavalier", "hat_color": Color(0.36, 0.12, 0.1)}, 1, 95],
			["head", "turban", {"hat": "turban", "hat_color": Color(0.9, 0.88, 0.8)}, 0, 35],
			["coat", "greatcoat", {"coat": "greatcoat", "coat_color": Color(0.28, 0.28, 0.3), "trim_color": Color(0.75, 0.76, 0.78)}, 1, 200],
			["accessory", "cape", {"cape": true, "cape_color": Color(0.14, 0.18, 0.34), "cape_tatter": 0.15}, 0, 60],
			["accessory", "cloak", {"cloak": true, "cloak_color": Color(0.24, 0.17, 0.12)}, 1, 110],
			["accessory", "bandolier", {"bandolier": true}, 0, 35],
			["legs", "breeches", {"legs": "breeches", "legs_color": Color(0.9, 0.88, 0.8)}, 0, 30],
			["feet", "tall_boots", {"feet": "tall_boots", "feet_color": Color(0.1, 0.09, 0.09)}, 1, 70],
			["belt", "sash", {"belt": "sash", "sash_color": Color(0.66, 0.14, 0.12)}, 0, 20],
			["accessory", "pauldron", {"pauldron": true}, 1, 80],
			["accessory", "scarf", {"scarf": true, "scarf_color": Color(0.8, 0.62, 0.2)}, 0, 18],
			["head", "fez", {"hat": "fez", "hat_color": Color(0.66, 0.14, 0.12)}, 0, 20],
			["head", "headband", {"hat": "headband", "hat_color": Color(0.14, 0.18, 0.34)}, 0, 10],
			["torso", "doublet", {"top": "doublet", "sleeves": "long", "top_color": Color(0.18, 0.34, 0.2)}, 0, 40],
			["torso", "kimono", {"top": "kimono", "sleeves": "long", "top_color": Color(0.36, 0.2, 0.44)}, 0, 45],
			["vest", "jerkin", {"vest": "jerkin", "vest_color": Color(0.4, 0.26, 0.14)}, 0, 45],
			["vest", "padded", {"vest": "padded", "vest_color": Color(0.82, 0.76, 0.62)}, 0, 55],
			["coat", "haori", {"coat": "haori", "coat_color": Color(0.1, 0.09, 0.09), "trim_color": Color(0.92, 0.9, 0.84)}, 0, 80],
			["coat", "duster", {"coat": "duster", "coat_color": Color(0.42, 0.42, 0.2), "trim_color": Color(0.1, 0.09, 0.09)}, 1, 120],
			["coat", "frock", {"coat": "frock", "coat_color": Color(0.28, 0.28, 0.3), "trim_color": Color(0.75, 0.76, 0.78)}, 1, 160],
			["hands", "bracers", {"gloves": false, "gloves_color": Color(0.24, 0.15, 0.09), "bracers": true}, 0, 25],
			["hands", "long_gloves", {"gloves": true, "gloves_color": Color(0.1, 0.08, 0.07), "long_gloves": true}, 0, 40],
			["legs", "hakama", {"legs": "hakama", "legs_color": Color(0.14, 0.18, 0.34)}, 0, 35],
			["legs", "leathers", {"legs": "leathers", "legs_color": Color(0.4, 0.26, 0.14)}, 0, 40],
			["feet", "sandals", {"feet": "sandals", "feet_color": Color(0.4, 0.26, 0.14)}, 0, 12],
			["belt", "wide_belt", {"belt": "wide_belt", "belt_color": Color(0.1, 0.08, 0.07)}, 0, 25],
			["accessory", "necklace", {"necklace": true}, 0, 15],
			["accessory", "goggles", {"goggles": true}, 0, 30],
			["accessory", "mantle", {"mantle": true, "mantle_color": Color(0.4, 0.28, 0.18)}, 1, 75],
			["head", "slouch", {"hat": "slouch", "hat_color": Color(0.24, 0.17, 0.12)}, 1, 70],
			["torso", "striped", {"top": "striped", "sleeves": "short", "top_color": Color(0.9, 0.88, 0.8)}, 0, 18],
			["vest", "harness", {"vest": "harness", "vest_color": Color(0.24, 0.15, 0.09)}, 0, 35],
			["legs", "slops", {"legs": "slops", "legs_color": Color(0.82, 0.76, 0.62)}, 0, 22],
			["feet", "cavalier_boots", {"feet": "cavalier_boots", "feet_color": Color(0.1, 0.08, 0.07)}, 1, 95],
			["accessory", "baldric", {"baldric": true}, 1, 55]],
		"buys": {"gear": 0.6},
	},
	"ida": {
		"name": "Old Ida's Pots", "line": "Hardtack in a jar. Lasts longer than you will.",
		"stock": [["biscuit", 3], ["rum", 10], ["tonic", 32], ["rice", 3], ["flour", 3], ["salt", 3], ["pepper", 6], ["mushroom", 3]],
		"buys": {"ingredient": 0.5},
	},
	"vey": {
		"name": "Vey's Armoury", "line": "Steel to wear. Blades are Haldor's business; keeping you alive in them is mine.",
		"stock": [["head", "morion", {"hat": "morion"}, 0, 90],
			["vest", "brigandine", {"vest": "brigandine", "vest_color": Color(0.4, 0.26, 0.14)}, 0, 110],
			["vest", "mail", {"vest": "mail"}, 0, 120],
			["vest", "cuirass", {"vest": "cuirass", "vest_color": Color(0.55, 0.55, 0.58)}, 1, 260],
			["hands", "gauntlets", {"gloves": true, "gloves_color": Color(0.1, 0.08, 0.07), "gauntlets": true}, 0, 70],
			["feet", "greaves", {"feet": "greaves", "feet_color": Color(0.1, 0.08, 0.07)}, 1, 150],
			["head", "kettle", {"hat": "kettle"}, 0, 80],
			["head", "coif", {"hat": "coif"}, 0, 85],
			["vest", "scale", {"vest": "scale", "vest_color": Color(0.24, 0.15, 0.09)}, 1, 170],
			["feet", "sabatons", {"feet": "sabatons", "feet_color": Color(0.1, 0.08, 0.07)}, 0, 90],
			["head", "helm", {"hat": "helm"}, 1, 150]],
		"buys": {"gear": 0.5},
	},
}

const KINDS := ["loot", "weapon", "consumable", "gear"]

## Traders made in play (a chain island's village: IslandVillage), the same shape as SHOPS.
static var extra := {}


static func shop(id: String) -> Dictionary:
	return SHOPS[id] if SHOPS.has(id) else extra[id]


## What a shop's stock entry is as an item (gear is made to order).
static func item_of(entry: Array) -> ItemData:
	if entry.size() == 2:
		return ItemDB.get_item(str(entry[0]))
	return Gear.make(str(entry[0]), str(entry[1]), entry[2], "", int(entry[3]))


## On the economy's one curve (Economy.price; the number written in a stock entry is no longer read).
static func price_of(entry: Array) -> int:
	return Economy.price(item_of(entry))


## What a shop pays for one `item` (0: it won't buy it).
static func offer(shop_id: String, item: ItemData) -> int:
	if item == null or item.id == "gold" or item.value <= 0:
		return 0
	var rate: float = float((shop(shop_id)["buys"] as Dictionary).get(Economy.kind_of(item), 0.0))
	return maxi(int(floor(item.worth() * rate)), 1) if rate > 0.0 else 0
