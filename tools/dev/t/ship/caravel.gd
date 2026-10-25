extends SceneTree
## The caravel (ShipClasses, 1.21 piece 5): buying her short of the price changes nothing and says what's short; with
## it, the gold and the materials go and she's the crew's ship: faster (13 m/s top), quicker to turn and off the mark,
## a lighter hull (340), a bow chaser fitted, no quarterdeck guns even with that line bought, four more bag slots, her
## lateen mizzen up; the sloop laid up keeps her own upgrades and paint and has them again when she's taken out.
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
	var SC = load("res://scripts/ship/ship_classes.gd")
	var p = stage.player
	var ship = stage.ship
	var inv = p.inventory_component
	var menu = root.get_node("GameMenu")
	match step:
		0:
			# the sloop with an upgrade and paint of her own
			root.get_node("Net").set_ship_kit(ship.kit.merged({"guns": 2, "sail": 2}, true))
			check("the sloop: her quarterdeck guns on (two lines bought)", ship.get_node_or_null("ShipModel/CannonS2") != null)
			inv.remove_item(load("res://resources/items/gold.tres"), inv.count("gold"))
			inv.add_item(load("res://resources/items/gold.tres"), 1000)
			menu._ship_event("buy", "caravel")
			until = TK.wait_ticks(2)
		1:
			check("short of the price: still the sloop, the gold still there", SC.class_of(ship.kit) == "sloop" and inv.count("gold") == 1000)
			inv.add_item(load("res://resources/items/gold.tres"), 500)
			for id in ["timber", "canvas", "iron"]:
				inv.add_item(load("res://resources/items/%s.tres" % id), 6)
			menu._ship_event("buy", "caravel")
			until = TK.wait_ticks(2)
		2:
			check("bought: the caravel is the crew's ship", SC.class_of(ship.kit) == "caravel")
			check("...for 1,400 gold, 6 timber, 4 canvas, 2 iron", inv.count("gold") == 100 and inv.count("timber") == 0 and inv.count("canvas") == 2 and inv.count("iron") == 4)
			check("her hull lighter (%.0f)" % ship.max_hull, absf(ship.max_hull - 340.0) < 1.0)
			check("her top speed 13 m/s (x%.3f)" % ship._top_k, absf(ship.MAX_SPEED * ship._top_k - 13.0) < 0.05)
			check("quicker to turn (%.3f) and off the mark (%.2f)" % [ship.MAX_TURN * ship._turn_k, ship.ACCEL * ship._accel_k], absf(ship.MAX_TURN * ship._turn_k - 0.68) < 0.005 and absf(ship.ACCEL * ship._accel_k - 3.1) < 0.01)
			check("a bow chaser fitted, no quarterdeck guns", ship.get_node_or_null("ShipModel/CannonBow") != null and ship.get_node_or_null("ShipModel/CannonS2") == null)
			check("four more bag slots", load("res://scripts/loot/inventory_component.gd").bonus_slots == 4)
			check("her lateen mizzen up", ship.get_node_or_null("ShipModel/Mizzen") != null)
			check("fresh: none of the sloop's upgrades or paint", int(ship.kit["guns"]) == 0 and int(ship.kit["sail"]) == 0)
			menu._ship_event("switch", "sloop")
			until = TK.wait_ticks(2)
		3:
			check("the sloop out again with her own upgrades and paint", SC.class_of(ship.kit) == "sloop" and int(ship.kit["guns"]) == 2 and int(ship.kit["sail"]) == 2)
			check("...her guns back and no mizzen", ship.get_node_or_null("ShipModel/CannonS2") != null and ship.get_node_or_null("ShipModel/Mizzen") == null)
			check("...the caravel laid up", SC.owns(ship.kit, "caravel"))
			check("buying her again does nothing", SC.class_of(SC.switch_to(ship.kit, "caravel")) == "caravel" and (ship.kit["fleet"] as Dictionary).has("caravel"))
			return TK.done(fails)
	step += 1
	return false
