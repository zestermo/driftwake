extends SceneTree
## The cutlass out of a move: in the guard the free (left) hand is up by the side, not back behind the shoulder; walking
## keeps that guard in every direction (forward and a diagonal give the same arms, no carry: Zach 2026-10-21); a sprint
## eases into the carry, the sword hand moving there without a snap, then holds the blade up and back at one angle to the
## chest through the stride (no swinging round with the run: Zach 2026-10-21).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var b
var step := 0
var until := 0
var fails := 0
var fwd_pose := []
var last_hand := Vector3.ZERO
var max_jump := 0.0
var jump_tick := 0
var mid_w := -1.0
var ticks := 0
var blades := []
var min_clear := 9.0


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


func local(v: Vector3) -> Vector3:
	return Vector3(v.dot(right()), v.y, v.dot(fwd()))


## The arms in the chest's frame: each hand from its shoulder, the blade's direction.
func arms() -> Array:
	var c: Basis = b.torso.global_basis.orthonormalized().inverse()
	return [c * (b.hand_r.global_position - b.arm_r.global_position), c * (b.hand_l.global_position - b.arm_l.global_position),
		(c * (b.weapon.global_basis * Vector3(0, 0, -1))).normalized()]


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
			check("walking forward (%.1f m/s): no carry (%.2f)" % [b.ground_speed, b.carry_w], b.ground_speed > 3.2 and b.carry_w < 0.02)
			fwd_pose = arms()
			TK.press("move_right")
			until = TK.wait_secs(1.0)
		3:
			check("walking diagonally (%.1f m/s, travel %.2f rad): no carry (%.2f)" % [b.ground_speed, b._travel_ang, b.carry_w],
				absf(b._travel_ang) > 0.5 and b.carry_w < 0.02)
			var d := arms()
			var dh: float = ((d[0] as Vector3) - (fwd_pose[0] as Vector3)).length()
			var dl: float = ((d[1] as Vector3) - (fwd_pose[1] as Vector3)).length()
			var db: float = (d[2] as Vector3).dot(fwd_pose[2])
			check("the same guard forward and diagonal (sword hand %.2f m, free hand %.2f m apart, blade dot %.2f)" % [dh, dl, db],
				dh < 0.12 and dl < 0.12 and db > 0.95)
			TK.release("move_right")
			until = TK.wait_secs(1.0)
		4:
			last_hand = arms()[0]
			TK.press("sprint")
			until = TK.wait_ticks(1)
		5:
			var h: Vector3 = arms()[0]
			ticks += 1
			if (h - last_hand).length() > max_jump:
				max_jump = (h - last_hand).length()
				jump_tick = ticks
			last_hand = h
			if ticks == 5:
				mid_w = b.carry_w
			if ticks < 45:
				until = TK.wait_ticks(1)
				return false
			check("sprinting (%.1f m/s): the carry (%.2f)" % [b.ground_speed, b.carry_w], b.sprinting and b.carry_w > 0.95)
			check("the carry eases in (%.2f after 5 ticks)" % mid_w, mid_w > 0.05 and mid_w < 0.95)
			check("the sword hand eases into the carry, no snap (largest step %.3f m a tick, on tick %d)" % [max_jump, jump_tick],
				max_jump < 0.15 and jump_tick > 2)
			ticks = 0
			until = TK.wait_ticks(1)
		6:
			var bl: Vector3 = arms()[2]
			blades.append(bl)
			min_clear = minf(min_clear, b._blade_clear(b.hand_r)[0])
			ticks += 1
			if ticks < 60:
				until = TK.wait_ticks(1)
				return false
			var mean := Vector3.ZERO
			for v in blades:
				mean += v
			mean = mean.normalized()
			var worst := 0.0
			for v in blades:
				worst = maxf(worst, (v as Vector3).angle_to(mean))
			check("the blade held steady through the stride (%.2f rad at most off its mean over 60 ticks)" % worst, worst < 0.12)
			check("the blade up and back, not dangling (chest frame %s)" % mean, mean.y > 0.6 and mean.z > 0.1 and mean.x > -0.05)
			check("the blade clear of the head and chest (%.2f m)" % min_clear, min_clear > -0.05)
			TK.release("sprint")
			TK.release("move_forward")
			return TK.done(fails)
	step += 1
	return false
