extends SceneTree
## Crouched, you get closer behind a standing sentry before it turns than you do standing.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var sentry
var near_d := 0.0
var stand_d := 0.0
var sneak := false
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -12), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "rifle"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func reset() -> void:
	sentry.global_position = sentry.post
	sentry.velocity = Vector3.ZERO
	sentry.reset_physics_interpolation()
	sentry._enter_idle()
	p.state_machine.force_state("Idle", {})
	p.global_position = Vector3(0, stage.GROUND_Y + 0.05, 8)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


## Start `d` m straight behind the sentry, standing or crouched.
func place_behind() -> void:
	var back: Vector3 = -sentry._fwd()
	p.global_position = sentry.global_position + back * near_d + Vector3.UP * 0.05
	p.velocity = Vector3.ZERO
	p.player_model.rotation.y = atan2(back.x, back.z)
	p.reset_physics_interpolation()
	if sneak and p.current_state_name() != "Crouch":
		p.state_machine.force_state("Crouch", {})
	elif not sneak and p.current_state_name() != "Idle":
		p.state_machine.force_state("Idle", {})


## A quarter metre closer every few ticks until the sentry turns; true while still creeping.
func approach_step() -> bool:
	if sentry.state != 0 or near_d <= 0.6:
		return false
	near_d -= 0.25
	place_behind()
	until = TK.wait_ticks(3)
	return true


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			sentry = stage.camp.grunts[0]
			check("the sentry stands its post", sentry.idle_mode != "sit")
			sneak = false
			near_d = 9.0
			place_behind()
			until = TK.wait_ticks(3)
		1:
			if approach_step():
				return false
			stand_d = near_d
			print("   standing: the sentry turned at %.2f m behind it" % near_d)
			reset()
			until = TK.wait_ticks(120)
		2:
			# (long enough for its delayed alarm to fire and be reset again, and the sentry to face its post)
			reset()
			until = TK.wait_ticks(120)
		3:
			sneak = true
			near_d = 9.0
			place_behind()
			until = TK.wait_ticks(3)
		4:
			if approach_step():
				return false
			print("   crouched: the sentry turned at %.2f m behind it" % near_d)
			check("crouched behind a grunt you get closer before it turns (%.2f m vs %.2f m standing)" % [near_d, stand_d], near_d < stand_d - 1.5 and near_d < 2.0)
			return TK.done(fails)
	step += 1
	return false
