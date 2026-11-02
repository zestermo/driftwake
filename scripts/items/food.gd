class_name Food
extends RefCounted
## Food and cooking (v1.18). Healing comes from food: a slow regen out of a fight (Player: REGEN_PCT a
## second once CALM_S has passed without a blow either way), food and drink from the quick slots in one
## (heal, and drinks' stamina / energy), and galley meals: cooked from ingredients (a recipe asks for
## ingredient tags, ItemData.ingredient), each a buff for 10-20 minutes on Progression.stat (one meal at a
## time, the newest wins; Progression.eat_meal). Cooking builds Cooking mastery (Progression.add_life);
## its perks make meals last longer (meal_time_pct) and hit harder (meal_power_pct). Each captain cooks
## and eats on their own machine. Ingredients and meals are made here as items (ItemDB). Numbers tuned in play.

const TAGS := ["fish", "meat", "fruit", "grain", "spice", "greens"]
const TAG_NAMES := {"fish": "fish", "meat": "meat", "fruit": "fruit", "grain": "grain", "spice": "spice", "greens": "greens",
	"island": "island ingredients"}

## Raw ingredients: id -> [name, tag, value, description]. (Fish, crab, boar, tangerines, sunfruit and
## hardtack are food already and count as their tag too.)
const INGREDIENTS := {
	"rice": ["Sack of Rice", "grain", 1, "Dry, white, and enough for a crew. Cook it first."],
	"flour": ["Bag of Flour", "grain", 1, "Milled wheat. Weevils extra."],
	"salt": ["Sea Salt", "spice", 1, "Boiled out of the sea in a pan. The sea has plenty."],
	"pepper": ["Peppercorns", "spice", 2, "Black and hot. Worth more than gold once, to some."],
	"mushroom": ["Wood Mushrooms", "greens", 1, "Brown caps from under the trees. The safe kind, mostly."],
	"seaweed": ["Kelp", "greens", 1, "Green ribbons from the shallows. Salty."],
	"coconut": ["Coconut", "fruit", 2, "Hard to open, worth it."],
	"egg": ["Gull Eggs", "meat", 2, "Speckled, from a cliff ledge. The gulls want them back."],
	"oyster": ["Oyster", "fish", 3, "Prised off a reef rock. Sometimes there's a pearl."],
	"sea_urchin": ["Sea Urchin", "fish", 3, "Spines outside, sweet roe inside."],
	# (1.28) each theme's own ingredient: a staple at its village cookpot, the key to its two island dishes
	"fire_chili": ["Fire Chili", "spice", 4, "A wrinkled red pod from the jungle. Handle it, then don't touch your eyes."],
	"frost_berries": ["Frost Berries", "fruit", 4, "Blue berries picked under the snow. Sweeter for the cold."],
	"desert_dates": ["Desert Dates", "fruit", 4, "Sticky and dark, from the oasis palms. Caravans run on them."],
	"black_truffle": ["Black Truffle", "greens", 5, "Dug from under the old oaks by a very proud pig."],
	"ghost_lily": ["Ghost Lily", "greens", 4, "A pale bloom from the fog marshes. Faintly peppery, faintly glowing."],
	"ember_salt": ["Ember Salt", "spice", 5, "Red-black salt scraped off cooling lava. It crackles on the tongue."],
	"sea_grapes": ["Sea Grapes", "greens", 4, "Little green beads off the atoll's reef. They pop like the sea."],
}
## (1.28) Each island theme's own ingredient (INGREDIENTS), a staple of its village cookpot; "island" in a
## recipe takes any of them.
const STAPLES := {"jungle": "fire_chili", "snow": "frost_berries", "desert": "desert_dates", "forest": "black_truffle",
	"fog": "ghost_lily", "volcanic": "ember_salt", "atoll": "sea_grapes"}

