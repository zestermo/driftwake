extends SceneTree
## A cannon's other moves on a dummy close in front: right click swings the barrel into it like a club (a guard-breaking
## blow that knocks down); learned, Cannon Ram at a sprint drives the muzzle into them; Recoil Leap in the air fires
## straight down: the blast below knocks the dummy flat and throws you up.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var last
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.2), "weapon": "hand_cannon"})


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
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a):
				hits += 1
				last = h)
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.7)
		1:
			hits = 0
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		2:
			check("right click: the barrel swung like a club (%s)" % p.body_model.current_action(), p.current_state_name() == "HeavyAttack" and p.body_model.current_action() == "cn_bash")
			until = TK.wait_secs(0.7)
		3:
			check("it lands through a guard and knocks down (%d)" % hits, hits >= 1 and last.breaker and last.knockdown and not last.ranged)
			p.progression.master_all()
			until = TK.wait_secs(1.0)
		4:
			if not p.is_free():
				return false
			p._reset_ammo()
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 6.0)
			p.reset_physics_interpolation()
			hits = 0
			p.sprinting = true
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		5:
			check("at a sprint: Cannon Ram (%s)" % p.body_model.current_action(), p.body_model.current_action() == "cn_ram")
			until = TK.wait_secs(0.8)
		6:
			check("the muzzle drives into them and knocks them down (%d)" % hits, hits >= 1 and last.knockdown)
			until = TK.wait_secs(1.0)
		7:
			if not p.is_free():
				return false
			p._reset_ammo()
			p.global_position = stage.dummy.global_position + Vector3(0, 3.0, 1.2)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			hits = 0
			p.state_machine.force_state("Plunge", {})
			until = TK.wait_ticks(4)
		8:
			check("in the air: Recoil Leap (%s, %s)" % [p.current_state_name(), p.body_model.current_action()], p.current_state_name() == "Plunge" and p.body_model.current_action() == "cn_air")
			until = TK.wait_secs(0.3)
		9:
			check("fired straight down: the blast below knocks the dummy flat (%d)" % hits, hits >= 1 and last.knockdown)
			check("and throws you up (%.2f m/s)" % p.velocity.y, p.velocity.y > 3.0)
			check("it spent the load", p.ammo[0] == 0)
			return TK.done(fails)
	step += 1
	return false
