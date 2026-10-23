class_name LowerBody
extends Skeleton3D
## Hips, seat, thighs, knees and shins as one skinned surface (no seams
## between rigid pieces). Lives under the hips joint with an identity
## transform, so bone space is hips space: bone 0 is the pelvis (always
## identity), the thigh and shin bones copy those joints every frame, after
## the animator, foot IK and ragdolls have posed them.
##
## The seat bones are helpers at the hip joints: they turn only part of the
## way with the thigh and push the seat out as the hip flexes (a glute
## stretching over the hip), so lifting a leg doesn't drag the seat forward
## and flatten it.
##
## Each knee is a chain of helpers at the knee joint turning 1/8, 2/8 ... 7/8
## of the way from thigh to shin, and each ring across the knee rides one of
## them, so a bent knee fans round the joint in an arc (round, full volume)
## instead of a blend averaging it into a point.

const PELVIS := 0
const THIGH_L := 1
const THIGH_R := 2
const SEAT_L := 3
const SEAT_R := 4
const SHIN_L := 5
const SHIN_R := 6
## Knee chains, 9 bones each: thigh, 7 helpers, shin.
const KNEE_L_CHAIN := [THIGH_L, 7, 8, 9, 10, 11, 12, 13, SHIN_L]
const KNEE_R_CHAIN := [THIGH_R, 14, 15, 16, 17, 18, 19, 20, SHIN_R]
## How much of the thigh's turn the seat takes.
const SEAT_FOLLOW := 0.32
## How far the seat pushes back (and a little down) at full hip flex.
const SEAT_PUSH := Vector3(0.0, -0.012, 0.035)

## One skin (BodyBuilder.one_skin): the whole body on this skeleton. ArmBody's bones follow
## from ARMS (ArmBody.X + ARMS; its torso bone follows the torso joint), the arms keep their
## own meshes (MeshL, MeshR: Haki, a severed arm) and every other rigid part (torso, neck,
## head, hat...) is in "Mesh", bound to a bone that copies its joint wholesale (follow()).
const ARMS := 21

var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var torso: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var _arm_mbs: Array = []
var _follow: Array = []   # [joint, bone] copied wholesale


func _init() -> void:
	name = "LowerBody"
	process_priority = 100
	for b in ["pelvis", "thigh_l", "thigh_r", "seat_l", "seat_r", "shin_l", "shin_r"]:
		add_bone(b)
	for j in ["knee_l", "knee_r"]:
		for i in range(1, 8):
			add_bone("%s_%d" % [j, i])


func has_arms() -> bool:
	return torso != null


## ArmBody's bones from ARMS on (first, before any follow()), its meshes (built in torso
## space, bones numbered as ArmBody's) moved onto this skeleton by setup().
func add_arms(t: Node3D, a_l: Node3D, a_r: Node3D, f_l: Node3D, f_r: Node3D, mb_l: MeshBuilder, mb_r: MeshBuilder) -> void:
	assert(get_bone_count() == ARMS)
	torso = t
	arm_l = a_l
	arm_r = a_r
	fore_l = f_l
	fore_r = f_r
	_arm_mbs = [mb_l, mb_r]
	for b in ["torso", "arm_l", "arm_r", "fore_l", "fore_r"]:
		add_bone("a_" + b)
	for j in ["shoulder_l", "shoulder_r", "elbow_l", "elbow_r"]:
		for i in range(1, 8):
			add_bone("%s_%d" % [j, i])


## A bone copying `joint` wholesale (rest: the joint in hips space); its index.
func follow(joint: Node3D, rest: Transform3D) -> int:
	var b := get_bone_count()
	add_bone("f_%s" % joint.name)
	set_bone_rest(b, rest)
	_follow.append([joint, b])
	return b


func arm_mesh(right: bool) -> MeshInstance3D:
	return get_node("MeshR" if right else "MeshL")


func bake_arm(right: bool) -> ArrayMesh:
	return ArmBody.bake(self, arm_mesh(right))


