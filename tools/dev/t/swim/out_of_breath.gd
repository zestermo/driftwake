extends SceneTree
## Out of breath on a dive: warned (the meter, the gasp), steady damage while the head stays under, and it
## stops the moment you surface.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sw
var meter
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func head_under() -> float:
	var h: Vector3 = p.body_model.head.global_position
	return p.water_surface(h) - h.y


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			sw = p.get_node("StateMachine/Swim")
			meter = stage.hud.find_child("BreathMeter", true, false)
			p.global_position = Vector3(stage.SHORE_X + 8.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(1.0)
		1:
			check("no breath meter at the surface", not meter.visible)
			TK.press("dodge")
			until = TK.wait_secs(1.2)
		2:
			check("the breath meter shows on a dive", meter.visible)
			hp0 = p.health_component.current_health
			sw.breath = 0.6
			until = TK.wait_secs(0.4)
		3:
			check("...nothing lost before it's empty", p.health_component.current_health >= hp0 - 0.01)
			until = TK.wait_secs(2.4)
		4:
			var lost: float = hp0 - p.health_component.current_health
			print("   out of breath ~2 s: lost ", snappedf(lost, 0.1), " of ", p.health_component.max_health)
			check("out of breath: gasping (the warning's on)", sw.gasping)
			check("...steady damage under water (%.1f)" % lost, lost > p.health_component.max_health * 0.06 and lost < p.health_component.max_health * 0.25)
			check("...still alive and swimming", p.current_state_name() == "Swim" and p.health_component.current_health > 0.0)
			TK.release("dodge")
			TK.press("jump")
			until = TK.wait_secs(4.0)
		5:
			TK.release("jump")
			check("kicked up to the surface (head %.2f under)" % head_under(), head_under() < 0.05)
			check("...no longer gasping", not sw.gasping)
			hp0 = p.health_component.current_health
			until = TK.wait_secs(2.0)
		6:
			check("no more damage at the surface (%.1f -> %.1f)" % [hp0, p.health_component.current_health], p.health_component.current_health >= hp0 - 0.01)
			return TK.done(fails)
	step += 1
	return false
