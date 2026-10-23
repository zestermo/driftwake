extends SceneTree
## A one-skin body (BodyBuilder.one_skin) through a ragdoll: the skin follows every ragdolled joint (the follower
## bones, torso and arms), a severed arm comes off baked and the head's bones fly with it, the rig restored after
## the ragdoll draws exactly what a fresh rig does in the same pose, and an afterimage (FX.still_copy) is that pose.
const TK := preload("res://tools/dev/test_kit.gd")
const SC := preload("res://tools/dev/t/world/_skin_cmp.gd")
var stage
var a
var c
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func live(i: int, x: float) -> Humanoid:
	var h := SC.rig(self, SC.look_of(i), true)
	h.process_mode = Node.PROCESS_MODE_INHERIT
	var p: Vector3 = stage.player.global_position
	h.global_position = p + Vector3(x, 0.0, -3.0)
	return h


## How far (m) the skin's bones are from the joints they copy: followers, the torso, the arms.
func lag(h: Humanoid) -> float:
	var lb: LowerBody = h.hips.get_node("LowerBody")
	var pairs: Array = lb._follow.duplicate()
	pairs += [[h.torso, LowerBody.ARMS + ArmBody.TORSO], [h.arm_l, LowerBody.ARMS + ArmBody.ARM_L],
		[h.fore_r, LowerBody.ARMS + ArmBody.FORE_R], [h.leg_l, LowerBody.THIGH_L]]
	var worst := 0.0
	for pr in pairs:
		var want: Transform3D = (pr[0] as Node3D).global_transform
		var got: Transform3D = lb.global_transform * lb.get_bone_global_pose(pr[1])
		worst = maxf(worst, want.origin.distance_to(got.origin))
		for k in range(3):
			worst = maxf(worst, (want.basis[k] - got.basis[k]).length() * 0.1)
	return worst


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			a = live(5, 1.5)
			c = live(9, -1.5)
			until = TK.wait_secs(0.5)
		1:
			check("standing: the skin follows the joints (%.4f m)" % lag(a), lag(a) < 0.002)
			a.start_ragdoll(Vector3(0, 2.0, -4.0), Vector3(1, 0, 0), false)
			c.start_ragdoll(Vector3(0, 1.0, 3.0), Vector3.ZERO, false)
			until = TK.wait_secs(1.2)
		2:
			check("ragdolled: the skin follows the joints (%.4f m)" % lag(a), lag(a) < 0.03)
			c.sever("arm_r", Vector3(3, 2, 0))
			c.sever("head", Vector3(-2, 3, 0))
			until = TK.wait_secs(0.4)
		3:
			var cut = c.arm_r.get_node_or_null("SeveredArm")
			var lb: LowerBody = c.hips.get_node("LowerBody")
			check("a severed arm comes off baked (%s surfaces), its skin hidden" % (str(cut.mesh.get_surface_count()) if cut else "no"),
				cut != null and cut.mesh.get_surface_count() > 0 and not lb.arm_mesh(true).visible)
			var far: float = c.head.global_position.distance_to(c.torso.global_position)
			check("the severed head's skin flies with it (%.2f m off, skin %.4f m from the joints)" % [far, lag(c)], far > 0.5 and lag(c) < 0.03)
			a.end_ragdoll()
			until = TK.wait_secs(0.3)
		4:
			a.process_mode = Node.PROCESS_MODE_DISABLED
			var b := SC.rig(self, SC.look_of(5), false)
			b.global_transform = a.global_transform
			SC.pose(a, 3)
			SC.pose(b, 3)
			var r := SC.misses(SC.verts(b, false, true), SC.verts(a, false, true))
			check("restored after the ragdoll: draws what a fresh rig does in the same pose, hair and cloth aside (%d of %d off%s)" % [r[0], r[1], "" if int(r[0]) == 0 else ", " + str(r[2])], int(r[0]) == 0)
			var ghost := Node3D.new()
			root.add_child(ghost)
			var skels := {}
			for mi in a.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh:
					root.get_node("FX").still_copy(mi, ghost, skels)
			var g := SC.misses(SC.verts(a, true), SC.verts(ghost, true))
			check("an afterimage is the body as posed (%d of %d off, %d skeletons copied)" % [g[0], g[1], skels.size()], int(g[0]) == 0 and skels.size() >= 1)
			return TK.done(fails)
	step += 1
	return false
