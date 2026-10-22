extends SceneTree
## A greatsword on the move: carried in the right hand down at the side, the point trailing low behind, the same way
## walking forward, backing off and strafing (no forward-only switch); at a sprint the point drags on the ground and
## its sparks fly from the blade's point as drawn (within 0.15 m of it), not from under it or a frame behind.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var bm
var step := 0
var until := 0
var fails := 0
var fwd := Vector3.ZERO
var pending: Array = []
var sparks: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weapon": "greatsword"})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func tip() -> Vector3:
	var w: MeshInstance3D = bm.weapon
	return w.get_global_transform_interpolated() * Vector3(0, 0, w.mesh.get_aabb().position.z * 0.97)


## The point relative to the body (its right, up, back).
func tip_local() -> Vector3:
	var b: Basis = p.player_model.global_basis.orthonormalized()
	var rel: Vector3 = tip() - p.global_position
	return Vector3(rel.dot(b.x), rel.y, rel.dot(b.z))


func _spark(n: Node) -> void:
	if n is CPUParticles3D and bm != null and bm.sprinting and (n as CPUParticles3D).amount == 3:
		pending.append([n, tip(), bm.get_global_transform_interpolated().origin.y])


func _process(_d: float) -> bool:
	for e in pending:
		if is_instance_valid(e[0]) and (e[0] as CPUParticles3D).direction.normalized().y > 0.4:
			sparks.append([(e[0] as Node3D).global_position, e[1], e[2]])
	pending.clear()
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			bm = p.body_model
			stage.camera_rig.rotation.y = 0.0
			node_added.connect(_spark)
			TK.press("move_forward")
			until = TK.wait_secs(0.9)
		1:
			fwd = tip_local()
			check("walking forward, carried in the right hand alone (left on it %.2f), the point low behind on the right (%s)" % [bm.pole_lw, str(fwd)],
				bm.pole_lw < 0.05 and fwd.x > 0.2 and fwd.y < 0.5 and fwd.z > 0.5)
			TK.release("move_forward")
			TK.press("move_back")
			until = TK.wait_secs(0.9)
		2:
			var t := tip_local()
			check("backing off, the same carry (%s vs %s; the chest leans back a little)" % [str(t), str(fwd)], bm.pole_lw < 0.05 and t.distance_to(fwd) < 0.4)
			TK.release("move_back")
			TK.press("move_left")
			until = TK.wait_secs(0.9)
		3:
			var t := tip_local()
			check("strafing, the same carry (%s vs %s)" % [str(t), str(fwd)], bm.pole_lw < 0.05 and t.distance_to(fwd) < 0.3)
			TK.release("move_left")
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(1.4)
		4:
			var t := tip_local()
			check("sprinting (%s), the point drags on the ground behind (%s)" % [str(bm.sprinting), str(t)], bm.sprinting and t.y < 0.15 and t.z > 0.5)
			var worst := 0.0
			for s in sparks:
				worst = maxf(worst, (s[0] as Vector3).distance_to(s[1]))
			check("sparks fly off the dragged point (%d bursts, the farthest %.3f m from the point)" % [sparks.size(), worst], sparks.size() >= 5 and worst <= 0.15)
			check("where it meets the ground", sparks.all(func(s): return (s[0] as Vector3).y - float(s[2]) < 0.15))
			TK.release("sprint")
			TK.release("move_forward")
			return TK.done(fails)
	step += 1
	return false
