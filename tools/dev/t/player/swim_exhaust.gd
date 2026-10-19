extends SceneTree
## A swimmer who runs out of stamina is exhausted: a slow float-paddle, no damage, and the stamina comes back
## while floating until they can swim properly again.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var tired_speed := 0.0


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
			p.global_position = Vector3(stage.SHORE_X + 6.0, 1.0, 0)
			p.reset_physics_interpolation()
			p.state_machine.force_state("Swim", {"entry_vy": 0.0, "quiet": true})
			until = TK.wait_secs(1.0)
		1:
			check("swimming (%s)" % p.current_state_name(), p.current_state_name() == "Swim")
			p.stamina = 0.0
			hp0 = p.health_component.current_health
			TK.press("move_right")
			TK.press("sprint")
			until = TK.wait_secs(2.5)
		2:
			var h := Vector2(p.velocity.x, p.velocity.z).length()
			print("   exhausted: hp ", hp0, " -> ", p.health_component.current_health, ", speed ", snappedf(h, 0.01), ", stamina ", snappedf(p.stamina, 0.1))
			check("exhausted for 2.5 s: no damage", is_equal_approx(p.health_component.current_health, hp0))
			check("...still swimming, not sunk or thrown out", p.current_state_name() == "Swim")
			check("...a slow paddle (%.2f m/s), no sprint" % h, h > 0.3 and h < 1.5)
			check("...stamina coming back while floating (%.1f)" % p.stamina, p.stamina > 3.0)
			TK.release("sprint")
			TK.release("move_right")
			until = TK.wait_secs(6.0)
		3:
			check("stamina back up to swimming again (%.1f)" % p.stamina, p.stamina > 30.0)
			check("...health untouched", is_equal_approx(p.health_component.current_health, hp0))
			TK.press("move_right")
			until = TK.wait_secs(1.2)
		4:
			var h := Vector2(p.velocity.x, p.velocity.z).length()
			check("normal swim speed again (%.2f m/s)" % h, h > 2.5)
			TK.release("move_right")
			return TK.done(fails)
	step += 1
	return false
