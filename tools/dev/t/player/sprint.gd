extends SceneTree
## Sprinting tops out at ~9 m/s and drains stamina; run dry, you're winded and drop back to the jog.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var max_spd := 0.0
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


func _physics_process(_d: float) -> bool:
	if step == 1:
		max_spd = maxf(max_spd, Vector2(p.velocity.x, p.velocity.z).length())
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			check("sprint speed is 9", is_equal_approx(p.sprint_speed, 9.0))
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(1.2)
		1:
			TK.release("move_forward")
			TK.release("sprint")
			check("sprint tops out at ~9 m/s (%.2f)" % max_spd, max_spd > 8.5 and max_spd < 9.5)
			check("sprinting drains stamina (%.1f)" % p.stamina, p.stamina < 90.0)
			# run the bar dry mid-sprint
			p.stamina = 3.0
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(0.8)
		2:
			var hv := Vector2(p.velocity.x, p.velocity.z).length()
			check("winded: sprint stops when empty (speed %.2f, winded %s)" % [hv, p.winded], p.winded and hv < 6.5)
			TK.release("move_forward")
			TK.release("sprint")
			return TK.done(fails)
	step += 1
	return false
