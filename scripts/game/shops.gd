extends RefCounted
## The traders (ShopScreen; the NPC's "shop" or a dialogue event "shop:<id>"), v1.18: every shop is a trade
## (smith, armourer, tailor, grocer, cook, luthier, treasure merchant; an artisan in the wilds) with a short
## stock that turns over each day. Each: a name, a line, its "trade", its staples ("stock", always there),
## a "pool" it shows "size" of on any one day (stock_on: seeded by the shop and Weather.day(), so every
## crewmate sees the same), and what it buys (item kind, Economy.kind_of -> the share of its worth paid).
## A stock entry: [item id] ("<id>@<tier>", "<id>@<tier>+<trait>") or [gear slot, style, look, tier]; a
## number after it is an old price, no longer read (Economy prices everything). Blue and up only at a
## treasure merchant ("treasure": a weapon of their "tier" with its trait every day, rare gear on some).
## What a captain sells waits in the shop's buy-back row at what they paid until the day turns (sold_back).

const SHOPS := {
	"nessa": {
		"name": "Nessa's Notions", "line": "Sea-gems at full price. Nobody on this island pays better.", "trade": "treasure", "tier": 2,
		"stock": [["rum", 9], ["biscuit", 3], ["tonic", 30],
			["accessory", "earring", {"earring": true}, 1, 40],
			["accessory", "eyepatch", {"eyepatch": true}, 0, 25],
			["accessory", "pouch", {"pouch": true}, 0, 30]],
		"buys": {"loot": 1.0, "gear": 0.5, "weapon": 0.5},
	},
	"gus": {
		"name": "The Salted Gull", "line": "Rum, stew, and a dry seat. Pick two.", "trade": "cook",
		"stock": [["rum", 8], ["stew", 18]],
		"pool": [["fish_stew"], ["porridge"], ["peppered_boar"], ["island_skewers"]], "size": 1,
		"buys": {"consumable": 0.4},
	},
	"corin": {
		"name": "Corin's Strings and Skins", "line": "Strings, skins and bellows. All in tune, give or take a gale.", "trade": "luthier",
		"stock": [["tin_whistle", 35], ["bodhran", 60], ["concertina", 110], ["banjo", 120], ["fiddle", 140], ["hurdy_gurdy", 175]],
		"buys": {},
	},
	"haldor": {
		"name": "Haldor's Forge", "line": "Every blade on the rack came out of that fire. I'll buy your spares, too.", "trade": "smith",
		"stock": [["cutlass", 45], ["dagger", 28], ["pistol", 90], ["hatchet", 30]],
		"pool": [["hunting_hanger", 40], ["naval_sabre", 70], ["boarding_axe", 70], ["duelling_pistol", 130], ["wakizashi", 120],
			["stiletto", 45], ["main_gauche", 60], ["kukri@1", 110], ["scimitar@1", 140], ["bearded_axe@1", 160], ["cutlass@1", 110], ["katana", 180],
			["spear", 50], ["pitchfork", 25], ["trident", 95], ["naginata", 110], ["halberd@1", 170],
			["warhammer", 55], ["shipwrights_mallet", 22], ["kanabo", 100], ["maul@1", 180],
			["tomahawk", 40], ["reavers_axe@1", 150], ["ships_cleaver", 40],
			["greatsword", 170], ["claymore@1", 280], ["sawtooth_greatblade@1", 300],
			["musket"], ["boarding_carbine"], ["blunderbuss"], ["long_rifle@1"], ["fowling_piece@1"],
			["hand_cannon"], ["swivel_gun"], ["carronade@1"],
			["slingshot"], ["vine_slingshot"], ["bone_slingshot"], ["iron_slingshot@1"]],
		"size": 5,
		"buys": {"weapon": 0.6},
	},
	"marlo": {
		"name": "Marlo's Fish", "line": "Grilled while you wait. Mostly while you wait.", "trade": "grocer",
		"stock": [["fish", 5], ["rod_driftwood"], ["bait_worm"]],
		"pool": [["crab_meat"], ["seaweed"], ["oyster"], ["salt"], ["rod_bamboo"], ["bait_shrimp"]], "size": 2,
		"buys": {"ingredient": 0.5},
	},
	"sela": {
		"name": "Sela's Clothier", "line": "Clothes and leathers. I'll take your old ones off your hands, too.", "trade": "tailor", "size": 10,
		"stock": [
			["head", "bandana", {"hat": "bandana", "hat_color": Color(0.66, 0.14, 0.12)}, 0, 15],
			["head", "tricorn", {"hat": "tricorn", "hat_color": Color(0.1, 0.09, 0.09)}, 0, 45],
			["coat", "jacket", {"coat": "jacket", "coat_color": Color(0.4, 0.28, 0.18), "trim_color": Color(0.62, 0.52, 0.38)}, 0, 50],
			["coat", "captain", {"coat": "captain", "coat_color": Color(0.14, 0.18, 0.34), "trim_color": Color(0.9, 0.75, 0.3)}, 1, 190],
			["vest", "vest", {"vest": "vest", "vest_color": Color(0.16, 0.42, 0.44)}, 0, 30],
			["legs", "breeches", {"legs": "breeches", "legs_color": Color(0.9, 0.88, 0.8)}, 0, 30]],
		"pool": [
			["head", "bicorne", {"hat": "bicorne", "hat_color": Color(0.14, 0.18, 0.34)}, 1, 85],
			["coat", "longcoat", {"coat": "longcoat", "coat_color": Color(0.36, 0.12, 0.1), "trim_color": Color(0.85, 0.7, 0.3)}, 0, 90],
			["vest", "corset", {"vest": "corset", "vest_color": Color(0.24, 0.17, 0.12)}, 1, 70],
			["hands", "gloves", {"gloves": true, "gloves_color": Color(0.24, 0.17, 0.12)}, 0, 25],
			["head", "cavalier", {"hat": "cavalier", "hat_color": Color(0.36, 0.12, 0.1)}, 1, 95],
			["head", "turban", {"hat": "turban", "hat_color": Color(0.9, 0.88, 0.8)}, 0, 35],
			["coat", "greatcoat", {"coat": "greatcoat", "coat_color": Color(0.28, 0.28, 0.3), "trim_color": Color(0.75, 0.76, 0.78)}, 1, 200],
			["accessory", "cape", {"cape": true, "cape_color": Color(0.14, 0.18, 0.34), "cape_tatter": 0.15}, 0, 60],
			["accessory", "cloak", {"cloak": true, "cloak_color": Color(0.24, 0.17, 0.12)}, 1, 110],
			["accessory", "bandolier", {"bandolier": true}, 0, 35],
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
			["accessory", "baldric", {"baldric": true}, 1, 55],
			["coat", "bosun_coat", Gear.LOOKS["bosun_coat"][1], 1],
			["belt", "powder_belt", Gear.LOOKS["powder_belt"][1], 0],
			["accessory", "shark_tooth", Gear.LOOKS["shark_tooth"][1], 0]],
		"buys": {"gear": 0.6},
	},
	"ida": {
		"name": "Old Ida's Pots", "line": "Hardtack in a jar. Lasts longer than you will.", "trade": "grocer",
		"stock": [["biscuit", 3], ["rum", 10], ["rice", 3], ["salt", 3]],
		"pool": [["flour"], ["pepper"], ["mushroom"], ["tonic"], ["egg"], ["coconut"], ["bait_worm"]], "size": 3,
		"buys": {"ingredient": 0.5},
	},
	"vey": {
		"name": "Vey's Armoury", "line": "Steel to wear. Blades are Haldor's business; keeping you alive in them is mine.", "trade": "armourer",
		"stock": [["head", "kettle", {"hat": "kettle"}, 0, 80], ["feet", "sabatons", {"feet": "sabatons", "feet_color": Color(0.1, 0.08, 0.07)}, 0, 90]],
		"size": 4,
		"pool": [["head", "morion", {"hat": "morion"}, 0, 90],
			["vest", "brigandine", {"vest": "brigandine", "vest_color": Color(0.4, 0.26, 0.14)}, 0, 110],
			["vest", "mail", {"vest": "mail"}, 0, 120],
			["vest", "cuirass", {"vest": "cuirass", "vest_color": Color(0.55, 0.55, 0.58)}, 1, 260],
			["hands", "gauntlets", {"gloves": true, "gloves_color": Color(0.1, 0.08, 0.07), "gauntlets": true}, 0, 70],
			["feet", "greaves", {"feet": "greaves", "feet_color": Color(0.1, 0.08, 0.07)}, 1, 150],
			["head", "coif", {"hat": "coif"}, 0, 85],
			["vest", "scale", {"vest": "scale", "vest_color": Color(0.24, 0.15, 0.09)}, 1, 170],
			["head", "helm", {"hat": "helm"}, 1, 150],
			["head", "bulwark_helm", Gear.LOOKS["bulwark_helm"][1], 1],
			["vest", "bulwark_brigandine", Gear.LOOKS["bulwark_brigandine"][1], 1],
			["hands", "bulwark_gauntlets", Gear.LOOKS["bulwark_gauntlets"][1], 1]],
		"buys": {"gear": 0.5},
	},
}

