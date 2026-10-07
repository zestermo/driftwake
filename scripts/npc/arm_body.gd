class_name ArmBody
extends Skeleton3D
## Both arms (shoulder to wrist, with their sleeves) as one skinned surface.
## Lives under the torso joint with an identity transform, so bone space is
## torso space: bone 0 is the torso, the arm and forearm bones copy those
## joints every frame (after the animator and ragdolls). Each shoulder and
## elbow is a chain of helpers turning 1/8, 2/8 ... 7/8 of the bend (see
## LowerBody), and each ring across the joint rides one of them, so bends fan
## round the joint in an arc and keep their volume. The hands stay rigid on
## the forearms.

const TORSO := 0
const ARM_L := 1
const ARM_R := 2
const FORE_L := 3
const FORE_R := 4
## Joint chains, 9 bones each: the bone above, 7 helpers, the bone below.
const SHOULDER_L_CHAIN := [TORSO, 5, 6, 7, 8, 9, 10, 11, ARM_L]
const SHOULDER_R_CHAIN := [TORSO, 12, 13, 14, 15, 16, 17, 18, ARM_R]
const ELBOW_L_CHAIN := [ARM_L, 19, 20, 21, 22, 23, 24, 25, FORE_L]
const ELBOW_R_CHAIN := [ARM_R, 26, 27, 28, 29, 30, 31, 32, FORE_R]

var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D


func _init() -> void:
	name = "ArmBody"
	process_priority = 100
	for b in ["torso", "arm_l", "arm_r", "fore_l", "fore_r"]:
		add_bone(b)
	for j in ["shoulder_l", "shoulder_r", "elbow_l", "elbow_r"]:
		for i in range(1, 8):
			add_bone("%s_%d" % [j, i])


## One mesh per arm (both on this skeleton), so an arm can be recoloured on its
## own (Armament Haki blackens only the weapon arm).
func arm_mesh(right: bool) -> MeshInstance3D:
	return get_node("MeshR" if right else "MeshL")


func setup(a_l: Node3D, a_r: Node3D, f_l: Node3D, f_r: Node3D, mb_l: MeshBuilder, mb_r: MeshBuilder) -> void:
	arm_l = a_l
	arm_r = a_r
	fore_l = f_l
	fore_r = f_r
	set_bone_rest(TORSO, Transform3D.IDENTITY)
	set_bone_rest(ARM_L, arm_l.transform)
	set_bone_rest(ARM_R, arm_r.transform)
	set_bone_rest(FORE_L, arm_l.transform * fore_l.transform)
	set_bone_rest(FORE_R, arm_r.transform * fore_r.transform)
	for c in [[SHOULDER_L_CHAIN, Transform3D(Basis(), arm_l.position)], [SHOULDER_R_CHAIN, Transform3D(Basis(), arm_r.position)],
			[ELBOW_L_CHAIN, arm_l.transform * fore_l.transform], [ELBOW_R_CHAIN, arm_r.transform * fore_r.transform]]:
		for i in range(1, 8):
			set_bone_rest(c[0][i], c[1])
	reset_bone_poses()
	var skin := Skin.new()
	for b in range(get_bone_count()):
		skin.add_bind(b, get_bone_global_rest(b).affine_inverse())
	for m in [["MeshL", mb_l], ["MeshR", mb_r]]:
		var mi := MeshInstance3D.new()
		mi.name = m[0]
		mi.mesh = (m[1] as MeshBuilder).commit()
		mi.skin = skin
		add_child(mi)
		mi.skeleton = NodePath("..")


## The arm as it is posed right now, as a plain (unskinned) mesh in this
## skeleton's space: skinned on the CPU, for a severed arm to carry off.
func bake_arm(right: bool) -> ArrayMesh:
	var mi := arm_mesh(right)
	var src := mi.mesh as ArrayMesh
	var skin := mi.skin
	var mats: Array[Transform3D] = []
	for i in range(skin.get_bind_count()):
		mats.append(get_bone_global_pose(skin.get_bind_bone(i)) * skin.get_bind_pose(i))
	var out := ArrayMesh.new()
	for s in range(src.get_surface_count()):
		var arr := src.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(v.size(), 1)
		for i in range(v.size()):
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			for k in range(per):
				var wt := w[i * per + k]
				if wt <= 0.0:
					continue
				var m: Transform3D = mats[bones[i * per + k]]
				p += (m * v[i]) * wt
				if nrm.size() == v.size():
					n += (m.basis * nrm[i]) * wt
			v[i] = p
			if nrm.size() == v.size():
				nrm[i] = n.normalized()
		arr[Mesh.ARRAY_VERTEX] = v
		if nrm.size() == v.size():
			arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_BONES] = null
		arr[Mesh.ARRAY_WEIGHTS] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_material(s, src.surface_get_material(s))
	return out


var _rig: Humanoid


## Only on frames the rig posed (a far or hidden rig skips them).
func _process(_delta: float) -> void:
	if _rig == null:
		_rig = Humanoid.rig_of(self)
	if _rig and _rig.pose_frame != Engine.get_process_frames():
		return
	_pose()


func _pose() -> void:
	var torso := get_parent_node_3d()
	if torso == null or arm_l == null or not is_inside_tree():
		return
	var inv := torso.global_transform.affine_inverse()
	for s in [[arm_l, fore_l, ARM_L, FORE_L, SHOULDER_L_CHAIN, ELBOW_L_CHAIN], [arm_r, fore_r, ARM_R, FORE_R, SHOULDER_R_CHAIN, ELBOW_R_CHAIN]]:
		var a: Transform3D = inv * (s[0] as Node3D).global_transform
		var f: Transform3D = inv * (s[1] as Node3D).global_transform
		set_bone_global_pose(s[2], a)
		set_bone_global_pose(s[3], f)
		var aq := a.basis.orthonormalized().get_rotation_quaternion()
		var fq := f.basis.orthonormalized().get_rotation_quaternion()
		for i in range(1, 8):
			set_bone_global_pose(s[4][i], Transform3D(Basis(Quaternion.IDENTITY.slerp(aq, i / 8.0)), a.origin))
			set_bone_global_pose(s[5][i], Transform3D(Basis(aq.slerp(fq, i / 8.0)), f.origin))
