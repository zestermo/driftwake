class_name UniquePlaces
extends RefCounted
## (1.25.5, docs/v1_26_plan.md "Unique places"; the pool and each place's reward are assumed, not previewed) Every
## chain village has one place no other village near it has, in one of its houses (VillageLayouts._convert): its
## room dressed for it (KitShops) and its keeper inside (IslandVillage._unique_keeper), whose talk is its reward. Rolled
## from the chain's seed in the chain's island order, so a chain doesn't repeat one until the pool's been round; the
## island before tells of it (IslandLife._ahead_lines). Each captain takes its reward on their own machine (their gold,
## their bag, their buffs); what's once per character is GameManager.opened under the island's save key.

const POOL := ["library", "onsen", "restaurant", "swordsmith", "sea_shrine", "cartographer", "dojo", "curio"]
const Shops := preload("res://scripts/game/shops.gd")
const SOAK := 20
const PRAY := 10
const CHART := 40
const LESSON := 50
## Each place: its name, the keeper's title, the rumour told on the island before, the keeper's intro and the menu's
## choices ([text, op]; op "shop" opens its shop).
const PLACES := {
	"library": {"title": "the old library", "keeper": "Archivist", "rumour": "There's a library on {name}, older than its harbour. A captain who reads the old logs there comes out knowing something about themselves.",
		"intro": ["Quietly, please. These logs have outlived every captain who wrote them.", "Read, if you like. Some find a little of their own Edy in the margins."],
		"choices": [["Let me read the old logs.", "read"]]},
	"onsen": {"title": "the hot spring", "keeper": "Bath-keeper", "rumour": "They've a hot spring on {name}, under a roof. One soak and you'll fight like you slept a week.",
		"intro": ["Leave your boots and your troubles at the door.", "%d gold, and the water does the rest. It'll stay with you a long while." % SOAK],
		"choices": [["A soak, please. (%d gold)" % SOAK, "soak"]]},
	"restaurant": {"title": "the fine kitchen", "keeper": "Chef", "rumour": "The kitchen on {name} cooks a captain's feast every night. Bring gold and an empty stomach.",
		"intro": ["Sit, sit. Tonight there is a feast, as there is every night.", "Galley food keeps you alive. Mine makes you want to be."],
		"choices": [["What's cooking?", "shop"]]},
	"swordsmith": {"title": "the master swordsmith's forge", "keeper": "Master swordsmith", "rumour": "A master swordsmith works on {name}. One blade a season, and each worth a ship.",
		"intro": ["A blade is a promise. Most smiths break theirs.", "I keep one or two finished. Look, but don't touch unless you mean to buy."],
		"choices": [["Show me your blades.", "shop"]]},
	"sea_shrine": {"title": "the shrine of the sea", "keeper": "Shrine keeper", "rumour": "There's a shrine of the sea on {name}. Leave an offering and the tide takes your side for a while.",
		"intro": ["The sea gives, and the sea takes. Here we ask it to give a little longer.", "An offering of %d gold, and its blessing goes with you." % PRAY],
		"choices": [["Leave an offering. (%d gold)" % PRAY, "pray"]]},
	"cartographer": {"title": "the old cartographer's", "keeper": "Old cartographer", "rumour": "The old cartographer on {name} has walked every path of it. Her charts aren't cheap, and they aren't wrong.",
		"intro": ["Every island is a puzzle. I've solved this one, and I'll sell you the answer.", "%d gold for the whole island on your map, every place on it marked. And if I've a treasure chart spare, it's yours." % CHART],
		"choices": [["Sell me the island's chart. (%d gold)" % CHART, "chart"]]},
	"dojo": {"title": "the fighting school", "keeper": "Sparring master", "rumour": "There's a fighting school on {name}. The master spars with any captain who pays, and they come out sharper.",
		"intro": ["Feet. Everything starts with the feet.", "%d gold for a lesson. One lesson is all most of you can take." % LESSON],
		"choices": [["Spar with me. (%d gold)" % LESSON, "spar"]]},
	"curio": {"title": "the curio shop", "keeper": "Curio dealer", "rumour": "A curio shop on {name} sells things from every sea. Half of it's junk. The other half isn't.",
		"intro": ["Shells, skulls, bottled ships, a fish that sings. Probably.", "Everything has a story. The stories are free."],
		"choices": [["Let me see your curios.", "shop"]]},
}
## Tools and tests: every village's place is this ("" for the roll).
static var force := ""


## The place an island's village has (data: worker-safe).
static func of(gi) -> String:
	return roll(int(gi.node.get("chain", 0)), int(gi.node["id"]))


## The pool shuffled by the chain's seed, then taken in the chain's island order.
static func roll(chain_seed: int, id: int) -> String:
	if force != "":
		return force
	var order := POOL.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([chain_seed, 5140])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	return order[posmod(id, order.size())]


## What the island before says of chain node `n`'s place.
static func rumour(n: Dictionary) -> String:
	return str(PLACES[roll(int(n.get("chain", 0)), int(n["id"]))]["rumour"]).replace("{name}", str(n["name"]))


