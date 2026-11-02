extends SceneTree
## The galley pantry (1.29): aboard, Stow food moves every food and ingredient stack from the bag into it (timber
## stays); it holds 24 stacks, 8 more a Galley & bunks level; cooking takes from the pantry first, then the bag; one
## comes back out a click at a time; it's GameManager.pantry (saved with the ship); ashore there's none to cook from.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var ship
var inv
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


func give(id: String, n: int) -> void:
	inv.add_item(ItemDB.get_item(id), n)


func in_pantry(id: String) -> int:
	var n := 0
	for st in ship.pantry.contents:
		if st.item.id == id:
			n += st.quantity
	return n


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var F = load("res://scripts/items/food.gd")
	match step:
		0:
			p = stage.player
			ship = stage.ship
			inv = p.inventory_component
			check("ashore: no pantry to cook from", F.pantry_of(p) == null)
			for st in inv.items.duplicate():
				if F.is_food(st.item):
					inv.remove_item(st.item, st.quantity)
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * (ship.layout.pantry_at + Vector3(-0.8, 0.1, 0))
			p.reset_physics_interpolation()
			until = TK.wait_ticks(10)
		1:
			check("aboard: the galley pantry", F.pantry_of(p) == ship.pantry)
			check("24 stacks to start, 8 more a Galley & bunks level", ship.pantry_slots() == 24)
			give("fish", 2)
			give("rice", 2)
			give("timber", 3)
			var n: int = F.stow_all(p, ship.pantry, ship.pantry_slots())
			check("Stow food: the fish and the rice go in (%d stacks)" % n, in_pantry("fish") == 2 and in_pantry("rice") == 2 and inv.count("fish") == 0 and inv.count("rice") == 0)
			check("...the timber stays in the bag", inv.count("timber") >= 3 and in_pantry("timber") == 0)
			check("...it's the ship's saved pantry", root.get_node("GameManager").pantry.size() == ship.pantry.contents.size())
			give("fish", 1)
			var use: Array = F.picks(inv, "fish_stew", ship.pantry)
			check("cooking takes from the pantry first", use.size() == 2 and use.all(func(u): return u[2]))
			check("Quick cook from the pantry", F.cook(p, "fish_stew", 1) == "" and inv.count("fish_stew") == 1)
			check("...one fish and one rice out of the pantry, the bag's fish untouched", in_pantry("fish") == 1 and in_pantry("rice") == 1 and inv.count("fish") == 1)
			ship.pantry.take(0, p, 1)
			check("one comes back out at a time", in_pantry("fish") + in_pantry("rice") == 1)
			ship.apply_kit({"galley": 3})
			check("Galley & bunks 3: 48 stacks", ship.pantry_slots() == 48)
			return TK.done(fails)
	step += 1
	return false
