extends SceneTree
## The dagger's mastered guard (the Hidden Knife, Guard 15): before the node a double-tap of block changes nothing;
## owned, it switches to the hidden knife (the dagger held at the small of the back, its point out past the right hip),
## the sheath hangs down from the belt in both guards (not stood out from the hip), the pick is in the save and the
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
	stage = TK.stage(self, {"hud": false, "weapon": "dagger"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func tip() -> Vector3:
	return b.weapon.global_transform * Vector3(0, 0, b.weapon.mesh.get_aabb().position.z)


## How far down the sheath runs from the belt (world, 1 straight down).
func sheath_down() -> float:
	var s: Node3D = b._sheaths[0]
	return -(-(s.global_basis.z as Vector3).normalized()).y


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
			check("the crouch's sheath hangs down from the belt (%.2f down)" % sheath_down(), sheath_down() > 0.75)
			TK.act("parry")
			until = TK.wait_ticks(8)
		2:
			TK.act("parry")
			until = TK.wait_secs(1.0)
		3:
			check("before the node a double-tap changes nothing", not b.guard2 and p.progression.guards.is_empty())
			p.progression.master_all()
			check("the Hidden Knife is the dagger's (Guard, 15)", p.progression.has_flag("guard2_dagger") and SkillTrees.node_def("dg_guard2")["level"] == 15)
			TK.act("parry")
			until = TK.wait_ticks(8)
		4:
			TK.act("parry")
			until = TK.wait_secs(1.5)
		5:
			check("owned, a double-tap switches to it", b.guard2 and p.progression.guards.has("dagger"))
			var right := (p.player_model.global_basis.x as Vector3).normalized()
			var fwd := -(p.player_model.global_basis.z as Vector3).normalized()
			var hand: Vector3 = b.hand_r.global_position
			var hip: Vector3 = b.hips.global_position
			check("the knife hand at the back of the hip (%.2f m behind the hips)" % -(hand - hip).dot(fwd), (hand - hip).dot(fwd) < -0.03)
			check("the knife hand out to the side (%.2f m right of the hips)" % (hand - hip).dot(right), (hand - hip).dot(right) > 0.15)
			check("its point out past the right hip (%.2f m right of the hips)" % (tip() - hip).dot(right), (tip() - hip).dot(right) > 0.2)
			check("the sheath still hangs down (%.2f down)" % sheath_down(), sheath_down() > 0.75)
			check("the snapshot carries it", bool(HumanoidSync.pack(b)[HumanoidSync.FIELDS.find("guard2")]))
			var d: Dictionary = p.progression.to_dict()
			# (loaded into a fresh record: the live one would buy its nodes back against a level-1 captain's pool)
			var pr2 = load("res://scripts/progression/progression.gd").new()
			pr2.from_dict(d)
			check("the save keeps it", pr2.guards.has("dagger"))
			pr2.free()
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(2)
		6:
			check("the combo comes straight out of it (%s)" % b.current_action(), b.current_action() == "dg_stab")
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
			check("another double-tap: the crouch (grip %.2f)" % b.pole_w, not b.guard2 and not p.progression.guards.has("dagger") and b.pole_w < 0.05)
			return TK.done(fails)
	step += 1
	return false
