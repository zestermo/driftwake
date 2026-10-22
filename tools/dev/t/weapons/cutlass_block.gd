extends SceneTree
## The cutlass block (Zach 2026-10-21): held, the blade is braced across the body (hand low right, point high left,
## edge out to the front), the free palm on its flat, the weight sunk over a bent front knee; a parry snaps into the
## same brace and the deflect shoves it out; the parry's window is unchanged.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
var step := 0
var until := 0
var fails := 0
var lift0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "cutlass"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


## [the blade's direction, the edge's direction, the free palm's distance from the blade's line, the sword hand from
## its shoulder]: the chest's frame.
func brace() -> Array:
	var c: Basis = b.torso.global_basis.orthonormalized().inverse()
	var wb: Basis = b.weapon.global_basis.orthonormalized()
	var blade: Vector3 = (wb * Vector3(0, 0, -1)).normalized()
	var a: Vector3 = b.hand_r.global_position
	var hl: Vector3 = b.hand_l.global_position
	var along := (hl - a).dot(blade)
	return [(c * blade).normalized(), (c * -(b.hand_r.global_basis.orthonormalized().y as Vector3)).normalized(),
		(hl - (a + blade * along)).length(), c * (a - b.arm_r.global_position), along]


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			b = p.body_model
			if not p.armed:
				TK.act("ready_weapon")
			until = TK.wait_secs(1.2)
		1:
			lift0 = b._lift.y
			TK.press("parry")
			until = TK.wait_secs(0.7)
		2:
			check("holding Q blocks (%s, %s)" % [p.current_state_name(), b.current_action()], p.current_state_name() == "Block" and b.current_action() == "guard_block")
			var r := brace()
			var bl: Vector3 = r[0]
			print("BRACE blade %s edge %s palm off %.3f at %.2f along, hand %s" % [bl, r[1], r[2], r[4], r[3]])
			check("the blade across the body: point up and to the left (%s)" % bl, bl.x < -0.5 and bl.y > 0.4 and absf(bl.z) < 0.5)
			check("the edge out to the front (%s)" % r[1], (r[1] as Vector3).z < -0.7)
			check("the free palm on the flat (%.3f m off the blade, %.2f m along)" % [r[2], r[4]], r[2] < 0.1 and r[4] > 0.25 and r[4] < 0.6)
			check("the weight sunk (hips %.3f lower than the guard)" % (lift0 - b._lift.y), lift0 - b._lift.y > 0.05)
			check("the front knee bent (%.2f)" % b.shin_l.rotation.x, b.shin_l.rotation.x < -0.6)
			TK.release("parry")
			until = TK.wait_secs(0.8)
		3:
			check("letting go drops the block (%s)" % b.current_action(), b.current_action() == "")
			check("the parry window unchanged (%.2f s)" % p.state_machine.get_node("Parry").parry_window, is_equal_approx(p.state_machine.get_node("Parry").parry_window, 0.26))
			b.play("sw_deflect", ActionSpecs.length("sw_deflect"))
			until = TK.wait_ticks(1)
		4:
			var r0 := brace()
			b.set_meta("h0", r0[3])
			until = TK.wait_secs(0.1)
		5:
			var r := brace()
			var dz: float = (b.get_meta("h0") as Vector3).z - (r[3] as Vector3).z
			check("the deflect shoves the blade out (%.2f m forward)" % dz, dz > 0.06)
			return TK.done(fails)
	step += 1
	return false
