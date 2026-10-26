extends SceneTree
## 1.23 smarter enemies, punishing: a heavy whiffed in front of a grunt is answered within a second (it swings at you
## without waiting for a turn); and a brute (a hammer grunt) blocked three times grabs you: mash to break free and he
## reels.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var b
var G
var step := 0
var until := 0
var fails := 0
var answered := -1
var t0 := 0
var mashed := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass", "grunts": [
		{"post": Vector3(0.0, 0, -4.2), "role": "sword", "seed": 101},
		{"post": Vector3(30.0, 0, 0.0), "role": "hammer", "seed": 102}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if g and G and answered < 0 and step >= 3 and step <= 4 and g.state in [G.S.CLOSE, G.S.WIND, G.S.SWING]:
		answered = Engine.get_physics_frames()
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 2:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			p = stage.player
			g = stage.camp.grunts[0]
			b = stage.camp.grunts[1]
			b.process_mode = Node.PROCESS_MODE_DISABLED
			p.hurtbox.monitorable = false
			g.alert()
			until = TK.wait_secs(1.0)
		1:
			# no turn for it: the camp's turns are taken
			stage.camp._tokens = [b, b]
			stage.camp.max_attackers = 1
			g._cooldown = 3.0
			g._set_state(G.S.CIRCLE)
			# (the swing goes 40 degrees off to its side: in front of it, but nowhere near it)
			stage.camera_rig.rotation.y = 0.7
			p.player_model.rotation.y = 0.7
			until = TK.wait_secs(0.2)
		2:
			# a heavy swung at the air in front of it (it isn't hit: out of reach of the blow)
			g.hurtbox.monitorable = false
			p.state_machine.force_state("HeavyAttack", {})
			t0 = Engine.get_physics_frames()
			until = TK.wait_ticks(1)
		3:
			if p.current_state_name() == "HeavyAttack":
				return false
			g.hurtbox.monitorable = true
			until = TK.wait_secs(1.1)
		4:
			print("   grunt hp %.0f/%.0f state %d dist %.2f seen %s hit %s" % [g.health.current_health, g.health.max_health, g.state,
				g.global_position.distance_to(p.global_position), g._whiff_seen, g._whiff_hit])
			var secs := float(answered - t0) / Engine.physics_ticks_per_second
			check("a whiffed heavy is punished at once (%.2f s after it started)" % secs, answered > 0 and secs < 2.2)
			g.process_mode = Node.PROCESS_MODE_DISABLED
			b.process_mode = Node.PROCESS_MODE_INHERIT
			b.global_position = Vector3(0, b.global_position.y, -2.0)
			b.reset_physics_interpolation()
			b.alert()
			p.hurtbox.monitorable = true
			until = TK.wait_secs(0.8)
		5:
			for i in 3:
				b.blocked_by(p)
			check("blocked three times, the brute's next is a grab", b._grab_ready)
			b._cooldown = 0.0
			t0 = Engine.get_physics_frames()
		6:
			# (mash as soon as he has you)
			if p.current_state_name() != "Grabbed" and Engine.get_physics_frames() - t0 < 4 * Engine.physics_ticks_per_second:
				return false
			check("he grabs you (%s)" % p.current_state_name(), p.current_state_name() == "Grabbed")
		7:
			# mash
			p.input_buffer.buffer_action("light_attack")
			mashed += 1
			until = TK.wait_ticks(4)
			if mashed < 9:
				return false
			until = TK.wait_secs(0.3)
		8:
			check("mashing breaks free (%s)" % p.current_state_name(), p.current_state_name() != "Grabbed")
			check("...and he reels (state %d)" % b.state, b.state == G.S.STAGGER)
			return TK.done(fails)
	step += 1
	return false
