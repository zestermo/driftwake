extends SceneTree
## The polearm's stance poses: standing it's the two-handed guard; running (above a walk) it's trailed low in the
## right hand, the head out ahead and down; Emperor's Bearing (Guard, mastery 10) plants it upright, butt on the
## ground, only after ~3 s with nothing played and never before the node; an attack comes straight out of it and the
## readied guard holds for a while after.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "spear"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func shaft() -> Vector3:
	return -(b.weapon.global_basis.z as Vector3).normalized()


func fwd() -> Vector3:
	return -(p.global_basis.z as Vector3).normalized()


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			b = p.body_model
			stage.camera_rig.rotation.y = p.rotation.y
			if not p.armed:
				TK.act("ready_weapon")
			until = TK.wait_secs(4.5)
		1:
			check("standing calm before the node: the two-handed guard, not planted (%.2f, left hand %.2f)" % [b.pole_plant_w, b.pole_lw],
				not b.pole_plant_ok and b.pole_plant_w == 0.0 and b.pole_lw > 0.9)
			TK.press("move_forward")
			until = TK.wait_secs(1.0)
		2:
			var s := shaft()
			check("running (%.1f m/s): one hand, the head out ahead and down (run %.2f, left hand %.2f, shaft ahead %.2f, down %.2f)"
				% [b.ground_speed, b.pole_run_w, b.pole_lw, s.dot(fwd()), s.y],
				b.ground_speed > 3.2 and b.pole_run_w > 0.9 and b.pole_lw < 0.1 and s.dot(fwd()) > 0.6 and s.y < -0.15)
			var head: Vector3 = b.weapon.global_transform * Vector3(0, 0, -WeaponDesigns.POLE_AHEAD)
			check("the head off the ground ahead (%.2f m up)" % (head.y - p.global_position.y), head.y - p.global_position.y > 0.03)
			TK.release("move_forward")
			until = TK.wait_secs(0.8)
		3:
			check("stopped, both hands back on it (%.2f)" % b.pole_lw, b.pole_run_w < 0.1 and b.pole_lw > 0.9)
			p.progression.master_all()
			check("mastered, Emperor's Bearing is the polearm's (Guard, 10)", b.pole_plant_ok and SkillTrees.node_def("pl_bearing")["level"] == 10)
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_secs(0.3)
		4:
			if not p.is_free():
				return false
			until = TK.wait_secs(1.5)
		5:
			check("1.5 s after an attack: still the readied guard (%.2f)" % b.pole_plant_w, b.pole_plant_w == 0.0)
			until = TK.wait_secs(2.6)
		6:
			var butt: Vector3 = b.weapon.global_transform * Vector3(0, 0, WeaponDesigns.POLE_BEHIND)
			check("calm 3 s and still: planted, the pole upright in one hand, its butt on the ground (%.2f, up %.2f, butt %.2f m)"
				% [b.pole_plant_w, shaft().y, butt.y - p.global_position.y],
				b.pole_plant_w > 0.95 and b.pole_lw < 0.1 and shaft().y > 0.9 and absf(butt.y - p.global_position.y) < 0.08)
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(1)
		7:
			check("an attack comes straight out of it (%s)" % b.current_action(), b.current_action() == "pole_thrust")
			until = TK.wait_secs(0.15)
		8:
			check("and the plant lets go (%.2f)" % b.pole_plant_w, b.pole_plant_w == 0.0)
			return TK.done(fails)
	step += 1
	return false
