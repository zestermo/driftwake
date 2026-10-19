extends SceneTree
## Tackett's yard as a tree of lines: a button per line with the next level's price, the levels as pips;
## buying takes the price and puts the next level on her; short of the price, nothing happens and the note
## says what's missing; a line at its top reads MAX.
const TK := preload("res://tools/dev/test_kit.gd")
var LINES
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
			LINES = load("res://scripts/ship/ship_lines.gd")
			var p = stage.player
			var ship = stage.ship
			var inv = p.inventory_component
			var gold = load("res://resources/items/gold.tres")
			inv.remove_item(gold, inv.count("gold"))
			var menu = root.get_node("GameMenu")
			var yard = menu._yard
			menu.open("yard")
			check("the yard has a button and pips for every line", yard._buy.size() == LINES.ORDER.size() and yard._pips.size() == LINES.ORDER.size())
			check("the next level's price is on its button", yard._buy["armour"].text == "60g")
			yard.buy("armour")
			check("no gold, no work, and the note says what's short (%s)" % yard._note.text, int(ship.kit["armour"]) == 0 and yard._note.text.contains("60 more gold"))
			inv.add_item(gold, 500)
			yard.buy("armour")
			check("bought: the gold's gone, she has level 1", inv.count("gold") == 440 and int(ship.kit["armour"]) == 1 and ship.parts.pieces("armour") == 1)
			check("...and the button moves on to the next price (on the curve: %s)" % yard._buy["armour"].text, yard._buy["armour"].text == "%dg" % LINES.price("armour", 1) and LINES.price("armour", 1) == 95)
			ship.apply_kit(ship.kit.merged({"rudder": LINES.max_level("rudder")}, true))
			yard._refresh()
			check("a line at its top reads MAX", yard._buy["rudder"].text == "MAX" and yard._buy["rudder"].disabled)
			# higher levels want salvage too
			root.get_node("Net").set_ship_kit(ship.kit.merged({"armour": 2}, true))
			yard.buy("armour")
			check("level 3 wants timber as well: refused without it (%s)" % yard._note.text, int(ship.kit["armour"]) == 2 and yard._note.text.contains("4 more ship's timber"))
			inv.add_item(load("res://resources/items/timber.tres"), 5)
			yard.buy("armour")
			check("...with it, the gold and the timber go and she has level 3", int(ship.kit["armour"]) == 3 and inv.count("timber") == 1 and inv.count("gold") == 290)
			check("the yard shows the salvage in your bag (%s)" % yard._gold.text, yard._gold.text.contains("1 timber"))
			yard._describe("guns")
			check("hovering a line says what its next level does (%s)" % yard._note.text, yard._note.text.contains("Shot racks") and yard._note.text.contains("+5% gun damage"))
			menu.close()
			return TK.done(fails)
	step += 1
	return false
