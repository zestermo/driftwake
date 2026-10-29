extends SceneTree
## The compass strip is always up (1.26, docs/v1_26_plan.md "Navigation"): on foot, off the ship, with no chart marks,
## and it hides only for talks and scenes (and under the menus, which pause the HUD).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var c: Control = root.find_child("Compass", true, false) as Control
	match step:
		0:
			until = TK.wait_secs(0.5)
		1:
			check("on foot with no marks: the compass is up", c != null and c.visible)
			return TK.done(fails)
	step += 1
	return false
