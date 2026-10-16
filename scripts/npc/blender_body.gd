class_name BlenderBody
extends Node3D
## Debug: the captain's procedural body swapped for a model edited in Blender.
## export_captain() bakes the procedural body (rest pose) into one armature and
## has Blender build art/blender/captain.blend from it; that .blend exports MODEL.
## In game the procedural rig keeps running unseen and every bone of the
## Blender armature copies the joint or skeleton bone it was named after.

const MODEL := "res://assets/models/captain/captain.glb"
const ART_DIR := "res://art/blender/"
const BLENDER := "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
const SETUP_PY := "res://tools/blender/captain_setup.py"

var hum: Humanoid
var skel: Skeleton3D
var _src: Array = []
var _off: Array[Transform3D] = []
var _order := PackedInt32Array()
var _kinv := Transform3D()
var _pose: Array[Transform3D] = []
var _mirror: Array = []
var _hidden: Dictionary = {}


## F4: on or off. Returns the toast.
static func toggle(h: Humanoid) -> String:
	var on := h.get_node_or_null("BlenderBody")
	if on:
		h.remove_child(on)
		on.queue_free()
		return "Body: procedural"
	if not ResourceLoader.exists(MODEL):
		return "No Blender model yet: Ctrl+F4 exports this captain"
	var b := BlenderBody.new()
	b.name = "BlenderBody"
	b.hum = h
	h.add_child(b)
	return "Body: Blender (%s)" % MODEL.get_file()


func _ready() -> void:
	process_priority = 110
	var scene := (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child(scene)
	var skels := scene.find_children("*", "Skeleton3D", true, false)
	assert(skels.size() == 1, "%s needs exactly one armature, has %d" % [MODEL, skels.size()])
	skel = skels[0]
	var rest := _rest_rig(hum.look, hum.swappable_hands)
	var rest_src := _sources(rest)
	var live := _sources(hum)
	var k := _xf(skel, hum)
	_kinv = k.affine_inverse()
	var n := skel.get_bone_count()
	_src.resize(n)
	_off.resize(n)
	_pose.resize(n)
	for b in range(n):
		var bn := skel.get_bone_name(b)
		_src[b] = []
		if live.has(bn) and rest_src.has(bn):
			_src[b] = [live[bn]["node"], live[bn]["bone"]]
			_off[b] = _rest_of(rest_src[bn], rest).affine_inverse() * k * skel.get_bone_global_rest(b)
	var queue := Array(skel.get_parentless_bones())
	while not queue.is_empty():
		var b: int = queue.pop_front()
		_order.append(b)
		queue.append_array(Array(skel.get_bone_children(b)))
	rest.free()
	var parts := {}
	for mi in _parts(hum):
		parts[_part_name(mi)] = mi
		_hidden[mi] = mi.layers
		mi.layers = 0
	var end := BodyBuilder.RANGE * float(hum.look.get("height", 1.0))
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in range(m.mesh.get_surface_count()):
			m.set_surface_override_material(s, _to_psx(m.get_active_material(s)))
		m.visibility_range_end = end
		m.visibility_range_end_margin = end * 0.1
		if parts.has(String(m.name)):
			_mirror.append([m, parts[String(m.name)]])


func _exit_tree() -> void:
	for mi in _hidden:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).layers = _hidden[mi]
	_hidden.clear()


func _process(_delta: float) -> void:
	if hum.pose_frame != Engine.get_process_frames():
		return
	var hinv := hum.global_transform.affine_inverse()
	for b in _order:
		var p := skel.get_bone_parent(b)
		var s: Array = _src[b]
		var g: Transform3D
		if s.is_empty():
			g = (_pose[p] if p >= 0 else Transform3D.IDENTITY) * skel.get_bone_rest(b)
		else:
			var now: Transform3D = hinv * (s[0] as Node3D).global_transform
			if int(s[1]) >= 0:
				now = now * (s[0] as Skeleton3D).get_bone_global_pose(s[1])
			g = _kinv * now * _off[b]
		_pose[b] = g
		skel.set_bone_pose(b, _pose[p].affine_inverse() * g if p >= 0 else g)
	for m in _mirror:
		(m[0] as Node3D).visible = (m[1] as Node3D).is_visible_in_tree()


