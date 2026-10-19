extends SceneTree
## The armature clips are authored on (docs/blender_clips.md): the default captain's joints as a glb, one bone
## per Humanoid joint named after it, at its rest (rotations zeroed, as the animator writes them), with a stick
## body skinned to it so there's something to see in Blender.
##   godot --path . --script res://tools/dev/clip_rig.gd -- res://art/clips/rig.glb
## Given a keys file too, it keys that clip on the rig and writes it with the animation: the stand-in for
## tools/blender/pilot_clip.py where Blender isn't installed (the same keys, the same kind of glb).
##   godot --path . --script res://tools/dev/clip_rig.gd -- res://art/clips/read.glb res://tools/blender/pilot_read.json

var _f := 0


func _process(_d: float) -> bool:
	_f += 1
	if _f < 3:
		return false
	var a := OS.get_cmdline_user_args()
	var h = load("res://scripts/npc/humanoid.gd").new()
	root.add_child(h)
	h.setup(CharacterLook.default_look())
	var src: Array = ClipPlayer.rests(h)
	var rest: Dictionary = src[0]
	var parents: Dictionary = src[1]
	var scene := Node3D.new()
	scene.name = "ClipRig"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	scene.add_child(skel)
	for j in Humanoid.JOINTS:
		skel.add_bone(j)
	for j in Humanoid.JOINTS:
		var b := skel.find_bone(j)
		var p: String = parents[j]
		if p != "":
			skel.set_bone_parent(b, skel.find_bone(p))
		var local: Transform3D = rest[j] if p == "" else (rest[p] as Transform3D).affine_inverse() * rest[j]
		skel.set_bone_rest(b, local)
	skel.reset_bone_poses()
	_stick_body(skel, rest, parents)
	if a.size() > 1:
		_keyed(scene, skel, rest, parents, a[1])
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	root.add_child(scene)
	assert(doc.append_from_scene(scene, state) == OK)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(a[0].get_base_dir()))
	assert(doc.write_to_filesystem(state, ProjectSettings.globalize_path(a[0])) == OK)
	print("CLIP RIG ", a[0], " bones ", skel.get_bone_count())
	quit()
	return false


## A box from each joint to its first child joint (a cube at the ends), skinned whole to that joint's bone.
func _stick_body(skel: Skeleton3D, rest: Dictionary, parents: Dictionary) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skin := Skin.new()
	for j in Humanoid.JOINTS:
		var b := skel.find_bone(j)
		skin.add_bind(b, (rest[j] as Transform3D).affine_inverse())
		var a: Vector3 = (rest[j] as Transform3D).origin
		var to := a + Vector3(0, -0.08, 0)
		for k in Humanoid.JOINTS:
			if parents[k] == j:
				to = (rest[k] as Transform3D).origin
				break
		_box(st, b, a, to, 0.035)
	skin.bind_count = Humanoid.JOINTS.size()
	var mi := MeshInstance3D.new()
	mi.name = "StickBody"
	mi.mesh = st.commit()
	mi.skin = skin
	skel.add_child(mi)
	mi.skeleton = mi.get_path_to(skel)


func _box(st: SurfaceTool, bone: int, a: Vector3, b: Vector3, r: float) -> void:
	var ax := (b - a)
	if ax.length() < 0.001:
		ax = Vector3(0, -0.05, 0)
	var up := Vector3.UP if absf(ax.normalized().y) < 0.9 else Vector3.RIGHT
	var u := ax.cross(up).normalized() * r
	var v := ax.cross(u).normalized() * r
	var c := [a + u + v, a + u - v, a - u - v, a - u + v, b + u + v, b + u - v, b - u - v, b - u + v]
	for q in [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_bones(PackedInt32Array([bone, 0, 0, 0]))
			st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			st.add_vertex(c[q[i]])


## The clip in `keys_path` (the pilot's keys: joint Eulers in the animator's convention at times) as rotation
## tracks on the rig's bones, in an AnimationPlayer named after the clip.
func _keyed(scene: Node3D, skel: Skeleton3D, rest: Dictionary, parents: Dictionary, keys_path: String) -> void:
	var clip: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(keys_path))
	var anim := Animation.new()
	anim.length = float(clip["length"])
	anim.loop_mode = Animation.LOOP_LINEAR if clip["loop"] else Animation.LOOP_NONE
	var joints: Dictionary = clip["keys"][0]["pose"]
	for j in joints:
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath("Skeleton3D:" + str(j)))
		var p: String = parents[j]
		var rel: Basis = (rest[j] as Transform3D).basis if p == "" else ((rest[p] as Transform3D).affine_inverse() * rest[j]).basis
		for key in clip["keys"]:
			var e: Array = key["pose"][j]
			anim.rotation_track_insert_key(tr, float(key["t"]), (rel * Basis.from_euler(Vector3(e[0], e[1], e[2]))).get_rotation_quaternion())
	var lib := AnimationLibrary.new()
	lib.add_animation(str(clip["name"]), anim)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	scene.add_child(ap)
	ap.add_animation_library("", lib)
