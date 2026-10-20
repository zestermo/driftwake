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
const TAG_NAMES := {"fish": "fish", "meat": "meat", "fruit": "fruit", "grain": "grain", "spice": "spice", "greens": "greens"}

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
}

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
}
## The order the galley lists them.
const ORDER := ["fish_stew", "peppered_boar", "porridge", "citrus_tart", "island_skewers", "reef_salad", "forest_curry", "captains_feast", "sea_legend"]

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
		parts.append("%d %s" % [int(r[tag]), TAG_NAMES[tag]])
	return ", ".join(parts)


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
	for tag in r.keys():
		var need := int(r[tag])
		var cands: Array = []
		for st in inv.items:
			if st.item.ingredient == tag and not cands.has(st.item):
				cands.append(st.item)
		cands.sort_custom(func(a: ItemData, b: ItemData):
			if a.is_consumable() != b.is_consumable():
				return not a.is_consumable()
			return a.value < b.value)
		for it in cands:
			if need <= 0:
				break
			var n := mini(need, int(inv.count(it.id)))
			out.append([it, n])
			need -= n
		if need > 0:
			return []
	return out


## How many of each tag the bag holds.
static func have(inv, tag: String) -> int:
	var n := 0
	for st in inv.items:
		if st.item.ingredient == tag:
			n += st.quantity
	return n


## Cook `meal_id` `portions` times over from one set of ingredients: "" when done, or why not.
static func cook(p, meal_id: String, portions: int) -> String:
	var pr = p.progression
	if not known(pr, meal_id):
		return "You don't know that recipe"
	var inv = p.inventory_component
	var use := picks(inv, meal_id)
	if use.is_empty():
		return "Not enough ingredients"
	var meal := ItemDB.get_item(meal_id)
	if inv.room_for(meal) < portions:
		return "Your bag's full"
	for u in use:
		inv.remove_item(u[0], int(u[1]))
	inv.add_item(meal, portions)
	var first: bool = not pr.cooked.has(meal_id)
	pr.cooked[meal_id] = int(pr.cooked.get(meal_id, 0)) + 1
	pr.add_life("cook", (COOK_XP + COOK_XP_PER * ingredients_in(meal_id)) * (2 if first else 1))
	return ""
