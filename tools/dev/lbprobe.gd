extends SceneTree
## Lower body mesh probe: lists triangles whose winding disagrees with their
## vertex normals (drawn inside-out) or that are degenerate, per surface.
## Args: [fem 1/0]


func _initialize():
	var a := OS.get_cmdline_user_args()
	var lk := CharacterLook.base_look()
	if a.size() == 0 or a[0] != "0":
		lk["body"] = "fem"
	var h := Humanoid.new()
	h.setup(lk)
	root.add_child(h)
	var lb := h.hips.get_node_or_null("LowerBody")
	if lb == null:
		print("no LowerBody (script error?)")
		quit(1)
		return
	var mesh: ArrayMesh = (lb.get_node("Mesh") as MeshInstance3D).mesh
	for s in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var bad := 0
		var degen := 0
		for t in range(0, v.size(), 3):
			# Godot front face: (c - a).cross(b - a) points outward
			var fnm := (v[t + 2] - v[t]).cross(v[t + 1] - v[t])
			if fnm.length() < 1e-9:
				degen += 1
				continue
			var avg := n[t] + n[t + 1] + n[t + 2]
			if fnm.normalized().dot(avg.normalized()) < 0.0:
				bad += 1
				if bad <= 12:
					print("  inside-out tri at ", (v[t] + v[t + 1] + v[t + 2]) / 3.0, "  face ", fnm.normalized(), "  normal ", avg.normalized())
		print("surface %d: %d tris, %d inside-out, %d degenerate" % [s, v.size() / 3, bad, degen])
	quit()
