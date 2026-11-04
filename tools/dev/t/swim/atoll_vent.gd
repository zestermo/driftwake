extends SceneTree
## A breathing vent in the atoll's deep basin (1.30, AtollBasin.Vent): a diver low on breath in its column gets it back
## (VENT_REFILL s a second), one beside it doesn't.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sw
var vent
var step := 0
var until := 0
var fails := 0
var b0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


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
			sw = p.get_node("StateMachine/Swim")
			vent = load("res://scripts/island/themes/atoll_basin.gd").Vent.new()
			stage.add_child(vent)
			vent.global_position = Vector3(stage.SHORE_X + 20.0, stage.SEA_FLOOR, 0)
			vent.depth = -stage.SEA_FLOOR
			p.global_position = Vector3(stage.SHORE_X + 20.0 + 6.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(0.6)
		1:
			TK.press("dodge")
			until = TK.wait_secs(1.0)
		2:
			TK.release("dodge")
			sw.breath = 4.0
			b0 = sw.breath
			until = TK.wait_secs(1.5)
		3:
			check("a diver beside the vent's column keeps losing breath (%.1f -> %.1f)" % [b0, sw.breath], sw.breath < b0)
			p.global_position = Vector3(stage.SHORE_X + 20.0, p.global_position.y, 0.3)
			p.reset_physics_interpolation()
			sw.breath = 4.0
			b0 = sw.breath
			until = TK.wait_secs(1.5)
		4:
			check("...in it, gets it back (%.1f -> %.1f)" % [b0, sw.breath], sw.breath > b0 + 4.0 and p.global_position.y < float(p.water_surface(p.global_position)) - 0.5)
			return TK.done(fails)
	step += 1
	return false