## Galley meals: id -> name, what it is, heal (when eaten), base minutes, buff {Progression.stat key: amount},
## recipe {ingredient tag: count}, and "taught": a recipe a captain must be taught first (Food.teach).
const MEALS := {
	"fish_stew": {"name": "Fisherman's Stew", "desc": "Fish and rice in a pot of broth. Sticks to your ribs.",
		"heal": 40.0, "min": 15.0, "buff": {"max_hp": 20.0, "regen_pct": 0.5}, "recipe": {"fish": 1, "grain": 1}},
	"peppered_boar": {"name": "Peppered Boar", "desc": "Boar seared black with pepper. Puts fire in your arm.",
		"heal": 35.0, "min": 12.0, "buff": {"damage_pct": 0.08}, "recipe": {"meat": 1, "spice": 1}},
	"porridge": {"name": "Sailor's Porridge", "desc": "Oats, hardtack and fruit, boiled thick. Keeps you going all watch.",
		"heal": 30.0, "min": 20.0, "buff": {"max_stamina": 20.0, "stamina_regen_pct": 0.15}, "recipe": {"grain": 2, "fruit": 1}},
	"citrus_tart": {"name": "Citrus Tart", "desc": "Sweet pastry and sharp fruit. Clears the head.",
		"heal": 30.0, "min": 15.0, "buff": {"max_energy": 15.0, "energy_regen_pct": 0.2}, "recipe": {"fruit": 2, "grain": 1}},
	"reef_salad": {"name": "Reef Salad", "desc": "Kelp, shellfish and salt. Tastes like a dive.",
		"heal": 30.0, "min": 15.0, "buff": {"swim_pct": 0.15, "max_stamina": 10.0}, "recipe": {"fish": 1, "greens": 1, "spice": 1}},
	"forest_curry": {"name": "Forest Curry", "desc": "Mushrooms and spice over rice. Sharpens the eye.",
		"heal": 35.0, "min": 12.0, "buff": {"crit_all": 0.06, "damage_pct": 0.03}, "recipe": {"greens": 2, "spice": 1, "grain": 1}},
	"island_skewers": {"name": "Island Skewers", "desc": "Meat and fruit on a stick, charred. Light on the feet.",
		"heal": 30.0, "min": 15.0, "buff": {"move_pct": 0.06, "sprint_pct": 0.06}, "recipe": {"meat": 1, "fruit": 1}},
	"captains_feast": {"name": "Captain's Feast", "desc": "A bit of everything, done properly. A crew fights for a cook like this.",
		"heal": 60.0, "min": 20.0, "buff": {"max_hp": 25.0, "damage_pct": 0.05, "defense": 4.0},
		"recipe": {"meat": 1, "fish": 1, "fruit": 1, "spice": 1}, "taught": true},
	# (taught by the first legendary fish a captain lands: FishTable.LEGEND_RECIPE; the stew's icon for now)
	"sea_legend": {"name": "Sea Legend's Platter", "desc": "Two fine fish, kelp and spice, the way the old sea cooks did it for a captain's table.",
		"heal": 70.0, "min": 25.0, "buff": {"max_hp": 30.0, "damage_pct": 0.06, "crit_all": 0.05, "swim_pct": 0.1},
		"recipe": {"fish": 2, "greens": 1, "spice": 1}, "taught": true, "icon": "fish_stew"},
	# (1.28: the floating restaurant's head chef teaches it, for gold or free to a crew that saved the kitchen)
	"tidewater_bouillabaisse": {"name": "Tidewater Bouillabaisse", "desc": "The floating kitchen's own: two fish, kelp and saffron-hot spice, simmered all watch.",
		"heal": 60.0, "min": 20.0, "buff": {"max_hp": 20.0, "regen_pct": 0.6, "defense": 3.0, "damage_pct": 0.04},
		"recipe": {"fish": 2, "greens": 1, "spice": 1}, "taught": true, "icon": "fish_stew"},
	# (1.28) island dishes: known from the start, made only with the theme's own ingredient (a recipe key that's an
	# item id takes exactly that item), stronger than a plain galley meal and slanted to the island
	"jungle_pepperpot": {"name": "Jungle Pepperpot", "desc": "Meat and greens stewed black with fire chilies. Your sword arm burns.",
		"heal": 40.0, "min": 15.0, "buff": {"damage_pct": 0.12, "crit_all": 0.04}, "recipe": {"fire_chili": 1, "meat": 1, "greens": 1}, "theme": "jungle"},
	"reef_ceviche": {"name": "Reef-Fruit Ceviche", "desc": "Raw fish cooked in fruit juice and chili. Cold, sharp, quick.",
		"heal": 35.0, "min": 15.0, "buff": {"swim_pct": 0.2, "move_pct": 0.08}, "recipe": {"fire_chili": 1, "fish": 1, "fruit": 1}, "theme": "jungle"},
	"frostberry_pie": {"name": "Frostberry Pie", "desc": "A thick crust round blue berries. Climbers carry it up the passes.",
		"heal": 35.0, "min": 20.0, "buff": {"max_stamina": 30.0, "stamina_regen_pct": 0.25}, "recipe": {"frost_berries": 1, "grain": 2}, "theme": "snow"},
	"ice_cod_chowder": {"name": "Ice Cod Chowder", "desc": "Fish, grain and tart berries in cream. Fends off the cold and the blows.",
		"heal": 45.0, "min": 20.0, "buff": {"max_hp": 35.0, "defense": 5.0}, "recipe": {"frost_berries": 1, "fish": 1, "grain": 1}, "theme": "snow"},
	"date_bread": {"name": "Date Bread", "desc": "Flat bread folded round dates and spice. It keeps for a whole caravan.",
		"heal": 30.0, "min": 15.0, "buff": {"max_energy": 25.0, "energy_regen_pct": 0.3}, "recipe": {"desert_dates": 1, "grain": 1, "spice": 1}, "theme": "desert"},
	"dune_skewers": {"name": "Dune Skewers", "desc": "Spiced meat and dates charred on iron. Eat it running.",
		"heal": 35.0, "min": 12.0, "buff": {"damage_pct": 0.1, "sprint_pct": 0.08}, "recipe": {"desert_dates": 1, "meat": 1, "spice": 1}, "theme": "desert"},
	"truffle_risotto": {"name": "Truffle Risotto", "desc": "Rice stirred slow with truffle shavings. Every blow finds the gap.",
		"heal": 35.0, "min": 15.0, "buff": {"crit_all": 0.08, "damage_pct": 0.05}, "recipe": {"black_truffle": 1, "grain": 1, "greens": 1}, "theme": "forest"},
	"hunters_stew": {"name": "Hunter's Stew", "desc": "Game, grain and truffle, left on the embers overnight.",
		"heal": 50.0, "min": 20.0, "buff": {"max_hp": 30.0, "regen_pct": 0.8}, "recipe": {"black_truffle": 1, "meat": 1, "grain": 1}, "theme": "forest"},
	"lily_broth": {"name": "Lily Broth", "desc": "A clear broth with a ghost lily floating in it. The head clears like fog lifting.",
		"heal": 35.0, "min": 15.0, "buff": {"max_energy": 20.0, "energy_regen_pct": 0.3, "defense": 3.0}, "recipe": {"ghost_lily": 1, "fish": 1, "spice": 1}, "theme": "fog"},
	"mist_dumplings": {"name": "Mist Dumplings", "desc": "Steamed parcels of meat and lily. Soft outside, sturdy within.",
		"heal": 40.0, "min": 15.0, "buff": {"defense": 6.0, "max_hp": 20.0}, "recipe": {"ghost_lily": 1, "grain": 1, "meat": 1}, "theme": "fog"},
	"lava_grill": {"name": "Lava-Stone Grill", "desc": "Meat and fish seared on a hot stone, salted with ember salt. Pure heat.",
		"heal": 40.0, "min": 12.0, "buff": {"damage_pct": 0.14}, "recipe": {"ember_salt": 1, "meat": 1, "fish": 1}, "theme": "volcanic"},
	"ember_curry": {"name": "Ember Curry", "desc": "Greens and grain in a curry that crackles. Sweat it out and keep swinging.",
		"heal": 35.0, "min": 15.0, "buff": {"crit_all": 0.06, "damage_pct": 0.06, "stamina_regen_pct": 0.2}, "recipe": {"ember_salt": 1, "greens": 1, "grain": 1}, "theme": "volcanic"},
	"lagoon_poke": {"name": "Lagoon Poke", "desc": "Raw reef fish on rice with sea grapes. Divers eat it on the sandbar between dives.",
		"heal": 40.0, "min": 15.0, "buff": {"max_hp": 25.0, "swim_pct": 0.15, "crit_all": 0.04}, "recipe": {"sea_grapes": 1, "fish": 1, "grain": 1}, "theme": "atoll"},
	"pearl_broth": {"name": "Pearl Diver's Broth", "desc": "Fish, sea grapes and spice in a hot broth. Long breaths, strong strokes.",
		"heal": 35.0, "min": 15.0, "buff": {"max_stamina": 25.0, "stamina_regen_pct": 0.25, "swim_pct": 0.15}, "recipe": {"sea_grapes": 1, "fish": 1, "spice": 1}, "theme": "atoll"},
	# (1.28) crew feasts: cooked aboard, every captain aboard gets the buff (docs/life_systems_plan.md)
	"harbour_feast": {"name": "Harbour Feast", "desc": "Fish from the rail, bread from the hold, a pot big enough to bathe in.",
		"heal": 60.0, "min": 25.0, "buff": {"max_hp": 30.0, "regen_pct": 0.6, "damage_pct": 0.05},
		"recipe": {"fish": 3, "grain": 2, "greens": 2, "spice": 1}, "feast": true, "icon": "fish_stew"},
	"roast_feast": {"name": "Boar Roast Feast", "desc": "A whole boar turned over the galley fire all afternoon.",
		"heal": 70.0, "min": 25.0, "buff": {"damage_pct": 0.08, "max_stamina": 25.0, "defense": 4.0},
		"recipe": {"meat": 3, "fruit": 2, "grain": 2, "spice": 2}, "feast": true, "taught": true, "icon": "peppered_boar"},
	"isles_feast": {"name": "Feast of the Isles", "desc": "A dish from every island you've sailed past, on one long table.",
		"heal": 80.0, "min": 30.0, "buff": {"max_hp": 40.0, "damage_pct": 0.1, "crit_all": 0.05, "defense": 5.0},
		"recipe": {"island": 3, "fish": 2, "meat": 2}, "feast": true, "taught": true, "icon": "captains_feast"},
	# (1.25.5 unique places: services, not dishes; never in ORDER, never cooked) a village's hot spring and its sea shrine
	"hot_spring": {"name": "Hot Spring Soak", "desc": "Warm to the bone.", "heal": 0.0, "min": 30.0,
		"buff": {"max_hp": 25.0, "regen_pct": 1.0, "stamina_regen_pct": 0.2}, "recipe": {}, "taught": true, "icon": "fish_stew"},
	"sea_blessing": {"name": "The Sea's Blessing", "desc": "The tide is on your side.", "heal": 0.0, "min": 20.0,
		"buff": {"swim_pct": 0.2, "defense": 3.0, "energy_regen_pct": 0.15}, "recipe": {}, "taught": true, "icon": "fish_stew"},
}
## The order the galley lists them.
const ORDER := ["fish_stew", "peppered_boar", "porridge", "citrus_tart", "island_skewers", "reef_salad", "forest_curry", "captains_feast", "sea_legend", "tidewater_bouillabaisse",
	"jungle_pepperpot", "reef_ceviche", "frostberry_pie", "ice_cod_chowder", "date_bread", "dune_skewers", "truffle_risotto", "hunters_stew",
	"lily_broth", "mist_dumplings", "lava_grill", "ember_curry", "lagoon_poke", "pearl_broth",
	"harbour_feast", "roast_feast", "isles_feast"]