const KINDS := ["loot", "weapon", "consumable", "gear"]

## A village grocer's goods by the island's theme (IslandVillage's cookpot shows GROCER_SIZE of them a day).
const THEME_GROCER := {
	"jungle": [["coconut"], ["jungle_fruit"], ["rice"], ["pepper"], ["mushroom"], ["seaweed"]],
	"desert": [["flour"], ["salt"], ["pepper"], ["coconut"], ["egg"]],
	"snow": [["salt"], ["flour"], ["egg"], ["seaweed"], ["crab_meat"]],
	"forest": [["mushroom"], ["egg"], ["flour"], ["salt"], ["pepper"]],
}
const GROCER_SIZE := 3
## What a treasure merchant's rare gear is made from (slot, style, look; their tier).
const RARE_GEAR := [
	["coat", "captain", {"coat": "captain", "coat_color": Color(0.36, 0.1, 0.12), "trim_color": Color(0.9, 0.75, 0.3)}],
	["coat", "greatcoat", {"coat": "greatcoat", "coat_color": Color(0.14, 0.18, 0.34), "trim_color": Color(0.85, 0.7, 0.3)}],
	["head", "bicorne", {"hat": "bicorne", "hat_color": Color(0.1, 0.09, 0.09)}],
	["vest", "cuirass", {"vest": "cuirass", "vest_color": Color(0.7, 0.6, 0.3)}],
	["feet", "cavalier_boots", {"feet": "cavalier_boots", "feet_color": Color(0.24, 0.12, 0.08)}],
	["accessory", "cloak", {"cloak": true, "cloak_color": Color(0.3, 0.08, 0.1)}],
	["coat", "bosun_coat", Gear.LOOKS["bosun_coat"][1]],
	["vest", "bulwark_brigandine", Gear.LOOKS["bulwark_brigandine"][1]],
]
const RARE_KINDS := ["cutlass", "katana", "axe", "pistol", "dagger", "polearm", "hammer", "greatsword", "longgun", "cannon", "slingshot"]
## The chance a treasure merchant also has a piece of rare gear on a given day.
const RARE_GEAR_CHANCE := 0.6
## The chance a treasure merchant has a fine rod that day (half of them the master's: only ever here).
const ROD_CHANCE := 0.3