## The Blender materials as psx_lit: texture, colour and emission from the file,
## the rest from tags in the material's name (see _std_name).
static func _to_psx(m: Material) -> ShaderMaterial:
	var sm := m as StandardMaterial3D
	var out := ShaderMaterial.new()
	out.shader = PSXMat.LIT_SHADER
	if sm.albedo_texture:
		out.set_shader_parameter("albedo_tex", sm.albedo_texture)
	out.set_shader_parameter("albedo_color", sm.albedo_color)
	var tags := sm.resource_name.split("~")
	out.set_shader_parameter("use_vertex_color", not "nv" in tags)
	out.set_shader_parameter("affine_amount", 1.0)
	for t in tags.slice(1):
		var v := t.get_slice(".", 0)
		if v.begins_with("a"):
			out.set_shader_parameter("affine_amount", float(v.substr(1)) / 100.0)
		elif v.begins_with("p"):
			out.set_shader_parameter("depth_pull", float(v.substr(1)) / 1000.0)
	if sm.emission_enabled:
		out.set_shader_parameter("emission_tex", PSXMat._white())
		out.set_shader_parameter("emission_color", sm.emission)
		out.set_shader_parameter("emission_energy", sm.emission_energy_multiplier)
	return out


# --------------------------------------------------------------------------
# the rig: one bone per joint that carries a body mesh (named after the joint)
# and per bone of the skinned parts' skeletons ("<owner>_<bone>")
# --------------------------------------------------------------------------
static func _parts(h: Humanoid) -> Array:
	return h.find_children("*", "MeshInstance3D", true, false).filter(func(n): return n.has_meta("body_part"))


## The joint a skeleton hangs off (hair and cloth sit in a SpringChains on it).
static func _joint_of(s: Node) -> Node3D:
	var p := s.get_parent()
	while p is SpringChains:
		p = p.get_parent()
	return p as Node3D


static func _prefix(s: Skeleton3D) -> String:
	return String(s.name) if s.name != &"Skeleton" else String(_joint_of(s).name) + "Chains"


static func _part_name(mi: MeshInstance3D) -> String:
	var owner_name := _prefix(mi.get_node(mi.skeleton) as Skeleton3D) if mi.skin else String(mi.get_parent().name)
	return owner_name + "_" + String(mi.name)


## Bone name -> {node, bone (-1 for a joint), parent bone name ("" for a root)}, parents first.
static func _sources(h: Humanoid) -> Dictionary:
	var out := {}
	for mi in _parts(h):
		if not mi.skin:
			_add_joint(out, h, mi.get_parent())
			continue
		var s := mi.get_node(mi.skeleton) as Skeleton3D
		var j := _joint_of(s)
		_add_joint(out, h, j)
		var pre := _prefix(s) + "_"
		for b in range(s.get_bone_count()):
			var p := s.get_bone_parent(b)
			out[pre + s.get_bone_name(b)] = {"node": s, "bone": b, "parent": pre + s.get_bone_name(p) if p >= 0 else String(j.name)}
	return out


static func _add_joint(out: Dictionary, h: Humanoid, j: Node3D) -> void:
	var jn := String(j.name)
	if j == h or (out.has(jn) and out[jn]["node"] == j):
		return
	assert(not out.has(jn), "two body joints named " + jn)
	var p := j.get_parent() as Node3D
	_add_joint(out, h, p)
	out[jn] = {"node": j, "bone": -1, "parent": "" if p == h else String(p.name)}