## How a buff key reads (percent keys show x 100).
const BUFF_TEXT := {"max_hp": "+%d max health", "regen_pct": "+%d%% health regen", "damage_pct": "+%d%% damage",
	"max_stamina": "+%d max stamina", "stamina_regen_pct": "+%d%% stamina regen", "max_energy": "+%d max energy",
	"energy_regen_pct": "+%d%% energy regen", "swim_pct": "+%d%% swim speed", "crit_all": "+%d%% crit chance",
	"move_pct": "+%d%% run speed", "sprint_pct": "+%d%% sprint speed", "defense": "+%d defense"}
const COUNT_KEYS := ["max_hp", "max_stamina", "max_energy", "defense"]

## Cooking mastery for a dish: COOK_XP and COOK_XP_PER for each ingredient in it (first time: twice).
const COOK_XP := 20
const COOK_XP_PER := 10


## Make the ingredients and meals as items (ItemDB._load_all).
static func make_items(items: Dictionary) -> void:
	for id in INGREDIENTS.keys():
		var d: Array = INGREDIENTS[id]
		var it := ItemData.new()
		it.id = id
		it.display_name = str(d[0])
		it.description = str(d[3])
		it.value = int(d[2])
		it.max_stack = 20
		it.item_type = ItemData.ItemType.LOOT
		it.ingredient = str(d[1])
		it.icon = load("res://assets/textures/icons/%s.png" % id)
		items[id] = it
	for id in MEALS.keys():
		var m: Dictionary = MEALS[id]
		var it := ItemData.new()
		it.id = id
		it.display_name = str(m["name"])
		it.description = str(m["desc"])
		it.value = 3 + 2 * ingredients_in(id)
		it.rarity = ItemData.Rarity.RARE if m.get("taught", false) else ItemData.Rarity.UNCOMMON
		it.max_stack = 5
		it.item_type = ItemData.ItemType.CONSUMABLE
		it.heal_amount = float(m["heal"])
		it.use_time = 1.1
		it.use_anim = "slurp"
		it.meal = id
		it.icon = load("res://assets/textures/icons/%s.png" % m.get("icon", id))
		items[id] = it
		# (1.28) how well it was cooked (the cooking game): "<id>@0" Burnt, "@2" Good, "@3" Perfect; the meal itself is Fair
		for g in [0, 2, 3]:
			var gi := it.duplicate() as ItemData
			gi.id = graded(id, g)
			gi.display_name = "%s %s" % [CookTiming.GRADE_NAMES[g], it.display_name]
			gi.meal_mult = float(CookTiming.MULT[g])
			gi.rarity = g as ItemData.Rarity
			gi.value = maxi(1, roundi(it.value * gi.meal_mult))
			items[gi.id] = gi


