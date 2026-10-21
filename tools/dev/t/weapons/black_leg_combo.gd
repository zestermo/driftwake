extends SceneTree
## Black-leg, learned: empty hands fight with kicks (style and stance "black_leg"), the hands open, loose and up a
## little on guard (no boxer's fists); the combo's low, mid and high kicks each land on the dummy, each turning the
## hips over and the arms out against the leg; the right-click is Guillotine Heel (the leg up over the head, then
## down) and it lands.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var taken := 0.0
var top := -9.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -1.8)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func foot_r() -> Vector3:
	var b = p.body_model
	return b.shin_r.global_transform * Vector3(0, b.shin_l.position.y, 0) - p.global_position


func _process(_d: float) -> bool:
	if step >= 10 and p.body_model.current_action() == "bl_heavy":
		top = maxf(top, foot_r().y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.learn_black_leg()
			TK.act("ready_weapon")
			until = TK.wait_secs(0.7)
		1:
			check("learned, empty hands kick (%s, stance %s)" % [p.style(), p.body_model.stance], p.style() == "black_leg" and p.body_model.stance == "black_leg")
			var hr: Vector3 = p.body_model.hand_r.global_position - p.global_position
			var hl: Vector3 = p.body_model.hand_l.global_position - p.global_position
			check("on guard the hands are open (not fists), loose and up a little (%.2f / %.2f m)" % [hr.y, hl.y],
				not p.body_model.fists and hr.y > 0.85 and hl.y > 0.85 and hr.y < 1.4 and hl.y < 1.4)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(5)
		2:
			check("left click: the low kick (%s)" % p.body_model.current_action(), p.body_model.current_action() == "bl_1")
			until = TK.wait_secs(0.25)
		3:
			check("it lands (%.0f)" % taken, taken > 0.0)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		4:
			check("it flows into the mid kick (%s)" % p.body_model.current_action(), p.body_model.current_action() == "bl_2")
			until = TK.wait_secs(0.12)
		5:
			var piv: Vector3 = p.body_model.pivot.rotation
			var hips: Vector3 = p.body_model.hips.rotation
			check("the hips turned over the standing foot, leaning away (yaw %.2f, lean %.2f)" % [piv.y + hips.y, piv.z], piv.y + hips.y > 1.0 and piv.z > 0.1)
			var b = p.body_model
			var back: float = (b.hand_r.global_position - b.arm_r.global_position).dot(b.torso.global_basis.z.normalized())
			check("the right arm thrown down and back past the chest against the right leg (%.2f m behind the shoulder)" % back, back > 0.15)
			until = TK.wait_secs(0.15)
		6:
			check("the mid kick lands (%.0f)" % taken, taken > 0.0)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(6)
		7:
			check("then the high kick (%s)" % p.body_model.current_action(), p.body_model.current_action() == "bl_3")
			until = TK.wait_secs(0.35)
		8:
			check("the high kick lands (%.0f)" % taken, taken > 0.0)
			until = TK.wait_secs(1.0)
		9:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 1.9)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			taken = 0.0
			top = -9.0
			TK.act("heavy_attack")
			until = TK.wait_ticks(5)
		10:
			check("right click: Guillotine Heel (%s)" % p.body_model.current_action(), p.body_model.current_action() == "bl_heavy")
			until = TK.wait_secs(0.75)
		11:
			check("the heel came up over the head (%.2f m) and down: it lands (%.0f)" % [top, taken], top > 1.5 and taken > 0.0)
			return TK.done(fails)
	step += 1
	return false