## The keeper's talk (every machine the same) under dialogue id `id` (`sid`: its shop, if it keeps one).
static func define(id: String, place: String, keeper: String, isl_name: String, sid: String) -> void:
	var P: Dictionary = PLACES[place]
	var menu: Array = []
	for c in P["choices"]:
		menu.append({"text": c[0], "next": "do_" + str(c[1])})
	menu.append({"text": "What is this place?", "next": "about"})
	menu.append({"text": "Goodbye.", "next": "end"})
	var nodes := {"intro": {"text": P["intro"], "next": "menu"}, "menu": {"text": "Well?", "choices": menu},
		"about": {"text": ["This is %s of %s. There's nothing like it on any island near." % [P["title"], isl_name]], "next": "menu"}}
	for c in P["choices"]:
		if c[1] == "shop":
			nodes["do_shop"] = {"text": ["Have a look."], "event": "shop:" + sid, "next": "end"}
		else:
			nodes["do_" + str(c[1])] = {"text": ["{%s_said}" % id], "event": "unique:%s:%s" % [id, c[1]], "next": "menu"}
	Engine.get_main_loop().root.get_node("Dialogue").define(id, {"speaker": keeper, "voice": 0.95, "start": "intro", "return": "menu", "nodes": nodes})


## The place's shop (restaurant, swordsmith, curio), into Shops.extra under `sid`.
static func shop(place: String, sid: String, keeper: String, tier: int) -> Dictionary:
	match place:
		"restaurant":
			return {"name": "%s's Table" % keeper, "line": "Tonight: everything.", "trade": "cook",
				"stock": [["captains_feast", 60], ["sea_legend", 80], ["fish_stew", 22], ["forest_curry", 24], ["island_skewers", 20], ["citrus_tart", 20]],
				"buys": {"consumable": 0.4}}
		"swordsmith":
			var t := mini(tier + 2, 5)
			return {"name": "%s's Masterworks" % keeper, "line": "Each of these has a name. Earn it.", "trade": "smith",
				"stock": Shops.with_traits([["katana@%d" % t, 300], ["naval_sabre@%d" % t, 260], ["claymore@%d" % mini(t, 4), 320], ["wakizashi@%d" % t, 220]], sid),
				"buys": {"weapon": 0.6}}
	return {"name": "%s's Curios" % keeper, "line": "Everything has a story.", "trade": "treasure", "tier": mini(tier + 1, 4),
		"stock": [["pearl", 30], ["treasure", 40], ["sea_urchin", 12], ["tin_whistle", 35], ["rum", 9]],
		"buys": {"loot": 1.0}}


## (this captain's machine) The place's reward from its keeper: `op` as the talk named it. Returns what to toast.
static func act(isl, place: String, op: String, p: Player) -> String:
	var gm := p.get_node("/root/GameManager")
	var inv := p.inventory_component
	var once: String = isl.save_key("unique_" + op)
	match op:
		"read":
			if gm.opened.has(once):
				return "You've read all the old logs have to tell you."
			gm.opened[once] = true
			p.progression.will_point(1, "the old library's logs")
			return "Between the lines of a dead captain's log, something of your own Edy."
		"soak", "pray", "chart", "spar":
			var cost: int = {"soak": SOAK, "pray": PRAY, "chart": CHART, "spar": LESSON}[op]
			if op == "spar" and gm.opened.has(once):
				return "\"You've had your lesson. Go and use it.\""
			if inv.count("gold") < cost:
				return "Not enough gold (%d)." % cost
			inv.remove_item(ItemDB.get_item("gold"), cost)
			match op:
				"soak":
					p.progression.eat_meal("hot_spring")
					var hc: HealthComponent = p.health_component
					hc.heal(hc.max_health)
					p.stamina = p.max_stamina
					p.power.energy = p.power.max_energy()
					return "The heat soaks the ache out of you. %s for a long while." % Food.buff_text("hot_spring")
				"pray":
					p.progression.eat_meal("sea_blessing")
					return "The tide is with you: %s." % Food.buff_text("sea_blessing")
				"chart":
					var d := MapIsles.of(isl)
					var all := PackedInt32Array()
					for c in range(int(d["n"]) * int(d["n"])):
						all.append(c)
					MapFog.apply(gm, str(d["key"]), int(d["n"]), all)
					for s in d["spots"]:
						MapFog.find(gm, str(d["key"]), str(s["id"]))
					var t := QuestRewards._unmapped(p)
					if t >= 0 and not gm.opened.has(once):
						gm.maps[t] = true
						gm.opened[once] = true
						return "The whole island on your map (M), and a treasure chart besides (your sea chart)."
					return "The whole island on your map (M)."
				"spar":
					gm.opened[once] = true
					var xp := QuestRewards.xp_for(p) * 2
					p.progression.add_xp(xp)
					return "Bruised, and sharper for it. %d XP." % xp
	return ""