## The item id of `meal_id` cooked to grade `g` (CookTiming: 0 Burnt, 1 Fair = the meal itself, 2 Good, 3 Perfect).
static func graded(meal_id: String, g: int) -> String:
	return meal_id if g == 1 else "%s@%d" % [meal_id, g]


static func ingredients_in(meal_id: String) -> int:
	var n := 0
	for k in (MEALS[meal_id]["recipe"] as Dictionary).values():
		n += int(k)
	return n


## A meal's buff for `key` at strength `k` (0 when it doesn't touch it).
static func bonus(meal_id: String, key: String, k: float) -> float:
	return float((MEALS[meal_id]["buff"] as Dictionary).get(key, 0.0)) * k


## "+20 max health, +50% health regen" (at strength `k`).
static func buff_text(meal_id: String, k: float = 1.0) -> String:
	var parts: Array = []
	var b: Dictionary = MEALS[meal_id]["buff"]
	for key in b.keys():
		var amt := float(b[key]) * k
		parts.append(BUFF_TEXT[key] % (roundi(amt) if key in COUNT_KEYS else roundi(amt * 100.0)))
	return ", ".join(parts)


## "1 fish, 1 grain"
static func recipe_text(meal_id: String) -> String:
	var parts: Array = []
	var r: Dictionary = MEALS[meal_id]["recipe"]
	for tag in r.keys():
		parts.append("%d %s" % [int(r[tag]), tag_name(tag)])
	return ", ".join(parts)


