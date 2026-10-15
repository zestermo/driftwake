extends SceneTree
## Draw calls by piece (headless, no camera): what a frame could draw and cast shadows with.
##   & $env:GODOT --headless --path . --script res://tools/dev/drawcount.gd -- isle     # Brinehollow by piece
##   & $env:GODOT --headless --path . --script res://tools/dev/drawcount.gd -- bodies   # 61 bodies: per body, by joint, by material
## isle: per island child (digits dropped) [nodes, surfaces, surfaces with no visibility range, surfaces casting
## shadows, surfaces visible past 150 m], then the meshes most often repeated as separate nodes (MultiMesh candidates).
var t := 0.0
var mode := "isle"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	mode = a[0] if a.size() > 0 else "isle"
	if mode == "bodies":
		_bodies()
		quit()
		return
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null or t < 1.5:
		return false
	var isl = load("res://scripts/island/starter_island.gd").new()
	isl.name = "CountIsle"
	isl.position = Vector3(0.0, 0.0, 9000.0)
	w.add_child(isl)
	isl.build(int(w.world_seed))
	var by := {}
	var reps := {}
	var tot := [0, 0, 0, 0, 0]
	for g in isl.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var a: Node = gi
		while a.get_parent() != isl:
			a = a.get_parent()
		var key := str(a.name).rstrip("0123456789_@")
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
	print("DRAW Brinehollow: %d nodes, %d surfaces, %d with no visibility range, %d casting shadows, %d seen past 150 m" % tot)
	var ks := by.keys()
	ks.sort_custom(func(x, y): return by[x][1] > by[y][1])
	for k in ks:
		print("  %-24s nodes %4d  surf %5d  norange %5d  shadow %5d  past150 %5d" % ([k] + by[k]))
	var ms := reps.keys().filter(func(x): return reps[x] >= 4)
	ms.sort_custom(func(x, y): return reps[x] * x.get_surface_count() > reps[y] * y.get_surface_count())
	for m in ms.slice(0, 15):
		print("  repeated mesh x%d (%d surf, aabb %s)" % [reps[m], m.get_surface_count(), m.get_aabb().size])
	quit()
	return true


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
