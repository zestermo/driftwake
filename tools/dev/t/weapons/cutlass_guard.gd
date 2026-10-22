extends SceneTree
## The cutlass's mastered guard (the Easy Guard, Guard 15): before the node a double-tap of block changes nothing;
## owned, it switches to the easy guard (stood square, the blade hanging out and down clear of the right leg, the free
## hand on the sash), the pick is in the save and the co-op snapshot, the combo comes straight out of it and the guard
## is back after; another double-tap switches back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
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


func tip() -> Vector3:
	return b.weapon.global_transform * Vector3(0, 0, b.weapon.mesh.get_aabb().position.z)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			b = p.body_model
			if not p.armed:
				TK.act("ready_weapon")
			until = TK.wait_secs(1.5)
		1:
			TK.act("parry")
			until = TK.wait_ticks(8)
		2:
			TK.act("parry")
			until = TK.wait_secs(1.0)
		3:
			check("before the node a double-tap changes nothing", not b.guard2 and p.progression.guards.is_empty())
			p.progression.master_all()
			check("the Easy Guard is the cutlass's (Guard, 15)", p.progression.has_flag("guard2_sword") and SkillTrees.node_def("s_guard2")["level"] == 15)
			TK.act("parry")
			until = TK.wait_ticks(8)
		4:
			TK.act("parry")
			until = TK.wait_secs(1.5)
		5:
			check("owned, a double-tap switches to it", b.guard2 and p.progression.guards.has("sword"))
			var right := (p.player_model.global_basis.x as Vector3).normalized()
			var t := tip()
			var knee: Vector3 = b.shin_r.global_position
			var gap := (t - knee).dot(right)
			check("the blade hangs out and down clear of the leg (point %.2f m out from the knee, %.2f m below the hand)" % [gap, b.hand_r.global_position.y - t.y],
				gap > 0.3 and t.y < b.hand_r.global_position.y - 0.4)
			var sash: Vector3 = b.hips.global_transform * SwordMoves.SASH
			check("the free hand on the sash (%.2f m off it)" % b.hand_l.global_position.distance_to(sash), b.hand_l.global_position.distance_to(sash) < 0.12)
			check("the snapshot carries it", bool(HumanoidSync.pack(b)[HumanoidSync.FIELDS.find("guard2")]))
			var d: Dictionary = p.progression.to_dict()
			# (loaded into a fresh record: the live one would buy its nodes back against a level-1 captain's pool)
			var pr2 = load("res://scripts/progression/progression.gd").new()
			pr2.from_dict(d)
			check("the save keeps it", pr2.guards.has("sword"))
			pr2.free()
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(2)
		6:
			check("the combo comes straight out of it (%s)" % b.current_action(), b.current_action() == "slash_r")
			until = TK.wait_ticks(1)
		7:
			if not p.is_free():
				return false
			until = TK.wait_secs(1.2)
		8:
			check("after it, the guard's back (grip %.2f)" % b.pole_w, b.guard2 and b.pole_w > 0.9)
			TK.act("parry")
			until = TK.wait_ticks(8)
		9:
			TK.act("parry")
			until = TK.wait_secs(1.2)
		10:
			check("another double-tap: the swashbuckler's guard (grip %.2f)" % b.pole_w, not b.guard2 and not p.progression.guards.has("sword") and b.pole_w < 0.05)
			return TK.done(fails)
	step += 1
	return false
