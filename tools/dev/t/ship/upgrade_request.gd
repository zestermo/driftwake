extends SceneTree
## Buying a level goes through the host (any captain can pay, Net.request_upgrade): paid for at the level she
## has, it goes on her; paid for at a level a crewmate already bought, the host refuses it and the whole
## price (gold and salvage) comes back to the payer's bag.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			var p = stage.player
			var ship = stage.ship
			var inv = p.inventory_component
			var gold = load("res://resources/items/gold.tres")
			inv.remove_item(gold, inv.count("gold"))
			inv.add_item(gold, 1000)
			inv.add_item(load("res://resources/items/timber.tres"), 4)
			var menu = root.get_node("GameMenu")
			var yard = menu._yard
			menu.open("yard")
			yard.order("armour", 0)
			check("paid at the level she has: it goes on her", int(ship.kit["armour"]) == 1 and inv.count("gold") == 940)
			yard.order("armour", 0)
			check("paid for a level a crewmate already bought: refused, the gold comes back (%s)" % yard._note.text,
				int(ship.kit["armour"]) == 1 and inv.count("gold") == 940 and yard._note.text.contains("already paid"))
			ship.apply_kit(ship.kit.merged({"armour": 2}, true))
			root.get_node("GameManager").ship_kit = ship.kit.duplicate()
			yard.order("armour", 1)
			check("...and the salvage too", int(ship.kit["armour"]) == 2 and inv.count("gold") == 940 and inv.count("timber") == 4)
			yard.order("armour", 2)
			check("the next one goes through (150 gold, 4 timber)", int(ship.kit["armour"]) == 3 and inv.count("gold") == 790 and inv.count("timber") == 0)
			menu.close()
			return TK.done(fails)
	step += 1
	return false
