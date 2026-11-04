extends SceneTree
## 1.30 AI captains' personalities (CaptainBrain): rolled from the captain's name (the same twice); a duelist answers
## the captain's swings with parries most, a bulwark with blocks, a berserker leaves most unanswered; and an AI captain
## jumps in now and then (a plunge onto the captain from a few metres, then a cooldown).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var r
var kinds := ["duelist", "bulwark", "berserker"]
var ki := 0
var swings := 0
var answers := {}
var plunged := false
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func duel() -> Script:
	return load("res://scripts/ai/rival_duel.gd")


func face(a: Node3D, b: Node3D) -> void:
	var d: Vector3 = b.global_position - a.global_position
	a.player_model.rotation.y = atan2(d.x, d.z) + PI


func _process(_d: float) -> bool:
	if r and is_instance_valid(r) and r.current_state_name() == "Plunge":
		plunged = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			var B: Script = load("res://scripts/ai/captain_brain.gd")
			check("rolled from the name, the same twice", B.roll_for("Rival_7") == B.roll_for("Rival_7"))
			until = TK.wait_ticks(1)
		1:
			# each personality in turn, a sharp one, the captain swinging at it
			p.health_component.current_health = p.health_component.max_health
			r = duel().spawn(p, 0.9, "cutlass")
			r.get_node("Brain").personality = kinds[ki]
			r.get_node("Brain")._jump_at = 1 << 40
			r.global_position = p.global_position + (-p.player_model.global_basis.z) * 2.0
			r.reset_physics_interpolation()
			swings = 0
			until = TK.wait_secs(1.0)
		2:
			if swings < 14:
				face(p, r)
				p.health_component.current_health = p.health_component.max_health
				if p.current_state_name() in ["Idle", "Move"]:
					TK.act("light_attack")
					swings += 1
				until = TK.wait_ticks(10)
				return false
			answers[kinds[ki]] = (r.get_node("Brain").answers as Dictionary).duplicate()
			r.queue_free()
			ki += 1
			if ki < kinds.size():
				step = 1
				until = TK.wait_ticks(3)
				return false
			var share := func(k: String, a: String) -> float:
				var d: Dictionary = answers[k]
				var n := 0
				for x in d:
					n += int(d[x])
				return float(d.get(a, 0)) / maxf(n, 1)
			print("ANSWERS ", answers)
			check("a duelist parries most", share.call("duelist", "parry") > share.call("bulwark", "parry") and share.call("duelist", "parry") > share.call("berserker", "parry"))
			check("a bulwark blocks most", share.call("bulwark", "block") > share.call("duelist", "block") and share.call("bulwark", "block") > share.call("berserker", "block"))
			check("a berserker leaves most unanswered", share.call("berserker", "none") > share.call("duelist", "none") and share.call("berserker", "none") > share.call("bulwark", "none"))
			until = TK.wait_ticks(3)
		3:
			r = duel().spawn(p, 0.9, "cutlass")
			r.global_position = p.global_position + (-p.player_model.global_basis.z) * 5.5
			r.reset_physics_interpolation()
			r.get_node("Brain")._jump_at = 0
			p.hurtbox.monitorable = false
			until = TK.wait_secs(5.0)
		4:
			check("an AI captain jumps in with a plunge", plunged)
			check("then waits its cooldown (%.1f s)" % ((r.get_node("Brain")._jump_at - Engine.get_physics_frames()) / 60.0), r.get_node("Brain")._jump_at - Engine.get_physics_frames() > 60 * 4)
			return TK.done(fails)
	step += 1
	return false
