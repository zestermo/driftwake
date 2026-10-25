class_name ShipLines
extends RefCounted
## Tackett's upgrade lines for the crew's sloop: each a few small steps, every
## step paid for in gold (and, higher up, salvage) and every step showing on
## her (ShipParts builds them). The kit (ShipKit) holds each line's level as an
## int under the line's id; old saves' one-time refits (bools) become the
## line's `legacy` level, so nothing bought is lost.
##
## A level: [name, what it is, materials {item id: n}, effects {key: amount}]; its gold is on the
## economy's curve (price: the line's "base" x 1.6 a level, Economy.upgrade_price), and entry() gives
## [name, what it is, gold, materials, effects].
## Effects sum over every level a line has reached (total()):
##   hull (max hull), speed (top speed), turn (turn rate), dmg (gun damage),
##   reload (reload time cut), range (gun range), guns (the quarterdeck pair),
##   reef (reef and whirlpool damage cut), chaser (the bow gun), chaser_dmg / chaser_range,
##   spot (m: the lookout puts ships and salvage on the compass), night (speed between dusk and dawn),
##   steady (a ram throws the crew that much less; 1 = not at all), board (boarders fewer),
##   fruit (tangerine trees), portions (more of each dish cooked at the galley), slots (bag slots),
##   ropes (the swing ropes at the yard's ends: none until bought)

const GROUPS := ["Hull", "Guns", "Rig", "Helm", "Deck", "Cabin"]

