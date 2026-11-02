class_name VillageVendors
extends RefCounted

const Shops := preload("res://scripts/game/shops.gd")
## A chain village's traders beyond the store and the cookpot (1.23, docs/v1_23_plan.md "Villages": every named NPC has
## a job). Each village rolls COUNT of them from POOL (seeded by the island, nothing guaranteed), each a named villager
## with a market spot, their own lines and a shop (Shops.extra) cut from the home island's shop of the same trade.

const POOL := ["tailor", "smith", "luthier", "apothecary"]
## How many a village has: a range, more on later islands (tier).
const COUNT := [2, 4]

## title, the home shop the stock comes from, the shop's name ("{n}" the vendor's name), its line, and the person's lines.
const TRADES := {
	"tailor": {"title": "Outfitter", "from": "sela", "shop": "{n}'s Outfitters", "line": "Cloth, leather and steel to wear, and a needle that never sleeps.",
		"intro": ["Clothes make the pirate. Bad clothes make the pirate laughed at.", "{name}. I dress half this island and mend the other half."],
		"self": ["I came for a season and stayed for the cloth. The dyes out here are like nothing on the mainland."],
		"talk": ["A good coat turns rain and blades both. Well. Rain.", "Bring me silk from the next island and I'll make you a legend.", "Wear red at sea and the gulls follow you. Superstition, mostly."]},
	"smith": {"title": "Smith", "from": "haldor", "shop": "{n}'s Forge", "line": "Every blade on the rack came out of my fire.",
		"intro": ["Mind the sparks. {name}, smith.", "You've a sword on you. Let me see the edge. Hm. Let me sell you a new one."],
		"self": ["My hammer arm's stronger than my sense, my wife says. She's not wrong."],
		"talk": ["Salt eats steel. Oil your blade every night.", "A heavier blade hits harder and swings slower. Choose your trouble.", "Pirates pay best. Pirates also pay last."]},
	"luthier": {"title": "Instrument maker", "from": "corin", "shop": "{n}'s Strings", "line": "Strings, skins and bellows. All in tune, give or take a gale.",
		"intro": ["A tune for the road? {name}, maker of noise.", "Every crew needs a fiddle. Most crews need a better one."],
		"self": ["I built my first drum out of a rum barrel. It still smells of rum. So do I."],
		"talk": ["Play near your crewmates and you'll fall into the same tune.", "A concertina's the sailor's friend: small, loud, hard to break.", "Music keeps the night watch awake. Mostly."]},
	"parts": {"title": "Parts dealer", "from": "", "shop": "{n}'s Parts", "line": "Gears, springs, wire and good iron. Whatever your gadget's missing.",
		"intro": ["Looking for a spring? A gear? {name}, parts and salvage.", "Tinkerers buy from me. So do people who wish they were tinkerers."],
		"self": ["Half my stock came off wrecks, half out of the mountain. All of it works. Mostly."],
		"talk": ["Brass for gears, steel for springs, copper for anything with a spark.", "Beast horn makes a fine trigger. Don't ask how I know.", "Bring me salvage and I'll pay you for it."]},
	"apothecary": {"title": "Apothecary", "from": "", "shop": "{n}'s Remedies", "line": "Tonics, salves, and something for the seasickness.",
		"intro": ["Bleeding? Sit. {name}, apothecary.", "You look like someone who gets hit a lot. I've just the thing."],
		"self": ["I learned from the island's healers and the island's mistakes."],
		"talk": ["A tonic on an empty stomach works twice as fast. And comes back twice as fast.", "Drink before the fight, not after you've lost it.", "Rum isn't medicine. It's close, though."]},
}

## The apothecary's own stock (no home shop has one).
const APOTHECARY := {"trade": "grocer", "stock": [["tonic", 28], ["rum", 9], ["biscuit", 3]],
	"pool": [["pepper"], ["mushroom"], ["salt"], ["seaweed"], ["egg"]], "size": 2, "buys": {"ingredient": 0.5, "consumable": 0.4}}