## How a recipe key reads: a tag ("grain"), "island ingredients", or an ingredient's own name ("Fire Chili").
static func tag_name(tag: String) -> String:
	return str(TAG_NAMES[tag]) if TAG_NAMES.has(tag) else str(INGREDIENTS[tag][0])


## Does `it` count for recipe key `tag`: a tag, "island" (any theme's staple), or exactly that item id.
static func fits(it: ItemData, tag: String) -> bool:
	if tag == "island":
		return STAPLES.values().has(it.id)
	return it.ingredient == tag if TAGS.has(tag) else it.id == tag


## Is `meal_id` a crew feast (cooked aboard only, everyone aboard eats it).
static func is_feast(meal_id: String) -> bool:
	return MEALS[meal_id].get("feast", false)


## Is `p` aboard the crew's own ship (where feasts are cooked and eaten).
static func aboard(p) -> bool:
	var ship = p.get_tree().get_first_node_in_group("ship")
	return ship != null and ship.owned() and ship.aboard(p.global_position)


## How long a meal lasts for `pr`'s captain (seconds), and how strong (Cooking's perks).
static func seconds(pr, meal_id: String) -> float:
	return float(MEALS[meal_id]["min"]) * 60.0 * (1.0 + pr.stat("meal_time_pct"))


static func strength(pr) -> float:
	return 1.0 + pr.stat("meal_power_pct")


