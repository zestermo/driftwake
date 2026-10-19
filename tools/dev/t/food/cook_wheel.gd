extends SceneTree
## Cooking on the action wheel: ashore with no fire Cook is greyed ("At a galley or campfire"); by a camp's fire it
## can be picked and opens the galley screen for one portion a dish.
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
			check("ashore with no fire: Cook greyed (%s)" % AW.why_not("cook", p), AW.entries_for(p).has("cook") and AW.why_not("cook", p) == "At a galley or campfire")
			load("res://scripts/game/camp.gd").make(p)
			until = TK.wait_ticks(4)
		1:
			p.state_machine.force_state("Idle", {})
			until = TK.wait_ticks(2)
		2:
			check("by the camp's fire: Cook can be done (%s)" % AW.why_not("cook", p), AW.why_not("cook", p) == "")
			AW.run("cook", p)
			var gm = root.get_node("GameMenu")
			check("it opens the galley screen, one portion a dish", gm._current == "galley" and gm._galley.portions == 1)
			gm.close()
			return TK.done(fails)
	step += 1
	return false
