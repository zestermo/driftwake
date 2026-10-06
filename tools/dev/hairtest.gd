extends SceneTree
## Hair and hats: every hair style builds for both bodies, and under every hat
## no hair reaches out past the scalp (nothing pokes through the hat).
var fails := 0
var f := 0


func check(name: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + name)
	if not cond:
		fails += 1


## Hair-material vertices of the head (head-local, unscaled), the strands included.
func _hair_verts(h) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi in h.head.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in range(m.get_surface_count()):
			var mat := m.surface_get_material(s) as ShaderMaterial
			if mat == null:
				continue
			var tex = mat.get_shader_parameter("albedo_tex")
			if tex == null or not str((tex as Texture2D).resource_path).contains("hair"):
				continue
			var v: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var xf: Transform3D = h.head.global_transform.affine_inverse() * (mi as Node3D).global_transform
			for p in v:
				out.append(xf * p)
	return out


func _process(_d: float) -> bool:
	f += 1
	if f < 2:
		return false
	var built := 0
	var styles: Array = CharacterLook.HAIR
	for body in ["masc", "fem"]:
		for hs in styles:
			var lk := CharacterLook.base_look()
			lk["body"] = body
			lk["hair"] = hs
			var h := Humanoid.new()
			h.setup(lk)
			root.add_child(h)
			if hs == "bald" or _hair_verts(h).size() > 0:
				built += 1
			h.free()
	check("every hair style builds for both bodies (%d / %d)" % [built, styles.size() * 2], built == styles.size() * 2)
	# under a hat, hair above the brim hugs the scalp: within the round head's
	# top ring (its real profile, 0.162 x 0.158 m) plus a few millimetres, and
	# no higher than the crown
	var bb := BodyBuilder.new()
	var ring := [0.268, 0.162, 0.158, 0.004, 0.0, BodyBuilder.P_HEAD()]
	var worst := ""
	var worst_r := 0.0
	for hat in CharacterLook.HATS:
		if hat == "none":
			continue
		for hs in styles:
			var lk := CharacterLook.base_look()
			lk["hair"] = hs
			lk["hat"] = hat
			var h := Humanoid.new()
			h.setup(lk)
			root.add_child(h)
			for p in _hair_verts(h):
				if p.y < 0.285:
					continue
				var d := Vector2(p.x, p.z - 0.004)
				var lim: float = bb._surf_r(ring, atan2(d.x, -d.y)) + 0.008
				var r := maxf(d.length() / lim, (p.y - 0.392) / 0.01 + 1.0 if p.y > 0.392 else 0.0)
				if r > worst_r:
					worst_r = r
					worst = "%s + %s at (%.3f, %.3f, %.3f)" % [hat, hs, p.x, p.y, p.z]
			h.free()
	check("no hair pokes out under any hat (worst %.2f of the limit: %s)" % [worst_r, worst], worst_r <= 1.0)
	print("RESULT ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit()
	return false
