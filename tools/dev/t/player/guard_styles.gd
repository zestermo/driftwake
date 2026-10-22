extends SceneTree
## Defense's guard style (variant at 7): Rolling Guard turns a dodge out of a block into a ~3 m roll that stays in the
## Block state, so a frontal blow mid-roll still glances off; Planted roots the guard (planted pose, no push-back,
## blocks cost 0.7x).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var pr
var g
var start := Vector3.ZERO
var cost0 := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass",
		"grunts": [{"post": Vector3(0, 0, -4.0), "yaw": 0.0, "mode": "stand", "seed": 37, "role": "sword"}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow() -> void:
	p.hurtbox.take_hit(g._hit_light, g)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			pr = p.progression
			g = stage.camp.grunts[0]
			g.set_physics_process(false)
			p.health_component.max_health = 99999.0
			p.health_component.current_health = 99999.0
			TK.press("parry")
			pr.owned["df_guard"] = true
			pr._own("df_rolling")
			p.state_machine.force_state("Block", {})
			until = TK.wait_secs(0.3)
		1:
			start = p.global_position
			TK.act("dodge")
			until = TK.wait_ticks(8)
		2:
			var st = p.state_machine.current_state
			check("mid-roll the state is still Block (%s)" % p.current_state_name(), p.current_state_name() == "Block" and st.rolling())
			p.stamina = p.max_stamina
			var hp0: float = p.health_component.current_health
			blow()
			check("a frontal blow mid-roll glances off (%.0f -> %.0f)" % [hp0, p.health_component.current_health], p.health_component.current_health == hp0 and p.stamina < p.max_stamina)
			until = TK.wait_secs(0.6)
		3:
			var moved: Vector3 = p.global_position - start
			moved.y = 0.0
			print("   rolled %.2f m" % moved.length())
			check("the roll covers ~3 m", moved.length() > 2.4 and moved.length() < 3.8)
			check("...and ends back in the guard (%s)" % p.current_state_name(), p.current_state_name() == "Block" and not p.state_machine.current_state.rolling())
			check("...the guard is not planted", not p.body_model.planted)
			p.stamina = p.max_stamina
			p.velocity = Vector3.ZERO
			blow()
			cost0 = p.max_stamina - p.stamina
			check("control: an ordinary guard is pushed back (%.2f)" % p.velocity.length(), p.velocity.length() > 0.1 and cost0 > 0.0)
			pr._switch("df_guard", 1)
			check("switched to Planted", pr.has_flag("guard_planted") and not pr.has_flag("rolling_guard"))
			p.state_machine.force_state("Idle", {})
			until = TK.wait_ticks(2)
		4:
			p.state_machine.force_state("Block", {})
			until = TK.wait_ticks(2)
		5:
			check("planted pose is up", p.body_model.planted)
			p.stamina = p.max_stamina
			p.velocity = Vector3.ZERO
			blow()
			var cost1: float = p.max_stamina - p.stamina
			check("Planted: no push-back (%.2f)" % p.velocity.length(), p.velocity.length() < 0.05)
			check("...blocks cost 0.7x (%.2f vs %.2f)" % [cost1, cost0], absf(cost1 - cost0 * 0.7) < 0.1)
			TK.release("parry")
			return TK.done(fails)
	step += 1
	return false
