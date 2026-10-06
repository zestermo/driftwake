class_name LowerBody
extends Skeleton3D
## Hips, seat and both thighs as one skinned surface (no seams between rigid
## pieces). Lives under the hips joint with an identity transform, so bone
## space is hips space: bone 0 is the pelvis (always identity), bones 1 and 2
## copy the thigh joints' transforms relative to the hips every frame, after
## the animator, foot IK and ragdolls have posed them.

const PELVIS := 0
const THIGH_L := 1
const THIGH_R := 2

var leg_l: Node3D
var leg_r: Node3D


func _init() -> void:
	name = "LowerBody"
	process_priority = 100
	add_bone("pelvis")
	add_bone("thigh_l")
	add_bone("thigh_r")


## Rest pose = the joints where they were built (hips space), and the mesh
## built in that same space.
func setup(hips_leg_l: Node3D, hips_leg_r: Node3D, mb: MeshBuilder) -> void:
	leg_l = hips_leg_l
	leg_r = hips_leg_r
	set_bone_rest(PELVIS, Transform3D.IDENTITY)
	set_bone_rest(THIGH_L, leg_l.transform)
	set_bone_rest(THIGH_R, leg_r.transform)
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


func _process(_delta: float) -> void:
	_pose()


func _pose() -> void:
	var hips := get_parent_node_3d()
	if hips == null or leg_l == null or not is_inside_tree():
		return
	var inv := hips.global_transform.affine_inverse()
	set_bone_global_pose(THIGH_L, inv * leg_l.global_transform)
	set_bone_global_pose(THIGH_R, inv * leg_r.global_transform)
