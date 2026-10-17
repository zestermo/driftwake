class_name ShipLines
extends RefCounted
## Tackett's upgrade lines for the crew's sloop: each a few small steps, every
## step paid for in gold (and, higher up, salvage) and every step showing on
## her (ShipParts builds them). The kit (ShipKit) holds each line's level as an
## int under the line's id; old saves' one-time refits (bools) become the
## line's `legacy` level, so nothing bought is lost.
##
## A level: [name, what it is, gold, materials {item id: n}, effects {key: amount}].
## Effects sum over every level a line has reached (total()):
##   hull (max hull), speed (top speed), turn (turn rate), dmg (gun damage),
##   reload (reload time cut), range (gun range), guns (the quarterdeck pair)

const GROUPS := ["Hull", "Guns", "Rig", "Helm"]

const LINES := {
	"armour": {"name": "Hull plating", "group": "Hull", "legacy": 5, "levels": [
		["Rubbing strakes", "Oak wales down both sides", 60, {}, {"hull": 0.08}],
		["Iron knees", "Iron straps amidships", 100, {}, {"hull": 0.08}],
		["Strapped hull", "Straps her whole length and an iron band", 150, {}, {"hull": 0.08}],
		["Iron stem", "An iron-shod bow", 200, {}, {"hull": 0.08}],
		["Capped rails", "Iron capping on her bulwarks", 260, {}, {"hull": 0.08}],
		["Plated quarters", "Riveted plates on her stern quarters", 340, {}, {"hull": 0.08}],
	]},
	"guns": {"name": "Gun deck", "group": "Guns", "legacy": 2, "levels": [
		["Shot racks", "A rack of shot by every gun", 50, {}, {"dmg": 0.05}],
		["Quarterdeck guns", "Two more swivel guns aft: three a side", 180, {}, {"guns": 1}],
		["Banded barrels", "Brass bands on every barrel", 160, {}, {"dmg": 0.05, "reload": 0.05}],
		["Gun shields", "Iron shields on the yokes", 220, {}, {"reload": 0.05}],
		["Long guns", "Longer barrels", 300, {}, {"dmg": 0.05, "range": 0.08}],
	]},
	"sails": {"name": "Sails & rigging", "group": "Rig", "legacy": 5, "levels": [
		["Bolt-roped sail", "Roped edges and reef bands", 50, {}, {"speed": 0.03}],
		["Jib", "A headsail out to the bowsprit", 90, {}, {"speed": 0.03}],
		["Longer yard", "A longer yard and a wider sail", 130, {}, {"speed": 0.03}],
		["Studding sails", "Booms and sails out past the yard's ends", 180, {}, {"speed": 0.03}],
		["Full canvas", "The biggest mainsail she'll carry, and a pennant", 240, {}, {"speed": 0.03}],
	]},
	"rudder": {"name": "Rudder & helm", "group": "Helm", "legacy": 5, "levels": [
		["Iron pintles", "Her rudder hung on iron", 40, {}, {"turn": 0.06}],
		["Brass wheel", "A brass-rimmed wheel", 80, {}, {"turn": 0.06}],
		["Binnacle", "A compass binnacle by the wheel", 120, {}, {"turn": 0.06}],
		["Balanced blade", "A wider, balanced rudder blade", 170, {}, {"turn": 0.06}],
		["Carved taffrail", "A gilded taffrail over her stern", 230, {}, {"turn": 0.06}],
	]},
}
## The lines in the yard's order (grouped as GROUPS).
const ORDER := ["armour", "guns", "sails", "rudder"]

## How an effect reads (percent keys show amount x 100).
const EFFECT_TEXT := {
	"hull": "+%d%% hull", "speed": "+%d%% speed", "turn": "+%d%% turning", "dmg": "+%d%% gun damage",
	"reload": "%d%% faster reload", "range": "+%d%% gun range", "guns": "+%d gun pair",
}
const COUNT_KEYS := ["guns"]


static func line(id: String) -> Dictionary:
	return LINES[id]


static func max_level(id: String) -> int:
	return (LINES[id]["levels"] as Array).size()


static func level(kit: Dictionary, id: String) -> int:
	return int(kit.get(id, 0))


## The next level's entry, [] at the top.
static func next(kit: Dictionary, id: String) -> Array:
	var lv := level(kit, id)
	var levels: Array = LINES[id]["levels"]
	return levels[lv] if lv < levels.size() else []


## One effect summed over every line's levels so far.
static func total(kit: Dictionary, key: String) -> float:
	var t := 0.0
	for id in LINES.keys():
		var levels: Array = LINES[id]["levels"]
		for i in range(mini(level(kit, id), levels.size())):
			t += float((levels[i][4] as Dictionary).get(key, 0.0))
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
