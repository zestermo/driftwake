class_name ShipClasses
extends RefCounted
## The crew's ships (docs/v1_21_plan.md, piece 5): the sloop they start with and the caravel the canal city's arsenal
## builds. A class changes how she handles and what she carries, not her deck: every class shares the sloop's layout
## (HullBuilder: the deck, the cabin, the helm, the nest, the gun ports), so every job aboard works the same; the
## caravel shows a lateen mizzen aft (ShipParts). The crew sails one at a time; the others are laid up with their own
## upgrades and paint (the kit's "fleet") and taken out again at a shipwright. In the ship kit (ShipKit): "class" and
## "fleet" {class: that ship's kit without those two}, synced like the rest of it (Net.set_ship_kit).
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
}
## What goes with a ship when she's laid up: everything in the kit but these.
const SHARED := ["class", "fleet"]


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
	out["class"] = cls
	out["fleet"] = fleet
	return out


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
