extends SceneTree
## A reef shark prowling the atoll's deep basin (1.30, AtollDeepLife.Prowler): a diver who comes close sees it turn on
## them, then it charges and bites; it goes back to its circle and leaves them be for a while.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var shark
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var h2 := 0.0


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
			p.global_position = Vector3(stage.SHORE_X + 20.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			var DL = load("res://scripts/island/themes/atoll_deeplife.gd")
			shark = DL.Prowler.new()
			shark.mesh = DL.shark_mesh()
			shark.ring_r = 4.0
			shark.depth = 0.0
			shark.turn = 0.05
			stage.add_child(shark)
			shark.global_position = Vector3(stage.SHORE_X + 20.0, -3.0, 0)
			p.health_component.max_health = 500.0
			p.health_component.current_health = 500.0
			hp0 = 500.0
			until = TK.wait_secs(0.5)
		1:
			check("the shark notices the diver and turns on them", int(shark.get("_mode")) >= 1)
			p.health_component.health_changed.connect(func(h: float, _m: float) -> void: hp0 = minf(hp0, h))
			until = TK.wait_secs(1.6)
		2:
			check("...charges and bites (lowest %.0f of 500)" % hp0, hp0 < 495.0)
			hp0 = p.health_component.current_health
			h2 = hp0
			until = TK.wait_secs(3.0)
		3:
			check("...then leaves them be a while (lowest %.0f since, %.0f then)" % [hp0, h2], hp0 >= h2 - 0.01)
			return TK.done(fails)
	step += 1
	return false
