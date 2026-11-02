extends SceneTree
## A crew feast (1.28): aboard the ship the galley lists the Harbour Feast as a crew feast; a quick cook of it
## feeds the captain straight away (their meal is the feast at the cook's strength), leaves none in the bag
## and takes the ingredients; ashore it can't be cooked.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var inv
var gm
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
			p = stage.player
			inv = p.inventory_component
			for e in [["fish", 3], ["rice", 2], ["seaweed", 2], ["salt", 1]]:
				inv.add_item(ItemDB.get_item(e[0]), e[1])
			check("ashore: the feast isn't cooked", Food.can_cook(p, "harbour_feast", 1) != "")
			p.global_position = stage.ship.to_global(Vector3(0.5, 0.6, 3.0))
			p.reset_physics_interpolation()
			until = TK.wait_ticks(20)
			step = 1
		1:
			check("aboard the crew's ship", Food.aboard(p))
			check("aboard: the feast can be cooked", Food.can_cook(p, "harbour_feast", 1) == "")
			gm = root.get_node("GameMenu")
			gm.open_galley(1)
			gm._galley._pick("harbour_feast")
			gm._galley.cook_selected()
			until = TK.wait_ticks(2)
			step = 2
		2:
			check("the captain is eating the feast (%s)" % p.progression.meal, p.progression.meal == "harbour_feast")
			check("none left in the bag", inv.count("harbour_feast") == 0)
			check("the ingredients are gone", inv.count("fish") == 0 and inv.count("rice") == 0)
			check("the feast's max health is on", p.progression.stat("max_hp") >= 30.0 - 0.01)
			gm.close()
			print("RESULT OK" if fails == 0 else "RESULT FAILED (%d)" % fails)
			quit(1 if fails else 0)
			step = 3
	return false
