extends SceneTree
## Quick stack (1.28): a chest's "Quick stack" puts in every bag stack of a kind it already holds, and nothing else
## (never the quick slot's item).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


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
			var db = load("res://scripts/loot/item_db.gd")
			var inv = p.inventory_component
			inv.add_item(db.get_item("fish"), 5)
			inv.add_item(db.get_item("crab_meat"), 3)
			var bag = (load("res://scenes/loot/loot_bag.tscn") as PackedScene).instantiate()
			stage.add_child(bag)
			bag.add_stack(db.get_item("fish"), 2)
			var moved: int = bag.quick_stack(p)
			check("one stack moved (%d)" % moved, moved == 1)
			check("the fish went in (bag %d, chest %d)" % [inv.count("fish"), _count(bag, "fish")], inv.count("fish") == 0 and _count(bag, "fish") == 7)
			check("the crab meat stayed in the bag (%d)" % inv.count("crab_meat"), inv.count("crab_meat") == 3)
			check("a second quick stack moves nothing", bag.quick_stack(p) == 0)
			bag.queue_free()
			return TK.done(fails)
	step += 1
	return false


func _count(bag, id: String) -> int:
	var n := 0
	for c in bag.contents:
		if c.item.id == id:
			n += c.quantity
	return n