const LINES := {
	"armour": {"name": "Hull plating", "group": "Hull", "legacy": 5, "base": 60, "levels": [
		["Rubbing strakes", "Oak wales down both sides", {}, {"hull": 0.08}],
		["Iron knees", "Iron straps amidships", {}, {"hull": 0.08}],
		["Strapped hull", "Straps her whole length and an iron band", {"timber": 4}, {"hull": 0.08}],
		["Iron stem", "An iron-shod bow", {"iron": 4, "timber": 4}, {"hull": 0.08}],
		["Capped rails", "Iron capping on her bulwarks", {"iron": 6, "timber": 4}, {"hull": 0.08}],
		["Plated quarters", "Riveted plates on her stern quarters", {"iron": 8, "copper": 2}, {"hull": 0.08}],
	]},
	"guns": {"name": "Gun deck", "group": "Guns", "legacy": 2, "base": 60, "levels": [
		["Shot racks", "A rack of shot by every gun", {}, {"dmg": 0.05}],
		["Quarterdeck guns", "Two more swivel guns aft: three a side", {}, {"guns": 1}],
		["Banded barrels", "Brass bands on every barrel", {"iron": 4}, {"dmg": 0.05, "reload": 0.05}],
		["Gun shields", "Iron shields on the yokes", {"iron": 6, "timber": 2}, {"reload": 0.05}],
		["Long guns", "Longer barrels", {"iron": 6, "copper": 3}, {"dmg": 0.05, "range": 0.08}],
	]},
	"sails": {"name": "Sails & rigging", "group": "Rig", "legacy": 5, "base": 50, "levels": [
		["Bolt-roped sail", "Roped edges and reef bands", {}, {"speed": 0.03}],
		["Jib", "A headsail out to the bowsprit", {}, {"speed": 0.03}],
		["Longer yard", "A longer yard and a wider sail", {"canvas": 4, "timber": 2}, {"speed": 0.03}],
		["Studding sails", "Booms and sails out past the yard's ends", {"canvas": 6, "timber": 4}, {"speed": 0.03}],
		["Full canvas", "The biggest mainsail she'll carry, and a pennant", {"canvas": 8, "copper": 1}, {"speed": 0.03}],
	]},
	"rudder": {"name": "Rudder & helm", "group": "Helm", "legacy": 5, "base": 40, "levels": [
		["Iron pintles", "Her rudder hung on iron", {}, {"turn": 0.06}],
		["Brass wheel", "A brass-rimmed wheel", {}, {"turn": 0.06}],
		["Binnacle", "A compass binnacle by the wheel", {"timber": 2, "iron": 2}, {"turn": 0.06}],
		["Balanced blade", "A wider, balanced rudder blade", {"timber": 6, "iron": 4}, {"turn": 0.06}],
		["Carved taffrail", "A gilded taffrail over her stern", {"timber": 4, "copper": 3}, {"turn": 0.06}],
	]},
	"copper": {"name": "Copper bottom", "group": "Hull", "legacy": 0, "base": 120, "levels": [
		["Copper bow", "Copper sheathing at her bow", {"copper": 3}, {"speed": 0.02, "reef": 0.2}],
		["Copper waist", "Sheathed back to amidships", {"copper": 5}, {"speed": 0.02, "reef": 0.2}],
		["Coppered hull", "Copper from stem to stern", {"copper": 8}, {"speed": 0.02, "reef": 0.2}],
	]},
	"chaser": {"name": "Bow chaser", "group": "Guns", "legacy": 0, "base": 160, "levels": [
		["Bow chaser", "A gun on a step at the bow, firing ahead", {"iron": 4, "timber": 2}, {"chaser": 1}],
		["Chaser's locker", "A shot locker and a banded barrel", {"iron": 3}, {"chaser_dmg": 0.15}],
		["Bow platform", "A railed platform and a long barrel", {"timber": 6, "iron": 3}, {"chaser_dmg": 0.15, "chaser_range": 0.12}],
	]},
	"nest": {"name": "Crow's nest", "group": "Rig", "legacy": 0, "base": 70, "levels": [
		["Canvas hood", "A canvas hood over the nest", {"canvas": 3}, {"spot": 150}],
		["Lookout cabin", "Boards, windows and a roof aloft", {"timber": 6, "canvas": 2}, {"spot": 150}],
		["Great spyglass", "A brass spyglass on a swivel", {"copper": 3, "iron": 2}, {"spot": 200}],
	]},
	"ropes": {"name": "Yard ropes", "group": "Rig", "legacy": 0, "base": 90, "levels": [
		["Swinging ropes", "A rope at each end of the yard to swing on", {"timber": 2}, {"ropes": 2}],
	]},
	"lanterns": {"name": "Lanterns", "group": "Deck", "legacy": 0, "base": 40, "levels": [
		["Lantern string", "Paper lanterns from the mast to the bowsprit", {}, {"night": 0.03}],
		["Stern strings", "Strings aft to the quarterdeck", {"canvas": 2}, {"night": 0.03}],
		["Festival lights", "Lanterns round the nest and along the rails", {"canvas": 2, "copper": 1}, {"night": 0.03}],
	]},
	"rails": {"name": "Railings", "group": "Deck", "legacy": 0, "base": 60, "levels": [
		["Man-ropes", "Iron stanchions and ropes along the rails", {}, {"steady": 0.5}],
		["Balustrade", "A turned balustrade on the bulwarks", {"timber": 6}, {"steady": 0.5}],
		["Boarding nets", "Nets rigged along her waist", {"canvas": 4, "timber": 2}, {"board": 1}],
	]},
	"grove": {"name": "Tangerine grove", "group": "Deck", "legacy": 0, "base": 90, "levels": [
		["A tangerine tree", "A tree in a planter on the quarterdeck", {"timber": 2}, {"fruit": 1}],
		["Two trees", "Another tree beside it", {"timber": 3}, {"fruit": 1}],
		["The grove", "A third tree between them", {"timber": 4, "copper": 1}, {"fruit": 1}],
	]},
	"galley": {"name": "Galley & bunks", "group": "Cabin", "legacy": 0, "base": 60, "levels": [
		["Upper bunk", "A second bunk over the bed", {"timber": 3}, {"portions": 1}],
		["Galley range", "An oven, hanging pots, a chimney up through the deck", {"iron": 4}, {"portions": 1}],
		["Hammocks", "Hammocks slung under the beams", {"canvas": 4, "timber": 2}, {"portions": 1}],
	]},
	"chest": {"name": "Ship's hold", "group": "Cabin", "legacy": 0, "base": 100, "levels": [
		["Iron-bound chest", "Iron bands and a lock on the storage chest", {"iron": 2, "timber": 2}, {"slots": 2}],
		["Sea chests", "A sea chest at the bunk's foot and by the galley", {"timber": 6}, {"slots": 2}],
		["Cargo hatch", "A hatch to the hold and crates lashed by it", {"timber": 8, "iron": 4}, {"slots": 2}],
	]},
}
## What Tackett's yard at Brinehollow does (1.22, Zach: "many of the upgrades should be only seen for the first time
## at a city"): the basics; the rest are first offered by a city's shipwright (and the chain's harbour vendors).
const HOME_LINES := ["armour", "guns", "sails", "rudder", "chest"]
## The lines in the yard's order (grouped as GROUPS).
const ORDER := ["armour", "copper", "guns", "chaser", "sails", "nest", "ropes", "rudder", "lanterns", "rails", "grove", "galley", "chest"]

