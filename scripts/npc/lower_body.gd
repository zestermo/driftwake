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

var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D


func _init() -> void:
	name = "LowerBody"
	process_priority = 100
	for b in ["pelvis", "thigh_l", "thigh_r", "seat_l", "seat_r", "shin_l", "shin_r"]:
		add_bone(b)
	for j in ["knee_l", "knee_r"]:
		for i in range(1, 8):
			add_bone("%s_%d" % [j, i])


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
	reset_bone_poses()
	var skin := Skin.new()
	for b in range(get_bone_count()):
		skin.add_bind(b, get_bone_global_rest(b).affine_inverse())
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mb.commit()
	mi.skin = skin
	add_child(mi)
	mi.skeleton = NodePath("..")


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
