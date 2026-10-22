extends SceneTree
## Bare fists box: a boxer's guard (fists closed and up by the face, the lead fist out ahead of the rear), then the
## combo on the dummy, each blow landing: the jab (the lead fist driven out near straight), the cross, the lead hook
## and (with the tree's move) the rear uppercut; the right-click haymaker draws the fist up over the shoulder, then
## brings it through them and lands harder than any combo blow.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var taken := 0.0
var jab_reach := 0.0
var cock := -9.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "dummy": Vector3(0, 0, -1.5)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if p != null:
		var b = p.body_model
		if b.current_action() == "fs_jab":
			jab_reach = maxf(jab_reach, (b.hand_l.global_position - b.arm_l.global_position).length())
		if b.current_action() == "fs_hay":
			cock = maxf(cock, b.hand_r.global_position.y - p.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.get_node("Hurtbox").hit_received.connect(func(h, _a): taken += h.damage)
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.progression.owned["u_round"] = true
			TK.act("ready_weapon")
			until = TK.wait_secs(0.7)
		1:
			var b = p.body_model
			check("empty hands box (style %s, stance %s, fists %s)" % [p.style(), b.stance, b.fists], p.style() == "fist" and b.stance == "fist" and b.fists)
			var hl: Vector3 = b.hand_l.global_position - p.global_position
			var hr: Vector3 = b.hand_r.global_position - p.global_position
			check("the guard: both fists up by the face (%.2f / %.2f m)" % [hl.y, hr.y], hl.y > 1.3 and hr.y > 1.3)
			check("the lead fist out ahead of the rear one (%.2f vs %.2f m ahead)" % [-hl.z, -hr.z], -hl.z > -hr.z + 0.2)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		2:
			check("left click: the jab (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_jab")
			until = TK.wait_secs(0.2)
		3:
			check("the jab lands (%.0f), the lead arm driven out near straight (%.2f m from the shoulder)" % [taken, jab_reach], taken > 0.0 and jab_reach > 0.55)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		4:
			check("then the cross (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_cross")
			until = TK.wait_secs(0.25)
		5:
			check("the cross lands (%.0f)" % taken, taken > 0.0)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		6:
			check("then the lead hook (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_hook")
			until = TK.wait_secs(0.3)
		7:
			check("the hook lands (%.0f)" % taken, taken > 0.0)
			taken = 0.0
			TK.act("light_attack")
			until = TK.wait_ticks(4)
		8:
			check("with the tree's move, the rear uppercut (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_upper")
			until = TK.wait_secs(0.4)
		9:
			check("the uppercut lands (%.0f)" % taken, taken > 0.0)
			until = TK.wait_secs(1.0)
		10:
			if not p.is_free():
				return false
			p.global_position = stage.dummy.global_position + Vector3(0, 0.05, 1.8)
			p.reset_physics_interpolation()
			p.velocity = Vector3.ZERO
			taken = 0.0
			TK.act("heavy_attack")
			until = TK.wait_ticks(4)
		11:
			check("right click: the haymaker (%s)" % p.body_model.current_action(), p.body_model.current_action() == "fs_hay")
			until = TK.wait_secs(0.75)
		12:
			check("the fist drawn up over the shoulder (%.2f m) and brought through: it lands hard (%.0f)" % [cock, taken], cock > 1.5 and taken >= 25.0)
			return TK.done(fails)
	step += 1
	return false
