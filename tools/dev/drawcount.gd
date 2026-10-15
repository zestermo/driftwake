extends SceneTree
## Draw calls by piece (headless, no camera): what a frame could draw and cast shadows with.
##   & $env:GODOT --headless --path . --script res://tools/dev/drawcount.gd -- world    # the bench's world (seed 4242), by piece
##   & $env:GODOT --headless --path . --script res://tools/dev/drawcount.gd -- bodies   # 61 bodies: per body, by joint, by material
## world: waits for the chain islands ahead, then per piece (an island's child, digits dropped; else the world's child)
## [nodes, surfaces, surfaces with no visibility range, casting shadows, drawn past 150 m], then the meshes most often
## repeated as separate nodes (MultiMesh candidates). "DRAW" lines are the totals.
var t := 0.0
var mode := "world"
var ready_at := -1.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	mode = a[0] if a.size() > 0 else "world"
	if mode == "bodies":
		_bodies()
		quit()
		return
	load("res://tools/dev/test_kit.gd").use_seed(self, 4242)
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null or t < 2.5:
		return false
	if not w.chain_ready():
		if t > 240.0:
			push_error("drawcount: the chain islands never finished building")
			quit(1)
		return false
	if ready_at < 0.0:
		ready_at = t
	if t - ready_at < 5.0:
		return false
	_count(root.get_node("World"))
	quit()
	return true


func _count(world: Node) -> void:
	var by := {}
	var reps := {}
	var tot := [0, 0, 0, 0, 0]
	for g in world.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var a: Node = gi
		while a.get_parent() != world and a.get_parent().get_parent() != null and a.get_parent().get_parent().name != "Islands":
			a = a.get_parent()
		var key := str(a.name).rstrip("0123456789_@")
		if a.get_parent() != world:
			key = "%s/%s" % [str(a.get_parent().name).left(14), key]
		var s := 1
		var m: Mesh = null
		if gi is MeshInstance3D:
			m = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D:
			m = (gi as MultiMeshInstance3D).multimesh.mesh
		if m != null:
			s = m.get_surface_count()
		if gi is MeshInstance3D and m != null:
			reps[m] = int(reps.get(m, 0)) + 1
		var e: Array = by.get(key, [0, 0, 0, 0, 0])
		var row := [1, s, s if gi.visibility_range_end <= 0.0 else 0,
			s if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0,
			s if gi.visibility_range_end <= 0.0 or gi.visibility_range_end > 150.0 else 0]
		for i in range(5):
			e[i] += row[i]
			tot[i] += row[i]
		by[key] = e
	print("DRAW world: %d nodes, %d surfaces, %d with no visibility range, %d casting shadows, %d drawn past 150 m" % tot)
	var ks := by.keys()
	ks.sort_custom(func(x, y): return by[x][1] > by[y][1])
	for k in ks.slice(0, 70):
		print("  %-34s nodes %5d  surf %5d  norange %5d  shadow %5d  past150 %5d" % ([k] + by[k]))
	var ms := reps.keys().filter(func(x): return reps[x] >= 4)
	ms.sort_custom(func(x, y): return reps[x] * x.get_surface_count() > reps[y] * y.get_surface_count())
	for m in ms.slice(0, 20):
		print("  repeated mesh x%d (%d surf, aabb %s)" % [reps[m], m.get_surface_count(), m.get_aabb().size])


func _bodies() -> void:
	var rng := RandomNumberGenerator.new()
	var looks: Array = [CharacterLook.default_look()]
	for i in range(60):
		rng.seed = 1000 + i
		looks.append(CharacterLook.random_look(rng))
	var tot := 0
	var tot_sh := 0
	var worst := 0
	var by_joint := {}
	var by_mat := {}
	for lk in looks:
		var h := Humanoid.new()
		h.setup(lk)
		root.add_child(h)
		var n := 0
		for g in h.find_children("*", "GeometryInstance3D", true, false):
			var s := 1
			if g is MeshInstance3D:
				var m: Mesh = (g as MeshInstance3D).mesh
				s = m.get_surface_count() if m else 0
				for i in range(s):
					var k := _mat_key((g as MeshInstance3D).get_active_material(i))
					by_mat[k] = int(by_mat.get(k, 0)) + 1
			n += s
			if (g as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				tot_sh += s
			var jk := "%s/%s" % [g.get_parent().name, g.name]
			by_joint[jk] = int(by_joint.get(jk, 0)) + s
		tot += n
		worst = maxi(worst, n)
		h.free()
	var c := float(looks.size())
	print("DRAW bodies: %.1f surfaces per body (worst %d), %.1f casting shadows" % [tot / c, worst, tot_sh / c])
	var jks := by_joint.keys()
	jks.sort_custom(func(a, b): return by_joint[a] > by_joint[b])
	for k in jks:
		print("  joint %-28s %.2f" % [k, by_joint[k] / c])
	var mks := by_mat.keys()
	mks.sort_custom(func(a, b): return by_mat[a] > by_mat[b])
	for k in mks:
		print("  mat %-40s %.2f" % [k, by_mat[k] / c])


func _mat_key(m: Material) -> String:
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var t = sm.get_shader_parameter("albedo_tex")
		var tn: String = (t as Texture2D).resource_path.get_file().get_basename() if t is Texture2D and (t as Texture2D).resource_path != "" else ("img" if t else "flat")
		return "%s/%s%s" % [sm.shader.resource_path.get_file().get_basename(), tn, " glow" if sm.get_shader_parameter("emission_tex") else ""]
	return m.get_class() if m else "none"
