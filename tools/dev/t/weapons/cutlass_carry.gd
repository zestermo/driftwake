extends SceneTree
## The cutlass out of a move: in the guard the free (left) hand is up by the side, not back behind the shoulder; walking
## straight forward the run carry hangs the sword arm at the side (the hand not swung back behind the hip) with the
## blade trailed back, down and out to the right, so from the camera behind it reads as a diagonal.
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


func fwd() -> Vector3:
	return -(p.global_basis.z as Vector3).normalized()


func right() -> Vector3:
	return (p.global_basis.x as Vector3).normalized()


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
			until = TK.wait_secs(1.5)
		1:
			check("the cutlass guard (%s)" % b.stance, p.armed and b.stance == "sword")
			var off: Vector3 = b.hand_l.global_position - b.arm_l.global_position
			check("guard: the free hand up by the side (%.2f m ahead of its shoulder, %.2f out, %.2f up)" % [off.dot(fwd()), -off.dot(right()), off.y],
				off.dot(fwd()) > -0.2 and -off.dot(right()) > 0.25 and off.y > 0.05)
			TK.press("move_forward")
			until = TK.wait_secs(1.0)
		2:
			check("walking forward (%.1f m/s): the run carry (%.2f)" % [b.ground_speed, b.carry_w], b.ground_speed > 3.2 and b.carry_w > 0.95)
			var hand: Vector3 = b.hand_r.global_position - b.arm_r.global_position
			check("the sword hand at the side, not swung back behind the hip (%.2f m behind its shoulder)" % -hand.dot(fwd()), -hand.dot(fwd()) < 0.18)
			var blade: Vector3 = (b.weapon.global_basis * Vector3(0, 0, -1)).normalized()
			check("the blade trailed back, down and out to the right (back %.2f, down %.2f, out %.2f)" % [-blade.dot(fwd()), -blade.y, blade.dot(right())],
				-blade.dot(fwd()) > 0.35 and blade.y < -0.2 and blade.dot(right()) > 0.2)
			TK.release("move_forward")
			return TK.done(fails)
	step += 1
	return false