## How an effect reads (percent keys show amount x 100, count keys as they are).
const EFFECT_TEXT := {
	"hull": "+%d%% hull", "speed": "+%d%% speed", "turn": "+%d%% turning", "dmg": "+%d%% gun damage",
	"reload": "%d%% faster reload", "range": "+%d%% gun range", "guns": "+%d gun pair",
	"reef": "%d%% less from reefs", "chaser": "+%d gun firing ahead", "chaser_dmg": "+%d%% chaser damage",
	"chaser_range": "+%d%% chaser range", "spot": "ships and salvage on the compass +%d m",
	"night": "+%d%% speed at night", "steady": "%d%% steadier when rammed", "board": "%d fewer boarder",
	"fruit": "+%d tangerine tree", "portions": "+%d portion a dish at the galley", "slots": "+%d bag slots",
	"ropes": "%d ropes to swing on",
}
const COUNT_KEYS := ["guns", "chaser", "spot", "board", "fruit", "portions", "slots", "ropes"]


static func line(id: String) -> Dictionary:
	return LINES[id]


static func max_level(id: String) -> int:
	return (LINES[id]["levels"] as Array).size()


static func level(kit: Dictionary, id: String) -> int:
	return int(kit.get(id, 0))


## Level `lv` (0-based) of a line in gold, on the economy's curve.
static func price(id: String, lv: int) -> int:
	return Economy.upgrade_price(int(LINES[id]["base"]), lv)


## Level `lv` of a line as [name, what it is, gold, materials, effects].
static func entry(id: String, lv: int) -> Array:
	var e: Array = LINES[id]["levels"][lv]
	return [e[0], e[1], price(id, lv), e[2], e[3]]


## The next level's entry, [] at the top.
static func next(kit: Dictionary, id: String) -> Array:
	var lv := level(kit, id)
	return entry(id, lv) if lv < max_level(id) else []


## One effect summed over every line's levels so far.
static func total(kit: Dictionary, key: String) -> float:
	var t := 0.0
	for id in LINES.keys():
		var levels: Array = LINES[id]["levels"]
		for i in range(mini(level(kit, id), levels.size())):
			t += float((levels[i][3] as Dictionary).get(key, 0.0))
	return t


## An old save's refit (true) as a level of its line.
static func from_saved(id: String, v: Variant) -> int:
	if v is bool:
		return int(LINES[id]["legacy"]) if v else 0
	return clampi(int(v), 0, max_level(id))


static func effect_text(fx: Dictionary) -> String:
	var parts: Array = []
	for k in fx.keys():
		var amt := float(fx[k])
		parts.append(EFFECT_TEXT[k] % (int(amt) if k in COUNT_KEYS else roundi(amt * 100.0)))
	return ", ".join(parts)


## "150 gold, 4 timber" for a level.
static func cost_text(entry: Array) -> String:
	var parts: Array = ["%d gold" % int(entry[2])]
	var mats: Dictionary = entry[3]
	for id in mats.keys():
		parts.append("%d %s" % [int(mats[id]), ItemDB.get_item(id).display_name.to_lower()])
	return ", ".join(parts)


## What a captain's bag is short of for a level ("" = they can pay).
static func short_of(inv: InventoryComponent, entry: Array) -> String:
	var parts: Array = []
	var need := {"gold": int(entry[2])}
	need.merge(entry[3])
	for id in need.keys():
		var have := inv.count(id)
		if have < int(need[id]):
			parts.append("%d more %s" % [int(need[id]) - have, "gold" if id == "gold" else ItemDB.get_item(id).display_name.to_lower()])
	return ", ".join(parts)


## Take a level's price out of the bag (short_of was "").
static func pay(inv: InventoryComponent, entry: Array) -> void:
	inv.remove_item(ItemDB.get_item("gold"), int(entry[2]))
	var mats: Dictionary = entry[3]
	for id in mats.keys():
		inv.remove_item(ItemDB.get_item(id), int(mats[id]))
