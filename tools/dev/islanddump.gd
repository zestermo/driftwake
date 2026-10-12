extends SceneTree
## Brinehollow node by node, for diffing two builds (the kit's "same island" check):
## a fresh StarterIsland is built 9 km off in the world and every node under it is
## written as one line (path with auto-name numbers dropped, class, transform to the
## mm, meshes by surface/vertex count/texture/tint, collision shapes, lights, NPC
## names, save ids, prompts). Diff two dumps with `git diff --no-index a.txt b.txt`.
## Headless is fine. Args: <out.txt>
var t := 0.0
var out := ""


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	var w = root.get_node_or_null("World/Islands")
	if w == null or t < 1.5:
		return false
	var isl = load("res://scripts/island/starter_island.gd").new()
	isl.name = "DumpIsle"
	isl.position = Vector3(0.0, 0.0, 9000.0)
	w.add_child(isl)
	isl.build(int(w.world_seed))
	var lines := PackedStringArray()
	_walk(isl, isl, lines)
	var ex := PackedStringArray()
	for e in isl.exclusions:
		ex.append("%s/%s" % [_f(Vector3(e[0].x, 0, e[0].y)), _f(float(e[1]))])
	lines.append("exclusions %d h%d" % [ex.size(), hash(ex)])
	lines.append("paths %d h%d" % [isl.paths.size(), hash(str(isl.paths))])
	lines.append("anchors odile%s tackett%s pell%s spawn%s" % [_f(Vector3(isl.odile_at.x, 0, isl.odile_at.y)), _f(Vector3(isl.tackett_at.x, 0, isl.tackett_at.y)), _f(Vector3(isl.pell_at.x, 0, isl.pell_at.y)), _f(isl.player_spawn_local)])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("DUMP %d nodes -> %s" % [lines.size(), out])
	if isl.get("build_ms") != null:
		print("BUILD_MS ", isl.build_ms)
	quit()
	return true


static func _clean(s: String) -> String:
	var re := RegEx.new()
	re.compile("@(\\w+)@\\d+")
	return re.sub(s, "@$1@", true)


static func _f(v) -> String:
	if v is Vector3:
		return "(%.3f,%.3f,%.3f)" % [v.x, v.y, v.z]
	if v is Color:
		return "(%.3f,%.3f,%.3f,%.3f)" % [v.r, v.g, v.b, v.a]
	if v is float:
		return "%.3f" % v
	return str(v)


static func _mat(m: Material) -> String:
	if m == null:
		return "-"
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var tex = sm.get_shader_parameter("albedo_tex")
		var tint = sm.get_shader_parameter("albedo_color")
		var tp := (tex as Texture2D).resource_path.get_file() if tex is Texture2D else "-"
		var em = sm.get_shader_parameter("emission_color")
		return "%s/%s%s" % [tp, _f(tint) if tint is Color else "-", "/e" + _f(em) if em is Color else ""]
	return m.get_class()


static func _mesh(m: Mesh) -> String:
	if m == null:
		return "nomesh"
	var parts := PackedStringArray()
	for i in range(m.get_surface_count()):
		var n := 0
		var vh := 0
		if m is ArrayMesh:
			n = (m as ArrayMesh).surface_get_array_len(i)
			var arr: Array = (m as ArrayMesh).surface_get_arrays(i)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var q := PackedInt32Array()
			for v in vs:
				q.append(roundi(v.x * 1000.0))
				q.append(roundi(v.y * 1000.0))
				q.append(roundi(v.z * 1000.0))
			vh = hash(q)
		parts.append("%d:%d:%s" % [n, vh, _mat(m.surface_get_material(i))])
	return "[" + " ".join(parts) + "]"


func _walk(isl: Node, n: Node, lines: PackedStringArray) -> void:
	for c in n.get_children():
		var line := "%s %s" % [_clean(str(isl.get_path_to(c))), c.get_class()]
		if c is Node3D:
			var x: Transform3D = (c as Node3D).transform
			line += " o%s b%s%s%s" % [_f(x.origin), _f(x.basis.x), _f(x.basis.y), _f(x.basis.z)]
			line += " v%s" % ("1" if (c as Node3D).visible else "0")
		if c is MeshInstance3D:
			line += " mesh%s cs%d" % [_mesh((c as MeshInstance3D).mesh), (c as GeometryInstance3D).cast_shadow]
		if c is GeometryInstance3D:
			line += " vr%s" % _f((c as GeometryInstance3D).visibility_range_end)
		if c is MultiMeshInstance3D:
			var mm: MultiMesh = (c as MultiMeshInstance3D).multimesh
			var hsh := 0
			for i in range(mm.instance_count):
				hsh = hash([hsh, _f(mm.get_instance_transform(i).origin)])
			line += " mm%d %s h%d" % [mm.instance_count, _mesh(mm.mesh), hsh]
		if c is CollisionShape3D:
			var s: Shape3D = (c as CollisionShape3D).shape
			var desc := s.get_class() if s else "none"
			if s is BoxShape3D:
				desc += _f((s as BoxShape3D).size)
			elif s is CylinderShape3D:
				desc += "%s/%s" % [_f((s as CylinderShape3D).radius), _f((s as CylinderShape3D).height)]
			elif s is SphereShape3D:
				desc += _f((s as SphereShape3D).radius)
			elif s is ConcavePolygonShape3D:
				desc += str((s as ConcavePolygonShape3D).get_faces().size())
			line += " " + desc
		if c is Light3D:
			line += " light%s e%s r%s" % [_f((c as Light3D).light_color), _f((c as Light3D).light_energy), _f(c.get("omni_range"))]
		for prop in ["save_id", "prompt_text", "npc_name", "dialogue_id", "shop_id", "voice", "walk_speed", "_facing", "length", "deck_depth", "rail", "freeboard", "half_len", "respawn_time"]:
			var v = c.get(prop)
			if v != null and not (v is Callable):
				line += " %s=%s" % [prop, _f(v)]
		if c.is_in_group("npcs"):
			var wp := PackedStringArray()
			for w in c.waypoints:
				wp.append(_f(w))
			line += " barks%d wp[%s] look%d seated%s" % [hash(str(c.barks)), ",".join(wp), hash(str(c.humanoid.look)), str(c.humanoid.seated)]
		if c.get("specs") is Array:
			line += " specs%d" % hash(str(c.get("specs")))
		if c.get("contents") is Array:
			var its := PackedStringArray()
			for st in c.contents:
				its.append("%s/%s x%d" % [st.item.id, st.item.display_name, st.quantity])
			line += " items[%s]" % ", ".join(its)
		if c is CollisionObject3D:
			line += " L%d M%d" % [(c as CollisionObject3D).collision_layer, (c as CollisionObject3D).collision_mask]
		lines.append(line)
		# (an NPC's body and a moored hull's rigging are built by their own code: their tops are enough)
		if c.is_in_group("npcs") or c is CharacterBody3D:
			continue
		_walk(isl, c, lines)
