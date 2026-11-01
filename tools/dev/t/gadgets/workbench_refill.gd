extends SceneTree
## Refilling (1.28): a spent gadget's charges come back at a workbench for its refill parts (and Tinkering xp); without
## them, or full, nothing's taken. A captain's camp has its own field bench, and the sloop has one on deck.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var camp


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
	var G = load("res://scripts/gadgets/gadgets.gd")
	match step:
		0:
			p = stage.player
			p.gadgets.give("smoke", 0)
			p.gadgets.owned["smoke"]["charges"] = 0
			var why: String = G.refill(p, "smoke")
			check("no blackpowder, no refill (%s)" % why, why.begins_with("Short of") and p.gadgets.charges("smoke") == 0)
			p.inventory_component.add_item(ItemDB.get_item("black_powder"), 1)
			check("one blackpowder refills it", G.refill(p, "smoke") == "" and p.gadgets.charges("smoke") == 3)
			check("...and it's used", p.inventory_component.count("black_powder") == 0)
			p.inventory_component.add_item(ItemDB.get_item("black_powder"), 1)
			check("a full one takes nothing", G.refill(p, "smoke") == "Already full" and p.inventory_component.count("black_powder") == 1)
			camp = load("res://scripts/game/camp.gd").place(self, 1, p.global_position + Vector3(4, 0, 0), 0.0)
			until = TK.wait_ticks(4)
		1:
			check("a camp has a field bench", camp.get_node_or_null("Workbench") != null)
			var ship = get_first_node_in_group("ship")
			check("the sloop has a bench on deck", ship != null and ship.find_child("Workbench", true, false) != null)
			var benches := get_nodes_in_group("workbenches")
			check("every bench can be used (%d)" % benches.size(), benches.size() >= 2 and benches.all(func(b): return b.get_node_or_null("Use") != null))
			return TK.done(fails)
	step += 1
	return false
