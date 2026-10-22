extends SceneTree
## The axe's mastered guard (the Bearded Guard, Brute 15): before the node a double-tap of block changes nothing; owned,
## it switches to the guard (both hands on the haft, the head up past the left shoulder), the pick is in the save and the
## co-op snapshot, the combo comes straight out of it and the guard is back after; another double-tap switches back.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "boarding_axe"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func head() -> Vector3:
	return b.weapon.global_transform * Vector3(0, 0, WeaponDesigns.axe_head_z(str(b.weapon.mesh.get_meta("model", ""))))


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
			check("the Bearded Guard is the axe's (Brute, 15)", p.progression.has_flag("guard2_axe") and SkillTrees.node_def("a_guard2")["level"] == 15)
			TK.act("parry")
			until = TK.wait_ticks(8)
		4:
			TK.act("parry")
			until = TK.wait_secs(1.5)
		5:
			check("owned, a double-tap switches to it", b.guard2 and p.progression.guards.has("axe"))
			var right := (p.player_model.global_basis.x as Vector3).normalized()
			var h := head()
			var sh: Vector3 = b.arm_l.global_position
			check("the head up past the left shoulder (%.2f m up, %.2f m left)" % [h.y - sh.y, -(h - sh).dot(right)],
				h.y > sh.y - 0.05 and (h - sh).dot(right) < 0.05)
			var a: Vector3 = b.hand_r.global_position
			var s: Vector3 = (h - a).normalized()
			var off: Vector3 = b.hand_l.global_position - a
			var miss := (off - s * off.dot(s)).length()
			check("both hands on the haft (the left %.2f m off it)" % miss, miss < 0.12 and b.pole_lw > 0.9)
			check("the snapshot carries it", bool(HumanoidSync.pack(b)[HumanoidSync.FIELDS.find("guard2")]))
			var d: Dictionary = p.progression.to_dict()
			p.progression.guards = {}
			p.progression.from_dict(d)
			check("the save keeps it", p.progression.guards.has("axe"))
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(2)
		6:
			check("the combo comes straight out of it (%s)" % b.current_action(), b.current_action() == "axe_hack")
			until = TK.wait_ticks(1)
		7:
			if not p.is_free():
				return false
			until = TK.wait_secs(1.2)
		8:
			check("after it, the guard's back (left hand %.2f)" % b.pole_lw, b.guard2 and b.pole_lw > 0.9)
			TK.act("parry")
			until = TK.wait_ticks(8)
		9:
			TK.act("parry")
			until = TK.wait_secs(1.2)
		10:
			check("another double-tap: the brawler's guard, one hand (grip %.2f)" % b.pole_w, not b.guard2 and not p.progression.guards.has("axe") and b.pole_w < 0.05)
			return TK.done(fails)
	step += 1
	return false