## Traders made in play (a chain island's village: IslandVillage; an artisan: Artisans), the same shape as SHOPS.
static var extra := {}
## Buy-back: shop id -> {"day", "items": [[ItemData, count, each], ...]} (this captain's, until the day turns).
static var _sold := {}


static func shop(id: String) -> Dictionary:
	return SHOPS[id] if SHOPS.has(id) else extra[id]


static func today() -> int:
	return int((Engine.get_main_loop() as SceneTree).root.get_node("Weather").day())


## What `id` has for sale today.
static func stock(id: String) -> Array:
	return stock_on(id, today())


## What `id` has for sale on day `day`: its staples, that day's picks from its pool, and a treasure
## merchant's rare pieces.
static func stock_on(id: String, day: int) -> Array:
	var s := shop(id)
	var out: Array = (s["stock"] as Array).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [id, day])
	if s.has("pool"):
		var pool: Array = (s["pool"] as Array).duplicate()
		for i in range(mini(int(s["size"]), pool.size())):
			out.append(pool.pop_at(rng.randi() % pool.size()))
	if s.get("trade", "") == "treasure":
		var tier := int(s["tier"])
		# (Loot.weapon's roll written out: Loot names SaveGame, which names autoloads, and tests preload this script)
		var kind: String = RARE_KINDS[rng.randi() % RARE_KINDS.size()]
		out.append([ItemDB.tiered(WeaponDesigns.pick_id(kind, rng), tier).id + "+" + WeaponTraits.roll(kind, rng)])
		if rng.randf() < RARE_GEAR_CHANCE:
			var g: Array = RARE_GEAR[rng.randi() % RARE_GEAR.size()]
			out.append([g[0], g[1], g[2], tier])
		# (drawn after the rest, so each day's other stock is as it was)
		if rng.randf() < ROD_CHANCE:
			out.append(["rod_master" if rng.randf() < 0.5 else "rod_steel"])
	return out