## Rest pose = the joints where they were built (hips space), and the mesh
## built in that same space.
func setup(hips_leg_l: Node3D, hips_leg_r: Node3D, hips_shin_l: Node3D, hips_shin_r: Node3D, mb: MeshBuilder) -> void:
	leg_l = hips_leg_l
	leg_r = hips_leg_r
	shin_l = hips_shin_l
	shin_r = hips_shin_r
	set_bone_rest(PELVIS, Transform3D.IDENTITY)
	set_bone_rest(THIGH_L, leg_l.transform)
	set_bone_rest(THIGH_R, leg_r.transform)
	set_bone_rest(SEAT_L, Transform3D(Basis(), leg_l.position))
	set_bone_rest(SEAT_R, Transform3D(Basis(), leg_r.position))
	set_bone_rest(SHIN_L, leg_l.transform * shin_l.transform)
	set_bone_rest(SHIN_R, leg_r.transform * shin_r.transform)
	for i in range(1, 8):
		set_bone_rest(KNEE_L_CHAIN[i], leg_l.transform * shin_l.transform)
		set_bone_rest(KNEE_R_CHAIN[i], leg_r.transform * shin_r.transform)
	if has_arms():
		# ArmBody's rests (torso space) in hips space
		var t := torso.transform
		set_bone_rest(ARMS + ArmBody.TORSO, t)
		set_bone_rest(ARMS + ArmBody.ARM_L, t * arm_l.transform)
		set_bone_rest(ARMS + ArmBody.ARM_R, t * arm_r.transform)
		set_bone_rest(ARMS + ArmBody.FORE_L, t * arm_l.transform * fore_l.transform)
		set_bone_rest(ARMS + ArmBody.FORE_R, t * arm_r.transform * fore_r.transform)
		for c in [[ArmBody.SHOULDER_L_CHAIN, Transform3D(Basis(), arm_l.position)], [ArmBody.SHOULDER_R_CHAIN, Transform3D(Basis(), arm_r.position)],
				[ArmBody.ELBOW_L_CHAIN, arm_l.transform * fore_l.transform], [ArmBody.ELBOW_R_CHAIN, arm_r.transform * fore_r.transform]]:
			for i in range(1, 8):
				set_bone_rest(ARMS + c[0][i], t * c[1])
	reset_bone_poses()
	var skin := Skin.new()
	for b in range(get_bone_count()):
		skin.add_bind(b, get_bone_global_rest(b).affine_inverse())
	var meshes := [["Mesh", mb]]
	if has_arms():
		for amb in _arm_mbs:
			(amb as MeshBuilder).shift_bones(ARMS, torso.transform)
		meshes += [["MeshL", _arm_mbs[0]], ["MeshR", _arm_mbs[1]]]
	for m in meshes:
		var mi := MeshInstance3D.new()
		mi.name = m[0]
		mi.mesh = (m[1] as MeshBuilder).commit()
		mi.skin = skin
		add_child(mi)
		mi.skeleton = NodePath("..")
	_arm_mbs = []


var _rig: Humanoid


## Only on frames the rig posed (a far or hidden rig skips them).
func _process(_delta: float) -> void:
	if _rig == null:
		_rig = Humanoid.rig_of(self)
	if _rig and _rig.pose_frame != Engine.get_process_frames():
		return
	_pose()


func _pose() -> void:
	var hips := get_parent_node_3d()
	if hips == null or leg_l == null or not is_inside_tree():
		return
	var inv := hips.global_transform.affine_inverse()
	for side in [[leg_l, THIGH_L, SEAT_L, shin_l, SHIN_L, KNEE_L_CHAIN], [leg_r, THIGH_R, SEAT_R, shin_r, SHIN_R, KNEE_R_CHAIN]]:
		var rel: Transform3D = inv * (side[0] as Node3D).global_transform
		set_bone_global_pose(side[1], rel)
		var q := rel.basis.orthonormalized().get_rotation_quaternion()
		var srel: Transform3D = inv * (side[3] as Node3D).global_transform
		set_bone_global_pose(side[4], srel)
		var sq := srel.basis.orthonormalized().get_rotation_quaternion()
		for i in range(1, 8):
			set_bone_global_pose(side[5][i], Transform3D(Basis(q.slerp(sq, i / 8.0)), srel.origin))
		# hip flex = the thigh swinging forward/up (rig: thigh x+ = forward)
		var flex := clampf(rel.basis.get_euler().x / 1.5, -0.5, 1.0)
		var rest_o := get_bone_rest(side[2]).origin
		set_bone_global_pose(side[2], Transform3D(Basis(Quaternion.IDENTITY.slerp(q, SEAT_FOLLOW)),
			rest_o + SEAT_PUSH * flex))
	for f in _follow:
		set_bone_global_pose(f[1], inv * (f[0] as Node3D).global_transform)
	if not has_arms():
		return
	# ArmBody's pose (see there), in hips space: the shoulder helpers turn from the torso's turn
	var t := inv * torso.global_transform
	set_bone_global_pose(ARMS + ArmBody.TORSO, t)
	var tq := t.basis.orthonormalized().get_rotation_quaternion()
	for s in [[arm_l, fore_l, ArmBody.ARM_L, ArmBody.FORE_L, ArmBody.SHOULDER_L_CHAIN, ArmBody.ELBOW_L_CHAIN],
			[arm_r, fore_r, ArmBody.ARM_R, ArmBody.FORE_R, ArmBody.SHOULDER_R_CHAIN, ArmBody.ELBOW_R_CHAIN]]:
		var a: Transform3D = inv * (s[0] as Node3D).global_transform
		var fo: Transform3D = inv * (s[1] as Node3D).global_transform
		set_bone_global_pose(ARMS + s[2], a)
		set_bone_global_pose(ARMS + s[3], fo)
		var aq := a.basis.orthonormalized().get_rotation_quaternion()
		var fq := fo.basis.orthonormalized().get_rotation_quaternion()
		for i in range(1, 8):
			set_bone_global_pose(ARMS + s[4][i], Transform3D(Basis(tq.slerp(aq, i / 8.0)), a.origin))
			set_bone_global_pose(ARMS + s[5][i], Transform3D(Basis(aq.slerp(fq, i / 8.0)), fo.origin))
