extends SceneTree
## Cooking on the action wheel: ashore with no fire there's no Cook; by a camp's fire "Cook by the fire" shows
## and opens the galley screen for one portion a dish.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var AW
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
			AW = load("res://scripts/game/action_wheel.gd")
			check("ashore with no fire: no Cook (%s)" % str(AW.entries_for(p)), not AW.entries_for(p).has("cook_camp") and not AW.entries_for(p).has("cook"))
			load("res://scripts/game/camp.gd").make(p)
			until = TK.wait_ticks(4)
		1:
			p.state_machine.force_state("Idle", {})
			until = TK.wait_ticks(2)
		2:
			check("by the camp's fire: Cook by the fire (%s)" % str(AW.entries_for(p)), AW.entries_for(p).has("cook_camp"))
			AW.run("cook_camp", p)
			var gm = root.get_node("GameMenu")
			check("it opens the galley screen, one portion a dish", gm._current == "galley" and gm._galley.portions == 1)
			gm.close()
			return TK.done(fails)
	step += 1
	return false