## What a shop's stock entry is as an item (gear is made to order).
static func item_of(entry: Array) -> ItemData:
	if entry.size() <= 2:
		return ItemDB.get_item(str(entry[0]))
	return Gear.make(str(entry[0]), str(entry[1]), entry[2], "", int(entry[3]))


## Stock entries with a trait given to every weapon of blue and up that hasn't one ("<id>@<tier>" ->
## "<id>@<tier>+<trait>"), from a stream seeded by `key` (the shop's id: the same everywhere).
static func with_traits(entries: Array, key: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key + ":traits")
	var out: Array = []
	for e in entries:
		var it := item_of(e)
		if e.size() <= 2 and it.is_weapon() and int(it.rarity) >= WeaponTraits.MIN_TIER and it.weapon_trait == "":
			e = [it.id + "+" + WeaponTraits.roll(it.weapon_model, rng)]
		out.append(e)
	return out


## A captain sold `n` of `item` to `id` for `each`: it waits in the buy-back row.
static func note_sold(id: String, item: ItemData, n: int, each: int) -> void:
	var items := sold_back(id)
	for e in items:
		if (e[0] as ItemData).id == item.id and int(e[2]) == each and item.stackable:
			e[1] = int(e[1]) + n
			return
	items.append([item, n, each])
	_sold[id] = {"day": today(), "items": items}


## The buy-back row: [[ItemData, count, each], ...] (empty once the day turns).
static func sold_back(id: String) -> Array:
	var b: Dictionary = _sold.get(id, {})
	if b.is_empty() or int(b["day"]) != today():
		_sold.erase(id)
		return []
	return b["items"]


## One of buy-back row entry `i` bought back.
static func took_back(id: String, i: int) -> void:
	var items := sold_back(id)
	items[i][1] = int(items[i][1]) - 1
	if int(items[i][1]) <= 0:
		items.remove_at(i)


## On the economy's one curve (Economy.price; the number written in a stock entry is no longer read).
static func price_of(entry: Array) -> int:
	return Economy.price(item_of(entry))


## What a shop pays for one `item` (0: it won't buy it).
static func offer(shop_id: String, item: ItemData) -> int:
	if item == null or item.id == "gold" or item.value <= 0:
		return 0
	var rate: float = float((shop(shop_id)["buys"] as Dictionary).get(Economy.kind_of(item), 0.0))
	return maxi(int(floor(item.worth() * rate)), 1) if rate > 0.0 else 0
