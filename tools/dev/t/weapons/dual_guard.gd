extends SceneTree
## Dual wield's mastered guard (Wings, Guard 15): before the node a double-tap of block changes nothing; owned, it
## switches to Wings (chest pitched forward, both arms swept back, both blades behind the shoulders and out to their
## sides), the pick is in the save and the co-op snapshot, the combo comes straight out of it and the guard is back
## after; another double-tap switches back.
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
			check("two blades (%s); before the node a double-tap changes nothing" % p.style(), p.style() == "dual_sword" and not b.guard2 and p.progression.guards.is_empty())
			p.progression.master_all()
			check("Wings is dual wield's (Guard, 15)", p.progression.has_flag("guard2_dual") and SkillTrees.node_def("d_guard2")["level"] == 15)
			TK.act("parry")
			until = TK.wait_ticks(8)
		4:
			TK.act("parry")
			until = TK.wait_secs(1.5)
		5:
			check("owned, a double-tap switches to it", b.guard2 and p.progression.guards.has("dual"))
			var right := (p.player_model.global_basis.x as Vector3).normalized()
			var fwd := -(p.player_model.global_basis.z as Vector3).normalized()
			var mid: Vector3 = (b.arm_r.global_position + b.arm_l.global_position) * 0.5
			var tr: Vector3 = tip(b.weapon)
			var tl: Vector3 = tip(b.offhand)
			check("both blades swept back behind the shoulders (%.2f, %.2f m back)" % [-(tr - mid).dot(fwd), -(tl - mid).dot(fwd)],
				(tr - mid).dot(fwd) < -0.2 and (tl - mid).dot(fwd) < -0.2)
			check("and out to their sides (%.2f right, %.2f left)" % [(tr - mid).dot(right), -(tl - mid).dot(right)], (tr - mid).dot(right) > 0.4 and (tl - mid).dot(right) < -0.4)
			check("the chest pitched forward (%.2f)" % b._cur["torso"].x, b._cur["torso"].x < -0.4)
			check("the snapshot carries it", bool(HumanoidSync.pack(b)[HumanoidSync.FIELDS.find("guard2")]))
			var d: Dictionary = p.progression.to_dict()
			# (loaded into a fresh record: the live one would buy its nodes back against a level-1 captain's pool)
			var pr2 = load("res://scripts/progression/progression.gd").new()
			pr2.from_dict(d)
			check("the save keeps it", pr2.guards.has("dual"))
			pr2.free()
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(2)
		6:
			check("the combo comes straight out of it (%s)" % b.current_action(), b.current_action() == "dual_1")
			until = TK.wait_ticks(1)
		7:
			if not p.is_free():
				return false
			until = TK.wait_secs(1.2)
		8:
			check("after it, Wings is back (chest %.2f)" % b._cur["torso"].x, b.guard2 and b._cur["torso"].x < -0.4)
			TK.act("parry")
			until = TK.wait_ticks(8)
		9:
			TK.act("parry")
			until = TK.wait_secs(1.2)
		10:
			check("another double-tap: the paired guard (chest %.2f)" % b._cur["torso"].x, not b.guard2 and not p.progression.guards.has("dual") and b._cur["torso"].x > -0.3)
			return TK.done(fails)
	step += 1
	return false
