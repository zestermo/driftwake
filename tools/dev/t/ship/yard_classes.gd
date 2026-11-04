extends SceneTree
## (1.30) Buying and swapping the brig and galleon at the canal city's yard (ShipClasses, CanalLife._ship_choices,
## GameMenu._ship_event): Grane offers the caravel and the brig but not yet the galleon (he says why instead) until the
## crew's done at the canal city (its log pose set) or past it; short of the price nothing changes; with it the brig is
## the crew's, in the crew's paint and figurehead, the sloop laid up with her upgrades. Upgrades are per ship: the brig's
## gun deck level stays hers through a swap to the galleon (fresh, the paint carried) and back. Every ship owned is kept.
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


func _shown(choices: Array, text: String) -> bool:
	for c in choices:
		if str(c["text"]).contains(text):
			return not c.has("if") or bool((c["if"] as Callable).call())
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var SC = load("res://scripts/ship/ship_classes.gd")
	var p = stage.player
	var ship = stage.ship
	var inv = p.inventory_component
	var menu = root.get_node("GameMenu")
	var net = root.get_node("Net")
	match step:
		0:
			check("the galleon waits on the chain: not before the canal city's done, then for sale",
				SC.locked_why("galleon", 5, true) != "" and SC.locked_why("galleon", 6, false) != "" and SC.locked_why("galleon", 6, true) == "" and SC.locked_why("galleon", 8, false) == "" and SC.locked_why("brig", -1, false) == "")
			var choices: Array = []
			var nodes := {}
			load("res://scripts/island/canal_life.gd")._ship_choices(choices, nodes, true)
			check("Grane offers the caravel and the brig", _shown(choices, "buy the caravel") and _shown(choices, "buy the brig"))
			check("...not the galleon yet: he says why instead", not _shown(choices, "buy the galleon") and _shown(choices, "And a galleon") and str(nodes["galleon_wait"]["text"][0]).contains("galleon"))
			# the sloop in the crew's colours, a gun deck level of her own
			net.set_ship_kit(ship.kit.merged({"guns": 2, "hull": 3, "figure": 5, "sail": 2}, true))
			inv.remove_item(load("res://resources/items/gold.tres"), inv.count("gold"))
			inv.add_item(load("res://resources/items/gold.tres"), 9000)
			for id in ["timber", "canvas", "iron", "copper"]:
				inv.add_item(load("res://resources/items/%s.tres" % id), 40)
			menu._ship_event("buy", "galleon")
			until = TK.wait_ticks(2)
		1:
			check("the galleon can't be bought before it's for sale (still the sloop, nothing paid)", SC.class_of(ship.kit) == "sloop" and inv.count("gold") == 9000)
			menu._ship_event("buy", "brig")
			until = TK.wait_ticks(3)
		2:
			check("bought: the brig is the crew's ship", SC.class_of(ship.kit) == "brig" and ship.layout.cls == "brig")
			check("...for %s" % SC.price_text("brig"), inv.count("gold") == 9000 - 3200 and inv.count("timber") == 30 and inv.count("canvas") == 34 and inv.count("iron") == 34)
			check("...in the crew's paint, sails and figurehead", int(ship.kit["hull"]) == 3 and int(ship.kit["sail"]) == 2 and int(ship.kit["figure"]) == 5)
			check("...fresh: none of the sloop's upgrades (no quarterdeck guns)", int(ship.kit["guns"]) == 0 and ship.get_node_or_null("ShipModel/CannonS5") == null)
			check("...the sloop laid up with hers", SC.owns(ship.kit, "sloop") and int(ship.kit["fleet"]["sloop"]["guns"]) == 2)
			net.set_ship_kit(ship.kit.merged({"guns": 2}, true))
			until = TK.wait_ticks(2)
		3:
			check("the brig's own gun deck line: her quarterdeck pair on", ship.get_node_or_null("ShipModel/CannonS5") != null)
			net.request_ship("buy", "galleon")
			until = TK.wait_ticks(3)
		4:
			check("the galleon (once for sale): hers, fresh, in the crew's colours", SC.class_of(ship.kit) == "galleon" and int(ship.kit["guns"]) == 0 and int(ship.kit["hull"]) == 3)
			check("every ship kept: galleon, sloop, brig (%s)" % str(SC.owned(ship.kit)), SC.owned(ship.kit) == ["galleon", "sloop", "brig"])
			net.set_ship_kit(ship.kit.merged({"hull": 4}, true))
			menu._ship_event("switch", "brig")
			until = TK.wait_ticks(3)
		5:
			check("back on the brig: her own upgrades, the new paint", SC.class_of(ship.kit) == "brig" and int(ship.kit["guns"]) == 2 and int(ship.kit["hull"]) == 4 and ship.get_node_or_null("ShipModel/CannonS5") != null)
			var choices: Array = []
			load("res://scripts/island/canal_life.gd")._ship_choices(choices, {}, true)
			check("the yard offers to sail the sloop and the galleon, sells neither again", _shown(choices, "sail the sloop") and _shown(choices, "sail the galleon") and not _shown(choices, "buy the brig"))
			return TK.done(fails)
	step += 1
	return false