## Skins (1.24): a village tailor's patterned clothes (here) and a village smith's weapons in another finish
## (WeaponDesigns.skin_ids), in their pools beside the home shop's (SKIN_SIZE more shown a day).
const SKINS := {
	"tailor": [
		["coat", "longcoat", {"coat": "longcoat", "coat_color": Color(0.4, 0.1, 0.12), "trim_color": Color(0.85, 0.68, 0.24), "coat_pattern": "brocade"}, 1],
		["coat", "captain", {"coat": "captain", "coat_color": Color(0.14, 0.18, 0.34), "trim_color": Color(0.85, 0.68, 0.24), "coat_pattern": "brocade"}, 1],
		["coat", "jacket", {"coat": "jacket", "coat_color": Color(0.62, 0.52, 0.38), "trim_color": Color(0.4, 0.28, 0.18), "coat_pattern": "patched"}, 0],
		["coat", "frock", {"coat": "frock", "coat_color": Color(0.18, 0.34, 0.2), "trim_color": Color(0.85, 0.68, 0.24), "coat_pattern": "check"}, 1],
		["torso", "shirt", {"top": "shirt", "sleeves": "long", "top_color": Color(0.9, 0.88, 0.8), "top_pattern": "stripes"}, 0],
		["torso", "tunic", {"top": "tunic", "sleeves": "short", "top_color": Color(0.66, 0.14, 0.12), "top_pattern": "check"}, 0],
		["vest", "vest", {"vest": "vest", "vest_color": Color(0.8, 0.62, 0.2), "vest_pattern": "brocade"}, 1],
		["vest", "vest", {"vest": "vest", "vest_color": Color(0.36, 0.2, 0.44), "vest_pattern": "stripes"}, 0],
		["legs", "trousers", {"legs": "trousers", "legs_color": Color(0.82, 0.76, 0.62), "legs_pattern": "stripes"}, 0],
		["legs", "breeches", {"legs": "breeches", "legs_color": Color(0.4, 0.1, 0.12), "legs_pattern": "check"}, 0],
		["legs", "slops", {"legs": "slops", "legs_color": Color(0.62, 0.52, 0.38), "legs_pattern": "patched"}, 0],
		["legs", "skirt", {"legs": "skirt", "legs_color": Color(0.14, 0.18, 0.34), "legs_pattern": "check"}, 0]],
}
const SKIN_SIZE := 2


## The parts dealer's shop (the forge town's): the yard's iron and copper, and every gadget part (Gadgets.part_ids).
static func _parts() -> Dictionary:
	var parts: Array = Gadgets.part_ids().map(func(i): return [i])
	return {"trade": "grocer", "stock": [["iron", 5], ["copper", 5]] + parts.slice(0, 3), "pool": parts, "size": mini(parts.size(), 3),
		"buys": {"loot": 0.6, "ingredient": 0.3}}


## The trades a village with seed `seed_` has (its own stream: nothing else's draws move); `always` (its style's
## "vendors_always": the forge town's smith and parts dealer) first, the roll filling the rest.
static func roll(seed_: int, tier: int, always: Array = []) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, 5107])
	var pool := POOL.filter(func(t): return not always.has(t))
	var out: Array = always.duplicate()
	var n := clampi(rng.randi_range(COUNT[0], COUNT[1]) + (1 if tier >= 3 else 0), 0, POOL.size())
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


## A role table (title, intro, self, talk) for trade `t`, like a theme's roles.
static func role(t: String) -> Dictionary:
	var d: Dictionary = TRADES[t]
	return {"title": d["title"], "work": "market", "intro": d["intro"], "self": d["self"], "talk": d["talk"]}


## The shop for trade `t` kept by `who` (short name), from its home shop's stock (Shops.SHOPS).
static func shop(t: String, who: String) -> Dictionary:
	var d: Dictionary = TRADES[t]
	var base: Dictionary = (Shops.SHOPS[d["from"]] as Dictionary).duplicate(true) if str(d["from"]) != "" else (_parts() if t == "parts" else APOTHECARY.duplicate(true))
	base["name"] = str(d["shop"]).replace("{n}", who)
	base["line"] = d["line"]
	var skins: Array = SKINS.get(t, [])
	if t == "smith":
		skins = WeaponDesigns.skin_ids().map(func(i): return [i])
	if not skins.is_empty():
		base["pool"] = (base["pool"] as Array) + skins
		base["size"] = int(base["size"]) + SKIN_SIZE
	return base