static func known(pr, meal_id: String) -> bool:
	return not MEALS[meal_id].get("taught", false) or pr.recipes.has(meal_id)


## A recipe learned (a quest's reward, a book, a cook's favour): true if it was new.
static func teach(pr, meal_id: String) -> bool:
	if pr.recipes.has(meal_id):
		return false
	pr.recipes[meal_id] = true
	return true


## What cooking `meal_id` would take out of the bag: [[ItemData, n], ...], or [] when it's short.
## Raw ingredients go before food that can be eaten as it is, the cheapest first.
static func picks(inv, meal_id: String) -> Array:
	var out: Array = []
	var r: Dictionary = MEALS[meal_id]["recipe"]
	var taken := {}
	# (exact items first, then "island", then the plain tags, so a tag never eats the item a dish is named for)
	var keys: Array = r.keys()
	keys.sort_custom(func(x, y): return _key_rank(x) < _key_rank(y))
	for tag in keys:
		var need := int(r[tag])
		var cands: Array = []
		for st in inv.items:
			if fits(st.item, tag) and not cands.has(st.item):
				cands.append(st.item)
		cands.sort_custom(func(x: ItemData, y: ItemData):
			if x.is_consumable() != y.is_consumable():
				return not x.is_consumable()
			return x.value < y.value)
		for it in cands:
			if need <= 0:
				break
			var n := mini(need, int(inv.count(it.id)) - int(taken.get(it.id, 0)))
			if n <= 0:
				continue
			out.append([it, n])
			taken[it.id] = int(taken.get(it.id, 0)) + n
			need -= n
		if need > 0:
			return []
	return out


static func _key_rank(tag: String) -> int:
	return 2 if TAGS.has(tag) else (1 if tag == "island" else 0)


## How many of each tag the bag holds.
static func have(inv, tag: String) -> int:
	var n := 0
	for st in inv.items:
		if fits(st.item, tag):
			n += st.quantity
	return n


## Could `p` cook `meal_id` now? "" when they could, or why not.
static func can_cook(p, meal_id: String, portions: int) -> String:
	if not known(p.progression, meal_id):
		return "You don't know that recipe"
	if is_feast(meal_id) and not aboard(p):
		return "Feasts are cooked in the ship's galley"
	var inv = p.inventory_component
	if picks(inv, meal_id).is_empty():
		return "Not enough ingredients"
	if inv.room_for(ItemDB.get_item(meal_id)) < portions:
		return "Your bag's full"
	return ""


## Cook `meal_id` `portions` times over from one set of ingredients, to grade `grade` (the cooking game's;
## Quick cook and shops are Fair): "" when done, or why not. A Perfect first cook doubles the first time's XP again.
static func cook(p, meal_id: String, portions: int, grade: int = 1) -> String:
	var why := can_cook(p, meal_id, portions)
	if why != "":
		return why
	var pr = p.progression
	var inv = p.inventory_component
	for u in picks(inv, meal_id):
		inv.remove_item(u[0], int(u[1]))
	inv.add_item(ItemDB.get_item(graded(meal_id, grade)), portions)
	var first: bool = not pr.cooked.has(meal_id)
	pr.cooked[meal_id] = int(pr.cooked.get(meal_id, 0)) + 1
	pr.add_life("cook", (COOK_XP + COOK_XP_PER * ingredients_in(meal_id)) * (2 if first else 1) * (2 if first and grade == 3 else 1))
	# (1.26) the galley's fire tops up the tonic flask too
	if p.has_method("refill_flask"):
		p.refill_flask()
	return ""
