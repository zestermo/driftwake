extends SceneTree
## The chain sickle's right click (the Reaping Whirl, reworked 2026-11-04): it plays sk_heavy, its hitbox opens and closes
## on the spec's window (ActionSpecs "hit", in physics ticks), it lands on the one in front, the weight goes out to full
## length and back without a pop (its reach from the left hand never jumps), and the body ends facing where it began
## (the two turns wrapped, no unwind).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hits := 0
var step := 0
var until := 0
var fails := 0
var t0 := 0
var opened := -1
var closed := -1
var far := 0.0
var jump := 0.0
var last_r := -1.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.0), "weapon": "chain_sickle"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_tick() -> void:
	var hb = p.sword_hitbox
	var t := Engine.get_physics_frames() - t0
	if hb.active and opened < 0:
		opened = t
	if not hb.active and opened >= 0 and closed < 0:
		closed = t


func _process(d: float) -> bool:
	if p and t0 > 0:
		_physics_tick()
		var parts: Array = p.body_model.get_meta("sickle_chain", [])
		if parts.size() == 2 and d > 0.0:
			var hand: Vector3 = p.body_model.hand_l.global_position
			var r := (parts[1] as Node3D).global_position.distance_to(hand)
			far = maxf(far, r)
			# (per frame, not per second: the hit-stop's slowed clock makes a frame's delta tiny)
			if last_r >= 0.0:
				jump = maxf(jump, absf(r - last_r))
			last_r = r
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(_h, _a): hits += 1)
			stage.camera_rig.rotation.y = 0.0
			until = TK.wait_secs(0.7)
		1:
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.6)
			p.player_model.rotation.y = 0.0
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			t0 = Engine.get_physics_frames()
			TK.act("heavy_attack")
			until = TK.wait_ticks(6)
		2:
			check("right click: the Reaping Whirl (%s)" % p.body_model.current_action(), p.body_model.current_action() == "sk_heavy")
			until = TK.wait_secs(1.6)
		3:
			var w := ActionSpecs.hit_seconds("sk_heavy") / WeaponDesigns.sickle(p.equipped_weapon.design, "speed")
			var tps := float(Engine.physics_ticks_per_second)
			check("the hitbox opens on the window (tick %d, spec %.0f)" % [opened, w.x * tps], opened >= 0 and absf(opened - w.x * tps) <= 4.0)
			# (the blow's hit-stop holds the state's clock a few ticks)
			var stop := 0.07 * tps
			check("and closes on it (tick %d, spec %.0f + %.0f hit-stop)" % [closed, w.y * tps, stop], closed >= 0 and closed >= w.y * tps - 4.0 and closed <= w.y * tps + stop + 4.0)
			check("it lands on the one in front (%d)" % hits, hits >= 1)
			check("the weight went out to full length (%.1f m)" % far, far > 4.5)
			check("and never popped (biggest change in its reach in a frame %.2f m)" % jump, jump < 1.8)
			check("the body ends facing ahead (pivot yaw %.2f)" % p.body_model.pivot.rotation.y, absf(wrapf(p.body_model.pivot.rotation.y, -PI, PI)) < 0.25)
			check("back to its feet (%s)" % p.state_machine.current_state.name, p.is_free())
			return TK.done(fails)
	step += 1
	return false
