extends RefCounted
## Brinehollow's traders (ShopScreen; the NPC's "shop" or a dialogue event
## "shop:<id>"). Each: a name, a line, what's for sale ([item id, price] -
## "<id>@<tier>" for another tier - or [gear slot, style, look, tier, price])
## and what they'll buy (item kind -> the share of its worth they pay; gold
## and things worth nothing aren't bought).

const SHOPS := {
	"nessa": {
		"name": "Nessa's Notions", "line": "Sea-gems at full price. Nobody on this island pays better.",
		"stock": [["rum", 9], ["biscuit", 3],
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
	"marlo": {
		"name": "Marlo's Fish", "line": "Grilled while you wait. Mostly while you wait.",
		"stock": [["fish", 5]],
		"buys": {},
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
			["accessory", "cape", {"cape": true, "cape_color": Color(0.14, 0.18, 0.34)}, 0, 60],
			["accessory", "bandolier", {"bandolier": true}, 0, 35],
			["legs", "breeches", {"legs": "breeches", "legs_color": Color(0.9, 0.88, 0.8)}, 0, 30],
			["feet", "tall_boots", {"feet": "tall_boots", "feet_color": Color(0.1, 0.09, 0.09)}, 1, 70],
			["belt", "sash", {"belt": "sash", "sash_color": Color(0.66, 0.14, 0.12)}, 0, 20],
			["accessory", "pauldron", {"pauldron": true}, 1, 80],
			["accessory", "scarf", {"scarf": true, "scarf_color": Color(0.8, 0.62, 0.2)}, 0, 18]],
		"buys": {"gear": 0.6},
	},
	"ida": {
		"name": "Old Ida's Pots", "line": "Hardtack in a jar. Lasts longer than you will.",
		"stock": [["biscuit", 3], ["rum", 10]],
		"buys": {},
	},
	"vey": {
		"name": "Vey's Armoury", "line": "Steel to carry and steel to wear. I'll buy your spares, too.",
		"stock": [["cutlass", 45], ["hunting_hanger", 40], ["naval_sabre", 70], ["hatchet", 30], ["boarding_axe", 70],
			["pistol", 90], ["duelling_pistol", 130], ["wakizashi", 120],
			["scimitar@1", 140], ["bearded_axe@1", 160], ["cutlass@1", 110], ["katana", 180],
			["head", "morion", {"hat": "morion"}, 0, 90],
			["vest", "brigandine", {"vest": "brigandine", "vest_color": Color(0.4, 0.26, 0.14)}, 0, 110],
			["vest", "mail", {"vest": "mail"}, 0, 120],
			["vest", "cuirass", {"vest": "cuirass", "vest_color": Color(0.55, 0.55, 0.58)}, 1, 260],
			["hands", "gauntlets", {"gloves": true, "gloves_color": Color(0.1, 0.08, 0.07), "gauntlets": true}, 0, 70],
			["feet", "greaves", {"feet": "greaves", "feet_color": Color(0.1, 0.08, 0.07)}, 1, 150]],
		"buys": {"weapon": 0.6, "gear": 0.5},
	},
}

const KINDS := ["loot", "weapon", "consumable", "gear"]


## What a shop's stock entry is as an item (gear is made to order).
static func item_of(entry: Array) -> ItemData:
	if entry.size() == 2:
		return ItemDB.get_item(str(entry[0]))
	return Gear.make(str(entry[0]), str(entry[1]), entry[2], "", int(entry[3]))


static func price_of(entry: Array) -> int:
	return int(entry[entry.size() - 1])


## What a shop pays for one `item` (0: it won't buy it).
static func offer(shop_id: String, item: ItemData) -> int:
	if item == null or item.id == "gold" or item.value <= 0:
		return 0
	var rate: float = float((SHOPS[shop_id]["buys"] as Dictionary).get(KINDS[int(item.item_type)], 0.0))
	return maxi(int(floor(item.worth() * rate)), 1) if rate > 0.0 else 0