## A node's transform in the rig's space, walking parents (works off the tree).
static func _xf(n: Node, h: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != h:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _rest_of(info: Dictionary, h: Humanoid) -> Transform3D:
	var t := _xf(info["node"], h)
	if int(info["bone"]) >= 0:
		t = t * (info["node"] as Skeleton3D).get_bone_global_rest(info["bone"])
	return t


## A fresh body of the same look, never posed: its joints are the rest pose.
static func _rest_rig(look: Dictionary, hands: bool) -> Humanoid:
	var h := Humanoid.new()
	h.swappable_hands = hands
	h.setup(look)
	return h


# --------------------------------------------------------------------------
# export (Ctrl+F4)
# --------------------------------------------------------------------------
static func export_captain(look: Dictionary, hands: bool, wait: bool = false) -> String:
	var rest := _rest_rig(look, hands)
	var src := _sources(rest)
	var root := Node3D.new()
	root.name = "Captain"
	var sk := Skeleton3D.new()
	sk.name = "Rig"
	root.add_child(sk)
	var idx := {}
	var glob := {}
	for bn in src:
		var b := sk.add_bone(bn)
		idx[bn] = b
		var g := _rest_of(src[bn], rest)
		g.basis = g.basis.orthonormalized()
		glob[bn] = g
		var p: String = src[bn]["parent"]
		if p != "":
			sk.set_bone_parent(b, idx[p])
		sk.set_bone_rest(b, (glob[p] as Transform3D).affine_inverse() * g if p != "" else g)
	sk.reset_bone_poses()
	var skin := Skin.new()
	for bn in idx:
		skin.add_bind(idx[bn], (glob[bn] as Transform3D).affine_inverse())
	var mats := {}
	for mi in _parts(rest):
		var out := MeshInstance3D.new()
		out.name = _part_name(mi)
		out.mesh = _bake(mi, rest, idx, mats)
		out.skin = skin
		sk.add_child(out)
		out.skeleton = NodePath("..")
		out.owner = root
	sk.owner = root
	rest.free()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	assert(err == OK, "glTF export failed: %s" % error_string(err))
	var dir := ProjectSettings.globalize_path(ART_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var glb := dir.path_join("captain_export.glb")
	err = doc.write_to_filesystem(state, glb)
	assert(err == OK, "writing %s failed: %s" % [glb, error_string(err)])
	root.free()
	# never overwrite an edited .blend: a second export lands next to it
	var blend := dir.path_join("captain.blend")
	var model := ProjectSettings.globalize_path(MODEL)
	if FileAccess.file_exists(blend):
		blend = dir.path_join("captain_new.blend")
		model = ""
	var args := ["--background", "--python-exit-code", "1", "--python",ProjectSettings.globalize_path(SETUP_PY), "--", glb, blend, model]
	if wait:
		var lines: Array = []
		var code := OS.execute(BLENDER, args, lines, true)
		print("".join(lines))
		assert(code == 0, "Blender failed (%d)" % code)
		return "Exported: art/blender/%s" % blend.get_file()
	var pid := OS.create_process(BLENDER, args)
	assert(pid > 0, "couldn't start Blender at " + BLENDER)
	return "Exported: Blender is building art/blender/%s" % blend.get_file()


## One source mesh in the rig's space, skinned to the export bones.
static func _bake(mi: MeshInstance3D, h: Humanoid, idx: Dictionary, mats: Dictionary) -> ArrayMesh:
	var src := mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	var m: Transform3D
	var rigid_bone := -1
	var binds: Array = []
	if mi.skin:
		var s := mi.get_node(mi.skeleton) as Skeleton3D
		m = _xf(s, h)
		var pre := _prefix(s) + "_"
		for k in range(mi.skin.get_bind_count()):
			var b := mi.skin.get_bind_bone(k)
			binds.append([idx[pre + s.get_bone_name(b)], s.get_bone_global_rest(b) * mi.skin.get_bind_pose(k)])
	else:
		m = _xf(mi, h)
		rigid_bone = idx[String(mi.get_parent().name)]
	for si in range(src.get_surface_count()):
		var arr := src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var vb := PackedInt32Array()
		var vw := PackedFloat32Array()
		var per := 4
		if rigid_bone >= 0:
			for i in range(v.size()):
				v[i] = m * v[i]
				nrm[i] = (m.basis * nrm[i]).normalized()
				vb.append_array([rigid_bone, 0, 0, 0])
				vw.append_array([1.0, 0.0, 0.0, 0.0])
		else:
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			per = bones.size() / v.size()
			for i in range(v.size()):
				var p := Vector3.ZERO
				var n := Vector3.ZERO
				for k in range(per):
					var wt := w[i * per + k]
					var bind: Array = binds[bones[i * per + k]]
					vb.append(bind[0])
					vw.append(wt)
					p += ((bind[1] as Transform3D) * v[i]) * wt
					n += ((bind[1] as Transform3D).basis * nrm[i]) * wt
				v[i] = m * p
				nrm[i] = (m.basis * n).normalized()
		var mat := mi.get_active_material(si) as ShaderMaterial
		# Blender reads vertex colours as linear: decode the sRGB-stored ones here
		if mat.get_shader_parameter("vertex_srgb") == true:
			var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
			for i in range(c.size()):
				c[i] = c[i].srgb_to_linear()
			arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_TANGENT] = null
		arr[Mesh.ARRAY_BONES] = vb
		arr[Mesh.ARRAY_WEIGHTS] = vw
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
		if not mats.has(mat):
			mats[mat] = _to_std(mat, mats)
		out.surface_set_material(out.get_surface_count() - 1, mats[mat])
	return out


## A psx_lit material as a plain one Blender can show. What glTF can't carry rides
## in the name: "~a<affine %>", "~p<depth pull in mm>", "~nv" (no vertex colour); "~u<n>" only keeps it unique.
static func _to_std(sm: ShaderMaterial, mats: Dictionary) -> StandardMaterial3D:
	var out := StandardMaterial3D.new()
	out.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	out.roughness = 1.0
	var tint: Color = sm.get_shader_parameter("albedo_color")
	var use_vc: bool = sm.get_shader_parameter("use_vertex_color")
	var tex := sm.get_shader_parameter("albedo_tex") as Texture2D
	var label := "flat"
	if tex and sm.get_shader_parameter("decal_mode") == true:
		# the face decal baked over its skin colour, so it paints like any texture
		label = "face"
		var img := tex.get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var px := img.get_pixel(x, y)
				var c := tint.lerp(px, px.a)
				c.a = 1.0
				img.set_pixel(x, y, c)
		tint = Color.WHITE
		out.albedo_texture = ImageTexture.create_from_image(img)
	elif tex:
		label = tex.resource_path.get_file().get_basename()
		if not mats.has(tex):
			mats[tex] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(tex.resource_path)))
		out.albedo_texture = mats[tex]
	out.albedo_color = tint
	out.vertex_color_use_as_albedo = use_vc
	var em = sm.get_shader_parameter("emission_color")
	if em != null and (em as Color) != Color(0, 0, 0, 1):
		out.emission_enabled = true
		out.emission = em
		out.emission_energy_multiplier = float(sm.get_shader_parameter("emission_energy"))
	var nm := "%s~a%d" % [label, roundi(float(sm.get_shader_parameter("affine_amount")) * 100.0)]
	var pull = sm.get_shader_parameter("depth_pull")
	if pull != null and float(pull) > 0.0:
		nm += "~p%d" % roundi(float(pull) * 1000.0)
	if not use_vc:
		nm += "~nv"
	# names must be unique (glTF writers number duplicates, which would garble a tag)
	var used: Dictionary = mats.get_or_add("names", {})
	if used.has(nm):
		nm += "~u%d" % used.size()
	used[nm] = true
	out.resource_name = nm
	return out
