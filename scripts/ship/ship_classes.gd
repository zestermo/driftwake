class_name ShipClasses
extends RefCounted
## The crew's ships (docs/v1_21_plan.md, piece 5): the sloop they start with and the caravel the canal city's arsenal
## builds. The sloop and caravel share the sloop's layout (the caravel shows a lateen mizzen aft); the 1.30 brig and
## galleon have their own (HullLayout._brig, _galleon: bigger hulls, more masts and guns, several rooms), built by the
## same HullBuilder, so every job aboard works the same. The crew sails one at a time; the others are laid up with
## their own upgrades (the kit's "fleet") and taken out again at a shipwright; her paint and figurehead go with the crew
## (LOOKS). In the ship kit (ShipKit): "class" and "fleet" {class: that ship's kit without those two}, synced like the
## rest of it (Net.set_ship_kit).
##
## A class: name, what it is, and over the sloop: speed / turn / accel (shares added to her own), hull (a share), its
## quarterdeck gun pair allowed (aft_guns), a bow chaser fitted, bag slots, and its price (gold and materials).
## The caravel's numbers: Zach's table (2026-10-24): 13 m/s, turn 0.68, accel 3.1, hull 340, no quarterdeck pair, a
## chaser, +4 slots, 1,400 gold + 12 salvage (6 timber, 4 canvas, 2 iron).

const CLASSES := {
	"sloop": {"name": "Sloop", "desc": "The crew's first ship: steady, a gun deck that grows, room for four.",
		"speed": 0.0, "turn": 0.0, "accel": 0.0, "hull": 0.0, "aft_guns": true, "chaser": false, "slots": 0},
	"caravel": {"name": "Caravel", "desc": "Light and quick, an explorer's ship: faster and quicker to turn, a bow chaser and a bigger hold, a lighter hull and no quarterdeck guns.",
		"speed": 2.0 / 11.0, "turn": 0.13 / 0.55, "accel": 0.5 / 2.6, "hull": -0.15, "aft_guns": false, "chaser": true, "slots": 4,
		"price": 1400, "mats": {"timber": 6, "canvas": 4, "iron": 2}},
	# (1.30, docs/v1_30_plan.md round 8; HullLayout._brig, _galleon) The gun ships: bigger, slower, much tougher, more
	# guns down the waist (the broadside from the helm fires them all). The numbers are the agent's, for Zach to tune.
	"brig": {"name": "Brig", "desc": "Two masts and a gun deck: five guns a side down her waist, a hull twice the sloop's, a cabin of two rooms. Slower to turn.",
		"speed": -1.0 / 11.0, "turn": -0.3, "accel": -0.15, "hull": 1.0, "aft_guns": true, "chaser": false, "slots": 6,
		"price": 3200, "mats": {"timber": 10, "canvas": 6, "iron": 6}},
	"galleon": {"name": "Galleon", "desc": "Three masts and two gun decks: ten guns a side, a bow chaser, a hull three times the sloop's, a high stern castle with a stateroom. Slow and stately.",
		"speed": -2.0 / 11.0, "turn": -0.5, "accel": -0.3, "hull": 2.0, "aft_guns": true, "chaser": true, "slots": 12,
		"price": 7500, "mats": {"timber": 18, "canvas": 10, "iron": 12, "copper": 4}, "after": GALLEON_AFTER},
}
## The galleon's sold once the crew's this far down the chain (Chain layers; the canal city is 6) with the log pose
## set there: the canal city's own island done, or the 15 minutes the lodestone takes.
const GALLEON_AFTER := 6
## Sold at the canal city's arsenal (Master Grane), in this order.
const FOR_SALE := ["caravel", "brig", "galleon"]
## What goes with a ship when she's laid up: everything in the kit but these. (1.30) Her paint, colours, flag and
## figurehead are the crew's, not one ship's: they carry over to whichever she sails (LOOKS).
const SHARED := ["class", "fleet"]
const LOOKS := ["hull", "sail", "field", "emblem", "mark", "figure", "rail", "spar", "deck", "stripe", "skull", "crossed", "headpiece"]


static func class_of(kit: Dictionary) -> String:
	var c := str(kit.get("class", "sloop"))
	return c if CLASSES.has(c) else "sloop"


static func of(kit: Dictionary) -> Dictionary:
	return CLASSES[class_of(kit)]


static func owns(kit: Dictionary, cls: String) -> bool:
	return class_of(kit) == cls or (kit.get("fleet", {}) as Dictionary).has(cls)


## The kit with `cls` sailing and the ship that was laid up with her upgrades; a ship never owned comes fresh
## (no upgrades, the default paint). Returns a new kit.
static func switch_to(kit: Dictionary, cls: String) -> Dictionary:
	var cur := class_of(kit)
	if cur == cls or not CLASSES.has(cls):
		return kit.duplicate(true)
	var fleet: Dictionary = (kit.get("fleet", {}) as Dictionary).duplicate(true)
	var laid := {}
	for k in kit.keys():
		if not k in SHARED:
			laid[k] = kit[k]
	fleet[cur] = laid
	var out: Dictionary = fleet.get(cls, ShipKit.fresh()).duplicate(true)
	fleet.erase(cls)
	for k in LOOKS:
		if kit.has(k):
			out[k] = kit[k]
	out["class"] = cls
	out["fleet"] = fleet
	return out


## Every ship the crew owns: the one she sails first, then the laid-up ones in CLASSES order.
static func owned(kit: Dictionary) -> Array:
	var out: Array = [class_of(kit)]
	for c in CLASSES:
		if c != out[0] and (kit.get("fleet", {}) as Dictionary).has(c):
			out.append(c)
	return out


## Why `cls` isn't for sale yet ("" when it is): the galleon waits on the chain. `layer`: the chain layer the crew's at
## (-1 Brinehollow's sea); `settled`: the log pose has set there.
static func locked_why(cls: String, layer: int, settled: bool) -> String:
	var after := int(CLASSES[cls].get("after", -1))
	if after < 0 or layer > after or (layer == after and settled):
		return ""
	return "Grane won't lay down a galleon for a crew he hasn't seen prove itself. Finish your business in these waters first."


## Can `inv` pay for `cls`? "" if so, else what's short.
static func short_of(inv: InventoryComponent, cls: String) -> String:
	var c: Dictionary = CLASSES[cls]
	if inv.count("gold") < int(c.get("price", 0)):
		return "%d gold" % int(c["price"])
	for id in (c.get("mats", {}) as Dictionary):
		if inv.count(id) < int(c["mats"][id]):
			return "%d %s" % [int(c["mats"][id]), id]
	return ""


static func pay(inv: InventoryComponent, cls: String) -> void:
	var c: Dictionary = CLASSES[cls]
	inv.remove_item(ItemDB.get_item("gold"), int(c.get("price", 0)))
	for id in (c.get("mats", {}) as Dictionary):
		inv.remove_item(ItemDB.get_item(id), int(c["mats"][id]))


static func price_text(cls: String) -> String:
	var c: Dictionary = CLASSES[cls]
	var parts := ["%s gold" % _thousands(int(c.get("price", 0)))]
	for id in (c.get("mats", {}) as Dictionary):
		parts.append("%d %s" % [int(c["mats"][id]), id])
	return ", ".join(parts)


static func _thousands(n: int) -> String:
	var s := str(n)
	return s if n < 1000 else "%s,%s" % [s.substr(0, s.length() - 3), s.substr(s.length() - 3)]
