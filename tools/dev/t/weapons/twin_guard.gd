extends SceneTree
## The twin daggers' mastered guard (the Viper, Guard 15): before the node a double-tap of block changes nothing;
## owned, it switches to the Viper (sunk low, the right dagger reared up by the face, the left low out ahead), the
## pick is in the save and the co-op snapshot, the combo comes straight out of it and the guard is back after;
## another double-tap switches back to the low cross.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "dagger"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func tip(w) -> Vector3:
	return w.global_transform * Vector3(0, 0, w.mesh.get_aabb().position.z)


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			b = p.body_model
			p.set_offhand(p.equipped_weapon.duplicate())
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
			check("two blades (%s); before the node a double-tap changes nothing" % p.style(), p.style() == "dual_dagger" and not b.guard2 and p.progression.guards.is_empty())
			p.progression.master_all()
			check("the Viper is the twin daggers' (Guard, 15)", p.progression.has_flag("guard2_dual_dagger") and SkillTrees.node_def("dd_guard2")["level"] == 15)
			TK.act("parry")
			until = TK.wait_ticks(8)
		4:
			TK.act("parry")
			until = TK.wait_secs(1.5)
		5:
			check("owned, a double-tap switches to it", b.guard2 and p.progression.guards.has("dual_dagger"))
			var fwd := -(p.player_model.global_basis.z as Vector3).normalized()
			var mid: Vector3 = (b.arm_r.global_position + b.arm_l.global_position) * 0.5
			var tr: Vector3 = tip(b.weapon)
			var tl: Vector3 = tip(b.offhand)
			var up := Vector3.UP
			var hr: Vector3 = b.hand_r.global_position
			check("the right dagger reared up by the face (hand %.2f m above the shoulders)" % (hr - mid).dot(up), (hr - mid).dot(up) > 0.0)
			check("its point down at them (%.2f below the hand)" % -(tr - hr).dot(up), (tr - hr).dot(up) < -0.05)
			check("the left one low out ahead (%.2f m ahead, %.2f below the shoulders)" % [(tl - mid).dot(fwd), -(tl - mid).dot(up)],
				(tl - mid).dot(fwd) > 0.15 and (tl - mid).dot(up) < -0.2)
			check("sunk low (lift %.2f)" % b._lift.y, b._lift.y < -0.25)
			check("side on (hips turned %.2f)" % b._cur["hips"].y, b._cur["hips"].y > 0.4)
			check("the snapshot carries it", bool(HumanoidSync.pack(b)[HumanoidSync.FIELDS.find("guard2")]))
			var d: Dictionary = p.progression.to_dict()
			# (loaded into a fresh record: the live one would buy its nodes back against a level-1 captain's pool)
			var pr2 = load("res://scripts/progression/progression.gd").new()
			pr2.from_dict(d)
			check("the save keeps it", pr2.guards.has("dual_dagger"))
			pr2.free()
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(2)
		6:
			check("the combo comes straight out of it (%s)" % b.current_action(), b.current_action() == "dd_1")
			until = TK.wait_ticks(1)
		7:
			if not p.is_free():
				return false
			until = TK.wait_secs(1.2)
		8:
			check("after it, the Viper is back (hips %.2f)" % b._cur["hips"].y, b.guard2 and b._cur["hips"].y > 0.4)
			TK.act("parry")
			until = TK.wait_ticks(8)
		9:
			TK.act("parry")
			until = TK.wait_secs(1.2)
		10:
			check("another double-tap: the low cross (hips %.2f)" % b._cur["hips"].y, not b.guard2 and not p.progression.guards.has("dual_dagger") and b._cur["hips"].y < 0.2)
			return TK.done(fails)
	step += 1
	return false
