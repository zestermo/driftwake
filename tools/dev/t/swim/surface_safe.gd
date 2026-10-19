extends SceneTree
## A captain without a Devil Fruit never drowns swimming on the surface: worn out and paddling for a long
## stretch, the head stays out, breath stays full and no health is lost.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sw
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var low_breath := INF


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"water": true, "hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(_d: float) -> bool:
	if sw and step >= 2:
		low_breath = minf(low_breath, sw.breath)
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			sw = p.get_node("StateMachine/Swim")
			p.global_position = Vector3(stage.SHORE_X + 8.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(1.0)
		1:
			hp0 = p.health_component.current_health
			p.stamina = 0.0
			TK.press("move_right")
			TK.press("sprint")
			until = TK.wait_secs(12.0)
		2:
			TK.release("sprint")
			TK.release("move_right")
			check("12 s worn out at the surface: still swimming", p.current_state_name() == "Swim")
			check("...no health lost (%.1f -> %.1f)" % [hp0, p.health_component.current_health], is_equal_approx(p.health_component.current_health, hp0))
			check("...breath never spent (lowest %.2f of %.1f)" % [low_breath, sw.breath_max()], is_equal_approx(low_breath, sw.breath_max()))
			check("...not gasping", not sw.gasping)
			return TK.done(fails)
	step += 1
	return false
