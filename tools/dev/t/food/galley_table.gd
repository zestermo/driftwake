extends SceneTree
## 1.23 galley meals: a pot of several portions goes on the ship's galley table; a captain who takes a portion eats it
## with the COOK's strength and length (named for the cook), one fewer is left, and the last portion clears the table.
## Also the storage's Personal tab: a second, hidden chest by the shared one (group "ship_storage").
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var t
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"ship": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var net = root.get_node("Net")
	match step:
		0:
			p = stage.player
			t = load("res://scripts/ship/galley_table.gd").of(self)
			check("the ship has a galley table", t != null)
			var stores := get_nodes_in_group("ship_storage")
			check("the storage has a Shared and a Personal chest (%d)" % stores.size(), stores.size() == 2)
			net.table_serve("fish_stew", 2, "Kai", 1.5, 420.0)
			until = TK.wait_ticks(2)
		1:
			check("the pot is on the table (%s, %d)" % [t.dish(), t.left], t.meal == "fish_stew" and t.left == 2 and t.dish() == "Kai's Fisherman's Stew")
			net.table_take()
			until = TK.wait_ticks(2)
		2:
			var pr = p.progression
			check("a portion eaten with the cook's strength and length (k %.2f, %.0f s)" % [pr.meal_k, pr.meal_left],
				pr.meal == "fish_stew" and is_equal_approx(pr.meal_k, 1.5) and pr.meal_left > 400.0)
			check("...one left", t.left == 1)
			net.table_take()
			until = TK.wait_ticks(2)
		3:
			check("the last portion clears the table", t.meal == "" and t.left == 0)
			return TK.done(fails)
	step += 1
	return false
