extends SceneTree
## Twin axes past the combo (their tree mastered): Raider's Leap at a sprint lands, the parry crosses the axes in
## an X, the combo's fourth blow is Reaping Whirl and lands, Buzzsaw drops from the air and its landing hits, and
## the hook drags a grunt in from three paces.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var taken := 0.0
var grunt
var gap := 0.0
var last := Vector3.ZERO
var top_speed := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -2.4), "weapon": "boarding_axe",
		"grunts": [{"post": Vector3(0, 0, 45.0), "yaw": 0.0, "mode": "stand", "seed": 37}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func haft(w) -> Vector3:
	return -(w.global_basis.z as Vector3).normalized()


func _process(d: float) -> bool:
	if grunt != null and is_instance_valid(grunt) and d > 0.0:
		var flat: Vector3 = grunt.global_position - last
		flat.y = 0.0
		top_speed = maxf(top_speed, flat.length() / d)
		last = grunt.global_position
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.inventory_component.add_item(ItemDB.get_item("boarding_axe"), 1)
			p.set_offhand(ItemDB.get_item("boarding_axe"))
			# (the dummy heals to full when it would die: count what lands instead)
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			stage.camera_rig.rotation.y = 0.0
			p.progression.master_all()
			until = TK.wait_secs(0.6)
		1:
			taken = 0.0
			p.quick_draw = true
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		2:
			check("at a sprint, Raider's Leap (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dx_rush")
			until = TK.wait_secs(0.6)
		3:
			check("it lands (%.0f damage)" % taken, taken > 0.0)
			until = TK.wait_secs(0.8)
		4:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 2.2)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			p.state_machine.force_state("Parry", {})
			until = TK.wait_secs(0.15)
		5:
			var r: Vector3 = haft(p.body_model.weapon)
			var l: Vector3 = haft(p.body_model.offhand)
			check("the parry (%s): both axes up, crossed (%.2f / %.2f up, %.2f / %.2f across)" % [p.body_model.current_action(), r.y, l.y, r.x, l.x],
				p.body_model.current_action() == "parry" and r.y > 0.3 and l.y > 0.3 and signf(r.x) != signf(l.x))
			until = TK.wait_secs(0.8)
		6:
			if not p.is_free():
				return false
			p.remember_combo(3)
			taken = 0.0
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		7:
			check("mastered, the combo's fourth blow is Reaping Whirl (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dx_4")
			until = TK.wait_secs(0.7)
		8:
			check("it lands (%.0f damage)" % taken, taken > 0.0)
			until = TK.wait_secs(0.8)
		9:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 3.5, 1.6)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			taken = 0.0
			p.state_machine.force_state("Plunge", {})
			until = TK.wait_ticks(3)
		10:
			check("attacked in the air, Buzzsaw (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dx_dive")
			until = TK.wait_secs(1.0)
		11:
			check("it lands on the dummy (%.0f damage)" % taken, taken > 0.0)
			until = TK.wait_secs(0.6)
		12:
			if not p.is_free():
				return false
			grunt = stage.camp.grunts[0] if stage.camp else null
			check("a grunt to hook", grunt != null)
			if grunt == null:
				return TK.done(fails)
			var fwd := Vector3(0, 0, -1)
			p.global_position = grunt.global_position - fwd * 3.0 + Vector3(0, 0.05, 0)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			gap = (grunt.global_position - p.global_position).length()
			last = grunt.global_position
			top_speed = 0.0
			p.remember_combo(2)
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(4)
		13:
			check("the third blow is the hook (%s)" % p.body_model.current_action(), p.body_model.current_action() == "dx_3")
			until = TK.wait_secs(0.8)
		14:
			var now: float = (grunt.global_position - p.global_position).length()
			check("the hook drags the grunt in, faster than it walks (%.1f m -> %.1f m, %.1f m/s)" % [gap, now, top_speed], now < gap - 0.6 and top_speed > 7.0)
			return TK.done(fails)
	step += 1
	return false
