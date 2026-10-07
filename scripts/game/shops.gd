extends RefCounted
## Brinehollow's traders (ShopScreen; the NPC's "shop" or a dialogue event
## "shop:<id>"). Each: a name, a line, what's for sale ([item id, price] or
## [gear slot, style, look, price]) and what they'll buy (item kind -> the
## share of its value they pay; gold and things worth nothing aren't bought).

const SHOPS := {
	"nessa": {
		"name": "Nessa's Notions", "line": "Sea-gems at full price. Nobody on this island pays better.",
		"stock": [["rum", 9], ["biscuit", 3],
			["accessory", "earring", {"earring": true}, 40],
			["accessory", "eyepatch", {"eyepatch": true}, 25],
			["accessory", "pouch", {"pouch": true}, 30]],
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
		"name": "Sela's Cloth", "line": "Sailcloth, silk and wool. Wear it like you mean it.",
		"stock": [
			["head", "tricorn", {"hat": "tricorn", "hat_color": Color(0.1, 0.09, 0.09)}, 45],
			["head", "bicorne", {"hat": "bicorne", "hat_color": Color(0.14, 0.18, 0.34)}, 55],
			["head", "bandana", {"hat": "bandana", "hat_color": Color(0.66, 0.14, 0.12)}, 15],
			["coat", "longcoat", {"coat": "longcoat", "coat_color": Color(0.36, 0.12, 0.1), "trim_color": Color(0.85, 0.7, 0.3)}, 90],
			["coat", "captain", {"coat": "captain", "coat_color": Color(0.14, 0.18, 0.34), "trim_color": Color(0.9, 0.75, 0.3)}, 160],
			["vest", "vest", {"vest": "vest", "vest_color": Color(0.16, 0.42, 0.44)}, 30],
			["feet", "tall_boots", {"feet": "tall_boots", "feet_color": Color(0.1, 0.09, 0.09)}, 40],
			["belt", "sash", {"belt": "sash", "sash_color": Color(0.66, 0.14, 0.12)}, 20],
			["accessory", "scarf", {"scarf": true, "scarf_color": Color(0.8, 0.62, 0.2)}, 18]],
		"buys": {"gear": 0.6},
	},
	"ida": {
		"name": "Old Ida's Pots", "line": "Hardtack in a jar. Lasts longer than you will.",
		"stock": [["biscuit", 3], ["rum", 10]],
		"buys": {},
	},
	"vey": {
		"name": "Vey's Armoury", "line": "Steel that's seen the Grand Patrol. Treat it better than I did.",
		"stock": [["cutlass", 45], ["boarding_axe", 70], ["pistol", 90], ["katana", 160]],
		"buys": {"weapon": 0.5},
	},
}

const KINDS := ["loot", "weapon", "consumable", "gear"]


## What a shop's stock entry is as an item (gear is made to order).
static func item_of(entry: Array) -> ItemData:
	if entry.size() == 2:
		return ItemDB.get_item(str(entry[0]))
	return Gear.make(str(entry[0]), str(entry[1]), entry[2])


static func price_of(entry: Array) -> int:
	return int(entry[entry.size() - 1])


## What a shop pays for one `item` (0: it won't buy it).
static func offer(shop_id: String, item: ItemData) -> int:
	if item == null or item.id == "gold" or item.value <= 0:
		return 0
	var rate: float = float((SHOPS[shop_id]["buys"] as Dictionary).get(KINDS[int(item.item_type)], 0.0))
	return maxi(int(floor(item.value * rate)), 1) if rate > 0.0 else 0
