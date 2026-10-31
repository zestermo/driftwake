extends SceneTree
## The debug menu (1.27, DebugMenu, F4 in a debug build): it lists every item and tree, gives items and gold, levels
## the Captain and a tree, feeds you a Driftfruit, and spawns grunts ahead of you.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var m
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
	var p = stage.player
	match step:
		0:
			m = load("res://scripts/game/debug_menu.gd").new()
			root.add_child(m)
			until = TK.wait_ticks(2)
		1:
			m._refill()
			check("every item and tree listed (%d items, %d trees)" % [m._items.item_count, m._trees.item_count], m._items.item_count >= 40 and m._trees.item_count > 20)
			var inv = p.inventory_component
			var g0: int = inv.count("gold")
			m._give("gold", 1000)
			check("+1000 gold (%d)" % (inv.count("gold") - g0), inv.count("gold") - g0 == 1000)
			var lv0: int = p.progression.level
			m._levels(1)
			check("Captain +1 (%d -> %d)" % [lv0, p.progression.level], p.progression.level == lv0 + 1)
			for i in range(m._trees.item_count):
				if m._trees.get_item_text(i) == "sword":
					m._trees.select(i)
			m._tree_levels(5)
			check("the cutlass tree +5 (%d)" % int(p.progression.mastery["sword"]["lv"]), int(p.progression.mastery["sword"]["lv"]) >= 6)
			for i in range(m._fruits.item_count):
				if m._fruits.get_item_text(i) == "storm":
					m._fruits.select(i)
			m._eat()
			check("ate the Storm Fruit", p.power.fruit == "storm")
			m._spawn(["sword", "rifle"])
			until = TK.wait_secs(1.0)
		2:
			var camps: Array = p.get_parent().find_children("DebugCamp*", "", false, false)
			check("two grunts spawned ahead of you (%d camps)" % camps.size(), camps.size() == 1)
			return TK.done(fails)
	step += 1
	return false
